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
# The frozen N10-03 source type is GenomeContractRef, not QualifiedRefV1.
# Keep both ref families distinct while exposing the same registered :ref row type.
struct UP2ContractRefValueV1 <: UP2TypedValueV1; value::GenomeContractRef; end
struct UP2TupleValueV1 <: UP2TypedValueV1; values::Tuple; element_type::Symbol; end
struct UP2AbsentValueV1 <: UP2TypedValueV1
    intended_type::Symbol
    reason::Symbol
    function UP2AbsentValueV1(intended_type, reason)
        kind, why = Symbol(intended_type), Symbol(reason)
        kind in (:integer, :symbol, :text, :rational, :unit, :hash, :ref, :tuple) ||
            throw(ArgumentError("UP2 absent value intended type is invalid"))
        new(kind, why)
    end
end

semantic_view(x::UP2IntegerValueV1) = (kind=:integer, value=x.value)
semantic_view(x::UP2SymbolValueV1) = (kind=:symbol, value=x.value)
semantic_view(x::UP2TextValueV1) = (kind=:text, value=x.value)
semantic_view(x::UP2RationalValueV1) = (kind=:rational, value=x.value)
semantic_view(x::UP2UnitValueV1) = (kind=:unit, value=x.value)
semantic_view(x::UP2HashValueV1) = (kind=:hash, value=x.value)
semantic_view(x::UP2RefValueV1) = (kind=:ref, value=x.value)
semantic_view(x::UP2ContractRefValueV1) =
    (kind=:ref, ref_type=:GenomeContractRef, value=x.value)
semantic_view(x::UP2TupleValueV1) = (kind=:tuple, values=x.values, element_type=x.element_type)
semantic_view(x::UP2AbsentValueV1) =
    (kind=:typed_absent, intended_type=x.intended_type, reason=x.reason)

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

"""One freeze-manifest source pin carried into the VNext UP2 input."""
struct UP2VNextSourcePinV1
    role::Symbol
    byte_count::Int
    sha256::Digest256
    function UP2VNextSourcePinV1(role, byte_count, sha256)
        r, n = Symbol(role), Int(byte_count)
        r in (:g1_builder, :g1_declaration_source, :g2_builder,
            :g2_declaration_source, :g3_builder, :g3_child_design) ||
            throw(ArgumentError("UP2 VNext source pin role is unsupported"))
        n > 0 && sha256 isa Digest256 ||
            throw(ArgumentError("UP2 VNext source pin is invalid"))
        new(r, n, sha256)
    end
end
semantic_view(x::UP2VNextSourcePinV1) =
    (role=x.role, byte_count=x.byte_count, sha256=x.sha256)

const _UP2_VNEXT_SOURCE_ROLES = (:g1_builder, :g1_declaration_source,
    :g2_builder, :g2_declaration_source, :g3_builder, :g3_child_design)

"""Candidate, receipt, package and N03 event identities from the VNext route."""
struct UP2VNextSourceBindingV1
    candidate_ref::QualifiedRefV1
    candidate_id::String
    scenario_id::String
    snapshot_id::String
    manifest_sha256::Digest256
    package_hash::Digest256
    semantic_identity::Digest256
    bundle_hash::Digest256
    n03_projection_hash::Digest256
    source_pins::NTuple{6,UP2VNextSourcePinV1}
    event_id::String
    trigger::Symbol
    time::Rational{Int64}
    time_basis::Union{Nothing,Symbol}
    projection_status::Symbol
    projection_resolution::Symbol
    authority_scope::Symbol
    authority_gap::String
    binding_hash::Digest256
    function UP2VNextSourceBindingV1(candidate_ref, candidate_id, scenario_id,
            snapshot_id, manifest_sha256, package_hash, semantic_identity,
            bundle_hash, n03_projection_hash, source_pins, event_id, trigger,
            time, time_basis, projection_status, projection_resolution,
            authority_scope, authority_gap)
        candidate_ref isa QualifiedRefV1 && candidate_ref.version == "v5" ||
            throw(ArgumentError("UP2 VNext candidate ref is invalid"))
        texts = (candidate_id, scenario_id, snapshot_id, event_id)
        all(x -> x isa AbstractString && !isempty(String(x)), texts) ||
            throw(ArgumentError("UP2 VNext identity text is incomplete"))
        candidate_ref.id == "fusionconceptai://candidate-design/" *
            String(candidate_id) ||
            throw(ArgumentError("UP2 VNext candidate id/ref mismatch"))
        digests = (manifest_sha256, package_hash, semantic_identity, bundle_hash,
            n03_projection_hash)
        all(x -> x isa Digest256, digests) ||
            throw(ArgumentError("UP2 VNext identity digest is incomplete"))
        source_pins isa Tuple && length(source_pins) == 6 &&
            all(x -> x isa UP2VNextSourcePinV1, source_pins) &&
            Tuple(x.role for x in source_pins) == _UP2_VNEXT_SOURCE_ROLES ||
            throw(ArgumentError("UP2 VNext source pins are incomplete or unordered"))
        trigger isa Symbol && trigger in (:initial, :scheduled, :fault, :threshold) ||
            throw(ArgumentError("UP2 VNext event trigger is invalid"))
        time isa Rational{Int64} && time >= 0 ||
            throw(ArgumentError("UP2 VNext event time is invalid"))
        basis = time_basis === nothing ? nothing : Symbol(time_basis)
        basis === nothing || basis in (:static, :continuous, :discrete, :event) ||
            throw(ArgumentError("UP2 VNext event time basis is invalid"))
        basis === :event ||
            throw(ArgumentError("UP2 VNext prepared input requires the authored event-time policy"))
        projection_status === :local_source_bound &&
            projection_resolution === :terminal_deferred ||
            throw(ArgumentError("UP2 VNext N03 projection must remain locally bound and deferred"))
        scope = Symbol(authority_scope)
        gap = String(authority_gap)
        scope === :local_source_data &&
            gap == "candidate_authored_event_time_policy_is_design_only" ||
            throw(ArgumentError("UP2 VNext prepared input requires the candidate-design authority ceiling"))
        body = (candidate_ref=candidate_ref, candidate_id=String(candidate_id),
            scenario_id=String(scenario_id), snapshot_id=String(snapshot_id),
            manifest_sha256=manifest_sha256, package_hash=package_hash,
            semantic_identity=semantic_identity, bundle_hash=bundle_hash,
            n03_projection_hash=n03_projection_hash, source_pins=source_pins,
            event_id=String(event_id), trigger=trigger, time=time,
            time_basis=basis, projection_status=projection_status,
            projection_resolution=projection_resolution, authority_scope=scope,
            authority_gap=gap)
        new(candidate_ref, String(candidate_id), String(scenario_id),
            String(snapshot_id), manifest_sha256, package_hash, semantic_identity,
            bundle_hash, n03_projection_hash, source_pins, String(event_id),
            trigger, time, basis, projection_status, projection_resolution,
            scope, gap, canonical_hash(body))
    end
end
semantic_view(x::UP2VNextSourceBindingV1) =
    (candidate_ref=x.candidate_ref, candidate_id=x.candidate_id,
     scenario_id=x.scenario_id, snapshot_id=x.snapshot_id,
     manifest_sha256=x.manifest_sha256, package_hash=x.package_hash,
     semantic_identity=x.semantic_identity, bundle_hash=x.bundle_hash,
     n03_projection_hash=x.n03_projection_hash, source_pins=x.source_pins,
     event_id=x.event_id, trigger=x.trigger, time=x.time,
     time_basis=x.time_basis, projection_status=x.projection_status,
     projection_resolution=x.projection_resolution,
     authority_scope=x.authority_scope, authority_gap=x.authority_gap,
     binding_hash=x.binding_hash)

"""Per-row availability without promoting deferred or absent values."""
struct UP2VNextFieldStateV1
    field_id::String
    state::Symbol
    reason::Symbol
    source_pin_roles::Tuple{Vararg{Symbol}}
    function UP2VNextFieldStateV1(field_id, state, reason, source_pin_roles=())
        id, st, why = String(field_id), Symbol(state), Symbol(reason)
        !isempty(id) || throw(ArgumentError("UP2 VNext field state requires an id"))
        st in (:source_present_deferred, :typed_absent) ||
            throw(ArgumentError("UP2 VNext field state is invalid"))
        roles = Tuple(Symbol(x) for x in source_pin_roles)
        all(x -> x in _UP2_VNEXT_SOURCE_ROLES, roles) ||
            throw(ArgumentError("UP2 VNext field state pin role is invalid"))
        new(id, st, why, roles)
    end
end
semantic_view(x::UP2VNextFieldStateV1) =
    (field_id=x.field_id, state=x.state, reason=x.reason,
     source_pin_roles=x.source_pin_roles)

"""VNext-backed UP2 input using the existing fixed 50 mutation rows.

This contract is separate from legacy `UP2PrecompilerInputV1` because T1 VNext
does not expose legacy GenomeContractRef values. Missing projectors use explicit
typed-absent values while their row state retains any pinned source availability.
"""
struct UP2VNextPrecompilerInputV1
    source_binding::UP2VNextSourceBindingV1
    mission_bounds::UP2MissionBoundsV1
    state::UP2PrecompilerStateV1
    field_states::NTuple{50,UP2VNextFieldStateV1}
    provider_bindings::Tuple
    status::Symbol
    resolution::Symbol
    claim_ceiling::Symbol
    input_hash::Digest256
    function UP2VNextPrecompilerInputV1(source_binding, mission_bounds, state,
            field_states; status=:prepared_not_executed,
            resolution=:terminal_deferred, claim_ceiling=:contract_only,
            provider_bindings=())
        source_binding isa UP2VNextSourceBindingV1 ||
            throw(ArgumentError("UP2 VNext source binding is absent"))
        mission_bounds isa UP2MissionBoundsV1 ||
            throw(ArgumentError("UP2 VNext mission bounds are invalid"))
        state isa UP2PrecompilerStateV1 && length(state.fields) == 50 ||
            throw(ArgumentError("UP2 VNext input requires the existing 50 fixed rows"))
        field_states isa Tuple && length(field_states) == 50 &&
            all(x -> x isa UP2VNextFieldStateV1, field_states) ||
            throw(ArgumentError("UP2 VNext field states require all 50 rows"))
        Tuple(x.id for x in state.fields) == Tuple(x.field_id for x in field_states) ||
            throw(ArgumentError("UP2 VNext field state order does not match the 50 rows"))
        provider_bindings isa Tuple && is_canonical_value(provider_bindings) ||
            throw(ArgumentError("UP2 VNext provider bindings must be canonical immutable values"))
        status === :prepared_not_executed && resolution === :terminal_deferred &&
            claim_ceiling === :contract_only ||
            throw(ArgumentError("UP2 VNext input must remain prepared, deferred, and contract-only"))
        body = (source_binding=source_binding, mission_bounds=mission_bounds,
            state=state, field_states=field_states, status=status,
            resolution=resolution, claim_ceiling=claim_ceiling)
        isempty(provider_bindings) ||
            (body = merge(body, (provider_bindings=provider_bindings,)))
        new(source_binding, mission_bounds, state, field_states, provider_bindings, status,
            resolution, claim_ceiling, canonical_hash(body))
    end
end
function semantic_view(x::UP2VNextPrecompilerInputV1)
    body = (source_binding=x.source_binding, mission_bounds=x.mission_bounds,
     state=x.state, field_states=x.field_states, status=x.status,
     resolution=x.resolution, claim_ceiling=x.claim_ceiling,
     input_hash=x.input_hash)
    isempty(x.provider_bindings) ? body :
        merge(body, (provider_bindings=x.provider_bindings,))
end

struct UP2VNextInputBuildResultV1
    status::Symbol
    resolution::Symbol
    reason::Symbol
    input::Union{Nothing,UP2VNextPrecompilerInputV1}
    n03_projection_hash::Union{Nothing,Digest256}
    result_hash::Digest256
end
semantic_view(x::UP2VNextInputBuildResultV1) =
    (status=x.status, resolution=x.resolution, reason=x.reason,
     input=x.input, n03_projection_hash=x.n03_projection_hash,
     result_hash=x.result_hash)

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
