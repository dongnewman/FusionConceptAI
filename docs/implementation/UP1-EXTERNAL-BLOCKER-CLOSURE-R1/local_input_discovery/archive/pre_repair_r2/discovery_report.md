# UP1 W4 — local external-input discovery repair R1

Status: `discovery_only` / `preparation_only`

A repository-only metadata scan found 2851 path-rule hits: 1904 candidate-class records and 947 excluded records. Every record has relative path, type, byte size, SHA-256, classification, and no emitted content in `raw/metadata_scan.jsonl`. AD-44/45/55/56 are explicitly covered in the candidate class; source/test/runtime/historical/non-target hits are retained in `excluded_inventory.json`.

No sensitive contents were emitted; the scan reports `sensitive_unopened_count=0`. All candidate records remain `usable=false`, `production=false`; no record is promoted.

The absence delta preserves every W1/W2/W3 register ID one-to-one (`26` rows), with source register path/hash, owner/provider/authority/recovery/expiry and full scoped-ID digest. `changed_inputs=false`, `new_real_inputs=[]`; unchanged inputs do not create an AD or repeat S3.

The validator is independent of self-reported expected values: it recomputes existence, byte count, SHA-256, types/enums, promotion flags, candidate/excluded coverage, crosswalk coverage and exact file set.

No source, test, AD, upstream register, shared registry, network, Julia, DESC, solver, mesh, or physical/search execution was touched.
