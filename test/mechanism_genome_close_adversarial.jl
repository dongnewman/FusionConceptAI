@testset "sealed mechanism wrapper adversarial boundaries" begin
    payload_a = _wrapper_payload()
    payload_b = _wrapper_payload(account="other-account")
    canonical_a = canonicalize_mechanism(payload_a, WRAPPER_CONTRACT; profile=WRAPPER_PROFILE)
    @test_throws ArgumentError MechanismGenomeV4(UInt64(1), WRAPPER_CONTRACT, payload_b,
        canonical_a, Val(:sealed))
    @test_throws MethodError MechanismGenomeV4(UInt64(1), WRAPPER_CONTRACT, payload_a, canonical_a)
    source = read(joinpath(@__DIR__, "..", "src", "Genomes", "MechanismGenome.jl"), String)
    @test occursin("payload::MechanismGenomePayloadV1", source)
    @test occursin("canonical::CanonicalMechanismV1", source)
    formal = split(source, "struct MechanismGenomeV4", limit=2)[2]
    formal = split(formal, "function MechanismGenomeV4", limit=2)[1]
    @test !occursin("graph::TypedOperatorHypergraphV1", formal)
    @test !(:graph in fieldnames(MechanismGenomeV4))
    @test !(:invariants in fieldnames(MechanismGenomeV4))
    @test !(:observables in fieldnames(MechanismGenomeV4))
end
