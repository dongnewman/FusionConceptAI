# Magnetic engineering execution report, 2026-09-12

The branch implements a candidate-owned magnetic pickup/readout circuit,
integrator and short-circuit protection model. The production entry point
requires actual same-revision multi-region physics and byte-bound DESC artifacts.
It cannot accept a caller-supplied test field as production engineering evidence.

## Actual execution evidence

Latest acceptance is `runs/revised_chain_20260912_r3`: engineering was executed
again after the exact declared-scenario validation repair. The focused suite
passed **44/44, exit 0**, confirmed in
`runs/revised_chain_20260912_audit/final_regressions/engineering.log` and its
`.exit` file. The five additional checks reject duplicated, reordered, missing
or extra fault scenarios. The r3 unified runner also completed **28/28
integration checks, process exit 0**; physical solver exit remains 3 and
verification exit remains 1, as recorded in `unified_r3.log` and
`unified_r3.exit`.

A read-only comparison of r2/r3 engineering JSON confirms identical candidate,
context, input B and both scenarios' complete metrics. Both circuit CSV hashes
are unchanged. The current executed source SHA-256 is
`a259d3b36d6fe7bb1fa3ad91eae5d800efce6fa525912047685daa974463056c`;
r3 `engineering.json` SHA-256 is
`9489e2c5610a95b4d6ebb60e9d759bb2f05422d8b0f4a0967ab31a6de3692b7d`.
The r2 source snapshot is retained at
`runs/revised_chain_20260912_audit/r2_executed_source/MagneticEngineeringV4.jl`.
The detailed numerical observations below describe the unchanged r2/r3
calculation. r3 still reports engineering `fail`, solver exit 0, upstream invalid
and applicability unsupported; the stricter acceptance guard does not improve
the physical calculation.

Execution is managed by the integrating agent's Julia/DESC queue. The focused
suite completed **39/39, process exit 0**, confirmed by reading
`runs/revised_chain_20260912_audit/engineering_focused.log` and
`engineering_focused.exit`. This comprises declaration/scope checks (11), an
independent closed-form RL software benchmark (16), and executed short-circuit
and protection-equation tests (12). These results do not establish that the
unified candidate chain or production engineering stage has completed.

The initial candidate-preflight process exited 1 because the file-header string
was interpreted as a docstring for a `using` statement. The header was changed
to an ordinary block comment before the successful focused run. This was a
loading error, not an RL or physical solver result.

The unified runner has now produced actual engineering results under
`runs/revised_chain_20260912_r2`. The engineering numerical solver completed both
400-step scenarios with **exit 0**. Its overall result is nevertheless
**`status=fail`, `upstream_status=fail`, `upstream_valid=false`,
`applicability_status=unsupported`**. The preceding multi-region solve actually
stopped with **exit 3**. Neither successful circuit arithmetic nor the nominal
readout's local connection flag qualifies the physical input or engineering
subsystem. This branch reviewed the completed engineering stage; completion of
the later unified validation, integration checks and Git delivery is reported
by the integrating agent.

Focused reproducible command from the repository root:

```
julia --project=. --startup-file=no test/runtime_v4_magnetic_engineering_tests.jl
```

The manufactured 2 T and zero-field cases in this command are software tests
only. Production calculation is performed by the unified runner through
`execute_engineering_v4(context,physics,run_dir)` and uses the actual revised
physics field, its final state scale, and the same candidate/context hashes.

Full reproduction (a new output directory is required) and existing-checkpoint
continuation, respectively:

```
julia --startup-file=no --project=. scripts/run_v4_revised_chain.jl <new-run-dir>
julia --startup-file=no --project=. scripts/run_v4_revised_chain.jl runs/revised_chain_20260912_r2 --resume
```

## Actual field binding and computed results

The engineering and physics JSON artifacts have the same candidate hash
`7b44ba518eb7e7fdede814c1fccb94bd540f41c8b5e4fd3130e6971465c35548` and context hash
`de87eb7f96b38dda09e4643fcbce20db17d21b3f2207a416f755768b096fd14d`.
The selected exact surface sample is at `(rho,theta,zeta)=(1,0,0)`,
`x=(5.95,0,0) m`; the pickup disk normal is `(0,1,0)`. Its raw DESC toroidal
component `1.4407346901278963 T` multiplied by the actually computed final
outer-state amplitude `a_edge=0.5944771568624893` gives
**`B_projected=0.8564838623803913 T`**. This value matches both the engineering
input and the final-field artifact. It does not reuse the unmodified parent or
unscaled DESC field.

The declared 10% ramp over 2 ms therefore imposes a change of
`0.08564838623803914 T`, followed through a total 4 ms horizon with 10 us steps.
These are computed circuit responses to an exploratory external excitation;
the ramp remains neither measured nor a solved plasma transient.

| Recorded numerical quantity | Nominal | Readout short |
|---|---:|---:|
| Induced emf peak magnitude | 0.0336340426 V | 0.0336340426 V |
| Current peak magnitude | 0.00330653190 A | 0.0202805600 A |
| Trip time | no trip | 0.00154 s |
| First completed dump-path step | none | 0.00155 s |
| Final reconstructed field change | 0.0842001437 T | 0.0380446301 T, frozen after disconnection |
| Input electrical energy | 2.11490917e-7 J | 3.31744040e-7 J |
| Computed Joule energy | 2.10961770e-7 J | 2.62415557e-7 J |
| Backward-Euler numerical dissipation | 5.29147721e-10 J | 6.93284824e-8 J |
| Maximum circuit equation residual | 6.2450e-17 V | 2.3592e-16 V |
| Discrete energy identity error | -1.3607e-22 J | 1.0588e-22 J |
| Protection latched | false | true |
| Local readout connected/valid at end | true | false |
| Numerical solver exit | 0 | 0 |

The short begins at 1 ms. The actual CSV crosses the 0.02 A detection threshold
at 1.54 ms with `i=-0.020280560038885447 A`. The following endpoint, 1.55 ms,
uses the 100 ohm dump resistor, has `readout_connected=false` and
`i=-0.010299592582944656 A`; the integrated readout remains frozen thereafter.
The associated `-1.0299592582944657 V` is a **dump-branch voltage**, not an active
sensor readout. The relay remains latched through the final row. Thus the
fault/protection trajectory was actually calculated; it is not just a declared
fault label or a preassigned trip outcome.

The fault time integration has a material accuracy limitation: numerical
dissipation is **20.8982% of the computed input energy** (nominal: 0.250199%).
The 10 us step is approximately the dump-path `L/R` time constant of 9.98 us.
The near-roundoff discrete identity only verifies the implemented scheme's
accounting; it does **not** establish convergence of the continuous switching
transient, Joule energy, peak voltage or trip time. Those quantities need a
fault-specific refinement/independent transient check before stronger numerical
claims. Numerical dissipation is not included in the reported physical Joule
term. All engineering applicability and qualification restrictions remain.

## Artifact and independent read-only checks

Both CSVs contain 401 rows, including the initial state. A separate read-only
PowerShell calculation from their recorded `h`, `i`, `emf` and branch resistance
reconstructed Joule energy, electrical input and backward-Euler dissipation.
The Joule metric differences were `2.647e-23 J` and `0 J`; this checks artifact
consistency, not an independent physical model. Source, selected final-field,
HDF5, both CSV and text-summary SHA-256 values were recomputed and matched the
recorded input/output bindings. No Julia or DESC process was restarted for this
report review.

| Artifact | SHA-256 |
|---|---|
| `engineering.json` | `c975b072466ffa5d99a3cb7ab827b679296fe2ff15e45e4f9e997fe5d41648f0` |
| `physics/final_boundary_field.json` | `3cdf0489e892b18dcd7bbb39eede3941266f4814f837d8be1fec7bd822d84563` |
| `desc/candidate_bound.h5` | `ed68641512138db071e465567140e83a78821fad88544a500d6446a8e0ceaeb4` |
| `engineering/nominal_circuit.csv` | `39e2d2871add296c0d26784fe4e093f2dedb361fa2ac71870eca348ece026f52` |
| `engineering/readout_short_circuit.csv` | `1dc103f36aad865aff07759caaf695a26712da810978b01c0dca2483b33fbfe1` |
| `src/RuntimeV4/MagneticEngineeringV4.jl` | `d9211c0ca492e50e7ed73c3e9275c19297793183bdccf71f85f88d9315b847ec` |

The first five artifact paths are relative to
`runs/revised_chain_20260912_r2`; the source path is relative to the repository.
The actual run recorded Julia 1.10.5, Windows (`NT`), x86_64 and 24 Julia threads.

## Implemented computation and truthful limits

* Geometry: declared finite circular winding at the nearest exact outer-surface reference node, local toroidal disk normal, wire length and cross section.
* Engineering equations: Faraday induction, Ohmic winding resistance, effective-inductance RL dynamics and voltage-based magnetic-flux integration.
* Protection/fault equations: a declared readout short, sampled threshold detection, latched commutation to a closed dump resistor and frozen disconnected readout.
* Numerical diagnostics: event-aligned implicit Euler, full state histories, circuit equation residual, Joule energy, magnetic energy, and separately identified numerical energy dissipation.
* Provenance: current declaration/typed AST, source bytes, exact upstream sample/HDF5 bytes, actual selected B and basis, output CSV hashes, Julia environment and solver exit.

All interval endpoints are exploratory design specifications with units and
applicability, not measurements or probability distributions. The field ramp is
a prescribed external excitation scenario; it is not an observed or solved
plasma time history. This module executes its equations and never fabricates
output trajectories to satisfy a receipt.

The sample remains a plasma-boundary field. Finite sensor placement, exterior
field continuation, aperture uniformity and device applicability are
`unsupported`. Upstream failure is propagated. Computed circuit arithmetic
cannot establish a solid stress, magnet margin, sensor qualification, physical
validation, or whole-device completion.

## Remaining blockers and recovery conditions

| Class | Remaining condition |
|---|---|
| Physics computation/evidence | An applicable converged upstream field and an accepted complete residual solve are not presumed from the existence of DESC output bytes. |
| Numerical accuracy | The 10 us fault run has substantial implicit-Euler dissipation; switching/energy/voltage accuracy needs a dedicated refinement or independent transient check. |
| Missing model | A physically placeable external sensor aperture and candidate-owned vacuum/finite-aperture magnetic field map. |
| Missing dynamic input/model | Evidence for the declared driver ramp, or an actual coupled transient field prediction. |
| Missing engineering data | Applicable circuit/winding/relay parameters, thermal and irradiation applicability, component data and calibration. |
| Missing validation data | An independent calibrated pickup/readout experiment and explicit model-discrepancy evidence. |

Implementation and legacy reuse decisions are documented in
`docs/implementation/magnetic_engineering_v4.md`. The branch owns only
`MagneticEngineeringV4.jl`, its focused test, and these two documents. Git
staging, commit and push belong to the integrating agent after acceptance.
