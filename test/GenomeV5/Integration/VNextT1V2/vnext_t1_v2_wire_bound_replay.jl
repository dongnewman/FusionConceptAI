using Test
using Serialization
using FusionConceptAI

const _R11_REPLAY_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
Base.include(Main, joinpath(@__DIR__, "..", "vnext_declaration_transport_local_v1_tests.jl"))
Base.include(FusionConceptAI, joinpath(_R11_REPLAY_ROOT, "src", "Contracts", "VNextT1CanonicalBytesV2.jl"))
Base.include(FusionConceptAI, joinpath(_R11_REPLAY_ROOT, "src", "Contracts", "VNextT1CandidateBindingV2.jl"))
Base.include(FusionConceptAI, joinpath(_R11_REPLAY_ROOT, "src", "GenomeV5", "Integration", "VNextDeclarationAuthorityRecheckLocalV2.jl"))
Base.include(FusionConceptAI, joinpath(_R11_REPLAY_ROOT, "src", "Contracts", "CandidateStatePackageV5NextV2.jl"))
Base.include(FusionConceptAI, joinpath(_R11_REPLAY_ROOT, "src", "Contracts", "VNextT1PackageBindingAdapterV2.jl"))

const _R11_ARTIFACT = joinpath(_R11_REPLAY_ROOT, "docs", "implementation",
    "UP1-04A-VNEXT-T1", "agent_local_r11_wire_bound_package",
    "candidate_state_package_v5_next_v2_r11.serialized")
const _R9_ARTIFACT = joinpath(_R11_REPLAY_ROOT, "docs", "implementation",
    "UP1-04A-VNEXT-T1", "agent_local_r9_g3_shape_guard",
    "candidate_state_package_v5_next_v2_r9.serialized")
const _R8_ARTIFACT = joinpath(_R11_REPLAY_ROOT, "docs", "implementation",
    "UP1-04A-VNEXT-T1", "agent_local_r7_negative_coverage",
    "candidate_state_package_v5_next_v2_r8.serialized")

@testset "R11b fresh wire-bound replay" begin
    isfile(_R11_ARTIFACT) || error("required R11 artifact is missing")
    package = Serialization.deserialize(open(_R11_ARTIFACT, "r"))
    @test package isa FusionConceptAI.CandidateStatePackageV5NextV2
    @test FusionConceptAI.vnext_t1_package_v2_validate(package) === nothing
    adapter = FusionConceptAI.vnext_t1_package_binding_adapter_v2(package)
    @test adapter.status === :prepared_not_executed
    @test adapter.input !== nothing
    binding = FusionConceptAI.vnext_t1_candidate_binding_v2(adapter.input, (adapter.input,))
    @test binding.status === :bound
    @test binding.reason === :exact_explicit_binding
    println("R11B_REPLAY_STATUS=PACKAGE_RELOAD_ADAPTER_BINDING_PASS")
    println("R11B_REPLAY_ARTIFACT_BYTES=", filesize(_R11_ARTIFACT))
    println("R11B_REPLAY_WIRE_BYTES=", length(FusionConceptAI.copy_bytes(package.wire)))
    println("R11B_REPLAY_WIRE_SHA=", package.wire.sha256.value)
    println("R11B_REPLAY_SEMANTIC_ID=", package.semantic_identity.value)
    println("R11B_REPLAY_PACKAGE_HASH=", package.package_hash.value)

    for (label, path) in (("R9", _R9_ARTIFACT), ("R8", _R8_ARTIFACT))
        isfile(path) || error("historical $label artifact is missing")
        old = Serialization.deserialize(open(path, "r"))
        @test FusionConceptAI.vnext_t1_package_v2_validate(old) in
            (:canonicalization_version_mismatch, :profile_version_mismatch)
        rejected = FusionConceptAI.vnext_t1_package_binding_adapter_v2(old)
        @test rejected.status === :fail_closed
        @test rejected.input === nothing
        @test rejected.binding === nothing
        println("R11B_OLD_", label, "_REJECTED=", rejected.reason)
    end
end
