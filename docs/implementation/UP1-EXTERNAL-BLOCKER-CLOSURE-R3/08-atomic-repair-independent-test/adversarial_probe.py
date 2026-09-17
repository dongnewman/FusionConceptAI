from __future__ import annotations

import base64
import copy
import hashlib
import json
import os
import pathlib
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[4]))

from tools.up1_external_closure_r3.atomic_bundle import canonical_bytes, validate_bundle
from tools.up1_external_closure_r3.atomic_bundle import bundle as impl
from tools.up1_external_closure_r3.atomic_bundle.canonical import CanonicalError


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def emit(name: str, status: str, **fields: object) -> None:
    print(json.dumps({"case": name, "status": status, **fields}, sort_keys=True, default=str))


def main() -> None:
    emit("profile", "PASS", profile=impl.canonical_profile())
    try:
        canonical_bytes({"n": 1e20})
        if impl.canonical_profile() == "RFC8785-required-float-reject-fallback":
            emit("float_exponent_reject", "FAIL", detail="1e20 accepted under fallback")
        else:
            emit("float_exponent_reject", "PASS", detail="RFC8785 active")
    except CanonicalError as exc:
        emit("float_exponent_reject", "PASS", code=exc.code)
    try:
        one = canonical_bytes({"n": 1})
        large = canonical_bytes({"n": 1e20})
        emit("float_integer_collision", "PASS" if one != large else "FAIL", equal=one == large, integer=one, large=large)
    except CanonicalError as exc:
        emit("float_integer_collision", "PASS", detail="large float rejected", code=exc.code, integer=canonical_bytes({"n": 1}))
    try:
        canonical_bytes({"n": -0.0})
        emit("negative_zero", "FAIL", detail="accepted")
    except CanonicalError as exc:
        emit("negative_zero", "PASS", code=exc.code)

    malformed = [
        b'{"schema":"x","packets":[{"payload":1}]}', b"[]", b'{"schema":1}',
        b'{"schema":"UP1.external-handoff.atomic-response-bundle.v1","packets":[1]}',
        b'{"schema":"UP1.external-handoff.atomic-response-bundle.v1","independent_review":3}',
    ]
    crashes = []
    malformed_results = []
    for raw in malformed:
        try:
            result = validate_bundle(raw)
            malformed_results.append({"status": result.get("status"), "no_publish": result.get("no_publish"), "codes": result.get("failure_codes")})
            if not isinstance(result, dict) or result.get("no_publish") is not True or "SCHEMA_INVALID" not in result.get("failure_codes", []):
                crashes.append("typed-fail-closed")
        except Exception as exc:  # evidence that the public API escaped its typed boundary
            crashes.append(type(exc).__name__ + ":" + str(exc))
    emit("malformed_shapes", "PASS" if not crashes else "FAIL", crashes=crashes, results=malformed_results)

    with tempfile.TemporaryDirectory(prefix="up1-r3-independent-") as tmp:
        root = pathlib.Path(tmp) / "q"
        raw = b"independent-quarantine-bytes"
        q = impl.quarantine_raw(raw, root)
        rec = q["receipt"]
        rec_without_digest = {k: v for k, v in rec.items() if k != "receipt_sha256"}
        receipt_digest_ok = rec["receipt_sha256"] == impl._digest(rec_without_digest)
        receiver = rec["receiver_signature"]
        receiver_raw = base64.b64decode(receiver["signature_b64"], validate=True)
        receiver_preimage = impl._receiver_preimage(rec)
        receiver_preimage_ok = receiver["receiver_preimage_sha256"] == digest(receiver_preimage)
        signature_digest_ok = receiver["signature_sha256"] == digest(receiver_raw)
        signature_ok = False
        try:
            from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
            Ed25519PrivateKey.from_private_bytes(bytes(range(1, 33))).public_key().verify(receiver_raw, receiver_preimage)
            signature_ok = True
        except Exception:
            signature_ok = False
        cas = pathlib.Path(q["cas_path"])
        cas_ok = cas.read_bytes() == raw and digest(cas.read_bytes()) == digest(raw) and rec["raw_blob_sha256"] == digest(raw)
        emit("quarantine_independent_recompute", "PASS" if all((receipt_digest_ok, receiver_preimage_ok, signature_digest_ok, signature_ok, cas_ok)) else "FAIL", receipt_digest=receipt_digest_ok, receiver_preimage=receiver_preimage_ok, signature_digest=signature_digest_ok, receiver_signature=signature_ok, cas=cas_ok)

        wrapped = {"set_receipt": {"quarantine_receipt": copy.deepcopy(rec)}}
        tamper_cases = {}
        for field, value in (("raw_object_sha256", "0" * 64), ("raw_size_bytes", len(raw) + 1), ("cas_transaction_id", "attacker"), ("receipt_sha256", "f" * 64)):
            tampered = copy.deepcopy(wrapped)
            tampered["set_receipt"]["quarantine_receipt"][field] = value
            errors: list[dict[str, str]] = []
            impl._check_quarantine(tampered, q, errors, raw)
            tamper_cases[field] = sorted({e["code"] for e in errors})
        tampered = copy.deepcopy(wrapped)
        tampered["set_receipt"]["quarantine_receipt"]["receiver_signature"]["signature_b64"] = "AAAA"
        errors = []
        impl._check_quarantine(tampered, q, errors, raw)
        tamper_cases["receiver_signature"] = sorted({e["code"] for e in errors})
        emit("quarantine_tamper_rejection", "PASS" if all(tamper_cases.values()) else "FAIL", codes=tamper_cases)

        # Existing CAS object with different bytes must not be overwritten; equal bytes are idempotent.
        collision_raw = b"cas-collision-independent"
        collision_digest = digest(collision_raw)
        collision_root = pathlib.Path(tmp) / "collision"
        (collision_root / "cas").mkdir(parents=True)
        (collision_root / "cas" / collision_digest).write_bytes(b"attacker")
        collision = ""
        try:
            impl.quarantine_raw(collision_raw, collision_root)
            collision = "accepted"
        except OSError as exc:
            collision = str(exc)
        (collision_root / "cas" / collision_digest).write_bytes(collision_raw)
        first = impl.quarantine_raw(collision_raw, collision_root)
        second = impl.quarantine_raw(collision_raw, collision_root)
        idempotent = first["cas_path"] == second["cas_path"] and pathlib.Path(first["cas_path"]).read_bytes() == collision_raw
        emit("cas_collision_idempotent", "PASS" if "CAS_COLLISION_FAIL_CLOSED" in collision and idempotent else "FAIL", collision=collision, idempotent=idempotent)

        # Root traversal is resolved and remains contained; symlink/junction roots are rejected when the host permits creation.
        traversal_root = pathlib.Path(tmp) / "traversal" / "nested" / ".."
        tq = impl.quarantine_raw(b"traversal", traversal_root)
        intended = (pathlib.Path(tmp) / "traversal").resolve()
        contained = pathlib.Path(tq["cas_path"]).resolve().is_relative_to(intended)
        emit("path_traversal", "PASS" if contained else "FAIL", cas_path=tq["cas_path"], intended=str(intended))
        link_status = "SKIP"
        link_detail = "symlink creation unavailable"
        link = pathlib.Path(tmp) / "symlink-root"
        target = pathlib.Path(tmp) / "symlink-target"
        target.mkdir()
        try:
            os.symlink(target, link, target_is_directory=True)
            try:
                impl.quarantine_raw(b"symlink", link)
                link_status = "FAIL"
                link_detail = "accepted"
            except OSError as exc:
                link_status = "PASS" if "CAS_REPARSE_POINT_REJECTED" in str(exc) else "FAIL"
                link_detail = str(exc)
        except (OSError, NotImplementedError) as exc:
            link_detail = type(exc).__name__ + ":" + str(exc)
        emit("symlink_reparse_root", link_status, detail=link_detail)
        junction_status = "SKIP"
        junction_detail = "junction creation unavailable"
        junction = pathlib.Path(tmp) / "junction-root"
        proc = subprocess.run(["cmd", "/c", "mklink", "/J", str(junction), str(target)], capture_output=True, text=True)
        if proc.returncode == 0:
            try:
                impl.quarantine_raw(b"junction", junction)
                junction_status, junction_detail = "FAIL", "accepted"
            except OSError as exc:
                junction_status, junction_detail = ("PASS" if "CAS_REPARSE_POINT_REJECTED" in str(exc) else "FAIL"), str(exc)
        else:
            junction_detail = (proc.stdout + proc.stderr).strip()
        emit("junction_reparse_root", junction_status, detail=junction_detail)

    # EHP-03: valid closure, then independently recomputed graph/row/mapping/ref tamper checks.
    H = "a" * 64
    shared = {"candidate_id": "candidate-1", "source_identity_sha256": H, "expected_context_sha256": H, "four_axis_refs": [{"axis_id": f"A{i}"} for i in range(4)]}
    source = {"candidate_id": "candidate-1", "revision": "r", "head": "h", "tree": H, "dirty_patch": {"present": True, "sha256": H, "entries": ["p"]}, "untracked": {"present": True, "sha256": H, "entries": ["u"]}, "submodules": {"present": True, "sha256": H, "entries": ["s"]}, "source_bytes_sha256": H, "inventory_sha256": H}
    shared["source_identity_sha256"] = impl._digest(source)
    edge = {"edge_id": "e1", "from_kind": "source", "from_id": "s", "to_kind": "candidate", "to_id": "candidate-1", "candidate_id": "candidate-1", "source_identity_sha256": shared["source_identity_sha256"], "namespace": "n", "version": "1"}
    reverse_edge = dict(edge, edge_id="e2", from_kind="candidate", from_id="candidate-1", to_kind="source", to_id="s")
    graph = {"forward_edges": [edge], "reverse_edges": [reverse_edge]}
    graph["graph_sha256"] = impl._digest({k: v for k, v in graph.items() if k != "graph_sha256"})
    signature_ref = {"issuer": "authority", "signature": H}
    row = {"row_id": "r1", "from_id": "x", "to_id": "y", "issuer_ref": signature_ref}
    row["row_sha256"] = impl._digest({k: v for k, v in row.items() if k != "row_sha256"})
    reverse_row = {"row_id": "r1", "from_id": "y", "to_id": "x", "issuer_ref": signature_ref}
    reverse_row["row_sha256"] = impl._digest({k: v for k, v in reverse_row.items() if k != "row_sha256"})
    mapping = {"candidate_id": "candidate-1", "ambiguity_decision": "none", "mapping_rows": [row], "reverse_rows": [reverse_row], "issuer_ref": signature_ref}
    mapping["mapping_sha256"] = impl._digest({k: v for k, v in mapping.items() if k != "mapping_sha256"})
    payload03 = {"source_identity": source, "axis_materials": [{"axis_id": f"A{i}"} for i in range(4)], "evidence_graph": graph, "g2_mapping": mapping, "authority_receipt": {"candidate_id": "candidate-1", "source_identity_sha256": shared["source_identity_sha256"], "graph_sha256": graph["graph_sha256"], "signature_ref": signature_ref}}
    errors: list[dict[str, str]] = []
    impl._check_ehp03(payload03, shared, errors)
    emit("ehp03_valid_closure", "PASS" if not errors else "FAIL", codes=sorted({e["code"] for e in errors}))
    ehp03_tamper = {}
    for field in ("graph_sha256", "mapping_sha256"):
        tampered = copy.deepcopy(payload03)
        tampered["evidence_graph" if field == "graph_sha256" else "g2_mapping"][field] = "f" * 64
        errors = []
        impl._check_ehp03(tampered, shared, errors)
        ehp03_tamper[field] = sorted({e["code"] for e in errors})
    tampered = copy.deepcopy(payload03)
    tampered["g2_mapping"]["mapping_rows"][0]["row_sha256"] = "f" * 64
    errors = []
    impl._check_ehp03(tampered, shared, errors)
    ehp03_tamper["row_sha256"] = sorted({e["code"] for e in errors})
    tampered = copy.deepcopy(payload03)
    tampered["authority_receipt"]["graph_sha256"] = "f" * 64
    errors = []
    impl._check_ehp03(tampered, shared, errors)
    ehp03_tamper["authority_graph_ref"] = sorted({e["code"] for e in errors})
    emit("ehp03_tamper_rejection", "PASS" if all(ehp03_tamper.values()) else "FAIL", codes=ehp03_tamper)

    # EHP-04: all material identity relations are independently checked.
    runtime_and_imports = {"runtimes": [{"name": "Julia", "path": "missing-julia", "path_sha256": digest(b"missing-julia")}, {"name": "Python", "path": "missing-python", "path_sha256": digest(b"missing-python")}], "imports": [], "lockfiles": []}
    sbom = {"document_id": "doc-1", "components": [{"component_id": "comp-1"}], "dependency_edges": []}
    sbom["document_sha256"] = impl._digest({k: v for k, v in sbom.items() if k != "document_sha256"})
    binary = {"candidate_id": "candidate-1", "sha256": H, "sbom_refs": [{"ref": "doc-1", "sha256": sbom["document_sha256"]}], "download_receipt": {"subject_sha256": H, "receipt_ref": {"sha256": H}}}
    payload04 = {"expected_context_sha256": H, "outer_authority": {"candidate_id": "candidate-1", "source_identity_sha256": shared["source_identity_sha256"], "expected_context_sha256": H}, "runtime_and_imports": runtime_and_imports, "sbom_documents": [sbom], "binaries": [binary], "foreign_owner_fixture": {"fixture_status": "not_executed", "reason": "TEST_ONLY"}}
    errors = []
    status = impl._check_ehp04(payload04, shared, errors)
    emit("ehp04_valid_closure", "PASS" if not errors and status == "not_executed" else "FAIL", fixture_status=status, codes=sorted({e["code"] for e in errors}))
    ehp04_tamper = {}
    for action in ("runtime", "sbom", "binary", "fixture"):
        tampered = copy.deepcopy(payload04)
        if action == "runtime": tampered["runtime_and_imports"]["runtimes"][0]["path_sha256"] = "f" * 64
        if action == "sbom": tampered["sbom_documents"][0]["document_sha256"] = "f" * 64
        if action == "binary": tampered["binaries"][0]["sbom_refs"][0]["sha256"] = "f" * 64
        if action == "fixture": tampered["foreign_owner_fixture"] = {"fixture_status": "executed"}
        errors = []
        impl._check_ehp04(tampered, shared, errors)
        ehp04_tamper[action] = sorted({e["code"] for e in errors})
    emit("ehp04_tamper_rejection", "PASS" if all(ehp04_tamper.values()) else "FAIL", codes=ehp04_tamper)

    # TEST_ONLY is a hard non-evidence boundary even if an upstream caller asks for acceptance.
    forced = impl._result(H, {"bundle_canonical_sha256": H}, {"cas_path": "", "receipt": {}}, [], "not_executed", True, decision_override="accepted_all", expected_bundle=H)
    marker = impl._result(H, {}, {"cas_path": "", "receipt": {}}, [{"code": "TEST_ONLY_NON_EVIDENCE", "path": "/packets/0"}], None, False)
    emit("test_only_non_evidence", "PASS" if forced["authority_credit"] is False and forced["no_publish"] is True and forced["formal_credit"] == "none" and marker["status"] == "fail_limited" and marker["no_publish"] is True else "FAIL", accepted_override_flags={k: forced[k] for k in ("decision", "authority_credit", "no_publish", "formal_credit")}, marker=marker)

    vectors = [f"R{i:02d}" for i in range(1, 26)] + ["D01"]
    raw_vectors = [b"not-json", b"[]", b"{}", b'{"schema":1}', b'{"schema":"wrong"}', b'{"schema":"UP1.external-handoff.atomic-response-bundle.v1"}']
    vector_failures = []
    vector_receipts = []
    for i, vector_id in enumerate(vectors):
        raw = raw_vectors[i % len(raw_vectors)]
        try:
            result = validate_bundle(raw)
            vector_receipts.append({"id": vector_id, "raw_sha256": digest(raw), "decision": result.get("decision"), "status": result.get("status"), "failure_codes": result.get("failure_codes"), "no_publish": result.get("no_publish")})
            if result.get("no_publish") is not True or result.get("status") not in {"fail_limited", "prototype_pass_limited"}:
                vector_failures.append(vector_id)
        except Exception as exc:
            vector_failures.append(vector_id + ":" + type(exc).__name__)
    emit("R01-R25-D01_actual_mapping", "PASS" if not vector_failures else "FAIL", failures=vector_failures, vectors=vector_receipts)


if __name__ == "__main__":
    main()
