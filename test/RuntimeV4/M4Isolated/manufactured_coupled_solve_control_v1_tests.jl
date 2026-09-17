using Test
using SHA

const SOURCE_A = normpath(joinpath(@__DIR__, "../../..", "src", "RuntimeV4", "M4Isolated", "ManufacturedEquationIRV1.jl"))
const SOURCE_B = normpath(joinpath(@__DIR__, "../../..", "src", "RuntimeV4", "M4Isolated", "ManufacturedResidualLoweringV1.jl"))
const SOURCE_C = normpath(joinpath(@__DIR__, "../../..", "src", "RuntimeV4", "M4Isolated", "ManufacturedDiscreteControlV1.jl"))
const SOURCE_D = normpath(joinpath(@__DIR__, "../../..", "src", "RuntimeV4", "M4Isolated", "ManufacturedCoupledSolveControlV1.jl"))
for path in (SOURCE_A, SOURCE_B, SOURCE_C, SOURCE_D)
    @assert isfile(path) "M4-D source path is missing: $path"
end
include(SOURCE_A)
include(SOURCE_B)
include(SOURCE_C)
include(SOURCE_D)

failure_codes(result) = Set(f.code for f in result.failures)
failure_signature(result) = [(f.code, f.path, f.detail) for f in result.failures]
stable_bytes(x) = sprint(show, x)

function clone_grid(g::M4CGridV1; domain_id=g.domain_id, counts=g.counts,
        spacing=g.spacing, cell_volume=g.cell_volume,
        cell_centered=g.cell_centered, uniform=g.uniform,
        mesh_unit=g.mesh_unit, volume_unit=g.volume_unit)
    M4CGridV1(domain_id, g.dimension, counts, spacing, cell_volume,
        cell_centered, uniform, mesh_unit, volume_unit)
end

function clone_units(u::M4CUnitBindingV1; coefficient_unit=u.coefficient_unit,
        source_unit=u.source_unit)
    M4CUnitBindingV1(u.coordinate_unit, u.mesh_unit, u.face_area_unit,
        u.cell_volume_unit, coefficient_unit, u.field_unit, source_unit,
        u.divergence_unit, u.residual_unit)
end

function clone_c(c::ManufacturedDiscreteControlV1; equation_id=c.equation_id,
        grid=c.grid, units=c.units, source_id=c.source_id,
        source_owner=c.source_owner, conservation_owner=c.conservation_owner,
        provenance=c.provenance)
    ManufacturedDiscreteControlV1(c.schema, c.residual, equation_id, c.domain_id,
        grid, c.topology, c.boundary, units, source_id, source_owner,
        conservation_owner, provenance, c.faces, c.cell_balances,
        c.claim_ceiling, c.evidence_scope)
end

function clone_interface(i::M4DInterfaceBindingV1; pairs=i.pairs,
        left_grid_counts=i.left_grid_counts, right_grid_counts=i.right_grid_counts,
        identity=i.identity, bijective=i.bijective,
        conservation_owner=i.conservation_owner)
    M4DInterfaceBindingV1(i.left_region_id, i.right_region_id,
        left_grid_counts, right_grid_counts, pairs, identity, bijective,
        conservation_owner)
end

function clone_cell(s::M4DCoupledCellSolutionV1; left_index=s.left_index,
        right_index=s.right_index, left_value=s.left_value,
        right_value=s.right_value, residual=s.residual)
    M4DCoupledCellSolutionV1(left_index, right_index, left_value,
        right_value, residual, s.equation_id, s.source_id,
        s.conservation_owner)
end

function clone_d(c::ManufacturedCoupledSolveControlV1;
        left=c.left, right=c.right, grid_counts=c.grid_counts,
        interface=c.interface, block_matrix=c.block_matrix, rhs=c.rhs,
        equation_id=c.equation_id, source_id=c.source_id,
        source_owner=c.source_owner, conservation_owner=c.conservation_owner,
        units=c.units, provenance=c.provenance, cell_solutions=c.cell_solutions,
        block_residuals=c.block_residuals, block_residual=c.block_residual,
        claim_ceiling=c.claim_ceiling, evidence_scope=c.evidence_scope)
    ManufacturedCoupledSolveControlV1(c.schema, left, right,
        c.left_region_id, c.right_region_id, grid_counts, interface,
        block_matrix, rhs, equation_id, source_id, source_owner,
        conservation_owner, units, provenance, cell_solutions,
        block_residuals, block_residual, claim_ceiling, evidence_scope)
end

function expect_typed(thunk, code::Symbol)
    result = try
        thunk()
    catch err
        println(stderr, "unexpected unclassified exception: $(typeof(err)): $(sprint(showerror, err))")
        @test false
        return nothing
    end
    @test result isa ManufacturedCoupledSolveControlResultV1
    if result isa ManufacturedCoupledSolveControlResultV1
        @test !result.valid
        @test result.status == :typed_failure
        @test code in failure_codes(result)
    end
    result
end

@testset "M4-D manufactured coupled solve control v1" begin
    ir = manufactured_equation_ir_v1()
    a = lower_manufactured_residual(ir)
    @test a.valid
    @test a.declaration !== nothing
    d = a.declaration
    @test validate_manufactured_residual(d, ir).valid

    left_result = build_manufactured_discrete_control(a, 2, 2, 2)
    right_result = build_manufactured_discrete_control(a, 2, 2, 2)
    @test left_result.valid && right_result.valid
    left, right = left_result.control, right_result.control
    @test left !== nothing && right !== nothing
    left = left::ManufacturedDiscreteControlV1
    right = right::ManufacturedDiscreteControlV1

    result = build_manufactured_coupled_solve_control(left, right)
    @test result.valid
    @test result.status == :valid
    @test isempty(result.failures)
    @test result.control !== nothing
    control = result.control::ManufacturedCoupledSolveControlV1
    @test validate_manufactured_coupled_solve_control(control).valid
    @test is_valid_manufactured_coupled_solve_control_v1(control)
    @test control.claim_ceiling == :manufactured_coupled_solve_control
    @test control.evidence_scope == :screen_only
    @test control.block_matrix ==
        (M4RationalV1(2, 1), M4RationalV1(-1, 1),
         M4RationalV1(-1, 1), M4RationalV1(2, 1))
    @test control.rhs == (M4RationalV1(1, 1), M4RationalV1(0, 1))
    @test length(control.interface.pairs) == 8
    @test length(control.cell_solutions) == 8
    @test control.block_residual == M4RationalV1(0, 1)

    @testset "exact block solve and identity interface" begin
        @test _m4d_sub(_m4d_mul(control.block_matrix[1], control.block_matrix[4]),
            _m4d_mul(control.block_matrix[2], control.block_matrix[3])) == M4RationalV1(3, 1)
        @test all(p -> p.left_index == p.right_index, control.interface.pairs)
        expected = Set((i, j, k) for k in 1:2, j in 1:2, i in 1:2)
        @test Set(s.left_index for s in control.cell_solutions) == expected
        @test Set(s.right_index for s in control.cell_solutions) == expected
        @test all(s -> s.left_value == M4RationalV1(2, 3) &&
            s.right_value == M4RationalV1(1, 3) &&
            s.residual == (M4RationalV1(0, 1), M4RationalV1(0, 1)),
            control.cell_solutions)
        @test all(r -> r == (M4RationalV1(0, 1), M4RationalV1(0, 1)),
            control.block_residuals)
    end

    @testset "deterministic payload and API aliases" begin
        payload_1 = stable_bytes(manufactured_coupled_solve_control_payload(control))
        payload_2 = stable_bytes(manufactured_coupled_solve_control_payload(
            build_manufactured_coupled_solve_control(left, right).control))
        @test payload_1 == payload_2
        @test sha256(codeunits(payload_1)) == sha256(codeunits(payload_2))
        @test manufactured_coupled_solve_control_v1(left, right).valid
        @test solve_manufactured_coupled_control_v1(left, right).valid
        @test manufactured_coupled_solve_payload_v1(control) ==
            manufactured_coupled_payload_v1(control)
    end

    @testset "typed input, interface, matrix, and RHS controls" begin
        expect_typed(() -> build_manufactured_coupled_solve_control(ir, right), :foreign_c_input)
        expect_typed(() -> build_manufactured_coupled_solve_control(left, ir), :foreign_c_input)

        duplicate = (control.interface.pairs[1], control.interface.pairs[1],
            control.interface.pairs[3:end]...)
        bad_interface = clone_interface(control.interface; pairs=duplicate)
        expect_typed(() -> build_manufactured_coupled_solve_control(left, right;
            interface=bad_interface), :nonbijective_interface)

        singular = (M4RationalV1(1, 1), M4RationalV1(0, 1),
            M4RationalV1(0, 1), M4RationalV1(0, 1))
        expect_typed(() -> build_manufactured_coupled_solve_control(left, right;
            block_matrix=singular), :singular_block)
        non_spd = (M4RationalV1(-1, 1), M4RationalV1(0, 1),
            M4RationalV1(0, 1), M4RationalV1(2, 1))
        expect_typed(() -> build_manufactured_coupled_solve_control(left, right;
            block_matrix=non_spd), :non_spd_block)
        expect_typed(() -> build_manufactured_coupled_solve_control(left, right;
            rhs=(M4RationalV1(1, 1),)), :foreign_c_input)

        wrong_rhs = clone_d(control; rhs=(M4RationalV1(0, 1), M4RationalV1(1, 1)))
        expect_typed(() -> validate_manufactured_coupled_solve_control(wrong_rhs), :nonzero_residual)
    end

    @testset "typed binding and provenance controls" begin
        bad_grid = clone_grid(right.grid; counts=(2, 2, 3))
        expect_typed(() -> build_manufactured_coupled_solve_control(left,
            clone_c(right; grid=bad_grid)), :grid_mismatch)

        wrong_unit = M4UnitV1("kg", (0, 1, 0, 0, 0, 0, 0), 1.0)
        expect_typed(() -> build_manufactured_coupled_solve_control(left,
            clone_c(right; units=clone_units(right.units; coefficient_unit=wrong_unit))), :unit_mismatch)
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; equation_id="FOREIGN-EQUATION")), :owner_mismatch)
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; source_id="FOREIGN-SOURCE")), :owner_mismatch)
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; source_owner="FOREIGN-SOURCE-OWNER")), :owner_mismatch)
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; conservation_owner="FOREIGN-CONSERVATION-OWNER")), :owner_mismatch)
        foreign_provenance = M4ProvenanceDeclarationV1(
            :explicit_manufactured_or_analytic, :manufactured_only,
            :no_external_authority, false, :foreign, :screen_only)
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; provenance=foreign_provenance)), :provenance_mismatch)
        bad_interface_owner = clone_interface(control.interface;
            conservation_owner="FOREIGN-CONSERVATION-OWNER")
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; interface=bad_interface_owner)), :owner_mismatch)
    end

    @testset "typed nonzero residual controls" begin
        bad_cell = clone_cell(control.cell_solutions[1];
            left_value=M4RationalV1(3, 3))
        bad_cells = (bad_cell, control.cell_solutions[2:end]...)
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; cell_solutions=bad_cells)), :nonzero_residual)
        bad_residuals = ((M4RationalV1(1, 100), M4RationalV1(0, 1)),
            control.block_residuals[2:end]...)
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; block_residuals=bad_residuals)), :nonzero_residual)
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; block_residual=M4RationalV1(1, 100))), :nonzero_residual)
    end

    @testset "source repair nested-input and correspondence regressions" begin
        # The repaired validator must turn failures inside either nested C
        # control into typed M4-D failures, never an unclassified exception.
        foreign_right_source_owner = clone_c(right;
            source_owner="FOREIGN-RIGHT-SOURCE-OWNER")
        nested_source_result = expect_typed(() ->
            validate_manufactured_coupled_solve_control(clone_d(control;
                right=foreign_right_source_owner)), :foreign_c_input)
        @test any(startswith(f.path, "right.") for f in nested_source_result.failures)

        foreign_right_conservation_owner = clone_c(right;
            conservation_owner="FOREIGN-RIGHT-CONSERVATION-OWNER")
        nested_conservation_result = expect_typed(() ->
            validate_manufactured_coupled_solve_control(clone_d(control;
                right=foreign_right_conservation_owner)), :foreign_c_input)
        @test any(startswith(f.path, "right.") for f in nested_conservation_result.failures)

        invalid_nested_right = clone_c(right; equation_id="FOREIGN-NESTED-EQUATION")
        nested_invalid_result = expect_typed(() ->
            validate_manufactured_coupled_solve_control(clone_d(control;
                right=invalid_nested_right)), :foreign_c_input)
        @test any(startswith(f.path, "right.") for f in nested_invalid_result.failures)

        @test :grid_mismatch in failure_codes(validate_manufactured_coupled_solve_control(
            clone_d(control; grid_counts=(2, 2, 3))))
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; grid_counts=(2, 2, 3))), :grid_mismatch)

        left_interface_grid_mismatch = clone_interface(control.interface;
            left_grid_counts=(2, 3, 2))
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; interface=left_interface_grid_mismatch)), :grid_mismatch)
        right_interface_grid_mismatch = clone_interface(control.interface;
            right_grid_counts=(3, 2, 2))
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; interface=right_interface_grid_mismatch)), :grid_mismatch)

        swapped_pairs = (control.interface.pairs[2], control.interface.pairs[1],
            control.interface.pairs[3:end]...)
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; interface=clone_interface(control.interface;
                pairs=swapped_pairs))), :nonbijective_interface)

        missing_pair = control.interface.pairs[1:end-1]
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; interface=clone_interface(control.interface;
                pairs=missing_pair))), :nonbijective_interface)

        duplicate_pair = (control.interface.pairs[1], control.interface.pairs[1],
            control.interface.pairs[3:end]...)
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; interface=clone_interface(control.interface;
                pairs=duplicate_pair))), :nonbijective_interface)

        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; cell_solutions=(clone_cell(control.cell_solutions[1];
                right_index=(2, 1, 1)), control.cell_solutions[2:end]...))),
            :nonbijective_interface)
        expect_typed(() -> validate_manufactured_coupled_solve_control(
            clone_d(control; cell_solutions=(clone_cell(control.cell_solutions[1];
                left_index=(2, 1, 1)), control.cell_solutions[2:end]...))),
            :nonbijective_interface)
    end

    @testset "screen-only API boundary" begin
        @test !isdefined(@__MODULE__, :CandidateStatePackageV5)
        @test !isdefined(@__MODULE__, :RuntimeEvidenceV4)
        @test !isdefined(@__MODULE__, :ForwardChainContextV4)
        @test !isdefined(@__MODULE__, :iterative_solver)
        @test !isdefined(@__MODULE__, :solve_pde)
        @test !isdefined(@__MODULE__, :production_provider)
        @test !isdefined(@__MODULE__, :invoke_provider)
        source_text = read(SOURCE_D, String)
        @test !occursin("Gridap", source_text)
    end

    @testset "failure determinism" begin
        bad = clone_d(control; source_owner="foreign")
        @test failure_signature(validate_manufactured_coupled_solve_control(bad)) ==
            failure_signature(validate_manufactured_coupled_solve_control(bad))
    end
end

println("M4-D-TESTS PASS manufactured_coupled_solve_control/screen_only")
