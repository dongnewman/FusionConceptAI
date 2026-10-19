"""Candidate-bound in-house tensor-Q1 sparse solver for the native G1/G2 MMS.

This source owns a distinct numerical protocol and provider identity.  It does
not import Gridap and never claims to be the `:gridap_sparse_lu` adapter.  The
bounded v1 topology is one positive diagonal affine physical chart, Q1 on a
single rectangular region, and zero Dirichlet data on all six faces.
"""

using LinearAlgebra
using SparseArrays
using SHA

const NATIVE_G1G2_INHOUSE_Q1_BACKEND_V1 =
    "Native-inhouse-Q1-Jacobi-PCG"

native_g1g2_inhouse_q1_source_hash_v1() =
    Digest256(bytes2hex(SHA.sha256(read(@__FILE__))))

struct NativeG1G2InHouseQ1ErrorV1 <: Exception
    code::Symbol
    details::Tuple{Vararg{Symbol}}
end

Base.showerror(io::IO, error::NativeG1G2InHouseQ1ErrorV1) =
    print(io, "in-house G1/G2 Q1 solver error ", error.code,
        isempty(error.details) ? "" : ": " * join(string.(error.details), ", "))

"""Predeclared Q1 interpolation and coercivity budget from Gridap V1.

The in-house protocol carries the exact same frozen geometry, coefficient,
orders, and upward-rounded error bounds.  These values are not estimated from
the solver output.
"""
native_g1g2_inhouse_q1_error_budget_basis_v1() =
    (schema="native-g1g2-pre-run-q1-error-budget-v1",
        derivation=:tensor_q1_fraction_integration_cea_poincare,
        value_representation=
            :rounded_decimal_approximations_of_fraction_integral_square_roots,
        physical_lower_metres=(1 // 2, 1 // 3, 1 // 4),
        physical_upper_metres=(5 // 2, 10 // 3, 17 // 4),
        physical_lengths_metres=(2 // 1, 3 // 1, 4 // 1),
        k_base=(2 // 1, 3 // 1, 4 // 1),
        k_slope=(1 // 10, 1 // 20, 1 // 30),
        ellipticity_bounds=(41 // 20, 497 // 120),
        q1_interpolation_l2_m32=(0.01042000975, 0.002805701325,
            0.000714216274),
        q1_interpolation_h1_m12=(0.02939176804, 0.01368454119,
            0.006674632049),
        cea_finest_h1_bound_m12=0.009487198126,
        poincare_finest_l2_bound_m32=0.004639855187,
        expected_l2_order=2 // 1, expected_h1_order=1 // 1,
        preasymptotic_order_half_width=3 // 5,
        polynomial_degree_bounds=(stiffness=2, rhs=3, squared_errors=4),
        gridap_quadrature_degree=8,
        declared_g2_quadrature_role=
            :identity_bound_geometry_metadata_not_execution_rule)

struct NativeG1G2InHouseQ1ProtocolV1
    cell_counts::NTuple{3,NTuple{3,Int}}
    quadrature_degree::Int
    quadrature_rule::Symbol
    solver::Symbol
    pcg_max_iterations_per_free_dof::Int
    residual_abs_tol::Float64
    residual_rel_tol::Float64
    boundary_abs_tol::Float64
    source_integral_abs_tol::Float64
    analytic_identity_abs_tol::Float64
    reaction_balance_abs_tol::Float64
    l2_order_interval::NTuple{2,Float64}
    h1_order_interval::NTuple{2,Float64}
    finest_l2_max::Float64
    finest_h1_seminorm_max::Float64
    budget_basis::NamedTuple
    protocol_hash::Digest256
end

function _ng12ihq1_protocol_body(cell_counts, quadrature_degree,
        quadrature_rule, solver, pcg_max_iterations_per_free_dof,
        residual_abs_tol, residual_rel_tol, boundary_abs_tol,
        source_integral_abs_tol, analytic_identity_abs_tol,
        reaction_balance_abs_tol, l2_order_interval, h1_order_interval,
        finest_l2_max, finest_h1_seminorm_max, budget_basis)
    (domain="native-g1g2-inhouse-q1-jacobi-pcg-protocol-v1",
        cell_counts=cell_counts, quadrature_degree=quadrature_degree,
        quadrature_rule=quadrature_rule, solver=solver,
        pcg_max_iterations_per_free_dof=pcg_max_iterations_per_free_dof,
        residual_abs_tol=residual_abs_tol,
        residual_rel_tol=residual_rel_tol,
        boundary_abs_tol=boundary_abs_tol,
        source_integral_abs_tol=source_integral_abs_tol,
        analytic_identity_abs_tol=analytic_identity_abs_tol,
        reaction_balance_abs_tol=reaction_balance_abs_tol,
        l2_order_interval=l2_order_interval,
        h1_order_interval=h1_order_interval,
        finest_l2_max=finest_l2_max,
        finest_h1_seminorm_max=finest_h1_seminorm_max,
        budget_basis=budget_basis)
end

function native_g1g2_inhouse_q1_protocol_v1()
    cells = ((2, 3, 4), (4, 6, 8), (8, 12, 16))
    degree = 8
    rule = :tensor_gauss_legendre_5_point_exact_degree_9
    solver = :inhouse_q1_jacobi_pcg
    maxiter_per_dof = 20
    residual_abs = 1.0e-9
    residual_rel = 1.0e-11
    boundary_abs = 1.0e-10
    source_abs = 1.0e-10
    identity_abs = 1.0e-12
    reaction_abs = 1.0e-9
    l2_interval = (1.4, 2.6)
    h1_interval = (0.6, 1.4)
    l2_max = 5.0e-3
    h1_max = 1.0e-2
    budget = native_g1g2_inhouse_q1_error_budget_basis_v1()
    body = _ng12ihq1_protocol_body(cells, degree, rule, solver,
        maxiter_per_dof, residual_abs, residual_rel, boundary_abs,
        source_abs, identity_abs, reaction_abs, l2_interval, h1_interval,
        l2_max, h1_max, budget)
    NativeG1G2InHouseQ1ProtocolV1(cells, degree, rule, solver,
        maxiter_per_dof, residual_abs, residual_rel, boundary_abs,
        source_abs, identity_abs, reaction_abs, l2_interval, h1_interval,
        l2_max, h1_max, budget, canonical_hash(body))
end

function _ng12ihq1_protocol_integrity(protocol::NativeG1G2InHouseQ1ProtocolV1)
    expected = native_g1g2_inhouse_q1_protocol_v1()
    canonical_json(_ng12ihq1_protocol_body(
        protocol.cell_counts, protocol.quadrature_degree,
        protocol.quadrature_rule, protocol.solver,
        protocol.pcg_max_iterations_per_free_dof,
        protocol.residual_abs_tol, protocol.residual_rel_tol,
        protocol.boundary_abs_tol, protocol.source_integral_abs_tol,
        protocol.analytic_identity_abs_tol,
        protocol.reaction_balance_abs_tol, protocol.l2_order_interval,
        protocol.h1_order_interval, protocol.finest_l2_max,
        protocol.finest_h1_seminorm_max, protocol.budget_basis)) ==
    canonical_json(_ng12ihq1_protocol_body(expected.cell_counts,
        expected.quadrature_degree, expected.quadrature_rule,
        expected.solver, expected.pcg_max_iterations_per_free_dof,
        expected.residual_abs_tol, expected.residual_rel_tol,
        expected.boundary_abs_tol, expected.source_integral_abs_tol,
        expected.analytic_identity_abs_tol,
        expected.reaction_balance_abs_tol, expected.l2_order_interval,
        expected.h1_order_interval, expected.finest_l2_max,
        expected.finest_h1_seminorm_max, expected.budget_basis)) &&
    canonical_hash(_ng12ihq1_protocol_body(
        protocol.cell_counts, protocol.quadrature_degree,
        protocol.quadrature_rule, protocol.solver,
        protocol.pcg_max_iterations_per_free_dof,
        protocol.residual_abs_tol, protocol.residual_rel_tol,
        protocol.boundary_abs_tol, protocol.source_integral_abs_tol,
        protocol.analytic_identity_abs_tol,
        protocol.reaction_balance_abs_tol, protocol.l2_order_interval,
        protocol.h1_order_interval, protocol.finest_l2_max,
        protocol.finest_h1_seminorm_max, protocol.budget_basis)) ==
        protocol.protocol_hash
end

semantic_view(protocol::NativeG1G2InHouseQ1ProtocolV1) = merge(
    _ng12ihq1_protocol_body(protocol.cell_counts,
        protocol.quadrature_degree, protocol.quadrature_rule,
        protocol.solver, protocol.pcg_max_iterations_per_free_dof,
        protocol.residual_abs_tol, protocol.residual_rel_tol,
        protocol.boundary_abs_tol, protocol.source_integral_abs_tol,
        protocol.analytic_identity_abs_tol,
        protocol.reaction_balance_abs_tol, protocol.l2_order_interval,
        protocol.h1_order_interval, protocol.finest_l2_max,
        protocol.finest_h1_seminorm_max, protocol.budget_basis),
    (protocol_hash=protocol.protocol_hash,))
canonical_hash(protocol::NativeG1G2InHouseQ1ProtocolV1) =
    protocol.protocol_hash

function _ng12ihq1_error_budget_applies(form,
        protocol::NativeG1G2InHouseQ1ProtocolV1)
    p = form.programs.parameters
    budget = protocol.budget_basis
    bounds = g2mb_chart_image_bounds(form.g2_declaration.source.chart_map)
    lower = ntuple(i -> bounds[i][1], 3)
    upper = ntuple(i -> bounds[i][2], 3)
    endpoint_values = Tuple(p.k_base[i] + p.k_slope[i] * x
        for i in 1:3 for x in (lower[i], upper[i]))
    p.physical_lower == budget.physical_lower_metres &&
    p.physical_upper == budget.physical_upper_metres &&
    p.physical_lengths == budget.physical_lengths_metres &&
    p.k_base == budget.k_base && p.k_slope == budget.k_slope &&
    lower == budget.physical_lower_metres &&
    upper == budget.physical_upper_metres &&
    (minimum(endpoint_values), maximum(endpoint_values)) ==
        budget.ellipticity_bounds &&
    protocol.cell_counts[1] == form.g2_declaration.source.mesh.cells
end

function _ng12ihq1_source_binding(form::NativeG1G2VariableDiffusionFormV1)
    (candidate_ref=form.candidate_ref,
        t1_package_hash=form.t1_package_hash,
        t1_semantic_identity=form.t1_semantic_identity,
        t0_bundle_hash=form.t0_bundle_hash,
        g1_declaration_hash=form.g1_declaration.declaration_hash,
        g2_declaration_hash=form.g2_declaration.declaration_hash,
        program_bundle_hash=form.programs.bundle_hash,
        form_hash=form.form_hash)
end

function _ng12ihq1_supported_form_errors(
        form::NativeG1G2VariableDiffusionFormV1)
    errors = Symbol[]
    append!(errors, native_g1g2_physics_errors_v1(form.g1_declaration,
        form.g2_declaration, form.programs, form.unit_profile))
    chart = form.g2_declaration.source.chart_map
    all(chart.jacobian_rows[i][j] == 0 for i in 1:3 for j in 1:3
        if i != j) && all(chart.jacobian_rows[i][i] > 0 for i in 1:3) ||
        push!(errors, :unsupported_chart)
    form.g2_declaration.source.mesh.basis === :Q1 ||
        push!(errors, :unsupported_basis)
    faces = form.g2_declaration.source.faces
    names = (:x_min, :x_max, :y_min, :y_max, :z_min, :z_max)
    length(faces) == 6 && Set(face.face for face in faces) == Set(names) ||
        push!(errors, :unsupported_boundary_face_set)
    if length(faces) == 6 && Set(face.face for face in faces) == Set(names)
        all(face.value.kind === :dirichlet && face.value.value == 0
            for face in faces) || push!(errors, :unsupported_boundary_data)
    end
    Tuple(unique(errors))
end

struct NativeG1G2InHouseQ1PlanV1
    compilation::NativeG1G2DiffusionCompilationV1
    compile_result_hash::Digest256
    protocol::NativeG1G2InHouseQ1ProtocolV1
    source_binding_hash::Digest256
    provider::ProviderManifestV4
    subject::ExecutablePhysicalSubjectV4
    solver_input::SolverInputV4
    solver_source_hash::Digest256
    plan_hash::Digest256
end

function _ng12ihq1_plan_body(compilation, compile_result_hash, protocol,
        source_binding_hash, provider, subject, solver_input,
        solver_source_hash)
    (domain="native-g1g2-inhouse-q1-plan-v1",
        compilation=compilation, compile_result_hash=compile_result_hash,
        protocol=protocol, source_binding_hash=source_binding_hash,
        provider=provider, subject=subject, solver_input=solver_input,
        solver_source_hash=solver_source_hash)
end

semantic_view(plan::NativeG1G2InHouseQ1PlanV1) = merge(
    _ng12ihq1_plan_body(plan.compilation, plan.compile_result_hash,
        plan.protocol, plan.source_binding_hash, plan.provider, plan.subject,
        plan.solver_input, plan.solver_source_hash),
    (plan_hash=plan.plan_hash,))
canonical_hash(plan::NativeG1G2InHouseQ1PlanV1) = plan.plan_hash

function _ng12ihq1_provider(compilation, protocol, source_binding_hash,
        solver_source_hash)
    domain = (bounds_hash=compilation.capability.applicability_bounds,
        form_hash=compilation.form.form_hash,
        source_binding_hash=source_binding_hash,
        protocol_hash=protocol.protocol_hash,
        supported_chart=:positive_diagonal_affine,
        supported_basis=:Q1,
        supported_boundary=:all_six_faces_zero_dirichlet,
        solver=:inhouse_q1_jacobi_pcg,
        quadrature_degree=protocol.quadrature_degree,
        quadrature_rule=protocol.quadrature_rule)
    ProviderManifestV4(NATIVE_G1G2_DIFFUSION_SCHEMA_V1,
        NATIVE_G1G2_DIFFUSION_VERSION_V1, :native_g1g2_diffusion,
        compilation.capability, domain, NATIVE_G1G2_INHOUSE_Q1_BACKEND_V1,
        "inhouse-q1-jacobi-pcg-v1", solver_source_hash,
        "inhouse-native-g1g2-q1-jacobi-pcg-v1", screen_only;
        input_schema_hash=compilation.capability.input_schema_hash,
        executor=_native_g1g2_inhouse_q1_provider_executor_v1)
end

function _ng12ihq1_materialized(compilation, compile_result_hash,
        protocol, source_binding_hash, solver_source_hash)
    (compilation=compilation, compile_result_hash=compile_result_hash,
        protocol=protocol, source_binding_hash=source_binding_hash,
        solver_source_hash=solver_source_hash,
        execution_scope=:numerical_preparation,
        formal_t2_receipt_assignment=false)
end

function _ng12ihq1_build_plan(compilation, compile_result_hash, protocol,
        solver_source_hash)
    form = compilation.form
    binding = _ng12ihq1_source_binding(form)
    source_binding_hash = canonical_hash(binding)
    provider = _ng12ihq1_provider(compilation, protocol,
        source_binding_hash, solver_source_hash)
    materialized = _ng12ihq1_materialized(compilation,
        compile_result_hash, protocol, source_binding_hash,
        solver_source_hash)
    subject = ExecutablePhysicalSubjectV4(
        compilation.subject.compiled_prefix_hash,
        compilation.subject.genome_bundle_hash,
        compilation.subject.mission_hash, compilation.subject.bounds_hash,
        compilation.subject.bindings, compilation.subject.scenarios,
        materialized, (compilation.capability,))
    solver_input = compile_solver_input(subject, compilation.scenario,
        compilation.capability, provider)
    body = _ng12ihq1_plan_body(compilation, compile_result_hash, protocol,
        source_binding_hash, provider, subject, solver_input,
        solver_source_hash)
    NativeG1G2InHouseQ1PlanV1(compilation, compile_result_hash, protocol,
        source_binding_hash, provider, subject, solver_input,
        solver_source_hash, canonical_hash(body))
end

"""Prepare an independently identified provider-bound in-house solver plan."""
function prepare_native_g1g2_inhouse_q1_v1(
        result::NativeG1G2DiffusionCompileResultV1,
        protocol::NativeG1G2InHouseQ1ProtocolV1=
            native_g1g2_inhouse_q1_protocol_v1())
    result.status === :compiled_numerical_preparation &&
    result.compilation !== nothing && isempty(result.errors) ||
        throw(NativeG1G2InHouseQ1ErrorV1(:compile_result_not_executable,
            Tuple(result.errors)))
    expected_result_hash = canonical_hash(_ng12_compile_result_body(
        result.status, result.resolution, result.accepted,
        result.claim_ceiling, result.compilation, result.errors,
        result.gaps))
    expected_result_hash == result.result_hash ||
        throw(NativeG1G2InHouseQ1ErrorV1(:compile_result_hash_mismatch, ()))
    validate_native_g1g2_diffusion_compilation_v1(result.compilation) ||
        throw(NativeG1G2InHouseQ1ErrorV1(:compilation_integrity_mismatch, ()))
    _ng12ihq1_protocol_integrity(protocol) ||
        throw(NativeG1G2InHouseQ1ErrorV1(:protocol_integrity_mismatch, ()))
    form = result.compilation.form
    form_errors = _ng12ihq1_supported_form_errors(form)
    isempty(form_errors) || throw(NativeG1G2InHouseQ1ErrorV1(
        :unsupported_topology, form_errors))
    _ng12ihq1_error_budget_applies(form, protocol) ||
        throw(NativeG1G2InHouseQ1ErrorV1(:predeclared_error_budget_not_applicable,
            ()))
    plan = _ng12ihq1_build_plan(result.compilation, result.result_hash,
        protocol, native_g1g2_inhouse_q1_source_hash_v1())
    validate_native_g1g2_inhouse_q1_plan_v1(plan) ||
        throw(NativeG1G2InHouseQ1ErrorV1(:plan_integrity_mismatch, ()))
    plan
end

function validate_native_g1g2_inhouse_q1_plan_v1(
        plan::NativeG1G2InHouseQ1PlanV1)
    try
        validate_native_g1g2_diffusion_compilation_v1(plan.compilation) ||
            return false
        expected_gaps = (:native_g1g2_numerical_execution_pending,
            :up1_aggregate_gate_pending,
            :g3_material_conversion_missing,
            :g3_two_region_interface_missing)
        plan.compile_result_hash == canonical_hash(
            _ng12_compile_result_body(:compiled_numerical_preparation,
                :terminal_deferred, false, :contract_only,
                plan.compilation, (), expected_gaps)) || return false
        _ng12ihq1_protocol_integrity(plan.protocol) || return false
        _ng12ihq1_error_budget_applies(plan.compilation.form,
            plan.protocol) || return false
        isempty(_ng12ihq1_supported_form_errors(
            plan.compilation.form)) || return false
        plan.solver_source_hash == native_g1g2_inhouse_q1_source_hash_v1() ||
            return false
        binding = canonical_hash(_ng12ihq1_source_binding(
            plan.compilation.form))
        plan.source_binding_hash == binding || return false
        expected_provider = _ng12ihq1_provider(plan.compilation,
            plan.protocol, binding, plan.solver_source_hash)
        canonical_json(plan.provider) == canonical_json(expected_provider) ||
            return false
        match_provider(plan.compilation.capability,
            (plan.provider,)).status == unique_match || return false
        expected_materialized = _ng12ihq1_materialized(
            plan.compilation, plan.compile_result_hash, plan.protocol,
            binding, plan.solver_source_hash)
        plan.subject.materialized_payload == expected_materialized ||
            return false
        plan.subject.operator_obligations ==
            (plan.compilation.capability,) || return false
        plan.subject.scenarios == (plan.compilation.scenario,) || return false
        plan.solver_input.physical_subject_hash ==
            plan.subject.physical_subject_hash || return false
        plan.solver_input.provider_manifest_hash ==
            plan.provider.manifest_hash || return false
        plan.solver_input.input_schema_hash ==
            plan.compilation.capability.input_schema_hash || return false
        rebuilt_input = compile_solver_input(plan.subject,
            plan.compilation.scenario, plan.compilation.capability,
            plan.provider)
        rebuilt_input.solver_input_hash ==
            plan.solver_input.solver_input_hash || return false
        plan.provider.executor ===
            _native_g1g2_inhouse_q1_provider_executor_v1 || return false
        canonical_hash(_ng12ihq1_plan_body(plan.compilation,
            plan.compile_result_hash, plan.protocol,
            plan.source_binding_hash, plan.provider, plan.subject,
            plan.solver_input, plan.solver_source_hash)) == plan.plan_hash
    catch
        false
    end
end

struct NativeG1G2InHouseQ1LevelResultV1
    level::Int
    cell_counts::NTuple{3,Int}
    physical_domain::NTuple{6,Float64}
    cells::Int
    free_dofs::Int
    dirichlet_dofs::Int
    matrix_shape::NTuple{2,Int}
    matrix_nnz::Int
    matrix_hash::Digest256
    full_matrix_hash::Digest256
    rhs_hash::Digest256
    solution_hash::Digest256
    matrix_rows::Tuple{Vararg{Int}}
    matrix_columns::Tuple{Vararg{Int}}
    matrix_values::Tuple{Vararg{Float64}}
    full_matrix_rows::Tuple{Vararg{Int}}
    full_matrix_columns::Tuple{Vararg{Int}}
    full_matrix_values::Tuple{Vararg{Float64}}
    free_dof_ids::Tuple{Vararg{Int}}
    boundary_dof_ids::Tuple{Vararg{Int}}
    rhs_values::Tuple{Vararg{Float64}}
    full_rhs_values::Tuple{Vararg{Float64}}
    solution_values::Tuple{Vararg{Float64}}
    full_solution_values::Tuple{Vararg{Float64}}
    rhs_norm_inf::Float64
    residual_abs::Float64
    residual_rel::Float64
    l2_error::Float64
    h1_seminorm_error::Float64
    boundary_linf::Float64
    assembled_source_integral::Float64
    analytic_source_integral::Float64
    source_integral_error::Float64
    analytic_outward_conormal_integral::Float64
    analytic_identity_defect::Float64
    discrete_trace_conormal_integral::Float64
    discrete_trace_conormal_error::Float64
    dof_partition_hash::Digest256
    discrete_interior_reaction_linf::Float64
    discrete_interior_reaction_sum::Float64
    discrete_interior_residual_match_linf::Float64
    discrete_boundary_reaction_integral::Float64
    discrete_boundary_reaction_balance_defect::Float64
    pcg_iterations::Int
    pcg_max_iterations::Int
    pcg_residual_target::Float64
    pcg_converged::Bool
    pcg_failure::Symbol
    assembly_cell_evaluations::Int
    assembly_quadrature_points::Int
    source_sign::Symbol
    status::Symbol
    errors::Tuple{Vararg{Symbol}}
    level_hash::Digest256
end

function _ng12ihq1_level_body(level, cell_counts, physical_domain, cells,
        free_dofs, dirichlet_dofs, matrix_shape, matrix_nnz, matrix_hash,
        full_matrix_hash, rhs_hash, solution_hash, matrix_rows,
        matrix_columns, matrix_values, full_matrix_rows,
        full_matrix_columns, full_matrix_values, free_dof_ids,
        boundary_dof_ids, rhs_values, full_rhs_values, solution_values,
        full_solution_values, rhs_norm_inf, residual_abs,
        residual_rel, l2_error, h1_seminorm_error, boundary_linf,
        assembled_source_integral, analytic_source_integral,
        source_integral_error, analytic_outward_conormal_integral,
        analytic_identity_defect, discrete_trace_conormal_integral,
        discrete_trace_conormal_error, dof_partition_hash,
        discrete_interior_reaction_linf, discrete_interior_reaction_sum,
        discrete_interior_residual_match_linf,
        discrete_boundary_reaction_integral,
        discrete_boundary_reaction_balance_defect, pcg_iterations,
        pcg_max_iterations, pcg_residual_target, pcg_converged, pcg_failure,
        assembly_cell_evaluations, assembly_quadrature_points, source_sign,
        status, errors)
    (domain="native-g1g2-inhouse-q1-level-v1", level=level,
        cell_counts=cell_counts, physical_domain=physical_domain,
        cells=cells, free_dofs=free_dofs,
        dirichlet_dofs=dirichlet_dofs, matrix_shape=matrix_shape,
        matrix_nnz=matrix_nnz, matrix_hash=matrix_hash,
        full_matrix_hash=full_matrix_hash, rhs_hash=rhs_hash,
        solution_hash=solution_hash, matrix_rows=matrix_rows,
        matrix_columns=matrix_columns, matrix_values=matrix_values,
        full_matrix_rows=full_matrix_rows,
        full_matrix_columns=full_matrix_columns,
        full_matrix_values=full_matrix_values,
        free_dof_ids=free_dof_ids, boundary_dof_ids=boundary_dof_ids,
        rhs_values=rhs_values, full_rhs_values=full_rhs_values,
        solution_values=solution_values,
        full_solution_values=full_solution_values,
        rhs_norm_inf=rhs_norm_inf, residual_abs=residual_abs,
        residual_rel=residual_rel, l2_error=l2_error,
        h1_seminorm_error=h1_seminorm_error,
        boundary_linf=boundary_linf,
        assembled_source_integral=assembled_source_integral,
        analytic_source_integral=analytic_source_integral,
        source_integral_error=source_integral_error,
        analytic_outward_conormal_integral=analytic_outward_conormal_integral,
        analytic_identity_defect=analytic_identity_defect,
        discrete_trace_conormal_integral=discrete_trace_conormal_integral,
        discrete_trace_conormal_error=discrete_trace_conormal_error,
        dof_partition_hash=dof_partition_hash,
        discrete_interior_reaction_linf=discrete_interior_reaction_linf,
        discrete_interior_reaction_sum=discrete_interior_reaction_sum,
        discrete_interior_residual_match_linf=
            discrete_interior_residual_match_linf,
        discrete_boundary_reaction_integral=
            discrete_boundary_reaction_integral,
        discrete_boundary_reaction_balance_defect=
            discrete_boundary_reaction_balance_defect,
        pcg_iterations=pcg_iterations,
        pcg_max_iterations=pcg_max_iterations,
        pcg_residual_target=pcg_residual_target,
        pcg_converged=pcg_converged, pcg_failure=pcg_failure,
        assembly_cell_evaluations=assembly_cell_evaluations,
        assembly_quadrature_points=assembly_quadrature_points,
        source_sign=source_sign, status=status, errors=errors)
end

semantic_view(level::NativeG1G2InHouseQ1LevelResultV1) = merge(
    _ng12ihq1_level_body(level.level, level.cell_counts,
        level.physical_domain, level.cells, level.free_dofs,
        level.dirichlet_dofs, level.matrix_shape, level.matrix_nnz,
        level.matrix_hash, level.full_matrix_hash, level.rhs_hash,
        level.solution_hash, level.matrix_rows, level.matrix_columns,
        level.matrix_values, level.full_matrix_rows,
        level.full_matrix_columns, level.full_matrix_values,
        level.free_dof_ids, level.boundary_dof_ids, level.rhs_values,
        level.full_rhs_values, level.solution_values,
        level.full_solution_values, level.rhs_norm_inf,
        level.residual_abs, level.residual_rel,
        level.l2_error, level.h1_seminorm_error, level.boundary_linf,
        level.assembled_source_integral, level.analytic_source_integral,
        level.source_integral_error,
        level.analytic_outward_conormal_integral,
        level.analytic_identity_defect,
        level.discrete_trace_conormal_integral,
        level.discrete_trace_conormal_error, level.dof_partition_hash,
        level.discrete_interior_reaction_linf,
        level.discrete_interior_reaction_sum,
        level.discrete_interior_residual_match_linf,
        level.discrete_boundary_reaction_integral,
        level.discrete_boundary_reaction_balance_defect,
        level.pcg_iterations, level.pcg_max_iterations,
        level.pcg_residual_target, level.pcg_converged,
        level.pcg_failure,
        level.assembly_cell_evaluations,
        level.assembly_quadrature_points, level.source_sign,
        level.status, level.errors), (level_hash=level.level_hash,))
canonical_hash(level::NativeG1G2InHouseQ1LevelResultV1) = level.level_hash

const _NG12IHQ1_GL5_X = (-0.9061798459386640, -0.5384693101056831,
    0.0, 0.5384693101056831, 0.9061798459386640)
const _NG12IHQ1_GL5_W = (0.2369268850561891, 0.4786286704993665,
    0.5688888888888889, 0.4786286704993665, 0.2369268850561891)
const _NG12IHQ1_Q1_BITS = ((0, 0, 0), (1, 0, 0), (0, 1, 0),
    (1, 1, 0), (0, 0, 1), (1, 0, 1), (0, 1, 1), (1, 1, 1))

function _ng12ihq1_domain(form::NativeG1G2VariableDiffusionFormV1)
    bounds = g2mb_chart_image_bounds(form.g2_declaration.source.chart_map)
    (Float64(bounds[1][1]), Float64(bounds[1][2]),
        Float64(bounds[2][1]), Float64(bounds[2][2]),
        Float64(bounds[3][1]), Float64(bounds[3][2]))
end

_ng12ihq1_node_id(i, j, k, nx, ny) =
    1 + i + (nx + 1) * (j + (ny + 1) * k)

function _ng12ihq1_cell_dofs(i, j, k, nx, ny)
    ntuple(a -> begin
        bits = _NG12IHQ1_Q1_BITS[a]
        _ng12ihq1_node_id(i + bits[1], j + bits[2], k + bits[3],
            nx, ny)
    end, 8)
end

function _ng12ihq1_basis(xi::NTuple{3,Float64}, h::NTuple{3,Float64})
    values = ntuple(a -> begin
        bits = _NG12IHQ1_Q1_BITS[a]
        prod((1.0 + (2 * bits[d] - 1) * xi[d]) / 2.0 for d in 1:3)
    end, 8)
    gradients = ntuple(a -> begin
        bits = _NG12IHQ1_Q1_BITS[a]
        ntuple(d -> begin
            sd = 2 * bits[d] - 1
            sd / h[d] * prod((1.0 + (2 * bits[e] - 1) * xi[e]) / 2.0
                for e in 1:3 if e != d)
        end, 3)
    end, 8)
    (values=values, gradients=gradients)
end

function _ng12ihq1_point(domain, cell::NTuple{3,Int}, h,
        xi::NTuple{3,Float64})
    ntuple(d -> domain[2d - 1] + (cell[d] + (xi[d] + 1.0) / 2.0) * h[d], 3)
end

function _ng12ihq1_sparse_hash(matrix)
    rows, columns, values = findnz(sparse(matrix))
    canonical_hash((shape=(size(matrix, 1), size(matrix, 2)),
        rows=Vector{Int}(rows), columns=Vector{Int}(columns),
        values=Vector{Float64}(values)))
end

function _ng12ihq1_sparse_payload(matrix)
    rows, columns, values = findnz(sparse(matrix))
    (shape=(size(matrix, 1), size(matrix, 2)),
        rows=Tuple(Int.(rows)), columns=Tuple(Int.(columns)),
        values=Tuple(Float64.(values)))
end

_ng12ihq1_sparse_payload_hash(payload) = canonical_hash(payload)

"""Assemble full and zero-Dirichlet-reduced Q1 matrices from cell integrals."""
function _ng12ihq1_assemble(form, counts::NTuple{3,Int}, domain)
    nx, ny, nz = counts
    lengths = (domain[2] - domain[1], domain[4] - domain[3],
        domain[6] - domain[5])
    h = (lengths[1] / nx, lengths[2] / ny, lengths[3] / nz)
    nfull = (nx + 1) * (ny + 1) * (nz + 1)
    ncells = nx * ny * nz
    rows = Vector{Int}(undef, 64 * ncells)
    columns = Vector{Int}(undef, 64 * ncells)
    values = Vector{Float64}(undef, 64 * ncells)
    rhs_full = zeros(Float64, nfull)
    source_integral = 0.0
    cursor = 0
    det_j = prod(h) / 8.0
    for k in 0:nz-1, j in 0:ny-1, i in 0:nx-1
        cell = (i, j, k)
        dofs = _ng12ihq1_cell_dofs(i, j, k, nx, ny)
        local_matrix = zeros(Float64, 8, 8)
        local_rhs = zeros(Float64, 8)
        for qz in 1:5, qy in 1:5, qx in 1:5
            xi = (_NG12IHQ1_GL5_X[qx], _NG12IHQ1_GL5_X[qy],
                _NG12IHQ1_GL5_X[qz])
            basis = _ng12ihq1_basis(xi, h)
            point = _ng12ihq1_point(domain, cell, h, xi)
            weight = det_j * _NG12IHQ1_GL5_W[qx] *
                _NG12IHQ1_GL5_W[qy] * _NG12IHQ1_GL5_W[qz]
            source = native_g1g2_source_value_v1(form, point)
            kdiag = native_g1g2_k_diagonal_v1(form, point)
            isfinite(source) && all(isfinite, kdiag) && all(>(0.0), kdiag) ||
                throw(NativeG1G2InHouseQ1ErrorV1(:nonfinite_or_nonpositive_material,
                    ()))
            source_integral += source * weight
            for a in 1:8
                na = basis.values[a]
                ga = basis.gradients[a]
                local_rhs[a] += na * source * weight
                for b in 1:8
                    gb = basis.gradients[b]
                    local_matrix[a, b] +=
                        (ga[1] * kdiag[1] * gb[1] +
                         ga[2] * kdiag[2] * gb[2] +
                         ga[3] * kdiag[3] * gb[3]) * weight
                end
            end
        end
        for a in 1:8
            rhs_full[dofs[a]] += local_rhs[a]
            for b in 1:8
                cursor += 1
                rows[cursor] = dofs[a]
                columns[cursor] = dofs[b]
                values[cursor] = local_matrix[a, b]
            end
        end
    end
    cursor == length(values) || error("local stiffness inventory mismatch")
    full_matrix = sparse(rows, columns, values, nfull, nfull)
    free_ids = Int[]
    boundary_ids = Int[]
    for k in 0:nz, j in 0:ny, i in 0:nx
        id = _ng12ihq1_node_id(i, j, k, nx, ny)
        if 0 < i < nx && 0 < j < ny && 0 < k < nz
            push!(free_ids, id)
        else
            push!(boundary_ids, id)
        end
    end
    length(free_ids) == prod(counts .- 1) ||
        error("interior Q1 dof inventory mismatch")
    length(boundary_ids) + length(free_ids) == nfull ||
        error("Q1 dof partition is incomplete")
    free_matrix = sparse(full_matrix[free_ids, free_ids])
    rhs_free = rhs_full[free_ids]
    partition_hash = canonical_hash((domain="native-g1g2-q1-dof-partition-v1",
        free_to_full=free_ids, boundary_to_full=boundary_ids))
    (full_matrix=full_matrix, free_matrix=free_matrix,
        rhs_full=rhs_full, rhs_free=rhs_free, free_ids=free_ids,
        boundary_ids=boundary_ids, source_integral=source_integral,
        partition_hash=partition_hash, physical_steps=h,
        cell_evaluations=ncells,
        quadrature_points=125 * ncells)
end

function _ng12ihq1_pcg(matrix::SparseMatrixCSC{Float64,Int},
        rhs::Vector{Float64}, protocol::NativeG1G2InHouseQ1ProtocolV1)
    length(rhs) == size(matrix, 1) == size(matrix, 2) ||
        throw(NativeG1G2InHouseQ1ErrorV1(:linear_system_shape_mismatch, ()))
    diagonal = Vector{Float64}(diag(matrix))
    all(isfinite, diagonal) && all(>(0.0), diagonal) ||
        throw(NativeG1G2InHouseQ1ErrorV1(:nonpositive_jacobi_diagonal, ()))
    x = zeros(Float64, length(rhs))
    rhs_inf = norm(rhs, Inf)
    target = max(protocol.residual_abs_tol,
        protocol.residual_rel_tol * rhs_inf)
    max_iterations = max(1,
        protocol.pcg_max_iterations_per_free_dof * length(rhs))
    r = rhs - matrix * x
    residual = norm(r, Inf)
    residual <= target && return (x=x, iterations=0, max_iterations=max_iterations,
        target=target, residual=residual, converged=true, failure=:none)
    z = r ./ diagonal
    p = copy(z)
    rz = dot(r, z)
    isfinite(rz) && rz > 0.0 ||
        return (x=x, iterations=0, max_iterations=max_iterations,
            target=target, residual=residual, converged=false,
            failure=:nonpositive_preconditioned_residual)
    for iteration in 1:max_iterations
        ap = matrix * p
        curvature = dot(p, ap)
        isfinite(curvature) && curvature > 0.0 ||
            return (x=x, iterations=iteration - 1,
                max_iterations=max_iterations, target=target,
                residual=norm(rhs - matrix * x, Inf), converged=false,
                failure=:nonpositive_curvature)
        alpha = rz / curvature
        isfinite(alpha) ||
            return (x=x, iterations=iteration - 1,
                max_iterations=max_iterations, target=target,
                residual=norm(rhs - matrix * x, Inf), converged=false,
                failure=:nonfinite_step)
        x .+= alpha .* p
        r = rhs - matrix * x
        residual = norm(r, Inf)
        isfinite(residual) ||
            return (x=x, iterations=iteration,
                max_iterations=max_iterations, target=target,
                residual=residual, converged=false,
                failure=:nonfinite_residual)
        residual <= target && return (x=x, iterations=iteration,
            max_iterations=max_iterations, target=target,
            residual=residual, converged=true, failure=:none)
        z = r ./ diagonal
        rz_next = dot(r, z)
        isfinite(rz_next) && rz_next > 0.0 ||
            return (x=x, iterations=iteration,
                max_iterations=max_iterations, target=target,
                residual=residual, converged=false,
                failure=:nonpositive_preconditioned_residual)
        beta = rz_next / rz
        isfinite(beta) ||
            return (x=x, iterations=iteration,
                max_iterations=max_iterations, target=target,
                residual=residual, converged=false,
                failure=:nonfinite_direction_update)
        p .= z .+ beta .* p
        rz = rz_next
    end
    (x=x, iterations=max_iterations, max_iterations=max_iterations,
        target=target, residual=norm(rhs - matrix * x, Inf),
        converged=false, failure=:max_iterations)
end

function _ng12ihq1_full_values(free_values, free_ids, nfull)
    values = zeros(Float64, nfull)
    values[free_ids] = free_values
    values
end

function _ng12ihq1_error_integrals(form, counts, domain, h, full_values)
    nx, ny, nz = counts
    l2_squared = 0.0
    h1_squared = 0.0
    for k in 0:nz-1, j in 0:ny-1, i in 0:nx-1
        cell = (i, j, k)
        dofs = _ng12ihq1_cell_dofs(i, j, k, nx, ny)
        for qz in 1:5, qy in 1:5, qx in 1:5
            xi = (_NG12IHQ1_GL5_X[qx], _NG12IHQ1_GL5_X[qy],
                _NG12IHQ1_GL5_X[qz])
            basis = _ng12ihq1_basis(xi, h)
            point = _ng12ihq1_point(domain, cell, h, xi)
            weight = prod(h) / 8.0 * _NG12IHQ1_GL5_W[qx] *
                _NG12IHQ1_GL5_W[qy] * _NG12IHQ1_GL5_W[qz]
            uh = sum(basis.values[a] * full_values[dofs[a]] for a in 1:8)
            grad_h = ntuple(d -> sum(basis.gradients[a][d] *
                full_values[dofs[a]] for a in 1:8), 3)
            value_error = uh - native_g1g2_reference_value_v1(form, point)
            grad_exact = native_g1g2_reference_gradient_v1(form, point)
            l2_squared += value_error^2 * weight
            h1_squared += sum((grad_h[d] - grad_exact[d])^2 for d in 1:3) *
                weight
        end
    end
    (l2=sqrt(max(0.0, l2_squared)), h1=sqrt(max(0.0, h1_squared)))
end

function _ng12ihq1_face_trace(form, counts, domain, h, full_values,
        axis::Int, side::Int)
    nx, ny, nz = counts
    tangent_axes = Tuple(d for d in 1:3 if d != axis)
    cell_ranges = (0:nx-1, 0:ny-1, 0:nz-1)
    fixed_cell = side < 0 ? 0 : counts[axis] - 1
    total = 0.0
    for k in cell_ranges[3], j in cell_ranges[2], i in cell_ranges[1]
        cell = (i, j, k)
        cell[axis] == fixed_cell || continue
        dofs = _ng12ihq1_cell_dofs(i, j, k, nx, ny)
        for qb in 1:5, qa in 1:5
            xi_values = zeros(Float64, 3)
            xi_values[axis] = side < 0 ? -1.0 : 1.0
            xi_values[tangent_axes[1]] = _NG12IHQ1_GL5_X[qa]
            xi_values[tangent_axes[2]] = _NG12IHQ1_GL5_X[qb]
            xi = Tuple(xi_values)
            basis = _ng12ihq1_basis(xi, h)
            point = _ng12ihq1_point(domain, cell, h, xi)
            grad_h = ntuple(d -> sum(basis.gradients[a][d] *
                full_values[dofs[a]] for a in 1:8), 3)
            kdiag = native_g1g2_k_diagonal_v1(form, point)
            weight = h[tangent_axes[1]] * h[tangent_axes[2]] / 4.0 *
                _NG12IHQ1_GL5_W[qa] * _NG12IHQ1_GL5_W[qb]
            total += side * kdiag[axis] * grad_h[axis] * weight
        end
    end
    total
end

function _ng12ihq1_boundary_trace(form, counts, domain, h, full_values)
    sum(_ng12ihq1_face_trace(form, counts, domain, h, full_values,
        axis, side) for axis in 1:3 for side in (-1, 1))
end

function _ng12ihq1_level_errors(values, protocol, pcg, source_sign)
    errors = Symbol[]
    all(isfinite, values) || push!(errors, :nonfinite_numerical_output)
    pcg.converged || push!(errors, Symbol("pcg_", pcg.failure))
    residual_ok = values[1] <= protocol.residual_abs_tol ||
        values[2] <= protocol.residual_rel_tol
    residual_ok || push!(errors, :algebraic_residual_exceeded)
    values[3] <= protocol.boundary_abs_tol ||
        push!(errors, :dirichlet_boundary_exceeded)
    values[4] <= protocol.source_integral_abs_tol ||
        push!(errors, :assembled_source_integral_mismatch)
    values[5] <= protocol.analytic_identity_abs_tol ||
        push!(errors, :analytic_balance_identity_mismatch)
    values[6] <= protocol.residual_abs_tol ||
        push!(errors, :interior_reaction_exceeded)
    values[7] <= protocol.residual_abs_tol ||
        push!(errors, :interior_reaction_residual_mismatch)
    values[8] <= protocol.reaction_balance_abs_tol ||
        push!(errors, :boundary_reaction_balance_exceeded)
    source_sign === :declared || push!(errors, :unsupported_source_sign)
    Tuple(unique(errors))
end

function run_native_g1g2_inhouse_q1_level_v1(
        plan::NativeG1G2InHouseQ1PlanV1, level::Integer)
    validate_native_g1g2_inhouse_q1_plan_v1(plan) ||
        throw(NativeG1G2InHouseQ1ErrorV1(:plan_integrity_mismatch, ()))
    1 <= level <= 3 || throw(ArgumentError("refinement level must be 1:3"))
    form = plan.compilation.form
    protocol = plan.protocol
    counts = protocol.cell_counts[Int(level)]
    domain = _ng12ihq1_domain(form)
    assembly = _ng12ihq1_assemble(form, counts, domain)
    pcg = _ng12ihq1_pcg(assembly.free_matrix, assembly.rhs_free,
        protocol)
    full_values = _ng12ihq1_full_values(pcg.x, assembly.free_ids,
        length(assembly.rhs_full))
    algebraic_residual = assembly.free_matrix * pcg.x - assembly.rhs_free
    residual_abs = norm(algebraic_residual, Inf)
    residual_rel = residual_abs / max(norm(assembly.rhs_free, Inf),
        eps(Float64))
    errors = _ng12ihq1_error_integrals(form, counts, domain,
        assembly.physical_steps, full_values)
    boundary_linf = maximum(abs(full_values[id])
        for id in assembly.boundary_ids)
    balance = native_g1g2_continuous_balance_v1(form)
    analytic_source = balance.source_integral
    analytic_outward = balance.outward_conormal_integral
    source_error = abs(assembly.source_integral - analytic_source)
    analytic_defect = analytic_source + analytic_outward
    trace = _ng12ihq1_boundary_trace(form, counts, domain,
        assembly.physical_steps, full_values)
    trace_error = abs(trace - analytic_outward)
    reactions = assembly.full_matrix * full_values - assembly.rhs_full
    interior_reactions = reactions[assembly.free_ids]
    boundary_reactions = reactions[assembly.boundary_ids]
    interior_linf = norm(interior_reactions, Inf)
    interior_sum = sum(interior_reactions)
    interior_match = norm(interior_reactions - algebraic_residual, Inf)
    boundary_reaction_sum = sum(boundary_reactions)
    reaction_balance = assembly.source_integral + boundary_reaction_sum
    observed = (residual_abs, residual_rel, boundary_linf, source_error,
        abs(analytic_defect), interior_linf, interior_match,
        abs(reaction_balance), errors.l2, errors.h1, trace, trace_error,
        assembly.source_integral, analytic_source, analytic_outward,
        interior_sum, boundary_reaction_sum, pcg.residual)
    finite = all(isfinite, observed) && all(isfinite, full_values)
    values = (residual_abs, residual_rel, boundary_linf, source_error,
        abs(analytic_defect), interior_linf, interior_match,
        abs(reaction_balance))
    level_errors = collect(_ng12ihq1_level_errors(values, protocol, pcg,
        :declared))
    finite || push!(level_errors, :nonfinite_numerical_output)
    level_error_tuple = Tuple(unique(level_errors))
    status = isempty(level_error_tuple) ? :pass : :numerical_fail
    matrix = assembly.free_matrix
    matrix_payload = _ng12ihq1_sparse_payload(matrix)
    full_matrix_payload = _ng12ihq1_sparse_payload(assembly.full_matrix)
    matrix_hash = _ng12ihq1_sparse_payload_hash(matrix_payload)
    full_matrix_hash = _ng12ihq1_sparse_payload_hash(full_matrix_payload)
    rhs_hash = canonical_hash(assembly.rhs_free)
    solution_hash = canonical_hash(pcg.x)
    args = (Int(level), counts, domain, prod(counts),
        length(assembly.free_ids), length(assembly.boundary_ids),
        (size(matrix, 1), size(matrix, 2)), nnz(matrix), matrix_hash,
        full_matrix_hash, rhs_hash, solution_hash,
        matrix_payload.rows, matrix_payload.columns, matrix_payload.values,
        full_matrix_payload.rows, full_matrix_payload.columns,
        full_matrix_payload.values, Tuple(assembly.free_ids),
        Tuple(assembly.boundary_ids), Tuple(assembly.rhs_free),
        Tuple(assembly.rhs_full), Tuple(pcg.x), Tuple(full_values),
        norm(assembly.rhs_free, Inf), residual_abs, residual_rel,
        errors.l2, errors.h1, boundary_linf, assembly.source_integral,
        analytic_source, source_error, analytic_outward, analytic_defect,
        trace, trace_error, assembly.partition_hash, interior_linf,
        interior_sum, interior_match, boundary_reaction_sum, reaction_balance,
        pcg.iterations, pcg.max_iterations, pcg.target, pcg.converged,
        pcg.failure, assembly.cell_evaluations,
        assembly.quadrature_points, :declared,
        status, level_error_tuple)
    body = _ng12ihq1_level_body(args...)
    NativeG1G2InHouseQ1LevelResultV1(args...,
        canonical_hash(body))
end

function _ng12ihq1_level_integrity(level::NativeG1G2InHouseQ1LevelResultV1)
    level.level in 1:3 && all(>(0), level.cell_counts) &&
    level.cells == prod(level.cell_counts) && level.free_dofs > 0 &&
    level.dirichlet_dofs > 0 && level.matrix_nnz > 0 &&
    level.matrix_shape == (level.free_dofs, level.free_dofs) &&
    level.assembly_cell_evaluations == level.cells &&
    level.assembly_quadrature_points == 125 * level.cells &&
    level.pcg_iterations <= level.pcg_max_iterations &&
    level.pcg_max_iterations > 0 && level.pcg_residual_target > 0.0 &&
    level.rhs_norm_inf >= 0.0 &&
    (level.pcg_converged == (level.pcg_failure === :none)) &&
    length(level.matrix_rows) == length(level.matrix_columns) ==
        length(level.matrix_values) == level.matrix_nnz &&
    length(level.full_matrix_rows) == length(level.full_matrix_columns) ==
        length(level.full_matrix_values) > 0 &&
    length(level.rhs_values) == level.free_dofs &&
    length(level.solution_values) == level.free_dofs &&
    length(level.full_rhs_values) == level.free_dofs + level.dirichlet_dofs &&
    length(level.full_solution_values) ==
        level.free_dofs + level.dirichlet_dofs &&
    all(isfinite, (level.residual_abs, level.residual_rel, level.l2_error,
        level.h1_seminorm_error, level.boundary_linf,
        level.assembled_source_integral, level.analytic_source_integral,
        level.source_integral_error,
        level.analytic_outward_conormal_integral,
        level.analytic_identity_defect,
        level.discrete_trace_conormal_integral,
        level.discrete_trace_conormal_error,
        level.discrete_interior_reaction_linf,
        level.discrete_interior_reaction_sum,
        level.discrete_interior_residual_match_linf,
        level.discrete_boundary_reaction_integral,
        level.discrete_boundary_reaction_balance_defect,
        level.pcg_residual_target, level.rhs_norm_inf)) &&
    canonical_hash(_ng12ihq1_level_body(level.level, level.cell_counts,
        level.physical_domain, level.cells, level.free_dofs,
        level.dirichlet_dofs, level.matrix_shape, level.matrix_nnz,
        level.matrix_hash, level.full_matrix_hash, level.rhs_hash,
        level.solution_hash, level.matrix_rows, level.matrix_columns,
        level.matrix_values, level.full_matrix_rows,
        level.full_matrix_columns, level.full_matrix_values,
        level.free_dof_ids, level.boundary_dof_ids, level.rhs_values,
        level.full_rhs_values, level.solution_values,
        level.full_solution_values, level.rhs_norm_inf,
        level.residual_abs, level.residual_rel,
        level.l2_error, level.h1_seminorm_error, level.boundary_linf,
        level.assembled_source_integral, level.analytic_source_integral,
        level.source_integral_error,
        level.analytic_outward_conormal_integral,
        level.analytic_identity_defect,
        level.discrete_trace_conormal_integral,
        level.discrete_trace_conormal_error, level.dof_partition_hash,
        level.discrete_interior_reaction_linf,
        level.discrete_interior_reaction_sum,
        level.discrete_interior_residual_match_linf,
        level.discrete_boundary_reaction_integral,
        level.discrete_boundary_reaction_balance_defect,
        level.pcg_iterations, level.pcg_max_iterations,
        level.pcg_residual_target, level.pcg_converged, level.pcg_failure,
        level.assembly_cell_evaluations,
        level.assembly_quadrature_points, level.source_sign, level.status,
        level.errors)) == level.level_hash
end

function _ng12ihq1_sparse_from_payload(shape,
        rows::Tuple{Vararg{Int}}, columns::Tuple{Vararg{Int}},
        values::Tuple{Vararg{Float64}})
    length(rows) == length(columns) == length(values) || return nothing
    all(1 <= row <= shape[1] for row in rows) || return nothing
    all(1 <= column <= shape[2] for column in columns) || return nothing
    all(isfinite, values) || return nothing
    matrix = sparse(collect(rows), collect(columns), collect(values),
        shape[1], shape[2])
    payload = _ng12ihq1_sparse_payload(matrix)
    payload.rows == rows && payload.columns == columns &&
        payload.values == values || return nothing
    matrix
end

function _ng12ihq1_close(a::Real, b::Real, atol::Float64=1.0e-12)
    isfinite(a) && isfinite(b) && isapprox(a, b; atol=atol,
        rtol=1.0e-12)
end

"""Rebuild and audit retained CSC A,b,x artifacts before accepting a report."""
function _ng12ihq1_validate_raw_level(plan,
        level::NativeG1G2InHouseQ1LevelResultV1, level_index::Int)
    nfull = prod(level.cell_counts .+ 1)
    matrix = _ng12ihq1_sparse_from_payload(level.matrix_shape,
        level.matrix_rows, level.matrix_columns, level.matrix_values)
    full_matrix = _ng12ihq1_sparse_from_payload((nfull, nfull),
        level.full_matrix_rows, level.full_matrix_columns,
        level.full_matrix_values)
    matrix === nothing && return false
    full_matrix === nothing && return false
    size(matrix) == level.matrix_shape || return false
    nnz(matrix) == level.matrix_nnz || return false
    _ng12ihq1_sparse_payload_hash(_ng12ihq1_sparse_payload(matrix)) ==
        level.matrix_hash || return false
    _ng12ihq1_sparse_payload_hash(_ng12ihq1_sparse_payload(full_matrix)) ==
        level.full_matrix_hash || return false
    length(level.free_dof_ids) == level.free_dofs || return false
    length(level.boundary_dof_ids) == level.dirichlet_dofs || return false
    length(unique(level.free_dof_ids)) == level.free_dofs || return false
    length(unique(level.boundary_dof_ids)) == level.dirichlet_dofs ||
        return false
    all_full = vcat(collect(level.free_dof_ids),
        collect(level.boundary_dof_ids))
    sort(all_full) == collect(1:nfull) || return false
    sort(collect(level.free_dof_ids)) == collect(level.free_dof_ids) ||
        return false
    sort(collect(level.boundary_dof_ids)) ==
        collect(level.boundary_dof_ids) || return false
    expected_partition_hash = canonical_hash((
        domain="native-g1g2-q1-dof-partition-v1",
        free_to_full=collect(level.free_dof_ids),
        boundary_to_full=collect(level.boundary_dof_ids)))
    level.dof_partition_hash == expected_partition_hash || return false
    rhs = collect(level.rhs_values)
    full_rhs = collect(level.full_rhs_values)
    solution = collect(level.solution_values)
    full_solution = collect(level.full_solution_values)
    length(rhs) == level.free_dofs && length(solution) == level.free_dofs ||
        return false
    length(full_rhs) == nfull && length(full_solution) == nfull ||
        return false
    all(isfinite, (rhs..., full_rhs..., solution..., full_solution...)) ||
        return false
    canonical_hash(rhs) == level.rhs_hash || return false
    canonical_hash(solution) == level.solution_hash || return false
    full_solution[collect(level.free_dof_ids)] == solution || return false
    all(iszero(full_solution[index]) for index in level.boundary_dof_ids) ||
        return false
    reduced_from_full = sparse(full_matrix[
        collect(level.free_dof_ids), collect(level.free_dof_ids)])
    _ng12ihq1_sparse_payload_hash(
        _ng12ihq1_sparse_payload(reduced_from_full)) == level.matrix_hash ||
        return false
    close_partition = isapprox(rhs, full_rhs[collect(level.free_dof_ids)];
        atol=2.0e-12, rtol=2.0e-12)
    close_partition || return false
    rhs_norm = norm(rhs, Inf)
    _ng12ihq1_close(level.rhs_norm_inf, rhs_norm) || return false
    residual = matrix * solution - rhs
    residual_abs = norm(residual, Inf)
    residual_rel = residual_abs / max(rhs_norm, eps(Float64))
    _ng12ihq1_close(level.residual_abs, residual_abs) || return false
    _ng12ihq1_close(level.residual_rel, residual_rel) || return false
    target = max(plan.protocol.residual_abs_tol,
        plan.protocol.residual_rel_tol * rhs_norm)
    _ng12ihq1_close(level.pcg_residual_target, target) || return false
    level.pcg_converged == (residual_abs <= target) || return false
    full_residual = full_matrix * full_solution - full_rhs
    interior = full_residual[collect(level.free_dof_ids)]
    boundary = full_residual[collect(level.boundary_dof_ids)]
    _ng12ihq1_close(level.discrete_interior_reaction_linf,
        norm(interior, Inf)) || return false
    _ng12ihq1_close(level.discrete_interior_reaction_sum,
        sum(interior)) || return false
    _ng12ihq1_close(level.discrete_interior_residual_match_linf,
        norm(interior - residual, Inf)) || return false
    boundary_integral = sum(boundary)
    _ng12ihq1_close(level.discrete_boundary_reaction_integral,
        boundary_integral) || return false
    _ng12ihq1_close(level.discrete_boundary_reaction_balance_defect,
        level.assembled_source_integral + boundary_integral) || return false
    _ng12ihq1_close(level.assembled_source_integral, sum(full_rhs);
        atol=2.0e-10) || return false
    _ng12ihq1_close(level.boundary_linf,
        maximum(abs(full_solution[index])
            for index in level.boundary_dof_ids)) || return false
    domain = _ng12ihq1_domain(plan.compilation.form)
    h = ((domain[2] - domain[1]) / level.cell_counts[1],
        (domain[4] - domain[3]) / level.cell_counts[2],
        (domain[6] - domain[5]) / level.cell_counts[3])
    errors = _ng12ihq1_error_integrals(plan.compilation.form,
        level.cell_counts, domain, h, full_solution)
    _ng12ihq1_close(level.l2_error, errors.l2) || return false
    _ng12ihq1_close(level.h1_seminorm_error, errors.h1) || return false
    trace = _ng12ihq1_boundary_trace(plan.compilation.form,
        level.cell_counts, domain, h, full_solution)
    _ng12ihq1_close(level.discrete_trace_conormal_integral, trace) ||
        return false
    balance = native_g1g2_continuous_balance_v1(plan.compilation.form)
    source_error = abs(level.assembled_source_integral -
        balance.source_integral)
    trace_error = abs(trace - balance.outward_conormal_integral)
    _ng12ihq1_close(level.source_integral_error, source_error) || return false
    _ng12ihq1_close(level.discrete_trace_conormal_error, trace_error) ||
        return false
    true
end

function _ng12ihq1_level_matches_plan(plan,
        level::NativeG1G2InHouseQ1LevelResultV1, level_index::Int)
    protocol = plan.protocol
    values = (level.residual_abs,
        level.residual_rel, level.boundary_linf,
        level.source_integral_error, abs(level.analytic_identity_defect),
        level.discrete_interior_reaction_linf,
        level.discrete_interior_residual_match_linf,
        abs(level.discrete_boundary_reaction_balance_defect))
    expected_errors = _ng12ihq1_level_errors(values, protocol,
        (converged=level.pcg_converged, failure=level.pcg_failure),
        level.source_sign)
    expected_status = isempty(expected_errors) ? :pass : :numerical_fail
    balance = native_g1g2_continuous_balance_v1(plan.compilation.form)
    level.level == level_index &&
    level.cell_counts == protocol.cell_counts[level_index] &&
    level.physical_domain == _ng12ihq1_domain(plan.compilation.form) &&
    level.cells == prod(level.cell_counts) &&
    level.free_dofs + level.dirichlet_dofs ==
        prod(level.cell_counts .+ 1) &&
    level.source_sign === :declared &&
    level.pcg_max_iterations ==
        protocol.pcg_max_iterations_per_free_dof * level.free_dofs &&
    _ng12ihq1_close(level.pcg_residual_target,
        max(protocol.residual_abs_tol,
            protocol.residual_rel_tol * level.rhs_norm_inf)) &&
    _ng12ihq1_close(level.residual_abs,
        level.discrete_interior_reaction_linf) &&
    level.analytic_source_integral == balance.source_integral &&
    level.analytic_outward_conormal_integral ==
        balance.outward_conormal_integral &&
    _ng12ihq1_close(level.source_integral_error,
        abs(level.assembled_source_integral -
            level.analytic_source_integral)) &&
    level.analytic_identity_defect == level.analytic_source_integral +
        level.analytic_outward_conormal_integral &&
    _ng12ihq1_close(level.discrete_trace_conormal_error, abs(
        level.discrete_trace_conormal_integral -
            level.analytic_outward_conormal_integral)) &&
    level.discrete_interior_residual_match_linf <=
        protocol.residual_abs_tol &&
    _ng12ihq1_close(level.discrete_boundary_reaction_balance_defect,
        level.assembled_source_integral +
            level.discrete_boundary_reaction_integral) &&
    level.status == expected_status &&
    level.errors == expected_errors &&
    _ng12ihq1_validate_raw_level(plan, level, level_index)
end

function _ng12ihq1_orders(errors)
    ntuple(i -> log(errors[i] / errors[i + 1]) / log(2.0), 2)
end

struct NativeG1G2InHouseQ1ReportV1
    candidate_ref::QualifiedRefV1
    t1_package_hash::Digest256
    source_binding_hash::Digest256
    plan_hash::Digest256
    solver_input_hash::Digest256
    protocol_hash::Digest256
    solver_source_hash::Digest256
    levels::NTuple{3,NativeG1G2InHouseQ1LevelResultV1}
    l2_orders::NTuple{2,Float64}
    h1_orders::NTuple{2,Float64}
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::ClaimCeiling
    numerical_scope::Symbol
    physical_status::Symbol
    errors::Tuple{Vararg{Symbol}}
    gaps::Tuple{Vararg{Symbol}}
    report_hash::Digest256
end

function _ng12ihq1_report_body(candidate_ref, t1_package_hash,
        source_binding_hash, plan_hash, solver_input_hash, protocol_hash,
        solver_source_hash, levels, l2_orders, h1_orders, status,
        resolution, accepted, claim_ceiling, numerical_scope,
        physical_status, errors, gaps)
    (domain="native-g1g2-inhouse-q1-report-v1",
        candidate_ref=candidate_ref, t1_package_hash=t1_package_hash,
        source_binding_hash=source_binding_hash, plan_hash=plan_hash,
        solver_input_hash=solver_input_hash, protocol_hash=protocol_hash,
        solver_source_hash=solver_source_hash, levels=levels,
        l2_orders=l2_orders, h1_orders=h1_orders, status=status,
        resolution=resolution, accepted=accepted,
        claim_ceiling=claim_ceiling, numerical_scope=numerical_scope,
        physical_status=physical_status, errors=errors, gaps=gaps)
end

semantic_view(report::NativeG1G2InHouseQ1ReportV1) = merge(
    _ng12ihq1_report_body(report.candidate_ref, report.t1_package_hash,
        report.source_binding_hash, report.plan_hash,
        report.solver_input_hash, report.protocol_hash,
        report.solver_source_hash, report.levels, report.l2_orders,
        report.h1_orders, report.status, report.resolution,
        report.accepted, report.claim_ceiling, report.numerical_scope,
        report.physical_status, report.errors, report.gaps),
    (report_hash=report.report_hash,))
canonical_hash(report::NativeG1G2InHouseQ1ReportV1) = report.report_hash

const _NG12IHQ1_REPORT_GAPS_V1 = (
    :native_g1g2_numerical_execution_pending,
    :up1_aggregate_gate_pending,
    :g3_material_conversion_missing,
    :g3_two_region_interface_missing,
    :generic_declaration_driven_up2_execution_missing,
    :coupled_multiregion_nonlinear_dae_pde_solver_missing,
    :independent_physical_validation_missing)

_ng12ihq1_report_gaps_v1(status) = status === :pass ?
    Base.tail(_NG12IHQ1_REPORT_GAPS_V1) : _NG12IHQ1_REPORT_GAPS_V1

function _ng12ihq1_series(plan::NativeG1G2InHouseQ1PlanV1)
    levels = ntuple(i -> run_native_g1g2_inhouse_q1_level_v1(plan, i), 3)
    l2_orders = _ng12ihq1_orders(ntuple(i -> levels[i].l2_error, 3))
    h1_orders = _ng12ihq1_orders(ntuple(i ->
        levels[i].h1_seminorm_error, 3))
    protocol = plan.protocol
    reasons = Symbol[]
    all(level -> level.status === :pass, levels) ||
        push!(reasons, :level_numerical_gate_failed)
    all(levels[i].l2_error > levels[i + 1].l2_error &&
        levels[i].h1_seminorm_error > levels[i + 1].h1_seminorm_error
        for i in 1:2) || push!(reasons, :errors_not_monotone)
    all(levels[i].discrete_trace_conormal_error >
        levels[i + 1].discrete_trace_conormal_error for i in 1:2) ||
        push!(reasons, :boundary_trace_flux_error_not_monotone)
    all(protocol.l2_order_interval[1] <= order <=
        protocol.l2_order_interval[2] for order in l2_orders) ||
        push!(reasons, :l2_order_outside_interval)
    all(protocol.h1_order_interval[1] <= order <=
        protocol.h1_order_interval[2] for order in h1_orders) ||
        push!(reasons, :h1_order_outside_interval)
    levels[3].l2_error <= protocol.finest_l2_max ||
        push!(reasons, :finest_l2_budget_exceeded)
    levels[3].h1_seminorm_error <= protocol.finest_h1_seminorm_max ||
        push!(reasons, :finest_h1_budget_exceeded)
    status = isempty(reasons) ? :pass : :numerical_fail
    form = plan.compilation.form
    args = (form.candidate_ref, form.t1_package_hash,
        plan.source_binding_hash, plan.plan_hash,
        plan.solver_input.solver_input_hash, protocol.protocol_hash,
        plan.solver_source_hash, levels, l2_orders, h1_orders, status,
        :terminal_deferred, false, screen_only,
        :manufactured_variable_diffusion, :unknown, Tuple(reasons),
        _ng12ihq1_report_gaps_v1(status))
    body = _ng12ihq1_report_body(args...)
    NativeG1G2InHouseQ1ReportV1(args..., canonical_hash(body))
end

function validate_native_g1g2_inhouse_q1_report_v1(
        plan::NativeG1G2InHouseQ1PlanV1,
        report::NativeG1G2InHouseQ1ReportV1)
    try
        validate_native_g1g2_inhouse_q1_plan_v1(plan) || return false
        all(_ng12ihq1_level_integrity, report.levels) || return false
        all(_ng12ihq1_level_matches_plan(plan, report.levels[i], i)
            for i in 1:3) || return false
        report.candidate_ref == plan.compilation.form.candidate_ref ||
            return false
        report.t1_package_hash == plan.compilation.form.t1_package_hash ||
            return false
        report.source_binding_hash == plan.source_binding_hash ||
            return false
        report.plan_hash == plan.plan_hash || return false
        report.solver_input_hash == plan.solver_input.solver_input_hash ||
            return false
        report.protocol_hash == plan.protocol.protocol_hash || return false
        report.solver_source_hash == plan.solver_source_hash || return false
        report.l2_orders == _ng12ihq1_orders(ntuple(i ->
            report.levels[i].l2_error, 3)) || return false
        report.h1_orders == _ng12ihq1_orders(ntuple(i ->
            report.levels[i].h1_seminorm_error, 3)) || return false
        report.resolution === :terminal_deferred && !report.accepted &&
            report.claim_ceiling == screen_only &&
            report.numerical_scope === :manufactured_variable_diffusion &&
            report.physical_status === :unknown || return false
        expected_errors = Symbol[]
        all(level -> level.status === :pass, report.levels) ||
            push!(expected_errors, :level_numerical_gate_failed)
        all(report.levels[i].l2_error > report.levels[i + 1].l2_error &&
            report.levels[i].h1_seminorm_error >
                report.levels[i + 1].h1_seminorm_error for i in 1:2) ||
            push!(expected_errors, :errors_not_monotone)
        all(report.levels[i].discrete_trace_conormal_error >
            report.levels[i + 1].discrete_trace_conormal_error
            for i in 1:2) ||
            push!(expected_errors, :boundary_trace_flux_error_not_monotone)
        all(plan.protocol.l2_order_interval[1] <= order <=
            plan.protocol.l2_order_interval[2] for order in report.l2_orders) ||
            push!(expected_errors, :l2_order_outside_interval)
        all(plan.protocol.h1_order_interval[1] <= order <=
            plan.protocol.h1_order_interval[2] for order in report.h1_orders) ||
            push!(expected_errors, :h1_order_outside_interval)
        report.levels[3].l2_error <= plan.protocol.finest_l2_max ||
            push!(expected_errors, :finest_l2_budget_exceeded)
        report.levels[3].h1_seminorm_error <=
            plan.protocol.finest_h1_seminorm_max ||
            push!(expected_errors, :finest_h1_budget_exceeded)
        report.errors == Tuple(expected_errors) || return false
        report.status == (isempty(expected_errors) ? :pass :
            :numerical_fail) || return false
        report.gaps == _ng12ihq1_report_gaps_v1(report.status) || return false
        canonical_hash(_ng12ihq1_report_body(report.candidate_ref,
            report.t1_package_hash, report.source_binding_hash,
            report.plan_hash, report.solver_input_hash,
            report.protocol_hash, report.solver_source_hash,
            report.levels, report.l2_orders, report.h1_orders,
            report.status, report.resolution, report.accepted,
            report.claim_ceiling, report.numerical_scope,
            report.physical_status, report.errors, report.gaps)) ==
            report.report_hash
    catch
        false
    end
end

function _ng12ihq1_plan_from_solver_input(input::SolverInputV4)
    input.payload.materialized_payload isa NamedTuple ||
        throw(NativeG1G2InHouseQ1ErrorV1(:unsupported_solver_input_payload, ()))
    materialized = input.payload.materialized_payload
    haskey(materialized, :compilation) &&
    haskey(materialized, :compile_result_hash) &&
    haskey(materialized, :protocol) &&
    haskey(materialized, :source_binding_hash) &&
    haskey(materialized, :solver_source_hash) ||
        throw(NativeG1G2InHouseQ1ErrorV1(:solver_input_fields_missing, ()))
    materialized.solver_source_hash ==
        native_g1g2_inhouse_q1_source_hash_v1() ||
        throw(NativeG1G2InHouseQ1ErrorV1(:solver_source_hash_mismatch, ()))
    plan = _ng12ihq1_build_plan(materialized.compilation,
        materialized.compile_result_hash, materialized.protocol,
        materialized.solver_source_hash)
    plan.source_binding_hash == materialized.source_binding_hash ||
        throw(NativeG1G2InHouseQ1ErrorV1(:source_binding_hash_mismatch, ()))
    plan.solver_input.solver_input_hash == input.solver_input_hash ||
        throw(NativeG1G2InHouseQ1ErrorV1(:solver_input_hash_mismatch, ()))
    validate_native_g1g2_inhouse_q1_plan_v1(plan) ||
        throw(NativeG1G2InHouseQ1ErrorV1(:reconstructed_plan_invalid, ()))
    plan
end

function _ng12ihq1_provider_metrics(report::NativeG1G2InHouseQ1ReportV1)
    length_unit = _ng12_si_length_unit(1)
    l2_unit = _ng12_si_length_unit(3 // 2)
    h1_unit = _ng12_si_length_unit(1 // 2)
    (MetricWithUnit(:finest_l2_error, report.levels[3].l2_error, l2_unit),
        MetricWithUnit(:finest_h1_seminorm_error,
            report.levels[3].h1_seminorm_error, h1_unit),
        MetricWithUnit(:max_algebraic_residual,
            maximum(level.residual_abs for level in report.levels), length_unit),
        MetricWithUnit(:max_relative_algebraic_residual,
            maximum(level.residual_rel for level in report.levels)),
        MetricWithUnit(:max_source_integral_error,
            maximum(level.source_integral_error for level in report.levels),
            length_unit),
        MetricWithUnit(:max_interior_reaction_linf,
            maximum(level.discrete_interior_reaction_linf
                for level in report.levels), length_unit),
        MetricWithUnit(:max_boundary_reaction_balance_defect,
            maximum(abs(level.discrete_boundary_reaction_balance_defect)
                for level in report.levels), length_unit),
        MetricWithUnit(:max_pcg_iterations,
            Float64(maximum(level.pcg_iterations for level in report.levels))),
        MetricWithUnit(:assembly_cell_evaluations,
            Float64(sum(level.assembly_cell_evaluations
                for level in report.levels))),
        MetricWithUnit(:solver_calls, 3.0))
end

function _native_g1g2_inhouse_q1_provider_executor_v1(
        input::SolverInputV4)
    plan = _ng12ihq1_plan_from_solver_input(input)
    report = _ng12ihq1_series(plan)
    validate_native_g1g2_inhouse_q1_report_v1(plan, report) ||
        throw(NativeG1G2InHouseQ1ErrorV1(:provider_report_integrity_mismatch, ()))
    (report=report, metrics=_ng12ihq1_provider_metrics(report),
        stage_outcome=report.status === :pass ? pass : numerical_fail,
        uncertainty=nothing,
        artifacts=(report.report_hash,
            (level.level_hash for level in report.levels)...),
        provider_calls=1, assembly_calls=3, solver_calls=3,
        assembled_cells=sum(level.assembly_cell_evaluations
            for level in report.levels),
        quadrature_points=sum(level.assembly_quadrature_points
            for level in report.levels))
end

function _ng12ihq1_expected_runtime_evidence_v1(plan, report)
    status_vector = StatusVectorV4(required, unique_match, resolved,
        low_fidelity_evaluated,
        report.status === :pass ? pass : numerical_fail)
    binding = (candidate_ref=report.candidate_ref,
        t1_package_hash=report.t1_package_hash,
        source_binding_hash=report.source_binding_hash,
        plan_hash=plan.plan_hash, report_hash=report.report_hash,
        numerical_scope=report.numerical_scope,
        physical_status=report.physical_status)
    RuntimeEvidenceV4(plan.subject.physical_subject_hash,
        plan.solver_input.scenario_hash, plan.solver_input.solver_input_hash,
        plan.provider.manifest_hash, binding, status_vector,
        _ng12ihq1_provider_metrics(report); claim_ceiling=screen_only,
        independence_group=plan.provider.independence_group,
        provider_manifest=plan.provider,
        backend_revision=plan.provider.backend_revision,
        numerical_configuration_hash=plan.protocol.protocol_hash,
        artifact_refs=(report.report_hash,
            (level.level_hash for level in report.levels)...),
        uncertainty_or_null=nothing)
end

struct NativeG1G2InHouseQ1ExecutionBundleV1
    plan_hash::Digest256
    solver_input_hash::Digest256
    report::NativeG1G2InHouseQ1ReportV1
    evidence::RuntimeEvidenceV4
    invocation_counts::NamedTuple
    formal_t2_consumer_receipts::Int
    bundle_hash::Digest256
end

function _ng12ihq1_execution_body(plan_hash, solver_input_hash, report,
        evidence, invocation_counts, formal_t2_consumer_receipts)
    (domain="native-g1g2-inhouse-q1-execution-bundle-v1",
        plan_hash=plan_hash, solver_input_hash=solver_input_hash,
        report=report, evidence=evidence,
        invocation_counts=invocation_counts,
        formal_t2_consumer_receipts=formal_t2_consumer_receipts)
end

semantic_view(bundle::NativeG1G2InHouseQ1ExecutionBundleV1) = merge(
    _ng12ihq1_execution_body(bundle.plan_hash, bundle.solver_input_hash,
        bundle.report, bundle.evidence, bundle.invocation_counts,
        bundle.formal_t2_consumer_receipts),
    (bundle_hash=bundle.bundle_hash,))
canonical_hash(bundle::NativeG1G2InHouseQ1ExecutionBundleV1) =
    bundle.bundle_hash

function execute_native_g1g2_inhouse_q1_once!(store,
        plan::NativeG1G2InHouseQ1PlanV1)
    store isa AbstractDict || throw(ArgumentError("execution store must be a dictionary"))
    validate_native_g1g2_inhouse_q1_plan_v1(plan) ||
        throw(NativeG1G2InHouseQ1ErrorV1(:plan_integrity_mismatch, ()))
    key = plan.solver_input.solver_input_hash
    if haskey(store, key)
        cached = store[key]
        cached isa NativeG1G2InHouseQ1ExecutionBundleV1 ||
            throw(NativeG1G2InHouseQ1ErrorV1(
                :cached_execution_bundle_type_mismatch, ()))
        validate_native_g1g2_inhouse_q1_execution_bundle_v1(plan, cached) ||
            throw(NativeG1G2InHouseQ1ErrorV1(
                :cached_execution_bundle_integrity_mismatch, ()))
        return cached
    end
    raw = plan.provider.executor(plan.solver_input)
    report = raw.report
    validate_native_g1g2_inhouse_q1_report_v1(plan, report) ||
        throw(NativeG1G2InHouseQ1ErrorV1(:report_integrity_mismatch, ()))
    raw.metrics == _ng12ihq1_provider_metrics(report) ||
        throw(NativeG1G2InHouseQ1ErrorV1(:provider_metrics_mismatch, ()))
    expected_artifacts = (report.report_hash,
        (level.level_hash for level in report.levels)...)
    raw.artifacts == expected_artifacts ||
        throw(NativeG1G2InHouseQ1ErrorV1(:provider_artifacts_mismatch, ()))
    evidence = _ng12ihq1_expected_runtime_evidence_v1(plan, report)
    counts = (provider_calls=raw.provider_calls,
        assembly_calls=raw.assembly_calls,
        solver_calls=raw.solver_calls,
        assembled_cells=raw.assembled_cells,
        quadrature_points=raw.quadrature_points,
        pcg_iterations=Tuple(level.pcg_iterations for level in report.levels),
        formal_t2_consumer_receipts=0)
    body = _ng12ihq1_execution_body(plan.plan_hash, key, report, evidence,
        counts, 0)
    bundle = NativeG1G2InHouseQ1ExecutionBundleV1(plan.plan_hash, key,
        report, evidence, counts, 0, canonical_hash(body))
    validate_native_g1g2_inhouse_q1_execution_bundle_v1(plan, bundle) ||
        throw(NativeG1G2InHouseQ1ErrorV1(
            :execution_bundle_integrity_mismatch, ()))
    store[key] = bundle
    bundle
end

function validate_native_g1g2_inhouse_q1_execution_bundle_v1(plan,
        bundle::NativeG1G2InHouseQ1ExecutionBundleV1)
    try
        validate_native_g1g2_inhouse_q1_plan_v1(plan) || return false
        validate_native_g1g2_inhouse_q1_report_v1(plan, bundle.report) ||
            return false
        bundle.plan_hash == plan.plan_hash || return false
        bundle.solver_input_hash == plan.solver_input.solver_input_hash ||
            return false
        bundle.invocation_counts == (provider_calls=1, assembly_calls=3,
            solver_calls=3,
            assembled_cells=sum(level.assembly_cell_evaluations
                for level in bundle.report.levels),
            quadrature_points=sum(level.assembly_quadrature_points
                for level in bundle.report.levels),
            pcg_iterations=Tuple(level.pcg_iterations
                for level in bundle.report.levels),
            formal_t2_consumer_receipts=0) || return false
        bundle.formal_t2_consumer_receipts == 0 || return false
        bundle.evidence.solver_input_hash == bundle.solver_input_hash ||
            return false
        canonical_json(bundle.evidence) == canonical_json(
            _ng12ihq1_expected_runtime_evidence_v1(plan, bundle.report)) ||
            return false
        canonical_hash(_ng12ihq1_execution_body(bundle.plan_hash,
            bundle.solver_input_hash, bundle.report, bundle.evidence,
            bundle.invocation_counts,
            bundle.formal_t2_consumer_receipts)) == bundle.bundle_hash
    catch
        false
    end
end
