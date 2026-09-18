"""Static-only R7 QA for the source/hardware inverse-realization seam.

This checker reads source, test, and fixture text only.  It never starts
Julia, DESC, a provider, a solver, or a checker.
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
SOURCE = ROOT / "src/RuntimeV4/SourceHardwareInverseRealizationContractV1.jl"
TEST = ROOT / "test/RuntimeV4/source_hardware_inverse_realization_contract_v1_tests.jl"
FIXTURE = ROOT / "test/RuntimeV4/fixtures/source_hardware_inverse_realization_contract_v1.json"


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    checks: list[tuple[str, bool]] = []

    def check(name: str, condition: bool) -> None:
        checks.append((name, bool(condition)))

    negative = fixture["negative"]
    ids = [item["id"] for item in negative]
    check("fixture_negative_count_37", len(ids) == 37)
    check("fixture_negative_ids_unique", len(ids) == len(set(ids)))
    check("fixture_expected_counters_zero", fixture["expected_counters"] == {
        "provider_calls": 0, "solver_calls": 0, "checker_calls": 0})
    check("test_explicit_coverage_registry", "negative_coverage" in test)
    check("test_coverage_set_matches_fixture",
          "Set(keys(negative_coverage)) == expected_ids" in test)
    check("test_positive_metadata_assertions", "positive = fixture.positive" in test)
    check("test_constructor_guards_reads_positive",
          "constructor_guards = positive.constructor_guards" in test)
    check("test_constructor_guards_rejects_fixture_root",
          "constructor_guards = fixture.constructor_guards" not in test)
    check("test_hash_assertion_design", "canonical_hash(design) == design.design_hash" in test)
    check("test_hash_assertion_request", "canonical_hash(request) == request.request_hash" in test)
    for vector in ids:
        check(f"test_vector:{vector}", vector in test)

    guards = fixture["positive"]["constructor_guards"]
    check("fixture_alternative_type", guards["alternative_type"] == "SourceHardwareRefV1")
    check("fixture_alternative_kind", guards["alternative_kind"] == "design_alternative")
    check("fixture_bool_rejection", guards["rejects_bool"] is True)
    check("fixture_wrong_kind_rejection", guards["rejects_wrong_kind"] is True)
    check("source_constructor_validates_alternative", (
        "alternative isa SourceHardwareRefV1 && alternative.kind === :design_alternative" in source))
    check("source_constructor_preserves_alternative", "new(alternative, _shir_digest" in source)
    check("source_constructor_no_bool_alias", "alt = alternative isa" not in source)
    check("test_positive_alternative_type", "request.design.alternative isa SourceHardwareRefV1" in test)
    check("test_positive_alternative_kind", "request.design.alternative.kind === :design_alternative" in test)
    check("test_bool_alternative_rejected", "_shir_design_with_alternative(\n        request.design, false)" in test)
    check("test_wrong_kind_alternative_rejected", "wrong_kind_alternative" in test)

    for token in (
        "candidate_binding_hash", "candidate_provenance_hash",
        "_shir_candidate_provenance_hash", "candidate_binding_hash_mismatch",
        "candidate_provenance_hash_mismatch", "!isempty(fail_closed) && return",
        "!isempty(unknown) && return", "!isempty(typed_absent) && return",
        "!isempty(deferred) && return",
    ):
        check(f"source:{token}", token in source)
    for forbidden in ("default_operator_registry", "task_manifest", "optimizer",
                      "subprocess", "include(", "run(", "ccall(", "DESC"):
        check(f"source_forbidden:{forbidden}", forbidden not in source)

    checks_failed = [name for name, passed in checks if not passed]
    result = {
        "schema": "UP4SourceHardwareInverseStaticQAR7",
        "status": "pass" if not checks_failed else "fail",
        "checks": len(checks),
        "failed_checks": checks_failed,
        "negative_count": len(ids),
        "unique_negative_count": len(set(ids)),
        "julia_executed": False,
        "desc_executed": False,
        "provider_calls": 0,
        "solver_calls": 0,
        "checker_calls": 0,
        "source_sha256": sha256(SOURCE),
        "test_sha256": sha256(TEST),
        "fixture_sha256": sha256(FIXTURE),
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not checks_failed else 1


if __name__ == "__main__":
    sys.exit(main())
