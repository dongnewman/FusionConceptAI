"""Authoritative typed multi-input/multi-output operator hypergraph."""

struct TypedNode
    node_id::String
    node_kind::Symbol
    physical_type::PhysicalType
    label::String
end

struct TypedHyperedge
    edge_id::String
    inputs::Tuple{Vararg{Int}}
    outputs::Tuple{Vararg{Int}}
    ast::TypedAST
    role::Symbol
    function TypedHyperedge(id::AbstractString, inputs, outputs, ast::TypedAST, role::Symbol=:additive)
        isempty(inputs) && isempty(outputs) && throw(ArgumentError("hyperedge needs an input or output"))
        role in (:governing, :additive, :constraint, :interface) || throw(ArgumentError("invalid hyperedge role"))
        new(String(id), Tuple(Int(i) for i in inputs), Tuple(Int(i) for i in outputs), ast, role)
    end
end

struct TypedOperatorHypergraphV1
    nodes::Tuple{Vararg{TypedNode}}
    hyperedges::Tuple{Vararg{TypedHyperedge}}
    function TypedOperatorHypergraphV1(nodes, edges)
        ns, es = Tuple(nodes), Tuple(edges)
        isempty(ns) && throw(ArgumentError("hypergraph needs at least one typed node"))
        n = length(ns)
        for e in es
            all(i -> 1 <= i <= n, e.inputs) && all(i -> 1 <= i <= n, e.outputs) || throw(ArgumentError("hyperedge node reference out of range"))
        end
        new(ns, es)
    end
end

node(kind::Symbol, ty::PhysicalType; id="", label="") = TypedNode(String(id), kind, ty, String(label))
