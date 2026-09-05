# RuntimeV4 acceptance record

This is a factual implementation checkpoint, not a claim of physical
feasibility or whole-device readiness.  It records the checks completed on
the RuntimeV4 additive path and the boundaries that remain active.

## Confirmed checks

- Runtime core standalone tests: **13/13** in
  `test/runtime_v4_core_tests.jl`, re-run in the clean acceptance project
  `D:\006-Programing\LMC\.codex_tmp\fusion-v4-final-acceptance` against the
  additive source files.
- Runtime vertical-slice tests: **25/25**, independently re-run by the root
  coordinator entirely from the fresh published `7e299b6` checkout using
  `julia --startup-file=no --project=. test/runtime_v4_vertical_slice_tests.jl`.
  This verifies the published P1 entrypoint, not the in-progress spine files.
- Queue/archive standalone tests: **35/35** in
  `test/runtime_v4_archive_tests.jl`, re-run with the same clean acceptance
  project and the published 9-argument Genome fixture.  It includes
  non-empty queue metadata merge, deferred multi-gap revival, deterministic
  scheduling, and local checkpoint corruption checks.
- G2 5.3 JSONL golden content hashes: **4/4** matched the fixture records
  (`binding`, `typed`, `phase`, and `set`) using the tab-delimited content
  field and stdlib SHA-256 rule from `field_geometry_5_3_tests.jl`.
- The fresh acceptance checkout also verified the fixture files have no CR
  bytes after the approved `.gitattributes` rule.
- Stage spine: **54/54**, including positive two-scenario screen closure,
  foreign-provider and prerequisite rejection, and typed unresolved stage
  declarations. Sol signed off the architecture and evidence boundaries.
  The root coordinator independently copied only the reviewed runtime step
  into a fresh `310db3b` worktree and ran core, vertical, archive, spine, and
  the CLI through `scripts/test_runtime_v4.jl`. All five exited zero; the
  four test suites passed **127 assertions** in total.
- The default CLI enumerated **11 stages** (S0-S10) and **76 phase-specific
  gap records**. It reported `admitted=false`, `p5_ready=false`,
  `provider_coverage_complete=false`, `goal_acceptance=false`,
  `terminal_classification_executed=false`, and `classification=withheld`.
  Missing physical requirements are typed unresolved declarations, not
  copied structural-screen capabilities. Admission and closure can each
  report the same missing requirement, so 76 is not a unique capability count.
- Conservation-scope test portability: **55/55** (44 ordinary and 11
  adversarial assertions), independently run from the clean checkout's
  `test` directory after resolving helper paths relative to source files.
- Full published-package baseline: `julia --startup-file=no --project=. -e
  'using Pkg; Pkg.test()'` at clean commit **310db3b** exited **0** on
  2026-09-05. Its 101 test-summary rows reported **2,576 passing assertions**,
  followed by `Testing FusionConceptAI tests passed`. This run excludes the
  pre-existing uncommitted G1 migration and is separate from the additive
  RuntimeV4 checks above.

The checks above are contract, canonicalization, routing, queue/archive, and
software-screen checks.  They do not constitute integrated multiphysics,
engineering qualification, independent validation, or VVUQ evidence.

## Known worktree boundary

The main worktree contains uncommitted G1 ownership work.  Its current
7-argument ownership form is incompatible with the committed clean fixture
that uses the 9-argument ownership form.  The archive 35/35 result above uses
the clean project and published fixture; the earlier dirty 35/35 result must
not be used as clean-release evidence.  The clean c0e0d85 acceptance baseline
also exposed nine JSONL line-ending failures; the narrow root
`.gitattributes` rule `test/fixtures/*.jsonl text eol=lf` fixes that boundary,
and the fresh acceptance check confirmed the fixture bytes and hashes.

The referenced implementation checkpoints are `d2ccb61` (approved runtime
plan), `0d779ff` (RuntimeV4 core), `ec82c8f` (fixture line-ending compatibility),
`7f93e68` (declared Genome vertical slice), `7e299b6` (queue/archive), and
`ca6a9be` (archive regression bound to the published G1 fixture), and
`310db3b` (source-relative scope-test helper paths). These identifiers are
provenance for the implementation state; they do not raise the evidence
ceiling.

## Current incompleteness

Search/archive code has standalone coverage. The stage spine now provides
the declared campaign, exact provider admission, evidence closure checks,
and withheld authority path. It does not execute the missing physical
stages. The published executor performs only structural screening; no integrated numerical
solver or numerical VVUQ provider has been accepted. Integrated physics
evidence is **0**, L4 evidence count is **0**, and no zero-unsupported result
is treated as proof that the overall goal has been achieved.  No claim of
physical readiness, validation, or complete fusion-device realization follows
from the tests listed above.

The full clean `Pkg.test` run at `ca6a9be` passed the earlier JSONL boundary
but stopped at a pre-existing `pwd()/test` helper-path error in conservation
scope tests. The narrow fix is published in `310db3b`; both the 55 focused
assertions and the subsequent full-package run passed. The separate
zero-dimensional algebraic solver remains under development and is outside
this checkpoint. The accepted stage spine is published in `d2b6d69`.
