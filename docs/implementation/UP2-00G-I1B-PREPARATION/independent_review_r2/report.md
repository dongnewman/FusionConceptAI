# G-I1B source matrix R2 independent review

Verdict: `pass_limited`; `accepted=false`. This is a different-Luna, read-only static review of the R2 repair. No Julia/DESC was run.

The repaired matrix is the same 50-row inventory as R1: N01 through N10 each contain exactly five rows, with 50 unique IDs and 50 unique field paths. The R2 manifest records `changed_rows=[N05-05]` and `unchanged_other_rows=49`; the exact row diff is preserved in `source_matrix_r1/repair_r2/N05-05_row.diff`. The R1 `changes_requested` report and manifest remain immutable inputs.

N05-05 now records:

- field path `/n05/right_endpoint/unit`;
- source type `UnitSignature`;
- source owner `declaration.right_endpoint.unit.source.source_ref`;
- content hash `declaration.right_endpoint.unit.source.source_hash`;
- source kind `authored_E1_over_actual_A` and local ceiling `yes_local_accepted_limited`.

This is the production-backed expression. `src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl:292-296` constructs the endpoint unit source hash as `canonical_hash((endpoint_ref=endpoint_ref, unit=unit))`, and `:428-429` validates the same `endpoint.unit.source.source_hash`. The repaired row therefore no longer uses the unrelated `declaration.law.law_hash`; the R1 defect is closed. The production law hash remains a separate expression at lines 136-139 and is not authority for this endpoint-unit row.

The matrix preserves the required boundary: `source_kind` and `eligible_for_g1b_local_row` describe local source inventory/contract eligibility only. They do not represent formal B04 receipt eligibility. Authored E1 rows remain authored extensions over actual A; absent authority remains `terminal_deferred`, present contradictions remain `fail_closed`, and unexpected faults remain `program_exception`. The matrix does not establish a provider, mesh, engineering, physical, UP2-total, B00/B04, or R01-R10 result.

Static QA passed: JSON parsing, artifact/hash checks, control-character scan, `validate_plan.py`, and `git diff --check` all exit 0; process sweep found no Julia/DESC. The archive records the frozen input hashes, R1 history, exact R2 diff, and the final QA. This review authorizes only a bounded G-I1B implementation handoff; it is not implementation acceptance.

