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
- Bounded algebraic residual core: **77/77**; module/CLI integration:
  **22/22**. Sol signed off the parameter-free 0D scalar constraint slice.
  The root independently placed the frozen implementation/dependency
  snapshot into a fresh `d2b6d69` worktree, including both `Project.toml` and
  `Manifest.toml`, then ran all six pre-scoped RuntimeV4 suites and both CLIs.
  All eight entrypoints exited zero, reporting **226 passing assertions** in
  total.
  The algebraic CLI started from `(0.5, -0.25)` and returned `(2.0, 1.0)`,
  residuals `(0.0, 0.0)`, and normalized residual norm `0.0`.
- Candidate-local algebraic scoped search: **59/59** in
  `test/runtime_v4_algebraic_scoped_search_tests.jl`, first run in a
  clean `d2b6d69`-based smoke project and independently confirmed by the root
  in a fresh `89a85dd` worktree. The root then ran the expanded seven suites
  and both CLIs with the six frozen implementation/dependency files copied
  together. All nine entrypoints exited zero on 2026-09-05; the 27 test-summary
  rows reported **285 passing assertions**. The tested files matched the main
  release snapshot by SHA-256. The suite checks exact local-provider
  provenance before archive mutation, deterministic queue selection without
  global candidate revival, typed `AlgebraicScopedResolutionV4` versus
  `AlgebraicScopedAttemptV4`, full status/provenance/threshold binding,
  preservation of compiled unresolved and capability obligations, and
  checkpoint identity.  The scoped result is candidate-, prefix-, plan-,
  stage-, and scenario-bound screen bookkeeping; it does not close physical
  gaps, revive the whole candidate, or satisfy S1-S10/P5.

- Typed G2 field evaluation: **50/50** focused assertions and CLI exit **0**
  against the published G1 contract. Sol independently audited and reran the
  final source, including the isolated fixture module that removes constant
  redefinition. The root then tested the final G2 snapshot together with the
  pending G1 r2 migration and the canonical String-axis correction. All **11
  entrypoints** exited zero; **30 test-summary rows / 348 assertions** passed
  with no warning or error. All **35 reviewed source-file SHA-256 values**
  remained unchanged throughout this combined run. The separate final G1
  full-package acceptance is recorded below.
  The field CLI computed `2x - y + 1` on 27 chart-coordinate nodes, with
  minimum `-2`, maximum `4`, and a typed scalar result. Evidence remains
  `screen_only`, with zero credible physical candidates and withheld authority.
  Tests cover exact operator manifests, provider/code/plan/scenario binding,
  grid bounds, sealed results, cache replay, and unknown-operator execution
  returning no subject, input, or evidence. A genuine `DT@v1` program is
  rejected by the upstream static-only phase-root contract; this does not
  claim coverage of an unreachable selected-DT compiler path.

- Final G1 r2 occurrence-ownership migration: **2,616/2,616 assertions** in
  **104 test-summary rows**, complete `Pkg.test`, exit **0** on 2026-09-05.
  The root ran Julia 1.10.5 with startup files disabled in the independent
  `e848e53`-based `fusion-v4-g1-acceptance` worktree, containing the frozen
  27-file migration. All 27 source/test/document raw hashes remained unchanged
  through the run and after copying the migration to main. Project/Manifest
  parsed contents and the Julia executable also match, as detailed below.
  The default runner includes both long fresh-process poison suites and
  the occurrence-ownership suite without diagnostic skip switches.
  The final tests distinguish external ledger identity changes from balanced
  coefficient changes, and constructor rejection from migration rejection.
  Main also matches the **32 unchanged raw-byte files** of the prior 348-assertion
  RuntimeV4 snapshot. The remaining three files are the two final package-test
  corrections and the migration implementation document. A fresh Git checkout
  may expand Julia sources to CRLF; its provider source hashes must be recorded
  separately from the LF snapshot and cannot borrow the latter's cache identity.
  After integration, the main-worktree smoke run passed **26 core assertions**
  and the G2 field CLI exited **0**, retaining its unresolved physical obligations.
  This acceptance covers software contracts and interoperability only.

For the G1 migration protocol's environment comparison, the 27 reviewed files
use exact raw SHA-256 identity. Project/Manifest raw hashes are recorded as
checkout provenance; their parsed TOML values must be exactly equal. The fresh
checkout uses CRLF and main uses LF, so their raw environment-file hashes differ:

| File | Fresh acceptance SHA-256 | Main SHA-256 |
|---|---|---|
| Project.toml | `2375FAEBADAB2D223EA693D171110BB2E6F9B37D941BEA29E7F9B16DF39B4629` | `97435481303DE9F543DACBB7B5C9AAB0F35493420BAC8310E99FB5A217169624` |
| Manifest.toml | `5072F85F611B59513FC61E716DC4CB64449DEF592BCA44543943F6564B1EC53E` | `C616BAAD478290530456E0D692D62A13A309DA9235529A3B94A437B2AB2D2203` |

Julia `TOML.parsefile` deep equality passed for both files, including locked
dependency versions and tree identities. The Julia executable SHA-256 matched
`8E86E2D48C574393C37BBFB6E922EA4176BA8E1A83F956826F3DA24948E389AD`.
Sol accepted this as unchanged dependencies and execution environment; a
change to reviewed source bytes, parsed dependency content, or the Julia
executable requires renewed relevant verification. This TOML comparison does
not normalize executable provider sources or permit cache identity reuse.

The algebraic numerical capability is restricted to declared G1 constraint roots using
`IDENTITY`, `ADD`, `SUB`, `NEG`, `SCALAR_MUL`, and `SCALAR_DIV` at revision v1.
The solver uses finite differences and bounded Newton steps under a frozen
protocol. Tests check actual residuals, failed convergence, singularity,
division by zero, bounds, registry/prefix binding, provider identity, and
cache corruption. Evidence binds the provider source SHA and stays
`screen_only`. The CLI retains three ignored edge hashes and the unresolved
whole-candidate physical obligations; it reports withheld authority and
zero credible physical candidates. This is an artificial regression system,
not an independently validated fusion device.

The checks above are contract, canonicalization, routing, queue/archive, and
software-screen checks.  They do not constitute integrated multiphysics,
engineering qualification, independent validation, or VVUQ evidence.

## Migration and compatibility history

The initial worktree contained a partial G1 ownership change with a
seven-argument constructor and incompatible nine-argument fixtures. The final
r2 migration replaces that mixed state coherently: type, admission, canonical
transport, hash layers, migration receipts, fixtures, and runtime call sites.
The original 16 dirty files were preserved byte-for-byte until the reviewed
migration was integrated. The historical archive 35/35 result above uses the
earlier clean project and fixture; it remains distinct from the final r2
package and RuntimeV4 results. The clean c0e0d85 acceptance baseline also
exposed nine JSONL line-ending failures; the narrow root
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
stages. The executors perform structural screening, candidate-local scoped
queue/archive bookkeeping, a bounded algebraic constraint-subgraph solve, and
typed G2 static field-program evaluation;
no integrated multiphysics
solver or numerical VVUQ provider has been accepted. Integrated physics
evidence is **0**, L4 evidence count is **0**, and no zero-unsupported result
is treated as proof that the overall goal has been achieved.  No claim of
physical readiness, validation, or complete fusion-device realization follows
from the tests listed above.

The full clean `Pkg.test` run at `ca6a9be` passed the earlier JSONL boundary
but stopped at a pre-existing `pwd()/test` helper-path error in conservation
scope tests. The narrow fix is published in `310db3b`; both the 55 focused
assertions and the subsequent full-package run passed. The accepted stage
spine is published in `d2b6d69`. The algebraic numerical qualification above
extends the software-screen checkpoint without raising its physical evidence
ceiling. General ODE/DAE/PDE, whole-device execution, numerical VVUQ,
independent validation, and final minimality certification remain unfinished.
