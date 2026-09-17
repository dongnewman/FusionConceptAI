# G-I1B source matrix R1 independent review

Verdict: **changes_requested**.

This is a read-only, different-Luna static review. Julia/DESC were not run. The author matrix is treated as an input and checked against the production source modules and existing local archive boundaries.

## Structure and provenance

- Rows: `50`; groups: `{'N01': 5, 'N02': 5, 'N03': 5, 'N04': 5, 'N05': 5, 'N06': 5, 'N07': 5, 'N08': 5, 'N09': 5, 'N10': 5}`; unique IDs: `50`; unique field paths: `50`.
- Source kinds: `{'actual_A': 45, 'authored_E1_over_actual_A': 5}`; local eligibility labels: `{'yes_local_contract_only': 10, 'yes_limited': 32, 'yes_limited_deferred': 3, 'yes_local_accepted_limited': 5}`.
- N06 uses candidate-neutral `<selected-index>` templates; the review matched each to the production interpolated path using the actual unique selector-derived index expression.

## Findings

- **G-I1B-R1-05** N05-05 assigns declaration.law.law_hash to the right endpoint UnitSignature row; production validates and hashes the endpoint unit provenance with endpoint.unit.source.source_hash. Correct the row hash expression or explicitly add the unit provenance hash as the row content hash.
  - matrix builder evidence: `build_matrix.py:36` records `declaration.law.law_hash` for `/n05/right_endpoint/unit`.
  - production evidence: `N05FluxAuthorityProjectionV1.jl:292-296` derives the unit source hash from `(endpoint_ref, unit)`; `:428-429` validates `endpoint.unit.source.source_hash`.

## Local envelope and ceiling

N01–N02 are actual-A typed local contract rows. N03–N04, N06–N10 are actual-A source projections; their missing cross-layer basis, mapping, provider, or legacy provenance stays `terminal_deferred`. N05 is authored E1 content over actual A and is limited to the existing accepted-limited local scope; the A-absent branch remains deferred. Typed contradictions remain `fail_closed`, and unexpected faults remain `program_exception`.

The matrix does not constitute formal B04, UP2 total, B00, provider, mesh, engineering, physical, or R01–R10 evidence. Formal G-I2/UP1-04B still requires fresh 50 rows, an independent checker, and two-process replay.

Hashes, command exits, stdout/stderr, UTC timestamps, JSON parse, plan validation, diff check, and process sweep are in `report.json`, `evidence_manifest.json`, and `command_receipts.json`.
