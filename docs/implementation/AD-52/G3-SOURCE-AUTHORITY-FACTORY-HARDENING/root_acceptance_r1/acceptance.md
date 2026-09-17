# AD-52 root acceptance R1

- `decision=accepted_limited`
- `accepted_scope=g3_source_factory_fail_closed_software_capability_only`
- `L4=0`

This root decision accepts the AD-52 implementation and `independent_review_r3` evidence as a limited software capability slice. The accepted behavior is the G3 source-authority factory's fail-closed handling of repository root, exact HEAD, tracked stage-zero index entry, HEAD tree/blob, byte/hash equality, clean target path, and relabel/flag/mutation adversaries. It does not establish actual source authority or external trust.

The implementation evidence passed its focused lane (`356/356`, exit `0`) and the independent review verdict is `pass_limited`. The frozen implementation source is `src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl` SHA-256 `ceac9a33368606843337194ee446b6de6f2b7c6223cbc110229d5df17cf84d39` (35,491 bytes); the focused test is `test/GenomeV5/G3/g3_source_authority_factory_v1_tests.jl` SHA-256 `23155dd7e7c6440177fe666fe463f73603b2c63a4572796801cbcee7d99c1e5b` (21,883 bytes). The review froze HEAD at `4b69f55f7f80240147a65a22809dc1207824dde2` and reported `pass_limited`.

The current repository's four G3 legacy source files remain untracked and absent from HEAD. Consequently the factory returns typed absence for the current repository and the four-scope source publication state is `typed_absent/no_publish`. Old AD48 `Present` evidence is historical and cannot be carried forward to this current HEAD or current source bytes. Fresh S2 and S3 evidence is required before any later source or trusted identity claim.

The acceptance excludes:

- actual source authority and external trust/attestation;
- candidate identity, final/package identity, provider, mesh, solver, engineering or physical evidence;
- G2 mapping, T0/T1/T2, search, and R01-R10 credit;
- any GenomeV5 publication closure or shared-entrypoint integration claim;
- `L4` credit (`L4=0`).

The following are expressly outside this decision: source-publication closure for the four current G3 scopes; inclusion of the four legacy sources in HEAD; `src/FusionConceptAI.jl` or other shared entrypoint changes; G3 feedback-law publication; candidate/T0/T1/T2 work; and AD53. AD53 remains an independent pending closure task and is not accepted by this archive.

Frozen inputs and evidence are recorded in `manifest.json` and `hash_inventory.json`. Cleanup and dirty-tree protection are recorded in `cleanup_inventory.json`. No Julia/DESC process was run by this archive operation, no source/test/index/HEAD/task manifest was changed, and no unrelated dirty file was deleted or staged.
