"""Static QA for the additive UP3 composition-solve plan contract."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src" / "RuntimeV4" / "CompositionSolvePlanV1.jl"
TEST = ROOT / "test" / "RuntimeV4" / "UP3" / "composition_solve_plan_v1_contract_tests.jl"
FIXTURE = ROOT / "test" / "RuntimeV4" / "UP3" / "composition_solve_plan_v1_fixture.json"
ORACLE = ROOT / "test" / "RuntimeV4" / "UP3" / "composition_solve_plan_v1_oracle.py"

sys.path.insert(0, str(ORACLE.parent))
import composition_solve_plan_v1_oracle as oracle  # noqa: E402


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    result = oracle.validate_fixture(fixture)
    # A short-circuit validator returns Bool.  Assigning that expression to a
    # typed field (for example `pc = x isa T && ... || throw(...)`) is a
    # source-level defect even when the value is semantically truthy.  Keep a
    # generic guard so this regression cannot re-enter under another variable
    # name; the explicit constructor below must retain the validated Symbol.
    bool_assignment_pattern = re.compile(
        r"(?ms)^\s*[A-Za-z_]\w*\s*=\s*[^\n;]*\bisa\b[^\n;]*&&[^\n;]*\|\|"
    )
    unsafe_bool_assignments = bool_assignment_pattern.findall(source)
    assert not unsafe_bool_assignments, (
        "typed-field Bool short-circuit assignment present: "
        + repr(unsafe_bool_assignments)
    )
    assert "preclassification::Symbol" in source
    assert "pc = preclassification" in source
    required_source = (
        "CompositionSolveBindingV1", "CompositionSolveInputV1",
        "CompositionSolvePlanV1", "CompositionSolveOutcomeV1",
        "CompositionSolveReceiptV1", "CompositionSolveAdmissionV1",
        "CompositionSolveProtocolV1", "_csp_compatible",
        "_csp_topological_order", "_csp_missing_binding",
        "provider_invocation_count", "solver_invocation_count",
        ":terminal_deferred", ":fail_closed", ":ready",
        ":direction_mismatch", ":unmatched_port", ":ambiguous_match", ":cycle", ":missing_ledger",
        ":provider_poisoning", ":code_poisoning", ":backend_poisoning",
        "singular_preclassified", "nonconvergent_preclassified",
        "composition_solve_receipt",
        "composition_solve_receipt_from_wire", "raw_composition_solve_receipt",
        "deserialize_composition_solve_receipt",
        "validate_composition_solve_receipt",
        "claim_ceiling=:contract_only", "receipt.status in _CSP_STATUSES",
        "malformed_component",
    )
    missing = [token for token in required_source if token not in source]
    assert not missing, f"missing source contract tokens: {missing}"
    assert fixture["positive"]["stage_spaces"] == ["chain-space-a", "chain-space-b"]
    assert fixture["mimo"] == {
        "status": "ready", "edges": 2, "parallel_component_pairs": 1,
    }
    for forbidden in ("invoke_provider", "execute_once!", "solve_pde", "build_mesh",
                      "default_operator_registry()", "DESC", "ccall(", "run("):
        assert forbidden not in source, f"execution token present: {forbidden}"
    required_test = (
        "module CompositionSolvePlanIsolatedV1", "admit_composition_solve",
        "validate_composition_solve_plan", "composition_solve_receipt",
        "renamed.plan.plan_hash == positive.plan.plan_hash",
        "provider_poisoning", "code_poisoning", "backend_poisoning",
        "protocol_mismatch", "ambiguous_match", "unmatched_port", "cycle",
        "duplicate_component", "duplicate_port", "missing_ledger",
        "direction_mismatch", "negative_coverage", "negative_expectations",
        "preclassification=:singular", "preclassification=:nonconvergent",
        "positive.input.preclassification === :none",
        "singular.input.preclassification === :singular",
        "nonconvergent.input.preclassification === :nonconvergent",
        "invalid_preclassification_bool", "@test_throws ArgumentError C.CompositionSolveInputV1",
        "provider_invocation_count == 0", "solver_invocation_count == 0",
        '"bad-direction"', "invalid_port_direction", "constructor_rejected",
        "_mimo", "mimo-space-a", "mimo-space-b",
        "chain-space-a", "chain-space-b",
        "producer_slot, e.consumer_slot", "binding_missing_matrix", "forged_receipt",
        "ambiguous_with_deferred", "deferred_reasons", "structural_reject",
        "composition_solve_receipt_from_wire", "forged_status",
    )
    missing_test = [token for token in required_test if token not in test]
    assert not missing_test, f"missing executable test seams: {missing_test}"
    assert "_d(c) = digest256_text(String(c))" in test, \
        "fixture digest helper must use the real digest256_text API"
    assert "repeat(" not in test, \
        "fixture must not synthesize digests by padding labels"
    assert not re.search(r"_d\s*\([^)]*\)\s*=\s*Digest256\s*\(", test), \
        "fixture digest helper must not call Digest256 directly on arbitrary labels"
    assert not re.search(r"_d\s*\([^)]*\)\s*=.*Digest256\s*\(.*string\s*\(", test), \
        "fixture digest helper must not wrap non-hex string labels in Digest256"
    expected_vectors = set(fixture["deferred"] + fixture["fail_closed"]
                           + fixture.get("constructor_rejected", []))
    assert set(fixture["negative_expectations"]) == expected_vectors
    missing_vectors = [vector for vector in expected_vectors if vector not in test]
    assert not missing_vectors, f"fixture vectors not represented in test: {missing_vectors}"
    for vector, expectation in fixture["negative_expectations"].items():
        assert expectation["status"] in ("terminal_deferred", "fail_closed",
                                          "constructor_rejected")
        assert expectation["code"]
    assert "include(joinpath(@__DIR__" in test
    assert "using FusionConceptAI" in test
    print(json.dumps({"schema": "CompositionSolvePlanStaticQAV1", "status": "pass",
                      "julia_executed": False, "desc_executed": False,
                      "provider_calls": 0, "solver_calls": 0,
                      "oracle": result}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
