#!/usr/bin/env python3
"""Independent Python-only contract checks for the frozen MMS replay V8."""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import importlib.util
import io
import json
import pathlib
import sys
import tempfile
import time
import types
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[4]
PROTOCOL_REL = pathlib.Path(
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_continuation_r8/replay_protocol_v8.json"
)
PROTOCOL_PATH = ROOT / PROTOCOL_REL
EXPECTED_PROTOCOL_SHA = "870b8a0ba496dda07e41bb84bafa3b0cfe6782f7a4673f0b9499876c4b54f8b5"
EXPECTED_CONTROLLER_SHA = "55f322d920d3579b8181b356e95c2d2ebdcd22816c43f3369c903d65c4facd28"
EXPECTED_SUITE_SHA = "8cb316c183d430ab279494600ec1d847ba0cec0b1aabc4d0906fcabe78f072c9"
EXPECTED_OUTPUT_REL = pathlib.Path(
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_continuation_r8/runtime_replay_r8"
)
CONTROLLER_PATH = ROOT / "test/RuntimeV4/UP2ClosureReplayOnlyV8/run_replay_staged_v8.py"
SUITE_PATH = ROOT / "test/RuntimeV4/UP2ClosureReplayOnlyV8/test_contract_v8.py"
RUNNER_MODULE_NAME = "independent_mms_v8_runner"

sys.dont_write_bytecode = True


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_json_sha(value: object) -> str:
    data = (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    return sha256_bytes(data)


def verify_pin(row: dict[str, object], label: str) -> pathlib.Path:
    rel = pathlib.PurePosixPath(str(row["path"]))
    if rel.is_absolute() or ".." in rel.parts:
        raise AssertionError(f"unsafe or non-relative pin ({label}): {rel}")
    path = ROOT.joinpath(*rel.parts)
    if not path.is_file():
        raise AssertionError(f"pinned file missing ({label}): {rel}")
    size = path.stat().st_size
    digest = sha256_file(path)
    if size != row.get("bytes") or digest != row.get("sha256"):
        raise AssertionError(f"pinned bytes or SHA drift ({label}): {rel}")
    return path


def load_runner():
    spec = importlib.util.spec_from_file_location(RUNNER_MODULE_NAME, CONTROLLER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("could not create a source loader for the pinned V8 controller")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


RUNNER = load_runner()
PROTOCOL = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))


class IndependentMmsV8ContractTests(unittest.TestCase):
    closure_summary: dict[str, object] = {}

    def test_frozen_protocol_sources_and_89_119_live_input_closure(self) -> None:
        self.assertEqual(PROTOCOL_PATH.stat().st_size, 93321)
        self.assertEqual(sha256_file(PROTOCOL_PATH), EXPECTED_PROTOCOL_SHA)
        self.assertEqual(sha256_file(CONTROLLER_PATH), EXPECTED_CONTROLLER_SHA)
        self.assertEqual(sha256_file(SUITE_PATH), EXPECTED_SUITE_SHA)
        self.assertEqual(PROTOCOL["schema"], "mms-replay-only-continuation-protocol-v8")
        self.assertIs(PROTOCOL["runtime_grant"], False)
        self.assertEqual(PROTOCOL["state"], "review_candidate_ungranted_no_julia")
        self.assertEqual(PROTOCOL["owned_source_files_by_path"][CONTROLLER_PATH.relative_to(ROOT).as_posix()],
                         EXPECTED_CONTROLLER_SHA)

        rows_to_check: list[tuple[str, dict[str, object]]] = []
        for row in PROTOCOL["owned_source_files"]:
            rows_to_check.append(("owned_source", row))
        for row in PROTOCOL["owned_evidence_docs"]:
            rows_to_check.append(("owned_evidence", row))
        for label, row in PROTOCOL["replay_inputs"].items():
            rows_to_check.append((f"replay_input:{label}", row))
        for label, row in PROTOCOL["v10_timeout_receipts"].items():
            rows_to_check.append((f"v10_timeout:{label}", row))

        v10_protocol_row = PROTOCOL["v10_protocol"]
        v10_protocol_path = ROOT / v10_protocol_row["path"]
        self.assertTrue(v10_protocol_path.is_file())
        self.assertEqual(sha256_file(v10_protocol_path), v10_protocol_row["sha256"])
        v10_protocol_snapshot = {
            "path": v10_protocol_row["path"],
            "bytes": v10_protocol_path.stat().st_size,
            "sha256": v10_protocol_row["sha256"],
        }
        rows_to_check.append(("v10_protocol_sha_pin", v10_protocol_snapshot))
        v10 = json.loads(v10_protocol_path.read_text(encoding="utf-8"))
        self.assertEqual(len(v10["inputs"]), 89)
        self.assertEqual(v10_protocol_row["pinned_input_count"], 89)
        for row in v10["inputs"]:
            rows_to_check.append(("v10_actual_input", row))

        tree = PROTOCOL["saved_producer_tree"]
        tree_root = ROOT.joinpath(*pathlib.PurePosixPath(tree["root"]).parts)
        self.assertTrue(tree_root.is_dir())
        self.assertEqual(len(tree["entries"]), 119)
        actual_tree_entries: list[dict[str, object]] = []
        for path in sorted(p for p in tree_root.rglob("*") if p.is_file()):
            actual_tree_entries.append({
                "path": path.relative_to(ROOT).as_posix(),
                "bytes": path.stat().st_size,
                "sha256": sha256_file(path),
            })
        self.assertEqual(actual_tree_entries, tree["entries"])
        self.assertEqual(tree["file_count"], 119)
        self.assertEqual(sum(int(row["bytes"]) for row in actual_tree_entries), 6590185)
        self.assertEqual(canonical_json_sha(actual_tree_entries), tree["sha256"])

        for row in tree["entries"]:
            rows_to_check.append(("saved_producer_tree", row))

        v7 = PROTOCOL["parent_v7_protocol"]
        rows_to_check.append(("v7_protocol", {
            "path": v7["path"],
            "bytes": (ROOT / v7["path"]).stat().st_size,
            "sha256": v7["sha256"],
        }))
        for label in ("report", "manifest", "commands"):
            review = PROTOCOL["parent_v7_independent_review"]
            path_field, hash_field = f"{label}_path", f"{label}_sha256"
            rows_to_check.append((f"v7_review:{label}", {
                "path": review[path_field],
                "bytes": (ROOT / review[path_field]).stat().st_size,
                "sha256": review[hash_field],
            }))

        unique_pins: dict[str, tuple[int, str]] = {}
        for label, row in rows_to_check:
            verify_pin(row, label)
            key = str(row["path"])
            identity = (int(row["bytes"]), str(row["sha256"]))
            if key in unique_pins and unique_pins[key] != identity:
                self.fail(f"conflicting pins for {key}")
            unique_pins[key] = identity
        closure_fingerprint = canonical_json_sha([
            {"path": path, "bytes": size, "sha256": digest}
            for path, (size, digest) in sorted(unique_pins.items())
        ])

        output_path = ROOT / EXPECTED_OUTPUT_REL
        self.assertFalse(output_path.exists(), "frozen runtime output leaf must remain absent")
        self.assertEqual(PROTOCOL["total_child_wall_limit_seconds"], 960)
        self.assertEqual(PROTOCOL["controller_overhead_seconds_limit"], 120)
        self.assertEqual(PROTOCOL["stage_limits"]["seconds"], 480)
        self.assertEqual(PROTOCOL["stage_limits"]["working_set_bytes"], 2**31)
        self.assertEqual(PROTOCOL["termination_cleanup_grace_seconds"], 6)
        self.assertFalse(output_path.exists(), "read-only pin validation must not create output")
        IndependentMmsV8ContractTests.closure_summary = {
            "unique_pinned_path_count": len(unique_pins),
            "v10_actual_input_count": len(v10["inputs"]),
            "saved_producer_tree_file_count": len(actual_tree_entries),
            "saved_producer_tree_bytes": sum(int(row["bytes"]) for row in actual_tree_entries),
            "saved_producer_tree_sha256": tree["sha256"],
            "verified_closure_fingerprint_sha256": closure_fingerprint,
            "output_leaf_absent": True,
        }

    def test_shared_960_second_budget_and_fail_closed_boundaries(self) -> None:
        contract = RUNNER.validate_aggregate_child_wall_contract(PROTOCOL)
        self.assertEqual(contract["total_limit_seconds"], 960.0)
        self.assertEqual(contract["stage_limit_seconds"], 480.0)
        self.assertEqual(contract["cleanup_grace_seconds"], 6.0)
        self.assertEqual(contract["poll_reserve_seconds"], 0.25)

        # Producer Popen-to-observed-exit time plus cleanup has already spent 486s.
        consumer = RUNNER.stage_child_wall_budget(960, 486, 480, 6)
        self.assertEqual(consumer["remaining_before_seconds"], 474.0)
        self.assertEqual(consumer["live_limit_seconds"], 467.75)
        self.assertLessEqual(486.0 + consumer["live_limit_seconds"] + 6.0 + 0.25, 960.0)

        underfunded = dict(PROTOCOL)
        underfunded["total_child_wall_limit_seconds"] = 959
        with self.assertRaisesRegex(ValueError, "below combined producer/consumer stage caps"):
            RUNNER.validate_aggregate_child_wall_contract(underfunded)
        for spent in (953.75, 960.001):
            with self.subTest(spent=spent):
                with self.assertRaises(RUNNER.AggregateChildWallBudgetExhausted):
                    RUNNER.stage_child_wall_budget(960, spent, 480, 6)
        with self.assertRaisesRegex(ValueError, "finite numbers"):
            RUNNER.stage_child_wall_budget(960, float("nan"), 480, 6)

    def test_popen_to_observed_exit_interval_includes_bounded_cleanup(self) -> None:
        class SimulatedPopen:
            pid = 987654321

            def __init__(self, *args, **kwargs) -> None:
                self.killed = False

            def poll(self):
                return -9 if self.killed else None

            def kill(self):
                self.killed = True

        def simulated_bounded_cleanup(pid: int, grace: float) -> dict[str, object]:
            cleanup_started = time.monotonic()
            time.sleep(0.035)
            return {
                "cleanup_grace_seconds": grace,
                "elapsed_seconds": time.monotonic() - cleanup_started,
                "terminate_requested_pids": [pid],
                "kill_requested_pids": [],
                "owned_process_identities": [{"pid": pid, "create_time": 0.0}],
                "remaining_process_pids": [],
                "termination_confirmed": True,
                "bounded_wait_deadline_monotonic": cleanup_started + grace,
            }

        with tempfile.TemporaryDirectory(prefix="mms_v8_static_popen_") as temp:
            stage_dir = pathlib.Path(temp) / "producer"
            external_started = time.monotonic()
            with mock.patch.object(RUNNER.subprocess, "Popen", SimulatedPopen), \
                 mock.patch.object(RUNNER, "live_tree_bytes", return_value=(0, [])), \
                 mock.patch.object(RUNNER, "terminate_tree", side_effect=simulated_bounded_cleanup):
                record = RUNNER.run_stage(
                    ["simulated-only"], ROOT, stage_dir, 0.02, 2**31, {},
                    {
                        "live_limit_seconds": 0.02,
                        "stage_cap_seconds": 0.02,
                        "cleanup_grace_seconds": 0.2,
                        "remaining_before_seconds": 0.25,
                    },
                )
            external_elapsed = time.monotonic() - external_started

        self.assertEqual(record["stop_reason"], "wall_timeout")
        self.assertEqual(record["exit_code"], -9)
        self.assertGreater(record["cleanup"]["elapsed_seconds"], 0)
        self.assertTrue(record["cleanup"]["direct_child_exit_observed_after_kill"])
        self.assertTrue(record["cleanup"]["termination_confirmed"])
        self.assertGreater(record["child_wall_seconds"], record["cleanup"]["elapsed_seconds"])
        self.assertLessEqual(record["child_wall_seconds"], external_elapsed + 0.01)
        self.assertEqual(record["stdout"]["bytes"], 0)
        self.assertEqual(record["stderr"]["bytes"], 0)

    def test_preflight_overhead_overrun_returns_without_output_or_child(self) -> None:
        self.assertEqual(RUNNER.controller_overhead_seconds(10, 130, 0), 120.0)
        self.assertEqual(RUNNER.enforce_controller_overhead_budget(10, 0, 120, now=129.999), 119.999)
        with self.assertRaises(RUNNER.ControllerOverheadBudgetExhausted):
            RUNNER.enforce_controller_overhead_budget(10, 0, 120, now=130)
        malformed = dict(PROTOCOL)
        malformed["controller_overhead_seconds_limit"] = 121
        with self.assertRaisesRegex(ValueError, "frozen 120-second cap"):
            RUNNER.validate_controller_overhead_contract(malformed)

        output_path = ROOT / EXPECTED_OUTPUT_REL
        self.assertFalse(output_path.exists())
        clock_values = iter((100.0, 221.0, 221.0))
        fake_clock = types.SimpleNamespace(monotonic=lambda: next(clock_values))
        argv = [
            str(CONTROLLER_PATH), "--protocol", str(PROTOCOL_PATH),
            "--protocol-sha256", EXPECTED_PROTOCOL_SHA,
            "--output", str(output_path), "--root-serial-slot-granted",
        ]
        captured = io.StringIO()
        with mock.patch.object(RUNNER, "verify_pre_output_contract", return_value={
                "protocol": PROTOCOL,
                "controller_overhead_contract": {"limit_seconds": 120.0}}), \
             mock.patch.object(RUNNER, "time", fake_clock), \
             mock.patch.object(RUNNER.subprocess, "Popen") as popen, \
             mock.patch.object(sys, "argv", argv), \
             contextlib.redirect_stdout(captured):
            exit_code = RUNNER.main()

        receipt = json.loads(captured.getvalue())
        self.assertEqual(exit_code, 124)
        self.assertEqual(receipt["classification"], "resource_interruption")
        self.assertEqual(receipt["phase"], "pre_output_preflight")
        self.assertEqual(receipt["controller_overhead_seconds"], 121.0)
        self.assertEqual(receipt["controller_overhead_overrun_seconds"], 1.0)
        self.assertIs(receipt["output_leaf_created"], False)
        self.assertIs(receipt["child_process_started"], False)
        popen.assert_not_called()
        self.assertFalse(output_path.exists())

    def test_v7_no_go_ancestry_is_exact_and_mutants_are_rejected(self) -> None:
        v7 = PROTOCOL["parent_v7_protocol"]
        review = PROTOCOL["parent_v7_independent_review"]
        self.assertEqual(review["classification"], "NO-GO for runtime grant")
        self.assertIn("960 was not enforced as a shared producer/consumer deadline",
                      review["failure_reason"])
        self.assertEqual(sha256_file(ROOT / v7["path"]), v7["sha256"])
        for path_key, hash_key in (("report_path", "report_sha256"),
                                   ("manifest_path", "manifest_sha256"),
                                   ("commands_path", "commands_sha256")):
            path = ROOT / review[path_key]
            self.assertEqual(sha256_file(path), review[hash_key])
        report = (ROOT / review["report_path"]).read_text(encoding="utf-8")
        self.assertIn("NO-GO for a V7 runtime grant", report)
        self.assertIn("There is no shared 960-second deadline", report)
        checked = RUNNER.verify_v7_no_go_ancestry(ROOT, v7, review)
        self.assertFalse(checked["report_path"].is_relative_to(ROOT / EXPECTED_OUTPUT_REL))

        altered = dict(review)
        altered["classification"] = "GO"
        with self.assertRaises((ValueError, AssertionError)):
            RUNNER.verify_v7_no_go_ancestry(ROOT, v7, altered)

    def test_pin_and_input_count_mutants_fail_closed(self) -> None:
        v10 = json.loads((ROOT / PROTOCOL["v10_protocol"]["path"]).read_text(encoding="utf-8"))
        self.assertEqual(len(v10["inputs"]), 89)
        stale_hash = dict(v10["inputs"][0])
        stale_hash["sha256"] = "0" * 64
        with self.assertRaisesRegex(AssertionError, "pinned bytes or SHA drift"):
            verify_pin(stale_hash, "mutant-stale-hash")
        stale_size = dict(v10["inputs"][0])
        stale_size["bytes"] = int(stale_size["bytes"]) + 1
        with self.assertRaisesRegex(AssertionError, "pinned bytes or SHA drift"):
            verify_pin(stale_size, "mutant-stale-size")
        self.assertEqual(len(v10["inputs"][:-1]), 88)
        self.assertNotEqual(len(v10["inputs"][:-1]), PROTOCOL["v10_protocol"]["pinned_input_count"])
        extra = list(v10["inputs"]) + [dict(v10["inputs"][0])]
        self.assertEqual(len(extra), 90)
        self.assertNotEqual(len(extra), PROTOCOL["v10_protocol"]["pinned_input_count"])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=pathlib.Path, required=True,
                        help="new tester-owned JSON receipt path")
    args = parser.parse_args()
    evidence_path = args.evidence.resolve()
    if evidence_path.exists():
        raise SystemExit(f"refusing to overwrite tester receipt: {evidence_path}")
    if not evidence_path.parent.is_dir():
        raise SystemExit(f"evidence-only archive leaf must already exist: {evidence_path.parent}")

    stream = io.StringIO()
    result = unittest.TextTestRunner(stream=stream, verbosity=2).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(IndependentMmsV8ContractTests)
    )
    receipt = {
        "schema": "independent-mms-replay-v8-static-contract-test-r1",
        "classification": "independent_static_bounded_test_only",
        "julia_started": False,
        "formal_or_physical_credit": False,
        "exit_code": 0 if result.wasSuccessful() else 1,
        "tests_run": result.testsRun,
        "passed": len(result.successes) if hasattr(result, "successes") else result.testsRun - len(result.failures) - len(result.errors),
        "failures": [str(test) for test, _ in result.failures],
        "errors": [str(test) for test, _ in result.errors],
        "unittest_output": stream.getvalue(),
        "protocol": {"path": PROTOCOL_REL.as_posix(), "bytes": PROTOCOL_PATH.stat().st_size,
                     "sha256": sha256_file(PROTOCOL_PATH)},
        "controller": {"path": CONTROLLER_PATH.relative_to(ROOT).as_posix(),
                       "bytes": CONTROLLER_PATH.stat().st_size,
                       "sha256": sha256_file(CONTROLLER_PATH)},
        "frozen_test_suite": {"path": SUITE_PATH.relative_to(ROOT).as_posix(),
                              "bytes": SUITE_PATH.stat().st_size,
                              "sha256": sha256_file(SUITE_PATH)},
        "closure_summary": IndependentMmsV8ContractTests.closure_summary,
        "source_path": pathlib.Path(__file__).resolve().relative_to(ROOT).as_posix(),
        "source_sha256": sha256_file(pathlib.Path(__file__).resolve()),
        "source_bytes": pathlib.Path(__file__).resolve().stat().st_size,
    }
    evidence_path.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"exit_code": receipt["exit_code"], "tests_run": receipt["tests_run"],
                      "passed": receipt["passed"], "failures": receipt["failures"],
                      "errors": receipt["errors"], "evidence": str(evidence_path)},
                     ensure_ascii=False, separators=(",", ":")))
    if not result.wasSuccessful():
        print(stream.getvalue(), file=sys.stderr)
    return int(receipt["exit_code"])


if __name__ == "__main__":
    raise SystemExit(main())
