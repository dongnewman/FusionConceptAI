# UP1 external blocker closure R2 — local discovery

Status: `completed`, claim ceiling: `preparation_only`, `changed_inputs=false`, `new_real_inputs=[]`.

This is a metadata/hash-only rediscovery over the FusionConceptAI repository and `outputs/fusion_concept_ai`. `.git`, review directories, cache directories, R1's generated local-discovery directory, and this R2 output directory were excluded. Suspected credential/private-key/token paths were not opened; no environment-variable values were read.

## R1 comparison

R1 recorded `2810` raw path hits and `1864` candidate records at HEAD `b2c04d8339774635aaecd73651efcdb101e01b5d`. Under the exact R1 rule, R2 has `3278` current hits: `1761` unchanged, `918` changed hashes, and `599` new paths. The supplementary certificate/root/axis/mapping/lockfile/evidence rule adds `2190` path hits. These deltas are local source/history/fixture/environment or R2 implementation material, not newly supplied external values.

## Findings

No real witness/authority receipt, trust root, public-key certificate chain, signed attestation, CRL/OCSP/TSA receipt, authoritative G2 mapping, candidate-bound four-axis issuance, or binary/SBOM/lockfile provenance receipt was found. The 12 public-material hits are Python/Conda CA bundles and are not an attestor chain or candidate-bound receipt. Local contracts, tests, fixtures, schemas, reports, source code, hashes, and historical run receipts remain nonusable and cannot be promoted.

The complete 26-row crosswalk is in `crosswalk.json`; every row retains the R1 provider/owner/authority/recovery/expiry fields and records the R2 metadata-hit count. The lossless path/size/mtime/hash stream is `raw/metadata_scan_r2.jsonl`.

## Disposition

`no_new_AD=true`; `no_s3_rerun=true`. The external trust-root/source-closure blocker remains open. A future S3 attempt requires an actual external input change plus a fresh candidate-bound source/environment closure and independent verifier evidence.

## Reproduction

```powershell
python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/09-local-discovery/scan_r2.py
python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/09-local-discovery/finalize_r2.py
```

Run PID/UTC/exit and stdout/stderr hashes are recorded in `run_ledger.json` and `validation_receipt.json`.
