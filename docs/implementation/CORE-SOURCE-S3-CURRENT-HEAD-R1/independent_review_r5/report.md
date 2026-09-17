# CORE current-HEAD fresh S3 R5 final independent review

Decision: `pass_limited`.

This is a read-only evidence review. No S3 rerun, Julia, DESC, mesh, solver, or physical recomputation was performed. No candidate product, historical archive, AD48/AD49 product, M1 product, or dirty AD56 factory was modified.

## Evidence accepted within scope

- `archive/repair_r3/corrected_static_measurement_receipt.json` independently hashes to `ffa2a9958151d1112b37ab0588a60fa08182bb3441aff307323a9a41aab22ac0`, exactly matching the top-level artifact reference.
- All top-level output/artifact references recompute successfully. The five current stderr digest fields are 64 lowercase hex and equal the exact SHA-256 of the one-byte LF (`01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b`); `wrong65_count=0`.
- Corrected static evidence is `[4,5,12,1,47,0]` with valid raw/hash/combined links. The former zero vector remains historical failed measurement only (`current_evidence=false`).
- Fingerprint `840922caac204df3d66ce3419868390c2fda8e79c3792cc4e074af2887edd9a5`, 14 external inputs, Branch B, G1/G2/G3 `typed_absent`, `terminal_deferred`, and `no_publish=true` are unchanged. The no-repeat/no-new-AD rule and failure history are preserved.
- Formal gates remain uncredited: T0/T1/T2/aggregate/UP2/B00/B04 and R01-R10 are open; L4 remains 0. Cleanup is exact-path/no-glob.

## Acceptance boundary

`pass_limited` applies only to the current S3 evidence and receipt integrity. It does not accept source authority, trust root, provider, candidate identity, numerical/engineering/physical evidence, any formal gate, R01-R10, or L4. The parent goal remains open and the next step is still conditional on real external-input change; unchanged inputs forbid another S3 run or synonymous AD.
