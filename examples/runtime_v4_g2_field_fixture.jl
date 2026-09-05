"""Declared G2 field-program fixture for the bounded evaluator."""

using FusionConceptAI

# Reuse only the already-declared mechanism, realization, mission, and contract
# registry.  Keep that fixture in a private module so this file defines the
# public `candidate` binding exactly once when included by a caller.
module DeclaredFixtureDependency
using FusionConceptAI
include(joinpath(@__DIR__, "runtime_v4_declared_fixture.jl"))
end

const _fixture_refs = DeclaredFixtureDependency._fixture_refs
const _fixture_mechanism = DeclaredFixtureDependency._fixture_mechanism
const _fixture_realization = DeclaredFixtureDependency._fixture_realization
const _fixture_graph = DeclaredFixtureDependency._fixture_graph
const _fixture_mission = DeclaredFixtureDependency._fixture_mission
const registry = DeclaredFixtureDependency.registry

const _g2_unit = UnitSignature()
const _g2_length = UnitSignature((0, 1, 0, 0, 0, 0, 0))
const _g2_chart = chart_coordinate_type_v1()
const _g2_scalar = phase_logit_type_v1()
const _g2_ops = default_operator_registry()
const _g2_site = FieldOperatorSiteRefV1("g2-field-site")
const _g2_support_ref = SpatialSupportRefV1("g2-support")
const _g2_chart_ref = ChartRefV1("g2-chart")
const _g2_bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), _g2_unit)
const _g2_support = SpatialSupportGeneV1(_g2_support_ref, 3,
    (CoordinateFrameRefV1("g2-frame"),),
    (CoordinateChartGeneV1(_g2_chart_ref, CoordinateFrameRefV1("g2-frame"),
        (_g2_bounds, _g2_bounds, _g2_bounds), (),
        SpatialProgramRootRefV1(FieldOperatorSiteRefV1("g2:coordinate_map_declaration:unexecuted:v1"), 1, _g2_chart,
            normalized_ambient_coordinate_type_v1()),
        SpatialProgramRootRefV1(FieldOperatorSiteRefV1("g2:metric_declaration:unexecuted:v1"), 1, _g2_chart,
            normalized_covariant_metric_type_v1())),),
    (), NonnegativeQuantityV1(1, _g2_length))

const _g2_parameter = FieldParameterGeneV1(FieldParameterRefV1("offset"), _g2_unit,
    ParameterTransformSpecV1(transform_linear),
    QuantityIntervalV1(ExactFiniteIntervalV1(0, 2, false), _g2_unit), 0.0)

function _g2_program(site=_g2_site)
    coefficient = ASTConstantV1(:coefficient, (2.0, -1.0, 0.0), _g2_chart)
    dot = ASTApplyV1(OperatorRefV1("DOT", "v1"), (1, 2), (;);
        registry=_g2_ops, input_types=(_g2_chart, _g2_chart))
    offset = ASTParameterV1(:offset, _g2_scalar)
    output = ASTApplyV1(OperatorRefV1("ADD", "v1"), (3, 4), (;);
        registry=_g2_ops, input_types=(_g2_scalar, _g2_scalar))
    copy = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (5,), (;);
        registry=_g2_ops, input_types=(_g2_scalar,))
    program = TypedASTProgramV1((ASTInputV1(1, _g2_chart), coefficient, dot,
        offset, output, copy), (5, 6), (1,); registry=_g2_ops)
    roots = (SpatialProgramRootRefV1(site, 1, _g2_chart, _g2_scalar),
        SpatialProgramRootRefV1(site, 2, _g2_chart, _g2_scalar))
    TypedFieldProgramGeneV1(site, program, roots,
        (FieldProgramParameterBindingV1(_g2_parameter.ref, 4),))
end

const _g2_typed_program = _g2_program()
const _g2_phase = PhaseFieldDeclarationV1(PhaseFieldRefV1("g2-field"),
    _g2_typed_program.root_refs[1])
const _g2_phase2 = PhaseFieldDeclarationV1(PhaseFieldRefV1("g2-field-copy"),
    _g2_typed_program.root_refs[2])
const _g2_phase_set = PhaseFieldSetGeneV1(_g2_support_ref, (_g2_parameter,),
    (_g2_typed_program,), (_g2_phase, _g2_phase2))
const _g2_field = FieldGeometryGenomeV4(2, _fixture_refs[2], _fixture_graph();
    fields=(_g2_support, _g2_phase_set))
const candidate = CandidateStatePackageV4("runtime-g2-field-fixture",
    _fixture_mission, _fixture_mechanism, _g2_field, _fixture_realization, registry)
const grid = ((-1.0, 0.0, 1.0), (-1.0, 0.0, 1.0), (-1.0, 0.0, 1.0))
const scenario = (name="g2-field-scenario",)
