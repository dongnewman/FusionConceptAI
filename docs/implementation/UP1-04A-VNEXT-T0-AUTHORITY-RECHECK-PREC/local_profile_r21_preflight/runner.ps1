[CmdletBinding()]
param(
    [ValidateRange(1, 86400)]
    [int]$TimeoutSeconds = 600
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot '..\..\..\..')).Path
$manifestPath = Join-Path $scriptRoot 'manifest.json'
$lockPath = Join-Path $scriptRoot 'runtime.lock'
$commandText = 'julia --startup-file=no --history-file=no --project=. test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_tests.jl .'
$utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
$timeoutMs = [int]($TimeoutSeconds * 1000)

function Write-JsonFile {
    param([Parameter(Mandatory=$true)][string]$Path, [Parameter(Mandatory=$true)]$Value)
    $json = if ($Value -is [array] -and $Value.Count -eq 0) { '[]' } else { $Value | ConvertTo-Json -Depth 16 }
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
    else { $script:failureReason = $script:failureReason + '; ' + $Message }
}
function Get-JuliaDescProcesses {
    @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop |
        Where-Object { $_.Name -match '(?i)^(julia(?:-debug)?|desc)(?:\.exe)?$' } |
        ForEach-Object {
            [ordered]@{ name=[string]$_.Name; processId=[int]$_.ProcessId;
                parentProcessId=[int]$_.ParentProcessId; threadCount=[int]$_.ThreadCount;
                commandLine=[string]$_.CommandLine }
        })
}
function Get-DescendantProcessIds {
    param([Parameter(Mandatory=$true)][int]$RootProcessId)
    $all = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
    $seen = @{$RootProcessId = $true}
    function Add-Children([int]$ParentId) {
        foreach ($row in @($all | Where-Object { [int]$_.ParentProcessId -eq $ParentId })) {
            $childId = [int]$row.ProcessId
            if (-not $seen.ContainsKey($childId)) { $seen[$childId] = $true; Add-Children $childId }
        }
    }
    Add-Children $RootProcessId
    @($seen.Keys | Where-Object { [int]$_ -ne $RootProcessId } | ForEach-Object { [int]$_ })
}
function Stop-OwnedProcessTree {
    param([Parameter(Mandatory=$true)][int]$RootProcessId)
    $ids = @(); $errors = @()
    try { $ids = @(Get-DescendantProcessIds $RootProcessId) }
    catch { $errors += 'descendant enumeration failed: ' + $_.Exception.ToString() }
    $killIds = @($ids + $RootProcessId | Select-Object -Unique | Sort-Object -Descending)
    foreach ($id in $killIds) {
        try { Stop-Process -Id ([int]$id) -Force -ErrorAction Stop }
        catch { $errors += "kill $id failed: " + $_.Exception.Message }
    }
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
    if ($Before.Count -ne 6 -or $After.Count -ne 6 -or $ProtectedFiles.Count -ne 6) { return $false }
    $expected = @($ProtectedFiles | ForEach-Object { [string]$_.path } | Sort-Object -Unique)
    $bk = @($Before.Keys | Sort-Object); $ak = @($After.Keys | Sort-Object)
    if ($expected.Count -ne 6 -or $bk.Count -ne 6 -or $ak.Count -ne 6) { return $false }
    if ((Compare-Object $expected $bk) -or (Compare-Object $expected $ak)) { return $false }
    foreach ($key in $expected) {
        if ([string]$Before[$key] -notmatch '^[0-9a-f]{64}$' -or [string]$After[$key] -notmatch '^[0-9a-f]{64}$') { return $false }
    }
    $true
}
function Compare-OwnedHashes {
    param([Parameter(Mandatory=$true)]$Before, [Parameter(Mandatory=$true)]$After, [Parameter(Mandatory=$true)]$ProtectedFiles)
    $changes = [ordered]@{}
    foreach ($entry in $ProtectedFiles) {
        $path = [string]$entry.path
        if ([string]$Before[$path] -ne [string]$After[$path]) { $changes[$path] = [ordered]@{before=[string]$Before[$path]; after=[string]$After[$path]} }
    }
    $changes
}
function Read-StreamTask {
    param([Parameter(Mandatory=$true)]$Task, [int]$WaitMilliseconds=10000)
    if (-not $Task.Wait($WaitMilliseconds)) { throw 'Redirected stream did not drain within bounded wait' }
    $Task.GetAwaiter().GetResult()
}

# CreateNew and the durable run directory make this wrapper exactly-once.
$lockStream = $null; $runDir = $null
try {
    if (Test-Path -LiteralPath $lockPath) { throw "Existing runtime lock refuses overwrite: $lockPath" }
    $lockStream = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    if (@(Get-ChildItem -LiteralPath $scriptRoot -Directory -Filter 'run_*').Count -ne 0) { throw 'Existing run receipt directory refuses overwrite' }
    $runDir = Join-Path $scriptRoot ('run_' + (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff') + '_' + [Guid]::NewGuid().ToString('N'))
    if (Test-Path -LiteralPath $runDir) { throw "Receipt directory collision refuses overwrite: $runDir" }
    [System.IO.Directory]::CreateDirectory($runDir) | Out-Null
}
catch {
    if ($null -ne $lockStream) { $lockStream.Dispose() }
    Write-Error $_.Exception.ToString(); exit 2
}

$failureReason=$null; $status='capture_failure'; $runnerExitCode=1; $executionStarted=$false; $startCount=0
$timedOut=$false; $timeoutReason=$null; $processId=$null; $exitCode=$null; $startedAtUtc=$null; $endedAtUtc=$null
$preProcesses=@(); $postProcessesFirst=@(); $postProcessesSecond=@(); $postflightInspectionError=$null
$protectedFiles=@(); $preHashes=[ordered]@{}; $postHashes=[ordered]@{}; $hashChanges=[ordered]@{}
$hashesComparable=$false; $ownedFilesUnchanged=$false; $process=$null; $stdout=''; $stderr=''; $stdoutTask=$null; $stderrTask=$null
$streamsCaptured=$false; $killRecord=$null; $launchThreadCount=$null

try {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $protectedFiles = @($manifest.protected_files)
    if ($protectedFiles.Count -ne 6) { throw "Expected exactly six protected files; found $($protectedFiles.Count)" }
    if (@($protectedFiles.path | Sort-Object -Unique).Count -ne 6) { throw 'Protected paths are not six unique paths' }
    $preProcesses = @(Get-JuliaDescProcesses)
    Write-JsonFile (Join-Path $runDir 'processes_before.json') $preProcesses
    if ($preProcesses.Count -ne 0) { throw 'Preflight found Julia/DESC; invocation was refused' }
    $preHashes = Get-OwnedHashes $protectedFiles
    Write-JsonFile (Join-Path $runDir 'owned_hashes_before.json') $preHashes
    if (-not (Test-HashesComparable $preHashes $preHashes $protectedFiles)) { throw 'Preflight hash set is not exactly six valid hashes' }
    foreach ($entry in $protectedFiles) {
        $p=[string]$entry.path; if ([string]$preHashes[$p] -ne ([string]$entry.sha256).ToLowerInvariant()) { throw "Frozen SHA-256 mismatch before execution: $p" }
    }

    $env:JULIA_NUM_THREADS='1'
    $startedAtUtc=(Get-Date).ToUniversalTime()
    $psi=New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName='julia'; $psi.Arguments='--startup-file=no --history-file=no --project=. test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_tests.jl .'
    $psi.WorkingDirectory=$repoRoot; $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true; $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
    $process=New-Object System.Diagnostics.Process; $process.StartInfo=$psi
    $startCount++
    if (-not $process.Start()) { throw 'Julia process did not start' }
    $executionStarted=$true; $processId=[int]$process.Id
    try { $launchThreadCount=[int]((Get-CimInstance Win32_Process -Filter "ProcessId=$processId").ThreadCount) } catch { $launchThreadCount=$null }
    $stdoutTask=$process.StandardOutput.ReadToEndAsync(); $stderrTask=$process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($timeoutMs)) {
        $timedOut=$true; $timeoutReason="WaitForExit exceeded $TimeoutSeconds seconds"; $status='timeout'; Add-FailureReason $timeoutReason
        $killRecord=Stop-OwnedProcessTree $processId; [void]$process.WaitForExit(5000)
    } else { [void]$process.WaitForExit() }
    $stdout=Read-StreamTask $stdoutTask; $stderr=Read-StreamTask $stderrTask; $streamsCaptured=$true
    $exitCode=[int]$process.ExitCode; $endedAtUtc=(Get-Date).ToUniversalTime()
    if (-not $timedOut) {
        if ($exitCode -eq 0) { $status='runtime_complete'; $runnerExitCode=0 }
        else { $status='child_nonzero'; Add-FailureReason "Julia exited with code $exitCode" }
    }
}
catch {
    Add-FailureReason $_.Exception.ToString()
    if ($timedOut) { $status='timeout' } elseif (-not $executionStarted) { $status='preflight_failure' } else { $status='capture_failure' }
}
finally {
    if ($null -ne $process -and $executionStarted -and -not $streamsCaptured) {
        try { $stdout=Read-StreamTask $stdoutTask; $stderr=Read-StreamTask $stderrTask; $streamsCaptured=$true }
        catch { Add-FailureReason ('stream capture failed: ' + $_.Exception.ToString()) }
    }
    if ($null -ne $process) { $process.Dispose() }
    Write-TextFile (Join-Path $runDir 'stdout.raw') $stdout; Write-TextFile (Join-Path $runDir 'stderr.raw') $stderr
    try { $postProcessesFirst=@(Get-JuliaDescProcesses) } catch { $postflightInspectionError=$_.Exception.ToString(); Add-FailureReason ('postflight first inspection failed: '+$postflightInspectionError) }
    Write-JsonFile (Join-Path $runDir 'processes_after_first.json') $postProcessesFirst
    Start-Sleep -Milliseconds 250
    try { $postProcessesSecond=@(Get-JuliaDescProcesses) } catch { $postflightInspectionError=$_.Exception.ToString(); Add-FailureReason ('postflight second inspection failed: '+$postflightInspectionError) }
    Write-JsonFile (Join-Path $runDir 'processes_after_second.json') $postProcessesSecond
    try { $postHashes=Get-OwnedHashes $protectedFiles } catch { Add-FailureReason ('postflight hash inspection failed: '+$_.Exception.ToString()); $postHashes=[ordered]@{} }
    Write-JsonFile (Join-Path $runDir 'owned_hashes_after.json') $postHashes
    $hashesComparable=Test-HashesComparable $preHashes $postHashes $protectedFiles
    if ($hashesComparable) { $hashChanges=Compare-OwnedHashes $preHashes $postHashes $protectedFiles } else { Add-FailureReason 'hashesComparable=false; before/after must each contain exactly six hashes' }
    Write-JsonFile (Join-Path $runDir 'owned_hash_changes.json') $hashChanges
    $ownedFilesUnchanged=$hashesComparable -and $hashChanges.Count -eq 0
    if (-not $ownedFilesUnchanged) { Add-FailureReason 'ownedFilesUnchanged=false'; if ($status -ne 'timeout') {$status='postflight_failure'} }
    $postflightZero=($null -eq $postflightInspectionError -and $postProcessesFirst.Count -eq 0 -and $postProcessesSecond.Count -eq 0)
    if (-not $postflightZero) { Add-FailureReason 'postflight did not obtain two consecutive zero Julia/DESC observations'; if ($status -ne 'timeout') {$status='postflight_failure'} }
    if ($null -eq $endedAtUtc) { $endedAtUtc=(Get-Date).ToUniversalTime() }
    $durationMs=if ($null -ne $startedAtUtc) { (($endedAtUtc-$startedAtUtc).TotalMilliseconds) } else {$null}
    Write-JsonFile (Join-Path $runDir 'thread.json') ([ordered]@{requested='1'; environment=[string]$env:JULIA_NUM_THREADS; processId=$processId; osThreadCountAtLaunch=$launchThreadCount})
    $metadata=[ordered]@{schema='T0AuthorityRecheckR21RunMetadataV1'; status=$status; command=$commandText; workingDirectory=$repoRoot; receiptDirectory=$runDir; lockPath=$lockPath; timeoutSeconds=$TimeoutSeconds; timeoutReason=$timeoutReason; timeoutClassified=$timedOut; startedOnce=($startCount -eq 1); startCount=$startCount; executionStarted=$executionStarted; processId=$processId; exitCode=$exitCode; startedAtUtc=$startedAtUtc; endedAtUtc=$endedAtUtc; durationMs=$durationMs; juliaNumThreads=[string]$env:JULIA_NUM_THREADS; osThreadCountAtLaunch=$launchThreadCount; preflightProcessCount=$preProcesses.Count; postflightFirstProcessCount=$postProcessesFirst.Count; postflightSecondProcessCount=$postProcessesSecond.Count; postflightZeroJuliaDesc=$postflightZero; hashesComparable=$hashesComparable; ownedFileCount=6; ownedFilesUnchanged=$ownedFilesUnchanged; streamsCaptured=$streamsCaptured; autoRetry=$false; failure=$failureReason; killRecord=$killRecord}
    Write-JsonFile (Join-Path $runDir 'run_metadata.json') $metadata
    Write-JsonFile (Join-Path $runDir 'capture_failure.json') ([ordered]@{schema='T0AuthorityRecheckR21CaptureFailureV1'; status=$status; timeout=$timedOut; timeoutReason=$timeoutReason; failure=$failureReason; receiptDirectory=$runDir})
    if ($null -ne $lockStream) { $lockStream.Dispose() }
}
if ($runnerExitCode -ne 0 -or -not $ownedFilesUnchanged -or -not $postflightZero) { exit 1 }
exit 0
