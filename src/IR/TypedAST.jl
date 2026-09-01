"""Immutable, locally typed ASTs used inside hyperedges."""

struct TypedASTNode
    opcode::Symbol
    inputs::Tuple{Vararg{Int}}
    output_type::PhysicalType
    parameters::NamedTuple
    function TypedASTNode(opcode::Symbol, inputs, output_type::PhysicalType, parameters::NamedTuple=(;))
        opcode in (:state, :parameter, :constant, :identity, :add, :sub, :neg, :mul, :div,
                   :gradient, :divergence, :curl, :dt) || throw(ArgumentError("unsupported or unproven typed AST opcode"))
        all(i -> i isa Integer && !isa(i, Bool) && typemin(Int) <= i <= typemax(Int) && i >= 1, inputs) ||
            throw(ArgumentError("AST input indexes must be in-range one-based integers"))
        invoke(_ast_closed_value_valid, Tuple{Any}, parameters) ||
            throw(ArgumentError("AST parameters are not a closed immutable value"))
        new(opcode, Tuple(Int(i) for i in inputs), output_type, parameters)
    end
end

struct TypedAST
    nodes::Tuple{Vararg{TypedASTNode}}
    root::Int
    input_ports::Tuple{Vararg{Int}}
    function TypedAST(nodes, root::Integer, input_ports=(); registry=nothing)
        registry_obj = registry === nothing ? invoke(default_operator_registry, Tuple{}) : registry
        registry_obj isa OperatorRegistryV1 || throw(ArgumentError("AST registry must be OperatorRegistryV1"))
        ns = Tuple(nodes)
        isempty(ns) && throw(ArgumentError("typed AST cannot be empty"))
        root isa Bool && throw(ArgumentError("AST root must be an integer"))
        typemin(Int) <= root <= typemax(Int) || throw(ArgumentError("AST root is out of range"))
        1 <= root <= length(ns) || throw(ArgumentError("AST root out of range"))
        all(i -> i isa Integer && !isa(i, Bool) && typemin(Int) <= i <= typemax(Int) && 1 <= i <= length(ns), input_ports) ||
            throw(ArgumentError("AST input port out of range"))
        length(unique(input_ports)) == length(input_ports) || throw(ArgumentError("AST input ports must be unique"))
        all(ns[i].opcode == :state && isempty(ns[i].inputs) for i in input_ports) ||
            throw(ArgumentError("AST input ports must identify external state leaves"))
        state_leaves = [i for i in eachindex(ns) if ns[i].opcode == :state]
        Set(state_leaves) == Set(input_ports) || throw(ArgumentError("every state leaf must be externally bound exactly once"))
        reachable = falses(length(ns))
        function mark(i)
            reachable[i] && return
            reachable[i] = true
            foreach(mark, ns[i].inputs)
        end
        mark(Int(root))
        all(reachable) || throw(ArgumentError("every AST node must be reachable from AST root"))
        invoke(_ast_closed_value_valid, Tuple{Any}, ns) ||
            throw(ArgumentError("typed AST payload is not a closed immutable value"))
        for (j, n) in enumerate(ns)
            all(i -> i < j, n.inputs) || throw(ArgumentError("AST must be topologically ordered"))
            invoke(_validate_ast_node, Tuple{OperatorRegistryV1,TypedASTNode,Any,Int}, registry_obj, n, ns, j)
        end
        new(ns, Int(root), Tuple(Int(i) for i in input_ports))
    end
end

"""AST-owned closed value checker; no package-wide trait or semantic dispatch is used."""
function _ast_closed_value_valid(x::Any)
    function visit(x)
        x === nothing && return true
        typeof(x) === String && return isvalid(x)
        Base.ismutabletype(typeof(x)) && !(typeof(x) === String || x isa Symbol) && return false
        x isa AbstractString && return false
        x isa Bool && return true
        x isa Symbol && return isvalid(String(x))
        typeof(x) in _P0_SAFE_INTEGER_TYPES && return true
        typeof(x) in _P0_SAFE_FLOAT_TYPES && return isfinite(Float64(x))
        if x isa Rational
            return typeof(numerator(x)) in _P0_SAFE_INTEGER_TYPES && typeof(denominator(x)) in _P0_SAFE_INTEGER_TYPES
        end
        x isa Enum && return true
        x isa Tuple && return all(visit, x)
        x isa NamedTuple && return all(visit, values(x))
        x isa QualifiedRefV1 && return visit(x.id) && visit(x.version)
        x isa OperatorRefV1 && return visit(x.qualified)
        x isa OperatorParameterSpecV1 && return visit(x.name) && visit(x.type_tag) && visit(x.required)
        x isa Digest256 && return visit(x.value)
        x isa UnitSignature && return visit(x.exponents)
        x isa TemporalTypeV1 && return visit(x.kind) && visit(x.derivative_order) && visit(x.clock_ref)
        x isa PhysicalType && return visit(x.value_kind) && visit(x.tensor_rank) && visit(x.spatial_dimension) &&
            visit(x.temporal_type) && visit(x.units)
        x isa TypedASTNode && return visit(x.opcode) && visit(x.inputs) && visit(x.output_type) && visit(x.parameters)
        false
    end
    visit(x)
end

_ast_operator_id(opcode::Symbol) = opcode == :identity ? "IDENTITY" : opcode == :add ? "ADD" :
    opcode == :sub ? "SUB" : opcode == :neg ? "NEG" : opcode == :mul ? "SCALAR_MUL" :
    opcode == :div ? "SCALAR_DIV" : opcode == :dt ? "DT" : opcode == :gradient ? "GRAD" :
    opcode == :divergence ? "DIV_OP" : opcode == :curl ? "CURL" : nothing

function _validate_ast_node(registry::OperatorRegistryV1, n::TypedASTNode, ns, j::Int)
    ins = Tuple(ns[i].output_type for i in n.inputs)
    if n.opcode in (:state, :parameter, :constant)
        isempty(ins) || throw(ArgumentError("$(n.opcode) is a leaf opcode"))
        return nothing
    end
    id = _ast_operator_id(n.opcode)
    id === nothing && throw(ArgumentError("unknown typed AST operator $(n.opcode)"))
    ref = OperatorRefV1(id, "v1")
    rule = invoke(operator_manifest, Tuple{OperatorRegistryV1,String,Union{Nothing,String}}, registry, id, "v1").input_type_rule
    inferred = invoke(_sealed_infer_outputs, Tuple{OperatorTypeRuleV1,Any,Any}, rule, ins, n.parameters)
    inferred == (n.output_type,) || throw(ArgumentError("typed AST output does not match registry-derived output"))
    invoke(validate_operator_signature, Tuple{OperatorRegistryV1,OperatorRefV1,Any,Any}, registry, ref,
        ins, (n.output_type,); parameters=n.parameters)
    nothing
end

function ast_leaf(opcode::Symbol, ty::PhysicalType; parameters=(;), input_port=nothing)
    port_tuple = opcode == :state ? (input_port === nothing ? (1,) : (Int(input_port),)) : ()
    TypedAST((TypedASTNode(opcode, (), ty, parameters),), 1, port_tuple)
end

semantic_view(x::TypedASTNode) = (opcode=x.opcode, inputs=x.inputs, output_type=x.output_type, parameters=x.parameters)
semantic_view(x::TypedAST) = (nodes=x.nodes, root=x.root, input_ports=x.input_ports)
