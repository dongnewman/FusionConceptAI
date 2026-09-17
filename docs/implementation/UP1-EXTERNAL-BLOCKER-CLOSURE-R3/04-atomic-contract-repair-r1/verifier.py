"""Offline, deterministic UP1 R3 cross-field contract predicates.

This module is an additive contract artifact, not the production verifier.  It
performs no network, trust-store, AD/S3, Julia/DESC, solver, or credential
operation.  Signature and external security outcomes must be supplied by a
future pinned implementation and default to ``terminal_deferred`` here.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import pathlib
import sys
from collections import Counter
from typing import Any

ROOT = pathlib.Path(__file__).resolve().parent
ORDER = ["EHP-01", "EHP-02", "EHP-03", "EHP-04"]
EXCLUSIONS = ["signature", "signature_sha256", "owner_preimage_sha256", "set_signature", "set_preimage_sha256", "review_signature", "review_preimage_sha256", "bundle_canonical_sha256"]


def _jcs(value: Any) -> bytes:
    """Deterministic comparison bytes for JSON data (no wire aliases)."""
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def _iso(value: Any) -> dt.datetime | None:
    if not isinstance(value, str):
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _err(errors: list[dict[str, str]], code: str, path: str) -> None:
    errors.append({"code": code, "path": path})


def parse_raw(raw_utf8: bytes) -> tuple[Any | None, list[dict[str, str]]]:
    errors: list[dict[str, str]] = []
    try:
        text = raw_utf8.decode("utf-8", errors="strict")
    except UnicodeDecodeError:
        _err(errors, "RAW_INVALID_UTF8", "/")
        return None, errors

    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        out: dict[str, Any] = {}
        for key, value in items:
            if key in out:
                raise ValueError(f"duplicate key: {key}")
            out[key] = value
        return out

    try:
        value = json.loads(text, object_pairs_hook=pairs, parse_constant=lambda token: (_ for _ in ()).throw(ValueError(token)))
    except (json.JSONDecodeError, ValueError):
        _err(errors, "RAW_PREPARSE_REJECTED", "/")
        return None, errors
    return value, errors


def _schema_errors(bundle: dict[str, Any]) -> list[dict[str, str]]:
    try:
        from jsonschema import Draft202012Validator, RefResolver
    except ImportError:
        return [{"code": "SCHEMA_VALIDATOR_UNAVAILABLE", "path": "/"}]
    schema_path = ROOT / "bundle.schema.json"
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    resolver = RefResolver(base_uri=schema_path.as_uri(), referrer=schema)
    errors: list[dict[str, str]] = []
    for item in Draft202012Validator(schema, resolver=resolver).iter_errors(bundle):
        path = "/" + "/".join(str(p) for p in item.absolute_path)
        _err(errors, "SCHEMA_INVALID", path or "/")
    return errors


def _packet_digest(packet: dict[str, Any], digest: dict[str, Any]) -> None:
    return None


def cross_field_predicates(bundle: dict[str, Any], raw_sha256: str | None = None) -> list[dict[str, str]]:
    errors: list[dict[str, str]] = []
    if bundle.get("packet_order") != ORDER:
        _err(errors, "PACKET_ORDER_MISMATCH", "/packet_order")
    if bundle.get("canonical_exclusions") != EXCLUSIONS:
        _err(errors, "CANONICAL_EXCLUSION_NAME_INVALID", "/canonical_exclusions")

    packets = bundle.get("packets")
    digests = bundle.get("packet_digests")
    if isinstance(packets, list) and isinstance(digests, list) and len(packets) == len(digests) == 4:
        ids = [p.get("packet_id") if isinstance(p, dict) else None for p in packets]
        dids = [d.get("packet_id") if isinstance(d, dict) else None for d in digests]
        if ids != ORDER or dids != ORDER:
            _err(errors, "PACKET_ORDER_MISMATCH", "/packets")
        for i, (packet, digest) in enumerate(zip(packets, digests)):
            if not isinstance(packet, dict) or not isinstance(digest, dict):
                continue
            if packet.get("payload_sha256") != digest.get("payload_sha256"):
                _err(errors, "PACKET_PAYLOAD_DIGEST_MISMATCH", f"/packets/{i}/payload_sha256")
            if packet.get("signature", {}).get("signature_sha256") != digest.get("owner_signature_sha256"):
                _err(errors, "PACKET_SIGNATURE_DIGEST_MISMATCH", f"/packets/{i}/signature/signature_sha256")

    shared = bundle.get("shared_binding")
    receipt = bundle.get("set_receipt")
    if not isinstance(shared, dict):
        _err(errors, "SHARED_BINDING_MISSING", "/shared_binding")
    if not isinstance(receipt, dict):
        _err(errors, "SET_RECEIPT_MISSING", "/set_receipt")
    if isinstance(shared, dict) and isinstance(receipt, dict):
        if receipt.get("bundle_id") != bundle.get("bundle_id"):
            _err(errors, "SET_BUNDLE_ID_MISMATCH", "/set_receipt/bundle_id")
        if receipt.get("request_id") != bundle.get("request_id"):
            _err(errors, "SET_REQUEST_ID_MISMATCH", "/set_receipt/request_id")
        if _jcs(receipt.get("shared_binding")) != _jcs(shared):
            _err(errors, "SET_SHARED_BINDING_MISMATCH", "/set_receipt/shared_binding")
        if _jcs(receipt.get("packet_digests")) != _jcs(digests):
            _err(errors, "SET_PACKET_DIGESTS_MISMATCH", "/set_receipt/packet_digests")

    quarantine = receipt.get("quarantine_receipt") if isinstance(receipt, dict) else None
    required = ["raw_receipt_id", "raw_object_sha256", "raw_blob_sha256", "raw_size_bytes", "immutable_locator", "cas_transaction_id", "durable_commit_utc", "verification_started_utc", "decision_utc", "receiver_signature", "state", "receipt_sha256"]
    if not isinstance(quarantine, dict) or any(not quarantine.get(k) and quarantine.get(k) != 0 for k in required):
        _err(errors, "QUARANTINE_RECEIPT_INCOMPLETE", "/set_receipt/quarantine_receipt")
    else:
        if quarantine.get("state") != "quarantine_raw":
            _err(errors, "QUARANTINE_STATE_INVALID", "/set_receipt/quarantine_receipt/state")
        if not quarantine.get("receipt_sha256") or not quarantine.get("cas_transaction_id") or not receipt.get("decision"):
            _err(errors, "DECISION_NOT_BOUND_TO_QUARANTINE", "/set_receipt/decision")
        if raw_sha256 and quarantine.get("raw_object_sha256") != raw_sha256:
            _err(errors, "QUARANTINE_RAW_DIGEST_MISMATCH", "/set_receipt/quarantine_receipt/raw_object_sha256")
        commit, verify, decision = map(_iso, (quarantine.get("durable_commit_utc"), quarantine.get("verification_started_utc"), quarantine.get("decision_utc")))
        if not commit or not verify or not decision or not (commit <= verify <= decision):
            _err(errors, "QUARANTINE_NOT_BEFORE_VERIFY", "/set_receipt/quarantine_receipt")
        sig = quarantine.get("receiver_signature")
        if not isinstance(sig, dict) or not sig.get("signature_b64") or not sig.get("signature_sha256"):
            _err(errors, "QUARANTINE_RECEIVER_SIGNATURE_MISSING", "/set_receipt/quarantine_receipt/receiver_signature")

    if isinstance(packets, list) and len(packets) == 4 and isinstance(shared, dict):
        for i, packet in enumerate(packets):
            if isinstance(packet, dict) and _jcs(packet.get("shared_binding")) != _jcs(shared):
                _err(errors, "PACKET_SHARED_BINDING_MISMATCH", f"/packets/{i}/shared_binding")

        p03 = packets[2].get("payload") if isinstance(packets[2], dict) else None
        _check_ehp03(p03, shared, errors)
        p04 = packets[3].get("payload") if isinstance(packets[3], dict) else None
        _check_ehp04(p04, shared, errors)
    return errors


def _check_ehp03(payload: Any, shared: dict[str, Any], errors: list[dict[str, str]]) -> None:
    if not isinstance(payload, dict):
        return
    candidate = shared.get("candidate_id")
    source_digest = shared.get("source_identity_sha256")
    source = payload.get("source_identity", {})
    if source.get("candidate_id") != candidate or payload.get("g2_mapping", {}).get("candidate_id") != candidate or payload.get("authority_receipt", {}).get("candidate_id") != candidate:
        _err(errors, "EHP03_CANDIDATE_BINDING_MISMATCH", "/packets/2/payload")
    authority = payload.get("authority_receipt", {})
    if authority.get("source_identity_sha256") != source_digest and source_digest:
        _err(errors, "EHP03_SOURCE_BINDING_MISMATCH", "/packets/2/payload/source_identity")
    for name in ("forward_edges", "reverse_edges"):
        for j, edge in enumerate(payload.get("evidence_graph", {}).get(name, [])):
            if edge.get("candidate_id") != candidate or edge.get("source_identity_sha256") != source_digest:
                _err(errors, "EHP03_SOURCE_BINDING_MISMATCH", f"/packets/2/payload/evidence_graph/{name}/{j}")
    axes = payload.get("axis_materials", [])
    expected_axes = {x.get("axis_id") for x in shared.get("four_axis_refs", []) if isinstance(x, dict)}
    actual_axes = {x.get("axis_id") for x in axes if isinstance(x, dict)}
    if len(axes) != 4 or actual_axes != expected_axes or len(actual_axes) != 4:
        _err(errors, "EHP03_AXIS_SET_MISMATCH", "/packets/2/payload/axis_materials")
    graph = payload.get("evidence_graph", {})
    fwd = graph.get("forward_edges", [])
    rev = graph.get("reverse_edges", [])
    def edge_key(e: dict[str, Any]) -> tuple[Any, ...]:
        return (e.get("from_kind"), e.get("from_id"), e.get("to_kind"), e.get("to_id"), e.get("candidate_id"), e.get("source_identity_sha256"), e.get("namespace"), e.get("version"))
    if Counter(edge_key(e) for e in fwd if isinstance(e, dict)) != Counter(edge_key(e) for e in rev if isinstance(e, dict)):
        _err(errors, "EHP03_GRAPH_BIJECTION_FAILURE", "/packets/2/payload/evidence_graph")
    mapping = payload.get("g2_mapping", {})
    if mapping.get("ambiguity_decision") != "none" or not mapping.get("mapping_rows") or not mapping.get("reverse_rows"):
        _err(errors, "EHP03_G2_MAPPING_MISMATCH", "/packets/2/payload/g2_mapping")


def _check_ehp04(payload: Any, shared: dict[str, Any], errors: list[dict[str, str]]) -> None:
    if not isinstance(payload, dict):
        return
    if payload.get("expected_context_sha256") != shared.get("expected_context_sha256"):
        _err(errors, "EHP04_CONTEXT_BINDING_MISMATCH", "/packets/3/payload/expected_context_sha256")
    outer = payload.get("outer_authority", {})
    if outer.get("candidate_id") != shared.get("candidate_id") or outer.get("source_identity_sha256") != shared.get("source_identity_sha256") or outer.get("expected_context_sha256") != shared.get("expected_context_sha256"):
        _err(errors, "EHP04_CONTEXT_BINDING_MISMATCH", "/packets/3/payload/outer_authority")
    runtimes = payload.get("runtime_and_imports", {}).get("runtimes", [])
    if len(runtimes) != 2 or {r.get("name") for r in runtimes if isinstance(r, dict)} != {"Julia", "Python"}:
        _err(errors, "EHP04_RUNTIME_SET_MISMATCH", "/packets/3/payload/runtime_and_imports/runtimes")
    ri = payload.get("runtime_and_imports", {})
    for field in ("imports", "lockfiles"):
        items = ri.get(field, [])
        keys = [(x.get("name"), x.get("version"), x.get("locator"), x.get("sha256")) for x in items if isinstance(x, dict)]
        if len(keys) != len(set(keys)):
            _err(errors, "EHP04_IDENTITY_MAP_DUPLICATE", f"/packets/3/payload/runtime_and_imports/{field}")
    for i, sbom in enumerate(payload.get("sbom_documents", [])):
        if not isinstance(sbom, dict):
            continue
        ids = [c.get("component_id") for c in sbom.get("components", []) if isinstance(c, dict)]
        if len(ids) != len(set(ids)):
            _err(errors, "EHP04_SBOM_COMPONENT_DUPLICATE", f"/packets/3/payload/sbom_documents/{i}/components")
        known = set(ids)
        for j, edge in enumerate(sbom.get("dependency_edges", [])):
            if edge.get("from_component_id") not in known or edge.get("to_component_id") not in known:
                _err(errors, "EHP04_SBOM_EDGE_ENDPOINT_MISSING", f"/packets/3/payload/sbom_documents/{i}/dependency_edges/{j}")
    for i, binary in enumerate(payload.get("binaries", [])):
        if binary.get("candidate_id") != shared.get("candidate_id") or binary.get("download_receipt", {}).get("subject_sha256") != binary.get("sha256"):
            _err(errors, "EHP04_BINARY_BINDING_MISMATCH", f"/packets/3/payload/binaries/{i}")
    fixture = payload.get("foreign_owner_fixture", {})
    if fixture.get("fixture_status") not in ("executed", "not_executed"):
        _err(errors, "EHP04_FIXTURE_DECISION_MISMATCH", "/packets/3/payload/foreign_owner_fixture")


def validate_bundle(raw_utf8: bytes, context: dict[str, Any] | None = None) -> dict[str, Any]:
    context = context or {}
    raw_digest = hashlib.sha256(raw_utf8).hexdigest()
    value, errors = parse_raw(raw_utf8)
    if value is None or not isinstance(value, dict):
        return {"schema_ok": False, "raw_sha256": raw_digest, "decision": "rejected_all", "failure_codes": sorted({e["code"] for e in errors}), "formal_credit": "none"}
    schema_errors = _schema_errors(value)
    errors.extend(schema_errors)
    errors.extend(cross_field_predicates(value, raw_digest))
    fixture = value.get("packets", [{}, {}, {}, {"payload": {}}])[3].get("payload", {}).get("foreign_owner_fixture", {}).get("fixture_status") if isinstance(value.get("packets"), list) and len(value.get("packets", [])) == 4 else None
    if fixture == "not_executed":
        decision = "terminal_deferred"
    elif errors:
        decision = "rejected_all"
    elif context.get("security_ok") is True:
        decision = "accepted_all"
    else:
        decision = "terminal_deferred"
    return {"schema_ok": not bool(schema_errors), "raw_sha256": raw_digest, "bundle_canonical_sha256": value.get("bundle_canonical_sha256"), "completeness": not bool(errors), "fixture_status": fixture, "decision": decision, "failure_codes": sorted({e["code"] for e in errors}), "formal_credit": "none"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        cases = [(b'{"a":1,"a":2}', "RAW_PREPARSE_REJECTED"), (b"{\"x\":NaN}", "RAW_PREPARSE_REJECTED"), (b"\xff", "RAW_INVALID_UTF8")]
        got = []
        for raw, code in cases:
            result = validate_bundle(raw)
            got.append({"expected": code, "observed": result["failure_codes"], "pass": code in result["failure_codes"]})
        print(json.dumps({"schema":"UP1.atomic-contract-repair.self-test.r1","cases":got,"pass":all(x["pass"] for x in got)}, sort_keys=True, separators=(",", ":")))
        return 0 if all(x["pass"] for x in got) else 1
    print("use --self-test")
    return 2


if __name__ == "__main__":
    sys.exit(main())
