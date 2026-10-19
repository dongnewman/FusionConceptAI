"""Python-only tests for the Native G1/G2 r13 argv-role contract."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import unittest


PREFLIGHT_PATH = Path(__file__).resolve().with_name("r13_prelaunch_preflight.py")
SPEC = importlib.util.spec_from_file_location("native_g1g2_r13_preflight_tests", PREFLIGHT_PATH)
assert SPEC is not None and SPEC.loader is not None
PREFLIGHT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PREFLIGHT)


def static_argv() -> list[str]:
    return [
        str(Path(sys.executable).resolve()), "-B", "run_recorded_r13.py",
        "--output", "r13_static_v1", "--planned-output", "r13_actual_v1",
        "--julia", "julia.exe", "--static-only",
    ]


def runtime_argv() -> list[str]:
    return [
        str(Path(sys.executable).resolve()), "-B", "run_recorded_r13.py",
        "--output", "r13_actual_v1", "--julia", "julia.exe",
    ]


class ParentArgvRoleTests(unittest.TestCase):
    def test_static_invocation_role_accepts_exact_parent(self) -> None:
        selected, expected = PREFLIGHT.verify_argv_identity(
            "static_only", static_argv(), runtime_argv(), static_argv(),
            Path("r13_static_v1/protocol.json"),
        )
        self.assertEqual(selected, "runner_invocation_argv")
        self.assertEqual(expected, static_argv())

    def test_actual_runtime_role_accepts_exact_parent(self) -> None:
        selected, expected = PREFLIGHT.verify_argv_identity(
            "actual", runtime_argv(), runtime_argv(), runtime_argv(),
            Path("r13_actual_v1/protocol.json"),
        )
        self.assertEqual(selected, "expected_runtime_supervisor_argv")
        self.assertEqual(expected, runtime_argv())

    def test_static_argv_is_not_accepted_for_actual_mode(self) -> None:
        with self.assertRaises(PREFLIGHT.ParentArgvIdentityMismatch) as caught:
            PREFLIGHT.verify_argv_identity(
                "actual", static_argv(), runtime_argv(), runtime_argv(),
                Path("r13_actual_v1/protocol.json"),
            )
        diagnostic = caught.exception.diagnostic
        self.assertEqual(diagnostic["status"], "fail_closed")
        self.assertEqual(diagnostic["selected_expected_field"],
            "expected_runtime_supervisor_argv")
        self.assertTrue(diagnostic["observed_matches_expected"])
        self.assertFalse(diagnostic["runner_invocation_matches_runtime_expected"])

    def test_extra_actual_argv_fails_closed_with_diagnostic(self) -> None:
        runtime_with_extra = runtime_argv() + ["--unexpected"]
        with self.assertRaises(PREFLIGHT.ParentArgvIdentityMismatch) as caught:
            PREFLIGHT.verify_argv_identity(
                "actual", runtime_with_extra, runtime_argv(), runtime_with_extra,
                Path("r13_actual_v1/protocol.json"),
            )
        diagnostic = caught.exception.diagnostic
        self.assertEqual(diagnostic["status"], "fail_closed")
        self.assertEqual(diagnostic["selected_expected_field"],
            "expected_runtime_supervisor_argv")
        self.assertEqual(diagnostic["observed_parent_argv"], runtime_with_extra)
        self.assertEqual(diagnostic["expected_argv"], runtime_argv())
        self.assertFalse(diagnostic["observed_matches_expected"])


if __name__ == "__main__":
    unittest.main()
