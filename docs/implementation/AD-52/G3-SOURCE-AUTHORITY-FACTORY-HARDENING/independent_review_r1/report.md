# AD52 G3 source-authority factory hardening — independent review R1

## Verdict

`pass_limited` with `accepted=false`. This review accepts only the fail-closed software capability of the G3 source factory under the reviewed inputs. It does not accept AD52 itself, create source authority or trust, and grants no candidate, final, provider, mesh, solver, engineering, physical, search, R01–R10 or L4 credit.

## Frozen inputs and status boundary

`input_hashes.json` freezes the two implementation inputs and all 44 files in the AD52 implementation evidence package. The factory is `35491` bytes, SHA-256 `ceac9a33368606843337194ee446b6de6f2b7c6223cbc110229d5df17cf84d39`; its focused test is `21883` bytes, SHA-256 `23155dd7e7c6440177fe666fe463f73603b2c63a4572796801cbcee7d99c1e5b`. The package remains `package_status=completed_review_pending`, `accepted=false`, and requires fresh S2/S3 evidence. Existing AD48 receipts were read as historical inputs and were not modified.

## Independent code and adversarial review

The source contains four explicit scope mappings: realization → `RealizationGenomeV5.jl`, control → `ControlGenomeV5.jl`, binding → `CoupledRealizationControlBindingV2.jl`, and bundle → `RealizationControlGenomeV5.jl`. The Git closure checks repository root, exact HEAD, `ls-tree` path, one stage-zero `ls-files --stage` entry, 40-hex blob, `show`/`cat-file` byte equality, working-tree bytes/SHA/length, porcelain cleanliness, and index flags. `assume-unchanged`, `skip-worktree`, path/status/blob/hash/byte mismatches all have explicit fail-closed routes. Current repository factory source is untracked and absent from HEAD; its result is expected to remain typed absence with no declaration publication. The source does not mutate the default registry.

An independent Python probe created a temporary HEAD-tracked Git fixture for all four scopes. It observed 4/4 positive Git closures and independently observed five adversarial controls: assume-unchanged, skip-worktree, dirty status, current factory source untracked, and current factory source absent from HEAD. The fixture was removed by `TemporaryDirectory`; raw stdout, stderr, PID `97852`, UTC and exit `0` are retained under `raw/adversarial_git_probe.*`.

## Independent execution

The focused Julia lane was run serially with PID `64592`, UTC `2026-09-15T20:35:32.6557823Z`, exit `0`, and `356/356` checks; raw streams and receipt are under `raw/focused.*`. This is software contract evidence only. No DESC, physics, provider, mesh, solver or search run occurred. The independent Python plan validator used PID `95784`, UTC `2026-09-15T20:41:21.157854Z`, exit `0`, reporting 31 Markdown, 534 relative links, 39 tasks and an acyclic DAG. Independent scoped diff check used PID `81288`, UTC `2026-09-15T20:41:33.765928Z`, exit `0`.

## Preservation and claim ceiling

The implementation package's prior failed attempts remain in its failure history and were not overwritten. The review writes only `independent_review_r1/**`; no source/test/core document/task manifest/AD48/AD49 evidence/runs file was changed, no file was staged or committed, and no unrelated dirty path was touched. Cleanup inventory records no residual fixture, script, `__pycache__` or temporary file. `trusted_source_identity=false`, `candidate_identity=false`, `final_candidate_or_package_declaration_hash=false`, and `L4=0`; fresh S2/S3 remains mandatory for any later source or trusted identity claim.
