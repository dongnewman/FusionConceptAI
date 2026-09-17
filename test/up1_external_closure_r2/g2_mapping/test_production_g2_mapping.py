from __future__ import annotations

import copy
import json
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
COMPONENT = ROOT / "tools" / "up1_external_closure_r2" / "g2_mapping"
sys.path.insert(0, str(COMPONENT))
import production_g2_mapping as evaluator  # noqa: E402


def profile() -> dict:
    return evaluator.load_path(COMPONENT / "fixtures" / "test_only_positive.json")


def expected() -> dict:
    return evaluator.load_path(COMPONENT / "fixtures" / "expected_binding.json")


class ProductionG2MappingTests(unittest.TestCase):
    def test_test_only_is_positive_non_evidence(self) -> None:
        result = evaluator.evaluate(profile())
        self.assertTrue(result["accepted"])
        self.assertEqual(result["decision"], "non_evidence")
        self.assertFalse(result["production_admissible"])

    def test_missing_authority_is_typed_absence(self) -> None:
        result = evaluator.evaluate(evaluator.load_path(COMPONENT / "fixtures" / "typed_absent.json"))
        self.assertEqual(result, {"accepted": True, "decision": "typed_absence", "production_admissible": False, "reason": "authoritative_mapping_not_supplied"})

    def test_production_without_external_signature_authority_fails_closed(self) -> None:
        item = profile()
        item["fixture_role"] = "PRODUCTION"
        item["status"] = "present"
        item["production_present_admission"] = True
        result = evaluator.evaluate(item, expected())
        self.assertEqual(result["decision"], "fail_closed")
        self.assertFalse(result["production_admissible"])
        self.assertFalse(result["authority_verified"])

    def test_production_requires_independent_expected_binding(self) -> None:
        item = profile()
        item["fixture_role"] = "PRODUCTION"
        item["status"] = "present"
        item["production_present_admission"] = True
        with self.assertRaisesRegex(evaluator.ProfileError, "independent_context_required"):
            evaluator.validate_profile(item)

    def test_parameterized_negative_cases(self) -> None:
        cases = {
            "namespace": lambda m: m.__setitem__("namespace", "foreign://g2"),
            "version": lambda m: m.__setitem__("version", ""),
            "interval": lambda m: m["effective_interval"].__setitem__("not_after", "2025-01-01T00:00:00Z"),
            "time": lambda m: m["effective_interval"].__setitem__("trusted_time", "2025-01-01T00:00:00"),
            "issuer": lambda m: m["issuer"].pop("id"),
            "algorithm": lambda m: m["signature"].__setitem__("algorithm", "md5"),
            "key_id": lambda m: m["signature"].pop("key_id"),
            "trust_root_ref": lambda m: m["signature"].__setitem__("trust_root_ref", "https://authority.example/trust-root/other"),
            "policy_oid": lambda m: m["trust_root"].__setitem__("policy_oid", "not-an-oid"),
            "eku": lambda m: m["trust_root"].__setitem__("eku", []),
            "key_usage": lambda m: m["trust_root"].pop("key_usage"),
            "name_constraints": lambda m: m["trust_root"].__setitem__("name_constraints", [""]),
            "revocation": lambda m: m["revocation"].__setitem__("status", "revoked"),
            "freshness": lambda m: m["revocation"].__setitem__("checked_at", "2026-01-01T00:00:00Z"),
            "nonce": lambda m: m["anti_replay"].__setitem__("nonce", "x"),
            "sequence": lambda m: m["anti_replay"].__setitem__("sequence", -1),
            "idempotency": lambda m: m["anti_replay"].pop("idempotency_key"),
            "replay": lambda m: m["anti_replay"].__setitem__("replay_status", "replayed"),
            "ambiguity": lambda m: m["ambiguity"].__setitem__("state", "ambiguous"),
            "conflict": lambda m: m["conflict"].__setitem__("state", "conflict"),
            "duplicate_axis": lambda m: m["four_axis_evidence"]["axes"][1].__setitem__("axis_id", "payload_schema_version"),
            "unknown_axis": lambda m: m["four_axis_evidence"]["axes"][0].__setitem__("axis_id", "unknown"),
            "binding": lambda m: m["binding_edges"]["g2_four_axis_evidence_edge"].__setitem__("sha256", "f" * 64),
        }
        for name, mutate in cases.items():
            with self.subTest(case=name):
                item = profile()
                mutate(item["mapping"])
                with self.assertRaises(evaluator.ProfileError):
                    evaluator.validate_profile(item)

    def test_unknown_field_rejected(self) -> None:
        item = profile()
        item["mapping"]["unexpected"] = True
        with self.assertRaisesRegex(evaluator.ProfileError, "unknown_fields"):
            evaluator.validate_profile(item)

    def test_foreign_candidate_self_consistent_rejected_by_expected_context(self) -> None:
        item = profile()
        item["mapping"]["candidate_ref"] = "fusionconceptai://candidate/foreign"
        item["mapping"]["binding_edges"]["source_candidate_edge"]["ref"] = "fusionconceptai://candidate/foreign"
        item["mapping"]["binding_edges"]["four_axis_evidence_candidate_edge"]["ref"] = "fusionconceptai://candidate/foreign"
        with self.assertRaisesRegex(evaluator.ProfileError, "expected_binding:candidate_id_or_ref_mismatch"):
            evaluator.validate_profile(item, expected())

    def test_foreign_source_self_consistent_rejected_by_expected_context(self) -> None:
        item = profile()
        item["mapping"]["source_ref"] = "fusionconceptai://source/foreign"
        item["mapping"]["binding_edges"]["candidate_source_edge"]["ref"] = "fusionconceptai://source/foreign"
        with self.assertRaisesRegex(evaluator.ProfileError, "expected_binding:source_ref_or_version_mismatch"):
            evaluator.validate_profile(item, expected())

    def test_canonical_and_source_hashes_are_recomputed(self) -> None:
        item = profile()
        item["mapping"]["integrity"]["declaration_sha256"] = "f" * 64
        with self.assertRaisesRegex(evaluator.ProfileError, "declaration_sha256:recomputed_hash_mismatch"):
            evaluator.validate_profile(item, expected())
        item = profile()
        item["mapping"]["integrity"]["source_sha256"] = "f" * 64
        with self.assertRaisesRegex(evaluator.ProfileError, "source_sha256:expected_source_identity_mismatch"):
            evaluator.validate_profile(item, expected())

    def test_missing_or_forged_receipt_and_signature_payload_rejected(self) -> None:
        item = profile()
        item["mapping"]["integrity"].pop("receipt")
        with self.assertRaisesRegex(evaluator.ProfileError, "mapping.integrity:unknown_fields|mapping.integrity:missing"):
            evaluator.validate_profile(item, expected())
        item = profile()
        item["mapping"]["integrity"]["signature_payload"]["payload_sha256"] = "f" * 64
        with self.assertRaisesRegex(evaluator.ProfileError, "signature_payload:recomputed_hash_mismatch"):
            evaluator.validate_profile(item, expected())

    def test_axis_reorder_cannot_reuse_old_declaration_hash(self) -> None:
        item = profile()
        item["mapping"]["four_axis_evidence"]["axes"] = list(reversed(item["mapping"]["four_axis_evidence"]["axes"]))
        with self.assertRaisesRegex(evaluator.ProfileError, "declaration_sha256:recomputed_hash_mismatch"):
            evaluator.validate_profile(item, expected())

    def test_duplicate_binding_node_ref_rejected(self) -> None:
        item = profile()
        item["mapping"]["g2_ref"] = item["mapping"]["candidate_ref"]
        with self.assertRaisesRegex(evaluator.ProfileError, "unique_refs_required"):
            evaluator.validate_profile(item)

    def test_duplicate_axis_evidence_ref_rejected(self) -> None:
        item = profile()
        item["mapping"]["four_axis_evidence"]["axes"][1]["evidence_ref"] = item["mapping"]["four_axis_evidence"]["axes"][0]["evidence_ref"]
        with self.assertRaisesRegex(evaluator.ProfileError, "duplicate"):
            evaluator.validate_profile(item)

    def test_duplicate_key_rejected_at_nested_object(self) -> None:
        raw = '{"schema":"UP1.g2-production-mapping.v2","fixture_role":"TEST_ONLY","status":"test_only","production_present_admission":false,"mapping":null,"absence":null,"mapping":null}'
        with self.assertRaisesRegex(evaluator.ProfileError, "duplicate_key:mapping"):
            evaluator.load_text(raw)

    def test_cli_isolated_json_and_fail_closed(self) -> None:
        good = subprocess.run([sys.executable, "-B", str(COMPONENT / "validate_g2_mapping.py"), str(COMPONENT / "fixtures" / "test_only_positive.json")], capture_output=True, text=True, check=False)
        self.assertEqual(good.returncode, 0)
        self.assertEqual(json.loads(good.stdout)["decision"], "non_evidence")
        bad = copy.deepcopy(profile())
        bad["mapping"]["binding_edges"]["source_candidate_edge"]["sha256"] = "f" * 64
        bad_path = self.create_temp_profile(bad)
        failed = subprocess.run([sys.executable, "-B", str(COMPONENT / "validate_g2_mapping.py"), str(bad_path)], capture_output=True, text=True, check=False)
        self.assertEqual(failed.returncode, 1)
        self.assertEqual(json.loads(failed.stdout)["decision"], "fail_closed")
        production = profile()
        production["fixture_role"], production["status"], production["production_present_admission"] = "PRODUCTION", "present", True
        production_path = self.create_temp_profile(production)
        no_authority = subprocess.run([sys.executable, "-B", str(COMPONENT / "validate_g2_mapping.py"), str(production_path), "--expected", str(COMPONENT / "fixtures" / "expected_binding.json")], capture_output=True, text=True, check=False)
        self.assertEqual(no_authority.returncode, 1)
        self.assertEqual(json.loads(no_authority.stdout)["decision"], "fail_closed")

    @staticmethod
    def create_temp_profile(value: dict) -> Path:
        path = COMPONENT / "_test_tmp_invalid.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    @classmethod
    def tearDownClass(cls) -> None:
        path = COMPONENT / "_test_tmp_invalid.json"
        if path.exists():
            path.unlink()


if __name__ == "__main__":
    unittest.main()
