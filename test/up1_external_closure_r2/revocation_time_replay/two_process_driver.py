"""Independent-process durable replay receipt driver (TEST_ONLY/non_evidence)."""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
CLI = ROOT / "tools" / "up1_external_closure_r2" / "revocation_time_replay" / "cli.py"
sys.path.insert(0, str(HERE))
from test_revocation_time_replay import fixture  # noqa: E402


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: two_process_driver.py LEDGER TRUSTED_KEY")
    ledger = str(Path(sys.argv[1]).resolve())
    key = str(Path(sys.argv[2]).resolve())
    raw = json.dumps(fixture(), ensure_ascii=False, separators=(",", ":"))
    input_hash = hashlib.sha256(raw.encode("utf-8")).hexdigest()
    started = dt.datetime.now(dt.timezone.utc).isoformat()
    parent = os.getpid()
    procs = [subprocess.Popen([sys.executable, "-B", str(CLI), "--ledger", ledger, "--key", key], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(2)]
    rows = []
    for proc in procs:
        stdout, stderr = proc.communicate(raw)
        try:
            parsed = json.loads(stdout)
        except json.JSONDecodeError:
            parsed = {"raw": stdout}
        ledger_info = parsed.get("replay_ledger", {}) if isinstance(parsed, dict) else {}
        rows.append({"pid": proc.pid, "parent_pid": parent, "started_utc": started, "ended_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "exit_code": proc.returncode, "stdout_sha256": hashlib.sha256(stdout.encode("utf-8")).hexdigest(), "stderr_sha256": hashlib.sha256(stderr.encode("utf-8")).hexdigest(), "result": parsed.get("result") if isinstance(parsed, dict) else None, "status": parsed.get("status") if isinstance(parsed, dict) else None, "error_code": parsed.get("error_code") if isinstance(parsed, dict) else None, "canonical_receipt_digest": parsed.get("canonical_receipt_digest") if isinstance(parsed, dict) else None, "ledger_state_hash": ledger_info.get("state_hash"), "ledger_auth_tag": ledger_info.get("auth_tag")})
    print(json.dumps({"schema": "UP1-R2.two-process-replay-receipt.v1", "TEST_ONLY": True, "non_evidence": True, "input_sha256": input_hash, "ledger_path": ledger, "processes": rows}, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return 0 if sorted(row["exit_code"] for row in rows) == [0, 2] else 1


if __name__ == "__main__":
    raise SystemExit(main())
