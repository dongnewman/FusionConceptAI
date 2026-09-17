# UP2-00G independent integration-readiness review R1

Verdict: **pass_limited** (read-only static review; no Julia/DESC).

The frozen G inputs were independently rehashed: report `3a5cba18f2f660fdda652fa933b354d7e987c6fbf0472bdc70987dc4c11e27d5`, manifest `f8ec73e8d3b10a17493012268724bbcbdb5caf0c4cb869bb2490c45a98adc43b`, input hashes `27926d49a912d2dcf09cd688a2aaca49a0771375232367ade8573d1dc574a275`, and QA `21ea85358ce37c2cb00b39197b406da44d88da96cc67c93d5485525807b5644f`. The actual `fixtures.json` contains the exact ordered 50 IDs N01-01 through N10-05, and `TypedPrecompilerValidatorV1.jl` registers the same exact 50 IDs without duplicates. The report matrix also has 50 rows and marks every formal B04 cell pending.

The local boundary is preserved. UP2-00 has top-level `review_pending`/`accepted=false`, while its nested N01/N02 integration slice is `accepted_limited`; its total remains `review_pending`. N03/N04/N07-N10 are bounded local `accepted_limited` slices. E1/N05 and E2/N06 are currently `review_pending`/unaccepted; E2 retains focused exit-1 history. G manifest `fresh_formal_rows=50`, `fresh_formal_receipts=0`, and all B00/B04/provider/mesh/engineering/physical/R01-R10 credit flags are false.

The wiring gap described by G is present: `src/FusionConceptAI.jl` includes the GenomeV5 integration loader but no UP2 include or unified UP2 export; `GenomeV5Integration.jl` loads G1/G2/G3 only. The proposed G-I0, G-I1, and G-I2 package names, owned files, dependencies, output contracts, and exit gates are all present, including source-derived mutation hashes, explicit `terminal_deferred`/`fail_closed`/`program_exception`, no expected-label routing or synthetic/reused evidence, compile-before-provider ordering, and no physics inference.

Historical provenance finding: UP2-00's manifest explicitly records same-name `focused_test_r6` overwrite with original bytes unrecoverable. It is a prior limitation, not a write performed by this review. Current source/artifact drift relative to the frozen G snapshot is observed for class(es) **N05, N06**; the frozen report remains internally consistent with its own `input_hashes.json`, and this is recorded as time-snapshot provenance rather than silently promoted status.

Independent command receipts with real exit codes, stdout/stderr, and UTC timestamps are in [command_receipts.json](command_receipts.json); structured results are in [report.json](report.json). `validate_plan.py` and `git diff --check` both exited 0. Process sweep output is retained and no process was started or killed by this review.
