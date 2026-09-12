# Executed four-state multi-region static-MHD model

## Scope and equations

This branch implements the complete residual of a **declared four-coefficient
reduced ansatz**. It does not implement a complete unrestricted MHD field solver.
G2 owns core `0 <= rho <= 0.5`, edge `0.5 <= rho <= 1`, the exact shared face,
the exterior face, state ownership, zero volumetric body force and test space.
For region i, `B_i = a_i B_DESC`, `J_i = a_i J_DESC`, `p_i = c_i q p_DESC`.
The four solved states are `[a_core,c_core,a_edge,c_edge]`; q is a separately
declared deterministic sensitivity input, nominal 1 and range [0.9,1.1].

The Cauchy stress convention is `T = BB'/mu0 - (p + B.B/(2mu0)) I`, hence
`div(T)=J cross B - grad(p)`. Each region has twelve dimensionless Cartesian
vector tests `e_k * (1,x/L,y/L,z/L)` with L = 1 m. All volume, explicit zero
source, interface and exterior terms are evaluated. At the internal face the
numerical flux is the arithmetic mean of the two stresses; twelve additional
traction-jump moments couple their traces. The fixed exterior prescribes the
traction of the freshly executed reference DESC field, including q-scaled
pressure. Axis regularity contributes zero surface measure; both angles are
periodic. The magnetic flux representation is solenoidal inside each region
under constant scaling. Normal-field jumps at the shared face and reference
normal field on exact surfaces are measured explicitly. Pointwise force and
traction jump diagnostics prevent symmetry cancellation from becoming a
physical-equilibrium claim.

The 36 by 4 full-state Jacobian is analytic for this state space. The assembled
residual is `R=C*[a1^2,q*c1,a2^2,q*c2]+d_m+q*d_p`. Damped bounded Gauss-Newton
records initial/final states and each accepted iteration. Exit 0 is a reduced
weak residual solution, 2 stationary nonzero residual, 3 failed bounded line
search, and 4 the iteration limit. The nonlinear update is actually attempted;
no synthetic trajectory is used for production. Limited test/ansatz sufficiency
and physical validation remain unsupported even if the moment solver exits 0.

The fixed nominal `mu0=1.25663706127e-6 N A^-2` was checked against the
[NIST 2022 CODATA table](https://physics.nist.gov/cuu/pdf/all.pdf). Its published
measurement uncertainty is not propagated by this model; a zero-width declared
computational interval denotes holding that nominal constant, not asserting
that permeability is experimentally exact.

## Raw integration and downstream binding

`scripts/complete_multiregion_desc_sample.py` consumes the actual new-candidate
DESC HDF5 receipt, validates its bytes and module path, and samples six-point
Gauss-Legendre radial quadrature in each region with 16 by 16 periodic angular
nodes per field period. All periods are rotated into Cartesian laboratory
coordinates; Cartesian vectors are never multiplied by NFP without rotation.
The exact rho=0.5/1 surfaces use oriented `e_theta cross e_zeta` for their measure
and normal. No finite offsets represent these traces.

Raw TSV columns are `kind region rho theta zeta x y z Bx By Bz p Jx Jy Jz
gradpx gradpy gradpz nx ny nz measure`. Volume measure is m^3; face measure m^2.
Field, current density, pressure and force density are SI. Each surface output
uses the actual final edge magnetic multiplier. Engineering receives the full
exact exterior sample array and concrete JSON path/hash. Plasma pressure is
explicitly not material stress. Upstream validity remains false because the
provider receipt attests execution but not equilibrium convergence; engineering
must propagate that limit.

The global ledger separately records integrated strong force, actual and
prescribed exterior traction, interface stress jump, zero body source and
regional/global divergence-theorem defects. Opposite numerical flux cancellation
alone never certifies conservation. The strong/weak discrepancy is retained for
the independent verification branch; it is not renamed quadrature error.

Production replay validates the G2 declaration in the actual context, all raw
artifact bytes, regenerated coefficient rows, nonlinear iterations, diagnostics
and final boundary samples. Tests use manufactured algebraic controls only and
carry no candidate physical credit. Heavy provider execution is owned by the
integrating agent's unified queue.

The revised declaration validator also rebuilds all owned G1/G2/G3 typed graphs
before this implementation is admitted. Replay checks normalization, row
ownership and initial state against raw assembly/declarations before solving;
re-sealed caller changes to those quantities are rejected. Engineering's field
scale, origin, upstream status and diagnostic-validity fields are recomputed,
including exact pointwise exterior-traction mismatch, rather than trusted from
the serialized result.

## Legacy reuse review before implementation

Reviewed `../outputs/fusion_concept_ai/src/candidate_residual_graph_runtime_v68.jl`
(state/residual contracts and solve entry point) and
`../outputs/fusion_concept_ai/src/candidate_solver_runtime_v5.jl:228` (Laplacian
steady-state solve). Decisions:

| Material | Decision | Reason |
|---|---|---|
| v68 explicit state/region ownership and residual history concept | extract | Retained the numerical-contract idea; rebuilt current typed declarations and actual artifact binding. No legacy type, authority or family routing imported. |
| v68 Newton-Krylov/homotopy runtime | reject | Current four-variable residual permits direct analytic Jacobian and small Gauss-Newton solve; legacy manifests and model authority would be unrelated inputs. |
| v5 graph-Laplacian state transition | reject | It solves a linear transport graph and cannot establish current MHD stress balance. |
| Current `CandidateCoupledPhysicsV4` Cartesian stress and rotation idea | extract | Re-derived current sign convention, exact face terms and candidate-owned full state map; sampled pressure/B Jacobian is not reused as the full Jacobian. |
| Synthetic known-root controls | test-only | Check Newton updates and contradictory-equation failure, never used as production upstream data. |

No legacy module is wrapped into a physical provider. No default registry changes
or historical result receipts are imported.

## Reproduction and status

Focused command: `julia --project=. test/runtime_v4_complete_multiregion_tests.jl`.
Production is through the integrating revised-candidate runner calling
`execute_multiregion_v4(context, upstream, run_dir)`. The emitted request fixes
candidate/context/declaration/HDF5 identities and quadrature. `sampler.exitcode`
and `solver.exitcode` are distinct. `iterations.tsv`, `coefficients.tsv`,
`raw_samples.tsv`, `sample_metadata.tsv`, `final_boundary_field.json` and result
semantic output provide reproducible raw evidence. The execution record hashes
source, sampler, Python/DESC environment, HDF5, requests and emitted data.

Production execution is recorded in
`docs/reports/complete_multiregion_v4_report_20260912.md`: the fresh DESC/sampler
steps exited 0, and the actual reduced multi-region solver exited 3 after five
accepted updates. Its scaled norm decreased while its raw residual worsened
210-fold. The report retains the clipped-step failure and boundary/local-force
defects; no tuning changed that failed result. Final focused software checks
passed 30/30 with process exit 0 and confer no physical-solve credit.
