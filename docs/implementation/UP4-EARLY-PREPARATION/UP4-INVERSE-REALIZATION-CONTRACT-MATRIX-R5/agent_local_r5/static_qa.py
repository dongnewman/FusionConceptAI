"""Static QA for the UP4 inverse-realization R5 domain repair."""
from __future__ import annotations

import hashlib
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
SOURCE = ROOT / "src/RuntimeV4/InverseRealizationRequestContractV1.jl"
TEST = ROOT / "test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl"
FIXTURE = ROOT / "test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json"
FAILED_RUN = ROOT / "runs/agent_local_up4_inverse_realization_contract_matrix_20260918_r4"


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    run = json.loads((FAILED_RUN / "run.json").read_text(encoding="utf-8"))
    raw_failure = "\n".join((FAILED_RUN / name).read_text(encoding="utf-8")
                              for name in ("stdout.raw", "stderr.raw"))
    checks: list[tuple[str, bool]] = []

    def check(name: str, value: bool) -> None:
        checks.append((name, bool(value)))

    ids = [item["id"] for item in fixture["negative"]]
    check("fixture_negative_ids_unique", len(ids) == len(set(ids)))
    check("fixture_cross_domain_case", "cross_domain_source_geometry" in ids)
    check("fixture_duplicate_provider_case", "duplicate_provider_domains" in ids)
    check("fixture_duplicate_reason", any(
        item.get("expected_reason") == "duplicate provider domains"
        for item in fixture["negative"]))
    check("fixture_zero_provider_requirement", fixture["provider_calls_required"] == 0)
    check("test_stable_domain_dedup", "Tuple(sort!(unique((target_domain, source_domain))))" in test)
    check("test_cross_domain_builder", "cross_domain = _irv1_fixture" in test)
    check("test_cross_domain_reason", "source_geometry_domain_mismatch" in test)
    check("test_duplicate_provider_external_case", "duplicate_provider_domains" in test)
    check("test_duplicate_provider_domains_literal", 'domains=("electrical-hardware", "electrical-hardware")' in test)
    check("test_duplicate_provider_reason", "duplicate provider domains" in test)
    check("test_zero_provider_counter", "duplicate_provider_domains.provider_calls == 0" in test)
    check("source_duplicate_domains_guard", "_irv1_sorted_strings" in source
          and "duplicate $label" in source)
    check("source_external_error_type", "InverseExternalInputError" in source)
    check("source_admission_normalizes_external", "constructor_fail_closed" in source)
    check("source_no_runtime_backend", all(token not in source for token in (
        "run_provider", "run_solver", "build_mesh", "DESC", "ccall(")))
    check("failed_r4_exit_one", run.get("exit_code") == 1)
    check("failed_r4_hashes_unchanged", run.get("hashes_unchanged") is True)
    check("failed_r4_original_duplicate_evidence", "duplicate provider domains" in raw_failure)
    check("failed_r4_raw_files_present", all((FAILED_RUN / name).is_file()
        for name in ("run.json", "stdout.raw", "stderr.raw", "input_hashes_pre.json",
                     "input_hashes_post.json")))

    failed = [name for name, passed in checks if not passed]
    result = {
        "schema": "UP4InverseRealizationContractMatrixStaticQAR5",
        "status": "pass" if not failed else "fail",
        "checks": len(checks),
        "failed_checks": failed,
        "julia_executed": False,
        "desc_executed": False,
        "provider_calls": 0,
        "solver_calls": 0,
        "source_sha256": sha256(SOURCE),
        "test_sha256": sha256(TEST),
        "fixture_sha256": sha256(FIXTURE),
        "failed_r4_run": run,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
