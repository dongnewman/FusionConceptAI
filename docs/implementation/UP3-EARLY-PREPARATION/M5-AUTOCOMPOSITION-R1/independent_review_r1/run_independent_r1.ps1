$ErrorActionPreference = 'Stop'
$root = 'D:\006-Programing\LMC\FusionConceptAI'
$out = Join-Path $root 'docs\implementation\UP3-EARLY-PREPARATION\M5-AUTOCOMPOSITION-R1\independent_review_r1\raw'
New-Item -ItemType Directory -Force -Path $out | Out-Null

function Invoke-Recorded([string]$Name, [string]$Exe, [string[]]$Argv) {
    $stdout = Join-Path $out ($Name + '.stdout.raw')
    $stderr = Join-Path $out ($Name + '.stderr.raw')
    $combined = Join-Path $out ($Name + '.combined.raw')
    $start = (Get-Date).ToUniversalTime().ToString('o')
    $p = Start-Process -FilePath $Exe -ArgumentList $Argv -WorkingDirectory $root -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    $process_id = $p.Id
    $p.WaitForExit()
    $p.Refresh()
    $end = (Get-Date).ToUniversalTime().ToString('o')
    $exit_code = [int]$p.ExitCode
    [System.IO.File]::WriteAllBytes($combined, [System.IO.File]::ReadAllBytes($stdout) + [System.IO.File]::ReadAllBytes($stderr))
    $rec = [ordered]@{name=$Name; command=(($Exe + ' ') + ($Argv -join ' ')); cwd=$root; pid=$process_id; started_utc=$start; ended_utc=$end; exit_code=$exit_code; stdout_raw=(Split-Path $stdout -Leaf); stderr_raw=(Split-Path $stderr -Leaf); combined_raw=(Split-Path $combined -Leaf); stdout_bytes=(Get-Item $stdout).Length; stderr_bytes=(Get-Item $stderr).Length; stdout_sha256=(Get-FileHash $stdout -Algorithm SHA256).Hash.ToLower(); stderr_sha256=(Get-FileHash $stderr -Algorithm SHA256).Hash.ToLower(); combined_sha256=(Get-FileHash $combined -Algorithm SHA256).Hash.ToLower()}
    $rec | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 (Join-Path $out ($Name + '.process.json'))
    if ($exit_code -ne 0) { throw "$Name exit $exit_code" }
}

Invoke-Recorded 'python_oracle' 'python' @('test\RuntimeV4\M4Isolated\oracles\auto_composition_oracle_v1.py')
Invoke-Recorded 'julia_tests' 'julia' @('--startup-file=no','--history-file=no','test\RuntimeV4\M4Isolated\manufactured_auto_composition_v1_tests.jl')
