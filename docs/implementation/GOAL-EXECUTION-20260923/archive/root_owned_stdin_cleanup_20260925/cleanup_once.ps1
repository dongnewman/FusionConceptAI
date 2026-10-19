$ErrorActionPreference = 'Stop'
$targetPid = 75060
$expectedParent = 74100
$expectedCreation = [datetimeoffset]'2026-09-24T01:08:04.999469+08:00'
$row = Get-CimInstance Win32_Process -Filter "ProcessId=$targetPid"
if ($null -eq $row) { throw 'target_missing_before_cleanup' }
if ($row.Name -cne 'python.exe' -or $row.ParentProcessId -ne $expectedParent) { throw 'target_identity_mismatch' }
if (-not ($row.CommandLine.Contains('r2_protocol_freeze_20260923_t2_protocol_attempt9b') -and $row.CommandLine.Contains('r2_protocol_freeze_20260923_t2_protocol_attempt9c_final'))) { throw 'target_command_mismatch' }
$actualCreation = [datetimeoffset]$row.CreationDate
if ($actualCreation.ToUniversalTime().Ticks -ne $expectedCreation.ToUniversalTime().Ticks) { throw 'target_creation_mismatch' }
$children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$targetPid")
if ($children.Count -ne 0) { throw 'target_has_children' }
$row | Select-Object ProcessId,ParentProcessId,CreationDate,Name,CommandLine | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'before.json') -Encoding utf8
$handle = Get-Process -Id $targetPid
if ([math]::Abs(($handle.StartTime.ToUniversalTime() - $expectedCreation.UtcDateTime).TotalMilliseconds) -gt 1) { throw 'handle_generation_mismatch' }
$handle.Kill()
$handle.WaitForExit(10000) | Out-Null
$after = Get-CimInstance Win32_Process -Filter "ProcessId=$targetPid"
$parent = Get-CimInstance Win32_Process -Filter "ProcessId=$expectedParent"
[pscustomobject]@{ target_pid=$targetPid; target_absent=($null -eq $after); parent_pid=$expectedParent; parent_present=($null -ne $parent); creation_utc=$expectedCreation.ToUniversalTime().ToString('o'); command_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant() } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'after.json') -Encoding utf8
if ($null -ne $after) { throw 'target_still_present_after_cleanup' }
Get-Content -LiteralPath (Join-Path $PSScriptRoot 'after.json')
