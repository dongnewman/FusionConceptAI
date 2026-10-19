# FusionConceptAI

FusionConceptAI implements typed G1 mechanisms, G2 fields/geometry, and G3 realization/control contracts, with candidate-bound compilation, spatial residuals, provider execution, coupled solvers, and validation interfaces.

Start with the [current architecture and remaining work](docs/v4_multitopology_generation/README.md). The [implementation record](docs/implementation/IMPLEMENTED-STATE-20261019/implementation.md) documents actual entrypoints, units, and verified limits; [run history](docs/implementation/IMPLEMENTED-STATE-20261019/run_history.md) summarizes earlier execution.

As of 2026-10-19 the experimental goal is **paused**. UP1/UP2-00 retain their user-accepted software scope. UP2's five global closures, complete UP2/UP3 acceptance, real reference-device inversion, and R01–R10 remain open. No candidate has passed all terminal physics, engineering, whole-cycle net-electric, VVUQ, originality, and fresh-process replay gates.

## Code entrypoints

- [`src/FusionConceptAI.jl`](src/FusionConceptAI.jl): package and Genome contracts.
- [`src/RuntimeV4/FusionRuntimeV4.jl`](src/RuntimeV4/FusionRuntimeV4.jl): additive runtime interfaces and components.
- [`docs/code_layout.md`](docs/code_layout.md): maintained code, compatibility contracts, and ownership.
- [`scripts/run_bounded_check.py`](scripts/run_bounded_check.py): bounded independent-process execution.

Existing software checks remain available from the repository root:

```powershell
julia --project=. scripts/test_runtime_v4.jl core archive
python -B docs/v4_multitopology_generation/validate_plan.py
```

These checks do not establish whole-device readiness. Historical raw outputs are local artifacts ignored by Git; authorized cleanup replaced most bulky outputs and temporary copies with compact records, retaining the paused-work input closure. See the [cleanup record](docs/implementation/WORKSPACE-CONSOLIDATION-20261019/README.md) for exactly what remains and what must be regenerated for replay.
