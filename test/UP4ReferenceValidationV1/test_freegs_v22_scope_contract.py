"""Python-only tests for FreeGS v22 structured scope restoration."""

from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
PROTOCOL_PATH = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v13/actual_run_protocol_v22_scope_contract_candidate_v1.json"
VERIFIER_PATH = ROOT / "tools/up4_reference_validation/verify_freegs_v22_scope_contract_candidate.py"
SPEC = importlib.util.spec_from_file_location("freegs_v22_scope_verifier_test", VERIFIER_PATH)
assert SPEC is not None and SPEC.loader is not None
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)


class FreeGSV22ScopeContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))

    def test_frozen_candidate_verifies_ungranted_and_preserves_status_map(self) -> None:
        result = VERIFIER.validate_candidate(PROTOCOL_PATH)
        self.assertEqual(result["status"], "static_protocol_scope_contract_pass_ungranted")
        self.assertEqual(result["dependency_pin_count"], 165)
        self.assertTrue(result["v21_status_contract_preserved"])
        self.assertFalse(result["root_resource_slot_granted"])
        self.assertFalse(result["runtime_execution_authorized"])
        self.assertTrue(result["new_actual_output_leaf_absent"])

    def test_structured_scope_has_exact_v20_key_inventory_and_v22_values(self) -> None:
        scope = self.protocol["scope"]
        v20_path = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v11/actual_run_protocol_v20_candidate_v1.json"
        v20 = json.loads(v20_path.read_text(encoding="utf-8"))
        self.assertEqual(set(scope), set(v20["scope"]))
        self.assertEqual(len(scope), 17)
        VERIFIER.validate_scope_contract(scope, v20["scope"])

    def test_every_scope_key_is_required_and_each_scope_value_is_bound(self) -> None:
        scope = self.protocol["scope"]
        for key in VERIFIER.EXPECTED_SCOPE:
            with self.subTest(missing_key=key):
                missing = dict(scope)
                del missing[key]
                with self.assertRaises(RuntimeError):
                    VERIFIER.validate_scope_contract(missing)
            with self.subTest(changed_value=key):
                changed = dict(scope)
                expected = VERIFIER.EXPECTED_SCOPE[key]
                changed[key] = (not expected) if type(expected) is bool else f"{expected}__tampered"
                with self.assertRaises(RuntimeError):
                    VERIFIER.validate_scope_contract(changed)

    def test_v21_scalar_scope_is_rejected_by_scope_contract(self) -> None:
        prior_path = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v12/actual_run_protocol_v21_candidate_v1.json"
        prior = json.loads(prior_path.read_text(encoding="utf-8"))
        with self.assertRaisesRegex(RuntimeError, "structured V20 object"):
            VERIFIER.validate_scope_contract(prior["scope"])

    def test_full_verifier_rejects_scalar_scope_copy(self) -> None:
        protocol = copy.deepcopy(self.protocol)
        protocol["scope"] = "Frozen FreeGS candidate"
        with tempfile.TemporaryDirectory() as tmp:
            candidate = Path(tmp) / "tampered_protocol.json"
            candidate.write_text(json.dumps(protocol), encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "structured V20 object"):
                VERIFIER.validate_candidate(candidate)

    def test_full_verifier_rejects_each_missing_scope_key(self) -> None:
        for key in VERIFIER.EXPECTED_SCOPE:
            with self.subTest(missing_key=key):
                protocol = copy.deepcopy(self.protocol)
                del protocol["scope"][key]
                with tempfile.TemporaryDirectory() as tmp:
                    candidate = Path(tmp) / "tampered_protocol.json"
                    candidate.write_text(json.dumps(protocol), encoding="utf-8")
                    with self.assertRaises(RuntimeError):
                        VERIFIER.validate_candidate(candidate)

    def test_scope_contract_binds_v21_no_go_and_both_review_receipts(self) -> None:
        prior = self.protocol["protocol_scope_contract_v22"]["prior_v21_candidate"]
        self.assertEqual(prior["protocol_sha256"], VERIFIER.V21_PROTOCOL_SHA256)
        self.assertEqual(prior["status_contract_verdict"], "GO_static_status_mapping_only")
        self.assertEqual(prior["runtime_candidate_verdict"], "NO_GO_scope_contract")
        self.assertEqual(prior["scope_review"]["report_sha256"], VERIFIER.V21_SCOPE_REVIEW_SHA256)
        self.assertEqual(prior["reference_inverse_status_review"]["report_sha256"], VERIFIER.V21_REFERENCE_REVIEW_SHA256)

    def test_all_natural_exit_statuses_are_identical_to_frozen_v21(self) -> None:
        v21_path = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v12/actual_run_protocol_v21_candidate_v1.json"
        v21 = json.loads(v21_path.read_text(encoding="utf-8"))
        current = self.protocol["steps"][0]
        prior = v21["steps"][0]
        self.assertEqual(current["natural_exit_statuses_by_code"], prior["natural_exit_statuses_by_code"])
        self.assertEqual(current["natural_exit_map"], prior["natural_exit_map"])
        self.assertEqual(current["result_exit_schema_contract"], prior["result_exit_schema_contract"])

    def test_solver_source_input_dynamic_controls_and_resources_are_unchanged(self) -> None:
        v21_path = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v12/actual_run_protocol_v21_candidate_v1.json"
        v21 = json.loads(v21_path.read_text(encoding="utf-8"))
        self.assertEqual(self.protocol["source_inputs"], v21["source_inputs"])
        self.assertEqual(self.protocol["resource_contract"], v21["resource_contract"])
        self.assertEqual(self.protocol["steps"][0]["dynamic_binding"], v21["steps"][0]["dynamic_binding"])
        self.assertEqual(self.protocol["steps"][0]["result_exit_schema_contract"], v21["steps"][0]["result_exit_schema_contract"])
        self.assertEqual(self.protocol["source_inputs"]["solver_input_sha256"], "0ea833fd717c313a2f5d1c562ccbb78a3dc5efc1f4a4679bd454b1b1a918f447")
        self.assertEqual(self.protocol["source_inputs"]["snapshot_sha256"], "fe7e3cf247cd9d0f0c58a9d3926899ec0b34323ac839992b61003085ebd738ac")

    def test_boolean_scope_fields_reject_integer_substitutes(self) -> None:
        for key in ("engineering_validation", "formal_acceptance", "independent_validation", "likelihood_ready", "parent_UP4_03_complete", "physical_validation", "reference_inversion_G1_G2_G3", "terminal_authority"):
            with self.subTest(key=key):
                changed = dict(self.protocol["scope"])
                changed[key] = 0
                with self.assertRaises(RuntimeError):
                    VERIFIER.validate_scope_contract(changed)


if __name__ == "__main__":
    unittest.main(verbosity=2)
