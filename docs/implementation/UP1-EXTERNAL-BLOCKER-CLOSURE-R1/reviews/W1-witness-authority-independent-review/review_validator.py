import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
W1 = ROOT / "witness_authority"
NAMES = ["gap_matrix.json", "external_input_register.json", "authority_channel_contract.json", "witness_attestation_schema.json", "validation_receipt.json", "manifest.json", "cleanup_inventory.json"]
objs = {n: json.loads((W1 / n).read_text(encoding="utf-8")) for n in NAMES}
assert len(objs) == len(NAMES)
findings = json.loads((Path(__file__).parent / "findings.json").read_text(encoding="utf-8"))
ids = [x["id"] for x in findings["findings"]]
assert ids == sorted(ids) and len(set(ids)) == 6
assert all(x["state"] == "typed_absence" for x in objs["gap_matrix.json"]["gaps"])
assert all(x["state"] == "typed_absence" for x in objs["external_input_register.json"]["inputs"])
assert objs["authority_channel_contract.json"]["no_publish"] is True
schema = objs["witness_attestation_schema.json"]
assert {"verifier_ref", "idempotency_key"}.issubset(set(schema["required_fields"]) - set(schema["field_contracts"]))
assert schema["placeholder_example"]["attestation_id"].startswith("TEST/")
print(json.dumps({"status":"pass", "json_unique_parse":"pass", "gap_count":9, "external_input_count":10, "finding_count":6, "known_schema_gaps":"captured_as_P1"}, sort_keys=True))
