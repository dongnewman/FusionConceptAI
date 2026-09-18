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
$commandText = 'julia --startup-file=no --history-file=no --project=. test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_tests.jl .'
$utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
$timeoutMs = [int]($TimeoutSeconds * 1000)

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )
    if ($Value -is [array] -and $Value.Count -eq 0) {
        $json = '[]'
    }
    else {
        $json = $Value | ConvertTo-Json -Depth 12
    }
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8NoBom)
}
function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowNull()][string]$Value
    )
    if ($null -eq $Value) {
        $Value = ''
    }
    [System.IO.File]::WriteAllText($Path, $Value, $utf8NoBom)
}

function Add-FailureReason {
    param([Parameter(Mandatory = $true)][string]$Message)
    if ($null -eq $script:failureReason) {
        $script:failureReason = $Message
    }
    else {
        $script:failureReason = $script:failureReason + '; ' + $Message
    }
}

function Get-JuliaDescProcesses {
    $rows = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop |
        Where-Object { $_.Name -match '(?i)^(julia(?:-debug)?|desc)(?:\.exe)?$' } |
        ForEach-Object {
            [ordered]@{
                name = [string]$_.Name
                processId = [int]$_.ProcessId
                parentProcessId = [int]$_.ParentProcessId
                commandLine = [string]$_.CommandLine
            }
        })
    return $rows
}

function Get-DescendantProcessIds {
    param([Parameter(Mandatory = $true)][int]$RootProcessId)
    $all = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
    $seen = @{}
    $seen[$RootProcessId] = $true
    function Add-Children {
        param([int]$ParentId)
        foreach ($row in @($all | Where-Object { [int]$_.ParentProcessId -eq $ParentId })) {
            $childId = [int]$row.ProcessId
            if (-not $seen.ContainsKey($childId)) {
                $seen[$childId] = $true
                Add-Children -ParentId $childId
            }
        }
    }
    Add-Children -ParentId $RootProcessId
    return @($seen.Keys | Where-Object { [int]$_ -ne $RootProcessId } | ForEach-Object { [int]$_ })
}

function Stop-OwnedProcessTree {
    param([Parameter(Mandatory = $true)][int]$RootProcessId)
    $ids = @()
    $errors = @()
    try {
        $ids = @(Get-DescendantProcessIds -RootProcessId $RootProcessId)
    }
    catch {
        $errors += 'descendant enumeration failed: ' + $_.Exception.ToString()
    }
    $killIds = @($ids + $RootProcessId | Select-Object -Unique | Sort-Object -Descending)
    foreach ($id in $killIds) {
        try {
            Stop-Process -Id ([int]$id) -Force -ErrorAction Stop
        }
        catch {
            # A child may have exited between enumeration and the kill request.
            $errors += "kill $id failed: " + $_.Exception.Message
        }
    }
    return [pscustomobject]@{
        rootProcessId = $RootProcessId
        attemptedProcessIds = @($killIds)
        errors = @($errors)
    }
}

function Get-OwnedHashes {
    param([Parameter(Mandatory = $true)]$ProtectedFiles)
    $hashes = [ordered]@{}
    foreach ($entry in $ProtectedFiles) {
        $relativePath = [string]$entry.path
        $fullPath = Join-Path $repoRoot $relativePath
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            throw "Protected file is missing: $relativePath"
        }
        $hashes[$relativePath] = ((Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash).ToLowerInvariant()
    }
    return $hashes
}

function Test-HashesComparable {
    param(
        [Parameter(Mandatory = $true)]$Before,
        [Parameter(Mandatory = $true)]$After,
        [Parameter(Mandatory = $true)]$ProtectedFiles
    )
    if ($Before.Count -ne $ProtectedFiles.Count -or $After.Count -ne $ProtectedFiles.Count -or $ProtectedFiles.Count -lt 1) {
        return $false
    }
    $beforeKeys = @($Before.Keys | Sort-Object)
    $afterKeys = @($After.Keys | Sort-Object)
    $expectedKeys = @($ProtectedFiles | ForEach-Object { [string]$_.path } | Sort-Object -Unique)
    if ($beforeKeys.Count -ne $ProtectedFiles.Count -or $afterKeys.Count -ne $ProtectedFiles.Count -or $expectedKeys.Count -ne $ProtectedFiles.Count) {
        return $false
    }
    if ((Compare-Object -ReferenceObject $expectedKeys -DifferenceObject $beforeKeys) -ne $null) {
        return $false
    }
    if ((Compare-Object -ReferenceObject $expectedKeys -DifferenceObject $afterKeys) -ne $null) {
        return $false
    }
    foreach ($key in $expectedKeys) {
        if ([string]$Before[$key] -notmatch '^[0-9a-f]{64}$' -or [string]$After[$key] -notmatch '^[0-9a-f]{64}$') {
            return $false
        }
    }
    return $true
}

function Compare-OwnedHashes {
    param(
        [Parameter(Mandatory = $true)]$Before,
        [Parameter(Mandatory = $true)]$After,
        [Parameter(Mandatory = $true)]$ProtectedFiles
    )
    $changes = [ordered]@{}
    foreach ($entry in $ProtectedFiles) {
        $relativePath = [string]$entry.path
        if ([string]$Before[$relativePath] -ne [string]$After[$relativePath]) {
            $changes[$relativePath] = [ordered]@{
                before = [string]$Before[$relativePath]
                after = [string]$After[$relativePath]
            }
        }
    }
    return $changes
}

function Read-StreamTask {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [int]$WaitMilliseconds = 10000
    )
    if (-not $Task.Wait($WaitMilliseconds)) {
        throw 'Redirected stream did not drain within the bounded wait'
    }
    return $Task.GetAwaiter().GetResult()
}

# A durable CreateNew lock makes a second runtime receipt an explicit refusal.
$lockStream = $null
$runDir = $null
try {
    if (Test-Path -LiteralPath $lockPath) {
        throw "Existing runtime lock refuses overwrite: $lockPath"
    }
    $lockStream = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    $existingReceipts = @(Get-ChildItem -LiteralPath $scriptRoot -Directory -Filter 'run_*' -ErrorAction Stop)
    if ($existingReceipts.Count -ne 0) {
        throw 'Existing runtime receipt directory refuses overwrite'
    }
    $runName = 'run_' + (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff') + '_' + [Guid]::NewGuid().ToString('N')
    $runDir = Join-Path $scriptRoot $runName
    if (Test-Path -LiteralPath $runDir) {
        throw "Receipt directory collision refuses overwrite: $runDir"
    }
    [System.IO.Directory]::CreateDirectory($runDir) | Out-Null
    if (-not (Test-Path -LiteralPath $runDir -PathType Container)) {
        throw "Receipt directory was not created: $runDir"
    }
}
catch {
    if ($null -ne $lockStream) {
        $lockStream.Dispose()
    }
    Write-Error $_.Exception.ToString()
    exit 2
}

$failureReason = $null
$status = 'capture_failure'
$runnerExitCode = 1
$executionStarted = $false
$startCount = 0
$timedOut = $false
$processId = $null
$exitCode = $null
$startedAtUtc = $null
$endedAtUtc = $null
$durationMs = $null
$preProcesses = @()
$postProcessesFirst = @()
$postProcessesSecond = @()
$postflightInspectionError = $null
$protectedFiles = @()
$preHashes = [ordered]@{}
$postHashes = [ordered]@{}
$hashChanges = [ordered]@{}
$hashesComparable = $false
$ownedFilesUnchanged = $false
$process = $null
$stdout = ''
$stderr = ''
$stdoutTask = $null
$stderrTask = $null
$streamsCaptured = $false
$killRecord = $null

try {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $protectedFiles = @($manifest.protected_files)
    if ($protectedFiles.Count -lt 1) {
        throw "Expected at least one protected file; found $($protectedFiles.Count)"
    }
    $uniquePaths = @($protectedFiles | ForEach-Object { [string]$_.path } | Sort-Object -Unique)
    if ($uniquePaths.Count -ne $protectedFiles.Count) {
        throw 'Protected file paths are not unique'
    }

    $preProcesses = @(Get-JuliaDescProcesses)
    Write-JsonFile -Path (Join-Path $runDir 'processes_before.json') -Value $preProcesses
    if ($preProcesses.Count -ne 0) {
        throw 'Preflight found one or more Julia/DESC processes; no invocation was attempted'
    }

    $preHashes = Get-OwnedHashes -ProtectedFiles $protectedFiles
    Write-JsonFile -Path (Join-Path $runDir 'owned_hashes_before.json') -Value $preHashes
    if (-not (Test-HashesComparable -Before $preHashes -After $preHashes -ProtectedFiles $protectedFiles)) {
        throw 'Preflight hash set is not exactly $($protectedFiles.Count) comparable SHA-256 values'
    }
    foreach ($entry in $protectedFiles) {
        $relativePath = [string]$entry.path
        $expectedHash = ([string]$entry.sha256).ToLowerInvariant()
        if ([string]$preHashes[$relativePath] -ne $expectedHash) {
            throw "Frozen SHA-256 mismatch before execution: $relativePath"
        }
    }

    $env:JULIA_NUM_THREADS = '1'
    $startedAtUtc = (Get-Date).ToUniversalTime()
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'julia'
    $psi.Arguments = '--startup-file=no --history-file=no --project=. test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_tests.jl .'
    $psi.WorkingDirectory = $repoRoot
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $startCount++
    if (-not $process.Start()) {
        throw 'Julia process did not start'
    }
    $executionStarted = $true
    $processId = $process.Id
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $completed = $process.WaitForExit($timeoutMs)
    if (-not $completed) {
        $timedOut = $true
        $status = 'timeout'
        Add-FailureReason "Julia process exceeded timeoutSeconds=$TimeoutSeconds"
        $killRecord = Stop-OwnedProcessTree -RootProcessId ([int]$processId)
        [void]$process.WaitForExit(5000)
    }
    else {
        # WaitForExit(int) can return before asynchronous redirected streams finish.
        [void]$process.WaitForExit()
    }
    $stdout = Read-StreamTask -Task $stdoutTask
    $stderr = Read-StreamTask -Task $stderrTask
    $streamsCaptured = $true
    $exitCode = [int]$process.ExitCode
    $endedAtUtc = (Get-Date).ToUniversalTime()
    $durationMs = ($endedAtUtc - $startedAtUtc).TotalMilliseconds
    if (-not $timedOut) {
        if ($exitCode -eq 0) {
            $status = 'runtime_complete'
            $runnerExitCode = 0
        }
        else {
            $status = 'child_nonzero'
            $runnerExitCode = 1
            Add-FailureReason "Julia exited with code $exitCode"
        }
    }
}
catch {
    Add-FailureReason $_.Exception.ToString()
    if ($timedOut) {
        $status = 'timeout'
    }
    elseif (-not $executionStarted) {
        $status = 'preflight_failure'
    }
    else {
        $status = 'capture_failure'
    }
    $runnerExitCode = 1
}
finally {
    if ($null -ne $process -and $executionStarted -and -not $streamsCaptured) {
        try {
            $stdout = Read-StreamTask -Task $stdoutTask
            $stderr = Read-StreamTask -Task $stderrTask
            $streamsCaptured = $true
        }
        catch {
            Add-FailureReason ('stdout/stderr capture failed: ' + $_.Exception.ToString())
            if (-not $timedOut) {
                $status = 'capture_failure'
            }
            $runnerExitCode = 1
        }
    }
    if ($null -ne $process) {
        $process.Dispose()
    }
    Write-TextFile -Path (Join-Path $runDir 'julia.stdout.raw') -Value $stdout
    Write-TextFile -Path (Join-Path $runDir 'julia.stderr.raw') -Value $stderr

    try {
        $postProcessesFirst = @(Get-JuliaDescProcesses)
    }
    catch {
        $postflightInspectionError = $_.Exception.ToString()
        Add-FailureReason ('postflight first process inspection failed: ' + $postflightInspectionError)
    }
    Write-JsonFile -Path (Join-Path $runDir 'processes_after_first.json') -Value $postProcessesFirst
    Start-Sleep -Milliseconds 250
    try {
        $postProcessesSecond = @(Get-JuliaDescProcesses)
    }
    catch {
        $postflightInspectionError = $_.Exception.ToString()
        Add-FailureReason ('postflight second process inspection failed: ' + $postflightInspectionError)
    }
    Write-JsonFile -Path (Join-Path $runDir 'processes_after_second.json') -Value $postProcessesSecond

    try {
        $postHashes = Get-OwnedHashes -ProtectedFiles $protectedFiles
    }
    catch {
        Add-FailureReason ('postflight hash inspection failed: ' + $_.Exception.ToString())
        $postHashes = [ordered]@{}
    }
    Write-JsonFile -Path (Join-Path $runDir 'owned_hashes_after.json') -Value $postHashes
    $hashesComparable = Test-HashesComparable -Before $preHashes -After $postHashes -ProtectedFiles $protectedFiles
    if ($hashesComparable) {
        $hashChanges = Compare-OwnedHashes -Before $preHashes -After $postHashes -ProtectedFiles $protectedFiles
    }
    else {
        $hashChanges = [ordered]@{}
        Add-FailureReason 'hashesComparable=false; before/after must each contain exactly $($protectedFiles.Count) valid SHA-256 values'
    }
    Write-JsonFile -Path (Join-Path $runDir 'owned_hash_changes.json') -Value $hashChanges
    $ownedFilesUnchanged = $hashesComparable -and ($hashChanges.Count -eq 0)
    if (-not $ownedFilesUnchanged) {
        Add-FailureReason 'ownedFilesUnchanged=false'
        if ($status -ne 'timeout') {
            $status = 'postflight_failure'
        }
        $runnerExitCode = 1
    }

    $postflightZeroJuliaDesc = ($null -eq $postflightInspectionError -and $postProcessesFirst.Count -eq 0 -and $postProcessesSecond.Count -eq 0)
    if (-not $postflightZeroJuliaDesc) {
        Add-FailureReason 'postflight did not obtain two consecutive zero Julia/DESC observations'
        if ($status -ne 'timeout') {
            $status = 'postflight_failure'
        }
        $runnerExitCode = 1
    }
    if ($null -eq $endedAtUtc) {
        $endedAtUtc = (Get-Date).ToUniversalTime()
    }
    if ($null -ne $startedAtUtc) {
        $durationMs = ($endedAtUtc - $startedAtUtc).TotalMilliseconds
    }
    if ($null -eq $exitCode) {
        Write-TextFile -Path (Join-Path $runDir 'exit_code.txt') -Value 'NOT_CAPTURED'
    }
    else {
        Write-TextFile -Path (Join-Path $runDir 'exit_code.txt') -Value ([string]$exitCode)
    }
    Write-JsonFile -Path (Join-Path $runDir 'thread.json') -Value ([ordered]@{
        requested = '1'
        environment = [string]$env:JULIA_NUM_THREADS
        executionStarted = $executionStarted
    })
    $metadata = [ordered]@{
        schema = 'T0AuthorityRecheckR22RunMetadataV2'
        status = $status
        command = $commandText
        workingDirectory = $repoRoot
        receiptDirectory = $runDir
        lockPath = $lockPath
        timeoutSeconds = $TimeoutSeconds
        timeoutClassified = $timedOut
        startedOnce = ($startCount -eq 1)
        startCount = $startCount
        executionStarted = $executionStarted
        processId = $processId
        exitCode = $exitCode
        startedAtUtc = $startedAtUtc
        endedAtUtc = $endedAtUtc
        durationMs = $durationMs
        juliaNumThreads = [string]$env:JULIA_NUM_THREADS
        preflightProcessCount = $preProcesses.Count
        postflightFirstProcessCount = $postProcessesFirst.Count
        postflightSecondProcessCount = $postProcessesSecond.Count
        postflightZeroJuliaDesc = $postflightZeroJuliaDesc
        hashesComparable = $hashesComparable
        ownedFileCount = $protectedFiles.Count
        ownedFilesUnchanged = $ownedFilesUnchanged
        streamsCaptured = $streamsCaptured
        autoRetry = $false
        failure = $failureReason
        killRecord = $killRecord
    }
    Write-JsonFile -Path (Join-Path $runDir 'run_metadata.json') -Value $metadata
    Write-JsonFile -Path (Join-Path $runDir 'capture_failure.json') -Value ([ordered]@{
        schema = 'T0AuthorityRecheckR22CaptureFailureV2'
        status = $status
        captureFailure = ($status -eq 'capture_failure')
        timeout = $timedOut
        failure = $failureReason
        receiptDirectory = $runDir
    })
    if ($null -ne $killRecord) {
        Write-JsonFile -Path (Join-Path $runDir 'timeout_kill.json') -Value $killRecord
    }
    if ($null -ne $lockStream) {
        $lockStream.Dispose()
    }
}

if ($runnerExitCode -ne 0) {
    exit 1
}
exit 0
