import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent

EXPECTED = {
    "src/GenomeV5/UP2/UP2ModuleEntryV1.jl": "7eb7ed593fbac217ea925830e53b675a38760aed708c7864bd43c436f74d8937",
    "test/GenomeV5/UP2/up2_module_entry_tests.jl": "3d595b399f8e9681881f61fa2e25590dd6646986385af72021a33672c96b4cb5",
    "test/GenomeV5/UP2/run_up2_module_entry.jl": "db1fd47e395d748ffed5205c1ed00be87a1dc63d684ce85e792b6f44632598d2",
    "test/GenomeV5/UP2/up2_module_entry_failure_probe.jl": "59204f1b24d6c03c1a6097e748c42808d06858a6197f49254c6ff28580c21591",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    failures = []
    hashes = {p: sha(ROOT / p) for p in EXPECTED}
    for p, value in EXPECTED.items():
        if hashes[p] != value:
            failures.append(f"hash:{p}")

    runner = (ROOT / "test/GenomeV5/UP2/run_up2_module_entry.jl").read_text(encoding="utf-8")
    probe = (ROOT / "test/GenomeV5/UP2/up2_module_entry_failure_probe.jl").read_text(encoding="utf-8")
    required_runner = (
        "PrecompilerInvocationCounterV1.jl",
        "_MANUAL_COUNTER_TYPE",
        "up2_module_entry_failure_probe.jl",
        "load_genome_v5_up2_components!()",
    )
    required_probe = (
        "(:G1, :G2, :G3)",
        "load_genome_v5_components!() = nothing",
        "UP2InvocationCounterV1",
        "up2_module_load_state() == :failed",
        "previously failed",
    )
    for token in required_runner:
        if token not in runner:
            failures.append(f"runner:{token}")
    for token in required_probe:
        if token not in probe:
            failures.append(f"probe:{token}")
    entry = (ROOT / "src/GenomeV5/UP2/UP2ModuleEntryV1.jl").read_text(encoding="utf-8")
    if "up2_provider!(" in entry or "integrate_genome_v5" in entry:
        failures.append("entry:execution-call")

    json_files = list(OUT.glob("*.json"))
    for path in json_files:
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            failures.append(f"json:{path.name}")

    bad_controls = []
    for path in [ROOT / p for p in EXPECTED] + [OUT / "acceptance.md", OUT / "evidence_manifest.json", OUT / "repair_r2.md"]:
        for line_number, line in enumerate(path.read_text(encoding="utf-8"), 1):
            if ord(line) < 32 and ord(line) not in (9, 10, 13):
                bad_controls.append((str(path), line_number, ord(line)))
    if bad_controls:
        failures.append("control-characters")

    protected = json.loads((OUT / "protected_dirty_hashes.json").read_text(encoding="utf-8"))
    protected_mismatches = [
        item["path"] for item in protected["files"]
        if sha(ROOT / item["path"]) != item["sha256"]
    ]
    if protected_mismatches:
        failures.append("protected-dirty-hash")

    plan = subprocess.run(["python", "docs/v4_multitopology_generation/validate_plan.py"], cwd=ROOT)
    diff = subprocess.run(["git", "diff", "--check"], cwd=ROOT)
    process = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match '^(julia|desc)(\\.exe)?$'}) | ConvertTo-Json -Depth 3"],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    raw = process.stdout.strip()
    try:
        processes = json.loads(raw) if raw else []
    except json.JSONDecodeError:
        processes = {"raw": raw}
    if isinstance(processes, dict):
        process_count = 1
    else:
        process_count = len(processes)
    result = {
        "work_order": "UP2-00G-I0-MODULE-SEAM",
        "repair": "R2",
        "checks": {
            "frozen_hashes": 0 if not any(x.startswith("hash:") for x in failures) else 1,
            "behavior_tokens": 0 if not any(x.startswith(("runner:", "probe:")) for x in failures) else 1,
            "entry_no_execution_call": 0 if not any(x.startswith("entry:") for x in failures) else 1,
            "json_parse": 0 if not any(x.startswith("json:") for x in failures) else 1,
            "control_scan": 0 if "control-characters" not in failures else 1,
            "protected_dirty_hashes": 0 if "protected-dirty-hash" not in failures else 1,
            "validate_plan_exit": plan.returncode,
            "git_diff_check_exit": diff.returncode,
            "process_sweep_exit": process.returncode,
        },
        "hashes": hashes,
        "protected_mismatches": protected_mismatches,
        "process_sweep": {"count": process_count, "raw": processes},
        "runtime": {"julia": "not_run", "desc": "not_run"},
        "failures": failures,
        "claim_ceiling": "wiring_contract_only",
        "note": "A nonempty process sweep is external activity; this repair did not start or stop processes.",
    }
    (OUT / "repair_r2_qa.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(1 if failures or plan.returncode or diff.returncode else 0)


if __name__ == "__main__":
    main()
