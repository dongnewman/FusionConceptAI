using Test
using LinearAlgebra
include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_ideal_mhd_interface_traction.jl"))

function imit_replace(x, changes::NamedTuple)
    names = fieldnames(typeof(x))[1:end-1]
    body = merge(NamedTuple{names}(ntuple(i -> getfield(x, i), length(names))),
        changes)
    typeof(x)(IMIT._IMIT_TOKEN, values(body)..., canonical_hash(body))
end

@testset "candidate-bound local ideal-MHD traction executes" begin
    @test length(imit_pressure_points) == 2length(drstp_result.samples)
    @test imit_pressure_request.points == imit_pressure_points
    @test imit_pressure_result.provider_executed
    @test imit_pressure_result.receipt.exit_code == 0
    @test imit_request.mu0_N_A2 == 1.25663706127e-6
    @test imit_request.mu0_unit == raw"N \cdot A^{-2}"
    @test imit_request.mu0_source ==
        "NIST-CODATA-2022-vacuum-magnetic-permeability"
    @test imit_request.state_semantics ===
        :desc_c_plus_minus_epsilon_proxy_not_boundary_limit
    @test imit_request.normal_convention ===
        :minus_and_plus_region_outward_unit_normals
    @test canonical_hash(imit_request) == imit_request.request_hash
    @test canonical_hash(imit_result) == imit_result.result_hash
    @test IMIT.validate_ideal_mhd_interface_traction_result(
        imit_upstream..., imit_request, imit_result) == imit_result.result_hash
    @test imit_result.provider_selected
    @test imit_result.provider_executed
    @test imit_result.constitutive_evaluated
    @test imit_result.one_sided_traction_validated
    @test imit_result.traction_jump_evaluated
    @test imit_result.numerical_flux_evaluated
    @test imit_result.paired_flux_assembled
    @test imit_result.central_pair_cancelled
    @test imit_result.interface_flux_executed
end

@testset "traction formula and paired central flux are independently checkable" begin
    @test length(imit_result.samples) == length(drstp_result.samples)
    for (index, sample) in enumerate(imit_result.samples)
        surface = drstp_result.samples[index]
        minus_state = imit_pressure_result.samples[2index-1]
        plus_state = imit_pressure_result.samples[2index]
        @test sample.minus_pressure_Pa == minus_state.pressure_Pa
        @test sample.plus_pressure_Pa == plus_state.pressure_Pa
        @test all(isapprox.(sample.minus_B_xyz_T, surface.minus_B_xyz_T))
        @test all(isapprox.(sample.plus_B_xyz_T, surface.plus_B_xyz_T))
        @test norm(collect(sample.minus_outward_normal_xyz)) ≈ 1.0
        @test all(isapprox.(sample.plus_outward_normal_xyz,
            Tuple(-v for v in sample.minus_outward_normal_xyz)))
        minus_expected = ntuple(i -> sample.minus_total_pressure_Pa *
            sample.minus_outward_normal_xyz[i] - sample.minus_B_xyz_T[i] *
            dot(sample.minus_B_xyz_T, sample.minus_outward_normal_xyz) /
            imit_request.mu0_N_A2, 3)
        plus_expected = ntuple(i -> sample.plus_total_pressure_Pa *
            sample.plus_outward_normal_xyz[i] - sample.plus_B_xyz_T[i] *
            dot(sample.plus_B_xyz_T, sample.plus_outward_normal_xyz) /
            imit_request.mu0_N_A2, 3)
        @test all(isapprox.(sample.minus_traction_xyz_Pa, minus_expected))
        @test all(isapprox.(sample.plus_traction_xyz_Pa, plus_expected))
        @test all(isapprox.(sample.traction_jump_residual_xyz_Pa,
            Tuple(sample.minus_traction_xyz_Pa[i] +
                sample.plus_traction_xyz_Pa[i] for i in 1:3)))
        @test sample.minus_flux_contribution_xyz_Pa ==
            sample.central_oriented_traction_xyz_Pa
        @test sample.plus_flux_contribution_xyz_Pa ==
            Tuple(-v for v in sample.central_oriented_traction_xyz_Pa)
        @test sample.paired_flux_defect_norm_Pa == 0.0
        @test canonical_hash(sample) == sample.sample_hash
    end
end

@testset "foreign and forged identities fail closed" begin
    forged_mu0 = imit_replace(imit_request,
        (mu0_N_A2=4pi*1e-7,))
    @test_throws ArgumentError canonical_hash(forged_mu0)

    forged_spec = imit_replace(imit_request.specs[1],
        (interface_id="forged-interface",))
    forged_specs = (forged_spec, Base.tail(imit_request.specs)...)
    forged_order = imit_replace(imit_request, (specs=forged_specs,))
    @test canonical_hash(forged_order) == forged_order.request_hash
    @test_throws ArgumentError IMIT.validate_ideal_mhd_interface_traction_request(
        imit_upstream..., forged_order)

    first_sample = imit_result.samples[1]
    flipped = imit_replace(first_sample,
        (minus_outward_normal_xyz=first_sample.plus_outward_normal_xyz,
         plus_outward_normal_xyz=first_sample.minus_outward_normal_xyz))
    @test canonical_hash(flipped) == flipped.sample_hash
    forged_samples = (flipped, Base.tail(imit_result.samples)...)
    forged_result = imit_replace(imit_result, (samples=forged_samples,))
    @test canonical_hash(forged_result) == forged_result.result_hash
    @test_throws ArgumentError IMIT.validate_ideal_mhd_interface_traction_result(
        imit_upstream..., imit_request, forged_result)

    forged_authority = imit_replace(imit_result,
        (jump_conditions_validated=true,))
    @test_throws ArgumentError canonical_hash(forged_authority)
end

@testset "paired cancellation is not physical or regional closure" begin
    @test all(sample -> sample.paired_flux_defect_norm_Pa == 0.0,
        imit_result.samples)
    @test all(sample -> sample.traction_jump_residual_norm_Pa >= 0.0,
        imit_result.samples)
    for name in (:jump_conditions_validated, :regional_residual_assembled,
            :jacobian_executed, :solver_convergence_validated,
            :multiregion_closure, :physical_validation,
            :engineering_validation, :emits_evidence, :grants_pass,
            :promotion_authority, :p5_ready, :terminal_authority)
        @test !getfield(imit_result, name)
    end
    @test imit_result.credible_physical_device_count == 0
    @test imit_result.claim_ceiling == screen_only
    manifest = IMIT.ideal_mhd_interface_traction_manifest()
    @test manifest.interface_flux_executed
    @test manifest.central_pair_cancelled
    @test !manifest.jump_conditions_validated
    @test !manifest.multiregion_closure
end

println("IDEAL_MHD_INTERFACE_TRACTION_FOCUSED_EXIT_CODE=0")
