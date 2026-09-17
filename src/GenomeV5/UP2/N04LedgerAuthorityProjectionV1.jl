"""Contract-only N04 ledger projection from an actual CandidateStatePackageV5.

The projection reuses the local G3 account/entry/closure checks.  It does not
invent an owner-uniqueness rule or claim that a G1 ledger occurrence is mapped
to a G3 account: that cross-layer authority remains an explicit gap.
"""

abstract type N04TypedValueV1 end
struct N04TextValueV1 <: N04TypedValueV1; value::String; end
struct N04StringTupleValueV1 <: N04TypedValueV1; value::Tuple{Vararg{String}}; end
struct N04RationalValueV1 <: N04TypedValueV1; value::Rational{Int64}; end

struct N04LedgerFieldV1
    id::String
    field_path::String
    source_locator::String
    source_type::Symbol
    value::N04TypedValueV1
end

struct N04LedgerProjectionV1
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    g1_ref::Any
    g3_ref::GenomeContractRef
    g1_schema_hash::Digest256
    g3_schema_hash::Digest256
    g1_occurrences::Tuple{Vararg{G1LedgerOccurrenceV2}}
    network::G3ResourceNetworkV2
    authority_gaps::Tuple{Vararg{String}}
    fields::Tuple{Vararg{N04LedgerFieldV1}}
    projection_hash::Digest256
end

struct N04MutationSpecV1
    id::String
    class_id::Symbol
    field_path::String
    source_locator::String
    source_type::Symbol
    mutation_kind::Symbol
    expected_error::Symbol
end

struct N04InvocationCounterV1
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
end
N04InvocationCounterV1() = N04InvocationCounterV1(0, 0, 0)

struct N04ValidationResultV1
    mutation_id::String
    input_hash::Digest256
    mutated_input_hash::Digest256
    status::Symbol
    error_code::Symbol
    error_path::String
    detail::String
    gap::Union{Nothing,String}
    original_value::N04TypedValueV1
    mutated_value::N04TypedValueV1
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
    result_hash::Digest256
end

semantic_view(x::N04TextValueV1) = (kind=:text, value=x.value)
semantic_view(x::N04StringTupleValueV1) = (kind=:string_tuple, value=x.value)
semantic_view(x::N04RationalValueV1) = (kind=:rational, value=x.value)
semantic_view(x::N04LedgerFieldV1) = (id=x.id, field_path=x.field_path,
    source_locator=x.source_locator, source_type=x.source_type, value=x.value)
semantic_view(x::N04LedgerProjectionV1) =
    (candidate_ref=x.candidate_ref, package_hash=x.package_hash,
     g1_ref=x.g1_ref, g3_ref=x.g3_ref, g1_schema_hash=x.g1_schema_hash,
     g3_schema_hash=x.g3_schema_hash, g1_occurrences=x.g1_occurrences,
     network=x.network, authority_gaps=x.authority_gaps, fields=x.fields)
semantic_view(x::N04MutationSpecV1) =
    (id=x.id, class_id=x.class_id, field_path=x.field_path,
     source_locator=x.source_locator, source_type=x.source_type,
     mutation_kind=x.mutation_kind, expected_error=x.expected_error)

_n04_field(p::N04LedgerProjectionV1, id::AbstractString) =
    first(x for x in p.fields if x.id == String(id))

function n04_projection_from_a(package::CandidateStatePackageV5)
    package.structural_status == :valid ||
        throw(ArgumentError("N04 requires a structurally valid A package"))
    package.candidate_ref.version == "v5" ||
        throw(ArgumentError("N04 requires a v5 candidate ref"))
    package.g3 isa RealizationControlGenomeV5 ||
        throw(ArgumentError("N04 requires the actual G3 realization/control package"))
    package.g3.realization.network isa G3ResourceNetworkV2 ||
        throw(ArgumentError("N04 requires the actual G3 resource network"))
    package.g3.contract_binding.candidate_ref == package.candidate_ref ||
        throw(ArgumentError("N04 G3 candidate binding mismatch"))
    package.component_identity.g3_genome_hash == package.g3.candidate_hash ||
        throw(ArgumentError("N04 G3 component hash is not package-bound"))
    package.component_identity.g1_genome_hash == package.g1.candidate_hash ||
        throw(ArgumentError("N04 G1 component hash is not package-bound"))

    network = package.g3.realization.network
    equations = package.g1.payload.equation_plan.equations
    occurrences = Tuple(o for equation in equations for o in equation.occurrences)
    gaps = String[]
    # A coincident string is insufficient authority: no versioned exact join
    # from a G1 occurrence to a G3 account/energy boundary exists here.
    push!(gaps, "g1_occurrence_to_g3_account_exact_join_missing")
    push!(gaps, "owner_uniqueness_scope_missing_shared_owner_is_legal")

    a0 = network.accounts[1]
    c0 = network.closures[1]
    e0 = network.entries[1]
    e1 = network.entries[2]
    fields = (
        N04LedgerFieldV1("N04-01", "/g3/realization/network/accounts/0/owner",
            "G3LedgerAccountV2.owner::String", :text, N04TextValueV1(a0.owner)),
        N04LedgerFieldV1("N04-02", "/g3/realization/network/closures/0/account_ids",
            "G3LedgerClosureV2.account_ids::Tuple[String]", :tuple,
            N04StringTupleValueV1(c0.account_ids)),
        N04LedgerFieldV1("N04-03", "/g3/realization/network/entries/0/account_id",
            "G3LedgerEntryV2.account_id::String", :text, N04TextValueV1(e0.account_id)),
        N04LedgerFieldV1("N04-04", "/g3/realization/network/entries/0/component_id",
            "G3LedgerEntryV2.component_id::String", :text, N04TextValueV1(e0.component_id)),
        N04LedgerFieldV1("N04-05", "/g3/realization/network/entries/1/coefficient",
            "G3LedgerEntryV2.coefficient::Rational{Int64}", :rational,
            N04RationalValueV1(e1.coefficient)))
    g1_ref = package.g1.contract_ref
    g3_ref = package.g3.contract_binding.contract_ref
    N04LedgerProjectionV1(package.candidate_ref, package.candidate_hash,
        g1_ref, g3_ref, g1_ref.schema_hash, g3_ref.schema_hash, occurrences,
        network, Tuple(unique(gaps)), fields,
        canonical_hash((candidate_ref=package.candidate_ref,
            package_hash=package.candidate_hash, g1_ref=g1_ref, g3_ref=g3_ref,
            g1_schema_hash=g1_ref.schema_hash, g3_schema_hash=g3_ref.schema_hash,
            g1_occurrences=occurrences, network=network,
            authority_gaps=Tuple(unique(gaps)), fields=fields)))
end

function _n04_copy(p::N04LedgerProjectionV1, id::AbstractString,
        value::N04TypedValueV1)
    fields = Tuple(x.id == String(id) ? N04LedgerFieldV1(x.id, x.field_path,
        x.source_locator, x.source_type, value) : x for x in p.fields)
    N04LedgerProjectionV1(p.candidate_ref, p.package_hash, p.g1_ref, p.g3_ref,
        p.g1_schema_hash, p.g3_schema_hash, p.g1_occurrences, p.network,
        p.authority_gaps, fields,
        canonical_hash((candidate_ref=p.candidate_ref, package_hash=p.package_hash,
            g1_ref=p.g1_ref, g3_ref=p.g3_ref, g1_schema_hash=p.g1_schema_hash,
            g3_schema_hash=p.g3_schema_hash, g1_occurrences=p.g1_occurrences,
            network=p.network, authority_gaps=p.authority_gaps, fields=fields)))
end

function _n04_mutate(p::N04LedgerProjectionV1, spec::N04MutationSpecV1)
    if spec.mutation_kind === :shared_owner
        owner = p.network.accounts[1].owner
        other_index = findfirst(a -> a.owner != owner, p.network.accounts)
        other_index === nothing && throw(ArgumentError("N04 shared-owner mutation lacks a distinct actual owner"))
        other = p.network.accounts[other_index].owner
        return _n04_copy(p, spec.id, N04TextValueV1(other))
    end
    spec.mutation_kind === :duplicate_account_ids &&
        return _n04_copy(p, spec.id, N04StringTupleValueV1((p.network.closures[1].account_ids[1],
            p.network.closures[1].account_ids[1])))
    spec.mutation_kind === :wrong_account_ref &&
        return _n04_copy(p, spec.id, N04TextValueV1(p.network.accounts[2].account_id))
    spec.mutation_kind === :passive_component_ref &&
        return _n04_copy(p, spec.id, N04TextValueV1(first(c.component_id for c in p.network.components if c.passive)))
    if spec.mutation_kind === :capacity_exceeded
        entry = p.network.entries[2]
        component = first(c for c in p.network.components if c.component_id == entry.component_id)
        target = component.capacity + (1 // 1)
        target == entry.coefficient && (target += (1 // 1))
        return _n04_copy(p, spec.id, N04RationalValueV1(target))
    end
    throw(ArgumentError("unknown N04 mutation $(spec.id)"))
end

function _n04_classify(p::N04LedgerProjectionV1, q::N04LedgerProjectionV1,
        spec::N04MutationSpecV1)
    v = _n04_field(q, spec.id).value
    spec.id === "N04-01" &&
        return (:terminal_deferred, :terminal_deferred,
            "owner_uniqueness_scope_missing_shared_owner_is_legal")
    if spec.id === "N04-02"
        v isa N04StringTupleValueV1 && !isempty(v.value) &&
            length(unique(v.value)) == length(v.value) &&
            all(x -> x in (a.account_id for a in p.network.accounts), v.value) && return nothing
        return (:fail_closed, :invalid_closure, "duplicate_or_unresolved_closure_account")
    elseif spec.id === "N04-03"
        e = p.network.entries[1]
        v isa N04TextValueV1 && any(a -> a.account_id == v.value, p.network.accounts) ||
            return (:fail_closed, :invalid_closure, "entry_account_ref_missing")
        port = first(x for x in p.network.resource_ports if x.port_id == e.port_id)
        v.value == port.account_id && return nothing
        return (:fail_closed, :invalid_closure, "entry_port_account_mismatch")
    elseif spec.id === "N04-04"
        e = p.network.entries[1]
        v isa N04TextValueV1 && any(c -> c.component_id == v.value, p.network.components) ||
            return (:fail_closed, :invalid_closure, "entry_component_ref_missing")
        component = first(c for c in p.network.components if c.component_id == v.value)
        e.effect === :source && component.passive &&
            return (:fail_closed, :invalid_closure, "passive_component_cannot_source")
        return nothing
    elseif spec.id === "N04-05"
        e = p.network.entries[2]
        port = first(x for x in p.network.resource_ports if x.port_id == e.port_id)
        component = first(c for c in p.network.components if c.component_id == e.component_id)
        v isa N04RationalValueV1 && v.value != 0 // 1 ||
            return (:fail_closed, :invalid_closure, "zero_ledger_coefficient")
        port.kind !== :effort && abs(v.value) > component.capacity &&
            return (:fail_closed, :invalid_closure, "component_capacity_exceeded")
        return nothing
    end
    nothing
end

function n04_validate_mutation(p::N04LedgerProjectionV1,
        spec::N04MutationSpecV1; counter=N04InvocationCounterV1())
    field = _n04_field(p, spec.id)
    field.field_path == spec.field_path && field.source_locator == spec.source_locator &&
        field.source_type == spec.source_type ||
        throw(ArgumentError("N04 mutation metadata does not bind to actual field"))
    q = _n04_mutate(p, spec)
    classified = _n04_classify(p, q, spec)
    classified === nothing && throw(ArgumentError("N04 mutation did not violate its local invariant"))
    status, code, detail = classified
    gap = status === :terminal_deferred ? "owner_uniqueness_scope_missing_shared_owner_is_legal" : nothing
    result_hash = canonical_hash((mutation_id=spec.id, input_hash=p.projection_hash,
        mutated_input_hash=q.projection_hash, status=status, error_code=code,
        error_path=spec.field_path, detail=detail, gap=gap,
        compile_calls=counter.compile_calls, provider_calls=counter.provider_calls,
        solver_calls=counter.solver_calls, scope=:schema_validation_only))
    N04ValidationResultV1(spec.id, p.projection_hash, q.projection_hash, status,
        code, spec.field_path, detail, gap, field.value,
        _n04_field(q, spec.id).value, counter.compile_calls,
        counter.provider_calls, counter.solver_calls, result_hash)
end
