# FusionConceptAI v4 runtime

This repository contains the typed three Genome contracts used by
FusionConceptAI: G1 mechanism, G2 field and geometry, and G3 realization and
control.  The source package entrypoint is
[`src/FusionConceptAI.jl`](src/FusionConceptAI.jl).  The frozen v4 contract and
Genome documents are under
[`docs/v4_multitopology_generation`](docs/v4_multitopology_generation), with
the implementation plan in
[`docs/implementation/sol_runtime_plan.md`](docs/implementation/sol_runtime_plan.md).

The additive RuntimeV4 module is assembled by
[`src/RuntimeV4/FusionRuntimeV4.jl`](src/RuntimeV4/FusionRuntimeV4.jl).  Its
implemented contracts cover typed candidate-prefix compilation, exact
capability matching, conservative materialization and solver-input identity,
screen-level execution evidence, stage evidence closure, and the standalone candidate queue and
deferred-capability archive in `Search.jl` and `Archives.jl`, plus a
candidate-local algebraic scoped work/archive layer.  RuntimeV4
consumes complete `CandidateStatePackageV4` objects and preserves unresolved
capability obligations; it does not manufacture missing physical components
or upgrade screen evidence.

Run the RuntimeV4 checks through the independent-process wrapper from the
repository root. With no names it runs core, vertical, archive, spine,
algebraic, algebraic_slice, algebraic_scoped, and g2_field in that order. The three CLI
checks remain selectable by name:

```powershell
julia --project=. scripts\test_runtime_v4.jl
julia --project=. scripts\test_runtime_v4.jl core archive
julia --project=. scripts\test_runtime_v4.jl algebraic_scoped
julia --project=. scripts\test_runtime_v4.jl g2_field g2_field_cli
```

The wrapper starts a separate Julia process for every selected item, inherits
the active `--project`, prints each exit status, and exits nonzero if any item
fails.  The individual entrypoints remain available for focused debugging.

Run the declared software campaign with `julia --project=. scripts/run_v4_spine.jl`.
Its default S0-S10 ladder records missing physical declarations explicitly.
Traversing this ladder does not mean its physics stages have executed:
the current fixture reports withheld authority and no whole-device readiness.

The bounded numerical example is available with
`julia --project=. scripts/run_v4_algebraic_slice.jl`. It extracts the declared
parameter-free, zero-dimensional scalar constraint AST and runs a bounded
Newton solve. The two-equation regression system reaches `(2, 1)` with zero
reported residual; its evidence is `screen_only` and covers the selected
constraint subgraph. The remaining candidate obligations are retained.

The candidate-local scoped search check is available with
`julia --project=. test/runtime_v4_algebraic_scoped_search_tests.jl`. Its
59 assertions cover exact local-provider provenance before archive mutation,
deterministic queue selection without global revival, typed screen resolution
versus numerical-failure attempts, preservation of unresolved candidate
obligations, and checkpoint identity. A scoped resolution remains attached to
one candidate, prefix, plan, stage, and scenario; it does not close generic
physical gaps or revive the candidate for whole-device stages.

The typed G2 field producer runs with
`julia --project=. scripts/run_v4_g2_field_evaluation.jl`. It evaluates the
declared static scalar AST on an explicit chart-coordinate grid. The example
computes `2x - y + 1` at 27 points, with minimum `-2` and maximum `4`.
Its sealed, typed result and evidence bind the candidate, plan, scenario,
operator manifests, provider source, and cache identity. Coordinate-map and
metric execution remain unresolved; this field evaluation does not solve a PDE
or establish physical-device readiness.

The current acceptance record is in
[`docs/implementation/runtime_acceptance.md`](docs/implementation/runtime_acceptance.md).
It records the verified standalone checks and their evidence boundary.  Core
and archive checks have clean-project results; the published vertical slice
also passed 25/25 in a fresh checkout. The accepted stage spine passed 54/54;
the numerical core passed 77/77 and its integration passed 22/22. The combined
runtime release check passed 285 assertions across all seven suites; both
CLI checks also exited successfully. The root ran all nine entrypoints in a
fresh `89a85dd` worktree with the frozen implementation snapshot and updated
Project and Manifest loaded together.
The G2 producer passed 50 focused assertions and its CLI against the published
G1 contract. A subsequent independent combined snapshot containing the pending
G1 r2 migration, final G2 producer, and canonical String-axis fix passed
348 assertions across eight suites and all three CLIs. This is RuntimeV4
interoperability evidence; the G1 migration's full package test remains a
separate release requirement.
The clean published package baseline at `310db3b`
also passed its full `Pkg.test` run. Integrated physics, L4 validation evidence,
and the user's overall fusion objective remain incomplete.
