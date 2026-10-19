"""Python-only polarity and provenance tests for the r16 freeze manifest."""

from __future__ import annotations

import copy
import importlib.util
from pathlib import Path
import unittest


HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location(
    "native_g1g2_r16_freeze_manifest", HERE / "r16_freeze_manifest_v1.py"
)
assert SPEC is not None and SPEC.loader is not None
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


def _inputs():
    protocol = {
        "schema": "native-g1g2-gridap-recorded-protocol-r16-v1",
        "run_mode": "static_only",
        "execution_plan": {"runtime_executed": False, "julia_started": False},
        "prelaunch_guard": {"required_before_julia": True},
        "limits_per_julia_stage": copy.deepcopy(BUILDER.EXPECTED_LIMITS),
        "memory_observability": copy.deepcopy(BUILDER.EXPECTED_MEMORY_OBSERVABILITY),
        "compiler_strategy": {
            "claim_scope": "compiler_resource_diagnostic",
            "mode": "--compile=min",
            "numerical_fixtures_or_thresholds_changed": False,
            "sampled_rss_stop_threshold_bytes_unchanged": 2_147_483_648,
            "diagnostic_is_numerical_success": False,
            "numerical_status_predeclared": "not_established",
            "physical_status_predeclared": "unknown",
        },
        "resource_monitor_policy": copy.deepcopy(BUILDER.EXPECTED_RESOURCE_POLICY),
        "resource_outcome_reporter": {
            "numerical_credit_on_incomplete_sample": False,
            "external_outer_supervisor_audit_required": True,
        },
        "process_tree_termination_contract": copy.deepcopy(
            BUILDER.EXPECTED_TERMINATION_CONTRACT
        ),
        "ownership": ["test/example.py"],
    }
    dependencies = {
        f"test/example_{index}.py": {"bytes": 10, "sha256": "a" * 64}
        for index in range(114)
    }
    dependencies["test/example.py"] = {"bytes": 10, "sha256": "a" * 64}
    static = {"dependencies": dependencies}
    return protocol, static, b"protocol", b"static"


class FreezeManifestClaimTests(unittest.TestCase):
    def test_generator_uses_exact_protocol_polarity(self) -> None:
        protocol, static, protocol_bytes, static_bytes = _inputs()
        manifest = BUILDER.build_freeze_manifest(
            protocol, static,
            protocol_bytes=protocol_bytes,
            static_preflight_bytes=static_bytes,
        )
        claims = manifest["claim_boundary"]
        self.assertIs(claims["numerical_credit_on_monitor_incomplete"], False)
        self.assertIs(claims["root_outer_supervisor_residual_audit_required"], True)
        self.assertIs(claims["numerical_credit_before_outer_supervisor_audit"], False)
        self.assertNotIn("no_numerical_credit_on_incomplete", claims)

    def test_generated_manifest_round_trips_through_same_validator(self) -> None:
        protocol, static, protocol_bytes, static_bytes = _inputs()
        manifest = BUILDER.build_freeze_manifest(
            protocol, static,
            protocol_bytes=protocol_bytes,
            static_preflight_bytes=static_bytes,
        )
        BUILDER.verify_freeze_manifest(
            manifest, protocol, static,
            protocol_bytes=protocol_bytes,
            static_preflight_bytes=static_bytes,
        )

    def test_inverted_or_changed_credit_metadata_fails_closed(self) -> None:
        protocol, static, protocol_bytes, static_bytes = _inputs()
        manifest = BUILDER.build_freeze_manifest(
            protocol, static,
            protocol_bytes=protocol_bytes,
            static_preflight_bytes=static_bytes,
        )
        changed = copy.deepcopy(manifest)
        changed["claim_boundary"]["numerical_credit_on_monitor_incomplete"] = True
        with self.assertRaisesRegex(ValueError, "protocol-derived metadata"):
            BUILDER.verify_freeze_manifest(
                changed, protocol, static,
                protocol_bytes=protocol_bytes,
                static_preflight_bytes=static_bytes,
            )

    def test_protocol_and_reporter_disagreement_fails_closed(self) -> None:
        protocol, static, protocol_bytes, static_bytes = _inputs()
        protocol["resource_outcome_reporter"]["numerical_credit_on_incomplete_sample"] = True
        with self.assertRaisesRegex(ValueError, "fields disagree"):
            BUILDER.build_freeze_manifest(
                protocol, static,
                protocol_bytes=protocol_bytes,
                static_preflight_bytes=static_bytes,
            )

    def test_non_boolean_credit_value_is_not_coerced(self) -> None:
        for malformed in (0, 1, "false", None):
            with self.subTest(malformed=malformed):
                protocol, static, protocol_bytes, static_bytes = _inputs()
                protocol["resource_monitor_policy"]["numerical_credit_on_monitor_incomplete"] = malformed
                with self.assertRaisesRegex(ValueError, "JSON boolean"):
                    BUILDER.build_freeze_manifest(
                        protocol, static,
                        protocol_bytes=protocol_bytes,
                        static_preflight_bytes=static_bytes,
                    )

    def test_outer_audit_contract_is_part_of_freeze_metadata(self) -> None:
        protocol, static, protocol_bytes, static_bytes = _inputs()
        manifest = BUILDER.build_freeze_manifest(
            protocol, static,
            protocol_bytes=protocol_bytes,
            static_preflight_bytes=static_bytes,
        )
        self.assertIs(manifest["process_tree_termination_contract"][
            "root_outer_supervisor_residual_audit_required"], True)
        protocol["process_tree_termination_contract"][
            "root_outer_supervisor_residual_audit_required"] = False
        with self.assertRaisesRegex(ValueError, "inconsistent"):
            BUILDER.build_freeze_manifest(
                protocol, static,
                protocol_bytes=protocol_bytes,
                static_preflight_bytes=static_bytes,
            )

    def test_changed_resource_budget_or_heap_hint_fails_closed(self) -> None:
        for key, value in (
            ("wall_seconds", 600.0),
            ("sampled_process_tree_rss_stop_threshold_bytes", 3_221_225_472),
        ):
            protocol, static, protocol_bytes, static_bytes = _inputs()
            protocol["limits_per_julia_stage"][key] = value
            with self.subTest(key=key):
                with self.assertRaisesRegex(ValueError, "stage limits differ"):
                    BUILDER.build_freeze_manifest(
                        protocol, static,
                        protocol_bytes=protocol_bytes,
                        static_preflight_bytes=static_bytes,
                    )

        protocol, static, protocol_bytes, static_bytes = _inputs()
        protocol["memory_observability"]["julia_heap_size_hint"] = "2G"
        with self.assertRaisesRegex(ValueError, "sampled RSS/heap-hint semantics"):
            BUILDER.build_freeze_manifest(
                protocol, static,
                protocol_bytes=protocol_bytes,
                static_preflight_bytes=static_bytes,
            )

    def test_actual_execution_cannot_be_frozen_as_static(self) -> None:
        protocol, static, protocol_bytes, static_bytes = _inputs()
        protocol["execution_plan"]["julia_started"] = True
        with self.assertRaisesRegex(ValueError, "cannot claim Julia started"):
            BUILDER.build_freeze_manifest(
                protocol, static,
                protocol_bytes=protocol_bytes,
                static_preflight_bytes=static_bytes,
            )


if __name__ == "__main__":
    unittest.main()
