"""Read-only AD-27 provenance verifier.

It checks the current after bytes against the author-reported hashes, then
removes the exact byte splice used for each AD-27 append and compares the
reconstructed bytes with the before hashes in decision_manifest.json.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
MANIFEST = ROOT / "docs/implementation/AD-27/decision_manifest.json"

CASES = (
    {
        "name": "README",
        "path": ROOT / "docs/v4_multitopology_generation/README.md",
        "before_key": "readme_before",
        "marker": b"[AD-27]",
        "remove_start": 20300,
        "remove_end": 20977,
        "after_bytes": 20977,
        "after_sha256": "E208D32ED2FEBD635DD416DC221ECB01992B67F363287CAF8EE11485EE03D8C0",
    },
    {
        "name": "core16",
        "path": ROOT / "docs/v4_multitopology_generation/16_execution_work_orders.md",
        "before_key": "core16_before",
        "marker": b"AD-27 is `proposal`",
        "remove_start": 57674,
        "remove_end": 58472,
        "after_bytes": 58474,
        "after_sha256": "9C1DC8107FFB299F423084410B12E84A7EE58450DA7262C18BD34F0BD8B12C63",
    },
    {
        "name": "core18",
        "path": ROOT / "docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md",
        "before_key": "core18_before",
        "marker": b'<a id="ad-27"></a>',
        "remove_start": 40362,
        "remove_end": 43825,
        "after_bytes": 43825,
        "after_sha256": "9D5D32FEDA8320DB05BD2B9B7ECC3FCB5D82C0A832EC27D2A39222DA0960CEAD",
    },
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    before = manifest["protected_inputs"]
    rows = []
    ok = True
    for case in CASES:
        data = case["path"].read_bytes()
        marker_at = data.find(case["marker"])
        current_sha = sha(data)
        rebuilt = data[: case["remove_start"]] + data[case["remove_end"] :]
        before_sha = before[case["before_key"]].upper()
        row = {
            "name": case["name"],
            "path": str(case["path"].relative_to(ROOT)).replace("\\", "/"),
            "current_bytes": len(data),
            "current_sha256": current_sha,
            "expected_after_bytes": case["after_bytes"],
            "expected_after_sha256": case["after_sha256"],
            "marker_offset": marker_at,
            "splice_start": case["remove_start"],
            "splice_end_exclusive": case["remove_end"],
            "reconstructed_bytes": len(rebuilt),
            "reconstructed_sha256": sha(rebuilt),
            "expected_before_sha256": before_sha,
        }
        row_ok = (
            len(data) == case["after_bytes"]
            and current_sha == case["after_sha256"]
            and marker_at >= 0
            and 0 <= case["remove_start"] < case["remove_end"] <= len(data)
            and sha(rebuilt) == before_sha
        )
        row["pass"] = row_ok
        ok = ok and row_ok
        rows.append(row)
    print(json.dumps({"status": "pass" if ok else "changes_requested", "cases": rows}, indent=2))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
