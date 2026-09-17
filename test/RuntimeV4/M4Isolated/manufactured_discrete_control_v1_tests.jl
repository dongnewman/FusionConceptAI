using Test
using SHA

const SOURCE_A = normpath(joinpath(@__DIR__, "../../..", "src", "RuntimeV4", "M4Isolated", "ManufacturedEquationIRV1.jl"))
const SOURCE_B = normpath(joinpath(@__DIR__, "../../..", "src", "RuntimeV4", "M4Isolated", "ManufacturedResidualLoweringV1.jl"))
const SOURCE_C = normpath(joinpath(@__DIR__, "../../..", "src", "RuntimeV4", "M4Isolated", "ManufacturedDiscreteControlV1.jl"))
@assert isfile(SOURCE_A) && isfile(SOURCE_B) && isfile(SOURCE_C)
include(SOURCE_A)
include(SOURCE_B)
include(SOURCE_C)

failure_codes(r) = Set(f.code for f in r.failures)
failure_signature(r) = [(f.code, f.path, f.detail) for f in r.failures]
stable_bytes(x) = sprint(show, x)

function clone_control(c::ManufacturedDiscreteControlV1;
        equation_id=c.equation_id, domain_id=c.domain_id, grid=c.grid,
        topology=c.topology, boundary=c.boundary, units=c.units,
        source_id=c.source_id, source_owner=c.source_owner,
        conservation_owner=c.conservation_owner, provenance=c.provenance,
        faces=c.faces, cell_balances=c.cell_balances,
        claim_ceiling=c.claim_ceiling, evidence_scope=c.evidence_scope)
    ManufacturedDiscreteControlV1(c.schema, c.residual, equation_id, domain_id,
        grid, topology, boundary, units, source_id, source_owner,
        conservation_owner, provenance, faces, cell_balances,
        claim_ceiling, evidence_scope)
end

function clone_grid(g::M4CGridV1; domain_id=g.domain_id, counts=g.counts,
        spacing=g.spacing, cell_volume=g.cell_volume,
        cell_centered=g.cell_centered, uniform=g.uniform,
        mesh_unit=g.mesh_unit, volume_unit=g.volume_unit)
    M4CGridV1(domain_id, g.dimension, counts, spacing, cell_volume,
        cell_centered, uniform, mesh_unit, volume_unit)
end

function clone_topology(t::M4CTopologyV1; id=t.id, grid_counts=t.grid_counts,
        cell_count=t.cell_count, face_count_per_cell=t.face_count_per_cell,
        conservation_owner=t.conservation_owner)
    M4CTopologyV1(id, t.dimension, grid_counts, cell_count, t.cell_centered,
        t.cartesian, t.uniform, face_count_per_cell, conservation_owner)
end

function clone_boundary(b::M4CBoundaryClosureV1; id=b.id,
        equation_id=b.equation_id, domain_id=b.domain_id,
        face_ids=b.face_ids, complete=b.complete, kind=b.kind,
        owner=b.owner, conservation_owner=b.conservation_owner)
    M4CBoundaryClosureV1(id, equation_id, domain_id, face_ids, complete, kind,
        owner, conservation_owner)
end

function clone_units(u::M4CUnitBindingV1; coefficient_unit=u.coefficient_unit,
        source_unit=u.source_unit)
    M4CUnitBindingV1(u.coordinate_unit, u.mesh_unit, u.face_area_unit,
        u.cell_volume_unit, coefficient_unit, u.field_unit, source_unit,
        u.divergence_unit, u.residual_unit)
end

function clone_face(f::M4CFaceFluxV1; normal_flux=f.normal_flux,
        divergence_contribution=f.divergence_contribution,
        source_id=f.source_id)
    M4CFaceFluxV1(f.cell_index, f.face_id, f.axis, f.side, f.coordinate,
        f.coefficient_component, f.field_gradient, normal_flux, f.face_area,
        divergence_contribution, f.equation_id, source_id,
        f.conservation_owner, f.boundary_id)
end

function clone_balance(b::M4CCellBalanceV1; faces=b.faces,
        divergence_total=b.divergence_total, residual_value=b.residual_value,
        source_id=b.source_id)
    M4CCellBalanceV1(b.cell_index, b.cell_center, faces,
        b.directional_divergence, divergence_total, b.source_value,
        residual_value, b.equation_id, source_id, b.source_owner,
        b.conservation_owner)
end

function with_first_face(c, f)
    old = c.cell_balances[1]
    balances = (clone_balance(old; faces=(f, old.faces[2:6]...)), c.cell_balances[2:end]...)
    clone_control(c; cell_balances=balances,
        faces=(balances[1].faces..., c.faces[7:end]...))
end

function with_first_balance(c, b)
    balances = (b, c.cell_balances[2:end]...)
    clone_control(c; cell_balances=balances,
        faces=(b.faces..., c.faces[7:end]...))
end

@testset "M4-C manufactured discrete control v1" begin
    ir = manufactured_equation_ir_v1()
    a = lower_manufactured_residual(ir)
    @test a.valid
    @test a.declaration !== nothing
    d = a.declaration
    @test validate_manufactured_residual(d, ir).valid

    controls = Dict{Tuple{Int,Int,Int},ManufacturedDiscreteControlV1}()
    for dims in ((2, 2, 2), (3, 4, 5))
        c_result = build_manufactured_discrete_control(a, dims...)
        @test c_result.valid
        @test c_result.status == :valid
        @test isempty(c_result.failures)
        @test c_result.control !== nothing
        c = c_result.control
        controls[dims] = c
        @test c.claim_ceiling == :manufactured_discrete_control
        @test c.evidence_scope == :screen_only
        @test validate_manufactured_discrete_control(c).valid
        @test is_valid_manufactured_discrete_control_v1(c)
        @test length(c.cell_balances) == prod(dims)
        @test length(c.faces) == 6 * prod(dims)
        @test c.grid.counts == dims
        @test c.topology.cell_count == prod(dims)
        for cell in c.cell_balances
            @test cell.directional_divergence ==
                (M4RationalV1(1, 10), M4RationalV1(1, 20), M4RationalV1(1, 30))
            @test cell.divergence_total == M4RationalV1(11, 60)
            @test cell.source_value == M4RationalV1(-11, 60)
            @test cell.residual_value == M4RationalV1(0, 1)
            @test length(cell.faces) == 6
            @test Tuple(f.face_id for f in cell.faces) ==
                ("x_min", "x_max", "y_min", "y_max", "z_min", "z_max")
            @test all(f -> f.field_gradient == M4RationalV1(1, 1), cell.faces)
        end
    end

    @testset "deterministic payload and aliases" begin
        c1 = controls[(3, 4, 5)]
        c2 = build_manufactured_discrete_control(a, 3, 4, 5).control
        p1 = stable_bytes(manufactured_discrete_control_payload(c1))
        p2 = stable_bytes(manufactured_discrete_control_payload(c2))
        @test p1 == p2
        @test sha256(codeunits(p1)) == sha256(codeunits(p2))
        @test manufactured_discrete_payload_v1(c1) ==
            manufactured_discrete_control_payload_v1(c1)
        @test manufactured_discrete_control_v1(a, 2, 2, 2).valid
        @test lower_manufactured_discrete_control_v1(a, 2, 2, 2).valid
    end

    @testset "typed grid, topology, boundary, unit and stencil controls" begin
        c = controls[(2, 2, 2)]
        @test :invalid_grid in failure_codes(
            build_manufactured_discrete_control(a, 1, 2, 2))
        @test :invalid_grid in failure_codes(
            build_manufactured_discrete_control(a, 2, 0, 2))
        @test :invalid_grid in failure_codes(
            build_manufactured_discrete_control(a, 2, 2, 1))
        @test :invalid_topology in failure_codes(validate_manufactured_discrete_control(
            clone_control(c; topology=clone_topology(c.topology; id="foreign-topology"))))
        @test :invalid_boundary in failure_codes(validate_manufactured_discrete_control(
            clone_control(c; boundary=clone_boundary(c.boundary; complete=false))))
        wrong_unit = M4UnitV1("kg", (0, 1, 0, 0, 0, 0, 0), 1.0)
        @test :unit_closure_failure in failure_codes(validate_manufactured_discrete_control(
            clone_control(c; units=clone_units(c.units; coefficient_unit=wrong_unit))))
        first = c.cell_balances[1].faces[1]
        @test :nonconservative_stencil in failure_codes(validate_manufactured_discrete_control(
            with_first_face(c, clone_face(first; normal_flux=M4RationalV1(99, 1)))))
        @test :nonconservative_stencil in failure_codes(validate_manufactured_discrete_control(
            with_first_face(c, clone_face(first; divergence_contribution=M4RationalV1(0, 1)))))
    end

    @testset "typed foreign A/B/equation/source/owner/provenance/residual controls" begin
        c = controls[(2, 2, 2)]
        @test :foreign_input in failure_codes(
            build_manufactured_discrete_control(ir, 2, 2, 2))
        bad_a = manufactured_equation_ir_v1(equation_id="FOREIGN-EQUATION")
        bad_b = lower_manufactured_residual(bad_a)
        @test !bad_b.valid
        @test :foreign_input in failure_codes(
            build_manufactured_discrete_control(bad_b, 2, 2, 2))
        @test :foreign_input in failure_codes(validate_manufactured_discrete_control(
            clone_control(c; equation_id="FOREIGN-EQUATION")))
        @test :foreign_input in failure_codes(validate_manufactured_discrete_control(
            clone_control(c; source_id="FOREIGN-SOURCE")))
        @test :owner_mismatch in failure_codes(validate_manufactured_discrete_control(
            clone_control(c; source_owner="FOREIGN-SOURCE-OWNER")))
        @test :owner_mismatch in failure_codes(validate_manufactured_discrete_control(
            clone_control(c; conservation_owner="FOREIGN-CONSERVATION-OWNER")))
        foreign_provenance = M4ProvenanceDeclarationV1(
            :explicit_manufactured_or_analytic, :manufactured_only,
            :no_external_authority, false, :foreign, :screen_only)
        @test :provenance_mismatch in failure_codes(validate_manufactured_discrete_control(
            clone_control(c; provenance=foreign_provenance)))
        first = c.cell_balances[1]
        @test :nonzero_residual in failure_codes(validate_manufactured_discrete_control(
            with_first_balance(c, clone_balance(first;
                residual_value=M4RationalV1(1, 100)))))
    end

    @testset "screen-only ceiling and forbidden API boundary" begin
        forbidden = (:discretize, :assemble, :assemble_matrix, :solve, :couple,
            :transfer_topology, :bind_candidate, :invoke_provider, :CandidateStatePackageV5)
        for name in forbidden
            @test !isdefined(@__MODULE__, name)
        end
        @test !isdefined(@__MODULE__, :RuntimeEvidenceV4)
        @test !isdefined(@__MODULE__, :ForwardChainContextV4)
    end

    @testset "failure determinism" begin
        c = controls[(2, 2, 2)]
        bad = clone_control(c; topology=clone_topology(c.topology; id="foreign"),
            source_owner="foreign")
        @test failure_signature(validate_manufactured_discrete_control(bad)) ==
            failure_signature(validate_manufactured_discrete_control(bad))
    end
end

println("M4-C-TESTS PASS manufactured_discrete_control/screen_only")
