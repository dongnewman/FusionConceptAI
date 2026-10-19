"""Compare in-house raw Q1 artifacts and Gridap metrics with SciPy direct Q1.

Input is a JSON export written by focused_tests.jl. This independent checker
rebuilds the same tensor-product Q1 form from the frozen mathematical
definition, then checks matrices, right-hand sides, the in-house PCG solution,
and both solvers' reported error/conservation metrics.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
from scipy.sparse import coo_matrix, csr_matrix

from independent_q1_oracle import (
    GRID_LEVELS,
    THRESHOLDS,
    run_frozen_series,
)


_METRIC_TOL = {
    "l2_error": 5.0e-8,
    "h1_seminorm_error": 5.0e-8,
    "assembled_source_integral": 1.0e-10,
    "analytic_source_integral": 1.0e-12,
    "source_integral_error": 1.0e-10,
    "analytic_outward_conormal_integral": 1.0e-12,
    "analytic_identity_defect": 1.0e-12,
    "discrete_boundary_reaction_integral": 1.0e-9,
    "discrete_boundary_reaction_balance_defect": 1.0e-9,
    "discrete_trace_conormal_integral": 1.0e-9,
    "discrete_trace_conormal_error": 1.0e-9,
}
_EXPECTED_CANDIDATE_REF = (
    "fusionconceptai://candidate/native-g1g2-diffusion-mms-v1")
_EXPECTED_CANDIDATE_VERSION = "v5"
_EXPECTED_SOLVER_SOURCE_SHA256 = (
    "bd8e60ff527c42723b2b38c28494761d33c30d9e2fb200c464fada926a4351bf")
_IDENTITY_HASH_FIELDS = (
    "t1_package_hash", "source_binding_hash", "plan_hash",
    "solver_input_hash", "protocol_hash", "solver_source_hash",
)


def _as_csr(row: dict, prefix: str, shape: tuple[int, int]) -> csr_matrix:
    rows = np.asarray(row[f"{prefix}rows"], dtype=np.int64) - 1
    columns = np.asarray(row[f"{prefix}columns"], dtype=np.int64) - 1
    values = np.asarray(row[f"{prefix}values"], dtype=np.float64)
    return coo_matrix((values, (rows, columns)), shape=shape).tocsr()


def _max_abs_sparse(matrix: csr_matrix) -> float:
    return 0.0 if matrix.nnz == 0 else float(np.max(np.abs(matrix.data)))


def _check_metrics(actual: dict, expected: dict, label: str) -> list[str]:
    failures: list[str] = []
    actual_counts = tuple(int(q) for q in actual["cell_counts"])
    expected_counts = tuple(int(q) for q in expected["cell_counts"])
    if actual_counts != expected_counts:
        failures.append(f"{label}:cell_counts")
        return failures
    t = THRESHOLDS
    if not (float(actual["residual_abs"]) <= t["residual_abs_tol"]
            or float(actual["residual_rel"]) <= t["residual_rel_tol"]):
        failures.append(f"{label}:residual_gate")
    if float(actual["boundary_linf"]) > t["boundary_abs_tol"]:
        failures.append(f"{label}:boundary_gate")
    if float(actual["source_integral_error"]) > t["source_integral_abs_tol"]:
        failures.append(f"{label}:source_integral_gate")
    if abs(float(actual["analytic_identity_defect"])) > t["analytic_identity_abs_tol"]:
        failures.append(f"{label}:analytic_identity_gate")
    if float(actual["discrete_interior_reaction_linf"]) > t["residual_abs_tol"]:
        failures.append(f"{label}:interior_reaction_gate")
    if abs(float(actual["discrete_boundary_reaction_balance_defect"])) > t["reaction_balance_abs_tol"]:
        failures.append(f"{label}:reaction_balance_gate")
    for name, atol in _METRIC_TOL.items():
        got = float(actual[name])
        want = float(expected[name])
        if not math.isfinite(got) or abs(got - want) > atol:
            failures.append(f"{label}:{name}_oracle_mismatch")
    if actual.get("status") not in (None, "pass"):
        failures.append(f"{label}:status_not_pass")
    if actual.get("errors") not in (None, []):
        failures.append(f"{label}:unexpected_error_classification")
    return failures


def _check_three_grid_report(report: dict, oracle: dict, name: str) -> list[str]:
    failures: list[str] = []
    levels = report["levels"]
    if len(levels) != 3:
        return [f"{name}:level_count"]
    for i, (actual, expected) in enumerate(zip(levels, oracle["levels"]), start=1):
        failures.extend(_check_metrics(actual, expected, f"{name}:level_{i}"))
    for label, order_field, bounds in (
        ("l2", "l2_orders", THRESHOLDS["l2_order_interval"]),
        ("h1", "h1_orders", THRESHOLDS["h1_order_interval"]),
    ):
        orders = tuple(float(q) for q in report[order_field])
        expected_orders = tuple(float(q) for q in oracle[order_field])
        if len(orders) != 2:
            failures.append(f"{name}:{label}_order_count")
            continue
        if any(not bounds[0] <= q <= bounds[1] for q in orders):
            failures.append(f"{name}:{label}_order_gate")
        if any(abs(a - b) > 5.0e-6 for a, b in zip(orders, expected_orders)):
            failures.append(f"{name}:{label}_order_oracle_mismatch")
    if float(levels[2]["l2_error"]) > THRESHOLDS["finest_l2_max"]:
        failures.append(f"{name}:finest_l2_gate")
    if float(levels[2]["h1_seminorm_error"]) > THRESHOLDS["finest_h1_seminorm_max"]:
        failures.append(f"{name}:finest_h1_gate")
    if report.get("status") != "pass":
        failures.append(f"{name}:report_status")
    if report.get("errors") not in (None, []):
        failures.append(f"{name}:report_error_classification")
    if report.get("resolution") not in (None, "terminal_deferred"):
        failures.append(f"{name}:resolution_overclaim")
    if report.get("accepted") not in (None, False):
        failures.append(f"{name}:acceptance_overclaim")
    if report.get("claim_ceiling") not in (None, "screen_only"):
        failures.append(f"{name}:claim_ceiling_overclaim")
    return failures


def _check_inhouse_identity(identity: dict, plan_identity: dict) -> list[str]:
    failures: list[str] = []
    identity_fields = (
        "candidate_ref", "candidate_version", *_IDENTITY_HASH_FIELDS)
    if not isinstance(identity, dict) or not isinstance(plan_identity, dict):
        return ["inhouse:identity_shape"]
    for field in identity_fields:
        if identity.get(field) != plan_identity.get(field):
            failures.append(f"inhouse:report_plan_{field}_mismatch")
    if identity.get("candidate_ref") != _EXPECTED_CANDIDATE_REF:
        failures.append("inhouse:candidate_ref_not_frozen_fixture")
    if identity.get("candidate_version") != _EXPECTED_CANDIDATE_VERSION:
        failures.append("inhouse:candidate_version_not_frozen_fixture")
    for field in (*_IDENTITY_HASH_FIELDS, "report_hash"):
        digest = identity.get(field, "")
        if (not isinstance(digest, str) or len(digest) != 64
                or any(char not in "0123456789abcdef" for char in digest)):
            failures.append(f"inhouse:{field}_malformed")
    if identity.get("solver_source_hash") != _EXPECTED_SOLVER_SOURCE_SHA256:
        failures.append("inhouse:solver_source_not_frozen_sha256")
    return failures


def _check_inhouse_raw(actual: dict, raw: dict, label: str) -> list[str]:
    failures: list[str] = []
    free = np.asarray(actual["free_dof_ids"], dtype=np.int64)
    boundary = np.asarray(actual["boundary_dof_ids"], dtype=np.int64)
    if not np.array_equal(free, np.asarray(raw["free_dof_ids"], dtype=np.int64)):
        failures.append(f"{label}:free_dof_map")
    if not np.array_equal(boundary, np.asarray(raw["boundary_dof_ids"], dtype=np.int64)):
        failures.append(f"{label}:boundary_dof_map")

    full_nodes = len(actual["full_solution_values"])
    counts = tuple(int(q) for q in actual["cell_counts"])
    if full_nodes != math.prod(q + 1 for q in counts):
        failures.append(f"{label}:full_node_count")
    if len(free) != math.prod(q - 1 for q in counts):
        failures.append(f"{label}:free_dof_count")
    if len(boundary) != full_nodes - len(free):
        failures.append(f"{label}:boundary_dof_count")
    if (len(np.unique(free)) != len(free)
            or len(np.unique(boundary)) != len(boundary)
            or not np.array_equal(np.sort(np.concatenate((free, boundary))),
                                  np.arange(1, full_nodes + 1))):
        failures.append(f"{label}:dof_partition_not_exact")

    nx, ny, nz = counts
    expected_boundary = []
    expected_free = []
    for k in range(nz + 1):
        for j in range(ny + 1):
            for i in range(nx + 1):
                dof = 1 + i + (nx + 1) * (j + (ny + 1) * k)
                (expected_boundary if i in (0, nx) or j in (0, ny)
                 or k in (0, nz) else expected_free).append(dof)
    if not np.array_equal(free, np.asarray(expected_free, dtype=np.int64)):
        failures.append(f"{label}:free_ids_not_interior_nodes")
    if not np.array_equal(boundary, np.asarray(expected_boundary, dtype=np.int64)):
        failures.append(f"{label}:boundary_ids_not_face_nodes")

    full_shape = (full_nodes, full_nodes)
    actual_full = _as_csr(actual, "full_matrix_", full_shape)
    expected_full = _as_csr(raw, "full_matrix_", full_shape)
    if (not np.all(np.isfinite(actual_full.data))
            or not np.all(np.isfinite(expected_full.data))):
        failures.append(f"{label}:nonfinite_full_matrix")
    if actual_full.shape != expected_full.shape or _max_abs_sparse(actual_full - expected_full) > 2.0e-11:
        failures.append(f"{label}:full_matrix_mismatch")

    reduced_shape = tuple(int(q) for q in actual["matrix_shape"])
    actual_free = _as_csr(actual, "matrix_", reduced_shape)
    expected_free = _as_csr(raw, "matrix_", reduced_shape)
    if (not np.all(np.isfinite(actual_free.data))
            or not np.all(np.isfinite(expected_free.data))):
        failures.append(f"{label}:nonfinite_free_matrix")
    if actual_free.shape != expected_free.shape or _max_abs_sparse(actual_free - expected_free) > 2.0e-11:
        failures.append(f"{label}:free_matrix_mismatch")
    sliced_full = actual_full[free - 1][:, free - 1].tocsr()
    if _max_abs_sparse(actual_free - sliced_full) > 2.0e-11:
        failures.append(f"{label}:free_matrix_not_full_matrix_slice")

    for name in ("full_rhs_values", "rhs_values"):
        got = np.asarray(actual[name], dtype=np.float64)
        want = np.asarray(raw[name], dtype=np.float64)
        if got.shape != want.shape or not np.allclose(got, want, atol=2.0e-11, rtol=2.0e-12):
            failures.append(f"{label}:{name}_mismatch")
    full_rhs = np.asarray(actual["full_rhs_values"], dtype=np.float64)
    if not np.allclose(np.asarray(actual["rhs_values"], dtype=np.float64),
                       full_rhs[free - 1], atol=2.0e-11, rtol=2.0e-12):
        failures.append(f"{label}:free_rhs_not_full_rhs_slice")
    if (len(actual["solution_values"]) != len(free)
            or len(actual["full_solution_values"]) != full_nodes
            or not np.allclose(
                np.asarray(actual["solution_values"], dtype=np.float64),
                np.asarray(actual["full_solution_values"], dtype=np.float64)[free - 1],
                atol=2.0e-12, rtol=2.0e-12)):
        failures.append(f"{label}:solution_partition_mismatch")

    # The independent direct solve supplies a stronger replay oracle than the
    # in-house convergence flag; the iterative solution is allowed the exact
    # frozen residual budget translated through this fixed discrete matrix.
    got_x = np.asarray(actual["full_solution_values"], dtype=np.float64)
    want_x = np.asarray(raw["full_solution_values"], dtype=np.float64)
    if got_x.shape != want_x.shape or not np.allclose(got_x, want_x, atol=1.0e-7, rtol=2.0e-8):
        failures.append(f"{label}:full_solution_direct_replay_mismatch")

    got_rhs = np.asarray(actual["rhs_values"], dtype=np.float64)
    got_free_x = np.asarray(actual["solution_values"], dtype=np.float64)
    replay_residual = actual_free @ got_free_x - got_rhs
    replay_abs = float(np.linalg.norm(replay_residual, ord=np.inf))
    replay_rel = replay_abs / max(float(np.linalg.norm(got_rhs, ord=np.inf)), np.finfo(float).eps)
    if abs(replay_abs - float(actual["residual_abs"])) > 1.0e-12:
        failures.append(f"{label}:reported_abs_residual_mismatch")
    if abs(replay_rel - float(actual["residual_rel"])) > 1.0e-12:
        failures.append(f"{label}:reported_rel_residual_mismatch")
    if abs(float(np.linalg.norm(got_rhs, ord=np.inf))
           - float(actual["rhs_norm_inf"])) > 1.0e-12:
        failures.append(f"{label}:reported_rhs_norm_mismatch")
    if not (replay_abs <= THRESHOLDS["residual_abs_tol"]
            or replay_rel <= THRESHOLDS["residual_rel_tol"]):
        failures.append(f"{label}:raw_replayed_residual_gate")
    full_reaction = actual_full @ got_x - np.asarray(actual["full_rhs_values"], dtype=np.float64)
    interior = full_reaction[free - 1]
    boundary_reaction = full_reaction[boundary - 1]
    reaction_balance = float(actual["assembled_source_integral"]
                             + np.sum(boundary_reaction))
    if abs(reaction_balance - float(actual["discrete_boundary_reaction_balance_defect"])) > 1.0e-12:
        failures.append(f"{label}:raw_boundary_reaction_mismatch")
    if abs(float(actual["assembled_source_integral"])
           - float(np.sum(full_rhs))) > 2.0e-10:
        failures.append(f"{label}:source_integral_rhs_mismatch")
    if abs(float(np.sum(boundary_reaction))
           - float(actual["discrete_boundary_reaction_integral"])) > 1.0e-12:
        failures.append(f"{label}:raw_boundary_reaction_integral_mismatch")
    if abs(float(np.linalg.norm(interior, ord=np.inf))
           - float(actual["discrete_interior_reaction_linf"])) > 1.0e-12:
        failures.append(f"{label}:raw_interior_reaction_linf_mismatch")
    if abs(float(np.sum(interior))
           - float(actual["discrete_interior_reaction_sum"])) > 1.0e-12:
        failures.append(f"{label}:raw_interior_reaction_sum_mismatch")
    if float(np.linalg.norm(interior, ord=np.inf)) > THRESHOLDS["residual_abs_tol"]:
        failures.append(f"{label}:raw_interior_reaction_gate")
    if np.max(np.abs(got_x[boundary - 1])) > THRESHOLDS["boundary_abs_tol"]:
        failures.append(f"{label}:raw_dirichlet_boundary_gate")
    return failures


def verify(path: Path, backends: tuple[str, ...] = ("inhouse",)) -> tuple[str, ...]:
    produced = json.loads(path.read_text(encoding="utf-8"))
    oracle = run_frozen_series(include_raw=True)
    failures: list[str] = []
    if tuple(tuple(q) for q in produced.get("grid_levels", ())) != GRID_LEVELS:
        failures.append("grid_level_manifest_mismatch")
    for name in backends:
        if name not in produced:
            failures.append(f"{name}:report_missing")
            continue
        failures.extend(_check_three_grid_report(produced[name], oracle, name))
    if "inhouse" in backends and "inhouse" in produced:
        identity = produced["inhouse"].get("identity", {})
        failures.extend(_check_inhouse_identity(
            identity, produced["inhouse"].get("plan_identity", {})))
    if "inhouse" in produced:
        for i, (actual, expected, raw) in enumerate(zip(
                produced["inhouse"]["levels"], oracle["levels"],
                oracle["raw_levels"]), start=1):
            failures.extend(_check_inhouse_raw(actual, raw, f"inhouse:raw_{i}"))
    return tuple(failures)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("production_json", type=Path)
    parser.add_argument("--backends", nargs="+", choices=("inhouse", "gridap"),
                        default=("inhouse",),
                        help="reports to compare; first serial run is inhouse only")
    args = parser.parse_args()
    failures = verify(args.production_json, tuple(args.backends))
    if failures:
        print("INDEPENDENT_RAW_CROSSCHECK=NO_GO failures=" + ",".join(failures))
        return 2
    print("INDEPENDENT_RAW_CROSSCHECK=GO grids=3 backends=" +
          ",".join(args.backends))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
