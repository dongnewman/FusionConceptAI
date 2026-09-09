"""Candidate-bound B1 Gridap weak-form adapter.

This file is loaded only in the isolated Gridap qualification environment. It
reuses the frozen typed D4.1 form, geometry, and G2 reports, but it assembles
and solves its own three-dimensional finite-element weak form. It never
consumes a native finite-difference assembly or result.
"""

using Gridap
using LinearAlgebra
using SparseArrays
using SHA
using TOML

const _GRIDAP_FIELD_SCHEMA = "runtime-v4-gridap-field-residual"
const _GRIDAP_FIELD_REVISION = "b1"
const _GRIDAP_WEAK_FORM_REVISION = "linear-static-scalar-weak-form-v1"
const _GRIDAP_INTERPOLATION_REVISION = "tensor-product-trilinear-from-g2-nodes-v1"
const _GRIDAP_REPLAY_REVISION = "fresh-gridap-reassembly-v1"
const _GRIDAP_B1_MAX_RESIDUAL_ABS_TOL = 1e-10
const _GRIDAP_B1_MAX_RESIDUAL_REL_TOL = 1e-10
const _GRIDAP_B1_MAX_BOUNDARY_ABS_TOL = 1e-10
const _GRIDAP_B1_MAX_MANUFACTURED_NODE_ABS_TOL = 0.45
const _GRIDAP_FIELD_TOKEN = Ref{Nothing}(nothing)
const _GRIDAP_REPO_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const _GRIDAP_QUALIFICATION_ROOT = joinpath(_GRIDAP_REPO_ROOT, "tools", "qualification", "gridap")

const _GRIDAP_EXPECTED = (
    julia_version="1.10.5",
    platform="x86_64-w64-mingw32",
    uuid="56d4f2e9-7ea1-5844-9cf6-b9c51ca7ce8e",
    version="0.20.8",
    tree="95fd6ec47697c8f031398434a119abe747330715",
    project_sha256="223fb6c8ea33f03989ccb4d76ed80016a3bc2799bc4210490c4e43cc7affceb6",
    manifest_sha256="2e1d103396d3f3faa13687bd4a95fde287d1f94e8b0006046b65e1e29aa3765a",
    installed_project_sha256="3b18f85db162689bdb1ca13ef293d0863f3c8e4ee223aea00cd14f3c3396728b",
)

_gridap_file_hash(path) = bytes2hex(SHA.sha256(read(path)))
gridap_field_adapter_source_hash() = Digest256(_gridap_file_hash(@__FILE__))

function _gridap_dependency_identity(root::AbstractString=_GRIDAP_QUALIFICATION_ROOT;
        verify_active::Bool=true)
    project_path = normpath(joinpath(root, "Project.toml"))
    manifest_path = normpath(joinpath(root, "Manifest.toml"))
    isfile(project_path) && isfile(manifest_path) ||
        throw(ArgumentError("Gridap qualification lock is missing"))
    project_sha256 = _gridap_file_hash(project_path)
    manifest_sha256 = _gridap_file_hash(manifest_path)
    project_sha256 == _GRIDAP_EXPECTED.project_sha256 ||
        throw(ArgumentError("Gridap qualification Project byte hash mismatch"))
    manifest_sha256 == _GRIDAP_EXPECTED.manifest_sha256 ||
        throw(ArgumentError("Gridap qualification Manifest byte hash mismatch"))
    verify_active && normpath(Base.active_project()) != project_path &&
        throw(ArgumentError("Gridap adapter is outside the pinned qualification environment"))

    manifest = TOML.parsefile(manifest_path)
    haskey(manifest, "deps") && haskey(manifest["deps"], "Gridap") ||
        throw(ArgumentError("Gridap is absent from the qualification manifest"))
    entries = manifest["deps"]["Gridap"]
    entry = entries isa AbstractVector ? only(entries) : entries
    get(entry, "uuid", "") == _GRIDAP_EXPECTED.uuid ||
        throw(ArgumentError("Gridap manifest UUID mismatch"))
    get(entry, "version", "") == _GRIDAP_EXPECTED.version ||
        throw(ArgumentError("Gridap manifest version mismatch"))
    get(entry, "git-tree-sha1", "") == _GRIDAP_EXPECTED.tree ||
        throw(ArgumentError("Gridap manifest source tree mismatch"))

    string(VERSION) == _GRIDAP_EXPECTED.julia_version ||
        throw(ArgumentError("Gridap Julia version mismatch"))
    string(Sys.MACHINE) == _GRIDAP_EXPECTED.platform ||
        throw(ArgumentError("Gridap platform mismatch"))
    string(Base.PkgId(Gridap).uuid) == _GRIDAP_EXPECTED.uuid ||
        throw(ArgumentError("loaded Gridap UUID mismatch"))
    string(Base.pkgversion(Gridap)) == _GRIDAP_EXPECTED.version ||
        throw(ArgumentError("loaded Gridap version mismatch"))
    installed_root = dirname(dirname(pathof(Gridap)))
    installed_project_sha256 = _gridap_file_hash(joinpath(installed_root, "Project.toml"))
    installed_project_sha256 == _GRIDAP_EXPECTED.installed_project_sha256 ||
        throw(ArgumentError("loaded Gridap source identity mismatch"))

    body = (julia_version=string(VERSION), platform=string(Sys.MACHINE),
        gridap_uuid=string(Base.PkgId(Gridap).uuid),
        gridap_version=string(Base.pkgversion(Gridap)),
        gridap_tree=get(entry, "git-tree-sha1", ""),
        project_sha256=Digest256(project_sha256),
        manifest_sha256=Digest256(manifest_sha256),
        installed_project_sha256=Digest256(installed_project_sha256))
    merge(body, (dependency_hash=canonical_hash(body),))
end

function _gridap_dependency_integrity(identity)
    fields = (:julia_version, :platform, :gridap_uuid, :gridap_version,
        :gridap_tree, :project_sha256, :manifest_sha256,
        :installed_project_sha256, :dependency_hash)
    all(hasproperty(identity, field) for field in fields) || return false
    body = (julia_version=identity.julia_version, platform=identity.platform,
        gridap_uuid=identity.gridap_uuid, gridap_version=identity.gridap_version,
        gridap_tree=identity.gridap_tree, project_sha256=identity.project_sha256,
        manifest_sha256=identity.manifest_sha256,
        installed_project_sha256=identity.installed_project_sha256)
    canonical_hash(body) == identity.dependency_hash
end

struct GridapFieldProtocolV4
    cell_family::Symbol
    fe_family::Symbol
    conformity::Symbol
    boundary::Symbol
    quadrature_degree::Int
    solver::Symbol
    input_field_representation::Symbol
    residual_abs_tol::Float64
    residual_rel_tol::Float64
    boundary_abs_tol::Float64
    manufactured_node_abs_tol::Float64
    protocol_hash::Digest256
    function GridapFieldProtocolV4(token::typeof(_GRIDAP_FIELD_TOKEN), args...)
        token === _GRIDAP_FIELD_TOKEN || throw(ArgumentError("sealed Gridap field protocol"))
        new(args...)
    end
end

function _gridap_protocol_body(cell_family, fe_family, conformity, boundary,
        quadrature_degree, solver, input_field_representation, residual_abs_tol,
        residual_rel_tol, boundary_abs_tol, manufactured_node_abs_tol)
    (cell_family=cell_family, fe_family=fe_family, conformity=conformity,
        boundary=boundary, quadrature_degree=quadrature_degree, solver=solver,
        input_field_representation=input_field_representation,
        weak_form_revision=_GRIDAP_WEAK_FORM_REVISION,
        interpolation_revision=_GRIDAP_INTERPOLATION_REVISION,
        residual_abs_tol=residual_abs_tol, residual_rel_tol=residual_rel_tol,
        boundary_abs_tol=boundary_abs_tol,
        manufactured_node_abs_tol=manufactured_node_abs_tol)
end

function GridapFieldProtocolV4(; cell_family::Symbol=:cartesian_hexahedral,
        fe_family::Symbol=:lagrangian_q1, conformity::Symbol=:H1,
        boundary::Symbol=:dirichlet_strong, quadrature_degree::Integer=8,
        solver::Symbol=:gridap_sparse_lu,
        input_field_representation::Symbol=:tensor_product_trilinear_from_g2_nodes,
        residual_abs_tol::Real=_GRIDAP_B1_MAX_RESIDUAL_ABS_TOL,
        residual_rel_tol::Real=_GRIDAP_B1_MAX_RESIDUAL_REL_TOL,
        boundary_abs_tol::Real=_GRIDAP_B1_MAX_BOUNDARY_ABS_TOL,
        manufactured_node_abs_tol::Real=_GRIDAP_B1_MAX_MANUFACTURED_NODE_ABS_TOL)
    cell_family === :cartesian_hexahedral || throw(ArgumentError("unsupported Gridap cell family"))
    fe_family === :lagrangian_q1 || throw(ArgumentError("unsupported Gridap FE family"))
    conformity === :H1 || throw(ArgumentError("unsupported Gridap conformity"))
    boundary === :dirichlet_strong || throw(ArgumentError("unsupported Gridap boundary rule"))
    quadrature_degree == 8 || throw(ArgumentError("Gridap B1 requires quadrature degree 8"))
    solver === :gridap_sparse_lu || throw(ArgumentError("unsupported Gridap solver"))
    input_field_representation === :tensor_product_trilinear_from_g2_nodes ||
        throw(ArgumentError("unsupported Gridap input interpolation"))
    tolerances = Float64.((residual_abs_tol, residual_rel_tol,
        boundary_abs_tol, manufactured_node_abs_tol))
    all(isfinite, tolerances) &&
        0 < tolerances[1] <= _GRIDAP_B1_MAX_RESIDUAL_ABS_TOL &&
        0 <= tolerances[2] <= _GRIDAP_B1_MAX_RESIDUAL_REL_TOL &&
        0 < tolerances[3] <= _GRIDAP_B1_MAX_BOUNDARY_ABS_TOL &&
        0 < tolerances[4] <= _GRIDAP_B1_MAX_MANUFACTURED_NODE_ABS_TOL ||
        throw(ArgumentError("invalid Gridap protocol tolerances"))
    body = _gridap_protocol_body(cell_family, fe_family, conformity, boundary,
        Int(quadrature_degree), solver, input_field_representation, tolerances...)
    GridapFieldProtocolV4(_GRIDAP_FIELD_TOKEN, cell_family, fe_family,
        conformity, boundary, Int(quadrature_degree), solver,
        input_field_representation, tolerances..., canonical_hash(body))
end

GridapFieldProtocolV4(args...) = throw(ArgumentError("Gridap field protocol is sealed"))
semantic_view(x::GridapFieldProtocolV4) = merge(_gridap_protocol_body(
    x.cell_family, x.fe_family, x.conformity, x.boundary, x.quadrature_degree,
    x.solver, x.input_field_representation, x.residual_abs_tol,
    x.residual_rel_tol, x.boundary_abs_tol, x.manufactured_node_abs_tol),
    (protocol_hash=x.protocol_hash,))
canonical_hash(x::GridapFieldProtocolV4) = x.protocol_hash

function _gridap_protocol_integrity(x::GridapFieldProtocolV4)
    canonical_hash(_gridap_protocol_body(x.cell_family, x.fe_family,
        x.conformity, x.boundary, x.quadrature_degree, x.solver,
        x.input_field_representation, x.residual_abs_tol, x.residual_rel_tol,
        x.boundary_abs_tol, x.manufactured_node_abs_tol)) == x.protocol_hash
end

struct GridapFieldResidualPlanV4
    native_plan::FieldResidualPipelinePlanV4
    protocol::GridapFieldProtocolV4
    dependency_identity::NamedTuple
    native_plan_hash::Digest256
    candidate_hash::Digest256
    prefix_hash::Digest256
    registry_hash::Digest256
    mission_hash::Digest256
    scenario_hash::Digest256
    constraint_edge_hash::Digest256
    form_hash::Digest256
    geometry_hash::Digest256
    grid_hash::Digest256
    u_plan_hash::Digest256
    f_plan_hash::Digest256
    u_result_hash::Digest256
    f_result_hash::Digest256
    u_evidence_id::Digest256
    f_evidence_id::Digest256
    source_content_hash::Digest256
    boundary_content_hash::Digest256
    adapter_code_hash::Digest256
    status::Symbol
    unresolved_gaps::Tuple
    plan_hash::Digest256
    function GridapFieldResidualPlanV4(token::typeof(_GRIDAP_FIELD_TOKEN), args...)
        token === _GRIDAP_FIELD_TOKEN || throw(ArgumentError("sealed Gridap field plan"))
        new(args...)
    end
end
GridapFieldResidualPlanV4(args...) = throw(ArgumentError("Gridap field plan is sealed"))

function _gridap_plan_body(native_plan_hash, candidate_hash, prefix_hash,
        registry_hash, mission_hash, scenario_hash, constraint_edge_hash,
        form_hash, geometry_hash, grid_hash, u_plan_hash, f_plan_hash,
        u_result_hash, f_result_hash, u_evidence_id, f_evidence_id,
        source_content_hash, boundary_content_hash, protocol_hash,
        dependency_hash, adapter_code_hash, status, unresolved_gaps)
    (schema=_GRIDAP_FIELD_SCHEMA, revision=_GRIDAP_FIELD_REVISION,
        replay_revision=_GRIDAP_REPLAY_REVISION,
        native_plan_hash=native_plan_hash, candidate_hash=candidate_hash,
        prefix_hash=prefix_hash, registry_hash=registry_hash,
        mission_hash=mission_hash, scenario_hash=scenario_hash,
        constraint_edge_hash=constraint_edge_hash, form_hash=form_hash,
        geometry_hash=geometry_hash, grid_hash=grid_hash,
        u_plan_hash=u_plan_hash, f_plan_hash=f_plan_hash,
        u_result_hash=u_result_hash, f_result_hash=f_result_hash,
        u_evidence_id=u_evidence_id, f_evidence_id=f_evidence_id,
        source_content_hash=source_content_hash,
        boundary_content_hash=boundary_content_hash,
        protocol_hash=protocol_hash, dependency_hash=dependency_hash,
        adapter_code_hash=adapter_code_hash, status=status,
        unresolved_gaps=unresolved_gaps)
end

semantic_view(x::GridapFieldResidualPlanV4) = merge(_gridap_plan_body(
    x.native_plan_hash, x.candidate_hash, x.prefix_hash, x.registry_hash,
    x.mission_hash, x.scenario_hash, x.constraint_edge_hash, x.form_hash,
    x.geometry_hash, x.grid_hash, x.u_plan_hash, x.f_plan_hash,
    x.u_result_hash, x.f_result_hash, x.u_evidence_id, x.f_evidence_id,
    x.source_content_hash, x.boundary_content_hash, x.protocol.protocol_hash,
    x.dependency_identity.dependency_hash, x.adapter_code_hash, x.status,
    x.unresolved_gaps), (plan_hash=x.plan_hash,))
canonical_hash(x::GridapFieldResidualPlanV4) = x.plan_hash

struct GridapFieldResidualCompilationV4
    plan::GridapFieldResidualPlanV4
    source::FieldResidualPayloadV4
    boundary::FieldResidualPayloadV4
    compilation_hash::Digest256
    function GridapFieldResidualCompilationV4(token::typeof(_GRIDAP_FIELD_TOKEN), args...)
        token === _GRIDAP_FIELD_TOKEN || throw(ArgumentError("sealed Gridap field compilation"))
        new(args...)
    end
end
GridapFieldResidualCompilationV4(args...) = throw(ArgumentError("Gridap field compilation is sealed"))
semantic_view(x::GridapFieldResidualCompilationV4) = (plan_hash=x.plan.plan_hash,
    source_content_hash=x.source.content_hash,
    boundary_content_hash=x.boundary.content_hash,
    compilation_hash=x.compilation_hash)
canonical_hash(x::GridapFieldResidualCompilationV4) = x.compilation_hash

function _gridap_payload_integrity(payload::FieldResidualPayloadV4)
    canonical_hash((state_ref=payload.state_ref, coordinates=payload.coordinates,
        values=payload.values, physical_type=payload.physical_type)) == payload.content_hash
end

function _gridap_plan_integrity(plan::GridapFieldResidualPlanV4)
    plan.status === :ready && isempty(plan.unresolved_gaps) &&
        _gridap_protocol_integrity(plan.protocol) &&
        _gridap_dependency_integrity(plan.dependency_identity) &&
        canonical_hash(plan.native_plan) == plan.native_plan_hash &&
        plan.native_plan_hash == plan.native_plan.plan_hash &&
        plan.candidate_hash == plan.native_plan.candidate_hash &&
        plan.prefix_hash == plan.native_plan.prefix_hash &&
        plan.registry_hash == plan.native_plan.registry_hash &&
        plan.mission_hash == plan.native_plan.mission.mission_hash &&
        plan.scenario_hash == plan.native_plan.mission.scenario_hash &&
        plan.constraint_edge_hash == plan.native_plan.mission.constraint_edge_hash &&
        plan.form_hash == plan.native_plan.form.form_hash &&
        plan.geometry_hash == plan.native_plan.geometry.geometry_hash &&
        plan.grid_hash == plan.native_plan.grid.grid_hash &&
        plan.u_plan_hash == plan.native_plan.u_plan_hash &&
        plan.f_plan_hash == plan.native_plan.f_plan_hash &&
        plan.u_result_hash == plan.native_plan.u_result_hash &&
        plan.f_result_hash == plan.native_plan.f_result_hash &&
        plan.u_evidence_id == plan.native_plan.u_evidence_id &&
        plan.f_evidence_id == plan.native_plan.f_evidence_id &&
        plan.source_content_hash == plan.native_plan.source_content_hash &&
        plan.boundary_content_hash == plan.native_plan.boundary_content_hash &&
        canonical_hash(_gridap_plan_body(plan.native_plan_hash,
            plan.candidate_hash, plan.prefix_hash, plan.registry_hash,
            plan.mission_hash, plan.scenario_hash, plan.constraint_edge_hash,
            plan.form_hash, plan.geometry_hash, plan.grid_hash,
            plan.u_plan_hash, plan.f_plan_hash, plan.u_result_hash,
            plan.f_result_hash, plan.u_evidence_id, plan.f_evidence_id,
            plan.source_content_hash, plan.boundary_content_hash,
            plan.protocol.protocol_hash, plan.dependency_identity.dependency_hash,
            plan.adapter_code_hash, plan.status, plan.unresolved_gaps)) == plan.plan_hash
end

function _gridap_compilation_integrity(compilation::GridapFieldResidualCompilationV4)
    _gridap_plan_integrity(compilation.plan) &&
        _gridap_payload_integrity(compilation.source) &&
        _gridap_payload_integrity(compilation.boundary) &&
        compilation.source.content_hash == compilation.plan.source_content_hash &&
        compilation.boundary.content_hash == compilation.plan.boundary_content_hash &&
        compilation.source.coordinates == compilation.boundary.coordinates &&
        canonical_hash((plan_hash=compilation.plan.plan_hash,
            source_content_hash=compilation.source.content_hash,
            boundary_content_hash=compilation.boundary.content_hash)) ==
                compilation.compilation_hash
end

function compile_gridap_field_residual_plan(candidate::CandidateStatePackageV4,
        compiled::CompiledCandidatePrefixV4,
        genome_registry::GenomeContractRegistryV4,
        operator_registry::OperatorRegistryV1, u_report::FieldEvaluationReportV4,
        f_report::FieldEvaluationReportV4; scenario, grid::FieldGridSpecV4,
        constraint_edge_hash::Digest256, unknown_state_ref::StateGeneRefV1,
        source_state_ref::StateGeneRefV1, residual_state_ref::StateGeneRefV1,
        affine_factors, affine_offsets,
        native_protocol::StructuredGridProtocolV4=StructuredGridProtocolV4(),
        protocol::GridapFieldProtocolV4=GridapFieldProtocolV4())
    dependency = _gridap_dependency_identity()
    _gridap_protocol_integrity(protocol) || throw(ArgumentError("Gridap protocol integrity mismatch"))
    native_plan = compile_field_residual_plan(candidate, compiled,
        genome_registry, operator_registry, u_report, f_report;
        scenario=scenario, grid=grid, constraint_edge_hash=constraint_edge_hash,
        unknown_state_ref=unknown_state_ref, source_state_ref=source_state_ref,
        residual_state_ref=residual_state_ref, affine_factors=affine_factors,
        affine_offsets=affine_offsets, protocol=native_protocol)
    source = FieldResidualPayloadV4(source_state_ref, grid,
        f_report.result.values, native_plan.form.source_types[1])
    boundary = FieldResidualPayloadV4(unknown_state_ref, grid,
        u_report.result.values, native_plan.form.unknown_type)
    source.content_hash == native_plan.source_content_hash ||
        throw(ArgumentError("Gridap source payload/native plan mismatch"))
    boundary.content_hash == native_plan.boundary_content_hash ||
        throw(ArgumentError("Gridap boundary payload/native plan mismatch"))
    adapter_code_hash = gridap_field_adapter_source_hash()
    body = _gridap_plan_body(native_plan.plan_hash, native_plan.candidate_hash,
        native_plan.prefix_hash, native_plan.registry_hash,
        native_plan.mission.mission_hash, native_plan.mission.scenario_hash,
        native_plan.mission.constraint_edge_hash, native_plan.form.form_hash,
        native_plan.geometry.geometry_hash, native_plan.grid.grid_hash,
        native_plan.u_plan_hash, native_plan.f_plan_hash,
        native_plan.u_result_hash, native_plan.f_result_hash,
        native_plan.u_evidence_id, native_plan.f_evidence_id,
        native_plan.source_content_hash, native_plan.boundary_content_hash,
        protocol.protocol_hash, dependency.dependency_hash, adapter_code_hash,
        :ready, ())
    plan = GridapFieldResidualPlanV4(_GRIDAP_FIELD_TOKEN, native_plan,
        protocol, dependency, native_plan.plan_hash, native_plan.candidate_hash,
        native_plan.prefix_hash, native_plan.registry_hash,
        native_plan.mission.mission_hash, native_plan.mission.scenario_hash,
        native_plan.mission.constraint_edge_hash, native_plan.form.form_hash,
        native_plan.geometry.geometry_hash, native_plan.grid.grid_hash,
        native_plan.u_plan_hash, native_plan.f_plan_hash,
        native_plan.u_result_hash, native_plan.f_result_hash,
        native_plan.u_evidence_id, native_plan.f_evidence_id,
        native_plan.source_content_hash, native_plan.boundary_content_hash,
        adapter_code_hash, :ready, (), canonical_hash(body))
    _gridap_plan_integrity(plan) || throw(ArgumentError("Gridap plan integrity mismatch"))
    compilation_hash = canonical_hash((plan_hash=plan.plan_hash,
        source_content_hash=source.content_hash,
        boundary_content_hash=boundary.content_hash))
    compilation = GridapFieldResidualCompilationV4(_GRIDAP_FIELD_TOKEN,
        plan, source, boundary, compilation_hash)
    _gridap_compilation_integrity(compilation) ||
        throw(ArgumentError("Gridap compilation integrity mismatch"))
    compilation
end

struct GridapAssemblyReceiptV4
    plan_hash::Digest256
    physical_domain::NTuple{6,Float64}
    cell_counts::NTuple{3,Int}
    cells::Int
    free_dofs::Int
    dirichlet_dofs::Int
    matrix_shape::NTuple{2,Int}
    matrix_nnz::Int
    matrix_hash::Digest256
    rhs_hash::Digest256
    rhs_norm_inf::Float64
    form_hash::Digest256
    geometry_hash::Digest256
    grid_hash::Digest256
    source_content_hash::Digest256
    boundary_content_hash::Digest256
    protocol_hash::Digest256
    dependency_hash::Digest256
    adapter_code_hash::Digest256
    weak_form_revision::String
    interpolation_revision::String
    assembly_hash::Digest256
    function GridapAssemblyReceiptV4(token::typeof(_GRIDAP_FIELD_TOKEN), args...)
        token === _GRIDAP_FIELD_TOKEN || throw(ArgumentError("sealed Gridap assembly receipt"))
        new(args...)
    end
end
GridapAssemblyReceiptV4(args...) = throw(ArgumentError("Gridap assembly receipt is sealed"))

function _gridap_receipt_body(plan_hash, physical_domain, cell_counts, cells,
        free_dofs, dirichlet_dofs, matrix_shape, matrix_nnz, matrix_hash,
        rhs_hash, rhs_norm_inf, form_hash, geometry_hash, grid_hash,
        source_content_hash, boundary_content_hash, protocol_hash,
        dependency_hash, adapter_code_hash, weak_form_revision,
        interpolation_revision)
    (plan_hash=plan_hash, physical_domain=physical_domain,
        cell_counts=cell_counts, cells=cells, free_dofs=free_dofs,
        dirichlet_dofs=dirichlet_dofs, matrix_shape=matrix_shape,
        matrix_nnz=matrix_nnz, matrix_hash=matrix_hash, rhs_hash=rhs_hash,
        rhs_norm_inf=rhs_norm_inf, form_hash=form_hash,
        geometry_hash=geometry_hash, grid_hash=grid_hash,
        source_content_hash=source_content_hash,
        boundary_content_hash=boundary_content_hash,
        protocol_hash=protocol_hash, dependency_hash=dependency_hash,
        adapter_code_hash=adapter_code_hash,
        weak_form_revision=weak_form_revision,
        interpolation_revision=interpolation_revision)
end

semantic_view(x::GridapAssemblyReceiptV4) = merge(_gridap_receipt_body(
    x.plan_hash, x.physical_domain, x.cell_counts, x.cells, x.free_dofs,
    x.dirichlet_dofs, x.matrix_shape, x.matrix_nnz, x.matrix_hash,
    x.rhs_hash, x.rhs_norm_inf, x.form_hash, x.geometry_hash, x.grid_hash,
    x.source_content_hash, x.boundary_content_hash, x.protocol_hash,
    x.dependency_hash, x.adapter_code_hash, x.weak_form_revision,
    x.interpolation_revision), (assembly_hash=x.assembly_hash,))
canonical_hash(x::GridapAssemblyReceiptV4) = x.assembly_hash

function _gridap_receipt_integrity(x::GridapAssemblyReceiptV4)
    canonical_hash(_gridap_receipt_body(x.plan_hash, x.physical_domain,
        x.cell_counts, x.cells, x.free_dofs, x.dirichlet_dofs,
        x.matrix_shape, x.matrix_nnz, x.matrix_hash, x.rhs_hash,
        x.rhs_norm_inf, x.form_hash, x.geometry_hash, x.grid_hash,
        x.source_content_hash, x.boundary_content_hash, x.protocol_hash,
        x.dependency_hash, x.adapter_code_hash, x.weak_form_revision,
        x.interpolation_revision)) == x.assembly_hash
end

struct GridapFieldSolveResultV4
    status::Symbol
    factorization_status::Symbol
    weak_form_sign::Symbol
    free_dof_values::Tuple
    physical_samples::Tuple
    residual_abs::Float64
    residual_rel::Float64
    boundary_mismatch::Float64
    manufactured_node_linf_error::Float64
    finite_values::Bool
    receipt_hash::Digest256
    protocol_hash::Digest256
    result_hash::Digest256
    function GridapFieldSolveResultV4(token::typeof(_GRIDAP_FIELD_TOKEN), args...)
        token === _GRIDAP_FIELD_TOKEN || throw(ArgumentError("sealed Gridap solve result"))
        new(args...)
    end
end
GridapFieldSolveResultV4(args...) = throw(ArgumentError("Gridap solve result is sealed"))

function _gridap_result_body(status, factorization_status, weak_form_sign,
        free_dof_values, physical_samples, residual_abs, residual_rel,
        boundary_mismatch, manufactured_node_linf_error, finite_values,
        receipt_hash, protocol_hash)
    (status=status, factorization_status=factorization_status,
        weak_form_sign=weak_form_sign, free_dof_values=free_dof_values,
        physical_samples=physical_samples, residual_abs=residual_abs,
        residual_rel=residual_rel, boundary_mismatch=boundary_mismatch,
        manufactured_node_linf_error=manufactured_node_linf_error,
        finite_values=finite_values, receipt_hash=receipt_hash,
        protocol_hash=protocol_hash)
end

semantic_view(x::GridapFieldSolveResultV4) = merge(_gridap_result_body(
    x.status, x.factorization_status, x.weak_form_sign, x.free_dof_values,
    x.physical_samples, x.residual_abs, x.residual_rel,
    x.boundary_mismatch, x.manufactured_node_linf_error, x.finite_values,
    x.receipt_hash, x.protocol_hash), (result_hash=x.result_hash,))
canonical_hash(x::GridapFieldSolveResultV4) = x.result_hash

function _gridap_result_integrity(x::GridapFieldSolveResultV4)
    canonical_hash(_gridap_result_body(x.status, x.factorization_status,
        x.weak_form_sign, x.free_dof_values, x.physical_samples,
        x.residual_abs, x.residual_rel, x.boundary_mismatch,
        x.manufactured_node_linf_error, x.finite_values, x.receipt_hash,
        x.protocol_hash)) == x.result_hash
end

struct GridapFieldResidualReportV4
    status::Symbol
    plan_hash::Digest256
    receipt::GridapAssemblyReceiptV4
    result::GridapFieldSolveResultV4
    evidence_class::Symbol
    claim_ceiling::ClaimCeiling
    numerical_vvuq_status::Symbol
    credible_physical_candidate_count::Int
    p5_ready::Bool
    unsupported_emitted::Bool
    report_hash::Digest256
    function GridapFieldResidualReportV4(token::typeof(_GRIDAP_FIELD_TOKEN), args...)
        token === _GRIDAP_FIELD_TOKEN || throw(ArgumentError("sealed Gridap field report"))
        new(args...)
    end
end
GridapFieldResidualReportV4(args...) = throw(ArgumentError("Gridap field report is sealed"))

function _gridap_report_body(status, plan_hash, receipt_hash, result_hash,
        evidence_class, claim_ceiling, numerical_vvuq_status,
        credible_physical_candidate_count, p5_ready, unsupported_emitted)
    (status=status, plan_hash=plan_hash, receipt_hash=receipt_hash,
        result_hash=result_hash, evidence_class=evidence_class,
        claim_ceiling=claim_ceiling,
        numerical_vvuq_status=numerical_vvuq_status,
        credible_physical_candidate_count=credible_physical_candidate_count,
        p5_ready=p5_ready, unsupported_emitted=unsupported_emitted)
end

semantic_view(x::GridapFieldResidualReportV4) = merge(_gridap_report_body(
    x.status, x.plan_hash, x.receipt.assembly_hash, x.result.result_hash,
    x.evidence_class, x.claim_ceiling, x.numerical_vvuq_status,
    x.credible_physical_candidate_count, x.p5_ready,
    x.unsupported_emitted), (report_hash=x.report_hash,))
canonical_hash(x::GridapFieldResidualReportV4) = x.report_hash

function _gridap_chart_to_physical(geometry::DiagonalAffineChartGeometryV4, q)
    ntuple(i -> geometry.scale * (Float64(geometry.factors[i]) * Float64(q[i]) +
        Float64(geometry.offsets[i])), 3)
end

function _gridap_physical_to_chart(geometry::DiagonalAffineChartGeometryV4, x)
    ntuple(i -> (Float64(x[i]) / geometry.scale -
        Float64(geometry.offsets[i])) / Float64(geometry.factors[i]), 3)
end

function _gridap_trilinear(values, coordinates, q)
    indices = ntuple(3) do axis
        c = collect(coordinates[axis])
        z = Float64(q[axis])
        first(c) - 64eps(Float64) <= z <= last(c) + 64eps(Float64) ||
            throw(ArgumentError("physical point maps outside the G2 chart grid"))
        clamped = clamp(z, first(c), last(c))
        j = clamp(searchsortedlast(c, clamped), 1, length(c) - 1)
        (j, (clamped - c[j]) / (c[j + 1] - c[j]))
    end
    _, ny, nz = length.(coordinates)
    value = 0.0
    for dx in 0:1, dy in 0:1, dz in 0:1
        ix, iy, iz = indices[1][1] + dx, indices[2][1] + dy, indices[3][1] + dz
        k = (ix - 1) * ny * nz + (iy - 1) * nz + iz
        weight = (dx == 0 ? 1 - indices[1][2] : indices[1][2]) *
            (dy == 0 ? 1 - indices[2][2] : indices[2][2]) *
            (dz == 0 ? 1 - indices[3][2] : indices[3][2])
        value += weight * values[k]
    end
    value
end

function _gridap_payload_value(payload::FieldResidualPayloadV4,
        geometry::DiagonalAffineChartGeometryV4, x)
    _gridap_trilinear(payload.values, payload.coordinates,
        _gridap_physical_to_chart(geometry, x))
end

function _gridap_physical_domain(geometry::DiagonalAffineChartGeometryV4,
        coordinates)
    endpoints = ntuple(3) do i
        a = geometry.scale * (Float64(geometry.factors[i]) * first(coordinates[i]) +
            Float64(geometry.offsets[i]))
        b = geometry.scale * (Float64(geometry.factors[i]) * last(coordinates[i]) +
            Float64(geometry.offsets[i]))
        (min(a, b), max(a, b))
    end
    (endpoints[1][1], endpoints[1][2], endpoints[2][1], endpoints[2][2],
        endpoints[3][1], endpoints[3][2])
end

function _gridap_matrix_hash(A)
    canonical_hash((m=size(A, 1), n=size(A, 2), colptr=Tuple(A.colptr),
        rowval=Tuple(A.rowval), nzval=Tuple(Float64.(A.nzval))))
end

function _gridap_sample_solution(uh, compilation::GridapFieldResidualCompilationV4)
    coordinates = compilation.source.coordinates
    geometry = compilation.plan.native_plan.geometry
    samples = NamedTuple[]
    reference_errors = Float64[]
    boundary_errors = Float64[]
    nx, ny, nz = length.(coordinates)
    k = 0
    for ix in 1:nx, iy in 1:ny, iz in 1:nz
        k += 1
        q = (coordinates[1][ix], coordinates[2][iy], coordinates[3][iz])
        physical = _gridap_chart_to_physical(geometry, q)
        value = Float64(uh(Point(physical...)))
        reference = compilation.boundary.values[k]
        push!(samples, (coordinate=physical, value=value))
        error = abs(value - reference)
        push!(reference_errors, error)
        if ix in (1, nx) || iy in (1, ny) || iz in (1, nz)
            push!(boundary_errors, error)
        end
    end
    Tuple(samples), maximum(reference_errors), maximum(boundary_errors)
end

function run_gridap_field_residual(compilation::GridapFieldResidualCompilationV4;
        weak_form_sign::Symbol=:declared)
    weak_form_sign in (:declared, :reversed_test_control) ||
        throw(ArgumentError("unsupported Gridap weak-form sign selector"))
    _gridap_compilation_integrity(compilation) ||
        throw(ArgumentError("Gridap compilation integrity mismatch"))
    plan = compilation.plan
    _gridap_dependency_identity() == plan.dependency_identity ||
        throw(ArgumentError("Gridap dependency changed after compilation"))
    gridap_field_adapter_source_hash() == plan.adapter_code_hash ||
        throw(ArgumentError("Gridap adapter source changed after compilation"))
    native = plan.native_plan
    form = native.form
    form.alpha == 1.0 && form.beta == 0.0 &&
        length(form.source_coefficients) == 1 ||
        throw(ArgumentError("Gridap B1 form is outside the audited linear subset"))

    coordinates = compilation.source.coordinates
    cell_counts = ntuple(i -> length(coordinates[i]) - 1, 3)
    domain = _gridap_physical_domain(native.geometry, coordinates)
    model = CartesianDiscreteModel(domain, cell_counts)
    reffe = ReferenceFE(lagrangian, Float64, 1)
    V0 = TestFESpace(model, reffe; conformity=:H1,
        dirichlet_tags="boundary")
    Ug = TrialFESpace(V0, x -> _gridap_payload_value(compilation.boundary,
        native.geometry, x))
    Ω = Triangulation(model)
    dΩ = Measure(Ω, plan.protocol.quadrature_degree)
    multiplier = weak_form_sign === :declared ? 1.0 : -1.0
    source_term(x) = multiplier * (form.source_coefficients[1] *
        _gridap_payload_value(compilation.source, native.geometry, x) +
        form.constant)
    a(u, v) = ∫(form.alpha * (∇(v) ⋅ ∇(u)) - form.beta * v * u) * dΩ
    b(v) = ∫(v * source_term) * dΩ
    op = AffineFEOperator(a, b, Ug, V0)
    uh = solve(LinearFESolver(LUSolver()), op)
    A = get_matrix(op)
    rhs = Float64.(get_vector(op))
    free_values = Tuple(Float64.(get_free_values(uh)))
    residual_abs = norm(A * collect(free_values) - rhs, Inf)
    rhs_norm_inf = norm(rhs, Inf)
    residual_rel = residual_abs / max(rhs_norm_inf, eps(Float64))
    samples, node_error, boundary_mismatch =
        _gridap_sample_solution(uh, compilation)

    matrix_hash = _gridap_matrix_hash(A)
    rhs_hash = canonical_hash(Tuple(rhs))
    receipt_body = _gridap_receipt_body(plan.plan_hash, domain, cell_counts,
        num_cells(model), num_free_dofs(V0), num_dirichlet_dofs(V0),
        (size(A, 1), size(A, 2)), nnz(A), matrix_hash, rhs_hash,
        rhs_norm_inf, plan.form_hash, plan.geometry_hash, plan.grid_hash,
        plan.source_content_hash, plan.boundary_content_hash,
        plan.protocol.protocol_hash, plan.dependency_identity.dependency_hash,
        plan.adapter_code_hash, _GRIDAP_WEAK_FORM_REVISION,
        _GRIDAP_INTERPOLATION_REVISION)
    receipt = GridapAssemblyReceiptV4(_GRIDAP_FIELD_TOKEN, plan.plan_hash,
        domain, cell_counts, num_cells(model), num_free_dofs(V0),
        num_dirichlet_dofs(V0), (size(A, 1), size(A, 2)), nnz(A),
        matrix_hash, rhs_hash, rhs_norm_inf, plan.form_hash,
        plan.geometry_hash, plan.grid_hash, plan.source_content_hash,
        plan.boundary_content_hash, plan.protocol.protocol_hash,
        plan.dependency_identity.dependency_hash, plan.adapter_code_hash,
        _GRIDAP_WEAK_FORM_REVISION, _GRIDAP_INTERPOLATION_REVISION,
        canonical_hash(receipt_body))

    finite_values = all(isfinite, free_values) &&
        all(sample -> isfinite(sample.value), samples) &&
        all(isfinite, (residual_abs, residual_rel, boundary_mismatch, node_error))
    residual_ok = residual_abs <= plan.protocol.residual_abs_tol ||
        residual_rel <= plan.protocol.residual_rel_tol
    boundary_ok = boundary_mismatch <= plan.protocol.boundary_abs_tol
    control_ok = node_error <= plan.protocol.manufactured_node_abs_tol
    status = if !finite_values
        :unknown
    elseif weak_form_sign === :declared && residual_ok && boundary_ok && control_ok
        :pass
    else
        :numerical_fail
    end
    result_body = _gridap_result_body(status, :success, weak_form_sign,
        free_values, samples, residual_abs, residual_rel, boundary_mismatch,
        node_error, finite_values, receipt.assembly_hash,
        plan.protocol.protocol_hash)
    result = GridapFieldSolveResultV4(_GRIDAP_FIELD_TOKEN, status, :success,
        weak_form_sign, free_values, samples, residual_abs, residual_rel,
        boundary_mismatch, node_error, finite_values, receipt.assembly_hash,
        plan.protocol.protocol_hash, canonical_hash(result_body))
    report_body = _gridap_report_body(status, plan.plan_hash,
        receipt.assembly_hash, result.result_hash, :manufactured_control,
        screen_only, :terminal_deferred, 0, false, false)
    report = GridapFieldResidualReportV4(_GRIDAP_FIELD_TOKEN, status,
        plan.plan_hash, receipt, result, :manufactured_control, screen_only,
        :terminal_deferred, 0, false, false, canonical_hash(report_body))
    validate_gridap_field_residual_report(compilation, report) ||
        throw(ArgumentError("Gridap report integrity mismatch"))
    report
end

function validate_gridap_field_residual_report(
        compilation::GridapFieldResidualCompilationV4,
        report::GridapFieldResidualReportV4)
    _gridap_compilation_integrity(compilation) || return false
    plan = compilation.plan
    _gridap_receipt_integrity(report.receipt) || return false
    _gridap_result_integrity(report.result) || return false
    report.plan_hash == plan.plan_hash || return false
    report.receipt.plan_hash == plan.plan_hash || return false
    report.receipt.form_hash == plan.form_hash || return false
    report.receipt.geometry_hash == plan.geometry_hash || return false
    report.receipt.grid_hash == plan.grid_hash || return false
    report.receipt.source_content_hash == plan.source_content_hash || return false
    report.receipt.boundary_content_hash == plan.boundary_content_hash || return false
    report.receipt.protocol_hash == plan.protocol.protocol_hash || return false
    report.receipt.dependency_hash == plan.dependency_identity.dependency_hash || return false
    report.receipt.adapter_code_hash == plan.adapter_code_hash || return false
    report.result.receipt_hash == report.receipt.assembly_hash || return false
    report.result.protocol_hash == plan.protocol.protocol_hash || return false
    report.status == report.result.status || return false
    report.evidence_class === :manufactured_control || return false
    report.claim_ceiling === screen_only || return false
    report.numerical_vvuq_status === :terminal_deferred || return false
    report.credible_physical_candidate_count == 0 || return false
    !report.p5_ready && !report.unsupported_emitted || return false
    report.result.factorization_status === :success || return false
    report.result.weak_form_sign in (:declared, :reversed_test_control) || return false
    expected_status = if !report.result.finite_values
        :unknown
    elseif report.result.weak_form_sign === :declared &&
            (report.result.residual_abs <= plan.protocol.residual_abs_tol ||
             report.result.residual_rel <= plan.protocol.residual_rel_tol) &&
            report.result.boundary_mismatch <= plan.protocol.boundary_abs_tol &&
            report.result.manufactured_node_linf_error <=
                plan.protocol.manufactured_node_abs_tol
        :pass
    else
        :numerical_fail
    end
    report.status === expected_status || return false
    canonical_hash(_gridap_report_body(report.status, report.plan_hash,
        report.receipt.assembly_hash, report.result.result_hash,
        report.evidence_class, report.claim_ceiling,
        report.numerical_vvuq_status,
        report.credible_physical_candidate_count, report.p5_ready,
        report.unsupported_emitted)) == report.report_hash
end

function replay_gridap_field_residual(
        compilation::GridapFieldResidualCompilationV4,
        report::GridapFieldResidualReportV4)
    validate_gridap_field_residual_report(compilation, report) || return false
    replay = run_gridap_field_residual(compilation;
        weak_form_sign=report.result.weak_form_sign)
    replay.report_hash == report.report_hash &&
        replay.receipt.assembly_hash == report.receipt.assembly_hash &&
        replay.result.result_hash == report.result.result_hash
end

run_gridap_b1(compilation::GridapFieldResidualCompilationV4; wrong_sign::Bool=false) =
    run_gridap_field_residual(compilation;
        weak_form_sign=wrong_sign ? :reversed_test_control : :declared)
