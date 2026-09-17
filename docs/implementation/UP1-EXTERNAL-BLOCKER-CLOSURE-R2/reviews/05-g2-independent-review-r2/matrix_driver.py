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
EXPECTED = COMP / "fixtures/expected_binding.json"
SOURCE = COMP / "production_g2_mapping.py"
sys.path.insert(0, str(COMP))
import production_g2_mapping as ev  # noqa: E402

fixture_bytes = FIXTURE.read_bytes()
base = ev.load_text(fixture_bytes.decode())
expected = ev.load_path(EXPECTED)


def utc():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def digest(data: bytes):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def get_path(value, path):
    cur = value
    try:
        for part in path.split("."):
            cur = cur[int(part)] if isinstance(cur, list) else cur[part]
    except (KeyError, IndexError, TypeError):
        return "<missing>"
    return cur


def reject_row(case_id, mutate, path, raw=None, expected_binding=expected, note=""):
    item = copy.deepcopy(base)
    original = get_path(item, path) if raw is None else "baseline JSON"
    attempted = raw
    observed = None
    reason = None
    try:
        if raw is None:
            if mutate is not None:
                mutate(item)
            attempted = get_path(item, path)
            ev.validate_profile(item, expected_binding)
        else:
            ev.load_text(raw)
        observed = "accepted"
    except ev.ProfileError as exc:
        observed = "rejected"
        reason = str(exc)
    except Exception as exc:
        observed = "program_exception"
        reason = f"{type(exc).__name__}:{exc}"
    ok = observed == "rejected"
    mutated = canonical(item).encode() if raw is None else raw.encode()
    return {"case_id": case_id, "mutation_id": case_id, "expected": "reject", "observed": observed, "ok": ok,
            "input_hash": digest(mutated), "source_hashes": {"production_g2_mapping.py": digest(SOURCE.read_bytes()), "fixture": digest(fixture_bytes), "expected_binding": digest(EXPECTED.read_bytes())},
            "path": path, "original_value": repr(original), "attempted_value": repr(attempted), "classification": "pass" if ok else "finding", "reason": reason, "note": note}


rows = []
try:
    ev.validate_profile(copy.deepcopy(base), expected)
    rows.append({"case_id": "G2-POS-TEST_ONLY-SCHEMA", "expected": "accept", "observed": "accepted", "ok": True, "classification": "pass", "note": "baseline schema validation accepts"})
except Exception as exc:
    rows.append({"case_id": "G2-POS-TEST_ONLY-SCHEMA", "expected": "accept", "observed": "program_exception", "ok": False, "classification": "finding", "reason": repr(exc)})
try:
    r = ev.evaluate(copy.deepcopy(base), expected)
    rows.append({"case_id": "G2-POS-TEST_ONLY-EVALUATE", "expected": "non_evidence", "observed": r["decision"], "ok": r["decision"] == "non_evidence", "result": r, "classification": "pass" if r["decision"] == "non_evidence" else "finding"})
except Exception as exc:
    rows.append({"case_id": "G2-POS-TEST_ONLY-EVALUATE", "expected": "non_evidence", "observed": "program_exception", "ok": False, "reason": repr(exc), "classification": "finding"})
try:
    r = ev.evaluate(ev.load_path(COMP / "fixtures/typed_absent.json"))
    rows.append({"case_id": "G2-POS-TYPED-ABSENT", "expected": "typed_absence", "observed": r["decision"], "ok": r == {"accepted": True, "decision": "typed_absence", "production_admissible": False, "reason": "authoritative_mapping_not_supplied"}, "result": r, "classification": "pass" if r["decision"] == "typed_absence" else "finding"})
except Exception as exc:
    rows.append({"case_id": "G2-POS-TYPED-ABSENT", "expected": "typed_absence", "observed": "program_exception", "ok": False, "reason": repr(exc), "classification": "finding"})

prod = copy.deepcopy(base)
prod["fixture_role"], prod["status"], prod["production_present_admission"] = "PRODUCTION", "present", True
try:
    r = ev.evaluate(prod, expected)
    safe = r["accepted"] is False and r["decision"] == "fail_closed" and r["production_admissible"] is False and r["authority_verified"] is False
    rows.append({"case_id": "G2-SEC-PRODUCTION-NO-AUTHORITY", "expected": "fail_closed_no_credit", "observed": r["decision"], "ok": safe, "result": r, "classification": "pass" if safe else "finding", "note": "arbitrary signature bytes do not pass production authority"})
except Exception as exc:
    rows.append({"case_id": "G2-SEC-PRODUCTION-NO-AUTHORITY", "expected": "fail_closed_no_credit", "observed": "program_exception", "ok": False, "reason": repr(exc), "classification": "finding"})

raw_fixture = fixture_bytes.decode()
rows += [
    reject_row("G2-NEG-DUPLICATE-JSON-TOP", None, "top", raw='{"schema":"UP1.g2-production-mapping.v2","fixture_role":"TEST_ONLY","status":"test_only","production_present_admission":false,"mapping":null,"absence":null,"mapping":null}'),
    reject_row("G2-NEG-DUPLICATE-JSON-NESTED", None, "top", raw=raw_fixture.replace('"algorithm": "ed25519",', '"algorithm": "ed25519", "algorithm": "rsa-pss-sha256",', 1)),
]

mutations = {
    "G2-NEG-UNKNOWN-TOP": (lambda m: m.__setitem__("unexpected", True), "unexpected"),
    "G2-NEG-UNKNOWN-NESTED": (lambda m: m["mapping"]["signature"].__setitem__("unexpected", True), "mapping.signature.unexpected"),
    "G2-NEG-AXIS-DUPLICATE-ID": (lambda m: m["mapping"]["four_axis_evidence"]["axes"][1].__setitem__("axis_id", "payload_schema_version"), "mapping.four_axis_evidence.axes.1.axis_id"),
    "G2-NEG-AXIS-MISSING": (lambda m: m["mapping"]["four_axis_evidence"]["axes"].pop(), "mapping.four_axis_evidence.axes"),
    "G2-NEG-AXIS-DUPLICATE-EVIDENCE-REF": (lambda m: m["mapping"]["four_axis_evidence"]["axes"][1].__setitem__("evidence_ref", m["mapping"]["four_axis_evidence"]["axes"][0]["evidence_ref"]), "mapping.four_axis_evidence.axes.1.evidence_ref"),
    "G2-NEG-AXIS-BAD-VERSION": (lambda m: m["mapping"]["four_axis_evidence"]["axes"][0].__setitem__("version", "latest"), "mapping.four_axis_evidence.axes.0.version"),
    "G2-NEG-EDGE-FORWARD-HASH": (lambda m: m["mapping"]["binding_edges"]["source_candidate_edge"].__setitem__("sha256", "f"*64), "mapping.binding_edges.source_candidate_edge.sha256"),
    "G2-NEG-EDGE-REVERSE-HASH": (lambda m: m["mapping"]["binding_edges"]["candidate_source_edge"].__setitem__("sha256", "f"*64), "mapping.binding_edges.candidate_source_edge.sha256"),
    "G2-NEG-EDGE-FORWARD-REF": (lambda m: m["mapping"]["binding_edges"]["four_axis_evidence_g2_edge"].__setitem__("ref", "fusionconceptai://GenomeV5/G2/foreign/v2"), "mapping.binding_edges.four_axis_evidence_g2_edge.ref"),
    "G2-NEG-EDGE-REVERSE-REF": (lambda m: m["mapping"]["binding_edges"]["g2_four_axis_evidence_edge"].__setitem__("ref", "fusionconceptai://evidence/four-axis/foreign"), "mapping.binding_edges.g2_four_axis_evidence_edge.ref"),
    "G2-NEG-FOREIGN-CANDIDATE-INCONSISTENT": (lambda m: m["mapping"].__setitem__("candidate_ref", "fusionconceptai://candidate/foreign"), "mapping.candidate_ref"),
    "G2-NEG-FOREIGN-SOURCE-INCONSISTENT": (lambda m: m["mapping"].__setitem__("source_ref", "fusionconceptai://source/foreign"), "mapping.source_ref"),
    "G2-NEG-ISSUER": (lambda m: m["mapping"]["issuer"].pop("id"), "mapping.issuer"),
    "G2-NEG-KEY-ID": (lambda m: m["mapping"]["signature"].pop("key_id"), "mapping.signature"),
    "G2-NEG-POLICY-OID": (lambda m: m["mapping"]["trust_root"].__setitem__("policy_oid", "not-an-oid"), "mapping.trust_root.policy_oid"),
    "G2-NEG-NAME-CONSTRAINT": (lambda m: m["mapping"]["trust_root"].__setitem__("name_constraints", [""]), "mapping.trust_root.name_constraints"),
    "G2-NEG-EKU": (lambda m: m["mapping"]["trust_root"].__setitem__("eku", []), "mapping.trust_root.eku"),
    "G2-NEG-KEY-USAGE": (lambda m: m["mapping"]["trust_root"].pop("key_usage"), "mapping.trust_root"),
    "G2-NEG-REVOCATION": (lambda m: m["mapping"]["revocation"].__setitem__("status", "revoked"), "mapping.revocation.status"),
    "G2-NEG-FRESHNESS": (lambda m: m["mapping"]["revocation"].__setitem__("checked_at", "2026-01-01T00:00:00Z"), "mapping.revocation.checked_at"),
    "G2-NEG-NONCE": (lambda m: m["mapping"]["anti_replay"].__setitem__("nonce", "x"), "mapping.anti_replay.nonce"),
    "G2-NEG-SEQUENCE": (lambda m: m["mapping"]["anti_replay"].__setitem__("sequence", -1), "mapping.anti_replay.sequence"),
    "G2-NEG-IDEMPOTENCY": (lambda m: m["mapping"]["anti_replay"].pop("idempotency_key"), "mapping.anti_replay"),
    "G2-NEG-REPLAY": (lambda m: m["mapping"]["anti_replay"].__setitem__("replay_status", "replayed"), "mapping.anti_replay.replay_status"),
    "G2-NEG-WRONG-TYPE": (lambda m: m["mapping"]["revocation"].__setitem__("freshness_seconds", "3600"), "mapping.revocation.freshness_seconds"),
}
for case_id, (mutate, path) in mutations.items():
    rows.append(reject_row(case_id, mutate, path))

def foreign_candidate(m):
    m["mapping"]["candidate_ref"] = "fusionconceptai://candidate/foreign"
    m["mapping"]["binding_edges"]["source_candidate_edge"]["ref"] = "fusionconceptai://candidate/foreign"
    m["mapping"]["binding_edges"]["four_axis_evidence_candidate_edge"]["ref"] = "fusionconceptai://candidate/foreign"

def foreign_source(m):
    m["mapping"]["source_ref"] = "fusionconceptai://source/foreign"
    m["mapping"]["binding_edges"]["candidate_source_edge"]["ref"] = "fusionconceptai://source/foreign"

rows.append(reject_row("G2-NEG-FOREIGN-CANDIDATE-SELF-CONSISTENT", foreign_candidate, "mapping.candidate_ref", note="all local candidate edges updated"))
rows.append(reject_row("G2-NEG-FOREIGN-SOURCE-SELF-CONSISTENT", foreign_source, "mapping.source_ref", note="local source edge updated"))

# Expected-binding attacks: replacement, omission, axis mismatch, and self-reference.
def production_without_context(m):
    m["fixture_role"], m["status"], m["production_present_admission"] = "PRODUCTION", "present", True

rows.append(reject_row("G2-NEG-EXPECTED-BINDING-MISSING", production_without_context, "fixture_role", expected_binding=None, note="production-independent context omission is fail closed"))
rows.append(reject_row("G2-NEG-EXPECTED-BINDING-REPLACED-CANDIDATE", None, "mapping", expected_binding={**expected, "candidate_ref": "fusionconceptai://candidate/other"}))
bad_axes = copy.deepcopy(expected); bad_axes["four_axis_materials"][0]["material_sha256"] = "f" * 64
rows.append(reject_row("G2-NEG-EXPECTED-BINDING-AXIS-REPLACED", None, "mapping", expected_binding=bad_axes))
rows.append(reject_row("G2-NEG-EXPECTED-BINDING-SELF-REFERENCE", None, "mapping", expected_binding=copy.deepcopy(base["mapping"])))

# R1's legal array permutation, with its declaration/receipt hash rebuilt.
permuted = copy.deepcopy(base)
permuted["mapping"]["four_axis_evidence"]["axes"] = list(reversed(permuted["mapping"]["four_axis_evidence"]["axes"]))
decl_body = json.loads(ev.canonical_declaration_bytes(permuted["mapping"]).decode())
decl_hash = hashlib.sha256(b"UP1-R2-G2-CANONICAL-DECLARATION-V1\0" + canonical(decl_body).encode()).hexdigest()
permuted["mapping"]["integrity"]["declaration_sha256"] = decl_hash
payload = permuted["mapping"]["integrity"]["signature_payload"]
payload["declaration_sha256"] = decl_hash
payload_body = {key: payload[key] for key in ("algorithm", "key_id", "declaration_sha256", "source_sha256", "nonce", "sequence")}
payload["payload_sha256"] = hashlib.sha256(b"UP1-R2-G2-SIGNATURE-PAYLOAD-V1\0" + canonical(payload_body).encode()).hexdigest()
permuted["mapping"]["integrity"]["receipt"]["declaration_sha256"] = decl_hash
permuted["mapping"]["integrity"]["receipt"]["signature_payload_sha256"] = payload["payload_sha256"]
try:
    ev.validate_profile(permuted, expected)
    rows.append({"case_id": "G2-POS-ARRAY-PERMUTATION", "expected": "accept_after_hash_rebuild", "observed": "accepted", "ok": True, "input_hash": digest(canonical(permuted).encode()), "classification": "pass", "note": "permutation requires declaration/receipt hash rebuild"})
except Exception as exc:
    rows.append({"case_id": "G2-POS-ARRAY-PERMUTATION", "expected": "accept_after_hash_rebuild", "observed": "program_exception", "ok": False, "reason": repr(exc), "classification": "finding"})

# Integrity attacks: stale/forged/missing hashes and legal reordering with stale receipt.
integrity_attacks = {
    "G2-NEG-CANONICAL-DECLARATION-FORGED": (lambda m: m["mapping"]["integrity"].__setitem__("declaration_sha256", "f"*64), "mapping.integrity.declaration_sha256"),
    "G2-NEG-CANONICAL-DECLARATION-MISSING": (lambda m: m["mapping"]["integrity"].pop("declaration_sha256"), "mapping.integrity"),
    "G2-NEG-SOURCE-IDENTITY-FORGED": (lambda m: m["mapping"]["source_identity"].__setitem__("identity_sha256", "f"*64), "mapping.source_identity.identity_sha256"),
    "G2-NEG-INTEGRITY-SOURCE-FORGED": (lambda m: m["mapping"]["integrity"].__setitem__("source_sha256", "f"*64), "mapping.integrity.source_sha256"),
    "G2-NEG-SIGNATURE-PAYLOAD-FORGED": (lambda m: m["mapping"]["integrity"]["signature_payload"].__setitem__("payload_sha256", "f"*64), "mapping.integrity.signature_payload.payload_sha256"),
    "G2-NEG-SIGNATURE-PAYLOAD-MISSING": (lambda m: m["mapping"]["integrity"]["signature_payload"].pop("payload_sha256"), "mapping.integrity.signature_payload"),
    "G2-NEG-RECEIPT-FORGED": (lambda m: m["mapping"]["integrity"]["receipt"].__setitem__("signature_payload_sha256", "f"*64), "mapping.integrity.receipt.signature_payload_sha256"),
    "G2-NEG-RECEIPT-MISSING": (lambda m: m["mapping"]["integrity"].pop("receipt"), "mapping.integrity"),
    "G2-NEG-CANONICAL-AXIS-REORDER": (lambda m: m["mapping"]["four_axis_evidence"].__setitem__("axes", list(reversed(m["mapping"]["four_axis_evidence"]["axes"]))), "mapping.four_axis_evidence.axes"),
}
for case_id, (mutate, path) in integrity_attacks.items():
    rows.append(reject_row(case_id, mutate, path))

print(json.dumps({"protocol_id": "UP1-EXTERNAL-BLOCKER-CLOSURE-R2-REVIEW-V1", "review_revision": "r2", "group_id": "R2-G2", "component": "G2", "TEST_ONLY": True, "non_evidence": True, "started_at_utc": utc(), "ended_at_utc": utc(), "pid": os.getpid(), "parent_pid": os.getppid(), "cwd": str(ROOT), "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(), "case_count": len(rows), "rows": rows}, sort_keys=True, separators=(",", ":")))
