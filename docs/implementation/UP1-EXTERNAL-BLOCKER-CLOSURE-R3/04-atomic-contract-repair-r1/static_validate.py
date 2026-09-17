"""Static-only acceptance audit for the additive UP1 R3 repair."""
from __future__ import annotations

import hashlib
import json
import pathlib
import re
import subprocess
import sys

from jsonschema import Draft202012Validator

ROOT = pathlib.Path(__file__).resolve().parent
SCHEMAS = ["bundle.schema.json", "ehp-01.schema.json", "ehp-02.schema.json", "ehp-03.schema.json", "ehp-04.schema.json"]
REQUIRED_CODES = {
    "SET_BUNDLE_ID_MISMATCH", "SET_REQUEST_ID_MISMATCH", "SET_PACKET_DIGESTS_MISMATCH", "SET_SHARED_BINDING_MISMATCH",
    "QUARANTINE_RECEIPT_INCOMPLETE", "QUARANTINE_NOT_BEFORE_VERIFY", "DECISION_NOT_BOUND_TO_QUARANTINE",
    "CANONICAL_EXCLUSION_NAME_INVALID", "PACKET_SHARED_BINDING_MISMATCH", "EHP03_CANDIDATE_BINDING_MISMATCH",
    "EHP03_SOURCE_BINDING_MISMATCH", "EHP03_AXIS_SET_MISMATCH", "EHP03_GRAPH_BIJECTION_FAILURE", "EHP03_G2_MAPPING_MISMATCH",
    "EHP04_CONTEXT_BINDING_MISMATCH", "EHP04_RUNTIME_SET_MISMATCH", "EHP04_IDENTITY_MAP_DUPLICATE",
    "EHP04_SBOM_EDGE_ENDPOINT_MISSING", "EHP04_BINARY_BINDING_MISMATCH", "EHP04_FIXTURE_DECISION_MISMATCH",
}


def main() -> int:
    loaded = {name: json.loads((ROOT / name).read_text(encoding="utf-8")) for name in SCHEMAS}
    checks: dict[str, bool] = {}
    for name, schema in loaded.items():
        Draft202012Validator.check_schema(schema)
        checks[f"draft202012:{name}"] = True
    bundle = loaded["bundle.schema.json"]
    positions = bundle["properties"]["packets"]["prefixItems"]
    checks["four_packet_allof_wrappers_closed"] = len(positions) == 4 and all(len(p.get("allOf", [])) == 2 and p.get("unevaluatedProperties") is False for p in positions)
    checks["canonical_exclusions_exact"] = bundle["$defs"]["canonical_exclusions"]["prefixItems"] == [{"const": x} for x in ["signature", "signature_sha256", "owner_preimage_sha256", "set_signature", "set_preimage_sha256", "review_signature", "review_preimage_sha256", "bundle_canonical_sha256"]]
    checks["quarantine_receipt_fields"] = set(["raw_object_sha256", "raw_blob_sha256", "raw_size_bytes", "immutable_locator", "cas_transaction_id", "durable_commit_utc", "receiver_signature"]).issubset(set(bundle["$defs"]["quarantine_receipt"]["required"]))
    predicate_doc = json.loads((ROOT / "verifier-predicates.json").read_text(encoding="utf-8"))
    predicate_codes = {p["error_code"] for p in predicate_doc["predicates"]}
    checks["predicate_code_coverage"] = REQUIRED_CODES.issubset(predicate_codes)
    matrix = (ROOT / "test-matrix.md").read_text(encoding="utf-8")
    checks["test_vector_coverage"] = all(f"R{i:02d}" in matrix for i in range(1, 26))
    checks["forbidden_aliases_not_in_schema"] = not any(alias in json.dumps(bundle, sort_keys=True) for alias in ("signature_digest", "payload_digest"))
    result = {"schema": "UP1.external-handoff.atomic-response-bundle.repair-static-validation.r1", "status": "pass" if all(checks.values()) else "fail", "implementation_status": "not_implemented", "formal_credit": "none", "network": False, "ad_s3_julia_desc_solver": "not_run", "production_tests": "not_run", "checks": checks}
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())
