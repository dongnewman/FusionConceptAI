# Executable future-focused tests for the isolated structure-search contract.
#
# The parent serial lane owns Julia execution.  This file is intentionally
# provided now so the next focused run calls the real isolated seam.
using Test
include(joinpath(@__DIR__, "../../../src/RuntimeV4/M4Isolated/BoundedStructureSearchV1.jl"))
using .BoundedStructureSearchV1

H(x) = digest_text(String(x))

function closure(; gate=nothing, gate_status=:typed_absent, freshness_hash=nothing)
    SearchInputClosureV1("candidate-1", H("candidate"), H("g1"), H("g2"), H("g3"),
        H("component"), H("registry"), H("source"), H("grammar"), H("mission"),
        H("bounds"), H("scenario"), H("conditions");
        m5c_gate_hash=gate, m5c_gate_status=gate_status,
        freshness_hash=freshness_hash)
end

# BEGIN_NEGATIVE_VECTOR_COVERAGE
const NEGATIVE_VECTOR_COVERAGE_V1 = (
    "missing_m5c_authority", "closure_hash_mismatch", "foreign_candidate",
    "foreign_parent", "condition_unmet_zero_merge", "condition_unknown_deferred",
    "contradiction_fail_closed", "stale_condition_token", "budget_overflow",
    "saturation_incomplete", "nonfinite_synthetic_screen", "provider_nonzero",
    "solver_nonzero", "mesh_nonzero", "physical_nonzero", "pid_in_content_hash",
    "utc_in_content_hash", "run_id_in_content_hash", "replay_hash_mismatch",
    "descriptor_label_leak", "builder_gate_bypass", "freshness_hash_mismatch",
    "source_generation_mismatch", "action_order_permutation",
    "multi_lineage_parent_lookup", "proposal_overflow_pre_mutation",
    "sealed_result_counter_injection", "content_receipt_tamper",
    "operational_identity_exclusion", "direct_apply_typed_absent",
    "direct_apply_stale_freshness", "unsupported_budget_dimension_rejected",
    "receipt_status_mismatch", "receipt_counters_mismatch",
    "receipt_semantic_bytes_tamper", "receipt_edge_swap", "receipt_sequence_tamper",
    "receipt_descriptor_tamper", "receipt_semantic_bytes_self_consistent_tamper",
    "make_receipt_without_ledger_rejected", "mixed_failed_deferred_then_success",
    "foreign_emitter_rejected", "self_consistent_stale_closure_receipt",
    "typed_absent_closure_receipt", "forged_failure_hash",
    "non_frozen_seed_self_consistent_receipt", "event_limit_self_consistent_tamper",
    "budget_caps_self_consistent_tamper", "budget_hash_tamper",
    "nonprefix_counter_self_consistent_tamper", "ledger_snapshot_counter_tamper",
    "rewrite_event_self_consistent_tamper", "receipt_make_replay_schema_equality",
    "receipt_seed_cap_self_consistent_tamper", "receipt_status_forgery",
    "node_payload_dict_rejected", "node_payload_set_rejected",
    "node_payload_custom_object_rejected", "node_payload_nested_unsupported_rejected",
    "multi_seed_cap_exceeded",
)
# END_NEGATIVE_VECTOR_COVERAGE

@test length(NEGATIVE_VECTOR_COVERAGE_V1) == 60
@test length(unique(NEGATIVE_VECTOR_COVERAGE_V1)) == 60

struct UnsupportedNodePayloadV1
    value::Int
end

@testset "UP5 bounded structure-search contract" begin
    absent = closure()
    prepared = prepare_search(absent)
    @test prepared.status === :terminal_deferred
    @test prepared.claim_ceiling === :screen_only && !prepared.accepted && prepared.no_publish

    c = closure(gate=H("m5c"), gate_status=:accepted)
    @test validate_closure(c)[1] === :ready
    root = make_root_prefix(c)
    met = StructureActionV1("a-met", root.prefix_hash, (kind=:typed_node,),
        :conditions_met, H("evaluation-met"); token_generation=1, source_generation=1)
    unmet = StructureActionV1("a-unmet", root.prefix_hash, (kind=:typed_node,),
        :condition_unmet, H("evaluation-unmet"); token_generation=1, source_generation=1)
    unknown = StructureActionV1("a-unknown", root.prefix_hash, (kind=:typed_node,),
        :equality_unknown, H("evaluation-unknown"); token_generation=1, source_generation=1)
    contradiction = StructureActionV1("a-contradiction", root.prefix_hash,
        (kind=:typed_node,), :contradiction, H("evaluation-contradiction");
        token_generation=1, source_generation=1)

    merged = apply_action(root, met, c; expected_candidate_generation=1,
        expected_source_generation=1, expected_token_generation=1,
        expected_freshness_hash=c.freshness_hash)
    @test merged.merged && merged.status === :replayed && merged.receipt !== nothing
    @test merged.child.candidate_ref == c.candidate_ref
    @test !apply_action(root, unmet, c; expected_candidate_generation=1,
        expected_source_generation=1, expected_token_generation=1,
        expected_freshness_hash=c.freshness_hash).merged
    @test apply_action(root, unmet, c; expected_candidate_generation=1,
        expected_source_generation=1, expected_token_generation=1,
        expected_freshness_hash=c.freshness_hash).status === :not_applicable
    @test apply_action(root, unknown, c; expected_candidate_generation=1,
        expected_source_generation=1, expected_token_generation=1,
        expected_freshness_hash=c.freshness_hash).status === :terminal_deferred
    @test apply_action(root, contradiction, c; expected_candidate_generation=1,
        expected_source_generation=1, expected_token_generation=1,
        expected_freshness_hash=c.freshness_hash).status === :fail_closed
    @test apply_action(root, met, c; expected_candidate_generation=1,
        expected_source_generation=1, expected_token_generation=2,
        expected_freshness_hash=c.freshness_hash).status === :fail_closed
    foreign_parent = StructurePrefixV1("foreign-candidate", c.closure_hash, nothing, (), ())
    @test apply_action(foreign_parent, met, c; expected_candidate_generation=1,
        expected_source_generation=1, expected_token_generation=1,
        expected_freshness_hash=c.freshness_hash).status === :fail_closed
    # direct_apply_typed_absent
    @test apply_action(make_root_prefix(absent), met, absent;
        expected_candidate_generation=1, expected_source_generation=1,
        expected_token_generation=1, expected_freshness_hash=absent.freshness_hash).status === :terminal_deferred
    stale_closure = closure(gate=H("m5c"), gate_status=:accepted,
        freshness_hash=H("stale-freshness"))
    stale_root = make_root_prefix(stale_closure)
    stale_action = StructureActionV1("a-stale-direct", stale_root.prefix_hash,
        (kind=:typed_node,), :conditions_met, H("stale-direct");
        token_generation=1, source_generation=1)
    # direct_apply_stale_freshness
    @test apply_action(stale_root, stale_action, stale_closure;
        expected_candidate_generation=1, expected_source_generation=1,
        expected_token_generation=1, expected_freshness_hash=stale_closure.freshness_hash).status === :fail_closed

    @test_throws ArgumentError budget_event(:prefixes, 11, 1, 63, 65, 64)
    @test_throws ArgumentError StructureSearchBudgetV1(max_provider_steps=1)
    @test_throws MethodError StructureSearchBudgetV1(max_eclasses=1)
    @test_throws ArgumentError StructureActionV1("bad", root.prefix_hash,
        (kind=:typed_node,), :not_a_condition, H("x"); token_generation=1, source_generation=1)
    # node_payload canonical closure: only deterministic scalar/tuple/named-tuple
    # values (and plain one-dimensional vectors) are accepted.
    @test_throws ArgumentError StructureActionV1("dict-payload", root.prefix_hash,
        (kind=Dict(:x => 1),), :conditions_met, H("dict-payload");
        token_generation=1, source_generation=1)
    @test_throws ArgumentError StructureActionV1("set-payload", root.prefix_hash,
        (kind=Set([:x]),), :conditions_met, H("set-payload");
        token_generation=1, source_generation=1)
    @test_throws ArgumentError StructureActionV1("custom-payload", root.prefix_hash,
        (kind=UnsupportedNodePayloadV1(1),), :conditions_met, H("custom-payload");
        token_generation=1, source_generation=1)
    @test_throws ArgumentError StructureActionV1("nested-payload", root.prefix_hash,
        (kind=(nested=Dict(:x => 1),),), :conditions_met, H("nested-payload");
        token_generation=1, source_generation=1)
    # The constructor admission itself must also reject unsupported top-level
    # payloads, proving that the guard is reached before field conversion.
    @test_throws ArgumentError StructureActionV1("top-level-dict", root.prefix_hash,
        Dict(:x => 1), :conditions_met, H("top-level-dict");
        token_generation=1, source_generation=1)
    @test_throws ArgumentError StructureActionV1("top-level-set", root.prefix_hash,
        Set([:x]), :conditions_met, H("top-level-set");
        token_generation=1, source_generation=1)
    @test_throws ArgumentError StructureActionV1("top-level-custom", root.prefix_hash,
        UnsupportedNodePayloadV1(1), :conditions_met, H("top-level-custom");
        token_generation=1, source_generation=1)
    @test_throws ArgumentError StructureActionV1("nested-set-payload", root.prefix_hash,
        (kind=(nested=Set([:x]),),), :conditions_met, H("nested-set-payload");
        token_generation=1, source_generation=1)

    result = build_prefix_dag(c, (met,);
        expected_candidate_generation=1, expected_source_generation=1,
        expected_token_generation=1, expected_freshness_hash=c.freshness_hash)
    @test result.status === :screen_only
    @test result.counters.provider_steps == 0
    @test result.counters.solver_steps == 0
    @test result.counters.mesh_steps == 0
    @test result.counters.physical_steps == 0
    @test validate_result(result)
    # receipt_make_replay_schema_equality
    @test replay_content_hash(result) == result.content_receipt.content_hash
    @test BoundedStructureSearchV1._content_receipt_body(result.content_receipt).budget_hash ==
        result.content_receipt.budget.budget_hash
    @test result.content_receipt !== nothing
    @test !hasproperty(result.content_receipt, :pid)

    bounded = build_prefix_dag(c, (met,); budget=StructureSearchBudgetV1(max_prefixes=1),
        expected_candidate_generation=1, expected_source_generation=1,
        expected_token_generation=1, expected_freshness_hash=c.freshness_hash)
    @test bounded.status === :terminal_deferred
    @test any(x.kind === :saturation_incomplete for x in bounded.failures)

    @testset "closure and freshness gates cannot be bypassed" begin
        bypassed = build_prefix_dag(absent, (); expected_candidate_generation=1,
            expected_source_generation=1, expected_token_generation=1,
            expected_freshness_hash=absent.freshness_hash)
        @test bypassed.status === :terminal_deferred
        stale = StructureActionV1("a-stale", root.prefix_hash, (kind=:typed_node,),
            :conditions_met, H("stale"); token_generation=1, source_generation=2)
        stale_result = build_prefix_dag(c, (stale,); expected_candidate_generation=1,
            expected_source_generation=1, expected_token_generation=1,
            expected_freshness_hash=c.freshness_hash)
        @test stale_result.status === :fail_closed
    end

    @testset "canonical multi-lineage order and saturation boundaries" begin
        branch_a = StructureActionV1("a-branch", root.prefix_hash, (kind=:a,),
            :conditions_met, H("branch-a"); token_generation=1, source_generation=1)
        branch_b = StructureActionV1("b-branch", root.prefix_hash, (kind=:b,),
            :conditions_met, H("branch-b"); token_generation=1, source_generation=1)
        branch_a_child = apply_action(root, branch_a, c;
            expected_candidate_generation=1, expected_source_generation=1,
            expected_token_generation=1, expected_freshness_hash=c.freshness_hash).child
        child_action = StructureActionV1("a-child", branch_a_child.prefix_hash,
            (kind=:child,), :conditions_met, H("child");
            token_generation=1, source_generation=1)
        kwargs = (expected_candidate_generation=1, expected_source_generation=1,
            expected_token_generation=1, expected_freshness_hash=c.freshness_hash)
        empty_dag = build_prefix_dag(c, (); kwargs...)
        @test empty_dag.status === :screen_only
        @test empty_dag.counters.prefixes == 1
        @test validate_result(empty_dag)
        mixed_unmet = StructureActionV1("mixed-a-unmet", root.prefix_hash,
            (kind=:unmet,), :condition_unmet, H("mixed-unmet");
            token_generation=1, source_generation=1)
        mixed_unknown = StructureActionV1("mixed-b-unknown", root.prefix_hash,
            (kind=:unknown,), :equality_unknown, H("mixed-unknown");
            token_generation=1, source_generation=1)
        mixed_fail = StructureActionV1("mixed-c-fail", root.prefix_hash,
            (kind=:fail,), :contradiction, H("mixed-fail");
            token_generation=1, source_generation=1)
        mixed_success = StructureActionV1("mixed-d-success", root.prefix_hash,
            (kind=:success,), :conditions_met, H("mixed-success");
            token_generation=1, source_generation=1)
        mixed = build_prefix_dag(c,
            (mixed_success, mixed_fail, mixed_unknown, mixed_unmet); kwargs...)
        # mixed_failed_deferred_then_success
        @test mixed.status === :fail_closed
        @test mixed.content_receipt.proposal_lineage[1].sequence == 1
        @test mixed.content_receipt.ledger_snapshot.events[1].sequence == 1
        @test validate_result(mixed)
        dag_a = build_prefix_dag(c, (child_action, branch_b, branch_a); kwargs...)
        dag_b = build_prefix_dag(c, (branch_a, child_action, branch_b); kwargs...)
        @test dag_a.content_receipt.content_hash == dag_b.content_receipt.content_hash
        @test dag_a.counters.prefixes == 4
        @test dag_a.counters.proposal_receipts == 3

        proposal_bound = build_prefix_dag(c, (branch_a,);
            budget=StructureSearchBudgetV1(max_proposal_receipts=0), kwargs...)
        @test proposal_bound.counters.prefixes == 1
        @test proposal_bound.counters.proposal_receipts == 0
        @test any(x.kind === :saturation_incomplete for x in proposal_bound.failures)
        seed_bound = build_prefix_dag(c, (branch_a,);
            budget=StructureSearchBudgetV1(max_seeds=0), kwargs...)
        @test seed_bound.status === :terminal_deferred
        @test seed_bound.counters.prefixes == 0
        rewrite_bound = build_prefix_dag(c, (branch_a,);
            budget=StructureSearchBudgetV1(max_rewrites_per_seed=0), kwargs...)
        @test rewrite_bound.status === :terminal_deferred
        @test rewrite_bound.counters.prefixes == 0
        exact_bound = build_prefix_dag(c, (branch_a,);
            budget=StructureSearchBudgetV1(max_prefixes=2), kwargs...)
        @test exact_bound.status === :screen_only
        @test !any(x.kind === :saturation_incomplete for x in exact_bound.failures)
    end

    @testset "proposal-value budget joins" begin
        # A root-only receipt consumes no seed, so max_seeds=0 is a valid
        # positive budget for the empty proposal lineage.
        zero_proposal_budget = StructureSearchBudgetV1(max_seeds=0)
        zero_proposal = build_prefix_dag(c, (); budget=zero_proposal_budget,
            expected_candidate_generation=1, expected_source_generation=1,
            expected_token_generation=1, expected_freshness_hash=c.freshness_hash)
        @test zero_proposal.status === :screen_only
        @test isempty(zero_proposal.content_receipt.proposal_lineage)
        @test validate_result(zero_proposal; expected_budget=zero_proposal_budget)
        @test replay_content_hash(zero_proposal;
            expected_budget=zero_proposal_budget) == zero_proposal.content_receipt.content_hash

        # make_content_receipt and replay must both use the actual typed
        # proposal values when enforcing distinct frozen-seed caps.
        action_a = StructureActionV1("multi-seed-a", root.prefix_hash,
            (kind=:multi_a,), :conditions_met, H("multi-seed-a");
            token_generation=1, source_generation=1)
        child_a = apply_action(root, action_a, c;
            expected_candidate_generation=1, expected_source_generation=1,
            expected_token_generation=1, expected_freshness_hash=c.freshness_hash).child
        action_b = StructureActionV1("multi-seed-b", child_a.prefix_hash,
            (kind=:multi_b,), :conditions_met, H("multi-seed-b");
            token_generation=1, source_generation=1)
        child_b = apply_action(child_a, action_b, c;
            expected_candidate_generation=1, expected_source_generation=1,
            expected_token_generation=1, expected_freshness_hash=c.freshness_hash).child
        proposal_a = StructureProposalV1(:grammar, FROZEN_SEEDS[1], 1,
            c.candidate_ref, root.prefix_hash, child_a.prefix_hash,
            digest_text(action_a.action_ref), c.closure_hash)
        proposal_b = StructureProposalV1(:grammar, FROZEN_SEEDS[2], 2,
            c.candidate_ref, child_a.prefix_hash, child_b.prefix_hash,
            digest_text(action_b.action_ref), c.closure_hash)
        descriptor_ledger_a = BudgetLedgerV1()
        descriptor_ledger_a.counters[:prefixes] = 2
        descriptor_a = descriptor(child_a, descriptor_ledger_a)
        descriptor_ledger_b = BudgetLedgerV1()
        descriptor_ledger_b.counters[:prefixes] = 3
        descriptor_b = descriptor(child_b, descriptor_ledger_b)
        multi_budget = StructureSearchBudgetV1(max_seeds=2)
        multi_ledger = BudgetLedgerV1()
        multi_ledger.counters[:rewrites] = 2
        multi_ledger.counters[:prefixes] = 3
        multi_ledger.counters[:proposal_receipts] = 2
        multi_ledger.events = BudgetEventV1[
            budget_event(:rewrites, FROZEN_SEEDS[1], 1, 0, 1,
                multi_budget.max_rewrites_per_seed),
            budget_event(:prefixes, FROZEN_SEEDS[1], 1, 1, 2,
                multi_budget.max_prefixes),
            budget_event(:proposal_receipts, FROZEN_SEEDS[1], 1, 0, 1,
                multi_budget.max_proposal_receipts),
            budget_event(:rewrites, FROZEN_SEEDS[2], 2, 1, 2,
                multi_budget.max_rewrites_per_seed),
            budget_event(:prefixes, FROZEN_SEEDS[2], 2, 2, 3,
                multi_budget.max_prefixes),
            budget_event(:proposal_receipts, FROZEN_SEEDS[2], 2, 1, 2,
                multi_budget.max_proposal_receipts),
        ]
        multi_counters = BoundedStructureSearchV1._counter_namedtuple(
            ((key, multi_ledger.counters[key])
             for key in BoundedStructureSearchV1._LEDGER_COUNTER_KEYS))
        multi_receipt = make_content_receipt(c, root,
            (root, child_a, child_b), (proposal_a, proposal_b),
            (descriptor_a, descriptor_b), multi_counters, :screen_only;
            ledger=multi_ledger, budget=multi_budget)
        multi_result = BoundedStructureSearchV1._result(:screen_only,
            c.closure_hash; receipt=multi_receipt, counters=multi_counters)
        @test validate_result(multi_result; expected_budget=multi_budget)
        @test replay_content_hash(multi_result;
            expected_budget=multi_budget) == multi_receipt.content_hash

        one_seed_budget = StructureSearchBudgetV1(max_seeds=1)
        # multi_seed_cap_exceeded
        @test_throws ArgumentError make_content_receipt(c, root,
            (root, child_a, child_b), (proposal_a, proposal_b),
            (descriptor_a, descriptor_b), multi_counters, :screen_only;
            ledger=multi_ledger, budget=one_seed_budget)
        forged_multi_content = BoundedStructureSearchV1._recomputed_content_hash(
            multi_receipt, multi_receipt.prefix_hashes,
            multi_receipt.proposal_hashes, multi_receipt.descriptor_hashes,
            multi_receipt.prefix_semantic_bytes, multi_receipt.proposal_semantic_bytes,
            multi_receipt.descriptor_semantic_bytes, multi_receipt.ledger_semantic_bytes;
            budget=one_seed_budget)
        forged_multi_receipt = StructureContentReceiptV1(
            multi_receipt.closure_hash, multi_receipt.root_hash,
            multi_receipt.prefix_hashes, multi_receipt.proposal_hashes,
            multi_receipt.descriptor_hashes, multi_receipt.prefix_semantic_bytes,
            multi_receipt.proposal_semantic_bytes, multi_receipt.descriptor_semantic_bytes,
            multi_receipt.ledger_semantic_bytes, multi_receipt.counters,
            multi_receipt.status, forged_multi_content, multi_receipt.closure,
            multi_receipt.prefix_lineage, multi_receipt.proposal_lineage,
            multi_receipt.descriptor_lineage, multi_receipt.ledger_snapshot,
            one_seed_budget)
        forged_multi_result = BoundedStructureSearchV1._result(:screen_only,
            c.closure_hash; receipt=forged_multi_receipt,
            counters=multi_counters)
        @test_throws ArgumentError replay_content_hash(forged_multi_result;
            expected_budget=one_seed_budget)
    end

    @testset "sealed result and receipt tamper guards" begin
        @test_throws ArgumentError StructureSearchResultV1(
            result.status, result.claim_ceiling, result.accepted, result.no_publish,
            result.closure_hash, result.content_receipt, result.operational_envelope,
            result.failures,
            (prefixes=1, screen_evaluations=0, proposal_receipts=1,
             qd_proposals=1, mcts_proposals=0, provider_steps=0, solver_steps=0,
             mesh_steps=0, physical_steps=0), result.result_hash)
        forged_failure = StructureFailureV1(:fail_closed, "forged failure",
            H("forged-failure-hash"))
        forged_failure_result = BoundedStructureSearchV1._result(:fail_closed,
            c.closure_hash; failures=(forged_failure,))
        # forged_failure_hash
        @test_throws ArgumentError replay_content_hash(forged_failure_result)
        @test_throws ArgumentError validate_result(forged_failure_result)
        receipt = result.content_receipt
        forged_receipt = StructureContentReceiptV1(receipt.closure_hash,
            receipt.root_hash, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            receipt.ledger_semantic_bytes, receipt.counters, receipt.status,
            H("forged-content"), receipt.closure, receipt.prefix_lineage,
             receipt.proposal_lineage, receipt.descriptor_lineage,
             receipt.ledger_snapshot, receipt.budget)
        forged = BoundedStructureSearchV1._new_result(result.status, result.claim_ceiling, false, true,
            result.closure_hash, forged_receipt, nothing, result.failures,
            result.counters, result.result_hash)
        @test_throws ArgumentError replay_content_hash(forged)
        @test_throws ArgumentError validate_result(forged)
        tampered_prefix_bytes = Tuple(copy(bytes) for bytes in receipt.prefix_semantic_bytes)
        tampered_first = copy(first(tampered_prefix_bytes))
        tampered_first[1] = tampered_first[1] == UInt8(0x78) ? UInt8(0x79) : UInt8(0x78)
        tampered_prefix_bytes = (tampered_first, tampered_prefix_bytes[2:end]...)
        # receipt_semantic_bytes_tamper
        semantic_forged_receipt = StructureContentReceiptV1(receipt.closure_hash,
            receipt.root_hash, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, tampered_prefix_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            receipt.ledger_semantic_bytes, receipt.counters, receipt.status,
            H("semantic-forged"), receipt.closure, receipt.prefix_lineage,
             receipt.proposal_lineage, receipt.descriptor_lineage,
             receipt.ledger_snapshot, receipt.budget)
        semantic_forged = BoundedStructureSearchV1._new_result(result.status,
            result.claim_ceiling, false, true, result.closure_hash,
            semantic_forged_receipt, nothing, result.failures, result.counters,
            result.result_hash)
        @test_throws ArgumentError replay_content_hash(semantic_forged)
        self_consistent_prefix_hashes = Tuple(BoundedStructureSearchV1._semantic_digest(bytes)
            for bytes in tampered_prefix_bytes)
        self_consistent_content = BoundedStructureSearchV1._recomputed_content_hash(
            receipt, self_consistent_prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, tampered_prefix_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            receipt.ledger_semantic_bytes)
        self_consistent_receipt = StructureContentReceiptV1(receipt.closure_hash,
            receipt.root_hash, self_consistent_prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, tampered_prefix_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            receipt.ledger_semantic_bytes, receipt.counters, receipt.status,
            self_consistent_content, receipt.closure, receipt.prefix_lineage,
             receipt.proposal_lineage, receipt.descriptor_lineage,
             receipt.ledger_snapshot, receipt.budget)
        self_consistent = BoundedStructureSearchV1._new_result(result.status,
            result.claim_ceiling, false, true, result.closure_hash,
            self_consistent_receipt, nothing, result.failures, result.counters,
            result.result_hash)
        # receipt_semantic_bytes_self_consistent_tamper
        @test_throws ArgumentError replay_content_hash(self_consistent)
        # receipt_status_mismatch
        status_receipt = StructureContentReceiptV1(receipt.closure_hash,
            receipt.root_hash, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            receipt.ledger_semantic_bytes, receipt.counters, :terminal_deferred,
            H("status-forged"), receipt.closure, receipt.prefix_lineage,
             receipt.proposal_lineage, receipt.descriptor_lineage,
             receipt.ledger_snapshot, receipt.budget)
        status_forged = BoundedStructureSearchV1._new_result(result.status,
            result.claim_ceiling, false, true, result.closure_hash,
            status_receipt, nothing, result.failures, result.counters,
            result.result_hash)
        @test_throws ArgumentError validate_result(status_forged)
        # receipt_status_forgery
        invalid_status_receipt = StructureContentReceiptV1(receipt.closure_hash,
            receipt.root_hash, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            receipt.ledger_semantic_bytes, receipt.counters, :winner,
            H("invalid-status"), receipt.closure, receipt.prefix_lineage,
            receipt.proposal_lineage, receipt.descriptor_lineage,
            receipt.ledger_snapshot, receipt.budget)
        invalid_status_result = BoundedStructureSearchV1._result(:screen_only,
            receipt.closure_hash; receipt=invalid_status_receipt,
            failures=result.failures, counters=result.counters)
        @test_throws ArgumentError replay_content_hash(invalid_status_result)
        # receipt_counters_mismatch
        counter_receipt = StructureContentReceiptV1(receipt.closure_hash,
            receipt.root_hash, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            receipt.ledger_semantic_bytes,
            (prefixes=999, screen_evaluations=0, proposal_receipts=999,
             qd_proposals=0, mcts_proposals=0, provider_steps=0,
             solver_steps=0, mesh_steps=0, physical_steps=0), receipt.status,
            H("counter-forged"), receipt.closure, receipt.prefix_lineage,
             receipt.proposal_lineage, receipt.descriptor_lineage,
             receipt.ledger_snapshot, receipt.budget)
        counter_forged = BoundedStructureSearchV1._new_result(result.status,
            result.claim_ceiling, false, true, result.closure_hash,
            counter_receipt, nothing, result.failures, result.counters,
            result.result_hash)
        @test_throws ArgumentError validate_result(counter_forged)
        # make_receipt_without_ledger_rejected
        @test_throws ArgumentError make_content_receipt(c, root, (root,), (), (),
            (prefixes=1, screen_evaluations=0, proposal_receipts=0,
             qd_proposals=0, mcts_proposals=0, provider_steps=0, solver_steps=0,
             mesh_steps=0, physical_steps=0), :screen_only)

        receipt_events = receipt.ledger_snapshot.events
        limit_event = receipt_events[2]
        forged_limit_event = BudgetEventV1(:prefixes, limit_event.seed,
            limit_event.sequence, limit_event.before, limit_event.after,
            limit_event.limit + 1, limit_event.status)
        forged_limit_snapshot = StructureLedgerSnapshotV1(
            (receipt_events[1], forged_limit_event, receipt_events[3]),
            receipt.ledger_snapshot.counter_pairs)
        forged_limit_ledger_bytes = BoundedStructureSearchV1._semantic_bytes(
            BoundedStructureSearchV1._ledger_semantic_body(forged_limit_snapshot))
        forged_limit_content = BoundedStructureSearchV1._recomputed_content_hash(
            receipt, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            forged_limit_ledger_bytes)
        forged_limit_receipt = StructureContentReceiptV1(receipt.closure_hash,
            receipt.root_hash, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            forged_limit_ledger_bytes, receipt.counters, receipt.status,
            forged_limit_content, receipt.closure, receipt.prefix_lineage,
            receipt.proposal_lineage, receipt.descriptor_lineage,
            forged_limit_snapshot, receipt.budget)
        forged_limit_result = BoundedStructureSearchV1._result(:screen_only,
            receipt.closure_hash; receipt=forged_limit_receipt,
            failures=result.failures, counters=result.counters)
        # event_limit_self_consistent_tamper
        @test_throws ArgumentError replay_content_hash(forged_limit_result)

        rewrite_event = receipt_events[1]
        forged_rewrite_event = BudgetEventV1(:rewrites, rewrite_event.seed,
            rewrite_event.sequence, rewrite_event.before,
            rewrite_event.after + 1, rewrite_event.limit, :complete)
        forged_rewrite_snapshot = StructureLedgerSnapshotV1(
            (forged_rewrite_event, receipt_events[2], receipt_events[3]),
            receipt.ledger_snapshot.counter_pairs)
        forged_rewrite_ledger_bytes = BoundedStructureSearchV1._semantic_bytes(
            BoundedStructureSearchV1._ledger_semantic_body(forged_rewrite_snapshot))
        forged_rewrite_content = BoundedStructureSearchV1._recomputed_content_hash(
            receipt, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            forged_rewrite_ledger_bytes)
        forged_rewrite_receipt = StructureContentReceiptV1(receipt.closure_hash,
            receipt.root_hash, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            forged_rewrite_ledger_bytes, receipt.counters, receipt.status,
            forged_rewrite_content, receipt.closure, receipt.prefix_lineage,
            receipt.proposal_lineage, receipt.descriptor_lineage,
            forged_rewrite_snapshot, receipt.budget)
        forged_rewrite_result = BoundedStructureSearchV1._result(:screen_only,
            receipt.closure_hash; receipt=forged_rewrite_receipt,
            failures=result.failures, counters=result.counters)
        # rewrite_event_self_consistent_tamper
        @test_throws ArgumentError replay_content_hash(forged_rewrite_result)

        forged_budget = StructureSearchBudgetV1(max_prefixes=999)
        forged_budget_content = BoundedStructureSearchV1._recomputed_content_hash(
            receipt, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            receipt.ledger_semantic_bytes; budget=forged_budget)
        forged_budget_receipt = StructureContentReceiptV1(receipt.closure_hash,
            receipt.root_hash, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            receipt.ledger_semantic_bytes, receipt.counters, receipt.status,
            forged_budget_content, receipt.closure, receipt.prefix_lineage,
            receipt.proposal_lineage, receipt.descriptor_lineage,
            receipt.ledger_snapshot, forged_budget)
        forged_budget_result = BoundedStructureSearchV1._result(:screen_only,
            receipt.closure_hash; receipt=forged_budget_receipt,
            failures=result.failures, counters=result.counters)
        # budget_caps_self_consistent_tamper
        @test_throws ArgumentError replay_content_hash(forged_budget_result;
            expected_budget=receipt.budget)

        forged_hash_budget = StructureSearchBudgetV1(
            BoundedStructureSearchV1._BUDGET_AUTHORITY_SEAL_V1,
            8, 32, 64, 48, 0, 0, 0, 0, H("forged-budget-hash"))
        forged_hash_content = BoundedStructureSearchV1._recomputed_content_hash(
            receipt, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            receipt.ledger_semantic_bytes; budget=forged_hash_budget)
        forged_hash_receipt = StructureContentReceiptV1(receipt.closure_hash,
            receipt.root_hash, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            receipt.ledger_semantic_bytes, receipt.counters, receipt.status,
            forged_hash_content, receipt.closure, receipt.prefix_lineage,
            receipt.proposal_lineage, receipt.descriptor_lineage,
            receipt.ledger_snapshot, forged_hash_budget)
        forged_hash_result = BoundedStructureSearchV1._result(:screen_only,
            receipt.closure_hash; receipt=forged_hash_receipt,
            failures=result.failures, counters=result.counters)
        # budget_hash_tamper
        @test_throws ArgumentError replay_content_hash(forged_hash_result;
            expected_budget=receipt.budget)

        nonprefix_pairs = Tuple((key, key === :screen_evaluations ? 1 : value)
            for (key, value) in receipt.ledger_snapshot.counter_pairs)
        nonprefix_snapshot = StructureLedgerSnapshotV1(receipt_events,
            nonprefix_pairs)
        nonprefix_ledger_bytes = BoundedStructureSearchV1._semantic_bytes(
            BoundedStructureSearchV1._ledger_semantic_body(nonprefix_snapshot))
        nonprefix_counters = merge(receipt.counters, (screen_evaluations=1,))
        nonprefix_content = BoundedStructureSearchV1._recomputed_content_hash(
            receipt, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            nonprefix_ledger_bytes; counters=nonprefix_counters)
        nonprefix_receipt = StructureContentReceiptV1(receipt.closure_hash,
            receipt.root_hash, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            nonprefix_ledger_bytes, nonprefix_counters, receipt.status,
            nonprefix_content, receipt.closure, receipt.prefix_lineage,
            receipt.proposal_lineage, receipt.descriptor_lineage,
            nonprefix_snapshot, receipt.budget)
        nonprefix_result = BoundedStructureSearchV1._result(:screen_only,
            receipt.closure_hash; receipt=nonprefix_receipt,
            failures=result.failures, counters=nonprefix_counters)
        # nonprefix_counter_self_consistent_tamper
        @test_throws ArgumentError replay_content_hash(nonprefix_result)

        ledger_counter_pairs = Tuple((key, key === :prefixes ? 999 : value)
            for (key, value) in receipt.ledger_snapshot.counter_pairs)
        ledger_counter_snapshot = StructureLedgerSnapshotV1(receipt_events,
            ledger_counter_pairs)
        ledger_counter_bytes = BoundedStructureSearchV1._semantic_bytes(
            BoundedStructureSearchV1._ledger_semantic_body(ledger_counter_snapshot))
        ledger_counter_result_counters = merge(receipt.counters, (prefixes=999,))
        ledger_counter_content = BoundedStructureSearchV1._recomputed_content_hash(
            receipt, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            ledger_counter_bytes; counters=ledger_counter_result_counters)
        ledger_counter_receipt = StructureContentReceiptV1(receipt.closure_hash,
            receipt.root_hash, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            ledger_counter_bytes, ledger_counter_result_counters, receipt.status,
            ledger_counter_content, receipt.closure, receipt.prefix_lineage,
            receipt.proposal_lineage, receipt.descriptor_lineage,
            ledger_counter_snapshot, receipt.budget)
        ledger_counter_result = BoundedStructureSearchV1._result(:screen_only,
            receipt.closure_hash; receipt=ledger_counter_receipt,
            failures=result.failures, counters=ledger_counter_result_counters)
        # ledger_snapshot_counter_tamper
        @test_throws ArgumentError replay_content_hash(ledger_counter_result)

        branch_a = StructureActionV1("receipt-a", root.prefix_hash, (kind=:a,),
            :conditions_met, H("receipt-a-condition"); token_generation=1,
            source_generation=1)
        branch_b = StructureActionV1("receipt-b", root.prefix_hash, (kind=:b,),
            :conditions_met, H("receipt-b-condition"); token_generation=1,
            source_generation=1)
        dag = build_prefix_dag(c, (branch_b, branch_a);
            expected_candidate_generation=1, expected_source_generation=1,
            expected_token_generation=1, expected_freshness_hash=c.freshness_hash)
        dag_receipt = dag.content_receipt
        swapped_proposals = (dag_receipt.proposal_lineage[2],
            dag_receipt.proposal_lineage[1])
        swapped_receipt = StructureContentReceiptV1(dag_receipt.closure_hash,
            dag_receipt.root_hash, dag_receipt.prefix_hashes,
            dag_receipt.proposal_hashes, dag_receipt.descriptor_hashes,
            dag_receipt.prefix_semantic_bytes, dag_receipt.proposal_semantic_bytes,
            dag_receipt.descriptor_semantic_bytes, dag_receipt.ledger_semantic_bytes,
            dag_receipt.counters, dag_receipt.status, dag_receipt.content_hash,
            dag_receipt.closure, dag_receipt.prefix_lineage, swapped_proposals,
            dag_receipt.descriptor_lineage, dag_receipt.ledger_snapshot,
            dag_receipt.budget)
        swapped_result = BoundedStructureSearchV1._new_result(dag.status,
            dag.claim_ceiling, false, true, dag.closure_hash, swapped_receipt,
            nothing, dag.failures, dag.counters, dag.result_hash)
        # receipt_edge_swap
        @test_throws ArgumentError replay_content_hash(swapped_result)

        sequence_forged = StructureProposalV1(:grammar,
            dag_receipt.proposal_lineage[1].seed, 99,
            dag_receipt.proposal_lineage[1].candidate_ref,
            dag_receipt.proposal_lineage[1].parent_prefix_hash,
            dag_receipt.proposal_lineage[1].prefix_hash,
            dag_receipt.proposal_lineage[1].action_hash,
            dag_receipt.proposal_lineage[1].closure_hash)
        sequence_receipt = StructureContentReceiptV1(dag_receipt.closure_hash,
            dag_receipt.root_hash, dag_receipt.prefix_hashes,
            dag_receipt.proposal_hashes, dag_receipt.descriptor_hashes,
            dag_receipt.prefix_semantic_bytes, dag_receipt.proposal_semantic_bytes,
            dag_receipt.descriptor_semantic_bytes, dag_receipt.ledger_semantic_bytes,
            dag_receipt.counters, dag_receipt.status, dag_receipt.content_hash,
            dag_receipt.closure, dag_receipt.prefix_lineage,
            (sequence_forged, dag_receipt.proposal_lineage[2]),
            dag_receipt.descriptor_lineage, dag_receipt.ledger_snapshot,
            dag_receipt.budget)
        sequence_result = BoundedStructureSearchV1._new_result(dag.status,
            dag.claim_ceiling, false, true, dag.closure_hash, sequence_receipt,
            nothing, dag.failures, dag.counters, dag.result_hash)
        # receipt_sequence_tamper
        @test_throws ArgumentError replay_content_hash(sequence_result)

        descriptor_forged = StructureDescriptorV1(
            dag_receipt.descriptor_lineage[1].prefix_byte_mod_16,
            dag_receipt.descriptor_lineage[1].typed_node_count_mod_16, 99)
        descriptor_receipt = StructureContentReceiptV1(dag_receipt.closure_hash,
            dag_receipt.root_hash, dag_receipt.prefix_hashes,
            dag_receipt.proposal_hashes, dag_receipt.descriptor_hashes,
            dag_receipt.prefix_semantic_bytes, dag_receipt.proposal_semantic_bytes,
            dag_receipt.descriptor_semantic_bytes, dag_receipt.ledger_semantic_bytes,
            dag_receipt.counters, dag_receipt.status, dag_receipt.content_hash,
            dag_receipt.closure, dag_receipt.prefix_lineage,
            dag_receipt.proposal_lineage,
            (descriptor_forged, dag_receipt.descriptor_lineage[2]),
            dag_receipt.ledger_snapshot, dag_receipt.budget)
        descriptor_result = BoundedStructureSearchV1._new_result(dag.status,
            dag.claim_ceiling, false, true, dag.closure_hash, descriptor_receipt,
            nothing, dag.failures, dag.counters, dag.result_hash)
        # receipt_descriptor_tamper
        @test_throws ArgumentError replay_content_hash(descriptor_result)

        qd_proposal = StructureProposalV1(:qd,
            dag_receipt.proposal_lineage[1].seed,
            dag_receipt.proposal_lineage[1].sequence,
            dag_receipt.proposal_lineage[1].candidate_ref,
            dag_receipt.proposal_lineage[1].parent_prefix_hash,
            dag_receipt.proposal_lineage[1].prefix_hash,
            dag_receipt.proposal_lineage[1].action_hash,
            dag_receipt.proposal_lineage[1].closure_hash)
        emitter_receipt = StructureContentReceiptV1(dag_receipt.closure_hash,
            dag_receipt.root_hash, dag_receipt.prefix_hashes,
            dag_receipt.proposal_hashes, dag_receipt.descriptor_hashes,
            dag_receipt.prefix_semantic_bytes, dag_receipt.proposal_semantic_bytes,
            dag_receipt.descriptor_semantic_bytes, dag_receipt.ledger_semantic_bytes,
            dag_receipt.counters, dag_receipt.status, dag_receipt.content_hash,
            dag_receipt.closure, dag_receipt.prefix_lineage,
            (qd_proposal, dag_receipt.proposal_lineage[2]),
            dag_receipt.descriptor_lineage, dag_receipt.ledger_snapshot,
            dag_receipt.budget)
        emitter_result = BoundedStructureSearchV1._new_result(dag.status,
            dag.claim_ceiling, false, true, dag.closure_hash, emitter_receipt,
            nothing, dag.failures, dag.counters, dag.result_hash)
        # foreign_emitter_rejected
        @test_throws ArgumentError replay_content_hash(emitter_result)

        stale_receipt_closure = closure(gate=H("m5c"), gate_status=:accepted,
            freshness_hash=H("stale-receipt-freshness"))
        stale_receipt = StructureContentReceiptV1(stale_receipt_closure.closure_hash,
            receipt.root_hash, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            receipt.ledger_semantic_bytes, receipt.counters, receipt.status,
            receipt.content_hash, stale_receipt_closure, receipt.prefix_lineage,
            receipt.proposal_lineage, receipt.descriptor_lineage,
            receipt.ledger_snapshot, receipt.budget)
        stale_result = BoundedStructureSearchV1._new_result(result.status,
            result.claim_ceiling, false, true, stale_receipt_closure.closure_hash,
            stale_receipt, nothing, result.failures, result.counters,
            result.result_hash)
        # self_consistent_stale_closure_receipt
        @test_throws ArgumentError replay_content_hash(stale_result)

        absent_receipt_closure = closure()
        absent_receipt = StructureContentReceiptV1(absent_receipt_closure.closure_hash,
            receipt.root_hash, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            receipt.ledger_semantic_bytes, receipt.counters, :terminal_deferred,
            receipt.content_hash, absent_receipt_closure, receipt.prefix_lineage,
            receipt.proposal_lineage, receipt.descriptor_lineage,
            receipt.ledger_snapshot, receipt.budget)
        absent_result = BoundedStructureSearchV1._new_result(:terminal_deferred,
            result.claim_ceiling, false, true, absent_receipt_closure.closure_hash,
            absent_receipt, nothing, result.failures, result.counters,
            result.result_hash)
        # typed_absent_closure_receipt
        @test_throws ArgumentError replay_content_hash(absent_result)

        original_proposal = receipt.proposal_lineage[1]
        non_frozen_proposal = StructureProposalV1(:grammar, 999,
            original_proposal.sequence, original_proposal.candidate_ref,
            original_proposal.parent_prefix_hash, original_proposal.prefix_hash,
            original_proposal.action_hash, original_proposal.closure_hash)
        original_event = receipt.ledger_snapshot.events[1]
        non_frozen_event = BudgetEventV1(:prefixes, 999, original_event.sequence,
            original_event.before, original_event.after, original_event.limit,
            original_event.status)
        non_frozen_snapshot = StructureLedgerSnapshotV1((non_frozen_event,),
            receipt.ledger_snapshot.counter_pairs)
        non_frozen_proposals = (non_frozen_proposal,)
        non_frozen_proposal_bytes = Tuple(BoundedStructureSearchV1._semantic_bytes(
            BoundedStructureSearchV1._proposal_semantic_body(x))
            for x in non_frozen_proposals)
        non_frozen_proposal_hashes = Tuple(BoundedStructureSearchV1._semantic_digest(x)
            for x in non_frozen_proposal_bytes)
        non_frozen_ledger_bytes = BoundedStructureSearchV1._semantic_bytes(
            BoundedStructureSearchV1._ledger_semantic_body(non_frozen_snapshot))
        non_frozen_content = BoundedStructureSearchV1._recomputed_content_hash(
            receipt, receipt.prefix_hashes, non_frozen_proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            non_frozen_proposal_bytes, receipt.descriptor_semantic_bytes,
            non_frozen_ledger_bytes)
        non_frozen_receipt = StructureContentReceiptV1(receipt.closure_hash,
            receipt.root_hash, receipt.prefix_hashes, non_frozen_proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            non_frozen_proposal_bytes, receipt.descriptor_semantic_bytes,
            non_frozen_ledger_bytes, receipt.counters, receipt.status,
            non_frozen_content, receipt.closure, receipt.prefix_lineage,
            non_frozen_proposals, receipt.descriptor_lineage, non_frozen_snapshot,
            receipt.budget)
        non_frozen_result = BoundedStructureSearchV1._result(:screen_only,
            receipt.closure_hash; receipt=non_frozen_receipt,
            failures=result.failures, counters=result.counters)
        # non_frozen_seed_self_consistent_receipt
        @test_throws ArgumentError replay_content_hash(non_frozen_result)
        op_a = make_operational_envelope(101, "2026-09-18T00:00:00Z",
            "2026-09-18T00:00:01Z", "first", ("raw-a",))
        op_b = make_operational_envelope(202, "2026-09-18T01:00:00Z",
            "2026-09-18T01:00:01Z", "second", ("raw-b",))
        with_a = BoundedStructureSearchV1._new_result(result.status, result.claim_ceiling, false, true,
            result.closure_hash, result.content_receipt, op_a, result.failures,
            result.counters, result.result_hash)
        with_b = BoundedStructureSearchV1._new_result(result.status, result.claim_ceiling, false, true,
            result.closure_hash, result.content_receipt, op_b, result.failures,
            result.counters, result.result_hash)
        @test with_a.result_hash == with_b.result_hash
        @test with_a.content_receipt.content_hash == with_b.content_receipt.content_hash
        # receipt_seed_cap_self_consistent_tamper
        zero_seed_budget = StructureSearchBudgetV1(max_seeds=0)
        zero_seed_ledger = BudgetLedgerV1()
        zero_seed_ledger.events = BudgetEventV1[receipt.ledger_snapshot.events...]
        zero_seed_ledger.counters = Dict{Symbol,Int}(receipt.ledger_snapshot.counter_pairs)
        @test_throws ArgumentError make_content_receipt(c, root,
            receipt.prefix_lineage, receipt.proposal_lineage,
            receipt.descriptor_lineage, receipt.counters, receipt.status;
            ledger=zero_seed_ledger, budget=zero_seed_budget)
        zero_seed_content = BoundedStructureSearchV1._recomputed_content_hash(
            receipt, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            receipt.ledger_semantic_bytes; budget=zero_seed_budget)
        zero_seed_receipt = StructureContentReceiptV1(receipt.closure_hash,
            receipt.root_hash, receipt.prefix_hashes, receipt.proposal_hashes,
            receipt.descriptor_hashes, receipt.prefix_semantic_bytes,
            receipt.proposal_semantic_bytes, receipt.descriptor_semantic_bytes,
            receipt.ledger_semantic_bytes, receipt.counters, receipt.status,
            zero_seed_content, receipt.closure, receipt.prefix_lineage,
            receipt.proposal_lineage, receipt.descriptor_lineage,
            receipt.ledger_snapshot, zero_seed_budget)
        zero_seed_result = BoundedStructureSearchV1._result(:screen_only,
            receipt.closure_hash; receipt=zero_seed_receipt,
            failures=result.failures, counters=result.counters)
        @test_throws ArgumentError replay_content_hash(zero_seed_result;
            expected_budget=zero_seed_budget)
    end
end
