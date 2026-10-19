"""Python-only tests for the Native G1/G2 r14 argv-role contract."""

from __future__ import annotations

import importlib.util
import copy
import json
from pathlib import Path
import sys
import unittest


PREFLIGHT_PATH = Path(__file__).resolve().with_name("r14_prelaunch_preflight.py")
SPEC = importlib.util.spec_from_file_location("native_g1g2_r14_preflight_tests", PREFLIGHT_PATH)
assert SPEC is not None and SPEC.loader is not None
PREFLIGHT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PREFLIGHT)
REPO_ROOT = Path(__file__).resolve().parents[3]
R13_PROTOCOL_PATH = REPO_ROOT / PREFLIGHT.R13_STATIC_PROTOCOL_REL
R13_PROTOCOL = json.loads(R13_PROTOCOL_PATH.read_text(encoding="utf-8"))
R10_PROTOCOL_PATH = REPO_ROOT / PREFLIGHT.R10_PROTOCOL_REL
R10_PROTOCOL = json.loads(R10_PROTOCOL_PATH.read_text(encoding="utf-8"))
R14_OUTPUT = (REPO_ROOT /
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_prelaunch_r14_v1/r14_actual_v1").resolve()


def r14_compile_min_stages() -> list[dict[str, object]]:
    stages = copy.deepcopy(R13_PROTOCOL["execution_plan"]["stage_commands"])
    old_output = (REPO_ROOT /
        "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
        "native_g1g2_prelaunch_r13_v1/r13_actual_v1").resolve()
    old_test = (REPO_ROOT /
        "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests_r12_markers.jl").resolve()
    new_test = (REPO_ROOT / PREFLIGHT.R14_JULIA_TEST).resolve()
    for stage in stages:
        argv = stage["argv"]
        stage["argv"] = [
            token.replace(str(old_output), str(R14_OUTPUT))
                 .replace(str(old_test), str(new_test))
            for token in argv
        ]
        argv = stage["argv"]
        argv.insert(argv.index("--threads=1") + 1, "--compile=min")
    return stages


def static_argv() -> list[str]:
    return [
        str(Path(sys.executable).resolve()), "-B", "run_recorded_r14.py",
        "--output", "r14_static_v1", "--planned-output", "r14_actual_v1",
        "--julia", "julia.exe", "--static-only",
    ]


def runtime_argv() -> list[str]:
    return [
        str(Path(sys.executable).resolve()), "-B", "run_recorded_r14.py",
        "--output", "r14_actual_v1", "--julia", "julia.exe",
    ]


class ParentArgvRoleTests(unittest.TestCase):
    def test_static_invocation_role_accepts_exact_parent(self) -> None:
        selected, expected = PREFLIGHT.verify_argv_identity(
            "static_only", static_argv(), runtime_argv(), static_argv(),
            Path("r14_static_v1/protocol.json"),
        )
        self.assertEqual(selected, "runner_invocation_argv")
        self.assertEqual(expected, static_argv())

    def test_actual_runtime_role_accepts_exact_parent(self) -> None:
        selected, expected = PREFLIGHT.verify_argv_identity(
            "actual", runtime_argv(), runtime_argv(), runtime_argv(),
            Path("r14_actual_v1/protocol.json"),
        )
        self.assertEqual(selected, "expected_runtime_supervisor_argv")
        self.assertEqual(expected, runtime_argv())

    def test_static_argv_is_not_accepted_for_actual_mode(self) -> None:
        with self.assertRaises(PREFLIGHT.ParentArgvIdentityMismatch) as caught:
            PREFLIGHT.verify_argv_identity(
                "actual", static_argv(), runtime_argv(), runtime_argv(),
                Path("r14_actual_v1/protocol.json"),
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
                Path("r14_actual_v1/protocol.json"),
            )
        diagnostic = caught.exception.diagnostic
        self.assertEqual(diagnostic["status"], "fail_closed")
        self.assertEqual(diagnostic["selected_expected_field"],
            "expected_runtime_supervisor_argv")
        self.assertEqual(diagnostic["observed_parent_argv"], runtime_with_extra)
        self.assertEqual(diagnostic["expected_argv"], runtime_argv())
        self.assertFalse(diagnostic["observed_matches_expected"])


class CompileMinArgvDeltaTests(unittest.TestCase):
    def test_exact_compile_min_delta_is_accepted(self) -> None:
        PREFLIGHT.verify_compile_min_delta(
            r14_compile_min_stages(),
            R13_PROTOCOL["execution_plan"]["stage_commands"],
            REPO_ROOT,
            R14_OUTPUT,
        )

    def test_missing_compile_mode_fails_closed(self) -> None:
        candidate = r14_compile_min_stages()
        candidate[1]["argv"].remove("--compile=min")
        with self.assertRaisesRegex(ValueError, "more than one compile-mode token"):
            PREFLIGHT.verify_compile_min_delta(
                candidate, R13_PROTOCOL["execution_plan"]["stage_commands"],
                REPO_ROOT, R14_OUTPUT,
            )


class ClaimAndThresholdGuardsTests(unittest.TestCase):
    def test_compiler_strategy_is_resource_diagnostic_only(self) -> None:
        PREFLIGHT.verify_compiler_strategy(
            copy.deepcopy(PREFLIGHT.EXPECTED_COMPILER_STRATEGY)
        )

    def test_numeric_or_physical_credit_is_rejected(self) -> None:
        for field, value in (
            ("claim_scope", "numerical_pass"),
            ("diagnostic_is_numerical_success", True),
            ("numerical_status_predeclared", "pass"),
            ("physical_status_predeclared", "pass"),
            ("numerical_fixtures_or_thresholds_changed", True),
            ("hard_rss_limit_bytes_unchanged", 3_221_225_472),
        ):
            with self.subTest(field=field):
                candidate = copy.deepcopy(PREFLIGHT.EXPECTED_COMPILER_STRATEGY)
                candidate[field] = value
                with self.assertRaisesRegex(ValueError, "overstates claim"):
                    PREFLIGHT.verify_compiler_strategy(candidate)

    def test_r10_numerical_protocol_is_accepted_unchanged(self) -> None:
        PREFLIGHT.verify_numerical_protocol_unchanged(R10_PROTOCOL, R10_PROTOCOL)

    def test_threshold_tampering_fails_closed(self) -> None:
        candidate = copy.deepcopy(R10_PROTOCOL)
        candidate["numerical_protocol"]["residual_abs_tol"] *= 10
        with self.assertRaisesRegex(ValueError, "thresholds differ"):
            PREFLIGHT.verify_numerical_protocol_unchanged(candidate, R10_PROTOCOL)

    def test_extra_compiler_flag_fails_closed(self) -> None:
        candidate = r14_compile_min_stages()
        candidate[1]["argv"].insert(candidate[1]["argv"].index("--compile=min"),
            "--optimize=0")
        with self.assertRaisesRegex(ValueError, "more than one compile-mode token"):
            PREFLIGHT.verify_compile_min_delta(
                candidate, R13_PROTOCOL["execution_plan"]["stage_commands"],
                REPO_ROOT, R14_OUTPUT,
            )

    def test_mesh_or_artifact_argv_mutation_fails_closed(self) -> None:
        candidate = r14_compile_min_stages()
        candidate[1]["argv"][-2] = "replay"
        with self.assertRaisesRegex(ValueError, "more than one compile-mode token"):
            PREFLIGHT.verify_compile_min_delta(
                candidate, R13_PROTOCOL["execution_plan"]["stage_commands"],
                REPO_ROOT, R14_OUTPUT,
            )


if __name__ == "__main__":
    unittest.main()
