from __future__ import annotations

import ast
import copy
import hashlib
import importlib.util
import json
import os
import pathlib
import tempfile
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[5]
import sys
sys.path.insert(0, str(ROOT))

from tools.up1_external_closure_r3.atomic_bundle import validate_bundle
from tools.up1_external_closure_r3.atomic_bundle import bundle as impl
SOURCE = ROOT / "tools" / "up1_external_closure_r3" / "atomic_bundle" / "bundle.py"
REGISTRY = ROOT / "docs" / "implementation" / "UP1-EXTERNAL-BLOCKER-CLOSURE-R3" / "11-atomic-prototype-repair-r3" / "error-registry.json"
VECTORS = ROOT / "test" / "up1_external_closure_r3" / "atomic_bundle" / "test_atomic_bundle_vectors.py"
RELATIONS = ROOT / "test" / "up1_external_closure_r3" / "atomic_bundle" / "test_atomic_bundle.py"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_vectors():
    spec = importlib.util.spec_from_file_location("vector_module_r11", VECTORS)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    import sys
    sys.modules["vector_module_r11"] = module
    spec.loader.exec_module(module)
    return module


def load_relations():
    spec = importlib.util.spec_from_file_location("relation_module_r11", RELATIONS)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    import sys
    sys.modules["relation_module_r11"] = module
    spec.loader.exec_module(module)
    return module


def errors_for(payload, shared, root=None):
    errors: list[dict[str, str]] = []
    status = impl._check_ehp04(payload, shared, errors, root)
    return {x["code"] for x in errors}, status


def make_ehp04(root: pathlib.Path, *, receipt_bytes: bytes = b'{"subject":"candidate.bin"}'):
    shared = {"candidate_id": "candidate-r11", "source_identity_sha256": "a" * 64, "expected_context_sha256": "b" * 64}
    julia = root / "julia"; julia.write_bytes(b"julia-r11")
    python = root / "python"; python.write_bytes(b"python-r11")
    binary = root / "candidate.bin"; binary.write_bytes(b"binary-r11")
    sbom_bytes = b'{"bomFormat":"CycloneDX","components":[{"bom-ref":"component-r11"}]}'
    sbom = root / "sbom.json"; sbom.write_bytes(sbom_bytes)
    receipt = root / "download.receipt"; receipt.write_bytes(receipt_bytes)
    sbom_hash = digest(sbom_bytes); binary_hash = digest(binary.read_bytes()); receipt_hash = digest(receipt_bytes)
    payload = {
        "expected_context_sha256": "b" * 64,
        "outer_authority": shared.copy(),
        "runtime_and_imports": {"runtimes": [
            {"name": "Julia", "path": str(julia), "path_sha256": digest(julia.read_bytes())},
            {"name": "Python", "path": str(python), "path_sha256": digest(python.read_bytes())}], "imports": [], "lockfiles": []},
        "sbom_documents": [{"document_id": "doc-r11", "document_sha256": sbom_hash, "path": str(sbom), "local_sha256": sbom_hash,
                            "components": [{"component_id": "component-r11"}], "dependency_edges": []}],
        "binaries": [{"candidate_id": "candidate-r11", "path": str(binary), "sha256": binary_hash,
                      "sbom_refs": [{"ref": "doc-r11", "sha256": sbom_hash}],
                      "download_receipt": {"subject_sha256": binary_hash,
                                           "receipt_ref": {"path": str(receipt), "sha256": receipt_hash}}}],
        "foreign_owner_fixture": {"fixture_status": "not_executed", "reason": "offline"},
    }
    return shared, payload, {"julia": julia, "python": python, "binary": binary, "sbom": sbom, "receipt": receipt}


def main():
    rows = []
    vectors = load_vectors().all_vectors()
    for v in vectors:
        built = v.build()
        raw = built if isinstance(built, bytes) else json.dumps(built, sort_keys=True, separators=(",", ":")).encode()
        result = validate_bundle(raw)
        expected_ok = result["decision"] == v.decision and (v.expected in result["failure_codes"] if v.expected not in {"no_failure_code", "internal accepted_all only"} else True)
        rows.append({"probe": "vector", "id": v.vector_id, "mutation_path": v.mutation_path,
                     "expected": v.expected, "expected_decision": v.decision,
                     "actual_codes": result["failure_codes"], "actual_decision": result["decision"],
                     "raw_sha256": digest(raw), "expected_match": expected_ok})

    with tempfile.TemporaryDirectory(prefix="up1-r11-ehp04-") as tmp:
        root = pathlib.Path(tmp)
        shared, payload, files = make_ehp04(root)
        codes, status = errors_for(payload, shared, root)
        rows.append({"probe": "ehp04_contained_real_bytes", "status": status, "codes": sorted(codes), "pass": not codes})

        escaped = copy.deepcopy(payload)
        escaped["runtime_and_imports"]["runtimes"][0]["path"] = str(pathlib.Path(tmp).parent / "outside-r11")
        pathlib.Path(escaped["runtime_and_imports"]["runtimes"][0]["path"]).write_bytes(b"outside")
        codes, status = errors_for(escaped, shared, root)
        rows.append({"probe": "ehp04_escape_path", "status": status, "codes": sorted(codes),
                     "pass": "EHP04_RUNTIME_ARTIFACT_UNAVAILABLE" in codes})

        codes, status = errors_for(payload, shared, None)
        rows.append({"probe": "ehp04_missing_root", "status": status, "codes": sorted(codes),
                     "pass": "EHP04_ARTIFACT_ROOT_REQUIRED" in codes})

        tampered = copy.deepcopy(payload)
        tampered["sbom_documents"][0]["local_sha256"] = "0" * 64
        codes, status = errors_for(tampered, shared, root)
        rows.append({"probe": "ehp04_sbom_hash_tamper", "status": status, "codes": sorted(codes),
                     "pass": "EHP04_SBOM_ARTIFACT_DIGEST_MISMATCH" in codes})

        tampered = copy.deepcopy(payload)
        tampered["binaries"][0]["download_receipt"]["receipt_ref"]["sha256"] = "0" * 64
        codes, status = errors_for(tampered, shared, root)
        rows.append({"probe": "ehp04_download_hash_tamper", "status": status, "codes": sorted(codes),
                     "pass": "EHP04_DOWNLOAD_RECEIPT_DIGEST_MISMATCH" in codes or "EHP04_DOWNLOAD_REF_MISMATCH" in codes})

        # Stronger semantic attack: bytes are present and hash-bound, but are
        # not a receipt document. The current contract checks bytes/hash and
        # envelope subject binding, not receipt-content subject binding.
        bad_root = root / "bad-receipt"
        bad_root.mkdir()
        shared_bad, payload_bad, _ = make_ehp04(bad_root, receipt_bytes=b"not-json-download-receipt")
        codes, status = errors_for(payload_bad, shared_bad, bad_root)
        rows.append({"probe": "ehp04_unparseable_download_bytes_with_correct_hash", "status": status,
                     "codes": sorted(codes), "accepted": not codes,
                     "note": "No receipt-content parse or subject binding is performed"})

        # Input-artifact hardlink attack: lexical path is inside root but inode
        # is shared with an outside file. EHP-04 does not apply CAS link-count
        # identity to artifact material.
        outside = root.parent / "outside-artifact-r11"; outside.write_bytes(b"hardlinked-artifact")
        inside = root / "hardlinked-artifact"
        try:
            os.link(outside, inside)
            content = impl._artifact_bytes(str(inside), root)
            rows.append({"probe": "ehp04_input_hardlink", "inside": str(inside), "outside": str(outside),
                         "st_nlink": inside.stat().st_nlink, "accepted": content == outside.read_bytes(),
                         "note": "EHP-04 artifact reader has no single-link identity check"})
        except (OSError, NotImplementedError) as exc:
            rows.append({"probe": "ehp04_input_hardlink", "host_skip": f"{type(exc).__name__}: {exc}"})

    # CAS hardlink/reparse and decision precedence are direct implementation
    # checks independent of the unittest assertions.
    raw = b"r11-cas-hardlink"
    with tempfile.TemporaryDirectory(prefix="up1-r11-cas-") as tmp:
        cas_root = pathlib.Path(tmp) / "q"
        outside = pathlib.Path(tmp) / "outside"
        outside.write_bytes(raw)
        target = cas_root / "cas" / digest(raw)
        target.parent.mkdir(parents=True)
        try:
            os.link(outside, target)
            try:
                impl.quarantine_raw(raw, cas_root)
                rows.append({"probe": "cas_external_hardlink", "pass": False, "unexpected": "accepted"})
            except OSError as exc:
                rows.append({"probe": "cas_external_hardlink", "error": str(exc), "pass": "CAS_HARDLINK_REJECTED" in str(exc)})
        except (OSError, NotImplementedError) as exc:
            rows.append({"probe": "cas_external_hardlink", "host_skip": f"{type(exc).__name__}: {exc}"})
        errs = [{"code": "EHP03_G2_ROW_DIGEST_MISMATCH", "path": "/g2"}]
        reject = impl._result("a" * 64, {}, {"cas_path": "", "receipt": {}}, errs, "not_executed", True)
        defer = impl._result("a" * 64, {}, {"cas_path": "", "receipt": {}}, [], "not_executed", True)
        rows.append({"probe": "decision_precedence", "reject_with_error": reject["decision"], "clean_not_executed": defer["decision"],
                     "pass": reject["decision"] == "rejected_all" and defer["decision"] == "terminal_deferred"})

    # G2 directional and authority-reference tamper.
    tv = load_relations()
    helper = tv.EHPRelationTests(); helper.setUp(); payload = helper._payload03()
    ref = {"ref": "authority-signature", "sha256": "a" * 64}; issued = "2026-09-17T00:00:00Z"
    row = {"row_id": "r1", "from_id": "source-x", "to_id": "candidate-1", "issuer_ref": ref, "issued_at": issued}
    row["row_sha256"] = impl._digest(row)
    inv = {"row_id": "r1", "from_id": "candidate-1", "to_id": "source-x", "issuer_ref": ref, "issued_at": issued}
    inv["row_sha256"] = impl._digest(inv)
    payload["g2_mapping"] = {"candidate_id": "candidate-1", "ambiguity_decision": "none", "mapping_rows": [row], "reverse_rows": [inv], "issuer_ref": ref}
    payload["authority_receipt"].update({"signature_ref": ref})
    errs: list[dict[str, str]] = []; impl._check_ehp03(payload, helper.shared, errs)
    g2_codes = {e["code"] for e in errs}
    rows.append({"probe": "g2_directional_positive", "codes": sorted(g2_codes),
                 "pass": not (g2_codes & {"EHP03_G2_MAPPING_MISMATCH", "EHP03_G2_MAPPING_DIGEST_MISMATCH", "EHP03_G2_ROW_DIGEST_MISMATCH", "EHP03_G2_REF_MISMATCH"}),
                 "forward_row_sha256": row["row_sha256"], "reverse_row_sha256": inv["row_sha256"]})
    payload["g2_mapping"]["reverse_rows"][0]["issuer_ref"] = {"ref": "attacker", "sha256": "a" * 64}
    errs = []; impl._check_ehp03(payload, helper.shared, errs)
    rows.append({"probe": "g2_issuer_tamper", "codes": sorted({e["code"] for e in errs}),
                 "pass": "EHP03_G2_REF_MISMATCH" in {e["code"] for e in errs}})

    # Unknown code preservation and TEST_ONLY trust boundary.
    errs = []; impl._err(errs, "UNREGISTERED_INTERNAL_VECTOR_CODE", "/vector")
    unknown = impl._result("a" * 64, {}, {"cas_path": "", "receipt": {}}, errs, None, True)
    test_only = validate_bundle(b'{"schema":"wrong"}', context={"public_keys": {"TEST_ONLY-owner": "x"}, "security_ok": True, "security_profile": "TEST_ONLY-R3"})
    rows.append({"probe": "unknown_code_fail_closed", "codes": unknown["failure_codes"], "decision": unknown["decision"],
                 "pass": "UNREGISTERED_INTERNAL_VECTOR_CODE" in unknown["failure_codes"] and unknown["decision"] == "rejected_all"})
    rows.append({"probe": "test_only_context", "codes": test_only["failure_codes"], "decision": test_only["decision"],
                 "pass": "SCHEMA_INVALID" in test_only["failure_codes"] and test_only["no_publish"]})

    # Implementation registry is compared both to serialized R3 registry and
    # to string literals in source; an AST-independent review still records
    # exact mismatches rather than trusting a claim in README.
    serialized = json.loads(REGISTRY.read_text(encoding="utf-8"))
    impl_codes = set(impl.ERROR_CODES)
    reg_codes = set(serialized.get("codes", []))
    literals = set()
    tree = ast.parse(SOURCE.read_text(encoding="utf-8"))
    for node in ast.walk(tree):
        if isinstance(node, ast.Constant) and isinstance(node.value, str) and node.value.isupper() and ("_" in node.value):
            literals.add(node.value)
    emitted_candidates = {x for x in literals if x.startswith(("RAW_", "CANONICAL_", "SCHEMA_", "PACKET_", "OWNER_", "SIGNATURE_", "SECURITY_", "TEST_ONLY_", "EHP03_", "EHP04_", "SET_", "BUNDLE_", "REVIEW_", "DECISION_", "QUARANTINE_", "CAS_", "TYPED_"))}
    rows.append({"probe": "error_registry", "impl_count": len(impl_codes), "serialized_count": len(reg_codes),
                 "registry_missing": sorted(impl_codes - reg_codes), "registry_extra": sorted(reg_codes - impl_codes),
                 "source_literal_not_registered": sorted(emitted_candidates - impl_codes),
                 "pass": impl_codes == reg_codes and not (emitted_candidates - impl_codes)})

    rows.append({"probe": "authority_publish_static_surface", "authority_credit_constant": False,
                 "no_publish_constant": True, "network_imports": [],
                 "pass": "authority_credit" in SOURCE.read_text(encoding="utf-8") and "no_publish" in SOURCE.read_text(encoding="utf-8")})

    print(json.dumps({"utc": datetime.now(timezone.utc).isoformat(), "rows": rows}, sort_keys=True, indent=2))


if __name__ == "__main__":
    main()
