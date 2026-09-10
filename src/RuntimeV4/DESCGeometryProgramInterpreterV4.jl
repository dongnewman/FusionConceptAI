"""Candidate-bound, screen-only DESC Fourier geometry interpreter."""

using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _DGPI_REVISION = "runtime-v4-desc-geometry-program-interpreter-v1"
const _DGPI_SCHEMA = "fusionconceptai:runtime-v4-desc-geometry-program-interpreter"
const _DGPI_NCOORD_REF = OperatorRefV1(
    "RUNTIME_V4_DESC_NORMALIZED_FOURIER_COORDINATE", "v1")
const _DGPI_NMETRIC_REF = OperatorRefV1(
    "RUNTIME_V4_DESC_NORMALIZED_ANALYTIC_METRIC", "v1")
const _DGPI_COORD_REF = OperatorRefV1(
    "RUNTIME_V4_SUPPORT_SCALE_COORDINATE", "v1")
const _DGPI_METRIC_REF = OperatorRefV1(
    "RUNTIME_V4_SUPPORT_SCALE_METRIC", "v1")
const _DGPI_DOMAIN = ((0.0, 1.0), (0.0, 1.0), (0.0, 1.0))

_dgpi_chart_type() = chart_coordinate_type_v1()
_dgpi_payload_type() = PhysicalType(:desc_fourier_geometry_payload, 0, 3,
    TemporalTypeV1(static_time), UnitSignature())
_dgpi_normalized_coordinate_type() = normalized_ambient_coordinate_type_v1()
_dgpi_normalized_metric_type() = normalized_covariant_metric_type_v1()
_dgpi_length_type() = PhysicalType(:support_scale, 0, 3,
    TemporalTypeV1(static_time), _tdpi_length_unit())
_dgpi_metric_scale_type() = PhysicalType(:support_scale_squared, 0, 3,
    TemporalTypeV1(static_time), _tdpi_metric_unit())
_dgpi_coordinate_type() = PhysicalType(:physical_coordinate_map, 1, 3,
    TemporalTypeV1(static_time), _tdpi_length_unit())
_dgpi_metric_type() = PhysicalType(:covariant_metric, 2, 3,
    TemporalTypeV1(static_time), _tdpi_metric_unit())

function _dgpi_int(value, label::String; minimum::Int, maximum::Int)
    value isa Bool && throw(ArgumentError("$label must be an integer"))
    typeof(value) <: Integer || throw(ArgumentError("$label must be an integer"))
    typemin(Int) <= value <= typemax(Int) ||
        throw(ArgumentError("$label is out of range"))
    result = Int(value)
    minimum <= result <= maximum ||
        throw(ArgumentError("$label is outside its admitted range"))
    result
end

function _dgpi_finite(value, label::String)
    value isa Bool && throw(ArgumentError("$label must be numeric"))
    value isa Real || throw(ArgumentError("$label must be numeric"))
    result = Float64(value)
    isfinite(result) || throw(ArgumentError("$label must be finite"))
    result == 0.0 ? 0.0 : result
end

struct DESCFourierProgramModeV4
    poloidal_mode::Int
    toroidal_mode::Int
    normalized_coefficient::Float64
    radial_power::Int
    function DESCFourierProgramModeV4(poloidal_mode, toroidal_mode,
            normalized_coefficient, radial_power)
        new(_dgpi_int(poloidal_mode, "poloidal mode"; minimum=-64, maximum=64),
            _dgpi_int(toroidal_mode, "toroidal mode"; minimum=-64, maximum=64),
            _dgpi_finite(normalized_coefficient, "normalized coefficient"),
            _dgpi_int(radial_power, "radial power"; minimum=0, maximum=64))
    end
end
semantic_view(x::DESCFourierProgramModeV4) = (
    poloidal_mode=x.poloidal_mode, toroidal_mode=x.toroidal_mode,
    normalized_coefficient=x.normalized_coefficient,
    radial_power=x.radial_power)

"""Closed payload; fixed-boundary data do not silently define the radial law."""
struct DESCFourierGeometryProgramV4
    boundary::ThreeDFourierBoundaryV4
    support_scale::NonnegativeQuantityV1
    radial_modes::Tuple{Vararg{DESCFourierProgramModeV4}}
    vertical_modes::Tuple{Vararg{DESCFourierProgramModeV4}}
    radial_law::Symbol
    domain::NTuple{3,Tuple{Float64,Float64}}
    function DESCFourierGeometryProgramV4(
            boundary::ThreeDFourierBoundaryV4,
            support_scale::NonnegativeQuantityV1,
            radial_powers, vertical_powers)
        support_scale.unit == _tdpi_length_unit() && support_scale.value > 0 ||
            throw(ArgumentError("support scale must be a positive SI length"))
        radial_powers isa Tuple && vertical_powers isa Tuple &&
            length(radial_powers) == length(boundary.radial_coefficients) &&
            length(vertical_powers) == length(boundary.vertical_coefficients) ||
            throw(ArgumentError("radial powers must map every Fourier mode exactly"))
        scale = Float64(support_scale.value)
        radial = Tuple(DESCFourierProgramModeV4(c.poloidal_mode,
            c.toroidal_mode, c.coefficient_m / scale, radial_powers[i])
            for (i, c) in enumerate(boundary.radial_coefficients))
        vertical = Tuple(DESCFourierProgramModeV4(c.poloidal_mode,
            c.toroidal_mode, c.coefficient_m / scale, vertical_powers[i])
            for (i, c) in enumerate(boundary.vertical_coefficients))
        for mode in radial
            if mode.poloidal_mode == 0 && mode.toroidal_mode == 0
                mode.radial_power == 0 ||
                    throw(ArgumentError("R00 must be the explicit axis term"))
            else
                mode.radial_power >= 1 ||
                    throw(ArgumentError("non-axis radial modes must vanish at rho=0"))
            end
        end
        all(mode -> mode.radial_power >= 1, vertical) ||
            throw(ArgumentError("vertical modes must vanish at rho=0"))
        boundary.stellarator_symmetric && 2 <= boundary.field_periods <= 8 ||
            throw(ArgumentError("interpreter requires the admitted symmetric DESC boundary"))
        new(boundary, support_scale, radial, vertical,
            :explicit_power_per_mode, _DGPI_DOMAIN)
    end
end
semantic_view(x::DESCFourierGeometryProgramV4) = (
    revision=_DGPI_REVISION, boundary=x.boundary,
    support_scale=x.support_scale, radial_modes=x.radial_modes,
    vertical_modes=x.vertical_modes, radial_law=x.radial_law,
    domain=x.domain)
canonical_hash(x::DESCFourierGeometryProgramV4) = canonical_hash(semantic_view(x))

function _dgpi_ast_payload(program::DESCFourierGeometryProgramV4)
    (schema=_DGPI_SCHEMA, revision=_DGPI_REVISION,
     boundary_hash=canonical_hash(program.boundary),
     support_scale_value=program.support_scale.value,
     radial_powers=Tuple(mode.radial_power for mode in program.radial_modes),
     vertical_powers=Tuple(mode.radial_power for mode in program.vertical_modes),
     radial_law=program.radial_law, domain=program.domain,
     program_hash=canonical_hash(program))
end

function _dgpi_program_from_ast_payload(payload, boundary, support_scale)
    payload isa NamedTuple ||
        throw(ArgumentError("geometry AST payload schema mismatch"))
    keys(payload) == (:schema, :revision, :boundary_hash,
        :support_scale_value, :radial_powers, :vertical_powers,
        :radial_law, :domain, :program_hash) ||
        throw(ArgumentError("geometry AST payload schema mismatch"))
    program = DESCFourierGeometryProgramV4(boundary, support_scale,
        payload.radial_powers, payload.vertical_powers)
    payload == _dgpi_ast_payload(program) ||
        throw(ArgumentError("geometry AST payload is foreign to the declaration"))
    program
end

function _dgpi_validate_program_payload(program::DESCFourierGeometryProgramV4)
    program.radial_law === :explicit_power_per_mode &&
        program.domain == _DGPI_DOMAIN ||
        throw(ArgumentError("DESC geometry program payload schema mismatch"))
    scale = Float64(program.support_scale.value)
    length(program.radial_modes) == length(program.boundary.radial_coefficients) &&
        length(program.vertical_modes) == length(program.boundary.vertical_coefficients) ||
        throw(ArgumentError("DESC geometry program mode coverage mismatch"))
    for (mode, coefficient) in zip(program.radial_modes,
            program.boundary.radial_coefficients)
        (mode.poloidal_mode, mode.toroidal_mode,
            mode.normalized_coefficient) ==
            (coefficient.poloidal_mode, coefficient.toroidal_mode,
             coefficient.coefficient_m / scale) ||
            throw(ArgumentError("radial program mode is foreign to the boundary"))
        ((mode.poloidal_mode == 0 && mode.toroidal_mode == 0 &&
          mode.radial_power == 0) ||
         ((mode.poloidal_mode != 0 || mode.toroidal_mode != 0) &&
          mode.radial_power >= 1)) ||
            throw(ArgumentError("radial program mode has an invalid axis law"))
    end
    for (mode, coefficient) in zip(program.vertical_modes,
            program.boundary.vertical_coefficients)
        (mode.poloidal_mode, mode.toroidal_mode,
            mode.normalized_coefficient) ==
            (coefficient.poloidal_mode, coefficient.toroidal_mode,
             coefficient.coefficient_m / scale) && mode.radial_power >= 1 ||
            throw(ArgumentError("vertical program mode is foreign to the boundary"))
    end
    canonical_hash(program)
end

function _dgpi_chart(program::DESCFourierGeometryProgramV4, input)
    input isa Tuple && !(input isa NamedTuple) && length(input) == 3 ||
        throw(ArgumentError("chart input must be an immutable (rho,theta,zeta) tuple"))
    q = ntuple(i -> _dgpi_finite(input[i],
        ("rho", "theta turn", "field-period turn")[i]), 3)
    all(0.0 <= q[i] <= 1.0 for i in 1:3) ||
        throw(ArgumentError("chart input must lie in the exact [0,1]^3 domain"))
    program.domain == _DGPI_DOMAIN ||
        throw(ArgumentError("program domain is not the exact turn-coordinate domain"))
    q
end

function _dgpi_mode_terms(modes, rho, theta, zeta, basis::Symbol)
    value = 0.0; radial = 0.0; poloidal = 0.0; toroidal = 0.0
    for mode in modes
        power = mode.radial_power
        factor = power == 0 ? 1.0 : rho^power
        derivative = power == 0 ? 0.0 :
            power * (rho == 0.0 && power == 1 ? 1.0 : rho^(power - 1))
        phase = mode.poloidal_mode * theta - mode.toroidal_mode * zeta
        cosine = cospi(2 * phase); sine = sinpi(2 * phase)
        coefficient = mode.normalized_coefficient
        if basis === :cosine
            value += coefficient * factor * cosine
            radial += coefficient * derivative * cosine
            poloidal -= 2pi * mode.poloidal_mode * coefficient * factor * sine
            toroidal += 2pi * mode.toroidal_mode * coefficient * factor * sine
        elseif basis === :sine
            value += coefficient * factor * sine
            radial += coefficient * derivative * sine
            poloidal += 2pi * mode.poloidal_mode * coefficient * factor * cosine
            toroidal -= 2pi * mode.toroidal_mode * coefficient * factor * cosine
        else
            throw(ArgumentError("unknown Fourier basis"))
        end
    end
    ntuple(i -> _dgpi_finite((value, radial, poloidal, toroidal)[i],
        "Fourier evaluation"), 4)
end

function _dgpi_normalized_geometry(program::DESCFourierGeometryProgramV4,
        input)
    _dgpi_validate_program_payload(program)
    rho, theta, zeta = _dgpi_chart(program, input)
    R, Rrho, Rtheta, Rzeta = _dgpi_mode_terms(
        program.radial_modes, rho, theta, zeta, :cosine)
    Z, Zrho, Ztheta, Zzeta = _dgpi_mode_terms(
        program.vertical_modes, rho, theta, zeta, :sine)
    azimuth = zeta / program.boundary.field_periods
    cosine = cospi(2 * azimuth); sine = sinpi(2 * azimuth)
    k = 2pi / program.boundary.field_periods
    coordinate = (R * cosine, R * sine, Z)
    jacobian = (
        (Rrho * cosine, Rtheta * cosine, Rzeta * cosine - k * R * sine),
        (Rrho * sine, Rtheta * sine, Rzeta * sine + k * R * cosine),
        (Zrho, Ztheta, Zzeta))
    clean_coordinate = ntuple(i -> _dgpi_finite(coordinate[i],
        "normalized coordinate"), 3)
    clean_jacobian = ntuple(i -> ntuple(j -> _dgpi_finite(
        jacobian[i][j], "normalized Jacobian"), 3), 3)
    metric = ntuple(i -> ntuple(j -> _dgpi_finite(sum(
        clean_jacobian[k0][i] * clean_jacobian[k0][j] for k0 in 1:3),
        "normalized metric"), 3), 3)
    (coordinate=clean_coordinate, jacobian=clean_jacobian, metric=metric)
end

desc_normalized_coordinate(program::DESCFourierGeometryProgramV4, input) =
    _dgpi_normalized_geometry(program, input).coordinate
desc_normalized_jacobian(program::DESCFourierGeometryProgramV4, input) =
    _dgpi_normalized_geometry(program, input).jacobian
desc_normalized_metric(program::DESCFourierGeometryProgramV4, input) =
    _dgpi_normalized_geometry(program, input).metric
_dgpi_scale_vector(value, scale) = ntuple(i -> _dgpi_finite(
    scale * value[i], "SI coordinate"), 3)
_dgpi_scale_matrix(value, scale, label) = ntuple(i -> ntuple(j ->
    _dgpi_finite(scale * value[i][j], label), 3), 3)
desc_coordinate(program::DESCFourierGeometryProgramV4, input) =
    _dgpi_scale_vector(desc_normalized_coordinate(program, input),
        Float64(program.support_scale.value))
desc_coordinate_jacobian(program::DESCFourierGeometryProgramV4, input) =
    _dgpi_scale_matrix(desc_normalized_jacobian(program, input),
        Float64(program.support_scale.value), "SI Jacobian")
desc_metric(program::DESCFourierGeometryProgramV4, input) =
    _dgpi_scale_matrix(desc_normalized_metric(program, input),
        Float64(program.support_scale.value)^2, "SI metric")

function _dgpi_manifest(ref, inputs, output)
    rule = ExactTypeRuleV1(inputs, (output,))
    OperatorManifestV1(ref, length(inputs), 1, rule, rule;
        allowed_roles=(:constraint,), locality=:local, pure=true,
        stateful=false, stochastic=false, event=false,
        parameter_schema=(), allowed_conservation_effects=(),
        forbidden_conservation_effects=())
end

function desc_geometry_operator_registry()
    registry = default_operator_registry()
    for manifest in (
            _dgpi_manifest(_DGPI_NCOORD_REF,
                (_dgpi_chart_type(), _dgpi_payload_type()),
                _dgpi_normalized_coordinate_type()),
            _dgpi_manifest(_DGPI_NMETRIC_REF,
                (_dgpi_chart_type(), _dgpi_payload_type()),
                _dgpi_normalized_metric_type()),
            _dgpi_manifest(_DGPI_COORD_REF,
                (_dgpi_normalized_coordinate_type(), _dgpi_length_type()),
                _dgpi_coordinate_type()),
            _dgpi_manifest(_DGPI_METRIC_REF,
                (_dgpi_normalized_metric_type(), _dgpi_metric_scale_type()),
                _dgpi_metric_type()))
        registry = register_operator(registry, manifest)
    end
    registry
end

struct DESCGeometryProgramBindingV4
    program::DESCFourierGeometryProgramV4
    coordinate_site_ref::FieldOperatorSiteRefV1
    metric_site_ref::FieldOperatorSiteRefV1
    coordinate_program::TypedASTProgramV1
    metric_program::TypedASTProgramV1
    coordinate_edge::AtomicMIMOHyperedgeV1
    metric_edge::AtomicMIMOHyperedgeV1
    registry::OperatorRegistryV1
end
semantic_view(x::DESCGeometryProgramBindingV4) = (
    program_hash=canonical_hash(x.program),
    coordinate_site_ref=x.coordinate_site_ref,
    metric_site_ref=x.metric_site_ref,
    coordinate_program_hash=canonical_hash(x.coordinate_program),
    metric_program_hash=canonical_hash(x.metric_program),
    coordinate_edge_hash=canonical_hash(x.coordinate_edge),
    metric_edge_hash=canonical_hash(x.metric_edge),
    registry_hash=canonical_hash(x.registry))
canonical_hash(x::DESCGeometryProgramBindingV4) = canonical_hash(semantic_view(x))

function _dgpi_ast_program(program, normalized_ref, normalized_type,
        scale_ref, scale_type, scale_value, physical_type, registry)
    nodes = (
        ASTInputV1(1, _dgpi_chart_type()),
        ASTConstantV1(:desc_fourier_geometry_payload,
            _dgpi_ast_payload(program),
            _dgpi_payload_type()),
        ASTApplyV1(normalized_ref, (1, 2), (;); registry=registry,
            input_types=(_dgpi_chart_type(), _dgpi_payload_type())),
        ASTConstantV1(:support_scale, scale_value, scale_type),
        ASTApplyV1(scale_ref, (3, 4), (;); registry=registry,
            input_types=(normalized_type, scale_type)))
    nodes[5].output_type == physical_type ||
        throw(ArgumentError("geometry scale operator output type mismatch"))
    TypedASTProgramV1(nodes, (3, 5), (1,); registry=registry)
end

function desc_geometry_typed_binding(program::DESCFourierGeometryProgramV4,
        coordinate_site_ref::FieldOperatorSiteRefV1,
        metric_site_ref::FieldOperatorSiteRefV1)
    coordinate_site_ref != metric_site_ref ||
        throw(ArgumentError("coordinate and metric sites must differ"))
    _dgpi_validate_program_payload(program)
    registry = desc_geometry_operator_registry()
    coordinate_program = _dgpi_ast_program(program, _DGPI_NCOORD_REF,
        _dgpi_normalized_coordinate_type(), _DGPI_COORD_REF,
        _dgpi_length_type(), program.support_scale.value,
        _dgpi_coordinate_type(), registry)
    metric_program = _dgpi_ast_program(program, _DGPI_NMETRIC_REF,
        _dgpi_normalized_metric_type(), _DGPI_METRIC_REF,
        _dgpi_metric_scale_type(), program.support_scale.value^2,
        _dgpi_metric_type(), registry)
    coordinate_edge = AtomicMIMOHyperedgeV1(coordinate_site_ref.value,
        (MIMOInputBindingV1(1, 1),),
        (MIMOOutputBindingV1(1, 2), MIMOOutputBindingV1(2, 3)),
        coordinate_program, constraint; registry=registry)
    metric_edge = AtomicMIMOHyperedgeV1(metric_site_ref.value,
        (MIMOInputBindingV1(1, 1),),
        (MIMOOutputBindingV1(1, 4), MIMOOutputBindingV1(2, 5)),
        metric_program, constraint; registry=registry)
    result = DESCGeometryProgramBindingV4(program, coordinate_site_ref,
        metric_site_ref, coordinate_program, metric_program,
        coordinate_edge, metric_edge, registry)
    canonical_hash(result)
    result
end

function _dgpi_unit_turn_chart(chart)
    all(bound -> bound.unit == UnitSignature() &&
        bound.interval.lower == 0//1 && bound.interval.upper == 1//1 &&
        !bound.interval.allow_equal, chart.chart_bounds) &&
        Tuple(axis.axis_position for axis in chart.periodic_axes) == (2, 3) &&
        all(axis -> axis.period.unit == UnitSignature() &&
            axis.period.value == 1//1, chart.periodic_axes)
end

function _dgpi_candidate_program(context, bridge_resolution)
    validate_forward_chain_context(context)
    bridge_resolution.status === :bridge_ready ||
        throw(ArgumentError("geometry interpreter requires a bridge-ready result"))
    validate_three_d_normalized_physical_root_bridge(context,
        bridge_resolution)
    declarations, bindings = _tdnprb_inventory(context)
    length(declarations) == 1 && length(bindings) == 1 ||
        throw(ArgumentError("geometry declaration/binding is missing or ambiguous"))
    declaration = only(declarations)
    canonical_hash(only(bindings)) ==
        canonical_hash(_tdpi_context_binding(context, declaration)) ||
        throw(ArgumentError("geometry declaration binding is foreign"))
    coordinate = declaration.coordinate_metric
    support, chart = _tdnprb_support_chart(context.candidate, coordinate)
    _dgpi_unit_turn_chart(chart) ||
        throw(ArgumentError("geometry interpreter requires exact unit-turn axes"))
    graph = forward_graph_binding(context, :field_geometry)
    coordinate_position, coordinate_edge = _tdnprb_edge(
        graph, coordinate.coordinate_map_site_ref)
    metric_position, metric_edge = _tdnprb_edge(graph,
        coordinate.metric_site_ref)
    coordinate_edge isa AtomicMIMOHyperedgeV1 &&
        metric_edge isa AtomicMIMOHyperedgeV1 ||
        throw(ArgumentError("geometry interpreter requires AtomicMIMO programs"))
    coordinate_nodes = coordinate_edge.program.nodes
    metric_nodes = metric_edge.program.nodes
    length(coordinate_nodes) == 5 && length(metric_nodes) == 5 &&
        coordinate_nodes[2] isa ASTConstantV1 &&
        metric_nodes[2] isa ASTConstantV1 &&
        coordinate_nodes[2].value isa NamedTuple &&
        metric_nodes[2].value isa NamedTuple ||
        throw(ArgumentError("geometry programs lack the sealed Fourier payload"))
    coordinate_nodes[2].value == metric_nodes[2].value ||
        throw(ArgumentError("coordinate and metric programs use different payloads"))
    program = _dgpi_program_from_ast_payload(coordinate_nodes[2].value,
        declaration.fourier_boundary, support.resolution_independent_scale)
    expected = desc_geometry_typed_binding(program,
        coordinate.coordinate_map_site_ref, coordinate.metric_site_ref)
    canonical_hash(coordinate_edge) == canonical_hash(expected.coordinate_edge) &&
        semantic_view(coordinate_edge) == semantic_view(expected.coordinate_edge) &&
        canonical_hash(metric_edge) == canonical_hash(expected.metric_edge) &&
        semantic_view(metric_edge) == semantic_view(expected.metric_edge) ||
        throw(ArgumentError("candidate geometry AST or manifest binding is not exact"))
    audit = something(bridge_resolution.audit)
    coordinate_roots = Tuple(_tdnprb_root(graph, coordinate_position,
        coordinate_edge, i) for i in 1:2)
    metric_roots = Tuple(_tdnprb_root(graph, metric_position,
        metric_edge, i) for i in 1:2)
    Tuple(root.identity_hash for root in coordinate_roots) ==
        (audit.normalized_coordinate_root_identity_hash,
         audit.physical_coordinate_root_identity_hash) &&
        Tuple(root.identity_hash for root in metric_roots) ==
        (audit.normalized_metric_root_identity_hash,
         audit.physical_metric_root_identity_hash) ||
        throw(ArgumentError("geometry roots do not match the validated bridge"))
    (program=program, declaration=declaration, support=support, chart=chart,
     graph=graph, coordinate_edge=coordinate_edge,
     metric_edge=metric_edge, coordinate_position=coordinate_position,
     metric_position=metric_position)
end

function _dgpi_determinant(matrix)
    value = matrix[1][1] * (matrix[2][2] * matrix[3][3] -
        matrix[2][3] * matrix[3][2]) -
        matrix[1][2] * (matrix[2][1] * matrix[3][3] -
        matrix[2][3] * matrix[3][1]) +
        matrix[1][3] * (matrix[2][1] * matrix[3][2] -
        matrix[2][2] * matrix[3][1])
    _dgpi_finite(value, "Jacobian determinant")
end

function _dgpi_evaluation_body(context, bridge_resolution, data, input,
        normalized, coordinate, normalized_determinant, si_determinant)
    (revision=_DGPI_REVISION,
     evaluation_kind=:desc_geometry_program_interpretation,
     status=:interpreted, context_hash=context.context_hash,
     candidate_hash=context.candidate_hash,
     compiled_prefix_hash=context.compiled.prefix_hash,
     registry_hash=context.registry_hash,
     physical_subject_hash=context.subject.physical_subject_hash,
     declaration_hash=canonical_hash(data.declaration),
     support_hash=canonical_hash(data.support), chart_hash=canonical_hash(data.chart),
     graph_binding_hash=data.graph.binding_hash,
     coordinate_edge_identity_hash=_forward_edge_identity(
        data.coordinate_edge, data.coordinate_position),
     metric_edge_identity_hash=_forward_edge_identity(
        data.metric_edge, data.metric_position),
     coordinate_program_hash=canonical_hash(data.coordinate_edge.program),
     metric_program_hash=canonical_hash(data.metric_edge.program),
     bridge_resolution_hash=canonical_hash(bridge_resolution),
     payload_hash=canonical_hash(data.program),
     support_scale=Float64(data.program.support_scale.value), input=input,
     normalized_coordinate=normalized.coordinate,
     normalized_jacobian=normalized.jacobian,
     normalized_metric=normalized.metric,
     coordinate=coordinate.coordinate, jacobian=coordinate.jacobian,
     metric=coordinate.metric,
     normalized_determinant=normalized_determinant,
     si_determinant=si_determinant, axis_degenerate=input[1] == 0.0,
     local_jacobian_singular=si_determinant == 0.0,
     geometry_program_interpreted=true,
     model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
     geometry_proved=false, certificate_emitted=false,
     request_emitted=false, provider_selected=false, provider_executed=false,
     solver_execution_attempted=false, solver_executed=false,
     physical_validation=false, engineering_validation=false,
     emits_evidence=false, grants_pass=false, promotion_authority=false,
     p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

mutable struct _DGPIPrivateToken end
const _DGPI_TOKEN = _DGPIPrivateToken()

struct DESCGeometryProgramEvaluationV4
    revision::String
    evaluation_kind::Symbol
    status::Symbol
    context_hash::Digest256
    candidate_hash::Digest256
    compiled_prefix_hash::Digest256
    registry_hash::Digest256
    physical_subject_hash::Digest256
    declaration_hash::Digest256
    support_hash::Digest256
    chart_hash::Digest256
    graph_binding_hash::Digest256
    coordinate_edge_identity_hash::Digest256
    metric_edge_identity_hash::Digest256
    coordinate_program_hash::Digest256
    metric_program_hash::Digest256
    bridge_resolution_hash::Digest256
    payload_hash::Digest256
    support_scale::Float64
    input::NTuple{3,Float64}
    normalized_coordinate::NTuple{3,Float64}
    normalized_jacobian::NTuple{3,NTuple{3,Float64}}
    normalized_metric::NTuple{3,NTuple{3,Float64}}
    coordinate::NTuple{3,Float64}
    jacobian::NTuple{3,NTuple{3,Float64}}
    metric::NTuple{3,NTuple{3,Float64}}
    normalized_determinant::Float64
    si_determinant::Float64
    axis_degenerate::Bool
    local_jacobian_singular::Bool
    geometry_program_interpreted::Bool
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    geometry_proved::Bool
    certificate_emitted::Bool
    request_emitted::Bool
    provider_selected::Bool
    provider_executed::Bool
    solver_execution_attempted::Bool
    solver_executed::Bool
    physical_validation::Bool
    engineering_validation::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    evaluation_hash::Digest256
    function DESCGeometryProgramEvaluationV4(token::_DGPIPrivateToken,
            fields...)
        token === _DGPI_TOKEN ||
            throw(ArgumentError("private DESC geometry evaluation constructor"))
        new(fields...)
    end
end

_dgpi_evaluation_values(x::DESCGeometryProgramEvaluationV4) =
    ntuple(i -> getfield(x, i), fieldcount(typeof(x)) - 1)
function _dgpi_evaluation_body_from_values(values...)
    NamedTuple{fieldnames(DESCGeometryProgramEvaluationV4)[1:end-1]}(values)
end
semantic_view(x::DESCGeometryProgramEvaluationV4) = merge(
    _dgpi_evaluation_body_from_values(_dgpi_evaluation_values(x)...),
    (evaluation_hash=x.evaluation_hash,))

function canonical_hash(x::DESCGeometryProgramEvaluationV4)
    body = _dgpi_evaluation_body_from_values(_dgpi_evaluation_values(x)...)
    expected = canonical_hash(body)
    expected == x.evaluation_hash ||
        throw(ArgumentError("DESC geometry evaluation hash mismatch"))
    x.revision == _DGPI_REVISION &&
        x.evaluation_kind === :desc_geometry_program_interpretation &&
        x.status === :interpreted && x.geometry_program_interpreted ||
        throw(ArgumentError("DESC geometry evaluation schema mismatch"))
    all(isfinite, x.input) && all(isfinite, x.normalized_coordinate) &&
        all(isfinite, Iterators.flatten(x.normalized_jacobian)) &&
        all(isfinite, Iterators.flatten(x.normalized_metric)) &&
        all(isfinite, x.coordinate) &&
        all(isfinite, Iterators.flatten(x.jacobian)) &&
        all(isfinite, Iterators.flatten(x.metric)) &&
        isfinite(x.normalized_determinant) && isfinite(x.si_determinant) ||
        throw(ArgumentError("DESC geometry evaluation contains non-finite output"))
    isfinite(x.support_scale) && x.support_scale > 0.0 ||
        throw(ArgumentError("DESC geometry evaluation has invalid support scale"))
    x.coordinate == _dgpi_scale_vector(
        x.normalized_coordinate, x.support_scale) &&
        x.jacobian == _dgpi_scale_matrix(
            x.normalized_jacobian, x.support_scale, "SI Jacobian") &&
        x.metric == _dgpi_scale_matrix(
            x.normalized_metric, x.support_scale^2, "SI metric") ||
        throw(ArgumentError("DESC geometry evaluation violates SI scaling"))
    expected_normalized_metric = ntuple(i -> ntuple(j -> _dgpi_finite(sum(
        x.normalized_jacobian[k][i] * x.normalized_jacobian[k][j]
        for k in 1:3), "normalized metric"), 3), 3)
    x.normalized_metric == expected_normalized_metric &&
        x.normalized_determinant == _dgpi_determinant(x.normalized_jacobian) &&
        x.si_determinant == _dgpi_determinant(x.jacobian) &&
        x.axis_degenerate == (x.input[1] == 0.0) &&
        x.local_jacobian_singular == (x.si_determinant == 0.0) ||
        throw(ArgumentError("DESC geometry evaluation violates analytic invariants"))
    x.model_class === :manufactured_input_fixture &&
        x.claim_ceiling == screen_only && !x.geometry_proved &&
        !x.certificate_emitted && !x.request_emitted &&
        !x.provider_selected && !x.provider_executed &&
        !x.solver_execution_attempted && !x.solver_executed &&
        !x.physical_validation && !x.engineering_validation &&
        !x.emits_evidence && !x.grants_pass && !x.promotion_authority &&
        !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("DESC geometry evaluation exceeded authority ceiling"))
    expected
end

function interpret_desc_geometry_program(context::ForwardChainContextV4,
        bridge_resolution::ThreeDNormalizedPhysicalRootBridgeResolutionV4,
        input)
    data = _dgpi_candidate_program(context, bridge_resolution)
    q = _dgpi_chart(data.program, input)
    normalized = _dgpi_normalized_geometry(data.program, q)
    scale = Float64(data.program.support_scale.value)
    coordinate = (
        coordinate=_dgpi_scale_vector(normalized.coordinate, scale),
        jacobian=_dgpi_scale_matrix(normalized.jacobian, scale, "SI Jacobian"),
        metric=_dgpi_scale_matrix(normalized.metric, scale^2, "SI metric"))
    normalized_determinant = _dgpi_determinant(normalized.jacobian)
    si_determinant = _dgpi_determinant(coordinate.jacobian)
    body = _dgpi_evaluation_body(context, bridge_resolution, data, q,
        normalized, coordinate, normalized_determinant, si_determinant)
    result = DESCGeometryProgramEvaluationV4(_DGPI_TOKEN,
        values(body)..., canonical_hash(body))
    canonical_hash(result)
    result
end

function validate_desc_geometry_program_evaluation(
        context::ForwardChainContextV4,
        bridge_resolution::ThreeDNormalizedPhysicalRootBridgeResolutionV4,
        evaluation::DESCGeometryProgramEvaluationV4)
    canonical_hash(evaluation)
    rebuilt = interpret_desc_geometry_program(context, bridge_resolution,
        evaluation.input)
    canonical_hash(rebuilt) == evaluation.evaluation_hash &&
        semantic_view(rebuilt) == semantic_view(evaluation) ||
        throw(ArgumentError("DESC geometry evaluation is foreign to context"))
    evaluation.evaluation_hash
end

desc_geometry_program_interpreter_manifest() = (
    schema=_DGPI_SCHEMA, revision=_DGPI_REVISION, status=:interpreted,
    radial_law=:explicit_power_per_mode, exact_domain=_DGPI_DOMAIN,
    geometry_program_interpreted=true, geometry_proved=false,
    certificate_emitted=false, request_emitted=false,
    provider_selected=false, provider_executed=false,
    solver_execution_attempted=false, solver_executed=false,
    physical_validation=false, engineering_validation=false,
    emits_evidence=false, grants_pass=false, promotion_authority=false,
    claim_ceiling=screen_only, p5_ready=false, terminal_authority=false,
    credible_physical_device_count=0)
