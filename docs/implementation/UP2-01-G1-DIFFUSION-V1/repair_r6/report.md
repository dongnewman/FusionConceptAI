# UP2-01-G1-DIFFUSION-V1 repair R6 provenance erratum

Status: `changes_ready_for_independent_r6_review`; `review_pending=true`; `accepted=false`.
Runtime status: `not_run`; Julia and DESC were not invoked.

This additive receipt corrects the historical path attribution in the R5
erratum. No source, test, fixture, static-QA file, or prior repair receipt was
modified.

## Correct R2/R3/R4/R5 evidence chain

The R5 field named `historical_receipts_untouched.repair_r3_*` with hashes
`0956b606...` and `0faed483...`. Those hashes are the actual files under
`repair_r2/`, not `repair_r3/`. The actual path/hash/byte ledger is:

| receipt path | bytes | SHA-256 |
|---|---:|---|
| `repair_r2/report.md` | 3482 | `0956b606e576ad8979fec115fd679f0f6465659f5be51f84e9c07786fbc9d44c` |
| `repair_r2/evidence_manifest.json` | 2032 | `0faed4835e7b52a9de28a5964bc30e695fdb99d642fc3710972d56d149ec44c2` |
| `repair_r3/report.md` | 3554 | `7e1ab164339f782a83b7819cca39c5a31276782e5b66ddc0e0262531356f1560` |
| `repair_r3/evidence_manifest.json` | 2499 | `2beb6360023fce345760e618b845d8dca66f0de964c0f1d230e812188f63b813` |
| `repair_r4/report.md` | 3745 | `43f793be1e1cc5b895ef7c92312743c5984cfcd44d0cf691d8d308eb37ae09e0` |
| `repair_r4/evidence_manifest.json` | 2850 | `907dbc104f02878b6f600954a33639aefea3bb4c4f98abb8274dad19f8cad28e` |
| `repair_r5/report.md` | 3187 | `ee0986149fda19d060e53320f4e64377c75c8b6f4d88ecce295309acdf3baaf4` |
| `repair_r5/evidence_manifest.json` | 3070 | `22f850682478efe8e0d5499860ed45816d0fb5b3599494a65cb9a7a63930c857` |

Therefore the R5 claim that the `repair_r3/` pair was untouched is a path
label error: the claimed pair is the R2 pair. R3 remains present and unchanged
at its own actual hashes above. R4 and R5 also remain unchanged at the hashes
listed above. This R6 receipt records the distinction without rewriting any
historical evidence.

## Target integrity and before/after

The four G1 targets were not mutated in R5 or R6. Their current bytes and
SHA-256, independently checked with `Get-Item.Length` and
`Get-FileHash -Algorithm SHA256`, are the following; R6 before and after are
identical because the repair is documentation-only:

| target | bytes | R6 before | R6 after |
|---|---:|---|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | 31743 | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | 9655 | `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6` | `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6` |
| `test/GenomeV5/G1/diffusion_v1_fixture.json` | 1582 | `7b580bf9ad875ed70ffc3aa0ee2e27cbe124c413ec7dad0a8fcd3410c6864641` | `7b580bf9ad875ed70ffc3aa0ee2e27cbe124c413ec7dad0a8fcd3410c6864641` |
| `test/GenomeV5/G1/static_qa_diffusion_v1.py` | 4499 | `87f511f5402224df06928a9e78c0d3213d2330da5b91021b628acd51d7536066` | `87f511f5402224df06928a9e78c0d3213d2330da5b91021b628acd51d7536066` |

## Dirty-state provenance

Before writing R6, `git status --short --untracked-files=all` contained 3681
entries with UTF-8/LF status SHA-256
`3998d6d0877128454ab725ffd7c63afbbf38f81be88a35755a80dc5d8173b935`.
The post-write count and hash are recorded in
`repair_r6/evidence_manifest.json`; within the G1 Diffusion path, the only
intended R6 additions are its new report and manifest. Unrelated dirty work
was preserved.

## Verification and claim boundary

The R6 JSON/hash assertion exited `0` with `hash_and_json_check=pass`. The
existing Python static QA exited `0` with `static_qa=pass` and
`julia_or_desc_executed=false`. No Julia/DESC command was run. No compiler,
provider, mesh, solver, physical, engineering, current-A, B00, B04, or R01-R10
credit is claimed.

An independent Luna R6 review should verify both R2/R3 paths, the R4/R5
receipts, the current target hashes and bytes, the pre/post dirty snapshot,
and the corrected provenance manifest before any serial focused lane.
