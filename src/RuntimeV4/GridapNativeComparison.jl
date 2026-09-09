"""Batch C: candidate-bound numerical V&V across native FD and Gridap FE.

This isolated layer consumes sealed provider outputs. It never assembles or
solves either discretization and it never turns manufactured controls into
physical, engineering, validation, promotion, or terminal authority.
"""

using LinearAlgebra
using SHA

const _GNC_SCHEMA = "runtime-v4-gridap-native-comparison"
const _GNC_REVISION = "batch-c-v1"
const _GNC_COORDINATE_TOLERANCE = 64eps(Float64)
const _GNC_RELATIVE_SCALE_FLOOR = 1.0e-12

# Conservative transfer bands frozen by source before the accepted fixture is
# constructed. Native and Gridap order bands remain owned by their sealed
# convergence receipts.
const _GNC_TRANSFER_BANDS = (
    linf_upper=(0.75, 0.20, 0.055),
    l2_upper=(0.95, 0.24, 0.060),
    relative_l2_upper=(0.14, 0.045, 0.012),
    order=(1.5, 2.5),
    coordinate_linf=_GNC_COORDINATE_TOLERANCE,
    interpolation_linf=0.0)

struct _GridapNativeComparisonToken end
const _GNC_TOKEN = _GridapNativeComparisonToken()

gridap_native_comparison_source_hash() =
    Digest256(bytes2hex(SHA.sha256(read(@__FILE__))))

"""Evidence that one native provider result replayed in a distinct fresh store."""
struct NativeFieldReplayWitnessV4
    plan::FieldResidualPipelinePlanV4
    primary_store::FieldResidualPipelineStoreV4
    replay_store::FieldResidualPipelineStoreV4
    solver_input_hash::Digest256
    primary_report_hash::Digest256
    replay_report_hash::Digest256
    receipt_hash::Digest256
    assembly_hash::Digest256
    result_hash::Digest256
    provider_hash::Digest256
    primary_snapshot_hash::Digest256
    replay_snapshot_hash::Digest256
    witness_hash::Digest256
    function NativeFieldReplayWitnessV4(token::_GridapNativeComparisonToken, args...)
        token === _GNC_TOKEN || throw(ArgumentError("private native replay witness"))
        new(args...)
    end
end

NativeFieldReplayWitnessV4(args...) =
    throw(ArgumentError("native replay witness is sealed"))

function _gnc_native_store_snapshot(store::FieldResidualPipelineStoreV4,
        plan::FieldResidualPipelinePlanV4, solver_input_hash::Digest256)
    get(store.execution_counts, solver_input_hash, 0) == 1 ||
        throw(ArgumentError("native replay store must contain exactly one execution"))
    report = get(store.reports, solver_input_hash, nothing)
    report isa FieldResidualPipelineReportV4 ||
        throw(ArgumentError("native replay store has no typed report"))
    validate_field_residual_pipeline_report(plan, report) ||
        throw(ArgumentError("native replay store contains an invalid report"))
    report.status === :pass && report.artifact isa FieldSolveResultV4 ||
        throw(ArgumentError("native replay requires a passed solve artifact"))
    report.receipt.solver_input_hash == solver_input_hash ||
        throw(ArgumentError("native replay solver-input mismatch"))
    artifact = report.artifact
    get(store.artifacts, artifact.result_hash, nothing) === artifact ||
        throw(ArgumentError("native replay artifact store mismatch"))
    body = (solver_input_hash=solver_input_hash, report_hash=report.report_hash,
        receipt_hash=report.receipt.receipt_hash,
        assembly_hash=report.receipt.assembly_hash,
        result_hash=artifact.result_hash, execution_count=1)
    report, canonical_hash(body)
end

function _gnc_witness_body(w::NativeFieldReplayWitnessV4)
    (revision=_GNC_REVISION, plan_hash=w.plan.plan_hash,
     solver_input_hash=w.solver_input_hash,
     primary_report_hash=w.primary_report_hash,
     replay_report_hash=w.replay_report_hash,
     receipt_hash=w.receipt_hash, assembly_hash=w.assembly_hash,
     result_hash=w.result_hash, provider_hash=w.provider_hash,
     primary_snapshot_hash=w.primary_snapshot_hash,
     replay_snapshot_hash=w.replay_snapshot_hash,
     distinct_stores=true)
end

semantic_view(w::NativeFieldReplayWitnessV4) =
    merge(_gnc_witness_body(w), (witness_hash=w.witness_hash,))
canonical_hash(w::NativeFieldReplayWitnessV4) = w.witness_hash

function make_native_field_replay_witness(plan::FieldResidualPipelinePlanV4,
        primary_store::FieldResidualPipelineStoreV4,
        replay_store::FieldResidualPipelineStoreV4,
        solver_input_hash::Digest256)
    primary_store !== replay_store ||
        throw(ArgumentError("native replay requires distinct stores"))
    primary, primary_snapshot =
        _gnc_native_store_snapshot(primary_store, plan, solver_input_hash)
    replay, replay_snapshot =
        _gnc_native_store_snapshot(replay_store, plan, solver_input_hash)
    primary.report_hash == replay.report_hash ||
        throw(ArgumentError("native fresh replay report mismatch"))
    primary.receipt.receipt_hash == replay.receipt.receipt_hash ||
        throw(ArgumentError("native fresh replay receipt mismatch"))
    primary.artifact.result_hash == replay.artifact.result_hash ||
        throw(ArgumentError("native fresh replay result mismatch"))
    provider_hash = field_residual_provider(plan).manifest_hash
    primary.evidence.provider_manifest_hash == provider_hash ||
        throw(ArgumentError("native provider binding mismatch"))
    body = (revision=_GNC_REVISION, plan_hash=plan.plan_hash,
        solver_input_hash=solver_input_hash,
        primary_report_hash=primary.report_hash,
        replay_report_hash=replay.report_hash,
        receipt_hash=primary.receipt.receipt_hash,
        assembly_hash=primary.receipt.assembly_hash,
        result_hash=primary.artifact.result_hash, provider_hash=provider_hash,
        primary_snapshot_hash=primary_snapshot,
        replay_snapshot_hash=replay_snapshot, distinct_stores=true)
    NativeFieldReplayWitnessV4(_GNC_TOKEN, plan, primary_store, replay_store,
        solver_input_hash, primary.report_hash, replay.report_hash,
        primary.receipt.receipt_hash, primary.receipt.assembly_hash,
        primary.artifact.result_hash, provider_hash, primary_snapshot,
        replay_snapshot, canonical_hash(body))
end

function validate_native_field_replay_witness(w::NativeFieldReplayWitnessV4)
    try
        w.primary_store !== w.replay_store || return false
        primary, primary_snapshot = _gnc_native_store_snapshot(
            w.primary_store, w.plan, w.solver_input_hash)
        replay, replay_snapshot = _gnc_native_store_snapshot(
            w.replay_store, w.plan, w.solver_input_hash)
        provider_hash = field_residual_provider(w.plan).manifest_hash
        primary.report_hash == replay.report_hash == w.primary_report_hash ==
            w.replay_report_hash || return false
        primary.receipt.receipt_hash == replay.receipt.receipt_hash ==
            w.receipt_hash || return false
        primary.receipt.assembly_hash == replay.receipt.assembly_hash ==
            w.assembly_hash || return false
        primary.artifact.result_hash == replay.artifact.result_hash ==
            w.result_hash || return false
        primary.evidence.provider_manifest_hash ==
            replay.evidence.provider_manifest_hash == provider_hash ==
            w.provider_hash || return false
        primary_snapshot == w.primary_snapshot_hash || return false
        replay_snapshot == w.replay_snapshot_hash || return false
        canonical_hash(_gnc_witness_body(w)) == w.witness_hash
    catch
        false
    end
end

function _gnc_primary_report(w::NativeFieldReplayWitnessV4)
    validate_native_field_replay_witness(w) ||
        throw(ArgumentError("invalid native replay witness"))
    w.primary_store.reports[w.solver_input_hash]
end

"""One explicit common-domain transfer operator and its separated metrics."""
struct GridapNativeTransferCaseV4
    nodes_per_axis::Int
    domain_identity::NamedTuple
    g2_identity::NamedTuple
    payload_identity::NamedTuple
    protocol_identity::NamedTuple
    provider_identity::NamedTuple
    assembly_identity::NamedTuple
    native_coordinates_hash::Digest256
    gridap_coordinates_hash::Digest256
    native_indices::Tuple{Vararg{Int}}
    gridap_indices::Tuple{Vararg{Int}}
    quadrature_weights_hash::Digest256
    mapping_hash::Digest256
    coordinate_linf::Float64
    interpolation_linf::Float64
    transfer_linf::Float64
    transfer_l2::Float64
    transfer_relative_l2::Float64
    native_solution_linf::Float64
    gridap_solution_l2::Float64
    gridap_solution_h1::Float64
    source_interpolation_l2::Float64
    boundary_interpolation_linf::Float64
    native_residual_inf::Float64
    gridap_residual_inf::Float64
    status::Symbol
    case_hash::Digest256
    function GridapNativeTransferCaseV4(token::_GridapNativeComparisonToken, args...)
        token === _GNC_TOKEN || throw(ArgumentError("private transfer case"))
        new(args...)
    end
end

GridapNativeTransferCaseV4(args...) =
    throw(ArgumentError("Gridap/native transfer case is sealed"))

function _gnc_case_body(c::GridapNativeTransferCaseV4)
    (revision=_GNC_REVISION, nodes_per_axis=c.nodes_per_axis,
     domain_identity=c.domain_identity, g2_identity=c.g2_identity,
     payload_identity=c.payload_identity,
     protocol_identity=c.protocol_identity,
     provider_identity=c.provider_identity,
     assembly_identity=c.assembly_identity,
     native_coordinates_hash=c.native_coordinates_hash,
     gridap_coordinates_hash=c.gridap_coordinates_hash,
     native_indices=c.native_indices, gridap_indices=c.gridap_indices,
     quadrature_weights_hash=c.quadrature_weights_hash,
     mapping_hash=c.mapping_hash, coordinate_linf=c.coordinate_linf,
     interpolation_linf=c.interpolation_linf,
     transfer_linf=c.transfer_linf, transfer_l2=c.transfer_l2,
     transfer_relative_l2=c.transfer_relative_l2,
     native_solution_linf=c.native_solution_linf,
     gridap_solution_l2=c.gridap_solution_l2,
     gridap_solution_h1=c.gridap_solution_h1,
     source_interpolation_l2=c.source_interpolation_l2,
     boundary_interpolation_linf=c.boundary_interpolation_linf,
     native_residual_inf=c.native_residual_inf,
     gridap_residual_inf=c.gridap_residual_inf, status=c.status)
end

semantic_view(c::GridapNativeTransferCaseV4) =
    merge(_gnc_case_body(c), (case_hash=c.case_hash,))
canonical_hash(c::GridapNativeTransferCaseV4) = c.case_hash

function _gnc_case_integrity(c::GridapNativeTransferCaseV4)
    metrics = (c.coordinate_linf, c.interpolation_linf, c.transfer_linf,
        c.transfer_l2, c.transfer_relative_l2, c.native_solution_linf,
        c.gridap_solution_l2, c.gridap_solution_h1,
        c.source_interpolation_l2, c.boundary_interpolation_linf,
        c.native_residual_inf, c.gridap_residual_inf)
    c.status in (:pass, :numerical_fail) && c.nodes_per_axis in (5, 9, 17) &&
        length(c.native_indices) == c.nodes_per_axis^3 &&
        length(c.gridap_indices) == c.nodes_per_axis^3 &&
        c.native_indices == Tuple(1:c.nodes_per_axis^3) &&
        length(unique(c.gridap_indices)) == length(c.gridap_indices) &&
        all(isfinite, metrics) && all(>=(0.0), metrics) &&
        canonical_hash((native_coordinates_hash=c.native_coordinates_hash,
            gridap_coordinates_hash=c.gridap_coordinates_hash,
            native_indices=c.native_indices, gridap_indices=c.gridap_indices,
            quadrature_weights_hash=c.quadrature_weights_hash,
            method=:exact_coordinate_bijection_then_tensor_trapezoid_l2)) ==
                c.mapping_hash &&
        canonical_hash(_gnc_case_body(c)) == c.case_hash
end

struct GridapNativeComparisonReceiptV4
    native_convergence_hash::Digest256
    gridap_convergence_hash::Digest256
    native_witness_hashes::NTuple{3,Digest256}
    gridap_bundle_hashes::NTuple{3,Digest256}
    transfer_case_hashes::NTuple{3,Digest256}
    native_independence_group::String
    gridap_independence_group::String
    gridap_dependency_hash::Digest256
    source_hash::Digest256
    receipt_hash::Digest256
    function GridapNativeComparisonReceiptV4(token::_GridapNativeComparisonToken, args...)
        token === _GNC_TOKEN || throw(ArgumentError("private comparison receipt"))
        new(args...)
    end
end

GridapNativeComparisonReceiptV4(args...) =
    throw(ArgumentError("Gridap/native comparison receipt is sealed"))

function _gnc_receipt_body(r::GridapNativeComparisonReceiptV4)
    (revision=_GNC_REVISION,
     native_convergence_hash=r.native_convergence_hash,
     gridap_convergence_hash=r.gridap_convergence_hash,
     native_witness_hashes=r.native_witness_hashes,
     gridap_bundle_hashes=r.gridap_bundle_hashes,
     transfer_case_hashes=r.transfer_case_hashes,
     native_independence_group=r.native_independence_group,
     gridap_independence_group=r.gridap_independence_group,
     matrix_identity=:independent_discretizations,
     rhs_identity=:independent_discretizations,
     gridap_dependency_hash=r.gridap_dependency_hash,
     source_hash=r.source_hash)
end

semantic_view(r::GridapNativeComparisonReceiptV4) =
    merge(_gnc_receipt_body(r), (receipt_hash=r.receipt_hash,))
canonical_hash(r::GridapNativeComparisonReceiptV4) = r.receipt_hash

struct FieldNumericalComparisonV4
    status::Symbol
    transfer_cases::NTuple{3,GridapNativeTransferCaseV4}
    receipt::GridapNativeComparisonReceiptV4
    native_linf_errors::NTuple{3,Float64}
    native_linf_orders::NTuple{2,Float64}
    gridap_l2_errors::NTuple{3,Float64}
    gridap_h1_errors::NTuple{3,Float64}
    gridap_l2_orders::NTuple{2,Float64}
    gridap_h1_orders::NTuple{2,Float64}
    transfer_linf_errors::NTuple{3,Float64}
    transfer_l2_errors::NTuple{3,Float64}
    transfer_relative_l2_errors::NTuple{3,Float64}
    transfer_linf_orders::NTuple{2,Float64}
    transfer_l2_orders::NTuple{2,Float64}
    acceptance_bands::NamedTuple
    rejection_reasons::Tuple{Vararg{String}}
    evidence_class::Symbol
    claim_ceiling::ClaimCeiling
    credible_physical_candidate_count::Int
    p5_ready::Bool
    unsupported_emitted::Bool
    report_hash::Digest256
    function FieldNumericalComparisonV4(token::_GridapNativeComparisonToken, args...)
        token === _GNC_TOKEN || throw(ArgumentError("private numerical comparison"))
        new(args...)
    end
end

FieldNumericalComparisonV4(args...) =
    throw(ArgumentError("field numerical comparison is sealed"))

function _gnc_report_body(r::FieldNumericalComparisonV4)
    (revision=_GNC_REVISION, status=r.status,
     transfer_case_hashes=Tuple(c.case_hash for c in r.transfer_cases),
     receipt_hash=r.receipt.receipt_hash,
     native_linf_errors=r.native_linf_errors,
     native_linf_orders=r.native_linf_orders,
     gridap_l2_errors=r.gridap_l2_errors,
     gridap_h1_errors=r.gridap_h1_errors,
     gridap_l2_orders=r.gridap_l2_orders,
     gridap_h1_orders=r.gridap_h1_orders,
     transfer_linf_errors=r.transfer_linf_errors,
     transfer_l2_errors=r.transfer_l2_errors,
     transfer_relative_l2_errors=r.transfer_relative_l2_errors,
     transfer_linf_orders=r.transfer_linf_orders,
     transfer_l2_orders=r.transfer_l2_orders,
     acceptance_bands=r.acceptance_bands,
     rejection_reasons=r.rejection_reasons,
     evidence_class=r.evidence_class, claim_ceiling=r.claim_ceiling,
     credible_physical_candidate_count=r.credible_physical_candidate_count,
     p5_ready=r.p5_ready, unsupported_emitted=r.unsupported_emitted)
end

semantic_view(r::FieldNumericalComparisonV4) =
    merge(_gnc_report_body(r), (report_hash=r.report_hash,))
canonical_hash(r::FieldNumericalComparisonV4) = r.report_hash

const GridapNativeComparisonReportV4 = FieldNumericalComparisonV4

function _gnc_physical_coordinates(plan::FieldResidualPipelinePlanV4)
    axes = plan.grid.axes
    Tuple(Tuple(Float64.(_gridap_chart_to_physical(plan.geometry,
        (axes[1][i], axes[2][j], axes[3][k]))))
        for i in eachindex(axes[1]), j in eachindex(axes[2]),
            k in eachindex(axes[3]))
end

function _gnc_coordinate_transfer(native_coordinates::Tuple,
        gridap_coordinates::Tuple)
    length(native_coordinates) == length(gridap_coordinates) ||
        throw(ArgumentError("transfer coordinate cardinality mismatch"))
    by_coordinate = Dict{NTuple{3,Float64},Int}()
    for (index, coordinate) in enumerate(gridap_coordinates)
        q = Tuple(Float64.(coordinate))
        length(q) == 3 || throw(ArgumentError("Gridap coordinate is not 3-D"))
        haskey(by_coordinate, q) &&
            throw(ArgumentError("duplicate Gridap transfer coordinate"))
        by_coordinate[q] = index
    end
    mapping = Tuple(begin
        q = Tuple(Float64.(coordinate))
        get(by_coordinate, q, 0) != 0 ||
            throw(ArgumentError("native coordinate has no exact Gridap peer"))
        by_coordinate[q]
    end for coordinate in native_coordinates)
    length(unique(mapping)) == length(mapping) ||
        throw(ArgumentError("transfer mapping is not bijective"))
    coordinate_linf = maximum(maximum(abs.(native_coordinates[i] .-
        gridap_coordinates[mapping[i]])) for i in eachindex(mapping))
    coordinate_linf <= _GNC_COORDINATE_TOLERANCE ||
        throw(ArgumentError("transfer coordinate mismatch"))
    mapping, coordinate_linf
end

function _gnc_axis_weights(axis::Tuple)
    length(axis) >= 2 || throw(ArgumentError("transfer axis needs two nodes"))
    n = length(axis)
    ntuple(i -> i == 1 ? abs(axis[2] - axis[1]) / 2 :
        i == n ? abs(axis[n] - axis[n - 1]) / 2 :
        abs(axis[i + 1] - axis[i - 1]) / 2, n)
end

function _gnc_tensor_weights(plan::FieldResidualPipelinePlanV4)
    geometry = plan.geometry
    axes = ntuple(d -> Tuple(Float64(geometry.scale * geometry.factors[d] * q +
        geometry.offsets[d]) for q in plan.grid.axes[d]), 3)
    weights = ntuple(d -> _gnc_axis_weights(axes[d]), 3)
    Tuple(weights[1][i] * weights[2][j] * weights[3][k]
        for i in eachindex(weights[1]), j in eachindex(weights[2]),
            k in eachindex(weights[3]))
end

function _gnc_common_identity(compilation::GridapFieldResidualCompilationV4,
        compiled::CompiledCandidatePrefixV4,
        genome_registry::GenomeContractRegistryV4, scenario)
    plan = compilation.plan
    geometry = plan.native_plan.geometry
    _runtime_validate_compiled_prefix(compiled, compiled.candidate,
        genome_registry, compiled.mission_payload, compiled.bounds_payload,
        compiled.minimality_scope.comparison_scope,
        compiled.minimality_scope.scenario_scope)
    compiled.prefix_hash == plan.prefix_hash ||
        throw(ArgumentError("comparison prefix mismatch"))
    canonical_hash(genome_registry) == plan.registry_hash ||
        throw(ArgumentError("comparison registry mismatch"))
    compiled.candidate.canonical_hashes.genome_bundle_hash == plan.candidate_hash ||
        throw(ArgumentError("comparison candidate mismatch"))
    compiled.minimality_scope.mission_hash == plan.mission_hash ||
        throw(ArgumentError("comparison mission mismatch"))
    canonical_hash(scenario) == plan.scenario_hash ||
        throw(ArgumentError("comparison scenario mismatch"))
    continuous_geometry_hash = canonical_hash((
        support_hash=canonical_hash(geometry.support),
        chart_ref=geometry.chart_ref, factors=geometry.factors,
        offsets=geometry.offsets, scale=geometry.scale, jhat=geometry.jhat,
        ghat=geometry.ghat, laplace_weights=geometry.laplace_weights))
    (candidate_hash=plan.candidate_hash, prefix_hash=plan.prefix_hash,
     registry_hash=plan.registry_hash, mission_hash=plan.mission_hash,
     bounds_hash=compiled.minimality_scope.bounds_hash,
     scenario_hash=plan.scenario_hash,
     constraint_edge_hash=plan.constraint_edge_hash,
     form_hash=plan.form_hash,
     continuous_geometry_hash=continuous_geometry_hash)
end

function _gnc_build_case(bundle::GridapFieldEvidenceBundleV4,
        witness::NativeFieldReplayWitnessV4,
        native_case_index::Int,
        native_convergence::ManufacturedFieldConvergenceReceiptV4,
        gridap_case::GridapFieldConvergenceCaseV4,
        compiled::CompiledCandidatePrefixV4,
        genome_registry::GenomeContractRegistryV4, scenario;
        fresh_replay::Bool)
    validate_gridap_field_evidence(bundle) ||
        throw(ArgumentError("invalid Gridap B3 bundle"))
    bundle.status === :pass && bundle.report isa GridapFieldResidualReportV4 ||
        throw(ArgumentError("Gridap B3 bundle has no passed report"))
    if fresh_replay
        replay_gridap_field_evidence_fresh(bundle) ||
            throw(ArgumentError("Gridap provider fresh replay mismatch"))
    end
    validate_native_field_replay_witness(witness) ||
        throw(ArgumentError("invalid native provider replay witness"))

    compilation = bundle.compilation
    gridap_report = bundle.report
    native_plan = witness.plan
    native_report = _gnc_primary_report(witness)
    native_result = native_report.artifact
    plan = compilation.plan
    native_plan.plan_hash == plan.native_plan_hash ||
        throw(ArgumentError("native/Gridap plan mismatch"))
    gridap_case.plan_hash == plan.plan_hash ||
        throw(ArgumentError("Gridap B2/B3 plan mismatch"))
    gridap_case.grid_hash == plan.grid_hash ||
        throw(ArgumentError("Gridap B2/B3 grid mismatch"))
    gridap_case.g2_u_result_hash == plan.u_result_hash &&
        gridap_case.g2_f_result_hash == plan.f_result_hash ||
        throw(ArgumentError("Gridap B2/B3 G2 result mismatch"))
    gridap_case.cells == gridap_report.receipt.cells &&
        gridap_case.dofs == gridap_report.receipt.free_dofs ||
        throw(ArgumentError("Gridap B2/B3 mesh receipt mismatch"))
    gridap_case.residual == gridap_report.result.residual_abs ||
        throw(ArgumentError("Gridap B2/B3 residual mismatch"))
    native_convergence.plan_hashes[native_case_index] == native_plan.plan_hash ||
        throw(ArgumentError("native convergence plan mismatch"))
    native_convergence.report_hashes[native_case_index] == native_report.report_hash ||
        throw(ArgumentError("native convergence report mismatch"))
    gridap_report.plan_hash == plan.plan_hash ||
        throw(ArgumentError("Gridap report plan mismatch"))
    bundle.subject.bounds_hash == compiled.minimality_scope.bounds_hash ||
        throw(ArgumentError("Gridap bundle bounds mismatch"))

    domain = _gnc_common_identity(compilation, compiled, genome_registry, scenario)
    native_plan.candidate_hash == domain.candidate_hash &&
        native_plan.prefix_hash == domain.prefix_hash &&
        native_plan.registry_hash == domain.registry_hash &&
        native_plan.mission.mission_hash == domain.mission_hash &&
        native_plan.mission.scenario_hash == domain.scenario_hash &&
        native_plan.mission.constraint_edge_hash == domain.constraint_edge_hash &&
        native_plan.form.form_hash == domain.form_hash &&
        native_plan.grid.grid_hash == plan.grid_hash ||
        throw(ArgumentError("native/Gridap domain identity mismatch"))

    geometry = native_plan.geometry
    continuous_geometry_hash = canonical_hash((
        support_hash=canonical_hash(geometry.support),
        chart_ref=geometry.chart_ref, factors=geometry.factors,
        offsets=geometry.offsets, scale=geometry.scale, jhat=geometry.jhat,
        ghat=geometry.ghat, laplace_weights=geometry.laplace_weights))
    continuous_geometry_hash == domain.continuous_geometry_hash ||
        throw(ArgumentError("native/Gridap continuous geometry mismatch"))

    native_provider = field_residual_provider(native_plan)
    native_provider.manifest_hash == witness.provider_hash ||
        throw(ArgumentError("native provider witness mismatch"))
    native_provider.independence_group != bundle.provider.independence_group ||
        throw(ArgumentError("providers do not have independent assembly groups"))
    native_provider.code_hash != bundle.provider.code_hash ||
        throw(ArgumentError("providers unexpectedly share one code identity"))

    native_coordinates = _gnc_physical_coordinates(native_plan)
    gridap_coordinates = Tuple(Tuple(Float64.(sample.coordinate))
        for sample in gridap_report.result.physical_samples)
    length(native_result.solution) == length(native_coordinates) ||
        throw(ArgumentError("native solution coordinate mismatch"))
    mapping, coordinate_linf =
        _gnc_coordinate_transfer(native_coordinates, gridap_coordinates)
    native_values = Float64.(native_result.solution)
    gridap_values = Tuple(Float64(gridap_report.result.physical_samples[mapping[i]].value)
        for i in eachindex(mapping))
    all(isfinite, native_values) && all(isfinite, gridap_values) ||
        throw(ArgumentError("non-finite transfer values"))
    delta = Tuple(native_values[i] - gridap_values[i]
        for i in eachindex(native_values))
    weights = _gnc_tensor_weights(native_plan)
    all(isfinite, weights) && all(>(0.0), weights) ||
        throw(ArgumentError("invalid common-domain quadrature weights"))
    transfer_linf = maximum(abs, delta)
    transfer_l2 = sqrt(sum(weights[i] * delta[i]^2 for i in eachindex(delta)))
    reference_l2 = sqrt(sum(weights[i] * gridap_values[i]^2
        for i in eachindex(gridap_values)))
    transfer_relative_l2 = transfer_l2 /
        max(reference_l2, _GNC_RELATIVE_SCALE_FLOOR)

    g2_identity = (geometry_hash=plan.geometry_hash, grid_hash=plan.grid_hash,
        u_plan_hash=plan.u_plan_hash, f_plan_hash=plan.f_plan_hash,
        u_result_hash=plan.u_result_hash, f_result_hash=plan.f_result_hash,
        u_evidence_id=plan.u_evidence_id, f_evidence_id=plan.f_evidence_id)
    payload_identity = (source_content_hash=plan.source_content_hash,
        boundary_content_hash=plan.boundary_content_hash)
    protocol_identity = (native_protocol_hash=native_plan.protocol.protocol_hash,
        gridap_protocol_hash=plan.protocol.protocol_hash,
        gridap_dependency_hash=plan.dependency_identity.dependency_hash,
        gridap_adapter_code_hash=plan.adapter_code_hash,
        native_code_hash=native_plan.code_hash)
    provider_identity = (native_plan_hash=native_plan.plan_hash,
        native_provider_hash=native_provider.manifest_hash,
        native_solver_input_hash=witness.solver_input_hash,
        native_report_hash=native_report.report_hash,
        native_replay_witness_hash=witness.witness_hash,
        gridap_plan_hash=plan.plan_hash, gridap_bundle_hash=bundle.bundle_hash,
        gridap_provider_hash=bundle.provider.manifest_hash,
        gridap_solver_input_hash=bundle.input.solver_input_hash,
        gridap_evidence_id=bundle.evidence.evidence_id,
        gridap_replay_hash=bundle.replay.envelope_hash,
        gridap_report_hash=gridap_report.report_hash)
    assembly_identity = (matrix_identity=:independent_discretizations,
        rhs_identity=:independent_discretizations,
        native_assembly_hash=native_report.receipt.assembly_hash,
        native_result_hash=native_result.result_hash,
        gridap_assembly_hash=gridap_report.receipt.assembly_hash,
        gridap_matrix_hash=gridap_report.receipt.matrix_hash,
        gridap_rhs_hash=gridap_report.receipt.rhs_hash,
        gridap_result_hash=gridap_report.result.result_hash)
    native_indices = Tuple(eachindex(native_coordinates))
    native_coordinates_hash = canonical_hash(native_coordinates)
    gridap_coordinates_hash = canonical_hash(gridap_coordinates)
    weights_hash = canonical_hash(weights)
    mapping_hash = canonical_hash((native_coordinates_hash=native_coordinates_hash,
        gridap_coordinates_hash=gridap_coordinates_hash,
        native_indices=native_indices, gridap_indices=mapping,
        quadrature_weights_hash=weights_hash,
        method=:exact_coordinate_bijection_then_tensor_trapezoid_l2))
    metrics = (coordinate_linf, 0.0, transfer_linf, transfer_l2,
        transfer_relative_l2, native_convergence.errors[native_case_index],
        gridap_case.solution_l2, gridap_case.solution_h1_seminorm,
        gridap_case.source_cell_center_rms,
        gridap_case.boundary_face_center_linf,
        Float64(native_result.residual_norm), gridap_report.result.residual_abs)
    body = (revision=_GNC_REVISION, nodes_per_axis=gridap_case.nodes_per_axis,
        domain_identity=domain, g2_identity=g2_identity,
        payload_identity=payload_identity, protocol_identity=protocol_identity,
        provider_identity=provider_identity, assembly_identity=assembly_identity,
        native_coordinates_hash=native_coordinates_hash,
        gridap_coordinates_hash=gridap_coordinates_hash,
        native_indices=native_indices, gridap_indices=mapping,
        quadrature_weights_hash=weights_hash, mapping_hash=mapping_hash,
        coordinate_linf=metrics[1], interpolation_linf=metrics[2],
        transfer_linf=metrics[3], transfer_l2=metrics[4],
        transfer_relative_l2=metrics[5], native_solution_linf=metrics[6],
        gridap_solution_l2=metrics[7], gridap_solution_h1=metrics[8],
        source_interpolation_l2=metrics[9],
        boundary_interpolation_linf=metrics[10],
        native_residual_inf=metrics[11], gridap_residual_inf=metrics[12],
        status=:pass)
    GridapNativeTransferCaseV4(_GNC_TOKEN, gridap_case.nodes_per_axis,
        domain, g2_identity, payload_identity, protocol_identity,
        provider_identity, assembly_identity, native_coordinates_hash,
        gridap_coordinates_hash, native_indices, mapping, weights_hash,
        mapping_hash, metrics..., :pass, canonical_hash(body))
end

_gnc_orders(errors::NTuple{3,Float64}) =
    ntuple(i -> log(errors[i] / errors[i + 1]) / log(2.0), 2)

function _gnc_acceptance(cases::NTuple{3,GridapNativeTransferCaseV4})
    reasons = String[]
    linf = ntuple(i -> cases[i].transfer_linf, 3)
    l2 = ntuple(i -> cases[i].transfer_l2, 3)
    relative = ntuple(i -> cases[i].transfer_relative_l2, 3)
    linf_orders = all(>(0.0), linf) ? _gnc_orders(linf) : (NaN, NaN)
    l2_orders = all(>(0.0), l2) ? _gnc_orders(l2) : (NaN, NaN)
    all(cases[i].coordinate_linf <= _GNC_TRANSFER_BANDS.coordinate_linf
        for i in 1:3) || push!(reasons, "coordinate_transfer")
    all(cases[i].interpolation_linf <= _GNC_TRANSFER_BANDS.interpolation_linf
        for i in 1:3) || push!(reasons, "interpolation_transfer")
    all(linf[i] <= _GNC_TRANSFER_BANDS.linf_upper[i] for i in 1:3) ||
        push!(reasons, "transfer_linf_band")
    all(l2[i] <= _GNC_TRANSFER_BANDS.l2_upper[i] for i in 1:3) ||
        push!(reasons, "transfer_l2_band")
    all(relative[i] <= _GNC_TRANSFER_BANDS.relative_l2_upper[i] for i in 1:3) ||
        push!(reasons, "transfer_relative_l2_band")
    all(linf[i] > linf[i + 1] && l2[i] > l2[i + 1] for i in 1:2) ||
        push!(reasons, "transfer_nonrefining")
    band = _GNC_TRANSFER_BANDS.order
    all(isfinite(o) && band[1] <= o <= band[2]
        for o in (linf_orders..., l2_orders...)) ||
        push!(reasons, "transfer_order_band")
    Tuple(reasons), linf, l2, relative, linf_orders, l2_orders
end

function _gnc_build_comparison(
        gridap_bundles::NTuple{3,GridapFieldEvidenceBundleV4},
        native_witnesses::NTuple{3,NativeFieldReplayWitnessV4},
        native_convergence::ManufacturedFieldConvergenceReceiptV4,
        gridap_convergence::GridapFieldConvergenceReceiptV4;
        compiled::CompiledCandidatePrefixV4,
        genome_registry::GenomeContractRegistryV4, scenario,
        fresh_replay::Bool)
    validate_manufactured_field_convergence_receipt(native_convergence) ||
        throw(ArgumentError("invalid native convergence receipt"))
    validate_gridap_field_convergence_receipt(gridap_convergence) ||
        throw(ArgumentError("invalid Gridap convergence receipt"))
    Tuple(c.nodes_per_axis for c in gridap_convergence.cases) == (5, 9, 17) ||
        throw(ArgumentError("Batch C requires the frozen 5/9/17 series"))
    cases = ntuple(i -> _gnc_build_case(gridap_bundles[i],
        native_witnesses[i], i, native_convergence,
        gridap_convergence.cases[i], compiled, genome_registry, scenario;
        fresh_replay=fresh_replay), 3)
    all(_gnc_case_integrity, cases) ||
        throw(ArgumentError("invalid transfer case"))
    length(unique(c.domain_identity for c in cases)) == 1 ||
        throw(ArgumentError("mixed Batch C domain identity"))
    dependency_hashes = Tuple(c.protocol_identity.gridap_dependency_hash
        for c in cases)
    length(unique(dependency_hashes)) == 1 ||
        throw(ArgumentError("mixed Gridap dependency identity"))
    native_groups = Tuple(field_residual_provider(w.plan).independence_group
        for w in native_witnesses)
    gridap_groups = Tuple(b.provider.independence_group for b in gridap_bundles)
    length(unique(native_groups)) == 1 && length(unique(gridap_groups)) == 1 ||
        throw(ArgumentError("mixed provider independence groups"))
    native_groups[1] != gridap_groups[1] ||
        throw(ArgumentError("native and Gridap providers are not independent"))

    reasons, transfer_linf, transfer_l2, transfer_relative,
        transfer_linf_orders, transfer_l2_orders = _gnc_acceptance(cases)
    status = isempty(reasons) ? :pass : :numerical_fail
    cases = ntuple(i -> begin
        c = cases[i]
        c.status == status && return c
        body = merge(_gnc_case_body(c), (status=status,))
        GridapNativeTransferCaseV4(_GNC_TOKEN, c.nodes_per_axis,
            c.domain_identity, c.g2_identity, c.payload_identity,
            c.protocol_identity, c.provider_identity, c.assembly_identity,
            c.native_coordinates_hash, c.gridap_coordinates_hash,
            c.native_indices, c.gridap_indices, c.quadrature_weights_hash,
            c.mapping_hash, c.coordinate_linf, c.interpolation_linf,
            c.transfer_linf, c.transfer_l2, c.transfer_relative_l2,
            c.native_solution_linf, c.gridap_solution_l2,
            c.gridap_solution_h1, c.source_interpolation_l2,
            c.boundary_interpolation_linf, c.native_residual_inf,
            c.gridap_residual_inf, status, canonical_hash(body))
    end, 3)

    source_hash = gridap_native_comparison_source_hash()
    receipt_body = (revision=_GNC_REVISION,
        native_convergence_hash=native_convergence.receipt_hash,
        gridap_convergence_hash=gridap_convergence.receipt_hash,
        native_witness_hashes=Tuple(w.witness_hash for w in native_witnesses),
        gridap_bundle_hashes=Tuple(b.bundle_hash for b in gridap_bundles),
        transfer_case_hashes=Tuple(c.case_hash for c in cases),
        native_independence_group=native_groups[1],
        gridap_independence_group=gridap_groups[1],
        matrix_identity=:independent_discretizations,
        rhs_identity=:independent_discretizations,
        gridap_dependency_hash=dependency_hashes[1], source_hash=source_hash)
    receipt = GridapNativeComparisonReceiptV4(_GNC_TOKEN,
        native_convergence.receipt_hash, gridap_convergence.receipt_hash,
        Tuple(w.witness_hash for w in native_witnesses),
        Tuple(b.bundle_hash for b in gridap_bundles),
        Tuple(c.case_hash for c in cases), native_groups[1], gridap_groups[1],
        dependency_hashes[1], source_hash, canonical_hash(receipt_body))
    native_errors = Tuple(Float64.(native_convergence.errors))
    native_orders = Tuple(Float64.(native_convergence.orders))
    gridap_l2 = ntuple(i -> gridap_convergence.cases[i].solution_l2, 3)
    gridap_h1 = ntuple(i -> gridap_convergence.cases[i].solution_h1_seminorm, 3)
    gridap_l2_orders = Tuple(Float64.(gridap_convergence.observed_l2_orders))
    gridap_h1_orders = Tuple(Float64.(gridap_convergence.observed_h1_orders))
    report_body = (revision=_GNC_REVISION, status=status,
        transfer_case_hashes=Tuple(c.case_hash for c in cases),
        receipt_hash=receipt.receipt_hash, native_linf_errors=native_errors,
        native_linf_orders=native_orders, gridap_l2_errors=gridap_l2,
        gridap_h1_errors=gridap_h1, gridap_l2_orders=gridap_l2_orders,
        gridap_h1_orders=gridap_h1_orders,
        transfer_linf_errors=transfer_linf,
        transfer_l2_errors=transfer_l2,
        transfer_relative_l2_errors=transfer_relative,
        transfer_linf_orders=transfer_linf_orders,
        transfer_l2_orders=transfer_l2_orders,
        acceptance_bands=_GNC_TRANSFER_BANDS, rejection_reasons=reasons,
        evidence_class=:manufactured_control, claim_ceiling=screen_only,
        credible_physical_candidate_count=0, p5_ready=false,
        unsupported_emitted=false)
    FieldNumericalComparisonV4(_GNC_TOKEN, status, cases, receipt,
        native_errors, native_orders, gridap_l2, gridap_h1,
        gridap_l2_orders, gridap_h1_orders, transfer_linf, transfer_l2,
        transfer_relative, transfer_linf_orders, transfer_l2_orders,
        _GNC_TRANSFER_BANDS, reasons, :manufactured_control, screen_only,
        0, false, false, canonical_hash(report_body))
end

function build_gridap_native_comparison(
        gridap_bundles::NTuple{3,GridapFieldEvidenceBundleV4},
        native_witnesses::NTuple{3,NativeFieldReplayWitnessV4},
        native_convergence::ManufacturedFieldConvergenceReceiptV4,
        gridap_convergence::GridapFieldConvergenceReceiptV4;
        compiled::CompiledCandidatePrefixV4,
        genome_registry::GenomeContractRegistryV4, scenario)
    _gnc_build_comparison(gridap_bundles, native_witnesses,
        native_convergence, gridap_convergence; compiled=compiled,
        genome_registry=genome_registry, scenario=scenario,
        fresh_replay=true)
end

compare_gridap_native(args...; kwargs...) =
    build_gridap_native_comparison(args...; kwargs...)

function _gnc_validate_internal(r::FieldNumericalComparisonV4)
    try
        all(_gnc_case_integrity, r.transfer_cases) || return false
        Tuple(c.nodes_per_axis for c in r.transfer_cases) == (5, 9, 17) ||
            return false
        canonical_hash(_gnc_receipt_body(r.receipt)) ==
            r.receipt.receipt_hash || return false
        r.receipt.transfer_case_hashes ==
            Tuple(c.case_hash for c in r.transfer_cases) || return false
        r.receipt.native_independence_group !=
            r.receipt.gridap_independence_group || return false
        r.receipt.source_hash == gridap_native_comparison_source_hash() ||
            return false
        reasons, linf, l2, relative, linf_orders, l2_orders =
            _gnc_acceptance(r.transfer_cases)
        r.status == (isempty(reasons) ? :pass : :numerical_fail) || return false
        r.rejection_reasons == reasons || return false
        r.transfer_linf_errors == linf || return false
        r.transfer_l2_errors == l2 || return false
        r.transfer_relative_l2_errors == relative || return false
        r.transfer_linf_orders == linf_orders || return false
        r.transfer_l2_orders == l2_orders || return false
        r.native_linf_errors ==
            ntuple(i -> r.transfer_cases[i].native_solution_linf, 3) ||
            return false
        r.gridap_l2_errors ==
            ntuple(i -> r.transfer_cases[i].gridap_solution_l2, 3) ||
            return false
        r.gridap_h1_errors ==
            ntuple(i -> r.transfer_cases[i].gridap_solution_h1, 3) ||
            return false
        r.native_linf_orders == _gnc_orders(r.native_linf_errors) ||
            return false
        r.gridap_l2_orders == _gnc_orders(r.gridap_l2_errors) || return false
        r.gridap_h1_orders == _gnc_orders(r.gridap_h1_errors) || return false
        r.acceptance_bands == _GNC_TRANSFER_BANDS || return false
        r.evidence_class === :manufactured_control || return false
        r.claim_ceiling === screen_only || return false
        r.credible_physical_candidate_count == 0 || return false
        !r.p5_ready && !r.unsupported_emitted || return false
        canonical_hash(_gnc_report_body(r)) == r.report_hash
    catch
        false
    end
end

"""A report cannot prove external provenance without its original inputs."""
validate_gridap_native_comparison(::FieldNumericalComparisonV4) = false

function validate_gridap_native_comparison(r::FieldNumericalComparisonV4,
        gridap_bundles::NTuple{3,GridapFieldEvidenceBundleV4},
        native_witnesses::NTuple{3,NativeFieldReplayWitnessV4},
        native_convergence::ManufacturedFieldConvergenceReceiptV4,
        gridap_convergence::GridapFieldConvergenceReceiptV4;
        compiled::CompiledCandidatePrefixV4,
        genome_registry::GenomeContractRegistryV4, scenario)
    try
        _gnc_validate_internal(r) || return false
        expected = _gnc_build_comparison(gridap_bundles, native_witnesses,
            native_convergence, gridap_convergence; compiled=compiled,
            genome_registry=genome_registry, scenario=scenario,
            fresh_replay=false)
        expected.report_hash == r.report_hash &&
            expected.receipt.receipt_hash == r.receipt.receipt_hash &&
            expected.transfer_cases == r.transfer_cases
    catch
        false
    end
end

validate_field_numerical_comparison(args...; kwargs...) =
    validate_gridap_native_comparison(args...; kwargs...)

gridap_native_comparison_manifest() = (
    schema=_GNC_SCHEMA, revision=_GNC_REVISION,
    evidence_class=:manufactured_control, claim_ceiling=screen_only,
    compares_independent_discretizations=true, physical_validation=false,
    engineering_validation=false, terminal_authority=false)
