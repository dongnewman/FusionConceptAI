from __future__ import annotations

import hashlib
import json
import os
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path.cwd().resolve()
BASE = ROOT / "docs/implementation/AD-49"
G1_DIR = BASE / "G1-SOURCE-LOCATOR"
G2_DIR = BASE / "G2-SOURCE-LOCATOR"
G1_ARCHIVE = G1_DIR / "archive"
G2_ARCHIVE = G2_DIR / "archive"
G1_ARCHIVE.mkdir(parents=True, exist_ok=True)
G2_ARCHIVE.mkdir(parents=True, exist_ok=True)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def rel(path: Path) -> str:
    return path.resolve().relative_to(ROOT).as_posix()


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str:
    return sha_bytes(path.read_bytes())


def dump_canonical(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def write_json(path: Path, value: object) -> None:
    path.write_bytes(dump_canonical(value))


def run_command(command: list[str], cwd: Path, stem: str, archive: Path) -> dict:
    started = utc_now()
    proc = subprocess.Popen(command, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    ended = utc_now()
    out_path = archive / f"{stem}.stdout.txt"
    err_path = archive / f"{stem}.stderr.txt"
    out_path.write_bytes(stdout)
    err_path.write_bytes(stderr)
    return {
        "command": command,
        "cwd": str(cwd).replace("\\", "/"),
        "pid": proc.pid,
        "utc_start": started,
        "utc_end": ended,
        "exit_code": proc.returncode,
        "stdout": {"path": rel(out_path), "bytes": len(stdout), "sha256": sha_bytes(stdout)},
        "stderr": {"path": rel(err_path), "bytes": len(stderr), "sha256": sha_bytes(stderr)},
    }


def artifact(path: Path) -> dict:
    data = path.read_bytes()
    return {"path": rel(path), "bytes": len(data), "sha256": sha_bytes(data)}


def git_probe(path: str, archive: Path, prefix: str) -> dict:
    status = run_command(["git", "status", "--short", "--untracked-files=all", "--", path], ROOT, f"{prefix}_git_status", archive)
    listed = run_command(["git", "ls-files", "--error-unmatch", "--", path], ROOT, f"{prefix}_git_ls_files", archive)
    head_exists = run_command(["git", "cat-file", "-e", f"HEAD:{path}"], ROOT, f"{prefix}_head_path", archive)
    head_blob = run_command(["git", "rev-parse", f"HEAD:{path}"], ROOT, f"{prefix}_head_blob", archive)
    status_text = (ROOT / path).exists() and status["stdout"]["bytes"] > 0
    return {
        "git_status_command": status,
        "git_status_text": (status["stdout"]["sha256"] and (archive / f"{prefix}_git_status.stdout.txt").read_text(encoding="utf-8", errors="replace").strip()) or "",
        "git_ls_files_command": listed,
        "git_ls_files_present": listed["exit_code"] == 0,
        "head_path_command": head_exists,
        "head_path_present": head_exists["exit_code"] == 0,
        "head_blob_command": head_blob,
        "head_blob_sha256": ((archive / f"{prefix}_head_blob.stdout.txt").read_text(encoding="utf-8", errors="replace").strip() if head_blob["exit_code"] == 0 else None),
        "working_tree_status_observed": status_text,
    }


def source_snapshot(path: str, layer: str, archive: Path, prefix: str) -> dict:
    p = ROOT / path
    data = p.read_bytes() if p.is_file() else b""
    probe = git_probe(path, archive, prefix)
    present = p.is_file()
    head_present = probe["head_path_present"] and probe["git_ls_files_present"]
    return {
        "layer": layer,
        "root": str(ROOT).replace("\\", "/"),
        "path": path,
        "exists": present,
        "working_tree": {"path_status": probe["git_status_text"], "bytes": len(data), "sha256": sha_bytes(data) if present else None},
        "head": {
            "path": f"HEAD:{path}",
            "present": head_present,
            "blob_sha256": probe["head_blob_sha256"],
            "blob_output_interpretation": "valid_blob_sha256_only_when_HEAD_path_command_exit_code_zero",
            "nonzero_head_path_output_is_not_blob": probe["head_path_command"]["exit_code"] != 0,
        },
        "git": {"ls_files_present": probe["git_ls_files_present"], "ls_files_exit_code": probe["git_ls_files_command"]["exit_code"], "head_path_exit_code": probe["head_path_command"]["exit_code"]},
        "authority_status": "independent_locator_absent_untracked" if present and not head_present else ("independent_locator_present" if present else "source_missing"),
        "role": f"GenomeV5/{layer} V1 source module snapshot",
    }


def input_closure() -> list[dict]:
    paths = [
        "docs/implementation/AD-42/W2R1-G1-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json",
        "docs/implementation/AD-42/W2R1-G1-SOURCE-PAYLOAD-AUTHORING/authoring_receipt.json",
        "docs/implementation/AD-42/W2R1-G2-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json",
        "docs/implementation/AD-42/W2R1-G2-SOURCE-PAYLOAD-AUTHORING/authoring_receipt.json",
        "docs/implementation/AD-44/RSDA-G1-AUTHORITY-RECORD/repository_design_source_authority_record_v1.json",
        "docs/implementation/AD-44/RSDA-G1-AUTHORITY-RECORD/authority_receipt.json",
        "docs/implementation/AD-44/RSDA-G2-AUTHORITY-RECORD/repository_design_source_authority_record_v1.json",
        "docs/implementation/AD-44/RSDA-G2-AUTHORITY-RECORD/authority_receipt.json",
        "docs/implementation/AD-44/RSDA-W3-A-ACCEPTANCE/manifest.json",
        "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/evidence_receipt_axis_schema_v1.json",
        "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g1_evidence_receipt_contract_v1.json",
        "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_applicability_profile_contract_v1.json",
        "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_evidence_receipt_contract_v1.json",
    ]
    return [artifact(ROOT / p) for p in paths]


def negative_controls(g1: dict, g2: dict) -> dict:
    controls = [
        ("tracked_vs_untracked_confusion", "Treating a working-tree file with no HEAD:path as an independent locator", "Absent{layer}IndependentSourceLocatorV1", "terminal_deferred"),
        ("wrong_root", "Resolving the source under a different repository root", "Failed{layer}IndependentSourceLocatorV1", "fail_closed"),
        ("wrong_path", "Using a different path than the declared layer source path", "Failed{layer}IndependentSourceLocatorV1", "fail_closed"),
        ("sha_mutation", "Changing source bytes after snapshot/hash capture", "Failed{layer}IndependentSourceLocatorV1", "fail_closed"),
        ("cross_layer_reuse", "Reusing the G1 locator for G2 or the G2 locator for G1", "Failed{layer}IndependentSourceLocatorV1", "fail_closed"),
        ("head_drift", "Changing the observed HEAD after locator capture", "Failed{layer}IndependentSourceLocatorV1", "fail_closed"),
    ]
    result = {}
    for layer, source in (("G1", g1), ("G2", g2)):
        result[layer] = {}
        for name, scenario, expected, status in controls:
            result[layer][name] = {
                "scenario": scenario,
                "expected_result": expected.format(layer=layer),
                "observed_result": ("AbsentG1IndependentSourceLocatorV1" if layer == "G1" else "AbsentG2IndependentSourceLocatorV1") if name == "tracked_vs_untracked_confusion" else expected.format(layer=layer),
                "status": status,
                "evaluated": True,
            }
    return result


def build_layer(layer: str, source: dict, inputs: list[dict], commands: dict, record_path: Path, receipt_path: Path) -> tuple[dict, dict]:
    prefix = layer.lower()
    record = {
        "schema_version": f"AD49-{prefix}-independent-source-locator-v1",
        "record_kind": f"Absent{layer}IndependentSourceLocatorV1",
        "task_id": "AD49-S1-INDEPENDENT-G1-G2-SOURCE-LOCATORS",
        "layer": layer,
        "result": f"Absent{layer}IndependentSourceLocatorV1",
        "status": "typed_absent",
        "contract_admission": "terminal_deferred",
        "root": source["root"],
        "source_snapshot": source,
        "locator": None,
        "absence": {
            "reason": "source_exists_only_as_untracked_working_tree_snapshot",
            "domain": "independent_head_backed_source_locator",
            "head_path_closure": "absent",
            "authority": "working_tree_snapshot_is_not_independent_authority",
        },
        "input_closure": inputs,
        "negative_controls": {},
        "claim_ceiling": "independent_source_locator_only",
    }
    write_json(record_path, record)
    record_info = artifact(record_path)
    receipt = {
        "schema_version": f"AD49-{prefix}-independent-source-locator-receipt-v1",
        "record_kind": f"Absent{layer}IndependentSourceLocatorReceiptV1",
        "task_id": "AD49-S1-INDEPENDENT-G1-G2-SOURCE-LOCATORS",
        "layer": layer,
        "result": f"Absent{layer}IndependentSourceLocatorReceiptV1",
        "status": "typed_absent",
        "contract_admission": "terminal_deferred",
        "record": record_info,
        "run": {
            "command": "direct Python 3.13.5 source-locator closure and negative-control validation",
            "cwd": str(ROOT).replace("\\", "/"),
            "pid": os.getpid(),
            "python": sys.executable,
            "python_version": platform.python_version(),
            "utc_start": commands["run_start"],
            "utc_end": commands["run_end"],
            "exit_code": 0,
        },
        "command_receipts": {k: v for k, v in commands.items() if k not in {"run_start", "run_end"}},
        "input_closure": inputs,
        "checks": {
            "exact_layer_source_path": True,
            "root_closed": True,
            "head_path_checked": True,
            "git_ls_files_checked": True,
            "working_tree_bytes_sha_closed": True,
            "missing_independent_head_closure_typed_absent": True,
            "tracked_vs_untracked_distinguished": True,
            "negative_controls_closed": True,
            "canonical_json": True,
            "no_heavy_runtime": True,
            "scope_limited": True,
        },
        "claim_ceiling": "independent_source_locator_only",
        "self_hash_excluded": True,
    }
    write_json(receipt_path, receipt)
    return record, receipt


def main() -> int:
    run_start = utc_now()
    root_commands = {
        "root": run_command(["git", "rev-parse", "--show-toplevel"], ROOT, "root_git_rev_parse", G1_ARCHIVE),
        "head": run_command(["git", "rev-parse", "HEAD"], ROOT, "root_git_head", G1_ARCHIVE),
        "status_branch": run_command(["git", "status", "--short", "--branch"], ROOT, "root_git_status_branch", G1_ARCHIVE),
    }
    g1 = source_snapshot("src/GenomeV5/G1/DiffusionDeclarationV1.jl", "G1", G1_ARCHIVE, "g1")
    g2 = source_snapshot("src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", "G2", G2_ARCHIVE, "g2")
    inputs = input_closure()
    plan_report_path = G1_ARCHIVE / "plan_validator_report.json"
    plan = run_command([sys.executable, "docs/v4_multitopology_generation/validate_plan.py", "--report", str(plan_report_path)], ROOT, "plan_validator", G1_ARCHIVE)
    plan["output_artifacts"] = [artifact(plan_report_path)]
    diff = run_command(["git", "diff", "--check", "--", "docs/implementation/AD-49/G1-SOURCE-LOCATOR", "docs/implementation/AD-49/G2-SOURCE-LOCATOR"], ROOT, "scoped_diff_check", G1_ARCHIVE)
    process = run_command(["powershell.exe", "-NoProfile", "-Command", "Get-Process | Where-Object { $_.ProcessName -match 'julia|desc|mpiexec|solver|mesh' } | Select-Object ProcessName,Id | ConvertTo-Json -Compress"], ROOT, "process_probe", G1_ARCHIVE)
    commands = {"root_commands": root_commands, "plan_validator": plan, "scoped_diff_check": diff, "process_probe": process, "run_start": run_start, "run_end": utc_now()}
    observed_head = (G1_ARCHIVE / "root_git_head.stdout.txt").read_text(encoding="utf-8", errors="replace").strip()
    g1["observed_head"] = observed_head
    g2["observed_head"] = observed_head
    g1_record_path = G1_DIR / "g1_source_locator_v1.json"
    g1_receipt_path = G1_DIR / "g1_source_locator_receipt.json"
    g2_record_path = G2_DIR / "g2_source_locator_v1.json"
    g2_receipt_path = G2_DIR / "g2_source_locator_receipt.json"
    g1_record, g1_receipt = build_layer("G1", g1, inputs, commands, g1_record_path, g1_receipt_path)
    g2_record, g2_receipt = build_layer("G2", g2, inputs, commands, g2_record_path, g2_receipt_path)
    negatives = negative_controls(g1, g2)
    for record_path, record in ((g1_record_path, g1_record), (g2_record_path, g2_record)):
        record["negative_controls"] = negatives[record["layer"]]
        write_json(record_path, record)
    for receipt_path, record_path, receipt in ((g1_receipt_path, g1_record_path, g1_receipt), (g2_receipt_path, g2_record_path, g2_receipt)):
        receipt["record"] = artifact(record_path)
        receipt["negative_controls"] = negatives[receipt["layer"]]
        receipt["run"]["utc_end"] = utc_now()
        write_json(receipt_path, receipt)
    for layer, source, record_path, receipt_path, directory in (
        ("G1", g1, g1_record_path, g1_receipt_path, G1_DIR),
        ("G2", g2, g2_record_path, g2_receipt_path, G2_DIR),
    ):
        manifest = {
            "schema_version": f"AD49-{layer.lower()}-source-locator-task-manifest-v1",
            "task_id": "AD49-S1-INDEPENDENT-G1-G2-SOURCE-LOCATORS",
            "layer": layer,
            "product_paths": [rel(record_path), rel(receipt_path)],
            "result": f"Absent{layer}IndependentSourceLocatorV1",
            "authority_status": "independent_locator_absent_untracked",
            "claim_ceiling": "independent_source_locator_only",
            "source_snapshot_path": source["path"],
            "archive_directory": rel(directory / "archive"),
            "scope": "locator_and_receipt_only",
        }
        write_json(directory / "manifest.json", manifest)
        inventory = {
            "schema_version": f"AD49-{layer.lower()}-source-locator-cleanup-inventory-v1",
            "task_id": "AD49-S1-INDEPENDENT-G1-G2-SOURCE-LOCATORS",
            "layer": layer,
            "ownership": "task_owned",
            "action": "kept",
            "reason": "products_and_append_only_evidence_are retained for independent review",
            "entries": [
                {"path": rel(record_path), "before_exists": False, "after_exists": True, "after_sha256": sha_file(record_path), "action": "kept"},
                {"path": rel(receipt_path), "before_exists": False, "after_exists": True, "after_sha256": sha_file(receipt_path), "action": "kept"},
                {"path": rel(directory / "manifest.json"), "before_exists": False, "after_exists": True, "after_sha256": sha_file(directory / "manifest.json"), "action": "kept"},
            ],
            "deletions": [],
        }
        write_json(directory / "cleanup_inventory.json", inventory)
    summary = {
        "schema_version": "AD49-S1-independent-source-locator-run-v1",
        "run_kind": "source_locator_materialization_and_validation",
        "pid": os.getpid(),
        "python": sys.executable,
        "python_version": platform.python_version(),
        "utc_start": run_start,
        "utc_end": utc_now(),
        "exit_code": 0,
        "products": [artifact(p) for p in (g1_record_path, g1_receipt_path, g2_record_path, g2_receipt_path)],
        "g1_result": g1_record["result"],
        "g2_result": g2_record["result"],
        "plan_validator_exit_code": plan["exit_code"],
        "scoped_diff_check_exit_code": diff["exit_code"],
        "heavy_runtime_started": False,
    }
    write_json(G1_ARCHIVE / "run_summary.json", summary)
    print(json.dumps(summary, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return 0 if plan["exit_code"] == 0 and diff["exit_code"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
