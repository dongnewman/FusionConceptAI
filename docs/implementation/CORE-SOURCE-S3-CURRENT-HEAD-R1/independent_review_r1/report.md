# CORE current-HEAD fresh S3 R1 independent review

Decision: `changes_requested`.

Scope: read-only review of `CORE-SOURCE-S3-CURRENT-HEAD-R1` against the v4 contracts, M1 `accepted_limited` input closure, and historical AD48/AD49 S3 boundaries. No candidate product was modified and no S3, Julia, DESC, mesh, solver, or physical recomputation was run.

## Confirmed

- Live `HEAD` is `b2c04d8339774635aaecd73651efcdb101e01b5d`, branch `main`, and `.git/index` SHA-256 is `6fb570961008194812a3c260d0c2be840800271fe82a1820d7760459bfddb8e0`.
- All six recorded owner working SHA-256 values match the current files. The three AD56 factory working SHA-256 values and filtered working OIDs match the product and are distinct from their recorded HEAD blob OIDs; the dirty executor/source provenance separation is preserved.
- The source closure's static counts are independently consistent with the files: probe imports 4, probe explicit `Base.include` calls 5, loader component files 12 behind one `Base.include` loop, enclosing module include directives 47, and factory include directives 0.
- Fourteen external inputs are itemized. Thirteen are `absent` and runtime closure is `unknown_deferred`; each has an owner/recovery/validation description. The honest branch is `blocked_external_trust_root_and_source_closure`; G1/G2/G3 are `typed_absent`, resolution is `terminal_deferred`, and `no_publish=true`. No parent credit is admissible; R01-R10 and L4 remain open/0.
- No evidence in the candidate receipt invokes the old destructive AD48/AD49 generators. The candidate directory is additive and historical products are declared preserved. This is only a negative observation, not a substitute for an exact replayable command.

## Blocking findings

1. `validation_receipt.json` has an invalid/stale S3 stderr digest: the declared value has length 65 and does not equal the SHA-256 of `archive/raw/fresh_s3_recheck.stderr.raw` (`01ba4719c80b6fe911b091a7c05124b64eeece9649e09c058ef8f9805daca546b`). The recorded combined raw is byte-identical to stdout (1439 bytes) while stderr contains one byte, so it is not a truthful combined capture. This violates the raw/hash receipt contract.
2. The S3 execution raw reports all static-closure counts as zero, contradicting `source_closure.json`, the report, and the independently observed nonzero closure. The result branch may be semantically honest, but the execution evidence is internally inconsistent and cannot be accepted as a fresh closure proof.
3. The receipt command is the non-replayable placeholder `python -c inline current HEAD/index/owner/factory/hash/static-closure/external-presence recheck`; it is not an exact command or script/preimage. Replace it with the exact command/script identity and preserve its true stdout, stderr, and combined bytes with UTC, exit, and hashes.
4. The claimed input fingerprint `840922caac204df3d66ce3419868390c2fda8e79c3792cc4e074af2887edd9a5` cannot be independently recalculated from the product: no canonical fingerprint preimage or serialization receipt is included. The next repair must include the canonical JSON preimage (or exact generator and canonicalization definition) and a receipt that recomputes this exact digest from the frozen HEAD/index/owners/factories/probe/loader/module inputs.

## Required repair / acceptance ceiling

Use append-only `independent_review_r2` or a successor repair under the existing task directory. Do not rerun S3, create a new AD, touch AD48/AD49/M1 products, alter dirty factories, or upgrade the branch. Correct only the evidence defects, preserve the current failed/typed-absence history, rerun read-only receipt validation as needed, and request a new independent review. Until then this review is `changes_requested`, and the fresh S3 product remains `execution_complete_review_pending` with claim ceiling `typed_absence_recheck_only`.
