$ErrorActionPreference = 'Stop'
$repo = (Get-Location).Path
$sourcePath = Join-Path $repo 'src/GenomeV5/UP2/VNextUP2ConsumerBridgeV1.jl'
$testPath = Join-Path $repo 'test/GenomeV5/UP2/VNextUP2ConsumerBridgeV1/vnext_up2_consumer_bridge_v1_tests.jl'
$source = [IO.File]::ReadAllText($sourcePath)
$test = [IO.File]::ReadAllText($testPath)
$trailing = @()
foreach ($p in @($sourcePath, $testPath)) {
    $n = 0
    foreach ($line in [IO.File]::ReadAllLines($p)) {
        $n++
        if ($line -match '[\t ]+$') { $trailing += "${p}:$n" }
    }
}
if ($trailing.Count -gt 0) { throw "trailing whitespace: $($trailing -join ', ')" }
$sourceMarkers = @('vnext_t2_up2_validate_input_v2(input)', 'aggregate.ledger', 'dgd_input_v1(', 'dgd_execute_v1(', ':typed_absent', ':terminal_deferred', 'formal_up_credit=false', 'formal_r_credit=false', 'ledger.gaps...', 'input.witness.gaps...')
foreach ($marker in $sourceMarkers) {
    if (-not $source.Contains($marker)) { throw "missing source marker: $marker" }
}
$testMarkers = @('t2_chain(edited_realization=true', 'formal_gate_verified === false', 'CandidateStatePackageV5NextV2', ':formal_gate_verified_false_synthetic_local', ':formal_b00_b04_receipts_not_supplied', 'unaccepted_result.dgd_invocation_count == 0', 'aggregate_mismatch.dgd_invocation_count == 0')
foreach ($marker in $testMarkers) {
    if (-not $test.Contains($marker)) { throw "missing test marker: $marker" }
}
Write-Output 'STATIC_SCOPE_CHECK=PASS'
Write-Output 'TRAILING_WHITESPACE_LINES=0'
Write-Output 'JULIA_PARSE_OR_EXECUTION=NOT_RUN'
Write-Output 'FORMAL_R3_PACKAGE_LINK=NOT_CHECKED'