"""Python-only checks for source-derived FreeGS exit/status sets in V21."""

from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
VERIFIER_PATH = ROOT / "tools/up4_reference_validation/verify_freegs_v21_protocol_status_candidate.py"
PROTOCOL_PATH = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v12/actual_run_protocol_v21_candidate_v1.json"
SUCCESS = "test_only_fixed_observed_box_dirichlet_policy_v2_converged_residual_measured"
EXPECTED = {
    "0": [SUCCESS],
    "2": ["input_validation_failed"],
    "3": ["backend_unavailable"],
    "4": [
        "numerical_fail_boundary_invariant",
        "numerical_fail_invalid_state",
        "numerical_fail_nonconvergence",
    ],
    "5": ["program_exception"],
    "6": ["unsupported_fixed_box_terminal_topology"],
}
ALL_STATUSES = sorted({status for statuses in EXPECTED.values() for status in statuses})


def load_verifier():
    spec = importlib.util.spec_from_file_location("freegs_v21_status_verifier", VERIFIER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load v21 static verifier")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FreeGSV21StatusContractTests(unittest.TestCase):
    def test_runner_and_baseline_source_derive_complete_natural_exit_status_sets(self):
        verifier = load_verifier()
        protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        contract = protocol["protocol_status_contract_v21"]
        runner = ROOT / contract["runner_source_path"]
        baseline = ROOT / contract["baseline_runner_source_path"]
        self.assertEqual(verifier.runner_statuses_by_exit_code(runner, baseline), EXPECTED)
        self.assertEqual(protocol["steps"][0]["natural_exit_statuses_by_code"], EXPECTED)
        self.assertEqual(protocol["steps"][0]["natural_exit_map"], verifier.CATEGORY_SUMMARY)

    def test_exhaustive_exit_code_status_cross_product_accepts_only_source_pairs(self):
        verifier = load_verifier()
        for code in EXPECTED:
            for status in ALL_STATUSES:
                with self.subTest(exit_code=code, status=status):
                    self.assertEqual(
                        verifier.status_accepts(code, status, EXPECTED),
                        status in EXPECTED[code],
                    )

    def test_exit_four_has_three_distinct_numerical_statuses(self):
        verifier = load_verifier()
        self.assertEqual(EXPECTED["4"], [
            "numerical_fail_boundary_invariant",
            "numerical_fail_invalid_state",
            "numerical_fail_nonconvergence",
        ])
        for status in EXPECTED["4"]:
            self.assertTrue(verifier.status_accepts(4, status, EXPECTED))
        self.assertFalse(verifier.status_accepts(4, "numerical_fail_nonconvergence_or_boundary_invariant", EXPECTED))

    def test_exit_four_statuses_cannot_be_confused_with_program_exception_or_topology(self):
        verifier = load_verifier()
        for status in EXPECTED["4"]:
            self.assertFalse(verifier.status_accepts(5, status, EXPECTED))
            self.assertFalse(verifier.status_accepts(6, status, EXPECTED))
        self.assertFalse(verifier.status_accepts(4, "program_exception", EXPECTED))
        self.assertFalse(verifier.status_accepts(4, "unsupported_fixed_box_terminal_topology", EXPECTED))
        self.assertFalse(verifier.status_accepts(5, "unsupported_fixed_box_terminal_topology", EXPECTED))
        self.assertFalse(verifier.status_accepts(6, "program_exception", EXPECTED))

    def test_every_nonzero_code_rejects_a_status_from_every_other_code(self):
        verifier = load_verifier()
        for code, statuses in EXPECTED.items():
            if code == "0":
                continue
            foreign = [status for other, values in EXPECTED.items() if other != code for status in values]
            for status in foreign:
                with self.subTest(exit_code=code, foreign_status=status):
                    self.assertFalse(verifier.status_accepts(code, status, EXPECTED))

    def test_v20_scalar_exit_four_label_is_bound_as_prior_no_go_not_an_allowed_status(self):
        verifier = load_verifier()
        protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        prior = protocol["protocol_status_contract_v21"]["prior_v20_candidate"]
        self.assertEqual(prior["protocol_sha256"], verifier.V20_PROTOCOL_SHA256)
        self.assertEqual(prior["prior_exit4_scalar_status"], "numerical_fail_nonconvergence_or_boundary_invariant")
        self.assertFalse(verifier.status_accepts(4, prior["prior_exit4_scalar_status"], EXPECTED))

    def test_protocol_verifier_rejects_missing_or_cross_code_status_membership(self):
        verifier = load_verifier()
        original = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        protocol_step = original["steps"][0]
        contract = original["protocol_status_contract_v21"]
        source_map = EXPECTED
        for code, statuses in EXPECTED.items():
            for status in statuses:
                tampered = copy.deepcopy(protocol_step)
                tampered["natural_exit_statuses_by_code"][code].remove(status)
                with self.subTest(control="remove", exit_code=code, status=status):
                    with self.assertRaisesRegex(RuntimeError, "exact natural status sets"):
                        verifier.validate_status_set_contract(tampered, contract, source_map)
            for status in ALL_STATUSES:
                if status in statuses:
                    continue
                tampered = copy.deepcopy(protocol_step)
                tampered["natural_exit_statuses_by_code"][code].append(status)
                tampered["natural_exit_statuses_by_code"][code].sort()
                with self.subTest(control="cross_code_insert", exit_code=code, status=status):
                    with self.assertRaisesRegex(RuntimeError, "exact natural status sets"):
                        verifier.validate_status_set_contract(tampered, contract, source_map)

    def test_full_verifier_rejects_exit5_or_exit6_cross_code_status_tampering(self):
        verifier = load_verifier()
        original = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        mutations = [
            ("exit5_boundary", "5", "numerical_fail_boundary_invariant"),
            ("exit6_program_exception", "6", "program_exception"),
        ]
        for name, code, status in mutations:
            protocol = copy.deepcopy(original)
            protocol["steps"][0]["natural_exit_statuses_by_code"][code] = [status]
            with self.subTest(control=name), tempfile.TemporaryDirectory() as temp_dir:
                candidate = Path(temp_dir) / "v21_tampered_status_set.json"
                candidate.write_text(json.dumps(protocol), encoding="utf-8")
                with self.assertRaisesRegex(RuntimeError, "exact natural status sets"):
                    verifier.validate_candidate(candidate)

    def test_v20_remains_frozen_and_v21_is_ungranted(self):
        protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        self.assertFalse(protocol["runtime_execution_authorized"])
        self.assertFalse(protocol["root_resource_slot"]["granted"])
        self.assertEqual(protocol["protocol_status_contract_v21"]["prior_v20_candidate"]["verdict"],
                         "NO-GO: V20 exit-4 scalar map cannot encode all pinned runner statuses; V21 binds the exact source-derived set")


if __name__ == "__main__":
    unittest.main(verbosity=2)
