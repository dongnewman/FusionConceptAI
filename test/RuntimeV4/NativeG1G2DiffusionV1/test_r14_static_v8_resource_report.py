"""Python-only tests for the additive R14 v8 resource outcome reporter."""

from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
V8_PROTOCOL_PATH = ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r14_v1/r14_static_v8/protocol.json"
V7_PROTOCOL_PATH = ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r14_v1/r14_static_v7/protocol.json"
V8_RUNNER_PATH = HERE / "run_recorded_r14_v8.py"
V8_PREFLIGHT_PATH = HERE / "r14_prelaunch_preflight_v8.py"
sys.path.insert(0, str(HERE))
import report_r14_resource_outcome_v8 as reporter  # noqa: E402


THRESHOLD = 2_147_483_648


def _write_json(path: Path, value: dict) -> bytes:
    raw = (json.dumps(value, sort_keys=True) + "\n").encode("utf-8")
    path.write_bytes(raw)
    return raw


def _make_stage(leaf: Path, index: int, name: str, values: list[int],
                stop_reason: str, exit_code: int,
                declared_peak: int | None = None) -> dict:
    stage_dir = leaf / f"{index:02d}_{name}"
    stage_dir.mkdir(parents=True)
    samples = b"".join(
        (json.dumps({"utc": f"2026-09-24T00:00:{row:02d}Z",
                     "process_tree_rss_bytes": value,
                     "elapsed_seconds": float(row) * 0.2}, sort_keys=True) + "\n").encode("utf-8")
        for row, value in enumerate(values)
    )
    (stage_dir / "samples.jsonl").write_bytes(samples)
    sampled_peak = max(values, default=0)
    peak = sampled_peak if declared_peak is None else declared_peak
    peak_index = values.index(sampled_peak) if values else None
    final = {
        "schema": "native-g1g2-recorded-stage-v1",
        "index": index,
        "stage": name,
        "exit_code": exit_code,
        "stop_reason": stop_reason,
        "sample_count": len(values),
        "peak_process_tree_rss_bytes": peak,
        "peak_process_tree_rss_sample_index": peak_index + 1 if peak_index is not None else None,
        "peak_process_tree_rss_sample_utc": (
            f"2026-09-24T00:00:{peak_index:02d}Z" if peak_index is not None else None
        ),
        "peak_process_tree_rss_sample_elapsed_seconds": (
            float(peak_index) * 0.2 if peak_index is not None else None
        ),
        "peak_process_tree_rss_sample_bytes": sampled_peak,
        "stdout": {"bytes": 0, "sha256": hashlib.sha256(b"").hexdigest()},
        "stderr": {"bytes": 0, "sha256": hashlib.sha256(b"").hexdigest()},
    }
    _write_json(stage_dir / "final.json", final)
    return final


def _make_run(leaf: Path, primary_values: list[int], primary_stop: str,
              primary_exit: int, declared_peak: int | None = None) -> dict:
    leaf.mkdir(parents=True)
    parse = _make_stage(leaf, 1, "parse_all", [120_000_000], "natural_exit", 0)
    primary = _make_stage(leaf, 2, "primary", primary_values, primary_stop,
                          primary_exit, declared_peak)
    summary = {
        "schema": "native-g1g2-run-summary-v1",
        "mode": "actual",
        "runtime_executed": True,
        "status": "pass" if primary_exit == 0 else "fail",
        "stages": [parse, primary],
        "scientific_status": "not_accepted",
        "physical_status": "unknown",
    }
    _write_json(leaf / "summary.json", summary)
    return summary


class R14V8ResourceReporterTests(unittest.TestCase):
    def test_frozen_protocol_pins_reporter_and_declares_resource_failure(self) -> None:
        protocol = json.loads(V8_PROTOCOL_PATH.read_text(encoding="utf-8"))
        reporter_path = Path(reporter.__file__).resolve()
        test_path = Path(__file__).resolve()
        self.assertEqual(protocol["version"], "r14_static_v8")
        self.assertEqual(protocol["julia_started"], False)
        self.assertEqual(protocol["runtime_contract"]["rss_threshold_bytes"], THRESHOLD)
        self.assertEqual(protocol["runtime_contract"]["rss_enforcement_semantics"], "sampled_stop_trigger")
        self.assertTrue(protocol["runtime_contract"]["sampled_overshoot_possible"])
        self.assertEqual(protocol["runtime_contract"]["sampled_threshold_hit_or_overshoot_disposition"],
                         "resource_failure")
        self.assertNotIn("os_enforced_hard_cap", protocol["runtime_contract"])
        rss_output = protocol["runner"]["rss_output"]
        self.assertTrue(rss_output["sampled_overshoot_possible"])
        self.assertNotIn("os_enforced_hard_cap", rss_output)
        self.assertEqual(rss_output["per_stage_peak_sample_time_fields"], [
            "peak_process_tree_rss_sample_index",
            "peak_process_tree_rss_sample_utc",
            "peak_process_tree_rss_sample_elapsed_seconds",
            "peak_process_tree_rss_sample_bytes",
        ])
        self.assertEqual(protocol["reporter"]["path"], reporter_path.relative_to(ROOT).as_posix())
        self.assertEqual(protocol["reporter"]["sha256"], hashlib.sha256(reporter_path.read_bytes()).hexdigest())
        self.assertEqual(protocol["static_qa"]["reporter_test_path"], test_path.relative_to(ROOT).as_posix())
        self.assertEqual(protocol["static_qa"]["reporter_test_sha256"], hashlib.sha256(test_path.read_bytes()).hexdigest())
        self.assertEqual(protocol["parent_v7_protocol_sha256"],
                         hashlib.sha256(V7_PROTOCOL_PATH.read_bytes()).hexdigest())
        self.assertEqual(protocol["runner"]["path"], V8_RUNNER_PATH.relative_to(ROOT).as_posix())
        self.assertEqual(protocol["runner"]["sha256"], hashlib.sha256(V8_RUNNER_PATH.read_bytes()).hexdigest())
        self.assertEqual(protocol["preflight"]["path"], V8_PREFLIGHT_PATH.relative_to(ROOT).as_posix())
        self.assertEqual(protocol["preflight"]["sha256"], hashlib.sha256(V8_PREFLIGHT_PATH.read_bytes()).hexdigest())
        self.assertFalse(protocol["static_launcher_invocation"]["julia_started"])

    def test_overshoot_emits_resource_failure_and_preserves_raw_stage_fields(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            leaf = Path(temporary) / "actual"
            _make_run(leaf, [1_000_000_000, THRESHOLD + 49_065_984],
                      "process_tree_rss_limit", 15)
            final_before = (leaf / "02_primary/final.json").read_bytes()
            samples_before = (leaf / "02_primary/samples.jsonl").read_bytes()

            report_path = reporter.write_new_report(leaf)
            report = json.loads(report_path.read_text(encoding="utf-8"))
            primary = report["stage_reports"][1]
            self.assertEqual(report["run_disposition"], "resource_failure")
            self.assertTrue(report["resource_failure"])
            self.assertEqual(primary["disposition"], "resource_failure")
            self.assertEqual(primary["rss_threshold"]["threshold_bytes"], THRESHOLD)
            self.assertEqual(primary["rss_threshold"]["overshoot_bytes"], 49_065_984)
            self.assertEqual(primary["peak_sample"], {
                "sample_index": 2,
                "utc": "2026-09-24T00:00:01Z",
                "elapsed_seconds": 0.2,
                "rss_bytes": THRESHOLD + 49_065_984,
                "tie_rule": "first sample among equal maxima",
            })
            self.assertEqual(primary["low_level_stage_outcome"]["stop_reason"],
                             "process_tree_rss_limit")
            self.assertEqual(primary["low_level_stage_outcome"]["exit_code"], 15)
            self.assertEqual(primary["input_receipts"]["samples_sha256"],
                             hashlib.sha256(samples_before).hexdigest())
            self.assertEqual((leaf / "02_primary/final.json").read_bytes(), final_before)
            self.assertEqual((leaf / "02_primary/samples.jsonl").read_bytes(), samples_before)
            self.assertEqual(report["claim_boundary"]["numerical_status"], "not_established")
            self.assertEqual(report["claim_boundary"]["physical_status"], "unknown")

    def test_exact_threshold_hit_is_also_resource_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            leaf = Path(temporary) / "actual"
            _make_run(leaf, [THRESHOLD], "process_tree_rss_limit", 15)
            report = reporter.build_report(leaf)
            primary = report["stage_reports"][1]
            self.assertEqual(report["run_disposition"], "resource_failure")
            self.assertEqual(primary["rss_threshold"]["overshoot_bytes"], 0)
            self.assertTrue(primary["rss_threshold"]["sampled_threshold_hit"])
            self.assertEqual(primary["peak_sample"]["sample_index"], 1)
            self.assertEqual(primary["peak_sample"]["elapsed_seconds"], 0.0)

    def test_below_threshold_report_does_not_claim_solver_success(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            leaf = Path(temporary) / "actual"
            _make_run(leaf, [THRESHOLD - 1], "natural_exit", 0)
            report = reporter.build_report(leaf)
            self.assertEqual(report["run_disposition"], "no_sampled_rss_threshold_crossing")
            self.assertFalse(report["resource_failure"])
            self.assertEqual(report["claim_boundary"]["numerical_status"], "not_established")
            self.assertEqual(report["claim_boundary"]["physical_status"], "unknown")
            self.assertFalse(report["claim_boundary"]["solver_success_claimed"])
            self.assertIsNotNone(report["stage_reports"][1]["peak_sample"]["utc"])

    def test_sampled_overshoot_wins_but_preserves_conflicting_low_level_stop_reason(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            leaf = Path(temporary) / "actual"
            _make_run(leaf, [THRESHOLD + 7], "natural_exit", 0)
            report = reporter.build_report(leaf)
            primary = report["stage_reports"][1]
            self.assertEqual(primary["disposition"], "resource_failure")
            self.assertEqual(primary["low_level_stage_outcome"]["stop_reason"], "natural_exit")
            self.assertEqual(primary["low_level_stage_outcome"]["threshold_stop_consistency"],
                             "sampled_threshold_hit_but_low_level_stop_reason_differs")

    def test_final_peak_disagreement_with_raw_sample_series_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            leaf = Path(temporary) / "actual"
            _make_run(leaf, [THRESHOLD + 1], "process_tree_rss_limit", 15,
                      declared_peak=THRESHOLD)
            with self.assertRaisesRegex(ValueError, "summary disagrees|peak RSS disagrees"):
                reporter.build_report(leaf)

    def test_rss_limit_stop_without_threshold_sample_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            leaf = Path(temporary) / "actual"
            _make_run(leaf, [THRESHOLD - 10], "process_tree_rss_limit", 15)
            with self.assertRaisesRegex(ValueError, "no sampled threshold hit"):
                reporter.build_report(leaf)

    def test_unknown_stage_name_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            leaf = Path(temporary) / "actual"
            leaf.mkdir()
            alien = _make_stage(leaf, 1, "parse_all", [100], "natural_exit", 0)
            alien["stage"] = "../outside"
            _write_json(leaf / "summary.json", {
                "mode": "actual",
                "runtime_executed": True,
                "stages": [alien],
            })
            with self.assertRaisesRegex(ValueError, "stage order"):
                reporter.build_report(leaf)

    def test_existing_report_is_never_overwritten(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            leaf = Path(temporary) / "actual"
            _make_run(leaf, [100], "natural_exit", 0)
            output = leaf / reporter.OUTPUT_FILENAME
            sentinel = b"preserve existing evidence\n"
            output.write_bytes(sentinel)
            with self.assertRaises(FileExistsError):
                reporter.write_new_report(leaf)
            self.assertEqual(output.read_bytes(), sentinel)

    def test_static_only_empty_summary_cannot_be_classified(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            leaf = Path(temporary) / "static_only"
            leaf.mkdir()
            _write_json(leaf / "summary.json", {
                "schema": "native-g1g2-run-summary-v1",
                "mode": "static_only",
                "runtime_executed": False,
                "stages": [],
            })
            with self.assertRaisesRegex(ValueError, "runtime_executed must be true"):
                reporter.build_report(leaf)

    def test_missing_or_false_runtime_executed_is_rejected(self) -> None:
        for summary in (
            {"mode": "actual", "stages": []},
            {"mode": "actual", "runtime_executed": False, "stages": []},
        ):
            with self.subTest(summary=summary), tempfile.TemporaryDirectory() as temporary:
                leaf = Path(temporary) / "actual"
                leaf.mkdir()
                _write_json(leaf / "summary.json", summary)
                with self.assertRaisesRegex(ValueError, "runtime_executed must be true"):
                    reporter.build_report(leaf)

    def test_true_runtime_with_empty_stages_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            leaf = Path(temporary) / "actual"
            leaf.mkdir()
            _write_json(leaf / "summary.json", {"runtime_executed": True, "stages": []})
            with self.assertRaisesRegex(ValueError, "at least one actual stage"):
                reporter.build_report(leaf)

    def test_static_only_mode_is_rejected_even_if_runtime_flag_conflicts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            leaf = Path(temporary) / "static_only"
            leaf.mkdir()
            stage = _make_stage(leaf, 1, "parse_all", [10], "natural_exit", 0)
            _write_json(leaf / "summary.json", {
                "mode": "static_only",
                "runtime_executed": True,
                "stages": [stage],
            })
            with self.assertRaisesRegex(ValueError, "static_only"):
                reporter.build_report(leaf)

    def test_one_valid_actual_stage_is_sufficient_for_diagnostic_report(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            leaf = Path(temporary) / "actual"
            leaf.mkdir()
            stage = _make_stage(leaf, 1, "parse_all", [10], "natural_exit", 0)
            _write_json(leaf / "summary.json", {
                "mode": "actual",
                "runtime_executed": True,
                "stages": [stage],
            })
            report = reporter.build_report(leaf)
            self.assertEqual(report["run_disposition"], "no_sampled_rss_threshold_crossing")
            self.assertEqual(report["stage_reports"][0]["peak_sample"]["sample_index"], 1)

    def test_missing_raw_peak_timestamp_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            leaf = Path(temporary) / "actual"
            _make_run(leaf, [50, 100], "natural_exit", 0)
            rows = [json.loads(line) for line in (leaf / "02_primary/samples.jsonl").read_text().splitlines()]
            rows[-1].pop("utc")
            (leaf / "02_primary/samples.jsonl").write_text(
                "".join(json.dumps(row, sort_keys=True) + "\n" for row in rows), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "utc must be a non-empty string"):
                reporter.build_report(leaf)

    def test_missing_raw_peak_elapsed_time_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            leaf = Path(temporary) / "actual"
            _make_run(leaf, [50, 100], "natural_exit", 0)
            rows = [json.loads(line) for line in (leaf / "02_primary/samples.jsonl").read_text().splitlines()]
            rows[-1]["elapsed_seconds"] = -0.2
            (leaf / "02_primary/samples.jsonl").write_text(
                "".join(json.dumps(row, sort_keys=True) + "\n" for row in rows), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "finite and nonnegative"):
                reporter.build_report(leaf)

    def test_empty_rss_sample_series_is_not_classified_as_no_crossing(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            leaf = Path(temporary) / "actual"
            _make_run(leaf, [], "natural_exit", 0)
            with self.assertRaisesRegex(ValueError, "at least one sample"):
                reporter.build_report(leaf)

    def test_reporter_source_declares_truthful_runner_semantics_and_peak_time(self) -> None:
        runner = V8_RUNNER_PATH.read_text(encoding="utf-8")
        self.assertIn('"rss_enforcement_semantics": "sampled_stop_trigger"', runner)
        self.assertIn('"sampled_overshoot_possible": True', runner)
        self.assertIn('"sampled_threshold_hit_or_overshoot_disposition": "resource_failure"', runner)
        self.assertIn('"peak_process_tree_rss_sample_utc"', runner)
        self.assertIn('"peak_process_tree_rss_sample_elapsed_seconds"', runner)
        self.assertNotIn('"whole_tree_rss_hard_cap_bytes"', runner)
        self.assertNotIn('"rss_limit_is_hard_stop"', runner)
        self.assertNotIn('"os_enforced_hard_cap"', runner)
        self.assertNotIn('"hard_cap"', runner)


if __name__ == "__main__":
    unittest.main(verbosity=2)
