from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
LEDGER = ROOT / "docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER"
COMMAND = ["julia", "--startup-file=no", "--project=.",
           "test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl"]
FROZEN = {
    "src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl":
        "69bd82f040f405e55768e52af64b9b9b6d97272a2ec3988b66b7bdf21ec1128c",
    "test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl":
        "dac8c62e4ba20b45930a119649468659931eca2236cb9c5181aba101392a66ce",
    "test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json":
        "361a1777a765ed6784a1f37c02febc24c2ba5f6eed3c6a15b99333af596736b2",
    "test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl":
        "9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af",
}
PROTECTED = ["src/FusionConceptAI.jl", "test/runtime_v4_test_manifest.json", "README.md"]


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def process_sweep() -> str:
    cmd = ("Get-Process | Where-Object { $_.ProcessName -match 'julia|desc' } "
           "| Select-Object Id,ProcessName,Path | ConvertTo-Json -Compress")
    cp = subprocess.run(["powershell", "-NoProfile", "-Command", cmd], cwd=ROOT,
                        text=True, capture_output=True, encoding="utf-8", errors="replace")
    if cp.returncode != 0:
        raise RuntimeError(f"process sweep failed: {cp.stderr}")
    return cp.stdout.strip()


def children_of(pid: int) -> list[dict]:
    cmd = ("Get-CimInstance Win32_Process | "
           f"Where-Object {{ $_.ParentProcessId -eq {pid} }} | "
           "Select-Object ProcessId,ParentProcessId,Name,CommandLine | "
           "ConvertTo-Json -Compress")
    cp = subprocess.run(["powershell", "-NoProfile", "-Command", cmd], cwd=ROOT,
                        text=True, capture_output=True, encoding="utf-8", errors="replace")
    if cp.returncode != 0 or not cp.stdout.strip():
        return []
    try:
        data = json.loads(cp.stdout)
    except json.JSONDecodeError:
        return []
    return data if isinstance(data, list) else [data]


def write_json(name: str, value) -> None:
    (OUT / name).write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "command.txt").write_text(" ".join(COMMAND) + "\n", encoding="utf-8")
    current_inputs = {rel: digest(ROOT / rel) for rel in FROZEN}
    (OUT / "input_hashes.txt").write_text("".join(
        f"{current_inputs[rel]}  {rel}\n" for rel in FROZEN), encoding="utf-8")
    status_before = subprocess.run(["git", "status", "--short", "--untracked-files=all"],
        cwd=ROOT, text=True, capture_output=True, encoding="utf-8", errors="replace")
    (OUT / "dirty_status_before.txt").write_text(status_before.stdout, encoding="utf-8")
    protected_before = {rel: digest(ROOT / rel) for rel in PROTECTED}
    (OUT / "protected_before_hashes.txt").write_text("".join(
        f"{protected_before[rel]}  {rel}\n" for rel in PROTECTED), encoding="utf-8")
    preflight = process_sweep()
    (OUT / "preflight_processes.json").write_text(preflight + ("\n" if preflight else ""), encoding="utf-8")
    if preflight not in ("", "null", "{}", "[]"):
        raise RuntimeError(f"Julia/DESC lane was occupied before run: {preflight}")
    if current_inputs != FROZEN:
        raise RuntimeError(json.dumps({"expected": FROZEN, "current": current_inputs}, indent=2))

    started = now()
    (OUT / "start_time.txt").write_text(started + "\n", encoding="utf-8")
    stdout_path = OUT / "stdout.log"
    stderr_path = OUT / "stderr.log"
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        proc = subprocess.Popen(COMMAND, cwd=ROOT, stdout=stdout, stderr=stderr)
        pid = proc.pid
        (OUT / "main_pid.txt").write_text(str(pid) + "\n", encoding="utf-8")
        snapshots = []
        while proc.poll() is None:
            snapshots.append({"utc": now(), "children": children_of(pid)})
            time.sleep(0.5)
        exit_code = proc.returncode
        snapshots.append({"utc": now(), "children": children_of(pid)})
    (OUT / "process_snapshots.jsonl").write_text("".join(
        json.dumps(x, ensure_ascii=False) + "\n" for x in snapshots), encoding="utf-8")
    ended = now()
    (OUT / "end_time.txt").write_text(ended + "\n", encoding="utf-8")
    (OUT / "exit.txt").write_text(str(exit_code) + "\n", encoding="utf-8")
    children = sorted({c.get("ProcessId") for s in snapshots for c in s["children"] if c.get("ProcessId") is not None})
    write_json("process.json", {"main_pid": pid, "child_pids_observed": children,
                                 "snapshots": len(snapshots)})
    postflight = process_sweep()
    (OUT / "postflight_processes.json").write_text(postflight + ("\n" if postflight else ""), encoding="utf-8")
    protected_after = {rel: digest(ROOT / rel) for rel in PROTECTED}
    (OUT / "protected_after_hashes.txt").write_text("".join(
        f"{rel}\t{protected_after[rel]}\n" for rel in PROTECTED), encoding="utf-8")
    status_after = subprocess.run(["git", "status", "--short", "--untracked-files=all"],
        cwd=ROOT, text=True, capture_output=True, encoding="utf-8", errors="replace")
    (OUT / "dirty_status_after.txt").write_text(status_after.stdout, encoding="utf-8")
    out_bytes = stdout_path.read_bytes()
    err_bytes = stderr_path.read_bytes()
    receipt = {
        "run": "focused_r8", "command": " ".join(COMMAND),
        "cwd": str(ROOT), "main_pid": pid, "child_pids_observed": children,
        "started_utc": started, "ended_utc": ended, "exit": exit_code,
        "classification": "pass" if exit_code == 0 else "program_exception",
        "stdout": {"path": "stdout.log", "bytes": len(out_bytes), "sha256": hashlib.sha256(out_bytes).hexdigest()},
        "stderr": {"path": "stderr.log", "bytes": len(err_bytes), "sha256": hashlib.sha256(err_bytes).hexdigest()},
        "input_hashes_match": current_inputs == FROZEN,
        "protected_before_after_match": protected_before == protected_after,
        "postflight": postflight,
        "prior_failures_preserved": True, "no_retry_in_round": True,
        "compile_calls": 0, "provider_calls": 0, "solver_calls": 0,
        "physical": False, "provider": False, "engineering": False,
        "b00_b04": False,
    }
    write_json("receipt.json", receipt)
    stdout_text = out_bytes.decode("utf-8", errors="replace")
    summaries = re.findall(r"Test Summary:.*", stdout_text)
    qa = {
        "input_hashes_match": receipt["input_hashes_match"],
        "source_test_fixture_runner_frozen": True,
        "exit": exit_code,
        "stdout_bytes": len(out_bytes), "stderr_bytes": len(err_bytes),
        "stdout_sha256": receipt["stdout"]["sha256"], "stderr_sha256": receipt["stderr"]["sha256"],
        "test_summary_lines": summaries,
        "child_pids_observed": children,
        "postflight_empty": postflight in ("", "null", "{}", "[]"),
        "protected_before_after_match": protected_before == protected_after,
        "r1_r7_raw_preserved": all((LEDGER / f"focused_r{i}" / "receipt.json").is_file() for i in range(1, 8)),
        "focused_rerun_count_in_this_round": 1,
        "claim_ceiling": "runtime result only; no B04/provider/mesh/engineering/physical/R01-R10 credit",
    }
    write_json("qa.json", qa)
    verdict = "runtime_pass_pending_independent" if exit_code == 0 else "runtime_failed"
    (OUT / "report.md").write_text(
        f"# E2-N06 focused R8\n\nVerdict: `{verdict}`.\n\n"
        f"Frozen source/test/fixture/runner hashes matched before the single run. Main PID `{pid}`; "
        f"UTC `{started}` to `{ended}`; real exit `{exit_code}`. Raw stdout/stderr byte counts and SHA-256 are in `receipt.json`. "
        f"Observed child PIDs: `{children}`. Postflight Julia/DESC sweep: `{postflight or 'empty'}`. "
        f"Protected dirty before/after hashes match: `{protected_before == protected_after}`.\n\n"
        "R1-R7 raw failures remain immutable. This run grants no B04/provider/mesh/engineering/physical/R01-R10 credit. "
        "If exit 0, an independent Luna post-run review is still required; if exit 1, the raw failure is final for this round and no retry was made.\n",
        encoding="utf-8")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
