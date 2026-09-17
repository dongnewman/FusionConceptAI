# CORE current-HEAD fresh S3 R3 independent review

Decision: `changes_requested`.

R3 is read-only. No S3 rerun, Julia, DESC, mesh, solver, or physical recomputation was performed. No candidate product, archive, AD48/AD49 product, M1 product, or dirty AD56 factory was modified.

## Confirmed

- The one-byte stderr raw is exactly LF (`0x0a`). Its independently computed SHA-256 is the 64-hex value `01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b`.
- The corrected static measurement raw has valid byte/hash links: stdout 299 bytes, stderr 1 byte, combined 300 bytes; combined is exactly `stdout || stderr` and its hash matches. The exact command is present and hash-addressed; its declared static vector is `[4,5,12,1,47,0]`.
- The current static vector is `[4,5,12,1,47,0]`. The R2 zero vector is explicitly classified as `historical_failed_measurement` with `current_evidence=false` in the top manifest/receipt and corrected measurement contract.
- The canonical UTF-8 compact sorted-key preimage still independently hashes to `840922caac204df3d66ce3419868390c2fda8e79c3792cc4e074af2887edd9a5`; HEAD/index and the frozen input identity did not drift.
- Fourteen external inputs remain `13 absent + 1 unknown_deferred`; Branch B and G1/G2/G3 `typed_absent`, `terminal_deferred`, `no_publish=true` remain unchanged. R1 failure history, no-repeat/no-new-AD rule, exact cleanup, no formal gate credit, and forbidden-tool restrictions are preserved.

## Blocking finding

The candidate R3 repair did not propagate the recomputed LF digest to all current receipt fields. The following current fields still contain a 65-character value (`...9649e09...`), not the actual 64-character SHA-256 (`...964e09...`):

- top-level `validation_receipt.json` repaired stderr field;
- `archive/repair_r2/repair_receipt.json` stderr field;
- `archive/repair_r3/corrected_static_measurement_receipt.json` raw stderr and artifact fields;
- `archive/repair_r3/validation_receipt.json` raw/artifact stderr fields.

Therefore the R3 validation claim `stderr_sha256_fields_all_current_candidate_and_r2=true` is false, and the stated “all current candidate/R2/R3 receipt fields use 64-hex value” is contradicted by the files. The corrected static raw itself is good, but the receipt chain is not yet admissible.

Repair only these receipt hashes and their dependent validation/raw-hash links append-only. Do not rerun S3, alter the frozen result, remove the R2 historical zero vector, or create a new AD. Then request a fresh independent review.

Claim ceiling remains `typed_absence_recheck_only`; no T0, authority recheck, T1, T2, aggregate, UP2, B00, B04, provider, R01-R10, or L4 credit.
