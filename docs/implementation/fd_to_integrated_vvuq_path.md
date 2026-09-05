# From the native field screen to integrated VVUQ

## Purpose and present boundary

This document fixes the next implementation sequence after the bounded native
field residual slice. It does not change any Genome document or infer physics
from a device, family, role, or display name.

The implemented numerical subject is deliberately narrow: one declared,
static, scalar, three-dimensional G1 constraint; an exact G2 typed field
program for source and Dirichlet data; a diagonal affine chart; and a bounded
second-order structured-grid solve. Its manufactured control can establish
software execution and numerical convergence only. Its claim ceiling is
`screen_only`.

The current grammar, bounds, mission, and evidence scope must remain explicit:

- **grammar:** the audited typed AST/operator manifests and the supported
  linear residual/weak-form subset;
- **bounds:** declared chart, scale, grid or mesh limits, parameter intervals,
  solver protocol, and resource ceiling;
- **mission:** the frozen candidate mission and named scenarios;
- **evidence:** manufactured numerical controls, code-to-code comparison,
  model validation data, engineering evidence, and whole-device closure remain
  distinct layers.

No manufactured control, mesh refinement result, or agreement between two
codes is experimental validation of a fusion device.

## Ordered implementation batches

### Batch A: finish the native candidate-to-evidence path

`FieldResidualPipeline.jl` must execute the frozen G2 source and boundary roots,
compile the exact G1 constraint edge, assemble with the reviewed native kernel,
solve the 5/9/17 grid sequence, and emit candidate-, scenario-, provider-,
protocol-, plan-, assembly-, and result-bound evidence. The study derives its
exact values from the declared G2 boundary root and derives physical spacing
from `L * J_hat`; callers cannot supply error or observed-order values.

`FieldResidualScopedSearch.jl` may resolve only the exact local
`structured_field_residual_solve` work item. Provider availability and a
successful numerical result are separate facts. The candidate remains
deferred while any compiled G1/G2, whole-device, engineering, VVUQ, or
validation obligation remains.

Stop Batch A when all of the following hold:

1. one real candidate runs G2 producer -> G1 residual -> sparse assembly -> LU
   solve -> RuntimeEvidence on all three grids;
2. the observed orders are finite and consistent with the declared
   second-order manufactured control;
3. a foreign provider, wrong candidate/scenario/root/edge, missing payload,
   numerical failure, or forged evidence cannot create a scoped resolution;
4. an unrelated archive gap and every broad compiled obligation remain intact;
5. the CLI reports zero credible physical candidates and `p5_ready=false`.

After the correctness path is frozen, profile compile time, solve time,
allocations, and peak memory on 5/9/17 and at least one larger admitted grid.
The current tuple-backed field and CSC payloads may specialize on payload
length. A later representation may use a stable element type plus a dedicated
immutable receipt and deterministic content hash, but it must preserve the
same numerical values, ordering, row ownership, and evidence bindings. This
performance work does not block Batch A correctness and cannot change its
claim ceiling.

### Batch B: add an independent Gridap weak-form adapter

Add a separate, optional Gridap adapter after Batch A is frozen. Pin the exact
Gridap dependency and record Julia, Gridap, linear-solver, platform, adapter
source, and dependency-lock identities. Absence or qualification failure of
Gridap produces a capability gap; it never falls back under the Gridap provider
identity.

The adapter consumes the same candidate-bound `LinearFieldResidualFormV4`, G2
producer results, `DiagonalAffineChartGeometryV4`, scenario, and boundary data.
It must translate the audited operator manifests to a weak form. It must not
call the native finite-difference assembler. A typed polynomial derivative for
the already supported AST subset may provide the exact gradient needed for an
H1 manufactured-error calculation; unsupported AST nodes remain deferred.

The first Gridap control uses the same declared quartic subject, a three-level
mesh family, and integration degree at least eight. It records L2 and H1 errors
and observed orders. Native finite-difference Linf error, Gridap L2 error, and
Gridap H1 error stay separate; they are never merged into one convergence
sequence.

Stop Batch B when the Gridap adapter has its own literal manifest, source-bound
provider, assembly receipt, result, and replay test; its numerical results are
consistent with its declared discretization order; and all high-fidelity,
physical-validation, and whole-device gates remain closed. Different solvers
inside one Gridap assembly do not count as independent code.

### Batch C: numerical V&V across two discretizations

Build a `FieldNumericalComparisonV4` from the frozen native and Gridap reports.
It binds the same candidate, constraint, geometry, source/boundary roots,
scenario, and physical domain, while retaining each code's mesh, norm,
quadrature, solver tolerance, residual, and uncertainty record.

The comparison may establish:

- manufactured-solution consistency;
- expected refinement behavior for each discretization;
- code-to-code agreement at explicitly transferred sample points;
- solver and discretization sensitivity within declared bounds.

It cannot establish a correct fusion model. Failure is a numerical V&V gap and
does not permanently prune the candidate unless a replayable no-solution
certificate exists for the same grammar, bounds, mission, and evidence scope.

Stop Batch C when both providers replay independently, transfer/interpolation
error is reported separately, and the comparison emits a numerical-V&V receipt
without changing the physical evidence ceiling.

### Batch D: extend only from typed physical declarations

The next executable physics slice must start from declared G1/G2 types for its
unknowns, constitutive parameters, sources, interfaces, boundary conditions,
and observables. `GRAD`, `DIV_OP`, `CURL`, `LAPLACE`, and `DT` identifiers alone
do not supply these semantics. No implementation may select a law or region by
role text, family label, or fallback position.

Static coupled fields can proceed when every block row, interface transfer,
material coefficient, and boundary term has an exact typed producer and unit
closure. Time evolution additionally requires a declared clock, mass/DAE form,
initial state, event semantics, and tolerance protocol. Missing declarations
remain explicit compilation obligations.

Stop that candidate's promotion in Batch D at the first missing typed producer
or unit/interface contract, and place the exact missing capability in the
development/deferred-work queue. Continue other candidates and other declared
chains. Do not insert a zero source, identity interface, default material, or
guessed boundary condition to keep one candidate moving.

Legacy runtimes are algorithm references only. A backend wrapper that returns
`unsupported`, or a fixed-state affine flux/Jacobian driven by caller-supplied
reference values, is not a qualified equilibrium or transport provider for
this path.

### Batch E: physical-model validation and uncertainty

Physical validation begins only with data whose subject, observable, operating
condition, calibration/validation split, measurement uncertainty, provenance,
license, and applicability domain are recorded. Public component tests and
physical-model benchmarks may be mapped to a new candidate when its typed
materials, geometry, boundary conditions, and operating regime lie within that
domain. A new device is not required to have device-specific measurements
before it can use such scoped evidence. Outside the proven applicability
domain the result remains `unknown`; component or model evidence does not
become whole-device experimental validation. Public data and open catalogs may
be researched and adapted autonomously. User input is required only for
undeclared mission choices, private/proprietary properties, credentials,
license acceptance, or exclusive compute resources.

Geometry, CAD, meshes, materials, and actuator combinations may be generated
as typed design alternatives from the three Genomes and qualified public
catalogs. They are not assumed to be user-supplied. Their unprovided private or
mission-specific attributes must not be guessed.

Parameter uncertainty requires typed distributions, correlations, admissible
bounds, and observable mappings. Until those exist, deterministic parameter
sweeps remain sensitivity screens and cannot be labeled UQ. Calibration data
cannot also serve as independent validation data without an explicit protocol.

Stop only that candidate's promotion at the relevant evidence layer unless at
least one applicable validation dataset and its measurement uncertainty pass
the declared admission checks. Queue missing adapters, datasets, or uncertainty
models as capability work and continue other declared candidates and chains.
Manufactured controls and code-to-code agreement contribute zero
experimental-validation credit.

### Batch F: whole-device integration and closure audit

Whole-device admission checks that the required scenarios, providers,
protocols, typed geometry/material/network/resource/actuator/control
producers, and hard gates are ready. Admission does not require results that
can only be produced after the integrated run.

After execution, the closure audit separately requires integrated numerical
results, numerical V&V, model-validation evidence, engineering/resource
evidence, uncertainty results, and any independent-code or experimental
evidence demanded by the frozen stage manifest. Empty requirement sets do not
pass. A `screen_only` result cannot close a high-fidelity or validation stage.

Stop only the affected candidate's stage promotion in Batch F, with an explicit
gap matrix whenever a required typed producer, qualified provider, scenario,
dataset, engineering model, or validation result is unavailable. Feed
implementable gaps back to the capability-development queue and continue other
admissible candidates. `p5_ready` remains false until the post-run closure
evidence is actually present and candidate-bound.

## Acceptance matrix

| Batch | Executable positive control | Mandatory negative control | Highest possible result |
|---|---|---|---|
| A native field | Frozen quartic G2 roots, exact G1 row, 5/9/17 native solves | wrong binding/provider/evidence, failed solve, unrelated gap retained | `screen_only` scoped resolution |
| B Gridap field | Same subject through an independent weak-form assembly | unavailable/unpinned backend, unsupported AST, shared-assembler masquerade | `screen_only` independent numerical result |
| C numerical V&V | replayed native/FE refinement and explicit field transfer | mixed candidate/domain/norm, non-independent code, nonconvergent sequence | numerical-V&V receipt |
| D coupled physics | fully typed block/interface/source/boundary system | missing unit/law/interface/clock, label routing, inserted defaults | declared model execution only |
| E validation/UQ | candidate-bound held-out data and typed uncertainty model | calibration reuse, missing uncertainty/provenance, manufactured-as-data | model-validation/UQ evidence at its declared ceiling |
| F whole device | admitted scenarios followed by integrated closure audit | empty manifest, missing prerequisite, screen evidence at a higher gate | stage result only when every required evidence class closes |

The first three batches are implementable with public software and the existing
bounded subject. Later batches become executable incrementally as typed
physical producers, public or project-specific validation data, and qualified
engineering resources become available. Until then, their gaps are real output
of the campaign rather than placeholders to suppress.
