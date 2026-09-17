# Integration repair R3 acceptance

R3 fixes the positive production reduction path (`role` is derived from the
strict root), rejects non-lowercase/non-hex external identity anchors, and
optionally re-computes anchors from supplied canonical `candidate_context` and
`source_identity` materials. Prior snapshots must equal the complete
authenticated ledger state, not merely share a receipt id. A direct test now
reaches the real `aggregate_gate.aggregate_document` API on a fully bound
verified structure; its eligible result remains preparation-only/no credit.

Fresh focused pytest: 11 passed. Fresh compile: exit 0. Dynamic Windows
symlink creation is unavailable in this host (WinError 1314); the path safety
implementation retains deterministic reparse/owner/ACL checks and records
that fixture as `test_scope_deferred`, not as a pass.

Dependency status: environment `pass_limited`; revocation
`pass_limited_with_test_scope_deferred` (foreign-owner dynamic fixture is
`not_executed`).
