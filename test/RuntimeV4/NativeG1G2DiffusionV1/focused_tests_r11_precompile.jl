const NG12_TEST_EPOCH_NS = time_ns()

function ng12_diagnostic_value(f)
    try
        string(f())
    catch error
        "unsupported:" * string(typeof(error))
    end
end

function ng12_stage(label::AbstractString; detail="")
    elapsed_ms = div(time_ns() - NG12_TEST_EPOCH_NS, 1_000_000)
    suffix = isempty(detail) ? "" : " detail=" * detail
    println("NG12_STAGE stage=", label, " elapsed_ms=", elapsed_ms,
        " gc_live_bytes=", ng12_diagnostic_value(Base.gc_live_bytes),
        " jit_total_bytes=", ng12_diagnostic_value(Base.jit_total_bytes),
        " process_maxrss_bytes=", ng12_diagnostic_value(Sys.maxrss),
        " gc_time_ns=", ng12_diagnostic_value(Base.gc_time_ns), suffix)
    flush(stdout)
end

ng12_stage("entry.before_imports";
    detail="julia_version=" * string(VERSION) *
        ",active_project=" * ng12_diagnostic_value(Base.active_project) *
        ",load_path=" * join(LOAD_PATH, "|") *
        ",heap_size_hint_bytes=" *
            ng12_diagnostic_value(() -> Base.JLOptions().heap_size_hint))

using Test
ng12_stage("entry.after_using_test")
using SHA
ng12_stage("entry.after_using_sha")
using Serialization
ng12_stage("entry.after_using_serialization")

ng12_stage("entry.before_fixture_include")
include(joinpath(@__DIR__, "fixture_and_oracle.jl"))
ng12_stage("entry.after_fixture_include")

function ng12_expect_code(f, text)
    try
        f()
        false
    catch error
        occursin(text, sprint(showerror, error))
    end
end

function ng12_rehashed_report(report; levels=report.levels,
        candidate_ref=report.candidate_ref, gaps=report.gaps,
        errors=report.errors, status=report.status)
    l2_orders = NG12_R._ng12_orders(ntuple(i -> levels[i].l2_error, 3))
    h1_orders = NG12_R._ng12_orders(
        ntuple(i -> levels[i].h1_seminorm_error, 3))
    args = (candidate_ref, report.t1_package_hash, report.plan_hash,
        report.solver_input_hash, report.protocol_hash, levels, l2_orders,
        h1_orders, status, report.resolution, report.accepted,
        report.claim_ceiling, report.numerical_scope,
        report.physical_status, errors, gaps)
    NG12_R.NativeG1G2GridapReportV1(args...,
        NG12_G.canonical_hash(NG12_R._ng12_report_body(args...)))
end

function ng12_rehashed_level(level;
        analytic_source_integral=level.analytic_source_integral,
        analytic_outward_conormal_integral=
            level.analytic_outward_conormal_integral,
        assembled_source_integral=level.assembled_source_integral)
    source_integral_error = abs(assembled_source_integral -
        analytic_source_integral)
    analytic_identity_defect = analytic_source_integral +
        analytic_outward_conormal_integral
    args = (level.level, level.cell_counts, level.physical_domain,
        level.cells, level.free_dofs, level.dirichlet_dofs,
        level.matrix_shape, level.matrix_nnz, level.matrix_hash,
        level.rhs_hash, level.solution_hash, level.residual_abs,
        level.residual_rel, level.l2_error, level.h1_seminorm_error,
        level.boundary_linf, assembled_source_integral,
        analytic_source_integral, source_integral_error,
        analytic_outward_conormal_integral, analytic_identity_defect,
        level.discrete_trace_conormal_integral,
        abs(level.discrete_trace_conormal_integral -
            analytic_outward_conormal_integral),
        level.dof_partition_hash,
        level.discrete_interior_reaction_linf,
        level.discrete_interior_reaction_sum,
        level.discrete_interior_residual_match_linf,
        level.discrete_boundary_reaction_integral,
        assembled_source_integral +
            level.discrete_boundary_reaction_integral,
        level.source_sign, level.status)
    NG12_R.NativeG1G2GridapLevelResultV1(args...,
        NG12_G.canonical_hash(NG12_R._ng12_level_body(args...)))
end

function ng12_primary(artifact_path::AbstractString)
    ng12_stage("primary.fixture.begin")
    fixture = ng12_compiled_fixture()
    chain = fixture.chain
    compilation = fixture.compile_result.compilation
    form = compilation.form
    plan = fixture.plan
    ng12_stage("primary.fixture.complete";
        detail="package=" * chain.admission.package.package_hash.value)

    @testset "native source and formal T1 carrier" begin
        @test chain.admission.status === :prepared_not_executed
        @test chain.admission.resolution === :terminal_deferred
        @test !chain.admission.accepted
        @test chain.admission.claim_ceiling === :contract_only
        @test isempty(chain.admission.errors)
        @test chain.admission.package isa NG12_G.CandidateStatePackageV5NextV2
        @test chain.admission.package.candidate_ref == NG12_CANDIDATE
        @test chain.witness_build.source_ready
        @test chain.witness_build.status === :source_ready
        @test NG12_G.validate_vnext_t2_concrete_source_witness_v3(
            chain.witness, chain.transport, chain.recheck_v1, chain.parent,
            chain.expected, chain.bridge, chain.realization,
            chain.control_payload, chain.control_state, chain.binding_key)
        @test chain.witness.candidate_ref == chain.admission.package.candidate_ref
        @test fixture.compile_result.status === :compiled_numerical_preparation
        @test fixture.compile_result.resolution === :terminal_deferred
        @test !fixture.compile_result.accepted
        @test fixture.compile_result.claim_ceiling === :contract_only
        @test isempty(fixture.compile_result.errors)
        @test :formal_t2_receipt_ledger_required in fixture.compile_result.gaps
        @test :g3_material_conversion_missing in fixture.compile_result.gaps
        @test :g3_two_region_interface_missing in fixture.compile_result.gaps
        @test NG12_R.validate_native_g1g2_diffusion_compilation_v1(compilation)

        expected_unknown = NG12_G.canonical_json(
            NG12_R._ng12_unknown_expression_body(chain.programs.unknown_program,
                chain.programs.reference_program, chain.programs.parameters,
                chain.profile.profile_hash))
        expected_source = NG12_G.canonical_json(
            NG12_R._ng12_source_expression_body(chain.programs.source_program,
                chain.programs.parameters, chain.profile.profile_hash))
        @test chain.g1.u.source_expression == expected_unknown
        @test chain.g1.f.source_expression == expected_source
        @test chain.g1.source_payload.u.source_expression == expected_unknown
        @test chain.g1.source_payload.f.source_expression == expected_source
        @test chain.g1.source_hash ==
            NG12_G.g1_diffusion_source_hash_v1(chain.g1.source_payload)
        g1_manifest = only(d for d in chain.admission.package.declarations
            if d.layer === :G1)
        g2_manifest = only(d for d in chain.admission.package.declarations
            if d.layer === :G2)
        @test NG12_G.copy_bytes(g1_manifest.declaration_bytes) ==
            Vector{UInt8}(codeunits(NG12_G.canonical_json(chain.g1)))
        @test NG12_G.copy_bytes(g2_manifest.declaration_bytes) ==
            Vector{UInt8}(codeunits(NG12_G.canonical_json(chain.g2)))
        @test isempty(NG12_R.native_g1g2_t1_binding_errors_v1(
            chain.admission, chain.g1, chain.g2))
        @test isempty(NG12_R.native_g1g2_physics_errors_v1(
            chain.g1, chain.g2, chain.programs, chain.profile))

        residual = chain.programs.residual_program
        operator_ids = Tuple(node isa NG12_G.ASTApplyV1 ?
            node.operator_ref.qualified.id : "" for node in residual.nodes)
        @test operator_ids[4:8] == ("GRAD",
            NG12_R.NATIVE_G1G2_K_APPLY_OPERATOR_V1,
            "DIV_OP", "NEG", "SUB")
        @test Tuple(residual.nodes[i].inputs for i in 4:8) ==
            ((1,), (2, 4), (5,), (6,), (7, 3))
        @test NG12_R.native_g1g2_translate_unit_v1(chain.profile,
            ng12_native_length(1)) == NG12_R._ng12_si_length_unit(1)
        @test NG12_R.native_g1g2_translate_unit_v1(chain.profile,
            NG12_G.UnitSignature()) == NG12_G.UnitSignature()
        @test ng12_expect_code(() -> NG12_R.native_g1g2_translate_unit_v1(
            chain.profile, ng12_native_unit((0, 0, 0, 0, 0, 0, 1))),
            "undocumented non-length axis")
        @test ng12_expect_code(() ->
            NG12_R.native_g1g2_unit_compatibility_profile_v1(
                length_scale_metres=2 // 1), "one-metre")
        @test ng12_expect_code(() ->
            NG12_R.native_g1g2_unit_compatibility_profile_v1(
                source_basis="RuntimeV4/SI-kg-m-s-A-K-mol-cd-v1"),
            "native length-first basis")
        @test form.t1_package === chain.admission.package
    end
    ng12_stage("primary.source_t1.complete")

    @testset "compile boundary negatives" begin
        bad_source = ng12_g1_declaration(chain.candidate, chain.programs;
            source_expression="f_candidate(x)=1")
        @test :g1_source_payload_mismatch in
            NG12_R.native_g1g2_physics_errors_v1(bad_source, chain.g2,
                chain.programs, chain.profile)

        short_k = ng12_g1_declaration(chain.candidate, chain.programs;
            domain_min=(0, 0, 0), domain_max=(1, 1, 1))
        @test :k_domain_does_not_cover_physical_chart in
            NG12_R.native_g1g2_physics_errors_v1(short_k, chain.g2,
                chain.programs, chain.profile)

        mixed = ng12_g2_declaration(all_zero_dirichlet=false)
        @test :boundary_not_all_zero_dirichlet in
            NG12_R.native_g1g2_physics_errors_v1(chain.g1, mixed,
                chain.programs, chain.profile)

        wrong_units = ng12_g2_declaration(
            field_unit=ng12_native_unit((0, 0, 0, 0, 0, 0, 1)),
            flux_unit=ng12_native_unit((0, 0, 0, 0, 0, 1, 0)))
        wrong_unit_errors = NG12_R.native_g1g2_physics_errors_v1(chain.g1,
            wrong_units, chain.programs, chain.profile)
        @test :g1_g2_field_unit_mismatch in wrong_unit_errors
        @test :g1_g2_flux_unit_mismatch in wrong_unit_errors
        @test :unit_basis_translation_rejected in wrong_unit_errors

        shear = ng12_g2_declaration(
            chart_rows=((2, 1 // 10, 0), (0, 3, 0), (0, 0, 4)))
        @test :unsupported_non_diagonal_or_reversing_chart in
            NG12_R.native_g1g2_physics_errors_v1(chain.g1, shear,
                chain.programs, chain.profile)

        old_errors = NG12_R.native_g1g2_physics_errors_v1(
            Main._t0l_g1(chain.candidate),
            Main._t0l_g2(chain.candidate), chain.programs, chain.profile)
        @test :g1_unknown_reference_payload_mismatch in old_errors
        @test :g1_source_payload_mismatch in old_errors
        @test :k_domain_does_not_cover_physical_chart in old_errors
        @test :boundary_not_all_zero_dirichlet in old_errors
        @test :g1_g2_field_unit_mismatch in old_errors

        foreign = ng12_source_chain(candidate=NG12_FOREIGN_CANDIDATE,
            qualify_witness=false)
        foreign_compile = NG12_R.compile_native_g1g2_diffusion_v1(
            foreign.admission, chain.g1, chain.g2, chain.programs,
            chain.profile)
        @test foreign_compile.status === :fail_closed
        @test foreign_compile.compilation === nothing
        @test :t1_candidate_g1_mismatch in foreign_compile.errors
        @test :t1_g1_declaration_carrier_mismatch in foreign_compile.errors
        @test :t1_g2_declaration_carrier_mismatch in foreign_compile.errors

        alternative_programs = ng12_alternative_source_program_bundle(
            chain.profile, chain.programs)
        alternative_chain = ng12_source_chain(
            profile_programs=(profile=chain.profile,
                programs=alternative_programs), qualify_witness=false)
        @test alternative_chain.admission.status === :prepared_not_executed
        alternative_errors = NG12_R.native_g1g2_physics_errors_v1(
            alternative_chain.g1, alternative_chain.g2,
            alternative_programs, chain.profile)
        @test :program_semantic_projection_mismatch in alternative_errors
        alternative_compile = NG12_R.compile_native_g1g2_diffusion_v1(
            alternative_chain.admission, alternative_chain.g1,
            alternative_chain.g2, alternative_programs, chain.profile)
        @test alternative_compile.status === :fail_closed
        @test alternative_compile.compilation === nothing

        altered_mesh_chain = ng12_source_chain(
            g2_declaration=ng12_g2_declaration(cells=(3, 3, 4)),
            qualify_witness=false)
        altered_mesh_compile = NG12_R.compile_native_g1g2_diffusion_v1(
            altered_mesh_chain.admission, altered_mesh_chain.g1,
            altered_mesh_chain.g2, altered_mesh_chain.programs,
            altered_mesh_chain.profile)
        @test altered_mesh_compile.status === :compiled_numerical_preparation
        @test ng12_expect_code(() ->
            NG12_R.prepare_gridap_native_g1g2_diffusion_v1(
                altered_mesh_compile, fixture.protocol),
            "error budget does not apply")

        altered_k_programs = NG12_R.native_g1g2_program_bundle_v1(
            chain.profile; physical_lower=NG12_PHYSICAL_LOWER,
            physical_upper=NG12_PHYSICAL_UPPER,
            k_base=(3 // 1, 3 // 1, 4 // 1), k_slope=NG12_K_SLOPE)
        altered_k_chain = ng12_source_chain(
            profile_programs=(profile=chain.profile,
                programs=altered_k_programs), qualify_witness=false)
        altered_k_compile = NG12_R.compile_native_g1g2_diffusion_v1(
            altered_k_chain.admission, altered_k_chain.g1,
            altered_k_chain.g2, altered_k_programs, chain.profile)
        @test altered_k_compile.status === :compiled_numerical_preparation
        @test isempty(altered_k_compile.errors)
        @test ng12_expect_code(() ->
            NG12_R.prepare_gridap_native_g1g2_diffusion_v1(
                altered_k_compile, fixture.protocol),
            "error budget does not apply")

        forged_form_body = NG12_R._ng12_form_body(NG12_FOREIGN_CANDIDATE,
            form.t1_package, form.t1_package_hash,
            form.t1_semantic_identity, form.t0_bundle_hash,
            form.g1_declaration, form.g2_declaration, form.programs,
            form.unit_profile, form.weak_form_sign,
            form.coordinate_semantics, form.boundary_semantics)
        forged_form = NG12_R.NativeG1G2VariableDiffusionFormV1(
            NG12_FOREIGN_CANDIDATE, form.t1_package, form.t1_package_hash,
            form.t1_semantic_identity, form.t0_bundle_hash,
            form.g1_declaration, form.g2_declaration, form.programs,
            form.unit_profile, form.weak_form_sign,
            form.coordinate_semantics, form.boundary_semantics,
            NG12_G.canonical_hash(forged_form_body))
        @test !NG12_R._ng12_form_integrity(forged_form)
    end
    ng12_stage("primary.negatives.complete")

    @testset "independent analytic oracle" begin
        points = ((3 / 4, 7 / 6, 5 / 4),
            (3 / 2, 11 / 6, 9 / 4),
            (9 / 4, 17 / 6, 15 / 4))
        for point in points
            @test isapprox(NG12_R.native_g1g2_reference_value_v1(form, point),
                ng12_oracle_reference(point); atol=2e-15, rtol=2e-15)
            @test all(isapprox.(
                NG12_R.native_g1g2_reference_gradient_v1(form, point),
                ng12_oracle_gradient(point); atol=2e-15, rtol=2e-15))
            @test all(isapprox.(NG12_R.native_g1g2_k_diagonal_v1(form, point),
                ng12_oracle_k(point); atol=2e-15, rtol=2e-15))
            @test isapprox(NG12_R.native_g1g2_source_value_v1(form, point),
                ng12_oracle_source(point); atol=2e-15, rtol=2e-15)
        end
        derivative_point = points[1]
        @test abs(ng12_oracle_source(derivative_point) -
            ng12_oracle_source_without_grad_k(derivative_point)) > 1e-6
        balance = NG12_R.native_g1g2_continuous_balance_v1(form)
        independent_balance = ng12_oracle_continuous_balance()
        @test isapprox(balance.source_integral,
            independent_balance.source_integral; atol=2e-15, rtol=2e-15)
        @test isapprox(balance.outward_conormal_integral,
            independent_balance.outward_conormal_integral;
            atol=2e-15, rtol=2e-15)
        @test independent_balance.defect == 0.0
        for axis in 1:3, side in 0:1
            point = ntuple(i -> i == axis ?
                Float64(side == 0 ? NG12_PHYSICAL_LOWER[i] :
                    NG12_PHYSICAL_UPPER[i]) :
                (Float64(NG12_PHYSICAL_LOWER[i]) +
                    Float64(NG12_PHYSICAL_UPPER[i])) / 2, 3)
            @test ng12_oracle_reference(point) == 0.0
        end
    end
    ng12_stage("primary.oracle.complete")

    @testset "provider plan and immutable protocol" begin
        @test NG12_R.validate_native_g1g2_gridap_plan_v1(plan)
        @test plan.subject.materialized_payload.compile_result_hash ==
            fixture.compile_result.result_hash
        @test plan.provider.executor ===
            NG12_R._native_g1g2_gridap_provider_executor_v1
        @test !isdefined(NG12_R, :_NG12_ACTIVE_PROVIDER_PLAN)
        @test plan.protocol.cell_counts == ((2, 3, 4), (4, 6, 8),
            (8, 12, 16))
        @test plan.protocol.quadrature_degree == 8
        @test plan.protocol.residual_abs_tol == 1e-9
        @test plan.protocol.residual_rel_tol == 1e-11
        @test plan.protocol.boundary_abs_tol == 1e-10
        @test plan.protocol.source_integral_abs_tol == 1e-10
        @test plan.protocol.analytic_identity_abs_tol == 1e-12
        @test plan.protocol.reaction_balance_abs_tol == 1e-9
        @test plan.protocol.l2_order_interval == (1.4, 2.6)
        @test plan.protocol.h1_order_interval == (0.6, 1.4)
        @test plan.protocol.finest_l2_max == 5e-3
        @test plan.protocol.finest_h1_seminorm_max == 1e-2
        budget = plan.protocol.budget_basis
        @test budget == NG12_R.native_g1g2_error_budget_basis_v1()
        @test budget.physical_lower_metres == NG12_PHYSICAL_LOWER
        @test budget.physical_upper_metres == NG12_PHYSICAL_UPPER
        @test budget.physical_lengths_metres == NG12_PHYSICAL_LENGTHS
        @test budget.k_base == NG12_K_BASE
        @test budget.k_slope == NG12_K_SLOPE
        @test budget.poincare_finest_l2_bound_m32 <
            plan.protocol.finest_l2_max
        @test budget.cea_finest_h1_bound_m12 <
            plan.protocol.finest_h1_seminorm_max
        @test budget.gridap_quadrature_degree ==
            plan.protocol.quadrature_degree
        @test plan.protocol.cell_counts[1] == chain.g2.source.mesh.cells
        @test plan.provider.domain.declared_g2_quadrature_role ===
            :identity_bound_geometry_metadata_not_execution_rule
        @test plan.subject.materialized_payload.formal_t2_receipt_assignment ===
            false
    end
    ng12_stage("primary.plan.complete")

    ng12_stage("primary.solve.begin")
    store = Dict{Any,Any}()
    bundle = NG12_R.execute_native_g1g2_gridap_once!(store, plan)
    cached = NG12_R.execute_native_g1g2_gridap_once!(store, plan)
    ng12_stage("primary.solve.complete";
        detail="report=" * bundle.report.report_hash.value)
    checkpoint_path = artifact_path * ".preassert.bin"
    ispath(checkpoint_path) && error("pre-assert checkpoint already exists")
    mkpath(dirname(checkpoint_path))
    open(checkpoint_path, "w") do io
        Serialization.serialize(io,
            (schema="native-g1g2-preassert-checkpoint-v1",
                plan_hash=plan.plan_hash, bundle=bundle,
                preparation_counts=fixture.preparation_counts,
                numerical_counts=bundle.invocation_counts))
    end
    checkpoint_sha = bytes2hex(SHA.sha256(read(checkpoint_path)))
    ng12_stage("primary.preassert_checkpoint.complete";
        detail="sha256=" * checkpoint_sha)
    ng12_stage("primary.wrong_sign.begin")
    reversed = NG12_R.run_native_g1g2_wrong_sign_control_v1(plan; level=2)
    ng12_stage("primary.wrong_sign.complete";
        detail="level=" * reversed.level_hash.value)
    wrong_sign_checkpoint_path = artifact_path *
        ".wrong-sign-preassert.bin"
    ispath(wrong_sign_checkpoint_path) &&
        error("wrong-sign pre-assert checkpoint already exists")
    open(wrong_sign_checkpoint_path, "w") do io
        Serialization.serialize(io,
            (schema="native-g1g2-wrong-sign-preassert-checkpoint-v1",
                plan_hash=plan.plan_hash, wrong_sign_level=reversed))
    end
    wrong_sign_checkpoint_sha = bytes2hex(
        SHA.sha256(read(wrong_sign_checkpoint_path)))
    ng12_stage("primary.wrong_sign_checkpoint.complete";
        detail="sha256=" * wrong_sign_checkpoint_sha)

    @testset "actual Gridap solve and adversarial receipts" begin
        @test length(store) == 1
        @test cached.bundle_hash == bundle.bundle_hash
        @test NG12_R.validate_native_g1g2_execution_bundle_v1(plan, bundle)
        report = bundle.report
        @test NG12_R.validate_native_g1g2_gridap_report_v1(plan, report)
        @test report.status === :pass
        @test report.resolution === :terminal_deferred
        @test !report.accepted
        @test report.claim_ceiling == NG12_G.screen_only
        @test report.physical_status === :unknown
        @test isempty(report.errors)
        @test all(level.status === :pass for level in report.levels)
        @test all(level.source_sign === :declared for level in report.levels)
        @test all(level.residual_abs <= plan.protocol.residual_abs_tol ||
            level.residual_rel <= plan.protocol.residual_rel_tol
            for level in report.levels)
        @test all(level.boundary_linf <= plan.protocol.boundary_abs_tol
            for level in report.levels)
        @test all(level.source_integral_error <=
            plan.protocol.source_integral_abs_tol for level in report.levels)
        @test all(abs(level.analytic_identity_defect) <=
            plan.protocol.analytic_identity_abs_tol
            for level in report.levels)
        @test all(level.discrete_interior_reaction_linf <=
            plan.protocol.residual_abs_tol for level in report.levels)
        @test all(level.discrete_interior_residual_match_linf <=
            plan.protocol.residual_abs_tol for level in report.levels)
        @test all(level.free_dofs + level.dirichlet_dofs ==
            prod(level.cell_counts .+ 1) for level in report.levels)
        @test all(abs(level.discrete_boundary_reaction_balance_defect) <=
            plan.protocol.reaction_balance_abs_tol for level in report.levels)
        @test all(isapprox(level.discrete_boundary_reaction_balance_defect,
            -level.discrete_interior_reaction_sum;
            atol=plan.protocol.reaction_balance_abs_tol, rtol=0.0)
            for level in report.levels)
        @test all(report.levels[i].discrete_trace_conormal_error >
            report.levels[i + 1].discrete_trace_conormal_error for i in 1:2)
        @test all(plan.protocol.l2_order_interval[1] <= order <=
            plan.protocol.l2_order_interval[2] for order in report.l2_orders)
        @test all(plan.protocol.h1_order_interval[1] <= order <=
            plan.protocol.h1_order_interval[2] for order in report.h1_orders)
        @test report.levels[3].l2_error <= plan.protocol.finest_l2_max
        @test report.levels[3].h1_seminorm_error <=
            plan.protocol.finest_h1_seminorm_max
        @test length(unique(level.matrix_hash for level in report.levels)) == 3
        @test length(unique(level.rhs_hash for level in report.levels)) == 3
        @test length(unique(level.solution_hash for level in report.levels)) == 3
        independent_balance = ng12_oracle_continuous_balance()
        @test all(isapprox(level.analytic_source_integral,
            independent_balance.source_integral; atol=2e-15, rtol=2e-15)
            for level in report.levels)
        @test bundle.invocation_counts == (compiler_calls=1,
            provider_calls=1, mesh_calls=3, assembly_calls=6,
            solver_calls=3, formal_t2_consumer_receipts=0)
        @test !bundle.formal_t2_consumer_receipts_reclassified
        @test fixture.preparation_counts == (
            t0_source_record_factory_calls=3,
            v3_source_witness_calls=1, t1_admission_calls=1,
            compiler_calls=1)
        metrics = Dict(metric.name => metric for metric in bundle.evidence.metrics)
        @test metrics[:finest_l2_error].unit ==
            NG12_R._ng12_si_length_unit(3 // 2)
        @test metrics[:finest_h1_seminorm_error].unit ==
            NG12_R._ng12_si_length_unit(1 // 2)
        @test metrics[:max_algebraic_residual].unit ==
            NG12_R._ng12_si_length_unit(1)
        @test metrics[:max_source_integral_error].unit ==
            NG12_R._ng12_si_length_unit(1)
        @test metrics[:max_interior_reaction_linf].unit ==
            NG12_R._ng12_si_length_unit(1)
        @test metrics[:max_interior_residual_match_linf].unit ==
            NG12_R._ng12_si_length_unit(1)
        @test metrics[:max_discrete_boundary_reaction_balance_defect].unit ==
            NG12_R._ng12_si_length_unit(1)
        @test metrics[:solver_calls].unit == NG12_G.UnitSignature()

        @test reversed.status === :numerical_fail
        @test reversed.source_sign === :reversed_test_control
        @test reversed.analytic_source_integral < 0
        @test reversed.matrix_hash == report.levels[2].matrix_hash
        @test reversed.rhs_hash != report.levels[2].rhs_hash
        @test reversed.solution_hash != report.levels[2].solution_hash
        @test isapprox(reversed.assembled_source_integral,
            -report.levels[2].assembled_source_integral;
            atol=plan.protocol.source_integral_abs_tol, rtol=0.0)
        @test reversed.l2_error > report.levels[2].l2_error
        @test reversed.discrete_interior_reaction_linf <=
            plan.protocol.residual_abs_tol
        @test reversed.discrete_interior_residual_match_linf <=
            plan.protocol.residual_abs_tol
        @test abs(reversed.discrete_boundary_reaction_balance_defect) <=
            plan.protocol.reaction_balance_abs_tol
        @test isapprox(reversed.discrete_boundary_reaction_balance_defect,
            -reversed.discrete_interior_reaction_sum;
            atol=plan.protocol.reaction_balance_abs_tol, rtol=0.0)

        forged_level = ng12_rehashed_level(report.levels[1];
            analytic_source_integral=
                report.levels[1].analytic_source_integral + 1.0)
        @test NG12_R._ng12_level_integrity(forged_level)
        forged_levels = (forged_level, report.levels[2], report.levels[3])
        forged_report = ng12_rehashed_report(report; levels=forged_levels)
        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan,
            forged_report)

        forged_gaps = ng12_rehashed_report(report; gaps=(:forged_gap,))
        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan, forged_gaps)
        foreign_report = ng12_rehashed_report(report;
            candidate_ref=NG12_FOREIGN_CANDIDATE)
        @test !NG12_R.validate_native_g1g2_gridap_report_v1(plan,
            foreign_report)

        expected_evidence = bundle.evidence
        forged_evidence = NG12_R.RuntimeEvidenceV4(
            expected_evidence.physical_subject_hash,
            expected_evidence.scenario_hash,
            expected_evidence.solver_input_hash,
            expected_evidence.provider_manifest_hash,
            merge(expected_evidence.binding_provenance,
                (report_hash=NG12_G.digest256_text("foreign-report"),)),
            expected_evidence.status_vector, expected_evidence.metrics;
            claim_ceiling=expected_evidence.claim_ceiling,
            independence_group=expected_evidence.independence_group,
            provider_manifest=plan.provider,
            backend_revision=expected_evidence.backend_revision,
            numerical_configuration_hash=
                expected_evidence.numerical_configuration_hash,
            artifact_refs=expected_evidence.artifact_refs,
            uncertainty_or_null=expected_evidence.uncertainty_or_null)
        forged_bundle_body = NG12_R._ng12_execution_bundle_body(
            bundle.plan_hash, bundle.solver_input_hash, bundle.report,
            forged_evidence, bundle.invocation_counts,
            bundle.formal_t2_consumer_receipts_reclassified)
        forged_bundle = NG12_R.NativeG1G2ExecutionBundleV1(
            bundle.plan_hash, bundle.solver_input_hash, bundle.report,
            forged_evidence, bundle.invocation_counts,
            bundle.formal_t2_consumer_receipts_reclassified,
            NG12_G.canonical_hash(forged_bundle_body))
        @test !NG12_R.validate_native_g1g2_execution_bundle_v1(plan,
            forged_bundle)

        pending = NG12_R.native_g1g2_downstream_input_link_v1(plan, bundle)
        @test pending.status === :pending_qualified_t2
        @test pending.resolution === :terminal_deferred
        @test !pending.accepted
        @test !pending.same_candidate_validated
        @test !pending.formal_t2_consumer_receipts_reclassified
        @test pending.t2_ledger_hash === nothing
        @test pending.t2_input_hash === nothing
        @test pending.numerical_invocation_counts.formal_t2_consumer_receipts == 0
        @test ng12_expect_code(() ->
            NG12_R.native_g1g2_downstream_input_link_v1(
                plan, bundle, nothing, nothing),
            "actual qualified T2 receipt ledger is invalid")

        bytes = ng12_serialize_bytes(bundle)
        reloaded = Serialization.deserialize(IOBuffer(bytes))
        @test reloaded isa NG12_R.NativeG1G2ExecutionBundleV1
        @test NG12_R.validate_native_g1g2_execution_bundle_v1(plan, reloaded)
        @test reloaded.bundle_hash == bundle.bundle_hash
    end
    ng12_stage("primary.assertions.complete")

    artifact = (schema="native-g1g2-gridap-primary-artifact-v1",
        candidate_ref=chain.candidate,
        source_witness_hash=NG12_G.canonical_hash(chain.witness),
        t1_package_hash=chain.admission.package.package_hash,
        t1_semantic_identity=chain.admission.package.semantic_identity,
        g1_declaration_hash=chain.g1.declaration_hash,
        g2_declaration_hash=chain.g2.declaration_hash,
        program_bundle_hash=chain.programs.bundle_hash,
        compile_result_hash=fixture.compile_result.result_hash,
        protocol_hash=fixture.protocol.protocol_hash,
        plan_hash=plan.plan_hash, bundle=bundle,
        preparation_counts=fixture.preparation_counts,
        numerical_counts=bundle.invocation_counts,
        preassert_checkpoint_sha256=checkpoint_sha,
        wrong_sign_checkpoint_sha256=wrong_sign_checkpoint_sha,
        pending_link=NG12_R.native_g1g2_downstream_input_link_v1(plan, bundle),
        oracle_balance=ng12_oracle_continuous_balance(),
        compiler_source_hash=
            NG12_R.native_g1g2_diffusion_compiler_source_hash_v1(),
        adapter_source_hash=
            NG12_R.native_g1g2_gridap_adapter_source_hash_v1())
    ispath(artifact_path) && error("artifact path already exists")
    mkpath(dirname(artifact_path))
    open(artifact_path, "w") do io
        Serialization.serialize(io, artifact)
    end
    artifact_sha = bytes2hex(SHA.sha256(read(artifact_path)))
    ng12_stage("primary.artifact.complete"; detail="sha256=" * artifact_sha)
    println("NG12_RESULT mode=primary status=pass report_hash=",
        bundle.report.report_hash.value, " artifact_sha256=", artifact_sha,
        " t0_source_record_factory_calls=3 v3_source_witness_calls=1",
        " t1_admission_calls=1 compiler_calls=1 provider_calls=1",
        " mesh_calls=3 assembly_calls=6 solver_calls=3",
        " formal_t2_consumer_receipts=0 resolution=terminal_deferred")
end

function ng12_replay(artifact_path::AbstractString)
    # Rebuild every source/T0/T1/compile/provider expectation before reading
    # the serialized result under test.
    ng12_stage("replay.fixture.begin")
    fixture = ng12_compiled_fixture()
    plan = fixture.plan
    ng12_stage("replay.fixture.complete";
        detail="plan=" * plan.plan_hash.value)
    ng12_stage("replay.solve.begin")
    fresh = NG12_R.execute_native_g1g2_gridap_once!(Dict{Any,Any}(), plan)
    ng12_stage("replay.solve.complete";
        detail="report=" * fresh.report.report_hash.value)
    replay_checkpoint_path = artifact_path * ".replay-preassert.bin"
    ispath(replay_checkpoint_path) &&
        error("replay pre-assert checkpoint already exists")
    open(replay_checkpoint_path, "w") do io
        Serialization.serialize(io,
            (schema="native-g1g2-replay-preassert-checkpoint-v1",
                plan_hash=plan.plan_hash, bundle=fresh,
                preparation_counts=fixture.preparation_counts,
                numerical_counts=fresh.invocation_counts))
    end
    ng12_stage("replay.preassert_checkpoint.complete";
        detail="sha256=" *
            bytes2hex(SHA.sha256(read(replay_checkpoint_path))))

    isfile(artifact_path) || error("primary artifact is missing")
    artifact_bytes = read(artifact_path)
    artifact = Serialization.deserialize(IOBuffer(artifact_bytes))
    ng12_stage("replay.artifact.loaded";
        detail="sha256=" * bytes2hex(SHA.sha256(artifact_bytes)))

    @testset "fresh-process source and assembly replay" begin
        @test artifact.schema == "native-g1g2-gridap-primary-artifact-v1"
        @test artifact.candidate_ref == fixture.chain.candidate
        @test artifact.source_witness_hash ==
            NG12_G.canonical_hash(fixture.chain.witness)
        @test artifact.t1_package_hash ==
            fixture.chain.admission.package.package_hash
        @test artifact.t1_semantic_identity ==
            fixture.chain.admission.package.semantic_identity
        @test artifact.g1_declaration_hash == fixture.chain.g1.declaration_hash
        @test artifact.g2_declaration_hash == fixture.chain.g2.declaration_hash
        @test artifact.program_bundle_hash == fixture.chain.programs.bundle_hash
        @test artifact.compile_result_hash == fixture.compile_result.result_hash
        @test artifact.protocol_hash == fixture.protocol.protocol_hash
        @test artifact.plan_hash == plan.plan_hash
        @test artifact.preparation_counts == fixture.preparation_counts
        @test artifact.numerical_counts == fresh.invocation_counts
        @test artifact.preassert_checkpoint_sha256 ==
            bytes2hex(SHA.sha256(read(artifact_path * ".preassert.bin")))
        @test artifact.wrong_sign_checkpoint_sha256 == bytes2hex(
            SHA.sha256(read(artifact_path * ".wrong-sign-preassert.bin")))
        @test artifact.compiler_source_hash ==
            NG12_R.native_g1g2_diffusion_compiler_source_hash_v1()
        @test artifact.adapter_source_hash ==
            NG12_R.native_g1g2_gridap_adapter_source_hash_v1()
        @test NG12_R.validate_native_g1g2_execution_bundle_v1(plan,
            artifact.bundle)
        @test NG12_R.validate_native_g1g2_execution_bundle_v1(plan, fresh)
        @test fresh.bundle_hash == artifact.bundle.bundle_hash
        @test fresh.report.report_hash == artifact.bundle.report.report_hash
        @test Tuple(level.matrix_hash for level in fresh.report.levels) ==
            Tuple(level.matrix_hash for level in artifact.bundle.report.levels)
        @test Tuple(level.rhs_hash for level in fresh.report.levels) ==
            Tuple(level.rhs_hash for level in artifact.bundle.report.levels)
        @test Tuple(level.solution_hash for level in fresh.report.levels) ==
            Tuple(level.solution_hash for level in artifact.bundle.report.levels)
        @test Tuple(level.l2_error for level in fresh.report.levels) ==
            Tuple(level.l2_error for level in artifact.bundle.report.levels)
        @test Tuple(level.h1_seminorm_error for level in fresh.report.levels) ==
            Tuple(level.h1_seminorm_error for level in
                artifact.bundle.report.levels)
        @test artifact.oracle_balance == ng12_oracle_continuous_balance()
        replay_link = NG12_R.native_g1g2_downstream_input_link_v1(plan, fresh)
        @test artifact.pending_link.link_hash == replay_link.link_hash
        @test artifact.pending_link.status === replay_link.status
        @test fresh.invocation_counts.formal_t2_consumer_receipts == 0
    end
    ng12_stage("replay.assertions.complete")
    println("NG12_RESULT mode=replay status=pass report_hash=",
        fresh.report.report_hash.value,
        " fresh_provider_calls=1 fresh_mesh_calls=3 fresh_assembly_calls=6",
        " fresh_solver_calls=3 formal_t2_consumer_receipts=0",
        " resolution=terminal_deferred")
end

length(ARGS) == 2 || error(
    "usage: focused_tests.jl <primary|replay> <artifact-path>")
mode, artifact_path = ARGS
ng12_stage("dispatch.before"; detail="mode=" * mode)
if mode == "primary"
    let
        ng12_stage("precompile.before";
            detail="target=ng12_primary signature=(String,)")
        precompile_result = nothing
        precompile_exception = nothing
        try
            precompile_result = precompile(ng12_primary, (String,))
        catch error
            precompile_exception = error
        end
        detail = "target=ng12_primary signature=(String,) result=" *
            string(precompile_result)
        if precompile_exception !== nothing
            detail *= " exception_type=" * string(typeof(precompile_exception)) *
                " exception=" * replace(
                    sprint(showerror, precompile_exception), r"\s+" => " ")
        end
        ng12_stage("precompile.after"; detail=detail)
    end
    ng12_primary(artifact_path)
elseif mode == "replay"
    ng12_replay(artifact_path)
else
    error("unsupported mode: " * mode)
end
