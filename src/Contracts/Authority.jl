"""Closed final authority: terminal claims require a complete closure audit."""

struct IntermediateAuthorityV4
    name::Symbol
end
semantic_view(x::IntermediateAuthorityV4) = (authority=x.name,)

struct _AuthorityCredential end
const _CREDENTIAL = _AuthorityCredential()

struct FinalWholeDeviceAuthorityV4
    name::Symbol
    function FinalWholeDeviceAuthorityV4(:: _AuthorityCredential, name::Symbol)
        new(name)
    end
end

struct AuthorityToken
    subject_hash::String
    issuer::FinalWholeDeviceAuthorityV4
    function AuthorityToken(:: _AuthorityCredential, subject_hash::String, issuer::FinalWholeDeviceAuthorityV4)
        new(subject_hash, issuer)
    end
end
semantic_view(x::AuthorityToken) = (subject_hash=x.subject_hash, issuer=x.issuer)

struct TerminalDecisionV4
    subject_hash::String
    disposition::TerminalDisposition
    authority::FinalWholeDeviceAuthorityV4
    function TerminalDecisionV4(:: _AuthorityCredential, subject_hash::String, disposition::TerminalDisposition,
                                authority::FinalWholeDeviceAuthorityV4)
        new(subject_hash, disposition, authority)
    end
end

struct FinalClosureInputV4
    required_obligations::Tuple{Vararg{Symbol}}
    satisfied_obligations::Tuple{Vararg{Symbol}}
    hard_gates::Tuple{Vararg{Bool}}
    scenarios::Tuple{Vararg{String}}
    covered_scenarios::Tuple{Vararg{String}}
    vvuq_checks::Tuple{Vararg{Bool}}
    deferred::Tuple{Vararg{String}}
    function FinalClosureInputV4(required, satisfied, gates, scenarios, covered, vvuq, deferred=())
        all(x -> x isa Symbol, required) && all(x -> x isa Symbol, satisfied) || throw(ArgumentError("obligations must be symbols"))
        all(x -> x isa Bool, gates) || throw(ArgumentError("hard gates must be booleans"))
        all(x -> x isa AbstractString, scenarios) && all(x -> x isa AbstractString, covered) || throw(ArgumentError("scenarios must be strings"))
        all(x -> x isa Bool, vvuq) && all(x -> x isa AbstractString, deferred) || throw(ArgumentError("invalid VVUQ/deferred structure"))
        new(Tuple(required), Tuple(satisfied), Tuple(gates), Tuple(String(x) for x in scenarios),
            Tuple(String(x) for x in covered), Tuple(vvuq), Tuple(String(x) for x in deferred))
    end
end
semantic_view(x::FinalClosureInputV4) = (required_obligations=x.required_obligations, satisfied_obligations=x.satisfied_obligations,
    hard_gates=x.hard_gates, scenarios=x.scenarios, covered_scenarios=x.covered_scenarios, vvuq_checks=x.vvuq_checks, deferred=x.deferred)

function _closure_complete(c::FinalClosureInputV4)
    isempty(c.required_obligations) || Set(c.required_obligations) == Set(c.satisfied_obligations) || return false
    all(c.hard_gates) || return false
    isempty(c.scenarios) || Set(c.scenarios) == Set(c.covered_scenarios) || return false
    isempty(c.vvuq_checks) || all(c.vvuq_checks) || return false
    isempty(c.deferred)
end

"""Only this validated path creates an authority token and terminal decision."""
function final_closure(subject_hash::AbstractString, c::FinalClosureInputV4, disposition::TerminalDisposition)
    isempty(subject_hash) && throw(ArgumentError("subject hash cannot be empty"))
    _closure_complete(c) || throw(ArgumentError("terminal_deferred: final closure has missing obligations, gates, scenarios, VVUQ, or deferred work"))
    authority = FinalWholeDeviceAuthorityV4(_CREDENTIAL, :final_whole_device)
    token = AuthorityToken(_CREDENTIAL, String(subject_hash), authority)
    TerminalDecisionV4(_CREDENTIAL, token.subject_hash, disposition, token.issuer)
end

function final_closure(::AbstractString, ::FinalClosureInputV4, ::Nothing)
    throw(ArgumentError("terminal disposition must be a typed TerminalDisposition"))
end

semantic_view(x::FinalWholeDeviceAuthorityV4) = (authority=:final_whole_device,)
semantic_view(x::TerminalDecisionV4) = (subject_hash=x.subject_hash, disposition=x.disposition, authority=x.authority)
