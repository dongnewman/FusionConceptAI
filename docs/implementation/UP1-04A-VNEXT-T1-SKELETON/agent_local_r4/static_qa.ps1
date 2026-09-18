$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$contract = Join-Path $repo 'src\Contracts\CandidateStatePackageV5Next.jl'
$integration = Join-Path $repo 'src\GenomeV5\Integration\VNextGenomeV5Integration.jl'
$module = Join-Path $repo 'src\FusionConceptAI.jl'
foreach ($path in @($contract, $integration, $module)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing QA input: $path" }
}
$c = Get-Content -LiteralPath $contract -Raw
$i = Get-Content -LiteralPath $integration -Raw
$m = Get-Content -LiteralPath $module -Raw
$all = $c + "`n" + $i

foreach ($token in @(
    'VNextT1NoLegacyReceiptV1', 'vnext_t1_no_legacy_receipt_v1',
    'legacy_refs::NTuple{0,QualifiedRefV1}',
    'vnext_t1_package_schema_hash_v1', 'vnext_t1_package_canonicalization_hash_v1',
    'vnext_t1_package_profile_hash_v1', 'package_schema_version',
    'package_canonicalization_version', 'package_profile_version',
    'package_schema_hash', 'package_canonicalization_hash', 'package_profile_hash',
    'package_hash = canonical_hash', '_vnext_t1_validate_feedback_order',
    'feedback canonical order mismatch', '(:g3_child_terminal_deferred,)',
    'unknown or multiple T0 gaps', 'T0 child/gap semantic mismatch',
    'T0 child kind/order mismatch', 'T0 child gap must be all typed absent',
    'T0 no-gap state must be all present',
    'VNEXT_T1_FROZEN_G1_CONTRACT_REF_V1', 'VNEXT_T1_FROZEN_G2_CONTRACT_REF_V1',
    'VNEXT_T1_FROZEN_G3_CONTRACT_REF_V1',
    'VNEXT_T1_FROZEN_G3_REALIZATION_CONTRACT_REF_V1',
    'VNEXT_T1_FROZEN_G3_CONTROL_CONTRACT_REF_V1',
    'VNEXT_T1_FROZEN_G3_BINDING_CONTRACT_REF_V1',
    'VNEXT_T1_FACTORY_IDS_V1', 'VNEXT_T1_FACTORY_VERSIONS_V1',
    '_vnext_t1_expected_factory_identity', 'factory result factory ID mismatch',
    'factory result factory version mismatch', 'factory result contract is not frozen',
    'child envelope frozen contract mismatch',
    '_vnext_t1_owned_bytes', 'bytes::VNextT1CanonicalBytesV1',
    'owned byte/hash join mismatch',
    '_vnext_t1_validate_present_child_body', 'child envelope kind',
    'child envelope source', 'absent child receipt envelope',
    'output.g1', 'output.g2', 'output.g3', 'output.children', 'output.feedback',
    'local_checked_present', 'claim_ceiling', 'prepared_not_executed',
    'terminal_deferred', 'fail_closed')) {
    if ($all -notmatch [regex]::Escape($token)) { throw "required token absent: $token" }
}
foreach ($forbidden in @(
    'GenomeV5MigrationReceipt', 'v5_fresh_migration_receipt',
    'integrate_genome_v5(', 'Base.include(', 'read(', 'run(',
    '::Any', '::NamedTuple', 'Tuple{Vararg')) {
    if ($all -match [regex]::Escape($forbidden)) { throw "forbidden token present: $forbidden" }
}
if ($m -match 'CandidateStatePackageV5Next|VNextGenomeV5Integration') {
    throw 'T1 additive files must remain excluded from the main module'
}
if ($i -match 'isempty\(transport\.gaps\)') {
    throw 'T1 snapshot must admit the exact known T0 child gap'
}
if ($c -match '(?m)^\s*(bytes|source_bytes|declaration_bytes|semantic_body_bytes|factory_receipt_bytes)\s*::\s*VNextT0LocalBytesV1') {
    throw 'T1 projections must not retain mutable T0 byte-vector fields'
}
if ($c -match 'migration_receipt|migration') {
    throw 'T1 source must not retain migration receipt terminology/dependencies'
}
$matrix = @(
    'no_recheck -> terminal_deferred/package_absent',
    'unknown_or_multiple_gap -> fail_closed/package_absent',
    'child_gap_without_absent_child -> fail_closed/package_absent',
    'absent_child_without_known_gap -> fail_closed/package_absent',
    'legacy_receipt_or_nonempty_legacy_refs -> fail_closed/package_absent',
    'package_owned_schema_hash_drift -> fail_closed/package_absent',
    'package_owned_canonicalization_hash_drift -> fail_closed/package_absent',
    'package_owned_profile_hash_drift -> fail_closed/package_absent',
    'feedback_order_or_duplicate_id -> fail_closed/package_absent',
    'present_child_envelope_join -> fail_closed/package_absent',
    'absent_child_typed_join -> fail_closed/package_absent',
    'gap_with_mixed_or_wrong_order_children -> fail_closed/package_absent',
    'no_gap_with_absent_or_wrong_order_children -> fail_closed/package_absent',
    'self_consistent_factory_id_version_or_contract_forgery -> fail_closed/package_absent',
    'mutable_projection_bytes_or_hash_drift -> fail_closed/package_absent',
    'exact_checked_present_t0 -> prepared_not_executed/contract_only'
)
Write-Output ('STATIC_NEGATIVE_MATRIX=' + $matrix.Count)
Write-Output 'STATIC_QA=PASS'
Write-Output 'RUNTIME=NOT_RUN'
Write-Output 'T0=UNRESOLVED'
Write-Output 'T1=PREPARED_NOT_EXECUTED'
