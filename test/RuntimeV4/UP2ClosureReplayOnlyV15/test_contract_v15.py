from __future__ import annotations

import ast
import copy
import hashlib
import importlib.util
import json
import pathlib
import tempfile
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[3]
BASE = pathlib.Path(__file__).resolve().parent
PROTOCOL_PATH = ROOT / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r15/replay_protocol_v15.json"
RUNNER_PATH = BASE / "run_replay_staged_v15.py"
JULIA_PATH = BASE / "replay_staged_v15.jl"
EXPECTED_OUTPUT = ROOT / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r15/runtime_replay_r15"


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_runner():
    spec = importlib.util.spec_from_file_location("up2_replay_only_v15_runner_contract", RUNNER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot import the V15 controller for static contract checks")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


RUNNER = load_runner()


class ReplayContractV15Tests(unittest.TestCase):
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
        self.assertEqual(p["schema"], "mms-replay-only-continuation-protocol-v15")
        self.assertEqual(p["version"], 15)
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
        self.assertEqual(p["static_contract_run"]["test_count"], 35)
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_pre_output_verifier_checks_full_ancestry_without_creating_output_or_child(self) -> None:
        p = self.protocol
        self.assertEqual(self.preflight["protocol_sha256"], sha(PROTOCOL_PATH))
        self.assertEqual(p["v10_protocol"]["pinned_input_count"], 89)
        self.assertEqual(len(p["saved_producer_tree"]["entries"]), 119)
        self.assertEqual(self.preflight["v8_failure"]["failure"]["classification"], "context_rebuild_failed")
        self.assertEqual(self.preflight["v8_failure"]["final"]["controller_exit_code"], 71)
        self.assertEqual(self.preflight["v10_replay_failure"]["failure"]["classification"],
                         "replay_hydration_unsupported")
        self.assertEqual(self.preflight["v10_replay_failure"]["tree_comparison_status"], "not_reached")
        self.assertEqual(self.preflight["v11_actual_failure"]["final"]["controller_exit_code"], 72)
        self.assertEqual(self.preflight["v11_actual_failure"]["failure"]["hydration_stage"],
                         "observe_typed_body_before_assertions")
        self.assertEqual(self.preflight["v14_actual_failure"]["failure"]["error"],
                         "unsupported rebuilt V4 declaration schema node at declaration.source.input: "
                         "Main.ManufacturedCandidateV1Tests.DefinitionRuntime.SpatialManufacturedNumericalInputV1")
        self.assertEqual(self.preflight["v14_postrun_audit"]["report"]["run_commands"]["producer_inner_solver_exit"], 2)
        self.assertEqual(self.preflight["v14_postrun_audit"]["report"]["final"]["producer_tree_comparison_status"],
                         "not_reached")
        self.assertFalse(self.preflight["v11_actual_failure"]["runtime_root"].joinpath("consumer_process").exists())
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

    def test_actual_v10_replay_failure_and_solver_failure_are_distinct(self) -> None:
        replay = self.preflight["v10_replay_failure"]
        self.assertEqual(replay["final"]["classification"], "replay_hydration_unsupported")
        self.assertEqual(replay["final"]["controller_exit_code"], 72)
        self.assertEqual(replay["failure"]["phase"], "typed_result_hydration")
        self.assertEqual(replay["failure"]["hydration_stage"], "canonical_result_hash_check")
        self.assertEqual(replay["failure"]["error"], "ArgumentError: spatial result hash mismatch")
        self.assertEqual(replay["final"]["solver_exit_code"], 2)
        self.assertEqual(replay["final"]["numerical_status"], "fail")
        self.assertEqual(replay["final"]["authority"], "no_publish")
        self.assertFalse(replay["runtime_root"].joinpath("consumer_process").exists())
        self.assertFalse(replay["runtime_root"].joinpath("producer_tree_before_consumer.json").exists())
        self.assertEqual(replay["tree_comparison_status"], "not_reached")
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_v10_failure_receipt_negative_controls_fail_closed(self) -> None:
        contract = copy.deepcopy(self.protocol["parent_v10_actual_replay_failure"])
        altered_runtime = copy.deepcopy(contract)
        altered_runtime["runtime"]["entries"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "drift"):
            RUNNER.verify_v10_replay_failure(ROOT, altered_runtime,
                self.protocol["parent_v10_independent_postrun_review"])

        altered_protocol = copy.deepcopy(contract)
        altered_protocol["protocol"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "V10 actual replay protocol"):
            RUNNER.verify_v10_replay_failure(ROOT, altered_protocol,
                self.protocol["parent_v10_independent_postrun_review"])

        altered_review = copy.deepcopy(self.protocol["parent_v10_independent_postrun_review"])
        altered_review["manifest_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "V10 independent postrun review manifest"):
            RUNNER.verify_v10_replay_failure(ROOT, contract, altered_review)
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_observe_first_schema_reconstruction_is_exact_and_fail_closed(self) -> None:
        src = self.julia
        RUNNER.check_hydration_contract_text(src)
        observe = src.index('new_json(joinpath(out, "hydration_observation_initial.json")')
        rebuild = src.index("result = hydration_rebuild_result(body, wire, expected_result_hash, context)")
        validator = src.index("S.validate_spatial_manufactured_result_v1(context, result)")
        consumer = src.index("M.result_tests(context, result, out)")
        self.assertLess(observe, rebuild)
        self.assertLess(rebuild, validator)
        self.assertLess(validator, consumer)
        self.assertIn('Set((item.typed_type, item.body_type)) == Set(("Float64", "Int64"))', src)
        self.assertIn("S.SpatialMultiRegionCaseV4(case_values..., case_hash)", src)
        self.assertIn("S.SpatialCurrentInputV4(", src)
        self.assertIn("S.SpatialManufacturedGeometryReceiptV1(", src)
        self.assertIn("hydration_declaration_from_body(body.declaration, expected_declaration)", src)
        self.assertIn("S._smr_bounded_identity_v1()", src)
        self.assertIn("S.spatial_manufactured_provider_identity_v1()", src)
        self.assertIn('error("observe-first found an unproven typed/body value, key, or shape difference")', src)
        self.assertNotIn("hydration_restore_exact_numeric_tokens", src)
        self.assertNotIn("residual_tolerance =", src)
        self.assertNotIn("max_iterations =", src)

        mutated_gate = src.replace('Set((item.typed_type, item.body_type)) == Set(("Float64", "Int64"))',
                                   'Set((item.typed_type, item.body_type)) == Set(("Float64", "Int64", "Int32"))')
        with self.assertRaisesRegex(ValueError, "required schema/gate bindings"):
            RUNNER.check_hydration_contract_text(mutated_gate)
        mutated_call_order = src.replace('new_json(joinpath(out, "hydration_observation_initial.json"), initial)',
                                         'result = hydration_rebuild_result(body, wire, expected_result_hash, context)\n    new_json(joinpath(out, "hydration_observation_initial.json"), initial)', 1)
        with self.assertRaisesRegex(ValueError, "call order changed"):
            RUNNER.check_hydration_contract_text(mutated_call_order)

    def test_declaration_and_current_input_reconstruction_are_bound_to_rebuilt_v4_schema(self) -> None:
        src = self.julia
        self.assertIn("function hydration_restore_from_template(value, template, path)", src)
        self.assertIn("function hydration_declaration_from_body(body_declaration, expected_declaration)", src)
        self.assertIn("S.SpatialMultiRegionDeclarationV4(values...)", src)
        self.assertIn("hydration_restore_from_template(getproperty(body_declaration, field)", src)
        self.assertIn("hydration_current_input(raw, field_path, declaration)", src)
        self.assertIn("hydration_restore_semantic_tree(value.current_closure, path * \".current_closure\", declaration)", src)
        self.assertIn("canonical_json(actual_enclosure) == canonical_json(value.enclosure)", src)
        self.assertIn("typeof(value) == typeof(template)", src)
        self.assertIn("unsupported rebuilt V4 declaration schema node", src)
        self.assertNotIn("hydration_current_input(raw, field_path)", src)

        weakened = src.replace("typeof(value) == typeof(template)", "true")
        with self.assertRaisesRegex(ValueError, "required schema/gate bindings"):
            RUNNER.check_hydration_contract_text(weakened)

    def test_v11_actual_failure_is_bound_separately_from_solver_failure(self) -> None:
        v11 = self.preflight["v11_actual_failure"]
        self.assertEqual(v11["final"]["classification"], "replay_hydration_unsupported")
        self.assertEqual(v11["final"]["controller_exit_code"], 72)
        self.assertEqual(v11["final"]["solver_exit_code"], 2)
        self.assertEqual(v11["final"]["numerical_status"], "fail")
        self.assertEqual(v11["final"]["authority"], "no_publish")
        self.assertEqual(v11["final"]["producer_tree_comparison_status"], "not_reached")
        self.assertIsNone(v11["final"]["producer_tree_unchanged"])
        self.assertEqual(v11["failure"]["error"],
                         "typed result differs from exact body beyond equal-valued numeric token types")
        diagnosis = json.loads(self.protocol["parent_v11_diagnosis"]["diagnosis_path"] and
                               (ROOT / self.protocol["parent_v11_diagnosis"]["diagnosis_path"]).read_text(encoding="utf-8"))
        self.assertEqual(diagnosis["observation"]["paired_leaf_count_total"], 2415)
        self.assertEqual(diagnosis["observation"]["exact_integral_float_to_int_count_total"], 153)
        self.assertEqual(diagnosis["observation"]["first_exact_token_difference"]["source_float_token"], "0.0")
        self.assertEqual(diagnosis["observation"]["first_exact_token_difference"]["typed_integer_token"], "0")
        self.assertEqual(v11["failure"]["solver_exit_code"], 2)
        self.assertFalse(v11["runtime_root"].joinpath("consumer_process").exists())
        self.assertFalse(v11["runtime_root"].joinpath("producer_process/numerical/producer_complete.json").exists())
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_v11_failure_ancestry_negative_controls_fail_closed(self) -> None:
        evidence = copy.deepcopy(self.protocol["parent_v11_actual_failure"])
        diagnosis = copy.deepcopy(self.protocol["parent_v11_diagnosis"])
        wrong_protocol = copy.deepcopy(evidence)
        wrong_protocol["protocol"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "V11 frozen protocol"):
            RUNNER.verify_v11_actual_failure(ROOT, wrong_protocol, diagnosis)

        wrong_leaf = copy.deepcopy(evidence)
        wrong_leaf["runtime"]["entries"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "frozen replay input drift"):
            RUNNER.verify_v11_actual_failure(ROOT, wrong_leaf, diagnosis)

        wrong_diagnosis = copy.deepcopy(diagnosis)
        wrong_diagnosis["diagnosis_path"] = evidence["runtime"]["final_path"]
        with self.assertRaisesRegex(ValueError, "V11 observe-first diagnosis identity changed"):
            RUNNER.verify_v11_actual_failure(ROOT, evidence, wrong_diagnosis)
        self.assertFalse(EXPECTED_OUTPUT.exists())
        process = copy.deepcopy(self.preflight["v11_actual_failure"]["process"])
        RUNNER.verify_v11_process_receipt(process)
        for field, bad_value in (("schema", "mms-replay-recorded-process-v3"), ("exit_code", 0)):
            altered = copy.deepcopy(process)
            altered[field] = bad_value
            with self.assertRaisesRegex(ValueError, "V11 producer process receipt changed"):
                RUNNER.verify_v11_process_receipt(altered)

    def test_v12_independent_static_no_go_and_all_three_mutations_are_bound(self) -> None:
        evidence = self.protocol["parent_v12_independent_no_go_review"]
        parent = self.preflight["v12_static_no_go"]
        self.assertEqual(parent["protocol"]["schema"], "mms-replay-only-continuation-protocol-v12")
        self.assertEqual(parent["review_manifest"]["classification"], "NO-GO")
        self.assertEqual(parent["review_manifest"]["reviewer_task"], "/root/mms_closure/oracle_review")
        self.assertEqual(len(parent["protocol"]["owned_source_files"]), 4)
        self.assertEqual(parent["static_receipt"]["command"]["test_count"], 19)
        self.assertTrue(parent["static_receipt"]["output_leaf_absent"])
        self.assertFalse((ROOT / parent["protocol"]["output_leaf"]).exists())
        commands = json.loads(parent["review_commands_path"].read_text(encoding="utf-8"))
        self.assertEqual(commands["runtime"]["julia_started"], False)
        mutation = next(item for item in commands["commands"] if item.get("observed"))
        self.assertEqual(mutation["exit_code"], 0)
        self.assertEqual(len(mutation["observed"]), 3)
        self.assertFalse(EXPECTED_OUTPUT.exists())

        wrong_probe = copy.deepcopy(evidence)
        wrong_probe["independent_review"]["commands_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "V12 independent review command receipt"):
            RUNNER.verify_v12_static_no_go(ROOT, wrong_probe)

    def test_v15_hydration_checker_rejects_fail_open_guard_mutations(self) -> None:
        source = self.julia
        mutations = (
            ("unequal numeric rejection",
             "        else\n            push!(semantic_differences, path)\n        end\n        return",
             "        else\n            nothing\n        end\n        return"),
            ("numeric comparator bypass", "if parsed == exact", "if parsed == exact || true"),
            ("key-set rejection", "if parsed_keys != exact_keys", "if false"),
            ("sequence length rejection",
             'length(parsed) == length(exact) || (push!(semantic_differences, path * ".<length>"); return)',
             'true || (push!(semantic_differences, path * ".<length>"); return)'),
            ("sequence shape rejection",
             'parsed_shape == exact_shape || (push!(semantic_differences, path * ".<shape>"); return)',
             'true || (push!(semantic_differences, path * ".<shape>"); return)'),
        )
        for label, before, after in mutations:
            with self.subTest(guard=label):
                self.assertIn(before, source, f"{label} mutation anchor drifted")
                weakened = source.replace(before, after, 1)
                self.assertNotEqual(weakened, source)
                with self.assertRaisesRegex(ValueError, "lost its fail-closed guard"):
                    RUNNER.check_hydration_contract_text(weakened)
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_v15_exact_manufactured_input_route_and_guards_fail_closed(self) -> None:
        RUNNER.check_hydration_contract_text(self.julia)
        mutations = (
            ("dispatcher bypass", "if template isa S.SpatialManufacturedNumericalInputV1",
             "if false && template isa S.SpatialManufacturedNumericalInputV1"),
            ("input field set", "Set(String.(keys(value))) == Set(String.(fields)) ||",
             "true ||"),
            ("concrete constructor", "S.SpatialManufacturedNumericalInputV1(values...)",
             "template"),
            ("strict input validator", "S.validate_spatial_manufactured_input_v1(restored) === true ||",
             "true ||"),
            ("exact body round trip", "canonical_json(S.semantic_view(restored)) == canonical_json(value) ||",
             "true ||"),
        )
        for label, before, after in mutations:
            with self.subTest(guard=label):
                self.assertIn(before, self.julia, f"{label} mutation anchor drifted")
                weakened = self.julia.replace(before, after, 1)
                self.assertNotEqual(weakened, self.julia)
                with self.assertRaises(ValueError):
                    RUNNER.check_hydration_contract_text(weakened)
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_live_tree_bytes_rejects_incomplete_enumeration_and_child_rss(self) -> None:
        class FakeProcess:
            def __init__(self, pid: int, rss: int = 100, create_error: Exception | None = None,
                         rss_error: Exception | None = None, children: list[object] | None = None,
                         children_error: Exception | None = None):
                self.pid = pid
                self._rss = rss
                self._create_error = create_error
                self._rss_error = rss_error
                self._children = children or []
                self._children_error = children_error

            def children(self, recursive: bool = True) -> list[object]:
                if self._children_error is not None:
                    raise self._children_error
                return self._children

            def create_time(self) -> float:
                if self._create_error is not None:
                    raise self._create_error
                return float(self.pid) / 10

            def memory_info(self):
                if self._rss_error is not None:
                    raise self._rss_error
                return type("Memory", (), {"rss": self._rss})()

        child_denied = RUNNER.psutil.AccessDenied(pid=42)
        child = FakeProcess(42, rss_error=child_denied)
        root = FakeProcess(41, rss=1000, children=[child])
        with mock.patch.object(RUNNER.psutil, "Process", return_value=root):
            with self.assertRaises(RUNNER.ProcessTreeObservationError) as caught:
                RUNNER.live_tree_bytes(41)
        self.assertEqual(caught.exception.evidence["scope"], "process_identity_or_rss")
        self.assertEqual(caught.exception.evidence["process_pid"], 42)
        self.assertEqual(caught.exception.evidence["partial_rss_bytes_not_used_for_gate"], 1000)
        self.assertEqual(caught.exception.evidence["error_type"], "AccessDenied")

        denied_descendants = FakeProcess(41, children_error=RUNNER.psutil.AccessDenied(pid=41))
        with mock.patch.object(RUNNER.psutil, "Process", return_value=denied_descendants):
            with self.assertRaises(RUNNER.ProcessTreeObservationError) as caught:
                RUNNER.live_tree_bytes(41)
        self.assertEqual(caught.exception.evidence["scope"], "descendant_enumeration")
        self.assertEqual(caught.exception.evidence["partial_rss_bytes_not_used_for_gate"], 0)

    def test_live_tree_bytes_requires_one_exact_root_identity(self) -> None:
        class FakeProcess:
            def __init__(self, pid: int, create_time: float, children: list[object] | None = None):
                self.pid = pid
                self._create_time = create_time
                self._children = children or []

            def create_time(self) -> float:
                return self._create_time

            def children(self, recursive: bool = True) -> list[object]:
                return self._children

            def memory_info(self):
                return type("Memory", (), {"rss": 100})()

        root = FakeProcess(41, 4.1)
        with mock.patch.object(RUNNER.psutil, "Process", return_value=root):
            self.assertEqual(RUNNER.live_tree_bytes(41, (41, 4.1))[0], 100)
            with self.assertRaises(RUNNER.ProcessTreeObservationError) as caught:
                RUNNER.live_tree_bytes(41, (41, 4.2))
        self.assertEqual(caught.exception.evidence["scope"], "root_identity")

        duplicate_root = FakeProcess(41, 4.1)
        root_with_duplicate = FakeProcess(41, 4.1, [duplicate_root])
        with mock.patch.object(RUNNER.psutil, "Process", return_value=root_with_duplicate):
            with self.assertRaises(RUNNER.ProcessTreeObservationError) as caught:
                RUNNER.live_tree_bytes(41, (41, 4.1))
        self.assertEqual(caught.exception.evidence["scope"], "root_identity_not_unique")

    def test_post_leader_descendant_check_fails_closed_on_reuse_and_unknown(self) -> None:
        class FakeProcess:
            def __init__(self, pid: int, create_time: float, running: bool = True):
                self.pid = pid
                self._create_time = create_time
                self._running = running

            def create_time(self) -> float:
                return self._create_time

            def is_running(self) -> bool:
                return self._running

        identities = [{"pid": 4201, "create_time": 420.1},
                      {"pid": 4202, "create_time": 420.2}]
        reused = FakeProcess(4202, 999.0)
        with mock.patch.object(RUNNER.psutil, "Process", return_value=reused):
            result = RUNNER.known_descendants_after_leader_exit(identities, (4201, 420.1))
        self.assertEqual(result["active_descendants"], [])
        self.assertEqual(result["unknown_descendants"][0]["stage"], "pid_identity_changed")
        self.assertIs(result["all_previously_observed_descendants_checked"], False)

        denied = RUNNER.psutil.AccessDenied(pid=4202)
        with mock.patch.object(RUNNER.psutil, "Process", side_effect=denied):
            result = RUNNER.known_descendants_after_leader_exit(identities, (4201, 420.1))
        self.assertEqual(result["unknown_descendants"][0]["stage"], "lookup")

    def test_run_stage_popen_exit_skips_root_rss_and_audits_descendants(self) -> None:
        class FakeRoot:
            pid = 4201

            def create_time(self):
                return 420.1

        class FakeChild:
            pid = 4201

            def __init__(self):
                self.poll_values = [None, None, None, 72]

            def poll(self):
                return self.poll_values.pop(0) if self.poll_values else 72

            def kill(self):
                raise AssertionError("natural producer exit must not request kill")

        child = FakeChild()
        root_identity = {"pid": 4201, "create_time": 420.1}
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            with mock.patch.object(RUNNER.subprocess, "Popen", return_value=child), \
                    mock.patch.object(RUNNER.psutil, "Process", return_value=FakeRoot()) as process_lookup, \
                    mock.patch.object(RUNNER, "live_tree_bytes", return_value=(1024, [root_identity])) as sample, \
                    mock.patch.object(RUNNER.psutil, "_ppid_map", return_value={}), \
                    mock.patch.object(RUNNER.time, "sleep") as sleep, \
                    mock.patch.object(RUNNER, "terminate_tree") as terminate:
                receipt = RUNNER.run_stage(
                    ["synthetic-child"], root, root / "producer", 4.0, 2147483648, {},
                    {"live_limit_seconds": 4.0, "stage_cap_seconds": 4.0,
                     "cleanup_grace_seconds": 0.1, "remaining_before_seconds": 960.0})
        self.assertEqual(receipt["stop_reason"], "exited")
        self.assertEqual(receipt["exit_code"], 72)
        self.assertIs(receipt["rss_sampling_complete"], True)
        self.assertEqual(receipt["rss_complete_sample_count"], 1)
        self.assertEqual(sample.call_count, 1)
        self.assertEqual(process_lookup.call_count, 1)
        self.assertEqual(sleep.call_count, 0)
        self.assertEqual(receipt["leader_exit_observation"]["mode"], "popen_exit_after_complete_rss_sample")
        self.assertEqual(receipt["leader_exit_observation"]["status"], "complete_no_residual_descendants")
        self.assertIs(receipt["leader_exit_descendant_check"]["process_table_snapshot_complete"], True)
        self.assertEqual(RUNNER.resource_interruption_exit_code(receipt["stop_reason"]), None)
        terminate.assert_not_called()
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_run_stage_final_ppid_audit_rejects_unobserved_live_child(self) -> None:
        class FakeRoot:
            pid = 4201

            def create_time(self):
                return 420.1

        class FakeDescendant:
            pid = 4202

            def create_time(self):
                return 420.2

            def is_running(self):
                return True

        class FakeChild:
            pid = 4201

            def __init__(self):
                self.poll_values = [None, None, None, 72]

            def poll(self):
                return self.poll_values.pop(0) if self.poll_values else 72

            def kill(self):
                pass

        child = FakeChild()
        root_identity = {"pid": 4201, "create_time": 420.1}
        cleanup = {"elapsed_seconds": 0.01, "cleanup_grace_seconds": 0.1,
                   "termination_confirmed": True, "remaining_process_pids": [],
                   "owned_process_identities": [root_identity, {"pid": 4202, "create_time": 420.2}]}
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            with mock.patch.object(RUNNER.subprocess, "Popen", return_value=child), \
                    mock.patch.object(RUNNER.psutil, "Process", side_effect=lambda pid: {
                        4201: FakeRoot(), 4202: FakeDescendant()}[pid]), \
                    mock.patch.object(RUNNER, "live_tree_bytes", return_value=(1024, [root_identity])), \
                    mock.patch.object(RUNNER.psutil, "_ppid_map", return_value={4202: 4201}), \
                    mock.patch.object(RUNNER.time, "sleep"), \
                    mock.patch.object(RUNNER, "terminate_tree", return_value=cleanup) as terminate:
                receipt = RUNNER.run_stage(
                    ["synthetic-child"], root, root / "producer", 4.0, 2147483648, {},
                    {"live_limit_seconds": 4.0, "stage_cap_seconds": 4.0,
                     "cleanup_grace_seconds": 0.1, "remaining_before_seconds": 960.0})
        self.assertEqual(receipt["stop_reason"], "leader_exited_with_live_descendants")
        self.assertEqual(receipt["exit_code"], 72)
        check = receipt["leader_exit_descendant_check"]
        self.assertEqual(check["unobserved_descendant_identity_count"], 1)
        self.assertEqual(check["unknown_descendants"][0]["stage"], "unobserved_post_sample_descendant")
        self.assertEqual(check["active_descendants"], [{"pid": 4202, "create_time": 420.2}])
        self.assertEqual(RUNNER.resource_interruption_exit_code(receipt["stop_reason"]), 124)
        self.assertEqual(terminate.call_args.args[2][-1], {"pid": 4202, "create_time": 420.2})
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_run_stage_exit_before_first_complete_sample_fails_closed(self) -> None:
        class FakeRoot:
            pid = 4201

            def create_time(self):
                return 420.1

        class FakeChild:
            pid = 4201

            def __init__(self):
                self.poll_values = [None, None, 72]

            def poll(self):
                return self.poll_values.pop(0) if self.poll_values else 72

            def kill(self):
                pass

        child = FakeChild()
        cleanup = {"elapsed_seconds": 0.01, "cleanup_grace_seconds": 0.1,
                   "termination_confirmed": True, "remaining_process_pids": [],
                   "owned_process_identities": [{"pid": 4201, "create_time": 420.1}]}
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            with mock.patch.object(RUNNER.subprocess, "Popen", return_value=child), \
                    mock.patch.object(RUNNER.psutil, "Process", return_value=FakeRoot()), \
                    mock.patch.object(RUNNER, "live_tree_bytes") as sample, \
                    mock.patch.object(RUNNER, "terminate_tree", return_value=cleanup) as terminate:
                receipt = RUNNER.run_stage(
                    ["synthetic-child"], root, root / "producer", 4.0, 2147483648, {},
                    {"live_limit_seconds": 4.0, "stage_cap_seconds": 4.0,
                     "cleanup_grace_seconds": 0.1, "remaining_before_seconds": 960.0})
        self.assertEqual(receipt["stop_reason"], "process_tree_observation_incomplete")
        self.assertEqual(receipt["exit_code"], 72)
        self.assertEqual(receipt["rss_complete_sample_count"], 0)
        self.assertIs(receipt["rss_sampling_complete"], False)
        self.assertEqual(receipt["leader_exit_descendant_check"]["unknown_descendants"][0]["stage"],
                         "pinned_root_identity_missing_or_changed")
        self.assertEqual(RUNNER.resource_interruption_exit_code(receipt["stop_reason"]), 124)
        sample.assert_not_called()
        terminate.assert_called_once()
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_run_stage_unconfirmed_cleanup_without_overrun_keeps_distinct_status(self) -> None:
        class FakeRoot:
            pid = 4201

            def create_time(self):
                return 420.1

        class FakeDescendant:
            pid = 4202

            def create_time(self):
                return 420.2

            def is_running(self):
                return True

        class FakeChild:
            pid = 4201

            def __init__(self):
                self.poll_values = [None, None, None, None, 72]

            def poll(self):
                return self.poll_values.pop(0) if self.poll_values else 72

            def kill(self):
                pass

        child = FakeChild()
        root_identity = {"pid": 4201, "create_time": 420.1}
        child_identity = {"pid": 4202, "create_time": 420.2}
        cleanup = {"elapsed_seconds": 0.01, "cleanup_grace_seconds": 0.1,
                   "termination_confirmed": False, "remaining_process_pids": [4202],
                   "owned_process_identities": [child_identity]}
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            with mock.patch.object(RUNNER.subprocess, "Popen", return_value=child), \
                    mock.patch.object(RUNNER.psutil, "Process", side_effect=lambda pid: {
                        4201: FakeRoot(), 4202: FakeDescendant()}[pid]), \
                    mock.patch.object(RUNNER, "live_tree_bytes", return_value=(2048, [root_identity, child_identity])), \
                    mock.patch.object(RUNNER.time, "sleep"), \
                    mock.patch.object(RUNNER, "terminate_tree", return_value=cleanup):
                receipt = RUNNER.run_stage(
                    ["synthetic-child"], root, root / "producer", 4.0, 2147483648, {},
                    {"live_limit_seconds": 4.0, "stage_cap_seconds": 4.0,
                     "cleanup_grace_seconds": 0.1, "remaining_before_seconds": 960.0})
        self.assertEqual(receipt["stop_reason"], "cleanup_unconfirmed")
        self.assertEqual(receipt["exit_code"], 72)
        self.assertEqual(receipt["aggregate_child_wall_overrun_seconds"], 0)
        self.assertEqual(receipt["cleanup"]["elapsed_seconds"], 0.01)
        self.assertEqual(receipt["cleanup"]["cleanup_grace_seconds"], 0.1)
        self.assertEqual(RUNNER.resource_interruption_exit_code(receipt["stop_reason"]), 124)
        self.assertNotEqual(receipt["stop_reason"], "aggregate_cleanup_overrun")
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_run_stage_leader_exit_with_live_descendant_is_interruption(self) -> None:
        class FakeProcess:
            def __init__(self, pid: int, create_time: float, children: list[object] | None = None,
                         running: bool = True):
                self.pid = pid
                self._create_time = create_time
                self._children = children or []
                self._running = running

            def create_time(self) -> float:
                return self._create_time

            def children(self, recursive: bool = True) -> list[object]:
                return self._children

            def memory_info(self):
                return type("Memory", (), {"rss": 1024})()

            def is_running(self) -> bool:
                return self._running

        class FakeChild:
            pid = 4201
            returncodes = [None, None, None, None, 0]

            def poll(self):
                return self.returncodes.pop(0) if self.returncodes else 0

            def kill(self):
                pass

        descendant = FakeProcess(4202, 420.2, running=True)
        root_process = FakeProcess(4201, 420.1, [descendant], running=False)
        process = FakeChild()
        cleanup = {"elapsed_seconds": 0.01, "cleanup_grace_seconds": 0.1,
                   "termination_confirmed": True, "remaining_process_pids": [],
                   "owned_process_identities": []}
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            with mock.patch.object(RUNNER.subprocess, "Popen", return_value=process), \
                    mock.patch.object(RUNNER.psutil, "Process", side_effect=lambda pid: {
                        4201: root_process, 4202: descendant}[pid]), \
                    mock.patch.object(RUNNER, "terminate_tree", return_value=cleanup) as terminate:
                receipt = RUNNER.run_stage(
                    ["synthetic-child"], root, root / "producer", 4.0, 2147483648, {},
                    {"live_limit_seconds": 4.0, "stage_cap_seconds": 4.0,
                     "cleanup_grace_seconds": 0.1, "remaining_before_seconds": 960.0})
        self.assertEqual(receipt["stop_reason"], "leader_exited_with_live_descendants")
        self.assertEqual(receipt["root_process_identity"], {"pid": 4201, "create_time": 420.1})
        self.assertEqual(receipt["leader_exit_descendant_check"]["active_descendants"],
                         [{"pid": 4202, "create_time": 420.2}])
        terminate.assert_called_once()
        self.assertEqual(terminate.call_args.args[3], (4201, 420.1))
        self.assertEqual(RUNNER.resource_interruption_exit_code(receipt["stop_reason"]), 124)

    def test_run_stage_never_uses_partial_rss_as_a_complete_limit_sample(self) -> None:
        class FakeRoot:
            pid = 4201

            def create_time(self):
                return 420.1

        class FakeChild:
            pid = 4201
            returncode = None

            def poll(self):
                return self.returncode

            def kill(self):
                self.returncode = -9

        child = FakeChild()
        observation = RUNNER.ProcessTreeObservationError(
            "process_identity_or_rss", child.pid, 4202, 2147483647, [],
            PermissionError("injected descendant RSS denial"))
        cleanup = {
            "elapsed_seconds": 0.01,
            "cleanup_grace_seconds": 0.1,
            "termination_confirmed": True,
            "remaining_process_pids": [],
            "owned_process_identities": [],
        }
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            with mock.patch.object(RUNNER.subprocess, "Popen", return_value=child), \
                    mock.patch.object(RUNNER.psutil, "Process", return_value=FakeRoot()), \
                    mock.patch.object(RUNNER, "live_tree_bytes", side_effect=observation), \
                    mock.patch.object(RUNNER, "terminate_tree", return_value=cleanup):
                process = RUNNER.run_stage(
                    ["synthetic-child"], root, root / "producer", 4.0, 2147483648, {},
                    {"live_limit_seconds": 4.0, "stage_cap_seconds": 4.0,
                     "cleanup_grace_seconds": 0.1, "remaining_before_seconds": 960.0})
        self.assertEqual(process["stop_reason"], "process_tree_observation_incomplete")
        self.assertEqual(process["exit_code"], -9)
        self.assertIs(process["rss_sampling_complete"], False)
        self.assertEqual(process["rss_complete_sample_count"], 0)
        self.assertEqual(process["peak_sampled_process_tree_working_set_bytes"], 0)
        self.assertEqual(process["rss_observation_errors"][0]["partial_rss_bytes_not_used_for_gate"], 2147483647)
        self.assertEqual(RUNNER.resource_interruption_exit_code(process["stop_reason"]), 124)

    def test_terminate_tree_wait_exception_keeps_candidates_unconfirmed(self) -> None:
        class FakeProcess:
            def __init__(self, pid: int, children: list[object] | None = None):
                self.pid = pid
                self._children = children or []

            def children(self, recursive: bool = True) -> list[object]:
                return self._children

            def create_time(self) -> float:
                return float(self.pid) / 10

            def terminate(self) -> None:
                pass

            def kill(self) -> None:
                pass

        child = FakeProcess(4202)
        root = FakeProcess(4201, [child])
        wait_error = PermissionError("injected wait_procs failure")
        with mock.patch.object(RUNNER.psutil, "Process", side_effect=lambda pid: {
                    4201: root, 4202: child}[pid]), \
                mock.patch.object(RUNNER.psutil, "wait_procs", side_effect=[wait_error, wait_error]):
            cleanup = RUNNER.terminate_tree(root.pid, 0.2, expected_root_identity=(4201, 420.1))
        self.assertIs(cleanup["termination_confirmed"], False)
        self.assertEqual(cleanup["remaining_process_pids"], [4201, 4202])
        self.assertEqual(cleanup["termination_verification_errors"][0]["stage"], "terminate_wait")
        self.assertEqual(cleanup["termination_verification_errors"][1]["stage"], "kill_wait")
        self.assertEqual(RUNNER.resource_interruption_exit_code("aggregate_cleanup_overrun"), 124)

    def test_terminate_tree_rejects_reused_root_and_unpinned_pid(self) -> None:
        class FakeProcess:
            def __init__(self, pid: int, create_time: float):
                self.pid = pid
                self._create_time = create_time
                self.signals: list[str] = []

            def create_time(self) -> float:
                return self._create_time

            def children(self, recursive: bool = True) -> list[object]:
                return []

            def terminate(self) -> None:
                self.signals.append("terminate")

            def kill(self) -> None:
                self.signals.append("kill")

        recycled = FakeProcess(4201, 999.0)
        with mock.patch.object(RUNNER.psutil, "Process", return_value=recycled), \
                mock.patch.object(RUNNER.psutil, "wait_procs") as wait:
            reused = RUNNER.terminate_tree(
                4201, 0.1, [{"pid": 4201, "create_time": 420.1}], (4201, 420.1))
            unpinned = RUNNER.terminate_tree(4201, 0.1)
        self.assertEqual(recycled.signals, [])
        self.assertIs(reused["process_tree_inventory_complete"], False)
        self.assertIs(reused["termination_confirmed"], False)
        self.assertIn("known_pid_reuse", [x.get("stage") for x in reused["termination_verification_errors"]])
        self.assertIs(unpinned["process_tree_inventory_complete"], False)
        self.assertIs(unpinned["termination_confirmed"], False)
        self.assertIn("root_identity_unpinned", [x.get("stage") for x in unpinned["termination_verification_errors"]])
        wait.assert_not_called()

    def test_terminate_tree_kill_failure_and_unknown_residual_stay_unconfirmed(self) -> None:
        class FakeProcess:
            def __init__(self, pid: int, create_time: float, children: list[object] | None = None,
                         kill_error: Exception | None = None):
                self.pid = pid
                self._create_time = create_time
                self._children = children or []
                self._kill_error = kill_error

            def create_time(self) -> float:
                return self._create_time

            def children(self, recursive: bool = True) -> list[object]:
                return self._children

            def terminate(self) -> None:
                pass

            def kill(self) -> None:
                if self._kill_error is not None:
                    raise self._kill_error

        denied = RUNNER.psutil.AccessDenied(pid=4202)
        child = FakeProcess(4202, 420.2, kill_error=denied)
        root = FakeProcess(4201, 420.1, [child])
        lookup_denied = RUNNER.psutil.AccessDenied(pid=4202)
        def process_lookup(pid: int):
            if pid == 4201:
                return root
            if pid == 4202:
                # The root's tree enumeration saw this pinned child, but its
                # subsequent identity recheck is now unknown.
                raise lookup_denied
            raise RUNNER.psutil.NoSuchProcess(pid)

        with mock.patch.object(RUNNER.psutil, "Process", side_effect=process_lookup), \
                mock.patch.object(RUNNER.psutil, "wait_procs", side_effect=lambda procs, timeout: ([], list(procs))):
            cleanup = RUNNER.terminate_tree(
                root.pid, 0.1, [{"pid": 4201, "create_time": 420.1},
                                {"pid": 4202, "create_time": 420.2}], (4201, 420.1))
        self.assertIs(cleanup["process_tree_inventory_complete"], False)
        self.assertIs(cleanup["termination_confirmed"], False)
        self.assertIn("known_process_lookup", [x.get("stage") for x in cleanup["termination_verification_errors"]])
        self.assertIn("kill_request", [x.get("stage") for x in cleanup["termination_verification_errors"]])
        self.assertEqual(cleanup["remaining_process_pids"], [4201, 4202])

    def test_monitor_uncertainty_blocks_consumer_and_preserves_frozen_limits(self) -> None:
        self.assertEqual(RUNNER.resource_interruption_exit_code("process_tree_observation_incomplete"), 124)
        self.assertEqual(RUNNER.resource_interruption_exit_code("working_set_limit"), 123)
        self.assertIsNone(RUNNER.resource_interruption_exit_code("exited"))
        main = next(node for node in ast.parse(self.runner).body
                    if isinstance(node, ast.FunctionDef) and node.name == "main")
        main_source = ast.get_source_segment(self.runner, main)
        self.assertIsNotNone(main_source)
        self.assertLess(main_source.index('producer["stop_reason"] != "exited"'),
                        main_source.index("build_consumer_launch_command("))
        self.assertIn("resource_interruption_exit_code(str(producer[\"stop_reason\"]))", main_source)
        self.assertIn("resource_interruption_exit_code(str(consumer[\"stop_reason\"]))", main_source)
        self.assertEqual(self.protocol["stage_limits"]["seconds"], 480)
        self.assertEqual(self.protocol["stage_limits"]["working_set_bytes"], 2147483648)
        self.assertEqual(self.protocol["total_child_wall_limit_seconds"], 960)
        self.assertEqual(self.protocol["controller_overhead_seconds_limit"], 120)
        self.assertEqual(self.protocol["preserved_numerical_status"]["solver_exit_code"], 2)
        self.assertIs(self.protocol["runtime_grant"], False)
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_producer_tree_status_is_tri_state_and_does_not_infer_drift(self) -> None:
        tree = ast.parse(self.runner)
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "main")
        main_source = ast.get_source_segment(self.runner, main)
        self.assertIn('producer_tree_comparison_status = "not_reached"', main_source)
        self.assertIn('producer_tree_comparison_status = "changed"', main_source)
        self.assertIn('producer_tree_comparison_status = "unchanged"', main_source)
        self.assertIn('"producer_tree_comparison_status": producer_tree_comparison_status', main_source)
        self.assertIn('else None)', main_source)

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
        self.assertEqual(p["coverage_contract"]["child_argv"]["entrypoint"], p["entrypoint"])
        self.assertIn("V15 tests follow", p["coverage_contract"]["child_argv"]["negative_control"])
        self.assertEqual(producer[6], p["saved_producer_tree"]["root"])

        stale_protocol = copy.deepcopy(p)
        stale_protocol["coverage_contract"]["child_argv"]["entrypoint"] = \
            "test/RuntimeV4/UP2ClosureReplayOnlyV11/replay_staged_v11.jl"
        with self.assertRaisesRegex(ValueError, "coverage description is stale"):
            RUNNER.verify_child_command_contract(stale_protocol)

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
        self.assertIn("verify_v10_replay_failure", called)
        self.assertIn("verify_v11_actual_failure", called)
        self.assertIn("verify_hydration_contract_text", called)
        self.assertIn("verify_v8_context_rebuild_failure", called)
        self.assertIn("verify_v9_static_no_go_ancestry", called)
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "main")
        main_source = ast.get_source_segment(self.runner, main)
        self.assertIsNotNone(main_source)
        self.assertLess(main_source.index("verify_pre_output_contract("), main_source.index("output.mkdir"))
        self.assertFalse(EXPECTED_OUTPUT.exists())

    def test_output_target_is_exact_frozen_r15_leaf(self) -> None:
        sibling = EXPECTED_OUTPUT.parent / "runtime_replay_r15_sibling"
        accepted = RUNNER.resolve_output_target(ROOT, EXPECTED_OUTPUT, self.protocol["output_leaf"])
        self.assertEqual(accepted, EXPECTED_OUTPUT.resolve())
        with self.assertRaisesRegex(ValueError, "exactly to protocol output_leaf"):
            RUNNER.resolve_output_target(ROOT, sibling, self.protocol["output_leaf"])
        with self.assertRaisesRegex(ValueError, "V15 replay-only archive"):
            RUNNER.resolve_output_target(ROOT, ROOT / "tmp/outside_v15", self.protocol["output_leaf"])
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
