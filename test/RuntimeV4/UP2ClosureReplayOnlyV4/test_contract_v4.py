"""Static-only preflight and hydration-source contracts for replay continuation V4."""
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
BASE = ROOT / "test/RuntimeV4/UP2ClosureReplayOnlyV4"
ARCHIVE = ROOT / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r4"
PROTOCOL_PATH = ARCHIVE / "replay_protocol_v4.json"
EXPECTED_OUTPUT = ARCHIVE / "runtime_replay_r4"
RUNNER_PATH = BASE / "run_replay_staged_v4.py"
JULIA_PATH = BASE / "replay_staged_v4.jl"


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_runner():
    spec = importlib.util.spec_from_file_location("up2_replay_only_v4_runner_contract", RUNNER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot import the replay v4 controller for static contract checks")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


RUNNER = load_runner()


class ReplayContractV4Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        cls.julia = JULIA_PATH.read_text(encoding="utf-8")
        cls.runner = RUNNER_PATH.read_text(encoding="utf-8")

    def test_protocol_keeps_test_only_identity_and_all_gates(self) -> None:
        p = self.protocol
        self.assertEqual(p["schema"], "mms-replay-only-continuation-protocol-v4")
        self.assertEqual(p["classification"], "test_only_continuation")
        self.assertIs(p["runtime_grant"], False)
        self.assertEqual(p["stage_limits"]["seconds"], 480)
        self.assertEqual(p["stage_limits"]["working_set_bytes"], 2**31)
        self.assertEqual(p["preserved_numerical_status"], {
            "status": "fail", "stopping_reason": "stationary_nonzero_residual", "solver_exit_code": 2,
            "physical_validation": "unsupported", "authority": "no_publish",
        })
        self.assertEqual(p["output_leaf"],
                         "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r4/runtime_replay_r4")
        self.assertFalse(EXPECTED_OUTPUT.exists(), "static checks must not create a replay output leaf")

    def test_parent_protocols_and_independent_v3_postrun_review_are_bound(self) -> None:
        p = self.protocol
        for key in ("parent_v3_protocol", "parent_v2_protocol", "parent_v1_protocol"):
            item = p[key]
            self.assertEqual(sha(ROOT / item["path"]), item["sha256"], key)
        review = p["parent_v3_independent_postrun_review"]
        self.assertEqual(sha(ROOT / review["report_path"]), review["report_sha256"])
        self.assertEqual(sha(ROOT / review["manifest_path"]), review["manifest_sha256"])
        self.assertEqual(p["parent_v3_protocol"]["sha256"],
                         "aaf637125b23de17d11d3da186aaa96811f74d085ed635a2f88a0d10f7de99bd")

    def test_v3_failure_evidence_is_exact_and_fail_closed(self) -> None:
        evidence = self.protocol["v3_runtime_failure"]
        checked = RUNNER.verify_v3_runtime_failure(ROOT, evidence)
        self.assertEqual(checked["final"]["classification"], "replay_hydration_unsupported")
        self.assertEqual(checked["final"]["controller_exit_code"], 72)
        self.assertEqual(checked["producer"]["exit_code"], 72)
        self.assertEqual(checked["failure"]["solver_exit_code"], 2)
        self.assertEqual(checked["failure"]["numerical_status"], "fail")
        self.assertEqual(sha(checked["paths"]["final"]),
                         "4ab312c74627b284496a1c149e0286235224381fc5b6ff8c7d3d067ca7d6959a")
        self.assertEqual(sha(checked["paths"]["inputs_before"]),
                         "88cb39a376c9f4c418ed64a73e608c7931761007b9bfadb476c010537d2e2689")
        self.assertEqual(sha(checked["paths"]["inputs_after"]),
                         "88cb39a376c9f4c418ed64a73e608c7931761007b9bfadb476c010537d2e2689")
        self.assertFalse(EXPECTED_OUTPUT.exists())

        changed = copy.deepcopy(evidence)
        changed["entries"][0]["bytes"] += 1
        with self.assertRaisesRegex(ValueError, "inventory drift"):
            RUNNER.verify_v3_runtime_failure(ROOT, changed)
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_source_expression_uses_an_unambiguous_positional_namedtuple(self) -> None:
        fixed = "merge(body, (; result_hash=(value=string(result_hash),)))"
        v3_source = ROOT / "test/RuntimeV4/UP2ClosureReplayOnlyV3/replay_staged_v3.jl"
        broken = "merge(body, (result_hash=(value=string(result_hash),)))"
        self.assertIn(fixed, self.julia)
        self.assertNotIn(broken, self.julia)
        self.assertIn(broken, v3_source.read_text(encoding="utf-8"))
        self.assertIn("typed_body = merge(body, (; result_hash=(value=string(result_hash),)))", self.julia)

    def test_hydration_phases_are_marked_without_weakening_checks(self) -> None:
        phases = (
            "canonical_body_parse", "semantic_hash_recompute", "result_digest_injection", "typed_wire_encoding",
            "json3_typed_parse", "concrete_type_check", "canonical_result_hash_check",
            "protocol_result_hash_check", "canonical_wire_roundtrip",
        )
        for phase in phases:
            self.assertIn(f'active_phase[] = "{phase}"', self.julia)
            self.assertIn(f'hydration_checkpoint!(out, "{phase}"', self.julia)
        self.assertIn("hydration_stage=hydration_phase[]", self.julia)

    def test_full_validator_consumer_and_failure_semantics_stay_mandatory(self) -> None:
        for token in (
            "S._smr_read_canonical_json_v1(wire)",
            "JSON3.read(typed_wire, S.SpatialManufacturedNumericalResultV1)",
            "canonical_hash(result) == result_hash",
            'canonical_json(result) * "\\n" == wire',
            "S.validate_spatial_manufactured_result_v1(context, result)",
            "M.result_tests(context, result, out)",
            "solver_exit_code == 2", "result.status == :fail", ":stationary_nonzero_residual",
            "producer_validator_started.json", "producer_validator_completed.json",
            "consumer_suite_started.json", "consumer_suite_completed.json",
        ):
            self.assertIn(token, self.julia)
        for token in ("execute_spatial_manufactured_numerical_v1(", "solve_spatial_state_v4(", "_smr_write_case("):
            self.assertNotIn(token, self.julia)
        self.assertIn("runtime_hit", self.runner)
        self.assertIn("working_set_limit", self.runner)
        self.assertIn("wall_timeout", self.runner)
        self.assertIn("--root-serial-slot-granted", self.runner)

    def test_v10_89_pins_and_partial_producer_tree_remain_identical(self) -> None:
        p = self.protocol
        v10 = ROOT / p["v10_protocol"]["path"]
        self.assertEqual(sha(v10), p["v10_protocol"]["sha256"])
        old = json.loads(v10.read_text(encoding="utf-8"))
        self.assertEqual(len(old["inputs"]), 89)
        self.assertEqual(p["v10_protocol"]["pinned_input_count"], 89)
        for entry in old["inputs"]:
            path = ROOT / entry["path"]
            self.assertEqual(path.stat().st_size, entry["bytes"], entry["path"])
            self.assertEqual(sha(path), entry["sha256"], entry["path"])
        tree = p["saved_producer_tree"]
        self.assertEqual(tree["file_count"], 119)
        self.assertEqual(len(tree["entries"]), 119)
        for entry in tree["entries"]:
            path = ROOT / entry["path"]
            self.assertEqual(path.stat().st_size, entry["bytes"], entry["path"])
            self.assertEqual(sha(path), entry["sha256"], entry["path"])
        for entry in p["replay_inputs"].values():
            path = ROOT / entry["path"]
            self.assertEqual(path.stat().st_size, entry["bytes"], entry["path"])
            self.assertEqual(sha(path), entry["sha256"], entry["path"])

    def test_source_inventory_and_evidence_hashes_match_protocol(self) -> None:
        for entry in self.protocol["owned_source_files"] + self.protocol["owned_evidence_docs"]:
            path = ROOT / entry["path"]
            self.assertTrue(path.is_file(), entry["path"])
            self.assertEqual(path.stat().st_size, entry["bytes"], entry["path"])
            self.assertEqual(sha(path), entry["sha256"], entry["path"])
        self.assertEqual(len(self.protocol["owned_source_files"]), 3)

    def test_preflight_validation_precedes_output_creation_and_child_launch(self) -> None:
        tree = ast.parse(self.runner)
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "main")
        calls = []
        for node in ast.walk(main):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                if node.func.id in ("verify_v3_runtime_failure", "verify_v10_timeout_receipts", "run_stage"):
                    calls.append((node.func.id, node.lineno))
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "mkdir":
                calls.append(("output_mkdir", node.lineno))
        lines = {}
        for name, line in calls:
            lines.setdefault(name, []).append(line)
        self.assertEqual(len(lines["verify_v3_runtime_failure"]), 1)
        self.assertEqual(len(lines["verify_v10_timeout_receipts"]), 1)
        self.assertEqual(len(lines["output_mkdir"]), 1)
        self.assertGreaterEqual(len(lines["run_stage"]), 2)
        self.assertLess(lines["verify_v3_runtime_failure"][0], lines["output_mkdir"][0])
        self.assertLess(lines["verify_v10_timeout_receipts"][0], lines["output_mkdir"][0])
        self.assertLess(lines["output_mkdir"][0], min(lines["run_stage"]))
        self.assertFalse(EXPECTED_OUTPUT.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
