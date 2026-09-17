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


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def utc() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def rebuild(value: dict) -> None:
    identity = value["source_identity"]
    identity["source_identity_digest"] = source_identity_digest(identity)
    for material in value["axis_materials"]:
        material["source_identity_digest"] = identity["source_identity_digest"]
        material["digest"] = material_digest(material)
        edge = {key: material[key] for key in ("axis", "candidate_id", "namespace", "version", "issuer", "issued_at")}
        edge.update(source_identity_digest=identity["source_identity_digest"], material_digest=material["digest"])
        material["source_edge"] = copy.deepcopy(edge)
        material["candidate_edge"] = copy.deepcopy(edge)
    identity["axis_edges"] = {m["axis"]: copy.deepcopy(m["source_edge"]) for m in value["axis_materials"]}
    value["candidate_axis_edges"] = {m["axis"]: copy.deepcopy(m["candidate_edge"]) for m in value["axis_materials"]}


def case(case_id: str, value: dict, expected: str, *, authority: bool | None = None) -> dict:
    result = validate_bundle(value, value.get("source_identity"))
    observed = "accept" if result.get("valid") else "reject"
    row = {"case_id": case_id, "expected": expected, "observed": observed, "ok": observed == expected,
           "status": result.get("status"), "authority_evidence": result.get("authority_evidence"),
           "errors": [x.get("code") for x in result.get("errors", [])]}
    if authority is not None:
        row["authority_ok"] = result.get("authority_evidence") is authority
        row["ok"] = row["ok"] and row["authority_ok"]
    return row


def run_process(name: str, argv: list[str], *, env: dict[str, str] | None = None) -> dict:
    start = utc()
    proc = subprocess.Popen(argv, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    end = utc()
    op = RAW / f"{name}.stdout.raw"; ep = RAW / f"{name}.stderr.raw"
    op.write_bytes(stdout); ep.write_bytes(stderr)
    return {"argv": argv, "pid": proc.pid, "started_utc": start, "ended_utc": end, "exit_code": proc.returncode,
            "stdout": {"path": str(op.relative_to(OUT)).replace("\\", "/"), "bytes": len(stdout), "sha256": digest(stdout)},
            "stderr": {"path": str(ep.relative_to(OUT)).replace("\\", "/"), "bytes": len(stderr), "sha256": digest(stderr)}}


def main() -> int:
    RAW.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []

    value = fixture(); value["state"] = "EXTERNAL_ISSUED"; value["provenance_class"] = "external_issued"
    for material in value["axis_materials"]: material["issuer"] = "issuer-only"
    rebuild(value)
    rows.append(case("ISSUER-ONLY-NO-AUTHORITY", value, "reject", authority=False))

    value = fixture(); value["state"] = "EXTERNAL_ISSUED"; value["provenance_class"] = "external_issued"
    value["authority"] = {key: True for key in ("signature_validated", "trust_root_validated", "trusted_time_validated", "revocation_validated", "g2_mapping_validated")}
    for material in value["axis_materials"]: material["issuer"] = "independent-issuer"; material["signature"] = "verified-reference"
    rebuild(value)
    rows.append(case("ALL-AUTHORITY-PREREQUISITES", value, "accept", authority=True))

    value = fixture(); material = value["axis_materials"][0]; material["source_identity_digest"] = "f" * 64; material["digest"] = material_digest(material)
    edge = {key: material[key] for key in ("axis", "candidate_id", "namespace", "version", "issuer", "issued_at")}; edge.update(source_identity_digest=value["source_identity"]["source_identity_digest"], material_digest=material["digest"])
    material["source_edge"] = copy.deepcopy(edge); material["candidate_edge"] = copy.deepcopy(edge); value["source_identity"]["axis_edges"][material["axis"]] = copy.deepcopy(edge); value["candidate_axis_edges"][material["axis"]] = copy.deepcopy(edge)
    rows.append(case("FOREIGN-MATERIAL-SOURCE-DIGEST", value, "reject"))

    value = fixture(); value["unknown_field"] = True; value["source_identity"]["unknown_field"] = True; value["axis_materials"][0]["unknown_field"] = True; value["candidate_axis_edges"]["extra"] = []
    rows.append(case("TOP-LEVEL-UNKNOWN-FIELDS", value, "reject"))
    for case_id, mutator in {
        "NESTED-SUBMODULE-UNKNOWN": lambda v: v["source_identity"]["submodule_closure"].update({"evil": True}),
        "NESTED-PAYLOAD-UNKNOWN": lambda v: v["axis_materials"][0]["payload"].update({"evil": True}),
        "NESTED-AD56-UNKNOWN": lambda v: v["ad56"].update({"evil": True}),
        "NESTED-EDGE-UNKNOWN": lambda v: v["candidate_axis_edges"]["payload_schema_version"].update({"evil": True}),
    }.items():
        value = fixture()
        if case_id == "NESTED-EDGE-UNKNOWN":
            rebuild(value); mutator(value)
        else:
            mutator(value); rebuild(value)
        rows.append(case(case_id, value, "reject"))

    value = fixture(); value["axis_materials"].append("scalar-extra"); rows.append(case("SCALAR-MATERIAL", value, "reject"))
    value = fixture(); value["candidate_axis_edges"]["extra"] = []; rows.append(case("SCALAR-EDGE", value, "reject"))
    value = fixture(); value["source_identity"]["identity_schema_version"] = "evil-schema"; rebuild(value); rows.append(case("IDENTITY-SCHEMA-VERSION-UNKNOWN", value, "reject"))
    value = fixture(); value["state"] = "EVIL_STATE"; rows.append(case("UNKNOWN-STATE", value, "reject", authority=False))
    value = fixture(); value["provenance_class"] = "EVIL_PROVENANCE"; rows.append(case("UNKNOWN-PROVENANCE", value, "reject", authority=False))

    value = fixture(); value["state"] = "EXTERNAL_ISSUED"; value["provenance_class"] = "external_issued"; value["authority"] = {key: True for key in ("signature_validated", "trust_root_validated", "trusted_time_validated", "revocation_validated", "g2_mapping_validated")}; value["ad56"]["authority_evidence"] = True
    for material in value["axis_materials"]: material["issuer"] = "issuer"; material["signature"] = "signature"
    rebuild(value); rows.append(case("AD56-CANNOT-ESCALATE", value, "reject", authority=False))

    value = fixture(); value["axis_materials"][0]["candidate_id"] = "foreign-a"; value["axis_materials"][1]["candidate_id"] = "foreign-b"
    first = validate_bundle(value, value["source_identity"]); reverse = copy.deepcopy(value); reverse["axis_materials"] = list(reversed(reverse["axis_materials"])); second = validate_bundle(reverse, reverse["source_identity"])
    rows.append({"case_id": "ERROR-ORDER-PERMUTATION", "expected": "permutation-invariant", "observed": "permutation-invariant" if first == second else "order-sensitive", "ok": first == second, "first_error_paths": [x.get("path") for x in first["errors"]], "second_error_paths": [x.get("path") for x in second["errors"]]})

    captured = capture_source_identity(ROOT)
    rows.append({"case_id": "HEAD-TREE-UNTRACKED-CONTENT", "expected": "bound", "observed": "bound" if "head_tree" in captured and isinstance(captured.get("untracked_files"), list) and isinstance(captured.get("untracked_content_digest"), str) else "missing", "ok": "head_tree" in captured and isinstance(captured.get("untracked_files"), list) and isinstance(captured.get("untracked_content_digest"), str), "capture_fields": sorted(captured)})
    observed_base = fixture(); stale = copy.deepcopy(observed_base["source_identity"]); stale["patch_digest"] = "f" * 64; stale["source_identity_digest"] = source_identity_digest(stale); drift = validate_bundle(observed_base, stale); rows.append({"case_id": "FRESH-OBSERVED-DRIFT", "expected": "reject", "observed": "reject" if not drift["valid"] else "accept", "ok": not drift["valid"], "errors": [x["code"] for x in drift["errors"]]})
    missing = validate_bundle(fixture()); rows.append({"case_id": "MISSING-FRESH-OBSERVED", "expected": "reject", "observed": "reject" if not missing["valid"] else "accept", "ok": not missing["valid"], "errors": [x["code"] for x in missing["errors"]]})
    absent = __import__("json").loads((ROOT / "test/up1_external_closure_r2/source_axis_binding/fixtures/typed_absence.json").read_text(encoding="utf-8")); absent_result = validate_bundle(absent, absent["source_identity"]); rows.append({"case_id": "TYPED-ABSENCE-AUTHORITY-FALSE", "expected": "accept", "observed": "accept" if absent_result["valid"] else "reject", "ok": absent_result["valid"] and absent_result["authority_evidence"] is False, "status": absent_result["status"], "authority_evidence": absent_result["authority_evidence"]})

    env = dict(os.environ); env["PYTHONPATH"] = str(ROOT / "tools" / "up1_external_closure_r2")
    raw = json.dumps(fixture(), ensure_ascii=False, sort_keys=True, separators=(",", ":")).replace('"candidate_id":"candidate-up1-r2-test-001"', '"candidate_id":"duplicate",' + '"candidate_id":"candidate-up1-r2-test-001"', 1)
    start = utc(); duplicate = subprocess.run([sys.executable, "-B", "-m", "source_axis_binding"], cwd=ROOT, env=env, input=raw.encode(), capture_output=True); end = utc(); (RAW / "duplicate_json.stdout.raw").write_bytes(duplicate.stdout); (RAW / "duplicate_json.stderr.raw").write_bytes(duplicate.stderr)
    rows.append({"case_id": "DUPLICATE-JSON-KEY", "expected": "reject", "observed": "reject" if duplicate.returncode else "accept", "ok": duplicate.returncode != 0, "exit_code": duplicate.returncode, "started_utc": start, "ended_utc": end, "parsed_status": json.loads(duplicate.stdout.decode()).get("status") if duplicate.stdout else None})

    tests = run_process("focused_tests", [sys.executable, "-B", "-m", "unittest", "discover", "-s", "test/up1_external_closure_r2/source_axis_binding", "-p", "test_*.py", "-v"])
    compile_run = run_process("compile", [sys.executable, "-B", "-m", "py_compile", "tools/up1_external_closure_r2/source_axis_binding/source_axis_binding.py", "test/up1_external_closure_r2/source_axis_binding/test_source_axis_binding.py"])
    cli_args = [sys.executable, "-B", "-m", "source_axis_binding", "--input", "test/up1_external_closure_r2/source_axis_binding/fixtures/typed_absence.json", "--observed-source", "test/up1_external_closure_r2/source_axis_binding/fixtures/observed_source.json"]
    cli_a = run_process("cli_a", cli_args, env=env); cli_b = run_process("cli_b", cli_args, env=env)
    component = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/04-source-axis-binding"; component_receipt = json.loads((component / "validation_receipt.json").read_text(encoding="utf-8")); component_raw = []
    for key in ("stdout_path", "stderr_path"):
        item = component_receipt["cli_probe"]; path = component / item[key]; component_raw.append({"declared": item[key], "exists": path.is_file(), "hash_match": path.is_file() and digest(path.read_bytes()) == item[key.replace("_path", "_sha256")]})
    source_revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(); source_tree = subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=ROOT, text=True).strip()
    result = {"schema": "UP1-R2.source-axis-binding.independent-attack-matrix.v3", "status": "pass_limited" if all(x["ok"] for x in rows) else "rework", "TEST_ONLY": True, "non_evidence": True, "pid": os.getpid(), "parent_pid": os.getppid(), "source_revision": source_revision, "source_tree": source_tree, "case_count": len(rows), "cases": rows, "findings": [x["case_id"] for x in rows if not x["ok"]], "focused_tests": tests, "compile": compile_run, "two_process_cli": {"a": cli_a, "b": cli_b, "semantic_equal": cli_a["stdout"]["sha256"] == cli_b["stdout"]["sha256"] and cli_a["stderr"]["sha256"] == cli_b["stderr"]["sha256"], "pids_distinct": cli_a["pid"] != cli_b["pid"]}, "component_raw": component_raw}
    matrix_path = OUT / "attack_matrix.json"; matrix_path.write_text(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")), encoding="utf-8")
    reviewed = [ROOT / p for p in ["tools/up1_external_closure_r2/source_axis_binding/source_axis_binding.py", "tools/up1_external_closure_r2/source_axis_binding/__init__.py", "tools/up1_external_closure_r2/source_axis_binding/__main__.py", "test/up1_external_closure_r2/source_axis_binding/test_source_axis_binding.py", "test/up1_external_closure_r2/source_axis_binding/fixtures/typed_absence.json", "test/up1_external_closure_r2/source_axis_binding/fixtures/negative_source_hash.json", "test/up1_external_closure_r2/source_axis_binding/fixtures/observed_source.json", "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/04-source-axis-binding/contract.json", "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/04-source-axis-binding/manifest.json", "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/04-source-axis-binding/validation_receipt.json", "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/04-source-axis-binding/README.md", "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/11-source-capture/snapshot.json", "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/11-source-capture/source_axis_crosswalk.json", "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/00-contract-freeze/interface_contracts.json"]]
    artifacts = {}
    for path in reviewed:
        data = path.read_bytes(); artifacts[str(path.relative_to(ROOT)).replace("\\", "/")] = {"bytes": len(data), "sha256": digest(data), "crlf": data.count(b"\\r\\n"), "lf": data.count(b"\\n"), "trailing_lf": data.endswith(b"\\n")}
    (OUT / "evidence_manifest.json").write_text(json.dumps({"schema": "UP1-R2.source-axis-binding.independent-review-manifest.v3", "status": result["status"], "TEST_ONLY": True, "non_evidence": True, "claim_ceiling": "review_findings_only; no authority or formal credit", "source_revision": source_revision, "source_tree": source_tree, "artifact_hashes": artifacts, "self_hash_exclusions": ["evidence_manifest.json", "run_receipt.json"]}, ensure_ascii=False, sort_keys=True, separators=(",", ":")), encoding="utf-8")
    (OUT / "run_receipt.json").write_text(json.dumps({"schema": "UP1-R2.source-axis-binding.independent-review-receipt.v3", "status": result["status"], "TEST_ONLY": True, "non_evidence": True, "pid": os.getpid(), "parent_pid": os.getppid(), "source_revision": source_revision, "source_tree": source_tree, "focused_tests": tests, "compile": compile_run, "two_process_cli": result["two_process_cli"], "component_raw": component_raw, "attack_matrix": {"path": "attack_matrix.json", "bytes": matrix_path.stat().st_size, "sha256": digest(matrix_path.read_bytes())}, "findings": result["findings"]}, ensure_ascii=False, sort_keys=True, separators=(",", ":")), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
