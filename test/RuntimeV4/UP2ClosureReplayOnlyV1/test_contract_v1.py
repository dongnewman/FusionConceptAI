"""Static contract checks for the isolated replay-only continuation."""
from __future__ import annotations

import hashlib
import json
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[3]
BASE = ROOT / "test/RuntimeV4/UP2ClosureReplayOnlyV1"
ARCHIVE = ROOT / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r1"
PROTOCOL_PATH = ARCHIVE / "replay_protocol_v1.json"


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class ReplayContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        cls.julia = (BASE / "replay_staged_v1.jl").read_text(encoding="utf-8")
        cls.runner = (BASE / "run_replay_staged_v1.py").read_text(encoding="utf-8")

    def test_protocol_is_test_only_and_preserves_gates(self) -> None:
        p = self.protocol
        self.assertEqual(p["schema"], "mms-replay-only-continuation-protocol-v1")
        self.assertEqual(p["classification"], "test_only_continuation")
        self.assertFalse(p["runtime_grant"])
        self.assertEqual(p["stage_limits"]["seconds"], 480)
        self.assertEqual(p["stage_limits"]["working_set_bytes"], 2**31)
        self.assertEqual(p["preserved_numerical_status"], {
            "status": "fail", "stopping_reason": "stationary_nonzero_residual", "solver_exit_code": 2,
            "physical_validation": "unsupported", "authority": "no_publish",
        })

    def test_frozen_producer_tree_and_all_source_hashes_are_complete(self) -> None:
        p = self.protocol
        v10 = ROOT / p["v10_protocol"]["path"]
        self.assertEqual(sha(v10), p["v10_protocol"]["sha256"])
        old = json.loads(v10.read_text(encoding="utf-8"))
        self.assertEqual(len(old["inputs"]), 89)
        for entry in old["inputs"]:
            path = ROOT / entry["path"]
            self.assertEqual(path.stat().st_size, entry["bytes"], entry["path"])
            self.assertEqual(sha(path), entry["sha256"], entry["path"])
        self.assertEqual(len(p["saved_producer_tree"]["entries"]), p["saved_producer_tree"]["file_count"])
        for entry in p["saved_producer_tree"]["entries"]:
            path = ROOT / entry["path"]
            self.assertEqual(path.stat().st_size, entry["bytes"], entry["path"])
            self.assertEqual(sha(path), entry["sha256"], entry["path"])
        for entry in p["replay_inputs"].values():
            path = ROOT / entry["path"]
            self.assertEqual(path.stat().st_size, entry["bytes"], entry["path"])
            self.assertEqual(sha(path), entry["sha256"], entry["path"])
        source_map = p["owned_source_files_by_path"]
        for entry in p["owned_source_files"]:
            path = ROOT / entry["path"]
            self.assertTrue(path.is_file(), entry["path"])
            self.assertEqual(sha(path), entry["sha256"], entry["path"])
            self.assertEqual(source_map[entry["path"]], entry["sha256"])
        for entry in p["owned_evidence_docs"]:
            path = ROOT / entry["path"]
            self.assertTrue(path.is_file(), entry["path"])
            self.assertEqual(sha(path), entry["sha256"], entry["path"])
        result_path = ROOT / p["replay_inputs"]["numerical_result"]["path"]
        wire = result_path.read_bytes()
        self.assertTrue(wire.endswith(b"\n") and not wire.endswith(b"\n\n"))
        self.assertEqual(hashlib.sha256(wire[:-1]).hexdigest(), p["preserved_identity"]["result_hash"])
        timeout = p["v10_timeout_receipts"]
        for entry in timeout.values():
            path = ROOT / entry["path"]
            self.assertEqual(path.stat().st_size, entry["bytes"], entry["path"])
            self.assertEqual(sha(path), entry["sha256"], entry["path"])
        self.assertEqual(sha(ROOT / timeout["controller_inputs_before"]["path"]),
                         sha(ROOT / timeout["controller_inputs_after"]["path"]))
        controller_final = json.loads((ROOT / timeout["controller_final"]["path"]).read_text(encoding="utf-8"))
        self.assertEqual((controller_final["controller_exit_code"], controller_final["execution_classification"],
                          controller_final["software_batch_complete"]), (124, "resource_interruption", False))
        process_final = json.loads((ROOT / timeout["producer_process_final"]["path"]).read_text(encoding="utf-8"))
        self.assertEqual((process_final["exit_code"], process_final["stop_reason"], process_final["stage"]),
                         (15, "wall_timeout", "producer"))
        process_record = json.loads((ROOT / timeout["producer_process_record"]["path"]).read_text(encoding="utf-8"))
        self.assertEqual((process_record["exit_code"], process_record["stop_reason"]), (15, "wall_timeout"))
        for stdout_stderr in ("producer_stdout", "producer_stderr"):
            raw = timeout[stdout_stderr]
            key = stdout_stderr.removeprefix("producer_")
            self.assertEqual((process_record[key]["bytes"], process_record[key]["sha256"]),
                             (raw["bytes"], raw["sha256"]))

    def test_producer_performs_typed_full_replay_and_consumer(self) -> None:
        self.assertIn("JSON3.read(typed_wire, S.SpatialManufacturedNumericalResultV1)", self.julia)
        self.assertIn("_smr_read_canonical_json_v1(wire)", self.julia)
        self.assertIn("S.validate_spatial_manufactured_result_v1(context, result)", self.julia)
        self.assertIn("M.result_tests(context, result, out)", self.julia)
        self.assertIn("canonical_json(result) * \"\\n\" == wire", self.julia)
        self.assertIn("solver_exit_code == 2", self.julia)
        self.assertIn("result.status == :fail", self.julia)
        self.assertIn("producer_validator_started.json", self.julia)
        self.assertIn("producer_validator_completed.json", self.julia)
        self.assertIn("consumer_suite_started.json", self.julia)
        self.assertIn("consumer_suite_completed.json", self.julia)

    def test_no_solver_or_production_writer_entrypoint_is_called(self) -> None:
        forbidden = (
            "execute_spatial_manufactured_numerical_v1(",
            "solve_spatial_state_v4(",
            "_smr_write_case(",
        )
        for token in forbidden:
            self.assertNotIn(token, self.julia)
        self.assertIn("--root-serial-slot-granted", self.runner)
        self.assertIn("time.sleep(0.25)", self.runner)
        self.assertIn("working_set_limit", self.runner)
        self.assertIn("runtime_hit", self.runner)
        self.assertIn("python_executable", self.runner)
        self.assertIn("original v10 controller timeout/failure semantics changed", self.runner)
        self.assertIn("saved numerical failure/solver exit 2 semantics changed", self.runner)
        self.assertIn("original v10 raw process output receipt mismatch", self.runner)

    def test_output_is_confined_to_new_archive_leaf(self) -> None:
        self.assertIn("replay_only_continuation_r1", self.runner)
        self.assertIn("runtime_replay_r1", self.protocol["output_leaf"])
        self.assertNotIn("runtime_manufactured_staged_r1", self.protocol["output_leaf"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
