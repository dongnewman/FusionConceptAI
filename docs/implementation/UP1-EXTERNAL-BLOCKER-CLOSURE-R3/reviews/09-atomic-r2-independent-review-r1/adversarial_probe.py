from __future__ import annotations

import ast
import hashlib
import json
import os
import re
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

from tools.up1_external_closure_r3.atomic_bundle import bundle as b


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]


def digest_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def record(name: str, observed: object, expected: object, **extra: object) -> dict[str, object]:
    return {"name": name, "observed": observed, "expected": expected, "pass": observed == expected, **extra}


def g2_payload() -> tuple[dict[str, object], dict[str, object]]:
    shared: dict[str, object] = {"candidate_id": "candidate-r3", "source_identity_sha256": "", "four_axis_refs": [{"axis_id": f"A{i}"} for i in range(4)]}
    source: dict[str, object] = {"candidate_id": "candidate-r3", "revision": "r", "head": "h", "tree": "a" * 64,
        "dirty_patch": {"present": True, "sha256": "a" * 64, "entries": ["p"]},
        "untracked": {"present": True, "sha256": "a" * 64, "entries": ["u"]},
        "submodules": {"present": True, "sha256": "a" * 64, "entries": ["s"]},
        "source_bytes_sha256": "a" * 64, "inventory_sha256": "a" * 64}
    shared["source_identity_sha256"] = b._digest(source)
    auth_ref = {"ref": "authority-signature", "sha256": "a" * 64}
    issued = "2026-09-17T00:00:00Z"
    fwd = {"edge_id": "edge-forward", "from_kind": "source", "from_id": "source-r3", "to_kind": "candidate", "to_id": "candidate-r3",
        "candidate_id": "candidate-r3", "source_identity_sha256": shared["source_identity_sha256"], "namespace": "r3", "version": "1",
        "issued_at": issued, "issuer_ref": auth_ref, "signature_ref": auth_ref}
    rev = {"edge_id": "edge-reverse", "from_kind": "candidate", "from_id": "candidate-r3", "to_kind": "source", "to_id": "source-r3",
        "candidate_id": "candidate-r3", "source_identity_sha256": shared["source_identity_sha256"], "namespace": "r3", "version": "1",
        "issued_at": issued, "issuer_ref": auth_ref, "signature_ref": auth_ref}
    graph = {"forward_edges": [fwd], "reverse_edges": [rev]}
    mapping_rows = [{"row_id": "row-1", "from_id": "source-r3", "to_id": "candidate-r3", "issuer_ref": auth_ref, "issued_at": issued}]
    reverse_rows = [{"row_id": "row-1", "from_id": "candidate-r3", "to_id": "source-r3", "issuer_ref": auth_ref, "issued_at": issued}]
    for row in mapping_rows + reverse_rows:
        row["row_sha256"] = b._digest({k: v for k, v in row.items() if k != "row_sha256"})
    payload = {"source_identity": source, "axis_materials": shared["four_axis_refs"], "evidence_graph": graph,
        "g2_mapping": {"candidate_id": "candidate-r3", "ambiguity_decision": "none", "mapping_rows": mapping_rows,
                        "reverse_rows": reverse_rows, "issuer_ref": auth_ref},
        "authority_receipt": {"candidate_id": "candidate-r3", "source_identity_sha256": shared["source_identity_sha256"],
                              "signature_ref": auth_ref, "graph_sha256": b._digest(graph)}}
    return payload, shared


def run() -> dict[str, object]:
    out: list[dict[str, object]] = []
    raw = b"atomic-r3-hardlink"
    with tempfile.TemporaryDirectory(prefix="up1-r3-review-") as td:
        tmp = Path(td)
        root = tmp / "q"
        (root / "cas").mkdir(parents=True)
        outside = tmp / "outside-object"
        outside.write_bytes(raw)
        cas = root / "cas" / digest_bytes(raw)
        hardlink_available = True
        try:
            os.link(outside, cas)
        except (OSError, NotImplementedError) as exc:
            hardlink_available = False
            out.append(record("cas_existing_hardlink", "SKIP", "CAS_HARDLINK_REJECTED", reason=f"{type(exc).__name__}: {exc}"))
        if hardlink_available:
            try:
                b.quarantine_raw(raw, root)
                observed = "RETURNED"
            except OSError as exc:
                observed = str(exc)
            out.append(record("cas_existing_hardlink", observed, "CAS_HARDLINK_REJECTED", samefile=cas.exists() and os.path.samefile(cas, outside)))

        collision = b"collision-r3"
        collision_root = tmp / "collision"
        (collision_root / "cas").mkdir(parents=True)
        collision_path = collision_root / "cas" / digest_bytes(collision)
        collision_path.write_bytes(b"different")
        try:
            b.quarantine_raw(collision, collision_root)
            observed = "RETURNED"
        except OSError as exc:
            observed = str(exc)
        out.append(record("cas_different_bytes_collision", observed, "CAS_COLLISION_FAIL_CLOSED"))
        collision_path.write_bytes(collision)
        first = b.quarantine_raw(collision, collision_root)
        second = b.quarantine_raw(collision, collision_root)
        out.append(record("cas_equal_bytes_idempotence", first["cas_path"] == second["cas_path"], True, cas_path=first["cas_path"]))

        # A receipt name is predictable when uuid4 is pinned; its existing hardlink
        # must be rejected by the same identity check as a CAS object.
        receipt_root = tmp / "receipt-hardlink"
        (receipt_root / "cas").mkdir(parents=True)
        receipt_root.joinpath("receipt-outside").write_bytes(b"receipt-placeholder")
        class FixedUUID:
            hex = "1" * 32
            def __str__(self) -> str:
                return "11111111-1111-1111-1111-111111111111"
        receipt_target = receipt_root / "receipts" / (str(FixedUUID()) + ".json")
        receipt_target.parent.mkdir()
        os.link(receipt_root / "receipt-outside", receipt_target)
        with patch.object(b.uuid, "uuid4", return_value=FixedUUID()):
            try:
                b.quarantine_raw(b"receipt-hardlink", receipt_root)
                observed = "RETURNED"
            except OSError as exc:
                observed = str(exc)
        out.append(record("receipt_existing_hardlink", observed, "CAS_HARDLINK_REJECTED", samefile=os.path.samefile(receipt_target, receipt_root / "receipt-outside")))

        # Existing symlink components are rejected before traversal/creation.
        symlink_root = tmp / "symlink-target"
        symlink_root.mkdir()
        symlink = tmp / "symlink-root"
        try:
            os.symlink(symlink_root, symlink, target_is_directory=True)
        except (OSError, NotImplementedError) as exc:
            out.append(record("reparse_root_before_mkdir", "SKIP", "CAS_REPARSE_POINT_REJECTED", reason=f"{type(exc).__name__}: {exc}"))
        else:
            try:
                b.quarantine_raw(b"reparse-r3", symlink)
                observed = "RETURNED"
            except OSError as exc:
                observed = str(exc)
            out.append(record("reparse_root_before_mkdir", observed, "CAS_REPARSE_POINT_REJECTED"))

        payload, shared = g2_payload()
        errors: list[dict[str, str]] = []
        b._check_ehp03(payload, shared, errors)
        out.append(record("ehp03_directional_g2_positive", sorted({e["code"] for e in errors}), [], row_hashes_distinct=payload["g2_mapping"]["mapping_rows"][0]["row_sha256"] != payload["g2_mapping"]["reverse_rows"][0]["row_sha256"]))
        tampered = json.loads(json.dumps(payload))
        tampered["g2_mapping"]["reverse_rows"][0]["issuer_ref"] = {"ref": "attacker", "sha256": "a" * 64}
        errors = []
        b._check_ehp03(tampered, shared, errors)
        out.append(record("ehp03_inverse_issuer_tamper", "EHP03_G2_REF_MISMATCH" in {e["code"] for e in errors}, True, codes=sorted({e["code"] for e in errors})) )

        out.append(record("decision_error_precedes_fixture_defer", b._result("a" * 64, {}, {"cas_path": "", "receipt": {}}, [{"code": "EHP03_G2_ROW_DIGEST_MISMATCH", "path": "/g2"}], "not_executed", True)["decision"], "rejected_all"))
        out.append(record("decision_clean_not_executed_defers", b._result("a" * 64, {}, {"cas_path": "", "receipt": {}}, [], "not_executed", True)["decision"], "terminal_deferred"))

        q = b.quarantine_raw(b"receiver-r3", tmp / "receiver")
        fake = {"set_receipt": {"quarantine_receipt": dict(q["receipt"])}}
        errors = []
        b._check_quarantine(fake, q, errors, b"receiver-r3")
        out.append(record("test_only_receiver_non_evidence", "TEST_ONLY_NON_EVIDENCE" in {e["code"] for e in errors}, True, codes=sorted({e["code"] for e in errors})))

        artifact_root = tmp / "artifacts"
        artifact_root.mkdir()
        inside_julia = artifact_root / "julia.bin"; inside_julia.write_bytes(b"julia")
        inside_python = artifact_root / "python.bin"; inside_python.write_bytes(b"python")
        outside_runtime = tmp / "outside-runtime.bin"; outside_runtime.write_bytes(b"outside")
        runtime_payload = {"expected_context_sha256": "a" * 64, "outer_authority": {"candidate_id": "candidate-r3", "source_identity_sha256": "a" * 64, "expected_context_sha256": "a" * 64},
            "runtime_and_imports": {"runtimes": [{"name": "Julia", "path": str(inside_julia), "path_sha256": digest_bytes(b"julia")}, {"name": "Python", "path": str(inside_python), "path_sha256": digest_bytes(b"python")}], "imports": [], "lockfiles": []}, "sbom_documents": [], "binaries": [], "foreign_owner_fixture": {"fixture_status": "not_executed"}}
        errors = []
        b._check_ehp04(runtime_payload, {"candidate_id": "candidate-r3", "source_identity_sha256": "a" * 64, "expected_context_sha256": "a" * 64}, errors, artifact_root)
        out.append(record("ehp04_contained_runtime_bytes", "EHP04_RUNTIME_ARTIFACT_UNAVAILABLE" in {e["code"] for e in errors}, False, codes=sorted({e["code"] for e in errors})))
        runtime_payload["runtime_and_imports"]["runtimes"][0]["path"] = str(outside_runtime)
        runtime_payload["runtime_and_imports"]["runtimes"][0]["path_sha256"] = digest_bytes(b"outside")
        errors = []
        b._check_ehp04(runtime_payload, {"candidate_id": "candidate-r3", "source_identity_sha256": "a" * 64, "expected_context_sha256": "a" * 64}, errors, artifact_root)
        out.append(record("ehp04_runtime_outside_declared_root", "EHP04_RUNTIME_ARTIFACT_UNAVAILABLE" in {e["code"] for e in errors}, True, codes=sorted({e["code"] for e in errors})))
        errors = []
        b._check_ehp04(runtime_payload, {"candidate_id": "candidate-r3", "source_identity_sha256": "a" * 64, "expected_context_sha256": "a" * 64}, errors, None)
        out.append(record("ehp04_no_root_context_rejects_outside_bytes", "EHP04_RUNTIME_ARTIFACT_UNAVAILABLE" in {e["code"] for e in errors}, True, codes=sorted({e["code"] for e in errors})))

    matrix_path = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R3/05-atomic-bundle-prototype/acceptance-test-matrix.json"
    repair_test = ROOT / "test/up1_external_closure_r3/atomic_bundle/test_atomic_bundle_repair.py"
    matrix = json.loads(matrix_path.read_text(encoding="utf-8"))
    non_schema_expected = [v["id"] for v in matrix["vectors"] if "SCHEMA_INVALID" not in v["expected"]]
    repair_text = repair_test.read_text(encoding="utf-8")
    out.append(record("vector_builder_source_has_one_comprehension", repair_text.count("for i in range(1, 26)"), 1))
    out.append(record("vector_matrix_semantic_expected_codes", len(non_schema_expected), 25, ids=non_schema_expected))
    out.append(record("vector_test_expected_all_schema_invalid", "expected = {vector_id: (\"rejected_all\", \"SCHEMA_INVALID\") for vector_id in builders}" in repair_text, False))

    registry = json.loads((ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R3/07-atomic-prototype-repair-r1/error-registry.json").read_text(encoding="utf-8"))
    out.append(record("error_registry_exact_source_set", sorted(b.ERROR_CODES - set(registry["codes"])), [], source_count=len(b.ERROR_CODES), registry_count=len(registry["codes"])))
    unknown_calls = sorted(set(re.findall(r'_err\(errors,\s*"([A-Z0-9_]+)"', (ROOT / "tools/up1_external_closure_r3/atomic_bundle/bundle.py").read_text(encoding="utf-8")))-set(b.ERROR_CODES))
    out.append(record("error_calls_all_registered", unknown_calls, [], unknown_calls=unknown_calls))

    frozen = {}
    for rel in ["tools/up1_external_closure_r3/atomic_bundle/bundle.py", "tools/up1_external_closure_r3/atomic_bundle/canonical.py", "test/up1_external_closure_r3/atomic_bundle/test_atomic_bundle.py", "test/up1_external_closure_r3/atomic_bundle/test_atomic_bundle_repair.py", "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R3/05-atomic-bundle-prototype/acceptance-test-matrix.json", "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R3/07-atomic-prototype-repair-r1/error-registry.json", "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R3/08-atomic-repair-independent-test/README.md", "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R3/reviews/07-atomic-prototype-repair-independent-review-r1/review.md"]:
        p = ROOT / rel
        frozen[rel] = {"sha256": digest_bytes(p.read_bytes()), "size": p.stat().st_size}
    return {"schema": "UP1.atomic-r2-independent-review-r1.probe.v1", "pid": os.getpid(), "utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"), "records": out, "frozen_inputs": frozen}


if __name__ == "__main__":
    print(json.dumps(run(), ensure_ascii=True, sort_keys=True, indent=2))
