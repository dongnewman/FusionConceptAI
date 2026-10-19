$ErrorActionPreference = 'Stop'
$leaf = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonId = 66196
$ownedShellPid = 72312
$python = Get-CimInstance Win32_Process -Filter "ProcessId=$pythonId"
$shell = Get-CimInstance Win32_Process -Filter "ProcessId=$ownedShellPid"
$all = @(Get-CimInstance Win32_Process)
$before = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
    python = $python | Select-Object ProcessId, ParentProcessId, Name, CreationDate, KernelModeTime, UserModeTime, CommandLine
    shell = $shell | Select-Object ProcessId, ParentProcessId, Name, CreationDate, CommandLine
    direct_children = @($all | Where-Object { $_.ParentProcessId -eq $pythonId -or $_.ParentProcessId -eq $ownedShellPid } | Select-Object ProcessId, ParentProcessId, Name, CreationDate, CommandLine)
}
$before | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $leaf 'r5_before.json') -Encoding utf8
if (-not $python -or -not $shell) { throw 'Expected pair absent; no cleanup' }
if ($python.ParentProcessId -ne $ownedShellPid -or $python.Name -ne 'python.exe' -or $shell.Name -ne 'pwsh.exe') { throw 'Identity mismatch; no cleanup' }
if ($python.CommandLine -ne '"D:\Users\Newman\anaconda3\python.exe" -B - test/GenomeV5/Integration/VNextT2FormalIndependentR1/build_coverage_map_r5.py') { throw 'Python command mismatch; no cleanup' }
if (-not $shell.CommandLine.Contains('python -B - test/GenomeV5/Integration/VNextT2FormalIndependentR1/build_coverage_map_r5.py')) { throw 'Shell command mismatch; no cleanup' }
if ($python.CreationDate.ToString('o') -ne '2026-09-23T23:38:13.2489280+08:00') { throw 'Python creation mismatch; no cleanup' }
if ($shell.CreationDate.ToString('o') -ne '2026-09-23T23:38:10.2416290+08:00') { throw 'Shell creation mismatch; no cleanup' }
if (@($all | Where-Object { $_.ParentProcessId -eq $pythonId }).Count -ne 0) { throw 'Python has child; no cleanup' }
if (@($all | Where-Object { $_.ParentProcessId -eq $ownedShellPid -and $_.ProcessId -ne $pythonId }).Count -ne 0) { throw 'Shell has unexpected child; no cleanup' }
Stop-Process -Id $pythonId -ErrorAction Stop
Start-Sleep -Milliseconds 300
Stop-Process -Id $ownedShellPid -ErrorAction Stop
Start-Sleep -Milliseconds 300
$after = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
    python_present = [bool](Get-CimInstance Win32_Process -Filter "ProcessId=$pythonId")
    shell_present = [bool](Get-CimInstance Win32_Process -Filter "ProcessId=$ownedShellPid")
}
$after | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $leaf 'r5_after.json') -Encoding utf8
if ($after.python_present -or $after.shell_present) { throw 'Target process remains' }
$after | ConvertTo-Json
