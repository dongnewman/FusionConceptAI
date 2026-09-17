"""Generate the R7 clean text/hash erratum from immutable R5/R6 evidence."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / "docs" / "implementation" / "UP2-00G-I1B-SOURCE-ENVELOPE"
OUT = Path(__file__).resolve().parent


def digest(path: Path) -> tuple[int, str]:
    data = path.read_bytes()
    return len(data), hashlib.sha256(data).hexdigest()


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


owner = read_json(BASE / "evidence_manifest.json")
r6 = read_json(BASE / "postrun_erratum_r6" / "evidence_manifest.json")
focused_hashes = read_json(BASE / "focused_r5" / "output_hashes.json")
focused_command = read_json(BASE / "focused_r5" / "command_receipts.json")
focused_report = read_json(BASE / "focused_r5" / "report.json")
postrun_report = read_json(BASE / "independent_postrun_r5" / "report.json")
postrun_manifest = read_json(BASE / "independent_postrun_r5" / "evidence_manifest.json")

stdout_bytes, stdout_sha = digest(BASE / "focused_r5" / "stdout.txt")
stderr_bytes, stderr_sha = digest(BASE / "focused_r5" / "stderr.txt")
correct_empty_sha = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
assert (stdout_bytes, stdout_sha) == (2806, "22f5b6723c74b3b502100cba753a9b567c09896722f3373ae28d45b579976121")
assert (stderr_bytes, stderr_sha) == (0, correct_empty_sha)

focused_receipt_values = {
    "output_hashes.json": next(item["sha256"] for item in focused_hashes if item["path"] == "stderr.txt"),
    "command_receipts.json": focused_command["raw_outputs"]["stderr"]["sha256"],
    "report.json": focused_report["raw_outputs"]["stderr"]["sha256"],
}
assert all(value == correct_empty_sha and len(value) == 64 for value in focused_receipt_values.values())

postrun_old_values = {
    "report.json": postrun_report["raw_outputs"]["stderr"]["sha256"],
    "evidence_manifest.json": postrun_manifest["raw_output_hashes"]["stderr"]["sha256"],
}
assert all(len(value) == 62 and value != correct_empty_sha for value in postrun_old_values.values())
assert r6["correct_replacement"]["value"] == correct_empty_sha
assert r6["correct_replacement"]["bytes"] == 0

old_r4 = postrun_manifest["old_focused_r4"]
old_r4_summary = postrun_report["focused_r4"]
for name, field in (("stdout.txt", "stdout_sha256"), ("stderr.txt", "stderr_sha256")):
    _, actual = digest(BASE / "focused_r4" / name)
    assert actual == old_r4[field]
assert old_r4["exit_code"] == 1 and old_r4["overwritten"] is False

protected = {}
for relative, record in owner["protected_inputs"].items():
    size, sha = digest(ROOT / relative)
    assert size == record["bytes"] and sha == record["sha256"]
    protected[relative] = {"bytes": size, "sha256": sha}

assert owner["status"] == "review_pending" and owner["accepted"] is False
assert owner["focused_r5"]["assertions"] == "2653/2653"

report = f"""# GI1B focused R5 postrun hash erratum R7

Verdict: `review_pending`; `accepted=false`.

R7 is an additive clean-text correction for the R6 evidence record. R6 JSON
and all older files remain immutable. No Julia or DESC command was run while
producing this record.

## Direct raw receipt values

The values below were read from the preserved raw bytes and calculated with
SHA-256:

| file | bytes | SHA-256 |
|---|---:|---|
| `focused_r5/stdout.txt` | {stdout_bytes} | `{stdout_sha}` |
| `focused_r5/stderr.txt` | {stderr_bytes} | `{stderr_sha}` |

The three focused-R5 structured receipts (`output_hashes.json`,
`command_receipts.json`, and `report.json`) already contain the same correct
64-character stderr SHA. The independent postrun-R5 `report.json` and
`evidence_manifest.json` retain the historical 62-character value
`e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`; those old
fields are preserved as the discrepancy that R6 addressed.

R6's structured replacement field records the correct value
`{r6["correct_replacement"]["value"]}` and `{r6["correct_replacement"]["bytes"]}` bytes.
R6's original report and JSON are not overwritten by R7.

## Frozen focused facts and scope

Focused R5 remains PID `14796`, exit `0`, with `2653/2653` assertions. The
four protected input hashes and byte counts remain unchanged. Focused R4's
historical exit `1`, `2051/2052` result, and raw evidence remain preserved;
that failure is not replaced by R5.

The owner acceptance remains `review_pending=true`, `accepted=false`. The
bounded claim is actual-A source-envelope software behavior only. It grants
no N06 actual authority, UP2 total, B00/B04, provider, mesh, solver,
physical, engineering, current-A, or R01-R10 credit. The local fixture stays
oracle-only and no mesh declaration is promoted to mesh execution.

R7 generated this UTF-8 report from raw bytes and structured JSON. It contains
no control characters, shell placeholders, or unexpanded length expressions.
"""
assert all(ord(char) >= 32 or char in "\n\r\t" for char in report)
assert "$stdoutHash" not in report and "$stderrHash" not in report
assert "$(" not in report
(OUT / "report.md").write_text(report, encoding="utf-8", newline="\n")

manifest = {
    "record_kind": "GI1B-postrun-erratum-r7",
    "schema_version": "GI1B-postrun-erratum-r7-v1",
    "status": "review_pending",
    "accepted": False,
    "frozen_head": owner["frozen_head"],
    "source_scope": "clean UTF-8 text correction generated from immutable raw R5/R6 evidence",
    "direct_raw": {
        "stdout": {"bytes": stdout_bytes, "sha256": stdout_sha},
        "stderr": {"bytes": stderr_bytes, "sha256": stderr_sha},
    },
    "focused_r5": {
        "pid": 14796,
        "exit_code": 0,
        "assertions": "2653/2653",
        "structured_receipts": focused_receipt_values,
        "structured_receipt_hash_length": 64,
    },
    "independent_postrun_r5_historical_fields": {
        "values": postrun_old_values,
        "length": 62,
        "preserved": True,
    },
    "r6_replacement": {
        "sha256": r6["correct_replacement"]["value"],
        "bytes": r6["correct_replacement"]["bytes"],
        "r6_report_untouched": True,
        "r6_json_untouched": True,
        "r6_archive_outputs": r6["archive_outputs"],
    },
    "focused_r4": {
        "exit_code": old_r4["exit_code"],
        "assertions": old_r4_summary["gi1b_pass"],
        "overwritten": old_r4["overwritten"],
    },
    "protected_inputs": protected,
    "owner_state": {"status": "review_pending", "accepted": False},
    "claim_ceiling": [
        "actual_A_source_envelope_software_only",
        "no_N06_actual_authority",
        "no_UP2_total",
        "no_B00",
        "no_B04",
        "no_provider",
        "no_mesh_execution",
        "no_physical",
        "no_engineering",
        "no_R01_R10",
    ],
    "text_validation": {"utf8": True, "control_chars": False, "unexpanded_placeholders": False},
}
(OUT / "evidence_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")

generator_size, generator_sha = digest(Path(__file__))
report_size, report_sha = digest(OUT / "report.md")
manifest_size, manifest_sha = digest(OUT / "evidence_manifest.json")
receipts = {
    "record_kind": "GI1B-postrun-erratum-r7-command-receipts",
    "status": "review_pending",
    "accepted": False,
    "generator": {"path": "generate_r7.py", "bytes": generator_size, "sha256": generator_sha, "exit_code": 0},
    "operations": [
        {"operation": "raw-byte SHA-256 extraction", "result": "stdout/stderr direct values recorded", "exit_code": 0},
        {"operation": "structured receipt cross-check", "result": "focused three correct; postrun two old 62-character fields preserved", "exit_code": 0},
        {"operation": "R6 replacement cross-check", "result": "correct 64-character empty-stderr value extracted from R6 JSON", "exit_code": 0},
        {"operation": "clean UTF-8 report validation", "result": "no control characters or unexpanded placeholders", "exit_code": 0},
        {"operation": "execution boundary", "result": "no Julia/DESC command", "exit_code": 0},
    ],
    "outputs": {
        "report_md": {"bytes": report_size, "sha256": report_sha},
        "evidence_manifest_json": {"bytes": manifest_size, "sha256": manifest_sha},
    },
    "scope_protection": {"r6_untouched": True, "old_evidence_untouched": True, "source_test_fixture_untouched": True},
}
(OUT / "command_receipts.json").write_text(json.dumps(receipts, indent=2) + "\n", encoding="utf-8", newline="\n")
print("r7_generation=pass")
print(f"stdout_bytes={stdout_bytes} stdout_sha256={stdout_sha}")
print(f"stderr_bytes={stderr_bytes} stderr_sha256={stderr_sha}")
print("focused_r5=PID14796 exit0 2653/2653")
print("old_postrun_fields=62_char_preserved")
print("clean_utf8_report=pass")
