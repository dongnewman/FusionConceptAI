"""Independent R4 G2 mapping acceptance and adversarial probes.

This suite deliberately builds its own payload and digest preimages.  It does
not import R3 implementation helpers, and it never edits the component under
test.  The positive payload is R3 EHP-03 compatible (the R4 validator accepts
the R3 schema and field names); the negative vectors exercise each binding and
publication boundary independently.
"""
from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import sys
import unittest
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[3]
COMPONENT = ROOT / "tools" / "up1_external_closure_r4" / "g2_mapping"
sys.path.insert(0, str(COMPONENT))
import validator  # noqa: E402


UTC = "2026-09-17T00:00:00Z"
SHA = "a" * 64


def d(value: Any) -> str:
    """Test-owned canonical digest, intentionally not validator.canonical_bytes."""
    raw = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def ref(name: str, token: str = SHA) -> dict[str, str]:
    return {"ref": name, "sha256": token}


def _edge(edge_id: str, from_kind: str, from_id: str, to_kind: str, to_id: str, source_sha: str, auth: dict[str, str]) -> dict[str, Any]:
    edge: dict[str, Any] = {
        "edge_id": edge_id,
        "from_kind": from_kind,
        "from_id": from_id,
        "to_kind": to_kind,
        "to_id": to_id,
        "candidate_id": "candidate://g2-r4",
        "source_identity_sha256": source_sha,
        "namespace": "fusion://g2",
        "version": "r3-compatible-v1",
        "issuer_ref": copy.deepcopy(auth),
        "issued_at": UTC,
        "signature_ref": copy.deepcopy(auth),
    }
    edge["edge_sha256"] = d(edge)
    return edge


def _row(row_id: str, from_id: str, to_id: str, source_sha: str, auth: dict[str, str]) -> dict[str, Any]:
    row: dict[str, Any] = {
        "row_id": row_id,
        "from_id": from_id,
        "to_id": to_id,
        "candidate_id": "candidate://g2-r4",
        "source_identity_sha256": source_sha,
        "issuer_ref": copy.deepcopy(auth),
        "issued_at": UTC,
    }
    row["row_sha256"] = d(row)
    return row


def positive_profile() -> dict[str, Any]:
    source = {
        "candidate_id": "candidate://g2-r4",
        "source_ref": "git://fixture/r3",
        "revision": "r3-compat-1",
    }
    source_sha = d(source)
    authority_signature = ref("authority://g2-r4/signature")
    graph = {
        "graph_id": "graph://g2-r4",
        "forward_edges": [_edge("edge-fwd-1", "source", "source://r3", "candidate", "candidate://g2-r4", source_sha, authority_signature)],
        "reverse_edges": [_edge("edge-rev-1", "candidate", "candidate://g2-r4", "source", "source://r3", source_sha, authority_signature)],
        "coverage": {"forward_edges": 1, "reverse_edges": 1, "unique_forward_pairs": 1, "unique_reverse_pairs": 1},
    }
    graph["graph_sha256"] = d(graph)
    mapping = {
        "namespace": "fusion://g2",
        "version": "r3-compatible-v1",
        "effective_interval": {"not_before": UTC, "not_after": "2027-09-17T00:00:00Z"},
        "candidate_id": "candidate://g2-r4",
        "mapping_id": "mapping://g2-r4",
        "ambiguity_decision": "none",
        "issuer_ref": copy.deepcopy(authority_signature),
        "mapping_rows": [_row("row-1", "source://r3", "candidate://g2-r4", source_sha, authority_signature)],
        "reverse_rows": [_row("row-1", "candidate://g2-r4", "source://r3", source_sha, authority_signature)],
        "coverage": {"forward_rows": 1, "reverse_rows": 1, "unique_forward_pairs": 1, "unique_reverse_pairs": 1},
    }
    mapping["mapping_sha256"] = d(mapping)
    authority = {
        "receipt_id": "receipt://g2-r4",
        "candidate_id": "candidate://g2-r4",
        "source_identity_sha256": source_sha,
        "graph_sha256": graph["graph_sha256"],
        "trusted_time_ref": ref("authority://g2-r4/time", "b" * 64),
        "revocation_ref": ref("authority://g2-r4/revocation", "c" * 64),
        "signature_ref": copy.deepcopy(authority_signature),
        "issuer_ref": copy.deepcopy(authority_signature),
        "external_verification": False,
    }
    return {
        "schema": "UP1.external-handoff.ehp-03-response.v1",
        "status": "present",
        "candidate_id": "candidate://g2-r4",
        "source_identity": source,
        "source_identity_sha256": source_sha,
        "evidence_graph": graph,
        "g2_mapping": mapping,
        "authority_receipt": authority,
        "fixture_role": "TEST_ONLY",
        "no_publish": True,
        "formal_credit": "none",
    }


class IndependentG2MappingTests(unittest.TestCase):
    def assert_fail(self, payload: dict[str, Any], needle: str | None = None) -> None:
        result = validator.evaluate(payload)
        self.assertFalse(result["accepted"], result)
        self.assertEqual(result["decision"], "fail_closed", result)
        self.assertTrue(result["no_publish"])
        self.assertEqual(result["formal_credit"], "none")
        if needle:
            self.assertIn(needle, result["error"], result)

    def test_r3_payload_structurally_valid_but_terminal_deferred(self) -> None:
        result = validator.evaluate(positive_profile())
        self.assertFalse(result["accepted"])
        self.assertEqual(result["decision"], "terminal_deferred")
        self.assertEqual(result["resolution"], "terminal_deferred")
        self.assertFalse(result["production_admissible"])
        self.assertTrue(result["no_publish"])
        self.assertEqual(result["formal_credit"], "none")
        self.assertFalse(result["authority_verified"])

    def test_direct_validation_exposes_graph_and_mapping_identity(self) -> None:
        result = validator.validate_mapping(positive_profile())
        self.assertTrue(result["structural_valid"])
        self.assertEqual(result["graph"]["forward_count"], 1)
        self.assertEqual(result["graph"]["reverse_count"], 1)
        self.assertEqual(result["mapping"]["forward_count"], 1)
        self.assertEqual(result["mapping"]["reverse_count"], 1)

    def test_each_graph_direction_is_required(self) -> None:
        for key in ("forward_edges", "reverse_edges"):
            item = positive_profile()
            item["evidence_graph"][key] = []
            self.assert_fail(item, "both_nonempty_edge_lists_required")

    def test_each_mapping_direction_is_required(self) -> None:
        for key in ("mapping_rows", "reverse_rows"):
            item = positive_profile()
            item["g2_mapping"][key] = []
            self.assert_fail(item, "both_nonempty_row_lists_required")

    def test_graph_edge_digest_and_graph_digest(self) -> None:
        item = positive_profile()
        item["evidence_graph"]["forward_edges"][0]["to_id"] = "candidate://changed"
        self.assert_fail(item, "edge_sha256:recomputed_hash_mismatch")
        item = positive_profile()
        item["evidence_graph"]["graph_sha256"] = "f" * 64
        self.assert_fail(item, "graph_sha256:recomputed_hash_mismatch")

    def test_mapping_row_digest_and_mapping_digest(self) -> None:
        item = positive_profile()
        item["g2_mapping"]["mapping_rows"][0]["to_id"] = "candidate://changed"
        self.assert_fail(item, "row_sha256:recomputed_hash_mismatch")
        item = positive_profile()
        item["g2_mapping"]["mapping_sha256"] = "f" * 64
        self.assert_fail(item, "mapping_sha256:recomputed_hash_mismatch")

    def test_graph_bijection_and_authority_refs_are_exact(self) -> None:
        item = positive_profile()
        reverse = item["evidence_graph"]["reverse_edges"][0]
        reverse["issued_at"] = "2026-09-17T00:01:00Z"
        reverse["edge_sha256"] = d({k: v for k, v in reverse.items() if k != "edge_sha256"})
        self.assert_fail(item, "bijection_failure")
        item = positive_profile()
        item["evidence_graph"]["forward_edges"][0]["issuer_ref"] = ref("authority://other")
        item["evidence_graph"]["forward_edges"][0]["edge_sha256"] = d({k: v for k, v in item["evidence_graph"]["forward_edges"][0].items() if k != "edge_sha256"})
        self.assert_fail(item, "issuer_ref:mismatch")

    def test_mapping_bijection_and_authority_refs_are_exact(self) -> None:
        item = positive_profile()
        reverse = item["g2_mapping"]["reverse_rows"][0]
        reverse["issued_at"] = "2026-09-17T00:01:00Z"
        reverse["row_sha256"] = d({k: v for k, v in reverse.items() if k != "row_sha256"})
        self.assert_fail(item, "bijection_failure")
        item = positive_profile()
        item["g2_mapping"]["issuer_ref"] = ref("authority://other")
        item["g2_mapping"]["mapping_sha256"] = d({k: v for k, v in item["g2_mapping"].items() if k != "mapping_sha256"})
        self.assert_fail(item, "issuer_ref:mismatch")

    def test_duplicates_and_coverage_are_fail_closed(self) -> None:
        item = positive_profile()
        edge = copy.deepcopy(item["evidence_graph"]["forward_edges"][0])
        item["evidence_graph"]["forward_edges"].append(edge)
        self.assert_fail(item, "duplicate_edge_id")
        item = positive_profile()
        row = copy.deepcopy(item["g2_mapping"]["mapping_rows"][0])
        item["g2_mapping"]["mapping_rows"].append(row)
        self.assert_fail(item, "duplicate_row_id")
        item = positive_profile()
        item["evidence_graph"]["coverage"]["forward_edges"] = 7
        item["evidence_graph"]["graph_sha256"] = d({k: v for k, v in item["evidence_graph"].items() if k != "graph_sha256"})
        item["authority_receipt"]["graph_sha256"] = item["evidence_graph"]["graph_sha256"]
        self.assert_fail(item, "coverage.forward_edges:mismatch")
        item = positive_profile()
        item["g2_mapping"]["coverage"]["reverse_rows"] = 7
        item["g2_mapping"]["mapping_sha256"] = d({k: v for k, v in item["g2_mapping"].items() if k != "mapping_sha256"})
        self.assert_fail(item, "coverage.reverse_rows:mismatch")

    def test_candidate_source_and_authority_binding(self) -> None:
        mutations: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
            ("source_identity.candidate_id:mismatch", lambda x: x["source_identity"].__setitem__("candidate_id", "candidate://other")),
            ("g2_mapping.candidate_id:mismatch", lambda x: x["g2_mapping"].__setitem__("candidate_id", "candidate://other")),
            ("authority_receipt.source_identity_sha256:mismatch", lambda x: x["authority_receipt"].__setitem__("source_identity_sha256", "f" * 64)),
            ("authority_receipt.graph_sha256:mismatch", lambda x: x["authority_receipt"].__setitem__("graph_sha256", "f" * 64)),
        ]
        for needle, mutate in mutations:
            with self.subTest(needle=needle):
                item = positive_profile()
                mutate(item)
                self.assert_fail(item, needle)

    def test_typed_absent_and_terminal_deferred_are_explicit(self) -> None:
        for status, expected in (("typed_absent", "typed_absence"), ("terminal_deferred", "terminal_deferred")):
            result = validator.evaluate({"schema": validator.SCHEMA, "status": status, "reason": "external authority unavailable"})
            self.assertTrue(result["accepted"])
            self.assertEqual(result["decision"], expected)
            self.assertEqual(result["resolution"], "terminal_deferred")
            self.assertTrue(result["no_publish"])
            self.assertEqual(result["formal_credit"], "none")

    def test_absence_with_payload_or_publication_is_rejected(self) -> None:
        for fields in ({"g2_mapping": {}}, {"no_publish": False}, {"formal_credit": "credit"}):
            item = {"status": "typed_absent", **fields}
            self.assert_fail(item)

    def test_duplicate_json_keys_fail_closed(self) -> None:
        raw = '{"schema":"UP1.external-handoff.ehp-03-response.v1","status":"typed_absent","status":"terminal_deferred"}'
        with self.assertRaisesRegex(validator.MappingError, "duplicate_key:status"):
            validator.load_text(raw)

    def test_nonfinite_and_unsafe_numbers_fail_closed(self) -> None:
        for raw, needle in (("{\"status\":\"typed_absent\",\"x\":NaN}", "nonfinite_number:NaN"), ("{\"status\":\"typed_absent\",\"x\":9007199254740992}", "unsafe_integer")):
            with self.subTest(raw=raw):
                if "NaN" in raw:
                    with self.assertRaisesRegex(validator.MappingError, needle):
                        validator.load_text(raw)
                else:
                    with self.assertRaisesRegex(validator.MappingError, needle):
                        validator.canonical_bytes(9007199254740992)

    def test_cli_exit_and_output_contract(self) -> None:
        good_path = COMPONENT / "_r4_test_positive.json"
        bad_path = COMPONENT / "_r4_test_bad.json"
        try:
            good_path.write_text(json.dumps(positive_profile(), ensure_ascii=False, sort_keys=True), encoding="utf-8")
            bad = positive_profile()
            bad["no_publish"] = False
            bad_path.write_text(json.dumps(bad, ensure_ascii=False, sort_keys=True), encoding="utf-8")
            good = subprocess.run([sys.executable, "-B", str(COMPONENT / "validate_g2_mapping.py"), str(good_path)], capture_output=True, text=True, check=False)
            self.assertEqual(good.returncode, 1)
            good_result = json.loads(good.stdout)
            self.assertEqual(good_result["decision"], "terminal_deferred")
            self.assertTrue(good_result["no_publish"])
            bad_result = subprocess.run([sys.executable, "-B", str(COMPONENT / "validate_g2_mapping.py"), str(bad_path)], capture_output=True, text=True, check=False)
            self.assertEqual(bad_result.returncode, 1)
            self.assertEqual(json.loads(bad_result.stdout)["decision"], "fail_closed")
        finally:
            good_path.unlink(missing_ok=True)
            bad_path.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
