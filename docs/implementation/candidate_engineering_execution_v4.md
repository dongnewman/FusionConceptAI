# Candidate engineering execution and real plasma-load handoff

This edge consumes the exact current `dgpi_context` and the already executed
`imit_upstream`, `imit_request`, `imit_result`. It introduces no new candidate,
Genome, DESC process, provider registry entry, authority or family route.

## Executed model and unexecuted domains

`execute_candidate_engineering(context, traction_upstream, traction_request,
traction_result)` first calls the complete
`validate_ideal_mhd_interface_traction_result` chain. It then independently
forms the Cartesian tensor

\[
\Pi=(p+B^2/(2\mu_0))I-B\otimes B/\mu_0,\qquad t=\Pi n.
\]

The sign follows outward static-MHD momentum flux. This is not a solid Cauchy
stress. Tensor-vector contraction is compared with the existing independently
written direct-traction formula. Normal and tangential tractions, and local
magnetic energy density `B^2/(2mu0)`, are computed at the actual two-sided DESC
sample locations. Units are Pa, T, N/A² and J/m³. The upstream permeability
value/source and Cartesian basis conversion are preserved.

Each location is a sampled plasma rho interface. The upstream samples are at
`c ± epsilon`; they are not a proved one-sided boundary limit. No global peak,
coil field, total coil stored energy, conductor stress, heat deposition or
component load follows from these point samples. `component_load=false` is
retained in every sample. The result records `load_projection_executed=true`
as an actual model substage. It records engineering, control and fault as
`executed=false, status=unsupported`.

The candidate's current G3 is `dgpi_base._fixture_realization`, declared in
`examples/runtime_v4_declared_fixture.jl`. Its realization and control
payloads are empty; both graphs contain region/boundary nodes and zero
hyperedges. Accordingly, eight candidate/graph-bound recoverable gaps cover
component load mapping, material applicability/allowables, structural models,
magnet/power models, thermal hydraulics, control plant/actuation, protection,
and declared fault cases. Each gap lists the actual inputs needed to reopen
that edge. The gap inventory itself is not execution of any of these models.

## Identity and integration

`CandidateEngineeringExecutionV4` carries candidate, context, scenario, G3,
realization/control graph binding hashes; payload/operator counts; traction
request/result and real pressure-process receipt hashes; equilibrium artifact
SHA-256; source path/SHA-256; typed samples and typed recoverable gaps.
`canonical_hash` verifies constitutive replay and the observation-only state.
`validate_candidate_engineering_execution` recomputes the receipt from the
complete real upstream chain, rejecting retargeted identities or missing
samples even if the altered object has a consistent standalone hash.

`candidate_engineering_summary` exposes compact measured extrema with names
that explicitly say `sampled`. The unified runner can call
`check_candidate_engineering_integration(owner, context, upstream, request,
result, execution)` from
`test/runtime_v4_candidate_engineering_integration_checks.jl` without
restarting the upstream provider.

## Legacy source audit before implementation

All legacy files below were read under
`D:/006-Programing/LMC/outputs/fusion_concept_ai/src/`. No legacy file is
included at runtime.

| Source and audited entry | Decision | Evidence and disposition |
| --- | --- | --- |
| `magnet_engineering_compiler.jl`, `default_magnet_engineering_requirements_v1` (line 76), `compile_magnet_engineering_problem_v1` (line 118) | extract | Reuse the explicit missing-input distinctions: conductor geometry, material applicability, structural support loads, supply/quench and maintainability. Re-express requirements as current G3-bound gaps. Legacy Genome/evidence/C2 and aggregation structures are rejected. |
| `material_engineering_provider_v109.jl`, catalog loader/audit and `execute_material_engineering_provider_v109` (line 145) | test-only / reject | Catalog hashing and independent applicable limits are useful future test patterns. Current execution hard-selects ITER, EUROFER, REBCO, radial-build and tokamak-scope records and requires old v106/v108 survivors. No current candidate material mapping establishes applicability. Do not apply those limits to plasma pressure. |
| `channel_thermal_hydraulics_provider_v117.jl`, `compile_coolant_channel_graph_v117` (line 70), `_v117_hydraulics` (line 150) | extract / test-only | Steady advection energy `m_dot cp (T_i-T_prev)=Q_i` and the analytic outlet check are reusable after typed heat/flow/geometry declarations exist. Fixed helium properties, overlay diameter/length/velocity lists, fixed flow fault and the old residual registry remain test-only. No current thermal solve is run. |
| `dynamic_fault_provider_v108.jl`, `_v108_control_scenario` (line 47), `_v108_state_space` (line 57), `_v108_quench_result` (line 148) | test-only / reject | Euler/RK2 comparison can test a declared ODE kernel. Hard-coded growth rates, disturbances, scenario names, controller gain overlays, coil proxy energy, density/heat-capacity assumptions and old authority path are rejected as current-candidate input. No trajectory or fault result is imported. |
| Legacy runtime wrappers | reject | No wrapper is admitted in this milestone: legacy dictionaries, earlier candidate identities and provider authority are incompatible with the current typed context and missing G3 inputs. |

Pinned source SHA-256 values:

```
magnet_engineering_compiler.jl
366982ADA0E604187E864E358AC9DC149F7F4F880ECF941BE9E3E9020B8D5FF3
material_engineering_provider_v109.jl
0E261689C248014E35A611450C0BA340244D769A2DF4F5066B1EC4BF0F253023
channel_thermal_hydraulics_provider_v117.jl
7DE19A263159510E83A5CA8EC138FFA56CAAF42CB33121F516B4333F666400B2
dynamic_fault_provider_v108.jl
D5A3EA7E30A267C1E3F87E61F84594130742A61AF18CF97505D1BBE698EF2BD9
```

## Verification boundary

The focused test checks exact hydrostatic, parallel/transverse magnetic and
oblique shear cases; tensor eigenvalues and rotational covariance; malformed
inputs; current G3 emptiness and non-promotable gaps. These are analytic
software/model-kernel checks, not experimental validation.

The separate integration check requires the actual current-candidate upstream
and receipt. A focused test exit code alone cannot establish its execution.
No engineering, control, fault, experimental validation, probabilistic UQ or
whole-device completion is granted by this edge.
