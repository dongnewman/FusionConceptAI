[CmdletBinding()]
param(
    [ValidateRange(1, 86400)]
    [int]$TimeoutSeconds = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot '..\..\..\..')).Path
$manifestPath = Join-Path $scriptRoot 'manifest.json'
$lockPath = Join-Path $scriptRoot 'runtime.lock'
$commandText = 'julia --startup-file=no --history-file=no --project=. test/GenomeV5/Integration/VNextT1CandidateBindingV2/vnext_t1_candidate_binding_v2_tests.jl'
$utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
$timeoutMs = [int]($TimeoutSeconds * 1000)
$runnerExpectedBytes = 16534
$runnerExpectedCanonicalSha256 = '2747220c3b555bd74bf204f1152f20e040ee340a1dd520f67ff51f82193db9c4'

function Assert-RunnerSelfContract {
    $path = Join-Path $scriptRoot 'runner.ps1'
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes.Length -ne $runnerExpectedBytes) { throw "Runner self byte-size mismatch: expected $runnerExpectedBytes, observed $($bytes.Length)" }
    $text = $utf8NoBom.GetString($bytes)
    $canonical = $text.Replace($runnerExpectedCanonicalSha256, ('0' * 64))
    $hash = ([Security.Cryptography.SHA256]::Create().ComputeHash($utf8NoBom.GetBytes($canonical)) | ForEach-Object { $_.ToString('x2') }) -join ''
    if ($hash -ne $runnerExpectedCanonicalSha256) { throw "Runner self canonical SHA-256 mismatch: expected $runnerExpectedCanonicalSha256, observed $hash" }
}

try { Assert-RunnerSelfContract } catch { Write-Error $_.Exception.ToString(); exit 2 }

function Write-JsonFile {
    param([string]$Path, $Value)
    $json = if ($Value -is [array] -and $Value.Count -eq 0) { '[]' } else { $Value | ConvertTo-Json -Depth 20 }
    [IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8NoBom)
}
function Write-TextFile {
    param([string]$Path, [AllowNull()][string]$Value)
    [IO.File]::WriteAllText($Path, $(if ($null -eq $Value) { '' } else { $Value }), $utf8NoBom)
}
function Add-Failure { param([string]$Message); if ($null -eq $script:failureReason) { $script:failureReason = $Message } else { $script:failureReason += '; ' + $Message } }

function Get-JuliaDescProcesses {
    @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object { $_.Name -match '(?i)^(julia(?:-debug)?|desc)(?:\.exe)?$' } | ForEach-Object {
        [ordered]@{ name = [string]$_.Name; processId = [int]$_.ProcessId; parentProcessId = [int]$_.ParentProcessId; commandLine = [string]$_.CommandLine }
    })
}
function Get-DescendantIds {
    param([int]$RootProcessId)
    $all = @(Get-CimInstance Win32_Process -ErrorAction Stop); $seen = @{}; $seen[$RootProcessId] = $true
    function Visit { param([int]$ParentId); foreach ($row in @($all | Where-Object { [int]$_.ParentProcessId -eq $ParentId })) { $id = [int]$row.ProcessId; if (-not $seen.ContainsKey($id)) { $seen[$id] = $true; Visit $id } } }
    Visit $RootProcessId
    @($seen.Keys | Where-Object { [int]$_ -ne $RootProcessId } | ForEach-Object { [int]$_ })
}
function Stop-OwnedTree {
    param([int]$RootProcessId)
    $ids = @(); $errors = @()
    try { $ids = @(Get-DescendantIds $RootProcessId) } catch { $errors += 'descendant enumeration failed: ' + $_.Exception.ToString() }
    $killIds = @($ids + $RootProcessId | Select-Object -Unique | Sort-Object -Descending)
    foreach ($id in $killIds) { try { Stop-Process -Id ([int]$id) -Force -ErrorAction Stop } catch { $errors += "kill $id failed: $($_.Exception.Message)" } }
    [ordered]@{ rootProcessId = $RootProcessId; attemptedProcessIds = @($killIds); errors = @($errors) }
}
function Get-OwnedHashes {
    param($ProtectedFiles)
    $hashes = [ordered]@{}
    foreach ($entry in $ProtectedFiles) {
        $path = [string]$entry.path; $full = Join-Path $repoRoot $path
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Protected file is missing: $path" }
        $item = Get-Item -LiteralPath $full
        $hashes[$path] = [ordered]@{ bytes = [int64]$item.Length; sha256 = ((Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash).ToLowerInvariant() }
    }
    $hashes
}
function Test-HashesComparable {
    param($Before, $After, $ProtectedFiles)
    if ($Before.Count -ne $ProtectedFiles.Count -or $After.Count -ne $ProtectedFiles.Count -or $ProtectedFiles.Count -lt 1) { return $false }
    $expected = @($ProtectedFiles | ForEach-Object { [string]$_.path } | Sort-Object -Unique)
    $beforeKeys = @($Before.Keys | Sort-Object); $afterKeys = @($After.Keys | Sort-Object)
    if ($expected.Count -ne $ProtectedFiles.Count -or $beforeKeys.Count -ne $ProtectedFiles.Count -or $afterKeys.Count -ne $ProtectedFiles.Count) { return $false }
    if ((Compare-Object $expected $beforeKeys) -ne $null -or (Compare-Object $expected $afterKeys) -ne $null) { return $false }
    foreach ($path in $expected) { if ([string]$Before[$path].sha256 -notmatch '^[0-9a-f]{64}$' -or [string]$After[$path].sha256 -notmatch '^[0-9a-f]{64}$') { return $false } }
    $true
}
function Compare-OwnedHashes {
    param($Before, $After, $ProtectedFiles)
    $changes = [ordered]@{}
    foreach ($entry in $ProtectedFiles) {
        $path = [string]$entry.path
        if ([string]$Before[$path].sha256 -ne [string]$After[$path].sha256 -or [int64]$Before[$path].bytes -ne [int64]$After[$path].bytes) {
            $changes[$path] = [ordered]@{ before = [ordered]@{ bytes = [int64]$Before[$path].bytes; sha256 = [string]$Before[$path].sha256 }; after = [ordered]@{ bytes = [int64]$After[$path].bytes; sha256 = [string]$After[$path].sha256 } }
        }
    }
    $changes
}
function Read-StreamTask { param($Task); if (-not $Task.Wait(10000)) { throw 'Redirected stream did not drain within bounded wait' }; $Task.GetAwaiter().GetResult() }
function Read-ReplayFields {
    param([string]$Text, [string]$Label)
    $pattern = '(?m)^VNEXT_T1_CANDIDATE_BINDING_V2_REPLAY schema=(?<schema>\S+) version=(?<version>\S+) status=(?<status>\S+) candidate_digest=(?<candidate_digest>\S+) wire_hash=(?<wire_hash>\S+) receipt_hash=(?<receipt_hash>\S+)\s*$'
    $m = [regex]::Match($Text, $pattern)
    if (-not $m.Success) { throw "$Label stdout lacks the exact replay fingerprint line" }
    [ordered]@{ schema = $m.Groups['schema'].Value; version = $m.Groups['version'].Value; status = $m.Groups['status'].Value; candidate_digest = $m.Groups['candidate_digest'].Value; wire_hash = $m.Groups['wire_hash'].Value; receipt_hash = $m.Groups['receipt_hash'].Value }
}
function Assert-24Summary { param([string]$Text, [string]$Label); if (-not [regex]::IsMatch($Text, '(?m)^VNext T1 V2 explicit candidate binding\s+\|\s+24\s+24\s+')) { throw "$Label stdout lacks the required 24/24 test summary" } }

$lockStream = $null; $runDir = $null
try {
    if (Test-Path -LiteralPath $lockPath) { throw "Existing runtime lock refuses overwrite: $lockPath" }
    $lockStream = [IO.File]::Open($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    if (@(Get-ChildItem -LiteralPath $scriptRoot -Directory -Filter 'run_*' -ErrorAction Stop).Count -ne 0) { throw 'Existing runtime receipt directory refuses overwrite' }
    $runDir = Join-Path $scriptRoot ('run_' + (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff') + '_' + [Guid]::NewGuid().ToString('N'))
    if (Test-Path -LiteralPath $runDir) { throw "Receipt directory collision refuses overwrite: $runDir" }
    [IO.Directory]::CreateDirectory($runDir) | Out-Null
} catch { if ($null -ne $lockStream) { $lockStream.Dispose() }; Write-Error $_.Exception.ToString(); exit 2 }

$failureReason = $null; $status = 'capture_failure'; $runnerExitCode = 1; $executionStarted = $false; $startCount = 0; $timedOut = $false
$process = $null; $processId = $null; $exitCode = $null; $startedAt = $null; $endedAt = $null; $durationMs = $null
$pre = @(); $post1 = @(); $post2 = @(); $postError = $null; $files = @(); $before = [ordered]@{}; $after = [ordered]@{}; $changes = [ordered]@{}
$comparable = $false; $unchanged = $false; $stdout = ''; $stderr = ''; $stdoutTask = $null; $stderrTask = $null; $streamsCaptured = $false; $killRecord = $null
$replayExact = $false; $r2Fields = [ordered]@{}; $r3Fields = [ordered]@{}; $r2StdoutPath = $null

try {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $files = @($manifest.protected_files)
    if ($files.Count -lt 1) { throw 'Manifest has no protected files' }
    if (@($files | ForEach-Object { [string]$_.path } | Sort-Object -Unique).Count -ne $files.Count) { throw 'Protected paths are not unique' }
    $pre = @(Get-JuliaDescProcesses); Write-JsonFile (Join-Path $runDir 'processes_before.json') $pre
    if ($pre.Count -ne 0) { throw 'Preflight found Julia/DESC process; no invocation was attempted' }
    $before = Get-OwnedHashes $files; Write-JsonFile (Join-Path $runDir 'owned_hashes_before.json') $before
    if (-not (Test-HashesComparable $before $before $files)) { throw 'Preflight hash set is not comparable' }
    foreach ($entry in $files) { $path = [string]$entry.path; if ([int64]$before[$path].bytes -ne [int64]$entry.bytes -or [string]$before[$path].sha256 -ne ([string]$entry.sha256).ToLowerInvariant()) { throw "Frozen byte/hash mismatch before execution: $path" } }
    $r2StdoutPath = Join-Path $repoRoot ([string]$manifest.r2_reference.stdout_path)
    if (-not (Test-Path -LiteralPath $r2StdoutPath -PathType Leaf)) { throw 'R2 stdout receipt is missing' }
    $r2Raw = [IO.File]::ReadAllBytes($r2StdoutPath); $r2Hash = ((Get-FileHash -LiteralPath $r2StdoutPath -Algorithm SHA256).Hash).ToLowerInvariant()
    if ($r2Raw.Length -ne [int64]$manifest.r2_reference.stdout_bytes -or $r2Hash -ne ([string]$manifest.r2_reference.stdout_sha256).ToLowerInvariant()) { throw 'R2 stdout receipt hash/size mismatch' }
    $r2Fields = Read-ReplayFields ($utf8NoBom.GetString($r2Raw)) 'R2'; Assert-24Summary ($utf8NoBom.GetString($r2Raw)) 'R2'
    $r2MetaPath = Join-Path $repoRoot ([string]$manifest.r2_reference.metadata_path); $r2Meta = Get-Content -LiteralPath $r2MetaPath -Raw | ConvertFrom-Json
    if ([string]$r2Meta.status -ne 'runtime_complete' -or [int]$r2Meta.exitCode -ne 0 -or [string]$r2Meta.juliaNumThreads -ne '1') { throw 'R2 receipt is not a complete threads=1 runtime receipt' }
    $env:JULIA_NUM_THREADS = '1'; $startedAt = (Get-Date).ToUniversalTime()
    $psi = New-Object Diagnostics.ProcessStartInfo; $psi.FileName = 'julia'; $psi.Arguments = '--startup-file=no --history-file=no --project=. test/GenomeV5/Integration/VNextT1CandidateBindingV2/vnext_t1_candidate_binding_v2_tests.jl'; $psi.WorkingDirectory = $repoRoot; $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process; $process.StartInfo = $psi; if (-not $process.Start()) { throw 'Julia process did not start' }
    $startCount = 1; $executionStarted = $true; $processId = $process.Id; $stdoutTask = $process.StandardOutput.ReadToEndAsync(); $stderrTask = $process.StandardError.ReadToEndAsync(); $completed = $process.WaitForExit($timeoutMs)
    if (-not $completed) { $timedOut = $true; $status = 'timeout'; Add-Failure "Julia process exceeded timeoutSeconds=$TimeoutSeconds"; $killRecord = Stop-OwnedTree ([int]$processId); [void]$process.WaitForExit(5000) } else { [void]$process.WaitForExit() }
    $stdout = Read-StreamTask $stdoutTask; $stderr = Read-StreamTask $stderrTask; $streamsCaptured = $true; $exitCode = [int]$process.ExitCode; $endedAt = (Get-Date).ToUniversalTime(); $durationMs = ($endedAt - $startedAt).TotalMilliseconds
    if (-not $timedOut) {
        if ($exitCode -eq 0) { $r3Fields = Read-ReplayFields $stdout 'R3'; Assert-24Summary $stdout 'R3'; $replayExact = $true; foreach ($key in @('schema','version','status','candidate_digest','wire_hash','receipt_hash')) { if ([string]$r3Fields[$key] -cne [string]$r2Fields[$key]) { $replayExact = $false } }; if (-not $replayExact) { $status = 'replay_mismatch'; Add-Failure 'R3 stdout fingerprint differs from R2 stdout' } else { $status = 'runtime_complete'; $runnerExitCode = 0 } } else { $status = 'child_nonzero'; Add-Failure "Julia exited with code $exitCode" }
    }
} catch { Add-Failure $_.Exception.ToString(); if ($timedOut) { $status = 'timeout' } elseif (-not $executionStarted) { $status = 'preflight_failure' } else { $status = 'capture_failure' } }
finally {
    if ($null -ne $process -and $executionStarted -and -not $streamsCaptured) { try { $stdout = Read-StreamTask $stdoutTask; $stderr = Read-StreamTask $stderrTask; $streamsCaptured = $true } catch { Add-Failure ('stdout/stderr capture failed: ' + $_.Exception.ToString()); $status = 'capture_failure' } }
    if ($null -ne $process) { $process.Dispose() }
    Write-TextFile (Join-Path $runDir 'julia.stdout.raw') $stdout; Write-TextFile (Join-Path $runDir 'julia.stderr.raw') $stderr
    try { $post1 = @(Get-JuliaDescProcesses) } catch { $postError = $_.Exception.ToString(); Add-Failure ('postflight first process inspection failed: ' + $postError) }; Write-JsonFile (Join-Path $runDir 'processes_after_first.json') $post1
    Start-Sleep -Milliseconds 250
    try { $post2 = @(Get-JuliaDescProcesses) } catch { $postError = $_.Exception.ToString(); Add-Failure ('postflight second process inspection failed: ' + $postError) }; Write-JsonFile (Join-Path $runDir 'processes_after_second.json') $post2
    try { $after = Get-OwnedHashes $files } catch { Add-Failure ('postflight hash inspection failed: ' + $_.Exception.ToString()); $after = [ordered]@{} }; Write-JsonFile (Join-Path $runDir 'owned_hashes_after.json') $after
    $comparable = Test-HashesComparable $before $after $files; if ($comparable) { $changes = Compare-OwnedHashes $before $after $files } else { Add-Failure 'hashesComparable=false' }; Write-JsonFile (Join-Path $runDir 'owned_hash_changes.json') $changes
    $unchanged = $comparable -and ($changes.Count -eq 0); if (-not $unchanged) { Add-Failure 'ownedFilesUnchanged=false'; if ($status -ne 'timeout') { $status = 'postflight_failure' }; $runnerExitCode = 1 }
    $zero = ($null -eq $postError -and $post1.Count -eq 0 -and $post2.Count -eq 0); if (-not $zero) { Add-Failure 'postflight did not obtain two consecutive zero Julia/DESC observations'; if ($status -ne 'timeout') { $status = 'postflight_failure' }; $runnerExitCode = 1 }
    if ($null -eq $endedAt) { $endedAt = (Get-Date).ToUniversalTime() }; if ($null -ne $startedAt) { $durationMs = ($endedAt - $startedAt).TotalMilliseconds }
    Write-TextFile (Join-Path $runDir 'exit_code.txt') $(if ($null -eq $exitCode) { 'NOT_CAPTURED' } else { [string]$exitCode }); Write-JsonFile (Join-Path $runDir 'thread.json') ([ordered]@{ requested = '1'; environment = [string]$env:JULIA_NUM_THREADS; executionStarted = $executionStarted })
    Write-JsonFile (Join-Path $runDir 'run_metadata.json') ([ordered]@{ schema = 'VNextT1CandidateBindingV2R3RunMetadataV1'; status = $status; accepted = $false; claimCeiling = 'contract_only'; command = $commandText; workingDirectory = $repoRoot; receiptDirectory = $runDir; lockPath = $lockPath; r2StdoutPath = $r2StdoutPath; timeoutSeconds = $TimeoutSeconds; timeoutClassified = $timedOut; startedOnce = ($startCount -eq 1); startCount = $startCount; executionStarted = $executionStarted; processId = $processId; exitCode = $exitCode; startedAtUtc = $startedAt; endedAtUtc = $endedAt; durationMs = $durationMs; juliaNumThreads = [string]$env:JULIA_NUM_THREADS; preflightProcessCount = $pre.Count; postflightFirstProcessCount = $post1.Count; postflightSecondProcessCount = $post2.Count; postflightZeroJuliaDesc = $zero; hashesComparable = $comparable; ownedFileCount = $files.Count; ownedFilesUnchanged = $unchanged; streamsCaptured = $streamsCaptured; autoRetry = $false; replayExact = $replayExact; r2Fields = $r2Fields; r3Fields = $r3Fields; failure = $failureReason; killRecord = $killRecord })
    Write-JsonFile (Join-Path $runDir 'capture_failure.json') ([ordered]@{ schema = 'VNextT1CandidateBindingV2R3CaptureFailureV1'; status = $status; accepted = $false; claimCeiling = 'contract_only'; captureFailure = ($status -eq 'capture_failure'); timeout = $timedOut; replayExact = $replayExact; failure = $failureReason; receiptDirectory = $runDir }); if ($null -ne $killRecord) { Write-JsonFile (Join-Path $runDir 'timeout_kill.json') $killRecord }; if ($null -ne $lockStream) { $lockStream.Dispose() }
}
if ($runnerExitCode -ne 0) { exit 1 }; exit 0
