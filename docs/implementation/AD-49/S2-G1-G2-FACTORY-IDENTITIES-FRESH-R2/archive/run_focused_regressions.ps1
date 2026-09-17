$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\..')).Path
$target = Join-Path $root 'docs\implementation\AD-49\S2-G1-G2-FACTORY-IDENTITIES-FRESH-R2'
$raw = Join-Path $target 'raw'
$julia = 'C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe'
$tests = @(
  'test/GenomeV5/G1/g1_source_authority_factory_v1_tests.jl',
  'test/GenomeV5/G2/g2_source_authority_factory_v1_tests.jl',
  'test/GenomeV5/G1/diffusion_v1_contract_tests.jl',
  'test/GenomeV5/G1/up1_g1_contract_tests.jl',
  'test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl',
  'test/GenomeV5/G2/up1_g2_contract_tests.jl'
)
$results = @()
foreach ($test in $tests) {
  $slug = ($test -replace '[^A-Za-z0-9]+','_').Trim('_').ToLowerInvariant()
  $stdout = Join-Path $raw ("focused_{0}_stdout.txt" -f $slug)
  $stderr = Join-Path $raw ("focused_{0}_stderr.txt" -f $slug)
  $start = [DateTime]::UtcNow.ToString('o')
  $p = Start-Process -FilePath $julia -ArgumentList @('--project=.', $test) -WorkingDirectory $root -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -Wait
  $end = [DateTime]::UtcNow.ToString('o')
  $results += [ordered]@{name=$slug; test=$test; pid=$p.Id; utc_start=$start; utc_end=$end; exit_code=$p.ExitCode; stdout_path=$stdout; stderr_path=$stderr}
  if ($p.ExitCode -ne 0) { throw "focused/regression failed: $test exit=$($p.ExitCode)" }
}
$results | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $raw 'focused_regressions_processes.json')
Write-Output 'AD49_FOCUSED_REGRESSIONS=PASS'
