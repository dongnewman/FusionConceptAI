#= Candidate identity and execution accounting for the current forward chain.

This contract records executed components separately from incomplete stages.
It neither constructs RuntimeEvidence nor supplies terminal authority.
=#
using FusionConceptAI
import FusionConceptAI: semantic_view, canonical_hash

const _CANDIDATE_CHAIN_REVISION = "candidate-chain-execution-v1"
const _CANDIDATE_CHAIN_STAGES = (:candidate_binding, :multi_region_physics,
    :engineering_control_fault, :numerical_verification, :validation_uq,
    :whole_device)
const _CANDIDATE_CHAIN_TOKEN = Val(:candidate_chain_execution)

struct CandidateChainIdentityV4
    candidate_ref::String
    candidate_hash::Digest256
    context_hash::Digest256
    genome_bundle_hash::Digest256
    genome_hashes::NTuple{3,Digest256}
    physical_subject_hash::Digest256
    scenario_hash::Digest256
    obligation_hashes::Tuple{Vararg{Digest256}}
    identity_hash::Digest256
    function CandidateChainIdentityV4(::Val{:candidate_chain_execution}, args...)
        new(args...)
    end
end

semantic_view(x::CandidateChainIdentityV4) = (
    candidate_ref=x.candidate_ref, candidate_hash=x.candidate_hash,
    context_hash=x.context_hash, genome_bundle_hash=x.genome_bundle_hash,
    genome_hashes=x.genome_hashes, physical_subject_hash=x.physical_subject_hash,
    scenario_hash=x.scenario_hash, obligation_hashes=x.obligation_hashes)

function make_candidate_chain_identity(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    body = (candidate_ref=context.candidate.identity_ref,
        candidate_hash=context.candidate_hash, context_hash=context.context_hash,
        genome_bundle_hash=context.candidate.canonical_hashes.genome_bundle_hash,
        genome_hashes=Tuple(g.genome_hash for g in context.genome_bindings),
        physical_subject_hash=context.subject.physical_subject_hash,
        scenario_hash=context.scenario_hash,
        obligation_hashes=context.obligation_hashes)
    CandidateChainIdentityV4(_CANDIDATE_CHAIN_TOKEN, values(body)...,
        canonical_hash(body))
end

struct CandidateChainMetricV4
    name::Symbol
    value::Float64
    unit::UnitSignature
    scope::String
    function CandidateChainMetricV4(name::Symbol, value::Real,
            unit::UnitSignature, scope::AbstractString)
        isfinite(value) || throw(ArgumentError("chain metric must be finite"))
        isempty(scope) && throw(ArgumentError("metric scope is required"))
        new(name, Float64(value), unit, String(scope))
    end
end
semantic_view(x::CandidateChainMetricV4) = (name=x.name, value=x.value,
    unit=x.unit, scope=x.scope)

struct CandidateChainGapV4
    stage::Symbol
    code::Symbol
    status::Symbol
    prerequisite_stages::Tuple{Vararg{Symbol}}
    required_input::String
    acceptance_check::String
    function CandidateChainGapV4(stage, code, status, prerequisite_stages,
            required_input, acceptance_check)
        stage in _CANDIDATE_CHAIN_STAGES || throw(ArgumentError("unknown gap stage"))
        status in (:unsupported, :deferred, :fail) ||
            throw(ArgumentError("a gap cannot be a pass"))
        ps = Tuple(Symbol(p) for p in prerequisite_stages)
        all(p -> p in _CANDIDATE_CHAIN_STAGES && p != stage, ps) ||
            throw(ArgumentError("invalid gap prerequisite"))
        length(unique(ps)) == length(ps) || throw(ArgumentError("duplicate prerequisite"))
        isempty(required_input) && throw(ArgumentError("missing recovery input"))
        isempty(acceptance_check) && throw(ArgumentError("missing recovery acceptance"))
        new(stage, code, status, ps, String(required_input), String(acceptance_check))
    end
end
semantic_view(x::CandidateChainGapV4) = (stage=x.stage, code=x.code,
    status=x.status, prerequisite_stages=x.prerequisite_stages,
    required_input=x.required_input, acceptance_check=x.acceptance_check)

struct CandidateChainStageV4
    stage::Symbol
    identity_hash::Digest256
    source_result_hashes::Tuple{Vararg{Digest256}}
    status::Symbol
    executed_components::Tuple{Vararg{Symbol}}
    unexecuted_components::Tuple{Vararg{Symbol}}
    metrics::Tuple{Vararg{CandidateChainMetricV4}}
    gaps::Tuple{Vararg{CandidateChainGapV4}}
    complete_requested_stage::Bool
    evidence_credit::Int
    stage_hash::Digest256
    function CandidateChainStageV4(::Val{:candidate_chain_execution}, args...)
        new(args...)
    end
end
semantic_view(x::CandidateChainStageV4) = (stage=x.stage,
    identity_hash=x.identity_hash, source_result_hashes=x.source_result_hashes,
    status=x.status, executed_components=x.executed_components,
    unexecuted_components=x.unexecuted_components, metrics=x.metrics,
    gaps=x.gaps, complete_requested_stage=x.complete_requested_stage,
    evidence_credit=x.evidence_credit)

function _candidate_chain_stage(identity::CandidateChainIdentityV4, stage::Symbol,
        source_hashes, status, executed, unexecuted, metrics, gaps)
    body = (stage=stage, identity_hash=canonical_hash(identity),
        source_result_hashes=Tuple(source_hashes), status=status,
        executed_components=Tuple(executed), unexecuted_components=Tuple(unexecuted),
        metrics=Tuple(metrics), gaps=Tuple(gaps),
        complete_requested_stage=stage === :candidate_binding, evidence_credit=0)
    result = CandidateChainStageV4(_CANDIDATE_CHAIN_TOKEN, values(body)...,
        canonical_hash(body))
    canonical_hash(result)
    result
end

function canonical_hash(x::CandidateChainIdentityV4)
    h = canonical_hash(semantic_view(x))
    h == x.identity_hash || throw(ArgumentError("chain identity hash mismatch"))
    h
end
function canonical_hash(x::CandidateChainStageV4)
    x.stage in _CANDIDATE_CHAIN_STAGES || throw(ArgumentError("unknown chain stage"))
    x.status in (:observed, :fail, :unsupported, :deferred) ||
        throw(ArgumentError("invalid execution status"))
    x.evidence_credit == 0 || throw(ArgumentError("execution accounting grants no evidence"))
    x.complete_requested_stage == (x.stage === :candidate_binding) ||
        throw(ArgumentError("partial execution cannot close a requested stage"))
    isempty(x.source_result_hashes) && throw(ArgumentError("stage requires bound source results"))
    isempty(intersect(x.executed_components, x.unexecuted_components)) ||
        throw(ArgumentError("component cannot be both executed and unexecuted"))
    length(unique(x.executed_components)) == length(x.executed_components) &&
        length(unique(x.unexecuted_components)) == length(x.unexecuted_components) ||
        throw(ArgumentError("duplicate execution components"))
    all(g -> g.stage == x.stage, x.gaps) || throw(ArgumentError("gap stage mismatch"))
    h = canonical_hash(semantic_view(x))
    h == x.stage_hash || throw(ArgumentError("chain stage hash mismatch"))
    h
end
