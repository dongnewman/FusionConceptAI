"""Static-only preflight and hydration-source contracts for replay continuation V6."""
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
BASE = ROOT / "test/RuntimeV4/UP2ClosureReplayOnlyV6"
ARCHIVE = ROOT / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r6"
PROTOCOL_PATH = ARCHIVE / "replay_protocol_v6.json"
EXPECTED_OUTPUT = ARCHIVE / "runtime_replay_r6"
RUNNER_PATH = BASE / "run_replay_staged_v6.py"
JULIA_PATH = BASE / "replay_staged_v6.jl"


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_runner():
    spec = importlib.util.spec_from_file_location("up2_replay_only_v6_runner_contract", RUNNER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot import the replay v6 controller for static contract checks")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


RUNNER = load_runner()


class ReplayContractV6Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        cls.julia = JULIA_PATH.read_text(encoding="utf-8")
        cls.runner = RUNNER_PATH.read_text(encoding="utf-8")

    def test_protocol_keeps_test_only_identity_and_all_gates(self) -> None:
        p = self.protocol
        self.assertEqual(p["schema"], "mms-replay-only-continuation-protocol-v6")
        self.assertEqual(p["classification"], "test_only_continuation")
        self.assertIs(p["runtime_grant"], False)
        self.assertEqual(p["stage_limits"]["seconds"], 480)
        self.assertEqual(p["stage_limits"]["working_set_bytes"], 2**31)
        self.assertEqual(p["preserved_numerical_status"], {
            "status": "fail", "stopping_reason": "stationary_nonzero_residual", "solver_exit_code": 2,
            "physical_validation": "unsupported", "authority": "no_publish",
        })
        self.assertEqual(p["output_leaf"],
                         "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r6/runtime_replay_r6")
        self.assertFalse(EXPECTED_OUTPUT.exists(), "static checks must not create a replay output leaf")

    def test_parent_protocols_and_independent_v3_postrun_review_are_bound(self) -> None:
        p = self.protocol
        for key in ("parent_v4_protocol", "parent_v3_protocol", "parent_v2_protocol", "parent_v1_protocol"):
            item = p[key]
            self.assertEqual(sha(ROOT / item["path"]), item["sha256"], key)
        self.assertEqual(p["parent_v4_protocol"]["sha256"],
                         "bcc29b37f538c73d67680c5378910ab8ac0da3e68e26c42fa14ee19b47636238")
        no_go = p["parent_v4_no_go_review"]
        self.assertEqual(sha(ROOT / no_go["report_path"]), no_go["report_sha256"])
        self.assertEqual(sha(ROOT / no_go["manifest_path"]), no_go["manifest_sha256"])
        report = (ROOT / no_go["report_path"]).read_text(encoding="utf-8")
        self.assertIn("NO-GO", report)
        self.assertIn("child_command_contract", report)
        self.assertIn("output_leaf", report)
        review = p["parent_v3_independent_postrun_review"]
        self.assertEqual(sha(ROOT / review["report_path"]), review["report_sha256"])
        self.assertEqual(sha(ROOT / review["manifest_path"]), review["manifest_sha256"])
        self.assertEqual(p["parent_v3_protocol"]["sha256"],
                         "aaf637125b23de17d11d3da186aaa96811f74d085ed635a2f88a0d10f7de99bd")

    def test_v5_no_go_review_and_protocol_are_bound(self) -> None:
        p = self.protocol
        parent = p["parent_v5_protocol"]
        self.assertEqual(sha(ROOT / parent["path"]), parent["sha256"])
        no_go = p["parent_v5_no_go_review"]
        self.assertEqual(no_go["classification"], "NO-GO")
        self.assertEqual(sha(ROOT / no_go["report_path"]), no_go["report_sha256"])
        self.assertEqual(sha(ROOT / no_go["manifest_path"]), no_go["manifest_sha256"])
        report = (ROOT / no_go["report_path"]).read_text(encoding="utf-8")
        self.assertIn("argv[6]", report)
        self.assertIn("literal argv vectors differ", report)

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

    def test_output_target_must_equal_the_frozen_protocol_leaf(self) -> None:
        expected = RUNNER.resolve_output_target(ROOT, EXPECTED_OUTPUT, self.protocol["output_leaf"])
        self.assertEqual(expected, EXPECTED_OUTPUT.resolve())
        relative = EXPECTED_OUTPUT.relative_to(ROOT)
        self.assertEqual(RUNNER.resolve_output_target(ROOT, relative, self.protocol["output_leaf"]), expected)
        relative = EXPECTED_OUTPUT.relative_to(ROOT)
        self.assertEqual(RUNNER.resolve_output_target(ROOT, relative, self.protocol["output_leaf"]), expected)
        sibling = EXPECTED_OUTPUT.parent / "runtime_replay_r6_sibling"
        with self.assertRaisesRegex(ValueError, "exactly to protocol output_leaf"):
            RUNNER.resolve_output_target(ROOT, sibling, self.protocol["output_leaf"])
        with self.assertRaisesRegex(ValueError, "V6 replay-only archive"):
            RUNNER.resolve_output_target(ROOT, ROOT / "tmp" / "outside_replay_leaf", self.protocol["output_leaf"])
        self.assertFalse(EXPECTED_OUTPUT.exists())
        self.assertFalse(sibling.exists())

    def test_protocol_child_argv_equals_actual_main_launch_assembly(self) -> None:
        p = self.protocol
        RUNNER.verify_child_command_contract(p)
        producer = RUNNER.build_producer_launch_command(
            p, p["runtime"]["julia_executable"], "<new-producer-numerical-dir>", "<protocol-sha256>")
        consumer = RUNNER.build_consumer_launch_command(
            p, p["runtime"]["julia_executable"], "<new-consumer-numerical-dir>",
            "<new-producer-numerical-dir>", "<protocol-sha256>",
            "<controller-sealed-carrier-sha256>", "<controller-sealed-binding-sha256>")
        self.assertEqual(producer, p["child_command_contract"]["producer"])
        self.assertEqual(consumer, p["child_command_contract"]["consumer"])
        self.assertEqual(producer[3], p["entrypoint"])
        self.assertEqual(producer[6], p["saved_producer_tree"]["root"])
        self.assertFalse(pathlib.Path(producer[6]).is_absolute())

        def assert_main_uses_assembly(source: str, mode: str) -> None:
            tree = ast.parse(source)
            main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "main")
            var = "producer_cmd" if mode == "producer" else "consumer_cmd"
            helper = f"build_{mode}_launch_command"
            assignments = [node for node in ast.walk(main) if isinstance(node, ast.Assign)
                           and any(isinstance(target, ast.Name) and target.id == var for target in node.targets)]
            self.assertEqual(len(assignments), 1)
            call = assignments[0].value
            self.assertIsInstance(call, ast.Call)
            self.assertIsInstance(call.func, ast.Name)
            self.assertEqual(call.func.id, helper)
            run_calls = [node for node in ast.walk(main) if isinstance(node, ast.Call)
                         and isinstance(node.func, ast.Name) and node.func.id == "run_stage"
                         and node.args and isinstance(node.args[0], ast.Name) and node.args[0].id == var]
            self.assertEqual(len(run_calls), 1)
            expected_args = (["protocol", "julia", "producer_root", "actual_protocol_sha"] if mode == "producer"
                             else ["protocol", "julia", "consumer_root", "producer_root", "actual_protocol_sha"])
            actual_args = [arg.id for arg in call.args if isinstance(arg, ast.Name)]
            self.assertEqual(actual_args, expected_args)
            if mode == "consumer":
                self.assertEqual(len(call.args), 7)
                for node, field in zip(call.args[5:], ("carrier_sha256", "binding_sha256")):
                    self.assertIsInstance(node, ast.Call)
                    self.assertIsInstance(node.func, ast.Name)
                    self.assertEqual(node.func.id, "str")
                    self.assertIsInstance(node.args[0], ast.Subscript)
                    self.assertIsInstance(node.args[0].value, ast.Name)
                    self.assertEqual(node.args[0].value.id, "seal")
                    self.assertEqual(node.args[0].slice.value, field)

        assert_main_uses_assembly(self.runner, "producer")
        assert_main_uses_assembly(self.runner, "consumer")
        self.assertIn('if protocol.get("entrypoint") != entrypoint:', self.runner)
        mutated = self.runner.replace(
            "producer_cmd = build_producer_launch_command(protocol, julia, producer_root, actual_protocol_sha)",
            'producer_cmd = build_child_command(julia, entrypoint, "producer", producer_root, tree_root, actual_protocol_sha)')
        self.assertNotEqual(mutated, self.runner)
        with self.assertRaises(AssertionError):
            assert_main_uses_assembly(mutated, "producer")

        mutated = copy.deepcopy(p)
        mutated["child_command_contract"]["producer"][3] = "test/RuntimeV4/UP2ClosureReplayOnlyV4/replay_staged_v4.jl"
        with self.assertRaisesRegex(ValueError, "controller-generated argv"):
            RUNNER.verify_child_command_contract(mutated)

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
        for token in ("execute_spatial_manufactured_numerical_v1(", "solve_spatial_state_v5(", "_smr_write_case("):
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
                if node.func.id in ("resolve_output_target", "verify_child_command_contract",
                                    "verify_v3_runtime_failure", "verify_v10_timeout_receipts", "run_stage"):
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
        self.assertEqual(len(lines["resolve_output_target"]), 1)
        self.assertEqual(len(lines["verify_child_command_contract"]), 1)
        self.assertLess(lines["resolve_output_target"][0], lines["output_mkdir"][0])
        self.assertLess(lines["verify_child_command_contract"][0], lines["output_mkdir"][0])
        self.assertLess(lines["verify_v3_runtime_failure"][0], lines["output_mkdir"][0])
        self.assertLess(lines["verify_v10_timeout_receipts"][0], lines["output_mkdir"][0])
        self.assertLess(lines["output_mkdir"][0], min(lines["run_stage"]))
        self.assertFalse(EXPECTED_OUTPUT.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
