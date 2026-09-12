# W04 current spatial-model closure audit

Status: read-only main-line audit begun at `c9ee99035bc04908bfc0df1e3b60d8c86033bcfb`, with a post-repair execution checkpoint at `f643059f68584c3630788fbd6c4ef1a9bda050ac`. This is not a revised physical model, a convergence result, or R03-R05 acceptance.

## Executed subject and observed failure

The audited subject is candidate `3de9cf49553e4f2ceaa0aa93330388f8b5c740f1706df9352a71229fe459502e`, context `0f7521a157ca710b195f82757a8d204058d99231b12346f9c8f37d9be526b10d`, in `runs/spatial_chain_20260912_r1`. The saved manifest recheck in this live run checked 549 records and 548 unique paths with zero mismatches and process exit 0. The historical stagnation recheck also exited 0. Neither check is physical validation.

All four physics cases remain scientific fail, solver exit 4. Nominal coarse has 360 unknowns, 2881 residual rows, numerical rank estimate 360, final scaled L2 norm `0.16145739547560198`, and final scaled max `0.012938963872709097`, against a fixed `1e-6` maximum-residual gate. The last four accepted updates leave the objective and projected gradient bitwise unchanged and only reduce node 1 pressure from approximately `7.1e-15` to `1.1e-78 Pa`. This is a numerical floating-point stagnation mechanism, not evidence of a solution or of physical impossibility.

## Post-repair execution checkpoint

The fresh non-resumed run `runs/goal_recovery_20260913_012528_cst/spatial_chain_after_stagnation_fix_r2` completed the runner with process exit 0 at candidate hash `3de9cf49553e4f2ceaa0aa93330388f8b5c740f1706df9352a71229fe459502e`. DESC exited 0; physics exited 4; engineering and verification each exited 0; the whole-device authority remained `deferred`, physical validation remained `unsupported`, and credible device count remained zero. Same-revision integration checks passed 43/43. These are execution and evidence-integrity results, not physical acceptance.

The old floating-point stagnation signature was not reproduced. All 40 accepted production updates across the four cases were classified `accepted_strict_decrease`. Nominal coarse reduced objective from `0.028486194675476546` before the first update to `0.018498967933640423` after the twelfth; its scaled residual norm decreased from `0.16877853736620838` to `0.13601091108304672`, while scaled residual max ended at `0.011177692496069813`, still more than four orders of magnitude above the `1e-6` gate. Nominal fine ended at scaled max `0.006263157331206082`; flux-low coarse at `0.010415454251006056`; flux-high coarse at `0.009993763053750175`. Each case stopped at its configured iteration limit, so the repair establishes representable optimizer progress but not convergence.

The independent derivative checks passed for every case (360 columns for each coarse case and 2640 for nominal fine, 32 colors each). Engineering execution and transfer/circuit substeps returned zero but remained unqualified because the physics state failed. The manifest-bound independent audit checked 554 records and 553 unique paths with zero byte mismatches; its overall exit was 1 only because that historical-recovery-specific auditor requires a prior `whole/program_exception`, while this clean run has none. No acceptance requirement is upgraded by that field-level audit.

## Unknown, equation, source, boundary, and interface ownership

| Item | Current production ownership | Closure assessment |
|---|---|---|
| Spatial unknowns | Continuous nodal cylindrical `B_R`, `B_phi`, `B_Z`, and nonnegative `p`; 4 values per merged Q1 node | Explicit for this narrow static state, but it does not include flow, density, species temperatures, composition, electric field, circuit state, material temperature/stress, or control state. |
| Geometry | Fixed fresh DESC geometry and metric samples | Geometry is not updated by solved pressure/current and therefore cannot establish a self-consistent free-boundary or deformable-device state. |
| Momentum | Per-cell broken test rows for `div(T)=0`, with `T=(BB-B^2 I/2)/mu0-pI` | The weak residual is executable. It does not choose the pressure/current free functions or field topology that select an equilibrium. |
| Magnetic solenoidality | Per-cell broken test rows for `div(B)=0` | Executable, but not an exact divergence-free representation and not by itself a topology/current closure. |
| Body source | Fixed zero vector, described as an exploratory numerical assumption | It is not a measured or candidate-derived source and cannot close missing transport, flow, or actuator physics. |
| Interior faces | Shared nodal `B,p`; one-sided left trace supplies equal-and-opposite numerical flux; declared interface is same material with no sheet current | Appropriate only for the declared continuous same-material slice. It is not a heterogeneous plasma/vacuum/material interface or a boundary-limit validation. |
| Exterior weak load | Reference DESC traction and prescribed `B.n=0` | The traction is computed from reference `B,p`, while normal field is independently forced to zero. Compatibility has not been demonstrated. |
| Exterior face rows | Additional moments enforce trial traction against the reference traction and trial normal field against zero | These are extra least-squares boundary residuals in addition to inserting the prescribed load in the cell weak rows. Their independence, weighting, and compatibility must be demonstrated; full column rank does not do so. |
| Integral constraint | One toroidal-flux cut | No candidate-owned pressure profile, iota/current profile, poloidal flux, helicity, or equivalent topology-selection constraint is present. |
| Currents and exterior field | Plasma `J=curl(B)/mu0` and an internal trace-derived `K`; exterior `B_out`, `K_outer`, coils, and return path remain unknown | The pickup computation consumes real J/K values but cannot close the electromagnetic implementation or force balance. |

The discrete system is overdetermined by construction (2881 by 360 on nominal coarse; 21761 by 2640 on nominal fine). A full numerical column-rank estimate only says there is no detected local column null direction at the declared scaling and threshold. It does not show that the overdetermined boundary/volume equations are mutually consistent, that the continuum equilibrium is unique, or that the chosen least-squares weights represent a physical variational problem.

## Concrete compatibility questions that must be answered before physical credit

1. Recompute, on the exact exterior quadrature, the reference `B.n`, reference tangential traction, and the residual implied by simultaneously requesting reference traction and `B.n=0`. If these boundary data are inconsistent beyond preregistered projection error, classify the declaration as a model/input incompatibility rather than tuning the nonlinear solver.
2. Separate the cell natural-boundary contribution from the added exterior face-moment equations and run rank/consistency tests on each block. Document whether the latter are a penalty/least-squares stabilization, an essential constraint, or an unintended duplicate enforcement, including their continuum target and scaling.
3. Add candidate-owned equilibrium selectors. For the current fixed-boundary nested-flux-surface scope, the minimum physically meaningful declaration must own a pressure profile and exactly one compatible rotational-transform or toroidal-current profile, plus the toroidal flux and boundary geometry. These inputs must come from G1/G2/mission fields with units, sources, bounds, and hashes, not from a reference name or hidden initializer.
4. State how the custom spatial variables enforce or diagnose flux-surface tangency and topology. If arbitrary nodal `B` remains allowed, add explicit candidate-bound topology obligations and do not interpret one flux integral as equivalent to an iota/current-profile closure.
5. Couple the plasma boundary to an exterior vacuum/coil/current-return solve, or retain a strict screen-only ceiling with `outer_Bout`, `outer_K`, and external current closure unresolved. A fixed reference traction cannot substitute for the actual G3 coil realization.
6. Keep pressure/current-equilibrium feedback inside the solve or a partitioned iteration with preregistered interface/state/conservation tolerances. One-way DESC initialization followed by a changed `B,p` state is not closure.

## Frozen next minimum problems

### N1: solver-verification problem, manufactured and non-physical

Use the production residual/Jacobian and bound-constrained solve on an analytic nonzero-source `B,p` field with independently derived source, exterior traction, normal field, and flux. Start from at least three materially different perturbations. Recover the manufactured state on at least three preregistered resolutions and report solution error and observed order, not only residual substitution. This isolates solver, active-set, derivative, and discretization defects. It grants numerical verification only.

### N2: fixed-boundary physical reference problem

Compile a label-neutral candidate declaration containing boundary geometry, toroidal flux, a sourced pressure profile, and one sourced iota/current profile. Execute an applicable equilibrium provider to produce the state, then independently map the same declared physical subject into the custom spatial residual. Predeclare observables and tolerances before examining the comparison. The current DESC result can be a code-to-code reference only within its design/simulation scope; it is not experimental validation.

### N3: exterior electromagnetic closure

Given an accepted N2 state, add candidate-owned G3 coil geometry/currents and an exterior vacuum-field/current-return provider. Iterate plasma boundary and coil/vacuum states until `B.n`, traction/current-sheet interfaces, circuit state, and conserved-current errors meet preregistered tolerances. Only then may pickup/control calculations be assessed as part of a closed electromagnetic implementation.

N1 may follow the W01 numerical repair. N2 requires the W03 source registry and a new versioned equilibrium-selector declaration. N3 depends on N2 and real G3 data. Transport/burning/thermal/structural/power-cycle feedback remains outside N1-N3 and therefore R04/R05 remain unpassed even if all three succeed.

## N1 manufactured-recovery execution result

The preregistered refined family at commit `2bf50fd64156de71bc6e2c514e5e0d724a5f7b34` completed with process exit 0. All three perturbations converged on all three resolutions (`h=1/3`, `1/4`, and `1/5`) within the fixed 48-update budget, and every accepted update was a strict representable objective decrease. Perturbation 3 required 13, 21, and 32 accepted updates respectively, confirming that its earlier 12-update failures were budget-limited rather than divergent.

This passes the narrow recovery-robustness portion of N1, but it does not pass a grid-consistency or observed-order claim. For perturbation 1, the relative solution error decreased from `6.20345e-4` at `h=1/3` to `6.94560e-5` at `h=1/4`, then increased to `2.74459e-4` at `h=1/5`; the latter pair therefore has observed order `-6.15795`. The other large positive pairwise values are also not promoted as credible asymptotic orders without a demonstrated common refinement regime. Residual convergence alone can select different nearby least-squares states in this manufactured problem.

The result remains numerical-only, has evidence authority `none`, and declares physical validation `unsupported`. It does not close the candidate-owned pressure/current selector, exterior field/current-return system, or the real four-case physics failure. R03 therefore remains unaccepted, and the next ordered minimum problem is N2 rather than further solver iteration tuning.

## N2 sourced-input checkpoint

The official DESC `v0.17.3` release artifact `HELIOTRON_output.h5` was downloaded from tag commit `fcc29be36f0b36b1b667df4b1f8891a9b633f5d1`. Its SHA-256 `305cbba9c82c32dff7cb4954367c20f0428f6ff216f5d1f53c3038870ca06dfe` and 467439-byte length match the copy installed with the pinned `desc-opt 0.17.3` environment. This supplies the first currently available source-complete external-simulation input for N2: `NFP=19`, toroidal flux `1 Wb`, pressure `18000(1-rho^2)^2 Pa`, iota `1+1.5 rho^2`, and four radial plus three vertical boundary modes above the preregistered `1e-12 m` zero threshold.

The executed normalizer produced label-neutral subject hash `07fc47f9a10537c9cc2c07db5a426b2566a5a87c1bdaa3a5ae99f3515dd889bb`. The largest discarded boundary coefficient is `1.94018e-16 m`. Registry tests pass 7/7, normalizer contract tests pass 6/6, and an independent output-validation invocation exits 0.

This checkpoint establishes source acquisition and deterministic representation only. The artifact is a DESC-produced external simulation, not a measurement or independent solver. It has no inverse parameter, calibration/held-out split, measurement uncertainty, or physical-validation authority. The normalized subject must next be bound into the typed G2 declaration and freshly reexecuted through the production DESC provider; the same subject must then be mapped independently into the spatial residual before a code-to-code comparison can be evaluated. R01 and R02 remain unaccepted.

## Current classification and next work order boundaries

- Numerical defect: confirmed floating-point stagnation; W01 owns the narrow algorithm correction.
- Model/declaration gaps: pressure/current topology selection and possible exterior boundary incompatibility; these are not solver-tolerance changes.
- Data gaps: sourced reference profiles, calibration/held-out measurements, coils/material/engineering inputs.
- External-resource gaps: independent validation data/provider and later experimental/engineering evidence.

The next main-line implementation work order after W01 is accepted should add an isolated N1 solution-recovery benchmark first. In parallel, use W03 results to freeze the N2 physical subject. No new high-level evidence path or whole-device authority should be enabled by this audit.
