"""Static-only QA for the R14 v6 sampled-RSS semantic correction.

This verifies frozen runner/protocol ancestry and R13 sampled evidence. It
does not launch Julia and does not amend the R14 runtime recorder.
"""

from __future__ import annotations

import copy
import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ARCHIVE = ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r14_v1"
V6_DIR = ARCHIVE / "r14_static_v6"
PROTOCOL_PATH = V6_DIR / "protocol.json"
V5_DIR = ARCHIVE / "r14_static_v5"
V5_PROTOCOL = V5_DIR / "protocol.json"
V5_HANDOFF = V5_DIR / "r14_static_handoff.json"
V5_STATIC = V5_DIR / "static_preflight.json"
R13_DIR = ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_actual_v1"
R13_SUMMARY = R13_DIR / "summary.json"
R13_SAMPLES = R13_DIR / "02_primary/samples.jsonl"

RSS_THRESHOLD = 2_147_483_648
PINNED_SHA256 = {
    ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/run_recorded_r14.py":
        "b2c5682f454d990e212538c24361e5b873731dbff96a1fc5f622bcf779ec1930",
    ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/r14_prelaunch_preflight.py":
        "1891f65a28b00c8cfa76ab72f3ef5988ed77897753e9335be0795eca7be9c812",
    ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/test_r14_prelaunch_preflight.py":
        "074917166609945e0f46da88f92657e4ddf930fb4eadea8a463783869412302a",
    ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests_r14_compile_min.jl":
        "7365639c802b3ff2ac5106bf368ea7ceea307afbe9bbfc78822907b186a99f78",
    V5_PROTOCOL:
        "20f5dadbca24663dc5d25888e46cc4082ac816ae202edeb1ea4ef602739f0db4",
    V5_HANDOFF:
        "784d4a0fc4f7d4fac25b96ecc24ccd31c7db5b90869e4b98e878ff08ab7ffeb9",
    V5_STATIC:
        "c111e96a35c4651956972dff819dea1ed8d8f1510b099c612391c3abf8d8f8cd",
    R13_SUMMARY:
        "e0ebc5cfd90ac36f4249af1022a2f05277c3e9850816244ca63bbb40ce1a5044",
    R13_SAMPLES:
        "8f018ea7d4ae7e9f86b78229420f68d06d34b87f7b51d84207394b92810918af",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_rss_semantics(protocol: dict) -> None:
    guard = protocol["rss_guard_semantics"]
    assert guard["threshold_bytes"] == RSS_THRESHOLD
    assert guard["sample_interval_seconds"] == 0.2
    assert guard["enforcement_semantics"] == "sampled_stop_trigger"
    assert guard["os_enforced_hard_cap"] is False
    assert guard["stop_when_sampled_rss_greater_than_or_equal_to_threshold"] is True
    assert guard["threshold_reached_or_overshot_disposition"] == "resource_failure"
    assert guard["overshoot_disposition"] == "resource_failure"
    assert "not the continuous peak" in guard["observed_peak_semantics"]
    assert "may exceed" in guard["between_sample_peak"]
    assert guard["no_success_from_threshold_stop"] is True


class R14StaticV6RssSemanticsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        cls.v5_handoff = json.loads(V5_HANDOFF.read_text(encoding="utf-8"))

    def test_frozen_r14_and_r13_ancestry_pins_match(self) -> None:
        for path, expected in PINNED_SHA256.items():
            with self.subTest(path=path.relative_to(ROOT).as_posix()):
                self.assertTrue(path.is_file())
                self.assertEqual(sha256(path), expected)

    def test_rss_guard_is_a_sampled_stop_trigger_not_a_hard_cap(self) -> None:
        validate_rss_semantics(self.protocol)
        self.assertEqual(self.protocol["version"], "r14_static_v6")
        self.assertEqual(self.protocol["status"], "static_candidate_for_independent_review_only")
        self.assertFalse(self.protocol["julia_started"])

    def test_r13_over_threshold_sample_is_exactly_resource_failure(self) -> None:
        observation = self.protocol["r13_observed_overshoot"]
        rows = [json.loads(line) for line in R13_SAMPLES.read_text(encoding="utf-8").splitlines() if line]
        sampled = [int(row["process_tree_rss_bytes"]) for row in rows]
        maximum = max(sampled)
        above = sum(value > RSS_THRESHOLD for value in sampled)
        self.assertEqual(len(rows), observation["sample_count"])
        self.assertEqual(maximum, observation["maximum_sampled_rss_bytes"])
        self.assertEqual(maximum, 2_196_549_632)
        self.assertEqual(maximum - RSS_THRESHOLD, observation["overshoot_bytes"])
        self.assertEqual(maximum - RSS_THRESHOLD, 49_065_984)
        self.assertEqual(above, observation["samples_at_or_above_threshold"])
        self.assertEqual(observation["corrected_stage_disposition"], "resource_failure")

    def test_v5_compile_mode_fixtures_and_budget_are_inherited(self) -> None:
        execution = self.protocol["execution_invariants_inherited_unchanged"]
        base = self.v5_handoff["r14_strategy"]
        self.assertEqual(execution["wall_seconds_per_stage"], base["wall_seconds_per_stage"])
        self.assertEqual(execution["wall_seconds_per_stage"], 480.0)
        self.assertEqual(execution["process_tree_rss_stop_threshold_bytes"], RSS_THRESHOLD)
        self.assertEqual(base["process_tree_rss_hard_cap_bytes"], RSS_THRESHOLD)
        self.assertEqual(execution["julia_heap_size_hint"], base["julia_heap_size_hint"])
        self.assertEqual(execution["julia_threads"], base["julia_threads"])
        self.assertEqual(execution["blas_threads"], base["blas_threads"])
        self.assertFalse(execution["fixtures_and_mesh_levels_changed"])
        self.assertFalse(execution["numerical_thresholds_changed"])
        self.assertEqual(execution["runtime_argv_delta_from_r13"], base["runtime_argv_delta"])
        self.assertEqual(execution["runtime_argv_delta_from_r14_static_v5"], "none; exact stage argv inherited from pinned v5 handoff")
        self.assertEqual([item["stage"] for item in self.v5_handoff["static_candidate"]["stage_commands"]], [
            "parse_all", "primary", "fresh_replay"
        ])
        for item in self.v5_handoff["static_candidate"]["stage_commands"]:
            argv = item["argv"]
            self.assertEqual(argv.count("--compile=min"), 1)
            self.assertEqual(argv.index("--compile=min"), argv.index("--threads=1") + 1)

    def test_negative_control_rejects_nonfailure_overshoot(self) -> None:
        mutated = copy.deepcopy(self.protocol)
        mutated["rss_guard_semantics"]["overshoot_disposition"] = "accepted"
        with self.assertRaises(AssertionError):
            validate_rss_semantics(mutated)

    def test_negative_control_rejects_hard_cap_claim(self) -> None:
        mutated = copy.deepcopy(self.protocol)
        mutated["rss_guard_semantics"]["os_enforced_hard_cap"] = True
        with self.assertRaises(AssertionError):
            validate_rss_semantics(mutated)

    def test_negative_control_rejects_threshold_widening(self) -> None:
        mutated = copy.deepcopy(self.protocol)
        mutated["rss_guard_semantics"]["threshold_bytes"] = RSS_THRESHOLD + 1
        with self.assertRaises(AssertionError):
            validate_rss_semantics(mutated)

    def test_runtime_reporter_gap_keeps_candidate_not_dispatch_ready(self) -> None:
        reporter = self.protocol["runtime_reporter_boundary"]
        self.assertFalse(reporter["runner_bytes_changed_in_v6"])
        self.assertTrue(reporter["protocol_level_classification_only"])
        self.assertTrue(reporter["runtime_output_must_emit_resource_failure_before_actual_dispatch"])
        self.assertEqual(reporter["status"], "not_updated_not_dispatch_ready")


if __name__ == "__main__":
    unittest.main(verbosity=2)
