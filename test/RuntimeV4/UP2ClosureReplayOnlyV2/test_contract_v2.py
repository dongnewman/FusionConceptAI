"""Static and pre-Julia receipt contracts for replay-only continuation v2."""
from __future__ import annotations

import ast
import copy
import hashlib
import importlib.util
import json
import pathlib
import sys
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[3]
BASE = ROOT / "test/RuntimeV4/UP2ClosureReplayOnlyV2"
ARCHIVE = ROOT / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r2"
PROTOCOL_PATH = ARCHIVE / "replay_protocol_v2.json"
EXPECTED_OUTPUT = ARCHIVE / "runtime_replay_r2"
RUNNER_PATH = BASE / "run_replay_staged_v2.py"


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_runner():
    spec = importlib.util.spec_from_file_location("up2_replay_only_v2_runner_contract", RUNNER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot import the replay v2 controller for preflight contract tests")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


RUNNER = load_runner()


class ReplayContractV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        cls.julia = (BASE / "replay_staged_v2.jl").read_text(encoding="utf-8")
        cls.runner = RUNNER_PATH.read_text(encoding="utf-8")

    def test_protocol_is_test_only_and_keeps_all_original_gates(self) -> None:
        p = self.protocol
        self.assertEqual(p["schema"], "mms-replay-only-continuation-protocol-v2")
        self.assertEqual(p["classification"], "test_only_continuation")
        self.assertFalse(p["runtime_grant"])
        self.assertEqual(p["stage_limits"]["seconds"], 480)
        self.assertEqual(p["stage_limits"]["working_set_bytes"], 2**31)
        self.assertEqual(p["preserved_numerical_status"], {
            "status": "fail", "stopping_reason": "stationary_nonzero_residual", "solver_exit_code": 2,
            "physical_validation": "unsupported", "authority": "no_publish",
        })
        self.assertEqual(p["parent_v1_protocol"]["path"],
                         "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r1/replay_protocol_v1.json")
        self.assertEqual(sha(ROOT / p["parent_v1_protocol"]["path"]), p["parent_v1_protocol"]["sha256"])
        failure = p["v1_preflight_failure"]
        failure_receipt_path = ROOT / failure["receipt_path"]
        failure_receipt = json.loads(failure_receipt_path.read_text(encoding="utf-8"))
        self.assertEqual(sha(failure_receipt_path), failure["receipt_sha256"])
        self.assertEqual(sha(ROOT / failure["stderr_path"]), failure["stderr_sha256"])
        self.assertEqual(sha(ROOT / failure["stdout_path"]), failure["stdout_sha256"])
        self.assertEqual((failure_receipt["source_sha256"], failure_receipt["protocol_sha256"], failure_receipt["natural_exit_code"],
                          failure_receipt["julia_started"], failure_receipt["output_directory_created"]),
                         ("baec84c3e9f7549ad800475753141717eb000fb3e001ff4579eaf0873b589eb8",
                          p["parent_v1_protocol"]["sha256"], 1, False, False))
        self.assertEqual(p["output_leaf"],
                         "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r2/runtime_replay_r2")

    def test_all_bound_v10_inputs_and_versioned_sources_match(self) -> None:
        p = self.protocol
        v10 = ROOT / p["v10_protocol"]["path"]
        self.assertEqual(sha(v10), p["v10_protocol"]["sha256"])
        old = json.loads(v10.read_text(encoding="utf-8"))
        self.assertEqual(len(old["inputs"]), 89)
        for entry in old["inputs"]:
            path = ROOT / entry["path"]
            self.assertEqual(path.stat().st_size, entry["bytes"], entry["path"])
            self.assertEqual(sha(path), entry["sha256"], entry["path"])
        tree = p["saved_producer_tree"]
        self.assertEqual(len(tree["entries"]), tree["file_count"])
        for entry in tree["entries"]:
            path = ROOT / entry["path"]
            self.assertEqual(path.stat().st_size, entry["bytes"], entry["path"])
            self.assertEqual(sha(path), entry["sha256"], entry["path"])
        for entry in p["replay_inputs"].values():
            path = ROOT / entry["path"]
            self.assertEqual(path.stat().st_size, entry["bytes"], entry["path"])
            self.assertEqual(sha(path), entry["sha256"], entry["path"])
        for entry in p["owned_source_files"] + p["owned_evidence_docs"]:
            path = ROOT / entry["path"]
            self.assertTrue(path.is_file(), entry["path"])
            self.assertEqual(path.stat().st_size, entry["bytes"], entry["path"])
            self.assertEqual(sha(path), entry["sha256"], entry["path"])
        result_path = ROOT / p["replay_inputs"]["numerical_result"]["path"]
        result_wire = result_path.read_bytes()
        self.assertTrue(result_wire.endswith(b"\n") and not result_wire.endswith(b"\n\n"))
        self.assertEqual(hashlib.sha256(result_wire[:-1]).hexdigest(), p["preserved_identity"]["result_hash"])

    def test_positive_preflight_reads_and_validates_every_timeout_receipt(self) -> None:
        self.assertEqual(set(RUNNER.V10_TIMEOUT_RECEIPT_KEYS), set(self.protocol["v10_timeout_receipts"]))
        result = RUNNER.verify_v10_timeout_receipts(ROOT, self.protocol["v10_timeout_receipts"])
        self.assertEqual(set(result["paths"]), set(RUNNER.V10_TIMEOUT_RECEIPT_KEYS))
        self.assertEqual(result["controller_final"]["controller_exit_code"], 124)
        self.assertEqual(result["controller_final"]["execution_classification"], "resource_interruption")
        self.assertFalse(result["controller_final"]["software_batch_complete"])
        self.assertEqual((result["original_stage"]["stop_reason"], result["original_stage"]["exit_code"]),
                         ("wall_timeout", 15))
        self.assertEqual((result["process_final"]["stop_reason"], result["process_final"]["exit_code"]),
                         ("wall_timeout", 15))
        self.assertEqual((result["process_record"]["stop_reason"], result["process_record"]["exit_code"]),
                         ("wall_timeout", 15))
        self.assertFalse(EXPECTED_OUTPUT.exists(), "pre-Julia receipt validation must not create replay output")

    def test_every_receipt_dereference_rejects_mapping_as_path_before_launch(self) -> None:
        original = self.protocol["v10_timeout_receipts"]
        for key in RUNNER.V10_TIMEOUT_RECEIPT_KEYS:
            with self.subTest(key=key):
                changed = copy.deepcopy(original)
                changed[key]["path"] = {"path": original[key]["path"]}
                with self.assertRaisesRegex(ValueError, "path"):
                    RUNNER.verify_v10_timeout_receipts(ROOT, changed)
                self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_malformed_missing_and_escaping_receipts_fail_closed(self) -> None:
        original = self.protocol["v10_timeout_receipts"]
        missing_path = copy.deepcopy(original)
        del missing_path["controller_final"]["path"]
        with self.assertRaisesRegex(ValueError, "path"):
            RUNNER.verify_v10_timeout_receipts(ROOT, missing_path)

        missing_receipt = copy.deepcopy(original)
        del missing_receipt["protocol_receipt"]
        with self.assertRaisesRegex(ValueError, "receipt set"):
            RUNNER.verify_v10_timeout_receipts(ROOT, missing_receipt)

        escaping = copy.deepcopy(original)
        escaping["controller_final"]["path"] = "../outside.json"
        with self.assertRaisesRegex(ValueError, "escapes"):
            RUNNER.verify_v10_timeout_receipts(ROOT, escaping)

        wrong_size = copy.deepcopy(original)
        wrong_size["producer_stdout"]["bytes"] += 1
        with self.assertRaisesRegex(ValueError, "drift"):
            RUNNER.verify_v10_timeout_receipts(ROOT, wrong_size)
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_preflight_is_in_main_before_output_creation_and_julia_launch(self) -> None:
        tree = ast.parse(self.runner)
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "main")
        helper_calls = [node.lineno for node in ast.walk(main)
                        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                        and node.func.id == "verify_v10_timeout_receipts"]
        bound_calls = [node.lineno for node in ast.walk(main)
                       if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                       and node.func.id == "verify_bound_sha256"]
        output_mkdir = [node.lineno for node in ast.walk(main)
                        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                        and node.func.attr == "mkdir"]
        stage_calls = [node.lineno for node in ast.walk(main)
                       if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                       and node.func.id == "run_stage"]
        self.assertEqual(len(helper_calls), 1)
        self.assertEqual(len(bound_calls), 4)
        self.assertEqual(len(output_mkdir), 1)
        self.assertGreaterEqual(len(stage_calls), 2)
        self.assertLess(helper_calls[0], output_mkdir[0])
        self.assertLess(max(bound_calls), output_mkdir[0])
        self.assertLess(helper_calls[0], min(stage_calls))

    def test_full_replay_validation_and_failure_semantics_remain_required(self) -> None:
        for token in (
            "JSON3.read(typed_wire, S.SpatialManufacturedNumericalResultV1)",
            "_smr_read_canonical_json_v1(wire)",
            "S.validate_spatial_manufactured_result_v1(context, result)",
            "M.result_tests(context, result, out)",
            "canonical_json(result) * \"\\n\" == wire",
            "solver_exit_code == 2",
            "result.status == :fail",
            "producer_validator_started.json", "producer_validator_completed.json",
            "consumer_suite_started.json", "consumer_suite_completed.json",
        ):
            self.assertIn(token, self.julia)
        for token in ("execute_spatial_manufactured_numerical_v1(", "solve_spatial_state_v4(", "_smr_write_case("):
            self.assertNotIn(token, self.julia)
        self.assertIn("--root-serial-slot-granted", self.runner)
        self.assertIn("working_set_limit", self.runner)
        self.assertIn("wall_timeout", self.runner)
        self.assertIn("runtime_hit", self.runner)


if __name__ == "__main__":
    unittest.main(verbosity=2)
