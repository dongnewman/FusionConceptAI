from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_R3 = "ffa2a9958151d1112b37ab0588a60fa08182bb3441aff307323a9a41aab22ac0"


def load(rel: str):
    return json.loads((ROOT / rel).read_text(encoding="utf-8"))


def digest(rel: str) -> str:
    return hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()


def main() -> None:
    top = load("validation_receipt.json")
    patch = load("archive/repair_r5/repair_patch.json")
    candidates = [
        "validation_receipt.json",
        "manifest.json",
        "source_closure.json",
        "external_inputs.json",
        "archive/repair_r2/repair_receipt.json",
        "archive/repair_r3/corrected_static_measurement_receipt.json",
        "archive/repair_r3/validation_receipt.json",
        "archive/repair_r4/repair_receipt.json",
        "archive/repair_r4/cleanup_inventory.json",
        "archive/repair_r5/repair_patch.json",
    ]
    for rel in candidates:
        load(rel)
    assert patch["before"] != patch["after"]
    assert top["artifact_hashes"]["corrected_static_measurement_receipt"]["sha256"] == EXPECTED_R3
    assert digest("archive/repair_r3/corrected_static_measurement_receipt.json") == EXPECTED_R3
    assert top["static_closure"]["count_vector"] == [4, 5, 12, 1, 47, 0]
    assert top["input_hashes"]["input_fingerprint"] == "840922caac204df3d66ce3419868390c2fda8e79c3792cc4e074af2887edd9a5"
    assert top["scientific_result"] == {"branch":"blocked_external_trust_root_and_source_closure","g1":"typed_absent","g2":"typed_absent","g3":"typed_absent","resolution":"terminal_deferred","no_publish":True}
    rows = []
    for key, entry in top["artifact_hashes"].items():
        if not isinstance(entry, dict) or "path" not in entry or "sha256" not in entry:
            continue
        actual = digest(entry["path"])
        assert actual == entry["sha256"], (key, entry, actual)
        rows.append({"json_path":f"validation_receipt.json:artifact_hashes.{key}.sha256","file":entry["path"],"value":entry["sha256"],"length":len(entry["sha256"])})
    raw_specs = [
        ("validation_receipt.json:repaired_raw.stderr.sha256", "archive/repair_r2/raw/fresh_s3_recheck.stderr.raw", top["repaired_raw"]["stderr"]["sha256"]),
        ("archive/repair_r2/repair_receipt.json:raw_bytes.stderr.sha256", "archive/repair_r2/raw/fresh_s3_recheck.stderr.raw", load("archive/repair_r2/repair_receipt.json")["raw_bytes"]["stderr"]["sha256"]),
        ("archive/repair_r3/corrected_static_measurement_receipt.json:raw.stderr.sha256", "archive/repair_r3/raw/corrected_static_measurement.stderr.raw", load("archive/repair_r3/corrected_static_measurement_receipt.json")["raw"]["stderr"]["sha256"]),
        ("archive/repair_r3/validation_receipt.json:raw.stderr.sha256", "archive/repair_r3/validation.stderr.raw", load("archive/repair_r3/validation_receipt.json")["raw"]["stderr"]["sha256"]),
    ]
    for json_path, file, declared in raw_specs:
        actual = digest(file)
        assert len(declared) == 64 and declared == actual
        rows.append({"json_path":json_path,"file":file,"value":declared,"length":len(declared)})
    print(json.dumps({"r3_target":EXPECTED_R3,"artifact_and_raw_fields":rows,"json_parse":"PASS","all_artifact_refs":"PASS","static_and_fingerprint":"PASS","s3_rerun":False}, sort_keys=True, indent=2))


if __name__ == "__main__":
    main()
