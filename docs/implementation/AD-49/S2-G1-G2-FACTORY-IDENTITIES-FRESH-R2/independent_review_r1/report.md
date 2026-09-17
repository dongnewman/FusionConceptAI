# AD49 fresh S2 G1/G2 factory identities independent R1

Date: 2026-09-16 (UTC evidence timestamps are in `raw/`)  
Verdict: `pass_limited`  
Root acceptance state: `pending`

## Decision

The fresh S2 five product set was frozen and rehashed before review. The four product hashes and the negative-controls hash match `input_hashes.json`; the reviewed files were not modified. The independent reviewer wrapper called the real G1 and G2 factories twice, strictly serially, after a passing Julia parse gate. Both replays exited 0 and returned `typed_absent` for identity and construction receipt because the declaration paths are present only in the working tree and absent from `HEAD` `4b69f55f7f80240147a65a22809dc1207824dde2`. The reviewer canonical hashes use the reviewed formula over layer, record kind, result, factory hash, S1 locator hash, F0 factory hash, and input HEAD; each identity and receipt hash matches the frozen products on both replays.

The reconstructed baseline is explicitly `temporal_role=post_run_reconstructed_snapshot`, `pre_run_baseline_present=false`, and `not_acceptance_evidence=true`. The live declaration bytes and SHA-256 match the recorded inputs, while `git ls-tree HEAD` is empty for both declaration paths. G2 mapping remains `absent`. AD45 handle/version/envelope hash, protected registry/entrypoint hashes, F0 factory hashes, S1 locator hashes, `GenomeContractRef`, and both typed four-axis structures were independently checked.

The construction receipts are software execution evidence only: `trusted=false`, `candidate_identity_created=false`, `final_hash_created=false`, and `implementation_hash_is_non_authority=true`. The result does not create source authority, candidate/package/T0 identity, provider/physics/search/engineering evidence, R01-R10, or L4 credit.

## Evidence and negative controls

The two successful Julia process records bind PIDs 95792 and 81992 to the emitted identity and receipt records. Six required focused tests ran serially with exit 0. The planning validator and scoped `git diff --check` each exited 0. No Julia process remains. The focused stderr was retained; it contains line-ending notices and the factory Git probe's fatal text for the intentional missing repository-head declaration probe. No soft-scope warning was observed, and these runner diagnostics did not mask a test failure because each focused process has exit 0 and passing output.

All negative controls pass: missing locator and unavailable anchor remain typed absence; foreign/conflicting handles fail closed; a factory hash cannot promote identity; and fixture/G3/registry aliases cannot substitute. The prior fresh-S2 attempts 1–4, the malformed reviewer parse attempts, partial `replay_1` outputs, and the 253-check superseded validation attempt are preserved and excluded from acceptance evidence.

## Boundary

`pass_limited` permits the parent to accept this fresh S2 software/typed-absence evidence and consider the separately gated S3 step. It does not turn a construction receipt into trusted attestation, does not mark the untracked declarations as repository authority, and does not grant provider, mesh, solver, engineering, physical, search, R01-R10, or L4 claims. A future source-authority result requires the declarations to be HEAD-tracked and a new independently reviewed run.

Independent audit: `independent_audit_result.json`, 271 checks, exit 0. `final_hashes.json` records before/after equality for all five frozen products and excludes its own self-hash; `cleanup_inventory.json` records 74 review-owned files with zero pycache, staging, or temporary residue. A final pass parsed 34 JSON files with zero errors and reran scoped `git diff --check` with exit 0. Only this `independent_review_r1/**` directory was written by this review; frozen S2 products and unrelated dirty work were preserved.
