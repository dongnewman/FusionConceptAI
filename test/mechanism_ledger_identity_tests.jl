using Test
using FusionConceptAI

@testset "typed conservation ledger identity" begin
    unit = UnitSignature((0 // 1, 1 // 2, 0 // 1, 0 // 1, 0 // 1, 0 // 1, 0 // 1))
    ref = QualifiedRefV1("energy", "v1")
    digest = Digest256(repeat("a", 64))
    identity = ConservationLedgerIdentityV1(ref, digest, unit)
    @test identity.account_kind_ref == ref
    @test identity.ontology_hash == digest
    @test identity.unit == unit
    @test FusionConceptAI._ledger_identity_full_key(identity) ==
        ("energy", "v1", repeat("a", 64), unit.exponents)
    @test semantic_view(identity) ==
        (account_kind_ref=ref, ontology_hash=digest, unit=unit)
    @test occursin("\"account_kind_ref\"", canonical_json(identity))
    @test occursin("\"ontology_hash\"", canonical_json(identity))
    @test occursin("\"unit\"", canonical_json(identity))
    @test canonical_hash(identity) isa Digest256
    @test_throws ArgumentError ConservationLedgerIdentityV1(ref, repeat("a", 64), unit)
    @test_throws ArgumentError ConservationLedgerIdentityV1(ref, digest, unit.exponents)
    @test_throws ArgumentError ConservationLedgerIdentityV1("energy", digest, unit)
    @test_throws MethodError ConservationAccountRefV1("energy", unit, :input, 1, :inflow)
    account = ConservationAccountRefV1(identity, :input, 1, :inflow)
    @test account.ledger_identity === identity
    @test account.port_side === :input && account.port_index == 1
    @test semantic_view(account).ledger_identity === identity
end
