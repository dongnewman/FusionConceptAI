# AD-26 R2 independent static review

- Verdict: **pass_limited**.
- Scope: architecture and evidence-protocol clarification only. No Julia/DESC was run, and this review grants no UP2, B00/B04, provider, mesh, engineering, physical, or R01–R10 credit.

## R2 finding

The R1 `changes_requested` item is closed. The current AD-26 first decision paragraph states that each present E1/E2 extension payload and each typed absent marker carries `schema_hash`, `canonicalization_hash`, and `compatibility_profile_hash` in the context payload. It separately requires the E1/E2 extension content hashes as context inputs and says those content hashes cannot be replaced by implicit defaults or similarly named fields. This is the required present/absent three-layer identity binding with an independent extension-content input.

The same paragraph still preserves complete same-candidate A/E0 refs and hashes, leaves E0 v1 `n05`/`n06` absent, and forbids rewriting or recomputing the original CandidateStatePackageV5 candidate hash and E0 binding/bound-input hashes. The dual `contract_admission`/`physical_resolution` and formal-50-row boundaries remain in the following paragraph and the linked indices.

## Scope and byte evidence

`repair_r2/after_snapshot.json` records core18 40,362 bytes and SHA-256 `a7bffc313dfef35c7e302dd251709491a4a91e15d37a275d92fd6fe9d5aca28`; the current file matches exactly, and its after paragraph occurs once. The recorded before core snapshot is 40,098 bytes with SHA-256 `8eef18b3a9c56681dae317109aa19089fd76097c951072ee4a73118bf94bbc9f`; the before sentence is absent from the current file. The bounded-diff SHA-256 is `d016b36711aa57d9aaf7e4d7b287d46da1f8b2978eb357df2d346dc749d8cdc7`.

README has one AD-26 index link at line 95 (SHA-256 `ed3080e9c164f20d8d67af5a886d3b473d4a578048aaccbbfa17dee07a8c9f75`), and execution work orders has one at line 754 (SHA-256 `b0620c8b7fb6ee71f06e6c8fe4f8251a0ae924a7c19eb4fee08bdbe800189e33`). Neither index grants implementation or physical credit. The current AD-26 acceptance archive remains `review_pending`/`accepted=false` (SHA-256 `79e4e72956a52593b85a16cf5eeb5f6b98d13f3b61a6ebcd02e8b935f52e29a4`).

The original R1 failure is preserved byte-for-byte: report SHA-256 `80431ce5334874b8fe4fb6e8caf50c265455211fafd9d2093204c02dfc209dae`, evidence-manifest SHA-256 `e731140b39df05057c672c23257c65af6c060f31743dae246d1eaf81f6f8cef8`. The R2 repair archive and current core are internally consistent under JSON parsing, control scan, snapshot text check, `validate_plan.py` exit 0, and scoped `git diff --check` exit 0. The repair manifest's `acceptance_sha256_before` is not independently reconstructable because no corresponding before-bytes file is included; it is retained as author-reported metadata and does not affect the verified core clarification.

## Restricted conclusion

`pass_limited` applies only to the AD-26 architecture/protocol clarification. Keep `review_pending` and `accepted=false` pending Sol adjudication. No implementation, B00/B04, provider, mesh, engineering, physical, or R01–R10 credit is warranted.
