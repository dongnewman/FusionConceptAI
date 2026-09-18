"""Independent Python oracle/static QA for UP4-02B R14.

This oracle does not import Julia, execute providers, or run DESC.  It checks
the closed typed receipt surface, the exact 18-case negative matrix, and
replays the positive transient/geometry fixed point independently so that the
fixture's convergence claim is numerical evidence rather than a loosened
expectation.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src" / "RuntimeV4" / "EngineeringFeedbackExecutionV1.jl"
TEST = ROOT / "test" / "RuntimeV4" / "UP4" / "engineering_feedback_execution_v1_tests.jl"
FIXTURE = ROOT / "test" / "RuntimeV4" / "UP4" / "engineering_feedback_execution_v1_fixture.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def independent_replay(max_iterations: int, tolerance: float) -> tuple[bool, list[float]]:
    """Replay the calibrated R14 envelope without reading Julia source values."""
    voltage, resistance, alpha = 10.0, 2.0, 0.003
    reference, ambient = 300.0, 300.0
    conductance, thermal_capacity, mass, heat_capacity, dt = 100.0, 1.0, 1.0, 1.0, 1.0
    stiffness, support_stiffness, load = 1.0e7, 1.0e7, 1000.0
    modulus, expansion, length = 1.0e11, 1.0e-5, 1.0
    total_capacity = thermal_capacity + mass * heat_capacity
    temperature, geometry = ambient, 1.0
    trajectory: list[float] = []
    for _ in range(max_iterations):
        resistance_now = resistance * geometry * max(0.0, 1.0 + alpha * (temperature - reference))
        current = voltage / resistance_now
        supply = voltage * current
        joule = current * current * resistance_now
        temperature_new = (joule + total_capacity / dt * temperature + conductance * ambient) / (
            total_capacity / dt + conductance
        )
        cooling = conductance * max(0.0, temperature_new - ambient)
        elastic = load / (stiffness * geometry + support_stiffness)
        displacement = elastic + expansion * length * max(0.0, temperature_new - reference)
        geometry_new = 1.0 + displacement / length
        internal_reaction = stiffness * geometry_new * elastic
        support_reaction = support_stiffness * elastic
        force_residual = internal_reaction + support_reaction - load
        storage_power = total_capacity * (temperature_new - temperature) / dt
        thermal_residual = joule - cooling - storage_power
        state_change = max(abs(temperature_new - temperature), abs(geometry_new - geometry))
        residual = max(abs(supply - joule), abs(thermal_residual), abs(force_residual), state_change)
        trajectory.append(residual)
        temperature, geometry = temperature_new, geometry_new
        if residual <= tolerance:
            return True, trajectory
    return False, trajectory


def independent_constitutive(fixture: dict) -> dict:
    """Build positive sample fields from p, B, mu0, and n independently."""
    p = fixture["pressure_Pa"]
    b = fixture["B_xyz_T"]
    mu0 = fixture["mu0_N_A2"]
    n = fixture["outward_normal_xyz"]
    energy = sum(value * value for value in b) / (2.0 * mu0)
    tensor = [[(p + energy if i == j else 0.0) - b[i] * b[j] / mu0
               for j in range(3)] for i in range(3)]
    traction = [sum(tensor[i][j] * n[j] for j in range(3)) for i in range(3)]
    normal = sum(traction[i] * n[i] for i in range(3))
    tangent = [traction[i] - normal * n[i] for i in range(3)]
    independent_difference = max(
        abs(traction[i] - fixture["traction_xyz_Pa"][i]) for i in range(3)
    )
    return {
        "magnetic_energy_density_J_m3": energy,
        "momentum_flux_xyz_Pa": tensor,
        "traction_xyz_Pa": traction,
        "normal_traction_Pa": normal,
        "tangential_traction_xyz_Pa": tangent,
        "independent_traction_difference_Pa": independent_difference,
    }


def close_nested(actual, expected, tolerance: float = 1e-12) -> bool:
    if isinstance(expected, list):
        return isinstance(actual, list) and len(actual) == len(expected) and all(
            close_nested(a, e, tolerance) for a, e in zip(actual, expected)
        )
    return abs(float(actual) - float(expected)) <= tolerance


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    required = (
        "UP4-02B-ENGINEERING-FEEDBACK-EXECUTION-V1-R14",
        "EngineeringFeedbackReducedSIEnvelopeV1",
        "EngineeringFeedbackCandidateEngineeringExecutionRefV1",
        "EngineeringFeedbackCandidatePlasmaLoadSampleRefV1",
        "EngineeringFeedbackSHIRRefV1", "EngineeringFeedbackBridgeRefV1",
        "EngineeringFeedbackTypedResourceRefV1", "EngineeringFeedbackExecutionRequestV1",
        "EngineeringFeedbackIterationV1", "EngineeringFeedbackLedgerV1",
        "EngineeringFeedbackHardGatesV1", "EngineeringFeedbackResidualVectorV1",
        "EngineeringFeedbackDiagnosticsV1", "EngineeringFeedbackExecutionV1",
        "execute_engineering_feedback", "validate_engineering_feedback_residuals",
        "candidate_hash", "scenario_hash", "g3_hash", "shir_hash", "bridge_hash",
        "upstream_execution_hash", "load_sample_hash", "component_load=false",
        "component_load_admitted", "magnetic_energy_density_J_m3", "momentum_flux_xyz_Pa",
        "constitutive replay mismatch", "bridge_shir_resource_mismatch", "content_hash",
        "load_sample_membership_mismatch", "independent_traction_difference_Pa",
        "stored independent traction difference must be non-negative",
        "Local closed projection", "screen only",
        "supply_power_W", "joule_heat_W", "cooling_W", "temperature_K",
        "allowable_stress_Pa", "stress_Pa", "displacement_m", "geometry_factor",
        "internal_reaction_N", "support_reaction_N", "energy_residual_W",
        "thermal_residual_W", "force_residual_N", "material_residual_Pa",
        "iteration_trace", "ledgers", "temperature_max_K", "stress_max_Pa",
        "clearance_used_m", "diagnostics_hash", "thermal_capacity_J_K",
        "heat_capacity_J_kg_K", "time_step_s", "declared_heat_W", "storage_power",
        "double_counted_heat", "forged_identity", "scenario_mismatch", "iteration_limit",
        "forged_residual", "temperature_exceeded", "stress_exceeded", "clearance_exceeded",
        "energy_residual_exceeded", "thermal_residual_exceeded", "force_residual_exceeded",
        "material_residual_exceeded", "accepted=false", "claim_ceiling=UP4_02B_CLAIM_CEILING",
        "engineering_credit=:none", "physical_credit=:none", "r01_r10_credit=:none",
        "component_load_not_admitted", "no component load was inferred",
    )
    missing = [token for token in required if token not in source]
    if missing:
        raise AssertionError(f"missing required R14 token(s): {missing}")
    for method in (
        "semantic_view(x::EngineeringFeedbackCandidatePlasmaLoadSampleRefV1)",
        "semantic_view(x::EngineeringFeedbackCandidateEngineeringExecutionRefV1)",
        "semantic_view(x::EngineeringFeedbackTypedResourceRefV1)",
        "semantic_view(x::Union{EngineeringFeedbackSHIRRefV1,EngineeringFeedbackBridgeRefV1})",
        "semantic_view(x::EngineeringFeedbackReducedSIEnvelopeV1)",
        "semantic_view(x::EngineeringFeedbackExecutionRequestV1)",
        "semantic_view(x::EngineeringFeedbackIterationV1)",
        "semantic_view(x::EngineeringFeedbackLedgerEntryV1)",
        "semantic_view(x::EngineeringFeedbackLedgerV1)",
        "semantic_view(x::EngineeringFeedbackHardGatesV1)",
        "semantic_view(x::EngineeringFeedbackDiagnosticsV1)",
        "semantic_view(x::EngineeringFeedbackResidualVectorV1)",
        "semantic_view(x::EngineeringFeedbackExecutionV1)",
    ):
        if method not in source:
            raise AssertionError(f"missing closed typed semantic projection: {method}")
    if "last = last(trace)" in source or "final_iteration = Base.last(trace)" not in source:
        raise AssertionError("final iteration still shadows Base.last")
    forbidden = (
        "default_operator_registry", "invoke_provider", "run_solver", "solve_pde",
        "DESC.", "HTTP.get", "Pkg.add", "CandidateEngineeringExecutionV4(",
    )
    found = [token for token in forbidden if token in source]
    if found:
        raise AssertionError(f"forbidden shared/provider execution token(s): {found}")
    if "::Any" in source or "NamedTuple" in source or "nothing" in source or "_up4_02b_get" in source:
        raise AssertionError("R14 requires closed typed inputs without optional/fallback fields")
    truncated_sample_name = "EngineeringFeedbackCandidatePlasmaLoad" + "RefV1"
    if truncated_sample_name in source:
        raise AssertionError("stale truncated plasma load sample method name remains")
    if fixture["revision"] != "UP4-02B-ENGINEERING-FEEDBACK-EXECUTION-V1-R14":
        raise AssertionError("fixture revision drifted")
    if fixture["accepted"] is not False or fixture["claim_ceiling"] != "screen_only":
        raise AssertionError("execution credit boundary drifted")
    if fixture["component_load"] is not False or fixture["component_load_admitted"] is not False:
        raise AssertionError("upstream component-load limitation was erased")
    if any(fixture[key] != 0 for key in ("provider_calls", "solver_calls", "checker_calls")):
        raise AssertionError("execution counters must remain zero")

    constitutive_fixture = fixture["positive_constitutive"]
    rebuilt = independent_constitutive(constitutive_fixture)
    for field, expected_value in rebuilt.items():
        actual_value = constitutive_fixture[field]
        if not close_nested(actual_value, expected_value):
            raise AssertionError(f"positive constitutive field drifted: {field}")
    if "function canonical_hash(x::EngineeringFeedbackCandidatePlasmaLoadSampleRefV1)" not in source:
        raise AssertionError("canonical sample replay method has the wrong typed name")
    strict_difference_check = source.index("x.independent_traction_difference_Pa >= 0")
    tolerance_difference_check = source.index("isapprox(independent_difference, x.independent_traction_difference_Pa")
    if strict_difference_check > tolerance_difference_check:
        raise AssertionError("stored traction-difference sign check occurs after tolerance comparison")
    for token in (
        "B = (0.1, 0.0, 0.2)",
        "magnetic_energy_density_J_m3=0.025",
        "momentum_flux_xyz_Pa=tensor",
        "tangential_traction_xyz_Pa=(0.0, 0.0, -0.02)",
    ):
        if token not in test:
            raise AssertionError(f"focused test positive constitutive builder missing: {token}")
    if ":negative_stored_difference" not in test:
        raise AssertionError("focused test does not dispatch the negative stored-difference case")
    if "EngineeringFeedbackExecutionRequestV1(upstream, sample, upstream.result_hash" not in test or "execute_engineering_feedback(_up4b_request(; mutation))" not in test:
        raise AssertionError("negative stored-difference case does not enter product execute path with explicit hashes")
    if "envelope_hash = mutation === :nonfinite ? _up4b_d(\"forged-nonfinite-envelope\")" not in test or "execute_engineering_feedback(nonfinite_request)" not in test:
        raise AssertionError("nonfinite case does not construct a typed request before product execution")

    iteration_start = source.index("function _up4_02b_iteration_body")
    iteration_end = source.index("semantic_view(x::EngineeringFeedbackIterationV1)", iteration_start)
    iteration_body = source[iteration_start:iteration_end]
    for field in ("internal_reaction_N=x.internal_reaction_N", "support_reaction_N=x.support_reaction_N"):
        if field not in iteration_body:
            raise AssertionError(f"iteration hash body omits {field}")
    if "canonical_hash(_up4_02b_iteration_body(x))" not in source:
        raise AssertionError("iteration trace canonical hash guard is missing")
    construction_start = source.index("body = (revision=UP4_02B_REVISION, iteration=k")
    construction_end = source.index("push!(trace", construction_start)
    construction = source[construction_start:construction_end]
    ordered_fields = (
        "geometry_factor=geom_new",
        "internal_reaction_N=internal_reaction",
        "support_reaction_N=support_reaction",
        "energy_residual_W=energy_residual",
        "thermal_residual_W=thermal_residual",
        "force_residual_N=force_residual",
        "material_residual_Pa=material_residual",
        "state_change=state_change",
    )
    positions = [construction.index(field) for field in ordered_fields]
    if positions != sorted(positions):
        raise AssertionError("iteration construction hash body field order differs from canonical body")

    replay = fixture["positive_replay"]
    converged, trajectory = independent_replay(replay["max_iterations"], replay["tolerance"])
    if converged is not replay["expected_converged"] or len(trajectory) != replay["expected_iterations"]:
        raise AssertionError(f"positive replay did not match fixture: {trajectory}")
    if any(trajectory[i + 1] >= trajectory[i] for i in range(len(trajectory) - 1)):
        raise AssertionError(f"positive residual trajectory is not decreasing: {trajectory}")
    if trajectory[-1] > replay["tolerance"]:
        raise AssertionError("positive replay final residual exceeds tolerance")

    negatives = {item["id"] for item in fixture["negative"]}
    expected = {
        "forged_identity", "scenario_mismatch", "g3_mismatch",
        "upstream_execution_hash_mismatch", "load_sample_hash_mismatch", "foreign_sample",
        "negative_stored_difference",
        "missing_source", "missing_return", "missing_heat_sink", "missing_cooling",
        "unit_mismatch", "owner_mismatch", "direction_mismatch", "capacity_exceeded",
        "yield_exceeded", "nonfinite", "iteration_limit", "forged_residual",
        "double_counted_heat",
    }
    if negatives != expected or set(fixture["dispatch"]) != expected:
        raise AssertionError(f"negative matrix drifted: {sorted(negatives)}")
    if any(fixture["dispatch"][item["id"]] != item["dispatch"] for item in fixture["negative"]):
        raise AssertionError("fixture dispatch is not closed")
    forged_case = next(item for item in fixture["negative"] if item["id"] == "forged_residual")
    if forged_case["expected_status"] != "fail_closed":
        raise AssertionError("forged residual must fail closed")
    if "length(result.ledgers) == 4" not in test or "component_load_admitted" not in test:
        raise AssertionError("focused test does not assert four ledgers and load limitation")
    if "Set(keys(observed)) == Set(String(item.id) for item in fixture.negative)" not in test or "length(observed) == 20" not in test:
        raise AssertionError("focused test does not assert exact 20-case observed closure")
    if "load_sample_membership_mismatch" not in source or "_up4_02b_sample_membership" not in source:
        raise AssertionError("request does not enforce exact upstream sample membership")
    if "any(abs(x.force_residual_N) > 0.0 for x in result.iteration_trace)" not in test:
        raise AssertionError("focused test does not prove independently solved force residual")
    if "tampered_trace" not in test or "@test_throws ArgumentError canonical_hash(tampered_trace)" not in test:
        raise AssertionError("focused test does not guard reaction fields in iteration hash")
    if "canonical_hash(request) == request.request_hash" not in test:
        raise AssertionError("focused test does not close request identity")

    hashes = {str(path.relative_to(ROOT)): sha256(path) for path in (SOURCE, TEST, FIXTURE, Path(__file__))}
    print(json.dumps({
        "status": "PASS static_qa_up4_02b_engineering_feedback_execution_v1_r14",
        "negative_case_count": len(negatives),
        "positive_replay_iterations": len(trajectory),
        "positive_residual_trajectory": trajectory,
        "positive_final_residual": trajectory[-1],
        "ledger_count": 4,
        "claim_ceiling": "screen_only",
        "component_load_admitted": False,
        "julia_executed": False,
        "desc_executed": False,
        "sha256": hashes,
    }, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
