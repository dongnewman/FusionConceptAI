# W4 local-input discovery independent review

## Decision

`rework_required`. The listed 25 candidates are internally consistent: all paths exist, byte counts and SHA-256 values match, every listed candidate is `usable=false` and `production=false`, and no listed fixture, self-signed, local-only, schema-only, or historical record was promoted. The static validator run PID `87756` is hash-linked and exited 0.

The global “25 candidates are complete” claim is not independently established. The metadata scan has no reproducible full path/output ledger, and repository-local authority/candidate-looking records in AD-44, AD-45, and AD-55/AD-56 are neither inventoried nor explicitly excluded with reasons. The W1/W2/W3 absence delta also merges renamed IDs without a machine-readable crosswalk. Therefore this review confirms `usable_production_count=0` for the listed 25, but not completeness of the repository-only discovery universe.

Claim ceiling remains `discovery_only/preparation_only`; no T0, B00, B04, UP1, R, L4, or parent-goal credit.

## Scope and safety

Only this review directory is written. Discovery, source, tests, ADs, registries, shared documents, and upstream registers were not modified. No Julia, DESC, solver, mesh, network, or recomputation was run. The independent path scan inspected names/extensions/metadata only for sensitive material; no private-key, token, credential, or secret contents were opened or emitted. No repository path matched private-key/secret/token/credential/password or `.pem/.p12/.pfx/.der/.key/.env` patterns, so `sensitive_unopened=[]` is consistent with this bounded scan.

## Checks

- Discovery exact set is 11 files; all package JSON parsed with duplicate-key rejection.
- All 25 candidate paths exist; recorded bytes and SHA-256 values match independently.
- PID `87756`, UTC `2026-09-16T15:51:38.3657914Z`–`2026-09-16T15:51:39.0141806Z`, exit `0`, stdout/stderr/combined hashes match the raw files. Stdout reports candidate count 25, changed inputs false, upstream register mutation false, usable production count 0.
- Listed candidates carry the required metadata fields and all are non-promotable. No local fixture, self-signed, or local-only record is treated as authoritative.
- `absence_delta.json` has 14 typed-absence entries and no new real inputs, but does not provide exact source-ID aliases to the W1 register (9), W2 register (11), and W3 register (5). Semantic coverage is plausible; exact equality is not machine-proven.

## Blocking recovery

Add a bounded, reproducible repository path inventory (names/extensions/metadata only), an explicit exclusion register for AD-44/AD-45/AD-55/AD-56 and other authority-looking historical artifacts, and an exact W1/W2/W3 ID crosswalk preserving owner/source/recovery/expiry. Re-run the safe validator and independent review only after a material input or scan-contract change. Unchanged inputs must not create a new AD or repeat acceptance.
