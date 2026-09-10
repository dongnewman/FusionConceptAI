"""Exact-context composition of the five typed RuntimeV4 3-D input slices.

This file only composes declarations and subject bindings that already belong
to one candidate, compiled prefix, scenario, and `ForwardChainContextV4`.
It selects and executes no provider or solver and grants no evidence authority.
"""

using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _TDPIC_REVISION = "runtime-v4-three-d-physical-input-composition-v1"
const _TDPIC_SCHEMA = "fusionconceptai:runtime-v4-three-d-physical-input-composition"
const _TDPIC_TOKEN = Val(:three_d_physical_input_composition_private)
const _TDPIC_REQUIRED_GAPS = (
    "required_typed_three_d_fourier_boundary",
    "required_typed_three_d_coordinate_metric",
    "required_typed_three_d_profiles_and_flux",
    "required_three_d_physical_provider_input_subject_binding",
    "required_typed_three_d_physical_region_support_mapping",
    "required_three_d_physical_region_support_mapping_subject_binding",
    "required_typed_three_d_region_law_exact_cover_set",
    "required_three_d_region_law_set_subject_binding",
    "required_typed_three_d_oriented_interface_discrete_spaces",
    "required_three_d_oriented_interface_subject_binding",
    "required_typed_three_d_governing_residual_jacobian_ownership",
    "required_three_d_governing_residual_jacobian_subject_binding",
    "required_typed_three_d_discretization_controls",
    "required_three_d_discretization_controls_subject_binding",
    "required_three_d_physical_input_composition_subject_binding")

const _TDPIC_SUPPORT_SELECTOR_KEYS = (:region_id, :support_ref)

function _tdpic_text(value, field::String)
    value isa AbstractString || throw(ArgumentError("$field must be text"))
    text = String(value)
    !isempty(strip(text)) && !occursin('*', text) ||
        throw(ArgumentError("$field cannot be empty or wildcarded"))
    text
end

function _tdpic_support_mapping_body(declaration_id, physical_hash,
        oriented_hash, physical_support_ref, region_ids, support_refs)
    (revision=_TDPIC_REVISION,
     declaration_kind=:three_d_physical_region_support_mapping,
     declaration_id=declaration_id,
     physical_declaration_hash=physical_hash,
     oriented_declaration_hash=oriented_hash,
     physical_support_ref=physical_support_ref,
     ordered_region_ids=region_ids,
     ordered_region_support_refs=support_refs,
     model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
     geometric_compatibility_proved=false, provider_selected=false,
     provider_executed=false, solver_executed=false, emits_evidence=false,
     grants_pass=false, promotion_authority=false, p5_ready=false,
     terminal_authority=false, credible_physical_device_count=0)
end

"""Structural mapping from one physical support to every oriented region support."""
struct ThreeDPhysicalRegionSupportMappingV4
    declaration_id::String
    physical_declaration_hash::Digest256
    oriented_declaration_hash::Digest256
    physical_support_ref::SpatialSupportRefV1
    ordered_region_ids::Tuple{Vararg{String}}
    ordered_region_support_refs::Tuple{Vararg{SpatialSupportRefV1}}
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    geometric_compatibility_proved::Bool
    provider_selected::Bool
    provider_executed::Bool
    solver_executed::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    declaration_hash::Digest256
    function ThreeDPhysicalRegionSupportMappingV4(
            token::Val{:three_d_physical_input_composition_private}, fields...)
        token === _TDPIC_TOKEN ||
            throw(ArgumentError("private physical-region support mapping constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDPhysicalRegionSupportMappingV4) = merge(
    _tdpic_support_mapping_body(x.declaration_id,
        x.physical_declaration_hash, x.oriented_declaration_hash,
        x.physical_support_ref, x.ordered_region_ids,
        x.ordered_region_support_refs), (declaration_hash=x.declaration_hash,))

function canonical_hash(x::ThreeDPhysicalRegionSupportMappingV4)
    n = length(x.ordered_region_ids)
    n >= 2 && length(x.ordered_region_support_refs) == n &&
        length(unique(x.ordered_region_ids)) == n ||
        throw(ArgumentError("physical-region support mapping is not an exact unique cover"))
    expected = canonical_hash(_tdpic_support_mapping_body(x.declaration_id,
        x.physical_declaration_hash, x.oriented_declaration_hash,
        x.physical_support_ref, x.ordered_region_ids,
        x.ordered_region_support_refs))
    expected == x.declaration_hash ||
        throw(ArgumentError("physical-region support mapping hash mismatch"))
    x.model_class === :manufactured_input_fixture &&
        x.claim_ceiling == screen_only && !x.geometric_compatibility_proved &&
        !x.provider_selected && !x.provider_executed && !x.solver_executed &&
        !x.emits_evidence && !x.grants_pass && !x.promotion_authority &&
        !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("physical-region support mapping exceeded structural authority"))
    expected
end

function declare_three_d_physical_region_support_mapping(
        physical::ThreeDPhysicalProviderInputV4,
        oriented::ThreeDOrientedInterfaceDeclarationSetV4;
        declaration_id::String, region_supports)
    canonical_hash(physical)
    canonical_hash(oriented)
    region_supports isa Tuple && !(region_supports isa NamedTuple) ||
        throw(ArgumentError("region supports must be an immutable tuple"))
    selectors = Tuple(begin
        item isa NamedTuple && keys(item) == _TDPIC_SUPPORT_SELECTOR_KEYS ||
            throw(ArgumentError("region support selector fields must be exact"))
        item.support_ref isa SpatialSupportRefV1 ||
            throw(ArgumentError("region support selector must be typed"))
        (region_id=_tdpic_text(item.region_id, "region_id"),
         support_ref=item.support_ref)
    end for item in region_supports)
    selector_ids = Tuple(x.region_id for x in selectors)
    oriented_ids = Tuple(x.region_id for x in oriented.regions)
    length(selectors) == length(oriented_ids) &&
        length(unique(selector_ids)) == length(selector_ids) &&
        Set(selector_ids) == Set(oriented_ids) ||
        throw(ArgumentError("region support mapping must exactly cover oriented regions"))
    ordered_supports = Tuple(begin
        selector = only(x for x in selectors if x.region_id == region.region_id)
        selector.support_ref == region.support_ref ||
            throw(ArgumentError("mapped support differs from oriented region support"))
        selector.support_ref
    end for region in oriented.regions)
    id = _tdpic_text(declaration_id, "declaration_id")
    body = _tdpic_support_mapping_body(id, canonical_hash(physical),
        canonical_hash(oriented), physical.coordinate_metric.support_ref,
        oriented_ids, ordered_supports)
    ThreeDPhysicalRegionSupportMappingV4(_TDPIC_TOKEN, id,
        body.physical_declaration_hash, body.oriented_declaration_hash,
        body.physical_support_ref, body.ordered_region_ids,
        body.ordered_region_support_refs, body.model_class,
        body.claim_ceiling, body.geometric_compatibility_proved,
        body.provider_selected, body.provider_executed, body.solver_executed,
        body.emits_evidence, body.grants_pass, body.promotion_authority,
        body.p5_ready, body.terminal_authority,
        body.credible_physical_device_count, canonical_hash(body))
end

function _tdpic_validate_support_mapping(candidate::CandidateStatePackageV4,
        graph::ForwardGraphBindingV4,
        physical::ThreeDPhysicalProviderInputV4,
        oriented::ThreeDOrientedInterfaceDeclarationSetV4,
        mapping::ThreeDPhysicalRegionSupportMappingV4)
    fields = candidate.field_geometry_genome_ref.fields
    physicals = Tuple(x for x in fields
        if typeof(x) === ThreeDPhysicalProviderInputV4)
    oriented_values = Tuple(x for x in fields
        if typeof(x) === ThreeDOrientedInterfaceDeclarationSetV4)
    length(physicals) == 1 &&
        canonical_hash(only(physicals)) == canonical_hash(physical) &&
        semantic_view(only(physicals)) == semantic_view(physical) ||
        throw(ArgumentError("support mapping physical declaration is not the unique current-candidate declaration"))
    length(oriented_values) == 1 &&
        canonical_hash(only(oriented_values)) == canonical_hash(oriented) &&
        semantic_view(only(oriented_values)) == semantic_view(oriented) ||
        throw(ArgumentError("support mapping oriented declaration is not the unique current-candidate declaration"))
    _tdpi_validate_declaration(candidate, graph, physical)
    _tdoi_compile_declaration(candidate, graph, oriented)
    mappings = Tuple(x for x in fields
        if typeof(x) === ThreeDPhysicalRegionSupportMappingV4)
    length(mappings) == 1 &&
        canonical_hash(only(mappings)) == canonical_hash(mapping) &&
        semantic_view(only(mappings)) == semantic_view(mapping) ||
        throw(ArgumentError("physical-region support mapping is absent from or ambiguous in current G2"))
    rebuilt = declare_three_d_physical_region_support_mapping(physical,
        oriented; declaration_id=mapping.declaration_id,
        region_supports=Tuple((region_id=id, support_ref=support)
            for (id, support) in zip(mapping.ordered_region_ids,
                mapping.ordered_region_support_refs)))
    canonical_hash(rebuilt) == canonical_hash(mapping) &&
        semantic_view(rebuilt) == semantic_view(mapping) ||
        throw(ArgumentError("physical-region support mapping is foreign to current declarations"))
    mapping
end

function _tdpic_support_binding_body(candidate_hash, compiled_prefix_hash,
        genome_hash, mapping_hash, physical_hash, oriented_hash,
        physical_support_ref, region_ids, support_refs, mission_hash,
        bounds_hash, scenario_hash)
    (revision=_TDPIC_REVISION,
     binding_kind=:three_d_physical_region_support_mapping_subject_binding,
     candidate_hash=candidate_hash, compiled_prefix_hash=compiled_prefix_hash,
     field_geometry_genome_hash=genome_hash,
     mapping_declaration_hash=mapping_hash,
     physical_declaration_hash=physical_hash,
     oriented_declaration_hash=oriented_hash,
     physical_support_ref=physical_support_ref,
     ordered_region_ids=region_ids,
     ordered_region_support_refs=support_refs,
     mission_hash=mission_hash, bounds_hash=bounds_hash,
     scenario_hash=scenario_hash)
end

struct ThreeDPhysicalRegionSupportMappingBindingV4
    candidate_hash::Digest256
    compiled_prefix_hash::Digest256
    field_geometry_genome_hash::Digest256
    mapping_declaration_hash::Digest256
    physical_declaration_hash::Digest256
    oriented_declaration_hash::Digest256
    physical_support_ref::SpatialSupportRefV1
    ordered_region_ids::Tuple{Vararg{String}}
    ordered_region_support_refs::Tuple{Vararg{SpatialSupportRefV1}}
    mission_hash::Digest256
    bounds_hash::Digest256
    scenario_hash::Digest256
    binding_hash::Digest256
    function ThreeDPhysicalRegionSupportMappingBindingV4(
            token::Val{:three_d_physical_input_composition_private}, fields...)
        token === _TDPIC_TOKEN ||
            throw(ArgumentError("private physical-region support binding constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDPhysicalRegionSupportMappingBindingV4) = merge(
    _tdpic_support_binding_body(x.candidate_hash, x.compiled_prefix_hash,
        x.field_geometry_genome_hash, x.mapping_declaration_hash,
        x.physical_declaration_hash, x.oriented_declaration_hash,
        x.physical_support_ref, x.ordered_region_ids,
        x.ordered_region_support_refs, x.mission_hash, x.bounds_hash,
        x.scenario_hash), (binding_hash=x.binding_hash,))

function canonical_hash(x::ThreeDPhysicalRegionSupportMappingBindingV4)
    length(x.ordered_region_ids) >= 2 &&
        length(x.ordered_region_ids) == length(x.ordered_region_support_refs) ||
        throw(ArgumentError("physical-region support binding is incomplete"))
    view = semantic_view(x)
    body = NamedTuple{keys(view)[1:end-1]}(values(view)[1:end-1])
    expected = canonical_hash(body)
    expected == x.binding_hash ||
        throw(ArgumentError("physical-region support binding hash mismatch"))
    expected
end

function make_three_d_physical_region_support_mapping_binding(
        compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4, mission_payload, bounds_payload,
        comparison_scope, scenario_scope, scenario,
        physical::ThreeDPhysicalProviderInputV4,
        oriented::ThreeDOrientedInterfaceDeclarationSetV4,
        mapping::ThreeDPhysicalRegionSupportMappingV4)
    comparison = _runtime_axis_tuple(comparison_scope, "comparison_scope")
    scenarios = _runtime_axis_tuple(scenario_scope, "scenario_scope")
    _runtime_validate_compiled_prefix(compiled, compiled.candidate, registry,
        mission_payload, bounds_payload, comparison, scenarios)
    is_canonical_value(scenario) &&
        _forward_scenario_name(scenario) in scenarios ||
        throw(ArgumentError("support mapping scenario is outside frozen scope"))
    graph = _make_forward_graph_binding(:field_geometry,
        compiled.field_geometry_graph)
    _tdpic_validate_support_mapping(compiled.candidate, graph, physical,
        oriented, mapping)
    body = _tdpic_support_binding_body(
        _forward_candidate_identity(compiled.candidate), compiled.prefix_hash,
        field_geometry_hash(compiled.candidate.field_geometry_genome_ref),
        canonical_hash(mapping), canonical_hash(physical),
        canonical_hash(oriented), mapping.physical_support_ref,
        mapping.ordered_region_ids, mapping.ordered_region_support_refs,
        _runtime_decl_hash(mission_payload), _runtime_decl_hash(bounds_payload),
        canonical_hash(scenario))
    ThreeDPhysicalRegionSupportMappingBindingV4(_TDPIC_TOKEN,
        body.candidate_hash, body.compiled_prefix_hash,
        body.field_geometry_genome_hash, body.mapping_declaration_hash,
        body.physical_declaration_hash, body.oriented_declaration_hash,
        body.physical_support_ref, body.ordered_region_ids,
        body.ordered_region_support_refs, body.mission_hash, body.bounds_hash,
        body.scenario_hash, canonical_hash(body))
end

function _tdpic_component_body(candidate_hash, compiled_prefix_hash,
        genome_hash, graph_hash, graph_binding_hash,
        physical_declaration_hash, physical_binding_hash,
        support_mapping_declaration_hash, support_mapping_binding_hash,
        region_law_set_declaration_hash, region_law_set_binding_hash,
        oriented_declaration_hash, oriented_binding_hash,
        residual_declaration_hash, residual_binding_hash,
        discretization_declaration_hash, discretization_binding_hash,
        region_ids, state_node_ids, state_node_identity_hashes,
        interface_ref_hashes, discrete_space_identity_hashes,
        mission_hash, bounds_hash, scenario_hash)
    (revision=_TDPIC_REVISION,
     binding_kind=:three_d_physical_input_composition_subject_binding,
     candidate_hash=candidate_hash, compiled_prefix_hash=compiled_prefix_hash,
     field_geometry_genome_hash=genome_hash,
     field_geometry_graph_hash=graph_hash,
     field_geometry_graph_binding_hash=graph_binding_hash,
     physical_declaration_hash=physical_declaration_hash,
     physical_binding_hash=physical_binding_hash,
     support_mapping_declaration_hash=support_mapping_declaration_hash,
     support_mapping_binding_hash=support_mapping_binding_hash,
     region_law_set_declaration_hash=region_law_set_declaration_hash,
     region_law_set_binding_hash=region_law_set_binding_hash,
     oriented_declaration_hash=oriented_declaration_hash,
     oriented_binding_hash=oriented_binding_hash,
     residual_declaration_hash=residual_declaration_hash,
     residual_binding_hash=residual_binding_hash,
     discretization_declaration_hash=discretization_declaration_hash,
     discretization_binding_hash=discretization_binding_hash,
     ordered_region_ids=region_ids,
     ordered_state_node_ids=state_node_ids,
     ordered_state_node_identity_hashes=state_node_identity_hashes,
     ordered_interface_ref_hashes=interface_ref_hashes,
     ordered_discrete_space_identity_hashes=discrete_space_identity_hashes,
     mission_hash=mission_hash, bounds_hash=bounds_hash,
     scenario_hash=scenario_hash)
end

"""Sealed identity join for the five component bindings in one subject."""
struct ThreeDPhysicalInputCompositionBindingV4
    candidate_hash::Digest256
    compiled_prefix_hash::Digest256
    field_geometry_genome_hash::Digest256
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    physical_declaration_hash::Digest256
    physical_binding_hash::Digest256
    support_mapping_declaration_hash::Digest256
    support_mapping_binding_hash::Digest256
    region_law_set_declaration_hash::Digest256
    region_law_set_binding_hash::Digest256
    oriented_declaration_hash::Digest256
    oriented_binding_hash::Digest256
    residual_declaration_hash::Digest256
    residual_binding_hash::Digest256
    discretization_declaration_hash::Digest256
    discretization_binding_hash::Digest256
    ordered_region_ids::Tuple{Vararg{String}}
    ordered_state_node_ids::Tuple{Vararg{String}}
    ordered_state_node_identity_hashes::Tuple{Vararg{Digest256}}
    ordered_interface_ref_hashes::Tuple{Vararg{Digest256}}
    ordered_discrete_space_identity_hashes::Tuple{Vararg{Digest256}}
    mission_hash::Digest256
    bounds_hash::Digest256
    scenario_hash::Digest256
    binding_hash::Digest256
    function ThreeDPhysicalInputCompositionBindingV4(
            token::Val{:three_d_physical_input_composition_private}, fields...)
        token === _TDPIC_TOKEN ||
            throw(ArgumentError("private 3-D composition binding constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDPhysicalInputCompositionBindingV4) = merge(
    _tdpic_component_body(x.candidate_hash, x.compiled_prefix_hash,
        x.field_geometry_genome_hash, x.field_geometry_graph_hash,
        x.field_geometry_graph_binding_hash, x.physical_declaration_hash,
        x.physical_binding_hash, x.support_mapping_declaration_hash,
        x.support_mapping_binding_hash, x.region_law_set_declaration_hash,
        x.region_law_set_binding_hash, x.oriented_declaration_hash,
        x.oriented_binding_hash, x.residual_declaration_hash,
        x.residual_binding_hash, x.discretization_declaration_hash,
        x.discretization_binding_hash, x.ordered_region_ids,
        x.ordered_state_node_ids, x.ordered_state_node_identity_hashes,
        x.ordered_interface_ref_hashes,
        x.ordered_discrete_space_identity_hashes, x.mission_hash,
        x.bounds_hash, x.scenario_hash), (binding_hash=x.binding_hash,))

function canonical_hash(x::ThreeDPhysicalInputCompositionBindingV4)
    n = length(x.ordered_region_ids)
    n >= 2 && length(x.ordered_state_node_ids) == n &&
        length(x.ordered_state_node_identity_hashes) == n ||
        throw(ArgumentError("3-D composition requires at least two exact region/state links"))
    length(unique(x.ordered_region_ids)) == n &&
        length(unique(x.ordered_state_node_ids)) == n &&
        length(unique(x.ordered_state_node_identity_hashes)) == n ||
        throw(ArgumentError("3-D composition region/state identities must be unique"))
    !isempty(x.ordered_interface_ref_hashes) &&
        !isempty(x.ordered_discrete_space_identity_hashes) ||
        throw(ArgumentError("3-D composition interface/space identities cannot be empty"))
    view = semantic_view(x)
    body = NamedTuple{keys(view)[1:end-1]}(values(view)[1:end-1])
    expected = canonical_hash(body)
    expected == x.binding_hash ||
        throw(ArgumentError("3-D composition binding hash mismatch"))
    expected
end

function _tdpic_equal(actual, expected, field::String)
    canonical_hash(actual) == canonical_hash(expected) &&
        semantic_view(actual) == semantic_view(expected) ||
        throw(ArgumentError("$field is foreign to the common compiled context"))
    actual
end

function _tdpic_keyed_state_cover(oriented_declarations, compiled_regions,
        residual_pairs)
    length(oriented_declarations) == length(compiled_regions) &&
        Tuple(x.region_id for x in oriented_declarations) ==
            Tuple(x.region_id for x in compiled_regions) ||
        throw(ArgumentError("oriented declarations and compiled refs differ"))
    oriented_states = Dict(oriented_declarations[i].state_node_id =>
        (identity_hash=compiled_regions[i].state_node_identity_hash,
         state_type=compiled_regions[i].state_type)
        for i in eachindex(oriented_declarations))
    residual_states = Dict(x.state_node_id =>
        (identity_hash=x.state_node_identity_hash, state_type=x.state_type)
        for x in residual_pairs)
    length(oriented_states) == length(oriented_declarations) &&
        length(residual_states) == length(residual_pairs) &&
        Set(keys(oriented_states)) == Set(keys(residual_states)) &&
        all(oriented_states[id] == residual_states[id]
            for id in keys(oriented_states)) ||
        throw(ArgumentError("oriented region states and residual ownership differ"))
    true
end

function _tdpic_cross_identities(candidate::CandidateStatePackageV4,
        graph::ForwardGraphBindingV4,
        physical::ThreeDPhysicalProviderInputV4,
        support_mapping::ThreeDPhysicalRegionSupportMappingV4,
        region_law_set::ThreeDRegionLawSetDeclarationV4,
        oriented::ThreeDOrientedInterfaceDeclarationSetV4,
        residual::ThreeDGoverningResidualJacobianDeclarationSetV4,
        discretization::ThreeDDiscretizationControlDeclarationV4)
    _tdpi_validate_declaration(candidate, graph, physical)
    _tdpic_validate_support_mapping(candidate, graph, physical, oriented,
        support_mapping)
    law_values = _tdrls_validate_declaration(candidate, graph, region_law_set)
    regions, interfaces = _tdoi_compile_declaration(candidate, graph, oriented)
    rebuilt_residual = _tdrj_rebuild_declaration(graph, residual)
    discrete = _tddc_validate_declaration(candidate, graph, discretization)

    region_ids = Tuple(x.region_id for x in regions)
    length(region_ids) >= 2 ||
        throw(ArgumentError("3-D composition requires at least two oriented regions"))
    region_law_set.ordered_region_ids == region_ids &&
        Tuple(x.region_node_id for x in region_law_set.laws) == region_ids ||
        throw(ArgumentError("region-law set does not exactly cover oriented regions"))
    canonical_hash(law_values.oriented) == canonical_hash(oriented) ||
        throw(ArgumentError("region-law set and oriented input name different declarations"))
    support_mapping.ordered_region_ids == region_ids &&
        support_mapping.ordered_region_support_refs ==
            Tuple(x.support_ref for x in oriented.regions) &&
        support_mapping.physical_support_ref ==
            physical.coordinate_metric.support_ref ||
        throw(ArgumentError("physical-region support mapping differs from current inputs"))
    n_laws = 3 * length(region_ids)
    length(region_law_set.ordered_edge_identity_hashes) == n_laws &&
        length(unique(region_law_set.ordered_edge_identity_hashes)) == n_laws &&
        length(unique(region_law_set.ordered_ast_root_identity_hashes)) == n_laws &&
        length(unique(region_law_set.ordered_output_node_identity_hashes)) == n_laws ||
        throw(ArgumentError("region-law set does not own globally distinct laws"))

    state_ids = Tuple(x.state_node_id for x in oriented.regions)
    state_hashes = Tuple(x.state_node_identity_hash for x in regions)
    _tdpic_keyed_state_cover(oriented.regions, regions,
        rebuilt_residual.pairs)

    interface_hashes = Tuple(x.ref_hash for x in interfaces)
    all(x -> x.minus_state_node_identity_hash in state_hashes &&
             x.plus_state_node_identity_hash in state_hashes, interfaces) ||
        throw(ArgumentError("interface endpoints are outside residual state coverage"))
    space_hashes = discrete.space_identity_hashes
    expected_space_hashes = Tuple(canonical_hash(x) for x in discrete.spaces)
    space_hashes == expected_space_hashes ||
        throw(ArgumentError("discretization spaces differ from oriented spaces"))
    (region_ids=region_ids, state_node_ids=state_ids,
     state_node_identity_hashes=state_hashes,
     interface_ref_hashes=interface_hashes,
     discrete_space_identity_hashes=space_hashes)
end

"""Build the sixth binding only after all five component bindings agree."""
function make_three_d_physical_input_composition_binding(
        compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4, mission_payload, bounds_payload,
        comparison_scope, scenario_scope, scenario,
        physical::ThreeDPhysicalProviderInputV4,
        support_mapping::ThreeDPhysicalRegionSupportMappingV4,
        region_law_set::ThreeDRegionLawSetDeclarationV4,
        oriented::ThreeDOrientedInterfaceDeclarationSetV4,
        residual::ThreeDGoverningResidualJacobianDeclarationSetV4,
        discretization::ThreeDDiscretizationControlDeclarationV4,
        physical_binding::ThreeDPhysicalProviderInputBindingV4,
        support_mapping_binding::ThreeDPhysicalRegionSupportMappingBindingV4,
        region_law_set_binding::ThreeDRegionLawSetBindingV4,
        oriented_binding::ThreeDOrientedInterfaceBindingV4,
        residual_binding::ThreeDGoverningResidualJacobianBindingV4,
        discretization_binding::ThreeDDiscretizationControlBindingV4)
    comparison = _runtime_axis_tuple(comparison_scope, "comparison_scope")
    scenarios = _runtime_axis_tuple(scenario_scope, "scenario_scope")
    _runtime_validate_compiled_prefix(compiled, compiled.candidate, registry,
        mission_payload, bounds_payload, comparison, scenarios)
    is_canonical_value(scenario) ||
        throw(ArgumentError("composition scenario is not canonicalizable"))
    _forward_scenario_name(scenario) in scenarios ||
        throw(ArgumentError("composition scenario is outside frozen scope"))

    expected_physical = make_three_d_physical_provider_input_binding(compiled,
        registry, mission_payload, bounds_payload, comparison, scenarios,
        scenario, physical)
    expected_oriented = make_three_d_oriented_interface_binding(compiled,
        registry, mission_payload, bounds_payload, comparison, scenarios,
        scenario, oriented)
    expected_support_mapping =
        make_three_d_physical_region_support_mapping_binding(compiled,
            registry, mission_payload, bounds_payload, comparison, scenarios,
            scenario, physical, oriented, support_mapping)
    expected_region = make_three_d_region_law_set_binding(compiled, registry,
        mission_payload, bounds_payload, comparison, scenarios, scenario,
        region_law_set, expected_oriented)
    expected_residual = make_three_d_governing_residual_jacobian_binding(
        compiled, registry, mission_payload, bounds_payload, comparison,
        scenarios, scenario, residual)
    expected_discretization = make_three_d_discretization_control_binding(
        compiled, registry, mission_payload, bounds_payload, comparison,
        scenarios, scenario, discretization, expected_oriented)
    _tdpic_equal(physical_binding, expected_physical, "physical binding")
    _tdpic_equal(support_mapping_binding, expected_support_mapping,
        "physical-region support mapping binding")
    _tdpic_equal(region_law_set_binding, expected_region,
        "region-law-set binding")
    _tdpic_equal(oriented_binding, expected_oriented, "oriented binding")
    _tdpic_equal(residual_binding, expected_residual, "residual binding")
    _tdpic_equal(discretization_binding, expected_discretization,
        "discretization binding")

    graph = _make_forward_graph_binding(:field_geometry,
        compiled.field_geometry_graph)
    cross = _tdpic_cross_identities(compiled.candidate, graph, physical,
        support_mapping, region_law_set, oriented, residual, discretization)
    body = _tdpic_component_body(
        _forward_candidate_identity(compiled.candidate), compiled.prefix_hash,
        field_geometry_hash(compiled.candidate.field_geometry_genome_ref),
        graph.canonical_graph_hash, canonical_hash(graph),
        canonical_hash(physical), canonical_hash(physical_binding),
        canonical_hash(support_mapping), canonical_hash(support_mapping_binding),
        canonical_hash(region_law_set), canonical_hash(region_law_set_binding),
        canonical_hash(oriented), canonical_hash(oriented_binding),
        canonical_hash(residual), canonical_hash(residual_binding),
        canonical_hash(discretization), canonical_hash(discretization_binding),
        cross.region_ids, cross.state_node_ids,
        cross.state_node_identity_hashes, cross.interface_ref_hashes,
        cross.discrete_space_identity_hashes,
        _runtime_decl_hash(mission_payload), _runtime_decl_hash(bounds_payload),
        canonical_hash(scenario))
    ThreeDPhysicalInputCompositionBindingV4(_TDPIC_TOKEN,
        body.candidate_hash, body.compiled_prefix_hash,
        body.field_geometry_genome_hash, body.field_geometry_graph_hash,
        body.field_geometry_graph_binding_hash,
        body.physical_declaration_hash, body.physical_binding_hash,
        body.support_mapping_declaration_hash,
        body.support_mapping_binding_hash,
        body.region_law_set_declaration_hash,
        body.region_law_set_binding_hash,
        body.oriented_declaration_hash, body.oriented_binding_hash,
        body.residual_declaration_hash, body.residual_binding_hash,
        body.discretization_declaration_hash,
        body.discretization_binding_hash, body.ordered_region_ids,
        body.ordered_state_node_ids, body.ordered_state_node_identity_hashes,
        body.ordered_interface_ref_hashes,
        body.ordered_discrete_space_identity_hashes, body.mission_hash,
        body.bounds_hash, body.scenario_hash, canonical_hash(body))
end

function _tdpic_input_body(context, binding, physical, support_mapping,
        region_laws, oriented, residual, discretization)
    (revision=_TDPIC_REVISION, schema=_TDPIC_SCHEMA,
     context_hash=context.context_hash, candidate_hash=context.candidate_hash,
     compiled_prefix_hash=context.compiled.prefix_hash,
     registry_hash=context.registry_hash,
     physical_subject_hash=context.subject.physical_subject_hash,
     composition_binding_hash=binding.binding_hash,
     physical_declaration_hash=canonical_hash(physical),
     physical_binding_hash=binding.physical_binding_hash,
     support_mapping_declaration_hash=canonical_hash(support_mapping),
     support_mapping_binding_hash=binding.support_mapping_binding_hash,
     region_law_set_compilation_hash=canonical_hash(region_laws),
     oriented_input_hash=canonical_hash(oriented),
     residual_ownership_hash=canonical_hash(residual),
     discretization_input_hash=canonical_hash(discretization),
     ordered_region_ids=binding.ordered_region_ids,
     ordered_state_node_ids=binding.ordered_state_node_ids,
     ordered_state_node_identity_hashes=binding.ordered_state_node_identity_hashes,
     ordered_interface_ref_hashes=binding.ordered_interface_ref_hashes,
     ordered_discrete_space_identity_hashes=
        binding.ordered_discrete_space_identity_hashes,
     model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
     provider_selected=false, provider_executed=false,
     solver_executed=false, emits_evidence=false, grants_pass=false,
     promotion_authority=false, p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

"""Fully reconstructed input package; still only a screen-level input."""
struct ThreeDPhysicalInputCompositionV4
    context_hash::Digest256
    candidate_hash::Digest256
    compiled_prefix_hash::Digest256
    registry_hash::Digest256
    physical_subject_hash::Digest256
    composition_binding_hash::Digest256
    physical_binding_hash::Digest256
    support_mapping_binding_hash::Digest256
    physical::ThreeDPhysicalProviderInputV4
    support_mapping::ThreeDPhysicalRegionSupportMappingV4
    region_laws::ThreeDRegionLawSetCompilationV4
    oriented::ThreeDOrientedInterfaceInputV4
    residual::ThreeDGoverningResidualJacobianOwnershipV4
    discretization::ThreeDDiscretizationControlInputV4
    ordered_region_ids::Tuple{Vararg{String}}
    ordered_state_node_ids::Tuple{Vararg{String}}
    ordered_state_node_identity_hashes::Tuple{Vararg{Digest256}}
    ordered_interface_ref_hashes::Tuple{Vararg{Digest256}}
    ordered_discrete_space_identity_hashes::Tuple{Vararg{Digest256}}
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    provider_executed::Bool
    solver_executed::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    input_hash::Digest256
    function ThreeDPhysicalInputCompositionV4(
            token::Val{:three_d_physical_input_composition_private}, fields...)
        token === _TDPIC_TOKEN ||
            throw(ArgumentError("private 3-D composition input constructor"))
        new(fields...)
    end
end

function semantic_view(x::ThreeDPhysicalInputCompositionV4)
    (revision=_TDPIC_REVISION, schema=_TDPIC_SCHEMA,
     context_hash=x.context_hash, candidate_hash=x.candidate_hash,
     compiled_prefix_hash=x.compiled_prefix_hash,
     registry_hash=x.registry_hash,
     physical_subject_hash=x.physical_subject_hash,
     composition_binding_hash=x.composition_binding_hash,
     physical_declaration_hash=canonical_hash(x.physical),
     physical_binding_hash=x.physical_binding_hash,
     support_mapping_declaration_hash=canonical_hash(x.support_mapping),
     support_mapping_binding_hash=x.support_mapping_binding_hash,
     region_law_set_compilation_hash=canonical_hash(x.region_laws),
     oriented_input_hash=canonical_hash(x.oriented),
     residual_ownership_hash=canonical_hash(x.residual),
     discretization_input_hash=canonical_hash(x.discretization),
     ordered_region_ids=x.ordered_region_ids,
     ordered_state_node_ids=x.ordered_state_node_ids,
     ordered_state_node_identity_hashes=x.ordered_state_node_identity_hashes,
     ordered_interface_ref_hashes=x.ordered_interface_ref_hashes,
     ordered_discrete_space_identity_hashes=x.ordered_discrete_space_identity_hashes,
     model_class=x.model_class, claim_ceiling=x.claim_ceiling,
     provider_selected=x.provider_selected, provider_executed=x.provider_executed,
     solver_executed=x.solver_executed, emits_evidence=x.emits_evidence,
     grants_pass=x.grants_pass, promotion_authority=x.promotion_authority,
     p5_ready=x.p5_ready, terminal_authority=x.terminal_authority,
     credible_physical_device_count=x.credible_physical_device_count,
     input_hash=x.input_hash)
end

function canonical_hash(x::ThreeDPhysicalInputCompositionV4)
    view = semantic_view(x)
    body = NamedTuple{keys(view)[1:end-1]}(values(view)[1:end-1])
    expected = canonical_hash(body)
    expected == x.input_hash ||
        throw(ArgumentError("3-D composition input hash mismatch"))
    x.model_class === :manufactured_input_fixture &&
        x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.solver_executed && !x.emits_evidence &&
        !x.grants_pass && !x.promotion_authority && !x.p5_ready &&
        !x.terminal_authority && x.credible_physical_device_count == 0 ||
        throw(ArgumentError("3-D composition input authority ceiling was exceeded"))
    expected
end

function _tdpic_resolution_body(context_hash, status, input, gaps)
    (revision=_TDPIC_REVISION, kind=:three_d_physical_input_composition,
     context_hash=context_hash, status=status,
     input_hash=input === nothing ? nothing : canonical_hash(input),
     recoverable_gaps=gaps, claim_ceiling=screen_only,
     provider_selected=false, provider_executed=false,
     solver_executed=false, emits_evidence=false, grants_pass=false,
     promotion_authority=false, p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct ThreeDPhysicalInputCompositionResolutionV4
    context_hash::Digest256
    status::Symbol
    input::Union{Nothing,ThreeDPhysicalInputCompositionV4}
    recoverable_gaps::Tuple{Vararg{String}}
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    provider_executed::Bool
    solver_executed::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    resolution_hash::Digest256
    function ThreeDPhysicalInputCompositionResolutionV4(
            token::Val{:three_d_physical_input_composition_private}, fields...)
        token === _TDPIC_TOKEN ||
            throw(ArgumentError("private 3-D composition resolution constructor"))
        new(fields...)
    end
end


semantic_view(x::ThreeDPhysicalInputCompositionResolutionV4) = merge(
    _tdpic_resolution_body(x.context_hash, x.status, x.input,
        x.recoverable_gaps), (resolution_hash=x.resolution_hash,))

function canonical_hash(x::ThreeDPhysicalInputCompositionResolutionV4)
    x.status in (:input_complete, :recoverable_gap) ||
        throw(ArgumentError("invalid 3-D composition status"))
    (x.status === :input_complete) == (x.input !== nothing) ||
        throw(ArgumentError("3-D composition status/payload mismatch"))
    x.status === :input_complete ? isempty(x.recoverable_gaps) :
        !isempty(x.recoverable_gaps) ||
        throw(ArgumentError("recoverable composition requires exact gaps"))
    view = semantic_view(x)
    body = NamedTuple{keys(view)[1:end-1]}(values(view)[1:end-1])
    expected = canonical_hash(body)
    expected == x.resolution_hash ||
        throw(ArgumentError("3-D composition resolution hash mismatch"))
    x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.solver_executed && !x.emits_evidence &&
        !x.grants_pass && !x.promotion_authority && !x.p5_ready &&
        !x.terminal_authority && x.credible_physical_device_count == 0 ||
        throw(ArgumentError("3-D composition resolution authority ceiling was exceeded"))
    expected
end

function _tdpic_resolution(context_hash, input, gaps)
    gap_tuple = Tuple(String(x) for x in gaps)
    status = input === nothing ? :recoverable_gap : :input_complete
    status === :input_complete && !isempty(gap_tuple) &&
        throw(ArgumentError("input_complete composition cannot retain gaps"))
    status === :recoverable_gap && isempty(gap_tuple) &&
        throw(ArgumentError("recoverable composition requires a gap"))
    body = _tdpic_resolution_body(context_hash, status, input, gap_tuple)
    ThreeDPhysicalInputCompositionResolutionV4(_TDPIC_TOKEN,
        context_hash, status, input, gap_tuple, screen_only, false, false,
        false, false, false, false, false, false, 0, canonical_hash(body))
end

function _tdpic_inventory(context::ForwardChainContextV4)
    fields = context.candidate.field_geometry_genome_ref.fields
    bindings = context.subject.bindings
    declarations = (
        physical=Tuple(x for x in fields if typeof(x) === ThreeDPhysicalProviderInputV4),
        support_mapping=Tuple(x for x in fields
            if typeof(x) === ThreeDPhysicalRegionSupportMappingV4),
        region=Tuple(x for x in fields if typeof(x) === ThreeDRegionLawSetDeclarationV4),
        oriented=Tuple(x for x in fields if typeof(x) === ThreeDOrientedInterfaceDeclarationSetV4),
        residual=Tuple(x for x in fields if typeof(x) === ThreeDGoverningResidualJacobianDeclarationSetV4),
        discretization=Tuple(x for x in fields if typeof(x) === ThreeDDiscretizationControlDeclarationV4))
    subject_bindings = (
        physical=Tuple(x for x in bindings if typeof(x) === ThreeDPhysicalProviderInputBindingV4),
        support_mapping=Tuple(x for x in bindings
            if typeof(x) === ThreeDPhysicalRegionSupportMappingBindingV4),
        region=Tuple(x for x in bindings if typeof(x) === ThreeDRegionLawSetBindingV4),
        oriented=Tuple(x for x in bindings if typeof(x) === ThreeDOrientedInterfaceBindingV4),
        residual=Tuple(x for x in bindings if typeof(x) === ThreeDGoverningResidualJacobianBindingV4),
        discretization=Tuple(x for x in bindings if typeof(x) === ThreeDDiscretizationControlBindingV4),
        composition=Tuple(x for x in bindings if typeof(x) === ThreeDPhysicalInputCompositionBindingV4))
    declarations, subject_bindings
end

function _tdpic_inventory_gaps(declarations, bindings)
    gaps = String[]
    groups = (
        (declarations.physical, _TDPIC_REQUIRED_GAPS[1:3],
            "ambiguous_typed_three_d_geometry_profile_declaration",
         bindings.physical, _TDPIC_REQUIRED_GAPS[4],
            "ambiguous_three_d_physical_provider_input_subject_binding"),
        (declarations.support_mapping, (_TDPIC_REQUIRED_GAPS[5],),
            "ambiguous_typed_three_d_physical_region_support_mapping",
         bindings.support_mapping, _TDPIC_REQUIRED_GAPS[6],
            "ambiguous_three_d_physical_region_support_mapping_subject_binding"),
        (declarations.region, (_TDPIC_REQUIRED_GAPS[7],),
            "ambiguous_typed_three_d_region_law_exact_cover_set",
         bindings.region, _TDPIC_REQUIRED_GAPS[8],
            "ambiguous_three_d_region_law_set_subject_binding"),
        (declarations.oriented, (_TDPIC_REQUIRED_GAPS[9],),
            "ambiguous_typed_three_d_oriented_interface_discrete_spaces",
         bindings.oriented, _TDPIC_REQUIRED_GAPS[10],
            "ambiguous_three_d_oriented_interface_subject_binding"),
        (declarations.residual, (_TDPIC_REQUIRED_GAPS[11],),
            "ambiguous_typed_three_d_governing_residual_jacobian_ownership",
         bindings.residual, _TDPIC_REQUIRED_GAPS[12],
            "ambiguous_three_d_governing_residual_jacobian_subject_binding"),
        (declarations.discretization, (_TDPIC_REQUIRED_GAPS[13],),
            "ambiguous_typed_three_d_discretization_controls",
         bindings.discretization, _TDPIC_REQUIRED_GAPS[14],
            "ambiguous_three_d_discretization_controls_subject_binding"))
    for (declaration_values, declaration_missing, declaration_ambiguous,
            binding_values, binding_missing, binding_ambiguous) in groups
        isempty(declaration_values) ? append!(gaps, declaration_missing) :
            length(declaration_values) == 1 ||
                push!(gaps, declaration_ambiguous)
        isempty(binding_values) ? push!(gaps, binding_missing) :
            length(binding_values) == 1 || push!(gaps, binding_ambiguous)
    end
    isempty(bindings.composition) ? push!(gaps, _TDPIC_REQUIRED_GAPS[15]) :
        length(bindings.composition) == 1 || push!(gaps,
            "ambiguous_three_d_physical_input_composition_subject_binding")
    Tuple(gaps)
end

function _tdpic_make_input(context, binding, physical, support_mapping,
        region_laws, oriented, residual, discretization)
    body = _tdpic_input_body(context, binding, physical, support_mapping,
        region_laws, oriented, residual, discretization)
    ThreeDPhysicalInputCompositionV4(_TDPIC_TOKEN,
        body.context_hash, body.candidate_hash, body.compiled_prefix_hash,
        body.registry_hash, body.physical_subject_hash,
        body.composition_binding_hash, body.physical_binding_hash,
        body.support_mapping_binding_hash, physical, support_mapping,
        region_laws, oriented,
        residual, discretization, body.ordered_region_ids,
        body.ordered_state_node_ids, body.ordered_state_node_identity_hashes,
        body.ordered_interface_ref_hashes,
        body.ordered_discrete_space_identity_hashes, body.model_class,
        body.claim_ceiling, body.provider_selected, body.provider_executed,
        body.solver_executed, body.emits_evidence, body.grants_pass,
        body.promotion_authority, body.p5_ready, body.terminal_authority,
        body.credible_physical_device_count, canonical_hash(body))
end

"""Compose only exact current-context components or return exact gaps."""
function compose_three_d_physical_inputs(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    declarations, bindings = _tdpic_inventory(context)
    gaps = _tdpic_inventory_gaps(declarations, bindings)
    component_binding_count = sum(length(getproperty(bindings, name))
        for name in (:physical, :support_mapping, :region, :oriented,
            :residual, :discretization))
    declaration_count = sum(length(getproperty(declarations, name))
        for name in keys(declarations))
    component_binding_count > 0 && declaration_count < 6 &&
        throw(ArgumentError("3-D component subject binding has a missing declaration"))
    !isempty(bindings.composition) && !isempty(gaps) &&
        throw(ArgumentError("composition binding cannot accompany missing or ambiguous components"))
    isempty(gaps) || return _tdpic_resolution(context.context_hash, nothing, gaps)

    physical = only(declarations.physical)
    support_mapping = only(declarations.support_mapping)
    region_declaration = only(declarations.region)
    oriented_declaration = only(declarations.oriented)
    residual_declaration = only(declarations.residual)
    discretization_declaration = only(declarations.discretization)
    rebuilt_binding = make_three_d_physical_input_composition_binding(
        context.compiled, context.registry, context.mission_payload,
        context.bounds_payload, context.comparison_scope,
        context.scenario_scope, context.scenario, physical,
        support_mapping, region_declaration, oriented_declaration,
        residual_declaration,
        discretization_declaration, only(bindings.physical),
        only(bindings.support_mapping), only(bindings.region),
        only(bindings.oriented),
        only(bindings.residual), only(bindings.discretization))
    composition_binding = only(bindings.composition)
    _tdpic_equal(composition_binding, rebuilt_binding,
        "composition subject binding")

    physical_resolution = resolve_three_d_physical_provider_input(context)
    physical_resolution.recoverable_gaps == _TDPI_REQUIRED_GAPS[4:7] &&
        physical_resolution.declaration_hash == canonical_hash(physical) &&
        physical_resolution.binding_hash == canonical_hash(only(bindings.physical)) ||
        throw(ArgumentError("base geometry/profile slice did not reconstruct exactly"))
    region_resolution = compile_three_d_region_law_set(context)
    region_resolution.status === :compiled ||
        throw(ArgumentError("region-law slice is incomplete"))
    oriented_resolution = resolve_three_d_oriented_interface_input(context)
    oriented_resolution.status === :input_complete ||
        throw(ArgumentError("oriented-interface slice is incomplete"))
    residual_resolution = compile_three_d_governing_residual_jacobian(context)
    residual_resolution.status === :compiled ||
        throw(ArgumentError("residual/Jacobian slice is incomplete"))
    discretization_resolution = resolve_three_d_discretization_controls(context)
    discretization_resolution.status === :input_complete ||
        throw(ArgumentError("discretization slice is incomplete"))
    input = _tdpic_make_input(context, composition_binding, physical,
        support_mapping, region_resolution, something(oriented_resolution.input),
        something(residual_resolution.ownership),
        something(discretization_resolution.input))
    canonical_hash(input)
    _tdpic_resolution(context.context_hash, input, ())
end

function validate_three_d_physical_input_composition(
        context::ForwardChainContextV4,
        input::ThreeDPhysicalInputCompositionV4)
    expected = compose_three_d_physical_inputs(context)
    expected.status === :input_complete ||
        throw(ArgumentError("current context does not own a complete 3-D input composition"))
    rebuilt = something(expected.input)
    canonical_hash(input) == canonical_hash(rebuilt) &&
        semantic_view(input) == semantic_view(rebuilt) ||
        throw(ArgumentError("3-D input composition differs from current context"))
    input.input_hash
end

validate_three_d_physical_input_composition(
    ::ThreeDPhysicalInputCompositionV4) = false

three_d_physical_input_composition_manifest() = (
    schema=_TDPIC_SCHEMA, revision=_TDPIC_REVISION,
    purpose=:exact_context_three_d_physical_input_composition,
    statuses=(:input_complete, :recoverable_gap),
    requires_same_candidate=true, requires_same_compiled_prefix=true,
    requires_same_forward_context_subject=true,
    requires_at_least_two_regions=true,
    requires_physical_region_support_mapping=true,
    support_mapping_is_structural_only=true,
    geometric_compatibility_proved=false,
    residual_state_cover_is_keyed=true,
    model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
    provider_selected=false, provider_executed=false,
    solver_executed=false, emits_evidence=false, grants_pass=false,
    physical_validation=false, engineering_validation=false,
    promotion_authority=false, p5_ready=false, terminal_authority=false,
    credible_physical_device_count=0)
