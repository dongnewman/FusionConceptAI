using Test
push!(LOAD_PATH, dirname(@__DIR__))
using FusionConceptAI
using Gridap

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_gridap_field_fixture.jl"))

const GRIDAP_NATIVE_ASSEMBLER_CALLS = Ref(0)
@eval FusionRuntimeV4 begin
    function assemble_field_residual_kernel(form::LinearFieldResidualFormV4,
            geometry::DiagonalAffineChartGeometryV4, grid,
            source_payloads::Tuple,
            boundary_payload::FieldResidualPayloadV4,
            protocol::StructuredGridProtocolV4)
        Main.GRIDAP_NATIVE_ASSEMBLER_CALLS[] += 1
        error("native assembler poison sentinel was called")
    end
end

function _gridap_b1_recompile(; scenario=d3_g2_scenario,
        u_report=gridap_b1_reports[1], f_report=gridap_b1_reports[2],
        affine_factors=(-1, 1, 1),
        affine_offsets=(1 // 4, -1 // 2, 2 // 3))
    FusionRuntimeV4.compile_gridap_field_residual_plan(
        composition_candidate, composition_compiled, tdae_registry,
        gridap_b1_operator_registry, u_report, f_report;
        scenario=scenario, grid=gridap_b1_grid,
        constraint_edge_hash=canonical_hash(composition_constraint),
        unknown_state_ref=StateGeneRefV1("u"),
        source_state_ref=StateGeneRefV1("f"),
        residual_state_ref=StateGeneRefV1("r"),
        affine_factors=affine_factors, affine_offsets=affine_offsets,
        native_protocol=gridap_b1_protocol)
end

function _contains_forbidden_symbol(value, forbidden)
    value isa Symbol && return value in forbidden
    value isa QuoteNode && return _contains_forbidden_symbol(value.value, forbidden)
    value isa Expr || return false
    any(arg -> _contains_forbidden_symbol(arg, forbidden), value.args)
end

@testset "B1 candidate-bound independent Gridap kernel" begin
    compilation = _gridap_b1_recompile()
    report = FusionRuntimeV4.run_gridap_field_residual(compilation)
    result = report.result
    receipt = report.receipt

    @test report.status === :pass
    @test result.status === :pass
    @test result.factorization_status === :success
    @test result.weak_form_sign === :declared
    @test result.finite_values
    @test receipt.cell_counts == (4, 4, 4)
    @test receipt.cells == 64
    @test receipt.free_dofs == 27
    @test receipt.dirichlet_dofs == 98
    @test receipt.matrix_shape == (27, 27)
    @test receipt.matrix_nnz > receipt.free_dofs
    @test all(isapprox.(receipt.physical_domain,
        (-0.75, 1.25, -1.5, 0.5, -1 / 3, 5 / 3);
        atol=8eps(Float64), rtol=0))
    @test length(result.free_dof_values) == receipt.free_dofs
    @test length(result.physical_samples) == 125
    @test result.residual_abs <= compilation.plan.protocol.residual_abs_tol ||
        result.residual_rel <= compilation.plan.protocol.residual_rel_tol
    @test result.boundary_mismatch <= compilation.plan.protocol.boundary_abs_tol
    @test result.manufactured_node_linf_error <=
        compilation.plan.protocol.manufactured_node_abs_tol

    @test report.evidence_class === :manufactured_control
    @test report.claim_ceiling === screen_only
    @test report.numerical_vvuq_status === :terminal_deferred
    @test report.credible_physical_candidate_count == 0
    @test !report.p5_ready
    @test !report.unsupported_emitted
    @test FusionRuntimeV4.validate_gridap_field_residual_report(compilation, report)
    @test FusionRuntimeV4.replay_gridap_field_residual(compilation, report)

    plan = compilation.plan
    @test plan.native_plan_hash == plan.native_plan.plan_hash
    @test plan.candidate_hash == composition_candidate.canonical_hashes.genome_bundle_hash
    @test plan.prefix_hash == composition_compiled.prefix_hash
    @test plan.grid_hash == gridap_b1_grid.grid_hash
    @test plan.u_plan_hash == gridap_b1_reports[1].plan.plan_hash
    @test plan.f_plan_hash == gridap_b1_reports[2].plan.plan_hash
    @test plan.u_result_hash == gridap_b1_reports[1].result.result_hash
    @test plan.f_result_hash == gridap_b1_reports[2].result.result_hash
    @test plan.u_evidence_id == gridap_b1_reports[1].evidence.evidence_id
    @test plan.f_evidence_id == gridap_b1_reports[2].evidence.evidence_id
    @test compilation.source.content_hash == plan.source_content_hash
    @test compilation.boundary.content_hash == plan.boundary_content_hash
    @test receipt.form_hash == plan.form_hash
    @test receipt.geometry_hash == plan.geometry_hash
    @test receipt.source_content_hash == plan.source_content_hash
    @test receipt.boundary_content_hash == plan.boundary_content_hash
    @test receipt.protocol_hash == plan.protocol.protocol_hash
    @test result.receipt_hash == receipt.assembly_hash

    probe_q = (0.2, -0.35, 0.6)
    probe_x = FusionRuntimeV4._gridap_chart_to_physical(
        plan.native_plan.geometry, probe_q)
    @test all(isapprox.(probe_x, (0.05, -0.85, 19 / 15);
        atol=8eps(Float64), rtol=0))
    @test probe_x[1] < FusionRuntimeV4._gridap_chart_to_physical(
        plan.native_plan.geometry, (-0.2, -0.35, 0.6))[1]
    @test all(isapprox.(FusionRuntimeV4._gridap_physical_to_chart(
        plan.native_plan.geometry, probe_x), probe_q;
        atol=8eps(Float64), rtol=0))

    dependency = plan.dependency_identity
    @test dependency.julia_version == "1.10.5"
    @test dependency.platform == "x86_64-w64-mingw32"
    @test dependency.gridap_uuid == "56d4f2e9-7ea1-5844-9cf6-b9c51ca7ce8e"
    @test dependency.gridap_version == "0.20.8"
    @test dependency.gridap_tree == "95fd6ec47697c8f031398434a119abe747330715"
    @test FusionRuntimeV4._gridap_dependency_integrity(dependency)

    wrong = FusionRuntimeV4.run_gridap_field_residual(compilation;
        weak_form_sign=:reversed_test_control)
    @test wrong.status === :numerical_fail
    @test wrong.result.status === :numerical_fail
    @test wrong.result.factorization_status === :success
    @test wrong.result.weak_form_sign === :reversed_test_control
    @test wrong.result.residual_abs <= compilation.plan.protocol.residual_abs_tol ||
        wrong.result.residual_rel <= compilation.plan.protocol.residual_rel_tol
    @test wrong.result.manufactured_node_linf_error >
        result.manufactured_node_linf_error
    @test FusionRuntimeV4.validate_gridap_field_residual_report(compilation, wrong)

    nonunit = _gridap_b1_recompile(affine_factors=(-1, 2, 1))
    nonunit_report = FusionRuntimeV4.run_gridap_field_residual(nonunit)
    @test nonunit_report.status === :numerical_fail
    @test nonunit_report.result.manufactured_node_linf_error >
        result.manufactured_node_linf_error

    @test GRIDAP_NATIVE_ASSEMBLER_CALLS[] == 0
end

@testset "B1 fails closed on foreign inputs and lock bytes" begin
    @test_throws ArgumentError _gridap_b1_recompile(
        scenario=(name="foreign-gridap-scenario",))
    @test_throws ArgumentError _gridap_b1_recompile(
        u_report=gridap_b1_reports[2], f_report=gridap_b1_reports[1])
    @test_throws ArgumentError FusionRuntimeV4.GridapFieldProtocolV4(
        quadrature_degree=2)
    @test_throws ArgumentError FusionRuntimeV4.GridapFieldProtocolV4(
        manufactured_node_abs_tol=Inf)
    @test_throws ArgumentError FusionRuntimeV4.GridapFieldProtocolV4(
        manufactured_node_abs_tol=1.0)
    @test_throws ArgumentError FusionRuntimeV4.run_gridap_field_residual(
        gridap_b1_compilation; weak_form_sign=:caller_selected_sign)

    mktempdir() do root
        cp(joinpath(@__DIR__, "..", "tools", "qualification", "gridap",
            "Project.toml"), joinpath(root, "Project.toml"))
        cp(joinpath(@__DIR__, "..", "tools", "qualification", "gridap",
            "Manifest.toml"), joinpath(root, "Manifest.toml"))
        open(joinpath(root, "Project.toml"), "a") do io
            write(io, "\n# changed-lock-byte\n")
        end
        @test_throws ArgumentError FusionRuntimeV4._gridap_dependency_identity(
            root; verify_active=false)
    end

    report = FusionRuntimeV4.run_gridap_field_residual(gridap_b1_compilation)
    forged = FusionRuntimeV4.GridapFieldResidualReportV4(
        FusionRuntimeV4._GRIDAP_FIELD_TOKEN, report.status, report.plan_hash,
        report.receipt, report.result, report.evidence_class, candidate_bound,
        report.numerical_vvuq_status, 1, true, report.unsupported_emitted,
        report.report_hash)
    @test !FusionRuntimeV4.validate_gridap_field_residual_report(
        gridap_b1_compilation, forged)
end

@testset "B1 adapter has no native or legacy assembly dependency" begin
    source_path = joinpath(@__DIR__, "..", "src", "RuntimeV4",
        "GridapFieldResidualAdapter.jl")
    source = read(source_path, String)
    syntax = Meta.parseall(source)
    forbidden = Set((:assemble_field_residual, :assemble_field_residual_kernel,
        :_fr_matrix, :ResidualAssemblyV4, :FieldSolveResultV4))
    @test !_contains_forbidden_symbol(syntax, forbidden)
    @test !occursin("outputs/fusion_concept_ai", source)
    @test !occursin("candidate_id", source)
    @test !occursin("device_family", source)
    @test GRIDAP_NATIVE_ASSEMBLER_CALLS[] == 0
end
