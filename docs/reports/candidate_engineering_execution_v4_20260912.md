# Current-candidate engineering handoff, 2026-09-12

The new edge is implemented in `CandidateEngineeringExecutionV4.jl`. It
replaces use of an unrelated manufactured engineering/control fixture in the
current candidate's handoff: real DESC pressure/B and interface normals can
now produce a candidate-bound, independently checked momentum-flux tensor
and pointwise traction projection.

Actual engineering, control and fault execution remains unsupported and
unexecuted because the current G3 has no realization/control payloads or
executable operators. No material, component, thermal, controller or fault
parameter was invented to change that result. Eight detailed recoverable
input/model gaps travel with the receipt. The implementation document records
the required extract/wrap/test-only/reject audit of the old sources.

The focused analytic/admission command is:

```
julia --project=. --startup-file=no test/runtime_v4_candidate_engineering_execution_tests.jl
```

Focused exits, real-upstream substage measurements and final integration exits
are recorded separately below. Real integration is owned by the unified
runner so this work does not restart DESC or independent-cubature processes.

## Verified results

The focused process finished with exit code **0** and **28/28** checks:
17 analytic momentum-flux invariant/invalid-input checks and 11 current-G3
admission/gap checks. In the exact analytic oblique-field case, the principal
momentum fluxes were `(-0.25, 4.25, 4.25)` Pa and traction was
`(3.75, -1, -1)` Pa. These chosen analytic inputs are test-only.

A subsequent header-only check with `--compile=min -O0` was deliberately
aborted for excessive interpreter-mode overhead (Julia PID 135412; command
exit **1**, no completed test result). It is not counted as a successful run.
The final unified integration uses normal compilation and includes the
production module with its header expressed as a block comment.

The unified run has now completed: the operating-system process exit in
`runs/candidate_chain_20260912/integrated.exit` is **0**, and
`runs/candidate_chain_20260912_integrated/runner.exit` is **0**. Its
`execution_manifest.json` records `script_exit_code=0`. The actual-candidate
engineering integration checks passed **22/22**; the complete runner passed
**108/108** checks. The log is
`runs/candidate_chain_20260912/integrated.log`.

These exits verify successful execution, artifact replay and integration
accounting. The actual engineering/control/fault model status remains
`unsupported` and unexecuted; numerical verification reports `fail`, and the
whole-device assessment reports `deferred`. This report does not claim results
for separate repository regression processes.

## Actual same-candidate plasma-load projection

The unified run wrote
`runs/candidate_chain_20260912_integrated/engineering.json` at
2026-09-12 13:11:21 +08:00 and printed
`CHAIN_ENGINEERING_LOAD_PROJECTION_EXIT_CODE=0`. The complete real DESC/traction
upstream was consumed by `execute_candidate_engineering`; the numbers below
are from that JSON, not from the analytic test. The completed main process and
actual-upstream integration checks are recorded separately above.

| Measured quantity | Actual value | Scope |
| --- | --- | --- |
| Sample count | 2 | Minus/plus samples on one `rho_interface`, owned by `rho_inner` / `rho_outer` |
| Maximum sampled pressure | 251.0 Pa | The plus-side sample is 249.0 Pa |
| Maximum sampled magnetic energy density | 1,784,654.6411021957 J/m³ | Local `B²/(2mu0)`, not total coil energy |
| Maximum sampled traction magnitude | 1,784,905.64110172 Pa | Plasma momentum-flux traction, not a component stress |
| Maximum independent tensor/direct-traction difference | 2.3283064365386963e-10 Pa | Independent algebraic decomposition comparison |

The two traction magnitudes are `1784905.64110172` and
`1784516.0128715236` Pa. Samples are finite-offset plasma interface proxies,
not boundary limits or global peaks. All samples retain `component_load=false`.

Identity and provenance:

```
candidate_hash = 0619e5bbd0537caad9bec630db6667b2e37c1346fb24ce86e4f10db39af16f10
context_hash = 88464c462e6009e930efef24ea1a1a20f16d8a3a449d0a9853c940f325a7afd5
scenario_hash = 9752177ad8f544a21564ec5ea148f75746cbee4b02723e1e530bca28ee188a5f
g3_hash = 53792b75f779996c240dbdd8e199f5c867e438d441345ff63192dc1959938433
equilibrium_output_sha256 = ffc7881305e283a4ea54eb2c3b926d5b81510be930921e43125a318dd7fd1d80
pressure_field_receipt_hash = fb28bc9a4936f60f4d2cbe652a4b65a31aab03109fd71c2ca75db8ba7db36b6d
traction_result_hash = b8002d7a097da378e8a9ed486241d8eb739c37218c2d2805e237059eba6de591
production_source_sha256 = 36bfde793b17aa0392f46f2acdae98dee4ff2de65af7601ffe5c177f3f33868e
engineering_json_sha256 = f05e8f20ed55a61bfa196aa192d71c48eccabe9ccd5ae0407ff2cc15bfbb5340
end_to_end_result_hash = 2e0042ce784b5bbc89594d1186ee59db011f6aecaa87fa212b64647fb0dfb1a3
execution_manifest_file_sha256 = 5db3b18b32b2cec18e839c6aa89e9d16b8e6aaf46e0a72fa6a6af6552affcdac
```

## Remaining engineering/control/fault gaps

The actual receipt confirms zero realization/control payloads and zero
realization/control operators. All eight gaps are `unsupported`, recoverable,
and bound to the above current G3 and the applicable typed graph binding.

| Gap code | Required inputs before the actual model can run |
| --- | --- |
| `missing_component_load_mapping` | Component geometry, plasma-to-component boundary map, area/time-supported loads |
| `missing_material_model_and_allowables` | Material/property source, temperature/irradiation applicability, stress allowables |
| `missing_structural_model` | Solid mesh/supports, constitutive law, load cases and displacement boundary conditions |
| `missing_power_and_magnet_model` | Finite conductor geometry, current/winding law, inductance/resistance and supply limits |
| `missing_thermal_hydraulic_model` | Deposited heat map, coolant/material properties, channel geometry and mass flow |
| `missing_control_plant_and_actuator_model` | Actual plant linearization/state equations, sensor transfer/noise/delay, actuators and controller |
| `missing_protection_model` | Quench/detection model, energy-extraction circuit and limits, safe-state/recovery criteria |
| `missing_declared_fault_cases` | Candidate-owned triggers, fault magnitude/timing, recovery horizon and thresholds |

Accordingly, `engineering_executed=false`, `control_executed=false` and
`fault_executed=false`; each corresponding status is `unsupported`. Physical
validation, engineering validation and promotion/terminal authority remain
false, with `claim_ceiling=screen_only` and `credible_device_count=0`.
