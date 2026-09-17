from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
BASE = ROOT / "docs/implementation/UP2-00G-I0-MODULE-SEAM"
FILES = {
    "src/GenomeV5/UP2/UP2ModuleEntryV1.jl": "7eb7ed593fbac217ea925830e53b675a38760aed708c7864bd43c436f74d8937",
    "test/GenomeV5/UP2/up2_module_entry_tests.jl": "3d595b399f8e9681881f61fa2e25590dd6646986385af72021a33672c96b4cb5",
    "test/GenomeV5/UP2/run_up2_module_entry.jl": "db1fd47e395d748ffed5205c1ed00be87a1dc63d684ce85e792b6f44632598d2",
    "test/GenomeV5/UP2/up2_module_entry_failure_probe.jl": "59204f1b24d6c03c1a6097e748c42808d06858a6197f49254c6ff28580c21591",
    "docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md": "a01c9c65a3bed8ed0b2f887ba3cfaac1d3941cc09bb08cd7717f6a59106de713",
}


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def process_sweep() -> tuple[list[dict], str, int]:
    cmd = ["powershell", "-NoProfile", "-Command",
           "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)(\\.exe)?$' } | Select-Object ProcessId,ParentProcessId,Name,CommandLine,CreationDate | ConvertTo-Json -Compress"]
    p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    raw = p.stdout.strip()
    if not raw:
        return [], p.stderr, p.returncode
    try:
        value = json.loads(raw)
        if isinstance(value, dict):
            value = [value]
        return value, p.stderr, p.returncode
    except json.JSONDecodeError:
        return [{"raw": raw}], p.stderr, p.returncode


def digest_map() -> dict:
    return {rel: {"sha256": sha(ROOT / rel), "bytes": (ROOT / rel).stat().st_size} for rel in FILES}


def protected_map() -> dict:
    archive = json.loads((BASE / "protected_dirty_hashes.json").read_text(encoding="utf-8"))
    values = {}
    for item in archive["files"]:
        p = ROOT / item["path"]
        values[item["path"]] = {"expected_sha256": item["sha256"], "actual_sha256": sha(p),
                                 "expected_bytes": item["bytes"], "actual_bytes": p.stat().st_size,
                                 "match": item["sha256"] == sha(p) and item["bytes"] == p.stat().st_size}
    return values


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    pre_processes, pre_err, pre_exit = process_sweep()
    preflight = {
        "work_order": "UP2-00G-I0-MODULE-SEAM", "attempt": "focused_r1",
        "checked_at_utc": utc(), "runner_command": ["julia", "--startup-file=no", "--project=.", "test/GenomeV5/UP2/run_up2_module_entry.jl"],
        "frozen_inputs": digest_map(),
        "expected_hashes": FILES,
        "r3_manifest_sha256": sha(BASE / "independent_review_r3/evidence_manifest.json"),
        "pre_process_sweep": {"processes": pre_processes, "stderr": pre_err, "exit": pre_exit},
        "protected_dirty_before": protected_map(),
    }
    (OUT / "preflight.json").write_text(json.dumps(preflight, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if pre_processes or pre_exit != 0:
        result = {"status": "runtime_failed", "reason": "Julia/DESC process conflict before launch", "preflight": preflight}
        (OUT / "receipt.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return 2

    stdout_path = OUT / "stdout.log"
    stderr_path = OUT / "stderr.log"
    command = ["julia", "--startup-file=no", "--project=.", "test/GenomeV5/UP2/run_up2_module_entry.jl"]
    started = utc()
    samples = []
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        proc = subprocess.Popen(command, cwd=ROOT, stdout=stdout, stderr=stderr)
        main_pid = proc.pid
        while proc.poll() is None:
            observed, sweep_stderr, sweep_exit = process_sweep()
            samples.append({"time_utc": utc(), "processes": observed,
                            "sweep_stderr": sweep_stderr, "sweep_exit": sweep_exit})
            time.sleep(0.5)
        real_exit = proc.returncode
    ended = utc()
    post_processes, post_err, post_exit = process_sweep()
    (OUT / "process_samples.json").write_text(json.dumps(samples, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    hashes = {
        "stdout": {"path": str(stdout_path.relative_to(ROOT)), "bytes": stdout_path.stat().st_size, "sha256": sha(stdout_path)},
        "stderr": {"path": str(stderr_path.relative_to(ROOT)), "bytes": stderr_path.stat().st_size, "sha256": sha(stderr_path)},
    }
    receipt = {
        "work_order": "UP2-00G-I0-MODULE-SEAM", "attempt": "focused_r1",
        "command": "julia --startup-file=no --project=. test/GenomeV5/UP2/run_up2_module_entry.jl",
        "cwd": str(ROOT), "main_pid": main_pid, "start_utc": started, "end_utc": ended,
        "real_exit": real_exit, "stdout": hashes["stdout"], "stderr": hashes["stderr"],
        "process_samples": samples, "post_processes": post_processes,
        "post_process_sweep_stderr": post_err, "post_process_sweep_exit": post_exit,
        "note": "The frozen runner itself launches the authorized fresh-process failure probe serially; no separate concurrent Julia was started.",
    }
    (OUT / "receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (OUT / "artifact_hashes.json").write_text(json.dumps({"inputs_after": digest_map(), "logs": hashes,
        "protected_dirty_after": protected_map()}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    stdout_text = stdout_path.read_text(encoding="utf-8", errors="replace")
    expected = {
        "additive module entry": (12, 12),
    }
    group_results = {}
    for title, pair in expected.items():
        found = re.findall(r"^UP2-00G-I0 " + re.escape(title) + r"\s*\|\s*(\d+)\s+(\d+)", stdout_text, re.MULTILINE)
        group_results[title] = {"found": found, "expected": list(pair), "pass": found == [tuple(str(x) for x in pair)]}
    # The runner includes the shared up2_module_entry_tests.jl testset as a named summary.
    group_results["UP2 additive module entry"] = {"found": re.findall(r"^UP2 additive module entry\s*\|\s*(\d+)\s+(\d+)", stdout_text, re.MULTILINE)}
    inputs_after = digest_map()
    input_matches = all(data["sha256"] == FILES[rel] for rel, data in inputs_after.items())
    protected_after = protected_map()
    protected_matches = all(x["match"] for x in protected_after.values())
    status = "runtime_pass_pending_independent" if real_exit == 0 and not post_processes and input_matches and protected_matches else "runtime_failed"
    report = {
        "work_order": "UP2-00G-I0-MODULE-SEAM", "attempt": "focused_r1",
        "status": status, "claim_ceiling": "focused_wiring_runtime_only_no_acceptance_or_credit",
        "real_exit": real_exit, "main_pid": main_pid, "start_utc": started, "end_utc": ended,
        "frozen_input_matches": input_matches, "protected_dirty_matches": protected_matches,
        "post_processes_empty": not post_processes and post_exit == 0,
        "test_groups": group_results,
        "source_hashes": inputs_after, "r3_manifest_sha256": preflight["r3_manifest_sha256"],
        "logs": hashes, "failures": [] if status != "runtime_failed" else ["runner exit/process/hash gate failed"],
        "limitations": ["This is the single authorized focused G-I0 runtime. It grants no UP2/B00/B04/provider/mesh/physical/R01-R10 credit.",
                        "The runner's fresh-process failure probe is included serially by the frozen runner; its individual output is part of stdout.log."],
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    md = f"""# G-I0 focused runtime R1

Status: **{status}**. Command ran exactly once with the frozen runner; no concurrent Julia/DESC process was started.

Main PID: `{main_pid}`. UTC: `{started}` to `{ended}`. Real exit: `{real_exit}`. Raw stdout/stderr and their SHA256/byte counts are recorded in [receipt.json](receipt.json). The runner's authorized fresh-process failure probe was invoked serially by the frozen runner. Post-run process sweep empty: `{not post_processes and post_exit == 0}`.

Frozen entry/test/runner/probe/core18 hashes remained unchanged, and protected dirty-file hashes were recomputed before and after. The runtime status is bounded to G-I0 wiring behavior and does not grant UP2, B00, B04, provider, mesh, engineering, physical, or R01-R10 credit. Independent Luna R3 static review remains the prerequisite review gate.

All raw output is preserved in `stdout.log` and `stderr.log`; structured receipt, process samples, and artifact hashes are in `receipt.json`, `process_samples.json`, and `artifact_hashes.json`.
"""
    (OUT / "report.md").write_text(md, encoding="utf-8")
    print(json.dumps({"status": status, "real_exit": real_exit, "main_pid": main_pid,
                      "stdout_sha256": hashes["stdout"]["sha256"], "stderr_sha256": hashes["stderr"]["sha256"],
                      "post_processes": len(post_processes)}, ensure_ascii=False))
    return 0 if status != "runtime_failed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
