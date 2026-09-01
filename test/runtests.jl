using Test
using FusionConceptAI

const U0 = UnitSignature((0, 0, 0, 0, 0, 0, 0))
const T0 = PhysicalType(:scalar_field, 0, 3, :differential, U0)

function fixture_graph(; reverse=false, labels=("alpha", "beta"), ids=("n-a", "n-b"))
    ns = [node(:state, T0; id=ids[1], label=labels[1]), node(:state, T0; id=ids[2], label=labels[2])]
    ast = ast_leaf(:state, T0)
    es = [TypedHyperedge("edge-x", (1,), (2,), ast, :governing)]
    reverse ? TypedOperatorHypergraphV1(reverse(ns), [TypedHyperedge("edge-y", (2,), (1,), ast, :governing)]) : TypedOperatorHypergraphV1(ns, es)
end

@testset "P0 contract refs and independent genome hashes" begin
    refs = [GenomeContractRef("urn:test:" * string(i), "v4.0.0", repeat(string(i), 64), repeat(string(i+1), 64), "profile-v4") for i in 1:3]
    registry = GenomeContractRegistryV4(refs...)
    @test all(!isempty, (registry.mechanism.schema_hash, registry.field_geometry.schema_hash, registry.realization_control.schema_hash))
    g = fixture_graph()
    m = MechanismGenomeV4(1, refs[1], g)
    f = FieldGeometryGenomeV4(2, refs[2], g)
    r = RealizationControlGenomeV4(3, 4, refs[3], g, g)
    @test length.( (mechanism_hash(m), field_geometry_hash(f), realization_control_hash(r)) ) == (64, 64, 64)
    @test mechanism_hash(m) == mechanism_hash(MechanismGenomeV4(999, refs[1], fixture_graph(labels=("other-a", "other-b"), ids=("z", "y"))))
    @test_throws ArgumentError GenomeContractRef("urn:x", "v4", "hash", "canon", "")
end

@testset "canonical identity/label and permutation invariance" begin
    a = fixture_graph(labels=("visible-a", "visible-b"), ids=("first", "second"))
    b = fixture_graph(labels=("redacted-a", "redacted-b"), ids=("other-1", "other-2"))
    @test canonical_hash(a) == canonical_hash(b)
    # Same directed relation after relabeling node order.
    ast = ast_leaf(:state, T0)
    c = TypedOperatorHypergraphV1([node(:state, T0; id="x"), node(:state, T0; id="y")], [TypedHyperedge("e", (2,), (1,), ast, :governing)])
    d = TypedOperatorHypergraphV1([node(:state, T0; id="y"), node(:state, T0; id="x")], [TypedHyperedge("e2", (1,), (2,), ast, :governing)])
    @test canonical_hash(c) == canonical_hash(d)
end

@testset "independent status dimensions and authority" begin
    @test StatusVectorV4(applicability=required, match_status=no_match).match_status == no_match
    @test StatusVectorV4(applicability=required, match_status=no_match).applicability == required
    @test_throws ArgumentError ApplicabilityRecord("obligation", not_applicable)
    @test IntermediateAuthorityProtocolV4(:compiler) isa AuthorityProtocolV4
    @test !(:FinalWholeDeviceAuthorityV4 in names(FusionConceptAI, all=false))
    @test !(:AuthorityToken in names(FusionConceptAI, all=false))
    @test !(:TerminalDecisionV4 in names(FusionConceptAI, all=false))
end

@testset "typed Proposal/Evidence isolation and six hashes" begin
    refs = [GenomeContractRef("urn:test:" * string(i), "v4.0.0", "s" * string(i), "c" * string(i), "profile") for i in 1:3]
    registry = GenomeContractRegistryV4(refs...)
    g = fixture_graph()
    m = MechanismGenomeV4(1, refs[1], g); f = FieldGeometryGenomeV4(2, refs[2], g); r = RealizationControlGenomeV4(3, 4, refs[3], g, g)
    p = ProposalEnvelopeV4("p", "candidate", (), :mcts, (), "cell", (;), (;), 1.0, "model", :compile)
    e = evidence_envelope(physical_subject_hash="physical", scenario_hash="scenario", solver_input_hash="solver", provider_manifest_hash="provider", backend_revision="backend", numerical_configuration_hash="numeric", applicability=required, match_status=unique_match, resolution_status=resolved, stage_outcome=unknown, metrics_with_units=(MetricWithUnit(:x, 1.0, U0),))
    mission = MissionContractRef("urn:mission", "v4", "schema", "canon")
    pkg = CandidateStatePackageV4("display", mission, m, f, r, registry; proposal_lineage=(p,), stage_evidence_refs=(EvidenceRef(e.evidence_id),))
    @test length(pkg.canonical_hashes.solver_input_hashes) == 0
    @test pkg.proposal_lineage[1] isa ProposalEnvelopeV4
    @test pkg.stage_evidence_refs[1] isa EvidenceRef
    @test canonical_hash(pkg) == canonical_hash(CandidateStatePackageV4("different-display", mission, m, f, r, registry; proposal_lineage=(p,), stage_evidence_refs=(EvidenceRef(e.evidence_id),)))
    @test_throws MethodError CandidateStatePackageV4("display", refs[1], m, f, r, registry; stage_evidence_refs=(p,))
    @test e isa EvidenceEnvelopeV4
    @test e.evidence_id == evidence_id_for(e.content)
end

@testset "conditional e-graph is P1-deferred" begin
    g = fixture_graph()
    eg = derive_conditional_egraph(g)
    @test eg.source_hash == canonical_hash(g)
    @test_throws ArgumentError derive_conditional_egraph(g, (; self_attested=true))
    @test !(:EquivalenceCertificateV1 in names(FusionConceptAI, all=false))
end

@testset "P0 negative controls and bounded large-graph canonicalization" begin
    @test occursin("\\u0001", canonical_json((control="\u0001",)))
    @test_throws ArgumentError canonical_json(Dict{Any,Any}(1 => :a, "1" => :b))
    matrix_json = canonical_json(reshape([1, 2, 3, 4], 2, 2))
    @test occursin("shape", matrix_json) && occursin("values", matrix_json)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), T0), TypedASTNode(:add, (1, 1), PhysicalType(:scalar_field, 0, 3, :differential, UnitSignature((1, 0, 0, 0, 0, 0, 0))))), 2)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), T0), TypedASTNode(:identity, (1,), PhysicalType(:vector_field, 1, 3, :differential, U0))), 2)
    refs = [GenomeContractRef("urn:test:" * string(i), "v4", "s" * string(i), "c" * string(i), "profile") for i in 1:3]
    g = fixture_graph(); r1 = RealizationControlGenomeV4(11, 12, refs[3], g, g; realization=(; basis=:a), control=(;))
    r2 = RealizationControlGenomeV4(11, 12, refs[3], g, g; realization=(; basis=:b), control=(;))
    @test realization_hash(r1) != realization_hash(r2)
    @test control_hash(r1) == control_hash(r2)
    @test coupled_realization_control_hash(r1) != coupled_realization_control_hash(r2)
    registry = GenomeContractRegistryV4(refs...)
    m = MechanismGenomeV4(1, refs[1], g); f = FieldGeometryGenomeV4(2, refs[2], g)
    foreign = GenomeContractRef("urn:foreign", "v4", "foreign", "foreign", "profile")
    rf = RealizationControlGenomeV4(3, 4, foreign, g, g)
    mission = MissionContractRef("urn:mission", "v4", "ms", "mc")
    deferred = CandidateStatePackageV4("id", mission, m, f, rf, registry)
    @test deferred.resolution == terminal_deferred
    @test migrate_legacy((; old_status=:pass)).resolution == terminal_deferred
    @test migrate_legacy((; mission_contract_ref=:m, mechanism_genome_ref=:a, field_geometry_genome_ref=:b, realization_control_genome_ref=:c, status=:pass)).resolution == terminal_deferred
    p = ProposalEnvelopeV4("p", "c", (), :search, (), "cell", (;), (;), 0.0, "model", :compile)
    @test_throws ArgumentError ProposalEnvelopeV4("p", "c", (), :search, (Any[1],), "cell", (;), (;), 0.0, "model", :compile)
    @test_throws ArgumentError MechanismGenomeV4(1, refs[1], g; invariants=(Any[1],))
    @test_throws ArgumentError FieldGeometryGenomeV4(2, refs[2], g; fields=(Dict(:mutable => true),))
    @test_throws Exception evidence_envelope(physical_subject_hash="p", scenario_hash="s", solver_input_hash="i", provider_manifest_hash="m", backend_revision="b", numerical_configuration_hash="n", applicability=required, match_status=unique_match, resolution_status=resolved, stage_outcome=unknown, metrics_with_units=(p,))
    nodes9 = [node(Symbol("kind_", i), T0; id=string(i)) for i in 1:9]
    nodes16 = [node(Symbol("kind_", i), T0; id=string(i)) for i in 1:16]
    g9 = TypedOperatorHypergraphV1(nodes9, ()); g9p = TypedOperatorHypergraphV1(reverse(nodes9), ())
    g16 = TypedOperatorHypergraphV1(nodes16, ()); g16p = TypedOperatorHypergraphV1(reverse(nodes16), ())
    t = @elapsed begin
        @test canonical_hash(g9) == canonical_hash(g9p)
        @test canonical_hash(g16) == canonical_hash(g16p)
    end
    @test t < 5.0
    cyc_nodes = [node(:same, T0; id=string(i)) for i in 1:9]
    cyc_ast = ast_leaf(:state, T0)
    cyc_edges = [TypedHyperedge("cycle-" * string(i), (i,), (mod1(i + 1, 9),), cyc_ast, :additive) for i in 1:9]
    cyc = TypedOperatorHypergraphV1(cyc_nodes, cyc_edges)
    elapsed = @elapsed @test_throws CanonicalizationDeferred canonical_hash(cyc)
    @test elapsed < 2.0
    @test_throws ArgumentError EvidenceRef("not-a-hash")
    @test_throws ArgumentError EvidenceRef(repeat("a", 64) * "0")
    @test_throws ArgumentError evidence_envelope(physical_subject_hash="p", scenario_hash="s", solver_input_hash="i", provider_manifest_hash="m", backend_revision="b", numerical_configuration_hash="n", applicability=required, match_status=no_match, resolution_status=resolved, stage_outcome=pass, metrics_with_units=(MetricWithUnit(:x, 1.0, U0),))
    @test_throws ArgumentError evidence_envelope(physical_subject_hash="p", scenario_hash="s", solver_input_hash="i", provider_manifest_hash="m", backend_revision="b", numerical_configuration_hash="n", applicability=required, match_status=no_match, resolution_status=resolved, stage_outcome=unknown, metrics_with_units=(MetricWithUnit(:x, 1.0, U0),))
    @test_throws ArgumentError evidence_envelope(physical_subject_hash="p", scenario_hash="s", solver_input_hash="i", provider_manifest_hash="m", backend_revision="b", numerical_configuration_hash="n", applicability=required, match_status=unique_match, resolution_status=resolved, stage_outcome=unknown, claim_ceiling=validation_vvuq, metrics_with_units=(MetricWithUnit(:x, 1.0, U0),))
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, CanonicalHashesV4("a", "b", "c", "d", nothing, ()), resolved, terminal_classified, (), (), (), (), (), "authority", none)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, CanonicalHashesV4("a", "b", "c", "d", nothing, ()), resolved, proposed, (), (), (), (), (), nothing, validation_vvuq)
end
