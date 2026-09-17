"""Read-only static QA for the UP4 inverse-realization contract R2 repair."""

from __future__ import annotations

import hashlib
import json
import pathlib
import re
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[5]
SOURCE = ROOT / "src/RuntimeV4/InverseRealizationRequestContractV1.jl"
TEST = ROOT / "test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl"
FIXTURE = ROOT / "test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json"
MANIFEST = ROOT / "docs/implementation/UP4-EARLY-PREPARATION/SOURCE-HARDWARE-INVERSE-CONTRACT-R1/agent_local_r2/manifest.json"


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(name: str, condition: bool, detail: str) -> dict:
    return {"name": name, "pass": bool(condition), "detail": detail}


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    checks: list[dict] = []

    required_source = (
        "_irv1_input_error",
        "_irv1_expected_input_error",
        "_irv1_checked_conversion",
        "_irv1_checked_float",
        "_irv1_checked_int",
        "_irv1_checked_symbol",
        "_irv1_checked_tuple",
        "MethodError",
        "InexactError",
        "OverflowError",
        "TypeError",
        "admit_inverse_realization_request",
        "validate_inverse_realization_request",
        "provider_calls === 0",
    )
    for token in required_source:
        checks.append(check(f"source:{token}", token in source, "R2 input-boundary token"))

    required_test = (
        '"not-a-float"',
        "Ref(:W)",
        "3.5",
        "big(typemax(Int)) + 1",
        "TypeError",
        '"internal_program_defect"',
        "_irv1_checked_conversion",
        'status == :fail_closed',
        "provider_calls == 0",
    )
    for token in required_test:
        checks.append(check(f"test:{token}", token in test, "malformed-input/non-swallow vector"))

    admit_match = re.search(
        r"function admit_inverse_realization_request\(builder::Function\)(?P<body>.*?)\nend\n",
        source,
        re.DOTALL,
    )
    admit_body = admit_match.group("body") if admit_match else ""
    validation_index = admit_body.find("validate_inverse_realization_request(request)")
    request_check_index = admit_body.find("request isa InverseRealizationRequestV1")
    checks.append(check(
        "admit:validation-outside-catch",
        bool(admit_match)
        and validation_index >= 0
        and request_check_index >= 0
        and validation_index > request_check_index
        and "_irv1_expected_input_error(error) || rethrow()" in admit_body,
        "typed builder catch ends before validation",
    ))
    checks.append(check(
        "admit:narrow-classifier",
        "startswith(sprint(showerror, error), \"inverse_input:\")" in source
        and "error isa ArgumentError || rethrow()" not in admit_body,
        "only tagged constructor input errors normalize",
    ))

    forbidden_source = (
        "Manufactured",
        "DESC",
        "default_operator_registry",
        "task_manifest",
        "optimizer",
        "subprocess",
        "include(",
        "run(",
        "ccall(",
    )
    for token in forbidden_source:
        checks.append(check(f"source:forbidden:{token}", token not in source, "execution/legacy boundary"))

    checks.append(check(
        "source:conversion-errors-are-local",
        "(error isa MethodError" in source
        and re.search(r"error isa InexactError", source) is not None
        and re.search(r"error isa OverflowError", source) is not None
        and re.search(r"error isa TypeError", source) is not None,
        "conversion helper catches only expected conversion classes",
    ))
    checks.append(check(
        "source:status-closure",
        all(token in source for token in (":contract_only", ":prepared", ":fail_closed", ":terminal_deferred")),
        "all contract-only statuses are represented",
    ))
    checks.append(check(
        "fixture:schema",
        fixture.get("schema") == "InverseRealizationRequestContractFixtureV1",
        "fixture schema",
    ))
    checks.append(check(
        "manifest:contract-boundary",
        manifest.get("status") == "contract_only"
        and manifest.get("runtime_execution") == "not_run"
        and manifest.get("julia_executed") is False
        and manifest.get("desc_executed") is False
        and manifest.get("provider_calls") == 0,
        "manifest preserves contract-only/no-call boundary",
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
        "schema": "UP4InverseRealizationContractStaticQAV2",
        "status": "pass" if not failed else "fail",
        "runtime_executed": False,
        "julia_executed": False,
        "desc_executed": False,
        "provider_calls": 0,
        "claim_ceiling": "contract_only",
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
