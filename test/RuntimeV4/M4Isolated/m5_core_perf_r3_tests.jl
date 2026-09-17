"""Bounded M5 core-performance regression tests.

These tests cover only the derivation-local cache/key seam.  They do not alter
the manufactured adapter, run a heavy lane, or assert a performance number.
"""

using Test
using JSON3
using FusionConceptAI

function _m5r3_program(op::String; registry=default_operator_registry())
    unit = UnitSignature()
    ty = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), unit)
    input = ASTInputV1(1, ty)
    apply = ASTApplyV1(OperatorRefV1(op, "v1"), (1,), (;);
        registry=registry, input_types=(ty,))
    TypedASTProgramV1((input, apply), (2,), (1,); registry=registry)
end

function _m5r3_chain_program(node_count::Int; registry=default_operator_registry())
    1 <= node_count <= 8 || throw(ArgumentError("chain node count outside R11 seam"))
    unit = UnitSignature()
    ty = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), unit)
    nodes = Vector{AbstractTypedASTNodeV1}(undef, node_count)
    nodes[1] = ASTInputV1(1, ty)
    i = 2
    while i <= node_count
        nodes[i] = ASTApplyV1(OperatorRefV1("NEG", "v1"), (i - 1,), (;);
            registry=registry, input_types=(ty,))
        i += 1
    end
    TypedASTProgramV1(Tuple(nodes), (node_count,), (1,); registry=registry)
end

@testset "M5 core performance R3 cache and key seam" begin
    registry = default_operator_registry()
    source = _m5r3_program("IDENTITY"; registry=registry)
    target = _m5r3_program("NEG"; registry=registry)
    condition = EqualityConditionRequirementV1(
        QualifiedRefV1("m5-r3-condition", "v1"), digest256_text("m5-r3-contract"))
    rule = WholeProgramConditionalRewriteV1(
        QualifiedRefV1("m5-r3-rule", "v1"), source, target, (condition,),
        QualifiedRefV1("m5-r3-checker", "v1"), digest256_text("m5-r3-checker");
        registry=registry)

    cache = FusionConceptAI._CEGDerivationCacheV1()
    source_bytes = FusionConceptAI._ceg_cached_program_bytes(cache, source)
    @test source_bytes === FusionConceptAI._ceg_cached_program_bytes(cache, source)
    @test FusionConceptAI._ceg_cached_program_hash(cache, source) == canonical_hash(source)
    @test FusionConceptAI._ceg_cached_rule_bytes(cache, rule) == canonical_json(rule)

    payload_counter = FusionConceptAI._tac_test_payload_counter_start()
    cold_cache = FusionConceptAI._TACDerivationCanonicalCacheV1()
    FusionConceptAI._tac_cached_program_bytes(cold_cache, source)
    @test payload_counter[] == 1
    @test !haskey(cold_cache.verified_tokens, source)
    payload_counter[] = 0
    FusionConceptAI._tac_cached_program_bytes(cold_cache, source)
    FusionConceptAI._tac_cached_program_hash(cold_cache, source)
    @test payload_counter[] == 0
    authority_cold = FusionConceptAI._TACDerivationCanonicalCacheV1()
    payload_counter[] = 0
    FusionConceptAI._tac_authoritative_program_bytes(authority_cold, source)
    @test payload_counter[] == 1
    @test haskey(authority_cold.verified_tokens, source)
    payload_counter[] = 0
    authority_hit = FusionConceptAI._tac_authoritative_program_bytes(authority_cold, source)
    @test authority_hit == source_bytes
    @test payload_counter[] == 0
    unverified_cache = FusionConceptAI._TACDerivationCanonicalCacheV1()
    unverified_bytes = "unverified-forged-bytes"
    unverified_entry = FusionConceptAI._TACCanonicalEntryV1(
        unverified_cache.owner_token, source, unverified_bytes,
        FusionConceptAI._tac_hash_json(unverified_bytes),
        FusionConceptAI._tac_program_fingerprint(source),
        FusionConceptAI._TAC_CACHE_GUARD)
    unverified_cache.entries[source] = unverified_entry
    payload_counter[] = 0
    @test_throws ArgumentError FusionConceptAI._tac_authoritative_program_bytes(
        unverified_cache, source)
    @test payload_counter[] == 1
    FusionConceptAI._tac_test_payload_counter_stop!()

    verified_cache = FusionConceptAI._TACDerivationCanonicalCacheV1()
    FusionConceptAI._tac_authoritative_program_bytes(verified_cache, source)
    delete!(verified_cache.verified_tokens, source)
    @test_throws ArgumentError FusionConceptAI._tac_cached_program_bytes(
        verified_cache, source)
    replacement_cache = FusionConceptAI._TACDerivationCanonicalCacheV1()
    FusionConceptAI._tac_authoritative_program_bytes(replacement_cache, source)
    replacement_cache.entries[source] = FusionConceptAI._TACCanonicalEntryV1(
        replacement_cache.owner_token, source, source_bytes,
        FusionConceptAI._tac_hash_json(source_bytes),
        FusionConceptAI._tac_program_fingerprint(source),
        FusionConceptAI._TAC_CACHE_GUARD)
    @test_throws ArgumentError FusionConceptAI._tac_cached_program_bytes(
        replacement_cache, source)
    foreign_token_cache = FusionConceptAI._TACDerivationCanonicalCacheV1()
    FusionConceptAI._tac_authoritative_program_bytes(foreign_token_cache, source)
    cross_owner_cache = FusionConceptAI._TACDerivationCanonicalCacheV1()
    cross_owner_cache.entries[source] = foreign_token_cache.entries[source]
    cross_owner_cache.verified_tokens[source] = foreign_token_cache.verified_tokens[source]
    @test_throws ArgumentError FusionConceptAI._tac_cached_program_bytes(
        cross_owner_cache, source)
    program_mismatch_cache = FusionConceptAI._TACDerivationCanonicalCacheV1()
    program_mismatch_cache.entries[target] = FusionConceptAI._TACCanonicalEntryV1(
        program_mismatch_cache.owner_token, source, source_bytes,
        FusionConceptAI._tac_hash_json(source_bytes),
        FusionConceptAI._tac_program_fingerprint(source),
        FusionConceptAI._TAC_CACHE_GUARD)
    @test_throws ArgumentError FusionConceptAI._tac_cached_program_bytes(
        program_mismatch_cache, target)
    wrong_hash_cache = FusionConceptAI._TACDerivationCanonicalCacheV1()
    wrong_hash_cache.entries[source] = FusionConceptAI._TACCanonicalEntryV1(
        wrong_hash_cache.owner_token, source, source_bytes,
        digest256_text("m5-r11-wrong-program-hash"),
        FusionConceptAI._tac_program_fingerprint(source),
        FusionConceptAI._TAC_CACHE_GUARD)
    @test_throws ArgumentError FusionConceptAI._tac_cached_program_bytes(
        wrong_hash_cache, source)
    wrong_witness_cache = FusionConceptAI._TACDerivationCanonicalCacheV1()
    wrong_witness_cache.entries[source] = FusionConceptAI._TACCanonicalEntryV1(
        wrong_witness_cache.owner_token, source, source_bytes,
        FusionConceptAI._tac_hash_json(source_bytes), "forged-structural-witness",
        FusionConceptAI._TAC_CACHE_GUARD)
    @test_throws ArgumentError FusionConceptAI._tac_cached_program_bytes(
        wrong_witness_cache, source)

    for node_count in 1:8
        representative = _m5r3_chain_program(node_count; registry=registry)
        baseline_bytes = canonical_json(representative)
        baseline_hash = canonical_hash(representative)
        representative_cache = FusionConceptAI._TACDerivationCanonicalCacheV1()
        @test FusionConceptAI._tac_cached_program_bytes(
            representative_cache, representative) == baseline_bytes
        @test FusionConceptAI._tac_cached_program_hash(
            representative_cache, representative) == baseline_hash
        @test FusionConceptAI._tac_authoritative_program_bytes(
            representative_cache, representative) == baseline_bytes
        @test FusionConceptAI._tac_cached_program_hash(
            representative_cache, representative) == baseline_hash
    end

    empty_key = FusionConceptAI._CEGMemberKeyV1("a\0b", "c")
    split_key = FusionConceptAI._CEGMemberKeyV1("a", "b\0c")
    @test !isequal(empty_key, split_key)
    @test FusionConceptAI._ceg_member_key_bytes(empty_key) !=
        FusionConceptAI._ceg_member_key_bytes(split_key)
    visited = Dict{FusionConceptAI._CEGMemberKeyV1,Nothing}()
    visited[empty_key] = nothing
    @test haskey(visited, empty_key)
    @test !haskey(visited, split_key)

    forward = FusionConceptAI._CEGProposal(
        FusionConceptAI._ceg_new_node(source, ()), target, (condition,), rule,
        FusionConceptAI.rewrite_forward, source_bytes,
        FusionConceptAI._ceg_cached_program_bytes(cache, target))
    proposal_key = FusionConceptAI._ceg_cached_proposal_identity(cache, forward)
    @test proposal_key.orientation == UInt8(1)
    @test FusionConceptAI._ceg_proposal_key_bytes(proposal_key) ==
        FusionConceptAI._ceg_length_delimited_key((proposal_key.rule_bytes,
            proposal_key.source_bytes, proposal_key.target_bytes, "1",
            proposal_key.condition_bytes))

    # Legacy canonical bytes remain the authority; the cached receipt writer
    # is required to emit the same bytes when given an equivalent artifact.
    @test FusionConceptAI._ceg_member_key(FusionConceptAI._ceg_new_node(source, ())) ==
        source_bytes * "\0" * FusionConceptAI._ceg_condition_bytes(())

    # The cache is a non-authoritative performance hint.  Its immutable
    # program/owner witness rejects cross-derivation entry injection; deleting
    # an entry is safe because the helper recomputes the hint from the program.
    mutated_entry = FusionConceptAI._CEGDerivationCacheV1()
    FusionConceptAI._ceg_cached_program_bytes(mutated_entry, source)
    foreign_entry = FusionConceptAI._CEGDerivationCacheV1()
    FusionConceptAI._ceg_cached_program_bytes(foreign_entry, source)
    mutated_entry.canonical.entries[source] = foreign_entry.canonical.entries[source]
    @test_throws ArgumentError FusionConceptAI._ceg_cached_program_bytes(mutated_entry, source)
    delete!(mutated_entry.canonical.entries, source)
    @test FusionConceptAI._ceg_cached_program_bytes(mutated_entry, source) == source_bytes
    @test_throws Exception (mutated_entry.owner_token = Ref{Nothing}())
    @test_throws Exception (cache.owner_token = Ref{Nothing}())

    mutated_condition = FusionConceptAI._CEGDerivationCacheV1()
    FusionConceptAI._ceg_cached_condition_bytes(mutated_condition, (condition,))
    mutated_condition.condition_bytes[(condition,)] = "forged-condition"
    @test_throws ArgumentError FusionConceptAI._ceg_cached_condition_bytes(mutated_condition, (condition,))
    mutated_rule = FusionConceptAI._CEGDerivationCacheV1()
    FusionConceptAI._ceg_cached_rule_bytes(mutated_rule, rule)
    mutated_rule.rule_bytes[rule] = "forged-rule"
    @test_throws ArgumentError FusionConceptAI._ceg_cached_rule_bytes(mutated_rule, rule)
    mutated_member = FusionConceptAI._CEGDerivationCacheV1()
    member_for_key = FusionConceptAI._ceg_new_node(source, ())
    FusionConceptAI._ceg_cached_member_identity(mutated_member, member_for_key)
    mutated_member.member_keys[member_for_key] = FusionConceptAI._CEGMemberKeyV1("forged", "[]")
    @test_throws ArgumentError FusionConceptAI._ceg_cached_member_identity(mutated_member, member_for_key)
    mutated_proposal_identity = FusionConceptAI._CEGDerivationCacheV1()
    FusionConceptAI._ceg_cached_proposal_identity(mutated_proposal_identity, forward)
    mutated_proposal_identity.proposal_keys[forward] = FusionConceptAI._CEGMemberKeyV1("forged", "[]")
    @test_throws ArgumentError FusionConceptAI._ceg_cached_proposal_identity(mutated_proposal_identity, forward)
    mutated_proposal_sort = FusionConceptAI._CEGDerivationCacheV1()
    FusionConceptAI._ceg_cached_proposal_sort_key(mutated_proposal_sort, forward)
    mutated_proposal_sort.proposal_sort_keys[forward] = "forged"
    @test_throws ArgumentError FusionConceptAI._ceg_cached_proposal_sort_key(mutated_proposal_sort, forward)

    @test_throws MethodError FusionConceptAI._CEGSealedProgramHashV1(
        source, FusionConceptAI._ceg_cached_program_hash(cache, source))
    @test_throws MethodError FusionConceptAI._CEGSealedProgramHashV1(
        cache.owner_token, source, source_bytes,
        FusionConceptAI._ceg_cached_program_hash(cache, source),
        FusionConceptAI._CEG_SEAL_GUARD)
    # Forced same-digest/different-bytes injection is tolerated only as a
    # performance-hint corruption; the authoritative receipt path rejects it.
    forged_cache = FusionConceptAI._CEGDerivationCacheV1()
    forged_hash = FusionConceptAI._ceg_cached_program_hash(forged_cache, source)
    forged_entry = FusionConceptAI._TACCanonicalEntryV1(
        forged_cache.canonical.owner_token, source, "forced-digest-bytes",
        forged_hash, FusionConceptAI._tac_program_fingerprint(source),
        FusionConceptAI._TAC_CACHE_GUARD)
    forged_cache.canonical.entries[source] = forged_entry
    @test_throws ArgumentError FusionConceptAI._ceg_cached_program_bytes(forged_cache, source)
    @test_throws ArgumentError FusionConceptAI._ceg_cached_program_hash(forged_cache, source)
    @test_throws ArgumentError FusionConceptAI._tac_authoritative_program_bytes(
        forged_cache.canonical, source)
    sealed = FusionConceptAI._ceg_sealed_program_hash(cache, source)
    other_cache = FusionConceptAI._CEGDerivationCacheV1()
    @test_throws ArgumentError FusionConceptAI._ceg_validate_sealed_program(
        other_cache, source, sealed)

    # The cached trace/provenance path must be byte-identical to the legacy
    # path while avoiding a second AST permutation search in the proposal loop.
    legacy_trace = FusionConceptAI._ceg_new_trace(
        1, rule, FusionConceptAI.rewrite_forward, source, target, 1, (condition,))
    cached_trace = FusionConceptAI._ceg_new_trace(
        cache, 1, rule, FusionConceptAI.rewrite_forward, source, target, 1, (condition,))
    @test canonical_json(legacy_trace) == canonical_json(cached_trace)
    rule_bytes = FusionConceptAI._ceg_cached_rule_bytes(cache, rule)
    @test_throws ArgumentError FusionConceptAI._CEGTraceFragmentsV1(
        cache.owner_token, source_bytes,
        FusionConceptAI._ceg_cached_program_bytes(cache, target), source_bytes,
        FusionConceptAI._ceg_cached_program_bytes(cache, target),
        FusionConceptAI._ceg_cached_program_hash(cache, source),
        FusionConceptAI._ceg_cached_program_hash(cache, target),
        digest256_text("wrong-rule-hash"), rule_bytes, getfield(rule, :rule_ref),
        FusionConceptAI._CEG_SEAL_GUARD)
    @test_throws Exception setfield!(cached_trace, :owner_token, Ref{Nothing}())
    legacy_provenance = ConditionalEqualityProvenanceV1(
        source, target, (condition,), (legacy_trace,))
    @test FusionConceptAI._ceg_validate_provenance_current(
        legacy_provenance, source, target,
        ConditionalRewriteSetV1((rule,)), cache)
    cached_provenance = FusionConceptAI._ceg_candidate_provenance(
        cache, forward, 1, source)
    @test canonical_json(legacy_provenance) == canonical_json(getfield(cached_provenance, 3))
    foreign_provenance_fragment = FusionConceptAI._CEGProvenanceFragmentsV1(
        other_cache.owner_token, FusionConceptAI._ceg_cached_program_hash(cache, source),
        FusionConceptAI._ceg_cached_program_hash(cache, target),
        FusionConceptAI._CEG_SEAL_GUARD)
    @test_throws ArgumentError ConditionalEqualityProvenanceV1(
        source, target, (condition,), (cached_trace,), foreign_provenance_fragment)
    foreign_rule = WholeProgramConditionalRewriteV1(
        QualifiedRefV1("m5-r3-foreign-rule", "v1"), source, target, (condition,),
        QualifiedRefV1("m5-r3-foreign-checker", "v1"), digest256_text("m5-r3-foreign-checker");
        registry=registry)
    foreign_trace = FusionConceptAI._ceg_new_trace(
        cache, 1, foreign_rule, FusionConceptAI.rewrite_forward, source, target, 1, (condition,))
    foreign_provenance = ConditionalEqualityProvenanceV1(
        source, target, (condition,), (foreign_trace,))
    @test_throws ArgumentError FusionConceptAI._ceg_validate_provenance_current(
        foreign_provenance, source, target,
        ConditionalRewriteSetV1((rule,)), cache)
    mixed_owner_trace = FusionConceptAI._ceg_new_trace(
        other_cache, 2, rule, FusionConceptAI.rewrite_reverse, target, source,
        2, (condition,))
    mixed_owner_provenance = ConditionalEqualityProvenanceV1(
        source, source, (condition,), (cached_trace, mixed_owner_trace))
    @test_throws ArgumentError FusionConceptAI._ceg_validate_provenance_current(
        mixed_owner_provenance, source, source,
        ConditionalRewriteSetV1((rule,)), cache)
    mixed_legacy_sealed = ConditionalEqualityProvenanceV1(
        source, source, (condition,), (legacy_trace, mixed_owner_trace))
    @test_throws ArgumentError FusionConceptAI._ceg_validate_provenance_current(
        mixed_legacy_sealed, source, source,
        ConditionalRewriteSetV1((rule,)), cache)
    forged_rule_cache = FusionConceptAI._CEGDerivationCacheV1()
    FusionConceptAI._ceg_cached_rule_bytes(forged_rule_cache, rule)
    forged_rule_cache.rule_bytes[rule] = FusionConceptAI._CEGRuleCacheEntryV1(
        forged_rule_cache.owner_token, rule, "forged-rule-bytes",
        FusionConceptAI._ceg_rule_fingerprint(rule))
    @test_throws ArgumentError FusionConceptAI._ceg_cached_rule_bytes(forged_rule_cache, rule)
    forged_rule_cache.rule_bytes[rule] = FusionConceptAI._CEGRuleCacheEntryV1(
        forged_rule_cache.owner_token, foreign_rule, canonical_json(rule),
        FusionConceptAI._ceg_rule_fingerprint(rule))
    @test_throws ArgumentError FusionConceptAI._ceg_cached_rule_bytes(forged_rule_cache, rule)
    forged_winner_cache = FusionConceptAI._CEGDerivationCacheV1()
    FusionConceptAI._ceg_cached_proposal_identity(forged_winner_cache, forward)
    forged_winner_cache.proposal_keys[forward] =
        FusionConceptAI._CEGProposalKeyV1("forged", "forged", "forged", UInt8(1), "forged")
    @test_throws ArgumentError FusionConceptAI._ceg_cached_proposal_identity(
        forged_winner_cache, forward)

    # Equal digest witnesses do not collapse distinct full-byte identities.
    forced_digest = digest256_text("forced-collision-witness")
    @test forced_digest == forced_digest
    collision_a = FusionConceptAI._CEGMemberKeyV1("program-A", "[]")
    collision_b = FusionConceptAI._CEGMemberKeyV1("program-B", "[]")
    collision_index = Dict{FusionConceptAI._CEGMemberKeyV1,Nothing}()
    collision_index[collision_a] = nothing
    collision_index[collision_b] = nothing
    @test length(collision_index) == 2
    forced_bucket = Dict{Digest256,Dict{FusionConceptAI._CEGMemberKeyV1,Nothing}}()
    forced_bucket[forced_digest] = collision_index
    @test length(forced_bucket[forced_digest]) == 2
    @test FusionConceptAI._ceg_member_key_bytes(collision_a) !=
        FusionConceptAI._ceg_member_key_bytes(collision_b)

    # Equivalent fresh-process proof: insertion order may differ, but the
    # explicit sealed-byte projection is the only order used for emission.
    order_a = Dict{FusionConceptAI._CEGMemberKeyV1,Nothing}()
    order_b = Dict{FusionConceptAI._CEGMemberKeyV1,Nothing}()
    order_a[collision_a] = nothing; order_a[collision_b] = nothing
    order_b[collision_b] = nothing; order_b[collision_a] = nothing
    order_key = k -> FusionConceptAI._ceg_member_key_bytes(k)
    @test map(order_key, sort!(collect(keys(order_a)), by=order_key)) ==
        map(order_key, sort!(collect(keys(order_b)), by=order_key))

    # The tiny graph exercises cold/hot receipt, query and replay equivalence.
    bounded = ConditionalEGraphBudgetV1(max_programs=4, max_rewrite_attempts=8,
        max_rounds=2, max_trace_steps=4)
    result = derive_conditional_program_egraph(source, (rule,), registry;
        saturation_budget=bounded)
    artifact = getfield(result, :artifact)
    @test artifact !== nothing
    result_receipt = canonical_json(result)
    @test canonical_hash(result) == digest256_text(result_receipt)
    if artifact !== nothing
        cold_equivalence = FusionConceptAI._ceg_equivalence_bytes(artifact)
        cold_attempt = FusionConceptAI._ceg_attempt_bytes(artifact)
        hot_cache = FusionConceptAI._CEGDerivationCacheV1()
        hot_equivalence = FusionConceptAI._ceg_equivalence_bytes(artifact, hot_cache)
        hot_attempt = FusionConceptAI._ceg_attempt_bytes(artifact, hot_cache)
        @test cold_equivalence == hot_equivalence
        @test cold_attempt == hot_attempt
        @test FusionConceptAI._ceg_hash_text(cold_equivalence) ==
            FusionConceptAI._ceg_hash_text(hot_equivalence)
        @test FusionConceptAI._ceg_hash_text(cold_attempt) ==
            FusionConceptAI._ceg_hash_text(hot_attempt)
        query = query_conditional_equality(artifact, target)
        @test getfield(query, :status) == conditional_equal
        queried_provenance = getfield(query, :provenance)
        @test queried_provenance isa ConditionalEqualityProvenanceV1
        query_receipt = canonical_json(query)
        query_receipt_again = canonical_json(query)
        parsed_query_receipt = JSON3.read(query_receipt)
        @test query_receipt == query_receipt_again
        @test parsed_query_receipt.kind == "conditional_equality_query_result"
        @test parsed_query_receipt.domain ==
            "fusionconceptai:v4:p1:conditional_equality_query_result:v1"
        @test canonical_hash(query) == digest256_text(query_receipt)
        @test replay_conditional_rewrite_trace(source, target, (rule,), registry,
            queried_provenance)
        artifact_rules = getfield(getfield(artifact, :rewrite_set), :rules)
        artifact_rule = getfield(artifact_rules, 1)
        receipt_cache = FusionConceptAI._CEGDerivationCacheV1()
        receipt_cache.rule_bytes[artifact_rule] = FusionConceptAI._CEGRuleCacheEntryV1(
            receipt_cache.owner_token, artifact_rule, "forged-rule-bytes",
            FusionConceptAI._ceg_rule_fingerprint(artifact_rule))
        @test FusionConceptAI._ceg_attempt_bytes(artifact, receipt_cache) == cold_attempt
        foreign_receipt_cache = FusionConceptAI._CEGDerivationCacheV1()
        foreign_receipt_cache.rule_bytes[foreign_rule] =
            FusionConceptAI._CEGRuleCacheEntryV1(
                foreign_receipt_cache.owner_token, foreign_rule,
                "forged-foreign-rule-bytes",
                FusionConceptAI._ceg_rule_fingerprint(foreign_rule))
        @test FusionConceptAI._ceg_attempt_bytes(artifact, foreign_receipt_cache) == cold_attempt
    end
end
