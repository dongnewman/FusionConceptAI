# N06 R10 independent static precheck

Status: `ready_for_serial_focused_r10` (static only; `accepted=false`). Reviewer: independent Luna, different from the N06 author.

The frozen implementation inputs were inspected at the current checkout. The N06 production source, focused test, fixture, and runner were unchanged during this review. The R9 raw focused attempt remains immutable and is retained as a real `program_exception` receipt: exit `1`, with actual-A `28/28`, typed-index `3/3`, and source mutation `31/31` before the test terminated on the stale static-control count. R9 therefore does not count as R10 execution or acceptance.

## Findings

- `test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json` has exactly 14 `static_negative_controls`, all unique. The IDs are `duplicate_resource_port_id`, `forged_source_locator`, `forged_source_type`, `same_dimension_exponent_mismatch`, `missing_power_flow_partner`, `foreign_valid_flow_link`, `reordered_network_dynamic_path`, `wrong_mutation_kind_for_target`, `relabeled_mutation_id`, `detached_projection`, `detached_g1_occurrence`, `foreign_e0_binding`, `missing_source_selector`, and `wrong_source_selector`.
- The test enforces the exact 14-element set and cardinality at lines 262-273. The fixture also contains exactly five `mapping_negative_controls` and five `mutations`.
- The five mapping target-delta controls are exercised individually at lines 276-300 through `_n06_expect_new_mapping_error`; the helper requires a newly introduced source-derived error and an `ArgumentError`. The fixture labels are checked as coverage labels and are not used to route production classification.
- The five mutation rows are consumed by an unconditional `for row in _N06_FIXTURE.mutations` at lines 225-238. Each call derives the spec by row id, invokes `G.n06_validate_mutation`, checks field path/status/error/original-versus-mutated value and changed input hash, and requires compile/provider/solver counters all zero. No early return or conditional gate bypasses these rows.
- The two newly required selector controls execute the real projection path. `missing_source_selector` deletes the actual `G._N06_G1_ROLE_SELECTORS[:source]`, calls `G.n06_projection_from_a(package,e0)`, asserts the targeted authored-selector error, and restores the entry in `finally` (lines 342-359). `wrong_source_selector` replaces the actual selector with the same ledger/equation/side but `port_index=99`, calls the same production projection, asserts the targeted source-match error, and restores it (lines 360-381). They occur after the preceding controls and are not skipped by an uncaught test-time exception in the source text.
- The production source resolves selectors with `get(..., nothing)` at line 319 and the source-derived join/projection path remains the authority. Current source/test/fixture hashes are recorded in `input_hashes.json`; G1/G2/G3, E0, integration, and core contract snapshots were also captured for drift detection.

## Protected evidence and limits

The R9 evidence is preserved, including its real exit-1 receipt and stdout/stderr hashes. This review performs no Julia/DESC execution, so it does not validate runtime behavior, process receipts, mesh/provider calls, physical semantics, or engineering execution. It grants no B04, physical, engineering, provider, mesh, or R01-R10 credit. `ready_for_serial_focused_r10` means only that the R10 test-only shape is statically ready for a separately authorized serial run; it is not a focused-run pass.

