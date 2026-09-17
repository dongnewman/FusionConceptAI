param(
    [Parameter(Mandatory=$true)][ValidateSet('f0','s2')][string]$Mode,
    [Parameter(Mandatory=$true)][ValidateSet('f0','s2_run1','s2_run2')][string]$Label
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$evidence = $PSScriptRoot
$julia = (Get-Command julia.exe).Source
$probe = Join-Path $evidence 'probe_f0_s2_current_head.jl'
$stdoutPath = Join-Path $evidence ($Label + '_stdout.txt')
$stderrPath = Join-Path $evidence ($Label + '_stderr.txt')
$receiptPath = Join-Path $evidence ($Label + '_receipt.json')

function Sha256-Bytes([byte[]]$b) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($h.ComputeHash($b))).Replace('-','').ToLowerInvariant() }
    finally { $h.Dispose() }
}
function Sha256-File([string]$p) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLowerInvariant() }
function Git([string[]]$a) { return (& git -C $root @a 2>&1 | Out-String).TrimEnd() }
function ProcSnapshot {
    @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)(\.exe)?$' } | ForEach-Object { [ordered]@{pid=[int]$_.ProcessId; name=$_.Name; command_line=$_.CommandLine} })
}

$inputPaths = @(
 'docs/v4_multitopology_generation/README.md',
 'docs/v4_multitopology_generation/00_normative_contracts_and_state_model.md',
 'docs/v4_multitopology_generation/16_execution_work_orders.md',
 'docs/v4_multitopology_generation/G1 机制基因组.md',
 'docs/v4_multitopology_generation/G2 场—几何基因组.md',
 'docs/v4_multitopology_generation/G3 实现—控制Genome.md',
 'docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md',
 'docs/v4_multitopology_generation/task_manifest.json',
 'docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json',
 'docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/envelope_receipt.json',
 'src/GenomeV5/G1/DiffusionDeclarationV1.jl',
 'src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl',
 'src/GenomeV5/G3/RealizationGenomeV5.jl',
 'src/GenomeV5/G3/ControlGenomeV5.jl',
 'src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl',
 'src/GenomeV5/G3/RealizationControlGenomeV5.jl',
 'src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl',
 'src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl',
 'src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl',
 'src/GenomeV5/Integration/GenomeV5Integration.jl',
 'src/GenomeV5/UP2/UP2ModuleEntryV1.jl'
)
$inputHashes = @($inputPaths | ForEach-Object { $p=$_; $full=Join-Path $root $p; [ordered]@{path=$p; exists=(Test-Path -LiteralPath $full); sha256= if(Test-Path -LiteralPath $full){Sha256-File $full}else{$null}; bytes=if(Test-Path -LiteralPath $full){(Get-Item -LiteralPath $full).Length}else{$null}} })
$before = ProcSnapshot
if ($before.Count -gt 0) { throw "Julia/DESC process exists before serial run" }
$started = (Get-Date).ToUniversalTime().ToString('o')
if ($Mode -eq 'f0' -and -not (Test-Path (Join-Path $evidence 'baseline_snapshot.json'))) {
    $status = Git @('status','--porcelain=v1','--untracked-files=all')
    [ordered]@{task='AD-55'; captured_utc=$started; repo_root=$root; head=Git @('rev-parse','HEAD'); expected_head='b2c04d8339774635aaecd73651efcdb101e01b5d'; dirty_inventory=@($status -split "`r?`n" | Where-Object { $_ -ne '' }); input_hashes=$inputHashes; process_snapshot_before=$before; task_manifest_sha256=($inputHashes | Where-Object path -eq 'docs/v4_multitopology_generation/task_manifest.json').sha256; expected_plan=[ordered]@{task_count=31;link_count=534;task_count_current=39;acyclic=$true}} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidence 'baseline_snapshot.json') -Encoding UTF8
}

$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = $julia
$psi.Arguments = '--project="' + $root + '" "' + $probe + '" ' + $Mode
$psi.WorkingDirectory = $root
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$proc = [System.Diagnostics.Process]::new(); $proc.StartInfo = $psi
$proc.Start() | Out-Null
$realPid = $proc.Id
$outTask = $proc.StandardOutput.ReadToEndAsync(); $errTask = $proc.StandardError.ReadToEndAsync()
$proc.WaitForExit(); $stdout = $outTask.Result; $stderr = $errTask.Result
[IO.File]::WriteAllText($stdoutPath, $stdout, [Text.UTF8Encoding]::new($false)); [IO.File]::WriteAllText($stderrPath, $stderr, [Text.UTF8Encoding]::new($false))
$ended = (Get-Date).ToUniversalTime().ToString('o')
$after = ProcSnapshot
$receipt = [ordered]@{task='AD-55'; stage=$Mode; label=$Label; command=($julia + ' --project="' + $root + '" "' + $probe + '" ' + $Mode); cwd=$root; pid_or_in_process=$realPid; started_utc=$started; ended_utc=$ended; exit_code=$proc.ExitCode; stdout_raw_and_sha256=[ordered]@{path=$stdoutPath;sha256=Sha256-File $stdoutPath;bytes=(Get-Item $stdoutPath).Length}; stderr_raw_and_sha256=[ordered]@{path=$stderrPath;sha256=Sha256-File $stderrPath;bytes=(Get-Item $stderrPath).Length}; combined_raw_and_sha256=[ordered]@{sha256=Sha256-Bytes ([Text.UTF8Encoding]::new($false).GetBytes($stdout+$stderr))}; input_hashes=$inputHashes; output_hashes=@(); artifact_hashes=@(); process_snapshot_before=$before; process_snapshot_after=$after; claims=[ordered]@{candidate_identity_created=$false;final_candidate_or_package_declaration_hash_created=$false;trusted_attestation_created=$false;provider=$false;mesh=$false;solver=$false;engineering_readiness=$false;physics=$false;search=$false;R01_R10=$false;L4=0}}
$receipt | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
if ($proc.ExitCode -ne 0) { exit $proc.ExitCode }
