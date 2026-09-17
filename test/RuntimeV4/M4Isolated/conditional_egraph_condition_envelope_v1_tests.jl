"""Executable focused tests for the isolated UP5-01 contract.

The parent serialized lane owns Julia execution. The tests are nevertheless
fully wired to the isolated include so that a later run exercises real calls,
not marker-only assertions.
"""

using Test
include(joinpath(@__DIR__, "../../../src/RuntimeV4/M4Isolated/ConditionalEGraphConditionEnvelopeV1.jl"))
using .ConditionalEGraphConditionEnvelopeV1

const UP5_01_CONDITION_REPLAY_CONTRACT = (
    claim_ceiling=:screen_only, accepted=false, no_publish=true,
    negative_vectors=(
        :missing_condition, :mismatched_unit, :mismatched_rank,
        :mismatched_domain, :mismatched_boundary, :mismatched_time,
        :mismatched_effect, :mismatched_conservation, :contradictory_available,
        :stale_token, :foreign_token, :tampered_trace, :foreign_registry,
        :foreign_rule, :foreign_source, :budget_mismatch,
        :foreign_token_bound_unmet, :foreign_source_bound_unmet,
        :foreign_target_bound_unmet, :foreign_rule_bound_unmet,
        :foreign_registry_bound_unmet, :foreign_budget_bound_unmet,
        :evaluation_hash_mismatch, :incomplete_not_inequality))

const SIG = ConditionSignatureV1("m", 3, "scalar_field", "closed", "static", "pure", "balanced")
const REQ = RequiredConditionV1("condition-1", SIG)
const REQUIRED = RequiredConditionCatalogV1((REQ,))
const SOURCE_HASH = digest_text("source")
const TARGET_HASH = digest_text("target")
const RULE_HASH = digest_text("rule")
const REGISTRY_HASH = digest_text("registry")
const BUDGET_HASH = digest_text("budget")
const TOKEN_CONTENT_HASH = digest_text(canonical_bytes((source_hash=SOURCE_HASH,
    target_hash=TARGET_HASH, rule_hash=RULE_HASH, registry_hash=REGISTRY_HASH,
    budget_hash=BUDGET_HASH)))

function _available(signature=SIG; observation="observation")
    AvailableConditionCatalogV1((AvailableConditionV1("condition-1", signature,
        digest_text(observation)),))
end

function _met_trace(; generation=7)
    evaluation = evaluate_conditions(REQUIRED, _available())
    token = ReceiptTokenV1("owner", generation, :rewrite_trace, TOKEN_CONTENT_HASH)
    RewriteTraceStepV1(1, SOURCE_HASH, TARGET_HASH, RULE_HASH, REGISTRY_HASH,
        BUDGET_HASH, evaluation, token)
end

function _unmet_evaluation()
    altered = ConditionSignatureV1("wrong", SIG.rank, SIG.domain, SIG.boundary,
        SIG.time, SIG.effect, SIG.conservation)
    evaluate_conditions(REQUIRED, _available(altered))
end

function _bound_unmet_step(; source_hash=SOURCE_HASH, target_hash=TARGET_HASH,
        rule_hash=RULE_HASH, registry_hash=REGISTRY_HASH, budget_hash=BUDGET_HASH,
        token=ReceiptTokenV1("owner", 7, :rewrite_trace, TOKEN_CONTENT_HASH))
    met = evaluate_conditions(REQUIRED, _available())
    evaluation = _unmet_evaluation()
    base = RewriteTraceStepV1(1, source_hash, target_hash, rule_hash,
        registry_hash, budget_hash, met, token)
    RewriteTraceStepV1(base, evaluation), evaluation
end

function _replay(step, evaluation; bind_evaluation=true, kwargs...)
    bound_step = bind_evaluation ? RewriteTraceStepV1(step, evaluation) : step
    replay_merge(bound_step, evaluation; owner="owner", source_hash=SOURCE_HASH,
        target_hash=TARGET_HASH, rule_hash=RULE_HASH, registry_hash=REGISTRY_HASH,
        budget_hash=BUDGET_HASH, expected_generation=7, kwargs...)
end

function _assert_rejected(result, status::Symbol)
    @test !result.merged && result.receipt === nothing
    @test result.status === status
    @test validate_replay_result(result)
    @test result.result_hash == digest_text(canonical_bytes(
        (merged=false, status=status, receipt_hash=nothing)))
end

@testset "UP5-01 isolated condition/replay contract" begin
    @test UP5_01_CONDITION_REPLAY_CONTRACT.claim_ceiling === :screen_only
    @test UP5_01_CONDITION_REPLAY_CONTRACT.accepted === false
    @test UP5_01_CONDITION_REPLAY_CONTRACT.no_publish === true

    met = evaluate_conditions(REQUIRED, _available())
    @test met.status === :conditions_met
    @test isempty(met.missing_refs) && isempty(met.unmet_refs) && isempty(met.contradiction_refs)
    @test met.evaluation_hash == digest_text(canonical_bytes(
        (status=:conditions_met, missing=(), unmet=(), contradictions=())))

    step = _met_trace()
    bound_met = RewriteTraceStepV1(step, met)
    @test bound_met.evaluation_hash == met.evaluation_hash
    @test bound_met.source_hash == step.source_hash && bound_met.target_hash == step.target_hash
    @test bound_met.rule_hash == step.rule_hash && bound_met.registry_hash == step.registry_hash
    @test bound_met.budget_hash == step.budget_hash && bound_met.condition_status == met.status
    @test bound_met.token.owner == step.token.owner &&
        bound_met.token.generation == step.token.generation &&
        bound_met.token.scope === step.token.scope &&
        bound_met.token.content_hash == step.token.content_hash
    result = _replay(step, met)
    @test result.merged && result.status === :replayed
    @test result.receipt !== nothing
    @test validate_replay_receipt(result.receipt, met; owner="owner",
        source_hash=SOURCE_HASH, target_hash=TARGET_HASH, rule_hash=RULE_HASH,
        registry_hash=REGISTRY_HASH, budget_hash=BUDGET_HASH,
        expected_generation=7)
    @test validate_replay_result(result)
    @test result.result_hash == digest_text(canonical_bytes(
        (merged=true, status=:replayed, receipt_hash=result.receipt.receipt_hash)))

    value = (kind=:cold_hot_probe, count=3)
    cold_bytes = cold_canonical_bytes(value)
    cold_hash = cold_canonical_hash(value)
    cache = CanonicalCacheV1("owner"; generation=7)
    cache_put!(cache, "probe", value)
    @test hot_canonical_bytes(cache, "probe", cold_hash) == cold_bytes
    @test hot_canonical_hash(cache, "probe", cold_hash) == cold_hash
    stale_cache = CanonicalCacheV1("owner"; generation=7)
    cache_put!(stale_cache, "probe", value)
    stale_cache.generation = 8
    @test_throws ArgumentError hot_canonical_hash(stale_cache, "probe", cold_hash)

    incomplete = make_saturation_receipt(SOURCE_HASH, RULE_HASH, REGISTRY_HASH,
        BUDGET_HASH, digest_text("trace"); complete=false)
    @test incomplete.status === :incomplete && incomplete.equivalence === :unknown

    @test_throws ArgumentError ConditionEvaluationV1(:conditions_met, ("missing",), (), ())
    @test_throws ArgumentError ConditionEvaluationV1(:equality_unknown, (), (), ())
    @test_throws ArgumentError ConditionEvaluationV1(:fail_closed, (), (), ())
    missing_multi = ConditionEvaluationV1(:equality_unknown,
        ("zeta", "alpha", "middle"), (), ())
    @test missing_multi.missing_refs == ("alpha", "middle", "zeta")
    unmet_multi = ConditionEvaluationV1(:condition_unmet, (),
        ("zeta", "alpha", "middle"), ())
    @test unmet_multi.unmet_refs == ("alpha", "middle", "zeta")
    contradiction_multi = ConditionEvaluationV1(:fail_closed, (), (),
        ("zeta", "alpha", "middle"))
    @test contradiction_multi.contradiction_refs == ("alpha", "middle", "zeta")
    @test_throws ArgumentError ConditionEvaluationV1(:fail_closed,
        ("overlap",), (), ("overlap",))

    # Every frozen vector is exercised against the real isolated functions.
    exercised_vectors = Set{Symbol}()
    for vector in UP5_01_CONDITION_REPLAY_CONTRACT.negative_vectors
        push!(exercised_vectors, vector)
        @testset "$(String(vector))" begin
            if vector === :missing_condition
                evaluation = evaluate_conditions(REQUIRED, AvailableConditionCatalogV1(()))
                @test evaluation.status === :equality_unknown
                rejected = _replay(step, evaluation)
                _assert_rejected(rejected, :equality_unknown)
            elseif vector in (:mismatched_unit, :mismatched_rank, :mismatched_domain,
                              :mismatched_boundary, :mismatched_time, :mismatched_effect,
                              :mismatched_conservation)
                field = vector === :mismatched_unit ? :unit :
                    vector === :mismatched_rank ? :rank :
                    vector === :mismatched_domain ? :domain :
                    vector === :mismatched_boundary ? :boundary :
                    vector === :mismatched_time ? :time :
                    vector === :mismatched_effect ? :effect : :conservation
                altered = ConditionSignatureV1(field === :unit ? "wrong" : SIG.unit,
                    field === :rank ? 99 : SIG.rank,
                    field === :domain ? "wrong" : SIG.domain,
                    field === :boundary ? "wrong" : SIG.boundary,
                    field === :time ? "wrong" : SIG.time,
                    field === :effect ? "wrong" : SIG.effect,
                    field === :conservation ? "wrong" : SIG.conservation)
                evaluation = evaluate_conditions(REQUIRED, _available(altered))
                @test evaluation.status === :condition_unmet
                rejected = _replay(step, evaluation)
                _assert_rejected(rejected, :condition_unmet)
            elseif vector === :contradictory_available
                rows = (AvailableConditionV1("condition-1", SIG, digest_text("a")),
                        AvailableConditionV1("condition-1", SIG, digest_text("b")))
                evaluation = evaluate_conditions(REQUIRED, AvailableConditionCatalogV1(rows))
                @test evaluation.status === :fail_closed
                rejected = _replay(step, evaluation)
                _assert_rejected(rejected, :fail_closed)
            elseif vector === :stale_token
                _assert_rejected(_replay(_met_trace(generation=6), met), :fail_closed)
            elseif vector === :foreign_token
                foreign = ReceiptTokenV1("foreign-owner", 7, :rewrite_trace, TOKEN_CONTENT_HASH)
                foreign_step = RewriteTraceStepV1(1, SOURCE_HASH, TARGET_HASH, RULE_HASH,
                    REGISTRY_HASH, BUDGET_HASH, met, foreign)
                _assert_rejected(_replay(foreign_step, met), :fail_closed)
            elseif vector === :tampered_trace
                tampered = RewriteTraceStepV1(1, SOURCE_HASH, digest_text("tampered-target"), RULE_HASH,
                    REGISTRY_HASH, BUDGET_HASH, met,
                    ReceiptTokenV1("owner", 7, :rewrite_trace, TOKEN_CONTENT_HASH))
                _assert_rejected(_replay(tampered, ConditionEvaluationV1(
                    :conditions_met, (), (), ())), :fail_closed)
            elseif vector === :foreign_registry
                _assert_rejected(replay_merge(step, met; owner="owner",
                    source_hash=SOURCE_HASH, target_hash=TARGET_HASH, rule_hash=RULE_HASH,
                    registry_hash=digest_text("foreign-registry"), budget_hash=BUDGET_HASH,
                    expected_generation=7), :fail_closed)
            elseif vector === :foreign_rule
                _assert_rejected(replay_merge(step, met; owner="owner",
                    source_hash=SOURCE_HASH, target_hash=TARGET_HASH, rule_hash=digest_text("foreign-rule"),
                    registry_hash=REGISTRY_HASH, budget_hash=BUDGET_HASH, expected_generation=7), :fail_closed)
            elseif vector === :foreign_source
                _assert_rejected(replay_merge(step, met; owner="owner",
                    source_hash=digest_text("foreign-source"), target_hash=TARGET_HASH,
                    rule_hash=RULE_HASH, registry_hash=REGISTRY_HASH, budget_hash=BUDGET_HASH,
                    expected_generation=7), :fail_closed)
            elseif vector === :budget_mismatch
                _assert_rejected(replay_merge(step, met; owner="owner",
                    source_hash=SOURCE_HASH, target_hash=TARGET_HASH, rule_hash=RULE_HASH,
                    registry_hash=REGISTRY_HASH, budget_hash=digest_text("foreign-budget"),
                    expected_generation=7), :fail_closed)
            elseif vector === :foreign_token_bound_unmet
                bound_step, evaluation = _bound_unmet_step(
                    token=ReceiptTokenV1("foreign-owner", 7, :rewrite_trace, TOKEN_CONTENT_HASH))
                _assert_rejected(replay_merge(bound_step, evaluation; owner="owner",
                    source_hash=SOURCE_HASH, target_hash=TARGET_HASH, rule_hash=RULE_HASH,
                    registry_hash=REGISTRY_HASH, budget_hash=BUDGET_HASH,
                    expected_generation=7), :fail_closed)
            elseif vector === :foreign_source_bound_unmet
                bound_step, evaluation = _bound_unmet_step(source_hash=digest_text("foreign-source"))
                _assert_rejected(replay_merge(bound_step, evaluation; owner="owner",
                    source_hash=SOURCE_HASH, target_hash=TARGET_HASH, rule_hash=RULE_HASH,
                    registry_hash=REGISTRY_HASH, budget_hash=BUDGET_HASH,
                    expected_generation=7), :fail_closed)
            elseif vector === :foreign_target_bound_unmet
                bound_step, evaluation = _bound_unmet_step(target_hash=digest_text("foreign-target"))
                _assert_rejected(replay_merge(bound_step, evaluation; owner="owner",
                    source_hash=SOURCE_HASH, target_hash=TARGET_HASH, rule_hash=RULE_HASH,
                    registry_hash=REGISTRY_HASH, budget_hash=BUDGET_HASH,
                    expected_generation=7), :fail_closed)
            elseif vector === :foreign_rule_bound_unmet
                bound_step, evaluation = _bound_unmet_step(rule_hash=digest_text("foreign-rule"))
                _assert_rejected(replay_merge(bound_step, evaluation; owner="owner",
                    source_hash=SOURCE_HASH, target_hash=TARGET_HASH, rule_hash=RULE_HASH,
                    registry_hash=REGISTRY_HASH, budget_hash=BUDGET_HASH,
                    expected_generation=7), :fail_closed)
            elseif vector === :foreign_registry_bound_unmet
                bound_step, evaluation = _bound_unmet_step(registry_hash=digest_text("foreign-registry"))
                _assert_rejected(replay_merge(bound_step, evaluation; owner="owner",
                    source_hash=SOURCE_HASH, target_hash=TARGET_HASH, rule_hash=RULE_HASH,
                    registry_hash=REGISTRY_HASH, budget_hash=BUDGET_HASH,
                    expected_generation=7), :fail_closed)
            elseif vector === :foreign_budget_bound_unmet
                bound_step, evaluation = _bound_unmet_step(budget_hash=digest_text("foreign-budget"))
                _assert_rejected(replay_merge(bound_step, evaluation; owner="owner",
                    source_hash=SOURCE_HASH, target_hash=TARGET_HASH, rule_hash=RULE_HASH,
                    registry_hash=REGISTRY_HASH, budget_hash=BUDGET_HASH,
                    expected_generation=7), :fail_closed)
            elseif vector === :evaluation_hash_mismatch
                different = ConditionEvaluationV1(:condition_unmet, (), ("condition-1",), ())
                @test different.evaluation_hash != met.evaluation_hash
                _assert_rejected(_replay(step, different; bind_evaluation=false), :fail_closed)
            elseif vector === :incomplete_not_inequality
                incomplete_result = MergeReplayResultV1(false, :incomplete, nothing)
                _assert_rejected(incomplete_result, :incomplete)
                @test_throws ArgumentError make_saturation_receipt(SOURCE_HASH, RULE_HASH,
                    REGISTRY_HASH, BUDGET_HASH, digest_text("trace");
                    complete=false, equivalence=:not_equivalent)
            end
        end
    end
    @test exercised_vectors == Set(UP5_01_CONDITION_REPLAY_CONTRACT.negative_vectors)
    @test length(exercised_vectors) == 24
end
