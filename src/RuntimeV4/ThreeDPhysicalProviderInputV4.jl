"""Candidate-bound declaration/gap edge for a future 3-D physical provider.

This isolated slice can bind typed G2 geometry and equilibrium profiles.  It
does not declare the still-missing multi-region constitutive, interface,
residual, or discretization contracts; those remain exact recoverable gaps.
It selects no provider, executes no solver, and emits no evidence.
"""

using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _TDPI_REVISION = "runtime-v4-three-d-physical-provider-input-v1"
const _TDPI_SCHEMA = "fusionconceptai:runtime-v4-three-d-physical-provider-input"
const _TDPI_TOKEN = Val(:three_d_physical_provider_input_private)
const _TDPI_REQUIRED_GAPS = (
    "required_typed_three_d_fourier_boundary",
    "required_typed_three_d_coordinate_metric",
    "required_typed_three_d_profiles_and_flux",
    "required_typed_three_d_region_constitutive_source_boundary",
    "required_typed_three_d_oriented_interface_discrete_spaces",
    "required_typed_three_d_governing_residual_jacobian_ownership",
    "required_typed_three_d_discretization_controls",
    "required_three_d_physical_provider_input_subject_binding")

function _tdpi_text(value, field::String)
    typeof(value) === String || throw(ArgumentError("$field must be an immutable String"))
    text = strip(value)
    !isempty(text) && isvalid(text) || throw(ArgumentError("$field cannot be empty"))
    lowered = lowercase(text)
    (lowered in ("*", "any", "all", "wildcard") || occursin('*', text)) &&
        throw(ArgumentError("$field cannot contain a wildcard"))
    String(text)
end

function _tdpi_int(value, field::String; minimum::Int, maximum::Int)
    value isa Bool && throw(ArgumentError("$field must be an integer, not Bool"))
    typeof(value) <: Integer || throw(ArgumentError("$field must be an integer"))
    typemin(Int) <= value <= typemax(Int) || throw(ArgumentError("$field is out of range"))
    result = Int(value)
    minimum <= result <= maximum || throw(ArgumentError("$field is outside its admitted range"))
    result
end

function _tdpi_finite(value, field::String; positive::Bool=false, nonzero::Bool=false)
    value isa Bool && throw(ArgumentError("$field must be numeric, not Bool"))
    value isa Real || throw(ArgumentError("$field must be numeric"))
    result = Float64(value)
    isfinite(result) || throw(ArgumentError("$field must be finite"))
    positive && result <= 0 && throw(ArgumentError("$field must be positive"))
    nonzero && result == 0 && throw(ArgumentError("$field must be nonzero"))
    result
end

_tdpi_dimensionless() = UnitSignature()
_tdpi_length_unit() = UnitSignature((0, 1, 0, 0, 0, 0, 0))
_tdpi_metric_unit() = UnitSignature((0, 2, 0, 0, 0, 0, 0))
_tdpi_pressure_unit() = UnitSignature((1, -1, -2, 0, 0, 0, 0))
_tdpi_current_unit() = UnitSignature((0, 0, 0, 1, 0, 0, 0))
_tdpi_flux_unit() = UnitSignature((1, 2, -2, -1, 0, 0, 0))

function _tdpi_static_3d_type(value::PhysicalType, field::String;
        kind::Symbol, rank::Int, unit::UnitSignature)
    value.value_kind === kind || throw(ArgumentError("$field has the wrong value kind"))
    value.tensor_rank == rank || throw(ArgumentError("$field has the wrong tensor rank"))
    value.spatial_dimension == 3 || throw(ArgumentError("$field must be three-dimensional"))
    value.temporal_type == TemporalTypeV1(static_time) ||
        throw(ArgumentError("$field must use static time semantics"))
    value.units == unit || throw(ArgumentError("$field has the wrong unit"))
    value
end

struct ThreeDFourierCoefficientV4
    poloidal_mode::Int
    toroidal_mode::Int
    coefficient_m::Float64
    function ThreeDFourierCoefficientV4(poloidal_mode, toroidal_mode, coefficient_m)
        new(_tdpi_int(poloidal_mode, "poloidal mode"; minimum=-64, maximum=64),
            _tdpi_int(toroidal_mode, "toroidal mode"; minimum=-64, maximum=64),
            _tdpi_finite(coefficient_m, "Fourier coefficient"; nonzero=true))
    end
end
semantic_view(x::ThreeDFourierCoefficientV4) = (
    poloidal_mode=x.poloidal_mode, toroidal_mode=x.toroidal_mode,
    coefficient_m=x.coefficient_m)

struct ThreeDFourierBoundaryV4
    boundary_id::String
    field_periods::Int
    stellarator_symmetric::Bool
    radial_coefficients::Tuple{Vararg{ThreeDFourierCoefficientV4}}
    vertical_coefficients::Tuple{Vararg{ThreeDFourierCoefficientV4}}
    length_unit::UnitSignature
    function ThreeDFourierBoundaryV4(boundary_id, field_periods,
            stellarator_symmetric, radial_coefficients, vertical_coefficients,
            length_unit::UnitSignature=_tdpi_length_unit())
        typeof(stellarator_symmetric) === Bool ||
            throw(ArgumentError("stellarator_symmetric must be Bool"))
        for (values, field) in ((radial_coefficients, "radial coefficients"),
                                (vertical_coefficients, "vertical coefficients"))
            values isa Tuple && !(values isa NamedTuple) && !isempty(values) &&
                all(x -> typeof(x) === ThreeDFourierCoefficientV4, values) ||
                throw(ArgumentError("$field must be a nonempty immutable typed tuple"))
            keys = Tuple((x.poloidal_mode, x.toroidal_mode) for x in values)
            length(unique(keys)) == length(keys) ||
                throw(ArgumentError("$field mode pairs must be unique"))
        end
        radial = Tuple(radial_coefficients)
        vertical = Tuple(vertical_coefficients)
        r00 = Tuple(x.coefficient_m for x in radial
            if x.poloidal_mode == 0 && x.toroidal_mode == 0)
        length(r00) == 1 && only(r00) > 0 ||
            throw(ArgumentError("boundary requires one positive radial (0,0) coefficient"))
        length_unit == _tdpi_length_unit() ||
            throw(ArgumentError("Fourier boundary must use SI length"))
        new(_tdpi_text(boundary_id, "boundary_id"),
            _tdpi_int(field_periods, "field_periods"; minimum=1, maximum=64),
            stellarator_symmetric, radial, vertical, length_unit)
    end
end
semantic_view(x::ThreeDFourierBoundaryV4) = (
    boundary_id=x.boundary_id, field_periods=x.field_periods,
    stellarator_symmetric=x.stellarator_symmetric,
    radial_coefficients=x.radial_coefficients,
    vertical_coefficients=x.vertical_coefficients, length_unit=x.length_unit)

struct ThreeDCoordinateMetricV4
    support_ref::SpatialSupportRefV1
    chart_ref::ChartRefV1
    coordinate_map_site_ref::FieldOperatorSiteRefV1
    metric_site_ref::FieldOperatorSiteRefV1
    coordinate_map_root_identity_hash::Digest256
    metric_root_identity_hash::Digest256
    coordinate_type::PhysicalType
    metric_type::PhysicalType
    chart_bounds::NTuple{3,QuantityIntervalV1}
    function ThreeDCoordinateMetricV4(support_ref::SpatialSupportRefV1,
            chart_ref::ChartRefV1,
            coordinate_map_site_ref::FieldOperatorSiteRefV1,
            metric_site_ref::FieldOperatorSiteRefV1,
            coordinate_map_root_identity_hash::Digest256,
            metric_root_identity_hash::Digest256,
            coordinate_type::PhysicalType, metric_type::PhysicalType,
            chart_bounds)
        coordinate_map_root_identity_hash != metric_root_identity_hash ||
            throw(ArgumentError("coordinate-map and metric AST roots must differ"))
        _tdpi_static_3d_type(coordinate_type, "coordinate type";
            kind=:physical_coordinate_map, rank=1, unit=_tdpi_length_unit())
        _tdpi_static_3d_type(metric_type, "metric type";
            kind=:covariant_metric, rank=2, unit=_tdpi_metric_unit())
        chart_bounds isa Tuple && !(chart_bounds isa NamedTuple) &&
            length(chart_bounds) == 3 &&
            all(x -> typeof(x) === QuantityIntervalV1 &&
                x.unit == _tdpi_dimensionless() &&
                x.interval.lower < x.interval.upper, chart_bounds) ||
            throw(ArgumentError("chart_bounds must be an ordered dimensionless typed 3-tuple"))
        new(support_ref, chart_ref, coordinate_map_site_ref, metric_site_ref,
            coordinate_map_root_identity_hash, metric_root_identity_hash,
            coordinate_type, metric_type, ntuple(i -> chart_bounds[i], 3))
    end
end
semantic_view(x::ThreeDCoordinateMetricV4) = (
    support_ref=x.support_ref, chart_ref=x.chart_ref,
    coordinate_map_site_ref=x.coordinate_map_site_ref,
    metric_site_ref=x.metric_site_ref,
    coordinate_map_root_identity_hash=x.coordinate_map_root_identity_hash,
    metric_root_identity_hash=x.metric_root_identity_hash,
    coordinate_type=x.coordinate_type, metric_type=x.metric_type,
    chart_bounds=x.chart_bounds)

struct ThreeDRadialProfileV4
    profile_id::String
    quantity::Symbol
    coefficients::Tuple{Vararg{Float64}}
    unit::UnitSignature
    radial_domain::QuantityIntervalV1
    function ThreeDRadialProfileV4(profile_id, quantity::Symbol, coefficients,
            unit::UnitSignature, radial_domain::QuantityIntervalV1)
        quantity in (:pressure, :iota, :current) ||
            throw(ArgumentError("profile quantity must be pressure, iota, or current"))
        coefficients isa Tuple && !(coefficients isa NamedTuple) &&
            1 <= length(coefficients) <= 64 ||
            throw(ArgumentError("profile coefficients must be an immutable 1:64 tuple"))
        values = Tuple(_tdpi_finite(x, "profile coefficient") for x in coefficients)
        expected = quantity === :pressure ? _tdpi_pressure_unit() :
            quantity === :iota ? _tdpi_dimensionless() : _tdpi_current_unit()
        unit == expected || throw(ArgumentError("profile has the wrong unit"))
        quantity !== :pressure || first(values) > 0 ||
            throw(ArgumentError("pressure profile requires positive axis pressure"))
        radial_domain.unit == _tdpi_dimensionless() &&
            radial_domain.interval.lower == 0 // 1 &&
            radial_domain.interval.upper == 1 // 1 &&
            radial_domain.interval.allow_equal == false ||
            throw(ArgumentError("radial domain must be the strict normalized [0,1] interval"))
        new(_tdpi_text(profile_id, "profile_id"), quantity, values, unit,
            radial_domain)
    end
end
semantic_view(x::ThreeDRadialProfileV4) = (
    profile_id=x.profile_id, quantity=x.quantity,
    coefficients=x.coefficients, unit=x.unit,
    radial_domain=x.radial_domain)

struct ThreeDProfilesFluxV4
    profile_set_id::String
    pressure::ThreeDRadialProfileV4
    rotational_or_current::ThreeDRadialProfileV4
    toroidal_flux_wb::Float64
    flux_unit::UnitSignature
    function ThreeDProfilesFluxV4(profile_set_id,
            pressure::ThreeDRadialProfileV4,
            rotational_or_current::ThreeDRadialProfileV4,
            toroidal_flux_wb, flux_unit::UnitSignature=_tdpi_flux_unit())
        pressure.quantity === :pressure ||
            throw(ArgumentError("pressure slot requires a pressure profile"))
        rotational_or_current.quantity in (:iota, :current) ||
            throw(ArgumentError("second profile must be iota or current"))
        pressure.profile_id != rotational_or_current.profile_id ||
            throw(ArgumentError("profile IDs must differ"))
        flux_unit == _tdpi_flux_unit() ||
            throw(ArgumentError("toroidal flux must use SI webers"))
        new(_tdpi_text(profile_set_id, "profile_set_id"), pressure,
            rotational_or_current,
            _tdpi_finite(toroidal_flux_wb, "toroidal flux"; nonzero=true),
            flux_unit)
    end
end
semantic_view(x::ThreeDProfilesFluxV4) = (
    profile_set_id=x.profile_set_id, pressure=x.pressure,
    rotational_or_current=x.rotational_or_current,
    toroidal_flux_wb=x.toroidal_flux_wb, flux_unit=x.flux_unit)

function _tdpi_input_body(declaration_id, boundary, coordinate_metric,
        profiles_flux)
    (revision=_TDPI_REVISION, declaration_id=declaration_id,
     fourier_boundary=boundary, coordinate_metric=coordinate_metric,
     profiles_flux=profiles_flux, model_class=:manufactured_input_fixture,
     claim_ceiling=screen_only, provider_selected=false,
     solver_executed=false, emits_evidence=false,
     p5_ready=false, credible_physical_device_count=0)
end

"""Typed G2-owned geometry/profile portion of a future provider input."""
struct ThreeDPhysicalProviderInputV4
    declaration_id::String
    fourier_boundary::ThreeDFourierBoundaryV4
    coordinate_metric::ThreeDCoordinateMetricV4
    profiles_flux::ThreeDProfilesFluxV4
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    solver_executed::Bool
    emits_evidence::Bool
    p5_ready::Bool
    credible_physical_device_count::Int
    declaration_hash::Digest256
    function ThreeDPhysicalProviderInputV4(declaration_id,
            boundary::ThreeDFourierBoundaryV4,
            coordinate_metric::ThreeDCoordinateMetricV4,
            profiles_flux::ThreeDProfilesFluxV4)
        id = _tdpi_text(declaration_id, "declaration_id")
        body = _tdpi_input_body(id, boundary, coordinate_metric, profiles_flux)
        new(id, boundary, coordinate_metric, profiles_flux,
            :manufactured_input_fixture, screen_only, false, false, false,
            false, 0, canonical_hash(body))
    end
    function ThreeDPhysicalProviderInputV4(
            token::Val{:three_d_physical_provider_input_private}, fields...)
        token === _TDPI_TOKEN || throw(ArgumentError("private 3-D input constructor"))
        new(fields...)
    end
end
semantic_view(x::ThreeDPhysicalProviderInputV4) = merge(
    _tdpi_input_body(x.declaration_id, x.fourier_boundary,
        x.coordinate_metric, x.profiles_flux),
    (declaration_hash=x.declaration_hash,))
function canonical_hash(x::ThreeDPhysicalProviderInputV4)
    expected = canonical_hash(_tdpi_input_body(x.declaration_id,
        x.fourier_boundary, x.coordinate_metric, x.profiles_flux))
    expected == x.declaration_hash ||
        throw(ArgumentError("3-D physical input declaration hash mismatch"))
    x.model_class === :manufactured_input_fixture &&
        x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.solver_executed && !x.emits_evidence && !x.p5_ready &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("3-D input declaration authority ceiling was exceeded"))
    expected
end

function _tdpi_graph_roots(binding::ForwardGraphBindingV4)
    binding.role === :field_geometry ||
        throw(ArgumentError("3-D input requires the G2 field-geometry graph"))
    canonical_hash(binding)
    roots = NamedTuple[]
    index = 0
    for edge in binding.graph.hyperedges
        _, program_roots, _ = _forward_edge_program(edge)
        for root_position in eachindex(program_roots)
            index += 1
            node_index = _forward_root_output_node(edge, root_position)
            push!(roots, (root_hash=binding.ast_root_identity_hashes[index],
                edge_id=edge.edge_id,
                output_type=binding.graph.nodes[node_index].physical_type))
        end
    end
    length(roots) == length(binding.ast_root_identity_hashes) ||
        throw(ArgumentError("G2 AST-root count mismatch"))
    Tuple(roots)
end

function _tdpi_validate_declaration(candidate::CandidateStatePackageV4,
        graph::ForwardGraphBindingV4, declaration::ThreeDPhysicalProviderInputV4)
    canonical_hash(declaration)
    matches = Tuple(x for x in candidate.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDPhysicalProviderInputV4 &&
           canonical_hash(x) == declaration.declaration_hash)
    length(matches) == 1 ||
        throw(ArgumentError("3-D input declaration is absent from or ambiguous in current G2 fields"))
    coordinate = declaration.coordinate_metric
    supports = Tuple(x for x in candidate.field_geometry_genome_ref.fields
        if typeof(x) === SpatialSupportGeneV1 && x.support_ref == coordinate.support_ref)
    length(supports) == 1 ||
        throw(ArgumentError("coordinate support is absent from or ambiguous in current G2 fields"))
    charts = Tuple(x for x in only(supports).charts if x.chart_ref == coordinate.chart_ref)
    length(charts) == 1 ||
        throw(ArgumentError("coordinate chart is absent from or ambiguous in current G2 support"))
    chart = only(charts)
    chart.coordinate_map_root.operator_site_ref == coordinate.coordinate_map_site_ref &&
        chart.metric_program_root.operator_site_ref == coordinate.metric_site_ref &&
        chart.chart_bounds == coordinate.chart_bounds ||
        throw(ArgumentError("coordinate/metric declaration does not match current typed G2 support"))
    roots = _tdpi_graph_roots(graph)
    coordinate_roots = Tuple(x for x in roots
        if x.root_hash == coordinate.coordinate_map_root_identity_hash)
    metric_roots = Tuple(x for x in roots
        if x.root_hash == coordinate.metric_root_identity_hash)
    length(coordinate_roots) == 1 && length(metric_roots) == 1 ||
        throw(ArgumentError("coordinate/metric root is absent from or ambiguous in current G2 AST identities"))
    coordinate_root = only(coordinate_roots)
    metric_root = only(metric_roots)
    coordinate_root.edge_id == coordinate.coordinate_map_site_ref.value &&
        coordinate_root.output_type == coordinate.coordinate_type ||
        throw(ArgumentError("coordinate-map AST identity/type mismatch"))
    metric_root.edge_id == coordinate.metric_site_ref.value &&
        metric_root.output_type == coordinate.metric_type ||
        throw(ArgumentError("metric AST identity/type mismatch"))
    declaration.declaration_hash
end

function _tdpi_binding_body(declaration_hash, genome_hash, graph_hash,
        graph_binding_hash, ast_root_hashes, mission_hash, bounds_hash,
        scenario_hash)
    (revision=_TDPI_REVISION,
     binding_kind=:three_d_physical_provider_input_subject_binding,
     declaration_hash=declaration_hash,
     field_geometry_genome_hash=genome_hash,
     field_geometry_graph_hash=graph_hash,
     field_geometry_graph_binding_hash=graph_binding_hash,
     ast_root_identity_hashes=ast_root_hashes,
     mission_hash=mission_hash, bounds_hash=bounds_hash,
     scenario_hash=scenario_hash)
end

struct ThreeDPhysicalProviderInputBindingV4
    declaration_hash::Digest256
    field_geometry_genome_hash::Digest256
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    ast_root_identity_hashes::Tuple{Vararg{Digest256}}
    mission_hash::Digest256
    bounds_hash::Digest256
    scenario_hash::Digest256
    binding_hash::Digest256
    function ThreeDPhysicalProviderInputBindingV4(
            token::Val{:three_d_physical_provider_input_private}, fields...)
        token === _TDPI_TOKEN || throw(ArgumentError("private 3-D input binding constructor"))
        new(fields...)
    end
end
semantic_view(x::ThreeDPhysicalProviderInputBindingV4) = merge(
    _tdpi_binding_body(x.declaration_hash, x.field_geometry_genome_hash,
        x.field_geometry_graph_hash, x.field_geometry_graph_binding_hash,
        x.ast_root_identity_hashes, x.mission_hash, x.bounds_hash,
        x.scenario_hash), (binding_hash=x.binding_hash,))
function canonical_hash(x::ThreeDPhysicalProviderInputBindingV4)
    expected = canonical_hash(_tdpi_binding_body(x.declaration_hash,
        x.field_geometry_genome_hash, x.field_geometry_graph_hash,
        x.field_geometry_graph_binding_hash, x.ast_root_identity_hashes,
        x.mission_hash, x.bounds_hash, x.scenario_hash))
    expected == x.binding_hash || throw(ArgumentError("3-D input binding hash mismatch"))
    expected
end

function make_three_d_physical_provider_input_binding(
        compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4, mission_payload, bounds_payload,
        comparison_scope, scenario_scope, scenario,
        declaration::ThreeDPhysicalProviderInputV4)
    comparison = _runtime_axis_tuple(comparison_scope, "comparison_scope")
    scenarios = _runtime_axis_tuple(scenario_scope, "scenario_scope")
    _runtime_validate_compiled_prefix(compiled, compiled.candidate, registry,
        mission_payload, bounds_payload, comparison, scenarios)
    is_canonical_value(scenario) || throw(ArgumentError("binding scenario is not canonicalizable"))
    _forward_scenario_name(scenario) in scenarios ||
        throw(ArgumentError("binding scenario is outside frozen scope"))
    graph = _make_forward_graph_binding(:field_geometry, compiled.field_geometry_graph)
    declaration_hash = _tdpi_validate_declaration(compiled.candidate, graph, declaration)
    genome_hash = field_geometry_hash(compiled.candidate.field_geometry_genome_ref)
    graph_hash = canonical_hash(compiled.field_geometry_graph)
    graph_binding_hash = canonical_hash(graph)
    ast_roots = graph.ast_root_identity_hashes
    mission_hash = _runtime_decl_hash(mission_payload)
    bounds_hash = _runtime_decl_hash(bounds_payload)
    scenario_hash = canonical_hash(scenario)
    body = _tdpi_binding_body(declaration_hash, genome_hash, graph_hash,
        graph_binding_hash, ast_roots, mission_hash, bounds_hash, scenario_hash)
    ThreeDPhysicalProviderInputBindingV4(_TDPI_TOKEN, declaration_hash,
        genome_hash, graph_hash, graph_binding_hash, ast_roots, mission_hash,
        bounds_hash, scenario_hash, canonical_hash(body))
end

function _tdpi_resolution_body(context_hash, declaration_hash, binding_hash,
        gaps)
    (revision=_TDPI_REVISION, kind=:three_d_physical_provider_input_resolution,
     context_hash=context_hash, status=:recoverable_gap,
     declaration_hash=declaration_hash, binding_hash=binding_hash,
     recoverable_gaps=gaps, claim_ceiling=screen_only,
     provider_selected=false, solver_executed=false,
     emits_evidence=false, p5_ready=false,
     credible_physical_device_count=0)
end

struct ThreeDPhysicalProviderInputResolutionV4
    context_hash::Digest256
    status::Symbol
    declaration_hash::Union{Nothing,Digest256}
    binding_hash::Union{Nothing,Digest256}
    recoverable_gaps::Tuple{Vararg{String}}
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    solver_executed::Bool
    emits_evidence::Bool
    p5_ready::Bool
    credible_physical_device_count::Int
    resolution_hash::Digest256
    function ThreeDPhysicalProviderInputResolutionV4(
            token::Val{:three_d_physical_provider_input_private}, fields...)
        token === _TDPI_TOKEN || throw(ArgumentError("private 3-D input resolution constructor"))
        new(fields...)
    end
end
semantic_view(x::ThreeDPhysicalProviderInputResolutionV4) = merge(
    _tdpi_resolution_body(x.context_hash, x.declaration_hash,
        x.binding_hash, x.recoverable_gaps),
    (resolution_hash=x.resolution_hash,))
function canonical_hash(x::ThreeDPhysicalProviderInputResolutionV4)
    x.status === :recoverable_gap && !isempty(x.recoverable_gaps) ||
        throw(ArgumentError("this declaration-only slice must retain recoverable gaps"))
    expected = canonical_hash(_tdpi_resolution_body(x.context_hash,
        x.declaration_hash, x.binding_hash, x.recoverable_gaps))
    expected == x.resolution_hash || throw(ArgumentError("3-D input resolution hash mismatch"))
    x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.solver_executed && !x.emits_evidence && !x.p5_ready &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("3-D input resolution authority ceiling was exceeded"))
    expected
end

function _tdpi_resolution(context_hash, declaration_hash, binding_hash, gaps)
    gap_tuple = Tuple(String(x) for x in gaps)
    isempty(gap_tuple) && throw(ArgumentError("input_complete is reserved until all typed edges land"))
    body = _tdpi_resolution_body(context_hash, declaration_hash, binding_hash, gap_tuple)
    ThreeDPhysicalProviderInputResolutionV4(_TDPI_TOKEN, context_hash,
        :recoverable_gap, declaration_hash, binding_hash, gap_tuple,
        screen_only, false, false, false, false, 0, canonical_hash(body))
end

function _tdpi_context_binding(context::ForwardChainContextV4,
        declaration::ThreeDPhysicalProviderInputV4)
    bindings = Tuple(x for x in context.subject.bindings
        if typeof(x) === ThreeDPhysicalProviderInputBindingV4)
    length(bindings) == 1 ||
        throw(ArgumentError("physical subject must contain exactly one typed 3-D input binding"))
    binding = only(bindings)
    canonical_hash(binding)
    graph = forward_graph_binding(context, :field_geometry)
    binding.declaration_hash == _tdpi_validate_declaration(context.candidate,
        graph, declaration) || throw(ArgumentError("3-D input binding declaration hash is foreign"))
    binding.field_geometry_genome_hash ==
        field_geometry_hash(context.candidate.field_geometry_genome_ref) ||
        throw(ArgumentError("3-D input binding G2 Genome hash is foreign"))
    binding.field_geometry_graph_hash == canonical_hash(context.compiled.field_geometry_graph) ||
        throw(ArgumentError("3-D input binding G2 graph hash is foreign"))
    binding.field_geometry_graph_binding_hash == canonical_hash(graph) ||
        throw(ArgumentError("3-D input binding G2 graph identity is foreign"))
    binding.ast_root_identity_hashes == graph.ast_root_identity_hashes ||
        throw(ArgumentError("3-D input binding AST identities are foreign"))
    binding.mission_hash == _runtime_decl_hash(context.mission_payload) ||
        throw(ArgumentError("3-D input binding mission hash is foreign"))
    binding.bounds_hash == _runtime_decl_hash(context.bounds_payload) ||
        throw(ArgumentError("3-D input binding bounds hash is foreign"))
    binding.scenario_hash == context.scenario_hash ||
        throw(ArgumentError("3-D input binding scenario hash is foreign"))
    binding
end

"""Compile exact current-context gaps without selecting or invoking a provider."""
function resolve_three_d_physical_provider_input(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    declarations = Tuple(x for x in context.candidate.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDPhysicalProviderInputV4)
    bindings = Tuple(x for x in context.subject.bindings
        if typeof(x) === ThreeDPhysicalProviderInputBindingV4)
    gaps = String[]
    declaration_hash = nothing
    binding_hash = nothing
    declaration = nothing
    if isempty(declarations)
        append!(gaps, _TDPI_REQUIRED_GAPS[1:3])
    elseif length(declarations) > 1
        push!(gaps, "ambiguous_typed_three_d_geometry_profile_declaration")
    else
        declaration = only(declarations)
        declaration_hash = canonical_hash(declaration)
    end
    append!(gaps, _TDPI_REQUIRED_GAPS[4:7])
    if isempty(bindings)
        push!(gaps, _TDPI_REQUIRED_GAPS[8])
    elseif length(bindings) > 1
        push!(gaps, "ambiguous_three_d_physical_provider_input_subject_binding")
    elseif declaration !== nothing
        binding = _tdpi_context_binding(context, declaration)
        binding_hash = canonical_hash(binding)
    else
        throw(ArgumentError("typed 3-D input binding has no current G2 declaration"))
    end
    _tdpi_resolution(context.context_hash, declaration_hash, binding_hash,
        Tuple(gaps))
end

three_d_physical_provider_input_manifest() = (
    schema=_TDPI_SCHEMA, revision=_TDPI_REVISION,
    purpose=:typed_three_d_geometry_profile_gap_compiler,
    statuses=(:input_complete, :recoverable_gap),
    implemented_status=:recoverable_gap,
    deferred_input_complete_edges=_TDPI_REQUIRED_GAPS[4:7],
    model_class=:manufactured_input_fixture,
    claim_ceiling=screen_only, provider_selected=false,
    solver_executed=false, emits_evidence=false,
    physical_validation=false, engineering_validation=false,
    terminal_authority=false, p5_ready=false,
    credible_physical_device_count=0)
