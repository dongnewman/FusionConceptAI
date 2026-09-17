"""Read-only targeted diagnosis for the preserved W3 R2 validator failure."""
from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[3]


def h(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def check(label, fn, observed):
    try:
        value = fn()
    except Exception as exc:
        observed.append({"label": label, "status": "assertion_failure", "error": f"{type(exc).__name__}:{exc}"})
    else:
        observed.append({"label": label, "status": "pass", "value": value})


def main():
    observed = []
    src = json.loads((ROOT / "source_four_axis_binding.json").read_text(encoding="utf-8"))
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    snap = src["source_snapshot"]
    check("snapshot.frozen_dirty_status_sha256_length", lambda: len(snap["frozen_dirty_status_sha256"]), observed)
    check("snapshot.frozen_dirty_status_sha256_hex", lambda: bool(len(snap["frozen_dirty_status_sha256"]) == 64 and all(c in "0123456789abcdef" for c in snap["frozen_dirty_status_sha256"])), observed)
    check("snapshot.source_manifest_observed_status", lambda: snap["dirty_status_sha256"] == manifest["source_snapshot"]["observed_dirty_status_sha256"], observed)
    check("snapshot.source_manifest_observed_patch", lambda: snap["dirty_patch_sha256"] == manifest["source_snapshot"]["observed_dirty_patch_sha256"], observed)
    current_status = h(subprocess.check_output(["git", "status", "--short"], cwd=REPO))
    current_patch = h(subprocess.check_output(["git", "diff", "--binary", "--"], cwd=REPO))
    check("snapshot.current_status_matches_frozen_observed", lambda: current_status == snap["dirty_status_sha256"], observed)
    check("snapshot.current_patch_matches_frozen_observed", lambda: current_patch == snap["dirty_patch_sha256"], observed)
    check("snapshot.current_status", lambda: current_status, observed)
    check("snapshot.frozen_status", lambda: snap["dirty_status_sha256"], observed)
    check("snapshot.current_patch", lambda: current_patch, observed)
    check("snapshot.frozen_patch", lambda: snap["dirty_patch_sha256"], observed)
    print(json.dumps({"status": "diagnostic_complete", "current_status_sha256": current_status, "current_patch_sha256": current_patch, "observations": observed}, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
