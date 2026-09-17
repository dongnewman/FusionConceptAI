# Integration repair R1 acceptance

This repair removes unauthenticated precomputed-stage and caller-prior-state
promotion paths. Production and TEST_ONLY packages require independently
supplied expected context, trust anchor hashes, replay key, integration ledger,
and local intake spool. All component calls go through the public validators;
an intake status object is never accepted as a local intake receipt.

Fresh focused pytest: 6 passed. Fresh bytecode compilation: exit 0. The
remaining result is intentionally `terminal_deferred` or `fail_closed`; no
eligible result is manufactured while component receipt bindings and external
authority remain unavailable. Environment R5 is recorded as `pass_limited` by
the dependency review; revocation R4 remains `review_pending`.
