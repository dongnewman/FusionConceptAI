"""Offline independent probes for the frozen UP1 R3 atomic prototype.

This file is an evidence-producing probe, not a production test and does not
modify the implementation or the repository test tree.  It deliberately keeps
the 26-vector builder audit independent from the test's local builder body.
"""
from __future__ import annotations

import copy
import hashlib
import json
import os
import pathlib
import re
import stat
import sys
import tempfile
from contextlib import contextmanager
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from tools.up1_external_closure_r3.atomic_bundle import validate_bundle  # noqa: E402
from tools.up1_external_closure_r3.atomic_bundle import bundle as impl  # noqa: E402


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def emit(case: str, status: str, **fields: object) -> None:
    print(json.dumps({"case": case, "status": status, **fields}, sort_keys=True, default=str))


def codes(errors: list[dict[str, str]]) -> list[str]:
    return sorted({str(x.get("code")) for x in errors})


def expect_raises(case: str, fn, expected: str) -> bool:
    try:
        fn()
    except OSError as exc:
        actual = str(exc).split(":", 1)[0]
        ok = actual == expected
        emit(case, "PASS" if ok else "FAIL", expected=expected, actual=actual, detail=str(exc))
        return ok
    except Exception as exc:  # pragma: no cover - evidence if boundary escapes
        emit(case, "FAIL", expected=expected, actual=type(exc).__name__, detail=str(exc))
        return False
    emit(case, "FAIL", expected=expected, actual="accepted")
    return False


def probe_hardlink() -> bool:
    raw = b"independent-hardlink"
    digest = sha256(raw)
    with tempfile.TemporaryDirectory(prefix="up1-r3-r2-hardlink-") as tmp:
        root = pathlib.Path(tmp) / "root"
        (root / "cas").mkdir(parents=True)
        outside = pathlib.Path(tmp) / "outside"
        outside.write_bytes(raw)
        target = root / "cas" / digest
        try:
            os.link(outside, target)
        except (OSError, NotImplementedError) as exc:
            emit("cas_hardlink", "SKIP", typed_skip=True, reason=f"{type(exc).__name__}: {exc}")
            return True
        return expect_raises("cas_hardlink", lambda: impl.quarantine_raw(raw, root), "CAS_HARDLINK_REJECTED")


def probe_reparse() -> bool:
    outcomes: list[bool] = []
    with tempfile.TemporaryDirectory(prefix="up1-r3-r2-reparse-") as tmp:
        base = pathlib.Path(tmp)
        target = base / "target"
        target.mkdir()
        root_link = base / "root-link"
        try:
            os.symlink(target, root_link, target_is_directory=True)
            outcomes.append(expect_raises("reparse_pre_root", lambda: impl.quarantine_raw(b"pre-root", root_link), "CAS_REPARSE_POINT_REJECTED"))
        except (OSError, NotImplementedError) as exc:
            emit("reparse_pre_root", "SKIP", typed_skip=True, real_probe_unavailable=f"{type(exc).__name__}: {exc}")
        regular_root = base / "regular-root"
        regular_root.mkdir()
        cas_link = regular_root / "cas"
        try:
            os.symlink(target, cas_link, target_is_directory=True)
            outcomes.append(expect_raises("reparse_pre_parent", lambda: impl.quarantine_raw(b"pre-parent", regular_root), "CAS_REPARSE_POINT_REJECTED"))
        except (OSError, NotImplementedError) as exc:
            emit("reparse_pre_parent", "SKIP", typed_skip=True, real_probe_unavailable=f"{type(exc).__name__}: {exc}")

        # A real replacement race is not safe or deterministic to create here.
        # Inject the post-check observation and label it as typed injected data.
        for label, selected in (("reparse_post_root", regular_root / "post-root"),
                                ("reparse_post_parent", regular_root / "post-parent" / "cas")):
            counts: dict[str, int] = {}
            original = impl._reparse
            selected = selected.absolute()

            def injected(path: pathlib.Path, *, _selected=selected) -> bool:
                path = pathlib.Path(path).absolute()
                key = str(path)
                counts[key] = counts.get(key, 0) + 1
                if path == _selected and counts[key] >= 2:
                    return True
                return original(path)

            try:
                selected.parent.mkdir(parents=True, exist_ok=True)
                with patch.object(impl, "_reparse", side_effect=injected):
                    ok = expect_raises(label, lambda p=selected: impl.quarantine_raw(label.encode(), p), "CAS_REPARSE_POINT_REJECTED")
                emit(label + "_annotation", "PASS" if ok else "FAIL", typed_injected=True, observations=counts)
                outcomes.append(ok)
            except Exception as exc:
                emit(label, "FAIL", typed_injected=True, detail=f"{type(exc).__name__}: {exc}")
                outcomes.append(False)
    return all(outcomes) if outcomes else True


def g2_payload() -> tuple[dict, dict]:
    h = "a" * 64
    shared = {"candidate_id": "candidate-1", "source_identity_sha256": h,
              "four_axis_refs": [{"axis_id": f"A{i}"} for i in range(4)]}
    source = {"candidate_id": "candidate-1", "revision": "r", "head": "h", "tree": h,
              "dirty_patch": {"present": True, "sha256": h, "entries": ["p"]},
              "untracked": {"present": True, "sha256": h, "entries": ["u"]},
              "submodules": {"present": True, "sha256": h, "entries": ["s"]},
              "source_bytes_sha256": h, "inventory_sha256": h}
    shared["source_identity_sha256"] = impl._digest(source)
    authority_ref = {"ref": "authority-signature", "sha256": h}
    edge = {"edge_id": "e1", "from_kind": "source", "from_id": "s", "to_kind": "candidate",
            "to_id": "candidate-1", "candidate_id": "candidate-1",
            "source_identity_sha256": shared["source_identity_sha256"], "namespace": "n",
            "version": "1", "issued_at": "2026-09-17T00:00:00Z",
            "issuer_ref": authority_ref, "signature_ref": authority_ref}
    edge["edge_sha256"] = impl._digest({k: v for k, v in edge.items() if k != "edge_sha256"})
    reverse_edge = dict(edge, edge_id="e2", from_kind="candidate", from_id="candidate-1",
                        to_kind="source", to_id="s")
    reverse_edge["edge_sha256"] = impl._digest({k: v for k, v in reverse_edge.items() if k != "edge_sha256"})
    graph = {"forward_edges": [edge], "reverse_edges": [reverse_edge]}
    graph["graph_sha256"] = impl._digest(graph)
    row = {"row_id": "r1", "from_id": "source-x", "to_id": "candidate-1",
           "issuer_ref": authority_ref, "issued_at": "2026-09-17T00:00:00Z"}
    row["row_sha256"] = impl._digest(row)
    inverse = {"row_id": "r1", "from_id": "candidate-1", "to_id": "source-x",
               "issuer_ref": authority_ref, "issued_at": "2026-09-17T00:00:00Z"}
    inverse["row_sha256"] = impl._digest(inverse)
    mapping = {"candidate_id": "candidate-1", "ambiguity_decision": "none", "mapping_rows": [row],
               "reverse_rows": [inverse], "issuer_ref": authority_ref}
    mapping["mapping_sha256"] = impl._digest(mapping)
    payload = {"source_identity": source, "axis_materials": [{"axis_id": f"A{i}"} for i in range(4)],
               "evidence_graph": graph, "g2_mapping": mapping,
               "authority_receipt": {"candidate_id": "candidate-1",
                                     "source_identity_sha256": shared["source_identity_sha256"],
                                     "graph_sha256": graph["graph_sha256"], "signature_ref": authority_ref}}
    return payload, shared


def probe_g2() -> bool:
    payload, shared = g2_payload()
    errors: list[dict[str, str]] = []
    impl._check_ehp03(payload, shared, errors)
    good = not errors and payload["g2_mapping"]["mapping_rows"][0]["row_sha256"] != payload["g2_mapping"]["reverse_rows"][0]["row_sha256"]
    emit("g2_directional_inverse", "PASS" if good else "FAIL", good_codes=codes(errors), distinct_digests=good)
    tampered = copy.deepcopy(payload)
    tampered["g2_mapping"]["reverse_rows"][0]["issuer_ref"] = {"ref": "attacker", "sha256": "a" * 64}
    errors = []
    impl._check_ehp03(tampered, shared, errors)
    observed = codes(errors)
    attacked = "EHP03_G2_REF_MISMATCH" in observed and "EHP03_G2_MAPPING_MISMATCH" in observed
    emit("g2_directional_authority_tamper", "PASS" if attacked else "FAIL", codes=observed)
    return good and attacked


def probe_decision_and_test_only() -> bool:
    q = {"cas_path": "", "receipt": {}}
    precedence = impl._result("a" * 64, {}, q, [{"code": "EHP03_G2_ROW_DIGEST_MISMATCH", "path": "/g2"}], "not_executed", True)
    deferred = impl._result("a" * 64, {}, q, [], "not_executed", True)
    marker = impl._result("a" * 64, {}, q, [{"code": "TEST_ONLY_NON_EVIDENCE", "path": "/packets/0"}], None, False)
    ok = precedence["decision"] == "rejected_all" and deferred["decision"] == "terminal_deferred" and marker["decision"] == "rejected_all" and marker["no_publish"]
    emit("decision_precedence", "PASS" if ok else "FAIL", precedence=precedence["decision"], clean_fixture=deferred["decision"], test_only=marker["decision"])

    owner_bundle = {"schema": "UP1.external-handoff.atomic-response-bundle.v1", "bundle_id": "bad", "request_id": "bad",
                    "bundle_version": "v1", "packet_order": impl.ORDER, "canonical_exclusions": impl.EXCLUSIONS,
                    "shared_binding": {"candidate_id": "c", "source_identity_sha256": "a" * 64, "four_axis_refs": []},
                    "packets": [], "packet_digests": [{"packet_id": packet_id} for packet_id in impl.ORDER], "bundle_canonical_sha256": "a" * 64,
                    "set_receipt": {}, "independent_review": {}}
    # Force the post-schema path solely to exercise owner/context precedence;
    # this does not alter the frozen implementation.
    with tempfile.TemporaryDirectory(prefix="up1-r3-r2-owner-") as owner_tmp, tempfile.TemporaryDirectory(prefix="up1-r3-r2-context-") as context_tmp, patch.object(impl, "_schema_errors", return_value=[]):
        for i, packet_id in enumerate(impl.ORDER):
            owner = "TEST_ONLY-owner" if i == 0 else f"owner-{i}"
            owner_bundle["packets"].append({"packet_id": packet_id, "packet_version": "v1",
                "owner": {"owner_id": owner, "role": impl.ROLES[i]},
                "shared_binding": owner_bundle["shared_binding"], "payload": {},
                "payload_sha256": "a" * 64, "signature": {"key_id": owner}})
        owner_result = validate_bundle(json.dumps(owner_bundle).encode(), context={"security_ok": True}, quarantine_root=owner_tmp)
        context_result = validate_bundle(json.dumps(owner_bundle).encode(), context={"security_ok": True,
            "trusted_public_keys": {"TEST_ONLY-owner": "x"}}, quarantine_root=context_tmp)
    owner_ok = "TEST_ONLY_NON_EVIDENCE" in owner_result["failure_codes"]
    context_ok = "TEST_ONLY_NON_EVIDENCE" in context_result["failure_codes"]
    emit("test_only_owner_context", "PASS" if owner_ok and context_ok else "FAIL",
         owner_codes=owner_result["failure_codes"], context_codes=context_result["failure_codes"])

    with tempfile.TemporaryDirectory(prefix="up1-r3-r2-receiver-") as tmp:
        qx = impl.quarantine_raw(b"receiver-test-only", tmp)
        errors: list[dict[str, str]] = []
        impl._check_quarantine({"set_receipt": {"quarantine_receipt": copy.deepcopy(qx["receipt"])}}, qx, errors, b"receiver-test-only")
        receiver_ok = "TEST_ONLY_NON_EVIDENCE" in codes(errors)
        emit("test_only_receiver", "PASS" if receiver_ok else "FAIL", codes=codes(errors))
    return ok and owner_ok and context_ok and receiver_ok


def probe_ehp04() -> bool:
    h = "a" * 64
    shared = {"candidate_id": "candidate-1", "source_identity_sha256": h, "expected_context_sha256": h}
    with tempfile.TemporaryDirectory(prefix="up1-r3-r2-ehp04-") as tmp:
        root = pathlib.Path(tmp)
        julia, python, binary = root / "julia", root / "python", root / "binary"
        julia.write_bytes(b"julia-local")
        python.write_bytes(b"python-local")
        binary.write_bytes(b"binary-local")
        runtime = {"runtimes": [{"name": "Julia", "path": str(julia), "path_sha256": sha256(julia.read_bytes())},
                                 {"name": "Python", "path": str(python), "path_sha256": sha256(python.read_bytes())}],
                   "imports": [], "lockfiles": []}
        sbom = {"document_id": "doc-1", "components": [{"component_id": "comp-1"}], "dependency_edges": []}
        sbom["document_sha256"] = impl._digest(sbom)
        binary_item = {"candidate_id": "candidate-1", "path": str(binary), "sha256": sha256(binary.read_bytes()),
                       "sbom_refs": [{"ref": "doc-1", "sha256": sbom["document_sha256"]}],
                       "download_receipt": {"subject_sha256": sha256(binary.read_bytes()),
                                            "receipt_ref": {"sha256": sha256(binary.read_bytes())}}}
        payload = {"expected_context_sha256": h, "outer_authority": dict(shared), "runtime_and_imports": runtime,
                   "sbom_documents": [sbom], "binaries": [binary_item],
                   "foreign_owner_fixture": {"fixture_status": "not_executed", "reason": "TEST_ONLY"}}
        errors: list[dict[str, str]] = []
        status = impl._check_ehp04(payload, shared, errors, root)
        local_ok = status == "not_executed" and not errors
        emit("ehp04_local_bytes", "PASS" if local_ok else "FAIL", fixture_status=status, codes=codes(errors))
        stdout, stderr, receipt = root / "stdout", root / "stderr", root / "receipt.json"
        stdout.write_bytes(b"stdout")
        stderr.write_bytes(b"stderr")
        fixture = {"fixture_status": "executed", "owner_id": "TEST_ONLY-owner", "acl_sha256": h,
                   "command": "offline", "exit_code": 0, "utc": "2026-09-17T00:00:00Z",
                   "stdout_path": str(stdout), "stderr_path": str(stderr), "receipt_path": str(receipt),
                   "stdout_sha256": sha256(stdout.read_bytes()), "stderr_sha256": sha256(stderr.read_bytes())}
        fixture["receipt_sha256"] = impl._digest(fixture)
        receipt.write_text(json.dumps({"receipt_sha256": fixture["receipt_sha256"]}), encoding="utf-8")
        payload["foreign_owner_fixture"] = fixture
        errors = []
        status = impl._check_ehp04(payload, shared, errors, root)
        receipt_ok = status == "executed" and not errors
        emit("ehp04_local_receipt", "PASS" if receipt_ok else "FAIL", fixture_status=status, codes=codes(errors))
        receipt.write_text("{\"receipt_sha256\":\"tampered\"}", encoding="utf-8")
        errors = []
        impl._check_ehp04(payload, shared, errors, root)
        tamper_ok = "EHP04_FIXTURE_RECEIPT_UNBOUND" in codes(errors)
        emit("ehp04_receipt_tamper", "PASS" if tamper_ok else "FAIL", codes=codes(errors))
    return local_ok and receipt_ok and tamper_ok


def probe_vectors() -> bool:
    matrix_path = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R3/05-atomic-bundle-prototype/acceptance-test-matrix.json"
    test_path = ROOT / "test/up1_external_closure_r3/atomic_bundle/test_atomic_bundle_repair.py"
    matrix = json.loads(matrix_path.read_text(encoding="utf-8"))
    vectors = {row["id"]: row["expected"] for row in matrix["vectors"]}
    source = test_path.read_text(encoding="utf-8")
    placeholder = '"mutation": f"R{i:02d}"'
    uniform_expected = 'expected = {vector_id: ("rejected_all", "SCHEMA_INVALID") for vector_id in builders}'
    static_placeholder = placeholder in source and uniform_expected in source
    receipts = []
    failures = []
    for vector_id, expected in vectors.items():
        raw = json.dumps({"schema": "UP1.external-handoff.atomic-response-bundle.v1", "mutation": vector_id}, separators=(",", ":")).encode()
        result = validate_bundle(raw)
        expected_code = expected.split("/", 1)[0]
        actual = {"decision": result["decision"], "codes": result["failure_codes"]}
        builder_path = "mutation" if vector_id.startswith("R") else "independent_review"
        receipts.append({"id": vector_id, "builder_path": builder_path, "raw_sha256": sha256(raw),
                         "expected": expected, "actual": actual})
        if expected_code not in result["failure_codes"] or result["decision"] != "rejected_all":
            failures.append(vector_id)
    ok = not static_placeholder and not failures
    emit("R01-R25-D01_builders", "PASS" if ok else "FAIL", static_placeholder=static_placeholder,
         distinct_builder_paths=sorted({x["builder_path"] for x in receipts}), failures=failures,
         receipts=receipts)
    return ok


def main() -> int:
    outcomes = {
        "hardlink": probe_hardlink(),
        "reparse": probe_reparse(),
        "g2": probe_g2(),
        "decision_test_only": probe_decision_and_test_only(),
        "ehp04": probe_ehp04(),
        "vectors": probe_vectors(),
    }
    failed = sorted(k for k, value in outcomes.items() if not value)
    emit("summary", "PASS" if not failed else "FAIL", conclusion="pass_limited" if not failed else "fail_limited",
         authority_credit=False, formal_credit="none", no_publish=True, failed=failed,
         outcomes=outcomes)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
