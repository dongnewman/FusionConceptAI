using Test
using SHA
using FusionConceptAI

const PB_UNIT = UnitSignature()
const PB_TYPE = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(differential_time), PB_UNIT)
const PB_CONTRACT = g1_occurrence_ownership_contract_ref("urn:fusion:phaseb")
const PB_PROFILE = CanonicalizationProfileV1("phaseb", "1", CanonicalizationBudgetV1(500_000, 50_000, 512, 8_000_000))

"""Small valid strong payload: two states, two governing MIMO edges, one closed ledger."""
function _phaseb_fixture(; contract=PB_CONTRACT, profile=PB_PROFILE,
                          registry=default_operator_registry())
    program = begin
        input = ASTInputV1(1, PB_TYPE)
        apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
            registry=registry, input_types=(PB_TYPE,))
        TypedASTProgramV1((input, apply), (2,), (1,); registry=registry)
    end
    ledger = ConservationLedgerIdentityV1(QualifiedRefV1("energy", "v1"), Digest256(repeat("0", 64)), PB_UNIT)
    account_in = PortAccountEffectV1(ConservationAccountRefV1(ledger, :input, 1, :inflow), 1 // 1)
    account_out = PortAccountEffectV1(ConservationAccountRefV1(ledger, :output, 1, :outflow), -1 // 1)
    edge_a = AtomicMIMOHyperedgeV1("site-a", (MIMOInputBindingV1(1, 1),),
        (MIMOOutputBindingV1(1, 1),), program, governing;
        account_effects=(account_in, account_out), registry=registry)
    edge_b = AtomicMIMOHyperedgeV1("site-b", (MIMOInputBindingV1(1, 2),),
        (MIMOOutputBindingV1(1, 2),), program, governing; registry=registry)
    graph = TypedOperatorHypergraphV1((node(:state, PB_TYPE; id="state-a"),
        node(:state, PB_TYPE; id="state-b")), (edge_a, edge_b); registry=registry)
    bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), PB_UNIT)
    states = (StateGeneV1(StateGeneRefV1("state-a"), PB_TYPE, bounds, (), (), (), state_derived),
        StateGeneV1(StateGeneRefV1("state-b"), PB_TYPE, bounds, (), (), (), state_derived))
    invariant = InvariantV1(InvariantRefV1("energy-invariant"), ledger,
        GlobalConservationScopeV1(), (InvariantTermV1(StateGeneRefV1("state-a"), 1),),
        (ConservationLedgerOccurrenceRefV1(OperatorSiteRefV1("site-a"), :input, 1, :inflow,
             occurrence_internal_effect, ledger),
         ConservationLedgerOccurrenceRefV1(OperatorSiteRefV1("site-a"), :output, 1, :outflow,
             occurrence_internal_effect, ledger)), 0,
        entropy_conserved)
    observable = ObservableGeneV1(ObservableRefV1("observable"),
        ProgramRootRefV1(OperatorSiteRefV1("site-a"), 1, PB_TYPE),
        QualifiedRefV1("intervention", "v1"), program, bounds, QualifiedRefV1("noise", "v1"),
        NonnegativeQuantityV1(1 // 10, PB_UNIT), NonnegativeQuantityV1(1 // 10, PB_UNIT),
        NonnegativeQuantityV1(1 // 2, PB_UNIT), (QualifiedRefV1("prediction", "v1"),))
    payload = MechanismGenomePayloadV1(states, (invariant,), graph, (), (), (observable,), ())
    payload, MechanismCanonicalizationContextV1(contract, profile),
        (registry=registry, program=program, edge_a=edge_a, edge_b=edge_b, graph=graph)
end

function _legacy_graph(; ids=("x", "y"), kinds=(:state, :state), labels=("", ""), permuted=false)
    ast = TypedAST((TypedASTNode(:state, (), PB_TYPE),
        TypedASTNode(:identity, (1,), PB_TYPE)), 2, (1,))
    edge = TypedHyperedge("legacy-edge", (1,), (2,), ast, :additive)
    ns = (node(kinds[1], PB_TYPE; id=ids[1], label=labels[1]),
        node(kinds[2], PB_TYPE; id=ids[2], label=labels[2]))
    permuted ? TypedOperatorHypergraphV1((ns[2], ns[1]),
        (TypedHyperedge("renumbered", (2,), (1,), ast, :additive),)) :
        TypedOperatorHypergraphV1(ns, (edge,))
end

function _deferred_message(f)
    try
        f()
        return nothing
    catch err
        err isa CanonicalizationDeferred || rethrow()
        return err.message
    end
end

function _legacy_migration_fixture(; ast=nothing, registry=default_operator_registry(),
                                   contract=PB_CONTRACT, declaration_contract=contract,
                                   source_invariants=nothing, declaration_invariants=nothing,
                                   extra_nodes=())
    old_ast = ast === nothing ? TypedAST((TypedASTNode(:state, (), PB_TYPE),
        TypedASTNode(:identity, (1,), PB_TYPE)), 2, (1,); registry=registry) : ast
    strong_payload, _, aux = _phaseb_fixture(; contract=contract, registry=registry)
    old_program = TypedASTProgramV1(old_ast; registry=registry)
    legacy_graph = TypedOperatorHypergraphV1((node(:state, PB_TYPE; id="state-a"),
        node(:state, PB_TYPE; id="state-b"), extra_nodes...),
        (AtomicMIMOHyperedgeV1("site-a", (MIMOInputBindingV1(1, 1),),
            (MIMOOutputBindingV1(1, 1),), old_program, governing;
            account_effects=aux.edge_a.account_effects, registry=registry),
         AtomicMIMOHyperedgeV1("site-b", (MIMOInputBindingV1(1, 2),),
            (MIMOOutputBindingV1(1, 2),), old_program, governing;
            registry=registry)))
    source = LegacyMechanismGenomeV4(7, contract, legacy_graph;
        invariants=source_invariants === nothing ? strong_payload.invariants : source_invariants,
        observables=strong_payload.observables)
    invs = declaration_invariants === nothing ? strong_payload.invariants : declaration_invariants
    declaration = G1LegacyMigrationDeclarationV1(QualifiedRefV1("mapping", "v1"), exact7_recanonicalize, declaration_contract,
        canonical_hash(source), declaration_contract, strong_payload.states, invs,
        strong_payload.parameters, strong_payload.symmetries, strong_payload.observables,
        strong_payload.operator_holes,
        (G1LegacyEdgeCompletionV1("site-a", aux.edge_a.account_effects, ()),
         G1LegacyEdgeCompletionV1("site-b", (), ())))
    source, declaration, MechanismCanonicalizationContextV1(contract, PB_PROFILE), registry
end

function _redeclare(d::G1LegacyMigrationDeclarationV1;
                    source_hash=d.source_mechanism_hash,
                    target_contract=d.target_contract_ref,
                    states=d.states, invariants=d.invariants,
                    edge_completions=d.edge_completions)
    G1LegacyMigrationDeclarationV1(d.mapping_ref, d.mode, d.source_contract_ref, source_hash, target_contract, states,
        invariants, d.parameters, d.symmetries, d.observables, d.operator_holes, edge_completions)
end

function _legacy_bijective_fixture(; edge_ids=("edge-a", "edge-b"),
                                    state_ids=("state-a", "state-b"), hole_id="hole-a")
    registry = default_operator_registry()
    ledger = ConservationLedgerIdentityV1(QualifiedRefV1("energy", "v1"), Digest256(repeat("0", 64)), PB_UNIT)
    old_ast = TypedAST((TypedASTNode(:state, (), PB_TYPE),
        TypedASTNode(:identity, (1,), PB_TYPE)), 2, (1,); registry=registry)
    old_program = TypedASTProgramV1(old_ast; registry=registry)
    effects = (PortAccountEffectV1(ConservationAccountRefV1(ledger, :input, 1, :inflow), 1 // 1),
        PortAccountEffectV1(ConservationAccountRefV1(ledger, :output, 1, :outflow), -1 // 1))
    graph = TypedOperatorHypergraphV1(
        (node(:state, PB_TYPE; id=state_ids[1]), node(:state, PB_TYPE; id=state_ids[2])),
        (AtomicMIMOHyperedgeV1(edge_ids[1], (MIMOInputBindingV1(1, 1),),
            (MIMOOutputBindingV1(1, 1),), old_program, governing;
            account_effects=effects, registry=registry),
         AtomicMIMOHyperedgeV1(edge_ids[2], (MIMOInputBindingV1(1, 2),),
            (MIMOOutputBindingV1(1, 2),), old_program, governing; registry=registry)); registry=registry)
    program = begin
        input = ASTInputV1(1, PB_TYPE)
        apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
            registry=registry, input_types=(PB_TYPE,))
        TypedASTProgramV1((input, apply), (2,), (1,); registry=registry)
    end
    bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), PB_UNIT)
    states = (StateGeneV1(StateGeneRefV1(state_ids[1]), PB_TYPE, bounds, (), (), (), state_derived),
        StateGeneV1(StateGeneRefV1(state_ids[2]), PB_TYPE, bounds, (), (), (), state_derived))
    invariant = InvariantV1(InvariantRefV1("energy-invariant"), ledger,
        GlobalConservationScopeV1(), (InvariantTermV1(StateGeneRefV1(state_ids[1]), 1),),
        (ConservationLedgerOccurrenceRefV1(OperatorSiteRefV1(edge_ids[1]), :input, 1, :inflow,
             occurrence_internal_effect, ledger),
         ConservationLedgerOccurrenceRefV1(OperatorSiteRefV1(edge_ids[1]), :output, 1, :outflow,
             occurrence_internal_effect, ledger)), 0,
        entropy_conserved)
    observable = ObservableGeneV1(ObservableRefV1("observable"),
        ProgramRootRefV1(OperatorSiteRefV1(edge_ids[1]), 1, PB_TYPE),
        QualifiedRefV1("intervention", "v1"), program, bounds, QualifiedRefV1("noise", "v1"),
        NonnegativeQuantityV1(1 // 10, PB_UNIT), NonnegativeQuantityV1(1 // 10, PB_UNIT),
        NonnegativeQuantityV1(1 // 2, PB_UNIT), (QualifiedRefV1("prediction", "v1"),))
    hole = TypedOperatorHoleV1(HoleRefV1(hole_id),
        (StateGeneRefV1(state_ids[1]),), (PB_TYPE,), QualifiedRefV1("direction", "v1"),
        (redistribution,), (interface_flux,), HoleComplexityBudgetV1(1, 0, 0, 0, 0, 1),
        QualifiedRefV1("null", "v1"), (QualifiedRefV1("alternative", "v1"),),
        (IdentifiabilityConditionV1(QualifiedRefV1("intervention", "v1"),
            ObservableRefV1("observable"), NonnegativeQuantityV1(1 // 2, PB_UNIT),
            NonnegativeQuantityV1(1 // 10, PB_UNIT)),), (ObservableRefV1("observable"),),
        (QualifiedRefV1("prediction", "v1"),))
    source = LegacyMechanismGenomeV4(7, PB_CONTRACT, graph;
        invariants=(invariant,), observables=(observable,))
    completion = (G1LegacyEdgeCompletionV1(edge_ids[1],
            (PortAccountEffectV1(ConservationAccountRefV1(ledger, :input, 1, :inflow), 1 // 1),
             PortAccountEffectV1(ConservationAccountRefV1(ledger, :output, 1, :outflow), -1 // 1)), ()),
        G1LegacyEdgeCompletionV1(edge_ids[2], (), ()))
    declaration = G1LegacyMigrationDeclarationV1(QualifiedRefV1("mapping", "v1"), exact7_recanonicalize, PB_CONTRACT,
        canonical_hash(source), PB_CONTRACT, states, (invariant,), (), (), (observable,), (hole,), completion)
    source, declaration, MechanismCanonicalizationContextV1(PB_CONTRACT, PB_PROFILE), registry
end

function _nine_node_budget_fixture()
    registry = default_operator_registry()
    nodes = ntuple(i -> node(:state, PB_TYPE; id="nine-node-$i"), 9)
    ast = TypedAST((TypedASTNode(:state, (), PB_TYPE),
        TypedASTNode(:identity, (1,), PB_TYPE)), 2, (1,); registry=registry)
    graph = TypedOperatorHypergraphV1(nodes,
        (TypedHyperedge("nine-edge-a", (1,), (1,), ast, :governing),
         TypedHyperedge("nine-edge-b", (2,), (2,), ast, :governing)); registry=registry)
    source = LegacyMechanismGenomeV4(7, PB_CONTRACT, graph)
    budget = CanonicalizationBudgetV1(1, 1, 512, 8_000_000)
    context = MechanismCanonicalizationContextV1(PB_CONTRACT,
        CanonicalizationProfileV1("phaseb-9-node-budget", "1", budget))
    source, context, registry
end

if get(ENV, "FUSION_PHASEB_CHILD", "0") == "1"
    payload, context, _ = _phaseb_fixture()
    h = mechanism_hash_layers(payload, context)
    print(join((string(getfield(h, i).value) for i in 1:8), ","))
    source, _, _, _ = _legacy_bijective_fixture()
    print("|", canonical_hash(source).value)
    source9, context9, registry9 = _nine_node_budget_fixture()
    budget_result = migrate_legacy_g1(source9, nothing, context9, registry9)
    print("|", budget_result.reason)
    print("|", FusionConceptAI._g1_layer_registry_wire(payload))
else
    @testset "4.6 Phase B strong and bridge boundaries" begin
        payload, context, aux = _phaseb_fixture()
        h = mechanism_hash_layers(payload, context)

        @testset "direct strong equivalence and explicit empty ledgers" begin
            rebuilt = MechanismGenomePayloadV1(payload.states, payload.invariants,
                payload.operator_graph, payload.parameters, payload.symmetries,
                payload.observables, payload.operator_holes)
            @test canonical_hash(payload) == canonical_hash(rebuilt)
            @test mechanism_hash_layers(payload, context) == mechanism_hash_layers(rebuilt, context)
            empty_edge = AtomicMIMOHyperedgeV1("empty-ledger", (MIMOInputBindingV1(1, 1),),
                (MIMOOutputBindingV1(1, 1),), aux.program, governing;
                account_effects=(), interface_flux_pairs=(), registry=aux.registry)
            @test empty_edge isa AtomicMIMOHyperedgeV1
            @test_throws ArgumentError AtomicMIMOHyperedgeV1("empty-interface", (MIMOInputBindingV1(1, 1),),
                (MIMOOutputBindingV1(1, 1),), aux.program, interface;
                account_effects=(), interface_flux_pairs=(), registry=aux.registry)
            source, declaration, migration_context, migration_registry = _legacy_migration_fixture()
            migrated = migrate_legacy_g1(source, declaration, migration_context, migration_registry)
            @test migrated.resolution == resolved
            @test migrated.genome isa MechanismGenomeV4
            @test migrated.genome.payload isa MechanismGenomePayloadV1
            @test migrated.genome.canonical isa CanonicalMechanismV1
            direct_genome = MechanismGenomeV4(source.seed, migration_context.contract_ref,
                migrated.genome.payload; profile=migration_context.profile)
            @test mechanism_hash(direct_genome) == mechanism_hash(migrated.genome)
            @test mechanism_subject_hash(direct_genome) == mechanism_subject_hash(migrated.genome)
            @test migrated.source_mechanism_hash == canonical_hash(source)
            @test migrated.mapping_ref == declaration.mapping_ref
            @test migrated.reason == migration_lossless
            @test migrated.declaration_content_hash == declaration.declaration_content_hash
            same_migration = migrate_legacy_g1(source, declaration, migration_context, migration_registry)
            @test (migrated.mapping_hash, mechanism_subject_hash(migrated.genome)) ==
                (same_migration.mapping_hash, mechanism_subject_hash(same_migration.genome))
            if isdefined(FusionConceptAI, :_G1LegacyMappingSeal)
                @test_throws ArgumentError FusionConceptAI.G1LegacyMigrationResultV1(
                    FusionConceptAI._G1LegacyMappingSeal(), terminal_deferred, nothing, nothing,
                    migrated.source_mechanism_hash, nothing, nothing, canonicalization_budget_exhausted)
            else
                @test !isdefined(FusionConceptAI, :_G1LegacyMappingSeal)
                @test_throws ArgumentError FusionConceptAI.G1LegacyMigrationResultV1(
                    (; forged=true), terminal_deferred, nothing, nothing,
                    migrated.source_mechanism_hash, nothing, nothing, canonicalization_budget_exhausted)
            end
            alternate_profile = CanonicalizationProfileV1("phaseb-alternate", "1", PB_PROFILE.budget)
            alternate = migrate_legacy_g1(source, declaration,
                MechanismCanonicalizationContextV1(PB_CONTRACT, alternate_profile), migration_registry)
            @test alternate.mapping_hash != migrated.mapping_hash
            @test mechanism_subject_hash(alternate.genome) != mechanism_subject_hash(migrated.genome)
            identity = operator_manifest(migration_registry, QualifiedRefV1("IDENTITY", "v1"))
            altered_identity = OperatorManifestV1(identity.operator_ref, identity.input_arity,
                identity.output_arity, identity.input_type_rule, identity.output_type_rule;
                allowed_roles=(identity.allowed_roles..., :boundary),
                parameter_schema=identity.parameter_schema, locality=identity.locality,
                max_derivative_contribution=identity.max_derivative_contribution,
                pure=identity.pure, stateful=identity.stateful, stochastic=identity.stochastic,
                event=identity.event, commutative_input_groups=identity.commutative_input_groups,
                cse_allowed=identity.cse_allowed,
                allowed_conservation_effects=identity.allowed_conservation_effects,
                forbidden_conservation_effects=identity.forbidden_conservation_effects)
            registry_variant = OperatorRegistryV1(tuple(
                altered_identity, (manifest for manifest in migration_registry.operators
                    if manifest.operator_ref != identity.operator_ref)...))
            variant_source, variant_declaration, variant_context, _ =
                _legacy_migration_fixture(registry=registry_variant)
            registry_changed = migrate_legacy_g1(variant_source, variant_declaration,
                variant_context, registry_variant)
            @test registry_changed.resolution == resolved
            @test registry_changed.mapping_hash != migrated.mapping_hash
            @test registry_changed.genome.canonical.hashes.operator_registry_hash !=
                migrated.genome.canonical.hashes.operator_registry_hash
            candidate_state = StateGeneV1(payload.states[1].state_ref, PB_TYPE,
                QuantityIntervalV1(ExactFiniteIntervalV1(-2, 2, false), PB_UNIT), (), (), (), state_derived)
            candidate_declaration = _redeclare(declaration;
                states=(candidate_state, declaration.states[2]))
            candidate_changed = migrate_legacy_g1(source, candidate_declaration,
                migration_context, migration_registry)
            @test candidate_changed.mapping_hash != migrated.mapping_hash
            @test mechanism_subject_hash(candidate_changed.genome) != mechanism_subject_hash(migrated.genome)
        end

        @testset "mixed and legacy admission" begin
            old_ast = TypedAST((TypedASTNode(:state, (), PB_TYPE),
                TypedASTNode(:identity, (1,), PB_TYPE)), 2, (1,))
            legacy = TypedHyperedge("legacy", (1,), (2,), old_ast, :additive)
            atomic = AtomicMIMOHyperedgeV1(legacy; registry=aux.registry)
            @test atomic.program isa TypedASTProgramV1
            mixed = TypedOperatorHypergraphV1(payload.operator_graph.nodes,
                (aux.edge_a, legacy); registry=aux.registry)
            @test_throws ArgumentError MechanismGenomePayloadV1(payload.states, payload.invariants,
                mixed, payload.parameters, payload.symmetries, payload.observables, payload.operator_holes)
            @test canonical_hash(_legacy_graph()) isa Digest256
            @test occursin("typed-incidence-graph", canonical_json(_legacy_graph()))
        end

        @testset "lossless-map failures defer" begin
            records = ((; missing_map=true), (; wrong_map=true), (; contract_ref=nothing),
                (; source_hash="bad"), (; opaque_legacy_gene=Any[1]),
                (; parameter=(; name=nothing)), (; constant=(; value=nothing)),
                (; manifest_mismatch=true))
            for record in records
                result = migrate_legacy(record)
                @test result.resolution == terminal_deferred
                @test result.package === nothing
                @test !isempty(result.reason)
            end
            old_missing_name = TypedAST((TypedASTNode(:state, (), PB_TYPE),
                TypedASTNode(:parameter, (), PB_TYPE), TypedASTNode(:add, (1, 2), PB_TYPE)), 3, (1,))
            @test !FusionConceptAI._g1_migration_check_legacy_ast(old_missing_name)
            old_constant_missing = TypedAST((TypedASTNode(:state, (), PB_TYPE),
                TypedASTNode(:constant, (), PB_TYPE, (scale=2,)),
                TypedASTNode(:add, (1, 2), PB_TYPE)), 3, (1,))
            @test_throws ArgumentError TypedASTProgramV1(old_constant_missing)

            function ast_migration_result(ast)
                graph = TypedOperatorHypergraphV1((node(:state, PB_TYPE; id="x"),
                    node(:state, PB_TYPE; id="y")),
                    (TypedHyperedge("legacy-edge", (1,), (2,), ast, :additive),))
                legacy_contract = GenomeContractRef("urn:fusion:legacy", "v1", repeat("a", 64), repeat("b", 64), "legacy")
                source = LegacyMechanismGenomeV4(1, legacy_contract, graph)
                declaration = G1LegacyMigrationDeclarationV1(QualifiedRefV1("mapping", "v1"), legacy9_to_exact7, legacy_contract,
                    canonical_hash(source), PB_CONTRACT, (), (), (), (), (), (),
                    (G1LegacyEdgeCompletionV1("legacy-edge", (), ()),))
                migrate_legacy_g1(source, declaration,
                    MechanismCanonicalizationContextV1(PB_CONTRACT, PB_PROFILE),
                    default_operator_registry())
            end
            @test ast_migration_result(old_missing_name).reason == legacy_ast_unrepresentable
            @test ast_migration_result(old_constant_missing).reason == legacy_ast_unrepresentable
            exact_typed = begin
                graph = TypedOperatorHypergraphV1((node(:state, PB_TYPE; id="x"), node(:state, PB_TYPE; id="y")),
                    (TypedHyperedge("legacy-edge", (1,), (2,), old_missing_name, :additive),))
                source = LegacyMechanismGenomeV4(1, PB_CONTRACT, graph)
                declaration = G1LegacyMigrationDeclarationV1(QualifiedRefV1("mapping", "v1"), exact7_recanonicalize, PB_CONTRACT,
                    canonical_hash(source), PB_CONTRACT, (), (), (), (), (), (),
                    (G1LegacyEdgeCompletionV1("legacy-edge", (), ()),))
                migrate_legacy_g1(source, declaration, MechanismCanonicalizationContextV1(PB_CONTRACT, PB_PROFILE), default_operator_registry())
            end
            @test exact_typed.reason == legacy_gene_semantics_unrepresentable
        end

        @testset "migration reason matrix and declaration closure" begin
            source, declaration, migration_context, migration_registry = _legacy_migration_fixture()
            missing_mapping = migrate_legacy_g1(source, nothing, migration_context, migration_registry)
            @test missing_mapping.reason == missing_mapping_resource
            @test missing_mapping.genome === nothing
            @test missing_mapping.mapping_hash === nothing
            wrong_hash = _redeclare(declaration; source_hash=digest256_text("wrong-source"))
            wrong_hash_result = migrate_legacy_g1(source, wrong_hash, migration_context, migration_registry)
            @test wrong_hash_result.reason == mapping_not_applicable
            @test wrong_hash_result.genome === nothing
            @test wrong_hash_result.mapping_hash === nothing
            foreign = GenomeContractRef("urn:foreign", "v1", repeat("c", 64), repeat("d", 64), "g1")
            wrong_contract = _redeclare(declaration; target_contract=foreign)
            wrong_contract_result = migrate_legacy_g1(source, wrong_contract, migration_context, migration_registry)
            @test wrong_contract_result.reason == contract_incompatible
            @test wrong_contract_result.genome === nothing
            @test wrong_contract_result.mapping_hash === nothing
            missing_completion = _redeclare(declaration; edge_completions=())
            missing_completion_result = migrate_legacy_g1(source, missing_completion, migration_context, migration_registry)
            @test missing_completion_result.reason == legacy_edge_completion_missing
            @test missing_completion_result.genome === nothing
            @test missing_completion_result.mapping_hash === nothing
            opaque_source = LegacyMechanismGenomeV4(7, PB_CONTRACT, source.graph;
                invariants=((; opaque=true),), observables=source.observables)
            opaque_declaration = _redeclare(declaration;
                source_hash=canonical_hash(opaque_source), invariants=())
            @test migrate_legacy_g1(opaque_source, opaque_declaration,
                migration_context, migration_registry).reason == legacy_gene_semantics_unrepresentable
        end

        @testset "migration alpha renaming and seed provenance" begin
            source_a, declaration_a, context_a, registry_a = _legacy_bijective_fixture()
            result_a = migrate_legacy_g1(source_a, declaration_a, context_a, registry_a)
            source_b, declaration_b, context_b, registry_b = _legacy_bijective_fixture(
                edge_ids=("z-edge", "a-edge"), state_ids=("z-state", "a-state"), hole_id="hole-z")
            result_b = migrate_legacy_g1(source_b, declaration_b, context_b, registry_b)
            @test result_a.resolution == resolved
            @test result_b.resolution == resolved
            @test result_a.mapping_hash == result_b.mapping_hash
            @test mechanism_subject_hash(result_a.genome) == mechanism_subject_hash(result_b.genome)
            @test result_a.source_mechanism_hash == canonical_hash(source_a)
            @test result_a.receipt.source_canonical_hash == result_a.source_mechanism_hash
            @test result_a.receipt.declaration_content_hash == result_a.declaration_content_hash
            @test result_a.receipt.target_subject_hash == mechanism_subject_hash(result_a.genome)
            @test result_a.receipt.target_canonical_transport_hash ==
                Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(
                    canonicalize_mechanism(result_a.genome.payload,
                        MechanismCanonicalizationContextV1(PB_CONTRACT, PB_PROFILE)).transport.canonical_bytes)))))
            source_seed, declaration_seed, context_seed, registry_seed =
                _legacy_bijective_fixture()
            source_seed = LegacyMechanismGenomeV4(999, source_seed.contract_ref, source_seed.graph;
                invariants=source_seed.invariants, observables=source_seed.observables)
            declaration_seed = _redeclare(declaration_seed;
                source_hash=canonical_hash(source_seed))
            result_seed = migrate_legacy_g1(source_seed, declaration_seed, context_seed, registry_seed)
            @test result_a.source_mechanism_hash == result_seed.source_mechanism_hash
            @test result_a.mapping_hash == result_seed.mapping_hash
        end

        @testset "constructor contradiction and dangling references" begin
            @test_throws ArgumentError LegacyMechanismGenomeV4(1, PB_CONTRACT, _legacy_graph(); invariants=(Any[1],))
            @test_throws ArgumentError MechanismGenomePayloadV1((payload.states[1], payload.states[1]),
                payload.invariants, payload.operator_graph, payload.parameters, payload.symmetries,
                payload.observables, payload.operator_holes)
            bad_unit = ConservationAccountRefV1(ConservationLedgerIdentityV1(QualifiedRefV1("energy", "v1"), Digest256(repeat("0", 64)), UnitSignature((1, 0, 0, 0, 0, 0, 0))), :input, 1, :inflow)
            @test_throws ArgumentError AtomicMIMOHyperedgeV1("bad-unit", (MIMOInputBindingV1(1, 1),),
                (MIMOOutputBindingV1(1, 1),), aux.program, governing;
                account_effects=(PortAccountEffectV1(bad_unit, 1 // 1),), registry=aux.registry)
            bad_sign = ConservationAccountRefV1(payload.invariants[1].ledger_identity, :output, 1, :outflow)
            @test_throws ArgumentError AtomicMIMOHyperedgeV1("bad-sign", (MIMOInputBindingV1(1, 1),),
                (MIMOOutputBindingV1(1, 1),), aux.program, governing;
                account_effects=(PortAccountEffectV1(bad_sign, 1 // 1),), registry=aux.registry)
            dangling = StateGeneV1(StateGeneRefV1("missing-state"), PB_TYPE,
                QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), PB_UNIT), (), (), (), state_derived)
            @test_throws ArgumentError MechanismGenomePayloadV1((dangling, payload.states[2]),
                payload.invariants, payload.operator_graph, payload.parameters, payload.symmetries,
                payload.observables, payload.operator_holes)
            @test_throws ArgumentError AtomicMIMOHyperedgeV1("duplicate-output",
                (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 1), MIMOOutputBindingV1(1, 1)),
                TypedASTProgramV1((ASTInputV1(1, PB_TYPE), ASTInputV1(2, PB_TYPE)), (1, 2), (1, 2)), additive;
                registry=aux.registry)
            @test_throws ArgumentError AtomicMIMOHyperedgeV1("closure-contradiction",
                (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 1),), aux.program, governing;
                account_effects=(aux.edge_a.account_effects[1],), registry=aux.registry)
        end

        @testset "raw and sealed dispatch" begin
            transport = canonicalize_mechanism_transport(payload, context)
            @test_throws ArgumentError CanonicalMechanismTransportV1(
                canonical_mechanism_transport_json(transport), context)
            @test_throws ArgumentError CanonicalMechanismV1(transport, h)
            @test canonical_hash(_legacy_graph()) isa Digest256
            @test_throws ArgumentError MechanismGenomePayloadV1(payload.states, payload.invariants,
                _legacy_graph(), payload.parameters, payload.symmetries, payload.observables, payload.operator_holes)
        end

        @testset "seed, label, family, unicode, and graph permutation" begin
            g = _legacy_graph(labels=("磁场🚀", "状態"), ids=("节点一", "node-two"))
            same_semantics = _legacy_graph(labels=("changed", "labels"), ids=("other-a", "other-b"))
            @test_throws MethodError mechanism_hash(LegacyMechanismGenomeV4(1, PB_CONTRACT, g))
            @test canonical_hash(LegacyMechanismGenomeV4(1, PB_CONTRACT, g)) ==
                canonical_hash(LegacyMechanismGenomeV4(999, PB_CONTRACT, same_semantics))
            @test canonical_hash(g) == canonical_hash(_legacy_graph(permuted=true))
            family = _legacy_graph(kinds=(:input, :input))
            @test canonical_hash(g) != canonical_hash(family)
        end

        @testset "ordered AST/MIMO/ledger identities" begin
            two_root_a = TypedASTProgramV1((ASTInputV1(1, PB_TYPE), ASTInputV1(2, PB_TYPE)),
                (1, 2), (1, 2); registry=aux.registry)
            two_root_b = TypedASTProgramV1(two_root_a.nodes, (2, 1), (1, 2); registry=aux.registry)
            @test canonical_hash(two_root_a) != canonical_hash(two_root_b)
            mimo_a = AtomicMIMOHyperedgeV1("mimo-a",
                (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)),
                (MIMOOutputBindingV1(1, 1), MIMOOutputBindingV1(2, 2)), two_root_a, additive;
                registry=aux.registry)
            mimo_b = AtomicMIMOHyperedgeV1("mimo-b",
                (MIMOInputBindingV1(2, 2), MIMOInputBindingV1(1, 1)),
                (MIMOOutputBindingV1(2, 2), MIMOOutputBindingV1(1, 1)), two_root_a, additive;
                registry=aux.registry)
            @test canonical_hash(mimo_a) != canonical_hash(mimo_b)
            ledger_reordered = AtomicMIMOHyperedgeV1("ledger-reordered",
                aux.edge_a.input_bindings, aux.edge_a.output_bindings, aux.program, governing;
                account_effects=Base.reverse(aux.edge_a.account_effects), registry=aux.registry)
            @test canonical_hash(aux.edge_a) != canonical_hash(ledger_reordered)
        end

        @testset "independent budget deferrals" begin
            budgets = (CanonicalizationBudgetV1(1, 50_000, 512, 8_000_000),
                CanonicalizationBudgetV1(500_000, 1, 512, 8_000_000),
                CanonicalizationBudgetV1(500_000, 50_000, 1, 8_000_000),
                CanonicalizationBudgetV1(500_000, 50_000, 512, 1))
            messages = ("layer search budget exhausted", "canonicalization refinement budget exhausted",
                "layer vertex budget exhausted", "layer wire byte budget exhausted")
            for (budget, message) in zip(budgets, messages)
                @test _deferred_message(() -> mechanism_hash_layers(payload,
                    MechanismCanonicalizationContextV1(PB_CONTRACT,
                        CanonicalizationProfileV1("phaseb", "1", budget)))) == message
            end
            source9, context9, registry9 = _nine_node_budget_fixture()
            result9 = migrate_legacy_g1(source9, nothing, context9, registry9)
            @test result9.resolution == terminal_deferred
            @test result9.reason == canonicalization_budget_exhausted
            @test result9.genome === nothing
            @test result9.mapping_hash === nothing
            @test result9.source_mechanism_hash === nothing
        end
    end

    @testset "sealed migration receipt authority" begin
        @test_throws ArgumentError G1LegacyMigrationReceiptV1(
            PB_CONTRACT, PB_CONTRACT, nothing, nothing, nothing, nothing, nothing,
            nothing, terminal_deferred, missing_mapping_resource)
    end

    @testset "4.6 helper injection and cross-process stability" begin
        julia = Base.julia_cmd()
        script = "using FusionConceptAI; const HIT=Ref{UInt8}(0); FusionConceptAI._g1_layer_rule(r::FusionConceptAI.SameTypeVariadicRuleV1)=(HIT[]=HIT[]|UInt8(0x01);\"injected\"); FusionConceptAI._canonical(n::FusionConceptAI.TypedNode)=(HIT[]=HIT[]|UInt8(0x02);\"injected-node\"); FusionConceptAI._g1_migration_closed_value(c::FusionConceptAI.GenomeContractRef)=(HIT[]=HIT[]|UInt8(0x04);\"poison\"); FusionConceptAI._g1_migration_deferred(::Nothing,::Nothing,::FusionConceptAI.G1LegacyMigrationReasonV1)=(HIT[]=HIT[]|UInt8(0x08);(resolution=FusionConceptAI.resolved,payload=nothing,canonical=nothing,source_mechanism_hash=nothing,mapping_ref=nothing,mapping_hash=nothing,declaration_content_hash=nothing,reason=FusionConceptAI.migration_lossless)); Base.isequal(a::FusionConceptAI.SameTypeVariadicRuleV1,b::FusionConceptAI.SameTypeVariadicRuleV1)=(HIT[]=HIT[]|UInt8(0x10);false); Base.hash(a::FusionConceptAI.SameTypeVariadicRuleV1,h::UInt)=(HIT[]=HIT[]|UInt8(0x20);xor(h,UInt(0x1234)))"
        # Pkg.test executes from a temporary test environment, so `.` is not
        # the package root for these fresh-process authority checks.
        package_root = Base.pkgdir(FusionConceptAI)
        test_file = joinpath(package_root, "test", "mechanism_phaseb_46_tests.jl")
        injected_script = "ENV[\"FUSION_PHASEB_CHILD\"] = \"1\"; " * script * "; include(" * repr(test_file) * "); rule = FusionConceptAI.SameTypeVariadicRuleV1(1, 1); FusionConceptAI._g1_layer_rule(rule); typed_node = FusionConceptAI.TypedNode(\"hit\", :state, FusionConceptAI.PhysicalType(:scalar_field, 0, 3, FusionConceptAI.TemporalTypeV1(FusionConceptAI.static_time), FusionConceptAI.UnitSignature()), \"\"); FusionConceptAI._canonical(typed_node); contract = FusionConceptAI.GenomeContractRef(\"urn:fusion:hit\", \"v1\", repeat(\"a\", 64), repeat(\"b\", 64), \"g1\"); FusionConceptAI._g1_migration_closed_value(contract); FusionConceptAI._g1_migration_deferred(nothing, nothing, FusionConceptAI.migration_lossless); isequal(rule, rule); hash(rule, UInt(0)); @assert HIT[] == 0x3f"
        normal_script = "ENV[\"FUSION_PHASEB_CHILD\"] = \"1\"; include(" * repr(test_file) * ")"
        injected = read(setenv(`$julia --startup-file=no --project=$package_root -e $injected_script`, "FUSION_PHASEB_CHILD" => "1"), String)
        normal = read(setenv(`$julia --startup-file=no --project=$package_root -e $normal_script`, "FUSION_PHASEB_CHILD" => "1"), String)
        @test injected == normal
        @test occursin("|", normal)
        hash_prefix = first(split(normal, '|'))
        @test length(split(hash_prefix, ',')) == 8
        @test all(length(x) == 64 for x in split(hash_prefix, ','))
        @test occursin("canonicalization_budget_exhausted", normal)
        @test occursin("manifests", normal)
    end
end
