using Test
using FusionConceptAI
using LinearAlgebra

module FieldResidualNumericsTestModule
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FieldProgramEvaluation.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FieldResidualNumerics.jl"))
end

const F = FieldResidualNumericsTestModule

const U0 = UnitSignature()
const LEN = UnitSignature((0, 1, 0, 0, 0, 0, 0))
const U_LAPLACE = UnitSignature((0, -2, 0, 0, 0, 0, 0))
const SCALAR = PhysicalType(:scalar_field, 0, 3, :static, U0)
const SOURCE_SCALAR = PhysicalType(:scalar_field, 0, 3, :static, U_LAPLACE)

function test_grid(n=5)
    a = ntuple(i -> -1.0 + 2.0 * (i - 1) / (n - 1), n)
    F.FieldGridSpecV4((a, a, a))
end

function test_geometry(grid)
    interval = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), U0)
    ct = chart_coordinate_type_v1(); at = normalized_ambient_coordinate_type_v1(); mt = normalized_covariant_metric_type_v1()
    frame = CoordinateFrameRefV1("frame")
    chart = CoordinateChartGeneV1(ChartRefV1("chart"), frame, (interval, interval, interval), (),
        SpatialProgramRootRefV1(FieldOperatorSiteRefV1("coordinate"), 1, ct, at),
        SpatialProgramRootRefV1(FieldOperatorSiteRefV1("metric"), 1, ct, mt))
    support = SpatialSupportGeneV1(SpatialSupportRefV1("support"), 3, (frame,), (chart,), (),
        NonnegativeQuantityV1(1, LEN))
    F.compile_diagonal_affine_geometry(support, ChartRefV1("chart"), (1,1,1), (0,0,0), grid)
end

function test_constraint(; parameter=false, zero_coefficient=false, two_sources=false)
    reg = default_operator_registry()
    in_u = ASTInputV1(7, SCALAR)
    in_f = ASTInputV1(11, SOURCE_SCALAR)
    in_g = ASTInputV1(13, SOURCE_SCALAR)
    nodes = if parameter
        p = ASTParameterV1(:p, SCALAR)
        add_p = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1,2), (;); registry=reg,
            input_types=(SCALAR,SCALAR))
        (in_u, p, add_p)
    elseif two_sources
        l = ASTApplyV1(OperatorRefV1("LAPLACE", "v1"), (1,), (;); registry=reg, input_types=(SCALAR,))
        add_sources = ASTApplyV1(OperatorRefV1("ADD", "v1"), (2,3), (;); registry=reg,
            input_types=(SOURCE_SCALAR,SOURCE_SCALAR))
        sub = ASTApplyV1(OperatorRefV1("SUB", "v1"), (4,5), (;); registry=reg,
            input_types=(SOURCE_SCALAR,SOURCE_SCALAR))
        (in_u, in_f, in_g, l, add_sources, sub)
    elseif zero_coefficient
        z1 = ASTConstantV1(:zero_u, 0.0, SOURCE_SCALAR)
        z2 = ASTConstantV1(:zero_f, 0.0, SCALAR)
        mul_u = ASTApplyV1(OperatorRefV1("SCALAR_MUL", "v1"), (3,1), (;); registry=reg, input_types=(SOURCE_SCALAR,SCALAR))
        mul_f = ASTApplyV1(OperatorRefV1("SCALAR_MUL", "v1"), (5,2), (;); registry=reg, input_types=(SCALAR,SOURCE_SCALAR))
        add = ASTApplyV1(OperatorRefV1("ADD", "v1"), (4,6), (;); registry=reg, input_types=(SOURCE_SCALAR,SOURCE_SCALAR))
        (in_u, in_f, z1, mul_u, z2, mul_f, add)
    else
        l = ASTApplyV1(OperatorRefV1("LAPLACE", "v1"), (1,), (;); registry=reg, input_types=(SCALAR,))
        sub = ASTApplyV1(OperatorRefV1("SUB", "v1"), (3,2), (;); registry=reg, input_types=(SOURCE_SCALAR,SOURCE_SCALAR))
        (in_u, in_f, l, sub)
    end
    roots = parameter ? (3,) : (two_sources ? (6,) : (zero_coefficient ? (7,) : (4,)))
    ports = parameter ? (1,) : (two_sources ? (1,2,3) : (1,2))
    program = TypedASTProgramV1(nodes, roots, ports; registry=reg)
    input_bindings = parameter ? (MIMOInputBindingV1(1,1),) : two_sources ?
        (MIMOInputBindingV1(1,1), MIMOInputBindingV1(2,2), MIMOInputBindingV1(3,3)) :
        (MIMOInputBindingV1(1,1), MIMOInputBindingV1(2,2))
    edge = AtomicMIMOHyperedgeV1("constraint-edge", input_bindings,
        (MIMOOutputBindingV1(1, parameter ? 2 : (two_sources ? 4 : 3)),), program, constraint; registry=reg)
    graph_nodes = parameter ? (node(:state, SCALAR; id="u"), node(:state, SCALAR; id="r")) : two_sources ?
        (node(:state, SCALAR; id="u"), node(:state, SOURCE_SCALAR; id="f"), node(:state, SOURCE_SCALAR; id="g"),
            node(:state, SOURCE_SCALAR; id="r")) :
        (node(:state, SCALAR; id="u"), node(:state, SOURCE_SCALAR; id="f"),
            node(:state, SOURCE_SCALAR; id="r"))
    graph = TypedOperatorHypergraphV1(graph_nodes, (edge,); registry=reg)
    edge, graph, reg
end

@testset "field residual typed geometry and linear AST" begin
    grid = test_grid()
    geometry = test_geometry(grid)
    @test geometry.jhat == (1.0, 1.0, 1.0)
    @test geometry.ghat == (1.0, 1.0, 1.0)
    @test_throws ArgumentError F.StructuredGridProtocolV4(max_iterations=2)
    doubled = begin
        s = geometry.support
        scale2 = SpatialSupportGeneV1(s.support_ref, 3, s.coordinate_frame_refs, s.charts, s.chart_transition_maps,
            NonnegativeQuantityV1(2, LEN))
        F.compile_diagonal_affine_geometry(scale2, geometry.chart_ref, geometry.factors, geometry.offsets, grid)
    end
    @test doubled.laplace_weights == ntuple(x -> geometry.laplace_weights[x] / 4, 3)
    @test_throws ArgumentError F.compile_diagonal_affine_geometry(test_geometry(grid).support,
        ChartRefV1("chart"), (1,1,1), (0,0,0), F.FieldGridSpecV4(((-1.0,-0.4,0.4,1.0,1.5), grid.axes[2], grid.axes[3])))
    edge, graph, reg = test_constraint()
    form = F.compile_linear_field_residual_form(edge, graph, reg;
        constraint_edge_hash=canonical_hash(edge), unknown_state_ref=StateGeneRefV1("u"),
        source_state_refs=(StateGeneRefV1("f"),), residual_state_ref=StateGeneRefV1("r"))
    @test form.alpha == 1.0 && form.beta == 0.0 && form.source_coefficients == (-1.0,)
    @test_throws ArgumentError F.compile_linear_field_residual_form(edge, graph, OperatorRegistryV1(());
        constraint_edge_hash=canonical_hash(edge), unknown_state_ref=StateGeneRefV1("u"),
        source_state_refs=(StateGeneRefV1("f"),), residual_state_ref=StateGeneRefV1("r"))
    @test_throws ArgumentError F.compile_linear_field_residual_form(edge, graph, reg;
        constraint_edge_hash=digest256_text("wrong"), unknown_state_ref=StateGeneRefV1("u"),
        source_state_refs=(StateGeneRefV1("f"),), residual_state_ref=StateGeneRefV1("r"))
    badedge = AtomicMIMOHyperedgeV1("governing-edge", edge.input_bindings, edge.output_bindings, edge.program, governing; registry=reg)
    @test_throws ArgumentError F.compile_linear_field_residual_form(badedge, graph, reg;
        constraint_edge_hash=canonical_hash(badedge), unknown_state_ref=StateGeneRefV1("u"),
        source_state_refs=(StateGeneRefV1("f"),), residual_state_ref=StateGeneRefV1("r"))
    pbad, gbad, rbad = test_constraint(parameter=true)
    @test_throws ArgumentError F.compile_linear_field_residual_form(pbad, gbad, rbad;
        constraint_edge_hash=canonical_hash(pbad), unknown_state_ref=StateGeneRefV1("u"),
        source_state_refs=(), residual_state_ref=StateGeneRefV1("r"))
end

@testset "field residual assembly and sparse solve" begin
    grid = test_grid(); geometry = test_geometry(grid); edge, graph, reg = test_constraint()
    form = F.compile_linear_field_residual_form(edge, graph, reg;
        constraint_edge_hash=canonical_hash(edge), unknown_state_ref=StateGeneRefV1("u"),
        source_state_refs=(StateGeneRefV1("f"),), residual_state_ref=StateGeneRefV1("r"))
    coords = grid.axes; n = prod(length.(coords))
    u = [x^4 + 2y^4 + 3z^4 for x in coords[1] for y in coords[2] for z in coords[3]]
    src = [12x^2 + 24y^2 + 36z^2 for x in coords[1] for y in coords[2] for z in coords[3]]
    source = F.FieldResidualPayloadV4(StateGeneRefV1("f"), grid, src, SOURCE_SCALAR)
    boundary = F.FieldResidualPayloadV4(StateGeneRefV1("u"), grid, u, SCALAR)
    protocol = F.StructuredGridProtocolV4()
    assembly = F.assemble_field_residual_kernel(form, geometry, grid, (source,), boundary, protocol)
    result = F.solve_field_residual_kernel(assembly, protocol)
    @test result.status == :converged
    @test result.residual_norm <= 1e-9
    @test result.boundary_mismatch == 0.0
    @test result.assembly_hash == assembly.assembly_hash
    @test result.protocol_hash == protocol.protocol_hash
    @test result.factorization_status == :success
    @test result.conditioning_estimate === nothing
    @test result.conditioning_status == :unknown_not_computed
    A = F._fr_matrix(assembly)
    s2 = geometry.support
    support2 = SpatialSupportGeneV1(s2.support_ref, 3, s2.coordinate_frame_refs, s2.charts, s2.chart_transition_maps,
        NonnegativeQuantityV1(2, LEN))
    geometry2 = F.compile_diagonal_affine_geometry(support2, geometry.chart_ref, geometry.factors, geometry.offsets, grid)
    assembly2 = F.assemble_field_residual_kernel(form, geometry2, grid, (source,), boundary, protocol)
    A2 = F._fr_matrix(assembly2)
    kcenter = F._fr_index(3, 3, 3, 5, 5, 5)
    @test isapprox(A2[kcenter, kcenter + 1] / A[kcenter, kcenter + 1], 0.25; rtol=1e-12)
    @test geometry2.geometry_hash != geometry.geometry_hash && assembly2.assembly_hash != assembly.assembly_hash
    @test length(assembly.row_ownership) == n
    @test canonical_hash(assembly) == assembly.assembly_hash
    boundary_indices = Set(assembly.boundary_indices)
    @test all(A[k,j] == 0.0 for k in 1:n if !(k in boundary_indices) for j in boundary_indices)
    @test_throws ArgumentError F.assemble_field_residual_kernel(form, geometry, grid, (), boundary, protocol)
    @test_throws ArgumentError F.assemble_field_residual_kernel(form, geometry, grid, (source, source), boundary, protocol)
    wrong_source = F.FieldResidualPayloadV4(StateGeneRefV1("f"), grid, src, SCALAR)
    @test_throws ArgumentError F.assemble_field_residual_kernel(form, geometry, grid, (wrong_source,), boundary, protocol)
    forged_source = F.FieldResidualPayloadV4(F._FR_TOKEN, source.state_ref, source.coordinates, source.values,
        source.physical_type, digest256_text(repeat("0", 64)))
    @test_throws ArgumentError F.assemble_field_residual_kernel(form, geometry, grid, (forged_source,), boundary, protocol)
    shifted_grid = F.FieldGridSpecV4((Tuple(x + 0.01 for x in grid.axes[1]), grid.axes[2], grid.axes[3]))
    shifted_boundary = F.FieldResidualPayloadV4(StateGeneRefV1("u"), shifted_grid, u, SCALAR)
    @test_throws ArgumentError F.assemble_field_residual_kernel(form, geometry, grid, (source,), shifted_boundary, protocol)
    protocol2 = F.StructuredGridProtocolV4(abs_tol=1e-9, rel_tol=1e-9)
    @test_throws ArgumentError F.solve_field_residual_kernel(assembly, protocol2)
    altered = F.FieldResidualPayloadV4(StateGeneRefV1("f"), grid, src .+ 1, SOURCE_SCALAR)
    altered_assembly = F.assemble_field_residual_kernel(form, geometry, grid, (altered,), boundary, protocol)
    @test altered_assembly.assembly_hash != assembly.assembly_hash
    edge2, graph2, reg2 = test_constraint(two_sources=true)
    form2 = F.compile_linear_field_residual_form(edge2, graph2, reg2;
        constraint_edge_hash=canonical_hash(edge2), unknown_state_ref=StateGeneRefV1("u"),
        source_state_refs=(StateGeneRefV1("g"), StateGeneRefV1("f")), residual_state_ref=StateGeneRefV1("r"))
    source_g = F.FieldResidualPayloadV4(StateGeneRefV1("g"), grid, src .* 0.5, SOURCE_SCALAR)
    assembly_order_a = F.assemble_field_residual_kernel(form2, geometry, grid, (source, source_g), boundary, protocol)
    assembly_order_b = F.assemble_field_residual_kernel(form2, geometry, grid, (source_g, source), boundary, protocol)
    @test assembly_order_a.assembly_hash == assembly_order_b.assembly_hash
    @test assembly_order_a.nzval == assembly_order_b.nzval && assembly_order_a.rhs == assembly_order_b.rhs
    @test F.solve_field_residual_kernel(assembly_order_a, protocol).solution ==
        F.solve_field_residual_kernel(assembly_order_b, protocol).solution
    singular_edge, singular_graph, singular_reg = test_constraint(zero_coefficient=true)
    @test_throws ArgumentError F.compile_linear_field_residual_form(singular_edge, singular_graph, singular_reg;
        constraint_edge_hash=canonical_hash(singular_edge), unknown_state_ref=StateGeneRefV1("u"),
        source_state_refs=(StateGeneRefV1("f"),), residual_state_ref=StateGeneRefV1("r"))
    bad_rowval = (2, assembly.rowval[2:end]...)
    corrupted = F.ResidualAssemblyV4(F._FR_TOKEN, assembly.n, assembly.colptr, bad_rowval, assembly.nzval,
        assembly.rhs, assembly.boundary_values, assembly.boundary_indices, assembly.row_ownership,
        assembly.form_hash, assembly.geometry_hash, assembly.grid_hash, assembly.protocol_hash,
        assembly.source_hashes, assembly.boundary_hash, assembly.assembly_hash)
    @test_throws ArgumentError F.solve_field_residual_kernel(corrupted, protocol)
    zero_colptr = Tuple(ones(Int, assembly.n + 1))
    singular0 = F.ResidualAssemblyV4(F._FR_TOKEN, assembly.n, zero_colptr, (), (), Tuple(zeros(assembly.n)),
        assembly.boundary_values, assembly.boundary_indices, assembly.row_ownership,
        assembly.form_hash, assembly.geometry_hash, assembly.grid_hash, assembly.protocol_hash,
        assembly.source_hashes, assembly.boundary_hash, digest256_text(repeat("0", 64)))
    singular = F.ResidualAssemblyV4(F._FR_TOKEN, assembly.n, singular0.colptr, singular0.rowval, singular0.nzval,
        singular0.rhs, singular0.boundary_values, singular0.boundary_indices, singular0.row_ownership,
        singular0.form_hash, singular0.geometry_hash, singular0.grid_hash, singular0.protocol_hash,
        singular0.source_hashes, singular0.boundary_hash, F._fr_assembly_integrity(singular0))
    failed = F.solve_field_residual_kernel(singular, protocol)
    @test failed.status == :numerical_fail
    @test failed.residual_norm === nothing && failed.backward_error === nothing && failed.boundary_mismatch === nothing
    @test failed.factorization_status == :failed && failed.reason !== nothing && !isempty(failed.reason)
    @test_throws ArgumentError F.FieldSolveResultV4(:converged, (), 0.0, 0.0, 0.0, :success, nothing,
        :unknown_not_computed, nothing, assembly.assembly_hash, protocol.protocol_hash, digest256_text(repeat("0", 64)))
end

function manufactured_error(n)
    grid = test_grid(n); geometry = test_geometry(grid); edge, graph, reg = test_constraint()
    form = F.compile_linear_field_residual_form(edge, graph, reg;
        constraint_edge_hash=canonical_hash(edge), unknown_state_ref=StateGeneRefV1("u"),
        source_state_refs=(StateGeneRefV1("f"),), residual_state_ref=StateGeneRefV1("r"))
    coords = grid.axes
    uexact = [x^4 + 2y^4 + 3z^4 for x in coords[1] for y in coords[2] for z in coords[3]]
    src = [12x^2 + 24y^2 + 36z^2 for x in coords[1] for y in coords[2] for z in coords[3]]
    source = F.FieldResidualPayloadV4(StateGeneRefV1("f"), grid, src, SOURCE_SCALAR)
    boundary = F.FieldResidualPayloadV4(StateGeneRefV1("u"), grid, uexact, SCALAR)
    protocol = F.StructuredGridProtocolV4()
    assembly = F.assemble_field_residual_kernel(form, geometry, grid, (source,), boundary, protocol)
    result = F.solve_field_residual_kernel(assembly, protocol)
    result.status == :converged || throw(ArgumentError("manufactured control did not converge"))
    maximum(abs.(collect(result.solution) .- uexact))
end

@testset "field residual manufactured second order control" begin
    e5, e9, e17 = manufactured_error(5), manufactured_error(9), manufactured_error(17)
    h5, h9, h17 = 2 / (5 - 1), 2 / (9 - 1), 2 / (17 - 1)
    p59 = log(e5 / e9) / log(h5 / h9)
    p917 = log(e9 / e17) / log(h9 / h17)
    @info "manufactured observed order" errors=(e5, e9, e17) orders=(p59, p917)
    @test e5 > e9 > e17
    @test isfinite(p59) && isfinite(p917)
    @test 1.7 <= p59 <= 2.3
    @test 1.7 <= p917 <= 2.3
end

