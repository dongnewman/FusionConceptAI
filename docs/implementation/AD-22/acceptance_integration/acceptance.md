# AD-22 acceptance integration

AD-22 is integrated as `accepted_limited` for architecture consistency and provenance only. The independent Luna review is `pass_limited` and is preserved at `../independent_review/report.md` (SHA256 `834f406d3658bbfff9171503ab04887a0e5a09b77db2228f637c0dbe05a66a67`) with manifest SHA256 `41cd5ec238b98ab349a19a7159fc165c4719447e2748b256c5969ec259abf3ea`.

The integrated author archive records `status=accepted_limited` and `accepted=true`. It preserves all ten N03/N04 obligations, the illustrative/provisional distinction, G1 local temporal checks, G3 intrinsic event checks, the shared-owner legal counterexample, and the missing G1-to-G3 ledger authority join. Future source binding, cross-layer authority, typed mutation receipts, and schema freeze remain required.

AD-22 does not accept UP2-00 implementation and grants no B04, provider, mesh, engineering, physical, or R01-R10 credit. No DAG, task manifest, source, test, run, or heavy-lane state was changed by this integration. `validate_plan.py` and `git diff --check` both exited `0`; these checks are documentation integrity evidence only.
