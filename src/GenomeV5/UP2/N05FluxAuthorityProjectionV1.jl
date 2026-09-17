"""Candidate-owned, contract-only N05 flux authority projection.

The existing A package supplies the G1 occurrence and G2 interface context,
but it does not supply flux endpoints, signs, or dimensioned flux units.  This
file therefore accepts only an explicitly typed authored declaration.  The
declaration is a contract boundary; it is not a provider or physics result.
"""

const UP2N05_SCHEMA_SOURCE_V1 = """
schema_id=GenomeV5/UP2/N05FluxAuthorityProjectionV1
version=v1
fields=candidate_ref:QualifiedRefV1,package_hash:Digest256,g1_ref:GenomeContractRef,g2_ref:GenomeContractRef,g3_ref:GenomeContractRef,version_axes:NamedTuple,law_kind:enum(flux|traction|current),law:UP2N05FluxLawV1,interface_ref:QualifiedRefV1,left_endpoint:UP2N05FluxEndpointV1,right_endpoint:UP2N05FluxEndpointV1,left_occurrence:UP2N05OccurrenceLocatorV1,right_occurrence:UP2N05OccurrenceLocatorV1,declaration_hash:Digest256
constraints=exact actual A candidate/package/outer refs/component hashes/axes; endpoint and UnitSignature provenance are authored typed values; G2 normal is geometry only; no compiler/provider/solver
"""
const UP2N05_CANONICAL_SOURCE_V1 = "UP2N05 canonical v1: ordered semantic fields and exact Rational/UnitSignature/ref values"
const UP2N05_PROFILE_SOURCE_V1 = "UP2N05 applicability v1: candidate-bound contract-only declaration; missing authority terminal_deferred; typed contradiction fail_closed"

const UP2N05_SCHEMA_HASH_V1 = digest256_text(UP2N05_SCHEMA_SOURCE_V1)
const UP2N05_CANONICAL_HASH_V1 = digest256_text(UP2N05_CANONICAL_SOURCE_V1)
const UP2N05_PROFILE_HASH_V1 = digest256_text(UP2N05_PROFILE_SOURCE_V1)

const UP2N05_MISSING_AUTHORITY_GAPS_V1 = (
    "N05-01_terminal_deferred:missing_left_endpoint_authority",
    "N05-02_terminal_deferred:missing_right_endpoint_authority",
    "N05-03_terminal_deferred:missing_flux_law_or_left_sign_authority",
    "N05-04_terminal_deferred:missing_flux_law_or_right_sign_authority",
    "N05-05_terminal_deferred:missing_endpoint_unit_provenance")

abstract type UP2N05TypedValueV1 end
struct UP2N05RefValueV1 <: UP2N05TypedValueV1; value::QualifiedRefV1; end
struct UP2N05IntValueV1 <: UP2N05TypedValueV1; value::Int8; end
struct UP2N05UnitValueV1 <: UP2N05TypedValueV1; value::UnitSignature; end
semantic_view(x::UP2N05RefValueV1) = (kind=:ref, value=x.value)
semantic_view(x::UP2N05IntValueV1) = (kind=:int8, value=x.value)
semantic_view(x::UP2N05UnitValueV1) = (kind=:unit, value=x.value)

struct UP2N05SourceLocatorV1
    layer::Symbol
    path::String
    source_ref::Union{GenomeContractRef,QualifiedRefV1}
    source_hash::Digest256
    source_type::Symbol
    function UP2N05SourceLocatorV1(layer::Symbol, path::AbstractString,
                                   source_ref::Union{GenomeContractRef,QualifiedRefV1},
                                   source_hash::Digest256, source_type::Symbol)
        layer in (:G1, :G2, :N05) || throw(ArgumentError("N05 locator layer must be G1, G2, or N05"))
        !isempty(String(path)) || throw(ArgumentError("N05 locator path cannot be empty"))
        new(layer, String(path), source_ref, source_hash, source_type)
    end
end
semantic_view(x::UP2N05SourceLocatorV1) = (layer=x.layer, path=x.path,
    source_ref=x.source_ref, source_hash=x.source_hash, source_type=x.source_type)

struct UP2N05OccurrenceLocatorV1
    equation_id::String
    port_side::Symbol
    port_index::Int
    ledger_id::String
    # Provenance for the authored locator.  The actual G1 occurrence is a
    # G1LedgerOccurrenceV2 and deliberately has no `.source` field; validation
    # joins it by the full four-field occurrence key below.
    locator::UP2N05SourceLocatorV1
    function UP2N05OccurrenceLocatorV1(equation_id::AbstractString, port_side::Symbol,
                                       port_index::Integer, ledger_id::AbstractString,
                                       locator::UP2N05SourceLocatorV1)
        port_side in (:input, :output) || throw(ArgumentError("N05 occurrence side invalid"))
        port_index > 0 || throw(ArgumentError("N05 occurrence index must be positive"))
        !isempty(String(equation_id)) && !isempty(String(ledger_id)) ||
            throw(ArgumentError("N05 occurrence identifiers cannot be empty"))
        locator.layer === :G1 || throw(ArgumentError("N05 occurrence locator must be G1"))
        new(String(equation_id), port_side, Int(port_index), String(ledger_id), locator)
    end
end
semantic_view(x::UP2N05OccurrenceLocatorV1) = (equation_id=x.equation_id,
    port_side=x.port_side, port_index=x.port_index, ledger_id=x.ledger_id, locator=x.locator)

struct UP2N05UnitProvenanceV1
    unit::UnitSignature
    source::UP2N05SourceLocatorV1
    status::Symbol
    function UP2N05UnitProvenanceV1(unit::UnitSignature, source::UP2N05SourceLocatorV1,
                                    status::Symbol)
        status in (:authoritative, :unverified) ||
            throw(ArgumentError("N05 unit provenance status invalid"))
        new(unit, source, status)
    end
end
semantic_view(x::UP2N05UnitProvenanceV1) = (unit=x.unit, source=x.source, status=x.status)

struct UP2N05FluxEndpointV1
    endpoint_ref::QualifiedRefV1
    port_id::String
    side::Symbol
    sign::Int8
    unit::UP2N05UnitProvenanceV1
    occurrence::UP2N05OccurrenceLocatorV1
    function UP2N05FluxEndpointV1(endpoint_ref::QualifiedRefV1, port_id::AbstractString,
                                  side::Symbol, sign::Integer,
                                  unit::UP2N05UnitProvenanceV1,
                                  occurrence::UP2N05OccurrenceLocatorV1)
        endpoint_ref.version == "v1" || throw(ArgumentError("N05 endpoint ref must use v1"))
        !isempty(String(endpoint_ref.id)) && !isempty(String(port_id)) ||
            throw(ArgumentError("N05 endpoint identifiers cannot be empty"))
        side in (:left, :right) || throw(ArgumentError("N05 endpoint side invalid"))
        sign isa Integer && !(sign isa Bool) || throw(ArgumentError("N05 endpoint sign must be an integer"))
        occurrence.port_side in (:input, :output) || throw(ArgumentError("N05 endpoint occurrence invalid"))
        new(endpoint_ref, String(port_id), side, Int8(sign), unit, occurrence)
    end
end
semantic_view(x::UP2N05FluxEndpointV1) = (endpoint_ref=x.endpoint_ref,
    port_id=x.port_id, side=x.side, sign=x.sign, unit=x.unit, occurrence=x.occurrence)

struct UP2N05LawExpressionV1
    operator::Symbol
    left_port::String
    right_port::String
    relation::Symbol
    function UP2N05LawExpressionV1(operator::Symbol, left_port::AbstractString,
                                   right_port::AbstractString, relation::Symbol)
        operator in (:signed_transfer, :oriented_transfer) ||
            throw(ArgumentError("N05 law operator invalid"))
        relation in (:antisymmetric_transfer,) ||
            throw(ArgumentError("N05 law relation invalid"))
        !isempty(String(left_port)) && !isempty(String(right_port)) ||
            throw(ArgumentError("N05 law ports cannot be empty"))
        new(operator, String(left_port), String(right_port), relation)
    end
end
semantic_view(x::UP2N05LawExpressionV1) = (operator=x.operator, left_port=x.left_port,
    right_port=x.right_port, relation=x.relation)

function _n05_law_id(candidate_ref::QualifiedRefV1, interface_ref::QualifiedRefV1)
    "fusionconceptai://GenomeV5/UP2/N05/" * candidate_ref.id * "/" * interface_ref.id * "/law"
end

function _n05_law_source_hash(law_ref::QualifiedRefV1, expression::UP2N05LawExpressionV1,
                              left_sign::Integer, right_sign::Integer, unit::UnitSignature)
    canonical_hash((law_ref=law_ref, expression=expression, left_sign=left_sign,
        right_sign=right_sign, unit=unit))
end

function _n05_occurrence_key(occurrence)
    (equation_id=occurrence.equation_id, port_side=occurrence.port_side,
     port_index=occurrence.port_index, ledger_id=occurrence.ledger_id)
end

function _n05_occurrence_path(occurrence)
    "/g1/payload/equation_plan/equations/$(occurrence.equation_id)/occurrences/$(occurrence.port_side)/$(occurrence.port_index)/ledger/$(occurrence.ledger_id)"
end

function _n05_unique_interface(interfaces, interface_ref)
    matches = [i for i in interfaces if i.interface_ref == interface_ref]
    length(matches) == 1 ? only(matches) : nothing
end

struct UP2N05FluxLawV1
    law_ref::QualifiedRefV1
    kind::Symbol
    expression::UP2N05LawExpressionV1
    left_sign::Int8
    right_sign::Int8
    unit::UnitSignature
    source::UP2N05SourceLocatorV1
    law_hash::Digest256
    function UP2N05FluxLawV1(law_ref::QualifiedRefV1, kind::Symbol,
            expression::UP2N05LawExpressionV1, left_sign::Integer, right_sign::Integer,
            unit::UnitSignature, source::UP2N05SourceLocatorV1)
        law_ref.version == "v1" || throw(ArgumentError("N05 law ref must use v1"))
        kind in (:flux, :traction, :current) || throw(ArgumentError("N05 law kind invalid"))
        source.layer === :N05 && source.source_ref == law_ref &&
            source.source_type === :AuthoredFluxLawV1 ||
            throw(ArgumentError("N05 law source is not authored"))
        body_hash = _n05_law_source_hash(law_ref, expression, left_sign, right_sign, unit)
        new(law_ref, kind, expression, Int8(left_sign), Int8(right_sign), unit, source,
            body_hash)
    end
end
semantic_view(x::UP2N05FluxLawV1) = (law_ref=x.law_ref, kind=x.kind,
    expression=x.expression, left_sign=x.left_sign, right_sign=x.right_sign,
    unit=x.unit, source=x.source, law_hash=x.law_hash)

struct UP2N05FluxDeclarationV1
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    g1_ref::GenomeContractRef
    g2_ref::GenomeContractRef
    g3_ref::GenomeContractRef
    version_axes::NamedTuple
    law_kind::Symbol
    law::UP2N05FluxLawV1
    interface_ref::QualifiedRefV1
    left_region_id::String
    right_region_id::String
    left_endpoint::UP2N05FluxEndpointV1
    right_endpoint::UP2N05FluxEndpointV1
    declaration_hash::Digest256
    function UP2N05FluxDeclarationV1(candidate_ref::QualifiedRefV1,
            package_hash::Digest256, g1_ref::GenomeContractRef, g2_ref::GenomeContractRef,
            g3_ref::GenomeContractRef, version_axes::NamedTuple, law_kind::Symbol,
            law::UP2N05FluxLawV1, interface_ref::QualifiedRefV1, left_region_id::AbstractString,
            right_region_id::AbstractString, left_endpoint::UP2N05FluxEndpointV1,
            right_endpoint::UP2N05FluxEndpointV1)
        candidate_ref.version == "v5" || throw(ArgumentError("N05 candidate ref must use v5"))
        law_kind in (:flux, :traction, :current) || throw(ArgumentError("N05 law kind invalid"))
        law.kind == law_kind || throw(ArgumentError("N05 law kind mismatch"))
        interface_ref.version == "v2" || throw(ArgumentError("N05 interface child ref must use v2"))
        left_endpoint.side === :left && right_endpoint.side === :right ||
            throw(ArgumentError("N05 endpoint sides are not ordered"))
        left_endpoint.occurrence.locator.layer === :G1 && right_endpoint.occurrence.locator.layer === :G1 ||
            throw(ArgumentError("N05 endpoint occurrence source must be G1"))
        left_endpoint.unit.status === :authoritative && right_endpoint.unit.status === :authoritative ||
            throw(ArgumentError("N05 authored declaration requires authoritative unit provenance"))
        body = (candidate_ref=candidate_ref, package_hash=package_hash, g1_ref=g1_ref,
            g2_ref=g2_ref, g3_ref=g3_ref, version_axes=version_axes, law_kind=law_kind,
            law=law,
            interface_ref=interface_ref, left_region_id=String(left_region_id),
            right_region_id=String(right_region_id), left_endpoint=left_endpoint,
            right_endpoint=right_endpoint)
        new(candidate_ref, package_hash, g1_ref, g2_ref, g3_ref, version_axes, law_kind, law,
            interface_ref, String(left_region_id), String(right_region_id), left_endpoint,
            right_endpoint, canonical_hash(body))
    end
end
semantic_view(x::UP2N05FluxDeclarationV1) = (candidate_ref=x.candidate_ref,
    package_hash=x.package_hash, g1_ref=x.g1_ref, g2_ref=x.g2_ref, g3_ref=x.g3_ref,
    version_axes=x.version_axes, law_kind=x.law_kind, law=x.law, interface_ref=x.interface_ref,
    left_region_id=x.left_region_id, right_region_id=x.right_region_id,
    left_endpoint=x.left_endpoint, right_endpoint=x.right_endpoint,
    declaration_hash=x.declaration_hash)

struct UP2N05AuthorityV1
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    g1_ref::GenomeContractRef
    g2_ref::GenomeContractRef
    g3_ref::GenomeContractRef
    g1_component_hash::Digest256
    g2_component_hash::Digest256
    g3_component_hash::Digest256
    version_axes::NamedTuple
    declaration::Union{Nothing,UP2N05FluxDeclarationV1}
    schema_hash::Digest256
    canonicalization_hash::Digest256
    profile_hash::Digest256
    binding_hash::Digest256
    gaps::Tuple{Vararg{String}}
    resolution::Symbol
end
semantic_view(x::UP2N05AuthorityV1) = (candidate_ref=x.candidate_ref,
    package_hash=x.package_hash, g1_ref=x.g1_ref, g2_ref=x.g2_ref, g3_ref=x.g3_ref,
    g1_component_hash=x.g1_component_hash, g2_component_hash=x.g2_component_hash,
    g3_component_hash=x.g3_component_hash, version_axes=x.version_axes,
    declaration=x.declaration, schema_hash=x.schema_hash,
    canonicalization_hash=x.canonicalization_hash, profile_hash=x.profile_hash,
    binding_hash=x.binding_hash, gaps=x.gaps, resolution=x.resolution)

struct UP2N05MutationSpecV1
    id::String
    field_path::String
    mutation_kind::Symbol
    expected_error::Symbol
    expected_resolution::Symbol
end

struct UP2N05MutationReceiptV1
    id::String
    baseline_package_hash::Digest256
    source_locator::UP2N05SourceLocatorV1
    source_type::Symbol
    original_value::UP2N05TypedValueV1
    mutated_value::UP2N05TypedValueV1
    original_value_hash::Digest256
    mutated_value_hash::Digest256
    declaration_hash::Digest256
    mutation_hash::Digest256
    error_code::Symbol
    error_path::String
    resolution::Symbol
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
end

function _n05_endpoint_id(candidate_ref::QualifiedRefV1, interface_ref::QualifiedRefV1, side::Symbol)
    "fusionconceptai://GenomeV5/UP2/N05/" * candidate_ref.id * "/" * interface_ref.id * "/" * String(side)
end

function _n05_authored_unit_path(endpoint_ref::QualifiedRefV1)
    "/n05/authored_flux_law/endpoint/$(endpoint_ref.id)/unit"
end

function _n05_authored_unit_source(endpoint_ref::QualifiedRefV1, unit::UnitSignature)
    UP2N05SourceLocatorV1(:N05,
        _n05_authored_unit_path(endpoint_ref),
        endpoint_ref, canonical_hash((endpoint_ref=endpoint_ref, unit=unit)),
        :AuthoredFluxLawUnitV1)
end

function _n05_endpoint_source(endpoint::UP2N05FluxEndpointV1, field_path::String)
    UP2N05SourceLocatorV1(:N05, field_path, endpoint.endpoint_ref,
        canonical_hash((endpoint_ref=endpoint.endpoint_ref, port_id=endpoint.port_id,
                        side=endpoint.side, sign=endpoint.sign,
                        occurrence=endpoint.occurrence)), :AuthoredFluxEndpointV1)
end

const UP2N05_MUTATION_BINDINGS_V1 = (
    (field_path="/n05/left_endpoint/endpoint_ref", mutation_kind=:foreign_left_endpoint_ref,
        target=:left_endpoint_ref, source_type=:AuthoredFluxEndpointV1),
    (field_path="/n05/right_endpoint/endpoint_ref", mutation_kind=:foreign_right_endpoint_ref,
        target=:right_endpoint_ref, source_type=:AuthoredFluxEndpointV1),
    (field_path="/n05/left_endpoint/sign", mutation_kind=:left_sign_zero,
        target=:left_sign, source_type=:AuthoredFluxEndpointV1),
    (field_path="/n05/right_endpoint/sign", mutation_kind=:same_endpoint_sign,
        target=:right_sign, source_type=:AuthoredFluxEndpointV1),
    (field_path="/n05/right_endpoint/unit", mutation_kind=:right_unit_mismatch,
        target=:right_unit, source_type=:AuthoredFluxLawUnitV1))

function _n05_mutation_binding(spec::UP2N05MutationSpecV1)
    for binding in UP2N05_MUTATION_BINDINGS_V1
        binding.field_path == spec.field_path && binding.mutation_kind === spec.mutation_kind &&
            return binding
    end
    throw(ArgumentError("N05 mutation field_path/mutation_kind is not registered"))
end

function _n05_binding_hash(candidate_ref, package_hash, g1_ref, g2_ref, g3_ref,
                           g1_component_hash, g2_component_hash, g3_component_hash,
                           axes, declaration, schema_hash, canonical_hash_value, profile_hash, gaps)
    canonical_hash((candidate_ref=candidate_ref, package_hash=package_hash, g1_ref=g1_ref,
        g2_ref=g2_ref, g3_ref=g3_ref, g1_component_hash=g1_component_hash,
        g2_component_hash=g2_component_hash, g3_component_hash=g3_component_hash,
        version_axes=axes, declaration=declaration, schema_hash=schema_hash,
        canonicalization_hash=canonical_hash_value, profile_hash=profile_hash, gaps=gaps))
end

function _n05_package_fields(package::CandidateStatePackageV5)
    package.candidate_ref, package.candidate_hash, package.g1.contract_ref,
        package.g2.contract_ref, package.g3.contract_binding.contract_ref,
        package.g1.candidate_hash, package.g2.candidate_hash, package.g3.candidate_hash,
        package.version_axes
end

function _n05_authority_errors(package::CandidateStatePackageV5, declaration::UP2N05FluxDeclarationV1)
    errors = String[]
    candidate_ref, package_hash, g1_ref, g2_ref, g3_ref, g1_hash, g2_hash, g3_hash, axes = _n05_package_fields(package)
    declaration.candidate_ref == candidate_ref || push!(errors, "candidate_ref_mismatch")
    declaration.package_hash == package_hash || push!(errors, "package_hash_mismatch")
    declaration.g1_ref == g1_ref || push!(errors, "G1_ref_mismatch")
    declaration.g2_ref == g2_ref || push!(errors, "G2_ref_mismatch")
    declaration.g3_ref == g3_ref || push!(errors, "G3_ref_mismatch")
    declaration.version_axes == axes || push!(errors, "version_axes_mismatch")
    canonical_hash((candidate_ref=declaration.candidate_ref, package_hash=declaration.package_hash,
        g1_ref=declaration.g1_ref, g2_ref=declaration.g2_ref, g3_ref=declaration.g3_ref,
        version_axes=declaration.version_axes, law_kind=declaration.law_kind,
        law=declaration.law, interface_ref=declaration.interface_ref,
        left_region_id=declaration.left_region_id, right_region_id=declaration.right_region_id,
        left_endpoint=declaration.left_endpoint, right_endpoint=declaration.right_endpoint)) ==
        declaration.declaration_hash || push!(errors, "declaration_hash_mismatch")
    declaration.law.kind == declaration.law_kind || push!(errors, "law_kind_mismatch")
    declaration.law.law_ref.id == _n05_law_id(candidate_ref, declaration.interface_ref) ||
        push!(errors, "law_ref_mismatch")
    declaration.law.source.layer === :N05 || push!(errors, "law_source_layer_mismatch")
    declaration.law.source.source_ref == declaration.law.law_ref ||
        push!(errors, "law_source_ref_mismatch")
    declaration.law.source.source_type === :AuthoredFluxLawV1 ||
        push!(errors, "law_source_type_mismatch")
    declaration.law.source.path == "/n05/authored_flux_law/$(declaration.law.law_ref.id)" ||
        push!(errors, "law_source_path_mismatch")
    declaration.law.source.source_hash == _n05_law_source_hash(declaration.law.law_ref,
        declaration.law.expression, declaration.law.left_sign, declaration.law.right_sign,
        declaration.law.unit) || push!(errors, "law_source_hash_mismatch")
    declaration.law.law_hash == _n05_law_source_hash(declaration.law.law_ref,
        declaration.law.expression, declaration.law.left_sign, declaration.law.right_sign,
        declaration.law.unit) || push!(errors, "law_hash_mismatch")
    interface = _n05_unique_interface(package.g2.region_interface.interfaces,
        declaration.interface_ref)
    interface === nothing && push!(errors, "interface_ref_mismatch")
    if interface !== nothing
        declaration.left_region_id == interface.left_region_id || push!(errors, "left_region_mismatch")
        declaration.right_region_id == interface.right_region_id || push!(errors, "right_region_mismatch")
    end
    declaration.left_endpoint.endpoint_ref.id == _n05_endpoint_id(candidate_ref, declaration.interface_ref, :left) ||
        push!(errors, "left_endpoint_ref_mismatch")
    declaration.right_endpoint.endpoint_ref.id == _n05_endpoint_id(candidate_ref, declaration.interface_ref, :right) ||
        push!(errors, "right_endpoint_ref_mismatch")
    declaration.left_endpoint.sign in (-1, 1) || push!(errors, "left_sign_invalid")
    declaration.right_endpoint.sign in (-1, 1) || push!(errors, "right_sign_invalid")
    declaration.left_endpoint.sign == -declaration.right_endpoint.sign || push!(errors, "endpoint_signs_not_opposite")
    declaration.law.left_sign == declaration.left_endpoint.sign || push!(errors, "left_sign_law_mismatch")
    declaration.law.right_sign == declaration.right_endpoint.sign || push!(errors, "right_sign_law_mismatch")
    declaration.law.expression.left_port == declaration.left_endpoint.port_id ||
        push!(errors, "left_port_law_mismatch")
    declaration.law.expression.right_port == declaration.right_endpoint.port_id ||
        push!(errors, "right_port_law_mismatch")
    declaration.law.expression.relation === :antisymmetric_transfer ||
        push!(errors, "law_relation_invalid")
    declaration.left_endpoint.unit.status === :authoritative && declaration.right_endpoint.unit.status === :authoritative ||
        push!(errors, "unit_provenance_missing")
    declaration.left_endpoint.unit.unit == declaration.right_endpoint.unit.unit ||
        push!(errors, "endpoint_unit_mismatch")
    declaration.law.unit == declaration.left_endpoint.unit.unit ||
        push!(errors, "law_unit_mismatch")
    for endpoint in (declaration.left_endpoint, declaration.right_endpoint)
        matches = [o for e in package.g1.payload.equation_plan.equations
                   for o in e.occurrences
                   if o.equation_id == endpoint.occurrence.equation_id &&
                      o.port_side == endpoint.occurrence.port_side &&
                      o.port_index == endpoint.occurrence.port_index &&
                      o.ledger_id == endpoint.occurrence.ledger_id]
        length(matches) == 1 || push!(errors, "G1_occurrence_not_unique:" * String(endpoint.side))
        occurrence = length(matches) == 1 ? only(matches) : nothing
        occurrence isa G1LedgerOccurrenceV2 || push!(errors, "G1_occurrence_type_mismatch:" * String(endpoint.side))
        endpoint.occurrence.locator.source_ref == g1_ref || push!(errors, "G1_occurrence_ref_mismatch:" * String(endpoint.side))
        endpoint.occurrence.locator.source_hash == g1_hash || push!(errors, "G1_occurrence_hash_mismatch:" * String(endpoint.side))
        expected_occurrence_path = _n05_occurrence_path(occurrence === nothing ? endpoint.occurrence : occurrence)
        endpoint.occurrence.locator.path == expected_occurrence_path ||
            push!(errors, "G1_occurrence_path_mismatch:" * String(endpoint.side))
        endpoint.occurrence.locator.source_type === :G1LedgerOccurrenceV2 ||
            push!(errors, "G1_occurrence_type_mismatch:" * String(endpoint.side))
        endpoint.unit.status === :authoritative || push!(errors, "flux_unit_authority_missing:" * String(endpoint.side))
        endpoint.unit.source.layer === :N05 || push!(errors, "flux_unit_source_layer_mismatch:" * String(endpoint.side))
        endpoint.unit.source.source_ref == endpoint.endpoint_ref ||
            push!(errors, "flux_unit_source_ref_mismatch:" * String(endpoint.side))
        endpoint.unit.source.source_type === :AuthoredFluxLawUnitV1 ||
            push!(errors, "flux_unit_source_type_mismatch:" * String(endpoint.side))
        endpoint.unit.source.path == _n05_authored_unit_path(endpoint.endpoint_ref) ||
            push!(errors, "flux_unit_source_path_mismatch:" * String(endpoint.side))
        endpoint.unit.source.source_hash == canonical_hash((endpoint_ref=endpoint.endpoint_ref,
            unit=endpoint.unit.unit)) || push!(errors, "flux_unit_source_hash_mismatch:" * String(endpoint.side))
    end
    _n05_occurrence_key(declaration.left_endpoint.occurrence) ==
        _n05_occurrence_key(declaration.right_endpoint.occurrence) &&
        push!(errors, "G1_occurrences_not_independent")
    errors
end

function _n05_e0_status(binding::UP2CandidatePhysicalBindingV1,
                        package::CandidateStatePackageV5)
    try
        result = up2e0_validate_binding(binding, package)
        result.status === :valid && return (:valid, String[])
        result.status === :program_exception &&
            return (:program_exception, String["E0_program_exception", result.errors...])
        return (:fail_closed, String["E0_source_contradiction", result.errors...])
    catch err
        return (:program_exception,
            String["E0_program_exception:" * sprint(showerror, err)])
    end
end

function up2n05_authority_from_a(package::CandidateStatePackageV5,
                                 e0_binding::UP2CandidatePhysicalBindingV1;
                                 declaration::Union{Nothing,UP2N05FluxDeclarationV1}=nothing)
    e0_status, e0_errors = _n05_e0_status(e0_binding, package)
    candidate_ref, package_hash, g1_ref, g2_ref, g3_ref, g1_hash, g2_hash, g3_hash, axes = _n05_package_fields(package)
    gaps = e0_status === :valid ?
        (declaration === nothing ? UP2N05_MISSING_AUTHORITY_GAPS_V1 : ()) : Tuple(e0_errors)
    declaration_errors = String[]
    declaration_exception = nothing
    if declaration !== nothing
        try
            declaration_errors = _n05_authority_errors(package, declaration)
        catch err
            declaration_exception = "N05_program_exception:" * sprint(showerror, err)
        end
    end
    binding_hash = _n05_binding_hash(candidate_ref, package_hash, g1_ref, g2_ref, g3_ref,
        g1_hash, g2_hash, g3_hash, axes, declaration, UP2N05_SCHEMA_HASH_V1,
        UP2N05_CANONICAL_HASH_V1, UP2N05_PROFILE_HASH_V1, gaps)
    UP2N05AuthorityV1(candidate_ref, package_hash, g1_ref, g2_ref, g3_ref, g1_hash,
        g2_hash, g3_hash, axes, declaration, UP2N05_SCHEMA_HASH_V1,
        UP2N05_CANONICAL_HASH_V1, UP2N05_PROFILE_HASH_V1, binding_hash, gaps,
        e0_status === :program_exception || declaration_exception !== nothing ? :program_exception :
        e0_status !== :valid ? :fail_closed :
        declaration === nothing ? :terminal_deferred : isempty(declaration_errors) ? :contract_ready : :fail_closed)
end

function up2n05_validate(authority::UP2N05AuthorityV1, package::CandidateStatePackageV5,
                         e0_binding::UP2CandidatePhysicalBindingV1)
    errors = String[]
    e0_status, e0_errors = _n05_e0_status(e0_binding, package)
    e0_status === :program_exception &&
        return (status=:program_exception, errors=Tuple(e0_errors), compile_calls=0,
            provider_calls=0, solver_calls=0)
    e0_status === :valid || append!(errors, e0_errors)
    candidate_ref, package_hash, g1_ref, g2_ref, g3_ref, g1_hash, g2_hash, g3_hash, axes = _n05_package_fields(package)
    authority.candidate_ref == candidate_ref || push!(errors, "source_candidate_ref_mismatch")
    authority.package_hash == package_hash || push!(errors, "source_package_hash_mismatch")
    authority.g1_ref == g1_ref || push!(errors, "source_G1_ref_mismatch")
    authority.g2_ref == g2_ref || push!(errors, "source_G2_ref_mismatch")
    authority.g3_ref == g3_ref || push!(errors, "source_G3_ref_mismatch")
    authority.version_axes == axes || push!(errors, "source_version_axes_mismatch")
    authority.resolution === :program_exception &&
        return (status=:program_exception, errors=("N05_program_exception:authority_source",),
            compile_calls=0, provider_calls=0, solver_calls=0)
    authority.binding_hash == _n05_binding_hash(authority.candidate_ref, authority.package_hash,
        authority.g1_ref, authority.g2_ref, authority.g3_ref, authority.g1_component_hash,
        authority.g2_component_hash, authority.g3_component_hash, authority.version_axes,
        authority.declaration, authority.schema_hash, authority.canonicalization_hash,
        authority.profile_hash, authority.gaps) || push!(errors, "binding_hash_mismatch")
    if authority.declaration === nothing
        Tuple(authority.gaps) == UP2N05_MISSING_AUTHORITY_GAPS_V1 || push!(errors, "missing_authority_gap_set_mismatch")
        return (status=e0_status !== :valid ? :fail_closed : isempty(errors) ? :terminal_deferred : :fail_closed,
            errors=Tuple(errors), compile_calls=0, provider_calls=0, solver_calls=0)
    end
    try
        append!(errors, _n05_authority_errors(package, authority.declaration))
    catch err
        return (status=:program_exception,
            errors=("N05_program_exception:" * sprint(showerror, err),),
            compile_calls=0, provider_calls=0, solver_calls=0)
    end
    isempty(errors) ? (status=:valid, errors=(), compile_calls=0, provider_calls=0, solver_calls=0) :
        (status=:fail_closed, errors=Tuple(unique(errors)), compile_calls=0, provider_calls=0, solver_calls=0)
end

function _n05_spec_value(authority::UP2N05AuthorityV1, spec::UP2N05MutationSpecV1)
    binding = _n05_mutation_binding(spec)
    d = authority.declaration
    d === nothing && return (UP2N05IntValueV1(0), UP2N05SourceLocatorV1(:G2, binding.field_path,
        authority.g2_ref, authority.g2_component_hash, :missing_authority))
    binding.target === :left_endpoint_ref && return (UP2N05RefValueV1(d.left_endpoint.endpoint_ref),
        _n05_endpoint_source(d.left_endpoint, binding.field_path))
    binding.target === :right_endpoint_ref && return (UP2N05RefValueV1(d.right_endpoint.endpoint_ref),
        _n05_endpoint_source(d.right_endpoint, binding.field_path))
    binding.target === :left_sign && return (UP2N05IntValueV1(d.left_endpoint.sign),
        _n05_endpoint_source(d.left_endpoint, binding.field_path))
    binding.target === :right_sign && return (UP2N05IntValueV1(d.right_endpoint.sign),
        _n05_endpoint_source(d.right_endpoint, binding.field_path))
    binding.target === :right_unit && return (UP2N05UnitValueV1(d.right_endpoint.unit.unit),
        d.right_endpoint.unit.source)
    throw(ArgumentError("N05 mutation target is not registered"))
end

function _n05_mutated_declaration(d::UP2N05FluxDeclarationV1, spec::UP2N05MutationSpecV1)
    binding = _n05_mutation_binding(spec)
    left = d.left_endpoint; right = d.right_endpoint
    if binding.target === :left_endpoint_ref
        foreign = QualifiedRefV1(left.endpoint_ref.id * "/foreign", "v1")
        left = UP2N05FluxEndpointV1(foreign, left.port_id, left.side, left.sign, left.unit, left.occurrence)
    elseif binding.target === :right_endpoint_ref
        foreign = QualifiedRefV1(right.endpoint_ref.id * "/foreign", "v1")
        right = UP2N05FluxEndpointV1(foreign, right.port_id, right.side, right.sign, right.unit, right.occurrence)
    elseif binding.target === :left_sign
        left = UP2N05FluxEndpointV1(left.endpoint_ref, left.port_id, left.side, 0, left.unit, left.occurrence)
    elseif binding.target === :right_sign
        right = UP2N05FluxEndpointV1(right.endpoint_ref, right.port_id, right.side, left.sign, right.unit, right.occurrence)
    elseif binding.target === :right_unit
        bad_unit = UnitSignature((1, 0, 0, 0, 0, 0, 0))
        bad_provenance = UP2N05UnitProvenanceV1(bad_unit,
            _n05_authored_unit_source(right.endpoint_ref, bad_unit), :authoritative)
        right = UP2N05FluxEndpointV1(right.endpoint_ref, right.port_id, right.side, right.sign, bad_provenance, right.occurrence)
    end
    UP2N05FluxDeclarationV1(d.candidate_ref, d.package_hash, d.g1_ref, d.g2_ref, d.g3_ref,
        d.version_axes, d.law_kind, d.law, d.interface_ref, d.left_region_id, d.right_region_id,
        left, right)
end

function up2n05_validate_mutation(authority::UP2N05AuthorityV1,
                                  package::CandidateStatePackageV5,
                                  e0_binding::UP2CandidatePhysicalBindingV1,
                                  spec::UP2N05MutationSpecV1)
    binding = _n05_mutation_binding(spec)
    # A mutation receipt is admissible only after the unmutated authority has
    # joined to this exact A package and its E0 source-bound input.  This keeps
    # foreign/stale authority and bad E0 inputs from producing formal-looking
    # receipts; the missing-declaration case is the sole deferred exception.
    baseline = up2n05_validate(authority, package, e0_binding)
    if authority.declaration === nothing
        baseline.status === :terminal_deferred ||
            throw(ArgumentError("N05 mutation baseline is $(baseline.status); no deferred receipt"))
    else
        baseline.status === :valid ||
            throw(ArgumentError("N05 mutation baseline is $(baseline.status); no mutation receipt"))
    end
    original, locator = _n05_spec_value(authority, spec)
    if authority.declaration !== nothing
        expected_source_path = binding.target === :right_unit ?
            _n05_authored_unit_path(authority.declaration.right_endpoint.endpoint_ref) : binding.field_path
        locator.path == expected_source_path || throw(ArgumentError("N05 mutation source path mismatch"))
        locator.source_type === binding.source_type || throw(ArgumentError("N05 mutation source type mismatch"))
    end
    if authority.declaration === nothing
        mutated = original
        return UP2N05MutationReceiptV1(spec.id, package.candidate_hash, locator,
            :missing_authority, original, mutated, canonical_hash(original),
            canonical_hash(mutated), Digest256(repeat("0", 64)), canonical_hash((id=spec.id, original=original, mutated=mutated)),
            :authority_gap, binding.field_path, :terminal_deferred, 0, 0, 0)
    end
    mutated_declaration = _n05_mutated_declaration(authority.declaration, spec)
    errors = _n05_authority_errors(package, mutated_declaration)
    isempty(errors) && throw(ArgumentError("N05 mutation did not violate a source invariant"))
    mutated = binding.target === :left_endpoint_ref ? UP2N05RefValueV1(mutated_declaration.left_endpoint.endpoint_ref) :
        binding.target === :right_endpoint_ref ? UP2N05RefValueV1(mutated_declaration.right_endpoint.endpoint_ref) :
        binding.target === :left_sign ? UP2N05IntValueV1(mutated_declaration.left_endpoint.sign) :
        binding.target === :right_sign ? UP2N05IntValueV1(mutated_declaration.right_endpoint.sign) :
        UP2N05UnitValueV1(mutated_declaration.right_endpoint.unit.unit)
    # Classify from the observed invariant errors.  Endpoint ref/port/sign or
    # interface contradictions take priority over secondary unit-provenance
    # errors caused by that same mutation; only a genuine unit contradiction is
    # an invalid type.  The fixture's expected label and the mutation id do not
    # participate in this decision.
    closure_markers = ("endpoint_ref_mismatch", "port_law_mismatch", "law_ref_mismatch",
        "interface_ref_mismatch", "region_mismatch", "sign_invalid",
        "signs_not_opposite", "sign_law_mismatch")
    unit_markers = ("unit_mismatch", "unit_provenance", "unit_source_")
    has_closure_error = any(any(contains(error, marker) for marker in closure_markers)
                            for error in errors)
    has_unit_error = any(any(contains(error, marker) for marker in unit_markers)
                         for error in errors)
    error_code = has_closure_error ? :invalid_closure :
        has_unit_error ? :invalid_type :
        throw(ArgumentError("N05 mutation errors have no registered classification: " * join(errors, ",")))
    UP2N05MutationReceiptV1(spec.id, package.candidate_hash, locator, :authored_typed,
        original, mutated, canonical_hash(original), canonical_hash(mutated),
        authority.declaration.declaration_hash,
        canonical_hash((id=spec.id, baseline=authority.declaration.declaration_hash, mutated=mutated)),
        error_code, binding.field_path, :fail_closed, 0, 0, 0)
end
