from __future__ import annotations

import ast
import copy
import hashlib
import importlib.util
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
BASE = pathlib.Path(__file__).resolve().parent
PROTOCOL_PATH = ROOT / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r10/replay_protocol_v10.json"
RUNNER_PATH = BASE / "run_replay_staged_v10.py"
JULIA_PATH = BASE / "replay_staged_v10.jl"
EXPECTED_OUTPUT = ROOT / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r10/runtime_replay_r10"


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_runner():
    spec = importlib.util.spec_from_file_location("up2_replay_only_v10_runner_contract", RUNNER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot import the V10 controller for static contract checks")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


RUNNER = load_runner()


class ReplayContractV10Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        cls.runner = RUNNER_PATH.read_text(encoding="utf-8")
        cls.julia = JULIA_PATH.read_text(encoding="utf-8")
        cls.helper_path = ROOT / cls.protocol["context_builder_contract"]["helper_path"]
        cls.candidate_path = ROOT / cls.protocol["context_builder_contract"]["candidate_source_path"]
        cls.helper = cls.helper_path.read_text(encoding="utf-8")
        cls.candidate_source = cls.candidate_path.read_text(encoding="utf-8")
        cls.preflight = RUNNER.verify_pre_output_contract(
            PROTOCOL_PATH, sha(PROTOCOL_PATH), EXPECTED_OUTPUT)

    def test_frozen_protocol_is_test_only_and_retains_all_numeric_gates(self) -> None:
        p = self.protocol
        self.assertEqual(p["schema"], "mms-replay-only-continuation-protocol-v10")
        self.assertEqual(p["version"], 10)
        self.assertEqual(p["classification"], "test_only_continuation")
        self.assertIs(p["runtime_grant"], False)
        self.assertEqual(p["preserved_numerical_status"], {
            "authority": "no_publish", "physical_validation": "unsupported",
            "solver_exit_code": 2, "status": "fail",
            "stopping_reason": "stationary_nonzero_residual"})
        self.assertEqual(p["v10_protocol"]["pinned_input_count"], 89)
        self.assertEqual(len(p["saved_producer_tree"]["entries"]), 119)
        self.assertEqual(p["stage_limits"]["seconds"], 480)
        self.assertEqual(p["stage_limits"]["working_set_bytes"], 2147483648)
        self.assertEqual(p["total_child_wall_limit_seconds"], 960)
        self.assertEqual(p["controller_overhead_seconds_limit"], 120)
        self.assertEqual(p["coverage_contract"]["nonlinear_solver_calls"], 0)
        self.assertEqual(p["parent_v9_protocol"]["sha256"],
                         "37ecd51c875dbd71461c3ef71900c66cd30ae6a14a04e3a3e795e4bef8cb56dd")
        self.assertEqual(p["parent_v9_static_receipt"]["receipt_sha256"],
                         "36de483509879e3f0ce164783895b64fbaefa4def319d7b7be507c4a222e5cf2")
        self.assertEqual(p["parent_v9_root_decision"]["sha256"],
                         "22c1b77fac4ea1173b182bc1a32b3e866864f81f7f3ee0f23a642c0b8882b2fc")
        self.assertEqual(p["static_contract_run"]["test_count"], 12)
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_pre_output_verifier_checks_full_ancestry_without_creating_output_or_child(self) -> None:
        p = self.protocol
        self.assertEqual(self.preflight["protocol_sha256"], sha(PROTOCOL_PATH))
        self.assertEqual(p["v10_protocol"]["pinned_input_count"], 89)
        self.assertEqual(len(p["saved_producer_tree"]["entries"]), 119)
        self.assertEqual(self.preflight["v8_failure"]["failure"]["classification"], "context_rebuild_failed")
        self.assertEqual(self.preflight["v8_failure"]["final"]["controller_exit_code"], 71)
        self.assertFalse(self.preflight["v8_failure"]["runtime_root"].joinpath("consumer_process").exists())
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_v8_failure_is_preserved_separately_from_v10_numerical_fail(self) -> None:
        v8 = self.preflight["v8_failure"]
        self.assertEqual(v8["failure"]["error"], "UndefVarError: `build_spatial_candidate_v5` not defined")
        self.assertEqual(v8["final"]["classification"], "program_exception")
        self.assertEqual(v8["final"]["controller_exit_code"], 71)
        self.assertEqual(v8["final"]["numerical_status"], "fail")
        self.assertEqual(v8["final"]["solver_exit_code"], 2)
        self.assertEqual(v8["producer"]["exit_code"], 71)
        self.assertEqual(v8["producer"]["stop_reason"], "exited")
        self.assertNotIn("stage", v8["producer"])
        self.assertEqual(self.preflight["v10_timeout"]["controller_final"]["controller_exit_code"], 124)
        self.assertEqual(self.preflight["v10_timeout"]["process_final"]["exit_code"], 15)
        self.assertEqual(self.preflight["v10_timeout"]["process_final"]["stop_reason"], "wall_timeout")
        self.assertEqual(self.protocol["preserved_numerical_status"]["solver_exit_code"], 2)
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_v9_candidate_static_pass_and_independent_no_go_are_both_preserved(self) -> None:
        ancestry = self.preflight["v9_ancestry"]
        self.assertEqual(ancestry["static_receipt"]["classification"], "static_contract_pass_test_only")
        self.assertEqual(ancestry["static_receipt"]["test_count"], 11)
        self.assertEqual(ancestry["static_receipt"]["exit_code"], 0)
        self.assertFalse(ancestry["old_output"].exists())
        self.assertFalse(EXPECTED_OUTPUT.exists())

        input_map = {item["path"]: item for item in self.preflight["input_entries"]}
        for entry in ancestry["tester_entries"] + ancestry["review_entries"]:
            self.assertEqual(input_map[entry["path"]], entry)
        for path in (ancestry["root_decision_path"], ancestry["tester_receipt_path"],
                     ancestry["tester_sums_path"], ancestry["review_receipt_path"],
                     ancestry["input_inventory_path"]):
            relative = path.relative_to(ROOT).as_posix()
            self.assertIn(relative, input_map)
            self.assertEqual(input_map[relative]["sha256"], sha(path))
        self.assertFalse(EXPECTED_OUTPUT.exists())

        wrong_classification = copy.deepcopy(self.protocol)
        wrong_classification["parent_v9_independent_no_go_review"]["classification"] = "GO"
        with self.assertRaisesRegex(ValueError, "V9 independent NO-GO classification"):
            RUNNER.verify_v9_static_no_go_ancestry(ROOT, wrong_classification)

        wrong_receipt_pin = copy.deepcopy(self.protocol)
        wrong_receipt_pin["parent_v9_static_receipt"]["receipt_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "V9 static test receipt"):
            RUNNER.verify_v9_static_no_go_ancestry(ROOT, wrong_receipt_pin)

        wrong_review_path = copy.deepcopy(self.protocol)
        wrong_review_path["parent_v9_independent_no_go_review"]["report_path"] = \
            "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r9/replay_protocol_v9.json"
        wrong_review_path["parent_v9_independent_no_go_review"]["report_sha256"] = \
            wrong_review_path["parent_v9_protocol"]["sha256"]
        with self.assertRaisesRegex(ValueError, "V9 independent review artifact inventory"):
            RUNNER.verify_v9_static_no_go_ancestry(ROOT, wrong_review_path)

        wrong_tester_entry = copy.deepcopy(self.protocol)
        wrong_tester_entry["parent_v9_independent_tester"]["entries"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "frozen replay input drift"):
            RUNNER.verify_v9_static_no_go_ancestry(ROOT, wrong_tester_entry)

        wrong_root_decision = copy.deepcopy(self.protocol)
        wrong_root_decision["parent_v9_root_decision"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "root V9 NO-GO decision"):
            RUNNER.verify_v9_static_no_go_ancestry(ROOT, wrong_root_decision)

    def test_context_builder_symbol_resolves_through_definition_runtime_v4(self) -> None:
        RUNNER.verify_context_builder_contract(ROOT, self.protocol)
        self.assertIn("module DefinitionRuntime", self.helper)
        self.assertIn('"SpatialCandidateV4.jl"', self.helper)
        self.assertIn("const S = M.S", self.julia)
        self.assertIn(
            "S.build_spatial_candidate_v4(parent.context, parent.physical_input; physical_declaration=d)",
            self.julia)
        self.assertIn("S.validate_spatial_candidate_v4(context)", self.julia)
        self.assertIn("function build_spatial_candidate_v4(", self.candidate_source)
        self.assertIn("function validate_spatial_candidate_v4(", self.candidate_source)
        self.assertNotIn("function build_spatial_candidate_v5(", self.candidate_source)
        self.assertNotIn("function validate_spatial_candidate_v5(", self.candidate_source)
        self.assertNotIn("build_spatial_candidate_v5", self.julia)
        self.assertNotIn("validate_spatial_candidate_v5", self.julia)

    def test_context_builder_negative_controls_reject_wrong_symbol_module_and_include(self) -> None:
        exact = "S.build_spatial_candidate_v4(parent.context, parent.physical_input; physical_declaration=d)"
        bad_symbol = self.julia.replace(exact, exact.replace("candidate_v4", "candidate_v5"))
        with self.assertRaisesRegex(ValueError, "defined V4 spatial candidate builder"):
            RUNNER.check_context_builder_binding_text(bad_symbol, self.helper, self.candidate_source)

        exact_validate = "S.validate_spatial_candidate_v4(context)"
        bad_validator = self.julia.replace(
            exact_validate, exact_validate.replace("candidate_v4", "candidate_v5"))
        with self.assertRaisesRegex(ValueError, "defined V4 spatial candidate validator"):
            RUNNER.check_context_builder_binding_text(bad_validator, self.helper, self.candidate_source)

        bad_module = self.julia.replace("const S = M.S", "const S = FusionConceptAI")
        with self.assertRaisesRegex(ValueError, "helper module alias"):
            RUNNER.check_context_builder_binding_text(bad_module, self.helper, self.candidate_source)

        bad_include = self.helper.replace('"SpatialCandidateV4.jl"', '"SpatialMultiRegionV4.jl"')
        with self.assertRaisesRegex(ValueError, "SpatialCandidateV4 included"):
            RUNNER.check_context_builder_binding_text(self.julia, bad_include, self.candidate_source)

        bad_definition = self.candidate_source.replace(
            "function build_spatial_candidate_v4(", "function build_spatial_candidate_v5(", 1)
        with self.assertRaisesRegex(ValueError, "required V4 builder"):
            RUNNER.check_context_builder_binding_text(self.julia, self.helper, bad_definition)

        bad_validator_definition = self.candidate_source.replace(
            "function validate_spatial_candidate_v4(", "function validate_spatial_candidate_v5(", 1)
        with self.assertRaisesRegex(ValueError, "required V4 validator"):
            RUNNER.check_context_builder_binding_text(self.julia, self.helper, bad_validator_definition)

    def test_context_builder_contract_hash_mutations_fail_closed(self) -> None:
        p = copy.deepcopy(self.protocol)
        p["context_builder_contract"]["builder_symbol"] = "build_spatial_candidate_v5"
        with self.assertRaisesRegex(ValueError, "unsupported module or symbol"):
            RUNNER.verify_context_builder_contract(ROOT, p)

        p = copy.deepcopy(self.protocol)
        p["context_builder_contract"]["validator_symbol"] = "validate_spatial_candidate_v5"
        with self.assertRaisesRegex(ValueError, "unsupported module or symbol"):
            RUNNER.verify_context_builder_contract(ROOT, p)

        p = copy.deepcopy(self.protocol)
        p["context_builder_contract"]["candidate_source_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "V4 spatial candidate source"):
            RUNNER.verify_context_builder_contract(ROOT, p)

    def test_v8_historical_process_schema_exit_and_paths_are_checked(self) -> None:
        actual = self.preflight["v8_failure"]
        RUNNER.verify_v8_failure_receipt_values(actual["final"], actual["producer"], actual["failure"])

        wrong_schema = copy.deepcopy(actual["producer"])
        wrong_schema["schema"] = "mms-recorded-process-v3"
        with self.assertRaisesRegex(ValueError, "V8 producer process receipt changed"):
            RUNNER.verify_v8_failure_receipt_values(actual["final"], wrong_schema, actual["failure"])

        wrong_exit = copy.deepcopy(actual["producer"])
        wrong_exit["exit_code"] = 0
        with self.assertRaisesRegex(ValueError, "V8 producer process receipt changed"):
            RUNNER.verify_v8_failure_receipt_values(actual["final"], wrong_exit, actual["failure"])

        wrong_path = copy.deepcopy(self.protocol)
        wrong_path["parent_v8_failed_attempt"]["producer_process_path"] = \
            wrong_path["parent_v8_failed_attempt"]["output_leaf"] + "/missing_process.json"
        with self.assertRaisesRegex(ValueError, "inventory lacks producer process"):
            RUNNER.verify_v8_context_rebuild_failure(ROOT, wrong_path)

    def test_protocol_child_argv_matches_actual_main_launch_assembly(self) -> None:
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

        tree = ast.parse(self.runner)
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "main")
        for mode, variable in (("producer", "producer_cmd"), ("consumer", "consumer_cmd")):
            assignment = [node for node in ast.walk(main) if isinstance(node, ast.Assign)
                          and any(isinstance(target, ast.Name) and target.id == variable for target in node.targets)]
            self.assertEqual(len(assignment), 1)
            call = assignment[0].value
            self.assertIsInstance(call, ast.Call)
            self.assertIsInstance(call.func, ast.Name)
            self.assertEqual(call.func.id, f"build_{mode}_launch_command")
            expected_call = {
                "producer": "build_producer_launch_command(protocol, julia, producer_root, actual_protocol_sha)",
                "consumer": "build_consumer_launch_command(protocol, julia, consumer_root, producer_root, actual_protocol_sha, str(seal['carrier_sha256']), str(seal['binding_sha256']))",
            }[mode]
            self.assertEqual(ast.unparse(call), expected_call)
            launches = [node for node in ast.walk(main) if isinstance(node, ast.Call)
                        and isinstance(node.func, ast.Name) and node.func.id == "run_stage"
                        and node.args and isinstance(node.args[0], ast.Name) and node.args[0].id == variable]
            self.assertEqual(len(launches), 1)

        mutated = copy.deepcopy(p)
        mutated["child_command_contract"]["producer"][3] = \
            "test/RuntimeV4/UP2ClosureReplayOnlyV8/replay_staged_v8.jl"
        with self.assertRaisesRegex(ValueError, "controller-generated argv"):
            RUNNER.verify_child_command_contract(mutated)

    def test_main_preflights_builder_contract_before_output_or_julia(self) -> None:
        tree = ast.parse(self.runner)
        preflight = next(node for node in tree.body if isinstance(node, ast.FunctionDef)
                         and node.name == "verify_pre_output_contract")
        calls = [node for node in ast.walk(preflight) if isinstance(node, ast.Call)
                 and isinstance(node.func, ast.Name)]
        called = [node.func.id for node in calls]
        self.assertIn("verify_context_builder_contract", called)
        self.assertIn("verify_v8_context_rebuild_failure", called)
        self.assertIn("verify_v9_static_no_go_ancestry", called)
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "main")
        main_source = ast.get_source_segment(self.runner, main)
        self.assertIsNotNone(main_source)
        self.assertLess(main_source.index("verify_pre_output_contract("), main_source.index("output.mkdir"))
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_output_target_is_exact_frozen_r10_leaf(self) -> None:
        sibling = EXPECTED_OUTPUT.parent / "runtime_replay_r10_sibling"
        accepted = RUNNER.resolve_output_target(ROOT, EXPECTED_OUTPUT, self.protocol["output_leaf"])
        self.assertEqual(accepted, EXPECTED_OUTPUT.resolve())
        with self.assertRaisesRegex(ValueError, "exactly to protocol output_leaf"):
            RUNNER.resolve_output_target(ROOT, sibling, self.protocol["output_leaf"])
        with self.assertRaisesRegex(ValueError, "V10 replay-only archive"):
            RUNNER.resolve_output_target(ROOT, ROOT / "tmp/outside_v10", self.protocol["output_leaf"])
        self.assertFalse(EXPECTED_OUTPUT.exists())
        self.assertFalse(sibling.exists())

    def test_controller_protocol_sha_and_entrypoint_versions_fail_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "protocol SHA"):
            RUNNER.verify_pre_output_contract(PROTOCOL_PATH, "0" * 64, EXPECTED_OUTPUT)
        p = copy.deepcopy(self.protocol)
        p["entrypoint"] = "test/RuntimeV4/UP2ClosureReplayOnlyV8/replay_staged_v8.jl"
        with self.assertRaisesRegex(ValueError, "entrypoint differs"):
            RUNNER.verify_context_builder_contract(ROOT, p)
        self.assertFalse(EXPECTED_OUTPUT.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
