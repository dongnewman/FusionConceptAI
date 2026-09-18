using Test
using JSON3

const DSC_ROOT = normpath(joinpath(@__DIR__, "../../.."))
const DSC_SOURCE = joinpath(DSC_ROOT, "src", "RuntimeV4", "DeclaredSpatialCompositionExecutionV1.jl")
@assert isfile(DSC_SOURCE) "declared spatial composition source is missing"
include(DSC_SOURCE)

function with_case(case; old_geometry=case.old_geometry, new_geometry=case.new_geometry,
                   old_state=case.old_state, field=case.field, boundary=case.boundary,
                   composition=case.composition)
    DeclaredSpatialCaseV1(old_geometry, new_geometry, old_state, field, boundary, composition)
end

function base_plan(; source=[1.0, 0.0, -0.5, 0.75], boundary=(0.0, 1.0))
    unit_u = "u-SI"; unit_f = "f-SI"
    DeclaredSpatialCompositionV1((
        DeclaredSpatialComponentV1("source-A", (DeclaredSpatialPortV1("p1", :output, :source, unit_f, "source"; role=:source, magnitude=1.0, payload=source),)),
        DeclaredSpatialComponentV1("source-B", (DeclaredSpatialPortV1("p2", :input, :source, unit_f, "source"; role=:source, magnitude=1.0, payload=source),)),
        DeclaredSpatialComponentV1("boundary-A", (DeclaredSpatialPortV1("p3", :output, :field, unit_u, "boundary"; role=:boundary, magnitude=1.0, payload=boundary),)),
        DeclaredSpatialComponentV1("boundary-B", (DeclaredSpatialPortV1("p4", :input, :field, unit_u, "boundary"; role=:boundary, magnitude=1.0, payload=boundary),)),
        DeclaredSpatialComponentV1("solver", (DeclaredSpatialPortV1("p5", :output, :field, unit_u, "field"; role=:field, magnitude=1.0),)),
        DeclaredSpatialComponentV1("return", (DeclaredSpatialPortV1("p6", :input, :field, unit_u, "field"; role=:field, magnitude=1.0),))))
end

@testset "UP2/UP3 declared spatial composition execution V1" begin
    case = manufactured_declared_spatial_case(plan=base_plan())
    outcome = execute_declared_spatial_composition(case)
    @test outcome.status === :ready
    @test outcome.code === :joint_linear_solved
    @test outcome.accepted === false
    @test outcome.claim_ceiling === :screen_only
    @test outcome.formal_up_credit === false
    @test outcome.formal_r_credit === false
    @test outcome.formal_l4_credit === false
    @test outcome.provider_calls == 0
    @test outcome.solver_invocations == 1
    @test outcome.conservation_residual <= 1e-12
    @test outcome.interface_flux_residual <= 1e-10
    @test outcome.joint_residual <= 1e-12
    @test outcome.ledger_residual <= 1e-12
    @test outcome.mms_order >= 1.8
    @test length(outcome.edges) == 3
    @test outcome.assembly.matrix isa Matrix{Float64}
    @test outcome.receipt_hash != ""

    @testset "measure overlap and label/order erasure" begin
        transfer = measure_overlap_transfer(case.old_geometry, case.new_geometry, case.old_state)
        @test transfer.valid
        @test transfer.transfer.new_state == (0.25, 0.25, 0.75, 0.75)
        @test transfer.residual <= 1e-12
        renamed_components = Tuple(DeclaredSpatialComponentV1("renamed-$i", Tuple(
            DeclaredSpatialPortV1("renamed-port-$i-$(j)", p.direction, p.quantity, p.unit,
                p.account; role=p.role, magnitude=p.magnitude, payload=p.payload)
            for (j, p) in enumerate(c.ports)))
            for (i, c) in enumerate(reverse(case.composition.components)))
        renamed = DeclaredSpatialCompositionV1(reverse(renamed_components))
        renamed_outcome = execute_declared_spatial_composition(with_case(case; composition=renamed))
        @test renamed_outcome.status === :ready
        @test renamed_outcome.assembly.assembly_hash == outcome.assembly.assembly_hash
        @test renamed_outcome.receipt_hash == outcome.receipt_hash
    end

    @testset "two K/BC groups are real numerical/hash drivers" begin
        altered = execute_declared_spatial_composition(with_case(case;
            field=DeclaredSpatialFieldV1([1.2, 1.8, 1.3, 0.9], case.field.source),
            boundary=DeclaredSpatialBoundaryV1(:dirichlet, 0.25, :dirichlet, 0.9),
            composition=base_plan(boundary=(0.25, 0.9))))
        @test altered.status === :ready
        @test altered.k_hash != outcome.k_hash
        @test altered.boundary_hash != outcome.boundary_hash
        @test altered.solution != outcome.solution
        @test altered.assembly.assembly_hash != outcome.assembly.assembly_hash
        payload_mismatch = execute_declared_spatial_composition(with_case(case;
            composition=base_plan(source=2.0 .* case.field.source)))
        @test payload_mismatch.status === :fail_closed
        @test payload_mismatch.code === :source_payload_mismatch
        payload_scaled = execute_declared_spatial_composition(with_case(case;
            field=DeclaredSpatialFieldV1(case.field.k_cells, 2.0 .* case.field.source),
            composition=base_plan(source=2.0 .* case.field.source)))
        @test payload_scaled.status === :ready
        @test payload_scaled.assembly.rhs != outcome.assembly.rhs
        @test payload_scaled.assembly.assembly_hash != outcome.assembly.assembly_hash
        @test payload_scaled.edges[1].producer.payload == 2.0 .* case.field.source
    end

    @testset "canonical field hashes and Neumann RHS contribution" begin
        bad_k_hash = execute_declared_spatial_composition(with_case(case;
            field=DeclaredSpatialFieldV1(case.field.k_cells, case.field.source;
                k_hash=repeat("0", 64))))
        @test bad_k_hash.status === :fail_closed
        @test bad_k_hash.code === :k_hash_mismatch
        neumann_case = with_case(case;
            boundary=DeclaredSpatialBoundaryV1(:neumann, 0.3, :dirichlet, 1.0),
            composition=base_plan(boundary=(0.3, 1.0)))
        neumann = execute_declared_spatial_composition(neumann_case)
        @test neumann.status === :ready
        @test neumann.assembly.rhs[1] != outcome.assembly.rhs[1]
    end

    negatives = Dict{String,Tuple{Symbol,Symbol}}()
    @testset "required fail-closed and terminal gaps" begin
        duplicate_plan = DeclaredSpatialCompositionV1((base_plan().components...,
            DeclaredSpatialComponentV1("duplicate", (DeclaredSpatialPortV1("dup", :output, :field, "u-SI", "field"; role=:field),))))
        duplicate = execute_declared_spatial_composition(with_case(case; composition=duplicate_plan))
        negatives["duplicate_producer"] = (duplicate.status, duplicate.code)
        @test negatives["duplicate_producer"] == (:fail_closed, :duplicate_producer)

        mismatch_plan = DeclaredSpatialCompositionV1((
            DeclaredSpatialComponentV1("source-A", (DeclaredSpatialPortV1("p1", :output, :source, "f-SI", "source"; role=:source, magnitude=1.0),)),
            DeclaredSpatialComponentV1("source-B", (DeclaredSpatialPortV1("p2", :input, :source, "f-SI", "source"; role=:source, magnitude=1.0),)),
            DeclaredSpatialComponentV1("boundary-A", (DeclaredSpatialPortV1("p3", :output, :field, "u-SI", "boundary"; role=:boundary, magnitude=1.0),)),
            DeclaredSpatialComponentV1("boundary-B", (DeclaredSpatialPortV1("p4", :input, :field, "bad-unit", "boundary"; role=:boundary, magnitude=1.0),)),
            DeclaredSpatialComponentV1("solver", (DeclaredSpatialPortV1("p5", :output, :field, "u-SI", "field"; role=:field),)),
            DeclaredSpatialComponentV1("return", (DeclaredSpatialPortV1("p6", :input, :field, "u-SI", "field"; role=:field),))))
        mismatch = execute_declared_spatial_composition(with_case(case; composition=mismatch_plan))
        negatives["unit_mismatch"] = (mismatch.status, mismatch.code)
        @test negatives["unit_mismatch"] == (:fail_closed, :unit_mismatch)

        missing_boundary_plan = DeclaredSpatialCompositionV1((base_plan().components[1], base_plan().components[2],
            base_plan().components[5], base_plan().components[6]))
        missing_boundary = execute_declared_spatial_composition(with_case(case; composition=missing_boundary_plan))
        negatives["missing_boundary"] = (missing_boundary.status, missing_boundary.code)
        @test negatives["missing_boundary"] == (:fail_closed, :missing_boundary)

        nonoverlap_geometry = DeclaredSpatialGeometryV1("new-outside", [0.0, 0.25, 0.5, 0.75, 1.25])
        nonoverlap = execute_declared_spatial_composition(with_case(case; new_geometry=nonoverlap_geometry))
        negatives["nonoverlap"] = (nonoverlap.status, nonoverlap.code)
        @test negatives["nonoverlap"] == (:terminal_deferred, :nonoverlap)

        nonfinite = execute_declared_spatial_composition(with_case(case;
            field=DeclaredSpatialFieldV1([1.0, NaN, 1.5, 0.8], case.field.source)))
        negatives["nonfinite_K"] = (nonfinite.status, nonfinite.code)
        @test negatives["nonfinite_K"] == (:fail_closed, :nonfinite_K)

        pure_neumann = execute_declared_spatial_composition(with_case(case;
            boundary=DeclaredSpatialBoundaryV1(:neumann, 0.0, :neumann, 0.0),
            composition=base_plan(boundary=(0.0, 0.0))))
        negatives["pure_neumann_singular"] = (pure_neumann.status, pure_neumann.code)
        @test negatives["pure_neumann_singular"] == (:numerical_fail, :pure_neumann_singular)

        missing_return_plan = DeclaredSpatialCompositionV1(base_plan().components[1:5])
        missing_return = execute_declared_spatial_composition(with_case(case; composition=missing_return_plan))
        negatives["missing_return"] = (missing_return.status, missing_return.code)
        @test negatives["missing_return"] == (:fail_closed, :missing_return)

        forged_geometry = DeclaredSpatialGeometryV1("new-4", case.new_geometry.edges;
            cell_labels=case.new_geometry.cell_labels, geometry_hash=repeat("0", 64))
        geometry_changed = execute_declared_spatial_composition(with_case(case; new_geometry=forged_geometry))
        negatives["geometry_hash_change"] = (geometry_changed.status, geometry_changed.code)
        @test negatives["geometry_hash_change"] == (:fail_closed, :geometry_hash_mismatch)
    end

    fixture = JSON3.read(read(joinpath(@__DIR__, "fixture.json"), String))
    @test fixture.schema == DSC_SCHEMA_V1
    @test fixture.claim_ceiling == "screen_only"
    holdout_case = manufactured_declared_spatial_case(
        k_cells=[2.0, 0.75, 1.4, 2.2], source=[-0.3, 1.0, 0.2, -0.1],
        boundary=DeclaredSpatialBoundaryV1(:dirichlet, 0.2, :dirichlet, -0.4),
        plan=base_plan(source=[-0.3, 1.0, 0.2, -0.1], boundary=(0.2, -0.4)))
    holdout_outcome = execute_declared_spatial_composition(holdout_case)
    @test fixture.holdout.case_ref == "holdout-independent"
    @test holdout_outcome.status === :ready
    @test all(isapprox(holdout_outcome.solution[i], fixture.holdout.solution[i]; atol=1e-10, rtol=0.0) for i in 1:4)
    pure_neumann_probe = execute_declared_spatial_composition(with_case(case;
        boundary=DeclaredSpatialBoundaryV1(:neumann, fixture.pure_neumann_probe.left_value,
            :neumann, fixture.pure_neumann_probe.right_value),
        composition=base_plan(boundary=(fixture.pure_neumann_probe.left_value,
            fixture.pure_neumann_probe.right_value))))
    @test String(pure_neumann_probe.status) == String(fixture.pure_neumann_probe.expected_status)
    @test String(pure_neumann_probe.code) == String(fixture.pure_neumann_probe.expected_code)
    expected = Dict{String,Tuple{Symbol,Symbol}}()
    for (name, pair) in pairs(fixture.negative_expectations)
        expected[String(name)] = (Symbol(String(pair[1])), Symbol(String(pair[2])))
    end
    @test negatives == expected
end
