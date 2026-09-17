using Test
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "MultiRegionCouplingContracts.jl"))
module RuntimeV4MultiRegionFixture
    using FusionConceptAI
    include(joinpath(@__DIR__, "..", "examples", "runtime_v4_declared_fixture.jl"))
end

@testset "RuntimeV4 multi-region coupling contract" begin
    # This fixture is synthetic and tests declarations only; it is not physical evidence.
    ty = PhysicalType(:scalar, 0, 0, :differential, UnitSignature((0,0,0,0,0,0,0)))
    n1, n2 = node(:state, ty; id="r1"), node(:state, ty; id="r2")
    ast = TypedASTProgramV1((ASTInputV1(1, ty), ASTInputV1(2, ty),
        ASTApplyV1(OperatorRefV1("SUB", "v1"), (1,2), (;), default_operator_registry(), (ty,ty)),
        ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;), default_operator_registry(), (ty,))), (3,4), (1,2), default_operator_registry())
    l = ConservationLedgerIdentityV1(QualifiedRefV1("test", "v1"), canonical_hash(:test), ty.units)
    m = PortAccountEffectV1(ConservationAccountRefV1(l, :output, 1, :minus), -1//1)
    p = PortAccountEffectV1(ConservationAccountRefV1(l, :output, 2, :plus), 1//1)
    pair = InterfaceFluxPairV1(m, p)
    edge = AtomicMIMOHyperedgeV1("if-1", (MIMOInputBindingV1(1,1), MIMOInputBindingV1(2,2)),
        (MIMOOutputBindingV1(1,1), MIMOOutputBindingV1(2,2)), ast, interface; interface_flux_pairs=(pair,))
    graph = TypedOperatorHypergraphV1((n1,n2), (edge,))
    @test_throws ArgumentError MultiRegionInterfaceV4("i", "a", "b", (:bad,), ("if-1",))
    # Contract binding is tested with a minimal compiled-like object only through field identity.
    @test edge.role === interface
    @test !isempty(edge.interface_flux_pairs)
    @test canonical_hash(graph) == canonical_hash(graph)

    # Candidate-bound validation against the real typed compiler fixture.
    compiled = compile_candidate(RuntimeV4MultiRegionFixture.candidate, RuntimeV4MultiRegionFixture.registry;
        mission_payload=(mission=:test,), bounds_payload=(bounds=:test,))
    contract = MultiRegionCouplingContractV4(compiled,
        (MultiRegionRefV4("r-a", (1,)), MultiRegionRefV4("r-b", (2,))),
        (MultiRegionInterfaceV4("i-1", "r-a", "r-b", (:particle,),
            (MultiRegionFluxBindingV4(:particle, "runtime-site-a", 1, 2, 1, 1, canonical_hash(:missing), canonical_hash(ty.units)),)),);
        required_channels=(:particle,))
    result = validate_multiregion_coupling(contract, compiled)
    @test result.status == :deferred
    @test any(contains(g, "not_interface_role") for g in result.gaps)
    @test contract.claim_ceiling == :screen_only
end
