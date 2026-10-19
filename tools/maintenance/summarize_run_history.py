"""Prepare a hash-bound, file-only cleanup plan after summarizing run evidence.

This command never deletes files. Raw artifacts are not reconstructed by a
summary; missing replay inputs must be regenerated. Source fixtures and the
explicit paused-work input closure are excluded from the plan.
"""
from __future__ import annotations

import collections
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/implementation/WORKSPACE-CONSOLIDATION-20261019"
SEED_RUNS = (
    "up2_C771_mask_active_step_saved_20261019_r17",
    "up2_near64_direct_boundary_BJ_bridge_20261019_r7",
    "up2_far_full64_edge_cost_forecast_20261019_r6",
    "up2_current_D0_adj35_full_continuous_sector_20261019_r3",
    "up2_current_D0_C771_actual64_implicit_root_graph_20261019_r3",
    "up2_current_D0_C771_actual64_saved_report_recovery_20261019_r3",
)
SOURCE_EXT = {".jl", ".py", ".ps1"}
RETIRED_FAMILIES = (
    "tools/up1_external_closure_r2/", "tools/up1_external_closure_r3/", "tools/up1_external_closure_r4/",
    "test/up1_external_closure_r2/", "test/up1_external_closure_r3/", "test/up1_external_closure_r4/",
    "tools/up4_reference_validation/", "test/UP4ReferenceValidationV1/", "test/UP4ReferenceValidationV10Review/",
)
RAW_EXT = {".raw", ".log", ".stdout", ".stderr", ".jsonl", ".csv", ".bin", ".f64", ".f32le", ".f64le", ".tmp", ".jls"}
BACKUP_EXT = {".patch", ".diff", ".snapshot", ".preimage", ".postimage", ".before", ".after", ".work", ".new", ".copy", ".orig", ".rej", ".draft", ".superseded"}
RECEIPT_FIELDS = (
    "actual_child_os_exit_code", "child_exit_code", "exit_code", "stop_reason",
    "seconds", "duration_seconds", "resource_gate_passed", "passed_software_check",
    "child_exit_success", "cleanup_complete", "input_pins_unchanged", "formal_acceptance",
    "physical_validation", "status", "reason", "failure_code", "peak_job_commit_bytes",
    "peak_sampled_tree_rss_bytes", "job_memory_limit_bytes", "resource_audit_coverage",
)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def safe_file(rel: str) -> Path:
    if Path(rel).is_absolute() or "\\" in rel or ":" in rel or ".." in Path(rel).parts:
        raise ValueError(f"cleanup path must be canonical and root-relative: {rel}")
    path = ROOT / rel
    resolved = path.resolve(strict=True)
    if not resolved.is_relative_to(ROOT) or not resolved.is_file() or path.is_symlink():
        raise ValueError(f"unsafe cleanup input: {rel}")
    return path


def source_refs(paths: set[str]) -> set[str]:
    """Preserve exact existing source references, including local include closure."""
    found = set(paths)
    queue = list(paths)
    seen = set()
    pattern = re.compile(r'["\']([^"\'\r\n]+\.(?:jl|py|ps1))["\']')
    while queue:
        rel = queue.pop()
        if rel in seen:
            continue
        seen.add(rel)
        path = ROOT / rel
        if not path.is_file() or path.stat().st_size > 3 * 1024 * 1024:
            continue
        raw = path.read_text(encoding="utf-8-sig", errors="replace")
        for token in pattern.findall(raw):
            for candidate in (ROOT / token, path.parent / token):
                try:
                    target = candidate.resolve(strict=True)
                except OSError:
                    continue
                if target.is_file() and target.is_relative_to(ROOT):
                    key = target.relative_to(ROOT).as_posix()
                    if key not in found:
                        found.add(key)
                        queue.append(key)
    return found


def keep_inputs(records: list[dict]) -> tuple[set[str], dict]:
    keep = {
        "tmp/up3_queue_rejection_focus.jl", "tmp/up3_q1_dispatch_diag.jl",
        "tmp/up3_queue_absent_constructor_test.jl",
    }
    reasons = {p: "paused UP3 focused-check entry" for p in keep}
    for run in SEED_RUNS:
        leaf = ROOT / "runs/e" / run
        pins = leaf / "input_pins_before.json"
        if not pins.is_file():
            raise ValueError(f"required paused-chain pins missing: {run}")
        pinned = read_json(pins)
        if not isinstance(pinned, dict) or not pinned:
            raise ValueError(f"empty/invalid paused-chain pins: {run}")
        for rel in pinned:
            safe_file(rel)
            keep.add(rel)
            reasons[rel] = f"exact input of paused chain: {run}"
        for p in (leaf / "result_data").rglob("*.jls") if (leaf / "result_data").is_dir() else ():
            rel = p.relative_to(ROOT).as_posix()
            keep.add(rel)
            reasons[rel] = f"latest diagnostic checkpoint: {run}"
    # Timeouts can legitimately have no result; successful saved-data stages
    # must retain an actual diagnostic payload, not just a directory name.
    for run in SEED_RUNS[:3] + SEED_RUNS[-1:]:
        latest = ROOT / "runs/e" / run / "result_data"
        if not latest.is_dir() or not any(latest.rglob("*.jls")):
            raise ValueError(f"required latest diagnostic payload missing: {run}")
    manifest = read_json(ROOT / "docs/v4_multitopology_generation/task_manifest.json")
    explicit_roots = set()
    for lane in manifest["work_lines"]:
        explicit_roots.update(lane["inputs"] + lane["latest_evidence"])
    for task in manifest["tasks"]:
        record = task.get("acceptance_record")
        if record and (ROOT / record).is_file():
            explicit_roots.add(record)
    current = next(t for t in manifest["tasks"] if t["id"] == "UP1-04A-VNEXT")
    accepted = read_json(safe_file(current["acceptance_record"]))
    explicit_roots.update(accepted[k] for k in ("actual_source_pair", "actual_native_pair"))
    for rel in sorted(explicit_roots):
        path = ROOT / rel
        if not path.exists() or not path.resolve().is_relative_to(ROOT):
            raise ValueError(f"active work-order input/evidence missing or outside root: {rel}")
        paths = [path] if path.is_file() else [p for p in path.rglob("*") if p.is_file()]
        for item in paths:
            key = item.relative_to(ROOT).as_posix()
            safe_file(key)
            keep.add(key)
            reasons[key] = "explicit active work-order input/evidence or current accepted software result"
    (OUT / "active_keep_roots.json").write_text(json.dumps(sorted(explicit_roots), ensure_ascii=False, indent=2), encoding="utf-8")
    # Source acquisition is an unadmitted reference input, not a simulation result.
    for row in records:
        if row["path"].startswith("tmp/resume_20261009_up4_source_owned/"):
            keep.add(row["path"])
            reasons[row["path"]] = "unadmitted reference-source acquisition/provenance"
    current_sources = {row["path"] for row in records
                       if row["path"].split("/")[0] in {"src", "test", "tools", "scripts", "examples"}
                       and not row["path"].startswith(RETIRED_FAMILIES)
                       and Path(row["path"]).suffix in SOURCE_EXT}
    closure = source_refs(current_sources | {p for p in keep if Path(p).suffix in SOURCE_EXT})
    for rel in closure:
        if rel.startswith(("runs/", "tmp/", "docs/implementation/")):
            keep.add(rel)
            reasons.setdefault(rel, "exact source reference/include from maintained code or paused entry")
    return keep, reasons


def deletion_reason(row: dict, keep: set[str]) -> str | None:
    rel, size = row["path"], row["bytes"]
    if rel in keep:
        return None
    p = Path(rel)
    if "__pycache__" in p.parts or rel.startswith((".ruff_cache/", ".pytest_cache/")):
        return "rebuildable interpreter/linter cache"
    if rel in {"0", "3000000000)", "test/runtime_v4_freegs_axisymmetric_lcfs_trace_tests.jl.after"}:
        return "orphan shell output or superseded source snapshot"
    if rel.startswith(RETIRED_FAMILIES):
        return "retired optional certification/UP4 protocol version family and its exclusive tests"
    if "/WORKSPACE-CONSOLIDATION-20261019/" in rel or "/IMPLEMENTED-STATE-20261019/" in rel:
        return None
    # Preserve receipt and source/input-pin metadata even in old scratch trees.
    # Closed retired code families above are recorded in the retirement manifest.
    if p.suffix == ".json" and any(token in p.name.lower() for token in ("receipt", "input_pins", "source_pins")):
        return None
    if rel.startswith("tmp/"):
        return "retired unreferenced temporary code/probe/output; paused entries excluded"
    in_runs = rel.startswith("runs/")
    in_archive = rel.startswith(("docs/implementation/", "tools/m5_search_contract_r2/evidence/"))
    if not in_runs and not in_archive:
        return "root run log/exit artifact" if "/" not in rel and p.suffix in {".log", ".exit"} else None
    if p.suffix in RAW_EXT:
        # Small serialized proof/config packets cost little and may be replay inputs.
        if p.suffix == ".jls" and size <= 64 * 1024:
            return None
        return "raw run payload/log summarized before removal"
    if p.suffix in BACKUP_EXT or (in_runs and p.suffix in SOURCE_EXT):
        return "obsolete run-local source copy/patch; maintained references excluded"
    if p.suffix == ".json":
        metadata = any(x in p.name.lower() for x in ("receipt", "input_pins", "invocation", "protocol", "manifest", "config"))
        if size > (2 * 1024 * 1024 if metadata else 128 * 1024):
            return "large run result/report replaced by bounded summary and artifact hash"
    return None


def group_for(rel: str) -> str:
    parts = rel.split("/")
    if parts[0] == "runs":
        return "/".join(parts[:3] if len(parts) > 2 and parts[1] == "e" else parts[:2])
    return "/".join(parts[:3] if parts[:2] == ["docs", "implementation"] else parts[:2])


def log_excerpt(path: Path, size: int) -> dict:
    limit = 256 * 1024
    with path.open("rb") as f:
        if size <= 4 * limit:
            data = f.read()
        else:
            head = f.read(limit)
            f.seek(max(0, size - 3 * limit))
            data = head + b"\n[... middle omitted ...]\n" + f.read(3 * limit)
    lines = data.decode("utf-8", errors="replace").splitlines()
    selected = []
    expression = re.compile(r"Test Summary|\b(?:ERROR|Error|FAIL|failed|failure|numerical_fail|resource_interruption|HOLD|stop_reason|status|Pass|Total)\b")
    for i, line in enumerate(lines):
        if expression.search(line):
            selected.extend(lines[max(0, i - 1):min(len(lines), i + 3)])
    if not selected:
        selected = lines[-8:]
    unique = list(dict.fromkeys(line[:600] for line in selected if line.strip()))
    return {"sampled": size > 4 * limit, "lines": unique[-32:]}


def json_scalar_excerpt(path: Path) -> dict:
    """Bounded scalar projection of a removed large JSON payload, not a replay."""
    wanted = r"status|reason|failure_code|accepted|formal_acceptance|claim_ceiling|full64|physical_validation|scaledmax|residual_norm|residual_abs|true_kkt_relative_defect|stationarity|iteration_count|row_count|provider_invocation_count|solver_invocation_count|resource_gate_passed|stop_reason"
    expression = re.compile(r'"(' + wanted + r')"\s*:\s*("[^"\r\n]{0,300}"|true|false|null|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)')
    values = collections.defaultdict(list)
    carry = ""
    with path.open("r", encoding="utf-8-sig", errors="replace") as stream:
        for chunk in iter(lambda: stream.read(256 * 1024), ""):
            data = carry + chunk
            for key, value in expression.findall(data):
                if value not in values[key]:
                    values[key].append(value)
                    if len(values[key]) > 8:
                        values[key] = values[key][:4] + values[key][-4:]
            carry = data[-1024:]
    return {"projection_only": True, "array_payload_omitted": True,
            "fields_at_any_depth_not_acceptance": dict(values)}


def main() -> None:
    with gzip.open(OUT / "baseline_file_inventory.json.gz", "rt", encoding="utf-8") as f:
        records = json.load(f)
    keep, reasons = keep_inputs(records)
    preserved = []
    for row in records:
        if row["path"] in keep:
            path = safe_file(row["path"])
            st = path.stat()
            preserved.append({**row, "bytes": st.st_size, "mtime_ns": st.st_mtime_ns,
                              "sha256": sha256(path),
                              "reason": reasons.get(row["path"], "maintained input")})
    (OUT / "retained_inputs.json").write_text(json.dumps(preserved, ensure_ascii=False, indent=2), encoding="utf-8")
    prior = {}
    plan_path = OUT / "deletion_plan.jsonl"
    if plan_path.is_file():
        with plan_path.open(encoding="utf-8") as stream:
            prior = {row["path"]: row for row in map(json.loads, stream)}
    groups = collections.defaultdict(lambda: {"files": 0, "bytes_before": 0, "delete_files": 0, "delete_bytes": 0, "receipts": [], "log_excerpts": [], "json_projections": []})
    plan = []
    for i, row in enumerate(records):
        rel = row["path"]
        reason = deletion_reason(row, keep)
        if not rel.startswith(("runs/", "tmp/", "docs/implementation/", "tools/m5_search_contract_r2/evidence/")) and not reason:
            continue
        group = groups[group_for(rel)]
        group["files"] += 1
        group["bytes_before"] += row["bytes"]
        path = ROOT / rel
        if path.name in {"receipt.json", "command_receipt.json", "resource_receipt.json"} and row["bytes"] < 2 * 1024 * 1024:
            try:
                receipt = read_json(path)
                group["receipts"].append({"path": rel, **{k: receipt[k] for k in RECEIPT_FIELDS if k in receipt}})
            except (OSError, ValueError, TypeError) as exc:
                group["receipts"].append({"path": rel, "parse_error": str(exc)})
        if reason and path.name in {"stdout.raw", "stderr.raw", "stdout.log", "stderr.log"}:
            group["log_excerpts"].append({"path": rel, **log_excerpt(path, row["bytes"])})
        if reason and path.suffix == ".json":
            group["json_projections"].append({"path": rel, **json_scalar_excerpt(path)})
        if reason:
            checked = safe_file(rel)
            st = checked.stat()
            if st.st_size != row["bytes"] or st.st_mtime_ns != row["mtime_ns"]:
                if reason == "rebuildable interpreter/linter cache":
                    row = {**row, "bytes": st.st_size, "mtime_ns": st.st_mtime_ns}
                else:
                    raise ValueError(f"file changed since baseline: {rel}")
            cached = prior.get(rel, {})
            digest = cached.get("sha256") if (cached.get("bytes"), cached.get("mtime_ns")) == (st.st_size, st.st_mtime_ns) else None
            record = {**row, "sha256": digest or sha256(checked), "reason": reason, "summary_group": group_for(rel)}
            plan.append(record)
            group["delete_files"] += 1
            group["delete_bytes"] += row["bytes"]
        if i and i % 10000 == 0:
            print(json.dumps({"inventory_checked": i, "planned_files": len(plan)}), flush=True)
    with (OUT / "deletion_plan.jsonl").open("w", encoding="utf-8", newline="\n") as f:
        for record in plan:
            f.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")
    with gzip.open(OUT / "run_history_index.jsonl.gz", "wt", encoding="utf-8", newline="\n") as f:
        for path, record in sorted(groups.items()):
            f.write(json.dumps({"path": path, **record}, ensure_ascii=False, separators=(",", ":")) + "\n")
    stats = {"schema": "summarized-raw-cleanup-plan-v1", "user_authorized_date": "2026-10-19",
             "goal_state": "paused", "plan_only": True, "groups": len(groups), "delete_files": len(plan),
             "delete_bytes": sum(r["bytes"] for r in plan), "retained_input_files": len(preserved),
             "retained_input_bytes": sum(r["bytes"] for r in preserved),
             "raw_cleanup_grants_no_acceptance": True, "deleted_inputs_require_regeneration_for_replay": True,
             "by_reason": dict(collections.Counter(r["reason"] for r in plan))}
    (OUT / "cleanup_plan_summary.json").write_text(json.dumps(stats, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(stats, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
