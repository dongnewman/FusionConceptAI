"""Candidate-bound manufactured static-field residual execution.

This deliberately narrow D4.1 screen binds one exact G1 residual constraint
to two evaluated G2 roots and the audited finite-difference kernel. It cannot
produce physical, engineering, high-fidelity, or VVUQ authority.
"""

using SHA
import FusionConceptAI: canonical_hash, semantic_view

const _FRP_SCHEMA = "runtime-v4-field-residual"
const _FRP_REVISION = "v4.1"
struct _FieldResidualPipelineToken end
const _FRP_TOKEN = _FieldResidualPipelineToken()

struct StaticFieldResidualMissionV4
    mission_hash::Digest256
    scenario_hash::Digest256
    constraint_edge_hash::Digest256
    evidence_class::Symbol
    function StaticFieldResidualMissionV4(::_FieldResidualPipelineToken,
            mission_hash::Digest256, scenario_hash::Digest256,
            constraint_edge_hash::Digest256, evidence_class::Symbol)
        evidence_class === :manufactured_control ||
            throw(ArgumentError("D4.1 evidence class must be manufactured_control"))
        new(mission_hash, scenario_hash, constraint_edge_hash, evidence_class)
    end
end
StaticFieldResidualMissionV4(args...) = throw(ArgumentError("static field residual mission is sealed"))
semantic_view(x::StaticFieldResidualMissionV4) = (mission_hash=x.mission_hash,
    scenario_hash=x.scenario_hash, constraint_edge_hash=x.constraint_edge_hash,
    evidence_class=x.evidence_class)
canonical_hash(x::StaticFieldResidualMissionV4) = canonical_hash(semantic_view(x))

struct TypedFieldSourceScaleBindingV4
    state_ref::StateGeneRefV1
    physical_type::PhysicalType
    scale::Float64
    function TypedFieldSourceScaleBindingV4(::_FieldResidualPipelineToken,
            state_ref::StateGeneRefV1, physical_type::PhysicalType, scale::Real)
        value = Float64(scale)
        isfinite(value) && value != 0.0 || throw(ArgumentError("source scale must be finite and nonzero"))
        new(state_ref, physical_type, value)
    end
end
TypedFieldSourceScaleBindingV4(args...) = throw(ArgumentError("field source scale binding is sealed"))
semantic_view(x::TypedFieldSourceScaleBindingV4) = (state_ref=x.state_ref,
    physical_type=x.physical_type, scale=x.scale)
canonical_hash(x::TypedFieldSourceScaleBindingV4) = canonical_hash(semantic_view(x))

struct FieldResidualPipelinePlanV4
    candidate_hash::Digest256
    prefix_hash::Digest256
    registry_hash::Digest256
    subject_hash::Digest256
    mission::StaticFieldResidualMissionV4
    source_scale_bindings::Tuple{Vararg{TypedFieldSourceScaleBindingV4}}
    form::LinearFieldResidualFormV4
    geometry::DiagonalAffineChartGeometryV4
    grid::FieldGridSpecV4
    protocol::StructuredGridProtocolV4
    u_plan_hash::Digest256
    f_plan_hash::Digest256
    u_result_hash::Digest256
    f_result_hash::Digest256
    u_evidence_id::Digest256
    f_evidence_id::Digest256
    source_content_hash::Digest256
    boundary_content_hash::Digest256
    code_hash::Digest256
    plan_hash::Digest256
    function FieldResidualPipelinePlanV4(::_FieldResidualPipelineToken, args...)
        new(args...)
    end
end
FieldResidualPipelinePlanV4(args...) = throw(ArgumentError("field residual pipeline plan is sealed"))
semantic_view(x::FieldResidualPipelinePlanV4) = (candidate_hash=x.candidate_hash,
    prefix_hash=x.prefix_hash, registry_hash=x.registry_hash, subject_hash=x.subject_hash,
    mission=x.mission, source_scale_bindings=x.source_scale_bindings, form=x.form,
    geometry=x.geometry, grid=x.grid, protocol=x.protocol, u_plan_hash=x.u_plan_hash,
    f_plan_hash=x.f_plan_hash, u_result_hash=x.u_result_hash,
    f_result_hash=x.f_result_hash, u_evidence_id=x.u_evidence_id,
    f_evidence_id=x.f_evidence_id, source_content_hash=x.source_content_hash,
    boundary_content_hash=x.boundary_content_hash, code_hash=x.code_hash,
    plan_hash=x.plan_hash)
canonical_hash(x::FieldResidualPipelinePlanV4) = x.plan_hash

struct FieldResidualPipelineReceiptV4
    plan_hash::Digest256
    solver_input_hash::Digest256
    assembly_hash::Union{Nothing,Digest256}
    artifact_hash::Union{Nothing,Digest256}
    status::Symbol
    execution_count::Int
    receipt_hash::Digest256
    function FieldResidualPipelineReceiptV4(::_FieldResidualPipelineToken, args...)
        new(args...)
    end
end
FieldResidualPipelineReceiptV4(args...) = throw(ArgumentError("field residual receipt is sealed"))
semantic_view(x::FieldResidualPipelineReceiptV4) = (plan_hash=x.plan_hash,
    solver_input_hash=x.solver_input_hash, assembly_hash=x.assembly_hash,
    artifact_hash=x.artifact_hash, status=x.status, execution_count=x.execution_count)

struct FieldResidualPipelineReportV4
    status::Symbol
    artifact::Union{Nothing,FieldSolveResultV4}
    receipt::FieldResidualPipelineReceiptV4
    evidence::RuntimeEvidenceV4
    claim_ceiling::ClaimCeiling
    credible_physical_candidate_count::Int
    p5_ready::Bool
    unsupported_emitted::Bool
    report_hash::Digest256
    function FieldResidualPipelineReportV4(::_FieldResidualPipelineToken, args...)
        new(args...)
    end
end
FieldResidualPipelineReportV4(args...) = throw(ArgumentError("field residual report is sealed"))
semantic_view(x::FieldResidualPipelineReportV4) = (status=x.status,
    artifact_hash=x.artifact === nothing ? nothing : x.artifact.result_hash,
    receipt=x.receipt, evidence=x.evidence, claim_ceiling=x.claim_ceiling,
    credible_physical_candidate_count=x.credible_physical_candidate_count,
    p5_ready=x.p5_ready, unsupported_emitted=x.unsupported_emitted)

mutable struct FieldResidualPipelineStoreV4
    reports::Dict{Digest256,FieldResidualPipelineReportV4}
    artifacts::Dict{Digest256,FieldSolveResultV4}
    execution_counts::Dict{Digest256,Int}
end
FieldResidualPipelineStoreV4() = FieldResidualPipelineStoreV4(
    Dict{Digest256,FieldResidualPipelineReportV4}(),
    Dict{Digest256,FieldSolveResultV4}(), Dict{Digest256,Int}())

struct ManufacturedFieldConvergenceReceiptV4
    plan_hashes::NTuple{3,Digest256}
    report_hashes::NTuple{3,Digest256}
    reference_result_hashes::NTuple{3,Digest256}
    errors::NTuple{3,Float64}
    orders::NTuple{2,Float64}
    status::Symbol
    claim_ceiling::ClaimCeiling
    receipt_hash::Digest256
    function ManufacturedFieldConvergenceReceiptV4(::_FieldResidualPipelineToken, args...)
        new(args...)
    end
end
ManufacturedFieldConvergenceReceiptV4(args...) = throw(ArgumentError("manufactured convergence receipt is sealed"))
semantic_view(x::ManufacturedFieldConvergenceReceiptV4) = (plan_hashes=x.plan_hashes,
    report_hashes=x.report_hashes, reference_result_hashes=x.reference_result_hashes,
    errors=x.errors, orders=x.orders, status=x.status, claim_ceiling=x.claim_ceiling)

function _frp_code_hash()
    bytes = vcat(read(joinpath(@__DIR__, "FieldResidualPipeline.jl")),
        read(joinpath(@__DIR__, "FieldResidualNumerics.jl")))
    Digest256(bytes2hex(SHA.sha256(bytes)))
end

_frp_plan_body(candidate_hash, prefix_hash, registry_hash, mission, bindings, form,
    geometry, grid, protocol, u_plan_hash, f_plan_hash, u_result_hash,
    f_result_hash, u_evidence_id, f_evidence_id, source_content_hash,
    boundary_content_hash, code_hash) = (
    candidate_hash=candidate_hash, prefix_hash=prefix_hash, registry_hash=registry_hash,
    mission=mission, source_scale_bindings=bindings, form=form, geometry=geometry,
    grid=grid, protocol=protocol, u_plan_hash=u_plan_hash, f_plan_hash=f_plan_hash,
    u_result_hash=u_result_hash, f_result_hash=f_result_hash,
    u_evidence_id=u_evidence_id, f_evidence_id=f_evidence_id,
    source_content_hash=source_content_hash,
    boundary_content_hash=boundary_content_hash,
    code_hash=code_hash)

function _frp_validate_plan(plan::FieldResidualPipelinePlanV4)
    body = _frp_plan_body(plan.candidate_hash, plan.prefix_hash, plan.registry_hash,
        plan.mission, plan.source_scale_bindings, plan.form, plan.geometry, plan.grid,
        plan.protocol, plan.u_plan_hash, plan.f_plan_hash, plan.u_result_hash,
        plan.f_result_hash, plan.u_evidence_id, plan.f_evidence_id,
        plan.source_content_hash, plan.boundary_content_hash, plan.code_hash)
    canonical_hash(body) == plan.plan_hash || throw(ArgumentError("field residual plan hash mismatch"))
    canonical_hash((candidate_hash=plan.candidate_hash, prefix_hash=plan.prefix_hash,
        plan_hash=plan.plan_hash)) == plan.subject_hash || throw(ArgumentError("field residual subject hash mismatch"))
    plan.code_hash == _frp_code_hash() || throw(ArgumentError("field residual code hash mismatch"))
    _fr_form_integrity(plan.form) || throw(ArgumentError("field residual form integrity mismatch"))
    _fr_geometry_integrity(plan.geometry) || throw(ArgumentError("field residual geometry integrity mismatch"))
    _fr_protocol_integrity(plan.protocol) == plan.protocol.protocol_hash || throw(ArgumentError("field residual protocol integrity mismatch"))
    plan.grid == plan.geometry.grid || throw(ArgumentError("field residual grid/geometry mismatch"))
    plan.mission.evidence_class == :manufactured_control ||
        throw(ArgumentError("field residual evidence class mismatch"))
    length(plan.source_scale_bindings) == 1 &&
        only(plan.source_scale_bindings).state_ref == only(plan.form.source_state_refs) &&
        only(plan.source_scale_bindings).physical_type == only(plan.form.source_types) &&
        only(plan.source_scale_bindings).scale == only(plan.form.source_coefficients) ||
        throw(ArgumentError("field residual source scale binding mismatch"))
    plan
end

function _frp_runtime_evidence_integrity(evidence::RuntimeEvidenceV4)
    body = (physical_subject_hash=evidence.physical_subject_hash,
        scenario_hash=evidence.scenario_hash, solver_input_hash=evidence.solver_input_hash,
        provider_manifest_hash=evidence.provider_manifest_hash,
        backend_revision=evidence.backend_revision,
        numerical_configuration_hash=evidence.numerical_configuration_hash,
        artifact_refs=evidence.artifact_refs, uncertainty_or_null=evidence.uncertainty_or_null,
        binding_provenance=evidence.binding_provenance, status_vector=evidence.status_vector,
        metrics=evidence.metrics, claim_ceiling=evidence.claim_ceiling,
        independence_group=evidence.independence_group)
    canonical_hash(body) == evidence.evidence_id
end

function _frp_field_result_integrity(result::FieldEvaluationResultV4)
    core = (coordinates=result.coordinates, values=result.values, output_type=result.output_type)
    scalars = Tuple(value for value in result.values if value isa Float64)
    low = isempty(scalars) ? nothing : minimum(scalars)
    high = isempty(scalars) ? nothing : maximum(scalars)
    result.checksum == canonical_hash(core) && result.min_value == low && result.max_value == high &&
        result.result_hash == canonical_hash((coordinates=result.coordinates,
            values=result.values, output_type=result.output_type, checksum=result.checksum,
            min_value=result.min_value, max_value=result.max_value))
end

function _frp_validate_g2(candidate, compiled, genome_registry, operator_registry,
        report, scenario, grid, state_ref::StateGeneRefV1)
    report isa FieldEvaluationReportV4 || throw(ArgumentError("G2 report must be typed"))
    plan = report.plan
    plan.candidate_hash == candidate.canonical_hashes.genome_bundle_hash &&
        plan.prefix_hash == compiled.prefix_hash &&
        plan.field_geometry_hash == candidate.canonical_hashes.field_geometry_hash &&
        plan.grid == grid && plan.scenario_hash == canonical_hash(scenario) &&
        plan.code_hash == _FIELD_EVAL_CODE_HASH ||
        throw(ArgumentError("G2 plan identity is outside the frozen candidate"))
    canonical_hash(_field_plan_body_from_plan(plan)) == plan.plan_hash ||
        throw(ArgumentError("G2 plan body/hash mismatch"))
    expected_plan = compile_field_evaluation_plan(candidate, compiled,
        genome_registry, operator_registry; scenario=scenario, grid=grid,
        program_site_ref=plan.program_site_ref,
        root_position=plan.root.root_position)
    semantic_view(plan) == semantic_view(expected_plan) ||
        throw(ArgumentError("G2 plan is not derived from the frozen candidate"))
    program, root, parameters = _field_plan_components(candidate, plan)
    root == plan.root || throw(ArgumentError("G2 root payload mismatch"))
    _field_operator_bindings(program, operator_registry)
    records = _field_collect(candidate.field_geometry_genome_ref.fields)
    phases = Tuple(phase for phase in records.phase_set.phase_fields if phase.logit_root == plan.root)
    length(phases) == 1 && only(phases).phase_field_ref.value == state_ref.value ||
        throw(ArgumentError("G2 root is not bound to the requested state"))
    report.status == :evaluated_screen && report.result isa FieldEvaluationResultV4 &&
        report.subject isa ExecutablePhysicalSubjectV4 && report.input isa SolverInputV4 &&
        report.evidence isa RuntimeEvidenceV4 || throw(ArgumentError("G2 report is not executed"))
    expected_result = evaluate_field_program(plan, program, root, parameters;
        operator_registry=operator_registry)
    semantic_view(report.result) == semantic_view(expected_result) ||
        throw(ArgumentError("G2 result is not derived from the frozen plan"))
    _frp_field_result_integrity(report.result) || throw(ArgumentError("G2 result integrity mismatch"))
    capability = _field_capability(plan)
    expected_provider = field_evaluation_provider(plan)
    expected_subject = _field_subject(candidate, compiled, plan, capability, scenario)
    expected_input = compile_solver_input(expected_subject, scenario, capability, expected_provider)
    semantic_view(report.subject) == semantic_view(expected_subject) ||
        throw(ArgumentError("G2 subject is not derived from the frozen plan"))
    semantic_view(report.input) == semantic_view(expected_input) ||
        throw(ArgumentError("G2 solver input is not derived from the frozen plan"))
    report.provider_manifest_hash == expected_provider.manifest_hash &&
        report.evidence.provider_manifest_hash == expected_provider.manifest_hash &&
        report.evidence.backend_revision == expected_provider.backend_revision &&
        report.evidence.independence_group == expected_provider.independence_group ||
        throw(ArgumentError("G2 provider identity is not the frozen plan provider"))
    report.claim_ceiling == screen_only && report.evidence.claim_ceiling == screen_only ||
        throw(ArgumentError("G2 report exceeds screen-only authority"))
    expected_binding = (physical_subject_hash=expected_input.physical_subject_hash,
        scenario_hash=expected_input.scenario_hash,
        solver_input_hash=expected_input.solver_input_hash,
        provider_manifest_hash=expected_provider.manifest_hash,
        backend_revision=expected_provider.backend_revision,
        code_hash=expected_provider.code_hash)
    expected_status = StatusVectorV4(required, unique_match, resolved,
        low_fidelity_evaluated, pass)
    report.evidence.physical_subject_hash == expected_subject.physical_subject_hash &&
        report.evidence.scenario_hash == plan.scenario_hash &&
        report.evidence.solver_input_hash == expected_input.solver_input_hash &&
        report.evidence.numerical_configuration_hash ==
            canonical_hash(expected_input.payload.numerical_configuration) &&
        report.evidence.artifact_refs == (report.result.result_hash,) &&
        report.evidence.uncertainty_or_null === nothing &&
        report.evidence.binding_provenance == expected_binding &&
        report.evidence.status_vector == expected_status &&
        report.evidence.metrics ==
            (MetricWithUnit(:grid_points, Float64(length(report.result.values))),) &&
        report.unresolved_gaps == plan.unresolved_gaps ||
        throw(ArgumentError("G2 execution evidence is not exact"))
    _frp_runtime_evidence_integrity(report.evidence) || throw(ArgumentError("G2 evidence integrity mismatch"))
    report
end

function _frp_validate_manufactured_g2(u_report::FieldEvaluationReportV4,
        f_report::FieldEvaluationReportV4, records)
    u_report.plan.program == f_report.plan.program ||
        throw(ArgumentError("D4.1 G2 roots must share the exact program payload"))
    program = u_report.plan.program
    nodes = program.program.nodes
    length(nodes) == 7 && program.program.roots == (3, 7) &&
        program.program.input_ports == (1,) ||
        throw(ArgumentError("D4.1 requires the exact two-root manufactured G2 AST"))
    nodes[1] isa ASTInputV1 && nodes[1].port == 1 ||
        throw(ArgumentError("D4.1 G2 must have one coordinate input"))
    nodes[2] isa ASTApplyV1 && nodes[2].operator_ref.qualified.id == "DOT" &&
        nodes[2].inputs == (1, 1) || throw(ArgumentError("D4.1 G2 rho2 expression mismatch"))
    nodes[3] isa ASTApplyV1 && nodes[3].operator_ref.qualified.id == "SCALAR_MUL" &&
        nodes[3].inputs == (2, 2) || throw(ArgumentError("D4.1 G2 u must equal rho2 squared"))
    nodes[4] isa ASTConstantV1 && nodes[4].value == 10.0 ||
        throw(ArgumentError("D4.1 G2 source coefficient must equal 10"))
    nodes[5] isa ASTApplyV1 && nodes[5].operator_ref.qualified.id == "SCALAR_MUL" &&
        nodes[5].inputs == (4, 2) || throw(ArgumentError("D4.1 G2 source core must equal 10rho2"))
    nodes[6] isa ASTParameterV1 && nodes[7] isa ASTApplyV1 &&
        nodes[7].operator_ref.qualified.id == "ADD" && nodes[7].inputs == (5, 6) ||
        throw(ArgumentError("D4.1 G2 zero-offset source binding mismatch"))
    length(program.parameter_bindings) == 1 &&
        only(program.parameter_bindings).parameter_node_position == 6 ||
        throw(ArgumentError("D4.1 G2 requires one exact zero-offset binding"))
    parameters = Tuple(parameter for parameter in records.parameters
        if parameter.ref == only(program.parameter_bindings).parameter_ref)
    length(parameters) == 1 && field_parameter_value(only(parameters)) == 0.0 ||
        throw(ArgumentError("D4.1 G2 offset must evaluate exactly to zero"))
    unitless = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), UnitSignature())
    all(nodes[i].output_type == unitless for i in 2:7) ||
        throw(ArgumentError("D4.1 G2 manufactured fields must be unitless static scalar3D"))
    for (coordinate, u_value, f_value) in zip(u_report.result.coordinates,
            u_report.result.values, f_report.result.values)
        rho2 = sum(value * value for value in coordinate)
        u_value == rho2 * rho2 || throw(ArgumentError("D4.1 G2 u artifact is not rho2 squared"))
        f_value == 10.0 * rho2 || throw(ArgumentError("D4.1 G2 f artifact is not 10rho2"))
    end
    nothing
end

function _frp_exact_static_field_constraint(edge::AtomicMIMOHyperedgeV1,
        unknown_ref::StateGeneRefV1, source_ref::StateGeneRefV1,
        residual_ref::StateGeneRefV1, candidate::CandidateStatePackageV4)
    nodes = edge.program.nodes
    length(nodes) == 6 && edge.program.roots == (6,) && edge.program.input_ports == (1, 2) ||
        throw(ArgumentError("D4.1 requires the exact six-node LAPLACE(u)-kappa*f AST"))
    nodes[1] isa ASTInputV1 && nodes[1].port == 1 && nodes[2] isa ASTInputV1 && nodes[2].port == 2 ||
        throw(ArgumentError("D4.1 residual AST input ordering mismatch"))
    nodes[3] isa ASTApplyV1 && nodes[3].operator_ref.qualified.id == "LAPLACE" && nodes[3].inputs == (1,) ||
        throw(ArgumentError("D4.1 residual AST lacks exact LAPLACE(u)"))
    nodes[4] isa ASTConstantV1 && nodes[4].value == 2.0 ||
        throw(ArgumentError("D4.1 kappa must be the exact finite constant 2.0 m^-2"))
    nodes[5] isa ASTApplyV1 && nodes[5].operator_ref.qualified.id == "SCALAR_MUL" && nodes[5].inputs == (4, 2) ||
        throw(ArgumentError("D4.1 residual AST kappa*f binding mismatch"))
    nodes[6] isa ASTApplyV1 && nodes[6].operator_ref.qualified.id == "SUB" && nodes[6].inputs == (3, 5) ||
        throw(ArgumentError("D4.1 residual AST subtraction mismatch"))
    unitless = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), UnitSignature())
    inverse_area = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time),
        UnitSignature((0, -2, 0, 0, 0, 0, 0)))
    nodes[1].output_type == unitless && nodes[2].output_type == unitless &&
        all(nodes[i].output_type == inverse_area for i in 3:6) ||
        throw(ArgumentError("D4.1 requires unitless u/f and m^-2 kappa/residual"))
    state_map = Dict(state.state_ref.value => state for state in candidate.mechanism_genome_ref.payload.states)
    all(haskey(state_map, ref.value) for ref in (unknown_ref, source_ref, residual_ref)) ||
        throw(ArgumentError("D4.1 state references are absent from G1"))
    state_map[unknown_ref.value].physical_type == unitless &&
        state_map[source_ref.value].physical_type == unitless &&
        state_map[residual_ref.value].physical_type == inverse_area ||
        throw(ArgumentError("D4.1 G1 state units do not match the manufactured contract"))
    residual = state_map[residual_ref.value]
    length(residual.constraint_refs) == 1 && only(residual.constraint_refs).value == edge.edge_id ||
        throw(ArgumentError("D4.1 residual state does not own the exact constraint"))
    nothing
end

function compile_field_residual_plan(candidate::CandidateStatePackageV4,
        compiled::CompiledCandidatePrefixV4, genome_registry::GenomeContractRegistryV4,
        operator_registry::OperatorRegistryV1, u_report, f_report; scenario,
        grid::FieldGridSpecV4, constraint_edge_hash::Digest256,
        unknown_state_ref::StateGeneRefV1, source_state_ref::StateGeneRefV1,
        residual_state_ref::StateGeneRefV1, affine_factors, affine_offsets,
        protocol::StructuredGridProtocolV4)
    compiled.candidate === candidate || throw(ArgumentError("candidate/prefix identity mismatch"))
    _runtime_validate_compiled_prefix(compiled, candidate, genome_registry,
        compiled.mission_payload, compiled.bounds_payload,
        compiled.minimality_scope.comparison_scope, compiled.minimality_scope.scenario_scope)
    _frp_validate_g2(candidate, compiled, genome_registry, operator_registry,
        u_report, scenario, grid, unknown_state_ref)
    _frp_validate_g2(candidate, compiled, genome_registry, operator_registry,
        f_report, scenario, grid, source_state_ref)
    u_report.plan.program_site_ref == f_report.plan.program_site_ref || throw(ArgumentError("G2 roots must share one program"))
    u_report.plan.root.root_position == 1 && f_report.plan.root.root_position == 2 ||
        throw(ArgumentError("G2 roots must be u root 1 and f root 2"))
    records = _field_collect(candidate.field_geometry_genome_ref.fields)
    _frp_validate_manufactured_g2(u_report, f_report, records)
    matches = Tuple(edge for edge in compiled.mechanism_graph.hyperedges
        if edge isa AtomicMIMOHyperedgeV1 && canonical_hash(edge) == constraint_edge_hash)
    length(matches) == 1 || throw(ArgumentError("constraint edge hash is not exact and unique"))
    edge = only(matches)
    _frp_exact_static_field_constraint(edge, unknown_state_ref, source_state_ref, residual_state_ref, candidate)
    form = compile_linear_field_residual_form(edge, compiled.mechanism_graph, operator_registry;
        constraint_edge_hash=constraint_edge_hash, unknown_state_ref=unknown_state_ref,
        source_state_refs=(source_state_ref,), residual_state_ref=residual_state_ref)
    form.alpha == 1.0 && form.beta == 0.0 && form.source_coefficients == (-2.0,) && form.constant == 0.0 ||
        throw(ArgumentError("D4.1 residual form is not LAPLACE(u)-2f"))
    u_report.result.output_type == form.unknown_type || throw(ArgumentError("unknown G2 type mismatch"))
    f_report.result.output_type == form.source_types[1] || throw(ArgumentError("source G2 type mismatch"))
    u_report.plan.chart_ref == f_report.plan.chart_ref || throw(ArgumentError("G2 roots use different charts"))
    geometry = compile_diagonal_affine_geometry(records.support, u_report.plan.chart_ref,
        affine_factors, affine_offsets, grid)
    binding = TypedFieldSourceScaleBindingV4(_FRP_TOKEN, source_state_ref,
        form.source_types[1], form.source_coefficients[1])
    mission = StaticFieldResidualMissionV4(_FRP_TOKEN,
        compiled.minimality_scope.mission_hash, canonical_hash(scenario),
        constraint_edge_hash, :manufactured_control)
    candidate_hash = candidate.canonical_hashes.genome_bundle_hash
    prefix_hash = compiled.prefix_hash
    registry_hash = canonical_hash(genome_registry)
    code_hash = _frp_code_hash()
    bindings = (binding,)
    source_payload = FieldResidualPayloadV4(source_state_ref, grid,
        f_report.result.values, form.source_types[1])
    boundary_payload = FieldResidualPayloadV4(unknown_state_ref, grid,
        u_report.result.values, form.unknown_type)
    body = _frp_plan_body(candidate_hash, prefix_hash, registry_hash, mission, bindings,
        form, geometry, grid, protocol, u_report.plan.plan_hash, f_report.plan.plan_hash,
        u_report.result.result_hash, f_report.result.result_hash,
        u_report.evidence.evidence_id, f_report.evidence.evidence_id,
        source_payload.content_hash, boundary_payload.content_hash, code_hash)
    plan_hash = canonical_hash(body)
    subject_hash = canonical_hash((candidate_hash=candidate_hash, prefix_hash=prefix_hash, plan_hash=plan_hash))
    plan = FieldResidualPipelinePlanV4(_FRP_TOKEN, candidate_hash, prefix_hash, registry_hash,
        subject_hash, mission, bindings, form, geometry, grid, protocol,
        u_report.plan.plan_hash, f_report.plan.plan_hash,
        u_report.result.result_hash, f_report.result.result_hash,
        u_report.evidence.evidence_id, f_report.evidence.evidence_id,
        source_payload.content_hash, boundary_payload.content_hash,
        code_hash, plan_hash)
    _frp_validate_plan(plan)
end
compile_field_residual_pipeline_plan(args...; kwargs...) = compile_field_residual_plan(args...; kwargs...)

function _frp_capability(plan::FieldResidualPipelinePlanV4)
    _frp_validate_plan(plan)
    bounds = canonical_hash((candidate_hash=plan.candidate_hash, prefix_hash=plan.prefix_hash,
        subject_hash=plan.subject_hash, form_hash=canonical_hash(plan.form),
        geometry_hash=canonical_hash(plan.geometry), grid_hash=plan.grid.grid_hash,
        protocol_hash=plan.protocol.protocol_hash))
    schema = canonical_hash((schema=_FRP_SCHEMA, revision=_FRP_REVISION,
        plan_hash=plan.plan_hash, code_hash=plan.code_hash))
    CapabilitySignatureV4(_FRP_SCHEMA, _FRP_REVISION, :structured_field_residual_solve,
        "manufactured LAPLACE residual", ("unknown", "source", "residual"),
        "rectilinear_field_grid", "rectilinear_field_grid", 3, ("x", "y", "z"),
        "dirichlet_elimination", "none", "static", ("solution", "residual"),
        screen_only, bounds; input_schema_hash=schema, coordinate_system="affine_cartesian")
end

function _frp_materialized_payload(input::SolverInputV4, plan::FieldResidualPipelinePlanV4)
    canonical_hash((physical_subject_hash=input.physical_subject_hash,
        scenario_hash=input.scenario_hash, provider_manifest_hash=input.provider_manifest_hash,
        input_schema_hash=input.input_schema_hash, payload=input.payload)) == input.solver_input_hash ||
        throw(ArgumentError("field residual solver input hash mismatch"))
    hasproperty(input.payload, :materialized_payload) && hasproperty(input.payload, :numerical_configuration) ||
        throw(ArgumentError("field residual solver input payload is incomplete"))
    payload = input.payload.materialized_payload
    all(hasproperty(payload, field) for field in (:plan, :plan_hash, :sources, :boundary)) ||
        throw(ArgumentError("field residual materialized payload is incomplete"))
    payload.plan isa FieldResidualPipelinePlanV4 && _frp_validate_plan(payload.plan).plan_hash == plan.plan_hash &&
        payload.plan_hash == plan.plan_hash || throw(ArgumentError("field residual input plan mismatch"))
    source_snapshots = Tuple(payload.sources)
    sources = Tuple(_frp_rehydrate_payload(snapshot, plan.grid) for snapshot in source_snapshots)
    boundary = _frp_rehydrate_payload(payload.boundary, plan.grid)
    length(sources) == 1 && only(sources).content_hash == plan.source_content_hash ||
        throw(ArgumentError("field residual source is not the frozen G2 artifact"))
    boundary.content_hash == plan.boundary_content_hash ||
        throw(ArgumentError("field residual boundary is not the frozen G2 artifact"))
    input.payload.numerical_configuration ==
        (protocol_hash=plan.protocol.protocol_hash,) ||
        throw(ArgumentError("field residual numerical configuration mismatch"))
    sources, boundary
end

function _frp_rehydrate_payload(snapshot, grid::FieldGridSpecV4)
    all(hasproperty(snapshot, field) for field in
        (:state_ref, :values, :physical_type, :content_hash)) ||
        throw(ArgumentError("field residual payload snapshot is incomplete"))
    snapshot.state_ref isa StateGeneRefV1 && snapshot.physical_type isa PhysicalType &&
        snapshot.content_hash isa Digest256 ||
        throw(ArgumentError("field residual payload snapshot is not typed"))
    payload = FieldResidualPayloadV4(snapshot.state_ref, grid,
        Tuple(snapshot.values), snapshot.physical_type)
    payload.content_hash == snapshot.content_hash ||
        throw(ArgumentError("field residual payload snapshot hash mismatch"))
    payload
end

function _frp_execute_input(input::SolverInputV4, plan::FieldResidualPipelinePlanV4)
    sources, boundary = _frp_materialized_payload(input, plan)
    assembly = assemble_field_residual_kernel(plan.form, plan.geometry, plan.grid,
        sources, boundary, plan.protocol)
    assembly, solve_field_residual_kernel(assembly, plan.protocol)
end

function _frp_classify_status(status::Symbol, factorization_status::Symbol)
    status == :converged && return (:pass, pass)
    status == :numerical_fail && factorization_status == :success &&
        return (:numerical_fail, numerical_fail)
    (:unknown, unknown)
end
_frp_classify_result(result::FieldSolveResultV4) =
    _frp_classify_status(result.status, result.factorization_status)

function _frp_executor(input)
    input isa SolverInputV4 || throw(ArgumentError("field residual provider requires SolverInputV4"))
    payload = input.payload.materialized_payload
    hasproperty(payload, :plan) || throw(ArgumentError("field residual provider input lacks plan"))
    plan = payload.plan
    plan isa FieldResidualPipelinePlanV4 || throw(ArgumentError("field residual provider plan is not typed"))
    provider = field_residual_provider(plan)
    input.physical_subject_hash == plan.subject_hash && input.scenario_hash == plan.mission.scenario_hash &&
        input.provider_manifest_hash == provider.manifest_hash && input.input_schema_hash == provider.input_schema_hash ||
        throw(ArgumentError("field residual provider input identity mismatch"))
    _, result = _frp_execute_input(input, plan)
    _, outcome = _frp_classify_result(result)
    (metrics=(), stage_outcome=outcome,
        artifacts=(result.result_hash,))
end

function field_residual_provider(plan::FieldResidualPipelinePlanV4)
    capability = _frp_capability(plan)
    domain = (plan_hash=plan.plan_hash, subject_hash=plan.subject_hash,
        candidate_hash=plan.candidate_hash, prefix_hash=plan.prefix_hash,
        registry_hash=plan.registry_hash, u_plan_hash=plan.u_plan_hash,
        f_plan_hash=plan.f_plan_hash, u_result_hash=plan.u_result_hash,
        f_result_hash=plan.f_result_hash, u_evidence_id=plan.u_evidence_id,
        f_evidence_id=plan.f_evidence_id,
        source_content_hash=plan.source_content_hash,
        boundary_content_hash=plan.boundary_content_hash,
        evidence_class=plan.mission.evidence_class)
    ProviderManifestV4(_FRP_SCHEMA, _FRP_REVISION, :structured_field_residual_solve,
        capability, domain, "native-sparse-lu", "julia-umfpack-v1", plan.code_hash,
        "runtime-v4-native-field-residual", screen_only;
        input_schema_hash=capability.input_schema_hash, executor=_frp_executor)
end
field_residual_pipeline_provider = field_residual_provider

function _frp_receipt(plan_hash, input_hash, assembly_hash, artifact_hash, status, count)
    body = (plan_hash=plan_hash, solver_input_hash=input_hash, assembly_hash=assembly_hash,
        artifact_hash=artifact_hash, status=status, execution_count=count)
    FieldResidualPipelineReceiptV4(_FRP_TOKEN, plan_hash, input_hash, assembly_hash,
        artifact_hash, status, count, canonical_hash(body))
end

function _frp_report(status, artifact, receipt, evidence, ceiling)
    artifact_hash = artifact === nothing ? nothing : artifact.result_hash
    body = (status=status, artifact_hash=artifact_hash, receipt=receipt, evidence=evidence,
        claim_ceiling=ceiling, credible_physical_candidate_count=0,
        p5_ready=false, unsupported_emitted=false)
    FieldResidualPipelineReportV4(_FRP_TOKEN, status, artifact, receipt, evidence,
        ceiling, 0, false, false, canonical_hash(body))
end

_frp_deferred_provenance(plan::FieldResidualPipelinePlanV4) = (
    plan_hash=plan.plan_hash,
    operation=:manufactured_static_field_residual,
    evidence_class=:manufactured_control,
    reason="missing_provider")

_frp_execution_provenance(plan::FieldResidualPipelinePlanV4,
        assembly_hash::Digest256) = (
    plan_hash=plan.plan_hash,
    operation=:manufactured_static_field_residual,
    physical_subject_hash=plan.subject_hash,
    candidate_hash=plan.candidate_hash,
    prefix_hash=plan.prefix_hash,
    assembly_hash=assembly_hash,
    u_plan_hash=plan.u_plan_hash,
    f_plan_hash=plan.f_plan_hash,
    u_result_hash=plan.u_result_hash,
    f_result_hash=plan.f_result_hash,
    u_evidence_id=plan.u_evidence_id,
    f_evidence_id=plan.f_evidence_id,
    evidence_class=:manufactured_control,
    code_hash=plan.code_hash)

function _frp_deferred(plan::FieldResidualPipelinePlanV4)
    vector = StatusVectorV4(required, no_match, terminal_deferred,
        low_fidelity_evaluated, terminal_deferred_stage)
    evidence = RuntimeEvidenceV4(plan.subject_hash, plan.mission.scenario_hash,
        plan.plan_hash, nothing, _frp_deferred_provenance(plan),
        vector, (); claim_ceiling=none)
    receipt = _frp_receipt(plan.plan_hash, plan.plan_hash, nothing, nothing,
        :terminal_deferred, 0)
    _frp_report(:terminal_deferred, nothing, receipt, evidence, none)
end

function execute_once!(store::FieldResidualPipelineStoreV4, input, provider,
        plan::FieldResidualPipelinePlanV4)
    _frp_validate_plan(plan)
    provider === nothing && return _frp_deferred(plan)
    provider isa ProviderManifestV4 || throw(ArgumentError("field residual provider must be typed"))
    provider.manifest_hash == field_residual_provider(plan).manifest_hash ||
        throw(ArgumentError("foreign or forged field residual provider"))
    input isa SolverInputV4 || throw(ArgumentError("field residual execution requires SolverInputV4"))
    input.physical_subject_hash == plan.subject_hash || throw(ArgumentError("field residual subject mismatch"))
    input.scenario_hash == plan.mission.scenario_hash || throw(ArgumentError("field residual scenario mismatch"))
    input.provider_manifest_hash == provider.manifest_hash || throw(ArgumentError("field residual input provider mismatch"))
    input.input_schema_hash == provider.input_schema_hash || throw(ArgumentError("field residual input schema mismatch"))
    _frp_materialized_payload(input, plan)
    if haskey(store.reports, input.solver_input_hash)
        cached = store.reports[input.solver_input_hash]
        validate_field_residual_pipeline_report(plan, cached) &&
            cached.receipt.solver_input_hash == input.solver_input_hash &&
            get(store.execution_counts, input.solver_input_hash, 0) == 1 ||
            throw(ArgumentError("field residual cache provenance mismatch"))
        cached.artifact === nothing ||
            get(store.artifacts, cached.artifact.result_hash, nothing) === cached.artifact ||
            throw(ArgumentError("field residual artifact cache mismatch"))
        return cached
    end
    assembly, result = _frp_execute_input(input, plan)
    status, outcome = _frp_classify_result(result)
    vector = StatusVectorV4(required, unique_match, resolved, low_fidelity_evaluated, outcome)
    evidence = RuntimeEvidenceV4(plan.subject_hash, plan.mission.scenario_hash,
        input.solver_input_hash, provider.manifest_hash,
        _frp_execution_provenance(plan, assembly.assembly_hash),
        vector, (); claim_ceiling=screen_only,
        provider_manifest=provider, backend_revision=provider.backend_revision,
        numerical_configuration_hash=canonical_hash(input.payload.numerical_configuration),
        artifact_refs=(plan.u_result_hash, plan.f_result_hash, result.result_hash))
    receipt = _frp_receipt(plan.plan_hash, input.solver_input_hash,
        assembly.assembly_hash, result.result_hash, status, 1)
    report = _frp_report(status, result, receipt, evidence, screen_only)
    store.reports[input.solver_input_hash] = report
    store.artifacts[result.result_hash] = result
    store.execution_counts[input.solver_input_hash] = 1
    report
end

function _frp_solve_result_integrity(result::FieldSolveResultV4)
    body = (status=result.status, solution=result.solution,
        residual_norm=result.residual_norm, boundary_mismatch=result.boundary_mismatch,
        backward_error=result.backward_error, factorization_status=result.factorization_status,
        conditioning_status=result.conditioning_status, reason=result.reason,
        assembly_hash=result.assembly_hash, protocol_hash=result.protocol_hash)
    canonical_hash(body) == result.result_hash
end

function validate_field_residual_pipeline_report(plan::FieldResidualPipelinePlanV4, report)
    report isa FieldResidualPipelineReportV4 || return false
    try _frp_validate_plan(plan) catch; return false end
    receipt = report.receipt
    receipt.plan_hash == plan.plan_hash && receipt.execution_count in (0, 1) &&
        receipt.receipt_hash == canonical_hash(semantic_view(receipt)) || return false
    report.credible_physical_candidate_count == 0 && !report.p5_ready && !report.unsupported_emitted || return false
    _frp_runtime_evidence_integrity(report.evidence) || return false
    isempty(report.evidence.metrics) && report.evidence.uncertainty_or_null === nothing || return false
    report.report_hash == canonical_hash(semantic_view(report)) || return false
    if report.status == :terminal_deferred
        return report.artifact === nothing && report.claim_ceiling == none &&
            receipt.execution_count == 0 && receipt.assembly_hash === nothing &&
            receipt.artifact_hash === nothing && report.evidence.claim_ceiling == none &&
            report.evidence.provider_manifest_hash === nothing &&
            isempty(report.evidence.artifact_refs) &&
            receipt.status == :terminal_deferred &&
            receipt.solver_input_hash == plan.plan_hash &&
            report.evidence.physical_subject_hash == plan.subject_hash &&
            report.evidence.scenario_hash == plan.mission.scenario_hash &&
            report.evidence.solver_input_hash == plan.plan_hash &&
            report.evidence.binding_provenance == _frp_deferred_provenance(plan) &&
            report.evidence.status_vector == StatusVectorV4(required, no_match,
                terminal_deferred, low_fidelity_evaluated, terminal_deferred_stage)
    end
    report.status in (:pass, :numerical_fail, :unknown) &&
        report.artifact isa FieldSolveResultV4 || return false
    artifact = report.artifact
    expected_provider = try field_residual_provider(plan) catch; return false end
    expected_status, expected_outcome = _frp_classify_result(artifact)
    _frp_solve_result_integrity(artifact) && artifact.protocol_hash == plan.protocol.protocol_hash &&
        report.status == expected_status && receipt.status == expected_status &&
        receipt.execution_count == 1 && receipt.assembly_hash == artifact.assembly_hash &&
        receipt.artifact_hash == artifact.result_hash && report.claim_ceiling == screen_only &&
        report.evidence.claim_ceiling == screen_only &&
        report.evidence.physical_subject_hash == plan.subject_hash &&
        report.evidence.scenario_hash == plan.mission.scenario_hash &&
        report.evidence.solver_input_hash == receipt.solver_input_hash &&
        report.evidence.provider_manifest_hash == expected_provider.manifest_hash &&
        report.evidence.backend_revision == expected_provider.backend_revision &&
        report.evidence.independence_group == expected_provider.independence_group &&
        report.evidence.numerical_configuration_hash ==
            canonical_hash((protocol_hash=plan.protocol.protocol_hash,)) &&
        report.evidence.status_vector == StatusVectorV4(required, unique_match,
            resolved, low_fidelity_evaluated, expected_outcome) &&
        report.evidence.artifact_refs ==
            (plan.u_result_hash, plan.f_result_hash, artifact.result_hash) &&
        report.evidence.binding_provenance ==
            _frp_execution_provenance(plan, artifact.assembly_hash)
end
validate_field_residual_report = validate_field_residual_pipeline_report
replay_field_residual_pipeline = validate_field_residual_pipeline_report

function build_manufactured_field_convergence_receipt(plans::Tuple, reports::Tuple,
        u_reports::Tuple)
    length(plans) == length(reports) == length(u_reports) == 3 ||
        throw(ArgumentError("D4.1 convergence requires exactly three cases"))
    all(plan -> plan isa FieldResidualPipelinePlanV4, plans) || throw(ArgumentError("convergence plans must be typed"))
    all(report -> report isa FieldResidualPipelineReportV4, reports) || throw(ArgumentError("convergence reports must be typed"))
    all(report -> report isa FieldEvaluationReportV4, u_reports) || throw(ArgumentError("convergence references must be G2 reports"))
    expected_sizes = (5, 9, 17)
    for i in 1:3
        _frp_validate_plan(plans[i])
        validate_field_residual_pipeline_report(plans[i], reports[i]) ||
            throw(ArgumentError("convergence contains an invalid residual report"))
        reports[i].status == :pass || throw(ArgumentError("convergence requires passed solves"))
        plans[i].u_plan_hash == u_reports[i].plan.plan_hash || throw(ArgumentError("convergence reference plan mismatch"))
        plans[i].u_result_hash == u_reports[i].result.result_hash &&
            plans[i].u_evidence_id == u_reports[i].evidence.evidence_id ||
            throw(ArgumentError("convergence reference evidence mismatch"))
        u_reports[i].status == :evaluated_screen && u_reports[i].result isa FieldEvaluationResultV4 &&
            _frp_field_result_integrity(u_reports[i].result) || throw(ArgumentError("convergence reference result is invalid"))
        all(length(axis) == expected_sizes[i] for axis in plans[i].grid.axes) ||
            throw(ArgumentError("D4.1 convergence grids must be 5/9/17 cubical grids"))
        length(reports[i].artifact.solution) == length(u_reports[i].result.values) ||
            throw(ArgumentError("convergence solution/reference size mismatch"))
    end
    errors = ntuple(i -> maximum(abs.(collect(reports[i].artifact.solution) .-
        Float64.(u_reports[i].result.values))), 3)
    all(isfinite, errors) && all(errors[i] > errors[i + 1] for i in 1:2) ||
        throw(ArgumentError("manufactured errors are not finite and strictly decreasing"))
    intervals = ntuple(i -> length(plans[i].grid.axes[1]) - 1, 3)
    orders = ntuple(i -> log(errors[i] / errors[i + 1]) /
        log(intervals[i + 1] / intervals[i]), 2)
    all(order -> 1.8 <= order <= 2.2, orders) ||
        throw(ArgumentError("manufactured convergence order is outside [1.8, 2.2]"))
    plan_hashes = ntuple(i -> plans[i].plan_hash, 3)
    report_hashes = ntuple(i -> reports[i].report_hash, 3)
    reference_hashes = ntuple(i -> u_reports[i].result.result_hash, 3)
    body = (plan_hashes=plan_hashes, report_hashes=report_hashes,
        reference_result_hashes=reference_hashes, errors=errors, orders=orders,
        status=:pass, claim_ceiling=screen_only)
    ManufacturedFieldConvergenceReceiptV4(_FRP_TOKEN, plan_hashes, report_hashes,
        reference_hashes, errors, orders, :pass, screen_only, canonical_hash(body))
end
build_manufactured_field_convergence_receipt(errors, orders) =
    throw(ArgumentError("caller-supplied convergence errors/orders are not accepted"))

function validate_manufactured_field_convergence_receipt(receipt::ManufacturedFieldConvergenceReceiptV4)
    expected_orders = ntuple(i -> log(receipt.errors[i] / receipt.errors[i + 1]) / log(2.0), 2)
    receipt.status == :pass && receipt.claim_ceiling == screen_only &&
        all(error -> isfinite(error) && error > 0.0, receipt.errors) &&
        all(receipt.errors[i] > receipt.errors[i + 1] for i in 1:2) &&
        all(order -> 1.8 <= order <= 2.2, receipt.orders) &&
        all(isapprox(receipt.orders[i], expected_orders[i]; rtol=0.0, atol=16eps(Float64)) for i in 1:2) &&
        receipt.receipt_hash == canonical_hash(semantic_view(receipt))
end
