"""P0 read-only derived view; conditional equivalence certificates are P1."""

struct DerivedEGraphViewV4
    source_hash::Digest256
    source_graph::TypedOperatorHypergraphV1
    function DerivedEGraphViewV4(graph::TypedOperatorHypergraphV1)
        new(canonical_hash(graph), graph)
    end
end
semantic_view(x::DerivedEGraphViewV4) = (source_hash=x.source_hash, source_graph=x.source_graph)
derive_conditional_egraph(graph::TypedOperatorHypergraphV1) = DerivedEGraphViewV4(graph)
derive_conditional_egraph(::TypedOperatorHypergraphV1, ::Any) = throw(ArgumentError("P1 conditional certificates are unavailable in P0"))
