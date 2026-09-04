"""Typed, closed scopes for conservation invariants."""

abstract type ConservationInvariantScopeV1 end

struct GlobalConservationScopeV1 <: ConservationInvariantScopeV1
    function GlobalConservationScopeV1()
        new()
    end
    function GlobalConservationScopeV1(args...)
        throw(ArgumentError("global conservation scope is nullary"))
    end
end

struct DomainConservationScopeV1 <: ConservationInvariantScopeV1
    state_refs::Tuple{Vararg{StateGeneRefV1}}
    function DomainConservationScopeV1(state_refs::Any)
        state_refs isa Tuple || throw(ArgumentError("domain state_refs must be an immutable tuple"))
        isempty(state_refs) && throw(ArgumentError("domain conservation scope cannot be empty"))
        all(typeof(ref) === StateGeneRefV1 for ref in state_refs) ||
            throw(ArgumentError("domain state_refs must contain exactly StateGeneRefV1"))
        ids = String[getfield(ref, :value) for ref in state_refs]
        length(unique(ids)) == length(ids) || throw(ArgumentError("domain state_refs must be unique"))
        ordered = sort!(collect(state_refs), by=ref -> getfield(ref, :value))
        new(Tuple(ordered))
    end
    function DomainConservationScopeV1(args...)
        throw(ArgumentError("domain conservation scope requires exactly one tuple"))
    end
end

struct InterfaceConservationScopeV1 <: ConservationInvariantScopeV1
    operator_site_ref::OperatorSiteRefV1
    function InterfaceConservationScopeV1(operator_site_ref::Any)
        typeof(operator_site_ref) === OperatorSiteRefV1 ||
            throw(ArgumentError("interface operator_site_ref must be exactly OperatorSiteRefV1"))
        new(operator_site_ref)
    end
    function InterfaceConservationScopeV1(args...)
        throw(ArgumentError("interface conservation scope requires exactly one operator-site reference"))
    end
end

semantic_view(::GlobalConservationScopeV1) = NamedTuple()
semantic_view(x::DomainConservationScopeV1) =
    (state_refs=getfield(x, :state_refs),)
semantic_view(x::InterfaceConservationScopeV1) =
    (operator_site_ref=getfield(x, :operator_site_ref),)
