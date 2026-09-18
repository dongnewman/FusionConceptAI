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
$commandText = 'julia --startup-file=no --history-file=no --project=. test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_tests.jl'
$utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
$timeoutMs = [int]($TimeoutSeconds * 1000)

function Write-JsonFile {
    param([Parameter(Mandatory=$true)][string]$Path, [Parameter(Mandatory=$true)]$Value)
    if ($Value -is [array] -and $Value.Count -eq 0) { $json = '[]' }
    else { $json = $Value | ConvertTo-Json -Depth 16 }
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8NoBom)
}
function Write-TextFile {
    param([Parameter(Mandatory=$true)][string]$Path, [AllowNull()][string]$Value)
    if ($null -eq $Value) { $Value = '' }
    [System.IO.File]::WriteAllText($Path, $Value, $utf8NoBom)
}
function Add-FailureReason {
    param([Parameter(Mandatory=$true)][string]$Message)
    if ($null -eq $script:failureReason) { $script:failureReason = $Message }
    else { $script:failureReason += '; ' + $Message }
}
function Get-JuliaDescProcesses {
    @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop |
        Where-Object { $_.Name -match '(?i)^(julia(?:-debug)?|desc)(?:\.exe)?$' } |
        ForEach-Object { [ordered]@{ name=[string]$_.Name; processId=[int]$_.ProcessId; parentProcessId=[int]$_.ParentProcessId; commandLine=[string]$_.CommandLine } })
}
function Get-DescendantProcessIds {
    param([Parameter(Mandatory=$true)][int]$RootProcessId)
    $all = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
    $seen = @{}; $seen[$RootProcessId] = $true
    function Add-Children { param([int]$ParentId)
        foreach ($row in @($all | Where-Object { [int]$_.ParentProcessId -eq $ParentId })) {
            $childId = [int]$row.ProcessId
            if (-not $seen.ContainsKey($childId)) { $seen[$childId] = $true; Add-Children -ParentId $childId }
        }
    }
    Add-Children -ParentId $RootProcessId
    @($seen.Keys | Where-Object { [int]$_ -ne $RootProcessId } | ForEach-Object { [int]$_ })
}
function Stop-OwnedProcessTree {
    param([Parameter(Mandatory=$true)][int]$RootProcessId)
    $ids = @(); $errors = @()
    try { $ids = @(Get-DescendantProcessIds -RootProcessId $RootProcessId) }
    catch { $errors += 'descendant enumeration failed: ' + $_.Exception.ToString() }
    $killIds = @($ids + $RootProcessId | Select-Object -Unique | Sort-Object -Descending)
    foreach ($id in $killIds) { try { Stop-Process -Id ([int]$id) -Force -ErrorAction Stop } catch { $errors += "kill $id failed: $($_.Exception.Message)" } }
    [ordered]@{ rootProcessId=$RootProcessId; attemptedProcessIds=@($killIds); errors=@($errors) }
}
function Get-OwnedHashes {
    param([Parameter(Mandatory=$true)]$ProtectedFiles)
    $hashes = [ordered]@{}
    foreach ($entry in $ProtectedFiles) {
        $relativePath = [string]$entry.path
        $fullPath = Join-Path $repoRoot $relativePath
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "Protected file is missing: $relativePath" }
        $hashes[$relativePath] = ((Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash).ToLowerInvariant()
    }
    $hashes
}
function Test-HashesComparable {
    param([Parameter(Mandatory=$true)]$Before, [Parameter(Mandatory=$true)]$After, [Parameter(Mandatory=$true)]$ProtectedFiles)
    if ($Before.Count -ne $ProtectedFiles.Count -or $After.Count -ne $ProtectedFiles.Count -or $ProtectedFiles.Count -lt 1) { return $false }
    $expected = @($ProtectedFiles | ForEach-Object { [string]$_.path } | Sort-Object -Unique)
    $beforeKeys = @($Before.Keys | Sort-Object); $afterKeys = @($After.Keys | Sort-Object)
    if ($expected.Count -ne $ProtectedFiles.Count -or $beforeKeys.Count -ne $ProtectedFiles.Count -or $afterKeys.Count -ne $ProtectedFiles.Count) { return $false }
    if ((Compare-Object $expected $beforeKeys) -ne $null -or (Compare-Object $expected $afterKeys) -ne $null) { return $false }
    foreach ($key in $expected) { if ([string]$Before[$key] -notmatch '^[0-9a-f]{64}$' -or [string]$After[$key] -notmatch '^[0-9a-f]{64}$') { return $false } }
    $true
}
function Compare-OwnedHashes {
    param([Parameter(Mandatory=$true)]$Before, [Parameter(Mandatory=$true)]$After, [Parameter(Mandatory=$true)]$ProtectedFiles)
    $changes = [ordered]@{}
    foreach ($entry in $ProtectedFiles) {
        $p = [string]$entry.path
        if ([string]$Before[$p] -ne [string]$After[$p]) { $changes[$p] = [ordered]@{ before=[string]$Before[$p]; after=[string]$After[$p] } }
    }
    $changes
}
function Read-StreamTask {
    param([Parameter(Mandatory=$true)]$Task, [int]$WaitMilliseconds=10000)
    if (-not $Task.Wait($WaitMilliseconds)) { throw 'Redirected stream did not drain within the bounded wait' }
    $Task.GetAwaiter().GetResult()
}

$lockStream = $null; $runDir = $null
try {
    if (Test-Path -LiteralPath $lockPath) { throw "Existing runtime lock refuses overwrite: $lockPath" }
    $lockStream = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    if (@(Get-ChildItem -LiteralPath $scriptRoot -Directory -Filter 'run_*' -ErrorAction Stop).Count -ne 0) { throw 'Existing runtime receipt directory refuses overwrite' }
    $runName = 'run_' + (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff') + '_' + [Guid]::NewGuid().ToString('N')
    $runDir = Join-Path $scriptRoot $runName
    if (Test-Path -LiteralPath $runDir) { throw "Receipt directory collision refuses overwrite: $runDir" }
    [System.IO.Directory]::CreateDirectory($runDir) | Out-Null
}
catch {
    if ($null -ne $lockStream) { $lockStream.Dispose() }
    Write-Error $_.Exception.ToString(); exit 2
}

$failureReason = $null; $status = 'capture_failure'; $runnerExitCode = 1
$executionStarted = $false; $startCount = 0; $timedOut = $false
$processId = $null; $exitCode = $null; $startedAtUtc = $null; $endedAtUtc = $null; $durationMs = $null
$preProcesses = @(); $postProcessesFirst = @(); $postProcessesSecond = @(); $postflightInspectionError = $null
$protectedFiles = @(); $preHashes = [ordered]@{}; $postHashes = [ordered]@{}; $hashChanges = [ordered]@{}
$hashesComparable = $false; $ownedFilesUnchanged = $false; $process = $null
$stdout = ''; $stderr = ''; $stdoutTask = $null; $stderrTask = $null; $streamsCaptured = $false; $killRecord = $null

try {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $protectedFiles = @($manifest.protected_files)
    if ($protectedFiles.Count -lt 1) { throw 'Manifest has no protected files' }
    if (@($protectedFiles | ForEach-Object { [string]$_.path } | Sort-Object -Unique).Count -ne $protectedFiles.Count) { throw 'Protected file paths are not unique' }
    $preProcesses = @(Get-JuliaDescProcesses); Write-JsonFile (Join-Path $runDir 'processes_before.json') $preProcesses
    if ($preProcesses.Count -ne 0) { throw 'Preflight found Julia/DESC process; no invocation was attempted' }
    $preHashes = Get-OwnedHashes -ProtectedFiles $protectedFiles; Write-JsonFile (Join-Path $runDir 'owned_hashes_before.json') $preHashes
    if (-not (Test-HashesComparable $preHashes $preHashes $protectedFiles)) { throw 'Preflight hash set is not comparable' }
    foreach ($entry in $protectedFiles) { $p=[string]$entry.path; if ([string]$preHashes[$p] -ne ([string]$entry.sha256).ToLowerInvariant()) { throw "Frozen SHA-256 mismatch before execution: $p" } }

    $env:JULIA_NUM_THREADS = '1'
    $startedAtUtc = (Get-Date).ToUniversalTime()
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'julia'; $psi.Arguments = '--startup-file=no --history-file=no --project=. test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_tests.jl'; $psi.WorkingDirectory = $repoRoot
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process; $process.StartInfo = $psi
    if (-not $process.Start()) { throw 'Julia process did not start' }
    $startCount = 1; $executionStarted = $true; $processId = $process.Id
    $stdoutTask = $process.StandardOutput.ReadToEndAsync(); $stderrTask = $process.StandardError.ReadToEndAsync()
    $completed = $process.WaitForExit($timeoutMs)
    if (-not $completed) { $timedOut = $true; $status='timeout'; Add-FailureReason "Julia process exceeded timeoutSeconds=$TimeoutSeconds"; $killRecord=Stop-OwnedProcessTree -RootProcessId ([int]$processId); [void]$process.WaitForExit(5000) } else { [void]$process.WaitForExit() }
    $stdout = Read-StreamTask $stdoutTask; $stderr = Read-StreamTask $stderrTask; $streamsCaptured = $true; $exitCode = [int]$process.ExitCode; $endedAtUtc=(Get-Date).ToUniversalTime(); $durationMs=($endedAtUtc-$startedAtUtc).TotalMilliseconds
    if (-not $timedOut) { if ($exitCode -eq 0) { $status='runtime_complete'; $runnerExitCode=0 } else { $status='child_nonzero'; Add-FailureReason "Julia exited with code $exitCode" } }
}
catch {
    Add-FailureReason $_.Exception.ToString()
    if ($timedOut) { $status='timeout' } elseif (-not $executionStarted) { $status='preflight_failure' } else { $status='capture_failure' }
}
finally {
    if ($null -ne $process -and $executionStarted -and -not $streamsCaptured) { try { $stdout=Read-StreamTask $stdoutTask; $stderr=Read-StreamTask $stderrTask; $streamsCaptured=$true } catch { Add-FailureReason ('stdout/stderr capture failed: '+$_.Exception.ToString()); $status='capture_failure' } }
    if ($null -ne $process) { $process.Dispose() }
    Write-TextFile (Join-Path $runDir 'julia.stdout.raw') $stdout; Write-TextFile (Join-Path $runDir 'julia.stderr.raw') $stderr
    try { $postProcessesFirst=@(Get-JuliaDescProcesses) } catch { $postflightInspectionError=$_.Exception.ToString(); Add-FailureReason ('postflight first process inspection failed: '+$postflightInspectionError) }
    Write-JsonFile (Join-Path $runDir 'processes_after_first.json') $postProcessesFirst; Start-Sleep -Milliseconds 250
    try { $postProcessesSecond=@(Get-JuliaDescProcesses) } catch { $postflightInspectionError=$_.Exception.ToString(); Add-FailureReason ('postflight second process inspection failed: '+$postflightInspectionError) }
    Write-JsonFile (Join-Path $runDir 'processes_after_second.json') $postProcessesSecond
    try { $postHashes=Get-OwnedHashes -ProtectedFiles $protectedFiles } catch { Add-FailureReason ('postflight hash inspection failed: '+$_.Exception.ToString()); $postHashes=[ordered]@{} }
    Write-JsonFile (Join-Path $runDir 'owned_hashes_after.json') $postHashes; $hashesComparable=Test-HashesComparable $preHashes $postHashes $protectedFiles
    if ($hashesComparable) { $hashChanges=Compare-OwnedHashes $preHashes $postHashes $protectedFiles } else { Add-FailureReason 'hashesComparable=false' }
    Write-JsonFile (Join-Path $runDir 'owned_hash_changes.json') $hashChanges; $ownedFilesUnchanged=$hashesComparable -and ($hashChanges.Count -eq 0)
    if (-not $ownedFilesUnchanged) { Add-FailureReason 'ownedFilesUnchanged=false'; if ($status -ne 'timeout') { $status='postflight_failure' }; $runnerExitCode=1 }
    $postflightZeroJuliaDesc=($null -eq $postflightInspectionError -and $postProcessesFirst.Count -eq 0 -and $postProcessesSecond.Count -eq 0)
    if (-not $postflightZeroJuliaDesc) { Add-FailureReason 'postflight did not obtain two consecutive zero Julia/DESC observations'; if ($status -ne 'timeout') { $status='postflight_failure' }; $runnerExitCode=1 }
    if ($null -eq $endedAtUtc) { $endedAtUtc=(Get-Date).ToUniversalTime() }; if ($null -ne $startedAtUtc) { $durationMs=($endedAtUtc-$startedAtUtc).TotalMilliseconds }
    Write-TextFile (Join-Path $runDir 'exit_code.txt') ($(if ($null -eq $exitCode) {'NOT_CAPTURED'} else {[string]$exitCode}))
    Write-JsonFile (Join-Path $runDir 'thread.json') ([ordered]@{ requested='1'; environment=[string]$env:JULIA_NUM_THREADS; executionStarted=$executionStarted })
    Write-JsonFile (Join-Path $runDir 'run_metadata.json') ([ordered]@{ schema='T1CandidateStatePackageR2RunMetadataV1'; status=$status; accepted=$false; claimCeiling='contract_only'; command=$commandText; workingDirectory=$repoRoot; receiptDirectory=$runDir; lockPath=$lockPath; timeoutSeconds=$TimeoutSeconds; timeoutClassified=$timedOut; timeoutKillReceipt='conditional'; startedOnce=($startCount -eq 1); startCount=$startCount; executionStarted=$executionStarted; processId=$processId; exitCode=$exitCode; startedAtUtc=$startedAtUtc; endedAtUtc=$endedAtUtc; durationMs=$durationMs; juliaNumThreads=[string]$env:JULIA_NUM_THREADS; preflightProcessCount=$preProcesses.Count; postflightFirstProcessCount=$postProcessesFirst.Count; postflightSecondProcessCount=$postProcessesSecond.Count; postflightZeroJuliaDesc=$postflightZeroJuliaDesc; hashesComparable=$hashesComparable; ownedFileCount=$protectedFiles.Count; ownedFilesUnchanged=$ownedFilesUnchanged; streamsCaptured=$streamsCaptured; autoRetry=$false; failure=$failureReason; killRecord=$killRecord })
    Write-JsonFile (Join-Path $runDir 'capture_failure.json') ([ordered]@{ schema='T1CandidateStatePackageR2CaptureFailureV1'; status=$status; accepted=$false; claimCeiling='contract_only'; captureFailure=($status -eq 'capture_failure'); timeout=$timedOut; timeoutKillReceipt='conditional'; failure=$failureReason; receiptDirectory=$runDir })
    if ($null -ne $killRecord) { Write-JsonFile (Join-Path $runDir 'timeout_kill.json') $killRecord }
    if ($null -ne $lockStream) { $lockStream.Dispose() }
}
if ($runnerExitCode -ne 0) { exit 1 }; exit 0
