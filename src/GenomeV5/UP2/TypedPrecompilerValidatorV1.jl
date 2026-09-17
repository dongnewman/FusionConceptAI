"""Value based contract validator for the UP2-00 preparation slice.

N01 and N02 are implemented as real typed projections and are classified from
mutated values. N05 is a typed interface-bound declaration with missing
flux-port provenance and remains deferred. N03, N04, N06-N10 remain explicitly
pending until their source projections and cross-field rules are frozen.
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
        ("N03-01", "/g1/equation_plan/equations/0/temporal_kind", "G1EquationV2.temporal_kind::TimeKindV1", :symbol, :pending, :invalid_type, "time_semantics_mismatch"),
        ("N03-02", "/g1/equation_plan/equations/0/derivative_order", "G1EquationV2.derivative_order::Int", :integer, :pending, :invalid_type, "time_semantics_mismatch"),
        ("N03-03", "/g1/grammar_profile/operators/0/temporal_kinds", "G1OperatorSpecV2.temporal_kinds::Tuple", :tuple, :pending, :invalid_type, "time_semantics_mismatch"),
        ("N03-04", "/g3/control/controllers/0/events/0/trigger", "G3EventV2.trigger::Symbol", :symbol, :pending, :invalid_type, "time_semantics_mismatch"),
        ("N03-05", "/g3/control/controllers/0/events/0/time", "G3EventV2.time::Rational{Int64}", :rational, :pending, :invalid_type, "time_semantics_mismatch"))))
    append!(rows, _up2_specs_for_class(:N04, (
        ("N04-01", "/g3/realization/network/accounts/0/owner", "G3LedgerAccountV2.owner::String", :text, :pending, :invalid_closure, "duplicate_conservation_or_energy_account_owner"),
        ("N04-02", "/g3/realization/network/closures/0/account_ids", "G3LedgerClosureV2.account_ids::Tuple[String]", :tuple, :pending, :invalid_closure, "duplicate_conservation_or_energy_account_owner"),
        ("N04-03", "/g3/realization/network/entries/0/account_id", "G3LedgerEntryV2.account_id::String", :text, :pending, :invalid_closure, "duplicate_conservation_or_energy_account_owner"),
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
        ("N07-01", "/g2/contract/regions/0/lower", "G2RegionV2.lower::NTuple{3,Rational{Int64}}", :tuple, :pending, :invalid_boundary, "nonclosed_or_out_of_bounds_boundary"),
        ("N07-02", "/g2/contract/regions/0/upper", "G2RegionV2.upper::NTuple{3,Rational{Int64}}", :tuple, :pending, :invalid_boundary, "nonclosed_or_out_of_bounds_boundary"),
        ("N07-03", "/g2/plan/exterior/boundary_faces", "G2ExteriorPlanV2.boundary_faces::Tuple[Symbol]", :tuple, :pending, :invalid_boundary, "nonclosed_or_out_of_bounds_boundary"),
        ("N07-04", "/g2/plan/exterior/boundary_patches/0/lower", "G2BoundaryFacePatchV2.lower::NTuple{2,Rational{Int64}}", :tuple, :pending, :invalid_boundary, "nonclosed_or_out_of_bounds_boundary"),
        ("N07-05", "/g2/plan/exterior/boundary_condition", "G2ExteriorPlanV2.boundary_condition::Symbol", :symbol, :pending, :invalid_boundary, "nonclosed_or_out_of_bounds_boundary"))))
    append!(rows, _up2_specs_for_class(:N08, (
        ("N08-01", "/g2/plan/chart/axes", "G2ChartPlanV2.axes::NTuple{3,Symbol}", :tuple, :pending, :invalid_boundary, "invalid_geometry_chart_mesh_or_topology"),
        ("N08-02", "/g2/plan/chart/map_kind", "G2ChartPlanV2.map_kind::Symbol", :symbol, :pending, :invalid_boundary, "invalid_geometry_chart_mesh_or_topology"),
        ("N08-03", "/g2/plan/mesh/cells_per_region", "G2MeshPlanV2.cells_per_region::NTuple{3,Int}", :tuple, :pending, :invalid_boundary, "invalid_geometry_chart_mesh_or_topology"),
        ("N08-04", "/g2/plan/mesh/basis", "G2MeshPlanV2.basis::Symbol", :symbol, :pending, :invalid_boundary, "invalid_geometry_chart_mesh_or_topology"),
        ("N08-05", "/g2/contract/interfaces", "RegionInterfaceContractV2.interfaces::Tuple", :tuple, :pending, :invalid_boundary, "invalid_geometry_chart_mesh_or_topology"))))
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

"""Derive the UP2 projection from the actual accepted A package.

Only the N01/N02 source fields are populated from concrete G1/G2/G3 values in
this first slice. Other registered fields remain typed pending projections and
cannot be classified until their source accessors are frozen.
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

function _up2_typed_value_matches(value::UP2TypedValueV1, kind::Symbol)
    kind === :integer && return value isa UP2IntegerValueV1
    kind === :symbol && return value isa UP2SymbolValueV1
    kind === :text && return value isa UP2TextValueV1
    kind === :rational && return value isa UP2RationalValueV1
    kind === :unit && return value isa UP2UnitValueV1
    kind === :hash && return value isa UP2HashValueV1
    kind === :ref && return value isa UP2RefValueV1
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

function _up2_mutation_value(spec)
    spec.id in ("N01-01", "N01-02", "N01-03") && return UP2IntegerValueV1(1)
    spec.id == "N01-04" && return UP2IntegerValueV1(2)
    spec.id == "N01-05" && return UP2SymbolValueV1(:tensor5)
    spec.class_id === :N02 && spec.source_type === :unit &&
        return UP2UnitValueV1(UnitSignature((1, 0, 0, 0, 0, 0, 0)))
    spec.id == "N02-03" && return UP2TextValueV1("kg")
    spec.mutation_kind === :left_empty && return UP2TextValueV1("")
    spec.mutation_kind === :right_empty && return UP2TextValueV1("")
    spec.mutation_kind === :left_sign_zero && return UP2IntegerValueV1(0)
    spec.mutation_kind === :same_sign && return UP2IntegerValueV1(1)
    spec.mutation_kind === :unit_mismatch && return UP2UnitValueV1(UnitSignature((1, 0, 0, 0, 0, 0, 0)))
    throw(ArgumentError("no real typed mutation value for $(spec.id); semantic gap is pending"))
end

function _up2_mutated_input(input, spec)
    field = _up2_find_field(input.state, spec.id)
    field === nothing && throw(ArgumentError("mutation field is not registered"))
    value = _up2_mutation_value(spec)
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

function _up2_real_classification(input, mutated, spec)
    spec.class_id in (:N01, :N02, :N05) || return nothing
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
    field = _up2_find_field(mutated.state, spec.id)
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
        counter=UP2InvocationCounterV1())
    up2_validate_input(input)
    frozen = up2_spec_for_id(spec.id)
    (frozen.field_path == spec.field_path && frozen.source_locator == spec.source_locator &&
        frozen.mutation_kind == spec.mutation_kind) || throw(ArgumentError("mutation metadata is not frozen"))
    mutated = _up2_mutated_input(input, frozen)
    classified = _up2_real_classification(input, mutated, frozen)
    classified === nothing && throw(ArgumentError("semantic gap pending for $(frozen.id); no expected label used"))
    code, status = classified
    result_hash = canonical_hash((mutation_id=frozen.id, input_hash=input.input_hash,
        mutated_input_hash=mutated.input_hash, error_code=code, error_path=frozen.field_path,
        detail=frozen.detail, compile_calls=counter.compile_calls,
        provider_calls=counter.provider_calls, solver_calls=counter.solver_calls,
        evidence_reused=false, status=status, scope=:schema_validation_only))
    UP2ValidationResultV1(frozen.id, input.input_hash, mutated.input_hash, status, code,
        frozen.field_path, frozen.detail, counter.compile_calls, counter.provider_calls,
        counter.solver_calls, false, result_hash)
end
