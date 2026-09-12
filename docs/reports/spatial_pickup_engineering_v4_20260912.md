# Spatial pickup engineering execution record — 2026-09-12

Status at closeout was **60/60 focused checks passed, process exit 0; actual
spatial engineering execution pending**. A subsequent minimal source/test edit
split input identity from physical upstream validity, split transfer/circuit
exits, and made trajectory/event timing semantics explicit. Per the main-agent
queue boundary, that changed revision has not yet been rerun. The prior measured
software checks do not establish the changed revision, physical validity, or
completion of the spatial chain. The main agent owns all Julia tests and actual
upstream/physics/circuit execution.

## Declaration and implementation

The G3 declaration, exact current-input schemas, finite-disk Biot-Savart,
independent unit-loop reciprocity, static flux/zero EMF, exact-flow conditional
RL response and fixed-cadence short/dump protection are implemented. The design
and legacy extract/test-only/reject audit are recorded in
`docs/implementation/spatial_pickup_engineering_v4.md`.

All four declared physical cases must feed this engineering implementation;
the named primary remains nominal coarse. The new execution does not reuse
the old reduced candidate's DESC receipt or sampled field as its spatial input.
The validator requires current-state spatial artifacts from the new candidate.

## Execution and measurements

| Work | Implemented | Executed at handoff | Exit code / measured result |
| --- | --- | --- | --- |
| Actual current artifact admission/replay | yes | no | pending main queue |
| J/K to finite-disk field and flux linkage | yes | no | pending actual four cases |
| Independent transfer reciprocity | yes | no | pending actual four cases |
| Stationary static zero-EMF result | yes | no | pending actual four cases |
| Conditional nominal/short exact RL, protection | yes | no | pending actual linkage |
| Focused software tests for closeout source | yes | yes | 60/60, process exit 0 |
| Focused software tests for current minimal edit | yes | no | pending main queue |
| Experimental / independent physical validation | no applicable data | no | unsupported |

The test-only current loop, CSV jump and 1-T-equivalent linkage are explicitly
manufactured software fixtures. They cannot replace any row of actual-case
engineering acceptance. A scenario's prescribed ramp also provides no evidence
of actual solved plasma dynamics.

The first root-queued focused process exited 1 while parsing the ambiguous
`0.&&!` expression; no model calculation ran. Evidence is
`runs/spatial_chain_20260912_audit/engineering_focused.log` and its exit file.
The expression was corrected to `0.0 && !`. Unsupported enclosure records may
omit an artifact; a supported enclosure still requires one. Dedicated cases
cover both branches. The closeout source SHA256 was
`e85b8ec6aee40fc802592ad95c547f3a399d3782366cd6cc6671c7e13c235649`;
the closeout focused test SHA256 was
`d8cb9b2d06ef157ba9ddae674ebbcafb20ba59cdc49565837b67b3ec659b7800`.

The root-queued rerun completed: ownership/enclosure 19/19, analytic loop and
reciprocity 8/8, current CSV mapping/tamper guards 7/7, exact RL segment 7/7,
protection/events 19/19. Log
`runs/spatial_chain_20260912_audit/engineering_focused_r2.log` records
`SPATIAL_PICKUP_ENGINEERING_FOCUSED_EXIT_CODE=0`; the companion
`engineering_focused_r2.exit` contains `0`. The current-loop and circuit inputs
in this focused run are test-only, not actual spatial candidate artifacts.

The current unexecuted minimal edit has source SHA256
`65ced17e2c02a1644e06ab2214517c04bae76bdeb5eabfad85cbe5ca3273f848`
and focused-test SHA256
`95c91d78ac54a4b69e81c6437b7670dc664a604d208c2403e54ba281cdefaeab`.
Those hashes identify code awaiting the main queue; they are not exit evidence.
The revised case seal requires `input_identity_valid=true` while retaining
`physical_upstream_valid=false`; compatibility `upstream_valid` must equal the
latter. Transfer and conditional-circuit exit codes are independently sealed.
Trajectory rows now state their pre-commutation right-limit semantics and a
pending commutation, while switch events carry explicit resistance, voltage,
connection and continuous-current left/right limits.

## Remaining limits and recovery conditions

Current-source closure and external coil/outer-sheet contributions must be
provided before the computed partial flux can become total external linkage.
A continuous actual DESC geometry bound must fit inside the candidate-owned
enclosure to prove continuous ideal-aperture clearance. Otherwise the code
records unsupported enclosure while retaining the frozen placement and actual
discrete-source contribution calculation. A sample-only enclosure is not a
continuous-volume proof.

Actual plasma dynamics are absent; the static transfer is a real engineering
computation, while the conditional ramp circuit remains a design response.
Hardware geometry, material applicability, parasitic/switch/thermal models and
experimental calibration remain unvalidated. Engineering process exit 0, if
obtained, will not override upstream failure or these applicability limits.

The previous reduced r3 run and its 44/44 focused exit 0 are documented in
`docs/reports/magnetic_engineering_v4_20260912.md`. Its 20.9% short-circuit BE
energy defect motivated the new exact-flow implementation; it is not a result
of this spatial code. Removal of that defect requires measured exact-flow
energy identities and independent verification on actual propagated flux.

## Reproduction and artifact requirements

Focused staging command from the repository root:

```powershell
julia --project=. runs/spatial_chain_20260912_staging/test/runtime_v4_spatial_pickup_engineering_tests.jl
```

The complete run uses the main spatial runner and its single revised candidate.
Its measured report must record candidate/context/state identities, raw current
CSV hashes, provider enclosure provenance, finite-disk and circuit CSV hashes,
source/environment hashes, process/solver exits, trip/event/energy results and
upstream validity. No Julia/DESC process was started by this engineering agent.
