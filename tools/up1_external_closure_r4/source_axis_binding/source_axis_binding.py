"""Offline, fail-closed source/four-axis binding prototype (UP1 r4).

This module only measures local bytes and local git state.  It never creates an
external material, a signature, or an authority assertion.  A complete local
fixture is explicitly ``TEST_ONLY`` and remains non-evidence.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Mapping

SCHEMA_VERSION = "UP1-R4.source-axis-binding.bundle.v1"
IDENTITY_SCHEMA_VERSION = "UP1-R4.source-identity.v1"
CANONICALIZATION_VERSION = "UP1-R4-CJSON-1"
DOMAIN = "UP1-R4.source-axis-binding.v1"
AXES = (
    "payload_schema_version",
    "canonicalization_profile_version",
    "applicability_profile_version",
    "evidence_receipt_version",
)
_HEX40 = re.compile(r"^[0-9a-f]{40}$")
_HEX64 = re.compile(r"^[0-9a-f]{64}$")
_ABSENT = {"typed_absent", "typed_absence", "absent", "TYPED_ABSENT"}


class BindingValidationError(ValueError):
    """Typed local capture/validation failure."""

    def __init__(self, code: str, message: str, *, path: str | None = None):
        super().__init__(message)
        self.code = code
        self.path = path


class DuplicateJSONKeyError(ValueError):
    pass


def _validate_canonical(value: Any, path: str = "$", active: set[int] | None = None) -> None:
    if value is None or type(value) in (bool, str, int):
        if type(value) is str:
            value.encode("utf-8", "strict")
            if any(0xD800 <= ord(ch) <= 0xDFFF for ch in value):
                raise ValueError(f"lone surrogate at {path}")
        return
    if type(value) is float:
        raise ValueError(f"float is not permitted in {CANONICALIZATION_VERSION} at {path}")
    if active is None:
        active = set()
    if isinstance(value, (Mapping, list, tuple)):
        marker = id(value)
        if marker in active:
            raise ValueError(f"cyclic value at {path}")
        active.add(marker)
        try:
            if isinstance(value, Mapping):
                for key, item in value.items():
                    if type(key) is not str:
                        raise ValueError(f"non-string key at {path}")
                    _validate_canonical(item, f"{path}.{key}", active)
            else:
                for index, item in enumerate(value):
                    _validate_canonical(item, f"{path}[{index}]", active)
        finally:
            active.remove(marker)
        return
    raise ValueError(f"unsupported canonical value at {path}")


def canonical_bytes(value: Any) -> bytes:
    """Compact UTF-8 sorted-key JSON with finite, integer-only numbers."""
    _validate_canonical(value)
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def canonical_digest(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def _without(value: Any, excluded: set[str], active: set[int] | None = None) -> Any:
    if isinstance(value, Mapping):
        return {key: _without(item, excluded, active) for key, item in value.items() if key not in excluded}
    if isinstance(value, list):
        return [_without(item, excluded, active) for item in value]
    return copy.deepcopy(value)


def canonical_preimage(value: Any, *, domain: str = DOMAIN, version: str = "v1", exclude: tuple[str, ...] = ()) -> bytes:
    """Build the domain-separated bytes used for a derived digest.

    The separator is an unambiguous ASCII line followed by exactly one
    canonical JSON object.  Exclusions are explicit and are applied
    recursively by field name, so self hashes and reverse edges cannot sneak
    into their own preimage.
    """
    if type(domain) is not str or not domain or type(version) is not str or not version:
        raise ValueError("domain and version must be non-empty strings")
    clean = _without(value, set(exclude)) if exclude else copy.deepcopy(value)
    return f"{domain}/{version}\n".encode("ascii") + canonical_bytes(clean)


def domain_separated_preimage(value: Any, *, domain: str = DOMAIN, version: str = "v1", exclude: tuple[str, ...] = ()) -> bytes:
    return canonical_preimage(value, domain=domain, version=version, exclude=exclude)


def preimage_digest(value: Any, *, domain: str = DOMAIN, version: str = "v1", exclude: tuple[str, ...] = ()) -> str:
    return hashlib.sha256(canonical_preimage(value, domain=domain, version=version, exclude=exclude)).hexdigest()


def raw_observation(data: bytes | bytearray, locator: str) -> dict[str, Any]:
    """Return a lossless local raw-byte identity record."""
    if not isinstance(data, (bytes, bytearray)) or not isinstance(locator, str) or not locator:
        raise ValueError("raw observation requires bytes and a non-empty locator")
    blob = bytes(data)
    return {"locator": locator.replace("\\", "/"), "raw_bytes": len(blob), "raw_sha256": hashlib.sha256(blob).hexdigest()}


def _without_identity(identity: Mapping[str, Any]) -> dict[str, Any]:
    return _without(identity, {"source_identity_digest", "identity_digest", "axis_edges", "candidate_axis_edges", "canonical_preimage", "canonical_preimage_sha256"})


def source_identity_digest(identity: Mapping[str, Any]) -> str:
    return preimage_digest(_without_identity(identity), domain=DOMAIN, version="source-identity")


def _material_body(material: Mapping[str, Any]) -> dict[str, Any]:
    # material_id is an input identity, not a derived reverse edge; changing it
    # must therefore change the digest and cannot be silently relabelled.
    return _without(material, {"digest", "material_digest", "source_edge", "candidate_edge", "run_edge", "authority_edge", "canonical_preimage", "canonical_preimage_sha256"})


def material_digest(material: Mapping[str, Any]) -> str:
    return preimage_digest(_material_body(material), domain=DOMAIN, version="axis-material")


axis_material_digest = material_digest


def bundle_preimage(bundle: Mapping[str, Any]) -> bytes:
    """Canonical bundle preimage excluding only derived receipt fields."""
    return canonical_preimage(bundle, domain=DOMAIN, version="bundle", exclude=("bundle_digest", "canonical_preimage_sha256", "formal_credit", "no_publish"))


def bundle_digest(bundle: Mapping[str, Any]) -> str:
    return hashlib.sha256(bundle_preimage(bundle)).hexdigest()


def _issue(code: str, message: str, path: str | None = None) -> dict[str, Any]:
    result = {"code": code, "message": message}
    if path is not None:
        result["path"] = path
    return result


def _ordered(errors: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(errors, key=lambda item: (str(item.get("path", "")), str(item.get("code", "")), str(item.get("message", ""))))


def _unknowns(value: Mapping[str, Any], allowed: set[str], prefix: str) -> list[dict[str, Any]]:
    return [_issue("unknown_field", f"unknown field: {key}", f"{prefix}.{key}") for key in sorted(set(value).difference(allowed))]


def _is_hex(value: Any, length: int) -> bool:
    return isinstance(value, str) and bool((_HEX40 if length == 40 else _HEX64).fullmatch(value))


def _parse_time(value: Any) -> bool:
    if not isinstance(value, str) or not value.endswith("Z"):
        return False
    try:
        datetime.fromisoformat(value[:-1] + "+00:00")
        return True
    except ValueError:
        return False


def _reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJSONKeyError(f"duplicate JSON object key: {key}")
        result[key] = value
    return result


def _git(root: str, *args: str) -> bytes:
    try:
        return subprocess.check_output(["git", *args], cwd=root, stderr=subprocess.PIPE)
    except (OSError, subprocess.CalledProcessError) as exc:
        raise BindingValidationError("source_capture_failed", f"git {' '.join(args)} failed: {exc}") from exc


def _file_records(root: Path, paths: list[str]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for raw in sorted(paths):
        relative = raw.replace("\\", "/")
        path = root / relative
        try:
            data = path.read_bytes()
        except OSError as exc:
            raise BindingValidationError("source_read_failed", f"cannot read source file {relative}: {exc}") from exc
        records.append({"locator": relative, "raw_bytes": len(data), "raw_sha256": hashlib.sha256(data).hexdigest()})
    return records


def capture_source_identity(repo_root: str | Path, source_files: list[str | Path] | None = None) -> dict[str, Any]:
    """Capture exact local source bytes plus HEAD/tree/dirty evidence."""
    root = Path(repo_root).resolve()
    root_s = str(root)
    tracked = [os.fsdecode(item) for item in _git(root_s, "ls-files", "-z").split(b"\0") if item]
    paths = [str(item) for item in source_files] if source_files is not None else tracked
    records = _file_records(root, paths)
    status = _git(root_s, "status", "--porcelain=v1", "--untracked-files=all")
    patch = _git(root_s, "diff", "--binary") + _git(root_s, "diff", "--cached", "--binary")
    untracked_raw = _git(root_s, "ls-files", "--others", "--exclude-standard", "-z")
    untracked = _file_records(root, [os.fsdecode(item) for item in untracked_raw.split(b"\0") if item])
    has_submodules = (root / ".gitmodules").exists()
    submodule = _git(root_s, "submodule", "status", "--recursive") if has_submodules else b""
    identity: dict[str, Any] = {
        "identity_schema_version": IDENTITY_SCHEMA_VERSION,
        "repository_locator": root_s.replace("\\", "/"),
        "source_locator": root_s.replace("\\", "/"),
        "source_files": records,
        "raw_bytes": sum(item["raw_bytes"] for item in records),
        "raw_sha256": hashlib.sha256(canonical_bytes(records)).hexdigest(),
        "head": _git(root_s, "rev-parse", "HEAD").decode("ascii").strip().lower(),
        "head_tree": _git(root_s, "rev-parse", "HEAD^{tree}").decode("ascii").strip().lower(),
        "dirty_status": "dirty" if status else "clean",
        "dirty_status_digest": hashlib.sha256(status).hexdigest(),
        "patch_digest": hashlib.sha256(patch).hexdigest(),
        "untracked_files": untracked,
        "untracked_content_digest": canonical_digest(untracked),
        "submodule_closure": {"applicable": has_submodules, "digest": hashlib.sha256(submodule).hexdigest() if has_submodules else None, "reason": "git submodule status --recursive" if has_submodules else "no .gitmodules"},
    }
    identity["git_evidence"] = {key: identity[key] for key in ("head", "head_tree", "dirty_status", "dirty_status_digest", "patch_digest", "untracked_files", "untracked_content_digest", "submodule_closure")}
    identity["source_identity_digest"] = source_identity_digest(identity)
    return identity


def _ref_is_typed_absent(ref: Any) -> bool:
    return isinstance(ref, Mapping) and ref.get("state") in _ABSENT and ref.get("value") is None


def _ref_valid(ref: Any) -> bool:
    if _ref_is_typed_absent(ref):
        return isinstance(ref.get("reason"), str) and bool(ref.get("reason"))
    if not isinstance(ref, Mapping) or not ref:
        return False
    if not any(isinstance(ref.get(key), str) and ref.get(key) for key in ("id", "uri", "ref", "value")):
        return False
    for key in ("sha256", "hash", "digest"):
        if key in ref and not _is_hex(ref[key], 64):
            return False
    return True


def _material_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def _source_digest_from(identity: Mapping[str, Any]) -> str:
    value = identity.get("source_identity_digest", identity.get("identity_digest"))
    return value if isinstance(value, str) else source_identity_digest(identity)


def validate_bundle(bundle: Mapping[str, Any], observed_source_identity: Mapping[str, Any] | None = None) -> dict[str, Any]:
    """Validate exact source/axis joins; every receipt is non-publishable."""
    errors: list[dict[str, Any]] = []
    checks: dict[str, bool] = {}
    base = {"schema": SCHEMA_VERSION, "valid": False, "status": "fail_closed", "authority_evidence": False, "formal_credit": "none", "no_publish": True}
    if not isinstance(bundle, Mapping):
        base["errors"] = [_issue("invalid_bundle", "bundle must be an object")]
        return base
    allowed = {"schema", "candidate_id", "run_id", "state", "provenance_class", "source_identity", "source", "axis_materials", "candidate_ref", "run_ref", "authority_ref", "refs", "candidate_axis_edges", "canonical_preimage_sha256", "bundle_digest", "formal_credit", "no_publish"}
    errors.extend(_unknowns(bundle, allowed, "bundle"))
    if bundle.get("schema") != SCHEMA_VERSION:
        errors.append(_issue("unknown_schema", "bundle schema is not the frozen UP1 r4 schema", "schema"))
    if "formal_credit" in bundle and bundle.get("formal_credit") != "none":
        errors.append(_issue("formal_credit_escalation", "formal_credit is permanently none", "formal_credit"))
    if "no_publish" in bundle and bundle.get("no_publish") is not True:
        errors.append(_issue("publish_forbidden", "no_publish must remain true", "no_publish"))
    state = bundle.get("state")
    if state not in {"TEST_ONLY", "TYPED_ABSENT", "typed_absent", "typed_absence", "EXTERNAL_ISSUED"}:
        errors.append(_issue("unknown_state", "state is not a frozen enum", "state"))
    provenance = bundle.get("provenance_class")
    if provenance not in {"test_fixture", "external_material_absent", "external_issued"}:
        errors.append(_issue("unknown_provenance_class", "provenance_class is not a frozen enum", "provenance_class"))
    if "bundle_digest" in bundle:
        if not _is_hex(bundle.get("bundle_digest"), 64) or bundle.get("bundle_digest") != bundle_digest(bundle):
            errors.append(_issue("bundle_hash_mismatch", "bundle_digest does not match domain-separated bundle preimage", "bundle_digest"))
    if "canonical_preimage_sha256" in bundle:
        expected_preimage = hashlib.sha256(bundle_preimage(bundle)).hexdigest()
        if not _is_hex(bundle.get("canonical_preimage_sha256"), 64) or bundle.get("canonical_preimage_sha256") != expected_preimage:
            errors.append(_issue("preimage_hash_mismatch", "canonical_preimage_sha256 does not match bundle preimage", "canonical_preimage_sha256"))
    candidate_id = bundle.get("candidate_id")
    run_id = bundle.get("run_id")
    if not isinstance(candidate_id, str) or not candidate_id:
        errors.append(_issue("missing_candidate", "candidate_id is required", "candidate_id"))
    if not isinstance(run_id, str) or not run_id:
        errors.append(_issue("missing_run", "run_id is required", "run_id"))
    identity = bundle.get("source_identity", bundle.get("source"))
    if not isinstance(identity, Mapping):
        errors.append(_issue("missing_source_identity", "source_identity is required", "source_identity"))
        identity = {}
    else:
        identity_allowed = {"identity_schema_version", "repository_locator", "source_locator", "locator", "source_files", "raw_bytes", "raw_sha256", "head", "head_tree", "dirty_status", "dirty_status_digest", "patch_digest", "untracked_files", "untracked_content_digest", "submodule_closure", "git_evidence", "source_identity_digest", "identity_digest", "axis_edges", "candidate_axis_edges", "canonical_preimage_sha256"}
        errors.extend(_unknowns(identity, identity_allowed, "source_identity"))
        if identity.get("identity_schema_version") != IDENTITY_SCHEMA_VERSION:
            errors.append(_issue("unknown_identity_schema", "identity_schema_version is not frozen", "source_identity.identity_schema_version"))
        locator = identity.get("source_locator", identity.get("locator", identity.get("repository_locator")))
        if not isinstance(locator, str) or not locator:
            errors.append(_issue("missing_source_locator", "source locator is required", "source_identity.source_locator"))
        if not isinstance(identity.get("raw_bytes"), int) or identity.get("raw_bytes") < 0:
            errors.append(_issue("missing_raw_bytes", "raw_bytes must be a non-negative integer", "source_identity.raw_bytes"))
        if not _is_hex(identity.get("raw_sha256"), 64):
            errors.append(_issue("invalid_raw_hash", "raw_sha256 must be lowercase SHA-256", "source_identity.raw_sha256"))
        for key in ("head", "head_tree"):
            if not _is_hex(identity.get(key), 40):
                errors.append(_issue("invalid_git_identity", f"{key} must be a 40-character git object id", f"source_identity.{key}"))
        for key in ("dirty_status_digest", "patch_digest", "untracked_content_digest"):
            if not _is_hex(identity.get(key), 64):
                errors.append(_issue("invalid_git_digest", f"{key} must be lowercase SHA-256", f"source_identity.{key}"))
        if identity.get("dirty_status") not in {"clean", "dirty"}:
            errors.append(_issue("invalid_dirty_status", "dirty_status must be clean or dirty", "source_identity.dirty_status"))
        if "git_evidence" in identity:
            git_evidence = identity.get("git_evidence")
            expected_git = {key: identity.get(key) for key in ("head", "head_tree", "dirty_status", "dirty_status_digest", "patch_digest", "untracked_files", "untracked_content_digest", "submodule_closure")}
            if not isinstance(git_evidence, Mapping) or git_evidence != expected_git:
                errors.append(_issue("git_evidence_mismatch", "git_evidence must exactly mirror captured git fields", "source_identity.git_evidence"))
        if not isinstance(identity.get("untracked_files"), list):
            errors.append(_issue("invalid_untracked_files", "untracked_files must be an array", "source_identity.untracked_files"))
        elif identity.get("untracked_content_digest") != canonical_digest(identity["untracked_files"]):
            errors.append(_issue("untracked_content_hash_mismatch", "untracked content digest mismatch", "source_identity.untracked_content_digest"))
        closure = identity.get("submodule_closure")
        if not isinstance(closure, Mapping) or not isinstance(closure.get("applicable"), bool):
            errors.append(_issue("invalid_submodule_closure", "submodule_closure.applicable must be explicit", "source_identity.submodule_closure"))
        elif closure["applicable"] and not _is_hex(closure.get("digest"), 64):
            errors.append(_issue("missing_submodule_closure_digest", "applicable submodule closure requires digest", "source_identity.submodule_closure.digest"))
        if isinstance(identity.get("source_files"), list):
            for index, record in enumerate(identity["source_files"]):
                if (not isinstance(record, Mapping) or set(record) != {"locator", "raw_bytes", "raw_sha256"} or
                        not isinstance(record.get("locator"), str) or not record.get("locator") or
                        not isinstance(record.get("raw_bytes"), int) or record.get("raw_bytes") < 0 or
                        not _is_hex(record.get("raw_sha256"), 64)):
                    errors.append(_issue("invalid_source_file_record", "source file requires locator, raw_bytes and raw_sha256", f"source_identity.source_files[{index}]"))
            total = sum(item.get("raw_bytes", -1) for item in identity["source_files"] if isinstance(item, Mapping))
            if total != identity.get("raw_bytes"):
                errors.append(_issue("raw_bytes_mismatch", "raw_bytes does not equal source file bytes", "source_identity.raw_bytes"))
            if identity.get("raw_sha256") != canonical_digest(identity["source_files"]):
                errors.append(_issue("raw_hash_mismatch", "raw_sha256 does not match source file records", "source_identity.raw_sha256"))
        declared = _source_digest_from(identity)
        if not _is_hex(declared, 64) or declared != source_identity_digest(identity):
            errors.append(_issue("hash_mismatch", "source identity digest mismatch", "source_identity.source_identity_digest"))
    if observed_source_identity is None:
        errors.append(_issue("missing_observed_source", "fresh observed source identity is required"))
    elif not isinstance(observed_source_identity, Mapping):
        errors.append(_issue("invalid_observed_source", "observed source identity must be an object"))
    elif _source_digest_from(observed_source_identity) != source_identity_digest(observed_source_identity):
        errors.append(_issue("observed_source_hash_mismatch", "observed source digest mismatch"))
    elif source_identity_digest(identity) != source_identity_digest(observed_source_identity):
        errors.append(_issue("source_drift", "observed source differs from bound source"))

    refs = bundle.get("refs")
    if refs is not None and not isinstance(refs, Mapping):
        errors.append(_issue("invalid_refs", "refs must be an object", "refs"))
        refs = {}
    refs = refs if isinstance(refs, Mapping) else {}
    resolved_refs = {key: bundle.get(f"{key}_ref", refs.get(key)) for key in ("candidate", "run", "authority")}
    for key, ref in resolved_refs.items():
        if ref is None:
            errors.append(_issue("missing_ref", f"{key}_ref is required", f"{key}_ref"))
        elif not _ref_valid(ref):
            errors.append(_issue("invalid_ref", f"{key}_ref is malformed", f"{key}_ref"))

    materials = _material_list(bundle.get("axis_materials"))
    if not isinstance(bundle.get("axis_materials"), list):
        errors.append(_issue("invalid_materials_type", "axis_materials must be an array", "axis_materials"))
    seen: set[str] = set()
    for index, material in enumerate(materials):
        if not isinstance(material, Mapping):
            errors.append(_issue("invalid_material_type", "axis material must be an object", f"axis_materials[{index}]"))
            continue
        allowed_material = {"axis", "material_id", "namespace", "version", "issuer", "issued_at", "candidate_id", "run_id", "source_identity_digest", "payload", "raw", "raw_locator", "raw_bytes", "raw_sha256", "digest", "material_digest", "source_edge", "candidate_edge", "run_edge", "authority_edge", "candidate_ref", "run_ref", "authority_ref", "canonical_preimage_sha256"}
        errors.extend(_unknowns(material, allowed_material, f"axis_materials[{index}]"))
        axis = material.get("axis")
        if not isinstance(axis, str) or axis not in AXES:
            errors.append(_issue("unknown_axis", "axis is not one of the frozen four axes", f"axis_materials[{index}].axis"))
        elif axis in seen:
            errors.append(_issue("duplicate_axis", "duplicate axis material", f"axis_materials[{index}].axis"))
        else:
            seen.add(axis)
        if not isinstance(material.get("material_id"), str) or not material.get("material_id"):
            errors.append(_issue("missing_material_id", "material_id is required", f"axis_materials[{index}].material_id"))
        for key in ("namespace", "version", "issuer", "candidate_id", "run_id", "source_identity_digest"):
            if not isinstance(material.get(key), str) or not material.get(key):
                errors.append(_issue("missing_material_field", f"{key} is required", f"axis_materials[{index}].{key}"))
        if not _parse_time(material.get("issued_at")):
            errors.append(_issue("invalid_issued_time", "issued_at must be RFC3339 UTC ending in Z", f"axis_materials[{index}].issued_at"))
        if not isinstance(material.get("payload"), Mapping):
            errors.append(_issue("invalid_payload", "payload must be an object", f"axis_materials[{index}].payload"))
        declared = material.get("digest", material.get("material_digest"))
        if not _is_hex(declared, 64) or declared != material_digest(material):
            errors.append(_issue("hash_mismatch", "axis material digest mismatch", f"axis_materials[{index}].digest"))
        if material.get("candidate_id") != candidate_id:
            errors.append(_issue("foreign_candidate", "axis material candidate differs", f"axis_materials[{index}].candidate_id"))
        if material.get("run_id") != run_id:
            errors.append(_issue("foreign_run", "axis material run differs", f"axis_materials[{index}].run_id"))
        if material.get("source_identity_digest") != _source_digest_from(identity):
            errors.append(_issue("foreign_source_identity", "axis material source differs", f"axis_materials[{index}].source_identity_digest"))
        for key in ("candidate_ref", "run_ref", "authority_ref"):
            if key in material and material[key] != resolved_refs[key[:-4]]:
                errors.append(_issue("ref_mismatch", f"axis material {key} differs from bundle ref", f"axis_materials[{index}].{key}"))
        raw = material.get("raw")
        if raw is not None:
            if not isinstance(raw, Mapping) or not isinstance(raw.get("locator"), str) or not isinstance(raw.get("raw_bytes"), int) or not _is_hex(raw.get("raw_sha256"), 64):
                errors.append(_issue("invalid_raw_material", "raw material requires locator, raw_bytes and raw_sha256", f"axis_materials[{index}].raw"))
        elif "raw_sha256" in material or "raw_bytes" in material or "raw_locator" in material:
            if not isinstance(material.get("raw_locator"), str) or not isinstance(material.get("raw_bytes"), int) or not _is_hex(material.get("raw_sha256"), 64):
                errors.append(_issue("invalid_raw_material", "raw material requires raw_locator, raw_bytes and raw_sha256", f"axis_materials[{index}]"))

    # Optional reverse-edge maps are still exact when present.  They are
    # derived joins, never an alternate source of identity.
    for map_name, edge_key in (("axis_edges", "source_identity"), ("candidate_axis_edges", "candidate")):
        edge_map = identity.get(map_name) if map_name == "axis_edges" else bundle.get(map_name)
        if edge_map is None:
            continue
        if not isinstance(edge_map, Mapping) or set(edge_map) != set(AXES):
            errors.append(_issue("edge_set_mismatch", f"{map_name} must contain exactly the four axes", map_name))
            continue
        by_axis = {m.get("axis"): m for m in materials if isinstance(m, Mapping)}
        for axis, edge in edge_map.items():
            material = by_axis.get(axis)
            if not isinstance(edge, Mapping) or not isinstance(material, Mapping):
                errors.append(_issue("edge_mismatch", "edge must point to an existing axis material", f"{map_name}.{axis}"))
                continue
            expected = {"axis": axis, "candidate_id": candidate_id, "run_id": run_id, "source_identity_digest": _source_digest_from(identity), "material_id": material.get("material_id"), "material_digest": material.get("digest", material.get("material_digest")), "namespace": material.get("namespace"), "version": material.get("version"), "issuer": material.get("issuer"), "issued_at": material.get("issued_at")}
            if any(key not in expected or edge.get(key) != expected[key] for key in edge):
                errors.append(_issue("edge_mismatch", "reverse edge is not an exact material join", f"{map_name}.{axis}"))

    missing = sorted(set(AXES).difference(seen))
    absent = state in _ABSENT
    if absent and materials:
        errors.append(_issue("absence_with_materials", "typed absence cannot contain axis materials", "axis_materials"))
    if not absent and missing:
        errors.append(_issue("missing_axis", f"missing axis material(s): {missing}", "axis_materials"))
    if state == "TEST_ONLY" and provenance != "test_fixture":
        errors.append(_issue("state_profile_mismatch", "TEST_ONLY requires test_fixture", "provenance_class"))
    if absent and provenance != "external_material_absent":
        errors.append(_issue("state_profile_mismatch", "typed absence requires external_material_absent", "provenance_class"))
    if state == "EXTERNAL_ISSUED":
        errors.append(_issue("external_material_not_supported", "this offline prototype cannot publish external authority", "state"))
    if not absent and not missing and materials:
        checks["exact_axis_set"] = set(seen) == set(AXES) and len(materials) == len(AXES)
    checks["source_identity_match"] = not any(error["code"] in {"source_drift", "foreign_source_identity", "hash_mismatch"} for error in errors)
    checks["refs_present"] = all(_ref_valid(ref) for ref in resolved_refs.values())
    if errors:
        result = dict(base)
        result.update({"candidate_id": candidate_id, "run_id": run_id, "axis_set": sorted(seen), "missing_axes": missing, "checks": checks, "errors": _ordered(errors)})
        return result
    if absent:
        return {**base, "valid": True, "status": "typed_absent", "admission": "terminal_deferred", "classification": "non_evidence", "candidate_id": candidate_id, "run_id": run_id, "axis_set": [], "missing_axes": list(AXES), "checks": checks, "errors": []}
    return {**base, "valid": True, "status": "TEST_ONLY", "admission": "admitted_non_evidence", "classification": "non_evidence", "candidate_id": candidate_id, "run_id": run_id, "axis_set": sorted(seen), "missing_axes": [], "checks": checks, "errors": []}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate UP1 r4 source/four-axis binding")
    parser.add_argument("--input", type=Path)
    parser.add_argument("--observed-source", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        raw = args.input.read_bytes() if args.input else sys.stdin.buffer.read()
        bundle = json.loads(raw.decode("utf-8"), object_pairs_hook=_reject_duplicate_pairs)
        observed = json.loads(args.observed_source.read_text(encoding="utf-8"), object_pairs_hook=_reject_duplicate_pairs) if args.observed_source else None
        receipt = validate_bundle(bundle, observed)
        encoded = canonical_bytes(receipt) + b"\n"
        if args.output:
            args.output.write_bytes(encoded)
        sys.stdout.buffer.write(encoded)
        return 0 if receipt.get("valid") else 1
    except DuplicateJSONKeyError as exc:
        sys.stdout.buffer.write(canonical_bytes({"valid": False, "status": "fail_closed", "authority_evidence": False, "formal_credit": "none", "no_publish": True, "errors": [{"code": "duplicate_json_key", "message": str(exc)}]}) + b"\n")
        return 1
    except (OSError, UnicodeError, json.JSONDecodeError, TypeError, ValueError) as exc:
        sys.stdout.buffer.write(canonical_bytes({"valid": False, "status": "program_exception", "authority_evidence": False, "formal_credit": "none", "no_publish": True, "errors": [{"code": "program_exception", "message": str(exc)}]}) + b"\n")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
