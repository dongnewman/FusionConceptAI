using Test
using JSON3
using FusionConceptAI
include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_n2_source_geometry_candidate.jl"))
Base.include(TDPI, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "N2SourceDESCReplayRequestV4.jl"))

const n2sr_member_path = normpath(joinpath(@__DIR__, "..", "runs",
    "goal_recovery_20260913_012528_cst", "n2_source_member_join_r3",
    "result.json"))
const n2sr_member_sha = Digest256(
    "e379fbe4ca6ee85a4aae59029dd3109ff9b20c04d2969480e7685412925bddbf")
const n2sr_controls = TDNPRB.N2SourceDESCReplayControlsV4(
    3, 1e-8, 1e-8, 1e-8)
const n2sr_request = TDNPRB.make_n2_source_desc_replay_request(
    n2g_context, n2g_candidate_geometry_binding, n2g_binding,
    n2g_reference_binding, n2g_bridge, n2g_source_path,
    n2g_interior_path, n2sr_member_path, n2sr_member_sha,
    n2sr_controls)

@testset "N2 source replay request is exact candidate-owned input only" begin
    p = n2sr_request.payload
    @test p.schema_version == TDNPRB._N2SR_SCHEMA
    @test p.request_builder_sha256 == TDNPRB._N2SR_CODE_SHA.value
    @test p.candidate_hash == n2g_context.candidate_hash.value
    @test p.context_hash == n2g_context.context_hash.value
    @test p.physical_subject_hash ==
        n2g_context.subject.physical_subject_hash.value
    @test p.candidate_geometry_binding_hash ==
        n2g_candidate_geometry_binding.binding_hash.value
    @test p.source_artifact_sha256 == n2g_program.interior.source_artifact_sha256.value
    @test p.member_join_receipt_sha256 == n2sr_member_sha.value
    @test p.field_periods == 19
    @test p.resolution == (L=24, M=12, N=3,
        L_grid=36, M_grid=18, N_grid=6)
    @test p.source_basis.indexing == "fringe"
    @test p.surface_basis.indexing == "linear"
    @test p.profile_basis.symmetry == "even"
    @test length(p.boundary.R_modes) == 4
    @test length(p.boundary.Z_modes) == 3
    @test p.pressure_coefficients == (18000.0, 0.0, -36000.0, 0.0, 18000.0)
    @test p.iota_coefficients == (1.0, 0.0, 1.5)
    @test p.toroidal_flux_wb == 1.0
    @test p.controls.maxiter == 3 && p.controls.optimizer == "lsq-exact"
    @test p.authority.claim_ceiling == "screen_only"
    @test !p.authority.provider_executed && !p.authority.geometry_proved
    @test p.authority.physical_validation == "unsupported"
    @test p.authority.credible_device_count == 0
    @test canonical_hash(n2sr_request) == n2sr_request.request_hash
    mktempdir() do directory
        path = joinpath(directory, "request.json")
        digest = TDNPRB.write_n2_source_desc_replay_request(n2sr_request, path)
        @test digest == TDNPRB._n2sr_sha(path)
        @test JSON3.read(read(path, String)).request_hash ==
            n2sr_request.request_hash.value
        @test_throws ArgumentError TDNPRB.write_n2_source_desc_replay_request(
            n2sr_request, path)
    end
end

@testset "N2 source replay request rejects mismatched identity and controls" begin
    @test_throws ArgumentError TDNPRB.N2SourceDESCReplayControlsV4(
        0, 1e-8, 1e-8, 1e-8)
    @test_throws ArgumentError TDNPRB.N2SourceDESCReplayControlsV4(
        3, NaN, 1e-8, 1e-8)
    @test_throws ArgumentError TDNPRB.make_n2_source_desc_replay_request(
        n2g_context, n2g_candidate_geometry_binding, n2g_binding,
        n2g_reference_binding, n2g_bridge, n2g_source_path,
        n2g_interior_path, n2sr_member_path, Digest256(repeat("a",64)),
        n2sr_controls)
    @test_throws ArgumentError TDNPRB.make_n2_source_desc_replay_request(
        n2g_context, n2g_candidate_geometry_binding, n2g_binding,
        n2g_reference_binding, n2g_bridge, n2g_normalized_path,
        n2g_interior_path, n2sr_member_path, n2sr_member_sha,
        n2sr_controls)
    for promoted in (:geometry_proved, :provider_executed)
        forged_authority = merge(n2sr_request.payload.authority,
            NamedTuple{(promoted,)}((true,)))
        forged = TDNPRB.N2SourceDESCReplayRequestV4(TDNPRB._N2SR_TOKEN,
            merge(n2sr_request.payload, (authority=forged_authority,)))
        @test_throws ArgumentError canonical_hash(forged)
    end
    mktempdir() do directory
        original = JSON3.read(read(n2sr_member_path, String), Dict)
        for (field, value) in (("physical_validation", "validated"),
                ("measurement", true), ("inverse_ready", true),
                ("held_out_prediction_ready", true))
            changed = deepcopy(original)
            changed["authority"][field] = value
            forged_path = joinpath(directory, "member_$(field).json")
            write(forged_path, JSON3.write(changed))
            @test_throws ArgumentError TDNPRB.make_n2_source_desc_replay_request(
                n2g_context, n2g_candidate_geometry_binding, n2g_binding,
                n2g_reference_binding, n2g_bridge, n2g_source_path,
                n2g_interior_path, forged_path, TDNPRB._n2sr_sha(forged_path),
                n2sr_controls)
        end
    end
end
