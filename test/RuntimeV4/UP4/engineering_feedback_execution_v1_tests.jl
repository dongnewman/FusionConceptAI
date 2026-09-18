using Test
using JSON3
using FusionConceptAI

const _UP4_02B_SOURCE = normpath(joinpath(@__DIR__, "../../../src/RuntimeV4/EngineeringFeedbackExecutionV1.jl"))
@assert isfile(_UP4_02B_SOURCE)
include(_UP4_02B_SOURCE)

_up4b_d(s) = digest256_text(String(s))

function _up4b_sample(candidate, scenario, g3; mutation=:positive)
    # Positive fixture values are built from p=1, B=(0.1,0,0.2), mu0=1 and
    # n=(1,0,0), rather than supplied as an unrelated self-consistent tensor.
    B = (0.1, 0.0, 0.2); n = (1.0, 0.0, 0.0)
    tensor = ((1.015, 0.0, -0.02), (0.0, 1.025, 0.0), (-0.02, 0.0, 0.985))
    traction = (1.015, 0.0, -0.02)
    body = (revision=UP4_02B_REVISION, upstream_sample_hash=_up4b_d("upstream-sample"),
        interface_id="fixture.interface", region_id="fixture.region", side=:minus,
        pressure_Pa=1.0, B_xyz_T=B, outward_normal_xyz=n, mu0_N_A2=1.0,
        magnetic_energy_density_J_m3=0.025, momentum_flux_xyz_Pa=tensor,
        traction_xyz_Pa=traction, normal_traction_Pa=1.015,
        tangential_traction_xyz_Pa=(0.0, 0.0, -0.02),
        independent_traction_difference_Pa=mutation === :negative_stored_difference ? -1e-12 : 0.0,
        spatial_scope=:sampled_plasma_rho_interface, component_load=false,
        candidate_hash=candidate, scenario_hash=scenario, g3_hash=g3)
    interface_id = mutation === :foreign_sample ? "foreign.interface" : "fixture.interface"
    body = merge(body, (interface_id=interface_id,))
    sample_hash = mutation === :forged_identity ? _up4b_d("forged-sample") : canonical_hash(body)
    EngineeringFeedbackCandidatePlasmaLoadSampleRefV1(body.upstream_sample_hash,
        body.interface_id, body.region_id, body.side, body.pressure_Pa, body.B_xyz_T,
        body.outward_normal_xyz, body.mu0_N_A2, body.magnetic_energy_density_J_m3,
        body.momentum_flux_xyz_Pa, body.traction_xyz_Pa, body.normal_traction_Pa,
        body.tangential_traction_xyz_Pa, body.independent_traction_difference_Pa,
        body.spatial_scope, body.component_load, sample_hash, body.candidate_hash,
        body.scenario_hash, body.g3_hash)
end

function _up4b_upstream(sample, candidate, scenario, g3; mutation=:positive)
    body = (revision="candidate-engineering-execution-v4-1",
        context_hash=_up4b_d("context"), candidate_hash=candidate,
        scenario_hash=scenario, g3_hash=g3, samples=(sample,),
        load_projection_status=:pointwise_physics_load_projection_executed,
        load_projection_executed=true)
    result_hash = mutation === :forged_identity ? _up4b_d("forged-upstream") : canonical_hash(body)
    EngineeringFeedbackCandidateEngineeringExecutionRefV1(body.revision, body.context_hash,
        body.candidate_hash, body.scenario_hash, body.g3_hash, body.samples,
        body.load_projection_status, body.load_projection_executed, result_hash)
end

function _up4b_resource(kind; mutation=:positive)
    unit = mutation === :unit_mismatch && kind === :source ? :V : :W
    direction = mutation === :direction_mismatch && kind === :source ? :passive :
        kind === :source || kind === :cooling ? :in : :out
    owner = mutation === :owner_mismatch && kind === :source ? "foreign-owner" : "fixture-owner"
    status = mutation === Symbol("missing_" * String(kind)) ? :typed_absent : :present
    content_hash = _up4b_d("content:" * String(kind))
    body = (revision=UP4_02B_REVISION, kind=kind, status=status, unit=unit,
        direction=direction, owner_scope=owner, content_hash=content_hash)
    EngineeringFeedbackTypedResourceRefV1(kind, status, unit, direction, owner,
        content_hash, canonical_hash(body))
end

function _up4b_contracts(candidate, scenario, g3; mutation=:positive)
    source = _up4b_resource(:source; mutation)
    return_ref = _up4b_resource(:return; mutation=mutation === :missing_return ? :missing_return : :positive)
    heat = _up4b_resource(:heat_sink; mutation=mutation === :missing_heat_sink ? :missing_heat_sink : :positive)
    cooling = _up4b_resource(:cooling; mutation=mutation === :missing_cooling ? :missing_cooling : :positive)
    shir_body = (revision=UP4_02B_REVISION, candidate_hash=candidate, scenario_hash=scenario,
        g3_hash=g3, resources=(source, return_ref, heat, cooling))
    shir_hash = canonical_hash(shir_body)
    shir = EngineeringFeedbackSHIRRefV1(shir_hash, candidate, scenario, g3,
        source, return_ref, heat, cooling, shir_hash)
    resources = (source, return_ref, heat, cooling)
    bridge_body = (revision=UP4_02B_REVISION, candidate_hash=candidate,
        scenario_hash=scenario, g3_hash=g3, resources=resources)
    bridge_hash = canonical_hash(bridge_body)
    bridge = EngineeringFeedbackBridgeRefV1(bridge_hash, candidate, scenario, g3,
        resources, bridge_hash)
    shir, bridge
end

function _up4b_envelope(candidate, scenario, g3, sample; mutation=:positive)
    source_capacity = mutation === :capacity_exceeded ? 1.0 : 100.0
    yield_stress = mutation === :yield_exceeded ? 1.0 : 2.0e8
    fields = (candidate_hash=candidate, scenario_hash=scenario, g3_hash=g3,
        load_sample_hash=sample.sample_hash, owner_scope="fixture-owner",
        voltage_V=10.0, resistance_ohm=2.0, resistance_temp_coeff_per_K=0.003,
        reference_temperature_K=300.0, ambient_temperature_K=300.0,
        thermal_conductance_W_K=100.0, thermal_capacity_J_K=1.0, time_step_s=1.0,
        max_temperature_K=500.0, mass_kg=1.0, heat_capacity_J_kg_K=1.0,
        yield_stress_Pa=yield_stress, yield_softening_per_K=0.001,
        elastic_modulus_Pa=1.0e11, thermal_expansion_per_K=1.0e-5,
        length_m=1.0, area_m2=0.01, stiffness_N_m=1.0e7,
        support_stiffness_N_m=1.0e7, mechanical_load_N=1000.0, clearance_m=0.01,
        current_capacity_A=20.0, source_capacity_W=source_capacity,
        cooling_capacity_W=100.0, declared_heat_W=mutation === :double_counted_heat ? 1.0 : 0.0,
        heat_includes_joule=mutation === :double_counted_heat)
    if mutation === :nonfinite
        fields = merge(fields, (resistance_ohm=NaN,))
    end
    body = (schema=UP4_02B_SCHEMA, revision=UP4_02B_REVISION, fields...)
    envelope_hash = mutation === :nonfinite ? _up4b_d("forged-nonfinite-envelope") : canonical_hash(body)
    EngineeringFeedbackReducedSIEnvelopeV1(fields..., envelope_hash)
end

function _up4b_request(; mutation=:positive)
    candidate, scenario, g3 = _up4b_d("candidate"), _up4b_d("scenario"), _up4b_d("g3")
    upstream_scenario = mutation === :scenario_mismatch ? _up4b_d("foreign-scenario") : scenario
    upstream_g3 = mutation === :g3_mismatch ? _up4b_d("foreign-g3") : g3
    sample = _up4b_sample(candidate, upstream_scenario, upstream_g3; mutation)
    upstream_sample = mutation in (:foreign_sample, :negative_stored_difference) ?
        _up4b_sample(candidate, upstream_scenario, upstream_g3; mutation=:positive) : sample
    upstream = _up4b_upstream(upstream_sample, candidate, upstream_scenario, upstream_g3;
        mutation=mutation in (:foreign_sample, :negative_stored_difference) ? :positive : mutation)
    shir, bridge = _up4b_contracts(candidate, scenario, g3; mutation)
    envelope = _up4b_envelope(candidate, scenario, g3, sample; mutation)
    if mutation === :negative_stored_difference
        return EngineeringFeedbackExecutionRequestV1(upstream, sample, upstream.result_hash,
            sample.sample_hash, shir.contract_hash, bridge.contract_hash, candidate, scenario, g3,
            shir, bridge, envelope, 50, 1e-8, _up4b_d("negative-stored-difference-request"))
    end
    engineering_feedback_request(upstream, sample, envelope;
        upstream_execution_hash=mutation === :upstream_execution_hash_mismatch ? _up4b_d("forged-upstream") : upstream.result_hash,
        load_sample_hash=mutation === :load_sample_hash_mismatch ? _up4b_d("forged-sample") : sample.sample_hash,
        shir_hash=shir.contract_hash, bridge_hash=bridge.contract_hash,
        candidate_hash=candidate, scenario_hash=scenario, g3_hash=g3,
        shir_contract=shir, bridge_contract=bridge,
        max_iterations=mutation === :iteration_limit ? 1 : 50, tolerance=1e-8)
end

@testset "UP4-02B reduced engineering-feedback execution V1 R14" begin
    fixture = JSON3.read(read(joinpath(@__DIR__, "engineering_feedback_execution_v1_fixture.json")))
    request = _up4b_request()
    @test canonical_hash(request) == request.request_hash
    result = execute_engineering_feedback(request)
    @test result.status === :pass
    @test !result.accepted && result.claim_ceiling === :screen_only
    @test result.engineering_credit === result.physical_credit === result.r01_r10_credit === :none
    @test length(result.iteration_trace) > 0 && length(result.ledgers) == 4
    @test Set(x.kind for x in result.ledgers) == Set((:energy, :thermal, :mechanical, :material))
    @test !result.component_load && !result.component_load_admitted
    @test occursin("component_load=false", result.limitation)
    @test isfinite(result.diagnostics.temperature_max_K)
    @test canonical_hash(result) == result.execution_hash
    @test result.residuals.converged
    @test length(result.iteration_trace) <= request.max_iterations
    @test any(abs(x.force_residual_N) > 0.0 for x in result.iteration_trace)
    first_trace = result.iteration_trace[1]
    tampered_trace = EngineeringFeedbackIterationV1(first_trace.iteration,
        first_trace.supply_power_W, first_trace.current_A, first_trace.resistance_ohm,
        first_trace.joule_heat_W, first_trace.cooling_W, first_trace.temperature_K,
        first_trace.allowable_stress_Pa, first_trace.stress_Pa, first_trace.displacement_m,
        first_trace.geometry_factor, first_trace.internal_reaction_N + 1.0,
        first_trace.support_reaction_N, first_trace.energy_residual_W,
        first_trace.thermal_residual_W, first_trace.force_residual_N,
        first_trace.material_residual_Pa, first_trace.state_change, first_trace.iteration_hash)
    @test_throws ArgumentError canonical_hash(tampered_trace)

    observed = Dict{String,NamedTuple}()
    for item in fixture.negative
        mutation = Symbol(String(fixture.dispatch[String(item.id)]))
        got = if mutation === :forged_residual
            forged = EngineeringFeedbackExecutionV1(result.schema, result.revision, result.status,
                result.accepted, result.claim_ceiling, result.engineering_credit,
                result.physical_credit, result.r01_r10_credit, result.candidate_hash,
                result.scenario_hash, result.g3_hash, result.shir_hash, result.bridge_hash,
                result.upstream_execution_hash, result.load_sample_hash, result.component_load,
                result.component_load_admitted, result.limitation, result.iteration_trace,
                result.ledgers, result.residuals, result.diagnostics, result.hard_gates,
                result.failures, result.exception_detail, _up4b_d("forged-residual"))
            validate_engineering_feedback_residuals(forged)
        elseif mutation === :nonfinite
            nonfinite_base = _up4b_request()
            nonfinite_sample = nonfinite_base.load_sample
            nonfinite_envelope = _up4b_envelope(nonfinite_base.candidate_hash,
                nonfinite_base.scenario_hash, nonfinite_base.g3_hash, nonfinite_sample; mutation=:nonfinite)
            nonfinite_request = EngineeringFeedbackExecutionRequestV1(nonfinite_base.upstream_execution,
                nonfinite_sample, nonfinite_base.upstream_execution_hash, nonfinite_base.load_sample_hash,
                nonfinite_base.shir_hash, nonfinite_base.bridge_hash, nonfinite_base.candidate_hash,
                nonfinite_base.scenario_hash, nonfinite_base.g3_hash, nonfinite_base.shir_contract,
                nonfinite_base.bridge_contract, nonfinite_envelope, nonfinite_base.max_iterations,
                nonfinite_base.tolerance, _up4b_d("forged-nonfinite-request"))
            execute_engineering_feedback(nonfinite_request)
        else
            execute_engineering_feedback(_up4b_request(; mutation))
        end
        expected_reason = Symbol(String(item.expected_reason))
        @test got.status === Symbol(String(item.expected_status))
        @test expected_reason in got.failures
        @test !got.accepted && got.claim_ceiling === :screen_only
        observed[String(item.id)] = (status=String(got.status), reason=String(expected_reason))
    end
    @test validate_engineering_feedback_residuals(result).execution_hash == result.execution_hash
    @test Set(keys(observed)) == Set(String(item.id) for item in fixture.negative)
    @test length(observed) == 20
end
