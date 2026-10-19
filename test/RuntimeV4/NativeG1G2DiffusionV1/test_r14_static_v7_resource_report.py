"""Python-only tests for the additive R14 v7 resource outcome reporter."""

from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
V7_PROTOCOL_PATH = ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r14_v1/r14_static_v7/protocol.json"
V6_PROTOCOL_PATH = ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r14_v1/r14_static_v6/protocol.json"
sys.path.insert(0, str(HERE))
import report_r14_resource_outcome_v7 as reporter  # noqa: E402


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
        (json.dumps({"process_tree_rss_bytes": value,
                     "elapsed_seconds": float(row) * 0.2}, sort_keys=True) + "\n").encode("utf-8")
        for row, value in enumerate(values)
    )
    (stage_dir / "samples.jsonl").write_bytes(samples)
    peak = max(values, default=0) if declared_peak is None else declared_peak
    final = {
        "schema": "native-g1g2-recorded-stage-v1",
        "index": index,
        "stage": name,
        "exit_code": exit_code,
        "stop_reason": stop_reason,
        "sample_count": len(values),
        "peak_process_tree_rss_bytes": peak,
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
        "runtime_executed": True,
        "status": "pass" if primary_exit == 0 else "fail",
        "stages": [parse, primary],
        "scientific_status": "not_accepted",
        "physical_status": "unknown",
    }
    _write_json(leaf / "summary.json", summary)
    return summary


class R14V7ResourceReporterTests(unittest.TestCase):
    def test_frozen_protocol_pins_reporter_and_declares_resource_failure(self) -> None:
        protocol = json.loads(V7_PROTOCOL_PATH.read_text(encoding="utf-8"))
        reporter_path = Path(reporter.__file__).resolve()
        test_path = Path(__file__).resolve()
        self.assertEqual(protocol["version"], "r14_static_v7")
        self.assertEqual(protocol["julia_started"], False)
        self.assertEqual(protocol["rss_guard"]["threshold_bytes"], THRESHOLD)
        self.assertEqual(protocol["rss_guard"]["enforcement_semantics"], "sampled_stop_trigger")
        self.assertEqual(protocol["rss_guard"]["threshold_reached_or_overshot_disposition"],
                         "resource_failure")
        self.assertEqual(protocol["reporter"]["path"], reporter_path.relative_to(ROOT).as_posix())
        self.assertEqual(protocol["reporter"]["sha256"], hashlib.sha256(reporter_path.read_bytes()).hexdigest())
        self.assertEqual(protocol["static_qa"]["test_path"], test_path.relative_to(ROOT).as_posix())
        self.assertEqual(protocol["static_qa"]["test_sha256"], hashlib.sha256(test_path.read_bytes()).hexdigest())
        self.assertEqual(protocol["parent_v6_protocol_sha256"],
                         hashlib.sha256(V6_PROTOCOL_PATH.read_bytes()).hexdigest())
        self.assertFalse(protocol["runtime_integration"]["runner_bytes_changed"])
        self.assertFalse(protocol["runtime_integration"]["julia_started"])

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
            _write_json(leaf / "summary.json", {"stages": [alien]})
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
