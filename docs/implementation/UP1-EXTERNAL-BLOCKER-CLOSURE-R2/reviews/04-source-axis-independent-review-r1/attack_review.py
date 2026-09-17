from __future__ import annotations

import copy
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
RAW = OUT / "raw"
sys.path.insert(0, str(ROOT / "tools" / "up1_external_closure_r2"))
sys.path.insert(0, str(ROOT / "test" / "up1_external_closure_r2" / "source_axis_binding"))

from source_axis_binding import capture_source_identity, material_digest, source_identity_digest, validate_bundle
from test_source_axis_binding import fixture


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def utc() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def run_process(name: str, argv: list[str], *, input_bytes: bytes | None = None, env: dict[str, str] | None = None) -> dict:
    started = utc()
    proc = subprocess.Popen(argv, cwd=ROOT, env=env, stdin=subprocess.PIPE if input_bytes is not None else None, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate(input_bytes)
    ended = utc()
    stdout_path = RAW / f"{name}.stdout.raw"
    stderr_path = RAW / f"{name}.stderr.raw"
    stdout_path.write_bytes(stdout)
    stderr_path.write_bytes(stderr)
    return {
        "argv": argv,
        "pid": proc.pid,
        "started_utc": started,
        "ended_utc": ended,
        "exit_code": proc.returncode,
        "stdout": {"path": str(stdout_path.relative_to(OUT)).replace("\\", "/"), "bytes": len(stdout), "sha256": sha(stdout)},
        "stderr": {"path": str(stderr_path.relative_to(OUT)).replace("\\", "/"), "bytes": len(stderr), "sha256": sha(stderr)},
    }


def rebuild(v: dict) -> None:
    ident = v["source_identity"]
    ident["source_identity_digest"] = source_identity_digest(ident)
    for m in v["axis_materials"]:
        m["source_identity_digest"] = ident["source_identity_digest"]
        m["digest"] = material_digest(m)
        edge = {k: m[k] for k in ("axis", "candidate_id", "namespace", "version", "issuer", "issued_at")}
        edge["source_identity_digest"] = ident["source_identity_digest"]
        edge["material_digest"] = m["digest"]
        m["source_edge"] = copy.deepcopy(edge)
        m["candidate_edge"] = copy.deepcopy(edge)
    ident["axis_edges"] = {m["axis"]: copy.deepcopy(m["source_edge"]) for m in v["axis_materials"]}
    v["candidate_axis_edges"] = {m["axis"]: copy.deepcopy(m["candidate_edge"]) for m in v["axis_materials"]}


def case(case_id: str, value: dict, expected: str) -> dict:
    try:
        result = validate_bundle(value)
        observed = "reject" if not result.get("valid") else "accept"
        ok = observed == expected
        return {"case_id": case_id, "expected": expected, "observed": observed, "ok": ok,
                "status": result.get("status"), "authority_evidence": result.get("authority_evidence"),
                "errors": [x.get("code") for x in result.get("errors", [])]}
    except Exception as exc:
        return {"case_id": case_id, "expected": expected, "observed": "program_exception", "ok": expected == "program_exception", "error": f"{type(exc).__name__}:{exc}"}


def main() -> int:
    RAW.mkdir(parents=True, exist_ok=True)
    cases: list[dict] = []

    v = fixture()
    v["state"] = "EXTERNAL_ISSUED"
    v["provenance_class"] = "external_issued"
    for m in v["axis_materials"]:
        m["issuer"] = "self-reported-issuer"
    rebuild(v)
    cases.append(case("AUTH-ISSUER-ONLY-NO-SIGNATURE-TIME-G2", v, "reject"))

    v = fixture()
    m = v["axis_materials"][0]
    m["source_identity_digest"] = "f" * 64
    m["digest"] = material_digest(m)
    edge = {k: m[k] for k in ("axis", "candidate_id", "namespace", "version", "issuer", "issued_at")}
    edge["source_identity_digest"] = v["source_identity"]["source_identity_digest"]
    edge["material_digest"] = m["digest"]
    m["source_edge"] = copy.deepcopy(edge)
    m["candidate_edge"] = copy.deepcopy(edge)
    v["source_identity"]["axis_edges"][m["axis"]] = copy.deepcopy(edge)
    v["candidate_axis_edges"][m["axis"]] = copy.deepcopy(edge)
    cases.append(case("FOREIGN-MATERIAL-SOURCE-DIGEST", v, "reject"))

    v = fixture()
    v["schema"] = "unrecognized-schema"
    v["source_identity"]["unknown_field"] = True
    v["axis_materials"][0]["unknown_field"] = True
    rebuild(v)
    cases.append(case("UNKNOWN-SCHEMA-AND-FIELDS", v, "reject"))

    v = fixture()
    v["axis_materials"].append("scalar-extra")
    cases.append(case("SCALAR-MATERIAL-SILENTLY-DROPPED", v, "reject"))

    v = fixture()
    v["candidate_axis_edges"]["extra"] = []
    cases.append(case("SCALAR-EDGE-SILENTLY-DROPPED", v, "reject"))

    v = fixture()
    v["axis_materials"][0]["candidate_id"] = "foreign-a"
    v["axis_materials"][1]["candidate_id"] = "foreign-b"
    forward = validate_bundle(v)
    reversed_bundle = copy.deepcopy(v)
    reversed_bundle["axis_materials"] = list(reversed(reversed_bundle["axis_materials"]))
    backward = validate_bundle(reversed_bundle)
    cases.append({"case_id": "ERROR-ORDER-AXIS-PERMUTATION", "expected": "permutation-invariant", "observed": "permutation-invariant" if forward == backward else "order-sensitive", "ok": forward == backward,
                  "forward_error_paths": [x.get("path") for x in forward.get("errors", [])], "reversed_error_paths": [x.get("path") for x in backward.get("errors", [])]})

    v = fixture()
    v["state"] = "EXTERNAL_ISSUED"
    v["provenance_class"] = "external_issued"
    for m in v["axis_materials"]:
        m.pop("signature", None)
        m["issuer"] = "issuer-without-verifier"
    rebuild(v)
    cases.append(case("MISSING-SIGNATURE-TRUSTED-TIME-G2-MAPPING", v, "reject"))

    v = fixture()
    v["schema"] = "UP1-R2.source-axis-binding.bundle.v1"
    duplicate_json = json.dumps(v, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    token = '"candidate_id":"candidate-up1-r2-test-001"'
    duplicate_json = duplicate_json.replace(token, '"candidate_id":"duplicate-key-value",' + token, 1)
    cli_env = dict(os.environ)
    cli_env["PYTHONPATH"] = str(ROOT / "tools" / "up1_external_closure_r2")
    dup_started = utc()
    dup = subprocess.run([sys.executable, "-B", "-m", "source_axis_binding"], cwd=ROOT, env=cli_env, input=duplicate_json.encode("utf-8"), capture_output=True)
    dup_ended = utc()
    (RAW / "duplicate_json.stdout.raw").write_bytes(dup.stdout)
    (RAW / "duplicate_json.stderr.raw").write_bytes(dup.stderr)
    cases.append({"case_id": "DUPLICATE-JSON-KEY-CLI", "expected": "reject", "observed": "reject" if dup.returncode else "accept", "ok": dup.returncode != 0,
                  "exit_code": dup.returncode, "started_utc": dup_started, "ended_utc": dup_ended,
                  "parsed_status": json.loads(dup.stdout.decode("utf-8")).get("status") if dup.stdout else None})

    captured = capture_source_identity(ROOT)
    snapshot = json.loads((ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/11-source-capture/snapshot.json").read_text(encoding="utf-8"))
    untracked = subprocess.check_output(["git", "status", "--porcelain=v1", "--untracked-files=all"], cwd=ROOT)
    has_untracked = any(line.startswith(b"?? ") for line in untracked.splitlines())
    cases.append({"case_id": "CAPTURE-MISSING-HEAD-TREE", "expected": "head_tree-bound", "observed": "head_tree-bound" if "head_tree" in captured else "head_tree-absent", "ok": "head_tree" in captured,
                  "snapshot_head_tree_present": "head_tree" in snapshot})
    cases.append({"case_id": "CAPTURE-UNTRACKED-CONTENT-BLIND", "expected": "content-hash-bound", "observed": "content-hash-bound" if not has_untracked else "path-only-untracked-status", "ok": not has_untracked,
                  "untracked_present": has_untracked, "capture_fields": sorted(captured)})

    tests = run_process("focused_tests", [sys.executable, "-B", "-m", "unittest", "discover", "-s", "test/up1_external_closure_r2/source_axis_binding", "-p", "test_*.py", "-v"])
    cli_env = dict(os.environ)
    cli_env["PYTHONPATH"] = str(ROOT / "tools" / "up1_external_closure_r2")
    cli_a = run_process("cli_a", [sys.executable, "-B", "-m", "source_axis_binding", "--input", "test/up1_external_closure_r2/source_axis_binding/fixtures/typed_absence.json"], env=cli_env)
    cli_b = run_process("cli_b", [sys.executable, "-B", "-m", "source_axis_binding", "--input", "test/up1_external_closure_r2/source_axis_binding/fixtures/typed_absence.json"], env=cli_env)

    comp = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/04-source-axis-binding"
    receipt = json.loads((comp / "validation_receipt.json").read_text(encoding="utf-8"))
    declared_paths = [receipt["cli_probe"]["stdout_path"], receipt["cli_probe"]["stderr_path"]]
    receipt_paths = [{"declared": p, "exists": (comp / p).is_file(), "actual_root_exists": (comp / Path(p).name).is_file()} for p in declared_paths]

    source_rev = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    tree_rev = subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=ROOT, text=True).strip()
    result = {
        "protocol_id": "UP1-EXTERNAL-BLOCKER-CLOSURE-R2-REVIEW-V1",
        "review_revision": "r1",
        "component": "source_axis_binding",
        "TEST_ONLY": True,
        "non_evidence": True,
        "pid": os.getpid(),
        "parent_pid": os.getppid(),
        "cwd": str(ROOT).replace("\\", "/"),
        "source_revision": source_rev,
        "source_tree": tree_rev,
        "case_count": len(cases),
        "cases": cases,
        "focused_tests": tests,
        "two_process_cli": {"a": cli_a, "b": cli_b, "semantic_equal": cli_a["stdout"]["sha256"] == cli_b["stdout"]["sha256"] and cli_a["stderr"]["sha256"] == cli_b["stderr"]["sha256"], "pids_distinct": cli_a["pid"] != cli_b["pid"]},
        "component_receipt_raw_path_audit": receipt_paths,
        "findings": [c["case_id"] for c in cases if not c["ok"]],
    }
    matrix_path = OUT / "attack_matrix.json"
    matrix_path.write_text(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")), encoding="utf-8")
    reviewed = [
        ROOT / "tools/up1_external_closure_r2/source_axis_binding/source_axis_binding.py",
        ROOT / "tools/up1_external_closure_r2/source_axis_binding/__init__.py",
        ROOT / "tools/up1_external_closure_r2/source_axis_binding/__main__.py",
        ROOT / "test/up1_external_closure_r2/source_axis_binding/test_source_axis_binding.py",
        ROOT / "test/up1_external_closure_r2/source_axis_binding/fixtures/typed_absence.json",
        ROOT / "test/up1_external_closure_r2/source_axis_binding/fixtures/negative_source_hash.json",
        ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/04-source-axis-binding/contract.json",
        ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/04-source-axis-binding/manifest.json",
        ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/04-source-axis-binding/validation_receipt.json",
        ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/04-source-axis-binding/README.md",
        ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/11-source-capture/snapshot.json",
        ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/11-source-capture/source_axis_crosswalk.json",
        ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/00-contract-freeze/interface_contracts.json",
    ]
    artifact_hashes = {}
    for path in reviewed:
        raw = path.read_bytes()
        artifact_hashes[str(path.relative_to(ROOT)).replace("\\", "/")] = {"bytes": len(raw), "sha256": sha(raw), "line_endings": {"crlf": raw.count(b"\\r\\n"), "lf": raw.count(b"\\n"), "trailing_lf": raw.endswith(b"\\n")}}
    manifest = {"schema": "UP1-R2.source-axis-binding.independent-review-manifest.v1", "status": "rework", "TEST_ONLY": True, "non_evidence": True, "claim_ceiling": "review_findings_only; no authority or formal credit", "source_revision": source_rev, "source_tree": tree_rev, "artifact_hashes": artifact_hashes, "review_artifacts": {"attack_matrix.json": {"bytes": matrix_path.stat().st_size, "sha256": sha(matrix_path.read_bytes())}}, "self_hash_exclusions": ["evidence_manifest.json", "run_receipt.json"]}
    (OUT / "evidence_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, sort_keys=True, separators=(",", ":")), encoding="utf-8")
    receipt_out = {"schema": "UP1-R2.source-axis-binding.independent-review-receipt.v1", "status": "rework", "TEST_ONLY": True, "non_evidence": True, "pid": os.getpid(), "parent_pid": os.getppid(), "started_utc": result["focused_tests"]["started_utc"], "ended_utc": result["focused_tests"]["ended_utc"], "source_revision": source_rev, "source_tree": tree_rev, "focused_tests": tests, "two_process_cli": result["two_process_cli"], "attack_matrix": {"path": "attack_matrix.json", "bytes": matrix_path.stat().st_size, "sha256": sha(matrix_path.read_bytes())}, "component_receipt_raw_path_audit": receipt_paths, "finding_count": len(result["findings"]), "findings": result["findings"]}
    (OUT / "run_receipt.json").write_text(json.dumps(receipt_out, ensure_ascii=False, sort_keys=True, separators=(",", ":")), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
