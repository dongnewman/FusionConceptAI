# E1-N05 independent static precheck

Verdict: **changes_requested** (static precheck only; not acceptance).
Captured UTC: `2026-09-14T03:10:34.264408+00:00`. Frozen source/test/fixture/runner hashes are in `report.json`; any change invalidates this report.

## Blocking findings

- **law_source_path_is_hashed_or_bound**: No source.path occurs in _n05_law_source_hash (line 133); path is only nonempty-checked by locator
- **endpoint_source_path_and_type_are_bound**: _n05_endpoint_source line 278 hashes endpoint content but omits path/source_type; caller supplies hardcoded field paths
- **g1_occurrence_exact_source_path_and_type_join**: No endpoint.occurrence.source.path/source_type equality assertions in _n05_authority_errors (occurrence block line 361)
- **mutations_are_source_and_invariant_derived**: _n05_spec_value line 464 and _n05_mutated_declaration line 480 branch on spec.id; expected_error/expected_resolution are not consumed
- **mutation_spec_field_path_is_used_as_source_locator**: spec.field_path is emitted as receipt.error_path (line 530) but does not select/verify the mutated declaration field

## Passing boundary checks

- `authored_law_expression_ref_hash_participate`: law hash helper line 133 hashes ref/expression/signs/unit; declaration body includes law
- `g1_occurrence_join_uses_four_identity_fields`: _n05_authority_errors occurrence search line 361 uses equation_id/port_side/port_index/ledger_id
- `g2_interface_ref_and_region_join`: Interface lookup line 332 matches interface_ref and checks left/right region IDs
- `flux_unit_has_separate_authored_n05_provenance`: N05 unit source checks occur in _n05_authority_errors near line 371; G1 occurrence carries provenance only
- `e0_program_exception_three_state_preserved`: _n05_e0_status line 384 maps valid/program_exception/fail_closed and retains E0_program_exception
- `actual_a_package_and_e0_binding_are_used`: Test _n05_actual_package integrates G1/G2/G3 at line 66 and calls E0 A binding at line 70
- `positive_scope_is_contract_ready_only`: Acceptance and manifest retain review_pending/accepted=false and contract_only; E0 acceptance carries no physical/provider credit
- `r1_test_api_mismatch_is_fixed`: Deferred assertion uses resolution at test line 131; no deferred.status remains
- `fixture_has_five_named_mutations`: Fixture mutation count=5; labels=['N05-01', 'N05-02', 'N05-03', 'N05-04', 'N05-05']

## Evidence and limits

- `command_receipts.json` records timestamp, stdout, stderr, and real exit for `git diff --check`, process probe, and JSON parsing.
- E0 accepted_limited and E1 review_pending/contract_only boundaries were read; no physical, provider, mesh, engineering, B00, B04, or R-credit was asserted.
- No Julia/DESC was started. The result is `changes_requested`; it cannot authorize dynamic execution until the blockers are repaired and the author snapshot is refrozen.
