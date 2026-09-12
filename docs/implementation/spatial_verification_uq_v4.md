# Spatial verification and executed flux propagation

This implementation is staged independently of the sealed reduced-model run.
It must consume actual spatial cases and cannot substitute manufactured fields
for their state or current artifacts.

## Legacy and prior implementation audit

| Source | Decision | Reason |
| --- | --- | --- |
| `../outputs/fusion_concept_ai/src/generic_vvuq_runtime_v94.jl` | extract | Central finite differences verify derivatives independently of analytic Jacobian code; no graph registry or authority is imported. |
| Legacy `run_pvw_numerical_vvuq_v94` | test-only | Its 1-D manufactured plasma/vacuum model does not verify a curved three-dimensional Q1 spatial state. |
| `../outputs/fusion_concept_ai/src/physical_vvuq_runtime_v96.jl` | extract | Separate independent arithmetic from experimental validation; do not import old physical-credit flags. |
| `../outputs/fusion_concept_ai/src/numerical_verification.jl` | reject | Invented measurement floors and combined error scores cannot replace independent error categories. |
| Current `ExecutedVerificationUQV4.jl` | extract/reject | Retain explicit state/output binding and analytic comparisons; reject its aggregate-only Jacobian gate and four-amplitude scope as spatial acceptance. |
| Current Decimal audit | extract | Its independent scalar arithmetic method explains cancellation. It is not a spatial PDE/MMS or a replacement production solve. |

All local spatial Jacobian rows use complete declared row-support coloring. The
global linear toroidal-flux row uses an independent Python surface integral for
every state column. This avoids forcing hundreds of colors merely because one
global row touches many otherwise independent nodes. No row or column is omitted.
Coloring is forbidden from inferring support from only numerically nonzero entries.
Every column and every physical row block is gated after declared unit scaling;
large magnetic blocks cannot mask pressure derivatives. Empty structural columns
are recorded as model/rank information, not silently removed from the state.

The independent Python oracle reconstructs Q1 basis, cylindrical field gradients,
stress, current and all weak/strong terms using content-checked geometry bytes. The
strong momentum expression includes `B*div(B)/mu0`. MMS uses independent affine
Cartesian B and pressure with an analytic nonzero source and boundary values.
Coarse and fine manufactured interpolants remain software benchmarks, separately
identified from actual candidate states and flux-endpoint propagation.

## Implemented numerical contract

The oracle reads the candidate/context/state identities, the actual primitive
geometry CSV files, the mesh ownership and the actual state. It neither imports
DESC nor invokes Julia assembly to create its independent result. Local corner
bases are merged at the axis and periodically wrapped on angular seams. The
cylindrical basis derivative is retained before rotation to Cartesian components.

Weak momentum includes volume stress, explicit source, every interior/interface
flux and the prescribed exterior traction. Strong momentum contains
`curl(B)/mu0 cross B + B*div(B)/mu0 - grad(p) - source`, plus numerical-minus-own
boundary flux corrections. Divergence, exterior traction, exterior normal-field
and toroidal-flux constraints are reconstructed separately. `N` and `Wb` blocks
retain their own units and conditioning scales; there is no raw mixed-unit norm.

| Check | Fixed numerical threshold | Interpretation |
| --- | --- | --- |
| Independent residual, each physical block | Scaled norm difference ≤ `1e-8 + 1e-8 * scaled reference norm` | Independent implementation at the same quadrature and geometry |
| Full Jacobian, every column and every block | Scaled column error ≤ `1e-8 + 1e-6 * scaled reference norm` | Includes weak pressure columns and independent linear flux row |
| Circuit current | `1e-12 A + 1e-9 * reference magnitude` | Entire actual conditional trajectory |
| Circuit energy | `1e-15 J + 1e-9 * reference magnitude` | Independent exponential antiderivatives |
| Circuit flux estimate | `1e-15 Wb + 1e-9 * reference magnitude` | Separate dimensioned threshold |
| Circuit branch voltage | `1e-12 V + 1e-9 * reference magnitude` | Includes branch commutation limits |

Finite differences use `cbrt(eps(Float64))*max(abs(x_j), unit_reference_j)` with
references `1 T` and `1000 Pa`. These are declared numerical conditioning values,
not physical uncertainty inputs. Explicit zero sparse entries outside a minimal
mathematical support are allowed; nonzero analytic entries outside support fail.
Each independent derivative column and each finite-difference sparse entry is
persisted, so an aggregate norm cannot conceal an unverified column.

The curved-domain MMS has independently specified Cartesian magnetic field
`(.2+.02*y, -.1-.015*z, .3+.01*x) T` and pressure
`500 + 4*x - 3*y + 2*z Pa`. It is solenoidal and its analytic current is
`(.015,-.01,-.02)/mu0 A/m²`, giving a nonzero analytic momentum source. Both actual
coarse and fine geometries execute the analytic field and its nodal Q1
interpolant. The production assembly separately consumes the analytic source,
traction and normal field; those manufactured arrays cannot become candidate
initializers or outputs. These benchmarks check source/boundary/field arithmetic
and interpolation. They do not solve an MMS nonlinear problem and do not establish
a solved-solution convergence order.

## Distinct error and evidence categories

1. Independent residual/Jacobian disagreement is an implementation or arithmetic
   question at fixed input and quadrature. Raw errors, scales and thresholds are
   stored by block/column; no threshold is relaxed after viewing an outcome.
2. Strong/weak identity differences on analytic MMS are quadrature/geometry
   consistency diagnostics. Current-state strong/weak differences also reflect
   the discrete field and face treatment; neither is called a certified isolated
   integration-error bound.
3. Two-space analytic-interpolant differences describe approximation. The two
   failed candidate solves, if failed, cannot establish discretization order.
4. Actual solve histories, feasibility, gradient and sparse QR diagnostics retain
   solver meanings. A stopped iteration is not proof of an irreducible residual
   floor or a constrained optimum.
5. Physical validation and model discrepancy remain unimplemented and unexecuted:
   no applicable experiment or independent physical solver is supplied. Numerical
   software verification supplies no physical-validation credit.

All four actual cases receive residual and full-column derivative verification.
Both actual nominal mesh levels receive the MMS checks. Deterministic propagation
consumes the actual `nominal_coarse`, `flux_low_coarse`, `flux_high_coarse` solved
states, current artifacts, finite-aperture flux and both conditional circuits.
The interval and source come from G2's toroidal-flux declaration. Sampled ranges
and endpoint secants are conditional calculations; no distributions, confidence
intervals or certified global bounds are manufactured. Fine is retained as a
numerical diagnostic and never selected to replace the fixed coarse primary case.

The actual stationary subsystem has static flux and zero induced emf. Prescribed
ramp outputs are explicitly conditional. A second circuit implementation uses
256-bit direct exponential antiderivatives, independent of the production
small-argument expansions, to replay every actual nominal/short trajectory and
energy integral. It independently checks peak induced emf, the total energy
identity and the maximum per-segment identity defect in addition to current,
branch voltage, flux estimate and accumulated energies. The engineering branch's vector-potential reciprocity provides
an independent formulation for the finite-aperture Biot-Savart transfer.

## Execution and binding

`execute_spatial_verification_v4(context,upstream,physics,engineering,run_dir)`
first validates actual upstream physics/current/engineering bindings. It executes
the independent Python oracle, local colored differences, both MMS levels and
the high-precision circuit comparisons, then writes raw CSVs, per-case logs and
process exit codes, a serialized numerical payload and a verification exit code.
`SpatialVerificationResultV4` binds candidate, context, source, upstream, physics,
engineering and case state hashes. A numerical exit of 0 is compatible with a
propagated physical failure; result status and physical qualification remain
separate. Artifacts include raw input/source/environment hashes and commands.
The result validator reconstructs the canonical independent-oracle request from
the actual physical state, declared mesh, raw geometry and row scales and compares
its exact bytes. It also checks the full structural pattern hash. This prevents
relabeling an unrelated oracle run without repeating finite differences or Python.

The independent Python focused checks executed 3/3 with exit 0. The binding-
hardened Julia focused checks subsequently executed 33/33 with exit 0. Narrow
MMS-column/source-norm and circuit-identity checks added after that run still need
a focused rerun. Actual candidate execution remains unexecuted. See the companion
staging report for the exact state and explicit artifacts.
