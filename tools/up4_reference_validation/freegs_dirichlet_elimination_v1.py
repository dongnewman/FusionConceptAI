"""Fixed-Dirichlet degree-of-freedom elimination for a sparse GS operator.

The routine is intentionally solver-agnostic. It accepts a pinned sparse
matrix and frozen box edges, verifies the exact boundary block structure, and
factorizes the interior block once. It never calls a full-grid fallback.
"""

from __future__ import annotations

import hashlib
from typing import Any, Mapping


EDGE_NAMES = ("r_min", "r_max", "z_min", "z_max")
HISTORICAL_FULL_GRID_PROJECTION_CAP_WB_PER_RAD = 1.0e-12


def _np() -> Any:
    import numpy as np

    return np


def _sha_float64(value: Any) -> str:
    import numpy as np

    payload = np.ascontiguousarray(value, dtype=np.dtype("<f8")).tobytes(order="C")
    return hashlib.sha256(payload).hexdigest()


def _sha_sparse(matrix: Any) -> str:
    import numpy as np

    csr = matrix.tocsr(copy=True)
    csr.sum_duplicates()
    csr.sort_indices()
    csr.eliminate_zeros()
    h = hashlib.sha256(f"csr:{csr.shape[0]}:{csr.shape[1]}\n".encode("ascii"))
    for arr, dtype in (
        (csr.indptr, np.dtype("<i8")),
        (csr.indices, np.dtype("<i8")),
        (csr.data, np.dtype("<f8")),
    ):
        h.update(np.ascontiguousarray(arr, dtype=dtype).tobytes(order="C"))
    return h.hexdigest()


def boundary_interior_indices(shape: tuple[int, int]) -> tuple[Any, Any]:
    """Return unique, disjoint, exhaustive C-order grid index partitions."""
    import numpy as np

    if len(shape) != 2:
        raise RuntimeError("grid must be rank two")
    nx, ny = int(shape[0]), int(shape[1])
    if nx < 3 or ny < 3:
        raise RuntimeError("grid must contain interior points")
    labels = np.arange(nx * ny, dtype=np.int64).reshape((nx, ny), order="C")
    mask = np.zeros((nx, ny), dtype=np.bool_)
    mask[0, :] = True
    mask[-1, :] = True
    mask[:, 0] = True
    mask[:, -1] = True
    flat = mask.ravel(order="C")
    boundary = np.flatnonzero(flat)
    interior = np.flatnonzero(~flat)
    if boundary.size != 2 * nx + 2 * ny - 4:
        raise RuntimeError("boundary index count mismatch")
    if interior.size != (nx - 2) * (ny - 2):
        raise RuntimeError("interior index count mismatch")
    if np.intersect1d(boundary, interior).size:
        raise RuntimeError("boundary and interior index sets overlap")
    if not np.array_equal(
        np.sort(np.concatenate((boundary, interior))),
        np.arange(nx * ny, dtype=np.int64),
    ):
        raise RuntimeError("boundary and interior index sets are not exhaustive")
    if np.unique(labels.ravel(order="C")[boundary]).size != boundary.size:
        raise RuntimeError("boundary corner was indexed more than once")
    return boundary, interior


def _expected_boundary_vector(shape: tuple[int, int], edges: Mapping[str, Any], bidx: Any) -> Any:
    import numpy as np

    nx, ny = shape
    full = np.empty((nx, ny), dtype=np.dtype("<f8"))
    full[0, :] = edges["r_min"]
    full[-1, :] = edges["r_max"]
    full[:, 0] = edges["z_min"]
    full[:, -1] = edges["z_max"]
    if not np.isfinite(full[0, :]).all() or not np.isfinite(full[-1, :]).all():
        raise RuntimeError("non-finite observed radial edge")
    if not np.isfinite(full[:, 0]).all() or not np.isfinite(full[:, -1]).all():
        raise RuntimeError("non-finite observed vertical edge")
    if not (
        edges["r_min"][0] == edges["z_min"][0]
        and edges["r_min"][-1] == edges["z_max"][0]
        and edges["r_max"][0] == edges["z_min"][-1]
        and edges["r_max"][-1] == edges["z_max"][-1]
    ):
        raise RuntimeError("observed Dirichlet edges have incompatible corners")
    return full.ravel(order="C")[bidx].copy()


class ReducedDirichletLinearSystem:
    """Solve the exact block system and receipt its residual without a gate."""

    def __init__(
        self,
        matrix: Any,
        shape: tuple[int, int],
        edges: Mapping[str, Any],
        *,
        receipt: dict[str, Any] | None = None,
        callback_count: Any = None,
    ) -> None:
        import numpy as np
        from scipy import sparse
        from scipy.sparse.linalg import factorized

        if not isinstance(shape, (tuple, list)) or len(shape) != 2:
            raise RuntimeError("grid shape must be a two-item tuple/list")
        if any(
            isinstance(value, (bool, np.bool_))
            or not isinstance(value, (int, np.integer))
            for value in shape
        ):
            raise RuntimeError("grid dimensions must be integers")
        if not sparse.issparse(matrix):
            raise RuntimeError("operator must be sparse")
        self.shape = int(shape[0]), int(shape[1])
        self.size = self.shape[0] * self.shape[1]
        if matrix.shape != (self.size, self.size):
            raise RuntimeError("operator shape mismatch")
        if matrix.dtype != np.dtype(np.float64):
            raise RuntimeError("operator dtype must remain float64")
        a = matrix.tocsr(copy=True)
        a.sum_duplicates()
        a.sort_indices()
        a.eliminate_zeros()
        if not np.isfinite(a.data).all():
            raise RuntimeError("operator contains non-finite coefficients")
        self.boundary, self.interior = boundary_interior_indices(self.shape)
        self.edges = {k: np.array(edges[k], dtype=np.dtype("<f8"), copy=True) for k in EDGE_NAMES}
        nx, ny = self.shape
        lengths = {"r_min": ny, "r_max": ny, "z_min": nx, "z_max": nx}
        for name, count in lengths.items():
            if self.edges[name].shape != (count,) or not np.isfinite(self.edges[name]).all():
                raise RuntimeError(f"edge shape/value mismatch: {name}")
        self.expected_boundary = _expected_boundary_vector(
            self.shape, self.edges, self.boundary
        )
        self.matrix = a
        self.a_ii = a[self.interior, :][:, self.interior].tocsc()
        self.a_ib = a[self.interior, :][:, self.boundary].tocsc()
        a_bi = a[self.boundary, :][:, self.interior].tocsr()
        a_bb = a[self.boundary, :][:, self.boundary].tocsr()
        a_bi.eliminate_zeros()
        if a_bi.nnz:
            raise RuntimeError("A_BI must be exactly zero")
        delta = a_bb - sparse.eye(self.boundary.size, format="csr", dtype=np.float64)
        delta.eliminate_zeros()
        if delta.nnz:
            raise RuntimeError("A_BB must be exactly identity")
        if self.a_ii.shape != (self.interior.size, self.interior.size):
            raise RuntimeError("A_II shape mismatch")
        if self.a_ib.shape != (self.interior.size, self.boundary.size):
            raise RuntimeError("A_IB shape mismatch")
        if not self.a_ii.nnz:
            raise RuntimeError("A_II is empty")
        try:
            self.solve_ii = factorized(self.a_ii.tocsc())
        except BaseException as exc:
            raise RuntimeError("A_II factorization failed; no fallback is permitted") from exc
        if not callable(self.solve_ii):
            raise RuntimeError("A_II factorizer did not return a callable")
        self.receipt = receipt
        self.callback_count = callback_count
        self.calls = 0
        self.operator_sha256 = _sha_sparse(a)
        self.a_ii_sha256 = _sha_sparse(self.a_ii)
        self.a_ib_sha256 = _sha_sparse(self.a_ib)
        if receipt is not None:
            receipt.setdefault("linear_solver_events", [])
            receipt["reduced_linear_system"] = {
                "status": "ready",
                "shape_r_z": list(self.shape),
                "flatten_order": "C",
                "operator_sha256": self.operator_sha256,
                "a_ii_shape": list(self.a_ii.shape),
                "a_ii_nnz": int(self.a_ii.nnz),
                "a_ii_sha256": self.a_ii_sha256,
                "a_ib_shape": list(self.a_ib.shape),
                "a_ib_nnz": int(self.a_ib.nnz),
                "a_ib_sha256": self.a_ib_sha256,
                "a_bi_exact_zero": True,
                "a_bb_exact_identity": True,
                "boundary_count_unique": int(self.boundary.size),
                "interior_count_unique": int(self.interior.size),
                "partition_disjoint_exhaustive": True,
                "factorization_lifetime": "scoped to one target solve call",
                "factorization_count": 1,
                "projection_used": False,
                "full_grid_fallback_permitted": False,
                "historical_full_grid_projection_guard_wb_per_rad":
                    HISTORICAL_FULL_GRID_PROJECTION_CAP_WB_PER_RAD,
                "residual_threshold": "not_defined_diagnostic_only",
            }

    def __call__(self, initial_psi: Any, rhs: Any) -> Any:
        import numpy as np

        x, b = np.asarray(initial_psi), np.asarray(rhs)
        if x.shape != self.shape or b.shape != self.shape:
            raise RuntimeError("solver input shape mismatch")
        if x.dtype != np.dtype(np.float64) or b.dtype != np.dtype(np.float64):
            raise RuntimeError("solver inputs must remain float64")
        if not np.isfinite(x).all() or not np.isfinite(b).all():
            raise RuntimeError("solver inputs must be finite")
        if self.callback_count is not None and self.callback_count() != self.calls + 1:
            raise RuntimeError("exactly one marked callback must precede each linear solve")
        b_edges = {
            "r_min": b[0, :], "r_max": b[-1, :],
            "z_min": b[:, 0], "z_max": b[:, -1],
        }
        for name in EDGE_NAMES:
            if not np.array_equal(b_edges[name], self.edges[name]):
                raise RuntimeError(f"RHS boundary does not match frozen edge: {name}")
        bf = np.ascontiguousarray(b, dtype=np.dtype("<f8")).reshape(-1, order="C")
        g = bf[self.boundary].copy()
        if not np.array_equal(g, self.expected_boundary):
            raise RuntimeError("boundary RHS differs from frozen source")
        reduced_rhs = bf[self.interior] - self.a_ib.dot(g)
        if not np.isfinite(reduced_rhs).all():
            raise RuntimeError("reduced RHS is non-finite")
        try:
            psi_i = np.asarray(self.solve_ii(reduced_rhs), dtype=np.dtype("<f8"))
        except BaseException as exc:
            raise RuntimeError("A_II solve failed; no fallback is permitted") from exc
        if psi_i.shape != (self.interior.size,) or not np.isfinite(psi_i).all():
            raise RuntimeError("A_II returned invalid interior values")
        out_flat = np.empty(self.size, dtype=np.dtype("<f8"))
        out_flat[self.interior] = psi_i
        out_flat[self.boundary] = g
        out = out_flat.reshape(self.shape, order="C")
        for name, values in {
            "r_min": out[0, :], "r_max": out[-1, :],
            "z_min": out[:, 0], "z_max": out[:, -1],
        }.items():
            if not np.array_equal(values, self.edges[name]):
                raise RuntimeError(f"reduced result is not exact on edge {name}")
        residual = self.matrix.dot(out_flat) - bf
        if not np.isfinite(residual).all():
            raise RuntimeError("discrete linear residual is non-finite")
        ri, rb = residual[self.interior], residual[self.boundary]
        self.calls += 1
        if self.receipt is not None:
            self.receipt["linear_solver_events"].append({
                "event_index": self.calls,
                "callback_preceded_solver_exactly_once": True,
                "initial_psi_sha256": _sha_float64(x),
                "rhs_sha256": _sha_float64(b),
                "rhs_boundary_equals_frozen_source_exactly": True,
                "output_psi_sha256": _sha_float64(out),
                "output_edges_exact": True,
                "interior_sha256": _sha_float64(out[1:-1, 1:-1]),
                "linear_residual": {
                    "classification": "diagnostic_only_no_physical_acceptance_threshold",
                    "max_abs_all": float(np.max(np.abs(residual))),
                    "l2_all": float(np.linalg.norm(residual)),
                    "max_abs_interior": float(np.max(np.abs(ri))),
                    "l2_interior": float(np.linalg.norm(ri)),
                    "max_abs_boundary": float(np.max(np.abs(rb))),
                },
            })
        return out
