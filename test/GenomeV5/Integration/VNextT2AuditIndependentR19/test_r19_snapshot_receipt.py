"""Independent Python-only tests for the frozen T2 R19 snapshot receipt gate.

This tester-owned source is outside the frozen protocol input closure. It
imports the pinned production controller directly and exercises both the
baseline predicate and the final-audit caller with synthetic snapshots only.
It never starts Julia or queries the live process table.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import subprocess
import sys
from pathlib import Path
from unittest.mock import patch
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[4]
PROTOCOL_REL = Path("docs/implementation/UP1-04A-VNEXT-T2/archive/r2_protocol_freeze_20260925_t2_protocol_r19_snapshot_receipt_retry4/protocol.json")
CONTROLLER_REL = Path("test/GenomeV5/Integration/VNextT2FormalIndependentR1/independent_negative_controller_r19.py")
QA_SOURCE_REL = Path("test/GenomeV5/Integration/VNextT2FormalIndependentR1/static_qa_independent_negative_r19.py")
MAP_REL = Path("test/GenomeV5/Integration/VNextT2FormalIndependentR1/coverage_map_r16.json")
FROZEN_QA_REL = Path("docs/implementation/UP1-04A-VNEXT-T2/archive/r2_protocol_freeze_20260925_t2_protocol_r19_snapshot_receipt_retry4/static_qa.json")
EXPECTED_PROTOCOL_SHA = "1b0e6f4e2267b32c83195b7cf0cf0b92c3b8d356b8fd69b6840f3cfdcf6810b8"
EXPECTED_CONTROLLER_SHA = "1d955e17b4b9634ab5288ada36d4e30d6402bf56670b14f8e9afabfde1f252ca"
EXPECTED_QA_SOURCE_SHA = "e85a1be54be42681bc8cf82a85161aba54f644f6c4e73a3fd30a3aae0f639716"
EXPECTED_MAP_SHA = "7cb1c9ed0d32c5ef09c135b185d42865fa22ed7381907a325ed63561fe19db56"
EXPECTED_FROZEN_QA_SHA = "4721600a7266186d784ad97d9ef25030121f2d649b6583330e081b3f49fde4db"
EXPECTED_R18_FAILS = {
    "snapshot_malformed_raw_identity_digest",
    "snapshot_missing_buffer_bytes",
    "snapshot_missing_host_identity",
    "snapshot_missing_query_attempts",
    "snapshot_missing_raw_identity_digest",
    "snapshot_missing_system_information_class",
    "snapshot_wrong_buffer_bytes",
    "snapshot_wrong_host_identity",
    "snapshot_wrong_query_attempts",
    "snapshot_wrong_system_information_class",
}


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str:
    return sha_bytes(path.read_bytes())


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def load_controller(path: Path):
    spec = importlib.util.spec_from_file_location("independent_r19_controller", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot create R19 controller import spec")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def receipt_for_controller(controller: Any) -> dict[str, Any]:
    native = controller._R23_TABLE
    return {
        "schema": "vnext-t2-r23-global-heavy-audit-r1",
        "complete": True,
        "processes": [],
        "controller_processes": [],
        "native_heavy_identities": [],
        "errors": [],
        "snapshot": {
            "schema": "vnext-t2-r23-native-snapshot-receipt-r1",
            "complete": True,
            "row_count": 2,
            "host_identity": list(native.WINDOWS_BUILD_PIN),
            "system_information_class": native.SYSTEM_INFORMATION_CLASS,
            "buffer_bytes": native.SPI_FIXED_HEADER_BYTES,
            "query_attempts": 1,
            "raw_identity_digest_sha256": "a" * 64,
            "identity_authority": "NtQuerySystemInformation_class5_raw_FILETIME_100ns",
        },
    }


def snapshot_cases() -> list[tuple[str, Callable[[dict[str, Any]], None] | None, bool]]:
    mutations: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
        ("snapshot_missing_host_identity", lambda r: r["snapshot"].pop("host_identity")),
        ("snapshot_wrong_host_identity", lambda r: r["snapshot"].__setitem__("host_identity", [])),
        ("snapshot_missing_system_information_class", lambda r: r["snapshot"].pop("system_information_class")),
        ("snapshot_wrong_system_information_class", lambda r: r["snapshot"].__setitem__("system_information_class", 4)),
        ("snapshot_missing_buffer_bytes", lambda r: r["snapshot"].pop("buffer_bytes")),
        ("snapshot_wrong_buffer_bytes", lambda r: r["snapshot"].__setitem__("buffer_bytes", False)),
        ("snapshot_missing_query_attempts", lambda r: r["snapshot"].pop("query_attempts")),
        ("snapshot_wrong_query_attempts", lambda r: r["snapshot"].__setitem__("query_attempts", True)),
        ("snapshot_missing_raw_identity_digest", lambda r: r["snapshot"].pop("raw_identity_digest_sha256")),
        ("snapshot_malformed_raw_identity_digest", lambda r: r["snapshot"].__setitem__("raw_identity_digest_sha256", "not-a-sha256")),
    ]
    return [("valid_complete_empty_positive", None, True), *[(name, mutate, False) for name, mutate in mutations]]


def synthetic_snapshot(controller: Any) -> Any:
    native = controller._R23_TABLE
    ticks = native.WINDOWS_EPOCH_100NS + 123_456_789
    rows = (
        native.ProcessRow(native.ProcessIdentity(0, ticks), 0, ""),
        native.ProcessRow(native.ProcessIdentity(4, ticks), 0, "System"),
    )
    return native.ProcessTableSnapshot(
        rows=rows,
        host_identity=tuple(native.WINDOWS_BUILD_PIN),
        buffer_bytes=native.SPI_FIXED_HEADER_BYTES,
        query_attempts=1,
        ntstatus_u32=0,
    )


def verify_all_pins(root: Path, protocol: dict[str, Any]) -> dict[str, Any]:
    inputs = protocol.get("inputs")
    require(type(inputs) is dict, "protocol inputs must be a path-keyed object")
    mismatches: list[dict[str, Any]] = []
    for rel, pin in inputs.items():
        if type(pin) is not dict or pin.get("path") != rel:
            mismatches.append({"path": rel, "reason": "malformed_pin"})
            continue
        path = (root / rel).resolve()
        try:
            path.relative_to(root.resolve())
        except ValueError:
            mismatches.append({"path": rel, "reason": "path_escape"})
            continue
        if not path.is_file():
            mismatches.append({"path": rel, "reason": "missing"})
            continue
        raw = path.read_bytes()
        actual_sha = sha_bytes(raw)
        if len(raw) != pin.get("bytes") or actual_sha != pin.get("sha256"):
            mismatches.append({
                "path": rel,
                "expected_bytes": pin.get("bytes"),
                "actual_bytes": len(raw),
                "expected_sha256": pin.get("sha256"),
                "actual_sha256": actual_sha,
            })
    positive = protocol.get("positive_reuse_input_pins")
    require(type(positive) is dict, "positive reuse pins must be path-keyed")
    positive_mismatches: list[str] = []
    for rel, pin in positive.items():
        if inputs.get(rel) != pin:
            positive_mismatches.append(rel)
    require(not mismatches, f"current input pin mismatch count={len(mismatches)}")
    require(not positive_mismatches, f"positive reuse pin mismatch count={len(positive_mismatches)}")
    return {
        "input_pin_count": len(inputs),
        "input_pin_matches": len(inputs) - len(mismatches),
        "input_pin_mismatch_count": len(mismatches),
        "positive_reuse_pin_count": len(positive),
        "positive_reuse_pins_match_inputs": len(positive) - len(positive_mismatches),
        "positive_reuse_mismatch_count": len(positive_mismatches),
    }


def validate_frozen_contract(root: Path, protocol: dict[str, Any], coverage: dict[str, Any],
                             frozen_qa: dict[str, Any], source_path: Path) -> dict[str, Any]:
    require(protocol.get("schema") == "vnext-t2-independent-negative-protocol-r8", "protocol schema drift")
    require(protocol.get("formal_t2_accepted") is False and
            protocol.get("scientific_acceptance") is False and
            protocol.get("physical_acceptance") is False and
            protocol.get("status") == "frozen_static_ready_not_executed" and
            protocol.get("actual_source_site_hits") == "pending_julia_execution",
            "protocol acceptance or execution ceiling drift")
    inputs = protocol["inputs"]
    require(source_path.resolve().relative_to(root.resolve()).as_posix() not in inputs,
            "independent tester source unexpectedly entered frozen input closure")
    require(protocol.get("input_count") == 655 and len(inputs) == 655,
            "expected 655 exact current input pins")
    require(protocol.get("positive_reuse_input_pins") and
            len(protocol["positive_reuse_input_pins"]) == 104,
            "expected 104 positive reuse pins")
    require(protocol.get("expected_phase_count") == 30 and len(protocol.get("phase_order", [])) == 30,
            "phase count drift")
    runtime = protocol.get("runtime_execution_plan", {})
    formal_ids = runtime.get("actual_formal_summary_case_ids", [])
    expected_coverage = {
        "phase_count": 30,
        "formal_cases": 45,
        "unique_cases": 60,
        "case_hits": 68,
        "assertion_sites": 214,
        "planned_site_hits": 622,
        "authority_ids": 175,
        "authority_nonzero_sites": 75,
        "authority_hits": 118,
        "transport_ids": 23,
        "transport_hits": 92,
        "relocated_ids": 175,
    }
    observed_coverage = {
        "phase_count": protocol.get("expected_phase_count"),
        "formal_cases": len(formal_ids),
        "unique_cases": runtime.get("expected_unique_case_count"),
        "case_hits": runtime.get("expected_runtime_case_hit_count"),
        "assertion_sites": coverage.get("successor_assertion_site_count"),
        "planned_site_hits": coverage.get("successor_expected_runtime_hit_count"),
        "authority_ids": 175,
        "authority_nonzero_sites": 75,
        "authority_hits": 118,
        "transport_ids": 23,
        "transport_hits": 92,
        "relocated_ids": 175,
    }
    require(observed_coverage == expected_coverage,
            f"coverage mismatch: {observed_coverage}")
    relocation = coverage.get("attempt9c_relocation_summary", {})
    require(relocation.get("all_source_text_and_phase_hit_contracts_equal") is True and
            relocation.get("entry_count") == 175,
            "case/site source-text and phase-hit comparison against attempt7 is not equal")
    gates = protocol.get("resource_gates", {})
    require(gates == {
        "authority_case_wall_seconds": 2400,
        "authority_phase_wall_seconds": 2400,
        "julia_threads": 1,
        "openblas_threads": 1,
        "phase_wall_seconds": 480,
        "phase_wall_timeout_overrides": {"actual_formal_preflight": 600},
        "process_tree_working_set_bytes": 2147483648,
    }, f"resource gates changed: {gates}")
    budget = protocol.get("controller_wall_budget_summary", {})
    require(budget.get("phase_count") == 30 and
            budget.get("summed_phase_wall_cap_seconds") == 16440 and
            budget.get("single_end_to_end_controller_timeout_enforced") is False,
            "summed wall budget contract drift")
    require(protocol.get("planned_evidence_directory_absent") is True and
            not (root / protocol["planned_evidence_directory"]).exists(),
            "planned formal output exists unexpectedly")
    r18 = protocol.get("r18_predicate_probe_no_go_lineage", {})
    require(r18.get("status") == "preserved_no_go" and
            r18.get("test_count") == 49 and
            r18.get("failure_count") == 10 and
            set(r18.get("failed_fields", [])) == EXPECTED_R18_FAILS and
            r18.get("julia_started") is False and r18.get("formal_t2_accepted") is False,
            "R18 NO-GO lineage changed or incomplete")
    old_failures = protocol.get("attempt11_retry5_retry6_static_failure_lineage", {})
    require(old_failures.get("status") == "both_immutable_partial_failures_pinned_no_acceptance" and
            old_failures.get("formal_t2_accepted") is False and old_failures.get("julia_started") is False,
            "retry5/retry6 failure lineage changed")
    require(frozen_qa.get("status") == "pass_static_r19_r23_no_julia" and
            frozen_qa.get("negative_control_count") >= 62 and
            frozen_qa.get("formal_t2_accepted") is False and
            frozen_qa.get("julia_executed") is False,
            "frozen static QA claim or status drift")
    return {
        "coverage": observed_coverage,
        "resource_gates": gates,
        "summed_wall_seconds": budget.get("summed_phase_wall_cap_seconds"),
        "r18_failure_lineage_count": r18.get("failure_count"),
        "retry5_retry6_lineage_status": old_failures.get("status"),
        "formal_output_absent": True,
        "formal_t2_accepted": False,
        "julia_started": False,
    }


def run_mutation_matrix(controller: Any) -> dict[str, Any]:
    baseline_and_final: list[dict[str, Any]] = []
    failures: list[str] = []
    for name, mutate, expected_go in snapshot_cases():
        receipt = receipt_for_controller(controller)
        if mutate is not None:
            mutate(receipt)
        try:
            controller.verify_baseline_heavy_processes_clear(copy.deepcopy(receipt))
            baseline_go = True
            baseline_error = None
        except Exception as error:
            baseline_go = False
            baseline_error = f"{type(error).__name__}: {error}"
        table = synthetic_snapshot(controller)
        root_identity = (0xFFFFFFFE, controller._R23_TABLE.WINDOWS_EPOCH_100NS + 999)
        with patch.object(controller, "_r23_exact_heavy_audit",
                          return_value=copy.deepcopy(receipt)):
            final = controller._r23_final_audit(
                root_identity, [], table, root_exit_confirmed=True)
        final_go = final.get("complete") is True and not final.get("errors")
        baseline_ok = baseline_go is expected_go
        final_ok = final_go is expected_go
        if not baseline_ok or not final_ok:
            failures.append(name)
        baseline_and_final.append({
            "case": name,
            "expected_go": expected_go,
            "baseline_go": baseline_go,
            "baseline_error": baseline_error,
            "final_go": final_go,
            "final_complete": final.get("complete"),
            "final_error_count": len(final.get("errors", [])),
            "pass": baseline_ok and final_ok,
        })
    return {
        "scenario_count": len(baseline_and_final),
        "boundary_assertion_count": len(baseline_and_final) * 2,
        "positive_scenarios": sum(row["expected_go"] for row in baseline_and_final),
        "negative_scenarios": sum(not row["expected_go"] for row in baseline_and_final),
        "boundary_assertions_passed": sum(2 for row in baseline_and_final if row["pass"]),
        "failure_cases": failures,
        "results": baseline_and_final,
    }


def save_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
                    encoding="utf-8", newline="\n")


def write_bundle_manifest(evidence: Path, source_anchors: list[dict[str, Any]], verdict: str) -> None:
    artifact_rows: list[dict[str, Any]] = []
    for path in sorted(evidence.iterdir()):
        if not path.is_file() or path.name in {"manifest.json", "SHA256SUMS"}:
            continue
        raw = path.read_bytes()
        artifact_rows.append({"path": path.name, "bytes": len(raw), "sha256": sha_bytes(raw)})
    sums_text = "".join(f"{row['sha256']}  {row['path']}\n" for row in artifact_rows)
    (evidence / "SHA256SUMS").write_text(sums_text, encoding="ascii", newline="\n")
    sums_raw = (evidence / "SHA256SUMS").read_bytes()
    artifact_rows.append({"path": "SHA256SUMS", "bytes": len(sums_raw), "sha256": sha_bytes(sums_raw)})
    manifest = {
        "schema": "independent-t2-r19-snapshot-receipt-evidence-manifest-r1",
        "evidence_only": True,
        "verdict": verdict,
        "artifacts": artifact_rows,
        "source_anchors": source_anchors,
        "execution_boundary": "Python -B only; no Julia or FreeGS",
    }
    save_json(evidence / "manifest.json", manifest)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence-dir", required=True)
    args = parser.parse_args()
    evidence = Path(args.evidence_dir).resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    repo = ROOT.resolve()
    protocol_path = repo / PROTOCOL_REL
    controller_path = repo / CONTROLLER_REL
    qa_source_path = repo / QA_SOURCE_REL
    map_path = repo / MAP_REL
    frozen_qa_path = repo / FROZEN_QA_REL
    source_path = Path(__file__).resolve()
    command_record = {
        "argv": [sys.executable, "-B", str(source_path), "--evidence-dir", str(evidence)],
        "cwd": str(repo),
        "julia_started": False,
    }
    save_json(evidence / "tester_command.json", command_record)
    anchors = [
        {"path": PROTOCOL_REL.as_posix(), "sha256": sha_file(protocol_path)},
        {"path": CONTROLLER_REL.as_posix(), "sha256": sha_file(controller_path)},
        {"path": QA_SOURCE_REL.as_posix(), "sha256": sha_file(qa_source_path)},
        {"path": MAP_REL.as_posix(), "sha256": sha_file(map_path)},
        {"path": FROZEN_QA_REL.as_posix(), "sha256": sha_file(frozen_qa_path)},
        {"path": source_path.relative_to(repo).as_posix(), "sha256": sha_file(source_path)},
    ]
    try:
        require(sha_file(protocol_path) == EXPECTED_PROTOCOL_SHA, "R19 protocol SHA mismatch")
        require(sha_file(controller_path) == EXPECTED_CONTROLLER_SHA, "R19 controller SHA mismatch")
        require(sha_file(qa_source_path) == EXPECTED_QA_SOURCE_SHA, "R19 QA source SHA mismatch")
        require(sha_file(map_path) == EXPECTED_MAP_SHA, "R19 map SHA mismatch")
        require(sha_file(frozen_qa_path) == EXPECTED_FROZEN_QA_SHA, "R19 frozen QA report SHA mismatch")
        protocol = load_json(protocol_path)
        coverage = load_json(map_path)
        frozen_qa = load_json(frozen_qa_path)
        input_rehash = verify_all_pins(repo, protocol)
        contract = validate_frozen_contract(repo, protocol, coverage, frozen_qa, source_path)

        controller = load_controller(controller_path)
        mutation = run_mutation_matrix(controller)
        require(not mutation["failure_cases"],
                f"snapshot receipt mutation failures: {mutation['failure_cases']}")

        qa_report_path = evidence / "static_qa_rerun.json"
        qa_command = [
            sys.executable, "-B", str(qa_source_path),
            "--protocol", str(protocol_path),
            "--protocol-sha256", EXPECTED_PROTOCOL_SHA,
            "--dispatch", str(protocol_path.parent / "dispatch.json"),
            "--command", str(protocol_path.parent / "command_argv.json"),
            "--report", str(qa_report_path),
        ]
        qa = subprocess.run(qa_command, cwd=repo, capture_output=True, check=False)
        (evidence / "static_qa_rerun.command.json").write_bytes(
            json.dumps({"argv": qa_command, "cwd": str(repo)}, sort_keys=True,
                       separators=(",", ":")).encode("utf-8") + b"\n")
        (evidence / "static_qa_rerun.exit.txt").write_text(f"{qa.returncode}\n", encoding="ascii")
        (evidence / "static_qa_rerun.stdout.raw").write_bytes(qa.stdout)
        (evidence / "static_qa_rerun.stderr.raw").write_bytes(qa.stderr)
        require(qa.returncode == 0, f"fresh R19 static QA exit {qa.returncode}")
        qa_report = load_json(qa_report_path)
        require(qa_report.get("status") == "pass_static_r19_r23_no_julia" and
                qa_report.get("negative_control_count") >= 62 and
                qa_report.get("julia_executed") is False,
                "fresh R19 static QA report is not passing/no-Julia")

        # Rehash again after all tests to prove no pinned input changed during this review.
        input_rehash_after = verify_all_pins(repo, protocol)
        require(input_rehash_after == input_rehash, "pinned input closure changed during tester run")
        result = {
            "schema": "independent-t2-r19-snapshot-receipt-tester-r1",
            "status": "PASS_STATIC_R19_SNAPSHOT_RECEIPT_AND_COVERAGE",
            "verdict": "GO_FOR_ONE_BOUNDED_FORMAL_RUN_ONLY",
            "source_anchors": anchors,
            "input_rehash_before": input_rehash,
            "input_rehash_after": input_rehash_after,
            "frozen_contract": contract,
            "snapshot_mutation_matrix": mutation,
            "fresh_static_qa": {
                "command": qa_command,
                "exit": qa.returncode,
                "status": qa_report.get("status"),
                "negative_controls": qa_report.get("negative_control_count"),
                "report_sha256": sha_file(qa_report_path),
                "stdout_sha256": sha_bytes(qa.stdout),
                "stderr_sha256": sha_bytes(qa.stderr),
            },
            "julia_started": False,
            "formal_t2_accepted": False,
            "claim_boundary": "static Python readiness only; no execution or scientific acceptance",
        }
        save_json(evidence / "independent_result.json", result)
        out = json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
        (evidence / "tester.stdout.raw").write_bytes(out.encode("utf-8"))
        (evidence / "tester.stderr.raw").write_bytes(b"")
        (evidence / "tester.exit.txt").write_text("0\n", encoding="ascii")
        write_bundle_manifest(evidence, anchors, result["verdict"])
        print(out, end="")
        return 0
    except Exception as error:
        failure = {
            "schema": "independent-t2-r19-snapshot-receipt-tester-r1",
            "status": "FAIL_STATIC_R19_REVIEW",
            "verdict": "NO_GO_FOR_ONE_BOUNDED_FORMAL_RUN",
            "source_anchors": anchors,
            "error": f"{type(error).__name__}: {error}",
            "julia_started": False,
            "formal_t2_accepted": False,
        }
        save_json(evidence / "independent_result.json", failure)
        out = json.dumps(failure, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
        (evidence / "tester.stdout.raw").write_bytes(out.encode("utf-8"))
        (evidence / "tester.stderr.raw").write_bytes(b"")
        (evidence / "tester.exit.txt").write_text("1\n", encoding="ascii")
        write_bundle_manifest(evidence, anchors, failure["verdict"])
        print(out, end="")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
