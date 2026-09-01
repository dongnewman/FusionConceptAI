"""Authoritative typed multi-input/multi-output operator hypergraph."""

struct TypedNode
    node_id::String
    node_kind::Symbol
    physical_type::PhysicalType
    label::String
end
semantic_view(x::TypedNode) = (node_kind=x.node_kind, physical_type=x.physical_type)

struct TypedHyperedge
    edge_id::String
    inputs::Tuple{Vararg{Int}}
    outputs::Tuple{Vararg{Int}}
    ast::TypedAST
    role::Symbol
    function TypedHyperedge(id::AbstractString, inputs, outputs, ast::TypedAST, role::Symbol=:additive)
        isempty(inputs) && isempty(outputs) && throw(ArgumentError("hyperedge needs an input or output"))
        length(outputs) == 1 || throw(ArgumentError("P0 supports one AST root output per hyperedge; split multi-output operators"))
        role in (:governing, :additive, :constraint, :interface) || throw(ArgumentError("invalid hyperedge role"))
        new(String(id), Tuple(Int(i) for i in inputs), Tuple(Int(i) for i in outputs), ast, role)
    end
end
semantic_view(x::TypedHyperedge) = (inputs=x.inputs, outputs=x.outputs, ast=x.ast, role=x.role)

struct TypedOperatorHypergraphV1
    nodes::Tuple{Vararg{TypedNode}}
    hyperedges::Tuple{Vararg{TypedHyperedge}}
    function TypedOperatorHypergraphV1(nodes, edges)
        ns, es = Tuple(nodes), Tuple(edges)
        isempty(ns) && throw(ArgumentError("hypergraph needs at least one typed node"))
        n = length(ns)
        for e in es
            all(i -> 1 <= i <= n, e.inputs) && all(i -> 1 <= i <= n, e.outputs) || throw(ArgumentError("hyperedge node reference out of range"))
            length(e.ast.input_ports) == length(e.inputs) || throw(ArgumentError("hyperedge inputs must bind ordered AST input ports"))
            all(e.ast.nodes[p].output_type == ns[node_ref].physical_type for (p, node_ref) in zip(e.ast.input_ports, e.inputs)) ||
                throw(ArgumentError("hyperedge AST input port type mismatch"))
            e.ast.nodes[e.ast.root].output_type == ns[e.outputs[1]].physical_type || throw(ArgumentError("hyperedge AST root/output type mismatch"))
        end
        new(ns, es)
    end
end
semantic_view(x::TypedOperatorHypergraphV1) = (nodes=x.nodes, hyperedges=x.hyperedges)

node(kind::Symbol, ty::PhysicalType; id="", label="") = TypedNode(String(id), kind, ty, String(label))
