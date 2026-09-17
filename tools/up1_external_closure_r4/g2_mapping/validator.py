"""Strict, independent verification of an external G2 mapping.

This is deliberately a structural verifier, not an authority verifier.  It
accepts the R3 EHP-03 payload shape and a small standalone R4 shape, then
recomputes row, mapping, graph and source identities.  All relations are
checked in both directions.  A structurally complete payload still remains
``terminal_deferred`` because this component cannot establish an external
issuer, signature, trust root, trusted time, or revocation authority.

The implementation is dependency-free and keeps its own canonicalisation
code so that passing this prototype is not a copied R3 authority conclusion.
"""
from __future__ import annotations

import hashlib
import json
import math
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterable


SCHEMA = "UP1.g2-independent-mapping-r4.v1"
R3_SCHEMA = "UP1.external-handoff.ehp-03-response.v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
URI = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*://[^\s]+$")
EDGE_KINDS = {"source", "candidate", "axis", "evidence", "g2"}


class MappingError(ValueError):
    """Deterministic validation error; callers must fail closed."""


ProfileError = MappingError


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise MappingError(f"duplicate_key:{key}")
        result[key] = value
    return result


def _constant(token: str) -> Any:
    raise MappingError(f"nonfinite_number:{token}")


def load_text(text: str) -> Any:
    if not isinstance(text, str):
        raise MappingError("json_text_required")
    try:
        text.encode("utf-8", "strict")
        return json.loads(text, object_pairs_hook=_pairs, parse_constant=_constant)
    except MappingError:
        raise
    except Exception as exc:
        raise MappingError(f"invalid_json:{exc}") from exc


def load_path(path: Path) -> Any:
    try:
        return load_text(path.read_text(encoding="utf-8"))
    except MappingError:
        raise
    except OSError as exc:
        raise MappingError(f"read_error:{exc}") from exc


def _check_value(value: Any, path: str = "$") -> None:
    """Reject values that this small canonicaliser cannot represent safely."""
    if value is None or type(value) is bool or type(value) is str:
        return
    if type(value) is int:
        if abs(value) > 9007199254740991:
            raise MappingError(f"{path}:unsafe_integer")
        return
    if type(value) is float:
        if not math.isfinite(value) or value == 0.0 and math.copysign(1.0, value) < 0:
            raise MappingError(f"{path}:noncanonical_number")
        # Avoid silently claiming RFC 8785 support in the dependency-free
        # prototype.  Inputs used by the mapping contract are integral/text.
        raise MappingError(f"{path}:float_unsupported")
    if isinstance(value, dict):
        for key, item in value.items():
            if type(key) is not str:
                raise MappingError(f"{path}:string_keys_required")
            _check_value(item, f"{path}.{key}")
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            _check_value(item, f"{path}[{index}]")
        return
    raise MappingError(f"{path}:unsupported_value")


def canonical_bytes(value: Any) -> bytes:
    """Return deterministic JSON bytes used by every R4 identity digest."""
    _check_value(value)
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def digest(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def _obj(value: Any, allowed: Iterable[str], path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise MappingError(f"{path}:object_required")
    unknown = set(value) - set(allowed)
    if unknown:
        raise MappingError(f"{path}:unknown_fields:{','.join(sorted(unknown))}")
    return value


def _req(value: dict[str, Any], key: str, path: str) -> Any:
    if key not in value:
        raise MappingError(f"{path}:missing:{key}")
    return value[key]


def _text(value: Any, path: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise MappingError(f"{path}:nonempty_string_required")
    return value


def _sha(value: Any, path: str) -> str:
    value = _text(value, path)
    if not SHA256.fullmatch(value):
        raise MappingError(f"{path}:lowercase_sha256_required")
    return value


def _ref(value: Any, path: str) -> dict[str, str]:
    item = _obj(value, {"ref", "sha256"}, path)
    ref = _text(_req(item, "ref", path), f"{path}.ref")
    # R3 permits opaque references.  URI validation is applied only to the
    # standalone R4 node refs, preserving R3 compatibility.
    _sha(_req(item, "sha256", path), f"{path}.sha256")
    return {"ref": ref, "sha256": item["sha256"]}


def _time(value: Any, path: str) -> str:
    value = _text(value, path)
    # Reject naive times while accepting the ISO forms used by R3 fixtures.
    if not (value.endswith("Z") or re.search(r"[+-][0-9]{2}:[0-9]{2}$", value)):
        raise MappingError(f"{path}:timezone_required")
    return value


def _same(a: Any, b: Any, path: str) -> None:
    if a != b:
        raise MappingError(f"{path}:mismatch")


def _alias(value: dict[str, Any], canonical: str, alternate: str, path: str) -> Any:
    """Resolve a compatibility alias without accepting contradictory values."""
    has_canonical = canonical in value
    has_alternate = alternate in value
    if has_canonical and has_alternate and value[canonical] != value[alternate]:
        raise MappingError(f"{path}:conflicting_aliases:{canonical}/{alternate}")
    if has_canonical:
        return value[canonical]
    if has_alternate:
        return value[alternate]
    return None


def _source_identity(source: Any, expected_candidate: str | None = None) -> tuple[dict[str, Any], str]:
    if not isinstance(source, dict):
        raise MappingError("source_identity:object_required")
    candidate = _text(source.get("candidate_id"), "source_identity.candidate_id")
    if expected_candidate is not None and candidate != expected_candidate:
        raise MappingError("source_identity.candidate_id:mismatch")
    # R3 has a source record without its own digest.  R4 allows an explicit
    # digest field but computes it over the record excluding that self-field.
    supplied = source.get("source_identity_sha256")
    body = {key: value for key, value in source.items() if key != "source_identity_sha256"}
    computed = digest(body)
    if supplied is not None and _sha(supplied, "source_identity.source_identity_sha256") != computed:
        raise MappingError("source_identity:recomputed_hash_mismatch")
    return source, computed


def _edge(value: Any, path: str, candidate: str, source_sha: str, authority_sig: dict[str, str]) -> dict[str, Any]:
    allowed = {"edge_id", "from_kind", "from_id", "to_kind", "to_id", "candidate_id", "source_identity_sha256", "namespace", "version", "edge_sha256", "issuer_ref", "issued_at", "signature_ref"}
    edge = _obj(value, allowed, path)
    for key in ("edge_id", "from_id", "to_id", "namespace", "version"):
        _text(_req(edge, key, path), f"{path}.{key}")
    for key in ("from_kind", "to_kind"):
        kind = _text(_req(edge, key, path), f"{path}.{key}")
        if kind not in EDGE_KINDS:
            raise MappingError(f"{path}.{key}:unknown_kind")
    _same(_req(edge, "candidate_id", path), candidate, f"{path}.candidate_id")
    _same(_sha(_req(edge, "source_identity_sha256", path), f"{path}.source_identity_sha256"), source_sha, f"{path}.source_identity_sha256")
    issuer = _ref(_req(edge, "issuer_ref", path), f"{path}.issuer_ref")
    signature = _ref(_req(edge, "signature_ref", path), f"{path}.signature_ref")
    _same(issuer, authority_sig, f"{path}.issuer_ref")
    _same(signature, authority_sig, f"{path}.signature_ref")
    _time(_req(edge, "issued_at", path), f"{path}.issued_at")
    supplied = _sha(_req(edge, "edge_sha256", path), f"{path}.edge_sha256")
    if supplied != digest({key: val for key, val in edge.items() if key != "edge_sha256"}):
        raise MappingError(f"{path}.edge_sha256:recomputed_hash_mismatch")
    return edge


def _row(value: Any, path: str, authority_sig: dict[str, str], candidate: str | None = None, source_sha: str | None = None) -> dict[str, Any]:
    allowed = {"row_id", "from_id", "to_id", "row_sha256", "issuer_ref", "issued_at", "candidate_id", "source_identity_sha256"}
    row = _obj(value, allowed, path)
    for key in ("row_id", "from_id", "to_id"):
        _text(_req(row, key, path), f"{path}.{key}")
    issuer = _ref(_req(row, "issuer_ref", path), f"{path}.issuer_ref")
    _same(issuer, authority_sig, f"{path}.issuer_ref")
    _time(_req(row, "issued_at", path), f"{path}.issued_at")
    if "candidate_id" in row:
        _same(_text(row["candidate_id"], f"{path}.candidate_id"), candidate, f"{path}.candidate_id")
    if "source_identity_sha256" in row:
        _same(_sha(row["source_identity_sha256"], f"{path}.source_identity_sha256"), source_sha, f"{path}.source_identity_sha256")
    supplied = _sha(_req(row, "row_sha256", path), f"{path}.row_sha256")
    if supplied != digest({key: val for key, val in row.items() if key != "row_sha256"}):
        raise MappingError(f"{path}.row_sha256:recomputed_hash_mismatch")
    return row


def _pair_identity(item: dict[str, Any]) -> tuple[Any, ...]:
    return (item["from_kind"], item["from_id"], item["to_kind"], item["to_id"], item["candidate_id"], item["source_identity_sha256"], item["namespace"], item["version"], item["issued_at"], item["issuer_ref"]["ref"], item["issuer_ref"]["sha256"], item["signature_ref"]["ref"], item["signature_ref"]["sha256"])


def _graph_endpoint_identity(item: dict[str, Any]) -> tuple[str, str, str, str]:
    """Return an endpoint identity independent of issuance timestamp."""
    return (item["from_kind"], item["from_id"], item["to_kind"], item["to_id"])


def _row_identity(item: dict[str, Any]) -> tuple[Any, ...]:
    return (item["row_id"], item["from_id"], item["to_id"], item["issuer_ref"]["ref"], item["issuer_ref"]["sha256"], item["issued_at"])


def _check_graph(graph: Any, candidate: str, source_sha: str, authority_sig: dict[str, str], authority_graph_sha: str) -> dict[str, Any]:
    graph = _obj(graph, {"graph_id", "forward_edges", "reverse_edges", "graph_sha256", "coverage"}, "evidence_graph")
    forward_raw = _req(graph, "forward_edges", "evidence_graph")
    reverse_raw = _req(graph, "reverse_edges", "evidence_graph")
    if not isinstance(forward_raw, list) or not forward_raw or not isinstance(reverse_raw, list) or not reverse_raw:
        raise MappingError("evidence_graph:both_nonempty_edge_lists_required")
    if "graph_id" in graph:
        _text(graph["graph_id"], "evidence_graph.graph_id")
    forward = [_edge(item, f"evidence_graph.forward_edges[{i}]", candidate, source_sha, authority_sig) for i, item in enumerate(forward_raw)]
    reverse = [_edge(item, f"evidence_graph.reverse_edges[{i}]", candidate, source_sha, authority_sig) for i, item in enumerate(reverse_raw)]
    f_ids = [item["edge_id"] for item in forward]
    r_ids = [item["edge_id"] for item in reverse]
    if len(f_ids) != len(set(f_ids)) or len(r_ids) != len(set(r_ids)):
        raise MappingError("evidence_graph:duplicate_edge_id")
    f_pairs = [_pair_identity(item) for item in forward]
    r_pairs = [_pair_identity(item) for item in reverse]
    f_endpoints = [_graph_endpoint_identity(item) for item in forward]
    r_endpoints = [_graph_endpoint_identity(item) for item in reverse]
    if len(f_endpoints) != len(set(f_endpoints)) or len(r_endpoints) != len(set(r_endpoints)):
        raise MappingError("evidence_graph:duplicate_endpoint_pair")
    inverse = [(*p[2:4], *p[0:2], *p[4:]) for p in f_pairs]
    # The tuple layout above is intentionally explicit: compare all authority,
    # candidate, source, namespace, version and time fields, not only endpoints.
    if Counter(inverse) != Counter(r_pairs):
        raise MappingError("evidence_graph:bijection_failure")
    if not any(candidate in (edge["from_id"], edge["to_id"]) for edge in forward + reverse):
        raise MappingError("evidence_graph:candidate_endpoint_uncovered")
    supplied = _sha(_req(graph, "graph_sha256", "evidence_graph"), "evidence_graph.graph_sha256")
    if supplied != digest({key: val for key, val in graph.items() if key != "graph_sha256"}):
        raise MappingError("evidence_graph.graph_sha256:recomputed_hash_mismatch")
    _same(supplied, authority_graph_sha, "authority_receipt.graph_sha256")
    if "coverage" in graph:
        coverage = _obj(graph["coverage"], {"forward_edges", "reverse_edges", "unique_forward_pairs", "unique_reverse_pairs"}, "evidence_graph.coverage")
        expected = {"forward_edges": len(forward), "reverse_edges": len(reverse), "unique_forward_pairs": len(set(f_endpoints)), "unique_reverse_pairs": len(set(r_endpoints))}
        for key, value in expected.items():
            if key in coverage and coverage[key] != value:
                raise MappingError(f"evidence_graph.coverage.{key}:mismatch")
    return {"graph_sha256": supplied, "forward_count": len(forward), "reverse_count": len(reverse)}


def _check_mapping(mapping: Any, candidate: str, authority_sig: dict[str, str], source_sha: str | None = None) -> dict[str, Any]:
    mapping = _obj(mapping, {"namespace", "version", "effective_interval", "candidate_id", "mapping_rows", "reverse_rows", "mapping_sha256", "issuer_ref", "ambiguity_decision", "mapping_id", "coverage"}, "g2_mapping")
    _text(_req(mapping, "namespace", "g2_mapping"), "g2_mapping.namespace")
    _text(_req(mapping, "version", "g2_mapping"), "g2_mapping.version")
    interval = _obj(_req(mapping, "effective_interval", "g2_mapping"), {"not_before", "not_after"}, "g2_mapping.effective_interval")
    _time(_req(interval, "not_before", "g2_mapping.effective_interval"), "g2_mapping.effective_interval.not_before")
    _time(_req(interval, "not_after", "g2_mapping.effective_interval"), "g2_mapping.effective_interval.not_after")
    _same(_req(mapping, "candidate_id", "g2_mapping"), candidate, "g2_mapping.candidate_id")
    if _req(mapping, "ambiguity_decision", "g2_mapping") != "none":
        raise MappingError("g2_mapping:ambiguity_or_conflict")
    issuer = _ref(_req(mapping, "issuer_ref", "g2_mapping"), "g2_mapping.issuer_ref")
    _same(issuer, authority_sig, "g2_mapping.issuer_ref")
    f_raw = _req(mapping, "mapping_rows", "g2_mapping")
    r_raw = _req(mapping, "reverse_rows", "g2_mapping")
    if not isinstance(f_raw, list) or not f_raw or not isinstance(r_raw, list) or not r_raw:
        raise MappingError("g2_mapping:both_nonempty_row_lists_required")
    forward = [_row(item, f"g2_mapping.mapping_rows[{i}]", authority_sig, candidate, source_sha) for i, item in enumerate(f_raw)]
    reverse = [_row(item, f"g2_mapping.reverse_rows[{i}]", authority_sig, candidate, source_sha) for i, item in enumerate(r_raw)]
    f_ids = [_row_identity(item)[0] for item in forward]
    r_ids = [_row_identity(item)[0] for item in reverse]
    if len(f_ids) != len(set(f_ids)) or len(r_ids) != len(set(r_ids)):
        raise MappingError("g2_mapping:duplicate_row_id")
    f_pairs = [(item["from_id"], item["to_id"], item["issued_at"], item["issuer_ref"]["ref"], item["issuer_ref"]["sha256"]) for item in forward]
    r_pairs = [(item["to_id"], item["from_id"], item["issued_at"], item["issuer_ref"]["ref"], item["issuer_ref"]["sha256"]) for item in reverse]
    f_endpoints = [(item["from_id"], item["to_id"]) for item in forward]
    r_endpoints = [(item["to_id"], item["from_id"]) for item in reverse]
    if len(f_endpoints) != len(set(f_endpoints)) or len(r_endpoints) != len(set(r_endpoints)):
        raise MappingError("g2_mapping:duplicate_endpoint_pair")
    f_relation = [(item["from_id"], item["to_id"], item["row_id"], item["issued_at"], item["issuer_ref"]["ref"], item["issuer_ref"]["sha256"]) for item in forward]
    r_relation = [(item["to_id"], item["from_id"], item["row_id"], item["issued_at"], item["issuer_ref"]["ref"], item["issuer_ref"]["sha256"]) for item in reverse]
    if Counter(f_relation) != Counter(r_relation):
        raise MappingError("g2_mapping:bijection_failure")
    supplied = _sha(_req(mapping, "mapping_sha256", "g2_mapping"), "g2_mapping.mapping_sha256")
    if supplied != digest({key: val for key, val in mapping.items() if key != "mapping_sha256"}):
        raise MappingError("g2_mapping.mapping_sha256:recomputed_hash_mismatch")
    if "mapping_id" in mapping:
        _text(mapping["mapping_id"], "g2_mapping.mapping_id")
    if "coverage" in mapping:
        coverage = _obj(mapping["coverage"], {"forward_rows", "reverse_rows", "unique_forward_pairs", "unique_reverse_pairs"}, "g2_mapping.coverage")
        expected = {"forward_rows": len(forward), "reverse_rows": len(reverse), "unique_forward_pairs": len(set(f_endpoints)), "unique_reverse_pairs": len(set(r_endpoints))}
        for key, value in expected.items():
            if key in coverage and coverage[key] != value:
                raise MappingError(f"g2_mapping.coverage.{key}:mismatch")
    return {"mapping_sha256": supplied, "forward_count": len(forward), "reverse_count": len(reverse)}


def _check_authority(authority: Any, candidate: str, source_sha: str) -> tuple[dict[str, Any], dict[str, str], str]:
    allowed = {"receipt_id", "candidate_id", "source_identity_sha256", "graph_sha256", "trusted_time_ref", "revocation_ref", "signature_ref", "issuer_ref", "external_verification"}
    authority = _obj(authority, allowed, "authority_receipt")
    _text(_req(authority, "receipt_id", "authority_receipt"), "authority_receipt.receipt_id")
    _same(_req(authority, "candidate_id", "authority_receipt"), candidate, "authority_receipt.candidate_id")
    _same(_sha(_req(authority, "source_identity_sha256", "authority_receipt"), "authority_receipt.source_identity_sha256"), source_sha, "authority_receipt.source_identity_sha256")
    graph_sha = _sha(_req(authority, "graph_sha256", "authority_receipt"), "authority_receipt.graph_sha256")
    for key in ("trusted_time_ref", "revocation_ref", "signature_ref"):
        _ref(_req(authority, key, "authority_receipt"), f"authority_receipt.{key}")
    signature = _ref(authority["signature_ref"], "authority_receipt.signature_ref")
    if "issuer_ref" in authority:
        _same(_ref(authority["issuer_ref"], "authority_receipt.issuer_ref"), signature, "authority_receipt.issuer_ref")
    if "external_verification" in authority and authority["external_verification"] is not False:
        raise MappingError("authority_receipt.external_verification:must_be_false_or_absent")
    return authority, signature, graph_sha


def _normalise(value: Any) -> tuple[str, Any, Any, Any, Any, str]:
    if not isinstance(value, dict):
        raise MappingError("profile:object_required")
    status = value.get("status", "present")
    if not isinstance(status, str) or status not in {"present", "typed_absent", "terminal_deferred"}:
        raise MappingError("profile.status:unknown_status")
    if status in {"typed_absent", "terminal_deferred"}:
        schema = _text(value.get("schema", SCHEMA), "profile.schema")
        allowed = {"schema", "status", "reason", "mapping", "g2_mapping", "authority", "authority_receipt", "no_publish", "formal_credit", "resolution"}
        _obj(value, allowed, "profile")
        mapping = _alias(value, "g2_mapping", "mapping", "profile.mapping")
        authority = _alias(value, "authority_receipt", "authority", "profile.authority")
        if mapping is not None or authority is not None:
            raise MappingError("profile.absence:values_must_be_null")
        if value.get("no_publish", True) is not True or value.get("formal_credit", "none") != "none":
            raise MappingError("profile.absence:publication_fields_mismatch")
        return status, None, None, None, None, schema
    allowed = {"schema", "status", "candidate_id", "source_identity", "source_identity_sha256", "evidence_graph", "graph", "g2_mapping", "mapping", "authority_receipt", "authority", "fixture_role", "production_present_admission", "no_publish", "formal_credit"}
    _obj(value, allowed, "profile")
    schema = _text(value.get("schema", R3_SCHEMA), "profile.schema")
    candidate = value.get("candidate_id")
    source = value.get("source_identity")
    graph = value.get("evidence_graph", value.get("graph"))
    mapping = _alias(value, "g2_mapping", "mapping", "profile.mapping")
    authority = _alias(value, "authority_receipt", "authority", "profile.authority")
    if any(item is None for item in (source, graph, mapping, authority)):
        raise MappingError("profile:missing_source_graph_mapping_or_authority")
    if value.get("no_publish", True) is not True or value.get("formal_credit", "none") != "none":
        raise MappingError("profile:publication_fields_mismatch")
    return "present", source, graph, mapping, authority, schema


def validate_mapping(value: Any) -> dict[str, Any]:
    status, source, graph, mapping, authority, schema = _normalise(value)
    if status in {"typed_absent", "terminal_deferred"}:
        return {"schema": schema, "status": status, "structural_valid": True, "no_publish": True, "formal_credit": "none"}
    candidate = _text(value.get("candidate_id", mapping.get("candidate_id")), "profile.candidate_id")
    source_record, source_sha = _source_identity(source, candidate)
    if "source_identity_sha256" in value:
        _same(_sha(value["source_identity_sha256"], "profile.source_identity_sha256"), source_sha, "profile.source_identity_sha256")
    authority_record, authority_sig, graph_sha = _check_authority(authority, candidate, source_sha)
    graph_result = _check_graph(graph, candidate, source_sha, authority_sig, graph_sha)
    mapping_result = _check_mapping(mapping, candidate, authority_sig, source_sha)
    return {"schema": schema, "status": status, "structural_valid": True, "candidate_id": candidate, "source_identity_sha256": source_sha, "graph": graph_result, "mapping": mapping_result, "authority_receipt_id": authority_record["receipt_id"], "authority_verified": False, "no_publish": True, "formal_credit": "none"}


validate_profile = validate_mapping
validate = validate_mapping


def evaluate(value: Any) -> dict[str, Any]:
    try:
        result = validate_mapping(value)
    except Exception as exc:
        return {"accepted": False, "decision": "fail_closed", "resolution": "fail_closed", "production_admissible": False, "authority_verified": False, "no_publish": True, "formal_credit": "none", "error": str(exc)}
    if result["status"] == "typed_absent":
        return {"accepted": True, "decision": "typed_absence", "resolution": "terminal_deferred", "production_admissible": False, "authority_verified": False, "no_publish": True, "formal_credit": "none", "reason": "external_authority_not_supplied"}
    if result["status"] == "terminal_deferred":
        return {"accepted": True, "decision": "terminal_deferred", "resolution": "terminal_deferred", "production_admissible": False, "authority_verified": False, "no_publish": True, "formal_credit": "none", "reason": "external_authority_not_verified"}
    return {"accepted": False, "decision": "terminal_deferred", "resolution": "terminal_deferred", "production_admissible": False, "authority_verified": False, "no_publish": True, "formal_credit": "none", "reason": "structural_mapping_valid_but_external_authority_unverified", "details": result}


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(json.dumps({"accepted": False, "decision": "usage", "usage": "validate_g2_mapping.py PROFILE.json"}, separators=(",", ":")))
        return 2
    try:
        result = evaluate(load_path(Path(argv[1])))
    except Exception as exc:  # defensive: CLI itself must also fail closed
        result = {"accepted": False, "decision": "fail_closed", "resolution": "fail_closed", "production_admissible": False, "authority_verified": False, "no_publish": True, "formal_credit": "none", "error": str(exc)}
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return 0 if result.get("accepted") is True else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
