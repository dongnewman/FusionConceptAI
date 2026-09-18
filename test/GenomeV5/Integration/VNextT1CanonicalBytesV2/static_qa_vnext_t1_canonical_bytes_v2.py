"""Static boundary checks for the additive VNext T1 V2 byte carrier."""

from __future__ import annotations

import json
import hashlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "src" / "Contracts" / "VNextT1CanonicalBytesV2.jl"
TEST = Path(__file__).with_name("vnext_t1_canonical_bytes_v2_tests.jl")
ORACLE = Path(__file__).with_name("independent_oracle_vnext_t1_canonical_bytes_v2.py")
FIXTURE = Path(__file__).with_name("fixture.json")
DOCS = ROOT / "docs" / "implementation" / "UP1-04A-VNEXT-T1-CANONICAL-BYTES-V2"
PROJECT = ROOT / "Project.toml"
R1_RUNTIME = DOCS / "local_profile_r1_runtime"
R2_RUNTIME = DOCS / "local_profile_r2_runtime"
PROTECTED = {
    ROOT / "src" / "Contracts" / "CandidateStatePackageV5Next.jl":
        (53197, "14e8f519dd4ffe56ca5678ae8e4b82009ced12616e05de11165e36c3b4adae73"),
    ROOT / "src" / "FusionConceptAI.jl":
        (10144, "e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783"),
}


def protected_unchanged(path: Path, expected: tuple[int, str]) -> bool:
    size, digest = expected
    payload = path.read_bytes()
    return len(payload) == size and hashlib.sha256(payload).hexdigest() == digest


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    oracle = ORACLE.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    project = PROJECT.read_text(encoding="utf-8")
    report = {}

    report["source_exists"] = SOURCE.is_file()
    report["non_parameterized_struct"] = "struct VNextT1CanonicalBytesV2\n" in source
    report["required_fields"] = all(token in source for token in (
        "raw::String", "sha256::Digest256", "encoding::Symbol"))
    report["copy_before_string"] = source.index("owned = copy(bytes)") < source.index("raw = String(owned)")
    report["exact_hash_codeunits"] = "codeunits(raw)" in source and "SHA.sha256" in source
    report["base64_stdlib"] = "using Base64" in source and "Base64.base64encode" in source
    report["base64_project_dependency"] = (
        'Base64 = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"' in project)
    report["stable_semantic_fields"] = all(token in source for token in (
        "schema=", "version=", "encoding=", "base64=", "length=", "sha256="))
    report["byte_helpers"] = all(token in source for token in (
        "byte_length", "copy_bytes", "byte_at", "ncodeunits(x.raw)"))
    report["definition_only"] = "include(" not in source and "register" not in source
    report["protected_production_files_unchanged"] = all(
        protected_unchanged(path, expected) for path, expected in PROTECTED.items())
    report["boundary_cases"] = all(str(n) in test for n in ("63", "64", "65", "1024", "8_269_445"))
    report["large_vector_not_tuple"] = all(token in test for token in (
        "Vector{UInt8}(undef, n)", "_v2_pattern(8_269_445")) and "NTuple{" not in test
    report["invalid_utf8_case"] = "invalid_utf8" in test and "0xff" in test
    report["ownership_case"] = "input[1] = 0xff" in test and "detached[2] = 0xee" in test
    report["invalid_utf8_ownership_case"] = all(token in test for token in (
        "input .= 0x00", "detached .= 0x11", "UInt8[0xff, 0xfe, 0xc3, 0x28]"))
    report["replay_case"] = "semantic_view(value)" in test and "replay" in test
    report["canonical_json_exact_and_nested"] = all(token in test for token in (
        "canonical JSON projection", "nested_expected", "sha256\\\":{\\\"value"))
    report["boundary_base64_goldens"] = "_V2_BOUNDARY_BASE64" in test and all(
        f"n{n}=" in test for n in (63, 64, 65, 1024))
    report["immutable_boundary_lookup"] = all(token in test for token in (
        "const _V2_BOUNDARY_BASE64 = (", "getproperty(", "Symbol(:n, length)"))
    report["tuple_pair_index_regression_absent"] = all(
        token not in test for token in ("63 =>", "64 =>", "65 =>", "1024 =>",
                                        "_V2_BOUNDARY_BASE64[length]"))
    report["stable_replay_line"] = "VNEXT_T1_CANONICAL_BYTES_V2_REPLAY" in test and all(
        token in test for token in ("schema=$(", "version=$(", "length=$(", "sha256=$(", "base64_sha256=$("))
    report["independent_python"] = all(token in oracle for token in (
        "hashlib", "base64", "does not import Julia", "fixture.json"))
    report["fixture_boundary"] = fixture["large"]["length"] == 8_269_445
    report["fixture_no_runtime_credit"] = (
        fixture["runtime"] == "r2_test_exception_boundary_pair_tuple_index_repaired_not_rerun"
        and fixture["r2"]["accepted"] is False
        and fixture["r2"]["credit"] == "none"
        and fixture["integration"] == "not_connected")
    report["docs_present"] = all((DOCS / name).is_file() for name in ("README.md", "manifest.json", "report.md"))
    report["r1_program_exception_archived"] = (
        (R1_RUNTIME / "runtime.lock").is_file()
        and any(R1_RUNTIME.glob("run_*/run_metadata.json")))
    report["r2_test_exception_archived"] = (
        (R2_RUNTIME / "runtime.lock").is_file()
        and any(R2_RUNTIME.glob("run_*/run_metadata.json")))

    failed = [name for name, ok in report.items() if not ok]
    if failed:
        print(json.dumps({"status": "FAIL", "failed": failed, "checks": report}, sort_keys=True))
        return 1
    print(json.dumps({"status": "PASS", "checks": len(report), "runtime": "NOT_RUN",
                      "integration": "NOT_CONNECTED"}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
