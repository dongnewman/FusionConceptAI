using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_desc_request_provider_execution.jl"))

# The DESC fixture owns its ForwardChainContext types in this module. Include
# the bridge beside those types so its contract method dispatch is exact.
Base.include(ThreeDPhysicalProviderInputRuntime,
    joinpath(@__DIR__, "..", "src", "RuntimeV4", "MultiRegionCouplingContracts.jl"))
Base.include(ThreeDPhysicalProviderInputRuntime,
    joinpath(@__DIR__, "..", "src", "RuntimeV4", "MultiRegionDiffusionProvider.jl"))
const MR = ThreeDPhysicalProviderInputRuntime

@testset "DESC context does not masquerade as multi-region readiness" begin
    compiled = dgpi_context.compiled
    @test length(compiled.mechanism_graph.nodes) >= 2
    contract = MR.MultiRegionCouplingContractV4(compiled,
        (MR.MultiRegionRefV4("left", (1,)), MR.MultiRegionRefV4("right", (2,))),
        (); required_channels=())
    @test MR.validate_multiregion_coupling(contract, compiled).status == :ready
    # Structural validator permits an empty required-channel declaration, but
    # provider admission must reject it as an invalid multi-region claim.
    @test_throws ArgumentError MR.admit_desc_multiregion_provider(dgpi_context,
        contract, dgrpe_result, dgrpe_receipt)
end

println("MULTIREGION_DESC_ADMISSION_FOCUSED_EXIT_CODE=0")
