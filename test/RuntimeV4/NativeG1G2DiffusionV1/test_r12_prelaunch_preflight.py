"""Focused Python-only tests for the Native G1/G2 r12 prelaunch guard."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]
PREFLIGHT_PATH = Path(__file__).resolve().with_name("r12_prelaunch_preflight.py")
RUNNER_PATH = Path(__file__).resolve().with_name("run_recorded_r12.py")
SPEC = importlib.util.spec_from_file_location("native_g1g2_r12_preflight_tests", PREFLIGHT_PATH)
assert SPEC is not None and SPEC.loader is not None
PREFLIGHT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PREFLIGHT)


class PrelaunchSupervisorArgumentTests(unittest.TestCase):
    def test_static_parent_argv_binds_both_leaves(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            evidence_root = Path(temporary).resolve()
            preparation = evidence_root / "r12_static_v1"
            planned = evidence_root / "r12_actual_v1"
            julia = str((evidence_root / "julia.exe").resolve())
            argv = [
                str(Path(sys.executable).resolve()), "-B", str(RUNNER_PATH.resolve()),
                "--output", preparation.name,
                "--julia", julia,
                "--planned-output", planned.name,
                "--static-only",
            ]
            self.assertEqual(PREFLIGHT.verify_parent_invocation(
                argv, "static_only", preparation, planned, julia,
                RUNNER_PATH, evidence_root, argv,
            ), argv)

    def test_actual_parent_argv_rejects_preparation_only_flag(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            evidence_root = Path(temporary).resolve()
            actual = evidence_root / "r12_actual_v1"
            julia = str((evidence_root / "julia.exe").resolve())
            argv = [
                str(Path(sys.executable).resolve()), "-B", str(RUNNER_PATH.resolve()),
                "--output", actual.name,
                "--julia", julia,
            ]
            self.assertEqual(PREFLIGHT.verify_parent_invocation(
                argv, "actual", actual, actual, julia,
                RUNNER_PATH, evidence_root, argv,
            ), argv)
            with self.assertRaisesRegex(ValueError, "must not include --planned-output"):
                PREFLIGHT.verify_parent_invocation(
                    argv + ["--planned-output", actual.name],
                    "actual", actual, actual, julia,
                    RUNNER_PATH, evidence_root,
                    argv + ["--planned-output", actual.name],
                )

    def test_parent_argv_mismatch_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            evidence_root = Path(temporary).resolve()
            preparation = evidence_root / "r12_static_v1"
            planned = evidence_root / "r12_actual_v1"
            julia = str((evidence_root / "julia.exe").resolve())
            argv = [
                str(Path(sys.executable).resolve()), "-B", str(RUNNER_PATH.resolve()),
                "--output", preparation.name,
                "--julia", julia,
                "--planned-output", planned.name,
                "--static-only",
            ]
            with self.assertRaisesRegex(ValueError, "differs from frozen actual_invocation_argv"):
                PREFLIGHT.verify_parent_invocation(
                    argv, "static_only", preparation, planned, julia,
                    RUNNER_PATH, evidence_root, argv[:-1] + ["--tampered"],
                )


if __name__ == "__main__":
    unittest.main()
