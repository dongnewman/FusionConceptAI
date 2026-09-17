"""Check the R4 source-hash freeze without changing production or tests."""
from __future__ import annotations

import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve()
REPO = HERE.parents[5]
FREEZE = REPO / "docs" / "implementation" / "UP1-EXTERNAL-BLOCKER-CLOSURE-R4" / "06-predicate-independent-test" / "source_hash_freeze.json"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest().upper()


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def main() -> int:
    started = utc_now()
    freeze = json.loads(FREEZE.read_text(encoding="utf-8"))
    expected = freeze["after"]
    rows = []
    for rel, expected_hash in expected.items():
        path = REPO / rel
        actual = sha256(path)
        rows.append({"path": rel, "expected_sha256": expected_hash, "actual_sha256": actual, "match": actual == expected_hash})
    production = [row for row in rows if row["path"].startswith("tools/")]
    checks = {
        "all_after_hashes_match": all(row["match"] for row in rows),
        "production_tools_changed": freeze.get("production_tools_changed") is False and all(row["match"] for row in production),
        "all_frozen_paths_exist": all((REPO / row["path"]).is_file() for row in rows),
    }
    status = "pass_limited" if all(checks.values()) else "fail_limited"
    print(json.dumps({
        "schema": "UP1-R4.predicate-independent-review-r1.source-freeze-audit.v1",
        "status": status,
        "run": {"pid": os.getpid(), "started_utc": started, "finished_utc": utc_now(), "exit_code": 0 if status == "pass_limited" else 1},
        "checks": checks,
        "rows": rows,
        "note": "Current hashes are compared with the frozen after-set; the recorded before/after vector-test delta is test-only and production_tools_changed remains false.",
    }, sort_keys=True, separators=(",", ":")))
    return 0 if status == "pass_limited" else 1


if __name__ == "__main__":
    raise SystemExit(main())
