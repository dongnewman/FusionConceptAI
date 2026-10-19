"""Static-only preflight and hydration-source contracts for replay continuation V8."""
from __future__ import annotations

import ast
import contextlib
import copy
import hashlib
import io
import importlib.util
import json
import pathlib
import sys
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[3]
BASE = ROOT / "test/RuntimeV4/UP2ClosureReplayOnlyV8"
ARCHIVE = ROOT / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r8"
PROTOCOL_PATH = ARCHIVE / "replay_protocol_v8.json"
EXPECTED_OUTPUT = ARCHIVE / "runtime_replay_r8"
RUNNER_PATH = BASE / "run_replay_staged_v8.py"
JULIA_PATH = BASE / "replay_staged_v8.jl"


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_runner():
    spec = importlib.util.spec_from_file_location("up2_replay_only_v8_runner_contract", RUNNER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot import the replay v8 controller for static contract checks")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


RUNNER = load_runner()


class ReplayContractV8Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        cls.julia = JULIA_PATH.read_text(encoding="utf-8")
        cls.runner = RUNNER_PATH.read_text(encoding="utf-8")

    def test_protocol_keeps_test_only_identity_and_all_gates(self) -> None:
        p = self.protocol
        self.assertEqual(p["schema"], "mms-replay-only-continuation-protocol-v8")
        self.assertEqual(p["classification"], "test_only_continuation")
        self.assertIs(p["runtime_grant"], False)
        self.assertEqual(p["stage_limits"]["seconds"], 480)
        self.assertEqual(p["stage_limits"]["working_set_bytes"], 2**31)
        self.assertEqual(p["total_child_wall_limit_seconds"], 960)
        self.assertEqual(p["termination_cleanup_grace_seconds"], 6)
        self.assertIn("bounded cleanup", p["aggregate_child_wall_definition"])
        self.assertEqual(p["controller_overhead_seconds_limit"], 120)
        self.assertIn("before the read-only preflight", p["controller_overhead_definition"])
        self.assertIn("controller_overhead_budget", p["receipt_contract"])
        self.assertEqual(p["preserved_numerical_status"], {
            "status": "fail", "stopping_reason": "stationary_nonzero_residual", "solver_exit_code": 2,
            "physical_validation": "unsupported", "authority": "no_publish",
        })
        self.assertEqual(p["output_leaf"],
                         "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r8/runtime_replay_r8")
        self.assertFalse(EXPECTED_OUTPUT.exists(), "static checks must not create a replay output leaf")

    def test_v7_aggregate_limit_no_go_is_bound_as_ancestry(self) -> None:
        p = self.protocol
        self.assertEqual(sha(ROOT / p["parent_v7_protocol"]["path"]), p["parent_v7_protocol"]["sha256"])
        review = p["parent_v7_independent_review"]
        self.assertEqual(review["classification"], "NO-GO for runtime grant")
        self.assertEqual(sha(ROOT / review["report_path"]), review["report_sha256"])
        self.assertEqual(sha(ROOT / review["manifest_path"]), review["manifest_sha256"])
        self.assertEqual(sha(ROOT / review["commands_path"]), review["commands_sha256"])
        checked = RUNNER.verify_v7_no_go_ancestry(ROOT, p["parent_v7_protocol"], review)
        self.assertFalse(checked["report_path"].is_relative_to(EXPECTED_OUTPUT))

    def test_aggregate_wall_contract_rejects_underbudget_before_output(self) -> None:
        protocol = copy.deepcopy(self.protocol)
        protocol["total_child_wall_limit_seconds"] = 959
        with self.assertRaisesRegex(ValueError, "below combined producer/consumer stage caps"):
            RUNNER.validate_aggregate_child_wall_contract(protocol)
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_consumer_budget_accounts_for_producer_cleanup_and_refuses_boundary(self) -> None:
        after_producer_cleanup = RUNNER.stage_child_wall_budget(960, 486, 480, 6)
        self.assertEqual(after_producer_cleanup["remaining_before_seconds"], 474)
        self.assertEqual(after_producer_cleanup["live_limit_seconds"], 467.75)
        self.assertLessEqual(after_producer_cleanup["live_limit_seconds"], 480)

        # At exactly cleanup grace plus poll reserve there is no safe live window.
        with self.assertRaisesRegex(RUNNER.AggregateChildWallBudgetExhausted, "remaining=6.250000000s"):
            RUNNER.stage_child_wall_budget(960, 953.75, 480, 6)
        with self.assertRaisesRegex(RUNNER.AggregateChildWallBudgetExhausted, "remaining=-0.001000000s"):
            RUNNER.stage_child_wall_budget(960, 960.001, 480, 6)
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_controller_overhead_includes_preflight_and_times_out_before_output_or_child(self) -> None:
        self.assertEqual(RUNNER.controller_overhead_seconds(10.0, 130.0, 0.0), 120.0)
        self.assertEqual(RUNNER.controller_overhead_seconds(10.0, 620.0, 490.0), 120.0)
        self.assertEqual(RUNNER.enforce_controller_overhead_budget(10.0, 20.0, 120.0, now=129.0), 99.0)
        with self.assertRaisesRegex(RUNNER.ControllerOverheadBudgetExhausted, "elapsed=121.000000000s"):
            RUNNER.enforce_controller_overhead_budget(10.0, 0.0, 120.0, now=131.0)
        with self.assertRaisesRegex(RUNNER.ControllerOverheadBudgetExhausted, "elapsed=121.000000000s"):
            RUNNER.enforce_controller_overhead_budget(10.0, 490.0, 120.0, now=621.0)

        argv = [
            "run_replay_staged_v8.py", "--protocol", str(PROTOCOL_PATH),
            "--protocol-sha256", sha(PROTOCOL_PATH), "--output", str(EXPECTED_OUTPUT),
            "--root-serial-slot-granted",
        ]
        clock_values = iter((100.0, 221.0))

        def slow_preflight_clock() -> float:
            return next(clock_values, 221.0)

        captured = io.StringIO()
        with mock.patch.object(RUNNER.time, "monotonic", side_effect=slow_preflight_clock), \
                mock.patch.object(RUNNER.subprocess, "Popen") as popen, \
                mock.patch.object(sys, "argv", argv), contextlib.redirect_stdout(captured):
            self.assertEqual(RUNNER.main(), 124)
        receipt = json.loads(captured.getvalue())
        self.assertEqual(receipt["classification"], "resource_interruption")
        self.assertEqual(receipt["phase"], "pre_output_preflight")
        self.assertEqual(receipt["controller_overhead_seconds"], 121.0)
        self.assertEqual(receipt["controller_overhead_overrun_seconds"], 1.0)
        self.assertIs(receipt["output_leaf_created"], False)
        self.assertIs(receipt["child_process_started"], False)
        popen.assert_not_called()
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_main_launches_each_stage_with_shared_aggregate_budget(self) -> None:
        tree = ast.parse(self.runner)
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "main")
        calls = [node for node in ast.walk(main) if isinstance(node, ast.Call)
                 and isinstance(node.func, ast.Name)]
        budget_assignments = [node for node in ast.walk(main) if isinstance(node, ast.Assign)
                              and any(isinstance(target, ast.Name) and target.id in
                                      ("producer_budget", "consumer_budget") for target in node.targets)]
        self.assertEqual(len(budget_assignments), 2)
        self.assertTrue(all(isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name)
                            and node.value.func.id == "stage_child_wall_budget"
                            for node in budget_assignments))
        stage_calls = [node for node in calls if node.func.id == "run_stage"]
        self.assertEqual(len(stage_calls), 2)
        for call, expected_name in zip(stage_calls, ("producer_budget", "consumer_budget")):
            self.assertEqual(len(call.args), 7)
            self.assertIsInstance(call.args[6], ast.Name)
            self.assertEqual(call.args[6].id, expected_name)

        runner_tree = ast.parse(self.runner)
        run_stage = next(node for node in runner_tree.body if isinstance(node, ast.FunctionDef)
                         and node.name == "run_stage")
        budget_raises = [node for node in ast.walk(run_stage) if isinstance(node, ast.Raise)
                         and isinstance(node.exc, ast.Call) and isinstance(node.exc.func, ast.Name)
                         and node.exc.func.id == "AggregateChildWallBudgetExhausted"]
        self.assertTrue(budget_raises)
        mkdir_line = next(node.lineno for node in ast.walk(run_stage) if isinstance(node, ast.Call)
                          and isinstance(node.func, ast.Attribute) and node.func.attr == "mkdir")
        self.assertLess(budget_raises[0].lineno, mkdir_line)
        self.assertIn("bounded_wait_deadline_monotonic", self.runner)
        self.assertIn("aggregate_child_wall_overrun_seconds", self.runner)
        self.assertFalse(EXPECTED_OUTPUT.exists())

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

    def test_v6_static_go_and_root_preflight_failure_are_preserved(self) -> None:
        p = self.protocol
        parent = p["parent_v6_protocol"]
        self.assertEqual(sha(ROOT / parent["path"]), parent["sha256"])
        review = p["parent_v6_independent_review"]
        self.assertEqual(review["classification"], "GO")
        self.assertEqual(sha(ROOT / review["report_path"]), review["report_sha256"])
        self.assertEqual(sha(ROOT / review["manifest_path"]), review["manifest_sha256"])
        attempt = p["parent_v6_root_attempt"]
        self.assertEqual(sha(ROOT / attempt["grant_path"]), attempt["grant_sha256"])
        self.assertEqual(sha(ROOT / attempt["observation_path"]), attempt["observation_sha256"])
        postrun = p["parent_v6_postrun_scopefix_review"]
        self.assertEqual(postrun["classification"], "NO-GO for retry")
        self.assertEqual(sha(ROOT / postrun["report_path"]), postrun["report_sha256"])
        self.assertEqual(sha(ROOT / postrun["manifest_path"]), postrun["manifest_sha256"])
        checked = RUNNER.verify_v6_root_preflight_failure(ROOT, parent, review, attempt, postrun)
        self.assertGreaterEqual(checked["postrun_review"]["manifest_entry_count"], 10)
        self.assertEqual(checked["observation"]["actual_historical_schema"], "mms-recorded-process-v3")
        self.assertEqual(checked["observation"]["shell_exit_code"], 1)
        self.assertFalse(checked["observation"]["output_leaf_exists"])
        self.assertFalse(checked["observation"]["julia_started"])
        changed_review = copy.deepcopy(postrun)
        changed_review["helper_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "relocated test-owned receipt helper"):
            RUNNER.verify_v6_postrun_scopefix_review(ROOT, changed_review)
        changed_review = copy.deepcopy(postrun)
        changed_review["classification"] = "GO"
        with self.assertRaisesRegex(ValueError, "classification or scope changed"):
            RUNNER.verify_v6_postrun_scopefix_review(ROOT, changed_review)

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
        sibling = EXPECTED_OUTPUT.parent / "runtime_replay_r8_sibling"
        with self.assertRaisesRegex(ValueError, "exactly to protocol output_leaf"):
            RUNNER.resolve_output_target(ROOT, sibling, self.protocol["output_leaf"])
        with self.assertRaisesRegex(ValueError, "V8 replay-only archive"):
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
        self.assertIn("aggregate_child_wall_overrun_seconds", self.runner)
        self.assertIn("controller_overhead_budget", self.runner)
        for token in ("termination_confirmed", "remaining_process_pids", "cleanup_unconfirmed"):
            self.assertIn(token, self.runner)
        self.assertIn("consumer_launch_blocked.json", self.runner)

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

    def test_original_process_schema_comes_from_actual_pinned_v10_json(self) -> None:
        checked = RUNNER.verify_v10_timeout_receipts(ROOT, self.protocol["v10_timeout_receipts"])
        process_final = checked["process_final"]
        process_record = checked["process_record"]
        self.assertEqual(process_final["schema"], "mms-recorded-process-v3")
        self.assertEqual(process_record["schema"], "mms-recorded-process-v3")
        self.assertEqual((process_final["stop_reason"], process_final["exit_code"],
                          process_final["stage"], process_final["controller_exit_code"]),
                         ("wall_timeout", 15, "producer", 124))
        self.assertEqual((process_record["stop_reason"], process_record["exit_code"]), ("wall_timeout", 15))
        self.assertNotIn("stage", process_record)
        self.assertEqual(process_record["controller_exit_code"], 124)
        RUNNER.validate_original_v10_process_receipts(process_final, process_record)
        for field, value in (("schema", "mms-recorded-process-v6"), ("exit_code", 0),
                             ("controller_exit_code", 0)):
            mutated_final = copy.deepcopy(process_final)
            mutated_final[field] = value
            with self.assertRaisesRegex(ValueError, "original v10 producer process receipt changed"):
                RUNNER.validate_original_v10_process_receipts(mutated_final, process_record)
        for field, value in (("schema", "mms-recorded-process-v6"), ("exit_code", 0),
                             ("controller_exit_code", 0)):
            mutated_record = copy.deepcopy(process_record)
            mutated_record[field] = value
            with self.assertRaisesRegex(ValueError, "original v10 producer raw process record changed"):
                RUNNER.validate_original_v10_process_receipts(process_final, mutated_record)
        changed_path = copy.deepcopy(self.protocol["v10_timeout_receipts"])
        changed_path["producer_process_record"]["path"] = changed_path["producer_process_record"]["path"] + ".missing"
        with self.assertRaisesRegex((ValueError, FileNotFoundError), "missing|not a file|receipt"):
            RUNNER.verify_v10_timeout_receipts(ROOT, changed_path)
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_main_calls_the_full_read_only_pre_output_chain(self) -> None:
        protocol_sha = sha(PROTOCOL_PATH)
        checked = RUNNER.verify_pre_output_contract(PROTOCOL_PATH, protocol_sha, EXPECTED_OUTPUT)
        self.assertEqual(checked["protocol_sha256"], protocol_sha)
        self.assertEqual(checked["output"], EXPECTED_OUTPUT.resolve())
        self.assertEqual(len(checked["input_entries"]), len({item["path"] for item in checked["input_entries"]}))
        self.assertEqual(checked["protocol"]["v10_protocol"]["pinned_input_count"], 89)
        self.assertEqual(len(checked["protocol"]["saved_producer_tree"]["entries"]), 119)
        self.assertEqual(checked["v10_timeout"]["process_final"]["schema"], "mms-recorded-process-v3")
        self.assertEqual(checked["controller_overhead_contract"]["limit_seconds"], 120.0)
        with self.assertRaisesRegex(ValueError, "protocol SHA"):
            RUNNER.verify_pre_output_contract(PROTOCOL_PATH, "0" * 64, EXPECTED_OUTPUT)
        sibling = EXPECTED_OUTPUT.parent / "runtime_replay_r8_wrong_leaf"
        with self.assertRaisesRegex(ValueError, "exactly to protocol output_leaf"):
            RUNNER.verify_pre_output_contract(PROTOCOL_PATH, protocol_sha, sibling)
        self.assertFalse(EXPECTED_OUTPUT.exists())
        self.assertFalse(sibling.exists())

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
        main_calls = [node for node in ast.walk(main) if isinstance(node, ast.Call)
                      and isinstance(node.func, ast.Name)]
        preflight_calls = [node for node in main_calls if node.func.id == "verify_pre_output_contract"]
        overhead_calls = [node for node in main_calls if node.func.id == "enforce_controller_overhead_budget"]
        output_mkdirs = [node for node in ast.walk(main) if isinstance(node, ast.Call)
                         and isinstance(node.func, ast.Attribute) and node.func.attr == "mkdir"]
        run_calls = [node for node in main_calls if node.func.id == "run_stage"]
        self.assertEqual(len(preflight_calls), 1)
        self.assertGreaterEqual(len(overhead_calls), 3)
        self.assertEqual(len(output_mkdirs), 1)
        self.assertGreaterEqual(len(run_calls), 2)
        overhead_calls.sort(key=lambda node: node.lineno)
        run_calls.sort(key=lambda node: node.lineno)
        self.assertLess(preflight_calls[0].lineno, output_mkdirs[0].lineno)
        self.assertLess(overhead_calls[0].lineno, output_mkdirs[0].lineno)
        self.assertGreater(overhead_calls[0].lineno, preflight_calls[0].lineno)
        self.assertLess(output_mkdirs[0].lineno, min(node.lineno for node in run_calls))
        self.assertLess(overhead_calls[1].lineno, run_calls[0].lineno)
        self.assertLess(overhead_calls[2].lineno, run_calls[1].lineno)

        preflight = next(node for node in tree.body if isinstance(node, ast.FunctionDef)
                         and node.name == "verify_pre_output_contract")
        checked_names = {node.func.id for node in ast.walk(preflight) if isinstance(node, ast.Call)
                         and isinstance(node.func, ast.Name)}
        for required in ("resolve_output_target", "verify_child_command_contract", "verify_inventory",
                         "validate_controller_overhead_contract", "validate_aggregate_child_wall_contract",
                         "verify_v7_no_go_ancestry",
                         "verify_v6_root_preflight_failure", "verify_v3_runtime_failure",
                         "verify_v10_timeout_receipts", "snapshot"):
            self.assertIn(required, checked_names)
        preflight_mutations = [node for node in ast.walk(preflight) if isinstance(node, ast.Call)
                               and ((isinstance(node.func, ast.Name) and node.func.id in ("run_stage", "write_new"))
                                    or (isinstance(node.func, ast.Attribute) and node.func.attr == "mkdir"))]
        self.assertFalse(preflight_mutations, "read-only preflight must not create output or launch a child")
        self.assertFalse(EXPECTED_OUTPUT.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
