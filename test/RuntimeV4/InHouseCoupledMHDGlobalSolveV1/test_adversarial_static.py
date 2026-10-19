"""Independent source-level adversarial checks for the isolated MHD scaffold.

This suite deliberately does not import Julia or claim to execute numerical
behavior. Missing required safeguards fail the suite and produce a NO-GO review
signal; source-pattern passes are preparation evidence only.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src" / "RuntimeV4" / "InHouseCoupledMHDGlobalSolveV1.jl"
def section(start: str, stop: str | None = None) -> str:
    text = SOURCE.read_text(encoding="utf-8")
    begin = text.index(start)
    end = len(text) if stop is None else text.index(stop, begin + len(start))
    return text[begin:end]


class TestFrozenInputAndIdentity(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.text = SOURCE.read_text(encoding="utf-8")

    def test_closure_is_candidate_kind_source_and_payload_bound(self) -> None:
        body = section("function _validate_closure", "\nstruct CoupledMHDGlobalPolicyV1")
        for required in (
            "e.kind === kind",
            "e.candidate_hash == candidate_hash",
            "_sha_file(e.source_path) == e.source_sha256",
            "string(canonical_hash(e.payload)) == e.payload_sha256",
            "canonical_hash(body)) == e.evidence_hash",
        ):
            with self.subTest(required=required):
                self.assertIn(required, body)

    def test_policy_hash_covers_every_frozen_gate_and_revalidates(self) -> None:
        build = section("function make_global_policy_v1", "\nfunction _validate_policy")
        validate = section("function _validate_policy", "\n\"Two-region provider binding")
        fields = (
            "acceptance_ref", "contract_source_path",
            "max_updates", "wall_seconds", "residual_tolerance",
            "constraint_tolerance", "stationarity_tolerance",
            "bound_dual_tolerance", "complementarity_tolerance", "step_tolerance",
            "minimum_step", "armijo_fraction", "max_backtracks",
            "max_active_set_iterations", "stagnation_window",
        )
        for field in fields:
            with self.subTest(field=field):
                self.assertIn(field, build)
                self.assertIn(field, validate)
        self.assertIn("rebuilt.policy_hash == p.policy_hash", validate)
        self.assertIn("contract_semantic_hash=_semantic_sha", build)
        self.assertNotIn("_sha_file(p.contract_source_path)", validate)

    def test_model_hash_binds_candidate_provider_and_closure_hashes(self) -> None:
        body = section("function _model_body", "\nfunction _validate_model")
        for required in (
            "candidate_hash=m.candidate_hash",
            "closure_hashes=Tuple(",
            "provider_semantic_hash=m.provider_semantic_hash",
            "provider_context_hash=m.provider_context_hash",
        ):
            with self.subTest(required=required):
                self.assertIn(required, body)


class TestCoverageAndNumericalGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.text = SOURCE.read_text(encoding="utf-8")

    def test_model_requires_exact_closure_and_id_inventories(self) -> None:
        build = section("function make_global_model_v1", "\nfunction _missing_closures")
        for required in (
            "Tuple(keys(closure_evidence)) == _REQUIRED_CLOSURES",
            "length(unique(pressure_indices)) == length(pressure_indices)",
            "length(unique(ids)) == length(ids)",
            "length(unique(interface_constraint_ids)) == length(interface_constraint_ids)",
            "length(unique(ids)) == length(ids), outer_constraint_ids",
        ):
            with self.subTest(required=required):
                self.assertIn(required, build)

    def test_provider_results_are_candidate_provider_and_exact_id_bound(self) -> None:
        body = section("Base.@noinline Base.@nospecializeinfer function _check_provider_record", "\n\"Assemble global equilibrium")
        self.assertIn("block.candidate_hash == m.candidate_hash", body)
        self.assertIn("block.provider_semantic_hash == m.provider_semantic_hash", body)
        self.assertIn("block.provider_context_hash == m.provider_context_hash", body)
        self.assertIn("Base.@noinline Base.@nospecializeinfer function _check_provider_record", body)
        self.assertIn("Base.@nospecialize block m expected_ids id_field", body)
        self.assertIn("Tuple(String.(getproperty(block, id_field))) == expected_ids", body)

    def test_regional_and_outer_provider_records_bind_the_region_identity(self) -> None:
        body = section("function _check_provider_record", "\n\"Assemble global equilibrium")
        self.assertTrue(re.search(r"hasproperty\(block,\s*:region_id\)", body),
            "provider identity must include an explicit region ID")
        self.assertTrue(re.search(r"block\.region_id\s*==\s*expected_region", body),
            "region callback output must be checked against the requested region")

    def test_residuals_are_rank_one_vectors_and_jacobians_match_dimensions(self) -> None:
        body = section("function _checked_block", "\nBase.@noinline Base.@nospecializeinfer function _check_provider_record")
        self.assertTrue(re.search(r"block\.residual\s+isa\s+AbstractVector", body),
            "matrix-shaped residuals must be rejected before assembly")
        self.assertIn("size(J) == (length(r), columns)", body)
        self.assertIn("all(isfinite, r) && all(isfinite, nonzeros(J))", body)

    def test_kkt_system_records_rank_defect_and_kkt_residual(self) -> None:
        body = section("function _active_kkt_step", "\n_merit(f, c)")
        for required in (
            "Ca = [C; E]",
            "K = [spzeros(n, n) transpose(J) transpose(Ca);",
            "rank_estimate < size(K, 2)",
            "kkt_defect = _maxabs(K * z - rhs)",
            "rel_defect <= policy.stationarity_tolerance",
        ):
            with self.subTest(required=required):
                self.assertIn(required, body)

    def test_pressure_active_set_activates_violations_and_releases_wrong_sign_duals(self) -> None:
        body = section("function _active_kkt_step", "\n_merit(f, c)")
        self.assertIn("x[i] + p[i] < 0.0", body)
        self.assertIn("push!(active, idx)", body)
        self.assertIn("bad_dual = findall(v -> v > policy.bound_dual_tolerance", body)
        self.assertIn("deleteat!(active, release_pos)", body)
        self.assertIn("complementarity = maximum(", body)

    def test_active_bound_multipliers_start_after_equality_constraint_rows(self) -> None:
        body = section("function _active_kkt_step", "\n_merit(f, c)")
        self.assertIn("mu[(size(C, 1) + 1):end]", body)
        self.assertNotIn("mu[(length(C) + 1):end]", body)

    def test_provider_jacobian_has_an_independent_consistency_check(self) -> None:
        build = section("callback_set = (regional_evaluator", "body = (revision=_REVISION")
        self.assertIn("implementation_methods", build)
        self.assertIn("oracle_methods", build)
        self.assertIn("isempty(intersect(implementation_methods, oracle_methods))", build)

        oracle = section("function _check_jacobian_oracle", "function _provider_context")
        for required in (
            "record.jacobian_oracle_hash == expected_oracle_hash",
            "size(oracle_jacobian) == size(assembled_jacobian)",
            "defect <= tolerance",
        ):
            with self.subTest(required=required):
                self.assertIn(required, oracle)

        assembly = section("function assemble_coupled_mhd_global_v1", "function _active_kkt_step")
        for operation in (":regional", ":interface", ":outer", ":global_conservation"):
            with self.subTest(operation=operation):
                self.assertIn(operation, assembly)

    def test_conservation_has_an_explicit_residual_or_acceptance_gate(self) -> None:
        build = section("function make_global_model_v1", "function _missing_closures")
        self.assertIn("global_conservation_ids", build)
        self.assertIn("global conservation requires a nonempty unique ID inventory", build)
        assembly = section("function assemble_coupled_mhd_global_v1", "function _active_kkt_step")
        for required in (
            "m.conservation_evaluator(x, m.closure_evidence, context)",
            "conservation_defect=_maxabs(conservation_block.residual)",
            "c = vcat(ci, co, conservation_block.residual)",
        ):
            with self.subTest(required=required):
                self.assertIn(required, assembly)
        solve = section("function solve_coupled_mhd_global_v1", "\n\"Replay an in-memory raw trace")
        self.assertIn("conservation_defect <= policy.constraint_tolerance", solve)


class TestDispositionAndReplay(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.text = SOURCE.read_text(encoding="utf-8")

    def test_missing_closures_are_typed_absent_and_malformed_closures_fail_closed(self) -> None:
        missing = section("function _missing_closures", "\nfunction coupled_mhd_capability_signature_v1")
        self.assertIn("if e === nothing", missing)
        self.assertIn("throw(ArgumentError(\"malformed closure evidence is fail-closed", missing)
        solve = section("function solve_coupled_mhd_global_v1", "\n\"Replay an in-memory raw trace")
        self.assertIn("_base_result(:typed_absent", solve)
        self.assertIn(":program_exception", solve)
        self.assertIn(":numerical_fail", solve)
        self.assertIn(":resource_interruption", solve)

    def test_raw_trace_contains_residual_jacobian_constraints_and_kkt_steps(self) -> None:
        trace_eval = section("function _trace_eval", "\nfunction _base_result")
        for required in (
            "residual=Tuple(a.residual)",
            "jacobian=_matrix_snapshot(a.jacobian)",
            "equality_residual=Tuple(a.equality_residual)",
            "equality_jacobian=_matrix_snapshot(a.equality_jacobian)",
            "raw_blocks=",
        ):
            with self.subTest(required=required):
                self.assertIn(required, trace_eval)
        self.assertIn("kkt_active_set=step_result.steps", self.text)

    def test_stagnation_uses_a_window_and_retains_a_trace(self) -> None:
        body = section("function solve_coupled_mhd_global_v1", "\n\"Replay an in-memory raw trace")
        self.assertIn("no_progress >= policy.stagnation_window", body)
        self.assertIn("failure=(kind=:stagnation,)", body)
        self.assertIn("raw_trace=Tuple(trace)", self.text)

    def test_final_metrics_are_recomputed_after_an_accepted_state_update(self) -> None:
        body = section("function solve_coupled_mhd_global_v1", "\n\"Replay an in-memory raw trace")
        accepted = body.index("x = trial")
        stagnation = body.index("no_progress >= policy.stagnation_window")
        post_accept = body[accepted:stagnation]
        self.assertIn("last_metrics =", post_accept)

    def test_replay_binds_candidate_model_policy_and_all_result_disposition_fields(self) -> None:
        body = section("function replay_coupled_mhd_global_v1", "\ncoupled_mhd_global_manifest_v1")
        self.assertIn("recorded_result.result_hash", body)
        for required in (
            ":candidate_hash, :model_hash",
            ":policy_hash, :initial_state",
            "recorded_result.candidate_hash == m.candidate_hash",
            "recorded_result.model_hash == m.model_hash",
            "recorded_result.policy_hash == policy.policy_hash",
            "all(identity_matches)",
            "raw_trace_match = canonical_json(replayed.raw_trace) == canonical_json(recorded_result.raw_trace)",
            "disposition_match = canonical_json(replayed) == canonical_json(recorded_result)",
        ):
            with self.subTest(required=required):
                self.assertIn(required, body)


if __name__ == "__main__":
    unittest.main(verbosity=2)
