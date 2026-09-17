"""Candidate-owned N06 source/field/return/heat/ledger mapping.

This is a contract projection only.  It consumes an actual A package and the
source-validated E0 bound input.  A local G3 balance is deliberately not used
as evidence of a G1-to-G3 conservation law.
"""

const _N06_SCHEMA_SOURCE_V1 = """
schema_id=GenomeV5/UP2/N06SourceFieldLedgerMappingV1
version=v1
fields=candidate_ref,package_hash,e0_bound_input_hash,projection_g1_equation_occurrence_closure,
projection_g2_region_boundary,selected_g3_flow_link,role_bindings(source|field|return|heat),
g1_locator,g2_locator,g3_locator,power_effort_flow_partner,energy_boundary,owner_scope,owner_account_ids,
dimensioned_conversion(dimension_rule,law_content_hash),provenance,content_hash
constraints=actual CandidateStatePackageV5; exact candidate/ref/hash/axis join;
source_field_return_heat_ledger_owner_scope is authored and candidate-owned;
missing mapping=terminal_deferred; typed contradiction=fail_closed;
unexpected exception=program_exception; compile/provider/solver=0
"""
const _N06_SELECTOR_SOURCE_V1 = """
g1_selector_roles=source(energy,governing-0,output,1);field(energy,source-0,output,1);
return(constraint,constraint-0,output,1);heat(constraint,constraint-0,output,2)
g2_selector=interface.left_region;boundary_face=x_min
selector_resolution=exact typed key; duplicate or absent source=fail_closed
"""
const _N06_CANONICAL_SOURCE_V1 = """
canonicalization_id=GenomeV5/UP2/n06-source-field-ledger/canonicalization/v1
encoding=UTF-8; line_endings=LF; tuples=declared order; refs=exact semantic fields
identity=candidate_ref,package_hash,e0_bound_input_hash,joins,conversions,provenance
digest=SHA-256 of canonical semantic value
"""
const _N06_PROFILE_SOURCE_V1 = """
profile_id=GenomeV5/UP2/n06-source-field-ledger/applicability/v1
scope=contract_ready projection only; no compiler/provider/mesh/engineering/physical credit
missing_authority=terminal_deferred; contradictory typed values=fail_closed
shared_owner=legal when account scopes are distinct; owner string equality is not double-count
"""
const _N06_CONVERSION_LAW_SOURCE_V1 = """
law_version=v1
same_dimension=from_unit.exponents==to_unit.exponents
time_derivative=to_unit.exponents==from_unit.exponents-time
power_from_effort_flow=requires_typed_effort_and_flow_sources
derived_offset=zero
"""

# These are authored selectors, rather than positional guesses.  Every
# selector is a complete G1 occurrence key; the actual package must contain
# exactly one matching typed occurrence before a projection can be made.
const _N06_G1_ROLE_SELECTORS = Dict(
    :source => (ledger_id="energy", equation_id="governing-0", port_side=:output, port_index=1),
    :field => (ledger_id="energy", equation_id="source-0", port_side=:output, port_index=1),
    :return => (ledger_id="constraint", equation_id="constraint-0", port_side=:output, port_index=1),
    :heat => (ledger_id="constraint", equation_id="constraint-0", port_side=:output, port_index=2))
const _N06_G2_SELECTOR = (interface_side=:left, boundary_face=:x_min)

_n06_selector_key(selector) = (ledger_id=String(selector.ledger_id),
    equation_id=String(selector.equation_id), port_side=Symbol(selector.port_side),
    port_index=Int(selector.port_index))

_n06_conversion_law_hash(rule::Symbol) =
    digest256_text(_N06_CONVERSION_LAW_SOURCE_V1 * "rule=$(rule)")

n06_schema_hash() = digest256_text(_N06_SCHEMA_SOURCE_V1 * _N06_SELECTOR_SOURCE_V1)
n06_canonicalization_hash() = digest256_text(_N06_CANONICAL_SOURCE_V1)
n06_profile_hash() = digest256_text(_N06_PROFILE_SOURCE_V1)

abstract type N06TypedValueV1 end
struct N06TextValueV1 <: N06TypedValueV1; value::String; end
struct N06SymbolValueV1 <: N06TypedValueV1; value::Symbol; end
struct N06UnitValueV1 <: N06TypedValueV1; value::UnitSignature; end
struct N06RationalValueV1 <: N06TypedValueV1; value::Rational{Int64}; end
struct N06StringTupleValueV1 <: N06TypedValueV1; value::Tuple{Vararg{String}}; end

struct N06SourceFieldV1
    id::String
    field_path::String
    source_locator::String
    source_type::Symbol
    value::N06TypedValueV1
end

struct N06DimensionedConversionV1
    law_id::QualifiedRefV1
    from_unit::UnitSignature
    to_unit::UnitSignature
    scale::Rational{Int64}
    offset::Rational{Int64}
    dimension_rule::Symbol
    provenance::String
    law_hash::Digest256
    function N06DimensionedConversionV1(law_id::QualifiedRefV1,
            from_unit::UnitSignature, to_unit::UnitSignature,
            scale::Rational, offset::Rational, dimension_rule::Symbol,
            provenance::AbstractString; law_hash::Union{Nothing,Digest256}=nothing)
        law_id.version == "v1" || throw(ArgumentError("N06 conversion law requires v1 token"))
        scale != 0 // 1 || throw(ArgumentError("N06 conversion scale cannot be zero"))
        dimension_rule in (:same_dimension, :time_derivative, :power_from_effort_flow) ||
            throw(ArgumentError("N06 conversion dimension rule is unsupported"))
        !isempty(String(provenance)) || throw(ArgumentError("N06 conversion provenance is required"))
        expected_law_hash = _n06_conversion_law_hash(dimension_rule)
        law_hash === nothing || law_hash == expected_law_hash ||
            throw(ArgumentError("N06 conversion law content hash mismatch"))
        new(law_id, from_unit, to_unit, Rational{Int64}(scale), Rational{Int64}(offset),
            dimension_rule, String(provenance), expected_law_hash)
    end
end

struct N06SourceFieldLedgerJoinV1
    role::Symbol
    g1_equation_id::String
    g1_occurrence_key::NamedTuple
    g1_closure_id::Union{Nothing,String}
    g2_region_id::String
    g2_boundary_face::Symbol
    g2_boundary_locator::String
    g3_port_id::String
    g3_partner_port_id::Union{Nothing,String}
    g3_link_id::Union{Nothing,String}
    g3_account_id::String
    g3_entry_id::Union{Nothing,String}
    g3_closure_id::Union{Nothing,String}
    owner_scope::String
    owner_account_ids::Tuple{Vararg{String}}
    energy_boundary::String
    conversion::N06DimensionedConversionV1
    provenance::String
    function N06SourceFieldLedgerJoinV1(role::Symbol, g1_equation_id::AbstractString,
            g1_occurrence_key::NamedTuple, g1_closure_id,
            g2_region_id::AbstractString, g2_boundary_face::Symbol,
            g2_boundary_locator::AbstractString, g3_port_id::AbstractString,
            g3_account_id::AbstractString, g3_entry_id, g3_closure_id,
            owner_scope::AbstractString, owner_account_ids, energy_boundary::AbstractString,
            conversion::N06DimensionedConversionV1,
            provenance::AbstractString; partner_port_id=nothing, link_id=nothing)
        role in (:source, :field, :return, :heat) || throw(ArgumentError("N06 mapping role is invalid"))
        !isempty(String(g1_equation_id)) && !isempty(String(g2_region_id)) ||
            throw(ArgumentError("N06 G1/G2 locators are required"))
        !isempty(String(g2_boundary_locator)) && !isempty(String(g3_port_id)) &&
            !isempty(String(g3_account_id)) || throw(ArgumentError("N06 G2/G3 locators are required"))
        ids = Tuple(String(x) for x in owner_account_ids)
        !isempty(ids) && !isempty(String(owner_scope)) && !isempty(String(energy_boundary)) &&
            !isempty(String(provenance)) ||
            throw(ArgumentError("N06 owner scope and provenance are required"))
        new(role, String(g1_equation_id), g1_occurrence_key,
            g1_closure_id === nothing ? nothing : String(g1_closure_id), String(g2_region_id),
            g2_boundary_face, String(g2_boundary_locator), String(g3_port_id),
            partner_port_id === nothing ? nothing : String(partner_port_id),
            link_id === nothing ? nothing : String(link_id),
            String(g3_account_id), g3_entry_id === nothing ? nothing : String(g3_entry_id),
            g3_closure_id === nothing ? nothing : String(g3_closure_id), String(owner_scope), ids,
            String(energy_boundary), conversion, String(provenance))
    end
end

struct N06SourceFieldLedgerMappingV1
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    e0_bound_input_hash::Digest256
    g1_ref::GenomeContractRef
    g2_ref::GenomeContractRef
    g3_ref::GenomeContractRef
    version_axes::NamedTuple
    joins::Tuple{Vararg{N06SourceFieldLedgerJoinV1}}
    schema_hash::Digest256
    canonicalization_hash::Digest256
    profile_hash::Digest256
    mapping_hash::Digest256
end

struct N06LedgerProjectionV1
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    e0_bound_input_hash::Digest256
    g1_ref::GenomeContractRef
    g2_ref::GenomeContractRef
    g3_ref::GenomeContractRef
    g1_equation_id::String
    g1_occurrence_key::NamedTuple
    g1_occurrence_keys::Tuple{Vararg{NamedTuple}}
    g1_closure_id::String
    g2_region_id::String
    g2_boundary_face::Symbol
    g2_boundary_locator::String
    g3_selected_flow_link_id::String
    network::G3ResourceNetworkV2
    fields::Tuple{Vararg{N06SourceFieldV1}}
    authority_gaps::Tuple{Vararg{String}}
    projection_hash::Digest256
end

struct N06MutationSpecV1
    id::String
    class_id::Symbol
    field_path::String
    source_locator::String
    source_type::Symbol
    mutation_kind::Symbol
    expected_error::Symbol
end

struct N06InvocationCounterV1
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
end
N06InvocationCounterV1() = N06InvocationCounterV1(0, 0, 0)

struct N06ValidationResultV1
    mutation_id::String
    input_hash::Digest256
    mutated_input_hash::Digest256
    status::Symbol
    error_code::Symbol
    error_path::String
    detail::String
    gap::Union{Nothing,String}
    original_value::N06TypedValueV1
    mutated_value::N06TypedValueV1
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
    result_hash::Digest256
end

semantic_view(x::N06TextValueV1) = (kind=:text, value=x.value)
semantic_view(x::N06SymbolValueV1) = (kind=:symbol, value=x.value)
semantic_view(x::N06UnitValueV1) = (kind=:unit, value=x.value)
semantic_view(x::N06RationalValueV1) = (kind=:rational, value=x.value)
semantic_view(x::N06StringTupleValueV1) = (kind=:string_tuple, value=x.value)
semantic_view(x::N06InvocationCounterV1) =
    (compile_calls=x.compile_calls, provider_calls=x.provider_calls,
     solver_calls=x.solver_calls)
semantic_view(x::N06SourceFieldV1) = (id=x.id, field_path=x.field_path,
    source_locator=x.source_locator, source_type=x.source_type, value=x.value)
semantic_view(x::N06DimensionedConversionV1) = (law_id=x.law_id,
    from_unit=x.from_unit, to_unit=x.to_unit, scale=x.scale, offset=x.offset,
    dimension_rule=x.dimension_rule, provenance=x.provenance, law_hash=x.law_hash)
semantic_view(x::N06SourceFieldLedgerJoinV1) = (role=x.role,
    g1_equation_id=x.g1_equation_id,
    g1_occurrence_key=x.g1_occurrence_key, g1_closure_id=x.g1_closure_id,
    g2_region_id=x.g2_region_id, g2_boundary_face=x.g2_boundary_face,
    g2_boundary_locator=x.g2_boundary_locator, g3_port_id=x.g3_port_id,
    g3_partner_port_id=x.g3_partner_port_id,
    g3_link_id=x.g3_link_id,
    g3_account_id=x.g3_account_id, g3_entry_id=x.g3_entry_id,
    g3_closure_id=x.g3_closure_id, owner_scope=x.owner_scope,
    owner_account_ids=x.owner_account_ids, energy_boundary=x.energy_boundary,
    conversion=x.conversion, provenance=x.provenance)
semantic_view(x::N06SourceFieldLedgerMappingV1) =
    (candidate_ref=x.candidate_ref, package_hash=x.package_hash,
     e0_bound_input_hash=x.e0_bound_input_hash, g1_ref=x.g1_ref, g2_ref=x.g2_ref,
     g3_ref=x.g3_ref, version_axes=x.version_axes, joins=x.joins,
     schema_hash=x.schema_hash, canonicalization_hash=x.canonicalization_hash,
     profile_hash=x.profile_hash)
semantic_view(x::N06LedgerProjectionV1) =
    (candidate_ref=x.candidate_ref, package_hash=x.package_hash,
     e0_bound_input_hash=x.e0_bound_input_hash, g1_ref=x.g1_ref, g2_ref=x.g2_ref,
     g3_ref=x.g3_ref, g1_equation_id=x.g1_equation_id,
     g1_occurrence_key=x.g1_occurrence_key, g1_occurrence_keys=x.g1_occurrence_keys,
     g1_closure_id=x.g1_closure_id,
     g2_region_id=x.g2_region_id, g2_boundary_face=x.g2_boundary_face,
     g2_boundary_locator=x.g2_boundary_locator,
     g3_selected_flow_link_id=x.g3_selected_flow_link_id, network=x.network,
     fields=x.fields, authority_gaps=x.authority_gaps)
semantic_view(x::N06MutationSpecV1) =
    (id=x.id, class_id=x.class_id, field_path=x.field_path,
     source_locator=x.source_locator, source_type=x.source_type,
     mutation_kind=x.mutation_kind, expected_error=x.expected_error)

function _n06_unique_index(items, id_of::Function, label::AbstractString)
    # Preserve the authored identity type.  G1 occurrence keys are typed
    # four-tuples, while the other registries use String IDs; stringifying
    # here loses the occurrence identity and raises on a Tuple.
    ids = [id_of(x) for x in items]
    length(unique(ids)) == length(ids) ||
        throw(ArgumentError("N06 $(label) contains duplicate IDs"))
    index = Dict{Any,Any}()
    for (id, item) in zip(ids, items)
        haskey(index, id) &&
            throw(ArgumentError("N06 $(label) contains duplicate IDs"))
        index[id] = item
    end
    index
end

function _n06_unique_match(items, predicate::Function, label::AbstractString)
    matches = [x for x in items if predicate(x)]
    isempty(matches) && throw(ArgumentError("N06 $(label) has no source match"))
    length(matches) == 1 || throw(ArgumentError("N06 $(label) is ambiguous"))
    only(matches)
end

function _n06_index_for(items, id_of::Function, value, label::AbstractString)
    _n06_unique_index(items, id_of, label)
    indices = findall(x -> id_of(x) == value, items)
    length(indices) == 1 || throw(ArgumentError("N06 $(label) locator is missing or ambiguous"))
    only(indices)
end

function _n06_resolve(items, predicate::Function, label::AbstractString,
                       errors::Vector{String})
    matches = [x for x in items if predicate(x)]
    isempty(matches) && push!(errors, "$(label)_missing")
    length(matches) > 1 && push!(errors, "$(label)_ambiguous")
    length(matches) == 1 ? only(matches) : nothing
end

function _n06_actual_refs(package::CandidateStatePackageV5)
    package.g1.contract_ref isa GenomeContractRef || throw(ArgumentError("N06 G1 ref missing"))
    package.g2.contract_ref isa GenomeContractRef || throw(ArgumentError("N06 G2 ref missing"))
    package.g3.contract_binding.contract_ref isa GenomeContractRef || throw(ArgumentError("N06 G3 ref missing"))
    package.g1.contract_ref, package.g2.contract_ref, package.g3.contract_binding.contract_ref
end

function _n06_actual_fields(package::CandidateStatePackageV5)
    equations = package.g1.payload.equation_plan.equations
    isempty(equations) && throw(ArgumentError("N06 actual A package has no G1 equations"))
    _n06_unique_index(equations, x -> x.equation_id, "G1 equations")
    governing_selector = get(_N06_G1_ROLE_SELECTORS, :source, nothing)
    governing_selector === nothing &&
        throw(ArgumentError("N06 authored governing selector is missing"))
    equation = _n06_unique_match(equations,
        x -> x.role == :governing && x.equation_id == governing_selector.equation_id &&
            !isempty(x.occurrences), "G1 authored governing equation")
    isempty(equation.occurrences) && throw(ArgumentError("N06 actual A package has no G1 occurrences"))
    _n06_unique_index(equation.occurrences,
        x -> (x.ledger_id, x.equation_id, x.port_side, x.port_index),
        "G1 occurrence keys")
    occurrence = _n06_unique_match(equation.occurrences,
        x -> (ledger_id=x.ledger_id, equation_id=x.equation_id,
            port_side=x.port_side, port_index=x.port_index) ==
            _n06_selector_key(governing_selector),
        "G1 authored governing occurrence")
    closures = package.g1.payload.grammar_profile.closures
    isempty(closures) && throw(ArgumentError("N06 actual A package has no G1 closures"))
    _n06_unique_index(closures, x -> x.closure_id, "G1 closures")
    closure = _n06_unique_match(closures, x -> x.closure_id == equation.closure_ref,
        "G1 equation closure")
    regions = package.g2.region_interface.regions
    isempty(regions) && throw(ArgumentError("N06 actual A package has no G2 regions"))
    _n06_unique_index(regions, x -> x.region_id, "G2 regions")
    patches = package.g2.plan.exterior.boundary_patches
    isempty(patches) && throw(ArgumentError("N06 actual A package has no G2 boundary patch"))
    interfaces = package.g2.region_interface.interfaces
    interface = _n06_unique_match(interfaces,
        i -> _N06_G2_SELECTOR.interface_side == :left && i.left_region_id != i.right_region_id,
        "G2 authored interface")
    region = _n06_unique_match(regions,
        r -> r.region_id == interface.left_region_id,
        "G2 authored interface-left region")
    patch_candidates = [x for x in patches if x.region_id == region.region_id]
    isempty(patch_candidates) && throw(ArgumentError("N06 G2 region has no boundary patch"))
    patch = _n06_unique_match(patch_candidates, x -> x.face == _N06_G2_SELECTOR.boundary_face,
        "G2 authored boundary patch")
    network = package.g3.realization.network
    isempty(network.resource_ports) && throw(ArgumentError("N06 actual A package has no G3 resource ports"))
    isempty(network.entries) && throw(ArgumentError("N06 actual A package has no G3 entries"))
    isempty(network.closures) && throw(ArgumentError("N06 actual A package has no G3 closures"))
    links = package.g3.binding.links
    isempty(links) && throw(ArgumentError("N06 actual A package has no G3 control-resource links"))
    _n06_unique_index(network.resource_ports, x -> x.port_id, "G3 resource ports")
    _n06_unique_index(network.entries, x -> x.entry_id, "G3 entries")
    _n06_unique_index(network.accounts, x -> x.account_id, "G3 accounts")
    _n06_unique_index(network.closures, x -> x.closure_id, "G3 ledger closures")
    _n06_unique_index(links, x -> x.link_id, "G3 control-resource links")
    port = _n06_unique_match(network.resource_ports, x -> x.kind == :effort,
        "G3 effort resource port")
    entry = _n06_unique_match(network.entries, x -> x.port_id == port.port_id,
        "G3 entry for effort resource port")
    g3closure = _n06_unique_match(network.closures,
        x -> entry.account_id in x.account_ids, "G3 closure for effort account")
    flow_port = _n06_unique_match(network.resource_ports, x -> x.kind == :flow,
        "G3 flow resource port")
    link = _n06_unique_match(links, x -> x.resource_port_id == flow_port.port_id,
        "G3 control-resource link for selected flow port")
    pi = _n06_index_for(network.resource_ports, x -> x.port_id, port.port_id,
        "G3 resource port")
    ei = _n06_index_for(network.entries, x -> x.entry_id, entry.entry_id,
        "G3 entry")
    ci = _n06_index_for(network.closures, x -> x.closure_id, g3closure.closure_id,
        "G3 ledger closure")
    li = _n06_index_for(links, x -> x.link_id, link.link_id,
        "G3 control-resource link")
    fields = (
        N06SourceFieldV1("N06-01", "/g3/realization/network/resource_ports/$(pi - 1)/port_id",
            "G3ResourcePortV2.port_id::String", :text, N06TextValueV1(port.port_id)),
        N06SourceFieldV1("N06-02", "/g3/realization/network/entries/$(ei - 1)/account_id",
            "G3LedgerEntryV2.account_id::String", :text, N06TextValueV1(entry.account_id)),
        N06SourceFieldV1("N06-03", "/g3/binding/links/$(li - 1)/resource_port_id",
            "G3ControlResourceLinkV2.resource_port_id::String", :text,
            N06TextValueV1(link.resource_port_id)),
        N06SourceFieldV1("N06-04", "/g3/realization/network/closures/$(ci - 1)/expected_balance",
            "G3LedgerClosureV2.expected_balance::Rational{Int64}", :rational,
            N06RationalValueV1(g3closure.expected_balance)),
        N06SourceFieldV1("N06-05", "/g3/realization/network/resource_ports/$(pi - 1)/kind",
            "G3ResourcePortV2.kind::Symbol", :symbol, N06SymbolValueV1(port.kind)))
    (equation, occurrence, closure, region, patch, network, entry, g3closure, link, fields)
end

function n06_projection_from_a(package::CandidateStatePackageV5,
                                e0::UP2CandidatePhysicalBindingV1)
    package.structural_status == :valid || throw(ArgumentError("N06 requires structural-valid A package"))
    e0_check = up2e0_validate_binding(e0, package)
    e0_check.status == :valid || begin
        e0_check.status == :program_exception &&
            throw(ErrorException("N06 E0 binding program_exception: " * join(e0_check.errors, ",")))
        throw(ArgumentError("N06 E0 binding validation failed: " * join(e0_check.errors, ",")))
    end
    e0.bound_input_hash isa Digest256 || throw(ArgumentError("N06 E0 bound hash missing"))
    e0.n05 === nothing && e0.n06 === nothing ||
        throw(ArgumentError("N06 cannot inject extensions into E0 v1 binding"))
    check = up2e0_check_package(package)
    check.status == :valid || begin
        check.status == :program_exception &&
            throw(ErrorException("N06 E0 source program_exception: " * join(check.errors, ",")))
        throw(ArgumentError("N06 E0 source validation failed: " * join(check.errors, ",")))
    end
    g1_ref, g2_ref, g3_ref = _n06_actual_refs(package)
    equation, occurrence, closure, region, patch, _, _, _, link, fields =
        _n06_actual_fields(package)
    boundary_index = _n06_index_for(package.g2.plan.exterior.boundary_patches,
        x -> (x.region_id, x.face), (patch.region_id, patch.face),
        "G2 boundary patch")
    boundary_locator = "/g2/plan/exterior/boundary_patches/$(boundary_index - 1)/$(patch.face)"
    gaps = ("g1_occurrence_to_g2_boundary_exact_join_missing",
        "g1_source_field_to_g3_return_heat_ledger_join_missing",
        "owner_scope_mapping_missing_shared_owner_is_legal")
    network = package.g3.realization.network
    occurrence_key = (ledger_id=occurrence.ledger_id, equation_id=occurrence.equation_id,
        port_side=occurrence.port_side, port_index=occurrence.port_index)
    all_occurrence_keys = Tuple((ledger_id=o.ledger_id, equation_id=o.equation_id,
        port_side=o.port_side, port_index=o.port_index)
        for e in package.g1.payload.equation_plan.equations for o in e.occurrences)
    N06LedgerProjectionV1(package.candidate_ref, package.candidate_hash,
        e0.bound_input_hash, g1_ref, g2_ref, g3_ref, equation.equation_id,
        occurrence_key, all_occurrence_keys, closure.closure_id, region.region_id, patch.face,
        boundary_locator, link.link_id, network, fields, gaps,
        canonical_hash((candidate_ref=package.candidate_ref, package_hash=package.candidate_hash,
            e0_bound_input_hash=e0.bound_input_hash, g1_ref=g1_ref, g2_ref=g2_ref,
            g3_ref=g3_ref, g1_equation_id=equation.equation_id,
            g1_occurrence_key=occurrence_key, g1_occurrence_keys=all_occurrence_keys,
            g1_closure_id=closure.closure_id,
            g2_region_id=region.region_id, g2_boundary_face=patch.face,
            g2_boundary_locator=boundary_locator, g3_selected_flow_link_id=link.link_id,
            network=network, fields=fields,
            authority_gaps=gaps)))
end

function _n06_join_errors(package::CandidateStatePackageV5,
                           joins::Tuple{Vararg{N06SourceFieldLedgerJoinV1}};
                           projection=nothing)
    equation, occurrence, closure, region, patch, network, entry, g3closure, link, _ = _n06_actual_fields(package)
    errors = String[]
    roles = Tuple(j.role for j in joins)
    required_roles = (:source, :field, :return, :heat)
    isempty(joins) && push!(errors, "n06_mapping_has_no_joins")
    Set(roles) == Set(required_roles) && length(roles) == length(required_roles) ||
        push!(errors, "n06_mapping_roles_incomplete_or_duplicate")
    equations = package.g1.payload.equation_plan.equations
    regions = package.g2.region_interface.regions
    patches = package.g2.plan.exterior.boundary_patches
    port_map = _n06_unique_index(network.resource_ports, x -> x.port_id, "G3 resource ports")
    account_map = _n06_unique_index(network.accounts, x -> x.account_id, "G3 accounts")
    entry_map = _n06_unique_index(network.entries, x -> x.entry_id, "G3 entries")
    closure_map = _n06_unique_index(network.closures, x -> x.closure_id, "G3 ledger closures")
    role_kind = Dict(:source => (:effort, :flow), :field => (:load,),
        :return => (:return,), :heat => (:heat_sink,))
    seen_occurrences = Set{Any}()
    seen_ports = Set{String}()
    seen_entries = Set{String}()
    for join in joins
        expected_selector = get(_N06_G1_ROLE_SELECTORS, join.role, nothing)
        expected_selector === nothing && push!(errors, "g1_role_selector_missing")
        expected_selector === nothing && continue
        expected_key = _n06_selector_key(expected_selector)
        join.g1_occurrence_key == expected_key ||
            push!(errors, "g1_occurrence_not_bound_to_role_selector")
        eq = _n06_resolve(equations, e -> e.equation_id == join.g1_equation_id,
            "g1_equation_locator", errors)
        eq === nothing && continue
        key = join.g1_occurrence_key
        projection === nothing || key in projection.g1_occurrence_keys ||
            push!(errors, "g1_occurrence_not_in_projection")
        if projection !== nothing && join.role == :source
            join.g1_equation_id == projection.g1_equation_id ||
                push!(errors, "g1_equation_not_in_projection")
            join.g1_closure_id == projection.g1_closure_id ||
                push!(errors, "g1_closure_not_in_projection")
        end
        projection === nothing || join.g2_region_id == projection.g2_region_id ||
            push!(errors, "g2_region_not_in_projection")
        projection === nothing || join.g2_boundary_face == projection.g2_boundary_face ||
            push!(errors, "g2_boundary_face_not_in_projection")
        projection === nothing || join.g2_boundary_locator == projection.g2_boundary_locator ||
            push!(errors, "g2_boundary_locator_not_in_projection")
        if join.role == :source && projection !== nothing
            join.g3_link_id == projection.g3_selected_flow_link_id ||
                push!(errors, "power_flow_link_not_in_projection")
        end
        matched_occurrence = _n06_resolve(eq.occurrences, o ->
            (ledger_id=o.ledger_id, equation_id=o.equation_id,
             port_side=o.port_side, port_index=o.port_index) == key,
            "g1_occurrence_locator", errors)
        matched_occurrence === nothing || push!(seen_occurrences, key)
        matched_occurrence === nothing || join.conversion.from_unit == matched_occurrence.unit ||
            push!(errors, "conversion_from_unit_mismatch")
        cl = _n06_resolve(package.g1.payload.grammar_profile.closures,
            c -> c.closure_id == join.g1_closure_id, "g1_closure_locator", errors)
        cl === nothing || eq.closure_ref == cl.closure_id || push!(errors, "g1_equation_closure_join_mismatch")
        rg = _n06_resolve(regions, r -> r.region_id == join.g2_region_id,
            "g2_region_locator", errors)
        boundary_matches = findall(p -> p.region_id == join.g2_region_id &&
            p.face == join.g2_boundary_face, patches)
        isempty(boundary_matches) && push!(errors, "g2_boundary_locator_missing")
        length(boundary_matches) > 1 && push!(errors, "g2_boundary_locator_ambiguous")
        boundary_index = length(boundary_matches) == 1 ? only(boundary_matches) : nothing
        boundary_index === nothing || join.g2_boundary_locator ==
            "/g2/plan/exterior/boundary_patches/$(boundary_index - 1)/$(join.g2_boundary_face)" ||
            push!(errors, "g2_boundary_locator_mismatch")
        haskey(port_map, join.g3_port_id) || push!(errors, "g3_port_locator_mismatch")
        haskey(account_map, join.g3_account_id) || push!(errors, "g3_account_locator_mismatch")
        join.g3_entry_id === nothing || haskey(entry_map, join.g3_entry_id) || push!(errors, "g3_entry_locator_mismatch")
        join.g3_closure_id === nothing || haskey(closure_map, join.g3_closure_id) || push!(errors, "g3_closure_locator_mismatch")
        haskey(port_map, join.g3_port_id) && port_map[join.g3_port_id].kind in get(role_kind, join.role, ()) ||
            push!(errors, "g3_role_kind_mismatch")
        if join.role == :source
            join.g3_link_id == link.link_id ||
                push!(errors, "power_flow_link_identity_mismatch")
            link.resource_port_id == join.g3_port_id ||
                push!(errors, "power_flow_link_port_mismatch")
            join.g3_partner_port_id === nothing && push!(errors, "power_flow_partner_missing")
            partner = join.g3_partner_port_id === nothing ? nothing :
                get(port_map, join.g3_partner_port_id, nothing)
            partner === nothing && push!(errors, "power_flow_partner_locator_mismatch")
            partner === nothing || partner.kind == :effort ||
                push!(errors, "power_flow_partner_kind_mismatch")
            haskey(port_map, join.g3_port_id) && port_map[join.g3_port_id].kind == :flow ||
                push!(errors, "power_source_port_must_be_flow")
            if partner !== nothing && haskey(port_map, join.g3_port_id)
                expected_power = UnitSignature(ntuple(i ->
                    partner.unit.exponents[i] + port_map[join.g3_port_id].unit.exponents[i], 7))
                join.conversion.to_unit == expected_power ||
                    push!(errors, "power_effort_flow_dimension_mismatch")
            end
        end
        push!(seen_ports, join.g3_port_id)
        join.g3_entry_id === nothing || push!(seen_entries, join.g3_entry_id)
        haskey(entry_map, join.g3_entry_id) && entry_map[join.g3_entry_id].port_id == join.g3_port_id ||
            push!(errors, "g3_entry_port_join_mismatch")
        haskey(closure_map, join.g3_closure_id) && join.g3_account_id in closure_map[join.g3_closure_id].account_ids ||
            push!(errors, "g3_closure_account_join_mismatch")
        length(unique(join.owner_account_ids)) == length(join.owner_account_ids) ||
            push!(errors, "owner_scope_accounts_duplicate")
        all(haskey(account_map, id) for id in join.owner_account_ids) || push!(errors, "owner_scope_account_missing")
        haskey(entry_map, join.g3_entry_id) && join.conversion.to_unit == entry_map[join.g3_entry_id].unit ||
            push!(errors, "conversion_to_unit_mismatch")
        join.conversion.dimension_rule in (:same_dimension, :time_derivative, :power_from_effort_flow) ||
            push!(errors, "conversion_dimension_rule_invalid")
        join.conversion.law_hash == _n06_conversion_law_hash(join.conversion.dimension_rule) ||
            push!(errors, "conversion_law_content_hash_mismatch")
        if join.conversion.dimension_rule == :same_dimension
            join.conversion.from_unit == join.conversion.to_unit ||
                push!(errors, "conversion_same_dimension_mismatch")
        elseif join.conversion.dimension_rule == :time_derivative
            expected_time_unit = UnitSignature(ntuple(i ->
                join.conversion.from_unit.exponents[i] - (i == 3 ? 1 : 0), 7))
            join.conversion.to_unit == expected_time_unit ||
                push!(errors, "conversion_time_derivative_dimension_mismatch")
        end
        (join.conversion.dimension_rule == :same_dimension || join.conversion.offset == (0 // 1)) ||
            push!(errors, "conversion_offset_invalid_for_derived_dimension")
        if haskey(account_map, join.g3_account_id)
            owner = account_map[join.g3_account_id].owner
            expected_accounts = Tuple(a.account_id for a in network.accounts if a.owner == owner)
            join.owner_scope == owner || push!(errors, "owner_scope_name_mismatch")
            join.owner_account_ids == expected_accounts || push!(errors, "owner_scope_account_join_mismatch")
        end
        expected_boundary = boundary_index === nothing ? "" :
            "$(join.g2_region_id):$(join.g2_boundary_face):$(join.g3_closure_id):$(join.g3_entry_id)"
        join.energy_boundary == expected_boundary || push!(errors, "energy_boundary_locator_mismatch")
    end
    length(seen_occurrences) == length(roles) || push!(errors, "g1_occurrence_roles_must_be_distinct")
    length(seen_ports) == length(roles) || push!(errors, "g3_role_ports_must_be_distinct")
    length(seen_entries) == length(roles) || push!(errors, "g3_role_entries_must_be_distinct")
    unique!(errors)
end

function n06_mapping_from_a(package::CandidateStatePackageV5,
                             e0::UP2CandidatePhysicalBindingV1,
                             joins::Tuple{Vararg{N06SourceFieldLedgerJoinV1}})
    projection = n06_projection_from_a(package, e0)
    errors = _n06_join_errors(package, joins; projection=projection)
    isempty(errors) || throw(ArgumentError("N06 mapping is structurally inconsistent: " * join(errors, ",")))
    g1_ref, g2_ref, g3_ref = projection.g1_ref, projection.g2_ref, projection.g3_ref
    body = (candidate_ref=projection.candidate_ref, package_hash=projection.package_hash,
        e0_bound_input_hash=projection.e0_bound_input_hash, g1_ref=g1_ref, g2_ref=g2_ref,
        g3_ref=g3_ref, version_axes=package.version_axes, joins=joins)
    N06SourceFieldLedgerMappingV1(projection.candidate_ref, projection.package_hash,
        projection.e0_bound_input_hash, g1_ref, g2_ref, g3_ref, package.version_axes,
        joins, n06_schema_hash(), n06_canonicalization_hash(), n06_profile_hash(),
        canonical_hash(body))
end

function _n06_mapping_hash(mapping::N06SourceFieldLedgerMappingV1)
    canonical_hash((candidate_ref=mapping.candidate_ref, package_hash=mapping.package_hash,
        e0_bound_input_hash=mapping.e0_bound_input_hash, g1_ref=mapping.g1_ref,
        g2_ref=mapping.g2_ref, g3_ref=mapping.g3_ref, version_axes=mapping.version_axes,
        joins=mapping.joins))
end

function _n06_copy(p::N06LedgerProjectionV1, id::AbstractString, value::N06TypedValueV1)
    fields = Tuple(x.id == String(id) ? N06SourceFieldV1(x.id, x.field_path,
        x.source_locator, x.source_type, value) : x for x in p.fields)
    N06LedgerProjectionV1(p.candidate_ref, p.package_hash, p.e0_bound_input_hash,
        p.g1_ref, p.g2_ref, p.g3_ref, p.g1_equation_id, p.g1_occurrence_key,
        p.g1_occurrence_keys, p.g1_closure_id, p.g2_region_id, p.g2_boundary_face,
        p.g2_boundary_locator, p.g3_selected_flow_link_id, p.network, fields, p.authority_gaps,
        canonical_hash((candidate_ref=p.candidate_ref, package_hash=p.package_hash,
            e0_bound_input_hash=p.e0_bound_input_hash, g1_ref=p.g1_ref, g2_ref=p.g2_ref,
            g3_ref=p.g3_ref, g1_equation_id=p.g1_equation_id,
            g1_occurrence_key=p.g1_occurrence_key, g1_occurrence_keys=p.g1_occurrence_keys,
            g1_closure_id=p.g1_closure_id,
            g2_region_id=p.g2_region_id, g2_boundary_face=p.g2_boundary_face,
            g2_boundary_locator=p.g2_boundary_locator,
            g3_selected_flow_link_id=p.g3_selected_flow_link_id, network=p.network,
            fields=fields, authority_gaps=p.authority_gaps)))
end

function _n06_path_index(path::AbstractString, collection::AbstractString)
    match(Regex("/$(collection)/(\\d+)/"), String(path))
end

function _n06_field_for_spec(p::N06LedgerProjectionV1,
                             spec::N06MutationSpecV1)
    matches = [x for x in p.fields if x.field_path == spec.field_path]
    length(matches) == 1 ||
        throw(ArgumentError("N06 mutation field path is missing or ambiguous"))
    only(matches)
end

function _n06_validate_spec_binding(p::N06LedgerProjectionV1,
                                    spec::N06MutationSpecV1)
    # The receipt id is a label only.  Dispatch is registered by the exact
    # projection path and mutation kind, then anchored to the typed source
    # locator/type and the selected original value.
    field = _n06_field_for_spec(p, spec)
    expected_kind = if field.source_locator == "G3ResourcePortV2.port_id::String" &&
            endswith(field.field_path, "/port_id") && field.source_type == :text
        :wrong_resource_port
    elseif field.source_locator == "G3LedgerEntryV2.account_id::String" &&
            endswith(field.field_path, "/account_id") && field.source_type == :text
        :wrong_entry_account
    elseif field.source_locator == "G3ControlResourceLinkV2.resource_port_id::String" &&
            endswith(field.field_path, "/resource_port_id") && field.source_type == :text
        :missing_control_link
    elseif field.source_locator == "G3LedgerClosureV2.expected_balance::Rational{Int64}" &&
            endswith(field.field_path, "/expected_balance") && field.source_type == :rational
        :closure_balance_mismatch
    elseif field.source_locator == "G3ResourcePortV2.kind::Symbol" &&
            endswith(field.field_path, "/kind") && field.source_type == :symbol
        :wrong_resource_kind
    else
        nothing
    end
    expected_kind === nothing &&
        throw(ArgumentError("N06 mutation target is not registered by path and source type"))
    spec.field_path == field.field_path && spec.mutation_kind === expected_kind ||
        throw(ArgumentError("N06 mutation kind is not bound to exact field path"))
    field.field_path == spec.field_path ||
        throw(ArgumentError("N06 mutation field path is not bound to projection"))
    field.source_locator == spec.source_locator ||
        throw(ArgumentError("N06 mutation source locator is not bound to projection"))
    field.source_type == spec.source_type ||
        throw(ArgumentError("N06 mutation source type is not bound to projection"))
    field.value isa N06TypedValueV1 ||
        throw(ArgumentError("N06 mutation target is not typed"))
    field
end

function _n06_source_field_matches(p::N06LedgerProjectionV1,
                                   field::N06SourceFieldV1,
                                   package::CandidateStatePackageV5)
    if occursin("/resource_ports/", field.field_path)
        m = _n06_path_index(field.field_path, "resource_ports")
        m === nothing && return (false, "resource_port_path_invalid")
        idx = parse(Int, m.captures[1]) + 1
        idx <= length(p.network.resource_ports) ||
            return (false, "resource_port_path_out_of_bounds")
        actual = p.network.resource_ports[idx]
        if endswith(field.field_path, "/port_id") &&
                field.source_locator == "G3ResourcePortV2.port_id::String"
            return (field.value isa N06TextValueV1 && field.value.value == actual.port_id,
                "resource_port_target_not_source_backed")
        elseif endswith(field.field_path, "/kind") &&
                field.source_locator == "G3ResourcePortV2.kind::Symbol"
            return (field.value isa N06SymbolValueV1 && field.value.value == actual.kind,
                "resource_kind_target_not_source_backed")
        end
    elseif occursin("/entries/", field.field_path) && endswith(field.field_path, "/account_id")
        m = _n06_path_index(field.field_path, "entries")
        m === nothing && return (false, "entry_path_invalid")
        idx = parse(Int, m.captures[1]) + 1
        idx <= length(p.network.entries) || return (false, "entry_path_out_of_bounds")
        actual = p.network.entries[idx]
        return (field.value isa N06TextValueV1 &&
            field.source_locator == "G3LedgerEntryV2.account_id::String" &&
            field.value.value == actual.account_id, "entry_target_not_source_backed")
    elseif occursin("/links/", field.field_path) && endswith(field.field_path, "/resource_port_id")
        m = _n06_path_index(field.field_path, "links")
        m === nothing && return (false, "link_path_invalid")
        idx = parse(Int, m.captures[1]) + 1
        idx <= length(package.g3.binding.links) ||
            return (false, "link_path_not_network_backed")
        actual = package.g3.binding.links[idx]
        return (field.value isa N06TextValueV1 &&
            field.source_locator == "G3ControlResourceLinkV2.resource_port_id::String" &&
            actual.link_id == p.g3_selected_flow_link_id &&
            field.value.value == actual.resource_port_id,
            "control_resource_link_target_not_source_backed")
    elseif occursin("/closures/", field.field_path) && endswith(field.field_path, "/expected_balance")
        m = _n06_path_index(field.field_path, "closures")
        m === nothing && return (false, "closure_path_invalid")
        idx = parse(Int, m.captures[1]) + 1
        idx <= length(p.network.closures) || return (false, "closure_path_out_of_bounds")
        actual = p.network.closures[idx]
        return (field.value isa N06RationalValueV1 &&
            field.source_locator == "G3LedgerClosureV2.expected_balance::Rational{Int64}" &&
            field.value.value == actual.expected_balance, "closure_target_not_source_backed")
    end
    (false, "mutation_target_locator_unrecognized")
end

function _n06_mutate(p::N06LedgerProjectionV1,
                     package::CandidateStatePackageV5,
                     spec::N06MutationSpecV1)
    field = _n06_validate_spec_binding(p, spec)
    source_ok, source_detail = _n06_source_field_matches(p, field, package)
    source_ok || throw(ArgumentError("N06 mutation target is not source-backed: " * source_detail))
    target = (field_path=field.field_path, mutation_kind=spec.mutation_kind,
        source_locator=field.source_locator, source_type=field.source_type,
        original=field.value)
    target.mutation_kind === :wrong_resource_port &&
        return _n06_copy(p, field.id, N06TextValueV1("forged-resource-port"))
    target.mutation_kind === :wrong_entry_account &&
        return _n06_copy(p, field.id, N06TextValueV1("forged-account"))
    target.mutation_kind === :missing_control_link &&
        return _n06_copy(p, field.id, N06TextValueV1("missing-link-resource"))
    target.mutation_kind === :closure_balance_mismatch &&
        return _n06_copy(p, field.id, N06RationalValueV1(field.value.value + (1 // 1)))
    target.mutation_kind === :wrong_resource_kind &&
        return _n06_copy(p, field.id, N06SymbolValueV1(:unsupported_kind))
    throw(ArgumentError("unknown N06 mutation $(spec.id)"))
end

function _n06_classify(p::N06LedgerProjectionV1, q::N06LedgerProjectionV1,
                       spec::N06MutationSpecV1)
    _n06_validate_spec_binding(p, spec)
    field = _n06_field_for_spec(q, spec)
    v = field.value
    if occursin("/resource_ports/", spec.field_path) && endswith(spec.field_path, "/port_id")
        m = _n06_path_index(spec.field_path, "resource_ports")
        m === nothing && return (:fail_closed, :invalid_ref, "resource_port_path_invalid")
        idx = parse(Int, m.captures[1]) + 1
        idx <= length(q.network.resource_ports) ||
            return (:fail_closed, :invalid_ref, "resource_port_path_out_of_bounds")
        actual = q.network.resource_ports[idx]
        v isa N06TextValueV1 && v.value == actual.port_id ||
            return (:fail_closed, :invalid_ref, "resource_port_not_source_backed")
    elseif occursin("/entries/", spec.field_path) && endswith(spec.field_path, "/account_id")
        m = _n06_path_index(spec.field_path, "entries")
        m === nothing && return (:fail_closed, :invalid_ref, "entry_path_invalid")
        idx = parse(Int, m.captures[1]) + 1
        idx <= length(q.network.entries) ||
            return (:fail_closed, :invalid_ref, "entry_path_out_of_bounds")
        actual = q.network.entries[idx]
        v isa N06TextValueV1 && v.value == actual.account_id ||
            return (:fail_closed, :invalid_ref, "entry_account_not_source_backed")
    elseif occursin("/links/", spec.field_path) && endswith(spec.field_path, "/resource_port_id")
        v isa N06TextValueV1 && v.value == _n06_field_for_spec(p, spec).value.value ||
            return (:fail_closed, :invalid_ref, "control_resource_link_not_source_backed")
        v.value in Tuple(x.port_id for x in q.network.resource_ports) ||
            return (:fail_closed, :invalid_ref, "control_resource_link_port_missing")
    elseif occursin("/closures/", spec.field_path) && endswith(spec.field_path, "/expected_balance")
        m = _n06_path_index(spec.field_path, "closures")
        m === nothing && return (:fail_closed, :invalid_closure, "closure_path_invalid")
        idx = parse(Int, m.captures[1]) + 1
        idx <= length(q.network.closures) ||
            return (:fail_closed, :invalid_closure, "closure_path_out_of_bounds")
        closure = q.network.closures[idx]
        expected = sum((e.coefficient for e in q.network.entries if e.account_id in closure.account_ids); init=0 // 1)
        v isa N06RationalValueV1 && v.value == expected ||
            return (:fail_closed, :invalid_closure, "closure_balance_mismatch")
    elseif occursin("/resource_ports/", spec.field_path) && endswith(spec.field_path, "/kind")
        m = _n06_path_index(spec.field_path, "resource_ports")
        m === nothing && return (:fail_closed, :invalid_kind, "resource_kind_path_invalid")
        idx = parse(Int, m.captures[1]) + 1
        idx <= length(q.network.resource_ports) ||
            return (:fail_closed, :invalid_kind, "resource_kind_path_out_of_bounds")
        actual = q.network.resource_ports[idx]
        allowed = (:effort, :flow, :load, :return, :heat_sink, :material)
        v isa N06SymbolValueV1 && v.value in allowed ||
            return (:fail_closed, :invalid_kind, "resource_kind_not_allowed")
        v.value == actual.kind ||
            return (:fail_closed, :invalid_kind, "resource_kind_changed_without_bound_unit")
    end
    (:terminal_deferred, :terminal_deferred, p.authority_gaps[1])
end

function _n06_projection_matches_package(package::CandidateStatePackageV5,
                                         e0::UP2CandidatePhysicalBindingV1,
                                         p::N06LedgerProjectionV1)
    expected = n06_projection_from_a(package, e0)
    checks = (
        p.candidate_ref == expected.candidate_ref,
        p.package_hash == expected.package_hash,
        p.e0_bound_input_hash == expected.e0_bound_input_hash,
        p.g1_ref == expected.g1_ref, p.g2_ref == expected.g2_ref,
        p.g3_ref == expected.g3_ref, p.g1_equation_id == expected.g1_equation_id,
        p.g1_occurrence_key == expected.g1_occurrence_key,
        p.g1_occurrence_keys == expected.g1_occurrence_keys,
        p.g1_closure_id == expected.g1_closure_id,
        p.g2_region_id == expected.g2_region_id,
        p.g2_boundary_face == expected.g2_boundary_face,
        p.g2_boundary_locator == expected.g2_boundary_locator,
        p.g3_selected_flow_link_id == expected.g3_selected_flow_link_id,
        canonical_hash(p.network) == canonical_hash(expected.network),
        canonical_hash(p.fields) == canonical_hash(expected.fields),
        p.authority_gaps == expected.authority_gaps,
        p.projection_hash == expected.projection_hash)
    all(checks) || throw(ArgumentError("N06 detached or foreign projection identity"))
    p
end

function n06_validate_mutation(package::CandidateStatePackageV5,
                               e0::UP2CandidatePhysicalBindingV1,
                               p::N06LedgerProjectionV1,
                               spec::N06MutationSpecV1;
                               counter=N06InvocationCounterV1())
    _n06_projection_matches_package(package, e0, p)
    field = _n06_validate_spec_binding(p, spec)
    q = _n06_mutate(p, package, spec)
    classification = _n06_classify(p, q, spec)
    status, code, detail = classification
    result_hash = canonical_hash((mutation_id=spec.id, input_hash=p.projection_hash,
        mutated_input_hash=q.projection_hash, status=status, error_code=code,
        error_path=spec.field_path, detail=detail, original=field.value,
        mutated=_n06_field_for_spec(q, spec).value, counters=counter))
    N06ValidationResultV1(spec.id, p.projection_hash, q.projection_hash, status, code,
        spec.field_path, detail, status === :terminal_deferred ? detail : nothing,
        field.value, _n06_field_for_spec(q, spec).value, counter.compile_calls,
        counter.provider_calls, counter.solver_calls, result_hash)
end

function n06_mapping_admission(package::CandidateStatePackageV5,
                               e0::UP2CandidatePhysicalBindingV1,
                               mapping::Union{Nothing,N06SourceFieldLedgerMappingV1}=nothing)
    projection = n06_projection_from_a(package, e0)
    mapping === nothing && return (status=:terminal_deferred,
        errors=projection.authority_gaps, projection=projection,
        compile_calls=0, provider_calls=0, solver_calls=0)
    mapping.candidate_ref == package.candidate_ref ||
        return (status=:fail_closed, errors=("candidate_ref_mismatch",), projection=projection,
            compile_calls=0, provider_calls=0, solver_calls=0)
    mapping.package_hash == package.candidate_hash && mapping.e0_bound_input_hash == e0.bound_input_hash ||
        return (status=:fail_closed, errors=("e0_identity_mismatch",), projection=projection,
            compile_calls=0, provider_calls=0, solver_calls=0)
    mapping.g1_ref == package.g1.contract_ref && mapping.g2_ref == package.g2.contract_ref &&
        mapping.g3_ref == package.g3.contract_binding.contract_ref ||
        return (status=:fail_closed, errors=("component_ref_mismatch",), projection=projection,
            compile_calls=0, provider_calls=0, solver_calls=0)
    mapping.version_axes == package.version_axes ||
        return (status=:fail_closed, errors=("version_axes_mismatch",), projection=projection,
            compile_calls=0, provider_calls=0, solver_calls=0)
    mapping.schema_hash == n06_schema_hash() &&
        mapping.canonicalization_hash == n06_canonicalization_hash() &&
        mapping.profile_hash == n06_profile_hash() ||
        return (status=:fail_closed, errors=("mapping_contract_hash_mismatch",), projection=projection,
            compile_calls=0, provider_calls=0, solver_calls=0)
    mapping.mapping_hash == _n06_mapping_hash(mapping) ||
        return (status=:fail_closed, errors=("mapping_hash_mismatch",), projection=projection,
            compile_calls=0, provider_calls=0, solver_calls=0)
    errors = _n06_join_errors(package, mapping.joins; projection=projection)
    isempty(errors) || return (status=:fail_closed, errors=Tuple(errors), projection=projection,
        compile_calls=0, provider_calls=0, solver_calls=0)
    # The current A package has no authoritative G1 semantic source/field/
    # return/heat event mapping. Exact local joins therefore remain deferred;
    # a later trusted factory may close this gap after supplying that source.
    (status=:terminal_deferred,
        errors=("n06_source_field_return_heat_semantics_unverified",), projection=projection,
        mapping=mapping, compile_calls=0, provider_calls=0, solver_calls=0)
end
