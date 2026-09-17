# Integration repair R2 acceptance

R2 closes the review findings around canonical receipt preimages, authenticated
state and aggregate reachability. `receipt_sha256`/`receipt_hash` now exclude
themselves and process metadata through a declared preimage, while `state_hash`
is independently recomputable. The integration ledger performs locked
expected-receipt/sequence CAS, so a stale concurrent writer is rejected.

Candidate and source roots must come from independent anchor fingerprints and
must match any package declaration. Prior state is accepted only as an exact
canonical match to the authenticated ledger latest record. The aggregate gate
public API is called when all bound production stages pass; TEST_ONLY and local
intake remain non-authority/deferred. Ledger/key parent reparse checks reject
symlink/reparse substitution; unavailable platform identity capability defers.

Fresh focused pytest: 9 passed. Fresh compile: exit 0. Dependencies remain
environment `pass_limited`; revocation `review_pending` pending its R4 verdict.
