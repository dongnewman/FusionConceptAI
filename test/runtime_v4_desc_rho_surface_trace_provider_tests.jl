using Test
using FusionConceptAI
using LinearAlgebra

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_desc_rho_surface_trace_provider.jl"))

module DRSTPFakePartitionModule
struct DESCRhoPartitionResultV4 end
validate_desc_rho_partition_result(args...) = true
end

function drstp_request_with(changes::NamedTuple)
    body = merge(semantic_view(drstp_request), changes)
    DRSTP.DESCRhoSurfaceTraceProviderRequestV4(DRSTP._DRSTP_TOKEN,
        values(body)..., canonical_hash(body))
end

function drstp_result_with(changes::NamedTuple)
    names = fieldnames(typeof(drstp_result))[1:end-2]
    body_changes = Base.structdiff(changes, NamedTuple{(:receipt,)})
    body = merge(NamedTuple{names}(ntuple(i -> getfield(drstp_result, i),
        length(names))), body_changes)
    receipt = get(changes, :receipt, drstp_result.receipt)
    hash_body = merge(body, (receipt_hash=canonical_hash(receipt),))
    DRSTP.DESCRhoSurfaceTraceProviderResultV4(values(body)..., receipt,
        canonical_hash(hash_body))
end

function drstp_receipt_with(changes::NamedTuple)
    names = fieldnames(typeof(drstp_receipt))[1:end-2]
    process_body = merge(NamedTuple{names}(ntuple(i ->
        getfield(drstp_receipt, i), length(names))), changes)
    process_hash = canonical_hash(process_body)
    body = merge(process_body, (process_hash=process_hash,))
    DRSTP.DESCRhoSurfaceTraceProviderReceiptV4(values(body)...,
        canonical_hash(body))
end

@testset "real candidate-bound DESC rho surface trace provider" begin
    @test canonical_hash(drstp_request) == drstp_request.request_hash
    @test DRSTP.validate_desc_rho_surface_trace_provider_request(
        drstp_upstream..., drstp_request) === drstp_request
    @test canonical_hash(drstp_receipt) == drstp_receipt.receipt_hash
    @test DRSTP.validate_desc_rho_surface_trace_provider_receipt(
        drstp_receipt)
    @test canonical_hash(drstp_result) == drstp_result.result_hash
    @test DRSTP.validate_desc_rho_surface_trace_provider_result(
        drstp_upstream..., drstp_request, drstp_result) ==
        drstp_result.result_hash
    @test drstp_result.desc_version == "0.17.3"
    @test drstp_result.nfp == dgrpe_request.runner_payload.nfp
    @test drstp_request.nfp == drstp_result.nfp
    @test length(drstp_result.samples) == length(drstp_request.samples)
    @test drstp_receipt.upstream_hdf5_sha256 ==
        drstp_request.equilibrium_output_sha256

    @test drstp_result.provider_selected && drstp_result.provider_executed
    @test drstp_result.output_schema_validated
    @test drstp_result.surface_geometry_sampled
    @test drstp_result.normal_geometry_validated
    @test drstp_result.tangent_geometry_validated
    @test drstp_result.two_sided_trace_executed
    @test drstp_result.region_ownership_validated
    @test !drstp_result.declared_normals_cross_checked

    for sample in drstp_result.samples
        @test sample.minus_rho == sample.rho_level - sample.epsilon_rho
        @test sample.plus_rho == sample.rho_level + sample.epsilon_rho
        @test sample.minus_position_xyz_m != sample.plus_position_xyz_m
        @test isapprox(norm(collect(sample.minus_outward_normal_xyz)), 1.0;
            atol=DRSTP._DRSTP_NORMAL_ATOL,
            rtol=DRSTP._DRSTP_NORMAL_ATOL)
        @test all(isapprox(sample.minus_outward_normal_xyz[i],
            -sample.plus_outward_normal_xyz[i];
            atol=DRSTP._DRSTP_NORMAL_ATOL,
            rtol=DRSTP._DRSTP_NORMAL_ATOL) for i in 1:3)
        @test sample.normal_grad_alignment >=
            1.0 - DRSTP._DRSTP_NORMAL_ATOL
        @test sample.tangent_normal_max_abs_dot <= 5.0e-8
        @test all(isfinite, (sample.minus_B_xyz_T...,
            sample.plus_B_xyz_T..., sample.minus_F_xyz_N_m3...,
            sample.plus_F_xyz_N_m3...))
    end
end

@testset "rho surface provider identity and replay fail closed" begin
    foreign_candidate = drstp_request_with((candidate_hash=
        canonical_hash((foreign=:candidate,)),))
    @test_throws ArgumentError DRSTP.validate_desc_rho_surface_trace_provider_request(
            drstp_upstream..., foreign_candidate)

    foreign_hdf5 = drstp_request_with((equilibrium_output_sha256=
        canonical_hash((foreign=:hdf5,)),))
    @test_throws ArgumentError DRSTP.validate_desc_rho_surface_trace_provider_request(
            drstp_upstream..., foreign_hdf5)

    @test_throws ArgumentError DRSTP.make_desc_rho_surface_trace_provider_request(
            drstp_upstream...; epsilon_rho=0.75)

    injected_upstream = (drstp_upstream[1:end-1]...,
        DRSTPFakePartitionModule.DESCRhoPartitionResultV4())
    @test_throws ArgumentError DRSTP.make_desc_rho_surface_trace_provider_request(
            injected_upstream...; epsilon_rho=1.0e-3)

    spec = only(drstp_request.samples)
    spec_body = merge(semantic_view(spec),
        (zeta_rad=2pi / drstp_request.nfp,))
    seam_spec = DRSTP.DESCRhoSurfaceTraceSampleSpecV4(DRSTP._DRSTP_TOKEN,
        values(spec_body)..., canonical_hash(spec_body))
    request_body = merge(semantic_view(drstp_request),
        (samples=(seam_spec,),))
    seam_request = DRSTP.DESCRhoSurfaceTraceProviderRequestV4(
        DRSTP._DRSTP_TOKEN, values(request_body)...,
        canonical_hash(request_body))
    @test_throws ArgumentError canonical_hash(seam_request)

    replay = DRSTP.rerun_desc_rho_surface_trace_provider(
        drstp_upstream..., drstp_request, drstp_result;
        run_dir=drstp_run_dir)
    @test replay.result_hash == drstp_result.result_hash
    @test semantic_view(replay) == semantic_view(drstp_result)
end

@testset "rho surface provider artifacts and geometry fail closed" begin
    missing_output = joinpath(mktempdir(), "missing-output.tsv")
    receipt_body = merge(semantic_view(drstp_receipt),
        (output_path=missing_output,))
    forged_receipt = DRSTP.DESCRhoSurfaceTraceProviderReceiptV4(
        values(receipt_body)..., canonical_hash(receipt_body))
    @test canonical_hash(forged_receipt) == forged_receipt.receipt_hash
    @test_throws ArgumentError DRSTP.validate_desc_rho_surface_trace_provider_receipt(forged_receipt)
    forged_result = drstp_result_with((receipt=forged_receipt,))
    @test_throws ArgumentError DRSTP.validate_desc_rho_surface_trace_provider_result(
            drstp_upstream..., drstp_request, forged_result)

    tampered_adapter_dir = mktempdir()
    tampered_adapter_path = joinpath(tampered_adapter_dir,
        "tampered_adapter.py")
    open(tampered_adapter_path, "w") do io
        write(io, DRSTP._DRSTP_ADAPTER_SOURCE * "\n# tampered\n")
    end
    tampered_adapter_receipt = drstp_receipt_with((
        adapter_path=tampered_adapter_path,
        adapter_source_sha256=DRSTP._drstp_sha256(tampered_adapter_path)))
    @test_throws ArgumentError DRSTP.validate_desc_rho_surface_trace_provider_receipt(
            tampered_adapter_receipt)

    foreign_desc_receipt = drstp_receipt_with((
        desc_module_path=drstp_receipt.adapter_path,
        desc_module_sha256=drstp_receipt.adapter_source_sha256))
    @test DRSTP.validate_desc_rho_surface_trace_provider_receipt(
        foreign_desc_receipt)
    foreign_desc_result = drstp_result_with((receipt=foreign_desc_receipt,))
    @test_throws ArgumentError DRSTP.validate_desc_rho_surface_trace_provider_result(
        drstp_upstream..., drstp_request, foreign_desc_result)

    duplicate_header_path = joinpath(mktempdir(), "duplicate-header.tsv")
    duplicate_lines = readlines(drstp_receipt.output_path)
    duplicate_lines[3] = replace(duplicate_lines[3],
        "CONTEXT_HASH" => "REQUEST_HASH")
    open(duplicate_header_path, "w") do io
        write(io, join(duplicate_lines, '\n') * "\n")
    end
    @test_throws ArgumentError DRSTP._drstp_parse_output(
        duplicate_header_path, drstp_request)

    wrong_theta_path = joinpath(mktempdir(), "wrong-theta.tsv")
    wrong_theta_lines = readlines(drstp_receipt.output_path)
    sample_columns = split(wrong_theta_lines[11], '\t')
    sample_columns[11] = repr(drstp_request.samples[1].theta_rad + 0.01)
    wrong_theta_lines[11] = join(sample_columns, '\t')
    open(wrong_theta_path, "w") do io
        write(io, join(wrong_theta_lines, '\n') * "\n")
    end
    @test_throws ArgumentError DRSTP._drstp_parse_output(
        wrong_theta_path, drstp_request)

    sample = only(drstp_result.samples)
    names = fieldnames(typeof(sample))[1:end-1]
    body = NamedTuple{names}(ntuple(i -> getfield(sample, i), length(names)))
    bad_body = merge(body, (plus_outward_normal_xyz=
        sample.minus_outward_normal_xyz,))
    bad_sample = DRSTP.DESCRhoSurfaceTraceProviderSampleV4(
        values(bad_body)..., canonical_hash(bad_body))
    @test_throws ArgumentError canonical_hash(bad_sample)
end

@testset "rho surface provider cannot gain downstream authority" begin
    for field in (:spatial_partition_geometry_validated,
            :interface_flux_executed, :solver_convergence_validated,
            :multiregion_closure, :physical_validation,
            :engineering_validation, :emits_evidence, :grants_pass,
            :promotion_authority, :p5_ready, :terminal_authority)
        forged = drstp_result_with(NamedTuple{(field,)}((true,)))
        @test_throws ArgumentError canonical_hash(forged)
    end
    @test_throws ArgumentError canonical_hash(
        drstp_result_with((credible_physical_device_count=1,)))
    @test_throws ArgumentError canonical_hash(
        drstp_result_with((claim_ceiling=candidate_bound,)))
end

println("DESC_RHO_SURFACE_TRACE_PROVIDER_FOCUSED_EXIT_CODE=0")
