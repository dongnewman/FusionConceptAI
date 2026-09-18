"""UP4-02B reduced engineering-feedback execution, additive R14.

This slice executes only a candidate-bound reduced SI envelope.  It consumes a
hash-validated upstream `CandidateEngineeringExecutionV4` sample, but never
promotes a sampled plasma rho-interface traction to a component load: the
upstream `component_load=false` limitation is retained in every result.

The loop is deliberately small and auditable:
source supply -> Joule heating -> cooling/material response -> structure ->
geometry/resistance.  It produces an iteration trace, energy/thermal/
mechanical/material ledgers and residuals.  It is a screen only: accepted is
always false, the claim ceiling is `screen_only`, and no UP4/R01--R10 credit
is issued.
"""

import FusionConceptAI: Digest256, digest256_text, canonical_hash, semantic_view

const UP4_02B_SCHEMA = "fusionconceptai:up4-02b-engineering-feedback-execution-v1"
const UP4_02B_REVISION = "UP4-02B-ENGINEERING-FEEDBACK-EXECUTION-V1-R14"
const UP4_02B_CLAIM_CEILING = :screen_only
const UP4_02B_STATUSES = (:pass, :fail_closed, :terminal_deferred,
    :numerical_fail, :physical_fail, :program_exception)
const UP4_02B_FAILURE_CODES = (
    :forged_identity, :candidate_mismatch, :scenario_mismatch, :g3_mismatch,
    :upstream_execution_hash_mismatch, :load_sample_hash_mismatch,
    :component_load_not_admitted, :missing_source, :missing_return,
    :missing_heat_sink, :missing_cooling, :unit_mismatch, :owner_mismatch,
    :direction_mismatch, :capacity_exceeded, :yield_exceeded, :nonfinite,
    :iteration_limit, :forged_residual, :double_counted_heat,
    :load_sample_membership_mismatch, :independent_traction_difference_mismatch,
    :invalid_envelope, :invalid_upstream, :missing_shir, :missing_bridge,
    :scenario_reuse_mismatch, :bridge_shir_resource_mismatch,
    :temperature_exceeded, :stress_exceeded, :clearance_exceeded,
    :energy_residual_exceeded, :thermal_residual_exceeded,
    :force_residual_exceeded, :material_residual_exceeded)

struct EngineeringFeedbackExecutionInputError <: Exception
    code::Symbol
    detail::String
end
Base.showerror(io::IO, e::EngineeringFeedbackExecutionInputError) =
    print(io, "UP4-02B input [", e.code, "]: ", e.detail)
_up4_02b_error(message) = EngineeringFeedbackExecutionInputError(:malformed_input, String(message))

_up4_02b_digest(x, label) = x isa Digest256 ? x : throw(_up4_02b_error("$label must be Digest256"))
_up4_02b_text(x, label) = x isa AbstractString && !isempty(strip(String(x))) && isvalid(String(x)) ?
    String(x) : throw(_up4_02b_error("$label must be non-empty UTF-8"))
_up4_02b_finite(x, label) = x isa Real && !(x isa Bool) && isfinite(Float64(x)) ?
    Float64(x) : throw(_up4_02b_error("$label must be finite"))
_up4_02b_positive(x, label) = _up4_02b_finite(x, label) > 0 ? Float64(x) :
    throw(_up4_02b_error("$label must be positive"))
_up4_02b_nonnegative(x, label) = _up4_02b_finite(x, label) >= 0 ? Float64(x) :
    throw(_up4_02b_error("$label must be non-negative"))
_up4_02b_tuple(x, label) = x isa Tuple ? x : throw(_up4_02b_error("$label must be a tuple"))

"""Local closed projection of the exact CandidatePlasmaLoadSampleV4 fields.

This projection is an additive receipt boundary, not a replacement for the
upstream provider type or a component-solid authority; the result remains a
screen only.
"""
struct EngineeringFeedbackCandidatePlasmaLoadSampleRefV1
    upstream_sample_hash::Digest256
    interface_id::String
    region_id::String
    side::Symbol
    pressure_Pa::Float64
    B_xyz_T::NTuple{3,Float64}
    outward_normal_xyz::NTuple{3,Float64}
    mu0_N_A2::Float64
    magnetic_energy_density_J_m3::Float64
    momentum_flux_xyz_Pa::NTuple{3,NTuple{3,Float64}}
    traction_xyz_Pa::NTuple{3,Float64}
    normal_traction_Pa::Float64
    tangential_traction_xyz_Pa::NTuple{3,Float64}
    independent_traction_difference_Pa::Float64
    spatial_scope::Symbol
    component_load::Bool
    sample_hash::Digest256
    candidate_hash::Digest256
    scenario_hash::Digest256
    g3_hash::Digest256
    function EngineeringFeedbackCandidatePlasmaLoadSampleRefV1(upstream_sample_hash,
            interface_id, region_id, side, pressure_Pa, B_xyz_T, outward_normal_xyz,
            mu0_N_A2, magnetic_energy_density_J_m3, momentum_flux_xyz_Pa,
            traction_xyz_Pa, normal_traction_Pa, tangential_traction_xyz_Pa,
            independent_traction_difference_Pa, spatial_scope, component_load,
            sample_hash, candidate_hash, scenario_hash, g3_hash)
        component_load === false || throw(EngineeringFeedbackExecutionInputError(
            :component_load_not_admitted, "CandidatePlasmaLoadSampleV4 component_load must be false"))
        new(upstream_sample_hash, String(interface_id), String(region_id), Symbol(side),
            Float64(pressure_Pa), Tuple(Float64.(B_xyz_T)), Tuple(Float64.(outward_normal_xyz)),
            Float64(mu0_N_A2), Float64(magnetic_energy_density_J_m3),
            Tuple(Tuple(Float64.(row)) for row in momentum_flux_xyz_Pa),
            Tuple(Float64.(traction_xyz_Pa)), Float64(normal_traction_Pa),
            Tuple(Float64.(tangential_traction_xyz_Pa)),
            Float64(independent_traction_difference_Pa), Symbol(spatial_scope), false,
            sample_hash, candidate_hash, scenario_hash, g3_hash)
    end
end
function _up4_02b_sample_body(x::EngineeringFeedbackCandidatePlasmaLoadSampleRefV1)
    (revision=UP4_02B_REVISION, upstream_sample_hash=x.upstream_sample_hash,
        interface_id=x.interface_id, region_id=x.region_id, side=x.side,
        pressure_Pa=x.pressure_Pa, B_xyz_T=x.B_xyz_T,
        outward_normal_xyz=x.outward_normal_xyz, mu0_N_A2=x.mu0_N_A2,
        magnetic_energy_density_J_m3=x.magnetic_energy_density_J_m3,
        momentum_flux_xyz_Pa=x.momentum_flux_xyz_Pa,
        traction_xyz_Pa=x.traction_xyz_Pa, normal_traction_Pa=x.normal_traction_Pa,
        tangential_traction_xyz_Pa=x.tangential_traction_xyz_Pa,
        independent_traction_difference_Pa=x.independent_traction_difference_Pa,
        spatial_scope=x.spatial_scope, component_load=x.component_load,
        candidate_hash=x.candidate_hash, scenario_hash=x.scenario_hash,
        g3_hash=x.g3_hash)
end
semantic_view(x::EngineeringFeedbackCandidatePlasmaLoadSampleRefV1) = _up4_02b_sample_body(x)
function canonical_hash(x::EngineeringFeedbackCandidatePlasmaLoadSampleRefV1)
    x.side in (:minus, :plus) && x.spatial_scope === :sampled_plasma_rho_interface ||
        throw(EngineeringFeedbackExecutionInputError(:invalid_upstream, "load sample scope/side mismatch"))
    x.component_load === false || throw(EngineeringFeedbackExecutionInputError(
        :component_load_not_admitted, "upstream component_load must remain false"))
    all(isfinite, (x.pressure_Pa, x.B_xyz_T..., x.outward_normal_xyz..., x.mu0_N_A2,
        x.magnetic_energy_density_J_m3, x.traction_xyz_Pa..., x.normal_traction_Pa,
        x.tangential_traction_xyz_Pa..., x.independent_traction_difference_Pa)) ||
        throw(EngineeringFeedbackExecutionInputError(:nonfinite, "load sample is non-finite"))
    x.pressure_Pa >= 0 && x.mu0_N_A2 > 0 || throw(EngineeringFeedbackExecutionInputError(
        :invalid_upstream, "load sample pressure/permeability is invalid"))
    isapprox(sum(abs2, x.outward_normal_xyz), 1.0; rtol=0, atol=1e-9) ||
        throw(EngineeringFeedbackExecutionInputError(:invalid_upstream, "load normal is not unit length"))
    energy = sum(abs2, x.B_xyz_T)/(2*x.mu0_N_A2)
    tensor = ntuple(i -> ntuple(j -> Float64((i == j ? x.pressure_Pa+energy : 0.0) -
        x.B_xyz_T[i]*x.B_xyz_T[j]/x.mu0_N_A2), 3), 3)
    traction = ntuple(i -> sum(tensor[i][j]*x.outward_normal_xyz[j] for j in 1:3), 3)
    normal = sum(traction[i]*x.outward_normal_xyz[i] for i in 1:3)
    tangent = ntuple(i -> traction[i]-normal*x.outward_normal_xyz[i], 3)
    independent_difference = maximum(abs(traction[i] - x.traction_xyz_Pa[i]) for i in 1:3)
    x.independent_traction_difference_Pa >= 0 || throw(EngineeringFeedbackExecutionInputError(
        :independent_traction_difference_mismatch,
        "stored independent traction difference must be non-negative"))
    isapprox(energy, x.magnetic_energy_density_J_m3; rtol=0, atol=1e-10) &&
        all(isapprox(tensor[i][j], x.momentum_flux_xyz_Pa[i][j]; rtol=0, atol=1e-10) for i in 1:3 for j in 1:3) &&
        all(isapprox(traction[i], x.traction_xyz_Pa[i]; rtol=0, atol=1e-10) for i in 1:3) &&
        isapprox(normal, x.normal_traction_Pa; rtol=0, atol=1e-10) &&
        all(isapprox(tangent[i], x.tangential_traction_xyz_Pa[i]; rtol=0, atol=1e-10) for i in 1:3) &&
        independent_difference >= 0 &&
        isapprox(independent_difference, x.independent_traction_difference_Pa; rtol=0, atol=1e-10) ||
        throw(EngineeringFeedbackExecutionInputError(:forged_identity,
            "load sample constitutive replay mismatch"))
    expected = canonical_hash(_up4_02b_sample_body(x))
    expected == x.sample_hash || throw(EngineeringFeedbackExecutionInputError(
        :forged_identity, "load sample hash mismatch"))
    expected
end

"""Closed projection of the exact CandidateEngineeringExecutionV4 identity fields."""
struct EngineeringFeedbackCandidateEngineeringExecutionRefV1
    revision::String
    context_hash::Digest256
    candidate_hash::Digest256
    scenario_hash::Digest256
    g3_hash::Digest256
    samples::Tuple{Vararg{EngineeringFeedbackCandidatePlasmaLoadSampleRefV1}}
    load_projection_status::Symbol
    load_projection_executed::Bool
    result_hash::Digest256
end
function _up4_02b_upstream_body(x::EngineeringFeedbackCandidateEngineeringExecutionRefV1)
    (revision=x.revision, context_hash=x.context_hash, candidate_hash=x.candidate_hash,
        scenario_hash=x.scenario_hash, g3_hash=x.g3_hash, samples=x.samples,
        load_projection_status=x.load_projection_status,
        load_projection_executed=x.load_projection_executed)
end
semantic_view(x::EngineeringFeedbackCandidateEngineeringExecutionRefV1) = _up4_02b_upstream_body(x)
function canonical_hash(x::EngineeringFeedbackCandidateEngineeringExecutionRefV1)
    x.revision == "candidate-engineering-execution-v4-1" &&
        x.load_projection_executed && x.load_projection_status === :pointwise_physics_load_projection_executed ||
        throw(EngineeringFeedbackExecutionInputError(:invalid_upstream, "upstream execution status mismatch"))
    isempty(x.samples) && throw(EngineeringFeedbackExecutionInputError(:invalid_upstream, "upstream has no samples"))
    foreach(canonical_hash, x.samples)
    all(s -> s.candidate_hash == x.candidate_hash && s.scenario_hash == x.scenario_hash &&
        s.g3_hash == x.g3_hash, x.samples) || throw(EngineeringFeedbackExecutionInputError(
        :forged_identity, "upstream/sample identity mismatch"))
    expected = canonical_hash(_up4_02b_upstream_body(x))
    expected == x.result_hash || throw(EngineeringFeedbackExecutionInputError(
        :forged_identity, "upstream execution hash mismatch"))
    expected
end

function _up4_02b_sample_membership(upstream::EngineeringFeedbackCandidateEngineeringExecutionRefV1,
        sample::EngineeringFeedbackCandidatePlasmaLoadSampleRefV1)
    sample_hash = canonical_hash(sample)
    exact = any(upstream.samples) do candidate_sample
        candidate_hash = canonical_hash(candidate_sample)
        candidate_hash == sample_hash &&
            candidate_sample.upstream_sample_hash == sample.upstream_sample_hash &&
            candidate_sample.interface_id == sample.interface_id &&
            candidate_sample.region_id == sample.region_id &&
            candidate_sample.side == sample.side &&
            candidate_sample.pressure_Pa == sample.pressure_Pa &&
            candidate_sample.B_xyz_T == sample.B_xyz_T &&
            candidate_sample.outward_normal_xyz == sample.outward_normal_xyz &&
            candidate_sample.mu0_N_A2 == sample.mu0_N_A2 &&
            candidate_sample.magnetic_energy_density_J_m3 == sample.magnetic_energy_density_J_m3 &&
            candidate_sample.momentum_flux_xyz_Pa == sample.momentum_flux_xyz_Pa &&
            candidate_sample.traction_xyz_Pa == sample.traction_xyz_Pa &&
            candidate_sample.normal_traction_Pa == sample.normal_traction_Pa &&
            candidate_sample.tangential_traction_xyz_Pa == sample.tangential_traction_xyz_Pa &&
            candidate_sample.independent_traction_difference_Pa == sample.independent_traction_difference_Pa &&
            candidate_sample.spatial_scope == sample.spatial_scope &&
            candidate_sample.component_load == sample.component_load &&
            candidate_sample.sample_hash == sample.sample_hash &&
            candidate_sample.candidate_hash == sample.candidate_hash &&
            candidate_sample.scenario_hash == sample.scenario_hash &&
            candidate_sample.g3_hash == sample.g3_hash
    end
    exact || throw(EngineeringFeedbackExecutionInputError(:load_sample_membership_mismatch,
        "load sample is not an exact member of upstream execution samples"))
    true
end

struct EngineeringFeedbackTypedResourceRefV1
    kind::Symbol
    status::Symbol
    unit::Symbol
    direction::Symbol
    owner_scope::String
    content_hash::Digest256
    ref_hash::Digest256
end
function _up4_02b_resource_body(x::EngineeringFeedbackTypedResourceRefV1)
    (revision=UP4_02B_REVISION, kind=x.kind, status=x.status, unit=x.unit,
        direction=x.direction, owner_scope=x.owner_scope, content_hash=x.content_hash)
end
semantic_view(x::EngineeringFeedbackTypedResourceRefV1) = _up4_02b_resource_body(x)
canonical_hash(x::EngineeringFeedbackTypedResourceRefV1) = begin
    x.status in (:present, :typed_absent, :unknown) || throw(_up4_02b_error("invalid resource status"))
    x.direction in (:in, :out, :bidirectional, :passive) || throw(_up4_02b_error("invalid resource direction"))
    expected = canonical_hash(_up4_02b_resource_body(x))
    expected == x.ref_hash || throw(EngineeringFeedbackExecutionInputError(:forged_identity, "resource hash mismatch"))
    expected
end

struct EngineeringFeedbackSHIRRefV1
    contract_hash::Digest256
    candidate_hash::Digest256
    scenario_hash::Digest256
    g3_hash::Digest256
    source::EngineeringFeedbackTypedResourceRefV1
    return_ref::EngineeringFeedbackTypedResourceRefV1
    heat_sink::EngineeringFeedbackTypedResourceRefV1
    cooling::EngineeringFeedbackTypedResourceRefV1
    closure_hash::Digest256
end
struct EngineeringFeedbackBridgeRefV1
    contract_hash::Digest256
    candidate_hash::Digest256
    scenario_hash::Digest256
    g3_hash::Digest256
    resources::Tuple{Vararg{EngineeringFeedbackTypedResourceRefV1}}
    closure_hash::Digest256
end
function _up4_02b_contract_body(x::Union{EngineeringFeedbackSHIRRefV1,EngineeringFeedbackBridgeRefV1})
    (revision=UP4_02B_REVISION, candidate_hash=x.candidate_hash, scenario_hash=x.scenario_hash,
        g3_hash=x.g3_hash, resources=x isa EngineeringFeedbackSHIRRefV1 ?
            (x.source, x.return_ref, x.heat_sink, x.cooling) : x.resources)
end
semantic_view(x::Union{EngineeringFeedbackSHIRRefV1,EngineeringFeedbackBridgeRefV1}) =
    _up4_02b_contract_body(x)
function canonical_hash(x::EngineeringFeedbackSHIRRefV1)
    foreach(canonical_hash, (x.source, x.return_ref, x.heat_sink, x.cooling))
    expected = canonical_hash(_up4_02b_contract_body(x))
    expected == x.closure_hash == x.contract_hash || throw(EngineeringFeedbackExecutionInputError(
        :forged_identity, "SHIR closure/hash mismatch"))
    expected
end
function canonical_hash(x::EngineeringFeedbackBridgeRefV1)
    isempty(x.resources) && throw(EngineeringFeedbackExecutionInputError(:missing_bridge, "bridge has no resources"))
    foreach(canonical_hash, x.resources)
    expected = canonical_hash(_up4_02b_contract_body(x))
    expected == x.closure_hash == x.contract_hash || throw(EngineeringFeedbackExecutionInputError(
        :forged_identity, "bridge closure/hash mismatch"))
    expected
end
function _up4_02b_join_resource_hashes(request)
    shir_refs = (request.shir_contract.source, request.shir_contract.return_ref,
        request.shir_contract.heat_sink, request.shir_contract.cooling)
    length(request.bridge_contract.resources) == length(shir_refs) ||
        throw(EngineeringFeedbackExecutionInputError(:bridge_shir_resource_mismatch,
            "bridge resource closure has unexpected cardinality"))
    bridge_by_kind = Dict(r.kind => r for r in request.bridge_contract.resources)
    length(bridge_by_kind) == length(shir_refs) || throw(EngineeringFeedbackExecutionInputError(
        :bridge_shir_resource_mismatch, "bridge resource kinds are duplicated"))
    foreach(shir_refs) do s
        haskey(bridge_by_kind, s.kind) || throw(EngineeringFeedbackExecutionInputError(
            :bridge_shir_resource_mismatch, "bridge is missing SHIR resource kind $(s.kind)"))
        b = bridge_by_kind[s.kind]
        (b.ref_hash == s.ref_hash && b.content_hash == s.content_hash &&
            b.status == s.status && b.unit == s.unit && b.direction == s.direction &&
            b.owner_scope == s.owner_scope) || throw(EngineeringFeedbackExecutionInputError(
            :bridge_shir_resource_mismatch, "bridge/SHIR resource closure differs for $(s.kind)"))
    end
    true
end

"""Candidate-bound reduced SI engineering envelope.

`mechanical_load_N` is an explicit reduced-envelope input.  It is not inferred
from the sampled upstream pressure/B traction because that sample is always
marked `component_load=false`.
"""
struct EngineeringFeedbackReducedSIEnvelopeV1
    candidate_hash::Digest256
    scenario_hash::Digest256
    g3_hash::Digest256
    load_sample_hash::Digest256
    owner_scope::String
    voltage_V::Float64
    resistance_ohm::Float64
    resistance_temp_coeff_per_K::Float64
    reference_temperature_K::Float64
    ambient_temperature_K::Float64
    thermal_conductance_W_K::Float64
    thermal_capacity_J_K::Float64
    time_step_s::Float64
    max_temperature_K::Float64
    mass_kg::Float64
    heat_capacity_J_kg_K::Float64
    yield_stress_Pa::Float64
    yield_softening_per_K::Float64
    elastic_modulus_Pa::Float64
    thermal_expansion_per_K::Float64
    length_m::Float64
    area_m2::Float64
    stiffness_N_m::Float64
    support_stiffness_N_m::Float64
    mechanical_load_N::Float64
    clearance_m::Float64
    current_capacity_A::Float64
    source_capacity_W::Float64
    cooling_capacity_W::Float64
    declared_heat_W::Float64
    heat_includes_joule::Bool
    envelope_hash::Digest256
    function EngineeringFeedbackReducedSIEnvelopeV1(candidate_hash, scenario_hash,
            g3_hash, load_sample_hash, owner_scope, voltage_V, resistance_ohm,
            resistance_temp_coeff_per_K, reference_temperature_K,
            ambient_temperature_K, thermal_conductance_W_K, thermal_capacity_J_K,
            time_step_s, max_temperature_K, mass_kg, heat_capacity_J_kg_K, yield_stress_Pa,
            yield_softening_per_K, elastic_modulus_Pa, thermal_expansion_per_K,
            length_m, area_m2, stiffness_N_m, support_stiffness_N_m, mechanical_load_N, clearance_m,
            current_capacity_A, source_capacity_W, cooling_capacity_W,
            declared_heat_W, heat_includes_joule, envelope_hash)
        vals = (voltage_V, resistance_ohm, resistance_temp_coeff_per_K,
            reference_temperature_K, ambient_temperature_K,
            thermal_conductance_W_K, thermal_capacity_J_K, time_step_s, max_temperature_K,
            mass_kg, heat_capacity_J_kg_K, yield_stress_Pa, yield_softening_per_K,
            elastic_modulus_Pa, thermal_expansion_per_K, length_m, area_m2,
            stiffness_N_m, support_stiffness_N_m, mechanical_load_N, clearance_m, current_capacity_A,
            source_capacity_W, cooling_capacity_W, declared_heat_W)
        if all(isfinite(Float64(x)) for x in vals)
            all(Float64(x) >= 0 for x in (resistance_ohm, thermal_conductance_W_K,
                thermal_capacity_J_K, time_step_s, mass_kg, heat_capacity_J_kg_K, yield_stress_Pa,
                elastic_modulus_Pa, length_m, area_m2, stiffness_N_m, support_stiffness_N_m,
                mechanical_load_N, clearance_m, current_capacity_A,
                source_capacity_W, cooling_capacity_W, declared_heat_W)) ||
                throw(_up4_02b_error("envelope has negative SI value"))
            Float64(voltage_V) > 0 && Float64(resistance_ohm) > 0 &&
                Float64(thermal_conductance_W_K) > 0 && Float64(thermal_capacity_J_K) > 0 &&
                Float64(time_step_s) > 0 && Float64(mass_kg) > 0 &&
                Float64(heat_capacity_J_kg_K) > 0 && Float64(yield_stress_Pa) > 0 &&
                Float64(elastic_modulus_Pa) > 0 && Float64(length_m) > 0 &&
                Float64(area_m2) > 0 && Float64(stiffness_N_m) > 0 &&
                Float64(support_stiffness_N_m) > 0 && Float64(current_capacity_A) > 0 &&
                Float64(source_capacity_W) > 0 && Float64(cooling_capacity_W) > 0 ||
                throw(_up4_02b_error("envelope capacity/geometry is zero"))
            Float64(max_temperature_K) >= Float64(ambient_temperature_K) >= 0 ||
                throw(_up4_02b_error("temperature bounds are invalid"))
            Float64(yield_softening_per_K) >= 0 && Float64(thermal_expansion_per_K) >= 0 ||
                throw(_up4_02b_error("material coefficients must be non-negative"))
        end
        new(_up4_02b_digest(candidate_hash, "candidate hash"),
            _up4_02b_digest(scenario_hash, "scenario hash"),
            _up4_02b_digest(g3_hash, "G3 hash"),
            _up4_02b_digest(load_sample_hash, "load sample hash"),
            _up4_02b_text(owner_scope, "owner scope"), map(Float64, vals)...,
            Bool(heat_includes_joule), _up4_02b_digest(envelope_hash, "envelope hash"))
    end
end

function _up4_02b_envelope_body(x::EngineeringFeedbackReducedSIEnvelopeV1)
    (schema=UP4_02B_SCHEMA, revision=UP4_02B_REVISION,
        candidate_hash=x.candidate_hash, scenario_hash=x.scenario_hash,
        g3_hash=x.g3_hash, load_sample_hash=x.load_sample_hash,
        owner_scope=x.owner_scope, voltage_V=x.voltage_V,
        resistance_ohm=x.resistance_ohm,
        resistance_temp_coeff_per_K=x.resistance_temp_coeff_per_K,
        reference_temperature_K=x.reference_temperature_K,
        ambient_temperature_K=x.ambient_temperature_K,
        thermal_conductance_W_K=x.thermal_conductance_W_K,
        thermal_capacity_J_K=x.thermal_capacity_J_K,
        time_step_s=x.time_step_s,
        max_temperature_K=x.max_temperature_K, mass_kg=x.mass_kg,
        heat_capacity_J_kg_K=x.heat_capacity_J_kg_K,
        yield_stress_Pa=x.yield_stress_Pa,
        yield_softening_per_K=x.yield_softening_per_K,
        elastic_modulus_Pa=x.elastic_modulus_Pa,
        thermal_expansion_per_K=x.thermal_expansion_per_K,
        length_m=x.length_m, area_m2=x.area_m2, stiffness_N_m=x.stiffness_N_m,
        support_stiffness_N_m=x.support_stiffness_N_m,
        mechanical_load_N=x.mechanical_load_N, clearance_m=x.clearance_m,
        current_capacity_A=x.current_capacity_A, source_capacity_W=x.source_capacity_W,
        cooling_capacity_W=x.cooling_capacity_W, declared_heat_W=x.declared_heat_W,
        heat_includes_joule=x.heat_includes_joule)
end
semantic_view(x::EngineeringFeedbackReducedSIEnvelopeV1) =
    merge(_up4_02b_envelope_body(x), (envelope_hash=x.envelope_hash,))
canonical_hash(x::EngineeringFeedbackReducedSIEnvelopeV1) = begin
    all(isfinite, (x.voltage_V, x.resistance_ohm, x.resistance_temp_coeff_per_K,
        x.reference_temperature_K, x.ambient_temperature_K, x.thermal_conductance_W_K,
        x.thermal_capacity_J_K, x.time_step_s, x.max_temperature_K, x.mass_kg,
        x.heat_capacity_J_kg_K, x.yield_stress_Pa, x.yield_softening_per_K,
        x.elastic_modulus_Pa, x.thermal_expansion_per_K, x.length_m, x.area_m2,
        x.stiffness_N_m, x.support_stiffness_N_m, x.mechanical_load_N, x.clearance_m,
        x.current_capacity_A, x.source_capacity_W, x.cooling_capacity_W,
        x.declared_heat_W)) || throw(EngineeringFeedbackExecutionInputError(
        :nonfinite, "engineering envelope has non-finite SI value"))
    expected = canonical_hash(_up4_02b_envelope_body(x))
    expected == x.envelope_hash || throw(ArgumentError("engineering envelope hash mismatch"))
    expected
end

"""Closed execution request; all upstream and contract objects are typed refs."""
struct EngineeringFeedbackExecutionRequestV1
    upstream_execution::EngineeringFeedbackCandidateEngineeringExecutionRefV1
    load_sample::EngineeringFeedbackCandidatePlasmaLoadSampleRefV1
    upstream_execution_hash::Digest256
    load_sample_hash::Digest256
    shir_hash::Digest256
    bridge_hash::Digest256
    candidate_hash::Digest256
    scenario_hash::Digest256
    g3_hash::Digest256
    shir_contract::EngineeringFeedbackSHIRRefV1
    bridge_contract::EngineeringFeedbackBridgeRefV1
    envelope::EngineeringFeedbackReducedSIEnvelopeV1
    max_iterations::Int
    tolerance::Float64
    request_hash::Digest256
end

function _up4_02b_request_body(x::EngineeringFeedbackExecutionRequestV1)
    (schema=UP4_02B_SCHEMA, revision=UP4_02B_REVISION,
        upstream_execution_hash=x.upstream_execution_hash,
        load_sample_hash=x.load_sample_hash, shir_hash=x.shir_hash,
        bridge_hash=x.bridge_hash, candidate_hash=x.candidate_hash,
        scenario_hash=x.scenario_hash, g3_hash=x.g3_hash,
        envelope=x.envelope, max_iterations=x.max_iterations,
        tolerance=x.tolerance)
end
semantic_view(x::EngineeringFeedbackExecutionRequestV1) =
    merge(_up4_02b_request_body(x), (request_hash=x.request_hash,))
canonical_hash(x::EngineeringFeedbackExecutionRequestV1) = begin
    canonical_hash(x.upstream_execution)
    canonical_hash(x.load_sample)
    _up4_02b_sample_membership(x.upstream_execution, x.load_sample)
    canonical_hash(x.shir_contract)
    canonical_hash(x.bridge_contract)
    canonical_hash(x.envelope)
    x.upstream_execution_hash == x.upstream_execution.result_hash ||
        throw(EngineeringFeedbackExecutionInputError(:upstream_execution_hash_mismatch, "request upstream hash mismatch"))
    x.load_sample_hash == x.load_sample.sample_hash == x.envelope.load_sample_hash ||
        throw(EngineeringFeedbackExecutionInputError(:load_sample_hash_mismatch, "request sample hash mismatch"))
    x.candidate_hash == x.upstream_execution.candidate_hash == x.envelope.candidate_hash ==
        x.shir_contract.candidate_hash == x.bridge_contract.candidate_hash ||
        throw(EngineeringFeedbackExecutionInputError(:candidate_mismatch, "request candidate hash mismatch"))
    x.scenario_hash == x.upstream_execution.scenario_hash == x.envelope.scenario_hash ==
        x.shir_contract.scenario_hash == x.bridge_contract.scenario_hash ||
        throw(EngineeringFeedbackExecutionInputError(:scenario_mismatch, "request scenario hash mismatch"))
    x.g3_hash == x.upstream_execution.g3_hash == x.envelope.g3_hash ==
        x.shir_contract.g3_hash == x.bridge_contract.g3_hash ||
        throw(EngineeringFeedbackExecutionInputError(:g3_mismatch, "request G3 hash mismatch"))
    x.shir_hash == x.shir_contract.contract_hash ||
        throw(EngineeringFeedbackExecutionInputError(:forged_identity, "request SHIR hash mismatch"))
    x.bridge_hash == x.bridge_contract.contract_hash ||
        throw(EngineeringFeedbackExecutionInputError(:forged_identity, "request bridge hash mismatch"))
    _up4_02b_join_resource_hashes(x)
    expected = canonical_hash(_up4_02b_request_body(x))
    expected == x.request_hash || throw(ArgumentError("engineering execution request hash mismatch"))
    expected
end

"""Build a request with a sealed request hash; validation is deferred to execute."""
function engineering_feedback_request(upstream_execution, load_sample,
        envelope::EngineeringFeedbackReducedSIEnvelopeV1;
        upstream_execution_hash=canonical_hash(upstream_execution),
        load_sample_hash=canonical_hash(load_sample), shir_hash=digest256_text("missing-shir"),
        bridge_hash=digest256_text("missing-bridge"),
        candidate_hash=envelope.candidate_hash, scenario_hash=envelope.scenario_hash,
        g3_hash=envelope.g3_hash, shir_contract, bridge_contract,
        max_iterations=50, tolerance=1e-8)
    mi = max_iterations isa Integer && !(max_iterations isa Bool) ? Int(max_iterations) :
        throw(_up4_02b_error("max_iterations must be integer"))
    mi > 0 || throw(_up4_02b_error("max_iterations must be positive"))
    tol = _up4_02b_positive(tolerance, "tolerance")
    body = (schema=UP4_02B_SCHEMA, revision=UP4_02B_REVISION,
        upstream_execution_hash=_up4_02b_digest(upstream_execution_hash, "upstream execution hash"),
        load_sample_hash=_up4_02b_digest(load_sample_hash, "load sample hash"),
        shir_hash=_up4_02b_digest(shir_hash, "SHIR hash"),
        bridge_hash=_up4_02b_digest(bridge_hash, "bridge hash"),
        candidate_hash=_up4_02b_digest(candidate_hash, "candidate hash"),
        scenario_hash=_up4_02b_digest(scenario_hash, "scenario hash"),
        g3_hash=_up4_02b_digest(g3_hash, "G3 hash"), envelope=envelope,
        max_iterations=mi, tolerance=tol)
    EngineeringFeedbackExecutionRequestV1(upstream_execution, load_sample,
        body.upstream_execution_hash, body.load_sample_hash, body.shir_hash,
        body.bridge_hash, body.candidate_hash, body.scenario_hash, body.g3_hash,
        shir_contract, bridge_contract, envelope, mi, tol, canonical_hash(body))
end

struct EngineeringFeedbackIterationV1
    iteration::Int
    supply_power_W::Float64
    current_A::Float64
    resistance_ohm::Float64
    joule_heat_W::Float64
    cooling_W::Float64
    temperature_K::Float64
    allowable_stress_Pa::Float64
    stress_Pa::Float64
    displacement_m::Float64
    geometry_factor::Float64
    internal_reaction_N::Float64
    support_reaction_N::Float64
    energy_residual_W::Float64
    thermal_residual_W::Float64
    force_residual_N::Float64
    material_residual_Pa::Float64
    state_change::Float64
    iteration_hash::Digest256
end
function _up4_02b_iteration_body(x::EngineeringFeedbackIterationV1)
    (revision=UP4_02B_REVISION, iteration=x.iteration,
        supply_power_W=x.supply_power_W, current_A=x.current_A,
        resistance_ohm=x.resistance_ohm, joule_heat_W=x.joule_heat_W,
        cooling_W=x.cooling_W, temperature_K=x.temperature_K,
        allowable_stress_Pa=x.allowable_stress_Pa, stress_Pa=x.stress_Pa,
        displacement_m=x.displacement_m, geometry_factor=x.geometry_factor,
        internal_reaction_N=x.internal_reaction_N, support_reaction_N=x.support_reaction_N,
        energy_residual_W=x.energy_residual_W, thermal_residual_W=x.thermal_residual_W,
        force_residual_N=x.force_residual_N, material_residual_Pa=x.material_residual_Pa,
        state_change=x.state_change)
end
semantic_view(x::EngineeringFeedbackIterationV1) =
    merge(_up4_02b_iteration_body(x), (iteration_hash=x.iteration_hash,))
canonical_hash(x::EngineeringFeedbackIterationV1) = begin
    expected = canonical_hash(_up4_02b_iteration_body(x))
    expected == x.iteration_hash || throw(ArgumentError("iteration hash mismatch"))
    expected
end

struct EngineeringFeedbackLedgerEntryV1
    role::Symbol
    amount::Float64
    sign::Int8
    unit::Symbol
    owner_scope::String
    entry_hash::Digest256
end
function _up4_02b_entry_body(x::EngineeringFeedbackLedgerEntryV1)
    (revision=UP4_02B_REVISION, role=x.role, amount=x.amount, sign=x.sign,
        unit=x.unit, owner_scope=x.owner_scope)
end
semantic_view(x::EngineeringFeedbackLedgerEntryV1) =
    merge(_up4_02b_entry_body(x), (entry_hash=x.entry_hash,))
canonical_hash(x::EngineeringFeedbackLedgerEntryV1) = begin
    x.amount >= 0 && x.sign in (-1, 1) || throw(ArgumentError("invalid ledger entry"))
    expected = canonical_hash(_up4_02b_entry_body(x))
    expected == x.entry_hash || throw(ArgumentError("ledger entry hash mismatch"))
    expected
end

struct EngineeringFeedbackLedgerV1
    kind::Symbol
    entries::Tuple{Vararg{EngineeringFeedbackLedgerEntryV1}}
    residual::Float64
    unit::Symbol
    owner_scope::String
    ledger_hash::Digest256
end
function _up4_02b_ledger_body(x::EngineeringFeedbackLedgerV1)
    (revision=UP4_02B_REVISION, kind=x.kind, entries=x.entries,
        residual=x.residual, unit=x.unit, owner_scope=x.owner_scope)
end
semantic_view(x::EngineeringFeedbackLedgerV1) =
    merge(_up4_02b_ledger_body(x), (ledger_hash=x.ledger_hash,))
canonical_hash(x::EngineeringFeedbackLedgerV1) = begin
    x.kind in (:energy, :thermal, :mechanical, :material) ||
        throw(ArgumentError("invalid ledger kind"))
    foreach(canonical_hash, x.entries)
    signed = sum((Float64(e.sign) * e.amount for e in x.entries); init=0.0)
    isapprox(signed, x.residual; rtol=0, atol=1e-12) ||
        throw(ArgumentError("forged residual in ledger"))
    expected = canonical_hash(_up4_02b_ledger_body(x))
    expected == x.ledger_hash || throw(ArgumentError("ledger hash mismatch"))
    expected
end

struct EngineeringFeedbackHardGatesV1
    energy::Bool
    thermal::Bool
    force::Bool
    material::Bool
    source_capacity::Bool
    current_capacity::Bool
    cooling_capacity::Bool
    temperature::Bool
    yield_strength::Bool
    clearance::Bool
    gates_hash::Digest256
end
function _up4_02b_gates_body(x::EngineeringFeedbackHardGatesV1)
    (revision=UP4_02B_REVISION, energy=x.energy, thermal=x.thermal,
        force=x.force, material=x.material, source_capacity=x.source_capacity,
        current_capacity=x.current_capacity, cooling_capacity=x.cooling_capacity,
        temperature=x.temperature, yield_strength=x.yield_strength,
        clearance=x.clearance)
end
semantic_view(x::EngineeringFeedbackHardGatesV1) =
    merge(_up4_02b_gates_body(x), (gates_hash=x.gates_hash,))
canonical_hash(x::EngineeringFeedbackHardGatesV1) = begin
    expected = canonical_hash(_up4_02b_gates_body(x))
    expected == x.gates_hash || throw(ArgumentError("hard-gate hash mismatch"))
    expected
end

struct EngineeringFeedbackDiagnosticsV1
    temperature_max_K::Float64
    stress_max_Pa::Float64
    clearance_used_m::Float64
    support_reaction_N::Float64
    force_residual_N::Float64
    energy_residual_W::Float64
    thermal_residual_W::Float64
    material_residual_Pa::Float64
    diagnostics_hash::Digest256
end
function _up4_02b_diagnostics_body(x::EngineeringFeedbackDiagnosticsV1)
    (revision=UP4_02B_REVISION, temperature_max_K=x.temperature_max_K,
        stress_max_Pa=x.stress_max_Pa, clearance_used_m=x.clearance_used_m,
        support_reaction_N=x.support_reaction_N, force_residual_N=x.force_residual_N,
        energy_residual_W=x.energy_residual_W, thermal_residual_W=x.thermal_residual_W,
        material_residual_Pa=x.material_residual_Pa)
end
semantic_view(x::EngineeringFeedbackDiagnosticsV1) =
    merge(_up4_02b_diagnostics_body(x), (diagnostics_hash=x.diagnostics_hash,))
canonical_hash(x::EngineeringFeedbackDiagnosticsV1) = begin
    all(isfinite, (x.temperature_max_K, x.stress_max_Pa, x.clearance_used_m,
        x.support_reaction_N, x.force_residual_N, x.energy_residual_W,
        x.thermal_residual_W, x.material_residual_Pa)) ||
        throw(EngineeringFeedbackExecutionInputError(:nonfinite, "diagnostic is non-finite"))
    expected = canonical_hash(_up4_02b_diagnostics_body(x))
    expected == x.diagnostics_hash || throw(EngineeringFeedbackExecutionInputError(
        :forged_residual, "diagnostic residual hash mismatch"))
    expected
end

struct EngineeringFeedbackResidualVectorV1
    energy_W::Float64
    thermal_W::Float64
    force_N::Float64
    material_Pa::Float64
    state_change::Float64
    converged::Bool
    residual_hash::Digest256
end
function _up4_02b_residual_body(x::EngineeringFeedbackResidualVectorV1)
    (revision=UP4_02B_REVISION, energy_W=x.energy_W, thermal_W=x.thermal_W,
        force_N=x.force_N, material_Pa=x.material_Pa, state_change=x.state_change,
        converged=x.converged)
end
semantic_view(x::EngineeringFeedbackResidualVectorV1) = _up4_02b_residual_body(x)
canonical_hash(x::EngineeringFeedbackResidualVectorV1) = begin
    all(isfinite, (x.energy_W, x.thermal_W, x.force_N, x.material_Pa, x.state_change)) ||
        throw(EngineeringFeedbackExecutionInputError(:nonfinite, "residual vector is non-finite"))
    expected = canonical_hash(_up4_02b_residual_body(x))
    expected == x.residual_hash || throw(EngineeringFeedbackExecutionInputError(
        :forged_residual, "residual vector hash mismatch"))
    expected
end

struct EngineeringFeedbackExecutionV1
    schema::String
    revision::String
    status::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    engineering_credit::Symbol
    physical_credit::Symbol
    r01_r10_credit::Symbol
    candidate_hash::Digest256
    scenario_hash::Digest256
    g3_hash::Digest256
    shir_hash::Digest256
    bridge_hash::Digest256
    upstream_execution_hash::Digest256
    load_sample_hash::Digest256
    component_load::Bool
    component_load_admitted::Bool
    limitation::String
    iteration_trace::Tuple{Vararg{EngineeringFeedbackIterationV1}}
    ledgers::Tuple{Vararg{EngineeringFeedbackLedgerV1}}
    residuals::EngineeringFeedbackResidualVectorV1
    diagnostics::EngineeringFeedbackDiagnosticsV1
    hard_gates::EngineeringFeedbackHardGatesV1
    failures::Tuple{Vararg{Symbol}}
    exception_detail::String
    execution_hash::Digest256
end
function _up4_02b_execution_body(x::EngineeringFeedbackExecutionV1)
    (schema=x.schema, revision=x.revision, status=x.status, accepted=x.accepted,
        claim_ceiling=x.claim_ceiling, engineering_credit=x.engineering_credit,
        physical_credit=x.physical_credit, r01_r10_credit=x.r01_r10_credit,
        candidate_hash=x.candidate_hash, scenario_hash=x.scenario_hash,
        g3_hash=x.g3_hash, shir_hash=x.shir_hash, bridge_hash=x.bridge_hash,
        upstream_execution_hash=x.upstream_execution_hash,
        load_sample_hash=x.load_sample_hash, component_load=x.component_load,
        component_load_admitted=x.component_load_admitted, limitation=x.limitation,
        iteration_trace=x.iteration_trace, ledgers=x.ledgers, residuals=x.residuals,
        diagnostics=x.diagnostics,
        hard_gates=x.hard_gates, failures=x.failures, exception_detail=x.exception_detail)
end
semantic_view(x::EngineeringFeedbackExecutionV1) =
    merge(_up4_02b_execution_body(x), (execution_hash=x.execution_hash,))
canonical_hash(x::EngineeringFeedbackExecutionV1) = begin
    x.schema == UP4_02B_SCHEMA && x.revision == UP4_02B_REVISION ||
        throw(ArgumentError("engineering execution schema/revision mismatch"))
    x.status in UP4_02B_STATUSES || throw(ArgumentError("invalid engineering execution status"))
    x.accepted === false && x.claim_ceiling === UP4_02B_CLAIM_CEILING ||
        throw(ArgumentError("UP4-02B cannot issue acceptance"))
    x.engineering_credit === :none && x.physical_credit === :none &&
        x.r01_r10_credit === :none || throw(ArgumentError("UP4-02B credit must remain none"))
    x.component_load === false && !x.component_load_admitted && !isempty(x.limitation) ||
        throw(ArgumentError("component-load limitation was erased"))
    foreach(canonical_hash, x.iteration_trace); foreach(canonical_hash, x.ledgers)
    canonical_hash(x.residuals)
    canonical_hash(x.diagnostics)
    canonical_hash(x.hard_gates)
    expected = canonical_hash(_up4_02b_execution_body(x))
    expected == x.execution_hash || throw(ArgumentError("engineering execution hash mismatch"))
    expected
end

function _up4_02b_contract_hash(x, expected, label)
    got = try canonical_hash(x) catch e
        throw(EngineeringFeedbackExecutionInputError(:forged_identity, "$label cannot be hash validated: $e"))
    end
    got == expected || throw(EngineeringFeedbackExecutionInputError(:forged_identity, "$label hash mismatch"))
    got
end
function _up4_02b_binding_audit(contract, request, label)
    contract.candidate_hash == request.candidate_hash || throw(EngineeringFeedbackExecutionInputError(:candidate_mismatch, "$label candidate mismatch"))
    contract.scenario_hash == request.scenario_hash || throw(EngineeringFeedbackExecutionInputError(:scenario_mismatch, "$label scenario mismatch"))
    contract.g3_hash == request.g3_hash || throw(EngineeringFeedbackExecutionInputError(:g3_mismatch, "$label G3 mismatch"))
    true
end
function _up4_02b_resource_audit(request)
    failures = Symbol[]
    shir = request.shir_contract
    all_refs = (shir.source, shir.return_ref, shir.heat_sink, shir.cooling)
    for (ref, code) in zip(all_refs, (:missing_source, :missing_return, :missing_heat_sink, :missing_cooling))
        ref.status === :present || push!(failures, code)
    end
    foreach(ref -> begin
        ref.unit === :W || push!(failures, :unit_mismatch)
        owner = ref.owner_scope
        owner == request.envelope.owner_scope || push!(failures, :owner_mismatch)
        ref.direction in (:in, :out, :bidirectional) || push!(failures, :direction_mismatch)
    end, all_refs)
    expected_kinds = (:source, :return, :heat_sink, :cooling)
    all(k -> any(r -> r.kind === k, request.bridge_contract.resources), expected_kinds) ||
        push!(failures, :missing_bridge)
    Tuple(unique(failures))
end

function _up4_02b_make_entry(role, amount, sign, unit, owner)
    a = Float64(amount)
    body = (revision=UP4_02B_REVISION, role=role, amount=a, sign=Int8(sign),
        unit=unit, owner_scope=owner)
    EngineeringFeedbackLedgerEntryV1(role, a, Int8(sign), unit, owner, canonical_hash(body))
end
function _up4_02b_make_ledger(kind, entries, unit, owner)
    es = Tuple(entries)
    residual = sum((Float64(e.sign) * e.amount for e in es); init=0.0)
    body = (revision=UP4_02B_REVISION, kind=kind, entries=es, residual=residual,
        unit=unit, owner_scope=owner)
    EngineeringFeedbackLedgerV1(kind, es, residual, unit, owner, canonical_hash(body))
end
function _up4_02b_make_gates(values)
    gates_hash = canonical_hash((revision=UP4_02B_REVISION,
        energy=values[1], thermal=values[2], force=values[3], material=values[4],
        source_capacity=values[5], current_capacity=values[6], cooling_capacity=values[7],
        temperature=values[8], yield_strength=values[9], clearance=values[10]))
    EngineeringFeedbackHardGatesV1(values[1], values[2], values[3], values[4],
        values[5], values[6], values[7], values[8], values[9], values[10], gates_hash)
end
function _up4_02b_make_residuals(energy, thermal, force, material, state_change, converged)
    body = (revision=UP4_02B_REVISION, energy_W=Float64(energy), thermal_W=Float64(thermal),
        force_N=Float64(force), material_Pa=Float64(material), state_change=Float64(state_change),
        converged=Bool(converged))
    EngineeringFeedbackResidualVectorV1(body.energy_W, body.thermal_W, body.force_N,
        body.material_Pa, body.state_change, body.converged, canonical_hash(body))
end

function _up4_02b_empty_result(request, status, failures; exception_detail="")
    r = request.envelope
    residuals = _up4_02b_make_residuals(0.0, 0.0, 0.0, 0.0, 0.0, false)
    # Failure receipts retain non-finite residual sentinels but use finite
    # diagnostic placeholders so their receipt remains hashable.
    diagnostic_body = (revision=UP4_02B_REVISION, temperature_max_K=0.0, stress_max_Pa=0.0,
        clearance_used_m=0.0, support_reaction_N=0.0, force_residual_N=0.0,
        energy_residual_W=0.0, thermal_residual_W=0.0, material_residual_Pa=0.0)
    diagnostics = EngineeringFeedbackDiagnosticsV1(diagnostic_body.temperature_max_K,
        diagnostic_body.stress_max_Pa, diagnostic_body.clearance_used_m,
        diagnostic_body.support_reaction_N, diagnostic_body.force_residual_N,
        diagnostic_body.energy_residual_W, diagnostic_body.thermal_residual_W,
        diagnostic_body.material_residual_Pa, canonical_hash(diagnostic_body))
    gates = _up4_02b_make_gates((false, false, false, false, false, false, false, false, false, false))
    body = (schema=UP4_02B_SCHEMA, revision=UP4_02B_REVISION, status=status,
        accepted=false, claim_ceiling=UP4_02B_CLAIM_CEILING, engineering_credit=:none,
        physical_credit=:none, r01_r10_credit=:none, candidate_hash=r.candidate_hash,
        scenario_hash=r.scenario_hash, g3_hash=r.g3_hash, shir_hash=request.shir_hash,
        bridge_hash=request.bridge_hash, upstream_execution_hash=request.upstream_execution_hash,
        load_sample_hash=request.load_sample_hash, component_load=false,
        component_load_admitted=false,
        limitation="Upstream rho-interface sample has component_load=false; no component load was inferred.",
        iteration_trace=(), ledgers=(), residuals=residuals, diagnostics=diagnostics, hard_gates=gates,
        failures=Tuple(unique(Symbol.(failures))), exception_detail=String(exception_detail))
    EngineeringFeedbackExecutionV1(UP4_02B_SCHEMA, UP4_02B_REVISION, status, false,
        UP4_02B_CLAIM_CEILING, :none, :none, :none, r.candidate_hash, r.scenario_hash,
        r.g3_hash, request.shir_hash, request.bridge_hash, request.upstream_execution_hash,
        request.load_sample_hash, false, false, body.limitation, (), (), residuals,
        diagnostics, gates, body.failures, body.exception_detail, canonical_hash(body))
end

"""Execute the reduced SI fixed-point screen and return a no-credit receipt."""
function execute_engineering_feedback(request::EngineeringFeedbackExecutionRequestV1)
    try
        canonical_hash(request)
        r = request.envelope
        canonical_hash(r)
        actual_upstream_hash = canonical_hash(request.upstream_execution)
        actual_upstream_hash == request.upstream_execution_hash ||
            return _up4_02b_empty_result(request, :fail_closed, (:upstream_execution_hash_mismatch,))
        actual_sample_hash = canonical_hash(request.load_sample)
        actual_sample_hash == request.load_sample_hash == r.load_sample_hash ||
            return _up4_02b_empty_result(request, :fail_closed, (:load_sample_hash_mismatch,))
        up_candidate = request.upstream_execution.candidate_hash
        up_scenario = request.upstream_execution.scenario_hash
        up_g3 = request.upstream_execution.g3_hash
        up_candidate == r.candidate_hash || return _up4_02b_empty_result(request, :fail_closed, (:candidate_mismatch, :forged_identity))
        up_scenario == r.scenario_hash || return _up4_02b_empty_result(request, :fail_closed, (:scenario_mismatch, :scenario_reuse_mismatch))
        up_g3 == r.g3_hash || return _up4_02b_empty_result(request, :fail_closed, (:g3_mismatch, :forged_identity))
        component = request.load_sample.component_load
        limitation = "Upstream rho-interface sample has component_load=false; no component load was inferred."
        component && return _up4_02b_empty_result(request, :fail_closed, (:component_load_not_admitted,))
        _up4_02b_contract_hash(request.shir_contract, request.shir_hash, "SHIR")
        _up4_02b_binding_audit(request.shir_contract, request, "SHIR")
        _up4_02b_contract_hash(request.bridge_contract, request.bridge_hash, "bridge")
        _up4_02b_binding_audit(request.bridge_contract, request, "bridge")
        resource_failures = _up4_02b_resource_audit(request)
        isempty(resource_failures) || return _up4_02b_empty_result(request,
            any(x -> x in (:missing_bridge,), resource_failures) ? :terminal_deferred : :fail_closed,
            resource_failures)
        r.heat_includes_joule && r.declared_heat_W > 0 &&
            return _up4_02b_empty_result(request, :fail_closed, (:double_counted_heat,))

        trace = EngineeringFeedbackIterationV1[]
        T = r.ambient_temperature_K
        geom = 1.0
        converged = false
        heat_capacity_total = r.thermal_capacity_J_K + r.mass_kg*r.heat_capacity_J_kg_K
        for k in 1:request.max_iterations
            resistance = r.resistance_ohm * geom * max(0.0,
                1 + r.resistance_temp_coeff_per_K * (T-r.reference_temperature_K))
            resistance > 0 && isfinite(resistance) || return _up4_02b_empty_result(request,
                :numerical_fail, (:nonfinite,))
            current = r.voltage_V / resistance
            supply = r.voltage_V * current
            joule = current^2 * resistance
            heat_input = joule + r.declared_heat_W
            Tnew = (heat_input + heat_capacity_total/r.time_step_s*T +
                r.thermal_conductance_W_K*r.ambient_temperature_K) /
                (heat_capacity_total/r.time_step_s + r.thermal_conductance_W_K)
            cooling = r.thermal_conductance_W_K * max(0.0, Tnew-r.ambient_temperature_K)
            allowable = r.yield_stress_Pa * max(0.0,
                1 - r.yield_softening_per_K * max(0.0, Tnew-r.reference_temperature_K))
            stress = r.mechanical_load_N / r.area_m2 +
                r.elastic_modulus_Pa * r.thermal_expansion_per_K * max(0.0, Tnew-r.reference_temperature_K)
            # The structural update is coupled to the prior geometry.  The
            # reactions are then evaluated at the updated geometry, so force
            # balance is an independently solved residual rather than a
            # quantity constructed to zero.
            elastic_displacement = r.mechanical_load_N /
                (r.stiffness_N_m * geom + r.support_stiffness_N_m)
            displacement = elastic_displacement +
                r.thermal_expansion_per_K * r.length_m * max(0.0, Tnew-r.reference_temperature_K)
            geom_new = 1 + displacement / r.length_m
            state_change = max(abs(Tnew-T), abs(geom_new-geom))
            energy_residual = supply-joule
            storage_power = heat_capacity_total*(Tnew-T)/r.time_step_s
            thermal_residual = heat_input-cooling-storage_power
            thermal_stress = r.elastic_modulus_Pa * r.thermal_expansion_per_K *
                max(0.0, Tnew-r.reference_temperature_K)
            internal_reaction = r.stiffness_N_m*geom_new*elastic_displacement
            support_reaction = r.support_stiffness_N_m*elastic_displacement
            force_residual = internal_reaction + support_reaction-r.mechanical_load_N
            # Signed inequality residual: <=0 is below the temperature-adjusted yield.
            material_residual = stress-allowable
            all(isfinite, (current, supply, joule, cooling, Tnew, allowable, stress,
                displacement, geom_new, state_change, energy_residual, thermal_residual,
                force_residual, material_residual)) || return _up4_02b_empty_result(request,
                :numerical_fail, (:nonfinite,))
            body = (revision=UP4_02B_REVISION, iteration=k, supply_power_W=supply,
                current_A=current, resistance_ohm=resistance, joule_heat_W=joule,
                cooling_W=cooling, temperature_K=Tnew, allowable_stress_Pa=allowable,
                stress_Pa=stress, displacement_m=displacement, geometry_factor=geom_new,
                internal_reaction_N=internal_reaction, support_reaction_N=support_reaction,
                energy_residual_W=energy_residual, thermal_residual_W=thermal_residual,
                force_residual_N=force_residual, material_residual_Pa=material_residual,
                state_change=state_change)
            push!(trace, EngineeringFeedbackIterationV1(k, supply, current, resistance,
                joule, cooling, Tnew, allowable, stress, displacement, geom_new,
                internal_reaction, support_reaction,
                energy_residual, thermal_residual, force_residual, material_residual,
                state_change, canonical_hash(body)))
            T, geom = Tnew, geom_new
            converged = maximum(abs.((energy_residual, thermal_residual, force_residual,
                state_change))) <= request.tolerance && material_residual <= 0
            converged && break
        end
        final_iteration = Base.last(trace)
        gates = _up4_02b_make_gates((
            abs(final_iteration.energy_residual_W) <= request.tolerance,
            abs(final_iteration.thermal_residual_W) <= request.tolerance,
            abs(final_iteration.force_residual_N) <= request.tolerance,
            final_iteration.material_residual_Pa <= 0,
            final_iteration.supply_power_W <= r.source_capacity_W,
            final_iteration.current_A <= r.current_capacity_A,
            final_iteration.cooling_W <= r.cooling_capacity_W,
            final_iteration.temperature_K <= r.max_temperature_K,
            final_iteration.stress_Pa <= final_iteration.allowable_stress_Pa,
            final_iteration.displacement_m <= r.clearance_m))
        physical = gates.source_capacity && gates.current_capacity && gates.cooling_capacity &&
            gates.temperature && gates.yield_strength && gates.clearance
        numerical = gates.energy && gates.thermal && gates.force && gates.material && converged
        status = !physical ? :physical_fail : !numerical ? :numerical_fail : :pass
        failures = Symbol[]
        !gates.source_capacity && push!(failures, :capacity_exceeded)
        !gates.current_capacity && push!(failures, :capacity_exceeded)
        !gates.cooling_capacity && push!(failures, :capacity_exceeded)
        !gates.temperature && push!(failures, :temperature_exceeded)
        !gates.yield_strength && (push!(failures, :yield_exceeded); push!(failures, :stress_exceeded))
        !gates.clearance && push!(failures, :clearance_exceeded)
        !gates.energy && push!(failures, :energy_residual_exceeded)
        !gates.thermal && push!(failures, :thermal_residual_exceeded)
        !gates.force && push!(failures, :force_residual_exceeded)
        !gates.material && push!(failures, :material_residual_exceeded)
        !converged && push!(failures, :iteration_limit)
        residuals = _up4_02b_make_residuals(final_iteration.energy_residual_W,
            final_iteration.thermal_residual_W, final_iteration.force_residual_N,
            final_iteration.material_residual_Pa, final_iteration.state_change, converged)
        energy_entries = (_up4_02b_make_entry(:source, final_iteration.supply_power_W, 1, :W, r.owner_scope),
            _up4_02b_make_entry(:joule_heat, final_iteration.joule_heat_W, -1, :W, r.owner_scope))
        storage_power = (r.thermal_capacity_J_K + r.mass_kg*r.heat_capacity_J_kg_K) *
            (final_iteration.temperature_K - (length(trace) == 1 ? r.ambient_temperature_K : trace[end-1].temperature_K)) / r.time_step_s
        thermal_entries = (_up4_02b_make_entry(:joule_heat, final_iteration.joule_heat_W, 1, :W, r.owner_scope),
            _up4_02b_make_entry(:declared_heat, r.declared_heat_W, 1, :W, r.owner_scope),
            _up4_02b_make_entry(:cooling, final_iteration.cooling_W, -1, :W, r.owner_scope),
            _up4_02b_make_entry(:thermal_storage, storage_power, -1, :W, r.owner_scope))
        mechanical_entries = (_up4_02b_make_entry(:load, r.mechanical_load_N, 1, :N, r.owner_scope),
            _up4_02b_make_entry(:internal_reaction, final_iteration.internal_reaction_N, -1, :N, r.owner_scope),
            _up4_02b_make_entry(:support_reaction, final_iteration.support_reaction_N, -1, :N, r.owner_scope))
        material_entries = (_up4_02b_make_entry(:allowable_capacity, final_iteration.allowable_stress_Pa, 1, :Pa, r.owner_scope),
            _up4_02b_make_entry(:applied_stress, final_iteration.stress_Pa, -1, :Pa, r.owner_scope))
        ledgers = (_up4_02b_make_ledger(:energy, energy_entries, :W, r.owner_scope),
            _up4_02b_make_ledger(:thermal, thermal_entries, :W, r.owner_scope),
            _up4_02b_make_ledger(:mechanical, mechanical_entries, :N, r.owner_scope),
            _up4_02b_make_ledger(:material, material_entries, :Pa, r.owner_scope))
        diagnostic_body = (revision=UP4_02B_REVISION,
            temperature_max_K=final_iteration.temperature_K, stress_max_Pa=final_iteration.stress_Pa,
            clearance_used_m=final_iteration.displacement_m,
            support_reaction_N=final_iteration.support_reaction_N,
            force_residual_N=final_iteration.force_residual_N,
            energy_residual_W=final_iteration.energy_residual_W,
            thermal_residual_W=final_iteration.thermal_residual_W,
            material_residual_Pa=final_iteration.material_residual_Pa)
        diagnostics = EngineeringFeedbackDiagnosticsV1(diagnostic_body.temperature_max_K,
            diagnostic_body.stress_max_Pa, diagnostic_body.clearance_used_m,
            diagnostic_body.support_reaction_N, diagnostic_body.force_residual_N,
            diagnostic_body.energy_residual_W, diagnostic_body.thermal_residual_W,
            diagnostic_body.material_residual_Pa, canonical_hash(diagnostic_body))
        body = (schema=UP4_02B_SCHEMA, revision=UP4_02B_REVISION, status=status,
            accepted=false, claim_ceiling=UP4_02B_CLAIM_CEILING, engineering_credit=:none,
            physical_credit=:none, r01_r10_credit=:none, candidate_hash=r.candidate_hash,
            scenario_hash=r.scenario_hash, g3_hash=r.g3_hash, shir_hash=request.shir_hash,
            bridge_hash=request.bridge_hash, upstream_execution_hash=request.upstream_execution_hash,
            load_sample_hash=request.load_sample_hash, component_load=false,
            component_load_admitted=false, limitation=limitation, iteration_trace=Tuple(trace),
            ledgers=ledgers, residuals=residuals, diagnostics=diagnostics, hard_gates=gates,
            failures=Tuple(unique(failures)), exception_detail="")
        result = EngineeringFeedbackExecutionV1(UP4_02B_SCHEMA, UP4_02B_REVISION, status,
            false, UP4_02B_CLAIM_CEILING, :none, :none, :none, r.candidate_hash,
            r.scenario_hash, r.g3_hash, request.shir_hash, request.bridge_hash,
            request.upstream_execution_hash, request.load_sample_hash, false, false,
            limitation, Tuple(trace), ledgers, residuals, diagnostics, gates, body.failures, "",
            canonical_hash(body))
        canonical_hash(result)
        result
    catch e
        e isa EngineeringFeedbackExecutionInputError || return _up4_02b_empty_result(request,
            :program_exception, (:invalid_envelope,); exception_detail=string(e))
        status = e.code in (:nonfinite, :iteration_limit) ? :numerical_fail : :fail_closed
        _up4_02b_empty_result(request, status, (e.code,); exception_detail=e.detail)
    end
end

"""Recheck an execution receipt independently; tampered residuals fail closed."""
function validate_engineering_feedback_residuals(result::EngineeringFeedbackExecutionV1)
    try
        canonical_hash(result)
        foreach(canonical_hash, result.ledgers)
        result
    catch e
        detail = e isa EngineeringFeedbackExecutionInputError ? e.detail : string(e)
        _up4_02b_empty_result_from_result(result, :fail_closed, (:forged_residual,); exception_detail=detail)
    end
end

function _up4_02b_empty_result_from_result(result::EngineeringFeedbackExecutionV1, status, failures; exception_detail="")
    body = _up4_02b_execution_body(result)
    residuals = _up4_02b_make_residuals(0.0, 0.0, 0.0, 0.0, 0.0, false)
    diagnostic_body = (revision=UP4_02B_REVISION, temperature_max_K=0.0, stress_max_Pa=0.0,
        clearance_used_m=0.0, support_reaction_N=0.0, force_residual_N=0.0,
        energy_residual_W=0.0, thermal_residual_W=0.0, material_residual_Pa=0.0)
    diagnostics = EngineeringFeedbackDiagnosticsV1(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        canonical_hash(diagnostic_body))
    gates = _up4_02b_make_gates((false, false, false, false, false, false, false, false, false, false))
    final_body = merge(body, (status=status, iteration_trace=(), ledgers=(), residuals=residuals,
        diagnostics=diagnostics, hard_gates=gates, failures=Tuple(failures),
        exception_detail=String(exception_detail)))
    EngineeringFeedbackExecutionV1(result.schema, result.revision, status, false,
        UP4_02B_CLAIM_CEILING, :none, :none, :none, result.candidate_hash,
        result.scenario_hash, result.g3_hash, result.shir_hash, result.bridge_hash,
        result.upstream_execution_hash, result.load_sample_hash, false, false,
        result.limitation, (), (), residuals, diagnostics, gates, Tuple(failures),
        String(exception_detail), canonical_hash(final_body))
end

const execute_engineering_feedback_execution = execute_engineering_feedback
const validate_engineering_feedback_execution = execute_engineering_feedback
const run_engineering_feedback_execution = execute_engineering_feedback
