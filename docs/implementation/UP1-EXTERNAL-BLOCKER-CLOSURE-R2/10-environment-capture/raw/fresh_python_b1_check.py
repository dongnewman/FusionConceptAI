"""Fresh Python -B self-check for the repaired environment receipt."""
from __future__ import annotations

import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "raw"


def utc() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    started = utc()
    pid = os.getpid()
    machine = json.loads((ROOT / "machine_observation.json").read_text(encoding="utf-8"))
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    cleanup = json.loads((ROOT / "cleanup_inventory.json").read_text(encoding="utf-8"))
    raw_path = RAW / "git_diff_binary.stdout.raw"
    raw_sha = sha(raw_path)
    declared = set(manifest["exact_file_set"])
    actual_without_manifest = {
        p.relative_to(ROOT).as_posix()
        for p in ROOT.rglob("*")
        if p.is_file() and p.name != "manifest.json"
    }
    checks = {
        "json_inputs_parse": True,
        "dirty_patch_exact_raw_sha256": machine["git"]["dirty_patch_sha256"] == raw_sha,
        "dirty_patch_digest_declares_no_normalization": machine["git"]["dirty_patch_digest"]["normalization"] == "none" and machine["git"]["dirty_patch_digest"]["normalized_sha256"] is None,
        "manifest_source_digest_matches": manifest["source_observation"]["dirty_patch_sha256"] == raw_sha,
        "manifest_exact_set_matches_current_except_manifest": declared == actual_without_manifest,
        "manifest_artifact_hashes_match": all(
            isinstance(v, str) and sha(ROOT / Path(k)) == v
            for k, v in manifest["artifact_sha256"].items()
        ),
        "all_captured_commands_have_pid_and_zero_exit": all(
            r.get("pid") and r.get("exit_code") == 0 for r in machine["command_records"]
        ),
        "historical_inconsistent_digest_preserved": any(
            x.get("recorded_sha256") == "e6b42d07d326be263a19509faddeece612f0e42495b8980de0e55f60f282fb99"
            and x.get("raw_and_fresh_sha256") == raw_sha
            for x in machine.get("historical_failures", [])
        ),
        "cleanup_self_hash_excluded": cleanup.get("self_hash_excluded") is True,
    }
    status = "pass" if all(checks.values()) else "fail"
    ended = utc()
    result = {
        "schema": "UP1.R2.fresh-python-b1-self-check.v1",
        "task_id": machine["task_id"],
        "pid": pid,
        "started_utc": started,
        "ended_utc": ended,
        "exit_code": 0 if status == "pass" else 1,
        "status": status,
        "checks": checks,
        "raw_git_diff_sha256": raw_sha,
        "failure": None if status == "pass" else "one or more self-checks failed",
    }
    text = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    stdout_path = RAW / "fresh_python_b1_check.stdout.raw"
    stderr_path = RAW / "fresh_python_b1_check.stderr.raw"
    combined_path = RAW / "fresh_python_b1_check.combined.raw"
    stdout_path.write_text(text, encoding="utf-8", newline="\n")
    stderr_path.write_text("", encoding="utf-8", newline="\n")
    combined_path.write_text(text, encoding="utf-8", newline="\n")
    result["stdout_sha256"] = sha(stdout_path)
    result["stderr_sha256"] = sha(stderr_path)
    result["combined_sha256"] = sha(combined_path)
    (RAW / "fresh_python_b1_check.receipt.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n"
    )
    print(text, end="")
    return result["exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())
