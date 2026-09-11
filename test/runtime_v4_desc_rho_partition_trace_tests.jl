using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_desc_rho_partition_trace.jl"))

module DRPFakeBasisModule
struct DESCFieldBasisBridgeResultV4 end
validate_desc_field_basis_bridge_result(args...) = true
end

function drp_request_with(changes::NamedTuple)
    body = merge(semantic_view(drp_request), changes)
    DRP.DESCRhoPartitionRequestV4(DRP._DRP_TOKEN, values(body)...,
        canonical_hash(body))
end

function drp_trace_with(trace, changes::NamedTuple)
    body = merge(semantic_view(trace), changes)
    DRP.DESCRhoTraceSampleV4(DRP._DRP_TOKEN, values(body)...,
        canonical_hash(body))
end

@testset "candidate-bound rho partition trace specification" begin
    @test canonical_hash(drp_request) == drp_request.request_hash
    @test DRP.validate_desc_rho_partition_request(drp_upstream...,
        drp_request) === drp_request
    @test canonical_hash(drp_result.receipt) == drp_result.receipt.receipt_hash
    @test canonical_hash(drp_result) == drp_result.result_hash
    @test DRP.validate_desc_rho_partition_result(drp_upstream..., drp_request,
        drp_result) ==
        drp_result.result_hash
    replay = DRP.rerun_desc_rho_partition(drp_upstream..., drp_request,
        drp_result)
    @test replay.result_hash == drp_result.result_hash
    @test semantic_view(replay) == semantic_view(drp_result)

    @test drp_result.status === :partition_trace_specification_screened
    @test drp_request.rho_domain_lower == 0.0
    @test all(trace.rho > 0.0 for interface in drp_request.interfaces
        for trace in (interface.minus_trace..., interface.plus_trace...))
    @test drp_result.partition_structure_validated
    @test !drp_result.spatial_partition_geometry_validated
    @test drp_result.trace_sample_map_validated
    @test drp_result.declared_normal_pairing_validated
    @test !drp_result.normal_geometry_validated
    @test !drp_result.interface_trace_executed
    @test !drp_result.provider_selected && !drp_result.provider_executed
    @test !drp_result.solver_convergence_validated
    @test !drp_result.multiregion_closure
    @test !drp_result.physical_validation
    @test !drp_result.engineering_validation
    @test !drp_result.emits_evidence && !drp_result.grants_pass
    @test !drp_result.promotion_authority && !drp_result.p5_ready
    @test !drp_result.terminal_authority
    @test drp_result.credible_physical_device_count == 0
    @test drp_result.claim_ceiling == screen_only
end

@testset "rho partition identities fail closed" begin
    foreign_support = drp_request_with((physical_support_hash=
        canonical_hash((foreign=:support,)),))
    @test_throws ArgumentError canonical_hash(foreign_support)

    foreign_context = drp_request_with((context_hash=
        canonical_hash((foreign=:context,)),))
    @test_throws ArgumentError DRP.validate_desc_rho_partition_request(
        drp_upstream..., foreign_context)
    @test_throws ArgumentError DRP.screen_desc_rho_partition(drp_upstream...,
        foreign_context)

    foreign_candidate = drp_request_with((candidate_hash=
        canonical_hash((foreign=:candidate,)),))
    @test_throws ArgumentError DRP.validate_desc_rho_partition_request(
        drp_upstream..., foreign_candidate)

    truncated_cover = drp_request_with((basis_sample_hashes=
        (drp_request.basis_sample_hashes[1],),))
    @test_throws ArgumentError canonical_hash(truncated_cover)

    missing_output = joinpath(mktempdir(), "missing-basis-output.tsv")
    receipt_body = merge(DFB._dfb_receipt_process_body(dfb_result.receipt),
        (output_path=missing_output,))
    process_hash = canonical_hash(receipt_body)
    forged_receipt = DFB.DESCFieldBasisBridgeReceiptV4(
        values(receipt_body)..., process_hash,
        canonical_hash(merge(receipt_body, (process_hash=process_hash,))))
    @test canonical_hash(forged_receipt) == forged_receipt.receipt_hash
    result_values = Any[getfield(dfb_result, i)
        for i in 1:fieldcount(typeof(dfb_result))]
    result_values[findfirst(==(:receipt),
        fieldnames(typeof(dfb_result)))] = forged_receipt
    provisional = DFB.DESCFieldBasisBridgeResultV4(result_values...)
    result_values[findfirst(==(:result_hash),
        fieldnames(typeof(dfb_result)))] = canonical_hash(semantic_view(provisional))
    forged_basis_result = DFB.DESCFieldBasisBridgeResultV4(result_values...)
    @test canonical_hash(forged_basis_result) == forged_basis_result.result_hash
    forged_request = drp_request_with((
        basis_result_hash=forged_basis_result.result_hash,
        basis_receipt_hash=forged_receipt.receipt_hash))
    @test canonical_hash(forged_request) == forged_request.request_hash
    forged_upstream = (drp_upstream[1:end-1]..., forged_basis_result)
    @test_throws ArgumentError DRP.screen_desc_rho_partition(
        forged_upstream..., forged_request)

    injected_upstream = (drp_upstream[1:end-1]...,
        DRPFakeBasisModule.DESCFieldBasisBridgeResultV4())
    @test_throws ArgumentError DRP.screen_desc_rho_partition(
        injected_upstream..., drp_request)
end

@testset "rho partition geometry fails closed" begin
    gap_regions = (
        DRP.DESCRhoRegionV4("rho_inner", 0.0, 0.70,
            drp_request.physical_support_hash),
        DRP.DESCRhoRegionV4("rho_outer", 0.75, 1.0,
            drp_request.physical_support_hash))
    @test_throws ArgumentError canonical_hash(
        drp_request_with((regions=gap_regions,)))

    overlap_regions = (
        DRP.DESCRhoRegionV4("rho_inner", 0.0, 0.80,
            drp_request.physical_support_hash),
        DRP.DESCRhoRegionV4("rho_outer", 0.75, 1.0,
            drp_request.physical_support_hash))
    @test_throws ArgumentError canonical_hash(
        drp_request_with((regions=overlap_regions,)))

    duplicate_regions = (drp_regions[1], drp_regions[1])
    @test_throws ArgumentError canonical_hash(
        drp_request_with((regions=duplicate_regions,)))

    @test_throws ArgumentError DRP.DESCRhoRegionV4("negative", -0.01, 0.25,
        drp_request.physical_support_hash)
    @test_throws ArgumentError DRP.DESCRhoRegionV4("outside", 0.75, 1.01,
        drp_request.physical_support_hash)

    reversed = DRP.DESCRhoInterfaceV4("rho_interface_reversed",
        "rho_outer", "rho_inner", 0.75, drp_minus_trace, drp_plus_trace)
    @test_throws ArgumentError canonical_hash(
        drp_request_with((interfaces=(reversed,),)))
    @test_throws ArgumentError canonical_hash(
        drp_request_with((interfaces=(),)))
end

@testset "rho trace sampling and orientation fail closed" begin
    same_normal_plus = DRP.make_desc_rho_trace_sample(drp_sample, :plus,
        (1.0, 0.0, 0.0))
    @test_throws ArgumentError DRP.DESCRhoInterfaceV4("same_normal",
        "rho_inner", "rho_outer", 0.75, drp_minus_trace,
        (same_normal_plus,))

    @test_throws ArgumentError DRP.make_desc_rho_trace_sample(drp_sample,
        :minus, (2.0, 0.0, 0.0))

    changed_B = (drp_minus_trace[1].B_cartesian_xyz_T[1] + 1.0,
        drp_minus_trace[1].B_cartesian_xyz_T[2],
        drp_minus_trace[1].B_cartesian_xyz_T[3])
    changed_minus = drp_trace_with(drp_minus_trace[1],
        (B_cartesian_xyz_T=changed_B,))
    changed_plus = drp_trace_with(drp_plus_trace[1],
        (B_cartesian_xyz_T=changed_B,))
    changed_interface = DRP.DESCRhoInterfaceV4("changed_field",
        "rho_inner", "rho_outer", 0.75, (changed_minus,), (changed_plus,))
    changed_request = drp_request_with((interfaces=(changed_interface,),))
    @test canonical_hash(changed_request) == changed_request.request_hash
    @test_throws ArgumentError DRP.validate_desc_rho_partition_request(
        drp_upstream..., changed_request)

    foreign_hash = canonical_hash((foreign=:basis_sample,))
    foreign_minus = drp_trace_with(drp_minus_trace[1],
        (source_basis_sample_hash=foreign_hash,))
    foreign_plus = drp_trace_with(drp_plus_trace[1],
        (source_basis_sample_hash=foreign_hash,))
    foreign_interface = DRP.DESCRhoInterfaceV4("foreign_sample",
        "rho_inner", "rho_outer", 0.75, (foreign_minus,), (foreign_plus,))
    @test_throws ArgumentError canonical_hash(
        drp_request_with((interfaces=(foreign_interface,),)))
end

@testset "rho result cannot gain downstream authority" begin
    authority_bools = (:spatial_partition_geometry_validated,
        :normal_geometry_validated, :interface_trace_executed,
        :provider_selected, :provider_executed,
        :solver_convergence_validated, :multiregion_closure,
        :physical_validation, :engineering_validation, :emits_evidence,
        :grants_pass, :promotion_authority, :p5_ready, :terminal_authority)
    for field in authority_bools
        values = Any[getfield(drp_result, i)
            for i in 1:fieldcount(typeof(drp_result))]
        values[findfirst(==(field), fieldnames(typeof(drp_result)))] = true
        forged = DRP.DESCRhoPartitionResultV4(DRP._DRP_TOKEN, values...)
        @test_throws ArgumentError canonical_hash(forged)
    end
    values = Any[getfield(drp_result, i)
        for i in 1:fieldcount(typeof(drp_result))]
    values[findfirst(==(:credible_physical_device_count),
        fieldnames(typeof(drp_result)))] = 1
    forged = DRP.DESCRhoPartitionResultV4(DRP._DRP_TOKEN, values...)
    @test_throws ArgumentError canonical_hash(forged)

    values = Any[getfield(drp_result, i)
        for i in 1:fieldcount(typeof(drp_result))]
    values[findfirst(==(:claim_ceiling),
        fieldnames(typeof(drp_result)))] = candidate_bound
    forged = DRP.DESCRhoPartitionResultV4(DRP._DRP_TOKEN, values...)
    @test_throws ArgumentError canonical_hash(forged)
end

println("DESC_RHO_PARTITION_TRACE_FOCUSED_EXIT_CODE=0")
