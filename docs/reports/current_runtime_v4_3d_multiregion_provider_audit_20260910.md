# Current Runtime V4 3-D multi-region provider audit — 2026-09-10

## Decision

Do not implement or admit a DESC/VMEC provider from the current candidate.
The solver installations are callable, but Runtime V4 does not yet own enough
candidate-bound physical input to construct a legitimate three-dimensional
equilibrium problem, much less the region constitutive and interface operators
required by the accepted multi-region contract.

This is a recoverable capability gap, not terminal `unsupported`. No solver job
was submitted because there is no valid current typed solver input. This audit
adds no provider, example, test, aggregator entry, result artifact, or evidence
claim, and it does not modify the accepted FreeGS slice.

## Current contract evidence

The current progress index already records real multi-region coupled physics as
absent: there is no candidate-derived 3-D constitutive/field provider through
the accepted contract. Current source confirms the separation:

- `src/RuntimeV4/ConservativeMultiRegionExecution.jl` describes itself as a
  content-addressed manufactured control. Its capability declares
  `coordinate_system="lumped_regions"`; `ConservativeRegionBalanceV4` receives
  a caller-supplied positive `diagonal`; and
  `make_conservative_interface_coefficient` receives a caller-supplied positive
  coefficient. Its provider and receipts are fixed to
  `model_class=:manufactured_control` and `claim_ceiling=screen_only`, with no
  runtime evidence or terminal authority.
- `examples/runtime_v4_g2_field_fixture.jl` owns a normalized `[-1,1]^3`
  support and a small `DOT`/`ADD` phase-logit program. The coordinate-map and
  metric roots are explicitly named
  `g2:coordinate_map_declaration:unexecuted:v1` and
  `g2:metric_declaration:unexecuted:v1`. They are declarations, not an executed
  physical chart or metric.
- `src/RuntimeV4/Compiler.jl` keeps these omissions explicit through
  `required_coordinate_declaration`,
  `required_physical_capability:<operator>`,
  `required_region_declaration`, and `required_boundary_declaration`.
- The accepted candidate-bound FreeGS execution is an axisymmetric
  `physical_model_screen` using a manufactured G2 fixture. It is neither a
  three-dimensional equilibrium provider nor a provider of real region
  constitutive/interface closure and must remain isolated.

The current G2 examples contain no typed Fourier surface, real spatial mesh,
pressure/iota/current profiles, toroidal flux, region material laws, physical
sources and boundaries, or typed 3-D provider result binding. A process can be
available while the candidate-to-input translation remains undefined; solver
availability therefore does not close this edge.

## Solver availability is not provider admissibility

Read-only dependency probes were run against the environments in the legacy
checkout `D:\006-Programing\LMC\outputs\fusion_concept_ai`:

| Probe | Observed result |
|---|---|
| `.venv-desc\Scripts\python.exe` | Python `3.13.5`, DESC `0.17.3`, `jax_finufft=False`, exit `0` |
| DESC interpreter SHA-256 | `cec2fab4b3258900cc330346de8c664e57fa04227406920a6edb06f0efeeebb1` |
| `.conda-vmex\Scripts\vmec.exe --version` | executable identifies itself as `vmex 0.7.0`, exit `0` |
| `.conda-vmex\Scripts\vmec.exe --help` | accepts an INDATA/structured input, restart and solver options, exit `0` |
| VMEX executable SHA-256 | `547ae0e1d75664e5a415c07329e7b06f6738261e32b49fddd0f86f87bf95cd35` |
| `.conda-vmex\python.exe` import probe | `vmec`, `vmecpp`, `simsopt`, and `xvmec` modules all absent; exit `0` |

These observations prove dependency presence only. In particular, the local
`vmec.exe` reports VMEX, not a currently integrated VMEC++ Python provider.
Neither probe proves that a Runtime V4 candidate can produce a solver input,
that a solve converges, or that the result supplies the accepted multi-region
physics contract.

## Exact missing current typed ownership

Before a provider can be implemented, one exact `ForwardChainContextV4` subject
must seal all of the following to the G2 graph, mission, bounds, and scenario:

1. A physical 3-D coordinate map and metric, or a complete Fourier boundary
   with mode indices, coefficients, `nfp`, symmetry convention, orientation,
   units, and validity domain.
2. Pressure and either iota or current profiles, toroidal flux, their units,
   admissible ranges, provenance, and profile convention.
3. Region partitions and material constitutive tensors or coefficient laws,
   plus physical sources and boundary conditions attached to exact regions.
4. Typed, oriented interfaces with exact endpoint regions, transfer/flux law,
   units, ledger conservation identity, and the required mortar, multiplier,
   or other discrete trace spaces.
5. One governing residual for each owned state/equation, its additive terms,
   state ordering, and residual/Jacobian ownership.
6. Mesh or spectral levels, discretization choices, initialization/restart
   state, convergence tolerances, and a backend capability manifest derived
   from the current context rather than caller self-assertion.
7. A typed external result schema binding solver outputs back to the same
   candidate, regions, interfaces, coordinates, units, and requested physical
   capabilities.
8. A controlled process boundary that hashes code, interpreter/executable,
   dependencies, exact input and output bytes, stdout, stderr, and exit status;
   revalidates cache hits; and performs deterministic fresh replay before any
   `screen_only` receipt is considered.

DESC equilibrium output alone would still not satisfy items 3–5. The accepted
multi-region layer needs candidate-derived constitutive, source, boundary,
interface, and discrete-space ownership in addition to a 3-D field solve.

## Legacy reuse classification

Legacy files under `D:\006-Programing\LMC\outputs\fusion_concept_ai` are not
current Runtime V4 authority. Their permitted reuse is narrow:

| Legacy source | Classification | Reason |
|---|---|---|
| `scripts/desc_fourier_runner.py` | extract | Reimplement its strict fixed-boundary DESC algorithm and input checks only after current typed inputs exist. It demonstrates that explicit R/Z Fourier modes, field periods/symmetry, pressure and iota power series, toroidal flux, resolution, continuation, and tolerances are required. |
| `scripts/desc_w7x_runner.py` and packaged W7-X data/docs | test-only | Useful as a known-device regression. The packaged W7-X state is not derived from the current candidate and cannot fill missing candidate fields. |
| `scripts/desc_candidate_equilibrium_convergence_runner_v1.py` | test-only | Retain convergence-test intent, not its old input/result authority. |
| `scripts/run_desc_candidate_equilibrium_convergence_v1.jl` | reject from current core | Uses the old Genome boundary, mutable dictionaries, and historical source/result artifacts. |
| `src/adapters/stellarator_desc_fourier_v1.jl` | reject from current core | Uses legacy family routing, Genome and evaluator authority; any reusable solver mechanics are already represented by the extract-only Python runner. |
| `src/multiregion_interface_assembly_v93.jl` and related v89/v93 schemas/runtime | test-only for negative intent; reject types/authority | Preserve vocabulary for governing residuals, material fields, boundary ownership, interface endpoints and mortar/multiplier spaces. Do not import their dictionary contracts or reduced unsupported verdict. |
| `src/multiregion_conservation_providers_v116.jl` | reject from current core | Historical candidate dictionaries and analytic manufactured providers do not furnish current 3-D constitutive/interface closure. |

The legacy W7-X documentation explicitly notes that its generic mechanism seed
does not contain a reconstructable Fourier boundary or profiles. Running that
packaged case, an old JSON payload, or a historical smoke artifact would create
old/test evidence, not current-candidate evidence. Historical raw runner success
also cannot override a failed physics gate or be promoted into a current
receipt.

## Admission sequence

A future implementation should proceed only after the current typed ownership
above lands and validates independently:

1. compile the exact candidate/context into a canonical, inspectable 3-D
   provider request and stop with a typed recoverable gap on any omission;
2. add the isolated controlled-process adapter without importing legacy
   Genome, dictionary, router, result, or authority objects;
3. bind and independently validate solver outputs against the exact request;
4. translate the physical fields into typed per-region governing,
   constitutive, source, boundary, and oriented interface terms accepted by
   `ConservativeMultiRegionExecutionV4`;
5. qualify with malformed/foreign/cross-candidate adversaries, cache
   revalidation, fresh replay, resolution/convergence studies, and a genuinely
   independent reference before considering any claim beyond `screen_only`.

Until then the correct status is:

```text
provider_status = recoverable_gap
solver_execution_attempted = false
p5_ready = false
credible_physical_device_count = 0
```
