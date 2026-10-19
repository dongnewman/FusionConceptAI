#!/usr/bin/env python3
"""Independent Python-only verification of the frozen FreeGS v17 candidate."""
from __future__ import annotations

import ast
import copy
import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ARCHIVE = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive"
LEAF = ARCHIVE / "agent_reference_gs_freegs_v17_static_r1_20260924"
OUT = ARCHIVE / "independent_freegs_v17_static_review_20260924"
PROTOCOL_REL = "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v8/actual_run_protocol_v17_candidate_v1.json"
PROTOCOL_SHA = "b880712fd7adaa4d7079226a12af9001d330fcc2f014130ef056651ef17ec5ed"
POLICY_SHA = "703e29e906274ae9b95aedb16f4b2df2a8255b83ced873f6472a8eccfcffde18"
RUNNER_SHA = "993a98cb19403de99f565bb11c16a2de0d7baa2cfdcbec0ba75ed61a2156ee58"
TEST_SHA = "3e0bf0f0891744241778f4c991178fc34216917cdf42324269f5c352d17c0e16"
VERIFIER_SHA = "1c9ee96e29cbafe861d9aa6628979a3101108635240a39d187a6cba8b3228b40"
HANDOFF_SHA = "75d5d0cd4aa570558a1f03c79e49bd3f9a2d005e51799906380320c741778197"
EVIDENCE_MANIFEST_SHA = "bf5a40ec19ca65201edee02d8de3f46a7195bb194308f589ee5ed475afc7d96a"
STATIC_TEST_OUTPUTS = {
    "v17_python_fake_tests.stdout.txt": "64ffafb548ee40c1c0e83cd4c6db3996bc25045869457209c7c35dfc2c6f94a0",
    "v16_dirichlet_fake_matrix_tests.stdout.txt": "6ccb1288af2d4f431eaeac88a273276125ed064cd63fa871018652af99cef29c",
    "v17_static_verifier.stdout.txt": "521fa715481d981f792d881f6ef2486e519f0690e5380894d68b5d30ff083b30",
}
EXPECTED_DIRECT = {
    "tools/up4_reference_validation/freegs_fixed_box_picard_v1.py": POLICY_SHA,
    "tools/up4_reference_validation/runtime_v4_freegs_axisymmetric_profile_runner_v8.py": RUNNER_SHA,
    "tools/up4_reference_validation/verify_freegs_v17_protocol_candidate.py": VERIFIER_SHA,
    "test/UP4ReferenceValidationV1/test_freegs_fixed_box_picard_v1.py": TEST_SHA,
    "tools/up4_reference_validation/freegs_observed_dirichlet_boundary_v4.py": "7565a6758808c036b0595293d297bbcd5c25c92f734499a21dedb25bcc2f634e",
    "tools/up4_reference_validation/freegs_dirichlet_elimination_v1.py": "06a3ddee2507289c0ee876bfba4108e562c96e46203d6416a0b0be6798f79eff",
    "tools/up4_reference_validation/runtime_v4_freegs_axisymmetric_profile_runner_v7.py": "8f14a5d43b53435bd62c1846d8dcd8e84068fd6a599579935d352b7bb7292ce9",
}
EXPECTED_LEAF = {
    "review_handoff.json": HANDOFF_SHA,
    "static_execution_summary.json": "ff35c13144c5eba966f0c1d3b17d627d5449405d79ac0c1d87d50346615d163f",
    "v16_dirichlet_fake_matrix_tests.stdout.txt": STATIC_TEST_OUTPUTS["v16_dirichlet_fake_matrix_tests.stdout.txt"],
    "v17_python_fake_tests.stdout.txt": STATIC_TEST_OUTPUTS["v17_python_fake_tests.stdout.txt"],
    "v17_static_verifier.stdout.txt": STATIC_TEST_OUTPUTS["v17_static_verifier.stdout.txt"],
}


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_receipt(path: Path, rel: str) -> dict:
    blob = path.read_bytes()
    return {"path": rel.replace("\\", "/"), "bytes": len(blob), "sha256": sha_bytes(blob)}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def imported_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import reviewer target: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check_sidecar_negatives(protocol: dict) -> list[dict]:
    verifier = imported_module(ROOT / "tools/up4_reference_validation/verify_freegs_v17_protocol_candidate.py", "independent_v17_verifier")
    rows = []
    def record(name: str, passed: bool, observed: str):
        rows.append({"name": name, "pass": bool(passed), "observed": observed})

    endpoint = protocol["runtime_endpoint_join"]
    expected_output = Path(endpoint["solver_output"])
    sidecars = protocol["mandatory_evidence_sidecars"]
    try:
        returned = verifier.validate_mandatory_sidecars(sidecars, expected_output)
        all_absent = all(not p.exists() for p in returned.values()) and not expected_output.parent.exists()
        record("frozen mandatory sidecars bind to absent same archive leaf", len(returned) == 5 and all_absent, str(expected_output.parent))
    except Exception as exc:
        record("frozen mandatory sidecars bind to absent same archive leaf", False, type(exc).__name__ + ": " + str(exc))

    keys = ("adapter_receipt", "execution", "solver_output", "stdout", "stderr")
    for key in keys:
        changed = copy.deepcopy(sidecars)
        changed[key] = str(expected_output.parent.parent / f"retargeted-{key}.json")
        try:
            verifier.validate_mandatory_sidecars(changed, expected_output)
            record("retargeted sidecar rejected: " + key, False, "accepted")
        except RuntimeError as exc:
            record("retargeted sidecar rejected: " + key, "not bound" in str(exc) or "schema changed" in str(exc), str(exc))

    changed = copy.deepcopy(sidecars)
    changed["unexpected"] = "extra"
    try:
        verifier.validate_mandatory_sidecars(changed, expected_output)
        record("unknown sidecar key rejected", False, "accepted")
    except RuntimeError as exc:
        record("unknown sidecar key rejected", "schema changed" in str(exc), str(exc))

    changed = copy.deepcopy(sidecars)
    changed["storage_rule"] = "write anywhere"
    try:
        verifier.validate_mandatory_sidecars(changed, expected_output)
        record("storage rule mutation rejected", False, "accepted")
    except RuntimeError as exc:
        record("storage rule mutation rejected", "storage rule changed" in str(exc), str(exc))

    with tempfile.TemporaryDirectory(prefix="sidecar-probe-", dir=OUT) as raw:
        leaf = Path(raw) / "archive" / "fake-output"
        leaf.mkdir(parents=True)
        output = leaf / "solver_output.json"
        fake = {
            "adapter_receipt": str(leaf / "freegs_adapter_receipt_v17.json"),
            "execution": str(leaf / "execution.json"),
            "solver_output": str(output),
            "stdout": str(leaf / "stdout.raw"),
            "stderr": str(leaf / "stderr.raw"),
            "storage_rule": sidecars["storage_rule"],
        }
        try:
            verifier.validate_mandatory_sidecars(fake, output)
            (leaf / "execution.json").write_bytes(b"existing evidence")
            try:
                verifier.validate_mandatory_sidecars(fake, output)
                record("preexisting sidecar rejected", False, "accepted")
            except RuntimeError as exc:
                record("preexisting sidecar rejected", "already exists" in str(exc), str(exc))
        except Exception as exc:
            record("preexisting sidecar rejected", False, type(exc).__name__ + ": " + str(exc))

    with tempfile.TemporaryDirectory(prefix="outside-archive-") as raw:
        leaf = Path(raw) / "run"
        leaf.mkdir()
        output = leaf / "solver_output.json"
        fake = {k: str(leaf / filename) for k, filename in {
            "adapter_receipt": "freegs_adapter_receipt_v17.json", "execution": "execution.json",
            "solver_output": "solver_output.json", "stdout": "stdout.raw", "stderr": "stderr.raw",
        }.items()}
        fake["storage_rule"] = sidecars["storage_rule"]
        try:
            verifier.validate_mandatory_sidecars(fake, output)
            record("nonarchive output rejected", False, "accepted")
        except RuntimeError as exc:
            record("nonarchive output rejected", "outside archive" in str(exc), str(exc))
    return rows


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    checks = []
    def check(name: str, passed: bool, detail=None):
        checks.append({"name": name, "pass": bool(passed), **({"detail": detail} if detail is not None else {})})

    protocol_path = ROOT / PROTOCOL_REL
    protocol = load_json(protocol_path)
    handoff = load_json(LEAF / "review_handoff.json")
    evidence_manifest = load_json(LEAF / "evidence_manifest.json")

    current_protocol = file_receipt(protocol_path, PROTOCOL_REL)
    check("exact frozen v17 protocol hash", current_protocol["sha256"] == PROTOCOL_SHA)
    check("handoff and evidence manifest anchors", sha_bytes((LEAF / "review_handoff.json").read_bytes()) == HANDOFF_SHA and sha_bytes((LEAF / "evidence_manifest.json").read_bytes()) == EVIDENCE_MANIFEST_SHA and evidence_manifest.get("candidate_protocol_sha256") == PROTOCOL_SHA)

    leaf_inventory = {p.relative_to(LEAF).as_posix(): file_receipt(p, p.relative_to(LEAF).as_posix()) for p in LEAF.rglob("*") if p.is_file() and p.name != "evidence_manifest.json"}
    expected_leaf = {name: sha for name, sha in EXPECTED_LEAF.items()}
    actual_leaf_shas = {name: row["sha256"] for name, row in leaf_inventory.items()}
    check("static evidence leaf inventory/pins", actual_leaf_shas == expected_leaf and len(evidence_manifest.get("entries", [])) == 5 and evidence_manifest.get("evidence_only") is True, actual_leaf_shas)

    deps = protocol.get("dependency_file_pins", [])
    pin_rows = []
    pin_errors = []
    seen = set()
    for item in deps:
        raw_path = item.get("path", "")
        normalized = str(Path(raw_path).resolve()).casefold()
        if normalized in seen:
            pin_errors.append("duplicate:" + raw_path)
        seen.add(normalized)
        p = Path(raw_path)
        if not p.is_file():
            pin_errors.append("missing:" + raw_path)
            continue
        row = file_receipt(p, raw_path)
        pin_rows.append(row)
        if row["bytes"] != item.get("bytes") or row["sha256"] != item.get("sha256"):
            pin_errors.append("drift:" + raw_path)
    check("all 162 protocol dependency pins rehashed", len(deps) == 162 and len(pin_rows) == 162 and not pin_errors and protocol.get("dependency_file_pin_count") == 162, {"count": len(pin_rows), "errors": pin_errors[:8]})

    direct_receipts = {rel: file_receipt(ROOT / rel, rel) for rel in EXPECTED_DIRECT}
    check("runner policy verifier and v16 dependencies exact pins", all(direct_receipts[k]["sha256"] == sha for k, sha in EXPECTED_DIRECT.items()), direct_receipts)
    pinned_picard = Path(protocol["v17_fixed_box_policy"]["pinned_native_picard_source_path"])
    picard_receipt = file_receipt(pinned_picard, str(pinned_picard))
    check("native FreeGS picard.py exact source pin", picard_receipt["sha256"] == protocol["v17_fixed_box_policy"]["pinned_native_picard_source_sha256"] == "731722b98c97dfd758428a411dce684806e36e8cb6e38e69f23552451646880f")

    policy_block = protocol["v17_fixed_box_policy"]
    resource = protocol["resource_contract"]
    check("candidate remains ungranted and physical credit absent", protocol.get("state") == "review_candidate_ungranted_not_dispatched" and protocol.get("runtime_execution_authorized") is False and protocol.get("root_resource_slot", {}).get("granted") is False and protocol.get("scope", {}).get("physical_validation") is False and policy_block.get("physical_or_inverse_credit") is False)
    check("same runtime limits and frozen numerical controls", resource.get("wall_seconds_per_step") == 180 and resource.get("process_tree_rss_bytes_per_step") == 2_147_483_648 and resource.get("julia_threads") == 1 and resource.get("blas_threads") == 1 and protocol.get("v7_runner", {}).get("numerical_controls", {}).get("atol") == 1e-10 and protocol.get("v7_runner", {}).get("numerical_controls", {}).get("rtol") == 1e-5 and protocol.get("v7_runner", {}).get("numerical_controls", {}).get("maxits") == 100 and protocol.get("v7_runner", {}).get("numerical_controls", {}).get("blend") == 0.0 and protocol.get("v7_runner", {}).get("picard_controls_changed") is False)
    check("1e-12 cap remains historical only and no corner proxy", policy_block.get("historical_v15_guard_cap_wb_per_rad") == 1e-12 and policy_block.get("historical_v15_guard_used_as_acceptance_threshold") is False and policy_block.get("psi_bndry_proxy_read_for_stopping") is False and policy_block.get("psi_bndry_proxy_write") is False)
    expected_trajectory = [
        {"observed_eq_solve_call_index": 1, "xpoints_before_solve": 4, "xpoints_after_solve": 2},
        {"observed_eq_solve_call_index": 2, "xpoints_before_solve": 2, "xpoints_after_solve": 0},
        {"observed_eq_solve_call_index": 3, "xpoints_before_solve": 0, "xpoints_after_solve": 0},
    ]
    check("prior v16 topology trajectory exactly 4 to 2 to 0", protocol.get("prior_actual_v16_numerical_run", {}).get("observed_xpoint_transitions") == expected_trajectory)
    check("v17 terminal topology gate and transient recording semantics", policy_block.get("terminal_topology_gate") == "after psi convergence only: fail closed if terminal xpoint_count != 0 or is_limited" and policy_block.get("transient_topology") == "observe/record every solve call; permit transient X-points to disappear" and protocol.get("v17_fixed_box_policy", {}).get("native_picard_iteration_count") == "not_run_not_inferred")
    check("fresh runtime output leaf absent and same-leaf sidecars bound", protocol.get("runtime_endpoint_join", {}).get("output_leaf_absent_at_candidate_freeze") is True and protocol.get("mandatory_evidence_sidecars", {}).get("solver_output") == protocol.get("runtime_endpoint_join", {}).get("solver_output") and protocol.get("runtime_endpoint_join", {}).get("output_leaf") == str(Path(protocol.get("runtime_endpoint_join", {}).get("output_leaf", ""))) and not Path(protocol.get("runtime_endpoint_join", {}).get("output_leaf", "")).exists())

    policy_path = ROOT / "tools/up4_reference_validation/freegs_fixed_box_picard_v1.py"
    policy_tree = ast.parse(policy_path.read_text(encoding="utf-8"))
    psi_bndry_attrs = [n for n in ast.walk(policy_tree) if isinstance(n, ast.Attribute) and n.attr == "psi_bndry"]
    check("policy has no eq.psi_bndry attribute read/write", not psi_bndry_attrs)

    cmd_specs = [
        ("v17 fake policy tests", [sys.executable, "-B", "test/UP4ReferenceValidationV1/test_freegs_fixed_box_picard_v1.py", "-v"], 15),
        ("v16 fake matrix tests", [sys.executable, "-B", "test/UP4ReferenceValidationV1/test_freegs_dirichlet_elimination_v1.py", "-v"], 23),
        ("static protocol verifier", [sys.executable, "-B", "tools/up4_reference_validation/verify_freegs_v17_protocol_candidate.py", PROTOCOL_REL], None),
    ]
    command_receipts = []
    command_results = {}
    for name, argv, count in cmd_specs:
        result = subprocess.run(argv, cwd=ROOT, capture_output=True, text=True, check=False)
        run = {
            "name": name, "argv": argv, "cwd": str(ROOT), "exit_code": result.returncode,
            "stdout": result.stdout, "stderr": result.stderr,
            "stdout_sha256": sha_bytes(result.stdout.encode()), "stderr_sha256": sha_bytes(result.stderr.encode()),
            "freegs_or_julia_started_by_checker": False,
        }
        if count is not None:
            run["expected_tests"] = count
            run["test_summary_found"] = f"Ran {count} tests" in result.stderr and "OK" in result.stderr
        else:
            try:
                run["parsed_stdout"] = json.loads(result.stdout.strip())
            except json.JSONDecodeError:
                run["parsed_stdout"] = None
        command_receipts.append(run)
        command_results[name] = run
        if count is not None:
            check(name + " exit and full test count", result.returncode == 0 and run["test_summary_found"])
        else:
            parsed = run["parsed_stdout"] or {}
            check(name + " natural exit and ungranted static status", result.returncode == 0 and parsed.get("status") == "static_protocol_check_pass_ungranted" and parsed.get("dependency_pin_count") == 162 and parsed.get("freegs_or_julia_started") is False and parsed.get("runtime_execution_authorized") is False and parsed.get("mandatory_sidecars_bound_to_same_fresh_archive_leaf") is True and parsed.get("v16_failure_and_exact_4_to_2_to_0_xpoint_trajectory_bound") == expected_trajectory)

    v17_test_output = command_results["v17 fake policy tests"]["stderr"]
    required_v17_assertions = (
        "test_transient_xpoints_4_to_2_to_0_are_recorded_terminal_empty_passes",
        "test_terminal_xpoint_fails_closed_after_psi_gate",
        "test_terminal_limited_state_fails_closed",
        "test_signed_zero_edge_drift_fails_even_when_array_equal_is_true",
        "test_freegs_proxy_does_not_mutate_imported_module",
        "test_runner_binding_context_restores_and_marks_v17_output",
        "test_runner_binding_context_restores_after_body_exception",
        "test_v17_sidecar_verifier_binds_all_required_files_to_new_leaf",
        "test_v17_sidecar_verifier_rejects_output_outside_archive",
    )
    v16_test_output = command_results["v16 fake matrix tests"]["stderr"]
    check("requested topology, exact-edge, proxy and restoration assertions ran", all(name + " (__main__." in v17_test_output for name in required_v17_assertions) and "test_adapter_does_not_write_psi_bndry_or_call_set_solver_vcycle" in v16_test_output and "test_marked_target_uses_reduced_solver_and_restores_instance_hooks" in v16_test_output)

    output_leaf = Path(protocol["runtime_endpoint_join"]["output_leaf"])
    check("independent static runs did not create the runtime output leaf", not output_leaf.exists())

    sidecar_controls = check_sidecar_negatives(protocol)
    check("sidecar positive and all binding/freshness fail-closed controls", all(row["pass"] for row in sidecar_controls), sidecar_controls)

    all_pass = all(row["pass"] for row in checks)
    pin_inventory = {
        "dependency_pin_count": len(pin_rows),
        "dependency_pins": pin_rows,
        "direct_pins": list(direct_receipts.values()),
        "native_picard": picard_receipt,
    }
    verification = {
        "schema": "independent_freegs_v17_static_review_v1",
        "verdict": "PASS_STATIC_UNGRANTED_CANDIDATE_ONLY" if all_pass else "NO_GO",
        "scope": "Read-only Python verification of frozen FreeGS v17 protocol/source pins, fake-object suites, static verifier, terminal/transient topology policy, and same-leaf sidecar binding. No FreeGS or Julia process was launched.",
        "candidate_protocol": current_protocol,
        "handoff": file_receipt(LEAF / "review_handoff.json", str((LEAF / "review_handoff.json").relative_to(ROOT))),
        "evidence_manifest": file_receipt(LEAF / "evidence_manifest.json", str((LEAF / "evidence_manifest.json").relative_to(ROOT))),
        "pin_inventory": pin_inventory,
        "commands": command_receipts,
        "sidecar_negative_controls": sidecar_controls,
        "checks": checks,
        "runtime_output_leaf": {"path": str(output_leaf), "exists_after_review": output_leaf.exists()},
        "claim_boundary": {"runtime_authorized": False, "solver_executed": False, "numerical_status": "not_established", "physical_status": "unknown"},
    }
    verification_path = OUT / "verification.json"
    verification_path.write_text(json.dumps(verification, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    manifest = {
        "schema": "independent_freegs_v17_static_review_manifest_v1",
        "verification": file_receipt(verification_path, str(verification_path.relative_to(ROOT))),
        "checker_source": file_receipt(Path(__file__).resolve(), str(Path(__file__).resolve().relative_to(ROOT))),
        "candidate_protocol": current_protocol,
        "handoff": file_receipt(LEAF / "review_handoff.json", str((LEAF / "review_handoff.json").relative_to(ROOT))),
        "evidence_manifest": file_receipt(LEAF / "evidence_manifest.json", str((LEAF / "evidence_manifest.json").relative_to(ROOT))),
        "checked_dependency_pin_count": len(pin_rows),
        "command_exits": {r["name"]: r["exit_code"] for r in command_receipts},
        "review_exit_code": 0 if all_pass else 1,
    }
    manifest_path = OUT / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "verdict": verification["verdict"], "checks_passed": sum(row["pass"] for row in checks),
        "checks_total": len(checks), "pins_rehashed": len(pin_rows),
        "sidecar_controls_passed": sum(row["pass"] for row in sidecar_controls),
        "sidecar_controls_total": len(sidecar_controls),
        "verification_sha256": sha_bytes(verification_path.read_bytes()),
        "manifest_sha256": sha_bytes(manifest_path.read_bytes()),
    }, sort_keys=True))
    return 0 if all_pass else 1


if __name__ == "__main__":
    raise SystemExit(main())
