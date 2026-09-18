using Test
using JSON3
using FusionConceptAI

const _UP4_02A_SOURCE = normpath(joinpath(@__DIR__, "../../../src/RuntimeV4/EngineeringFeedbackBridgeContractV1.jl"))
@assert isfile(_UP4_02A_SOURCE)
include(_UP4_02A_SOURCE)

_up4_d(s) = digest256_text(String(s))

function _up4_ref(kind, candidate_hash, scenario_hash; suffix=String(kind), status=:present,
        unit=:W, direction=:in, owner="fixture-owner", capacity=100//1,
        content_hash=_up4_d("content:$suffix"), reason="")
    body = (revision=UP4_02A_REVISION, ref="fixture.$suffix", kind=kind, version="v1",
        candidate_hash=candidate_hash, scenario_hash=scenario_hash, content_hash=content_hash,
        unit=unit, direction=direction, owner_scope=owner, capacity=capacity,
        status=status, reason=status === :present ? "" : reason)
    EngineeringFeedbackTypedRefV1(body.ref, body.kind, body.version, body.candidate_hash,
        body.scenario_hash, body.content_hash, body.unit, body.direction, body.owner_scope,
        body.capacity, body.status, body.reason, canonical_hash(body))
end

function _up4_axes(candidate_hash, scenario_hash)
    axes = (_up4_ref(:axis, candidate_hash, scenario_hash; suffix="axis.contract"),
        _up4_ref(:axis, candidate_hash, scenario_hash; suffix="axis.schema"),
        _up4_ref(:axis, candidate_hash, scenario_hash; suffix="axis.canonical"),
        _up4_ref(:axis, candidate_hash, scenario_hash; suffix="axis.compatibility"))
    body = (revision=UP4_02A_REVISION, contract_axis=axes[1], schema_axis=axes[2],
        canonicalization_axis=axes[3], compatibility_axis=axes[4])
    EngineeringFeedbackVersionAxesV1(axes[1], axes[2], axes[3], axes[4], canonical_hash(body))
end

function _up4_entry(id, role, amount, sign, resource; unit=:W, direction=sign > 0 ? :in : :out,
        owner="fixture-owner", resource_hash=canonical_hash(resource))
    EngineeringFeedbackLedgerEntryV1(id, role, amount, sign, unit, direction, owner,
        resource_hash)
end

function _up4_ledger(kind, entries; forged=false, empty=false, owner="fixture-owner", unit=:W)
    es = empty ? () : Tuple(entries)
    actual = sum((Int(e.sign) * e.amount for e in es); init=0//1)
    supplied = forged ? actual + 1 : actual
    body = (revision=UP4_02A_REVISION, ledger_kind=kind, entries=es,
        expected_residual=supplied, actual_residual=supplied, unit=unit, owner_scope=owner)
    EngineeringFeedbackLedgerClosureV1(kind, es, supplied, supplied, unit, owner,
        canonical_hash(body))
end

function _up4_request(mutation::Symbol=:positive)
    candidate_projection = canonical_hash((revision=UP4_02A_REVISION, ref="fixture.candidate",
        kind=:candidate, version="v1", unit=:W, direction=:in, owner_scope="fixture-owner",
        capacity=100//1, status=:present, reason=""))
    scenario_projection = canonical_hash((revision=UP4_02A_REVISION, ref="fixture.scenario",
        kind=:scenario, version="v1", unit=:W, direction=:in, owner_scope="fixture-owner",
        capacity=100//1, status=:present, reason=""))
    candidate_projection = mutation === :candidate_projection_mismatch ?
        _up4_d("forged-candidate-projection") : candidate_projection
    scenario_projection = mutation === :scenario_projection_mismatch ?
        _up4_d("forged-scenario-projection") : scenario_projection
    candidate = _up4_ref(:candidate, candidate_projection, scenario_projection; suffix="candidate")
    scenario = _up4_ref(:scenario, candidate.ref_hash, scenario_projection; suffix="scenario")
    ch, sh = candidate.ref_hash, scenario.ref_hash
    if mutation === :scenario_reuse_mismatch
        sh = _up4_d("foreign-scenario")
    end
    g1_candidate = mutation === :candidate_hash_mismatch ? _up4_d("foreign-candidate") : ch
    g1 = _up4_ref(:genome, g1_candidate, sh; suffix="g1")
    g2 = _up4_ref(:genome, ch, sh; suffix="g2")
    g3_candidate = mutation === :g3_hash_mismatch ? _up4_d("foreign-g3") : ch
    g3 = _up4_ref(:genome, g3_candidate, sh; suffix="g3")
    parent = _up4_ref(:parent, ch, sh; suffix="parent")
    mission = _up4_ref(:mission, ch, sh; suffix="mission")
    physical = _up4_ref(:physical_subject, ch, sh; suffix="physical_subject")
    axes = _up4_axes(ch, sh)
    design_hash, realization_hash, control_hash = _up4_d("design"), _up4_d("realization"), _up4_d("control")
    binding_body = (revision=UP4_02A_REVISION, candidate=candidate, g1=g1, g2=g2, g3=g3,
        parent=parent, mission=mission, scenario=scenario, physical_subject=physical,
        axes=axes, design_hash, realization_plan_hash=realization_hash,
        control_plan_hash=control_hash)
    binding = EngineeringFeedbackBindingV1(candidate, g1, g2, g3, parent, mission, scenario,
        physical, axes, design_hash, realization_hash, control_hash, canonical_hash(binding_body))

    source_status = mutation === :missing_source ? :typed_absent : :present
    return_status = mutation === :missing_return ? :typed_absent : :present
    heat_status = mutation === :missing_heat_sink ? :typed_absent : :present
    source_direction = mutation === :passive_source ? :passive :
        mutation === :direction_mismatch ? :out : :in
    owner = "fixture-owner"
    source_owner = mutation === :owner_mismatch ? "foreign-owner" : owner
    source_unit = mutation === :unit_mismatch ? :V : :W
    source = _up4_ref(:source, ch, scenario.ref_hash; suffix="source", status=source_status,
        unit=source_unit, direction=source_direction, owner=source_owner,
        capacity=mutation === :capacity_exceeded ? 5//1 : 100//1,
        reason=source_status === :present ? "" : "deleted source")
    coil = _up4_ref(:coil, ch, sh; suffix="coil", direction=:out, owner=owner)
    driver = _up4_ref(:driver, ch, sh; suffix="driver", direction=:out, owner=owner)
    return_ref = _up4_ref(:return, ch, sh; suffix="return", status=return_status, direction=:out, owner=owner,
        reason=return_status === :present ? "" : "deleted return")
    heat_sink = _up4_ref(:heat_sink, ch, sh; suffix="heat_sink", status=heat_status, direction=:out, owner=owner,
        reason=heat_status === :present ? "" : "deleted heat sink")
    material_status = mutation === :unknown_material ? :unknown : :present
    material = _up4_ref(:material, ch, sh; suffix="material", unit=:kg, status=material_status,
        reason=material_status === :present ? "" : "unresolved", owner=owner)
    manufacturing = _up4_ref(:manufacturing, ch, sh; suffix="manufacturing", unit=:kg, direction=:out,
        owner=owner, content_hash=realization_hash)
    cooling = _up4_ref(:cooling, ch, sh; suffix="cooling", owner=owner)
    support = _up4_ref(:support, ch, sh; suffix="support", owner=owner,
        status=mutation === :missing_support_boundary ? :typed_absent : :present,
        reason=mutation === :missing_support_boundary ? "deleted support" : "")
    control_fault = _up4_ref(:control_fault, ch, sh; suffix="control_fault", owner=owner,
        content_hash=control_hash)
    control = _up4_ref(:control, ch, sh; suffix="control", owner=owner, content_hash=control_hash)
    provider_status = mutation === :provider_dropout ? :typed_absent : mutation === :ambiguous_provider ? :unknown : :present
    provider = _up4_ref(:provider, ch, sh; suffix="provider", unit=:unitless, owner=owner, status=provider_status,
        reason=provider_status === :present ? "" : "capability gap")
    solver = _up4_ref(:solver, ch, sh; suffix="solver", unit=:unitless, owner=owner)
    checker = _up4_ref(:checker, ch, sh; suffix="checker", unit=:unitless, owner=owner)
    refs = (source, coil, driver, return_ref, heat_sink, material, manufacturing, cooling,
        support, control_fault, control, provider, solver, checker)

    source_entry = _up4_entry("energy.source", :source, 10//1, 1, source; owner=owner,
        resource_hash=mutation === :missing_link ? _up4_d("missing-resource-link") : canonical_hash(source))
    energy = _up4_ledger(:energy, (source_entry,
        _up4_entry("energy.return", :return, 10//1, -1, return_ref; owner=owner),
        _up4_entry("energy.heat", :heat_sink, 2//1, -1, heat_sink; owner=owner));
        forged=mutation === :forged_residual, owner=owner)
    material_ledger = _up4_ledger(:material, (_up4_entry("material.in", :input, 3//1, 1, material; unit=:kg, owner=owner),
        _up4_entry("material.out", :output, 3//1, -1, manufacturing; unit=:kg, owner=owner)); unit=:kg, owner=owner)
    thermal = _up4_ledger(:thermal, (_up4_entry("thermal.in", :input, 4//1, 1, cooling; owner=owner),
        _up4_entry("thermal.out", :heat_sink, 4//1, -1, heat_sink; owner=owner)); owner=owner)
    mechanical = _up4_ledger(:mechanical, (_up4_entry("mechanical.in", :input, 5//1, 1, support; owner=owner),
        _up4_entry("mechanical.out", :output, 5//1, -1, coil; owner=owner)); owner=owner)
    ledgers = mutation === :duplicate_ledger ? (energy, energy, thermal, mechanical) :
        mutation === :empty_entry ? (energy, _up4_ledger(:material, (); empty=true, owner=owner), thermal, mechanical) :
        (energy, material_ledger, thermal, mechanical)
    feedback_status = mutation === :feedback_edge_removed ? :typed_absent : :present
    control_resource = mutation === :feedback_link ? provider : control_fault
    target_body = (revision=UP4_02A_REVISION, target_id="fixture.target", target_layer=:G3,
        target_path="/g3/control/fault", quantity=:control_fault, unit=:W, direction=:in,
        owner_scope=owner, control_resource=control_resource, candidate_hash=ch,
        g1_hash=g1.ref_hash, g2_hash=g2.ref_hash, g3_hash=g3.ref_hash, status=feedback_status)
    target = EngineeringFeedbackFeedbackTargetV1(target_body.target_id, target_body.target_layer,
        target_body.target_path, target_body.quantity, target_body.unit, target_body.direction,
        target_body.owner_scope, target_body.control_resource, target_body.candidate_hash,
        target_body.g1_hash, target_body.g2_hash, target_body.g3_hash, target_body.status,
        canonical_hash(target_body))
    bundle_body = (revision=UP4_02A_REVISION, source, coil, driver, return_ref, heat_sink,
        material, manufacturing, cooling, support, control_fault, control, provider, solver,
        checker, realization_plan_hash=realization_hash, control_plan_hash=control_hash)
    resources = EngineeringFeedbackResourceBundleV1(refs..., realization_hash, control_hash,
        canonical_hash(bundle_body))
    bytes = "{\"schema\":\"up4-02a\",\"fixture\":true}"
    request_body = (schema=UP4_02A_SCHEMA, revision=UP4_02A_REVISION, request_ref="fixture.request",
        binding=binding, resources=resources, ledgers=ledgers, feedback_targets=(target,),
        static_flux=mutation === :static_flux_to_emf ? 1//1 : 0//1,
        emf=mutation === :static_flux_to_emf ? 1//1 : 0//1,
        time_derivative_declared=false, motion_declared=false, drive_declared=false,
        canonical_bytes_hash=digest256_text(bytes))
    EngineeringFeedbackBridgeContractV1(UP4_02A_SCHEMA, UP4_02A_REVISION, "fixture.request",
        binding, resources, ledgers, (target,), request_body.static_flux, request_body.emf,
        false, false, false, bytes, request_body.canonical_bytes_hash, canonical_hash(request_body))
end

@testset "UP4-02A engineering feedback bridge contract-only V1" begin
    fixture = JSON3.read(read(joinpath(@__DIR__, "engineering_feedback_bridge_contract_v1_fixture.json")))
    request = _up4_request()
    @test canonical_hash(request) == request.request_hash
    result = validate_engineering_feedback_bridge(request)
    @test result.status == :prepared
    @test !result.accepted
    @test result.claim_ceiling === :contract_only
    @test canonical_hash(request) == request.request_hash
    @test canonical_hash(result) == result.resolution_hash
    @test result.provider_calls == result.solver_calls == result.checker_calls == 0
    @test length(request.ledgers) == 4
    @test Set(x.ledger_kind for x in request.ledgers) == Set(_UP4_02A_LEDGER_KINDS)
    @test request.feedback_targets[1].candidate_hash == request.binding.candidate.ref_hash
    @test !isempty(request.feedback_targets)
    @test length(fixture.negative) >= 15

    coverage = Dict{String,NamedTuple}()
    for item in fixture.negative
        id = String(item.id)
        mutation = Symbol(String(fixture.dispatch[id]))
        req = _up4_request(mutation)
        @test canonical_hash(req) == req.request_hash
        got = validate_engineering_feedback_bridge(req)
        expected_reason = Symbol(String(item.expected_reason))
        @test got.status === Symbol(String(item.expected_status))
        @test expected_reason in got.failures
        @test !got.accepted
        @test got.claim_ceiling === :contract_only
        @test got.provider_calls == got.solver_calls == got.checker_calls == 0
        @test canonical_hash(req) == req.request_hash
        coverage[id] = (status=String(got.status), reason=String(expected_reason),
            provider_calls=got.provider_calls, solver_calls=got.solver_calls,
            checker_calls=got.checker_calls)
    end
    @test Set(keys(coverage)) == Set(String(item.id) for item in fixture.negative)
    @test length(coverage) == length(fixture.negative)
end
