using Test
using LinearAlgebra

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_desc_regional_integrated_force_observation.jl"))
const R = DRIFO

@testset "regional tensor quadrature is exact and candidate-bound" begin
    @test R.canonical_hash(drifo_request) == drifo_request.request_hash
    @test length(drifo_request.region_ids) == 2
    @test length(drifo_request.nodes) == 16
    @test length(unique(node.node_hash for node in drifo_request.nodes)) == 16
    @test isapprox(sum(node.full_torus_weight for node in drifo_request.nodes),
        4pi^2; rtol=1e-14, atol=1e-14)
    regions = Dict(region.region_id => region for region in
        drstp_upstream[12].regions)
    for region_id in drifo_request.region_ids
        nodes = filter(node -> node.region_id == region_id, drifo_request.nodes)
        region = regions[region_id]
        @test length(nodes) == 8
        @test Set(node.local_index for node in nodes) ==
            Set((ir, itheta, izeta) for ir in 1:2 for itheta in 1:2 for izeta in 1:2)
        @test all(region.rho_lower < node.point.rho < region.rho_upper
            for node in nodes)
        @test all(0.0 <= node.point.theta_rad < 2pi for node in nodes)
        @test all(0.0 <= node.point.zeta_rad < 2pi / drifo_request.nfp
            for node in nodes)
        @test isapprox(sum(node.full_torus_weight for node in nodes),
            (region.rho_upper - region.rho_lower) * 4pi^2;
            rtol=1e-14, atol=1e-14)
    end
    @test R.validate_desc_regional_integrated_force_observation_request(
        imit_upstream..., imit_request, imit_result, drifo_request) ==
        drifo_request.request_hash
end

@testset "sealed provider replay and integrated-force recomputation" begin
    @test drifo_execution.field_result.receipt.exit_code == 0
    @test drifo_execution.basis_result.receipt.exit_code == 0
    @test drifo_result.receipt.output_schema_validated
    @test R.canonical_hash(drifo_result.receipt) == drifo_result.receipt.receipt_hash
    @test R.canonical_hash(drifo_result) == drifo_result.result_hash
    @test R.validate_desc_regional_integrated_force_observation_result(
        imit_upstream..., imit_request, imit_result, drifo_request,
        drifo_execution.field_request, drifo_execution.field_result,
        drifo_execution.basis_request, drifo_execution.basis_result,
        drifo_result) == drifo_result.result_hash
    @test length(drifo_result.node_observations) == 16
    @test length(drifo_result.region_observations) == 2
    for (node, spec) in zip(drifo_result.node_observations, drifo_request.nodes)
        @test node.node_hash == spec.node_hash
        @test node.region_id == spec.region_id
        @test node.local_index == spec.local_index
        @test node.weighted_force_xyz_N == ntuple(i ->
            node.F_cartesian_xyz_N_m3[i] * node.sqrt_g_m3 *
                node.full_torus_weight, 3)
    end
    for region in drifo_result.region_observations
        nodes = filter(node -> node.region_id == region.region_id,
            drifo_result.node_observations)
        @test length(nodes) == 8
        @test region.integrated_force_xyz_N == ntuple(k ->
            sum(node.weighted_force_xyz_N[k] for node in nodes), 3)
        @test region.quadrature_volume_m3 ==
            sum(node.sqrt_g_m3 * node.full_torus_weight for node in nodes)
        @test region.integrated_force_norm_N ==
            norm(collect(region.integrated_force_xyz_N))
    end
end

@testset "observation-only authority remains closed" begin
    @test drifo_result.tensor_quadrature_executed
    @test drifo_result.regional_force_integrals_observed
    @test !drifo_result.test_function_applied
    @test !drifo_result.boundary_terms_available
    @test !drifo_result.weak_form_assembled
    @test !drifo_result.regional_residual_assembled
    @test !drifo_result.jacobian_executed
    @test !drifo_result.global_conservation_validated
    @test !drifo_result.solver_convergence_validated
    @test !drifo_result.multiregion_closure
    @test !drifo_result.physical_validation
    @test !drifo_result.engineering_validation
    @test !drifo_result.emits_evidence
    @test !drifo_result.grants_pass
    @test !drifo_result.promotion_authority
    @test !drifo_result.p5_ready
    @test !drifo_result.terminal_authority
    @test drifo_result.credible_physical_device_count == 0
    @test drifo_result.claim_ceiling == screen_only
end

@testset "foreign ownership and sealed-output tampering fail closed" begin
    request_body = R.semantic_view(drifo_request)
    foreign_region_body = merge(request_body,
        (region_ids=reverse(drifo_request.region_ids),))
    foreign_region_request = R.DESCRegionalIntegratedForceObservationRequestV4(
        R._DRIFO_TOKEN, values(foreign_region_body)...,
        R.canonical_hash(foreign_region_body))
    @test R.canonical_hash(foreign_region_request) ==
        foreign_region_request.request_hash
    @test_throws ArgumentError R.validate_desc_regional_integrated_force_observation_request(
        imit_upstream..., imit_request, imit_result, foreign_region_request)

    first_node = drifo_request.nodes[1]
    other_support = drifo_request.nodes[end].region_support_hash
    foreign_support_body = merge(R.semantic_view(first_node),
        (region_support_hash=other_support,))
    foreign_support_node = R.DESCRegionalForceQuadratureNodeV4(R._DRIFO_TOKEN,
        values(foreign_support_body)..., R.canonical_hash(foreign_support_body))
    foreign_nodes = (foreign_support_node, drifo_request.nodes[2:end]...)
    foreign_support_request_body = merge(request_body, (nodes=foreign_nodes,))
    foreign_support_request = R.DESCRegionalIntegratedForceObservationRequestV4(
        R._DRIFO_TOKEN, values(foreign_support_request_body)...,
        R.canonical_hash(foreign_support_request_body))
    @test_throws ArgumentError R.validate_desc_regional_integrated_force_observation_request(
        imit_upstream..., imit_request, imit_result, foreign_support_request)

    axis_point = R.DESCFieldSamplePointV4(0.0, first_node.point.theta_rad,
        first_node.point.zeta_rad)
    axis_node_body = merge(R.semantic_view(first_node), (point=axis_point,))
    axis_node = R.DESCRegionalForceQuadratureNodeV4(R._DRIFO_TOKEN,
        values(axis_node_body)..., R.canonical_hash(axis_node_body))
    @test_throws ArgumentError R.canonical_hash(axis_node)

    mktempdir() do directory
        tampered_path = joinpath(directory, "tampered_observation.tsv")
        rows = readlines(drifo_result.receipt.output_path)
        node_index = findfirst(line -> startswith(line, "NODE\t"), rows)
        fields = split(rows[node_index], '\t'; keepempty=true)
        fields[end] = repr(parse(Float64, fields[end]) + 1.0)
        rows[node_index] = join(fields, '\t')
        write(tampered_path, join(rows, '\n') * "\n")
        receipt_body = merge(R.semantic_view(drifo_result.receipt),
            (output_path=tampered_path,
             output_sha256=R._drifo_sha256(tampered_path)))
        tampered_receipt = R.DESCRegionalIntegratedForceObservationReceiptV4(
            values(receipt_body)..., R.canonical_hash(receipt_body))
        result_names = fieldnames(typeof(drifo_result))[1:end-1]
        result_body = NamedTuple{result_names}(ntuple(i ->
            getfield(drifo_result, i), length(result_names)))
        result_body = merge(result_body, (receipt=tampered_receipt,))
        result_hash_body = merge(Base.structdiff(result_body,
            NamedTuple{(:receipt,)}),
            (receipt_hash=R.canonical_hash(tampered_receipt),))
        tampered_result = R.DESCRegionalIntegratedForceObservationResultV4(
            values(result_body)..., R.canonical_hash(result_hash_body))
        @test_throws ArgumentError R.validate_desc_regional_integrated_force_observation_result(
            imit_upstream..., imit_request, imit_result, drifo_request,
            drifo_execution.field_request, drifo_execution.field_result,
            drifo_execution.basis_request, drifo_execution.basis_result,
            tampered_result)
    end
end

println("DESC_REGIONAL_INTEGRATED_FORCE_OBSERVATION_FOCUSED_EXIT_CODE=0")
