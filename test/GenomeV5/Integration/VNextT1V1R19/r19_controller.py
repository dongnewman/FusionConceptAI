"""Fail-fast, one fresh default-mode Julia per selected original assertion.

Implementation does not authorize execution. --self-test executes no Julia.
Pilot/formal modes require the mainline's post-independent-review decision.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import copy
import hashlib
import json
import os
import subprocess
import sys
import psutil

ROOT = Path(__file__).resolve().parents[4]
OWNER_ROOT = ROOT / "docs/implementation/UP1-04A-VNEXT-T1"
MONITOR = ROOT / "test/GenomeV5/Integration/VNextT1V1R18/run_recorded.py"
HARNESS = ROOT / "test/GenomeV5/Integration/VNextT1V1R19/static_selection_harness.jl"
PREFIX = "R19_CHILD_LEDGER="
TARGETS = [f"r19-{i:03d}" for i in range(1, 64)]

def utc():
    return datetime.now(timezone.utc).isoformat()

def record(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest().upper()}

def sources():
    return {p.relative_to(ROOT).as_posix(): record(p)
            for folder in ("src", "test") for p in (ROOT / folder).rglob("*")
            if p.is_file() and "__pycache__" not in p.parts}

def heavy():
    return [{"pid": p.pid, "name": p.info["name"], "cmdline": p.info["cmdline"]}
            for p in psutil.process_iter(["name", "cmdline"])
            if (p.info["name"] or "").lower() in
            ("julia.exe", "desc.exe", "mesh.exe", "mpiexec.exe")]

def evidence_path(relative):
    if Path(relative).is_absolute() or ".." in Path(relative).parts:
        raise ValueError("evidence path must be relative without traversal")
    path = (ROOT / relative).resolve()
    path.relative_to(OWNER_ROOT.resolve())
    if path == OWNER_ROOT.resolve():
        raise ValueError("broad evidence root forbidden")
    return path

def write_new(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2)

def dispatch_fail_fast(targets, launch):
    for target in targets:
        item = launch(target)
        yield item
        if item["verdict"] != "pass":
            break

def validate_child(final, stdout, target, proof, source_sha):
    if final.get("exit_code") != 0 or final.get("stop_reason") != "natural_exit":
        raise ValueError("child did not naturally exit zero")
    if final.get("source_changes") != [] or final.get("residual_heavy_processes") != []:
        raise ValueError("child source or residual conflict")
    if final.get("peak_working_set_bytes", 2**31) >= 2**31:
        raise ValueError("child working set gate failed")
    lines = [line[len(PREFIX):] for line in stdout.splitlines() if line.startswith(PREFIX)]
    if len(lines) != 1:
        raise ValueError("missing or duplicate runtime ledger")
    ledger = json.loads(lines[0])
    ids = ledger.get("runtime_assertion_ids")
    if not isinstance(ids, list) or not ids or any(item != target for item in ids):
        raise ValueError("zero or foreign runtime assertion IDs")
    if ledger.get("hit_count") != len(ids) or ledger.get("target_id") != target:
        raise ValueError("hit count or target mismatch")
    if ledger.get("selected_expression_hash") != proof["selected_expression_hash"]:
        raise ValueError("selected macro hash mismatch")
    if ledger.get("source_sha256") != source_sha or ledger.get("context_hash") != proof["context_hash"]:
        raise ValueError("source or nonassertion context hash mismatch")
    for field in ("context_ast_equal", "runtime_context_completed", "source_and_protected_unchanged"):
        if ledger.get(field) is not True:
            raise ValueError("missing true runtime condition: " + field)
    if ledger.get("before_protected") != ledger.get("after_protected"):
        raise ValueError("protected source map changed")
    if ledger.get("full_formal_acceptance") is not False:
        raise ValueError("single child cannot award full acceptance")
    if ledger.get("pid") != final.get("pid"):
        raise ValueError("runtime/controller PID mismatch")
    return ledger

def self_test():
    dispatched = []
    def fake_launch(target):
        dispatched.append(target)
        return {"verdict": "fail" if target == "second" else "pass"}
    list(dispatch_fail_fast(["first", "second", "must_not_launch"], fake_launch))
    assert dispatched == ["first", "second"], "dispatch did not stop at first failure"
    proof = {"selected_expression_hash": "EXPR", "context_hash": "CONTEXT"}
    ledger = {"target_id": "r19-001", "runtime_assertion_ids": ["r19-001"] * 7,
              "hit_count": 7, "selected_expression_hash": "EXPR", "context_hash": "CONTEXT",
              "source_sha256": "SOURCE", "context_ast_equal": True,
              "runtime_context_completed": True, "source_and_protected_unchanged": True,
              "before_protected": {"x": 1}, "after_protected": {"x": 1},
              "full_formal_acceptance": False, "pid": 123}
    final = {"exit_code": 0, "stop_reason": "natural_exit", "source_changes": [],
             "residual_heavy_processes": [], "peak_working_set_bytes": 1024, "pid": 123}
    pack = lambda row: PREFIX + json.dumps(row)
    validate_child(final, pack(ledger), "r19-001", proof, "SOURCE")
    rejected = 0
    mutations = [
        ("runtime_assertion_ids", []), ("runtime_assertion_ids", ["r19-002"]),
        ("hit_count", 1), ("selected_expression_hash", "WRONG"),
        ("source_sha256", "WRONG"), ("context_hash", "WRONG"),
        ("context_ast_equal", False), ("runtime_context_completed", False),
        ("source_and_protected_unchanged", False), ("after_protected", {}),
        ("full_formal_acceptance", True), ("pid", 124)]
    for key, value in mutations:
        altered = copy.deepcopy(ledger)
        altered[key] = value
        try:
            validate_child(final, pack(altered), "r19-001", proof, "SOURCE")
        except ValueError:
            rejected += 1
        else:
            raise AssertionError("accepted corrupt ledger: " + key)
    for text in ("", pack(ledger) + "\n" + pack(ledger)):
        try:
            validate_child(final, text, "r19-001", proof, "SOURCE")
        except ValueError:
            rejected += 1
        else:
            raise AssertionError("accepted missing/duplicate ledger")
    for key, value in (("exit_code", 1), ("stop_reason", "wall_timeout"),
                       ("source_changes", ["x"]), ("residual_heavy_processes", [{"pid": 9}]),
                       ("peak_working_set_bytes", 2**31)):
        altered = copy.deepcopy(final)
        altered[key] = value
        try:
            validate_child(altered, pack(ledger), "r19-001", proof, "SOURCE")
        except ValueError:
            rejected += 1
        else:
            raise AssertionError("accepted bad process receipt: " + key)
    print(json.dumps({"self_test": "pass", "legal_repeated_hits": 7,
                      "rejected_invalid_receipts": rejected, "fail_fast_dispatch": True,
                      "product_execution": False}))

def execute(args):
    static_path = evidence_path(args.static_manifest)
    static = json.loads(static_path.read_text(encoding="utf-8"))
    if static.get("verdict") != "static_only" or static.get("product_execution") is not False:
        raise ValueError("not an R19 preexecution static receipt")
    rows = static["static_targets"]
    proofs = {row["target_id"]: row for row in static["proofs"]}
    if [row["id"] for row in rows] != TARGETS or sorted(proofs) != TARGETS:
        raise ValueError("zero/duplicate/unknown/missing targets in static manifest")
    for row in rows:
        proof = proofs[row["id"]]
        if proof["selected_count"] != 1 or proof["selected_expression_hash"] != row["expression_hash"] or proof["context_ast_equal"] is not True:
            raise ValueError("static AST proof mismatch")
    for rel, expected in static["before_protected"].items():
        if record(ROOT / rel) != expected:
            raise ValueError("source/helper/product/harness changed after static proof: " + rel)
    if args.mode == "pilot":
        if args.target not in TARGETS:
            raise ValueError("pilot requires one known target")
        targets = [args.target]
    else:
        if args.target is not None:
            raise ValueError("formal mode cannot narrow target set")
        targets = TARGETS
    if heavy() or (ROOT / "tmp/runtime.lock").exists():
        raise RuntimeError("serial lane occupied")
    out = evidence_path(args.out)
    out.mkdir(parents=True, exist_ok=False)
    (out / "children").mkdir()
    before = sources()
    started = utc()
    results, failure = [], None
    reservation = ROOT / "tmp/r19_queue.lock"
    reservation.parent.mkdir(exist_ok=True)
    with reservation.open("x", encoding="utf-8") as stream:
        json.dump({"owner": "t1_astra_xhigh_closeout", "controller_pid": os.getpid(), "utc": utc()}, stream)
    try:
        write_new(out / "preflight.json", {"mode": args.mode, "started_utc": started,
            "controller_pid": os.getpid(), "command": sys.argv, "static_manifest": str(static_path),
            "static_manifest_hash": record(static_path), "targets": targets, "inputs_before": before,
            "julia": args.julia, "julia_mode": "default", "working_set_limit": 2**31,
            "child_wall_timeout": args.timeout, "fail_fast": True, "actual_model_attestation": "unavailable"})
        def launch(target):
            nonlocal failure
            child = out / "children" / target
            command = [sys.executable, "-B", str(MONITOR), "--out", child.relative_to(ROOT).as_posix(),
                       "--timeout", str(args.timeout), "--", args.julia, "--startup-file=no",
                       "--history-file=no", "--project=.", str(HARNESS), "--child", target]
            completed = subprocess.run(command, cwd=ROOT, capture_output=True,
                                       creationflags=subprocess.CREATE_NO_WINDOW)
            # Controller streams are generated evidence, not source modifications.
            (child / "monitor.stdout.raw").write_bytes(completed.stdout)
            (child / "monitor.stderr.raw").write_bytes(completed.stderr)
            item = {"target_id": target, "monitor_exit_code": completed.returncode,
                    "monitor_command": command}
            try:
                if completed.returncode != 0:
                    raise ValueError("monitor nonzero; inspect retained final/raw files")
                final = json.loads((child / "final.json").read_text(encoding="utf-8"))
                stdout = (child / "stdout.raw").read_text(encoding="utf-8")
                item["runtime"] = validate_child(final, stdout, target, proofs[target], static["source_sha256"])
                item["process"] = final
                item["verdict"] = "pass"
            except Exception as err:
                item["verdict"] = "fail"
                item["reason"] = str(err)
                failure = {"target_id": target, "reason": str(err)}
            return item
        for item in dispatch_fail_fast(targets, launch):
            target = item["target_id"]
            results.append(item)
            write_new(out / ("progress_" + target + ".json"), item)
            print(json.dumps({"target": target, "verdict": item["verdict"], "completed": len(results)}), flush=True)
        after = sources()
        changes = sorted(key for key in set(before) | set(after) if before.get(key) != after.get(key))
        residual = heavy()
        runtime_lock_present = (ROOT / "tmp/runtime.lock").exists()
        complete = failure is None and len(results) == len(targets) and not changes and not residual and not runtime_lock_present
        formal_pass = args.mode == "formal" and complete and targets == TARGETS
        write_new(out / "aggregate.json", {"mode": args.mode, "started_utc": started, "ended_utc": utc(),
            "verdict": "pass" if complete else "incomplete_or_failed", "formal_regression_pass": formal_pass,
            "formal_T1_acceptance": False, "first_failure": failure, "results": results,
            "ordered_unrun_target_ids": targets[len(results):], "source_changes": changes,
            "inputs_after": after, "residual_heavy_processes": residual,
            "runtime_lock_present": runtime_lock_present,
            "actual_model_attestation": "unavailable"})
        return 0 if complete else 1
    finally:
        owner = json.loads(reservation.read_text(encoding="utf-8"))
        if owner.get("controller_pid") != os.getpid():
            raise RuntimeError("queue reservation owner changed; not removing it")
        reservation.unlink()
        write_new(out / "queue_release.json", {"utc": utc(), "reservation_removed": True,
            "runtime_lock_present": (ROOT / "tmp/runtime.lock").exists(), "residual_heavy_processes": heavy()})

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--mode", choices=("pilot", "formal"))
    parser.add_argument("--target")
    parser.add_argument("--out")
    parser.add_argument("--static-manifest")
    parser.add_argument("--julia")
    parser.add_argument("--timeout", type=float, default=1800)
    args = parser.parse_args()
    if args.self_test:
        self_test()
    elif all((args.mode, args.out, args.static_manifest, args.julia)):
        raise SystemExit(execute(args))
    else:
        parser.error("use --self-test, or explicit mode/out/static-manifest/julia after authorization")
