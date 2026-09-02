"""Independent RFC 8259/sha256 check for the Julia exact-incidence fixture."""
import hashlib
import json
from pathlib import Path


fixture = json.loads((Path(__file__).parent / "fixtures" / "exact_incidence_golden.json").read_text(encoding="utf-8"))
payload = fixture["canonical_json"]
parsed = json.loads(payload)
assert json.dumps(parsed, ensure_ascii=False, separators=(",", ":")) == payload
assert hashlib.sha256(payload.encode("utf-8")).hexdigest() == fixture["sha256"]
assert parsed["domain"] == "fusionconceptai:v4:typed-incidence-graph:v1"
print("exact-incidence golden verified")
