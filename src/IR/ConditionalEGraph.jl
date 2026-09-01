"""Derived conditional e-graph. It has no authority over the source hypergraph."""

struct SideConditionProof
    condition::String
    proof_ref::String
    function SideConditionProof(condition::AbstractString, proof_ref::AbstractString)
        all(!isempty, (condition, proof_ref)) || throw(ArgumentError("equivalence requires a side-condition proof"))
        new(String(condition), String(proof_ref))
    end
end

struct EquivalenceCertificateV1
    left_hash::String
    right_hash::String
    side_condition_proof::SideConditionProof
end

struct ConditionalEGraph
    source_hash::String
    expressions::Tuple
    certificates::Tuple{Vararg{EquivalenceCertificateV1}}
end

function derive_conditional_egraph(graph::TypedOperatorHypergraphV1, certificates=())
    certs = Tuple(certificates)
    all(c -> c isa EquivalenceCertificateV1, certs) || throw(ArgumentError("invalid equivalence certificate"))
    ConditionalEGraph(canonical_hash(graph), (graph,), certs)
end
