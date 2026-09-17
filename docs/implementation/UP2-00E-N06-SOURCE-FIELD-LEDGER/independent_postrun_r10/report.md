# N06 focused R10 independent postrun review

## Verdict

Verdict: `pass_limited` for the executed N06 software/contract-test slice, pending Sol adjudication. The run does **not** accept N06 physical resolution, dimensioned G1→G3 source/field/return/heat law, formal B04, provider, mesh, engineering, or R01–R10 credit.

I am not the N06 author, repairer, or executor. This is a read-only postrun review. No Julia/DESC was run and no implementation, core document, focused evidence, or prior review directory was modified. The only writes are this new `independent_postrun_r10/` directory.

## Runtime evidence checked

`focused_r10/evidence_manifest.json`, `run_summary.json`, `process_receipt.json`, raw logs, input hashes and protected comparison were read directly.

- Command: `julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl`
- Main PID: `33836`
- UTC: `2026-09-14T06:17:04.9578748Z` → `2026-09-14T06:19:52.5473688Z`
- `exit.txt` is three bytes `30-0D-0A` (`0\r\n`), real exit `0`; it is not inferred from stdout.
- stdout: 3852 bytes, SHA-256 `d6975da0772b9945c73aa70e46237c4ce27372cb02e20d9419b50ac7c5e9bec3`
- stderr: 0 bytes, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- postflight: Julia `0`, DESC `0`; the current process sweep is also empty.
- The focused manifest records one serial run and no repair/rerun. R9 exit-1 evidence is retained under `focused_r9/`; R8 and all prior attempts remain separate and untouched.

The raw stdout contains the complete group summaries: G1 `47/47`, `21/21`; G2 `57/57`, `59/59`, `8/8`; G3 `49/49`, `35/35`, `23/23`; N06 actual-A `28/28`, typed occurrence index `3/3`, source-derived mutation `31/31`, and shared-owner/E0 boundary `40/40`.

## Source-derived mutation and selector audit

The actual focused test reads `n06_source_field_ledger_mapping_fixtures.json` and builds a candidate-specific `CandidateStatePackageV5` through the G1/G2/G3 child fixtures and `integrate_genome_v5`; it then creates E0 with `up2_candidate_physical_binding_from_a(package)` and projects N06 from that package. The five mutation rows are consumed by the unconditional loop at `test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl:225-238`. Each call goes through `G.n06_validate_mutation(package, e0, projection, spec)`, checks a changed mutated input hash and changed typed value, exact source path, status/error and zero compile/provider/solver counters.

The production path is source-derived. `n06_validate_mutation` first checks the projection against the actual package/E0 (`N06SourceFieldLedgerMappingV1.jl:809-830`), validates the mutation target against its field path/source locator/type, mutates a concrete typed G3 field (`:wrong_resource_port`, `:wrong_entry_account`, `:missing_control_link`, `:closure_balance_mismatch`, `:wrong_resource_kind` at lines 733-752), and classifies from the changed value and actual package relationships (`:invalid_ref`, `:invalid_closure`, or `:invalid_kind` at lines 755-807). `expected_error` is not read by the production classifier. The forged-oracle control at test lines 239-243 changes only the expected error to `:terminal_deferred` and still observes the source-derived `:invalid_ref`, confirming the label is an oracle and not a router.

The two selector controls are real production-path controls. At test lines 342-359, `missing_source_selector` deletes the actual `G._N06_G1_ROLE_SELECTORS[:source]`, calls `G.n06_projection_from_a(package,e0)`, asserts the targeted `ArgumentError`, and restores the selector in `finally`. At lines 360-381, `wrong_source_selector` changes the real selector to the same ledger/equation/side with `port_index=99`, calls the same production projection, asserts the targeted no-source-match error, and restores it in `finally`. The completed `40/40` group and `run_summary.json` record both controls as reached; this is stronger than a fixture-name-only assertion.

The source's exact selector and join checks are also visible at `N06SourceFieldLedgerMappingV1.jl:449-586`: four-field G1 occurrence keys, exact G2 boundary locator, selected G3 port/link/account/entry/closure, role kind, owner-account scope and conversion-law checks. Duplicate or absent source selectors are rejected by the real projection path. The focused test's five static and five mapping negative controls are exact-set checked; the old R9 stale count failure is not reused as runtime evidence.

## Deferred and fail-closed boundaries

The baseline valid-shaped authored sample is deliberately not admitted as a complete mapping: the test observes `conversion_same_dimension_mismatch` in baseline mapping errors and `n06_mapping_from_a` rejects it. `n06_mapping_admission(package,e0)` with no mapping returns `terminal_deferred` because the actual package lacks authoritative cross-layer source/field/return/heat semantics. These are distinct paths: a contradiction in a typed mapping is fail-closed, while absence of the authoritative mapping is deferred.

The source itself states that local G3 balance is not evidence of a G1→G3 conservation law. The present test and source do not establish the missing dimensioned G1→G3 conversion law, source/field/return/heat provenance, or owner-scope authority. The existence of a `power_from_effort_flow` contract rule and local G3 effort/flow values does not turn dimensionless G1 occurrences into physical power evidence. No provider, mesh, solver, engineering or physical stage is called.

## Frozen input and history checks

The 11-input `focused_r10/input_hashes_before.json` and `input_hashes_after.json` match. `protected_hash_comparison.json` independently records `all_unchanged=true` for N06 source/test/fixture/runner, E0, G1, G2, the four G3 sources and Integration. This review recomputes those current hashes in `hash_recheck.json`; no protected input drift was found. Existing R8/R9 failure history and all raw run artifacts remain immutable.

## Claim ceiling and open gate

This `pass_limited` applies only to the actual-A N06 software/contract test evidence represented by the R10 receipt. It does not close N06 semantic authority, UP2 total, G-I1/G-I2, UP1-04B, B00/B04, or any physical/engineering gate. The next gate still requires an authored, candidate-bound, content-hashed dimensioned source→field→return/heat/ledger mapping with exact provenance and independent formal receipts/checker under the frozen 50-row B04 protocol.
