$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$contract = Join-Path $root 'src\Contracts\CandidateStatePackageV5Next.jl'
$integration = Join-Path $root 'src\GenomeV5\Integration\VNextGenomeV5Integration.jl'
$module = Join-Path $root 'src\FusionConceptAI.jl'

foreach ($path in @($contract, $integration, $module)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "missing static-QA input: $path"
    }
}
$contractText = Get-Content -LiteralPath $contract -Raw
$integrationText = Get-Content -LiteralPath $integration -Raw
$moduleText = Get-Content -LiteralPath $module -Raw

foreach ($token in @(
    'CandidateStatePackageV5Next', 'VNextT1ComponentCountReceiptV1',
    'VNextT1ExpectedRecheckV1', 'VNextT1PriorBundleSnapshotV1',
    'canonical_json(transport)', 'vnext_t0_local_bundle_hash_recompute_v1',
    'output.g1', 'output.g2', 'output.g3', 'output.children', 'output.feedback',
    'VNEXT_T1_AXIS_IDS_V1', 'payload-schema', 'evidence-receipt',
    'VNEXT_T1_AXIS_VERSION_V1', 'factory_result_hash', 'factory_axes',
    'prior_bundle_bytes', 'prior_bundle', 'output_hash',
    'output_projection', 'expected_factory_axes',
    'receipt bytes do not equal canonical result envelope',
    'feedback body candidate', 'feedback body source',
    'feedback body declaration', 'feedback body target ref',
    'child_identity_hash', 'target_declaration_identity_hash',
    'local_checked_present', 'resolution', 'accepted', 'contract_only',
    'terminal_deferred', 'fail_closed', 'labels=()',
    'v5_fresh_migration_receipt')) {
    if (($contractText + "`n" + $integrationText) -notmatch [regex]::Escape($token)) {
        throw "required contract token absent: $token"
    }
}
if (($contractText + "`n" + $integrationText) -match '::Any|::NamedTuple|::Tuple\{Vararg') {
    throw 'R3 requires closed concrete fields; Any/open NamedTuple/Vararg found'
}
if ($contractText -match 'semantic_body::|recheck::|output::VNextAuthority|transport::VNextT0') {
    throw 'R3 package/gate retains a transitive open T0 body/output/transport field'
}
if ($integrationText -match 'canonical_json\(output\)') {
    throw 'R3 must canonicalize the closed output projection, not the open T0 output'
}
if ($moduleText -match 'CandidateStatePackageV5Next|VNextGenomeV5Integration') {
    throw 'T1 skeleton must remain excluded from FusionConceptAI.jl'
}
foreach ($forbidden in @('integrate_genome_v5(', 'read(', 'run(', 'Base.include(')) {
    if (($contractText + "`n" + $integrationText) -match [regex]::Escape($forbidden)) {
        throw "forbidden runtime/legacy call present: $forbidden"
    }
}
$negativeMatrix = @(
    @{ case = 'missing_t0_recheck'; expected = 'terminal_deferred/package_absent' },
    @{ case = 'wrong_t0_gate'; expected = 'fail_closed/package_absent' },
    @{ case = 'prior_bundle_bytes_or_hash_mismatch'; expected = 'fail_closed/package_absent' },
    @{ case = 'layer_factory_axes_mistaken_for_outer_local_axes'; expected = 'fail_closed/package_absent' },
    @{ case = 'receipt_envelope_mutation_or_self_hash_only'; expected = 'fail_closed/package_absent' },
    @{ case = 'declaration_axis_or_source_receipt_join_mismatch'; expected = 'fail_closed/package_absent' },
    @{ case = 'feedback_body_candidate_source_declaration_target_mismatch'; expected = 'fail_closed/package_absent' },
    @{ case = 'feedback_target_body_hash_mismatch'; expected = 'fail_closed/package_absent' },
    @{ case = 'present_child_body_or_identity_mismatch'; expected = 'fail_closed/package_absent' },
    @{ case = 'absent_child_status_reason_receipt_source_path_mismatch'; expected = 'fail_closed/package_absent' },
    @{ case = 'package_schema_canonical_profile_identity_mismatch'; expected = 'fail_closed/package_absent' },
    @{ case = 'exact_checked_present_gate'; expected = 'prepared_not_executed/contract_only' }
)
foreach ($row in $negativeMatrix) {
    if ([string]::IsNullOrWhiteSpace($row.case) -or [string]::IsNullOrWhiteSpace($row.expected)) {
        throw 'negative matrix row is incomplete'
    }
}
Write-Output ('STATIC_NEGATIVE_MATRIX=' + $negativeMatrix.Count)
Write-Output 'STATIC_QA=PASS'
Write-Output 'RUNTIME=NOT_RUN'
Write-Output 'T0=UNRESOLVED'
Write-Output 'T1=PREPARED_NOT_EXECUTED'
