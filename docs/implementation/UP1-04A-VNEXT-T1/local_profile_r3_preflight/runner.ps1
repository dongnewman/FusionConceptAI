[CmdletBinding()]
param([ValidateRange(1,86400)][int]$TimeoutSeconds = 300)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot '..\..\..\..')).Path
$manifestPath = Join-Path $scriptRoot 'manifest.json'
$lockPath = Join-Path $scriptRoot 'runtime.lock'
$commandText = 'julia --startup-file=no --history-file=no --project=. test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_tests.jl'
$enc = New-Object System.Text.UTF8Encoding -ArgumentList $false
$timeoutMs = [int]($TimeoutSeconds * 1000)

function Write-JsonFile { param([string]$Path,[Parameter(Mandatory=$true)]$Value)
    $json = if ($Value -is [array] -and $Value.Count -eq 0) { '[]' } else { $Value | ConvertTo-Json -Depth 16 }
    [IO.File]::WriteAllText($Path,$json + [Environment]::NewLine,$enc)
}
function Write-TextFile { param([string]$Path,[AllowNull()][string]$Value)
    [IO.File]::WriteAllText($Path,($(if ($null -eq $Value) { '' } else { $Value })),$enc)
}
function Fail { param([string]$Message)
    if ($null -eq $script:failureReason) { $script:failureReason = $Message } else { $script:failureReason += '; ' + $Message }
}
function JuliaDesc { @(
    Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object { $_.Name -match '(?i)^(julia(?:-debug)?|desc)(?:\.exe)?$' } |
      ForEach-Object { [ordered]@{name=[string]$_.Name;processId=[int]$_.ProcessId;parentProcessId=[int]$_.ParentProcessId;commandLine=[string]$_.CommandLine} }
) }
function DescendantIds { param([int]$Root)
    $all=@(Get-CimInstance Win32_Process -ErrorAction Stop); $seen=@{}; $seen[$Root]=$true
    function Walk { param([int]$Parent)
        foreach ($row in @($all | Where-Object { [int]$_.ParentProcessId -eq $Parent })) {
            $id=[int]$row.ProcessId; if (-not $seen.ContainsKey($id)) { $seen[$id]=$true; Walk $id }
        }
    }
    Walk $Root; @($seen.Keys | Where-Object { [int]$_ -ne $Root } | ForEach-Object { [int]$_ })
}
function Stop-Tree { param([int]$Root)
    $ids=@(); $errors=@()
    try { $ids=@(DescendantIds $Root) } catch { $errors += 'descendant enumeration failed: ' + $_.Exception.ToString() }
    $kill=@($ids + $Root | Select-Object -Unique | Sort-Object -Descending)
    foreach ($id in $kill) { try { Stop-Process -Id ([int]$id) -Force -ErrorAction Stop } catch { $errors += "kill $id failed: $($_.Exception.Message)" } }
    [ordered]@{rootProcessId=$Root;attemptedProcessIds=@($kill);errors=@($errors)}
}
function OwnedHashes { param($Files)
    $out=[ordered]@{}
    foreach ($entry in $Files) {
        $relative=[string]$entry.path; $full=Join-Path $repoRoot $relative
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Protected file is missing: $relative" }
        $out[$relative]=((Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash).ToLowerInvariant()
    }
    $out
}
function HashesValid { param($Before,$After,$Files)
    if ($Before.Count -ne $Files.Count -or $After.Count -ne $Files.Count -or $Files.Count -lt 1) { return $false }
    $expected=@($Files | ForEach-Object {[string]$_.path} | Sort-Object -Unique)
    $bk=@($Before.Keys | Sort-Object); $ak=@($After.Keys | Sort-Object)
    if ($expected.Count -ne $Files.Count -or $bk.Count -ne $Files.Count -or $ak.Count -ne $Files.Count) { return $false }
    if ((Compare-Object $expected $bk) -ne $null -or (Compare-Object $expected $ak) -ne $null) { return $false }
    foreach ($key in $expected) { if ([string]$Before[$key] -notmatch '^[0-9a-f]{64}$' -or [string]$After[$key] -notmatch '^[0-9a-f]{64}$') { return $false } }
    $true
}
function HashChanges { param($Before,$After,$Files)
    $out=[ordered]@{}; foreach ($entry in $Files) { $p=[string]$entry.path; if ([string]$Before[$p] -ne [string]$After[$p]) { $out[$p]=[ordered]@{before=[string]$Before[$p];after=[string]$After[$p]} } }; $out
}
function Drain { param($Task)
    if (-not $Task.Wait(10000)) { throw 'Redirected stream did not drain within bounded wait' }; $Task.GetAwaiter().GetResult()
}

$lockStream=$null; $runDir=$null
try {
    if (Test-Path -LiteralPath $lockPath) { throw "Existing runtime lock refuses overwrite: $lockPath" }
    $lockStream=[IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    if (@(Get-ChildItem -LiteralPath $scriptRoot -Directory -Filter 'run_*' -ErrorAction Stop).Count -ne 0) { throw 'Existing runtime receipt directory refuses overwrite' }
    $runDir=Join-Path $scriptRoot ('run_' + (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff') + '_' + [Guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($runDir) | Out-Null
} catch {
    if ($null -ne $lockStream) {$lockStream.Dispose()}; Write-Error $_.Exception.ToString(); exit 2
}

$failureReason=$null; $status='capture_failure'; $runnerExitCode=1; $executionStarted=$false; $startCount=0
$timedOut=$false; $process=$null; $processId=$null; $exitCode=$null; $startedAt=$null; $endedAt=$null; $durationMs=$null
$pre=@(); $post1=@(); $post2=@(); $postError=$null; $files=@(); $before=[ordered]@{}; $after=[ordered]@{}; $changes=[ordered]@{}
$comparable=$false; $unchanged=$false; $stdout=''; $stderr=''; $stdoutTask=$null; $stderrTask=$null; $streamsCaptured=$false; $killRecord=$null
try {
    $manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json; $files=@($manifest.protected_files)
    if ($files.Count -lt 1) { throw 'Manifest has no protected files' }
    if (@($files | ForEach-Object {[string]$_.path} | Sort-Object -Unique).Count -ne $files.Count) { throw 'Protected paths are not unique' }
    $pre=@(JuliaDesc); Write-JsonFile (Join-Path $runDir 'processes_before.json') $pre
    if ($pre.Count -ne 0) { throw 'Preflight found Julia/DESC process; no invocation was attempted' }
    $before=OwnedHashes $files; Write-JsonFile (Join-Path $runDir 'owned_hashes_before.json') $before
    if (-not (HashesValid $before $before $files)) { throw 'Preflight hash set is not comparable' }
    foreach ($entry in $files) { $p=[string]$entry.path; if ([string]$before[$p] -ne ([string]$entry.sha256).ToLowerInvariant()) { throw "Frozen SHA-256 mismatch before execution: $p" } }
    $env:JULIA_NUM_THREADS='1'; $startedAt=(Get-Date).ToUniversalTime()
    $psi=New-Object Diagnostics.ProcessStartInfo; $psi.FileName='julia'; $psi.Arguments='--startup-file=no --history-file=no --project=. test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_tests.jl'; $psi.WorkingDirectory=$repoRoot; $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true; $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
    $process=New-Object Diagnostics.Process; $process.StartInfo=$psi
    if (-not $process.Start()) { throw 'Julia process did not start' }
    $startCount=1; $executionStarted=$true; $processId=$process.Id
    $stdoutTask=$process.StandardOutput.ReadToEndAsync(); $stderrTask=$process.StandardError.ReadToEndAsync(); $completed=$process.WaitForExit($timeoutMs)
    if (-not $completed) { $timedOut=$true; $status='timeout'; Fail "Julia process exceeded timeoutSeconds=$TimeoutSeconds"; $killRecord=Stop-Tree ([int]$processId); [void]$process.WaitForExit(5000) } else { [void]$process.WaitForExit() }
    $stdout=Drain $stdoutTask; $stderr=Drain $stderrTask; $streamsCaptured=$true; $exitCode=[int]$process.ExitCode; $endedAt=(Get-Date).ToUniversalTime(); $durationMs=($endedAt-$startedAt).TotalMilliseconds
    if (-not $timedOut) { if ($exitCode -eq 0) {$status='runtime_complete';$runnerExitCode=0} else {$status='child_nonzero';Fail "Julia exited with code $exitCode"} }
} catch {
    Fail $_.Exception.ToString(); if ($timedOut) {$status='timeout'} elseif (-not $executionStarted) {$status='preflight_failure'} else {$status='capture_failure'}
} finally {
    if ($null -ne $process -and $executionStarted -and -not $streamsCaptured) { try {$stdout=Drain $stdoutTask;$stderr=Drain $stderrTask;$streamsCaptured=$true} catch {Fail ('stdout/stderr capture failed: '+$_.Exception.ToString());$status='capture_failure'} }
    if ($null -ne $process) {$process.Dispose()}; Write-TextFile (Join-Path $runDir 'julia.stdout.raw') $stdout; Write-TextFile (Join-Path $runDir 'julia.stderr.raw') $stderr
    try {$post1=@(JuliaDesc)} catch {$postError=$_.Exception.ToString();Fail ('postflight first process inspection failed: '+$postError)}; Write-JsonFile (Join-Path $runDir 'processes_after_first.json') $post1; Start-Sleep -Milliseconds 250
    try {$post2=@(JuliaDesc)} catch {$postError=$_.Exception.ToString();Fail ('postflight second process inspection failed: '+$postError)}; Write-JsonFile (Join-Path $runDir 'processes_after_second.json') $post2
    try {$after=OwnedHashes $files} catch {Fail ('postflight hash inspection failed: '+$_.Exception.ToString());$after=[ordered]@{}}; Write-JsonFile (Join-Path $runDir 'owned_hashes_after.json') $after
    $comparable=HashesValid $before $after $files; if ($comparable) {$changes=HashChanges $before $after $files} else {Fail 'hashesComparable=false'}; Write-JsonFile (Join-Path $runDir 'owned_hash_changes.json') $changes; $unchanged=$comparable -and ($changes.Count -eq 0)
    if (-not $unchanged) {Fail 'ownedFilesUnchanged=false';if ($status -ne 'timeout') {$status='postflight_failure'};$runnerExitCode=1}; $zero=($null -eq $postError -and $post1.Count -eq 0 -and $post2.Count -eq 0)
    if (-not $zero) {Fail 'postflight did not obtain two consecutive zero Julia/DESC observations';if ($status -ne 'timeout') {$status='postflight_failure'};$runnerExitCode=1}; if ($null -eq $endedAt) {$endedAt=(Get-Date).ToUniversalTime()}; if ($null -ne $startedAt) {$durationMs=($endedAt-$startedAt).TotalMilliseconds}
    Write-TextFile (Join-Path $runDir 'exit_code.txt') $(if ($null -eq $exitCode) {'NOT_CAPTURED'} else {[string]$exitCode})
    Write-JsonFile (Join-Path $runDir 'thread.json') ([ordered]@{requested='1';environment=[string]$env:JULIA_NUM_THREADS;executionStarted=$executionStarted})
    Write-JsonFile (Join-Path $runDir 'run_metadata.json') ([ordered]@{schema='T1CandidateStatePackageR3RunMetadataV1';status=$status;accepted=$false;claimCeiling='contract_only';command=$commandText;workingDirectory=$repoRoot;receiptDirectory=$runDir;lockPath=$lockPath;timeoutSeconds=$TimeoutSeconds;timeoutClassified=$timedOut;timeoutKillReceipt='conditional';startedOnce=($startCount -eq 1);startCount=$startCount;executionStarted=$executionStarted;processId=$processId;exitCode=$exitCode;startedAtUtc=$startedAt;endedAtUtc=$endedAt;durationMs=$durationMs;juliaNumThreads=[string]$env:JULIA_NUM_THREADS;preflightProcessCount=$pre.Count;postflightFirstProcessCount=$post1.Count;postflightSecondProcessCount=$post2.Count;postflightZeroJuliaDesc=$zero;hashesComparable=$comparable;ownedFileCount=$files.Count;ownedFilesUnchanged=$unchanged;streamsCaptured=$streamsCaptured;autoRetry=$false;failure=$failureReason;killRecord=$killRecord})
    Write-JsonFile (Join-Path $runDir 'capture_failure.json') ([ordered]@{schema='T1CandidateStatePackageR3CaptureFailureV1';status=$status;accepted=$false;claimCeiling='contract_only';captureFailure=($status -eq 'capture_failure');timeout=$timedOut;timeoutKillReceipt='conditional';failure=$failureReason;receiptDirectory=$runDir}); if ($null -ne $killRecord) {Write-JsonFile (Join-Path $runDir 'timeout_kill.json') $killRecord}; if ($null -ne $lockStream) {$lockStream.Dispose()}
}
if ($runnerExitCode -ne 0) {exit 1}; exit 0
