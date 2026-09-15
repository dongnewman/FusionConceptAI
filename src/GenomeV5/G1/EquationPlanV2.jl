"""Small typed equation plan used by the G1 V2 admission slice."""

abstract type G1ExpressionNodeV2 end

struct G1StateInputV2 <: G1ExpressionNodeV2
    state_id::String
    physical_type::PhysicalType
    function G1StateInputV2(state_id::Any, physical_type::Any)
        physical_type isa PhysicalType || throw(ArgumentError("state input physical_type must be PhysicalType"))
        new(_g1v5_text(state_id, "state input state_id"), physical_type)
    end
end

struct G1ParameterInputV2 <: G1ExpressionNodeV2
    parameter_id::String
    physical_type::PhysicalType
    function G1ParameterInputV2(parameter_id::Any, physical_type::Any)
        physical_type isa PhysicalType || throw(ArgumentError("parameter input physical_type must be PhysicalType"))
        new(_g1v5_text(parameter_id, "parameter input parameter_id"), physical_type)
    end
end

struct G1OperatorApplyV2 <: G1ExpressionNodeV2
    operator_ref::QualifiedRefV1
    input_indices::Tuple{Vararg{Int}}
    output_type::PhysicalType
    parameters::NamedTuple
    function G1OperatorApplyV2(operator_ref::Any, input_indices::Any, output_type::Any; parameters=(;))
        ref = operator_ref isa QualifiedRefV1 ? operator_ref : throw(ArgumentError("apply operator_ref must be QualifiedRefV1"))
        ref.version != "v1" || throw(ArgumentError("legacy v1 operator cannot enter G1 V2 expression"))
        idx = _g1v5_tuple(input_indices, "apply input_indices")
        !isempty(idx) && all(i -> i isa Integer && !(i isa Bool) && i > 0, idx) || throw(ArgumentError("apply input_indices are invalid"))
        length(unique(idx)) == length(idx) || throw(ArgumentError("apply input_indices must be unique"))
        output_type isa PhysicalType || throw(ArgumentError("apply output_type must be PhysicalType"))
        parameters isa NamedTuple || throw(ArgumentError("apply parameters must be NamedTuple"))
        invoke(_ast_closed_value_valid, Tuple{Any}, parameters) || throw(ArgumentError("apply parameters are not closed immutable values"))
        new(ref, Tuple(Int.(idx)), output_type, parameters)
    end
end

"""A typed operator application with one input tuple and several output types."""
struct G1MIMOOperatorApplyV2 <: G1ExpressionNodeV2
    operator_ref::QualifiedRefV1
    input_indices::Tuple{Vararg{Int}}
    output_types::Tuple{Vararg{PhysicalType}}
    function G1MIMOOperatorApplyV2(operator_ref::Any, input_indices::Any, output_types::Any)
        ref = operator_ref isa QualifiedRefV1 ? operator_ref : throw(ArgumentError("MIMO apply operator_ref must be QualifiedRefV1"))
        ref.version != "v1" || throw(ArgumentError("legacy v1 operator cannot enter G1 V2 MIMO expression"))
        idx = _g1v5_tuple(input_indices, "MIMO apply input_indices")
        !isempty(idx) && all(i -> i isa Integer && !(i isa Bool) && i > 0, idx) || throw(ArgumentError("MIMO apply input_indices are invalid"))
        length(unique(idx)) == length(idx) || throw(ArgumentError("MIMO apply input_indices must be unique"))
        outs = _g1v5_tuple(output_types, "MIMO apply output_types")
        !isempty(outs) && all(x -> x isa PhysicalType, outs) || throw(ArgumentError("MIMO apply output_types are invalid"))
        new(ref, Tuple(Int.(idx)), Tuple(outs))
    end
end

struct G1TypedExpressionV2
    nodes::Tuple{Vararg{G1ExpressionNodeV2}}
    roots::Tuple{Vararg{Int}}
    function G1TypedExpressionV2(nodes::Any, root::Any)
        ns = _g1v5_tuple(nodes, "expression nodes")
        !isempty(ns) && all(x -> x isa G1ExpressionNodeV2, ns) || throw(ArgumentError("expression nodes are not typed"))
        rs = root isa Integer && !(root isa Bool) ? (Int(root),) :
            root isa Tuple && !isempty(root) && all(x -> x isa Integer && !(x isa Bool), root) ? Tuple(Int.(root)) :
            throw(ArgumentError("expression root(s) must be an integer or non-empty tuple"))
        all(r -> 1 <= r <= length(ns), rs) || throw(ArgumentError("expression root is out of range"))
        for (i, node) in enumerate(ns)
            if node isa G1OperatorApplyV2
                all(j -> j < i, node.input_indices) || throw(ArgumentError("expression is not a topologically ordered DAG"))
            elseif node isa G1MIMOOperatorApplyV2
                all(j -> j < i, node.input_indices) || throw(ArgumentError("MIMO expression is not a topologically ordered DAG"))
            end
        end
        new(Tuple(ns), rs)
    end
end

function Base.getproperty(expression::G1TypedExpressionV2, name::Symbol)
    name === :root && return length(getfield(expression, :roots)) == 1 ? first(getfield(expression, :roots)) :
        throw(ArgumentError("multi-output expression has roots; use .roots"))
    getfield(expression, name)
end

function g1_expression_hash(expression::G1TypedExpressionV2)
    canonical_hash(expression)
end

struct G1ResidualSemanticsV2
    equation_id::String
    role::Symbol
    operator_ref::QualifiedRefV1
    input_state_refs::Tuple{Vararg{String}}
    output_state_refs::Tuple{Vararg{String}}
    expression_hash::Digest256
    expression::G1TypedExpressionV2
    input_units::Tuple{Vararg{UnitSignature}}
    output_units::Tuple{Vararg{UnitSignature}}
    input_ranks::Tuple{Vararg{Int}}
    output_ranks::Tuple{Vararg{Int}}
    temporal_kind::TimeKindV1
    derivative_order::Int
    effects::Tuple{Vararg{Symbol}}
    closure_ref::Union{Nothing,String}
    occurrences::Tuple{Vararg{G1LedgerOccurrenceV2}}
    claim_ceiling::Symbol
    residual_kind::Symbol
end

function g1_lowering_residual(equation)
    G1ResidualSemanticsV2(equation.equation_id, equation.role, equation.operator_ref,
        equation.input_state_refs, equation.output_state_refs, g1_expression_hash(equation.expression),
        equation.expression, equation.input_units, equation.output_units, equation.input_ranks,
        equation.output_ranks, equation.temporal_kind, equation.derivative_order, equation.effects,
        equation.closure_ref, equation.occurrences,
        :contract_only,
        equation.role === :constraint ? :constraint_residual : :equation_residual)
end

struct G1EquationV2
    equation_id::String
    role::Symbol
    operator_ref::QualifiedRefV1
    input_state_refs::Tuple{Vararg{String}}
    output_state_refs::Tuple{Vararg{String}}
    input_units::Tuple{Vararg{UnitSignature}}
    output_units::Tuple{Vararg{UnitSignature}}
    input_ranks::Tuple{Vararg{Int}}
    output_ranks::Tuple{Vararg{Int}}
    temporal_kind::TimeKindV1
    derivative_order::Int
    effects::Tuple{Vararg{Symbol}}
    occurrences::Tuple{Vararg{G1LedgerOccurrenceV2}}
    closure_ref::Union{Nothing,String}
    expression::G1TypedExpressionV2
    function G1EquationV2(equation_id::Any, role::Any, operator_ref::Any,
                          input_state_refs::Any, output_state_refs::Any,
                          input_units::Any, output_units::Any, temporal_kind::Any,
                          derivative_order::Any, effects::Any, occurrences::Any,
                          closure_ref::Any, expression::Any; input_ranks=nothing, output_ranks=nothing, mimo=nothing)
        eid = _g1v5_text(equation_id, "equation_id")
        r = role isa Symbol ? role : Symbol(role)
        r in _G1V5_ROLES || throw(ArgumentError("equation role is invalid"))
        ref = operator_ref isa QualifiedRefV1 ? operator_ref : throw(ArgumentError("equation operator_ref must be QualifiedRefV1"))
        ref.version != "v1" || throw(ArgumentError("legacy v1 operator cannot enter G1 V2 equation plan"))
        ins = _g1v5_tuple(input_state_refs, "input_state_refs")
        outs = _g1v5_tuple(output_state_refs, "output_state_refs")
        isempty(outs) || all(x -> x isa AbstractString && !isempty(String(x)), outs) || throw(ArgumentError("output state refs are invalid"))
        all(x -> x isa AbstractString && !isempty(String(x)), ins) || throw(ArgumentError("input state refs are invalid"))
        length(unique(String.(ins))) == length(ins) || throw(ArgumentError("input state refs must be unique"))
        length(unique(String.(outs))) == length(outs) || throw(ArgumentError("output state refs must be unique"))
        iu = _g1v5_tuple(input_units, "input_units"); ou = _g1v5_tuple(output_units, "output_units")
        length(iu) == length(ins) && length(ou) == length(outs) || throw(ArgumentError("equation unit arity does not match state arity"))
        all(x -> x isa UnitSignature, iu) && all(x -> x isa UnitSignature, ou) || throw(ArgumentError("equation units must be UnitSignature"))
        ir = input_ranks === nothing ? ntuple(_ -> 0, length(ins)) : _g1v5_tuple(input_ranks, "equation input_ranks")
        or = output_ranks === nothing ? ntuple(_ -> 0, length(outs)) : _g1v5_tuple(output_ranks, "equation output_ranks")
        length(ir) == length(ins) && length(or) == length(outs) && all(x -> x isa Integer && !(x isa Bool) && x >= 0, ir) && all(x -> x isa Integer && !(x isa Bool) && x >= 0, or) || throw(ArgumentError("equation tensor ranks are invalid"))
        expected_mimo = length(ins) > 1 || length(outs) > 1
        expected_mimo && (input_ranks === nothing || output_ranks === nothing) &&
            throw(ArgumentError("MIMO equation requires explicit input_ranks and output_ranks"))
        temporal_kind isa TimeKindV1 || throw(ArgumentError("equation temporal_kind is invalid"))
        d = derivative_order isa Integer && !(derivative_order isa Bool) ? Int(derivative_order) : throw(ArgumentError("derivative_order must be an integer"))
        0 <= d <= 255 || throw(ArgumentError("derivative_order is outside the G1 V2 bound"))
        es = _g1v5_tuple(effects, "effects")
        all(x -> x isa Symbol && x in _G1V5_EFFECTS, es) || throw(ArgumentError("equation effect is invalid"))
        os = _g1v5_tuple(occurrences, "occurrences")
        all(x -> typeof(x) === G1LedgerOccurrenceV2, os) || throw(ArgumentError("equation occurrences are not typed"))
        keys = Tuple((x.equation_id, x.port_side, x.port_index, x.ledger_id) for x in os)
        all(x -> x.equation_id == eid, os) || throw(ArgumentError("occurrence equation_id does not match equation"))
        length(unique(keys)) == length(keys) || throw(ArgumentError("equation has duplicate ledger occurrences"))
        cr = closure_ref === nothing ? nothing : _g1v5_text(closure_ref, "closure_ref")
        expr = expression isa G1TypedExpressionV2 ? expression : throw(ArgumentError("equation expression must be G1TypedExpressionV2"))
        length(expr.roots) == length(outs) || throw(ArgumentError("expression root count does not match equation output count"))
        if length(outs) > 1
            root_node = expr.nodes[first(expr.roots)]
            root_node isa G1MIMOOperatorApplyV2 || throw(ArgumentError("multi-output equation requires one typed MIMO apply root"))
            all(ridx -> ridx == first(expr.roots), expr.roots) || throw(ArgumentError("MIMO roots must bind the same apply node in output order"))
        end
        for (i, root_index) in enumerate(expr.roots)
            root = expr.nodes[root_index]
            root isa G1MIMOOperatorApplyV2 && length(root.output_types) < i && throw(ArgumentError("MIMO expression output binding is incomplete"))
            root_type = root isa G1StateInputV2 ? root.physical_type :
                root isa G1ParameterInputV2 ? root.physical_type :
                root isa G1OperatorApplyV2 ? root.output_type : root.output_types[i]
            root_type.units == ou[i] && root_type.tensor_rank == or[i] &&
                root_type.temporal_type.kind == temporal_kind ||
                throw(ArgumentError("expression root type does not match equation output"))
        end
        mimo === nothing || mimo === expected_mimo || throw(ArgumentError("mimo flag does not match equation arity"))
        new(eid, r, ref, Tuple(String.(ins)), Tuple(String.(outs)), Tuple(iu), Tuple(ou),
            Tuple(Int.(ir)), Tuple(Int.(or)), temporal_kind, d, Tuple(es), Tuple(os), cr, expr)
    end
end

struct G1EquationPlanV2
    plan_ref::QualifiedRefV1
    equations::Tuple{Vararg{G1EquationV2}}
    function G1EquationPlanV2(plan_ref::Any, equations::Any)
        ref = plan_ref isa QualifiedRefV1 ? plan_ref : throw(ArgumentError("plan_ref must be QualifiedRefV1"))
        ref.version != "v1" || throw(ArgumentError("legacy v1 equation plan cannot enter G1 V2"))
        eqs = _g1v5_tuple(equations, "equations")
        isempty(eqs) || all(x -> typeof(x) === G1EquationV2, eqs) || throw(ArgumentError("equation plan contains an invalid equation"))
        ids = Tuple(x.equation_id for x in eqs)
        length(unique(ids)) == length(ids) || throw(ArgumentError("equation plan contains duplicate equation ids"))
        new(ref, Tuple(eqs))
    end
end

equation_roles(plan::G1EquationPlanV2) = Tuple(sort!(collect(unique(x.role for x in plan.equations))))
equation_plan_hash(plan::G1EquationPlanV2) = canonical_hash(plan)

semantic_view(x::G1EquationV2) =
    (equation_id=x.equation_id, role=x.role, operator_ref=x.operator_ref,
     input_state_refs=x.input_state_refs, output_state_refs=x.output_state_refs,
     input_units=x.input_units, output_units=x.output_units, input_ranks=x.input_ranks,
     output_ranks=x.output_ranks, temporal_kind=x.temporal_kind,
     derivative_order=x.derivative_order, effects=x.effects, occurrences=x.occurrences,
     closure_ref=x.closure_ref, expression=x.expression)
semantic_view(x::G1EquationPlanV2) = (plan_ref=x.plan_ref, equations=x.equations)
semantic_view(x::G1StateInputV2) = (state_id=x.state_id, physical_type=x.physical_type)
semantic_view(x::G1ParameterInputV2) = (parameter_id=x.parameter_id, physical_type=x.physical_type)
semantic_view(x::G1OperatorApplyV2) = (operator_ref=x.operator_ref, input_indices=x.input_indices, output_type=x.output_type, parameters=x.parameters)
semantic_view(x::G1MIMOOperatorApplyV2) = (operator_ref=x.operator_ref, input_indices=x.input_indices, output_types=x.output_types)
semantic_view(x::G1TypedExpressionV2) = (nodes=x.nodes, roots=x.roots)
semantic_view(x::G1ResidualSemanticsV2) = (equation_id=x.equation_id, role=x.role, operator_ref=x.operator_ref,
    input_state_refs=x.input_state_refs, output_state_refs=x.output_state_refs,
    expression_hash=x.expression_hash, expression=x.expression, input_units=x.input_units,
    output_units=x.output_units, input_ranks=x.input_ranks, output_ranks=x.output_ranks,
    temporal_kind=x.temporal_kind, derivative_order=x.derivative_order, effects=x.effects,
    closure_ref=x.closure_ref, occurrences=x.occurrences, claim_ceiling=x.claim_ceiling,
    residual_kind=x.residual_kind)
canonical_json(x::G1EquationV2) = canonical_json(semantic_view(x))
canonical_json(x::G1EquationPlanV2) = canonical_json(semantic_view(x))
canonical_json(x::G1StateInputV2) = canonical_json(semantic_view(x))
canonical_json(x::G1ParameterInputV2) = canonical_json(semantic_view(x))
canonical_json(x::G1OperatorApplyV2) = canonical_json(semantic_view(x))
canonical_json(x::G1MIMOOperatorApplyV2) = canonical_json(semantic_view(x))
canonical_json(x::G1TypedExpressionV2) = canonical_json(semantic_view(x))
canonical_json(x::G1ResidualSemanticsV2) = canonical_json(semantic_view(x))
