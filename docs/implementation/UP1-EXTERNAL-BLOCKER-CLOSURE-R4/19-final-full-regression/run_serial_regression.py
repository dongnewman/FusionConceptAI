"""Capture the final UP1 R4 offline regression as immutable raw evidence."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / "docs" / "implementation" / "UP1-EXTERNAL-BLOCKER-CLOSURE-R4" / "19-final-full-regression"
RAW = OUT / "raw"
SCOPE = [
    ROOT / "tools" / "up1_external_closure_r3" / "atomic_bundle",
    ROOT / "test" / "up1_external_closure_r3" / "atomic_bundle",
    ROOT / "tools" / "up1_external_closure_r4",
    ROOT / "test" / "up1_external_closure_r4",
]


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def source_files() -> list[Path]:
    return sorted(p for root in SCOPE for p in root.rglob("*.py") if "__pycache__" not in p.parts)


def freeze(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    return {"path": str(path.relative_to(ROOT)).replace("\\", "/"), "bytes": len(data), "sha256": sha256_bytes(data)}


def freeze_all() -> list[dict[str, object]]:
    return [freeze(path) for path in source_files()]


def parse_counts(kind: str, stdout: str, stderr: str) -> dict[str, object]:
    combined = stdout + "\n" + stderr
    if kind == "r3_atomic":
        match = re.search(r"Ran (\d+) tests? .*?OK(?: \(skipped=(\d+)\))?", combined, re.S)
        return {
            "tests": int(match.group(1)) if match else None,
            "skipped": int(match.group(2) or 0) if match else None,
            "xfailed": 0,
            "xpassed": 0,
        }
    match = re.search(
        r"(?:(\d+) passed)?(?:, )?(?:(\d+) skipped)?(?:, )?(?:(\d+) xfailed)?(?:, )?(?:(\d+) xpassed)? in ",
        combined,
    )
    return {
        "tests": sum(int(x or 0) for x in match.groups()) if match else None,
        "passed": int(match.group(1) or 0) if match else None,
        "skipped": int(match.group(2) or 0) if match else 0,
        "xfailed": int(match.group(3) or 0) if match else 0,
        "xpassed": int(match.group(4) or 0) if match else 0,
    }


def run_one(label: str, index: int, command: list[str]) -> dict[str, object]:
    started = utc_now()
    proc = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    finished = utc_now()
    prefix = f"{label}_{index}"
    combined = stdout + stderr
    (RAW / f"{prefix}.stdout.raw.txt").write_bytes(stdout)
    (RAW / f"{prefix}.stderr.raw.txt").write_bytes(stderr)
    (RAW / f"{prefix}.combined.raw.txt").write_bytes(combined)
    (RAW / f"{prefix}.pid.txt").write_text(f"{proc.pid}\n", encoding="utf-8")
    (RAW / f"{prefix}.utc.txt").write_text(f"started={started}\nfinished={finished}\n", encoding="utf-8")
    (RAW / f"{prefix}.exit.txt").write_text(f"{proc.returncode}\n", encoding="utf-8")
    row = {
        "kind": label,
        "run": index,
        "pid": proc.pid,
        "started_utc": started,
        "finished_utc": finished,
        "exit": proc.returncode,
        "command": command,
        "stdout_bytes": len(stdout),
        "stderr_bytes": len(stderr),
        "stdout_sha256": sha256_bytes(stdout),
        "stderr_sha256": sha256_bytes(stderr),
        "combined_sha256": sha256_bytes(combined),
        "counts": parse_counts(label, stdout.decode("utf-8", "replace"), stderr.decode("utf-8", "replace")),
    }
    return row


def main() -> int:
    RAW.mkdir(parents=True, exist_ok=True)
    before = freeze_all()
    r3 = [sys.executable, "-B", "-m", "unittest", "discover", "-s", "test/up1_external_closure_r3/atomic_bundle", "-p", "test_*.py"]
    r4 = [sys.executable, "-B", "-m", "pytest", "test/up1_external_closure_r4", "-q"]
    static = [sys.executable, "-B", "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/19-final-full-regression/static_check.py"]
    rows = [run_one("r3_atomic", 1, r3), run_one("r3_atomic", 2, r3), run_one("r4_full", 1, r4), run_one("r4_full", 2, r4), run_one("static_import_compile", 1, static)]
    after = freeze_all()
    before_map = {row["path"]: row for row in before}
    after_map = {row["path"]: row for row in after}
    changed = sorted(path for path in before_map.keys() & after_map.keys() if before_map[path] != after_map[path])
    comparison = {
        "schema": "UP1.external-closure-r4.final-full-regression.hash-comparison.v1",
        "checked_utc": utc_now(),
        "before_count": len(before),
        "after_count": len(after),
        "unchanged": before_map == after_map,
        "changed": changed,
        "missing": sorted(before_map.keys() - after_map.keys()),
        "added": sorted(after_map.keys() - before_map.keys()),
    }
    (OUT / "before_hash.json").write_text(json.dumps({"schema": "UP1.external-closure-r4.final-full-regression.freeze.v1", "checked_utc": utc_now(), "files": before}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (OUT / "after_hash.json").write_text(json.dumps({"schema": "UP1.external-closure-r4.final-full-regression.after-freeze.v1", "checked_utc": utc_now(), "files": after}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (OUT / "hash_comparison.json").write_text(json.dumps(comparison, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    manifest = {
        "schema": "UP1.external-closure-r4.final-full-regression.manifest.v1",
        "cwd": str(ROOT),
        "scope": "offline local software regression only; R3 atomic focused and entire R4 test tree; no network, no Julia/DESC, no T0/S3, no heavy lane",
        "frozen_sets": [str(path.relative_to(ROOT)).replace("\\", "/") for path in SCOPE],
        "file_count": len(before),
        "commands": {"r3_atomic": r3, "r4_full": r4, "static": static},
        "records": rows,
        "hash_comparison": "hash_comparison.json",
        "verdict": "software_pass_limited" if comparison["unchanged"] and all(row["exit"] == 0 for row in rows) else "software_fail_limited",
        "authority": "external_authority_fail_limited",
        "network": False,
        "heavy_lane": False,
        "t0_executed": False,
        "s3_executed": False,
        "julia_executed": False,
        "desc_executed": False,
    }
    (OUT / "run_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(manifest, sort_keys=True, separators=(",", ":")))
    return 0 if manifest["verdict"] == "software_pass_limited" else 1


if __name__ == "__main__":
    raise SystemExit(main())
