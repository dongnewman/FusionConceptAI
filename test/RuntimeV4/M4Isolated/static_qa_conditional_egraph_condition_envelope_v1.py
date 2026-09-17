"""Static-only QA for the isolated UP5-01 contract slice."""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src" / "RuntimeV4" / "M4Isolated" / "ConditionalEGraphConditionEnvelopeV1.jl"
TEST = ROOT / "test" / "RuntimeV4" / "M4Isolated" / "conditional_egraph_condition_envelope_v1_tests.jl"
FIXTURE = ROOT / "test" / "RuntimeV4" / "M4Isolated" / "conditional_egraph_condition_envelope_v1_fixture.json"


def _source_delimiters_are_balanced(source: str) -> bool:
    """Conservative delimiter check that ignores Julia strings/comments."""
    pairs = {"(": ")", "[": "]", "{": "}"}
    stack: list[str] = []
    state: str | None = None
    i = 0
    while i < len(source):
        if state == "triple":
            if source.startswith('"""', i):
                state = None
                i += 3
            else:
                i += 1
            continue
        if state in {'"', "'"}:
            if source[i] == "\\":
                i += 2
            elif source[i] == state:
                state = None
                i += 1
            else:
                i += 1
            continue
        if source.startswith('"""', i):
            state = "triple"
            i += 3
            continue
        if source[i] in {'"', "'"}:
            state = source[i]
            i += 1
            continue
        if source[i] == "#":
            newline = source.find("\n", i)
            i = len(source) if newline < 0 else newline + 1
            continue
        token = source[i]
        if token in pairs:
            stack.append(token)
        elif token in pairs.values():
            if not stack or pairs[stack.pop()] != token:
                return False
        i += 1
    return state is None and not stack


def _generator_extra_argument_lines(source: str) -> list[int]:
    """Find unparenthesized generator expressions followed by an extra arg."""
    risky = re.compile(r"\b(?:join|map|filter|reduce|collect|Tuple)\(\s*[^()\n]*\bfor\b[^()\n]*,")
    return [line_no for line_no, line in enumerate(source.splitlines(), 1) if risky.search(line)]


def _sort_generator_lines(source: str) -> list[int]:
    """Find direct sort(generator) calls; collect/typed-vector forms are valid."""
    risky = re.compile(
        r"\bsort!?\(\s*(?!collect\()(?!(?:[A-Za-z_]\w*)\s*\[)[^,\n]*\bfor\b"
    )
    return [line_no for line_no, line in enumerate(source.splitlines(), 1) if risky.search(line)]


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    assert _source_delimiters_are_balanced(source), "source delimiter/string boundary is unbalanced"
    assert source.lstrip().startswith('"""'), "source documentation boundary is missing"
    assert re.search(r"\bmodule\s+ConditionalEGraphConditionEnvelopeV1\b", source), "module boundary is missing"
    assert source.rstrip().endswith("end"), "source must end at the module boundary"
    assert not _generator_extra_argument_lines(source), "generator expression has an unparenthesized extra argument"
    assert not _sort_generator_lines(source), "sort/sort! must not receive a direct generator"
    assert "sort!(String[String(x) for x in missing_refs])" in source
    assert "sort!(String[String(x) for x in unmet_refs])" in source
    assert "sort!(String[String(x) for x in contradiction_refs])" in source
    assert 'join((_encode(y) for y in x), ";")' in source, "tuple canonical join must parenthesize generator"
    required = (
        "conditions_met", "condition_unmet", "equality_unknown", "fail_closed",
        "incomplete", "unit", "rank", "domain", "boundary", "time", "effect",
        "conservation", "foreign receipt token", "stale receipt token",
        "trace identity mismatch", "cache hash mismatch", "cold_canonical_bytes",
        "hot_canonical_bytes", "cold_canonical_hash", "hot_canonical_hash",
        "evaluation_hash_mismatch", "replayed result requires merged receipt",
        "non-replayed result must be zero-merge",
    )
    missing = [token for token in required if token not in source and token not in test]
    assert not missing, f"missing contract markers: {missing}"
    for call in (
        "evaluate_conditions(", "replay_merge(", "cache_put!(", "hot_canonical_bytes(",
        "hot_canonical_hash(", "make_saturation_receipt(",
        "validate_replay_receipt(", "validate_replay_result(",
        "for vector in UP5_01_CONDITION_REPLAY_CONTRACT.negative_vectors",
        "MergeReplayResultV1(false, :incomplete, nothing)",
        "RewriteTraceStepV1(step, evaluation)",
        "bind_evaluation=false",
        "bound_met.evaluation_hash == met.evaluation_hash",
        "bound_met.source_hash == step.source_hash",
        "bound_met.target_hash == step.target_hash",
        "bound_met.rule_hash == step.rule_hash",
        "bound_met.registry_hash == step.registry_hash",
        "bound_met.budget_hash == step.budget_hash",
        "foreign_token_bound_unmet", "foreign_source_bound_unmet",
        "foreign_target_bound_unmet", "foreign_rule_bound_unmet",
        "foreign_registry_bound_unmet", "foreign_budget_bound_unmet",
        "replay_merge(bound_step, evaluation",
        "missing_multi.missing_refs == (\"alpha\", \"middle\", \"zeta\")",
        "unmet_multi.unmet_refs == (\"alpha\", \"middle\", \"zeta\")",
        "contradiction_multi.contradiction_refs == (\"alpha\", \"middle\", \"zeta\")",
        "ConditionEvaluationV1(:fail_closed,\n        (\"overlap\",), (), (\"overlap\",))",
    ):
        assert call in test, f"missing executable seam call: {call}"
    assert "_validate_replay_identity(step, evaluation" in source
    assert "function RewriteTraceStepV1(step::RewriteTraceStepV1" in source
    assert "push!(exercised_vectors, vector)" in test
    assert "exercised_vectors == Set(UP5_01_CONDITION_REPLAY_CONTRACT.negative_vectors)" in test
    assert "@test length(exercised_vectors) == 24" in test
    assert "for vector in UP5_01_CONDITION_REPLAY_CONTRACT.negative_vectors" in test
    assert '"$(String(vector))"' in test
    assert "@testset String(" not in test
    expression_testset_lines = [
        line_no for line_no, line in enumerate(test.splitlines(), 1)
        if re.search(r"@testset\s+(?!\")\S", line)
    ]
    assert not expression_testset_lines, f"expression-style @testset name at lines {expression_testset_lines}"
    assert "step.evaluation_hash == evaluation.evaluation_hash" in source
    helper_start = source.index("function _validate_replay_identity")
    replay_start = source.index("function replay_merge")
    helper_body = source[helper_start:replay_start]
    assert "step.condition_status === evaluation.status" in helper_body
    assert "validate_token(step.token" in helper_body
    assert source.index("_validate_replay_identity(step, evaluation", replay_start) < source.index(
        "if evaluation.status !== :conditions_met", replay_start
    )
    assert fixture["schema"] == "ConditionalEGraphConditionEnvelopeFixtureV1"
    assert fixture["status"] == "contract_only"
    assert fixture["claim_ceiling"] == "screen_only"
    assert fixture["accepted"] is False and fixture["no_publish"] is True
    assert set(fixture["required_axes"]) == {
        "unit", "rank", "domain", "boundary", "time", "effect", "conservation"
    }
    assert len(fixture["negative_vectors"]) == 24
    assert set(fixture["bound_unmet_identity_vectors"]) == {
        "foreign_token_bound_unmet", "foreign_source_bound_unmet",
        "foreign_target_bound_unmet", "foreign_rule_bound_unmet",
        "foreign_registry_bound_unmet", "foreign_budget_bound_unmet",
    }
    for vector in fixture["negative_vectors"]:
        assert f":{vector}" in test, f"frozen vector missing from executable test: {vector}"
    print(json.dumps({
        "record_kind": "UP5-01-condition-replay-static-qa",
        "status": "pass",
        "julia_executed": False,
        "desc_executed": False,
        "accepted": False,
        "claim_ceiling": "screen_only",
        "formal_credit": "none",
        "negative_vector_count": len(fixture["negative_vectors"]),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
