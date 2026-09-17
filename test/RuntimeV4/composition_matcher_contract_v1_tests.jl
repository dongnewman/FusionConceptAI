"""Executable contract tests for the isolated UP3 matcher module.

This test deliberately includes the additive source into a dedicated module;
the matcher is not required to be installed in FusionConceptAI.jl yet.
"""

using Test
using JSON3
import FusionConceptAI: Digest256, PhysicalType,
    UnitSignature, TemporalTypeV1, static_time, screen_only

module CompositionMatcherIsolatedV1
include(joinpath(@__DIR__, "..", "..", "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(@__DIR__, "..", "..", "src", "RuntimeV4", "CompositionMatcherContractV1.jl"))
end

const M = CompositionMatcherIsolatedV1
@test all(name -> isdefined(M, name),
    (:CapabilitySignatureV4, :Digest256, :PhysicalType, :UnitSignature,
     :canonical_hash, :semantic_view))
# Test-only references must be real canonical SHA-256 digests.  Do not create
# Digest256 values by padding labels: labels are not hex and that masks the
# production constructor's input validation.
_d(c) = M.canonical_hash((tag=String(c),))
@test length(string(_d("s"))) == 64
@test all(c -> c in "0123456789abcdef", string(_d("s")))
@test _d("s") != _d("x")
_u(n=0) = UnitSignature(ntuple(i -> i == 1 ? n : 0, 7))
_pt(u=UnitSignature()) = PhysicalType(:scalar, 0, 1, TemporalTypeV1(static_time), u)

function _sig(source, target; op="transfer", input_schema=_d("input-schema"))
    M.CapabilitySignatureV4("cap-v1", "r1", :field, op, ("rho",), source, target,
        1, ("x",), "periodic", "interface", "static", ("rho",),
        screen_only, _d("a"); input_schema_hash=input_schema)
end

function _port(id, side, sig; sign=side === :output ? 1 : -1, account="energy",
        owner="shared", space=_d("s"), domain=_d("d"), unit=UnitSignature())
    M.CompositionPortContractV1(id, side, sig, _pt(unit), unit, space, domain,
        "periodic", "interface", :source, account, owner, sign)
end

function _pair(; out_id="display-out", in_id="display-in", out_space=_d("s"),
        in_space=_d("s"), provider=:declared, authority=:contract_only,
        consumer_input_schema=nothing)
    out_sig = _sig("A", "B")
    consumer_schema = consumer_input_schema === nothing ? _d("input-schema") : consumer_input_schema
    in_sig = _sig("B", "C"; input_schema=consumer_schema)
    producer = M.CompositionComponentContractV1(_d("1"), _d("2"), out_sig,
        (), (_port(out_id, :output, out_sig; space=out_space),), provider, authority)
    consumer = M.CompositionComponentContractV1(_d("3"), _d("4"), in_sig,
        (_port(in_id, :input, in_sig; space=in_space),), (), provider, authority)
    producer, consumer
end

function _cycle_components()
    ab = _sig("A", "B")
    ba = _sig("B", "A")
    a = M.CompositionComponentContractV1(_d("9"), _d("a"), ab,
        (_port("a-in", :input, ab),), (_port("a-out", :output, ab),),
        :declared, :contract_only)
    b = M.CompositionComponentContractV1(_d("b"), _d("c"), ba,
        (_port("b-in", :input, ba),), (_port("b-out", :output, ba),),
        :declared, :contract_only)
    a, b
end

function _multi_pair()
    one_out = _sig("A", "B"; op="one")
    two_out = _sig("A", "C"; op="two")
    one_in = _sig("B", "D"; op="one")
    two_in = _sig("C", "D"; op="two")
    p1 = M.CompositionComponentContractV1(_d("d"), _d("e"), one_out, (),
        (_port("first-output", :output, one_out; account="e1"),), :declared, :contract_only)
    p2 = M.CompositionComponentContractV1(_d("f"), _d("0"), two_out, (),
        (_port("second-output", :output, two_out; account="e2"),), :declared, :contract_only)
    inputs = (_port("first-input", :input, one_in; account="e1"),
        _port("second-input", :input, two_in; account="e2"))
    c = M.CompositionComponentContractV1(_d("1"), _d("2"), one_in, inputs, (),
        :declared, :contract_only)
    c_reversed = M.CompositionComponentContractV1(c.component_ref, c.source_ref,
        c.capability, reverse(c.inputs), c.outputs, :declared, :contract_only)
    p1, p2, c, c_reversed
end

@testset "composition matcher contract v1 R7" begin
    fixture = JSON3.read(read(joinpath(@__DIR__, "composition_matcher_contract_v1_fixture.json")))
    @test String(fixture.scope) == "contract_only"
    @test length(fixture.negative) == 9

    # Failure identity keeps typed code/path/detail, while display labels are
    # erased and ordering is governed by an explicit stable sort key.
    failure_a = M.CompositionMatcherFailureV1(:ambiguous_match, "input.left", "same")
    failure_b = M.CompositionMatcherFailureV1(:ambiguous_match, "input.right", "same")
    failure_c = M.CompositionMatcherFailureV1(:ambiguous_match,
        "component:abc:input:def", "same")
    failure_d = M.CompositionMatcherFailureV1(:cycle, "edges", "same")
    @test M._cmc_failure_key(failure_a) == M._cmc_failure_key(failure_b)
    @test M._cmc_failure_key(failure_a) != M._cmc_failure_key(failure_c)
    @test M._cmc_failure_key(failure_a) != M._cmc_failure_key(failure_d)
    @test M._cmc_failure_sort_key(failure_a) == M._cmc_failure_sort_key(failure_b)
    @test M._cmc_failure_key(failure_a) == M._cmc_failure_key(failure_a)

    producer, consumer = _pair()
    plan = M.match_composition_contract((consumer, producer))
    @test plan.status === :contract_only
    @test length(plan.edges) == Int(fixture.positive.edges)
    @test plan.provider_invocation_count == 0
    @test plan.solver_invocation_count == 0
    @test M.validate_composition_match(plan).plan_hash == plan.plan_hash
    @test M.composition_match_hash(plan) == plan.plan_hash

    renamed_producer, renamed_consumer = _pair(out_id="renamed-output", in_id="renamed-input")
    renamed = M.match_composition_contract((renamed_producer, renamed_consumer))
    @test renamed.input_hash == plan.input_hash
    @test renamed.plan_hash == plan.plan_hash

    # Both component order and input/output tuple order are display-order noise.
    @test M.match_composition_contract((producer, consumer)).plan_hash == plan.plan_hash
    @test M.match_composition_contract((consumer, producer)).plan_hash == plan.plan_hash

    multi_p1, multi_p2, multi_consumer, multi_reversed_consumer = _multi_pair()
    multi = M.match_composition_contract((multi_consumer, multi_p2, multi_p1))
    multi_reordered = M.match_composition_contract((multi_p1, multi_reversed_consumer, multi_p2))
    @test multi.status === :contract_only
    @test length(multi.edges) == 2
    @test multi_reordered.plan_hash == multi.plan_hash

    # Structural contradictions fail closed, while missing execution authority defers.
    _, bad_space_consumer = _pair(in_space=_d("x"))
    bad_space = M.match_composition_contract((producer, bad_space_consumer))
    @test bad_space.status === :fail_closed
    @test any(f -> f.code === :unmatched_signature, bad_space.failures)

    _, bad_schema_consumer = _pair(consumer_input_schema=_d("other-input-schema"))
    bad_schema = M.match_composition_contract((producer, bad_schema_consumer))
    @test bad_schema.status === :fail_closed
    @test Set(f.code for f in bad_schema.failures) == Set([:unmatched_signature])

    amb_a, amb_consumer = _pair(out_id="a-out", in_id="amb-in")
    amb_b, _ = _pair(out_id="b-out", in_id="unused")
    amb_b = M.CompositionComponentContractV1(_d("5"), _d("6"), amb_b.capability,
        amb_b.inputs, amb_b.outputs, :declared, :contract_only)
    ambiguous = M.match_composition_contract((amb_a, amb_b, amb_consumer))
    @test ambiguous.status === :fail_closed
    @test Set(f.code for f in ambiguous.failures) == Set([:ambiguous_match])
    @test any(f -> f.code === :ambiguous_match, ambiguous.failures)

    cycle_a, cycle_b = _cycle_components()
    cycle = M.match_composition_contract((cycle_b, cycle_a))
    @test cycle.status === :fail_closed
    @test Set(f.code for f in cycle.failures) == Set([:cycle])
    @test any(f -> f.code === :cycle, cycle.failures)

    dropout_p, dropout_c = _pair(provider=:missing)
    dropout = M.match_composition_contract((dropout_p, dropout_c))
    @test dropout.status === :terminal_deferred
    @test isempty(dropout.failures)
    @test any(occursin("provider_unavailable", r) for r in dropout.deferred_reasons)

    absent_p, absent_c = _pair(authority=:typed_absent)
    absent = M.match_composition_contract((absent_p, absent_c))
    @test absent.status === :terminal_deferred
    @test isempty(absent.failures)
    @test any(occursin("authority_absent", r) for r in absent.deferred_reasons)

    lone = M.CompositionComponentContractV1(_d("7"), _d("8"), _sig("A", "B"),
        (), (_port("unclosed", :output, _sig("A", "B")),), :declared, :contract_only)
    unclosed = M.match_composition_contract((lone,))
    @test unclosed.status === :fail_closed
    @test any(f -> f.code === :unclosed_ledger, unclosed.failures)

    duplicate = M.match_composition_contract((producer, producer))
    @test duplicate.status === :fail_closed
    @test any(f -> f.code === :duplicate_component, duplicate.failures)

    invalid = M.match_composition_contract((producer, :not_a_component))
    @test invalid.status === :fail_closed
    @test any(f -> f.code === :invalid_component, invalid.failures)
    @test M.match_composition_contract(nothing).status === :fail_closed

    tampered = M.CompositionMatchPlanV1(plan.schema, plan.components, plan.edges,
        plan.topological_order, plan.unresolved_ports, plan.unresolved_keys,
        plan.ledger_defects, plan.failures, plan.deferred_reasons, plan.status,
        1, plan.solver_invocation_count, plan.input_hash, plan.plan_hash)
    checked = M.validate_composition_match(tampered)
    @test checked.status === :fail_closed
    @test any(f -> f.code === :validation_mismatch, checked.failures)

    tampered_hash = M.CompositionMatchPlanV1(plan.schema, plan.components, plan.edges,
        plan.topological_order, plan.unresolved_ports, plan.unresolved_keys,
        plan.ledger_defects, plan.failures, plan.deferred_reasons, plan.status,
        plan.provider_invocation_count, plan.solver_invocation_count,
        plan.input_hash, _d("tampered-plan-hash"))
    checked_hash = M.validate_composition_match(tampered_hash)
    @test checked_hash.status === :fail_closed
    @test any(f -> f.code === :validation_mismatch, checked_hash.failures)

    # Construction-time invariants remain explicit exceptions; match-time bad
    # inputs above always return typed plans.
    @test_throws ArgumentError M.CompositionPortContractV1("unit-mismatch", :input,
        _sig("A", "B"), _pt(UnitSignature()), _u(1), _d("s"), _d("d"),
        "periodic", "interface", :source, "energy", "shared", -1)
    @test_throws ArgumentError M.CompositionPortContractV1("", :input, _sig("A", "B"),
        _pt(), UnitSignature(), _d("s"), _d("d"), "periodic", "interface",
        :source, "energy", "shared", -1)
end
