"""Fail-closed validator for the UP1 R2 witness/authority seam.

The validator has no network, clock, key-store, or credential dependency.
The caller may provide a trusted observation time for deterministic tests;
otherwise the current UTC time is only recorded in the result and is never a
substitute for trusted external time evidence.

There are three intentionally different outcomes:

* ``typed_absence``: an external fact (real witness, endpoint, signature or
  acknowledgement) is not supplied, so the parent gate remains deferred.
* ``fail_closed``: supplied data is malformed, contradictory, foreign,
  duplicated, or cannot be bound to the exact candidate.
* ``non_evidence``: TEST_ONLY material was evaluated for software behavior.

No outcome from this module closes UP1 or any R01-R10 gate.
"""

from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime, timezone
from typing import Any, Iterable, Mapping, MutableMapping, Optional

SCHEMA = "UP1.external_closure_r2.witness_authority.v1"
HEX64 = re.compile(r"^[0-9a-f]{64}$")
ABSENCE = {"", "typed_absence", "absent", "none", "null", "unspecified", "not_supplied"}
TEST_MARKERS = ("TEST/", "TEST_ONLY", "PLACEHOLDER", "fixture_only", "example_only")

LAYER_NAMES = ("G1", "G2", "G3")
AXIS_NAMES = ("schema", "canonical", "profile", "candidate_binding")


class DuplicateKeyError(ValueError):
    """Raised when strict JSON contains an object member more than once."""


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in pairs:
        if key in out:
            raise DuplicateKeyError(f"duplicate JSON key: {key}")
        out[key] = value
    return out


def parse_json(text: str) -> Any:
    """Parse one strict JSON value, rejecting duplicate keys and NaN values."""

    def reject_constant(value: str) -> None:
        raise ValueError(f"non-standard JSON constant: {value}")

    return json.loads(text, object_pairs_hook=_pairs, parse_constant=reject_constant)


def canonical_json(value: Any) -> str:
    """Canonical JSON used for local digest comparisons."""

    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"),
                      allow_nan=False)


def sha256_json(value: Any) -> str:
    return hashlib.sha256(canonical_json(value).encode("utf-8")).hexdigest()


def _utc() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _hex(value: Any) -> bool:
    return isinstance(value, str) and bool(HEX64.fullmatch(value))


def _contains_marker(value: Any) -> bool:
    if isinstance(value, str):
        upper = value.upper()
        return any(marker.upper() in upper for marker in TEST_MARKERS)
    if isinstance(value, Mapping):
        # Oracle/documentation metadata is deliberately outside the decision
        # boundary; a fixture's ``expected`` value must never turn production
        # data into a marker or influence classification.
        ignored = {"expected", "oracle", "comment", "fixture_kind"}
        return any(key not in ignored and (_contains_marker(key) or _contains_marker(v))
                   for key, v in value.items())
    if isinstance(value, (list, tuple)):
        return any(_contains_marker(v) for v in value)
    return False


def _is_absent(value: Any) -> bool:
    return value is None or (isinstance(value, str) and value.strip().lower() in ABSENCE)


class _Failure(Exception):
    def __init__(self, code: str, detail: str, path: str = "") -> None:
        super().__init__(detail)
        self.code, self.detail, self.path = code, detail, path


class _ExternalAbsence(Exception):
    """A structurally valid request whose external fact is not available."""

    def __init__(self, code: str, detail: str, path: str) -> None:
        super().__init__(detail)
        self.code, self.detail, self.path = code, detail, path


def _check_object(value: Any, allowed: Iterable[str], path: str) -> None:
    """Reject unversioned extensions at every public object boundary."""
    if not isinstance(value, Mapping):
        raise _Failure("ERR_INVALID_OBJECT", f"{path} must be an object", path)
    unknown = sorted(set(value) - set(allowed))
    if unknown:
        raise _Failure("ERR_UNKNOWN_FIELD", f"unknown field(s): {','.join(unknown)}", f"{path}.{unknown[0]}")


def _reject_alias(value: Mapping[str, Any], alias: str, canonical: str, path: str) -> None:
    """Reject a semantic alias instead of choosing one representation."""
    if alias in value:
        code = "ERR_ALIAS_CONFLICT" if canonical in value else "ERR_UNKNOWN_FIELD"
        raise _Failure(code, f"legacy alias '{alias}' is not accepted; use '{canonical}'", f"{path}.{alias}")


_ROOT_FIELDS = {
    "mode", "request_id", "idempotency_key", "nonce", "requested_at_trusted_time",
    "witness_scope", "attestation_sha256", "candidate_id", "canonical_object_sha256",
    "source_revision", "source_locator", "source_version", "layer_refs", "four_axis_refs",
    "witness", "authority",
}
_CANDIDATE_FIELDS = {
    "candidate_id", "canonical_object_sha256", "source_revision", "source_locator", "source_version",
    "layer_refs", "four_axis_refs",
}
_BINDING_FIELDS = {"candidate_id", "ref", "sha256", "version"}
_WITNESS_FIELDS = {
    "identity", "independence_declaration", "evidence_candidates", "signature_material",
}
_IDENTITY_FIELDS = {"name", "organization"}
_INDEPENDENCE_FIELDS = {
    "statement", "scope", "conflict_disclosure", "external_attestation",
}
_ATTESTATION_FIELDS = {
    "attestation_id", "provider", "ref", "digest", "verifier_ref", "verifier_version",
    "candidate_id", "subject_object_sha256", "status",
}
_EVIDENCE_FIELDS = {
    "evidence_id", "candidate_id", "canonical_object_sha256",
    "source_revision", "source_locator", "source_version", "layer_refs", "four_axis_refs",
}
_SIGNATURE_FIELDS = {"ref", "algorithm", "signature", "digest", "scope", "subject_object_sha256"}
_AUTHORITY_FIELDS = {"endpoint", "ack"}
_ENDPOINT_FIELDS = {"uri", "owner", "transport", "authentication", "trust_root_ref", "verifier_ref", "verifier_version"}
_ACK_FIELDS = {
    "ack_id", "request_id", "idempotency_key", "accepted_object_sha256", "authority_decision",
    "received_at_trusted_time", "verifier_ref", "verifier_version", "receipt_signature", "receipt_sha256",
}


def _canonical_request_digest(record: Mapping[str, Any]) -> str:
    # All accepted root fields are included.  This deliberately differs from
    # the candidate object digest: source, axes, witness and authority changes
    # must conflict under a reused idempotency key.
    return sha256_json(record)


def _reject_legacy_aliases(record: Mapping[str, Any]) -> None:
    """Walk semantic boundaries before any absence shortcut can hide aliases."""
    _reject_alias(record, "object_sha256", "canonical_object_sha256", "root")
    _reject_alias(record, "candidate", "candidate_id", "root")
    _reject_alias(record, "layers", "layer_refs", "root")
    _reject_alias(record, "axes", "four_axis_refs", "root")
    _reject_alias(record, "axis_refs", "four_axis_refs", "root")
    witness = record.get("witness")
    if isinstance(witness, Mapping):
        for alias, canonical in (("independence", "independence_declaration"), ("evidence", "evidence_candidates"),
                                 ("signature_material_ref", "signature_material"), ("signature", "signature_material"),
                                 ("signature_ref", "signature_material"), ("signature_algorithm", "signature_material")):
            _reject_alias(witness, alias, canonical, "witness")
        identity = witness.get("identity")
        if isinstance(identity, Mapping):
            _reject_alias(identity, "witness_name", "name", "witness.identity")
            _reject_alias(identity, "institution", "organization", "witness.identity")
        independence = witness.get("independence_declaration")
        if isinstance(independence, Mapping):
            _reject_alias(independence, "conflicts", "conflict_disclosure", "witness.independence_declaration")
        evidence = witness.get("evidence_candidates")
        if isinstance(evidence, list):
            for index, item in enumerate(evidence):
                if isinstance(item, Mapping):
                    _reject_alias(item, "object_sha256", "canonical_object_sha256", f"witness.evidence_candidates[{index}]")
    authority = record.get("authority")
    if isinstance(authority, Mapping):
        _reject_alias(authority, "receipt", "ack", "authority")
        endpoint = authority.get("endpoint")
        if isinstance(endpoint, Mapping):
            _reject_alias(endpoint, "endpoint", "uri", "authority.endpoint")


class AuthorityLedger:
    """In-memory replay ledger; it never writes or talks to an authority."""

    def __init__(self) -> None:
        self._requests: dict[str, str] = {}
        self._acks: dict[str, str] = {}

    def validate(self, record: Mapping[str, Any], *, now: Optional[str] = None) -> dict[str, Any]:
        return _validate(record, ledger=self, now=now)


def _result(*, status: str, resolution: str, code: str, detail: str,
            request_id: Optional[str], mode: str, started: str, now: str,
            path: str = "", non_evidence: bool = False) -> dict[str, Any]:
    return {
        "schema": SCHEMA,
        "status": status,
        "resolution": resolution,
        "terminal_deferred": resolution == "typed_absence" and status == "typed_absence",
        "error_code": code,
        "error_path": path,
        "detail": detail,
        "request_id": request_id,
        "mode": mode,
        "non_evidence": bool(non_evidence),
        "no_publish": True,
        "claim_ceiling": "preparation_only",
        "r01_r10_closed": False,
        "started_at_utc": started,
        "ended_at_utc": now,
    }


def _absence(code: str, detail: str, record: Mapping[str, Any], started: str,
             now: str, path: str = "") -> dict[str, Any]:
    mode = str(record.get("mode", "PRODUCTION"))
    test = mode == "TEST_ONLY"
    return _result(status="non_evidence" if test else "typed_absence",
                   resolution="typed_absence", code=code, detail=detail,
                   request_id=record.get("request_id"), mode=mode,
                   started=started, now=now, path=path, non_evidence=test)


def _require_text(record: Mapping[str, Any], key: str, path: str = "") -> str:
    value = record.get(key)
    if not _text(value):
        raise _Failure("ERR_MISSING_FIELD", f"required non-empty string: {key}", path or key)
    return value


def _candidate(record: Mapping[str, Any]) -> dict[str, Any]:
    out = {
        "candidate_id": record.get("candidate_id"),
        "canonical_object_sha256": record.get("canonical_object_sha256"),
        "source_revision": record.get("source_revision"),
        "source_locator": record.get("source_locator"),
        "source_version": record.get("source_version"),
        "layer_refs": record.get("layer_refs"),
        "four_axis_refs": record.get("four_axis_refs"),
    }
    _reject_alias(record, "object_sha256", "canonical_object_sha256", "root")
    _reject_alias(record, "candidate", "candidate_id", "root")
    _reject_alias(record, "layers", "layer_refs", "root")
    _reject_alias(record, "axes", "four_axis_refs", "root")
    _reject_alias(record, "axis_refs", "four_axis_refs", "root")
    for key in ("candidate_id", "source_revision", "source_locator", "source_version"):
        if not _text(out[key]):
            raise _Failure("ERR_MISSING_FIELD", f"candidate.{key} is required", f"candidate.{key}")
    if not _hex(out["canonical_object_sha256"]):
        raise _Failure("ERR_INVALID_OBJECT_HASH", "candidate canonical object hash must be 64 lowercase hex", "candidate.canonical_object_sha256")
    for group_name, names in (("layer_refs", LAYER_NAMES), ("four_axis_refs", AXIS_NAMES)):
        refs = out[group_name]
        if not isinstance(refs, Mapping):
            raise _Failure("ERR_MISSING_FIELD", f"candidate.{group_name} is required", f"candidate.{group_name}")
        if set(refs) != set(names):
            raise _Failure("ERR_AXIS_OR_LAYER_SET", f"candidate.{group_name} must contain exactly {','.join(names)}", f"candidate.{group_name}")
        for name in names:
            item = refs[name]
            if not isinstance(item, Mapping):
                raise _Failure("ERR_INVALID_BINDING", f"{group_name}.{name} must be an object", f"candidate.{group_name}.{name}")
            _check_object(item, _BINDING_FIELDS, f"candidate.{group_name}.{name}")
            cid = item.get("candidate_id")
            if cid != out["candidate_id"]:
                code = "ERR_FOREIGN_LAYER_CANDIDATE" if group_name == "layer_refs" else "ERR_FOREIGN_AXIS_CANDIDATE"
                raise _Failure(code, f"{group_name}.{name} candidate_id is foreign", f"candidate.{group_name}.{name}.candidate_id")
            required_ok = (_text(item.get("ref")) and _hex(item.get("sha256")) and
                           _text(item.get("version")))
            if not required_ok:
                raise _Failure("ERR_MISSING_FIELD", f"{group_name}.{name} requires ref, sha256 and version", f"candidate.{group_name}.{name}")
    return out


def _validate_witness(record: Mapping[str, Any], candidate: Mapping[str, Any]) -> Optional[dict[str, Any]]:
    witness = record.get("witness")
    if witness is None:
        witness = record
    if not isinstance(witness, Mapping):
        raise _Failure("ERR_INVALID_WITNESS", "witness must be an object", "witness")
    # When witness is the root compatibility form, root validation already
    # rejected unknown fields.  Nested witness objects have their own boundary.
    if record.get("witness") is not None:
        _reject_alias(witness, "independence", "independence_declaration", "witness")
        _reject_alias(witness, "evidence", "evidence_candidates", "witness")
        _reject_alias(witness, "signature_material_ref", "signature_material", "witness")
        _reject_alias(witness, "signature", "signature_material", "witness")
        _reject_alias(witness, "signature_ref", "signature_material", "witness")
        _reject_alias(witness, "signature_algorithm", "signature_material", "witness")
        _check_object(witness, _WITNESS_FIELDS, "witness")
    identity = witness.get("identity", witness)
    if not isinstance(identity, Mapping):
        raise _Failure("ERR_INVALID_WITNESS", "witness.identity must be an object", "witness.identity")
    if witness.get("identity") is not None:
        _reject_alias(identity, "witness_name", "name", "witness.identity")
        _reject_alias(identity, "institution", "organization", "witness.identity")
        _check_object(identity, _IDENTITY_FIELDS, "witness.identity")
    name = identity.get("name")
    organization = identity.get("organization")
    if _is_absent(name) or _is_absent(organization):
        raise _ExternalAbsence("ERR_WITNESS_EXTERNAL_ABSENT", "real witness identity is not supplied", "witness.identity")
    if not _text(name) or not _text(organization):
        raise _Failure("ERR_INVALID_WITNESS_IDENTITY", "witness name and organization must be non-empty", "witness.identity")
    independence = witness.get("independence_declaration")
    if not isinstance(independence, Mapping):
        raise _Failure("ERR_MISSING_FIELD", "independence declaration is required", "witness.independence_declaration")
    _check_object(independence, _INDEPENDENCE_FIELDS, "witness.independence_declaration")
    statement = independence.get("statement")
    scope = independence.get("scope")
    _reject_alias(independence, "conflicts", "conflict_disclosure", "witness.independence_declaration")
    conflicts = independence.get("conflict_disclosure")
    if not _text(statement) or not _text(scope) or conflicts is None:
        raise _Failure("ERR_MISSING_FIELD", "independence statement, scope and conflict disclosure are required", "witness.independence_declaration")
    if conflicts not in (False, "none", "NONE", "no_conflict"):
        raise _Failure("ERR_CONFLICT_DECLARED", "witness conflict disclosure is not clear", "witness.independence_declaration.conflict_disclosure")
    # Scope is a typed, canonical identifier.  Substring containment would
    # allow attacker/candidate-x/other to masquerade as candidate-x.
    if not isinstance(scope, str) or scope != candidate["candidate_id"]:
        raise _Failure("ERR_SCOPE_MISMATCH", "witness scope is not bound to candidate", "witness.independence_declaration.scope")
    external = independence.get("external_attestation")
    external_ref = None
    evidence = witness.get("evidence_candidates")
    if not isinstance(evidence, list) or not evidence:
        raise _Failure("ERR_MISSING_FIELD", "at least one evidence candidate is required", "witness.evidence_candidates")
    seen: set[str] = set()
    for index, item in enumerate(evidence):
        if not isinstance(item, Mapping):
            raise _Failure("ERR_INVALID_EVIDENCE", "evidence candidate must be an object", f"witness.evidence_candidates[{index}]")
        cid = item.get("candidate_id")
        if not _text(cid) or cid != candidate["candidate_id"]:
            raise _Failure("ERR_FOREIGN_EVIDENCE_CANDIDATE", "evidence candidate is foreign or missing candidate_id", f"witness.evidence_candidates[{index}].candidate_id")
        evidence_id = item.get("evidence_id", str(index))
        if not isinstance(evidence_id, str) or not evidence_id.strip():
            raise _Failure("ERR_INVALID_EVIDENCE_FIELD_TYPE", "evidence_id must be a non-empty string", f"witness.evidence_candidates[{index}].evidence_id")
        if evidence_id in seen:
            raise _Failure("ERR_DUPLICATE_EVIDENCE", "duplicate evidence candidate", f"witness.evidence_candidates[{index}]")
        seen.add(evidence_id)
        _check_object(item, _EVIDENCE_FIELDS, f"witness.evidence_candidates[{index}]")
        _reject_alias(item, "object_sha256", "canonical_object_sha256", f"witness.evidence_candidates[{index}]")
        digest = item.get("canonical_object_sha256")
        if digest != candidate["canonical_object_sha256"]:
            raise _Failure("ERR_EVIDENCE_HASH_MISMATCH", "evidence digest differs from candidate", f"witness.evidence_candidates[{index}]")
        for key in ("source_revision", "source_locator", "source_version"):
            if item.get(key) != candidate[key]:
                raise _Failure("ERR_EVIDENCE_SOURCE_MISMATCH", f"evidence {key} differs from candidate", f"witness.evidence_candidates[{index}].{key}")
        # A signature is only meaningful when its evidence repeats the complete
        # candidate/source/layer/axis binding.  Abbreviated evidence is not
        # upgraded to a full claim by this validator.
        for group_name, expected in (("layer_refs", LAYER_NAMES), ("four_axis_refs", AXIS_NAMES)):
            refs = item.get(group_name)
            if not isinstance(refs, Mapping) or set(refs) != set(expected):
                raise _Failure("ERR_AXIS_OR_LAYER_SET", "evidence binding set is incomplete or has aliases", f"witness.evidence_candidates[{index}].{group_name}")
            for axis, ref in refs.items():
                if not isinstance(ref, Mapping):
                    raise _Failure("ERR_INVALID_BINDING", "evidence binding must be an object", f"witness.evidence_candidates[{index}].{group_name}.{axis}")
                _check_object(ref, _BINDING_FIELDS, f"witness.evidence_candidates[{index}].{group_name}.{axis}")
                expected_ref = candidate[group_name][axis]
                if dict(ref) != dict(expected_ref):
                    code = "ERR_FOREIGN_LAYER_CANDIDATE" if group_name == "layer_refs" and ref.get("candidate_id") != candidate["candidate_id"] else "ERR_FOREIGN_AXIS_CANDIDATE" if group_name == "four_axis_refs" and ref.get("candidate_id") != candidate["candidate_id"] else "ERR_EVIDENCE_BINDING_MISMATCH"
                    raise _Failure(code, "evidence binding differs from canonical candidate binding", f"witness.evidence_candidates[{index}].{group_name}.{axis}")
    expected_signature_digest = sha256_json(_signature_binding_payload(candidate, evidence))
    signature = witness.get("signature_material")
    if signature is None or not isinstance(signature, Mapping):
        raise _ExternalAbsence("ERR_SIGNATURE_EXTERNAL_ABSENT", "signature material is not supplied", "witness.signature_material")
    _check_object(signature, _SIGNATURE_FIELDS, "witness.signature_material")
    if _is_absent(signature.get("signature")) or _is_absent(signature.get("ref")):
        raise _ExternalAbsence("ERR_SIGNATURE_EXTERNAL_ABSENT", "signature material is not supplied", "witness.signature_material")
    if not _text(signature.get("ref")) or not _text(signature.get("algorithm")) or not isinstance(signature.get("signature"), str):
        raise _Failure("ERR_INVALID_SIGNATURE_MATERIAL", "signature material requires ref and algorithm", "witness.signature_material")
    if not _hex(signature.get("digest")):
        raise _Failure("ERR_INVALID_SIGNATURE_MATERIAL", "signature material digest must be 64 lowercase hex", "witness.signature_material.digest")
    if signature["digest"] != expected_signature_digest:
        raise _Failure("ERR_SIGNATURE_BINDING_MISMATCH", "signature digest does not cover complete candidate/source/layer/axis evidence", "witness.signature_material.digest")
    if "scope" in signature and signature["scope"] != candidate["candidate_id"]:
        raise _Failure("ERR_SIGNATURE_SCOPE_MISMATCH", "signature scope is not exact candidate scope", "witness.signature_material.scope")
    if "subject_object_sha256" in signature and signature["subject_object_sha256"] != candidate["canonical_object_sha256"]:
        raise _Failure("ERR_SIGNATURE_OBJECT_MISMATCH", "signature subject digest differs from candidate", "witness.signature_material.subject_object_sha256")
    # Structural signature/evidence failures take precedence.  Only a fully
    # shaped request reaches this external-proof boundary, where self-certified
    # independence is explicitly deferred rather than admitted as authority.
    if external is None:
        if _is_absent(external_ref):
            raise _ExternalAbsence("ERR_INDEPENDENCE_EXTERNAL_ABSENT", "self-certified independence has no externally verifiable attestation", "witness.independence_declaration")
        external = {"ref": external_ref}
    if not isinstance(external, Mapping):
        raise _Failure("ERR_INVALID_ATTESTATION", "external independence attestation must be an object", "witness.independence_declaration.external_attestation")
    _check_object(external, _ATTESTATION_FIELDS, "witness.independence_declaration.external_attestation")
    for key, value in external.items():
        if not isinstance(value, str) or not value.strip():
            raise _Failure("ERR_INVALID_ATTESTATION_FIELD_TYPE", f"external attestation {key} must be a non-empty string", f"witness.independence_declaration.external_attestation.{key}")
    for key in ("ref", "digest", "verifier_ref", "verifier_version", "candidate_id", "subject_object_sha256"):
        if not _text(external.get(key)):
            raise _Failure("ERR_MISSING_ATTESTATION_FIELD", f"external attestation requires {key}", f"witness.independence_declaration.external_attestation.{key}")
    if not _hex(external["digest"]) or not _hex(external["subject_object_sha256"]):
        raise _Failure("ERR_INVALID_ATTESTATION_DIGEST", "external attestation digests must be 64 lowercase hex", "witness.independence_declaration.external_attestation")
    if external["candidate_id"] != candidate["candidate_id"] or external.get("status", "verified") not in ("verified", "valid"):
        raise _Failure("ERR_ATTESTATION_BINDING", "external independence attestation is foreign or unverified", "witness.independence_declaration.external_attestation")
    if external["subject_object_sha256"] != candidate["canonical_object_sha256"]:
        raise _Failure("ERR_ATTESTATION_OBJECT_MISMATCH", "independence attestation is bound to another object", "witness.independence_declaration.external_attestation.subject_object_sha256")
    return {"name": name, "organization": organization}


def _signature_binding_payload(candidate: Mapping[str, Any], evidence: list[Any]) -> dict[str, Any]:
    """Canonical payload whose digest is cited by signature material."""
    return {
        "candidate_id": candidate["candidate_id"],
        "canonical_object_sha256": candidate["canonical_object_sha256"],
        "source_revision": candidate["source_revision"],
        "source_locator": candidate["source_locator"],
        "source_version": candidate["source_version"],
        "layer_refs": candidate["layer_refs"],
        "four_axis_refs": candidate["four_axis_refs"],
        "evidence_candidates": evidence,
    }


def _validate_authority(record: Mapping[str, Any], candidate: Mapping[str, Any]) -> Optional[dict[str, Any]]:
    authority = record.get("authority")
    if authority is None:
        authority = {}
    if not isinstance(authority, Mapping):
        raise _Failure("ERR_INVALID_AUTHORITY", "authority must be an object", "authority")
    if record.get("authority") is not None:
        _reject_alias(authority, "receipt", "ack", "authority")
        _check_object(authority, _AUTHORITY_FIELDS, "authority")
    endpoint = authority.get("endpoint")
    if endpoint is None:
        return None
    if not isinstance(endpoint, Mapping):
        raise _Failure("ERR_INVALID_AUTHORITY", "authority.endpoint must be an object", "authority.endpoint")
    if authority.get("endpoint") is not None:
        _check_object(endpoint, _ENDPOINT_FIELDS, "authority.endpoint")
    _reject_alias(endpoint, "endpoint", "uri", "authority.endpoint")
    uri = endpoint.get("uri")
    if _is_absent(uri):
        return None
    if not _text(uri) or not _text(endpoint.get("owner")):
        raise _Failure("ERR_INVALID_ENDPOINT", "authority endpoint requires uri and owner", "authority.endpoint")
    for key, value in endpoint.items():
        if not isinstance(value, str) or not value.strip():
            raise _Failure("ERR_INVALID_ENDPOINT_FIELD_TYPE", f"endpoint.{key} must be a non-empty string", f"authority.endpoint.{key}")
    ack = authority.get("ack")
    if ack is None:
        return None
    if not isinstance(ack, Mapping):
        raise _Failure("ERR_INVALID_ACK", "authority ack must be an object", "authority.ack")
    _check_object(ack, _ACK_FIELDS, "authority.ack")
    required = ("ack_id", "request_id", "idempotency_key", "accepted_object_sha256",
                "authority_decision", "received_at_trusted_time", "verifier_ref",
                "verifier_version", "receipt_signature", "receipt_sha256")
    for key in required:
        if key not in ack or _is_absent(ack[key]):
            if key == "receipt_signature":
                return None
            raise _Failure("ERR_MISSING_ACK_FIELD", f"ack requires {key}", f"authority.ack.{key}")
    for key in required:
        if not isinstance(ack[key], str) or not ack[key].strip():
            raise _Failure("ERR_INVALID_ACK_FIELD_TYPE", f"ack.{key} must be a non-empty string", f"authority.ack.{key}")
    if ack["request_id"] != record.get("request_id") or ack["idempotency_key"] != record.get("idempotency_key"):
        raise _Failure("ERR_ACK_REQUEST_MISMATCH", "ack is not bound to request/idempotency key", "authority.ack")
    if ack["accepted_object_sha256"] != candidate["canonical_object_sha256"]:
        raise _Failure("ERR_ACK_OBJECT_MISMATCH", "ack object digest differs from candidate", "authority.ack.accepted_object_sha256")
    if not _hex(ack["receipt_sha256"]):
        raise _Failure("ERR_INVALID_ACK_HASH", "receipt_sha256 must be 64 lowercase hex", "authority.ack.receipt_sha256")
    if not _text(ack["receipt_signature"]):
        raise _Failure("ERR_INVALID_ACK_SIGNATURE", "receipt signature must be non-empty", "authority.ack.receipt_signature")
    return {"ack_id": ack["ack_id"], "idempotency_key": ack["idempotency_key"]}


def _validate(record: Mapping[str, Any], *, ledger: Optional[AuthorityLedger], now: Optional[str]) -> dict[str, Any]:
    started = _utc()
    observed = now or _utc()
    if not isinstance(record, Mapping):
        return _result(status="fail_closed", resolution="fail_closed", code="ERR_ROOT_NOT_OBJECT",
                       detail="root JSON value must be an object", request_id=None, mode="UNKNOWN",
                       started=started, now=observed)
    try:
        _reject_legacy_aliases(record)
        _check_object(record, _ROOT_FIELDS, "root")
    except _Failure as failure:
        test_only = record.get("mode") == "TEST_ONLY"
        return _result(status="non_evidence" if test_only else "fail_closed", resolution="fail_closed", code=failure.code,
                       detail=failure.detail, request_id=record.get("request_id"), mode=str(record.get("mode", "UNKNOWN")),
                       started=started, now=observed, path=failure.path, non_evidence=test_only)
    mode = record.get("mode", "PRODUCTION")
    if "mode" not in record:
        return _result(status="fail_closed", resolution="fail_closed", code="ERR_MISSING_FIELD",
                       detail="required non-empty string: mode", request_id=record.get("request_id"),
                       mode="UNKNOWN", started=started, now=observed, path="mode")
    if mode not in ("PRODUCTION", "TEST_ONLY"):
        return _result(status="fail_closed", resolution="fail_closed", code="ERR_INVALID_MODE",
                       detail="mode must be PRODUCTION or TEST_ONLY", request_id=record.get("request_id"),
                       mode=str(mode), started=started, now=observed)
    if mode == "TEST_ONLY":
        # TEST_ONLY can exercise every branch but can never become evidence.
        try:
            candidate = _candidate(record)
            if record.get("witness_scope") != candidate["candidate_id"]:
                raise _Failure("ERR_SCOPE_MISMATCH", "request witness_scope is not exact candidate scope", "witness_scope")
            _validate_witness(record, candidate)
            _validate_authority(record, candidate)
        except _ExternalAbsence as absence:
            return _result(status="non_evidence", resolution="typed_absence", code=absence.code,
                           detail=absence.detail, request_id=record.get("request_id"), mode=mode,
                           started=started, now=observed, path=absence.path, non_evidence=True)
        except _Failure as failure:
            return _result(status="non_evidence", resolution="fail_closed", code=failure.code,
                           detail=failure.detail, request_id=record.get("request_id"), mode=mode,
                           started=started, now=observed, path=failure.path, non_evidence=True)
        return _result(status="non_evidence", resolution="typed_absence", code="ERR_TEST_ONLY_NON_EVIDENCE",
                       detail="TEST_ONLY input is never evidence or an authority decision",
                       request_id=record.get("request_id"), mode=mode, started=started, now=observed,
                       non_evidence=True)
    # Production test markers are an explicit safety rail, not an absence.
    if _contains_marker(record):
        return _result(status="fail_closed", resolution="fail_closed", code="ERR_TEST_ONLY_MARKER",
                       detail="TEST_ONLY/placeholder material cannot enter PRODUCTION", request_id=record.get("request_id"),
                       mode=mode, started=started, now=observed)
    try:
        request_id = _require_text(record, "request_id")
        idem = _require_text(record, "idempotency_key")
        for key in ("nonce", "requested_at_trusted_time", "witness_scope", "attestation_sha256"):
            _require_text(record, key)
        if not _hex(record["attestation_sha256"]):
            raise _Failure("ERR_INVALID_ATTESTATION_HASH", "attestation_sha256 must be 64 lowercase hex", "attestation_sha256")
        candidate = _candidate(record)
        if record["witness_scope"] != candidate["candidate_id"]:
            raise _Failure("ERR_SCOPE_MISMATCH", "request witness_scope is not exact candidate scope", "witness_scope")
        request_digest = _canonical_request_digest(record)
        if ledger is not None and idem in ledger._requests:
            old = ledger._requests[idem]
            code = "ERR_DUPLICATE_IDEMPOTENCY" if old == request_digest else "ERR_IDEMPOTENCY_CONFLICT"
            raise _Failure(code, "idempotency key was already observed", "idempotency_key")
        # Consume the replay key before any external absence return.  The
        # ledger stores complete canonical request bytes, not object digest.
        if ledger is not None:
            ledger._requests[idem] = request_digest
        witness = _validate_witness(record, candidate)
        authority = _validate_authority(record, candidate)
        if authority is None:
            return _absence("ERR_AUTHORITY_EXTERNAL_ABSENT", "real authority endpoint/ack receipt is not supplied", record, started, observed, "authority")
        if ledger is not None and authority["ack_id"] in ledger._acks:
            raise _Failure("ERR_DUPLICATE_ACK", "ack_id was already observed", "authority.ack.ack_id")
        if ledger is not None:
            ledger._acks[authority["ack_id"]] = candidate["canonical_object_sha256"]
        return _result(status="present_admissible_shape", resolution="typed_absence",
                       code="OK_SHAPE_ONLY", detail="all local bindings are valid; external verification remains absent",
                       request_id=request_id, mode=mode, started=started, now=observed)
    except _ExternalAbsence as absence:
        return _absence(absence.code, absence.detail, record, started, observed, absence.path)
    except _Failure as failure:
        return _result(status="fail_closed", resolution="fail_closed", code=failure.code,
                       detail=failure.detail, request_id=record.get("request_id"), mode=mode,
                       started=started, now=observed, path=failure.path)


def validate(record: Mapping[str, Any], *, now: Optional[str] = None) -> dict[str, Any]:
    """Validate one record with a fresh in-memory replay ledger."""
    return AuthorityLedger().validate(record, now=now)


def validate_batch(records: Iterable[Mapping[str, Any]], *, now: Optional[str] = None) -> list[dict[str, Any]]:
    """Validate a deterministic batch, allowing duplicate detection across rows."""
    ledger = AuthorityLedger()
    return [ledger.validate(item, now=now) for item in records]
