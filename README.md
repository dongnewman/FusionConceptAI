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
deferred-capability archive in `Search.jl` and `Archives.jl`.  RuntimeV4
consumes complete `CandidateStatePackageV4` objects and preserves unresolved
capability obligations; it does not manufacture missing physical components
or upgrade screen evidence.

Run the RuntimeV4 checks through the independent-process wrapper from the
repository root.  With no names it runs core, vertical, archive, and spine in
that order; names may be selected during development:

```powershell
julia --project=. scripts\test_runtime_v4.jl
julia --project=. scripts\test_runtime_v4.jl core archive
```

The wrapper starts a separate Julia process for every selected item, inherits
the active `--project`, prints each exit status, and exits nonzero if any item
fails.  The individual entrypoints remain available for focused debugging.

Run the declared software campaign with `julia --project=. scripts/run_v4_spine.jl`.
Its default S0-S10 ladder records missing physical declarations explicitly.
Traversing this ladder does not mean its physics stages have executed:
the current fixture reports withheld authority and no whole-device readiness.

The current acceptance record is in
[`docs/implementation/runtime_acceptance.md`](docs/implementation/runtime_acceptance.md).
It records the verified standalone checks and their evidence boundary.  Core
and archive checks have clean-project results; the published vertical slice
also passed 25/25 in a fresh checkout. The accepted stage spine passed 54/54;
the combined runtime checks passed 127 assertions with all five entrypoints
exiting successfully. The clean published package baseline at `310db3b`
also passed its full `Pkg.test` run. Integrated physics, L4 validation evidence,
and the user's overall fusion objective remain incomplete.
