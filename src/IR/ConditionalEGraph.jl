"""Derived conditional e-graph with replayable side-condition evidence."""

struct SideConditionCheck
    checker_hash::String
    result::Bool
    replay_artifact::String
    function SideConditionCheck(checker_hash::AbstractString, result::Bool, replay_artifact::AbstractString)
        result && !isempty(checker_hash) && !isempty(replay_artifact) || throw(ArgumentError("side condition must have a passing checker and replay artifact"))
        new(String(checker_hash), result, String(replay_artifact))
    end
end
semantic_view(x::SideConditionCheck) = (checker_hash=x.checker_hash, result=x.result, replay_artifact=x.replay_artifact)

struct SideConditionProof
    condition::String
    check::SideConditionCheck
    function SideConditionProof(condition::AbstractString, check::SideConditionCheck)
        !isempty(condition) || throw(ArgumentError("equivalence condition cannot be empty"))
        new(String(condition), check)
    end
end
semantic_view(x::SideConditionProof) = (condition=x.condition, check=x.check)

struct EquivalenceCertificateV1
    source_hash::String
    left_hash::String
    right_hash::String
    rule_hash::String
    side_condition_proof::SideConditionProof
    function EquivalenceCertificateV1(source::AbstractString, left::AbstractString, right::AbstractString,
                                      rule::AbstractString, proof::SideConditionProof)
        all(!isempty, (source, left, right, rule)) || throw(ArgumentError("equivalence certificate hashes cannot be empty"))
        new(String(source), String(left), String(right), String(rule), proof)
    end
end
semantic_view(x::EquivalenceCertificateV1) = (source_hash=x.source_hash, left_hash=x.left_hash, right_hash=x.right_hash,
                                                rule_hash=x.rule_hash, side_condition_proof=x.side_condition_proof)

struct ConditionalEGraph
    source_hash::String
    expressions::Tuple
    certificates::Tuple{Vararg{EquivalenceCertificateV1}}
end
semantic_view(x::ConditionalEGraph) = (source_hash=x.source_hash, expressions=x.expressions, certificates=x.certificates)

function derive_conditional_egraph(graph::TypedOperatorHypergraphV1, certificates=())
    source = canonical_hash(graph); certs = Tuple(certificates)
    all(c -> c isa EquivalenceCertificateV1 && c.source_hash == source && c.side_condition_proof.check.result, certs) ||
        throw(ArgumentError("certificate source/proof does not bind to authoritative graph"))
    ConditionalEGraph(source, (graph,), certs)
end
