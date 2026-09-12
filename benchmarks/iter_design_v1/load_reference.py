"""Small, label-neutral registry loader and validator (stdlib only)."""
from __future__ import annotations
import json
from pathlib import Path

EVIDENCE = {"design_target", "measurement", "simulation", "published_experimental_range"}
UNITS = {"MW", "T", "MA", "m^3", "m", "A", "eV", "m^-3", "1", "boolean", "categorical", "URI", None}

def validate_registry(obj):
    errors = []
    if obj.get("schema_version") != "reference_registry_v1": errors.append("schema_version")
    if obj.get("validation_pass") is not False: errors.append("validation_pass must be false")
    refs = obj.get("references")
    if not isinstance(refs, list) or not refs: return ["references"]
    ids = set()
    for ref in refs:
        rid = ref.get("reference_id")
        if not isinstance(rid, str) or rid in ids: errors.append("duplicate/missing reference_id")
        ids.add(rid)
        if not ref.get("device_name") or not isinstance(ref.get("benchmark"), bool): errors.append(f"{rid}: identity")
        if ref.get("evidence_class") not in EVIDENCE: errors.append(f"{rid}: evidence_class")
        if not ref.get("mission"): errors.append(f"{rid}: mission")
        src = ref.get("source", {})
        for key in ("url", "accessed_date", "license_or_access"):
            if not src.get(key): errors.append(f"{rid}: source.{key}")
        if ref.get("mission") == "non_electricity_producing_public_design_reference" and ref.get("evidence_class") == "measurement": errors.append(f"{rid}: ITER design mislabeled measurement")
        fields = ref.get("fields", {})
        for name, field in fields.items():
            if not isinstance(field, dict) or "value" not in field or "uncertainty" not in field: errors.append(f"{rid}: field {name}")
            if field.get("unit") not in UNITS: errors.append(f"{rid}: unit {name}")
            if field.get("value") is None and not field.get("missing_reason"): errors.append(f"{rid}: unknown without reason {name}")
            if isinstance(field.get("value"), (int, float)) and field["value"] < 0 and name not in {"signed_current"}: errors.append(f"{rid}: negative range {name}")
        split = ref.get("data_split", {})
        cal = set(split.get("calibration_artifact_ids", [])); hold = set(split.get("held_out_artifact_ids", []))
        cch = set(split.get("calibration_channel_ids", [])); hch = set(split.get("held_out_channel_ids", []))
        if cal & hold: errors.append(f"{rid}: artifact leakage")
        if cch & hch: errors.append(f"{rid}: channel leakage")
        if ref.get("evidence_class") == "design_target" and (cal or hold): errors.append(f"{rid}: design target split as measurement")
    return errors

def inversion_ready(ref):
    """Readiness is evidence-based; metadata presence cannot substitute for raw data."""
    if ref.get("evidence_class") != "measurement" or ref.get("status") == "pending_data": return False
    if ref.get("fields", {}).get("raw_data_obtained", {}).get("value") is not True: return False
    for field in ref.get("fields", {}).values():
        if field.get("unit_consistency") == "unresolved_catalog_metadata_inconsistency": return False
    return bool(ref.get("data_split", {}).get("declared"))

def load_registry(path=None):
    path = Path(path or Path(__file__).parents[1] / "reference_registry_v1.json")
    obj = json.loads(path.read_text(encoding="utf-8"))
    errors = validate_registry(obj)
    if errors: raise ValueError("registry validation failed: " + "; ".join(errors))
    return obj

if __name__ == "__main__":
    data = load_registry()
    print(f"validated {len(data['references'])} references; validation_pass={data['validation_pass']}")
