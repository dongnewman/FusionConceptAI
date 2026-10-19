"""Python-only preflight/contract negatives; does not launch Julia or Gridap."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

import run_native_g1g2_gridap_consumer_r24_v1 as r24


PROTOCOL = r24.repo_path(r24.REL_PROTOCOL)


def load_candidate() -> dict:
    return r24.load_protocol(PROTOCOL)


class R24ProtocolContractTests(unittest.TestCase):
    def test_frozen_r13_resource_and_consumer_gates(self) -> None:
        protocol = load_candidate()
        r24.validate_protocol_shape(protocol)
        self.assertEqual(protocol["limits"]["sample_interval_seconds"], 0.2)
        self.assertEqual(protocol["limits"]["wall_seconds_per_stage"], 480.0)
        self.assertEqual(protocol["limits"]["sampled_rss_stop_threshold_bytes"], 2_147_483_648)
        self.assertEqual(protocol["limits"]["julia_heap_size_hint"], "1G")
        self.assertEqual(protocol["limits"]["compiler_mode"], "--compile=min")
        self.assertEqual(protocol["execution_plan"]["stage_order"], ["parse_all", "primary", "fresh_replay"])
        self.assertTrue(protocol["fixture_and_solver_thresholds_unchanged"])
        self.assertTrue(protocol["execution_plan"]["compile_min_is_only_non_path_argv_delta_from_R13"])
        self.assertFalse(protocol["acceptance_boundary"]["numerical_credit"])
        self.assertFalse(protocol["acceptance_boundary"]["physical_credit"])

    def test_static_and_actual_argv_roles_do_not_alias(self) -> None:
        protocol = load_candidate()
        contract = protocol["invocation_contract"]
        self.assertNotEqual(contract["static_verifier_argv"], contract["actual_supervisor_argv"])
        r24.validate_invocation("static_verifier", contract["static_verifier_argv"], protocol)
        r24.validate_invocation("actual_supervisor", contract["actual_supervisor_argv"], protocol)
        with self.assertRaisesRegex(r24.PreflightError, "selected role"):
            r24.validate_invocation("actual_supervisor", contract["static_verifier_argv"], protocol)
        with self.assertRaisesRegex(r24.PreflightError, "selected role"):
            r24.validate_invocation("static_verifier", contract["actual_supervisor_argv"], protocol)

    def test_stage_commands_use_one_frozen_consumer_and_only_compile_min_delta(self) -> None:
        protocol = load_candidate()
        output = r24.repo_path(protocol["planned_output_leaf"])
        commands = r24.planned_stage_commands(protocol, output)
        self.assertEqual([x["stage"] for x in commands], ["parse_all", "primary", "fresh_replay"])
        primary, replay = commands[1]["argv"], commands[2]["argv"]
        self.assertEqual(primary[-2], "primary")
        self.assertEqual(replay[-2], "replay")
        self.assertEqual(primary[-3], replay[-3])
        self.assertTrue(primary[-3].endswith("focused_tests_r14_compile_min.jl"))
        for plan in commands:
            argv = plan["argv"]
            self.assertEqual(argv.count("--compile=min"), 1)
            self.assertEqual(argv.count("--threads=1"), 1)
            self.assertIn("--heap-size-hint=1G", argv)

    def test_stage_contract_mutation_is_rejected(self) -> None:
        protocol = load_candidate()
        protocol["limits"]["sample_interval_seconds"] = 0.25
        with self.assertRaisesRegex(r24.PreflightError, "resource/compiler contract"):
            r24.validate_protocol_shape(protocol)

    def test_protocol_rejects_duplicate_or_missing_source_pins(self) -> None:
        protocol = load_candidate()
        protocol["input_pins"].append(dict(protocol["input_pins"][0]))
        with self.assertRaisesRegex(r24.PreflightError, "duplicated"):
            r24.validate_protocol_shape(protocol)
        protocol = load_candidate()
        protocol["input_pins"] = [x for x in protocol["input_pins"]
                                  if x["path"] != r24.REL_FOCUSED]
        protocol["input_pin_count"] = len(protocol["input_pins"])
        with self.assertRaisesRegex(r24.PreflightError, "required consumer/helper"):
            r24.validate_protocol_shape(protocol)

    def test_pin_checker_detects_modified_input_without_dispatch(self) -> None:
        protocol = load_candidate()
        pin = next(x for x in protocol["input_pins"] if x["path"] == "Project.toml")
        original = dict(pin)
        pin["sha256"] = "0" * 64
        with self.assertRaisesRegex(r24.PreflightError, "frozen input pins"):
            r24.verify_input_pins(protocol)
        pin.update(original)

    def test_runtime_entry_requires_explicit_dispatch_mode(self) -> None:
        with self.assertRaisesRegex(r24.PreflightError, "explicit --dispatch-actual"):
            r24.main(["--protocol", str(PROTOCOL), "--output", str(r24.repo_path(r24.REL_OUTPUT))])

    def test_sampled_rss_gate_is_fail_closed_and_keeps_no_credit(self) -> None:
        _, audit = r24._load_r23()
        below = audit.sampled_resource_disposition([
            {"complete": True, "rss_bytes": 2_147_483_647, "elapsed_seconds": 2.0}])
        hit = audit.sampled_resource_disposition([
            {"complete": True, "rss_bytes": 2_147_483_648, "elapsed_seconds": 2.0}])
        overshoot = audit.sampled_resource_disposition([
            {"complete": True, "rss_bytes": 2_196_549_632, "elapsed_seconds": 242.0}])
        incomplete = audit.sampled_resource_disposition([
            {"complete": False, "rss_bytes": None, "elapsed_seconds": 2.0}])
        self.assertEqual(below["disposition"], "no_sampled_rss_threshold_crossing")
        self.assertEqual(hit["disposition"], "resource_failure")
        self.assertEqual(overshoot["disposition"], "resource_failure")
        self.assertEqual(incomplete["disposition"], "resource_monitor_incomplete")
        for result in (below, hit, overshoot, incomplete):
            self.assertFalse(result["numerical_credit"])
            self.assertEqual(result.get("physical_status"), "unknown")

    def test_r23_exact_generation_apis_are_the_only_runtime_identity_path(self) -> None:
        source = Path(r24.repo_path(r24.REL_RUNNER)).read_text(encoding="utf-8")
        for anchor in ("bind_popen_generation", "sample_process_tree",
                       "signal_exact_process", "read_process_handle_identity",
                       "query_native_process_table", "audit_residual_identities"):
            self.assertIn(anchor, source)
        self.assertNotIn("process.terminate(", source)
        self.assertNotIn("process.kill(", source)
        self.assertNotIn("create_time()", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
