"""Strict, offline validator for the UP1 R2 environment closure.

The validator has three intentionally separate evidence layers:

* ``local_observation``: values measured from this host (never authority);
* ``reproducible_declaration``: a candidate's declared lock/recipe closure;
* ``authority_proof``: a signed, externally verifiable provenance receipt.

Only the third layer can promote a closure to ``present``.  A missing signed
receipt is a typed absence; contradictory bytes or malformed declarations are
fail-closed.  ``TEST_ONLY`` documents are always ``non_evidence``.
"""
from __future__ import annotations

import hashlib
import json
import os
import platform
import re
import base64
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping

try:
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
except ImportError:  # pragma: no cover - environment policy is checked by CLI
    InvalidSignature = Exception  # type: ignore[assignment,misc]
    Ed25519PublicKey = None  # type: ignore[assignment,misc]

HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")
TYPED_ABSENT = "typed_absent"
FAIL_CLOSED = "fail_closed"
PRESENT = "present"
NON_EVIDENCE = "non_evidence"

REQUIRED_ROOT = {
    "schema", "fixture_role", "candidate_ref", "status", "claim_ceiling",
    "local_observation", "reproducible_declaration", "authority_proof",
    "package_locks", "runtimes", "binaries", "sbom",
}
OPTIONAL_ROOT = {"environment_variables", "locale_timezone", "artifact_inputs", "import_closure", "module_paths", "expected_context"}
OBS_KEYS = {"os", "architecture", "runtime_paths", "observed_utc", "evidence_class"}
OS_KEYS = {"name", "version", "architecture"}
RUNTIME_KEYS = {"name", "version", "path", "sha256", "role", "evidence_class"}
LOCK_KEYS = {"name", "path", "sha256", "kind", "evidence_class"}
PATH_KEYS = {"name", "version", "path", "sha256", "type", "evidence_class"}
BINARY_KEYS = {
    "name", "version", "path", "sha256", "publisher", "signature",
    "download_receipt", "build_recipe", "sbom_refs", "license", "evidence_class",
}
SIG_KEYS = {"algorithm", "key_id", "signature", "verified", "issuer", "trust_root", "profile", "subject_sha256", "subject_name", "subject_version", "subject_path", "public_key_b64", "signature_b64"}
RECEIPT_KEYS = {"origin", "receipt_id", "receipt_sha256", "retrieved_utc", "signed", "subject_sha256", "subject_name", "subject_version", "subject_path", "subject_binary_sha256"}
RECIPE_KEYS = {"kind", "uri", "sha256", "digest", "subject_sha256", "subject_name", "subject_version", "subject_path", "subject_binary_sha256"}
SBOM_KEYS = {"format", "spec_version", "document_sha256", "components", "dependency_edges", "evidence_class"}
COMPONENT_KEYS = {"bom_ref", "name", "version", "purl", "sha256", "supplier", "license"}
EDGE_KEYS = {"ref", "depends_on"}
DECL_KEYS = {"schema", "candidate_ref", "source_revision", "lock_hashes", "runtime_hashes", "binary_hashes", "recipe_hashes", "sbom_document_sha256", "authenticated_closure", "declaration_sha256", "evidence_class"}
AUTH_KEYS = {"status", "signed_receipt", "authority", "signature", "outer_envelope", "verified_at_utc", "evidence_class"}
SIGNED_KEYS = {"receipt_id", "payload_sha256", "signature", "algorithm", "key_id", "issuer", "trust_root", "verification_method", "profile", "expected_context_sha256", "public_key_b64", "signature_b64", "payload"}
ABSENCE_KEYS = {"absence_code", "owner", "authoritative_source", "recovery_condition"}
CONTEXT_KEYS = {"candidate_ref", "source_revision", "frozen_root", "profile", "lock_identities", "binary_identities", "authenticated_closure"}
AUTHENTICATED_CLOSURE_KEYS = {"authority", "download_receipts", "binary_licenses", "sbom_components"}
TRUST_ANCHOR_KEYS = {"public_key_b64", "key_id", "issuer", "trust_root", "policy"}


class ProvenanceError(ValueError):
    """A structural or semantic defect that must fail closed."""


class DuplicateKeyError(ProvenanceError):
    pass


class MissingProvenanceError(ProvenanceError):
    """Production proof material is absent (typed absence, never admission)."""
    pass


def _pairs_hook(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKeyError(f"duplicate_key:{key}")
        result[key] = value
    return result


def load_json(path: str | os.PathLike[str]) -> dict[str, Any]:
    """Load JSON with duplicate-key rejection and a root-object check."""
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"), object_pairs_hook=_pairs_hook)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ProvenanceError(f"invalid_json:{exc}") from exc
    if not isinstance(value, dict):
        raise ProvenanceError("root_not_object")
    return value


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def canonical_sha256(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def _b64(value: Any, label: str) -> bytes:
    text = _str(value, label)
    try:
        decoded = base64.b64decode(text.encode("ascii"), validate=True)
    except (ValueError, UnicodeError) as exc:
        raise ProvenanceError(f"invalid_base64:{label}") from exc
    if not decoded:
        raise ProvenanceError(f"empty_base64:{label}")
    return decoded


def _verify_ed25519(public_key_b64: Any, signature_b64: Any, payload: Any, label: str) -> None:
    if Ed25519PublicKey is None:
        raise ProvenanceError("cryptography_unavailable")
    public = _b64(public_key_b64, f"{label}.public_key_b64")
    signature = _b64(signature_b64, f"{label}.signature_b64")
    try:
        Ed25519PublicKey.from_public_bytes(public).verify(signature, canonical_bytes(payload))
    except (ValueError, InvalidSignature) as exc:
        raise ProvenanceError(f"invalid_signature:{label}") from exc


def file_sha256(path: str | os.PathLike[str]) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _unknown(obj: Mapping[str, Any], allowed: set[str], label: str) -> None:
    extra = sorted(set(obj) - allowed)
    if extra:
        raise ProvenanceError(f"unknown_fields:{label}:{','.join(extra)}")


def _required(obj: Mapping[str, Any], names: set[str], label: str) -> None:
    missing = sorted(names - set(obj))
    if missing:
        raise ProvenanceError(f"missing_fields:{label}:{','.join(missing)}")


def _str(value: Any, label: str, *, nonempty: bool = True) -> str:
    if not isinstance(value, str) or (nonempty and not value.strip()):
        raise ProvenanceError(f"invalid_string:{label}")
    return value


def _hash(value: Any, label: str) -> str:
    value = _str(value, label)
    if not HEX64.fullmatch(value):
        raise ProvenanceError(f"invalid_sha256:{label}")
    return value.lower()


def _utc(value: Any, label: str) -> None:
    text = _str(value, label)
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ProvenanceError(f"invalid_utc:{label}") from exc
    if parsed.tzinfo is None:
        raise ProvenanceError(f"utc_requires_timezone:{label}")


def _evidence_class(value: Any, label: str) -> None:
    if value not in {"local_observation", "reproducible_declaration", "authority_proof"}:
        raise ProvenanceError(f"invalid_evidence_class:{label}")


def _absence(obj: Mapping[str, Any], label: str) -> None:
    _required(obj, ABSENCE_KEYS, label)
    for key in ABSENCE_KEYS:
        if key == "absence_code":
            _str(obj[key], f"{label}.{key}")
        elif obj[key] in (None, ""):
            raise ProvenanceError(f"missing_absence_accountability:{label}.{key}")


def _check_path_hash(item: Mapping[str, Any], label: str, root: Path | None) -> None:
    path = _str(item["path"], f"{label}.path")
    # Without an explicit verification root this is only a declaration. A
    # process cwd must never silently turn a TEST_ONLY relative path into a
    # host-bound hash check (or permit production closure without a root).
    if root is None:
        return
    actual_path = Path(path)
    if root is not None and not actual_path.is_absolute():
        actual_path = root / actual_path
    if actual_path.exists():
        actual = file_sha256(actual_path)
        expected = _hash(item["sha256"], f"{label}.sha256")
        if actual != expected:
            raise ProvenanceError(f"hash_drift:{label}:expected={expected}:actual={actual}")


def _check_signed_path(item: Mapping[str, Any], label: str, root: Path | None, signed: bool) -> None:
    """Signed closures must resolve every path beneath the supplied root."""
    path = _str(item["path"], f"{label}.path")
    candidate = Path(path)
    if not signed:
        return
    if root is None:
        raise ProvenanceError(f"signed_path_root_missing:{label}")
    if candidate.is_absolute() or ".." in candidate.parts:
        raise ProvenanceError(f"absolute_or_traversal_path:{label}")
    resolved_root = root.resolve()
    resolved = (resolved_root / candidate).resolve()
    try:
        resolved.relative_to(resolved_root)
    except ValueError as exc:
        raise ProvenanceError(f"path_escape:{label}") from exc
    if not resolved.is_file():
        raise ProvenanceError(f"path_missing:{label}")


def _validate_os(obs: Mapping[str, Any]) -> None:
    _unknown(obs, OBS_KEYS, "local_observation")
    _required(obs, OBS_KEYS, "local_observation")
    _unknown(obs["os"], OS_KEYS, "local_observation.os")
    _required(obs["os"], OS_KEYS, "local_observation.os")
    for key in OS_KEYS:
        _str(obs["os"][key], f"local_observation.os.{key}")
    _str(obs["architecture"], "local_observation.architecture")
    _utc(obs["observed_utc"], "local_observation.observed_utc")
    _evidence_class(obs["evidence_class"], "local_observation")
    if obs["evidence_class"] != "local_observation":
        raise ProvenanceError("observation_layer_mislabelled")
    if not isinstance(obs["runtime_paths"], list):
        raise ProvenanceError("runtime_paths_not_array")


def _validate_runtime_paths(items: Any, runtime_items: list[Mapping[str, Any]], *, signed: bool, root: Path | None) -> None:
    if not isinstance(items, list):
        raise ProvenanceError("runtime_paths_not_array")
    if len(items) != len(runtime_items):
        raise ProvenanceError("runtime_paths_runtime_count_mismatch")
    expected = {str(item["name"]).lower(): item for item in runtime_items}
    seen: set[str] = set()
    for index, item in enumerate(items):
        label = f"local_observation.runtime_paths[{index}]"
        if not isinstance(item, dict):
            raise ProvenanceError(f"not_object:{label}")
        _unknown(item, PATH_KEYS, label)
        _required(item, PATH_KEYS, label)
        name = _str(item["name"], f"{label}.name").lower()
        if name in seen or name not in expected:
            raise ProvenanceError(f"runtime_path_identity_invalid:{name}")
        seen.add(name)
        for key in ("version", "path", "type"):
            _str(item[key], f"{label}.{key}")
        if item["type"] != "executable":
            raise ProvenanceError(f"runtime_path_type_invalid:{name}")
        _hash(item["sha256"], f"{label}.sha256")
        _evidence_class(item["evidence_class"], label)
        if item["evidence_class"] != "local_observation":
            raise ProvenanceError(f"runtime_path_layer_mislabelled:{name}")
        _check_signed_path(item, label, root, signed)
        if item["name"] != expected[name]["name"] or item["version"] != expected[name]["version"] or item["path"] != expected[name]["path"] or item["sha256"].lower() != expected[name]["sha256"].lower():
            raise ProvenanceError(f"runtime_path_binding_drift:{name}")


def _validate_runtimes(items: Any, root: Path | None, *, signed: bool) -> dict[str, Mapping[str, Any]]:
    if not isinstance(items, list):
        raise ProvenanceError("runtimes_not_array")
    found: dict[str, Mapping[str, Any]] = {}
    for index, item in enumerate(items):
        label = f"runtimes[{index}]"
        if not isinstance(item, dict):
            raise ProvenanceError(f"not_object:{label}")
        _unknown(item, RUNTIME_KEYS, label)
        _required(item, RUNTIME_KEYS, label)
        name = _str(item["name"], f"{label}.name")
        if name.lower() in found:
            raise ProvenanceError(f"duplicate_runtime:{name}")
        _str(item["version"], f"{label}.version")
        _str(item["path"], f"{label}.path")
        _hash(item["sha256"], f"{label}.sha256")
        _str(item["role"], f"{label}.role")
        _evidence_class(item["evidence_class"], label)
        _check_signed_path(item, label, root, signed)
        _check_path_hash(item, label, root)
        found[name.lower()] = item
    for expected in ("julia", "python"):
        if expected not in found:
            raise ProvenanceError(f"required_runtime_missing:{expected}")
    return found


def _validate_locks(items: Any, root: Path | None, *, signed: bool) -> list[str]:
    if not isinstance(items, list):
        raise ProvenanceError("package_locks_not_array")
    paths: list[str] = []
    names_seen: set[str] = set()
    for index, item in enumerate(items):
        label = f"package_locks[{index}]"
        if not isinstance(item, dict):
            raise ProvenanceError(f"not_object:{label}")
        _unknown(item, LOCK_KEYS, label)
        _required(item, LOCK_KEYS, label)
        name = _str(item["name"], f"{label}.name")
        if name.lower() in names_seen:
            raise ProvenanceError(f"duplicate_lock_name:{name}")
        names_seen.add(name.lower())
        path = _str(item["path"], f"{label}.path")
        _hash(item["sha256"], f"{label}.sha256")
        _str(item["kind"], f"{label}.kind")
        _evidence_class(item["evidence_class"], label)
        _check_signed_path(item, label, root, signed)
        _check_path_hash(item, label, root)
        if name in {"Project.toml", "Manifest.toml"}:
            paths.append(name)
    if set(paths) != {"Project.toml", "Manifest.toml"}:
        raise ProvenanceError("project_manifest_pair_incomplete")
    return paths


def _validate_signature(sig: Any, label: str, *, binary: bool = True, strict: bool = False, expected_anchor: Mapping[str, Any] | None = None, expected_profile: str | None = None) -> None:
    if not isinstance(sig, dict):
        raise ProvenanceError(f"not_object:{label}")
    _unknown(sig, SIG_KEYS, label)
    required = {"algorithm", "key_id", "signature", "verified", "issuer", "trust_root"}
    if binary:
        required |= {"subject_sha256", "subject_name", "subject_version", "subject_path"}
    if strict:
        required |= {"profile"}
    _required(sig, required, label)
    for key in ("algorithm", "key_id", "signature", "issuer", "trust_root"):
        _str(sig[key], f"{label}.{key}")
    if binary:
        _hash(sig["subject_sha256"], f"{label}.subject_sha256")
        for key in ("subject_name", "subject_version", "subject_path"):
            _str(sig[key], f"{label}.{key}")
        if strict:
            missing = {"public_key_b64", "signature_b64"} - set(sig)
            if missing or any(sig.get(key) in (None, "") for key in ("public_key_b64", "signature_b64")):
                raise MissingProvenanceError(f"missing_signature_material:{label}")
            if sig["signature"] != sig["signature_b64"]:
                raise ProvenanceError(f"opaque_signature_alias_mismatch:{label}")
            if expected_anchor is not None:
                for key in ("key_id", "issuer", "trust_root"):
                    if sig[key] != expected_anchor[key]:
                        raise ProvenanceError(f"signature_anchor_{key}_mismatch:{label}")
                if sig["public_key_b64"] != expected_anchor["public_key_b64"]:
                    raise ProvenanceError(f"signature_anchor_key_mismatch:{label}")
            if expected_profile is not None and sig.get("profile") != expected_profile:
                raise ProvenanceError(f"signature_profile_mismatch:{label}")
            _verify_ed25519(sig["public_key_b64"], sig["signature_b64"], {"name": sig["subject_name"], "version": sig["subject_version"], "path": sig["subject_path"], "sha256": sig["subject_sha256"]}, label)
    if sig["verified"] is not True:
        raise ProvenanceError(f"signature_not_verified:{label}")


def _validate_receipt(receipt: Any, label: str) -> None:
    if not isinstance(receipt, dict):
        raise ProvenanceError(f"not_object:{label}")
    _unknown(receipt, RECEIPT_KEYS, label)
    _required(receipt, RECEIPT_KEYS, label)
    _str(receipt["origin"], f"{label}.origin")
    _str(receipt["receipt_id"], f"{label}.receipt_id")
    _hash(receipt["receipt_sha256"], f"{label}.receipt_sha256")
    for key in ("subject_sha256", "subject_binary_sha256"):
        _hash(receipt[key], f"{label}.{key}")
    for key in ("subject_name", "subject_version", "subject_path"):
        _str(receipt[key], f"{label}.{key}")
    _utc(receipt["retrieved_utc"], f"{label}.retrieved_utc")
    if receipt["signed"] is not True:
        raise ProvenanceError(f"download_receipt_not_signed:{label}")
    payload = dict(receipt)
    payload.pop("receipt_sha256")
    if canonical_sha256(payload) != receipt["receipt_sha256"].lower():
        raise ProvenanceError(f"download_receipt_digest_mismatch:{label}")


def _validate_recipe(recipe: Any, label: str) -> None:
    if not isinstance(recipe, dict):
        raise ProvenanceError(f"not_object:{label}")
    _unknown(recipe, RECIPE_KEYS, label)
    _required(recipe, RECIPE_KEYS, label)
    _str(recipe["kind"], f"{label}.kind")
    if recipe["kind"] not in {"container", "build_recipe"}:
        raise ProvenanceError(f"unsupported_build_recipe_kind:{label}")
    _str(recipe["uri"], f"{label}.uri")
    _hash(recipe["sha256"], f"{label}.sha256")
    _str(recipe["digest"], f"{label}.digest")
    _hash(recipe["subject_sha256"], f"{label}.subject_sha256")
    _hash(recipe["subject_binary_sha256"], f"{label}.subject_binary_sha256")
    for key in ("subject_name", "subject_version", "subject_path"):
        _str(recipe[key], f"{label}.{key}")
    payload = dict(recipe)
    payload.pop("sha256")
    payload.pop("digest")
    if canonical_sha256(payload) != recipe["sha256"].lower():
        raise ProvenanceError(f"build_recipe_digest_mismatch:{label}")
    if recipe["digest"] != "sha256:" + recipe["sha256"].lower():
        raise ProvenanceError(f"build_recipe_digest_prefix_mismatch:{label}")


def _validate_binaries(items: Any, root: Path | None, *, signed: bool, strict_signatures: bool = False, expected_profile: str | None = None, expected_anchor: Mapping[str, Any] | None = None) -> None:
    if not isinstance(items, list) or not items:
        raise ProvenanceError("binaries_not_nonempty_array")
    names_seen: set[str] = set()
    for index, item in enumerate(items):
        label = f"binaries[{index}]"
        if not isinstance(item, dict):
            raise ProvenanceError(f"not_object:{label}")
        _unknown(item, BINARY_KEYS, label)
        _required(item, BINARY_KEYS, label)
        for key in ("name", "version", "path", "publisher", "license"):
            _str(item[key], f"{label}.{key}")
        normalized_name = item["name"].lower()
        if normalized_name in names_seen:
            raise ProvenanceError(f"duplicate_binary_name:{item['name']}")
        names_seen.add(normalized_name)
        _hash(item["sha256"], f"{label}.sha256")
        _evidence_class(item["evidence_class"], label)
        _check_signed_path(item, label, root, signed)
        _validate_signature(item["signature"], f"{label}.signature", strict=strict_signatures, expected_anchor=expected_anchor, expected_profile=expected_profile)
        if strict_signatures and item["signature"].get("profile") != expected_profile:
            raise ProvenanceError(f"binary_signature_profile_mismatch:{label}")
        _validate_receipt(item["download_receipt"], f"{label}.download_receipt")
        _validate_recipe(item["build_recipe"], f"{label}.build_recipe")
        subject = {"name": item["name"], "version": item["version"], "path": item["path"], "sha256": item["sha256"].lower(), "publisher": item["publisher"]}
        subject_digest = canonical_sha256(subject)
        for nested_label, nested in (("signature", item["signature"]), ("download_receipt", item["download_receipt"]), ("build_recipe", item["build_recipe"])):
            if nested["subject_sha256"].lower() != subject_digest or nested["subject_name"] != item["name"] or nested["subject_version"] != item["version"] or nested["subject_path"] != item["path"]:
                raise ProvenanceError(f"binary_subject_binding_drift:{label}.{nested_label}")
            if nested.get("subject_binary_sha256", item["sha256"]).lower() != item["sha256"].lower():
                raise ProvenanceError(f"binary_hash_binding_drift:{label}.{nested_label}")
        if not isinstance(item["sbom_refs"], list) or not item["sbom_refs"]:
            raise ProvenanceError(f"sbom_refs_missing:{label}")
        if len(item["sbom_refs"]) != len(set(item["sbom_refs"])):
            raise ProvenanceError(f"duplicate_sbom_ref:{label}")
        for ref in item["sbom_refs"]:
            _str(ref, f"{label}.sbom_refs")
        _check_path_hash(item, label, root)


def _validate_sbom(sbom: Mapping[str, Any]) -> None:
    _unknown(sbom, SBOM_KEYS, "sbom")
    _required(sbom, SBOM_KEYS, "sbom")
    for key in ("format", "spec_version"):
        _str(sbom[key], f"sbom.{key}")
    _hash(sbom["document_sha256"], "sbom.document_sha256")
    _evidence_class(sbom["evidence_class"], "sbom")
    components = sbom["components"]
    edges = sbom["dependency_edges"]
    if not isinstance(components, list) or not components:
        raise ProvenanceError("sbom_components_not_nonempty_array")
    refs: set[str] = set()
    for index, component in enumerate(components):
        label = f"sbom.components[{index}]"
        if not isinstance(component, dict):
            raise ProvenanceError(f"not_object:{label}")
        _unknown(component, COMPONENT_KEYS, label)
        _required(component, COMPONENT_KEYS, label)
        ref = _str(component["bom_ref"], f"{label}.bom_ref")
        if ref in refs:
            raise ProvenanceError(f"duplicate_sbom_ref:{ref}")
        refs.add(ref)
        for key in ("name", "version", "purl", "supplier", "license"):
            _str(component[key], f"{label}.{key}")
        if component["purl"] != f"pkg:generic/{component['name']}@{component['version']}":
            raise ProvenanceError(f"sbom_purl_identity_mismatch:{label}")
        _hash(component["sha256"], f"{label}.sha256")
    if not isinstance(edges, list) or not edges:
        raise ProvenanceError("sbom_dependency_edges_not_array")
    edge_refs: set[str] = set()
    for index, edge in enumerate(edges):
        label = f"sbom.dependency_edges[{index}]"
        if not isinstance(edge, dict):
            raise ProvenanceError(f"not_object:{label}")
        _unknown(edge, EDGE_KEYS, label)
        _required(edge, EDGE_KEYS, label)
        _str(edge["ref"], f"{label}.ref")
        if edge["ref"] in edge_refs:
            raise ProvenanceError(f"duplicate_sbom_edge_ref:{edge['ref']}")
        edge_refs.add(edge["ref"])
        if edge["ref"] not in refs:
            raise ProvenanceError(f"sbom_edge_unknown_ref:{edge['ref']}")
        if not isinstance(edge["depends_on"], list):
            raise ProvenanceError(f"sbom_edge_depends_on_not_array:{label}")
        for dep in edge["depends_on"]:
            if dep not in refs:
                raise ProvenanceError(f"sbom_edge_unknown_dependency:{dep}")
    if edge_refs != refs:
        raise ProvenanceError("sbom_component_edge_coverage_incomplete")
    # A dependency closure is a DAG. Detect self edges and longer cycles
    # independently of input ordering.
    graph = {edge["ref"]: set(edge["depends_on"]) for edge in edges}
    visiting: set[str] = set()
    visited: set[str] = set()
    def visit(ref: str) -> None:
        if ref in visiting:
            raise ProvenanceError(f"sbom_dependency_cycle:{ref}")
        if ref in visited:
            return
        visiting.add(ref)
        for dep in graph[ref]:
            visit(dep)
        visiting.remove(ref)
        visited.add(ref)
    for ref in sorted(refs):
        visit(ref)


def _authenticated_closure(document: Mapping[str, Any]) -> dict[str, Any]:
    """Return the candidate-bound metadata omitted by plain hash maps."""
    authority = document["authority_proof"]
    return {
        "authority": {"authority": authority["authority"], "verified_at_utc": authority["verified_at_utc"]},
        "download_receipts": {
            item["name"]: {"origin": item["download_receipt"]["origin"], "retrieved_utc": item["download_receipt"]["retrieved_utc"]}
            for item in document["binaries"]
        },
        "binary_licenses": {item["name"]: item["license"] for item in document["binaries"]},
        "sbom_components": {
            component["bom_ref"]: {"supplier": component["supplier"], "license": component["license"]}
            for component in document["sbom"]["components"]
        },
    }


def _validate_authenticated_closure(closure: Any, expected: Mapping[str, Any], label: str) -> None:
    if not isinstance(closure, dict):
        raise ProvenanceError(f"{label}_not_object")
    _unknown(closure, AUTHENTICATED_CLOSURE_KEYS, label)
    _required(closure, AUTHENTICATED_CLOSURE_KEYS, label)
    authority = closure["authority"]
    if not isinstance(authority, dict):
        raise ProvenanceError(f"{label}.authority_not_object")
    _unknown(authority, {"authority", "verified_at_utc"}, f"{label}.authority")
    _required(authority, {"authority", "verified_at_utc"}, f"{label}.authority")
    _str(authority["authority"], f"{label}.authority.authority")
    _utc(authority["verified_at_utc"], f"{label}.authority.verified_at_utc")
    for group, fields in (("download_receipts", {"origin", "retrieved_utc"}), ("binary_licenses", None), ("sbom_components", {"supplier", "license"})):
        values = closure[group]
        if not isinstance(values, dict) or not values:
            raise ProvenanceError(f"{label}.{group}_missing")
        for name, value in values.items():
            _str(name, f"{label}.{group}.name")
            if fields is None:
                _str(value, f"{label}.{group}.{name}")
                continue
            if not isinstance(value, dict):
                raise ProvenanceError(f"{label}.{group}.{name}_not_object")
            _unknown(value, fields, f"{label}.{group}.{name}")
            _required(value, fields, f"{label}.{group}.{name}")
            for field in fields:
                _str(value[field], f"{label}.{group}.{name}.{field}")
            if group == "download_receipts":
                _utc(value["retrieved_utc"], f"{label}.{group}.{name}.retrieved_utc")
    if dict(closure) != dict(expected):
        raise ProvenanceError(f"{label}_identity_mismatch")


def _validate_declaration(declaration: Mapping[str, Any], candidate: str | None, expected_closure: Mapping[str, Any]) -> None:
    _unknown(declaration, DECL_KEYS, "reproducible_declaration")
    _required(declaration, DECL_KEYS, "reproducible_declaration")
    _str(declaration["schema"], "reproducible_declaration.schema")
    if candidate is None or declaration["candidate_ref"] != candidate:
        raise ProvenanceError("declaration_candidate_mismatch")
    _str(declaration["source_revision"], "reproducible_declaration.source_revision")
    _validate_authenticated_closure(declaration["authenticated_closure"], expected_closure, "reproducible_declaration.authenticated_closure")
    for key in ("lock_hashes", "runtime_hashes", "binary_hashes", "recipe_hashes"):
        values = declaration[key]
        if not isinstance(values, dict) or not values:
            raise ProvenanceError(f"declaration_{key}_missing")
        for name, value in values.items():
            _str(name, f"{key}.name")
            _hash(value, f"{key}.{name}")
    if not isinstance(declaration["sbom_document_sha256"], list) or not declaration["sbom_document_sha256"]:
        raise ProvenanceError("declaration_sbom_hashes_missing")
    for value in declaration["sbom_document_sha256"]:
        _hash(value, "declaration.sbom_document_sha256")
    declared = dict(declaration)
    declared.pop("declaration_sha256")
    if _hash(declaration["declaration_sha256"], "reproducible_declaration.declaration_sha256") != canonical_sha256(declared):
        raise ProvenanceError("declaration_hash_mismatch")
    _evidence_class(declaration["evidence_class"], "reproducible_declaration")
    if declaration["evidence_class"] != "reproducible_declaration":
        raise ProvenanceError("declaration_layer_mislabelled")


def _validate_expected_context(context: Any, document: Mapping[str, Any]) -> str:
    if not isinstance(context, dict):
        raise ProvenanceError("expected_context_not_object")
    _unknown(context, CONTEXT_KEYS, "expected_context")
    _required(context, CONTEXT_KEYS, "expected_context")
    if context["candidate_ref"] != document["candidate_ref"]:
        raise ProvenanceError("expected_context_candidate_mismatch")
    for key in ("candidate_ref", "source_revision", "frozen_root", "profile"):
        _str(context[key], f"expected_context.{key}")
    _hash(context["frozen_root"], "expected_context.frozen_root")
    for key in ("lock_identities", "binary_identities"):
        values = context[key]
        if not isinstance(values, list) or not values:
            raise ProvenanceError(f"expected_context_{key}_missing")
        seen: set[str] = set()
        for index, item in enumerate(values):
            if not isinstance(item, dict):
                raise ProvenanceError(f"expected_context_{key}[{index}]_not_object")
            _unknown(item, {"name", "version", "path", "sha256"}, f"expected_context.{key}[{index}]")
            _required(item, {"name", "version", "path", "sha256"}, f"expected_context.{key}[{index}]")
            name = _str(item["name"], f"expected_context.{key}[{index}].name").lower()
            if name in seen:
                raise ProvenanceError(f"expected_context_{key}_duplicate:{name}")
            seen.add(name)
            _str(item["version"], f"expected_context.{key}[{index}].version")
            _str(item["path"], f"expected_context.{key}[{index}].path")
            _hash(item["sha256"], f"expected_context.{key}[{index}].sha256")
    _validate_authenticated_closure(context["authenticated_closure"], _authenticated_closure(document), "expected_context.authenticated_closure")
    return canonical_sha256(context)


def _validate_trust_anchor(anchor: Any, document: Mapping[str, Any]) -> str:
    """Validate the caller-supplied trust root, never a bundle field."""
    if not isinstance(anchor, dict):
        raise MissingProvenanceError("trust_anchor_not_supplied")
    _unknown(anchor, TRUST_ANCHOR_KEYS, "trust_anchor")
    _required(anchor, TRUST_ANCHOR_KEYS, "trust_anchor")
    for key in ("key_id", "issuer", "trust_root", "policy"):
        _str(anchor[key], f"trust_anchor.{key}")
    if anchor["policy"] != document["claim_ceiling"]:
        raise ProvenanceError("trust_anchor_policy_mismatch")
    public = _b64(anchor["public_key_b64"], "trust_anchor.public_key_b64")
    if Ed25519PublicKey is None:
        raise ProvenanceError("cryptography_unavailable")
    try:
        Ed25519PublicKey.from_public_bytes(public)
    except ValueError as exc:
        raise ProvenanceError("invalid_trust_anchor_public_key") from exc
    return canonical_sha256(anchor)


def _validate_context_consistency(context: Mapping[str, Any], document: Mapping[str, Any]) -> None:
    declaration = document["reproducible_declaration"]
    if context["source_revision"] != declaration["source_revision"]:
        raise ProvenanceError("expected_context_source_revision_mismatch")
    lock_actual = [{"name": x["name"], "version": x["kind"], "path": x["path"], "sha256": x["sha256"]} for x in document["package_locks"]]
    binary_actual = [{"name": x["name"], "version": x["version"], "path": x["path"], "sha256": x["sha256"]} for x in document["binaries"]]
    if context["lock_identities"] != lock_actual or context["binary_identities"] != binary_actual:
        raise ProvenanceError("expected_context_identity_mismatch")
    if context["authenticated_closure"] != _authenticated_closure(document):
        raise ProvenanceError("expected_context_authenticated_closure_mismatch")


def _validate_envelope_signature(envelope: Any, payload: Any, label: str, *, profile: str, expected_anchor: Mapping[str, Any]) -> None:
    if not isinstance(envelope, dict):
        raise MissingProvenanceError(f"{label}_not_object")
    required = {"payload_sha256", "algorithm", "key_id", "issuer", "trust_root", "public_key_b64", "signature_b64", "profile"}
    missing = required - set(envelope)
    if missing:
        raise MissingProvenanceError(f"missing_fields:{label}:{','.join(sorted(missing))}")
    if any(envelope[key] in (None, "") for key in required):
        raise MissingProvenanceError(f"empty_fields:{label}")
    for key in ("algorithm", "key_id", "issuer", "trust_root", "profile"):
        _str(envelope[key], f"{label}.{key}")
    if envelope["algorithm"] != "ed25519" or envelope["profile"] != profile:
        raise ProvenanceError(f"{label}_algorithm_or_profile_mismatch")
    for key in ("key_id", "issuer", "trust_root"):
        if envelope[key] != expected_anchor[key]:
            raise ProvenanceError(f"{label}_{key}_anchor_mismatch")
    if envelope["public_key_b64"] != expected_anchor["public_key_b64"]:
        raise ProvenanceError(f"{label}_public_key_anchor_mismatch")
    if _hash(envelope["payload_sha256"], f"{label}.payload_sha256") != canonical_sha256(payload):
        raise ProvenanceError(f"{label}_payload_hash_mismatch")
    _verify_ed25519(envelope["public_key_b64"], envelope["signature_b64"], payload, label)


def _validate_authority(auth: Mapping[str, Any], declaration: Mapping[str, Any], context: Mapping[str, Any] | None, context_hash: str | None, anchor: Mapping[str, Any] | None) -> None:
    # Typed absence carries accountable recovery metadata in addition to the
    # normal authority envelope.  Those fields are forbidden on a signed
    # proof, which prevents an unsigned explanation from being mistaken for a
    # proof while still making absence actionable.
    _unknown(auth, AUTH_KEYS | ABSENCE_KEYS, "authority_proof")
    _required(auth, AUTH_KEYS - {"outer_envelope"}, "authority_proof")
    _evidence_class(auth["evidence_class"], "authority_proof")
    if auth["evidence_class"] != "authority_proof":
        raise ProvenanceError("authority_layer_mislabelled")
    if auth["status"] not in {"signed_verified", TYPED_ABSENT}:
        raise ProvenanceError("invalid_authority_status")
    if auth["status"] == TYPED_ABSENT:
        _absence(auth, "authority_proof")
        return
    if context is None or context_hash is None or anchor is None:
        raise MissingProvenanceError("signed_external_context_or_anchor_missing")
    _validate_signature(auth["signature"], "authority_proof.signature", binary=False)
    for key in ("algorithm", "key_id", "issuer", "trust_root"):
        if auth["signature"][key] != ("ed25519" if key == "algorithm" else anchor[key]):
            raise ProvenanceError(f"authority_signature_{key}_anchor_mismatch")
    signed = auth["signed_receipt"]
    if not isinstance(signed, dict):
        raise ProvenanceError("authority_signed_receipt_not_object")
    _unknown(signed, SIGNED_KEYS, "authority_proof.signed_receipt")
    missing = SIGNED_KEYS - set(signed)
    if missing:
        raise MissingProvenanceError(f"missing_fields:authority_proof.signed_receipt:{','.join(sorted(missing))}")
    if any(signed[key] in (None, "") for key in {"signature", "algorithm", "key_id", "issuer", "trust_root", "verification_method", "profile", "expected_context_sha256", "public_key_b64", "signature_b64"}):
        raise MissingProvenanceError("empty_fields:authority_proof.signed_receipt")
    _str(signed["receipt_id"], "authority_proof.signed_receipt.receipt_id")
    _hash(signed["payload_sha256"], "authority_proof.signed_receipt.payload_sha256")
    for key in ("signature", "algorithm", "key_id", "issuer", "trust_root", "verification_method", "profile", "expected_context_sha256", "public_key_b64", "signature_b64"):
        _str(signed[key], f"authority_proof.signed_receipt.{key}")
    if signed["algorithm"] != "ed25519" or signed["profile"] != context["profile"] or signed["expected_context_sha256"] != context_hash:
        raise ProvenanceError("signed_receipt_context_or_profile_mismatch")
    for key in ("key_id", "issuer", "trust_root"):
        if signed[key] != anchor[key]:
            raise ProvenanceError(f"signed_receipt_{key}_anchor_mismatch")
    if signed["public_key_b64"] != anchor["public_key_b64"]:
        raise ProvenanceError("signed_receipt_public_key_anchor_mismatch")
    payload = signed["payload"]
    if not isinstance(payload, dict) or _hash(signed["payload_sha256"], "authority_proof.signed_receipt.payload_sha256") != canonical_sha256(payload):
        raise ProvenanceError("authority_payload_hash_mismatch")
    if payload.get("candidate_ref") != declaration["candidate_ref"] or payload.get("declaration_sha256") != declaration["declaration_sha256"] or payload.get("expected_context_sha256") != context_hash or payload.get("profile") != context["profile"] or payload.get("authenticated_closure") != declaration["authenticated_closure"] or payload.get("authenticated_closure_sha256") != canonical_sha256(declaration["authenticated_closure"]):
        raise ProvenanceError("authority_payload_binding_mismatch")
    if signed["signature"] != signed["signature_b64"]:
        raise ProvenanceError("opaque_signature_alias_mismatch:authority_proof.signed_receipt")
    _verify_ed25519(signed["public_key_b64"], signed["signature_b64"], payload, "authority_proof.signed_receipt")
    _str(auth["authority"], "authority_proof.authority")
    _utc(auth["verified_at_utc"], "authority_proof.verified_at_utc")
    _validate_envelope_signature(auth.get("outer_envelope"), signed, "authority_proof.outer_envelope", profile=context["profile"], expected_anchor=anchor)
    if (auth["outer_envelope"]["issuer"], auth["outer_envelope"]["trust_root"], auth["outer_envelope"]["key_id"], auth["outer_envelope"]["algorithm"]) != (signed["issuer"], signed["trust_root"], signed["key_id"], signed["algorithm"]):
        raise ProvenanceError("authority_chain_identity_mismatch")


def _validate_consistency(document: Mapping[str, Any]) -> None:
    """Ensure the declaration actually describes the observed closure."""
    declaration = document["reproducible_declaration"]
    lock_hashes = {item["name"]: item["sha256"].lower() for item in document["package_locks"]}
    runtime_hashes = {item["name"]: item["sha256"].lower() for item in document["runtimes"]}
    binary_hashes = {item["name"]: item["sha256"].lower() for item in document["binaries"]}
    recipe_hashes = {item["name"]: item["build_recipe"]["sha256"].lower() for item in document["binaries"]}
    for key, actual in (("lock_hashes", lock_hashes), ("runtime_hashes", runtime_hashes), ("binary_hashes", binary_hashes), ("recipe_hashes", recipe_hashes)):
        declared = {str(name): str(value).lower() for name, value in declaration[key].items()}
        if declared != actual:
            raise ProvenanceError(f"declaration_{key}_drift")
    if declaration["sbom_document_sha256"] != [document["sbom"]["document_sha256"]]:
        raise ProvenanceError("declaration_sbom_document_drift")
    refs = {component["bom_ref"] for component in document["sbom"]["components"]}
    covered_refs = {ref for binary in document["binaries"] for ref in binary["sbom_refs"]}
    if refs != covered_refs:
        raise ProvenanceError("sbom_orphan_or_uncovered_component")
    for index, binary in enumerate(document["binaries"]):
        if not set(binary["sbom_refs"]).issubset(refs):
            raise ProvenanceError(f"binary_sbom_reference_drift:binaries[{index}]")
        matched = [c for c in document["sbom"]["components"] if c["bom_ref"] in binary["sbom_refs"]]
        if len(matched) != 1:
            raise ProvenanceError(f"binary_sbom_coverage_invalid:binaries[{index}]")
        component = matched[0]
        if (component["name"].lower(), component["version"], component["sha256"].lower()) != (binary["name"].lower(), binary["version"], binary["sha256"].lower()):
            raise ProvenanceError(f"binary_sbom_identity_drift:binaries[{index}]")


@dataclass(frozen=True)
class ValidationResult:
    status: str
    decision: str
    checks: dict[str, str]
    errors: tuple[str, ...]
    input_sha256: str | None = None

    def as_dict(self) -> dict[str, Any]:
        return {
            "schema": "UP1.environment-provenance-validation-receipt.v1",
            "status": self.status,
            "decision": self.decision,
            "checks": self.checks,
            "errors": list(self.errors),
            "input_sha256": self.input_sha256,
        }


def validate_document(
    document: Mapping[str, Any],
    *,
    root: str | os.PathLike[str] | None = None,
    expected_context: Mapping[str, Any] | None = None,
    trust_anchor: Mapping[str, Any] | None = None,
    expected_context_sha256: str | None = None,
    trust_anchor_sha256: str | None = None,
) -> ValidationResult:
    """Validate a parsed closure, returning a non-throwing result.

    Structural defects and hash drift are fail-closed.  A correctly typed
    absence is accepted as ``typed_absent``; ``TEST_ONLY`` is always
    ``non_evidence`` even when every shape check passes.
    """
    checks: dict[str, str] = {}
    try:
        if not isinstance(document, dict):
            raise ProvenanceError("root_not_object")
        _unknown(document, REQUIRED_ROOT | OPTIONAL_ROOT, "root")
        _required(document, REQUIRED_ROOT, "root")
        if document["schema"] != "UP1.environment-provenance-closure.r2":
            raise ProvenanceError("schema_mismatch")
        if "expected_context" in document:
            raise ProvenanceError("bundle_expected_context_forbidden")
        role = document["fixture_role"]
        _str(role, "fixture_role")
        candidate = document["candidate_ref"]
        if candidate is not None:
            _str(candidate, "candidate_ref")
        root_path = Path(root) if root is not None else None
        signed = isinstance(document["authority_proof"], dict) and document["authority_proof"].get("status") == "signed_verified"
        # TEST_ONLY payloads exercise schema and linkage controls without
        # becoming host-bound evidence; they may therefore use synthetic
        # paths and do not require a filesystem root.
        path_bound = signed and role != "TEST_ONLY"
        context = None
        context_hash = None
        anchor = None
        anchor_hash = None
        if signed or role == "TEST_ONLY":
            if expected_context is None or expected_context_sha256 is None:
                raise MissingProvenanceError("expected_context_anchor_missing")
            if trust_anchor is None or trust_anchor_sha256 is None:
                raise MissingProvenanceError("trust_anchor_missing")
            context = expected_context
            context_hash = _validate_expected_context(context, document)
            if _hash(expected_context_sha256, "expected_context_sha256") != context_hash:
                raise ProvenanceError("expected_context_frozen_hash_mismatch")
            anchor = trust_anchor
            anchor_hash = _validate_trust_anchor(anchor, document)
            if _hash(trust_anchor_sha256, "trust_anchor_sha256") != anchor_hash:
                raise ProvenanceError("trust_anchor_frozen_hash_mismatch")
            checks["expected_context"] = "external_shape_and_frozen_hash_pass"
            checks["trust_anchor"] = "external_shape_and_frozen_hash_pass"
        _validate_os(document["local_observation"])
        checks["local_observation"] = "pass"
        runtimes = _validate_runtimes(document["runtimes"], root_path, signed=path_bound)
        _validate_runtime_paths(document["local_observation"]["runtime_paths"], list(runtimes.values()), signed=path_bound, root=root_path)
        checks["julia_python_runtime"] = "pass"
        _validate_locks(document["package_locks"], root_path, signed=path_bound)
        checks["project_manifest_locks"] = "pass"
        _validate_binaries(document["binaries"], root_path, signed=path_bound, strict_signatures=signed, expected_profile=context["profile"] if context is not None else None, expected_anchor=anchor)
        checks["binary_identity_and_hash"] = "pass"
        _validate_sbom(document["sbom"])
        checks["sbom_components_and_dependency_edges"] = "pass"
        declaration = document["reproducible_declaration"]
        if not isinstance(declaration, dict):
            raise ProvenanceError("declaration_not_object")
        authenticated_closure = _authenticated_closure(document)
        _validate_declaration(declaration, candidate, authenticated_closure)
        _validate_consistency(document)
        checks["reproducible_declaration"] = "pass"
        if context is not None:
            _validate_context_consistency(context, document)
            checks["expected_context"] = "pass"
        authority = document["authority_proof"]
        if not isinstance(authority, dict):
            raise ProvenanceError("authority_not_object")
        _validate_authority(authority, declaration, context, context_hash, anchor)
        checks["authority_proof"] = "pass"
        expected_status = NON_EVIDENCE if role == "TEST_ONLY" else (PRESENT if authority["status"] == "signed_verified" else TYPED_ABSENT)
        expected_decision = "non_evidence" if expected_status == NON_EVIDENCE else ("admissible" if expected_status == PRESENT else "typed_absence")
        if document["status"] != expected_status:
            raise ProvenanceError(f"root_status_mismatch:declared={document['status']}:derived={expected_status}")
        if document["claim_ceiling"] != "environment_provenance_only":
            raise ProvenanceError("claim_ceiling_uplift_or_mismatch")
        return ValidationResult(expected_status, expected_decision, checks, (), None)
    except MissingProvenanceError as exc:
        # A production claim without its project anchor or signature bytes is
        # explicitly unavailable.  A forged or contradictory envelope still
        # reaches the fail-closed branch below.  Root status remains derived:
        # a document claiming present while material is absent is itself
        # contradictory and is rejected.
        if role != "TEST_ONLY" and document.get("status") == TYPED_ABSENT and document.get("claim_ceiling") == "environment_provenance_only":
            return ValidationResult(TYPED_ABSENT, "typed_absence", checks, (f"missing_provenance:{exc}",), None)
        return ValidationResult(FAIL_CLOSED, "reject", checks, (f"invalid_document:{exc}",), None)
    except (ProvenanceError, KeyError, TypeError, AttributeError) as exc:
        # Keep the public validator total for hostile/foreign JSON.  A Python
        # implementation error must never turn malformed input into an
        # apparent acceptance or leak a traceback into a receipt.
        return ValidationResult(FAIL_CLOSED, "reject", checks, (f"invalid_document:{exc}",), None)


def observe_local_environment() -> dict[str, Any]:
    """Read-only host observation helper; no package probing or network calls."""
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    return {
        "os": {"name": platform.system(), "version": platform.version(), "architecture": platform.machine()},
        "architecture": platform.machine(),
        "runtime_paths": [],
        "observed_utc": now,
        "evidence_class": "local_observation",
    }
