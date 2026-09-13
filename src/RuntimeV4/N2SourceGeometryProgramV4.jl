"""Source-owned Fourier-Zernike G2 coordinate/metric AST slice.

The graph and evaluator are screen-only. The old monomial DESC interpreter,
default registry, geometry compatibility proof, and provider gates are not
changed by this additive source-basis program.
"""
module N2SourceGeometryProgramRuntime
using FusionConceptAI
using SHA
import FusionConceptAI: canonical_hash, semantic_view
include(joinpath(@__DIR__, "N2SourceFourierZernikeV4.jl"))
const N2Z = N2SourceFourierZernikeRuntime

const _N2G_REVISION = "runtime-v4-n2-source-zernike-geometry-v1"
const _N2G_SCHEMA = "fusionconceptai:runtime-v4-n2-source-zernike-geometry"
const _N2G_PROGRAM_CODE_SHA = Digest256(bytes2hex(SHA.sha256(read(@__FILE__))))
const _N2G_SOURCE_EVALUATOR_SHA = Digest256(bytes2hex(SHA.sha256(read(
    joinpath(@__DIR__, "N2SourceFourierZernikeV4.jl")))))
const _N2G_BASIS_SEMANTICS = (
    radial="(-1)^k rho^abs(m) JacobiP(k,abs(m),0,1-2rho^2); k=(l-abs(m))/2",
    poloidal="positive mode cosine; negative mode sine; physical radians",
    toroidal="positive mode cosine; negative mode sine; n*NFP*physical_zeta",
    chart="rho, theta/(2pi), NFP*physical_zeta/(2pi)",
    metric="Cartesian Gram J_transpose_J with derivatives in unit-turn chart")
const _N2G_NCOORD = OperatorRefV1(
    "RUNTIME_V4_N2_SOURCE_ZERNIKE_NORMALIZED_COORDINATE", "v1")
const _N2G_NMETRIC = OperatorRefV1(
    "RUNTIME_V4_N2_SOURCE_ZERNIKE_NORMALIZED_METRIC", "v1")
const _N2G_COORD = OperatorRefV1("RUNTIME_V4_SUPPORT_SCALE_COORDINATE", "v1")
const _N2G_METRIC = OperatorRefV1("RUNTIME_V4_SUPPORT_SCALE_METRIC", "v1")
const _N2G_LENGTH = UnitSignature((0, 1, 0, 0, 0, 0, 0))
const _N2G_METRIC_UNIT = UnitSignature((0, 2, 0, 0, 0, 0, 0))

_chart_type() = chart_coordinate_type_v1()
_payload_type() = PhysicalType(:n2_source_zernike_geometry_payload, 0, 3,
    TemporalTypeV1(static_time), UnitSignature())
_ncoord_type() = normalized_ambient_coordinate_type_v1()
_nmetric_type() = normalized_covariant_metric_type_v1()
_length_type() = PhysicalType(:support_scale, 0, 3,
    TemporalTypeV1(static_time), _N2G_LENGTH)
_metric_scale_type() = PhysicalType(:support_scale_squared, 0, 3,
    TemporalTypeV1(static_time), _N2G_METRIC_UNIT)
_coordinate_type() = PhysicalType(:physical_coordinate_map, 1, 3,
    TemporalTypeV1(static_time), _N2G_LENGTH)
_metric_type() = PhysicalType(:covariant_metric, 2, 3,
    TemporalTypeV1(static_time), _N2G_METRIC_UNIT)

struct _N2GToken end
const _N2G_TOKEN = _N2GToken()

struct N2SourceGeometryProgramV4
    interior::N2Z.N2SourceInteriorV4
    support_scale::NonnegativeQuantityV1
    program_hash::Digest256
    function N2SourceGeometryProgramV4(::_N2GToken,
            interior::N2Z.N2SourceInteriorV4,
            support_scale::NonnegativeQuantityV1)
        interior.claim_ceiling === screen_only &&
            !interior.physical_validation && !interior.provider_selected &&
            !interior.solver_executed && interior.credible_device_count == 0 &&
            interior.selected_equilibrium_index == 3 &&
            interior.field_periods == 19 &&
            length(interior.radial_modes) == 598 &&
            length(interior.vertical_modes) == 585 &&
            support_scale.unit == _N2G_LENGTH && support_scale.value > 0 ||
            throw(ArgumentError("source geometry or SI support scale is not admitted"))
        body = (_N2G_SCHEMA, _N2G_REVISION,
            interior.source_artifact_sha256, interior.result_sha256,
            interior.subject_sha256, interior.selected_equilibrium_index,
            interior.field_periods, support_scale,
            _N2G_PROGRAM_CODE_SHA, _N2G_SOURCE_EVALUATOR_SHA,
            _N2G_BASIS_SEMANTICS)
        new(interior, support_scale, canonical_hash(body))
    end
end

semantic_view(program::N2SourceGeometryProgramV4) = (
    schema=_N2G_SCHEMA, revision=_N2G_REVISION,
    source_artifact_sha256=program.interior.source_artifact_sha256,
    interior_result_sha256=program.interior.result_sha256,
    interior_subject_sha256=program.interior.subject_sha256,
    selected_equilibrium_index=program.interior.selected_equilibrium_index,
    field_periods=program.interior.field_periods,
    radial_basis=:DESC_FourierZernike_fringe,
    radial_mode_count=length(program.interior.radial_modes),
    vertical_mode_count=length(program.interior.vertical_modes),
    support_scale=program.support_scale,
    evaluator_source_sha256=_N2G_SOURCE_EVALUATOR_SHA,
    program_code_sha256=_N2G_PROGRAM_CODE_SHA,
    basis_semantics=_N2G_BASIS_SEMANTICS,
    program_hash=program.program_hash)
canonical_hash(program::N2SourceGeometryProgramV4) = canonical_hash(semantic_view(program))

"""Load the exact source-owned spectrum; no manufactured radial-law fallback."""
function load_n2_source_geometry_program(source_path::AbstractString,
        result_path::AbstractString, expected_result_sha256::Digest256,
        support_scale::NonnegativeQuantityV1)
    interior = N2Z.load_n2_source_interior(source_path, result_path,
        expected_result_sha256)
    N2SourceGeometryProgramV4(_N2G_TOKEN, interior, support_scale)
end

function _ast_payload(program::N2SourceGeometryProgramV4)
    (schema=_N2G_SCHEMA, revision=_N2G_REVISION,
     source_artifact_sha256=program.interior.source_artifact_sha256,
     interior_result_sha256=program.interior.result_sha256,
     interior_subject_sha256=program.interior.subject_sha256,
     selected_equilibrium_index=program.interior.selected_equilibrium_index,
     field_periods=program.interior.field_periods,
     radial_basis=:DESC_FourierZernike_fringe,
     radial_mode_count=length(program.interior.radial_modes),
     vertical_mode_count=length(program.interior.vertical_modes),
     support_scale_value=program.support_scale.value,
     evaluator_source_sha256=_N2G_SOURCE_EVALUATOR_SHA,
     program_code_sha256=_N2G_PROGRAM_CODE_SHA,
     basis_semantics=_N2G_BASIS_SEMANTICS,
     program_hash=canonical_hash(program))
end

function _manifest(ref, inputs, output)
    rule = ExactTypeRuleV1(inputs, (output,))
    OperatorManifestV1(ref, length(inputs), 1, rule, rule;
        allowed_roles=(:constraint,), locality=:local, pure=true,
        stateful=false, stochastic=false, event=false,
        parameter_schema=(), allowed_conservation_effects=(),
        forbidden_conservation_effects=())
end

"""Candidate-local registry; default_operator_registry() remains untouched."""
function n2_source_geometry_registry()
    registry = default_operator_registry()
    for manifest in (
            _manifest(_N2G_NCOORD, (_chart_type(), _payload_type()),
                _ncoord_type()),
            _manifest(_N2G_NMETRIC, (_chart_type(), _payload_type()),
                _nmetric_type()),
            _manifest(_N2G_COORD, (_ncoord_type(), _length_type()),
                _coordinate_type()),
            _manifest(_N2G_METRIC, (_nmetric_type(), _metric_scale_type()),
                _metric_type()))
        registry = register_operator(registry, manifest)
    end
    registry
end

function _ast_program(program, normalized_ref, normalized_type,
        scale_ref, scale_type, scale_value, physical_type, registry)
    nodes = (
        ASTInputV1(1, _chart_type()),
        ASTConstantV1(:source_zernike_geometry_payload,
            _ast_payload(program), _payload_type()),
        ASTApplyV1(normalized_ref, (1, 2), (;); registry=registry,
            input_types=(_chart_type(), _payload_type())),
        ASTConstantV1(:support_scale, scale_value, scale_type),
        ASTApplyV1(scale_ref, (3, 4), (;); registry=registry,
            input_types=(normalized_type, scale_type)))
    nodes[5].output_type == physical_type ||
        throw(ArgumentError("source geometry scale output type mismatch"))
    TypedASTProgramV1(nodes, (3, 5), (1,); registry=registry)
end

struct N2SourceGeometryBindingV4
    program::N2SourceGeometryProgramV4
    coordinate_site_ref::FieldOperatorSiteRefV1
    metric_site_ref::FieldOperatorSiteRefV1
    coordinate_program::TypedASTProgramV1
    metric_program::TypedASTProgramV1
    coordinate_edge::AtomicMIMOHyperedgeV1
    metric_edge::AtomicMIMOHyperedgeV1
    registry::OperatorRegistryV1
end
semantic_view(binding::N2SourceGeometryBindingV4) = (
    program_hash=canonical_hash(binding.program),
    coordinate_site_ref=binding.coordinate_site_ref,
    metric_site_ref=binding.metric_site_ref,
    coordinate_program_hash=canonical_hash(binding.coordinate_program),
    metric_program_hash=canonical_hash(binding.metric_program),
    coordinate_edge_hash=canonical_hash(binding.coordinate_edge),
    metric_edge_hash=canonical_hash(binding.metric_edge),
    registry_hash=canonical_hash(binding.registry))
canonical_hash(binding::N2SourceGeometryBindingV4) = canonical_hash(semantic_view(binding))

function n2_source_geometry_typed_binding(program::N2SourceGeometryProgramV4,
        coordinate_site_ref::FieldOperatorSiteRefV1,
        metric_site_ref::FieldOperatorSiteRefV1)
    coordinate_site_ref != metric_site_ref ||
        throw(ArgumentError("coordinate and metric sites must differ"))
    registry = n2_source_geometry_registry()
    coordinate_program = _ast_program(program, _N2G_NCOORD,
        _ncoord_type(), _N2G_COORD, _length_type(),
        program.support_scale.value, _coordinate_type(), registry)
    metric_program = _ast_program(program, _N2G_NMETRIC,
        _nmetric_type(), _N2G_METRIC, _metric_scale_type(),
        program.support_scale.value^2, _metric_type(), registry)
    coordinate_edge = AtomicMIMOHyperedgeV1(coordinate_site_ref.value,
        (MIMOInputBindingV1(1, 1),),
        (MIMOOutputBindingV1(1, 2), MIMOOutputBindingV1(2, 3)),
        coordinate_program, constraint; registry=registry)
    metric_edge = AtomicMIMOHyperedgeV1(metric_site_ref.value,
        (MIMOInputBindingV1(1, 1),),
        (MIMOOutputBindingV1(1, 4), MIMOOutputBindingV1(2, 5)),
        metric_program, constraint; registry=registry)
    binding = N2SourceGeometryBindingV4(program, coordinate_site_ref,
        metric_site_ref, coordinate_program, metric_program,
        coordinate_edge, metric_edge, registry)
    canonical_hash(binding)
    binding
end

"""Build the typed G2 subgraph with distinct normalized and SI roots."""
function n2_source_geometry_graph(binding::N2SourceGeometryBindingV4)
    TypedOperatorHypergraphV1((
        node(:chart_coordinate, _chart_type(); id="source-chart-input"),
        node(:normalized_coordinate, _ncoord_type(); id="source-normalized-coordinate"),
        node(:physical_coordinate, _coordinate_type(); id="source-physical-coordinate"),
        node(:normalized_metric, _nmetric_type(); id="source-normalized-metric"),
        node(:physical_metric, _metric_type(); id="source-physical-metric")),
        (binding.coordinate_edge, binding.metric_edge); registry=binding.registry)
end

struct N2SourceUnitTurnChartV4
    rho::Float64
    theta_turn::Float64
    period_turn::Float64
    function N2SourceUnitTurnChartV4(rho, theta_turn, period_turn)
        values = (rho, theta_turn, period_turn)
        all(x -> x isa Real && !(x isa Bool) && isfinite(Float64(x)) &&
            0 <= x <= 1, values) ||
            throw(ArgumentError("source geometry requires finite unit-turn chart input"))
        new(Float64(rho), Float64(theta_turn), Float64(period_turn))
    end
end
semantic_view(input::N2SourceUnitTurnChartV4) = (
    coordinate_semantics=:rho_poloidal_turn_field_period_turn,
    rho=input.rho, theta_turn=input.theta_turn,
    period_turn=input.period_turn)

"""Interpret the bound source basis at a unit-turn chart node, screen-only.

This computes a local Jacobian and Gram matrix but never proves full-domain
orientation, nondegeneracy or admissibility.
"""
function evaluate_n2_source_geometry(binding::N2SourceGeometryBindingV4,
        input::N2SourceUnitTurnChartV4)
    _ast_payload(binding.program) == binding.coordinate_program.nodes[2].value &&
        _ast_payload(binding.program) == binding.metric_program.nodes[2].value ||
        throw(ArgumentError("source geometry AST payload differs from source program"))
    rebuilt = n2_source_geometry_typed_binding(binding.program,
        binding.coordinate_site_ref, binding.metric_site_ref)
    canonical_hash(binding) == canonical_hash(rebuilt) &&
        semantic_view(binding) == semantic_view(rebuilt) ||
        throw(ArgumentError("source geometry AST/manifest binding changed"))
    rho, theta_turn, period_turn =
        input.rho, input.theta_turn, input.period_turn
    nfp = binding.program.interior.field_periods
    theta = 2pi * theta_turn
    zeta = 2pi * period_turn / nfp
    chart = N2Z.evaluate_n2_source_rz_jacobian(binding.program.interior,
        rho, theta, zeta)
    c, s = cos(zeta), sin(zeta)
    kt, kz = 2pi, 2pi / nfp
    coordinate = (chart.R_m*c, chart.R_m*s, chart.Z_m)
    jacobian = (
        (chart.dR.rho*c, kt*chart.dR.theta*c,
            kz*(chart.dR.zeta*c-chart.R_m*s)),
        (chart.dR.rho*s, kt*chart.dR.theta*s,
            kz*(chart.dR.zeta*s+chart.R_m*c)),
        (chart.dZ.rho, kt*chart.dZ.theta, kz*chart.dZ.zeta))
    gram = ntuple(i -> ntuple(j -> sum(jacobian[k][i] * jacobian[k][j]
        for k in 1:3), 3), 3)
    scale = Float64(binding.program.support_scale.value)
    normalized = ntuple(i -> coordinate[i] / scale, 3)
    normalized_jacobian = ntuple(i -> ntuple(j -> jacobian[i][j] / scale,
        3), 3)
    normalized_gram = ntuple(i -> ntuple(j -> gram[i][j] / scale^2,
        3), 3)
    (input=(rho, theta_turn, period_turn),
     normalized_coordinate=normalized,
     normalized_jacobian=normalized_jacobian,
     normalized_metric=normalized_gram,
     coordinate=coordinate, jacobian=jacobian, metric=gram,
     program_hash=canonical_hash(binding.program),
     binding_hash=canonical_hash(binding),
     claim_ceiling=screen_only, geometry_proved=false,
     provider_selected=false, provider_executed=false,
     physical_validation=false, credible_device_count=0)
end

n2_source_geometry_manifest() = (
    schema=_N2G_SCHEMA, revision=_N2G_REVISION,
    source_basis=:DESC_FourierZernike_fringe,
    normalized_to_SI_roots=true,
    local_registry_only=true,
    claim_ceiling=screen_only, geometry_proved=false,
    provider_selected=false, provider_executed=false,
    physical_validation=false, credible_device_count=0)
end
