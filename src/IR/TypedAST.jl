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
        is_canonical_value(parameters) || throw(ArgumentError("AST parameters are not canonicalizable"))
        new(opcode, Tuple(Int(i) for i in inputs), output_type, parameters)
    end
end

struct TypedAST
    nodes::Tuple{Vararg{TypedASTNode}}
    root::Int
    input_ports::Tuple{Vararg{Int}}
    function TypedAST(nodes, root::Integer, input_ports=(); registry::OperatorRegistryV1=default_operator_registry())
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
        deep_immutable(ns) || throw(ArgumentError("typed AST payload must be deeply immutable"))
        is_canonical_value(ns) || throw(ArgumentError("typed AST payload is not canonicalizable"))
        for (j, n) in enumerate(ns)
            all(i -> i < j, n.inputs) || throw(ArgumentError("AST must be topologically ordered"))
            _validate_ast_node(registry, n, ns, j)
        end
        new(ns, Int(root), Tuple(Int(i) for i in input_ports))
    end
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
    inferred = _infer_rule_output(operator_manifest(registry, id, "v1").input_type_rule, ins, n.parameters)
    inferred == (n.output_type,) || throw(ArgumentError("typed AST output does not match registry-derived output"))
    validate_operator_signature(registry, ref, ins, (n.output_type,); parameters=n.parameters)
    nothing
end

function ast_leaf(opcode::Symbol, ty::PhysicalType; parameters=(;), input_port=nothing)
    port_tuple = opcode == :state ? (input_port === nothing ? (1,) : (Int(input_port),)) : ()
    TypedAST((TypedASTNode(opcode, (), ty, parameters),), 1, port_tuple)
end

semantic_view(x::TypedASTNode) = (opcode=x.opcode, inputs=x.inputs, output_type=x.output_type, parameters=x.parameters)
semantic_view(x::TypedAST) = (nodes=x.nodes, root=x.root, input_ports=x.input_ports)
