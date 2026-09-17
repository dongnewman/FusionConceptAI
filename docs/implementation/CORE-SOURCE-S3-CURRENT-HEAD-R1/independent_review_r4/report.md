# CORE current-HEAD fresh S3 R4 final independent review

Decision: `changes_requested`.

R4 is read-only. No S3 rerun, Julia, DESC, mesh, solver, or physical recomputation was performed; no candidate product, archive, AD48/AD49 product, M1 product, or dirty AD56 factory was modified.

## Passed checks

- The exact one-byte LF raw (`0a`) hashes to `01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b`. Scanning current candidate JSON while excluding `independent_review_*` gives `wrong65_count=0`; all five current stderr digest fields in the four repair paths are 64 lowercase hex and equal the independently computed value.
- The four corrected receipt paths are present and consistent: top-level `validation_receipt.json`, `archive/repair_r2/repair_receipt.json`, `archive/repair_r3/corrected_static_measurement_receipt.json`, and `archive/repair_r3/validation_receipt.json`.
- Corrected static measurement has current vector `[4,5,12,1,47,0]`; its stdout/stderr/combined raw hashes and exact `stdout || stderr` relation pass. The former zero vector is historical failed measurement only with `current_evidence=false`.
- Fingerprint `840922caac204df3d66ce3419868390c2fda8e79c3792cc4e074af2887edd9a5`, Branch B, 14 external inputs (`13 absent + 1 unknown_deferred`), G1/G2/G3 typed absence, `terminal_deferred/no_publish`, no-repeat rule, failure history, exact cleanup, and no formal gate credit remain unchanged.

## Remaining blocking finding

Top-level `validation_receipt.json` still records the old SHA-256 for `archive/repair_r3/corrected_static_measurement_receipt.json` (`b4d1ac87e41d1f44f1a2ff190a23503eae41167949d9fb8e0fa2dd20d0ef0f36`), but the current file hashes to `ffa2a9958151d1112b37ab0588a60fa08182bb3441aff307323a9a41aab22ac0`. All other top-level output/artifact hashes checked pass. This stale artifact map prevents final receipt acceptance.

Repair only that top-level reference and its dependent validation record, append-only, without rerunning S3 or creating an AD. Then the evidence is eligible for `pass_limited` review; claim ceiling remains `typed_absence_recheck_only`, with T0/T1/T2/aggregate/UP2/B00/B04/R01-R10/L4 still uncredited.
