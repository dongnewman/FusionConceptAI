"""Read-only static QA for the additive UP6 validation-ledger contract."""

from __future__ import annotations

import hashlib
import json
import pathlib
import re
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[4]
SOURCE = ROOT / "src/RuntimeV4/FinalValidationLedgerContractV1.jl"
TEST = ROOT / "test/RuntimeV4/final_validation_ledger_contract_v1_tests.jl"
FIXTURE = ROOT / "test/RuntimeV4/fixtures/final_validation_ledger_contract_v1.json"
MANIFEST = ROOT / "docs/implementation/UP6-EARLY-PREPARATION/FINAL-VALIDATION-LEDGER-CONTRACT-R1/manifest.json"


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(name: str, condition: bool, detail: str) -> dict:
    return {"name": name, "pass": bool(condition), "detail": detail}


_OPEN_TO_CLOSE = {"(": ")", "[": "]", "{": "}"}
_CLOSE_TO_OPEN = {close: open_ for open_, close in _OPEN_TO_CLOSE.items()}


def julia_delimiter_pairs(text: str) -> tuple[dict[int, int] | None, str]:
    """Scan Julia delimiters while ignoring comments and quoted strings.

    This is a deterministic lexical precheck only; it never invokes Julia's
    parser and must not be reported as Julia parse evidence.
    """
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
    """Require every fixture negative to have a closed Julia dispatch call."""
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
    unclosed = [
        match.group(1) for match in matches
        if match.end() - 1 not in pairs
    ]
    if missing or duplicate_ids or unclosed:
        return False, (
            f"missing={missing}; duplicate={duplicate_ids}; "
            f"unclosed={unclosed}"
        )
    return True, f"{len(dispatch_ids)} fixture dispatch calls are individually closed"


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    checks: list[dict] = []

    for token in (
        "FinalValidationLedgerIdentityV1",
        "FinalValidationLedgerEvidenceRefV1",
        "FinalValidationLedgerMetricsV1",
        "FinalValidationLedgerObligationV1",
        "FinalValidationLedgerContractV1",
        "FinalValidationLedgerDecisionV1",
        "validate_final_validation_ledger",
        "applicability",
        "provider_match",
        "resolution",
        "execution_classification",
        "numerical_status",
        "physical_status",
        "lifecycle",
        "conservation",
        "convergence",
        "error",
        "vvuq",
        "engineering",
        "net_output",
        "replay",
        "originality",
        "R01-R10",
        "terminal_deferred",
        "numerical_fail",
        "physical_fail",
        "fail_closed",
        "no_publish",
        "evidence_credit=0",
        "mission_hash", "mechanism_hash", "field_geometry_hash", "realization_control_hash",
        "evidence_binding_mismatch", "required_false",
    ):
        checks.append(check(f"source:{token}", token in source, "required ledger contract token"))

    for token in (
        "identity_mismatch",
        "provider_out_of_domain",
        "exit_zero_missing_terminal_artifact",
        "iteration_limit",
        "negative_engineering_margin",
        "net_output_interval_crosses_zero",
        "calibration_reused_as_held_out",
        "not_applicable_without_proof",
        "historical_receipt_as_fresh",
        "missing_required_scenario",
        "evidence_binding_mismatch",
        "required_false",
        "JSON3.read",
        "_FVLC_FIXTURE",
        "@test decision.publish == :no_publish",
        "@test decision.evidence_credit == 0",
        "@test mismatch_decision.status == :fail_closed",
        "@test provider_decision.status == :terminal_deferred",
        "@test validate_final_validation_ledger(iteration_limit).status == :numerical_fail",
        "@test validate_final_validation_ledger(negative_margin).status == :physical_fail",
        "@test validate_final_validation_ledger(unknown_interval).status == :unknown",
        'occursin(":evidence_missing", reason)',
        "_FVLC_NEGATIVE_IDS",
    ):
        checks.append(check(f"test:{token}", token in test, "required negative/admission vector"))

    for token in (
        "R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08", "R09", "R10",
        "ENG-BALANCE", "ENG-NET-LEDGER", "ENG-CONTROL-FAULT",
    ):
        checks.append(check(f"fixture:{token}", token in json.dumps(fixture), "required obligation identity"))

    checks.append(check(
        "source:no-authority-definition",
        "struct FinalWholeDeviceAuthorityV4" not in source
        and "export FinalWholeDeviceAuthorityV4" not in source
        and "include(" not in source,
        "reserved authority name is not implemented or wired",
    ))
    checks.append(check(
        "source:fixed-no-publish",
        "const _FVLC_PUBLISH = :no_publish" in source
        and "publish === _FVLC_PUBLISH" in source
        and "evidence_credit === 0" in source
        and "accepted === false" in source,
        "contract cannot publish or grant credit",
    ))
    checks.append(check(
        "source:dimension-separated",
        all(token in source for token in (
            "row.provider_match", "row.resolution", "row.execution_classification",
            "row.numerical_status", "row.physical_status", "row.lifecycle")),
        "status dimensions are not collapsed",
    ))
    checks.append(check(
        "source:frozen-stage-vocabulary",
        "(:pass, :physical_fail, :numerical_fail, :unknown, :not_applicable, :not_executed, :terminal_deferred)" in source
        and "s in allowed" in source,
        "numerical/physical statuses use the finite frozen stage vocabulary",
    ))
    checks.append(check(
        "source:evidence-deferred-boundary",
        all(token in source for token in (
            "row.execution_classification === :process_completed",
            "row.ledger_status !== :pending",
            "_fvlc_identity_missing(ledger.identity)",
            "_fvlc_identity_missing(row.identity)",
            'push!(deferred, "$(row.obligation_id):evidence_missing")')),
        "missing identity or pending ledger keeps missing evidence terminal_deferred",
    ))
    checks.append(check(
        "manifest:boundary",
        manifest.get("status") == "contract_only"
        and manifest.get("accepted") is False
        and manifest.get("publish") == "no_publish"
        and manifest.get("evidence_credit") == 0
        and manifest.get("julia_executed") is False
        and manifest.get("desc_executed") is False,
        "manifest preserves early-preparation/no-credit boundary",
    ))
    checks.append(check(
        "fixture:shape",
        fixture.get("schema") == "FinalValidationLedgerContractFixtureV1"
        and fixture.get("claim_ceiling") == "contract_only"
        and fixture.get("publish") == "no_publish"
        and len(fixture.get("negative", [])) == 12
        and fixture.get("accepted") is False
        and fixture.get("evidence_credit") == 0
        and fixture.get("l4_credible_count") == 0
        and fixture.get("authority_status") == "reserved_not_implemented"
        and fixture.get("all_obligations_required") is True,
        "fixture schema and negative coverage",
    ))
    fixture_negative_ids = {item.get("id") for item in fixture.get("negative", [])}
    for label, text in (("source", source), ("test", test)):
        delimiters, detail = julia_delimiter_pairs(text)
        checks.append(check(
            f"julia:{label}-delimiters",
            delimiters is not None,
            detail,
        ))
    dispatch_ok, dispatch_detail = fixture_dispatch_closure(test, fixture_negative_ids)
    checks.append(check(
        "test:fixture-negative-dispatch",
        "const _FVLC_NEGATIVE_IDS = Tuple(String(x.id) for x in _FVLC_FIXTURE.negative)" in test
        and dispatch_ok,
        dispatch_detail,
    ))
    checks.append(check(
        "test:obligation-tuple-expansion",
        "ids = (_FVLC_R_IDS..., _FVLC_ENG_IDS...)" in test
        and "Tuple(_FVLC_R_IDS..., _FVLC_ENG_IDS...)" not in test,
        "obligation IDs use tuple expansion rather than the invalid Tuple varargs form",
    ))
    checks.append(check(
        "source:contract-claim-keyword",
        "claim_ceiling=_FVLC_CLAIM_CEILING" in source
        and "claim_ceiling === _FVLC_CLAIM_CEILING" in source
        and "claim_ceiling=:screen_only" not in source,
        "contract constructor binds the fixed keyword and rejects claim-ceiling escapes",
    ))
    checks.append(check(
        "test:contract-claim-boundary",
        "claim_ceiling=:contract_only" in test
        and "claim_ceiling=:screen_only" in test,
        "default/explicit contract_only and screen_only rejection are covered",
    ))
    checks.append(check(
        "source:evidence-binding",
        all(token in source for token in (
            "_fvlc_evidence_binding_matches", "evidence.candidate_ref",
            "evidence.physical_subject_hash", "evidence.solver_input_hash",
            "evidence.scenario_ref", "evidence_binding_mismatch")),
        "evidence refs are checked against the ledger identity",
    ))
    checks.append(check(
        "source:required-fail-closed",
        "row.required === true || push!(fail_closed" in source
        and "required_false" in source,
        "all R01-R10 and ENG rows must remain required",
    ))

    for path in (SOURCE, TEST, FIXTURE):
        checks.append(check(f"file:{path.relative_to(ROOT).as_posix()}", path.is_file(), "file exists"))

    status = subprocess.run(
        ["git", "status", "--short", "--", str(SOURCE), str(TEST), str(FIXTURE)],
        cwd=ROOT, text=True, capture_output=True, check=False,
    )
    checks.append(check("git:scope", status.returncode == 0, status.stdout.strip()))

    failed = [item for item in checks if not item["pass"]]
    result = {
        "schema": "FinalValidationLedgerContractStaticQAV1",
        "status": "pass" if not failed else "fail",
        "runtime_executed": False,
        "julia_executed": False,
        "desc_executed": False,
        "provider_executed": False,
        "solver_executed": False,
        "claim_ceiling": "contract_only",
        "publish": "no_publish",
        "evidence_credit": 0,
        "l4_credible_count": 0,
        "source_sha256": sha256(SOURCE),
        "test_sha256": sha256(TEST),
        "fixture_sha256": sha256(FIXTURE),
        "checks": checks,
        "failed_checks": [item["name"] for item in failed],
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
