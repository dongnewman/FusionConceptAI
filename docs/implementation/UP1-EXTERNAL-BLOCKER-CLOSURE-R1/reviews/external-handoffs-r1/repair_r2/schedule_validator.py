from __future__ import annotations
import hashlib, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROUTE = ["T0", "authority_recheck", "T1", "T2", "aggregate", "UP2-00", "UP1-04B", "UP1-04", "UP2-01"]

def pairs(items):
    out = {}
    for key, value in items:
        if key in out:
            raise ValueError(f"duplicate_key:{key}")
        out[key] = value
    return out

def load(path):
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=pairs)

def main():
    schedule = load(ROOT / "conditional_schedule.json")
    assert schedule["route"] == ROUTE
    assert schedule["calendar_dates"] == "not_assigned"
    stages = schedule["stages"]
    assert [x["stage"] for x in stages] == ROUTE
    for i, stage in enumerate(stages):
        assert stage["requires"] and stage["failure_transition"]
        expected = ROUTE[i + 1] if i + 1 < len(ROUTE) else "parent_architect_acceptance_decision_only"
        assert stage["success_transition"] == expected
    packets = load(ROOT / "request_packets.json")
    assert packets["not_sent"] is True and packets["external_mutation"] is False and packets["new_ad"] is False
    assert len(packets["packets"]) == 4
    assert all(p["original_absence_ids"] and p["required_fields"] and p["reject_if"] and p["recovery_trigger"] for p in packets["packets"])
    files = sorted(x.relative_to(ROOT).as_posix() for x in ROOT.rglob("*") if x.is_file())
    manifest = load(ROOT / "manifest.json")
    assert files == sorted(manifest["exact_set"])
    cleanup = load(ROOT / "cleanup_inventory.json")
    amap = cleanup["current_artifact_hash_map"]
    dynamic = {name for name in files if name.startswith("repair_r2/raw/schedule_validator")}
    assert set(amap) == set(files) - {"manifest.json", "cleanup_inventory.json"} - dynamic
    for name, digest in amap.items():
        if name.startswith("repair_r2/raw/schedule_validator"):
            continue
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest
    print(json.dumps({"status":"pass","route":ROUTE,"adjacent_transitions":len(ROUTE)-1,"packet_count":4,"exact_file_count":len(files),"non_self_hash_count":len(amap),"not_sent":True,"formal_credit":False}, separators=(",", ":")))

if __name__ == "__main__":
    main()
