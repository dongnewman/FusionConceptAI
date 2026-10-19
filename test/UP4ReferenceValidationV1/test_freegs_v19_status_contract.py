"""Python-only regression tests for the FreeGS v19 protocol status binding."""

from __future__ import annotations

import ast
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
VERIFIER_PATH = ROOT / "tools/up4_reference_validation/verify_freegs_v19_protocol_status_candidate.py"
RUNNER_PATH = ROOT / "tools/up4_reference_validation/runtime_v4_freegs_axisymmetric_profile_runner_v9.py"
V18_PROTOCOL_PATH = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v9/actual_run_protocol_v18_candidate_v1.json"
V19_PROTOCOL_PATH = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v10/actual_run_protocol_v19_candidate_v1.json"
EXPECTED_STATUS = "test_only_fixed_observed_box_dirichlet_policy_v2_converged_residual_measured"


def load_verifier():
    spec = importlib.util.spec_from_file_location("freegs_v19_protocol_verifier", VERIFIER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load v19 static verifier")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FreeGSV19StatusContractTests(unittest.TestCase):
    def test_declared_success_status_matches_pinned_runner_assignment(self):
        verifier = load_verifier()
        tree = ast.parse(RUNNER_PATH.read_text(encoding="utf-8"))
        self.assertEqual(verifier.runner_success_status(tree), EXPECTED_STATUS)
        protocol = json.loads(V19_PROTOCOL_PATH.read_text(encoding="utf-8"))
        step = protocol["steps"][0]
        self.assertEqual(step["result_exit_schema_contract"]["success"]["required_status"], EXPECTED_STATUS)
        self.assertEqual(protocol["protocol_status_contract_v19"]["runner_emitted_success_status"], EXPECTED_STATUS)

    def test_stale_v18_status_is_rejected_against_runner_output(self):
        verifier = load_verifier()
        tree = ast.parse(RUNNER_PATH.read_text(encoding="utf-8"))
        emitted = verifier.runner_success_status(tree)
        old_protocol = json.loads(V18_PROTOCOL_PATH.read_text(encoding="utf-8"))
        stale = old_protocol["steps"][0]["result_exit_schema_contract"]["success"]["required_status"]
        self.assertEqual(stale, verifier.STALE_V18_SUCCESS_STATUS)
        self.assertFalse(verifier.status_contract_accepts(stale, emitted))

    def test_static_verifier_rejects_a_protocol_tampered_back_to_v18_status(self):
        verifier = load_verifier()
        protocol = json.loads(V19_PROTOCOL_PATH.read_text(encoding="utf-8"))
        protocol["steps"][0]["result_exit_schema_contract"]["success"]["required_status"] = (
            verifier.STALE_V18_SUCCESS_STATUS
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            tampered_path = Path(temp_dir) / "v19_status_mismatch_negative_control.json"
            tampered_path.write_text(json.dumps(protocol), encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "protocol success status differs"):
                verifier.validate_candidate(tampered_path)

    def test_v19_step_and_task_labels_are_version_bound(self):
        protocol = json.loads(V19_PROTOCOL_PATH.read_text(encoding="utf-8"))
        step = protocol["steps"][0]
        contract = protocol["protocol_status_contract_v19"]
        argv = step["launcher_argv_template"]
        self.assertEqual(step["name"], "direct_actual_freegs_fixed_observed_box_picard_policy_v19_status_contract")
        self.assertEqual(contract["step_name"], step["name"])
        self.assertEqual(argv[argv.index("--name") + 1], contract["supervisor_task_name"])
        self.assertEqual(contract["supervisor_task_name"], "native-axisymmetric-v9-fixed-box-picard-v19-status-contract")


if __name__ == "__main__":
    unittest.main(verbosity=2)
