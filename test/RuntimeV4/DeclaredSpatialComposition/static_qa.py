"""Python-only static QA for UP2/UP3 declared spatial composition.

It intentionally does not execute Julia, DESC, or any provider.  The focused
Julia test is delivered for the repository runner but is not launched here.
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]
SOURCE = ROOT / "src" / "RuntimeV4" / "DeclaredSpatialCompositionExecutionV1.jl"
TEST = BASE / "declared_spatial_composition_execution_v1_tests.jl"
FIXTURE = BASE / "fixture.json"
ORACLE = BASE / "independent_oracle.py"

sys.path.insert(0, str(BASE))
import independent_oracle as oracle  # noqa: E402


def _masked_julia(source: str) -> str:
    """Mask strings/comments while preserving newlines and delimiter positions."""
    out = list(source)
    i = 0
    state = None
    while i < len(source):
        if state is None:
            if source.startswith('"""', i):
                state = "triple"
                out[i:i + 3] = "   "
                i += 3
                continue
            if source[i] == '"':
                state = "double"
                out[i] = " "
                i += 1
                continue
            if source[i] == "'":
                state = "single"
                out[i] = " "
                i += 1
                continue
            if source[i] == '#':
                state = "comment"
                out[i] = " "
                i += 1
                continue
            i += 1
            continue
        if state == "comment":
            if source[i] == "\n":
                state = None
            else:
                out[i] = " "
            i += 1
            continue
        if state == "triple" and source.startswith('"""', i):
            out[i:i + 3] = "   "
            i += 3
            state = None
            continue
        if state == "double" and source[i] == '"':
            out[i] = " "
            i += 1
            state = None
            continue
        if state == "single" and source[i] == "'":
            out[i] = " "
            i += 1
            state = None
            continue
        if source[i] == "\\" and state in ("double", "single"):
            out[i] = " "
            if i + 1 < len(source):
                out[i + 1] = "\n" if source[i + 1] == "\n" else " "
                i += 2
            else:
                i += 1
            continue
        if source[i] != "\n":
            out[i] = " "
        i += 1
    return "".join(out)


def delimiter_balance(source: str, label: str) -> dict:
    masked = _masked_julia(source)
    pairs = {"(": ")", "[": "]", "{": "}"}
    reverse = {v: k for k, v in pairs.items()}
    stack = []
    for pos, char in enumerate(masked):
        if char in pairs:
            line = masked.count("\n", 0, pos) + 1
            stack.append((char, line))
        elif char in reverse:
            if not stack or stack[-1][0] != reverse[char]:
                line = masked.count("\n", 0, pos) + 1
                raise AssertionError(f"{label}: mismatched {char} at line {line}")
            stack.pop()
    assert not stack, f"{label}: unclosed delimiters {stack}"
    return {"status": "balanced", "delimiter_count": 0}


def block_balance(source: str, label: str) -> dict:
    """Conservative Julia block check without launching Julia."""
    text = _masked_julia(source)
    stack = []
    opener = re.compile(r'^(?:function|struct|if|for|while|try|begin|let|macro|module|quote)\b|^@testset\b.*\bbegin\b|=\s*(?:if|begin)\b')
    paren_depth = 0
    for line_no, line in enumerate(text.splitlines(), 1):
        code = line.split("#", 1)[0].strip()
        is_generator_for = code.startswith("for ") and paren_depth > 0
        if opener.search(code) and not is_generator_for:
            stack.append((line_no, code))
        elif re.match(r'^end\b', code):
            if not stack:
                raise AssertionError(f"{label}: unmatched end at Julia line {line_no}")
            stack.pop()
        paren_depth += line.count("(") - line.count(")")
    if stack:
        raise AssertionError(f"{label}: unclosed Julia blocks: {stack}")
    return {"status": "balanced", "block_count": 0}


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    oracle_source = ORACLE.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    oracle_result = oracle.validate_fixture(fixture)
    parse_result = {
        "source_blocks": block_balance(source, "source"),
        "test_blocks": block_balance(test, "test"),
        "source_delimiters": delimiter_balance(source, "source"),
        "test_delimiters": delimiter_balance(test, "test"),
    }

    required_source = (
        "DeclaredSpatialGeometryV1", "DeclaredSpatialBoundaryV1", "DeclaredSpatialFieldV1",
        "DeclaredSpatialPortV1", "DeclaredSpatialComponentV1", "DeclaredSpatialCompositionV1",
        "DeclaredSpatialCaseV1", "measure_overlap_transfer", "auto_typed_port_edges",
        "assemble_declared_spatial_fv", "execute_declared_spatial_composition",
        "declared_spatial_mms_refinement", "_dsc_harmonic", "face_transmissibility",
        "conservation_residual", "interface_flux_residual", "ledger_residual",
        "semantic_view", "canonical_hash", "payload", "edge_payload_hash",
        "_dsc_expected_k_hash", "_dsc_expected_source_hash", "source_hash",
        "effective_source", "effective_boundary", "coupling_gain", ":neumann",
        "uface", "cell_conductivity", "face_positions", "left_flux", "right_flux",
        "_dsc_edge_payload", "_dsc_boundary_payload", "A .*= coupling_gain",
        "source_payload_mismatch", "boundary_payload_mismatch",
        "geometry_hash_mismatch", "nonoverlap", "nonfinite_K", "pure_neumann_singular",
        "missing_return", "duplicate_producer", "unit_mismatch", "missing_boundary",
        "solver_invocations", "provider_calls", "formal_up_credit", "formal_r_credit",
        "formal_l4_credit", "screen_only", "accepted=false", "DSC_SCHEMA_V1",
    )
    missing = [token for token in required_source if token not in source]
    assert not missing, f"missing source seams: {missing}"
    assert "T0" not in source and "default_operator_registry" not in source
    assert not re.search(r"\b(?:provider|mesh|DESC)\s*\(", source, re.I)
    assert "include(" not in source and "using FusionConceptAI" not in source
    assert "candidate_ref" not in source and "UP_CREDIT" not in source
    assert "p = if plan === nothing" in source and ")), plan\n" not in source

    required_test = (
        "measure overlap and label/order erasure", "two K/BC groups are real numerical/hash drivers",
        "duplicate_producer", "unit_mismatch", "missing_boundary", "nonoverlap", "nonfinite_K",
        "pure_neumann_singular", "missing_return", "geometry_hash_change", "fixture.negative_expectations",
        "solver_invocations == 1", "provider_calls == 0", "mms_order >= 1.8",
        "conservation_residual <= 1e-12", "interface_flux_residual <= 1e-10",
        "joint_residual <= 1e-12", "ledger_residual <= 1e-12",
        "payload_scaled", "canonical field hashes and Neumann RHS contribution",
        "holdout-independent", "bad_k_hash", "source_payload_mismatch",
        "pure_neumann_probe", "expected_status", "expected_code",
    )
    missing_test = [token for token in required_test if token not in test]
    assert not missing_test, f"missing test gates: {missing_test}"
    assert "pure_neumann_matrix" in oracle_source
    assert set(fixture["negative_expectations"]) == {
        "duplicate_producer", "unit_mismatch", "missing_boundary", "nonoverlap",
        "nonfinite_K", "pure_neumann_singular", "missing_return", "geometry_hash_change",
    }
    assert fixture["claim_ceiling"] == "screen_only"
    assert fixture["accepted"] is False
    assert fixture["formal_credit"] == {"up": False, "r": False, "l4": False}
    assert fixture["execution"]["provider_calls"] == 0
    assert fixture["execution"]["solver_invocations"] == 1
    assert fixture["execution"]["julia_executed"] is False
    assert fixture["execution"]["desc_executed"] is False
    assert fixture["holdout"]["case_ref"] == "holdout-independent"
    assert "candidate" not in fixture["holdout"]["case_ref"].lower()
    assert fixture["neumann_probe"]["expected_boundary_rhs_contribution"] == 0.3
    assert fixture["pure_neumann_probe"]["expected_status"] == "numerical_fail"
    assert fixture["pure_neumann_probe"]["expected_code"] == "pure_neumann_singular"

    digest = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    print(json.dumps({
        "schema": "DeclaredSpatialCompositionStaticQAV1", "status": "pass",
        "julia_executed": False, "desc_executed": False, "provider_calls": 0,
        "solver_invocations": 1, "source_sha256": digest, "oracle": oracle_result,
        "parse": parse_result,
        "gaps": fixture["gaps"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
