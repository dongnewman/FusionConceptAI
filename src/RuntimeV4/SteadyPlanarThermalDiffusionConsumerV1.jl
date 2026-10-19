"""Candidate-bound steady planar wall-conduction consumer over the existing DCCE FV path.

This is a deliberately narrow component model: one-dimensional, static heat
conduction through a planar slab per unit cross-sectional area; G2 x_min/x_max
own the end conditions, and all four transverse faces are adiabatic. It requires
actual candidate G1/G2/G3 declarations and a T0 bundle. It calls the existing
declared spatial transfer, finite-volume assembly, and linear solve functions;
it bypasses the separate two-DOF manufactured DGD solve. This is screen-only
component numerics, not plasma transport, reactor heat load, validation, or
terminal physics authority.
"""

module SteadyPlanarThermalDiffusionConsumerV1

using FusionConceptAI
import FusionConceptAI: UnitSignature, canonical_hash, semantic_view

const _TEMP_K = UnitSignature((0, 0, 0, 0, 1, 0, 0))
const _COORD_M = UnitSignature((1, 0, 0, 0, 0, 0, 0))
const _METRIC_M2 = UnitSignature((2, 0, 0, 0, 0, 0, 0))
const _AREA_M2 = _METRIC_M2
const _VOLUME_M3 = UnitSignature((3, 0, 0, 0, 0, 0, 0))
const _K_W_M_K = UnitSignature((1, 1, -3, 0, -1, 0, 0))
const _FLUX_W_M2 = UnitSignature((0, 1, -3, 0, 0, 0, 0))
const _SOURCE_W_M3 = UnitSignature((-1, 1, -3, 0, 0, 0, 0))
const _GRIDAP_Q1_DIAGNOSTIC_CALL_SINK = Ref{Any}(nothing)

const _G1_THERMAL_SOURCE_SCHEMA =
    "fusionconceptai:genome-v5:g1-typed-source-field-program-v1"

_units(x, expected) = x == expected

function _thermal_t0_record(bundle, layer)
    matches = Tuple(record for record in bundle.declarations if
        record isa FusionConceptAI.VNextT0LocalPresentDeclarationV1 &&
        record.layer === layer)
    length(matches) == 1 ||
        throw(ArgumentError("thermal_t0_record_not_unique:$layer"))
    only(matches)
end

"""Verify the exact source-bearing T0 records before trusting the capability.

The capability is an object carried by the admitted G1 semantic body. T0
source/declaration identity hashes are recomputed from the actual byte records;
they are intentionally not treated as capability-authored provenance.
"""
function _verify_g1_steady_thermal_field_capability_v1(input, g1_record,
        g2_record, capability; records_checked::Bool=false)
    g1_record isa FusionConceptAI.VNextT0LocalPresentDeclarationV1 &&
        g1_record.layer === :G1 ||
        throw(ArgumentError("thermal_source_proof_g1_record_type_or_layer_mismatch"))
    g2_record isa FusionConceptAI.VNextT0LocalPresentDeclarationV1 &&
        g2_record.layer === :G2 ||
        throw(ArgumentError("thermal_source_proof_g2_record_type_or_layer_mismatch"))
    if !records_checked
        FusionConceptAI._dgd_record_integrity(g1_record, input.candidate_ref, input.g1)
        FusionConceptAI._dgd_record_integrity(g2_record, input.candidate_ref, input.g2)
    end
    g1_record.candidate_ref == g2_record.candidate_ref == input.candidate_ref ||
        throw(ArgumentError("thermal_source_proof_record_candidate_mismatch"))
    g1_record.source_ref == input.g1.source_ref &&
        g1_record.declaration_ref isa FusionConceptAI.QualifiedRefV1 ||
        throw(ArgumentError("thermal_source_proof_g1_actual_record_join_mismatch"))
    g2_record.source_ref == input.g2.source.source_ref &&
        g2_record.declaration_ref isa FusionConceptAI.QualifiedRefV1 ||
        throw(ArgumentError("thermal_source_proof_g2_actual_record_join_mismatch"))
    hasproperty(g1_record.semantic_body.body, :value) ||
        throw(ArgumentError("thermal_g1_source_value_missing"))
    source_value = g1_record.semantic_body.body.value
    hasproperty(source_value, :g1_typed_source_field_program) ||
        throw(ArgumentError("thermal_g1_typed_source_program_missing"))
    source_value.g1_typed_source_field_program === capability ||
        throw(ArgumentError("thermal_source_capability_not_the_admitted_g1_carrier"))
    true
end

function verify_g1_steady_thermal_field_capability_v1(input, g1_record,
        g2_record, capability)
    _verify_g1_steady_thermal_field_capability_v1(input, g1_record,
        g2_record, capability; records_checked=false)
end

"""Recover the typed source program from the exact, already admitted G1 body."""
function _thermal_source_capability(input; records_checked::Bool=false)
    g1_record = _thermal_t0_record(input.bundle, :G1)
    g2_record = _thermal_t0_record(input.bundle, :G2)
    g1_record.candidate_ref == input.candidate_ref == g2_record.candidate_ref ||
        throw(ArgumentError("thermal_source_record_candidate_mismatch"))
    hasproperty(g1_record.semantic_body.body, :value) ||
        throw(ArgumentError("thermal_g1_source_value_missing"))
    source_value = g1_record.semantic_body.body.value
    hasproperty(source_value, :g1_typed_source_field_program) ||
        throw(ArgumentError("thermal_g1_typed_source_program_missing"))
    capability = source_value.g1_typed_source_field_program
    capability.schema == _G1_THERMAL_SOURCE_SCHEMA ||
        throw(ArgumentError("thermal_g1_source_program_schema_mismatch"))
    _verify_g1_steady_thermal_field_capability_v1(input, g1_record,
        g2_record, capability; records_checked=records_checked)
    capability.candidate_ref == input.candidate_ref ||
        throw(ArgumentError("thermal_g1_source_program_candidate_mismatch"))
    capability.g1_source_ref == g1_record.source_ref == input.g1.source_ref ||
        throw(ArgumentError("thermal_g1_source_program_source_ref_mismatch"))
    capability.g1_declaration_ref == g1_record.declaration_ref ||
        throw(ArgumentError("thermal_g1_source_program_declaration_ref_mismatch"))
    capability.g1_u_field_id == input.g1.u.field_id &&
        capability.g1_f_field_id == input.g1.f.field_id ||
        throw(ArgumentError("thermal_g1_source_program_field_binding_mismatch"))
    capability.g2_source_ref == g2_record.source_ref == input.g2.source.source_ref ||
        throw(ArgumentError("thermal_g1_source_program_g2_source_ref_mismatch"))
    capability.g2_declaration_ref == g2_record.declaration_ref ||
        throw(ArgumentError("thermal_g1_source_program_g2_declaration_ref_mismatch"))
    (capability=capability, g1_record=g1_record, g2_record=g2_record)
end

"""Read the optional G3 temperature-to-G1-source law from the admitted child bytes.

The returned law is an authored source capability, not a native G3 controller
gene. Its temperature sensor, owned fraction actuator, and existing resource link
must be present in the exact typed G3 child carried by the current T0 record.
"""
function thermal_temperature_source_density_input_v1(input, temperature_K)
    g3_record = _thermal_t0_record(input.bundle, :G3)
    FusionConceptAI._dgd_record_integrity(g3_record, input.candidate_ref, input.g3)
    hasproperty(g3_record.semantic_body.body, :authored_child_design) ||
        throw(ArgumentError("thermal_G3_authored_child_design_missing"))
    child = g3_record.semantic_body.body.authored_child_design
    _thermal_admit_temperature_source_profile_v1(input, g3_record, child, temperature_K)
end

function _thermal_admit_temperature_source_profile_v1(input, g3_record, child, temperature_K)
    hasproperty(child, :control) && hasproperty(child, :control_design) ||
        throw(ArgumentError("thermal_G3_control_source_or_design_missing"))
    control = child.control
    control isa FusionConceptAI.G3ControlSourceBodyV1 ||
        throw(ArgumentError("thermal_G3_control_source_wrong_type"))
    hasproperty(child.control_design, :temperature_source_feedback) ||
        throw(ArgumentError("thermal_G3_temperature_source_feedback_absent"))
    law = child.control_design.temperature_source_feedback
    law isa NamedTuple && keys(law) == (:schema, :version, :scope,
        :execution_scope, :candidate_id, :scenario_id, :controller_id,
        :temperature_sensor_port_id, :temperature_sensor_unit,
        :actuator_port_id, :actuator_unit, :actuator_to_q,
        :target_g1_field_id, :target_operator, :measurement_reduction,
        :law, :setpoint_kelvin, :gain_w_m3_per_kelvin, :gain_unit,
        :q0_w_m3, :q_min_w_m3, :q_max_w_m3, :q_unit, :parameter_id) ||
        throw(ArgumentError("thermal_G3_temperature_source_feedback_shape_invalid"))
    law.schema == "up3-temperature-source-density-proportional-v1" &&
        law.version == "v1" && law.scope === :authored_design_assumption &&
        law.execution_scope === :authored_source_capability &&
        hasproperty(child, :unit_basis) &&
        child.unit_basis == (:kg, :m, :s, :A, :K, :mol, :cd) &&
        law.candidate_id == child.candidate_id &&
        law.scenario_id == child.scenario_id &&
        law.candidate_id == replace(input.candidate_ref.id,
            "fusionconceptai://candidate-design/" => "") ||
        throw(ArgumentError("thermal_G3_temperature_source_feedback_identity_mismatch"))
    controller_rows = Tuple(c for c in control.controllers
        if c.controller_id == law.controller_id)
    length(controller_rows) == 1 ||
        throw(ArgumentError("thermal_G3_temperature_source_controller_ambiguous"))
    controller = only(controller_rows)
    signals = Dict(signal.port_id => signal for signal in control.signal_ports)
    haskey(signals, law.temperature_sensor_port_id) &&
        haskey(signals, law.actuator_port_id) &&
        law.temperature_sensor_port_id in controller.sensor_port_ids &&
        law.actuator_port_id in controller.actuator_port_ids &&
        law.actuator_port_id in control.plan.signal_port_ids ||
        throw(ArgumentError("thermal_G3_temperature_source_ports_not_bound"))
    sensor = signals[law.temperature_sensor_port_id]
    command = signals[law.actuator_port_id]
    sensor.signal_kind === :sensor && sensor.direction === :in &&
        sensor.unit == law.temperature_sensor_unit == _TEMP_K &&
        command.signal_kind === :command && command.direction === :out &&
        command.unit == law.actuator_unit &&
        command.unit == UnitSignature() &&
        command.account_id == "source_command_account" ||
        throw(ArgumentError("thermal_G3_temperature_source_port_signature_mismatch"))
    hasproperty(child, :control_resource_links) && hasproperty(child, :resource_network) ||
        throw(ArgumentError("thermal_G3_temperature_source_resource_binding_missing"))
    links = Tuple(link for link in child.control_resource_links
        if link.controller_id == controller.controller_id &&
            link.sensor_port_id == sensor.port_id &&
            link.actuator_port_id == command.port_id &&
            link.fault_id in controller.fault_ids)
    length(links) == 1 ||
        throw(ArgumentError("thermal_G3_temperature_source_resource_link_missing_or_ambiguous"))
    link = only(links)
    current_map = child.control_design.command_to_current_map
    power_map = child.control_design.command_to_power_map
    link.resource_port_id == current_map.target_resource_port_id &&
        current_map.law === :fraction_of_rated_current &&
        current_map.rated_current == 2 &&
        current_map.rated_current_unit == UnitSignature((0, 0, 0, 1, 0, 0, 0)) &&
        current_map.command_unit == command.unit && current_map.output_unit == current_map.rated_current_unit &&
        current_map.offset == 0 && power_map.coefficient == 1000 &&
        power_map.coefficient_unit == UnitSignature((1, 2, -3, 0, 0, 0, 0)) &&
        power_map.command_unit == command.unit &&
        power_map.output_unit == UnitSignature((1, 2, -3, 0, 0, 0, 0)) &&
        power_map.offset == 0 ||
        throw(ArgumentError("thermal_G3_temperature_source_current_or_power_map_mismatch"))
    resource_ports = Tuple(port for port in child.resource_network.resource_ports
        if port.port_id == link.resource_port_id)
    length(resource_ports) == 1 ||
        throw(ArgumentError("thermal_G3_temperature_source_resource_port_missing_or_ambiguous"))
    resource_port = only(resource_ports)
    resource_port.kind === :flow && resource_port.direction === :out &&
        resource_port.unit == current_map.output_unit &&
        resource_port.account_id == "design_energy" ||
        throw(ArgumentError("thermal_G3_temperature_source_resource_port_signature_mismatch"))
    hasproperty(child, :realization) &&
        hasproperty(child.realization, :manufacturing_domains) ||
        throw(ArgumentError("thermal_G3_temperature_sensor_domain_missing"))
    sensor_domains = Tuple(domain for domain in child.realization.manufacturing_domains
        if domain.parameter === :temperature && domain.unit == _TEMP_K)
    length(sensor_domains) == 1 ||
        throw(ArgumentError("thermal_G3_temperature_sensor_domain_ambiguous"))
    sensor_domain = only(sensor_domains)
    law.target_g1_field_id == input.g1.f.field_id &&
        law.target_operator === :minus_div_k_grad &&
        law.measurement_reduction === :maximum_cell_center &&
        law.law === :proportional_temperature_error_clamped_v1 &&
        law.q_unit == _SOURCE_W_M3 &&
        law.actuator_to_q isa NamedTuple &&
        keys(law.actuator_to_q) == (:fraction_min, :fraction_max, :q_min_w_m3, :q_max_w_m3) &&
        law.actuator_to_q.fraction_min == 0 && law.actuator_to_q.fraction_max == 1 &&
        law.actuator_to_q.q_min_w_m3 == law.q_min_w_m3 &&
        law.actuator_to_q.q_max_w_m3 == law.q_max_w_m3 &&
        law.gain_unit == UnitSignature((-1, 1, -3, 0, -1, 0, 0)) &&
        law.q_min_w_m3 isa Rational && law.q0_w_m3 isa Rational &&
        law.q_max_w_m3 isa Rational &&
        0 <= law.q_min_w_m3 < law.q0_w_m3 < law.q_max_w_m3 &&
        law.gain_w_m3_per_kelvin isa Rational &&
        law.gain_w_m3_per_kelvin > 0 &&
        sensor_domain.lower <= law.setpoint_kelvin <= sensor_domain.upper &&
        sensor_domain.lower <= temperature_K <= sensor_domain.upper &&
        isfinite(Float64(temperature_K)) ||
        throw(ArgumentError("thermal_G3_temperature_source_law_or_bounds_invalid"))
    g1_records = _thermal_source_capability(input; records_checked=false)
    capability = g1_records.capability
    capability.g1_f_field_id == input.g1.f.field_id &&
        capability.g1_source_ref == g1_records.g1_record.source_ref &&
        capability.g2_source_ref == g1_records.g2_record.source_ref &&
        Float64(capability.source_law.bindings.q.value) == Float64(law.q0_w_m3) ||
        throw(ArgumentError("thermal_G3_temperature_source_G1_join_mismatch"))
    q0 = Float64(law.q0_w_m3)
    q = clamp(q0 + Float64(law.gain_w_m3_per_kelvin) *
        (Float64(law.setpoint_kelvin) - Float64(temperature_K)),
        Float64(law.q_min_w_m3), Float64(law.q_max_w_m3))
    parameter_ref = FusionConceptAI.FieldParameterRefV1(law.parameter_id)
    actuator_fraction = Float64((q - law.q_min_w_m3) /
        (law.q_max_w_m3 - law.q_min_w_m3))
    law.actuator_to_q.fraction_min <= actuator_fraction <=
        law.actuator_to_q.fraction_max ||
        throw(ArgumentError("thermal_G3_temperature_source_actuator_out_of_bounds"))
    remapped_q = Float64(law.actuator_to_q.q_min_w_m3) + actuator_fraction *
        Float64(law.actuator_to_q.q_max_w_m3 - law.actuator_to_q.q_min_w_m3)
    isapprox(remapped_q, q; rtol=0, atol=8eps(max(abs(q), 1.0))) ||
        throw(ArgumentError("thermal_G3_temperature_source_actuator_map_mismatch"))
    runtime = isdefined(Main, :FusionRuntimeV4) ?
        getfield(Main, :FusionRuntimeV4) : nothing
    runtime !== nothing &&
        isdefined(runtime, :g1_runtime_source_density_parameter_v1) &&
        isdefined(runtime, :g1_runtime_source_density_input_v1) &&
        isdefined(runtime, :evaluate_g1_runtime_source_density_v1) ||
        throw(ArgumentError("thermal_G1_runtime_source_density_api_not_loaded"))
    source_profile = Base.invokelatest(
        getfield(runtime, :g1_runtime_source_density_parameter_v1), capability;
        parameter_ref=parameter_ref,
        q_bounds_W_m3=(Float64(law.q_min_w_m3), Float64(law.q_max_w_m3)))
    bounds = FusionConceptAI.QuantityIntervalV1(
        FusionConceptAI.ExactFiniteIntervalV1(law.q_min_w_m3,
            law.q_max_w_m3, false), _SOURCE_W_M3)
    normalized = 2.0 * (q - Float64(law.q_min_w_m3)) /
        (Float64(law.q_max_w_m3 - law.q_min_w_m3)) - 1.0
    gene = FusionConceptAI.FieldParameterGeneV1(parameter_ref, _SOURCE_W_M3,
        FusionConceptAI.ParameterTransformSpecV1(FusionConceptAI.transform_linear),
        bounds, normalized)
    source_input = Base.invokelatest(
        getfield(runtime, :g1_runtime_source_density_input_v1),
        source_profile, gene)
    chart = input.g2.source.chart_map
    chart_points = Tuple((((Float64(input.spatial_case.new_geometry.edges[i]) +
        Float64(input.spatial_case.new_geometry.edges[i + 1])) / 2.0 -
        Float64(chart.offset[1])) / Float64(chart.jacobian_rows[1][1]), 0.5, 0.5)
        for i in 1:(length(input.spatial_case.new_geometry.edges) - 1))
    evaluated = Base.invokelatest(
        getfield(runtime, :evaluate_g1_runtime_source_density_v1),
        capability, source_profile, source_input, chart_points)
    source_record_hash = canonical_hash((record=g3_record.source_identity_hash,
        declaration=g3_record.declaration_identity_hash,
        profile=law, control=control))
    (schema="fusionconceptai:runtime-v4:g3-temperature-to-g1-source-density-v1",
        status=:ready, claim_ceiling=:screen_only,
        g3_source_ref=g3_record.source_ref,
        g3_declaration_ref=g3_record.declaration_ref,
        g3_source_profile_hash=canonical_hash(law),
        g3_source_record_hash=source_record_hash,
        controller_id=controller.controller_id,
        sensor_port_id=sensor.port_id, sensor_unit=sensor.unit,
        actuator_port_id=command.port_id, actuator_unit=command.unit,
        actuator_fraction=actuator_fraction,
        resource_link_id=link.link_id, resource_port_id=link.resource_port_id,
        temperature_K=Float64(temperature_K), setpoint_K=Float64(law.setpoint_kelvin),
        gain_W_m3_K=Float64(law.gain_w_m3_per_kelvin),
        q0_W_m3=q0, q_min_W_m3=Float64(law.q_min_w_m3),
        q_max_W_m3=Float64(law.q_max_w_m3), q_W_m3=source_input.q_W_m3,
        g1_profile=source_profile, g1_input=source_input,
        g1_evaluation=evaluated, candidate_ref=input.candidate_ref)
end

"""Independent conservative FV oracle for a cellwise source and equal end temperatures.

The cell source sets successive face fluxes through F[i+1]-F[i]=q[i]*h;
the left face flux is selected so the integrated temperature rise is zero.
This does not call the assembled matrix solver.
"""
function _thermal_nonuniform_fv_flux_oracle_v1(q_cells, h, length_m, kxx, t0)
    n = length(q_cells)
    n > 0 && isfinite(h) && h > 0.0 && isfinite(kxx) && kxx > 0.0 &&
        isapprox(length_m, n * h; rtol=0.0, atol=1e-12) ||
        throw(ArgumentError("thermal_nonuniform_oracle_geometry_invalid"))
    all(isfinite, q_cells) && all(>=(0.0), q_cells) ||
        throw(ArgumentError("thermal_nonuniform_oracle_source_invalid"))
    increments = Float64.(q_cells) .* Float64(h)
    unit_flux = zeros(Float64, n + 1)
    for i in 1:n
        unit_flux[i + 1] = unit_flux[i] + increments[i]
    end
    # Boundary half-cells and interior center-to-center intervals have widths
    # h/2, h, ..., h, h/2. Their weighted flux sum must give zero net ΔT.
    weighted = 0.5 * unit_flux[1] + sum(unit_flux[2:n]) + 0.5 * unit_flux[end]
    total_weight = n * h
    flux_left = -weighted / (total_weight / h)
    flux_faces = unit_flux .+ flux_left
    centers = Vector{Float64}(undef, n)
    centers[1] = Float64(t0) - flux_faces[1] * h / (2.0 * kxx)
    for i in 2:n
        centers[i] = centers[i - 1] - flux_faces[i] * h / kxx
    end
    flux_right = flux_faces[end]
    (temperature_K=Tuple(centers), flux_left_W_m2=flux_faces[1],
        flux_right_W_m2=flux_right, face_flux_W_m2=Tuple(flux_faces),
        cell_source_per_area_W_m2=Tuple(increments))
end

function _thermal_validate_source_program(input, records, g2faces, g2owners,
        chart, J, physical_lower, physical_upper;
        source_density_profile=nothing, source_density_input=nothing,
        cell_source_W_m3=nothing)
    g1, g2, spatial = input.g1, input.g2, input.spatial_case
    capability = records.capability
    law = capability.source_law
    kexpr = g1.K.expression
    xlength = Float64(physical_upper[1] - physical_lower[1])
    xorigin = Float64(physical_lower[1])
    t0_face, right_face = g2faces[:x_min], g2faces[:x_max]
    t0_face.kind === :dirichlet && right_face.kind === :dirichlet ||
        throw(ArgumentError("thermal_source_law_requires_two_dirichlet_x_faces"))
    t0 = Float64(t0_face.value)
    t_right = Float64(right_face.value)
    equal_x_faces = t0 == t_right
    q = 1.0
    kxx = Float64(kexpr.base_diag[1])
    expected_amplitude = q * xlength^2 / (2.0 * kxx)
    law.kind === :steady_planar_quadratic_diffusion_v1 &&
        law.physical_equation == "-d/dx(Kxx*du/dx)=q'''; Kxx is constant in x" &&
        law.u_formula == (equal_x_faces ?
            "u(x)=T0+(q'''/(2*Kxx))*x*(L-x)" :
            "u(x)=T_left+((T_right-T_left)/L)*x+(q'''/(2*Kxx))*x*(L-x)") &&
        law.chart_formula == (equal_x_faces ?
            "u(xi)=T0+(q'''*L^2/(2*Kxx))*xi*(1-xi)" :
            "u(xi)=T_left+(T_right-T_left)*xi+(q'''*L^2/(2*Kxx))*xi*(1-xi)") &&
        law.source_formula == "q'''(xi)=q'''" ||
        throw(ArgumentError("thermal_source_law_not_the_supported_quadratic"))
    law.chart_input_type == FusionConceptAI.chart_coordinate_type_v1() &&
        law.chart_input_unit == UnitSignature() && law.chart_ref == chart.chart_ref &&
        law.chart_hash == canonical_hash(chart) ||
        throw(ArgumentError("thermal_source_law_chart_binding_mismatch"))
    law.reference_x_domain == (Float64(chart.domain_lower[1]),
        Float64(chart.domain_upper[1])) &&
        law.reference_x_domain == (0.0, 1.0) &&
        law.physical_x_origin_m == xorigin && law.physical_x_origin_m == 0.0 &&
        law.physical_x_extent_m == xlength && law.physical_x_extent_m > 0.0 ||
        throw(ArgumentError("thermal_source_law_physical_domain_mismatch"))
    law.u_type == g1.u.physical_type && law.f_type == g1.f.physical_type &&
        law.K_type == g1.K.physical_type &&
        law.u_field_id == g1.u.field_id && law.f_field_id == g1.f.field_id &&
        law.K_type_field_id == g1.K.field_id ||
        throw(ArgumentError("thermal_source_law_g1_field_binding_mismatch"))
    law.T0_K == t0 && law.q_W_m3 == q && law.Kxx_W_mK == kxx &&
        law.L_m == xlength && law.authored_amplitude.value == expected_amplitude &&
        law.authored_amplitude.unit == _TEMP_K ||
        throw(ArgumentError("thermal_source_law_values_not_source_derived"))
    law.bindings.T0.source === :G2 &&
        law.bindings.T0.declaration_ref == records.g2_record.declaration_ref &&
        law.bindings.T0.source_ref == records.g2_record.source_ref &&
        law.bindings.T0.role === :x_min_dirichlet &&
        law.bindings.T0.face_id == g2owners[:x_min].face_id &&
        law.bindings.T0.value == t0 && law.bindings.T0.unit == _TEMP_K ||
        throw(ArgumentError("thermal_T0_binding_does_not_match_G2_face"))
    law.bindings.T_L.source === :G2 &&
        law.bindings.T_L.declaration_ref == records.g2_record.declaration_ref &&
        law.bindings.T_L.source_ref == records.g2_record.source_ref &&
        law.bindings.T_L.face_id == g2owners[:x_max].face_id &&
        law.bindings.T_L.role === :x_max_dirichlet &&
        law.bindings.T_L.value == right_face.value &&
        law.bindings.T_L.unit == _TEMP_K ||
        throw(ArgumentError("thermal_TL_binding_does_not_match_G2_face"))
    law.bindings.transverse_zero_conormal.source === :G2 &&
        law.bindings.transverse_zero_conormal.role === :zero_conormal &&
        law.bindings.transverse_zero_conormal.unit == _FLUX_W_M2 &&
        law.bindings.transverse_zero_conormal.face_ids ==
            Tuple(g2owners[name].face_id for name in (:y_min, :y_max, :z_min, :z_max)) ||
        throw(ArgumentError("thermal_transverse_binding_does_not_match_g2_faces"))
    law.bindings.q.source === :G1 &&
        law.bindings.q.field_id == g1.f.field_id &&
        law.bindings.q.grad_ref == g1.operators.grad.operator_ref &&
        law.bindings.q.k_apply_ref == g1.operators.coefficient_apply.operator_ref &&
        law.bindings.q.div_ref == g1.operators.div.operator_ref &&
        law.bindings.q.value == q && law.bindings.q.unit == _SOURCE_W_M3 ||
        throw(ArgumentError("thermal_source_binding_does_not_match_G1"))
    law.bindings.Kxx.source === :G1 &&
        law.bindings.Kxx.field_id == g1.K.field_id &&
        law.bindings.Kxx.coefficient_field_id == g1.K.field_id &&
        law.bindings.Kxx.value == kxx && iszero(kexpr.slope_diag[1]) &&
        iszero(law.bindings.Kxx.x_slope) &&
        law.bindings.Kxx.unit == _K_W_M_K ||
        throw(ArgumentError("thermal_Kxx_binding_does_not_match_G1"))
    law.bindings.L.source === :G2 &&
        law.bindings.L.declaration_ref == records.g2_record.declaration_ref &&
        law.bindings.L.source_ref == records.g2_record.source_ref &&
        law.bindings.L.chart_ref == chart.chart_ref &&
        law.bindings.L.value == xlength && law.bindings.L.unit == _COORD_M ||
        throw(ArgumentError("thermal_length_binding_does_not_match_G2"))
    hasproperty(law, :boundary_faces) && law.boundary_faces isa Tuple &&
        length(law.boundary_faces) == 6 ||
        throw(ArgumentError("thermal_source_law_does_not_bind_all_six_g2_faces"))
    actual_face_bytes = canonical_hash(Tuple(sort(collect(g2.source.faces);
        by=face -> String(face.face))))
    law_face_bytes = canonical_hash(Tuple(sort(collect(law.boundary_faces);
        by=face -> String(face.face))))
    actual_face_bytes == law_face_bytes ||
        throw(ArgumentError("thermal_source_law_faces_differ_from_actual_g2_source"))
    iszero(J[1][2]) && iszero(J[1][3]) && iszero(J[2][1]) &&
        iszero(J[2][3]) && iszero(J[3][1]) && iszero(J[3][2]) ||
        throw(ArgumentError("thermal_source_map_must_be_axis_aligned"))
    capability.program_hash == canonical_hash(capability.program) ||
        throw(ArgumentError("thermal_source_program_hash_mismatch"))
    capability.roots.u.declared_type == g1.u.physical_type &&
        capability.roots.f.declared_type == g1.f.physical_type ||
        throw(ArgumentError("thermal_source_program_root_units_mismatch"))

    edges = spatial.new_geometry.edges
    cell_centers = Tuple((Float64(edges[i]) + Float64(edges[i + 1])) / 2.0
        for i in 1:(length(edges) - 1))
    ref_y = (Float64(chart.domain_lower[2]) + Float64(chart.domain_upper[2])) / 2.0
    ref_z = (Float64(chart.domain_lower[3]) + Float64(chart.domain_upper[3])) / 2.0
    to_reference(x, offset, scale) = (Float64(x) - Float64(offset)) / Float64(scale)
    center_points = Tuple((to_reference(x, chart.offset[1], J[1][1]), ref_y, ref_z)
        for x in cell_centers)
    boundary_points = ((Float64(chart.domain_lower[1]), ref_y, ref_z),
        (Float64(chart.domain_upper[1]), ref_y, ref_z))
    u_points = (center_points..., boundary_points...)
    runtime = isdefined(Main, :FusionRuntimeV4) ?
        getfield(Main, :FusionRuntimeV4) : nothing
    runtime !== nothing &&
        isdefined(runtime, :evaluate_g1_typed_source_program_v1) ||
        throw(ArgumentError("thermal_G1_typed_source_evaluator_runtime_not_loaded"))
    evaluator = getfield(runtime, :evaluate_g1_typed_source_program_v1)
    u_result = Base.invokelatest(evaluator,
        capability, capability.roots.u, u_points)
    f_result = Base.invokelatest(evaluator,
        capability, capability.roots.f, center_points)
    for (result, root, points, expected_type, label) in (
            (u_result, capability.roots.u, u_points, g1.u.physical_type, :u),
            (f_result, capability.roots.f, center_points, g1.f.physical_type, :f))
        result.status === :ready && result.candidate_ref == input.candidate_ref &&
            result.g1_source_ref == records.g1_record.source_ref &&
            result.g1_declaration_ref == records.g1_record.declaration_ref &&
            result.g2_source_ref == records.g2_record.source_ref &&
            result.g2_declaration_ref == records.g2_record.declaration_ref &&
            result.program_hash == capability.program_hash &&
            result.root_ref == root && result.root_hash == canonical_hash(root) &&
            result.root_type == expected_type && result.chart_points == points &&
            length(result.values) == length(points) ||
            throw(ArgumentError("thermal_$(label)_evaluation_identity_mismatch"))
    end
    amplitude = Float64(law.authored_amplitude.value)
    u_centers = ntuple(i -> Float64(u_result.values[i]), length(center_points))
    f_centers = ntuple(i -> Float64(f_result.values[i]), length(center_points))
    expected_u = ntuple(i -> t0 + amplitude * center_points[i][1] *
        (1.0 - center_points[i][1]) +
        (t_right - t0) * center_points[i][1], length(center_points))
    all(isapprox(u_centers[i], expected_u[i]; atol=1e-12, rtol=0.0)
        for i in eachindex(expected_u)) ||
        throw(ArgumentError("thermal_u_ast_not_equal_to_bound_quadratic_lift"))
    Tuple(Float64.(u_result.values[length(center_points)+1:end])) == (t0, t_right) ||
        throw(ArgumentError("thermal_u_ast_does_not_match_G2_end_temperatures"))
    (source_density_profile === nothing) == (source_density_input === nothing) ||
        throw(ArgumentError("thermal_runtime_source_profile_input_pair_incomplete"))
    runtime_source_values, runtime_q = if source_density_profile === nothing
        all(==(q), f_centers) && all(==(q), spatial.field.source) ||
            throw(ArgumentError("thermal_f_ast_does_not_match_FV_source"))
        f_centers, q
    else
        all(==(q), f_centers) ||
            throw(ArgumentError("thermal_f_ast_does_not_match_pinned_G1_q0"))
        isdefined(runtime, :evaluate_g1_runtime_source_density_v1) ||
            throw(ArgumentError("thermal_G1_runtime_source_density_evaluator_not_loaded"))
        runtime_evaluation = Base.invokelatest(
            getfield(runtime, :evaluate_g1_runtime_source_density_v1),
            capability, source_density_profile, source_density_input, center_points)
        all(isfinite, runtime_evaluation.values) && length(runtime_evaluation.values) == length(f_centers) ||
            throw(ArgumentError("thermal_runtime_source_evaluation_invalid"))
        Tuple(Float64.(runtime_evaluation.values)), Float64(source_density_input.q_W_m3)
    end
    if cell_source_W_m3 === nothing
        all(==(runtime_q), spatial.field.source) &&
            Tuple(Float64.(runtime_source_values)) == Tuple(Float64.(spatial.field.source)) ||
            throw(ArgumentError("thermal_f_runtime_source_does_not_match_G1_or_FV_source"))
    else
        length(cell_source_W_m3) == length(spatial.field.source) &&
            Tuple(Float64.(cell_source_W_m3)) == Tuple(Float64.(spatial.field.source)) &&
            all(isfinite, cell_source_W_m3) && all(>=(0.0), cell_source_W_m3) &&
            isapprox(sum(Float64.(cell_source_W_m3) .* diff(Float64.(edges))),
                runtime_q * xlength; rtol=1e-10, atol=1e-12) ||
            throw(ArgumentError("thermal_cell_source_profile_power_or_shape_mismatch"))
    end
    h = Float64(edges[2]) - Float64(edges[1])
    all(isapprox(Float64(edges[i + 1] - edges[i]), h; atol=1e-12, rtol=0.0)
        for i in 1:(length(edges) - 1)) ||
        throw(ArgumentError("thermal_exact_fv_oracle_requires_uniform_cells"))
    cross_section_area = Float64((physical_upper[2] - physical_lower[2]) *
        (physical_upper[3] - physical_lower[3]))
    isfinite(cross_section_area) && cross_section_area > 0.0 ||
        throw(ArgumentError("thermal_g2_cross_section_area_invalid"))
    source_audit = (schema=capability.schema,
        g1_source_ref=records.g1_record.source_ref,
        g1_declaration_ref=records.g1_record.declaration_ref,
        g1_source_identity_hash=records.g1_record.source_identity_hash,
        g1_declaration_identity_hash=records.g1_record.declaration_identity_hash,
        g2_source_ref=records.g2_record.source_ref,
        g2_declaration_ref=records.g2_record.declaration_ref,
        g2_source_identity_hash=records.g2_record.source_identity_hash,
        g2_declaration_identity_hash=records.g2_record.declaration_identity_hash,
        capability_hash=capability.capability_hash,
        binding_hash=capability.binding_hash, program_hash=capability.program_hash,
        u_root_hash=u_result.root_hash, f_root_hash=f_result.root_hash,
        u_evaluation_hash=u_result.result_hash, f_evaluation_hash=f_result.result_hash,
        chart_points=center_points, boundary_chart_points=boundary_points,
        candidate_u_center_K=u_centers, source_W_m3=runtime_source_values,
        exact_law=(T0_K=t0, q_W_m3=q, Kxx_W_mK=kxx, L_m=xlength,
            amplitude_K=amplitude, d2u_dx2_K_m2=-2.0 * amplitude / xlength^2,
            minus_div_K_grad_W_m3=2.0 * kxx * amplitude / xlength^2,
            lateral_conormal_W_m2=0.0),
        cross_section_area_m2=cross_section_area,
        fv_uniform_spacing_m=h,
        fv_analytic_correction_K=runtime_q * h^2 / (8.0 * kxx))
    if source_density_profile !== nothing
        source_audit = merge(source_audit, (
            runtime_source_profile_hash=canonical_hash(source_density_profile),
            runtime_source_input_hash=canonical_hash(source_density_input),
            runtime_source_q_W_m3=runtime_q))
    end
    spatial_fv_oracle = nothing
    analytic_fv = if cell_source_W_m3 !== nothing
        right_face.value == t0 ||
            throw(ArgumentError("thermal_nonuniform_source_oracle_requires_equal_dirichlet_faces"))
        spatial_fv_oracle = _thermal_nonuniform_fv_flux_oracle_v1(
            Float64.(cell_source_W_m3), h, xlength, kxx, t0)
        spatial_fv_oracle.temperature_K
    elseif source_density_profile === nothing
        ntuple(i -> u_centers[i] + q * h^2 / (8.0 * kxx), length(u_centers))
    else
        ntuple(i -> t0 + (t_right - t0) * center_points[i][1] +
            runtime_q * xlength^2 / (2.0 * kxx) *
            center_points[i][1] * (1.0 - center_points[i][1]) +
            runtime_q * h^2 / (8.0 * kxx), length(u_centers))
    end
    if cell_source_W_m3 !== nothing
        source_audit = merge(source_audit, (
            spatial_source_model=:caller_declared_cell_power_distribution_with_0D_integral_binding,
            spatial_source_W_m3=Tuple(Float64.(cell_source_W_m3)),
            spatial_source_hash=canonical_hash(Tuple(Float64.(cell_source_W_m3))),
            G1_uniform_reference_q_W_m3=runtime_q,
            physical_deposition_evidence=false,
            spatial_fv_oracle=(model=:conservative_face_flux_recurrence,
                cell_width_m=h,
                cell_source_per_area_W_m2=spatial_fv_oracle.cell_source_per_area_W_m2,
                face_flux_W_m2=spatial_fv_oracle.face_flux_W_m2,
                temperature_K=spatial_fv_oracle.temperature_K)))
    end
    (source_audit=source_audit, candidate_u_center_K=u_centers,
        source_W_m3=runtime_source_values, analytic_fv_temperature_K=analytic_fv,
        cross_section_area_m2=cross_section_area)
end

"""Reject unless the real candidate inputs define this exact material slice."""
function _validate_thermal_input(input; records_checked::Bool=false,
        source_density_profile=nothing, source_density_input=nothing,
        cell_source_W_m3=nothing)
    g1, g2, spatial = input.g1, input.g2, input.spatial_case
    g1_status, g1_errors = FusionConceptAI.g1_diffusion_validate(g1)
    g1_status === :valid || throw(ArgumentError("thermal_g1_invalid:$g1_errors"))
    g2_admission = FusionConceptAI.g2mb_admit(g2.source)
    g2_admission.status in (:valid, :terminal_deferred) &&
        g2_admission.structural_status === :valid &&
        g2_admission.metric_status === :valid &&
        isempty(g2_admission.errors) &&
        g2_admission.resolution in (:resolved, :terminal_deferred) ||
        throw(ArgumentError("thermal_g2_structure_not_admissible:$(g2_admission.status)"))
    up, kp, fp = g1.u.physical_type, g1.K.physical_type, g1.f.physical_type
    up.value_kind === :scalar_field && up.tensor_rank == 0 &&
        up.spatial_dimension == 3 && up.units == _TEMP_K ||
        throw(ArgumentError("thermal_state_must_be_static_scalar_kelvin"))
    up.temporal_type == FusionConceptAI.TemporalTypeV1(FusionConceptAI.static_time) ||
        throw(ArgumentError("thermal_state_must_be_static"))
    kp.value_kind === :tensor_field && kp.tensor_rank == 2 &&
        kp.spatial_dimension == 3 && kp.units == _K_W_M_K ||
        throw(ArgumentError("thermal_conductivity_must_be_tensor_W_m_K"))
    fp.value_kind === :scalar_field && fp.tensor_rank == 0 &&
        fp.spatial_dimension == 3 && fp.units == _SOURCE_W_M3 ||
        throw(ArgumentError("thermal_source_must_be_volumetric_W_m3"))
    fp.temporal_type == FusionConceptAI.TemporalTypeV1(FusionConceptAI.static_time) ||
        throw(ArgumentError("thermal_source_must_be_static"))
    g1.operators.grad.output_type.units ==
        UnitSignature((-1, 0, 0, 0, 1, 0, 0)) ||
        throw(ArgumentError("thermal_gradient_must_be_K_per_m"))
    g1.operators.coefficient_apply.output_type.units == _FLUX_W_M2 ||
        throw(ArgumentError("thermal_flux_must_be_W_m2"))
    g1.operators.div.output_type.units == _SOURCE_W_M3 ||
        throw(ArgumentError("thermal_divergence_must_be_W_m3"))

    gu = g2.source.units
    gu.reference_coordinate == UnitSignature() && gu.coordinate == _COORD_M &&
        gu.jacobian == _COORD_M && gu.metric == _METRIC_M2 &&
        gu.area == _AREA_M2 && gu.volume == _VOLUME_M3 &&
        gu.field_value == _TEMP_K && gu.flux_value == _FLUX_W_M2 ||
        throw(ArgumentError("thermal_g2_si_units_mismatch"))
    chart = g2.source.chart_map
    chart.map_kind === :affine && chart.axes == (:x, :y, :z) ||
        throw(ArgumentError("thermal_chart_axes_or_map_kind_mismatch"))
    J = chart.jacobian_rows
    all(J[i][j] == 0 for i in 1:3 for j in 1:3 if i != j) ||
        throw(ArgumentError("thermal_chart_must_be_axis_aligned"))
    all(J[i][i] > 0 for i in 1:3) ||
        throw(ArgumentError("thermal_chart_orientation_must_be_positive"))
    xlo = chart.offset[1] + J[1][1] * chart.domain_lower[1]
    xhi = chart.offset[1] + J[1][1] * chart.domain_upper[1]
    physical_lower = ntuple(i -> chart.offset[i] + J[i][i] * chart.domain_lower[i], 3)
    physical_upper = ntuple(i -> chart.offset[i] + J[i][i] * chart.domain_upper[i], 3)
    old, new = spatial.old_geometry.edges, spatial.new_geometry.edges
    first(old) == xlo == first(new) && last(old) == xhi == last(new) ||
        throw(ArgumentError("thermal_mesh_does_not_match_g2_x_extent"))

    # The 1-D exact solution needs constant Kxx along x and zero cross terms.
    # Kyy(y) and Kzz(z) may vary because the supported candidate field is
    # independent of y/z, so those coefficients multiply zero gradients.
    # Assembly stays per square metre; the reported cross section comes from
    # the diagonal G2 chart extents and never rescales the FV matrix.
    kexpr = g1.K.expression
    iszero(kexpr.slope_diag[1]) ||
        throw(ArgumentError("thermal_Kxx_must_be_constant_for_supported_profile"))
    all(kexpr.domain_min[i] <= physical_lower[i] <= physical_upper[i] <=
        kexpr.domain_max[i] for i in 1:3) ||
        throw(ArgumentError("thermal_domain_outside_candidate_K_domain"))
    faces = Dict(f.face => f.value for f in g2.source.faces)
    face_owners = Dict(f.face => f for f in g2.source.faces)
    length(faces) == 6 || throw(ArgumentError("thermal_requires_exactly_six_g2_faces"))
    haskey(faces, :x_min) && haskey(faces, :x_max) ||
        throw(ArgumentError("thermal_x_boundary_missing"))
    for side in (:x_min, :x_max)
        f = faces[side]
        want = f.kind === :dirichlet ? _TEMP_K : _FLUX_W_M2
        f.unit == want || throw(ArgumentError("thermal_x_boundary_unit_mismatch:$side"))
    end
    for side in (:y_min, :y_max, :z_min, :z_max)
        f = faces[side]
        f.kind === :neumann && iszero(f.value) && f.unit == _FLUX_W_M2 ||
            throw(ArgumentError("thermal_transverse_face_must_be_adiabatic:$side"))
    end
    b = spatial.boundary
    left, right = faces[:x_min], faces[:x_max]
    left.kind == right.kind ||
        throw(ArgumentError("thermal_x_faces_must_use_the_same_boundary_kind"))
    b.left_kind == left.kind && Float64(left.value) == b.left_value &&
        b.right_kind == right.kind && Float64(right.value) == b.right_value ||
        throw(ArgumentError("thermal_boundary_projection_mismatch"))
    g1.f.source_expression in ("f(x)=1", "f_candidate(x)=1") ||
        throw(ArgumentError("thermal_component_supports_only_constant_declared_source"))
    length(spatial.field.k_cells) == length(new) - 1 ||
        throw(ArgumentError("thermal_mesh_cell_count_mismatch"))
    yref = (chart.domain_lower[2] + chart.domain_upper[2]) / 2
    zref = (chart.domain_lower[3] + chart.domain_upper[3]) / 2
    y = chart.offset[2] + J[2][2] * yref
    z = chart.offset[3] + J[3][3] * zref
    for i in eachindex(spatial.field.k_cells)
        x = (new[i] + new[i+1]) / 2
        K = FusionConceptAI.g1_diffusion_k_eval(kexpr, (x, y, z))
        Float64(K[1][1]) == spatial.field.k_cells[i] ||
            throw(ArgumentError("thermal_conductivity_values_do_not_match_candidate_K:$i"))
    end
    records = _thermal_source_capability(input; records_checked=records_checked)
    source_audit = _thermal_validate_source_program(input, records, faces,
        face_owners, chart, J, physical_lower, physical_upper;
        source_density_profile=source_density_profile,
        source_density_input=source_density_input,
        cell_source_W_m3=cell_source_W_m3)
    (admission=g2_admission, source_audit=source_audit.source_audit,
        candidate_u_center_K=source_audit.candidate_u_center_K,
        source_W_m3=source_audit.source_W_m3,
        analytic_fv_temperature_K=source_audit.analytic_fv_temperature_K,
        cross_section_area_m2=source_audit.cross_section_area_m2)
end

"""Check that the typed port edges do not rescale/replace the thermal inputs."""
function _validate_thermal_component_edges(input, edges, g2faces)
    spatial = input.spatial_case
    length(edges) == 3 && Set(edge.account for edge in edges) ==
        Set(("source", "boundary", "field")) ||
        throw(ArgumentError("thermal_requires_exact_source_boundary_field_edges"))
    all(edge -> edge.producer.magnitude == 1.0 &&
        edge.consumer.magnitude == 1.0, edges) ||
        throw(ArgumentError("thermal_typed_edge_magnitude_must_be_one"))
    source_edge = only(Tuple(edge for edge in edges if edge.account == "source"))
    boundary_edge = only(Tuple(edge for edge in edges if edge.account == "boundary"))
    field_edge = only(Tuple(edge for edge in edges if edge.account == "field"))
    xkind = g2faces[:x_min].kind
    boundary_contract = xkind === :dirichlet ?
        (quantity=:field, unit="K", role=:boundary) :
        (quantity=:flux, unit="W/m^2", role=:boundary)
    expected = Dict("source" => (quantity=:source, unit="W/m^3", role=:source),
        "boundary" => boundary_contract,
        "field" => (quantity=:field, unit="K", role=:field))
    for edge in edges
        contract = expected[edge.account]
        producer, consumer = edge.producer, edge.consumer
        producer.direction === :output && consumer.direction === :input &&
            producer.account == edge.account == consumer.account &&
            producer.quantity === contract.quantity &&
            consumer.quantity === contract.quantity &&
            producer.unit == contract.unit && consumer.unit == contract.unit &&
            producer.role === contract.role && consumer.role === contract.role &&
            producer.ledger_sign == 1 && consumer.ledger_sign == -1 ||
            throw(ArgumentError("thermal_typed_edge_semantic_signature_mismatch:$(edge.account)"))
    end
    source_payload = try
        Tuple(Float64.(collect(source_edge.producer.payload)))
    catch
        throw(ArgumentError("thermal_source_edge_payload_malformed"))
    end
    source_payload == Tuple(Float64.(spatial.field.source)) ||
        throw(ArgumentError("thermal_source_edge_payload_mismatch"))
    boundary_payload = try
        p = boundary_edge.producer.payload
        p isa Tuple && length(p) == 2 || throw(ArgumentError("bad_boundary_payload"))
        Tuple(Float64.(p))
    catch
        throw(ArgumentError("thermal_boundary_edge_payload_malformed"))
    end
    expected_g2_boundary = (Float64(g2faces[:x_min].value),
        Float64(g2faces[:x_max].value))
    boundary_payload == expected_g2_boundary ||
        throw(ArgumentError("thermal_boundary_edge_payload_mismatch"))
    boundary_payload == (Float64(spatial.boundary.left_value),
        Float64(spatial.boundary.right_value)) ||
        throw(ArgumentError("thermal_boundary_edge_differs_from_fv_boundary"))
    field_edge.producer.payload === nothing ||
        throw(ArgumentError("thermal_field_edge_cannot_override_candidate_field"))
    edge_hash = canonical_hash(Tuple(sort([(
        account=edge.account,
        quantity=edge.quantity, unit=edge.unit,
        producer=(direction=edge.producer.direction, account=edge.producer.account,
            quantity=edge.producer.quantity, unit=edge.producer.unit,
            role=edge.producer.role, ledger_sign=edge.producer.ledger_sign,
            magnitude=edge.producer.magnitude, payload=edge.producer.payload),
        consumer=(direction=edge.consumer.direction, account=edge.consumer.account,
            quantity=edge.consumer.quantity, unit=edge.consumer.unit,
            role=edge.consumer.role, ledger_sign=edge.consumer.ledger_sign,
            magnitude=edge.consumer.magnitude, payload=edge.consumer.payload))
        for edge in edges], by=repr)))
    (edge_hash=edge_hash, accounts=("boundary", "field", "source"),
        source_payload=source_payload, boundary_payload=boundary_payload,
        producer_magnitudes=(source=source_edge.producer.magnitude,
            boundary=boundary_edge.producer.magnitude,
            field=field_edge.producer.magnitude),
        expected_semantic_signatures=(source=expected["source"],
            boundary=expected["boundary"], field=expected["field"]),
        semantic_signatures=(source=(source_edge.producer.quantity,
                source_edge.producer.unit, source_edge.producer.role),
            boundary=(boundary_edge.producer.quantity,
                boundary_edge.producer.unit, boundary_edge.producer.role),
            field=(field_edge.producer.quantity, field_edge.producer.unit,
                field_edge.producer.role)))
end

"""Run the existing 1-D FV consumer with candidate declarations as authority.

The baseline DCCE endpoint also runs its separate manufactured two-DOF DGD
control lane. This component endpoint deliberately omits that lane and calls
the already-existing candidate composition, state-transfer, FV assembly, and
linear-solve routines directly after the component-specific checks above.
"""
# Memoize only the four exact, deeply immutable AST programs carried by the
# candidate's current G1 T0 record. Carrier probing is opportunistic: any shape
# mismatch falls back to the original consumer path, where validation and error
# ordering remain authoritative.
function _thermal_g1_ast_payload_targets_v1(bundle)
    try
        g1_records = Tuple(record for record in bundle.declarations
            if record isa FusionConceptAI.VNextT0LocalPresentDeclarationV1 &&
                record.layer === :G1)
        length(g1_records) == 1 || return nothing
        body = only(g1_records).semantic_body.body
        hasproperty(body, :value) &&
            hasproperty(body.value, :g1_typed_source_field_program) || return nothing
        capability = body.value.g1_typed_source_field_program
        hasproperty(capability, :program) || return nothing
        programs = capability.program
        programs isa NamedTuple &&
            keys(programs) === (:x_coordinate, :x_bubble, :u, :f) || return nothing
        asts = Tuple(stage.ast for stage in values(programs)
            if hasproperty(stage, :ast))
        length(asts) == 4 &&
            all(ast -> ast isa FusionConceptAI.TypedASTProgramV1, asts) ||
            return nothing
        asts
    catch err
        err isa InterruptException && rethrow()
        nothing
    end
end

function _execute_steady_planar_thermal_diffusion_v1(candidate, g1, g2, g3,
        bundle, spatial_case; source_feedback=nothing, candidate_source_density=nothing,
        cell_source_W_m3=nothing)
    stage_asts = _thermal_g1_ast_payload_targets_v1(bundle)
    run_consumer() = _execute_steady_planar_thermal_diffusion_v1_uncached(
        candidate, g1, g2, g3, bundle, spatial_case;
        source_feedback=source_feedback,
        candidate_source_density=candidate_source_density,
        cell_source_W_m3=cell_source_W_m3)
    stage_asts === nothing && return run_consumer()
    FusionConceptAI._with_canonical_json_memo(stage_asts;
            payload_targets=stage_asts) do
        run_consumer()
    end
end

function _execute_steady_planar_thermal_diffusion_v1_uncached(candidate, g1, g2, g3,
        bundle, spatial_case; source_feedback=nothing, candidate_source_density=nothing,
        cell_source_W_m3=nothing)
    (source_feedback === nothing || candidate_source_density === nothing) ||
        throw(ArgumentError("thermal_source_feedback_paths_are_mutually_exclusive"))
    source_density_profile = source_feedback !== nothing ? source_feedback.g1_profile :
        candidate_source_density === nothing ? nothing : candidate_source_density.g1_profile
    source_density_input = source_feedback !== nothing ? source_feedback.g1_input :
        candidate_source_density === nothing ? nothing : candidate_source_density.g1_input
    input = FusionConceptAI.dcce_input_v1(candidate, g1, g2, g3, bundle,
        spatial_case)
    compile = FusionConceptAI.dgd_compile_v1(
        FusionConceptAI.DeclaredG123InputV1(candidate, g1, g2, g3, bundle,
            FusionConceptAI.DeclaredG123HashSetV1(candidate,
                input.hashes.g1_body_hash, input.hashes.g2_body_hash,
                input.hashes.g3_body_hash, input.hashes.bundle_hash)))
    # This component has its own source-authoritative TypedAST/PDE gate below.
    # Preserve the old string compiler unchanged and report its result only as
    # a diagnostic; its deferral does not establish this component's readiness.
    # dcce_input_v1 returns only after its full DGD record-integrity validation.
    thermal_validation = _validate_thermal_input(input; records_checked=true,
        source_density_profile=source_density_profile,
        source_density_input=source_density_input,
        cell_source_W_m3=cell_source_W_m3)
    if source_feedback !== nothing
        expected_feedback = thermal_temperature_source_density_input_v1(input,
            source_feedback.temperature_K)
        source_feedback.g3_source_profile_hash ==
            expected_feedback.g3_source_profile_hash &&
            source_feedback.g3_source_record_hash ==
            expected_feedback.g3_source_record_hash &&
            canonical_hash(source_feedback.g1_profile) ==
            canonical_hash(expected_feedback.g1_profile) &&
            canonical_hash(source_feedback.g1_input) ==
            canonical_hash(expected_feedback.g1_input) &&
            source_feedback.q_W_m3 == expected_feedback.q_W_m3 &&
            source_feedback.actuator_fraction == expected_feedback.actuator_fraction &&
            source_feedback.resource_link_id == expected_feedback.resource_link_id &&
            source_feedback.resource_port_id == expected_feedback.resource_port_id ||
            throw(ArgumentError("thermal_runtime_feedback_does_not_rebuild_from_G3_source"))
    end
    g2_admission = thermal_validation.admission
    lowering = FusionConceptAI.dcce_typed_lower_v1(input)
    plan = FusionConceptAI.dcce_composition_plan_v1(input)
    plan.status === :ready || throw(ArgumentError("thermal_composition_not_ready:$(plan.code)"))
    edge_audit = _validate_thermal_component_edges(input, plan.edges,
        Dict(face.face => face.value for face in g2.source.faces))
    dgd_input = FusionConceptAI.DeclaredG123InputV1(candidate, g1, g2, g3,
        bundle, FusionConceptAI.DeclaredG123HashSetV1(candidate,
            input.hashes.g1_body_hash, input.hashes.g2_body_hash,
            input.hashes.g3_body_hash, input.hashes.bundle_hash))
    authority = FusionConceptAI.dgd_composition_admit_v1(dgd_input)
    authority.status in (:ready, :terminal_deferred) ||
        throw(ArgumentError("thermal_composition_structure_not_admissible:$(authority.status)"))
    transfer = FusionConceptAI.measure_overlap_transfer(spatial_case.old_geometry,
        spatial_case.new_geometry, spatial_case.old_state)
    transfer.valid || throw(ArgumentError("thermal_state_transfer_not_ready:$(transfer.code)"))
    assembled = FusionConceptAI.assemble_declared_spatial_fv(
        spatial_case.new_geometry, spatial_case.field, spatial_case.boundary;
        edges=plan.edges)
    assembled.valid || throw(ArgumentError("thermal_assembly_not_ready:$(assembled.code)"))
    b = spatial_case.boundary
    b.left_kind === :neumann && b.right_kind === :neumann &&
        throw(ArgumentError("thermal_pure_neumann_nullspace_deferred"))
    # Recenter the same finite-volume equation on the left Dirichlet value.
    # This avoids recovering a sub-kelvin rise by subtracting two ~300 K values.
    t0 = Float64(b.left_value)
    cell_widths = diff(Float64.(collect(spatial_case.new_geometry.edges)))
    temperature_rise_rhs = Float64.(spatial_case.field.source) .* cell_widths
    temperature_rise_rhs[end] +=
        assembled.assembly.face_transmissibility[end] *
        (Float64(b.right_value) - t0)
    temperature_rise, residual, solve_code = FusionConceptAI._dsc_solve(
        assembled.assembly.matrix, temperature_rise_rhs)
    solve_code === :joint_linear_solved && isfinite(residual) && residual <= 1e-12 ||
        throw(ArgumentError("thermal_fv_solve_failed:$solve_code"))
    solution = temperature_rise .+ t0
    all(isapprox(Float64(solution[i]),
        thermal_validation.analytic_fv_temperature_K[i]; atol=1e-10, rtol=0.0)
        for i in eachindex(solution)) ||
        throw(ArgumentError("thermal_fv_solution_differs_from_closed_form_oracle"))
    h = Float64(spatial_case.new_geometry.edges[2] -
        spatial_case.new_geometry.edges[1])
    kxx = Float64(g1.K.expression.base_diag[1])
    source_cells = Float64.(spatial_case.field.source)
    q = cell_source_W_m3 === nothing ? only(unique(source_cells)) :
        sum(source_cells .* cell_widths) / sum(cell_widths)
    t_right = Float64(b.right_value)
    boundary_temperature_rise = t_right - t0
    slab_length_m = Float64(last(spatial_case.new_geometry.edges) -
        first(spatial_case.new_geometry.edges))
    left_fourier_flux = kxx * Float64(temperature_rise[1]) / (h / 2.0)
    right_fourier_flux = kxx *
        (Float64(temperature_rise[end]) - boundary_temperature_rise) / (h / 2.0)
    if cell_source_W_m3 === nothing
        expected_source_flux = q * slab_length_m / 2.0
        expected_boundary_gradient_flux = kxx * boundary_temperature_rise / slab_length_m
        isapprox(left_fourier_flux,
            expected_source_flux + expected_boundary_gradient_flux;
            atol=1e-10, rtol=0.0) &&
            isapprox(right_fourier_flux,
            expected_source_flux - expected_boundary_gradient_flux;
            atol=1e-10, rtol=0.0) ||
            throw(ArgumentError("thermal_end_fourier_flux_energy_balance_failed"))
    else
        oracle = _thermal_nonuniform_fv_flux_oracle_v1(source_cells, h,
            Float64(last(spatial_case.new_geometry.edges) -
                first(spatial_case.new_geometry.edges)), kxx, t0)
        isapprox(left_fourier_flux, -oracle.flux_left_W_m2; atol=1e-10, rtol=0.0) &&
            isapprox(right_fourier_flux, oracle.flux_right_W_m2; atol=1e-10, rtol=0.0) ||
            throw(ArgumentError("thermal_nonuniform_boundary_flux_oracle_mismatch"))
    end
    # Source density is kg/(m*s^3); integrating over the G2 volume gives kg*m^2/s^3.
    watt = UnitSignature((2, 1, -3, 0, 0, 0, 0))
    source_power_W = cell_source_W_m3 === nothing ?
        q * slab_length_m * thermal_validation.cross_section_area_m2 :
        sum(source_cells .* cell_widths) * thermal_validation.cross_section_area_m2
    left_power_W = left_fourier_flux * thermal_validation.cross_section_area_m2
    right_power_W = right_fourier_flux * thermal_validation.cross_section_area_m2
    outward_boundary_power_W = left_power_W + right_power_W
    energy_balance_residual_W = source_power_W - outward_boundary_power_W
    isapprox(energy_balance_residual_W, 0.0; atol=1e-10, rtol=0.0) ||
        throw(ArgumentError("thermal_integrated_source_outflow_balance_failed"))
    x_min_owner = only(filter(face -> face.face === :x_min, g2.source.faces))
    x_max_owner = only(filter(face -> face.face === :x_max, g2.source.faces))
    heat_power_balance = (
        schema="fusionconceptai:runtime-v4:steady-planar-heat-power-balance-v1",
        candidate_ref=candidate,
        g1_body_hash=input.hashes.g1_body_hash,
        g2_body_hash=input.hashes.g2_body_hash,
        g2_chart_hash=canonical_hash(g2.source.chart_map),
        unit=watt,
        generated_source=FusionConceptAI.MetricWithUnit(:generated_source_power,
            source_power_W, watt),
        outward_boundary_power=FusionConceptAI.MetricWithUnit(
            :outward_boundary_power, outward_boundary_power_W, watt),
        balance_residual=FusionConceptAI.MetricWithUnit(
            :source_minus_boundary_outflow, energy_balance_residual_W, watt),
        terms=(
            (term=:volumetric_source, ledger_sign=1,
                power=FusionConceptAI.MetricWithUnit(:source_power, source_power_W, watt),
                source_ref=g1.source_ref, source_hash=input.hashes.g1_body_hash,
                support_hash=canonical_hash(g2.source.chart_map)),
            (term=:outward_boundary_x_min, ledger_sign=-1,
                power=FusionConceptAI.MetricWithUnit(:x_min_outward_power,
                    left_power_W, watt), face=x_min_owner.face,
                face_id=x_min_owner.face_id, owner_region_id=x_min_owner.owner_region_id,
                ownership=x_min_owner.ownership),
            (term=:outward_boundary_x_max, ledger_sign=-1,
                power=FusionConceptAI.MetricWithUnit(:x_max_outward_power,
                    right_power_W, watt), face=x_max_owner.face,
                face_id=x_max_owner.face_id, owner_region_id=x_max_owner.owner_region_id,
                ownership=x_max_owner.ownership)))
    body = (schema="fusionconceptai:runtime-v4:steady-planar-thermal-diffusion-v1",
        status=:screen_only, accepted=false,
        candidate_ref=candidate, source_bundle_hash=input.hashes.bundle_hash,
        g1_body_hash=input.hashes.g1_body_hash, g2_body_hash=input.hashes.g2_body_hash,
        g3_body_hash=input.hashes.g3_body_hash,
        g2_admission_status=g2_admission.status,
        g2_admission_resolution=g2_admission.resolution,
        g2_admission_gaps=g2_admission.gaps,
        g123_composition_admission_status=authority.status,
        g123_composition_admission_code=authority.code,
        composition_edge_audit=edge_audit,
        legacy_dgd_compile_status=compile.status,
        legacy_dgd_compile_code=compile.code,
        legacy_dcce_lowering_status=lowering.status,
        legacy_dcce_lowering_code=lowering.code,
        typed_source_program_status=:ready,
        typed_source_program_code=:candidate_bound_ast_and_component_pde_checks_passed,
        source_program_audit=thermal_validation.source_audit,
        candidate_temperature_at_cell_centers_K=thermal_validation.candidate_u_center_K,
        fv_closed_form_temperature_K=thermal_validation.analytic_fv_temperature_K,
        fv_solution_minus_candidate_temperature_K=Tuple(Float64(solution[i]) -
            thermal_validation.candidate_u_center_K[i] for i in eachindex(solution)),
        spatial_case_hash=canonical_hash((geometry=spatial_case.new_geometry,
            field=spatial_case.field, boundary=spatial_case.boundary,
            composition=spatial_case.composition)),
        model_scope=:steady_planar_wall_per_unit_area,
        equation=:minus_div_K_grad_equals_source,
        cross_section_area_m2=thermal_validation.cross_section_area_m2,
        temperature_K=Tuple(solution),
        temperature_reference_K=t0, temperature_rise_K=Tuple(temperature_rise),
        residual_coordinates=:temperature_rise,
        coordinate_m=Tuple(spatial_case.new_geometry.edges),
        volume_source_W_m3=Tuple(spatial_case.field.source),
        conductivity_W_mK=Tuple(spatial_case.field.k_cells),
        outward_fourier_flux_left_W_m2=left_fourier_flux,
        outward_fourier_flux_right_W_m2=right_fourier_flux,
        outward_heat_power_left_W=left_power_W,
        outward_heat_power_right_W=right_power_W,
        outward_boundary_heat_loss_W=outward_boundary_power_W,
        energy_balance_residual_W=energy_balance_residual_W,
        heat_power_balance=heat_power_balance,
        fv_discretization_correction_K=cell_source_W_m3 === nothing ?
            q * h^2 / (8.0 * kxx) :
            Tuple(qi * h^2 / (8.0 * kxx) for qi in source_cells),
        integrated_source_per_area_W_m2=q * slab_length_m,
        integrated_source_W=source_power_W,
        residual_norm=residual, assembly_hash=assembled.assembly.assembly_hash,
        state_transfer_hash=transfer.transfer.transfer_hash,
        dgd_mms_solver_calls=0, physical_validation=false,
        engineering_validation=false, evidence_credit=0, claim_ceiling=:screen_only)
    merge(body, (result_hash=canonical_hash(body),))
end

function execute_steady_planar_thermal_diffusion_v1(candidate, g1, g2, g3,
        bundle, spatial_case)
    _execute_steady_planar_thermal_diffusion_v1(candidate, g1, g2, g3,
        bundle, spatial_case)
end

"""Route an explicit candidate-authored 0D D-T screen into the real slab RHS.

The spec is a candidate-local NamedTuple with schema
`candidate-dt-to-thermal-source-v1`, candidate_ref, plasma_region_id,
thermal_region_id, plasma_input, wall_transfer_fraction, wall_volume_m3,
q_bounds_W_m3, and parameter_id. Set wall_volume_m3 to `nothing` to derive
that volume from the authoritative G2 chart; a supplied typed value is still
checked against the chart. It states a uniform transfer assumption; it does
not supply plasma transport, measured deposition, or physical evidence.
"""
function _thermal_g2_physical_volume_m3_v1(chart)
    chart.map_kind === :affine && chart.axes == (:x, :y, :z) ||
        throw(ArgumentError("dt_thermal_g2_chart_kind_or_axes_invalid"))
    J = chart.jacobian_rows
    all(J[i][j] == 0 for i in 1:3 for j in 1:3 if i != j) ||
        throw(ArgumentError("dt_thermal_g2_chart_must_be_axis_aligned"))
    all(J[i][i] > 0 for i in 1:3) ||
        throw(ArgumentError("dt_thermal_g2_chart_orientation_must_be_positive"))
    physical_spans = ntuple(i -> Float64(J[i][i]) *
        (Float64(chart.domain_upper[i]) - Float64(chart.domain_lower[i])), 3)
    all(isfinite, physical_spans) && all(v -> v > 0.0, physical_spans) ||
        throw(ArgumentError("dt_thermal_g2_physical_spans_invalid"))
    volume = prod(physical_spans)
    isfinite(volume) && volume > 0.0 ||
        throw(ArgumentError("dt_thermal_g2_physical_volume_invalid"))
    volume
end

function _dt_thermal_exact_gene_bound(value, field::String)
    if typeof(value) !== Float64
        return invoke(FusionConceptAI._gene_rational, Tuple{Any,Any}, value, field)
    end
    isfinite(value) || throw(ArgumentError("$field must be finite"))
    exact = rationalize(BigInt, value; tol=zero(value))
    numerator_exact, denominator_exact = numerator(exact), denominator(exact)
    typemin(Int64) <= numerator_exact <= typemax(Int64) &&
        1 <= denominator_exact <= typemax(Int64) ||
        throw(ArgumentError("$field has no exact Rational{Int64} representation"))
    bound = Rational{Int64}(Int64(numerator_exact), Int64(denominator_exact))
    Float64(bound) == value ||
        throw(ArgumentError("$field does not round-trip exactly through Rational{Int64}"))
    bound
end

function execute_steady_planar_dt_screen_thermal_v1(candidate, g1, g2, g3,
        bundle, spatial_case, spec; source_mode::Symbol=:instantaneous,
        deposited_power=nothing, providers=nothing)
    source_mode in (:instantaneous, :composition_interval_average) ||
        throw(ArgumentError("dt_thermal_source_mode_unsupported"))
    required = (:schema, :candidate_ref, :plasma_region_id, :thermal_region_id,
        :plasma_input, :wall_transfer_fraction, :wall_volume_m3,
        :q_bounds_W_m3, :parameter_id)
    spec isa NamedTuple && keys(spec) == required &&
        spec.schema == "candidate-dt-to-thermal-source-v1" ||
        throw(ArgumentError("dt_thermal_candidate_spec_shape_or_schema_invalid"))
    candidate_input = FusionConceptAI.dcce_input_v1(candidate, g1, g2, g3,
        bundle, spatial_case)
    spec.candidate_ref == candidate_input.candidate_ref ||
        throw(ArgumentError("dt_thermal_candidate_identity_mismatch"))
    (spec.plasma_region_id isa String && !isempty(spec.plasma_region_id) &&
        spec.thermal_region_id isa String && !isempty(spec.thermal_region_id)) ||
        throw(ArgumentError("dt_thermal_region_identity_empty"))
    spec.plasma_region_id != spec.thermal_region_id ||
        throw(ArgumentError("dt_thermal_region_ids_must_be_distinct"))
    runtime = isdefined(Main, :FusionRuntimeV4) ? Main.FusionRuntimeV4 : nothing
    provider_function = source_mode === :instantaneous ?
        :evaluate_dt_fusion_reactivity_v1 : :evolve_dt_fusion_composition_v1
    runtime !== nothing && isdefined(runtime, :DTFusionReactivityInputV1) &&
        isdefined(runtime, :DTFusionQuantityV1) &&
        isdefined(runtime, provider_function) ||
        throw(ArgumentError("dt_thermal_runtime_api_not_loaded"))
    isa(spec.plasma_input, getfield(runtime, :DTFusionReactivityInputV1)) ||
        throw(ArgumentError("dt_thermal_plasma_input_not_typed"))
    qtype = getfield(runtime, :DTFusionQuantityV1)
    isa(spec.wall_transfer_fraction, qtype) &&
        (spec.wall_volume_m3 === nothing || isa(spec.wall_volume_m3, qtype)) &&
        spec.q_bounds_W_m3 isa Tuple && length(spec.q_bounds_W_m3) == 2 &&
        all(q -> isa(q, qtype), spec.q_bounds_W_m3) ||
        throw(ArgumentError("dt_thermal_transfer_or_wall_quantity_not_typed"))
    fraction, wall_volume = spec.wall_transfer_fraction, spec.wall_volume_m3
    qlo, qhi = spec.q_bounds_W_m3
    fraction.unit == :one && fraction.dimension == UnitSignature() &&
        isfinite(fraction.value) && 0.0 <= fraction.value <= 1.0 ||
        throw(ArgumentError("dt_thermal_wall_transfer_fraction_invalid"))
    if wall_volume !== nothing
        wall_volume.unit == :m3 && wall_volume.dimension == _VOLUME_M3 &&
            isfinite(wall_volume.value) && wall_volume.value > 0.0 ||
            throw(ArgumentError("dt_thermal_wall_volume_invalid"))
    end
    all(q -> q.unit == :W_m3 && q.dimension == _SOURCE_W_M3 &&
        isfinite(q.value), (qlo, qhi)) && 0.0 <= qlo.value < qhi.value ||
        throw(ArgumentError("dt_thermal_wall_source_bounds_invalid"))
    spec.parameter_id isa String && !isempty(spec.parameter_id) ||
        throw(ArgumentError("dt_thermal_parameter_id_invalid"))
    records = _thermal_source_capability(candidate_input)
    capability = records.capability
    capability.candidate_ref == candidate_input.candidate_ref &&
        capability.g1_source_ref == records.g1_record.source_ref &&
        capability.g2_source_ref == records.g2_record.source_ref ||
        throw(ArgumentError("dt_thermal_g1_g2_identity_mismatch"))
    x_min = only(filter(face -> face.face === :x_min, g2.source.faces))
    x_max = only(filter(face -> face.face === :x_max, g2.source.faces))
    x_min.owner_region_id == spec.thermal_region_id == x_max.owner_region_id ||
        throw(ArgumentError("dt_thermal_g2_region_identity_mismatch"))
    chart = g2.source.chart_map
    actual_wall_volume = _thermal_g2_physical_volume_m3_v1(chart)
    isfinite(actual_wall_volume) && actual_wall_volume > 0.0 &&
        (wall_volume === nothing ||
            isapprox(Float64(wall_volume.value), actual_wall_volume; rtol=1e-10, atol=0.0)) ||
        throw(ArgumentError("dt_thermal_declared_wall_volume_differs_from_g2_geometry"))
    plasma_volume = spec.plasma_input.volume_m3
    plasma_volume.unit == :m3 && plasma_volume.dimension == _VOLUME_M3 &&
        isfinite(plasma_volume.value) && plasma_volume.value > 0.0 ||
        throw(ArgumentError("dt_thermal_plasma_volume_invalid"))
    source = Base.invokelatest(getfield(runtime, provider_function),
        spec.plasma_input; providers=providers)
    if source.status === :typed_absent &&
            source.reason === :provider_match_not_unique &&
            source.provider_match_status === runtime.no_match
        required_capability = Base.invokelatest(
            getfield(runtime, :dt_fusion_reactivity_capability_v1))
        capability_identity = string(required_capability.schema, "@",
            required_capability.revision, "/", required_capability.kind, "/",
            required_capability.operator, "/", canonical_hash(required_capability))
        throw(ArgumentError("dt_thermal_required_provider_missing:no_match:" *
            capability_identity))
    end
    if source_mode === :instantaneous
        source.status === :screen_only && hasproperty(source, :net_thermal_source_W_m3) &&
            source.claim_ceiling == runtime.screen_only &&
            source.candidate_bound === false && source.physical_evidence === false ||
            throw(ArgumentError("dt_thermal_provider_not_screen_only_or_not_evaluated"))
        net_source_W_m3 = Float64(source.net_thermal_source_W_m3)
    else
        source.status === :screen_only &&
            source.reason === :explicit_homogeneous_0d_composition_evolved &&
            hasproperty(source, :net_thermal_source_energy_density_J_m3) &&
            hasproperty(source, :output_units) &&
            source.output_units.fusion_energy_density == UnitSignature((-1, 1, -2, 0, 0, 0, 0)) &&
            source.input == getfield(runtime, :semantic_view)(spec.plasma_input) &&
            source.claim_ceiling == runtime.screen_only &&
            source.candidate_bound === false && source.physical_evidence === false ||
            throw(ArgumentError("dt_thermal_composition_provider_not_screen_only_or_not_evaluated"))
        interval = spec.plasma_input.interval_s
        interval.unit == :s && interval.dimension == UnitSignature((0, 0, 1, 0, 0, 0, 0)) &&
            isfinite(interval.value) && interval.value > 0.0 ||
            throw(ArgumentError("dt_thermal_composition_interval_must_be_positive_seconds"))
        # Interval-average forcing for the steady FV response; this does not
        # evolve the slab temperature or claim a transient thermal solution.
        net_source_W_m3 = Float64(source.net_thermal_source_energy_density_J_m3) /
            Float64(interval.value)
    end
    # This consumer has no sink/removal path, so reject net cooling before
    # multiplying by a possibly zero transfer fraction (which could yield -0.0).
    isfinite(net_source_W_m3) && net_source_W_m3 >= 0.0 ||
        throw(ArgumentError("dt_thermal_net_source_must_be_finite_nonnegative"))
    # Replace the slab RHS with the explicit transferred source. Do not add it
    # to the fixture source and do not route it through G3 temperature feedback.
    transferred_power_W = net_source_W_m3 * Float64(plasma_volume.value) *
        Float64(fraction.value)
    q_wall = transferred_power_W / actual_wall_volume
    isfinite(q_wall) && qlo.value <= q_wall <= qhi.value ||
        throw(ArgumentError("dt_thermal_transferred_q_outside_candidate_bounds"))
    parameter_ref = FusionConceptAI.FieldParameterRefV1(spec.parameter_id)
    profile = Base.invokelatest(
        getfield(runtime, :g1_runtime_source_density_parameter_v1), capability;
        parameter_ref=parameter_ref,
        q_bounds_W_m3=(Float64(qlo.value), Float64(qhi.value)))
    profile.q_min_W_m3 <= q_wall <= profile.q_max_W_m3 ||
        throw(ArgumentError("dt_thermal_transferred_q_outside_g1_runtime_bounds"))
    bounds = FusionConceptAI.QuantityIntervalV1(
        FusionConceptAI.ExactFiniteIntervalV1(
            _dt_thermal_exact_gene_bound(qlo.value, "interval lower bound"),
            _dt_thermal_exact_gene_bound(qhi.value, "interval upper bound"), false),
        _SOURCE_W_M3)
    normalized = 2.0 * (q_wall - Float64(qlo.value)) /
        Float64(qhi.value - qlo.value) - 1.0
    parameter = FusionConceptAI.FieldParameterGeneV1(parameter_ref, _SOURCE_W_M3,
        FusionConceptAI.ParameterTransformSpecV1(FusionConceptAI.transform_linear),
        bounds, normalized)
    runtime_input = Base.invokelatest(
        getfield(runtime, :g1_runtime_source_density_input_v1), profile, parameter)
    cell_source_W_m3 = nothing
    spatial_source_contract = nothing
    if deposited_power !== nothing
        required_deposition_keys = (:schema, :candidate_ref, :g2_chart_hash,
            :cell_edges_m, :deposited_power_W, :unit)
        deposited_power isa NamedTuple && keys(deposited_power) == required_deposition_keys &&
            deposited_power.schema == "caller-declared-cell-power-distribution-0d-integral-v1" &&
            deposited_power.candidate_ref == candidate_input.candidate_ref &&
            deposited_power.g2_chart_hash == canonical_hash(chart) &&
            deposited_power.unit === :W ||
            throw(ArgumentError("dt_thermal_deposition_identity_or_schema_mismatch"))
        edges_m = Tuple(Float64.(spatial_case.new_geometry.edges))
        Tuple(Float64.(deposited_power.cell_edges_m)) == edges_m ||
            throw(ArgumentError("dt_thermal_deposition_cell_edges_mismatch"))
        powers_W = Tuple(Float64.(deposited_power.deposited_power_W))
        length(powers_W) == length(edges_m) - 1 && all(isfinite, powers_W) &&
            all(>=(0.0), powers_W) ||
            throw(ArgumentError("dt_thermal_deposition_cell_power_invalid"))
        isapprox(sum(powers_W), transferred_power_W; rtol=1e-10, atol=1e-12) ||
            throw(ArgumentError("dt_thermal_deposition_does_not_match_transferred_power"))
        widths_m = diff(collect(edges_m))
        cell_volumes_m3 = widths_m .* (actual_wall_volume /
            (last(edges_m) - first(edges_m)))
        cell_source_W_m3 = Tuple(powers_W[i] / cell_volumes_m3[i]
            for i in eachindex(powers_W))
        all(isfinite, cell_source_W_m3) && all(>=(0.0), cell_source_W_m3) ||
            throw(ArgumentError("dt_thermal_deposition_density_invalid"))
        spatial_source_contract = (schema=deposited_power.schema,
            scope=:caller_declared_cell_power_distribution_with_0D_integral_binding,
            physical_deposition_evidence=false,
            input_hash=canonical_hash(deposited_power),
            candidate_ref=deposited_power.candidate_ref,
            g2_chart_hash=deposited_power.g2_chart_hash,
            cell_edges_m=edges_m, cell_volumes_m3=Tuple(cell_volumes_m3),
            deposited_power_W=powers_W, cell_source_W_m3=cell_source_W_m3,
            total_deposited_power_W=sum(powers_W),
            uniform_G1_reference_q_W_m3=q_wall)
    end
    reference_y = (Float64(chart.domain_lower[2]) +
        Float64(chart.domain_upper[2])) / 2.0
    reference_z = (Float64(chart.domain_lower[3]) +
        Float64(chart.domain_upper[3])) / 2.0
    points = Tuple((((Float64(spatial_case.new_geometry.edges[i]) +
        Float64(spatial_case.new_geometry.edges[i + 1])) / 2.0 -
        Float64(chart.offset[1])) / Float64(chart.jacobian_rows[1][1]),
        reference_y, reference_z)
        for i in 1:(length(spatial_case.new_geometry.edges) - 1))
    evaluated = Base.invokelatest(getfield(runtime,
        :evaluate_g1_runtime_source_density_v1), capability, profile,
        runtime_input, points)
    all(isapprox(Float64(v), q_wall; rtol=0.0, atol=8eps(max(abs(q_wall), 1.0)))
        for v in evaluated.values) ||
        throw(ArgumentError("dt_thermal_typed_g1_values_differ_from_provider_rhs"))
    runtime_q = Float64(runtime_input.q_W_m3)
    all(==(runtime_q), Float64.(evaluated.values)) ||
        throw(ArgumentError("dt_thermal_typed_g1_values_do_not_match_runtime_input"))
    runtime_case = cell_source_W_m3 === nothing ?
        _thermal_spatial_case_with_source_density_v1(spatial_case, runtime_q) :
        _thermal_spatial_case_with_source_profile_v1(spatial_case, cell_source_W_m3)
    result = _execute_steady_planar_thermal_diffusion_v1(candidate, g1, g2, g3,
        bundle, runtime_case; candidate_source_density=(g1_profile=profile,
            g1_input=runtime_input), cell_source_W_m3=cell_source_W_m3)
    isapprox(result.integrated_source_W, transferred_power_W;
        rtol=1e-10, atol=1e-12) &&
        abs(result.energy_balance_residual_W) <= 1e-10 ||
        throw(ArgumentError("dt_thermal_consumer_power_or_energy_balance_failed"))
    body = (schema="fusionconceptai:runtime-v4:candidate-dt-to-thermal-screen-v1",
        status=:screen_only, candidate_ref=candidate_input.candidate_ref,
        source_mode=source_mode,
        candidate_bound=false, physical_evidence=false, engineering_evidence=false,
        evidence_credit=0, claim_ceiling=:screen_only,
        plasma_region_id=spec.plasma_region_id,
        thermal_region_id=spec.thermal_region_id,
        candidate_spec_hash=canonical_hash(spec),
        plasma_input_hash=canonical_hash(spec.plasma_input),
        provider_result=source, provider_result_hash=canonical_hash(source),
        wall_transfer_fraction=Float64(fraction.value),
        plasma_volume_m3=Float64(plasma_volume.value),
        thermal_volume_m3=actual_wall_volume,
        transferred_power_W=transferred_power_W,
        rhs_source_W_m3=cell_source_W_m3 === nothing ?
            Tuple(Float64.(evaluated.values)) : cell_source_W_m3,
        runtime_source_input_hash=canonical_hash(runtime_input),
        thermal_result=result, thermal_result_hash=result.result_hash,
        residual_norm=result.residual_norm,
        energy_balance_residual_W=result.energy_balance_residual_W)
    if spatial_source_contract !== nothing
        body = merge(body, (spatial_source_contract=spatial_source_contract,))
    end
    merge(body, (result_hash=canonical_hash(body),))
end

function _thermal_spatial_case_with_source_density_v1(spatial_case, q_W_m3)
    isfinite(Float64(q_W_m3)) && Float64(q_W_m3) >= 0.0 ||
        throw(ArgumentError("thermal_runtime_source_density_must_be_finite_nonnegative"))
    n = length(spatial_case.field.source)
    source = Tuple(Float64(q_W_m3) for _ in 1:n)
    _thermal_spatial_case_with_source_profile_v1(spatial_case, source)
end

function _thermal_spatial_case_with_source_profile_v1(spatial_case, source_values)
    n = length(spatial_case.field.source)
    length(source_values) == n && all(isfinite, source_values) &&
        all(>=(0.0), source_values) ||
        throw(ArgumentError("thermal_runtime_source_profile_invalid"))
    source = Tuple(Float64.(source_values))
    field = FusionConceptAI.DeclaredSpatialFieldV1(spatial_case.field.k_cells,
        source; k_hash=spatial_case.field.k_hash)
    components = Tuple(begin
        ports = Tuple(begin
            payload = port.account == "source" ? source : port.payload
            FusionConceptAI.DeclaredSpatialPortV1(port.port_ref,
                port.direction, port.quantity, port.unit, port.account;
                role=port.role, ledger_sign=port.ledger_sign,
                magnitude=port.magnitude, payload=payload)
        end for port in component.ports)
        FusionConceptAI.DeclaredSpatialComponentV1(component.component_ref, ports)
    end for component in spatial_case.composition.components)
    composition = FusionConceptAI.DeclaredSpatialCompositionV1(components;
        plan_ref=spatial_case.composition.plan_ref)
    FusionConceptAI.DeclaredSpatialCaseV1(spatial_case.old_geometry,
        spatial_case.new_geometry, spatial_case.old_state, field,
        spatial_case.boundary, composition; case_ref=spatial_case.case_ref)
end

"""Run a source-bound temperature-to-q response with one real FV re-solve.

This performs one authored feedback response (seed solve -> measured maximum
cell-centre temperature -> bounded q source -> solve again). It does not claim
fixed-point convergence; both solves reuse the same candidate and declarations.
"""
function execute_steady_planar_thermal_feedback_step_v1(candidate, g1, g2, g3,
        bundle, spatial_case)
    seed = execute_steady_planar_thermal_diffusion_v1(candidate, g1, g2, g3,
        bundle, spatial_case)
    input = FusionConceptAI.dcce_input_v1(candidate, g1, g2, g3, bundle,
        spatial_case)
    measurement = maximum(Float64.(seed.temperature_K))
    feedback = thermal_temperature_source_density_input_v1(input, measurement)
    runtime_case = _thermal_spatial_case_with_source_density_v1(spatial_case,
        feedback.q_W_m3)
    solved = _execute_steady_planar_thermal_diffusion_v1(candidate, g1, g2, g3,
        bundle, runtime_case; source_feedback=feedback)
    result_feedback = (schema="fusionconceptai:runtime-v4:single-step-thermal-source-feedback-v1",
        status=:screen_only, fixed_point_converged=false, iteration_count=1,
        source_profile_hash=feedback.g3_source_profile_hash,
        source_record_hash=feedback.g3_source_record_hash,
        g1_profile_hash=feedback.g1_profile.profile_hash,
        g1_parameter_hash=feedback.g1_input.parameter_hash,
        measurement_reduction=:maximum_cell_center,
        controller_id=feedback.controller_id, sensor_port_id=feedback.sensor_port_id,
        actuator_port_id=feedback.actuator_port_id,
        actuator_fraction=feedback.actuator_fraction,
        resource_link_id=feedback.resource_link_id,
        resource_port_id=feedback.resource_port_id,
        seed_temperature_K=measurement, q0_W_m3=feedback.q0_W_m3,
        q_W_m3=feedback.q_W_m3, seed_result_hash=seed.result_hash,
        response_result_hash=solved.result_hash,
        seed_solver_invocations=1, response_solver_invocations=1,
        claim_ceiling=:screen_only)
    body = merge(Base.structdiff(solved, (result_hash=nothing,)),
        (temperature_source_feedback=result_feedback,))
    merge(body, (result_hash=canonical_hash(body),))
end

struct ThermalTemperatureSourceFeedbackInvalidV1 <: Exception
    cause::Any
end
Base.showerror(io::IO, err::ThermalTemperatureSourceFeedbackInvalidV1) =
    print(io, "invalid source-bound temperature feedback: ", sprint(showerror, err.cause))

function _execute_steady_planar_thermal_gridap_q1_v1(candidate, g1, g2, g3,
        bundle, spatial_case; source_feedback=nothing)
    source_profile = source_feedback === nothing ? nothing :
        source_feedback.g1_profile
    source_input = source_feedback === nothing ? nothing :
        source_feedback.g1_input
    input = FusionConceptAI.dcce_input_v1(candidate, g1, g2, g3, bundle,
        spatial_case)
    validation = _validate_thermal_input(input; records_checked=true,
        source_density_profile=source_profile,
        source_density_input=source_input)
    transfer = FusionConceptAI.measure_overlap_transfer(spatial_case.old_geometry,
        spatial_case.new_geometry, spatial_case.old_state)
    transfer.valid || throw(ArgumentError("thermal_state_transfer_not_ready:$(transfer.code)"))
    transfer_hash = transfer.transfer.transfer_hash
    if source_feedback !== nothing
        expected = thermal_temperature_source_density_input_v1(input,
            source_feedback.temperature_K)
        source_feedback.g3_source_profile_hash == expected.g3_source_profile_hash &&
            source_feedback.g3_source_record_hash == expected.g3_source_record_hash &&
            canonical_hash(source_feedback.g1_profile) == canonical_hash(expected.g1_profile) &&
            canonical_hash(source_feedback.g1_input) == canonical_hash(expected.g1_input) &&
            source_feedback.q_W_m3 == expected.q_W_m3 &&
            source_feedback.actuator_fraction == expected.actuator_fraction &&
            source_feedback.resource_link_id == expected.resource_link_id &&
            source_feedback.resource_port_id == expected.resource_port_id ||
            throw(ArgumentError("thermal_runtime_feedback_does_not_rebuild_from_G3_source"))
    end

    isdefined(Main, :FusionRuntimeV4) ||
        throw(ArgumentError("thermal_gridap_runtime_is_not_loaded"))
    runtime = getfield(Main, :FusionRuntimeV4)
    isdefined(runtime, :run_g1_thermal_q1_gridap_v1) ||
        throw(ArgumentError("thermal_gridap_q1_route_is_not_loaded"))
    dgd_input = FusionConceptAI.DeclaredG123InputV1(candidate, g1, g2, g3,
        bundle, FusionConceptAI.DeclaredG123HashSetV1(candidate,
            input.hashes.g1_body_hash, input.hashes.g2_body_hash,
            input.hashes.g3_body_hash, input.hashes.bundle_hash))
    route = getfield(runtime, :run_g1_thermal_q1_gridap_v1)
    diagnostic_sink = _GRIDAP_Q1_DIAGNOSTIC_CALL_SINK[]
    if diagnostic_sink === nothing
        q1 = Base.invokelatest(route, dgd_input;
            quadrature_degree=4, source_density_profile=source_profile,
            source_density_runtime_input=source_input,
            include_cell_center_sensor=true)
    else
        live_before = Base.gc_live_bytes()
        timed_call = @timed try
            (value=Base.invokelatest(route, dgd_input;
                quadrature_degree=4, source_density_profile=source_profile,
                source_density_runtime_input=source_input,
                include_cell_center_sensor=true),
             exception=nothing)
        catch err
            (value=nothing, exception=err,
             exception_type=string(typeof(err)),
             exception_message=sprint(showerror, err))
        end
        q1 = timed_call.value.value
        common_metrics = (call_index=length(diagnostic_sink) + 1,
            wall_seconds=timed_call.time, allocated_bytes=timed_call.bytes,
            gc_seconds=timed_call.gctime, live_heap_before_bytes=live_before,
            live_heap_after_bytes=Base.gc_live_bytes(),
            source_density_W_m3=source_input === nothing ?
                only(unique(Float64.(spatial_case.field.source))) :
                Float64(source_input.q_W_m3))
        if timed_call.value.exception !== nothing
            push!(diagnostic_sink, merge(common_metrics,
                (status=nothing, resolution=nothing, code=nothing,
                 residual_abs=nothing, energy_balance_status=nothing,
                 energy_balance_defect_W=nothing,
                 maximum_cell_center_temperature_K=nothing,
                 exception_type=timed_call.value.exception_type,
                 exception_message=timed_call.value.exception_message)))
            println("UP3_Q1_GRIDAP_CALL=", last(diagnostic_sink))
            flush(stdout)
            throw(timed_call.value.exception)
        end
        energy_balance = hasproperty(q1, :energy_balance) ? q1.energy_balance : nothing
        push!(diagnostic_sink, merge(common_metrics,
            (status=hasproperty(q1, :status) ? q1.status : nothing,
             resolution=hasproperty(q1, :resolution) ? q1.resolution : nothing,
             code=hasproperty(q1, :code) ? q1.code : nothing,
             residual_abs=hasproperty(q1, :residual_abs) ? q1.residual_abs : nothing,
             energy_balance_status=energy_balance !== nothing &&
                hasproperty(energy_balance, :status) ? energy_balance.status : nothing,
             energy_balance_defect_W=energy_balance !== nothing &&
                hasproperty(energy_balance, :source_power_balance_defect_w) ?
                    energy_balance.source_power_balance_defect_w : nothing,
             maximum_cell_center_temperature_K=hasproperty(q1,
                :maximum_cell_center_temperature_k) ?
                    q1.maximum_cell_center_temperature_k : nothing,
             exception_type=nothing, exception_message=nothing)))
        println("UP3_Q1_GRIDAP_CALL=", last(diagnostic_sink))
        flush(stdout)
    end
    expected_x_centers = Tuple((Float64(spatial_case.new_geometry.edges[i]) +
        Float64(spatial_case.new_geometry.edges[i + 1])) / 2
        for i in 1:(length(spatial_case.new_geometry.edges) - 1))
    q1.status === :executed && q1.energy_balance.status === :pass &&
        q1.residual_abs <= q1.energy_balance.tolerance_w &&
        q1.source_density_w_m3 == only(unique(Float64.(spatial_case.field.source))) &&
        length(q1.temperature_cell_centers_k) == length(spatial_case.field.source) &&
        length(q1.physical_cell_centers) == length(expected_x_centers) &&
        all(isapprox(q1.physical_cell_centers[i][1], expected_x_centers[i];
            atol=1e-12, rtol=0.0) for i in eachindex(expected_x_centers)) &&
        length(spatial_case.field.k_cells) == length(spatial_case.field.source) ||
        throw(ArgumentError("thermal_gridap_q1_source_or_numerical_gate_failed"))
    if source_feedback !== nothing
        q1.runtime_source_density !== nothing &&
            q1.runtime_source_density.profile_hash == source_profile.profile_hash &&
            q1.runtime_source_density.input_hash == source_input.input_hash &&
            q1.runtime_source_density.parameter_hash == source_input.parameter_hash &&
            q1.runtime_source_density.q_W_m3 == source_feedback.q_W_m3 ||
            throw(ArgumentError("thermal_gridap_q1_runtime_source_identity_mismatch"))
    end
    merge(q1, (status=:screen_only, accepted=false,
        solver_component=:gridap_q1,
        source_program_audit=validation.source_audit,
        temperature_K=q1.temperature_cell_centers_k,
        maximum_cell_center_temperature_K=q1.maximum_cell_center_temperature_k,
        volume_source_W_m3=Tuple(q1.source_density_w_m3 for
            _ in eachindex(spatial_case.field.source)),
        conductivity_W_mK=Tuple(Float64.(spatial_case.field.k_cells)),
        energy_balance_residual_W=q1.energy_balance.source_power_balance_defect_w,
        state_transfer_hash=transfer_hash,
        result_hash=canonical_hash((route=:source_bound_gridap_q1,
            source_binding=q1.source_binding, source_density=q1.source_density_w_m3,
            runtime_source_density=q1.runtime_source_density,
            mesh=q1.mesh, physical_cell_centers=q1.physical_cell_centers,
            temperature_cell_centers=q1.temperature_cell_centers_k,
            manufactured_solution=q1.manufactured_solution,
            state_transfer_hash=transfer_hash, residual=q1.residual_abs,
            energy_balance=q1.energy_balance))))
end

function _execute_steady_planar_thermal_gridap_q1_fixed_point_v1(candidate,
        g1, g2, g3, bundle, spatial_case,
        protocol::FusionConceptAI.CompositionSolveProtocolV1)
    tolerance = protocol.residual_tolerance
    isfinite(tolerance) && tolerance > 0.0 ||
        throw(ArgumentError("thermal_fixed_point_residual_tolerance_invalid"))
    current = _execute_steady_planar_thermal_gridap_q1_v1(candidate, g1, g2,
        g3, bundle, spatial_case)
    initial_source = Tuple(Float64.(current.volume_source_W_m3))
    !isempty(initial_source) && all(isfinite, initial_source) &&
        all(==(first(initial_source)), initial_source) ||
        throw(ArgumentError("thermal_fixed_point_initial_source_is_not_uniform"))
    q_applied = first(initial_source)
    input = FusionConceptAI.dcce_input_v1(candidate, g1, g2, g3, bundle,
        spatial_case)
    trace = NamedTuple[]
    converged = false
    termination = :iteration_limit
    feedback = nothing
    for iteration in 1:protocol.max_iterations
        temperature_K = current.maximum_cell_center_temperature_K
        feedback = try
            thermal_temperature_source_density_input_v1(input, temperature_K)
        catch err
            err isa ArgumentError || rethrow()
            throw(ThermalTemperatureSourceFeedbackInvalidV1(err))
        end
        q_next = Float64(feedback.q_W_m3)
        residual = abs(q_next - q_applied)
        isfinite(residual) ||
            throw(ArgumentError("thermal_fixed_point_residual_is_nonfinite"))
        push!(trace, (iteration=iteration, applied_q_W_m3=q_applied,
            maximum_cell_center_temperature_K=temperature_K,
            next_q_W_m3=q_next, residual_W_m3=residual,
            actuator_fraction=feedback.actuator_fraction,
            g1_parameter_hash=feedback.g1_input.parameter_hash,
            gridap_q1_result_hash=current.result_hash,
            q1_residual_abs=current.residual_abs,
            q1_energy_balance=current.energy_balance))
        if residual <= tolerance
            converged = true
            termination = :residual_tolerance
            break
        end
        if iteration < protocol.max_iterations
            runtime_case = _thermal_spatial_case_with_source_density_v1(
                spatial_case, q_next)
            current = _execute_steady_planar_thermal_gridap_q1_v1(candidate,
                g1, g2, g3, bundle, runtime_case; source_feedback=feedback)
            q_applied = q_next
        end
    end
    status = converged ? :screen_only :
        protocol.nonconvergent_policy === :fail_closed ? :fail_closed : :terminal_deferred
    summary = (schema="fusionconceptai:runtime-v4:thermal-source-fixed-point-screen-v1",
        status=status, fixed_point_converged=converged,
        termination=termination, claim_ceiling=:screen_only,
        candidate_ref=candidate, protocol_ref=protocol.protocol_ref,
        max_iterations=protocol.max_iterations, iteration_count=length(trace),
        residual_tolerance=tolerance, residual_tolerance_unit=_SOURCE_W_M3,
        residual=last(trace).residual_W_m3, residual_unit=_SOURCE_W_M3,
        nonconvergent_policy=protocol.nonconvergent_policy,
        measurement_reduction=:maximum_cell_center,
        measurement_backend=:gridap_q1_cell_center_evaluation,
        temperature_K=last(trace).maximum_cell_center_temperature_K,
        applied_q_W_m3=first(current.volume_source_W_m3),
        next_q_W_m3=feedback.q_W_m3, q0_W_m3=feedback.q0_W_m3,
        q_min_W_m3=feedback.q_min_W_m3, q_max_W_m3=feedback.q_max_W_m3,
        actuator_fraction=feedback.actuator_fraction,
        controller_id=feedback.controller_id, sensor_port_id=feedback.sensor_port_id,
        actuator_port_id=feedback.actuator_port_id,
        resource_link_id=feedback.resource_link_id, resource_port_id=feedback.resource_port_id,
        g3_source_profile_hash=feedback.g3_source_profile_hash,
        g3_source_record_hash=feedback.g3_source_record_hash,
        g1_profile_hash=feedback.g1_profile.profile_hash,
        next_g1_parameter_hash=feedback.g1_input.parameter_hash,
        iteration_trace=Tuple(trace), solver_invocation_count=length(trace),
        final_gridap_q1_result_hash=current.result_hash)
    body = merge(Base.structdiff(current, (result_hash=nothing,)),
        (status=status, accepted=false, claim_ceiling=:screen_only,
         provider_invocation_count=0, physical_validation=false,
         engineering_validation=false, evidence_credit=0,
         temperature_source_fixed_point=summary))
    merge(body, (result_hash=canonical_hash(body),))
end

"""Run the candidate-authored thermal source law to a bounded q fixed point.

This thermal-specific screen reuses the exact admitted G3 temperature law and
source-bound G1 evaluator, then re-solves the same SI slab FV consumer. The
protocol's `max_iterations` is the maximum number of q-update residual checks;
`residual_tolerance` is interpreted here as an absolute source-density
residual in W/m^3. A nonconverged cap follows the protocol's policy. This does
not execute a general cyclic CompositionSolvePlan or claim physical validation.
"""
function execute_steady_planar_thermal_fixed_point_v1(candidate, g1, g2, g3,
        bundle, spatial_case,
        protocol::FusionConceptAI.CompositionSolveProtocolV1;
        solver_component::Symbol=:fv)
    solver_component === :gridap_q1 &&
        return _execute_steady_planar_thermal_gridap_q1_fixed_point_v1(
            candidate, g1, g2, g3, bundle, spatial_case, protocol)
    solver_component === :fv ||
        throw(ArgumentError("thermal_fixed_point_solver_component_unsupported"))
    max_iterations = protocol.max_iterations
    residual_tolerance_W_m3 = protocol.residual_tolerance
    isfinite(residual_tolerance_W_m3) && residual_tolerance_W_m3 > 0.0 ||
        throw(ArgumentError("thermal_fixed_point_residual_tolerance_invalid"))

    current = execute_steady_planar_thermal_diffusion_v1(candidate, g1, g2,
        g3, bundle, spatial_case)
    input = FusionConceptAI.dcce_input_v1(candidate, g1, g2, g3, bundle,
        spatial_case)
    initial_source = Tuple(Float64.(current.volume_source_W_m3))
    isempty(initial_source) &&
        throw(ArgumentError("thermal_fixed_point_initial_source_is_empty"))
    all(isfinite, initial_source) && all(==(first(initial_source)), initial_source) ||
        throw(ArgumentError("thermal_fixed_point_initial_source_is_not_uniform"))
    q_applied = first(initial_source)

    trace = NamedTuple[]
    converged = false
    termination = :iteration_limit
    feedback = nothing
    for iteration in 1:max_iterations
        temperature_K = maximum(Float64.(current.temperature_K))
        feedback = try
            thermal_temperature_source_density_input_v1(input, temperature_K)
        catch err
            err isa ArgumentError || rethrow()
            throw(ThermalTemperatureSourceFeedbackInvalidV1(err))
        end
        q_next = Float64(feedback.q_W_m3)
        residual_W_m3 = abs(q_next - q_applied)
        isfinite(residual_W_m3) ||
            throw(ArgumentError("thermal_fixed_point_residual_is_nonfinite"))
        push!(trace, (iteration=iteration, applied_q_W_m3=q_applied,
            maximum_cell_center_temperature_K=temperature_K,
            next_q_W_m3=q_next, residual_W_m3=residual_W_m3,
            actuator_fraction=feedback.actuator_fraction,
            g1_parameter_hash=feedback.g1_input.parameter_hash,
            fv_result_hash=current.result_hash))
        if residual_W_m3 <= residual_tolerance_W_m3
            converged = true
            termination = :residual_tolerance
            break
        end
        if iteration < max_iterations
            runtime_case = _thermal_spatial_case_with_source_density_v1(
                spatial_case, q_next)
            current = _execute_steady_planar_thermal_diffusion_v1(candidate,
                g1, g2, g3, bundle, runtime_case; source_feedback=feedback)
            q_applied = q_next
        end
    end

    final_source = Tuple(Float64.(current.volume_source_W_m3))
    isempty(final_source) &&
        throw(ArgumentError("thermal_fixed_point_final_source_is_empty"))
    all(isfinite, final_source) && all(==(first(final_source)), final_source) ||
        throw(ArgumentError("thermal_fixed_point_final_source_is_not_uniform"))
    applied_q_W_m3 = first(final_source)
    residual_W_m3 = last(trace).residual_W_m3
    status = converged ? :screen_only :
        protocol.nonconvergent_policy === :fail_closed ? :fail_closed : :terminal_deferred
    summary = (schema="fusionconceptai:runtime-v4:thermal-source-fixed-point-screen-v1",
        status=status, fixed_point_converged=converged,
        termination=termination, claim_ceiling=:screen_only,
        candidate_ref=candidate, protocol_ref=protocol.protocol_ref,
        max_iterations=max_iterations, iteration_count=length(trace),
        residual_tolerance=residual_tolerance_W_m3,
        residual_tolerance_unit=_SOURCE_W_M3,
        residual=residual_W_m3, residual_unit=_SOURCE_W_M3,
        nonconvergent_policy=protocol.nonconvergent_policy,
        measurement_reduction=:maximum_cell_center,
        temperature_K=last(trace).maximum_cell_center_temperature_K,
        applied_q_W_m3=applied_q_W_m3,
        next_q_W_m3=feedback.q_W_m3,
        q0_W_m3=feedback.q0_W_m3,
        q_min_W_m3=feedback.q_min_W_m3,
        q_max_W_m3=feedback.q_max_W_m3,
        actuator_fraction=feedback.actuator_fraction,
        controller_id=feedback.controller_id,
        sensor_port_id=feedback.sensor_port_id,
        actuator_port_id=feedback.actuator_port_id,
        resource_link_id=feedback.resource_link_id,
        resource_port_id=feedback.resource_port_id,
        g3_source_profile_hash=feedback.g3_source_profile_hash,
        g3_source_record_hash=feedback.g3_source_record_hash,
        g1_profile_hash=feedback.g1_profile.profile_hash,
        next_g1_parameter_hash=feedback.g1_input.parameter_hash,
        iteration_trace=Tuple(trace),
        solver_invocation_count=length(trace),
        final_fv_result_hash=current.result_hash)
    body = merge(Base.structdiff(current, (result_hash=nothing,)),
        (status=status, temperature_source_fixed_point=summary))
    merge(body, (result_hash=canonical_hash(body),))
end

"""
UP3's narrow executable path for the existing SI planar thermal component.

The admitted typed plan is rebuilt from the exact caller inputs. It binds
candidate/T0/G1/G2/G3/spatial declarations to one solver node. The solver
receives only the existing source-bound SI slab case; feedback is unsupported
and remains typed absent. This does not consume the native MMS scalar heat
receipt or claim full UP3 feedback.
"""
const UP3_STEADY_PLANAR_COMPOSITION_SCHEMA_V1 =
    "fusionconceptai:runtime-v4:up3-steady-planar-composition-v1"

function _up3_slab_component_ref(role, artifact_hashes, case_hash)
    canonical_hash((schema=UP3_STEADY_PLANAR_COMPOSITION_SCHEMA_V1,
        role=role, artifacts=artifact_hashes, spatial_case_hash=case_hash))
end

function _up3_slab_port(label, slot, direction, quantity, unit, space,
        account, owner; role_override=nothing)
    role = role_override === nothing ?
        (direction === :output ? :source : :sink) : role_override
    sign = role === :state ? 0 : (direction === :output ? 1 : -1)
    FusionConceptAI.CompositionSolvePortV1(label, slot, direction, quantity,
        unit, space, account, owner, sign, role)
end

function _up3_slab_actual_source_hashes(candidate, g1, g2, g3, bundle, spatial_case)
    input = FusionConceptAI.dcce_input_v1(candidate, g1, g2, g3, bundle,
        spatial_case)
    h = input.hashes
    spatial_hash = canonical_hash((
        old_geometry=semantic_view(spatial_case.old_geometry),
        new_geometry=semantic_view(spatial_case.new_geometry),
        old_state=Tuple(spatial_case.old_state),
        field=semantic_view(spatial_case.field),
        boundary=spatial_case.boundary === nothing ? nothing :
            semantic_view(spatial_case.boundary),
        composition=semantic_view(spatial_case.composition)))
    (candidate_ref=canonical_hash(candidate),
        g1_body_hash=canonical_hash(h.g1_body_hash),
        g2_body_hash=canonical_hash(h.g2_body_hash),
        g3_body_hash=canonical_hash(h.g3_body_hash),
        bundle_hash=canonical_hash(h.bundle_hash),
        spatial_case_hash=spatial_hash)
end

function _up3_slab_components(candidate, g1, g2, g3, bundle, spatial_case;
        solver_component::Symbol=:fv)
    solver_component in (:fv, :gridap_q1) ||
        throw(ArgumentError("up3_slab_solver_component_unsupported"))
    hashes = _up3_slab_actual_source_hashes(candidate, g1, g2, g3, bundle,
        spatial_case)
    chart_ref = canonical_hash((g2_body_hash=hashes.g2_body_hash,
        chart_source_hash=g2.source.source_hash))
    scalar_space = FusionConceptAI.CompositionSolveSpaceV1(
        canonical_hash((spatial_case=hashes.spatial_case_hash, kind=:scalar)),
        :scalar, 3, chart_ref)
    seed_space = FusionConceptAI.CompositionSolveSpaceV1(
        canonical_hash((spatial_case=hashes.spatial_case_hash, kind=:q0_seed_scalar)),
        :scalar, 3, chart_ref)
    feedback_space = FusionConceptAI.CompositionSolveSpaceV1(
        canonical_hash((spatial_case=hashes.spatial_case_hash, kind=:q_feedback_spatial_state)),
        :scalar, 3, chart_ref)
    g3_bundle_space = FusionConceptAI.CompositionSolveSpaceV1(
        canonical_hash((spatial_case=hashes.spatial_case_hash, kind=:t0_bundle_for_g3)),
        :scalar, 3, chart_ref)
    tensor_space = FusionConceptAI.CompositionSolveSpaceV1(
        canonical_hash((spatial_case=hashes.spatial_case_hash, kind=:tensor)),
        :tensor, 3, chart_ref)
    domain_space = FusionConceptAI.CompositionSolveSpaceV1(
        canonical_hash((spatial_case=hashes.spatial_case_hash, kind=:g2_domain)),
        :scalar, 3, chart_ref)
    context_space = FusionConceptAI.CompositionSolveSpaceV1(
        canonical_hash((spatial_case=hashes.spatial_case_hash, kind=:g3_context)),
        :scalar, 3, chart_ref)
    bundle_space = FusionConceptAI.CompositionSolveSpaceV1(
        canonical_hash((spatial_case=hashes.spatial_case_hash, kind=:t0_bundle)),
        :scalar, 3, chart_ref)
    dimensionless = FusionConceptAI.CompositionSolveUnitV1(:field,
        (0, 0, 0, 0, 0, 0, 0))
    source_unit = FusionConceptAI.CompositionSolveUnitV1(:heat,
        (-1, 1, -3, 0, 0, 0, 0))
    conductivity_unit = FusionConceptAI.CompositionSolveUnitV1(:material,
        (1, 1, -3, 0, -1, 0, 0))

    g1_ref = _up3_slab_component_ref(:g1_diffusion,
        (hashes.g1_body_hash,), hashes.spatial_case_hash)
    g2_ref = _up3_slab_component_ref(:g2_domain,
        (hashes.g2_body_hash,), hashes.spatial_case_hash)
    g3_ref = _up3_slab_component_ref(:g3_candidate_context,
        (hashes.g3_body_hash,), hashes.spatial_case_hash)
    t0_ref = _up3_slab_component_ref(:t0_bundle,
        (hashes.bundle_hash,), hashes.spatial_case_hash)
    solver_role = solver_component === :fv ? :steady_planar_fv_solver :
        :steady_planar_gridap_q1_solver
    solver_ref = _up3_slab_component_ref(solver_role,
        (hashes.g1_body_hash, hashes.g2_body_hash, hashes.g3_body_hash,
         hashes.bundle_hash), hashes.spatial_case_hash)

    feedback_declared = up3_temperature_source_feedback_declared_v1(bundle)
    g1_ports = feedback_declared ? (
        _up3_slab_port("g1_source_density", 1, :output, :heat, source_unit,
            scalar_space, "source_density", "g1"),
        _up3_slab_port("g1_conductivity", 2, :output, :material,
            conductivity_unit, tensor_space, "conductivity", "g1"),
        _up3_slab_port("g1_source_seed", 3, :output, :heat, source_unit,
            seed_space, "source_seed", "g1")) : (
        _up3_slab_port("g1_source_density", 1, :output, :heat, source_unit,
            scalar_space, "source_density", "g1"),
        _up3_slab_port("g1_conductivity", 2, :output, :material,
            conductivity_unit, tensor_space, "conductivity", "g1"))
    g2_ports = (_up3_slab_port("g2_chart_and_domain", 1, :output,
        :field, dimensionless, domain_space, "domain", "g2"),)
    g3_inputs, g3_outputs = if feedback_declared
        ((
            _up3_slab_port("g3_base_source_input", 1, :input, :heat,
                source_unit, scalar_space, "source_density", "g1"),
            _up3_slab_port("g3_bundle_input", 2, :input, :field,
                dimensionless, g3_bundle_space, "bundle", "g3"),
            _up3_slab_port("temperature_measurement_input", 3, :input,
                :field, FusionConceptAI.CompositionSolveUnitV1(:field,
                    (0, 0, 0, 0, 1, 0, 0)), scalar_space, "temperature",
                "solver")),
         (
            _up3_slab_port("feedback_source_density", 1, :output, :heat,
                source_unit, feedback_space, "source_density", "g3";
                role_override=:state),))
    else
        ((), (_up3_slab_port("g3_candidate_context", 1, :output,
            :field, dimensionless, context_space, "context", "g3"),))
    end
    t0_ports = feedback_declared ? (
        _up3_slab_port("t0_bundle_for_solver", 1, :output, :field,
            dimensionless, bundle_space, "bundle", "t0"),
        _up3_slab_port("t0_bundle_for_g3", 2, :output, :field,
            dimensionless, g3_bundle_space, "bundle", "g3")) :
        (_up3_slab_port("t0_bundle", 1, :output,
            :field, dimensionless, bundle_space, "bundle", "t0"),)
    solver_inputs, solver_outputs = if feedback_declared
        ((
            _up3_slab_port("source_density_feedback_input", 1, :input,
                :heat, source_unit, feedback_space, "source_density", "g3";
                role_override=:state),
            _up3_slab_port("conductivity_input", 2, :input, :material,
                conductivity_unit, tensor_space, "conductivity", "g1"),
            _up3_slab_port("domain_input", 3, :input, :field,
                dimensionless, domain_space, "domain", "g2"),
            _up3_slab_port("bundle_input", 5, :input, :field,
                dimensionless, bundle_space, "bundle", "t0"),
            _up3_slab_port("source_seed_input", 6, :input, :heat,
                source_unit, seed_space, "source_seed", "g1")),
         (_up3_slab_port("maximum_cell_center_temperature", 1, :output,
            :field, FusionConceptAI.CompositionSolveUnitV1(:field,
                (0, 0, 0, 0, 1, 0, 0)), scalar_space, "temperature",
            "solver"),))
    else
        ((
            _up3_slab_port("source_density_input", 1, :input, :heat,
                source_unit, scalar_space, "source_density", "g1"),
            _up3_slab_port("conductivity_input", 2, :input, :material,
                conductivity_unit, tensor_space, "conductivity", "g1"),
            _up3_slab_port("domain_input", 3, :input, :field,
                dimensionless, domain_space, "domain", "g2"),
            _up3_slab_port("g3_context_input", 4, :input, :field,
                dimensionless, context_space, "context", "g3"),
            _up3_slab_port("bundle_input", 5, :input, :field,
                dimensionless, bundle_space, "bundle", "t0")), ())
    end
    provider_name = solver_component === :fv ?
        :existing_declared_si_slab_consumer :
        :existing_source_bound_gridap_q1_consumer
    code_name = solver_component === :fv ? :steady_planar_fv_execution :
        :steady_planar_gridap_q1_execution
    backend_name = solver_component === :fv ? :local_cpu : :gridap_q1_lu
    provider_ref = canonical_hash((schema=UP3_STEADY_PLANAR_COMPOSITION_SCHEMA_V1,
        provider=provider_name))
    code_ref = canonical_hash((schema=UP3_STEADY_PLANAR_COMPOSITION_SCHEMA_V1,
        code=code_name))
    backend_ref = canonical_hash((schema=UP3_STEADY_PLANAR_COMPOSITION_SCHEMA_V1,
        backend=backend_name))
    refs = (provider_ref=provider_ref, code_ref=code_ref,
        backend_ref=backend_ref)
    components = (
        FusionConceptAI.CompositionSolveComponentV1(g1_ref, provider_ref,
            code_ref, backend_ref, (), g1_ports),
        FusionConceptAI.CompositionSolveComponentV1(g2_ref, provider_ref,
            code_ref, backend_ref, (), g2_ports),
        FusionConceptAI.CompositionSolveComponentV1(g3_ref, provider_ref,
            code_ref, backend_ref, g3_inputs, g3_outputs),
        FusionConceptAI.CompositionSolveComponentV1(t0_ref, provider_ref,
            code_ref, backend_ref, (), t0_ports),
        FusionConceptAI.CompositionSolveComponentV1(solver_ref, provider_ref,
            code_ref, backend_ref, solver_inputs, solver_outputs))
    feedback_edge_keys = feedback_declared ?
        ((g3_ref, 1, solver_ref, 1),) : ()
    (hashes=hashes, refs=refs, components=components,
        feedback_edge_keys=feedback_edge_keys)
end

function up3_steady_planar_composition_admit_v1(candidate, g1, g2, g3,
        bundle, spatial_case, protocol::FusionConceptAI.CompositionSolveProtocolV1;
        solver_component::Symbol=:fv,
        subject_ref::FusionConceptAI.Digest256,
        mission_ref::FusionConceptAI.Digest256,
        scenario_ref::FusionConceptAI.Digest256)
    parts = _up3_slab_components(candidate, g1, g2, g3, bundle, spatial_case;
        solver_component=solver_component)
    r = parts.refs
    binding = FusionConceptAI.CompositionSolveBindingV1(
        parts.hashes.candidate_ref, subject_ref, mission_ref, scenario_ref,
        r.provider_ref, r.code_ref, r.backend_ref, protocol.protocol_ref)
    input = FusionConceptAI.CompositionSolveInputV1(binding,
        parts.components, protocol;
        feedback_edge_keys=parts.feedback_edge_keys)
    FusionConceptAI.admit_composition_solve(input)
end

"""Admit and execute the exact source-bound SI slab composition.

Only ready plans generated from these actual inputs are executable. The
admitted composition is an acyclic source/solver DAG unless the exact
G3-to-solver state edge is explicitly declared as the supported feedback edge.
A present, validated G3 temperature-source law selects that thermal-specific
fixed-point evaluator; other cycles remain rejected. The native 3-D MMS heat
receipt is not accepted here, and removing the required source edge is fail-closed
rather than a zero-source fallback.
"""
function up3_temperature_source_feedback_declared_v1(bundle)
    records = Tuple(record for record in bundle.declarations if
        record isa FusionConceptAI.VNextT0LocalPresentDeclarationV1 &&
        record.layer === :G3)
    isempty(records) && return false
    length(records) == 1 ||
        throw(ArgumentError("up3_G3_source_record_not_unique_for_feedback_route"))
    body = only(records).semantic_body.body
    hasproperty(body, :authored_child_design) ||
        throw(ArgumentError("up3_G3_authored_child_design_missing_for_feedback_route"))
    body.authored_child_design isa NamedTuple ||
        throw(ArgumentError("up3_G3_authored_child_design_shape_invalid_for_feedback_route"))
    child = body.authored_child_design
    hasproperty(child, :control_design) ||
        throw(ArgumentError("up3_G3_control_design_missing_for_feedback_route"))
    child.control_design isa NamedTuple ||
        throw(ArgumentError("up3_G3_control_design_shape_invalid_for_feedback_route"))
    hasproperty(child.control_design, :temperature_source_feedback)
end


function _up3_slab_execution_bindings_v1(candidate, g1, g2, g3, bundle,
        spatial_case, admission::FusionConceptAI.CompositionSolveAdmissionV1;
        solver_component::Symbol=:fv)
    admission.plan isa FusionConceptAI.CompositionSolvePlanV1 ||
        throw(ArgumentError("up3_slab_execution_plan_missing"))
    plan = admission.plan
    parts = _up3_slab_components(candidate, g1, g2, g3, bundle, spatial_case;
        solver_component=solver_component)
    components = plan.input.components
    refs = parts.refs
    by_role = Dict{Symbol,FusionConceptAI.CompositionSolveComponentV1}()
    role_map = Dict(parts.components[1].component_ref => :g1,
        parts.components[2].component_ref => :g2,
        parts.components[3].component_ref => :g3,
        parts.components[4].component_ref => :t0,
        parts.components[5].component_ref => :solver)
    for component in components
        haskey(role_map, component.component_ref) ||
            throw(ArgumentError("up3_slab_execution_component_unrecognized"))
        by_role[role_map[component.component_ref]] = component
    end
    length(by_role) == 5 || throw(ArgumentError("up3_slab_execution_components_incomplete"))
    g1c, g2c, g3c, t0c, sc = (by_role[k] for k in (:g1, :g2, :g3, :t0, :solver))
    source_ids = Tuple((parts.hashes.candidate_ref, parts.hashes.g1_body_hash,
        parts.hashes.g2_body_hash, parts.hashes.g3_body_hash,
        parts.hashes.bundle_hash, parts.hashes.spatial_case_hash))
    input = FusionConceptAI.dcce_input_v1(candidate, g1, g2, g3, bundle,
        spatial_case)
    source_capability = _thermal_source_capability(input).capability
    q0 = Float64(source_capability.source_law.bindings.q.value)
    k_values = Tuple(Float64.(spatial_case.field.k_cells))
    domain_payload = (g2=g2, old_geometry=spatial_case.old_geometry,
        new_geometry=spatial_case.new_geometry,
        old_state=Tuple(spatial_case.old_state), boundary=spatial_case.boundary,
        composition=spatial_case.composition, case_ref=spatial_case.case_ref,
        k_hash=spatial_case.field.k_hash)
    feedback_declared = up3_temperature_source_feedback_declared_v1(bundle)
    if feedback_declared
        # Validate the authored feedback route before any composition callbacks.
        # Reuse this binding build's admitted DCCE input; live callbacks still
        # rebuild feedback from their measured temperature.
        g3_record = _thermal_t0_record(bundle, :G3)
        feedback_law = g3_record.semantic_body.body.authored_child_design.
            control_design.temperature_source_feedback
        try
            thermal_temperature_source_density_input_v1(input,
                Float64(feedback_law.setpoint_kelvin))
        catch err
            err isa ArgumentError || rethrow()
            throw(ThermalTemperatureSourceFeedbackInvalidV1(err))
        end
    end

    port_value(component, slot, payload) =
        FusionConceptAI.CompositionSolvePortValueV1(component.component_ref,
            FusionConceptAI._csp_port_for(component, :output, slot), payload,
            source_ids)
    function binding(component, kind, callback)
        FusionConceptAI.CompositionSolveProviderBindingV1(component.component_ref,
            refs.provider_ref, refs.code_ref, refs.backend_ref, source_ids,
            kind, callback)
    end
    g1_invoke = function (_)
        outputs = if feedback_declared
            (port_value(g1c, 1, q0),
             port_value(g1c, 2, (g1=g1, k_cells=k_values,
                k_hash=spatial_case.field.k_hash)),
             port_value(g1c, 3, q0))
        else
            (port_value(g1c, 1, q0),
             port_value(g1c, 2, (g1=g1, k_cells=k_values,
                k_hash=spatial_case.field.k_hash)))
        end
        (outputs=outputs, result=(q0_W_m3=q0,
            conductivity_W_mK=k_values, source_capability_hash=
                canonical_hash(source_capability)))
    end
    g2_invoke = _ -> (outputs=(port_value(g2c, 1, domain_payload),),
        result=(g2_source_hash=parts.hashes.g2_body_hash,
            case_ref=spatial_case.case_ref))
    t0_invoke = _ -> (outputs=feedback_declared ?
        (port_value(t0c, 1, bundle), port_value(t0c, 2, bundle)) :
        (port_value(t0c, 1, bundle),),
        result=(bundle_hash=parts.hashes.bundle_hash,))
    g3_invoke = function (values)
        if !feedback_declared
            return (outputs=(port_value(g3c, 1, (g3=g3,)),),
                result=(g3_source_hash=parts.hashes.g3_body_hash,))
        end
        haskey(values, 1) && haskey(values, 2) ||
            throw(ArgumentError("up3_G3_base_source_or_bundle_input_missing"))
        Float64(values[1].payload) == q0 ||
            throw(ArgumentError("up3_G3_base_source_differs_from_G1_seed"))
        values[2].payload === bundle ||
            canonical_hash(values[2].payload) == canonical_hash(bundle) ||
            throw(ArgumentError("up3_G3_bundle_input_differs_from_T0"))
        law = _thermal_t0_record(bundle, :G3).semantic_body.body.
            authored_child_design.control_design.temperature_source_feedback
        temperature = haskey(values, 3) ? Float64(values[3].payload) :
            Float64(law.setpoint_kelvin)
        feedback = thermal_temperature_source_density_input_v1(input, temperature)
        payload = (q_W_m3=Float64(feedback.q_W_m3), feedback=feedback, g3=g3)
        (outputs=(port_value(g3c, 1, payload),),
            result=(feedback=feedback, temperature_K=temperature,
                g3_source_hash=parts.hashes.g3_body_hash))
    end
    solver_invoke = function (values)
        trace_enabled = get(ENV, "UP3_COMPOSITION_TRACE", "") == "1"
        trace_enabled && (println("UP3_TRACE_THERMAL_SOLVER_BEGIN component=", solver_component); flush(stdout))
        case_started_ns = trace_enabled ? time_ns() : 0
        trace_enabled && (println("UP3_TRACE_THERMAL_CASE_BEGIN component=", solver_component); flush(stdout))
        haskey(values, 1) && haskey(values, 2) && haskey(values, 3) &&
            haskey(values, 5) && (feedback_declared || haskey(values, 4)) ||
            throw(ArgumentError("up3_slab_solver_required_resolved_inputs_missing"))
        q_payload = values[1].payload
        q = q_payload isa Number ? Float64(q_payload) :
            Float64(q_payload.q_W_m3)
        k_payload = values[2].payload
        domain = values[3].payload
        bundle_value = values[5].payload
        k_payload.g1.source_ref == g1.source_ref ||
            throw(ArgumentError("up3_slab_G1_resolved_conductivity_owner_mismatch"))
        domain.g2.source.source_ref == g2.source.source_ref ||
            throw(ArgumentError("up3_slab_G2_resolved_domain_owner_mismatch"))
        bundle_value === bundle ||
            canonical_hash(bundle_value) == canonical_hash(bundle) ||
            throw(ArgumentError("up3_slab_T0_resolved_bundle_mismatch"))
        k_cells = Tuple(Float64.(k_payload.k_cells))
        isempty(k_cells) && throw(ArgumentError("up3_slab_resolved_conductivity_empty"))
        all(isfinite, k_cells) || throw(ArgumentError("up3_slab_resolved_conductivity_nonfinite"))
        field = FusionConceptAI.DeclaredSpatialFieldV1(k_cells,
            zeros(length(k_cells)); k_hash=domain.k_hash)
        resolved_case = FusionConceptAI.DeclaredSpatialCaseV1(
            domain.old_geometry, domain.new_geometry, domain.old_state, field,
            domain.boundary, domain.composition; case_ref=domain.case_ref)
        runtime_case = _thermal_spatial_case_with_source_density_v1(
            resolved_case, q)
        trace_enabled && (println("UP3_TRACE_THERMAL_CASE_END component=", solver_component,
            " elapsed_ns=", time_ns() - case_started_ns); flush(stdout))
        g3_value = feedback_declared ? q_payload.g3 : values[4].payload.g3
        solver_result = if feedback_declared
            haskey(values, 6) ||
                throw(ArgumentError("up3_slab_G1_q0_seed_missing_from_solver"))
            Float64(values[6].payload) == q0 ||
                throw(ArgumentError("up3_slab_G1_q0_seed_value_mismatch"))
            feedback = q_payload.feedback
            feedback isa NamedTuple && hasproperty(feedback, :q_W_m3) &&
                Float64(feedback.q_W_m3) == q ||
                throw(ArgumentError("up3_slab_G3_feedback_payload_differs_from_solver_source"))
            solver_started_ns = trace_enabled ? time_ns() : 0
            trace_enabled && (println("UP3_TRACE_THERMAL_NUMERICAL_SOLVE_BEGIN component=", solver_component); flush(stdout))
            solved = solver_component === :fv ?
                _execute_steady_planar_thermal_diffusion_v1(candidate, g1, g2,
                    g3_value, bundle_value, runtime_case; source_feedback=feedback) :
                _execute_steady_planar_thermal_gridap_q1_v1(candidate, g1, g2,
                    g3_value, bundle_value, runtime_case; source_feedback=feedback)
            trace_enabled && (println("UP3_TRACE_THERMAL_NUMERICAL_SOLVE_END component=", solver_component,
                " elapsed_ns=", time_ns() - solver_started_ns); flush(stdout))
            solved
        else
            solver_started_ns = trace_enabled ? time_ns() : 0
            trace_enabled && (println("UP3_TRACE_THERMAL_NUMERICAL_SOLVE_BEGIN component=", solver_component); flush(stdout))
            solved = solver_component === :fv ?
                execute_steady_planar_thermal_diffusion_v1(candidate, g1, g2,
                    g3_value, bundle_value, runtime_case) :
                _execute_steady_planar_thermal_gridap_q1_v1(candidate, g1, g2,
                    g3_value, bundle_value, runtime_case)
            trace_enabled && (println("UP3_TRACE_THERMAL_NUMERICAL_SOLVE_END component=", solver_component,
                " elapsed_ns=", time_ns() - solver_started_ns); flush(stdout))
            solved
        end
        if feedback_declared
            measured_temperature = solver_component === :fv ?
                maximum(Float64.(solver_result.temperature_K)) :
                Float64(solver_result.maximum_cell_center_temperature_K)
            outputs = (port_value(sc, 1, measured_temperature),)
        else
            outputs = ()
        end
        (outputs=outputs, result=solver_result)
    end
    bindings = (
        binding(g1c, :provider, g1_invoke),
        binding(g2c, :provider, g2_invoke),
        binding(g3c, :provider, g3_invoke),
        binding(t0c, :provider, t0_invoke),
        binding(sc, :solver, solver_invoke))
    feedback_seeds = if feedback_declared
        feedback_edges = FusionConceptAI._csp_feedback_edges(plan)
        length(feedback_edges) == 1 ||
            throw(ArgumentError("up3_slab_requires_exactly_one_source_feedback_edge"))
        feedback_edge = only(feedback_edges)
        seed_edges = Tuple(edge for edge in plan.edges
            if edge.producer_component == g1c.component_ref &&
                edge.producer_slot == 3 && edge.consumer_component == sc.component_ref &&
                edge.consumer_slot == 6)
        length(seed_edges) == 1 ||
            throw(ArgumentError("up3_slab_G1_q0_seed_edge_missing_or_ambiguous"))
        seed_port = FusionConceptAI._csp_port_for(g1c, :output, 3)
        seed_value = port_value(g1c, 3, q0)
        unit = seed_port.unit
        (FusionConceptAI.CompositionSolveFeedbackSeedV1(feedback_edge,
            only(seed_edges), seed_value, 1.0, unit,
            protocol_tolerance(admission.input.protocol)),)
    else
        ()
    end
    (provider_bindings=bindings, feedback_seeds=feedback_seeds,
     source_identity_hashes=source_ids)
end

protocol_tolerance(protocol::FusionConceptAI.CompositionSolveProtocolV1) =
    protocol.residual_tolerance

function _up3_slab_iteration_trace_v1(raw_trace, solver_component)
    trace_values = Tuple(begin
        feedback = step.provider_result.feedback
        solver = step.solver_result
        source = Tuple(Float64.(solver.volume_source_W_m3))
        feedback.temperature_K == step.temperature_K &&
            Float64(feedback.q_W_m3) == step.next ||
            throw(ArgumentError("up3_trace_G3_feedback_not_bound_to_measured_solver_state"))
        !isempty(source) && all(==(step.applied), source) ||
            throw(ArgumentError("up3_trace_solver_source_differs_from_applied_q"))
        residual = hasproperty(solver, :residual_abs) ?
            Float64(solver.residual_abs) : Float64(solver.residual_norm)
        energy = hasproperty(solver, :energy_balance) ?
            solver.energy_balance : solver.heat_power_balance
        common = (iteration=step.iteration,
            applied_q_W_m3=step.applied,
            maximum_cell_center_temperature_K=step.temperature_K,
            next_q_W_m3=step.next,
            residual_W_m3=step.residual_raw,
            actuator_fraction=feedback.actuator_fraction,
            g1_parameter_hash=feedback.g1_input.parameter_hash,
            g3_source_profile_hash=feedback.g3_source_profile_hash,
            solver_residual_abs=residual,
            solver_energy_balance=energy,
            solver_source_density=source,
            solver_result_hash=step.solver_result_hash)
        if solver_component === :gridap_q1
            merge(common, (q1_residual_abs=Float64(solver.residual_abs),
                q1_energy_balance=solver.energy_balance,
                gridap_q1_result_hash=solver.result_hash))
        else
            merge(common, (fv_result_hash=solver.result_hash,))
        end
    end for step in raw_trace)
    trace = Tuple(begin
        previous = i == 1 ? nothing : trace_values[i - 1]
        row = trace_values[i]
        previous === nothing || row.applied_q_W_m3 == previous.next_q_W_m3 ||
            throw(ArgumentError("up3_trace_applied_q_does_not_follow_previous_feedback"))
        row
    end for i in eachindex(trace_values))
    trace
end

function execute_up3_steady_planar_composition_v1(candidate, g1, g2, g3,
        bundle, spatial_case, admission::FusionConceptAI.CompositionSolveAdmissionV1;
        solver_component::Symbol=:fv)
    stage_asts = _thermal_g1_ast_payload_targets_v1(bundle)
    run_execution() = execute_up3_steady_planar_composition_v1_uncached(
        candidate, g1, g2, g3, bundle, spatial_case, admission;
        solver_component=solver_component)
    stage_asts === nothing && return run_execution()
    FusionConceptAI._with_canonical_json_memo(stage_asts;
            payload_targets=stage_asts) do
        run_execution()
    end
end

function execute_up3_steady_planar_composition_v1_uncached(candidate, g1, g2, g3,
        bundle, spatial_case, admission::FusionConceptAI.CompositionSolveAdmissionV1;
        solver_component::Symbol=:fv)
    admission.input isa FusionConceptAI.CompositionSolveInputV1 &&
        admission.plan isa FusionConceptAI.CompositionSolvePlanV1 ||
        throw(ArgumentError("up3_slab_composition_admission_is_not_typed"))
    binding = admission.input.binding
    protocol = admission.input.protocol
    protocol isa FusionConceptAI.CompositionSolveProtocolV1 ||
        throw(ArgumentError("up3_slab_composition_protocol_is_absent"))
    actual = _up3_slab_components(candidate, g1, g2, g3, bundle, spatial_case;
        solver_component=solver_component)
    r = actual.refs
    binding.candidate_ref == actual.hashes.candidate_ref &&
        binding.provider_ref == r.provider_ref &&
        binding.code_ref == r.code_ref && binding.backend_ref == r.backend_ref &&
        binding.protocol_ref == protocol.protocol_ref ||
        throw(ArgumentError("up3_slab_composition_binding_differs_from_actual_inputs"))
    expected_input = FusionConceptAI.CompositionSolveInputV1(binding,
        actual.components, protocol;
        feedback_edge_keys=actual.feedback_edge_keys)
    admission.input.input_hash == expected_input.input_hash &&
        FusionConceptAI.semantic_view(admission.input) ==
            FusionConceptAI.semantic_view(expected_input) ||
        throw(ArgumentError("up3_slab_selected_nodes_or_ports_do_not_match_actual_inputs"))
    admission.plan.input.input_hash == expected_input.input_hash &&
    FusionConceptAI.semantic_view(admission.plan.input) ==
        FusionConceptAI.semantic_view(expected_input) ||
        throw(ArgumentError("up3_slab_selected_plan_input_does_not_match_actual_inputs"))
    checked = FusionConceptAI.validate_composition_solve_plan(admission.plan)
    expected_admission = FusionConceptAI.admit_composition_solve(expected_input)
    checked.status === :ready && checked.plan_hash == admission.plan.plan_hash &&
        expected_admission.plan isa FusionConceptAI.CompositionSolvePlanV1 &&
        expected_admission.plan.status === :ready &&
        expected_admission.outcome.status === :ready &&
        admission.plan.plan_hash == expected_admission.plan.plan_hash &&
        checked.plan_hash == expected_admission.plan.plan_hash ||
        throw(ArgumentError("up3_slab_composition_plan_not_ready_or_not_reproducible"))
    FusionConceptAI.semantic_view(admission.outcome) ==
        FusionConceptAI.semantic_view(expected_admission.outcome) ||
        throw(ArgumentError("up3_slab_composition_admission_outcome_mismatch"))
    receipt = admission.receipt
    FusionConceptAI.validate_composition_solve_receipt(receipt) &&
        FusionConceptAI.semantic_view(receipt) ==
            FusionConceptAI.semantic_view(expected_admission.receipt) ||
        throw(ArgumentError("up3_slab_composition_admission_receipt_invalid"))

    feedback_declared = up3_temperature_source_feedback_declared_v1(bundle)
    runtime = _up3_slab_execution_bindings_v1(candidate, g1, g2, g3,
        bundle, spatial_case, admission; solver_component=solver_component)
    execution = FusionConceptAI.execute_composition_solve_v1(admission,
        runtime.provider_bindings; feedback_seeds=runtime.feedback_seeds)
    feedback_trace = _up3_slab_iteration_trace_v1(execution.feedback_trace,
        solver_component)
    composition_execution = (
        status=execution.status,
        provider_callback_count=execution.provider_callback_count,
        solver_callback_count=execution.solver_callback_count,
        feedback_trace=feedback_trace,
        resolved_edge_value_hashes=Tuple((edge=FusionConceptAI.semantic_view(x.edge),
            payload_hash=x.value.payload_hash) for x in execution.resolved_edge_values),
        routed_value_audit=Tuple((edge=FusionConceptAI.semantic_view(x.edge),
            producer_slot=x.producer_slot, consumer_slot=x.consumer_slot,
            quantity=x.quantity, unit=x.unit, account=x.account, owner=x.owner,
            producer_ledger_sign=x.producer_ledger_sign,
            consumer_ledger_sign=x.consumer_ledger_sign,
            payload_hash=x.payload_hash, audit_scope=x.audit_scope,
            numeric_value=x.numeric_value,
            signed_balance=x.signed_balance, absolute_error=x.absolute_error,
            status=x.status) for x in execution.routed_value_audit),
        failure_code=execution.failure_code,
        failure_detail=execution.failure_detail)
    if execution.result === nothing
        body = (schema=UP3_STEADY_PLANAR_COMPOSITION_SCHEMA_V1,
            composition_input_hash=expected_input.input_hash,
            composition_plan_hash=checked.plan_hash,
            actual_source_hashes=actual.hashes,
            composition_execution=composition_execution,
            provider_invocation_count=0,
            solver_invocation_count=execution.solver_callback_count,
            claim_ceiling=:screen_only)
        return (status=execution.status, accepted=false,
            composition_input_hash=expected_input.input_hash,
            composition_plan_hash=checked.plan_hash,
            composition_execution=composition_execution,
            provider_invocation_count=0,
            solver_invocation_count=execution.solver_callback_count,
            claim_ceiling=:screen_only, result_hash=canonical_hash(body))
    end
    result = execution.result
    source_proof = result.source_program_audit
    source_proof.schema ===
        SteadyPlanarThermalDiffusionConsumerV1._G1_THERMAL_SOURCE_SCHEMA &&
        source_proof.g1_source_ref == g1.source_ref &&
        source_proof.g2_source_ref == g2.source.source_ref ||
        throw(ArgumentError("up3_slab_embedded_source_proof_does_not_match_selected_G1_G2"))
    source_proof_hash = canonical_hash(source_proof)
    feedback_status = feedback_declared ?
        (execution.status === :executed ? :screen_only : execution.status) :
        :typed_absent
    feedback_reason = !feedback_declared ? :unsupported_feedback_scope :
        (execution.status === :executed ? :residual_tolerance :
            :iteration_limit)
    solver_invocation_count = execution.solver_callback_count
    fixed_point_summary = if feedback_declared
        trace = feedback_trace
        isempty(trace) && throw(ArgumentError("up3_feedback_execution_trace_missing"))
        final_edge = only(x.value for x in execution.resolved_edge_values
            if x.edge.producer_component ==
                only(c.component_ref for c in actual.components
                    if c.outputs isa Tuple && any(p -> p.role === :state, c.outputs)))
        feedback = final_edge.payload.feedback
        (schema="fusionconceptai:runtime-v4:thermal-source-fixed-point-screen-v1",
         status=feedback_status, fixed_point_converged=execution.status === :executed,
         termination=feedback_reason, claim_ceiling=:screen_only,
         candidate_ref=candidate, protocol_ref=protocol.protocol_ref,
         max_iterations=protocol.max_iterations, iteration_count=length(trace),
         residual_tolerance=protocol.residual_tolerance,
         residual_tolerance_unit=_SOURCE_W_M3,
         residual=last(trace).residual_W_m3, residual_unit=_SOURCE_W_M3,
         nonconvergent_policy=protocol.nonconvergent_policy,
         measurement_reduction=:maximum_cell_center,
         measurement_backend=solver_component === :fv ?
             :fv_cell_center_evaluation : :gridap_q1_cell_center_evaluation,
         temperature_K=last(trace).maximum_cell_center_temperature_K,
         applied_q_W_m3=last(trace).applied_q_W_m3,
         next_q_W_m3=last(trace).next_q_W_m3,
         q0_W_m3=feedback.q0_W_m3, q_min_W_m3=feedback.q_min_W_m3,
         q_max_W_m3=feedback.q_max_W_m3,
         actuator_fraction=feedback.actuator_fraction,
         controller_id=feedback.controller_id,
         sensor_port_id=feedback.sensor_port_id,
         actuator_port_id=feedback.actuator_port_id,
         resource_link_id=feedback.resource_link_id,
         resource_port_id=feedback.resource_port_id,
         g3_source_profile_hash=feedback.g3_source_profile_hash,
         g3_source_record_hash=feedback.g3_source_record_hash,
         g1_profile_hash=feedback.g1_profile.profile_hash,
         next_g1_parameter_hash=feedback.g1_input.parameter_hash,
         iteration_trace=trace,
         solver_invocation_count=solver_invocation_count,
         final_solver_result_hash=canonical_hash(result),
         solver_source_density=last(trace).solver_source_density,
         solver_residual_abs=last(trace).solver_residual_abs,
         solver_energy_balance=last(trace).solver_energy_balance,
         final_gridap_q1_result_hash=solver_component === :gridap_q1 ?
             last(trace).gridap_q1_result_hash : nothing)
    else
        nothing
    end
    body = (schema=UP3_STEADY_PLANAR_COMPOSITION_SCHEMA_V1,
        composition_input_hash=expected_input.input_hash,
        composition_plan_hash=checked.plan_hash,
        actual_source_hashes=actual.hashes,
        embedded_source_proof_hash=source_proof_hash,
        thermal_result_hash=result.result_hash,
        feedback_status=feedback_status,
        feedback_reason=feedback_reason,
        composition_execution=composition_execution,
        temperature_source_fixed_point=fixed_point_summary,
        accepted=false, physical_validation=false,
        engineering_validation=false, evidence_credit=0,
        provider_invocation_count=0, solver_invocation_count=solver_invocation_count,
        claim_ceiling=:screen_only)
    merge(result, (composition_input_hash=expected_input.input_hash,
        composition_plan_hash=checked.plan_hash,
        embedded_source_proof_hash=source_proof_hash,
        status=feedback_declared ? feedback_status : result.status,
        feedback_status=feedback_status,
        feedback_reason=feedback_reason,
        composition_execution=composition_execution,
        accepted=false, physical_validation=false,
        engineering_validation=false, evidence_credit=0,
        provider_invocation_count=body.provider_invocation_count,
        solver_invocation_count=body.solver_invocation_count,
        result_hash=canonical_hash(body)),
        feedback_declared ? (temperature_source_fixed_point=fixed_point_summary,) :
            NamedTuple())
end


end # module
