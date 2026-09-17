# E1-N05 independent static precheck R2

Verdict: **ready_for_focused_r2** (static only; not acceptance).
Captured UTC: `2026-09-14T03:31:07.066166+00:00`. Frozen hashes are in `report.json`; any author change invalidates this report.

## Blocking findings


## R1 repair evidence

- `law_canonical_path_and_type_checked`: _n05_authority_errors checks exact law path at line 363 and authored source type at line 361
- `law_ref_expression_sign_unit_hash_recomputed`: constructor computes law hash at line 168; validator recomputes source/law hash at lines 366/369
- `g1_occurrence_canonical_path_and_type_checked`: endpoint locator path/type are checked at lines 412-407
- `endpoint_and_unit_authored_path_type_checked`: unit path/type checks are at lines 422/420; mutation locator path/type guard at lines 575/576
- `mutation_dispatch_uses_field_path_and_kind`: registry lookup lines 313-318 matches both field_path and mutation_kind; implementation branches on binding.target
- `mutation_expected_fields_are_oracle_only`: expected_error/expected_resolution are absent from mutation implementation; tests compare fixture expectations after receipt construction
- `missing_declaration_five_rows_remain_authority_gap_terminal_deferred`: nil declaration branch returns equal values, authority_gap and terminal_deferred at lines 496-583; test covers five rows and equality at line 145
- `declaration_and_law_hashes_recomputed_on_declared_path`: declaration hash recomputation is at line 353; law hash mismatch is at line 369; mutation receipt carries original declaration hash
- `actual_a_join_and_contract_scope_preserved`: test builds actual A package and E0 binding; manifest remains review_pending/accepted=false contract_only and AD-24 denies physical/provider/B04 credit

## Commands and limits

- `command_receipts.json` contains command, timestamps, stdout, stderr, and real exit for diff-check, process probe, and JSON parse.
- No Julia/DESC was run. The verdict cannot authorize focused execution until blockers are addressed and hashes are refrozen.
