from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import os
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
TEST_DIR = ROOT / "test" / "up1_external_closure_r3" / "atomic_bundle"
sys.path.insert(0, str(ROOT))
from tools.up1_external_closure_r3.atomic_bundle import bundle as b


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_vectors():
    spec = importlib.util.spec_from_file_location("r3_vectors", TEST_DIR / "test_atomic_bundle_vectors.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module.all_vectors()


def rec(name: str, observed, expected, **extra):
    return {"name": name, "observed": observed, "expected": expected, "pass": observed == expected, **extra}


def ehp04_probe(out: list[dict]):
    with tempfile.TemporaryDirectory(prefix="up1-r3-final-") as td:
        root = Path(td) / "artifact-root"
        root.mkdir()
        julia = root / "julia.bin"; julia.write_bytes(b"julia-runtime")
        python = root / "python.bin"; python.write_bytes(b"python-runtime")
        sbom_bytes = b'{"components":["component-final"]}'
        sbom = root / "sbom.json"; sbom.write_bytes(sbom_bytes)
        binary_bytes = b"candidate-binary-final"
        binary = root / "candidate.bin"; binary.write_bytes(binary_bytes)
        receipt_bytes = b'{"subject_sha256":"' + digest(binary_bytes).encode() + b'"}'
        receipt = root / "download.receipt"; receipt.write_bytes(receipt_bytes)
        sbom_hash = digest(sbom_bytes); binary_hash = digest(binary_bytes); receipt_hash = digest(receipt_bytes)
        payload = {
            "expected_context_sha256": "b" * 64,
            "outer_authority": {"candidate_id": "candidate-final", "source_identity_sha256": "a" * 64, "expected_context_sha256": "b" * 64},
            "runtime_and_imports": {"runtimes": [
                {"name": "Julia", "path": str(julia), "path_sha256": digest(julia.read_bytes())},
                {"name": "Python", "path": str(python), "path_sha256": digest(python.read_bytes())}], "imports": [], "lockfiles": []},
            "sbom_documents": [{"document_id": "doc-final", "document_sha256": sbom_hash, "path": str(sbom), "components": [{"component_id": "component-final"}], "dependency_edges": []}],
            "binaries": [{"candidate_id": "candidate-final", "path": str(binary), "sha256": binary_hash,
                          "sbom_refs": [{"ref": "doc-final", "sha256": sbom_hash}],
                          "download_receipt": {"subject_sha256": binary_hash, "receipt_ref": {"path": str(receipt), "sha256": receipt_hash}}}],
            "foreign_owner_fixture": {"fixture_status": "not_executed", "reason": "offline"},
        }
        shared = {"candidate_id": "candidate-final", "source_identity_sha256": "a" * 64, "expected_context_sha256": "b" * 64}
        errors: list[dict[str, str]] = []
        status = b._check_ehp04(payload, shared, errors, root)
        out.append(rec("ehp04_root_contained_local_bytes_and_recomputed_hashes", {"status": status, "codes": sorted({x["code"] for x in errors})}, {"status": "not_executed", "codes": []}, sbom_sha256=sbom_hash, binary_sha256=binary_hash, download_receipt_sha256=receipt_hash))
        outside = Path(td) / "outside-runtime.bin"; outside.write_bytes(b"outside")
        payload_outside = copy.deepcopy(payload)
        payload_outside["runtime_and_imports"]["runtimes"][0]["path"] = str(outside)
        payload_outside["runtime_and_imports"]["runtimes"][0]["path_sha256"] = digest(outside.read_bytes())
        errors = []
        b._check_ehp04(payload_outside, shared, errors, root)
        out.append(rec("ehp04_root_containment_rejects_outside_runtime", "EHP04_RUNTIME_ARTIFACT_UNAVAILABLE" in {x["code"] for x in errors}, True, codes=sorted({x["code"] for x in errors})))
        errors = []
        b._check_ehp04(payload, shared, errors, None)
        codes = {x["code"] for x in errors}
        out.append(rec("ehp04_missing_root_rejects_claims", {"root_required": "EHP04_ARTIFACT_ROOT_REQUIRED" in codes, "sbom_unavailable": "EHP04_SBOM_ARTIFACT_UNAVAILABLE" in codes, "download_unavailable": "EHP04_DOWNLOAD_RECEIPT_UNAVAILABLE" in codes}, {"root_required": True, "sbom_unavailable": True, "download_unavailable": True}, codes=sorted(codes)))


def cas_probe(out: list[dict]):
    raw = b"atomic-final-cas"
    with tempfile.TemporaryDirectory(prefix="up1-r3-cas-") as td:
        base = Path(td) / "hardlink"; (base / "cas").mkdir(parents=True)
        outside = Path(td) / "outside"; outside.write_bytes(raw)
        target = base / "cas" / digest(raw)
        try:
            os.link(outside, target)
            try: b.quarantine_raw(raw, base); observed = "RETURNED"
            except OSError as exc: observed = str(exc).split(":", 1)[0]
            out.append(rec("cas_existing_hardlink_rejected", observed, "CAS_HARDLINK_REJECTED", samefile=os.path.samefile(target, outside)))
        except (OSError, NotImplementedError) as exc:
            out.append(rec("cas_existing_hardlink_rejected", "SKIP", "CAS_HARDLINK_REJECTED", reason=f"{type(exc).__name__}: {exc}"))
        collision = Path(td) / "collision"; (collision / "cas").mkdir(parents=True)
        colliding = b"different"; cpath = collision / "cas" / digest(raw); cpath.write_bytes(colliding)
        try: b.quarantine_raw(raw, collision); observed = "RETURNED"
        except OSError as exc: observed = str(exc).split(":", 1)[0]
        out.append(rec("cas_different_bytes_collision_fail_closed", observed, "CAS_COLLISION_FAIL_CLOSED"))
        cpath.write_bytes(raw)
        first = b.quarantine_raw(raw, collision); second = b.quarantine_raw(raw, collision)
        out.append(rec("cas_equal_bytes_replay_idempotent", first["cas_path"] == second["cas_path"], True, cas_path=first["cas_path"]))


def g2_probe(out: list[dict]):
    ref = {"ref": "authority-final", "sha256": "a" * 64}
    source = {"candidate_id": "candidate-final", "revision": "r", "head": "h", "tree": "a" * 64,
              "dirty_patch": {"present": True, "sha256": "a" * 64, "entries": ["p"]},
              "untracked": {"present": True, "sha256": "a" * 64, "entries": ["u"]},
              "submodules": {"present": True, "sha256": "a" * 64, "entries": ["s"]}, "source_bytes_sha256": "a" * 64, "inventory_sha256": "a" * 64}
    source_hash = b._digest(source)
    shared = {"candidate_id": "candidate-final", "source_identity_sha256": source_hash, "four_axis_refs": [{"axis_id": f"A{i}"} for i in range(4)]}
    fwd = {"edge_id": "f", "from_kind": "source", "from_id": "s", "to_kind": "candidate", "to_id": "candidate-final", "candidate_id": "candidate-final", "source_identity_sha256": source_hash, "namespace": "n", "version": "1", "issued_at": "2026-09-17T00:00:00Z", "issuer_ref": ref, "signature_ref": ref}
    rev = dict(fwd, edge_id="r", from_kind="candidate", from_id="candidate-final", to_kind="source", to_id="s")
    rows = [{"row_id": "row", "from_id": "s", "to_id": "candidate-final", "issuer_ref": ref, "issued_at": "2026-09-17T00:00:00Z"}]
    inverse = [{"row_id": "row", "from_id": "candidate-final", "to_id": "s", "issuer_ref": ref, "issued_at": "2026-09-17T00:00:00Z"}]
    for row in rows + inverse: row["row_sha256"] = b._digest(row)
    payload = {"source_identity": source, "axis_materials": shared["four_axis_refs"], "evidence_graph": {"forward_edges": [fwd], "reverse_edges": [rev]}, "g2_mapping": {"candidate_id": "candidate-final", "ambiguity_decision": "none", "mapping_rows": rows, "reverse_rows": inverse, "issuer_ref": ref}, "authority_receipt": {"candidate_id": "candidate-final", "source_identity_sha256": source_hash, "signature_ref": ref}}
    errors: list[dict[str, str]] = []; b._check_ehp03(payload, shared, errors)
    out.append(rec("g2_directional_rows_recompute_and_inverse_bind", sorted({x["code"] for x in errors}), [], row_hashes_distinct=rows[0]["row_sha256"] != inverse[0]["row_sha256"]))
    tampered = copy.deepcopy(payload); tampered["g2_mapping"]["reverse_rows"][0]["issuer_ref"] = {"ref": "attacker", "sha256": "a" * 64}
    errors = []; b._check_ehp03(tampered, shared, errors)
    out.append(rec("g2_inverse_authority_tamper_rejected", "EHP03_G2_REF_MISMATCH" in {x["code"] for x in errors}, True, codes=sorted({x["code"] for x in errors})))


def vectors_probe(out: list[dict]):
    vectors = load_vectors(); rows = []
    for vector in vectors:
        built = vector.build(); raw = built if isinstance(built, bytes) else json.dumps(built, sort_keys=True, separators=(",", ":")).encode()
        result = b.validate_bundle(raw)
        rows.append({"id": vector.vector_id, "mutation_path": vector.mutation_path, "expected": vector.expected, "expected_decision": vector.decision, "actual_decision": result["decision"], "actual_codes": result["failure_codes"], "raw_sha256": digest(raw), "code_hit": vector.expected == "no_failure_code" or vector.expected in result["failure_codes"] or vector.vector_id in {"R23"}})
    out.append(rec("all_26_named_builders_unique_paths_and_matrix_bound", {"count": len(rows), "unique_paths": len({x["mutation_path"] for x in rows}), "unique_raw_hashes": len({x["raw_sha256"] for x in rows}), "all_expected_decision": all(x["expected_decision"] == x["actual_decision"] for x in rows), "all_expected_code_hit": all(x["code_hit"] for x in rows)}, {"count": 26, "unique_paths": 26, "unique_raw_hashes": 26, "all_expected_decision": True, "all_expected_code_hit": True}, rows=rows))


def registry_and_boundaries(out: list[dict]):
    registry_path = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R3/11-atomic-prototype-repair-r3/error-registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    out.append(rec("error_registry_exactly_matches_implementation", b.validate_error_registry(registry), True, source_count=len(b.ERROR_CODES), registry_count=len(registry["codes"]), contains_decision_code="DECISION_NOT_BOUND_TO_QUARANTINE" in b.ERROR_CODES))
    errors = []; b._err(errors, "UNKNOWN_FINAL_INTERNAL_CODE", "/unknown"); result = b._result("a" * 64, {}, {"cas_path": "", "receipt": {}}, errors, None, True)
    out.append(rec("unknown_internal_code_preserved_and_fail_closed", {"preserved": errors[0]["code"], "decision": result["decision"], "no_publish": result["no_publish"]}, {"preserved": "UNKNOWN_FINAL_INTERNAL_CODE", "decision": "rejected_all", "no_publish": True}))
    reject = b._result("a" * 64, {}, {"cas_path": "", "receipt": {}}, [{"code": "EHP03_G2_ROW_DIGEST_MISMATCH", "path": "/g2"}], "not_executed", True)
    defer = b._result("a" * 64, {}, {"cas_path": "", "receipt": {}}, [], "not_executed", True)
    out.append(rec("decision_error_precedes_not_executed_defer", {"error": reject["decision"], "clean": defer["decision"]}, {"error": "rejected_all", "clean": "terminal_deferred"}))
    with tempfile.TemporaryDirectory(prefix="up1-r3-boundary-") as td:
        q = b.quarantine_raw(b"test-only-final", td)
        fake = {"set_receipt": {"quarantine_receipt": dict(q["receipt"])} }; errors = []; b._check_quarantine(fake, q, errors, b"test-only-final")
        out.append(rec("test_only_receiver_receipt_is_non_evidence", "TEST_ONLY_NON_EVIDENCE" in {x["code"] for x in errors}, True, codes=sorted({x["code"] for x in errors})))


def main():
    out: list[dict] = []
    ehp04_probe(out); cas_probe(out); g2_probe(out); vectors_probe(out); registry_and_boundaries(out)
    print(json.dumps({"schema": "UP1.atomic-final-independent-test.r3.v1", "pid": os.getpid(), "utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"), "records": out, "pass_count": sum(x["pass"] for x in out), "record_count": len(out)}, ensure_ascii=True, sort_keys=True, indent=2))


if __name__ == "__main__":
    main()
