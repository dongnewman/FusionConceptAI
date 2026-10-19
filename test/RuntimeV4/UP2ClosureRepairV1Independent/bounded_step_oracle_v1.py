"""Independent SciPy audit of saved N1 lower-bounded linear subproblems.

The producer must first save the actual unscaled assembly and its scaled
``A, r, lower`` snapshot.  This consumer reconstructs the scaling, binds the
saved-state lineage and source files, and solves the convex subproblem with
SciPy BVLS/TRF/SVD routines.  It does not translate the Julia working-set
algorithm and does not execute a nonlinear or physical solve.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import platform
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np
import scipy
import scipy.linalg
from scipy.optimize import lsq_linear


EXPECTED_UPDATES = (0, 1, 12)
KKT_ABSOLUTE_TOLERANCE = 1.0e-10
RANK_RELATIVE_TOLERANCE = 1.0e-10
FEASIBILITY_ROUNDOFF_FACTOR = 8.0
EPS = np.finfo(np.float64).eps


class AuditFailure(AssertionError):
    """A stable-code failure suitable for a preserved execution receipt."""

    def __init__(self, code: str, detail: str):
        super().__init__(f"{code}: {detail}")
        self.code = code
        self.detail = detail


def require(condition: bool, code: str, detail: str) -> None:
    if not condition:
        raise AuditFailure(code, detail)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def digest_value(value: Any) -> str:
    if isinstance(value, dict) and set(value) == {"value"}:
        value = value["value"]
    require(
        isinstance(value, str)
        and len(value) == 64
        and all(c in "0123456789abcdef" for c in value),
        "identity_digest_error",
        f"invalid SHA-256 value {value!r}",
    )
    return value


def finite_vector(value: Any, length: int, label: str) -> np.ndarray:
    result = np.asarray(value, dtype=np.float64)
    require(result.shape == (length,), "shape_error", f"{label} has shape {result.shape}")
    require(bool(np.all(np.isfinite(result))), "nonfinite_error", f"{label} is nonfinite")
    return result


@dataclass(frozen=True)
class CoordinateMatrix:
    rows: int
    columns: int
    row_indices: np.ndarray
    column_indices: np.ndarray
    values: np.ndarray

    def dense(self) -> np.ndarray:
        result = np.zeros((self.rows, self.columns), dtype=np.float64)
        result[self.row_indices, self.column_indices] = self.values
        return result


def coordinate_matrix(block: dict[str, Any], rows: int, columns: int, label: str) -> CoordinateMatrix:
    require(block.get("format") == "coordinate", "matrix_format_error", f"{label} format")
    ii = np.asarray(block.get("row_indices"), dtype=np.int64)
    jj = np.asarray(block.get("column_indices"), dtype=np.int64)
    vv = np.asarray(block.get("values"), dtype=np.float64)
    require(ii.ndim == jj.ndim == vv.ndim == 1, "matrix_shape_error", f"{label} vectors")
    require(len(ii) == len(jj) == len(vv), "matrix_shape_error", f"{label} vector lengths")
    require(bool(np.all(np.isfinite(vv))), "matrix_nonfinite_error", label)
    require(bool(np.all((1 <= ii) & (ii <= rows))), "matrix_index_error", f"{label} rows")
    require(bool(np.all((1 <= jj) & (jj <= columns))), "matrix_index_error", f"{label} columns")
    pairs = list(zip(ii.tolist(), jj.tolist(), strict=True))
    require(len(pairs) == len(set(pairs)), "matrix_duplicate_coordinate", label)
    return CoordinateMatrix(rows, columns, ii - 1, jj - 1, vv)


def comparison_enclosure(actual: np.ndarray, expected: np.ndarray, operation_factor: float) -> dict[str, Any]:
    require(actual.shape == expected.shape, "comparison_shape_error", f"{actual.shape} != {expected.shape}")
    difference = np.abs(actual - expected)
    scale = np.maximum(np.maximum(np.abs(actual), np.abs(expected)), np.finfo(np.float64).tiny)
    allowance = operation_factor * EPS * scale
    passed = bool(np.all(difference <= allowance))
    ratios = np.divide(difference, allowance, out=np.zeros_like(difference), where=allowance > 0)
    return {
        "passed": passed,
        "operation_factor": operation_factor,
        "maximum_absolute_difference": float(np.max(difference, initial=0.0)),
        "maximum_allowance_ratio": float(np.max(ratios, initial=0.0)),
    }


def numeric_matrix_sha256(matrix: CoordinateMatrix) -> str:
    payload = b"".join(
        (
            np.asarray([matrix.rows, matrix.columns], dtype="<i8").tobytes(),
            np.asarray(matrix.row_indices + 1, dtype="<i8").tobytes(),
            np.asarray(matrix.column_indices + 1, dtype="<i8").tobytes(),
            np.asarray(matrix.values, dtype="<f8").tobytes(),
        )
    )
    return sha256_bytes(payload)


def compare_scaled_coordinate_matrices(
    raw: CoordinateMatrix,
    scaled: CoordinateMatrix,
    row_scales: np.ndarray,
    column_scales: np.ndarray,
) -> dict[str, Any]:
    raw_map = {
        (int(row), int(column)): float(value)
        for row, column, value in zip(raw.row_indices, raw.column_indices, raw.values, strict=True)
    }
    scaled_map = {
        (int(row), int(column)): float(value)
        for row, column, value in zip(scaled.row_indices, scaled.column_indices, scaled.values, strict=True)
    }
    raw_nonzero = {key for key, value in raw_map.items() if value != 0.0}
    scaled_nonzero = {key for key, value in scaled_map.items() if value != 0.0}
    require(
        raw_nonzero == scaled_nonzero,
        "scaled_matrix_nonzero_sparsity_mismatch",
        json.dumps(
            {
                "missing_scaled_nonzeros": sorted([list(key) for key in raw_nonzero - scaled_nonzero]),
                "extra_scaled_nonzeros": sorted([list(key) for key in scaled_nonzero - raw_nonzero]),
            }
        ),
    )
    keys = sorted(set(raw_map) | set(scaled_map))
    actual = np.asarray([scaled_map.get(key, 0.0) for key in keys], dtype=np.float64)
    expected = np.asarray(
        [
            (raw_map.get(key, 0.0) / row_scales[key[0]]) * column_scales[key[1]]
            for key in keys
        ],
        dtype=np.float64,
    )
    enclosure = comparison_enclosure(actual, expected, 8.0)
    require(enclosure["passed"], "scaled_matrix_reconstruction_mismatch", json.dumps(enclosure))
    return {
        **enclosure,
        "raw_stored_coordinates": len(raw_map),
        "scaled_stored_coordinates": len(scaled_map),
        "mathematical_nonzero_coordinates": len(raw_nonzero),
        "raw_explicit_zero_coordinates": len(raw_map) - len(raw_nonzero),
        "scaled_explicit_zero_coordinates": len(scaled_map) - len(scaled_nonzero),
        "coordinate_comparison": "key_union_with_missing_exact_zero",
    }


def scalar_enclosure(actual: float, expected: float, operation_factor: float, scale: float) -> bool:
    return abs(actual - expected) <= operation_factor * EPS * max(1.0, abs(actual), abs(expected), scale)


def least_squares_metrics(A: np.ndarray, r: np.ndarray, step: np.ndarray) -> dict[str, Any]:
    model = A @ step + r
    gradient = A.T @ model
    gamma_model = (A.shape[1] + 1) * EPS / (1.0 - (A.shape[1] + 1) * EPS)
    gamma_gradient = (A.shape[0] + 1) * EPS / (1.0 - (A.shape[0] + 1) * EPS)
    model_error_bound = gamma_model * (np.abs(A) @ np.abs(step) + np.abs(r))
    gradient_error_bound = 4.0 * (
        gamma_gradient * (np.abs(A).T @ np.abs(model)) + np.abs(A).T @ model_error_bound
    )
    return {
        "model": model,
        "gradient": gradient,
        "gradient_roundoff_bound": gradient_error_bound,
        "objective": float(np.dot(model, model) / 2.0),
        "normal_gradient_inf": float(np.linalg.norm(gradient, np.inf)),
        "normal_gradient_l2": float(np.linalg.norm(gradient, 2)),
        "gradient_roundoff_bound_l2": float(np.linalg.norm(gradient_error_bound, 2)),
    }


def semantic_least_squares_agreement(
    A: np.ndarray,
    r: np.ndarray,
    first: np.ndarray,
    second: np.ndarray,
    numerical_rank: int,
    singular_values: np.ndarray,
    label: str,
) -> dict[str, Any]:
    first_metrics = least_squares_metrics(A, r, first)
    second_metrics = least_squares_metrics(A, r, second)
    for name, metrics in (("first", first_metrics), ("second", second_metrics)):
        require(
            metrics["normal_gradient_inf"] <= KKT_ABSOLUTE_TOLERANCE,
            "unbounded_strict_stationarity_failure",
            f"{label} {name}: {metrics['normal_gradient_inf']}",
        )
    objective_tolerance = KKT_ABSOLUTE_TOLERANCE * max(
        1.0, abs(first_metrics["objective"]), abs(second_metrics["objective"])
    )
    objective_difference = abs(first_metrics["objective"] - second_metrics["objective"])
    require(
        objective_difference <= objective_tolerance,
        "unbounded_objective_disagreement",
        f"{label}: {objective_difference}>{objective_tolerance}",
    )
    require(0 < numerical_rank <= A.shape[1], "unbounded_numerical_rank_error", str(numerical_rank))
    retained_sigma_min = float(singular_values[numerical_rank - 1])
    require(retained_sigma_min > 0.0, "unbounded_retained_singular_value_error", str(retained_sigma_min))
    first_q_upper = first_metrics["normal_gradient_l2"] + first_metrics["gradient_roundoff_bound_l2"]
    second_q_upper = second_metrics["normal_gradient_l2"] + second_metrics["gradient_roundoff_bound_l2"]
    q_sum_upper = first_q_upper + second_q_upper
    delta = first - second
    fitted_delta_l2 = float(np.linalg.norm(A @ delta, 2))
    if numerical_rank == A.shape[1]:
        compared_quantity = "step_l2"
        observed = float(np.linalg.norm(delta, 2))
        derived_bound = q_sum_upper / (retained_sigma_min * retained_sigma_min)
    else:
        compared_quantity = "fitted_vector_l2"
        observed = fitted_delta_l2
        derived_bound = q_sum_upper / retained_sigma_min
    require(
        observed <= derived_bound,
        "unbounded_normal_equation_consistency_failure",
        f"{label} {compared_quantity}: {observed}>{derived_bound}",
    )
    return {
        "label": label,
        "numerical_rank": numerical_rank,
        "columns": A.shape[1],
        "singular_threshold": float(RANK_RELATIVE_TOLERANCE * singular_values[0]),
        "retained_singular_value_min": retained_sigma_min,
        "comparison": compared_quantity,
        "observed_difference": observed,
        "normal_equation_derived_bound": float(derived_bound),
        "fitted_vector_difference_l2": fitted_delta_l2,
        "objective_difference": objective_difference,
        "objective_tolerance": objective_tolerance,
        "first_normal_gradient_inf": first_metrics["normal_gradient_inf"],
        "second_normal_gradient_inf": second_metrics["normal_gradient_inf"],
        "first_gradient_roundoff_bound_l2": first_metrics["gradient_roundoff_bound_l2"],
        "second_gradient_roundoff_bound_l2": second_metrics["gradient_roundoff_bound_l2"],
        "scope": "numerical_error_audit_not_certified_spectral_bound",
    }


def expected_source_paths(repo_root: Path) -> dict[str, Path]:
    old_numerical = (
        repo_root
        / "docs"
        / "implementation"
        / "UP2-04-CLOSURE-REPAIR-PREC"
        / "agent_r2_n1_20260922"
        / "runtime_r1"
        / "numerical"
    )
    return {
        "old_solver_input_sha256": old_numerical / "solver_input.json",
        "old_attempts_sha256": old_numerical / "attempts.json",
        "old_solver_primary_sha256": old_numerical / "solver_primary.json",
        "benchmark_sha256": repo_root / "test" / "RuntimeV4" / "UP2ClosureRepairV1" / "n1_manufactured_refinement_v2.jl",
        "callback_source_sha256": repo_root / "test" / "RuntimeV4" / "UP2ClosureRepairV1" / "n1_manufactured_refinement_v2.jl",
        "spatial_solver_sha256": repo_root / "src" / "RuntimeV4" / "SpatialMultiRegionV4.jl",
    }


def validate_source_binding(binding: dict[str, Any], algorithm: dict[str, Any], repo_root: Path) -> dict[str, str]:
    observed: dict[str, str] = {}
    paths = expected_source_paths(repo_root)
    for field in (
        "old_solver_input_sha256",
        "old_attempts_sha256",
        "benchmark_sha256",
        "spatial_solver_sha256",
    ):
        path = paths[field]
        require(field in binding, "source_binding_missing", field)
        require(path.is_file(), "source_file_missing", str(path))
        actual = sha256_file(path)
        expected = digest_value(binding[field])
        require(actual == expected, "source_hash_mismatch", f"{field}: {actual} != {expected}")
        observed[field] = actual

    helper = repo_root / "src" / "RuntimeV4" / "SpatialBoundedLinearStepV1.jl"
    helper_hash = sha256_file(helper)
    require(
        digest_value(algorithm.get("implementation_sha256")) == helper_hash,
        "bounded_step_implementation_hash_mismatch",
        str(helper),
    )
    observed["bounded_step_implementation_sha256"] = helper_hash

    identity = binding.get("source_identity")
    require(isinstance(identity, dict), "source_identity_missing", "source_identity")
    callback = identity.get("callback", {})
    callback_hash = sha256_file(paths["callback_source_sha256"])
    require(
        digest_value(callback.get("saved_sha256"))
        == digest_value(callback.get("current_sha256"))
        == callback_hash,
        "callback_source_identity_error",
        "saved/current/live callback hashes differ",
    )
    require(
        callback.get("saved_source") == "solver_input.json:callback_source_sha256",
        "callback_source_provenance_error",
        repr(callback.get("saved_source")),
    )
    observed["callback_source_sha256"] = callback_hash

    solver_input_path = paths["old_solver_input_sha256"]
    solver_primary_path = paths["old_solver_primary_sha256"]
    solver_payload = solver_input_path.read_text(encoding="utf-8").rstrip("\r\n")
    solver_digest = sha256_bytes(solver_payload.encode("utf-8"))
    solver_primary = read_json(solver_primary_path)
    solver_identity = identity.get("solver_input", {})
    require(
        digest_value(solver_identity.get("saved_digest"))
        == digest_value(solver_identity.get("current_digest"))
        == digest_value(solver_primary.get("input_hash"))
        == solver_digest,
        "solver_input_identity_error",
        "saved/current/primary/live digests differ",
    )
    require(
        solver_identity.get("canonical_payload") == solver_payload,
        "solver_input_payload_error",
        "payload does not equal the frozen solver input",
    )
    require(
        digest_value(solver_identity.get("primary_file_sha256")) == sha256_file(solver_primary_path),
        "solver_primary_hash_mismatch",
        str(solver_primary_path),
    )
    require(
        solver_identity.get("saved_source") == "solver_primary.json:input_hash",
        "solver_input_provenance_error",
        repr(solver_identity.get("saved_source")),
    )
    observed["solver_input_canonical_sha256"] = solver_digest
    observed["solver_primary_sha256"] = sha256_file(solver_primary_path)

    saved_input = json.loads(solver_payload)
    require(
        digest_value(saved_input.get("callback_source_sha256")) == callback_hash,
        "callback_saved_input_mismatch",
        "solver_input.json callback_source_sha256",
    )
    for field, saved_field in (("declaration", "declaration"), ("analytic", "analytic_inputs")):
        item = identity.get(field, {})
        payload = item.get("canonical_payload")
        require(isinstance(payload, str), "canonical_payload_missing", field)
        require(
            item.get("saved_digest") is None
            and item.get("saved_digest_status") == "absent_as_separate_field",
            "invented_saved_digest",
            field,
        )
        require(
            digest_value(item.get("current_digest")) == sha256_bytes(payload.encode("utf-8")),
            "canonical_payload_digest_mismatch",
            field,
        )
        require(
            json.loads(payload) == saved_input[saved_field],
            "canonical_payload_source_mismatch",
            field,
        )
        require(
            item.get("comparison") in ("full_parsed_canonical_payload_equal", "full_parsed_payload_equal"),
            "canonical_payload_comparison_error",
            field,
        )
        observed[f"{field}_canonical_sha256"] = sha256_bytes(payload.encode("utf-8"))

    operator = identity.get("operator", {})
    operator_path = Path(operator.get("source_path", "")).resolve()
    require(operator_path == paths["spatial_solver_sha256"].resolve(), "operator_path_error", str(operator_path))
    require(digest_value(operator.get("source_sha256")) == sha256_file(operator_path), "operator_hash_error", str(operator_path))
    require(operator.get("entry") == "assemble_spatial_system_v4", "operator_entry_error", repr(operator.get("entry")))
    require(
        isinstance(operator.get("module_name"), str)
        and operator["module_name"].endswith("RuntimeV4ManufacturedRecoveryBenchmark")
        and isinstance(operator.get("callback_module"), str)
        and operator["callback_module"].endswith("N1ManufacturedRefinementV2"),
        "operator_module_identity_error",
        repr(operator),
    )
    require(
        operator.get("source_callback") == "source_v2"
        and operator.get("traction_callback") == "traction_v2"
        and operator.get("normal_callback") == "normal_v2"
        and operator.get("flux_callback") == "flux_v2",
        "operator_callback_error",
        repr(operator),
    )
    require(identity.get("canonical_hash_algorithm") == "sha256_of_canonical_json_UTF8", "canonical_hash_algorithm_error", repr(identity.get("canonical_hash_algorithm")))
    canonical_sources = identity.get("canonical_sources", {})
    canonical_expected = {
        "hashes_sha256": repo_root / "src" / "Canonical" / "Hashes.jl",
        "json_sha256": repo_root / "src" / "Canonical" / "CanonicalJSON.jl",
    }
    for field, path in canonical_expected.items():
        require(digest_value(canonical_sources.get(field)) == sha256_file(path), "canonical_source_hash_error", field)
        observed[field] = sha256_file(path)
    return observed


def reconstruct_saved_state(
    binding: dict[str, Any], solver_input: dict[str, Any], attempts: list[dict[str, Any]]
) -> dict[str, Any]:
    columns = len(binding["column_scales"])
    scales = finite_vector(binding["column_scales"], columns, "column_scales")
    state = finite_vector(solver_input["initial_state"], columns, "initial_state").copy()
    update_target = int(binding["after_accepted_updates"])
    require(update_target >= 0, "state_update_index_error", str(update_target))
    require(attempts, "state_attempts_empty", "attempt list")

    current_hash = digest_value(attempts[0]["state_before_hash"])
    accepted_count = 0
    expected_by_count: dict[int, str] = {0: current_hash}
    reconstructed_by_count: dict[int, np.ndarray] = {0: state.copy()}
    require(
        len(attempts) == EXPECTED_UPDATES[-1] and all(bool(attempt.get("accepted")) for attempt in attempts),
        "legacy_attempt_index_contract_error",
        "the frozen producer maps k to attempt index only because all 12 attempts were accepted",
    )
    for attempt in attempts:
        before_hash = digest_value(attempt["state_before_hash"])
        require(before_hash == current_hash, "state_hash_chain_error", "state_before_hash")
        if bool(attempt["accepted"]):
            step = finite_vector(attempt["proposed_scaled_step"], columns, "proposed_scaled_step")
            alpha = float(attempt["accepted_alpha"])
            require(math.isfinite(alpha), "state_update_nonfinite", "accepted_alpha")
            state = state + alpha * scales * step
            for pressure in range(3, columns, 4):
                tolerance = FEASIBILITY_ROUNDOFF_FACTOR * EPS * max(1.0, abs(state[pressure] / scales[pressure])) * scales[pressure]
                require(state[pressure] >= -tolerance, "saved_pressure_infeasible", str(pressure + 1))
                if state[pressure] < 0.0:
                    state[pressure] = 0.0
            accepted_count += 1
        after_hash = digest_value(attempt["state_after_hash"])
        current_hash = after_hash
        expected_by_count[accepted_count] = current_hash
        reconstructed_by_count[accepted_count] = state.copy()

    require(update_target in expected_by_count, "state_update_index_error", str(update_target))
    state_identity = binding.get("state_identity", {})
    require(isinstance(state_identity, dict), "state_hash_binding_missing", "state_identity")
    bound_hash = digest_value(state_identity.get("saved_digest"))
    require(bound_hash == expected_by_count[update_target], "saved_state_hash_mismatch", str(update_target))
    require(
        digest_value(state_identity.get("current_digest")) == bound_hash,
        "current_state_hash_mismatch",
        str(update_target),
    )
    state_payload = state_identity.get("canonical_payload")
    require(isinstance(state_payload, str), "state_payload_missing", str(update_target))
    require(sha256_bytes(state_payload.encode("utf-8")) == bound_hash, "state_payload_hash_mismatch", str(update_target))
    require(state_identity.get("saved_source") == "attempts.json", "state_source_error", repr(state_identity.get("saved_source")))
    expected_field = "state_before_hash" if update_target == 0 else "state_after_hash"
    expected_attempt_index = 1 if update_target == 0 else update_target
    require(state_identity.get("field") == expected_field, "state_hash_field_error", repr(state_identity.get("field")))
    require(int(state_identity.get("attempt_index")) == expected_attempt_index, "state_hash_attempt_error", repr(state_identity.get("attempt_index")))

    observed_state = finite_vector(binding["state"], columns, "binding.state")
    payload_state = finite_vector(json.loads(state_payload), columns, "state_identity.canonical_payload")
    require(np.array_equal(payload_state, observed_state), "state_payload_value_mismatch", str(update_target))
    expected_state = reconstructed_by_count[update_target]
    difference = np.abs(observed_state - expected_state)
    # Each accepted update has two products and one addition.  This enclosure
    # checks serialization/reconstruction only; it is not a KKT relaxation.
    allowance = 8.0 * max(1, update_target) * EPS * np.maximum(
        1.0, np.maximum(np.abs(observed_state), np.abs(expected_state))
    )
    require(bool(np.all(difference <= allowance)), "saved_state_reconstruction_mismatch", str(update_target))
    return {
        "saved_state_hash": bound_hash,
        "maximum_state_reconstruction_difference": float(np.max(difference, initial=0.0)),
        "maximum_state_reconstruction_allowance": float(np.max(allowance, initial=0.0)),
    }


def validate_scaled_input(top: dict[str, Any]) -> tuple[np.ndarray, np.ndarray, np.ndarray, dict[str, Any]]:
    binding = top["binding"]
    raw = top["raw"]
    snapshot = top["input"]
    require(raw.get("origin") == "actual_unscaled_assembly", "raw_origin_error", repr(raw.get("origin")))
    require(snapshot.get("schema") == "spatial-bounded-linear-input-v1", "snapshot_schema_error", repr(snapshot.get("schema")))
    require(snapshot.get("index_base") == 1, "snapshot_index_base_error", repr(snapshot.get("index_base")))
    require(snapshot.get("coordinates") == "dimensionless_scaled_step", "snapshot_coordinate_error", repr(snapshot.get("coordinates")))
    require(snapshot.get("objective") == "half_squared_norm_A_step_plus_residual", "snapshot_objective_error", repr(snapshot.get("objective")))
    require(snapshot.get("zero_step_feasible") is True, "snapshot_zero_feasibility_error", "false")

    rows = int(snapshot["rows"])
    columns = int(snapshot["columns"])
    require(rows == int(raw["jacobian"]["rows"]), "raw_scaled_shape_error", "rows")
    require(columns == int(raw["jacobian"]["columns"]), "raw_scaled_shape_error", "columns")
    require(raw["jacobian"].get("index_base") == 1, "raw_index_base_error", repr(raw["jacobian"].get("index_base")))
    require(columns == len(binding["state"]) == 40, "n1_column_contract_error", str(columns))
    require(rows == 289, "n1_row_contract_error", str(rows))

    raw_matrix = coordinate_matrix(raw["jacobian"], rows, columns, "raw.jacobian")
    scaled_matrix = coordinate_matrix(snapshot["matrix"], rows, columns, "input.matrix")

    row_scales = finite_vector(binding["row_scales"], rows, "row_scales")
    column_scales = finite_vector(binding["column_scales"], columns, "column_scales")
    require(bool(np.all(row_scales > 0.0)), "row_scale_contract_error", "nonpositive row scale")
    expected_columns = np.tile(np.array([5.0, 5.0, 5.0, 100000.0]), columns // 4)
    require(np.array_equal(column_scales, expected_columns), "column_scale_contract_error", "not [5,5,5,1e5]")
    require(len(binding["row_blocks"]) == rows, "row_block_contract_error", "row block count")

    matrix_enclosure = compare_scaled_coordinate_matrices(raw_matrix, scaled_matrix, row_scales, column_scales)

    raw_residual = finite_vector(raw["residual"], rows, "raw.residual")
    scaled_residual = finite_vector(snapshot["residual"], rows, "input.residual")
    residual_enclosure = comparison_enclosure(scaled_residual, raw_residual / row_scales, 4.0)
    require(residual_enclosure["passed"], "scaled_residual_reconstruction_mismatch", json.dumps(residual_enclosure))

    state = finite_vector(binding["state"], columns, "binding.state")
    lower = np.full(columns, -np.inf, dtype=np.float64)
    lower[3::4] = -state[3::4] / column_scales[3::4]
    observed_lower = np.array(
        [-np.inf if value is None else float(value) for value in snapshot["lower_bounds"]], dtype=np.float64
    )
    require(observed_lower.shape == (columns,), "lower_bound_shape_error", str(observed_lower.shape))
    require(np.array_equal(observed_lower, lower), "lower_bound_reconstruction_mismatch", "pressure lower bounds")
    require(bool(np.all(lower <= 0.0)), "zero_step_infeasible", "positive lower bound")
    unbounded = [index + 1 for index in np.flatnonzero(~np.isfinite(lower)).tolist()]
    require(snapshot["unbounded_below_indices"] == unbounded, "unbounded_index_mismatch", repr(unbounded))

    algorithm = snapshot["algorithm"]
    policy = algorithm["policy"]
    require(algorithm.get("method") == "lower_bounded_sparse_QR_active_set_v1", "algorithm_method_error", repr(algorithm.get("method")))
    require(algorithm.get("scope") == "linearized_subproblem_only", "algorithm_scope_error", repr(algorithm.get("scope")))
    require(float(policy.get("rank_relative_tolerance")) == RANK_RELATIVE_TOLERANCE, "rank_tolerance_error", repr(policy.get("rank_relative_tolerance")))
    require(float(policy.get("kkt_absolute_tolerance")) == KKT_ABSOLUTE_TOLERANCE, "kkt_tolerance_error", repr(policy.get("kkt_absolute_tolerance")))
    require(float(policy.get("feasibility_roundoff_factor")) == FEASIBILITY_ROUNDOFF_FACTOR, "feasibility_factor_error", repr(policy.get("feasibility_roundoff_factor")))

    checks = {
        "raw_rows": rows,
        "raw_columns": columns,
        "raw_nonzeros": len(raw_matrix.values),
        "raw_matrix_numeric_sha256": numeric_matrix_sha256(raw_matrix),
        "scaled_matrix_numeric_sha256": numeric_matrix_sha256(scaled_matrix),
        "raw_residual_f64le_sha256": sha256_bytes(np.asarray(raw_residual, dtype="<f8").tobytes()),
        "scaled_residual_f64le_sha256": sha256_bytes(np.asarray(scaled_residual, dtype="<f8").tobytes()),
        "matrix_reconstruction": matrix_enclosure,
        "residual_reconstruction": residual_enclosure,
        "finite_lower_bound_indices": [index + 1 for index in np.flatnonzero(np.isfinite(lower)).tolist()],
    }
    return scaled_matrix.dense(), scaled_residual, lower, checks


def independent_kkt(
    A: np.ndarray,
    r: np.ndarray,
    lower: np.ndarray,
    step: np.ndarray,
    working_active_indices: list[int] | None = None,
) -> dict[str, Any]:
    model = A @ step + r
    gradient = A.T @ model
    finite_bounds = np.isfinite(lower)
    coordinate_tolerances = FEASIBILITY_ROUNDOFF_FACTOR * EPS * np.maximum(
        1.0, np.maximum(np.abs(step), np.abs(np.where(finite_bounds, lower, 0.0)))
    )
    contact = finite_bounds & (np.abs(step - np.where(finite_bounds, lower, 0.0)) <= coordinate_tolerances)
    if working_active_indices is None:
        active = contact
    else:
        active = np.zeros_like(finite_bounds)
        zero_based = np.asarray(working_active_indices, dtype=np.int64) - 1
        require(
            zero_based.ndim == 1
            and len(zero_based) == len(np.unique(zero_based))
            and bool(np.all((0 <= zero_based) & (zero_based < len(lower)))),
            "working_active_index_error",
            repr(working_active_indices),
        )
        active[zero_based] = True
        require(bool(np.all(finite_bounds[active])), "working_active_unbounded_error", repr(working_active_indices))
        require(bool(np.all(contact[active])), "working_active_not_at_bound", repr(working_active_indices))
    free = ~active
    primal_violations = np.where(finite_bounds, np.maximum(lower - step, 0.0), 0.0)
    primal_violation = float(np.max(primal_violations, initial=0.0))
    primal_feasible = bool(np.all(step[finite_bounds] >= lower[finite_bounds] - coordinate_tolerances[finite_bounds]))
    free_stationarity = float(np.max(np.abs(gradient[free]), initial=0.0))
    lower_dual_violation = float(np.max(np.maximum(-gradient[active], 0.0), initial=0.0))
    gaps = step[finite_bounds] - lower[finite_bounds]
    finite_gradient = gradient[finite_bounds]
    complementarity = float(np.max(np.abs(gaps * finite_gradient), initial=0.0))
    scaled_complementarity = float(
        np.max(np.abs(gaps * finite_gradient) / np.maximum(1.0, np.abs(gaps)), initial=0.0)
    )
    objective = float(np.dot(model, model) / 2.0)
    passed = (
        bool(np.all(np.isfinite(step)))
        and bool(np.all(np.isfinite(model)))
        and bool(np.all(np.isfinite(gradient)))
        and primal_feasible
        and free_stationarity <= KKT_ABSOLUTE_TOLERANCE
        and lower_dual_violation <= KKT_ABSOLUTE_TOLERANCE
        and scaled_complementarity <= KKT_ABSOLUTE_TOLERANCE
    )
    return {
        "passed": passed,
        "tolerance": KKT_ABSOLUTE_TOLERANCE,
        "gradient": gradient.tolist(),
        "active_indices": [index + 1 for index in np.flatnonzero(active).tolist()],
        "free_indices": [index + 1 for index in np.flatnonzero(free).tolist()],
        "contact_indices": [index + 1 for index in np.flatnonzero(contact).tolist()],
        "primal_violation": primal_violation,
        "maximum_coordinate_tolerance": float(np.max(coordinate_tolerances[finite_bounds], initial=0.0)),
        "primal_coordinate_tolerances": [
            {"index": index + 1, "tolerance": float(coordinate_tolerances[index])}
            for index in np.flatnonzero(finite_bounds).tolist()
        ],
        "primal_feasible": primal_feasible,
        "free_stationarity": free_stationarity,
        "lower_dual_violation": lower_dual_violation,
        "complementarity": complementarity,
        "scaled_complementarity": scaled_complementarity,
        "objective": objective,
    }


def validate_serialized_kkt(
    result: dict[str, Any], global_audit: dict[str, Any], working_audit: dict[str, Any], A: np.ndarray, r: np.ndarray
) -> None:
    stored = result["kkt"]
    require(stored.get("passed") is True and stored.get("finite") is True, "stored_kkt_failed", repr(stored.get("passed")))
    require(
        set(result.get("active_indices", [])) <= set(global_audit["contact_indices"]),
        "working_active_not_contact_subset",
        repr(result.get("active_indices")),
    )
    require(result.get("active_indices") == working_audit["active_indices"], "active_index_mismatch", repr(result.get("active_indices")))
    require(result.get("free_indices") == working_audit["free_indices"], "free_index_mismatch", repr(result.get("free_indices")))
    require(float(stored["tolerance"]) == KKT_ABSOLUTE_TOLERANCE, "stored_kkt_tolerance_error", repr(stored["tolerance"]))
    require(stored.get("primal_feasible") is True, "stored_primal_feasibility_error", "false")
    require(stored.get("working_bounds_satisfied") is True, "stored_working_bound_error", "false")
    coordinate_records = stored.get("primal_coordinate_tolerances")
    require(isinstance(coordinate_records, list), "stored_coordinate_tolerance_error", "not a list")
    expected_coordinate_records = global_audit["primal_coordinate_tolerances"]
    require(
        [int(record["index"]) for record in coordinate_records]
        == [record["index"] for record in expected_coordinate_records],
        "stored_coordinate_tolerance_index_error",
        repr(coordinate_records),
    )
    for stored_record, expected_record in zip(coordinate_records, expected_coordinate_records, strict=True):
        tolerance_check = comparison_enclosure(
            np.asarray([float(stored_record["tolerance"])]),
            np.asarray([float(expected_record["tolerance"])]),
            2.0,
        )
        require(
            tolerance_check["passed"],
            "stored_coordinate_tolerance_value_error",
            json.dumps(tolerance_check),
        )
    step = np.asarray(result["step"], dtype=np.float64)
    model = A @ step + r
    scale = float(np.linalg.norm(A, 1) * max(np.linalg.norm(model, np.inf), np.linalg.norm(r, np.inf)))
    gradient = finite_vector(stored["gradient"], A.shape[1], "result.kkt.gradient")
    independently_computed_gradient = np.asarray(working_audit["gradient"])
    gamma_model = (A.shape[1] + 1) * EPS / (1.0 - (A.shape[1] + 1) * EPS)
    gamma_gradient = (A.shape[0] + 1) * EPS / (1.0 - (A.shape[0] + 1) * EPS)
    model_magnitude = np.abs(A) @ np.abs(step) + np.abs(r)
    model_error_bound = gamma_model * model_magnitude
    gradient_error_bound = 4.0 * (
        gamma_gradient * (np.abs(A).T @ np.abs(model)) + np.abs(A).T @ model_error_bound
    )
    gradient_difference = np.abs(gradient - independently_computed_gradient)
    require(
        bool(np.all(gradient_difference <= gradient_error_bound)),
        "stored_gradient_mismatch",
        json.dumps(
            {
                "maximum_absolute_difference": float(np.max(gradient_difference, initial=0.0)),
                "maximum_forward_error_bound": float(np.max(gradient_error_bound, initial=0.0)),
            }
        ),
    )
    for field in ("free_stationarity", "lower_dual_violation", "scaled_complementarity"):
        require(float(stored[field]) <= KKT_ABSOLUTE_TOLERANCE, "stored_strict_kkt_metric_failure", field)
    for field in (
        "primal_violation",
        "free_stationarity",
        "lower_dual_violation",
        "complementarity",
        "scaled_complementarity",
        "objective",
    ):
        require(
            scalar_enclosure(float(stored[field]), float(working_audit[field]), 256.0 * max(1, A.shape[0]), scale),
            "stored_kkt_metric_mismatch",
            field,
        )


def scipy_oracles(A: np.ndarray, r: np.ndarray, lower: np.ndarray) -> dict[str, Any]:
    upper = np.full(A.shape[1], np.inf, dtype=np.float64)
    bvls = lsq_linear(A, -r, bounds=(lower, upper), method="bvls", tol=1.0e-14, max_iter=10000)
    trf = lsq_linear(
        A,
        -r,
        bounds=(lower, upper),
        method="trf",
        lsq_solver="exact",
        tol=1.0e-14,
        max_iter=10000,
    )
    bvls_audit = independent_kkt(A, r, lower, np.asarray(bvls.x, dtype=np.float64))
    trf_audit = independent_kkt(A, r, lower, np.asarray(trf.x, dtype=np.float64))
    require(bool(bvls.success), "scipy_bvls_solver_failure", str(bvls.message))
    require(bvls_audit["passed"], "scipy_bvls_strict_kkt_failure", json.dumps(bvls_audit))
    require(bool(trf.success), "scipy_trf_solver_failure", str(trf.message))
    require(
        abs(float(bvls_audit["objective"]) - float(trf_audit["objective"]))
        <= KKT_ABSOLUTE_TOLERANCE
        * max(1.0, abs(float(bvls_audit["objective"])), abs(float(trf_audit["objective"]))),
        "scipy_bvls_trf_objective_disagreement",
        f"BVLS={bvls_audit['objective']} TRF={trf_audit['objective']}",
    )

    svd_step, _, svd_rank, singular_values = scipy.linalg.lstsq(
        A, -r, cond=RANK_RELATIVE_TOLERANCE, lapack_driver="gelsd"
    )
    qr_step, _, qr_rank, _ = scipy.linalg.lstsq(
        A, -r, cond=RANK_RELATIVE_TOLERANCE, lapack_driver="gelsy"
    )
    svd_model = A @ svd_step + r
    qr_model = A @ qr_step + r
    condition = float(singular_values[0] / singular_values[-1]) if singular_values[-1] > 0.0 else None
    return {
        "bvls": {
            "success": bool(bvls.success),
            "status": int(bvls.status),
            "message": str(bvls.message),
            "iterations": None if bvls.nit is None else int(bvls.nit),
            "step": np.asarray(bvls.x).tolist(),
            "audit": bvls_audit,
        },
        "trf": {
            "success": bool(trf.success),
            "status": int(trf.status),
            "message": str(trf.message),
            "iterations": None if trf.nit is None else int(trf.nit),
            "step": np.asarray(trf.x).tolist(),
            "audit": trf_audit,
        },
        "unbounded_svd": {
            "rank": int(svd_rank),
            "condition_number": condition,
            "singular_values": np.asarray(singular_values).tolist(),
            "numerical_rank_threshold": float(RANK_RELATIVE_TOLERANCE * singular_values[0]),
            "step": np.asarray(svd_step).tolist(),
            "objective": float(np.dot(svd_model, svd_model) / 2.0),
            "normal_gradient_inf": float(np.linalg.norm(A.T @ svd_model, np.inf)),
        },
        "unbounded_qr": {
            "rank": int(qr_rank),
            "step": np.asarray(qr_step).tolist(),
            "objective": float(np.dot(qr_model, qr_model) / 2.0),
            "normal_gradient_inf": float(np.linalg.norm(A.T @ qr_model, np.inf)),
        },
    }


def audit_case(
    update: int,
    input_path: Path,
    result_path: Path,
    repo_root: Path,
    solver_input: dict[str, Any],
    attempts: list[dict[str, Any]],
) -> dict[str, Any]:
    require(input_path.is_file(), "snapshot_input_missing", str(input_path))
    require(result_path.is_file(), "snapshot_result_missing", str(result_path))
    input_bytes = input_path.read_bytes()
    result_bytes = result_path.read_bytes()
    input_top = json.loads(input_bytes)
    result_top = json.loads(result_bytes)
    for field in ("binding", "raw", "input"):
        require(input_top[field] == result_top[field], "input_result_binding_mismatch", field)
    binding = input_top["binding"]
    require(binding.get("case") == "n1_v2_saved_legacy_state", "binding_case_error", repr(binding.get("case")))
    require(int(binding.get("after_accepted_updates")) == update, "binding_update_error", str(update))
    require(binding.get("physical_convergence") == "not_assessed", "binding_physical_scope_error", repr(binding.get("physical_convergence")))

    A, r, lower, scaling_checks = validate_scaled_input(input_top)
    source_hashes = validate_source_binding(binding, input_top["input"]["algorithm"], repo_root)
    state_lineage = reconstruct_saved_state(binding, solver_input, attempts)

    result = result_top["result"]
    require(result.get("converged") is True, "julia_bounded_step_not_converged", repr(result.get("status")))
    require(int(result.get("exit_code")) == 0, "julia_bounded_step_exit_error", repr(result.get("exit_code")))
    require(result.get("status") == "kkt_converged", "julia_bounded_step_status_error", repr(result.get("status")))
    require(result.get("physical_convergence") == "not_assessed", "result_physical_scope_error", repr(result.get("physical_convergence")))
    require(result.get("algorithm") == input_top["input"]["algorithm"], "result_algorithm_identity_error", "algorithm")
    require(result.get("failure") is None, "julia_bounded_step_failure_payload", repr(result.get("failure")))
    require(int(result.get("inner_iterations")) <= int(result.get("inner_iteration_limit")), "inner_iteration_limit_error", repr(result.get("inner_iterations")))
    require(result.get("history") and result["history"][-1].get("event") == "kkt_converged", "history_terminal_event_error", repr(result.get("history", [])[-1:]))
    step = finite_vector(result["step"], A.shape[1], "result.step")
    actual_audit = independent_kkt(A, r, lower, step)
    require(actual_audit["passed"], "julia_step_strict_kkt_failure", json.dumps(actual_audit))
    working_audit = independent_kkt(A, r, lower, step, [int(value) for value in result.get("active_indices", [])])
    require(working_audit["passed"], "julia_working_set_strict_kkt_failure", json.dumps(working_audit))
    validate_serialized_kkt(result, actual_audit, working_audit, A, r)
    initial_objective = float(np.dot(r, r) / 2.0)
    require(
        scalar_enclosure(float(result["initial_objective"]), initial_objective, 256.0 * A.shape[0], initial_objective),
        "initial_objective_mismatch",
        repr(result.get("initial_objective")),
    )

    scipy_results = scipy_oracles(A, r, lower)
    bvls_objective = float(scipy_results["bvls"]["audit"]["objective"])
    require(
        abs(actual_audit["objective"] - bvls_objective)
        <= KKT_ABSOLUTE_TOLERANCE * max(1.0, abs(actual_audit["objective"]), abs(bvls_objective)),
        "bounded_objective_disagreement",
        f"Julia={actual_audit['objective']} BVLS={bvls_objective}",
    )

    stored_unbounded = finite_vector(result_top["unbounded_QR_step"], A.shape[1], "unbounded_QR_step")
    singular_values = np.asarray(scipy_results["unbounded_svd"]["singular_values"], dtype=np.float64)
    rank = int(scipy_results["unbounded_svd"]["rank"])
    if result.get("unconstrained_step") is None:
        unconstrained_identity = {"status": "nullable_not_recorded_from_nonempty_initial_working_set"}
    else:
        result_unconstrained = finite_vector(result["unconstrained_step"], A.shape[1], "result.unconstrained_step")
        unconstrained_identity = semantic_least_squares_agreement(
            A, r, stored_unbounded, result_unconstrained, rank, singular_values, "top_level_QR_vs_helper_QR"
        )
    stored_unbounded_feasible = bool(np.all(stored_unbounded >= lower))
    require(
        result_top["unbounded_QR_feasible"] is stored_unbounded_feasible,
        "unbounded_feasibility_mismatch",
        repr(stored_unbounded_feasible),
    )
    stored_model = A @ stored_unbounded + r
    stored_objective = float(np.dot(stored_model, stored_model) / 2.0)
    svd_objective = float(scipy_results["unbounded_svd"]["objective"])
    svd_step = np.asarray(scipy_results["unbounded_svd"]["step"], dtype=np.float64)
    top_vs_svd = semantic_least_squares_agreement(
        A, r, stored_unbounded, svd_step, rank, singular_values, "top_level_QR_vs_independent_SVD"
    )
    helper_vs_svd = (
        None
        if result.get("unconstrained_step") is None
        else semantic_least_squares_agreement(
            A,
            r,
            result_unconstrained,
            svd_step,
            rank,
            singular_values,
            "helper_QR_vs_independent_SVD",
        )
    )

    return {
        "after_accepted_updates": update,
        "input_path": str(input_path),
        "result_path": str(result_path),
        "input_sha256": sha256_bytes(input_bytes),
        "result_sha256": sha256_bytes(result_bytes),
        "source_hashes": source_hashes,
        "state_lineage": state_lineage,
        "scaling_checks": scaling_checks,
        "julia_step_audit": actual_audit,
        "julia_working_set_audit": working_audit,
        "scipy_oracles": scipy_results,
        "objective_difference_julia_minus_bvls": actual_audit["objective"] - bvls_objective,
        "stored_unbounded_qr": {
            "feasible": stored_unbounded_feasible,
            "objective": stored_objective,
            "normal_gradient_inf": float(np.linalg.norm(A.T @ stored_model, np.inf)),
            "helper_nullable_unconstrained_comparison": unconstrained_identity,
            "top_level_vs_independent_svd": top_vs_svd,
            "helper_vs_independent_svd": helper_vs_svd,
        },
        "physical_convergence": "not_assessed",
    }


def self_test() -> dict[str, Any]:
    A = np.zeros((1, 2), dtype=np.float64)
    r = np.zeros(1, dtype=np.float64)
    lower = np.array([0.0, -np.inf])
    masked_violation = independent_kkt(A, r, lower, np.array([-1.0, 1.0e16]))
    require(not masked_violation["passed"], "self_test_masked_violation_not_detected", "large free coordinate")

    # A free coordinate may land exactly on its bound with zero gradient.  Its
    # contact classification need not equal the solver's working set.
    tie_A = np.array([[2.0, 1.0], [0.0, 1.0]])
    tie_r = np.array([-1.0, -1.0])
    tie_lower = np.zeros(2)
    tie_step = np.array([0.0, 1.0])
    tie_global = independent_kkt(tie_A, tie_r, tie_lower, tie_step)
    tie_working = independent_kkt(tie_A, tie_r, tie_lower, tie_step, [])
    require(
        tie_global["passed"] and tie_working["passed"] and tie_global["contact_indices"] == [1],
        "self_test_contact_working_set_error",
        "accidental bound contact",
    )

    raw_sparse = CoordinateMatrix(
        2,
        2,
        np.array([0, 0, 1], dtype=np.int64),
        np.array([0, 1, 1], dtype=np.int64),
        np.array([2.0, 0.0, 3.0]),
    )
    # Reordered nonzeros, the raw explicit zero dropped, and an extra stored
    # zero all represent the same mathematical sparse matrix.
    scaled_sparse = CoordinateMatrix(
        2,
        2,
        np.array([1, 1, 0], dtype=np.int64),
        np.array([1, 0, 0], dtype=np.int64),
        np.array([12.0, 0.0, 4.0]),
    )
    sparse_check = compare_scaled_coordinate_matrices(
        raw_sparse, scaled_sparse, np.array([2.0, 3.0]), np.array([4.0, 12.0])
    )
    require(sparse_check["passed"], "self_test_sparse_zero_equivalence_error", json.dumps(sparse_check))
    missing_nonzero_detected = False
    try:
        compare_scaled_coordinate_matrices(
            raw_sparse,
            CoordinateMatrix(
                2,
                2,
                np.array([0], dtype=np.int64),
                np.array([0], dtype=np.int64),
                np.array([4.0]),
            ),
            np.array([2.0, 3.0]),
            np.array([4.0, 12.0]),
        )
    except AuditFailure as error:
        missing_nonzero_detected = error.code == "scaled_matrix_nonzero_sparsity_mismatch"
    require(missing_nonzero_detected, "self_test_missing_nonzero_not_detected", "sparse coordinate deletion")

    rank_deficient_A = np.array([[1.0, 1.0], [2.0, 2.0]])
    rank_deficient_r = np.array([-3.0, -6.0])
    rank_deficient_singular = np.linalg.svd(rank_deficient_A, compute_uv=False)
    nullspace_agreement = semantic_least_squares_agreement(
        rank_deficient_A,
        rank_deficient_r,
        np.array([1.5, 1.5]),
        np.array([3.0, 0.0]),
        1,
        rank_deficient_singular,
        "self_test_rank_deficient_nullspace",
    )
    require(
        nullspace_agreement["comparison"] == "fitted_vector_l2",
        "self_test_rank_deficient_comparison_error",
        repr(nullspace_agreement),
    )
    range_perturbation_detected = False
    try:
        semantic_least_squares_agreement(
            rank_deficient_A,
            rank_deficient_r,
            np.array([1.5, 1.5]),
            np.array([3.1, 0.0]),
            1,
            rank_deficient_singular,
            "self_test_rank_deficient_range_perturbation",
        )
    except AuditFailure as error:
        range_perturbation_detected = error.code == "unbounded_strict_stationarity_failure"
    require(range_perturbation_detected, "self_test_range_perturbation_not_detected", "rank-deficient range")
    large_nonstationary_detected = False
    large_A = 1.0e6 * np.eye(2)
    large_r = np.array([1.0e6, 1.0e6])
    try:
        semantic_least_squares_agreement(
            large_A,
            large_r,
            np.array([-1.0, -1.0]),
            np.array([-1.0 + EPS, -1.0]),
            2,
            np.linalg.svd(large_A, compute_uv=False),
            "self_test_large_nonstationary",
        )
    except AuditFailure as error:
        large_nonstationary_detected = error.code == "unbounded_strict_stationarity_failure"
    require(large_nonstationary_detected, "self_test_large_nonstationary_not_detected", "roundoff is diagnostic only")

    A2 = np.array([[1.0, 1.0], [0.0, 1.0]])
    r2 = np.array([-3.0, 1.0])
    lower2 = np.array([-np.inf, 0.0])
    solution = scipy_oracles(A2, r2, lower2)
    require(solution["bvls"]["audit"]["passed"], "self_test_bvls_kkt_error", "analytic case")
    require(
        np.linalg.norm(np.asarray(solution["bvls"]["step"]) - np.array([3.0, 0.0]), np.inf) <= 32.0 * EPS,
        "self_test_analytic_solution_error",
        repr(solution["bvls"]["step"]),
    )
    return {
        "schema": "bounded-step-independent-self-test-v1",
        "masked_coordinate_violation_detected": True,
        "contact_working_set_distinction_detected": True,
        "sparse_explicit_zero_drop_and_reorder_accepted": True,
        "sparse_missing_nonzero_detected": True,
        "rank_deficient_nullspace_semantics_accepted": True,
        "rank_deficient_range_perturbation_detected": True,
        "large_matrix_nonstationarity_detected": True,
        "analytic_solution": solution["bvls"]["step"],
        "strict_kkt_tolerance": KKT_ABSOLUTE_TOLERANCE,
        "physical_convergence": "not_assessed",
    }


def write_new_json(path: Path, value: Any) -> None:
    require(not path.exists(), "output_exists", str(path))
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")


def run_audit(repo_root: Path, snapshot_dir: Path, output_dir: Path) -> dict[str, Any]:
    require(repo_root.is_dir(), "repo_root_missing", str(repo_root))
    require(snapshot_dir.is_dir(), "snapshot_directory_missing", str(snapshot_dir))
    require(not output_dir.exists(), "output_exists", str(output_dir))
    output_dir.mkdir(parents=True)
    sources = expected_source_paths(repo_root)
    solver_input = read_json(sources["old_solver_input_sha256"])
    attempts = read_json(sources["old_attempts_sha256"])
    cases = []
    for update in EXPECTED_UPDATES:
        try:
            case = audit_case(
                update,
                snapshot_dir / f"n1_linear_input_{update}.json",
                snapshot_dir / f"n1_linear_result_{update}.json",
                repo_root,
                solver_input,
                attempts,
            )
            cases.append(case)
            write_new_json(output_dir / f"case_after_{update}.json", case)
        except AuditFailure as error:
            write_new_json(
                output_dir / f"case_after_{update}_failure.json",
                {
                    "schema": "n1-bounded-step-independent-case-failure-v1",
                    "after_accepted_updates": update,
                    "code": error.code,
                    "detail": error.detail,
                    "completed_prior_cases": [case["after_accepted_updates"] for case in cases],
                    "physical_convergence": "not_assessed",
                },
            )
            raise
    report = {
        "schema": "n1-bounded-step-independent-scipy-audit-v1",
        "program_state": "pass",
        "execution_classification": "process_completed",
        "numerical_scope": "three_saved_linearized_subproblems_only",
        "numerical_state": "strict_kkt_and_independent_scipy_oracles_pass",
        "nonlinear_solve": "not_executed",
        "physical_state": "unknown",
        "physical_convergence": "not_assessed",
        "formal_UP2_04_accepted": False,
        "resolution": "terminal_deferred",
        "python": platform.python_version(),
        "numpy": np.__version__,
        "scipy": scipy.__version__,
        "blas_threads": {
            name: os.environ.get(name)
            for name in ("OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "OMP_NUM_THREADS")
        },
        "oracle_sha256": sha256_file(Path(__file__)),
        "snapshot_directory": str(snapshot_dir),
        "cases": cases,
    }
    report_path = output_dir / "independent_bounded_step_report.json"
    write_new_json(report_path, report)
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("self-test")
    audit_parser = subparsers.add_parser("audit")
    audit_parser.add_argument("--repo-root", type=Path, required=True)
    audit_parser.add_argument("--snapshot-dir", type=Path, required=True)
    audit_parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "self-test":
            report = self_test()
        else:
            report = run_audit(args.repo_root.resolve(), args.snapshot_dir.resolve(), args.output_dir.resolve())
        print(json.dumps({
            "program_state": report.get("program_state", "pass"),
            "schema": report["schema"],
            "physical_convergence": report["physical_convergence"],
        }, sort_keys=True))
        return 0
    except AuditFailure as error:
        print(json.dumps({"program_state": "fail", "code": error.code, "detail": error.detail}, sort_keys=True), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
