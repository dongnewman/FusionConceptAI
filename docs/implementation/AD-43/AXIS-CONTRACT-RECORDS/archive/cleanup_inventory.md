# AD43-AXIS-CONTRACT-RECORDS cleanup inventory

Task-owned product scope is exactly four contract deliverables:

- `docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/evidence_receipt_axis_schema_v1.json`
- `docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g1_evidence_receipt_contract_v1.json`
- `docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_applicability_profile_contract_v1.json`
- `docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_evidence_receipt_contract_v1.json`

The task-owned `archive/**` paths are evidence-only append-only sidecars under
the AD-36 accepted-limited policy. They contain raw validation streams,
validation metadata, and this cleanup inventory. No source, test, fixture,
static-QA file, launcher, payload, declaration, candidate hash, W2R1 product,
or product copy is stored under `archive/**`.

The first direct validation attempt is retained as a failed historical receipt
(`validation_stdout.json` / `validation_stderr.txt`); it failed only because
the checker treated the explanatory phrase `source-backed authority` as a
forbidden product token. The corrected direct validation is append-only in
`validation_r2_*`, `validation_r3_*`, and `validation_r4_*`; the final r4 run
exited 0 with 38/38 checks passing after adding source literal/descriptor hash
material. No previous AD-43
audit, AD-42 W0 product, AD-40 historical receipt, unrelated dirty path, or
ambiguous path was removed or modified.

Current task-owned evidence paths:

- `archive/validation_stdout.json`
- `archive/validation_stderr.txt`
- `archive/validation_r2_stdout.json`
- `archive/validation_r2_stderr.txt`
- `archive/validation_receipt_r2.json`
- `archive/validation_r3_stdout.json`
- `archive/validation_r3_stderr.txt`
- `archive/validation_receipt_r3.json`
- `archive/validation_r4_stdout.json`
- `archive/validation_r4_stderr.txt`
- `archive/validation_receipt_r4.json`
- `archive/cleanup_inventory.md`

`independent_review` remains pending. The four products only define source
contracts; `PresentAxisContractRecordV1` does not assert a candidate-bound
axis, source-backed authority, declaration present, T0/T1/T2, provider, mesh,
solver, engineering, physical, search, or R01-R10 evidence.
