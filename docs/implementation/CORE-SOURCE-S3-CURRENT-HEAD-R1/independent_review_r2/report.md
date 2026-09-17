# CORE current-HEAD fresh S3 R2 independent review

Decision: `changes_requested`.

This R2 is read-only. No S3 rerun, Julia, DESC, mesh, solver, or physical recomputation was performed, and no candidate product, archive, AD48/AD49 product, M1 product, or dirty AD56 factory was modified.

## Independently confirmed

- Live HEAD is `b2c04d8339774635aaecd73651efcdb101e01b5d`, branch `main`, and index SHA-256 is `6fb570961008194812a3c260d0c2be840800271fe82a1820d7760459bfddb8e0`.
- The repair preimage file SHA-256 is `d8fdf6c750f3a6db5324275400d7799b79b3467cec3c0d25485be79b024a5159`; canonical UTF-8 compact sorted-key JSON over that preimage independently hashes to `840922caac204df3d66ce3419868390c2fda8e79c3792cc4e074af2887edd9a5`. The fingerprint is therefore reproducible.
- The source-closure six-count vector and semantics are independently consistent: `[4,5,12,1,47,0]` = probe imports, probe include targets, loader component entries, loader `Base.include` sites, enclosing-module includes, factory includes.
- Repaired combined raw is exactly `stdout || stderr` with byte sizes `1439 + 1 = 1440`, and its declared combined hash matches. The stderr file is exactly one LF byte.
- The exact command file exists and is hash-addressed (`19c307520749e51d8541a5b69f1c4bb6646b78de39bcf2f2fcdf54879f8e38af`). Its read-only source/hash/static inspection logic is consistent with the frozen inputs; it was not executed by this reviewer.
- Fourteen external inputs remain itemized as 13 `absent` and 1 `unknown_deferred`. Branch B remains `blocked_external_trust_root_and_source_closure`; G1/G2/G3 remain `typed_absent`, `terminal_deferred`, and `no_publish=true`.
- R1 failure history is present, cleanup remains exact-path/no-glob, unchanged-input no-repeat is preserved, and formal gates remain open with no R/L4 credit.

## Blocking finding

The repaired R2 receipt still declares the one-byte stderr SHA-256 as a 65-character value:

`01ba4719c80b6fe911b091a7c05124b64eeece9649e09c058ef8f9805daca546b`

The actual SHA-256 is the 64-character value:

`01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b`

Thus `validation_receipt.json` and `archive/repair_r2/repair_receipt.json` fail the byte/hash receipt contract even though the combined raw itself is correct.

## Evidence consistency issue requiring explicit repair

The authoritative repaired raw still contains the old static vector `[0,0,0,0,0,0]`, while `source_closure.json` and the independent measurement establish `[4,5,12,1,47,0]`. The report labels this as an immutable historical undercount, which is acceptable only if the receipt explicitly classifies that raw as historical and links a separate exact read-only static-measurement raw/receipt. As currently written, `validation_receipt.json` calls the repaired raw authoritative, so the execution evidence remains internally inconsistent.

Repair only these evidence links/labels append-only; do not rerun S3, create a synonymous AD, change the frozen result, or alter the original failure raw. After the digest correction and explicit historical-vs-corrected raw classification, request R3 review.

Claim ceiling remains `typed_absence_recheck_only`; no T0, authority recheck, T1, T2, aggregate, UP2, B00, B04, provider, R01-R10, or L4 credit.
