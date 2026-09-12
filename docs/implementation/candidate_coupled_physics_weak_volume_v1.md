# Current-candidate static-MHD weak-volume execution

This implementation consumes the current `dgpi_context` DESC candidate and
the complete typed 17-object upstream tuple plus a real q3 or independent
cubature field/basis execution. It produces an executed constitutive weak
volume block and a measured force-moment block. The complete regional weak
residual and actual coupled PDE solve remain `deferred`.

## Reviewed legacy implementation and disposition

The following files in `D:/006-Programing/LMC/outputs/fusion_concept_ai/src`
were inspected before implementation. No legacy authority or family routing
is imported.

| Legacy implementation | Decision | Reason / retained boundary |
|---|---|---|
| `graph_residual_assembler_v94.jl` | extract | Retain the principle of explicit row/column ownership and refusing whole-graph credit for a partial subgraph. The new implementation uses current typed candidate, Genome and operator graph hashes; it does not import the dictionary runtime or authority. |
| `multiregion_conservation_providers_v116.jl` | test-only | Its 1-D core/edge diffusion and Spitzer-Harm providers declare mesh, boundary and coefficient assumptions. Those cannot represent the current candidate's 3-D DESC state. No coefficient, source, boundary, or manufactured analytical profile is transferred into the current candidate. |
| `multiregion_nonlinear_runtime_v90.jl` | reject | Region role strings select core/open states; fallback scales and reduced coefficients do not establish a current typed AST all-state residual. The legacy Newton/DAE claim is not routed into this result. |
| Existing committed DESC field and Cartesian basis providers | wrap | Invoke their exact validation entry points and consume real pressure/B/F/position/Jacobian samples from the bound equilibrium artifact. No fresh provider is started by this module. |
| Existing untracked `RegionalMHDWeakResidualV4.jl` | reject as execution provider | Its production boundary honestly records missing capabilities and `provider_executed=false`; the generic integral ledger does not execute a complete test/source/boundary weak form. It is preserved unchanged. |

## Executed equations and scope

The current real DESC samples supply pressure `p` (Pa), Cartesian magnetic
field `B` (T), force-balance error `F` (N/m³), position `x` (m), and positive
volume Jacobian. The stress is

`T = (p + dot(B,B)/(2 mu0)) I - B B' / mu0`,

with `mu0 = 1.25663706127e-6 N A^-2`, matching the already accepted interface
traction convention. The reference length `L` is a declared diagnostic scale,
not a candidate geometry mutation. For each owned region, this code executes
four scalar tests `phi = (1, x/L, y/L, z/L)` and their three Cartesian vector
components:

- Constitutive weak-volume term `integral T grad(phi) dV` (N).
- Strong force moment `integral phi F dV` (N).
- Sampled-state derivative of the first term with respect to every bound
  pressure and Cartesian B component. Rows and columns have explicit region,
  test, component and exact point ownership. Pressure derivative units are
  N/Pa and magnetic derivative units are N/T, represented with immutable
  `UnitSignature` values as well as readable unit labels.
- `integral |F| dV`, region volume and peak sampled `|F|`. These retain local
  non-closure when the net force cancels by symmetry.

For the static ideal-MHD stress convention, `F=-div(T)` and integration by
parts relates the two executed blocks through a boundary integral. This code
does not infer the boundary term by subtracting the two blocks. It does not
declare an absent external body source to be zero.

The stress convention follows the standard magnetic-pressure/tension form
([UT Austin plasma lecture](https://farside.ph.utexas.edu/teaching/plasma/lectures/node105.html)).
The existing provider is the pinned
[DESC equilibrium implementation](https://desc-docs.readthedocs.io/en/stable/_api/equilibrium/desc.equilibrium.Equilibrium.html).

## Periodicity and integration

The input quadrature weight already includes NFP. For each field period,
the code divides that scalar measure by NFP and rotates Cartesian position,
B, F and the stress tensor by `2 pi k / NFP`, then evaluates the lab-frame
tests. It never multiplies a first-period Cartesian force vector by NFP.
This is reconstruction using the provider's declared periodic model;
`periodic_model_reconstruction_executed=true` and
`full_torus_direct_sampling_executed=false` are separate immutable flags.

The analytic derivative includes the rotation of the magnetic perturbation.
A central finite difference checks every sampled pressure/B column. Since
the local stress is at most quadratic in these variables, a stress-scaled
finite step has zero centered truncation error and avoids avoidable
subtractive cancellation. This is a constitutive sample Jacobian; it is not
a derivative of the DESC equilibrium solution, geometry, density, velocity,
temperature, source closure or candidate operator AST.

## Actual blocked producers

| Needed capability | Current producer boundary | Consequence |
|---|---|---|
| Candidate-owned regional test space and all-state DOF map | `ThreeDGoverningResidualJacobianV4.jl` compiles typed ownership; this diagnostic does not replace its AST roots | No full candidate residual/Jacobian assembly |
| Candidate-owned external body-source declaration | No validated current-candidate production declaration is consumed | Source term remains unexecuted; zero is not assumed |
| Interior and exterior surface quadrature with boundary-limit state and geometry | `DESCRhoSurfaceTraceProviderV4.jl` and traction provider currently return finite-offset interface samples; accepted traction quadrature is a single sample, not a surface integral | No boundary integral or complete weak residual |
| Complete region/interface Jacobian tied to current state variables | Sample p/B constitutive derivative exists here; complete candidate state derivatives remain unavailable | No assembled global Newton matrix |
| Exterior flux/source conservation accounting | The required source and boundary providers above are absent | No global conservation verdict |
| Actual current-candidate nonlinear coupled solver | Requires complete residual/Jacobian and declared boundary/source problem | `coupled_solve_attempted=false`, not a failed solve |

## Entry points and validation

`execute_candidate_coupled_physics(upstream, regional_execution; run_dir,
reference_length_m=1.0)` creates `CandidateCoupledPhysicsResultV4` and a TSV.
`validate_candidate_coupled_physics` validates the current candidate context,
three Genome bindings and graph hashes; reopens the sealed upstream providers;
checks partition/support/node order and the declared quadrature rule; then
recomputes every integral and derivative and checks exact replay.

The output always retains `status=:deferred`, `evidence_credit=0`, and
`claim_ceiling=screen_only`. Executed weak-volume and strong-moment flags do
not turn source, boundary, complete residual, global conservation or coupled
solve flags on.

The numerical-kernel test is lightweight and starts no provider. The real
acceptance file only defines `test_candidate_coupled_physics(owner, upstream,
regional_execution, result)` so the single end-to-end runner can reuse its
already running provider chain.
