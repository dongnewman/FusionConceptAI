# UP4-EARLY-PREPARATION Repair R1

Status: `review_pending`; `claim_ceiling=contract_only`; no credit.

Independent review found one malformed observed digest in
`reference_data_catalog_template.json` under
`records[record_id=local_n2_normalized_result_context].exact_bytes_sha256.value`.

## Source recheck

Before editing, the current local file was read-only hashed with:

```text
Get-FileHash -Algorithm SHA256 -LiteralPath runs/goal_recovery_20260913_012528_cst/n2_desc_heliotron_normalize_r3/result.json
```

Observed source artifact:

```text
path   = runs/goal_recovery_20260913_012528_cst/n2_desc_heliotron_normalize_r3/result.json
length = 7849 bytes
sha256 = 2f4aa65c01a05634c86c8f50cf15f5e5688a0548b51166b32ab90547b5096e25
```

The previous package-local value was
`2f4aa65c01a05634c86f50cf15f5e5688a0548b51166b32ab90547b5096e25` and was
malformed. It was replaced with the recomputed 64-character SHA-256 above.
The source artifact itself was not modified.

## Owned repair set

Only these package-local files are owned by Repair R1:

1. `reference_data_catalog_template.json`
2. `manifest.json`
3. `validation_report.md`
4. `cleanup_inventory.md`
5. `repair_r1/report.md`
6. `repair_r1/manifest.json`

The pre-existing `independent_review_r1/` directory and all repository source,
tests, scripts, runs, benchmarks, planning documents and registries remain
outside this repair scope.

## Boundary

No download, Julia, DESC, inverse solve, provider, mesh, solver, engineering
back-substitution, physical execution, cleanup deletion, or shared registry/final
package edit was performed. The package remains `review_pending`.
