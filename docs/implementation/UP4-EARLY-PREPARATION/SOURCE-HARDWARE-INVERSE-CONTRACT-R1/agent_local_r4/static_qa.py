"""Read-only static QA for the UP4 inverse-realization contract R4 repair."""

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
MANIFEST = ROOT / "docs/implementation/UP4-EARLY-PREPARATION/SOURCE-HARDWARE-INVERSE-CONTRACT-R1/agent_local_r4/manifest.json"


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

    for token in (
        "struct InverseExternalInputError <: Exception",
        "Base.showerror(io::IO, error::InverseExternalInputError)",
        "_irv1_input_error(message) = InverseExternalInputError",
        "_irv1_checked_conversion(String, x, label)",
        "throw(InverseExternalInputError(:conversion",
        "MethodError", "InexactError", "OverflowError", "TypeError",
        "admit_inverse_realization_request",
        "validate_inverse_realization_request",
        "provider_calls === 0",
    ):
        checks.append(check(f"source:{token}", token in source, "R4 typed exception boundary"))

    for token in (
        "InverseExternalInputError", '"not-a-float"', "Ref(:W)", "3.5",
        "big(typemax(Int)) + 1", "TypeError", "_IRV1BrokenString",
        "AbstractString", "malformed_abstract_string", "same_message",
        "@test_throws ArgumentError", "@test_throws MethodError",
        "@test_throws ErrorException", '"internal_program_defect"',
        "provider_calls == 0",
    ):
        checks.append(check(f"test:{token}", token in test, "R4 malformed and non-swallow vector"))

    admit_match = re.search(
        r"function admit_inverse_realization_request\(builder::Function\)(?P<body>.*?)\nend\n",
        source, re.DOTALL,
    )
    body = admit_match.group("body") if admit_match else ""
    validation_index = body.find("validate_inverse_realization_request(request)")
    type_index = body.find("request isa InverseRealizationRequestV1")
    checks.append(check(
        "admit:exact-type-only",
        bool(admit_match)
        and "typeof(error) === InverseExternalInputError || rethrow()" in body
        and "error isa InverseExternalInputError || rethrow()" not in body
        and "_irv1_expected_input_error" not in source
        and "startswith(sprint(showerror" not in source,
        "admission catches exact sealed external-input type",
    ))
    checks.append(check(
        "admit:validation-outside-catch",
        bool(admit_match) and validation_index >= 0 and type_index >= 0
        and validation_index > type_index,
        "validation remains outside external-input catch",
    ))
    checks.append(check(
        "source:conversion-errors-local",
        all(token in source for token in ("error isa MethodError", "error isa InexactError",
                                          "error isa OverflowError", "error isa TypeError")),
        "only local conversion seam catches expected conversion classes",
    ))
    checks.append(check(
        "source:text-conversion-local",
        "_irv1_checked_conversion(String, x, label)" in source
        and "value = String(x)" not in source,
        "AbstractString-to-String normalization uses the typed conversion seam",
    ))

    for token in ("Manufactured", "DESC", "default_operator_registry", "task_manifest",
                  "optimizer", "subprocess", "include(", "run(", "ccall("):
        checks.append(check(f"source:forbidden:{token}", token not in source, "execution/legacy boundary"))

    checks.append(check(
        "source:status-closure",
        all(token in source for token in (":contract_only", ":prepared", ":fail_closed", ":terminal_deferred")),
        "all contract-only statuses represented",
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
        "schema": "UP4InverseRealizationContractStaticQAV4",
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
