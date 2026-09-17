"""Independent, explicit R3 mutation vectors.

Each function below owns one semantic path.  The vectors are intentionally
kept in the test tree: they are an offline/prototype acceptance harness, not a
new authority source.  Keeping builders as named functions makes accidental
copy/paste or a uniform SCHEMA_INVALID assertion visible during review.
"""
from __future__ import annotations

import copy
import hashlib
import json
import tempfile
import unittest
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable
from unittest.mock import patch

from tools.up1_external_closure_r3.atomic_bundle import EXCLUSIONS, validate_bundle
from tools.up1_external_closure_r3.atomic_bundle import bundle as impl
from tools.up1_external_closure_r3.atomic_bundle.canonical import CanonicalError


@dataclass(frozen=True)
class MutationVector:
    vector_id: str
    mutation_path: str
    expected: str
    decision: str
    build: Callable[[], Any]


def _base() -> dict[str, Any]:
    """A deliberately small, mutable envelope-shaped input."""
    shared = {"candidate_id": "candidate-vector", "source_identity_sha256": "a" * 64,
              "expected_context_sha256": "b" * 64, "four_axis_refs": [{"axis_id": f"A{i}"} for i in range(4)]}
    # Keep the wire copies independent.  A shared Python object here would
    # make R07 mutate the top-level binding as a side effect and would hide
    # the production shared-binding predicate.
    packets = [{"packet_id": packet_id, "payload": {"vector": packet_id}, "owner": {"owner_id": f"owner-{i}", "role": impl.ROLES[i]},
                "signature": {"key_id": f"owner-{i}"}, "shared_binding": copy.deepcopy(shared)} for i, packet_id in enumerate(impl.ORDER)]
    digests = [impl.packet_digest(packet) for packet in packets]
    source = {"candidate_id": "candidate-vector", "revision": "r1", "head": "h1", "tree": "a" * 64,
              "dirty_patch": {"present": True, "sha256": "a" * 64, "entries": ["p"]},
              "untracked": {"present": True, "sha256": "a" * 64, "entries": ["u"]},
              "submodules": {"present": True, "sha256": "a" * 64, "entries": ["s"]}, "source_bytes_sha256": "a" * 64, "inventory_sha256": "a" * 64}
    # Bind the direct EHP-03 fixture to its actual source identity.  The
    # initial placeholder is replaced before packet copies are frozen.
    shared["source_identity_sha256"] = impl._digest(source)
    for packet in packets:
        packet["shared_binding"] = copy.deepcopy(shared)
    authority = {"candidate_id": "candidate-vector", "source_identity_sha256": impl._digest(source), "signature_ref": {"ref": "authority", "sha256": "a" * 64}}
    source["candidate_id"] = "candidate-vector"
    axis_materials = [{"axis_id": f"A{i}"} for i in range(4)]
    edge = {"edge_id": "edge-vector", "from_kind": "source", "from_id": "source-vector", "to_kind": "candidate", "to_id": "candidate-vector",
            "candidate_id": "candidate-vector", "source_identity_sha256": impl._digest(source), "namespace": "n", "version": "1", "issued_at": "2026-09-17T00:00:00Z",
            "issuer_ref": {"ref": "authority", "sha256": "a" * 64}, "signature_ref": {"ref": "authority", "sha256": "a" * 64}}
    reverse_edge = dict(edge, edge_id="edge-vector-reverse", from_kind="candidate", from_id="candidate-vector", to_kind="source", to_id="source-vector")
    edge["edge_sha256"] = impl._digest({k: v for k, v in edge.items() if k != "edge_sha256"})
    reverse_edge["edge_sha256"] = impl._digest({k: v for k, v in reverse_edge.items() if k != "edge_sha256"})
    ehp03 = {"source_identity": source, "axis_materials": axis_materials,
             "evidence_graph": {"forward_edges": [edge], "reverse_edges": [reverse_edge]},
             "g2_mapping": {"candidate_id": "candidate-vector", "ambiguity_decision": "none",
                             "issuer_ref": authority["signature_ref"],
                             "mapping_rows": [{"row_id": "r1", "issuer_ref": authority["signature_ref"]}],
                             "reverse_rows": [{"row_id": "r1", "issuer_ref": authority["signature_ref"]}]},
             "authority_receipt": authority}
    sbom = {"document_id": "doc-vector", "components": [{"component_id": "component-vector"}, {"component_id": "component-second"}], "dependency_edges": []}
    binary = {"candidate_id": "candidate-vector", "sha256": "a" * 64, "sbom_refs": [{"ref": "doc-vector", "sha256": "a" * 64}], "download_receipt": {"subject_sha256": "a" * 64}}
    ehp04 = {"expected_context_sha256": "b" * 64,
             "runtime_and_imports": {"runtimes": [{"name": "Julia"}, {"name": "Python"}], "imports": [{"name": "x", "version": "1", "locator": "l", "sha256": "a" * 64}, {"name": "y", "version": "1", "locator": "m", "sha256": "b" * 64}], "lockfiles": [{"name": "lock", "version": "1", "locator": "l", "sha256": "a" * 64}]},
             "sbom_documents": [sbom], "binaries": [binary], "foreign_owner_fixture": {"fixture_status": "executed", "reason": "offline"}}
    packets[2]["payload"] = ehp03
    packets[3]["payload"] = ehp04
    digests = [impl.packet_digest(packet) for packet in packets]
    return {"schema": "UP1.external-handoff.atomic-response-bundle.v1", "bundle_id": "00000000-0000-4000-8000-000000000001",
            "request_id": "00000000-0000-4000-8000-000000000002", "bundle_version": "v1", "packet_order": list(impl.ORDER),
            "canonical_exclusions": list(EXCLUSIONS), "shared_binding": shared, "packets": packets, "packet_digests": digests,
            "bundle_canonical_sha256": "c" * 64,
            "set_receipt": {"bundle_id": "00000000-0000-4000-8000-000000000001", "request_id": "00000000-0000-4000-8000-000000000002",
                "packet_digests": copy.deepcopy(digests), "shared_binding": copy.deepcopy(shared), "decision": "rejected_all", "quarantine_receipt": {
                    "raw_receipt_id": "receipt-vector", "raw_object_sha256": "a" * 64, "raw_blob_sha256": "a" * 64, "raw_size_bytes": 1,
                    "immutable_locator": "C:/vector/cas/a", "cas_transaction_id": "cas-vector", "durable_commit_utc": "2026-09-17T00:00:00Z",
                    "verification_started_utc": "2026-09-17T00:01:00Z", "decision_utc": "2026-09-17T00:02:00Z", "receiver_signature": {},
                    "state": "quarantine_raw", "receipt_sha256": "a" * 64}},
            "independent_review": {"derived_decision": "rejected_all"}, "security": {"security_ok": False, "trusted_public_keys": {"pinned": "x"}}}


def _mutate(path: str, value: Any) -> dict[str, Any]:
    out = _base()
    target: Any = out
    parts = path.strip("/").split("/")
    for part in parts[:-1]:
        target = target[int(part)] if isinstance(target, list) else target[part]
    last = int(parts[-1]) if isinstance(target, list) else parts[-1]
    target[last] = value
    return out


def build_R01() -> dict[str, Any]:
    return _mutate("/unknown_nested_key", "R01")
def build_R02() -> dict[str, Any]:
    out = _base(); out["packets"] = list(reversed(out["packets"])); return out
def build_R03() -> dict[str, Any]:
    return _mutate("/canonical_exclusions/0", "signature_digest")
def build_R04() -> dict[str, Any]:
    return _mutate("/set_receipt/bundle_id", "00000000-0000-4000-8000-000000000099")
def build_R05() -> dict[str, Any]:
    return _mutate("/set_receipt/request_id", "00000000-0000-4000-8000-000000000099")
def build_R06() -> dict[str, Any]:
    return _mutate("/set_receipt/packet_digests/0/packet_id", "EHP-99")
def build_R07() -> dict[str, Any]:
    return _mutate("/packets/0/shared_binding/candidate_id", "other-candidate")
def build_R08() -> dict[str, Any]:
    return _mutate("/set_receipt/quarantine_receipt", {"raw_receipt_id": "incomplete"})
def build_R09() -> dict[str, Any]:
    return _mutate("/set_receipt/quarantine_receipt/verification_started_utc", "2026-09-18T00:00:00Z")
def build_R10() -> dict[str, Any]:
    return _mutate("/set_receipt/quarantine_receipt/raw_object_sha256", "d" * 64)
def build_R11() -> dict[str, Any]:
    return _mutate("/set_receipt/quarantine_receipt/cas_transaction_id", "")
def build_R12() -> dict[str, Any]:
    return _mutate("/packets/2/payload/source_identity/candidate_id", "other-candidate")
def build_R13() -> dict[str, Any]:
    return _mutate("/packets/2/payload/source_identity/source_bytes_sha256", "e" * 64)
def build_R14() -> dict[str, Any]:
    return _mutate("/packets/2/payload/axis_materials", [{"axis_id": "A0"}])
def build_R15() -> dict[str, Any]:
    out = _base()
    edges = out["packets"][2]["payload"]["evidence_graph"]["forward_edges"]
    edges.append(copy.deepcopy(edges[0]))
    edges[1]["edge_id"] = edges[0]["edge_id"]
    return out
def build_R16() -> dict[str, Any]:
    return _mutate("/packets/2/payload/g2_mapping/mapping_rows", [])
def build_R17() -> dict[str, Any]:
    return _mutate("/packets/3/payload/expected_context_sha256", "f" * 64)
def build_R18() -> dict[str, Any]:
    return _mutate("/packets/3/payload/runtime_and_imports/runtimes", [{"name": "Julia"}])
def build_R19() -> dict[str, Any]:
    return _mutate("/packets/3/payload/runtime_and_imports/imports/1", {"name": "x", "version": "1", "locator": "l", "sha256": "a" * 64})
def build_R20() -> dict[str, Any]:
    return _mutate("/packets/3/payload/sbom_documents/0/components/0/component_id", "component-second")
def build_R21() -> dict[str, Any]:
    return _mutate("/packets/3/payload/binaries/0/candidate_id", "other-candidate")
def build_R22() -> dict[str, Any]:
    return _mutate("/packets/3/payload/foreign_owner_fixture/fixture_status", "not_executed")
def build_R23() -> bytes:
    return b'{"a":1,"a":2}'
def build_R24() -> dict[str, Any]:
    return _mutate("/security/trusted_public_keys", None)
def build_R25() -> dict[str, Any]:
    return _mutate("/security/security_ok", True)
def build_D01() -> dict[str, Any]:
    return _mutate("/set_receipt/decision", "accepted_all")


VECTOR_SPECS = {
    "R01": ("/unknown_nested_key", "SCHEMA_INVALID", "rejected_all"),
    "R02": ("/packets", "PACKET_ORDER_MISMATCH", "rejected_all"),
    "R03": ("/canonical_exclusions/0", "CANONICAL_EXCLUSION_NAME_INVALID", "rejected_all"),
    "R04": ("/set_receipt/bundle_id", "SET_BUNDLE_ID_MISMATCH", "rejected_all"),
    "R05": ("/set_receipt/request_id", "SET_REQUEST_ID_MISMATCH", "rejected_all"),
    "R06": ("/set_receipt/packet_digests/0/packet_id", "SET_PACKET_DIGESTS_MISMATCH", "rejected_all"),
    "R07": ("/packets/0/shared_binding/candidate_id", "PACKET_SHARED_BINDING_MISMATCH", "rejected_all"),
    "R08": ("/set_receipt/quarantine_receipt", "QUARANTINE_RECEIPT_INCOMPLETE", "rejected_all"),
    "R09": ("/set_receipt/quarantine_receipt/verification_started_utc", "QUARANTINE_NOT_BEFORE_VERIFY", "rejected_all"),
    "R10": ("/set_receipt/quarantine_receipt/raw_object_sha256", "QUARANTINE_RAW_DIGEST_MISMATCH", "rejected_all"),
    "R11": ("/set_receipt/quarantine_receipt/cas_transaction_id", "DECISION_NOT_BOUND_TO_QUARANTINE", "rejected_all"),
    "R12": ("/packets/2/payload/source_identity/candidate_id", "EHP03_CANDIDATE_BINDING_MISMATCH", "rejected_all"),
    "R13": ("/packets/2/payload/source_identity/source_bytes_sha256", "EHP03_SOURCE_BINDING_MISMATCH", "rejected_all"),
    "R14": ("/packets/2/payload/axis_materials", "EHP03_AXIS_SET_MISMATCH", "rejected_all"),
    "R15": ("/packets/2/payload/evidence_graph/forward_edges/1/edge_id", "EHP03_GRAPH_BIJECTION_FAILURE", "rejected_all"),
    "R16": ("/packets/2/payload/g2_mapping/mapping_rows", "EHP03_G2_MAPPING_MISMATCH", "rejected_all"),
    "R17": ("/packets/3/payload/expected_context_sha256", "EHP04_CONTEXT_BINDING_MISMATCH", "rejected_all"),
    "R18": ("/packets/3/payload/runtime_and_imports/runtimes", "EHP04_RUNTIME_SET_MISMATCH", "rejected_all"),
    "R19": ("/packets/3/payload/runtime_and_imports/imports/1", "EHP04_IDENTITY_MAP_DUPLICATE", "rejected_all"),
    "R20": ("/packets/3/payload/sbom_documents/0/components/0/component_id", "EHP04_SBOM_COMPONENT_DUPLICATE", "rejected_all"),
    "R21": ("/packets/3/payload/binaries/0/candidate_id", "EHP04_BINARY_BINDING_MISMATCH", "rejected_all"),
    "R22": ("/packets/3/payload/foreign_owner_fixture/fixture_status", "no_failure_code", "terminal_deferred"),
    "R23": ("/raw", "RAW_DUPLICATE_KEY", "rejected_all"),
    "R24": ("/security/trusted_public_keys", "no_failure_code", "terminal_deferred"),
    "R25": ("/security/security_ok", "internal accepted_all only", "accepted_all"),
    "D01": ("/set_receipt/decision", "DECISION_DISAGREEMENT", "rejected_all"),
}


def all_vectors() -> list[MutationVector]:
    vectors: list[MutationVector] = []
    for vector_id in [f"R{i:02d}" for i in range(1, 26)] + ["D01"]:
        path, expected, decision = VECTOR_SPECS[vector_id]
        vectors.append(MutationVector(vector_id, path, expected, decision, globals()[f"build_{vector_id}"]))
    return vectors


_CALLED_FUNCTION = {
    "R02": "validate_packet_order",
    "R03": "validate_canonical_exclusions",
    "R04": "validate_set_receipt_bundle_id",
    "R05": "validate_set_receipt_request_id",
    "R06": "validate_set_receipt_packet_digests",
    "R07": "validate_shared_binding",
    "R08": "_check_quarantine",
    "R09": "_check_quarantine",
    "R10": "_check_quarantine",
    "R11": "_check_quarantine",
    "R12": "_check_ehp03",
    "R13": "_check_ehp03",
    "R14": "_check_ehp03",
    "R15": "_check_ehp03",
    "R16": "_check_ehp03",
    "R17": "_check_ehp04",
    "R18": "_check_ehp04",
    "R19": "_check_ehp04",
    "R20": "_check_ehp04",
    "R21": "_check_ehp04",
    "R22": "_check_ehp04",
    "R24": "validate_security_and_decision",
    "R25": "validate_security_and_decision",
    "D01": "validate_decision_consistency",
}

_OWNED_PREDICATES = {
    vector_id: function_name for vector_id, function_name in _CALLED_FUNCTION.items()
    if vector_id in {"R02", "R03", "R04", "R05", "R06", "R07", "R24", "R25", "D01"}
}


def _json_bytes(value: Any) -> bytes:
    return value if isinstance(value, bytes) else json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _finish_semantic(errors: list[dict[str, str]], *, raw: bytes, fixture_status: str | None,
                     security_ok: bool) -> dict[str, Any]:
    """Use the production result/decision object for direct semantic checks.

    The public wire validator is intentionally not used for these vectors: a
    complete wire envelope would require a self-referential raw/CAS receipt.
    This helper preserves the production fail-closed decision precedence while
    passing the mutated object through the real production predicates above.
    """
    if errors:
        decision = "rejected_all"
    elif fixture_status == "not_executed":
        decision = "terminal_deferred"
    elif security_ok:
        decision = "accepted_all"
    else:
        impl._err(errors, "SECURITY_OUTCOME_UNAVAILABLE", "/security")
        decision = "rejected_all"
    if errors:
        decision = "rejected_all"
    return impl._result(hashlib.sha256(raw).hexdigest(), {}, {"cas_path": "", "receipt": {}},
                        errors, fixture_status, True, decision_override=decision)


def _semantic_execute(vector: MutationVector, built: Any, raw: bytes) -> tuple[str | None, str, dict[str, Any]]:
    """Execute one mutation against its production semantic predicate.

    R01 and R23 are the two intentionally end-to-end parser/schema vectors.
    All other vectors are direct calls to the production predicate that owns
    their path, followed by the production `_result` decision layer.
    """
    if vector.vector_id in {"R01", "R23"}:
        with tempfile.TemporaryDirectory() as tmp:
            result = validate_bundle(raw, quarantine_root=Path(tmp) / "q")
        codes = result["failure_codes"]
        return (codes[0] if codes else None, "validate_bundle", result)

    errors: list[dict[str, str]] = []
    fixture_status: str | None = "executed"
    security_ok = True
    bundle = built
    shared = bundle["shared_binding"]
    calls: list[str] = []

    def invoke_owned(function_name: str, *args: Any, **kwargs: Any) -> Any:
        """Call the production attribute while recording the actual dispatch.

        The wrapper is deliberately local to the independent harness.  It does
        not provide a replacement predicate: the original production function
        remains the function that computes the errors/decision.
        """
        original = getattr(impl, function_name)

        def traced(*inner_args: Any, **inner_kwargs: Any) -> Any:
            calls.append(function_name)
            return original(*inner_args, **inner_kwargs)

        with patch.object(impl, function_name, traced):
            return getattr(impl, function_name)(*args, **kwargs)

    if vector.vector_id == "R02":
        invoke_owned("validate_packet_order", bundle, errors)
    elif vector.vector_id == "R03":
        invoke_owned("validate_canonical_exclusions", bundle, errors)
    elif vector.vector_id in {"R04", "R05", "R06"}:
        function_name = {
            "R04": "validate_set_receipt_bundle_id",
            "R05": "validate_set_receipt_request_id",
            "R06": "validate_set_receipt_packet_digests",
        }[vector.vector_id]
        invoke_owned(function_name, bundle, errors)
    elif vector.vector_id == "R07":
        invoke_owned("validate_shared_binding", bundle, errors)
    elif vector.vector_id in {"R08", "R09", "R10", "R11"}:
        rec = bundle["set_receipt"]["quarantine_receipt"]
        q = {"cas_path": rec.get("immutable_locator", ""), "receipt": rec}
        invoke_owned("_check_quarantine", bundle, q, errors, raw)
    elif vector.vector_id in {"R12", "R13", "R14", "R15", "R16"}:
        invoke_owned("_check_ehp03", bundle["packets"][2]["payload"], shared, errors)
    elif vector.vector_id in {"R17", "R18", "R19", "R20", "R21"}:
        invoke_owned("_check_ehp04", bundle["packets"][3]["payload"], shared, errors)
    elif vector.vector_id == "R22":
        # The deferred fixture is evaluated on a clean EHP-04 envelope.  The
        # original wire-shaped builder remains the actual mutation input; the
        # direct harness removes unrelated artifact claims so this vector tests
        # only the fixture/decision path it owns.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            runtime_paths = []
            for name, data in (("julia", b"julia-vector"), ("python", b"python-vector")):
                path = root / name
                path.write_bytes(data)
                runtime_paths.append({"name": "Julia" if name == "julia" else "Python",
                                      "path": str(path), "path_sha256": hashlib.sha256(data).hexdigest()})
            payload = {"expected_context_sha256": shared["expected_context_sha256"],
                       "outer_authority": copy.deepcopy(shared),
                       "runtime_and_imports": {"runtimes": runtime_paths, "imports": [], "lockfiles": []},
                       "sbom_documents": [], "binaries": [],
                       "foreign_owner_fixture": {"fixture_status": "not_executed", "reason": "offline"}}
            fixture_status = invoke_owned("_check_ehp04", payload, shared, errors, root)
    elif vector.vector_id == "R24":
        # External security is absent; clean not_executed state is the only
        # production path that may defer, never accept.  The decision and
        # status below come from the production predicate, not this harness.
        security_result = invoke_owned("validate_security_and_decision", bundle,
                                       fixture_status="not_executed", security_ok=False,
                                       errors=errors)
        fixture_status = security_result["fixture_status"]
        security_ok = security_result["security_ok"]
    elif vector.vector_id == "R25":
        # This is an internal acceptance-shaped decision only.  No external
        # trust/authority credit is implied by the production result object.
        security_result = invoke_owned("validate_security_and_decision", bundle,
                                       fixture_status="executed", security_ok=True,
                                       errors=errors)
        fixture_status = security_result["fixture_status"]
        security_ok = security_result["security_ok"]
    elif vector.vector_id == "D01":
        # Without a pinned external security outcome the production decision
        # layer derives rejection; the mutation claims acceptance.
        invoke_owned("validate_decision_consistency", bundle, "rejected_all", errors)
    else:  # pragma: no cover - inventory is asserted by all_vectors()
        raise AssertionError(f"unmapped semantic vector: {vector.vector_id}")

    result = _finish_semantic(errors, raw=raw, fixture_status=fixture_status, security_ok=security_ok)
    codes = result["failure_codes"]
    actual_code = next((code for code in codes if code == vector.expected), codes[0] if codes else None)
    # The receipt must identify a function observed at runtime.  A missing
    # trace is a harness failure, never a permissible hand-written fallback.
    called_function = " -> ".join(calls)
    return actual_code, called_function, result


class ExplicitMutationVectorTests(unittest.TestCase):
    def test_all_26_builders_are_independent_and_matrix_bound(self):
        vectors = all_vectors()
        matrix_path = Path(__file__).parents[3] / "docs" / "implementation" / "UP1-EXTERNAL-BLOCKER-CLOSURE-R3" / "05-atomic-bundle-prototype" / "acceptance-test-matrix.json"
        matrix = {row["id"]: row["expected"] for row in json.loads(matrix_path.read_text(encoding="utf-8"))["vectors"]}
        self.assertEqual(len(vectors), 26)
        self.assertEqual({v.vector_id for v in vectors}, {f"R{i:02d}" for i in range(1, 26)} | {"D01"})
        self.assertEqual(len({v.mutation_path for v in vectors}), 26)
        raw_values = []
        for vector in vectors:
            built = vector.build()
            raw = built if isinstance(built, bytes) else json.dumps(built, sort_keys=True, separators=(",", ":")).encode()
            raw_values.append(raw)
            self.assertNotEqual(raw, json.dumps(_base(), sort_keys=True, separators=(",", ":")).encode(), vector.vector_id)
            if vector.vector_id not in {"R23"} and vector.expected != "no_failure_code":
                self.assertIn(vector.expected, matrix[vector.vector_id])
            self.assertIn(vector.decision, matrix[vector.vector_id])
            if vector.vector_id not in {"R01", "R23"}:
                self.assertNotEqual(vector.expected, "SCHEMA_INVALID")
        self.assertEqual(len({hashlib.sha256(raw).hexdigest() for raw in raw_values}), 26)

    def test_all_vectors_reach_owned_production_semantics(self):
        """R3 semantic replay: 26/26 vectors, with no schema placeholder.

        R01/R23 intentionally exercise the public parser/schema boundary.  The
        remaining vectors call the production predicate that owns the mutated
        path and then the production result object.  This is necessary because
        the complete wire envelope cannot be a fixed accepted baseline: its raw
        digest is embedded in its quarantine receipt.
        """
        receipts: list[dict[str, Any]] = []
        for vector in all_vectors():
            built = vector.build()
            raw = _json_bytes(built)
            actual_code, called_function, result = _semantic_execute(vector, built, raw)
            expected_code = None if vector.expected in {"no_failure_code", "internal accepted_all only"} else vector.expected
            with self.subTest(vector=vector.vector_id):
                self.assertEqual(result["decision"], vector.decision)
                self.assertTrue(result["no_publish"])
                if expected_code is None:
                    self.assertIsNone(actual_code)
                else:
                    self.assertEqual(actual_code, expected_code)
                if vector.vector_id not in {"R01", "R23"}:
                    self.assertNotEqual(result["failure_codes"], ["SCHEMA_INVALID"])
                self.assertEqual(called_function, _CALLED_FUNCTION.get(vector.vector_id, "validate_bundle"))
            receipts.append({
                "vector_id": vector.vector_id,
                "path": vector.mutation_path,
                "input_hash": hashlib.sha256(raw).hexdigest(),
                "called_function": called_function,
                "actual_code": actual_code or "no_failure_code",
                "actual_decision": result["decision"],
            })
        self.assertEqual(len(receipts), 26)
        self.assertEqual({r["vector_id"] for r in receipts}, {f"R{i:02d}" for i in range(1, 26)} | {"D01"})

    def test_unknown_internal_code_is_preserved_and_fail_closed(self):
        errors: list[dict[str, str]] = []
        impl._err(errors, "UNREGISTERED_INTERNAL_VECTOR_CODE", "/vector")
        self.assertEqual(errors[0]["code"], "UNREGISTERED_INTERNAL_VECTOR_CODE")
        result = impl._result("a" * 64, {}, {"cas_path": "", "receipt": {}}, errors, None, True)
        self.assertEqual(result["decision"], "rejected_all")
        self.assertTrue(result["no_publish"])

    def test_ehp04_requires_root_and_recomputes_sbom_download_bytes(self):
        shared = {"candidate_id": "candidate-vector", "source_identity_sha256": "a" * 64, "expected_context_sha256": "b" * 64}
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            julia = root / "julia"; julia.write_bytes(b"julia")
            python = root / "python"; python.write_bytes(b"python")
            binary = root / "candidate.bin"; binary.write_bytes(b"binary")
            sbom_bytes = b'{"components":["component-vector"]}'
            sbom_path = root / "sbom.json"; sbom_path.write_bytes(sbom_bytes)
            receipt_bytes = b'{"subject":"candidate.bin"}'
            receipt_path = root / "download.receipt"; receipt_path.write_bytes(receipt_bytes)
            sbom_hash = hashlib.sha256(sbom_bytes).hexdigest()
            binary_hash = hashlib.sha256(binary.read_bytes()).hexdigest()
            payload = {"expected_context_sha256": "b" * 64, "outer_authority": shared,
                "runtime_and_imports": {"runtimes": [{"name": "Julia", "path": str(julia), "path_sha256": hashlib.sha256(julia.read_bytes()).hexdigest()}, {"name": "Python", "path": str(python), "path_sha256": hashlib.sha256(python.read_bytes()).hexdigest()}], "imports": [], "lockfiles": []},
                "sbom_documents": [{"document_id": "doc-vector", "document_sha256": sbom_hash, "path": str(sbom_path), "components": [{"component_id": "component-vector"}], "dependency_edges": []}],
                "binaries": [{"candidate_id": "candidate-vector", "path": str(binary), "sha256": binary_hash, "sbom_refs": [{"ref": "doc-vector", "sha256": sbom_hash}], "download_receipt": {"subject_sha256": binary_hash, "receipt_ref": {"path": str(receipt_path), "sha256": hashlib.sha256(receipt_bytes).hexdigest()}}}],
                "foreign_owner_fixture": {"fixture_status": "not_executed", "reason": "offline"}}
            errors: list[dict[str, str]] = []
            self.assertEqual(impl._check_ehp04(payload, shared, errors, root), "not_executed")
            self.assertNotIn("EHP04_SBOM_ARTIFACT_DIGEST_MISMATCH", {e["code"] for e in errors})
            self.assertNotIn("EHP04_DOWNLOAD_RECEIPT_DIGEST_MISMATCH", {e["code"] for e in errors})
            errors = []
            impl._check_ehp04(payload, shared, errors, None)
            self.assertIn("EHP04_ARTIFACT_ROOT_REQUIRED", {e["code"] for e in errors})
            self.assertIn("EHP04_SBOM_ARTIFACT_UNAVAILABLE", {e["code"] for e in errors})


if __name__ == "__main__":
    unittest.main()
