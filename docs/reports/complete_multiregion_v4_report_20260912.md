# Complete declared multi-region residual execution report, 2026-09-12

This report covers the four-state reduced static-MHD branch. The declared
model has two candidate-owned regions, 24 regional affine vector-test equations
and 12 shared-interface traction-jump moment equations. Complete means every
term and state of that declared reduced model; unrestricted MHD field-space
closure remains unimplemented.

## Implementation and software checks

The production implementation and exact DESC surface/volume sampler are present
in `src/RuntimeV4/CompleteMultiRegionV4.jl` and
`scripts/complete_multiregion_desc_sample.py`. The final focused command was
`julia --project=. test/runtime_v4_complete_multiregion_tests.jl`.

The integrating queue recorded **30/30 focused assertions passed, process exit
0**, in `runs/revised_chain_20260912_audit/physics_focused_final.log` and
`physics_focused_final.exit`. These test nonlinear updates of all four states,
inconsistent-equation failure, all Jacobian columns, weak stress signs,
interface orientation, and rejection of forged normalization/initial state/
engineering validity. The manufactured controls provide software verification
only. Python syntax compilation also exited 0. No focused test result certifies
the candidate or the physical chain.

The branch implementation was frozen for production at SHA256
`72115623040139b567e991f2d124dfdb16e4c3f454919bef3d87d9349bc007ef`;
the Python sampler SHA256 is
`65b0cea24fa6b66338c3a2f31792e5f1cf9e6799f91408f9cf41429892aeec10`.
The main agent owns the heavy Julia/DESC execution queue. The first unified run
stopped during candidate-graph construction (exit 1), before a revised candidate
or physics calculation was executed; that failure is not a physics result.

## Actual candidate execution: failed solve

The main queue executed `runs/revised_chain_20260912_r2` using candidate
`7b44ba518eb7e7fdede814c1fccb94bd540f41c8b5e4fd3130e6971465c35548`
and context
`de87eb7f96b38dda09e4643fcbce20db17d21b3f2207a416f755768b096fd14d`.
The physical result identity, also bound by the executed engineering output, is
`9945af6c28b4875103e3894eb61a7b21d36255b24c755f93d2b4940f66c4f241`.
DESC and its output inspector exited 0; the exact-surface/volume sampler exited
0. A fresh candidate-bound HDF5 was consumed. **The multi-region nonlinear
solver actually executed and failed with exit 3, `bounded_line_search_failed`.**
Its failure is retained; no parameter, state bound, residual weighting or source
was altered to obtain a passing result.

There are 17,920 actual Cartesian samples: 15,360 volume samples and 1,280
samples on each exact interface/exterior surface. This is six Gauss-Legendre
radial nodes in each region, 16 by 16 angular nodes per sector and all five
field periods rotated. The zero body source, all regional volume terms,
arithmetic shared-interface traction, exterior prescribed traction and
independent interface-jump moments were assembled into 36 residual rows and
all four state-Jacobian columns. Axis zero measure and angular periodicity are
declared conditions rather than missing terms.

Six iteration records include the initial state and five accepted updates:

| Quantity | Initial | Final |
|---|---:|---:|
| `[a_core,c_core,a_edge,c_edge]` | `[1,1,1,1]` | `[0.5,0.5,0.5944771568624893,0.5]` |
| Raw weak residual 2-norm, N | 87,985.5348743 | 18,489,788.2281 |
| Scaled weak residual 2-norm | 1.77223837459 | 1.02080259616 |
| Scaled maximum residual | 1 | 0.642642812348 |
| Scaled normal-equation gradient norm | 3.17207766550 | 0.751006362034 |

**The raw force-residual norm worsened by 210.146 times.** The decrease of the
weighted objective is not an improvement of the unweighted physical residual.
The final scaled maximum also exceeds the declared 1e-6 tolerance by more than
five orders of magnitude.

## Why this iteration stopped

This postprocessing reads the actual `physics.json` coefficient rows and state;
it neither launches Julia/DESC nor substitutes another solution. The fixed
row-scale rule is `s_i=max(sum_j(abs(C_ij))+abs(d_mi)+abs(d_pi),1 N)`. Scales
range from 1 N to 55,977,606.2351 N. The line search minimizes `norm(R ./ s)`;
therefore very different absolute forces can receive comparable objective
weight. The decisive examples are:

| Row | Initial residual, N | Final residual, N | Scale, N | Final scaled residual |
|---|---:|---:|---:|---:|
| edge `x e_x/L` | 59,550.3203 | 38,269.5853 | 59,550.3203 | 0.6426428123 |
| edge `z e_z/L` | -19,890.2622 | -18,472,003.4031 | 55,977,606.2351 | -0.3299891625 |
| interface jump `z e_z/L` | 0 | 723,637.0711 | 14,000,806.7540 | 0.0516853838 |

The pressure and core-field multipliers reach their declared lower bound 0.5.
At the final state the unconstrained regularized Gauss-Newton step is
approximately `[-0.204629,-3.939877,4.64e-16,-7.454936]`. Clipping this step to
the declared box leaves essentially the same state; all 21 tested step lengths
fail strict objective decrease.

This is **not proof that the best bounded state was found**. The gradient of
half the squared scaled norm is approximately
`[0.193579,-0.036985,0.713738,0.125490]`. The free edge-field coefficient has a
nonzero gradient, and increasing the lower-bound core-pressure coefficient is
a feasible descent direction. Read-only single-coordinate diagnostic probes
confirm that `c_core += 0.001` gives scaled norm 1.02076638460, and
`a_edge -= 0.001` gives 1.02010492125, both below the recorded final norm.
These probes were not accepted as physical outputs or engineering inputs.
They identify failure of the clipped unconstrained-step method under active
bounds, in addition to the limited model basis.

An independent NumPy SVD of the same fixed weighted coefficient system has rank
4, singular values approximately `[1.399628,0.969425,0.158898,0.082946]`, and an
unconstrained transformed residual floor of 0.4611093161. The transformed
minimizer `[a_core^2,c_core,a_edge^2,c_edge]` is approximately
`[0.0453713,-3.4398772,0.3534031,-6.9549356]`, outside the declared bounds and
requiring negative pressure multipliers. The nonzero floor diagnoses
incompatibility of this reduced moment system **at the current quadrature**;
it does not separate quadrature error from field-space/model error, and it is
not a physical equilibrium solution.

## Physical diagnostics and engineering handoff

| Actual final diagnostic | Core | Edge |
|---|---:|---:|
| Region volume, m^3 | 4.37645536647 | 13.12975543996 |
| Local strong-force RMS, N m^-3 | 8,838.037755 | 16,737.689448 |
| Local strong-force peak, N m^-3 | 32,735.816440 | 46,050.160312 |
| Relative local strong-force peak | 1 | 1 |

The exact-interface traction-jump peak is **297,184.0216 Pa**, relative 0.171317;
the exact-exterior actual-versus-prescribed traction mismatch peaks at
**1,995,864.8848 Pa**, relative 0.477756. These are plasma stress diagnostics,
not material component stresses. The interface normal-B jump is
3.14672e-17 T and the reference surface normal-B peak 4.44089e-16 T; their small
values check the flux-surface normal condition but do not repair force balance.

The integrated Cartesian strong-force and divergence-theorem defects are near
roundoff (global defect components approximately
`[-1.09623e-10,-1.48726e-10,-4.71599e-10] N`). These toroidal vector integrals
cancel despite large local force, affine-test and traction defects. The ledger
therefore preserves `conservation_certified=false`; opposite numerical
interface terms also cancel by construction and are not a completeness proof.

Engineering consumed `final_boundary_field.json`, whose real exact exterior
fields include the actually attained `a_edge=0.5944771568624893` multiplier.
Its binding explicitly reports `upstream_valid=false`, `upstream_status=fail`
and `reduced_model_diagnostic_valid=false`. No candidate receipt from the parent
revision was attached to this output.

## Remaining blockers by kind

- **Candidate declarations:** the two regions, shared/exterior/axis conditions,
  four states, zero source, test space, bounds and the chosen engineering input
  mapping are present for this declared reduced model. No empty declaration
  prevented this calculation.
- **Model/basis and boundary limitations:** four regional multipliers cannot
  modify spatial field shape or geometry; the fixed reference exterior traction
  is not solved together with an exterior vacuum/current/material system. The
  affine test space does not establish function-space closure. Transport,
  energy evolution and unrestricted MHD remain unimplemented.
- **Numerical/computation failure:** the actual bounded line search stopped
  without convergence or constrained stationarity. Its row weighting permitted
  a 210-fold worsening of the raw residual. Future solver/scaling changes must
  be reviewed as new computational work, not retroactively applied to this
  result. Independent integration/discretization error bounds are not supplied
  by the small global vector integral or by the coefficient SVD.
- **Data/validation:** the saved DESC provider receipt lacks optimizer
  convergence attestation. There is no applicable experimental validation set,
  independent physical equilibrium solution or model-discrepancy calibration;
  those physical validation gates remain unsupported.

## Reproduction and artifact identities

The production entry point is
`julia --startup-file=no --project=. scripts/run_v4_revised_chain.jl <new-run-dir>`.
The real sampler command and Julia/BLAS/Python/DESC environment identities are
stored in `runs/revised_chain_20260912_r2/physics.json`; raw request and module
path arguments are preserved in `physics/sample_request.tsv` and its execution
record. The run used Julia 1.10.5, Python 3.13.5, DESC 0.17.3, NumPy 2.4.2 and
JAX/JAXlib 0.9.2. A validated resume must reuse this revised-candidate checkpoint
rather than launch a duplicate upstream solve.

| Artifact | SHA256 |
|---|---|
| fresh `desc/candidate_bound.h5` | `ed68641512138db071e465567140e83a78821fad88544a500d6446a8e0ceaeb4` |
| `physics/raw_samples.tsv` | `63316cde9bad0d45902ca275383b4e496ddda265f9c480c8bc40f3d34d7b2f8f` |
| `physics/coefficients.tsv` | `9aca8693bfc8ad01d64b3ec3860766d40a312b2ec14dbd22582b58d19c425fdb` |
| `physics/iterations.tsv` | `fb93ea08c02ada895265eadfe9500e4e7cfe8c9c62cf3c5a048549070fe44efb` |
| `physics/final_boundary_field.json` | `3cdf0489e892b18dcd7bbb39eede3941266f4814f837d8be1fec7bd822d84563` |
| `physics.json` | `0d26818beb9c878bb22454f76577075eab761cdcea68aec7029d68e8b2a59e4c` |

`physics/sampler.exitcode` contains 0; `physics/solver.exitcode` contains 3.
All equation/source files retain the frozen hashes reported above. This report
postprocessing used Python/NumPy only and exited 0; it did not restart the
physical solver.

## Limits retained independently of solver outcome

Even if the reduced weak equations solve, the limited ansatz/test-space
adequacy remains unsupported. Pointwise force, interface traction jump,
exterior traction mismatch and normal magnetic-field jump are retained to
expose moment cancellation. Global numerical-interface cancellation alone
cannot certify conservation. The existing DESC provider receipt confirms
execution/schema inspection but does not preserve optimizer convergence
attestation, so engineering receives that upstream limitation.

No experimental dataset, independent physical equilibrium solution or model
discrepancy calibration enters this branch. Physical validation remains
unsupported. The q pressure scenarios are exploratory deterministic
constitutive sensitivity at fixed DESC geometry and B; they are not profile
uncertainty propagated through a fresh equilibrium solve.

The legacy reuse decisions, full residual convention, units, source provenance,
exact surface treatment and reproduction interface are documented in
`docs/implementation/complete_multiregion_v4.md`.
