"""Value based contract validator for the UP2-00 preparation slice.

N01/N02 and the N03 G1/G3 event values are projected from the actual A package;
the selected VNext N01/N02 rows use source-pinned G1 operator types and the G2
profile dimension. N03-03 consumes an explicit candidate-authored G1 operator
temporal whitelist when present.
N03 event mutations remain pending where the event time-basis policy is absent.
N04-02 projects G3 closure account IDs and classifies the registered
duplicate-ID mutation. N04-05 consumes the candidate-bound typed G3 ledger
coefficient for a local capacity mutation; physical authority remains deferred.
N07/N08 project actual G2 V5 values and the explicitly mapped subset of a
candidate-bound G2 MetricBoundary V1 source. N07-04 and N08-01 are projected
only from explicit whole-face coverage and axis labels. Unmapped legacy geometry
rows stay typed absent; these candidate-authored values remain contract-only. N04-01/03
consume the explicit candidate-bound typed-ledger crosswalk when present; older
packages keep those rows typed absent. N04-02/04/05 consume bound authored
ledger values; N06-N10 remain pending; N05 retains missing flux-port provenance.
"""

function _up2_specs_for_class(class_id::Symbol, rows)
    Tuple(UP2MutationSpecV1(id, class_id, path, locator, source_type, mutation_kind,
        expected_error, terminal_deferred, 0, detail)
        for (id, path, locator, source_type, mutation_kind, expected_error, detail) in rows)
end

const _UP2_MUTATION_SPECS = let
    rows = UP2MutationSpecV1[]
    append!(rows, _up2_specs_for_class(:N01, (
        ("N01-01", "/g1/equation_plan/equations/0/input_ranks/0", "G1EquationV2.input_ranks::Int", :integer, :rank, :invalid_type, "rank_or_dimension_mismatch"),
        ("N01-02", "/g1/equation_plan/equations/0/output_ranks/0", "G1EquationV2.output_ranks::Int", :integer, :rank, :invalid_type, "rank_or_dimension_mismatch"),
        ("N01-03", "/g1/states/0/physical_type/tensor_rank", "PhysicalType.tensor_rank::Int", :integer, :rank, :invalid_type, "rank_or_dimension_mismatch"),
        ("N01-04", "/g2/plan/embedding/ambient_dimension", "G2EmbeddingPlanV2.ambient_dimension::Int", :integer, :dimension, :invalid_type, "rank_or_dimension_mismatch"),
        ("N01-05", "/g2/plan/field_space/value_shape", "G2FieldSpacePlanV2.value_shape::Symbol", :symbol, :shape, :invalid_type, "rank_or_dimension_mismatch"))))
    append!(rows, _up2_specs_for_class(:N02, (
        ("N02-01", "/g1/equation_plan/equations/0/input_units/0", "G1EquationV2.input_units::UnitSignature", :unit, :unit, :invalid_type, "unit_or_normalization_mismatch"),
        ("N02-02", "/g1/equation_plan/equations/0/output_units/0", "G1EquationV2.output_units::UnitSignature", :unit, :unit, :invalid_type, "unit_or_normalization_mismatch"),
        ("N02-03", "/g2/plan/field_space/state_unit", "G2FieldSpacePlanV2.state_unit::String", :text, :unit_text, :invalid_type, "unit_or_normalization_mismatch"),
        ("N02-04", "/g3/realization/network/resource_ports/0/unit", "G3ResourcePortV2.unit::UnitSignature", :unit, :unit, :invalid_type, "unit_or_normalization_mismatch"),
        ("N02-05", "/g3/realization/network/entries/0/unit", "G3LedgerEntryV2.unit::UnitSignature", :unit, :unit, :invalid_type, "unit_or_normalization_mismatch"))))
    append!(rows, _up2_specs_for_class(:N03, (
        ("N03-01", "/g1/equation_plan/equations/0/temporal_kind", "G1EquationV2.temporal_kind::TimeKindV1", :symbol, :unsupported_time_kind, :invalid_type, "time_semantics_mismatch"),
        ("N03-02", "/g1/equation_plan/equations/0/derivative_order", "G1EquationV2.derivative_order::Int", :integer, :negative_derivative_order, :invalid_type, "time_semantics_mismatch"),
        ("N03-03", "/g1/grammar_profile/operators/0/temporal_kinds", "G1OperatorSpecV2.temporal_kinds::Tuple", :tuple, :exclude_equation_time_kind, :invalid_type, "time_semantics_mismatch"),
        ("N03-04", "/g3/control/controllers/0/events/0/trigger", "G3EventV2.trigger::Symbol", :symbol, :pending, :invalid_type, "time_semantics_mismatch"),
        ("N03-05", "/g3/control/controllers/0/events/0/time", "G3EventV2.time::Rational{Int64}", :rational, :pending, :invalid_type, "time_semantics_mismatch"))))
    append!(rows, _up2_specs_for_class(:N04, (
        ("N04-01", "/g3/realization/network/accounts/0/owner", "G3LedgerAccountV2.owner::String", :text, :owner_crosswalk_mismatch, :invalid_closure, "duplicate_conservation_or_energy_account_owner"),
        ("N04-02", "/g3/realization/network/closures/0/account_ids", "G3LedgerClosureV2.account_ids::Tuple[String]", :tuple, :duplicate_account_ids, :invalid_closure, "duplicate_conservation_or_energy_account_owner"),
        ("N04-03", "/g3/realization/network/entries/0/account_id", "G3LedgerEntryV2.account_id::String", :text, :unknown_account_ref, :invalid_closure, "duplicate_conservation_or_energy_account_owner"),
        ("N04-04", "/g3/realization/network/entries/0/component_id", "G3LedgerEntryV2.component_id::String", :text, :pending, :invalid_closure, "duplicate_conservation_or_energy_account_owner"),
        ("N04-05", "/g3/realization/network/entries/1/coefficient", "G3LedgerEntryV2.coefficient::Rational{Int64}", :rational, :pending, :invalid_closure, "duplicate_conservation_or_energy_account_owner"))))
    append!(rows, _up2_specs_for_class(:N05, (
        ("N05-01", "/up2/flux_pair/left_port", "UP2FluxPairV1.left_port::String", :text, :left_empty, :invalid_closure, "unpaired_interface_flux_traction_current"),
        ("N05-02", "/up2/flux_pair/right_port", "UP2FluxPairV1.right_port::String", :text, :right_empty, :invalid_closure, "unpaired_interface_flux_traction_current"),
        ("N05-03", "/up2/flux_pair/left_sign", "UP2FluxPairV1.left_sign::Int8", :integer, :left_sign_zero, :invalid_closure, "unpaired_interface_flux_traction_current"),
        ("N05-04", "/up2/flux_pair/right_sign", "UP2FluxPairV1.right_sign::Int8", :integer, :same_sign, :invalid_closure, "unpaired_interface_flux_traction_current"),
        ("N05-05", "/up2/flux_pair/unit", "UP2FluxPairV1.unit::UnitSignature", :unit, :unit_mismatch, :invalid_closure, "unpaired_interface_flux_traction_current"))))
    append!(rows, _up2_specs_for_class(:N06, (
        ("N06-01", "/g3/realization/network/resource_ports", "G3ResourceNetworkV2.resource_ports::Tuple", :tuple, :pending, :invalid_closure, "missing_source_binding_or_return_path_or_heat_sink"),
        ("N06-02", "/g3/realization/network/entries", "G3ResourceNetworkV2.entries::Tuple", :tuple, :pending, :invalid_closure, "missing_source_binding_or_return_path_or_heat_sink"),
        ("N06-03", "/g3/binding/links/0/resource_port_id", "G3ControlResourceLinkV2.resource_port_id::String", :text, :pending, :invalid_closure, "missing_source_binding_or_return_path_or_heat_sink"),
        ("N06-04", "/g3/realization/network/closures/0/expected_balance", "G3LedgerClosureV2.expected_balance::Rational{Int64}", :rational, :pending, :invalid_closure, "missing_source_binding_or_return_path_or_heat_sink"),
        ("N06-05", "/g3/realization/network/resource_ports/0/kind", "G3ResourcePortV2.kind::Symbol", :symbol, :pending, :invalid_closure, "missing_source_binding_or_return_path_or_heat_sink"))))
    append!(rows, _up2_specs_for_class(:N07, (
        ("N07-01", "/g2/contract/regions/0/lower", "G2RegionV2.lower::NTuple{3,Rational{Int64}}", :tuple, :lower_out_of_domain, :invalid_boundary, "nonclosed_or_out_of_bounds_boundary"),
        ("N07-02", "/g2/contract/regions/0/upper", "G2RegionV2.upper::NTuple{3,Rational{Int64}}", :tuple, :upper_out_of_domain, :invalid_boundary, "nonclosed_or_out_of_bounds_boundary"),
        ("N07-03", "/g2/plan/exterior/boundary_faces", "G2ExteriorPlanV2.boundary_faces::Tuple[Symbol]", :tuple, :drop_face, :invalid_boundary, "nonclosed_or_out_of_bounds_boundary"),
        ("N07-04", "/g2/plan/exterior/boundary_patches/0/lower", "G2BoundaryFacePatchV2.lower::NTuple{2,Rational{Int64}}", :tuple, :patch_out_of_domain, :invalid_boundary, "nonclosed_or_out_of_bounds_boundary"),
        ("N07-05", "/g2/plan/exterior/boundary_condition", "G2ExteriorPlanV2.boundary_condition::Symbol", :symbol, :none_condition, :invalid_boundary, "nonclosed_or_out_of_bounds_boundary"))))
    append!(rows, _up2_specs_for_class(:N08, (
        ("N08-01", "/g2/plan/chart/axes", "G2ChartPlanV2.axes::NTuple{3,Symbol}", :tuple, :axes_invalid, :invalid_boundary, "invalid_geometry_chart_mesh_or_topology"),
        ("N08-02", "/g2/plan/chart/map_kind", "G2ChartPlanV2.map_kind::Symbol", :symbol, :map_invalid, :invalid_boundary, "invalid_geometry_chart_mesh_or_topology"),
        ("N08-03", "/g2/plan/mesh/cells_per_region", "G2MeshPlanV2.cells_per_region::NTuple{3,Int}", :tuple, :cells_nonpositive, :invalid_boundary, "invalid_geometry_chart_mesh_or_topology"),
        ("N08-04", "/g2/plan/mesh/basis", "G2MeshPlanV2.basis::Symbol", :symbol, :basis_invalid, :invalid_boundary, "invalid_geometry_chart_mesh_or_topology"),
        ("N08-05", "/g2/contract/interfaces", "RegionInterfaceContractV2.interfaces::Tuple", :tuple, :duplicate_interface, :invalid_boundary, "invalid_geometry_chart_mesh_or_topology"))))
    append!(rows, _up2_specs_for_class(:N09, (
        ("N09-01", "/g1/grammar_profile/operators/0/provider_match", "G1OperatorSpecV2.provider_match::Symbol", :symbol, :pending, :provider_match, "provider_signature_gap"),
        ("N09-02", "/g2/grammar_profile/provider_match", "SpatialGrammarProfileV2.provider_match::Symbol", :symbol, :pending, :provider_match, "provider_signature_gap"),
        ("N09-03", "/g2/plan/exterior/provider_match", "G2ExteriorPlanV2.provider_match::Symbol", :symbol, :pending, :provider_match, "provider_signature_gap"),
        ("N09-04", "/g3/realization/provider_match", "RealizationGenomeV5.provider_match::Symbol", :symbol, :pending, :provider_match, "provider_signature_gap"),
        ("N09-05", "/g3/control/provider_match", "ControlGenomeV5.provider_match::Symbol", :symbol, :pending, :provider_match, "provider_signature_gap"))))
    append!(rows, _up2_specs_for_class(:N10, (
        ("N10-01", "/candidate_state_package/component_identity/g1_ref/schema_hash", "CandidateStatePackageV5.component_identity.g1_ref.schema_hash::Digest256", :hash, :pending, :invalid_type, "foreign_or_stale_receipt_or_hash_mismatch"),
        ("N10-02", "/candidate_state_package/component_identity/g2_ref/canonicalization_hash", "CandidateStatePackageV5.component_identity.g2_ref.canonicalization_hash::Digest256", :hash, :pending, :terminal_deferred, "foreign_or_stale_receipt_or_hash_mismatch"),
        ("N10-03", "/candidate_state_package/component_identity/g3_child_refs/binding", "CandidateStatePackageV5.component_identity.g3_child_refs.binding::GenomeContractRef", :ref, :pending, :terminal_deferred, "foreign_or_stale_receipt_or_hash_mismatch"),
        ("N10-04", "/candidate_state_package/candidate_hash", "CandidateStatePackageV5.candidate_hash::Digest256", :hash, :pending, :invalid_type, "foreign_or_stale_receipt_or_hash_mismatch"),
        ("N10-05", "/candidate_state_package/migration_receipt/candidate_identity_after", "GenomeV5MigrationReceipt.candidate_identity_after::String", :text, :pending, :terminal_deferred, "foreign_or_stale_receipt_or_hash_mismatch"))))
    Tuple(rows)
end

up2_expected_mutations() = _UP2_MUTATION_SPECS
up2_mutation_count() = length(_UP2_MUTATION_SPECS)
up2_spec_for_id(id::AbstractString) = begin
    found = Tuple(x for x in _UP2_MUTATION_SPECS if x.id == String(id))
    length(found) == 1 ? first(found) : throw(ArgumentError("unknown UP2 mutation id: $id"))
end

function _up2_pending_value(kind::Symbol, package)
    kind === :integer && return UP2IntegerValueV1(0)
    kind === :symbol && return UP2SymbolValueV1(:pending)
    kind === :text && return UP2TextValueV1("pending")
    kind === :rational && return UP2RationalValueV1(0 // 1)
    kind === :unit && return UP2UnitValueV1(UnitSignature())
    kind === :tuple && return UP2TupleValueV1((), :pending)
    kind === :hash && return UP2HashValueV1(package.candidate_hash)
    kind === :ref && return UP2RefValueV1(package.candidate_ref)
    throw(ArgumentError("unsupported pending UP2 type $kind"))
end

"""Project the local N03 G1 values without requiring the separate N03 module."""
function _up2_n03_local_source_values(package, equation)
    operators = package.g1.payload.grammar_profile.operators
    operator_index = findfirst(x -> x.ref == equation.operator_ref, operators)
    (operator_index === nothing || operator_index != 1) &&
        throw(ArgumentError("UP2 N03 field path requires the equation operator at index 1"))
    operator = operators[operator_index]
    (operator.ref == equation.operator_ref && operator.temporal_kinds isa Tuple &&
        all(x -> x isa TimeKindV1, operator.temporal_kinds)) ||
        throw(ArgumentError("UP2 N03 operator source is invalid"))
    ("N03-01" => UP2SymbolValueV1(Symbol(equation.temporal_kind)),
     "N03-02" => UP2IntegerValueV1(Int(equation.derivative_order)),
     "N03-03" => UP2TupleValueV1(Tuple(Symbol(x) for x in operator.temporal_kinds), :timekind_v1))
end

"""Read the first typed G3 control event from the candidate-bound A package.

This binds the local trigger/time values to the package projection hash. It does
not supply a time unit/basis or authorize cross-layer event semantics.
"""
function _up2_n03_g3_event_source(package)
    control = package.g3.control
    controllers = control.controllers
    isempty(controllers) && throw(ArgumentError("UP2 N03 requires an actual G3 controller"))
    events = first(controllers).events
    isempty(events) && throw(ArgumentError("UP2 N03 requires an actual G3 controller event"))
    event = first(events)
    event isa G3EventV2 || throw(ArgumentError("UP2 N03 event source is not G3EventV2"))
    event.trigger in (:initial, :scheduled, :fault, :threshold) ||
        throw(ArgumentError("UP2 N03 G3 event trigger is outside the registered enum"))
    event.time isa Rational{Int64} && event.time >= 0 ||
        throw(ArgumentError("UP2 N03 G3 event time is not a nonnegative Rational{Int64}"))
    event
end

function _up2_n03_unlisted_time_kind(input)
    source = _up2_find_field(input.state, "N03-03")
    source === nothing && throw(ArgumentError("N03 operator temporal kinds are absent"))
    source.value isa UP2TupleValueV1 && source.value.element_type === :timekind_v1 ||
        throw(ArgumentError("N03 operator temporal kinds are not source-derived TimeKindV1 values"))
    allowed = source.value.values
    alternative = findfirst(kind -> Symbol(kind) ∉ allowed, instances(TimeKindV1))
    alternative === nothing && throw(ArgumentError("N03 source operator admits every TimeKindV1 value"))
    Symbol(instances(TimeKindV1)[alternative])
end

function _up2_n07n08_up2_value(value)
    isdefined(@__MODULE__, :N07N08TypedValueV1) &&
        value isa N07N08TypedValueV1 ||
        throw(ArgumentError("N07/N08 projection type is not loaded"))
    value isa N07N08Rational3V1 && return UP2TupleValueV1(value.value, :rational)
    value isa N07N08Rational2V1 && return UP2TupleValueV1(value.value, :rational)
    value isa N07N08SymbolTupleV1 && return UP2TupleValueV1(value.value, :symbol)
    value isa N07N08SymbolValueV1 && return UP2SymbolValueV1(value.value)
    value isa N07N08Int3V1 && return UP2TupleValueV1(value.value, :integer)
    value isa N07N08InterfaceRefsV1 && return UP2TupleValueV1(value.value, :qualified_ref)
    throw(ArgumentError("unsupported N07/N08 typed projection value $(typeof(value))"))
end

function _up2_n07n08_field_value(projection, id::String)
    isdefined(@__MODULE__, :N07N08ProjectionV1) &&
        projection isa N07N08ProjectionV1 ||
        throw(ArgumentError("N07/N08 projection type is not loaded"))
    field = _n07n08_field(projection, id)
    _up2_n07n08_up2_value(field.value)
end

"""Derive the UP2 projection from the actual accepted A package.

N01/N02 and N03 G1/G3 event values are populated from concrete source values.
The G3 event trigger/time are local source data only: without a candidate-bound
time-basis policy, their cross-layer mutation classifications remain pending.
N04/N06-N10 remain typed pending projections.
"""
function up2_projection_from_a(package::CandidateStatePackageV5)
    package.structural_status == :valid || throw(ArgumentError("A package is not structurally valid"))
    package.resolution == terminal_deferred || throw(ArgumentError("A package resolution must remain deferred"))
    package.claim_ceiling == none || throw(ArgumentError("A package claim ceiling is not contract-only"))
    eq = package.g1.payload.equation_plan.equations[1]
    input_state = first(s for s in package.g1.payload.states if s.state_id == eq.input_state_refs[1])
    interfaces = package.g2.region_interface.interfaces
    length(interfaces) == 1 || throw(ArgumentError("UP2 N05 requires one actual G2 interface declaration"))
    interface = first(interfaces)
    n03_local_values = _up2_n03_local_source_values(package, eq)
    n03_event = _up2_n03_g3_event_source(package)
    n07n08 = n07_n08_projection_from_a(package)
    fields = Tuple(begin
        value = if spec.id == "N01-01"
            UP2IntegerValueV1(eq.input_ranks[1])
        elseif spec.id == "N01-02"
            UP2IntegerValueV1(eq.output_ranks[1])
        elseif spec.id == "N01-03"
            UP2IntegerValueV1(input_state.physical_type.tensor_rank)
        elseif spec.id == "N01-04"
            UP2IntegerValueV1(package.g2.plan.embedding.ambient_dimension)
        elseif spec.id == "N01-05"
            UP2SymbolValueV1(package.g2.plan.field_space.value_shape)
        elseif spec.id == "N02-01"
            UP2UnitValueV1(eq.input_units[1])
        elseif spec.id == "N02-02"
            UP2UnitValueV1(eq.output_units[1])
        elseif spec.id == "N02-03"
            UP2TextValueV1(package.g2.plan.field_space.state_unit)
        elseif spec.id == "N02-04"
            UP2UnitValueV1(package.g3.realization.network.resource_ports[1].unit)
        elseif spec.id == "N02-05"
            UP2UnitValueV1(package.g3.realization.network.entries[1].unit)
        elseif spec.id in ("N03-01", "N03-02", "N03-03")
            last(first(x for x in n03_local_values if first(x) == spec.id))
        elseif spec.id == "N03-04"
            UP2SymbolValueV1(n03_event.trigger)
        elseif spec.id == "N03-05"
            UP2RationalValueV1(n03_event.time)
        elseif spec.id == "N04-02"
            UP2TupleValueV1(Tuple(package.g3.realization.network.closures[1].account_ids), :string)
        elseif spec.id == "N05-01"
            UP2TextValueV1("pending-port:left")
        elseif spec.id == "N05-02"
            UP2TextValueV1("pending-port:right")
        elseif spec.id == "N05-03"
            UP2IntegerValueV1(interface.normal)
        elseif spec.id == "N05-04"
            UP2IntegerValueV1(-interface.normal)
        elseif spec.id == "N05-05"
            UP2UnitValueV1(eq.input_units[1])
        elseif spec.class_id in (:N07, :N08)
            _up2_n07n08_field_value(n07n08, spec.id)
        else
            _up2_pending_value(spec.source_type, package)
        end
        UP2SemanticFieldV1(spec.id, spec.field_path, spec.source_locator, spec.source_type, value)
    end for spec in _UP2_MUTATION_SPECS)
    pair = UP2FluxPairV1("pair-actual-a", "pending-port:left", "pending-port:right",
        interface.normal, -interface.normal, eq.input_units[1], interface.interface_ref,
        interface.left_region_id, interface.right_region_id, interface.normal,
        interface.transfer_kind, :unverified)
    UP2AProjectionV1(package.candidate_ref, package.candidate_hash, fields, pair)
end

function _up2_vnext_build_result(status, resolution, reason, input, projection_hash)
    body = (status=status, resolution=resolution, reason=reason,
        input=input, n03_projection_hash=projection_hash)
    UP2VNextInputBuildResultV1(status, resolution, reason, input,
        projection_hash, canonical_hash(body))
end

function _up2_vnext_layer_roles(field_path)
    startswith(field_path, "/g1/") &&
        return (:g1_builder, :g1_declaration_source)
    startswith(field_path, "/g2/") &&
        return (:g2_builder, :g2_declaration_source)
    startswith(field_path, "/g3/") &&
        return (:g3_builder, :g3_child_design)
    ()
end

"""Expose only typed refs retained from the current VNext T0/T1 source.

The returned refs are not a fabricated legacy `CandidateStatePackageV5`
identity. Declaration refs came from the typed T0 factory receipts; the binding
ref came from the T0 child body and was checked by T1 when present.
"""
function _up2_n10_json_semantic(value)
    if value isa JSON3.Object
        return Dict{String,Any}(String(k) => _up2_n10_json_semantic(v)
            for (k, v) in pairs(value))
    elseif value isa AbstractVector
        return Tuple(_up2_n10_json_semantic(v) for v in value)
    end
    value
end

const _UP2_N10_BYTE_INTEGER_TOKENS = ntuple(i -> string(i - 1), 256)

function _up2_n10_write_canonical_json(io::IO, value)
    if value isa JSON3.Object
        # Match Dict{String,Any}(String(k) => v for pairs(value)): stringified
        # keys use last-write-wins semantics before canonical key sorting.
        normalized = Dict{String,Any}()
        for (key, child) in pairs(value)
            normalized[String(key)] = child
        end
        names = sort!(collect(keys(normalized)))
        print(io, '{')
        for i in eachindex(names)
            i == firstindex(names) || print(io, ',')
            name = names[i]
            print(io, _jsonquote(name), ':')
            _up2_n10_write_canonical_json(io, normalized[name])
        end
        print(io, '}')
    elseif value isa AbstractVector
        print(io, '[')
        first_item = true
        for child in value
            first_item || print(io, ',')
            first_item = false
            _up2_n10_write_canonical_json(io, child)
        end
        print(io, ']')
    elseif value isa Bool
        print(io, value ? "true" : "false")
    elseif typeof(value) in _P0_SAFE_INTEGER_TYPES && 0 <= value <= 255
        print(io, _UP2_N10_BYTE_INTEGER_TOKENS[Int(value) + 1])
    else
        # Delegate scalar spelling, including float edge cases and null/string
        # escaping, to the established canonical encoder.
        print(io, canonical_json(value))
    end
    nothing
end

function _up2_n10_canonical_json(value)
    io = IOBuffer()
    _up2_n10_write_canonical_json(io, value)
    String(take!(io))
end

function _up2_n10_digest_from_wire(value, label)
    raw = _n03_get(value, :value)
    raw isa AbstractString || throw(ArgumentError("N10 $label digest is malformed"))
    Digest256(String(raw))
end

function _up2_n10_contract_ref_from_wire(value, label)
    value === nothing && return nothing
    uri, version = _n03_get(value, :uri), _n03_get(value, :version)
    profile = _n03_get(value, :compatibility_profile)
    all(x -> x isa AbstractString && !isempty(String(x)), (uri, version, profile)) ||
        throw(ArgumentError("N10 $label contract ref is incomplete"))
    GenomeContractRef(String(uri), String(version),
        _up2_n10_digest_from_wire(_n03_get(value, :schema_hash), "$label.schema_hash"),
        _up2_n10_digest_from_wire(_n03_get(value, :canonicalization_hash),
            "$label.canonicalization_hash"), String(profile))
end

"""Decode source-bound G1/G2 factory refs from immutable T0 receipt bytes.

The factory result refs are accepted only when they equal the public contracts
recomputed from the already source-pinned UP2 G1/G2 contexts. The binding child
is read from the single parsed T0 wire and remains absent when its body has no
explicit `contract_ref` field.
"""
Base.@noinline Base.@nospecializeinfer function _up2_vnext_n10_identity_context(package, binding;
        g1_context=nothing, g2_context=nothing,
        include_source_contract_refs::Bool=false)
    Base.@nospecialize package g1_context g2_context
    package isa CandidateStatePackageV5NextV2 ||
        throw(ArgumentError("N10 source requires the bound CandidateStatePackageV5NextV2"))
    package.candidate_ref == binding.candidate_ref &&
        package.package_hash == binding.package_hash &&
        package.semantic_identity == binding.semantic_identity &&
        package.bundle_hash == binding.bundle_hash ||
        throw(ArgumentError("N10 current-source package identity differs from its source binding"))

    g1 = g1_context === nothing ?
        _up2_vnext_g1_operator_type_context(package, binding;
            include_semantic_body=true) : g1_context
    g2 = g2_context === nothing ?
        _up2_vnext_g2_geometry_context(package, binding, g1;
            include_semantic_body=true) : g2_context
    g1_expected = GenomeContractRef(
        "fusionconceptai://GenomeV5/G1/diffusion/public-contract/v1", "v5",
        g1_diffusion_schema_hash_v1(g1.interface_flux_pair !== nothing),
        g1_diffusion_canonicalization_hash_v1(),
        "g1-diffusion-v1-profile:" *
            g1_diffusion_profile_hash_v1(g1.interface_flux_pair !== nothing).value)
    g2_expected = _g2sf_expected_contract(g2.service_source_context.region_interface_present)

    wire_bytes = copy_bytes(package.wire)
    package.wire.sha256 == Digest256(bytes2hex(SHA.sha256(wire_bytes))) ||
        throw(ArgumentError("N10 T0 whole-wire SHA-256 mismatch"))
    wire = JSON3.read(String(wire_bytes))
    _up2_vnext_g2_ref_matches(_n03_get(wire, :candidate_ref), binding.candidate_ref) ||
        throw(ArgumentError("N10 T0 whole-wire candidate differs from source binding"))
    wire_declarations = _n03_get(wire, :declarations)

    declaration_ref(layer) = begin
        declarations = Tuple(d for d in package.declarations if d.layer === layer)
        length(declarations) == 1 ||
            throw(ArgumentError("N10 requires exactly one $(layer) T1 declaration"))
        d = only(declarations)
        d.candidate_ref == binding.candidate_ref ||
            throw(ArgumentError("N10 $(layer) declaration candidate mismatch"))
        raw = copy_bytes(d.factory_receipt_bytes)
        d.factory_receipt_bytes.sha256 == Digest256(bytes2hex(SHA.sha256(raw))) ||
            throw(ArgumentError("N10 $(layer) factory receipt carrier SHA-256 mismatch"))
        receipt_text = String(raw)
        receipt = JSON3.read(receipt_text)
        receipt_candidate = _n03_get(receipt, :candidate_ref)
        _up2_vnext_g2_ref_matches(receipt_candidate, binding.candidate_ref) ||
            throw(ArgumentError("N10 $(layer) factory receipt candidate mismatch"))
        String(_n03_get(receipt, :layer)) == String(layer) ||
            throw(ArgumentError("N10 $(layer) factory receipt layer mismatch"))
        _up2_vnext_g2_ref_matches(_n03_get(receipt, :source_ref), d.source_ref) &&
            _up2_vnext_g2_ref_matches(_n03_get(receipt, :declaration_ref), d.declaration_ref) ||
            throw(ArgumentError("N10 $(layer) factory receipt is detached from T1 declaration"))
        wire_matches = Tuple(x for x in wire_declarations if
            String(_n03_get(x, :layer)) == String(layer))
        length(wire_matches) == 1 ||
            throw(ArgumentError("N10 $(layer) declaration is missing/duplicated in T0 wire"))
        wire_decl = only(wire_matches)
        wire_receipt = _n03_get(wire_decl, :factory_receipt)
        wire_result = _n03_get(wire_receipt, :factory_result)
        wire_result === nothing &&
            throw(ArgumentError("N10 $(layer) T0 factory result is missing"))
        _up2_n10_canonical_json(wire_result) == receipt_text ||
            throw(ArgumentError("N10 $(layer) T1 receipt bytes differ from T0 factory result"))
        _up2_vnext_g2_ref_matches(_n03_get(wire_decl, :candidate_ref), binding.candidate_ref) &&
            _up2_vnext_g2_ref_matches(_n03_get(wire_decl, :source_ref), d.source_ref) &&
            _up2_vnext_g2_ref_matches(_n03_get(wire_decl, :declaration_ref), d.declaration_ref) ||
            throw(ArgumentError("N10 $(layer) T0 wire declaration is detached from T1"))
        ref = _up2_n10_contract_ref_from_wire(_n03_get(receipt, :contract_ref),
            "$(layer).factory_result")
        wire_ref = _up2_n10_contract_ref_from_wire(_n03_get(wire_result, :contract_ref),
            "$(layer).wire_factory_result")
        semantic_ref = if layer === :G2
            semantic_body = hasproperty(g2, :semantic_body) ? g2.semantic_body :
                JSON3.read(String(copy_bytes(d.semantic_body_bytes)))
            _up2_n10_contract_ref_from_wire(_n03_get(semantic_body, :contract_ref),
                "G2.semantic_body")
        else
            ref
        end
        ref !== nothing && wire_ref == ref && semantic_ref == ref ||
            throw(ArgumentError("N10 $(layer) factory refs disagree across T0/T1 source records"))
        expected = layer === :G1 ? g1_expected : g2_expected
        ref == expected ||
            throw(ArgumentError("N10 $(layer) factory ref differs from source-pinned public contract"))
        ref
    end
    g1_ref = declaration_ref(:G1)
    g2_ref = declaration_ref(:G2)

    binding_children = Tuple(c for c in package.children if c.kind === :binding)
    length(binding_children) == 1 ||
        throw(ArgumentError("N10 requires exactly one T1 binding child"))
    child = only(binding_children)
    child.status === :present && child.candidate_ref == binding.candidate_ref ||
        throw(ArgumentError("N10 binding child is not present for this candidate"))
    wire_children = _n03_get(wire, :children)
    child_rows = Tuple(x for x in wire_children if
        String(_n03_get(x, :kind)) == "binding")
    length(child_rows) == 1 ||
        throw(ArgumentError("N10 T0 binding child is missing/duplicated"))
    wire_child = only(child_rows)
    body = _n03_get(wire_child, :body)
    body === nothing && throw(ArgumentError("N10 T0 binding child body is missing"))
    body_hash = canonical_hash(_up2_n10_json_semantic(body))
    child.body_hash == body_hash ||
        throw(ArgumentError("N10 T0 binding body hash differs from T1 child manifest"))
    _up2_vnext_g2_ref_matches(_n03_get(wire_child, :candidate_ref), binding.candidate_ref) &&
        _up2_vnext_g2_ref_matches(_n03_get(body, :source_ref), child.source_ref) &&
        _n03_get(body, :source_sha256) !== nothing ||
        throw(ArgumentError("N10 T0 binding body is detached from its T1 source child"))
    source_sha = _n03_get(_n03_get(body, :source_sha256), :value)
    child.source_bytes === nothing &&
        throw(ArgumentError("N10 T1 binding child source bytes are absent"))
    child.source_bytes.sha256.value == source_sha ||
        throw(ArgumentError("N10 T0 binding body source hash differs from T1"))
    expected_child_identity = canonical_hash((candidate_ref=binding.candidate_ref,
        layer=:G3, child_id="binding", kind=:binding, child_ref=child.child_ref,
        body_hash=body_hash, source_ref=child.source_ref,
        source_sha256=child.source_bytes.sha256))
    child.child_identity_hash == expected_child_identity ||
        throw(ArgumentError("N10 T0 binding child identity hash mismatch"))
    binding_ref = _up2_n10_contract_ref_from_wire(_n03_get(body, :contract_ref),
        "binding_child.body")
    binding_ref === nothing ||
        binding_ref == g3_contract_ref(:binding) ||
        throw(ArgumentError("N10 T0 binding child ref differs from frozen G3 binding contract"))

    g3_decl = only(Tuple(d for d in package.declarations if d.layer === :G3))
    g3_raw = copy_bytes(g3_decl.factory_receipt_bytes)
    g3_decl.factory_receipt_bytes.sha256 ==
        Digest256(bytes2hex(SHA.sha256(g3_raw))) ||
        throw(ArgumentError("N10 G3 factory receipt carrier SHA-256 mismatch"))
    g3_text = String(g3_raw)
    g3_receipt = JSON3.read(g3_text)
    g3_decl.candidate_ref == binding.candidate_ref &&
        _up2_vnext_g2_ref_matches(_n03_get(g3_receipt, :candidate_ref), binding.candidate_ref) &&
        String(_n03_get(g3_receipt, :layer)) == "G3" &&
        _up2_vnext_g2_ref_matches(_n03_get(g3_receipt, :source_ref), g3_decl.source_ref) &&
        _up2_vnext_g2_ref_matches(_n03_get(g3_receipt, :declaration_ref), g3_decl.declaration_ref) ||
        throw(ArgumentError("N10 G3 T1 factory receipt is detached from its declaration"))
    g3_rows = Tuple(x for x in wire_declarations if String(_n03_get(x, :layer)) == "G3")
    length(g3_rows) == 1 || throw(ArgumentError("N10 T0 G3 declaration missing/duplicated"))
    g3_wire_decl = only(g3_rows)
    _up2_vnext_g2_ref_matches(_n03_get(g3_wire_decl, :candidate_ref), binding.candidate_ref) &&
        _up2_vnext_g2_ref_matches(_n03_get(g3_wire_decl, :source_ref), g3_decl.source_ref) &&
        _up2_vnext_g2_ref_matches(_n03_get(g3_wire_decl, :declaration_ref), g3_decl.declaration_ref) ||
        throw(ArgumentError("N10 G3 T0 declaration is detached from T1"))
    g3_wire_result = _n03_get(_n03_get(g3_wire_decl, :factory_receipt), :factory_result)
    g3_wire_result !== nothing &&
        _up2_n10_canonical_json(g3_wire_result) == g3_text ||
        throw(ArgumentError("N10 G3 T1 receipt differs from T0 factory result"))
    g3_ref = _up2_n10_contract_ref_from_wire(_n03_get(g3_receipt, :contract_ref), "G3")
    g3_wire_ref = _up2_n10_contract_ref_from_wire(_n03_get(g3_wire_result, :contract_ref), "G3.wire")
    g3_ref !== nothing && g3_ref == g3_wire_ref == vnext_t0_local_g3_feedback_contract_v1() ||
        throw(ArgumentError("N10 G3 ref differs from published T0 feedback contract"))

    context = (source_version=:vnext_t1_v2_t0_factory_bytes,
        candidate_ref=binding.candidate_ref, package_hash=binding.package_hash,
        semantic_identity=binding.semantic_identity, bundle_hash=binding.bundle_hash,
        contract_refs=(g1=g1_ref, g2=g2_ref, binding=binding_ref),
        g1_context=g1, geometry_context=g2)
    include_source_contract_refs ? merge(context,
        (source_contract_refs=(g1=g1_ref, g2=g2_ref, g3=g3_ref),)) : context
end

"""Return the source-bound G1/G2/G3 declaration refs after a fresh T0/T1 check."""
Base.@noinline Base.@nospecializeinfer function up2_vnext_source_contract_refs_v1(
        package, input::UP2VNextPrecompilerInputV1)
    Base.@nospecialize package input
    context = _up2_vnext_n10_identity_context(package, input.source_binding;
        include_source_contract_refs=true)
    refs = context.source_contract_refs
    all(ref -> ref isa GenomeContractRef, (refs.g1, refs.g2, refs.g3)) ||
        throw(ArgumentError("UP2 source contract ref triplet is not fully typed"))
    (g1=refs.g1, g2=refs.g2, g3=refs.g3)
end

function _up2_vnext_n10_value(spec, context)
    refs = context.contract_refs
    if spec.id == "N10-01"
        refs.g1 === nothing && return UP2AbsentValueV1(spec.source_type,
            :n10_g1_t0_factory_contract_ref_absent)
        return UP2HashValueV1(refs.g1.schema_hash)
    elseif spec.id == "N10-02"
        refs.g2 === nothing && return UP2AbsentValueV1(spec.source_type,
            :n10_g2_t0_factory_contract_ref_absent)
        return UP2HashValueV1(refs.g2.canonicalization_hash)
    elseif spec.id == "N10-03"
        refs.binding === nothing && return UP2AbsentValueV1(spec.source_type,
            :n10_binding_t0_child_contract_ref_absent)
        return UP2ContractRefValueV1(refs.binding)
    elseif spec.id == "N10-04"
        hasproperty(context, :identity_package) || return nothing
        return UP2HashValueV1(context.identity_package.candidate_hash)
    elseif spec.id == "N10-05"
        hasproperty(context, :identity_package) || return nothing
        return UP2TextValueV1(context.identity_package.migration_receipt.candidate_identity_after)
    end
    nothing
end

"""Join an actual V5 identity package to the already source-bound current T1.

The package's N10 projection recomputes its real CandidateStatePackageV5 hash
and fresh receipt. Component-specific joins below prevent a same-candidate
package assembled from unrelated V5 components from entering these rows.
"""
Base.@noinline Base.@nospecializeinfer function _up2_vnext_n10_current_package_context(package, binding, identity_package,
        source_n10_context, g1_context, g2_context, ledger_context)
    Base.@nospecialize package identity_package source_n10_context g1_context g2_context ledger_context
    identity_package isa CandidateStatePackageV5 ||
        throw(ArgumentError("N10-04/05 requires an actual CandidateStatePackageV5"))
    identity_package.candidate_ref == binding.candidate_ref ||
        throw(ArgumentError("N10 V5 identity package candidate differs from current T1"))
    isdefined(@__MODULE__, :n10_identity_projection_from_a) ||
        throw(ArgumentError("N10 actual V5 identity projection is unavailable"))
    projection = getfield(@__MODULE__, :n10_identity_projection_from_a)(identity_package)
    projection.candidate_ref == identity_package.candidate_ref &&
        projection.package_hash == identity_package.candidate_hash &&
        projection.migration_receipt == identity_package.migration_receipt ||
        throw(ArgumentError("N10 identity projection differs from the actual V5 package"))
    n10_04 = getfield(@__MODULE__, :_n10_field)(projection, "N10-04")
    n10_05 = getfield(@__MODULE__, :_n10_field)(projection, "N10-05")
    n10_04.original_value isa N10DigestValueV1 &&
        n10_04.original_value.value == identity_package.candidate_hash &&
        n10_05.original_value isa N10TextValueV1 &&
        n10_05.original_value.value ==
            identity_package.migration_receipt.candidate_identity_after ||
        throw(ArgumentError("N10-04/05 projection values are not the actual package fields"))

    # The G2 wrapper keeps the exact current factory/declaration objects. Join
    # its authored source body to the declaration bytes retained by T1.
    g2_decl = only(Tuple(d for d in package.declarations if d.layer === :G2))
    g2_body = hasproperty(g2_context, :semantic_body) ?
        g2_context.semantic_body :
        JSON3.read(String(copy_bytes(g2_decl.semantic_body_bytes)))
    g2_projection = _n03_get(identity_package.component_identity, :g2_source_projection)
    g2_projection === nothing &&
        throw(ArgumentError("N10 G2 identity lacks its source-aware V5 projection"))
    g2_source = _n03_get(g2_body, :source)
    source_declaration = g2_projection.source_declaration
    _up2_vnext_wire_semantic_equal(g2_source,
        semantic_view(source_declaration.source_payload)) &&
        source_declaration.declaration.contract_ref ==
            _up2_n10_contract_ref_from_wire(_n03_get(g2_body, :contract_ref),
                "G2.T1.semantic_body") ||
        throw(ArgumentError("N10 G2 source projection differs from current T1 authored declaration"))
    g2_projection.genome === identity_package.g2 ||
        throw(ArgumentError("N10 G2 source projection is detached from package component"))

    # G3's component identity stores all builder/child commitments. Join those
    # commitments to T1's byte carriers and to UP2's independent child rebuild.
    g3_decl = only(Tuple(d for d in package.declarations if d.layer === :G3))
    binding_child = only(Tuple(c for c in package.children if c.kind === :binding))
    g3 = identity_package.g3
    isdefined(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) &&
        g3 isa getfield(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) ||
        throw(ArgumentError("N10 G3 identity requires the source-aware typed aggregate"))
    payload = g3.authored_payload
    source_pin = only(Tuple(pin for pin in binding.source_pins
        if pin.role === :g3_child_design))
    payload.candidate_ref == binding.candidate_ref &&
        payload.source_sha256 == source_pin.sha256 &&
        payload.builder_source_sha256 == g3_decl.source_bytes.sha256 &&
        payload.source_admission.source_identity_hash == g3_decl.source_identity_hash &&
        payload.source_admission.declaration_identity_hash == g3_decl.declaration_identity_hash &&
        payload.source_admission.binding_child_identity_hash == binding_child.child_identity_hash &&
        payload.source_admission.child_source_ref == binding_child.source_ref &&
        payload.source_admission.child_source_sha256 == binding_child.source_bytes.sha256 &&
        payload.source_admission.builder_source_ref == g3_decl.source_ref &&
        payload.source_admission.builder_source_sha256 == g3_decl.source_bytes.sha256 ||
        throw(ArgumentError("N10 G3 authored V5 identity is detached from current T1 byte identities"))
    t1_child_identities = Tuple((kind=child.kind, identity_hash=child.child_identity_hash)
        for child in sort(collect(package.children); by=child -> String(child.kind)))
    payload.source_admission.child_identity_hashes == t1_child_identities ||
        throw(ArgumentError("N10 G3 source proof child identities differ from the actual T1 child carriers"))
    g3_verification = _n03_get(identity_package.component_identity, :g3_source_verification)
    g3_verification !== nothing &&
        g3_verification.route === :vnext_t2_materialize_g3_v1 &&
        g3_verification.result === :source_rebuilt &&
        g3_verification.payload_hash == payload.payload_hash &&
        g3_verification.source_admission_hash == canonical_hash(payload.source_admission) &&
        g3_verification.source_context_identity == payload.source_admission.source_context_identity &&
        g3_verification.child_identity_hashes == payload.source_admission.child_identity_hashes ||
        throw(ArgumentError("N10 G3 package proof is absent or detached from its T1/T2 source join"))
    hasproperty(ledger_context, :rebuilt_child_design) &&
        canonical_hash(semantic_view(payload.source_realization)) ==
            canonical_hash(semantic_view(ledger_context.rebuilt_child_design.realization)) &&
        canonical_hash(semantic_view(payload.control_source)) ==
            canonical_hash(semantic_view(ledger_context.rebuilt_child_design.control)) &&
        canonical_hash(semantic_view(payload.network)) ==
            canonical_hash(semantic_view(ledger_context.rebuilt_child_design.resource_network)) ||
        throw(ArgumentError("N10 G3 authored V5 values differ from the independently rebuilt T1 child"))

    # V5 G1 is source-authored as an explicit residual design. Check its typed
    # endpoint fields against the G1 semantic declaration; source expressions
    # remain candidate-design data and are not upgraded into provider evidence.
    g1_decl = only(Tuple(d for d in package.declarations if d.layer === :G1))
    g1_body = hasproperty(g1_context, :semantic_body) ?
        g1_context.semantic_body :
        JSON3.read(String(copy_bytes(g1_decl.semantic_body_bytes)))
    g1_source = _n03_get(g1_body, :source_payload)
    g1_source_identity = _n03_get(identity_package.component_identity,
        :g1_source_projection)
    g1_source_identity isa NamedTuple &&
        all(key -> hasproperty(g1_source_identity, key),
            (:candidate_ref, :source_declaration_ref, :source_bytes_sha256,
             :declaration_identity_hash, :unknown_source_expression_sha256,
             :source_expression_sha256, :source_projection_hash, :g1_candidate_hash)) ||
        throw(ArgumentError("N10 G1 identity omits the source-expression projection"))
    g1_source_identity.candidate_ref == binding.candidate_ref &&
        g1_source_identity.source_declaration_ref == g1_decl.declaration_ref &&
        g1_source_identity.source_bytes_sha256 == g1_decl.source_bytes.sha256 &&
        g1_source_identity.declaration_identity_hash == g1_decl.declaration_identity_hash &&
        g1_source_identity.g1_candidate_hash == identity_package.g1.candidate_hash ||
        throw(ArgumentError("N10 G1 source-expression projection is detached from current T1"))
    g1_states = identity_package.g1.payload.states
    for name in (:u, :K, :f)
        raw = _n03_get(g1_body, name)
        field_id = String(_n03_get(raw, :field_id))
        typed = only(Tuple(state for state in g1_states if state.state_id == field_id))
        signature = _up2_vnext_g1_physical_signature(_n03_get(raw, :physical_type),
            "N10 G1.$(name)")
        typed.physical_type.value_kind === signature.value_kind &&
            typed.physical_type.tensor_rank == signature.tensor_rank &&
            typed.physical_type.spatial_dimension == signature.spatial_dimension &&
            Symbol(typed.physical_type.temporal_type.kind) === signature.temporal_type.kind &&
            typed.physical_type.temporal_type.derivative_order == signature.temporal_type.derivative_order &&
            typed.physical_type.temporal_type.clock_ref == signature.temporal_type.clock_ref &&
            typed.physical_type.units == signature.units ||
            throw(ArgumentError("N10 G1 V5 typed source field $(name) differs from current T1"))
    end
    g1_equations = identity_package.g1.payload.equation_plan.equations
    equation(id) = only(Tuple(x for x in g1_equations if x.equation_id == id))
    apply_node(eq) = only(Tuple(x for x in eq.expression.nodes
        if x isa G1OperatorApplyV2))
    gradient_parameters = apply_node(equation("r2-grad-constraint")).parameters
    source_parameters = apply_node(equation("r2-negative-source-additive")).parameters
    profile_parameters = apply_node(equation("r2-k-affine-profile-constraint")).parameters
    t1_u = _n03_get(g1_source, :u)
    t1_k = _n03_get(_n03_get(g1_source, :K), :expression)
    t1_f = _n03_get(g1_source, :f)
    gradient_parameters.unknown_source_expression ==
        _n03_get(t1_u, :source_expression) &&
        source_parameters.source_expression == _n03_get(t1_f, :source_expression) &&
        profile_parameters.coefficient_base ==
            _up2_vnext_g2_ratios(_n03_get(t1_k, :base_diag), 3, "N10 G1.K.base_diag") &&
        profile_parameters.coefficient_slope ==
            _up2_vnext_g2_ratios(_n03_get(t1_k, :slope_diag), 3, "N10 G1.K.slope_diag") &&
        profile_parameters.coefficient_domain_min ==
            _up2_vnext_g2_ratios(_n03_get(t1_k, :domain_min), 3, "N10 G1.K.domain_min") &&
        profile_parameters.coefficient_domain_max ==
            _up2_vnext_g2_ratios(_n03_get(t1_k, :domain_max), 3, "N10 G1.K.domain_max") ||
        throw(ArgumentError("N10 G1 V5 authored equations do not preserve current T1 u/K/f source expressions"))
    expected_unknown_sha = Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(
        codeunits(String(_n03_get(t1_u, :source_expression)))))))
    expected_source_sha = Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(
        codeunits(String(_n03_get(t1_f, :source_expression)))))))
    source_projection_body = (domain="up4-r2-g1-v5-source-projection-v1",
        candidate_ref=g1_source_identity.candidate_ref,
        source_declaration_ref=g1_source_identity.source_declaration_ref,
        source_bytes_sha256=g1_source_identity.source_bytes_sha256,
        declaration_identity_hash=g1_source_identity.declaration_identity_hash,
        unknown_source_expression_sha256=g1_source_identity.unknown_source_expression_sha256,
        source_expression_sha256=g1_source_identity.source_expression_sha256,
        g1_candidate_hash=g1_source_identity.g1_candidate_hash)
    g1_source_identity.unknown_source_expression_sha256 == expected_unknown_sha &&
        g1_source_identity.source_expression_sha256 == expected_source_sha &&
        g1_source_identity.source_projection_hash == canonical_hash(source_projection_body) ||
        throw(ArgumentError("N10 G1 source-expression SHA/projection hash differs from T1 source bytes"))
    hasproperty(projection, :fields) && length(projection.fields) == 5 ||
        throw(ArgumentError("N10 actual V5 projection does not contain the frozen five rows"))
    all(field -> field isa N10IdentityFieldV1,
        projection.fields) || throw(ArgumentError("N10 projection contains an untyped field"))
    (candidate_ref=binding.candidate_ref, package_hash=binding.package_hash,
        semantic_identity=binding.semantic_identity, bundle_hash=binding.bundle_hash,
        contract_refs=source_n10_context.contract_refs,
        identity_package=identity_package, identity_projection=projection,
        g1_context=g1_context, geometry_context=g2_context)
end

Base.@noinline Base.@nospecializeinfer function _up2_vnext_n10_validation_context(package, binding, identity_package;
        g1_context=nothing, g2_context=nothing, ledger_context=nothing)
    Base.@nospecialize package binding identity_package g1_context g2_context ledger_context
    base = _up2_vnext_n10_identity_context(package, binding;
        g1_context=g1_context, g2_context=g2_context)
    identity_package === nothing && return base
    g1_context = base.g1_context
    geometry_context = base.geometry_context
    if ledger_context === nothing
        ledger_context = _up2_vnext_n04_05_context(package, binding;
            include_child_design=true, identity_package=identity_package)
    else
        ledger_context isa NamedTuple &&
            hasproperty(ledger_context, :rebuilt_child_design) &&
            hasproperty(ledger_context, :package_hash) &&
            hasproperty(ledger_context, :n03_projection_hash) &&
            ledger_context.package_hash == binding.package_hash &&
            ledger_context.n03_projection_hash == binding.n03_projection_hash ||
            throw(ArgumentError("N10 supplied N04-05 context is detached from current T1"))
    end
    current_package_context = _up2_vnext_n10_current_package_context(
        package, binding, identity_package, base, g1_context, geometry_context,
        ledger_context)
    merge(current_package_context, (ledger_context=ledger_context,))
end

function _up2_vnext_field_state(spec, projection; n04_02_present=false,
        n04_01_03_present=false, n04_04_present=false, n04_05_present=false,
        n06_04_present=false, n06_03_present=false, n06_network_present=false,
        n02_04_05_present=false, g1_context=nothing,
        n05_context=nothing, n07n08_context=nothing, n09_context=nothing,
        n10_context=nothing)
    if spec.id in ("N10-04", "N10-05") &&
            n10_context isa NamedTuple && hasproperty(n10_context, :identity_package)
        reason = spec.id == "N10-04" ?
            :current_vnext_t0_t1_component_identity_compatibility_view :
            :current_vnext_t0_t1_fresh_identity_receipt_not_v4_migration
        roles = (:g1_builder, :g1_declaration_source, :g2_builder,
            :g2_declaration_source, :g3_builder, :g3_child_design)
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred, reason, roles)
    end
    if spec.id in ("N10-01", "N10-02", "N10-03") &&
            n10_context isa NamedTuple
        ref = spec.id == "N10-01" ? n10_context.contract_refs.g1 :
            spec.id == "N10-02" ? n10_context.contract_refs.g2 :
            n10_context.contract_refs.binding
        if ref === nothing
            reason = spec.id == "N10-01" ? :n10_g1_t0_factory_contract_ref_absent :
                spec.id == "N10-02" ? :n10_g2_t0_factory_contract_ref_absent :
                :n10_binding_t0_child_contract_ref_absent
            return UP2VNextFieldStateV1(spec.id, :typed_absent, reason)
        end
        roles = spec.id == "N10-01" ? (:g1_builder, :g1_declaration_source) :
            spec.id == "N10-02" ? (:g2_builder, :g2_declaration_source) :
            (:g3_builder, :g3_child_design)
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :current_vnext_t1_t0_typed_ref_not_legacy_v5_identity, roles)
    end
    if spec.id in ("N01-01", "N01-02", "N02-01", "N02-02") &&
            g1_context isa NamedTuple && haskey(g1_context.values, spec.id)
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :candidate_design_g1_operator_type_contract_only,
            (:g1_builder, :g1_declaration_source))
    elseif spec.id in ("N03-01", "N03-02") &&
            g1_context isa NamedTuple && haskey(g1_context.values, spec.id)
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :candidate_design_g1_diffusion_time_contract_only,
            (:g1_builder, :g1_declaration_source))
    elseif spec.id == "N03-03" && g1_context isa NamedTuple &&
            haskey(g1_context.values, spec.id)
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :candidate_design_g1_operator_temporal_whitelist_contract_only,
            (:g1_builder, :g1_declaration_source))
    elseif spec.id in ("N02-04", "N02-05") && n02_04_05_present
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :candidate_design_g3_ledger_unit_design_only,
            (:g3_builder, :g3_child_design))
    elseif spec.id in ("N01-03", "N01-05", "N02-03") &&
            n07n08_context isa NamedTuple &&
            haskey(n07n08_context.values, spec.id) &&
            n07n08_context.cross_state_context !== nothing
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :candidate_design_g1_g2_state_field_binding_contract_only,
            (:g1_builder, :g1_declaration_source,
             :g2_builder, :g2_declaration_source))
    elseif spec.id == "N08-04" && n07n08_context isa NamedTuple &&
            haskey(n07n08_context.values, spec.id) &&
            n07n08_context.cross_state_context !== nothing
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :candidate_design_g2_q1_h1_degree1_basis_contract_only,
            (:g2_builder, :g2_declaration_source))
    elseif spec.id == "N01-04" && n07n08_context isa NamedTuple &&
            hasproperty(n07n08_context, :profile_dimension)
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :candidate_design_g2_profile_contract_only,
            (:g2_builder, :g2_declaration_source))
    elseif spec.id == "N09-01" && n09_context isa NamedTuple &&
            haskey(n09_context.matches, spec.id)
        reason = n09_context.matches[spec.id] === :unique_match ?
            :candidate_design_g1_grad_native_gridap_service_match : :provider_availability_gap
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred, reason,
            (:g1_builder, :g1_declaration_source))
    elseif spec.id in ("N09-02", "N09-03") &&
            n09_context isa NamedTuple && haskey(n09_context.matches, spec.id)
        reason = n09_context.matches[spec.id] !== :unique_match ?
            :provider_availability_gap : spec.id == "N09-02" ?
            :candidate_design_g2_profile_native_gridap_service_match :
            :candidate_design_g2_exterior_native_gridap_service_match
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred, reason,
            (:g2_builder, :g2_declaration_source))
    elseif spec.id == "N09-04" && n09_context isa NamedTuple &&
            haskey(n09_context.matches, spec.id)
        reason = n09_context.matches[spec.id] === :unique_match ?
            :candidate_design_g1_g2_scalar_heat_lift_provider_match : :provider_availability_gap
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred, reason,
            (:g1_builder, :g1_declaration_source,
             :g2_builder, :g2_declaration_source,
             :g3_builder, :g3_child_design))
    elseif spec.id == "N09-05" && n09_context isa NamedTuple &&
            haskey(n09_context.matches, spec.id)
        reason = n09_context.matches[spec.id] === :unique_match ?
            :candidate_design_g3_control_sampled_service_match : :provider_availability_gap
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred, reason,
            (:g3_builder, :g3_child_design))
    end
    if spec.id == "N04-01" && n04_01_03_present
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :candidate_design_ledger_owner_design_only,
            (:g3_builder, :g3_child_design))
    elseif spec.id == "N04-03" && n04_01_03_present
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :candidate_design_ledger_entry_account_design_only,
            (:g3_builder, :g3_child_design))
    elseif spec.id == "N04-02" && n04_02_present
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :candidate_design_ledger_closure_design_only,
            (:g3_builder, :g3_child_design))
    elseif spec.id == "N04-04" && n04_04_present
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :candidate_design_ledger_component_design_only,
            (:g3_builder, :g3_child_design))
    elseif spec.id == "N04-05" && n04_05_present
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :candidate_design_ledger_capacity_design_only,
            (:g3_builder, :g3_child_design))
    elseif spec.id in ("N06-01", "N06-05") && n06_network_present
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :candidate_design_g3_typed_resource_network_contract_only,
            (:g3_builder, :g3_child_design))
    elseif spec.id == "N06-03" && n06_03_present
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :candidate_design_g3_control_flow_link_design_only,
            (:g3_builder, :g3_child_design))
    elseif spec.id == "N06-02"
        if n06_04_present
            return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
                :candidate_design_g3_ledger_entries_design_only,
                (:g3_builder, :g3_child_design))
        end
        return UP2VNextFieldStateV1(spec.id, :typed_absent,
            :candidate_design_typed_ledger_entries_absent)
    elseif spec.id == "N06-04"
        if n06_04_present
            return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
                :candidate_design_g3_closure_balance_design_only,
                (:g3_builder, :g3_child_design))
        end
        return UP2VNextFieldStateV1(spec.id, :typed_absent,
            :candidate_design_typed_ledger_closure_absent)
    elseif spec.id in ("N03-04", "N03-05")
        reason = projection.time_basis === :event ?
            :candidate_design_event_time_policy_design_only :
            :candidate_design_event_time_basis_absent
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred, reason,
            (:g3_builder, :g3_child_design))
    elseif spec.id in ("N05-01", "N05-02", "N05-03", "N05-04") &&
            n05_context isa NamedTuple
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :candidate_design_g1_g2_interface_flux_contract_only,
            (:g1_builder, :g1_declaration_source,
             :g2_builder, :g2_declaration_source))
    elseif spec.id in ("N05-01", "N05-02")
        return UP2VNextFieldStateV1(spec.id, :typed_absent,
            :up2_flux_pair_not_projected_from_vnext_t1)
    elseif spec.id in ("N05-03", "N05-04")
        n05_context isa NamedTuple && return UP2VNextFieldStateV1(spec.id,
            :source_present_deferred,
            :candidate_design_g1_g2_interface_flux_contract_only,
            (:g1_builder, :g1_declaration_source,
             :g2_builder, :g2_declaration_source))
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :g2_interface_normal_is_not_flux_sign_evidence,
            (:g2_builder, :g2_declaration_source))
    elseif spec.class_id in (:N07, :N08)
        n07n08_context isa NamedTuple ||
            throw(ArgumentError("VNext $(spec.id) requires the bound G2 geometry projection"))
        if haskey(n07n08_context.values, spec.id)
            return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
                :candidate_design_g2_geometry_contract_only,
                (:g2_builder, :g2_declaration_source))
        end
        reason = get(n07n08_context.absent_reasons, spec.id,
            :g2_typed_field_projector_absent)
        return UP2VNextFieldStateV1(spec.id, :typed_absent, reason)
    elseif spec.id == "N05-05"
        n05_context isa NamedTuple && return UP2VNextFieldStateV1(spec.id,
            :source_present_deferred,
            :candidate_design_g1_k_apply_output_unit_contract_only,
            (:g1_builder, :g1_declaration_source))
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :g1_input_unit_is_not_flux_unit_evidence,
            (:g1_builder, :g1_declaration_source))
    elseif spec.class_id === :N09
        return UP2VNextFieldStateV1(spec.id, :typed_absent,
            :provider_match_evidence_absent)
    elseif startswith(spec.field_path, "/candidate_state_package/")
        return UP2VNextFieldStateV1(spec.id, :source_present_deferred,
            :vnext_package_identity_not_projected_to_legacy_field)
    end
    roles = _up2_vnext_layer_roles(spec.field_path)
    isempty(roles) && return UP2VNextFieldStateV1(spec.id, :typed_absent,
        :source_field_not_in_vnext_package)
    UP2VNextFieldStateV1(spec.id, :source_present_deferred,
        :pinned_layer_source_field_projector_absent, roles)
end


function _up2_vnext_wire_semantic_equal(wire, value)
    if value isa Bool
        return wire isa Bool && wire == value
    elseif value isa Rational
        wire isa AbstractDict || return false
        numerator_wire = _n03_get(wire, :numerator)
        denominator_wire = _n03_get(wire, :denominator)
        return numerator_wire isa Integer && denominator_wire isa Integer &&
            numerator_wire == numerator(value) &&
            denominator_wire == denominator(value)
    elseif value isa Symbol
        return wire isa AbstractString && String(wire) == String(value)
    elseif value isa AbstractString
        return wire isa AbstractString && String(wire) == String(value)
    elseif value isa Integer
        return wire isa Integer && !(wire isa Bool) && wire == value
    elseif value isa Tuple
        wire isa AbstractVector && length(wire) == length(value) || return false
        return all(_up2_vnext_wire_semantic_equal(wire[i], value[i])
            for i in eachindex(value))
    elseif value isa NamedTuple
        wire isa AbstractDict || return false
        Tuple(sort!(String.(collect(keys(wire))))) ==
            Tuple(sort!(String.(collect(keys(value))))) || return false
        return all(_up2_vnext_wire_semantic_equal(_n03_get(wire, key),
            getproperty(value, key)) for key in keys(value))
    end
    applicable(semantic_view, value) &&
        return _up2_vnext_wire_semantic_equal(wire, semantic_view(value))
    false
end

function _up2_vnext_g2_ratio(value, field::AbstractString)
    numerator_wire = _n03_get(value, :numerator)
    denominator_wire = _n03_get(value, :denominator)
    numerator_wire isa Integer && !(numerator_wire isa Bool) &&
        denominator_wire isa Integer && !(denominator_wire isa Bool) &&
        denominator_wire > 0 || throw(ArgumentError("$field is not an exact positive-denominator rational"))
    typemin(Int64) <= numerator_wire <= typemax(Int64) &&
        1 <= denominator_wire <= typemax(Int64) ||
        throw(ArgumentError("$field exceeds Rational{Int64}"))
    Int64(numerator_wire) // Int64(denominator_wire)
end

function _up2_vnext_g2_ratios(value, arity::Int, field::AbstractString)
    value isa AbstractVector && length(value) == arity ||
        throw(ArgumentError("$field has the wrong rational tuple arity"))
    ntuple(i -> _up2_vnext_g2_ratio(value[i], "$field[$i]"), arity)
end

function _up2_vnext_g2_ref_matches(wire, ref::QualifiedRefV1)
    wire !== nothing && _n03_get(wire, :id) == ref.id &&
        _n03_get(wire, :version) == ref.version
end

function _up2_vnext_g1_temporal_signature(physical_type, label)
    temporal = _n03_get(physical_type, :temporal_type)
    all(name -> _n03_has(temporal, name), (:kind, :derivative_order, :clock_ref)) ||
        throw(ArgumentError("VNext G1 $label temporal_type is incomplete"))
    kind = _n03_get(temporal, :kind)
    order = _n03_get(temporal, :derivative_order)
    clock = _n03_get(temporal, :clock_ref)
    kind == "static_time" && order isa Integer && !(order isa Bool) &&
        order == 0 && clock === nothing ||
        throw(ArgumentError("VNext G1 $label is not static_time/order0/clockless"))
    (kind=:static_time, derivative_order=0, clock_ref=nothing)
end

function _up2_vnext_g1_physical_signature(wire, label)
    value_kind = _n03_get(wire, :value_kind)
    rank = _n03_get(wire, :tensor_rank)
    dimension = _n03_get(wire, :spatial_dimension)
    value_kind isa AbstractString && !isempty(String(value_kind)) &&
        rank isa Integer && !(rank isa Bool) && rank >= 0 &&
        dimension isa Integer && !(dimension isa Bool) && dimension >= 1 ||
        throw(ArgumentError("VNext G1 $label has an invalid PhysicalType shape"))
    (value_kind=Symbol(String(value_kind)), tensor_rank=Int(rank),
        spatial_dimension=Int(dimension),
        temporal_type=_up2_vnext_g1_temporal_signature(wire, label),
        units=_up2_vnext_unit_signature(_n03_get(wire, :units)))
end

"""Project the G1 scalar endpoint types from a source-pinned T1 declaration."""
Base.@noinline Base.@nospecializeinfer function _up2_vnext_g1_operator_type_context(package,
        binding::UP2VNextSourceBindingV1; include_semantic_body=false)
    Base.@nospecialize package binding include_semantic_body
    package isa CandidateStatePackageV5NextV2 ||
        throw(ArgumentError("VNext G1 operator types require CandidateStatePackageV5NextV2"))
    package.package_hash == binding.package_hash &&
        package.semantic_identity == binding.semantic_identity &&
        package.bundle_hash == binding.bundle_hash ||
        throw(ArgumentError("VNext G1 package identity differs from the source binding"))
    declarations = Tuple(d for d in package.declarations if d.layer === :G1)
    length(declarations) == 1 ||
        throw(ArgumentError("VNext G1 operator types require one T1 G1 declaration"))
    declaration = only(declarations)
    declaration.candidate_ref == binding.candidate_ref ||
        throw(ArgumentError("VNext G1 declaration candidate differs from the source binding"))
    body_bytes = copy_bytes(declaration.semantic_body_bytes)
    declaration.semantic_body_bytes.sha256 ==
        Digest256(bytes2hex(SHA.sha256(body_bytes))) ||
        throw(ArgumentError("VNext G1 semantic body bytes/hash mismatch"))
    body = JSON3.read(String(body_bytes))
    _up2_vnext_g2_ref_matches(_n03_get(body, :candidate_ref), binding.candidate_ref) &&
        _up2_vnext_g2_ref_matches(_n03_get(body, :source_ref), declaration.source_ref) ||
        throw(ArgumentError("VNext G1 semantic body identity differs from its declaration"))

    declaration_pins = Tuple(pin for pin in binding.source_pins
        if pin.role === :g1_declaration_source)
    builder_pins = Tuple(pin for pin in binding.source_pins
        if pin.role === :g1_builder)
    length(declaration_pins) == 1 && length(builder_pins) == 1 ||
        throw(ArgumentError("VNext G1 declaration/builder source pins are absent or ambiguous"))
    declaration_pin, builder_pin = only(declaration_pins), only(builder_pins)
    isdefined(@__MODULE__, :_n03_vnext_carrier_matches) &&
        _n03_vnext_carrier_matches(declaration.source_bytes, declaration_pin) ||
        throw(ArgumentError("VNext G1 declaration source differs from its source pin"))
    isdefined(@__MODULE__, :_n03_vnext_semantic_input_matches) &&
        _n03_vnext_semantic_input_matches(declaration, :authored_builder_input,
            builder_pin) ||
        throw(ArgumentError("VNext G1 authored builder input differs from its source pin"))

    operators = _n03_get(body, :operators)
    grad, coefficient_apply, div = _n03_get(operators, :grad),
        _n03_get(operators, :coefficient_apply), _n03_get(operators, :div)
    grad_input, grad_output = _n03_get(grad, :input_type), _n03_get(grad, :output_type)
    apply_input, apply_output = _n03_get(coefficient_apply, :input_type),
        _n03_get(coefficient_apply, :output_type)
    div_input, div_output = _n03_get(div, :input_type), _n03_get(div, :output_type)
    u, coefficient, f = _n03_get(body, :u), _n03_get(body, :K), _n03_get(body, :f)
    u_type, coefficient_type, f_type = _n03_get(u, :physical_type),
        _n03_get(coefficient, :physical_type), _n03_get(f, :physical_type)

    # The frozen equation locators name the temporal kind/order of this whole
    # diffusion equation. Project them only when every field and operator
    # endpoint carries the same static, order-zero, clockless semantics.
    temporal_nodes = (("u", u_type), ("K", coefficient_type), ("f", f_type),
        ("GRAD.input", grad_input), ("GRAD.output", grad_output),
        ("K_APPLY.input", apply_input), ("K_APPLY.output", apply_output),
        ("DIV.input", div_input), ("DIV.output", div_output))
    temporal_signatures = Tuple(_up2_vnext_g1_temporal_signature(
        node[2], node[1]) for node in temporal_nodes)
    all(signature -> signature == first(temporal_signatures), temporal_signatures) ||
        throw(ArgumentError("VNext G1 diffusion temporal endpoints disagree"))

    u_field, coefficient_field, f_field = _n03_get(u, :field_id),
        _n03_get(coefficient, :field_id), _n03_get(f, :field_id)
    _n03_get(grad, :input_field_id) == u_field &&
        _n03_get(grad, :output_field_id) == _n03_get(coefficient_apply, :input_field_id) &&
        _n03_get(coefficient_apply, :output_field_id) == _n03_get(div, :input_field_id) &&
        _n03_get(div, :output_field_id) == f_field &&
        _n03_get(coefficient_apply, :coefficient_field_id) == coefficient_field ||
        throw(ArgumentError("VNext G1 diffusion field/operator chain is not closed"))
    _up2_vnext_g1_physical_signature(u_type, "u") ==
        _up2_vnext_g1_physical_signature(grad_input, "GRAD.input") &&
        _up2_vnext_g1_physical_signature(grad_output, "GRAD.output") ==
        _up2_vnext_g1_physical_signature(apply_input, "K_APPLY.input") &&
        _up2_vnext_g1_physical_signature(apply_output, "K_APPLY.output") ==
        _up2_vnext_g1_physical_signature(div_input, "DIV.input") &&
        _up2_vnext_g1_physical_signature(div_output, "DIV.output") ==
        _up2_vnext_g1_physical_signature(f_type, "f") ||
        throw(ArgumentError("VNext G1 diffusion PhysicalType chain is not closed"))
    _up2_vnext_unit_signature(_n03_get(coefficient_apply, :coefficient_units)) ==
        _up2_vnext_unit_signature(_n03_get(coefficient_type, :units)) ||
        throw(ArgumentError("VNext G1 K_APPLY coefficient units differ from K"))

    grad_input = _n03_get(grad, :input_type)
    grad_rank, div_rank = _n03_get(grad_input, :tensor_rank),
        _n03_get(div_output, :tensor_rank)
    u_rank, f_rank = _n03_get(u_type, :tensor_rank), _n03_get(f_type, :tensor_rank)
    grad_unit = _up2_vnext_unit_signature(_n03_get(grad_input, :units))
    div_unit = _up2_vnext_unit_signature(_n03_get(div_output, :units))
    _n03_get(grad, :input_field_id) == _n03_get(u, :field_id) &&
        grad_rank == u_rank && grad_unit == _up2_vnext_unit_signature(_n03_get(u_type, :units)) &&
        _n03_get(div, :output_field_id) == _n03_get(f, :field_id) &&
        div_rank == f_rank && div_unit == _up2_vnext_unit_signature(_n03_get(f_type, :units)) ||
        throw(ArgumentError("VNext G1 GRAD/DIV endpoint types do not match authored scalar fields"))
    all(rank -> rank isa Integer && !(rank isa Bool) && rank == 0,
        (grad_rank, div_rank)) ||
        throw(ArgumentError("VNext G1 scalar endpoint tensor ranks are invalid"))
    grad_unit = _up2_vnext_unit_signature(_n03_get(grad_input, :units))
    div_unit = _up2_vnext_unit_signature(_n03_get(div_output, :units))
    source_payload = _n03_get(body, :source_payload)
    unknown_binding_wire = _n03_get(source_payload, :unknown_state_binding)
    unknown_state_binding = nothing
    if unknown_binding_wire !== nothing
        state_index = _n03_get(unknown_binding_wire, :state_index)
        role = _n03_get(unknown_binding_wire, :role)
        field_id = _n03_get(unknown_binding_wire, :field_id)
        binding_type = _n03_get(unknown_binding_wire, :physical_type)
        state_index isa Integer && !(state_index isa Bool) && state_index == 0 &&
            role == "unknown" && field_id isa AbstractString &&
            String(field_id) == String(u_field) ||
            throw(ArgumentError("VNext G1 unknown-state binding is malformed or does not identify u"))
        binding_signature = _up2_vnext_g1_physical_signature(binding_type,
            "source_payload.unknown_state_binding")
        u_signature = _up2_vnext_g1_physical_signature(u_type, "u")
        binding_signature == u_signature ||
            throw(ArgumentError("VNext G1 unknown-state PhysicalType differs from u"))
        unknown_state_binding = (state_index=0, role=:unknown,
            field_id=String(field_id), physical_signature=binding_signature)
    end
    # Optional candidate-authored G1 interface-flux pair.  It is parsed from
    # the pinned typed declaration body; G2 geometry is independently checked
    # by _up2_vnext_n05_flux_context before this is admitted as a UP2 row.
    interface_flux_wire = _n03_get(source_payload, :interface_flux_pair)
    interface_flux_pair = nothing
    if interface_flux_wire !== nothing
        interface_ref_wire = _n03_get(interface_flux_wire, :interface_ref)
        operator_ref_wire = _n03_get(interface_flux_wire, :operator_ref)
        _n03_get(operator_ref_wire, :id) ==
            _n03_get(_n03_get(coefficient_apply, :operator_ref), :id) &&
            _n03_get(operator_ref_wire, :version) == "v1" &&
            _n03_get(interface_flux_wire, :field_id) == _n03_get(coefficient_apply, :output_field_id) ||
            throw(ArgumentError("VNext G1 interface-flux pair is not bound to K_APPLY output"))
        apply_output_type = _n03_get(coefficient_apply, :output_type)
        _n03_get(apply_output_type, :value_kind) == "vector_field" &&
            _n03_get(apply_output_type, :tensor_rank) == 1 &&
            _n03_get(apply_output_type, :spatial_dimension) == 3 ||
            throw(ArgumentError("VNext G1 interface-flux pair requires a three-dimensional K_APPLY vector output"))
        left_normal_wire = _n03_get(interface_flux_wire, :left_outward_normal)
        right_normal_wire = _n03_get(interface_flux_wire, :right_outward_normal)
        left_normal_wire isa AbstractVector && length(left_normal_wire) == 3 &&
            right_normal_wire isa AbstractVector && length(right_normal_wire) == 3 ||
            throw(ArgumentError("VNext G1 interface-flux pair normals are malformed"))
        interface_flux_pair = (
            interface_ref=QualifiedRefV1(String(_n03_get(interface_ref_wire, :id)),
                String(_n03_get(interface_ref_wire, :version))),
            left_region=String(_n03_get(interface_flux_wire, :left_region_id)),
            right_region=String(_n03_get(interface_flux_wire, :right_region_id)),
            left_port=String(_n03_get(interface_flux_wire, :left_port_id)),
            right_port=String(_n03_get(interface_flux_wire, :right_port_id)),
            operator_ref=QualifiedRefV1(String(_n03_get(operator_ref_wire, :id)),
                String(_n03_get(operator_ref_wire, :version))),
            field_id=String(_n03_get(interface_flux_wire, :field_id)),
            left_normal=ntuple(i -> Int(left_normal_wire[i]), 3),
            right_normal=ntuple(i -> Int(right_normal_wire[i]), 3),
            left_sign=Int(_n03_get(interface_flux_wire, :left_sign)),
            right_sign=Int(_n03_get(interface_flux_wire, :right_sign)),
            unit=_up2_vnext_unit_signature(_n03_get(apply_output_type, :units)),
            law=Symbol(String(_n03_get(interface_flux_wire, :law))))
        interface_flux_pair.left_normal in ((1,0,0), (0,1,0), (0,0,1)) &&
            interface_flux_pair.right_normal == ntuple(i -> -interface_flux_pair.left_normal[i], 3) &&
            interface_flux_pair.left_sign == 1 && interface_flux_pair.right_sign == -1 &&
            interface_flux_pair.law === :left_outward_flux_plus_right_outward_flux_equals_zero ||
            throw(ArgumentError("VNext G1 interface-flux pair has an unsupported orientation or manufactured law"))
    end
    temporal_support_wire = _n03_get(source_payload, :operator_temporal_support)
    operator_temporal_kinds = nothing
    if temporal_support_wire !== nothing
        valid_time_kinds = Tuple(Symbol(kind) for kind in instances(TimeKindV1))
        support_records = (
            (:grad, grad, _n03_get(grad, :input_type), _n03_get(grad, :output_type)),
            (:coefficient_apply, coefficient_apply,
                _n03_get(coefficient_apply, :input_type),
                _n03_get(coefficient_apply, :output_type)),
            (:div, div, _n03_get(div, :input_type), _n03_get(div, :output_type)))
        for (name, operator, input_type, output_type) in support_records
            support = _n03_get(temporal_support_wire, name)
            support_ref = _n03_get(support, :operator_ref)
            operator_ref = _n03_get(operator, :operator_ref)
            _n03_get(support_ref, :id) == _n03_get(operator_ref, :id) &&
                _n03_get(support_ref, :version) == _n03_get(operator_ref, :version) ||
                throw(ArgumentError("VNext G1 $name temporal whitelist names a different operator"))
            kinds_wire = _n03_get(support, :temporal_kinds)
            kinds_wire isa AbstractVector && !isempty(kinds_wire) &&
                all(kind -> kind isa AbstractString, kinds_wire) ||
                throw(ArgumentError("VNext G1 $name temporal whitelist is not a nonempty TimeKindV1 tuple"))
            kinds = Tuple(Symbol(String(kind)) for kind in kinds_wire)
            all(kind -> kind in valid_time_kinds, kinds) &&
                length(unique(kinds)) == length(kinds) ||
                throw(ArgumentError("VNext G1 $name temporal whitelist has invalid or duplicate TimeKindV1 members"))
            input_temporal = _up2_vnext_g1_temporal_signature(input_type,
                String(name) * ".input")
            output_temporal = _up2_vnext_g1_temporal_signature(output_type,
                String(name) * ".output")
            input_temporal.kind in kinds && output_temporal.kind in kinds ||
                throw(ArgumentError("VNext G1 $name temporal whitelist excludes an authored endpoint kind"))
            name === :grad && (operator_temporal_kinds = kinds)
        end
    end
    values = Dict{String,Any}(
        "N01-01" => Int(grad_rank),
        "N01-02" => Int(div_rank),
        "N02-01" => grad_unit,
        "N02-02" => div_unit,
        "N03-01" => :static_time,
        "N03-02" => 0)
    operator_temporal_kinds === nothing ||
        (values["N03-03"] = operator_temporal_kinds)
    projection_hash_body = (candidate_ref=binding.candidate_ref,
        package_hash=binding.package_hash, semantic_identity=binding.semantic_identity,
        bundle_hash=binding.bundle_hash, declaration_ref=declaration.declaration_ref,
        declaration_hash=declaration.declaration_identity_hash,
        source_ref=declaration.source_ref,
        semantic_body_sha256=declaration.semantic_body_bytes.sha256,
        builder_sha256=builder_pin.sha256,
        declaration_source_sha256=declaration_pin.sha256,
        values=values)
    projection_hash = canonical_hash(unknown_state_binding === nothing ?
        projection_hash_body :
        merge(projection_hash_body, (unknown_state_binding=unknown_state_binding,)))
    context = (candidate_ref=binding.candidate_ref, package_hash=binding.package_hash,
        semantic_identity=binding.semantic_identity, bundle_hash=binding.bundle_hash,
        declaration_ref=declaration.declaration_ref,
        declaration_hash=declaration.declaration_identity_hash,
        source_ref=declaration.source_ref, unknown_state_binding=unknown_state_binding,
        interface_flux_pair=interface_flux_pair,
        projection_hash=projection_hash,
        values=values)
    context = operator_temporal_kinds === nothing ? context :
        merge(context, (operator_temporal_kinds=operator_temporal_kinds,))
    include_semantic_body ? merge(context, (semantic_body=body,)) : context
end

"""Read only N07/N08 fields whose semantics are explicit in the bound T1 G2 body.

The VNext G2 source is G2MetricBoundary V1, not a serialized legacy G2 V5 graph.
Fields without a direct or frozen equivalent remain typed absent.
"""
Base.@noinline Base.@nospecializeinfer function _up2_vnext_g2_geometry_context(package,
        binding::UP2VNextSourceBindingV1, g1_context=nothing;
        include_semantic_body=false)
    Base.@nospecialize package binding g1_context include_semantic_body
    package isa CandidateStatePackageV5NextV2 ||
        throw(ArgumentError("VNext G2 geometry requires CandidateStatePackageV5NextV2"))
    package.package_hash == binding.package_hash &&
        package.semantic_identity == binding.semantic_identity &&
        package.bundle_hash == binding.bundle_hash ||
        throw(ArgumentError("VNext G2 geometry package identity differs from the source binding"))
    declarations = Tuple(d for d in package.declarations if d.layer === :G2)
    length(declarations) == 1 ||
        throw(ArgumentError("VNext G2 geometry requires one T1 G2 declaration"))
    declaration = only(declarations)
    declaration.candidate_ref == binding.candidate_ref ||
        throw(ArgumentError("VNext G2 declaration candidate differs from the source binding"))
    body_bytes = copy_bytes(declaration.semantic_body_bytes)
    declaration.semantic_body_bytes.sha256 ==
        Digest256(bytes2hex(SHA.sha256(body_bytes))) ||
        throw(ArgumentError("VNext G2 semantic body bytes/hash mismatch"))
    body = JSON3.read(String(body_bytes))
    _up2_vnext_g2_ref_matches(_n03_get(body, :candidate_ref), binding.candidate_ref) ||
        throw(ArgumentError("VNext G2 semantic body candidate differs from the source binding"))
    envelope = _n03_get(body, :candidate_envelope)
    source = _n03_get(body, :source)
    envelope !== nothing && source !== nothing ||
        throw(ArgumentError("VNext G2 semantic body lacks its source envelope"))
    _up2_vnext_g2_ref_matches(_n03_get(envelope, :candidate_ref), binding.candidate_ref) ||
        throw(ArgumentError("VNext G2 candidate envelope is not bound to the candidate"))
    _up2_vnext_g2_ref_matches(_n03_get(source, :source_ref), declaration.source_ref) &&
        _up2_vnext_g2_ref_matches(_n03_get(envelope, :source_ref), declaration.source_ref) ||
        throw(ArgumentError("VNext G2 source ref differs from the T1 declaration"))
    source_hash = _n03_get(source, :source_hash)
    source_hash_value = _n03_get(source_hash, :value)
    envelope_source_hash = _n03_get(_n03_get(envelope, :source_hash), :value)
    source_hash_value isa AbstractString &&
        source_hash_value == envelope_source_hash ||
        throw(ArgumentError("VNext G2 source envelope hash differs from its source"))

    declaration_pin = Tuple(pin for pin in binding.source_pins
        if pin.role === :g2_declaration_source)
    length(declaration_pin) == 1 ||
        throw(ArgumentError("VNext G2 geometry requires one declaration-source pin"))
    declaration_source_pin = only(declaration_pin)
    isdefined(@__MODULE__, :_n03_vnext_carrier_matches) &&
        _n03_vnext_carrier_matches(declaration.source_bytes,
            declaration_source_pin) ||
        throw(ArgumentError("VNext G2 declaration source differs from its production-source pin"))
    builder_pin = Tuple(pin for pin in binding.source_pins if pin.role === :g2_builder)
    length(builder_pin) == 1 ||
        throw(ArgumentError("VNext G2 geometry requires one candidate builder pin"))
    pin = only(builder_pin)
    isdefined(@__MODULE__, :_n03_vnext_semantic_input_matches) &&
        _n03_vnext_semantic_input_matches(declaration,
            :authored_builder_input, pin) ||
        throw(ArgumentError("VNext G2 authored builder input differs from its candidate-builder pin"))

    chart = _n03_get(source, :chart_map)
    mesh = _n03_get(source, :mesh)
    profile = _n03_get(source, :profile)
    faces_wire = _n03_get(source, :faces)
    chart !== nothing && mesh !== nothing && profile !== nothing &&
        faces_wire isa AbstractVector ||
        throw(ArgumentError("VNext G2 typed source lacks chart, mesh, profile, or faces"))
    _n03_get(chart, :map_kind) == "affine" ||
        throw(ArgumentError("VNext G2 chart map kind is unsupported"))
    lower = _up2_vnext_g2_ratios(_n03_get(chart, :domain_lower), 3,
        "G2MBChartMapV1.domain_lower")
    upper = _up2_vnext_g2_ratios(_n03_get(chart, :domain_upper), 3,
        "G2MBChartMapV1.domain_upper")
    all(lower[i] < upper[i] for i in 1:3) ||
        throw(ArgumentError("VNext G2 chart domain is not strictly ordered"))
    jacobian_wire = _n03_get(chart, :jacobian_rows)
    jacobian_wire isa AbstractVector && length(jacobian_wire) == 3 ||
        throw(ArgumentError("VNext G2 chart Jacobian is not 3 by 3"))
    jacobian = ntuple(i -> _up2_vnext_g2_ratios(jacobian_wire[i], 3,
        "G2MBChartMapV1.jacobian_rows[$i]"), 3)
    offset = _up2_vnext_g2_ratios(_n03_get(chart, :offset), 3,
        "G2MBChartMapV1.offset")
    identity_jacobian = jacobian == ((1 // 1, 0 // 1, 0 // 1),
        (0 // 1, 1 // 1, 0 // 1), (0 // 1, 0 // 1, 1 // 1))
    map_kind = identity_jacobian && all(iszero, offset) ? :identity : :declared_map

    # G2RegionV2.lower/upper are bounds in the represented region coordinates.
    # The chart domain is a valid lossless rectangular region only when this
    # affine map is monomial (axis permutation/scaling plus translation).
    # For that case, map all eight exact corners to obtain the physical AABB.
    monomial_map = all(count(x -> !iszero(x), row) == 1 for row in jacobian) &&
        all(count(j -> !iszero(jacobian[j][i]), 1:3) == 1 for i in 1:3)
    image_bounds = if monomial_map
        corners = ntuple(n -> ntuple(i ->
            (((n - 1) >> (i - 1)) & 1) == 1 ? upper[i] : lower[i], 3), 8)
        images = ntuple(n -> ntuple(i -> offset[i] +
            sum(jacobian[i][j] * corners[n][j] for j in 1:3), 3), 8)
        ntuple(i -> (minimum(p[i] for p in images),
            maximum(p[i] for p in images)), 3)
    else
        nothing
    end

    expected_faces = (:x_max, :x_min, :y_max, :y_min, :z_max, :z_min)
    face_ids = String[]
    faces = Symbol[]
    owner_regions = String[]
    boundary_kinds = Symbol[]
    face_values = NamedTuple[]
    face_normals = Dict(:x_min => (-1, 0, 0), :x_max => (1, 0, 0),
        :y_min => (0, -1, 0), :y_max => (0, 1, 0),
        :z_min => (0, 0, -1), :z_max => (0, 0, 1))
    for (index, face_wire) in enumerate(faces_wire)
        face = Symbol(String(_n03_get(face_wire, :face)))
        face in keys(face_normals) ||
            throw(ArgumentError("VNext G2 face[$index] is outside the frozen Cartesian boundary enum"))
        normal_wire = _n03_get(face_wire, :reference_normal)
        normal_wire isa AbstractVector && length(normal_wire) == 3 &&
            Tuple(Int(x) for x in normal_wire) == face_normals[face] ||
            throw(ArgumentError("VNext G2 face[$index] normal does not match its declared face"))
        push!(face_ids, String(_n03_get(face_wire, :face_id)))
        push!(faces, face)
        push!(owner_regions, String(_n03_get(face_wire, :owner_region_id)))
        value = _n03_get(face_wire, :value)
        kind = Symbol(String(_n03_get(value, :kind)))
        kind in (:dirichlet, :neumann) ||
            throw(ArgumentError("VNext G2 face[$index] boundary kind is unsupported"))
        push!(boundary_kinds, kind)
        exact_value = _up2_vnext_g2_ratio(_n03_get(value, :value),
            "G2MBFaceV1.value[$index]")
        push!(face_values, (face=face, face_id=String(_n03_get(face_wire, :face_id)),
            owner_region_id=String(_n03_get(face_wire, :owner_region_id)),
            reference_normal=face_normals[face], kind=kind, value=exact_value))
    end
    region_interface_wire = _n03_get(source, :region_interface)
    region_exterior_owners_wire = _n03_get(source, :region_exterior_owners)
    if region_interface_wire === nothing
        region_exterior_owners_wire === nothing ||
            throw(ArgumentError("VNext G2 source has region owners without a region interface"))
        length(faces) == 6 && Tuple(sort(copy(faces); by=String)) == expected_faces &&
            length(unique(face_ids)) == 6 && length(unique(owner_regions)) == 1 &&
            only(unique(owner_regions)) == "local_unit_cube" ||
            throw(ArgumentError("VNext G2 source does not declare one complete six-face exterior"))
    else
        length(faces) == 6 && Tuple(sort(copy(faces); by=String)) == expected_faces &&
            length(unique(face_ids)) == 6 && length(unique(owner_regions)) == 1 &&
            only(unique(owner_regions)) == "local_unit_cube" ||
            throw(ArgumentError("VNext G2 partition source has malformed parent-domain faces"))
        region_exterior_owners_wire isa AbstractVector && length(region_exterior_owners_wire) == 10 ||
            throw(ArgumentError("VNext G2 partition source lacks its ten authored region exterior owners"))
    end
    condition = length(unique(boundary_kinds)) == 1 ? first(boundary_kinds) : :mixed

    axes_wire = _n03_get(chart, :axes)
    chart_axes = nothing
    if axes_wire !== nothing
        axes_wire isa AbstractVector && length(axes_wire) == 3 &&
            all(axis -> axis isa AbstractString, axes_wire) ||
            throw(ArgumentError("VNext G2 chart axes are not a three-symbol tuple"))
        axes = Tuple(Symbol(String(axis)) for axis in axes_wire)
        all(axis -> axis in (:x, :y, :z), axes) &&
            length(unique(axes)) == 3 ||
            throw(ArgumentError("VNext G2 chart axes are not unique Cartesian labels"))
        chart_axes = axes
    end

    cells_wire = _n03_get(mesh, :cells)
    cells_wire isa AbstractVector && length(cells_wire) == 3 &&
        all(x -> x isa Integer && !(x isa Bool) && 1 <= x <= typemax(Int), cells_wire) ||
        throw(ArgumentError("VNext G2 mesh cells are not three positive Int values"))
    cells = ntuple(i -> Int(cells_wire[i]), 3)
    chart_ref_wire = _n03_get(chart, :chart_ref)
    mesh_chart_ref_wire = _n03_get(mesh, :chart_ref)
    _n03_get(mesh_chart_ref_wire, :id) == _n03_get(chart_ref_wire, :id) &&
        _n03_get(mesh_chart_ref_wire, :version) == _n03_get(chart_ref_wire, :version) &&
        _n03_get(profile, :dimension) == 3 &&
        _n03_get(profile, :topology) == "cartesian" ||
        throw(ArgumentError("VNext G2 profile is outside the 3D Cartesian projection scope"))

    field_space_wire = _n03_get(source, :field_space)
    q1_interpretation = _n03_get(source, :q1_interpretation)
    cross_state_context = nothing
    cross_state_projection_hash = nothing
    cross_values = Dict{String,Any}()
    if field_space_wire !== nothing || q1_interpretation !== nothing
        field_space_wire !== nothing &&
            q1_interpretation == "continuous_tensor_product_lagrange_degree1_h1" ||
            throw(ArgumentError("VNext G2 field-space/Q1 interpretation declaration is incomplete or unsupported"))
        state_field_id = _n03_get(field_space_wire, :state_field_id)
        value_shape = _n03_get(field_space_wire, :value_shape)
        state_unit = _n03_get(field_space_wire, :state_unit)
        state_unit_signature = _up2_vnext_unit_signature(
            _n03_get(field_space_wire, :state_unit_signature))
        field_value_unit = _up2_vnext_unit_signature(
            _n03_get(_n03_get(source, :units), :field_value))
        profile_basis_family = _n03_get(profile, :basis_family)
        mesh_basis = _n03_get(mesh, :basis)
        state_field_id isa AbstractString && !isempty(String(state_field_id)) &&
            value_shape == "scalar" && state_unit == "1" &&
            state_unit_signature == UnitSignature() &&
            state_unit_signature == field_value_unit &&
            mesh_basis == "Q1" && profile_basis_family == "tensor_product" ||
            throw(ArgumentError("VNext G2 field-space or declared Q1/H1 semantics are inconsistent"))
        g1 = g1_context === nothing ?
            _up2_vnext_g1_operator_type_context(package, binding) : g1_context
        g1_binding = g1.unknown_state_binding
        g1_binding isa NamedTuple ||
            throw(ArgumentError("VNext G2 field-space is present without a G1 unknown-state binding"))
        g1_type = g1_binding.physical_signature
        g1_binding.state_index == 0 && g1_binding.role === :unknown &&
            g1_binding.field_id == String(state_field_id) &&
            g1_type.value_kind === :scalar_field && g1_type.tensor_rank == 0 &&
            g1_type.spatial_dimension == Int(_n03_get(profile, :dimension)) &&
            g1_type.units == state_unit_signature ||
            throw(ArgumentError("VNext G1/G2 state field identity, shape, or unit does not agree"))
        cross_values["N01-03"] = g1_type.tensor_rank
        cross_values["N01-05"] = Symbol(String(value_shape))
        cross_values["N02-03"] = String(state_unit)
        # The authored interpretation explicitly binds Q1 to continuous
        # tensor-product degree-one Lagrange H1; the legacy basis value is linear.
        cross_values["N08-04"] = :linear
        cross_state_context = (state_field_id=String(state_field_id),
            value_shape=:scalar, state_unit=String(state_unit),
            state_unit_signature=state_unit_signature,
            q1_interpretation=:continuous_tensor_product_lagrange_degree1_h1,
            g1_state_index=0, g1_role=:unknown,
            g1_field_id=g1_binding.field_id,
            g1_physical_signature=g1_type)
        cross_state_projection_hash = g1.projection_hash
    end

    values = Dict{String,Any}(
        "N07-03" => Tuple(faces),
        "N07-05" => condition,
        "N08-02" => map_kind,
        "N08-03" => cells)
    merge!(values, cross_values)
    chart_axes === nothing || (values["N08-01"] = chart_axes)
    absent_reasons = Dict{String,Symbol}(
        "N07-04" => :g2mb_source_has_no_boundary_patch,
        "N08-01" => :g2mb_chart_has_no_coordinate_axis_labels,
        "N08-04" => :g2mb_q1_basis_equivalence_not_frozen,
        "N08-05" => :g2mb_source_has_no_internal_interfaces)
    region_interface_present = false
    region_interface_exterior_owners_validated = false
    interface_flux_geometry = nothing
    if region_interface_wire !== nothing
        regions_wire = _n03_get(region_interface_wire, :regions)
        interfaces_wire = _n03_get(region_interface_wire, :interfaces)
        regions_wire isa AbstractVector && length(regions_wire) == 2 &&
            interfaces_wire isa AbstractVector && length(interfaces_wire) == 1 ||
            throw(ArgumentError("VNext G2 topology is outside the exact two-region partition contract"))
        left, right = regions_wire
        interface = only(interfaces_wire)
        region_ids = (String(_n03_get(left, :region_id)),
            String(_n03_get(right, :region_id)))
        region_ids[1] != region_ids[2] ||
            throw(ArgumentError("VNext G2 partition region identities are not unique"))
        left_lower = _up2_vnext_g2_ratios(_n03_get(left, :lower), 3,
            "G2RegionV2.lower")
        left_upper = _up2_vnext_g2_ratios(_n03_get(left, :upper), 3,
            "G2RegionV2.upper")
        right_lower = _up2_vnext_g2_ratios(_n03_get(right, :lower), 3,
            "G2RegionV2.lower")
        right_upper = _up2_vnext_g2_ratios(_n03_get(right, :upper), 3,
            "G2RegionV2.upper")
        left_lower == lower && right_upper == upper &&
            all(left_lower[i] < left_upper[i] && right_lower[i] < right_upper[i]
                for i in 1:3) ||
            throw(ArgumentError("VNext G2 regions do not cover valid bounded chart boxes"))
        all(_n03_get(left, key) == _n03_get(right, key)
            for key in (:chart_ref, :embedding_ref, :field_space_ref)) ||
            throw(ArgumentError("VNext G2 partition region refs are inconsistent"))
        region_chart_ref = _n03_get(left, :chart_ref)
        String(_n03_get(region_chart_ref, :id)) ==
            String(_n03_get(_n03_get(chart, :chart_ref), :id)) &&
            String(_n03_get(region_chart_ref, :version)) == "v2" &&
            String(_n03_get(_n03_get(chart, :chart_ref), :version)) == "v1" ||
            throw(ArgumentError("VNext G2 region chart refs do not bind the declared chart"))
        axis_value = _n03_get(interface, :axis)
        axis_value isa Integer && 1 <= axis_value <= 3 ||
            throw(ArgumentError("VNext G2 interface axis is invalid"))
        axis = Int(axis_value)
        coordinate = _up2_vnext_g2_ratio(_n03_get(interface, :coordinate),
            "G2InterfaceV2.coordinate")
        left_upper[axis] == coordinate && right_lower[axis] == coordinate &&
            all(left_lower[i] == right_lower[i] && left_upper[i] == right_upper[i] &&
                left_lower[i] == lower[i] && left_upper[i] == upper[i]
                for i in 1:3 if i != axis) ||
            throw(ArgumentError("VNext G2 interface is not an exact full-face partition"))
        String(_n03_get(interface, :left_region_id)) == region_ids[1] &&
            String(_n03_get(interface, :right_region_id)) == region_ids[2] &&
            _n03_get(interface, :normal) == 1 &&
            _n03_get(interface, :continuity) == "trace_flux" &&
            _n03_get(interface, :transfer_kind) == "conservative" ||
            throw(ArgumentError("VNext G2 interface orientation or transfer contract is invalid"))
        expected_owners = Set{Tuple{Symbol,String}}()
        for face in expected_faces
            axis_index = face in (:x_min, :x_max) ? 1 : face in (:y_min, :y_max) ? 2 : 3
            lower_side = face in (:x_min, :y_min, :z_min)
            boundary_coordinate = lower_side ? lower[axis_index] : upper[axis_index]
            for (index, region) in enumerate((left, right))
                bounds = index == 1 ? (left_lower, left_upper) : (right_lower, right_upper)
                edge = lower_side ? bounds[1][axis_index] : bounds[2][axis_index]
                edge == boundary_coordinate && push!(expected_owners, (face, region_ids[index]))
            end
        end
        actual_owners = Set((Symbol(String(_n03_get(x, :face))),
            String(_n03_get(x, :owner_region_id))) for x in region_exterior_owners_wire)
        actual_owners == expected_owners && length(actual_owners) == 10 &&
            length(actual_owners) == length(region_exterior_owners_wire) ||
            throw(ArgumentError("VNext G2 partition exterior owners do not match exact region coverage"))
        all(x -> x.kind === :dirichlet && iszero(x.value), face_values) ||
            throw(ArgumentError("VNext G2 partition exterior is not zero Dirichlet"))
        ref_wire = _n03_get(interface, :interface_ref)
        String(_n03_get(ref_wire, :version)) == "v2" ||
            throw(ArgumentError("VNext G2 interface ref must use v2"))
        values["N08-05"] = (QualifiedRefV1(String(_n03_get(ref_wire, :id)), "v2"),)
        interface_flux_geometry = (
            interface_ref=QualifiedRefV1(String(_n03_get(ref_wire, :id)), "v2"),
            left_region=region_ids[1], right_region=region_ids[2],
            axis=axis, coordinate=coordinate,
            left_normal=ntuple(i -> i == axis ? Int(_n03_get(interface, :normal)) : 0, 3),
            right_normal=ntuple(i -> i == axis ? -Int(_n03_get(interface, :normal)) : 0, 3),
            continuity=Symbol(String(_n03_get(interface, :continuity))),
            transfer_kind=Symbol(String(_n03_get(interface, :transfer_kind))))
        delete!(absent_reasons, "N08-05")
        region_interface_present = true
        region_interface_exterior_owners_validated = true
    end
    haskey(values, "N08-04") && delete!(absent_reasons, "N08-04")
    if image_bounds === nothing
        absent_reasons["N07-01"] = :g2mb_affine_image_is_not_rectangular_region_bounds
        absent_reasons["N07-02"] = :g2mb_affine_image_is_not_rectangular_region_bounds
    else
        values["N07-01"] = ntuple(i -> image_bounds[i][1], 3)
        values["N07-02"] = ntuple(i -> image_bounds[i][2], 3)
    end
    boundary_patch_context = nothing
    boundary_coverage = _n03_get(source, :boundary_coverage)
    if boundary_coverage !== nothing
        boundary_coverage == "whole_face" && chart_axes === (:x, :y, :z) &&
            _n03_get(profile, :topology) == "cartesian" ||
            throw(ArgumentError("VNext G2 whole-face coverage lacks ordered Cartesian axis semantics"))
        positive_diagonal = all(iszero(jacobian[i][j])
            for i in 1:3 for j in 1:3 if i != j) &&
            all(jacobian[i][i] > 0 for i in 1:3)
        positive_diagonal && image_bounds !== nothing ||
            throw(ArgumentError("VNext G2 whole-face coverage lacks a positive diagonal physical chart"))
        canonical_faces = Tuple(sort(copy(faces); by=String))
        canonical_face = first(canonical_faces)
        tangent_axes = canonical_face in (:x_min, :x_max) ? (2, 3) :
            canonical_face in (:y_min, :y_max) ? (1, 3) : (1, 2)
        patch_lower = ntuple(i -> image_bounds[tangent_axes[i]][1], 2)
        patch_upper = ntuple(i -> image_bounds[tangent_axes[i]][2], 2)
        values["N07-04"] = patch_lower
        boundary_patch_context = (coverage=:whole_face, face=canonical_face,
            tangent_axes=tangent_axes, lower=patch_lower, upper=patch_upper)
    end
    profile_dimension = Int(_n03_get(profile, :dimension))
    service_source_context = (
        profile_dimension=profile_dimension,
        profile_topology=Symbol(String(_n03_get(profile, :topology))),
        profile_basis_family=Symbol(String(_n03_get(profile, :basis_family))),
        chart_axes=chart_axes,
        mesh_basis=Symbol(String(_n03_get(mesh, :basis))),
        field_space_present=field_space_wire !== nothing,
        field_value_shape=field_space_wire === nothing ? nothing :
            Symbol(String(_n03_get(field_space_wire, :value_shape))),
        field_unit_label=field_space_wire === nothing ? nothing :
            String(_n03_get(field_space_wire, :state_unit)),
        q1_interpretation=q1_interpretation === nothing ? nothing :
            Symbol(String(q1_interpretation)),
        faces=Tuple(face_values),
        region_interface_present=region_interface_present,
        region_interface_exterior_owners_validated=region_interface_exterior_owners_validated,
        interface_flux_geometry=interface_flux_geometry,
        boundary_coverage=boundary_coverage === nothing ? nothing :
            Symbol(String(boundary_coverage)),
        chart_map_kind=map_kind,
        positive_diagonal_chart=all(iszero(jacobian[i][j])
            for i in 1:3 for j in 1:3 if i != j) &&
            all(jacobian[i][i] > 0 for i in 1:3)
    )
    haskey(values, "N07-04") && delete!(absent_reasons, "N07-04")
    haskey(values, "N08-01") && delete!(absent_reasons, "N08-01")
    projection_hash_body = (candidate_ref=binding.candidate_ref,
        package_hash=binding.package_hash, semantic_identity=binding.semantic_identity,
        bundle_hash=binding.bundle_hash, declaration_ref=declaration.declaration_ref,
        declaration_hash=declaration.declaration_identity_hash,
        source_ref=declaration.source_ref, source_hash=source_hash,
        semantic_body_sha256=declaration.semantic_body_bytes.sha256,
        builder_sha256=pin.sha256, declaration_source_sha256=only(declaration_pin).sha256,
        values=values, profile_dimension=profile_dimension,
        absent_reasons=absent_reasons)
    projection_hash_body = cross_state_context === nothing ?
        projection_hash_body : merge(projection_hash_body,
            (cross_state_context=cross_state_context,
             cross_state_projection_hash=cross_state_projection_hash))
    projection_hash_body = boundary_patch_context === nothing ?
        projection_hash_body : merge(projection_hash_body,
            (boundary_patch_context=boundary_patch_context,))
    projection_hash = canonical_hash(projection_hash_body)
    context = (candidate_ref=binding.candidate_ref, package_hash=binding.package_hash,
        semantic_identity=binding.semantic_identity, bundle_hash=binding.bundle_hash,
        declaration_ref=declaration.declaration_ref,
        declaration_hash=declaration.declaration_identity_hash,
        source_ref=declaration.source_ref, source_hash=source_hash,
        projection_hash=projection_hash, values=values,
        profile_dimension=profile_dimension,
        service_source_context=service_source_context,
        interface_flux_geometry=interface_flux_geometry,
        cross_state_context=cross_state_context,
        cross_state_projection_hash=cross_state_projection_hash,
        absent_reasons=absent_reasons)
    context = boundary_patch_context === nothing ? context :
        merge(context, (boundary_patch_context=boundary_patch_context,))
    include_semantic_body ? merge(context, (semantic_body=body,)) : context
end

"""Bind optional G1-authored flux endpoints to the independently pinned G2 interface."""
Base.@noinline Base.@nospecializeinfer function _up2_vnext_n05_flux_context(package,
        binding::UP2VNextSourceBindingV1, g1_context=nothing,
        geometry_context=nothing)
    Base.@nospecialize package binding g1_context geometry_context
    g1 = g1_context === nothing ?
        _up2_vnext_g1_operator_type_context(package, binding) : g1_context
    geometry = geometry_context === nothing ?
        _up2_vnext_g2_geometry_context(package, binding) : geometry_context
    authored = g1.interface_flux_pair
    authored === nothing && return nothing
    geometry.interface_flux_geometry isa NamedTuple ||
        throw(ArgumentError("VNext G1 flux pair has no exact pinned G2 region interface"))
    actual = geometry.interface_flux_geometry
    actual.axis == 1 && actual.coordinate == 1 // 2 &&
        authored.interface_ref.id == actual.interface_ref.id &&
        authored.interface_ref.version == actual.interface_ref.version &&
        authored.left_region == actual.left_region &&
        authored.right_region == actual.right_region &&
        authored.left_normal == actual.left_normal &&
        authored.right_normal == actual.right_normal &&
        actual.continuity === :trace_flux && actual.transfer_kind === :conservative &&
        authored.law === :left_outward_flux_plus_right_outward_flux_equals_zero ||
        throw(ArgumentError("VNext G1 flux pair differs from the independently pinned G2 interface geometry"))
    axis_normal = ntuple(i -> i == actual.axis ? 1 : 0, 3)
    authored.left_normal == axis_normal && authored.left_sign == 1 &&
        authored.right_sign == -1 ||
        throw(ArgumentError("VNext G1 manufactured flux signs do not match the authored outward-normal convention"))
    pair = UP2FluxPairV1("pair-vnext-" * authored.interface_ref.id,
        authored.left_port, authored.right_port, authored.left_sign,
        authored.right_sign, authored.unit, authored.interface_ref,
        authored.left_region, authored.right_region, 1,
        actual.transfer_kind, :unverified)
    (pair=pair, authored=authored, g1_projection_hash=g1.projection_hash,
        g2_projection_hash=geometry.projection_hash,
        projection_hash=canonical_hash((pair=pair, authored=authored,
            g1_projection_hash=g1.projection_hash,
            g2_projection_hash=geometry.projection_hash)))
end

function _up2_vnext_n09_runtime()
    isdefined(Main, :FusionRuntimeV4) ||
        throw(ArgumentError("N09 native runtime authority is unavailable"))
    runtime = getfield(Main, :FusionRuntimeV4)
    parentmodule(getfield(runtime, :NativeG1G2GridapPlanV1)) === runtime ||
        throw(ArgumentError("N09 native plan type is outside its runtime authority"))
    runtime
end

function _up2_vnext_n09_service_request(plan, row_id::String)
    runtime = _up2_vnext_n09_runtime()
    factory_name, service, executor_name = row_id == "N09-01" ?
        (:native_g1g2_gridap_grad_service_v1,
            getfield(runtime, :_NG12_GRAD_SERVICE_V1),
            :_ng12_gridap_grad_executor_v1) :
        row_id == "N09-02" ?
        (:native_g1g2_gridap_chart_mesh_service_v1,
            getfield(runtime, :_NG12_CHART_MESH_SERVICE_V1),
            :_ng12_gridap_chart_mesh_executor_v1) :
        row_id == "N09-03" ?
        (:native_g1g2_gridap_exterior_boundary_service_v1,
            getfield(runtime, :_NG12_EXTERIOR_BOUNDARY_SERVICE_V1),
            :_ng12_gridap_exterior_boundary_executor_v1) :
        throw(ArgumentError("N09 row has no native G2 service mapping"))
    typeof(plan) === getfield(runtime, :NativeG1G2GridapPlanV1) &&
        parentmodule(typeof(plan)) === runtime ||
        throw(ArgumentError("N09 requires a typed native Gridap plan"))
    admission = Base.invokelatest(getfield(runtime,
        :native_g1g2_gridap_plan_admission_v1), plan)
    admission !== nothing && Base.invokelatest(getfield(runtime,
        :validate_native_g1g2_gridap_plan_admission_v1), plan, admission) ||
        throw(ArgumentError("N09 native Gridap plan admission is stale"))
    factory = getfield(runtime, factory_name)
    request = Base.invokelatest(factory, plan, 1)
    executor = getfield(runtime, executor_name)
    Base.invokelatest(getfield(runtime,
        :validate_native_g1g2_gridap_service_request_v1), request) === true ||
        throw(ArgumentError("N09 native service request failed exact factory validation"))
    request.service === service && request.provider.executor === executor ||
        throw(ArgumentError("N09 native service kind or executor mismatch"))
    match = Base.invokelatest(getfield(runtime, :match_provider),
        request.capability, (request.provider,))
    match.status === getfield(runtime, :unique_match) &&
        match.provider === request.provider ||
        throw(ArgumentError("N09 native service did not uniquely match its capability"))
    request
end

function _up2_vnext_n09_source_obligation(plan, request, row_id::String,
        geometry_context::NamedTuple, g1_context::NamedTuple)
    source = geometry_context.service_source_context
    compilation = plan.compilation
    form = compilation.form
    runtime = _up2_vnext_n09_runtime()
    protocol = plan.protocol
    level = request.level
    service = request.service
    g2 = form.g2_declaration
    g2source = g2.source
    g2.contract_ref == g2source.candidate_ref &&
        g2source.source_ref == geometry_context.source_ref &&
        g2source.source_hash.value == _n03_get(geometry_context.source_hash, :value) &&
        g2.schema_hash == g2mb_schema_hash_v1(g2source.region_interface !== nothing) ||
        throw(ArgumentError("N09 native G2 compile input is not the source-pinned T1 declaration"))
    cells = protocol.cell_counts[level]
    declared_mesh_quadrature_hash = canonical_hash((
        points=g2source.mesh.quadrature_points,
        weights=g2source.mesh.quadrature_weights))
    if row_id == "N09-01"
        grad = form.g1_declaration.operators.grad
        input_type = grad.input_type
        output_type = grad.output_type
        unknown = g1_context.unknown_state_binding
        source.profile_dimension == 3 &&
            source.profile_topology === :cartesian &&
            source.profile_basis_family === :tensor_product &&
            source.chart_axes === (:x, :y, :z) &&
            source.mesh_basis === :Q1 && source.field_space_present &&
            source.field_value_shape === :scalar &&
            source.field_unit_label == "1" &&
            source.q1_interpretation ===
                :continuous_tensor_product_lagrange_degree1_h1 &&
            source.positive_diagonal_chart ||
            throw(ArgumentError("N09-01 G2 source does not declare the Q1/H1 scalar field requirement"))
        unknown isa NamedTuple && unknown.role === :unknown &&
            unknown.state_index == 0 &&
            unknown.field_id == grad.input_field_id == form.g1_declaration.u.field_id &&
            unknown.physical_signature.value_kind === input_type.value_kind &&
            unknown.physical_signature.tensor_rank == input_type.tensor_rank &&
            unknown.physical_signature.spatial_dimension ==
                input_type.spatial_dimension &&
            unknown.physical_signature.temporal_type.kind === :static_time &&
            unknown.physical_signature.temporal_type.derivative_order == 0 &&
            unknown.physical_signature.temporal_type.clock_ref === nothing &&
            unknown.physical_signature.units == input_type.units &&
            grad.output_field_id ==
                form.g1_declaration.operators.coefficient_apply.input_field_id &&
            input_type.value_kind === :scalar_field &&
            input_type.tensor_rank == 0 && input_type.spatial_dimension == 3 &&
            input_type.temporal_type == TemporalTypeV1(static_time) &&
            output_type.value_kind === :vector_field &&
            output_type.tensor_rank == 1 && output_type.spatial_dimension == 3 &&
            output_type.temporal_type == TemporalTypeV1(static_time) ||
            throw(ArgumentError("N09-01 G1 typed GRAD contract is not bound to the source unknown or static vector output"))
    elseif row_id == "N09-02"
        source.profile_dimension == 3 &&
            source.profile_topology === :cartesian &&
            source.profile_basis_family === :tensor_product &&
            source.chart_axes === (:x, :y, :z) &&
            source.mesh_basis === :Q1 && source.field_space_present &&
            source.field_value_shape === :scalar &&
            source.field_unit_label == "1" &&
            source.q1_interpretation ===
                :continuous_tensor_product_lagrange_degree1_h1 &&
            source.positive_diagonal_chart ||
            throw(ArgumentError("N09-02 G2 source does not declare the Gridap chart/mesh requirement"))
    elseif row_id == "N09-03"
        expected_faces = Set((:x_min, :x_max, :y_min, :y_max, :z_min, :z_max))
        expected_count = 6
        exterior_owners_valid = all(x -> x.owner_region_id == "local_unit_cube", source.faces) &&
            (!source.region_interface_present || source.region_interface_exterior_owners_validated)
        length(source.faces) == expected_count &&
            Set(x.face for x in source.faces) == expected_faces &&
            exterior_owners_valid &&
            all(x -> x.kind === :dirichlet && iszero(x.value), source.faces) &&
            source.boundary_coverage === :whole_face &&
            source.chart_axes === (:x, :y, :z) &&
            source.positive_diagonal_chart ||
            throw(ArgumentError("N09-03 G2 source does not declare the full owned zero-Dirichlet exterior"))
    else
        throw(ArgumentError("N09 row has no source-derived native service obligation"))
    end
    schema = getfield(runtime, :_NG12_SERVICE_SCHEMA_V1)
    revision = "v1"
    if row_id == "N09-01"
        service = getfield(runtime, :_NG12_GRAD_SERVICE_V1)
        grad = form.g1_declaration.operators.grad
        grad_contract = semantic_view(grad)
        input_schema_hash = canonical_hash(merge((
            schema=schema, revision=revision, service=service,
            plan_hash=plan.plan_hash,
            candidate_ref=form.candidate_ref,
            package_hash=form.t1_package_hash,
            semantic_identity=form.t1_semantic_identity,
            bundle_hash=form.t0_bundle_hash,
            g1_declaration_hash=form.g1_declaration.declaration_hash,
            g2_declaration_hash=g2.declaration_hash,
            g2_source_hash=g2source.source_hash,
            form_hash=form.form_hash,
            declared_mesh_quadrature_hash=declared_mesh_quadrature_hash,
            protocol_hash=protocol.protocol_hash, level=level,
            cells=cells,
            dependency_hash=plan.dependency_identity.dependency_hash,
            adapter_source_hash=plan.adapter_source_hash),
            (g1_grad_contract=grad_contract,)))
        applicability_hash = canonical_hash((
            service_scope="candidate-bound-native-g1g2-gridap-service-v1",
            service=service, plan_hash=plan.plan_hash,
            candidate_ref=form.candidate_ref,
            package_hash=form.t1_package_hash,
            semantic_identity=form.t1_semantic_identity,
            bundle_hash=form.t0_bundle_hash,
            g1_declaration_hash=form.g1_declaration.declaration_hash,
            g2_declaration_hash=g2.declaration_hash,
            g2_source_hash=g2source.source_hash, form_hash=form.form_hash,
            declared_mesh_quadrature_hash=declared_mesh_quadrature_hash,
            protocol_hash=protocol.protocol_hash, level=level, cells=cells))
        return Base.invokelatest(getfield(runtime, :CapabilitySignatureV4),
            schema, revision, service,
            string(grad.operator_ref.id, "@", grad.operator_ref.version),
            (grad.input_field_id,), "gridap_q1_h1_static_3d_scalar",
            "gridap_q1_piecewise_l2_static_3d_vector", source.profile_dimension,
            Tuple(String(axis) for axis in source.chart_axes), "none", "none",
            "steady", ("candidate_u_gradient_cell_field",),
            getfield(runtime, :screen_only), applicability_hash;
            input_schema_hash=input_schema_hash,
            coordinate_system="candidate_physical_cartesian")
    end
    operation = row_id == "N09-02" ?
        "materialize_candidate_chart_mesh_basis_quadrature" :
        "materialize_candidate_exterior_boundary_conditions"
    outputs = row_id == "N09-02" ?
        ("cartesian_discrete_model", "q1_reference_element",
         "physical_triangulation", "quadrature_measure") :
        ("six_face_owner_bindings", "zero_dirichlet_test_trial_spaces",
         "boundary_triangulation", "boundary_measure", "outward_normal")
    boundary_relation = row_id == "N09-03" ?
        "six-candidate-owned-exterior-faces-zero-dirichlet" : "none"
    input_schema_hash = canonical_hash((schema=schema, revision=revision,
        service=service, plan_hash=plan.plan_hash,
        candidate_ref=form.candidate_ref,
        package_hash=form.t1_package_hash,
        semantic_identity=form.t1_semantic_identity,
        bundle_hash=form.t0_bundle_hash,
        g1_declaration_hash=form.g1_declaration.declaration_hash,
        g2_declaration_hash=g2.declaration_hash,
        g2_source_hash=g2source.source_hash, form_hash=form.form_hash,
        declared_mesh_quadrature_hash=declared_mesh_quadrature_hash,
        protocol_hash=protocol.protocol_hash, level=level, cells=cells,
        dependency_hash=plan.dependency_identity.dependency_hash,
        adapter_source_hash=plan.adapter_source_hash))
    applicability_hash = canonical_hash((
        service_scope="candidate-bound-native-g1g2-gridap-service-v1",
        service=service, plan_hash=plan.plan_hash,
        candidate_ref=form.candidate_ref,
        package_hash=form.t1_package_hash,
        semantic_identity=form.t1_semantic_identity,
        bundle_hash=form.t0_bundle_hash,
        g1_declaration_hash=form.g1_declaration.declaration_hash,
        g2_declaration_hash=g2.declaration_hash,
        g2_source_hash=g2source.source_hash, form_hash=form.form_hash,
        declared_mesh_quadrature_hash=declared_mesh_quadrature_hash,
        protocol_hash=protocol.protocol_hash, level=level, cells=cells))
    target_space = row_id == "N09-02" ?
        "gridap_$(lowercase(String(source.mesh_basis)))_h1_space" :
        "gridap_q1_h1_space"
    Base.invokelatest(getfield(runtime, :CapabilitySignatureV4),
        schema, revision, service,
        operation, ("u",),
        "physical_candidate_field", target_space, source.profile_dimension,
        Tuple(String(axis) for axis in source.chart_axes), boundary_relation,
        "none", "steady", outputs, getfield(runtime, :screen_only), applicability_hash;
        input_schema_hash=input_schema_hash,
        coordinate_system="candidate_physical_cartesian")
end

function _up2_vnext_n09_binding(plan, request, row_id::String, status::Symbol)
    form = plan.compilation.form
    runtime = _up2_vnext_n09_runtime()
    (field_id=row_id, service=request.service, service_kind=request.provider.kind,
        status=status, plan_hash=plan.plan_hash, form_hash=form.form_hash,
        compiler_source_hash=Base.invokelatest(getfield(runtime,
            :native_g1g2_diffusion_compiler_source_hash_v1)),
        adapter_source_hash=plan.adapter_source_hash,
        dependency_hash=plan.dependency_identity.dependency_hash,
        service_contract_hash=canonical_hash(request.capability),
        provider_manifest_hash=request.provider.manifest_hash,
        provider_domain_hash=canonical_hash(request.provider.domain),
        service_input_schema_hash=request.solver_input.input_schema_hash,
        service_applicability_hash=request.capability.applicability_bounds,
        declared_mesh_quadrature_hash=canonical_hash((
            points=form.g2_declaration.source.mesh.quadrature_points,
            weights=form.g2_declaration.source.mesh.quadrature_weights)),
        execution_quadrature_degree=plan.protocol.quadrature_degree,
        solver_input_hash=request.solver_input.solver_input_hash,
        subject_hash=request.subject.physical_subject_hash,
        candidate_ref=form.candidate_ref,
        package_hash=form.t1_package_hash,
        semantic_identity=form.t1_semantic_identity,
        bundle_hash=form.t0_bundle_hash,
        g1_declaration_hash=form.g1_declaration.declaration_hash,
        g2_declaration_hash=form.g2_declaration.declaration_hash,
        g2_source_hash=form.g2_declaration.source.source_hash,
        level=request.level)
end

function _up2_vnext_n09_g3_obligation(d,c,binding; fault_basis=d.fault_event_basis)
    c isa G3ControlSourceBodyV1 && d.fault_event_basis===:sampled_observation ||
        throw(ArgumentError("N09-05 requires the pinned sampled G3 source"))
    selected=_up2_vnext_n09_g3_thermostat_ports(c)
    s,a,p=selected.sensor,selected.command,selected.power; k=selected.controller; f=only(c.faults)
    s.unit==UnitSignature((0,0,0,0,1,0,0)) && a.unit==UnitSignature((0,0,0,0,0,0,0)) &&
        p.unit==UnitSignature((2,1,-3,0,0,0,0)) && k.fault_ids==(f.fault_id,) &&
        f.target_id==k.controller_id && f.mode===:overtemperature && f.safe_action===:trip &&
        f.detection_signal_id==s.port_id && f.deadline==d.trip_deadline_seconds ||
        throw(ArgumentError("N09-05 typed ports, units, fault identity do not close"))
    init=only(k.initial_states)
    init.unit==s.unit && init.value==293//1 || throw(ArgumentError("N09-05 initial state is not source-bound"))
    if !hasproperty(d,:re_enable_policy)
        ev=only(k.events)
        ev.event_id=="initial_enable" && ev.trigger===:initial && ev.time==0//1 && ev.action===:enable ||
            throw(ArgumentError("N09-05 initial-enable state is not source-bound"))
    else
        guard_policy=d.re_enable_policy
        length(k.events)==2 && first(k.events).event_id=="initial_enable" && first(k.events).trigger===:initial &&
            first(k.events).time==0//1 && first(k.events).action===:enable && last(k.events).event_id==guard_policy.event_id &&
            last(k.events).trigger===:threshold && last(k.events).time==0//1 && last(k.events).action===:recover &&
            guard_policy.signal_port_id==s.port_id && guard_policy.comparator===:at_or_below && guard_policy.unit==s.unit &&
            guard_policy.threshold_kelvin isa Rational{Int64} && 0//1<=guard_policy.threshold_kelvin<d.overtemperature_trip_kelvin &&
            guard_policy.action===:recover || throw(ArgumentError("N09-05 typed clear/re-enable event differs from its authored guard"))
    end
    m=d.command_to_power_map
    m.coefficient==1000//1 && m.offset==0//1 && m.command_unit==a.unit &&
        m.coefficient_unit==p.unit && m.output_unit==p.unit ||
        throw(ArgumentError("N09-05 numeric command-to-power map is not typed"))
    r=getfield(Main,:FusionRuntimeV4)
    outputs=hasproperty(d,:re_enable_policy) ?
        (:command_fraction,:power_status,:action,:fault_tick,:deadline,:fault_latched,:re_enabled_at) :
        (:command_fraction,:power_status,:action,:fault_tick,:deadline)
    base_policy=(d.sample_period_seconds,d.setpoint_kelvin,d.full_source_at_or_below_kelvin,
        d.zero_source_at_or_above_kelvin,d.in_band_action,d.command_fraction_bounds,
        d.trip_command_fraction,d.overtemperature_trip_kelvin,d.trip_deadline_seconds,
        d.sampled_fault_trace_kelvin,d.command_to_power_map)
    policy=hasproperty(d,:re_enable_policy) ? (base_policy,d.re_enable_policy) : base_policy
    ih=canonical_hash((inputs=(:sample_index,:time_seconds,:temperature_kelvin),
        outputs=outputs,policy=policy))
    bounds=canonical_hash((binding=binding,design=d,control=semantic_view(c),fault_basis=fault_basis))
    Base.invokelatest(getfield(r,:CapabilitySignatureV4),getfield(r,:_TECFE_SCHEMA),
        getfield(r,:_TECFE_REVISION),:engineering_control_fault_operational_screen,
        "g3_candidate_sampled_thermostat",(k.controller_id,f.fault_id),
        "G3_temperature_K","G3_command_fraction_and_power_W",1,("sampled_controller_time",),
        "contiguous_exact_1/20_second_samples","typed_G3_sensor_command_status_ports",
        string(fault_basis,"; same-sample trip; deadline 1/10 second"),
        ("full_command_trace","full_power_status_trace","sampled_fault_and_action_times","deadline_check"),
        getfield(r,:screen_only),bounds;input_schema_hash=ih,
        coordinate_system="candidate_controller_time")
end

function _up2_vnext_n09_load_g3_control_provider!(runtime)
    root = normpath(joinpath(@__DIR__, "..", "..", ".."))
    components = (
        ("ForwardChainContext.jl", :ForwardChainContextV4),
        ("EngineeringControlFaultGraphObligationV4.jl",
            :EngineeringControlFaultGraphCompilationV4),
        ("TrustedProviderRegistryV4.jl", :TrustedProviderRegistryV4),
        ("TrustedEngineeringControlFaultProviderV4.jl",
            :g3_sampled_control_provider_v1),
    )
    for (file, sentinel) in components
        if !isdefined(runtime, sentinel)
            path = joinpath(root, "src", "RuntimeV4", file)
            isfile(path) || throw(ArgumentError(
                "N09-05 runtime component source is absent: $file"))
            root_added_to_load_path = !(root in LOAD_PATH)
            root_added_to_load_path && push!(LOAD_PATH, root)
            try
                Base.include(runtime, path)
            finally
                if root_added_to_load_path
                    root_index = findlast(==(root), LOAD_PATH)
                    root_index === nothing || deleteat!(LOAD_PATH, root_index)
                end
            end
        end
        isdefined(runtime, sentinel) || throw(ArgumentError(
            "N09-05 runtime component did not register $sentinel"))
    end
    isdefined(runtime, :G3ControlSourceBodyV1) || throw(ArgumentError(
        "N09-05 typed G3 source type is unavailable in the runtime namespace"))
    nothing
end

const _UP2_VNEXT_N09_G3_SOURCE_UNIT_BASIS_V2 =
    (:kg, :m, :s, :A, :K, :mol, :cd)
const _UP2_VNEXT_N09_G3_RUNTIME_UNIT_BASIS_V1 =
    (:m, :kg, :s, :A, :K, :mol, :cd)
const _UP2_VNEXT_N09_G3_UNIT_BASIS_PERMUTATION_V2 = (2, 1, 3, 4, 5, 6, 7)

function _up2_vnext_n09_unit_to_runtime_basis_v2(runtime, unit, source_basis)
    typeof(unit) === getfield(runtime, :UnitSignature) ||
        throw(ArgumentError("N09-05 source control unit is not a UnitSignature"))
    source_basis == _UP2_VNEXT_N09_G3_SOURCE_UNIT_BASIS_V2 ||
        throw(ArgumentError("N09-05 V2 G3 source unit basis is unsupported"))
    exponents = Tuple(unit.exponents)
    length(exponents) == 7 ||
        throw(ArgumentError("N09-05 source unit exponent vector is incomplete"))
    permutation = _UP2_VNEXT_N09_G3_UNIT_BASIS_PERMUTATION_V2
    Base.invokelatest(getfield(runtime, :UnitSignature),
        ntuple(i -> exponents[permutation[i]], 7))
end

"""Create an auditable runtime-basis view for the legacy V1 control provider.

The authored V2 G3 child remains intact in `source_design`/`source_control`.
Only the provider input is permuted from its explicitly declared
`(:kg,:m,:s,...)` source basis to the runtime's legacy `(:m,:kg,:s,...)`
`UnitSignature` order. This is a representational conversion; all source
records, pin hashes, and source values are retained and re-checkable.
"""
function _up2_vnext_n09_g3_thermostat_ports(control)
    control isa G3ControlSourceBodyV1 ||
        throw(ArgumentError("N09-05 requires the pinned typed G3 control source"))
    length(control.controllers) == 1 ||
        throw(ArgumentError("N09-05 requires exactly one authored thermostat controller"))
    controller = only(control.controllers)
    length(controller.sensor_port_ids) == 1 &&
        length(controller.actuator_port_ids) == 1 &&
        length(controller.actuator_resource_port_ids) == 1 ||
        throw(ArgumentError("N09-05 thermostat must identify one sensor, command, and power-status port"))
    selected_signal(port_id, kind, label) = begin
        rows = Tuple(signal for signal in control.signal_ports if signal.port_id == port_id)
        length(rows) == 1 && only(rows).signal_kind === kind ||
            throw(ArgumentError("N09-05 authored thermostat $label port is absent, ambiguous, or has the wrong kind"))
        only(rows)
    end
    sensor = selected_signal(only(controller.sensor_port_ids), :sensor, "sensor")
    command = selected_signal(only(controller.actuator_port_ids), :command, "command")
    power = selected_signal(only(controller.actuator_resource_port_ids), :status, "power-status")
    (controller=controller, sensor=sensor, command=command, power=power)
end

function _up2_vnext_n09_normalize_g3_provider_input_v2(runtime, design, control)
    hasproperty(design, :unit_basis) && hasproperty(design, :control_design) ||
        throw(ArgumentError("N09-05 basis conversion requires the authored V2 G3 source"))
    source_basis = design.unit_basis
    source_basis == _UP2_VNEXT_N09_G3_SOURCE_UNIT_BASIS_V2 ||
        throw(ArgumentError("N09-05 authored G3 unit basis differs from its declared V2 basis"))
    source_power_unit = Base.invokelatest(getfield(runtime, :UnitSignature),
        (1, 2, -3, 0, 0, 0, 0))
    source_current_unit = Base.invokelatest(getfield(runtime, :UnitSignature),
        (0, 0, 0, 1, 0, 0, 0))
    dimensionless_unit = Base.invokelatest(getfield(runtime, :UnitSignature),
        (0, 0, 0, 0, 0, 0, 0))
    temperature_unit = Base.invokelatest(getfield(runtime, :UnitSignature),
        (0, 0, 0, 0, 1, 0, 0))
    selected = _up2_vnext_n09_g3_thermostat_ports(control)
    source_sensor, source_command, source_power = selected.sensor, selected.command, selected.power
    source_map = design.control_design.command_to_power_map
    source_map.coefficient_unit == source_power_unit &&
        source_map.output_unit == source_power_unit &&
        source_map.command_unit == source_command.unit &&
        source_command.unit == dimensionless_unit ||
        throw(ArgumentError("N09-05 source command/power map is not expressed in its declared basis"))
    source_current_map = design.control_design.command_to_current_map
    source_current_map.command_unit == source_command.unit &&
        source_current_map.rated_current_unit == source_current_unit &&
        source_current_map.output_unit == source_current_unit &&
        source_current_map.law === :fraction_of_rated_current &&
        source_current_map.rated_current > 0 ||
        throw(ArgumentError("N09-05 source command/current map is not expressed in its declared basis"))
    source_sensor.direction === :in && source_command.direction === :out &&
        source_power.direction === :out ||
        throw(ArgumentError("N09-05 thermostat port directions differ from the authored controller"))
    hasproperty(design, :resource_network) &&
        hasproperty(design, :control_resource_links) ||
        throw(ArgumentError("N09-05 source current map has no authored network/link context"))
    source_flow_ports = Tuple(port for port in design.resource_network.resource_ports
        if port.port_id == source_current_map.target_resource_port_id)
    length(source_flow_ports) == 1 ||
        throw(ArgumentError("N09-05 command/current map target flow port is absent or ambiguous"))
    source_flow = only(source_flow_ports)
    source_flow.kind === :flow && source_flow.direction === :out &&
        source_flow.unit == source_current_map.rated_current_unit == source_current_map.output_unit &&
        source_flow.account_id == source_power.account_id ||
        throw(ArgumentError("N09-05 command/current map target does not match the authored flow port"))
    source_links = Tuple(link for link in design.control_resource_links
        if link.controller_id == selected.controller.controller_id)
    length(source_links) == 1 ||
        throw(ArgumentError("N09-05 authored thermostat resource link is absent or ambiguous"))
    source_link = only(source_links)
    source_link.sensor_port_id == source_sensor.port_id &&
        source_link.actuator_port_id == source_command.port_id &&
        source_link.resource_port_id == source_current_map.target_resource_port_id &&
        source_link.fault_id in selected.controller.fault_ids ||
        throw(ArgumentError("N09-05 authored control link differs from its controller/map port IDs"))
    source_sensor.unit == temperature_unit && source_power.unit == source_power_unit ||
        throw(ArgumentError("N09-05 thermostat ports do not match their declared source unit basis"))

    runtime_power_unit = _up2_vnext_n09_unit_to_runtime_basis_v2(runtime,
        source_power_unit, source_basis)
    runtime_map = merge(source_map, (coefficient_unit=runtime_power_unit,
        output_unit=runtime_power_unit))
    runtime_current_map = merge(source_current_map,
        (rated_current_unit=_up2_vnext_n09_unit_to_runtime_basis_v2(runtime,
            source_current_map.rated_current_unit, source_basis),
         command_unit=_up2_vnext_n09_unit_to_runtime_basis_v2(runtime,
            source_current_map.command_unit, source_basis),
         output_unit=_up2_vnext_n09_unit_to_runtime_basis_v2(runtime,
            source_current_map.output_unit, source_basis)))
    runtime_design = merge(design.control_design,
        (command_to_current_map=runtime_current_map,
         command_to_power_map=runtime_map))
    signal_type = getfield(runtime, :G3ControlSignalV1)
    runtime_signals = Tuple(Base.invokelatest(signal_type,
        signal.port_id, signal.signal_kind, signal.direction,
        _up2_vnext_n09_unit_to_runtime_basis_v2(runtime, signal.unit, source_basis),
        signal.account_id) for signal in control.signal_ports)
    control_type = getfield(runtime, :G3ControlSourceBodyV1)
    runtime_control = Base.invokelatest(control_type, control.source_id,
        control.owner_scope, runtime_signals, control.controllers,
        control.faults, control.plan)
    runtime_selected = _up2_vnext_n09_g3_thermostat_ports(runtime_control)
    normalized = (schema="up2-vnext-n09-g3-provider-input-v2",
        source_unit_basis=source_basis,
        runtime_unit_basis=_UP2_VNEXT_N09_G3_RUNTIME_UNIT_BASIS_V1,
        basis_permutation=_UP2_VNEXT_N09_G3_UNIT_BASIS_PERMUTATION_V2,
        source_design_hash=canonical_hash(design),
        source_control_hash=canonical_hash(control),
        source_command_to_power_map=source_map,
        source_power_port=source_power,
        runtime_command_to_power_map=runtime_map,
        runtime_power_port=runtime_selected.power,
        runtime_design_hash=canonical_hash(runtime_design),
        runtime_control_hash=canonical_hash(runtime_control))
    (design=runtime_design, control=runtime_control,
        normalized_provider_input=normalized,
        normalized_provider_input_hash=canonical_hash(normalized))
end
function _up2_vnext_n09_g3_context(design,binding; available_route_ids=nothing)
    design===nothing && return nothing
    hasproperty(design,:control_design) && hasproperty(design,:control) ||
        throw(ArgumentError("N09-05 rebuilt G3 control source is incomplete"))
    d,c=design.control_design,design.control
    has_basis = :fault_event_basis in keys(d)
    has_trace = :sampled_fault_trace_kelvin in keys(d)
    has_map = :command_to_power_map in keys(d)
    source_map = has_map ? d.command_to_power_map : nothing
    legacy_map = !has_basis && !has_trace && source_map isa AbstractString &&
        String(source_map) == "source_power_W = 1000 * command_fraction"
    entirely_absent = !has_basis && !has_trace && !has_map
    (legacy_map || entirely_absent) && return nothing
    presence=(has_basis,has_trace,has_map && source_map isa NamedTuple)
    all(presence) || throw(ArgumentError("N09-05 G3 fields are partially present or malformed"))
    r=getfield(Main,:FusionRuntimeV4)
    _up2_vnext_n09_load_g3_control_provider!(r)
    source_control = c
    unit_conversion = if hasproperty(design, :unit_basis)
        normalized = _up2_vnext_n09_normalize_g3_provider_input_v2(r,
            design, c)
        d, c = normalized.design, normalized.control
        normalized
    else
        nothing
    end
    provider=Base.invokelatest(getfield(r,:g3_sampled_control_provider_v1),d,c,binding)
    obligation=_up2_vnext_n09_g3_obligation(d,c,binding)
    available_route_ids = _up2_vnext_n09_availability_routes_v1(available_route_ids)
    route_pool = _up2_vnext_n09_route_pool_v1("N09-05", provider, available_route_ids)
    match=Base.invokelatest(getfield(r,:match_provider),obligation,route_pool)
    match_status=Symbol(string(match.status))
    if match_status !== :unique_match || match.provider !== provider
        available_route_ids !== nothing && match_status === :no_match &&
            !("N09-05" in available_route_ids) ||
            throw(ArgumentError("N09-05 independently derived obligation did not match"))
        base = (design=d,control=c,binding=binding,provider=provider,
            obligation=obligation,match_status=match_status,result=nothing,trace_hash=nothing)
        return unit_conversion === nothing ? base : merge(base,
            (source_design=design,source_control=source_control,
             source_unit_basis=design.unit_basis,
             normalized_provider_input=unit_conversion.normalized_provider_input,
             normalized_provider_input_hash=unit_conversion.normalized_provider_input_hash))
    end
    trace=Base.invokelatest(getfield(r,:execute_g3_sampled_control_trace_v1),d,c,binding,obligation,provider)
    ts=d.sampled_fault_trace_kelvin
    control=only(c.controllers)
    sensor=_up2_vnext_n09_g3_thermostat_ports(c).sensor
    initial=only(control.initial_states)
    if !hasproperty(d,:re_enable_policy)
        initial_event=only(control.events)
        initial.unit==UnitSignature((0,0,0,0,1,0,0)) && initial.unit==sensor.unit &&
            initial.value==293//1 && initial_event.event_id=="initial_enable" &&
            initial_event.trigger===:initial && initial_event.time==0//1 && initial_event.action===:enable ||
            throw(ArgumentError("N09-05 initial state/event is not exact typed T1 source"))
    else
        p=d.re_enable_policy
        initial.unit==UnitSignature((0,0,0,0,1,0,0)) && initial.unit==sensor.unit && initial.value==293//1 &&
            length(control.events)==2 && first(control.events).event_id=="initial_enable" &&
            first(control.events).trigger===:initial && first(control.events).time==0//1 &&
            first(control.events).action===:enable && last(control.events).event_id==p.event_id &&
            last(control.events).trigger===:threshold && last(control.events).action===:recover ||
            throw(ArgumentError("N09-05 initial/re-enable events are not exact typed T1 source"))
    end
    length(trace.samples)==length(ts) && all(i->trace.samples[i].time_seconds==(i-1)*d.sample_period_seconds &&
        trace.samples[i].temperature_kelvin==ts[i] &&
        trace.samples[i].power_unit==UnitSignature((2,1,-3,0,0,0,0)) &&
        trace.samples[i].power_status==d.command_to_power_map.coefficient*trace.samples[i].command_fraction+
            d.command_to_power_map.offset,eachindex(ts)) ||
        throw(ArgumentError("N09-05 command/power trace differs from every source sample"))
    fi=findfirst(t->t>=d.overtemperature_trip_kelvin,ts)
    base_trace_ok=fi!==nothing && trace.fault_observed_at==(fi-1)*d.sample_period_seconds &&
        trace.trip_action_at==trace.fault_observed_at && trace.logical_response_seconds==0//1 &&
        trace.deadline_satisfied && trace.logical_response_seconds<=c.faults[1].deadline &&
        trace.timing_scope===:discrete_software_samples && trace.claim_ceiling===getfield(r,:screen_only) &&
        !trace.engineering_evidence && !trace.physical_evidence && !trace.terminal_authority
    guard_trace_ok=true
    if hasproperty(d,:re_enable_policy)
        clear_index=findfirst(x->x.action===:recover,trace.samples)
        guard_trace_ok=trace.re_enable_threshold_kelvin==d.re_enable_policy.threshold_kelvin &&
            trace.re_enable_policy_hash==canonical_hash(d.re_enable_policy) && trace.re_enabled_at!==nothing &&
            !trace.fault_latched && clear_index!==nothing && clear_index>1 && clear_index<length(trace.samples)
        if guard_trace_ok
            trip_sample=trace.samples[clear_index-1]
            clear_sample=trace.samples[clear_index]
            resumed_sample=trace.samples[clear_index+1]
            power_map=d.command_to_power_map
            guard_trace_ok=trip_sample.action===:trip && trip_sample.fault_latched &&
                trip_sample.command_fraction==d.trip_command_fraction &&
                clear_sample.action===:recover && !clear_sample.fault_latched &&
                clear_sample.temperature_kelvin==d.re_enable_policy.threshold_kelvin &&
                clear_sample.command_fraction==d.trip_command_fraction &&
                clear_sample.power_status==power_map.coefficient*d.trip_command_fraction+power_map.offset &&
                trace.re_enabled_at==clear_sample.time_seconds &&
                resumed_sample.temperature_kelvin==293//1 && resumed_sample.action===:full_source &&
                resumed_sample.command_fraction==1//1 &&
                resumed_sample.power_status==power_map.coefficient*(1//1)+power_map.offset &&
                !resumed_sample.fault_latched
        end
    end
    base_trace_ok && guard_trace_ok || throw(ArgumentError("N09-05 sampled fault/deadline/re-enable/authority result is invalid"))
    base = (design=d,control=c,binding=binding,provider=provider,
        obligation=obligation,result=trace,trace_hash=canonical_hash(trace))
    available_route_ids === nothing ||
        (base = merge(base, (match_status=match_status,)))
    unit_conversion === nothing ? base : merge(base,
        (source_design=design,source_control=source_control,
         source_unit_basis=design.unit_basis,
         normalized_provider_input=unit_conversion.normalized_provider_input,
         normalized_provider_input_hash=unit_conversion.normalized_provider_input_hash))
end

Base.@nospecializeinfer function _up2_vnext_n09_availability_routes_v1(ids)
    ids === nothing && return nothing
    ids isa Tuple || throw(ArgumentError("N09 available route IDs must be an immutable tuple"))
    allowed = ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05")
    all(id -> id isa String && id in allowed, ids) && length(unique(ids)) == length(ids) ||
        throw(ArgumentError("N09 availability selection contains an unknown or duplicate route ID"))
    ids
end
function _up2_vnext_n09_route_pool_v1(id, provider, ids)
    ids === nothing && return (provider,)
    id in ids ? (provider,) : ()
end
function _up2_vnext_n09_context_with_g1(package,
        binding::UP2VNextSourceBindingV1,
        geometry_context::NamedTuple, plan; g3_source_context=nothing,
        g1_context=nothing, native_report=nothing,
        heat_lift_receipt=nothing,
        include_fe_boundary_energy_readout::Bool=false,
        available_route_ids=nothing)
    Base.@nospecialize package geometry_context plan g1_context
    available_route_ids = _up2_vnext_n09_availability_routes_v1(available_route_ids)
    runtime = _up2_vnext_n09_runtime()
    compilation = plan.compilation
    form = compilation.form
    form.candidate_ref == binding.candidate_ref == package.candidate_ref &&
        form.t1_package_hash == binding.package_hash == package.package_hash &&
        form.t1_semantic_identity == binding.semantic_identity == package.semantic_identity &&
        form.t0_bundle_hash == binding.bundle_hash == package.bundle_hash &&
        form.t1_package_hash == package.package_hash &&
        form.t1_semantic_identity == package.semantic_identity &&
        form.t0_bundle_hash == package.bundle_hash ||
        throw(ArgumentError("N09 native plan differs from the bound T1 package"))
    binding_inherited = try
        package === form.t1_package &&
            Base.invokelatest(getfield(runtime,
                :native_g1g2_gridap_plan_admission_v1), plan) !== nothing
    catch
        false
    end
    binding_errors = binding_inherited ? () :
        Base.invokelatest(getfield(runtime,
            :_ng12_t1_package_binding_errors), package,
            form.g1_declaration, form.g2_declaration)
    isempty(binding_errors) ||
        throw(ArgumentError("N09 native declarations do not match the T1 byte carriers"))
    g1 = Tuple(d for d in package.declarations if d.layer === :G1)
    g2 = Tuple(d for d in package.declarations if d.layer === :G2)
    length(g1) == length(g2) == 1 ||
        throw(ArgumentError("N09 native plan requires unique T1 G1/G2 declarations"))
    geometry_source_hash_value = _n03_get(geometry_context.source_hash, :value)
    geometry_source_hash_value isa AbstractString ||
        throw(ArgumentError("N09 G2 source hash wire value is not text"))
    geometry_source_hash = Digest256(String(geometry_source_hash_value))
    geometry_context.declaration_ref == only(g2).declaration_ref &&
        geometry_context.source_ref == only(g2).source_ref &&
        geometry_source_hash.value == form.g2_declaration.source.source_hash.value ||
        throw(ArgumentError("N09 native plan declarations differ from pinned T1 source"))
    requests = Dict{String,Any}()
    obligations = Dict{String,Any}()
    matches = Dict{String,Symbol}()
    provider_bindings = NamedTuple[]
    fe_boundary_energy_readout = nothing
    g1_context = g1_context === nothing ?
        _up2_vnext_g1_operator_type_context(package, binding) : g1_context
    for row_id in ("N09-01", "N09-02", "N09-03")
        request = _up2_vnext_n09_service_request(plan, row_id)
        obligation = _up2_vnext_n09_source_obligation(plan, request,
            row_id, geometry_context, g1_context)
        obligations[row_id] = obligation
        route_pool = _up2_vnext_n09_route_pool_v1(row_id, request.provider, available_route_ids)
        result = Base.invokelatest(getfield(runtime, :match_provider), obligation, route_pool)
        status = Symbol(string(result.status))
        if status === :unique_match
            result.provider === request.provider ||
                throw(ArgumentError("N09 native G2 service matched a different source route provider"))
        elseif available_route_ids === nothing || status !== :no_match ||
                row_id in available_route_ids
            throw(ArgumentError("N09 native G2 service match is not unique"))
        end
        # Record the independently reconstructed source obligation, not the
        # provider request's self-declared capability.
        requests[row_id] = request
        matches[row_id] = status
        base_binding = _up2_vnext_n09_binding(plan, request, row_id, status)
        push!(provider_bindings, merge(base_binding,
            (obligation_hash=canonical_hash(obligation),)))
    end
    if native_report !== nothing || heat_lift_receipt !== nothing
        typed_ledger_context = g3_source_context !== nothing &&
            hasproperty(g3_source_context, :typed_ledger_context) ?
            g3_source_context.typed_ledger_context : nothing
        typed_ledger_context isa NamedTuple &&
            hasproperty(typed_ledger_context, :authored_heat_lift) ||
            throw(ArgumentError("N09-04 requires the validated candidate-bound typed G3 ledger context"))
        native_report !== nothing && heat_lift_receipt !== nothing ||
            throw(ArgumentError("N09-04 requires both the validated native report and executed heat-lift receipt"))
        child_pin = only(x for x in binding.source_pins
            if x.role === :g3_child_design)
        typed_ledger_context.source_pin_sha256 == child_pin.sha256 &&
            typed_ledger_context.source_sha256 == child_pin.sha256 ||
            throw(ArgumentError("N09-04 typed ledger source pin differs from the bound T1 G3 child source"))
        Base.invokelatest(getfield(runtime,
            :validate_native_g1g2_gridap_scalar_heat_lift_receipt_v1),
            plan, native_report, typed_ledger_context, heat_lift_receipt) === true ||
            throw(ArgumentError("N09-04 scalar heat-lift receipt failed exact validation"))
        if include_fe_boundary_energy_readout
            fe_boundary_energy_readout = Base.invokelatest(getfield(runtime,
                :native_g1g2_gridap_scalar_heat_lift_fe_boundary_energy_readout_v1),
                plan, native_report, typed_ledger_context, heat_lift_receipt)
        end
        heat_lift_receipt.result.candidate_ref == binding.candidate_ref &&
            heat_lift_receipt.result.t1_package_hash == binding.package_hash &&
            heat_lift_receipt.result.plan_hash == plan.plan_hash ||
            throw(ArgumentError("N09-04 scalar heat lift differs from exact T1 source binding"))
        route_pool = _up2_vnext_n09_route_pool_v1("N09-04",
            heat_lift_receipt.provider, available_route_ids)
        match = Base.invokelatest(getfield(runtime, :match_provider),
            heat_lift_receipt.obligation, route_pool)
        match_status = Symbol(string(match.status))
        if match_status === :unique_match
            match.provider === heat_lift_receipt.provider ||
                throw(ArgumentError("N09-04 scalar heat lift matched a different source route provider"))
        elseif available_route_ids === nothing || match_status !== :no_match ||
                "N09-04" in available_route_ids
            throw(ArgumentError("N09-04 scalar heat lift provider match is not unique"))
        end
        requests["N09-04"] = heat_lift_receipt
        obligations["N09-04"] = heat_lift_receipt.obligation
        matches["N09-04"] = Symbol(string(match.status))
        push!(provider_bindings, (field_id="N09-04", status=match_status,
            source_pin_roles=(:g1_builder, :g1_declaration_source,
                :g2_builder, :g2_declaration_source,
                :g3_builder, :g3_child_design),
            source_pin_sha256=child_pin.sha256,
            provider_hash=heat_lift_receipt.provider.manifest_hash,
            provider_capability_hash=canonical_hash(heat_lift_receipt.provider.capability),
            obligation_hash=canonical_hash(heat_lift_receipt.obligation),
            authored_obligation_hash=heat_lift_receipt.result.authored_obligation_hash,
            result_hash=canonical_hash(heat_lift_receipt.result),
            receipt_hash=canonical_hash(heat_lift_receipt),
            source_integral_m=heat_lift_receipt.result.source_integral_m,
            source_power_w=heat_lift_receipt.result.source_power_w,
            source_power_limit_w=heat_lift_receipt.result.source_power_limit_w,
            candidate_ref=binding.candidate_ref, package_hash=binding.package_hash,
            semantic_identity=binding.semantic_identity,
            bundle_hash=binding.bundle_hash))
    end
    g3=_up2_vnext_n09_g3_context(
        g3_source_context===nothing ? nothing : g3_source_context.rebuilt_child_design,
        binding; available_route_ids=available_route_ids)
    if g3!==nothing
        g3_match_status = hasproperty(g3, :match_status) ? g3.match_status : :unique_match
        requests["N09-05"]=g3; obligations["N09-05"]=g3.obligation; matches["N09-05"]=g3_match_status
        pin=only(x for x in binding.source_pins if x.role===:g3_child_design)
        g3_provider_binding=(field_id="N09-05",status=g3_match_status,
            source_pin_roles=(:g3_builder,:g3_child_design),source_pin_sha256=pin.sha256,
            provider_hash=g3.provider.manifest_hash,provider_capability_hash=canonical_hash(g3.provider.capability),
            obligation_hash=canonical_hash(g3.obligation),trace_hash=g3.trace_hash,
            candidate_ref=binding.candidate_ref,package_hash=binding.package_hash,
            semantic_identity=binding.semantic_identity,bundle_hash=binding.bundle_hash)
        if hasproperty(g3,:normalized_provider_input)
            g3_provider_binding=merge(g3_provider_binding,
                (source_unit_basis=g3.source_unit_basis,
                 runtime_unit_basis=g3.normalized_provider_input.runtime_unit_basis,
                 unit_basis_permutation=g3.normalized_provider_input.basis_permutation,
                 normalized_provider_input=g3.normalized_provider_input,
                 normalized_provider_input_hash=g3.normalized_provider_input_hash))
        end
        push!(provider_bindings,g3_provider_binding)
    end
    available_route_ids === nothing || all(id -> haskey(obligations, id), available_route_ids) ||
        throw(ArgumentError("N09 availability selection names an absent optional source route"))
    n09_context = (requests=requests, obligations=obligations, matches=matches,
        provider_bindings=Tuple(provider_bindings),
        plan_hash=plan.plan_hash,
        g2_projection_hash=geometry_context.projection_hash,
        native_report=native_report, heat_lift_receipt=heat_lift_receipt)
    include_fe_boundary_energy_readout &&
        fe_boundary_energy_readout === nothing &&
        throw(ArgumentError("opt-in FE boundary-energy readout requires the actual N09-04 report and heat-lift receipt"))
    include_fe_boundary_energy_readout &&
        (n09_context = merge(n09_context,
            (fe_boundary_energy_readout=fe_boundary_energy_readout,)))
    (n09_context=n09_context, g1_context=g1_context)
end

function _up2_vnext_n09_context(package,
        binding::UP2VNextSourceBindingV1,
        geometry_context::NamedTuple, plan; g3_source_context=nothing,
        g1_context=nothing, native_report=nothing,
        heat_lift_receipt=nothing,
        include_fe_boundary_energy_readout::Bool=false,
        available_route_ids=nothing)
    _up2_vnext_n09_context_with_g1(package, binding, geometry_context, plan;
        g3_source_context=g3_source_context, g1_context=g1_context,
        native_report=native_report,
        heat_lift_receipt=heat_lift_receipt,
        include_fe_boundary_energy_readout=include_fe_boundary_energy_readout,
        available_route_ids=available_route_ids).n09_context
end

function _up2_vnext_n04_05_context_without_child_design(context::NamedTuple)
    Base.structdiff(context, (rebuilt_child_design=nothing,))
end

function _up2_vnext_n09_mutated_match(context::NamedTuple, row_id::String;
        archive=nothing, binding=nothing)
    request = get(context.requests, row_id, nothing)
    request === nothing && throw(ArgumentError("N09 service request is absent"))
    capability = context.obligations[row_id]
    runtime = _up2_vnext_n09_runtime()
    capability_constructor = getfield(runtime, :CapabilitySignatureV4)
    if row_id=="N09-05"
        x=context.requests[row_id]
        altered=_up2_vnext_n09_g3_obligation(x.design,x.control,x.binding;
            fault_basis=:continuous_interpolation)
        result=Base.invokelatest(getfield(runtime,:match_provider),altered,(x.provider,))
        result.status===getfield(runtime,:out_of_domain) && result.provider===nothing ||
            throw(ArgumentError("N09-05 inter-sample mutation did not become out_of_domain"))
        _up2_vnext_archive_n09_gap!(runtime, archive, binding, context, row_id, altered, result)
        return result
    end
    altered = if row_id == "N09-04"
        flux_outputs = Tuple(x for x in capability.required_output
            if x == "q:W_m2")
        length(flux_outputs) == 1 ||
            throw(ArgumentError("N09-04 heat-lift capability has no unique Fourier-flux output token"))
        mutated_output = Tuple(x == "q:W_m2" ?
            "q:W_m2:fourier_sign_control" : x
            for x in capability.required_output)
        Base.invokelatest(capability_constructor,
            capability.schema, capability.revision, capability.kind,
            capability.operator, capability.states, capability.source_space,
            capability.target_space, capability.dimension, capability.coordinates,
            capability.boundary_relation, capability.interface_relation,
            capability.time_semantics, mutated_output,
            capability.evidence_level, capability.applicability_bounds;
            input_schema_hash=capability.input_schema_hash,
            coordinate_system=capability.coordinate_system)
    elseif row_id == "N09-01"
        Base.invokelatest(capability_constructor,
            capability.schema, capability.revision,
            capability.kind, capability.operator, capability.states,
            capability.source_space, capability.source_space,
            capability.dimension, capability.coordinates,
            capability.boundary_relation, capability.interface_relation,
            capability.time_semantics, capability.required_output,
            capability.evidence_level, capability.applicability_bounds;
            input_schema_hash=capability.input_schema_hash,
            coordinate_system=capability.coordinate_system)
    elseif row_id == "N09-02"
        Base.invokelatest(capability_constructor,
            capability.schema, capability.revision,
            capability.kind, capability.operator, capability.states,
            capability.source_space, "gridap_q0_l2_space",
            capability.dimension, capability.coordinates,
            capability.boundary_relation, capability.interface_relation,
            capability.time_semantics, capability.required_output,
            capability.evidence_level, capability.applicability_bounds;
            input_schema_hash=capability.input_schema_hash,
            coordinate_system=capability.coordinate_system)
    elseif row_id == "N09-03"
        Base.invokelatest(capability_constructor,
            capability.schema, capability.revision,
            capability.kind, capability.operator, capability.states,
            capability.source_space, capability.target_space,
            capability.dimension, capability.coordinates,
            "five-candidate-owned-exterior-faces-zero-dirichlet",
            capability.interface_relation, capability.time_semantics,
            capability.required_output, capability.evidence_level,
            capability.applicability_bounds;
            input_schema_hash=capability.input_schema_hash,
            coordinate_system=capability.coordinate_system)
    else
        throw(ArgumentError("N09 row has no controlled native capability mutation"))
    end
    result = Base.invokelatest(getfield(runtime, :match_provider),
        altered, (request.provider,))
    result.status === getfield(runtime, :out_of_domain) && result.provider === nothing ||
        throw(ArgumentError("N09 controlled capability mutation did not produce out_of_domain"))
    _up2_vnext_archive_n09_gap!(runtime, archive, binding, context, row_id, altered, result)
    result
end

function _up2_vnext_archive_candidate_ref_v1(binding::UP2VNextSourceBindingV1)
    canonical_hash((schema="up2-vnext-capability-archive-candidate-ref-v1",
        candidate_ref=binding.candidate_ref, candidate_id=binding.candidate_id,
        scenario_id=binding.scenario_id, binding_hash=binding.binding_hash,
        package_hash=binding.package_hash, semantic_identity=binding.semantic_identity,
        bundle_hash=binding.bundle_hash))
end

function _up2_vnext_archive_n09_gap!(runtime, archive, binding, context, row_id,
        obligation::Any, result)
    archive === nothing && return nothing
    binding isa UP2VNextSourceBindingV1 ||
        throw(ArgumentError("N09 archive observation requires the current T1 source binding"))
    archive_type = getfield(runtime, :CapabilityArchiveV4)
    typeof(archive) === archive_type ||
        throw(ArgumentError("N09 archive sink must be the current RuntimeV4 CapabilityArchiveV4"))
    row_id in ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05") ||
        throw(ArgumentError("N09 archive stage is not a frozen provider-gap mutation"))
    result.status === getfield(runtime, :out_of_domain) && result.provider === nothing ||
        throw(ArgumentError("N09 archive accepts only the actual non-unique provider match"))
    request = get(context.requests, row_id, nothing)
    request === nothing && throw(ArgumentError("N09 archive source provider request is absent"))
    provider = request.provider
    retry_hash = Base.invokelatest(getfield(runtime, :_archive_provider_hash), (provider,))
    archive_candidate_ref = _up2_vnext_archive_candidate_ref_v1(binding)
    stage = Symbol("up2_", replace(lowercase(row_id), "-" => "_"))
    Base.invokelatest(getfield(runtime, :defer!), archive, archive_candidate_ref,
        stage, obligation, result.status, result.reason, retry_hash)
end

function _up2_vnext_g2_up2_value(spec::UP2MutationSpecV1, value)
    if spec.id in ("N07-01", "N07-02")
        value isa NTuple{3,Rational{Int64}} ||
            throw(ArgumentError("VNext $(spec.id) source is not an exact rational 3-tuple"))
        return UP2TupleValueV1(value, :rational)
    elseif spec.id == "N07-03"
        value isa Tuple && all(x -> x isa Symbol, value) ||
            throw(ArgumentError("VNext N07-03 source is not a symbol tuple"))
        return UP2TupleValueV1(value, :symbol)
    elseif spec.id == "N07-04"
        value isa NTuple{2,Rational{Int64}} ||
            throw(ArgumentError("VNext N07-04 source is not an exact rational 2-tuple"))
        return UP2TupleValueV1(value, :rational)
    elseif spec.id == "N08-01"
        value isa NTuple{3,Symbol} ||
            throw(ArgumentError("VNext N08-01 source is not a Symbol 3-tuple"))
        return UP2TupleValueV1(value, :symbol)
    elseif spec.id in ("N07-05", "N08-02", "N08-04")
        value isa Symbol || throw(ArgumentError("VNext $(spec.id) source is not a Symbol"))
        return UP2SymbolValueV1(value)
    elseif spec.id == "N08-03"
        value isa NTuple{3,Int} ||
            throw(ArgumentError("VNext N08-03 source is not an Int tuple"))
        return UP2TupleValueV1(value, :integer)
    elseif spec.id == "N08-05"
        value isa Tuple && all(x -> x isa QualifiedRefV1 && x.version == "v2", value) ||
            throw(ArgumentError("VNext N08-05 source is not a typed G2 interface-ref tuple"))
        return UP2TupleValueV1(value, :qualified_ref)
    end
    throw(ArgumentError("VNext $(spec.id) has no G2 typed UP2 conversion"))
end

function _up2_vnext_unit_signature(value)
    exponents = _n03_get(value, :exponents)
    exponents isa AbstractVector && length(exponents) == 7 ||
        throw(ArgumentError("N04-05 unit signature is incomplete"))
    UnitSignature(ntuple(i -> _n03_vnext_time(exponents[i]), 7))
end

Base.@noinline Base.@nospecializeinfer function _up2_vnext_typed_ledger_context(ledger_wire, design, realization,
        rebuilt_design, binding::UP2VNextSourceBindingV1)
    Base.@nospecialize ledger_wire design realization rebuilt_design binding
    ledger_wire === nothing && return nothing
    child_pins = Tuple(pin for pin in binding.source_pins
        if pin.role === :g3_child_design)
    length(child_pins) == 1 ||
        throw(ArgumentError("N04 typed ledger requires one G3 child-source pin"))
    child_pin = only(child_pins)
    candidate_wire = _n03_get(ledger_wire, :candidate_ref)
    _up2_vnext_g2_ref_matches(candidate_wire, binding.candidate_ref) &&
        _n03_get(ledger_wire, :candidate_id) == binding.candidate_id &&
        _n03_get(ledger_wire, :scenario_id) == binding.scenario_id ||
        throw(ArgumentError("N04 typed ledger candidate identity differs from its T1 binding"))
    source_path = String(_n03_get(ledger_wire, :source_path))
    source_sha_value = _n03_get(_n03_get(ledger_wire, :source_sha256), :value)
    source_sha_value isa AbstractString &&
        occursin(r"^[0-9a-f]{64}$", String(source_sha_value)) ||
        throw(ArgumentError("N04 typed ledger child-source digest is malformed"))
    source_path == rebuilt_design.source_path &&
        _n03_get(ledger_wire, :design_scope) == "candidate_design_only" &&
        source_sha_value == child_pin.sha256.value ||
        throw(ArgumentError("N04 typed ledger source identity differs from its pinned child source"))

    rebuilt_design.candidate_id == binding.candidate_id &&
        rebuilt_design.scenario_id == binding.scenario_id &&
        _up2_vnext_wire_semantic_equal(
            _n03_get(design, :realization), semantic_view(rebuilt_design.realization)) ||
        throw(ArgumentError("N04 child-source reconstruction differs from candidate design identity or realization"))

    raw_owner_records = _n03_get(ledger_wire, :account_owners)
    raw_memberships = _n03_get(ledger_wire, :owner_scope_account_membership)
    raw_owner_records isa AbstractVector && raw_memberships isa AbstractVector ||
        throw(ArgumentError("N04 typed ledger explicit owner crosswalk is absent"))
    all(record -> begin
        account_id, owner = _n03_get(record, :account_id), _n03_get(record, :owner)
        account_id isa AbstractString && !isempty(String(account_id)) &&
            owner isa AbstractString && !isempty(String(owner))
    end, raw_owner_records) ||
        throw(ArgumentError("N04 typed ledger owner crosswalk contains malformed values"))
    all(record -> begin
        owner_scope = _n03_get(record, :owner_scope)
        account_scope_ids = _n03_get(record, :account_ids)
        owner_scope isa AbstractString && !isempty(String(owner_scope)) &&
            account_scope_ids isa AbstractVector &&
            all(id -> id isa AbstractString && !isempty(String(id)), account_scope_ids)
    end, raw_memberships) ||
        throw(ArgumentError("N04 typed ledger owner-scope membership contains malformed values"))
    owner_records = Tuple((account_id=String(_n03_get(record, :account_id)),
        owner=String(_n03_get(record, :owner))) for record in raw_owner_records)
    _up2_vnext_wire_semantic_equal(raw_owner_records,
        rebuilt_design.account_owners) ||
        throw(ArgumentError("N04 typed ledger owners differ from the pinned authored crosswalk"))

    accounts = realization.ledger_accounts
    account_ids = Tuple(account.account_id for account in accounts)
    !isempty(account_ids) && length(unique(account_ids)) == length(account_ids) ||
        throw(ArgumentError("N04 typed ledger accounts are empty or duplicated"))
    owner_ids = Tuple(record.account_id for record in owner_records)
    length(owner_ids) == length(unique(owner_ids)) &&
        Set(owner_ids) == Set(account_ids) &&
        all(record -> !isempty(record.owner), owner_records) ||
        throw(ArgumentError("N04 explicit owner records must cover every account exactly once"))
    owner_by_id = Dict(record.account_id => record.owner for record in owner_records)
    typed_accounts = Tuple(G3LedgerAccountV2(account.account_id,
        account.domain, account.unit, owner_by_id[account.account_id])
        for account in accounts)
    raw_accounts = _n03_get(ledger_wire, :accounts)
    _up2_vnext_wire_semantic_equal(raw_accounts, typed_accounts) ||
        throw(ArgumentError("N04 typed G3 accounts differ from source accounts and explicit owners"))

    raw_source_accounts = _n03_get(ledger_wire, :source_accounts)
    _up2_vnext_wire_semantic_equal(raw_source_accounts, accounts) ||
        throw(ArgumentError("N04 typed ledger source accounts differ from authored G3 accounts"))
    entries = Tuple(G3LedgerEntryV2(entry.entry_id, entry.account_id,
        entry.port_id, entry.component_id, entry.coefficient, entry.unit,
        entry.effect) for entry in realization.ledger_entries)
    closures = Tuple(G3LedgerClosureV2(closure.closure_id, closure.domain,
        closure.account_ids, closure.expected_balance)
        for closure in realization.ledger_closures)
    _up2_vnext_wire_semantic_equal(_n03_get(ledger_wire, :entries), entries) &&
        _up2_vnext_wire_semantic_equal(_n03_get(ledger_wire, :closures), closures) ||
        throw(ArgumentError("N04 typed ledger entries or closures differ from authored G3 values"))
    all(entry -> entry.account_id in account_ids, entries) &&
        all(id -> id in account_ids, (id for closure in closures
            for id in closure.account_ids)) ||
        throw(ArgumentError("N04 typed ledger contains an unknown account reference"))
    length(unique(Tuple(entry.entry_id for entry in entries))) == length(entries) &&
        length(unique(Tuple(closure.closure_id for closure in closures))) ==
            length(closures) ||
        throw(ArgumentError("N04 typed ledger entries or closures are duplicated"))

    length(raw_memberships) == 1 &&
        _up2_vnext_wire_semantic_equal(raw_memberships,
            rebuilt_design.owner_scope_account_membership) ||
        throw(ArgumentError("N04 owner-scope/account membership is absent or ambiguous"))
    membership = only(Tuple((owner_scope=String(_n03_get(record, :owner_scope)),
        account_ids=Tuple(String(id) for id in _n03_get(record, :account_ids)))
        for record in raw_memberships))
    expected_scope_accounts = Tuple(account.account_id for account in accounts
        if account.owner_scope == membership.owner_scope)
    membership.owner_scope == realization.owner_scope &&
        length(unique(membership.account_ids)) == length(membership.account_ids) &&
        all(id -> id in account_ids, membership.account_ids) &&
        membership.account_ids == expected_scope_accounts ||
        throw(ArgumentError("N04 owner-scope/account membership differs from typed account scopes"))

    balances = Tuple((closure_id=closure.closure_id,
        account_ids=closure.account_ids,
        actual_balance=sum(entry.coefficient for entry in entries
            if entry.account_id in closure.account_ids),
        expected_balance=closure.expected_balance) for closure in closures)
    all(balance -> balance.actual_balance == balance.expected_balance, balances) ||
        throw(ArgumentError("N04 typed ledger closure coefficient sum is unbalanced"))
    _up2_vnext_wire_semantic_equal(_n03_get(ledger_wire, :balances), balances) ||
        throw(ArgumentError("N04 typed ledger balance view differs from entries and closures"))

    source_sha256 = Digest256(String(source_sha_value))
    body = (candidate_ref=binding.candidate_ref,
        candidate_id=String(binding.candidate_id), scenario_id=String(binding.scenario_id),
        source_path=source_path, design_scope=:candidate_design_only,
        source_sha256=source_sha256, source_accounts=accounts,
        account_owners=owner_records,
        owner_scope_account_membership=(membership,), accounts=typed_accounts,
        entries=entries, closures=closures, balances=balances,
        claim_ceiling=:contract_only, physical_validation=false,
        engineering_validation=false, measurement_authority=false,
        upstream_G1_authority=:missing, upstream_G2_authority=:missing)
    if hasproperty(rebuilt_design, :unit_basis)
        rebuilt_design.schema == "up4-r2-g3-child-design-source-v2" &&
            rebuilt_design.unit_basis == (:kg, :m, :s, :A, :K, :mol, :cd) ||
            throw(ArgumentError("N04 typed child unit-basis branch is invalid"))
        network = rebuilt_design.resource_network
        effort_waivers = Tuple(rebuilt_design.effort_ports_without_ledger)
        effort_waivers == ("source_voltage",) ||
            throw(ArgumentError("N04 v2 effort-ledger waiver differs from exact source_voltage port"))
        network isa G3ResourceNetworkV2 && isempty(g3_validate_resource_network(network;
            effort_ports_without_ledger=effort_waivers)) ||
            throw(ArgumentError("N04 v2 child resource network is invalid"))
        laws = Tuple(rebuilt_design.authored_power_laws)
        links = Tuple(rebuilt_design.control_resource_links)
        all(law -> law isa G3AuthoredPowerLawV1, laws) &&
            all(link -> link isa G3ControlResourceLinkV2, links) ||
            throw(ArgumentError("N04 v2 child power laws or control links are untyped"))
        heat_lift = rebuilt_design.authored_heat_lift
        _up2_vnext_wire_semantic_equal(_n03_get(ledger_wire, :authored_heat_lift),
            heat_lift) ||
            throw(ArgumentError("N04 authored heat-lift tuple differs from pinned G3 child source"))
        budget = only(Tuple(entry for entry in realization.ledger_entries
            if entry.entry_id == heat_lift.budget_join.entry_id))
        heat_lift.schema == "g3-authored-scalar-heat-lift-v1" &&
            heat_lift.version == "v1" &&
            heat_lift.candidate_id == binding.candidate_id &&
            heat_lift.scenario_id == binding.scenario_id &&
            heat_lift.source_unit_basis == rebuilt_design.unit_basis &&
            heat_lift.native_unit_basis == (:m, :kg, :s, :A, :K, :mol, :cd) &&
            heat_lift.native_basis_permutation == (2, 1, 3, 4, 5, 6, 7) &&
            heat_lift.source_operator === :minus_div_k_grad &&
            heat_lift.budget_join.entry_id == "field_allocation" &&
            heat_lift.budget_join.account_id == budget.account_id == "design_energy" &&
            heat_lift.budget_join.port_id == budget.port_id == "diffusion_load" &&
            heat_lift.budget_join.component_id == budget.component_id == "diffusion_core" &&
            budget.effect === :load && budget.unit == UnitSignature((1, 2, -3, 0, 0, 0, 0)) &&
            budget.coefficient == -500 &&
            heat_lift.budget_join.coefficient_w == budget.coefficient &&
            heat_lift.budget_join.limit_w == abs(budget.coefficient) == 500 ||
            throw(ArgumentError("N04 authored heat-lift budget differs from the exact -500W field allocation"))
        _up2_vnext_wire_semantic_equal(_n03_get(ledger_wire, :effort_ports_without_ledger), effort_waivers) &&
            _up2_vnext_wire_semantic_equal(_n03_get(ledger_wire, :resource_network), network) &&
            _up2_vnext_wire_semantic_equal(_n03_get(ledger_wire, :authored_power_laws), laws) &&
            _up2_vnext_wire_semantic_equal(_n03_get(ledger_wire, :control_resource_links), links) &&
            _up2_vnext_wire_semantic_equal(_n03_get(ledger_wire, :unit_basis), rebuilt_design.unit_basis) &&
            _up2_vnext_wire_semantic_equal(_n03_get(ledger_wire, :command_to_current_map),
                rebuilt_design.control_design.command_to_current_map) &&
            _up2_vnext_wire_semantic_equal(_n03_get(ledger_wire, :command_to_power_map),
                rebuilt_design.control_design.command_to_power_map) &&
            _n03_get(ledger_wire, :power_status_signal_id) == "source_power_resource" ||
            throw(ArgumentError("N04 v2 typed resource/control view differs from pinned G3 source"))
        body = merge(body, (unit_basis=rebuilt_design.unit_basis,
            resource_network=network,
            effort_ports_without_ledger=effort_waivers,
            authored_power_laws=laws,
            authored_heat_lift=heat_lift, control_resource_links=links,
            command_to_current_map=rebuilt_design.control_design.command_to_current_map,
            command_to_power_map=rebuilt_design.control_design.command_to_power_map,
            power_status_signal_id="source_power_resource",
            source_unit_contract=:declared_si_candidate_design_v2))
    end
    identity_hash = canonical_hash(body)
    wire_identity_hash = _n03_get(_n03_get(ledger_wire, :identity_hash), :value)
    wire_identity_hash == identity_hash.value &&
        _up2_vnext_wire_semantic_equal(ledger_wire,
            merge(body, (identity_hash=identity_hash,))) ||
        throw(ArgumentError("N04 typed ledger inner identity hash or canonical body mismatch"))
    context = (identity_hash=identity_hash, source_sha256=source_sha256,
        source_pin_sha256=child_pin.sha256, source_path=source_path,
        owner=first(typed_accounts).owner,
        entry_account_id=first(entries).account_id,
        account_ids=account_ids, accounts=typed_accounts, entries=entries,
        closures=closures, balances=balances,
        authority_scope=:local_source_data,
        authority_gap="candidate_authored_typed_ledger_is_design_only")
    hasproperty(rebuilt_design, :unit_basis) ? merge(context,
        (candidate_ref=binding.candidate_ref, candidate_id=binding.candidate_id,
         source_accounts=accounts,
         account_owners=owner_records,
         owner_scope_account_membership=(membership,),
         scenario_id=binding.scenario_id, unit_basis=rebuilt_design.unit_basis,
         resource_network=rebuilt_design.resource_network,
         effort_ports_without_ledger=Tuple(rebuilt_design.effort_ports_without_ledger),
         authored_power_laws=Tuple(rebuilt_design.authored_power_laws),
         authored_heat_lift=rebuilt_design.authored_heat_lift,
         control_resource_links=Tuple(rebuilt_design.control_resource_links),
         command_to_current_map=rebuilt_design.control_design.command_to_current_map,
         command_to_power_map=rebuilt_design.control_design.command_to_power_map,
         power_status_signal_id="source_power_resource")) : context
end

function _up2_vnext_n06_resource_network(context, binding::UP2VNextSourceBindingV1)
    verified = _up2_vnext_n06_04_closure(context, binding)
    typed = context.typed_ledger_context
    hasproperty(typed, :resource_network) &&
        hasproperty(typed, :authored_power_laws) &&
        hasproperty(typed, :effort_ports_without_ledger) ||
        throw(ArgumentError("VNext N06 typed resource network or authored power-law proof is absent"))
    network = typed.resource_network
    laws = Tuple(law for law in typed.authored_power_laws
        if law isa G3AuthoredPowerLawV1 && law.law_id == "source_bus_VI")
    length(laws) == 1 ||
        throw(ArgumentError("VNext N06 source-bus V-I law is absent or ambiguous"))
    law = only(laws)
    effort = Tuple(port for port in network.resource_ports
        if port.port_id == law.effort_port_id)
    current = Tuple(port for port in network.resource_ports
        if port.port_id == law.current_port_id)
    length(effort) == 1 && length(current) == 1 ||
        throw(ArgumentError("VNext N06 source-bus law ports are absent or ambiguous"))
    effort_port, current_port = only(effort), only(current)
    effort_port.kind === :effort &&
        current_port.kind in (:flow, :return) &&
        law.voltage * law.current == law.power ||
        throw(ArgumentError("VNext N06 source-bus law does not bind typed effort/current ports"))
    typed.effort_ports_without_ledger == (effort_port.port_id,) ||
        throw(ArgumentError("VNext N06 ledger-free effort exception differs from the bound source V-I law"))
    network isa G3ResourceNetworkV2 && isempty(g3_validate_resource_network(network;
        effort_ports_without_ledger=typed.effort_ports_without_ledger)) ||
        throw(ArgumentError("VNext N06 typed resource network is invalid"))
    verified.closure isa G3LedgerClosureV2 ||
        throw(ArgumentError("VNext N06 source network lacks its verified ledger closure"))
    (typed=typed, network=network, source_law=law,
        effort_port=effort_port, current_port=current_port)
end

function _up2_vnext_n06_mismatched_kind(port::G3ResourcePortV2)
    first(kind for kind in _G3_V5_RESOURCE_KINDS
        if kind !== port.kind && _g3_expected_unit(kind) != port.unit)
end

function _up2_vnext_n06_03_flow_link(context, binding::UP2VNextSourceBindingV1)
    context isa NamedTuple && hasproperty(context, :typed_ledger_context) &&
        context.typed_ledger_context isa NamedTuple &&
        hasproperty(context.typed_ledger_context, :resource_network) ||
        throw(ArgumentError("VNext N06-03 requires the current-source typed resource network"))
    context.authority_scope === :local_source_data &&
        context.n03_projection_hash == binding.n03_projection_hash &&
        context.package_hash == binding.package_hash ||
        throw(ArgumentError("VNext N06-03 network differs from its T1 source binding"))
    pins = Tuple(pin for pin in binding.source_pins if pin.role === :g3_child_design)
    length(pins) == 1 || throw(ArgumentError("VNext N06-03 requires one pinned G3 child source"))
    pin = only(pins)
    typed = context.typed_ledger_context
    typed.source_pin_sha256 == pin.sha256 && typed.source_sha256 == pin.sha256 &&
        typed.unit_basis == (:kg, :m, :s, :A, :K, :mol, :cd) ||
        throw(ArgumentError("VNext N06-03 network basis/source pin is invalid"))
    network = typed.resource_network
    hasproperty(typed, :effort_ports_without_ledger) &&
        typed.effort_ports_without_ledger == ("source_voltage",) ||
        throw(ArgumentError("VNext N06-03 effort-ledger waiver is not the pinned source_voltage allowlist"))
    network isa G3ResourceNetworkV2 && isempty(g3_validate_resource_network(network;
        effort_ports_without_ledger=typed.effort_ports_without_ledger)) ||
        throw(ArgumentError("VNext N06-03 candidate resource network is invalid"))
    flow = Tuple(port for port in network.resource_ports if port.kind === :flow)
    length(flow) == 1 || throw(ArgumentError("VNext N06-03 flow port is absent or ambiguous"))
    flow_port = only(flow)
    flow_port.port_id == "source_supply_current" &&
        flow_port.unit == UnitSignature((0, 0, 0, 1, 0, 0, 0)) &&
        flow_port.direction in (:out, :bidirectional) ||
        throw(ArgumentError("VNext N06-03 selected flow is not source_supply_current in A"))
    links = typed.control_resource_links
    length(links) == 1 || throw(ArgumentError("VNext N06-03 control link is absent or ambiguous"))
    link = only(links)
    link isa G3ControlResourceLinkV2 &&
        link.link_id == "thermal_supervisor_source_supply_current" &&
        link.controller_id == "candidate_thermal_supervisor" &&
        link.sensor_port_id == "core_temperature" &&
        link.actuator_port_id == "source_fraction_command" &&
        link.resource_port_id == flow_port.port_id &&
        link.fault_id == "core_overtemperature_trip" ||
        throw(ArgumentError("VNext N06-03 link does not exactly join authored control and flow IDs"))
    laws = Tuple(law for law in typed.authored_power_laws if law.law_id == "source_bus_VI")
    length(laws) == 1 || throw(ArgumentError("VNext N06-03 source V-I-P law is absent or ambiguous"))
    law = only(laws)
    law.effort_port_id == "source_voltage" &&
        law.current_port_id == flow_port.port_id &&
        law.power_endpoint_id == "source_bus" &&
        law.voltage == 500 && law.current == 2 && law.power == 1000 ||
        throw(ArgumentError("VNext N06-03 current-flow link is not joined to 500V*2A=1000W source_bus"))
    typed.power_status_signal_id == "source_power_resource" &&
        typed.power_status_signal_id != link.resource_port_id &&
        typed.command_to_current_map.target_resource_port_id == link.resource_port_id &&
        typed.command_to_current_map.law === :fraction_of_rated_current &&
        typed.command_to_current_map.rated_current == law.current &&
        typed.command_to_current_map.rated_current_unit == flow_port.unit &&
        typed.command_to_current_map.output_unit == flow_port.unit ||
        throw(ArgumentError("VNext N06-03 command/current or separate power-status join is invalid"))
    (link=link, flow_port=flow_port, source_law=law)
end

function _up2_vnext_n06_04_closure(context::NamedTuple, binding::UP2VNextSourceBindingV1)
    context isa NamedTuple && hasproperty(context, :typed_ledger_context) &&
        context.typed_ledger_context isa NamedTuple ||
        throw(ArgumentError("VNext N06-04 requires the candidate-bound typed G3 ledger"))
    context.authority_scope === :local_source_data &&
        context.authority_gap == "candidate_authored_g3_ledger_capacity_is_design_only" &&
        context.n03_projection_hash == binding.n03_projection_hash &&
        context.package_hash == binding.package_hash ||
        throw(ArgumentError("VNext N06-04 ledger context differs from its source binding"))
    child_pins = Tuple(pin for pin in binding.source_pins
        if pin.role === :g3_child_design)
    length(child_pins) == 1 ||
        throw(ArgumentError("VNext N06-04 requires one pinned G3 child-design source"))
    child_pin = only(child_pins)
    typed = context.typed_ledger_context
    typed.authority_scope === :local_source_data &&
        typed.authority_gap == "candidate_authored_typed_ledger_is_design_only" &&
        typed.source_pin_sha256 == child_pin.sha256 &&
        typed.source_sha256 == child_pin.sha256 ||
        throw(ArgumentError("VNext N06-04 typed ledger is not bound to the G3 child source"))
    closure_rows = Tuple(closure for closure in typed.closures
        if closure.closure_id == context.closure_id)
    length(closure_rows) == 1 ||
        throw(ArgumentError("VNext N06-04 source closure is absent or ambiguous"))
    closure = only(closure_rows)
    closure isa G3LedgerClosureV2 && closure.domain === :energy &&
        closure.account_ids == context.closure_account_ids &&
        !isempty(closure.account_ids) &&
        length(unique(closure.account_ids)) == length(closure.account_ids) ||
        throw(ArgumentError("VNext N06-04 closure domain or account binding is invalid"))
    account_ids = Tuple(account.account_id for account in typed.accounts)
    length(unique(account_ids)) == length(account_ids) ||
        throw(ArgumentError("VNext N06-04 typed accounts are ambiguous"))
    closure_accounts = Tuple(account for account in typed.accounts
        if account.account_id in closure.account_ids)
    length(closure_accounts) == length(closure.account_ids) &&
        all(account -> account.domain === closure.domain, closure_accounts) &&
        length(unique(Tuple(account.unit for account in closure_accounts))) == 1 ||
        throw(ArgumentError("VNext N06-04 closure accounts differ in domain or unit"))
    all(entry -> begin
        accounts = Tuple(account for account in typed.accounts
            if account.account_id == entry.account_id)
        length(accounts) == 1 && only(accounts).unit == entry.unit
    end, typed.entries) ||
        throw(ArgumentError("VNext N06-04 ledger entry account/unit join is invalid"))
    closure_entries = Tuple(entry for entry in typed.entries
        if entry.account_id in closure.account_ids)
    !isempty(closure_entries) ||
        throw(ArgumentError("VNext N06-04 closure has no typed ledger entries"))
    actual_balance = sum(entry.coefficient for entry in closure_entries)
    actual_balance == closure.expected_balance ||
        throw(ArgumentError("VNext N06-04 source closure balance is not independently closed"))
    balance_rows = Tuple(balance for balance in typed.balances
        if balance.closure_id == closure.closure_id)
    length(balance_rows) == 1 && only(balance_rows).actual_balance == actual_balance &&
        only(balance_rows).expected_balance == closure.expected_balance ||
        throw(ArgumentError("VNext N06-04 typed balance view differs from entries and closure"))
    (closure=closure, actual_balance=actual_balance, entries=typed.entries)
end

Base.@noinline Base.@nospecializeinfer function _up2_vnext_n04_05_context(package,
        binding::UP2VNextSourceBindingV1; event_projection=nothing,
        include_child_design=false, identity_package=nothing)
    Base.@nospecialize package binding event_projection include_child_design identity_package
    isdefined(@__MODULE__, :n03_vnext_t1_local_event_projection) ||
        throw(ArgumentError("N04-05 requires the verified VNext G3 projection"))
    event_projection === nothing ||
        (isdefined(@__MODULE__, :N03VNextLocalEventProjectionV1) &&
            event_projection isa getfield(@__MODULE__, :N03VNextLocalEventProjectionV1)) ||
        throw(ArgumentError("N04-05 received an unverified N03 projection value"))
    pins = NamedTuple{_UP2_VNEXT_SOURCE_ROLES}(Tuple(
        (bytes=pin.byte_count, sha256=pin.sha256) for pin in binding.source_pins))
    projection = event_projection === nothing ?
        getfield(@__MODULE__, :n03_vnext_t1_local_event_projection)(package;
            candidate_ref=binding.candidate_ref, candidate_id=binding.candidate_id,
            scenario_id=binding.scenario_id, snapshot_id=binding.snapshot_id,
            manifest_sha256=binding.manifest_sha256,
            package_hash=binding.package_hash,
            semantic_identity=binding.semantic_identity,
            bundle_hash=binding.bundle_hash, source_pins=pins) : event_projection
    projection.status === :local_source_bound &&
        projection.resolution === :terminal_deferred &&
        projection.reason === :candidate_design_event_time_policy_consumed &&
        projection.time_basis === :event &&
        projection.authority_scope === :local_source_data &&
        projection.authority_gap == "candidate_authored_event_time_policy_is_design_only" &&
        projection.projection_hash == binding.n03_projection_hash &&
        projection.candidate_ref == binding.candidate_ref &&
        projection.candidate_id == binding.candidate_id &&
        projection.scenario_id == binding.scenario_id &&
        projection.snapshot_id == binding.snapshot_id &&
        projection.manifest_sha256 == binding.manifest_sha256 &&
        projection.package_hash == binding.package_hash &&
        projection.semantic_identity == binding.semantic_identity &&
        projection.bundle_hash == binding.bundle_hash &&
        projection.event_id == binding.event_id &&
        projection.trigger === binding.trigger &&
        projection.time == binding.time ||
        throw(ArgumentError("N04-05 VNext package no longer matches its source binding"))
    projection_pin_values = Tuple((pin.role, pin.byte_count, pin.sha256)
        for pin in projection.source_pins)
    binding_pin_values = Tuple((pin.role, pin.byte_count, pin.sha256)
        for pin in binding.source_pins)
    Tuple(pin.role for pin in projection.source_pins) == _UP2_VNEXT_SOURCE_ROLES &&
        projection_pin_values == binding_pin_values ||
        throw(ArgumentError("N04-05 N03 projection source pins differ from the source binding"))

    g3_matches = Tuple(d for d in package.declarations if d.layer === :G3)
    length(g3_matches) == 1 ||
        throw(ArgumentError("N04-05 requires one bound G3 declaration"))
    body = JSON3.read(String(copy_bytes(only(g3_matches).semantic_body_bytes)))
    design = _n03_get(body, :authored_child_design)
    _n03_get(design, :schema) in ("up4-r2-g3-child-design-source-v1",
        "up4-r2-g3-child-design-source-v2") &&
        _n03_get(design, :design_scope) == "candidate_design_only" &&
        _n03_get(design, :candidate_id) == binding.candidate_id &&
        _n03_get(design, :scenario_id) == binding.scenario_id ||
        throw(ArgumentError("N04-05 G3 design identity is not candidate-bound"))
    source = _n03_get(design, :realization)
    all(name -> isdefined(@__MODULE__, name),
        (:G3RealizationSourceBodyV1, :G3RealizationSourcePortV1,
         :G3RealizationComponentV1, :G3RealizationMaterialDomainV1,
         :G3RealizationManufacturingDomainV1, :G3RealizationLedgerAccountV1,
         :G3RealizationLedgerEntryV1, :G3RealizationLedgerClosureV1)) ||
        throw(ArgumentError("N04-05 typed G3 source constructors are unavailable"))
    typed_ports = Tuple(G3RealizationSourcePortV1(
        String(_n03_get(x, :port_id)), Symbol(_n03_get(x, :role)),
        _up2_vnext_unit_signature(_n03_get(x, :unit)),
        Symbol(_n03_get(x, :direction)), _n03_get(x, :sign),
        String(_n03_get(x, :owner_scope))) for x in _n03_get(source, :ports))
    typed_components = Tuple(G3RealizationComponentV1(
        String(_n03_get(x, :component_id)), Symbol(_n03_get(x, :kind)),
        Tuple(String(id) for id in _n03_get(x, :port_ids)),
        _n03_vnext_time(_n03_get(x, :capacity)),
        _up2_vnext_unit_signature(_n03_get(x, :capacity_unit)),
        String(_n03_get(x, :material_id)),
        String(_n03_get(x, :manufacturing_process_id)))
        for x in _n03_get(source, :components))
    typed_materials = Tuple(G3RealizationMaterialDomainV1(
        String(_n03_get(x, :material_id)), Symbol(_n03_get(x, :property)),
        _n03_vnext_time(_n03_get(x, :lower)),
        _n03_vnext_time(_n03_get(x, :upper)),
        _up2_vnext_unit_signature(_n03_get(x, :unit)))
        for x in _n03_get(source, :material_domains))
    typed_manufacturing = Tuple(G3RealizationManufacturingDomainV1(
        String(_n03_get(x, :process_id)), Symbol(_n03_get(x, :parameter)),
        _n03_vnext_time(_n03_get(x, :lower)),
        _n03_vnext_time(_n03_get(x, :upper)),
        _up2_vnext_unit_signature(_n03_get(x, :unit)))
        for x in _n03_get(source, :manufacturing_domains))
    typed_accounts = Tuple(G3RealizationLedgerAccountV1(
        String(_n03_get(x, :account_id)), Symbol(_n03_get(x, :domain)),
        _up2_vnext_unit_signature(_n03_get(x, :unit)),
        String(_n03_get(x, :owner_scope)))
        for x in _n03_get(source, :ledger_accounts))
    typed_entries = Tuple(G3RealizationLedgerEntryV1(
        String(_n03_get(x, :entry_id)), String(_n03_get(x, :account_id)),
        String(_n03_get(x, :port_id)), String(_n03_get(x, :component_id)),
        _n03_vnext_time(_n03_get(x, :coefficient)),
        _up2_vnext_unit_signature(_n03_get(x, :unit)),
        Symbol(_n03_get(x, :effect)))
        for x in _n03_get(source, :ledger_entries))
    typed_closures = Tuple(G3RealizationLedgerClosureV1(
        String(_n03_get(x, :closure_id)), Symbol(_n03_get(x, :domain)),
        Tuple(String(id) for id in _n03_get(x, :account_ids)),
        _n03_vnext_time(_n03_get(x, :expected_balance)))
        for x in _n03_get(source, :ledger_closures))
    realization = G3RealizationSourceBodyV1(
        String(_n03_get(source, :source_id)),
        String(_n03_get(source, :owner_scope)), typed_ports,
        _n03_vnext_time(_n03_get(source, :source_power)),
        _n03_vnext_time(_n03_get(source, :field_power)),
        _n03_vnext_time(_n03_get(source, :return_power)),
        _n03_vnext_time(_n03_get(source, :heat_power)),
        _n03_vnext_time(_n03_get(source, :capacity)),
        _up2_vnext_unit_signature(_n03_get(source, :capacity_unit)),
        _n03_vnext_time(_n03_get(source, :closure_residual)),
        typed_components, typed_materials, typed_manufacturing,
        typed_accounts, typed_entries, typed_closures)
    _up2_vnext_wire_semantic_equal(source, semantic_view(realization)) ||
        throw(ArgumentError("N04-05 typed G3 source reconstruction is not lossless"))
    length(realization.ledger_entries) >= 2 && !isempty(realization.ledger_closures) ||
        throw(ArgumentError("N04 typed ledger rows are incomplete"))
    entry = realization.ledger_entries[2]
    entry.entry_id == "field_allocation" && entry.effect === :load ||
        throw(ArgumentError("N04-05 row is not the authored field allocation"))
    port_rows = Tuple(x for x in realization.ports if x.port_id == entry.port_id)
    component_rows = Tuple(x for x in realization.components if
        x.component_id == entry.component_id)
    account_rows = Tuple(x for x in realization.ledger_accounts if
        x.account_id == entry.account_id)
    length(port_rows) == length(component_rows) == length(account_rows) == 1 ||
        throw(ArgumentError("N04-05 ledger identity references are not unique"))
    port, component, account =
        only(port_rows), only(component_rows), only(account_rows)
    port.role === :field && port.direction === :in &&
        component.kind === :passive_component &&
        entry.port_id in component.port_ids &&
        entry.unit == port.unit == component.capacity_unit == account.unit &&
        account.domain === :energy && account.owner_scope == realization.owner_scope &&
        port.owner_scope == realization.owner_scope ||
        throw(ArgumentError("N04-05 typed ledger identity or unit mismatch"))

    closure = realization.ledger_closures[1]
    source_entry = realization.ledger_entries[1]
    closure.closure_id == "design_energy_balance" && closure.domain === :energy &&
        !isempty(closure.account_ids) &&
        length(unique(closure.account_ids)) == length(closure.account_ids) &&
        all(id -> any(a -> a.account_id == id, realization.ledger_accounts),
            closure.account_ids) ||
        throw(ArgumentError("N04-02 candidate closure identity is invalid"))
    length(Tuple(c for c in realization.ledger_closures
        if c.closure_id == closure.closure_id)) == 1 ||
        throw(ArgumentError("N04-02 candidate closure identity is ambiguous"))
    source_port = only(Tuple(x for x in realization.ports
        if x.port_id == source_entry.port_id))
    source_component = only(Tuple(x for x in realization.components
        if x.component_id == source_entry.component_id))
    source_account = only(Tuple(x for x in realization.ledger_accounts
        if x.account_id == source_entry.account_id))
    passive_components = Tuple(x for x in realization.components
        if x.kind === :passive_component)
    source_entry.entry_id == "source_input" && source_entry.effect === :source &&
        source_port.role === :source && source_port.direction in (:out, :bidirectional) &&
        source_component.kind === :source_component &&
        source_entry.port_id in source_component.port_ids &&
        source_entry.account_id in closure.account_ids &&
        source_entry.unit == source_port.unit == source_component.capacity_unit ==
            source_account.unit && !isempty(passive_components) ||
        throw(ArgumentError("N04-04 candidate source/passive component identity is invalid"))
    passive_component = first(passive_components)
    passive_component.component_id != source_entry.component_id ||
        throw(ArgumentError("N04-04 passive mutation aliases the source component"))
    ledger_wire = _n03_get(body, :authored_typed_ledger_source)
    rebuilt_child_design = nothing
    if ledger_wire !== nothing
        child_input = _n03_get(body, :authored_child_design_input)
        source_sha = _n03_vnext_digest(child_input, :sha256)
        byte_array = _n03_get(child_input, :bytes)
        shape, values = _n03_get(byte_array, :shape), _n03_get(byte_array, :values)
        shape isa AbstractVector && length(shape) == 1 &&
            first(shape) isa Integer && !(first(shape) isa Bool) &&
            first(shape) >= 0 ||
            throw(ArgumentError("N04 authored child byte shape is invalid"))
        values isa AbstractVector && length(values) == Int(first(shape)) &&
            all(x -> x isa Integer && !(x isa Bool) && 0 <= x <= typemax(UInt8), values) ||
            throw(ArgumentError("N04 authored child bytes are malformed"))
        raw_child_bytes = UInt8.(values)
        child_pins = Tuple(pin for pin in binding.source_pins
            if pin.role === :g3_child_design)
        length(child_pins) == 1 ||
            throw(ArgumentError("N04 child source pin is absent or ambiguous"))
        child_pin = only(child_pins)
        control_children = Tuple(child for child in package.children
            if child.kind === :control)
        length(control_children) == 1 ||
            throw(ArgumentError("N04 control child source is absent or ambiguous"))
        control_child = only(control_children)
        _n03_vnext_carrier_matches(control_child.source_bytes, child_pin) &&
            length(raw_child_bytes) == child_pin.byte_count &&
            copy_bytes(control_child.source_bytes) == raw_child_bytes &&
            source_sha == child_pin.sha256 &&
            Digest256(bytes2hex(SHA.sha256(raw_child_bytes))) == child_pin.sha256 ||
            throw(ArgumentError("N04 child raw source differs from its package child and pin"))
        isdefined(@__MODULE__, :vnext_t2_v3_rebuild_g3_child_design_source_v1) ||
            throw(ArgumentError("N04 frozen G3 child source rebuilder is unavailable"))
        carrier = VNextT0LocalBytesV1(raw_child_bytes, source_sha)
        # The path comes from the typed view only as a claim and include_string
        # diagnostic name; the helper executes the pinned raw bytes and checks
        # the child builder's returned source_path against this claim.
        source_path_claim = _n03_get(ledger_wire, :source_path)
        source_path_claim isa AbstractString && !isempty(String(source_path_claim)) ||
            throw(ArgumentError("N04 typed ledger source path claim is malformed"))
        factory_invocation = nothing
        identity_proof = nothing
        if identity_package !== nothing &&
                identity_package isa CandidateStatePackageV5 &&
                isdefined(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) &&
                identity_package.g3 isa getfield(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) &&
                hasproperty(identity_package.g3.authored_payload, :source_proof)
            candidate_proof = identity_package.g3.authored_payload.source_proof
            if hasproperty(candidate_proof, :g3_factory_invocation)
                identity_package.candidate_ref == binding.candidate_ref ||
                    throw(ArgumentError("N04 selected G3 invocation is detached from current T1 candidate"))
                identity_proof = candidate_proof
                factory_invocation = identity_proof.g3_factory_invocation
                required_invocation =
                    (:candidate_id, :scenario_id, :source_path, :re_enable_threshold_kelvin)
                factory_invocation isa NamedTuple &&
                    propertynames(factory_invocation) == required_invocation &&
                    factory_invocation.candidate_id == binding.candidate_id &&
                    factory_invocation.scenario_id == binding.scenario_id ||
                    throw(ArgumentError("N04 selected G3 factory invocation differs from current T1 identity"))
                hasproperty(identity_proof, :rebuilt_child) ||
                    throw(ArgumentError("N04 selected G3 source proof has no rebuilt child"))
                proof_controls = Tuple(child for child in identity_proof.children
                    if child.kind === :control)
                length(proof_controls) == 1 ||
                    throw(ArgumentError("N04 selected G3 proof lacks a unique control child locator"))
                proof_control = only(proof_controls)
                isdefined(@__MODULE__, :VNextT0LocalChildPresentV1) &&
                    proof_control isa getfield(@__MODULE__, :VNextT0LocalChildPresentV1) &&
                    proof_control.layer === :G3 &&
                    proof_control.candidate_ref == binding.candidate_ref &&
                    proof_control.child_ref == control_child.child_ref &&
                    proof_control.source_ref == control_child.source_ref &&
                    proof_control.body_hash == control_child.body_hash &&
                    proof_control.child_identity_hash == control_child.child_identity_hash &&
                    proof_control.source_locator.source_ref == control_child.source_ref &&
                    proof_control.source_locator.provenance === :current_source &&
                    proof_control.source_locator.source_sha256 == child_pin.sha256 &&
                    proof_control.source_locator.source_size == child_pin.byte_count &&
                    proof_control.source_bytes.sha256 == child_pin.sha256 &&
                    length(proof_control.source_bytes.bytes) == child_pin.byte_count &&
                    proof_control.source_bytes.bytes == raw_child_bytes ||
                    throw(ArgumentError("N04 selected G3 proof child differs from current T1 control carrier"))
                proof_control_path = proof_control.source_locator.source_path
                factory_invocation.source_path == proof_control_path == String(source_path_claim) ||
                    throw(ArgumentError("N04 selected G3 factory path differs from its T1 source locator"))
            end
        end
        rebuilt_child_design = if identity_proof === nothing
            rebuild_g3_child = getfield(@__MODULE__, :vnext_t2_v3_rebuild_g3_child_design_source_v1)
            if factory_invocation === nothing
                Base.invokelatest(rebuild_g3_child, carrier, child_pin.sha256,
                    String(source_path_claim))
            else
                Base.invokelatest(rebuild_g3_child, carrier, child_pin.sha256,
                    String(source_path_claim); candidate_id=factory_invocation.candidate_id,
                    scenario_id=factory_invocation.scenario_id,
                    re_enable_threshold_kelvin=factory_invocation.re_enable_threshold_kelvin)
            end
        else
            proof_child = identity_proof.rebuilt_child
            proof_child.candidate_id == binding.candidate_id &&
                proof_child.scenario_id == binding.scenario_id &&
                proof_child.source_path == String(source_path_claim) &&
                identity_package.g3.authored_payload.source_sha256 == child_pin.sha256 &&
                _up2_vnext_wire_semantic_equal(design, proof_child) ||
                throw(ArgumentError("N04 retained G3 source proof child differs from current T1 source/design"))
            proof_child
        end
        rebuilt_child_design.source_path == String(source_path_claim) ||
            throw(ArgumentError("N04 rebuilt child source path differs from its typed path claim"))
        identity_proof === nothing ||
            canonical_hash(identity_proof.rebuilt_child) ==
                canonical_hash(rebuilt_child_design) ||
            throw(ArgumentError("N04 rebuilt G3 child differs from supplied V5 source proof"))
    end
    typed_ledger_context = _up2_vnext_typed_ledger_context(
        ledger_wire, design, realization, rebuilt_child_design, binding)
    source_bus_unit = nothing
    source_entry_unit = nothing
    if typed_ledger_context !== nothing
        source_entry.entry_id == "source_input" && source_port.port_id == "source_bus" &&
            source_entry.port_id == source_port.port_id ||
            throw(ArgumentError("N02-04/05 source_input does not uniquely join source_bus"))
        typed_source_entries = Tuple(x for x in typed_ledger_context.entries
            if x.entry_id == "source_input")
        length(typed_source_entries) == 1 ||
            throw(ArgumentError("N02-05 typed source_input entry is absent or ambiguous"))
        typed_source_entry = only(typed_source_entries)
        typed_source_entry.port_id == source_port.port_id &&
            typed_source_entry.unit == source_port.unit == source_entry.unit ||
            throw(ArgumentError("N02-04/05 source_input/source_bus units differ"))
        source_bus_unit = source_port.unit
        source_entry_unit = typed_source_entry.unit
    end
    result = (entry_id=entry.entry_id, account_id=entry.account_id,
        port_id=entry.port_id, component_id=entry.component_id,
        coefficient=entry.coefficient, capacity=component.capacity,
        unit=entry.unit, effect=entry.effect, port_role=port.role,
        port_direction=port.direction, authority_scope=:local_source_data,
        closure_id=closure.closure_id, closure_account_ids=closure.account_ids,
        account_ids=Tuple(a.account_id for a in realization.ledger_accounts),
        source_entry_id=source_entry.entry_id,
        source_entry_account_id=source_entry.account_id,
        source_entry_port_id=source_entry.port_id,
        source_bus_unit=source_bus_unit,
        source_entry_unit=source_entry_unit,
        n02_04_05_present=typed_ledger_context !== nothing,
        source_entry_component_id=source_entry.component_id,
        source_entry_effect=source_entry.effect,
        source_component_kind=source_component.kind,
        passive_component_id=passive_component.component_id,
        passive_component_kind=passive_component.kind,
        typed_ledger_context=typed_ledger_context,
        authority_gap="candidate_authored_g3_ledger_capacity_is_design_only",
        n03_projection_hash=projection.projection_hash,
        package_hash=binding.package_hash)
    include_child_design ? merge(result,
        (rebuilt_child_design=rebuilt_child_design,)) : result
end

"""Build the fixed UP2 row set from a verified VNext T1 package and N03 projection.

The caller supplies snapshot identity and six source pins from the sidecar and
freeze receipt it has already checked. This method rechecks those pins against
the package through N03, and uses N03 as the only source for N03-04/05. Rows
without a matching typed projector carry `UP2AbsentValueV1`; source-present
layers remain deferred and missing UP2 flux/provider evidence remains absent.
"""
Base.@noinline Base.@nospecializeinfer function up2_input_from_vnext_t1(package, mission_bounds::UP2MissionBoundsV1;
        candidate_ref=nothing, candidate_id=nothing, scenario_id=nothing,
        snapshot_id=nothing, manifest_sha256=nothing, source_pins=nothing,
        native_plan=nothing, native_report=nothing, heat_lift_receipt=nothing,
        current_identity=false, identity_package=nothing, available_route_ids=nothing)
    Base.@nospecialize package source_pins native_plan native_report heat_lift_receipt identity_package
    available_route_ids = _up2_vnext_n09_availability_routes_v1(available_route_ids)
    available_route_ids === nothing || native_plan !== nothing ||
        throw(ArgumentError("N09 availability selection requires the current native plan"))
    identity_package !== nothing && !current_identity &&
        return _up2_vnext_build_result(:fail_closed, :none,
            :n10_current_package_requires_current_identity_opt_in, nothing, nothing)
    isdefined(@__MODULE__, :n03_vnext_t1_local_event_projection) ||
        return _up2_vnext_build_result(:typed_absent, :terminal_deferred,
            :n03_vnext_projection_not_loaded, nothing, nothing)
    projection = getfield(@__MODULE__, :n03_vnext_t1_local_event_projection)(package;
        candidate_ref=candidate_ref, candidate_id=candidate_id,
        scenario_id=scenario_id, snapshot_id=snapshot_id,
        manifest_sha256=manifest_sha256, package_hash=_n03_get(package, :package_hash),
        semantic_identity=_n03_get(package, :semantic_identity),
        bundle_hash=_n03_get(package, :bundle_hash), source_pins=source_pins)
    if projection.status !== :local_source_bound ||
            projection.resolution !== :terminal_deferred
        return _up2_vnext_build_result(projection.status, projection.resolution,
            projection.reason, nothing, projection.projection_hash)
    end
    projection.reason === :candidate_design_event_time_policy_consumed &&
        projection.time_basis === :event &&
        projection.authority_scope === :local_source_data &&
        projection.authority_gap == "candidate_authored_event_time_policy_is_design_only" ||
        return _up2_vnext_build_result(:typed_absent, :terminal_deferred,
            projection.reason, nothing, projection.projection_hash)
    projection.candidate_ref == candidate_ref &&
        projection.candidate_id == candidate_id &&
        projection.scenario_id == scenario_id &&
        projection.snapshot_id == snapshot_id &&
        projection.manifest_sha256 == manifest_sha256 &&
        projection.package_hash == package.package_hash &&
        projection.semantic_identity == package.semantic_identity &&
        projection.bundle_hash == package.bundle_hash ||
        return _up2_vnext_build_result(:fail_closed, :none,
            :n03_vnext_projection_identity_mismatch, nothing,
            projection.projection_hash)
    (projection.event_id isa AbstractString && projection.trigger isa Symbol &&
        projection.time isa Rational{Int64}) ||
        return _up2_vnext_build_result(:typed_absent, :terminal_deferred,
            :n03_vnext_event_values_absent, nothing, projection.projection_hash)
    pins = Tuple(UP2VNextSourcePinV1(pin.role, pin.byte_count, pin.sha256)
        for pin in projection.source_pins)
    Tuple(pin.role for pin in pins) == _UP2_VNEXT_SOURCE_ROLES ||
        return _up2_vnext_build_result(:typed_absent, :terminal_deferred,
            :n03_vnext_source_pins_absent, nothing, projection.projection_hash)
    binding = UP2VNextSourceBindingV1(projection.candidate_ref,
        projection.candidate_id, projection.scenario_id, projection.snapshot_id,
        projection.manifest_sha256, projection.package_hash,
        projection.semantic_identity, projection.bundle_hash,
        projection.projection_hash, pins, projection.event_id,
        projection.trigger, projection.time, projection.time_basis,
        projection.status, projection.resolution, projection.authority_scope,
        projection.authority_gap)
    g1_context = try
        _up2_vnext_g1_operator_type_context(package, binding;
            include_semantic_body=current_identity)
    catch
        return _up2_vnext_build_result(:fail_closed, :none,
            :vnext_g1_operator_type_context_invalid, nothing,
            projection.projection_hash)
    end
    ledger_context = try
        _up2_vnext_n04_05_context(package, binding;
            event_projection=projection,
            include_child_design=native_plan !== nothing || identity_package !== nothing,
            identity_package=identity_package)
    catch
        return _up2_vnext_build_result(:fail_closed, :none,
            :vnext_n04_05_ledger_context_invalid, nothing,
            projection.projection_hash)
    end
    geometry_context = try
        _up2_vnext_g2_geometry_context(package, binding, g1_context;
            include_semantic_body=current_identity)
    catch
        return _up2_vnext_build_result(:fail_closed, :none,
            :vnext_g2_geometry_context_invalid, nothing,
            projection.projection_hash)
    end
    n05_context = try
        _up2_vnext_n05_flux_context(package, binding, g1_context,
            geometry_context)
    catch
        return _up2_vnext_build_result(:fail_closed, :none,
            :vnext_n05_flux_pair_context_invalid, nothing,
            projection.projection_hash)
    end
    n09_context = if native_plan === nothing
        nothing
    else
        try
            _up2_vnext_n09_context(package, binding, geometry_context,
                native_plan; g3_source_context=ledger_context,
                    g1_context=g1_context, native_report=native_report,
                    heat_lift_receipt=heat_lift_receipt,
                available_route_ids=available_route_ids)
        catch
            return _up2_vnext_build_result(:fail_closed, :none,
                :vnext_n09_native_service_context_invalid, nothing,
                projection.projection_hash)
        end
    end
    n10_context = if current_identity
        try
            source_context = _up2_vnext_n10_identity_context(package, binding;
                g1_context=g1_context, g2_context=geometry_context)
            identity_package === nothing ? source_context :
                _up2_vnext_n10_current_package_context(package, binding,
                    identity_package, source_context, g1_context,
                    geometry_context, ledger_context)
        catch err
            @error "UP2 N10 source context failed" exception=(err, catch_backtrace())
            return _up2_vnext_build_result(:fail_closed, :none,
                :vnext_n10_typed_identity_context_invalid, nothing,
                projection.projection_hash)
        end
    else
        nothing
    end
    fields = Tuple(begin
        value = if spec.id == "N03-04"
            UP2SymbolValueV1(projection.trigger)
        elseif spec.id == "N03-05"
            UP2RationalValueV1(projection.time)
        elseif current_identity && spec.id in
                ("N10-01", "N10-02", "N10-03", "N10-04", "N10-05") &&
                (spec.id in ("N10-01", "N10-02", "N10-03") || identity_package !== nothing)
            _up2_vnext_n10_value(spec, n10_context)
        elseif spec.id in ("N01-01", "N01-02")
            UP2IntegerValueV1(g1_context.values[spec.id])
        elseif spec.id == "N01-04"
            UP2IntegerValueV1(geometry_context.profile_dimension)
        elseif spec.id in ("N02-01", "N02-02")
            UP2UnitValueV1(g1_context.values[spec.id])
        elseif n05_context isa NamedTuple && spec.id == "N05-01"
            UP2TextValueV1(n05_context.pair.left_port)
        elseif n05_context isa NamedTuple && spec.id == "N05-02"
            UP2TextValueV1(n05_context.pair.right_port)
        elseif n05_context isa NamedTuple && spec.id == "N05-03"
            UP2IntegerValueV1(n05_context.pair.left_sign)
        elseif n05_context isa NamedTuple && spec.id == "N05-04"
            UP2IntegerValueV1(n05_context.pair.right_sign)
        elseif n05_context isa NamedTuple && spec.id == "N05-05"
            UP2UnitValueV1(n05_context.pair.unit)
        elseif spec.id in ("N03-01", "N03-02")
            spec.id == "N03-01" ?
                UP2SymbolValueV1(g1_context.values[spec.id]) :
                UP2IntegerValueV1(g1_context.values[spec.id])
        elseif spec.id == "N03-03" && haskey(g1_context.values, spec.id)
            UP2TupleValueV1(g1_context.values[spec.id], :timekind_v1)
        elseif spec.id in ("N01-03", "N01-05", "N02-03") &&
                haskey(geometry_context.values, spec.id)
            spec.id == "N01-03" ?
                UP2IntegerValueV1(geometry_context.values[spec.id]) :
                spec.id == "N01-05" ?
                    UP2SymbolValueV1(geometry_context.values[spec.id]) :
                    UP2TextValueV1(geometry_context.values[spec.id])
        elseif spec.id == "N02-04" && ledger_context.n02_04_05_present
            UP2UnitValueV1(ledger_context.source_bus_unit)
        elseif spec.id == "N02-05" && ledger_context.n02_04_05_present
            UP2UnitValueV1(ledger_context.source_entry_unit)
        elseif spec.id == "N04-01" && ledger_context.typed_ledger_context !== nothing
            UP2TextValueV1(ledger_context.typed_ledger_context.owner)
        elseif spec.id == "N04-02"
            UP2TupleValueV1(ledger_context.closure_account_ids, :string)
        elseif spec.id == "N04-03" && ledger_context.typed_ledger_context !== nothing
            UP2TextValueV1(ledger_context.typed_ledger_context.entry_account_id)
        elseif spec.id == "N04-04"
            UP2TextValueV1(ledger_context.source_entry_component_id)
        elseif spec.id == "N04-05"
            UP2RationalValueV1(ledger_context.coefficient)
        elseif spec.id in ("N06-01", "N06-05")
            typed = ledger_context.typed_ledger_context
            if typed === nothing || !hasproperty(typed, :resource_network)
                UP2AbsentValueV1(spec.source_type,
                    :field_projector_not_implemented)
            else
                source = _up2_vnext_n06_resource_network(ledger_context, binding)
                ports = source.network.resource_ports
                spec.id == "N06-01" ?
                    UP2TupleValueV1(ports, :G3ResourcePortV2) :
                    UP2SymbolValueV1(first(ports).kind)
            end
        elseif spec.id == "N06-02"
            if ledger_context.typed_ledger_context === nothing
                UP2AbsentValueV1(spec.source_type,
                    :candidate_design_typed_ledger_entries_absent)
            else
                verified = _up2_vnext_n06_04_closure(ledger_context, binding)
                UP2TupleValueV1(verified.entries, :g3_ledger_entry_v2)
            end
        elseif spec.id == "N06-03"
            if ledger_context.typed_ledger_context === nothing ||
                    !hasproperty(ledger_context.typed_ledger_context, :resource_network)
                UP2AbsentValueV1(spec.source_type,
                    :field_projector_not_implemented)
            else
                selected = _up2_vnext_n06_03_flow_link(ledger_context, binding)
                UP2TextValueV1(selected.link.resource_port_id)
            end
        elseif spec.id == "N06-04"
            if ledger_context.typed_ledger_context === nothing
                UP2AbsentValueV1(spec.source_type,
                    :candidate_design_typed_ledger_closure_absent)
            else
                closure = _up2_vnext_n06_04_closure(ledger_context, binding).closure
                UP2RationalValueV1(closure.expected_balance)
            end
        elseif spec.id in ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05") &&
                n09_context isa NamedTuple &&
                haskey(n09_context.matches, spec.id)
            UP2SymbolValueV1(n09_context.matches[spec.id])
        elseif spec.class_id in (:N07, :N08) && haskey(geometry_context.values, spec.id)
            _up2_vnext_g2_up2_value(spec, geometry_context.values[spec.id])
        elseif spec.class_id in (:N07, :N08)
            UP2AbsentValueV1(spec.source_type,
                geometry_context.absent_reasons[spec.id])
        else
            absent_reason = spec.id in ("N05-01", "N05-02") ||
                spec.class_id === :N09 ? :source_evidence_absent :
                :field_projector_not_implemented
            UP2AbsentValueV1(spec.source_type, absent_reason)
        end
        UP2SemanticFieldV1(spec.id, spec.field_path, spec.source_locator,
            spec.source_type, value)
    end for spec in _UP2_MUTATION_SPECS)
    field_states = Tuple(_up2_vnext_field_state(spec, projection;
        g1_context=g1_context, n05_context=n05_context,
        n04_01_03_present=ledger_context.typed_ledger_context !== nothing,
        n04_02_present=spec.id == "N04-02",
        n04_04_present=spec.id == "N04-04",
        n04_05_present=spec.id == "N04-05",
        n06_04_present=spec.id in ("N06-02", "N06-04") &&
            ledger_context.typed_ledger_context !== nothing,
        n06_03_present=spec.id == "N06-03" &&
            ledger_context.typed_ledger_context !== nothing &&
            hasproperty(ledger_context.typed_ledger_context, :resource_network),
        n06_network_present=spec.id in ("N06-01", "N06-05") &&
            ledger_context.typed_ledger_context !== nothing &&
            hasproperty(ledger_context.typed_ledger_context, :resource_network),
        n02_04_05_present=ledger_context.n02_04_05_present,
        n07n08_context=geometry_context, n09_context=n09_context,
        n10_context=n10_context)
        for spec in _UP2_MUTATION_SPECS)
    pair = n05_context isa NamedTuple ? n05_context.pair :
        UP2FluxPairV1("pair-vnext-pending", "pending-port:left",
            "pending-port:right", -1, 1, UnitSignature())
    state = UP2PrecompilerStateV1(fields, pair)
    input = UP2VNextPrecompilerInputV1(binding, mission_bounds, state,
        field_states; provider_bindings=n09_context === nothing ? () :
            n09_context.provider_bindings)
    input_valid = try
        _up2_validate_vnext_input_with_context(input, package, native_plan,
            nothing, n10_context; native_report=native_report,
            heat_lift_receipt=heat_lift_receipt, identity_package=identity_package,
            available_route_ids=available_route_ids)
        true
    catch
        false
    end
    input_valid ||
        return _up2_vnext_build_result(:fail_closed, :none,
            :vnext_up2_input_validation_failed, nothing, projection.projection_hash)
    if available_route_ids !== nothing && n09_context isa NamedTuple &&
            any(status -> status !== :unique_match,
                values(n09_context.matches))
        return _up2_vnext_build_result(:typed_absent, :terminal_deferred,
            :n09_provider_availability_gap, input, projection.projection_hash)
    end
    _up2_vnext_build_result(input.status, input.resolution,
        :vnext_t1_50_row_input_prepared_deferred, input,
        projection.projection_hash)
end

function _up2_find_field(state, id::String)
    found = Tuple(x for x in state.fields if x.id == id)
    length(found) == 1 ? first(found) : nothing
end

function up2_validate_input(input::UP2PrecompilerInputV1)
    input.candidate_ref.version == "v5" || throw(ArgumentError("candidate ref version is not v5"))
    startswith(input.g2_ref.uri, "fusionconceptai://GenomeV5/G2/") || throw(ArgumentError("G2 URI namespace mismatch"))
    input.package_status === :a_limited || throw(ArgumentError("input is not A-limited"))
    input.claim_ceiling == none || throw(ArgumentError("UP2 input exceeds contract-only ceiling"))
    input.resolution == terminal_deferred || throw(ArgumentError("provider/authority gaps must remain deferred"))
    length(input.state.fields) == 50 || throw(ArgumentError("UP2 input must contain all 50 fields"))
    for spec in _UP2_MUTATION_SPECS
        field = _up2_find_field(input.state, spec.id)
        field === nothing && throw(ArgumentError("UP2 input misses registered field $(spec.id)"))
        (field.field_path == spec.field_path && field.source_locator == spec.source_locator &&
            field.source_type == spec.source_type) ||
            throw(ArgumentError("UP2 source metadata mismatch for $(spec.id)"))
        _up2_typed_value_matches(field.value, spec.source_type) ||
            throw(ArgumentError("UP2 typed value mismatch for $(spec.id)"))
    end
    up2_flux_pair_valid(input.state.flux_pair) ||
        throw(ArgumentError("UP2 baseline flux pair is not a valid opposite-sign pair"))
    _up2_baseline_invariants(input) || throw(ArgumentError("UP2 baseline source invariants are invalid"))
    true
end

function _up2_vnext_binding_body(binding::UP2VNextSourceBindingV1)
    (candidate_ref=binding.candidate_ref, candidate_id=binding.candidate_id,
        scenario_id=binding.scenario_id, snapshot_id=binding.snapshot_id,
        manifest_sha256=binding.manifest_sha256,
        package_hash=binding.package_hash,
        semantic_identity=binding.semantic_identity,
        bundle_hash=binding.bundle_hash,
        n03_projection_hash=binding.n03_projection_hash,
        source_pins=binding.source_pins, event_id=binding.event_id,
        trigger=binding.trigger, time=binding.time,
        time_basis=binding.time_basis,
        projection_status=binding.projection_status,
        projection_resolution=binding.projection_resolution,
        authority_scope=binding.authority_scope,
        authority_gap=binding.authority_gap)
end

"""Validate the VNext 50-row contract without treating absent fields as values."""
Base.@noinline Base.@nospecializeinfer function _up2_validate_vnext_n09_context_proof(
        input, n09_fields, binding::UP2VNextSourceBindingV1, contexts)
    Base.@nospecialize input n09_fields contexts
    context = contexts.n09_context
    input.provider_bindings == context.provider_bindings ||
        throw(ArgumentError("VNext UP2 N09 provider bindings differ from current service requests"))
    all(i -> n09_fields[i].value isa UP2SymbolValueV1 &&
        n09_fields[i].value.value === context.matches[("N09-01", "N09-02", "N09-03")[i]], 1:3) ||
        throw(ArgumentError("VNext UP2 N09 status differs from exact service match"))
    n09_04 = _up2_find_field(input.state, "N09-04")
    haskey(context.matches, "N09-04") ==
        (n09_04.value isa UP2SymbolValueV1) ||
        throw(ArgumentError("VNext UP2 N09-04 presence differs from scalar heat-lift service"))
    haskey(context.matches, "N09-04") && n09_04.value isa UP2SymbolValueV1 &&
        n09_04.value.value === context.matches["N09-04"] ||
        !haskey(context.matches, "N09-04") ||
        throw(ArgumentError("VNext UP2 N09-04 status differs from exact scalar heat-lift match"))
    field05 = _up2_find_field(input.state, "N09-05")
    haskey(context.matches, "N09-05") == (field05.value isa UP2SymbolValueV1) ||
        throw(ArgumentError("VNext UP2 N09-05 presence differs from rebuilt G3 source"))
    haskey(context.matches, "N09-05") && field05.value.value === context.matches["N09-05"] ||
        !haskey(context.matches, "N09-05") ||
        throw(ArgumentError("VNext UP2 N09-05 status differs from rebuilt G3 matcher"))
    return contexts
end

Base.@noinline Base.@nospecializeinfer function _up2_validate_vnext_n09_present(
        input, n09_fields, package, binding::UP2VNextSourceBindingV1, native_plan,
        contexts=nothing, native_report=nothing, heat_lift_receipt=nothing;
        identity_package=nothing, available_route_ids=nothing)
    Base.@nospecialize input n09_fields package native_plan contexts
    package isa CandidateStatePackageV5NextV2 && native_plan !== nothing ||
        throw(ArgumentError("VNext UP2 N09 G2 provider rows require their bound T1 package and native plan"))
    if contexts === nothing || !hasproperty(contexts, :n09_context)
        child_context = contexts !== nothing && hasproperty(contexts, :ledger_context) ?
            contexts.ledger_context : _up2_vnext_n04_05_context(package, binding;
                include_child_design=true, identity_package=identity_package)
        geometry_context = contexts !== nothing && hasproperty(contexts, :geometry_context) ?
            contexts.geometry_context : _up2_vnext_g2_geometry_context(package, binding)
        g1_context = contexts !== nothing && hasproperty(contexts, :g1_context) ?
            contexts.g1_context : nothing
        native_report = contexts !== nothing && hasproperty(contexts, :native_report) ?
            contexts.native_report : native_report
        heat_lift_receipt = contexts !== nothing && hasproperty(contexts, :heat_lift_receipt) ?
            contexts.heat_lift_receipt : heat_lift_receipt
        built = _up2_vnext_n09_context_with_g1(package, binding,
            geometry_context, native_plan; g3_source_context=child_context,
            g1_context=g1_context, native_report=native_report,
            heat_lift_receipt=heat_lift_receipt,
            available_route_ids=available_route_ids)
        base = (n09_context=built.n09_context,
            ledger_context=child_context, geometry_context=geometry_context,
            g1_context=built.g1_context, native_report=native_report,
            heat_lift_receipt=heat_lift_receipt)
        contexts = contexts !== nothing && hasproperty(contexts, :n05_context) ?
            merge(base, (n05_context=contexts.n05_context,)) : base
    end
    _up2_validate_vnext_n09_context_proof(input, n09_fields, binding, contexts)
end

Base.@noinline Base.@nospecializeinfer function _up2_validate_vnext_input_with_context(input::UP2VNextPrecompilerInputV1,
        package, native_plan, supplied_n09_contexts=nothing, supplied_n10_context=nothing;
        native_report=nothing, heat_lift_receipt=nothing, identity_package=nothing,
        available_route_ids=nothing)
    Base.@nospecialize input package native_plan supplied_n09_contexts supplied_n10_context identity_package
    available_route_ids = _up2_vnext_n09_availability_routes_v1(available_route_ids)
    available_route_ids === nothing || native_plan !== nothing ||
        throw(ArgumentError("N09 availability selection requires the current native plan"))
    n09_validation_contexts = nothing
    n05_validation_contexts = nothing
    n10_validation_contexts = nothing
    n10_context_reusable = false
    n10_context_rebuilt_here = false
    input.status === :prepared_not_executed &&
        input.resolution === :terminal_deferred &&
        input.claim_ceiling === :contract_only ||
        throw(ArgumentError("VNext UP2 status or claim ceiling exceeds its contract"))
    binding = input.source_binding
    binding.time_basis === :event &&
        binding.authority_scope === :local_source_data &&
        binding.authority_gap == "candidate_authored_event_time_policy_is_design_only" ||
        throw(ArgumentError("VNext UP2 binding lacks the candidate event-time design ceiling"))
    canonical_hash(_up2_vnext_binding_body(binding)) == binding.binding_hash ||
        throw(ArgumentError("VNext UP2 source binding hash mismatch"))
    Tuple(pin.role for pin in binding.source_pins) == _UP2_VNEXT_SOURCE_ROLES ||
        throw(ArgumentError("VNext UP2 six source pins are incomplete"))
    length(input.state.fields) == length(_UP2_MUTATION_SPECS) ==
        length(input.field_states) == 50 ||
        throw(ArgumentError("VNext UP2 input does not contain the fixed 50 rows"))
    for (spec, field, field_state) in zip(_UP2_MUTATION_SPECS,
            input.state.fields, input.field_states)
        field.id == spec.id && field_state.field_id == spec.id &&
            field.field_path == spec.field_path &&
            field.source_locator == spec.source_locator &&
            field.source_type == spec.source_type ||
            throw(ArgumentError("VNext UP2 row metadata mismatch for $(spec.id)"))
        all(role -> role in _UP2_VNEXT_SOURCE_ROLES, field_state.source_pin_roles) ||
            throw(ArgumentError("VNext UP2 row has an unknown source pin role"))
        field_state.state === :source_present_deferred &&
            isempty(field_state.source_pin_roles) && spec.class_id !== :N10 &&
            throw(ArgumentError("VNext UP2 source-present row lacks its source pin roles"))
        if field.value isa UP2AbsentValueV1
            field.value.intended_type === spec.source_type ||
                throw(ArgumentError("VNext UP2 absent row type mismatch for $(spec.id)"))
            field_state.state in (:source_present_deferred, :typed_absent) ||
                throw(ArgumentError("VNext UP2 absent row state is invalid"))
            field_state.state === :typed_absent &&
                !isempty(field_state.source_pin_roles) &&
                throw(ArgumentError("VNext UP2 typed-absent row cannot claim source pins"))
        else
            _up2_typed_value_matches(field.value, spec.source_type) ||
                throw(ArgumentError("VNext UP2 typed row mismatch for $(spec.id)"))
            field_state.state === :source_present_deferred ||
                throw(ArgumentError("VNext UP2 typed row is not marked source-present/deferred"))
        end
        all(role -> any(pin -> pin.role === role, binding.source_pins),
            field_state.source_pin_roles) ||
            throw(ArgumentError("VNext UP2 row source pin is not bound for $(spec.id)"))
    end
    n10_ids = ("N10-01", "N10-02", "N10-03")
    n10_fields = Tuple(_up2_find_field(input.state, id) for id in n10_ids)
    n10_states = Tuple(first(x for x in input.field_states if x.field_id == id)
        for id in n10_ids)
    if package isa CandidateStatePackageV5NextV2
        generic_absence = all(i -> begin
            field, row = n10_fields[i], n10_states[i]
            field.value isa UP2AbsentValueV1 &&
                field.value.reason === :field_projector_not_implemented &&
                row.state === :source_present_deferred &&
                row.reason === :vnext_package_identity_not_projected_to_legacy_field &&
                isempty(row.source_pin_roles)
        end, eachindex(n10_ids))
        if generic_absence
            identity_package === nothing ||
                throw(ArgumentError("N10 V5 identity package cannot attach to generic-absent current T1 rows"))
            all(id -> begin
                field = _up2_find_field(input.state, id)
                row = first(x for x in input.field_states if x.field_id == id)
                field.value isa UP2AbsentValueV1 &&
                    field.value.reason === :field_projector_not_implemented &&
                    row.state === :source_present_deferred &&
                    row.reason === :vnext_package_identity_not_projected_to_legacy_field &&
                    isempty(row.source_pin_roles)
            end, ("N10-04", "N10-05")) ||
                throw(ArgumentError("VNext UP2 N10-04/05 generic absence state is invalid"))
        else
            n10_context_rebuilt_here = supplied_n10_context === nothing
            n10_context = if n10_context_rebuilt_here
                n10_g1_context = supplied_n09_contexts !== nothing &&
                    hasproperty(supplied_n09_contexts, :g1_context) ?
                    supplied_n09_contexts.g1_context : nothing
                n10_g2_context = supplied_n09_contexts !== nothing &&
                    hasproperty(supplied_n09_contexts, :geometry_context) ?
                    supplied_n09_contexts.geometry_context : nothing
                n10_ledger_context = supplied_n09_contexts !== nothing &&
                    hasproperty(supplied_n09_contexts, :ledger_context) ?
                    supplied_n09_contexts.ledger_context : nothing
                identity_package === nothing ?
                    _up2_vnext_n10_identity_context(package, binding;
                        g1_context=n10_g1_context, g2_context=n10_g2_context) :
                    _up2_vnext_n10_validation_context(package, binding, identity_package;
                        g1_context=n10_g1_context, g2_context=n10_g2_context,
                        ledger_context=n10_ledger_context)
            else
                supplied_n10_context
            end
            n10_context.candidate_ref == binding.candidate_ref &&
                n10_context.package_hash == binding.package_hash &&
                n10_context.semantic_identity == binding.semantic_identity &&
                n10_context.bundle_hash == binding.bundle_hash ||
                throw(ArgumentError("supplied N10 context is detached from this package/binding"))
            expected_values = Tuple(_up2_vnext_n10_value(up2_spec_for_id(id), n10_context)
                for id in n10_ids)
            expected_roles = ((:g1_builder, :g1_declaration_source),
                (:g2_builder, :g2_declaration_source),
                (:g3_builder, :g3_child_design))
            expected_reasons = (:n10_g1_t0_factory_contract_ref_absent,
                :n10_g2_t0_factory_contract_ref_absent,
                :n10_binding_t0_child_contract_ref_absent)
            all(i -> begin
                field, row, expected = n10_fields[i], n10_states[i], expected_values[i]
                semantic_view(field.value) == semantic_view(expected) || return false
                if expected isa UP2AbsentValueV1
                    row.state === :typed_absent && row.reason === expected_reasons[i] &&
                        isempty(row.source_pin_roles)
                else
                    row.state === :source_present_deferred &&
                        row.reason === :current_vnext_t1_t0_typed_ref_not_legacy_v5_identity &&
                        row.source_pin_roles == expected_roles[i]
                end
            end, eachindex(n10_ids)) || throw(ArgumentError(
                "VNext UP2 N10 current T0/T1 typed-ref projection is not source-bound"))
            n10_validation_contexts = (n10_context=n10_context,)
            if hasproperty(n10_context, :g1_context) &&
                    hasproperty(n10_context, :geometry_context)
                n10_context_reusable = true
                n05_validation_contexts = (g1_context=n10_context.g1_context,
                    geometry_context=n10_context.geometry_context)
                if n10_context_rebuilt_here &&
                        hasproperty(n10_context, :ledger_context)
                    n05_validation_contexts = merge(n05_validation_contexts,
                        (ledger_context=n10_context.ledger_context,))
                end
            end
            if identity_package !== nothing
                hasproperty(n10_context, :identity_package) &&
                    n10_context.identity_package === identity_package ||
                    throw(ArgumentError("N10 supplied context is detached from the supplied V5 identity package"))
                for id in ("N10-04", "N10-05")
                    field = _up2_find_field(input.state, id)
                    row = first(x for x in input.field_states if x.field_id == id)
                    expected = _up2_vnext_n10_value(up2_spec_for_id(id), n10_context)
                    reason = id == "N10-04" ?
                        :current_vnext_t0_t1_component_identity_compatibility_view :
                        :current_vnext_t0_t1_fresh_identity_receipt_not_v4_migration
                    expected_roles = (:g1_builder, :g1_declaration_source, :g2_builder,
                        :g2_declaration_source, :g3_builder, :g3_child_design)
                    semantic_view(field.value) == semantic_view(expected) &&
                        row.state === :source_present_deferred && row.reason === reason &&
                        row.source_pin_roles == expected_roles ||
                        throw(ArgumentError("VNext UP2 $(id) is not bound to its current-source V5 package"))
                end
            else
                all(id -> begin
                    field = _up2_find_field(input.state, id)
                    row = first(x for x in input.field_states if x.field_id == id)
                    field.value isa UP2AbsentValueV1 &&
                        field.value.reason === :field_projector_not_implemented &&
                        row.state === :source_present_deferred &&
                        row.reason === :vnext_package_identity_not_projected_to_legacy_field &&
                        isempty(row.source_pin_roles)
                end, ("N10-04", "N10-05")) ||
                    throw(ArgumentError("VNext UP2 N10-04/05 require an explicit current-source identity package"))
            end
        end
    elseif any(field -> !(field.value isa UP2AbsentValueV1), n10_fields)
        throw(ArgumentError("VNext UP2 N10 typed identity rows require their bound T1 package"))
    end
    trigger = _up2_find_field(input.state, "N03-04").value
    time = _up2_find_field(input.state, "N03-05").value
    trigger isa UP2SymbolValueV1 && trigger.value === binding.trigger ||
        throw(ArgumentError("VNext UP2 N03-04 does not match its N03 projection"))
    time isa UP2RationalValueV1 && time.value == binding.time ||
        throw(ArgumentError("VNext UP2 N03-05 does not match its N03 projection"))
    all(id -> begin
        row = first(x for x in input.field_states if x.field_id == id)
        row.state === :source_present_deferred &&
            row.source_pin_roles == (:g3_builder, :g3_child_design)
    end, ("N03-04", "N03-05")) ||
        throw(ArgumentError("VNext UP2 N03 event rows lost their G3 source binding"))
    g1_projection_ids = ("N01-01", "N01-02", "N02-01", "N02-02")
    all(id -> begin
        field = _up2_find_field(input.state, id)
        row = first(x for x in input.field_states if x.field_id == id)
        expected_type = id in ("N01-01", "N01-02") ?
            UP2IntegerValueV1 : UP2UnitValueV1
        field.value isa expected_type && row.state === :source_present_deferred &&
            row.reason === :candidate_design_g1_operator_type_contract_only &&
            row.source_pin_roles == (:g1_builder, :g1_declaration_source)
    end, g1_projection_ids) ||
        throw(ArgumentError("VNext UP2 G1 operator type rows lost their source binding"))
    n01_04_field = _up2_find_field(input.state, "N01-04")
    n01_04_state = first(x for x in input.field_states if x.field_id == "N01-04")
    n01_04_field.value isa UP2IntegerValueV1 &&
        n01_04_field.value.value == 3 &&
        n01_04_state.state === :source_present_deferred &&
        n01_04_state.reason === :candidate_design_g2_profile_contract_only &&
        n01_04_state.source_pin_roles == (:g2_builder, :g2_declaration_source) ||
        throw(ArgumentError("VNext UP2 N01-04 G2 profile dimension binding is invalid"))
    cross_ids = ("N01-03", "N01-05", "N02-03")
    cross_fields = Tuple(_up2_find_field(input.state, id) for id in cross_ids)
    cross_present = Tuple(!(field.value isa UP2AbsentValueV1) for field in cross_fields)
    if any(cross_present)
        all(cross_present) ||
            throw(ArgumentError("VNext UP2 G1/G2 state-field join is only partially projected"))
        cross_expected = (UP2IntegerValueV1, UP2SymbolValueV1, UP2TextValueV1)
        all(i -> begin
            field = cross_fields[i]
            row = first(x for x in input.field_states if x.field_id == cross_ids[i])
            field.value isa cross_expected[i] && row.state === :source_present_deferred &&
                row.reason === :candidate_design_g1_g2_state_field_binding_contract_only &&
                row.source_pin_roles == (:g1_builder, :g1_declaration_source,
                    :g2_builder, :g2_declaration_source)
        end, eachindex(cross_ids)) ||
            throw(ArgumentError("VNext UP2 G1/G2 state-field rows lost their source binding"))
        cross_fields[1].value.value == 0 &&
            cross_fields[2].value.value === :scalar &&
            cross_fields[3].value.value == "1" ||
            throw(ArgumentError("VNext UP2 G1/G2 state-field values differ from declared join"))
    end
    n04_owner_field, n04_entry_field =
        _up2_find_field(input.state, "N04-01"),
        _up2_find_field(input.state, "N04-03")
    n04_owner_state, n04_entry_state =
        first(x for x in input.field_states if x.field_id == "N04-01"),
        first(x for x in input.field_states if x.field_id == "N04-03")
    n04_owner_absent = n04_owner_field.value isa UP2AbsentValueV1 &&
        n04_entry_field.value isa UP2AbsentValueV1 &&
        n04_owner_state.state === :source_present_deferred &&
        n04_entry_state.state === :source_present_deferred &&
        n04_owner_state.reason === :pinned_layer_source_field_projector_absent &&
        n04_entry_state.reason === :pinned_layer_source_field_projector_absent &&
        n04_owner_state.source_pin_roles == (:g3_builder, :g3_child_design) &&
        n04_entry_state.source_pin_roles == (:g3_builder, :g3_child_design)
    n04_owner_present = n04_owner_field.value isa UP2TextValueV1 &&
        n04_entry_field.value isa UP2TextValueV1 &&
        !isempty(n04_owner_field.value.value) && !isempty(n04_entry_field.value.value) &&
        n04_owner_state.state === :source_present_deferred &&
        n04_entry_state.state === :source_present_deferred &&
        n04_owner_state.reason === :candidate_design_ledger_owner_design_only &&
        n04_entry_state.reason === :candidate_design_ledger_entry_account_design_only &&
        n04_owner_state.source_pin_roles == (:g3_builder, :g3_child_design) &&
        n04_entry_state.source_pin_roles == (:g3_builder, :g3_child_design)
    (n04_owner_absent || n04_owner_present) ||
        throw(ArgumentError("VNext UP2 N04-01/03 typed-ledger projection state is invalid"))
    all(begin
        field = _up2_find_field(input.state, id)
        row = first(x for x in input.field_states if x.field_id == id)
        expected_type = id == "N04-02" ? UP2TupleValueV1 : UP2TextValueV1
        field.value isa expected_type && row.state === :source_present_deferred &&
            row.reason === reason &&
            row.source_pin_roles == (:g3_builder, :g3_child_design)
    end for (id, reason) in (("N04-02", :candidate_design_ledger_closure_design_only),
                             ("N04-04", :candidate_design_ledger_component_design_only))) ||
        throw(ArgumentError("VNext UP2 N04-02/04 candidate design row binding is invalid"))
    n06_balance_field = _up2_find_field(input.state, "N06-04")
    n06_balance_state = first(x for x in input.field_states
        if x.field_id == "N06-04")
    n06_entries_field = _up2_find_field(input.state, "N06-02")
    n06_entries_state = first(x for x in input.field_states if x.field_id == "N06-02")
    n06_entries_absent = n06_entries_field.value isa UP2AbsentValueV1 &&
        n06_entries_field.value.reason === :candidate_design_typed_ledger_entries_absent &&
        n06_entries_state.state === :typed_absent &&
        n06_entries_state.reason === :candidate_design_typed_ledger_entries_absent &&
        isempty(n06_entries_state.source_pin_roles)
    n06_entries_present = n06_entries_field.value isa UP2TupleValueV1 &&
        n06_entries_field.value.element_type === :g3_ledger_entry_v2 &&
        n06_entries_state.state === :source_present_deferred &&
        n06_entries_state.reason === :candidate_design_g3_ledger_entries_design_only &&
        n06_entries_state.source_pin_roles == (:g3_builder, :g3_child_design)
    (n06_entries_absent || n06_entries_present) ||
        throw(ArgumentError("VNext UP2 N06-02 typed-ledger entries projection state is invalid"))
    n06_balance_absent = n06_balance_field.value isa UP2AbsentValueV1 &&
        n06_balance_field.value.reason === :candidate_design_typed_ledger_closure_absent &&
        n06_balance_state.state === :typed_absent &&
        n06_balance_state.reason === :candidate_design_typed_ledger_closure_absent &&
        isempty(n06_balance_state.source_pin_roles)
    n06_balance_present = n06_balance_field.value isa UP2RationalValueV1 &&
        n06_balance_state.state === :source_present_deferred &&
        n06_balance_state.reason === :candidate_design_g3_closure_balance_design_only &&
        n06_balance_state.source_pin_roles == (:g3_builder, :g3_child_design)
    (n06_balance_absent || n06_balance_present) ||
        throw(ArgumentError("VNext UP2 N06-04 typed-ledger closure projection state is invalid"))
    n06_link_field = _up2_find_field(input.state, "N06-03")
    n06_link_state = first(x for x in input.field_states if x.field_id == "N06-03")
    n06_link_absent = n06_link_field.value isa UP2AbsentValueV1 &&
        n06_link_field.value.reason === :field_projector_not_implemented &&
        n06_link_state.state === :source_present_deferred &&
        n06_link_state.reason === :pinned_layer_source_field_projector_absent &&
        n06_link_state.source_pin_roles ==
            _up2_vnext_layer_roles(up2_spec_for_id("N06-03").field_path)
    n06_link_present = n06_link_field.value isa UP2TextValueV1 &&
        n06_link_field.value.value == "source_supply_current" &&
        n06_link_state.state === :source_present_deferred &&
        n06_link_state.reason === :candidate_design_g3_control_flow_link_design_only &&
        n06_link_state.source_pin_roles == (:g3_builder, :g3_child_design)
    (n06_link_absent || n06_link_present) ||
        throw(ArgumentError("VNext UP2 N06-03 control-flow projection state is invalid"))
    n06_network_fields = Tuple(_up2_find_field(input.state, id)
        for id in ("N06-01", "N06-05"))
    n06_network_states = Tuple(first(x for x in input.field_states
        if x.field_id == id) for id in ("N06-01", "N06-05"))
    n06_network_ids = ("N06-01", "N06-05")
    n06_network_absent = all(i ->
        n06_network_fields[i].value isa UP2AbsentValueV1 &&
        n06_network_fields[i].value.reason === :field_projector_not_implemented &&
        n06_network_states[i].state === :source_present_deferred &&
        n06_network_states[i].reason === :pinned_layer_source_field_projector_absent &&
        n06_network_states[i].source_pin_roles ==
            _up2_vnext_layer_roles(up2_spec_for_id(n06_network_ids[i]).field_path), 1:2)
    n06_network_present =
        n06_network_fields[1].value isa UP2TupleValueV1 &&
        n06_network_fields[1].value.element_type === :G3ResourcePortV2 &&
        n06_network_fields[2].value isa UP2SymbolValueV1 &&
        all(i -> n06_network_states[i].state === :source_present_deferred &&
            n06_network_states[i].reason ===
                :candidate_design_g3_typed_resource_network_contract_only &&
            n06_network_states[i].source_pin_roles ==
                (:g3_builder, :g3_child_design), 1:2)
    (n06_network_absent || n06_network_present) ||
        throw(ArgumentError("VNext UP2 N06-01/05 resource-network projection state is invalid"))
    n05_ids = ("N05-01", "N05-02", "N05-03", "N05-04", "N05-05")
    n05_fields = Tuple(_up2_find_field(input.state, id) for id in n05_ids)
    n05_states = Tuple(first(x for x in input.field_states if x.field_id == id)
        for id in n05_ids)
    n05_absent = all(i -> n05_fields[i].value isa UP2AbsentValueV1 &&
        n05_states[i].state === (i <= 2 ? :typed_absent : :source_present_deferred) &&
        n05_states[i].reason === (i <= 2 ?
            :up2_flux_pair_not_projected_from_vnext_t1 :
            i <= 4 ? :g2_interface_normal_is_not_flux_sign_evidence :
            :g1_input_unit_is_not_flux_unit_evidence) &&
        n05_states[i].source_pin_roles === (i <= 2 ? () :
            i <= 4 ? (:g2_builder, :g2_declaration_source) :
            (:g1_builder, :g1_declaration_source)), 1:5)
    n05_present = all(i -> !(n05_fields[i].value isa UP2AbsentValueV1) &&
        n05_states[i].state === :source_present_deferred, 1:5)
    (n05_absent || n05_present) ||
        throw(ArgumentError("VNext UP2 N05 flux pair is partially projected or has invalid absence state"))
    if n05_present
        package isa CandidateStatePackageV5NextV2 ||
            throw(ArgumentError("VNext UP2 N05 present rows require their bound T1 package"))
        n05_g1_context = supplied_n09_contexts !== nothing &&
            hasproperty(supplied_n09_contexts, :g1_context) ?
            supplied_n09_contexts.g1_context :
            n10_context_reusable ? n10_context.g1_context :
            _up2_vnext_g1_operator_type_context(package, binding)
        n05_geometry_context = supplied_n09_contexts !== nothing &&
            hasproperty(supplied_n09_contexts, :geometry_context) ?
            supplied_n09_contexts.geometry_context :
            n10_context_reusable ? n10_context.geometry_context :
            _up2_vnext_g2_geometry_context(package, binding, n05_g1_context)
        pair_context = supplied_n09_contexts !== nothing &&
            hasproperty(supplied_n09_contexts, :n05_context) ?
            supplied_n09_contexts.n05_context :
            _up2_vnext_n05_flux_context(package, binding, n05_g1_context,
                n05_geometry_context)
        pair_context isa NamedTuple ||
            throw(ArgumentError("VNext UP2 N05 present rows lack a typed G1 flux pair"))
        expected_values = (UP2TextValueV1(pair_context.pair.left_port),
            UP2TextValueV1(pair_context.pair.right_port),
            UP2IntegerValueV1(pair_context.pair.left_sign),
            UP2IntegerValueV1(pair_context.pair.right_sign),
            UP2UnitValueV1(pair_context.pair.unit))
        expected_reasons = (:candidate_design_g1_g2_interface_flux_contract_only,
            :candidate_design_g1_g2_interface_flux_contract_only,
            :candidate_design_g1_g2_interface_flux_contract_only,
            :candidate_design_g1_g2_interface_flux_contract_only,
            :candidate_design_g1_k_apply_output_unit_contract_only)
        expected_roles = ((:g1_builder, :g1_declaration_source,
            :g2_builder, :g2_declaration_source),
            (:g1_builder, :g1_declaration_source,
             :g2_builder, :g2_declaration_source),
            (:g1_builder, :g1_declaration_source,
             :g2_builder, :g2_declaration_source),
            (:g1_builder, :g1_declaration_source,
             :g2_builder, :g2_declaration_source),
            (:g1_builder, :g1_declaration_source))
        all(i -> semantic_view(n05_fields[i].value) ==
                semantic_view(expected_values[i]) &&
            n05_states[i].reason === expected_reasons[i] &&
            n05_states[i].source_pin_roles == expected_roles[i], 1:5) ||
            throw(ArgumentError("VNext UP2 N05 rows differ from independently rebuilt G1/G2 flux context"))
        canonical_hash(input.state.flux_pair) == canonical_hash(pair_context.pair) ||
            throw(ArgumentError("VNext UP2 N05 pair differs from independently rebuilt G1/G2 flux context"))
        fresh_n10_ledger_context = n10_context_rebuilt_here &&
            n05_validation_contexts !== nothing &&
            hasproperty(n05_validation_contexts, :ledger_context) ?
            n05_validation_contexts.ledger_context : nothing
        n05_validation_contexts = (n05_context=pair_context,
            g1_context=n05_g1_context, geometry_context=n05_geometry_context)
        if fresh_n10_ledger_context !== nothing
            n05_validation_contexts = merge(n05_validation_contexts,
                (ledger_context=fresh_n10_ledger_context,))
        end
        n09_validation_contexts = n05_validation_contexts
    end
    n09_04 = _up2_find_field(input.state, "N09-04")
    state04 = first(x for x in input.field_states if x.field_id == "N09-04")
    n09_04_absent = n09_04.value isa UP2AbsentValueV1 &&
        n09_04.value.reason === :source_evidence_absent &&
        state04.state === :typed_absent &&
        state04.reason === :provider_match_evidence_absent &&
        isempty(state04.source_pin_roles)
    status04 = n09_04.value isa UP2SymbolValueV1 ? n09_04.value.value : nothing
    n09_04_present = status04 in (:unique_match, :no_match) &&
        state04.state === :source_present_deferred &&
        state04.reason === (status04 === :unique_match ?
            :candidate_design_g1_g2_scalar_heat_lift_provider_match : :provider_availability_gap) &&
        state04.source_pin_roles == (:g1_builder, :g1_declaration_source,
            :g2_builder, :g2_declaration_source, :g3_builder, :g3_child_design)
    (n09_04_absent || n09_04_present) ||
        throw(ArgumentError("VNext UP2 N09-04 scalar heat-lift row has an invalid source state"))
    n09_fields = Tuple(_up2_find_field(input.state, id)
        for id in ("N09-01", "N09-02", "N09-03"))
    n09_states = Tuple(first(x for x in input.field_states
        if x.field_id == id) for id in ("N09-01", "N09-02", "N09-03"))
    n09_absent = all(i -> n09_fields[i].value isa UP2AbsentValueV1 &&
        n09_fields[i].value.reason === :source_evidence_absent &&
        n09_states[i].state === :typed_absent &&
        n09_states[i].reason === :provider_match_evidence_absent &&
        isempty(n09_states[i].source_pin_roles), 1:3)
    n09_present = all(i -> begin
        status = n09_fields[i].value isa UP2SymbolValueV1 ? n09_fields[i].value.value : nothing
        reason = status === :no_match ? :provider_availability_gap : i == 1 ?
            :candidate_design_g1_grad_native_gridap_service_match :
            i == 2 ? :candidate_design_g2_profile_native_gridap_service_match :
            :candidate_design_g2_exterior_native_gridap_service_match
        status in (:unique_match, :no_match) && n09_states[i].state === :source_present_deferred &&
            n09_states[i].reason === reason && n09_states[i].source_pin_roles == (i == 1 ?
                (:g1_builder, :g1_declaration_source) : (:g2_builder, :g2_declaration_source))
    end, 1:3)
    n09_present = n09_present && (n09_04_absent || n09_04_present)
    (n09_absent || n09_present) ||
        throw(ArgumentError("VNext UP2 N09 G2 provider rows have an invalid partial or mismatched state"))
    field05 = _up2_find_field(input.state, "N09-05")
    state05 = first(x for x in input.field_states if x.field_id == "N09-05")
    n09_05_absent = field05.value isa UP2AbsentValueV1 &&
        field05.value.reason === :source_evidence_absent &&
        state05.state === :typed_absent && state05.reason === :provider_match_evidence_absent &&
        isempty(state05.source_pin_roles)
    status05 = field05.value isa UP2SymbolValueV1 ? field05.value.value : nothing
    n09_05_present = status05 in (:unique_match, :no_match) &&
        state05.state === :source_present_deferred &&
        state05.reason === (status05 === :unique_match ?
            :candidate_design_g3_control_sampled_service_match : :provider_availability_gap) &&
        state05.source_pin_roles == (:g3_builder, :g3_child_design)
    (n09_05_absent || n09_05_present) ||
        throw(ArgumentError("VNext UP2 N09-05 G3 control row has an invalid source state"))
    if n09_present || n09_05_present || n09_04_present
        contexts_for_n09 = supplied_n09_contexts === nothing ?
            n05_validation_contexts : supplied_n09_contexts
        if contexts_for_n09 !== nothing && n05_validation_contexts !== nothing &&
                !hasproperty(contexts_for_n09, :n05_context)
            contexts_for_n09 = merge(contexts_for_n09,
                (n05_context=n05_validation_contexts.n05_context,))
        end
        n09_validation_contexts = _up2_validate_vnext_n09_present(input,
            n09_fields, package, binding, native_plan, contexts_for_n09,
            native_report, heat_lift_receipt; identity_package=identity_package,
            available_route_ids=available_route_ids)
    else
        isempty(input.provider_bindings) ||
            throw(ArgumentError("VNext UP2 N09 bindings are present while provider rows are absent"))
    end
    g2_present_ids = ["N07-01", "N07-02", "N07-03", "N07-05",
        "N08-02", "N08-03"]
    g2_absent_reasons = Dict(
        "N07-04" => :g2mb_source_has_no_boundary_patch,
        "N08-01" => :g2mb_chart_has_no_coordinate_axis_labels,
        "N08-04" => :g2mb_q1_basis_equivalence_not_frozen,
        "N08-05" => :g2mb_source_has_no_internal_interfaces)
    for id in ("N07-04", "N08-01", "N08-05")
        if !(_up2_find_field(input.state, id).value isa UP2AbsentValueV1)
            push!(g2_present_ids, id)
            delete!(g2_absent_reasons, id)
        end
    end
    all(begin
        f = _up2_find_field(input.state, id)
        s = first(x for x in input.field_states if x.field_id == id)
        !(f.value isa UP2AbsentValueV1) &&
            s.state === :source_present_deferred &&
            s.reason === :candidate_design_g2_geometry_contract_only &&
            s.source_pin_roles == (:g2_builder, :g2_declaration_source)
    end for id in g2_present_ids) ||
        throw(ArgumentError("VNext UP2 mapped G2 rows lost their source binding"))
    all(begin
        f = _up2_find_field(input.state, id)
        s = first(x for x in input.field_states if x.field_id == id)
        f.value isa UP2AbsentValueV1 && f.value.reason === reason &&
            s.state === :typed_absent && s.reason === reason &&
            isempty(s.source_pin_roles)
    end for (id, reason) in g2_absent_reasons
        if id != "N08-04" || _up2_find_field(input.state, id).value isa UP2AbsentValueV1) ||
        throw(ArgumentError("VNext UP2 unmapped G2 rows cannot claim typed geometry"))
    n08_04 = _up2_find_field(input.state, "N08-04")
    n08_04_state = first(x for x in input.field_states if x.field_id == "N08-04")
    if !(n08_04.value isa UP2AbsentValueV1)
        n08_04.value isa UP2SymbolValueV1 && n08_04.value.value === :linear &&
            all(cross_present) &&
            n08_04_state.state === :source_present_deferred &&
            n08_04_state.reason === :candidate_design_g2_q1_h1_degree1_basis_contract_only &&
            n08_04_state.source_pin_roles == (:g2_builder, :g2_declaration_source) ||
            throw(ArgumentError("VNext UP2 N08-04 Q1/H1 legacy-basis mapping is invalid"))
    end
    input.state.flux_pair.port_source === :unverified ||
        throw(ArgumentError("VNext UP2 must preserve the unverified flux pair"))
    input_hash_body = (source_binding=binding,
        mission_bounds=input.mission_bounds, state=input.state,
        field_states=input.field_states, status=input.status,
        resolution=input.resolution, claim_ceiling=input.claim_ceiling)
    isempty(input.provider_bindings) ||
        (input_hash_body = merge(input_hash_body,
            (provider_bindings=input.provider_bindings,)))
    input.input_hash == canonical_hash(input_hash_body) ||
        throw(ArgumentError("VNext UP2 input hash mismatch"))
    if n10_validation_contexts !== nothing
        n09_validation_contexts = n09_validation_contexts === nothing ?
            n10_validation_contexts : merge(n09_validation_contexts,
                n10_validation_contexts)
    end
    n09_validation_contexts
end

function up2_validate_vnext_input(input::UP2VNextPrecompilerInputV1;
        package=nothing, native_plan=nothing, native_report=nothing,
        heat_lift_receipt=nothing, identity_package=nothing, available_route_ids=nothing)
    _up2_validate_vnext_input_with_context(input, package, native_plan;
        native_report=native_report, heat_lift_receipt=heat_lift_receipt,
        identity_package=identity_package, available_route_ids=available_route_ids)
    true
end

up2_validate_input(input::UP2VNextPrecompilerInputV1; kwargs...) =
    up2_validate_vnext_input(input; kwargs...)

function _up2_typed_value_matches(value::UP2TypedValueV1, kind::Symbol)
    kind === :integer && return value isa UP2IntegerValueV1
    kind === :symbol && return value isa UP2SymbolValueV1
    kind === :text && return value isa UP2TextValueV1
    kind === :rational && return value isa UP2RationalValueV1
    kind === :unit && return value isa UP2UnitValueV1
    kind === :hash && return value isa UP2HashValueV1
    kind === :ref && return value isa Union{UP2RefValueV1,UP2ContractRefValueV1}
    kind === :tuple && return value isa UP2TupleValueV1
    false
end

function _up2_baseline_invariants(input)
    ranks = Tuple(_up2_find_field(input.state, id).value for id in ("N01-01", "N01-02", "N01-03"))
    all(x -> x isa UP2IntegerValueV1 && x.value >= 0, ranks) || return false
    ranks[1].value == ranks[2].value == ranks[3].value || return false
    shape = _up2_find_field(input.state, "N01-05").value
    dim = _up2_find_field(input.state, "N01-04").value
    state_unit = _up2_find_field(input.state, "N02-03").value
    shape isa UP2SymbolValueV1 && shape.value in (:scalar, :vector3) || return false
    dim isa UP2IntegerValueV1 && dim.value == 3 || return false
    state_unit isa UP2TextValueV1 && state_unit.value == input.mission_bounds.unit || return false
    unit_ids = ("N02-01", "N02-02", "N02-04", "N02-05")
    units = Tuple(_up2_find_field(input.state, id).value for id in unit_ids)
    all(x -> x isa UP2UnitValueV1, units) || return false
    units[1].value == units[2].value || return false
    units[3].value == units[4].value || return false
    pair = input.state.flux_pair
    _up2_find_field(input.state, "N05-01").value.value == pair.left_port || return false
    _up2_find_field(input.state, "N05-02").value.value == pair.right_port || return false
    _up2_find_field(input.state, "N05-03").value.value == pair.left_sign || return false
    _up2_find_field(input.state, "N05-04").value.value == pair.right_sign || return false
    _up2_find_field(input.state, "N05-05").value.value == pair.unit || return false
    true
end

function _up2_n07n08_spec(spec::UP2MutationSpecV1)
    source_type = spec.id in ("N07-01", "N07-02") ? :rational3 :
        spec.id == "N07-03" ? :symbol_tuple :
        spec.id == "N07-04" ? :rational2 :
        spec.id in ("N07-05", "N08-02", "N08-04") ? :symbol :
        spec.id == "N08-01" ? :symbol_tuple :
        spec.id == "N08-03" ? :int3 :
        spec.id == "N08-05" ? :interface_refs :
        throw(ArgumentError("not an N07/N08 row: $(spec.id)"))
    N07N08MutationSpecV1(spec.id, spec.class_id, spec.field_path,
        spec.source_locator, source_type, spec.mutation_kind,
        spec.expected_error, spec.expected_resolution,
        spec.expected_provider_calls)
end

function _up2_n07n08_a_projection(input::UP2PrecompilerInputV1, package)
    package isa CandidateStatePackageV5 &&
        package.candidate_ref == input.candidate_ref &&
        package.candidate_hash == input.package_hash ||
        throw(ArgumentError("N07/N08 mutation requires its bound actual A package"))
    projection = n07_n08_projection_from_a(package)
    projection.candidate_ref == input.candidate_ref &&
        projection.package_hash == input.package_hash ||
        throw(ArgumentError("N07/N08 projection identity differs from the UP2 input"))
    for spec in _UP2_MUTATION_SPECS
        spec.class_id in (:N07, :N08) || continue
        field = _up2_find_field(input.state, spec.id)
        field === nothing && throw(ArgumentError("UP2 input misses $(spec.id)"))
        field.field_path == spec.field_path &&
            field.source_locator == spec.source_locator &&
            field.source_type == spec.source_type &&
            semantic_view(field.value) == semantic_view(
                _up2_n07n08_field_value(projection, spec.id)) ||
            throw(ArgumentError("UP2 $(spec.id) differs from its bound actual G2 source"))
    end
    projection
end

function _up2_vnext_n07n08_value(spec::UP2MutationSpecV1,
        input::UP2VNextPrecompilerInputV1, context)
    field = _up2_find_field(input.state, spec.id)
    row = first(x for x in input.field_states if x.field_id == spec.id)
    expected_reason = spec.id == "N08-04" ?
        :candidate_design_g2_q1_h1_degree1_basis_contract_only :
        :candidate_design_g2_geometry_contract_only
    haskey(context.values, spec.id) && row.state === :source_present_deferred &&
        row.reason === expected_reason &&
        row.source_pin_roles == (:g2_builder, :g2_declaration_source) ||
        throw(ArgumentError("VNext $(spec.id) has no candidate-bound typed G2 value"))
    semantic_view(field.value) == semantic_view(
        _up2_vnext_g2_up2_value(spec, context.values[spec.id])) ||
        throw(ArgumentError("VNext $(spec.id) baseline differs from its bound G2 source"))
    if spec.id == "N07-01"
        return UP2TupleValueV1((-1 // 1, 0 // 1, 0 // 1), :rational)
    elseif spec.id == "N07-02"
        return UP2TupleValueV1((3 // 1, 1 // 1, 1 // 1), :rational)
    elseif spec.id == "N07-03"
        return UP2TupleValueV1(Tuple(x for x in context.values[spec.id]
            if x !== :x_min), :symbol)
    elseif spec.id == "N07-04"
        patch = getproperty(context, :boundary_patch_context)
        baseline = context.values[spec.id]
        return UP2TupleValueV1((patch.lower[1] - 1 // 1, baseline[2]), :rational)
    elseif spec.id == "N07-05"
        return UP2SymbolValueV1(:none_declared)
    elseif spec.id == "N08-02"
        return UP2SymbolValueV1(:invalid_map)
    elseif spec.id == "N08-03"
        return UP2TupleValueV1((0, 2, 2), :integer)
    elseif spec.id == "N08-01"
        return UP2TupleValueV1((:x, :y, :q), :symbol)
    elseif spec.id == "N08-04"
        return UP2SymbolValueV1(:spectral)
    elseif spec.id == "N08-05"
        refs = context.values[spec.id]
        return UP2TupleValueV1((first(refs), first(refs)), :qualified_ref)
    end
    throw(ArgumentError("VNext $(spec.id) has no typed G2 mutation"))
end

function _up2_mutation_value(spec, input; package=nothing,
        native_plan=nothing, n04_05_context=nothing, g1_context=nothing,
        n07n08_context=nothing,
        n09_context=nothing)
    if input isa UP2VNextPrecompilerInputV1 &&
            spec.class_id === :N09 && spec.id in
                ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05")
        package isa CandidateStatePackageV5NextV2 && n09_context isa NamedTuple &&
            haskey(n09_context.matches, spec.id) ||
            throw(ArgumentError("VNext $(spec.id) mutation requires its bound native service context"))
        row = first(x for x in input.field_states if x.field_id == spec.id)
        expected_reason = spec.id == "N09-01" ?
            :candidate_design_g1_grad_native_gridap_service_match :
            spec.id == "N09-04" ?
            :candidate_design_g1_g2_scalar_heat_lift_provider_match :
            spec.id == "N09-02" ?
            :candidate_design_g2_profile_native_gridap_service_match :
            spec.id == "N09-03" ?
            :candidate_design_g2_exterior_native_gridap_service_match :
            :candidate_design_g3_control_sampled_service_match
        expected_roles = spec.id == "N09-01" ?
            (:g1_builder, :g1_declaration_source) :
            spec.id in ("N09-02", "N09-03") ?
            (:g2_builder, :g2_declaration_source) :
            spec.id == "N09-04" ?
            (:g1_builder, :g1_declaration_source, :g2_builder,
             :g2_declaration_source, :g3_builder, :g3_child_design) :
            (:g3_builder, :g3_child_design)
        row.state === :source_present_deferred && row.reason === expected_reason &&
            row.source_pin_roles == expected_roles &&
            input.provider_bindings == n09_context.provider_bindings ||
            throw(ArgumentError("VNext $(spec.id) baseline is not bound to the native service"))
        baseline = _up2_find_field(input.state, spec.id).value
        baseline isa UP2SymbolValueV1 &&
            baseline.value === n09_context.matches[spec.id] === :unique_match ||
            throw(ArgumentError("VNext $(spec.id) baseline does not match its exact native service"))
        return UP2SymbolValueV1(Symbol(string(
            _up2_vnext_n09_mutated_match(n09_context, spec.id).status)))
    end
    if spec.class_id in (:N07, :N08)
        if input isa UP2VNextPrecompilerInputV1
            package === nothing &&
                throw(ArgumentError("VNext $(spec.id) mutation requires its bound T1 package"))
            context = n07n08_context === nothing ?
                _up2_vnext_g2_geometry_context(package, input.source_binding) :
                n07n08_context
            return _up2_vnext_n07n08_value(spec, input, context)
        end
        package === nothing &&
            throw(ArgumentError("$(spec.id) mutation requires its bound actual A package"))
        projection = _up2_n07n08_a_projection(input, package)
        q = _n07n08_mutate(projection, _up2_n07n08_spec(spec))
        return _up2_n07n08_field_value(q, spec.id)
    end
    spec.id in ("N01-01", "N01-02", "N01-03") && return UP2IntegerValueV1(1)
    spec.id == "N01-04" && return UP2IntegerValueV1(2)
    spec.id == "N01-05" && return UP2SymbolValueV1(:tensor5)
    spec.id == "N03-01" && return UP2SymbolValueV1(_up2_n03_unlisted_time_kind(input))
    spec.id == "N03-02" && return UP2IntegerValueV1(-1)
    spec.id == "N03-03" && return UP2TupleValueV1((_up2_n03_unlisted_time_kind(input),), :timekind_v1)
    spec.class_id === :N02 && spec.source_type === :unit &&
        return UP2UnitValueV1(UnitSignature((1, 0, 0, 0, 0, 0, 0)))
    spec.id == "N02-03" && return UP2TextValueV1("kg")
    spec.mutation_kind === :left_empty && return UP2TextValueV1("")
    spec.mutation_kind === :right_empty && return UP2TextValueV1("")
    spec.mutation_kind === :left_sign_zero && return UP2IntegerValueV1(0)
    spec.mutation_kind === :same_sign && return UP2IntegerValueV1(1)
    spec.mutation_kind === :unit_mismatch && return UP2UnitValueV1(UnitSignature((1, 0, 0, 0, 0, 0, 0)))
    if spec.id == "N04-02" && spec.mutation_kind === :duplicate_account_ids
        original = _up2_find_field(input.state, spec.id).value
        original isa UP2TupleValueV1 && original.element_type === :string && !isempty(original.values) ||
            throw(ArgumentError("N04-02 requires the actual typed G3 closure account_ids"))
        all(x -> x isa String && !isempty(x), original.values) && length(unique(original.values)) == length(original.values) ||
            throw(ArgumentError("N04-02 baseline closure account_ids are not unique nonempty strings"))
        return UP2TupleValueV1((String(first(original.values)), String(first(original.values))), :string)
    end
    throw(ArgumentError("no real typed mutation value for $(spec.id); semantic gap is pending"))
end

function _up2_vnext_n0102_source_value(spec::UP2MutationSpecV1,
        g1_context, geometry_context; ledger_context=nothing)
    if spec.id in ("N01-01", "N01-02", "N02-01", "N02-02")
        g1_context isa NamedTuple && haskey(g1_context.values, spec.id) ||
            throw(ArgumentError("VNext $(spec.id) has no source-pinned G1 operator value"))
        value = g1_context.values[spec.id]
        if spec.id in ("N01-01", "N01-02")
            value isa Int || throw(ArgumentError("VNext $(spec.id) G1 rank is not Int"))
            return UP2IntegerValueV1(value)
        end
        value isa UnitSignature ||
            throw(ArgumentError("VNext $(spec.id) G1 endpoint unit is not UnitSignature"))
        return UP2UnitValueV1(value)
    elseif spec.id in ("N01-03", "N01-05", "N02-03")
        geometry_context isa NamedTuple &&
            geometry_context.cross_state_context !== nothing &&
            haskey(geometry_context.values, spec.id) ||
            throw(ArgumentError("VNext $(spec.id) has no source-pinned G1/G2 state-field join"))
        value = geometry_context.values[spec.id]
        if spec.id == "N01-03"
            value isa Int || throw(ArgumentError("VNext N01-03 joined state rank is not Int"))
            return UP2IntegerValueV1(value)
        elseif spec.id == "N01-05"
            value isa Symbol || throw(ArgumentError("VNext N01-05 joined state shape is not Symbol"))
            return UP2SymbolValueV1(value)
        end
        value isa String || throw(ArgumentError("VNext N02-03 joined state unit label is not String"))
        return UP2TextValueV1(value)
    elseif spec.id in ("N03-01", "N03-02")
        g1_context isa NamedTuple && haskey(g1_context.values, spec.id) ||
            throw(ArgumentError("VNext $(spec.id) has no source-pinned G1 temporal value"))
        value = g1_context.values[spec.id]
        return spec.id == "N03-01" ? UP2SymbolValueV1(value) :
            UP2IntegerValueV1(value)
    elseif spec.id in ("N02-04", "N02-05")
        ledger_context isa NamedTuple && ledger_context.n02_04_05_present ||
            throw(ArgumentError("VNext $(spec.id) has no source-pinned G3 unit"))
        value = spec.id == "N02-04" ? ledger_context.source_bus_unit :
            ledger_context.source_entry_unit
        value isa UnitSignature ||
            throw(ArgumentError("VNext $(spec.id) G3 source unit is not UnitSignature"))
        return UP2UnitValueV1(value)
    elseif spec.id == "N01-04"
        geometry_context isa NamedTuple && hasproperty(geometry_context, :profile_dimension) ||
            throw(ArgumentError("VNext N01-04 has no source-pinned G2 profile dimension"))
        return UP2IntegerValueV1(geometry_context.profile_dimension)
    end
    throw(ArgumentError("VNext $(spec.id) is not a projected N01/N02 source row"))
end

function _up2_vnext_n0102_mutated_value(spec::UP2MutationSpecV1, baseline)
    if spec.id in ("N01-01", "N01-02", "N01-04")
        baseline isa UP2IntegerValueV1 && baseline.value >= 0 &&
            baseline.value < typemax(Int) ||
            throw(ArgumentError("VNext $(spec.id) baseline integer cannot be incremented"))
        return UP2IntegerValueV1(baseline.value + 1)
    elseif spec.id == "N01-03"
        baseline isa UP2IntegerValueV1 && baseline.value >= 0 &&
            baseline.value < typemax(Int) ||
            throw(ArgumentError("VNext N01-03 baseline rank cannot be incremented"))
        return UP2IntegerValueV1(baseline.value + 1)
    elseif spec.id == "N01-05"
        baseline isa UP2SymbolValueV1 && baseline.value in (:scalar, :vector3) ||
            throw(ArgumentError("VNext N01-05 baseline shape is not a supported source shape"))
        return UP2SymbolValueV1(baseline.value === :scalar ? :vector3 : :scalar)
    elseif spec.id == "N02-03"
        baseline isa UP2TextValueV1 && !isempty(baseline.value) ||
            throw(ArgumentError("VNext N02-03 baseline unit label is not text"))
        return UP2TextValueV1(baseline.value == "1" ? "__unit_label_mismatch__" : "1")
    elseif spec.id in ("N02-01", "N02-02")
        baseline isa UP2UnitValueV1 ||
            throw(ArgumentError("VNext $(spec.id) baseline is not a typed unit"))
        exponents = baseline.value.exponents
        changed_first = iszero(exponents[1]) ? 1 // 1 : 0 // 1
        return UP2UnitValueV1(UnitSignature(ntuple(i -> i == 1 ? changed_first :
            exponents[i], 7)))
    elseif spec.id in ("N02-04", "N02-05")
        baseline isa UP2UnitValueV1 ||
            throw(ArgumentError("VNext $(spec.id) baseline is not a typed unit"))
        exponents = baseline.value.exponents
        changed_first = exponents[1] + (1 // 1)
        return UP2UnitValueV1(UnitSignature(ntuple(i -> i == 1 ? changed_first :
            exponents[i], 7)))
    end
    throw(ArgumentError("VNext $(spec.id) has no registered N01/N02 mutation"))
end

Base.@noinline Base.@nospecializeinfer function _up2_mutation_value(spec::UP2MutationSpecV1,
        input::UP2VNextPrecompilerInputV1; package=nothing, n04_05_context=nothing,
        native_plan=nothing, g1_context=nothing, n07n08_context=nothing,
        n09_context=nothing, native_report=nothing, heat_lift_receipt=nothing,
        identity_package=nothing)
    Base.@nospecialize spec input package n04_05_context native_plan g1_context n07n08_context n09_context native_report heat_lift_receipt identity_package
    validated_contexts = _up2_validate_vnext_input_with_context(input,
        package, native_plan; identity_package=identity_package,
        native_report=native_report, heat_lift_receipt=heat_lift_receipt)
    validated_contexts !== nothing && hasproperty(validated_contexts, :n09_context) &&
        (n09_context = validated_contexts.n09_context)
    n05_context = validated_contexts !== nothing &&
        hasproperty(validated_contexts, :n05_context) ?
        validated_contexts.n05_context : nothing
    n10_context = validated_contexts !== nothing &&
        hasproperty(validated_contexts, :n10_context) ?
        validated_contexts.n10_context : nothing
    _up2_mutation_value_after_validation(spec, input; package=package,
        n04_05_context=n04_05_context, native_plan=native_plan,
        g1_context=g1_context, n07n08_context=n07n08_context,
        n09_context=n09_context, n05_context=n05_context,
        n10_context=n10_context, native_report=native_report,
        heat_lift_receipt=heat_lift_receipt)
end

Base.@noinline Base.@nospecializeinfer function _up2_mutation_value_after_validation(spec::UP2MutationSpecV1,
        input::UP2VNextPrecompilerInputV1; package=nothing, n04_05_context=nothing,
        native_plan=nothing, g1_context=nothing, n07n08_context=nothing,
        n09_context=nothing, n05_context=nothing, n10_context=nothing,
        native_report=nothing, heat_lift_receipt=nothing)
    Base.@nospecialize spec input package n04_05_context native_plan g1_context n07n08_context n09_context n05_context n10_context native_report heat_lift_receipt
    if spec.class_id === :N10 && spec.id in ("N10-04", "N10-05")
        package isa CandidateStatePackageV5NextV2 &&
            n10_context isa NamedTuple && hasproperty(n10_context, :identity_package) ||
            throw(ArgumentError("VNext $(spec.id) mutation requires its source-bound actual V5 package"))
        identity_package = n10_context.identity_package
        reason = spec.id == "N10-04" ?
            :current_vnext_t0_t1_component_identity_compatibility_view :
            :current_vnext_t0_t1_fresh_identity_receipt_not_v4_migration
        roles = (:g1_builder, :g1_declaration_source, :g2_builder,
            :g2_declaration_source, :g3_builder, :g3_child_design)
        row = first(state for state in input.field_states if state.field_id == spec.id)
        row.state === :source_present_deferred && row.reason === reason &&
            row.source_pin_roles == roles || throw(ArgumentError("VNext $(spec.id) baseline is not bound to its actual V5 field"))
        baseline = _up2_find_field(input.state, spec.id).value
        semantic_view(baseline) == semantic_view(_up2_vnext_n10_value(spec, n10_context)) || throw(ArgumentError("VNext $(spec.id) baseline differs from its actual V5 field"))
        if spec.id == "N10-04"
            spec.mutation_kind === :pending && spec.expected_error === :invalid_type ||
                throw(ArgumentError("VNext N10-04 frozen outcome changed"))
            return UP2TextValueV1("wrong-type:" * identity_package.candidate_hash.value)
        end
        spec.mutation_kind === :pending && spec.expected_error === :terminal_deferred &&
            spec.expected_resolution === terminal_deferred || throw(ArgumentError("VNext N10-05 frozen outcome changed"))
        original = identity_package.migration_receipt.candidate_identity_after
        changed = canonical_hash((domain="up2-n10-05-fresh-identity-mismatch-v1",
            candidate_ref=identity_package.candidate_ref,
            original_identity_after=original)).value
        changed == original && (changed = canonical_hash((original=original,
            mutation_id=spec.id)).value)
        return UP2TextValueV1(changed)
    end
    if spec.class_id === :N10 && spec.id in ("N10-01", "N10-02", "N10-03")
        package isa CandidateStatePackageV5NextV2 && n10_context isa NamedTuple ||
            throw(ArgumentError("VNext $(spec.id) mutation requires its bound T0/T1 contract refs"))
        expected_error = spec.id == "N10-01" ? :invalid_type : :terminal_deferred
        spec.mutation_kind === :pending && spec.expected_error === expected_error &&
            spec.expected_resolution === terminal_deferred ||
            throw(ArgumentError("VNext $(spec.id) mutation metadata is not frozen"))
        ref = spec.id == "N10-01" ? n10_context.contract_refs.g1 :
            spec.id == "N10-02" ? n10_context.contract_refs.g2 :
            n10_context.contract_refs.binding
        ref isa GenomeContractRef ||
            throw(ArgumentError("VNext $(spec.id) has no bound typed contract ref"))
        row = first(state for state in input.field_states if state.field_id == spec.id)
        expected_roles = spec.id == "N10-01" ?
            (:g1_builder, :g1_declaration_source) :
            spec.id == "N10-02" ?
            (:g2_builder, :g2_declaration_source) :
            (:g3_builder, :g3_child_design)
        row.state === :source_present_deferred &&
            row.reason === :current_vnext_t1_t0_typed_ref_not_legacy_v5_identity &&
            row.source_pin_roles == expected_roles ||
            throw(ArgumentError("VNext $(spec.id) baseline is not bound to its typed contract ref"))
        baseline = _up2_find_field(input.state, spec.id).value
        semantic_view(baseline) == semantic_view(_up2_vnext_n10_value(spec, n10_context)) ||
            throw(ArgumentError("VNext $(spec.id) baseline differs from its bound typed contract ref"))
        if spec.id == "N10-01"
            changed_hash = Digest256(ref.schema_hash.value == repeat("0", 64) ?
                repeat("1", 64) : repeat("0", 64))
            return UP2TextValueV1(changed_hash.value)
        elseif spec.id == "N10-02"
            changed_hash = Digest256(ref.canonicalization_hash.value == repeat("0", 64) ?
                repeat("1", 64) : repeat("0", 64))
            return UP2HashValueV1(changed_hash)
        else
            return UP2ContractRefValueV1(GenomeContractRef(
                ref.uri * "/up2-binding-ref-mismatch", ref.version,
                ref.schema_hash, ref.canonicalization_hash,
                ref.compatibility_profile))
        end
    end
    if spec.class_id === :N05
        package isa CandidateStatePackageV5NextV2 &&
            spec.expected_error === :invalid_closure && n05_context isa NamedTuple ||
            throw(ArgumentError("VNext $(spec.id) mutation requires its bound T1 flux context"))
        expected_mutations = Dict("N05-01" => :left_empty,
            "N05-02" => :right_empty, "N05-03" => :left_sign_zero,
            "N05-04" => :same_sign, "N05-05" => :unit_mismatch)
        get(expected_mutations, spec.id, nothing) === spec.mutation_kind ||
            throw(ArgumentError("VNext N05 mutation metadata is not frozen"))
        row = first(state for state in input.field_states if state.field_id == spec.id)
        expected_reason = spec.id == "N05-05" ?
            :candidate_design_g1_k_apply_output_unit_contract_only :
            :candidate_design_g1_g2_interface_flux_contract_only
        expected_roles = spec.id == "N05-05" ?
            (:g1_builder, :g1_declaration_source) :
            (:g1_builder, :g1_declaration_source, :g2_builder, :g2_declaration_source)
        row.state === :source_present_deferred && row.reason === expected_reason &&
            row.source_pin_roles == expected_roles ||
            throw(ArgumentError("VNext $(spec.id) baseline is not bound to its typed flux pair"))
        pair = n05_context.pair
        baseline = _up2_find_field(input.state, spec.id).value
        expected = spec.id == "N05-01" ? UP2TextValueV1(pair.left_port) :
            spec.id == "N05-02" ? UP2TextValueV1(pair.right_port) :
            spec.id == "N05-03" ? UP2IntegerValueV1(pair.left_sign) :
            spec.id == "N05-04" ? UP2IntegerValueV1(pair.right_sign) :
            UP2UnitValueV1(pair.unit)
        semantic_view(baseline) == semantic_view(expected) ||
            throw(ArgumentError("VNext $(spec.id) baseline differs from typed flux source"))
        return spec.id == "N05-01" ? UP2TextValueV1("") :
            spec.id == "N05-02" ? UP2TextValueV1("") :
            spec.id == "N05-03" ? UP2IntegerValueV1(0) :
            spec.id == "N05-04" ? UP2IntegerValueV1(pair.left_sign) :
            UP2UnitValueV1(UnitSignature((1,0,0,0,0,0,0)))
    end
    if spec.class_id === :N09 && spec.id in
            ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05")
        package isa CandidateStatePackageV5NextV2 &&
            native_plan !== nothing && n09_context isa NamedTuple ||
            throw(ArgumentError("VNext $(spec.id) mutation requires its bound native service context"))
        row = first(state for state in input.field_states if state.field_id == spec.id)
        expected_reason = spec.id == "N09-01" ?
            :candidate_design_g1_grad_native_gridap_service_match :
            spec.id == "N09-04" ?
            :candidate_design_g1_g2_scalar_heat_lift_provider_match :
            spec.id == "N09-02" ?
            :candidate_design_g2_profile_native_gridap_service_match :
            spec.id == "N09-03" ?
            :candidate_design_g2_exterior_native_gridap_service_match :
            :candidate_design_g3_control_sampled_service_match
        expected_roles = spec.id == "N09-01" ?
            (:g1_builder, :g1_declaration_source) :
            spec.id in ("N09-02", "N09-03") ?
            (:g2_builder, :g2_declaration_source) :
            spec.id == "N09-04" ?
            (:g1_builder, :g1_declaration_source, :g2_builder,
             :g2_declaration_source, :g3_builder, :g3_child_design) :
            (:g3_builder, :g3_child_design)
        row.state === :source_present_deferred && row.reason === expected_reason &&
            row.source_pin_roles == expected_roles &&
            input.provider_bindings == n09_context.provider_bindings ||
            throw(ArgumentError("VNext $(spec.id) baseline is not bound to the native service"))
        baseline = _up2_find_field(input.state, spec.id).value
        baseline isa UP2SymbolValueV1 &&
            baseline.value === n09_context.matches[spec.id] === :unique_match ||
            throw(ArgumentError("VNext $(spec.id) baseline does not match its exact native service"))
        return UP2SymbolValueV1(Symbol(string(
            _up2_vnext_n09_mutated_match(n09_context, spec.id).status)))
    end
    if spec.id in ("N06-01", "N06-05")
        package isa CandidateStatePackageV5NextV2 &&
            spec.class_id === :N06 && spec.mutation_kind === :pending &&
            spec.expected_error === :invalid_closure &&
            spec.expected_resolution === terminal_deferred ||
            throw(ArgumentError("VNext $(spec.id) mutation requires its bound typed resource network"))
        context = n04_05_context === nothing ?
            _up2_vnext_n04_05_context(package, input.source_binding;
                include_child_design=true) : n04_05_context
        source = _up2_vnext_n06_resource_network(context, input.source_binding)
        row = first(x for x in input.field_states if x.field_id == spec.id)
        row.state === :source_present_deferred &&
            row.reason === :candidate_design_g3_typed_resource_network_contract_only &&
            row.source_pin_roles == (:g3_builder, :g3_child_design) ||
            throw(ArgumentError("VNext $(spec.id) row is not bound to the typed G3 resource network"))
        baseline = _up2_find_field(input.state, spec.id).value
        if spec.id == "N06-01"
            baseline isa UP2TupleValueV1 &&
                baseline.element_type === :G3ResourcePortV2 &&
                canonical_hash(baseline.values) ==
                    canonical_hash(source.network.resource_ports) ||
                throw(ArgumentError("VNext N06-01 baseline differs from bound typed G3 resource ports"))
            port = source.effort_port
            any(component -> port.port_id in component.resource_port_ids,
                source.network.components) ||
                throw(ArgumentError("VNext N06-01 source effort port is not a required component port"))
            changed_ports = Tuple(item for item in source.network.resource_ports
                if item.port_id != port.port_id)
            return UP2TupleValueV1(changed_ports, :G3ResourcePortV2)
        end
        source.network.resource_ports[1].port_id == source.effort_port.port_id ||
            throw(ArgumentError("VNext N06-05 fixed tuple index does not identify the bound source effort port"))
        baseline isa UP2SymbolValueV1 &&
            baseline.value === source.network.resource_ports[1].kind ||
            throw(ArgumentError("VNext N06-05 baseline differs from the bound first resource-port kind"))
        return UP2SymbolValueV1(_up2_vnext_n06_mismatched_kind(source.effort_port))
    end
    if spec.id == "N06-03"
        package isa CandidateStatePackageV5NextV2 &&
            spec.class_id === :N06 && spec.expected_error === :invalid_closure &&
            spec.mutation_kind === :pending ||
            throw(ArgumentError("VNext N06-03 mutation requires the current-source flow-link contract"))
        context = n04_05_context === nothing ?
            _up2_vnext_n04_05_context(package, input.source_binding;
                include_child_design=true) : n04_05_context
        selected = _up2_vnext_n06_03_flow_link(context, input.source_binding)
        row = first(state for state in input.field_states if state.field_id == spec.id)
        row.state === :source_present_deferred &&
            row.reason === :candidate_design_g3_control_flow_link_design_only &&
            row.source_pin_roles == (:g3_builder, :g3_child_design) ||
            throw(ArgumentError("VNext N06-03 row is not bound to the pinned typed flow link"))
        baseline = _up2_find_field(input.state, spec.id).value
        baseline isa UP2TextValueV1 && baseline.value == selected.link.resource_port_id ||
            throw(ArgumentError("VNext N06-03 baseline differs from the authored current-flow link"))
        return UP2TextValueV1(baseline.value * "__unknown_resource")
    end
    if spec.id == "N06-02"
        package === nothing && throw(ArgumentError("VNext N06-02 mutation requires its bound T1 package"))
        spec.class_id === :N06 && spec.expected_error === :invalid_closure &&
            spec.mutation_kind === :pending || throw(ArgumentError("VNext N06-02 mutation metadata is not frozen"))
        context = n04_05_context === nothing ?
            _up2_vnext_n04_05_context(package, input.source_binding) : n04_05_context
        verified = _up2_vnext_n06_04_closure(context, input.source_binding)
        row = first(x for x in input.field_states if x.field_id == spec.id)
        row.state === :source_present_deferred &&
            row.reason === :candidate_design_g3_ledger_entries_design_only &&
            row.source_pin_roles == (:g3_builder, :g3_child_design) ||
            throw(ArgumentError("VNext N06-02 row is not bound to typed G3 ledger entries"))
        baseline = _up2_find_field(input.state, spec.id).value
        baseline isa UP2TupleValueV1 && baseline.element_type === :g3_ledger_entry_v2 &&
            canonical_hash(baseline.values) == canonical_hash(verified.entries) ||
            throw(ArgumentError("VNext N06-02 baseline differs from bound typed G3 ledger entries"))
        heat_rows = Tuple(e for e in verified.entries if e.effect === :heat_rejection)
        length(heat_rows) == 1 || throw(ArgumentError("VNext N06-02 requires one authored heat-rejection ledger entry"))
        heat_entry = only(heat_rows)
        heat_entry.account_id in verified.closure.account_ids ||
            throw(ArgumentError("VNext N06-02 heat-rejection entry is outside the selected verified closure"))
        return UP2TupleValueV1(Tuple(e for e in verified.entries
            if e.entry_id != heat_entry.entry_id), :g3_ledger_entry_v2)
    end
    if spec.id == "N06-04"
        package === nothing &&
            throw(ArgumentError("VNext N06-04 mutation requires its bound T1 package"))
        spec.class_id === :N06 && spec.expected_error === :invalid_closure &&
            spec.mutation_kind === :pending ||
            throw(ArgumentError("VNext N06-04 mutation metadata is not frozen"))
        context = n04_05_context === nothing ?
            _up2_vnext_n04_05_context(package, input.source_binding) : n04_05_context
        verified = _up2_vnext_n06_04_closure(context, input.source_binding)
        row = first(state for state in input.field_states if state.field_id == spec.id)
        row.state === :source_present_deferred &&
            row.reason === :candidate_design_g3_closure_balance_design_only &&
            row.source_pin_roles == (:g3_builder, :g3_child_design) ||
            throw(ArgumentError("VNext N06-04 row is not bound to the typed G3 closure"))
        baseline = _up2_find_field(input.state, spec.id).value
        baseline isa UP2RationalValueV1 &&
            baseline.value == verified.closure.expected_balance == verified.actual_balance ||
            throw(ArgumentError("VNext N06-04 baseline differs from independently balanced source closure"))
        return UP2RationalValueV1(baseline.value + (Int64(1) // Int64(1)))
    end
    if spec.id == "N03-03"
        package === nothing &&
            throw(ArgumentError("VNext N03-03 mutation requires its bound T1 package"))
        spec.class_id === :N03 && spec.expected_error === :invalid_type &&
            spec.mutation_kind === :exclude_equation_time_kind ||
            throw(ArgumentError("VNext N03-03 mutation metadata is not frozen"))
        g1 = g1_context === nothing ?
            _up2_vnext_g1_operator_type_context(package, input.source_binding) : g1_context
        haskey(g1.values, "N03-03") ||
            throw(ArgumentError("VNext N03-03 has no explicit source-pinned G1 whitelist"))
        row = first(state for state in input.field_states if state.field_id == spec.id)
        row.state === :source_present_deferred &&
            row.reason === :candidate_design_g1_operator_temporal_whitelist_contract_only &&
            row.source_pin_roles == (:g1_builder, :g1_declaration_source) ||
            throw(ArgumentError("VNext N03-03 row is not bound to the G1 temporal whitelist"))
        baseline = _up2_find_field(input.state, spec.id).value
        expected = UP2TupleValueV1(g1.values["N03-03"], :timekind_v1)
        baseline isa UP2TupleValueV1 && baseline.element_type === :timekind_v1 &&
            semantic_view(baseline) == semantic_view(expected) ||
            throw(ArgumentError("VNext N03-03 baseline differs from the source-pinned G1 whitelist"))
        equation_kind = g1.values["N03-01"]
        equation_kind in baseline.values ||
            throw(ArgumentError("VNext N03-03 G1 whitelist does not admit the equation kind"))
        mutated_kinds = Tuple(kind for kind in baseline.values if kind !== equation_kind)
        return UP2TupleValueV1(mutated_kinds, :timekind_v1)
    end
    if spec.id in ("N03-01", "N03-02")
        package === nothing &&
            throw(ArgumentError("VNext $(spec.id) mutation requires its bound T1 package"))
        expected_kind = spec.id == "N03-01" ? :unsupported_time_kind :
            :negative_derivative_order
        spec.class_id === :N03 && spec.expected_error === :invalid_type &&
            spec.mutation_kind === expected_kind ||
            throw(ArgumentError("VNext $(spec.id) mutation metadata is not frozen"))
        g1 = g1_context === nothing ?
            _up2_vnext_g1_operator_type_context(package, input.source_binding) : g1_context
        row = first(state for state in input.field_states if state.field_id == spec.id)
        row.state === :source_present_deferred &&
            row.reason === :candidate_design_g1_diffusion_time_contract_only &&
            row.source_pin_roles == (:g1_builder, :g1_declaration_source) ||
            throw(ArgumentError("VNext $(spec.id) row is not bound to the G1 diffusion time chain"))
        baseline = _up2_find_field(input.state, spec.id).value
        expected = _up2_vnext_n0102_source_value(spec, g1, nothing)
        semantic_view(baseline) == semantic_view(expected) ||
            throw(ArgumentError("VNext $(spec.id) baseline differs from its source-pinned temporal value"))
        return spec.id == "N03-01" ? UP2SymbolValueV1(:algebraic_time) :
            UP2IntegerValueV1(-1)
    end
    if spec.id in ("N01-01", "N01-02", "N01-03", "N01-04", "N01-05",
            "N02-01", "N02-02", "N02-03",
            "N02-04", "N02-05")
        package === nothing &&
            throw(ArgumentError("VNext $(spec.id) mutation requires its bound T1 package"))
        mutation_kind = spec.id in ("N01-01", "N01-02", "N01-03") ? :rank :
            spec.id == "N01-04" ? :dimension :
            spec.id == "N01-05" ? :shape :
            spec.id == "N02-03" ? :unit_text : :unit
        spec.class_id === (startswith(spec.id, "N02-") ? :N02 : :N01) &&
            spec.expected_error === :invalid_type && spec.mutation_kind === mutation_kind ||
            throw(ArgumentError("VNext $(spec.id) mutation metadata is not frozen"))
        g3 = n04_05_context
        g1_needed = spec.id in ("N01-01", "N01-02", "N02-01", "N02-02")
        g1 = g1_context === nothing && g1_needed ?
            _up2_vnext_g1_operator_type_context(package, input.source_binding) : g1_context
        g3_needed = spec.id in ("N02-04", "N02-05")
        g3 = g3 === nothing && g3_needed ?
            _up2_vnext_n04_05_context(package, input.source_binding) : g3
        g2_needed = spec.id in ("N01-03", "N01-04", "N01-05", "N02-03")
        g2 = g2_needed ? (n07n08_context === nothing ?
            _up2_vnext_g2_geometry_context(package, input.source_binding) : n07n08_context) :
            n07n08_context
        row = first(state for state in input.field_states if state.field_id == spec.id)
        cross_state_needed = spec.id in ("N01-03", "N01-05", "N02-03")
        expected_reason = cross_state_needed ?
            :candidate_design_g1_g2_state_field_binding_contract_only :
            spec.id == "N01-04" ?
            :candidate_design_g2_profile_contract_only :
            g3_needed ? :candidate_design_g3_ledger_unit_design_only :
            :candidate_design_g1_operator_type_contract_only
        expected_roles = cross_state_needed ?
            (:g1_builder, :g1_declaration_source, :g2_builder, :g2_declaration_source) :
            spec.id == "N01-04" ?
            (:g2_builder, :g2_declaration_source) :
            g3_needed ? (:g3_builder, :g3_child_design) :
            (:g1_builder, :g1_declaration_source)
        row.state === :source_present_deferred && row.reason === expected_reason &&
            row.source_pin_roles == expected_roles ||
            throw(ArgumentError("VNext $(spec.id) row is not bound to its typed source"))
        baseline = _up2_find_field(input.state, spec.id).value
        expected = _up2_vnext_n0102_source_value(spec, g1, g2;
            ledger_context=g3)
        semantic_view(baseline) == semantic_view(expected) ||
            throw(ArgumentError("VNext $(spec.id) baseline differs from its source-pinned value"))
        return _up2_vnext_n0102_mutated_value(spec, baseline)
    end
    if spec.class_id in (:N07, :N08)
        package === nothing &&
            throw(ArgumentError("VNext $(spec.id) mutation requires its bound T1 package"))
        spec.expected_error === :invalid_boundary ||
            throw(ArgumentError("VNext $(spec.id) mutation metadata is not frozen"))
        expected_kind = spec.id == "N07-04" ? :patch_out_of_domain :
            spec.id == "N08-01" ? :axes_invalid : nothing
        expected_kind === nothing || spec.mutation_kind === expected_kind ||
            throw(ArgumentError("VNext $(spec.id) mutation kind is not frozen"))
        context = n07n08_context === nothing ?
            _up2_vnext_g2_geometry_context(package, input.source_binding) : n07n08_context
        return _up2_vnext_n07n08_value(spec, input, context)
    end
    if spec.id in ("N04-01", "N04-02", "N04-03", "N04-04")
        package === nothing &&
            throw(ArgumentError("VNext $(spec.id) mutation requires its bound T1 package"))
        spec.class_id === :N04 && spec.expected_error === :invalid_closure ||
            throw(ArgumentError("VNext $(spec.id) mutation metadata is not frozen"))
        context = n04_05_context === nothing ?
            _up2_vnext_n04_05_context(package, input.source_binding) : n04_05_context
        if spec.id in ("N04-01", "N04-03")
            spec.id == "N04-01" ?
                (spec.mutation_kind === :owner_crosswalk_mismatch ||
                    throw(ArgumentError("VNext N04-01 mutation kind is not frozen"))) :
                (spec.mutation_kind === :unknown_account_ref ||
                    throw(ArgumentError("VNext N04-03 mutation kind is not frozen")))
            typed = context.typed_ledger_context
            typed isa NamedTuple ||
                throw(ArgumentError("VNext $(spec.id) typed G3 owner/account source is absent"))
            row = first(state for state in input.field_states if state.field_id == spec.id)
            expected_reason = spec.id == "N04-01" ?
                :candidate_design_ledger_owner_design_only :
                :candidate_design_ledger_entry_account_design_only
            row.state === :source_present_deferred && row.reason === expected_reason &&
                row.source_pin_roles == (:g3_builder, :g3_child_design) ||
                throw(ArgumentError("VNext $(spec.id) row is not bound to typed candidate ledger source"))
            baseline = _up2_find_field(input.state, spec.id).value
            expected = spec.id == "N04-01" ? typed.owner : typed.entry_account_id
            baseline isa UP2TextValueV1 && baseline.value == expected ||
                throw(ArgumentError("VNext $(spec.id) baseline differs from explicit typed source"))
            if spec.id == "N04-01"
                target = "__up2_owner_crosswalk_mismatch__"
                target == expected && (target *= "_mutated")
                return UP2TextValueV1(target)
            end
            target = "__up2_unknown_account__"
            while target in typed.account_ids
                target *= "_mutated"
            end
            return UP2TextValueV1(target)
        end
        row = first(state for state in input.field_states if state.field_id == spec.id)
        row.state === :source_present_deferred &&
            row.source_pin_roles == (:g3_builder, :g3_child_design) ||
            throw(ArgumentError("VNext $(spec.id) row is not bound to candidate design source"))
        if spec.id == "N04-02"
            row.reason === :candidate_design_ledger_closure_design_only &&
                spec.mutation_kind === :duplicate_account_ids ||
                throw(ArgumentError("VNext N04-02 mutation is not the registered closure mutation"))
            baseline = _up2_find_field(input.state, spec.id).value
            baseline isa UP2TupleValueV1 && baseline.element_type === :string &&
                baseline.values == context.closure_account_ids &&
                length(unique(baseline.values)) == length(baseline.values) &&
                all(id -> id in context.account_ids, baseline.values) ||
                throw(ArgumentError("VNext N04-02 baseline differs from bound authored closure"))
            return UP2TupleValueV1((String(first(baseline.values)),
                String(first(baseline.values))), :string)
        end
        row.reason === :candidate_design_ledger_component_design_only &&
            spec.mutation_kind === :pending ||
            throw(ArgumentError("VNext N04-04 mutation metadata is not frozen"))
        baseline = _up2_find_field(input.state, spec.id).value
        baseline isa UP2TextValueV1 &&
            baseline.value == context.source_entry_component_id &&
            context.source_entry_effect === :source &&
            context.source_component_kind === :source_component &&
            context.passive_component_kind === :passive_component ||
            throw(ArgumentError("VNext N04-04 baseline differs from bound source/passive component"))
        return UP2TextValueV1(context.passive_component_id)
    elseif spec.id == "N04-05"
        package === nothing &&
            throw(ArgumentError("VNext N04-05 mutation requires its bound T1 package"))
        spec.class_id === :N04 && spec.expected_error === :invalid_closure ||
            throw(ArgumentError("VNext N04-05 mutation metadata is not frozen"))
        context = n04_05_context === nothing ?
            _up2_vnext_n04_05_context(package, input.source_binding) : n04_05_context
        row = first(state for state in input.field_states if state.field_id == spec.id)
        row.state === :source_present_deferred &&
            row.reason === :candidate_design_ledger_capacity_design_only &&
            row.source_pin_roles == (:g3_builder, :g3_child_design) ||
            throw(ArgumentError("VNext N04-05 row is not bound to candidate design source"))
        baseline = _up2_find_field(input.state, spec.id).value
        baseline isa UP2RationalValueV1 &&
            baseline.value == context.coefficient ||
            throw(ArgumentError("VNext N04-05 baseline differs from bound authored ledger"))
        expected_sign = context.effect === :source ? 1 :
            context.effect in (:load, :return, :heat_rejection) ? -1 : 0
        expected_sign != 0 && baseline.value != 0 &&
            abs(baseline.value) <= context.capacity &&
            sign(baseline.value) == expected_sign ||
            throw(ArgumentError("VNext N04-05 baseline is not a within-capacity typed ledger value"))
        target = sign(baseline.value) * (context.capacity + (1 // 1))
        return UP2RationalValueV1(target)
    end
    spec.class_id === :N03 && spec.expected_error === :invalid_type ||
        throw(ArgumentError("VNext mutation is outside the supported N03/N04-05 contract slice"))
    binding = input.source_binding
    binding.time_basis === :event && binding.authority_scope === :local_source_data &&
        binding.authority_gap == "candidate_authored_event_time_policy_is_design_only" ||
        throw(ArgumentError("VNext N03 mutation lacks the candidate-design time policy"))
    row = first(state for state in input.field_states if state.field_id == spec.id)
    row.state === :source_present_deferred &&
        row.reason === :candidate_design_event_time_policy_design_only &&
        row.source_pin_roles == (:g3_builder, :g3_child_design) ||
        throw(ArgumentError("VNext N03 event row is not bound to candidate design source"))
    if spec.id == "N03-04"
        baseline = _up2_find_field(input.state, spec.id).value
        binding.trigger === :initial && baseline isa UP2SymbolValueV1 &&
            baseline.value === binding.trigger ||
            throw(ArgumentError("VNext N03-04 baseline does not match authored initial trigger"))
        return UP2SymbolValueV1(:scheduled)
    elseif spec.id == "N03-05"
        baseline = _up2_find_field(input.state, spec.id).value
        binding.time >= 0 && baseline isa UP2RationalValueV1 &&
            baseline.value == binding.time ||
            throw(ArgumentError("VNext N03-05 baseline does not match authored event time"))
        return UP2RationalValueV1(-Int64(1) // Int64(1))
    end
    throw(ArgumentError("VNext mutation is not a registered N03-04/05 row"))
end

function _up2_mutated_input(input, spec; package=nothing)
    field = _up2_find_field(input.state, spec.id)
    field === nothing && throw(ArgumentError("mutation field is not registered"))
    value = _up2_mutation_value(spec, input; package=package)
    mutated = UP2SemanticFieldV1(field.id, field.field_path, field.source_locator, field.source_type, value)
    fields = Tuple(x.id == field.id ? mutated : x for x in input.state.fields)
    pair = input.state.flux_pair
    rebuild = (lp, rp, ls, rs, u) -> UP2FluxPairV1(pair.pair_id, lp, rp, ls, rs, u,
        pair.interface_ref, pair.left_region, pair.right_region, pair.normal,
        pair.transfer_kind, pair.port_source)
    if spec.class_id === :N05
        pair = spec.mutation_kind === :left_empty ? rebuild("", pair.right_port, pair.left_sign, pair.right_sign, pair.unit) :
            spec.mutation_kind === :right_empty ? rebuild(pair.left_port, "", pair.left_sign, pair.right_sign, pair.unit) :
            spec.mutation_kind === :left_sign_zero ? rebuild(pair.left_port, pair.right_port, 0, pair.right_sign, pair.unit) :
            spec.mutation_kind === :same_sign ? rebuild(pair.left_port, pair.right_port, pair.left_sign, pair.left_sign, pair.unit) :
            rebuild(pair.left_port, pair.right_port, pair.left_sign, pair.right_sign, value.value)
    end
    state = UP2PrecompilerStateV1(fields, pair)
    UP2PrecompilerInputV1(input.candidate_ref, input.g1_ref, input.g2_ref, input.g3_ref,
        input.g1_hash, input.g2_hash, input.g3_hash, input.package_hash,
        input.mission_bounds, state, input.source_manifest_hash, input.package_status,
        input.resolution, input.claim_ceiling)
end

Base.@noinline Base.@nospecializeinfer function _up2_mutated_input(input::UP2VNextPrecompilerInputV1,
        spec::UP2MutationSpecV1; package=nothing, n04_05_context=nothing,
        native_plan=nothing, g1_context=nothing, n07n08_context=nothing,
        n09_context=nothing, native_report=nothing, heat_lift_receipt=nothing,
        identity_package=nothing)
    Base.@nospecialize input spec package n04_05_context native_plan g1_context n07n08_context n09_context native_report heat_lift_receipt identity_package
    if n09_context isa NamedTuple
        native_report === nothing && hasproperty(n09_context, :native_report) &&
            (native_report = n09_context.native_report)
        heat_lift_receipt === nothing && hasproperty(n09_context, :heat_lift_receipt) &&
            (heat_lift_receipt = n09_context.heat_lift_receipt)
    elseif input isa UP2VNextPrecompilerInputV1 && spec.class_id === :N09 &&
            (native_report !== nothing || heat_lift_receipt !== nothing)
        native_report !== nothing && heat_lift_receipt !== nothing &&
            package isa CandidateStatePackageV5NextV2 && native_plan !== nothing ||
            throw(ArgumentError("direct N09 mutation requires its current report, receipt, T1 package, and native plan"))
        ledger_context = _up2_vnext_n04_05_context(package, input.source_binding;
            include_child_design=true, identity_package=identity_package)
        geometry_context = _up2_vnext_g2_geometry_context(package,
            input.source_binding)
        n09_context = _up2_vnext_n09_context(package, input.source_binding,
            geometry_context, native_plan; g3_source_context=ledger_context,
            native_report=native_report, heat_lift_receipt=heat_lift_receipt)
    end
    field = _up2_find_field(input.state, spec.id)
    field === nothing && throw(ArgumentError("mutation field is not registered"))
    value = _up2_mutation_value(spec, input; package=package,
        native_plan=native_plan, n04_05_context=n04_05_context,
        g1_context=g1_context,
        n07n08_context=n07n08_context, n09_context=n09_context,
        native_report=native_report, heat_lift_receipt=heat_lift_receipt,
        identity_package=identity_package)
    _up2_mutated_vnext_input_from_value(input, field, value, spec)
end

Base.@noinline Base.@nospecializeinfer function _up2_mutated_input_after_validation(input::UP2VNextPrecompilerInputV1,
        spec::UP2MutationSpecV1; package=nothing, n04_05_context=nothing,
        native_plan=nothing, g1_context=nothing, n07n08_context=nothing,
        n09_context=nothing, n05_context=nothing, n10_context=nothing,
        native_report=nothing, heat_lift_receipt=nothing)
    Base.@nospecialize input spec package n04_05_context native_plan g1_context n07n08_context n09_context n05_context n10_context native_report heat_lift_receipt
    field = _up2_find_field(input.state, spec.id)
    field === nothing && throw(ArgumentError("mutation field is not registered"))
    value = _up2_mutation_value_after_validation(spec, input; package=package,
        native_plan=native_plan, n04_05_context=n04_05_context,
        g1_context=g1_context, n07n08_context=n07n08_context,
        n09_context=n09_context, n05_context=n05_context,
        n10_context=n10_context)
    _up2_mutated_vnext_input_from_value(input, field, value, spec)
end

Base.@noinline Base.@nospecializeinfer function _up2_mutated_vnext_input_from_value(input::UP2VNextPrecompilerInputV1,
        field::UP2SemanticFieldV1, value::UP2TypedValueV1, spec::UP2MutationSpecV1)
    Base.@nospecialize input field value
    mutated = UP2SemanticFieldV1(field.id, field.field_path, field.source_locator,
        field.source_type, value)
    fields = Tuple(x.id == field.id ? mutated : x for x in input.state.fields)
    pair = input.state.flux_pair
    if spec.class_id === :N05
        pair = UP2FluxPairV1(pair.pair_id,
            spec.id == "N05-01" ? "" : pair.left_port,
            spec.id == "N05-02" ? "" : pair.right_port,
            spec.id == "N05-03" ? 0 : pair.left_sign,
            spec.id == "N05-04" ? pair.left_sign : pair.right_sign,
            spec.id == "N05-05" ? value.value : pair.unit,
            pair.interface_ref, pair.left_region, pair.right_region, pair.normal,
            pair.transfer_kind, pair.port_source)
    end
    state = UP2PrecompilerStateV1(fields, pair)
    UP2VNextPrecompilerInputV1(input.source_binding, input.mission_bounds,
        state, input.field_states;
        provider_bindings=input.provider_bindings)
end

struct UP2ValidationResultV1
    mutation_id::String
    input_hash::Digest256
    mutated_input_hash::Digest256
    status::Symbol
    error_code::Symbol
    error_path::String
    detail::String
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
    evidence_reused::Bool
    result_hash::Digest256
end

semantic_view(x::UP2ValidationResultV1) =
    (mutation_id=x.mutation_id, input_hash=x.input_hash, mutated_input_hash=x.mutated_input_hash,
     status=x.status, error_code=x.error_code, error_path=x.error_path, detail=x.detail,
     compile_calls=x.compile_calls, provider_calls=x.provider_calls, solver_calls=x.solver_calls,
     evidence_reused=x.evidence_reused, result_hash=x.result_hash)

Base.@noinline Base.@nospecializeinfer function _up2_real_classification(input::UP2VNextPrecompilerInputV1,
        mutated::UP2VNextPrecompilerInputV1, spec::UP2MutationSpecV1;
        package=nothing, n04_05_context=nothing, g1_context=nothing,
        n07n08_context=nothing, n09_context=nothing, n05_context=nothing,
        n10_context=nothing)
    Base.@nospecialize input mutated spec package n04_05_context g1_context n07n08_context n09_context n05_context n10_context
    if spec.class_id === :N10 && spec.id in ("N10-04", "N10-05")
        package isa CandidateStatePackageV5NextV2 &&
            n10_context isa NamedTuple && hasproperty(n10_context, :identity_package) ||
            return nothing
        identity_package = n10_context.identity_package
        reason = spec.id == "N10-04" ?
            :current_vnext_t0_t1_component_identity_compatibility_view :
            :current_vnext_t0_t1_fresh_identity_receipt_not_v4_migration
        roles = (:g1_builder, :g1_declaration_source, :g2_builder,
            :g2_declaration_source, :g3_builder, :g3_child_design)
        row = first(state for state in input.field_states if state.field_id == spec.id)
        row.state === :source_present_deferred && row.reason === reason &&
            row.source_pin_roles == roles || return nothing
        baseline = _up2_find_field(input.state, spec.id).value
        semantic_view(baseline) == semantic_view(_up2_vnext_n10_value(spec, n10_context)) ||
            return nothing
        changed = _up2_find_field(mutated.state, spec.id).value
        if spec.id == "N10-04"
            spec.expected_error === :invalid_type || return nothing
            changed isa UP2TextValueV1 &&
                changed.value != identity_package.candidate_hash.value || return nothing
            return (:invalid_type, :fail_closed, spec.detail)
        end
        spec.expected_error === :terminal_deferred &&
            spec.expected_resolution === terminal_deferred || return nothing
        changed isa UP2TextValueV1 &&
            changed.value != identity_package.migration_receipt.candidate_identity_after || return nothing
        return (:terminal_deferred, :terminal_deferred, spec.detail)
    end
    if spec.class_id === :N10 && spec.id in ("N10-01", "N10-02", "N10-03")
        package isa CandidateStatePackageV5NextV2 && n10_context isa NamedTuple ||
            return nothing
        expected_error = spec.id == "N10-01" ? :invalid_type : :terminal_deferred
        spec.mutation_kind === :pending && spec.expected_error === expected_error &&
            spec.expected_resolution === terminal_deferred || return nothing
        ref = spec.id == "N10-01" ? n10_context.contract_refs.g1 :
            spec.id == "N10-02" ? n10_context.contract_refs.g2 :
            n10_context.contract_refs.binding
        ref isa GenomeContractRef || return nothing
        row = first(state for state in input.field_states if state.field_id == spec.id)
        expected_roles = spec.id == "N10-01" ?
            (:g1_builder, :g1_declaration_source) :
            spec.id == "N10-02" ?
            (:g2_builder, :g2_declaration_source) :
            (:g3_builder, :g3_child_design)
        row.state === :source_present_deferred &&
            row.reason === :current_vnext_t1_t0_typed_ref_not_legacy_v5_identity &&
            row.source_pin_roles == expected_roles || return nothing
        baseline = _up2_find_field(input.state, spec.id).value
        semantic_view(baseline) == semantic_view(_up2_vnext_n10_value(spec, n10_context)) || return nothing
        changed = _up2_find_field(mutated.state, spec.id).value
        if spec.id == "N10-01"
            expected_hash = Digest256(ref.schema_hash.value == repeat("0", 64) ?
                repeat("1", 64) : repeat("0", 64))
            changed isa UP2TextValueV1 && changed.value == expected_hash.value &&
                expected_hash != ref.schema_hash || return nothing
            return (:invalid_type, :fail_closed, spec.detail)
        elseif spec.id == "N10-02"
            expected_hash = Digest256(ref.canonicalization_hash.value == repeat("0", 64) ?
                repeat("1", 64) : repeat("0", 64))
            changed isa UP2HashValueV1 && changed.value == expected_hash &&
                expected_hash != ref.canonicalization_hash || return nothing
            return (:terminal_deferred, :terminal_deferred, spec.detail)
        else
            changed isa UP2ContractRefValueV1 || return nothing
            changed_ref = changed.value
            changed_ref.uri == ref.uri * "/up2-binding-ref-mismatch" &&
                changed_ref.version == ref.version &&
                changed_ref.schema_hash == ref.schema_hash &&
                changed_ref.canonicalization_hash == ref.canonicalization_hash &&
                changed_ref.compatibility_profile == ref.compatibility_profile || return nothing
            return (:terminal_deferred, :terminal_deferred, spec.detail)
        end
    end
    if spec.class_id === :N05
        package isa CandidateStatePackageV5NextV2 && n05_context isa NamedTuple || return nothing
        pair = mutated.state.flux_pair
        baseline = n05_context.pair
        pair.port_source === :unverified && baseline.port_source === :unverified &&
            pair.pair_id == baseline.pair_id &&
            pair.interface_ref == baseline.interface_ref &&
            pair.left_region == baseline.left_region &&
            pair.right_region == baseline.right_region &&
            pair.normal == baseline.normal && pair.transfer_kind == baseline.transfer_kind || return nothing
        changed = _up2_find_field(mutated.state, spec.id).value
        if spec.id == "N05-01"
            changed isa UP2TextValueV1 && changed.value == pair.left_port &&
                isempty(pair.left_port) && pair.right_port == baseline.right_port &&
                pair.left_sign == baseline.left_sign && pair.right_sign == baseline.right_sign &&
                pair.unit == baseline.unit || return nothing
        elseif spec.id == "N05-02"
            changed isa UP2TextValueV1 && changed.value == pair.right_port &&
                isempty(pair.right_port) && pair.left_port == baseline.left_port &&
                pair.left_sign == baseline.left_sign && pair.right_sign == baseline.right_sign &&
                pair.unit == baseline.unit || return nothing
        elseif spec.id == "N05-03"
            changed isa UP2IntegerValueV1 && changed.value == pair.left_sign == 0 &&
                pair.left_port == baseline.left_port && pair.right_port == baseline.right_port &&
                pair.left_sign == 0 && pair.right_sign == baseline.right_sign &&
                pair.unit == baseline.unit || return nothing
        elseif spec.id == "N05-04"
            changed isa UP2IntegerValueV1 && changed.value == pair.right_sign == baseline.left_sign &&
                pair.left_port == baseline.left_port && pair.right_port == baseline.right_port &&
                pair.left_sign == baseline.left_sign && pair.unit == baseline.unit || return nothing
        elseif spec.id == "N05-05"
            changed isa UP2UnitValueV1 && changed.value == UnitSignature((1,0,0,0,0,0,0)) &&
                pair.unit == changed.value && pair.left_port == baseline.left_port &&
                pair.right_port == baseline.right_port && pair.left_sign == baseline.left_sign &&
                pair.right_sign == baseline.right_sign || return nothing
        else
            return nothing
        end
        return (:invalid_closure, :fail_closed, spec.detail)
    end
    if spec.class_id === :N09 && spec.id in
            ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05")
        package isa CandidateStatePackageV5NextV2 && n09_context isa NamedTuple &&
            haskey(n09_context.matches, spec.id) ||
            throw(ArgumentError("VNext $(spec.id) classification requires its bound native service context"))
        row = first(x for x in input.field_states if x.field_id == spec.id)
        expected_reason = spec.id == "N09-01" ?
            :candidate_design_g1_grad_native_gridap_service_match :
            spec.id == "N09-04" ?
            :candidate_design_g1_g2_scalar_heat_lift_provider_match :
            spec.id == "N09-02" ?
            :candidate_design_g2_profile_native_gridap_service_match :
            spec.id == "N09-03" ?
            :candidate_design_g2_exterior_native_gridap_service_match :
            :candidate_design_g3_control_sampled_service_match
        expected_roles = spec.id == "N09-01" ?
            (:g1_builder, :g1_declaration_source) :
            spec.id in ("N09-02", "N09-03") ?
            (:g2_builder, :g2_declaration_source) :
            spec.id == "N09-04" ?
            (:g1_builder, :g1_declaration_source, :g2_builder,
             :g2_declaration_source, :g3_builder, :g3_child_design) :
            (:g3_builder, :g3_child_design)
        row.state === :source_present_deferred && row.reason === expected_reason &&
            row.source_pin_roles == expected_roles &&
            input.provider_bindings == n09_context.provider_bindings || return nothing
        baseline = _up2_find_field(input.state, spec.id).value
        changed = _up2_find_field(mutated.state, spec.id).value
        baseline isa UP2SymbolValueV1 &&
            baseline.value === n09_context.matches[spec.id] === :unique_match ||
            return nothing
        mutated_match = _up2_vnext_n09_mutated_match(n09_context,
            spec.id)
        Symbol(string(mutated_match.status)) === :out_of_domain &&
            changed isa UP2SymbolValueV1 &&
            changed.value === Symbol(string(mutated_match.status)) ||
            return nothing
        return (:provider_match, :terminal_deferred, spec.detail)
    end
    if spec.id in ("N03-01", "N03-02")
        package === nothing &&
            throw(ArgumentError("VNext $(spec.id) classification requires its bound T1 package"))
        g1 = g1_context === nothing ?
            _up2_vnext_g1_operator_type_context(package, input.source_binding) : g1_context
        row = first(state for state in input.field_states if state.field_id == spec.id)
        row.state === :source_present_deferred &&
            row.reason === :candidate_design_g1_diffusion_time_contract_only &&
            row.source_pin_roles == (:g1_builder, :g1_declaration_source) || return nothing
        baseline = _up2_find_field(input.state, spec.id).value
        changed = _up2_find_field(mutated.state, spec.id).value
        expected_baseline = _up2_vnext_n0102_source_value(spec, g1, nothing)
        semantic_view(baseline) == semantic_view(expected_baseline) || return nothing
        if spec.id == "N03-01"
            baseline isa UP2SymbolValueV1 && baseline.value === :static_time &&
                changed isa UP2SymbolValueV1 && changed.value === :algebraic_time ||
                return nothing
        else
            baseline isa UP2IntegerValueV1 && baseline.value == 0 &&
                changed isa UP2IntegerValueV1 && changed.value < 0 || return nothing
        end
        return (:invalid_type, :fail_closed, spec.detail)
    end
    if spec.id == "N03-03"
        package === nothing &&
            throw(ArgumentError("VNext N03-03 classification requires its bound T1 package"))
        g1 = g1_context === nothing ?
            _up2_vnext_g1_operator_type_context(package, input.source_binding) : g1_context
        haskey(g1.values, "N03-03") || return nothing
        row = first(state for state in input.field_states if state.field_id == spec.id)
        row.state === :source_present_deferred &&
            row.reason === :candidate_design_g1_operator_temporal_whitelist_contract_only &&
            row.source_pin_roles == (:g1_builder, :g1_declaration_source) || return nothing
        baseline = _up2_find_field(input.state, spec.id).value
        changed = _up2_find_field(mutated.state, spec.id).value
        expected = UP2TupleValueV1(g1.values["N03-03"], :timekind_v1)
        baseline isa UP2TupleValueV1 && baseline.element_type === :timekind_v1 &&
            semantic_view(baseline) == semantic_view(expected) || return nothing
        equation_kind = g1.values["N03-01"]
        equation_kind in baseline.values || return nothing
        expected_mutation = UP2TupleValueV1(
            Tuple(kind for kind in baseline.values if kind !== equation_kind),
            :timekind_v1)
        semantic_view(changed) == semantic_view(expected_mutation) &&
            !(equation_kind in changed.values) || return nothing
        return (:invalid_type, :fail_closed, spec.detail)
    end
    if spec.id in ("N01-01", "N01-02", "N01-03", "N01-04", "N01-05",
            "N02-01", "N02-02", "N02-03", "N02-04", "N02-05")
        package === nothing &&
            throw(ArgumentError("VNext $(spec.id) classification requires its bound T1 package"))
        g3_needed = spec.id in ("N02-04", "N02-05")
        g3 = n04_05_context === nothing && g3_needed ?
            _up2_vnext_n04_05_context(package, input.source_binding) : n04_05_context
        g1_needed = spec.id in ("N01-01", "N01-02", "N02-01", "N02-02")
        g1 = g1_context === nothing && g1_needed ?
            _up2_vnext_g1_operator_type_context(package, input.source_binding) : g1_context
        cross_state_needed = spec.id in ("N01-03", "N01-05", "N02-03")
        g2_needed = spec.id == "N01-04" || cross_state_needed
        g2 = g2_needed ? (n07n08_context === nothing ?
            _up2_vnext_g2_geometry_context(package, input.source_binding) : n07n08_context) :
            n07n08_context
        row = first(state for state in input.field_states if state.field_id == spec.id)
        expected_reason = cross_state_needed ?
            :candidate_design_g1_g2_state_field_binding_contract_only :
            spec.id == "N01-04" ?
            :candidate_design_g2_profile_contract_only :
            g3_needed ? :candidate_design_g3_ledger_unit_design_only :
            :candidate_design_g1_operator_type_contract_only
        expected_roles = cross_state_needed ?
            (:g1_builder, :g1_declaration_source, :g2_builder, :g2_declaration_source) :
            spec.id == "N01-04" ?
            (:g2_builder, :g2_declaration_source) :
            g3_needed ? (:g3_builder, :g3_child_design) :
            (:g1_builder, :g1_declaration_source)
        row.state === :source_present_deferred && row.reason === expected_reason &&
            row.source_pin_roles == expected_roles || return nothing
        baseline = _up2_find_field(input.state, spec.id).value
        changed = _up2_find_field(mutated.state, spec.id).value
        expected_baseline = _up2_vnext_n0102_source_value(spec, g1, g2;
            ledger_context=g3)
        semantic_view(baseline) == semantic_view(expected_baseline) || return nothing
        semantic_view(changed) == semantic_view(
            _up2_vnext_n0102_mutated_value(spec, baseline)) || return nothing
        source_value = expected_baseline.value
        if spec.id in ("N01-01", "N01-02", "N01-03")
            changed isa UP2IntegerValueV1 && changed.value != source_value || return nothing
        elseif spec.id == "N01-05"
            changed isa UP2SymbolValueV1 && changed.value in (:scalar, :vector3) &&
                changed.value != source_value || return nothing
        elseif spec.id == "N02-03"
            changed isa UP2TextValueV1 && !isempty(changed.value) &&
                changed.value != source_value || return nothing
        elseif spec.id == "N01-04"
            source_value == 3 && changed isa UP2IntegerValueV1 &&
                changed.value > 0 && changed.value != source_value || return nothing
        elseif spec.id in ("N02-04", "N02-05")
            changed isa UP2UnitValueV1 || return nothing
            source_exponents = source_value.exponents
            changed_exponents = changed.value.exponents
            changed_exponents[1] == source_exponents[1] + (1 // 1) &&
                all(changed_exponents[i] == source_exponents[i] for i in 2:7) ||
                return nothing
        else
            changed isa UP2UnitValueV1 && changed.value != source_value || return nothing
        end
        return (:invalid_type, :fail_closed, spec.detail)
    end
    if spec.class_id in (:N07, :N08)
        package === nothing &&
            throw(ArgumentError("VNext $(spec.id) classification requires its bound T1 package"))
        context = n07n08_context === nothing ?
            _up2_vnext_g2_geometry_context(package, input.source_binding) : n07n08_context
        haskey(context.values, spec.id) || return nothing
        row = first(x for x in input.field_states if x.field_id == spec.id)
        expected_reason = spec.id == "N08-04" ?
            :candidate_design_g2_q1_h1_degree1_basis_contract_only :
            :candidate_design_g2_geometry_contract_only
        row.state === :source_present_deferred &&
            row.reason === expected_reason &&
            row.source_pin_roles == (:g2_builder, :g2_declaration_source) || return nothing
        original = _up2_find_field(input.state, spec.id).value
        changed = _up2_find_field(mutated.state, spec.id).value
        semantic_view(original) == semantic_view(
            _up2_vnext_g2_up2_value(spec, context.values[spec.id])) || return nothing
        semantic_view(changed) == semantic_view(
            _up2_vnext_n07n08_value(spec, input, context)) || return nothing
        valid = if spec.id == "N07-01"
            lo = changed.values
            hi = context.values["N07-02"]
            all(lo[i] < hi[i] && context.values["N07-01"][i] <= lo[i] <= hi[i]
                for i in 1:3)
        elseif spec.id == "N07-02"
            lo = context.values["N07-01"]
            hi = changed.values
            all(lo[i] < hi[i] && lo[i] <= hi[i] <= context.values["N07-02"][i]
                for i in 1:3)
        elseif spec.id == "N07-03"
            changed.values isa Tuple &&
                all(face -> face in changed.values, context.values["N07-03"])
        elseif spec.id == "N07-05"
            changed.value !== :none_declared
        elseif spec.id == "N08-02"
            changed.value in (:identity, :declared_map)
        elseif spec.id == "N08-03"
            all(x -> x >= 1, changed.values)
        elseif spec.id == "N08-04"
            changed.value === :linear
        elseif spec.id == "N07-04"
            patch = getproperty(context, :boundary_patch_context)
            changed isa UP2TupleValueV1 && changed.element_type === :rational &&
                changed.values isa NTuple{2,Rational{Int64}} || return nothing
            all(i -> patch.lower[i] <= changed.values[i] < patch.upper[i], 1:2)
        elseif spec.id == "N08-01"
            changed isa UP2TupleValueV1 && changed.element_type === :symbol &&
                changed.values == (:x, :y, :q) || return nothing
            length(unique(changed.values)) == 3 &&
                all(axis -> axis in (:x, :y, :z), changed.values)
        elseif spec.id == "N08-05"
            changed isa UP2TupleValueV1 && changed.element_type === :qualified_ref &&
                length(changed.values) == 2 &&
                length(unique(changed.values)) == 2
        else
            false
        end
        valid && return nothing
        return (:invalid_boundary, :fail_closed, spec.detail)
    end
    if spec.id in ("N06-01", "N06-05")
        package isa CandidateStatePackageV5NextV2 &&
            spec.class_id === :N06 && spec.mutation_kind === :pending &&
            spec.expected_error === :invalid_closure &&
            spec.expected_resolution === terminal_deferred || return nothing
        context = n04_05_context === nothing ?
            _up2_vnext_n04_05_context(package, input.source_binding;
                include_child_design=true) : n04_05_context
        source = _up2_vnext_n06_resource_network(context, input.source_binding)
        row = first(x for x in input.field_states if x.field_id == spec.id)
        row.state === :source_present_deferred &&
            row.reason === :candidate_design_g3_typed_resource_network_contract_only &&
            row.source_pin_roles == (:g3_builder, :g3_child_design) || return nothing
        baseline = _up2_find_field(input.state, spec.id).value
        changed = _up2_find_field(mutated.state, spec.id).value
        network = source.network
        if spec.id == "N06-01"
            baseline isa UP2TupleValueV1 &&
                baseline.element_type === :G3ResourcePortV2 &&
                canonical_hash(baseline.values) == canonical_hash(network.resource_ports) ||
                return nothing
            target = source.effort_port
            expected_ports = Tuple(port for port in network.resource_ports
                if port.port_id != target.port_id)
            changed isa UP2TupleValueV1 &&
                changed.element_type === :G3ResourcePortV2 &&
                canonical_hash(changed.values) == canonical_hash(expected_ports) ||
                return nothing
            length(expected_ports) == length(network.resource_ports) - 1 &&
                any(component -> target.port_id in component.resource_port_ids,
                    network.components) || return nothing
            mutated_network = G3ResourceNetworkV2(network.components,
                changed.values, network.accounts, network.entries, network.closures)
            errors = g3_validate_resource_network(mutated_network;
                effort_ports_without_ledger=source.typed.effort_ports_without_ledger)
            ("missing_required_resource_port:" * String(target.kind)) in errors ||
                return nothing
        else
            target = source.effort_port
            network.resource_ports[1].port_id == target.port_id &&
                baseline isa UP2SymbolValueV1 &&
                baseline.value === target.kind || return nothing
            kind = _up2_vnext_n06_mismatched_kind(target)
            changed isa UP2SymbolValueV1 && changed.value === kind || return nothing
            expected_ports = Tuple(port.port_id == target.port_id ?
                G3ResourcePortV2(port.port_id, kind, port.direction, port.unit,
                    port.account_id) : port for port in network.resource_ports)
            mutated_network = G3ResourceNetworkV2(network.components,
                expected_ports, network.accounts, network.entries, network.closures)
            errors = g3_validate_resource_network(mutated_network;
                effort_ports_without_ledger=source.typed.effort_ports_without_ledger)
            ("resource_unit_mismatch:" * target.port_id) in errors ||
                return nothing
        end
        return (:invalid_closure, :fail_closed, spec.detail)
    end
    if spec.id == "N06-03"
        package isa CandidateStatePackageV5NextV2 &&
            spec.class_id === :N06 && spec.expected_error === :invalid_closure &&
            spec.mutation_kind === :pending || return nothing
        context = n04_05_context === nothing ?
            _up2_vnext_n04_05_context(package, input.source_binding;
                include_child_design=true) : n04_05_context
        selected = _up2_vnext_n06_03_flow_link(context, input.source_binding)
        row = first(x for x in input.field_states if x.field_id == spec.id)
        row.state === :source_present_deferred &&
            row.reason === :candidate_design_g3_control_flow_link_design_only &&
            row.source_pin_roles == (:g3_builder, :g3_child_design) || return nothing
        baseline = _up2_find_field(input.state, spec.id).value
        changed = _up2_find_field(mutated.state, spec.id).value
        baseline isa UP2TextValueV1 &&
            baseline.value == selected.link.resource_port_id &&
            changed isa UP2TextValueV1 && changed.value != baseline.value &&
            !(changed.value in Tuple(port.port_id for port in
                context.typed_ledger_context.resource_network.resource_ports)) || return nothing
        return (:invalid_closure, :fail_closed, "control_link_resource_port_missing")
    end
    if spec.id == "N06-02"
        package === nothing && throw(ArgumentError("VNext N06-02 classification requires its bound T1 package"))
        context = n04_05_context === nothing ?
            _up2_vnext_n04_05_context(package, input.source_binding) : n04_05_context
        verified = _up2_vnext_n06_04_closure(context, input.source_binding)
        row = first(x for x in input.field_states if x.field_id == spec.id)
        row.state === :source_present_deferred &&
            row.reason === :candidate_design_g3_ledger_entries_design_only &&
            row.source_pin_roles == (:g3_builder, :g3_child_design) || return nothing
        baseline = _up2_find_field(input.state, spec.id).value
        changed = _up2_find_field(mutated.state, spec.id).value
        baseline isa UP2TupleValueV1 && baseline.element_type === :g3_ledger_entry_v2 &&
            canonical_hash(baseline.values) == canonical_hash(verified.entries) || return nothing
        heat_rows = Tuple(e for e in verified.entries if e.effect === :heat_rejection)
        length(heat_rows) == 1 || return nothing
        heat_entry = only(heat_rows)
        heat_entry.account_id in verified.closure.account_ids || return nothing
        expected_entries = Tuple(e for e in verified.entries if e.entry_id != heat_entry.entry_id)
        changed isa UP2TupleValueV1 && changed.element_type === :g3_ledger_entry_v2 &&
            canonical_hash(changed.values) == canonical_hash(expected_entries) || return nothing
        actual_balance = sum(e.coefficient for e in changed.values
            if e.account_id in verified.closure.account_ids)
        actual_balance != verified.closure.expected_balance || return nothing
        return (:invalid_closure, :fail_closed, spec.detail)
    end
    if spec.id == "N06-04"
        package === nothing &&
            throw(ArgumentError("VNext N06-04 classification requires its bound T1 package"))
        context = n04_05_context === nothing ?
            _up2_vnext_n04_05_context(package, input.source_binding) : n04_05_context
        verified = _up2_vnext_n06_04_closure(context, input.source_binding)
        row = first(state for state in input.field_states if state.field_id == spec.id)
        row.state === :source_present_deferred &&
            row.reason === :candidate_design_g3_closure_balance_design_only &&
            row.source_pin_roles == (:g3_builder, :g3_child_design) || return nothing
        baseline = _up2_find_field(input.state, spec.id).value
        changed = _up2_find_field(mutated.state, spec.id).value
        baseline isa UP2RationalValueV1 &&
            baseline.value == verified.closure.expected_balance == verified.actual_balance &&
            changed isa UP2RationalValueV1 &&
            changed.value == baseline.value + (Int64(1) // Int64(1)) &&
            changed.value != verified.actual_balance || return nothing
        return (:invalid_closure, :fail_closed, spec.detail)
    end
    if spec.id in ("N04-01", "N04-03")
        package === nothing &&
            throw(ArgumentError("VNext $(spec.id) classification requires its bound T1 package"))
        context = n04_05_context === nothing ?
            _up2_vnext_n04_05_context(package, input.source_binding) : n04_05_context
        typed = context.typed_ledger_context
        typed isa NamedTuple && typed.authority_scope === :local_source_data ||
            return nothing
        expected_reason = spec.id == "N04-01" ?
            :candidate_design_ledger_owner_design_only :
            :candidate_design_ledger_entry_account_design_only
        row = first(x for x in input.field_states if x.field_id == spec.id)
        row.state === :source_present_deferred && row.reason === expected_reason &&
            row.source_pin_roles == (:g3_builder, :g3_child_design) || return nothing
        baseline = _up2_find_field(input.state, spec.id).value
        changed = _up2_find_field(mutated.state, spec.id).value
        if spec.id == "N04-01"
            spec.mutation_kind === :owner_crosswalk_mismatch &&
                baseline isa UP2TextValueV1 && baseline.value == typed.owner &&
                changed isa UP2TextValueV1 && !isempty(changed.value) &&
                changed.value != typed.owner || return nothing
            return (:invalid_closure, :fail_closed, "owner_crosswalk_mismatch")
        end
        spec.mutation_kind === :unknown_account_ref &&
            baseline isa UP2TextValueV1 && baseline.value == typed.entry_account_id &&
            changed isa UP2TextValueV1 &&
            !(changed.value in typed.account_ids) || return nothing
        return (:invalid_closure, :fail_closed, "entry_account_ref_missing")
    end
    if spec.id in ("N04-02", "N04-04")
        package === nothing &&
            throw(ArgumentError("VNext $(spec.id) classification requires its bound T1 package"))
        context = n04_05_context === nothing ?
            _up2_vnext_n04_05_context(package, input.source_binding) : n04_05_context
        context.authority_scope === :local_source_data || return nothing
        baseline = _up2_find_field(input.state, spec.id).value
        changed = _up2_find_field(mutated.state, spec.id).value
        if spec.id == "N04-02"
            baseline isa UP2TupleValueV1 && baseline.element_type === :string &&
                baseline.values == context.closure_account_ids &&
                length(unique(baseline.values)) == length(baseline.values) &&
                all(id -> id in context.account_ids, baseline.values) || return nothing
            changed isa UP2TupleValueV1 && changed.element_type === :string &&
                changed.values == (String(first(baseline.values)),
                    String(first(baseline.values))) || return nothing
            return (:invalid_closure, :fail_closed,
                "duplicate_or_unresolved_closure_account")
        end
        baseline isa UP2TextValueV1 &&
            baseline.value == context.source_entry_component_id &&
            context.source_entry_effect === :source &&
            context.source_component_kind === :source_component || return nothing
        changed isa UP2TextValueV1 &&
            changed.value == context.passive_component_id &&
            context.passive_component_kind === :passive_component || return nothing
        return (:invalid_closure, :fail_closed,
            "passive_component_cannot_source")
    elseif spec.id == "N04-05"
        package === nothing &&
            throw(ArgumentError("VNext N04-05 classification requires its bound T1 package"))
        context = n04_05_context === nothing ?
            _up2_vnext_n04_05_context(package, input.source_binding) : n04_05_context
        context.authority_scope === :local_source_data &&
            context.authority_gap == "candidate_authored_g3_ledger_capacity_is_design_only" ||
            return nothing
        baseline = _up2_find_field(input.state, spec.id).value
        changed = _up2_find_field(mutated.state, spec.id).value
        expected_sign = context.effect === :source ? 1 :
            context.effect in (:load, :return, :heat_rejection) ? -1 : 0
        expected_sign != 0 && context.port_role === :field &&
            context.port_direction === :in &&
            baseline isa UP2RationalValueV1 &&
            baseline.value == context.coefficient && baseline.value != 0 // 1 &&
            abs(baseline.value) <= context.capacity &&
            sign(baseline.value) == expected_sign &&
            changed isa UP2RationalValueV1 && changed.value != 0 // 1 &&
            sign(changed.value) == sign(baseline.value) &&
            changed.value == sign(baseline.value) *
                (context.capacity + (1 // 1)) &&
            abs(changed.value) > context.capacity ||
            return nothing
        return (:invalid_closure, :fail_closed,
            "component_capacity_exceeded")
    end
    binding = input.source_binding
    original = _up2_find_field(input.state, spec.id).value
    changed = _up2_find_field(mutated.state, spec.id).value
    if spec.id == "N03-04"
        original isa UP2SymbolValueV1 && original.value === binding.trigger || return nothing
        changed isa UP2SymbolValueV1 &&
            changed.value in (:initial, :scheduled, :fault, :threshold) || return nothing
        changed.value === binding.trigger && return nothing
        return (:invalid_type, :fail_closed,
            "event_trigger_policy_mismatch: mutated G3 trigger differs from authored initial trigger")
    elseif spec.id == "N03-05"
        original isa UP2RationalValueV1 && original.value == binding.time &&
            original.value >= 0 || return nothing
        changed isa UP2RationalValueV1 && changed.value < 0 || return nothing
        return (:invalid_type, :fail_closed,
            "event_time_negative: mutated G3 event time must be nonnegative")
    end
    nothing
end

function _up2_real_classification(input, mutated, spec; package=nothing)
    if spec.class_id in (:N07, :N08)
        package isa CandidateStatePackageV5 ||
            throw(ArgumentError("$(spec.id) classification requires its bound actual A package"))
        projection = _up2_n07n08_a_projection(input, package)
        q = _n07n08_mutate(projection, _up2_n07n08_spec(spec))
        changed = _up2_find_field(mutated.state, spec.id)
        semantic_view(changed.value) == semantic_view(
            _up2_n07n08_field_value(q, spec.id)) || return nothing
        classified = _n07n08_classify(projection, q, _up2_n07n08_spec(spec))
        classified === nothing && return nothing
        return (first(classified), last(classified), spec.detail)
    end
    spec.class_id in (:N01, :N02, :N03, :N04, :N05) || return nothing
    if spec.class_id === :N05
        p = mutated.state.flux_pair
        p.port_source == :authoritative || return nothing
        if spec.mutation_kind === :unit_mismatch
            p.unit == _up2_find_field(input.state, "N05-05").value.value && return nothing
            return (:invalid_closure, :fail_closed)
        end
        up2_flux_pair_valid(p) && return nothing
        return (:invalid_closure, :fail_closed)
    end
    if spec.id == "N04-02" && spec.mutation_kind === :duplicate_account_ids
        field = _up2_find_field(mutated.state, spec.id)
        baseline = _up2_find_field(input.state, spec.id).value
        baseline isa UP2TupleValueV1 && baseline.element_type === :string && !isempty(baseline.values) || return nothing
        field.value isa UP2TupleValueV1 && field.value.element_type === :string || return nothing
        all(x -> x isa String, baseline.values) && all(x -> x isa String, field.value.values) || return nothing
        length(unique(baseline.values)) == length(baseline.values) || return nothing
        field.value.values == (String(first(baseline.values)), String(first(baseline.values))) || return nothing
        return (:invalid_closure, :fail_closed)
    end
    field = _up2_find_field(mutated.state, spec.id)
    if spec.class_id === :N03
        equation_kind = _up2_find_field(input.state, "N03-01").value
        equation_order = _up2_find_field(input.state, "N03-02").value
        operator_kinds = _up2_find_field(input.state, "N03-03").value
        equation_kind isa UP2SymbolValueV1 && equation_order isa UP2IntegerValueV1 || return nothing
        operator_kinds isa UP2TupleValueV1 && operator_kinds.element_type === :timekind_v1 || return nothing
        equation_kind.value in operator_kinds.values || return nothing
        if spec.id == "N03-01"
            field.value isa UP2SymbolValueV1 && !(field.value.value in operator_kinds.values) || return nothing
            return (:invalid_type, :fail_closed)
        elseif spec.id == "N03-02"
            equation_order.value >= 0 || return nothing
            field.value isa UP2IntegerValueV1 && field.value.value < 0 || return nothing
            return (:invalid_type, :fail_closed)
        elseif spec.id == "N03-03"
            field.value isa UP2TupleValueV1 && field.value.element_type === :timekind_v1 || return nothing
            equation_kind.value in field.value.values && return nothing
            return (:invalid_type, :fail_closed)
        end
    end
    if spec.id in ("N01-01", "N01-02", "N01-03")
        related = Tuple(_up2_find_field(mutated.state, id).value for id in ("N01-01", "N01-02", "N01-03"))
        field.value isa UP2IntegerValueV1 && field.value.value >= 0 &&
            all(x -> x isa UP2IntegerValueV1 && x.value == field.value.value, related) && return nothing
        return (:invalid_type, :fail_closed)
    elseif spec.id == "N01-04"
        field.value isa UP2IntegerValueV1 && field.value.value == 3 && return nothing
        return (:invalid_type, :fail_closed)
    elseif spec.id == "N01-05"
        field.value isa UP2SymbolValueV1 && field.value.value in (:scalar, :vector3) && return nothing
        return (:invalid_type, :fail_closed)
    elseif spec.id in ("N02-01", "N02-02", "N02-04", "N02-05")
        baseline = _up2_find_field(input.state, spec.id).value
        field.value isa UP2UnitValueV1 && baseline isa UP2UnitValueV1 && field.value.value == baseline.value && return nothing
        return (:invalid_type, :fail_closed)
    elseif spec.id == "N02-03"
        field.value isa UP2TextValueV1 && field.value.value == input.mission_bounds.unit && return nothing
        return (:invalid_type, :fail_closed)
    end
    nothing
end

function up2_validate_mutation(input::UP2PrecompilerInputV1, spec::UP2MutationSpecV1;
        package=nothing, counter=UP2InvocationCounterV1())
    up2_validate_input(input)
    frozen = up2_spec_for_id(spec.id)
    (frozen.field_path == spec.field_path && frozen.source_locator == spec.source_locator &&
        frozen.mutation_kind == spec.mutation_kind) || throw(ArgumentError("mutation metadata is not frozen"))
    frozen.class_id in (:N07, :N08) && package === nothing &&
        throw(ArgumentError("$(frozen.id) mutation requires its bound actual A package"))
    mutated = _up2_mutated_input(input, frozen; package=package)
    classified = _up2_real_classification(input, mutated, frozen; package=package)
    classified === nothing && throw(ArgumentError("semantic gap pending for $(frozen.id); no expected label used"))
    code, status = classified[1], classified[2]
    detail = length(classified) >= 3 ? classified[3] : frozen.detail
    result_hash = canonical_hash((mutation_id=frozen.id, input_hash=input.input_hash,
        mutated_input_hash=mutated.input_hash, error_code=code, error_path=frozen.field_path,
        detail=detail, compile_calls=counter.compile_calls,
        provider_calls=counter.provider_calls, solver_calls=counter.solver_calls,
        evidence_reused=false, status=status, scope=:schema_validation_only))
    UP2ValidationResultV1(frozen.id, input.input_hash, mutated.input_hash, status, code,
        frozen.field_path, detail, counter.compile_calls, counter.provider_calls,
        counter.solver_calls, false, result_hash)
end

Base.@noinline Base.@nospecializeinfer function up2_validate_mutation(input::UP2VNextPrecompilerInputV1,
        spec::UP2MutationSpecV1; package=nothing,
        native_plan=nothing, native_report=nothing, heat_lift_receipt=nothing,
        identity_package=nothing, counter=UP2InvocationCounterV1(), archive=nothing,
        available_route_ids=nothing)
    Base.@nospecialize input spec package native_plan native_report heat_lift_receipt identity_package counter archive
    frozen = up2_spec_for_id(spec.id)
    n03_mutation = frozen.class_id === :N03 &&
        frozen.id in ("N03-01", "N03-02", "N03-03", "N03-04", "N03-05")
    n03_g1_mutation = frozen.id in ("N03-01", "N03-02", "N03-03") &&
        frozen.class_id === :N03
    n04_02_04_mutation = frozen.class_id === :N04 &&
        frozen.id in ("N04-02", "N04-04")
    n04_05_mutation = frozen.class_id === :N04 && frozen.id === "N04-05"
    n06_02_mutation = frozen.class_id === :N06 && frozen.id === "N06-02"
    n06_03_mutation = frozen.class_id === :N06 && frozen.id === "N06-03"
    n06_04_mutation = frozen.class_id === :N06 && frozen.id === "N06-04"
    n06_01_05_mutation = frozen.class_id === :N06 &&
        frozen.id in ("N06-01", "N06-05")
    n04_01_03_mutation = frozen.class_id === :N04 &&
        frozen.id in ("N04-01", "N04-03")
    n05_mutation = frozen.class_id === :N05 &&
        frozen.id in ("N05-01", "N05-02", "N05-03", "N05-04", "N05-05")
    n09_mutation = frozen.class_id === :N09 &&
        frozen.id in ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05")
    n10_mutation = frozen.class_id === :N10 &&
        frozen.id in ("N10-01", "N10-02", "N10-03", "N10-04", "N10-05")
    n0102_mutation = frozen.id in
        ("N01-01", "N01-02", "N01-03", "N01-04", "N01-05",
         "N02-01", "N02-02", "N02-03", "N02-04", "N02-05") &&
        frozen.class_id in (:N01, :N02)
    (frozen.field_path == spec.field_path &&
        frozen.source_locator == spec.source_locator &&
        frozen.mutation_kind == spec.mutation_kind &&
        (n0102_mutation || n03_mutation || n04_01_03_mutation ||
            n04_02_04_mutation || n04_05_mutation || n06_02_mutation ||
            n06_03_mutation || n06_04_mutation || n06_01_05_mutation || n05_mutation || n10_mutation ||
            frozen.class_id in (:N07, :N08) || n09_mutation)) ||
        throw(ArgumentError("VNext mutation metadata is not frozen"))
    n07n08_mutation = frozen.class_id in (:N07, :N08)
    n01_04_mutation = n0102_mutation && frozen.id === "N01-04"
    n01_g2_mutation = n0102_mutation &&
        frozen.id in ("N01-03", "N01-04", "N01-05", "N02-03")
    (n0102_mutation || n03_g1_mutation || n04_01_03_mutation || n04_02_04_mutation ||
        n04_05_mutation || n06_02_mutation || n06_03_mutation || n06_04_mutation ||
        n06_01_05_mutation || n05_mutation || n07n08_mutation || n09_mutation || n10_mutation) && package === nothing &&
        throw(ArgumentError("VNext candidate-design mutation requires its bound T1 package"))
    n09_mutation && native_plan === nothing &&
        throw(ArgumentError("VNext $(frozen.id) mutation requires its current native service plan"))
    frozen.id in ("N10-04", "N10-05") && identity_package === nothing &&
        throw(ArgumentError("VNext $(frozen.id) mutation requires its actual current-source V5 identity package"))
    mutation_ledger_context = n09_mutation ?
        _up2_vnext_n04_05_context(package, input.source_binding;
            include_child_design=true, identity_package=identity_package) : nothing
    mutation_geometry_context = n09_mutation ?
        _up2_vnext_g2_geometry_context(package, input.source_binding) : nothing
    mutation_n09_built = n09_mutation ? _up2_vnext_n09_context_with_g1(package,
        input.source_binding, mutation_geometry_context, native_plan;
        g3_source_context=mutation_ledger_context,
        native_report=native_report, heat_lift_receipt=heat_lift_receipt,
        available_route_ids=available_route_ids) : nothing
    n09_context = n09_mutation ? mutation_n09_built.n09_context : nothing
    supplied_n09_contexts = n09_mutation ?
        (n09_context=mutation_n09_built.n09_context,
         ledger_context=mutation_ledger_context,
         geometry_context=mutation_geometry_context,
         g1_context=mutation_n09_built.g1_context,
         native_report=native_report, heat_lift_receipt=heat_lift_receipt) : nothing
    validated_n09_contexts = _up2_validate_vnext_input_with_context(input,
        package, native_plan, supplied_n09_contexts;
        native_report=native_report, heat_lift_receipt=heat_lift_receipt,
        identity_package=identity_package, available_route_ids=available_route_ids)
    validated_n09_contexts === nothing || (n09_context = n09_mutation ?
        validated_n09_contexts.n09_context : n09_context)
    if available_route_ids !== nothing && n09_mutation &&
            (n09_context === nothing ||
             get(n09_context.matches, frozen.id, nothing) !== :unique_match)
        status = :terminal_deferred
        code = :provider_match
        detail = n09_context !== nothing &&
            get(n09_context.matches, frozen.id, nothing) === :no_match ?
            "provider_availability_gap; mutation not executed" :
            "source_evidence_absent; mutation not executed"
        result_hash = canonical_hash((mutation_id=frozen.id,
            input_hash=input.input_hash, mutated_input_hash=input.input_hash,
            error_code=code, error_path=frozen.field_path, detail=detail,
            availability_route_ids=available_route_ids,
            provider_context_hash=n09_context === nothing ? nothing :
                canonical_hash(n09_context.provider_bindings),
            compile_calls=counter.compile_calls, provider_calls=counter.provider_calls,
            solver_calls=counter.solver_calls, evidence_reused=false,
            status=status, scope=:schema_validation_only))
        return UP2ValidationResultV1(frozen.id, input.input_hash,
            input.input_hash, status, code, frozen.field_path, detail,
            counter.compile_calls, counter.provider_calls, counter.solver_calls,
            false, result_hash)
    end
    n05_context = validated_n09_contexts !== nothing &&
        hasproperty(validated_n09_contexts, :n05_context) ?
        validated_n09_contexts.n05_context : nothing
    n10_context = validated_n09_contexts !== nothing &&
        hasproperty(validated_n09_contexts, :n10_context) ?
        validated_n09_contexts.n10_context : nothing
    g1_context_needed = frozen.id in
        ("N01-01", "N01-02", "N02-01", "N02-02", "N03-01", "N03-02", "N03-03")
    g1_context = g1_context_needed ?
        (validated_n09_contexts === nothing ?
            _up2_vnext_g1_operator_type_context(package, input.source_binding) :
            validated_n09_contexts.g1_context) : nothing
    # Reuse only the ledger context freshly rebuilt by this validation call;
    # otherwise retain the original direct rebuild path.
    validated_ledger_context = if validated_n09_contexts !== nothing &&
            hasproperty(validated_n09_contexts, :ledger_context)
        candidate = validated_n09_contexts.ledger_context
        hasproperty(candidate, :rebuilt_child_design) &&
            hasproperty(candidate, :package_hash) &&
            hasproperty(candidate, :n03_projection_hash) &&
            candidate.package_hash == input.source_binding.package_hash &&
            candidate.n03_projection_hash == input.source_binding.n03_projection_hash ?
            candidate : nothing
    else
        nothing
    end
    context = n06_01_05_mutation ?
        (validated_ledger_context === nothing ?
            _up2_vnext_n04_05_context(package, input.source_binding;
                include_child_design=true, identity_package=identity_package) :
            validated_ledger_context) :
        (n04_01_03_mutation || n04_02_04_mutation || n04_05_mutation ||
         n06_02_mutation || n06_03_mutation || n06_04_mutation ||
         frozen.id in ("N02-04", "N02-05")) ?
            (validated_n09_contexts === nothing ?
                _up2_vnext_n04_05_context(package, input.source_binding;
                    include_child_design=n06_03_mutation) :
                _up2_vnext_n04_05_context_without_child_design(
                    validated_n09_contexts.ledger_context)) : nothing
    geometry_context = (n07n08_mutation || n01_g2_mutation) ?
        (validated_n09_contexts === nothing ?
            _up2_vnext_g2_geometry_context(package, input.source_binding) :
            validated_n09_contexts.geometry_context) : nothing
    (frozen.field_path == spec.field_path &&
        frozen.source_locator == spec.source_locator &&
        frozen.mutation_kind == spec.mutation_kind &&
        (n0102_mutation || n03_mutation || n04_01_03_mutation ||
            n04_02_04_mutation || n04_05_mutation || n05_mutation ||
            n06_02_mutation || n06_03_mutation || n06_04_mutation ||
            n06_01_05_mutation || n07n08_mutation || n09_mutation || n10_mutation)) ||
        throw(ArgumentError("VNext mutation metadata is not frozen"))
    mutated = _up2_mutated_input_after_validation(input, frozen;
        package=package, native_plan=native_plan, n04_05_context=context,
        g1_context=g1_context,
        n07n08_context=geometry_context, n09_context=n09_context,
        n05_context=n05_context, n10_context=n10_context,
        native_report=native_report, heat_lift_receipt=heat_lift_receipt)
    classified = _up2_real_classification(input, mutated, frozen;
        package=package, n04_05_context=context, g1_context=g1_context,
        n07n08_context=geometry_context, n09_context=n09_context,
        n05_context=n05_context, n10_context=n10_context)
    classified === nothing &&
        throw(ArgumentError("candidate-design mutation was not classified"))
    code, status, detail = classified
    result_hash_body = (mutation_id=frozen.id,
        input_hash=input.input_hash, mutated_input_hash=mutated.input_hash,
        error_code=code, error_path=frozen.field_path, detail=detail,
        compile_calls=counter.compile_calls, provider_calls=counter.provider_calls,
        solver_calls=counter.solver_calls, evidence_reused=false,
        scope=:schema_validation_only,
        authority_scope=input.source_binding.authority_scope,
        authority_gap=input.source_binding.authority_gap,
        n04_05_context_hash=context === nothing ? nothing :
            canonical_hash(context),
        g1_type_context_hash=g1_context === nothing ? nothing :
            g1_context.projection_hash,
        n07n08_context_hash=geometry_context === nothing ? nothing :
            geometry_context.projection_hash)
    if n09_context !== nothing
        mutated_match = _up2_vnext_n09_mutated_match(n09_context, frozen.id;
            archive=archive, binding=input.source_binding)
        result_hash_body = merge(result_hash_body,
            (n09_provider_context_hash=canonical_hash(n09_context.provider_bindings),
             n09_mutated_obligation_hash=mutated_match.obligation_hash,
             n09_mutated_provider_hash=mutated_match.provider === nothing ?
                nothing : mutated_match.provider.manifest_hash))
    end
    result_hash = canonical_hash(result_hash_body)
    UP2ValidationResultV1(frozen.id, input.input_hash, mutated.input_hash,
        status, code, frozen.field_path, detail, counter.compile_calls,
        counter.provider_calls, counter.solver_calls, false, result_hash)
end


# Validate the source-owned F4 route declaration against the freshly rebuilt
# current T1 child, preserving the production checks and their error order.
function _up2_vnext_current_source_selection_v1(child, binding, typed)
    child isa NamedTuple && hasproperty(child, :provider_route_selection) ||
        throw(ArgumentError("F4 candidate provider selection is absent from the rebuilt pinned G3 source"))
    declaration = child.provider_route_selection
    declaration.schema == "g3-candidate-provider-selection-v1" &&
        declaration.version == "v1" && declaration.design_scope == "candidate_design_only" &&
        declaration.candidate_id == binding.candidate_id &&
        declaration.scenario_id == binding.scenario_id ||
        throw(ArgumentError("F4 provider selection differs from rebuilt T1 G3 source identity"))
    child_pin = only(pin for pin in binding.source_pins if pin.role === :g3_child_design)
    typed isa NamedTuple && typed.source_pin_sha256 == child_pin.sha256 &&
        typed.source_sha256 == child_pin.sha256 ||
        throw(ArgumentError("F4 rebuilt child does not retain the exact T1 source pin"))

    runtime = _up2_vnext_n09_runtime()
    selections = declaration.selections
    ids = Tuple(x.selection_id for x in selections)
    ids == ("N09-01", "N09-02", "N09-03", "N09-04", "N09-05") ||
        throw(ArgumentError("F4 candidate provider selection is not the fixed current N09 route set"))
    (declaration=declaration, child_pin=child_pin, runtime=runtime, selections=selections)
end

# Rebuild the candidate-owned provider view from current T1 child bytes and the
# existing N09 request/receipt validators. This checks only the route inputs and
# reuses captured native artifacts; it does not rerun the 50-row validator/solver.
function _up2_vnext_candidate_provider_registry_v1(input::UP2VNextPrecompilerInputV1,
        package; native_plan, native_report, heat_lift_receipt,
        identity_package=nothing)
    binding = input.source_binding
    binding_again = UP2VNextSourceBindingV1(binding.candidate_ref,
        binding.candidate_id, binding.scenario_id, binding.snapshot_id,
        binding.manifest_sha256, binding.package_hash, binding.semantic_identity,
        binding.bundle_hash, binding.n03_projection_hash, binding.source_pins,
        binding.event_id, binding.trigger, binding.time, binding.time_basis,
        binding.projection_status, binding.projection_resolution,
        binding.authority_scope, binding.authority_gap)
    semantic_view(binding_again) == semantic_view(binding) ||
        throw(ArgumentError("F4 input source binding failed its existing typed constructor replay"))
    package isa CandidateStatePackageV5NextV2 &&
        package.candidate_ref == binding.candidate_ref &&
        package.package_hash == binding.package_hash &&
        package.semantic_identity == binding.semantic_identity &&
        package.bundle_hash == binding.bundle_hash ||
        throw(ArgumentError("F4 T1 package differs from its validated source binding"))

    g1_context = _up2_vnext_g1_operator_type_context(package, binding)
    ledger_context = _up2_vnext_n04_05_context(package, binding;
        include_child_design=true, identity_package=identity_package)
    geometry_context = _up2_vnext_g2_geometry_context(package, binding, g1_context;
        include_semantic_body=true)
    rebuilt = _up2_vnext_n09_context_with_g1(package, binding,
        geometry_context, native_plan; g3_source_context=ledger_context,
        g1_context=g1_context, native_report=native_report,
        heat_lift_receipt=heat_lift_receipt)
    n09 = rebuilt.n09_context
    input.provider_bindings == n09.provider_bindings ||
        throw(ArgumentError("F4 input provider bindings differ from freshly rebuilt current N09 routes"))
    child = ledger_context.rebuilt_child_design
    selection_context = _up2_vnext_current_source_selection_v1(child, binding,
        ledger_context.typed_ledger_context)
    declaration = selection_context.declaration
    child_pin = selection_context.child_pin
    runtime = selection_context.runtime
    selections = selection_context.selections
    routes = map(selections) do selection
        id = selection.selection_id
        haskey(n09.requests, id) && haskey(n09.obligations, id) ||
            throw(ArgumentError("F4 current N09 provider request/receipt is absent: $id"))
        request = n09.requests[id]
        provider = request.provider
        obligation = n09.obligations[id]
        service = id == "N09-05" ? provider.kind : request.service
        if id in ("N09-01", "N09-02", "N09-03")
            request.plan === native_plan && request.plan_hash == native_plan.plan_hash ||
                throw(ArgumentError("F4 provider request differs from the current native plan"))
            profile = request.solver_input.payload.materialized_payload.service_scope
        elseif id == "N09-04"
            request.result.candidate_ref == binding.candidate_ref &&
                request.result.t1_package_hash == binding.package_hash &&
                request.result.plan_hash == native_plan.plan_hash ||
                throw(ArgumentError("F4 heat-lift receipt differs from the current T1/native plan"))
            profile = provider.schema
        else
            rebuilt_g3 = request
            rebuilt_g3.binding.candidate_ref == binding.candidate_ref &&
                rebuilt_g3.binding.package_hash == binding.package_hash &&
                rebuilt_g3.binding.semantic_identity == binding.semantic_identity &&
                rebuilt_g3.binding.bundle_hash == binding.bundle_hash &&
                canonical_hash(rebuilt_g3.result) == rebuilt_g3.trace_hash ||
                throw(ArgumentError("F4 G3 sampled-control route differs from the freshly rebuilt current T1 route"))
            profile = obligation.operator
        end
        expected_backend_revision_source =
            id in ("N09-01", "N09-02", "N09-03") ? :gridap_dependency_version :
            id == "N09-04" ? :fixed_scalar_heat_lift_v1 : :fixed_sampled_control_source
        expected_backend_revision = id in ("N09-01", "N09-02", "N09-03") ?
            string(native_plan.dependency_identity.gridap_version) :
            id == "N09-04" ? "scalar-heat-lift-v1" : "sampled-control-source"
        selection.backend_revision_source == expected_backend_revision_source &&
            provider.schema == selection.provider_schema &&
            provider.revision == selection.provider_revision &&
            provider.kind == selection.service == service &&
            provider.backend == selection.backend &&
            provider.backend_revision == expected_backend_revision &&
            provider.independence_group == selection.independence_group &&
            provider.code_hash isa Digest256 &&
            profile == selection.profile_id ||
            throw(ArgumentError("F4 actual provider descriptor differs from candidate selection"))
        provider_file = normpath(joinpath(@__DIR__, "..", "..", "..",
            split(selection.provider_source_path, '/')...))
        isfile(provider_file) || throw(ArgumentError("F4 provider source file is absent"))
        actual_provider_sha = Digest256(bytes2hex(SHA.sha256(read(provider_file))))
        actual_provider_sha == provider.code_hash ||
            throw(ArgumentError("F4 provider manifest code hash differs from actual source bytes"))
        match = Base.invokelatest(getfield(runtime, :match_provider),
            obligation, (provider,))
        match.status === getfield(runtime, :unique_match) && match.provider === provider ||
            throw(ArgumentError("F4 provider failed exact full-signature match"))
        (selection_id=id, service=service, profile_id=profile,
            provider_source_path=selection.provider_source_path,
            provider_code_hash=provider.code_hash, capability=obligation,
            manifest=provider, manifest_hash=provider.manifest_hash,
            match_status=match.status)
    end
    identity = (candidate_ref=binding.candidate_ref,
        candidate_id=binding.candidate_id, scenario_id=binding.scenario_id,
        source_binding_hash=binding.binding_hash, t1_package_hash=binding.package_hash,
        t1_semantic_identity=binding.semantic_identity, t0_bundle_hash=binding.bundle_hash,
        native_plan_hash=native_plan.plan_hash,
        g3_child_source_hash=child_pin.sha256)
    registry_body = (schema="up1-04b-candidate-owned-provider-registry-v1",
        version="v1", design_scope=:candidate_design_only, identity=identity,
        source_selection=declaration, routes=Tuple(routes),
        status=:unique_match, resolution=:contract_only, claim_ceiling=:contract_only,
        emits_evidence=false, execution_authority=false, terminal_authority=false)
    # Current VNext T1 supplies no EngineeringControlFaultInputV4 compatible
    # with this V5 candidate. Preserve that exact gap; do not graft a foreign
    # V4 decision onto this source identity.
    registry=merge(registry_body,(registry_hash=canonical_hash(registry_body),))
    g3=n09.requests["N09-05"]
    ecf_input=if hasproperty(g3.design,:re_enable_policy)
        body=(schema="up2-vnext-n09-g3-ecf-screen-input-v1",
            source_selection=declaration.ecf_compatibility,candidate_ref=binding.candidate_ref,
            candidate_id=binding.candidate_id,scenario_id=binding.scenario_id,
            t1_package_hash=binding.package_hash,t1_semantic_identity=binding.semantic_identity,
            t0_bundle_hash=binding.bundle_hash,source_pin_sha256=child_pin.sha256,
            provider_hash=g3.provider.manifest_hash,capability_hash=canonical_hash(g3.provider.capability),
            obligation_hash=canonical_hash(g3.obligation),control_hash=canonical_hash(g3.control),
            guard=g3.design.re_enable_policy,discrete_trace=g3.result,trace_hash=g3.trace_hash,
            claim_ceiling=getfield(runtime,:screen_only),engineering_evidence=false,
            physical_evidence=false,terminal_authority=false)
        merge(body,(input_hash=canonical_hash(body),))
    else
        (status=:typed_absent,reason=:no_current_v5_source_bound_ecf_input,
            source_selection=declaration.ecf_compatibility,candidate_ref=binding.candidate_ref,
            t1_package_hash=binding.package_hash,source_pin_sha256=child_pin.sha256)
    end
    (registry=registry,ecf_compatibility=ecf_input)
end
