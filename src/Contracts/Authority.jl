"""Capability-separated authority. Only the final authority can mint terminal claims."""

struct IntermediateAuthorityV4
    name::Symbol
end

struct FinalWholeDeviceAuthorityV4
    name::Symbol
end

struct AuthorityToken
    subject_hash::String
    issuer::FinalWholeDeviceAuthorityV4
    seal::UInt64
    function AuthorityToken(subject_hash::String, issuer::FinalWholeDeviceAuthorityV4, seal::UInt64)
        seal == UInt64(0x465556344154484f) || throw(ArgumentError("AuthorityToken cannot be constructed directly"))
        new(subject_hash, issuer, seal)
    end
end

struct TerminalDecisionV4
    subject_hash::String
    disposition::TerminalDisposition
    authority::FinalWholeDeviceAuthorityV4
end

function issue_authority_token(authority::FinalWholeDeviceAuthorityV4, subject_hash::AbstractString)
    isempty(subject_hash) && throw(ArgumentError("terminal authority requires a physical subject hash"))
    AuthorityToken(String(subject_hash), authority, UInt64(0x465556344154484f))
end

function issue_authority_token(::IntermediateAuthorityV4, ::AbstractString)
    throw(ArgumentError("intermediate authority cannot issue a terminal AuthorityToken"))
end

function emit_terminal(token::AuthorityToken, disposition::TerminalDisposition)
    TerminalDecisionV4(token.subject_hash, disposition, token.issuer)
end

function emit_terminal(::IntermediateAuthorityV4, ::TerminalDisposition)
    throw(ArgumentError("intermediate authority cannot emit terminal dispositions"))
end
