from __future__ import annotations

import copy
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path.cwd().resolve()
COMP = ROOT / "tools/up1_external_closure_r2/g2_mapping"
FIXTURE = COMP / "fixtures/test_only_positive.json"
SOURCE = COMP / "production_g2_mapping.py"
sys.path.insert(0, str(COMP))
import production_g2_mapping as ev  # noqa: E402


def utc() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def cj(value) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


fixture_bytes = FIXTURE.read_bytes()
base = ev.load_text(fixture_bytes.decode("utf-8"))
source_hash = sha(SOURCE.read_bytes())
fixture_hash = sha(fixture_bytes)


def record(case_id: str, expected: str, mutate=None, raw: str | None = None, note: str = ""):
    item = copy.deepcopy(base)
    original = cj(item)
    attempted = original
    observed = ""
    reason = None
    error_path = None
    try:
        if raw is not None:
            attempted = raw
            ev.load_text(raw)
            observed = "accepted_parse"
        else:
            if mutate is not None:
                mutate(item)
            attempted = cj(item)
            ev.validate_profile(item)
            observed = "accepted"
    except ev.ProfileError as exc:
        observed = "rejected"
        reason = str(exc)
        error_path = reason.split(":", 1)[0]
    except Exception as exc:  # unexpected faults must be visible
        observed = "program_exception"
        reason = f"{type(exc).__name__}:{exc}"
    ok = (expected == "accept" and observed in {"accepted", "accepted_parse"}) or (expected == "reject" and observed == "rejected")
    return {
        "case_id": case_id,
        "mutation_id": case_id,
        "expected": expected,
        "observed": observed,
        "ok": ok,
        "input_hash": sha(attempted.encode("utf-8")),
        "source_hashes": {"production_g2_mapping.py": source_hash, "fixture": fixture_hash},
        "path": case_id,
        "original_value": original,
        "attempted_value": attempted,
        "classification": "pass" if ok else "finding",
        "reason": reason,
        "error_path": error_path,
        "note": note,
    }


rows = []
raw_fixture = fixture_bytes.decode("utf-8")
rows.append(record("G2-POS-TEST_ONLY-SCHEMA", "accept"))
try:
    result = ev.evaluate(copy.deepcopy(base))
    rows.append({"case_id": "G2-POS-TEST_ONLY-EVALUATE", "expected": "non_evidence", "observed": result["decision"], "ok": result["decision"] == "non_evidence", "result": result, "classification": "pass" if result["decision"] == "non_evidence" else "finding"})
except Exception as exc:
    rows.append({"case_id": "G2-POS-TEST_ONLY-EVALUATE", "expected": "non_evidence", "observed": "program_exception", "ok": False, "reason": repr(exc), "classification": "finding"})
try:
    absent = ev.evaluate(ev.load_path(COMP / "fixtures/typed_absent.json"))
    rows.append({"case_id": "G2-POS-TYPED-ABSENT", "expected": "typed_absence", "observed": absent["decision"], "ok": absent["decision"] == "typed_absence" and absent["production_admissible"] is False, "result": absent, "classification": "pass" if absent["decision"] == "typed_absence" else "finding"})
except Exception as exc:
    rows.append({"case_id": "G2-POS-TYPED-ABSENT", "expected": "typed_absence", "observed": "program_exception", "ok": False, "reason": repr(exc), "classification": "finding"})

prod = copy.deepcopy(base)
prod["fixture_role"], prod["status"], prod["production_present_admission"] = "PRODUCTION", "present", True
try:
    got = ev.evaluate(prod)
    safe = got.get("decision") == "production_admissible_structural" and got.get("authority_verified") is False and got.get("production_admissible") is True
    rows.append({"case_id": "G2-SEC-PRODUCTION-NO-AUTHORITY", "expected": "structural_only_no_verify", "observed": got.get("decision"), "ok": safe, "result": got, "classification": "pass" if safe else "finding", "note": "arbitrary signature bytes are accepted structurally but authority_verified is false"})
except Exception as exc:
    rows.append({"case_id": "G2-SEC-PRODUCTION-NO-AUTHORITY", "expected": "structural_only_no_verify", "observed": "program_exception", "ok": False, "reason": repr(exc), "classification": "finding"})

rows += [
    record("G2-NEG-DUPLICATE-JSON-TOP", "reject", raw='{"schema":"UP1.g2-production-mapping.v2","fixture_role":"TEST_ONLY","status":"test_only","production_present_admission":false,"mapping":null,"absence":null,"mapping":null}'),
    record("G2-NEG-DUPLICATE-JSON-NESTED", "reject", raw=raw_fixture.replace('"algorithm": "ed25519",', '"algorithm": "ed25519", "algorithm": "rsa-pss-sha256",', 1)),
]

mutations = {
    "G2-NEG-UNKNOWN-TOP": lambda m: m.__setitem__("unexpected", True),
    "G2-NEG-UNKNOWN-NESTED": lambda m: m["mapping"]["signature"].__setitem__("unexpected", True),
    "G2-NEG-AXIS-DUPLICATE-ID": lambda m: m["mapping"]["four_axis_evidence"]["axes"][1].__setitem__("axis_id", "payload_schema_version"),
    "G2-NEG-AXIS-MISSING": lambda m: m["mapping"]["four_axis_evidence"]["axes"].pop(),
    "G2-NEG-AXIS-DUPLICATE-EVIDENCE-REF": lambda m: m["mapping"]["four_axis_evidence"]["axes"][1].__setitem__("evidence_ref", m["mapping"]["four_axis_evidence"]["axes"][0]["evidence_ref"]),
    "G2-NEG-AXIS-BAD-VERSION": lambda m: m["mapping"]["four_axis_evidence"]["axes"][0].__setitem__("version", "latest"),
    "G2-NEG-EDGE-FORWARD-HASH": lambda m: m["mapping"]["binding_edges"]["source_candidate_edge"].__setitem__("sha256", "f" * 64),
    "G2-NEG-EDGE-REVERSE-HASH": lambda m: m["mapping"]["binding_edges"]["candidate_source_edge"].__setitem__("sha256", "f" * 64),
    "G2-NEG-EDGE-FORWARD-REF": lambda m: m["mapping"]["binding_edges"]["four_axis_evidence_g2_edge"].__setitem__("ref", "fusionconceptai://GenomeV5/G2/foreign/v2"),
    "G2-NEG-EDGE-REVERSE-REF": lambda m: m["mapping"]["binding_edges"]["g2_four_axis_evidence_edge"].__setitem__("ref", "fusionconceptai://evidence/four-axis/foreign"),
    "G2-NEG-FOREIGN-CANDIDATE-INCONSISTENT": lambda m: m["mapping"].__setitem__("candidate_ref", "fusionconceptai://candidate/foreign"),
    "G2-NEG-FOREIGN-SOURCE-INCONSISTENT": lambda m: m["mapping"].__setitem__("source_ref", "fusionconceptai://source/foreign"),
    "G2-NEG-ISSUER": lambda m: m["mapping"]["issuer"].pop("id"),
    "G2-NEG-KEY-ID": lambda m: m["mapping"]["signature"].pop("key_id"),
    "G2-NEG-POLICY-OID": lambda m: m["mapping"]["trust_root"].__setitem__("policy_oid", "not-an-oid"),
    "G2-NEG-NAME-CONSTRAINT": lambda m: m["mapping"]["trust_root"].__setitem__("name_constraints", [""]),
    "G2-NEG-EKU": lambda m: m["mapping"]["trust_root"].__setitem__("eku", []),
    "G2-NEG-KEY-USAGE": lambda m: m["mapping"]["trust_root"].pop("key_usage"),
    "G2-NEG-REVOCATION": lambda m: m["mapping"]["revocation"].__setitem__("status", "revoked"),
    "G2-NEG-FRESHNESS": lambda m: m["mapping"]["revocation"].__setitem__("checked_at", "2026-01-01T00:00:00Z"),
    "G2-NEG-NONCE": lambda m: m["mapping"]["anti_replay"].__setitem__("nonce", "x"),
    "G2-NEG-SEQUENCE": lambda m: m["mapping"]["anti_replay"].__setitem__("sequence", -1),
    "G2-NEG-IDEMPOTENCY": lambda m: m["mapping"]["anti_replay"].pop("idempotency_key"),
    "G2-NEG-REPLAY": lambda m: m["mapping"]["anti_replay"].__setitem__("replay_status", "replayed"),
    "G2-NEG-WRONG-TYPE": lambda m: m["mapping"]["revocation"].__setitem__("freshness_seconds", "3600"),
}
for case_id, mutate in mutations.items():
    rows.append(record(case_id, "reject", mutate))

def foreign_candidate(m):
    m["mapping"]["candidate_ref"] = "fusionconceptai://candidate/foreign"
    edges = m["mapping"]["binding_edges"]
    edges["source_candidate_edge"]["ref"] = "fusionconceptai://candidate/foreign"
    edges["four_axis_evidence_candidate_edge"]["ref"] = "fusionconceptai://candidate/foreign"

def foreign_source(m):
    m["mapping"]["source_ref"] = "fusionconceptai://source/foreign"
    m["mapping"]["binding_edges"]["candidate_source_edge"]["ref"] = "fusionconceptai://source/foreign"

rows.append(record("G2-NEG-FOREIGN-CANDIDATE-SELF-CONSISTENT", "reject", foreign_candidate, note="all local edges updated; profile has no external candidate identity context"))
rows.append(record("G2-NEG-FOREIGN-SOURCE-SELF-CONSISTENT", "reject", foreign_source, note="all local edges updated; profile has no external source identity context"))

permuted = copy.deepcopy(base)
permuted["mapping"]["four_axis_evidence"]["axes"] = list(reversed(permuted["mapping"]["four_axis_evidence"]["axes"]))
try:
    perm_result = ev.validate_profile(permuted)
    rows.append({"case_id": "G2-POS-ARRAY-PERMUTATION", "expected": "accept", "observed": "accepted", "ok": True, "input_hash": sha(cj(permuted).encode()), "result": perm_result, "classification": "pass", "note": "accepted; no canonical bytes/hash is emitted by validator"})
except Exception as exc:
    rows.append({"case_id": "G2-POS-ARRAY-PERMUTATION", "expected": "accept", "observed": "rejected", "ok": False, "reason": repr(exc), "classification": "finding"})

print(json.dumps({
    "protocol_id": "UP1-EXTERNAL-BLOCKER-CLOSURE-R2-REVIEW-V1", "review_revision": "r1", "group_id": "R2-G2", "component": "G2",
    "TEST_ONLY": True, "non_evidence": True, "started_at_utc": utc(), "ended_at_utc": utc(), "pid": os.getpid(), "parent_pid": os.getppid(),
    "cwd": str(ROOT), "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(), "seed": "none",
    "case_count": len(rows), "rows": rows,
}, sort_keys=True, separators=(",", ":")))
