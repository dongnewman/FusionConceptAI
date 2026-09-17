from __future__ import annotations

import base64
import json
import tempfile
import unittest
from pathlib import Path

from tools.up1_external_closure_r3.atomic_bundle import (
    EXCLUSIONS, canonical_bytes, parse_json_strict, quarantine_raw, validate_bundle,
)
from tools.up1_external_closure_r3.atomic_bundle import bundle as impl
from tools.up1_external_closure_r3.atomic_bundle.canonical import CanonicalError


H = "a" * 64


class StrictInputTests(unittest.TestCase):
    def test_duplicate_nonfinite_and_utf8_are_rejected(self):
        for raw, code in ((b'{"a":1,"a":2}', "RAW_DUPLICATE_KEY"), (b'{"a":NaN}', "RAW_NONFINITE_NUMBER"), (b"\xff", "RAW_INVALID_UTF8")):
            with self.subTest(code=code):
                with self.assertRaises(CanonicalError) as raised:
                    parse_json_strict(raw)
                self.assertEqual(raised.exception.code, code)

    def test_unsupported_number_is_not_silently_replaced(self):
        with self.assertRaises(CanonicalError) as raised:
            parse_json_strict(b'{"n":9007199254740992}')
        self.assertEqual(raised.exception.code, "CANONICAL_NUMBER_UNSUPPORTED")

    def test_domain_preimages_and_exact_exclusions(self):
        self.assertEqual(EXCLUSIONS[0], "signature")
        packet = {"packet_id": "EHP-01", "payload": {"x": 1}, "payload_sha256": H,
                  "signature": {"key_id": "owner", "signature_b64": "x", "signature_sha256": H,
                                 "owner_preimage_sha256": H}}
        preimage = impl.packet_owner_preimage(packet)
        self.assertTrue(preimage.startswith(b"UP1.external-handoff.atomic-response-bundle.v1/packet-owner\n"))
        self.assertNotIn(b"signature_b64", preimage)
        self.assertNotIn(b"payload_sha256", preimage)

    def test_test_only_ed25519_fixture_verifies(self):
        fixture = json.loads((Path(__file__).parent / "fixtures" / "test_only_ed25519.json").read_text(encoding="utf-8"))
        packet = {"packet_id": "EHP-01", "packet_version": "v1", "owner": {"owner_id": "TEST_ONLY-owner-01", "role": "ehp01_witness"}, "shared_binding": {"candidate_id": "TEST_ONLY-candidate"}, "payload": {"fixture": "TEST_ONLY"}, "payload_sha256": H, "signature": {"key_id": "TEST_ONLY-owner-01", "algorithm": "Ed25519", "profile_id": "TEST_ONLY-R3", "signature_b64": fixture["signature_b64"], "signature_sha256": fixture["signature_sha256"], "owner_preimage_sha256": fixture["packet_preimage_sha256"]}}
        errors = []
        impl._verify_signature(packet["signature"], impl.packet_owner_preimage(packet), {"public_keys": {fixture["key_id"]: fixture["public_key_b64"]}}, errors, "/signature")
        self.assertEqual(errors, [])


class LocalCASAndResultTests(unittest.TestCase):
    def test_quarantine_is_atomic_cas_and_hash_bound(self):
        with tempfile.TemporaryDirectory() as tmp:
            raw = b'{"fixture":"TEST_ONLY"}'
            q = quarantine_raw(raw, tmp)
            cas = Path(q["cas_path"])
            self.assertTrue(cas.is_file())
            self.assertEqual(cas.read_bytes(), raw)
            self.assertEqual(q["receipt"]["raw_size_bytes"], len(raw))
            self.assertEqual(q["receipt"]["raw_object_sha256"], q["receipt"]["raw_blob_sha256"])
            self.assertFalse(list(Path(tmp).rglob("*.tmp")))

    def test_invalid_bundle_is_fail_limited_and_never_published(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = validate_bundle(b'{"schema":"wrong"}', quarantine_root=tmp)
            self.assertEqual(result["decision"], "rejected_all")
            self.assertEqual(result["status"], "fail_limited")
            self.assertFalse(result["authority_credit"])
            self.assertTrue(result["no_publish"])
            self.assertEqual(result["formal_credit"], "none")


class EHPRelationTests(unittest.TestCase):
    def setUp(self):
        self.shared = {"candidate_id": "candidate-1", "source_identity_sha256": H,
                       "four_axis_refs": [{"axis_id": f"A{i}"} for i in range(4)]}
        self.edge = {"edge_id": "e1", "from_kind": "source", "from_id": "s",
                     "to_kind": "candidate", "to_id": "candidate-1", "candidate_id": "candidate-1",
                     "source_identity_sha256": H, "namespace": "n", "version": "1"}
        self.reverse = dict(self.edge, edge_id="e2", from_kind="candidate", from_id="candidate-1",
                            to_kind="source", to_id="s")

    def _payload03(self):
        source = {"candidate_id": "candidate-1", "revision": "r", "head": "h", "tree": H,
                  "dirty_patch": {}, "untracked": {}, "submodules": {}, "source_bytes_sha256": H,
                  "inventory_sha256": H}
        source["dirty_patch"] = {"present": True, "sha256": H, "entries": ["p"]}
        source["untracked"] = {"present": True, "sha256": H, "entries": ["u"]}
        source["submodules"] = {"present": True, "sha256": H, "entries": ["s"]}
        source_digest = impl._digest(source)
        self.shared["source_identity_sha256"] = source_digest
        return {"source_identity": source, "axis_materials": [{"axis_id": f"A{i}"} for i in range(4)],
                "evidence_graph": {"forward_edges": [self.edge], "reverse_edges": [self.reverse]},
                "g2_mapping": {"candidate_id": "candidate-1", "ambiguity_decision": "none",
                                "mapping_rows": [{"from_id": "x", "to_id": "y"}],
                                "reverse_rows": [{"from_id": "y", "to_id": "x"}]},
                "authority_receipt": {"candidate_id": "candidate-1", "source_identity_sha256": source_digest}}

    def test_duplicate_or_non_inverse_graph_fails(self):
        payload = self._payload03()
        payload["evidence_graph"]["forward_edges"].append(dict(self.edge, edge_id="e3"))
        errors = []
        impl._check_ehp03(payload, self.shared, errors)
        self.assertIn("EHP03_GRAPH_BIJECTION_FAILURE", {x["code"] for x in errors})

    def test_directional_g2_rows_recompute_independently_and_bind_authority(self):
        """A valid inverse has distinct directional row digests."""
        ref = {"ref": "authority-signature", "sha256": H}
        issued = "2026-09-17T00:00:00Z"
        row = {"row_id": "r1", "from_id": "source-x", "to_id": "candidate-1", "issuer_ref": ref, "issued_at": issued}
        row["row_sha256"] = impl._digest(row)
        inverse = {"row_id": "r1", "from_id": "candidate-1", "to_id": "source-x", "issuer_ref": ref, "issued_at": issued}
        inverse["row_sha256"] = impl._digest(inverse)
        errors = []
        payload = self._payload03()
        payload["g2_mapping"] = {"candidate_id": "candidate-1", "ambiguity_decision": "none", "mapping_rows": [row], "reverse_rows": [inverse], "issuer_ref": ref}
        payload["authority_receipt"].update({"signature_ref": ref})
        impl._check_ehp03(payload, self.shared, errors)
        self.assertNotIn("EHP03_G2_MAPPING_MISMATCH", {x["code"] for x in errors})
        self.assertNotEqual(row["row_sha256"], inverse["row_sha256"])
        inverse["issuer_ref"] = {"ref": "attacker", "sha256": H}
        errors = []
        impl._check_ehp03(payload, self.shared, errors)
        self.assertIn("EHP03_G2_MAPPING_MISMATCH", {x["code"] for x in errors})
        self.assertIn("EHP03_G2_REF_MISMATCH", {x["code"] for x in errors})
        payload = self._payload03(); payload["evidence_graph"]["reverse_edges"][0]["to_id"] = "other"
        errors = []; impl._check_ehp03(payload, self.shared, errors)
        self.assertIn("EHP03_GRAPH_BIJECTION_FAILURE", {x["code"] for x in errors})

    def test_ehp04_identity_sbom_and_binary_relations(self):
        payload = {"expected_context_sha256": H,
                   "outer_authority": {"candidate_id": "candidate-1", "source_identity_sha256": H, "expected_context_sha256": H},
                   "runtime_and_imports": {"runtimes": [{"name": "Julia"}], "imports": [{"name": "x", "version": "1", "locator": "l", "sha256": H}, {"name": "x", "version": "1", "locator": "l", "sha256": H}], "lockfiles": []},
                   "sbom_documents": [{"components": [{"component_id": "c"}, {"component_id": "c"}], "dependency_edges": [{"from_component_id": "missing", "to_component_id": "c"}]}],
                   "binaries": [{"candidate_id": "foreign", "sha256": H, "download_receipt": {"subject_sha256": "b"}}],
                   "foreign_owner_fixture": {"fixture_status": "not_executed", "reason": "TEST_ONLY"}}
        errors = []; status = impl._check_ehp04(payload, self.shared, errors)
        codes = {x["code"] for x in errors}
        self.assertEqual(status, "not_executed")
        self.assertTrue({"EHP04_RUNTIME_SET_MISMATCH", "EHP04_IDENTITY_MAP_DUPLICATE", "EHP04_SBOM_COMPONENT_DUPLICATE", "EHP04_SBOM_EDGE_ENDPOINT_MISSING", "EHP04_BINARY_BINDING_MISMATCH"} <= codes)


class MatrixAndDecisionTests(unittest.TestCase):
    def test_all_r_vectors_and_decision_disagreement_are_registered(self):
        matrix = json.loads((Path(__file__).parents[3] / "docs" / "implementation" / "UP1-EXTERNAL-BLOCKER-CLOSURE-R3" / "05-atomic-bundle-prototype" / "acceptance-test-matrix.json").read_text(encoding="utf-8"))
        ids = {x["id"] for x in matrix["vectors"]}
        self.assertEqual(ids, {f"R{i:02d}" for i in range(1, 26)} | {"D01"})


if __name__ == "__main__":
    unittest.main()
