"""Fail-closed validation for an immutable source and four axis materials.

The validator is intentionally boring: all joins are exact, all hashes are
content hashes, and an absent external issuer is represented as typed absence.
``TEST_ONLY`` fixtures can exercise the complete join but never become authority
evidence.
"""

from __future__ import annotations

import copy
import hashlib
import json
import re
import argparse
import sys
import os
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any, Mapping

SCHEMA_VERSION = "UP1-R2.source-axis-binding.v1"
AXES = (
    "payload_schema_version",
    "canonicalization_profile_version",
    "applicability_profile_version",
    "evidence_receipt_version",
)
_HEX64 = re.compile(r"^[0-9a-f]{64}$")
_HEX40 = re.compile(r"^[0-9a-f]{40}$")
_BUNDLE_KEYS = {"schema", "candidate_id", "state", "provenance_class", "ad56", "authority", "source_identity", "axis_materials", "candidate_axis_edges"}
_IDENTITY_KEYS = {"identity_schema_version", "repository_locator", "head", "head_tree", "dirty_status", "dirty_status_digest", "patch_digest", "untracked_files", "untracked_content_digest", "submodule_closure", "source_identity_digest", "axis_edges"}
_MATERIAL_KEYS = {"axis", "namespace", "version", "issuer", "issued_at", "candidate_id", "source_identity_digest", "payload", "digest", "source_edge", "candidate_edge", "signature"}
_EDGE_KEYS = {"axis", "candidate_id", "source_identity_digest", "material_digest", "namespace", "version", "issuer", "issued_at"}
_AD56_KEYS = {"source", "authority_evidence", "classification"}
_AUTHORITY_KEYS = {"signature_validated", "trust_root_validated", "trusted_time_validated", "revocation_validated", "g2_mapping_validated"}
_SUBMODULE_KEYS = {"applicable", "digest", "reason"}
_PAYLOAD_KEYS = {"fixture", "ordinal"}
_STATES = {"TEST_ONLY", "typed_absence", "EXTERNAL_ISSUED"}
_PROVENANCE_CLASSES = {"test_fixture", "external_material_absent", "external_issued"}


class BindingValidationError(ValueError):
    """A malformed object. ``code`` is stable for machine-readable receipts."""

    def __init__(self, code: str, message: str, *, path: str | None = None):
        super().__init__(message)
        self.code = code
        self.path = path


class DuplicateJSONKeyError(ValueError):
    pass


def canonical_bytes(value: Any) -> bytes:
    """Return the one canonical JSON representation used by every digest."""

    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")


def canonical_digest(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def _without(value: Mapping[str, Any], *keys: str) -> dict[str, Any]:
    return {k: copy.deepcopy(v) for k, v in value.items() if k not in keys}


def source_identity_digest(identity: Mapping[str, Any]) -> str:
    """Digest immutable source facts, never the derived edges or self-digest."""

    return canonical_digest(_without(identity, "source_identity_digest", "axis_edges", "candidate_axis_edges"))


def capture_source_identity(repo_root: str | Path) -> dict[str, Any]:
    """Capture the exact local git facts used by a binding.

    This is software bookkeeping only. It does not contact an issuer and the
    resulting dirty snapshot cannot be promoted to authority evidence.
    """
    root = str(repo_root)

    def git(*args: str) -> bytes:
        try:
            return subprocess.check_output(["git", *args], cwd=root, stderr=subprocess.PIPE)
        except (OSError, subprocess.CalledProcessError) as exc:
            raise BindingValidationError("source_capture_failed", f"git {' '.join(args)} failed: {exc}") from exc

    head = git("rev-parse", "HEAD").decode("ascii").strip().lower()
    head_tree = git("rev-parse", "HEAD^{tree}").decode("ascii").strip().lower()
    status = git("status", "--porcelain=v1", "--untracked-files=all")
    patch = git("diff", "--binary") + git("diff", "--cached", "--binary")
    untracked_raw = git("ls-files", "--others", "--exclude-standard", "-z")
    untracked_files = []
    for name in sorted(x for x in untracked_raw.split(b"\0") if x):
        path = Path(root) / os.fsdecode(name)
        data = path.read_bytes()
        untracked_files.append({"path": os.fsdecode(name).replace("\\", "/"), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
    has_submodules = (Path(root) / ".gitmodules").exists()
    closure_bytes = git("submodule", "status", "--recursive") if has_submodules else b""
    identity: dict[str, Any] = {
        "identity_schema_version": "UP1-R2.source-identity.v1",
        "repository_locator": str(Path(root).resolve()).replace("\\", "/"),
        "head": head,
        "head_tree": head_tree,
        "dirty_status": "dirty" if status else "clean",
        "dirty_status_digest": hashlib.sha256(status).hexdigest(),
        "patch_digest": hashlib.sha256(patch).hexdigest(),
        "untracked_files": untracked_files,
        "untracked_content_digest": canonical_digest(untracked_files),
        "submodule_closure": {
            "applicable": has_submodules,
            "digest": hashlib.sha256(closure_bytes).hexdigest() if has_submodules else None,
            "reason": "git submodule status --recursive" if has_submodules else "no .gitmodules",
        },
    }
    identity["source_identity_digest"] = source_identity_digest(identity)
    return identity


def material_digest(material: Mapping[str, Any]) -> str:
    """Digest material identity and body, excluding derived reverse edges."""

    body = _without(material, "digest", "material_digest", "source_edge", "candidate_edge")
    return canonical_digest(body)


def _issue(code: str, message: str, path: str | None = None) -> dict[str, Any]:
    item = {"code": code, "message": message}
    if path is not None:
        item["path"] = path
    return item


def _unknowns(value: Mapping[str, Any], allowed: set[str], prefix: str) -> list[dict[str, Any]]:
    return [_issue("unknown_field", f"unknown field: {key}", f"{prefix}.{key}") for key in sorted(set(value).difference(allowed))]


def _ordered_errors(errors: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(errors, key=lambda x: (str(x.get("path", "")), str(x.get("code", "")), str(x.get("message", ""))))


def _reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        if key in value:
            raise DuplicateJSONKeyError(f"duplicate JSON object key: {key}")
        value[key] = item
    return value


def _is_hex(value: Any, size: int) -> bool:
    return isinstance(value, str) and bool(((_HEX64 if size == 64 else _HEX40)).fullmatch(value))


def _parse_time(value: Any) -> bool:
    if not isinstance(value, str) or not value.endswith("Z"):
        return False
    try:
        datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError:
        return False
    return True


def _materials_as_list(value: Any) -> list[dict[str, Any]]:
    if isinstance(value, list):
        return list(value)
    return []


def _edge_map(value: Any) -> dict[str, Mapping[str, Any]]:
    if not isinstance(value, Mapping):
        return {}
    return {str(k): v for k, v in value.items()}


def validate_bundle(bundle: Mapping[str, Any], observed_source_identity: Mapping[str, Any] | None = None) -> dict[str, Any]:
    """Validate a bundle and return a stable JSON-ready receipt.

    A structurally complete ``TEST_ONLY`` bundle returns ``status=TEST_ONLY`` and
    ``valid=true`` while explicitly carrying ``authority_evidence=false``. A
    bundle with no external materials returns ``typed_absence`` and
    ``admission=terminal_deferred``. Contradictions and drift return
    ``fail_closed`` with a non-zero CLI exit.
    """

    errors: list[dict[str, Any]] = []
    checks: dict[str, bool] = {}
    if not isinstance(bundle, Mapping):
        return {"schema": SCHEMA_VERSION, "valid": False, "status": "fail_closed", "errors": [_issue("invalid_bundle", "bundle must be an object")], "authority_evidence": False}

    errors.extend(_unknowns(bundle, _BUNDLE_KEYS, "bundle"))
    if bundle.get("schema") != "UP1-R2.source-axis-binding.bundle.v1":
        errors.append(_issue("unknown_schema", "bundle schema is not the frozen UP1 R2 schema", "schema"))
    if not isinstance(bundle.get("state"), str) or bundle.get("state") not in _STATES:
        errors.append(_issue("unknown_state", "state is not a frozen enum", "state"))
    if not isinstance(bundle.get("provenance_class"), str) or bundle.get("provenance_class") not in _PROVENANCE_CLASSES:
        errors.append(_issue("unknown_provenance_class", "provenance_class is not a frozen enum", "provenance_class"))
    candidate_id = bundle.get("candidate_id")
    if not isinstance(candidate_id, str) or not candidate_id:
        errors.append(_issue("missing_candidate", "candidate_id is required", "candidate_id"))
    identity = bundle.get("source_identity")
    if not isinstance(identity, Mapping):
        errors.append(_issue("missing_source_identity", "source_identity is required", "source_identity"))
        identity = {}
    else:
        errors.extend(_unknowns(identity, _IDENTITY_KEYS, "source_identity"))
        if identity.get("identity_schema_version") != "UP1-R2.source-identity.v1":
            errors.append(_issue("unknown_identity_schema", "identity_schema_version is not the frozen enum", "source_identity.identity_schema_version"))
        required = ("head", "head_tree", "dirty_status_digest", "patch_digest", "untracked_files", "untracked_content_digest", "submodule_closure")
        for key in required:
            if key not in identity:
                errors.append(_issue("missing_source_field", f"missing immutable source field: {key}", f"source_identity.{key}"))
        if not _is_hex(identity.get("head"), 40):
            errors.append(_issue("invalid_head", "head must be a 40-character lowercase git object id", "source_identity.head"))
        if not _is_hex(identity.get("head_tree"), 40):
            errors.append(_issue("invalid_head_tree", "head_tree must be the 40-character HEAD^{tree} object id", "source_identity.head_tree"))
        for key in ("dirty_status_digest", "patch_digest"):
            if not _is_hex(identity.get(key), 64):
                errors.append(_issue("invalid_source_digest", f"{key} must be 64 lowercase hex", f"source_identity.{key}"))
        closure = identity.get("submodule_closure")
        if not isinstance(closure, Mapping) or not isinstance(closure.get("applicable"), bool):
            errors.append(_issue("invalid_submodule_closure", "submodule_closure.applicable must be explicit", "source_identity.submodule_closure"))
        elif isinstance(closure, Mapping):
            errors.extend(_unknowns(closure, _SUBMODULE_KEYS, "source_identity.submodule_closure"))
            if not isinstance(closure.get("reason"), str):
                errors.append(_issue("invalid_submodule_closure_reason", "submodule closure reason is required", "source_identity.submodule_closure.reason"))
            if closure["applicable"] and not _is_hex(closure.get("digest"), 64):
                errors.append(_issue("missing_submodule_closure_digest", "applicable submodule closure requires a digest", "source_identity.submodule_closure.digest"))
            if not closure["applicable"] and closure.get("digest") not in (None, ""):
                errors.append(_issue("unexpected_submodule_closure_digest", "non-applicable closure cannot carry a digest", "source_identity.submodule_closure.digest"))
        untracked = identity.get("untracked_files")
        if not isinstance(untracked, list):
            errors.append(_issue("invalid_untracked_files", "untracked_files must be an array of content records", "source_identity.untracked_files"))
        else:
            for index, record in enumerate(untracked):
                if not isinstance(record, Mapping) or set(record) != {"path", "bytes", "sha256"} or not isinstance(record.get("path"), str) or not isinstance(record.get("bytes"), int) or not _is_hex(record.get("sha256"), 64):
                    errors.append(_issue("invalid_untracked_record", "untracked record requires path, bytes and sha256", f"source_identity.untracked_files[{index}]"))
            if identity.get("untracked_content_digest") != canonical_digest(untracked):
                errors.append(_issue("untracked_content_hash_mismatch", "untracked content digest does not match sorted content records", "source_identity.untracked_content_digest"))
        declared = identity.get("source_identity_digest")
        computed = source_identity_digest(identity)
        checks["source_identity_hash"] = declared == computed
        if declared != computed:
            errors.append(_issue("hash_mismatch", "source_identity_digest does not match immutable source facts", "source_identity.source_identity_digest"))
        if observed_source_identity is not None:
            # Compare immutable facts only; reverse axis edges are derived and may
            # be absent from a source-observation probe.
            checks["source_identity_drift"] = source_identity_digest(identity) == source_identity_digest(observed_source_identity)
            if not checks["source_identity_drift"]:
                errors.append(_issue("source_drift", "observed source identity differs from the bound immutable identity"))
    if observed_source_identity is None:
        errors.append(_issue("missing_observed_source", "a fresh observed source identity is required"))
    elif not isinstance(observed_source_identity, Mapping):
        errors.append(_issue("invalid_observed_source", "observed source identity must be an object"))
    else:
        errors.extend(_unknowns(observed_source_identity, _IDENTITY_KEYS, "observed_source"))
        if observed_source_identity.get("source_identity_digest") != source_identity_digest(observed_source_identity):
            errors.append(_issue("observed_source_hash_mismatch", "observed source identity digest is not self-consistent"))

    # AD56 is a bookkeeping label only; it cannot turn a local dirty snapshot into authority.
    provenance_class = bundle.get("provenance_class")
    # A label cannot manufacture external authority: every axis must carry a
    # real issuer before an external-issued state can be considered evidence.
    raw_materials = _materials_as_list(bundle.get("axis_materials"))
    all_real_issuers = bool(raw_materials) and all(
        isinstance(m, Mapping) and isinstance(m.get("issuer"), str) and not m["issuer"].startswith("typed_absence:") for m in raw_materials
    )
    authority_evidence = provenance_class == "external_issued" and bundle.get("state") == "EXTERNAL_ISSUED" and all_real_issuers
    if bundle.get("state") == "EXTERNAL_ISSUED":
        authority = bundle.get("authority")
        if not isinstance(authority, Mapping):
            errors.append(_issue("missing_external_authority", "EXTERNAL_ISSUED requires validated signature, trust root, time, revocation and G2 mapping", "authority"))
        else:
            errors.extend(_unknowns(authority, _AUTHORITY_KEYS, "authority"))
            if set(authority) != _AUTHORITY_KEYS or any(authority.get(k) is not True for k in _AUTHORITY_KEYS):
                errors.append(_issue("external_authority_incomplete", "all five external authority validations must be true", "authority"))
            for index, material in enumerate(raw_materials):
                if isinstance(material, Mapping) and not isinstance(material.get("signature"), str):
                    errors.append(_issue("missing_external_signature", "each external axis requires a verified signature reference", f"axis_materials[{index}].signature"))
    if bundle.get("ad56") is not None:
        if not isinstance(bundle.get("ad56"), Mapping):
            errors.append(_issue("invalid_ad56_type", "ad56 must be an object", "ad56"))
        else:
            errors.extend(_unknowns(bundle["ad56"], _AD56_KEYS, "ad56"))
        checks["ad56_not_authority"] = not isinstance(bundle.get("ad56"), Mapping) or bundle.get("ad56", {}).get("authority_evidence") is False
        if not checks["ad56_not_authority"]:
            errors.append(_issue("ad56_authority_escalation", "AD56 dirty bookkeeping cannot be authority evidence"))

    materials_value = bundle.get("axis_materials")
    if not isinstance(materials_value, list):
        errors.append(_issue("invalid_materials_type", "axis_materials must be an array", "axis_materials"))
    materials = _materials_as_list(materials_value)
    seen: set[str] = set()
    duplicate_axes: list[str] = []
    for index, material in enumerate(materials):
        if not isinstance(material, Mapping):
            errors.append(_issue("invalid_material_type", "axis material must be an object", f"axis_materials[{index}]"))
            continue
        errors.extend(_unknowns(material, _MATERIAL_KEYS, f"axis_materials[{index}]"))
        axis = material.get("axis")
        if axis in seen:
            duplicate_axes.append(str(axis))
        seen.add(str(axis))
    if duplicate_axes:
        errors.append(_issue("duplicate_axis", f"duplicate axis material(s): {sorted(set(duplicate_axes))}"))
    unknown = sorted(seen.difference(AXES))
    if unknown:
        errors.append(_issue("unknown_axis", f"unknown axis material(s): {unknown}"))
    missing = sorted(set(AXES).difference(seen))

    # The external provider can be absent. This is a typed, non-success state.
    state = bundle.get("state")
    if state == "TEST_ONLY" and provenance_class != "test_fixture":
        errors.append(_issue("state_profile_mismatch", "TEST_ONLY requires provenance_class=test_fixture", "provenance_class"))
    if state == "typed_absence" and provenance_class != "external_material_absent":
        errors.append(_issue("state_profile_mismatch", "typed_absence requires provenance_class=external_material_absent", "provenance_class"))
    if state == "EXTERNAL_ISSUED" and provenance_class != "external_issued":
        errors.append(_issue("state_profile_mismatch", "EXTERNAL_ISSUED requires provenance_class=external_issued", "provenance_class"))
    external_materials_present = bool(materials)
    if not external_materials_present and state in ("typed_absence", "TEST_ONLY"):
        return {
            "schema": SCHEMA_VERSION,
            "valid": not errors,
            "status": "typed_absence" if not errors else "fail_closed",
            "admission": "terminal_deferred" if not errors else "fail_closed",
            "classification": "non_evidence" if state == "TEST_ONLY" else "external_material_absent",
            "authority_evidence": False,
            "candidate_id": candidate_id,
            "axis_set": [],
            "missing_axes": list(AXES),
            "checks": checks,
            "errors": _ordered_errors(errors),
        }
    if missing:
        errors.append(_issue("missing_axis", f"missing axis material(s): {missing}"))

    expected_source_digest = source_identity_digest(identity)
    candidate_edges = _edge_map(bundle.get("candidate_axis_edges", bundle.get("candidate_edges")))
    source_edges = _edge_map(identity.get("axis_edges"))
    if "candidate_axis_edges" not in bundle or not isinstance(bundle.get("candidate_axis_edges"), Mapping):
        errors.append(_issue("invalid_candidate_edges_type", "candidate_axis_edges must be an object", "candidate_axis_edges"))
    if "axis_edges" not in identity or not isinstance(identity.get("axis_edges"), Mapping):
        errors.append(_issue("invalid_source_edges_type", "source_identity.axis_edges must be an object", "source_identity.axis_edges"))
    for axis, edge in source_edges.items():
        if not isinstance(edge, Mapping):
            errors.append(_issue("invalid_edge_type", "source edge must be an object", f"source_identity.axis_edges.{axis}"))
        else:
            errors.extend(_unknowns(edge, _EDGE_KEYS, f"source_identity.axis_edges.{axis}"))
    for axis, edge in candidate_edges.items():
        if not isinstance(edge, Mapping):
            errors.append(_issue("invalid_edge_type", "candidate edge must be an object", f"candidate_axis_edges.{axis}"))
        else:
            errors.extend(_unknowns(edge, _EDGE_KEYS, f"candidate_axis_edges.{axis}"))
    if set(source_edges) != set(AXES):
        errors.append(_issue("source_edge_missing_or_ambiguous", "source identity edge set is not exactly the four-axis set", "source_identity.axis_edges"))
    if set(candidate_edges) != set(AXES):
        errors.append(_issue("candidate_edge_missing_or_ambiguous", "candidate edge set is not exactly the four-axis set", "candidate_axis_edges"))
    for material in materials:
        if not isinstance(material, Mapping):
            continue
        axis = material.get("axis")
        if axis not in AXES:
            continue
        prefix = f"axis_materials.{axis}"
        for key in ("namespace", "version", "issuer", "issued_at", "candidate_id"):
            if not isinstance(material.get(key), str) or not material.get(key):
                errors.append(_issue("missing_axis_field", f"{key} is required", f"{prefix}.{key}"))
        if not _parse_time(material.get("issued_at")):
            errors.append(_issue("invalid_issued_time", "issued_at must be RFC3339 UTC ending in Z", f"{prefix}.issued_at"))
        payload = material.get("payload")
        if not isinstance(payload, Mapping):
            errors.append(_issue("invalid_payload_type", "axis material payload must be an object", f"{prefix}.payload"))
        else:
            errors.extend(_unknowns(payload, _PAYLOAD_KEYS, f"{prefix}.payload"))
            if set(payload) != _PAYLOAD_KEYS or not isinstance(payload.get("fixture"), str) or not isinstance(payload.get("ordinal"), int) or any(isinstance(v, (Mapping, list)) for v in payload.values()):
                errors.append(_issue("invalid_payload_schema", "payload must contain only scalar fixture and ordinal fields", f"{prefix}.payload"))
        if material.get("candidate_id") != candidate_id:
            errors.append(_issue("foreign_candidate", "axis material candidate differs from bundle candidate", f"{prefix}.candidate_id"))
        if material.get("source_identity_digest") != expected_source_digest:
            errors.append(_issue("foreign_source_identity", "axis material is bound to a different source identity", f"{prefix}.source_identity_digest"))
        declared_material = material.get("digest", material.get("material_digest"))
        computed_material = material_digest(material)
        if not _is_hex(declared_material, 64) or declared_material != computed_material:
            errors.append(_issue("hash_mismatch", "axis material digest does not match canonical material body", f"{prefix}.digest"))
        source_edge = material.get("source_edge")
        candidate_edge = material.get("candidate_edge")
        expected_edge = {
            "axis": axis,
            "candidate_id": candidate_id,
            "source_identity_digest": expected_source_digest,
            "material_digest": computed_material,
            "namespace": material.get("namespace"),
            "version": material.get("version"),
            "issuer": material.get("issuer"),
            "issued_at": material.get("issued_at"),
        }
        if source_edge != expected_edge:
            errors.append(_issue("source_edge_mismatch", "axis to source edge is not an exact reverse edge", f"{prefix}.source_edge"))
        if candidate_edge != expected_edge:
            errors.append(_issue("candidate_edge_mismatch", "axis to candidate edge is not an exact reverse edge", f"{prefix}.candidate_edge"))
        if source_edges.get(axis) != expected_edge:
            errors.append(_issue("source_edge_missing_or_ambiguous", "source identity does not point back to this exact axis material", f"source_identity.axis_edges.{axis}"))
        if candidate_edges.get(axis) != expected_edge:
            errors.append(_issue("candidate_edge_missing_or_ambiguous", "candidate binding does not point back to this exact axis material", f"candidate_axis_edges.{axis}"))

    checks["exact_axis_set"] = not missing and not unknown and not duplicate_axes and len(materials) == len(AXES)
    checks["bidirectional_edges"] = not any(x["code"].endswith("edge_mismatch") or "edge_missing" in x["code"] for x in errors)
    checks["candidate_exact"] = not any(x["code"] == "foreign_candidate" for x in errors)
    status = "fail_closed" if errors else ("TEST_ONLY" if state == "TEST_ONLY" else "valid")
    errors = _ordered_errors(errors)
    authority_output = bool(not errors and authority_evidence and state == "EXTERNAL_ISSUED" and provenance_class == "external_issued")
    return {
        "schema": SCHEMA_VERSION,
        "valid": not errors,
        "status": status,
        "admission": "admitted_non_evidence" if not errors and state == "TEST_ONLY" else ("admitted" if not errors else "fail_closed"),
        "classification": "non_evidence" if state == "TEST_ONLY" else ("external_issued" if authority_evidence else "unattested"),
        "authority_evidence": authority_output,
        "candidate_id": candidate_id,
        "source_identity_digest": expected_source_digest,
        "axis_set": sorted(seen),
        "missing_axes": missing,
        "checks": checks,
        "errors": errors,
    }


def main(argv: list[str] | None = None) -> int:
    """Small JSON CLI, also usable by invoking this file directly."""
    parser = argparse.ArgumentParser(description="Validate UP1 R2 immutable source/four-axis binding")
    parser.add_argument("--input", type=Path, help="JSON bundle; stdin when omitted")
    parser.add_argument("--observed-source", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        bundle = json.loads((args.input.read_bytes() if args.input else sys.stdin.buffer.read()).decode("utf-8"), object_pairs_hook=_reject_duplicate_pairs)
        observed = json.loads(args.observed_source.read_text(encoding="utf-8"), object_pairs_hook=_reject_duplicate_pairs) if args.observed_source else None
        receipt = validate_bundle(bundle, observed)
        encoded = canonical_bytes(receipt)
        if args.output:
            args.output.write_bytes(encoded)
        sys.stdout.buffer.write(encoded + b"\n")
        return 0 if receipt.get("valid") else 1
    except DuplicateJSONKeyError as exc:
        encoded = canonical_bytes({"valid": False, "status": "fail_closed", "authority_evidence": False, "errors": [{"code": "duplicate_json_key", "message": str(exc)}]})
        sys.stdout.buffer.write(encoded + b"\n")
        return 1
    except (OSError, UnicodeError, json.JSONDecodeError, TypeError, ValueError) as exc:
        encoded = canonical_bytes({"valid": False, "status": "program_exception", "authority_evidence": False, "errors": [{"code": "program_exception", "message": str(exc)}]})
        sys.stdout.buffer.write(encoded + b"\n")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
