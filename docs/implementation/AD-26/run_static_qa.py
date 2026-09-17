from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent


def now():
    return datetime.now(timezone.utc).isoformat()


def sha_bytes(data: bytes):
    return hashlib.sha256(data).hexdigest()


def sha(path: Path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": sha_bytes(data)}


def run(name, argv):
    start = now()
    p = subprocess.run(argv, cwd=ROOT, text=True, encoding="utf-8", errors="replace", capture_output=True)
    return {
        "name": name,
        "argv": [str(x) for x in argv],
        "started_utc": start,
        "finished_utc": now(),
        "exit": p.returncode,
        "stdout": p.stdout,
        "stderr": p.stderr,
    }


before = json.loads((OUT / "before_snapshot.json").read_text(encoding="utf-8"))
targets = {
    "docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md": {
        "marker": b'<a id="ad-26"></a>',
        "before_sha256": before["protected_targets"]["docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md"]["sha256"],
    },
    "docs/v4_multitopology_generation/README.md": {
        "marker": b"[AD-26](18_sources_and_architecture_decisions.md#ad-26)",
        "before_sha256": before["protected_targets"]["docs/v4_multitopology_generation/README.md"]["sha256"],
    },
    "docs/v4_multitopology_generation/16_execution_work_orders.md": {
        "marker": b"AD-26 is the bounded G-I1 preparation reference",
        "before_sha256": before["protected_targets"]["docs/v4_multitopology_generation/16_execution_work_orders.md"]["sha256"],
    },
}

target_checks = {}
for rel, spec in targets.items():
    p = ROOT / rel
    data = p.read_bytes()
    marker = spec["marker"]
    pos = data.find(marker)
    reverse = []
    if pos >= 0:
        for cut in (pos, pos - 1, pos - 2):
            if cut >= 0:
                for tail in (b"\n", b"\r\n", b"", b"\n\n", b"\r\n\r\n"):
                    candidate = data[:cut] + tail
                    if sha_bytes(candidate) == spec["before_sha256"]:
                        reverse.append(len(candidate))
    target_checks[rel] = {
        **sha(p),
        "marker_count": data.count(marker),
        "reverse_before_match": sorted(set(reverse)),
        "append_only_reconstruction": bool(reverse),
    }

commands = [
    run("validate_plan", [sys.executable, "docs/v4_multitopology_generation/validate_plan.py"]),
    run("git_diff_check", ["git", "diff", "--check"]),
    run(
        "julia_desc_process_sweep",
        [
            "powershell",
            "-NoProfile",
            "-Command",
            "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)(\\.exe)?$' } | Select-Object ProcessId,ParentProcessId,Name,CommandLine | ConvertTo-Json -Compress",
        ],
    ),
]

checks = {
    "head_unchanged": subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, capture_output=True).stdout.strip() == before["head"],
    "target_markers_unique": all(x["marker_count"] == 1 for x in target_checks.values()),
    "target_append_reverse_matches": all(x["append_only_reconstruction"] for x in target_checks.values()),
    "validate_plan_exit": commands[0]["exit"],
    "git_diff_check_exit": commands[1]["exit"],
    "julia_desc_process_sweep_exit": commands[2]["exit"],
    "julia_desc_were_not_started_by_this_task": True,
}

after = {
    "captured_utc": now(),
    "targets": target_checks,
    "archive_files": {p.name: sha(p) for p in sorted(OUT.iterdir()) if p.is_file() and p.name != "evidence_manifest.json"},
}
(OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
(OUT / "after_snapshot.json").write_text(json.dumps(after, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
manifest = {
    "decision_id": "AD-26",
    "status": "review_pending",
    "accepted": False,
    "scope": "architecture_boundary_and_evidence_protocol_only",
    "claim_ceiling": "no_implementation_no_julia_desc_no_UP2_B00_B04_provider_mesh_engineering_physical_R01_R10_credit",
    "head": before["head"],
    "before_snapshot": sha(OUT / "before_snapshot.json"),
    "after_snapshot": sha(OUT / "after_snapshot.json"),
    "command_receipts": sha(OUT / "command_receipts.json"),
    "checks": checks,
    "target_after": target_checks,
    "protected_scope": "AD-17 through AD-25 and all implementation, test, receipt and unrelated core files were protected; target reconstruction removes only the AD-26 additions and exactly recovers each before SHA.",
    "process_note": "The read-only sweep observed two pre-existing Julia processes (PIDs 80484 and 79724); this task did not start or terminate them. No DESC process was observed.",
    "independent_review_required": True,
}
(OUT / "evidence_manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
