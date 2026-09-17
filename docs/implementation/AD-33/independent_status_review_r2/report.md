# AD-33 independent status review R2

## Verdict

`changes_requested`.

The synchronized semantic status is still bounded correctly: AD-33 is an architecture/work-order boundary, the only intended shared machine node is `UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC`, the node remains planned/proposal/accepted=false/review_pending, and the local implementation ceiling is the typed-absent scaffold. The evidence package used by `status_sync_r2`, however, is stale against the current core checkout.

The status-sync receipt records 37 tasks and hashes for the core planning files. The current checkout has 39 tasks and different hashes for five of the recorded inputs. The current `validate_plan.py` run is exit 1: the DAG is acyclic and JSON/links are readable, but the validator reports manifest/text drift for `UP1-04A-VNEXT-G3-BINDING-EDIT-PREC` and `UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC`. A fresh status synchronization is required after the current core work-order text and task manifest settle.

No Julia or DESC command was launched for this review.

## Current status boundary

The current AD-33 acceptance and manifest remain semantically conservative. They state `accepted_limited` for architecture/work-order boundary only; the shared node is planned/proposal/accepted=false/review_pending with `claim_ceiling=contract_only`, depends only on UP1-01/02/03, treats G1/G2 V1 paths as read-only inputs, is parallel to T0/AD-31/AD-32, and does not unlock T0/T1/T2. No G1/G2 edit sibling machine node is created. Present authority, present G1/G2 child, source publication, UP2, provider, mesh, engineering, physical, B00/B04 and R01-R10 claims remain false.

The current task manifest is valid JSON with 39 tasks, R01-R10 intact, and the parent node still has the expected dependency list and planned status. The current task list contains the additional work-order IDs `UP1-04A-VNEXT-G3-BINDING-EDIT-PREC` and `UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC` relative to the 37-task status-sync claim. The current validator reports the graph acyclic, but its work-order consistency check fails for those two IDs.

## Hash and receipt audit

The eight status-sync input hashes were checked against the current files. Three core planning documents, the core implementation README, and the task manifest have drifted from the values recorded in `docs/implementation/AD-33/status_sync_r2/manifest.json`:

| path | status-sync R2 hash | current bytes | current SHA-256 |
|---|---|---:|---|
| `docs/v4_multitopology_generation/16_execution_work_orders.md` | `e085e52a97cd7b3dddf7a33ea8dbac4311a54695d94fca79b0660327054e3f33` | 92624 | `82072b6575e8b70d9a62a87af992543b6ab6a2e6b46aa0df5b088bc0e5fd84bb` |
| `docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md` | `5b04ad2cf7b64c7e866784bc778c1783a88eeb16475c42643a7fc61a980f934f` | 72243 | `ccccbf564558a52c76d4b1b797b1fe246692729decb229e4be47584d6b174e31` |
| `docs/v4_multitopology_generation/README.md` | `3d23257233b521f5cf84326f6b7d0bb9d970d6034eee61c42cc44f62a8b1084b` | 35950 | `b63ea205a85d5d01ffa6c199730b74684fd6c30e4e766e8b0d38c448e37b468f` |
| `docs/v4_multitopology_generation/task_manifest.json` | `d03b909792b9ef6d56420e00152385399ce59c6b96c018c0e2a11e22441f64cc` | 86428 | `fdd9521945abb25b5e427b2d3c6f8926c000ad8c73659822b874194692ba1619` |
| `docs/implementation/README.md` | `d96576064bce30952eafc256e167aa5d9db35ce6ea8d81c66e9b306b06becd4c` | 19069 | `4a16e955830a1d22b597843d243311b945aee85ab7a395af8ab7e06587fa1b49` |

The other three status-sync inputs still match: the UP1-04A implementation README (`866f59da...`), acceptance (`2cc43b8f...`), and manifest (`3f8f1019...`). The status-sync R2 report and manifest themselves are valid JSON/text; the status-sync manifest excludes its own manifest hash as declared.

The implementation postrun R2 evidence has not drifted. Its stable cleanup remains 20/20 paths with all bytes/SHA checks true, zero scratch/cache/unrelated entries, zero removals, zero deferred items, and stable manifest snapshot match. Its prior Python receipt remains 38/38, exit 0, Python 3.13.5 at `D:\Users\Newman\anaconda3\python.exe`, executable SHA-256 `388fe2cffda8a134e7d7dc4e978f7c478857ece6b69694daecbed25e51ec633a`. Julia R1-R4 remain preserved failures; R5 remains 52/52 exit 0 under Julia 1.10.5, executable SHA-256 `8e86e2d48c574393c37bbfb6e922ea4176ba8e1a83f956826f3da24948e389ad`. No execution was repeated here.

## Cleanup and dirty protection

`status_sync_r2/manifest.json` records no temporary files, no removed or deferred paths, and protects pre-existing dirty work and PIDs 65224/58068. PID 66044 is recorded as already absent with no termination. Its own manifest is excluded from its cleanup hash set. These local cleanup semantics are appropriate, but the owned-path hashes for the three core planning documents, task manifest, and implementation README are now stale, so the synchronization cannot be accepted as a current status receipt.

## Minimum repair and boundary

Refresh the AD-33 status synchronization after the current 39-task planning text is stable. Recompute all eight input hashes and every owned path, rerun `validate_plan.py`, and resolve the two reported manifest/text drift groups before issuing a new status receipt. Keep the parent node planned/proposal/accepted=false/review_pending, keep G1/G2 siblings uncreated, and retain all actual/present/physical/R credits false. No Julia/DESC rerun is needed.

This review writes only its own report and manifest. Its verdict does not promote the local scaffold or alter the AD-33 acceptance boundary.
