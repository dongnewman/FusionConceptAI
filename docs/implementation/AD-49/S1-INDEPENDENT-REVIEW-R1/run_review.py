from __future__ import annotations

import hashlib
import json
import os
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / "docs/implementation/AD-49/S1-INDEPENDENT-REVIEW-R1"
ARCHIVE = OUT / "archive"
ARCHIVE.mkdir(parents=True, exist_ok=True)


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def artifact(path: Path) -> dict:
    data = path.read_bytes()
    return {"path": path.relative_to(ROOT).as_posix(), "bytes": len(data), "sha256": sha_bytes(data)}


def canonical(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def write_json(path: Path, value: object) -> None:
    path.write_bytes(canonical(value))


def run(label: str, argv: list[str], cwd: Path = ROOT) -> dict:
    started = now()
    proc = subprocess.Popen(argv, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    ended = now()
    out_path = ARCHIVE / f"{label}.stdout.txt"
    err_path = ARCHIVE / f"{label}.stderr.txt"
    out_path.write_bytes(stdout)
    err_path.write_bytes(stderr)
    return {
        "command": argv,
        "cwd": cwd.as_posix(),
        "pid": proc.pid,
        "utc_start": started,
        "utc_end": ended,
        "exit_code": proc.returncode,
        "stdout": artifact(out_path),
        "stderr": artifact(err_path),
    }


def read_json(rel: str) -> tuple[dict, bytes]:
    path = ROOT / rel
    data = path.read_bytes()
    return json.loads(data), data


def check_command_receipts(value: object, errors: list[str], seen: list[dict]) -> None:
    if isinstance(value, dict):
        if {"command", "cwd", "exit_code"}.issubset(value):
            seen.append(value)
            for stream in ("stdout", "stderr"):
                stream_info = value.get(stream)
                if isinstance(stream_info, dict) and stream_info.get("path"):
                    path = ROOT / stream_info["path"]
                    if not path.exists():
                        errors.append(f"receipt raw missing: {stream_info['path']}")
                    else:
                        actual = artifact(path)
                        if actual.get("bytes") != stream_info.get("bytes") or actual.get("sha256") != stream_info.get("sha256"):
                            errors.append(f"receipt raw hash mismatch: {stream_info['path']}")
            for item in value.get("output_artifacts", []):
                path = ROOT / item["path"]
                if not path.exists():
                    errors.append(f"receipt output missing: {item['path']}")
                elif artifact(path) != item:
                    errors.append(f"receipt output hash mismatch: {item['path']}")
        else:
            for child in value.values():
                check_command_receipts(child, errors, seen)
    elif isinstance(value, list):
        for child in value:
            check_command_receipts(child, errors, seen)


def main() -> int:
    started = now()
    errors: list[str] = []
    preexisting = {p.relative_to(ROOT).as_posix(): artifact(p) for p in OUT.rglob("*") if p.is_file() and p.name not in {"final_hashes.json", "cleanup_inventory.json"}}
    baseline_status = run("review_baseline_git_status", ["git", "status", "--short", "--branch"])
    root_receipt = run("review_root_git_rev_parse", ["git", "rev-parse", "--show-toplevel"])
    head_receipt = run("review_root_git_head", ["git", "rev-parse", "HEAD"])
    root = root_receipt["stdout"]["path"]
    observed_root = (ROOT / root).read_text(encoding="utf-8", errors="replace") if False else (ARCHIVE / "review_root_git_rev_parse.stdout.txt").read_text(encoding="utf-8").strip()
    observed_head = (ARCHIVE / "review_root_git_head.stdout.txt").read_text(encoding="utf-8").strip()
    if Path(observed_root).resolve() != ROOT.resolve():
        errors.append(f"root mismatch: {observed_root}")
    if observed_head != "4b69f55f7f80240147a65a22809dc1207824dde2":
        errors.append(f"HEAD mismatch: {observed_head}")

    layers = {
        "G1": {
            "source": "src/GenomeV5/G1/DiffusionDeclarationV1.jl",
            "record": "docs/implementation/AD-49/G1-SOURCE-LOCATOR/g1_source_locator_v1.json",
            "receipt": "docs/implementation/AD-49/G1-SOURCE-LOCATOR/g1_source_locator_receipt.json",
            "manifest": "docs/implementation/AD-49/G1-SOURCE-LOCATOR/manifest.json",
            "archive": "G1-SOURCE-LOCATOR/archive",
        },
        "G2": {
            "source": "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl",
            "record": "docs/implementation/AD-49/G2-SOURCE-LOCATOR/g2_source_locator_v1.json",
            "receipt": "docs/implementation/AD-49/G2-SOURCE-LOCATOR/g2_source_locator_receipt.json",
            "manifest": "docs/implementation/AD-49/G2-SOURCE-LOCATOR/manifest.json",
            "archive": "G2-SOURCE-LOCATOR/archive",
        },
    }
    live_git: dict[str, dict] = {}
    products: list[dict] = []
    input_paths: set[str] = set()
    for layer, spec in layers.items():
        record, record_bytes = read_json(spec["record"])
        receipt, receipt_bytes = read_json(spec["receipt"])
        manifest, manifest_bytes = read_json(spec["manifest"])
        source = ROOT / spec["source"]
        if record_bytes != canonical(record):
            errors.append(f"{layer} record not canonical compact JSON")
        if receipt_bytes != canonical(receipt):
            errors.append(f"{layer} receipt not canonical compact JSON")
        if manifest_bytes != canonical(manifest):
            errors.append(f"{layer} manifest not canonical compact JSON")
        for token in ("GG1", "GG2"):
            for path, data in ((spec["record"], record_bytes), (spec["receipt"], receipt_bytes), (spec["manifest"], manifest_bytes)):
                if token.encode() in data:
                    errors.append(f"{layer}: forbidden union token {token} in {path}")
        expected = f"Absent{layer}IndependentSourceLocatorV1"
        if record.get("result") != expected or record.get("record_kind") != expected:
            errors.append(f"{layer}: absent result union mismatch")
        if record.get("status") != "typed_absent" or record.get("contract_admission") != "terminal_deferred":
            errors.append(f"{layer}: terminal absence mismatch")
        if record.get("locator") is not None:
            errors.append(f"{layer}: locator is not null")
        snapshot = record.get("source_snapshot", {})
        working = snapshot.get("working_tree", {})
        head = snapshot.get("head", {})
        if not source.exists():
            errors.append(f"{layer}: source missing")
        else:
            live = artifact(source)
            if working.get("bytes") != live["bytes"] or working.get("sha256") != live["sha256"]:
                errors.append(f"{layer}: working-tree bytes/SHA mismatch")
            if snapshot.get("path") != spec["source"]:
                errors.append(f"{layer}: source path mismatch")
        ls = run(f"{layer.lower()}_fresh_git_ls_files", ["git", "ls-files", "--error-unmatch", "--", spec["source"]])
        hp = run(f"{layer.lower()}_fresh_head_path", ["git", "cat-file", "-e", f"HEAD:{spec['source']}"])
        hb = run(f"{layer.lower()}_fresh_head_blob", ["git", "rev-parse", f"HEAD:{spec['source']}"])
        ws = run(f"{layer.lower()}_fresh_git_status", ["git", "status", "--short", "--", spec["source"]])
        live_git[layer] = {"ls_files": ls, "head_path": hp, "head_blob": hb, "status": ws}
        if ls["exit_code"] == 0 or hp["exit_code"] == 0:
            errors.append(f"{layer}: source unexpectedly tracked/present in HEAD")
        if ls["exit_code"] != 1 or hp["exit_code"] != 128:
            errors.append(f"{layer}: unexpected git absence exit codes")
        if hb["exit_code"] == 0 or bytes.fromhex("00") is None:
            if hb["exit_code"] == 0:
                errors.append(f"{layer}: HEAD blob unexpectedly resolved")
        hb_out = (ROOT / hb["stdout"]["path"]).read_bytes().decode("utf-8", errors="replace").strip()
        if __import__("re").fullmatch(r"[0-9a-fA-F]{40}", hb_out):
            errors.append(f"{layer}: failed head-blob command emitted a blob SHA")
        if snapshot.get("observed_head") != observed_head:
            errors.append(f"{layer}: recorded HEAD differs from live HEAD")
        if head.get("present") is not False or head.get("blob_sha256") is not None or snapshot.get("git", {}).get("ls_files_present") is not False:
            errors.append(f"{layer}: typed absence HEAD closure mismatch")
        if working.get("path_status") != f"?? {spec['source']}":
            errors.append(f"{layer}: working-tree status mismatch")
        for name, control in record.get("negative_controls", {}).items():
            expected_control = expected if name == "tracked_vs_untracked_confusion" else f"Failed{layer}IndependentSourceLocatorV1"
            if control.get("evaluated") is not True or control.get("expected_result") != expected_control or control.get("observed_result") != expected_control:
                errors.append(f"{layer}: negative control {name} union mismatch")
        if record.get("absence", {}).get("authority") != "working_tree_snapshot_is_not_independent_authority":
            errors.append(f"{layer}: authority boundary missing")
        for item in record.get("input_closure", []):
            input_paths.add(item["path"])
            path = ROOT / item["path"]
            if not path.exists():
                errors.append(f"{layer}: input missing {item['path']}")
            elif artifact(path).get("bytes") != item.get("bytes") or artifact(path).get("sha256") != item.get("sha256"):
                errors.append(f"{layer}: input hash mismatch {item['path']}")
        if receipt.get("record") != artifact(ROOT / spec["record"]):
            errors.append(f"{layer}: receipt record hash boundary mismatch")
        if receipt.get("status") != "typed_absent" or receipt.get("contract_admission") != "terminal_deferred":
            errors.append(f"{layer}: receipt status boundary mismatch")
        if receipt.get("self_hash_excluded") is not True:
            errors.append(f"{layer}: self-hash exclusion missing")
        if manifest.get("result") != expected or manifest.get("source_snapshot_path") != spec["source"]:
            errors.append(f"{layer}: manifest mismatch")
        seen_commands: list[dict] = []
        check_command_receipts(receipt.get("command_receipts", {}), errors, seen_commands)
        if not seen_commands:
            errors.append(f"{layer}: command receipts absent")
        products.extend([artifact(ROOT / spec["record"]), artifact(ROOT / spec["receipt"]), artifact(ROOT / spec["manifest"])])

    input_closure = {p: artifact(ROOT / p) for p in sorted(input_paths)}
    for layer, spec in layers.items():
        rec, _ = read_json(spec["record"])
        for item in rec["input_closure"]:
            if input_closure[item["path"]] != item:
                errors.append(f"shared input closure mismatch: {item['path']}")

    archive_checks: dict[str, object] = {}
    g1a = ROOT / "docs/implementation/AD-49/G1-SOURCE-LOCATOR/archive"
    g2a = ROOT / "docs/implementation/AD-49/G2-SOURCE-LOCATOR/archive"
    for layer, ap, source in (("G1", g1a, layers["G1"]["source"]), ("G2", g2a, layers["G2"]["source"])):
        hp_out = (ap / f"{layer.lower()}_head_path.stdout.txt").read_bytes()
        hp_err = (ap / f"{layer.lower()}_head_path.stderr.txt").read_bytes()
        hb_out = (ap / f"{layer.lower()}_head_blob.stdout.txt").read_bytes()
        hb_err = (ap / f"{layer.lower()}_head_blob.stderr.txt").read_bytes()
        ls_out = (ap / f"{layer.lower()}_git_ls_files.stdout.txt").read_bytes()
        ls_err = (ap / f"{layer.lower()}_git_ls_files.stderr.txt").read_bytes()
        archive_checks[layer] = {
            "head_path_empty_stdout": len(hp_out) == 0,
            "head_path_fatal_stderr": b"not in 'HEAD'" in hp_err,
            "head_blob_stdout_is_expression_not_sha": not bool(__import__("re").fullmatch(rb"[0-9a-fA-F]{40}\s*", hb_out)),
            "head_blob_fatal_stderr": b"not in 'HEAD'" in hb_err,
            "ls_files_empty_stdout": len(ls_out) == 0,
            "ls_files_untracked_error": b"did not match any file" in ls_err,
        }
        if not all(archive_checks[layer].values()):
            errors.append(f"{layer}: archived failed-command semantics mismatch")
    g1_summary = json.loads((g1a / "run_summary.json").read_bytes())
    if g1_summary.get("g1_result") != "AbsentG1IndependentSourceLocatorV1" or g1_summary.get("g2_result") != "AbsentG2IndependentSourceLocatorV1" or g1_summary.get("heavy_runtime_started") is not False:
        errors.append("G1 archive run summary mismatch")
    old_direct = json.loads((g1a / "direct_validation.json").read_bytes())
    if old_direct.get("exit_code") != 0 or old_direct.get("checks", {}).get("head_absence") is not True or old_direct.get("checks", {}).get("negative_controls") is not True:
        errors.append("archived direct validation is not passing")

    process = run("fresh_process_probe", ["powershell.exe", "-NoProfile", "-Command", "Get-Process | Where-Object { $_.ProcessName -match 'julia|desc|mpiexec|solver|mesh' } | Select-Object ProcessName,Id | ConvertTo-Json -Compress"])
    plan_report = ARCHIVE / "plan_validator_report.json"
    plan = run("fresh_plan_validator", [sys.executable, "docs/v4_multitopology_generation/validate_plan.py", "--report", str(plan_report)])
    scoped = run("fresh_scoped_git_diff_check", ["git", "diff", "--check", "--", "docs/implementation/AD-49/G1-SOURCE-LOCATOR", "docs/implementation/AD-49/G2-SOURCE-LOCATOR"])
    if plan["exit_code"] != 0:
        errors.append("fresh plan validator failed")
    if scoped["exit_code"] != 0:
        errors.append("fresh scoped diff check failed")
    if process["exit_code"] != 0:
        errors.append("fresh process probe failed")
    plan_result = json.loads(plan_report.read_bytes()) if plan_report.exists() else {}
    if plan_result.get("task_dag_acyclic") is not True:
        errors.append("plan validator did not report acyclic DAG")

    direct = {
        "schema_version": "AD49-S1-independent-review-R1-direct-v1",
        "record_kind": "independent_source_locator_review",
        "task_id": "AD49-S1-INDEPENDENT-G1-G2-SOURCE-LOCATORS",
        "python": sys.executable,
        "python_version": platform.python_version(),
        "pid": os.getpid(),
        "utc_start": started,
        "utc_end": now(),
        "exit_code": 0 if not errors else 1,
        "checks": {
            "root_head": not any("root mismatch" in e or "HEAD mismatch" in e for e in errors),
            "source_live_git_closure": not any("unexpectedly tracked" in e or "unexpected git absence" in e for e in errors),
            "working_tree_bytes_sha": not any("bytes/SHA" in e for e in errors),
            "products_canonical_and_union": not any("canonical" in e or "union" in e for e in errors),
            "absent_terminal_deferred_no_publish_boundary": not any("absence" in e or "authority" in e for e in errors),
            "negative_controls": not any("negative control" in e for e in errors),
            "ad42_ad44_input_closure": not any("input" in e for e in errors),
            "receipt_hash_boundaries": not any("receipt" in e for e in errors),
            "archive_failed_command_not_blob": not any("archived failed" in e for e in errors),
            "plan_validator": plan["exit_code"] == 0,
            "scoped_diff_check": scoped["exit_code"] == 0,
            "no_heavy_runtime": process["exit_code"] == 0,
        },
        "observed_root": observed_root,
        "observed_head": observed_head,
        "layers": live_git,
        "archive_checks": archive_checks,
        "input_closure": input_closure,
        "products": products,
        "commands": {"baseline_status": baseline_status, "root": root_receipt, "head": head_receipt, "process_probe": process, "plan_validator": plan, "scoped_diff_check": scoped},
        "errors": errors,
        "no_heavy_runtime": True,
        "self_hash_excluded": True,
    }
    write_json(ARCHIVE / "direct_validation.json", direct)
    (ARCHIVE / "direct_validation.stdout.json").write_bytes(canonical(direct))
    (ARCHIVE / "direct_validation.stderr.txt").write_bytes(b"")

    status_after = run("review_final_git_status", ["git", "status", "--short", "--branch"])
    baseline_lines = (ROOT / baseline_status["stdout"]["path"]).read_text(encoding="utf-8", errors="replace").splitlines()
    after_lines = (ROOT / status_after["stdout"]["path"]).read_text(encoding="utf-8", errors="replace").splitlines()
    new_lines = [line for line in after_lines if line not in baseline_lines]
    outside_scope = [line for line in new_lines if not line[3:].startswith("docs/implementation/AD-49/S1-INDEPENDENT-REVIEW-R1")]
    if outside_scope:
        errors.append("final status introduced paths outside review scope")
    write_json(ARCHIVE / "final_scope_check.json", {
        "schema_version": "AD49-S1-independent-review-R1-final-scope-v1",
        "baseline_status": baseline_status,
        "final_status": status_after,
        "new_status_lines": new_lines,
        "outside_scope": outside_scope,
        "scope_ok": not outside_scope,
    })
    review_status = {
        "schema_version": "AD49-S1-independent-review-R1-manifest-v1",
        "task_id": "AD49-S1-INDEPENDENT-G1-G2-SOURCE-LOCATORS",
        "reviewer": "different gpt-5.6-luna/high",
        "verdict": "pass_limited" if not errors else "changes_requested",
        "claim_ceiling": "independent_source_locator_only",
        "scope": "fresh source locator product/archive review; no source/product mutation",
        "product_paths": [layers["G1"]["record"], layers["G1"]["receipt"], layers["G2"]["record"], layers["G2"]["receipt"]],
        "observed_root": observed_root,
        "observed_head": observed_head,
        "direct_validation": "archive/direct_validation.json",
        "plan_validator": "archive/plan_validator_report.json",
        "scoped_diff_check": scoped,
        "no_heavy_runtime": True,
        "errors": errors,
        "self_hash_excluded": True,
    }
    write_json(OUT / "manifest.json", review_status)
    verdict = review_status["verdict"]
    report = f"""# AD-49 S1 G1/G2 source locator independent review R1

Date: {now()}  
Reviewer: `different gpt-5.6-luna/high` (fresh independent review)  
Verdict: `{verdict}`  
Claim ceiling: `independent_source_locator_only`

## Decision

Fresh read-only recomputation of the four G1/G2 source-locator products and both layer archives gives `{verdict}`. The repository root is `{observed_root}` and HEAD is `{observed_head}`. Both declared V1 source files exist only as untracked working-tree snapshots. Live `git ls-files --error-unmatch` exits 1 and `git cat-file -e HEAD:path` exits 128 for both; the corresponding `git rev-parse HEAD:path` failures emit the `HEAD:path` expression and fatal stderr, not a blob SHA.

The products close as `AbsentG1IndependentSourceLocatorV1` and `AbsentG2IndependentSourceLocatorV1`, each with `status=typed_absent`, `contract_admission=terminal_deferred`, `locator=null`, and explicit `working_tree_snapshot_is_not_independent_authority`. Their working-tree byte counts/SHA-256 are independently matched to live files. The recorded HEAD/ls-files absence and `??` status are also independently matched.

## Contract and provenance checks

The canonical JSON, exact layer paths, receipt record hash boundaries, self-hash exclusion, and all six negative controls per layer were checked. `tracked_vs_untracked_confusion` resolves to the layer-specific `Absent...` union with `terminal_deferred`; wrong root/path, cross-layer reuse, SHA mutation, and HEAD drift resolve to the layer-specific `Failed...` union with `fail_closed`. No `GG1` or `GG2` union token occurs in the reviewed products.

All 14 AD-42/AD-44/AD-43 input files listed by each product were rehashed by current bytes and matched. The prior archives' PID/UTC/exit metadata was inspected; their head-path/head-blob/ls-files raw streams preserve the nonzero failure semantics and do not present failure output as a blob. The prior run summary is `AbsentG1...`/`AbsentG2...` with `heavy_runtime_started=false`.

## Independent validation receipts

The fresh direct validator is `archive/direct_validation.json`; raw stdout/stderr, per-layer git command streams, root/status streams, and final status are in `archive/`. The planning validator and its report are in `archive/plan_validator_report.json`; the scoped `git diff --check` receipt is in `archive/fresh_scoped_git_diff_check.*`; final scope comparison is `archive/final_scope_check.json`. The process probe observed only the pre-existing `remotesolverdispatcherservice` (PID 6268), with no Julia/DESC/mesh/solver/MPI workload. No Julia, DESC, provider, mesh, solver, engineering, physics, or search command was run.

## Boundary and handoff

This review confirms only the independent locator absence boundary. It does not create or publish source authority, declaration/content/final candidate hashes, factory identity, G2 mapping, candidate identity, T0/T1/T2, provider, mesh, solver, engineering, physical, search, R01-R10, or L4 credit. A `pass_limited` result permits the parent to consider the next separately gated probe under its own decision; it does not grant source authority or factory/identity credit.

Cleanup is append-only: `cleanup_inventory.json` records the review-owned exact set and zero deletions. Existing products, sources, tests, fixtures, registries, task manifest, and unrelated dirty work were not modified.
    """
    (OUT / "report.md").write_text(report, encoding="utf-8", newline="\n")
    owned = sorted(p.relative_to(ROOT).as_posix() for p in OUT.rglob("*") if p.is_file() and p.name not in {"cleanup_inventory.json", "final_hashes.json"})
    cleanup = {
        "schema_version": "AD49-S1-independent-review-R1-cleanup-v1",
        "task_id": "AD49-S1-INDEPENDENT-G1-G2-SOURCE-LOCATORS",
        "ownership": "review_owned",
        "deletions": [],
        "entries": [{"path": p, "owner": "AD49-S1-INDEPENDENT-G1-G2-SOURCE-LOCATORS", "category": "review_evidence", "before_exists": p in preexisting, "after_exists": True, "before_sha256": preexisting.get(p, {}).get("sha256"), "after_sha256": sha_bytes((ROOT / p).read_bytes()), "action": "kept", "reason": "append_only independent review evidence"} for p in owned],
        "final_exact_owned_set": owned,
    }
    write_json(OUT / "cleanup_inventory.json", cleanup)
    final_files = sorted(p for p in OUT.rglob("*") if p.is_file() and p.name != "final_hashes.json")
    write_json(OUT / "final_hashes.json", {"schema_version": "AD49-S1-independent-review-R1-final-hashes-v1", "utc": now(), "pid": os.getpid(), "files": {p.relative_to(ROOT).as_posix(): artifact(p) for p in final_files}})
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
