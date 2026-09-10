# Current Runtime V4 3-D multi-region provider audit — 2026-09-10

## Decision

Do not yet admit a complete DESC/VMEC multi-region provider from the current
candidate. Runtime V4 owns a committed, structurally accepted composition of
its candidate-bound typed 3-D inputs, an isolated candidate-bound DESC
fixed-boundary request compiler at `5363cd9`, and a gap-only geometry-program
preflight at `main@86dc03f`.

The compiler is accepted only as a gap-only boundary. Its public status set is
`(:recoverable_gap,)` and `can_emit_request=false`. The current composition
fixture returns exactly the three missing DESC convention, control, and
subject-binding gaps. The fully declared manufactured fixture returns only
`required_verified_desc_geometric_compatibility_proof`. Both resolutions carry
`request=nothing`.

The preflight shows that a geometry certificate is not yet constructible from
the current G2 candidate. It reports eleven exact prerequisites, including an
absent normalized-to-SI root bridge and absent geometry interpreter. The next
admissible edge is to implement that bridge, the actual candidate-owned
coordinate/metric programs, and their interpreter before attempting a
separately reviewed continuous-domain proof. Until that proof exists, the
compiler must not emit a request and no provider may be selected or executed.

This remains a recoverable capability gap, not terminal `unsupported`. No DESC
process or solver was started, no request or result artifact was emitted, and
no receipt or evidence was created. The accepted compiler does not modify or
extend the FreeGS slice and does not close the multi-region provider edge.

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
- `src/RuntimeV4/ThreeDPhysicalProviderInputV4.jl` now binds a typed Fourier
  boundary, coordinate/metric AST identities, pressure plus iota/current
  profiles, and toroidal flux to the current candidate, compiled G2 graph,
  mission, bounds, and scenario.
- `src/RuntimeV4/ThreeDRegionLawCompilerV4.jl` now binds one typed region's
  constitutive, source, and boundary operators. It is deliberately not a
  multi-region exact-cover declaration.
- `src/RuntimeV4/ThreeDRegionLawSetCompilerV4.jl` now extends that primitive
  with exactly one constitutive/source/boundary law triple for every oriented
  region, canonical region order, and globally unique law, AST-root, and
  output-node identities. This is structural typed ownership only.
- `src/RuntimeV4/ThreeDOrientedInterfaceInputV4.jl` now owns typed regions,
  oriented interface endpoints, conservation identity, and
  volume/trace/multiplier spaces.
- `src/RuntimeV4/ThreeDGoverningResidualJacobianV4.jl` now requires one
  distinct typed residual/Jacobian pair for every current G2 state. Composition
  compares this cover to oriented states by keyed state-node identity, so tuple
  order is not treated as physical identity.
- `src/RuntimeV4/ThreeDDiscretizationControlsV4.jl` now binds mesh, exact
  discrete-space, nonlinear, linear, and refinement controls to the same
  subject.
- `src/RuntimeV4/ThreeDPhysicalInputCompositionV4.jl` now reconstructs the
  accepted component declarations and bindings from one candidate, compiled
  prefix, mission, bounds, and scenario. Its candidate-owned support map covers
  every oriented region ID and exact support ref, but explicitly retains
  `geometric_compatibility_proved=false`: it proves co-owned structural
  association, not a coordinate transform, containment, overlap, or interface
  geometry.
- `src/RuntimeV4/DESCFixedBoundaryRequestCompilerV4.jl` now validates the exact
  candidate, prefix, composition, convention, DESC controls, and subject
  bindings against a closed, canonically ordered gap vocabulary. It
  deliberately fixes `geometric_compatibility_proved=false`, admits only
  `recoverable_gap`, and cannot emit an execution request. Its focused runner
  passed 223/223 assertions at `5363cd9`.
- `src/RuntimeV4/DESCGeometryProgramPreflightV4.jl` now reconstructs the same
  context/composition/request binding and joins the selected G2 support, chart,
  edges, program roots, input/output types, and forward-chain root identities.
  The current DESC-declared fixture returns eleven exact gaps: normalized-turn
  bounds, both angular period-axis declarations and their exact set, coordinate
  and metric chart/graph ABI mismatches, the missing normalized-to-SI bridge,
  missing input-dependent programs, missing pinned manifests, and the missing
  geometry interpreter. Focused tests passed 118/118 and the standalone runner,
  core 26/26, spine 54/54, trusted registry 65/65, trusted FreeGS 43/43, and
  pinned FreeGS 0.8.2 regression all exited zero. Independent final review
  found no remaining P1/P2 defect. The slice is gap-only and emits no proof,
  certificate, request, provider result, or evidence.

These slices and their composition remain manufactured compiler/input fixtures
with a `screen_only` ceiling, no provider selection or execution, and no
evidence or terminal authority. Composition `input_complete` means structural
input completeness only. The accepted DESC compiler does not convert that
structural package into a provider request: its declared fixture stops at the
verified geometry-proof gap and its resolution contains no request.

## Solver availability is not provider admissibility

Read-only dependency probes were run against the environments in the legacy
checkout `D:\006-Programing\LMC\outputs\fusion_concept_ai`:

| Probe | Observed result |
|---|---|
| `.venv-desc\Scripts\python.exe` | Python `3.13.5`, DESC `0.17.3`, `jax_finufft=False`, exit `0` |
| DESC interpreter SHA-256 | `cec2fab4b3258900cc330346de8c664e57fa04227406920a6edb06f0efeeebb1` |
| `.venv-desc\Scripts\desc.exe --help` | fixed-boundary DESC CLI starts successfully, exit `0` |
| Legacy tracked DESC runner SHA-256 | `scripts/desc_fourier_runner.py`: `9e0130c1968ba0a99c6a4c0e956b1dd453d3b690787ab4d5b1a71a9a9b79f252` |
| `.conda-vmex\Scripts\vmec.exe --version` | executable identifies itself as `vmex 0.7.0`, exit `0` |
| `.conda-vmex\Scripts\vmec.exe --help` | accepts an INDATA/structured input, restart and solver options, exit `0` |
| VMEX executable SHA-256 | `547ae0e1d75664e5a415c07329e7b06f6738261e32b49fddd0f86f87bf95cd35` |
| `.conda-vmex\python.exe` import probe | `vmex` and deprecated `vmec_jax` shim present; `vmec`, `vmecpp`, `simsopt`, and `xvmec` absent; exit `0` |
| VMEX package origin | `direct_url.json` names `runs/v87_vvuq_preflight_20260826/sources/vmex`, but that source directory is absent |

These observations prove dependency presence only. The installed DESC
environment can import and start its fixed-boundary path without network
access, but the old repository has no wheelhouse or hash-locked distribution
set, so that environment cannot be reconstructed offline from repository
contents alone. The local `vmec.exe` is an alias for VMEX, not a currently
integrated VMEC++/SIMSOPT provider; its recorded local package source has also
disappeared, so VMEX is callable but not repository-reproducible. Neither probe
proves that a Runtime V4 candidate can produce an accepted solver request, that
a solve converges, or that the result supplies the multi-region contract.

## Remaining geometry-proof, request-emission, result, and process gaps

The structural composition is now accepted. Before a provider can be admitted,
the following backend edges must still be typed and validated:

1. **Geometry program, proof, and request emission:** the accepted gap-only compiler
   already pins the Fourier phase/sign/NFP convention, normalized radial-profile
   basis, DESC-specific resolution and solver controls, and unsupported-domain
   checks. The accepted preflight shows that the current chart needs distinct
   normalized and SI roots joined through the support scale, real
   input-dependent coordinate/metric programs, pinned operator semantics, and
   an interpreter. Only after those prerequisites exist may a separate
   candidate-bound verifier prove the geometric semantics against the physical
   chart. Until it does,
   `can_emit_request=false` and `request=nothing`.
2. **Result:** bind a typed external result schema to the exact composition,
   candidate, regions, interfaces, coordinates, units, request, and requested
   capability. A fixed-boundary equilibrium result cannot claim that the
   composition's multi-region operators were executed.
3. **Process:** hash repository code, interpreter, dependency inventory, exact
   input/output bytes, stdout, stderr, and exit status; validate the structured
   success status and result hash; revalidate cache hits; and perform
   deterministic fresh replay before even a `screen_only` receipt is
   considered.

DESC output can close only a fixed-boundary ideal-MHD equilibrium subcapability.
It does not consume the composition's per-region constitutive/source/boundary
operators, oriented interfaces, full-state residual/Jacobian pairs, or finite-
element spaces, so it cannot by itself close the complete multi-region edge.

## Legacy reuse classification

Legacy files under `D:\006-Programing\LMC\outputs\fusion_concept_ai` are not
current Runtime V4 authority. Their permitted reuse is narrow:

| Legacy source | Classification | Reason |
|---|---|---|
| `scripts/desc_fourier_runner.py` | extract; preferred next conditional backend | Reimplement its strict fixed-boundary DESC algorithm and input checks inside the current repository from the accepted composition after the provider-specific request contract lands. It demonstrates that explicit R/Z Fourier modes, field periods/symmetry, pressure and iota power series, toroidal flux, resolution, continuation, and tolerances are required. |
| `scripts/vmex_candidate_equilibrium_runner_v1.py` | extract mapping ideas only; do not select | It records the DESC-to-VMEC phase, mode, `rho=sqrt(s)`, profile, `NS_ARRAY`, and `PHIEDGE` translations, but the runner is ignored/untracked and the installed VMEX source recorded by `direct_url.json` is gone. |
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

Both old fixed-boundary runners serialize an error object but return process
exit code `0` from `main`. A future controlled wrapper must therefore require
and validate the typed output status and result hash; process exit status alone
is not a success condition.

## Admission sequence

A future implementation should proceed from the accepted structural
composition without widening its authority:

1. preserve the accepted request-boundary compiler and gap-only geometry
   preflight; implement the normalized/SI root bridge, executable G2 geometry
   programs, and interpreter, then close
   `required_verified_desc_geometric_compatibility_proof` with a separately
   reviewed continuous-domain proof contract; only then may request emission
   be reconsidered;
2. add a repository-pinned DESC fixed-boundary adapter, dependency lock, and
   controlled process wrapper without importing legacy Genome, dictionary,
   router, result, or authority objects;
3. bind and independently validate solver outputs against the exact request;
4. keep the equilibrium subcapability separate from the still-unavailable
   provider that would execute the per-region governing, constitutive, source,
   boundary, interface, and discrete-space composition;
5. qualify with malformed/foreign/cross-candidate adversaries, cache
   revalidation, fresh replay, resolution/convergence studies, and a genuinely
   independent reference before considering any claim beyond `screen_only`.

Until then the correct status is:

```text
request_status = recoverable_gap
request_emitted = false
geometric_compatibility_proved = false
provider_status = recoverable_gap
provider_selected = false
provider_executed = false
solver_execution_attempted = false
solver_executed = false
physical_validation = false
engineering_validation = false
emits_evidence = false
p5_ready = false
credible_physical_device_count = 0
```
