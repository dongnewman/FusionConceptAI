"""Additive, contract-only whole-device validation ledger.

This file records the admission boundary for a future whole-device authority;
it is intentionally not included by the package module and never emits a
terminal disposition.  It preserves applicability, provider, execution,
numerical, physical, lifecycle, evidence, conservation, convergence, error,
VVUQ, engineering, net-output, replay, originality, and R01-R10 dimensions
without collapsing them into one pass/fail bit.
"""

import FusionConceptAI: Digest256, digest256_text, canonical_hash, semantic_view

const _FVLC_REVISION = "final-validation-ledger-contract-v1"
const _FVLC_CLAIM_CEILING = :contract_only
const _FVLC_PUBLISH = :no_publish
const _FVLC_AUTHORITY = "FinalWholeDeviceAuthorityV4"
const _FVLC_REQUIRED_R_IDS = Tuple(Symbol("R", lpad(string(i), 2, '0')) for i in 1:10)
const _FVLC_REQUIRED_ENG_IDS = (
    "ENG-BALANCE", "ENG-STABILITY", "ENG-ORBIT-TRANSPORT", "ENG-BURN",
    "ENG-RADIATION", "ENG-EXTERNAL-DOMAIN", "ENG-POWER", "ENG-COOLING",
    "ENG-MATERIAL", "ENG-STRUCTURE", "ENG-CONTROL-FAULT", "ENG-FUEL-CYCLE",
    "ENG-CONVERSION", "ENG-AUXILIARY", "ENG-NET-LEDGER")
const _FVLC_REQUIRED_ALL_IDS = (String.( _FVLC_REQUIRED_R_IDS)..., _FVLC_REQUIRED_ENG_IDS...)
const _FVLC_ALLOWED_APPLICABILITY = (:required, :not_applicable)
const _FVLC_ALLOWED_PROVIDER_MATCH =
    (:unique_match, :no_match, :ambiguous, :out_of_domain, :invalid_signature)
const _FVLC_ALLOWED_RESOLUTION = (:resolved, :terminal_deferred)
const _FVLC_ALLOWED_EXECUTION =
    (:process_completed, :program_exception, :human_interruption, :not_executed, :unknown)
const _FVLC_ALLOWED_STAGE =
    (:pass, :physical_fail, :numerical_fail, :unknown, :not_applicable, :not_executed, :terminal_deferred)
const _FVLC_ALLOWED_LIFECYCLE =
    (:proposed, :compiled, :materialized, :integrated_executed, :terminal_classified)
const _FVLC_ALLOWED_DECISION =
    (:contract_only, :fail_closed, :terminal_deferred, :numerical_fail, :physical_fail, :unknown)
const _FVLC_ALLOWED_LEDGER_STATUS = (:pending, :observed, :terminal_classified)

struct _FinalValidationLedgerInputError <: Exception
    detail::String
end

Base.showerror(io::IO, error::_FinalValidationLedgerInputError) =
    print(io, "final validation ledger input error: ", error.detail)

_fvlc_input_error(message) = _FinalValidationLedgerInputError(String(message))

# The token is a mutable singleton so a freshly constructed token is not
# identity-equivalent to the trusted instance.  Identity is only one seam:
# every token-bearing constructor below also revalidates its full invariant,
# so reading the trusted binding cannot be used to create an invalid record.
mutable struct _FVLCConstructionToken end
const _FVLC_TOKEN = _FVLCConstructionToken()

function _fvlc_require_token(token::_FVLCConstructionToken)
    token === _FVLC_TOKEN || throw(ArgumentError("invalid final-validation construction token"))
    nothing
end

_fvlc_text(x, label) = begin
    x isa AbstractString || throw(ArgumentError("$label must be text"))
    value = String(x)
    isempty(strip(value)) && throw(ArgumentError("$label must be non-empty"))
    isvalid(value) || throw(ArgumentError("$label must be valid UTF-8"))
    value
end

function _fvlc_digest(x, label; allow_nothing=true)
    x === nothing && allow_nothing && return nothing
    x isa Digest256 && return x
    x isa AbstractString || throw(ArgumentError("$label must be Digest256 text"))
    length(String(x)) == 64 || throw(ArgumentError("$label must be 64 hex characters"))
    Digest256(String(x))
end

_fvlc_symbol(x, allowed, label) = begin
    s = x isa Symbol ? x : Symbol(x)
    s in allowed || throw(ArgumentError("invalid $label"))
    s
end

_fvlc_tuple(x, label) = begin
    result = Tuple(x)
    result
end

"""All identity axes that must be rebuilt when an upstream semantic input changes."""
struct FinalValidationLedgerIdentityV1
    candidate_ref::Union{Nothing,String}
    mission_hash::Union{Nothing,Digest256}
    mechanism_hash::Union{Nothing,Digest256}
    field_geometry_hash::Union{Nothing,Digest256}
    realization_control_hash::Union{Nothing,Digest256}
    genome_bundle_hash::Union{Nothing,Digest256}
    physical_subject_hash::Union{Nothing,Digest256}
    solver_input_hash::Union{Nothing,Digest256}
    scenario_manifest_hash::Union{Nothing,Digest256}
    provider_ref::Union{Nothing,String}
    provider_hash::Union{Nothing,Digest256}
    toolchain_ref::Union{Nothing,String}
    toolchain_hash::Union{Nothing,Digest256}
    source_tree_ref::Union{Nothing,String}
    source_tree_hash::Union{Nothing,Digest256}
    build_ref::Union{Nothing,String}
    build_hash::Union{Nothing,Digest256}
    channel_ref::Union{Nothing,String}
    channel_hash::Union{Nothing,Digest256}
    interpreter_ref::Union{Nothing,String}
    interpreter_hash::Union{Nothing,Digest256}
    module_ref::Union{Nothing,String}
    module_hash::Union{Nothing,Digest256}
end

function FinalValidationLedgerIdentityV1(; candidate_ref=nothing, mission_hash=nothing,
        mechanism_hash=nothing, field_geometry_hash=nothing,
        realization_control_hash=nothing, genome_bundle_hash=nothing,
        physical_subject_hash=nothing, solver_input_hash=nothing,
        scenario_manifest_hash=nothing, provider_ref=nothing, provider_hash=nothing,
        toolchain_ref=nothing, toolchain_hash=nothing, source_tree_ref=nothing,
        source_tree_hash=nothing, build_ref=nothing, build_hash=nothing,
        channel_ref=nothing, channel_hash=nothing, interpreter_ref=nothing,
        interpreter_hash=nothing, module_ref=nothing, module_hash=nothing)
    text_or_nothing(x, label) = x === nothing ? nothing : _fvlc_text(x, label)
    FinalValidationLedgerIdentityV1(
        text_or_nothing(candidate_ref, "candidate_ref"),
        _fvlc_digest(mission_hash, "mission_hash"),
        _fvlc_digest(mechanism_hash, "mechanism_hash"),
        _fvlc_digest(field_geometry_hash, "field_geometry_hash"),
        _fvlc_digest(realization_control_hash, "realization_control_hash"),
        _fvlc_digest(genome_bundle_hash, "genome_bundle_hash"),
        _fvlc_digest(physical_subject_hash, "physical_subject_hash"),
        _fvlc_digest(solver_input_hash, "solver_input_hash"),
        _fvlc_digest(scenario_manifest_hash, "scenario_manifest_hash"),
        text_or_nothing(provider_ref, "provider_ref"), _fvlc_digest(provider_hash, "provider_hash"),
        text_or_nothing(toolchain_ref, "toolchain_ref"), _fvlc_digest(toolchain_hash, "toolchain_hash"),
        text_or_nothing(source_tree_ref, "source_tree_ref"), _fvlc_digest(source_tree_hash, "source_tree_hash"),
        text_or_nothing(build_ref, "build_ref"), _fvlc_digest(build_hash, "build_hash"),
        text_or_nothing(channel_ref, "channel_ref"), _fvlc_digest(channel_hash, "channel_hash"),
        text_or_nothing(interpreter_ref, "interpreter_ref"), _fvlc_digest(interpreter_hash, "interpreter_hash"),
        text_or_nothing(module_ref, "module_ref"), _fvlc_digest(module_hash, "module_hash"))
end

semantic_view(x::FinalValidationLedgerIdentityV1) = (
    candidate_ref=x.candidate_ref, mission_hash=x.mission_hash,
    mechanism_hash=x.mechanism_hash, field_geometry_hash=x.field_geometry_hash,
    realization_control_hash=x.realization_control_hash,
    genome_bundle_hash=x.genome_bundle_hash, physical_subject_hash=x.physical_subject_hash,
    solver_input_hash=x.solver_input_hash, scenario_manifest_hash=x.scenario_manifest_hash,
    provider_ref=x.provider_ref, provider_hash=x.provider_hash,
    toolchain_ref=x.toolchain_ref, toolchain_hash=x.toolchain_hash,
    source_tree_ref=x.source_tree_ref, source_tree_hash=x.source_tree_hash,
    build_ref=x.build_ref, build_hash=x.build_hash, channel_ref=x.channel_ref,
    channel_hash=x.channel_hash, interpreter_ref=x.interpreter_ref,
    interpreter_hash=x.interpreter_hash, module_ref=x.module_ref, module_hash=x.module_hash)

struct FinalValidationLedgerEvidenceRefV1
    evidence_id::String
    kind::Symbol
    content_hash::Union{Nothing,Digest256}
    candidate_ref::Union{Nothing,String}
    scenario_ref::Union{Nothing,String}
    physical_subject_hash::Union{Nothing,Digest256}
    solver_input_hash::Union{Nothing,Digest256}
    independence_group::Union{Nothing,String}
    status::Symbol
end

function FinalValidationLedgerEvidenceRefV1(evidence_id, kind;
        content_hash=nothing, candidate_ref=nothing, scenario_ref=nothing,
        physical_subject_hash=nothing, solver_input_hash=nothing,
        independence_group=nothing, status=:pending)
    k = _fvlc_symbol(kind, (:verification, :validation, :discrepancy, :uncertainty,
        :engineering, :net_output, :replay, :originality, :applicability_proof),
        "evidence kind")
    st = _fvlc_symbol(status, (:pending, :pass, :unknown, :terminal_deferred), "evidence status")
    text_or_nothing(x, label) = x === nothing ? nothing : _fvlc_text(x, label)
    FinalValidationLedgerEvidenceRefV1(_fvlc_text(evidence_id, "evidence_id"), k,
        _fvlc_digest(content_hash, "content_hash"), text_or_nothing(candidate_ref, "candidate_ref"),
        text_or_nothing(scenario_ref, "scenario_ref"),
        _fvlc_digest(physical_subject_hash, "physical_subject_hash"),
        _fvlc_digest(solver_input_hash, "solver_input_hash"),
        text_or_nothing(independence_group, "independence_group"), st)
end

semantic_view(x::FinalValidationLedgerEvidenceRefV1) = (
    evidence_id=x.evidence_id, kind=x.kind, content_hash=x.content_hash,
    candidate_ref=x.candidate_ref, scenario_ref=x.scenario_ref,
    physical_subject_hash=x.physical_subject_hash, solver_input_hash=x.solver_input_hash,
    independence_group=x.independence_group, status=x.status)

"""Metric groups retain independent conservation/convergence/error/VVUQ/engineering axes."""
struct FinalValidationLedgerMetricsV1
    conservation::NamedTuple
    convergence::NamedTuple
    error::NamedTuple
    vvuq::NamedTuple
    engineering::NamedTuple
    net_output::NamedTuple
    replay::NamedTuple
    originality::NamedTuple
    function FinalValidationLedgerMetricsV1(; conservation=(status=:pending,),
            convergence=(status=:pending,), error=(status=:pending,),
            vvuq=(status=:pending,), engineering=(status=:pending,),
            net_output=(status=:pending,), replay=(status=:pending,),
            originality=(status=:pending,))
        all(x -> x isa NamedTuple, (conservation, convergence, error, vvuq,
            engineering, net_output, replay, originality)) ||
            throw(ArgumentError("all ledger metric groups must be NamedTuple"))
        new(conservation, convergence, error, vvuq, engineering, net_output,
            replay, originality)
    end
end

semantic_view(x::FinalValidationLedgerMetricsV1) = (
    conservation=x.conservation, convergence=x.convergence, error=x.error,
    vvuq=x.vvuq, engineering=x.engineering, net_output=x.net_output,
    replay=x.replay, originality=x.originality)

struct FinalValidationLedgerObligationV1
    obligation_id::String
    family::Symbol
    requirement::String
    required::Bool
    ledger_status::Symbol
    applicability::Symbol
    provider_match::Symbol
    resolution::Symbol
    execution_classification::Symbol
    numerical_status::Symbol
    physical_status::Symbol
    lifecycle::Symbol
    claim_ceiling::Symbol
    authority::String
    accepted::Bool
    identity::FinalValidationLedgerIdentityV1
    evidence_refs::Tuple
    metrics::FinalValidationLedgerMetricsV1
    remaining_gaps::Tuple
    function FinalValidationLedgerObligationV1(token::_FVLCConstructionToken,
            obligation_id::String, family::Symbol, requirement::String, required::Bool,
            ledger_status::Symbol, applicability::Symbol, provider_match::Symbol,
            resolution::Symbol, execution_classification::Symbol,
            numerical_status::Symbol, physical_status::Symbol, lifecycle::Symbol,
            claim_ceiling::Symbol, authority::String, accepted::Bool,
            identity::FinalValidationLedgerIdentityV1, evidence_refs::Tuple,
            metrics::FinalValidationLedgerMetricsV1, remaining_gaps::Tuple)
        _fvlc_require_token(token)
        _fvlc_validate_obligation_parts(obligation_id, family, requirement, required,
            ledger_status, applicability, provider_match, resolution,
            execution_classification, numerical_status, physical_status, lifecycle,
            claim_ceiling, authority, accepted, identity, evidence_refs, metrics,
            remaining_gaps)
        new(obligation_id, family, requirement, required, ledger_status, applicability,
            provider_match, resolution, execution_classification, numerical_status,
            physical_status, lifecycle, claim_ceiling, authority, accepted, identity,
            evidence_refs, metrics, remaining_gaps)
    end
end

function _fvlc_validate_obligation_parts(obligation_id::String, family::Symbol,
        requirement::String, required::Bool, ledger_status::Symbol,
        applicability::Symbol, provider_match::Symbol, resolution::Symbol,
        execution_classification::Symbol, numerical_status::Symbol,
        physical_status::Symbol, lifecycle::Symbol, claim_ceiling::Symbol,
        authority::String, accepted::Bool, identity, evidence_refs::Tuple,
        metrics, remaining_gaps::Tuple)
    _fvlc_text(obligation_id, "obligation_id")
    _fvlc_text(requirement, "requirement")
    _fvlc_symbol(ledger_status, _FVLC_ALLOWED_LEDGER_STATUS, "ledger status")
    _fvlc_symbol(applicability, _FVLC_ALLOWED_APPLICABILITY, "applicability")
    _fvlc_symbol(provider_match, _FVLC_ALLOWED_PROVIDER_MATCH, "provider match")
    _fvlc_symbol(resolution, _FVLC_ALLOWED_RESOLUTION, "resolution")
    _fvlc_symbol(execution_classification, _FVLC_ALLOWED_EXECUTION,
        "execution classification")
    _fvlc_symbol(numerical_status, _FVLC_ALLOWED_STAGE, "numerical status")
    _fvlc_symbol(physical_status, _FVLC_ALLOWED_STAGE, "physical status")
    _fvlc_symbol(lifecycle, _FVLC_ALLOWED_LIFECYCLE, "lifecycle")
    claim_ceiling === _FVLC_CLAIM_CEILING ||
        throw(ArgumentError("ledger claim ceiling must be contract_only"))
    authority == _FVLC_AUTHORITY ||
        throw(ArgumentError("only FinalWholeDeviceAuthorityV4 is reserved authority"))
    accepted === false || throw(ArgumentError("contract-only obligation cannot be accepted"))
    identity isa FinalValidationLedgerIdentityV1 ||
        throw(ArgumentError("typed ledger identity required"))
    all(x -> x isa FinalValidationLedgerEvidenceRefV1, evidence_refs) ||
        throw(ArgumentError("typed ledger evidence refs required"))
    metrics isa FinalValidationLedgerMetricsV1 ||
        throw(ArgumentError("typed ledger metrics required"))
    all(x -> x isa String && !isempty(strip(x)) && isvalid(x), remaining_gaps) ||
        throw(ArgumentError("remaining gaps must be non-empty valid strings"))
    required isa Bool || throw(ArgumentError("required must be Bool"))
    nothing
end

function FinalValidationLedgerObligationV1(obligation_id, family, requirement;
        required=true, ledger_status=:pending, applicability=:required,
        provider_match=:unique_match, resolution=:resolved,
        execution_classification=:not_executed, numerical_status=:not_executed,
        physical_status=:not_applicable, lifecycle=:proposed,
        claim_ceiling=:contract_only, authority=_FVLC_AUTHORITY, accepted=false,
        identity=FinalValidationLedgerIdentityV1(), evidence_refs=(),
        metrics=FinalValidationLedgerMetricsV1(), remaining_gaps=())
    id = _fvlc_text(obligation_id, "obligation_id")
    fam = family isa Symbol ? family : Symbol(family)
    req = _fvlc_text(requirement, "requirement")
    ls = _fvlc_symbol(ledger_status, _FVLC_ALLOWED_LEDGER_STATUS, "ledger status")
    ap = _fvlc_symbol(applicability, _FVLC_ALLOWED_APPLICABILITY, "applicability")
    pm = _fvlc_symbol(provider_match, _FVLC_ALLOWED_PROVIDER_MATCH, "provider match")
    rs = _fvlc_symbol(resolution, _FVLC_ALLOWED_RESOLUTION, "resolution")
    ec = _fvlc_symbol(execution_classification, _FVLC_ALLOWED_EXECUTION, "execution classification")
    ns = _fvlc_symbol(numerical_status, _FVLC_ALLOWED_STAGE, "numerical status")
    ps = _fvlc_symbol(physical_status, _FVLC_ALLOWED_STAGE, "physical status")
    lc = _fvlc_symbol(lifecycle, _FVLC_ALLOWED_LIFECYCLE, "lifecycle")
    claim_ceiling === _FVLC_CLAIM_CEILING || throw(ArgumentError("ledger claim ceiling must be contract_only"))
    authority == _FVLC_AUTHORITY || throw(ArgumentError("only FinalWholeDeviceAuthorityV4 is reserved authority"))
    required isa Bool || throw(ArgumentError("required must be Bool"))
    accepted === false || throw(ArgumentError("contract-only obligation cannot be accepted"))
    identity isa FinalValidationLedgerIdentityV1 || throw(ArgumentError("typed ledger identity required"))
    refs = _fvlc_tuple(evidence_refs, "evidence_refs")
    all(x -> x isa FinalValidationLedgerEvidenceRefV1, refs) ||
        throw(ArgumentError("typed ledger evidence refs required"))
    metrics isa FinalValidationLedgerMetricsV1 || throw(ArgumentError("typed ledger metrics required"))
    gaps = Tuple(_fvlc_text(x, "remaining gap") for x in _fvlc_tuple(remaining_gaps, "remaining_gaps"))
    _fvlc_validate_obligation_parts(id, fam, req, required, ls, ap, pm, rs, ec, ns,
        ps, lc, claim_ceiling, String(authority), false, identity, refs, metrics, gaps)
    FinalValidationLedgerObligationV1(_FVLC_TOKEN, id, fam, req, Bool(required), ls,
        ap, pm, rs, ec, ns, ps, lc, claim_ceiling, String(authority),
        Bool(accepted), identity, refs, metrics, gaps)
end

semantic_view(x::FinalValidationLedgerObligationV1) = (
    obligation_id=x.obligation_id, family=x.family, requirement=x.requirement,
    required=x.required, ledger_status=x.ledger_status, applicability=x.applicability,
    provider_match=x.provider_match, resolution=x.resolution,
    execution_classification=x.execution_classification,
    numerical_status=x.numerical_status, physical_status=x.physical_status,
    lifecycle=x.lifecycle, claim_ceiling=x.claim_ceiling, authority=x.authority,
    accepted=x.accepted, identity=x.identity, evidence_refs=x.evidence_refs,
    metrics=x.metrics, remaining_gaps=x.remaining_gaps)

struct FinalValidationLedgerContractV1
    ledger_ref::String
    identity::FinalValidationLedgerIdentityV1
    protocol_hash::Union{Nothing,Digest256}
    obligations::Tuple
    authority::String
    authority_status::Symbol
    claim_ceiling::Symbol
    accepted::Bool
    publish::Symbol
    evidence_credit::Int
    ledger_hash::Digest256
    function FinalValidationLedgerContractV1(token::_FVLCConstructionToken,
            ledger_ref::String, identity::FinalValidationLedgerIdentityV1,
            protocol_hash::Union{Nothing,Digest256}, obligations::Tuple,
            authority::String, authority_status::Symbol, claim_ceiling::Symbol,
            accepted::Bool, publish::Symbol, evidence_credit::Int,
            ledger_hash::Digest256)
        _fvlc_require_token(token)
        _fvlc_validate_contract_parts(ledger_ref, identity, protocol_hash, obligations,
            authority, authority_status, claim_ceiling, accepted, publish,
            evidence_credit, ledger_hash)
        new(ledger_ref, identity, protocol_hash, obligations, authority,
            authority_status, claim_ceiling, accepted, publish, evidence_credit,
            ledger_hash)
    end
end

function _fvlc_validate_contract_parts(ledger_ref::String,
        identity, protocol_hash, obligations::Tuple, authority::String,
        authority_status::Symbol, claim_ceiling::Symbol, accepted::Bool,
        publish::Symbol, evidence_credit::Int, ledger_hash::Digest256)
    id = _fvlc_text(ledger_ref, "ledger_ref")
    identity isa FinalValidationLedgerIdentityV1 ||
        throw(ArgumentError("typed ledger identity required"))
    protocol_hash === nothing || protocol_hash isa Digest256 ||
        throw(ArgumentError("protocol_hash must be Digest256 or nothing"))
    all(x -> x isa FinalValidationLedgerObligationV1, obligations) ||
        throw(ArgumentError("typed ledger obligations required"))
    ids = Tuple(x.obligation_id for x in obligations)
    length(unique(ids)) == length(ids) || throw(_fvlc_input_error("duplicate obligation id"))
    length(ids) == length(_FVLC_REQUIRED_ALL_IDS) ||
        throw(_fvlc_input_error("R01-R10 plus 15 ENG obligations are required"))
    all(x -> x in _FVLC_REQUIRED_ALL_IDS, ids) ||
        throw(_fvlc_input_error("foreign obligation id"))
    all(x -> x in ids, _FVLC_REQUIRED_ALL_IDS) ||
        throw(_fvlc_input_error("missing required obligation id"))
    authority == _FVLC_AUTHORITY || throw(ArgumentError("reserved authority mismatch"))
    authority_status === :reserved_not_implemented ||
        throw(ArgumentError("final authority is not implemented by this contract"))
    claim_ceiling === _FVLC_CLAIM_CEILING ||
        throw(ArgumentError("ledger claim ceiling must be contract_only"))
    accepted === false || throw(ArgumentError("contract-only ledger cannot be accepted"))
    publish === _FVLC_PUBLISH || throw(ArgumentError("contract-only ledger is no_publish"))
    evidence_credit === 0 || throw(ArgumentError("contract-only ledger has zero evidence credit"))
    body = (revision=_FVLC_REVISION, ledger_ref=id, identity=identity,
        protocol_hash=protocol_hash, obligations=obligations,
        authority=String(authority), authority_status=authority_status,
        claim_ceiling=_FVLC_CLAIM_CEILING, accepted=false, publish=_FVLC_PUBLISH,
        evidence_credit=0)
    canonical_hash(body) == ledger_hash ||
        throw(ArgumentError("final validation ledger identity mismatch"))
    nothing
end

function FinalValidationLedgerContractV1(ledger_ref, identity, obligations;
        protocol_hash=nothing, authority=_FVLC_AUTHORITY,
        authority_status=:reserved_not_implemented,
        claim_ceiling=_FVLC_CLAIM_CEILING, accepted=false,
        publish=_FVLC_PUBLISH, evidence_credit=0)
    id = _fvlc_text(ledger_ref, "ledger_ref")
    identity isa FinalValidationLedgerIdentityV1 || throw(ArgumentError("typed ledger identity required"))
    rows = _fvlc_tuple(obligations, "obligations")
    all(x -> x isa FinalValidationLedgerObligationV1, rows) ||
        throw(ArgumentError("typed ledger obligations required"))
    ids = Tuple(x.obligation_id for x in rows)
    length(unique(ids)) == length(ids) || throw(_fvlc_input_error("duplicate obligation id"))
    length(ids) == length(_FVLC_REQUIRED_ALL_IDS) ||
        throw(_fvlc_input_error("R01-R10 plus 15 ENG obligations are required"))
    all(id -> id in _FVLC_REQUIRED_ALL_IDS, ids) ||
        throw(_fvlc_input_error("foreign obligation id"))
    all(id -> id in ids, _FVLC_REQUIRED_ALL_IDS) ||
        throw(_fvlc_input_error("missing required obligation id"))
    authority == _FVLC_AUTHORITY || throw(ArgumentError("reserved authority mismatch"))
    authority_status === :reserved_not_implemented ||
        throw(ArgumentError("final authority is not implemented by this contract"))
    claim_ceiling === _FVLC_CLAIM_CEILING ||
        throw(ArgumentError("ledger claim ceiling must be contract_only"))
    accepted === false || throw(ArgumentError("contract-only ledger cannot be accepted"))
    publish === _FVLC_PUBLISH || throw(ArgumentError("contract-only ledger is no_publish"))
    evidence_credit === 0 || throw(ArgumentError("contract-only ledger has zero evidence credit"))
    body = (revision=_FVLC_REVISION, ledger_ref=id, identity=identity,
        protocol_hash=_fvlc_digest(protocol_hash, "protocol_hash"), obligations=rows,
        authority=String(authority), authority_status=authority_status,
        claim_ceiling=claim_ceiling, accepted=false, publish=_FVLC_PUBLISH,
        evidence_credit=0)
    ledger_hash = canonical_hash(body)
    _fvlc_validate_contract_parts(body.ledger_ref, identity, body.protocol_hash, rows,
        body.authority, body.authority_status, body.claim_ceiling, false,
        body.publish, 0, ledger_hash)
    FinalValidationLedgerContractV1(_FVLC_TOKEN, body.ledger_ref, identity, body.protocol_hash,
        rows, body.authority, body.authority_status, body.claim_ceiling,
        false, body.publish, 0, ledger_hash)
end

semantic_view(x::FinalValidationLedgerContractV1) = (
    revision=_FVLC_REVISION, ledger_ref=x.ledger_ref, identity=x.identity,
    protocol_hash=x.protocol_hash, obligations=x.obligations, authority=x.authority,
    authority_status=x.authority_status, claim_ceiling=x.claim_ceiling,
    accepted=x.accepted, publish=x.publish, evidence_credit=x.evidence_credit)

canonical_hash(x::FinalValidationLedgerContractV1) = begin
    expected = canonical_hash(semantic_view(x))
    expected == x.ledger_hash || throw(ArgumentError("final validation ledger identity mismatch"))
    expected
end

struct FinalValidationLedgerDecisionV1
    status::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    publish::Symbol
    evidence_credit::Int
    authority::String
    ledger_hash::Digest256
    reasons::Tuple
    decision_hash::Digest256
    function FinalValidationLedgerDecisionV1(token::_FVLCConstructionToken,
            status::Symbol, accepted::Bool, claim_ceiling::Symbol, publish::Symbol,
            evidence_credit::Int, authority::String, ledger_hash::Digest256,
            reasons::Tuple, decision_hash::Digest256)
        _fvlc_require_token(token)
        _fvlc_validate_decision_parts(status, accepted, claim_ceiling, publish,
            evidence_credit, authority, ledger_hash, reasons, decision_hash)
        new(status, accepted, claim_ceiling, publish, evidence_credit, authority,
            ledger_hash, reasons, decision_hash)
    end
end

function _fvlc_validate_decision_parts(status::Symbol, accepted::Bool,
        claim_ceiling::Symbol, publish::Symbol, evidence_credit::Int,
        authority::String, ledger_hash::Digest256, reasons::Tuple,
        decision_hash::Digest256)
    _fvlc_symbol(status, _FVLC_ALLOWED_DECISION, "ledger decision")
    accepted === false || throw(ArgumentError("contract-only decision cannot be accepted"))
    claim_ceiling === _FVLC_CLAIM_CEILING ||
        throw(ArgumentError("ledger decision claim ceiling must be contract_only"))
    publish === _FVLC_PUBLISH || throw(ArgumentError("ledger decision is no_publish"))
    evidence_credit === 0 || throw(ArgumentError("ledger decision has zero evidence credit"))
    authority == _FVLC_AUTHORITY || throw(ArgumentError("decision authority mismatch"))
    all(x -> x isa String && !isempty(strip(x)) && isvalid(x), reasons) ||
        throw(ArgumentError("decision reasons must be non-empty valid strings"))
    body = (revision=_FVLC_REVISION, status=status, accepted=false,
        claim_ceiling=_FVLC_CLAIM_CEILING, publish=_FVLC_PUBLISH,
        evidence_credit=0, authority=_FVLC_AUTHORITY, ledger_hash=ledger_hash,
        reasons=reasons)
    canonical_hash(body) == decision_hash ||
        throw(ArgumentError("ledger decision identity mismatch"))
    nothing
end

function _fvlc_decision(status, ledger_hash, reasons)
    _fvlc_symbol(status, _FVLC_ALLOWED_DECISION, "ledger decision")
    rs = Tuple(String(x) for x in reasons)
    body = (revision=_FVLC_REVISION, status=status, accepted=false,
        claim_ceiling=_FVLC_CLAIM_CEILING, publish=_FVLC_PUBLISH,
        evidence_credit=0, authority=_FVLC_AUTHORITY, ledger_hash=ledger_hash,
        reasons=rs)
    FinalValidationLedgerDecisionV1(_FVLC_TOKEN, status, false, _FVLC_CLAIM_CEILING,
        _FVLC_PUBLISH, 0, _FVLC_AUTHORITY, ledger_hash, rs, canonical_hash(body))
end

semantic_view(x::FinalValidationLedgerDecisionV1) = (
    revision=_FVLC_REVISION, status=x.status, accepted=x.accepted,
    claim_ceiling=x.claim_ceiling, publish=x.publish,
    evidence_credit=x.evidence_credit, authority=x.authority,
    ledger_hash=x.ledger_hash, reasons=x.reasons)

canonical_hash(x::FinalValidationLedgerDecisionV1) = begin
    expected = canonical_hash(semantic_view(x))
    expected == x.decision_hash || throw(ArgumentError("ledger decision identity mismatch"))
    expected
end

_fvlc_identity_missing(x::FinalValidationLedgerIdentityV1) =
    x.candidate_ref === nothing || x.genome_bundle_hash === nothing ||
    x.mission_hash === nothing || x.mechanism_hash === nothing ||
    x.field_geometry_hash === nothing || x.realization_control_hash === nothing ||
    x.physical_subject_hash === nothing || x.solver_input_hash === nothing ||
    x.scenario_manifest_hash === nothing || x.provider_ref === nothing ||
    x.provider_hash === nothing || x.toolchain_ref === nothing ||
    x.toolchain_hash === nothing || x.source_tree_ref === nothing ||
    x.source_tree_hash === nothing || x.build_ref === nothing ||
    x.build_hash === nothing || x.channel_ref === nothing ||
    x.channel_hash === nothing || x.interpreter_ref === nothing ||
    x.interpreter_hash === nothing || x.module_ref === nothing ||
    x.module_hash === nothing

_fvlc_same_identity(a, b) = semantic_view(a) == semantic_view(b)

function _fvlc_has_applicability_proof(row::FinalValidationLedgerObligationV1)
    any(x -> x.kind === :applicability_proof && x.status === :pass,
        row.evidence_refs)
end

"""Evidence is admissible only when all four ledger binding axes agree."""
function _fvlc_evidence_binding_matches(evidence::FinalValidationLedgerEvidenceRefV1,
        identity::FinalValidationLedgerIdentityV1)
    evidence.candidate_ref == identity.candidate_ref &&
        evidence.physical_subject_hash == identity.physical_subject_hash &&
        evidence.solver_input_hash == identity.solver_input_hash &&
        evidence.scenario_ref == string(identity.scenario_manifest_hash)
end

function validate_final_validation_ledger(ledger::FinalValidationLedgerContractV1)
    ledger_hash = canonical_hash(ledger)
    fail_closed = String[]
    provider_gap = String[]
    deferred = String[]
    program = String[]
    numerical = String[]
    physical = String[]
    unknown = String[]
    for row in ledger.obligations
        row.required === true || push!(fail_closed, "$(row.obligation_id):required_false")
        if !_fvlc_identity_missing(ledger.identity) && !_fvlc_identity_missing(row.identity) &&
                !_fvlc_same_identity(ledger.identity, row.identity)
            push!(fail_closed, "$(row.obligation_id):identity_mismatch")
        elseif _fvlc_identity_missing(ledger.identity) || _fvlc_identity_missing(row.identity)
            push!(deferred, "$(row.obligation_id):identity_pending")
        end
        row.accepted && push!(fail_closed, "$(row.obligation_id):premature_acceptance")
        row.claim_ceiling === _FVLC_CLAIM_CEILING ||
            push!(fail_closed, "$(row.obligation_id):claim_ceiling_escape")
        row.authority == _FVLC_AUTHORITY || push!(fail_closed, "$(row.obligation_id):authority_mismatch")
        if row.applicability === :not_applicable && !_fvlc_has_applicability_proof(row)
            push!(deferred, "$(row.obligation_id):not_applicable_without_proof")
        end
        row.provider_match === :unique_match || push!(provider_gap, "$(row.obligation_id):provider_match_gap")
        row.resolution === :resolved || push!(provider_gap, "$(row.obligation_id):resolution_deferred")
        row.lifecycle === :proposed && push!(deferred, "$(row.obligation_id):lifecycle_not_executed")
        row.execution_classification === :program_exception &&
            push!(program, "$(row.obligation_id):program_exception")
        row.execution_classification === :human_interruption &&
            push!(program, "$(row.obligation_id):human_interruption")
        row.execution_classification === :not_executed &&
            push!(deferred, "$(row.obligation_id):not_executed")
        row.execution_classification === :unknown && push!(unknown, "$(row.obligation_id):execution_unknown")
        row.numerical_status === :numerical_fail && push!(numerical, "$(row.obligation_id):numerical_fail")
        row.physical_status === :physical_fail && push!(physical, "$(row.obligation_id):physical_fail")
        row.numerical_status === :unknown && push!(unknown, "$(row.obligation_id):numerical_unknown")
        row.physical_status === :unknown && push!(unknown, "$(row.obligation_id):physical_unknown")
        row.ledger_status === :pending && push!(deferred, "$(row.obligation_id):ledger_pending")
        if isempty(row.evidence_refs)
            evidence_unknown = row.execution_classification === :process_completed &&
                row.ledger_status !== :pending && !_fvlc_identity_missing(ledger.identity) &&
                !_fvlc_identity_missing(row.identity)
            evidence_unknown ?
                push!(unknown, "$(row.obligation_id):terminal_artifact_missing") :
                push!(deferred, "$(row.obligation_id):evidence_missing")
        end
        haskey(row.metrics.vvuq, :calibration_heldout_disjoint) &&
            row.metrics.vvuq.calibration_heldout_disjoint === false &&
            push!(fail_closed, "$(row.obligation_id):calibration_reused_as_held_out")
        haskey(row.metrics.replay, :historical_receipt_as_fresh) &&
            row.metrics.replay.historical_receipt_as_fresh === true &&
            push!(deferred, "$(row.obligation_id):historical_receipt_as_fresh")
        haskey(row.metrics.replay, :terminal_artifact) &&
            row.metrics.replay.terminal_artifact === false &&
            push!(unknown, "$(row.obligation_id):terminal_artifact_missing")
        haskey(row.metrics.engineering, :required_scenarios_complete) &&
            row.metrics.engineering.required_scenarios_complete === false &&
            push!(deferred, "$(row.obligation_id):missing_required_scenario")
        haskey(row.metrics.net_output, :interval_crosses_zero) &&
            row.metrics.net_output.interval_crosses_zero === true &&
            push!(unknown, "$(row.obligation_id):net_output_interval_crosses_zero")
        for evidence in row.evidence_refs
            !_fvlc_identity_missing(ledger.identity) &&
                !_fvlc_evidence_binding_matches(evidence, ledger.identity) &&
                push!(fail_closed, "$(row.obligation_id):evidence_binding_mismatch")
            evidence.content_hash === nothing && push!(deferred, "$(row.obligation_id):evidence_hash_missing")
            evidence.status === :unknown && push!(unknown, "$(row.obligation_id):evidence_unknown")
            evidence.status === :terminal_deferred && push!(deferred, "$(row.obligation_id):evidence_deferred")
        end
    end
    !isempty(fail_closed) && return _fvlc_decision(:fail_closed, ledger_hash, fail_closed)
    !isempty(provider_gap) && return _fvlc_decision(:terminal_deferred, ledger_hash, provider_gap)
    !isempty(program) && return _fvlc_decision(:unknown, ledger_hash, program)
    !isempty(numerical) && return _fvlc_decision(:numerical_fail, ledger_hash, numerical)
    !isempty(physical) && return _fvlc_decision(:physical_fail, ledger_hash, physical)
    !isempty(unknown) && return _fvlc_decision(:unknown, ledger_hash, unknown)
    !isempty(deferred) && return _fvlc_decision(:terminal_deferred, ledger_hash, deferred)
    _fvlc_decision(:contract_only, ledger_hash,
        ("ledger contract structurally admitted; FinalWholeDeviceAuthorityV4 is not implemented",
         "no_publish", "evidence_credit_zero"))
end

"""Admit only the typed ledger factory and normalize its sealed input failures."""
function admit_final_validation_ledger(builder::Function)
    ledger = try
        builder()
    catch error
        error isa _FinalValidationLedgerInputError || rethrow()
        detail = sprint(showerror, error)
        return _fvlc_decision(:fail_closed,
            digest256_text("invalid-final-validation-ledger:" * detail),
            ("ledger_factory_fail_closed", detail))
    end
    ledger isa FinalValidationLedgerContractV1 ||
        return _fvlc_decision(:fail_closed,
            digest256_text("invalid-final-validation-ledger:wrong-type"),
            ("ledger_type_mismatch",))
    validate_final_validation_ledger(ledger)
end

const validate_final_validation_ledger_v1 = validate_final_validation_ledger
