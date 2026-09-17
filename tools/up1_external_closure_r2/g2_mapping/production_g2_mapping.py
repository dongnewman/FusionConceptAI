"""Strict, dependency-free validation for an external G2 mapping profile.

The validator is deliberately a structural gate.  It verifies that an
authoritative profile contains the fields needed for independent verification;
it does not manufacture a trust root or perform cryptographic verification.
``TEST_ONLY`` profiles are useful positive schema controls only and can never
produce evidence or production credit.  Missing authority is represented by a
typed absence record rather than a guessed value.
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


SCHEMA = "UP1.g2-production-mapping.v2"
REGISTERED_NAMESPACE = "fusionconceptai://GenomeV5/G2/metric-boundary/external-mapping"
ALGORITHMS = {"ed25519", "ecdsa-secp256r1-sha256", "rsa-pss-sha256"}
AXES = {
    "payload_schema_version",
    "canonicalization_profile_version",
    "applicability_profile_version",
    "evidence_receipt_version",
}
HEX64 = re.compile(r"^[0-9a-f]{64}$")
VERSION = re.compile(r"^v[0-9]+(?:\.[0-9]+){0,2}$")
OID = re.compile(r"^[0-9]+(?:\.[0-9]+)+$")
URI = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*://[^\s]+$")
HEX40 = re.compile(r"^[0-9a-f]{40}$")
DOMAIN_DECLARATION = b"UP1-R2-G2-CANONICAL-DECLARATION-V1\0"
DOMAIN_SOURCE = b"UP1-R2-G2-SOURCE-IDENTITY-V1\0"
DOMAIN_SIGNATURE_PAYLOAD = b"UP1-R2-G2-SIGNATURE-PAYLOAD-V1\0"


class ProfileError(ValueError):
    """A deterministic fail-closed profile error."""


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in pairs:
        if key in out:
            raise ProfileError(f"duplicate_key:{key}")
        out[key] = value
    return out


def load_text(text: str) -> Any:
    try:
        return json.loads(text, object_pairs_hook=_pairs)
    except ProfileError:
        raise
    except Exception as exc:
        raise ProfileError(f"invalid_json:{exc}") from exc


def load_path(path: Path) -> Any:
    try:
        return load_text(path.read_text(encoding="utf-8"))
    except ProfileError:
        raise
    except OSError as exc:
        raise ProfileError(f"read_error:{exc}") from exc


def _obj(value: Any, allowed: Iterable[str], path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ProfileError(f"{path}:object_required")
    allowed_set = set(allowed)
    unknown = set(value) - allowed_set
    if unknown:
        raise ProfileError(f"{path}:unknown_fields:{','.join(sorted(unknown))}")
    return value


def _required(value: dict[str, Any], key: str, path: str) -> Any:
    if key not in value:
        raise ProfileError(f"{path}:missing:{key}")
    return value[key]


def _text(value: Any, path: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ProfileError(f"{path}:nonempty_string_required")
    return value


def _uri(value: Any, path: str) -> str:
    value = _text(value, path)
    if not URI.fullmatch(value):
        raise ProfileError(f"{path}:uri_required")
    return value


def _time(value: Any, path: str) -> datetime:
    value = _text(value, path)
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ProfileError(f"{path}:invalid_time") from exc
    if parsed.tzinfo is None:
        raise ProfileError(f"{path}:timezone_required")
    return parsed.astimezone(timezone.utc)


def _sha(value: Any, path: str) -> str:
    value = _text(value, path)
    if not HEX64.fullmatch(value):
        raise ProfileError(f"{path}:lowercase_sha256_required")
    return value


def _domain_hash(domain: bytes, value: Any) -> str:
    payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(domain + payload).hexdigest()


def _source_identity(value: Any, path: str) -> dict[str, Any]:
    item = _obj(value, {"head", "dirty_status_digest", "patch_digest", "submodule_closure", "identity_sha256"}, path)
    head = _text(_required(item, "head", path), f"{path}.head").lower()
    if not HEX40.fullmatch(head):
        raise ProfileError(f"{path}.head:sha1_required")
    status = _sha(_required(item, "dirty_status_digest", path), f"{path}.dirty_status_digest")
    patch = _sha(_required(item, "patch_digest", path), f"{path}.patch_digest")
    closure = _text(_required(item, "submodule_closure", path), f"{path}.submodule_closure")
    supplied = _sha(_required(item, "identity_sha256", path), f"{path}.identity_sha256")
    body = {"head": head, "dirty_status_digest": status, "patch_digest": patch, "submodule_closure": closure}
    computed = _domain_hash(DOMAIN_SOURCE, body)
    if supplied != computed:
        raise ProfileError(f"{path}.identity_sha256:recomputed_hash_mismatch")
    return {**body, "identity_sha256": supplied}


def _integrity(value: Any, mapping: dict[str, Any], source: dict[str, Any]) -> dict[str, Any]:
    item = _obj(value, {"declaration_sha256", "source_sha256", "signature_payload", "receipt"}, "mapping.integrity")
    declaration = _sha(_required(item, "declaration_sha256", "mapping.integrity"), "mapping.integrity.declaration_sha256")
    source_hash = _sha(_required(item, "source_sha256", "mapping.integrity"), "mapping.integrity.source_sha256")
    expected_source = source["identity_sha256"]
    if source_hash != expected_source:
        raise ProfileError("mapping.integrity.source_sha256:expected_source_identity_mismatch")
    payload = _obj(_required(item, "signature_payload", "mapping.integrity"), {"algorithm", "key_id", "declaration_sha256", "source_sha256", "nonce", "sequence", "payload_sha256"}, "mapping.integrity.signature_payload")
    if payload["algorithm"] != mapping["signature"]["algorithm"] or payload["key_id"] != mapping["signature"]["key_id"]:
        raise ProfileError("mapping.integrity.signature_payload:signer_mismatch")
    if payload["declaration_sha256"] != declaration or payload["source_sha256"] != source_hash:
        raise ProfileError("mapping.integrity.signature_payload:hash_mismatch")
    _text(_required(payload, "nonce", "mapping.integrity.signature_payload"), "mapping.integrity.signature_payload.nonce")
    sequence = _required(payload, "sequence", "mapping.integrity.signature_payload")
    if sequence != mapping["anti_replay"]["sequence"]:
        raise ProfileError("mapping.integrity.signature_payload:sequence_mismatch")
    supplied_payload = _sha(_required(payload, "payload_sha256", "mapping.integrity.signature_payload"), "mapping.integrity.signature_payload.payload_sha256")
    payload_body = {key: payload[key] for key in ("algorithm", "key_id", "declaration_sha256", "source_sha256", "nonce", "sequence")}
    if supplied_payload != _domain_hash(DOMAIN_SIGNATURE_PAYLOAD, payload_body):
        raise ProfileError("mapping.integrity.signature_payload:recomputed_hash_mismatch")
    receipt = _obj(_required(item, "receipt", "mapping.integrity"), {"declaration_sha256", "source_sha256", "signature_payload_sha256"}, "mapping.integrity.receipt")
    if receipt["declaration_sha256"] != declaration or receipt["source_sha256"] != source_hash or receipt["signature_payload_sha256"] != supplied_payload:
        raise ProfileError("mapping.integrity.receipt:hash_mismatch")
    return {"declaration_sha256": declaration, "source_sha256": source_hash, "signature_payload_sha256": supplied_payload}


def _string_list(value: Any, path: str, *, nonempty: bool = False) -> list[str]:
    if not isinstance(value, list) or (nonempty and not value):
        raise ProfileError(f"{path}:list_required")
    if any(not isinstance(item, str) or not item.strip() for item in value):
        raise ProfileError(f"{path}:nonempty_strings_required")
    return value


def _edge(value: Any, path: str) -> tuple[str, str]:
    edge = _obj(value, {"ref", "sha256"}, path)
    return _uri(_required(edge, "ref", path), f"{path}.ref"), _sha(
        _required(edge, "sha256", path), f"{path}.sha256"
    )


def _absence(value: Any) -> dict[str, Any]:
    absence = _obj(
        value,
        {"code", "owner", "authoritative_source", "authority_ref", "recovery_condition", "expiry_condition"},
        "profile.absence",
    )
    for key in ("code", "owner", "authoritative_source", "recovery_condition", "expiry_condition"):
        _text(_required(absence, key, "profile.absence"), f"profile.absence.{key}")
    authority = _obj(_required(absence, "authority_ref", "profile.absence"), {"state", "value"}, "profile.absence.authority_ref")
    if _required(authority, "state", "profile.absence.authority_ref") != "typed_absent" or authority.get("value") is not None:
        raise ProfileError("profile.absence.authority_ref:typed_absent_required")
    return absence


def _validate_axes(value: Any, mapping: dict[str, Any]) -> dict[str, Any]:
    axes_doc = _obj(value, {"ref", "sha256", "axes"}, "mapping.four_axis_evidence")
    axis_ref = _uri(_required(axes_doc, "ref", "mapping.four_axis_evidence"), "mapping.four_axis_evidence.ref")
    axis_hash = _sha(_required(axes_doc, "sha256", "mapping.four_axis_evidence"), "mapping.four_axis_evidence.sha256")
    entries = _required(axes_doc, "axes", "mapping.four_axis_evidence")
    if not isinstance(entries, list) or len(entries) != 4:
        raise ProfileError("mapping.four_axis_evidence.axes:exactly_four_required")
    seen: set[str] = set()
    evidence_refs: set[str] = set()
    for index, entry in enumerate(entries):
        path = f"mapping.four_axis_evidence.axes[{index}]"
        item = _obj(entry, {"axis_id", "version", "evidence_ref", "sha256"}, path)
        axis_id = _text(_required(item, "axis_id", path), f"{path}.axis_id")
        if axis_id in seen:
            raise ProfileError(f"{path}.axis_id:duplicate:{axis_id}")
        seen.add(axis_id)
        if axis_id not in AXES:
            raise ProfileError(f"{path}.axis_id:unknown:{axis_id}")
        version = _text(_required(item, "version", path), f"{path}.version")
        if not VERSION.fullmatch(version):
            raise ProfileError(f"{path}.version:immutable_version_required")
        evidence_ref = _uri(_required(item, "evidence_ref", path), f"{path}.evidence_ref")
        if evidence_ref in evidence_refs:
            raise ProfileError(f"{path}.evidence_ref:duplicate:{evidence_ref}")
        evidence_refs.add(evidence_ref)
        _sha(_required(item, "sha256", path), f"{path}.sha256")
    if seen != AXES:
        missing = sorted(AXES - seen)
        raise ProfileError(f"mapping.four_axis_evidence.axes:missing:{','.join(missing)}")
    if axis_ref != mapping["four_axis_evidence_ref"]:
        raise ProfileError("mapping.four_axis_evidence.ref:binding_mismatch")
    return {"ref": axis_ref, "sha256": axis_hash, "axis_ids": sorted(seen)}


def _validate_edges(mapping: dict[str, Any]) -> dict[str, Any]:
    allowed = {
        "source_candidate_edge",
        "candidate_source_edge",
        "candidate_four_axis_evidence_edge",
        "four_axis_evidence_candidate_edge",
        "four_axis_evidence_g2_edge",
        "g2_four_axis_evidence_edge",
    }
    edges = _obj(_required(mapping, "binding_edges", "mapping"), allowed, "mapping.binding_edges")
    names = [
        ("source_candidate_edge", "candidate_source_edge", "candidate_ref", "source_ref", "source_candidate"),
        (
            "candidate_four_axis_evidence_edge",
            "four_axis_evidence_candidate_edge",
            "four_axis_evidence_ref",
            "candidate_ref",
            "candidate_four_axis_evidence",
        ),
        (
            "four_axis_evidence_g2_edge",
            "g2_four_axis_evidence_edge",
            "g2_ref",
            "four_axis_evidence_ref",
            "four_axis_evidence_g2",
        ),
    ]
    result: dict[str, Any] = {}
    for forward_name, reverse_name, forward_dest, reverse_dest, label in names:
        f_ref, f_hash = _edge(_required(edges, forward_name, "mapping.binding_edges"), f"mapping.binding_edges.{forward_name}")
        r_ref, r_hash = _edge(_required(edges, reverse_name, "mapping.binding_edges"), f"mapping.binding_edges.{reverse_name}")
        if f_ref != mapping[forward_dest] or r_ref != mapping[reverse_dest] or f_hash != r_hash:
            raise ProfileError(f"mapping.binding_edges.{label}:bidirectional_mismatch")
        result[label] = {"ref": f_ref, "sha256": f_hash}
    return result


def _expected_binding(value: Any, mapping: dict[str, Any]) -> dict[str, Any]:
    expected = _obj(value, {"schema", "candidate_id", "candidate_ref", "source_ref", "source_version", "source_identity", "four_axis_materials"}, "expected_binding")
    if _required(expected, "schema", "expected_binding") != "UP1.g2-expected-binding.v1":
        raise ProfileError("expected_binding.schema:unsupported")
    candidate_id = _text(_required(expected, "candidate_id", "expected_binding"), "expected_binding.candidate_id")
    candidate_ref = _uri(_required(expected, "candidate_ref", "expected_binding"), "expected_binding.candidate_ref")
    source_ref = _uri(_required(expected, "source_ref", "expected_binding"), "expected_binding.source_ref")
    source_version = _text(_required(expected, "source_version", "expected_binding"), "expected_binding.source_version")
    if candidate_id != mapping["candidate_id"] or candidate_ref != mapping["candidate_ref"]:
        raise ProfileError("expected_binding:candidate_id_or_ref_mismatch")
    if source_ref != mapping["source_ref"] or source_version != mapping["source_version"]:
        raise ProfileError("expected_binding:source_ref_or_version_mismatch")
    source = _source_identity(_required(expected, "source_identity", "expected_binding"), "expected_binding.source_identity")
    profile_source = _source_identity(mapping["source_identity"], "mapping.source_identity")
    if source != profile_source:
        raise ProfileError("expected_binding:source_identity_mismatch")
    materials = _required(expected, "four_axis_materials", "expected_binding")
    if not isinstance(materials, list) or len(materials) != 4:
        raise ProfileError("expected_binding.four_axis_materials:exactly_four_required")
    expected_axes: dict[str, tuple[str, str, str]] = {}
    for index, raw in enumerate(materials):
        path = f"expected_binding.four_axis_materials[{index}]"
        item = _obj(raw, {"axis_id", "version", "evidence_ref", "material_sha256"}, path)
        axis_id = _text(_required(item, "axis_id", path), f"{path}.axis_id")
        if axis_id in expected_axes or axis_id not in AXES:
            raise ProfileError(f"{path}.axis_id:duplicate_or_unknown")
        expected_axes[axis_id] = (
            _text(_required(item, "version", path), f"{path}.version"),
            _uri(_required(item, "evidence_ref", path), f"{path}.evidence_ref"),
            _sha(_required(item, "material_sha256", path), f"{path}.material_sha256"),
        )
    if set(expected_axes) != AXES:
        raise ProfileError("expected_binding.four_axis_materials:axis_set_mismatch")
    actual_axes = {item["axis_id"]: (item["version"], item["evidence_ref"], item["sha256"]) for item in mapping["four_axis_evidence"]["axes"]}
    if actual_axes != expected_axes:
        raise ProfileError("expected_binding:four_axis_materials_mismatch")
    return {"candidate_id": candidate_id, "candidate_ref": candidate_ref, "source_ref": source_ref, "source_version": source_version, "source_identity": source, "four_axis_materials": expected_axes}


def canonical_declaration_bytes(mapping: dict[str, Any]) -> bytes:
    """Return canonical declaration bytes, excluding only the integrity receipt."""
    declaration = {key: value for key, value in mapping.items() if key != "integrity"}
    return json.dumps(declaration, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def validate_profile(profile: Any, expected_binding: Any = None) -> dict[str, Any]:
    top = _obj(profile, {"schema", "fixture_role", "status", "production_present_admission", "mapping", "absence"}, "profile")
    if _required(top, "schema", "profile") != SCHEMA:
        raise ProfileError("profile.schema:unsupported")
    fixture_role = _text(_required(top, "fixture_role", "profile"), "profile.fixture_role")
    status = _text(_required(top, "status", "profile"), "profile.status")
    admission = _required(top, "production_present_admission", "profile")
    if not isinstance(admission, bool):
        raise ProfileError("profile.production_present_admission:boolean_required")
    mapping = top["mapping"]
    absence = top["absence"]
    if status == "typed_absent":
        if mapping is not None or admission is not False:
            raise ProfileError("typed_absence:mapping_must_be_null_and_non_admissible")
        _absence(absence)
        return {"fixture_role": fixture_role, "status": status, "production_admissible": False}
    if absence is not None:
        raise ProfileError("profile.absence:null_required_for_present_profile")
    if status not in {"present", "test_only"} or not isinstance(mapping, dict):
        raise ProfileError("profile:present_mapping_required")

    allowed = {
        "namespace", "version", "effective_interval", "issuer", "trust_root", "signature", "revocation",
        "anti_replay", "ambiguity", "conflict", "source_ref", "candidate_ref", "four_axis_evidence_ref",
        "g2_ref", "candidate_id", "source_version", "source_identity", "four_axis_evidence", "binding_edges", "integrity",
    }
    mapping = _obj(mapping, allowed, "mapping")
    namespace = _uri(_required(mapping, "namespace", "mapping"), "mapping.namespace")
    if namespace != REGISTERED_NAMESPACE:
        raise ProfileError("mapping.namespace:foreign_namespace")
    version = _text(_required(mapping, "version", "mapping"), "mapping.version")
    if not VERSION.fullmatch(version):
        raise ProfileError("mapping.version:immutable_version_required")
    interval = _obj(_required(mapping, "effective_interval", "mapping"), {"not_before", "not_after", "trusted_time"}, "mapping.effective_interval")
    not_before = _time(_required(interval, "not_before", "mapping.effective_interval"), "mapping.effective_interval.not_before")
    not_after = _time(_required(interval, "not_after", "mapping.effective_interval"), "mapping.effective_interval.not_after")
    trusted = _time(_required(interval, "trusted_time", "mapping.effective_interval"), "mapping.effective_interval.trusted_time")
    if not_before >= not_after or not_before > trusted or trusted > not_after:
        raise ProfileError("mapping.effective_interval:invalid_interval_or_trusted_time")

    issuer = _obj(_required(mapping, "issuer", "mapping"), {"id", "chain"}, "mapping.issuer")
    issuer_id = _text(_required(issuer, "id", "mapping.issuer"), "mapping.issuer.id")
    chain = _string_list(_required(issuer, "chain", "mapping.issuer"), "mapping.issuer.chain", nonempty=True)

    trust = _obj(_required(mapping, "trust_root", "mapping"), {"ref", "fingerprint", "policy_oid", "eku", "key_usage", "name_constraints"}, "mapping.trust_root")
    trust_ref = _uri(_required(trust, "ref", "mapping.trust_root"), "mapping.trust_root.ref")
    fingerprint = _sha(_required(trust, "fingerprint", "mapping.trust_root"), "mapping.trust_root.fingerprint")
    policy_oid = _text(_required(trust, "policy_oid", "mapping.trust_root"), "mapping.trust_root.policy_oid")
    if not OID.fullmatch(policy_oid):
        raise ProfileError("mapping.trust_root.policy_oid:oid_required")
    eku = _string_list(_required(trust, "eku", "mapping.trust_root"), "mapping.trust_root.eku", nonempty=True)
    key_usage = _string_list(_required(trust, "key_usage", "mapping.trust_root"), "mapping.trust_root.key_usage", nonempty=True)
    name_constraints = _string_list(_required(trust, "name_constraints", "mapping.trust_root"), "mapping.trust_root.name_constraints")

    signature = _obj(_required(mapping, "signature", "mapping"), {"algorithm", "signature_bytes", "key_id", "certificate_chain", "trust_root_ref"}, "mapping.signature")
    algorithm = _text(_required(signature, "algorithm", "mapping.signature"), "mapping.signature.algorithm")
    if algorithm not in ALGORITHMS:
        raise ProfileError("mapping.signature.algorithm:unsupported")
    signature_bytes = _text(_required(signature, "signature_bytes", "mapping.signature"), "mapping.signature.signature_bytes")
    key_id = _text(_required(signature, "key_id", "mapping.signature"), "mapping.signature.key_id")
    certs = _string_list(_required(signature, "certificate_chain", "mapping.signature"), "mapping.signature.certificate_chain", nonempty=True)
    if _uri(_required(signature, "trust_root_ref", "mapping.signature"), "mapping.signature.trust_root_ref") != trust_ref:
        raise ProfileError("mapping.signature.trust_root_ref:binding_mismatch")

    rev = _obj(_required(mapping, "revocation", "mapping"), {"status", "source", "checked_at", "freshness_seconds"}, "mapping.revocation")
    if _required(rev, "status", "mapping.revocation") != "not_revoked":
        raise ProfileError("mapping.revocation.status:not_revoked_required")
    _uri(_required(rev, "source", "mapping.revocation"), "mapping.revocation.source")
    checked = _time(_required(rev, "checked_at", "mapping.revocation"), "mapping.revocation.checked_at")
    freshness = _required(rev, "freshness_seconds", "mapping.revocation")
    if not isinstance(freshness, int) or isinstance(freshness, bool) or not 0 < freshness <= 86400:
        raise ProfileError("mapping.revocation.freshness_seconds:bounded_positive_integer_required")
    age = (trusted - checked).total_seconds()
    if checked > trusted or age > freshness:
        raise ProfileError("mapping.revocation:freshness_expired")

    anti = _obj(_required(mapping, "anti_replay", "mapping"), {"enabled", "nonce", "sequence", "idempotency_key", "replay_status"}, "mapping.anti_replay")
    if _required(anti, "enabled", "mapping.anti_replay") is not True:
        raise ProfileError("mapping.anti_replay.enabled:true_required")
    nonce = _text(_required(anti, "nonce", "mapping.anti_replay"), "mapping.anti_replay.nonce")
    if len(nonce) < 8:
        raise ProfileError("mapping.anti_replay.nonce:too_short")
    sequence = _required(anti, "sequence", "mapping.anti_replay")
    if not isinstance(sequence, int) or isinstance(sequence, bool) or sequence < 0:
        raise ProfileError("mapping.anti_replay.sequence:nonnegative_integer_required")
    idem = _text(_required(anti, "idempotency_key", "mapping.anti_replay"), "mapping.anti_replay.idempotency_key")
    if _required(anti, "replay_status", "mapping.anti_replay") != "not_replayed":
        raise ProfileError("mapping.anti_replay.replay_status:not_replayed_required")

    ambiguity = _obj(_required(mapping, "ambiguity", "mapping"), {"state", "competing_entries", "decision"}, "mapping.ambiguity")
    competing = _required(ambiguity, "competing_entries", "mapping.ambiguity")
    if _required(ambiguity, "state", "mapping.ambiguity") != "none" or competing != [] or _required(ambiguity, "decision", "mapping.ambiguity") != "unique":
        raise ProfileError("mapping.ambiguity:unique_required")
    conflict = _obj(_required(mapping, "conflict", "mapping"), {"state", "conflicts", "resolution"}, "mapping.conflict")
    if _required(conflict, "state", "mapping.conflict") != "none" or _required(conflict, "conflicts", "mapping.conflict") != [] or _required(conflict, "resolution", "mapping.conflict") != "none":
        raise ProfileError("mapping.conflict:no_conflict_required")

    for key in ("source_ref", "candidate_ref", "four_axis_evidence_ref", "g2_ref"):
        mapping[key] = _uri(_required(mapping, key, "mapping"), f"mapping.{key}")
    candidate_id = _text(_required(mapping, "candidate_id", "mapping"), "mapping.candidate_id")
    source_version = _text(_required(mapping, "source_version", "mapping"), "mapping.source_version")
    source = _source_identity(_required(mapping, "source_identity", "mapping"), "mapping.source_identity")
    expected = None
    if expected_binding is not None:
        expected = _expected_binding(expected_binding, mapping)
    elif fixture_role == "PRODUCTION":
        raise ProfileError("expected_binding:independent_context_required")
    if expected is not None:
        source_for_hash = expected["source_identity"]
    else:
        source_for_hash = source
    if len({mapping["source_ref"], mapping["candidate_ref"], mapping["four_axis_evidence_ref"], mapping["g2_ref"]}) != 4:
        raise ProfileError("mapping.refs:unique_refs_required")
    axes = _validate_axes(_required(mapping, "four_axis_evidence", "mapping"), mapping)
    edges = _validate_edges(mapping)
    declaration_hash = _domain_hash(DOMAIN_DECLARATION, json.loads(canonical_declaration_bytes(mapping).decode("utf-8")))
    integrity_input = _obj(_required(mapping, "integrity", "mapping"), {"declaration_sha256", "source_sha256", "signature_payload", "receipt"}, "mapping.integrity")
    supplied_declaration = _sha(_required(integrity_input, "declaration_sha256", "mapping.integrity"), "mapping.integrity.declaration_sha256")
    if supplied_declaration != declaration_hash:
        raise ProfileError("mapping.integrity.declaration_sha256:recomputed_hash_mismatch")
    integrity = _integrity(_required(mapping, "integrity", "mapping"), mapping, source_for_hash)
    details = {
        "namespace": namespace,
        "version": version,
        "issuer": issuer_id,
        "signature_algorithm": algorithm,
        "key_id": key_id,
        "trust_root_ref": trust_ref,
        "trust_root_fingerprint": fingerprint,
        "policy_oid": policy_oid,
        "eku": eku,
        "key_usage": key_usage,
        "name_constraints": name_constraints,
        "revocation": "not_revoked",
        "freshness_seconds": freshness,
        "nonce": nonce,
        "sequence": sequence,
        "idempotency_key": idem,
        "replay": "not_replayed",
        "axes": axes,
        "binding_edges": edges,
        "candidate_id": candidate_id,
        "source_version": source_version,
        "declaration_sha256": declaration_hash,
        "source_sha256": integrity["source_sha256"],
        "signature_payload_sha256": integrity["signature_payload_sha256"],
    }
    return {"fixture_role": fixture_role, "status": status, "production_admissible": bool(admission), "details": details, "expected_binding": expected}


def evaluate(profile: Any, expected_binding: Any = None) -> dict[str, Any]:
    result = validate_profile(profile, expected_binding)
    if result["status"] == "typed_absent":
        return {"accepted": True, "decision": "typed_absence", "production_admissible": False, "reason": "authoritative_mapping_not_supplied"}
    if result["fixture_role"] == "TEST_ONLY" or result["status"] == "test_only" or not result["production_admissible"]:
        return {"accepted": True, "decision": "non_evidence", "production_admissible": False, "reason": "TEST_ONLY_or_nonproduction", "details": result["details"]}
    if result["fixture_role"] != "PRODUCTION" or result["status"] != "present":
        raise ProfileError("production_admission:explicit_present_profile_required")
    return {"accepted": False, "decision": "fail_closed", "production_admissible": False, "authority_verified": False, "reason": "external_authority_signature_not_verified", "details": result["details"]}


def main(argv: list[str]) -> int:
    if len(argv) not in {2, 4} or (len(argv) == 4 and argv[2] != "--expected"):
        print(json.dumps({"accepted": False, "decision": "usage", "usage": "production_g2_mapping.py PROFILE [--expected EXPECTED_BINDING]"}, separators=(",", ":")))
        return 2
    try:
        expected = load_path(Path(argv[3])) if len(argv) == 4 else None
        result = evaluate(load_path(Path(argv[1])), expected)
    except Exception as exc:
        result = {"accepted": False, "decision": "fail_closed", "error": str(exc)}
        print(json.dumps(result, sort_keys=True, separators=(",", ":")))
        return 1
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0 if result.get("accepted") is True else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
