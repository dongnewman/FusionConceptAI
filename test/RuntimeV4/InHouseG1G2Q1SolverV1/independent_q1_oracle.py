"""Independent SciPy Q1 oracle for the frozen native G1/G2 MMS.

This module does not import FusionConceptAI or production solver code. It
assembles tensor-product trilinear elements directly from the frozen physical
box, diagonal affine coefficient, and manufactured polynomial. The strong
source follows from differentiating -div(K grad(u)) by hand.
"""

from __future__ import annotations

import argparse
import itertools
import json
import math
from dataclasses import asdict, dataclass
from fractions import Fraction as F
from typing import Iterable

import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.linalg import spsolve


# Frozen fixture values copied as exact rationals from the independent
# declaration fixture, not read from or evaluated by production helpers.
LOWER = (F(1, 2), F(1, 3), F(1, 4))
LENGTHS = (F(2), F(3), F(4))
K_BASE = (F(2), F(3), F(4))
K_SLOPE = (F(1, 10), F(1, 20), F(1, 30))
GRID_LEVELS = ((2, 3, 4), (4, 6, 8), (8, 12, 16))

# These are the unchanged V1 numerical gates. The in-house backend may have a
# distinct identity, but its acceptance criteria are the same.
THRESHOLDS = {
    "residual_abs_tol": 1.0e-9,
    "residual_rel_tol": 1.0e-11,
    "boundary_abs_tol": 1.0e-10,
    "source_integral_abs_tol": 1.0e-10,
    "analytic_identity_abs_tol": 1.0e-12,
    "reaction_balance_abs_tol": 1.0e-9,
    "l2_order_interval": (1.4, 2.6),
    "h1_order_interval": (0.6, 1.4),
    "finest_l2_max": 5.0e-3,
    "finest_h1_seminorm_max": 1.0e-2,
}


def _bubble(t: F | float) -> F | float:
    return t * (1 - t)


def exact_value(point: Iterable[F | float]) -> F | float:
    """u=product_i t_i(1-t_i), with t_i=(x_i-a_i)/L_i."""
    xyz = tuple(point)
    t = tuple((xyz[i] - LOWER[i]) / LENGTHS[i] for i in range(3))
    return math.prod(_bubble(q) for q in t)


def exact_gradient(point: Iterable[float]) -> tuple[float, float, float]:
    xyz = tuple(float(q) for q in point)
    t = tuple((xyz[i] - float(LOWER[i])) / float(LENGTHS[i])
              for i in range(3))
    return tuple(
        (1.0 - 2.0 * t[i]) / float(LENGTHS[i])
        * math.prod(_bubble(t[j]) for j in range(3) if j != i)
        for i in range(3)
    )


def diagonal_k(point: Iterable[F | float]) -> tuple[F | float, ...]:
    xyz = tuple(point)
    return tuple(K_BASE[i] + K_SLOPE[i] * xyz[i] for i in range(3))


def strong_source(point: Iterable[F | float]) -> F | float:
    """Compute -sum_i d_i(k_i d_i u), including each k_i' term.

    For b_i=t_i(1-t_i), b_i'= (1-2t_i)/L_i and
    b_i''=-2/L_i^2. Applying the product rule to k_i b_i' gives
    -[(k_i' b_i' + k_i b_i'') product_{j!=i} b_j].
    """
    xyz = tuple(point)
    t = tuple((xyz[i] - LOWER[i]) / LENGTHS[i] for i in range(3))
    ks = diagonal_k(xyz)
    total = 0
    for i in range(3):
        other_bubbles = math.prod(_bubble(t[j]) for j in range(3) if j != i)
        first = 2 * ks[i] / (LENGTHS[i] ** 2)
        coefficient_derivative = (
            K_SLOPE[i] * (1 - 2 * t[i]) / LENGTHS[i]
        )
        total += (first - coefficient_derivative) * other_bubbles
    return total


def _fraction_source_integral() -> F:
    """Integrate the source polynomial exactly over the physical box."""
    total = F(0)
    for i in range(3):
        lo = LOWER[i]
        hi = lo + LENGTHS[i]
        k_lo = K_BASE[i] + K_SLOPE[i] * lo
        k_hi = K_BASE[i] + K_SLOPE[i] * hi
        # Integrate -d_i(k_i d_i u) over t_i in [0,1], then each
        # transverse bubble contributes integral_0^1 t(1-t) dt = 1/6.
        # The affine coefficient and its derivative cancel to the mean
        # endpoint coefficient after integration over the axis coordinate.
        mean_k = (k_lo + k_hi) / 2
        transverse_jacobian = math.prod(
            LENGTHS[j] for j in range(3) if j != i
        )
        total += 2 * mean_k / LENGTHS[i] * transverse_jacobian / 36
    return total


def _fraction_outward_conormal() -> F:
    """Integrate the outward conormal K grad(u) dot n over six faces."""
    total = F(0)
    for i in range(3):
        lo = LOWER[i]
        hi = lo + LENGTHS[i]
        k_lo = K_BASE[i] + K_SLOPE[i] * lo
        k_hi = K_BASE[i] + K_SLOPE[i] * hi
        transverse_jacobian = math.prod(
            LENGTHS[j] for j in range(3) if j != i
        )
        total -= (k_lo + k_hi) / LENGTHS[i] * transverse_jacobian / 36
    return total


def exact_balance() -> tuple[float, float, float]:
    """Return exact source, outward conormal, and identity defect."""
    source = _fraction_source_integral()
    outward = _fraction_outward_conormal()
    return float(source), float(outward), float(source + outward)


def _shape(reference_point: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Trilinear basis and physical-reference derivatives on [-1,1]^3."""
    bits = tuple(itertools.product((0, 1), repeat=3))
    values = np.empty(8, dtype=np.float64)
    gradients = np.empty((8, 3), dtype=np.float64)
    for a, corner in enumerate(bits):
        factors = tuple(
            (reference_point[d] + 1.0) / 2.0 if corner[d]
            else (1.0 - reference_point[d]) / 2.0
            for d in range(3)
        )
        values[a] = math.prod(factors)
        for d in range(3):
            derivative = 0.5 if corner[d] else -0.5
            for other in range(3):
                if other != d:
                    derivative *= factors[other]
            gradients[a, d] = derivative
    return values, gradients


def _node_id(i: int, j: int, k: int, counts: tuple[int, int, int]) -> int:
    nx, ny, _ = counts
    return i + (nx + 1) * (j + (ny + 1) * k)


def _element_nodes(i: int, j: int, k: int,
                   counts: tuple[int, int, int]) -> np.ndarray:
    return np.array([
        _node_id(i + bx, j + by, k + bz, counts)
        for bx, by, bz in itertools.product((0, 1), repeat=3)
    ], dtype=np.int64)


def _physical_point(cell: tuple[int, int, int], xi: np.ndarray,
                    counts: tuple[int, int, int]) -> tuple[float, float, float]:
    return tuple(
        float(LOWER[d])
        + (cell[d] + 0.5 * (xi[d] + 1.0))
        * float(LENGTHS[d]) / counts[d]
        for d in range(3)
    )


def _global_coordinates(counts: tuple[int, int, int]) -> np.ndarray:
    nx, ny, nz = counts
    points = np.empty(((nx + 1) * (ny + 1) * (nz + 1), 3), dtype=np.float64)
    for k in range(nz + 1):
        for j in range(ny + 1):
            for i in range(nx + 1):
                q = _node_id(i, j, k, counts)
                points[q] = tuple(
                    float(LOWER[d]) + (i, j, k)[d]
                    * float(LENGTHS[d]) / counts[d]
                    for d in range(3)
                )
    return points


@dataclass(frozen=True)
class LevelMetrics:
    cell_counts: tuple[int, int, int]
    total_nodes: int
    free_dofs: int
    dirichlet_dofs: int
    matrix_nnz: int
    residual_abs: float
    residual_rel: float
    l2_error: float
    h1_seminorm_error: float
    boundary_linf: float
    assembled_source_integral: float
    analytic_source_integral: float
    source_integral_error: float
    analytic_outward_conormal_integral: float
    analytic_identity_defect: float
    discrete_interior_reaction_linf: float
    discrete_interior_reaction_sum: float
    discrete_boundary_reaction_integral: float
    discrete_boundary_reaction_balance_defect: float
    discrete_trace_conormal_integral: float
    discrete_trace_conormal_error: float


def solve_level(counts: tuple[int, int, int], *,
                include_raw: bool = False) -> LevelMetrics | tuple[LevelMetrics, dict]:
    """Assemble and solve one physical Cartesian trilinear Q1 level."""
    counts = tuple(int(q) for q in counts)
    if len(counts) != 3 or any(q <= 0 for q in counts):
        raise ValueError("cell counts must be three positive integers")

    # Two-point Gauss exactly integrates each local stiffness and source term:
    # their transformed polynomial degree is at most three in any coordinate.
    gx2, gw2 = np.polynomial.legendre.leggauss(2)
    quadrature2 = tuple(
        (np.array((x, y, z)), wx * wy * wz)
        for (x, wx), (y, wy), (z, wz) in itertools.product(
            zip(gx2, gw2), repeat=3
        )
    )
    # Three-point Gauss exactly integrates the squared Q1 interpolation
    # defects: degree is at most four in each physical coordinate.
    gx3, gw3 = np.polynomial.legendre.leggauss(3)
    quadrature3 = tuple(
        (np.array((x, y, z)), wx * wy * wz)
        for (x, wx), (y, wy), (z, wz) in itertools.product(
            zip(gx3, gw3), repeat=3
        )
    )

    hx = tuple(float(LENGTHS[d]) / counts[d] for d in range(3))
    det_j = math.prod(q / 2.0 for q in hx)
    total_nodes = math.prod(q + 1 for q in counts)
    row_parts: list[np.ndarray] = []
    col_parts: list[np.ndarray] = []
    data_parts: list[np.ndarray] = []
    rhs = np.zeros(total_nodes, dtype=np.float64)
    assembled_source = 0.0

    for cell in itertools.product(*(range(q) for q in counts)):
        nodes = _element_nodes(*cell, counts)
        kel = np.zeros((8, 8), dtype=np.float64)
        bel = np.zeros(8, dtype=np.float64)
        for xi, weight in quadrature2:
            n, dref = _shape(xi)
            dphys = dref * np.array([2.0 / hx[d] for d in range(3)])[None, :]
            point = _physical_point(cell, xi, counts)
            kdiag = tuple(float(v) for v in diagonal_k(point))
            src = float(strong_source(point))
            w = weight * det_j
            for d in range(3):
                kel += (w * kdiag[d]) * np.outer(dphys[:, d], dphys[:, d])
            bel += (w * src) * n
            assembled_source += w * src
        row_parts.append(np.repeat(nodes, 8))
        col_parts.append(np.tile(nodes, 8))
        data_parts.append(kel.reshape(-1))
        np.add.at(rhs, nodes, bel)

    matrix = coo_matrix((np.concatenate(data_parts),
                         (np.concatenate(row_parts), np.concatenate(col_parts))),
                        shape=(total_nodes, total_nodes)).tocsr()
    matrix.sum_duplicates()

    coordinates = _global_coordinates(counts)
    a = np.array([float(q) for q in LOWER])
    b = a + np.array([float(q) for q in LENGTHS])
    boundary_mask = np.any(
        np.isclose(coordinates, a, rtol=0.0, atol=1.0e-13)
        | np.isclose(coordinates, b, rtol=0.0, atol=1.0e-13), axis=1
    )
    boundary = np.flatnonzero(boundary_mask)
    free = np.flatnonzero(~boundary_mask)
    solution = np.zeros(total_nodes, dtype=np.float64)
    reduced = matrix[free][:, free].tocsr()
    solution[free] = spsolve(reduced, rhs[free])

    interior_residual = reduced @ solution[free] - rhs[free]
    residual_abs = float(np.linalg.norm(interior_residual, ord=np.inf))
    residual_rel = residual_abs / max(float(np.linalg.norm(rhs[free], ord=np.inf)),
                                      np.finfo(float).eps)
    full_reaction = matrix @ solution - rhs
    interior_reaction = full_reaction[free]
    boundary_reaction = full_reaction[boundary]

    # Independent exact identity follows from the divergence theorem. On the
    # two i-faces, the outward conormal is -k_i/L_i times the transverse
    # bubble; each transverse integral is L/6.
    analytic_source, analytic_outward, analytic_defect = exact_balance()
    source_integral_error = abs(assembled_source - analytic_source)

    # Independently integrate the finite-element conormal on each physical
    # boundary face. A two-point rule is exact here: on a face, the normal
    # coefficient is constant and the Q1 normal derivative is bilinear in
    # the two tangential coordinates.
    trace_gauss, trace_weights = np.polynomial.legendre.leggauss(2)
    discrete_trace = 0.0
    for axis in range(3):
        tangent_axes = tuple(d for d in range(3) if d != axis)
        for side in (-1, 1):
            cell_index = 0 if side < 0 else counts[axis] - 1
            face_cell_ranges = [range(q) for q in counts]
            face_cell_ranges[axis] = range(cell_index, cell_index + 1)
            for cell in itertools.product(*face_cell_ranges):
                nodes = _element_nodes(*cell, counts)
                local_u = solution[nodes]
                for qa, ta in enumerate(trace_gauss):
                    for qb, tb in enumerate(trace_gauss):
                        xi = np.zeros(3, dtype=np.float64)
                        xi[axis] = -1.0 if side < 0 else 1.0
                        xi[tangent_axes[0]] = ta
                        xi[tangent_axes[1]] = tb
                        _, dref = _shape(xi)
                        dphys = dref * np.array(
                            [2.0 / hx[d] for d in range(3)])[None, :]
                        point = _physical_point(cell, xi, counts)
                        grad_fe = local_u @ dphys
                        conormal = side * float(diagonal_k(point)[axis]) * grad_fe[axis]
                        face_weight = (
                            hx[tangent_axes[0]] * hx[tangent_axes[1]] / 4.0
                            * trace_weights[qa] * trace_weights[qb]
                        )
                        discrete_trace += conormal * face_weight
    discrete_trace_error = abs(discrete_trace - analytic_outward)

    # Integrate the continuum-minus-FE errors with a higher exact rule.
    l2_sq = 0.0
    h1_sq = 0.0
    for cell in itertools.product(*(range(q) for q in counts)):
        nodes = _element_nodes(*cell, counts)
        local_u = solution[nodes]
        for xi, weight in quadrature3:
            n, dref = _shape(xi)
            dphys = dref * np.array([2.0 / hx[d] for d in range(3)])[None, :]
            point = _physical_point(cell, xi, counts)
            exact_u = float(exact_value(point))
            exact_grad = np.array(exact_gradient(point))
            fe_u = float(n @ local_u)
            fe_grad = local_u @ dphys
            w = weight * det_j
            l2_sq += w * (exact_u - fe_u) ** 2
            h1_sq += w * float(np.dot(exact_grad - fe_grad,
                                      exact_grad - fe_grad))

    metrics = LevelMetrics(
        cell_counts=counts,
        total_nodes=total_nodes,
        free_dofs=int(free.size),
        dirichlet_dofs=int(boundary.size),
        matrix_nnz=int(matrix.nnz),
        residual_abs=residual_abs,
        residual_rel=float(residual_rel),
        l2_error=math.sqrt(max(l2_sq, 0.0)),
        h1_seminorm_error=math.sqrt(max(h1_sq, 0.0)),
        boundary_linf=float(np.max(np.abs(solution[boundary]))),
        assembled_source_integral=float(assembled_source),
        analytic_source_integral=analytic_source,
        source_integral_error=float(source_integral_error),
        analytic_outward_conormal_integral=analytic_outward,
        analytic_identity_defect=analytic_defect,
        discrete_interior_reaction_linf=float(
            np.linalg.norm(interior_reaction, ord=np.inf)),
        discrete_interior_reaction_sum=float(np.sum(interior_reaction)),
        discrete_boundary_reaction_integral=float(np.sum(boundary_reaction)),
        discrete_boundary_reaction_balance_defect=float(
            assembled_source + np.sum(boundary_reaction)),
        discrete_trace_conormal_integral=float(discrete_trace),
        discrete_trace_conormal_error=float(discrete_trace_error),
    )
    if not include_raw:
        return metrics

    free_matrix = matrix[free][:, free].tocoo()
    full_coo = matrix.tocoo()
    raw = {
        "matrix_shape": list(reduced.shape),
        "matrix_rows": (free_matrix.row + 1).astype(int).tolist(),
        "matrix_columns": (free_matrix.col + 1).astype(int).tolist(),
        "matrix_values": free_matrix.data.astype(float).tolist(),
        "full_matrix_shape": list(matrix.shape),
        "full_matrix_rows": (full_coo.row + 1).astype(int).tolist(),
        "full_matrix_columns": (full_coo.col + 1).astype(int).tolist(),
        "full_matrix_values": full_coo.data.astype(float).tolist(),
        "free_dof_ids": (free + 1).astype(int).tolist(),
        "boundary_dof_ids": (boundary + 1).astype(int).tolist(),
        "rhs_values": rhs[free].astype(float).tolist(),
        "full_rhs_values": rhs.astype(float).tolist(),
            "solution_values": solution[free].astype(float).tolist(),
            "full_solution_values": solution.astype(float).tolist(),
        "full_dof_count": int(total_nodes),
        "boundary_mask": boundary_mask.astype(bool).tolist(),
    }
    return metrics, raw


def _orders(values: tuple[float, float, float]) -> tuple[float, float]:
    return tuple(math.log(values[i] / values[i + 1], 2.0) for i in range(2))


def run_frozen_series(*, include_raw: bool = False) -> dict:
    if include_raw:
        pairs = tuple(solve_level(level, include_raw=True) for level in GRID_LEVELS)
        levels = tuple(pair[0] for pair in pairs)
        raw_levels = tuple(pair[1] for pair in pairs)
    else:
        levels = tuple(solve_level(level) for level in GRID_LEVELS)
        raw_levels = ()
    l2_orders = _orders(tuple(q.l2_error for q in levels))
    h1_orders = _orders(tuple(q.h1_seminorm_error for q in levels))
    report = {
        "schema": "independent-scipy-q1-oracle-v1",
        "grid_levels": GRID_LEVELS,
        "thresholds": THRESHOLDS,
        "levels": tuple(asdict(q) for q in levels),
        "l2_orders": l2_orders,
        "h1_orders": h1_orders,
        "analytic_balance": exact_balance(),
    }
    if include_raw:
        report["raw_levels"] = raw_levels
    return report


def acceptance_failures(report: dict) -> tuple[str, ...]:
    """Apply frozen gates verbatim to independent oracle results."""
    failures: list[str] = []
    levels = report["levels"]
    t = THRESHOLDS
    for index, row in enumerate(levels, start=1):
        if not (row["residual_abs"] <= t["residual_abs_tol"]
                or row["residual_rel"] <= t["residual_rel_tol"]):
            failures.append(f"level_{index}:residual")
        if row["boundary_linf"] > t["boundary_abs_tol"]:
            failures.append(f"level_{index}:boundary")
        if row["source_integral_error"] > t["source_integral_abs_tol"]:
            failures.append(f"level_{index}:source_integral")
        if abs(row["analytic_identity_defect"]) > t["analytic_identity_abs_tol"]:
            failures.append(f"level_{index}:analytic_identity")
        if row["discrete_interior_reaction_linf"] > t["residual_abs_tol"]:
            failures.append(f"level_{index}:interior_reaction")
        if abs(row["discrete_boundary_reaction_balance_defect"]) > t["reaction_balance_abs_tol"]:
            failures.append(f"level_{index}:reaction_balance")
    for name, bounds in (("l2_orders", t["l2_order_interval"]),
                         ("h1_orders", t["h1_order_interval"])):
        for i, order in enumerate(report[name], start=1):
            if not bounds[0] <= order <= bounds[1]:
                failures.append(f"{name}_{i}:outside_frozen_interval")
    if levels[-1]["l2_error"] > t["finest_l2_max"]:
        failures.append("finest_l2_budget")
    if levels[-1]["h1_seminorm_error"] > t["finest_h1_seminorm_max"]:
        failures.append("finest_h1_budget")
    if any(levels[i]["l2_error"] <= levels[i + 1]["l2_error"]
           or levels[i]["h1_seminorm_error"] <= levels[i + 1]["h1_seminorm_error"]
           for i in range(2)):
        failures.append("errors_not_monotone")
    return tuple(failures)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true",
                        help="emit a single machine-readable JSON report")
    parser.add_argument("--cells", nargs=3, type=int,
                        help="solve one cell-count tuple and emit TSV metrics")
    parser.add_argument("--raw-json", action="store_true",
                        help="include raw CSC-equivalent triplets with --cells")
    args = parser.parse_args()
    if args.cells:
        result = solve_level(tuple(args.cells), include_raw=args.raw_json)
        if args.raw_json:
            metrics, raw = result
            payload = {"metrics": asdict(metrics), "raw": raw}
        else:
            payload = asdict(result)
        print(json.dumps(payload, separators=(",", ":")))
        return 0
    report = run_frozen_series()
    if args.json:
        print(json.dumps(report, separators=(",", ":")))
        return 0
    for index, level in enumerate(report["levels"], start=1):
        print(
            f"level={index} cells={level['cell_counts']} "
            f"residual_abs={level['residual_abs']:.12e} "
            f"residual_rel={level['residual_rel']:.12e} "
            f"L2={level['l2_error']:.12e} "
            f"H1={level['h1_seminorm_error']:.12e} "
            f"source_error={level['source_integral_error']:.12e} "
            f"reaction_balance={level['discrete_boundary_reaction_balance_defect']:.12e}"
        )
    print(f"l2_orders={report['l2_orders']}")
    print(f"h1_orders={report['h1_orders']}")
    failures = acceptance_failures(report)
    print(f"status={'PASS' if not failures else 'NUMERICAL_FAIL'} failures={failures}")
    return 0 if not failures else 2


if __name__ == "__main__":
    raise SystemExit(main())
