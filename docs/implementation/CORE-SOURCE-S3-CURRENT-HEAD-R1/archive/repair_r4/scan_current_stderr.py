from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WRONG = "01ba4719c80b6fe911b091a7c05124b64eeece9649e09c058ef8f9805daca546b"
EXPECTED = "01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def get(obj, *keys):
    for key in keys:
        obj = obj[key]
    return obj


def main() -> None:
    wrong_hits = []
    for path in ROOT.rglob("*.json"):
        rel = path.relative_to(ROOT)
        if any(part.startswith("independent_review_") for part in rel.parts):
            continue
        if "archive" in rel.parts and "raw" in rel.parts:
            continue
        count = path.read_text(encoding="utf-8").count(WRONG)
        if count:
            wrong_hits.append({"path": str(rel).replace("\\", "/"), "count": count})
    assert not wrong_hits, wrong_hits

    specs = [
        ("validation_receipt.json", ("repaired_raw", "stderr"), "archive/repair_r2/raw/fresh_s3_recheck.stderr.raw"),
        ("archive/repair_r2/repair_receipt.json", ("raw_bytes", "stderr"), "archive/repair_r2/raw/fresh_s3_recheck.stderr.raw"),
        ("archive/repair_r3/corrected_static_measurement_receipt.json", ("raw", "stderr"), "archive/repair_r3/raw/corrected_static_measurement.stderr.raw"),
        ("archive/repair_r3/validation_receipt.json", ("raw", "stderr"), "archive/repair_r3/validation.stderr.raw"),
    ]
    fields = []
    for json_rel, keys, raw_rel in specs:
        declared = get(load(ROOT / json_rel), *keys)
        raw_path = ROOT / raw_rel
        actual = hashlib.sha256(raw_path.read_bytes()).hexdigest()
        assert declared["sha256"] == EXPECTED == actual
        assert len(declared["sha256"]) == 64
        fields.append({"json_path": f"{json_rel}:{'.'.join(keys)}.sha256", "raw_path": raw_rel, "value": declared["sha256"], "length": len(declared["sha256"]), "file_sha256": actual})

    assert load(ROOT / "manifest.json")["static_closure_count_vector"]["vector"] == [4, 5, 12, 1, 47, 0]
    assert load(ROOT / "source_closure.json")["static_closure"]["count_vector"] == [4, 5, 12, 1, 47, 0]
    assert load(ROOT / "validation_receipt.json")["input_hashes"]["input_fingerprint"] == "840922caac204df3d66ce3419868390c2fda8e79c3792cc4e074af2887edd9a5"
    print(json.dumps({"wrong_string_count": 0, "stderr_fields": fields, "static_vector": [4, 5, 12, 1, 47, 0], "fingerprint": "840922caac204df3d66ce3419868390c2fda8e79c3792cc4e074af2887edd9a5", "s3_rerun": False}, sort_keys=True, indent=2))


if __name__ == "__main__":
    main()
