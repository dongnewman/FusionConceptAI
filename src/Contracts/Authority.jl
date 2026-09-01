"""P0 authority protocol only. Final closure authority is intentionally a P5 artifact."""

abstract type AuthorityProtocolV4 end

struct IntermediateAuthorityProtocolV4 <: AuthorityProtocolV4
    scope::Symbol
end

"""No terminal authority, token, decision, or disposition factory exists in P0."""
semantic_view(x::IntermediateAuthorityProtocolV4) = (scope=x.scope,)
