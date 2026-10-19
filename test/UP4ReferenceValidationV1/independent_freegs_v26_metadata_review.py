from __future__ import annotations

import difflib
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Any


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
BASE = Path("docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC")
V25_PROTOCOL_REL = BASE / "agent_reference_gs_20260924/native_axisymmetric_forward_v16/actual_run_protocol_v25_process_tree_candidate_v1.json"
V26_PROTOCOL_REL = BASE / "agent_reference_gs_20260924/native_axisymmetric_forward_v17/actual_run_protocol_v26_process_tree_candidate_v1.json"
V25_SUPERVISOR_REL = Path("tools/up4_reference_validation/freegs_process_supervisor_v25.py")
V26_SUPERVISOR_REL = Path("tools/up4_reference_validation/freegs_process_supervisor_v26.py")
OUT = ROOT / BASE / "archive/independent_freegs_v26_metadata_review_20260924"
EXPECTED = {
    "v25_protocol": "ce2a06249c79f9a134adf41bc0731ead1da7189b4fb6fd14ea2d6850e604d8ae",
    "v26_protocol": "f3f7c0f5ab4a3638ba937243c5dc1d2613f7b5f3480c6df852fbac69021702f8",
    "v25_supervisor": "7092ac49e8a6af758b97433b002dbf605ff4cbf12669aa5c5de42ec07c90c53b",
    "v26_supervisor": "8602a24f4ddd44ac4d4870aa1933691244139a224afbf42e3c268055b84afff6",
    "v26_test": "91d63afe33bb8e59c4be0c22deedbb1ca9ff631aea45e5826e6b70f18fa50e0d",
    "v26_verifier": "ced36c5dfa6582d80c01650fbd4f7b432d80b3925ac84ca227c2ef79e5628682",
    "v26_pin_manifest": "d51d6dbef07dee67d2e255ab36c21dccb802b6b3742ca7981ee484272f7ccb92",
    "v25_execution": "c59260de901ecf165b305a2fdfedcb28b7e517b518503cb4ae4fd81490eedfb4",
    "v25_adapter": "7cee871eea12f7526071a91b769d4fc4b9b1eae84c46ee1895eb6aaa229c21af",
    "v25_output": "e1c23b86456927da63f9db5fa0d92deb4964d4b0fa784f64b87b70ffa0c804b6",
    "v25_stdout": "5410a2ca4d1907be0c9b13ab2c1f1a03ff23b8086e22a87d6369268133cf40c2",
    "empty_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
}


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def norm(path: str | Path) -> str:
    return os.path.normcase(str(Path(path).resolve(strict=False)))


def write_json(path: Path, value: Any) -> None:
    path.write_text(
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False) + "\n",
        encoding="utf-8", newline="\n",
    )


def main() -> int:
    if not OUT.is_dir() or any(OUT.iterdir()):
        raise RuntimeError(f"evidence output leaf must be a newly created empty directory: {OUT}")

    errors: list[str] = []
    checks: dict[str, bool] = {}
    v25_protocol_path = ROOT / V25_PROTOCOL_REL
    v26_protocol_path = ROOT / V26_PROTOCOL_REL
    v25_source_path = ROOT / V25_SUPERVISOR_REL
    v26_source_path = ROOT / V26_SUPERVISOR_REL
    v26_test_rel = Path("test/UP4ReferenceValidationV1/test_freegs_process_supervisor_v26.py")
    v26_verifier_rel = Path("tools/up4_reference_validation/verify_freegs_v26_process_tree_candidate.py")
    pin_manifest_rel = Path("tools/up4_reference_validation/freegs_v26_pin_manifest.json")
    v26_test_path = ROOT / v26_test_rel
    v26_verifier_path = ROOT / v26_verifier_rel
    pin_manifest_path = ROOT / pin_manifest_rel
    v25_actual_rel = BASE / "archive/root_freegs_v25_grant_20260924/actual_run_r25/freegs_solve"
    v25_actual_path = ROOT / v25_actual_rel

    exact_hash_targets = {
        "v25_protocol": v25_protocol_path,
        "v26_protocol": v26_protocol_path,
        "v25_supervisor": v25_source_path,
        "v26_supervisor": v26_source_path,
        "v26_test": v26_test_path,
        "v26_verifier": v26_verifier_path,
        "v26_pin_manifest": pin_manifest_path,
    }
    exact_hashes = {}
    for label, path in exact_hash_targets.items():
        actual = sha256_file(path) if path.is_file() else None
        exact_hashes[label] = {
            "path": str(path.relative_to(ROOT)).replace("\\", "/"),
            "bytes": path.stat().st_size if path.is_file() else None,
            "expected_sha256": EXPECTED[label], "actual_sha256": actual,
            "match": actual == EXPECTED[label],
        }
        if actual != EXPECTED[label]:
            errors.append(f"hash mismatch/missing: {label}")

    v25 = load_json(v25_protocol_path)
    v26 = load_json(v26_protocol_path)
    v25_pin_map = {norm(row["path"]): row for row in v25["dependency_file_pins"]}
    v26_pins = v26["dependency_file_pins"]
    v26_pin_map = {norm(row["path"]): row for row in v26_pins}
    pin_results = []
    for row in v26_pins:
        path = Path(row["path"])
        exists = path.is_file()
        actual_bytes = path.stat().st_size if exists else None
        actual_sha = sha256_file(path) if exists else None
        ok = exists and actual_bytes == row["bytes"] and actual_sha == row["sha256"].lower()
        pin_results.append({
            "path": row["path"], "expected_bytes": row["bytes"], "actual_bytes": actual_bytes,
            "expected_sha256": row["sha256"].lower(), "actual_sha256": actual_sha, "match": ok,
        })
        if not ok:
            errors.append(f"V26 input pin mismatch/missing: {row['path']}")

    inherited = sorted(k for k, old in v25_pin_map.items()
                       if k in v26_pin_map and old["bytes"] == v26_pin_map[k]["bytes"]
                       and old["sha256"].lower() == v26_pin_map[k]["sha256"].lower())
    changed = sorted(k for k, old in v25_pin_map.items()
                     if k in v26_pin_map and (old["bytes"] != v26_pin_map[k]["bytes"]
                     or old["sha256"].lower() != v26_pin_map[k]["sha256"].lower()))
    missing = sorted(set(v25_pin_map) - set(v26_pin_map))
    added = sorted(set(v26_pin_map) - set(v25_pin_map))

    # Compare V25 actual-run sidecars against the immutable prior-run receipt.
    prior = v26["prior_v25_receipt_contract_mismatch"]
    sidecar_expectations = {
        "actual_execution": (prior["actual_execution_path"], prior["actual_execution_sha256"], EXPECTED["v25_execution"]),
        "actual_adapter": (prior["actual_adapter_receipt_path"], prior["actual_adapter_receipt_sha256"], EXPECTED["v25_adapter"]),
        "actual_solver_output": (prior["actual_solver_output_path"], prior["actual_solver_output_sha256"], EXPECTED["v25_output"]),
        "actual_stdout": (prior["actual_stdout_path"], prior["actual_stdout_sha256"], EXPECTED["v25_stdout"]),
        "actual_stderr": (prior["actual_stderr_path"], prior["actual_stderr_sha256"], EXPECTED["empty_sha256"]),
    }
    sidecar_results = {}
    for name, (raw_path, protocol_sha, expected_sha) in sidecar_expectations.items():
        path = Path(raw_path)
        current_sha = sha256_file(path) if path.is_file() else None
        row = {"path": raw_path, "protocol_sha256": protocol_sha,
               "handoff_sha256": expected_sha, "current_sha256": current_sha,
               "match": current_sha == protocol_sha == expected_sha}
        sidecar_results[name] = row
        if not row["match"]:
            errors.append(f"V25 actual sidecar mismatch: {name}")
    all_v25_actual_files = []
    for path in sorted(v25_actual_path.rglob("*")):
        if path.is_file():
            all_v25_actual_files.append({
                "path": str(path.relative_to(ROOT)).replace("\\", "/"),
                "bytes": path.stat().st_size, "sha256": sha256_file(path),
            })

    # Diff executable sources; only module docstring plus the two receipt literals may differ.
    old_lines = v25_source_path.read_text(encoding="utf-8").splitlines()
    new_lines = v26_source_path.read_text(encoding="utf-8").splitlines()
    matcher = difflib.SequenceMatcher(a=old_lines, b=new_lines, autojunk=False)
    changed_hunks = []
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag != "equal":
            changed_hunks.append({
                "tag": tag, "v25_start_line": i1 + 1, "v26_start_line": j1 + 1,
                "v25_lines": old_lines[i1:i2], "v26_lines": new_lines[j1:j2],
            })
    old_changed = [line for h in changed_hunks for line in h["v25_lines"]]
    new_changed = [line for h in changed_hunks for line in h["v26_lines"]]
    expected_old = [
        '"""Fail-closed sampled process-tree supervisor for the FreeGS v25 candidate.',
        '        "supervisor_version": "freegs-process-supervisor-v24",',
        '        "tree_observation_contract": "complete_sampled_recursive_tree_rss_and_tracked_descendant_exit_v2_popen_identity_bound",',
    ]
    expected_new = [
        '"""Fail-closed sampled process-tree supervisor for the FreeGS v26 candidate.',
        '        "supervisor_version": "freegs-process-supervisor-v26",',
        '        "tree_observation_contract": "complete_sampled_recursive_tree_rss_and_tracked_descendant_exit_v2_popen_identity_bound_strictly_typed",',
    ]

    scope = v26["protocol_scope_contract_v22"]
    resource = v26["resource_contract"]
    output_join = v26["runtime_endpoint_join"]
    output_path = Path(output_join["output_leaf"])
    v26_scope = v26["scope"]
    v25_scope = v25["scope"]

    # Child calls are Python-only. Preserve the exact argv, outputs and exit codes.
    verifier_argv = [sys.executable, "-B", str(v26_verifier_rel), str(V26_PROTOCOL_REL)]
    tests_argv = [sys.executable, "-B", str(v26_test_rel), "-v"]
    child_runs = {}
    for label, argv in (("verifier", verifier_argv), ("fake_tests", tests_argv)):
        completed = subprocess.run(argv, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   check=False, shell=False)
        (OUT / f"{label}.stdout.raw").write_bytes(completed.stdout)
        (OUT / f"{label}.stderr.raw").write_bytes(completed.stderr)
        (OUT / f"{label}.exit.txt").write_text(f"{completed.returncode}\n", encoding="ascii", newline="\n")
        child_runs[label] = {
            "argv": argv, "cwd": str(ROOT), "exit_code": completed.returncode,
            "stdout_bytes": len(completed.stdout), "stdout_sha256": sha256_bytes(completed.stdout),
            "stderr_bytes": len(completed.stderr), "stderr_sha256": sha256_bytes(completed.stderr),
            "stdout_path": f"{label}.stdout.raw", "stderr_path": f"{label}.stderr.raw",
            "exit_path": f"{label}.exit.txt",
        }

    test_transcript = (OUT / "fake_tests.stdout.raw").read_bytes() + (OUT / "fake_tests.stderr.raw").read_bytes()
    test_text = test_transcript.decode("utf-8", errors="replace")
    tests_54 = "Ran 54 tests" in test_text and "OK" in test_text
    verifier_ok = child_runs["verifier"]["exit_code"] == 0
    tests_ok = child_runs["fake_tests"]["exit_code"] == 0 and tests_54

    checks.update({
        "frozen_protocol_and_code_hashes_match": all(row["match"] for row in exact_hashes.values()),
        "all_194_v26_dependency_pins_rehashed": len(v26_pins) == v26["dependency_file_pin_count"] == 194 and sum(row["match"] for row in pin_results) == 194,
        "exactly_190_v25_pins_inherited_and_four_v26_files_added": len(v25_pin_map) == 190 and len(inherited) == 190 and not changed and not missing and len(added) == 4,
        "v25_actual_receipt_sidecars_match_protocol_and_current_bytes": all(row["match"] for row in sidecar_results.values()),
        "v25_actual_output_is_preserved_unchanged": prior.get("actual_output_preserved_unchanged") is True,
        "source_diff_is_only_docstring_plus_two_metadata_literals": old_changed == expected_old and new_changed == expected_new,
        "scope_is_exact_17_key_inventory_and_unchanged_from_v25": len(v26_scope) == 17 and scope["scope_key_count"] == 17 and set(scope["scope_key_names"]) == set(v26_scope) and v26_scope == v25_scope and scope["current_scope"] == v26_scope,
        "resource_caps_unchanged_from_v25": resource["wall_seconds_per_step"] == 180 and resource["process_tree_rss_bytes_per_step"] == 2_147_483_648 and resource["julia_threads"] == resource["blas_threads"] == 1 and resource == v25["resource_contract"],
        "v26_runtime_ungranted_and_output_leaf_absent": v26["runtime_execution_authorized"] is False and v26["root_resource_slot"]["granted"] is False and output_join["output_leaf_absent_at_candidate_freeze"] is True and not output_path.exists(),
        "test_only_claim_scope_has_no_physical_or_inverse_credit": v26_scope.get("physical_validation") is False and v26_scope.get("reference_inversion_G1_G2_G3") is False and v26_scope.get("formal_acceptance") is False and v26_scope.get("engineering_validation") is False and prior.get("runtime_or_physics_credit") is False,
        "static_verifier_exit_0": verifier_ok,
        "fake_test_suite_exit_0_and_54_tests": tests_ok,
    })
    for name, passed in checks.items():
        if not passed:
            errors.append(f"check failed: {name}")

    verdict = "GO_FOR_ONE_BOUNDED_TEST_ONLY_RERUN" if all(checks.values()) else "NO_GO"
    receipt = {
        "schema": "independent-freegs-v26-metadata-review-v1",
        "reviewer_role": "independent_python_only_static_tester",
        "protocol_path": str(V26_PROTOCOL_REL).replace("\\", "/"),
        "protocol_sha256": sha256_file(v26_protocol_path),
        "verdict": verdict,
        "bounded_authorization_boundary": "GO covers one future bounded test-only run only after root's fresh exclusive-process audit and separate grant. No FreeGS/Julia was run here; no physical, inverse, engineering, or formal-acceptance credit is conferred.",
        "checks": checks,
        "errors": errors,
        "frozen_artifact_hashes": exact_hashes,
        "pin_closure": {
            "v25_count": len(v25_pin_map), "v26_count": len(v26_pins),
            "matched_current_count": sum(row["match"] for row in pin_results),
            "inherited_v25_count": len(inherited), "changed_v25_paths": changed,
            "missing_v25_paths": missing,
            "added_v26_paths": [v26_pin_map[k]["path"] for k in added],
            "mismatches": [row for row in pin_results if not row["match"]],
        },
        "v25_actual_sidecars": sidecar_results,
        "v25_actual_leaf_inventory": all_v25_actual_files,
        "source_diff": {
            "v25_path": str(V25_SUPERVISOR_REL).replace("\\", "/"),
            "v26_path": str(V26_SUPERVISOR_REL).replace("\\", "/"),
            "changed_hunks": changed_hunks,
            "only_expected_docstring_and_two_receipt_metadata_literals": old_changed == expected_old and new_changed == expected_new,
        },
        "scope_and_budget": {
            "scope_key_count": scope["scope_key_count"], "scope_key_names": scope["scope_key_names"],
            "scope_unchanged_from_v25": v26_scope == v25_scope,
            "wall_seconds_per_step": resource["wall_seconds_per_step"],
            "process_tree_rss_bytes_per_step": resource["process_tree_rss_bytes_per_step"],
            "julia_threads": resource["julia_threads"], "blas_threads": resource["blas_threads"],
            "runtime_execution_authorized": v26["runtime_execution_authorized"],
            "output_leaf": str(output_path), "output_leaf_exists": output_path.exists(),
        },
        "python_child_runs": child_runs,
    }
    write_json(OUT / "independent_review_receipt.json", receipt)
    command = {
        "outer_argv": [sys.executable, "-B", sys.argv[0]], "cwd": str(ROOT),
        "exit_code": 0, "python_no_bytecode": bool(sys.flags.dont_write_bytecode),
        "child_commands": child_runs,
        "scope": "Python-only static hash/diff review; ran V26 verifier and fake-process unit tests; no FreeGS/Julia",
    }
    write_json(OUT / "command_argv.json", command)
    receipt_sha = sha256_file(OUT / "independent_review_receipt.json")
    summary = {
        "schema": "independent-freegs-v26-review-summary-v1", "verdict": verdict,
        "failed_checks": [key for key, value in checks.items() if not value],
        "receipt_sha256": receipt_sha,
    }
    summary_bytes = (json.dumps(summary, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode("utf-8")
    (OUT / "audit.stdout.raw").write_bytes(summary_bytes)
    (OUT / "audit.stderr.raw").write_bytes(b"")
    (OUT / "audit.exit.txt").write_text("0\n", encoding="ascii", newline="\n")

    source_path = Path(__file__).resolve()
    evidence_files = []
    for path in sorted(OUT.iterdir()):
        if path.is_file():
            evidence_files.append({"path": path.name, "bytes": path.stat().st_size,
                                   "sha256": sha256_file(path)})
    manifest = {
        "schema": "independent-freegs-v26-review-evidence-manifest-v1",
        "evidence_leaf": str(OUT.relative_to(ROOT)).replace("\\", "/"),
        "source_path": str(source_path.relative_to(ROOT)).replace("\\", "/"),
        "source_bytes": source_path.stat().st_size, "source_sha256": sha256_file(source_path),
        "evidence_files_excluding_manifest": evidence_files,
    }
    write_json(OUT / "evidence_manifest.json", manifest)
    sys.stdout.write(summary_bytes.decode("utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
