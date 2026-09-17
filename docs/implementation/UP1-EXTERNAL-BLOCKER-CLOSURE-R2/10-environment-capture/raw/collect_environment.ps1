$ErrorActionPreference = 'Continue'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$raw = Join-Path $root 'raw'
$utcNow = { (Get-Date).ToUniversalTime().ToString('o') }

function Sha256([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function WriteUtf8([string]$path, [string]$text) {
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
}
function RelativePath([string]$path) {
    return $path.Substring($root.Length + 1).Replace('\','/')
}

$records = New-Object 'System.Collections.Generic.List[object]'
function Invoke-Capture([string]$name, [string]$fileName, [string[]]$arguments) {
    $safe = ($name -replace '[^A-Za-z0-9_.-]', '_')
    $outPath = Join-Path $raw ($safe + '.stdout.raw')
    $errPath = Join-Path $raw ($safe + '.stderr.raw')
    $combinedPath = Join-Path $raw ($safe + '.combined.raw')
    $start = & $utcNow
    $stdout = ''
    $stderr = ''
    $exit = $null
    $pidValue = $null
    $failure = $null
    $resolved = $fileName
    try {
        $cmd = Get-Command $fileName -ErrorAction Stop | Select-Object -First 1
        if ($cmd.Path) { $resolved = $cmd.Path }
        $psi = [Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $resolved
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        if ($psi.PSObject.Properties.Name -contains 'ArgumentList') {
            foreach ($arg in $arguments) { [void]$psi.ArgumentList.Add($arg) }
        } else {
            $quoted = foreach ($arg in $arguments) { '"' + ($arg -replace '"','\"') + '"' }
            $psi.Arguments = $quoted -join ' '
        }
        $p = [Diagnostics.Process]::new()
        $p.StartInfo = $psi
        [void]$p.Start()
        $pidValue = $p.Id
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        $p.WaitForExit()
        $exit = $p.ExitCode
        $p.Dispose()
    } catch {
        $failure = $_.Exception.Message
        $stderr = if ($stderr) { $stderr + "`n" + $failure } else { $failure }
        $exit = -1
    }
    $end = & $utcNow
    WriteUtf8 $outPath $stdout
    WriteUtf8 $errPath $stderr
    WriteUtf8 $combinedPath ($stdout + $stderr)
    $record = [ordered]@{
        name = $name
        command = (@($resolved) + @($arguments)) -join ' '
        executable = $resolved
        arguments = @($arguments)
        cwd = (Get-Location).Path
        pid = $pidValue
        started_utc = $start
        ended_utc = $end
        exit_code = $exit
        failure = $failure
        raw = [ordered]@{
            stdout = RelativePath $outPath
            stderr = RelativePath $errPath
            combined = RelativePath $combinedPath
            stdout_sha256 = Sha256 $outPath
            stderr_sha256 = Sha256 $errPath
            combined_sha256 = Sha256 $combinedPath
        }
    }
    $records.Add([pscustomobject]$record)
    return [pscustomobject]$record
}

function Json([object]$obj, [string]$path) {
    WriteUtf8 $path (($obj | ConvertTo-Json -Depth 30) + "`n")
}

$git = (Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1).Path
$julia = (Get-Command julia -ErrorAction SilentlyContinue | Select-Object -First 1).Path
$python = (Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1).Path
$openssl = (Get-Command openssl -ErrorAction SilentlyContinue | Select-Object -First 1).Path

$gitRoot = Invoke-Capture 'git_root' 'git' @('rev-parse','--show-toplevel')
$gitHead = Invoke-Capture 'git_head' 'git' @('rev-parse','HEAD')
$gitStatus = Invoke-Capture 'git_status_short' 'git' @('status','--short')
$gitDiff = Invoke-Capture 'git_diff_binary' 'git' @('diff','--binary')
$gitDiffCached = Invoke-Capture 'git_diff_cached_binary' 'git' @('diff','--cached','--binary')
$gitVersion = Invoke-Capture 'git_version' 'git' @('--version')
$juliaVersion = Invoke-Capture 'julia_version' 'julia' @('--version')
$pythonVersion = Invoke-Capture 'python_version' 'python' @('--version')
$opensslVersion = $null
if ($openssl) { $opensslVersion = Invoke-Capture 'openssl_version' 'openssl' @('version','-a') }
$lockDiscovery = Invoke-Capture 'lock_file_discovery' 'rg' @('--files','-g','Project.toml','-g','Manifest.toml','-g','*.lock','-g','poetry.lock','-g','Pipfile.lock','-g','environment*.yml','-g','environment*.yaml','-g','requirements*.txt')
$juliaDeps = $null
if ($julia) { $juliaDeps = Invoke-Capture 'julia_pkg_status_manifest' 'julia' @('--startup-file=no','--project=.','-e','using Pkg; Pkg.status(; mode=Pkg.PKGMODE_MANIFEST)') }
$pythonDeps = $null
if ($python) { $pythonDeps = Invoke-Capture 'python_pip_list_json' 'python' @('-m','pip','list','--format=json') }
$pythonSys = $null
if ($python) { $pythonSys = Invoke-Capture 'python_runtime_sys' 'python' @('-c','import json,sys,platform; print(json.dumps({"executable":sys.executable,"version":sys.version,"implementation":platform.python_implementation(),"sys_path":sys.path}, sort_keys=True))') }
$juliaSys = $null
if ($julia) { $juliaSys = Invoke-Capture 'julia_runtime_sys' 'julia' @('--startup-file=no','--project=.','-e','println(Sys.BINDIR); println(VERSION); println.(LOAD_PATH)') }

$allFiles = @('Project.toml','Manifest.toml')
$lockDiscoveryOut = Join-Path $root ($lockDiscovery.raw.stdout -replace '^\./','')
if (Test-Path -LiteralPath $lockDiscoveryOut -PathType Leaf) {
    $allFiles += (Get-Content -Raw $lockDiscoveryOut -ErrorAction SilentlyContinue) -split "`r?`n" | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }
}
$allFiles = @($allFiles | ForEach-Object { $_.ToString().Replace('\','/') } | Sort-Object -Unique)
$lockRecords = foreach ($rel in $allFiles) {
    $full = [IO.Path]::GetFullPath((Join-Path (Get-Location) $rel))
    [ordered]@{ path = $rel; absolute_path = $full; exists = (Test-Path -LiteralPath $full -PathType Leaf); sha256 = Sha256 $full; bytes = if (Test-Path -LiteralPath $full -PathType Leaf) { (Get-Item -LiteralPath $full).Length } else { $null }; status = if (Test-Path -LiteralPath $full -PathType Leaf) { 'observed_present_unbound' } else { 'typed_absent' } }
}

function BinaryObservation([string]$name, [string]$path, [object]$versionRecord) {
    if (-not $path) {
        return [ordered]@{ name=$name; status='typed_absent'; absence_code='INTERPRETER_OR_TOOL_NOT_FOUND'; path=$null; version=$null; sha256=$null; publisher=$null; signature=$null; source_note='No executable resolved by Get-Command; no installation or download attempted.' }
    }
    $item = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
    $vi = if ($item) { $item.VersionInfo } else { $null }
    $sig = Get-AuthenticodeSignature -LiteralPath $path -ErrorAction SilentlyContinue
    $cert = if ($sig) { $sig.SignerCertificate } else { $null }
    [ordered]@{
        name=$name; status='observed_not_candidate_bound'; path=[IO.Path]::GetFullPath($path); version=if($vi){$vi.ProductVersion}else{$null}; sha256=Sha256 $path; bytes=if($item){$item.Length}else{$null}; last_write_time_utc=if($item){$item.LastWriteTimeUtc.ToString('o')}else{$null}
        publisher=[ordered]@{ company_name=if($vi){$vi.CompanyName}else{$null}; product_name=if($vi){$vi.ProductName}else{$null}; product_version=if($vi){$vi.ProductVersion}else{$null}; file_version=if($vi){$vi.FileVersion}else{$null}; legal_copyright=if($vi){$vi.LegalCopyright}else{$null} }
        signature=[ordered]@{ status=if($sig){$sig.Status.ToString()}else{'unavailable'}; status_message=if($sig){$sig.StatusMessage}else{$null}; signer_subject=if($cert){$cert.Subject}else{$null}; signer_issuer=if($cert){$cert.Issuer}else{$null}; signer_thumbprint=if($cert){$cert.Thumbprint}else{$null}; not_before_utc=if($cert){$cert.NotBefore.ToUniversalTime().ToString('o')}else{$null}; not_after_utc=if($cert){$cert.NotAfter.ToUniversalTime().ToString('o')}else{$null} }
        download_origin=$null; build_recipe=$null; sbom=$null; license=$null; candidate_ref=$null; authority_ref=$null; provenance_absence_code='PROVENANCE_ATTESTATION_NOT_SUPPLIED'; provenance_owner='publisher/distributor or environment owner'; authoritative_source='signed publisher provenance ledger'; recovery_condition='Provide independently verifiable origin, build recipe, SBOM, license, signature/trust chain and candidate import binding.'
    }
}

$binaryObservations = @(
    (BinaryObservation 'git' $git $gitVersion),
    (BinaryObservation 'julia' $julia $juliaVersion),
    (BinaryObservation 'python' $python $pythonVersion),
    (BinaryObservation 'openssl' $openssl $opensslVersion)
)

$machine = [ordered]@{
    schema='UP1.R2.machine-observation.v1'; task_id='UP1-EXTERNAL-BLOCKER-CLOSURE-R2/W3-10-environment-capture'; observation_status='local_observation_only'; claim_ceiling='preparation_only/screen_only'; observed_utc=(& $utcNow); cwd=(Get-Location).Path; os=[ordered]@{ caption=(Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption; version=[Environment]::OSVersion.Version.ToString(); build=(Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).BuildNumber; platform=$([Environment]::OSVersion.Platform.ToString()); architecture=$env:PROCESSOR_ARCHITECTURE; process_architecture=$env:PROCESSOR_ARCHITEW6432; computer_name=$env:COMPUTERNAME }; locale=(Get-Culture).Name; timezone=(Get-TimeZone).Id; git=[ordered]@{ executable=$git; head=((Get-Content -Raw (Join-Path $raw 'git_head.stdout.raw')).Trim()); raw_command_record='raw/git_head.*'; status_sha256=$gitStatus.raw.stdout_sha256; dirty_patch_sha256=(Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes(''))) -Algorithm SHA256).Hash.ToLowerInvariant(); note='status and raw patch receipts are recorded; patch digest is finalized in manifest from raw outputs.' }; interpreters=[ordered]@{ julia=$julia; python=$python }; command_records=$records }
$machine.git.dirty_patch_sha256 = Sha256 (Join-Path $raw 'git_diff_binary.stdout.raw')
$machine.git.cached_diff_sha256 = Sha256 (Join-Path $raw 'git_diff_cached_binary.stdout.raw')
$machine.git.dirty_patch_digest = [ordered]@{algorithm='SHA-256'; input_path='raw/git_diff_binary.stdout.raw'; input_bytes='exact raw bytes'; raw_sha256=$machine.git.dirty_patch_sha256; normalized_sha256=$null; normalization='none'; purpose='dirty worktree receipt over the exact captured unstaged git diff bytes'}
Json $machine (Join-Path $root 'machine_observation.json')

$binary = [ordered]@{ schema='UP1.R2.binary-inventory.v1'; task_id=$machine.task_id; status='observed_not_candidate_bound'; observed_utc=(& $utcNow); candidate_ref=$null; authority_ref=[ordered]@{state='typed_absent';value=$null}; binaries=$binaryObservations; up1_lightweight_chain_interpreters=@($binaryObservations | Where-Object { $_.name -in @('julia','python') }); policy=[ordered]@{local_file_hash_and_authenticode_are_observation_only=$true; missing_origin_recipe_sbom_license_or_candidate_binding='typed_absent'; no_download_or_install=true} ; command_records=$records | Where-Object { $_.name -match 'version$|runtime_sys' } }
Json $binary (Join-Path $root 'binary_inventory.json')

$dep = [ordered]@{ schema='UP1.R2.dependency-closure.v1'; task_id=$machine.task_id; status='typed_absent'; claim_ceiling='preparation_only/screen_only'; observed_utc=(& $utcNow); candidate_ref=$null; authority_ref=[ordered]@{state='typed_absent';value=$null}; lock_files=$lockRecords; observed_runtime_commands=@($juliaDeps,$pythonDeps,$juliaSys,$pythonSys) | Where-Object { $_ }; import_closure=[ordered]@{status='typed_absent'; entries=@(); absence_code='CANDIDATE_IMPORT_CLOSURE_NOT_BOUND'; owner='execution/provider owner'; authoritative_source='candidate-bound import manifest'; recovery_condition='Bind every imported module/package path and hash for the exact candidate.'}; package_closure=[ordered]@{status='observed_local_only'; source='Julia Pkg.status and python pip list raw outputs'; candidate_bound=$false}; module_paths=[ordered]@{status='observed_local_only'; candidate_bound=$false; source='Julia LOAD_PATH and Python sys.path raw outputs'}; artifact_closure=[ordered]@{status='typed_absent'; entries=@(); absence_code='CANDIDATE_ARTIFACT_CLOSURE_NOT_BOUND'; owner='execution/provider owner'; authoritative_source='candidate artifact ledger'; recovery_condition='Bind all runtime artifacts and inputs.'}; command_records=$records | Where-Object { $_.name -match 'lock_file|pkg_status|pip_list|runtime_sys' } }
Json $dep (Join-Path $root 'dependency_closure.json')

$gaps = @(
    [ordered]@{code='CANDIDATE_ENVIRONMENT_NOT_FROZEN'; state='typed_absent'; owner='execution environment owner'; authoritative_source='candidate-bound environment receipt'; recovery_condition='Freeze exact candidate environment values or an approved deterministic redaction ledger.'},
    [ordered]@{code='CANDIDATE_IMPORT_CLOSURE_NOT_BOUND'; state='typed_absent'; owner='execution/provider owner'; authoritative_source='candidate-bound import manifest'; recovery_condition='Record every imported source/module/package path and hash for the exact UP1 candidate.'},
    [ordered]@{code='EXTERNAL_BINARY_PROVENANCE_NOT_ATTESTED'; state='typed_absent'; owner='publisher/distributor or environment owner'; authoritative_source='signed publisher provenance/SBOM/license ledger'; recovery_condition='Supply verifiable origin, build recipe, SBOM, license and trust-chain evidence for every imported binary/library.'},
    [ordered]@{code='TRUST_ROOT_NOT_SUPPLIED'; state='typed_absent'; owner='external authority/PKI owner'; authoritative_source='external trust-root and signed attestation package'; recovery_condition='Provide fresh issuer, key, certificate, revocation, trusted-time and anti-replay evidence.'},
    [ordered]@{code='CANDIDATE_ARTIFACT_CLOSURE_NOT_BOUND'; state='typed_absent'; owner='execution/provider owner'; authoritative_source='candidate artifact ledger'; recovery_condition='Bind runtime artifacts and inputs to candidate/evidence hashes.'},
    [ordered]@{code='NO_AUTHORITY_FROM_LOCAL_OBSERVATION'; state='typed_absent'; owner='Sol/external authority'; authoritative_source='independent external authority receipt'; recovery_condition='Do not promote local OS, hash, Authenticode or package observations without independent authority and candidate binding.'}
)
$authority = [ordered]@{schema='UP1.R2.authority-gaps.v1'; task_id=$machine.task_id; status='terminal_deferred'; claim_ceiling='preparation_only/screen_only'; observed_utc=(& $utcNow); candidate_ref=$null; gaps=$gaps; interpretation='Local observations are retained as facts of this audit only. Missing or unverifiable provenance remains typed_absent; no authority, candidate, provider, mesh, solver, engineering, physical, B00, B04, UP1 or R credit is claimed.'}
Json $authority (Join-Path $root 'authority_gaps.json')

$primary = @('machine_observation.json','binary_inventory.json','dependency_closure.json','authority_gaps.json')
$rawFiles = Get-ChildItem -LiteralPath $raw -File | Where-Object { $_.Name -notlike 'collect_environment.ps1' } | Sort-Object FullName
$allowed = @($primary + @($rawFiles | ForEach-Object { 'raw/' + $_.Name }) + 'raw/collect_environment.ps1' | Sort-Object -Unique)
$hashMap = [ordered]@{}
foreach ($rel in $allowed) { $full=Join-Path $root $rel; if(Test-Path -LiteralPath $full -PathType Leaf){$hashMap[$rel]=Sha256 $full} }
$manifest = [ordered]@{schema='UP1.R2.environment-capture.manifest.v1'; task_id=$machine.task_id; work_order='W3 / 10-environment-capture'; status='completed_review_pending'; claim_ceiling='preparation_only/screen_only'; write_root='docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/10-environment-capture/'; observed_utc=(& $utcNow); base_commit=((Get-Content -Raw (Join-Path $raw 'git_head.stdout.raw')).Trim()); writable_paths=@('docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/10-environment-capture/**'); forbidden=@('source mutation','test mutation','registry mutation','shared-doc mutation','installation','download','secret access','validator implementation','Julia/DESC/mesh/solver execution'); exact_file_set=@($allowed + 'cleanup_inventory.json' | Sort-Object -Unique); artifact_sha256=$hashMap; command_records=$records; source_observation=[ordered]@{status='local_observation_only'; git_status_sha256=$gitStatus.raw.stdout_sha256; dirty_patch_sha256=$machine.git.dirty_patch_sha256; note='Do not reinterpret as trusted provenance.'}; status_credit=[ordered]@{UP1=$false;B00=$false;B04=$false;provider=$false;mesh=$false;solver=$false;engineering=$false;physical=$false;R01_R10=$false;L4=$false;parent_goal=$false}; no_install_or_download=$true; no_secret_access=$true; self_hash_policy='manifest and cleanup_inventory self-hashes excluded'}
Json $manifest (Join-Path $root 'manifest.json')

$after = Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName
$cleanupRows = foreach ($f in $after) { $rel=$f.FullName.Substring($root.Length+1).Replace('\','/'); [ordered]@{path=$rel; owner='W3/10-environment-capture'; category=if($rel -like 'raw/*'){'raw_receipt_or_collector'}else{'declared_output'}; before_exists=$false; after_exists=$true; before_sha256=$null; after_sha256=Sha256 $f.FullName; action='retain'; reason='declared capture output or mandatory raw/evidence receipt'} }
$cleanup = [ordered]@{schema='UP1.R2.cleanup-inventory.v1'; task_id=$machine.task_id; status='no_cleanup_required'; observed_utc=(& $utcNow); root=$root; exact_owned_set=@($cleanupRows.path); entries=$cleanupRows; self_hash_excluded=$true; note='No pre-existing R2 files were overwritten; collector is retained under raw/ to make the command reproducible.'}
Json $cleanup (Join-Path $root 'cleanup_inventory.json')
