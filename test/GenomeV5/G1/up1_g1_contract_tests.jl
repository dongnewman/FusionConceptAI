using Test
using FusionConceptAI
using JSON3

const _G1V5_ROOT = joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G1")
Base.include(FusionConceptAI, joinpath(_G1V5_ROOT, "GrammarProfileV2.jl"))
Base.include(FusionConceptAI, joinpath(_G1V5_ROOT, "EquationPlanV2.jl"))
Base.include(FusionConceptAI, joinpath(_G1V5_ROOT, "MechanismGenomePayloadV2.jl"))
Base.include(FusionConceptAI, joinpath(_G1V5_ROOT, "MechanismGenomeV5.jl"))

const G = FusionConceptAI
const _FIXTURE = JSON3.read(read(joinpath(@__DIR__, "fixtures.json"), String))

_ref(x) = G.QualifiedRefV1(String(x.id), String(x.version))
_unit(x) = G.UnitSignature(Tuple(Int.(x)))
_time(x) = getfield(G, Symbol(String(x)))
_physical(x) = G.PhysicalType(Symbol(String(x.value_kind)), Int(x.tensor_rank), Int(x.spatial_dimension),
    G.TemporalTypeV1(_time(x.time)), _unit(x.unit_exponents))
_roles(x) = Tuple(Symbol.(String.(x)))
_effects(x) = Tuple(Symbol.(String.(x)))
_ranks(x) = Tuple(Int.(x))

function _scalar_expr(ref, state_id, unit; value_kind=:scalar_field, parameters=(;))
    ty = G.PhysicalType(value_kind, 0, 0, G.TemporalTypeV1(G.static_time), unit)
    G.G1TypedExpressionV2((G.G1StateInputV2(state_id, ty), G.G1OperatorApplyV2(ref, (1,), ty; parameters=parameters)), 2)
end

function _mimo_expr(ref, ids, units, ranks)
    input_types = Tuple(G.PhysicalType(i == 1 ? :scalar_field : :vector_field, ranks[i], 0, G.TemporalTypeV1(G.static_time), units[i]) for i in eachindex(units))
    output_types = Tuple(G.PhysicalType(i == 1 ? :scalar_field : :vector_field, ranks[i], 0, G.TemporalTypeV1(G.static_time), units[i]) for i in eachindex(units))
    nodes = (G.G1StateInputV2(ids[1], input_types[1]), G.G1StateInputV2(ids[2], input_types[2]),
        G.G1MIMOOperatorApplyV2(ref, (1, 2), output_types))
    G.G1TypedExpressionV2(nodes, (3, 3))
end

function _profile_from_fixture(; provider_match=:unique_match)
    p = _FIXTURE.profile
    ops = Tuple(begin
        iu = Tuple(_unit(u) for u in o.input_units)
        ou = Tuple(_unit(u) for u in o.output_units)
        G.G1OperatorSpecV2(_ref(o), Int(o.input_arity), Int(o.output_arity), _roles(o.roles), iu, ou,
            Tuple(_time(t) for t in o.temporal_kinds), Int(o.max_derivative_order), _effects(o.effects);
            input_ranks=_ranks(o.input_ranks), output_ranks=_ranks(o.output_ranks), provider_match=provider_match)
    end for o in _FIXTURE.operators)
    closures = Tuple(G.G1ClosureRuleV2(String(c.id), String(c.ledger_id), _unit(c.unit_exponents),
        Tuple(String.(c.equation_ids)), Int(c.expected_balance_num) // Int(c.expected_balance_den)) for c in _FIXTURE.closures)
    profile = G.GrammarProfileV2(_ref(p.profile_ref), _ref(p.canonicalization_profile), _ref(p.applicability_profile),
        ops, closures; max_states=Int(p.max_states), max_equations=Int(p.max_equations), max_ast_nodes=Int(p.max_ast_nodes))
    profile, ops
end

function _contract(axes, profile; pending_hash=false)
    kwargs = pending_hash ? (; schema_hash_pending_reason="schema pending", canonicalization_hash_pending_reason="canonicalization pending",
        grammar_profile_hash_pending_reason="grammar profile pending", applicability_profile_hash_pending_reason="applicability profile pending") :
        (; grammar_profile_hash=G.g1_grammar_profile_hash(profile), applicability_profile_hash=G.g1_applicability_profile_hash(profile))
    schema = pending_hash ? nothing : G.g1_schema_hash()
    canonical = pending_hash ? nothing : G.g1_canonicalization_hash()
    G.G1GenomeContractRefV2("pending://GenomeV5/G1/candidate-1", String(_FIXTURE.contract_version), schema, canonical,
        "candidate-owned-g1-v2", axes, "candidate-1"; kwargs...)
end

function _g1_fixture(; provider_match=:unique_match, pending_hash=false)
    profile, ops = _profile_from_fixture(provider_match=provider_match)
    op_map = Dict(o.ref.id => o for o in ops)
    states = Tuple(G.G1StateV2(String(s.id), _physical(s); derivative_order=Int(s.derivative_order)) for s in _FIXTURE.states)
    state_map = Dict(s.state_id => s for s in states)
    equations = Tuple(begin
        op = op_map[String(e.operator_id)]
        ins = Tuple(String.(e.inputs)); outs = Tuple(String.(e.outputs))
        occurrences = Tuple(begin
            side = Symbol(String(o.side)); index = Int(o.port_index)
            units = side === :input ? op.input_units : op.output_units
            G.G1LedgerOccurrenceV2(String(e.id), side, index, Int(o.coefficient_num) // Int(o.coefficient_den),
                String(o.ledger_id), units[index], Symbol(String(o.effect)))
        end for o in e.occurrences)
        expr = String(e.expression_kind) == "mimo" ? _mimo_expr(op.ref, ins, op.input_units, op.input_ranks) : _scalar_expr(op.ref, ins[1], op.output_units[1])
        G.G1EquationV2(String(e.id), Symbol(String(e.role)), op.ref, ins, outs, op.input_units, op.output_units,
            first(op.temporal_kinds), Int(op.max_derivative_order), _effects(e.effects), occurrences, String(e.closure), expr;
            input_ranks=op.input_ranks, output_ranks=op.output_ranks, mimo=String(e.expression_kind) == "mimo")
    end for e in _FIXTURE.equations)
    plan_ref = G.QualifiedRefV1("fusion.g1.plan", "v2")
    plan = G.G1EquationPlanV2(plan_ref, equations)
    axes = G.G1VersionAxesV2(_ref(_FIXTURE.version_axes.payload_schema), _ref(_FIXTURE.version_axes.canonicalization_profile),
        _ref(_FIXTURE.version_axes.applicability_profile), _ref(_FIXTURE.version_axes.evidence_receipt))
    contract = _contract(axes, profile; pending_hash=pending_hash)
    payload = G.MechanismGenomePayloadV2(contract, states, plan, profile)
    genome = pending_hash ? nothing : G.MechanismGenomeV5(G.g1_materialize_contract_ref(contract, profile), payload, axes)
    genome, payload, profile, axes, state_map
end

@testset "UP1-01 G1 V2 contract and fixture-driven component core" begin
    genome, payload, profile, axes, _ = _g1_fixture()
    admission = G.g1_admission(payload)
    @test admission.structural_status == :valid
    @test admission.provider_match == :unique_match
    @test admission.resolution == :resolved
    @test isempty(admission.errors)
    @test genome.contract_ref isa G.GenomeContractRef
    @test genome.contract_ref.version == "v5"
    @test genome.contract_ref.compatibility_profile == G.g1_compatibility_profile_token(profile)
    @test genome.contract_ref == G.g1_materialize_contract_ref(payload.contract_ref, profile)
    @test payload.contract_ref.schema_hash == G.g1_schema_hash()
    @test payload.contract_ref.canonicalization_hash == G.g1_canonicalization_hash()
    @test payload.contract_ref.grammar_profile_hash == G.g1_grammar_profile_hash(profile)
    @test payload.contract_ref.applicability_profile_hash == G.g1_applicability_profile_hash(profile)
    @test G.g1_profile_hash(profile) isa G.Digest256
    @test Set(G.equation_roles(payload.equation_plan)) == Set((:governing, :additive, :constraint))
    @test length(payload.equation_plan.equations[3].input_state_refs) == 2
    @test length(payload.equation_plan.equations[3].output_state_refs) == 2
    @test payload.equation_plan.equations[3].expression.nodes[3] isa G.G1MIMOOperatorApplyV2
    @test _FIXTURE.fixture_id == "UP1-FX-G1-001"
    @test length(_FIXTURE.states) == length(payload.states)
    @test length(_FIXTURE.operators) == length(profile.operators)
    @test length(_FIXTURE.equations) == length(payload.equation_plan.equations)
    @test length(_FIXTURE.negative_cases) >= 9
    @test payload.equation_plan.equations[1].expression.nodes[1].physical_type == payload.states[1].physical_type
    @test payload.equation_plan.equations[1].expression.nodes[2].output_type == payload.states[1].physical_type
    @test payload.equation_plan.equations[3].expression.nodes[2].physical_type == payload.states[2].physical_type
    @test payload.equation_plan.equations[3].expression.nodes[3].output_types[2] == payload.states[2].physical_type

    lowered = G.g1_lowering_plan(payload)
    @test lowered[3].expression === payload.equation_plan.equations[3].expression
    @test lowered[3].input_state_refs == ("temperature", "auxiliary")
    @test lowered[3].output_state_refs == ("temperature", "auxiliary")
    @test lowered[3].closure_ref == "constraint-balance"
    @test length(lowered[3].occurrences) == 2
    @test lowered[3].claim_ceiling == :contract_only

    edited = G.g1_edit_expression(genome, "source-0", _scalar_expr(profile.operators[2].ref, "temperature", profile.operators[2].output_units[1]; parameters=(; edit_tag=:edited)))
    @test G.g1_genome_hash(edited) != G.g1_genome_hash(genome)
    @test G.equation_plan_hash(edited.payload.equation_plan) != G.equation_plan_hash(payload.equation_plan)
    @test_throws ArgumentError G.g1_edit_expression(genome, "source-0", "source_v2(temperature)")

    deferred_genome, deferred_payload, _, _, _ = _g1_fixture(provider_match=:no_match)
    deferred = G.g1_admission(deferred_payload)
    @test deferred.structural_status == :valid
    @test deferred.provider_match == :no_match
    @test deferred.resolution == :terminal_deferred
    @test G.g1_provider_resolution(deferred_genome) == :terminal_deferred
    @test_throws ArgumentError G.g1_lowering_plan(deferred_payload)

    pending_genome, pending_payload, _, _, _ = _g1_fixture(pending_hash=true)
    pending = G.g1_admission(pending_payload)
    @test pending.structural_status == :valid
    @test pending.provider_match == :unique_match
    @test pending.resolution == :terminal_deferred
    @test Set(pending.gaps) == Set(("schema_hash_pending", "canonicalization_hash_pending", "grammar_profile_hash_pending", "applicability_profile_hash_pending"))
    @test pending_genome === nothing
    @test_throws ArgumentError G.g1_materialize_contract_ref(pending_payload.contract_ref, profile)
    @test_throws ArgumentError G.g1_lowering_plan(pending_payload)
end

@testset "UP1-01 G1 fail-closed negative controls" begin
    genome, payload, profile, axes, _ = _g1_fixture()
    eq = payload.equation_plan.equations[2]
    missing_closure = G.G1EquationV2(eq.equation_id, eq.role, eq.operator_ref, eq.input_state_refs, eq.output_state_refs,
        eq.input_units, eq.output_units, eq.temporal_kind, eq.derivative_order, eq.effects, eq.occurrences, nothing, eq.expression)
    bad_payload = G.MechanismGenomePayloadV2(payload.contract_ref, payload.states,
        G.G1EquationPlanV2(payload.equation_plan.plan_ref, (payload.equation_plan.equations[1], missing_closure, payload.equation_plan.equations[3])), profile)
    bad = G.g1_admission(bad_payload)
    @test bad.structural_status == :fail_closed
    @test "missing_closure:source-0" in bad.errors
    @test_throws ArgumentError G.g1_equation_plan(bad_payload)

    @test_throws ArgumentError G.G1EquationV2("duplicate", :additive, eq.operator_ref, ("temperature",), ("temperature",), (_unit(_FIXTURE.states[1].unit_exponents),), (_unit(_FIXTURE.states[1].unit_exponents),), G.static_time, 0, (:net_creation,),
        (G.G1LedgerOccurrenceV2("duplicate", :output, 1, 1 // 1, "energy", eq.output_units[1], :net_creation), G.G1LedgerOccurrenceV2("duplicate", :output, 1, -1 // 1, "energy", eq.output_units[1], :net_creation)), "energy-balance", _scalar_expr(eq.operator_ref, "temperature", eq.output_units[1]))

    bad_unit = G.G1EquationV2("unit-bad", :additive, eq.operator_ref, ("temperature",), ("temperature",), (G.UnitSignature([1, 0, 0, 0, 0, 0, 0]),), eq.output_units, G.static_time, 0, (:net_creation,), (), "energy-balance", _scalar_expr(eq.operator_ref, "temperature", eq.output_units[1]))
    bad_unit_payload = G.MechanismGenomePayloadV2(payload.contract_ref, payload.states,
        G.G1EquationPlanV2(payload.equation_plan.plan_ref, (payload.equation_plan.equations[1], bad_unit, payload.equation_plan.equations[3])), profile)
    @test G.g1_admission(bad_unit_payload).structural_status == :fail_closed
    empty_occurrence = G.G1EquationV2(eq.equation_id, eq.role, eq.operator_ref, eq.input_state_refs, eq.output_state_refs,
        eq.input_units, eq.output_units, eq.temporal_kind, eq.derivative_order, eq.effects, (), eq.closure_ref, eq.expression)
    empty_occurrence_payload = G.MechanismGenomePayloadV2(payload.contract_ref, payload.states,
        G.G1EquationPlanV2(payload.equation_plan.plan_ref, (payload.equation_plan.equations[1], empty_occurrence, payload.equation_plan.equations[3])), profile)
    empty_occurrence_admission = G.g1_admission(empty_occurrence_payload)
    @test empty_occurrence_admission.structural_status == :fail_closed
    @test "closure_equation_has_no_occurrences:source-0" in empty_occurrence_admission.errors
    @test_throws ArgumentError G.G1OperatorSpecV2(G.QualifiedRefV1("legacy", "v1"), 1, 1, (:additive,), (eq.input_units[1],), (eq.output_units[1],), (G.static_time,), 0, (:none,))
    @test_throws ArgumentError G.G1GenomeContractRefV2("pending://GenomeV5/G1/legacy", "MechanismGenomeV5", nothing, nothing, "candidate-owned-g1-v2", axes, "candidate-1";
        schema_hash_pending_reason="pending", canonicalization_hash_pending_reason="pending", grammar_profile_hash_pending_reason="pending", applicability_profile_hash_pending_reason="pending")
    @test_throws ArgumentError G.G1GenomeContractRefV2("pending://wire-domain:v2", "v5", nothing, nothing, "candidate-owned-g1-v2", axes, "candidate-1";
        schema_hash_pending_reason="pending", canonicalization_hash_pending_reason="pending", grammar_profile_hash_pending_reason="pending", applicability_profile_hash_pending_reason="pending")
    @test_throws ArgumentError G.MechanismGenomeV5(payload.contract_ref, payload, axes)
    forged_public_ref = G.GenomeContractRef("pending://GenomeV5/G1/forged", "v5", G.Digest256(repeat("0", 64)),
        G.g1_canonicalization_hash(), G.g1_compatibility_profile_token(profile))
    @test_throws ArgumentError G.MechanismGenomeV5(forged_public_ref, payload, axes)

    mismatched_axes = G.G1VersionAxesV2(axes.payload_schema_version, G.QualifiedRefV1("wrong.canonical", "v2"), axes.applicability_profile_version, axes.evidence_receipt_version)
    @test_throws ArgumentError G.MechanismGenomeV5(genome.contract_ref, payload, mismatched_axes)

    mimo = payload.equation_plan.equations[3]
    wrong_input_type = G.G1StateInputV2("auxiliary", G.PhysicalType(:vector_field, 0, 0,
        G.TemporalTypeV1(G.static_time), mimo.input_units[2]))
    wrong_input_expr = G.G1TypedExpressionV2((mimo.expression.nodes[1], wrong_input_type, mimo.expression.nodes[3]), (3, 3))
    wrong_input_eq = G.G1EquationV2(mimo.equation_id, mimo.role, mimo.operator_ref, mimo.input_state_refs, mimo.output_state_refs,
        mimo.input_units, mimo.output_units, mimo.temporal_kind, mimo.derivative_order, mimo.effects, mimo.occurrences,
        mimo.closure_ref, wrong_input_expr; input_ranks=mimo.input_ranks, output_ranks=mimo.output_ranks, mimo=true)
    wrong_input_payload = G.MechanismGenomePayloadV2(payload.contract_ref, payload.states,
        G.G1EquationPlanV2(payload.equation_plan.plan_ref, (payload.equation_plan.equations[1], payload.equation_plan.equations[2], wrong_input_eq)), profile)
    wrong_input_admission = G.g1_admission(wrong_input_payload)
    @test wrong_input_admission.structural_status == :fail_closed
    @test any(startswith(e, "typed_expression_input_physical_type_mismatch:constraint-0:auxiliary") for e in wrong_input_admission.errors)
    @test "mimo_input_unit_mismatch" in String.(_FIXTURE.negative_cases)
    mimo_fixture_operator = first(o for o in _FIXTURE.operators if String(o.id) == mimo.operator_ref.id)
    mismatched_input_unit_exponents = Int.(mimo_fixture_operator.input_units[2])
    mismatched_input_unit_exponents[1] += 1
    mismatched_input_unit = _unit(mismatched_input_unit_exponents)
    wrong_input_unit_type = G.PhysicalType(:vector_field, mimo.input_ranks[2], 0,
        G.TemporalTypeV1(G.static_time), mismatched_input_unit)
    wrong_input_unit_node = G.G1StateInputV2("auxiliary", wrong_input_unit_type)
    wrong_input_unit_expr = G.G1TypedExpressionV2((mimo.expression.nodes[1], wrong_input_unit_node, mimo.expression.nodes[3]), (3, 3))
    wrong_input_unit_eq = G.G1EquationV2(mimo.equation_id, mimo.role, mimo.operator_ref, mimo.input_state_refs, mimo.output_state_refs,
        mimo.input_units, mimo.output_units, mimo.temporal_kind, mimo.derivative_order, mimo.effects, mimo.occurrences,
        mimo.closure_ref, wrong_input_unit_expr; input_ranks=mimo.input_ranks, output_ranks=mimo.output_ranks, mimo=true)
    wrong_input_unit_payload = G.MechanismGenomePayloadV2(payload.contract_ref, payload.states,
        G.G1EquationPlanV2(payload.equation_plan.plan_ref, (payload.equation_plan.equations[1], payload.equation_plan.equations[2], wrong_input_unit_eq)), profile)
    wrong_input_unit_admission = G.g1_admission(wrong_input_unit_payload)
    @test wrong_input_unit_admission.structural_status == :fail_closed
    @test any(startswith(e, "typed_expression_input_physical_type_mismatch:constraint-0:auxiliary") for e in wrong_input_unit_admission.errors)
    bad_root_expr = G.G1TypedExpressionV2(mimo.expression.nodes, (3, 2))
    @test_throws ArgumentError G.G1EquationV2(mimo.equation_id, mimo.role, mimo.operator_ref, mimo.input_state_refs, mimo.output_state_refs,
        mimo.input_units, mimo.output_units, mimo.temporal_kind, mimo.derivative_order, mimo.effects, mimo.occurrences, mimo.closure_ref, bad_root_expr; mimo=true)
    short_output = G.G1TypedExpressionV2((mimo.expression.nodes[1], mimo.expression.nodes[2], G.G1MIMOOperatorApplyV2(mimo.operator_ref, (1, 2), (mimo.expression.nodes[3].output_types[1],))), (3, 3))
    @test_throws ArgumentError G.G1EquationV2(mimo.equation_id, mimo.role, mimo.operator_ref, mimo.input_state_refs, mimo.output_state_refs,
        mimo.input_units, mimo.output_units, mimo.temporal_kind, mimo.derivative_order, mimo.effects, mimo.occurrences, mimo.closure_ref, short_output; mimo=true)
    wrong_port_types = G.G1TypedExpressionV2((mimo.expression.nodes[1], mimo.expression.nodes[2], G.G1MIMOOperatorApplyV2(mimo.operator_ref, (1, 2),
        (mimo.expression.nodes[3].output_types[1], G.PhysicalType(:scalar_field, 0, 0, G.TemporalTypeV1(G.static_time), mimo.output_units[2])))), (3, 3))
    @test_throws ArgumentError G.G1EquationV2(mimo.equation_id, mimo.role, mimo.operator_ref, mimo.input_state_refs, mimo.output_state_refs,
        mimo.input_units, mimo.output_units, mimo.temporal_kind, mimo.derivative_order, mimo.effects, mimo.occurrences, mimo.closure_ref, wrong_port_types;
        input_ranks=mimo.input_ranks, output_ranks=mimo.output_ranks, mimo=true)
end
