using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "G3MaterialFieldProjectionV3", "focused_tests.jl"))
const _G3MFP4_ROOT = joinpath(@__DIR__, "..", "..", "..", "..", "src", "GenomeV5", "G3")
Base.include(FusionConceptAI, joinpath(_G3MFP4_ROOT, "G3MaterialFieldProjectionV4.jl"))

function _g3mfp4_rehash_v3(receipt::G.G3MFPProjectionReceiptV3; changes...)
    names = fieldnames(typeof(receipt))
    values = Any[getfield(receipt, name) for name in names]
    for (name, value) in pairs((; changes...))
        index = findfirst(field -> field === name, names)
        index === nothing && error("unknown V3 receipt field: " * String(name))
        values[index] = value
    end
    provisional = G.G3MFPProjectionReceiptV3(values...)
    hash_index = findfirst(field -> field === :receipt_hash, names)
    values[hash_index] = canonical_hash(G._g3mfp3_receipt_content(provisional))
    G.G3MFPProjectionReceiptV3(values...)
end

function _g3mfp4_forge_outer(upstream, status, resolution, errors)
    error_tuple = Tuple(String.(errors))
    body = G._g3mfp4_receipt_body(upstream, status, resolution, error_tuple)
    hash = canonical_hash((domain=G.G3_MFP_V4_HASH_DOMAIN, body=body))
    seal = getfield(G, :_G3MFP_PROJECTION_RECEIPT_V4_SEAL)
    G.G3MFPProjectionReceiptV4(upstream, status, resolution, error_tuple, hash, seal)
end

@testset "G3 MFP V4 sealed no-credit receipt view" begin
    receipt = G.g3_mfp_project_v4(nothing)
    validity, errors = G.g3_mfp_validate_projection_receipt_v4(receipt)
    @test validity == :valid
    @test isempty(errors)
    @test receipt.status == :terminal_deferred
    @test receipt.resolution == :terminal_deferred
    view = semantic_view(receipt)
    @test view.accepted === false
    @test view.claim_ceiling === :screen_only
    @test view.physical_status === :unknown
    @test (view.formal_up2_credit, view.formal_r_credit,
        view.discovery_credit, view.engineering_credit) == (false, false, false, false)
    @test (view.compiler_calls, view.provider_calls, view.mesh_calls,
        view.solver_calls) == (0, 0, 0, 0)
    @test view.g2_map_provenance === :opaque_unverified
    @test view.jacobian_payload_verified === false
    @test view.receipt_hash == receipt.receipt_hash
    @test !(:accepted in fieldnames(typeof(receipt)))
    @test !(:formal_up2_credit in fieldnames(typeof(receipt)))
end

@testset "G3 MFP V4 wraps the synthetic V3 screen projection" begin
    declaration, source_point, heat_witness, allocation, conductivity, _ = _g3mfp3_inputs()
    upstream = G.g3_mfp_project_v3(declaration, source_point;
        heat_endpoint_witness=heat_witness, heat_allocation=allocation,
        conductivity_selections=conductivity)
    @test upstream.status == :evaluated_screen_only
    receipt = G.g3_mfp_project_v4(declaration, source_point;
        heat_endpoint_witness=heat_witness, heat_allocation=allocation,
        conductivity_selections=conductivity)
    @test first(G.g3_mfp_validate_projection_receipt_v4(receipt)) == :valid
    view = semantic_view(receipt)
    @test view.status == :evaluated_screen_only
    @test view.resolution == :screen_only
    @test view.upstream_v3_receipt.receipt_hash == upstream.receipt_hash
    @test view.upstream_v3_receipt.content.heat_power_w == 15 // 1
    @test view.upstream_v3_receipt.content.integrated_heat_power_w == 15 // 1
    @test view.accepted === false
    @test view.physical_status === :unknown
    @test view.claim_ceiling === :screen_only
    @test view.g2_map_provenance === :opaque_unverified
    @test view.jacobian_payload_verified === false
end

@testset "G3 MFP V4 rejects the V3 public-constructor credit forgery" begin
    upstream = G.g3_mfp_project_v3(nothing)
    forged = _g3mfp4_rehash_v3(upstream; accepted=true)
    @test canonical_hash(G._g3mfp3_receipt_content(forged)) == forged.receipt_hash
    wrapped = G._g3mfp4_wrap_v3_receipt(forged)
    @test wrapped.status == :fail_closed
    @test wrapped.upstream_v3_receipt === nothing
    @test first(G.g3_mfp_validate_projection_receipt_v4(wrapped)) == :valid
    @test semantic_view(wrapped).accepted === false
    @test any(error -> occursin("accepted_flag_not_false", error), wrapped.errors)
end

@testset "G3 MFP V4 rejects stale upstream hash and invalid outer semantics" begin
    upstream = G.g3_mfp_project_v3(nothing)
    fields = Any[getfield(upstream, name) for name in fieldnames(typeof(upstream))]
    hash_index = findfirst(field -> field === :receipt_hash, fieldnames(typeof(upstream)))
    fields[hash_index] = digest256_text("tampered V3 receipt digest")
    tampered_upstream = G.G3MFPProjectionReceiptV3(fields...)
    rejected = G._g3mfp4_wrap_v3_receipt(tampered_upstream)
    @test rejected.status == :fail_closed
    @test rejected.upstream_v3_receipt === nothing
    @test first(G.g3_mfp_validate_projection_receipt_v4(rejected)) == :valid

    outer = _g3mfp4_forge_outer(upstream, :evaluated_screen_only, :screen_only, ())
    outer_validity, outer_errors = G.g3_mfp_validate_projection_receipt_v4(outer)
    @test outer_validity == :invalid
    @test "v4_status_disagrees_with_upstream" in outer_errors
    @test_throws ArgumentError semantic_view(outer)
end

@testset "G3 MFP V4 has no default fieldwise constructor" begin
    receipt = G.g3_mfp_project_v4(nothing)
    @test_throws MethodError G.G3MFPProjectionReceiptV4(receipt.upstream_v3_receipt,
        receipt.status, receipt.resolution, receipt.errors, receipt.receipt_hash)
    @test_throws ArgumentError G.G3MFPProjectionReceiptV4(receipt.upstream_v3_receipt,
        receipt.status, receipt.resolution, receipt.errors, receipt.receipt_hash,
        Ref{Nothing}(nothing))
end
