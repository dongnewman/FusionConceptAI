using Test
using FusionConceptAI

const _canon_registry = default_operator_registry()
const _canon_type = PhysicalType(:scalar_field, 0, 3,
    TemporalTypeV1(static_time), UnitSignature())

function _atomic_graph(n; edge_prefix="e", label="")
    nodes = Tuple(node(:state, _canon_type; id="n" * string(i), label=label)
        for i in 1:n)
    edges = Tuple(begin
        input = ASTInputV1(1, _canon_type)
        ident = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,);
            registry=_canon_registry, input_types=(_canon_type,))
        program = TypedASTProgramV1((input, ident), (2,), (1,);
            registry=_canon_registry)
        AtomicMIMOHyperedgeV1(edge_prefix * string(i),
            (MIMOInputBindingV1(1, i),), (MIMOOutputBindingV1(1, i),),
            program, governing; registry=_canon_registry)
    end for i in 1:n)
    TypedOperatorHypergraphV1(nodes, edges; registry=_canon_registry)
end

function _renumbered_atomic_graph(g, order; edge_prefix="renamed")
    old_to_new = Dict(old => new for (new, old) in enumerate(order))
    nodes = Tuple(g.nodes[i] for i in order)
    edges = Tuple(begin
        AtomicMIMOHyperedgeV1(edge_prefix * string(k),
            Tuple(MIMOInputBindingV1(b.program_position,
                old_to_new[b.graph_node_index]) for b in e.input_bindings),
            Tuple(MIMOOutputBindingV1(b.program_position,
                old_to_new[b.graph_node_index]) for b in e.output_bindings),
            e.program, e.role; registry=_canon_registry)
    end for (k, e) in enumerate(g.hyperedges))
    TypedOperatorHypergraphV1(nodes, edges; registry=_canon_registry)
end

@testset "large AtomicMIMO canonical composition" begin
    g9 = _atomic_graph(9)
    g10 = _atomic_graph(10)
    @test canonical_hash((graph=g9,)) == canonical_hash((graph=_renumbered_atomic_graph(g9,
        (9, 1, 8, 2, 7, 3, 6, 4, 5); edge_prefix="other"),))
    @test canonical_hash((graph=g10,)) == canonical_hash((graph=_renumbered_atomic_graph(g10,
        reverse(1:10); edge_prefix="other"),))
    altered = _atomic_graph(10)
    e = altered.hyperedges[1]
    altered_input = ASTInputV1(1, _canon_type)
    altered_apply = ASTApplyV1(OperatorRefV1("NEG", "v1"), (1,);
        registry=_canon_registry, input_types=(_canon_type,))
    altered_program = TypedASTProgramV1((altered_input, altered_apply),
        (2,), (1,); registry=_canon_registry)
    altered_edges = (AtomicMIMOHyperedgeV1("e1", e.input_bindings,
        e.output_bindings, altered_program, governing; registry=_canon_registry),
        altered.hyperedges[2:end]...)
    altered_graph = TypedOperatorHypergraphV1(altered.nodes, altered_edges;
        registry=_canon_registry)
    @test canonical_hash((graph=g10,)) != canonical_hash((graph=altered_graph,))
end

@testset "small AtomicMIMO and legacy boundary" begin
    g8 = _atomic_graph(8)
    @test canonical_hash(g8) == canonical_hash(_renumbered_atomic_graph(g8,
        reverse(1:8); edge_prefix="renamed"))
    @test canonical_hash(g8) ==
        Digest256("8a559fa830e6d5dce722c4602a13bcf29f9f0fb7249097426f1984c25b652371")
    ast = TypedAST((TypedASTNode(:state, (), _canon_type),
        TypedASTNode(:identity, (1,), _canon_type)), 2, (1,);
        registry=_canon_registry)
    legacy_edges = Tuple(TypedHyperedge("legacy" * string(i), (i,), (i,), ast,
        :governing) for i in 1:9)
    legacy = TypedOperatorHypergraphV1(
        Tuple(node(:state, _canon_type; id="l" * string(i)) for i in 1:9),
        legacy_edges)
    @test canonical_hash(legacy) isa Digest256
end

@testset "large disconnected and binding semantics" begin
    atomic7 = _atomic_graph(7)
    disconnected_nodes = (atomic7.nodes...,
        node(:state, _canon_type; id="d1"),
        node(:state, _canon_type; id="d2"),
        node(:state, _canon_type; id="d3"))
    disconnected = TypedOperatorHypergraphV1(disconnected_nodes,
        atomic7.hyperedges; registry=_canon_registry)
    rb = _renumbered_atomic_graph(disconnected, reverse(1:10);
        edge_prefix="renamed")
    reordered = TypedOperatorHypergraphV1(rb.nodes, rb.hyperedges;
        registry=_canon_registry)
    @test canonical_hash((graph=disconnected,)) == canonical_hash((graph=reordered,))
    @test canonical_hash((graph=disconnected,)) !=
        canonical_hash((graph=TypedOperatorHypergraphV1(atomic7.nodes,
            atomic7.hyperedges; registry=_canon_registry),))
    g = _atomic_graph(10)
    e = g.hyperedges[1]
    rebound = AtomicMIMOHyperedgeV1("e1", (MIMOInputBindingV1(1, 2),),
        e.output_bindings, e.program, governing; registry=_canon_registry)
    rebound_graph = TypedOperatorHypergraphV1(g.nodes,
        (rebound, g.hyperedges[2:end]...); registry=_canon_registry)
    @test canonical_hash((graph=g,)) != canonical_hash((graph=rebound_graph,))
    altered_type = PhysicalType(:scalar_field, 1, 3,
        TemporalTypeV1(static_time), UnitSignature())
    @test_throws ArgumentError TypedOperatorHypergraphV1(
        (node(:state, altered_type; id="n1"), g.nodes[2:end]...),
        g.hyperedges; registry=_canon_registry)
    ast = TypedAST((TypedASTNode(:state, (), _canon_type),
        TypedASTNode(:identity, (1,), _canon_type)), 2, (1,);
        registry=_canon_registry)
    mixed = TypedOperatorHypergraphV1(g.nodes,
        (g.hyperedges..., TypedHyperedge("legacy", (1,), (2,), ast, :governing)))
    rg = _renumbered_atomic_graph(g, reverse(1:10); edge_prefix="renamed")
    mixed_reordered = TypedOperatorHypergraphV1(rg.nodes,
        (rg.hyperedges..., TypedHyperedge("legacy-renamed", (10,), (9,), ast, :governing)))
    @test canonical_hash((graph=mixed,)) == canonical_hash((graph=mixed_reordered,))
end
