"""Independent dense SciPy + exhaustive working-set oracles for small steps.

This does not call or translate the Julia active-set algorithm. Rank-deficient
answers are compared by fitted residual/objective and KKT, not a unique vector.
Run `generate FILE` before the separately authorized Julia unit test, or
`compare SNAPSHOT_AND_RESULT.json REPORT.json` for an actual production snapshot.
Neither oracle success nor Julia success certifies nonlinear/physical recovery.
"""
from __future__ import annotations

import argparse
import csv
import re
import hashlib
import itertools
import json
import platform
from pathlib import Path
import time

import numpy as np
import scipy
from scipy.optimize import linprog, lsq_linear
from scipy.sparse import coo_matrix, csr_matrix, hstack, vstack


def kkt(A, r, lower, x):
    q = A.T @ (A @ x + r)
    finite = np.isfinite(lower)
    bound_tolerance = 8 * np.finfo(float).eps * np.maximum(1, np.maximum(np.abs(x), np.abs(np.where(finite, lower, 0))))
    active = finite & (np.abs(x - np.where(finite, lower, 0)) <= bound_tolerance)
    primal = float(np.max(np.maximum(lower[finite] - x[finite], 0), initial=0))
    free = float(np.max(np.abs(q[~active]), initial=0))
    dual = float(np.max(np.maximum(-q[active], 0), initial=0))
    return {"primal_violation": primal, "free_stationarity": free,
            "lower_dual_violation": dual, "absolute_kkt_tolerance": 1e-10,
            "passed": bool(np.all(x[finite] >= lower[finite] - bound_tolerance[finite])) and max(free, dual) <= 1e-10}


def exhaustive(A, r, lower):
    """Enumerate faces and solve each reduced dense SVD problem independently."""
    constrained = np.flatnonzero(np.isfinite(lower))
    if len(constrained) > 12:
        return {"status": "not_executed_too_many_faces"}
    best = None
    for flags in itertools.product([False, True], repeat=len(constrained)):
        active = constrained[np.array(flags, dtype=bool)]
        free = np.setdiff1d(np.arange(A.shape[1]), active)
        x = np.zeros(A.shape[1]); x[active] = lower[active]
        if len(free):
            x[free] = np.linalg.lstsq(A[:, free], -r - A[:, active] @ x[active], rcond=1e-13)[0]
        if np.any(x < lower - 1e-10):
            continue
        audit = kkt(A, r, lower, x)
        objective = float(np.linalg.norm(A @ x + r) ** 2 / 2)
        if audit["passed"] and (best is None or objective < best["objective"]):
            best = {"status": "kkt_face_found", "objective": objective,
                    "step": x.tolist(), "kkt": audit, "active_face": (active + 1).tolist()}
    if best is None:
        raise AssertionError("exhaustive oracle found no feasible KKT face")
    return best


def solve_case(A, r, lower):
    bvls = lsq_linear(A, -r, bounds=(lower, np.inf), method="bvls", tol=1e-12, max_iter=1000)
    trf = lsq_linear(A, -r, bounds=(lower, np.inf), method="trf", tol=1e-12, max_iter=1000)
    audit = kkt(A, r, lower, bvls.x)
    # Do not substitute SciPy's success flag for measured KKT.
    assert audit["passed"], (bvls.message, audit)
    exact = exhaustive(A, r, lower)
    assert abs(bvls.cost - trf.cost) <= 1e-10 * max(1, bvls.cost)
    if exact["status"] == "kkt_face_found":
        assert abs(bvls.cost - exact["objective"]) <= 1e-10 * max(1, bvls.cost)
    return {"bvls_step": bvls.x.tolist(), "objective": float(bvls.cost),
            "bvls_status": int(bvls.status), "bvls_kkt": audit,
            "trf_objective": float(trf.cost), "trf_status": int(trf.status),
            "exhaustive": exact, "matrix_rank": int(np.linalg.matrix_rank(A))}


def solve_residual_band(input_metadata_path: Path, ray_vectors_path: Path,
                        ray_result_path: Path) -> dict:
    """One sparse original-residual band LP for an existing saved Q1 state.

    This is a local affine diagnostic only. It does not change or certify the
    original nonlinear system, line search, or scientific acceptance.
    """
    metadata_raw = input_metadata_path.read_bytes()
    ray_vectors_raw = ray_vectors_path.read_bytes()
    ray_result_raw = ray_result_path.read_bytes()
    metadata = json.loads(metadata_raw)
    ray_vectors = json.loads(ray_vectors_raw)
    ray_result = json.loads(ray_result_raw)
    def require(ok, message):
        if not ok:
            raise ValueError(message)

    require(ray_vectors.get("scope") == "diagnostic_only_original_scaled_row_order" and
            ray_result.get("scope") == "single_original_operator_quartic_ray_diagnostic",
            "saved ray vector scope mismatch")
    require(metadata.get("schema") == "bounded-step-saved-q1-8-input-v1",
            "input is not the existing final12 Q1 saved metadata")
    m, n = int(metadata["rows"]), int(metadata["columns"])
    require((m, n) == (2337, 2080) and metadata.get("full_state_columns") == 2080,
            "saved final12 Q1 dimensions differ from 2337x2080")
    require(metadata.get("pressure_only") is False and metadata.get("projection_compare") is True and
            metadata.get("solve_column_map") == list(range(1, n + 1)),
            "saved metadata is not the full identity-ordered Q1 system")
    require(metadata.get("row_scaling") == "divide_by_residual_rows_declared_scale" and
            metadata.get("lower_bound_rule") == "pressure_step_minus_current_pressure",
            "saved Q1 scaling or pressure-bound rule mismatch")
    source_dir = Path(metadata["production_dir"])
    state_path = source_dir / "solver_state.csv"
    residual_path = source_dir / "residual_rows.csv"
    jacobian_path = source_dir / "global_weak_jacobian.csv"
    expected_hashes = metadata.get("source_sha256")
    require(isinstance(expected_hashes, dict), "saved metadata lacks production input hashes")
    def file_sha256(path):
        h = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                h.update(chunk)
        return h.hexdigest()
    input_hashes = {"state": file_sha256(state_path), "residual": file_sha256(residual_path),
                    "jacobian": file_sha256(jacobian_path)}
    require(all(input_hashes[k] == str(expected_hashes.get(k, "")).lower()
                for k in input_hashes), "final12 production CSV hash differs from saved metadata")
    def csv_rows(path, header):
        with path.open("r", newline="", encoding="utf-8") as stream:
            reader = csv.DictReader(stream)
            require(reader.fieldnames == header, f"unexpected production CSV header: {path.name}")
            return list(reader)
    state_rows = csv_rows(state_path, ["node_id", "BR_T", "Bphi_T", "BZ_T", "p_Pa"])
    require(len(state_rows) == 520, "final12 production state must contain 520 ordered nodes")
    state = np.empty(n, dtype=np.float64)
    for node, row in enumerate(state_rows, start=1):
        require(int(row["node_id"]) == node, "production state node order is not canonical")
        state[4 * (node - 1):4 * node] = [float(row[k]) for k in ("BR_T", "Bphi_T", "BZ_T", "p_Pa")]
    column_scales = np.asarray(metadata["column_scales"], dtype=np.float64)
    require(column_scales.shape == (n,) and np.all(np.isfinite(column_scales)) and
            np.array_equal(column_scales, np.tile([5.0, 5.0, 5.0, 1.0e5], 520)),
            "final12 field/pressure layout differs from [BR,Bphi,BZ,p]")
    require(np.all(np.isfinite(state)) and np.all(state[3::4] >= 0.0),
            "final12 state is nonfinite or pressure-infeasible")
    residual_rows = csv_rows(residual_path, ["row", "block", "residual", "declared_scale"])
    require(len(residual_rows) == m, "final12 residual row count mismatch")
    raw_r = np.empty(m, dtype=np.float64)
    row_scales = np.empty(m, dtype=np.float64)
    for row_id, row in enumerate(residual_rows, start=1):
        require(int(row["row"]) == row_id, "production residual row order is not canonical")
        raw_r[row_id - 1] = float(row["residual"])
        row_scales[row_id - 1] = float(row["declared_scale"])
    require(np.all(np.isfinite(raw_r)) and np.all(np.isfinite(row_scales)) and np.all(row_scales > 0.0),
            "final12 residual or row scales are invalid")
    r = raw_r / row_scales
    lower = np.full(n, -np.inf, dtype=np.float64)
    lower[3::4] = -state[3::4] / column_scales[3::4]
    require(np.all(np.isfinite(r)) and np.all(np.isfinite(lower[3::4])),
            "normalized final12 residual or pressure bounds are nonfinite")
    matrix_rows = csv_rows(jacobian_path, ["row", "column", "value"])
    require(len(matrix_rows) == int(metadata["nnz"]), "final12 Jacobian nnz differs from metadata")
    rows = np.empty(len(matrix_rows), dtype=np.int64)
    columns = np.empty(len(matrix_rows), dtype=np.int64)
    values = np.empty(len(matrix_rows), dtype=np.float64)
    for k, entry in enumerate(matrix_rows):
        rows[k], columns[k], values[k] = int(entry["row"]), int(entry["column"]), float(entry["value"])
    require(np.all((1 <= rows) & (rows <= m)) and np.all((1 <= columns) & (columns <= n)) and
            np.all(np.isfinite(values)), "final12 sparse Jacobian has invalid coordinates")
    J = coo_matrix((values, (rows - 1, columns - 1)), shape=(m, n), dtype=np.float64).tocsr()
    J.sum_duplicates()
    require(J.nnz == len(values), "final12 sparse Jacobian has duplicate or explicit-zero coordinates")
    A = J.multiply(column_scales).multiply(1.0 / row_scales[:, None]).tocsr()
    A.sum_duplicates()
    require(np.all(np.isfinite(A.data)), "scaled final12 sparse Jacobian is nonfinite")
    primary_path = source_dir / "global_weak_primary.json"
    require(Path(ray_result["current_primary_path"]).resolve() == primary_path.resolve(),
            "ray result and saved production metadata refer to different primary results")
    primary_hash = file_sha256(primary_path)
    require(primary_hash == str(ray_result["current_primary_sha256"]).lower(),
            "final12 primary result hash differs from the ray's bound primary")
    with primary_path.open("rb") as stream:
        primary_head = stream.read(4096)
    update_match = re.search(rb'"accepted_update_count"\s*:\s*(\d+)', primary_head)
    require(update_match is not None, "final12 primary lacks accepted update count")
    state_before_iteration = int(update_match.group(1))
    require(state_before_iteration == 12, "bound primary is not the final12 saved state")

    alpha = float(ray_result["alpha"])
    raw_step = np.asarray(ray_vectors["effective_scaled_step"], dtype=np.float64)
    ray_r = np.asarray(ray_vectors["baseline_residual"], dtype=np.float64)
    ray_linear = np.asarray(ray_vectors["linear_increment"], dtype=np.float64)
    ray_state = np.asarray(ray_vectors["ray_state"], dtype=np.float64)
    require(np.isfinite(alpha) and 0.0 < alpha <= 1.0, "saved ray alpha is invalid")
    require(raw_step.shape == (n,) and ray_r.shape == (m,) and ray_linear.shape == (m,) and
            ray_state.shape == (n,),
            "saved ray vector dimensions mismatch")
    require(np.all(np.isfinite(raw_step)) and np.all(np.isfinite(ray_r)) and
            np.all(np.isfinite(ray_linear)) and np.all(np.isfinite(ray_state)),
            "saved ray vectors are nonfinite")
    require(np.allclose(r, ray_r, rtol=0.0, atol=2.0e-9),
            "saved ray baseline differs from sparse linear input")
    require(np.allclose(A @ raw_step, ray_linear, rtol=0.0, atol=2.0e-9),
            "saved ray linear increment differs from sparse Jacobian")
    dref = alpha * raw_step
    require(np.allclose(state + column_scales * dref, ray_state, rtol=2.0e-12, atol=2.0e-8),
            "final12 production state does not match the ray endpoint identity")
    delta = float(np.max(np.abs(dref)))
    sigma = float(np.max(np.abs(r)))
    require(np.isfinite(delta) and delta > 0.0 and np.isfinite(sigma) and sigma > 0.0,
            "saved trust scale or original residual scale is invalid")
    g = np.asarray(A.T @ r, dtype=np.float64).reshape(-1)
    g_l1 = float(np.linalg.norm(g, ord=1))
    require(np.all(np.isfinite(g)) and np.isfinite(g_l1) and g_l1 > 0.0,
            "original scaled gradient is invalid")
    lower_s = np.maximum(lower, -delta)
    require(np.all(dref >= lower_s - 1.0e-10 * max(1.0, delta)) and
            np.all(dref <= delta + 1.0e-10 * max(1.0, delta)),
            "alpha-scaled reference step is outside trust or final12 pressure bounds")
    descent_limit = float(np.dot(g, dref))
    require(np.isfinite(descent_limit) and descent_limit < 0.0,
            "reference step does not define a finite descent half-space")
    reference_band = float(np.max(np.abs(r + A @ dref)) / sigma)
    require(np.isfinite(reference_band), "reference LP band is nonfinite")

    # Variables are (u,tau), with s=delta*u. Both residual bands are sparse.
    matrix_scale = delta / sigma
    require(np.isfinite(matrix_scale) and matrix_scale > 0.0,
            "normalized sparse matrix scale is invalid")
    scaled_A = A * matrix_scale
    require(np.all(np.isfinite(scaled_A.data)), "scaled sparse LP matrix overflowed")
    normalized_r = r / sigma
    require(np.all(np.isfinite(normalized_r)), "normalized residual coefficients are nonfinite")
    ones = csr_matrix(-np.ones((m, 1), dtype=np.float64))
    positive = hstack((scaled_A, ones), format="csr")
    negative = hstack((-scaled_A, ones), format="csr")
    normalized_gradient = g / g_l1
    require(np.all(np.isfinite(normalized_gradient)), "normalized descent coefficients are nonfinite")
    descent = hstack((csr_matrix(normalized_gradient.reshape(1, -1)),
                      csr_matrix((1, 1))), format="csr")
    A_ub = vstack((positive, negative, descent), format="csr")
    descent_scale = delta * g_l1
    require(np.isfinite(descent_scale) and descent_scale > 0.0,
            "normalized descent scale is invalid")
    descent_rhs = descent_limit / descent_scale
    require(np.isfinite(descent_rhs), "normalized descent right-hand side is nonfinite")
    b_ub = np.concatenate((-normalized_r, normalized_r, np.asarray([descent_rhs])))
    require(np.all(np.isfinite(b_ub)), "normalized inequality coefficients are nonfinite")
    bounds_u = np.maximum(lower_s, -delta) / delta
    require(not np.any(np.isnan(bounds_u)) and np.all(np.isfinite(bounds_u) | np.isneginf(bounds_u)),
            "normalized variable bounds are invalid")
    bounds = list(zip(bounds_u.tolist(), np.ones(n).tolist())) + [(0.0, None)]
    objective = np.zeros(n + 1, dtype=np.float64)
    objective[-1] = 1.0
    started = time.perf_counter()
    solved = linprog(objective, A_ub=A_ub, b_ub=b_ub, bounds=bounds,
                     method="highs-ds", options={
                         "time_limit": 6.0,
                         "primal_feasibility_tolerance": 1.0e-10,
                         "dual_feasibility_tolerance": 1.0e-10,
                         "threads": 1,
                     })
    elapsed = time.perf_counter() - started
    audit = {"computed": False, "passed": False, "absolute_tolerance": 1.0e-10}
    vectors = None
    if solved.success and solved.x is not None and np.all(np.isfinite(solved.x)):
        u = np.asarray(solved.x[:-1], dtype=np.float64)
        tau = float(solved.x[-1])
        s = delta * u
        residual_model = r + A @ s
        inequality_slack = b_ub - A_ub @ solved.x
        primal_rows = float(np.max(np.maximum(-inequality_slack, 0.0), initial=0.0))
        primal_bounds = float(max(np.max(np.maximum(bounds_u-u, 0.0), initial=0.0),
                                  np.max(np.maximum(u-1.0, 0.0), initial=0.0),
                                  max(-tau, 0.0)))
        dual_ineq = np.asarray(solved.ineqlin.marginals, dtype=np.float64)
        dual_lower = np.asarray(solved.lower.marginals, dtype=np.float64)
        dual_upper = np.asarray(solved.upper.marginals, dtype=np.float64)
        stationarity = objective - np.asarray(A_ub.T @ dual_ineq).reshape(-1) - dual_lower - dual_upper
        stationarity_inf = float(np.max(np.abs(stationarity), initial=0.0))
        dual_sign = float(max(np.max(np.maximum(dual_ineq, 0.0), initial=0.0),
                              np.max(np.maximum(-dual_lower, 0.0), initial=0.0),
                              np.max(np.maximum(dual_upper, 0.0), initial=0.0)))
        comp_ineq = float(np.max(np.abs(dual_ineq * inequality_slack), initial=0.0))
        lo_finite = np.isfinite(np.asarray([b[0] for b in bounds], dtype=np.float64))
        hi_finite = np.isfinite(np.asarray([b[1] for b in bounds], dtype=np.float64))
        bound_slack = np.asarray(solved.x, dtype=np.float64)
        lo = np.asarray([0.0 if b[0] is None else b[0] for b in bounds], dtype=np.float64)
        hi = np.asarray([0.0 if b[1] is None else b[1] for b in bounds], dtype=np.float64)
        comp_lower = float(np.max(np.abs(dual_lower[lo_finite] *
                                         (bound_slack[lo_finite] - lo[lo_finite])), initial=0.0))
        comp_upper = float(np.max(np.abs(dual_upper[hi_finite] *
                                         (hi[hi_finite] - bound_slack[hi_finite])), initial=0.0))
        dual_objective = float(np.dot(b_ub, dual_ineq) +
            np.dot(lo[lo_finite], dual_lower[lo_finite]) +
            np.dot(hi[hi_finite], dual_upper[hi_finite]))
        primal_objective = float(np.dot(objective, solved.x))
        objective_gap = float(primal_objective - dual_objective)
        stationarity_scale = float(np.max(np.asarray(objective +
            np.abs(A_ub.T) @ np.abs(dual_ineq)).reshape(-1), initial=0.0) +
            np.max(np.abs(dual_lower), initial=0.0) +
            np.max(np.abs(dual_upper), initial=0.0))
        dual_objective_scale = float(np.dot(np.abs(b_ub), np.abs(dual_ineq)) +
            np.dot(np.abs(lo[lo_finite]), np.abs(dual_lower[lo_finite])) +
            np.dot(np.abs(hi[hi_finite]), np.abs(dual_upper[hi_finite])))
        roundoff = float(64.0 * np.finfo(float).eps * max(1.0, abs(primal_objective),
            abs(dual_objective), stationarity_scale, dual_objective_scale,
            comp_ineq, comp_lower, comp_upper))
        kkt_passed = bool(max(primal_rows, primal_bounds, stationarity_inf, dual_sign,
                              comp_ineq, comp_lower, comp_upper, abs(objective_gap)) <=
                          1.0e-10 + roundoff)
        original_residual = np.asarray(r + A @ s, dtype=np.float64)
        vectors = {"u": u.tolist(), "s_scaled": s.tolist(), "tau": tau,
                   "linear_residual": original_residual.tolist(),
                   "linear_residual_inf": float(np.max(np.abs(original_residual), initial=0.0)),
                   "original_residual_gate": 1.0e-6,
                   "linear_gate_predicted": bool(np.max(np.abs(original_residual), initial=0.0) <= 1.0e-6),
                   "inequality_marginals": dual_ineq.tolist(),
                   "lower_bound_marginals": dual_lower.tolist(),
                   "upper_bound_marginals": dual_upper.tolist()}
        audit = {"computed": True, "passed": kkt_passed, "absolute_tolerance": 1.0e-10,
            "roundoff_allowance": roundoff, "max_primal_inequality_violation": primal_rows,
            "max_primal_variable_bound_violation": primal_bounds,
            "stationarity_inf": stationarity_inf, "dual_sign_violation": dual_sign,
            "inequality_complementarity_inf": comp_ineq,
            "lower_complementarity_inf": comp_lower, "upper_complementarity_inf": comp_upper,
            "primal_objective": primal_objective, "dual_objective": dual_objective,
            "absolute_objective_gap": abs(objective_gap)}
    result = {"schema": "saved-q1-original-residual-band-lp-diagnostic-v1",
        "scope": "one_sparse_affine_saved_state_direction_only_not_nonlinear_acceptance",
        "solver": "scipy.optimize.linprog/highs-ds", "scipy": scipy.__version__,
        "status": int(solved.status), "message": str(solved.message),
        "success": bool(solved.success), "elapsed_seconds": elapsed,
        "time_limit_seconds": 6.0, "thread_limit": 1,
        "primal_feasibility_tolerance": 1.0e-10, "dual_feasibility_tolerance": 1.0e-10,
        "rows": m, "columns": n, "sparse_nnz_after_duplicate_sum": int(A.nnz),
        "input_metadata_sha256": hashlib.sha256(metadata_raw).hexdigest(),
        "production_input_sha256": input_hashes, "current_primary_sha256": primary_hash,
        "ray_vectors_sha256": hashlib.sha256(ray_vectors_raw).hexdigest(),
        "ray_result_sha256": hashlib.sha256(ray_result_raw).hexdigest(),
        "state_before_iteration": state_before_iteration,
        "column_layout": "BR_T,Bphi_T,BZ_T,p_Pa_per_node; pressure_columns_4_mod_4",
        "alpha": alpha, "trust_radius_inf": delta, "original_residual_inf": sigma,
        "reference_descent_dot": descent_limit, "reference_linear_band_tau": reference_band,
        "reference_step": dref.tolist(), "audit": audit, "vectors": vectors,
        "nonlinear_endpoint_evaluated": False, "original_armijo_evaluated": False,
        "global_infeasibility_established": False, "formal_acceptance": False}
    return result


def named_cases():
    yield "review_counterexample", [[1, 1], [0, 1]], [-3, 1], [None, 0]
    yield "release_from_zero", [[1, 0], [0, 1]], [-2, -3], [0, 0]
    yield "nonzero_active_rhs", [[1, 1], [0, 1]], [-3, 3], [None, -0.5]
    yield "rank_deficient", [[1, 1], [2, 2]], [-3, -6], [0, 0]
    yield "rank_deficient_at_bound", [[1, 1], [2, 2]], [1, 2], [0, 0]
    yield "zero_matrix", [[0, 0], [0, 0], [0, 0]], [-1, 2, -3], [0, -0.25]
    yield "zero_column", [[1, 0], [2, 0], [3, 0]], [-2, -4, -6], [None, 0]
    yield "underdetermined", [[1, 1, 0], [0, 1, 1]], [-3, -2], [None, 0, -0.1]
    yield "simultaneous_hits", [[1, 0], [0, 1]], [2, 2], [-0.5, -0.5]
    yield "unbounded_free", [[2, -1], [1, 3], [0, 1]], [2, -4, 1], [None, None]
    yield "bind_then_release_after_qr_downdate", [[2, 0, 0], [0, 1, 0], [0, 0, 1]], [2, 0, -1], [-0.5, None, 0]
    rng = np.random.default_rng(22092026)
    for index in range(64):
        n = 2 + index % 6; m = n + 3
        A = rng.normal(size=(m, n)); r = rng.normal(size=m)
        if index % 7 == 0:
            A[:, -1] = A[:, 0]
        lower = [None if j % 3 == 0 else (0.0 if index % 2 else -float(rng.uniform(.05, 1.5))) for j in range(n)]
        yield f"seeded_{index:02d}", A.tolist(), r.tolist(), lower


def save(path, result):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        raise FileExistsError(f"retain existing evidence: {path}")
    path.write_text(json.dumps(result, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["generate", "compare", "residual-band"])
    parser.add_argument("input_or_output", type=Path)
    parser.add_argument("report", type=Path, nargs="?")
    parser.add_argument("--ray-vectors", type=Path)
    parser.add_argument("--ray-result", type=Path)
    args = parser.parse_args()
    metadata = {"schema": "bounded-linear-independent-oracle-v1", "python": platform.python_version(),
                "numpy": np.__version__, "scipy": scipy.__version__,
                "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                "scope": "linear_subproblem_only_not_nonlinear_or_physical_acceptance"}
    if args.mode == "residual-band":
        if args.report is None or args.ray_vectors is None or args.ray_result is None:
            parser.error("residual-band requires REPORT.json, --ray-vectors, and --ray-result")
        result = solve_residual_band(args.input_or_output, args.ray_vectors, args.ray_result)
        save(args.report, {**metadata, **result})
        print(json.dumps({"status": result["status"], "success": result["success"],
                          "audit_passed": result["audit"]["passed"],
                          "tau": None if result["vectors"] is None else result["vectors"]["tau"],
                          "elapsed_seconds": result["elapsed_seconds"]}))
        if not result["success"] or not result["audit"]["passed"]:
            raise SystemExit(2)
        return 0
    if args.mode == "generate":
        assert not kkt(np.zeros((1, 2)), np.array([0.]), np.array([0., -np.inf]), np.array([-1., 1e16]))["passed"]
        cases = []
        for name, matrix, residual, bounds in named_cases():
            A = np.asarray(matrix, dtype=float); r = np.asarray(residual, dtype=float)
            lower = np.array([-np.inf if v is None else v for v in bounds])
            cases.append({"name": name, "A": matrix, "r": residual, "lower": bounds,
                          "oracle": solve_case(A, r, lower)})
        save(args.input_or_output, {**metadata, "cases": cases})
        print(json.dumps({"oracle_cases": len(cases), "output": str(args.input_or_output)}))
    else:
        if args.report is None:
            parser.error("compare requires REPORT.json")
        raw = args.input_or_output.read_bytes(); data = json.loads(raw)
        snap = data["input"]; result = data["result"]
        A = np.zeros((snap["rows"], snap["columns"]))
        assert snap["index_base"] == 1
        for i, j, v in zip(snap["matrix"]["row_indices"], snap["matrix"]["column_indices"], snap["matrix"]["values"]):
            A[i - 1, j - 1] += v
        r = np.asarray(snap["residual"])
        lower = np.array([-np.inf if v is None else v for v in snap["lower_bounds"]])
        oracle = solve_case(A, r, lower); x = np.asarray(result["step"])
        audit = kkt(A, r, lower, x); objective = float(np.linalg.norm(A @ x + r) ** 2 / 2)
        passed = bool(result["converged"] and audit["passed"] and
                      abs(objective - oracle["objective"]) <= 1e-10 * max(1, oracle["objective"]))
        save(args.report, {**metadata, "input_sha256": hashlib.sha256(raw).hexdigest(),
                           "oracle": oracle, "actual_kkt": audit, "actual_objective": objective,
                           "passed": passed})
        print(json.dumps({"passed": passed, "objective": objective, "oracle_objective": oracle["objective"]}))
        if not passed:
            raise SystemExit(1)


if __name__ == "__main__":
    main()
