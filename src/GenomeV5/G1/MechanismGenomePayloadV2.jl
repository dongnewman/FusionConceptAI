"""Versioned G1 payload admission over the small equation-plan slice."""

struct G1StateV2
    state_id::String
    physical_type::PhysicalType
    derivative_order::Int
    function G1StateV2(state_id::Any, physical_type::Any; derivative_order=0)
        sid = _g1v5_text(state_id, "state_id")
        physical_type isa PhysicalType || throw(ArgumentError("G1 V2 state physical_type must be PhysicalType"))
        d = derivative_order isa Integer && !(derivative_order isa Bool) ? Int(derivative_order) : throw(ArgumentError("state derivative_order must be an integer"))
        0 <= d <= 255 || throw(ArgumentError("state derivative_order is outside the G1 V2 bound"))
        new(sid, physical_type, d)
    end
end

struct G1AdmissionResultV2
    structural_status::Symbol
    provider_match::Symbol
    resolution::Symbol
    errors::Tuple{Vararg{String}}
    gaps::Tuple{Vararg{String}}
    plan_hash::Digest256
end

struct MechanismGenomePayloadV2
    contract_ref::G1GenomeContractRefV2
    states::Tuple{Vararg{G1StateV2}}
    equation_plan::G1EquationPlanV2
    grammar_profile::GrammarProfileV2
    function MechanismGenomePayloadV2(contract_ref::Any, states::Any,
                                      equation_plan::Any, grammar_profile::Any)
        ref = contract_ref isa G1GenomeContractRefV2 ? contract_ref : throw(ArgumentError("G1 V2 contract_ref must be G1GenomeContractRefV2"))
        ref.version != "v1" || throw(ArgumentError("V1 contract cannot be reinterpreted as G1 V2"))
        ss = _g1v5_tuple(states, "states")
        isempty(ss) || all(x -> typeof(x) === G1StateV2, ss) || throw(ArgumentError("states must contain G1StateV2"))
        ids = Tuple(x.state_id for x in ss)
        length(unique(ids)) == length(ids) || throw(ArgumentError("G1 V2 state ids must be unique"))
        equation_plan isa G1EquationPlanV2 || throw(ArgumentError("equation_plan must be G1EquationPlanV2"))
        grammar_profile isa GrammarProfileV2 || throw(ArgumentError("grammar_profile must be GrammarProfileV2"))
        length(ss) <= grammar_profile.max_states || throw(ArgumentError("G1 V2 state count exceeds profile bound"))
        length(equation_plan.equations) <= grammar_profile.max_equations || throw(ArgumentError("G1 V2 equation count exceeds profile bound"))
        new(ref, Tuple(ss), equation_plan, grammar_profile)
    end
end

function MechanismGenomePayloadV2(old::MechanismGenomePayloadV1)
    throw(ArgumentError("V1 payload is read-only and requires an explicit migration receipt; it is not reinterpreted as V2"))
end

function _g1v5_find_operator(profile::GrammarProfileV2, ref::QualifiedRefV1)
    found = Tuple(x for x in profile.operators if x.ref == ref)
    length(found) == 1 ? first(found) : nothing
end

function _g1v5_find_closure(profile::GrammarProfileV2, ref::String)
    found = Tuple(x for x in profile.closures if x.closure_id == ref)
    length(found) == 1 ? first(found) : nothing
end

function _g1v5_admission_errors(payload::MechanismGenomePayloadV2)
    errors = String[]; gaps = String[]
    profile = payload.grammar_profile
    plan = payload.equation_plan
    state_map = Dict(x.state_id => x for x in payload.states)
    payload.contract_ref.schema_hash === nothing && push!(gaps, "schema_hash_pending")
    payload.contract_ref.canonicalization_hash === nothing && push!(gaps, "canonicalization_hash_pending")
    payload.contract_ref.grammar_profile_hash === nothing && push!(gaps, "grammar_profile_hash_pending")
    payload.contract_ref.applicability_profile_hash === nothing && push!(gaps, "applicability_profile_hash_pending")
    payload.contract_ref.grammar_profile_hash !== nothing &&
        payload.contract_ref.grammar_profile_hash != g1_grammar_profile_hash(profile) &&
        push!(errors, "grammar_profile_hash_mismatch")
    payload.contract_ref.applicability_profile_hash !== nothing &&
        payload.contract_ref.applicability_profile_hash != g1_applicability_profile_hash(profile) &&
        push!(errors, "applicability_profile_hash_mismatch")
    payload.contract_ref.schema_hash !== nothing && payload.contract_ref.schema_hash != g1_schema_hash() &&
        push!(errors, "schema_hash_mismatch")
    payload.contract_ref.canonicalization_hash !== nothing && payload.contract_ref.canonicalization_hash != g1_canonicalization_hash() &&
        push!(errors, "canonicalization_hash_mismatch")
    role_set = Set(x.role for x in plan.equations)
    _G1V5_ROLES ⊆ role_set || push!(errors, "missing_required_equation_role")
    length(plan.equations) <= profile.max_equations || push!(errors, "equation_count_bound")
    occurrence_keys = Set{Tuple}()
    for equation in plan.equations
        operator = _g1v5_find_operator(profile, equation.operator_ref)
        operator === nothing && (push!(errors, "operator_not_in_candidate_owned_profile:" * equation.operator_ref.id * "@" * equation.operator_ref.version); continue)
        equation.role in operator.roles || push!(errors, "operator_role_mismatch:" * equation.equation_id)
        operator.input_arity == length(equation.input_state_refs) || push!(errors, "input_arity_mismatch:" * equation.equation_id)
        operator.output_arity == length(equation.output_state_refs) || push!(errors, "output_arity_mismatch:" * equation.equation_id)
        operator.input_units == equation.input_units || push!(errors, "operator_input_unit_mismatch:" * equation.equation_id)
        operator.output_units == equation.output_units || push!(errors, "operator_output_unit_mismatch:" * equation.equation_id)
        operator.input_ranks == equation.input_ranks || push!(errors, "operator_input_rank_mismatch:" * equation.equation_id)
        operator.output_ranks == equation.output_ranks || push!(errors, "operator_output_rank_mismatch:" * equation.equation_id)
        equation.temporal_kind in operator.temporal_kinds || push!(errors, "temporal_kind_not_supported:" * equation.equation_id)
        equation.derivative_order <= operator.max_derivative_order || push!(errors, "derivative_order_exceeds_operator:" * equation.equation_id)
        Set(equation.effects) == Set(operator.effects) || push!(errors, "effect_declaration_mismatch:" * equation.equation_id)
        roots = equation.expression.roots
        root = equation.expression.nodes[first(roots)]
        if root isa G1OperatorApplyV2
            length(roots) == 1 || push!(errors, "typed_expression_output_binding_mismatch:" * equation.equation_id)
            length(root.input_indices) == operator.input_arity || push!(errors, "typed_expression_input_arity_mismatch:" * equation.equation_id)
            root.operator_ref == equation.operator_ref || push!(errors, "typed_expression_operator_mismatch:" * equation.equation_id)
        elseif root isa G1MIMOOperatorApplyV2
            length(roots) == operator.output_arity || push!(errors, "typed_expression_output_binding_mismatch:" * equation.equation_id)
            all(ridx -> ridx == first(roots), roots) || push!(errors, "typed_expression_mimo_root_node_mismatch:" * equation.equation_id)
            length(root.input_indices) == operator.input_arity || push!(errors, "typed_expression_input_arity_mismatch:" * equation.equation_id)
            length(root.output_types) == operator.output_arity || push!(errors, "typed_expression_output_arity_mismatch:" * equation.equation_id)
            root.operator_ref == equation.operator_ref || push!(errors, "typed_expression_operator_mismatch:" * equation.equation_id)
            all(i -> root.output_types[i].units == equation.output_units[i] &&
                    root.output_types[i].tensor_rank == equation.output_ranks[i] &&
                    root.output_types[i].temporal_type.kind == equation.temporal_kind,
                eachindex(root.output_types)) || push!(errors, "typed_expression_output_type_mismatch:" * equation.equation_id)
        elseif operator.input_arity != 0
            push!(errors, "typed_expression_has_no_operator_application:" * equation.equation_id)
        end
        if root isa Union{G1OperatorApplyV2,G1MIMOOperatorApplyV2}
            indices = root.input_indices
            all(i -> i <= length(equation.expression.nodes), indices) || push!(errors, "typed_expression_input_index_out_of_range:" * equation.equation_id)
            if all(i -> i <= length(equation.expression.nodes), indices)
                bound = Tuple(equation.expression.nodes[i] for i in indices)
                all(x -> x isa G1StateInputV2, bound) || push!(errors, "typed_expression_input_is_not_state:" * equation.equation_id)
                all(x -> x isa G1StateInputV2, bound) &&
                    Tuple(x.state_id for x in bound) == equation.input_state_refs ||
                    push!(errors, "typed_expression_input_binding_mismatch:" * equation.equation_id)
            end
        end
        for node in equation.expression.nodes
            node isa G1StateInputV2 || continue
            haskey(state_map, node.state_id) || (push!(errors, "typed_expression_unknown_state_input:" * equation.equation_id); continue)
            expected_state = state_map[node.state_id]
            node.physical_type == expected_state.physical_type ||
                push!(errors, "typed_expression_input_physical_type_mismatch:" * equation.equation_id * ":" * node.state_id)
        end
        expression_state_ids = Set(n.state_id for n in equation.expression.nodes if n isa G1StateInputV2)
        all(sid in expression_state_ids for sid in equation.input_state_refs) || push!(errors, "typed_expression_state_binding_mismatch:" * equation.equation_id)
        for (i, sid) in enumerate(equation.input_state_refs)
            haskey(state_map, sid) || (push!(errors, "missing_input_state:" * equation.equation_id); continue)
            state_map[sid].physical_type.units == equation.input_units[i] || push!(errors, "input_unit_mismatch:" * equation.equation_id)
            state_map[sid].physical_type.tensor_rank == equation.input_ranks[i] || push!(errors, "input_rank_mismatch:" * equation.equation_id)
            state_map[sid].physical_type.temporal_type.kind == equation.temporal_kind || push!(errors, "input_temporal_mismatch:" * equation.equation_id)
            state_map[sid].derivative_order == equation.derivative_order || push!(errors, "input_derivative_mismatch:" * equation.equation_id)
        end
        for (i, sid) in enumerate(equation.output_state_refs)
            haskey(state_map, sid) || (push!(errors, "missing_output_state:" * equation.equation_id); continue)
            state_map[sid].physical_type.units == equation.output_units[i] || push!(errors, "output_unit_mismatch:" * equation.equation_id)
            state_map[sid].physical_type.tensor_rank == equation.output_ranks[i] || push!(errors, "output_rank_mismatch:" * equation.equation_id)
            state_map[sid].physical_type.temporal_type.kind == equation.temporal_kind || push!(errors, "output_temporal_mismatch:" * equation.equation_id)
            state_map[sid].derivative_order == equation.derivative_order || push!(errors, "output_derivative_mismatch:" * equation.equation_id)
            if root isa G1MIMOOperatorApplyV2 && i <= length(root.output_types)
                root.output_types[i] == state_map[sid].physical_type ||
                    push!(errors, "typed_expression_output_physical_type_mismatch:" * equation.equation_id * ":" * sid)
            elseif root isa G1OperatorApplyV2 && i == 1
                root.output_type == state_map[sid].physical_type ||
                    push!(errors, "typed_expression_output_physical_type_mismatch:" * equation.equation_id * ":" * sid)
            end
        end
        equation.closure_ref === nothing && push!(errors, "missing_closure:" * equation.equation_id)
        equation.closure_ref !== nothing && isempty(equation.occurrences) &&
            push!(errors, "closure_equation_has_no_occurrences:" * equation.equation_id)
        for occurrence in equation.occurrences
            limit = occurrence.port_side === :input ? length(equation.input_state_refs) : length(equation.output_state_refs)
            occurrence.port_index <= limit || push!(errors, "occurrence_port_out_of_range:" * equation.equation_id)
            endpoint_unit = occurrence.port_side === :input ?
                (occurrence.port_index <= length(equation.input_units) ? equation.input_units[occurrence.port_index] : nothing) :
                (occurrence.port_index <= length(equation.output_units) ? equation.output_units[occurrence.port_index] : nothing)
            endpoint_unit === nothing || endpoint_unit == occurrence.unit || push!(errors, "occurrence_unit_mismatch:" * equation.equation_id)
            occurrence.effect in equation.effects || push!(errors, "occurrence_effect_not_declared:" * equation.equation_id)
            key = (occurrence.ledger_id, occurrence.equation_id, occurrence.port_side, occurrence.port_index)
            key in occurrence_keys && push!(errors, "duplicate_effect_occurrence:" * equation.equation_id)
            push!(occurrence_keys, key)
        end
    end
    for closure in profile.closures
        ids = Set(closure.equation_ids)
        relevant = Tuple(e for e in plan.equations if e.equation_id in ids)
        isempty(relevant) && push!(errors, "closure_has_no_equation:" * closure.closure_id)
        actual_ids = Set(e.equation_id for e in relevant)
        actual_ids == ids || push!(errors, "closure_equation_reference_mismatch:" * closure.closure_id)
        for equation in relevant
            equation.closure_ref == closure.closure_id || (push!(errors, "closure_ref_mismatch:" * equation.equation_id * ":" * closure.closure_id); continue)
            all(o -> o.ledger_id == closure.ledger_id && o.unit == closure.unit, equation.occurrences) ||
                push!(errors, "closure_ledger_or_unit_mismatch:" * closure.closure_id)
        end
        balance = sum((o.coefficient for e in relevant for o in e.occurrences if o.ledger_id == closure.ledger_id); init=0 // 1)
        balance == closure.expected_balance || push!(errors, "closure_balance_mismatch:" * closure.closure_id)
    end
    for equation in plan.equations
        equation.closure_ref === nothing && continue
        _g1v5_find_closure(profile, equation.closure_ref) === nothing && push!(errors, "unknown_closure:" * equation.equation_id)
    end
    for operator in profile.operators
        operator.provider_match == :unique_match || push!(gaps, "provider_match=" * String(operator.provider_match) * ":" * operator.ref.id)
    end
    unique!(errors); unique!(gaps); errors, gaps
end

function g1_admission(payload::MechanismGenomePayloadV2)::G1AdmissionResultV2
    errors, gaps = _g1v5_admission_errors(payload)
    structural = isempty(errors) ? :valid : :fail_closed
    provider_gaps = filter(x -> startswith(x, "provider_match="), gaps)
    match = isempty(provider_gaps) ? :unique_match : :no_match
    resolution = isempty(gaps) ? :resolved : :terminal_deferred
    G1AdmissionResultV2(structural, match, resolution, Tuple(errors), Tuple(gaps), equation_plan_hash(payload.equation_plan))
end

g1_equation_plan(payload::MechanismGenomePayloadV2) = begin
    result = g1_admission(payload)
    isempty(result.errors) || throw(ArgumentError("G1 V2 admission failed closed: " * join(result.errors, ",")))
    payload.equation_plan
end

g1_lowering_plan(payload::MechanismGenomePayloadV2) = begin
    result = g1_admission(payload)
    isempty(result.errors) || throw(ArgumentError("G1 V2 lowering requires admitted typed plan"))
    isempty(result.gaps) && result.resolution === :resolved ||
        throw(ArgumentError("G1 V2 candidate-bound lowering is deferred until schema/profile/provider resolution is complete"))
    Tuple(g1_lowering_residual(equation) for equation in payload.equation_plan.equations)
end

semantic_view(x::G1StateV2) = (state_id=x.state_id, physical_type=x.physical_type, derivative_order=x.derivative_order)
semantic_view(x::G1AdmissionResultV2) = (structural_status=x.structural_status, provider_match=x.provider_match,
    resolution=x.resolution, errors=x.errors, gaps=x.gaps, plan_hash=x.plan_hash)
semantic_view(x::MechanismGenomePayloadV2) = (contract_ref=x.contract_ref, states=x.states,
    equation_plan=x.equation_plan, grammar_profile=x.grammar_profile)
canonical_json(x::G1StateV2) = canonical_json(semantic_view(x))
canonical_json(x::G1AdmissionResultV2) = canonical_json(semantic_view(x))
canonical_json(x::MechanismGenomePayloadV2) = canonical_json(semantic_view(x))
g1_payload_hash(x::MechanismGenomePayloadV2) = canonical_hash(x)
