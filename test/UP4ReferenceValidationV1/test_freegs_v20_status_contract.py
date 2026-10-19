"""Python-only regression tests for every V20 success-status mapping surface."""

from __future__ import annotations

import ast
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
VERIFIER_PATH = ROOT / "tools/up4_reference_validation/verify_freegs_v20_protocol_status_candidate.py"
RUNNER_PATH = ROOT / "tools/up4_reference_validation/runtime_v4_freegs_axisymmetric_profile_runner_v9.py"
V19_PROTOCOL_PATH = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v10/actual_run_protocol_v19_candidate_v1.json"
V20_PROTOCOL_PATH = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v11/actual_run_protocol_v20_candidate_v1.json"
EXPECTED_STATUS = "test_only_fixed_observed_box_dirichlet_policy_v2_converged_residual_measured"


def load_verifier():
    spec = importlib.util.spec_from_file_location("freegs_v20_protocol_verifier", VERIFIER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load v20 static verifier")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FreeGSV20StatusContractTests(unittest.TestCase):
    def test_success_field_and_exit_zero_map_match_runner_assignment(self):
        verifier = load_verifier()
        emitted = verifier.runner_success_status(ast.parse(RUNNER_PATH.read_text(encoding="utf-8")))
        protocol = json.loads(V20_PROTOCOL_PATH.read_text(encoding="utf-8"))
        step = protocol["steps"][0]
        self.assertEqual(emitted, EXPECTED_STATUS)
        self.assertEqual(step["result_exit_schema_contract"]["success"]["required_status"], emitted)
        self.assertEqual(step["natural_exit_map"]["0"], emitted)
        contract = protocol["protocol_status_contract_v20"]
        self.assertEqual(contract["runner_emitted_success_status"], emitted)
        self.assertEqual(contract["success_required_status"], emitted)
        self.assertEqual(contract["natural_exit_zero_status"], emitted)

    def test_v19_exit_zero_map_negative_control_is_rejected(self):
        verifier = load_verifier()
        emitted = verifier.runner_success_status(ast.parse(RUNNER_PATH.read_text(encoding="utf-8")))
        old_protocol = json.loads(V19_PROTOCOL_PATH.read_text(encoding="utf-8"))
        stale = old_protocol["steps"][0]["natural_exit_map"]["0"]
        self.assertEqual(stale, verifier.STALE_V18_SUCCESS_STATUS)
        self.assertFalse(verifier.status_contract_accepts(stale, emitted))

    def test_static_verifier_rejects_tampered_success_status_field(self):
        self._assert_protocol_rejected("success", "protocol success status differs")

    def test_static_verifier_rejects_tampered_exit_zero_map(self):
        self._assert_protocol_rejected("exit_zero", "natural exit 0 mapping differs")

    def _assert_protocol_rejected(self, field: str, message: str):
        verifier = load_verifier()
        protocol = json.loads(V20_PROTOCOL_PATH.read_text(encoding="utf-8"))
        if field == "success":
            protocol["steps"][0]["result_exit_schema_contract"]["success"]["required_status"] = verifier.STALE_V18_SUCCESS_STATUS
        elif field == "exit_zero":
            protocol["steps"][0]["natural_exit_map"]["0"] = verifier.STALE_V18_SUCCESS_STATUS
        else:
            raise AssertionError(field)
        with tempfile.TemporaryDirectory() as temp_dir:
            tampered_path = Path(temp_dir) / f"v20_{field}_mismatch_negative_control.json"
            tampered_path.write_text(json.dumps(protocol), encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, message):
                verifier.validate_candidate(tampered_path)

    def test_v20_step_and_task_labels_are_version_bound(self):
        protocol = json.loads(V20_PROTOCOL_PATH.read_text(encoding="utf-8"))
        step = protocol["steps"][0]
        contract = protocol["protocol_status_contract_v20"]
        argv = step["launcher_argv_template"]
        self.assertEqual(step["name"], "direct_actual_freegs_fixed_observed_box_picard_policy_v20_status_contract")
        self.assertEqual(contract["step_name"], step["name"])
        self.assertEqual(argv[argv.index("--name") + 1], contract["supervisor_task_name"])
        self.assertEqual(contract["supervisor_task_name"], "native-axisymmetric-v9-fixed-box-picard-v20-status-contract")


if __name__ == "__main__":
    unittest.main(verbosity=2)
