# N10 acceptance integration record

This archive records the docs-only integration of an independent Luna/high `pass_limited` review. The accepted scope is five actual-A identity/receipt fields and same-G2-plan candidate-specific rebinding.

Evidence used:

- Independent review manifest: `../independent_review_r1/manifest.json`, SHA256 `ea1a548b6aeadd3c65159b043f3da203d0654c9757dea194f59dab0297cea2d0`.
- Runtime: exit `0`; actual-A identity/receipt `80/80`; foreign candidate/receipt controls `7/7`; compile/provider/solver `0/0/0`; post-run Julia/DESC count zero.
- N10-04 remains synthetic attempted-hash only; N10-05 is fresh-receipt-only; V4 legacy provenance remains `terminal_deferred`.
- The old aborted `x.txt` was hashed in `before_freeze.json`, recorded in `aborted_artifact_removal.json`, and removed as non-evidence. No Julia/DESC was run by this integration.

The UP2-00 total gate remains `review_pending`; all 50 formal B04 receipts, checker, and two-process replay remain pending. B00/B04/provider/mesh/engineering/physical/R01-R10 credit is false. The task manifest was not edited.
