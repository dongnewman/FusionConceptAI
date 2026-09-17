import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def check(condition, label, failures):
    if not condition:
        failures.append(label)

def main():
    failures = []
    entry = (ROOT / "src/GenomeV5/UP2/UP2ModuleEntryV1.jl").read_text(encoding="utf-8")
    fusion = (ROOT / "src/FusionConceptAI.jl").read_text(encoding="utf-8")
    integration = (ROOT / "src/GenomeV5/Integration/GenomeV5Integration.jl").read_text(encoding="utf-8")
    before = json.loads((OUT / "prewrite_snapshot.json").read_text(encoding="utf-8"))
    after = json.loads((OUT / "after_snapshot.json").read_text(encoding="utf-8"))
    protected = json.loads((OUT / "protected_dirty_hashes.json").read_text(encoding="utf-8"))
    check(after["head"] == "4b69f55f7f80240147a65a22809dc1207824dde2", "head", failures)
    check("include(\"GenomeV5/UP2/UP2ModuleEntryV1.jl\")" in fusion, "fusion include", failures)
    for token in ("load_genome_v5_up2_components!", "up2_module_load_state", "up2_module_dependency_order"):
        check(fusion.count(token) >= 1, f"fusion export {token}", failures)
    check(integration.count("genome_v5_component_layer_order()") >= 1, "integration order accessor", failures)
    order = [
        "load_genome_v5_components!()",
        "PrecompilerInvocationCounterV1.jl",
        "TypedPrecompilerContractV1.jl",
        "TypedPrecompilerValidatorV1.jl",
        "UP2CandidatePhysicalBindingV1.jl",
        "N03TimeAuthorityProjectionV1.jl",
        "N04LedgerAuthorityProjectionV1.jl",
        "N05FluxAuthorityProjectionV1.jl",
        "N06SourceFieldLedgerMappingV1.jl",
        "N07N08GeometryProjectionV1.jl",
        "N09ProviderGapProjectionV1.jl",
        "N10IdentityReceiptProjectionV1.jl",
    ]
    positions = [entry.index(x) for x in order]
    check(positions == sorted(positions), "dependency order", failures)
    check(entry.count("_UP2_MODULE_LOAD_STATE[] === :loaded && return nothing") == 1, "idempotence guard", failures)
    check("up2_provider!(" not in entry and "integrate_genome_v5" not in entry, "no execution call", failures)
    after_files = after["after_files"]
    for rel, expected in before["before_hashes_from_dispatch"].items():
        check(after_files[rel]["sha256"] != expected, f"after changed {rel}", failures)
    check(digest(ROOT / "src/FusionConceptAI.jl") == after_files["src/FusionConceptAI.jl"]["sha256"], "FusionConceptAI after hash", failures)
    check(digest(ROOT / "src/GenomeV5/Integration/GenomeV5Integration.jl") == after_files["src/GenomeV5/Integration/GenomeV5Integration.jl"]["sha256"], "integration after hash", failures)
    for item in protected["files"]:
        check(digest(ROOT / item["path"]) == item["sha256"], f"protected dirty {item['path']}", failures)
    for p in sorted(OUT.iterdir()):
        if p.is_file():
            text = p.read_text(encoding="utf-8")
            check(not any(ord(c) < 32 and ord(c) not in (9, 10, 13) for c in text), f"control {p.name}", failures)
    for p in (OUT / "prewrite_snapshot.json", OUT / "after_snapshot.json", OUT / "protected_dirty_hashes.json", OUT / "evidence_manifest.json"):
        try:
            json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            failures.append(f"json {p.name}")
    plan = subprocess.run(["python", "docs/v4_multitopology_generation/validate_plan.py"], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    diff = subprocess.run(["git", "diff", "--check"], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    proc = subprocess.run(["powershell", "-NoProfile", "-Command", "@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match 'julia|desc'} | Select-Object ProcessId,Name,CommandLine) | ConvertTo-Json -Depth 3"], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    raw = proc.stdout.strip() or "[]"
    try:
        processes = json.loads(raw)
    except json.JSONDecodeError:
        processes = {"raw": raw}
    result = {
        "work_order": "UP2-00G-I0-MODULE-SEAM",
        "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "checks": {
            "source_and_export_static": 0 if not failures else 1,
            "json_parse": 0 if not any(x.startswith("json ") for x in failures) else 1,
            "control_scan": 0 if not any(x.startswith("control ") for x in failures) else 1,
            "protected_after_hash": 0 if not any("after hash" in x for x in failures) else 1,
            "validate_plan_exit": plan.returncode,
            "git_diff_check_exit": diff.returncode,
            "process_sweep_exit": proc.returncode,
        },
        "process_sweep": processes,
        "failures": failures,
        "runtime": {"julia": "not run", "desc": "not run"},
        "note": "A non-empty process sweep records external activity and is not attributed to this work order; this QA did not start or stop processes.",
    }
    (OUT / "static_qa.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(1 if failures or plan.returncode or diff.returncode or proc.returncode else 0)

if __name__ == "__main__":
    main()
