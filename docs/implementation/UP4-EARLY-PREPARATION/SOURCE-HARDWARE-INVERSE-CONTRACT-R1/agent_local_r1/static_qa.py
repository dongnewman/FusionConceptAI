"""Read-only static QA for the UP4 inverse-realization contract-only slice."""

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
MANIFEST = ROOT / "docs/implementation/UP4-EARLY-PREPARATION/SOURCE-HARDWARE-INVERSE-CONTRACT-R1/agent_local_r1/manifest.json"


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
        "InverseRealizationBoundV1",
        "InverseRealizationPortV1",
        "InverseRealizationElectricalV1",
        "InverseRealizationMaterialV1",
        "InverseRealizationGeometryV1",
        "InverseRealizationProviderCapabilityV1",
        "InverseRealizationRequestV1",
        "InverseRealizationContractResultV1",
        "validate_inverse_realization_request",
        "admit_inverse_realization_request",
        "canonical_hash",
        "provider_calls",
        "derivative_capability_missing",
        "return_port_missing",
        "voltage_requires_nonforbidden_emf_policy",
    )
    for token in required_source:
        checks.append(check(f"source:{token}", token in source, "required contract token"))

    required_test = (
        "target_return_quantity_mismatch",
        "provider=false",
        "return_port=false",
        "derivative_orders=()",
        "provider_calls == 0",
        "canonical_hash(reordered)",
        "NaN",
    )
    for token in required_test:
        checks.append(check(f"test:{token}", token in test, "required static vector"))

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
        "source:status-closure",
        all(token in source for token in (":contract_only", ":prepared", ":fail_closed", ":terminal_deferred")),
        "all contract-only statuses are represented",
    ))
    checks.append(check(
        "source:finite-bounds",
        "isfinite" in source and "lo <= hi" in source,
        "finite ordered bounds are checked",
    ))
    checks.append(check(
        "source:ordering-invariance",
        "sort!" in source and "_irv1_sorted_symbols" in source,
        "provider capability collections are sorted before identity",
    ))
    checks.append(check(
        "source:zero-provider-calls",
        "provider_calls === 0" in source and "provider_calls=0" in source,
        "result constructor and decision path forbid provider invocation",
    ))

    checks.append(check(
        "fixture:schema",
        fixture.get("schema") == "InverseRealizationRequestContractFixtureV1",
        "fixture schema",
    ))
    checks.append(check(
        "fixture:positive",
        fixture.get("positive", {}).get("expected_status") == "prepared",
        "positive ceiling is prepared/contract-only",
    ))
    checks.append(check(
        "manifest:contract-boundary",
        manifest.get("status") == "contract_only"
        and manifest.get("runtime_execution") == "not_run"
        and manifest.get("provider_calls") == 0,
        "manifest preserves contract-only/no-call boundary",
    ))
    negatives = {item["id"]: item["expected_status"] for item in fixture.get("negative", [])}
    for name in ("provider_capability_missing", "derivative_capability_missing", "return_port_missing"):
        checks.append(check(f"fixture:{name}", negatives.get(name) == "terminal_deferred", "missing prerequisite defers"))
    for name in ("target_return_quantity_mismatch", "target_return_unit_mismatch", "target_return_function_space_mismatch", "target_return_domain_mismatch", "voltage_forbidden_emf"):
        checks.append(check(f"fixture:{name}", negatives.get(name) == "fail_closed", "contradiction fails closed"))

    for path in (SOURCE, TEST, FIXTURE):
        checks.append(check(f"file:{path.relative_to(ROOT).as_posix()}", path.is_file(), "file exists"))

    status = subprocess.run(
        ["git", "status", "--short", "--", str(SOURCE), str(TEST), str(FIXTURE)],
        cwd=ROOT, text=True, capture_output=True, check=False,
    )
    checks.append(check("git:scope", status.returncode == 0, status.stdout.strip()))

    failed = [item for item in checks if not item["pass"]]
    result = {
        "schema": "UP4InverseRealizationContractStaticQAV1",
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
