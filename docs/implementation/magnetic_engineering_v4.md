# Magnetic pickup engineering execution v4

Revision 1, 2026-09-12. This module executes one declared engineering subsystem:
a finite local pickup winding, resistive readout, effective inductance, magnetic
flux integrator, short-circuit fault, threshold detector and dump-path relay.
It consumes the actual same-candidate outer-region magnetic field after the
multi-region state update attempt. A numerical circuit result is produced even
when that physical input has failed; the failure is retained in the output.

## Reuse audit before implementation

The following files were read in `../outputs/fusion_concept_ai/src` before the
new implementation was written. They are not loaded by this module.

| Legacy source | Decision | Reason and retained boundary |
|---|---|---|
| `candidate_engineering_multiphysics_runtime_v1.jl`, `engineering_load_context_v1` | extract input-admission pattern; reimplement | Retain candidate/state/hash binding and propagation of invalid upstream state. Reject use of manifest peak B or fallback radiation sink as the present pickup input; exact current DESC samples are required. |
| `dynamic_fault_provider_v108.jl`, `_v108_state_space` | extract numerical execution/reporting pattern; reimplement | Explicitly integrate state equations and record numerical method/step. This module uses event-aligned implicit Euler for stiff RL dynamics and an energy identity, rather than copying its Euler/RK2 model. |
| Same file, `_v108_control_scenario`, `_v108_quench_result` | reject | Fixed growth/disturbance constants and inferred magnet energy do not constitute present candidate physics or pickup inputs. No legacy named-fault dynamics or quench qualification is imported. |
| `magnet_engineering_compiler.jl` | reject authority and model inventory | Its broad magnet requirements and evidence gates do not define a sensor, spatial mapping or circuit. No old authority, family routing or engineering credits enter RuntimeV4. |

No legacy wrapper is needed. Manufactured constant-B inputs occur only in the
focused software test, never in `execute_engineering_v4` admission.

## Candidate ownership and equations

`engineering_declaration_v4()` returns deeply immutable
`MagneticEngineeringDeclarationV4`. It must be present exactly once in G3
realization. G3 owns `MAGNETIC_PICKUP_FLUX_V4`, `FARADAY_RL_CIRCUIT_V4` and
`PICKUP_INTEGRATOR_PROTECTION_V4`, whose typed AST `declaration` constant carries
`QualifiedRefV1(declaration_hash,"v1")` as the final typed operator input. Operator
parameters are empty because the existing exact-type manifest forbids custom
parameter schemas. No default registry is changed.
Admission also calls `validate_revised_declarations_v4` to rebuild and compare
the complete implemented G1/G2/G3 graphs, including operator wiring and types;
matching labels and declaration hashes alone is insufficient.

The declared aperture is a circular disk with normal in the local toroidal
direction. Its reference location is the nearest actual exact outer-surface
DESC node to `(rho,theta,zeta)=(1,0,0)`. The selected coordinates, basis, magnetic
vector, outer-state scale and upstream bytes are stored. The approximation
`B_aperture = B_boundary dot e_phi` has no proven exterior continuation or finite
aperture error bound. Placement and field applicability therefore remain
`unsupported`; neither exact surface sampling nor a small design radius proves
that hardware can be placed there.

The real static field supplies the amplitude of an explicitly prescribed
external excitation scenario:

```
B(t) = B_boundary_projected * (1 + alpha*min(t/T_ramp,1))
Phi(t) = N*pi*r^2*B(t)
emf(t) = -dPhi/dt
wire_length = N*2*pi*r
Rwire = resistivity*wire_length/(pi*wire_radius^2)
L*di/dt + (Rwire+Rbranch)*i = emf
dBhat/dt = -Rbranch*i/(N*pi*r^2) while readout remains connected
```

Initial current and reconstructed field change are zero. The winding is an
ideal isothermal Ohmic conductor; the effective circuit inductance is a design
input, not a value inferred from the plasma magnetic-energy density. The stated
inductance includes the series circuit; finite winding/lead geometry has no
validated inductance model yet. Electromagnetic back reaction, temperature,
irradiation, insulation and solid stresses are outside this model.

The nominal case uses the load resistor. The fault case shorts the readout at
the declared time, leaving a positive short resistance. Once `abs(i)` reaches
the detection threshold at a numerical endpoint, the relay latches and the next
interval commutates into a closed dump resistor. This preserves inductive
current continuity and executes energy removal. It is an ideal relay model;
switching arcs and detection electronics are unmodeled. Readout integration
freezes after the relay opens the readout path, and measurement validity is
false for the fault or any trip. This is sensor protection, not plasma control.

## Parameter sources, SI units and applicability

Every parameter source is this **exploratory design specification, revision 1**.
The values and intervals below are explicit design choices. They are not
measurements, material certifications, tolerances, distributions, confidence
intervals, or independently justified physical uncertainty. Their shared scope
is an ideal lumped isothermal circuit. In particular, the resistivity value is
an assumed effective Ohmic coefficient and does not establish the suitability
of any real alloy or operating environment.

| Parameter | Nominal | Design interval | SI unit |
|---|---:|---:|---|
| loop radius | 0.005 | [0.0045, 0.0055] | m |
| wire radius | 0.0001 | fixed | m |
| turns | 10 | fixed integer | 1 |
| effective resistivity | 1.72e-8 | [1.6e-8, 1.9e-8] | ohm m |
| effective total series inductance | 0.001 | fixed | H |
| nominal load resistance | 10 | [8, 12] | ohm |
| fractional imposed ramp | 0.1 | fixed | 1 |
| ramp duration | 0.002 | fixed | s |
| execution horizon | 0.004 | fixed | s |
| primary time step | 0.00001 | refinement allowed | s |
| short-circuit start | 0.001 | fixed | s |
| short resistance | 0.01 | fixed | ohm |
| trip current magnitude | 0.02 | fixed | A |
| dump resistance | 100 | fixed | ohm |

The declaration binds these design choices before the new candidate hash and
new upstream execution. Any change to the default declaration requires another
candidate revision. The pure kernel admits interval-contained overrides only
for sensitivity calculations; the production entry point rejects overrides.

## Numerical implementation and accounting

Declared discontinuity times are inserted in the time grid. The exact average
emf over each interval follows the change of the declared flux. Backward Euler
updates current by

```
i_next = (L*i_previous + h*emf)/(L+h*Rtotal)
```

The linear equation residual is reported separately from time discretization.
The executed discrete energy identity is

```
sum(h*emf*i_next) = final(0.5*L*i^2)
                    + sum(h*Rtotal*i_next^2)
                    + sum(0.5*L*(i_next-i_previous)^2).
```

The last term is backward-Euler numerical dissipation. It is reported separately
from Joule heat and the continuous energy balance defect; it cannot be called
physical dissipation or hidden in a generic error. Time refinement and an
independent analytic RL solution test this discretization. A synthetic constant
field test validates circuit software only. The verification branch consumes
the genuine engineering field amplitude for independent RL checking and design
interval propagation.

## API, provenance and remaining work

* `magnetic_pickup_response_v4(B_projected_T; declaration, overrides, fault, dt_override)` is the pure numerical kernel.
* `execute_engineering_v4(context,physics,run_dir)` validates the G3 declaration/AST and actual physics artifacts, then computes both declared scenarios.
* `validate_engineering_result_v4(context,physics,result)` replays the binding and the circuit calculations.

The production result records candidate/context/declaration/physics hashes,
actual sample and HDF5 paths and byte hashes, source bytes, Julia environment,
computed CSVs, every state history, metrics, status and numeric solver exit.
The physics validator replays raw fields through the actual final state scale
before engineering consumes them. Candidate or artifact substitution is an
error. Successful circuit arithmetic has solver exit `0`, but engineering
qualification remains false. Upstream solve failure produces `status=fail`;
otherwise physical applicability still produces `status=unsupported`.

Recovery requires: an applicable converged physical field; an actual exterior
field and finite aperture map for feasible hardware placement; a qualified
external excitation or coupled transient calculation; component/relay/material
data and applicability; and an independent calibrated experiment. No physical
validation, structural margin, magnet qualification or whole-device evidence
credit is created by this sensor calculation.
