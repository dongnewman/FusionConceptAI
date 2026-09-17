"""Independent strict evaluator for a future G2 present profile.

This evaluator is structural only. It never creates trust, certificates, or
external authority. TEST_ONLY profiles can only return non_evidence.
"""
from __future__ import annotations

import copy
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

HEX64 = re.compile(r"^[0-9a-f]{64}$")
ALGORITHMS = {"ed25519", "ecdsa-secp256r1-sha256", "rsa-pss-sha256"}
TOP = {"fixture_role", "status", "production_present_admission", "mapping"}
MAPPING = {
    "namespace", "version", "effective_interval", "issuer", "trust_root", "signature",
    "revocation", "anti_replay", "ambiguity", "conflict", "source_ref", "candidate_ref",
    "evidence_ref", "binding_edges",
}


class ProfileError(ValueError):
    pass


def _pairs(pairs):
    out = {}
    for key, value in pairs:
        if key in out:
            raise ProfileError(f"duplicate_key:{key}")
        out[key] = value
    return out


def load_text(text: str):
    try:
        return json.loads(text, object_pairs_hook=_pairs)
    except ProfileError:
        raise
    except Exception as exc:
        raise ProfileError(f"invalid_json:{exc}") from exc


def load_path(path: Path):
    return load_text(path.read_text(encoding="utf-8"))


def _obj(value, allowed, path):
    if not isinstance(value, dict):
        raise ProfileError(f"{path}:object_required")
    unknown = set(value) - set(allowed)
    if unknown:
        raise ProfileError(f"{path}:unknown_fields:{','.join(sorted(unknown))}")
    return value


def _required(value, key, path):
    if key not in value:
        raise ProfileError(f"{path}:missing:{key}")
    return value[key]


def _text(value, path):
    if not isinstance(value, str) or not value:
        raise ProfileError(f"{path}:nonempty_string_required")
    return value


def _time(value, path):
    _text(value, path)
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ProfileError(f"{path}:invalid_time") from exc
    if parsed.tzinfo is None:
        raise ProfileError(f"{path}:timezone_required")
    return parsed.astimezone(timezone.utc)


def _list(value, path, nonempty=False):
    if not isinstance(value, list) or (nonempty and not value):
        raise ProfileError(f"{path}:list_required")
    return value


def _edge(value, path):
    value = _obj(value, {"ref", "sha256"}, path)
    ref = _text(_required(value, "ref", path), f"{path}.ref")
    digest = _text(_required(value, "sha256", path), f"{path}.sha256").lower()
    if not HEX64.fullmatch(digest):
        raise ProfileError(f"{path}.sha256:sha256_required")
    return ref, digest


def validate_structure(profile):
    profile = _obj(profile, TOP, "profile")
    fixture_role = _text(_required(profile, "fixture_role", "profile"), "profile.fixture_role")
    status = _text(_required(profile, "status", "profile"), "profile.status")
    production_flag = _required(profile, "production_present_admission", "profile")
    if not isinstance(production_flag, bool):
        raise ProfileError("profile.production_present_admission:boolean_required")
    mapping = _obj(_required(profile, "mapping", "profile"), MAPPING, "mapping")

    namespace = _text(_required(mapping, "namespace", "mapping"), "mapping.namespace")
    version = _text(_required(mapping, "version", "mapping"), "mapping.version")
    interval = _obj(_required(mapping, "effective_interval", "mapping"), {"not_before", "not_after", "trusted_time"}, "mapping.effective_interval")
    not_before = _time(_required(interval, "not_before", "mapping.effective_interval"), "mapping.effective_interval.not_before")
    not_after = _time(_required(interval, "not_after", "mapping.effective_interval"), "mapping.effective_interval.not_after")
    trusted_time = _time(_required(interval, "trusted_time", "mapping.effective_interval"), "mapping.effective_interval.trusted_time")
    if not_before >= not_after or trusted_time < not_before or trusted_time > not_after:
        raise ProfileError("mapping.effective_interval:invalid_interval_or_trusted_time")

    issuer = _obj(_required(mapping, "issuer", "mapping"), {"id", "chain"}, "mapping.issuer")
    issuer_id = _text(_required(issuer, "id", "mapping.issuer"), "mapping.issuer.id")
    chain = _list(_required(issuer, "chain", "mapping.issuer"), "mapping.issuer.chain", True)
    if not all(isinstance(x, str) and x for x in chain):
        raise ProfileError("mapping.issuer.chain:nonempty_strings_required")

    trust_root = _obj(_required(mapping, "trust_root", "mapping"), {"fingerprint", "policy_oid", "eku", "key_usage", "name_constraints"}, "mapping.trust_root")
    fingerprint = _text(_required(trust_root, "fingerprint", "mapping.trust_root"), "mapping.trust_root.fingerprint").lower()
    if not HEX64.fullmatch(fingerprint):
        raise ProfileError("mapping.trust_root.fingerprint:sha256_required")
    policy_oid = _text(_required(trust_root, "policy_oid", "mapping.trust_root"), "mapping.trust_root.policy_oid")
    eku = _list(_required(trust_root, "eku", "mapping.trust_root"), "mapping.trust_root.eku", True)
    key_usage = _list(_required(trust_root, "key_usage", "mapping.trust_root"), "mapping.trust_root.key_usage", True)
    name_constraints = _list(_required(trust_root, "name_constraints", "mapping.trust_root"), "mapping.trust_root.name_constraints")
    if not all(isinstance(x, str) and x for x in eku + key_usage + name_constraints):
        raise ProfileError("mapping.trust_root:nonempty_string_lists_required")

    signature = _obj(_required(mapping, "signature", "mapping"), {"algorithm", "signature_bytes", "key_id", "certificate_chain"}, "mapping.signature")
    algorithm = _text(_required(signature, "algorithm", "mapping.signature"), "mapping.signature.algorithm")
    if algorithm not in ALGORITHMS:
        raise ProfileError("mapping.signature.algorithm:unsupported")
    signature_bytes = _text(_required(signature, "signature_bytes", "mapping.signature"), "mapping.signature.signature_bytes")
    key_id = _text(_required(signature, "key_id", "mapping.signature"), "mapping.signature.key_id")
    certs = _list(_required(signature, "certificate_chain", "mapping.signature"), "mapping.signature.certificate_chain", True)
    if not all(isinstance(x, str) and x for x in certs):
        raise ProfileError("mapping.signature.certificate_chain:nonempty_strings_required")

    revocation = _obj(_required(mapping, "revocation", "mapping"), {"status", "source", "checked_at", "freshness_seconds"}, "mapping.revocation")
    rev_status = _text(_required(revocation, "status", "mapping.revocation"), "mapping.revocation.status")
    if rev_status != "not_revoked":
        raise ProfileError("mapping.revocation.status:not_revoked_required")
    _text(_required(revocation, "source", "mapping.revocation"), "mapping.revocation.source")
    checked_at = _time(_required(revocation, "checked_at", "mapping.revocation"), "mapping.revocation.checked_at")
    freshness = _required(revocation, "freshness_seconds", "mapping.revocation")
    if not isinstance(freshness, int) or isinstance(freshness, bool) or not 0 < freshness <= 86400:
        raise ProfileError("mapping.revocation.freshness_seconds:bounded_positive_integer_required")
    if checked_at > trusted_time:
        raise ProfileError("mapping.revocation.checked_at:future_relative_to_trusted_time")

    anti = _obj(_required(mapping, "anti_replay", "mapping"), {"enabled", "nonce", "sequence", "idempotency_key", "replay_status"}, "mapping.anti_replay")
    if _required(anti, "enabled", "mapping.anti_replay") is not True:
        raise ProfileError("mapping.anti_replay.enabled:true_required")
    nonce = _text(_required(anti, "nonce", "mapping.anti_replay"), "mapping.anti_replay.nonce")
    if len(nonce) < 8:
        raise ProfileError("mapping.anti_replay.nonce:too_short")
    sequence = _required(anti, "sequence", "mapping.anti_replay")
    if not isinstance(sequence, int) or isinstance(sequence, bool) or sequence < 0:
        raise ProfileError("mapping.anti_replay.sequence:nonnegative_integer_required")
    _text(_required(anti, "idempotency_key", "mapping.anti_replay"), "mapping.anti_replay.idempotency_key")
    if _required(anti, "replay_status", "mapping.anti_replay") != "not_replayed":
        raise ProfileError("mapping.anti_replay.replay_status:not_replayed_required")

    ambiguity = _obj(_required(mapping, "ambiguity", "mapping"), {"state", "competing_entries", "decision"}, "mapping.ambiguity")
    if _required(ambiguity, "state", "mapping.ambiguity") != "none" or _required(ambiguity, "competing_entries", "mapping.ambiguity") != [] or _required(ambiguity, "decision", "mapping.ambiguity") != "unique":
        raise ProfileError("mapping.ambiguity:unique_required")
    conflict = _obj(_required(mapping, "conflict", "mapping"), {"state", "conflicts", "resolution"}, "mapping.conflict")
    if _required(conflict, "state", "mapping.conflict") != "none" or _required(conflict, "conflicts", "mapping.conflict") != [] or _required(conflict, "resolution", "mapping.conflict") != "none":
        raise ProfileError("mapping.conflict:no_conflict_required")

    source_ref = _text(_required(mapping, "source_ref", "mapping"), "mapping.source_ref")
    candidate_ref = _text(_required(mapping, "candidate_ref", "mapping"), "mapping.candidate_ref")
    evidence_ref = _text(_required(mapping, "evidence_ref", "mapping"), "mapping.evidence_ref")
    edges = _obj(_required(mapping, "binding_edges", "mapping"), {"source_candidate_edge", "candidate_source_edge", "source_evidence_edge", "evidence_source_edge"}, "mapping.binding_edges")
    sc_ref, sc_hash = _edge(_required(edges, "source_candidate_edge", "mapping.binding_edges"), "mapping.binding_edges.source_candidate_edge")
    cs_ref, cs_hash = _edge(_required(edges, "candidate_source_edge", "mapping.binding_edges"), "mapping.binding_edges.candidate_source_edge")
    se_ref, se_hash = _edge(_required(edges, "source_evidence_edge", "mapping.binding_edges"), "mapping.binding_edges.source_evidence_edge")
    es_ref, es_hash = _edge(_required(edges, "evidence_source_edge", "mapping.binding_edges"), "mapping.binding_edges.evidence_source_edge")
    if (sc_ref, sc_hash) != (candidate_ref, cs_hash) or cs_ref != source_ref or se_ref != evidence_ref or es_ref != source_ref or sc_hash != se_hash or se_hash != es_hash:
        raise ProfileError("mapping.binding_edges:bidirectional_source_candidate_evidence_mismatch")
    return {"fixture_role": fixture_role, "status": status, "production_present_admission": production_flag, "namespace": namespace, "version": version, "issuer_id": issuer_id, "key_id": key_id, "signature_bytes": signature_bytes}


def evaluate(profile):
    details = validate_structure(profile)
    if profile["fixture_role"] == "TEST_ONLY" or profile["status"] == "test_only" or profile["production_present_admission"] is False:
        return {"accepted": True, "decision": "non_evidence", "production_admissible": False, "reason": "TEST_ONLY_or_nonproduction", "details": details}
    if profile["fixture_role"] != "PRODUCTION" or profile["status"] != "present" or profile["production_present_admission"] is not True:
        raise ProfileError("production_admission:explicit_present_profile_required")
    return {"accepted": True, "decision": "production_admissible", "production_admissible": True, "details": details}


def mutate(base, case):
    x = copy.deepcopy(base)
    m = x["mapping"]
    if case == "namespace_missing": m.pop("namespace")
    elif case == "version_missing": m.pop("version")
    elif case == "effective_interval_missing": m.pop("effective_interval")
    elif case == "trusted_time_missing": m["effective_interval"].pop("trusted_time")
    elif case == "issuer_id_missing": m["issuer"].pop("id")
    elif case == "issuer_chain_missing": m["issuer"].pop("chain")
    elif case == "signature_bytes_missing": m["signature"].pop("signature_bytes")
    elif case == "algorithm_invalid": m["signature"]["algorithm"] = "unknown-algorithm"
    elif case == "key_id_missing": m["signature"].pop("key_id")
    elif case == "trust_root_missing": m.pop("trust_root")
    elif case == "policy_oid_missing": m["trust_root"].pop("policy_oid")
    elif case == "eku_missing": m["trust_root"].pop("eku")
    elif case == "key_usage_missing": m["trust_root"].pop("key_usage")
    elif case == "name_constraints_missing": m["trust_root"].pop("name_constraints")
    elif case == "revocation_status_missing": m["revocation"].pop("status")
    elif case == "freshness_invalid": m["revocation"]["freshness_seconds"] = 0
    elif case == "nonce_missing": m["anti_replay"].pop("nonce")
    elif case == "sequence_invalid": m["anti_replay"]["sequence"] = -1
    elif case == "idempotency_missing": m["anti_replay"].pop("idempotency_key")
    elif case == "replay_invalid": m["anti_replay"]["replay_status"] = "replayed"
    elif case == "ambiguity_conflict": m["ambiguity"]["state"] = "ambiguous"
    elif case == "conflict_present": m["conflict"]["state"] = "conflict"
    elif case == "binding_edge_mismatch": m["binding_edges"]["evidence_source_edge"]["sha256"] = "f" * 64
    elif case == "unknown_field": m["unexpected"] = True
    else: raise KeyError(case)
    return x


def main(argv):
    if len(argv) != 2:
        print(json.dumps({"status": "usage", "usage": "production_g2_evaluator.py PROFILE"}, sort_keys=True))
        return 2
    try:
        result = evaluate(load_path(Path(argv[1])))
        print(json.dumps(result, sort_keys=True, separators=(",", ":")))
        return 0
    except Exception as exc:
        print(json.dumps({"accepted": False, "decision": "fail_closed", "error": str(exc)}, sort_keys=True, separators=(",", ":")))
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
