"""Independent oracle for the two R4 intake-boundary repairs.

This probe is evidence-only: it imports the frozen implementation, uses a
private temporary directory, and never sends bytes or writes outside it.
"""
from __future__ import annotations

import hashlib
import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
import sys

sys.path.insert(0, str(ROOT))

from tools.up1_external_closure_r4.authoritative_intake import IntakeError, atomic_quarantine
from tools.up1_external_closure_r4.authoritative_intake import intake as intake_impl


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def main() -> int:
    rows: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory(prefix="up1-r4-repair-") as td:
        root = Path(td)

        raw = b'{"packet_id":"EHP-01","value":"hardlink-repair"}'
        hard_root = root / "hardlink"
        source = hard_root / "outside.bin"
        target = hard_root / "quarantine" / f"{sha256(raw)}.bin"
        target.parent.mkdir(parents=True)
        source.write_bytes(raw)
        try:
            os.link(source, target)
        except (OSError, NotImplementedError) as exc:
            rows.append({"name": "hardlink_rejected", "pass": "SKIP", "observed": "hardlink_unavailable", "expected": "immutable_alias", "reason": str(exc)})
        else:
            try:
                atomic_quarantine(raw, hard_root)
                observed = "accepted"
            except IntakeError as exc:
                observed = exc.code
            rows.append({
                "name": "hardlink_rejected",
                "pass": observed == "immutable_alias",
                "observed": observed,
                "expected": "immutable_alias",
                "samefile_after": os.path.samefile(source, target),
                "target_bytes_unchanged": target.read_bytes() == raw,
            })

        traversal_parent = root / "traversal"
        spool = traversal_parent / "spool"
        spool.mkdir(parents=True)
        escaped = spool / ".." / "escape"
        escaped_sibling = traversal_parent / "escape"
        before_exists = escaped_sibling.exists()
        try:
            intake_impl._ensure_regular_parent(escaped, spool)
            observed = "accepted"
        except IntakeError as exc:
            observed = exc.code
        rows.append({
            "name": "root_parent_escape_rejected_before_mkdir",
            "pass": observed == "path_escape" and not escaped_sibling.exists() and not before_exists,
            "observed": observed,
            "expected": "path_escape",
            "outside_created": escaped_sibling.exists(),
            "spool_children": sorted(p.name for p in spool.iterdir()),
        })

    output = {
        "schema": "UP1.authoritative-intake-r4.repair-boundary-probe.v1",
        "pid": os.getpid(),
        "utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "records": rows,
        "pass_count": sum(row["pass"] is True for row in rows),
        "skip_count": sum(row["pass"] == "SKIP" for row in rows),
        "record_count": len(rows),
    }
    print(json.dumps(output, ensure_ascii=True, sort_keys=True, indent=2))
    return 0 if output["pass_count"] == output["record_count"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
