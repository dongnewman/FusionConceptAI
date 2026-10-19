using Test
using Serialization
using FusionConceptAI

const _REPLAY_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
Base.include(Main, joinpath(@__DIR__, "..", "vnext_declaration_transport_local_v1_tests.jl"))
Base.include(FusionConceptAI, joinpath(_REPLAY_ROOT, "src", "Contracts", "VNextT1CanonicalBytesV2.jl"))
Base.include(FusionConceptAI, joinpath(_REPLAY_ROOT, "src", "Contracts", "VNextT1CandidateBindingV2.jl"))
Base.include(FusionConceptAI, joinpath(_REPLAY_ROOT, "src", "GenomeV5", "Integration", "VNextDeclarationAuthorityRecheckLocalV2.jl"))
Base.include(FusionConceptAI, joinpath(_REPLAY_ROOT, "src", "Contracts", "CandidateStatePackageV5NextV2.jl"))
Base.include(FusionConceptAI, joinpath(_REPLAY_ROOT, "src", "Contracts", "VNextT1PackageBindingAdapterV2.jl"))
const _REPLAY_ARTIFACT = joinpath(_REPLAY_ROOT, "docs", "implementation", "UP1-04A-VNEXT-T1", "agent_local_r7_negative_coverage", "candidate_state_package_v5_next_v2_r8.serialized")

@testset "V2 carrier replay (bounded, not independent T1 review)" begin
    payload = UInt8[0x00, 0xff, 0x10, 0x20, 0x7f]
    original = FusionConceptAI.VNextT1CanonicalBytesV2(payload)
    payload[1] = 0x55
    @test FusionConceptAI.copy_bytes(original) == UInt8[0x00, 0xff, 0x10, 0x20, 0x7f]
    io = IOBuffer(); Serialization.serialize(io, original)
    reloaded = Serialization.deserialize(IOBuffer(take!(io)))
    @test reloaded isa FusionConceptAI.VNextT1CanonicalBytesV2
    @test reloaded.sha256 == original.sha256
    @test FusionConceptAI.copy_bytes(reloaded) == FusionConceptAI.copy_bytes(original)
end

if isfile(_REPLAY_ARTIFACT)
    package = Serialization.deserialize(open(_REPLAY_ARTIFACT, "r"))
    adapter = FusionConceptAI.vnext_t1_package_binding_adapter_v2(package)
    @test adapter.input !== nothing
    binding = FusionConceptAI.vnext_t1_candidate_binding_v2(adapter.input, (adapter.input,))
    @test binding.status === :bound
    println("V2_REPLAY_STATUS=PACKAGE_RELOAD_ADAPTER_BINDING_PASS")
    println("V2_REPLAY_ARTIFACT_BYTES=", filesize(_REPLAY_ARTIFACT))
else
    error("required serialized CandidateStatePackageV5NextV2 artifact is missing")
end
