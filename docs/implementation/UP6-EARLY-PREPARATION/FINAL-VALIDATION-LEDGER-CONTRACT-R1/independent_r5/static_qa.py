"""Independent R5 read-only QA for FinalValidationLedgerContractV1.

This checker only reads source, test and fixture bytes.  It never starts Julia,
DESC, a provider, a solver, or a runtime process.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parents[5]
SOURCE = ROOT / "src/RuntimeV4/FinalValidationLedgerContractV1.jl"
TEST = ROOT / "test/RuntimeV4/final_validation_ledger_contract_v1_tests.jl"
FIXTURE = ROOT / "test/RuntimeV4/fixtures/final_validation_ledger_contract_v1.json"
ROOT_QA = ROOT / "docs/implementation/UP6-EARLY-PREPARATION/FINAL-VALIDATION-LEDGER-CONTRACT-R1/static_qa.py"


_OPEN_TO_CLOSE = {"(": ")", "[": "]", "{": "}"}
_CLOSE_TO_OPEN = {close: open_ for open_, close in _OPEN_TO_CLOSE.items()}


def julia_delimiter_pairs(text: str) -> tuple[dict[int, int] | None, str]:
    """Deterministic lexical delimiter precheck; Julia parser is not run."""
    stack: list[tuple[str, int]] = []
    pairs: dict[int, int] = {}
    i = 0
    state = "code"
    quote = ""
    block_comment_depth = 0
    while i < len(text):
        if state == "line_comment":
            if text[i] == "\n":
                state = "code"
            i += 1
            continue
        if state == "block_comment":
            if text.startswith("#=", i):
                block_comment_depth += 1
                i += 2
            elif text.startswith("=#", i):
                block_comment_depth -= 1
                i += 2
                if block_comment_depth == 0:
                    state = "code"
            else:
                i += 1
            continue
        if state == "string":
            if text.startswith(quote, i):
                i += len(quote)
                state = "code"
            elif text[i] == "\\":
                i += 2
            else:
                i += 1
            continue
        if text.startswith("#=", i):
            state = "block_comment"
            block_comment_depth = 1
            i += 2
            continue
        if text[i] == "#":
            state = "line_comment"
            i += 1
            continue
        if text.startswith('"""', i):
            state = "string"
            quote = '"""'
            i += 3
            continue
        if text[i] in ('"', "'"):
            state = "string"
            quote = text[i]
            i += 1
            continue
        if text[i] in _OPEN_TO_CLOSE:
            stack.append((text[i], i))
        elif text[i] in _CLOSE_TO_OPEN:
            if not stack:
                return None, f"unmatched closing {text[i]!r} at offset {i}"
            opening, opening_index = stack.pop()
            if opening != _CLOSE_TO_OPEN[text[i]]:
                return None, (
                    f"mismatched {opening!r} at offset {opening_index} "
                    f"with {text[i]!r} at offset {i}"
                )
            pairs[opening_index] = i
        i += 1
    if state == "block_comment":
        return None, "unterminated Julia block comment"
    if state == "string":
        return None, "unterminated Julia quoted string"
    if stack:
        opening, opening_index = stack[-1]
        return None, f"unmatched opening {opening!r} at offset {opening_index}"
    return pairs, "lexical delimiter scan balanced (Julia parser not executed)"


def fixture_dispatch_closure(test: str, fixture_negative_ids: set[str]) -> tuple[bool, str]:
    pairs, delimiter_detail = julia_delimiter_pairs(test)
    if pairs is None:
        return False, f"dispatch closure blocked by {delimiter_detail}"
    matches = list(re.finditer(
        r'id == "([^"]+)"\s*&&\s*return\s+validate_final_validation_ledger\s*\(',
        test,
    ))
    dispatch_ids = [match.group(1) for match in matches]
    missing = sorted(fixture_negative_ids.difference(dispatch_ids))
    duplicate_ids = sorted({item for item in dispatch_ids if dispatch_ids.count(item) > 1})
    unclosed = [match.group(1) for match in matches if match.end() - 1 not in pairs]
    if missing or duplicate_ids or unclosed:
        return False, (
            f"missing={missing}; duplicate={duplicate_ids}; "
            f"unclosed={unclosed}"
        )
    return True, f"{len(dispatch_ids)} fixture dispatch calls are individually closed"


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    checks: list[dict[str, object]] = []

    def check(name: str, passed: bool, detail: str) -> None:
        checks.append({"name": name, "pass": bool(passed), "detail": detail})

    required_r = [f"R{i:02d}" for i in range(1, 11)]
    engineering = fixture.get("engineering_families", [])
    negatives = fixture.get("negative", [])
    negative_ids = [item.get("id") for item in negatives]
    dispatch_ids = set(re.findall(r'id == "([^"]+)"', test))

    check("identity:all-four-new-hashes", all(
        f"x.{field} === nothing" in source for field in (
            "mission_hash", "mechanism_hash", "field_geometry_hash",
            "realization_control_hash")), "all four upstream identity hashes are missing-sensitive")
    check("evidence:four-axis-binding", all(token in source for token in (
        "evidence.candidate_ref", "evidence.physical_subject_hash",
        "evidence.solver_input_hash", "evidence.scenario_ref",
        "evidence_binding_mismatch")), "evidence refs are checked against ledger identity")
    check("obligation:required-fail-closed", "row.required === true || push!(fail_closed" in source,
          "required=false cannot pass silently")
    check("obligations:exact-set", fixture.get("required_r_ids") == required_r
          and len(engineering) == 15 and len(set(engineering)) == 15,
          "fixture carries exactly R01-R10 plus 15 ENG families")
    check("tests:fixture-driven", "using JSON3" in test and "_FVLC_FIXTURE = JSON3.read" in test
          and "_FVLC_NEGATIVE_IDS = Tuple(String(x.id) for x in _FVLC_FIXTURE.negative)" in test,
          "Julia test derives obligation and negative vectors from fixture")
    for label, text in (("source", source), ("test", test)):
        delimiters, detail = julia_delimiter_pairs(text)
        check(f"julia:{label}-delimiters", delimiters is not None, detail)
    dispatch_ok, dispatch_detail = fixture_dispatch_closure(test, set(negative_ids))
    check("tests:all-negative-dispatched", len(negative_ids) == 12
          and dispatch_ok,
          dispatch_detail)
    check("tests:obligation-tuple-expansion",
          "ids = (_FVLC_R_IDS..., _FVLC_ENG_IDS...)" in test
          and "Tuple(_FVLC_R_IDS..., _FVLC_ENG_IDS...)" not in test,
          "obligation IDs use tuple expansion rather than the invalid Tuple varargs form")
    check("source:contract-claim-keyword",
          "claim_ceiling=_FVLC_CLAIM_CEILING" in source
          and "claim_ceiling === _FVLC_CLAIM_CEILING" in source
          and "claim_ceiling=:screen_only" not in source,
          "contract constructor binds fixed claim keyword and validator remains contract_only")
    check("source:frozen-stage-vocabulary",
          "(:pass, :physical_fail, :numerical_fail, :unknown, :not_applicable, :not_executed, :terminal_deferred)" in source
          and "s in allowed" in source,
          "numerical/physical statuses use the finite frozen stage vocabulary")
    check("source:evidence-deferred-boundary",
          all(token in source for token in (
              "row.execution_classification === :process_completed",
              "row.ledger_status !== :pending",
              "_fvlc_identity_missing(ledger.identity)",
              "_fvlc_identity_missing(row.identity)",
              'push!(deferred, "$(row.obligation_id):evidence_missing")')),
          "missing identity or pending ledger keeps missing evidence terminal_deferred")
    check("tests:contract-claim-boundary",
          "claim_ceiling=:contract_only" in test
          and "claim_ceiling=:screen_only" in test,
          "default/explicit contract_only and screen_only rejection are covered")
    check("boundary:fixed", fixture.get("claim_ceiling") == "contract_only"
          and fixture.get("accepted") is False and fixture.get("publish") == "no_publish"
          and fixture.get("evidence_credit") == 0 and fixture.get("l4_credible_count") == 0
          and fixture.get("authority_status") == "reserved_not_implemented"
          and fixture.get("all_obligations_required") is True,
          "contract-only/no-publish/zero-credit/L4=0 boundary is fixed")
    check("authority:not-wired", "struct FinalWholeDeviceAuthorityV4" not in source
          and "include(" not in source,
          "FinalWholeDeviceAuthorityV4 remains a reserved string only")
    check("root-qa:present", ROOT_QA.is_file(), "root static QA is present for cross-check")

    failed = [item["name"] for item in checks if not item["pass"]]
    result = {
        "schema": "FinalValidationLedgerContractIndependentR5StaticQAV1",
        "status": "pass" if not failed else "fail",
        "runtime_executed": False,
        "julia_executed": False,
        "desc_executed": False,
        "provider_executed": False,
        "solver_executed": False,
        "accepted": False,
        "claim_ceiling": "contract_only",
        "publish": "no_publish",
        "evidence_credit": 0,
        "l4_credible_count": 0,
        "negative_count": len(negative_ids),
        "source_sha256": sha256(SOURCE),
        "test_sha256": sha256(TEST),
        "fixture_sha256": sha256(FIXTURE),
        "root_static_qa_sha256": sha256(ROOT_QA),
        "checks": checks,
        "failed_checks": failed,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 1


if __name__ == "__main__":
    raise SystemExit(main())
