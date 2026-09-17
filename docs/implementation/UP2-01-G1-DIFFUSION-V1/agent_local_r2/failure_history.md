# R2 failure history (immutable prior review)

The independent agent-local R1 review remains unchanged at
`../independent_agent_local_r1/`. It returned `fail` at the same HEAD
`cfc745939a02fd023854dd04e9bb6d04ccadf9ee`, with five findings:

1. F1/P1: source payload was not explicitly candidate-bound.
2. F2/P1: operator IDs and complete PhysicalType endpoint equality were not
   closed.
3. F3/P2: closure/applicability references were not bound to the profile,
   version and hash.
4. F4/P2: cleanup inventory lacked AD-35 `final_exact_owned_set` and a
   per-path before/after/action/reason ledger.
5. F5/P2: focused tests did not directly assert zero downstream counters,
   required gaps, and schema/canonicalization/profile receipt hashes.

No source or test file was changed by that reviewer. R2 addresses each
finding in the four authorized product files and adds only this new
`agent_local_r2` evidence directory. The old R1 evidence and review remain
read-only.
