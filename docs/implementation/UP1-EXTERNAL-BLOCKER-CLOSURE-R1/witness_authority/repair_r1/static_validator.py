import json
import os
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
W1 = ROOT / "witness_authority"
started = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def load(path):
    return json.loads(path.read_text(encoding="utf-8"))

gap = load(W1 / "gap_matrix.json")
register = load(W1 / "external_input_register.json")
channel = load(W1 / "authority_channel_contract.json")
schema = load(W1 / "witness_attestation_schema.json")
positive = load(W1 / "repair_r1/fixtures/contract_shape_positive.json")
placeholder = load(W1 / "repair_r1/fixtures/placeholder_present_negative.json")
retry = load(W1 / "repair_r1/fixtures/placeholder_retry_present.json")
foreign = load(W1 / "repair_r1/fixtures/foreign_layer_axis_negative.json")
foreign_axis = load(W1 / "repair_r3/fixtures/foreign_axis_binding_negative.json")

def reject_present(record):
    """Independent production-present evaluator; never reads fixture expected fields."""
    if record.get("state") != "present":
        return "typed_absence", "ERR_NOT_PRESENT"
    encoded = json.dumps(record, sort_keys=True, separators=(",", ":"))
    if "TEST/PLACEHOLDER" in encoded or "TEST/FOREIGN" in encoded:
        return "fail_closed", "ERR_PLACEHOLDER_PRESENT"
    candidate = record.get("candidate_id")
    for layer, binding in record.get("layer_refs", {}).items():
        if binding.get("candidate_id") != candidate:
            return "fail_closed", "ERR_FOREIGN_LAYER_CANDIDATE"
        if not isinstance(binding.get("sha256"), str) or len(binding["sha256"]) != 64:
            return "fail_closed", "ERR_LAYER_HASH_INVALID"
    for axis, binding in record.get("four_axis_refs", {}).items():
        if binding.get("candidate_id") != candidate:
            return "fail_closed", "ERR_FOREIGN_AXIS_CANDIDATE"
        if not isinstance(binding.get("sha256"), str) or len(binding["sha256"]) != 64:
            return "fail_closed", "ERR_AXIS_HASH_INVALID"
    return "present_admissible_shape", "OK_SHAPE_ONLY"

def evaluate_retry(record):
    if record.get("state") != "present":
        return "typed_absence", "ERR_NOT_PRESENT"
    if not isinstance(record.get("retry_budget"), int) or record["retry_budget"] <= 0:
        return "fail_closed", "ERR_RETRY_BUDGET_PLACEHOLDER_OR_INVALID"
    if not isinstance(record.get("backoff_seconds"), (int, float)) or record["backoff_seconds"] < 0:
        return "fail_closed", "ERR_BACKOFF_PLACEHOLDER_OR_INVALID"
    return "present_admissible_shape", "OK_RETRY_SHAPE_ONLY"

assert positive.get("state") == "typed_absence" and positive.get("no_publish") is True
assert all(x.get("state") == "typed_absence" and x.get("no_publish") for x in gap["gaps"])
gaps = {x["id"]: x for x in gap["gaps"]}
assert len(register["inputs"]) == 10
for item in register["inputs"]:
    g = gaps[item["gap_id"]]
    for key in ("provider", "owner", "responsible_party", "authority_ref", "recovery_condition", "expiry_condition"):
        assert item[key] is not None and item[key] == g[key]
    assert item["authoritative_source"] == g["authority_source"]
assert set(schema["required_fields"]) == set(schema["field_contracts"])
assert {"verifier_ref", "idempotency_key"}.issubset(schema["field_contracts"])
assert {"candidate_id", "layer_refs", "four_axis_refs", "source_version"}.issubset(channel["request_schema"]["required_fields"])
assert {"trusted_time_source_ref", "freshness_window_seconds", "revocation_source_ref"}.issubset(channel["freshness_and_revocation"]["required_fields"])

decision_positive, code_positive = reject_present(positive)
decision_placeholder, code_placeholder = reject_present(placeholder)
decision_retry, code_retry = evaluate_retry(retry)
decision_foreign, code_foreign = reject_present(foreign)
decision_foreign_axis, code_foreign_axis = reject_present(foreign_axis)
assert decision_positive == "typed_absence" and code_positive == "ERR_NOT_PRESENT"
assert decision_placeholder == "fail_closed" and code_placeholder == "ERR_PLACEHOLDER_PRESENT"
assert decision_retry == "fail_closed" and code_retry.startswith("ERR_RETRY_")
assert decision_foreign == "fail_closed" and code_foreign == "ERR_FOREIGN_LAYER_CANDIDATE"
assert decision_foreign_axis == "fail_closed" and code_foreign_axis == "ERR_FOREIGN_AXIS_CANDIDATE"

ended = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
print("W1_REPAIR_R3_INDEPENDENT_EVALUATOR=pass")
print("PID=" + str(os.getpid()))
print("UTC_STARTED=" + started)
print("UTC_ENDED=" + ended)
print("contract_shape_positive=typed_absence|ERR_NOT_PRESENT|non_evidence")
print("placeholder_present_negative=fail_closed|ERR_PLACEHOLDER_PRESENT")
print("placeholder_retry_negative=fail_closed|" + code_retry)
print("foreign_layer_binding_negative=fail_closed|ERR_FOREIGN_LAYER_CANDIDATE")
print("foreign_axis_binding_negative=fail_closed|ERR_FOREIGN_AXIS_CANDIDATE")
print("EXPECTED_FIELDS_READ=0")
print("CLAIM_CEILING=preparation_only")
