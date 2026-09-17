from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
COMMAND = ["julia", "--startup-file=no", "--project=.",
           "test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl"]
INPUTS = {
    "src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl": "804cf2cb3522eceefe37664737934bcffdad15ba2d5d2a28c0a70bcf1fca1f6d",
    "test/GenomeV5/G1/fixtures.json": "9531b5baa6f45cf71527c882de1fa1fa60bedd2c999498e4147fa81a23451bf0",
    "test/GenomeV5/G2/fixtures.json": "831d54a696670166e2b912a1e3b6bd1dd97a03bdf33f6c41260c5d604661f84e",
    "test/GenomeV5/G3/fixtures.json": "f25945083f250f3620e0dc66a003a926df7235e6ce377f5946d85f6d7caa0bb0",
    "src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl": "69bd82f040f405e55768e52af64b9b9b6d97272a2ec3988b66b7bdf21ec1128c",
    "test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl": "d88a1ed7965716eb4210c09fd5b89b3e4e27e8677c15ff8dcbe0721b8a373ca1",
    "test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json": "e37314924102c75ac47a34652d0a480c4730e04590cb17294033719ce92d37b8",
    "test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl": "9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af",
}
PROTECTED = ["src/FusionConceptAI.jl", "test/runtime_v4_test_manifest.json", "README.md"]


def utc() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sweep() -> str:
    cmd = "Get-Process | Where-Object { $_.ProcessName -match 'julia|desc' } | Select-Object Id,ProcessName,Path | ConvertTo-Json -Compress"
    cp = subprocess.run(["powershell", "-NoProfile", "-Command", cmd], cwd=ROOT,
                        text=True, capture_output=True, encoding="utf-8", errors="replace")
    if cp.returncode != 0:
        raise RuntimeError(cp.stderr)
    return cp.stdout.strip()


def children(pid: int) -> list[dict]:
    cmd = ("Get-CimInstance Win32_Process | "
           f"Where-Object {{ $_.ParentProcessId -eq {pid} }} | "
           "Select-Object ProcessId,ParentProcessId,Name,CommandLine | ConvertTo-Json -Compress")
    cp = subprocess.run(["powershell", "-NoProfile", "-Command", cmd], cwd=ROOT,
                        text=True, capture_output=True, encoding="utf-8", errors="replace")
    if cp.returncode != 0 or not cp.stdout.strip():
        return []
    try:
        value = json.loads(cp.stdout)
    except json.JSONDecodeError:
        return []
    return value if isinstance(value, list) else [value]


def write_json(name: str, value) -> None:
    (OUT / name).write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    current = {p: digest(ROOT / p) for p in INPUTS}
    (OUT / "command.txt").write_text(" ".join(COMMAND) + "\n", encoding="utf-8")
    (OUT / "input_hashes.txt").write_text("".join(f"{current[p]}  {p}\n" for p in INPUTS), encoding="utf-8")
    (OUT / "dirty_status_before.txt").write_text(subprocess.run(
        ["git", "status", "--short", "--untracked-files=all"], cwd=ROOT,
        text=True, capture_output=True, encoding="utf-8", errors="replace").stdout, encoding="utf-8")
    before = {}
    for p in PROTECTED:
        f = ROOT / p
        before[p] = {"sha256": digest(f), "bytes": f.stat().st_size,
                     "mtime_utc": dt.datetime.fromtimestamp(f.stat().st_mtime, dt.timezone.utc).isoformat().replace("+00:00", "Z")}
    write_json("protected_before.json", before)
    pre = sweep()
    (OUT / "preflight_processes.json").write_text(pre + ("\n" if pre else ""), encoding="utf-8")
    if pre not in ("", "null", "{}", "[]"):
        raise RuntimeError(f"Julia/DESC process occupied before run: {pre}")
    if current != INPUTS:
        raise RuntimeError(json.dumps({"expected": INPUTS, "current": current}, indent=2))

    start = utc()
    (OUT / "start_time.txt").write_text(start + "\n", encoding="utf-8")
    out_path, err_path = OUT / "stdout.log", OUT / "stderr.log"
    snapshots = []
    with out_path.open("wb") as out, err_path.open("wb") as err:
        proc = subprocess.Popen(COMMAND, cwd=ROOT, stdout=out, stderr=err)
        pid = proc.pid
        (OUT / "main_pid.txt").write_text(str(pid) + "\n", encoding="utf-8")
        while proc.poll() is None:
            snapshots.append({"utc": utc(), "children": children(pid)})
            time.sleep(0.5)
        exit_code = proc.returncode
        snapshots.append({"utc": utc(), "children": children(pid)})
    end = utc()
    (OUT / "end_time.txt").write_text(end + "\n", encoding="utf-8")
    (OUT / "exit.txt").write_text(str(exit_code) + "\n", encoding="utf-8")
    (OUT / "process_snapshots.jsonl").write_text("".join(json.dumps(x, ensure_ascii=False) + "\n" for x in snapshots), encoding="utf-8")
    observed = sorted({c["ProcessId"] for s in snapshots for c in s["children"] if c.get("ProcessId") is not None})
    write_json("process.json", {"main_pid": pid, "child_pids_observed": observed, "snapshots": len(snapshots)})
    post = sweep()
    (OUT / "postflight_processes.json").write_text(post + ("\n" if post else ""), encoding="utf-8")
    after = {}
    for p in PROTECTED:
        f = ROOT / p
        after[p] = {"sha256": digest(f), "bytes": f.stat().st_size,
                    "mtime_utc": dt.datetime.fromtimestamp(f.stat().st_mtime, dt.timezone.utc).isoformat().replace("+00:00", "Z")}
    write_json("protected_after.json", after)
    (OUT / "dirty_status_after.txt").write_text(subprocess.run(
        ["git", "status", "--short", "--untracked-files=all"], cwd=ROOT,
        text=True, capture_output=True, encoding="utf-8", errors="replace").stdout, encoding="utf-8")

    out_bytes, err_bytes = out_path.read_bytes(), err_path.read_bytes()
    receipt = {
        "work_order": "UP2-00E-N06-SOURCE-FIELD-LEDGER", "attempt": "focused_r9",
        "command": " ".join(COMMAND), "cwd": str(ROOT), "main_pid": pid,
        "child_pids_observed": observed, "started_utc": start, "ended_utc": end,
        "real_exit": exit_code, "classification": "pass" if exit_code == 0 else "program_exception",
        "input_hashes_match": current == INPUTS,
        "stdout": {"path": "stdout.log", "bytes": len(out_bytes), "sha256": hashlib.sha256(out_bytes).hexdigest()},
        "stderr": {"path": "stderr.log", "bytes": len(err_bytes), "sha256": hashlib.sha256(err_bytes).hexdigest()},
        "postflight": post, "protected_before_after_match": before == after,
        "prior_failures_preserved": True, "no_retry_in_round": True,
        "compile_calls": 0, "provider_calls": 0, "solver_calls": 0,
        "physical": False, "provider": False, "engineering": False, "b00_b04": False,
    }
    write_json("receipt.json", receipt)
    text = out_bytes.decode("utf-8", errors="replace")
    summaries = [line for line in text.splitlines() if line.startswith("Test Summary:") or line.startswith("UP1-") or line.startswith("UP2-")]
    n06_group = [line for line in summaries if "N06" in line]
    mutation_marker = "UP2-00E N06 source-derived mutation controls"
    execution = {
        "n06_source_derived_mutation_group_present_in_stdout": mutation_marker in text,
        "n06_group_summary_lines": n06_group,
        "five_fixture_mutation_rows_in_frozen_test": "for row in _N06_FIXTURE.mutations" in (ROOT / "test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl").read_text(encoding="utf-8"),
        "raw_stdout_contains_n06_group": "UP2-00E N06" in text,
    }
    write_json("test_groups.json", {"summary_lines": summaries, "n06_execution": execution})
    qa = {
        "input_hashes_match": current == INPUTS, "real_exit": exit_code,
        "stdout_bytes": len(out_bytes), "stderr_bytes": len(err_bytes),
        "stdout_sha256": receipt["stdout"]["sha256"], "stderr_sha256": receipt["stderr"]["sha256"],
        "test_groups": summaries, "n06_execution": execution,
        "child_pids_observed": observed, "postflight_empty": post in ("", "null", "{}", "[]"),
        "protected_before_after_match": before == after, "no_retry": True,
        "claim_ceiling": "runtime contract evidence only; no physical/engineering/B04/R credit",
    }
    write_json("qa.json", qa)
    verdict = "runtime_pass_pending_independent" if exit_code == 0 else "runtime_failed"
    (OUT / "report.md").write_text(
        f"# N06 test-only focused R9\n\nVerdict: `{verdict}`. One serial frozen runner invocation was performed.\n\n"
        f"Input hashes matched. Main PID `{pid}`; UTC `{start}`–`{end}`; real exit `{exit_code}`. "
        f"Observed child PIDs `{observed}`. stdout/stderr bytes and SHA-256 are in `receipt.json`. "
        f"Postflight Julia/DESC sweep: `{post or 'empty'}`. Protected before/after SHA+mtime match: `{before == after}`.\n\n"
        f"N06 execution evidence is in `test_groups.json`; the raw stdout is authoritative for which groups reached execution. "
        "R1-R8 raw evidence remains immutable. No repair or retry was performed, and no physical/engineering/B04/R credit is granted.\n",
        encoding="utf-8")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
