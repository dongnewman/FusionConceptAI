$ErrorActionPreference = 'Stop'
$root = 'D:\006-Programing\LMC\FusionConceptAI'
Set-Location $root
Write-Output ('HEAD=' + (& git rev-parse HEAD))
Write-Output 'INPUT_HASHES'
$paths = @(
  'src/RuntimeV4/M4Isolated/ManufacturedEquationIRV1.jl',
  'src/RuntimeV4/M4Isolated/ManufacturedResidualLoweringV1.jl',
  'src/RuntimeV4/M4Isolated/ManufacturedDiscreteControlV1.jl',
  'test/RuntimeV4/M4Isolated/manufactured_discrete_control_v1_tests.jl',
  'test/RuntimeV4/M4Isolated/oracles/discrete_control_oracle_v1.py')
function Hash-File([string]$path) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($path)))).Replace('-', '').ToLower() }
  finally { $sha.Dispose() }
}
foreach ($path in $paths) { Write-Output ($path + ' ' + (Hash-File $path)) }
Write-Output 'SHARED_TRACKED_DIFF'
& git diff --name-only -- src/RuntimeV4/FusionRuntimeV4.jl src/RuntimeV4/SpatialRuntimeV4.jl Project.toml Manifest.toml
Write-Output 'FORBIDDEN_SYMBOL_SCAN'
$scan = & rg -n 'assemble_matrix|bind_candidate|invoke_provider|CandidateStatePackageV5|ForwardChainContextV4|RuntimeEvidenceV4' src/RuntimeV4/M4Isolated test/RuntimeV4/M4Isolated 2>$null
if ($LASTEXITCODE -eq 1) { Write-Output 'no-forbidden-symbols-found' } else { $scan }
Write-Output 'ACTIVE_PROCESSES'
Get-Process | Where-Object { $_.ProcessName -match 'julia|python|desc|gridap' } | Select-Object Id,ProcessName | Format-Table -HideTableHeaders
Write-Output 'REVIEWER_BOUNDARY'
Write-Output 'No source/test/oracle/shared file writes; only independent_review_r1 evidence directory is authorized.'
