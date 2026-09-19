[CmdletBinding()]
param(
    [ValidateRange(1, 86400)]
    [int]$TimeoutSeconds = 300,
    [switch]$PreflightOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot '..\..\..\..')).Path
$manifestPath = Join-Path $scriptRoot 'manifest.json'
$lockPath = Join-Path $scriptRoot 'runtime.lock'
$commandText = 'julia --startup-file=no --history-file=no --project=. test/RuntimeV4/UP2CrossMeshConservativeTransfer/cross_mesh_conservative_transfer_v1_tests.jl'
$utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false

function Write-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)]$Value)
    if ($Value -is [array] -and $Value.Count -eq 0) { $json = '[]' }
    else { $json = $Value | ConvertTo-Json -Depth 20 }
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8NoBom)
}

function Write-TextFile {
    param([Parameter(Mandatory = $true)][string]$Path, [AllowNull()][string]$Value)
    if ($null -eq $Value) { $Value = '' }
    [System.IO.File]::WriteAllText($Path, $Value, $utf8NoBom)
}

function Get-JuliaDescProcesses {
    @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop |
        Where-Object { $_.Name -match '(?i)^(julia(?:-debug)?|desc)(?:\.exe)?$' } |
        ForEach-Object {
            [ordered]@{ name = [string]$_.Name; processId = [int]$_.ProcessId
                parentProcessId = [int]$_.ParentProcessId; commandLine = [string]$_.CommandLine }
        })
}

function Get-DescendantProcessIds {
    param([Parameter(Mandatory = $true)][int]$RootProcessId)
    $all = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
    $seen = @{}; $seen[$RootProcessId] = $true
    function Add-Children { param([int]$ParentId)
        foreach ($row in @($all | Where-Object { [int]$_.ParentProcessId -eq $ParentId })) {
            $id = [int]$row.ProcessId
            if (-not $seen.ContainsKey($id)) { $seen[$id] = $true; Add-Children -ParentId $id }
        }
    }
    Add-Children -ParentId $RootProcessId
    @($seen.Keys | Where-Object { [int]$_ -ne $RootProcessId } | ForEach-Object { [int]$_ })
}

function Stop-OwnedProcessTree {
    param([Parameter(Mandatory = $true)][int]$RootProcessId)
    $ids = @(); $errors = @()
    try { $ids = @(Get-DescendantProcessIds -RootProcessId $RootProcessId) }
    catch { $errors += 'descendant enumeration failed: ' + $_.Exception.ToString() }
    $killIds = @($ids + $RootProcessId | Select-Object -Unique | Sort-Object -Descending)
    foreach ($id in $killIds) {
        try { Stop-Process -Id ([int]$id) -Force -ErrorAction Stop }
        catch { $errors += "kill $id failed: " + $_.Exception.Message }
    }
    [pscustomobject]@{ rootProcessId = $RootProcessId; attemptedProcessIds = @($killIds); errors = @($errors) }
}

function Read-Manifest {
    $m = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ([string]$m.schema -ne 'DeclaredCrossMeshConservativeTransferPreflightManifestV1') { throw 'manifest schema mismatch' }
    if ([string]$m.task -ne 'UP2-CROSS-MESH-CONSERVATIVE-TRANSFER-V1') { throw 'manifest task mismatch' }
    if ([string]$m.required_runtime_command -ne $commandText) { throw 'required runtime command mismatch' }
    if ([int]$m.required_environment.JULIA_NUM_THREADS -ne 1) { throw 'required JULIA_NUM_THREADS must be 1' }
    if ([int]$m.timeout.defaultSeconds -ne 300) { throw 'manifest default timeout must be 300 seconds' }
    if ([bool]$m.timeout.automaticRetry) { throw 'automatic retry must be false' }
    if ([bool]$m.receipt_policy.exactlyOnce -ne $true -or [string]$m.receipt_policy.lock -notmatch 'CreateNew') { throw 'receipt policy is not exactly-once/CreateNew' }
    if ([int]$m.process_policy.postflight_consecutive_zero_observations -ne 2) { throw 'postflight must require two zero observations' }
    if ([int]$m.protected_files.Count -ne 20) { throw 'protected_files must contain exactly twenty entries' }
    if ([string]$m.runner_sha256 -notmatch '^[0-9a-f]{64}$') { throw 'runner_sha256 missing or malformed' }
    $paths = @($m.protected_files | ForEach-Object { [string]$_.path })
    if (($paths | Sort-Object -Unique).Count -ne $paths.Count) { throw 'manifest contains duplicate protected paths' }
    $roles = @($m.protected_files | ForEach-Object { [string]$_.role })
    if (($roles | Where-Object { $_ -eq 'slice' }).Count -ne 6 -or
        ($roles | Where-Object { $_ -eq 'dirty_protection' }).Count -ne 6 -or
        ($roles | Where-Object { $_ -eq 'dependency' }).Count -ne 8) {
        throw 'protected_files roles must contain 6 slice, 6 dirty_protection, and 8 dependency entries'
    }
    foreach ($entry in $m.protected_files) {
        if ([string]$entry.path -match '^[\\/]' -or [string]$entry.path -match '(^|[\\/])\.\.([\\/]|$)') { throw "manifest path escapes repository: $($entry.path)" }
        if ([int64]$entry.bytes -lt 0) { throw "manifest byte count malformed: $($entry.path)" }
        if ([string]$entry.sha256 -notmatch '^[0-9a-fA-F]{64}$') { throw "manifest SHA-256 malformed: $($entry.path)" }
    }
    return $m
}

function Get-Entries($Manifest) {
    @($Manifest.protected_files)
}

function Get-Hashes($Entries) {
    $hashes = [ordered]@{}
    foreach ($entry in $Entries) {
        $relative = [string]$entry.path; $full = Join-Path $repoRoot $relative
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "protected file is missing: $relative" }
        $hashes[$relative] = ((Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash).ToLowerInvariant()
    }
    $hashes
}

function Assert-Hashes($Manifest, $Hashes) {
    foreach ($entry in (Get-Entries $Manifest)) {
        $relative = [string]$entry.path; $expected = ([string]$entry.sha256).ToLowerInvariant()
        if ([string]$Hashes[$relative] -ne $expected) { throw "frozen SHA-256 mismatch: $relative" }
        $full = Join-Path $repoRoot $relative
        $actualBytes = [int64](Get-Item -LiteralPath $full).Length
        if ($actualBytes -ne [int64]$entry.bytes) { throw "frozen byte-count mismatch: $relative" }
    }
}

function Compare-Hashes($Before, $After, $Manifest) {
    $changes = [ordered]@{}
    foreach ($entry in (Get-Entries $Manifest)) {
        $relative = [string]$entry.path
        if ([string]$Before[$relative] -ne [string]$After[$relative]) {
            $changes[$relative] = [ordered]@{ before = [string]$Before[$relative]; after = [string]$After[$relative] }
        }
    }
    $changes
}

function Read-StreamTask($Task) {
    if (-not $Task.Wait(10000)) { throw 'redirected stream did not drain within bounded wait' }
    $Task.GetAwaiter().GetResult()
}

function Invoke-StaticPreflight($Manifest) {
    $staticPath = Join-Path $repoRoot 'test\RuntimeV4\UP2CrossMeshConservativeTransfer\static_qa_declared_cross_mesh_v1.py'
    $oraclePath = Join-Path $repoRoot 'test\RuntimeV4\UP2CrossMeshConservativeTransfer\independent_oracle_declared_cross_mesh_v1.py'
    $static = & python -B $staticPath 2>&1
    if ($LASTEXITCODE -ne 0 -or (($static -join "`n") -notmatch 'DECLARED_CROSS_MESH_CONSERVATIVE_TRANSFER_V1_STATIC_QA=PASS')) { throw 'Python static QA did not report PASS' }
    $oracle = & python -B $oraclePath 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Python independent oracle exited nonzero' }
    $oracleText = ($oracle -join "`n").Trim()
    $oracleJson = $oracleText | ConvertFrom-Json
    if ([string]$oracleJson.status -ne 'pass' -or [bool]$oracleJson.julia_executed -or [bool]$oracleJson.product_code_imported) { throw 'oracle output did not prove pass/python-only boundary' }
    [pscustomobject]@{ staticOutput = ($static -join "`n"); oracleOutput = $oracleText }
}

# Preflight is intentionally side-effect free: no lock, receipt directory, Julia, or DESC.
if ($PreflightOnly) {
    try {
        $manifest = Read-Manifest
        $entries = Get-Entries $manifest
        $hashes = Get-Hashes $entries
        Assert-Hashes $manifest $hashes
        $runnerHash = ((Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash).ToLowerInvariant()
        if ($runnerHash -ne ([string]$manifest.runner_sha256).ToLowerInvariant()) { throw 'runner self-hash mismatch' }
        $result = Invoke-StaticPreflight $manifest
        Write-Output 'UP2_CROSS_MESH_CONSERVATIVE_TRANSFER_V1_PREFLIGHT=PASS'
        Write-Output $result.staticOutput
        Write-Output $result.oracleOutput
        exit 0
    }
    catch { Write-Error $_.Exception.ToString(); exit 2 }
}

$lockStream = $null; $runDir = $null; $process = $null; $stdoutTask = $null; $stderrTask = $null
$failureReason = $null; $status = 'capture_failure'; $runnerExitCode = 1; $executionStarted = $false
$startCount = 0; $timedOut = $false; $processId = $null; $exitCode = $null; $stdout = ''; $stderr = ''
$preProcesses = @(); $postProcessesFirst = @(); $postProcessesSecond = @(); $postflightError = $null
$preHashes = [ordered]@{}; $postHashes = [ordered]@{}; $hashChanges = [ordered]@{}; $ownedFilesUnchanged = $false
$streamsCaptured = $false; $killRecord = $null; $startedAtUtc = $null; $endedAtUtc = $null; $durationMs = $null

try {
    if (Test-Path -LiteralPath $lockPath) { throw "Existing runtime lock refuses overwrite: $lockPath" }
    $lockStream = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    if (@(Get-ChildItem -LiteralPath $scriptRoot -Directory -Filter 'run_*').Count -ne 0) { throw 'Existing runtime receipt directory refuses overwrite' }
    $runDir = Join-Path $scriptRoot ('run_' + (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff') + '_' + [Guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($runDir) | Out-Null
}
catch { if ($null -ne $lockStream) { $lockStream.Dispose() }; Write-Error $_.Exception.ToString(); exit 2 }

try {
    $manifest = Read-Manifest
    $entries = Get-Entries $manifest
    $preProcesses = @(Get-JuliaDescProcesses)
    Write-JsonFile (Join-Path $runDir 'processes_before.json') $preProcesses
    if ($preProcesses.Count -ne 0) { throw 'preflight found Julia/DESC processes; invocation refused' }
    $preHashes = Get-Hashes $entries; Assert-Hashes $manifest $preHashes
    Write-JsonFile (Join-Path $runDir 'owned_hashes_before.json') $preHashes
    $runnerHash = ((Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash).ToLowerInvariant()
    if ($runnerHash -ne ([string]$manifest.runner_sha256).ToLowerInvariant()) { throw 'runner self-hash mismatch' }

    $env:JULIA_NUM_THREADS = '1'; $startedAtUtc = (Get-Date).ToUniversalTime()
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'julia'; $psi.Arguments = '--startup-file=no --history-file=no --project=. test/RuntimeV4/UP2CrossMeshConservativeTransfer/cross_mesh_conservative_transfer_v1_tests.jl'
    $psi.WorkingDirectory = $repoRoot; $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process; $process.StartInfo = $psi; $startCount++
    if (-not $process.Start()) { throw 'Julia process did not start' }
    $executionStarted = $true; $processId = $process.Id
    $stdoutTask = $process.StandardOutput.ReadToEndAsync(); $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit([int]($TimeoutSeconds * 1000))) {
        $timedOut = $true; $status = 'timeout'; $failureReason = "Julia exceeded timeoutSeconds=$TimeoutSeconds"
        $killRecord = Stop-OwnedProcessTree -RootProcessId ([int]$processId); [void]$process.WaitForExit(5000)
    } else { [void]$process.WaitForExit() }
    $stdout = Read-StreamTask $stdoutTask; $stderr = Read-StreamTask $stderrTask; $streamsCaptured = $true
    $exitCode = [int]$process.ExitCode; $endedAtUtc = (Get-Date).ToUniversalTime()
    if (-not $timedOut) { if ($exitCode -eq 0) { $status = 'runtime_complete'; $runnerExitCode = 0 } else { $status = 'child_nonzero'; $failureReason = "Julia exited with code $exitCode" } }
}
catch { if ($null -eq $failureReason) { $failureReason = $_.Exception.ToString() }; if (-not $executionStarted) { $status = 'preflight_failure' }; elseif (-not $timedOut) { $status = 'capture_failure' } }
finally {
    if ($null -ne $process -and $executionStarted -and -not $streamsCaptured) { try { $stdout = Read-StreamTask $stdoutTask; $stderr = Read-StreamTask $stderrTask; $streamsCaptured = $true } catch { $failureReason = 'stream capture failed: ' + $_.Exception.ToString() } }
    if ($null -ne $process) { $process.Dispose() }
    Write-TextFile (Join-Path $runDir 'julia.stdout.raw') $stdout; Write-TextFile (Join-Path $runDir 'julia.stderr.raw') $stderr
    try { $postProcessesFirst = @(Get-JuliaDescProcesses) } catch { $postflightError = $_.Exception.ToString() }
    Write-JsonFile (Join-Path $runDir 'processes_after_first.json') $postProcessesFirst
    Start-Sleep -Milliseconds 250
    try { $postProcessesSecond = @(Get-JuliaDescProcesses) } catch { $postflightError = $_.Exception.ToString() }
    Write-JsonFile (Join-Path $runDir 'processes_after_second.json') $postProcessesSecond
    try { $postHashes = Get-Hashes (Get-Entries $manifest); $hashChanges = Compare-Hashes $preHashes $postHashes $manifest } catch { $failureReason = 'postflight hash inspection failed: ' + $_.Exception.ToString() }
    Write-JsonFile (Join-Path $runDir 'owned_hashes_after.json') $postHashes; Write-JsonFile (Join-Path $runDir 'owned_hash_changes.json') $hashChanges
    $ownedFilesUnchanged = ($hashChanges.Count -eq 0 -and $postHashes.Count -eq $preHashes.Count)
    $postZero = ($null -eq $postflightError -and $postProcessesFirst.Count -eq 0 -and $postProcessesSecond.Count -eq 0)
    if (-not $ownedFilesUnchanged -or -not $postZero) { $runnerExitCode = 1; if ($status -ne 'timeout') { $status = 'postflight_failure' } }
    if ($null -eq $endedAtUtc) { $endedAtUtc = (Get-Date).ToUniversalTime() }; if ($null -ne $startedAtUtc) { $durationMs = ($endedAtUtc - $startedAtUtc).TotalMilliseconds }
    Write-TextFile (Join-Path $runDir 'exit_code.txt') ($(if ($null -eq $exitCode) { 'NOT_CAPTURED' } else { [string]$exitCode }))
    Write-JsonFile (Join-Path $runDir 'thread.json') ([ordered]@{ requested = '1'; environment = [string]$env:JULIA_NUM_THREADS; executionStarted = $executionStarted })
    Write-JsonFile (Join-Path $runDir 'run_metadata.json') ([ordered]@{ schema = 'DeclaredCrossMeshConservativeTransferRunMetadataV1'; status = $status; command = $commandText; workingDirectory = $repoRoot; receiptDirectory = $runDir; timeoutSeconds = $TimeoutSeconds; timeoutClassified = $timedOut; startedOnce = ($startCount -eq 1); startCount = $startCount; executionStarted = $executionStarted; processId = $processId; exitCode = $exitCode; startedAtUtc = $startedAtUtc; endedAtUtc = $endedAtUtc; durationMs = $durationMs; juliaNumThreads = [string]$env:JULIA_NUM_THREADS; preflightProcessCount = $preProcesses.Count; postflightFirstProcessCount = $postProcessesFirst.Count; postflightSecondProcessCount = $postProcessesSecond.Count; postflightZeroJuliaDesc = $postZero; ownedFileCount = $preHashes.Count; ownedFilesUnchanged = $ownedFilesUnchanged; streamsCaptured = $streamsCaptured; autoRetry = $false; failure = $failureReason; killRecord = $killRecord })
    Write-JsonFile (Join-Path $runDir 'capture_failure.json') ([ordered]@{ schema = 'DeclaredCrossMeshConservativeTransferCaptureFailureV1'; status = $status; captureFailure = ($status -eq 'capture_failure'); timeout = $timedOut; failure = $failureReason; receiptDirectory = $runDir })
    if ($null -ne $killRecord) { Write-JsonFile (Join-Path $runDir 'timeout_kill.json') $killRecord }
    if ($null -ne $lockStream) { $lockStream.Dispose() }
}

if ($runnerExitCode -ne 0) { exit 1 }
exit 0
