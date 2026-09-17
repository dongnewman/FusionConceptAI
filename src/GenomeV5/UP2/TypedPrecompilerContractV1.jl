"""Typed, contract-only precompiler input for UP2-00.

Values are source projections supplied by UP1-04A. They remain typed so
mutation validation can inspect cross-field invariants. No solver, mesh, or
provider is implemented here.
"""

const _UP2_SCHEMA_SOURCE_V1 = """
schema_id=GenomeV5/UP2/TypedPrecompilerContractV1
version=v2
fields=candidate_ref:QualifiedRefV1,g1_ref:GenomeContractRef,g2_ref:GenomeContractRef,g3_ref:GenomeContractRef,
package_hash:Digest256,mission_bounds_hash:Digest256,source_manifest_hash:Digest256,
typed_source_fields:Tuple[UP2SemanticFieldV1],g2_flux_pair:UP2FluxPairV1,claim_ceiling:ClaimCeiling
mutation=id:String,class:Symbol,field_path:String,source_locator:String,source_type:Symbol,
mutation_kind:Symbol,expected_error:Symbol,expected_resolution:ResolutionStatus,expected_provider_calls:Int
constraints=mutation changes a typed value; validator derives code/path from changed value and invariant;
N01 rank/dimension, N02 unit/normalization are value-checked; N05 paired flux binds a G2 interface_ref/regions/normal
but remains terminal_deferred until external flux port/unit provenance is authoritative;
N01-N08 compile/provider calls=0; N09 provider gap terminal_deferred; N10 no evidence reuse
"""

up2_schema_hash() = digest256_text(_UP2_SCHEMA_SOURCE_V1)

function _up2_bounds3(value, field)
    value isa Tuple && length(value) == 3 || throw(ArgumentError("$field must be a 3-tuple"))
    ntuple(i -> begin
        v = value[i]
        v isa Rational || v isa Integer || throw(ArgumentError("$field[$i] must be exact"))
        try Rational{Int64}(v) catch; throw(ArgumentError("$field[$i] is out of range")) end
    end, 3)
end

struct UP2MissionBoundsV1
    mission_id::String
    quantity::String
    unit::String
    coordinate_unit::String
    lower::NTuple{3,Rational{Int64}}
    upper::NTuple{3,Rational{Int64}}
    time_basis::Symbol
    function UP2MissionBoundsV1(mission_id::AbstractString, quantity::AbstractString,
            unit::AbstractString, coordinate_unit::AbstractString, lower::Any, upper::Any,
            time_basis::Any)
        all(x -> !isempty(String(x)), (mission_id, quantity, unit, coordinate_unit)) ||
            throw(ArgumentError("UP2 mission/bounds text fields cannot be empty"))
        lo = _up2_bounds3(lower, "mission lower"); hi = _up2_bounds3(upper, "mission upper")
        all(lo[i] < hi[i] for i in 1:3) || throw(ArgumentError("mission bounds are not ordered"))
        tb = time_basis isa Symbol ? time_basis : Symbol(time_basis)
        tb in (:static, :continuous, :discrete, :event) || throw(ArgumentError("invalid UP2 time basis"))
        new(String(mission_id), String(quantity), String(unit), String(coordinate_unit), lo, hi, tb)
    end
end

semantic_view(x::UP2MissionBoundsV1) =
    (mission_id=x.mission_id, quantity=x.quantity, unit=x.unit,
     coordinate_unit=x.coordinate_unit, lower=x.lower, upper=x.upper,
     time_basis=x.time_basis)

abstract type UP2TypedValueV1 end
struct UP2IntegerValueV1 <: UP2TypedValueV1; value::Int; end
struct UP2SymbolValueV1 <: UP2TypedValueV1; value::Symbol; end
struct UP2TextValueV1 <: UP2TypedValueV1; value::String; end
struct UP2RationalValueV1 <: UP2TypedValueV1; value::Rational{Int64}; end
struct UP2UnitValueV1 <: UP2TypedValueV1; value::UnitSignature; end
struct UP2HashValueV1 <: UP2TypedValueV1; value::Digest256; end
struct UP2RefValueV1 <: UP2TypedValueV1; value::QualifiedRefV1; end
struct UP2TupleValueV1 <: UP2TypedValueV1; values::Tuple; element_type::Symbol; end

semantic_view(x::UP2IntegerValueV1) = (kind=:integer, value=x.value)
semantic_view(x::UP2SymbolValueV1) = (kind=:symbol, value=x.value)
semantic_view(x::UP2TextValueV1) = (kind=:text, value=x.value)
semantic_view(x::UP2RationalValueV1) = (kind=:rational, value=x.value)
semantic_view(x::UP2UnitValueV1) = (kind=:unit, value=x.value)
semantic_view(x::UP2HashValueV1) = (kind=:hash, value=x.value)
semantic_view(x::UP2RefValueV1) = (kind=:ref, value=x.value)
semantic_view(x::UP2TupleValueV1) = (kind=:tuple, values=x.values, element_type=x.element_type)

struct UP2FluxPairV1
    pair_id::String
    left_port::String
    right_port::String
    left_sign::Int8
    right_sign::Int8
    unit::UnitSignature
    interface_ref::QualifiedRefV1
    left_region::String
    right_region::String
    normal::Int8
    transfer_kind::Symbol
    port_source::Symbol
    function UP2FluxPairV1(pair_id::AbstractString, left_port::AbstractString,
            right_port::AbstractString, left_sign::Any, right_sign::Any, unit::UnitSignature,
            interface_ref::QualifiedRefV1, left_region::AbstractString,
            right_region::AbstractString, normal::Any, transfer_kind::Any,
            port_source::Any)
        pair_id isa AbstractString && left_port isa AbstractString && right_port isa AbstractString ||
            throw(ArgumentError("UP2 flux pair endpoints must be strings"))
        left_sign isa Integer && right_sign isa Integer ||
            throw(ArgumentError("UP2 flux signs must be integers"))
        interface_ref.version in ("v2", "v5") || throw(ArgumentError("UP2 flux interface ref version is unsupported"))
        left_region isa AbstractString && right_region isa AbstractString ||
            throw(ArgumentError("UP2 flux pair regions must be strings"))
        normal isa Integer && abs(normal) == 1 || throw(ArgumentError("UP2 flux normal must be -1 or +1"))
        transfer_kind isa Symbol || throw(ArgumentError("UP2 flux transfer kind must be a Symbol"))
        port_source isa Symbol && port_source in (:authoritative, :unverified) ||
            throw(ArgumentError("UP2 flux port source must be authoritative or unverified"))
        new(String(pair_id), String(left_port), String(right_port), Int8(left_sign), Int8(right_sign), unit,
            interface_ref, String(left_region), String(right_region), Int8(normal), transfer_kind, port_source)
    end
end

function UP2FluxPairV1(pair_id::AbstractString, left_port::AbstractString,
        right_port::AbstractString, left_sign::Any, right_sign::Any, unit::UnitSignature)
    UP2FluxPairV1(pair_id, left_port, right_port, left_sign, right_sign, unit,
        QualifiedRefV1("fusionconceptai://GenomeV5/G2/interface/pending", "v5"),
        "pending-left", "pending-right", 1, :pending, :unverified)
end

semantic_view(x::UP2FluxPairV1) =
    (pair_id=x.pair_id, left_port=x.left_port, right_port=x.right_port,
     left_sign=x.left_sign, right_sign=x.right_sign, unit=x.unit,
     interface_ref=x.interface_ref, left_region=x.left_region,
     right_region=x.right_region, normal=x.normal, transfer_kind=x.transfer_kind,
     port_source=x.port_source)

up2_flux_pair_valid(x::UP2FluxPairV1) =
    !isempty(x.pair_id) && !isempty(x.left_port) && !isempty(x.right_port) &&
    x.left_port != x.right_port && abs(x.left_sign) == 1 && abs(x.right_sign) == 1 &&
    x.left_sign == -x.right_sign

struct UP2SemanticFieldV1
    id::String
    field_path::String
    source_locator::String
    source_type::Symbol
    value::UP2TypedValueV1
    function UP2SemanticFieldV1(id::AbstractString, field_path::AbstractString,
            source_locator::AbstractString, source_type::Any, value::UP2TypedValueV1)
        all(x -> !isempty(String(x)), (id, field_path, source_locator)) ||
            throw(ArgumentError("UP2 field identity cannot be empty"))
        new(String(id), String(field_path), String(source_locator), Symbol(source_type), value)
    end
end

semantic_view(x::UP2SemanticFieldV1) =
    (id=x.id, field_path=x.field_path, source_locator=x.source_locator,
     source_type=x.source_type, value=x.value)

struct UP2PrecompilerStateV1
    fields::Tuple{Vararg{UP2SemanticFieldV1}}
    flux_pair::UP2FluxPairV1
    state_hash::Digest256
    function UP2PrecompilerStateV1(fields::Any, flux_pair::UP2FluxPairV1)
        fields isa Tuple && !isempty(fields) || throw(ArgumentError("UP2 field set must be non-empty"))
        all(x -> x isa UP2SemanticFieldV1, fields) || throw(ArgumentError("UP2 fields are not typed"))
        ids = Tuple(x.id for x in fields); paths = Tuple(x.field_path for x in fields)
        length(unique(ids)) == length(ids) || throw(ArgumentError("UP2 field IDs must be unique"))
        length(unique(paths)) == length(paths) || throw(ArgumentError("UP2 field paths must be unique"))
        new(Tuple(fields), flux_pair, canonical_hash((fields=Tuple(fields), flux_pair=flux_pair)))
    end
end

semantic_view(x::UP2PrecompilerStateV1) =
    (fields=x.fields, flux_pair=x.flux_pair, state_hash=x.state_hash)

struct UP2AProjectionV1
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    fields::Tuple{Vararg{UP2SemanticFieldV1}}
    flux_pair::UP2FluxPairV1
    projection_hash::Digest256
    function UP2AProjectionV1(candidate_ref::QualifiedRefV1, package_hash::Digest256,
            fields::Any, flux_pair::UP2FluxPairV1)
        candidate_ref.version == "v5" || throw(ArgumentError("A projection candidate ref must be v5"))
        fields isa Tuple && length(fields) == 50 || throw(ArgumentError("A projection requires all 50 typed fields"))
        all(x -> x isa UP2SemanticFieldV1, fields) || throw(ArgumentError("A projection fields are not typed"))
        new(candidate_ref, package_hash, Tuple(fields), flux_pair,
            canonical_hash((candidate_ref=candidate_ref, package_hash=package_hash,
                fields=Tuple(fields), flux_pair=flux_pair)))
    end
end

semantic_view(x::UP2AProjectionV1) =
    (candidate_ref=x.candidate_ref, package_hash=x.package_hash, fields=x.fields,
     flux_pair=x.flux_pair, projection_hash=x.projection_hash)

struct UP2MutationSpecV1
    id::String
    class_id::Symbol
    field_path::String
    source_locator::String
    source_type::Symbol
    mutation_kind::Symbol
    expected_error::Symbol
    expected_resolution::ResolutionStatus
    expected_provider_calls::Int
    detail::String
    function UP2MutationSpecV1(id::AbstractString, class_id::Any, field_path::AbstractString,
            source_locator::AbstractString, source_type::Any, mutation_kind::Any,
            expected_error::Any, expected_resolution::ResolutionStatus,
            expected_provider_calls::Integer, detail::AbstractString)
        expected_provider_calls == 0 || throw(ArgumentError("UP2 mutations require zero provider calls"))
        e = Symbol(expected_error)
        e in (:invalid_type, :invalid_closure, :invalid_boundary, :provider_match, :terminal_deferred) ||
            throw(ArgumentError("UP2 error class is not registered"))
        new(String(id), Symbol(class_id), String(field_path), String(source_locator),
            Symbol(source_type), Symbol(mutation_kind), e, expected_resolution,
            Int(expected_provider_calls), String(detail))
    end
end

semantic_view(x::UP2MutationSpecV1) =
    (id=x.id, class_id=x.class_id, field_path=x.field_path,
     source_locator=x.source_locator, source_type=x.source_type, mutation_kind=x.mutation_kind,
     expected_error=x.expected_error, expected_resolution=x.expected_resolution,
     expected_provider_calls=x.expected_provider_calls, detail=x.detail)

struct UP2PrecompilerInputV1
    candidate_ref::QualifiedRefV1
    g1_ref::GenomeContractRef
    g2_ref::GenomeContractRef
    g3_ref::GenomeContractRef
    g1_hash::Digest256
    g2_hash::Digest256
    g3_hash::Digest256
    package_hash::Digest256
    mission_bounds::UP2MissionBoundsV1
    state::UP2PrecompilerStateV1
    source_manifest_hash::Digest256
    package_status::Symbol
    resolution::ResolutionStatus
    claim_ceiling::ClaimCeiling
    input_hash::Digest256
    function UP2PrecompilerInputV1(candidate_ref::QualifiedRefV1, g1_ref::GenomeContractRef,
            g2_ref::GenomeContractRef, g3_ref::GenomeContractRef, g1_hash::Digest256,
            g2_hash::Digest256, g3_hash::Digest256, package_hash::Digest256,
            mission_bounds::UP2MissionBoundsV1, state::UP2PrecompilerStateV1,
            source_manifest_hash::Digest256, package_status::Symbol,
            resolution::ResolutionStatus, claim_ceiling::ClaimCeiling)
        candidate_ref.version == "v5" || throw(ArgumentError("UP2 candidate ref must be v5"))
        startswith(g2_ref.uri, "fusionconceptai://GenomeV5/G2/") ||
            throw(ArgumentError("UP2 requires the new G2 public URI namespace"))
        all(x -> x.version == "v5", (g1_ref, g2_ref, g3_ref)) ||
            throw(ArgumentError("UP2 layer refs must be v5"))
        package_status === :a_limited || throw(ArgumentError("UP2 input requires A-limited package status"))
        resolution == terminal_deferred || throw(ArgumentError("UP2 input must preserve deferred gaps"))
        claim_ceiling == none || throw(ArgumentError("UP2 claim ceiling must remain none"))
        body = (candidate_ref=candidate_ref, g1_ref=g1_ref, g2_ref=g2_ref, g3_ref=g3_ref,
            g1_hash=g1_hash, g2_hash=g2_hash, g3_hash=g3_hash, package_hash=package_hash,
            mission_bounds=mission_bounds, state=state, source_manifest_hash=source_manifest_hash,
            package_status=package_status, resolution=resolution, claim_ceiling=claim_ceiling)
        new(candidate_ref, g1_ref, g2_ref, g3_ref, g1_hash, g2_hash, g3_hash, package_hash,
            mission_bounds, state, source_manifest_hash, package_status, resolution, claim_ceiling,
            canonical_hash(body))
    end
end

semantic_view(x::UP2PrecompilerInputV1) =
    (candidate_ref=x.candidate_ref, g1_ref=x.g1_ref, g2_ref=x.g2_ref, g3_ref=x.g3_ref,
     g1_hash=x.g1_hash, g2_hash=x.g2_hash, g3_hash=x.g3_hash, package_hash=x.package_hash,
     mission_bounds=x.mission_bounds, state=x.state, source_manifest_hash=x.source_manifest_hash,
     package_status=x.package_status, resolution=x.resolution, claim_ceiling=x.claim_ceiling,
     input_hash=x.input_hash)

function up2_input_from_a(package::CandidateStatePackageV5, mission_bounds::UP2MissionBoundsV1,
        projection::UP2AProjectionV1, source_manifest_hash::Digest256)
    package.structural_status == :valid || throw(ArgumentError("UP1-04A package is structurally invalid"))
    package.resolution == terminal_deferred || throw(ArgumentError("UP1-04A package must preserve deferred gaps"))
    package.claim_ceiling == none || throw(ArgumentError("UP1-04A package claim ceiling is too high"))
    projection.package_hash == package.candidate_hash ||
        throw(ArgumentError("A projection package hash does not match the actual package"))
    projection.candidate_ref == package.candidate_ref ||
        throw(ArgumentError("A projection candidate ref does not match the actual package"))
    isdefined(@__MODULE__, :up2_projection_from_a) ||
        throw(ArgumentError("UP2 source projection accessor is unavailable"))
    derived = getfield(@__MODULE__, :up2_projection_from_a)(package)
    projection.projection_hash == derived.projection_hash ||
        throw(ArgumentError("A projection values do not match the actual package projection"))
    state = UP2PrecompilerStateV1(projection.fields, projection.flux_pair)
    identity = package.component_identity
    UP2PrecompilerInputV1(package.candidate_ref, package.g1.contract_ref,
        package.g2.contract_ref, package.g3.contract_binding.contract_ref, identity.g1_genome_hash,
        identity.g2_genome_hash, identity.g3_genome_hash, package.candidate_hash,
        mission_bounds, state, source_manifest_hash, :a_limited,
        package.resolution, package.claim_ceiling)
end

function up2_input_from_a(package::CandidateStatePackageV5,
        mission_bounds::UP2MissionBoundsV1, source_manifest_hash::Digest256)
    projection = getfield(@__MODULE__, :up2_projection_from_a)(package)
    up2_input_from_a(package, mission_bounds, projection, source_manifest_hash)
end
