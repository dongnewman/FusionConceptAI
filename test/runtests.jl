using Test
using FusionConceptAI

const U0 = UnitSignature((0, 0, 0, 0, 0, 0, 0))
const T0 = PhysicalType(:scalar_field, 0, 3, :differential, U0)

function fixture_graph(; reverse=false, labels=("alpha", "beta"), ids=("n-a", "n-b"))
    ns = [node(:state, T0; id=ids[1], label=labels[1]), node(:state, T0; id=ids[2], label=labels[2])]
    ast = ast_leaf(:identity, T0)
    es = [TypedHyperedge("edge-x", (1,), (2,), ast, :governing)]
    reverse ? TypedOperatorHypergraphV1(reverse(ns), [TypedHyperedge("edge-y", (2,), (1,), ast, :governing)]) : TypedOperatorHypergraphV1(ns, es)
end

@testset "P0 contract refs and independent genome hashes" begin
    refs = [GenomeContractRef("urn:test:" * string(i), "v4.0.0", repeat(string(i), 64), repeat(string(i+1), 64), "profile-v4") for i in 1:3]
    registry = GenomeContractRegistryV4(refs...)
    @test all(!isempty, (registry.mechanism.schema_hash, registry.field_geometry.schema_hash, registry.realization_control.schema_hash))
    g = fixture_graph()
    m = MechanismGenomeV4(1, g)
    f = FieldGeometryGenomeV4(2, g)
    r = RealizationControlGenomeV4(3, 4, g, g)
    @test length.( (mechanism_hash(m), field_geometry_hash(f), realization_control_hash(r)) ) == (64, 64, 64)
    @test_throws ArgumentError GenomeContractRef("urn:x", "v4", "hash", "canon", "")
end

@testset "canonical identity/label and permutation invariance" begin
    a = fixture_graph(labels=("visible-a", "visible-b"), ids=("first", "second"))
    b = fixture_graph(labels=("redacted-a", "redacted-b"), ids=("other-1", "other-2"))
    @test canonical_hash(a) == canonical_hash(b)
    # Same directed relation after relabeling node order.
    ast = ast_leaf(:identity, T0)
    c = TypedOperatorHypergraphV1([node(:state, T0; id="x"), node(:state, T0; id="y")], [TypedHyperedge("e", (2,), (1,), ast, :governing)])
    d = TypedOperatorHypergraphV1([node(:state, T0; id="y"), node(:state, T0; id="x")], [TypedHyperedge("e2", (1,), (2,), ast, :governing)])
    @test canonical_hash(c) == canonical_hash(d)
end

@testset "independent status dimensions and authority" begin
    @test StatusVectorV4(applicability=required, match_status=no_match).match_status == no_match
    @test StatusVectorV4(applicability=required, match_status=no_match).applicability == required
    @test_throws ArgumentError ApplicabilityRecord("obligation", not_applicable)
    intermediate = IntermediateAuthorityV4(:compiler)
    @test_throws ArgumentError issue_authority_token(intermediate, "subject")
    final = FinalWholeDeviceAuthorityV4(:whole_device)
    token = issue_authority_token(final, "subject")
    @test emit_terminal(token, terminal_unsupported).disposition == terminal_unsupported
    @test_throws ArgumentError emit_terminal(intermediate, terminal_unsupported)
end

@testset "typed Proposal/Evidence isolation and six hashes" begin
    refs = [GenomeContractRef("urn:test:" * string(i), "v4.0.0", "s" * string(i), "c" * string(i), "profile") for i in 1:3]
    registry = GenomeContractRegistryV4(refs...)
    g = fixture_graph(); m = MechanismGenomeV4(1, g); f = FieldGeometryGenomeV4(2, g); r = RealizationControlGenomeV4(3, 4, g, g)
    p = ProposalEnvelopeV4("p", "candidate", (), :mcts, (), "cell", (;), (;), 1.0, "model", :compile)
    e = EvidenceEnvelopeV4("e", "physical", "scenario", "solver", "provider", "backend", "numeric", required, unique_match, resolved, unknown, (;))
    pkg = CandidateStatePackageV4("display", refs[1], m, f, r, registry; proposal_lineage=(p,), stage_evidence_refs=(EvidenceRef("e"),))
    @test length(pkg.canonical_hashes.solver_input_hashes) == 0
    @test pkg.proposal_lineage[1] isa ProposalEnvelopeV4
    @test pkg.stage_evidence_refs[1] isa EvidenceRef
    @test_throws MethodError CandidateStatePackageV4("display", refs[1], m, f, r, registry; stage_evidence_refs=(p,))
    @test e isa EvidenceEnvelopeV4
end

@testset "conditional e-graph is derived and proof-bound" begin
    g = fixture_graph()
    cert = EquivalenceCertificateV1("a", "b", SideConditionProof("kappa is constant", "proof-1"))
    eg = derive_conditional_egraph(g, (cert,))
    @test eg.source_hash == canonical_hash(g)
    @test_throws ArgumentError SideConditionProof("", "proof")
    @test_throws ArgumentError SideConditionProof("condition", "")
end
