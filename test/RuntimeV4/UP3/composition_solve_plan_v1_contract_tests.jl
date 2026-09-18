"""Contract-only tests for the additive UP3 composition solve plan."""

using Test
using JSON3
using FusionConceptAI

module CompositionSolvePlanIsolatedV1
using FusionConceptAI
include(joinpath(@__DIR__, "..", "..", "..", "src", "RuntimeV4", "CompositionSolvePlanV1.jl"))
end

const C = CompositionSolvePlanIsolatedV1
# Derive fixture references through the package's real SHA-256 digest API.
# Labels remain deterministic semantic tags; no padding/truncation is used.
_d(c) = digest256_text(String(c))
_unit(exponents=(0, 0, 0, 0, 0, 0, 0)) = C.CompositionSolveUnitV1(:power, exponents)
_space(ref="s") = C.CompositionSolveSpaceV1(_d(ref), :scalar, 3, _d("chart"))

function _port(label, slot, direction; unit=_unit(), space=_space(), sign=direction === :output ? 1 : -1,
        role=direction === :output ? :source : :sink, quantity=:power)
    C.CompositionSolvePortV1(label, slot, direction, quantity, unit, space,
        "energy", "shared", sign, role)
end

function _component(ref, inputs, outputs; provider=_d("provider"), code=_d("code"), backend=_d("backend"))
    C.CompositionSolveComponentV1(_d(ref), provider, code, backend, inputs, outputs)
end

function _binding(; candidate=_d("candidate"), subject=_d("subject"), mission=_d("mission"),
        scenario=_d("scenario"), provider=_d("provider"), code=_d("code"),
        backend=_d("backend"), protocol=_d("protocol"))
    C.CompositionSolveBindingV1(candidate, subject, mission, scenario, provider,
        code, backend, protocol)
end

_protocol() = C.CompositionSolveProtocolV1(_d("protocol"), 20, 1.0e-8)

function _chain(; labels=("p1", "p2", "p3"), components_order=:normal,
         provider=_d("provider"), code=_d("code"), backend=_d("backend"),
         unit=_unit(), space=nothing)
    # The positive chain must expose stage-specific function spaces.  This
    # makes a->b and b->c unique typed routes even though both producer
    # outputs have the same quantity/unit; labels and first-producer order
    # remain irrelevant to routing.
    space_a = space === nothing ? _space("chain-space-a") : space
    space_b = space === nothing ? _space("chain-space-b") : space
    a = _component("a", (), (_port(labels[1], 1, :output; unit=unit, space=space_a),);
         provider=provider, code=code, backend=backend)
    b = _component("b", (_port(labels[2], 1, :input; unit=unit, space=space_a),),
        (_port("middle-out", 2, :output; unit=unit, space=space_b),);
         provider=provider, code=code, backend=backend)
    c = _component("c", (_port(labels[3], 1, :input; unit=unit, space=space_b),), ();
         provider=provider, code=code, backend=backend)
    components_order === :reverse ? (c, b, a) : (a, b, c)
end

function _mimo(; permuted=false, provider=_d("provider"), code=_d("code"), backend=_d("backend"))
    # Slots are local endpoint locators; typed quantity/unit/space contracts
    # select the edge.  Distinct spaces make the two legal MIMO edges
    # observable and prevent a fixture from passing through cross-space
    # matching merely because both ports use the default type.
    unit = _unit()
    space_a, space_b = _space("mimo-space-a"), _space("mimo-space-b")
    outputs = (_port("out-1", 1, :output; unit=unit, space=space_a),
               _port("out-2", 2, :output; unit=unit, space=space_b))
    inputs = (_port("in-1", 1, :input; unit=unit, space=space_a),
              _port("in-2", 2, :input; unit=unit, space=space_b))
    producer = _component("mimo-producer", (), permuted ? Base.reverse(outputs) : outputs;
        provider=provider, code=code, backend=backend)
    consumer = _component("mimo-consumer", permuted ? Base.reverse(inputs) : inputs, ();
        provider=provider, code=code, backend=backend)
    (producer, consumer)
end

function _admit(components; binding=_binding(), protocol=_protocol(), preclassification=:none)
    input = C.CompositionSolveInputV1(binding, components, protocol;
        preclassification=preclassification)
    C.admit_composition_solve(input)
end

_record_negative!(coverage, name, outcome, code) =
    (coverage[name] = (outcome.status, code); nothing)

@testset "UP3 composition solve plan contract-only v1" begin
    fixture = JSON3.read(read(joinpath(@__DIR__, "composition_solve_plan_v1_fixture.json")))
    negative_coverage = Dict{Symbol,Tuple{Symbol,Symbol}}()
    @test String(fixture.schema) == "fusionconceptai:composition-solve-plan-v1"
    @test String(fixture.claim_ceiling) == "contract_only"
    @test fixture.accepted == false

    positive = _admit(_chain())
    @test positive.outcome.status === :ready
    @test positive.outcome.code === :ready
    @test length(positive.plan.edges) == Int(fixture.positive.edges)
    @test positive.outcome.provider_invocation_count == 0
    @test positive.outcome.solver_invocation_count == 0
    @test positive.input.preclassification === :none
    @test positive.receipt.claim_ceiling === :contract_only
    @test C.validate_composition_solve_receipt(positive.receipt)
    @test C.validate_composition_solve_plan(positive.plan).plan_hash == positive.plan.plan_hash
    @test C.composition_solve_receipt(positive).receipt_hash == positive.receipt.receipt_hash

    # MIMO has two legal typed edges with the same component endpoints.  The
    # topological relation must be deduplicated consistently on both sides.
    mimo = _admit(_mimo())
    mimo_permuted = _admit(_mimo(permuted=true))
    @test mimo.outcome.status === :ready
    @test length(mimo.plan.edges) == 2
    @test length(unique((e.producer_component, e.consumer_component) for e in mimo.plan.edges)) == 1
    @test Set((e.producer_slot, e.consumer_slot) for e in mimo.plan.edges) == Set(((1, 1), (2, 2)))
    @test mimo.plan.topological_order == mimo_permuted.plan.topological_order
    @test mimo.plan.plan_hash == mimo_permuted.plan.plan_hash

    # The canonical chain uses two distinct stage spaces; routing must not
    # collapse to a same-label or first-producer heuristic.
    @test Set((e.producer_slot, e.consumer_slot) for e in positive.plan.edges) ==
        Set(((1, 1), (2, 1)))

    renamed = _admit(_chain(labels=("renamed-a", "renamed-b", "renamed-c"), components_order=:reverse))
    @test renamed.plan.plan_hash == positive.plan.plan_hash
    @test renamed.outcome.input_hash == positive.outcome.input_hash

    # Every missing binding identity is deferred, including protocol_ref;
    # absence is not misclassified as a protocol mismatch.
    function _binding_missing(field)
        values = Dict{Symbol,Any}(
            :candidate_ref => _d("candidate"), :subject_ref => _d("subject"),
            :mission_ref => _d("mission"), :scenario_ref => _d("scenario"),
            :provider_ref => _d("provider"), :code_ref => _d("code"),
            :backend_ref => _d("backend"), :protocol_ref => _d("protocol"))
        values[field] = nothing
        C.CompositionSolveBindingV1(values[:candidate_ref], values[:subject_ref],
            values[:mission_ref], values[:scenario_ref], values[:provider_ref],
            values[:code_ref], values[:backend_ref], values[:protocol_ref])
    end
    for field in (:candidate_ref, :subject_ref, :mission_ref, :scenario_ref,
                  :provider_ref, :code_ref, :backend_ref, :protocol_ref)
        matrix_case = _admit(_chain(); binding=_binding_missing(field))
        @test matrix_case.outcome.status === :terminal_deferred
        @test any(occursin("binding_missing:" * String(field), r) for r in matrix_case.outcome.reasons)
    end
    _record_negative!(negative_coverage, :binding_missing_matrix,
        _admit(_chain(); binding=_binding_missing(:protocol_ref)).outcome, :binding_missing)

    missing_binding = _admit(_chain(); binding=_binding(provider=nothing))
    @test missing_binding.outcome.status === :terminal_deferred
    @test any(occursin("binding_missing:provider_ref", r) for r in missing_binding.outcome.reasons)
    _record_negative!(negative_coverage, :missing_binding, missing_binding.outcome, :binding_missing)

    missing_authority_a = _component("missing-a", (), (_port("a", 1, :output),),
        provider=nothing, code=nothing, backend=nothing)
    missing_authority_b = _component("missing-b", (_port("b", 1, :input),), (),
        provider=nothing, code=nothing, backend=nothing)
    missing_component_authority = _admit((missing_authority_a, missing_authority_b);
        binding=_binding(provider=nothing, code=nothing, backend=nothing))
    @test missing_component_authority.outcome.status === :terminal_deferred
    @test missing_component_authority.receipt.provider_invocation_count == 0
    @test any(occursin("provider_missing:", r) for r in missing_component_authority.outcome.reasons)
    @test any(occursin("code_missing:", r) for r in missing_component_authority.outcome.reasons)
    @test any(occursin("backend_missing:", r) for r in missing_component_authority.outcome.reasons)
    _record_negative!(negative_coverage, :provider_missing,
        missing_component_authority.outcome, :provider_missing)
    _record_negative!(negative_coverage, :code_missing,
        missing_component_authority.outcome, :code_missing)
    _record_negative!(negative_coverage, :backend_missing,
        missing_component_authority.outcome, :backend_missing)

    singular = _admit(_chain(); preclassification=:singular)
    nonconvergent = _admit(_chain(); preclassification=:nonconvergent)
    @test singular.outcome.status === :terminal_deferred
    @test nonconvergent.outcome.status === :terminal_deferred
    @test singular.input.preclassification === :singular
    @test nonconvergent.input.preclassification === :nonconvergent
    @test any(occursin("singular_preclassified", r) for r in singular.outcome.reasons)
    @test any(occursin("nonconvergent_preclassified", r) for r in nonconvergent.outcome.reasons)
    _record_negative!(negative_coverage, :singular_preclassified, singular.outcome,
        :singular_preclassified)
    _record_negative!(negative_coverage, :nonconvergent_preclassified, nonconvergent.outcome,
        :nonconvergent_preclassified)

    # `Bool` is not a numerical preclassification.  In particular, the
    # constructor must reject it rather than allowing short-circuit validation
    # to write `true`/`false` into the typed Symbol field.
    for invalid_preclassification in (true, false)
        @test_throws ArgumentError C.CompositionSolveInputV1(_binding(), _chain(), _protocol();
            preclassification=invalid_preclassification)
    end
    _record_negative!(negative_coverage, :invalid_preclassification_bool,
        (status=:constructor_rejected,), :invalid_preclassification_bool)

    base = _chain()
    _, _, base_c = base
    wrong_unit_c = _component("c", (_port("wrong-unit", 1, :input;
        unit=_unit((1, 0, 0, 0, 0, 0, 0))),), ())
    wrong_unit = _admit((base[1], base[2], wrong_unit_c))
    @test wrong_unit.outcome.status === :fail_closed
    @test any(f -> f.code === :unmatched_port, wrong_unit.plan.failures)
    _record_negative!(negative_coverage, :unit_mismatch, wrong_unit.outcome, :unmatched_port)
    wrong_space_c = _component("c", (_port("wrong-space", 1, :input;
        space=_space("foreign-space")),), ())
    wrong_space = _admit((base[1], base[2], wrong_space_c))
    @test wrong_space.outcome.status === :fail_closed
    @test any(f -> f.code === :unmatched_port, wrong_space.plan.failures)
    _record_negative!(negative_coverage, :space_mismatch, wrong_space.outcome, :unmatched_port)

    direction_component = _component("direction", (_port("wrong-direction", 1, :output),), ())
    direction_mismatch = _admit((direction_component,))
    @test direction_mismatch.outcome.status === :fail_closed
    @test any(f -> f.code === :direction_mismatch, direction_mismatch.plan.failures)
    _record_negative!(negative_coverage, :direction_mismatch,
        direction_mismatch.outcome, :direction_mismatch)

    poisoned_provider = _admit(_chain(provider=_d("foreign-provider")))
    @test poisoned_provider.outcome.status === :fail_closed
    @test any(f -> f.code === :provider_poisoning, poisoned_provider.plan.failures)
    _record_negative!(negative_coverage, :provider_poisoning,
        poisoned_provider.outcome, :provider_poisoning)
    poisoned_code = _admit(_chain(code=_d("foreign-code")))
    @test any(f -> f.code === :code_poisoning, poisoned_code.plan.failures)
    _record_negative!(negative_coverage, :code_poisoning, poisoned_code.outcome, :code_poisoning)
    poisoned_backend = _admit(_chain(backend=_d("foreign-backend")))
    @test any(f -> f.code === :backend_poisoning, poisoned_backend.plan.failures)
    _record_negative!(negative_coverage, :backend_poisoning,
        poisoned_backend.outcome, :backend_poisoning)

    protocol_mismatch = _admit(_chain(); protocol=C.CompositionSolveProtocolV1(_d("foreign-protocol"), 20, 1e-8))
    @test protocol_mismatch.outcome.status === :fail_closed
    @test any(f -> f.code === :protocol_mismatch, protocol_mismatch.plan.failures)
    _record_negative!(negative_coverage, :protocol_mismatch,
        protocol_mismatch.outcome, :protocol_mismatch)

    unmatched_c = _component("c", (_port("unmatched", 1, :input;
        quantity=:heat, unit=C.CompositionSolveUnitV1(:heat, (0, 0, 0, 0, 0, 0, 0))),), ())
    unmatched = _admit((base[1], base[2], unmatched_c))
    @test any(f -> f.code === :unmatched_port, unmatched.plan.failures)
    _record_negative!(negative_coverage, :unmatched_port, unmatched.outcome, :unmatched_port)

    amb_a = _component("a", (), (_port("a", 1, :output),))
    amb_b = _component("b", (), (_port("b", 1, :output; role=:state, sign=0),))
    amb_c = _component("c", (_port("c", 1, :input),), ())
    ambiguous = _admit((amb_a, amb_b, amb_c))
    @test ambiguous.outcome.status === :fail_closed
    @test ambiguous.outcome.code === :structural_reject
    @test any(f -> f.code === :ambiguous_match, ambiguous.plan.failures)
    _record_negative!(negative_coverage, :ambiguous_match,
        ambiguous.outcome, :ambiguous_match)

    # Structural ambiguity dominates deferred authority/numerical gaps, but
    # the plan must retain every deferred reason for auditability.
    ambiguous_deferred = _admit((amb_a, amb_b, amb_c);
        binding=_binding(provider=nothing), preclassification=:singular)
    @test ambiguous_deferred.outcome.status === :fail_closed
    @test ambiguous_deferred.outcome.code === :structural_reject
    @test any(f -> f.code === :ambiguous_match, ambiguous_deferred.plan.failures)
    @test any(occursin("binding_missing:provider_ref", r)
        for r in ambiguous_deferred.plan.deferred_reasons)
    @test "singular_preclassified" in ambiguous_deferred.plan.deferred_reasons
    _record_negative!(negative_coverage, :ambiguous_with_deferred,
        ambiguous_deferred.outcome, :ambiguous_match)

    cycle_a = _component("cycle-a", (_port("a-in", 1, :input),), (_port("a-out", 1, :output),))
    cycle_b = _component("cycle-b", (_port("b-in", 1, :input),), (_port("b-out", 1, :output),))
    cycle = _admit((cycle_a, cycle_b))
    @test any(f -> f.code === :cycle, cycle.plan.failures)
    _record_negative!(negative_coverage, :cycle, cycle.outcome, :cycle)

    duplicate = _admit((_chain()[1], _chain()[1]))
    @test duplicate.outcome.status === :fail_closed
    @test any(f -> f.code === :duplicate_component, duplicate.plan.failures)
    _record_negative!(negative_coverage, :duplicate_component,
        duplicate.outcome, :duplicate_component)

    duplicate_port = _component("dup", (_port("one", 1, :input), _port("two", 1, :input)), ())
    duplicated = _admit((duplicate_port,))
    @test any(f -> f.code === :duplicate_port, duplicated.plan.failures)
    _record_negative!(negative_coverage, :duplicate_port, duplicated.outcome, :duplicate_port)

    missing_ledger = _admit((_component("open", (), (_port("open", 1, :output),)),))
    @test any(f -> f.code === :missing_ledger, missing_ledger.plan.failures)
    _record_negative!(negative_coverage, :missing_ledger, missing_ledger.outcome, :missing_ledger)

    constructor_error = try
        _port("bad-direction", 1, :sideways)
        nothing
    catch err
        err
    end
    @test constructor_error isa ArgumentError
    _record_negative!(negative_coverage, :invalid_port_direction,
        (status=:constructor_rejected,), :invalid_port_direction)

    malformed_component = try
        C.CompositionSolveInputV1(_binding(), (nothing,), _protocol())
        nothing
    catch err
        err
    end
    @test malformed_component isa ArgumentError
    malformed_admission = C.admit_composition_solve((components=(nothing,),))
    @test malformed_admission.outcome.status === :fail_closed
    @test malformed_admission.outcome.code === :invalid_input

    # A receipt forged with a non-contract claim ceiling must not validate,
    # even if its other fields and hash are otherwise well-formed.
    forged_receipt = C.composition_solve_receipt_from_wire(positive.receipt.input_hash,
        positive.receipt.plan_hash, positive.receipt.result_hash, positive.receipt.status,
        0, 0, :physics, positive.receipt.receipt_hash)
    @test !C.validate_composition_solve_receipt(forged_receipt)
    forged_status = C.composition_solve_receipt_from_wire(positive.receipt.input_hash,
        positive.receipt.plan_hash, positive.receipt.result_hash, :physics,
        0, 0, :contract_only, positive.receipt.receipt_hash)
    @test !C.validate_composition_solve_receipt(forged_status)
    @test_throws MethodError C.CompositionSolveReceiptV1(positive.receipt.input_hash,
        positive.receipt.plan_hash, positive.receipt.result_hash, positive.receipt.status,
        0, 0, :physics, positive.receipt.receipt_hash)

    invalid_input = C.admit_composition_solve(nothing)
    @test invalid_input.outcome.status === :fail_closed
    @test invalid_input.outcome.code === :invalid_input
    _record_negative!(negative_coverage, :invalid_input, invalid_input.outcome, :invalid_input)

    expected_vectors = Set(Symbol(String(x)) for x in
        (fixture.deferred..., fixture.fail_closed..., fixture.constructor_rejected...))
    @test Set(keys(negative_coverage)) == expected_vectors
    for (name, expected) in pairs(fixture.negative_expectations)
        vector = Symbol(String(name))
        @test haskey(negative_coverage, vector)
        actual_status, actual_code = negative_coverage[vector]
        @test String(actual_status) == String(expected.status)
        @test String(actual_code) == String(expected.code)
    end
end
