$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../../../..')).Path
$julia = 'C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe'
$raw = Join-Path $PSScriptRoot 'raw'
New-Item -ItemType Directory -Force -Path $raw | Out-Null

function Invoke-ReviewRun([string]$name, [string]$testPath) {
    $stdout = Join-Path $raw ($name + '_stdout.txt')
    $stderr = Join-Path $raw ($name + '_stderr.txt')
    $start = [DateTime]::UtcNow
    $p = Start-Process -FilePath $julia -ArgumentList @('--project=.', $testPath) -WorkingDirectory $root -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    $pidValue = $p.Id
    $p.WaitForExit()
    $end = [DateTime]::UtcNow
    $record = [ordered]@{
        name = $name
        pid = $pidValue
        utc_start = $start.ToString('o')
        utc_end = $end.ToString('o')
        exit_code = $p.ExitCode
        command = "$julia --project=. $testPath"
        cwd = $root
        stdout_path = $stdout
        stderr_path = $stderr
    }
    $record | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $raw ($name + '_process.json'))
}

Invoke-ReviewRun 'g1_focused' 'test/GenomeV5/G1/g1_source_authority_factory_v1_tests.jl'
Invoke-ReviewRun 'g2_focused' 'test/GenomeV5/G2/g2_source_authority_factory_v1_tests.jl'
Invoke-ReviewRun 'g1_diffusion_regression' 'test/GenomeV5/G1/diffusion_v1_contract_tests.jl'
Invoke-ReviewRun 'g1_up1_regression' 'test/GenomeV5/G1/up1_g1_contract_tests.jl'
Invoke-ReviewRun 'g2_metric_regression' 'test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl'
Invoke-ReviewRun 'g2_up1_regression' 'test/GenomeV5/G2/up1_g2_contract_tests.jl'
Invoke-ReviewRun 'g1_wrong_provenance_probe' 'docs/implementation/AD-49/F0-G1-G2-SOURCE-AUTHORITY-FACTORIES/independent_review_r1/provenance_probe_g1.jl'
Invoke-ReviewRun 'g2_wrong_provenance_probe' 'docs/implementation/AD-49/F0-G1-G2-SOURCE-AUTHORITY-FACTORIES/independent_review_r1/provenance_probe_g2.jl'
