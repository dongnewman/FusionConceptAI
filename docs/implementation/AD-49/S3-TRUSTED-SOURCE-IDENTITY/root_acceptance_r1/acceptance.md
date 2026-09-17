# AD49 S3 root acceptance R1

Decision: **accepted_limited** for the four formal trusted-source identity/receipt products as typed absence records and for the recorded missing external trust/source-closure matrix. Current gate: `blocked_external_trust_root_and_source_closure`. Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`.

Accepted products are the four readiness products 89–92: G1 identity and receipt, and G2 identity and receipt. Their final hashes are recorded in `hash_inventory.json` and independently reproduced in `independent_review_r1/final_product_hashes.json` and `replay_comparison.json`. Both independent replay runs exited 0 and matched every formal product byte-for-byte. Formal replay also had two serial exit-0 runs; v1–v3 and prior `not_executed` attempts are historical only and do not count as evidence.

The accepted semantics are `typed_absent`, `terminal_deferred=true`, `no_publish=true`, and `present_result_permitted=false`, with reason `missing_source_closure_and_independent_attestation_chain`. Source declarations are worktree-bound but absent from HEAD. Independent attestor, key, certificate, signature, verifier, trust root, revocation, freshness, trusted time, and replay material are all missing. G2 mapping remains absent. A construction receipt, local hash, reviewer, fixture, URI, seed, test exit, or provider root cannot become trusted source evidence.

This acceptance permits **AD50 core status synchronization** only. It does not unlock G2 mapping, W3B, AD46, source authority, trusted attestation, candidate identity, T0/T1/T2, provider, mesh, solver, engineering, physics, search, or R01–R10. All such claims remain false and credible L4 remains 0. No Julia or DESC was run.

Validation gates were checked from the formal and independent records: JSON parsing passed, direct validation exit 0, negative controls passed, both replay comparisons were byte-identical, planning validation exit 0, scoped diff exit 0, no self-inclusion, no staging/pycache/temp residue, and only the root acceptance directory is written by this step.
