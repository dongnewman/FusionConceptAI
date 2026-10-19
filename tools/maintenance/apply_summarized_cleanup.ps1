[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$WorkspaceRoot,
    [Parameter(Mandatory = $true)][string]$PlanPath,
    [switch]$Apply
)

# One-time, file-only application of the 2026-10-19 user-authorized manifest.
# No recursive removal, wildcard expansion, Git cleanup or shell delegation.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $WorkspaceRoot).Path.TrimEnd('\', '/')
$expected = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\', '/')
if ($root -ne $expected) { throw "Workspace must be the repository containing this script: $expected" }
$prefix = $root + [IO.Path]::DirectorySeparatorChar
$recordDir = Join-Path $root 'docs/implementation/WORKSPACE-CONSOLIDATION-20261019'
$plan = (Resolve-Path -LiteralPath $PlanPath).Path
if ($plan -ne (Join-Path $recordDir 'deletion_plan.jsonl')) { throw 'Unexpected plan location' }
$receiptPath = Join-Path $recordDir 'deletion_receipt.jsonl'
$summaryPath = Join-Path $recordDir 'deletion_execution.json'
if ($Apply -and (Test-Path -LiteralPath $receiptPath)) { throw 'Existing deletion receipt: inspect it before another application' }
if (Get-Process -Name julia -ErrorAction SilentlyContinue) { throw 'Julia is running; no deletion permitted' }

$retired = @(
    'tools/up1_external_closure_r2/', 'tools/up1_external_closure_r3/', 'tools/up1_external_closure_r4/',
    'test/up1_external_closure_r2/', 'test/up1_external_closure_r3/', 'test/up1_external_closure_r4/',
    'tools/up4_reference_validation/', 'test/UP4ReferenceValidationV1/', 'test/UP4ReferenceValidationV10Review/'
)
$protected = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($item in (Get-Content -LiteralPath (Join-Path $recordDir 'retained_inputs.json') -Raw | ConvertFrom-Json)) {
    [void]$protected.Add($item.path)
}
$activeRoots = @(Get-Content -LiteralPath (Join-Path $recordDir 'active_keep_roots.json') -Raw | ConvertFrom-Json)
$checkedDirs = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
[void]$checkedDirs.Add($root)
$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

function Resolve-CheckedTarget([string]$rel) {
    if (!$rel -or $rel.Contains('\') -or $rel.Contains(':') -or $rel.StartsWith('/') -or
        $rel.Split('/').Where({ $_ -in @('', '.', '..') }).Count) { throw "Noncanonical path: $rel" }
    $full = [IO.Path]::GetFullPath((Join-Path $root $rel))
    if (!$full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Outside workspace: $rel" }
    if ($protected.Contains($rel)) { throw "Protected input in plan: $rel" }
    foreach ($active in $activeRoots) {
        if ($rel -eq $active -or $rel.StartsWith($active.TrimEnd('/') + '/', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Active work-order path in plan: $rel"
        }
    }
    $allowed = $rel.StartsWith('runs/') -or $rel.StartsWith('tmp/') -or
        $rel.StartsWith('docs/implementation/') -or $rel.StartsWith('tools/m5_search_contract_r2/evidence/') -or
        ($rel -in @('0', '3000000000)', 'test/runtime_v4_freegs_axisymmetric_lcfs_trace_tests.jl.after')) -or
        (!$rel.Contains('/') -and [IO.Path]::GetExtension($rel) -in @('.log', '.exit')) -or
        $rel.Split('/').Contains('__pycache__') -or $rel.StartsWith('.ruff_cache/') -or $rel.StartsWith('.pytest_cache/')
    foreach ($family in $retired) { if ($rel.StartsWith($family)) { $allowed = $true; break } }
    if (!$allowed -or $rel.StartsWith('docs/implementation/WORKSPACE-CONSOLIDATION-20261019/') -or
        $rel.StartsWith('docs/implementation/IMPLEMENTED-STATE-20261019/')) { throw "Outside cleanup scopes: $rel" }
    $dir = [IO.Path]::GetDirectoryName($full)
    while (!$checkedDirs.Contains($dir)) {
        $attributes = [IO.File]::GetAttributes($dir)
        if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Reparse parent: $dir" }
        [void]$checkedDirs.Add($dir)
        $dir = [IO.Path]::GetDirectoryName($dir)
    }
    return $full
}

$rows = [Collections.Generic.List[object]]::new()
$planHash = (Get-FileHash -LiteralPath $plan -Algorithm SHA256).Hash.ToLowerInvariant()
$totalBytes = [long]0
foreach ($line in [IO.File]::ReadLines($plan)) {
    $row = $line | ConvertFrom-Json
    if (!$seen.Add($row.path)) { throw "Duplicate plan path: $($row.path)" }
    if ($row.sha256 -notmatch '^[0-9a-f]{64}$' -or [long]$row.bytes -lt 0) { throw 'Invalid manifest hash/size' }
    $full = Resolve-CheckedTarget $row.path
    $item = Get-Item -LiteralPath $full -Force
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Not a regular file: $($row.path)"
    }
    if ($item.Length -ne [long]$row.bytes) { throw "Size changed before application: $($row.path)" }
    $rows.Add([pscustomobject]@{ Record = $row; FullPath = $full })
    $totalBytes += [long]$row.bytes
    if ($rows.Count % 10000 -eq 0) { Write-Output "Preflight checked $($rows.Count) files" }
}
$planned = Get-Content -LiteralPath (Join-Path $recordDir 'cleanup_plan_summary.json') -Raw | ConvertFrom-Json
if ($rows.Count -ne $planned.delete_files -or $totalBytes -ne $planned.delete_bytes) { throw 'Plan summary differs from manifest' }
Write-Output "Validated $($rows.Count) files, $totalBytes bytes, plan SHA256 $planHash"
if (!$Apply) { Write-Output 'Preflight only; no files deleted'; return }

$encoding = [Text.UTF8Encoding]::new($false)
$writer = [IO.StreamWriter]::new($receiptPath, $false, $encoding)
$deleted = 0
$deletedBytes = [long]0
$started = [DateTime]::UtcNow.ToString('o')
$failure = $null
try {
    foreach ($entry in $rows) {
        $row = $entry.Record
        $actual = (Get-FileHash -LiteralPath $entry.FullPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $row.sha256) { throw "Hash changed; stopped before deletion: $($row.path)" }
        Remove-Item -LiteralPath $entry.FullPath -Force
        if (Test-Path -LiteralPath $entry.FullPath) { throw "Target still exists: $($row.path)" }
        $writer.WriteLine((@{ path = $row.path; bytes = [long]$row.bytes; sha256 = $actual; status = 'deleted' } | ConvertTo-Json -Compress))
        $deleted++
        $deletedBytes += [long]$row.bytes
        if ($deleted % 5000 -eq 0) {
            $writer.Flush()
            Write-Output "Deleted $deleted / $($rows.Count) files; $deletedBytes bytes"
        }
    }
} catch {
    $failure = $_.Exception.Message
    throw
} finally {
    $writer.Dispose()
    $summary = [ordered]@{
        schema = 'hash-checked-file-only-cleanup-v1'; goal_state = 'paused'; plan_only = $false
        started_utc = $started; finished_utc = [DateTime]::UtcNow.ToString('o')
        plan_sha256 = $planHash; planned_files = $rows.Count; planned_bytes = $totalBytes
        deleted_files = $deleted; deleted_bytes = $deletedBytes; failure = $failure
        complete = ($null -eq $failure -and $deleted -eq $rows.Count)
        recursive_delete_used = $false; scientific_acceptance = $false
    }
    [IO.File]::WriteAllText($summaryPath, ($summary | ConvertTo-Json -Depth 5), $encoding)
}
Write-Output ($summary | ConvertTo-Json -Depth 5)
