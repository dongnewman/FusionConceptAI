$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\..')).Path
$raw = Join-Path $PSScriptRoot 'raw'
New-Item -ItemType Directory -Force -Path $raw | Out-Null
$julia = (Get-Command julia -ErrorAction Stop).Source

function Invoke-Captured([string]$name, [string[]]$arguments) {
    $start = [DateTime]::UtcNow
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $julia
    $psi.WorkingDirectory = $repo
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Arguments = (($arguments | ForEach-Object { '"' + $_.Replace('"','\\"') + '"' }) -join ' ')
    $p = [System.Diagnostics.Process]::new()
    $p.StartInfo = $psi
    [void]$p.Start()
    $processId = $p.Id
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $end = [DateTime]::UtcNow
    $stdoutPath = Join-Path $raw ($name + '_stdout.txt')
    $stderrPath = Join-Path $raw ($name + '_stderr.txt')
    [IO.File]::WriteAllText($stdoutPath, $stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($stderrPath, $stderr, [Text.UTF8Encoding]::new($false))
    $record = [ordered]@{
        name = $name; pid = $processId; utc_start = $start.ToString("yyyy-MM-ddTHH:mm:ss.fffffff'Z'"); utc_end = $end.ToString("yyyy-MM-ddTHH:mm:ss.fffffff'Z'"); exit_code = $p.ExitCode
        command = ($julia + ' ' + ($arguments -join ' ')); cwd = $repo.Replace('\','/')
        stdout_path = ('docs/implementation/AD-49/F0-G1-G2-SOURCE-AUTHORITY-FACTORIES/independent_review_r2/raw/' + $name + '_stdout.txt')
        stderr_path = ('docs/implementation/AD-49/F0-G1-G2-SOURCE-AUTHORITY-FACTORIES/independent_review_r2/raw/' + $name + '_stderr.txt')
    }
    $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $raw ($name + '_process.json')) -Encoding utf8
    if ($p.ExitCode -ne 0) { throw "$name exited $($p.ExitCode)" }
}

$pre = Get-Process -Name julia -ErrorAction SilentlyContinue | Select-Object Id,ProcessName,Path
$pre | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $raw 'preflight_julia_processes.json') -Encoding utf8
if ($pre) { throw 'preflight found an existing Julia process; no Julia command was started' }

Invoke-Captured 'g1_focused_r2' @('--startup-file=no','--project=.','test/GenomeV5/G1/g1_source_authority_factory_v1_tests.jl')
Invoke-Captured 'g2_focused_r2' @('--startup-file=no','--project=.','test/GenomeV5/G2/g2_source_authority_factory_v1_tests.jl')
Invoke-Captured 'g1_diffusion_regression_r2' @('--startup-file=no','--project=.','test/GenomeV5/G1/diffusion_v1_contract_tests.jl')
Invoke-Captured 'g1_up1_regression_r2' @('--startup-file=no','--project=.','test/GenomeV5/G1/up1_g1_contract_tests.jl')
Invoke-Captured 'g2_metric_regression_r2' @('--startup-file=no','--project=.','test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl')
Invoke-Captured 'g2_up1_regression_r2' @('--startup-file=no','--project=.','test/GenomeV5/G2/up1_g2_contract_tests.jl')

$post = Get-Process -Name julia -ErrorAction SilentlyContinue | Select-Object Id,ProcessName,Path
$post | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $raw 'postflight_julia_processes.json') -Encoding utf8
if ($post) { throw 'postflight found a Julia process after serial checks' }
