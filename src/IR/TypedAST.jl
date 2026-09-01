"""Immutable, locally typed ASTs used inside hyperedges."""

struct TypedASTNode
    opcode::Symbol
    inputs::Tuple{Vararg{Int}}
    output_type::PhysicalType
    parameters::NamedTuple
    function TypedASTNode(opcode::Symbol, inputs, output_type::PhysicalType, parameters::NamedTuple=(;))
        all(i -> i >= 1, inputs) || throw(ArgumentError("AST input indexes are one-based"))
        new(opcode, Tuple(Int(i) for i in inputs), output_type, parameters)
    end
end

struct TypedAST
    nodes::Tuple{Vararg{TypedASTNode}}
    root::Int
    function TypedAST(nodes, root::Integer)
        ns = Tuple(nodes)
        isempty(ns) && throw(ArgumentError("typed AST cannot be empty"))
        1 <= root <= length(ns) || throw(ArgumentError("AST root out of range"))
        for (j, n) in enumerate(ns)
            all(i -> i < j, n.inputs) || throw(ArgumentError("AST must be topologically ordered"))
        end
        new(ns, Int(root))
    end
end

ast_leaf(opcode::Symbol, ty::PhysicalType; parameters=(;)) = TypedAST((TypedASTNode(opcode, (), ty, parameters),), 1)
