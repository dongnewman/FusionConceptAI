using Test
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "MultiRegionCouplingContracts.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "MultiRegionDiffusionProvider.jl"))
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_declared_fixture.jl"))
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_three_d_physical_provider_input.jl"))

function ready_fixture()
    c = compile_candidate(candidate, registry; mission_payload=(mission=:test,), bounds_payload=(bounds=:test,))
    ty = c.mechanism_graph.nodes[1].physical_type; reg = default_operator_registry()
    ast = TypedASTProgramV1((ASTInputV1(1,ty), ASTInputV1(2,ty),
        ASTApplyV1(OperatorRefV1("IDENTITY","v1"),(1,), (;), reg, (ty,)),
        ASTApplyV1(OperatorRefV1("IDENTITY","v1"),(2,), (;), reg, (ty,))), (3,4), (1,2), reg)
    ledger = ConservationLedgerIdentityV1(QualifiedRefV1("diffusion-test", "v1"), canonical_hash(:diffusion_test), ty.units)
    m = PortAccountEffectV1(ConservationAccountRefV1(ledger,:output,1,:minus), -1//1)
    p = PortAccountEffectV1(ConservationAccountRefV1(ledger,:output,2,:plus), 1//1)
    edge = AtomicMIMOHyperedgeV1("diffusion-interface", (MIMOInputBindingV1(1,1),MIMOInputBindingV1(2,2)),
        (MIMOOutputBindingV1(1,1),MIMOOutputBindingV1(2,2)), ast, interface; interface_flux_pairs=(InterfaceFluxPairV1(m,p),), registry=reg)
    graph = TypedOperatorHypergraphV1(c.mechanism_graph.nodes, (edge,); registry=reg)
    cc = CompiledCandidatePrefixV4(c.candidate,c.mission_payload,c.bounds_payload,c.minimality_scope,
        graph,c.field_geometry_graph,c.realization_graph,c.control_graph,c.normalized_regions,
        c.normalized_interfaces,c.normalized_boundaries,c.unresolved_nonterminals,c.capability_obligations,c.compilation_status)
    flux_binding = MultiRegionFluxBindingV4(:particle, "diffusion-interface",
        1, 2, 1, 2, ledger, ty.units)
    contract = MultiRegionCouplingContractV4(cc,
        (MultiRegionRefV4("left",(1,)),MultiRegionRefV4("right",(2,))),
        (MultiRegionInterfaceV4("contact","left","right",(:particle,), (flux_binding,)),);
        required_channels=(:particle,))
    @test validate_multiregion_coupling(contract,cc).status == :ready
    contract,cc
end

@testset "real two-region diffusion provider" begin
    contract, compiled = ready_fixture(); u = UnitSignature()
    bc = DiffusionBoundaryV4(:dirichlet, 0.0, u); br = DiffusionBoundaryV4(:dirichlet, 1.0, u)
    a = DiffusionRegionSpecV4("left", (0.0,0.5,1.0), 1.0, 0.0, u, bc, bc)
    b = DiffusionRegionSpecV4("right", (1.0,1.5,2.0), 1.0, 0.0, u, br, br)
    validation = validate_multiregion_coupling(contract,compiled)
    plan = MultiRegionCouplingPlanV4(contract,validation,(a,b),"contact",u)
    receipt = solve_multiregion_diffusion(plan)
    @test receipt.result.status == :pass
    @test receipt.result.interface_value_jump ≤ 1e-9
    @test abs(receipt.result.oriented_flux_minus-receipt.result.oriented_flux_plus) ≤ 1e-9
    @test_throws ArgumentError DiffusionRegionSpecV4("left",(0.0,1.0),1.0,0.0,u,DiffusionBoundaryV4(:dirichlet,0.0,UnitSignature((1,0,0,0,0,0,0))),bc)
    @test_throws ArgumentError MultiRegionCouplingPlanV4(contract,MultiRegionCouplingValidationV4(:ready,digest256_text("forged"),(),(:particle,)),(a,b),"contact",u)
    singular = MultiRegionCouplingPlanV4(contract,validation,
        (DiffusionRegionSpecV4("left",(0.0,0.5,1.0),1.0,1.0,u,DiffusionBoundaryV4(:neumann,0,u),DiffusionBoundaryV4(:neumann,0,u)),
         DiffusionRegionSpecV4("right",(1.0,1.5,2.0),1.0,1.0,u,DiffusionBoundaryV4(:neumann,0,u),DiffusionBoundaryV4(:neumann,0,u))),"contact",u)
    @test solve_multiregion_diffusion(singular).result.status == :numerical_fail
end

@testset "3-D context integration stays fail-closed" begin
    # The fixture is a real typed ForwardChainContextV4 from a separate
    # RuntimeV4 module. The adapter must resolve validation by concrete owner,
    # retain candidate/subject/scenario identity, and report the absent
    # composition/provider edges without running the 1-D manufactured kernel.
    integration = integrate_multiregion_context(generic_3d_context)
    @test integration.status == :deferred
    @test integration.composition_status == :absent
    @test integration.context_hash ==
        generic_3d_context.context_hash
    @test integration.candidate_hash ==
        generic_3d_context.candidate_hash
    @test integration.subject_hash ==
        generic_3d_context.subject.physical_subject_hash
    @test integration.scenario_hash ==
        generic_3d_context.scenario_hash
    @test "required_three_d_input_composition_api" in integration.gaps
    @test "required_real_multiregion_constitutive_provider" in integration.gaps
    @test integration.claim_ceiling == :screen_only
    @test canonical_hash(integration) == integration.integration_hash

    # Invalid/foreign input is rejected before any provider path is entered.
    @test_throws ArgumentError integrate_multiregion_context(nothing)
end
