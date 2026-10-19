isdefined(Main, :_THERMAL_SLAB_CASE_CACHE) ||
    include(joinpath(@__DIR__, "thermal_slab_actual_source_fixture.jl"))

@testset "UP5 queue initialization loads the existing consumer on demand" begin
    @test _THERMAL_SLAB_BINDINGS_ABSENT_BEFORE
    @test isdefined(_DCCE, :CompositionSolveProtocolV1)
    @test isdefined(Main, :SteadyPlanarThermalDiffusionConsumerV1)
    @test _THERMAL_SLAB_ENSURED_BINDINGS.protocol_type === _DCCE.CompositionSolveProtocolV1
    @test _THERMAL_SLAB_CONSUMER === Main.SteadyPlanarThermalDiffusionConsumerV1
    @test isdefined(_THERMAL_SLAB_CONSUMER, :execute_up3_steady_planar_composition_v1)
end
const _THERMAL_Q1_DIAGNOSTIC_ONLY = get(ENV, "UP3_Q1_GRIDAP_DIAGNOSTIC_ONLY", "0") == "1"
if !_THERMAL_Q1_DIAGNOSTIC_ONLY
@testset "DCCE admits only source-bound SI thermal fields and matching geometry" begin
    dcce_timing = get(ENV, "UP2_DCCE_TIMING", "0") == "1"
    if dcce_timing
        println("UP2_DCCE_GROUP_ENTER")
        flush(stdout)
    end
    heldout_dir = "test/fixtures/thermal_slab/thermal-slab-up4-v5-20261003-heldout-k3"
    cases = (
        (_THERMAL_SLAB_CANDIDATE_DIR, 2.0),
        (_THERMAL_SLAB_K22_CANDIDATE_DIR, 2.2),
        (heldout_dir, 3.0),
    )
    function _thermal_dcce_run_typed_case(actual, spatial=actual.spatial; g1=actual.built.g1.declaration)
        if dcce_timing
            call_started_ns = time_ns()
            println("UP2_DCCE_CALL_BEGIN candidate=$(actual.built.candidate_ref.id)")
            flush(stdout)
        end
        outcome = _DCCE.dcce_compile_execute_v1(actual.built.candidate_ref, g1,
            actual.built.g2.declaration, actual.built.g3.declaration,
            actual.t0.transport, spatial)
        if dcce_timing
            elapsed_ms = round((time_ns() - call_started_ns) / 1.0e6; digits=3)
            println("UP2_DCCE_CALL_END candidate=$(actual.built.candidate_ref.id) elapsed_ms=$(elapsed_ms)")
            flush(stdout)
        end
        outcome
    end
    function spatial_variant(actual; edges=actual.spatial.new_geometry.edges,
            k_cells=actual.spatial.field.k_cells,
            source=actual.spatial.field.source,
            boundary=actual.spatial.boundary)
        geometry = _DCCE.DeclaredSpatialGeometryV1(
            "thermal-source-variant", edges)
        field = _DCCE.DeclaredSpatialFieldV1(k_cells, source)
        _DCCE.DeclaredSpatialCaseV1(actual.spatial.old_geometry, geometry,
            actual.spatial.old_state, field, boundary,
            actual.spatial.composition; case_ref="thermal-source-variant")
    end

    candidate_refs = Any[]
    for (candidate_dir, expected_kxx) in cases
        if dcce_timing
            println("UP2_DCCE_CASE_BEGIN path=$(candidate_dir)")
            flush(stdout)
        end
        actual = _thermal_source_case(candidate_dir)
        if dcce_timing
            println("UP2_DCCE_CASE_READY path=$(candidate_dir) candidate=$(actual.built.candidate_ref.id)")
            flush(stdout)
        end
        push!(candidate_refs, actual.built.candidate_ref)
        outcome = _thermal_dcce_run_typed_case(actual)
        @test outcome.status === :terminal_deferred
        @test outcome.code === :g2_admission_terminal_deferred
        @test outcome.accepted === false
        @test outcome.numerical.status === :terminal_deferred
        @test outcome.numerical.code === :dgd_2dof_mesh_not_executed
        @test outcome.composition.authority.status === :terminal_deferred
        @test outcome.composition.authority.code === :g2_admission_terminal_deferred
        @test outcome.numerical.dgd.status === :terminal_deferred
        @test outcome.numerical.dgd.code === :unsupported_typed_source_mesh
        @test outcome.numerical.dgd.solver_calls == 0
        @test outcome.numerical.dgd_transfer.status === :not_executed
        @test outcome.numerical.dgd_transfer.resolution === :terminal_deferred
        @test outcome.numerical.dgd_transfer.code === :unsupported_typed_source_mesh
        @test outcome.numerical.dgd_transfer.old_state === nothing
        @test outcome.numerical.dgd_transfer.new_state === nothing
        @test outcome.numerical.dgd_transfer.overlap === nothing
        @test outcome.numerical.dgd_transfer.weights === nothing
        @test outcome.numerical.dgd_transfer.solver_calls == 0
        @test outcome.numerical.fv.status === :ready
        @test outcome.numerical.fv.solver_calls == 1
        @test outcome.numerical.solver_calls == 1
        @test outcome.aggregate.status === :terminal_deferred
        @test outcome.aggregate.code === :g2_admission_terminal_deferred
        @test outcome.aggregate.resolution === :terminal_deferred
        @test outcome.aggregate.solver_calls == 1
        @test outcome.aggregate.dgd_solver_calls == 0
        @test outcome.aggregate.fv_solver_calls == 1
        @test outcome.numerical.fv.residual_norm <= 1e-12
        @test outcome.aggregate.accepted === false
        @test outcome.aggregate.screen_only === true
        @test outcome.aggregate.formal_up_credit === false
        @test outcome.aggregate.formal_r_credit === false
        @test Tuple(actual.spatial.field.k_cells) == ntuple(_ -> expected_kxx, 4)
        @test Tuple(actual.spatial.field.source) == (1.0, 1.0, 1.0, 1.0)
    end
    @test length(unique(ref.id for ref in candidate_refs)) == 3

    actual = _thermal_source_case()
    base = actual.spatial
    bad_k = collect(base.field.k_cells)
    bad_k[2] += 0.125
    bad_k_outcome = _thermal_dcce_run_typed_case(actual, spatial_variant(actual; k_cells=bad_k))
    @test bad_k_outcome.lowering.status === :fail_closed
    @test bad_k_outcome.lowering.code === :g1_coefficient_field_mismatch

    bad_source = collect(base.field.source)
    bad_source[3] += 0.125
    bad_source_outcome = _thermal_dcce_run_typed_case(actual, spatial_variant(actual; source=bad_source))
    @test bad_source_outcome.lowering.status === :fail_closed
    @test bad_source_outcome.lowering.code === :g1_source_field_mismatch

    subset_edges = (0.25, 0.625, 1.0, 1.375, 1.75)
    subset_outcome = _thermal_dcce_run_typed_case(actual, spatial_variant(actual; edges=subset_edges))
    @test subset_outcome.lowering.status !== :ready
    expanded_edges = (-0.25, 0.375, 1.0, 1.625, 2.25)
    expanded_outcome = _thermal_dcce_run_typed_case(actual, spatial_variant(actual; edges=expanded_edges))
    @test expanded_outcome.lowering.status !== :ready

    wrong_left_kind = _DCCE.DeclaredSpatialBoundaryV1(
        :neumann, 0.0, :dirichlet, 300.0)
    wrong_left_outcome = _thermal_dcce_run_typed_case(actual,
        spatial_variant(actual; boundary=wrong_left_kind))
    @test wrong_left_outcome.lowering.status !== :ready
    wrong_right_value = _DCCE.DeclaredSpatialBoundaryV1(
        :dirichlet, 300.0, :dirichlet, 301.0)
    wrong_right_outcome = _thermal_dcce_run_typed_case(actual,
        spatial_variant(actual; boundary=wrong_right_value))
    @test wrong_right_outcome.lowering.status !== :ready

    bad_f = _DCCE.G1DiffusionScalarFieldV1(
        actual.built.g1.declaration.f.field_id,
        actual.built.g1.declaration.f.physical_type,
        actual.built.g1.declaration.f.source_ref;
        source_expression="f_candidate(x)=2")
    wrong_f = _DCCE.g1_diffusion_edit_source(
        actual.built.g1.declaration, :f, bad_f)
    wrong_f_outcome = _thermal_dcce_run_typed_case(actual; g1=wrong_f)
    @test wrong_f_outcome.status !== :ready
    @test wrong_f_outcome.accepted === false

    wrong_f_dir = "test/fixtures/thermal_slab/thermal-slab-up4-v5-20261003-wrong-f-expression"
    wrong_f_source_error = try
        _thermal_build_source_case(wrong_f_dir)
        nothing
    catch err
        err
    end
    @test wrong_f_source_error isa ArgumentError
    @test occursin("thermal slab G1 expression contract mismatch",
        sprint(showerror, wrong_f_source_error))
end
if get(ENV, "UP2_DCCE_TIMING", "0") == "1"
    println("UP2_DCCE_GROUP_COMPLETE")
    flush(stdout)
end

@testset "UP2-01 candidate-authored G1 AST reaches the source-bound FV consumer" begin
    malformed_source = "{"
    unknown_u_source = "{\"schema\":\"candidate-g1-source-unknown-v9\",\"role\":\"u\",\"nodes\":[],\"root\":1}"
    unknown_f_source = "{\"schema\":\"candidate-g1-source-unknown-v9\",\"role\":\"f\",\"nodes\":[],\"root\":1}"
    for role in (:u, :f)
        @test_throws ArgumentError Main.FusionRuntimeV4._g1_authored_source_expression_root_v1(
            malformed_source, role)
    end
    @test_throws ArgumentError Main.FusionRuntimeV4._g1_authored_source_expression_root_v1(
        unknown_u_source, :u)
    @test_throws ArgumentError Main.FusionRuntimeV4._g1_authored_source_expression_root_v1(
        unknown_f_source, :f)
    @test Main.FusionRuntimeV4._g1_authored_source_expression_root_v1(
        "f(x)=1", :f) === nothing

    # Predeclare every label, including the held-out quadratic, before creating
    # any source bytes or running the consumer.
    labels = (:up2_01_legal_constant_f, :up2_01_legal_affine_f,
        :up2_01_holdout_quadratic_f, :up2_01_transverse_bc_negative,
        :up2_01_flux_unit_negative, :up2_01_variable_kxx_affine)
    @test length(labels) == 6
    function authored_case(label)
        variant = _thermal_materialize_source_variant_v1(
            _DCCE_ROOT, _THERMAL_SLAB_CANDIDATE_DIR, label)
        @test startswith(variant.candidate_directory, "tmp/up2_01_source_variants/")
        actual = _thermal_source_case(variant.candidate_directory;
            source_root=variant.source_root)
        @test actual.t0.status === :valid
        g1_record = only(filter(r -> r.layer === :G1,
            actual.records.declarations))
        g2_record = only(filter(r -> r.layer === :G2,
            actual.records.declarations))
        capability = g1_record.semantic_body.body.value.g1_typed_source_field_program
        @test capability.candidate_ref == actual.built.candidate_ref
        @test capability.g1_source_ref == g1_record.source_ref
        @test capability.g1_declaration_ref == g1_record.declaration_ref
        @test capability.g2_source_ref == g2_record.source_ref
        @test capability.g2_declaration_ref == g2_record.declaration_ref
        @test capability.roots.f.declared_type == actual.built.g1.declaration.f.physical_type
        @test capability.roots.u.declared_type == actual.built.g1.declaration.u.physical_type
        chart = actual.built.g2.declaration.source.chart_map
        edges = actual.spatial.new_geometry.edges
        x_centers = Tuple((Float64(edges[i]) + Float64(edges[i + 1])) / 2
            for i in 1:(length(edges) - 1))
        y_ref = (Float64(chart.domain_lower[2]) + Float64(chart.domain_upper[2])) / 2
        z_ref = (Float64(chart.domain_lower[3]) + Float64(chart.domain_upper[3])) / 2
        points = Tuple(begin
            xi = (x - Float64(chart.offset[1])) /
                Float64(chart.jacobian_rows[1][1])
            (xi, y_ref, z_ref)
        end for x in x_centers)
        evaluated_f = Base.invokelatest(
            Main.FusionRuntimeV4.evaluate_g1_typed_source_program_v1,
            capability, capability.roots.f, points)
        @test evaluated_f.status === :ready
        @test evaluated_f.candidate_ref == actual.built.candidate_ref
        @test evaluated_f.g1_source_ref == g1_record.source_ref
        @test evaluated_f.g2_source_ref == g2_record.source_ref
        values = Tuple(Float64(v) for v in evaluated_f.values)
        expected = label in (:up2_01_legal_constant_f, :up2_01_variable_kxx_affine) ?
            ntuple(_ -> 1.0, length(points)) :
            label === :up2_01_legal_affine_f ?
                Tuple(1.0 + 0.5 * p[1] for p in points) :
                label === :up2_01_holdout_quadratic_f ?
                    Tuple(1.0 + 0.5 * p[1]^2 for p in points) : values
        if label in (:up2_01_legal_constant_f, :up2_01_legal_affine_f,
                :up2_01_holdout_quadratic_f, :up2_01_variable_kxx_affine)
            @test all(isapprox(a, b; atol=1e-14, rtol=0.0)
                for (a,b) in zip(values, expected))
        end
        x_faces = Dict(face.face => Float64(face.value.value) for
            face in actual.built.g2.declaration.source.faces
            if face.face in (:x_min, :x_max))
        u_points = ((Float64(chart.domain_lower[1]), y_ref, z_ref),
            (Float64(chart.domain_upper[1]), y_ref, z_ref))
        evaluated_u = Base.invokelatest(
            Main.FusionRuntimeV4.evaluate_g1_typed_source_program_v1,
            capability, capability.roots.u, u_points)
        @test evaluated_u.status === :ready
        @test Tuple(Float64(v) for v in evaluated_u.values) ==
            (x_faces[:x_min], x_faces[:x_max])
        composition_components = Tuple(begin
            ports = Tuple(_DCCE.DeclaredSpatialPortV1(port.port_ref,
                port.direction, port.quantity, port.unit, port.account;
                role=port.role, ledger_sign=port.ledger_sign,
                magnitude=port.magnitude,
                payload=port.role === :source ? values : port.payload)
                for port in component.ports)
            _DCCE.DeclaredSpatialComponentV1(component.component_ref, ports)
        end for component in actual.spatial.composition.components)
        composition = _DCCE.DeclaredSpatialCompositionV1(composition_components;
            plan_ref=actual.spatial.composition.plan_ref)
        field = _DCCE.DeclaredSpatialFieldV1(actual.spatial.field.k_cells, values)
        spatial = _DCCE.DeclaredSpatialCaseV1(actual.spatial.old_geometry,
            actual.spatial.new_geometry, actual.spatial.old_state, field,
            actual.spatial.boundary, composition;
            case_ref="up2-01-authored-$(label)")
        (variant=variant, actual=actual, capability=capability,
            points=points, values=values, spatial=spatial)
    end

    # The refinement and held-out G2 profiles retain their declared geometry.
    constant_case = authored_case(:up2_01_legal_constant_f)
    affine_case = authored_case(:up2_01_legal_affine_f)
    heldout_case = authored_case(:up2_01_holdout_quadratic_f)
    cases = (constant_case, affine_case, heldout_case)
    @test length(unique(c.variant.candidate_id for c in cases)) == 3
    @test length(unique(c.actual.built.candidate_ref for c in cases)) == 3
    @test (constant_case.actual.built.g2.declaration.source.mesh.cells,
        affine_case.actual.built.g2.declaration.source.mesh.cells,
        heldout_case.actual.built.g2.declaration.source.mesh.cells) ==
        ((4,1,1), (8,1,1), (6,1,1))
    @test heldout_case.actual.built.g2.declaration.source.faces[1].value.value == 310//1

    outputs = map(c -> _DCCE.dcce_compile_execute_v1(
        c.actual.built.candidate_ref, c.actual.built.g1.declaration,
        c.actual.built.g2.declaration, c.actual.built.g3.declaration,
        c.actual.t0.transport, c.spatial), cases)
    for (case, output) in zip(cases, outputs)
        @test output.lowering.status === :ready
        @test output.lowering.source == case.values
        fv = output.numerical.fv
        @test fv.status === :ready
        @test fv.solver_calls == 1
        @test fv.factorization_count == 1
        @test fv.refinement_solve_count in (0, 1)
        @test fv.lu_rhs_solve_count == 1 + fv.refinement_solve_count
        @test output.numerical.solver_calls == 1
        @test isfinite(fv.residual_norm)
        @test fv.residual_norm <= 1e-12
        @test fv.assembly_hash isa AbstractString
        @test output.accepted === false
        @test output.claim_ceiling === :screen_only
    end
    @test length(outputs[1].numerical.fv.rhs) == 4
    @test length(outputs[2].numerical.fv.rhs) == 8
    @test length(outputs[3].numerical.fv.rhs) == 6
    heldout_fv = outputs[3].numerical.fv
    @test heldout_fv.initial_residual_norm > 1e-12
    @test heldout_fv.refinement_solve_count == 1
    @test heldout_fv.lu_rhs_solve_count == 2
    @test outputs[1].numerical.fv.assembly_hash != outputs[2].numerical.fv.assembly_hash
    @test outputs[2].numerical.fv.assembly_hash != outputs[3].numerical.fv.assembly_hash

    variable_k_case = authored_case(:up2_01_variable_kxx_affine)
    variable_k_expr = variable_k_case.actual.built.g1.declaration.K.expression
    @test variable_k_expr.slope_diag[1] == 1//5
    variable_centers = Tuple((Float64(variable_k_case.spatial.new_geometry.edges[i]) +
        Float64(variable_k_case.spatial.new_geometry.edges[i + 1])) / 2 for i in 1:4)
    @test all(isapprox(variable_k_case.spatial.field.k_cells[i],
        2.0 + 0.2 * variable_centers[i]; atol=1e-14, rtol=0.0) for i in 1:4)
    @test length(unique(variable_k_case.spatial.field.k_cells)) == 4
    variable_k_output = _DCCE.dcce_compile_execute_v1(
        variable_k_case.actual.built.candidate_ref,
        variable_k_case.actual.built.g1.declaration,
        variable_k_case.actual.built.g2.declaration,
        variable_k_case.actual.built.g3.declaration,
        variable_k_case.actual.t0.transport, variable_k_case.spatial)
    @test variable_k_output.lowering.status === :ready
    @test variable_k_output.lowering.source == variable_k_case.values
    variable_k_fv = variable_k_output.numerical.fv
    @test variable_k_fv.status === :ready
    @test variable_k_fv.solver_calls == 1
    @test variable_k_fv.factorization_count == 1
    @test variable_k_fv.refinement_solve_count in (0, 1)
    @test variable_k_fv.lu_rhs_solve_count == 1 + variable_k_fv.refinement_solve_count
    @test variable_k_output.numerical.solver_calls == 1
    @test isfinite(variable_k_fv.residual_norm)
    @test variable_k_fv.residual_norm <= 1e-12
    @test variable_k_output.accepted === false
    @test variable_k_output.claim_ceiling === :screen_only
    @test variable_k_output.numerical.fv.matrix != outputs[1].numerical.fv.matrix
    common_xprobe = fill(301.0, 4)
    fv_dense_matrix = matrix -> [Float64(matrix[i][j])
        for i in eachindex(matrix), j in eachindex(first(matrix))]
    constant_k_residual = fv_dense_matrix(outputs[1].numerical.fv.matrix) *
        common_xprobe - collect(outputs[1].numerical.fv.rhs)
    variable_k_residual = fv_dense_matrix(variable_k_output.numerical.fv.matrix) *
        common_xprobe - collect(variable_k_output.numerical.fv.rhs)
    @test maximum(abs.(variable_k_residual .- constant_k_residual)) > 1e-10
    dense_control_tuple = ((1.0, 2.0, 3.0, 4.0), (5.0, 6.0, 7.0, 8.0),
        (9.0, 10.0, 11.0, 12.0), (13.0, 14.0, 15.0, 16.0))
    @test fv_dense_matrix(dense_control_tuple) ==
        [1.0 2.0 3.0 4.0; 5.0 6.0 7.0 8.0; 9.0 10.0 11.0 12.0; 13.0 14.0 15.0 16.0]
    for output in (outputs..., variable_k_output)
        fv = output.numerical.fv
        original_system_residual = fv_dense_matrix(fv.matrix) * collect(fv.solution) -
            collect(fv.rhs)
        @test _DCCE.norm(original_system_residual, Inf) == fv.residual_norm
    end

    transverse = authored_case(:up2_01_transverse_bc_negative)
    @test transverse.actual.t0.status === :valid
    transverse_out = _DCCE.dcce_compile_execute_v1(
        transverse.actual.built.candidate_ref,
        transverse.actual.built.g1.declaration,
        transverse.actual.built.g2.declaration,
        transverse.actual.built.g3.declaration,
        transverse.actual.t0.transport, transverse.spatial)
    @test transverse_out.status === :terminal_deferred
    @test transverse_out.lowering.status === :terminal_deferred
    @test transverse_out.lowering.code === :unsupported_g1_transverse_boundary_profile
    @test transverse_out.numerical === nothing

    flux_unit = authored_case(:up2_01_flux_unit_negative)
    @test flux_unit.actual.t0.status === :valid
    flux_unit_out = _DCCE.dcce_compile_execute_v1(
        flux_unit.actual.built.candidate_ref,
        flux_unit.actual.built.g1.declaration,
        flux_unit.actual.built.g2.declaration,
        flux_unit.actual.built.g3.declaration,
        flux_unit.actual.t0.transport, flux_unit.spatial)
    @test flux_unit_out.status === :fail_closed
    @test flux_unit_out.lowering.status === :fail_closed
    @test flux_unit_out.lowering.code === :g1_g2_unit_mismatch
    @test flux_unit_out.numerical === nothing
end

function _thermal_assert_disconnected_feedback_trace_guard_v1(actual, baseline_result)
    built, records = actual.built, actual.records
    consumer = _THERMAL_SLAB_CONSUMER
    runtime = getfield(Main, :FusionRuntimeV4)
    g1_record = only(filter(r -> r.layer === :G1, records.declarations))
    capability = g1_record.semantic_body.body.value.g1_typed_source_field_program
    q_parameter_ref = _DCCE.FieldParameterRefV1("thermal_slab_q_runtime_v1")
    q_profile = runtime.g1_runtime_source_density_parameter_v1(capability;
        parameter_ref=q_parameter_ref, q_bounds_W_m3=(0.0, 2.0))
    q_bounds = _DCCE.QuantityIntervalV1(
        _DCCE.ExactFiniteIntervalV1(0//1, 2//1, false),
        capability.source_law.f_type.units)
    q_transform = _DCCE.ParameterTransformSpecV1(_DCCE.transform_linear)
    points = ((0.125, 0.5, 0.5), (0.375, 0.5, 0.5),
        (0.625, 0.5, 0.5), (0.875, 0.5, 0.5))
    q_gene = _DCCE.FieldParameterGeneV1(q_parameter_ref,
        capability.source_law.f_type.units, q_transform, q_bounds, 0.0)
    q_input = runtime.g1_runtime_source_density_input_v1(q_profile, q_gene)
    q_dynamic = runtime.evaluate_g1_runtime_source_density_v1(capability,
        q_profile, q_input, points)
    q_half_gene = _DCCE.FieldParameterGeneV1(q_parameter_ref,
        capability.source_law.f_type.units, q_transform, q_bounds, -0.5)
    q_half_input = runtime.g1_runtime_source_density_input_v1(q_profile, q_half_gene)
    q_half_dynamic = runtime.evaluate_g1_runtime_source_density_v1(capability,
        q_profile, q_half_input, points)
    @test q_half_input.q_W_m3 == 0.5
    @test q_half_dynamic.values == (0.5, 0.5, 0.5, 0.5)
    @test q_dynamic.result_hash != q_half_dynamic.result_hash
    q_half_spatial = consumer._thermal_spatial_case_with_source_density_v1(
        actual.spatial, q_half_input.q_W_m3)
    q_half_solver = consumer._execute_steady_planar_thermal_diffusion_v1(
        built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, actual.t0.transport, q_half_spatial;
        candidate_source_density=(g1_profile=q_profile, g1_input=q_half_input))
    @test q_half_solver.status === :screen_only
    @test q_half_solver.volume_source_W_m3 == (0.5, 0.5, 0.5, 0.5)
    @test q_half_solver.temperature_K != baseline_result.temperature_K

    protocol = _DCCE.CompositionSolveProtocolV1(
        _DCCE.canonical_hash((test_protocol=:thermal_slab_up3_disconnected_trace_v1,)),
        24, 1e-12)
    admission = consumer.up3_steady_planar_composition_admit_v1(
        built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, actual.t0.transport, actual.spatial, protocol;
        solver_component=:fv,
        subject_ref=_DCCE.canonical_hash((subject=:thermal_slab,)),
        mission_ref=_DCCE.canonical_hash((mission=:steady_screen,)),
        scenario_ref=_DCCE.canonical_hash(_DCCE.semantic_view(
            built.identity.scenario_ref)))
    @test admission.outcome.status === :ready
    bindings = consumer._up3_slab_execution_bindings_v1(
        built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, actual.t0.transport, actual.spatial, admission;
        solver_component=:fv)
    composition = _DCCE.execute_composition_solve_v1(admission,
        bindings.provider_bindings; feedback_seeds=bindings.feedback_seeds)
    @test composition.status === :executed
    @test !isempty(composition.feedback_trace)
    real_step = first(composition.feedback_trace)
    disconnected_solver_step = merge(real_step,
        (solver_result=q_half_solver, solver_result_hash=q_half_solver.result_hash))
    disconnected_measurement_step = merge(disconnected_solver_step,
        (temperature_K=maximum(Float64.(q_half_solver.temperature_K)),))
    measurement_error = try
        consumer._up3_slab_iteration_trace_v1((disconnected_measurement_step,), :fv)
        nothing
    catch err
        err
    end
    @test measurement_error isa ArgumentError
    @test measurement_error.msg == "up3_trace_G3_feedback_not_bound_to_measured_solver_state"
    source_error = try
        consumer._up3_slab_iteration_trace_v1((disconnected_solver_step,), :fv)
        nothing
    catch err
        err
    end
    @test source_error isa ArgumentError
    @test source_error.msg == "up3_trace_solver_source_differs_from_applied_q"
    (candidate_ref=built.candidate_ref, q_W_m3=q_half_input.q_W_m3,
     q_half_temperature_K=q_half_solver.temperature_K,
     raw_composition_steps=length(composition.feedback_trace),
     measurement_guard=measurement_error.msg, source_guard=source_error.msg)
end

@testset "current-source SI thermal slab uses the admitted G1 carrier" begin
    actual = _thermal_source_case()
    built, records = actual.built, actual.records
    g1_record = only(filter(r -> r.layer === :G1, records.declarations))
    g2_record = only(filter(r -> r.layer === :G2, records.declarations))
    capability = g1_record.semantic_body.body.value.g1_typed_source_field_program
    thermal_input = _DCCE.dcce_input_v1(built.candidate_ref, built.g1.declaration,
        built.g2.declaration, built.g3.declaration, actual.t0.transport, actual.spatial)
    @test _THERMAL_SLAB_CONSUMER._thermal_source_capability(thermal_input).capability === capability
    @test capability.candidate_ref == built.candidate_ref
    @test capability.g1_source_ref == g1_record.source_ref
    @test capability.g1_declaration_ref == g1_record.declaration_ref
    @test capability.g2_source_ref == g2_record.source_ref
    @test capability.g2_declaration_ref == g2_record.declaration_ref
    @test capability.source_law.T0_K == 300.0
    @test capability.source_law.q_W_m3 == 1.0
    @test capability.source_law.Kxx_W_mK == 2.0
    @test capability.source_law.L_m == 2.0
    @test built.g1.declaration.u.physical_type.units == _DCCE.UnitSignature((0,0,0,0,1,0,0))
    @test built.g1.declaration.K.physical_type.units == _DCCE.UnitSignature((1,1,-3,0,-1,0,0))
    @test built.g1.declaration.f.physical_type.units == _DCCE.UnitSignature((-1,1,-3,0,0,0,0))
    @test built.g1.declaration.K.expression.domain_min == (0//1,0//1,0//1)
    @test built.g1.declaration.K.expression.domain_max == (2//1,1//1,1//1)
    @test built.g1.declaration.K.expression.base_diag == (2//1,3//1,4//1)
    @test built.g1.declaration.K.expression.slope_diag == (0//1,1//10,0//1)
    chart = built.g2.declaration.source.chart_map
    @test chart.domain_lower == (0//1,0//1,0//1)
    @test chart.domain_upper == (1//1,1//1,1//1)
    @test chart.offset == (0//1,0//1,0//1)
    @test chart.jacobian_rows == ((2//1,0//1,0//1),(0//1,1//1,0//1),(0//1,0//1,1//1))
    face_map = Dict(face.face => face for face in built.g2.declaration.source.faces)
    @test face_map[:x_min].value.kind === :dirichlet
    @test face_map[:x_min].value.value == 300//1
    @test face_map[:x_max].value.kind === :dirichlet
    @test face_map[:x_max].value.value == 300//1
    @test all(face_map[face].value.kind === :neumann &&
        iszero(face_map[face].value.value) for face in (:y_min,:y_max,:z_min,:z_max))
    @test length(capability.source_law.boundary_faces) == 6
    @test Set(face.face for face in capability.source_law.boundary_faces) ==
        Set((:x_min, :x_max, :y_min, :y_max, :z_min, :z_max))
    @test _THERMAL_SLAB_CONSUMER.verify_g1_steady_thermal_field_capability_v1(
        thermal_input, g1_record, g2_record, capability)

    dgd_input = _DCCE.dgd_input_v1(built.candidate_ref, built.g1.declaration,
        built.g2.declaration, built.g3.declaration, actual.t0.transport)
    @test dgd_input.candidate_ref == built.candidate_ref
    result = _THERMAL_SLAB_CONSUMER.execute_steady_planar_thermal_diffusion_v1(
        built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, actual.t0.transport, actual.spatial)
    @test result.status === :screen_only
    @test result.accepted === false
    @test result.claim_ceiling === :screen_only
    @test result.typed_source_program_status === :ready
    @test collect(result.candidate_temperature_at_cell_centers_K) ≈
        collect((300.109375, 300.234375, 300.234375, 300.109375)) atol=1e-12
    @test collect(result.temperature_K) ≈ collect((300.125, 300.25, 300.25, 300.125)) atol=1e-12
    @test result.fv_discretization_correction_K ≈ 1/64 atol=1e-12
    @test result.outward_fourier_flux_left_W_m2 ≈ 1.0 atol=1e-12
    @test result.outward_fourier_flux_right_W_m2 ≈ 1.0 atol=1e-12
    @test result.integrated_source_per_area_W_m2 ≈ 2.0 atol=1e-12
    @test result.physical_validation === false
    @test result.engineering_validation === false
    @test result.evidence_credit == 0

    if result.status === :screen_only && result.accepted === false &&
            result.typed_source_program_status === :ready &&
            result.candidate_ref == built.candidate_ref &&
            result.source_program_audit.binding_hash isa _DCCE.Digest256 &&
            isfinite(result.residual_norm) && result.residual_norm <= 1e-12
        println("THERMAL_SLAB_ACTUAL_SUCCESS=", (
            status=result.status,
            candidate_ref=(id=result.candidate_ref.id, version=result.candidate_ref.version),
            source_bundle_hash=result.source_bundle_hash,
            g1_source_identity_hash=result.source_program_audit.g1_source_identity_hash,
            g2_source_identity_hash=result.source_program_audit.g2_source_identity_hash,
            binding_hash=result.source_program_audit.binding_hash,
            temperature_K=result.temperature_K,
            source_W_m3=result.volume_source_W_m3,
            flux_left_W_m2=result.outward_fourier_flux_left_W_m2,
            flux_right_W_m2=result.outward_fourier_flux_right_W_m2,
            integrated_source_W=result.integrated_source_W,
            residual_norm=result.residual_norm, result_hash=result.result_hash))
    end

    runtime = getfield(Main, :FusionRuntimeV4)
    points = ((0.125, 0.5, 0.5), (0.375, 0.5, 0.5),
        (0.625, 0.5, 0.5), (0.875, 0.5, 0.5))
    analytic = runtime.evaluate_g1_typed_source_program_v1(capability,
        capability.roots.u, points)
    @test analytic.status === :ready
    @test collect(analytic.values) ≈ collect((300.109375, 300.234375, 300.234375, 300.109375)) atol=1e-12
    source_values = runtime.evaluate_g1_typed_source_program_v1(capability,
        capability.roots.f, points)
    @test source_values.status === :ready
    @test source_values.values == (1.0, 1.0, 1.0, 1.0)
    q_parameter_ref = _DCCE.FieldParameterRefV1("thermal_slab_q_runtime_v1")
    q_profile = runtime.g1_runtime_source_density_parameter_v1(capability;
        parameter_ref=q_parameter_ref, q_bounds_W_m3=(0.0, 2.0))
    q_bounds = _DCCE.QuantityIntervalV1(
        _DCCE.ExactFiniteIntervalV1(0//1, 2//1, false), capability.source_law.f_type.units)
    q_transform = _DCCE.ParameterTransformSpecV1(_DCCE.transform_linear)
    q_gene = _DCCE.FieldParameterGeneV1(q_parameter_ref,
        capability.source_law.f_type.units, q_transform, q_bounds, 0.0)
    q_input = runtime.g1_runtime_source_density_input_v1(q_profile, q_gene)
    q_dynamic = runtime.evaluate_g1_runtime_source_density_v1(capability,
        q_profile, q_input, points)
    @test q_input.q_W_m3 == 1.0
    @test_throws ArgumentError runtime._g1_runtime_q_positive_q0_v1(0.0)
    @test q_dynamic.values == (1.0, 1.0, 1.0, 1.0)
    g3_temperature_source = _THERMAL_SLAB_CONSUMER.thermal_temperature_source_density_input_v1(
        thermal_input, 300.25)
    @test g3_temperature_source.status === :ready
    @test g3_temperature_source.claim_ceiling === :screen_only
    @test g3_temperature_source.controller_id == "candidate_thermal_supervisor"
    @test g3_temperature_source.sensor_port_id == "core_temperature"
    @test g3_temperature_source.actuator_port_id == "source_fraction_command"
    @test g3_temperature_source.sensor_unit == _DCCE.UnitSignature((0,0,0,0,1,0,0))
    @test g3_temperature_source.actuator_unit == _DCCE.UnitSignature()
    @test g3_temperature_source.temperature_K == 300.25
    @test g3_temperature_source.q_W_m3 == 1.75
    @test g3_temperature_source.actuator_fraction ≈ 5/6 atol=1e-12 rtol=0
    @test g3_temperature_source.g1_evaluation.values == (1.75, 1.75, 1.75, 1.75)
    @test g3_temperature_source.resource_link_id == "thermal_supervisor_source_supply_current"
    @test g3_temperature_source.resource_port_id == "source_supply_current"
    g3_record = only(filter(r -> r.layer === :G3, actual.records.declarations))
    child_design = g3_record.semantic_body.body.authored_child_design
    # Exercise the same source-profile admission used after the public T0 byte
    # proof, with only its typed link removed.
    without_feedback_link = merge(child_design, (control_resource_links=(),))
    @test_throws ArgumentError _THERMAL_SLAB_CONSUMER._thermal_admit_temperature_source_profile_v1(
        thermal_input, g3_record, without_feedback_link, 300.25)
    control = child_design.control
    wrong_unit_signals = Tuple(signal.port_id == "source_fraction_command" ?
        _DCCE.G3ControlSignalV1(signal.port_id, signal.signal_kind, signal.direction,
            _DCCE.UnitSignature((0, 0, 1, 0, 0, 0, 0)), signal.account_id) : signal
        for signal in control.signal_ports)
    wrong_unit_control = _DCCE.G3ControlSourceBodyV1(control.source_id,
        control.owner_scope, wrong_unit_signals, control.controllers, control.faults,
        control.plan)
    wrong_unit_child = merge(child_design, (control=wrong_unit_control,))
    @test_throws ArgumentError _THERMAL_SLAB_CONSUMER._thermal_admit_temperature_source_profile_v1(
        thermal_input, g3_record, wrong_unit_child, 300.25)
    @test_throws ArgumentError _THERMAL_SLAB_CONSUMER.thermal_temperature_source_density_input_v1(
        thermal_input, NaN)
    feedback_step = _THERMAL_SLAB_CONSUMER.execute_steady_planar_thermal_feedback_step_v1(
        built.candidate_ref,
            built.g1.declaration, built.g2.declaration, built.g3.declaration,
            actual.t0.transport, actual.spatial)
    @test feedback_step.temperature_source_feedback.status === :screen_only
    @test feedback_step.temperature_source_feedback.fixed_point_converged === false
    @test feedback_step.temperature_source_feedback.iteration_count == 1
    @test feedback_step.temperature_source_feedback.seed_solver_invocations == 1
    @test feedback_step.temperature_source_feedback.response_solver_invocations == 1
    @test feedback_step.temperature_source_feedback.seed_temperature_K ≈ 300.25 atol=1e-12 rtol=0
    @test feedback_step.temperature_source_feedback.q_W_m3 ≈ 1.75 atol=1e-12 rtol=0
    @test feedback_step.temperature_source_feedback.actuator_fraction ≈ 5/6 atol=1e-12 rtol=0
    @test collect(feedback_step.volume_source_W_m3) ≈ collect((1.75, 1.75, 1.75, 1.75)) atol=1e-12 rtol=0
    @test collect(feedback_step.temperature_K) ≈ collect((300.21875, 300.4375, 300.4375, 300.21875)) atol=1e-12 rtol=0
    @test feedback_step.outward_fourier_flux_left_W_m2 ≈ 1.75 atol=1e-12 rtol=0
    @test feedback_step.outward_fourier_flux_right_W_m2 ≈ 1.75 atol=1e-12 rtol=0
    @test feedback_step.integrated_source_W ≈ 3.5 atol=1e-12 rtol=0
    @test feedback_step.energy_balance_residual_W ≈ 0.0 atol=1e-12 rtol=0
    # Route the authenticated G3 feedback q into the optional 3-D Gridap source.
    gridap_route = getfield(runtime, :run_g1_thermal_q1_gridap_v1)
    runtime_profile = g3_temperature_source.g1_profile
    runtime_q_input = g3_temperature_source.g1_input
    runtime_q_result = Base.invokelatest(gridap_route, dgd_input;
        quadrature_degree=4, source_density_profile=runtime_profile,
        source_density_runtime_input=runtime_q_input)
    @test (runtime_q_result.status, runtime_q_result.resolution,
        runtime_q_result.accepted, runtime_q_result.claim_ceiling) ==
        (:executed, :screen_only, false, :screen_only)
    @test runtime_q_result.candidate_ref == built.candidate_ref
    @test runtime_q_result.solver_invocations == 1
    @test runtime_q_result.source_density_w_m3 ==
        feedback_step.temperature_source_feedback.q_W_m3 == 1.75
    runtime_source = runtime_q_result.runtime_source_density
    @test runtime_source.profile_hash == runtime_profile.profile_hash
    @test runtime_source.input_hash == runtime_q_input.input_hash
    @test runtime_source.parameter_hash == runtime_q_input.parameter_hash
    @test runtime_source.evaluation_hash isa _DCCE.Digest256
    @test runtime_source.q_W_m3 == runtime_q_input.q_W_m3 == 1.75
    @test runtime_source.unit == _DCCE.UnitSignature((-1,1,-3,0,0,0,0))
    @test runtime_q_result.typed_source_temperature_scope === :frozen_g1_u_q0_reference
    @test runtime_q_result.nodal_source_comparison_scope === :q0_baseline_only
    @test runtime_q_result.nodal_source_comparison_q0_W_m3 == 1.0
    @test size(runtime_q_result.matrix) == (12,12)
    @test length(runtime_q_result.free_theta_values) == 12
    @test maximum(abs.(runtime_q_result.matrix *
        collect(runtime_q_result.free_theta_values) - collect(runtime_q_result.rhs))) <= 1e-12
    # Independent constant-Kxx extrusion oracle: -2*T''=q on x∈[0,2],
    # with T=300 K at both ends; Kyy(y) is orthogonal to this y-invariant solution.
    expected_runtime_T = Tuple(300.0 + 1.75*x*(2.0-x)/(2.0*2.0)
        for (x,y,z) in runtime_q_result.physical_nodes)
    @test length(runtime_q_result.temperature_nodes_k) == 20
    @test all(isapprox(t, expected; atol=1e-10, rtol=0.0)
        for (t,expected) in zip(runtime_q_result.temperature_nodes_k, expected_runtime_T))
    @test isfinite(runtime_q_result.residual_abs) && runtime_q_result.residual_abs <= 1e-12
    runtime_energy = runtime_q_result.energy_balance
    @test runtime_energy.status === :pass
    @test runtime_energy.tolerance_w == 1.0e-12
    @test runtime_energy.source_power_integral_w ≈ 3.5 atol=1e-12 rtol=0
    @test runtime_energy.dirichlet_reaction_sum_w ≈ -3.5 atol=1e-12 rtol=0
    @test abs(runtime_energy.source_power_balance_defect_w) <= 1e-12
    @test runtime_energy.interior_reaction_linf_w <= 1e-12
    @test runtime_energy.interior_residual_match_linf_w <= 1e-12
    runtime_q0_result = Base.invokelatest(gridap_route, dgd_input; quadrature_degree=4)
    @test runtime_energy.dof_partition_hash ==
        runtime_q0_result.energy_balance.dof_partition_hash
    @test runtime_q_result.authority_scope === :g1_g2_source_bound_only
    println("UP2_G1_THERMAL_GRIDAP_RUNTIME_SOURCE=", JSON3.write((
        candidate_ref=string(runtime_q_result.candidate_ref),
        profile_hash=runtime_source.profile_hash,
        input_hash=runtime_source.input_hash,
        parameter_hash=runtime_source.parameter_hash,
        evaluation_hash=runtime_source.evaluation_hash,
        q_W_m3=runtime_source.q_W_m3, unit=runtime_source.unit,
        temperatures_K=runtime_q_result.temperature_nodes_k,
        residual_abs=runtime_q_result.residual_abs,
        energy_balance=runtime_q_result.energy_balance,
        solver_invocations=runtime_q_result.solver_invocations,
        numerical_scope=runtime_q_result.numerical_scope,
        authority_scope=runtime_q_result.authority_scope)))
    flush(stdout)

    @test_throws ArgumentError Base.invokelatest(gridap_route, dgd_input;
        quadrature_degree=4, source_density_profile=runtime_profile)
    @test_throws ArgumentError Base.invokelatest(gridap_route, dgd_input;
        quadrature_degree=4, source_density_runtime_input=runtime_q_input)
    # Use a self-consistent runtime profile/input from the cached alternate K22 case.
    foreign_actual = _thermal_source_case(_THERMAL_SLAB_K22_CANDIDATE_DIR)
    foreign_dgd_input = _DCCE.dgd_input_v1(foreign_actual.built.candidate_ref,
        foreign_actual.built.g1.declaration, foreign_actual.built.g2.declaration,
        foreign_actual.built.g3.declaration, foreign_actual.t0.transport)
    foreign_capability = _DCCE._dgd_g1_typed_source_capability_v1(foreign_dgd_input)
    foreign_parameter_ref = _DCCE.FieldParameterRefV1("gridap_foreign_q_v1")
    foreign_profile = Base.invokelatest(
        getfield(runtime, :g1_runtime_source_density_parameter_v1), foreign_capability;
        parameter_ref=foreign_parameter_ref, q_bounds_W_m3=(0.0,2.0))
    foreign_bounds = _DCCE.QuantityIntervalV1(
        _DCCE.ExactFiniteIntervalV1(0//1,2//1,false), foreign_profile.unit)
    foreign_gene = _DCCE.FieldParameterGeneV1(foreign_parameter_ref,
        foreign_profile.unit, _DCCE.ParameterTransformSpecV1(_DCCE.transform_linear),
        foreign_bounds, 0.75)
    foreign_q_input = Base.invokelatest(
        getfield(runtime, :g1_runtime_source_density_input_v1),
        foreign_profile, foreign_gene)
    @test foreign_profile.candidate_ref == foreign_actual.built.candidate_ref
    @test foreign_profile.candidate_ref != built.candidate_ref
    @test foreign_q_input.q_W_m3 == 1.75
    @test_throws ArgumentError Base.invokelatest(gridap_route, dgd_input;
        quadrature_degree=4, source_density_profile=foreign_profile,
        source_density_runtime_input=foreign_q_input)
    # Changed G1 f program cannot reuse the original source-profile proof.
    @test_throws ArgumentError begin
        bad_f = _DCCE.G1DiffusionScalarFieldV1(built.g1.declaration.f.field_id,
            built.g1.declaration.f.physical_type, built.g1.declaration.f.source_ref;
            source_expression="f_candidate(x)=2")
        bad_g1 = _DCCE.g1_diffusion_edit_source(built.g1.declaration, :f, bad_f)
        bad_program_input = _DCCE.dgd_input_v1(built.candidate_ref, bad_g1,
            built.g2.declaration, built.g3.declaration, actual.t0.transport)
        Base.invokelatest(gridap_route, bad_program_input; quadrature_degree=4,
            source_density_profile=runtime_profile,
            source_density_runtime_input=runtime_q_input)
    end
    # Re-hash an otherwise typed runtime input to ensure the evaluator enforces q bounds.
    narrow_profile = Base.invokelatest(
        getfield(runtime, :g1_runtime_source_density_parameter_v1), capability;
        parameter_ref=runtime_profile.parameter_ref, q_bounds_W_m3=(0.0,1.5))
    out_of_bounds_body = (profile_hash=narrow_profile.profile_hash,
        parameter_hash=runtime_q_input.parameter_hash,
        q_W_m3=runtime_q_input.q_W_m3, unit=narrow_profile.unit)
    runtime_input_type = getfield(runtime, :G1RuntimeSourceDensityInputV1)
    out_of_bounds_input = Base.invokelatest(runtime_input_type,
        narrow_profile.profile_hash, runtime_q_input.parameter_hash,
        runtime_q_input.q_W_m3, narrow_profile.unit,
        _DCCE.canonical_hash(out_of_bounds_body))
    @test_throws ArgumentError Base.invokelatest(gridap_route, dgd_input;
        quadrature_degree=4, source_density_profile=narrow_profile,
        source_density_runtime_input=out_of_bounds_input)
    if feedback_step.temperature_source_feedback.status === :screen_only &&
            feedback_step.temperature_source_feedback.fixed_point_converged === false
        println("UP3_TEMPERATURE_FEEDBACK_STEP=", (
            candidate=(id=feedback_step.candidate_ref.id,
                version=feedback_step.candidate_ref.version),
            source_bundle_hash=feedback_step.source_bundle_hash,
            source_profile_hash=feedback_step.temperature_source_feedback.source_profile_hash,
            source_record_hash=feedback_step.temperature_source_feedback.source_record_hash,
            seed_temperature_K=feedback_step.temperature_source_feedback.seed_temperature_K,
            q_W_m3=feedback_step.temperature_source_feedback.q_W_m3,
            actuator_fraction=feedback_step.temperature_source_feedback.actuator_fraction,
            response_temperature_K=feedback_step.temperature_K,
            integrated_source_W=feedback_step.integrated_source_W,
            outward_boundary_heat_loss_W=feedback_step.outward_boundary_heat_loss_W,
            energy_balance_residual_W=feedback_step.energy_balance_residual_W,
            fixed_point_converged=feedback_step.temperature_source_feedback.fixed_point_converged,
            result_hash=feedback_step.result_hash))
        flush(stdout)
    end
    # Solve the source-authored law against the independent 4-cell FV maximum:
    # Tmax(q)=T0+q*L^2/(8*Kxx), q=clamp(q0+gain*(setpoint-Tmax),qmin,qmax).
    feedback_law = g3_record.semantic_body.body.authored_child_design.
        control_design.temperature_source_feedback
    q0 = Float64(feedback_law.q0_w_m3)
    gain = Float64(feedback_law.gain_w_m3_per_kelvin)
    setpoint = Float64(feedback_law.setpoint_kelvin)
    qmin, qmax = Float64(feedback_law.q_min_w_m3), Float64(feedback_law.q_max_w_m3)
    t0 = Float64(capability.source_law.T0_K)
    length_m = Float64(capability.source_law.L_m)
    kxx = Float64(capability.source_law.Kxx_W_mK)
    fv_max_rise_per_q = length_m^2 / (8.0 * kxx)
    q_fixed_expected = clamp((q0 + gain * (setpoint - t0)) /
        (1.0 + gain * fv_max_rise_per_q), qmin, qmax)
    @test q_fixed_expected == 1.6
    fixed_protocol = _DCCE.CompositionSolveProtocolV1(
        _DCCE.canonical_hash((test_protocol=:thermal_slab_up3_fixed_point_v1,)),
        24, 1e-12)
    fixed = _THERMAL_SLAB_CONSUMER.execute_steady_planar_thermal_fixed_point_v1(
        built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, actual.t0.transport, actual.spatial, fixed_protocol)
    fixed_summary = fixed.temperature_source_fixed_point
    @test fixed.status === :screen_only
    @test fixed.accepted === false
    @test fixed.claim_ceiling === :screen_only
    @test fixed.physical_validation === false
    @test fixed.engineering_validation === false
    @test fixed.evidence_credit == 0
    @test result.status === :screen_only && result.accepted === false
    @test result.volume_source_W_m3 == (1.0, 1.0, 1.0, 1.0)
    @test all(==(first(result.volume_source_W_m3)), result.volume_source_W_m3)
    @test result.integrated_source_W == 2.0
    @test fixed.volume_source_W_m3 != result.volume_source_W_m3
    @test fixed.integrated_source_W != result.integrated_source_W
    @test fixed_summary.fixed_point_converged === true
    @test fixed_summary.termination === :residual_tolerance
    @test fixed_summary.residual_tolerance == 1e-12
    @test fixed_summary.residual_tolerance_unit == _DCCE.UnitSignature((-1,1,-3,0,0,0,0))
    @test fixed_summary.residual <= 1e-12
    @test fixed_summary.applied_q_W_m3 ≈ q_fixed_expected atol=1e-12 rtol=0
    @test fixed_summary.next_q_W_m3 ≈ q_fixed_expected atol=1e-12 rtol=0
    @test fixed_summary.solver_invocation_count == fixed_summary.iteration_count
    @test fixed_summary.iteration_count > 1
    cell_centers = (0.25, 0.75, 1.25, 1.75)
    cell_width_m = 0.5
    fv_expected_temperature = ntuple(i -> t0 + q_fixed_expected *
        cell_centers[i] * (length_m - cell_centers[i]) / (2.0 * kxx) +
        q_fixed_expected * cell_width_m^2 / (8.0 * kxx), 4)
    @test collect(fixed.temperature_K) ≈ collect(fv_expected_temperature) atol=1e-12 rtol=0
    @test all(isapprox(value, q_fixed_expected; atol=1e-12, rtol=0) for value in fixed.volume_source_W_m3)
    expected_end_flux_W_m2 = q_fixed_expected * length_m / 2.0
    @test fixed.outward_fourier_flux_left_W_m2 ≈ expected_end_flux_W_m2 atol=1e-12 rtol=0
    @test fixed.outward_fourier_flux_right_W_m2 ≈ expected_end_flux_W_m2 atol=1e-12 rtol=0
    cross_section_area_m2 = Float64(chart.jacobian_rows[2][2] *
        (chart.domain_upper[2] - chart.domain_lower[2])) *
        Float64(chart.jacobian_rows[3][3] *
        (chart.domain_upper[3] - chart.domain_lower[3]))
    expected_energy_W = fixed_summary.applied_q_W_m3 * length_m * cross_section_area_m2
    energy_oracle_atol_W = 1e-12 * length_m * cross_section_area_m2
    @test energy_oracle_atol_W == 2e-12
    @test fixed.integrated_source_W ≈ expected_energy_W atol=1e-12 rtol=0
    @test fixed.integrated_source_W ≈ 3.2 atol=energy_oracle_atol_W rtol=0
    @test fixed.outward_boundary_heat_loss_W ≈ expected_energy_W atol=1e-12 rtol=0
    @test fixed.outward_boundary_heat_loss_W ≈ 3.2 atol=energy_oracle_atol_W rtol=0
    @test fixed.energy_balance_residual_W ≈ 0.0 atol=1e-12 rtol=0
    cap_protocol = _DCCE.CompositionSolveProtocolV1(
        _DCCE.canonical_hash((test_protocol=:thermal_slab_up3_fixed_point_cap_v1,)),
        1, 1e-12)
    capped = _THERMAL_SLAB_CONSUMER.execute_steady_planar_thermal_fixed_point_v1(
        built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, actual.t0.transport, actual.spatial, cap_protocol)
    @test capped.status === :terminal_deferred
    @test capped.temperature_source_fixed_point.fixed_point_converged === false
    @test capped.temperature_source_fixed_point.termination === :iteration_limit
    @test capped.temperature_source_fixed_point.iteration_count == 1
    @test capped.temperature_source_fixed_point.solver_invocation_count == 1
    fail_closed_cap_protocol = _DCCE.CompositionSolveProtocolV1(
        _DCCE.canonical_hash((test_protocol=:thermal_slab_up3_fixed_point_fail_closed_cap_v1,)),
        1, 1e-12; nonconvergent_policy=:fail_closed)
    fail_closed_cap = _THERMAL_SLAB_CONSUMER.execute_steady_planar_thermal_fixed_point_v1(
        built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, actual.t0.transport, actual.spatial, fail_closed_cap_protocol)
    @test fail_closed_cap.status === :fail_closed
    @test fail_closed_cap.temperature_source_fixed_point.fixed_point_converged === false
    @test fail_closed_cap.temperature_source_fixed_point.termination === :iteration_limit
    @test fail_closed_cap.temperature_source_fixed_point.iteration_count == 1
    @test_throws ArgumentError _DCCE.CompositionSolveProtocolV1(
        _DCCE.canonical_hash((test_protocol=:thermal_slab_up3_fixed_point_bad_count_v1,)),
        0, 1e-12)
    @test_throws ArgumentError _DCCE.CompositionSolveProtocolV1(
        _DCCE.canonical_hash((test_protocol=:thermal_slab_up3_fixed_point_bad_tolerance_v1,)),
        4, 0.0)
    @test_throws ArgumentError _DCCE.CompositionSolveProtocolV1(
        _DCCE.canonical_hash((test_protocol=:thermal_slab_up3_fixed_point_nonfinite_tolerance_v1,)),
        4, NaN)
    println("UP3_TEMPERATURE_FIXED_POINT=", (
        candidate=(id=fixed.candidate_ref.id, version=fixed.candidate_ref.version),
        source_bundle_hash=fixed.source_bundle_hash,
        source_profile_hash=fixed_summary.g3_source_profile_hash,
        source_record_hash=fixed_summary.g3_source_record_hash,
        max_iterations=fixed_summary.max_iterations, iteration_count=fixed_summary.iteration_count,
        residual_tolerance_W_m3=fixed_summary.residual_tolerance,
        residual_W_m3=fixed_summary.residual, applied_q_W_m3=fixed_summary.applied_q_W_m3,
        next_q_W_m3=fixed_summary.next_q_W_m3, temperature_K=fixed.temperature_K,
        source_W_m3=fixed.volume_source_W_m3, integrated_source_W=fixed.integrated_source_W,
        outward_boundary_heat_loss_W=fixed.outward_boundary_heat_loss_W,
        energy_balance_residual_W=fixed.energy_balance_residual_W,
        iteration_trace=fixed_summary.iteration_trace,
        cap=(status=capped.status, termination=capped.temperature_source_fixed_point.termination,
            iteration_count=capped.temperature_source_fixed_point.iteration_count),
        fail_closed_cap=(status=fail_closed_cap.status,
            termination=fail_closed_cap.temperature_source_fixed_point.termination),
        nonconvergent_policy=fixed_summary.nonconvergent_policy,
        physical_validation=fixed.physical_validation,
        engineering_validation=fixed.engineering_validation, evidence_credit=fixed.evidence_credit,
        no_feedback_baseline=(q_W_m3=first(result.volume_source_W_m3),
            integrated_source_W=result.integrated_source_W),
        result_hash=fixed.result_hash))
    flush(stdout)
    _thermal_assert_disconnected_feedback_trace_guard_v1(actual, result)
    wrong_q_bounds = _DCCE.QuantityIntervalV1(
        _DCCE.ExactFiniteIntervalV1(0//1, 3//1, false), capability.source_law.f_type.units)
    wrong_q_gene = _DCCE.FieldParameterGeneV1(q_parameter_ref,
        capability.source_law.f_type.units, q_transform, wrong_q_bounds, 0.0)
    @test_throws ArgumentError runtime.g1_runtime_source_density_input_v1(
        q_profile, wrong_q_gene)
    wrong_q_unit = _DCCE.UnitSignature((0, 1, -3, 0, 0, 0, 0))
    wrong_unit_gene = _DCCE.FieldParameterGeneV1(q_parameter_ref,
        wrong_q_unit, q_transform,
        _DCCE.QuantityIntervalV1(_DCCE.ExactFiniteIntervalV1(0//1, 2//1, false), wrong_q_unit),
        0.0)
    @test_throws ArgumentError runtime.g1_runtime_source_density_input_v1(
        q_profile, wrong_unit_gene)
    @test_throws ArgumentError runtime.evaluate_g1_typed_source_program_v1(
        capability, capability.roots.u, ((1.01, 0.5, 0.5),))
end
flush(stdout)

@testset "current-source thermal source rejects mismatched typed declarations" begin
    actual = _thermal_source_case()
    built, transport, spatial = actual.built, actual.t0.transport, actual.spatial
    g1, g2, g3 = built.g1.declaration, built.g2.declaration, built.g3.declaration
    g1_record = only(filter(r -> r.layer === :G1, actual.records.declarations))
    authored_input = g1_record.semantic_body.body.authored_builder_input
    bad_byte_count = merge(authored_input, (byte_count=authored_input.byte_count + 1,))
    @test_throws ArgumentError _DCCE._dgd_current_source_authored_input_v1(
        g1_record, bad_byte_count; expected_filename="g1_source.jl")
    wrong_u_type = _DCCE.PhysicalType(:scalar_field, 0, 3,
        g1.u.physical_type.temporal_type, _DCCE.UnitSignature())
    wrong_grad_type = _DCCE.PhysicalType(:vector_field, 1, 3,
        g1.u.physical_type.temporal_type, _DCCE.UnitSignature((-1,0,0,0,0,0,0)))
    wrong_flux_type = _DCCE.PhysicalType(:vector_field, 1, 3,
        g1.u.physical_type.temporal_type, _DCCE.UnitSignature((0,1,-3,0,-1,0,0)))
    wrong_f_type = _DCCE.PhysicalType(:scalar_field, 0, 3,
        g1.u.physical_type.temporal_type, _DCCE.UnitSignature((-1,1,-3,0,-1,0,0)))
    wrong_u = _DCCE.G1DiffusionScalarFieldV1(g1.u.field_id, wrong_u_type,
        g1.u.source_ref; source_expression=g1.u.source_expression)
    wrong_f = _DCCE.G1DiffusionScalarFieldV1(g1.f.field_id, wrong_f_type,
        g1.f.source_ref; source_expression=g1.f.source_expression)
    wrong_grad = _DCCE.G1TypedGradV1(g1.operators.grad.operator_ref,
        wrong_u.field_id, g1.operators.grad.output_field_id,
        wrong_u_type, wrong_grad_type)
    wrong_k_apply = _DCCE.G1TypedKApplyV1(g1.operators.coefficient_apply.operator_ref,
        wrong_grad.output_field_id, g1.operators.coefficient_apply.output_field_id,
        wrong_grad_type, wrong_flux_type, g1.K.field_id;
        coefficient_units=g1.K.physical_type.units)
    wrong_div = _DCCE.G1TypedDivV1(g1.operators.div.operator_ref,
        wrong_k_apply.output_field_id, wrong_f.field_id,
        wrong_flux_type, wrong_f_type)
    wrong_operators = _DCCE.G1DiffusionOperatorChainV1(wrong_grad,
        wrong_k_apply, wrong_div, wrong_f.field_id;
        residual_sign=g1.operators.residual_sign)
    old_binding = g1.source_payload.unknown_state_binding
    wrong_binding = _DCCE.G1DiffusionUnknownStateBindingV1(old_binding.state_index,
        old_binding.role, wrong_u.field_id, wrong_u_type)
    wrong_payload = _DCCE.G1DiffusionSourcePayloadV1(g1.candidate_ref,
        g1.source_ref, g1.source_version, wrong_u, g1.K, wrong_f;
        unknown_state_binding=wrong_binding,
        operator_temporal_support=g1.source_payload.operator_temporal_support,
        interface_flux_pair=g1.source_payload.interface_flux_pair)
    wrong_g1 = _DCCE.g1_diffusion_declaration_v1(g1.candidate_ref,
        g1.source_ref, g1.source_version,
        _DCCE.g1_diffusion_source_hash_v1(wrong_payload), wrong_u, g1.K,
        wrong_f, wrong_operators, g1.closure_ref, g1.applicability_ref,
        g1.applicability_domain, g1.negative_controls;
        ownership=g1.ownership, source_payload=wrong_payload)
    @test _DCCE.g1_diffusion_validate(wrong_g1)[1] === :valid
    @test wrong_g1.u.physical_type.units != g1.u.physical_type.units
    @test_throws ArgumentError _THERMAL_SLAB_CONSUMER.execute_steady_planar_thermal_diffusion_v1(
        built.candidate_ref, wrong_g1, g2, g3, transport, spatial)

    wrong_xmax = _DCCE.G2MBFaceValueV1(:dirichlet, 301//1,
        _DCCE.UnitSignature((0,0,0,0,1,0,0)))
    wrong_g2 = _DCCE.g2mb_edit_source(g2, :face_value, ("thermal_x_max", wrong_xmax))
    @test_throws ArgumentError _THERMAL_SLAB_CONSUMER.execute_steady_planar_thermal_diffusion_v1(
        built.candidate_ref, g1, wrong_g2, g3, transport, spatial)

    c = g2.source.chart_map
    wrong_chart = _DCCE.G2MBChartMapV1(c.chart_ref, c.domain_lower, c.domain_upper,
        ((3//1,0//1,0//1),(0//1,1//1,0//1),(0//1,0//1,1//1)), c.offset;
        map_kind=c.map_kind, axes=c.axes)
    wrong_chart_g2 = _DCCE.g2mb_edit_source(g2, :chart_map, wrong_chart)
    @test_throws ArgumentError _THERMAL_SLAB_CONSUMER.execute_steady_planar_thermal_diffusion_v1(
        built.candidate_ref, g1, wrong_chart_g2, g3, transport, spatial)
end
flush(stdout)

@testset "typed candidate K edit changes the same source-bound thermal slab solve" begin
    base = _thermal_source_case()
    edited = _thermal_source_case(_THERMAL_SLAB_K22_CANDIDATE_DIR)
    base_g1 = base.built.g1.declaration
    edited_g1 = edited.built.g1.declaration
    @test base.built.candidate_ref != edited.built.candidate_ref
    @test base.built.identity.scenario_ref == edited.built.identity.scenario_ref
    @test base_g1.K.expression.base_diag == (2//1, 3//1, 4//1)
    @test edited_g1.K.expression.base_diag == (11//5, 3//1, 4//1)
    @test edited_g1.K.expression.slope_diag == base_g1.K.expression.slope_diag ==
        (0//1, 1//10, 0//1)
    @test base_g1.u.source_expression == edited_g1.u.source_expression ==
        "u_candidate_steady_planar_quadratic_diffusion_v1"
    @test base_g1.f.source_expression == edited_g1.f.source_expression == "f(x)=1"
    @test base.built.g2.declaration.source.chart_map.jacobian_rows ==
        edited.built.g2.declaration.source.chart_map.jacobian_rows ==
        ((2//1,0//1,0//1),(0//1,1//1,0//1),(0//1,0//1,1//1))
    for actual in (base, edited)
        faces = Dict(face.face => face for face in actual.built.g2.declaration.source.faces)
        @test faces[:x_min].value.kind === :dirichlet
        @test faces[:x_min].value.value == faces[:x_max].value.value == 300//1
        @test all(faces[face].value.kind === :neumann &&
            iszero(faces[face].value.value) for face in (:y_min,:y_max,:z_min,:z_max))
    end
    @test base_g1.source_hash != edited_g1.source_hash
    @test base_g1.declaration_hash != edited_g1.declaration_hash
    @test base.built.g1.source_ref != edited.built.g1.source_ref
    @test base.t0.transport.status === edited.t0.transport.status === :valid
    @test base.current.status === edited.current.status === :prepared_not_executed

    function solve(actual)
        built, g1, g2, g3 = actual.built, actual.built.g1.declaration,
            actual.built.g2.declaration, actual.built.g3.declaration
        _THERMAL_SLAB_CONSUMER.execute_steady_planar_thermal_diffusion_v1(
            built.candidate_ref, g1, g2, g3, actual.t0.transport, actual.spatial)
    end
    result_a, result_b = solve(base), solve(edited)
    @test result_a.status === result_b.status === :screen_only
    @test result_a.accepted === result_b.accepted === false
    @test result_a.evidence_credit == result_b.evidence_credit == 0
    @test collect(result_a.temperature_K) ≈ collect((300.125, 300.25, 300.25, 300.125)) atol=1e-12
    @test collect(result_b.temperature_K) ≈ collect(ntuple(i ->
        300.0 + (10/11) * (result_a.temperature_K[i] - 300.0), 4)) atol=1e-12
    @test result_b.temperature_K != result_a.temperature_K
    @test result_a.integrated_source_per_area_W_m2 ≈ 2.0 atol=1e-12
    @test result_b.integrated_source_per_area_W_m2 ≈ result_a.integrated_source_per_area_W_m2 atol=1e-12
    @test result_b.outward_fourier_flux_left_W_m2 ≈ result_a.outward_fourier_flux_left_W_m2 atol=1e-12
    @test result_b.outward_fourier_flux_right_W_m2 ≈ result_a.outward_fourier_flux_right_W_m2 atol=1e-12
    @test result_b.physical_validation === result_a.physical_validation === false
    @test result_b.engineering_validation === result_a.engineering_validation === false
end
flush(stdout)

@testset "UP3 source-bound composition reaches the existing SI slab consumer" begin
    source_variant = _thermal_materialize_source_variant_v1(_DCCE_ROOT, _THERMAL_SLAB_CANDIDATE_DIR, :base_no_law)
    actual = _thermal_source_case(source_variant.candidate_directory; source_root=source_variant.source_root)
    candidate = actual.built.candidate_ref
    g1, g2, g3 = actual.built.g1.declaration, actual.built.g2.declaration,
        actual.built.g3.declaration
    bundle, spatial = actual.t0.transport, actual.spatial
    protocol = _DCCE.CompositionSolveProtocolV1(
        _DCCE.canonical_hash((test_protocol=:thermal_slab_up3_v1,)), 4, 1e-12)
    admission = _THERMAL_SLAB_CONSUMER.up3_steady_planar_composition_admit_v1(
        candidate, g1, g2, g3, bundle, spatial, protocol;
        subject_ref=_DCCE.canonical_hash((test_subject=:thermal_slab,)),
        mission_ref=_DCCE.canonical_hash((test_mission=:static_slab_screen,)),
        scenario_ref=_DCCE.canonical_hash((test_scenario=:uniform_generation,)))
    @test admission.outcome.status === :ready
    @test admission.plan.status === :ready
    @test length(admission.plan.edges) == 5
    @test admission.receipt.claim_ceiling === :contract_only

    result = _THERMAL_SLAB_CONSUMER.execute_up3_steady_planar_composition_v1(
        candidate, g1, g2, g3, bundle, spatial, admission)
    println("UP3_COMPOSITION_FAILURE_DETAILS=", JSON3.write(result.composition_execution))
    flush(stdout)
    @test result.status === :screen_only
    @test result.claim_ceiling === :screen_only
    @test result.feedback_status === :typed_absent
    @test result.feedback_reason === :unsupported_feedback_scope
    @test result.provider_invocation_count == 0
    @test result.solver_invocation_count == 1
    @test result.physical_validation === false
    @test result.engineering_validation === false
    @test result.evidence_credit == 0
    # The SI unit exponent basis here is (m, kg, s, A, K, mol, cd).
    balance = result.heat_power_balance
    watt = _DCCE.UnitSignature((2, 1, -3, 0, 0, 0, 0))
    @test balance.schema == "fusionconceptai:runtime-v4:steady-planar-heat-power-balance-v1"
    @test balance.candidate_ref == candidate
    @test balance.g1_body_hash == result.g1_body_hash
    @test balance.g2_body_hash == result.g2_body_hash
    @test balance.g2_chart_hash == _DCCE.canonical_hash(g2.source.chart_map)
    @test balance.unit == watt
    @test balance.generated_source.unit == balance.outward_boundary_power.unit ==
        balance.balance_residual.unit == watt
    @test balance.generated_source.value == result.integrated_source_W == 2.0
    @test balance.outward_boundary_power.value == result.outward_boundary_heat_loss_W == 2.0
    @test isapprox(balance.balance_residual.value, 0.0; atol=1e-10, rtol=0.0)
    @test isapprox(result.energy_balance_residual_W, 0.0; atol=1e-10, rtol=0.0)
    @test length(balance.terms) == 3
    source_term, x_min_term, x_max_term = balance.terms
    @test source_term.term === :volumetric_source
    @test source_term.ledger_sign == 1
    @test source_term.power.unit == watt && source_term.power.value == 2.0
    @test source_term.source_ref == g1.source_ref
    @test source_term.source_hash == balance.g1_body_hash
    @test source_term.support_hash == balance.g2_chart_hash
    for (term, face, term_id, expected_power) in ((x_min_term, :x_min,
            :outward_boundary_x_min, result.outward_heat_power_left_W),
            (x_max_term, :x_max, :outward_boundary_x_max,
             result.outward_heat_power_right_W))
        owner = only(filter(item -> item.face === face, g2.source.faces))
        @test term.term === term_id
        @test term.face === owner.face
        @test term.face_id == owner.face_id
        @test term.owner_region_id == owner.owner_region_id
        @test term.ownership === owner.ownership === :candidate_owned
        @test term.ledger_sign == -1
        @test term.power.unit == watt
        @test isapprox(term.power.value, expected_power; atol=1e-12, rtol=0.0)
    end
    @test isapprox(sum(term.ledger_sign * term.power.value for term in balance.terms),
        0.0; atol=1e-12, rtol=0.0)

    # Remove the matched G1 source-density edge by omitting both endpoints.
    # The resulting four-edge plan can still admit, but the real consumer must
    # reject its node/port set before invoking the thermal solver.
    parts = _THERMAL_SLAB_CONSUMER._up3_slab_components(
        candidate, g1, g2, g3, bundle, spatial)
    g1_node, g2_node, g3_node, t0_node, solver_node = parts.components
    without_source_g1 = _DCCE.CompositionSolveComponentV1(
        g1_node.component_ref, g1_node.provider_ref, g1_node.code_ref,
        g1_node.backend_ref, g1_node.inputs,
        Tuple(port for port in g1_node.outputs if port.slot != 1))
    without_source_solver = _DCCE.CompositionSolveComponentV1(
        solver_node.component_ref, solver_node.provider_ref, solver_node.code_ref,
        solver_node.backend_ref,
        Tuple(port for port in solver_node.inputs if port.slot != 1), solver_node.outputs)
    negative_input = _DCCE.CompositionSolveInputV1(admission.input.binding,
        (without_source_g1, g2_node, g3_node, t0_node, without_source_solver), protocol;
        feedback_edge_keys=admission.input.feedback_edge_keys)
    negative = _DCCE.admit_composition_solve(negative_input)
    @test negative.outcome.status === :ready
    @test length(negative.plan.edges) == 4
    @test negative.plan.provider_invocation_count == 0
    @test negative.plan.solver_invocation_count == 0
    @test_throws ArgumentError _THERMAL_SLAB_CONSUMER.execute_up3_steady_planar_composition_v1(
        candidate, g1, g2, g3, bundle, spatial, negative)
end
flush(stdout)

@testset "UP3 composition propagates the typed G1 K edit through the SI solver" begin
    base_variant = _thermal_materialize_source_variant_v1(_DCCE_ROOT, _THERMAL_SLAB_CANDIDATE_DIR, :base_no_law)
    @test base_variant.candidate_directory == _THERMAL_SLAB_BASE_NO_LAW_DIR
    base = _thermal_source_case(base_variant.candidate_directory; source_root=base_variant.source_root)
    @test !hasproperty(only(filter(r -> r.layer === :G3, base.records.declarations)).semantic_body.body.authored_child_design.control_design, :temperature_source_feedback)
    edited = _thermal_source_case(_THERMAL_SLAB_K22_CANDIDATE_DIR)
    base_g1, edited_g1 = base.built.g1.declaration, edited.built.g1.declaration
    @test base.built.identity.scenario_ref == edited.built.identity.scenario_ref
    @test base.built.candidate_ref != edited.built.candidate_ref
    @test base_g1.K.expression.base_diag == (2//1, 3//1, 4//1)
    @test edited_g1.K.expression.base_diag == (11//5, 3//1, 4//1)
    @test edited_g1.K.expression.slope_diag == base_g1.K.expression.slope_diag ==
        (0//1, 1//10, 0//1)
    @test base_g1.source_ref != edited_g1.source_ref
    @test base_g1.source_hash != edited_g1.source_hash
    @test base_g1.declaration_hash != edited_g1.declaration_hash

    protocol = _DCCE.CompositionSolveProtocolV1(
        _DCCE.canonical_hash((test_protocol=:thermal_slab_up3_k_edit_v1,)), 4, 1e-12)
    subject_ref = _DCCE.canonical_hash((test_subject=:thermal_slab,))
    mission_ref = _DCCE.canonical_hash((test_mission=:static_slab_screen,))
    scenario_ref = _DCCE.canonical_hash(
        _DCCE.semantic_view(base.built.identity.scenario_ref))
    function compose(actual)
        built = actual.built
        candidate = built.candidate_ref
        g1, g2, g3 = built.g1.declaration, built.g2.declaration, built.g3.declaration
        bundle, spatial = actual.t0.transport, actual.spatial
        admission = _THERMAL_SLAB_CONSUMER.up3_steady_planar_composition_admit_v1(
            candidate, g1, g2, g3, bundle, spatial, protocol;
            subject_ref=subject_ref, mission_ref=mission_ref, scenario_ref=scenario_ref)
        @test admission.outcome.status === :ready
        @test admission.plan.status === :ready
        @test length(admission.plan.edges) == 5
        result = _THERMAL_SLAB_CONSUMER.execute_up3_steady_planar_composition_v1(
            candidate, g1, g2, g3, bundle, spatial, admission)
        @test result.status === :screen_only
        @test result.claim_ceiling === :screen_only
        @test result.physical_validation === false
        @test result.engineering_validation === false
        @test result.evidence_credit == 0
        @test result.feedback_status === :typed_absent
        @test result.feedback_reason === :unsupported_feedback_scope
        @test result.provider_invocation_count == 0
        @test result.solver_invocation_count == 1
        (admission=admission, result=result)
    end

    composed_a, composed_b = compose(base), compose(edited)
    result_a, result_b = composed_a.result, composed_b.result
    @test composed_a.admission.input.input_hash != composed_b.admission.input.input_hash
    @test result_a.source_program_audit.g1_source_ref !=
        result_b.source_program_audit.g1_source_ref
    @test result_a.source_program_audit.g1_source_identity_hash !=
        result_b.source_program_audit.g1_source_identity_hash
    @test result_a.source_program_audit.g1_declaration_identity_hash !=
        result_b.source_program_audit.g1_declaration_identity_hash
    law_a, law_b = result_a.source_program_audit.exact_law,
        result_b.source_program_audit.exact_law
    @test law_a.T0_K == law_b.T0_K == 300.0
    @test law_a.q_W_m3 == law_b.q_W_m3 == 1.0
    @test law_a.L_m == law_b.L_m == 2.0
    @test law_a.Kxx_W_mK == 2.0
    @test law_b.Kxx_W_mK == 2.2
    @test collect(result_a.temperature_K) ≈ collect((300.125, 300.25, 300.25, 300.125)) atol=1e-12
    @test collect(result_b.temperature_K) ≈ collect(ntuple(i ->
        300.0 + (10/11) * (result_a.temperature_K[i] - 300.0), 4)) atol=1e-12
    @test result_b.temperature_K != result_a.temperature_K
    @test result_a.volume_source_W_m3 == result_b.volume_source_W_m3 == (1.0, 1.0, 1.0, 1.0)
    @test result_a.integrated_source_per_area_W_m2 ==
        result_b.integrated_source_per_area_W_m2 == 2.0
    @test result_a.integrated_source_W == result_b.integrated_source_W == 2.0
    @test result_a.outward_fourier_flux_left_W_m2 ≈ 1.0 atol=1e-12
    @test result_b.outward_fourier_flux_left_W_m2 ≈ 1.0 atol=1e-12
    @test result_a.outward_fourier_flux_right_W_m2 ≈ 1.0 atol=1e-12
    @test result_b.outward_fourier_flux_right_W_m2 ≈ 1.0 atol=1e-12
    @test result_a.outward_fourier_flux_left_W_m2 ≈ result_b.outward_fourier_flux_left_W_m2 atol=1e-12
    @test result_a.outward_fourier_flux_right_W_m2 ≈ result_b.outward_fourier_flux_right_W_m2 atol=1e-12
    @test result_a.outward_heat_power_left_W + result_a.outward_heat_power_right_W ≈
        result_a.integrated_source_W atol=1e-12
    @test result_b.outward_heat_power_left_W + result_b.outward_heat_power_right_W ≈
        result_b.integrated_source_W atol=1e-12
    if result_a.status === :screen_only && result_b.status === :screen_only &&
        result_a.composition_input_hash == composed_a.admission.input.input_hash &&
        result_b.composition_input_hash == composed_b.admission.input.input_hash &&
        result_a.composition_plan_hash == composed_a.admission.plan.plan_hash &&
        result_b.composition_plan_hash == composed_b.admission.plan.plan_hash
    println("UP3_K22_ACTUAL_SUCCESS ", (
        candidate_hash=(base=_DCCE.canonical_hash(_DCCE.semantic_view(result_a.candidate_ref)),
            edited=_DCCE.canonical_hash(_DCCE.semantic_view(result_b.candidate_ref))),
        source_identity_hash=(base=result_a.source_program_audit.g1_source_identity_hash,
            edited=result_b.source_program_audit.g1_source_identity_hash),
        g2_source_identity_hash=(base=result_a.source_program_audit.g2_source_identity_hash,
            edited=result_b.source_program_audit.g2_source_identity_hash),
        g2_declaration_identity_hash=(base=result_a.source_program_audit.g2_declaration_identity_hash,
            edited=result_b.source_program_audit.g2_declaration_identity_hash),
        source_bundle_hash=(base=result_a.source_bundle_hash, edited=result_b.source_bundle_hash),
        result_hash=(base=result_a.result_hash, edited=result_b.result_hash),
        composition=(base=(input=result_a.composition_input_hash,
                plan=result_a.composition_plan_hash),
            edited=(input=result_b.composition_input_hash,
                plan=result_b.composition_plan_hash)),
        status=(base=result_a.status, edited=result_b.status),
        TA_K=result_a.temperature_K, TB_K=result_b.temperature_K,
        outward_fourier_flux_W_m2=(base=(left=result_a.outward_fourier_flux_left_W_m2,
                right=result_a.outward_fourier_flux_right_W_m2),
            edited=(left=result_b.outward_fourier_flux_left_W_m2,
                right=result_b.outward_fourier_flux_right_W_m2)),
        integrated_source_W=(base=result_a.integrated_source_W,
            edited=result_b.integrated_source_W),
        residual_norm=(base=result_a.residual_norm, edited=result_b.residual_norm)))
    end
    flush(stdout)
end
end # !_THERMAL_Q1_DIAGNOSTIC_ONLY

function _thermal_v5_bound_input(actual; scenario="thermal-slab-screen-queue-v1")
    built, current, independent = actual.built, actual.current, actual.independent
    candidate, transport = built.candidate_ref, actual.t0.transport
    expected = independent.expected
    admission_input = _DCCE.VNextT1AdmissionInputV2(candidate, transport,
        current.recheck,
        ntuple(i -> _DCCE.vnext_t1_parent_commitment_v2(candidate,
            transport.declarations[i]), 2), expected.commitment_hash,
        (status=current.bridge.status, resolution=current.bridge.resolution,
         authority_verified=current.bridge.authority_verified,
         expected_commitment=expected, binding_state=current.bridge.binding_state,
         commitment_hash=expected.commitment_hash))
    admission = current.t1
    admission.status === :prepared_not_executed || error(:thermal_t1_not_prepared)
    package = admission.package
    io = IOBuffer()
    Serialization.serialize(io, package)
    reloaded = Serialization.deserialize(IOBuffer(take!(io)))
    base_adapter = _DCCE.vnext_t1_package_binding_adapter_v2(reloaded)
    adapter = _DCCE.vnext_t1_package_binding_adapter_v2(reloaded,
        (base_adapter.input,))
    adapter.status === :prepared_not_executed && adapter.binding !== nothing ||
        error(:thermal_t1_reload_binding_not_ready)
    witness = current.witness.witness
    software_hash = _DCCE.canonical_hash((domain="thermal-screen-synthetic-software-gate-v1",
        candidate_ref=candidate, witness_hash=witness.witness_hash, scenario=scenario))
    admission_hash = _DCCE.canonical_hash((domain="thermal-screen-synthetic-t1-admission-v1",
        candidate_ref=candidate, package_hash=reloaded.package_hash,
        witness_hash=witness.witness_hash, scenario=scenario))
    gate = _DCCE.vnext_t2_formal_gate_identity_v2(candidate, scenario,
        witness.witness_hash, reloaded.package_hash, reloaded.semantic_identity,
        reloaded.bundle_hash, reloaded.wire.sha256,
        _DCCE.canonical_hash(_DCCE.semantic_view(adapter)),
        adapter.binding.receipt_hash, admission_input.parent_commitments,
        expected.commitment_hash, software_hash, admission_hash;
        evidence_kind=:synthetic_local, formal_t1_accepted=true)
    build = _DCCE.vnext_t2_up2_input_from_t1_admission_v2(witness,
        admission_input, admission, reloaded, adapter, gate; scenario=scenario)
    build.status === :prepared_not_executed && build.input !== nothing ||
        error((:thermal_t2_input_not_prepared, build.status, build.reason))
    build.input
end

function _thermal_v5_queue_child(actual; scenario="thermal-slab-screen-queue-v1", max_iterations=4,
        solver_component=:fv)
    input = _thermal_v5_bound_input(actual; scenario=scenario)
    protocol = _DCCE.CompositionSolveProtocolV1(
        _DCCE.canonical_hash((protocol=:thermal_slab_queue_child_v1, max_iterations=max_iterations)), max_iterations, 1e-12)
    _DCCE.vnext_up3_thermal_queue_child_v1(input, actual.spatial, protocol,
        _DCCE.canonical_hash((subject=:thermal_slab,)),
        _DCCE.canonical_hash((mission=:steady_screen,)),
        _DCCE.canonical_hash(_DCCE.semantic_view(actual.built.identity.scenario_ref));
        solver_component=solver_component)
end

function _thermal_write_result_data_v1(result_dir, label, result)
    label in (:base, :heldout) || throw(ArgumentError("unsupported result label: $label"))
    output_dir = abspath(String(result_dir))
    isdir(output_dir) || throw(ArgumentError("result_dir must be an existing bounded output directory"))
    path = joinpath(output_dir, "up3_$(label)_result_data.jls")
    ispath(path) && throw(ArgumentError("refusing to overwrite result data: $path"))

    open(path, "w") do io
        Serialization.serialize(io, (label=String(label), result=result))
        flush(io)
    end
    bytes = read(path)
    receipt = (label=String(label), file=basename(path), bytes=length(bytes),
        sha256=bytes2hex(SHA.sha256(bytes)))
    println("UP3_RESULT_DATA_RECEIPT=", JSON3.write(receipt))
    flush(stdout)
    receipt
end

function _thermal_run_up3_declared_k22_feedback_holdout_v1(; result_dir)
    @testset "UP3 declared base and K22 heldout use the canonical feedback consumer" begin
        function dispatch(actual)
            child = _thermal_v5_queue_child(actual; max_iterations=24)
            queue = _DCCE.VNextUP3ThermalQueueV1()
            _DCCE.vnext_up3_thermal_enqueue!(queue, child)
            selection = _DCCE.vnext_up3_thermal_next!(queue)
            _DCCE.vnext_up3_thermal_dispatch_selected!(queue, selection)
        end

        # This is the existing source-authored base fixture and its actual
        # source-record/T0/queue path, isolated from the larger focused suite.
        base = _thermal_source_case()
        base_result = dispatch(base)
        base_result_data_receipt = _thermal_write_result_data_v1(
            result_dir, :base, base_result)
        @test base.t0.status === :valid
        @test base_result.status === :screen_only
        @test base_result.candidate_ref == base.built.candidate_ref
        @test base_result.result.accepted === false
        @test base_result.result.evidence_credit == 0
        @test base_result.result.physical_validation === false
        @test base_result.result.engineering_validation === false
        @test base_result.result.composition_execution.status === :executed
        @test base_result.result.composition_execution.provider_callback_count > 0
        base_fp = base_result.result.temperature_source_fixed_point
        @test base_fp.fixed_point_converged === true
        @test base_fp.iteration_count == base_fp.solver_invocation_count == 21
        @test base_result.result.composition_execution.solver_callback_count ==
            base_fp.iteration_count
        @test base_fp.applied_q_W_m3 ≈ 1.6 atol=1e-12 rtol=0
        @test abs(base_result.result.energy_balance_residual_W) <= 1e-12

        # Reuse the already-declared K22 source and the existing heldout
        # materializer, which binds that source to the authored G3 feedback law.
        heldout_variant = _thermal_materialize_source_variant_v1(
            _DCCE_ROOT, _THERMAL_SLAB_K22_CANDIDATE_DIR, :k22_feedback_heldout)
        heldout = _thermal_source_case(heldout_variant.candidate_directory;
            source_root=heldout_variant.source_root)
        heldout_result = dispatch(heldout)
        heldout_result_data_receipt = _thermal_write_result_data_v1(
            result_dir, :heldout, heldout_result)
        heldout_g1 = only(filter(r -> r.layer === :G1, heldout.records.declarations))
        heldout_g2 = only(filter(r -> r.layer === :G2, heldout.records.declarations))
        heldout_g3 = only(filter(r -> r.layer === :G3, heldout.records.declarations))
        base_g1 = only(filter(r -> r.layer === :G1, base.records.declarations))
        base_g2 = only(filter(r -> r.layer === :G2, base.records.declarations))
        heldout_g1_k = heldout.built.g1.declaration.K.expression
        heldout_g2_source = heldout.built.g2.declaration.source
        heldout_law = heldout_g3.semantic_body.body.authored_child_design.control_design.temperature_source_feedback
        heldout_x_boundary = Tuple(face.value.value for face in heldout_g2_source.faces
            if face.face in (:x_min, :x_max))
        # The feedback oracle below is for the K22-only source holdout: retain
        # its 2 m domain, four FV cells, and 300 K end faces.
        base_g1_k = base.built.g1.declaration.K.expression
        base_g2_source = base.built.g2.declaration.source
        @test heldout_g1_k.domain_min == base_g1_k.domain_min
        @test heldout_g1_k.domain_max == (2//1, 1//1, 1//1)
        @test heldout_g1_k.domain_max == base_g1_k.domain_max
        @test heldout_g1_k.base_diag == (11//5, base_g1_k.base_diag[2],
            base_g1_k.base_diag[3])
        @test heldout_g1_k.slope_diag == base_g1_k.slope_diag
        @test (heldout_law.setpoint_kelvin, heldout_law.gain_w_m3_per_kelvin,
            heldout_law.q0_w_m3, heldout_law.q_min_w_m3,
            heldout_law.q_max_w_m3) == (301//1, 1//1, 1//1, 1//2, 2//1)
        @test heldout_g2_source.mesh.cells == base_g2_source.mesh.cells == (4, 1, 1)
        @test heldout_g2_source.chart_map.jacobian_rows[1][1] == 2//1
        @test heldout_g2_source.chart_map.jacobian_rows ==
            base_g2_source.chart_map.jacobian_rows
        @test heldout_g2_source.chart_map.offset == base_g2_source.chart_map.offset
        @test heldout_x_boundary == (300//1, 300//1)
        @test Tuple(Float64.(heldout.spatial.new_geometry.edges)) ==
            (0.0, 0.5, 1.0, 1.5, 2.0)
        @test length(heldout.spatial.field.source) == 4
        # Keep the causal-cut negative on this source-bound K22 holdout too.
        # The raw consumer result above is persisted before the injected stale
        # G3 route is exercised; the negative remains on the same canonical
        # admission/executor path and the authored G1 source units.
        heldout_child = _thermal_v5_queue_child(heldout; max_iterations=24)
        heldout_causal_cut = _thermal_assert_stale_route_causal_negative_v1(
            heldout, heldout_child, heldout_result)
        @test heldout.t0.status === :valid
        @test heldout.built.candidate_ref != base.built.candidate_ref
        @test heldout_g1.source_ref != base_g1.source_ref
        @test heldout_g2.source_ref != base_g2.source_ref
        @test heldout_result.status === :screen_only
        @test heldout_result.candidate_ref == heldout.built.candidate_ref
        @test heldout_result.result.accepted === false
        @test heldout_result.result.evidence_credit == 0
        @test heldout_result.result.physical_validation === false
        @test heldout_result.result.engineering_validation === false
        @test heldout_result.result.composition_execution.status === :executed
        @test heldout_result.result.composition_execution.provider_callback_count > 0
        heldout_fp = heldout_result.result.temperature_source_fixed_point
        heldout_q = 44 / 27
        @test heldout_fp.fixed_point_converged === true
        @test heldout_fp.iteration_count == heldout_fp.solver_invocation_count
        @test heldout_result.result.composition_execution.solver_callback_count ==
            heldout_fp.iteration_count
        @test heldout_fp.iteration_count <= heldout_fp.max_iterations == 24
        @test heldout_fp.applied_q_W_m3 ≈ heldout_q atol=1e-12 rtol=0
        @test heldout_result.result.integrated_source_W ≈ 88 / 27 atol=1e-12 rtol=0
        @test heldout_result.result.outward_fourier_flux_left_W_m2 ≈ heldout_q atol=1e-12 rtol=0
        @test heldout_result.result.outward_fourier_flux_right_W_m2 ≈ heldout_q atol=1e-12 rtol=0
        @test abs(heldout_result.result.energy_balance_residual_W) <= 1e-12

        println("UP3_DECLARED_BASE_K22_FEEDBACK_HOLDOUT=", JSON3.write((
            base_candidate=base.built.candidate_ref.id,
            base_input_hash=base_result.result.composition_input_hash.value,
            base_result_hash=base_result.result.result_hash.value,
            base_iterations=base_fp.iteration_count,
            heldout_candidate=heldout.built.candidate_ref.id,
            heldout_g1_source_ref=heldout_g1.source_ref.id,
            heldout_g2_source_ref=heldout_g2.source_ref.id,
            heldout_input_hash=heldout_result.result.composition_input_hash.value,
            heldout_result_hash=heldout_result.result.result_hash.value,
            heldout_iterations=heldout_fp.iteration_count,
            heldout_q_W_m3=heldout_fp.applied_q_W_m3,
            heldout_energy_balance_residual_W=
                heldout_result.result.energy_balance_residual_W,
            heldout_causal_cut=heldout_causal_cut,
            result_data=(base=base_result_data_receipt,
                heldout=heldout_result_data_receipt),
            claim_ceiling=:screen_only, evidence_credit=0)))
        flush(stdout)
    end
end

Base.@nospecializeinfer function _thermal_assert_stale_route_causal_negative_v1(actual, child, positive_dispatch)
    Base.@nospecialize actual child positive_dispatch
    trace_enabled = get(ENV, "UP3_COMPOSITION_TRACE", "") == "1"
    if trace_enabled
        println("UP3_STALE_ROUTE_NEGATIVE_FUNCTION_BEGIN")
        flush(stdout)
    end
    consumer = _THERMAL_SLAB_CONSUMER
    runtime = getfield(Main, :FusionRuntimeV4)
    built, records = actual.built, actual.records
    g1_record = only(filter(r -> r.layer === :G1, records.declarations))
    capability = g1_record.semantic_body.body.value.g1_typed_source_field_program
    parameter_ref = _DCCE.FieldParameterRefV1("thermal_slab_q_runtime_v1")
    profile = runtime.g1_runtime_source_density_parameter_v1(capability;
        parameter_ref=parameter_ref, q_bounds_W_m3=(0.0, 2.0))
    bounds = _DCCE.QuantityIntervalV1(
        _DCCE.ExactFiniteIntervalV1(0//1, 2//1, false),
        capability.source_law.f_type.units)
    transform = _DCCE.ParameterTransformSpecV1(_DCCE.transform_linear)
    gene = _DCCE.FieldParameterGeneV1(parameter_ref,
        capability.source_law.f_type.units, transform, bounds, -0.5)
    q_half_input = runtime.g1_runtime_source_density_input_v1(profile, gene)
    @test q_half_input.q_W_m3 == 0.5
    if trace_enabled
        println("UP3_STALE_ROUTE_NEGATIVE_STAGE_END stage=q_half_profile")
        println("UP3_STALE_ROUTE_NEGATIVE_STAGE_BEGIN stage=q_half_solver")
        flush(stdout)
    end
    q_half_spatial = consumer._thermal_spatial_case_with_source_density_v1(
        actual.spatial, q_half_input.q_W_m3)
    q_half_solver = consumer._execute_steady_planar_thermal_diffusion_v1(
        built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, actual.t0.transport, q_half_spatial;
        candidate_source_density=(g1_profile=profile, g1_input=q_half_input))
    @test q_half_solver.status === :screen_only
    @test all(==(q_half_input.q_W_m3), q_half_solver.volume_source_W_m3)
    if trace_enabled
        println("UP3_STALE_ROUTE_NEGATIVE_STAGE_END stage=q_half_solver")
        println("UP3_STALE_ROUTE_NEGATIVE_STAGE_BEGIN stage=admission_and_bindings")
        flush(stdout)
    end

    @test _DCCE.vnext_t2_up2_validate_input_v2(child.input).status === :valid
    admission = consumer.up3_steady_planar_composition_admit_v1(
        built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, actual.t0.transport, actual.spatial, child.protocol;
        solver_component=child.solver_component, subject_ref=child.subject_ref,
        mission_ref=child.mission_ref, scenario_ref=child.scenario_ref)
    @test admission.outcome.status === :ready
    @test admission.plan.plan_hash == positive_dispatch.result.composition_plan_hash
    bindings = consumer._up3_slab_execution_bindings_v1(
        built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, actual.t0.transport, actual.spatial, admission;
        solver_component=child.solver_component)
    feedback_key = only(admission.input.feedback_edge_keys)
    g3_ref = feedback_key[1]
    g3_binding = only(filter(b -> b.component_ref == g3_ref &&
        b.callback_kind === :provider, bindings.provider_bindings))
    if trace_enabled
        println("UP3_STALE_ROUTE_NEGATIVE_STAGE_END stage=admission_and_bindings")
        println("UP3_STALE_ROUTE_NEGATIVE_STAGE_BEGIN stage=negative_executor")
        flush(stdout)
    end
    stale_q = Float64(q_half_input.q_W_m3)
    original_g3_invoke = g3_binding.invoke
    stale_g3_invoke = function (values)
        routed = original_g3_invoke(values)
        haskey(values, 3) || return routed
        current = only(routed.outputs)
        payload = merge(current.payload, (q_W_m3=stale_q,))
        replacement = _DCCE.CompositionSolvePortValueV1(
            current.component_ref, current.port, payload,
            current.source_identity_hashes)
        (outputs=(replacement,), result=routed.result)
    end
    csp = parentmodule(typeof(admission.plan))
    binding_type = getfield(csp, :CompositionSolveProviderBindingV1)
    stale_binding = binding_type(g3_binding.component_ref,
        g3_binding.provider_ref, g3_binding.code_ref, g3_binding.backend_ref,
        g3_binding.source_identity_hashes, g3_binding.callback_kind,
        stale_g3_invoke)
    stale_bindings = Tuple(b.component_ref == g3_ref ? stale_binding : b
        for b in bindings.provider_bindings)
    stale_execution = _DCCE.execute_composition_solve_v1(admission,
        stale_bindings; feedback_seeds=bindings.feedback_seeds)
    if trace_enabled
        println("UP3_STALE_ROUTE_NEGATIVE_STAGE_END stage=negative_executor status=", stale_execution.status,
            " solver_attempts=", stale_execution.solver_callback_count,
            " providers=", stale_execution.provider_callback_count)
        flush(stdout)
    end
    @test stale_execution.status === :fail_closed
    @test stale_execution.failure_code === :runtime_callback_failed
    @test occursin("up3_slab_G3_feedback_payload_differs_from_solver_source", stale_execution.failure_detail)
    @test stale_execution.result === nothing
    @test length(stale_execution.feedback_trace) == 1
    @test stale_execution.solver_callback_count == 2 # second callback attempt fails closed
    step = only(stale_execution.feedback_trace)
    positive_first_step=first(positive_dispatch.result.composition_execution.feedback_trace)
    @test step.solver_result_hash==positive_first_step.solver_result_hash
    @test step.solver_result.status === :screen_only
    @test step.solver_result_hash isa _DCCE.Digest256
    @test step.solver_result.result_hash isa _DCCE.Digest256
    @test step.next == stale_q
    @test step.residual > child.protocol.residual_tolerance
    @test all(==(step.applied), step.solver_result.volume_source_W_m3)
    @test step.solver_result.result_hash != q_half_solver.result_hash
    measured_feedback = consumer.thermal_temperature_source_density_input_v1(
        _DCCE.dcce_input_v1(built.candidate_ref, built.g1.declaration,
            built.g2.declaration, built.g3.declaration, actual.t0.transport,
            actual.spatial), maximum(Float64.(step.solver_result.temperature_K)))
    @test step.provider_result.temperature_K == measured_feedback.temperature_K
    @test step.provider_result.temperature_K != maximum(Float64.(q_half_solver.temperature_K))
    @test step.provider_result.feedback.q_W_m3 == measured_feedback.q_W_m3
    @test step.provider_result.feedback.q_W_m3 != stale_q
    feedback_edge = only(filter(edge ->
        (edge.producer_component, edge.producer_slot,
            edge.consumer_component, edge.consumer_slot) == feedback_key,
        admission.plan.edges))
    feedback_hash = _DCCE.canonical_hash(_DCCE.semantic_view(feedback_edge))
    feedback_routes = filter(route -> route.numeric_value !== nothing &&
        _DCCE.canonical_hash(route.edge) == feedback_hash,
        stale_execution.routed_value_audit)
    @test Float64[route.numeric_value for route in feedback_routes] ==
        Float64[step.applied, step.next]
    (status=stale_execution.status,completed_real_steps=length(stale_execution.feedback_trace),
     solver_callback_attempts=stale_execution.solver_callback_count,
     provider_callback_count=stale_execution.provider_callback_count,
     first_solver_result_hash=string(step.solver_result_hash),
     first_solver_equals_positive=(step.solver_result_hash==positive_first_step.solver_result_hash),
     stale_q_W_m3=stale_q, actual_feedback_q_W_m3=step.provider_result.feedback.q_W_m3,
     step_residual_W_m3=step.residual_raw,
     failure=stale_execution.failure_detail)
end

function _thermal_q1_diag_maxrss_bytes()
    isdefined(Sys, :maxrss) || return nothing
    try
        Base.invokelatest(getfield(Sys, :maxrss))
    catch
        nothing
    end
end

_thermal_q1_diag_field(x, name) = x !== nothing && hasproperty(x, name) ?
    getproperty(x, name) : nothing
_thermal_q1_diag_string(x) = x === nothing ? nothing : string(x)
function _thermal_q1_diag_detail(x)
    x === nothing && return nothing
    (type=string(typeof(x)),
     stage=_thermal_q1_diag_string(_thermal_q1_diag_field(x, :stage)),
     exception_type=_thermal_q1_diag_string(_thermal_q1_diag_field(x, :exception_type)),
     message=_thermal_q1_diag_field(x, :message),
     status=_thermal_q1_diag_string(_thermal_q1_diag_field(x, :status)),
     resolution=_thermal_q1_diag_string(_thermal_q1_diag_field(x, :resolution)),
     reason=_thermal_q1_diag_string(_thermal_q1_diag_field(x, :reason)),
     code=_thermal_q1_diag_string(_thermal_q1_diag_field(x, :code)))
end

if _THERMAL_Q1_DIAGNOSTIC_ONLY
    actual = _thermal_source_case(_THERMAL_SLAB_CANDIDATE_DIR)
    child = _thermal_v5_queue_child(actual; max_iterations=24,
        solver_component=:gridap_q1)
    queue = _DCCE.VNextUP3ThermalQueueV1()
    _DCCE.vnext_up3_thermal_enqueue!(queue, child)
    selection = _DCCE.vnext_up3_thermal_next!(queue)
    diagnostic_calls = NamedTuple[]
    sink_ref = getfield(_THERMAL_SLAB_CONSUMER, :_GRIDAP_Q1_DIAGNOSTIC_CALL_SINK)
    previous_sink = sink_ref[]
    rss_before = _thermal_q1_diag_maxrss_bytes()
    live_before = Base.gc_live_bytes()
    Profile.clear()
    dispatch_ref = Ref{Any}(nothing)
    dispatch_timing = Ref{Any}(nothing)
    dispatch_error = Ref{Any}(nothing)
    sink_ref[] = diagnostic_calls
    try
        dispatch_timing[] = @timed Profile.@profile begin
            try
                dispatch_ref[] = _DCCE.vnext_up3_thermal_dispatch_selected!(queue, selection)
            catch err
                dispatch_error[] = (exception_type=string(typeof(err)),
                    exception_message=sprint(showerror, err))
            end
        end
    finally
        sink_ref[] = previous_sink
    end
    rss_after = _thermal_q1_diag_maxrss_bytes()
    live_after = Base.gc_live_bytes()
    dispatched = dispatch_ref[]
    timing = dispatch_timing[]
    result = _thermal_q1_diag_field(dispatched, :result)
    fixed_point = _thermal_q1_diag_field(result, :temperature_source_fixed_point)
    profile_summary = (schema="up3-q1-gridap-call-profile-v1", diagnostic_only=true,
        acceptance=false,
        candidate_ref=(id=actual.built.candidate_ref.id,
            version=actual.built.candidate_ref.version),
        solver_component=_thermal_q1_diag_string(child.solver_component),
        dispatch_status=_thermal_q1_diag_string(_thermal_q1_diag_field(dispatched, :status)),
        dispatch_reason=_thermal_q1_diag_string(_thermal_q1_diag_field(dispatched, :reason)),
        dispatch_result_detail=_thermal_q1_diag_detail(result),
        result_status=_thermal_q1_diag_string(_thermal_q1_diag_field(result, :status)),
        result_code=_thermal_q1_diag_string(_thermal_q1_diag_field(result, :code)),
        result_message=_thermal_q1_diag_field(result, :message),
        fixed_point_status=_thermal_q1_diag_string(_thermal_q1_diag_field(fixed_point, :status)),
        fixed_point_iterations=_thermal_q1_diag_field(fixed_point, :iteration_count),
        solver_invocation_count=_thermal_q1_diag_field(fixed_point, :solver_invocation_count),
        error=dispatch_error[], calls=Tuple(diagnostic_calls),
        total_wall_seconds=timing.time,
        total_allocated_bytes=timing.bytes, total_gc_seconds=timing.gctime,
        live_heap_before_bytes=live_before, live_heap_after_bytes=live_after,
        maxrss_before_bytes=rss_before, maxrss_after_bytes=rss_after)
    println("UP3_Q1_GRIDAP_DIAGNOSTIC_JSON=" * JSON3.write(profile_summary))
    flush(stdout)
    println("UP3_Q1_GRIDAP_PROFILE_BEGIN")
    Profile.print(stdout; format=:flat)
    println("UP3_Q1_GRIDAP_PROFILE_END")
    flush(stdout)
    diagnostic_ok = dispatch_error[] === nothing && dispatched !== nothing &&
        _thermal_q1_diag_field(dispatched, :status) === :screen_only &&
        fixed_point !== nothing
    diagnostic_ok || exit(1)
    exit(0)
end

if !_THERMAL_Q1_DIAGNOSTIC_ONLY
@testset "current-source G1/G2 executes full 3-D Q1 Gridap screen" begin
    actual = _thermal_source_case()
    built = actual.built
    g1, g2, g3 = built.g1.declaration, built.g2.declaration, built.g3.declaration
    input = _DCCE.dgd_input_v1(built.candidate_ref, g1, g2, g3, actual.t0.transport)
    runtime = getfield(Main, :FusionRuntimeV4)
    route = getfield(runtime, :run_g1_thermal_q1_gridap_v1)
    result = Base.invokelatest(route, input; quadrature_degree=4)
    @test (result.status, result.resolution, result.accepted, result.claim_ceiling) ==
        (:executed, :screen_only, false, :screen_only)
    @test result.candidate_ref == built.candidate_ref
    @test result.solver_invocations == 1
    @test result.numerical_scope === :source_bound_full_3d_q1_steady_diffusion_screen
    @test result.authority_scope === :g1_g2_source_bound_only

    g1_record = only(filter(r -> r.layer === :G1, actual.records.declarations))
    g2_record = only(filter(r -> r.layer === :G2, actual.records.declarations))
    capability = _DCCE._dgd_g1_typed_source_capability_v1(input)
    @test result.source_binding.g1_source_ref == g1_record.source_ref
    @test result.source_binding.g1_declaration_ref == g1_record.declaration_ref
    @test result.source_binding.g2_source_ref == g2_record.source_ref
    @test result.source_binding.g2_declaration_ref == g2_record.declaration_ref
    @test result.source_binding.g1_body_hash == input.hashes.g1_body_hash
    @test result.source_binding.g2_body_hash == input.hashes.g2_body_hash
    @test result.source_binding.bundle_hash == input.hashes.bundle_hash
    @test result.source_binding.typed_program_hash == capability.program_hash
    @test result.source_binding.typed_capability_hash == capability.capability_hash
    @test (g1.K.physical_type.units, g1.f.physical_type.units,
        g1.u.physical_type.units) ==
        (_DCCE.UnitSignature((1,1,-3,0,-1,0,0)),
         _DCCE.UnitSignature((-1,1,-3,0,0,0,0)),
         _DCCE.UnitSignature((0,0,0,0,1,0,0)))
    @test g1.K.expression.base_diag == (2//1,3//1,4//1)
    @test g1.K.expression.slope_diag == (0//1,1//10,0//1)
    @test result.source_density_w_m3 == 1.0
    @test result.runtime_source_density === nothing
    @test result.typed_source_temperature_scope === :frozen_g1_u_q0_reference
    @test result.nodal_source_comparison_scope === :same_q0_reference
    @test result.nodal_source_comparison_q0_W_m3 == 1.0
    q0_energy = result.energy_balance
    @test q0_energy.status === :pass
    @test q0_energy.tolerance_w == 1.0e-12
    @test q0_energy.source_power_integral_w ≈ 2.0 atol=1e-12 rtol=0
    @test q0_energy.dirichlet_reaction_sum_w ≈ -2.0 atol=1e-12 rtol=0
    @test abs(q0_energy.source_power_balance_defect_w) <= 1e-12
    @test q0_energy.interior_reaction_linf_w <= 1e-12
    @test q0_energy.interior_residual_match_linf_w <= 1e-12
    @test result.temperature_reference_k == 300.0

    mesh = result.mesh
    @test (mesh.basis, mesh.element, mesh.cells, mesh.cell_count,
        mesh.nodal_count, mesh.free_dofs, mesh.dirichlet_dofs) ==
        (:Q1, :HEX, (4,1,1), 4, 20, 12, 8)
    @test mesh.physical_domain == (0.0,2.0,0.0,1.0,0.0,1.0)
    @test mesh.quadrature_degree == 4
    @test mesh.x_dirichlet_facets.tag == "g1_thermal_x_dirichlet_v1"
    @test length(mesh.x_dirichlet_facets.x_min_faces) == 1
    @test length(mesh.x_dirichlet_facets.x_max_faces) == 1
    @test isempty(intersect(mesh.x_dirichlet_facets.x_min_faces,
        mesh.x_dirichlet_facets.x_max_faces))
    @test Set(mesh.dof_coordinates.dirichlet) ==
        Set((x,y,z) for z in (0.0,1.0) for y in (0.0,1.0) for x in (0.0,2.0))
    @test Set(mesh.dof_coordinates.free) ==
        Set((x,y,z) for z in (0.0,1.0) for y in (0.0,1.0) for x in (0.5,1.0,1.5))

    owners = Dict(f.face => f for f in g2.source.faces)
    projected = Dict(f.face => f for f in mesh.face_projection)
    @test Set(keys(projected)) == Set((:x_min,:x_max,:y_min,:y_max,:z_min,:z_max))
    area = Dict(:x_min=>(-1.0,0.0,0.0), :x_max=>(1.0,0.0,0.0),
        :y_min=>(0.0,-2.0,0.0), :y_max=>(0.0,2.0,0.0),
        :z_min=>(0.0,0.0,-2.0), :z_max=>(0.0,0.0,2.0))
    for (name, owner) in owners
        face = projected[name]
        xessential = name in (:x_min,:x_max)
        @test (face.face_id, face.owner_region_id, face.reference_normal) ==
            (owner.face_id, owner.owner_region_id, owner.reference_normal)
        @test (face.kind, face.value, face.unit) ==
            (owner.value.kind, Float64(owner.value.value), owner.value.unit)
        @test face.physical_oriented_area_vector == area[name]
        @test face.projected_gridap_boundary_cells ==
            face.expected_gridap_boundary_cells == (xessential ? 1 : 4)
        @test face.gridap_boundary_condition ==
            (xessential ? :essential_dirichlet : :natural_zero_neumann)
        @test face.gridap_dirichlet_tag ==
            (xessential ? mesh.x_dirichlet_facets.tag : nothing)
    end

    xnodes, ynodes, znodes = (0.0,0.5,1.0,1.5,2.0), (0.0,1.0), (0.0,1.0)
    physical_nodes = Tuple((x,y,z) for z in znodes for y in ynodes for x in xnodes)
    @test result.physical_nodes == physical_nodes
    h = 0.5
    A = zeros(3,3)
    b = zeros(3)
    for e in 1:4
        conductance = 2.0 / h # Kxx=2; the actual 0.1 slope belongs to Kyy(y).
        left, right = e-1, e
        for node in (left,right)
            if 1 <= node <= 3
                A[node,node] += conductance
                b[node] += h/2
            end
        end
        if 1 <= left <= 3 && 1 <= right <= 3
            A[left,right] -= conductance
            A[right,left] -= conductance
        end
    end
    l21 = A[2,1]/A[1,1]
    d2 = A[2,2]-l21*A[1,2]
    l32 = A[3,2]/d2
    d3 = A[3,3]-l32*A[2,3]
    z1, z2, z3 = b[1], b[2]-l21*b[1], b[3]-l32*(b[2]-l21*b[1])
    t3 = z3/d3
    t2 = (z2-A[2,3]*t3)/d2
    t1 = (z1-A[1,2]*t2)/A[1,1]
    theta = (t1,t2,t3)
    @test size(result.matrix) == (12,12)
    @test length(result.free_theta_values) == length(result.rhs) == 12
    @test maximum(abs.(result.matrix*collect(result.free_theta_values)-collect(result.rhs))) <= 1e-12
    @test maximum(abs.(A*collect(theta)-b)) <= 1e-12
    theta_x = (0.0,theta[1],theta[2],theta[3],0.0)
    expected_T = Tuple(300.0+theta_x[i] for z in znodes for y in ynodes for (i,x) in enumerate(xnodes))
    @test length(result.temperature_nodes_k) == 20
    @test all(isapprox(a,b; atol=1e-10,rtol=0.0)
        for (a,b) in zip(result.temperature_nodes_k,expected_T))
    @test all(isapprox(result.temperature_nodes_k[i],300.0; atol=1e-12,rtol=0.0)
        for i in eachindex(physical_nodes) if physical_nodes[i][1] in (0.0,2.0))
    @test isfinite(result.residual_abs) && result.residual_abs <= 1e-12
    @test isfinite(result.residual_rel)
    chart_nodes = Tuple((p[1]/2,p[2],p[3]) for p in physical_nodes)
    u_eval = Base.invokelatest(runtime.evaluate_g1_typed_source_program_v1,
        capability, capability.roots.u, chart_nodes)
    @test u_eval.status === :ready
    @test result.typed_source_temperature_nodes_k == u_eval.values
    @test result.nodal_source_error_linf ==
        maximum(abs.(collect(result.temperature_nodes_k).-collect(u_eval.values)))


    # Independent MMS oracle: the exact quadratic and its piecewise Q1
    # interpolant differ inside elements even when all nodal values agree.
    q1_volume_l2(q, kxx, length_x, area_yz, nx) =
        abs(q) * sqrt(area_yz * length_x * (length_x / nx)^4 /
            (120.0 * kxx^2))
    base_mms = result.manufactured_solution
    @test base_mms.kind === :constant_source_planar_slab
    @test base_mms.norm === :non_normalized_volume_l2
    @test base_mms.error_units === :K_m3_2
    @test base_mms.quadrature_degree >= 4
    @test base_mms.exact_solution == (T0_K=300.0, q_W_m3=1.0,
        Kxx_W_mK=2.0, x_domain=(0.0,2.0))
    base_l2_expected = q1_volume_l2(1.0, 2.0, 2.0, 1.0, 4)
    @test isfinite(base_mms.temperature_l2_error_k_m32)
    @test base_mms.temperature_l2_error_k_m32 > 0.0
    @test isapprox(base_mms.temperature_l2_error_k_m32, base_l2_expected;
        atol=2e-14, rtol=2e-12)

    refinement_variant = _thermal_materialize_source_variant_v1(
        _DCCE_ROOT, _THERMAL_SLAB_CANDIDATE_DIR, :up2_02_refinement)
    refinement = _thermal_source_case(refinement_variant.candidate_directory;
        source_root=refinement_variant.source_root)
    @test refinement.t0.status === :valid
    fine_built = refinement.built
    fine_g1, fine_g2, fine_g3 = fine_built.g1.declaration,
        fine_built.g2.declaration, fine_built.g3.declaration
    fine_g1_record = only(filter(r -> r.layer === :G1,
        refinement.records.declarations))
    fine_g2_record = only(filter(r -> r.layer === :G2,
        refinement.records.declarations))
    fine_input = _DCCE.dgd_input_v1(fine_built.candidate_ref,
        fine_g1, fine_g2, fine_g3, refinement.t0.transport)
    fine_capability = _DCCE._dgd_g1_typed_source_capability_v1(fine_input)
    @test fine_capability !== nothing
    @test fine_capability.source_law.T0_K == 300.0
    @test fine_capability.source_law.L_m == 2.0
    @test fine_capability.source_law.Kxx_W_mK == 2.0
    fine_x_faces = Dict(f.face => f.value.value for f in fine_g2.source.faces
        if f.face in (:x_min, :x_max))
    @test Float64(fine_x_faces[:x_min]) == Float64(fine_x_faces[:x_max]) == 300.0
    fine_result = Base.invokelatest(route, fine_input; quadrature_degree=4)
    fine_mms = fine_result.manufactured_solution
    fine_l2_expected = q1_volume_l2(1.0, 2.0, 2.0, 1.0, 8)
    @test fine_built.candidate_ref != built.candidate_ref
    fine_g1_authored = fine_g1_record.semantic_body.body.authored_builder_input
    @test fine_g1_authored.sha256.value == fine_built.entries.g1_source_jl.sha256
    @test fine_g1_authored.byte_count == fine_built.entries.g1_source_jl.byte_count
    @test fine_g1_authored.sha256 !=
        g1_record.semantic_body.body.authored_builder_input.sha256
    fine_g2_authored = fine_g2_record.semantic_body.body.authored_builder_input
    @test fine_g2_authored.sha256.value == fine_built.entries.g2_source_jl.sha256
    @test fine_g2_authored.byte_count == fine_built.entries.g2_source_jl.byte_count
    @test fine_g2_authored.sha256 !=
        g2_record.semantic_body.body.authored_builder_input.sha256
    @test fine_g2.source.mesh.cells == (8,1,1)
    @test fine_input.hashes.g2_body_hash != input.hashes.g2_body_hash
    @test fine_result.source_binding.g1_body_hash == fine_input.hashes.g1_body_hash
    @test fine_result.source_binding.g2_body_hash == fine_input.hashes.g2_body_hash
    @test fine_result.source_binding.bundle_hash == fine_input.hashes.bundle_hash
    @test (fine_result.status, fine_result.mesh.cells,
        fine_result.solver_invocations) == (:executed, (8,1,1), 1)
    @test fine_result.mesh.physical_domain == (0.0,2.0,0.0,1.0,0.0,1.0)
    @test all(isapprox(t, 300.0; atol=1e-12, rtol=0.0)
        for (p,t) in zip(fine_result.physical_nodes,
            fine_result.temperature_nodes_k) if p[1] in (0.0,2.0))
    @test isapprox(fine_mms.temperature_l2_error_k_m32, fine_l2_expected;
        atol=2e-14, rtol=2e-12)
    @test isapprox(fine_mms.temperature_l2_error_k_m32 /
        base_mms.temperature_l2_error_k_m32, 0.25; atol=2e-12, rtol=0.0)
    @test fine_result.residual_abs <= 1e-12
    @test fine_result.energy_balance.status === :pass
    @test fine_result.energy_balance.tolerance_w == 1e-12
    @test isapprox(fine_result.energy_balance.source_power_integral_w, 2.0;
        atol=1e-12, rtol=0.0)
    @test isapprox(fine_result.energy_balance.dirichlet_reaction_sum_w, -2.0;
        atol=1e-12, rtol=0.0)
    @test abs(fine_result.energy_balance.source_power_balance_defect_w) <= 1e-12
    @test fine_result.energy_balance.interior_reaction_linf_w <= 1e-12
    @test fine_result.energy_balance.interior_residual_match_linf_w <= 1e-12

    # A distinct candidate is authored from source bytes, reread, and passed
    # through a fresh T0 build before the held-out consumer execution.
    heldout_variant = _thermal_materialize_source_variant_v1(
        _DCCE_ROOT, _THERMAL_SLAB_CANDIDATE_DIR, :up2_02_holdout)
    heldout = _thermal_source_case(heldout_variant.candidate_directory;
        source_root=heldout_variant.source_root)
    @test heldout.t0.status === :valid
    held_built = heldout.built
    held_g1, held_g2, held_g3 = held_built.g1.declaration,
        held_built.g2.declaration, held_built.g3.declaration
    held_g1_record = only(filter(r -> r.layer === :G1,
        heldout.records.declarations))
    held_g2_record = only(filter(r -> r.layer === :G2,
        heldout.records.declarations))
    held_input = _DCCE.dgd_input_v1(held_built.candidate_ref,
        held_g1, held_g2, held_g3, heldout.t0.transport)
    held_capability = _DCCE._dgd_g1_typed_source_capability_v1(held_input)
    @test held_capability !== nothing
    @test held_capability.source_law.T0_K == 310.0
    @test held_capability.source_law.L_m == 1.5
    @test held_capability.source_law.Kxx_W_mK == 3.0
    @test held_g2.source.mesh.cells == (6,1,1)
    held_x_faces = Dict(f.face => f.value.value for f in held_g2.source.faces
        if f.face in (:x_min, :x_max))
    @test Float64(held_x_faces[:x_min]) == Float64(held_x_faces[:x_max]) == 310.0
    held_profile_ref = _DCCE.FieldParameterRefV1(
        "up2_02_q1_mms_holdout_source")
    held_profile = runtime.g1_runtime_source_density_parameter_v1(
        held_capability; parameter_ref=held_profile_ref,
        q_bounds_W_m3=(0.0,2.0))
    held_q_bounds = _DCCE.QuantityIntervalV1(
        _DCCE.ExactFiniteIntervalV1(0//1,2//1,false),
        held_capability.source_law.f_type.units)
    held_q_gene = _DCCE.FieldParameterGeneV1(held_profile_ref,
        held_capability.source_law.f_type.units,
        _DCCE.ParameterTransformSpecV1(_DCCE.transform_linear),
        held_q_bounds, 0.75)
    held_q_input = runtime.g1_runtime_source_density_input_v1(
        held_profile, held_q_gene)
    @test held_q_input.q_W_m3 == 1.75
    held_result = Base.invokelatest(route, held_input;
        quadrature_degree=4, source_density_profile=held_profile,
        source_density_runtime_input=held_q_input)
    held_mms = held_result.manufactured_solution
    held_l2_expected = q1_volume_l2(1.75, 3.0, 1.5, 1.0, 6)
    @test held_built.candidate_ref != built.candidate_ref
    held_g1_authored = held_g1_record.semantic_body.body.authored_builder_input
    @test held_g1_authored.sha256.value == held_built.entries.g1_source_jl.sha256
    @test held_g1_authored.byte_count == held_built.entries.g1_source_jl.byte_count
    @test held_g1_authored.sha256 !=
        g1_record.semantic_body.body.authored_builder_input.sha256
    held_g2_authored = held_g2_record.semantic_body.body.authored_builder_input
    @test held_g2_authored.sha256.value == held_built.entries.g2_source_jl.sha256
    @test held_g2_authored.byte_count == held_built.entries.g2_source_jl.byte_count
    @test held_g2_authored.sha256 !=
        g2_record.semantic_body.body.authored_builder_input.sha256
    @test held_input.hashes.g1_body_hash != input.hashes.g1_body_hash
    @test held_input.hashes.g2_body_hash != input.hashes.g2_body_hash
    @test held_result.source_binding.g1_body_hash == held_input.hashes.g1_body_hash
    @test held_result.source_binding.g2_body_hash == held_input.hashes.g2_body_hash
    @test held_result.source_binding.bundle_hash == held_input.hashes.bundle_hash
    @test (held_result.status, held_result.mesh.cells,
        held_result.solver_invocations) == (:executed, (6,1,1), 1)
    @test held_result.mesh.physical_domain == (0.0,1.5,0.0,1.0,0.0,1.0)
    @test held_result.temperature_reference_k == 310.0
    @test all(isapprox(t, 310.0; atol=1e-12, rtol=0.0)
        for (p,t) in zip(held_result.physical_nodes,
            held_result.temperature_nodes_k) if p[1] in (0.0,1.5))
    @test held_result.source_density_w_m3 == 1.75
    @test held_result.runtime_source_density.q_W_m3 == 1.75
    @test held_mms.exact_solution == (T0_K=310.0, q_W_m3=1.75,
        Kxx_W_mK=3.0, x_domain=(0.0,1.5))
    @test isapprox(held_mms.temperature_l2_error_k_m32, held_l2_expected;
        atol=2e-14, rtol=2e-12)
    @test isfinite(held_result.residual_abs) && held_result.residual_abs <= 1e-12
    held_energy = held_result.energy_balance
    @test held_energy.status === :pass
    @test held_energy.tolerance_w == 1.0e-12
    @test isapprox(held_energy.source_power_integral_w, 2.625;
        atol=1e-12, rtol=0.0)
    @test isapprox(held_energy.dirichlet_reaction_sum_w, -2.625;
        atol=1e-12, rtol=0.0)
    @test abs(held_energy.source_power_balance_defect_w) <= 1e-12
    @test held_energy.interior_reaction_linf_w <= 1e-12
    @test held_energy.interior_residual_match_linf_w <= 1e-12

    println("UP2_G1_THERMAL_GRIDAP_MMS=" * JSON3.write((
        scope=:two_level_declared_mms_component_screen,
        base=(cells=result.mesh.cells,
            l2_k_m32=base_mms.temperature_l2_error_k_m32,
            expected_l2_k_m32=base_l2_expected),
        refinement=(candidate_ref=fine_built.candidate_ref.id,
            cells=fine_result.mesh.cells,
            l2_k_m32=fine_mms.temperature_l2_error_k_m32,
            expected_l2_k_m32=fine_l2_expected,
            ratio=fine_mms.temperature_l2_error_k_m32 /
                base_mms.temperature_l2_error_k_m32),
        heldout=(candidate_ref=held_built.candidate_ref.id,
            cells=held_result.mesh.cells,
            domain=held_result.mesh.physical_domain,
            source_w_m3=held_result.source_density_w_m3,
            temperature_reference_k=held_result.temperature_reference_k,
            kxx_w_mk=held_mms.exact_solution.Kxx_W_mK,
            l2_k_m32=held_mms.temperature_l2_error_k_m32,
            expected_l2_k_m32=held_l2_expected,
            power_balance_w=held_energy.source_power_balance_defect_w),
        claim_ceiling=:screen_only)))
    flush(stdout)

    println("UP2_G1_THERMAL_GRIDAP_RESULT=", JSON3.write((candidate_ref=string(result.candidate_ref), source_binding=result.source_binding, cells=mesh.cells, nodal_count=mesh.nodal_count, free_dofs=mesh.free_dofs, dirichlet_dofs=mesh.dirichlet_dofs, dof_coordinates=mesh.dof_coordinates, temperature_nodes_k=result.temperature_nodes_k, residual_abs=result.residual_abs, residual_rel=result.residual_rel, energy_balance=result.energy_balance, solver_invocations=result.solver_invocations, numerical_scope=result.numerical_scope, authority_scope=result.authority_scope)))
    flush(stdout)
    @test_throws ArgumentError Base.invokelatest(route,input; quadrature_degree=0)
    @test_throws ArgumentError begin
        bad = _DCCE.G2MBFaceValueV1(:dirichlet,301//1,
            _DCCE.UnitSignature((0,0,0,0,1,0,0)))
        changed = _DCCE.g2mb_edit_source(g2,:face_value,("thermal_x_max",bad))
        Base.invokelatest(route,_DCCE.dgd_input_v1(built.candidate_ref,g1,changed,g3,
            actual.t0.transport); quadrature_degree=4)
    end
    @test_throws ArgumentError begin
        bad = _DCCE.G2MBFaceValueV1(:dirichlet,300//1,_DCCE.UnitSignature())
        changed = _DCCE.g2mb_edit_source(g2,:face_value,("thermal_x_max",bad))
        Base.invokelatest(route,_DCCE.dgd_input_v1(built.candidate_ref,g1,changed,g3,
            actual.t0.transport); quadrature_degree=4)
    end
    @test_throws ArgumentError begin
        bad = _DCCE.G1DiffusionScalarFieldV1(g1.f.field_id,g1.f.physical_type,
            g1.f.source_ref; source_expression="f_candidate(x)=2")
        changed = _DCCE.g1_diffusion_edit_source(g1,:f,bad)
        Base.invokelatest(route,_DCCE.dgd_input_v1(built.candidate_ref,changed,g2,g3,
            actual.t0.transport); quadrature_degree=4)
    end
end

if get(ENV, "UP2_G1_GRIDAP_FOCUS", "0") != "1"
println("UP3_PREQUEUE_CASE_CACHE_RELEASE_BEGIN entries=", length(_THERMAL_SLAB_CASE_CACHE))
flush(stdout)
empty!(_THERMAL_SLAB_CASE_CACHE)
GC.gc(true)
println("UP3_PREQUEUE_CASE_CACHE_RELEASE_END entries=", length(_THERMAL_SLAB_CASE_CACHE))
flush(stdout)
@testset "native V5 queue selects a source-bound child for one UP3 screen solve" begin
    base, edited = _thermal_source_case(), _thermal_source_case(_THERMAL_SLAB_K22_CANDIDATE_DIR)
    child_a, child_b = _thermal_v5_queue_child(base), _thermal_v5_queue_child(edited)
    # The production path carries the V2 checked output: declarations, children,
    # and feedback are compared against the same admitted T0 transport.
    input_a, witness_a = child_a.input, child_a.input.witness
    recheck, transport = witness_a.t0_recheck, witness_a.t0_transport
    @test recheck isa _DCCE.VNextAuthorityRecheckLocalV2Checked
    @test _DCCE._vnext_t2_t0_recheck_match_v2(input_a)

    # Keep the old V1 field representation covered through this private helper
    # seam, using the exact source-owned T0 carriers above.
    legacy_recheck = _DCCE.VNextAuthorityRecheckLocalCheckedPresentV1(
        recheck.candidate_ref, transport.declarations[1],
        transport.declarations[2], transport.declarations[3],
        transport.feedback, transport.children, transport.bundle_hash)
    legacy_witness = (candidate_ref=witness_a.candidate_ref,
        t0_transport=transport, t0_recheck=legacy_recheck,
        manifest=witness_a.manifest)
    @test _DCCE._vnext_t2_t0_recheck_match_v2(
        (witness=legacy_witness, package=input_a.package))

    declarations_changed = (recheck.declarations[2], recheck.declarations[1],
        recheck.declarations[3])
    children_changed = (recheck.children[2], recheck.children[1],
        recheck.children[3])
    feedback_changed = (recheck.feedback..., :up5_test_tamper)
    bad_rechecks = (
        _DCCE.VNextAuthorityRecheckLocalV2Checked(recheck.candidate_ref,
            recheck.bundle_hash, declarations_changed, recheck.children,
            recheck.feedback, recheck.g3_children_deferred),
        _DCCE.VNextAuthorityRecheckLocalV2Checked(recheck.candidate_ref,
            recheck.bundle_hash, recheck.declarations, children_changed,
            recheck.feedback, recheck.g3_children_deferred),
        _DCCE.VNextAuthorityRecheckLocalV2Checked(recheck.candidate_ref,
            recheck.bundle_hash, recheck.declarations, recheck.children,
            feedback_changed, recheck.g3_children_deferred))
    for bad_recheck in bad_rechecks
        bad_witness = (candidate_ref=witness_a.candidate_ref,
            t0_transport=transport, t0_recheck=bad_recheck,
            manifest=witness_a.manifest)
        @test !_DCCE._vnext_t2_t0_recheck_match_v2(
            (witness=bad_witness, package=input_a.package))
    end
    @test child_a.input.package isa _DCCE.CandidateStatePackageV5NextV2
    @test child_a.input.witness isa _DCCE.VNextT2ConcreteSourceWitnessV3
    @test child_a.input.package.candidate_ref == child_a.input.witness.candidate_ref ==
        base.built.candidate_ref
    @test child_b.input.package.candidate_ref == child_b.input.witness.candidate_ref ==
        edited.built.candidate_ref
    @test child_a.input.package.candidate_ref != child_b.input.package.candidate_ref
    @test base.built.identity.scenario_ref == edited.built.identity.scenario_ref
    @test child_a.scenario_ref == child_b.scenario_ref ==
        _DCCE.canonical_hash(_DCCE.semantic_view(base.built.identity.scenario_ref))
    @test child_a.input.package.bundle_hash == child_a.input.witness.t0_transport.bundle_hash
    @test child_b.input.package.bundle_hash == child_b.input.witness.t0_transport.bundle_hash
    @test child_a.input.witness.g1.record.source_ref != child_b.input.witness.g1.record.source_ref

    queue = _DCCE.VNextUP3ThermalQueueV1()
    _DCCE.vnext_up3_thermal_enqueue!(queue, child_a)
    _DCCE.vnext_up3_thermal_enqueue!(queue, child_b)
    foreign_queue = _DCCE.VNextUP3ThermalQueueV1()
    _DCCE.vnext_up3_thermal_enqueue!(foreign_queue, child_b)
    selected_a = _DCCE.vnext_up3_thermal_next!(queue)
    foreign_selection = _DCCE.vnext_up3_thermal_next!(foreign_queue)
    @test_throws ArgumentError _DCCE.vnext_up3_thermal_dispatch_selected!(queue,
        foreign_selection)
    result_a = _DCCE.vnext_up3_thermal_dispatch_selected!(queue, selected_a)
    selected_b = _DCCE.vnext_up3_thermal_next!(queue)
    result_b = _DCCE.vnext_up3_thermal_dispatch_selected!(queue, selected_b)
    for (label, dispatch_result) in ((:result_a, result_a), (:result_b, result_b))
        detail = dispatch_result.result
        if hasproperty(detail, :stage) && hasproperty(detail, :exception_type) &&
                hasproperty(detail, :message)
            println("UP3_QUEUE_DISPATCH_EXCEPTION=", (result=label,
                stage=detail.stage, exception_type=detail.exception_type,
                message=detail.message))
        end
    end

    @test result_a.status === :terminal_deferred
    @test result_a.resolution === :terminal_deferred
    @test result_a.reason === :up3_thermal_fixed_point_nonconvergent
    @test result_b.status === :screen_only
    @test result_b.resolution === :terminal_deferred
    @test result_b.reason === :up3_thermal_screen_complete
    @test result_a.candidate_ref == base.built.candidate_ref
    @test result_b.candidate_ref == edited.built.candidate_ref
    @test result_a.result.claim_ceiling === result_b.result.claim_ceiling === :screen_only
    @test result_a.result.accepted === result_b.result.accepted === false
    @test result_a.result.feedback_status === :terminal_deferred
    @test result_a.result.feedback_reason === :iteration_limit
    @test !hasproperty(only(filter(r -> r.layer === :G3, child_b.input.witness.t0_transport.declarations)).semantic_body.body.authored_child_design.control_design, :temperature_source_feedback)
    @test result_b.result.feedback_status === :typed_absent
    @test result_b.result.feedback_reason === :unsupported_feedback_scope
    @test result_a.result.provider_invocation_count == result_b.result.provider_invocation_count == 0
    @test result_a.result.solver_invocation_count == 4
    @test result_b.result.solver_invocation_count == 1
    @test result_a.result.evidence_credit == result_b.result.evidence_credit == 0
    @test result_a.result.physical_validation === result_b.result.physical_validation === false
    @test result_a.result.engineering_validation === result_b.result.engineering_validation === false
    fp_4 = result_a.result.temperature_source_fixed_point
    @test fp_4.fixed_point_converged === false
    @test fp_4.termination === :iteration_limit
    @test fp_4.nonconvergent_policy === :terminal_deferred
    @test fp_4.max_iterations == 4
    @test fp_4.iteration_count == fp_4.solver_invocation_count == 4
    @test !hasproperty(result_b.result, :temperature_source_fixed_point)
    @test collect(result_b.result.temperature_K) ≈ collect(ntuple(i ->
        300.0 + (10/11) * (i == 1 || i == 4 ? 0.125 : 0.25), 4)) atol=1e-12 rtol=0

    # The selected caller may supply 24 iterations; the actual law converges in 21.
    child_24 = _thermal_v5_queue_child(base; max_iterations=24)
    queue_24 = _DCCE.VNextUP3ThermalQueueV1()
    _DCCE.vnext_up3_thermal_enqueue!(queue_24, child_24)
    selection_24 = _DCCE.vnext_up3_thermal_next!(queue_24)
    result_24 = _DCCE.vnext_up3_thermal_dispatch_selected!(queue_24, selection_24)
    fp_24 = result_24.result.temperature_source_fixed_point
    @test result_24.status === :screen_only
    @test result_24.resolution === :terminal_deferred
    @test result_24.reason === :up3_thermal_screen_complete
    @test result_24.result.feedback_status === :screen_only
    @test result_24.result.feedback_reason === :residual_tolerance
    @test result_24.result.accepted === false
    @test result_24.result.claim_ceiling === :screen_only
    @test result_24.result.physical_validation === false
    @test result_24.result.engineering_validation === false
    @test result_24.result.evidence_credit == 0
    @test result_24.result.provider_invocation_count == 0
    @test fp_24.max_iterations == 24
    @test fp_24.fixed_point_converged === true
    @test fp_24.iteration_count == fp_24.solver_invocation_count == 21
    @test fp_24.applied_q_W_m3 ≈ 1.6 atol=1e-12 rtol=0
    @test all(isapprox(q, 1.6; atol=1e-12, rtol=0) for q in result_24.result.volume_source_W_m3)
    if get(ENV, "UP3_COMPOSITION_TRACE", "") == "1"
        println("UP3_STALE_ROUTE_NEGATIVE_CALL_BEGIN")
        flush(stdout)
    end
    stale_route_negative = _thermal_assert_stale_route_causal_negative_v1(
        base, child_24, result_24)
    println("UP3_STALE_FEEDBACK_ROUTE_NEGATIVE=", stale_route_negative)
    flush(stdout)

    # Rebuild a distinct K22 candidate from current source bytes with the existing
    # authored temperature law. This exercises the selected queue on held-out G1/G2
    # source identities rather than changing the already-admitted package in memory.
    heldout_variant = _thermal_materialize_source_variant_v1(
        _DCCE_ROOT, _THERMAL_SLAB_K22_CANDIDATE_DIR, :k22_feedback_heldout)
    heldout = _thermal_source_case(heldout_variant.candidate_directory;
        source_root=heldout_variant.source_root)
    heldout_child = _thermal_v5_queue_child(heldout; max_iterations=24)
    heldout_g1 = only(filter(r -> r.layer === :G1, heldout.records.declarations))
    heldout_g2 = only(filter(r -> r.layer === :G2, heldout.records.declarations))
    heldout_g3 = only(filter(r -> r.layer === :G3, heldout.records.declarations))
    heldout_design = heldout_g3.semantic_body.body.authored_child_design
    heldout_law = heldout_design.control_design.temperature_source_feedback
    heldout_controller = only(filter(c -> c.controller_id == heldout_law.controller_id,
        heldout_design.control.controllers))
    heldout_matching_links = Tuple(link for link in heldout_design.control_resource_links
        if link.controller_id == heldout_controller.controller_id &&
            link.sensor_port_id == heldout_law.temperature_sensor_port_id &&
            link.actuator_port_id == heldout_law.actuator_port_id &&
            link.fault_id in heldout_controller.fault_ids)
    @test heldout_variant.scenario_id == heldout.built.identity.scenario_id
    @test heldout.built.candidate_ref.id == "fusionconceptai://candidate-design/$(heldout_variant.candidate_id)"
    @test heldout.built.candidate_ref != edited.built.candidate_ref
    @test heldout_g1.source_ref != only(filter(r -> r.layer === :G1,
        edited.records.declarations)).source_ref
    @test heldout_g2.source_ref != only(filter(r -> r.layer === :G2,
        edited.records.declarations)).source_ref
    @test heldout.built.g1.declaration.K.expression.base_diag[1] == 11//5
    heldout_chart = heldout.built.g2.declaration.source.chart_map
    edited_chart = edited.built.g2.declaration.source.chart_map
    @test heldout_chart.domain_lower == edited_chart.domain_lower
    @test heldout_chart.domain_upper == edited_chart.domain_upper
    @test heldout_chart.jacobian_rows == edited_chart.jacobian_rows
    @test heldout_chart.offset == edited_chart.offset
    @test heldout_chart.map_kind == edited_chart.map_kind
    @test heldout_chart.axes == edited_chart.axes
    @test heldout.t0.status === :valid
    @test _DCCE.vnext_t2_up2_validate_input_v2(heldout_child.input).status === :valid
    @test hasproperty(heldout_design.control_design, :temperature_source_feedback)
    @test length(heldout_matching_links) == 1

    heldout_queue = _DCCE.VNextUP3ThermalQueueV1()
    _DCCE.vnext_up3_thermal_enqueue!(heldout_queue, heldout_child)
    heldout_selection = _DCCE.vnext_up3_thermal_next!(heldout_queue)
    heldout_result = _DCCE.vnext_up3_thermal_dispatch_selected!(heldout_queue,
        heldout_selection)
    heldout_fp = heldout_result.result.temperature_source_fixed_point
    heldout_kxx = Float64(heldout.built.g1.declaration.K.expression.base_diag[1])
    heldout_q_oracle = 44/27 # q = 2 - (5/22)q for the Kxx=11/5 FV slab.
    heldout_centers = (0.25, 0.75, 1.25, 1.75)
    heldout_expected_temperature = ntuple(i -> 300.0 + heldout_q_oracle *
        heldout_centers[i] * (2.0 - heldout_centers[i]) / (2.0 * heldout_kxx) +
        heldout_q_oracle * 0.5^2 / (8.0 * heldout_kxx), 4)
    @test heldout_result.status === :screen_only
    @test heldout_result.resolution === :terminal_deferred
    @test heldout_result.reason === :up3_thermal_screen_complete
    @test heldout_result.candidate_ref == heldout.built.candidate_ref
    @test heldout_result.result.feedback_status === :screen_only
    @test heldout_result.result.feedback_reason === :residual_tolerance
    @test heldout_result.result.accepted === false
    @test heldout_result.result.claim_ceiling === :screen_only
    @test heldout_result.result.evidence_credit == 0
    @test heldout_result.result.provider_invocation_count == 0
    @test heldout_result.result.physical_validation === false
    @test heldout_result.result.engineering_validation === false
    @test heldout_fp.max_iterations == 24
    @test heldout_fp.fixed_point_converged === true
    @test heldout_fp.termination === :residual_tolerance
    @test heldout_fp.iteration_count == heldout_fp.solver_invocation_count
    @test heldout_fp.iteration_count <= heldout_fp.max_iterations
    @test heldout_fp.applied_q_W_m3 ≈ heldout_q_oracle atol=1e-12 rtol=0
    @test heldout_fp.temperature_K ≈ 300.0 + 10/27 atol=1e-12 rtol=0
    @test collect(heldout_result.result.temperature_K) ≈
        collect(heldout_expected_temperature) atol=1e-12 rtol=0
    @test all(isapprox(q, heldout_q_oracle; atol=1e-12, rtol=0)
        for q in heldout_result.result.volume_source_W_m3)
    @test heldout_result.result.integrated_source_W ≈ 88/27 atol=1e-12 rtol=0
    @test heldout_result.result.outward_fourier_flux_left_W_m2 ≈ heldout_q_oracle atol=1e-12 rtol=0
    @test heldout_result.result.outward_fourier_flux_right_W_m2 ≈ heldout_q_oracle atol=1e-12 rtol=0
    @test heldout_result.result.energy_balance_residual_W ≈ 0.0 atol=1e-12 rtol=0
    println("UP3_K22_FEEDBACK_HELDOUT=", JSON3.write((
        candidate_ref=(id=heldout.built.candidate_ref.id,
            version=heldout.built.candidate_ref.version),
        scenario_id=heldout_variant.scenario_id,
        g1_source_ref=(id=heldout_g1.source_ref.id, version=heldout_g1.source_ref.version),
        g2_source_ref=(id=heldout_g2.source_ref.id, version=heldout_g2.source_ref.version),
        g1_source_sha256=heldout_g1.source_bytes.sha256,
        g2_source_sha256=heldout_g2.source_bytes.sha256,
        status=heldout_result.status, reason=heldout_result.reason,
        iterations=heldout_fp.iteration_count, max_iterations=heldout_fp.max_iterations,
        residual_W_m3=heldout_fp.residual, applied_q_W_m3=heldout_fp.applied_q_W_m3,
        temperature_K=heldout_result.result.temperature_K,
        source_W_m3=heldout_result.result.volume_source_W_m3,
        integrated_source_W=heldout_result.result.integrated_source_W,
        left_flux_W_m2=heldout_result.result.outward_fourier_flux_left_W_m2,
        right_flux_W_m2=heldout_result.result.outward_fourier_flux_right_W_m2,
        energy_balance_residual_W=heldout_result.result.energy_balance_residual_W,
        result_hash=heldout_result.result.result_hash.value)))
    flush(stdout)

    # Independent review holdout: changed coefficient, physical x span, mesh,
    # Dirichlet values, and owner region, materialized through the existing
    # source-variant builder with refreshed manifest pins.
    review_variant = _thermal_materialize_source_variant_v1(
        _DCCE_ROOT, _THERMAL_SLAB_CANDIDATE_DIR, :up3_review_holdout_r14)
    review_case = _thermal_source_case(review_variant.candidate_directory;
        source_root=review_variant.source_root)
    review_child = _thermal_v5_queue_child(review_case; max_iterations=24)
    review_g1 = only(filter(r -> r.layer === :G1,
        review_case.records.declarations))
    review_g2 = only(filter(r -> r.layer === :G2,
        review_case.records.declarations))
    review_faces = review_case.built.g2.declaration.source.faces
    review_chart = review_case.built.g2.declaration.source.chart_map
    review_k = review_case.built.g1.declaration.K.expression
    review_x_faces = Dict(face.face => face.value.value for face in review_faces
        if face.face in (:x_min, :x_max))
    @test review_case.t0.status === :valid
    @test _DCCE.vnext_t2_up2_validate_input_v2(review_child.input).status === :valid
    @test review_case.built.candidate_ref != base.built.candidate_ref
    @test review_case.built.identity.scenario_ref == base.built.identity.scenario_ref
    @test review_g1.source_ref != only(filter(r -> r.layer === :G1,
        base.records.declarations)).source_ref
    @test review_g2.source_ref != only(filter(r -> r.layer === :G2,
        base.records.declarations)).source_ref
    @test review_k.domain_min == (0//1, 0//1, 0//1)
    @test review_k.domain_max == (3//2, 1//1, 1//1)
    @test review_k.base_diag == (3//1, 3//1, 4//1)
    @test review_k.slope_diag == (0//1, 1//10, 0//1)
    @test review_chart.jacobian_rows[1][1] == 3//2
    @test review_case.built.g2.declaration.source.mesh.cells == (6, 1, 1)
    @test review_x_faces == Dict(:x_min => 298//1, :x_max => 306//1)
    @test all(face -> face.owner_region_id == "thermal_slab_review", review_faces)

    review_queue = _DCCE.VNextUP3ThermalQueueV1()
    _DCCE.vnext_up3_thermal_enqueue!(review_queue, review_child)
    review_selection = _DCCE.vnext_up3_thermal_next!(review_queue)
    review_result = _DCCE.vnext_up3_thermal_dispatch_selected!(review_queue,
        review_selection)
    review_fp = review_result.result.temperature_source_fixed_point
    review_execution = review_result.result.composition_execution
    @test review_result.status === :screen_only
    @test review_result.resolution === :terminal_deferred
    @test review_result.reason === :up3_thermal_screen_complete
    @test review_result.result.candidate_ref == review_case.built.candidate_ref
    @test review_result.result.accepted === false
    @test review_result.result.claim_ceiling === :screen_only
    @test review_result.result.evidence_credit == 0
    @test review_result.result.physical_validation === false
    @test review_result.result.engineering_validation === false
    @test review_result.result.provider_invocation_count == 0
    @test review_execution.status === :executed
    @test review_execution.solver_callback_count == review_fp.iteration_count
    @test review_execution.provider_callback_count == review_fp.iteration_count + 4
    @test review_fp.fixed_point_converged === true
    @test review_fp.iteration_count == review_fp.solver_invocation_count <= 24
    @test review_fp.applied_q_W_m3 != fp_24.applied_q_W_m3
    @test review_fp.temperature_K != fp_24.temperature_K
    @test all(isapprox(q, review_fp.applied_q_W_m3; atol=1e-12, rtol=0)
        for q in review_result.result.volume_source_W_m3)
    @test all(step -> all(==(step.applied_q_W_m3), step.solver_source_density),
        review_fp.iteration_trace)
    @test all(step -> isfinite(step.solver_energy_balance.balance_residual.value) &&
        abs(step.solver_energy_balance.balance_residual.value) <= 1e-10,
        review_fp.iteration_trace)
    # Check the actual unequal-face typed-AST and FV queue outputs against the
    # source-derived boundary lift, then check both outward normals and power.
    review_edges = Float64.(collect(review_case.spatial.new_geometry.edges))
    review_widths = diff(review_edges)
    review_origin = Float64(review_chart.offset[1] +
        review_chart.jacobian_rows[1][1] * review_chart.domain_lower[1])
    review_length = Float64(review_chart.jacobian_rows[1][1] *
        (review_chart.domain_upper[1] - review_chart.domain_lower[1]))
    review_kxx = Float64(review_k.base_diag[1])
    review_left_temperature = Float64(review_x_faces[:x_min])
    review_right_temperature = Float64(review_x_faces[:x_max])
    review_h = first(review_widths)
    review_q = review_fp.applied_q_W_m3
    @test all(isapprox(width, review_h; atol=1e-10, rtol=0.0)
        for width in review_widths)
    @test isapprox(last(review_edges) - first(review_edges), review_length;
        atol=1e-10, rtol=0.0)
    review_cell_x = Tuple((review_edges[i] + review_edges[i + 1]) / 2
        for i in 1:length(review_widths))
    # The candidate-temperature field is the frozen authored G1 u AST (q0),
    # while the feedback solve uses the runtime G3-applied q. Keep those two
    # source profiles separate when constructing the independent oracles.
    review_source_capability =
        review_g1.semantic_body.body.value.g1_typed_source_field_program
    review_authored_q = Float64(review_source_capability.source_law.q_W_m3)
    review_ast_temperature = ntuple(i -> begin
        x = review_cell_x[i] - review_origin
        review_left_temperature +
            (review_right_temperature - review_left_temperature) * x / review_length +
            review_authored_q * x * (review_length - x) / (2.0 * review_kxx)
    end, length(review_cell_x))
    review_runtime_lift_temperature = ntuple(i -> begin
        x = review_cell_x[i] - review_origin
        review_left_temperature +
            (review_right_temperature - review_left_temperature) * x / review_length +
            review_q * x * (review_length - x) / (2.0 * review_kxx)
    end, length(review_cell_x))
    review_fv_temperature = ntuple(i -> review_runtime_lift_temperature[i] +
        review_q * review_h^2 / (8.0 * review_kxx), length(review_cell_x))
    @test collect(review_result.result.candidate_temperature_at_cell_centers_K) ≈
        collect(review_ast_temperature) atol=1e-10 rtol=0.0
    @test collect(review_result.result.temperature_K) ≈
        collect(review_fv_temperature) atol=1e-10 rtol=0.0
    review_boundary_delta = review_right_temperature - review_left_temperature
    review_expected_left_flux = review_q * review_length / 2 +
        review_kxx * review_boundary_delta / review_length
    review_expected_right_flux = review_q * review_length / 2 -
        review_kxx * review_boundary_delta / review_length
    @test review_result.result.outward_fourier_flux_left_W_m2 ≈
        review_expected_left_flux atol=1e-10 rtol=0.0
    @test review_result.result.outward_fourier_flux_right_W_m2 ≈
        review_expected_right_flux atol=1e-10 rtol=0.0
    review_expected_source_power = review_q * review_length *
        review_result.result.cross_section_area_m2
    @test review_result.result.integrated_source_W ≈
        review_expected_source_power atol=1e-10 rtol=0.0
    @test review_result.result.energy_balance_residual_W ≈ 0.0 atol=1e-10 rtol=0.0
    review_protocol = _DCCE.CompositionSolveProtocolV1(
        _DCCE.canonical_hash((protocol=:thermal_slab_queue_child_v1,
            max_iterations=24)), 24, 1e-12)
    review_admission = _THERMAL_SLAB_CONSUMER.up3_steady_planar_composition_admit_v1(
        review_case.built.candidate_ref, review_case.built.g1.declaration,
        review_case.built.g2.declaration, review_case.built.g3.declaration,
        review_case.t0.transport, review_case.spatial, review_protocol;
        solver_component=:fv,
        subject_ref=_DCCE.canonical_hash((subject=:thermal_slab,)),
        mission_ref=_DCCE.canonical_hash((mission=:steady_screen,)),
        scenario_ref=_DCCE.canonical_hash(_DCCE.semantic_view(
            review_case.built.identity.scenario_ref)))
    @test review_admission.outcome.status === :ready
    review_feedback_edge_key = only(review_admission.input.feedback_edge_keys)
    review_feedback_edge = only(filter(edge ->
        (edge.producer_component, edge.producer_slot,
            edge.consumer_component, edge.consumer_slot) ==
        review_feedback_edge_key, review_admission.plan.edges))
    review_feedback_key = _DCCE.canonical_hash(
        _DCCE.semantic_view(review_feedback_edge))
    review_feedback_routes = filter(route -> route.numeric_value !== nothing &&
        _DCCE.canonical_hash(route.edge) == review_feedback_key,
        review_execution.routed_value_audit)
    @test Float64[route.numeric_value for route in review_feedback_routes] ==
        Float64[step.applied_q_W_m3 for step in review_fp.iteration_trace]
    println("UP3_R14_REVIEW_HOLDOUT=", JSON3.write((
        candidate_id=review_variant.candidate_id,
        scenario_id=review_variant.scenario_id,
        g1_source_sha256=review_g1.source_bytes.sha256,
        g2_source_sha256=review_g2.source_bytes.sha256,
        mesh=review_case.built.g2.declaration.source.mesh.cells,
        k_base=review_k.base_diag,
        chart_x_scale=review_chart.jacobian_rows[1][1],
        x_boundary_k=(review_x_faces[:x_min], review_x_faces[:x_max]),
        owner_region=first(review_faces).owner_region_id,
        status=review_result.status, iterations=review_fp.iteration_count,
        applied_q_W_m3=review_fp.applied_q_W_m3,
        temperature_K=review_fp.temperature_K,
        energy_balance_residuals_W=Tuple(
            step.solver_energy_balance.balance_residual.value for
            step in review_fp.iteration_trace),
        claim_ceiling=review_result.result.claim_ceiling,
        evidence_credit=review_result.result.evidence_credit)))
    flush(stdout)

    # A fresh, source-authored G3 variant keeps the law but omits its core sensor
    # from the bound controller ports. T0/T1 validate; dispatch fails closed before
    # the separate exact-link guard exercised above.
    up3_tail_started_ns = time_ns()
    println("UP3_TAIL_STAGE=edge_variant_materialize_begin elapsed_ms=",
        (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    edge_variant = _thermal_materialize_source_variant_v1(
        _DCCE_ROOT, _THERMAL_SLAB_CANDIDATE_DIR, :feedback_edge_removed)
    println("UP3_TAIL_STAGE=edge_variant_materialize_end elapsed_ms=",
        (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    println("UP3_TAIL_STAGE=edge_source_case_begin elapsed_ms=",
        (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    edge_case = _thermal_source_case(edge_variant.candidate_directory;
        source_root=edge_variant.source_root)
    println("UP3_TAIL_STAGE=edge_source_case_end elapsed_ms=",
        (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    edge_child = _thermal_v5_queue_child(edge_case)
    edge_g3_record = only(filter(r -> r.layer === :G3, edge_case.records.declarations))
    edge_design = edge_g3_record.semantic_body.body.authored_child_design
    edge_law = edge_design.control_design.temperature_source_feedback
    edge_controller = only(filter(c -> c.controller_id == edge_law.controller_id,
        edge_design.control.controllers))
    edge_matches = Tuple(link for link in edge_design.control_resource_links
        if link.controller_id == edge_controller.controller_id &&
            link.sensor_port_id == edge_law.temperature_sensor_port_id &&
            link.actuator_port_id == edge_law.actuator_port_id &&
            link.fault_id in edge_controller.fault_ids)
    @test edge_case.t0.status === :valid
    @test _DCCE.vnext_t2_up2_validate_input_v2(edge_child.input).status === :valid
    @test hasproperty(edge_design.control_design, :temperature_source_feedback)
    @test length(edge_design.control_resource_links) == 1
    @test isempty(edge_matches)
    edge_queue = _DCCE.VNextUP3ThermalQueueV1()
    _DCCE.vnext_up3_thermal_enqueue!(edge_queue, edge_child)
    edge_selection = _DCCE.vnext_up3_thermal_next!(edge_queue)
    println("UP3_TAIL_STAGE=edge_fv_dispatch_begin elapsed_ms=",
        (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    edge_result = _DCCE.vnext_up3_thermal_dispatch_selected!(edge_queue, edge_selection)
    println("UP3_TAIL_STAGE=edge_fv_dispatch_end elapsed_ms=",
        (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
        Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
    flush(stdout)
    @test edge_result.status === :fail_closed
    @test edge_result.resolution === :none
    @test edge_result.reason === :temperature_source_feedback_invalid
    @test occursin("thermal_G3_temperature_source_ports_not_bound",
        edge_result.result.message)
    # A package/witness candidate mismatch is rejected before queue mutation by
    # the cheap enqueue identity guard; full source validation remains at dispatch.
    wrong_body = _DCCE._vnext_t2_bound_input_body_v2(child_a.input.witness,
        child_b.input.package, child_b.input.adapter, child_b.input.formal_gate,
        child_b.input.scenario, child_b.input.profile)
    wrong_input = _DCCE.VNextT2UP2BoundInputV2(child_a.input.witness,
        child_b.input.package, child_b.input.adapter, child_b.input.formal_gate,
        child_b.input.scenario, child_b.input.profile, _DCCE.canonical_hash(wrong_body))
    wrong_child = _DCCE.vnext_up3_thermal_queue_child_v1(wrong_input,
        base.spatial, child_b.protocol, child_b.subject_ref, child_b.mission_ref,
        child_b.scenario_ref)
    wrong_queue = _DCCE.VNextUP3ThermalQueueV1()
    before_wrong_queue = (children=copy(wrong_queue.children),
        cursor=wrong_queue.cursor, selected=wrong_queue.selected)
    wrong_enqueue_error = try
        _DCCE.vnext_up3_thermal_enqueue!(wrong_queue, wrong_child)
        nothing
    catch err
        err
    end
    @test wrong_enqueue_error isa ArgumentError
    @test wrong_enqueue_error.msg == "vnext_up3_queue_candidate_ref_mismatch"
    @test wrong_queue.children == before_wrong_queue.children
    @test wrong_queue.cursor == before_wrong_queue.cursor
    @test wrong_queue.selected === before_wrong_queue.selected

    # Opt-in only: run this same existing focused consumer file under the
    # follow-up bounded actual-consumer A/B invocation (1200 s, 4 GiB). The
    # default FV route and its existing 24-iteration assertions above remain
    # the baseline and stay outside this branch.
    if get(ENV, "UP3_GRIDAP_Q1_COMPOSITION_FOCUS", "0") == "1"
        q1_dispatch = function (actual)
            child = _thermal_v5_queue_child(actual; max_iterations=24,
                solver_component=:gridap_q1)
            queue = _DCCE.VNextUP3ThermalQueueV1()
            _DCCE.vnext_up3_thermal_enqueue!(queue, child)
            selection = _DCCE.vnext_up3_thermal_next!(queue)
            (child=child,
             dispatch=_DCCE.vnext_up3_thermal_dispatch_selected!(queue, selection))
        end
        assert_q1_trace = Base.@nospecializeinfer function (actual, run)
            Base.@nospecialize actual run
            println("UP3_TAIL_STAGE=q1_assert_helper_enter candidate=", actual.built.candidate_ref.id, " elapsed_ms=", (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=", Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
            flush(stdout)
            child, dispatched = run.child, run.dispatch
            result = dispatched.result
            fp = result.temperature_source_fixed_point
            @test child.solver_component === :gridap_q1
            @test dispatched.status === :screen_only
            @test dispatched.candidate_ref == actual.built.candidate_ref
            @test result.solver_component === :gridap_q1
            @test result.numerical_scope === :source_bound_full_3d_q1_steady_diffusion_screen
            @test fp.measurement_backend === :gridap_q1_cell_center_evaluation
            @test fp.measurement_reduction === :maximum_cell_center
            @test fp.fixed_point_converged === true
            @test fp.max_iterations == 24
            @test 1 <= fp.iteration_count == fp.solver_invocation_count <= 24
            @test fp.residual <= fp.residual_tolerance
            @test result.feedback_status === :screen_only
            @test result.feedback_reason === :residual_tolerance
            @test result.accepted === false && result.evidence_credit == 0
            @test result.physical_validation === false && result.engineering_validation === false
            @test result.provider_invocation_count == 0
println("UP3_TAIL_STAGE=q1_assert_admission_begin candidate=", actual.built.candidate_ref.id, " elapsed_ms=", (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=", Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
flush(stdout)
admit = getfield(_THERMAL_SLAB_CONSUMER, :up3_steady_planar_composition_admit_v1)
expected_admission = Base.invokelatest(admit,
    actual.built.candidate_ref, actual.built.g1.declaration,
    actual.built.g2.declaration, actual.built.g3.declaration,
    actual.t0.transport, actual.spatial, child.protocol;
    solver_component=:gridap_q1, subject_ref=child.subject_ref,
    mission_ref=child.mission_ref, scenario_ref=child.scenario_ref)
println("UP3_TAIL_STAGE=q1_assert_admission_end candidate=", actual.built.candidate_ref.id, " elapsed_ms=", (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=", Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
flush(stdout)
@test expected_admission.outcome.status === :ready
@test expected_admission.plan.plan_hash == result.composition_plan_hash
@test length(expected_admission.plan.edges) == 8
@test length(Set((edge.consumer_component, edge.consumer_slot)
    for edge in expected_admission.plan.edges)) == 8
            execution = result.composition_execution
            @test execution.status === :executed
            @test execution.failure_code === :none
            @test execution.provider_callback_count == fp.iteration_count + 4
            @test execution.solver_callback_count == fp.iteration_count
            @test result.provider_invocation_count == 0 # contract receipt remains nonexecuting
            @test result.solver_invocation_count == execution.solver_callback_count
            @test execution.feedback_trace == fp.iteration_trace
            @test length(execution.resolved_edge_value_hashes) == length(expected_admission.plan.edges)
            @test all(x -> x.payload_hash isa _DCCE.Digest256,
                execution.resolved_edge_value_hashes)
            route_audit = execution.routed_value_audit
            g3_ref, g3_slot, solver_ref, solver_slot =
                only(expected_admission.input.feedback_edge_keys)
            g3_feedback_edge = only(filter(edge ->
                (edge.producer_component, edge.producer_slot,
                    edge.consumer_component, edge.consumer_slot) ==
                (g3_ref, g3_slot, solver_ref, solver_slot),
                expected_admission.plan.edges))
            g3_feedback_key = _DCCE.canonical_hash(
                _DCCE.semantic_view(g3_feedback_edge))
            feedback_routes = filter(route -> route.numeric_value !== nothing &&
                _DCCE.canonical_hash(route.edge) == g3_feedback_key,
                route_audit)
            @test !isempty(feedback_routes)
            @test Float64[route.numeric_value for route in feedback_routes] ==
                Float64[step.applied for step in execution.feedback_trace]
            @test all(step -> isfinite(step.applied) && isfinite(step.next) &&
                isfinite(step.residual_raw) && step.residual_unit === :W_m3 &&
                step.solver_result_hash isa _DCCE.Digest256 &&
                step.provider_result_hash isa _DCCE.Digest256,
                execution.feedback_trace)
            @test all(i == 1 || execution.feedback_trace[i].applied ==
                execution.feedback_trace[i-1].next for i in eachindex(execution.feedback_trace))

            # Cheap contract-negative controls use the actual source-bound
            # callbacks but never call a solver. They guard binding identity,
            # seed semantics, edge admission, callback output typing, and order.
            if actual === base
                csp = parentmodule(typeof(expected_admission.plan))
                runtime_builder = getfield(_THERMAL_SLAB_CONSUMER,
                    :_up3_slab_execution_bindings_v1)
                runtime = runtime_builder(actual.built.candidate_ref,
                    actual.built.g1.declaration, actual.built.g2.declaration,
                    actual.built.g3.declaration, actual.t0.transport,
                    actual.spatial, expected_admission; solver_component=:gridap_q1)
                bindings = runtime.provider_bindings
                seeds = runtime.feedback_seeds
                execute = getfield(csp, :execute_composition_solve_v1)
                @test length(bindings) == 5
                @test length(seeds) == 1
                binding_map = getfield(csp, :_csp_binding_map)
                ordered = binding_map(expected_admission.plan, bindings)
                reversed = binding_map(expected_admission.plan, reverse(bindings))
                @test Set(keys(ordered)) == Set(keys(reversed))
                @test all(ordered[k].component_ref == reversed[k].component_ref
                    for k in keys(ordered))
                input_type = typeof(expected_admission.input)
                component_type = typeof(first(expected_admission.input.components))
                permuted_components = Tuple(component_type(c.component_ref,
                    c.provider_ref, c.code_ref, c.backend_ref,
                    reverse(c.inputs), reverse(c.outputs))
                    for c in reverse(expected_admission.input.components))
                permuted_input = input_type(expected_admission.input.binding,
                    permuted_components, expected_admission.input.protocol;
                    preclassification=expected_admission.input.preclassification,
                    feedback_edge_keys=expected_admission.input.feedback_edge_keys)
                @test permuted_input.input_hash == expected_admission.input.input_hash
                permuted_admission = getfield(csp, :admit_composition_solve)(permuted_input)
                @test permuted_admission.outcome.status === :ready
                @test permuted_admission.plan.plan_hash == expected_admission.plan.plan_hash

                # Exercise order invariance with two complete actual FV fixed
                # points. This avoids repeating the more expensive Q1 solves;
                # the Q1 base and independent holdout remain full consumer gates.
                fv_admission = Base.invokelatest(admit,
                    actual.built.candidate_ref, actual.built.g1.declaration,
                    actual.built.g2.declaration, actual.built.g3.declaration,
                    actual.t0.transport, actual.spatial, child.protocol;
                    solver_component=:fv, subject_ref=child.subject_ref,
                    mission_ref=child.mission_ref, scenario_ref=child.scenario_ref)
                @test fv_admission.outcome.status === :ready
                fv_components_permuted = Tuple(component_type(c.component_ref,
                    c.provider_ref, c.code_ref, c.backend_ref,
                    reverse(c.inputs), reverse(c.outputs))
                    for c in reverse(fv_admission.input.components))
                fv_input_permuted = input_type(fv_admission.input.binding,
                    fv_components_permuted, fv_admission.input.protocol;
                    preclassification=fv_admission.input.preclassification,
                    feedback_edge_keys=fv_admission.input.feedback_edge_keys)
                fv_admission_permuted = getfield(csp, :admit_composition_solve)(
                    fv_input_permuted)
                @test fv_admission_permuted.outcome.status === :ready
                @test fv_admission_permuted.plan.plan_hash == fv_admission.plan.plan_hash
                fv_runtime = runtime_builder(actual.built.candidate_ref,
                    actual.built.g1.declaration, actual.built.g2.declaration,
                    actual.built.g3.declaration, actual.t0.transport,
                    actual.spatial, fv_admission; solver_component=:fv)
                fv_runtime_permuted = runtime_builder(actual.built.candidate_ref,
                    actual.built.g1.declaration, actual.built.g2.declaration,
                    actual.built.g3.declaration, actual.t0.transport,
                    actual.spatial, fv_admission_permuted; solver_component=:fv)
                fv_execution = execute(fv_admission, fv_runtime.provider_bindings;
                    feedback_seeds=fv_runtime.feedback_seeds)
                fv_execution_permuted = execute(fv_admission_permuted,
                    reverse(fv_runtime_permuted.provider_bindings);
                    feedback_seeds=fv_runtime_permuted.feedback_seeds)
                @test fv_execution.status === :executed
                @test fv_execution.provider_callback_count > 0
                @test fv_execution.solver_callback_count > 0
                @test !isempty(fv_execution.feedback_trace)
                @test all(step ->
                    isfinite(step.solver_result.energy_balance_residual_W) &&
                    abs(step.solver_result.energy_balance_residual_W) <= 1e-10 &&
                    step.solver_result.heat_power_balance.balance_residual.value ==
                        step.solver_result.energy_balance_residual_W,
                    fv_execution.feedback_trace)
                @test fv_execution.status === fv_execution_permuted.status
                @test fv_execution.provider_callback_count ==
                    fv_execution_permuted.provider_callback_count
                @test fv_execution.solver_callback_count ==
                    fv_execution_permuted.solver_callback_count
                @test fv_execution.feedback_trace == fv_execution_permuted.feedback_trace
                semantic = getfield(csp, :semantic_view)
                edge_payload_hashes(execution) = Tuple((
                    edge=semantic(item.edge), payload_hash=item.value.payload_hash)
                    for item in execution.resolved_edge_values)
                @test edge_payload_hashes(fv_execution) ==
                    edge_payload_hashes(fv_execution_permuted)
                @test fv_execution.result.result_hash ==
                    fv_execution_permuted.result.result_hash

                hashfn = getfield(csp, :canonical_hash)
                binding_type = typeof(first(bindings))
                first_binding = first(bindings)
                wrong_binding = binding_type(first_binding.component_ref,
                    hashfn((forged_provider=first_binding.provider_ref,)),
                    first_binding.code_ref, first_binding.backend_ref,
                    first_binding.source_identity_hashes,
                    first_binding.callback_kind, first_binding.invoke)
                wrong_bindings = (wrong_binding, bindings[2:end]...)
                wrong_binding_result = execute(expected_admission, wrong_bindings;
                    feedback_seeds=seeds)
                @test wrong_binding_result.failure_code === :binding_invalid
                @test wrong_binding_result.provider_callback_count == 0
                @test wrong_binding_result.solver_callback_count == 0

                seed = only(seeds)
                port_type = typeof(seed.seed_value.port)
                value_type = typeof(seed.seed_value)
                seed_type = typeof(seed)
                original_port = seed.seed_value.port
                function seed_with_port(port; source_ids=seed.seed_value.source_identity_hashes)
                    value = value_type(seed.seed_value.component_ref, port,
                        seed.seed_value.payload, source_ids)
                    seed_type(seed.feedback_edge, seed.seed_edge, value,
                        seed.residual_scale, seed.residual_unit, seed.residual_tolerance)
                end
                function assert_bad_seed(bad_seed)
                    bad = execute(expected_admission, bindings; feedback_seeds=(bad_seed,))
                    @test bad.failure_code === :feedback_seed_invalid
                    @test bad.provider_callback_count == 0
                    @test bad.solver_callback_count == 0
                end
                wrong_unit = typeof(original_port.unit)(:heat,
                    (0, 0, -3, 0, 0, 0, 0))
                assert_bad_seed(seed_with_port(port_type(original_port.label,
                    original_port.slot, original_port.direction, original_port.quantity,
                    wrong_unit, original_port.space, original_port.account,
                    original_port.owner, original_port.ledger_sign, original_port.role)))
                assert_bad_seed(seed_with_port(port_type(original_port.label,
                    original_port.slot, original_port.direction, original_port.quantity,
                    original_port.unit, original_port.space, original_port.account,
                    "forged-seed-owner", original_port.ledger_sign, original_port.role)))
                assert_bad_seed(seed_with_port(port_type(original_port.label,
                    original_port.slot, original_port.direction, original_port.quantity,
                    original_port.unit, original_port.space, "forged-seed-account",
                    original_port.owner, original_port.ledger_sign, original_port.role)))
                assert_bad_seed(seed_with_port(port_type(original_port.label,
                    original_port.slot + 10, original_port.direction,
                    original_port.quantity, original_port.unit, original_port.space,
                    original_port.account, original_port.owner,
                    original_port.ledger_sign, original_port.role)))
                assert_bad_seed(seed_with_port(original_port;
                    source_ids=(hashfn((forged_seed_source=true,)),)))
                wrong_seed_edge = seed_type(seed.feedback_edge, seed.feedback_edge,
                    seed.seed_value, seed.residual_scale, seed.residual_unit,
                    seed.residual_tolerance)
                assert_bad_seed(wrong_seed_edge)
                @test_throws ArgumentError seed_type(seed.feedback_edge, seed.seed_edge,
                    seed.seed_value, seed.residual_scale,
                    typeof(seed.residual_unit)(:heat, (0, 0, 0, 0, 0, 0, 0)),
                    seed.residual_tolerance)

                broken_edges = Tuple(edge for edge in expected_admission.plan.edges
                    if edge != seed.feedback_edge)
                broken_plan = typeof(expected_admission.plan)(
                    expected_admission.plan.input, broken_edges,
                    expected_admission.plan.topological_order,
                    expected_admission.plan.unresolved,
                    expected_admission.plan.failures,
                    expected_admission.plan.deferred_reasons,
                    expected_admission.plan.status, 0, 0)
                broken_admission = typeof(expected_admission)(
                    expected_admission.input, broken_plan,
                    expected_admission.outcome, expected_admission.receipt)
                missing_feedback_edge = execute(broken_admission, bindings;
                    feedback_seeds=seeds)
                @test missing_feedback_edge.failure_code === :admission_invalid
                @test missing_feedback_edge.provider_callback_count == 0
                @test missing_feedback_edge.solver_callback_count == 0

                # A label is diagnostic only: rebuild the actual G1 callback's
                # values with changed labels and pass them through the same
                # output validator without invoking downstream components.
                g1_binding = first(bindings)
                g1_component = only(c for c in expected_admission.plan.input.components
                    if c.component_ref == g1_binding.component_ref)
                empty_inputs = Dict{Int,typeof(seed.seed_value)}()
                g1_return = g1_binding.invoke(empty_inputs)
                relabeled = Tuple(begin
                    p = value.port
                    changed = port_type("renamed-$(p.label)", p.slot, p.direction,
                        p.quantity, p.unit, p.space, p.account, p.owner,
                        p.ledger_sign, p.role)
                    value_type(value.component_ref, changed, value.payload,
                        value.source_identity_hashes)
                end for value in g1_return.outputs)
                checked_labels = getfield(csp, :_csp_output_map)(g1_binding,
                    g1_component, (outputs=relabeled, result=g1_return.result))
                @test length(checked_labels.outputs) == length(g1_return.outputs)
                @test all(getfield(csp, :_csp_validate_port_value)(
                    value, g1_component.component_ref,
                    getfield(csp, :_csp_port_for)(g1_component, :output, value.port.slot),
                    g1_binding.source_identity_hashes)
                    for value in relabeled)

                # A semantic endpoint change in a callback output is rejected
                # after the attempted provider call and before any solver call.
                forged_invoke = function (inputs)
                    returned = g1_binding.invoke(inputs)
                    output = first(returned.outputs)
                    p = output.port
                    forged = port_type(p.label, p.slot, p.direction, p.quantity,
                        p.unit, p.space, "forged-output-account", p.owner,
                        p.ledger_sign, p.role)
                    forged_value = value_type(output.component_ref, forged,
                        output.payload, output.source_identity_hashes)
                    (outputs=(forged_value, returned.outputs[2:end]...),
                        result=returned.result)
                end
                forged_binding = binding_type(g1_binding.component_ref,
                    g1_binding.provider_ref, g1_binding.code_ref,
                    g1_binding.backend_ref, g1_binding.source_identity_hashes,
                    g1_binding.callback_kind, forged_invoke)
                forged_bindings = (forged_binding, bindings[2:end]...)
                forged_output = execute(expected_admission, forged_bindings;
                    feedback_seeds=seeds)
                @test forged_output.failure_code === :runtime_callback_failed
                @test forged_output.provider_callback_count >= 1
                @test forged_output.solver_callback_count == 0
            end

            edges = actual.spatial.new_geometry.edges
            expected_centers = Tuple(((Float64(edges[i]) + Float64(edges[i+1])) / 2,
                0.5, 0.5) for i in 1:(length(edges)-1))
            @test length(result.physical_cell_centers) == length(expected_centers)
            @test all(all(isapprox(result.physical_cell_centers[i][j],
                expected_centers[i][j]; atol=1e-12, rtol=0.0) for j in 1:3)
                for i in eachindex(expected_centers))
            @test length(result.temperature_cell_centers_k) == length(expected_centers)
            @test maximum(result.temperature_cell_centers_k) < maximum(result.temperature_nodes_k)
            @test fp.temperature_K ≈ maximum(result.temperature_cell_centers_k) atol=1e-12 rtol=0.0

            println("UP3_TAIL_STAGE=q1_assert_dcce_input_begin candidate=", actual.built.candidate_ref.id, " elapsed_ms=", (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=", Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
            flush(stdout)
            input = Base.invokelatest(getfield(_DCCE, :dcce_input_v1),
                actual.built.candidate_ref, actual.built.g1.declaration,
                actual.built.g2.declaration, actual.built.g3.declaration,
                actual.t0.transport, actual.spatial)
            println("UP3_TAIL_STAGE=q1_assert_dcce_input_end candidate=", actual.built.candidate_ref.id, " elapsed_ms=", (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=", Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
            flush(stdout)
            trace = fp.iteration_trace
            feedback_fn = getfield(_THERMAL_SLAB_CONSUMER, :thermal_temperature_source_density_input_v1)
            @test length(trace) == fp.iteration_count
            for (i, step) in enumerate(trace)
                println("UP3_TAIL_STAGE=q1_assert_feedback_begin iteration=", i, "/", length(trace), " candidate=", actual.built.candidate_ref.id, " elapsed_ms=", (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=", Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
                flush(stdout)
                feedback = Base.invokelatest(feedback_fn,
                    input, step.maximum_cell_center_temperature_K)
                println("UP3_TAIL_STAGE=q1_assert_feedback_end iteration=", i, "/", length(trace), " status=", feedback.status, " elapsed_ms=", (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=", Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
                flush(stdout)
                @test feedback.status === :ready
                @test step.next_q_W_m3 == feedback.q_W_m3
                @test step.actuator_fraction == feedback.actuator_fraction
                @test step.g1_parameter_hash == feedback.g1_input.parameter_hash
                @test step.residual_W_m3 ≈ abs(step.next_q_W_m3 - step.applied_q_W_m3) atol=1e-12 rtol=0.0
                @test i == 1 || step.applied_q_W_m3 == trace[i-1].next_q_W_m3
                @test isfinite(step.q1_residual_abs) &&
                    step.q1_energy_balance.status === :pass &&
                    step.q1_residual_abs <= step.q1_energy_balance.tolerance_w
                @test step.solver_residual_abs == step.q1_residual_abs
                @test step.solver_energy_balance == step.q1_energy_balance
                @test all(==(step.applied_q_W_m3), step.solver_source_density)
                @test step.g3_source_profile_hash == feedback.g3_source_profile_hash
                @test abs(step.q1_energy_balance.source_power_balance_defect_w) <=
                    step.q1_energy_balance.tolerance_w
            end
            println("UP3_TAIL_STAGE=q1_assert_final_feedback_begin candidate=", actual.built.candidate_ref.id, " elapsed_ms=", (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=", Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
            flush(stdout)
            final_feedback = Base.invokelatest(feedback_fn,
                input, last(trace).maximum_cell_center_temperature_K)
            println("UP3_TAIL_STAGE=q1_assert_final_feedback_end candidate=", actual.built.candidate_ref.id, " elapsed_ms=", (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=", Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
            flush(stdout)
            @test fp.temperature_K == last(trace).maximum_cell_center_temperature_K
            @test fp.controller_id == final_feedback.controller_id
            @test fp.sensor_port_id == final_feedback.sensor_port_id
            @test fp.actuator_port_id == final_feedback.actuator_port_id
            @test fp.resource_link_id == final_feedback.resource_link_id
            @test fp.resource_port_id == final_feedback.resource_port_id
            @test fp.g3_source_profile_hash == final_feedback.g3_source_profile_hash
            @test fp.g3_source_record_hash == final_feedback.g3_source_record_hash
            @test fp.next_g1_parameter_hash == final_feedback.g1_input.parameter_hash
            @test fp.final_gridap_q1_result_hash == last(trace).gridap_q1_result_hash
            result
        end

        println("UP3_TAIL_STAGE=q1_base_dispatch_begin elapsed_ms=",
            (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        q1_base = q1_dispatch(base)
        println("UP3_TAIL_STAGE=q1_base_dispatch_end elapsed_ms=",
            (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        println("UP3_TAIL_STAGE=q1_base_assertions_begin elapsed_ms=",
            (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        q1_base_result = assert_q1_trace(base, q1_base)
        println("UP3_TAIL_STAGE=q1_base_assertions_end elapsed_ms=",
            (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        @test q1_base_result.composition_plan_hash != result_24.result.composition_plan_hash
        @test q1_base_result.result_hash isa _DCCE.Digest256

        q1_independent_variant = _thermal_materialize_up3_blind_holdout_v1(_DCCE_ROOT)
        q1_independent_holdout = _thermal_source_case(
            q1_independent_variant.candidate_directory;
            source_root=q1_independent_variant.source_root)
        @test q1_independent_holdout.t0.status === :valid
        @test q1_independent_variant.candidate_id ==
            "thermal-slab-up4-v5-20261001-up3-blind-l125-k25-t305-n5"
        @test q1_independent_holdout.built.candidate_ref.id ==
            "fusionconceptai://candidate-design/thermal-slab-up4-v5-20261001-up3-blind-l125-k25-t305-n5"
        q1_holdout_chart = q1_independent_holdout.built.g2.declaration.source.chart_map
        @test q1_holdout_chart.jacobian_rows[1][1] == 5//4
        @test q1_independent_holdout.built.g2.declaration.source.mesh.cells == (5, 1, 1)
        @test q1_independent_holdout.built.g1.declaration.K.expression.base_diag[1] == 5//2
        @test q1_independent_holdout.built.g1.declaration.K.expression.domain_max[1] == 5//4
        println("UP3_TAIL_STAGE=q1_independent_holdout_dispatch_begin elapsed_ms=",
            (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        q1_heldout = q1_dispatch(q1_independent_holdout)
        println("UP3_TAIL_STAGE=q1_heldout_dispatch_end elapsed_ms=",
            (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        println("UP3_TAIL_STAGE=q1_heldout_assertions_begin elapsed_ms=",
            (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        q1_heldout_result = assert_q1_trace(q1_independent_holdout, q1_heldout)
        println("UP3_TAIL_STAGE=q1_heldout_assertions_end elapsed_ms=",
            (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        @test q1_heldout_result.candidate_ref != q1_base_result.candidate_ref
        @test q1_heldout_result.source_program_audit.g1_source_ref !=
            q1_base_result.source_program_audit.g1_source_ref
        @test q1_heldout_result.source_program_audit.g2_source_ref !=
            q1_base_result.source_program_audit.g2_source_ref
        @test q1_heldout_result.composition_execution.provider_callback_count > 0
        @test q1_heldout_result.composition_execution.solver_callback_count > 0
        @test q1_heldout_result.result_hash != q1_base_result.result_hash
        @test q1_heldout_result.temperature_source_fixed_point.temperature_K !=
            q1_base_result.temperature_source_fixed_point.temperature_K
        @test q1_heldout_result.residual_abs isa Real
        @test abs(q1_base_result.energy_balance_residual_W) <=
            q1_base_result.energy_balance.tolerance_w
        @test abs(q1_heldout_result.energy_balance_residual_W) <=
            q1_heldout_result.energy_balance.tolerance_w
        @test all(step -> step.q1_energy_balance.status === :pass &&
            abs(step.q1_energy_balance.source_power_balance_defect_w) <=
                step.q1_energy_balance.tolerance_w,
            q1_heldout_result.temperature_source_fixed_point.iteration_trace)

        println("UP3_TAIL_STAGE=q1_edge_dispatch_begin elapsed_ms=",
            (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        q1_edge_child = _thermal_v5_queue_child(edge_case; max_iterations=24,
            solver_component=:gridap_q1)
        q1_edge_queue = _DCCE.VNextUP3ThermalQueueV1()
        _DCCE.vnext_up3_thermal_enqueue!(q1_edge_queue, q1_edge_child)
        q1_edge_selection = _DCCE.vnext_up3_thermal_next!(q1_edge_queue)
        q1_edge = _DCCE.vnext_up3_thermal_dispatch_selected!(q1_edge_queue,
            q1_edge_selection)
        @test q1_edge.status === :fail_closed
        @test q1_edge.reason === :temperature_source_feedback_invalid
        @test occursin("thermal_G3_temperature_source_ports_not_bound",
            q1_edge.result.message)
        @test !hasproperty(q1_edge.result, :temperature_source_fixed_point)
        println("UP3_TAIL_STAGE=q1_edge_dispatch_end elapsed_ms=",
            (time_ns() - up3_tail_started_ns) / 1.0e6, " gc_live_bytes=",
            Base.gc_live_bytes(), " jit_total_bytes=", Base.jit_total_bytes())
        flush(stdout)
        println("UP3_GRIDAP_Q1_FOLLOWUP=existing_thermal_slab_actual_consumer_AB;seconds=1200;memory_gib=4;candidate=", q1_base_result.candidate_ref.id, ";plan=", q1_base_result.composition_plan_hash.value, ";iterations=", q1_base_result.temperature_source_fixed_point.iteration_count)
        flush(stdout)
    end
    println("UP5_QUEUE_ACTUAL_JSON ", JSON3.write((schema="up5-native-v5-queue-result-v1",
        selected_A=(candidate_ref=(id=child_a.input.package.candidate_ref.id,
                version=child_a.input.package.candidate_ref.version),
            g1_source_ref=(id=child_a.input.witness.g1.record.source_ref.id,
                version=child_a.input.witness.g1.record.source_ref.version),
            scenario_ref=child_a.scenario_ref.value,
            input_hash=result_a.result.composition_input_hash.value,
            plan_hash=result_a.result.composition_plan_hash.value,
            result_hash=result_a.result.result_hash.value,
            temperature_K=result_a.result.temperature_K,
            outward_fourier_flux_W_m2=(left=result_a.result.outward_fourier_flux_left_W_m2,
                right=result_a.result.outward_fourier_flux_right_W_m2),
            residual_norm=result_a.result.residual_norm),
        selected_B=(candidate_ref=(id=child_b.input.package.candidate_ref.id,
                version=child_b.input.package.candidate_ref.version),
            g1_source_ref=(id=child_b.input.witness.g1.record.source_ref.id,
                version=child_b.input.witness.g1.record.source_ref.version),
            scenario_ref=child_b.scenario_ref.value,
            input_hash=result_b.result.composition_input_hash.value,
            plan_hash=result_b.result.composition_plan_hash.value,
            result_hash=result_b.result.result_hash.value,
            temperature_K=result_b.result.temperature_K,
            outward_fourier_flux_W_m2=(left=result_b.result.outward_fourier_flux_left_W_m2,
                right=result_b.result.outward_fourier_flux_right_W_m2),
            residual_norm=result_b.result.residual_norm,
            feedback_status=result_b.result.feedback_status),
        selected_A_4=(status=result_a.status, result_hash=result_a.result.result_hash.value,
            fixed_point=(iterations=fp_4.iteration_count, max_iterations=fp_4.max_iterations,
                converged=fp_4.fixed_point_converged, applied_q_W_m3=fp_4.applied_q_W_m3)),
        selected_A_24=(status=result_24.status, result_hash=result_24.result.result_hash.value,
            fixed_point=(iterations=fp_24.iteration_count, max_iterations=fp_24.max_iterations,
                converged=fp_24.fixed_point_converged, applied_q_W_m3=fp_24.applied_q_W_m3)))))
end

@testset "native V5 queue rejects absent and mismatched selections before UP3" begin
    # Earlier UP3 suites retain large source/package temporaries until their
    # scopes unwind. Reclaim them before rebuilding the two admission packages
    # used only to exercise queue identity rejection.
    GC.gc(true)
    base_variant = _thermal_materialize_source_variant_v1(_DCCE_ROOT, _THERMAL_SLAB_CANDIDATE_DIR, :base_no_law)
    base = _thermal_source_case(base_variant.candidate_directory; source_root=base_variant.source_root)
    child = _thermal_v5_queue_child(base)
    base_spatial = base.spatial
    base = nothing
    base_variant = nothing
    GC.gc(true)
    edited = _thermal_source_case(_THERMAL_SLAB_K22_CANDIDATE_DIR)
    child_b = _thermal_v5_queue_child(edited)
    edited = nothing
    GC.gc(true)
    selection_queue = _DCCE.VNextUP3ThermalQueueV1()
    _DCCE.vnext_up3_thermal_enqueue!(selection_queue, child)
    _DCCE.vnext_up3_thermal_enqueue!(selection_queue, child_b)
    correct_selection = _DCCE.vnext_up3_thermal_next!(selection_queue)
    bad_index_selection = _DCCE.VNextUP3ThermalQueueSelectionV1(
        selection_queue, 2, child_b)
    @test bad_index_selection.queue === selection_queue
    @test 1 <= bad_index_selection.index <= length(selection_queue.children)
    @test selection_queue.children[bad_index_selection.index] === bad_index_selection.child
    @test selection_queue.selected !== bad_index_selection.index
    @test_throws ArgumentError _DCCE.vnext_up3_thermal_dispatch_selected!(
        selection_queue, bad_index_selection)
    @test selection_queue.selected === correct_selection.index
    bad_child_selection = _DCCE.VNextUP3ThermalQueueSelectionV1(
        selection_queue, correct_selection.index, child_b)
    @test bad_child_selection.queue === selection_queue
    @test bad_child_selection.index === selection_queue.selected
    @test selection_queue.children[bad_child_selection.index] !== bad_child_selection.child
    @test_throws ArgumentError _DCCE.vnext_up3_thermal_dispatch_selected!(
        selection_queue, bad_child_selection)
    @test selection_queue.selected === correct_selection.index

    empty_queue = _DCCE.VNextUP3ThermalQueueV1()
    @test _DCCE.vnext_up3_thermal_next!(empty_queue) === nothing
    absent = _DCCE.vnext_up3_thermal_dispatch_selected!(empty_queue, nothing)
    @test absent.status === :typed_absent
    @test absent.resolution === :terminal_deferred
    @test absent.reason === :queue_selection_absent
    @test absent.candidate_ref === nothing
    @test absent.result === nothing
    absent_child_error = try
        _DCCE.vnext_up3_thermal_queue_child_v1(nothing, base_spatial,
            child.protocol, child.subject_ref, child.mission_ref, child.scenario_ref)
        nothing
    catch err
        err
    end
    @test absent_child_error isa ArgumentError
    @test absent_child_error.msg === "vnext_up3_child_input_absent"

    # Bypass the enqueue API with the opposite cross-candidate pairing to keep
    # dispatch-time full T2 revalidation covered against direct queue corruption.
    bad_body = _DCCE._vnext_t2_bound_input_body_v2(child_b.input.witness,
        child.input.package, child.input.adapter, child.input.formal_gate,
        child.input.scenario, child.input.profile)
    bad_input = _DCCE.VNextT2UP2BoundInputV2(child_b.input.witness,
        child.input.package, child.input.adapter, child.input.formal_gate,
        child.input.scenario, child.input.profile, _DCCE.canonical_hash(bad_body))
    bad_child = _DCCE.vnext_up3_thermal_queue_child_v1(bad_input,
        base_spatial, child.protocol, child.subject_ref, child.mission_ref,
        child.scenario_ref)
    bad_queue = _DCCE.VNextUP3ThermalQueueV1()
    push!(bad_queue.children, bad_child)
    bad_selection = _DCCE.vnext_up3_thermal_next!(bad_queue)
    bad_result = _DCCE.vnext_up3_thermal_dispatch_selected!(bad_queue, bad_selection)
    @test bad_result.status === :fail_closed
    @test bad_result.resolution === :none
    @test bad_result.reason === :t2_preflight_candidate_ref_mismatch
    @test bad_result.result.status === :fail_closed
    @test bad_result.result.reason === :t2_preflight_candidate_ref_mismatch

    # A valid bound input with an invalid local composition protocol is stopped
    # before admission/execution; no consumer result or solver call is exposed.
    @test _DCCE.vnext_t2_up2_validate_input_v2(child.input).status === :valid
    invalid_protocol_child = _DCCE.vnext_up3_thermal_queue_child_v1(
        child.input, base_spatial, nothing, child.subject_ref,
        child.mission_ref, child.scenario_ref)
    protocol_queue = _DCCE.VNextUP3ThermalQueueV1()
    _DCCE.vnext_up3_thermal_enqueue!(protocol_queue, invalid_protocol_child)
    protocol_selection = _DCCE.vnext_up3_thermal_next!(protocol_queue)
    invalid_protocol = _DCCE.vnext_up3_thermal_dispatch_selected!(
        protocol_queue, protocol_selection)
    @test invalid_protocol.status === :fail_closed
    @test invalid_protocol.resolution === :none
    @test invalid_protocol.reason === :composition_protocol_invalid
    @test invalid_protocol.result === nothing
end

const _THERMAL_G2_REGION_ORDER_REVERSED_DIR =
    "test/fixtures/g2_region_order/current-source-reversed-candidate"

function _thermal_g2_current_source_region_order_case(candidate_directory)
    built = _DCCE._vnext_current_source_candidate_records_v1(_DCCE_ROOT,
        candidate_directory)
    records = _DCCE._vnext_current_source_records_v1(built)
    t0 = _DCCE.vnext_declaration_transport_local_v1(records.candidate,
        records.declarations, records.children, records.feedback;
        frozen_context=built.root)
    g2_record = only(filter(record -> record.layer === :G2,
        records.declarations))
    source = g2_record.semantic_body.body.source
    projection = _DCCE.g2_v5_source_projection_v1(records.g2)
    (built=built, records=records, t0=t0, g2_record=g2_record,
        source=source, projection=projection)
end

@testset "current-source G2 partition is keyed by directed region IDs" begin
    authored = _thermal_g2_current_source_region_order_case(
        "benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2")
    reversed = _thermal_g2_current_source_region_order_case(
        _THERMAL_G2_REGION_ORDER_REVERSED_DIR)

    @test authored.built.candidate_ref == reversed.built.candidate_ref
    @test authored.t0.status === reversed.t0.status === :valid

    # Rebuild the child from its manifest-pinned logical path. Its typed and
    # numeric fields must remain exactly those returned by the source builder.
    child_entry = reversed.built.entries.g3_child_design_source_jl
    child_sha = _DCCE.Digest256(reversed.built.child_sha)
    rebuilt_child = _DCCE.vnext_t2_v3_rebuild_g3_child_design_source_v1(
        _DCCE.VNextT0LocalBytesV1(copy(child_entry.bytes), child_sha), child_sha,
        child_entry.logical_path)
    @test rebuilt_child.source_path == child_entry.logical_path
    @test _DCCE.canonical_json(rebuilt_child) ==
        _DCCE.canonical_json(reversed.built.child_design)
    @test reversed.built.child_design.provider_route_selection.source_path ==
        child_entry.logical_path
    authored_child_with_reversed_path = merge(authored.built.child_design,
        (source_path=reversed.built.child_design.source_path,
            provider_route_selection=merge(
                authored.built.child_design.provider_route_selection,
                (source_path=reversed.built.child_design.provider_route_selection.source_path,))))
    @test _DCCE.canonical_json(authored_child_with_reversed_path) ==
        _DCCE.canonical_json(reversed.built.child_design)
    wrong_child_path =
        "benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2/g3_child_design_source.jl"
    wrong_path_error = try
        _DCCE.vnext_t2_v3_rebuild_g3_child_design_source_v1(
            _DCCE.VNextT0LocalBytesV1(copy(child_entry.bytes), child_sha), child_sha,
            wrong_child_path)
        nothing
    catch err
        err
    end
    @test wrong_path_error isa ArgumentError
    @test wrong_path_error.msg == "rebuilt G3 child source path mismatch"
    independent_g3 = _DCCE._vnext_current_source_independent_g3_inputs_v1(
        reversed.built, reversed.records, reversed.t0.transport)
    @test hasproperty(independent_g3, :expected)
    @test _DCCE.g2mb_admit(authored.source).structural_status === :valid
    @test _DCCE.g2mb_admit(reversed.source).structural_status === :valid
    @test _DCCE.g2mb_admit(authored.source).metric_status === :valid
    @test _DCCE.g2mb_admit(reversed.source).metric_status === :valid

    # Fresh records bind the changed G2 authored input. The G1 builder stays
    # byte-identical; the G3 builder differs only to guard the reversed child
    # logical path, whose complete typed/numeric body was compared above.
    authored_g1 = only(filter(record -> record.layer === :G1,
        authored.records.declarations))
    reversed_g1 = only(filter(record -> record.layer === :G1,
        reversed.records.declarations))
    authored_g3 = only(filter(record -> record.layer === :G3,
        authored.records.declarations))
    reversed_g3 = only(filter(record -> record.layer === :G3,
        reversed.records.declarations))
    @test authored.g2_record.source_bytes.sha256 == reversed.g2_record.source_bytes.sha256
    @test authored.g2_record.semantic_body.body.authored_builder_input.sha256 !=
        reversed.g2_record.semantic_body.body.authored_builder_input.sha256
    @test authored.source.source_hash != reversed.source.source_hash
    @test authored_g1.source_bytes.sha256 == reversed_g1.source_bytes.sha256
    @test authored_g3.source_bytes.sha256 != reversed_g3.source_bytes.sha256

    authored_source_order = Tuple(region.region_id for region in
        authored.source.region_interface.regions)
    reversed_source_order = Tuple(region.region_id for region in
        reversed.source.region_interface.regions)
    @test authored_source_order == ("local_unit_cube_left", "local_unit_cube_right")
    @test reversed_source_order == reverse(authored_source_order)

    authored_genome = authored.projection.genome
    reversed_genome = reversed.projection.genome
    authored_regions = Tuple(_DCCE.semantic_view(region) for region in
        authored_genome.region_interface.regions)
    reversed_regions = Tuple(_DCCE.semantic_view(region) for region in
        reversed_genome.region_interface.regions)
    @test authored_regions == reversed_regions
    @test Tuple(region.region_id for region in authored_genome.region_interface.regions) ==
        ("local_unit_cube_left", "local_unit_cube_right")
    authored_interface = only(authored_genome.region_interface.interfaces)
    reversed_interface = only(reversed_genome.region_interface.interfaces)
    @test _DCCE.semantic_view(authored_interface) == _DCCE.semantic_view(reversed_interface)
    @test authored_interface.left_region_id == "local_unit_cube_left"
    @test authored_interface.right_region_id == "local_unit_cube_right"
    @test authored_interface.normal == reversed_interface.normal == 1

    patch_view(patch) = (face=patch.face, region_id=patch.region_id,
        lower=patch.lower, upper=patch.upper)
    authored_patches = Tuple(patch_view(patch) for patch in
        authored_genome.plan.exterior.boundary_patches)
    reversed_patches = Tuple(patch_view(patch) for patch in
        reversed_genome.plan.exterior.boundary_patches)
    @test authored_patches == reversed_patches
    @test Set((patch.face, patch.region_id) for patch in authored_patches) == Set((
        (:x_min, "local_unit_cube_left"), (:x_max, "local_unit_cube_right"),
        (:y_min, "local_unit_cube_left"), (:y_min, "local_unit_cube_right"),
        (:y_max, "local_unit_cube_left"), (:y_max, "local_unit_cube_right"),
        (:z_min, "local_unit_cube_left"), (:z_min, "local_unit_cube_right"),
        (:z_max, "local_unit_cube_left"), (:z_max, "local_unit_cube_right")))
    @test authored_genome.plan.mesh.region_ids == reversed_genome.plan.mesh.region_ids
    @test authored.projection.source_map_retained && reversed.projection.source_map_retained
    @test authored.projection.claim_ceiling === :contract_only
    @test reversed.projection.claim_ceiling === :contract_only

    geometry_hash(genome) = _DCCE.canonical_hash((region_interface=genome.region_interface,
        plan=genome.plan)).value
    source_and_projection_view(case) = (
        source_ref=(id=case.source.source_ref.id, version=case.source.source_ref.version),
        source_hash=case.source.source_hash.value,
        factory_source_sha256=case.g2_record.source_bytes.sha256.value,
        authored_builder_input_sha256=
            case.g2_record.semantic_body.body.authored_builder_input.sha256.value,
        g3_authored_builder_source_sha256=case.records.g3_record.source_bytes.sha256.value,
        g3_authored_builder_source_path=case.records.g3_record.source_locator.source_path,
        g3_authored_child_source_sha256=
            case.records.g3_record.semantic_body.body.authored_child_design_input.sha256.value,
        g3_authored_child_source_path=
            case.records.g3_record.semantic_body.body.authored_child_design.source_path,
        declaration_ref=(id=case.g2_record.declaration_ref.id,
            version=case.g2_record.declaration_ref.version),
        declaration_identity_hash=case.g2_record.declaration_identity_hash.value,
        projected_candidate_hash=case.projection.genome.candidate_hash.value,
        projected_geometry_hash=geometry_hash(case.projection.genome),
        oriented_region_ids=Tuple(region.region_id for region in
            case.projection.genome.region_interface.regions),
        exterior_owners=Tuple((face=String(p.face), region_id=p.region_id) for p in
            case.projection.genome.plan.exterior.boundary_patches))
    println("G2_REGION_ORDER_ACTUAL_JSON=" * JSON3.write((
        schema="current-source-g2-region-order-actual-v1",
        base=source_and_projection_view(authored),
        reversed=source_and_projection_view(reversed))))
    flush(stdout)
end
end
end # !_THERMAL_Q1_DIAGNOSTIC_ONLY

# Instantaneous D-T screen to the existing typed G1/FV source consumer.
@testset "candidate D-T screen output reaches actual thermal residual RHS" begin
    case = _thermal_source_case()
    built = case.built
    rt = Main.FusionRuntimeV4
    thermal = Main.SteadyPlanarThermalDiffusionConsumerV1
    bundle, spatial = case.t0.transport, case.spatial
    input = _DCCE.dcce_input_v1(built.candidate_ref, built.g1.declaration,
        built.g2.declaration, built.g3.declaration, bundle, spatial)
    baseline = thermal.execute_steady_planar_thermal_diffusion_v1(
        built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, bundle, spatial)
    @test baseline.volume_source_W_m3 == Tuple(spatial.field.source)
    power_density = _DCCE.UnitSignature((-1, 1, -3, 0, 0, 0, 0))
    density = _DCCE.UnitSignature((-3, 0, 0, 0, 0, 0, 0))
    energy = _DCCE.UnitSignature((2, 1, -2, 0, 0, 0, 0))
    volume_unit = _DCCE.UnitSignature((3, 0, 0, 0, 0, 0, 0))
    seconds = _DCCE.UnitSignature((0, 0, 1, 0, 0, 0, 0))
    one = _DCCE.UnitSignature()
    dq(v, u, d) = rt.DTFusionQuantityV1(v, u, d)
    plasma = rt.DTFusionReactivityInputV1(
        dq(1.0e17, :m3_inverse, density), dq(1.0e17, :m3_inverse, density),
        dq(10.0, :keV, energy), dq(1.0, :m3, volume_unit),
        dq(0.01, :s, seconds), dq(0.5, :one, one),
        dq(1.0, :W_m3, power_density), dq(0.25, :W_m3, power_density))
    chart = built.g2.declaration.source.chart_map
    geometry_volume = abs(prod(Float64(chart.jacobian_rows[i][i]) *
        Float64(chart.domain_upper[i] - chart.domain_lower[i]) for i in 1:3))
    @test baseline.integrated_source_W ≈ geometry_volume atol=1e-12 rtol=0
    thermal_region = only(filter(f -> f.face === :x_min,
        built.g2.declaration.source.faces)).owner_region_id
    spec = (schema="candidate-dt-to-thermal-source-v1",
        candidate_ref=input.candidate_ref, plasma_region_id="synthetic-plasma",
        thermal_region_id=thermal_region, plasma_input=plasma,
        wall_transfer_fraction=dq(1.0, :one, one),
        wall_volume_m3=dq(geometry_volume, :m3, volume_unit),
        q_bounds_W_m3=(dq(1//100, :W_m3, power_density),
            dq(2//1, :W_m3, power_density)),
        parameter_id="candidate-dt-source-q")
    result = thermal.execute_steady_planar_dt_screen_thermal_v1(
        built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, bundle, spatial, spec)
    provider = rt.evaluate_dt_fusion_reactivity_v1(plasma)
    @test provider.status === :screen_only
    @test result.status === :screen_only
    @test result.candidate_bound === false
    @test result.physical_evidence === false
    @test result.evidence_credit == 0
    @test result.thermal_result.volume_source_W_m3 == result.rhs_source_W_m3
    @test all(==(result.rhs_source_W_m3[1]), result.rhs_source_W_m3)
    @test result.thermal_result.residual_norm <= 1e-12
    @test abs(result.energy_balance_residual_W) <= 1e-10
    @test isapprox(result.transferred_power_W,
        provider.net_thermal_source_W_m3 * result.plasma_volume_m3;
        rtol=1e-12, atol=1e-12)
    @test provider.deposited_alpha_power_density_W_m3 > 0.0
    @test provider.auxiliary_power_density_W_m3 > 0.0
    @test provider.declared_loss_power_density_W_m3 > 0.0
    @test isapprox(provider.net_thermal_source_W_m3,
        provider.deposited_alpha_power_density_W_m3 +
            provider.auxiliary_power_density_W_m3 -
            provider.declared_loss_power_density_W_m3; rtol=1e-12, atol=1e-12)
    @test result.thermal_result.volume_source_W_m3 != Tuple(case.spatial.field.source)
    @test isapprox(result.thermal_result.integrated_source_W,
        result.transferred_power_W; rtol=1e-10, atol=1e-12)
    @test isapprox(result.thermal_result.integrated_source_W,
        result.rhs_source_W_m3[1] * geometry_volume; rtol=1e-10, atol=1e-12)
    args = (built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, bundle, spatial)
    half_transfer = thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(spec, (wall_transfer_fraction=dq(0.5, :one, one),)))
    @test isapprox(half_transfer.transferred_power_W, result.transferred_power_W / 2;
        rtol=1e-12, atol=1e-12)
    @test isapprox(half_transfer.thermal_result.integrated_source_W,
        half_transfer.transferred_power_W; rtol=1e-10, atol=1e-12)
    @test all(isapprox(q, half_transfer.rhs_source_W_m3[1]; rtol=0.0, atol=1e-12)
        for q in half_transfer.thermal_result.volume_source_W_m3)
    requested_q_wall_W_m3 = half_transfer.transferred_power_W / half_transfer.thermal_volume_m3
    consumed_q_W_m3 = first(half_transfer.rhs_source_W_m3)
    @test half_transfer.thermal_result.volume_source_W_m3 == half_transfer.rhs_source_W_m3
    @test isapprox(consumed_q_W_m3, requested_q_wall_W_m3; rtol=0.0,
        atol=8eps(max(abs(requested_q_wall_W_m3), 1.0)))
    println("UP2_DT_HALF_TRANSFER_ROUNDTRIP=", (requested_q_wall_W_m3=requested_q_wall_W_m3,
        consumed_q_W_m3=consumed_q_W_m3))
    derived_wall = thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(spec, (wall_volume_m3=nothing,)))
    @test derived_wall.thermal_volume_m3 == geometry_volume
    @test derived_wall.transferred_power_W == result.transferred_power_W
    @test derived_wall.thermal_result.result_hash == result.thermal_result.result_hash
    @test derived_wall.candidate_spec_hash != result.candidate_spec_hash
    @test derived_wall.result_hash != result.result_hash
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(spec, (candidate_ref="foreign-candidate",)))
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(spec, (thermal_region_id="wrong-wall-region",)))
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(spec, (wall_transfer_fraction=dq(2.0, :one, one),)))
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(spec, (wall_transfer_fraction=dq(-0.1, :one, one),)))
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(spec, (plasma_input=nothing,)))
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(spec, (wall_transfer_fraction=dq(1//2, :W_m3, power_density),)))
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(spec, (wall_volume_m3=dq(2 * geometry_volume,
            :m3, volume_unit),)))
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(spec, (wall_volume_m3=dq(geometry_volume, :m3, power_density),)))
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(spec, (q_bounds_W_m3=(dq(1//2, :W_m3, volume_unit),
            dq(2//1, :W_m3, power_density)),)))
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(spec, (q_bounds_W_m3=nothing,)))
    out_of_domain_plasma = rt.DTFusionReactivityInputV1(plasma.nD_m3,
        plasma.nT_m3, dq(0.2, :keV, energy), plasma.volume_m3,
        plasma.interval_s, plasma.alpha_deposition_fraction,
        plasma.auxiliary_power_density_W_m3, plasma.declared_loss_power_density_W_m3)
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(spec, (plasma_input=out_of_domain_plasma,)))
    negative_density_plasma = rt.DTFusionReactivityInputV1(
        dq(-1.0, :m3_inverse, density), plasma.nT_m3, plasma.Ti_keV,
        plasma.volume_m3, plasma.interval_s, plasma.alpha_deposition_fraction,
        plasma.auxiliary_power_density_W_m3, plasma.declared_loss_power_density_W_m3)
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(spec, (plasma_input=negative_density_plasma,)))
    loss_dominated_plasma = rt.DTFusionReactivityInputV1(plasma.nD_m3,
        plasma.nT_m3, plasma.Ti_keV, plasma.volume_m3, plasma.interval_s,
        plasma.alpha_deposition_fraction, plasma.auxiliary_power_density_W_m3,
        dq(10.0, :W_m3, power_density))
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(spec, (plasma_input=loss_dominated_plasma,)))
    zero_transfer_zero_minimum = merge(spec,
        (wall_transfer_fraction=dq(0.0, :one, one),
         q_bounds_W_m3=(dq(0//1, :W_m3, power_density),
             dq(2//1, :W_m3, power_density))))
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(zero_transfer_zero_minimum,
            (plasma_input=loss_dominated_plasma,)))
    @test result.source_mode === :instantaneous
    explicit_instant = thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., spec; source_mode=:instantaneous)
    @test explicit_instant.source_mode === :instantaneous
    @test explicit_instant.result_hash == result.result_hash

    # Independent equal-fuel burn oracle: dn/dt = -<sigma v> n^2,
    # hence n(t) = n0 / (1 + <sigma v> n0 t) at fixed Ti.
    burn_interval_s = 1.0e5
    burn_plasma = rt.DTFusionReactivityInputV1(plasma.nD_m3, plasma.nT_m3,
        plasma.Ti_keV, plasma.volume_m3, dq(burn_interval_s, :s, seconds),
        plasma.alpha_deposition_fraction, plasma.auxiliary_power_density_W_m3,
        plasma.declared_loss_power_density_W_m3)
    burn_provider = rt.evolve_dt_fusion_composition_v1(burn_plasma)
    @test burn_provider.status === :screen_only
    @test burn_provider.integration_model === :analytic_composition_evolution
    n0 = Float64(burn_plasma.nD_m3.value)
    dt = Float64(burn_plasma.interval_s.value)
    expected_final = n0 / (1.0 + burn_provider.frozen_temperature_reactivity_m3_s * n0 * dt)
    expected_extent = n0 - expected_final
    @test expected_extent / n0 > 0.4
    @test isapprox(burn_provider.final_nD_m3, expected_final; rtol=1e-12, atol=0.0)
    @test isapprox(burn_provider.final_nT_m3, expected_final; rtol=1e-12, atol=0.0)
    @test isapprox(burn_provider.reaction_extent_per_m3, expected_extent;
        rtol=1e-12, atol=0.0)
    @test isapprox(burn_provider.deuterium_consumed_count, expected_extent *
        burn_plasma.volume_m3.value; rtol=1e-12, atol=1e-4)
    @test isapprox(burn_provider.tritium_consumed_count, expected_extent *
        burn_plasma.volume_m3.value; rtol=1e-12, atol=1e-4)
    @test burn_provider.helium4_birth_count == burn_provider.fusion_reaction_count
    @test burn_provider.neutron_birth_count == burn_provider.fusion_reaction_count
    @test all(abs(x) <= 1e-12 * n0 for x in (
        burn_provider.deuterium_particle_balance_residual_per_m3,
        burn_provider.tritium_particle_balance_residual_per_m3,
        burn_provider.helium_particle_balance_residual_per_m3,
        burn_provider.neutron_particle_balance_residual_per_m3,
        burn_provider.nucleon_inventory_balance_residual_per_m3))

    mev_j = 1.602176634e-13
    alpha_expected_J_m3 = expected_extent * 3.5 * mev_j
    neutron_expected_J_m3 = expected_extent * 14.1 * mev_j
    fusion_expected_J_m3 = alpha_expected_J_m3 + neutron_expected_J_m3
    thermal_expected_J_m3 = burn_plasma.alpha_deposition_fraction.value *
        alpha_expected_J_m3 + burn_plasma.auxiliary_power_density_W_m3.value * dt -
        burn_plasma.declared_loss_power_density_W_m3.value * dt
    @test isapprox(burn_provider.alpha_birth_energy_density_J_m3,
        alpha_expected_J_m3; rtol=1e-12, atol=1e-8)
    @test isapprox(burn_provider.neutron_birth_energy_density_J_m3,
        neutron_expected_J_m3; rtol=1e-12, atol=1e-8)
    @test isapprox(burn_provider.fusion_birth_energy_density_J_m3,
        fusion_expected_J_m3; rtol=1e-12, atol=1e-8)
    @test isapprox(burn_provider.net_thermal_source_energy_density_J_m3,
        thermal_expected_J_m3; rtol=1e-12, atol=1e-8)
    @test isapprox(burn_provider.alpha_birth_energy_J, alpha_expected_J_m3 * burn_plasma.volume_m3.value; rtol=1e-12, atol=1e-8)
    @test isapprox(burn_provider.neutron_birth_energy_J, neutron_expected_J_m3 * burn_plasma.volume_m3.value; rtol=1e-12, atol=1e-8)
    @test isapprox(burn_provider.fusion_birth_energy_J, fusion_expected_J_m3 * burn_plasma.volume_m3.value; rtol=1e-12, atol=1e-8)
    @test isapprox(burn_provider.fusion_reaction_count, expected_extent * burn_plasma.volume_m3.value; rtol=1e-12, atol=1e-4)
    @test abs(burn_provider.fusion_energy_partition_residual_J) <= 1e-8
    @test abs(burn_provider.thermal_energy_account_residual_J) <= 1e-8
    @test isapprox(burn_provider.net_thermal_source_energy_J,
        burn_provider.net_thermal_source_energy_density_J_m3 *
            burn_plasma.volume_m3.value; rtol=1e-12, atol=1e-8)

    # Compare the interval-average burn source to the initial frozen-rate
    # source, using a one-second public provider probe to stay within its
    # frozen-composition exposure guard.
    frozen_probe_input = rt.DTFusionReactivityInputV1(burn_plasma.nD_m3,
        burn_plasma.nT_m3, burn_plasma.Ti_keV, burn_plasma.volume_m3,
        dq(1.0, :s, seconds), burn_plasma.alpha_deposition_fraction,
        burn_plasma.auxiliary_power_density_W_m3,
        burn_plasma.declared_loss_power_density_W_m3)
    frozen_probe = rt.evaluate_dt_fusion_reactivity_v1(frozen_probe_input)
    q_avg_W_m3 = burn_provider.net_thermal_source_energy_density_J_m3 / dt
    @test frozen_probe.status === :screen_only
    @test abs(q_avg_W_m3 - frozen_probe.net_thermal_source_W_m3) >
        0.1 * abs(frozen_probe.net_thermal_source_W_m3)

    burn_spec = merge(spec, (plasma_input=burn_plasma,))
    burn_result = thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., burn_spec; source_mode=:composition_interval_average)
    @test burn_result.source_mode === :composition_interval_average
    @test burn_result.provider_result.integration_model === :analytic_composition_evolution
    @test burn_result.provider_result_hash != result.provider_result_hash
    @test burn_result.result_hash != result.result_hash
    @test isapprox(burn_result.transferred_power_W * dt,
        burn_provider.net_thermal_source_energy_J * spec.wall_transfer_fraction.value;
        rtol=1e-12, atol=1e-8)
    @test isapprox(burn_result.transferred_power_W,
        q_avg_W_m3 * burn_plasma.volume_m3.value * spec.wall_transfer_fraction.value;
        rtol=1e-12, atol=1e-8)
    @test isapprox(burn_result.rhs_source_W_m3[1],
        burn_result.transferred_power_W / geometry_volume; rtol=1e-12, atol=1e-12)
    @test all(==(burn_result.rhs_source_W_m3[1]), burn_result.rhs_source_W_m3)
    @test burn_result.thermal_result.volume_source_W_m3 == burn_result.rhs_source_W_m3
    @test isapprox(burn_result.thermal_result.integrated_source_W,
        burn_result.transferred_power_W; rtol=1e-10, atol=1e-12)
    @test burn_result.thermal_result.residual_norm <= 1e-12
    @test abs(burn_result.energy_balance_residual_W) <= 1e-10

    half_burn = thermal.execute_steady_planar_dt_screen_thermal_v1(args...,
        merge(burn_spec, (wall_transfer_fraction=dq(0.5, :one, one),));
        source_mode=:composition_interval_average)
    @test isapprox(half_burn.transferred_power_W,
        burn_result.transferred_power_W / 2; rtol=1e-12, atol=1e-8)
    @test isapprox(half_burn.rhs_source_W_m3[1],
        burn_result.rhs_source_W_m3[1] / 2; rtol=1e-12, atol=1e-12)
    @test half_burn.provider_result_hash == burn_result.provider_result_hash
    @test isapprox(half_burn.thermal_result.integrated_source_W,
        half_burn.transferred_power_W; rtol=1e-10, atol=1e-12)

    zero_fuel = rt.DTFusionReactivityInputV1(dq(0.0, :m3_inverse, density),
        burn_plasma.nT_m3, burn_plasma.Ti_keV, burn_plasma.volume_m3,
        burn_plasma.interval_s, burn_plasma.alpha_deposition_fraction,
        burn_plasma.auxiliary_power_density_W_m3,
        burn_plasma.declared_loss_power_density_W_m3)
    zero_fuel_result = thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(burn_spec, (plasma_input=zero_fuel,));
        source_mode=:composition_interval_average)
    @test zero_fuel_result.provider_result.final_nD_m3 == 0.0
    @test zero_fuel_result.provider_result.final_nT_m3 == zero_fuel.nT_m3.value
    @test zero_fuel_result.provider_result.reaction_extent_per_m3 == 0.0
    @test zero_fuel_result.provider_result.fusion_birth_energy_J == 0.0
    @test isapprox(zero_fuel_result.rhs_source_W_m3[1], 0.75 / geometry_volume;
        rtol=1e-12, atol=1e-12)
    @test isapprox(zero_fuel_result.thermal_result.integrated_source_W,
        zero_fuel_result.transferred_power_W; rtol=1e-10, atol=1e-12)

    invalid_T = rt.DTFusionReactivityInputV1(burn_plasma.nD_m3, burn_plasma.nT_m3,
        dq(100.0, :keV, energy), burn_plasma.volume_m3, burn_plasma.interval_s,
        burn_plasma.alpha_deposition_fraction, burn_plasma.auxiliary_power_density_W_m3,
        burn_plasma.declared_loss_power_density_W_m3)
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(burn_spec, (plasma_input=invalid_T,));
        source_mode=:composition_interval_average)
    for bad_interval in (0.0, -1.0)
        invalid_interval = rt.DTFusionReactivityInputV1(burn_plasma.nD_m3,
            burn_plasma.nT_m3, burn_plasma.Ti_keV, burn_plasma.volume_m3,
            dq(bad_interval, :s, seconds), burn_plasma.alpha_deposition_fraction,
            burn_plasma.auxiliary_power_density_W_m3,
            burn_plasma.declared_loss_power_density_W_m3)
        @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
            args..., merge(burn_spec, (plasma_input=invalid_interval,));
            source_mode=:composition_interval_average)
    end
    net_cooling = rt.DTFusionReactivityInputV1(burn_plasma.nD_m3,
        burn_plasma.nT_m3, burn_plasma.Ti_keV, burn_plasma.volume_m3,
        burn_plasma.interval_s, burn_plasma.alpha_deposition_fraction,
        burn_plasma.auxiliary_power_density_W_m3, dq(100.0, :W_m3, power_density))
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(burn_spec, (plasma_input=net_cooling,
            wall_transfer_fraction=dq(0.0, :one, one),));
        source_mode=:composition_interval_average)
    println("UP2_DT_HEAT_BURN_AVG_RESULT=", (candidate_ref=string(burn_result.candidate_ref),
        source_mode=burn_result.source_mode, ncell=length(burn_result.rhs_source_W_m3),
        nD_final_m3=burn_result.provider_result.final_nD_m3,
        nT_final_m3=burn_result.provider_result.final_nT_m3,
        q_avg_W_m3=q_avg_W_m3, Pwall_W=burn_result.transferred_power_W,
        Vwall_m3=burn_result.thermal_volume_m3,
        qwall_W_m3=first(burn_result.rhs_source_W_m3),
        fv_residual=burn_result.thermal_result.residual_norm,
        energy_balance_W=burn_result.energy_balance_residual_W,
        provider_result_hash=burn_result.provider_result_hash,
        thermal_result_hash=burn_result.thermal_result_hash,
        result_hash=burn_result.result_hash))
    println("UP2_DT_HEAT_UNIT_YZ_RESULT=", (candidate_ref=string(result.candidate_ref),
        ncell=length(result.thermal_result.volume_source_W_m3),
        qnet_W_m3=result.provider_result.net_thermal_source_W_m3,
        Pwall_W=result.transferred_power_W, Vwall_m3=result.thermal_volume_m3,
        qwall_W_m3=first(result.rhs_source_W_m3),
        fv_residual=result.thermal_result.residual_norm,
        energy_balance_W=result.energy_balance_residual_W,
        result_hash=result.result_hash))
end

@testset "UP2-05 D-T provider removal reports the required capability before thermal dispatch" begin
    case = _thermal_source_case()
    built = case.built
    rt = Main.FusionRuntimeV4
    thermal = Main.SteadyPlanarThermalDiffusionConsumerV1
    bundle, spatial = case.t0.transport, case.spatial
    input = _DCCE.dcce_input_v1(built.candidate_ref, built.g1.declaration,
        built.g2.declaration, built.g3.declaration, bundle, spatial)
    power_density = _DCCE.UnitSignature((-1, 1, -3, 0, 0, 0, 0))
    density = _DCCE.UnitSignature((-3, 0, 0, 0, 0, 0, 0))
    energy = _DCCE.UnitSignature((2, 1, -2, 0, 0, 0, 0))
    volume_unit = _DCCE.UnitSignature((3, 0, 0, 0, 0, 0, 0))
    seconds = _DCCE.UnitSignature((0, 0, 1, 0, 0, 0, 0))
    one = _DCCE.UnitSignature()
    dq(v, u, d) = rt.DTFusionQuantityV1(v, u, d)
    plasma = rt.DTFusionReactivityInputV1(
        dq(1.0e17, :m3_inverse, density), dq(1.0e17, :m3_inverse, density),
        dq(10.0, :keV, energy), dq(1.0, :m3, volume_unit),
        dq(0.01, :s, seconds), dq(0.5, :one, one),
        dq(1.0, :W_m3, power_density), dq(0.25, :W_m3, power_density))
    chart = built.g2.declaration.source.chart_map
    geometry_volume = abs(prod(Float64(chart.jacobian_rows[i][i]) *
        Float64(chart.domain_upper[i] - chart.domain_lower[i]) for i in 1:3))
    thermal_region = only(filter(f -> f.face === :x_min,
        built.g2.declaration.source.faces)).owner_region_id
    spec = (schema="candidate-dt-to-thermal-source-v1",
        candidate_ref=input.candidate_ref, plasma_region_id="synthetic-plasma",
        thermal_region_id=thermal_region, plasma_input=plasma,
        wall_transfer_fraction=dq(1.0, :one, one),
        wall_volume_m3=dq(geometry_volume, :m3, volume_unit),
        q_bounds_W_m3=(dq(1//100, :W_m3, power_density),
            dq(2//1, :W_m3, power_density)),
        parameter_id="candidate-dt-source-q")
    args = (built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, bundle, spatial, spec)
    provider = rt.dt_fusion_reactivity_manifest_v1()

    # This exercises the same provider match and downstream FV residual with
    # the source-owned manifest supplied by the consumer's caller.
    consumed = thermal.execute_steady_planar_dt_screen_thermal_v1(
        args...; providers=(provider,))
    @test consumed.status === :screen_only
    @test consumed.provider_result.provider_manifest_hash == provider.manifest_hash
    @test consumed.thermal_result.volume_source_W_m3 == consumed.rhs_source_W_m3
    @test consumed.thermal_result.residual_norm <= 1e-12
    @test isapprox(consumed.thermal_result.integrated_source_W,
        consumed.transferred_power_W; rtol=1e-10, atol=1e-10)
    @test abs(consumed.thermal_result.energy_balance_residual_W) <= 1e-10
    @test consumed.evidence_credit == 0
    @test consumed.candidate_bound === false
    @test consumed.physical_evidence === false

    required_capability = rt.dt_fusion_reactivity_capability_v1()
    expected_gap = "dt_thermal_required_provider_missing:no_match:" *
        string(required_capability.schema, "@", required_capability.revision, "/",
            required_capability.kind, "/", required_capability.operator, "/",
            _DCCE.canonical_hash(required_capability))
    missing_error = try
        thermal.execute_steady_planar_dt_screen_thermal_v1(
            args...; providers=())
        nothing
    catch error
        error
    end
    @test missing_error isa ArgumentError
    @test missing_error.msg == expected_gap
    # The exact no-match exception is raised before the downstream thermal
    # solve; a missing provider cannot yield a thermal receipt or dispatch.
end

@testset "D-T thermal source uses full non-unit Y/Z G2 physical volume" begin
    variant = _thermal_materialize_source_variant_v1(_DCCE_ROOT,
        _THERMAL_SLAB_CANDIDATE_DIR, :up2_02_nonunit_yz)
    case = _thermal_source_case(variant.candidate_directory;
        source_root=variant.source_root)
    built = case.built
    rt = Main.FusionRuntimeV4
    thermal = Main.SteadyPlanarThermalDiffusionConsumerV1
    bundle, spatial = case.t0.transport, case.spatial
    chart = built.g2.declaration.source.chart_map
    reference_volume = prod(Float64(chart.domain_upper[i] -
        chart.domain_lower[i]) for i in 1:3)
    physical_volume = abs(prod(Float64(chart.jacobian_rows[i][i]) *
        Float64(chart.domain_upper[i] - chart.domain_lower[i]) for i in 1:3))
    @test chart.jacobian_rows[2][2] == 1//2
    @test chart.jacobian_rows[3][3] == 1//4
    @test reference_volume == 1.0
    @test physical_volume == 0.25

    input = _DCCE.dcce_input_v1(built.candidate_ref, built.g1.declaration,
        built.g2.declaration, built.g3.declaration, bundle, spatial)
    thermal_region = only(filter(f -> f.face === :x_min,
        built.g2.declaration.source.faces)).owner_region_id
    dq(v, u, d) = rt.DTFusionQuantityV1(v, u, d)
    one = _DCCE.UnitSignature()
    density = _DCCE.UnitSignature((-3, 0, 0, 0, 0, 0, 0))
    energy = _DCCE.UnitSignature((2, 1, -2, 0, 0, 0, 0))
    seconds = _DCCE.UnitSignature((0, 0, 1, 0, 0, 0, 0))
    power_density = _DCCE.UnitSignature((-1, 1, -3, 0, 0, 0, 0))
    volume_unit = _DCCE.UnitSignature((3, 0, 0, 0, 0, 0, 0))
    plasma = rt.DTFusionReactivityInputV1(
        dq(1.0e17, :m3_inverse, density), dq(1.0e17, :m3_inverse, density),
        dq(10.0, :keV, energy), dq(1.0, :m3, volume_unit),
        dq(0.01, :s, seconds), dq(0.5, :one, one),
        dq(1.0, :W_m3, power_density), dq(0.25, :W_m3, power_density))
    yz_spec = (schema="candidate-dt-to-thermal-source-v1",
        candidate_ref=input.candidate_ref, plasma_region_id="synthetic-plasma",
        thermal_region_id=thermal_region, plasma_input=plasma,
        wall_transfer_fraction=dq(1.0, :one, one),
        wall_volume_m3=dq(physical_volume, :m3, volume_unit),
        q_bounds_W_m3=(dq(1//100, :W_m3, power_density),
            dq(10//1, :W_m3, power_density)),
        parameter_id="candidate-dt-source-nonunit-yz-q")
    baseline = thermal.execute_steady_planar_thermal_diffusion_v1(
        built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, bundle, spatial)
    @test baseline.volume_source_W_m3 == Tuple(spatial.field.source)
    @test isapprox(baseline.integrated_source_W, physical_volume;
        rtol=0.0, atol=1e-12)

    args = (built.candidate_ref, built.g1.declaration, built.g2.declaration,
        built.g3.declaration, bundle, spatial)
    result = thermal.execute_steady_planar_dt_screen_thermal_v1(args..., yz_spec)
    @test result.status === :screen_only
    @test result.thermal_volume_m3 == physical_volume
    @test result.thermal_result.volume_source_W_m3 == result.rhs_source_W_m3
    @test all(==(result.rhs_source_W_m3[1]), result.rhs_source_W_m3)
    @test isapprox(result.thermal_result.integrated_source_W,
        result.transferred_power_W; rtol=1e-10, atol=1e-12)
    @test abs(result.energy_balance_residual_W) <= 1e-10
    @test_throws ArgumentError thermal.execute_steady_planar_dt_screen_thermal_v1(
        args..., merge(yz_spec, (wall_volume_m3=
            dq(reference_volume, :m3, volume_unit),)))
    println("UP2_DT_HEAT_NONUNIT_YZ_RESULT=", (candidate_ref=string(result.candidate_ref),
        ncell=length(result.thermal_result.volume_source_W_m3),
        qnet_W_m3=result.provider_result.net_thermal_source_W_m3,
        Pwall_W=result.transferred_power_W, Vwall_m3=result.thermal_volume_m3,
        qwall_W_m3=first(result.rhs_source_W_m3),
        fv_residual=result.thermal_result.residual_norm,
        energy_balance_W=result.energy_balance_residual_W,
        result_hash=result.result_hash))
end

@testset "UP2-02 authored G2 refinement reaches the source-bound FV consumer" begin
    base = _thermal_source_case()
    variant = _thermal_materialize_source_variant_v1(_DCCE_ROOT,
        _THERMAL_SLAB_CANDIDATE_DIR, :up2_02_refinement)
    refined = _thermal_source_case(variant.candidate_directory;
        source_root=variant.source_root)

    @test base.t0.status === refined.t0.status === :valid
    @test base.built.g2.declaration.source.mesh.cells == (4, 1, 1)
    @test refined.built.g2.declaration.source.mesh.cells == (8, 1, 1)
    @test base.built.candidate_ref != refined.built.candidate_ref
    @test length(refined.spatial.new_geometry.edges) - 1 == 8

    transfer = _DCCE.measure_overlap_transfer(refined.spatial.old_geometry,
        refined.spatial.new_geometry, refined.spatial.old_state)
    @test transfer.status === :ready && transfer.valid
    @test length(transfer.transfer.new_state) == 8
    @test transfer.transfer.new_state == ntuple(_ ->
        Float64(refined.spatial.old_state[1]), 8)
    @test all(isfinite, transfer.transfer.new_state)
    @test all(>(0.0), transfer.transfer.new_state)
    @test isapprox(transfer.transfer.new_total, transfer.transfer.old_total;
        rtol=0.0, atol=1e-12)
    @test transfer.transfer.conservation_residual <= 1e-12

    thermal = Main.SteadyPlanarThermalDiffusionConsumerV1
    result = thermal.execute_steady_planar_thermal_diffusion_v1(
        refined.built.candidate_ref, refined.built.g1.declaration,
        refined.built.g2.declaration, refined.built.g3.declaration,
        refined.t0.transport, refined.spatial)
    println("UP2_02_FV_TRANSFER_RESULT_CAPTURE=", repr((
        transfer=(status=transfer.status, valid=transfer.valid,
            old_total=transfer.transfer.old_total,
            new_total=transfer.transfer.new_total,
            new_state=transfer.transfer.new_state,
            conservation_residual=transfer.transfer.conservation_residual,
            transfer_hash=string(transfer.transfer.transfer_hash)),
        result=(status=result.status, accepted=result.accepted,
            candidate_ref=string(result.candidate_ref),
            temperature_K=result.temperature_K,
            volume_source_W_m3=result.volume_source_W_m3,
            energy_balance_residual_W=result.energy_balance_residual_W,
            integrated_source_W=result.integrated_source_W,
            residual_norm=result.residual_norm,
            state_transfer_hash=result.state_transfer_hash,
            result_hash=string(result.result_hash)))))
    flush(stdout)
    @test (result.status, result.accepted, result.physical_validation,
        result.engineering_validation, result.claim_ceiling) ==
        (:screen_only, false, false, false, :screen_only)
    @test result.candidate_ref == refined.built.candidate_ref
    @test result.state_transfer_hash == transfer.transfer.transfer_hash
    @test length(result.temperature_K) == 8
    @test all(isfinite, result.temperature_K)
    @test all(>(0.0), result.temperature_K)
    @test result.residual_norm <= 1e-12
    @test abs(result.energy_balance_residual_W) <= 1e-10
end

if !_THERMAL_Q1_DIAGNOSTIC_ONLY

@testset "native V5 queue evaluates a non-equivalent G2 metric geometry edit" begin
    base = _thermal_source_case()
    variant = _thermal_materialize_source_variant_v1(_DCCE_ROOT,
        _THERMAL_SLAB_CANDIDATE_DIR, :up2_02_nonunit_yz)
    edited = _thermal_source_case(variant.candidate_directory;
        source_root=variant.source_root)
    base_chart = base.built.g2.declaration.source.chart_map
    edited_chart = edited.built.g2.declaration.source.chart_map

    @test base.t0.status === edited.t0.status === :valid
    @test base.built.identity.scenario_ref == edited.built.identity.scenario_ref
    @test base.built.candidate_ref != edited.built.candidate_ref
    base_k = base.built.g1.declaration.K.expression
    edited_k = edited.built.g1.declaration.K.expression
    @test typeof(base_k) === typeof(edited_k)
    @test base_k.expression_id == edited_k.expression_id
    @test base_k.base_diag == edited_k.base_diag
    @test base_k.slope_diag == edited_k.slope_diag
    chart_physical_bounds = chart -> (
        ntuple(i -> chart.offset[i] + chart.jacobian_rows[i][i] *
            chart.domain_lower[i], 3),
        ntuple(i -> chart.offset[i] + chart.jacobian_rows[i][i] *
            chart.domain_upper[i], 3))
    @test (base_k.domain_min, base_k.domain_max) == chart_physical_bounds(base_chart)
    @test (edited_k.domain_min, edited_k.domain_max) == chart_physical_bounds(edited_chart)
    common_physical_point = (1.0, 0.25, 0.125)
    @test _DCCE.g1_diffusion_k_eval(base_k, common_physical_point) ==
        _DCCE.g1_diffusion_k_eval(edited_k, common_physical_point)
    @test base_chart.domain_lower == edited_chart.domain_lower
    @test base_chart.domain_upper == edited_chart.domain_upper
    @test base_chart.jacobian_rows[1] == edited_chart.jacobian_rows[1]
    @test base_chart.jacobian_rows[2][2] == 1//1
    @test base_chart.jacobian_rows[3][3] == 1//1
    @test edited_chart.jacobian_rows[2][2] == 1//2
    @test edited_chart.jacobian_rows[3][3] == 1//4

    physical_volume(chart) = abs(prod(Float64(chart.jacobian_rows[i][i]) *
        Float64(chart.domain_upper[i] - chart.domain_lower[i]) for i in 1:3))
    @test physical_volume(base_chart) == 2.0
    @test physical_volume(edited_chart) == 0.25

    child_a = _thermal_v5_queue_child(base; max_iterations=24)
    child_b = _thermal_v5_queue_child(edited; max_iterations=24)
    @test child_a.input.package.candidate_ref == child_a.input.witness.candidate_ref
    @test child_b.input.package.candidate_ref == child_b.input.witness.candidate_ref
    @test child_a.scenario_ref == child_b.scenario_ref

    queue = _DCCE.VNextUP3ThermalQueueV1()
    _DCCE.vnext_up3_thermal_enqueue!(queue, child_a)
    _DCCE.vnext_up3_thermal_enqueue!(queue, child_b)
    result_a = _DCCE.vnext_up3_thermal_dispatch_selected!(queue,
        _DCCE.vnext_up3_thermal_next!(queue))
    result_b = _DCCE.vnext_up3_thermal_dispatch_selected!(queue,
        _DCCE.vnext_up3_thermal_next!(queue))

    @test result_a.status === result_b.status === :screen_only
    @test result_a.result.candidate_ref == base.built.candidate_ref
    @test result_b.result.candidate_ref == edited.built.candidate_ref
    @test result_a.result.temperature_source_fixed_point.fixed_point_converged
    @test result_b.result.temperature_source_fixed_point.fixed_point_converged
    @test result_a.result.temperature_source_fixed_point.applied_q_W_m3 ≈ 1.6 atol=1e-12 rtol=0
    @test result_b.result.temperature_source_fixed_point.applied_q_W_m3 ≈ 1.6 atol=1e-12 rtol=0
    @test result_a.result.integrated_source_W ≈ 3.2 atol=1e-10 rtol=0
    @test result_b.result.integrated_source_W ≈ 0.4 atol=1e-10 rtol=0
    @test result_a.result.integrated_source_W != result_b.result.integrated_source_W
    @test abs(result_a.result.energy_balance_residual_W) <= 1e-10
    @test abs(result_b.result.energy_balance_residual_W) <= 1e-10
    @test result_a.result.physical_validation === result_b.result.physical_validation === false
    @test result_a.result.evidence_credit == result_b.result.evidence_credit == 0
    println("UP5_G2_METRIC_QUEUE_RESULT=", (
        candidate=(baseline=(id=result_a.result.candidate_ref.id,
                version=result_a.result.candidate_ref.version),
            edited=(id=result_b.result.candidate_ref.id,
                version=result_b.result.candidate_ref.version)),
        scenario_ref=(baseline=child_a.scenario_ref.value,
            edited=child_b.scenario_ref.value),
        g2_source_identity_hash=(baseline=result_a.result.source_program_audit.g2_source_identity_hash.value,
            edited=result_b.result.source_program_audit.g2_source_identity_hash.value),
        chart_jacobian_yz=(baseline=(base_chart.jacobian_rows[2][2],
                base_chart.jacobian_rows[3][3]),
            edited=(edited_chart.jacobian_rows[2][2],
                edited_chart.jacobian_rows[3][3])),
        physical_volume_m3=(baseline=physical_volume(base_chart),
            edited=physical_volume(edited_chart)),
        q_source_W_m3=(baseline=result_a.result.temperature_source_fixed_point.applied_q_W_m3,
            edited=result_b.result.temperature_source_fixed_point.applied_q_W_m3),
        result_hash=(baseline=result_a.result.result_hash.value,
            edited=result_b.result.result_hash.value),
        integrated_source_W=(baseline=result_a.result.integrated_source_W,
            edited=result_b.result.integrated_source_W),
        energy_balance_residual_W=(baseline=result_a.result.energy_balance_residual_W,
            edited=result_b.result.energy_balance_residual_W),
        queue_status=(baseline=result_a.status, edited=result_b.status),
        claim_ceiling=(baseline=result_a.result.claim_ceiling,
            edited=result_b.result.claim_ceiling),
        physical_validation=(baseline=result_a.result.physical_validation,
            edited=result_b.result.physical_validation),
        evidence_credit=(baseline=result_a.result.evidence_credit,
            edited=result_b.result.evidence_credit)))
end

@testset "native V5 queue evaluates a G3 feedback-capability removal" begin
    with_feedback = _thermal_source_case()
    no_feedback_variant = _thermal_materialize_source_variant_v1(_DCCE_ROOT,
        _THERMAL_SLAB_CANDIDATE_DIR, :base_no_law)
    without_feedback = _thermal_source_case(no_feedback_variant.candidate_directory;
        source_root=no_feedback_variant.source_root)
    with_g3 = only(filter(r -> r.layer === :G3,
        with_feedback.records.declarations)).semantic_body.body.authored_child_design
    without_g3 = only(filter(r -> r.layer === :G3,
        without_feedback.records.declarations)).semantic_body.body.authored_child_design

    @test with_feedback.t0.status === without_feedback.t0.status === :valid
    @test with_feedback.built.identity.scenario_ref ==
        without_feedback.built.identity.scenario_ref
    @test with_feedback.built.candidate_ref != without_feedback.built.candidate_ref
    @test with_feedback.built.g1.declaration.K.expression ==
        without_feedback.built.g1.declaration.K.expression
    with_g1_record = only(filter(r -> r.layer === :G1,
        with_feedback.records.declarations))
    without_g1_record = only(filter(r -> r.layer === :G1,
        without_feedback.records.declarations))
    with_g1_program = with_g1_record.semantic_body.body.value.g1_typed_source_field_program
    without_g1_program = without_g1_record.semantic_body.body.value.g1_typed_source_field_program
    with_feedback_law = with_g3.control_design.temperature_source_feedback
    @test with_g1_program.source_law.T0_K == without_g1_program.source_law.T0_K
    @test with_g1_program.source_law.q_W_m3 == without_g1_program.source_law.q_W_m3
    @test with_feedback_law.q0_w_m3 == with_g1_program.source_law.q_W_m3
    @test with_g1_program.source_law.L_m == without_g1_program.source_law.L_m
    @test with_feedback.built.g2.declaration.source.faces ==
        without_feedback.built.g2.declaration.source.faces
    @test with_feedback.built.g2.declaration.source.mesh.cells ==
        without_feedback.built.g2.declaration.source.mesh.cells
    with_chart = with_feedback.built.g2.declaration.source.chart_map
    without_chart = without_feedback.built.g2.declaration.source.chart_map
    chart_ref_id_for_candidate = candidate_ref -> replace(candidate_ref.id,
        "fusionconceptai://candidate-design/" =>
            "fusionconceptai://GenomeV5/G2/chart/")
    @test with_chart.chart_ref != without_chart.chart_ref
    @test with_chart.chart_ref.id ==
        chart_ref_id_for_candidate(with_feedback.built.candidate_ref)
    @test without_chart.chart_ref.id ==
        chart_ref_id_for_candidate(without_feedback.built.candidate_ref)
    @test with_chart.chart_ref.version == without_chart.chart_ref.version == "v1"
    @test with_chart.domain_lower == without_chart.domain_lower
    @test with_chart.domain_upper == without_chart.domain_upper
    @test with_chart.jacobian_rows == without_chart.jacobian_rows
    @test with_chart.offset == without_chart.offset
    @test with_chart.map_kind == without_chart.map_kind
    @test with_chart.axes == without_chart.axes
    @test hasproperty(with_g3.control_design, :temperature_source_feedback)
    @test !hasproperty(without_g3.control_design, :temperature_source_feedback)

    child_a = _thermal_v5_queue_child(with_feedback; max_iterations=24)
    child_b = _thermal_v5_queue_child(without_feedback; max_iterations=24)
    queue = _DCCE.VNextUP3ThermalQueueV1()
    _DCCE.vnext_up3_thermal_enqueue!(queue, child_a)
    _DCCE.vnext_up3_thermal_enqueue!(queue, child_b)
    result_a = _DCCE.vnext_up3_thermal_dispatch_selected!(queue,
        _DCCE.vnext_up3_thermal_next!(queue))
    result_b = _DCCE.vnext_up3_thermal_dispatch_selected!(queue,
        _DCCE.vnext_up3_thermal_next!(queue))

    @test result_a.status === result_b.status === :screen_only
    @test result_a.result.candidate_ref == with_feedback.built.candidate_ref
    @test result_b.result.candidate_ref == without_feedback.built.candidate_ref
    @test result_a.result.feedback_status === :screen_only
    @test result_a.result.temperature_source_fixed_point.fixed_point_converged
    @test result_a.result.temperature_source_fixed_point.applied_q_W_m3 ≈ 1.6 atol=1e-12 rtol=0
    @test result_b.result.feedback_status === :typed_absent
    @test !hasproperty(result_b.result, :temperature_source_fixed_point)
    @test all(==(1.0), result_b.result.volume_source_W_m3)
    @test result_a.result.integrated_source_W ≈ 3.2 atol=1e-10 rtol=0
    @test result_b.result.integrated_source_W ≈ 2.0 atol=1e-10 rtol=0
    @test result_a.result.integrated_source_W != result_b.result.integrated_source_W
    @test result_a.result.temperature_K != result_b.result.temperature_K
    @test result_a.result.physical_validation === result_b.result.physical_validation === false
    @test result_a.result.evidence_credit == result_b.result.evidence_credit == 0
    println("UP5_G3_FEEDBACK_REMOVAL_QUEUE_RESULT=", (
        candidate=(with_feedback=(id=result_a.result.candidate_ref.id,
                version=result_a.result.candidate_ref.version),
            without_feedback=(id=result_b.result.candidate_ref.id,
                version=result_b.result.candidate_ref.version)),
        scenario_ref=(with_feedback=child_a.scenario_ref.value,
            without_feedback=child_b.scenario_ref.value),
        g3_source_identity_hash=(with_feedback=only(filter(r -> r.layer === :G3,
                with_feedback.records.declarations)).source_identity_hash.value,
            without_feedback=only(filter(r -> r.layer === :G3,
                without_feedback.records.declarations)).source_identity_hash.value),
        feedback_capability=(with_feedback=hasproperty(with_g3.control_design, :temperature_source_feedback), without_feedback=hasproperty(without_g3.control_design, :temperature_source_feedback)),
        feedback_status=(with_feedback=result_a.result.feedback_status,
            without_feedback=result_b.result.feedback_status),
        source_density_W_m3=(with_feedback=first(result_a.result.volume_source_W_m3),
            without_feedback=first(result_b.result.volume_source_W_m3)),
        result_hash=(with_feedback=result_a.result.result_hash.value,
            without_feedback=result_b.result.result_hash.value),
        temperature_K=(with_feedback=result_a.result.temperature_K,
            without_feedback=result_b.result.temperature_K),
        integrated_source_W=(with_feedback=result_a.result.integrated_source_W,
            without_feedback=result_b.result.integrated_source_W),
        energy_balance_residual_W=(with_feedback=result_a.result.energy_balance_residual_W,
            without_feedback=result_b.result.energy_balance_residual_W),
        queue_status=(with_feedback=result_a.status, without_feedback=result_b.status),
        claim_ceiling=(with_feedback=result_a.result.claim_ceiling,
            without_feedback=result_b.result.claim_ceiling),
        physical_validation=(with_feedback=result_a.result.physical_validation,
            without_feedback=result_b.result.physical_validation),
        evidence_credit=(with_feedback=result_a.result.evidence_credit,
            without_feedback=result_b.result.evidence_credit)))
end
end


@testset "UP2-01 D-T screen drives candidate-bound spatial FV deposition" begin
    actual=_thermal_source_case()
    rt=Main.FusionRuntimeV4; consumer=_THERMAL_SLAB_CONSUMER
    unit_density=UnitSignature((-3,0,0,0,0,0,0))
    unit_energy=UnitSignature((2,1,-2,0,0,0,0))
    unit_volume=UnitSignature((3,0,0,0,0,0,0))
    unit_time=UnitSignature((0,0,1,0,0,0,0))
    unit_one=UnitSignature()
    unit_power_density=UnitSignature((-1,1,-3,0,0,0,0))
    dq(value,unit,dimension)=rt.DTFusionQuantityV1(Float64(value),unit,dimension)
    plasma_volume=1.0
    plasma_input=rt.DTFusionReactivityInputV1(
        dq(2.0e19,:m3_inverse,unit_density),dq(1.6e19,:m3_inverse,unit_density),
        dq(10.0,:keV,unit_energy),dq(plasma_volume,:m3,unit_volume),
        dq(0.25,:s,unit_time),dq(0.35,:one,unit_one),
        dq(25.0,:W_m3,unit_power_density),dq(50.0,:W_m3,unit_power_density))
    provider=rt.dt_fusion_reactivity_manifest_v1()
    dt_source=rt.evaluate_dt_fusion_reactivity_v1(plasma_input;providers=(provider,))
    @test dt_source.status===:screen_only
    @test dt_source.candidate_bound===false && dt_source.physical_evidence===false
    @test dt_source.net_thermal_source_W_m3>0.0
    @test dt_source.auxiliary_power_density_W_m3==25.0
    @test dt_source.declared_loss_power_density_W_m3==50.0
    @test dt_source.net_thermal_source_W_m3≈
        dt_source.deposited_alpha_power_density_W_m3+25.0-50.0 rtol=1e-12
    @test abs(dt_source.thermal_account_residual_J)<=1e-10*
        max(abs(dt_source.net_thermal_source_energy_J),1.0)

    built=actual.built; spatial=actual.spatial; chart=built.g2.declaration.source.chart_map
    J=chart.jacobian_rows
    physical_spans=ntuple(i->Float64(J[i][i])*(Float64(chart.domain_upper[i])-Float64(chart.domain_lower[i])),3)
    wall_volume=prod(physical_spans)
    target_reference_q=1.25
    transfer_fraction=target_reference_q*wall_volume/
        (dt_source.net_thermal_source_W_m3*plasma_volume)
    @test 0.0<transfer_fraction<1.0
    thermal_region = only(filter(f -> f.face === :x_min,
        built.g2.declaration.source.faces)).owner_region_id
    spec=(schema="candidate-dt-to-thermal-source-v1",
        candidate_ref=built.candidate_ref,plasma_region_id="explicit-dt-screen-plasma",
        thermal_region_id=thermal_region,plasma_input=plasma_input,
        wall_transfer_fraction=dq(transfer_fraction,:one,unit_one),
        wall_volume_m3=dq(wall_volume,:m3,unit_volume),
        q_bounds_W_m3=(dq(0.5,:W_m3,unit_power_density),dq(2.0,:W_m3,unit_power_density)),
        parameter_id="q_dt_wall_reference")
    edges=Tuple(Float64.(spatial.new_geometry.edges)); n=length(edges)-1
    @test n==4
    weights=(0.15,0.20,0.30,0.35)
    transferred=dt_source.net_thermal_source_W_m3*plasma_volume*transfer_fraction
    # This is a synthetic caller-declared distribution whose 0D integral is
    # bound to the provider power. It is not measured deposition evidence.
    deposited_power=(schema="caller-declared-cell-power-distribution-0d-integral-v1",
        candidate_ref=built.candidate_ref,g2_chart_hash=canonical_hash(chart),
        cell_edges_m=edges,deposited_power_W=Tuple(transferred*w for w in weights),unit=:W)
    @test isapprox(sum(deposited_power.deposited_power_W),transferred;rtol=1e-14,atol=0.0)

    args=(built.candidate_ref,built.g1.declaration,built.g2.declaration,
        built.g3.declaration,actual.t0.transport,spatial,spec)
    outcome=consumer.execute_steady_planar_dt_screen_thermal_v1(args...;
        source_mode=:instantaneous,deposited_power=deposited_power)
    @test outcome.status===:screen_only && outcome.candidate_ref==built.candidate_ref
    @test outcome.candidate_bound===false && outcome.physical_evidence===false
    @test outcome.engineering_evidence===false && outcome.evidence_credit==0
    @test outcome.claim_ceiling===:screen_only
    @test outcome.provider_result_hash==canonical_hash(outcome.provider_result)
    @test outcome.provider_result.net_thermal_source_W_m3==dt_source.net_thermal_source_W_m3
    @test isapprox(outcome.transferred_power_W,transferred;rtol=1e-12,atol=1e-12)

    contract=outcome.spatial_source_contract
    @test contract.schema==deposited_power.schema
    @test contract.scope===:caller_declared_cell_power_distribution_with_0D_integral_binding
    @test contract.physical_deposition_evidence===false
    @test contract.input_hash==canonical_hash(deposited_power)
    @test contract.candidate_ref==built.candidate_ref
    @test contract.g2_chart_hash==canonical_hash(chart)
    @test contract.cell_edges_m==edges
    @test contract.deposited_power_W==deposited_power.deposited_power_W
    @test contract.total_deposited_power_W≈outcome.transferred_power_W rtol=1e-12
    @test isapprox(sum(contract.cell_volumes_m3),wall_volume;rtol=1e-12,atol=1e-12)
    widths=diff(collect(edges))
    @test all(isapprox(contract.cell_volumes_m3[i],widths[i]*wall_volume/(last(edges)-first(edges));
        rtol=1e-12,atol=1e-12) for i in 1:n)
    independently_derived_q=Tuple(contract.deposited_power_W[i]/contract.cell_volumes_m3[i] for i in 1:n)
    @test isapprox(collect(contract.cell_source_W_m3),collect(independently_derived_q);rtol=1e-12,atol=1e-12)
    @test outcome.rhs_source_W_m3==contract.cell_source_W_m3
    thermal=outcome.thermal_result
    @test thermal.volume_source_W_m3==contract.cell_source_W_m3
    @test contract.uniform_G1_reference_q_W_m3≈outcome.transferred_power_W/wall_volume rtol=1e-12
    @test maximum(contract.cell_source_W_m3)-minimum(contract.cell_source_W_m3)>0.0
    @test !all(==(contract.uniform_G1_reference_q_W_m3),contract.cell_source_W_m3)

    # Independent conservation recurrence: source-per-area increments the
    # rightward face flux; endpoint signed fluxes close the integrated power.
    program_audit=thermal.source_program_audit
    @test program_audit.spatial_source_model===:caller_declared_cell_power_distribution_with_0D_integral_binding
    @test program_audit.physical_deposition_evidence===false
    audit=program_audit.spatial_fv_oracle
    @test audit.model===:conservative_face_flux_recurrence
    @test audit.cell_width_m≈widths[1] rtol=0 atol=1e-12
    increments=collect(contract.cell_source_W_m3).*widths
    face_flux=collect(audit.face_flux_W_m2)
    @test length(face_flux)==n+1
    @test isapprox(collect(audit.cell_source_per_area_W_m2),increments;rtol=1e-12,atol=1e-12)
    @test all(isapprox(face_flux[i+1]-face_flux[i],increments[i];rtol=1e-12,atol=1e-12) for i in 1:n)
    area=wall_volume/(last(edges)-first(edges))
    @test isapprox(thermal.outward_fourier_flux_left_W_m2,-face_flux[1];rtol=1e-12,atol=1e-10)
    @test isapprox(thermal.outward_fourier_flux_right_W_m2,face_flux[end];rtol=1e-12,atol=1e-10)
    @test isapprox(thermal.integrated_source_W,area*sum(increments);rtol=1e-12,atol=1e-10)
    @test isapprox(thermal.integrated_source_W,outcome.transferred_power_W;rtol=1e-10,atol=1e-10)
    @test isapprox(area*(-face_flux[1]+face_flux[end]),outcome.transferred_power_W;rtol=1e-10,atol=1e-10)
    @test abs(thermal.energy_balance_residual_W)<=1e-10
    @test isapprox(thermal.outward_heat_power_left_W+thermal.outward_heat_power_right_W,
        outcome.transferred_power_W;rtol=1e-10,atol=1e-10)
    @test all(isapprox(thermal.temperature_K[i],audit.temperature_K[i];atol=1e-10,rtol=0.0) for i in 1:n)


    # Same D-T power with uniform deposition is a control; the nonuniform
    # spatial deposition must change the actual FV field, not just metadata.
    uniform=consumer.execute_steady_planar_dt_screen_thermal_v1(args...;
        source_mode=:instantaneous)
    @test uniform.transferred_power_W≈outcome.transferred_power_W rtol=1e-12
    @test all(==(contract.uniform_G1_reference_q_W_m3),uniform.rhs_source_W_m3)
    @test uniform.thermal_result.temperature_K!=thermal.temperature_K
    @test uniform.thermal_result.integrated_source_W≈thermal.integrated_source_W rtol=1e-12

    foreign=merge(deposited_power,(candidate_ref=QualifiedRefV1(
        "fusionconceptai://candidate/foreign-dt-spatial","v1"),))
    @test_throws ArgumentError consumer.execute_steady_planar_dt_screen_thermal_v1(args...;
        source_mode=:instantaneous,deposited_power=foreign)
    wrong_edges=merge(deposited_power,(cell_edges_m=Tuple(edges[1:end-1]),))
    @test_throws ArgumentError consumer.execute_steady_planar_dt_screen_thermal_v1(args...;
        source_mode=:instantaneous,deposited_power=wrong_edges)
    wrong_total=merge(deposited_power,(deposited_power_W=Tuple(2p for p in deposited_power.deposited_power_W),))
    @test_throws ArgumentError consumer.execute_steady_planar_dt_screen_thermal_v1(args...;
        source_mode=:instantaneous,deposited_power=wrong_total)

    # Stable machine-readable output for same-postimage bounded A/B comparison.
    println("UP2_DT_NONUNIFORM_FV_RESULT=", JSON3.write((
        candidate_ref=string(outcome.candidate_ref),
        provider_result_hash=string(outcome.provider_result_hash),
        g2_chart_hash=string(contract.g2_chart_hash),
        deposited_power_W=contract.deposited_power_W,
        cell_edges_m=contract.cell_edges_m,
        cell_volumes_m3=contract.cell_volumes_m3,
        cell_source_W_m3=contract.cell_source_W_m3,
        temperature_K=thermal.temperature_K,
        face_flux_W_m2=Tuple(audit.face_flux_W_m2),
        integrated_source_W=thermal.integrated_source_W,
        residual_norm=thermal.residual_norm,
        energy_balance_residual_W=thermal.energy_balance_residual_W,
        local_fv_curvature_offset_K=thermal.fv_discretization_correction_K,
        thermal_result_hash=string(thermal.result_hash),
        result_hash=string(outcome.result_hash),
        scope=string(contract.scope),
        physical_deposition_evidence=contract.physical_deposition_evidence,
        candidate_bound=outcome.candidate_bound,
        physical_evidence=outcome.physical_evidence)))
    flush(stdout)
end
