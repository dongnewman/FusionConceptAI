"""Independent NumPy row residual oracle for the frozen N1 MMS fixture.

This module is an offline diagnostic.  It does not call Julia, the production
assembler, the MMS solver, or any candidate/authority API.  The mesh, Q1
basis, torus metric, weak forms, and analytic manufactured fields are rebuilt
from the saved canonical input so a retained solver state can be checked row
by row and then evaluated with fixed higher-order quadrature.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np


@dataclass(frozen=True)
class Face:
    axis: int
    left: int
    right: int | None
    role: str
    fixed: float


@dataclass(frozen=True)
class Sample:
    entity: int
    q: np.ndarray
    xyz: np.ndarray
    radius: float
    phi: float
    weight: float
    normal: np.ndarray
    E: np.ndarray
    Einv: np.ndarray


@dataclass
class Mesh:
    nodes_q: list[tuple[float, float, float]]
    cell_nodes: list[list[int]]
    corner_to_local: list[list[int]]
    bounds: list[tuple[tuple[float, float], ...]]
    faces: list[Face]
    cell_row_start: list[int]
    exterior_row_start: dict[int, int]
    row_blocks: list[str]
    row_supports: list[list[int]]
    cut_nodes: list[int]


def _digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def build_mesh(model: dict[str, Any]) -> Mesh:
    """Rebuild the frozen periodic Q1 torus mesh and row ownership."""
    mesh_input = model["mesh"]
    rhos = list(map(float, mesh_input["rho"]))
    nt = int(mesh_input["theta_count"])
    nz = int(mesh_input["zeta_per_period"]) * int(mesh_input["nfp"])
    nr = len(rhos) - 1

    nodes_q: list[tuple[float, float, float]] = []
    node_id: dict[tuple[int, int, int], int] = {}
    for iz in range(nz):
        for ir in range(nr + 1):
            for it in range(1 if ir == 0 else nt):
                node_id[(ir, it, iz)] = len(nodes_q)
                nodes_q.append((rhos[ir], it * 2.0 * math.pi / nt,
                                iz * 2.0 * math.pi / nz))

    cell_nodes: list[list[int]] = []
    corner_to_local: list[list[int]] = []
    bounds: list[tuple[tuple[float, float], ...]] = []
    cell_id: dict[tuple[int, int, int], int] = {}
    for iz in range(nz):
        for ir in range(nr):
            for it in range(nt):
                ids: list[int] = []
                mapping: list[int] = []
                for k in range(8):
                    br, bt, bz = k % 2, (k // 2) % 2, k // 4
                    rr = ir + br
                    tt = 0 if rr == 0 else (it + bt) % nt
                    zz = (iz + bz) % nz
                    node = node_id[(rr, tt, zz)]
                    if node not in ids:
                        ids.append(node)
                    mapping.append(ids.index(node))
                cell_id[(ir, it, iz)] = len(cell_nodes)
                cell_nodes.append(ids)
                corner_to_local.append(mapping)
                bounds.append(((rhos[ir], rhos[ir + 1]),
                               (it * 2.0 * math.pi / nt,
                                (it + 1) * 2.0 * math.pi / nt),
                               (iz * 2.0 * math.pi / nz,
                                (iz + 1) * 2.0 * math.pi / nz)))

    faces: list[Face] = []
    for iz in range(nz):
        for ir in range(1, nr + 1):
            for it in range(nt):
                left = cell_id[(ir - 1, it, iz)]
                right = cell_id[(ir, it, iz)] if ir < nr else None
                faces.append(Face(0, left, right,
                                  "exterior" if right is None else "interior",
                                  rhos[ir]))
    for iz in range(nz):
        for ir in range(nr):
            for it in range(nt):
                left = cell_id[(ir, (it - 1) % nt, iz)]
                right = cell_id[(ir, it, iz)]
                faces.append(Face(1, left, right, "interior",
                                  it * 2.0 * math.pi / nt))
    for iz in range(nz):
        for ir in range(nr):
            for it in range(nt):
                left = cell_id[(ir, it, (iz - 1) % nz)]
                right = cell_id[(ir, it, iz)]
                faces.append(Face(2, left, right, "interior",
                                  iz * 2.0 * math.pi / nz))

    row_blocks: list[str] = []
    row_supports: list[list[int]] = []
    cell_row_start: list[int] = []

    def dofs(ids: list[int]) -> list[int]:
        return [4 * node + component for node in ids for component in range(1, 5)]

    for ids in cell_nodes:
        cell_row_start.append(len(row_blocks))
        support = dofs(ids)
        for _node in ids:
            for component in range(4):
                row_blocks.append("divB_Wb" if component == 3 else "momentum_N")
                row_supports.append(support.copy())

    exterior_row_start: dict[int, int] = {}
    for face_id, face in enumerate(faces):
        if face.role != "exterior":
            continue
        ids = [node for node in cell_nodes[face.left]
               if nodes_q[node][0] == 1.0]
        if len(ids) != 4:
            raise ValueError(f"exterior Q1 trace has {len(ids)} nodes, expected four")
        exterior_row_start[face_id] = len(row_blocks)
        support = dofs(ids)
        for _node in ids:
            for component in range(4):
                row_blocks.append("normal_B_Wb" if component == 3 else "traction_N")
                row_supports.append(support.copy())

    cut_nodes = [node for node, q in enumerate(nodes_q) if q[2] == 0.0]
    row_blocks.append("total_flux_Wb")
    row_supports.append([4 * node + component
                         for node in cut_nodes for component in range(1, 4)])
    expected_unknowns = 4 * len(nodes_q)
    if expected_unknowns != int(mesh_input["unknowns"]):
        raise ValueError(f"mesh has {expected_unknowns} unknowns, expected {mesh_input['unknowns']}")
    if len(row_blocks) != int(mesh_input["rows"]):
        raise ValueError(f"mesh has {len(row_blocks)} rows, expected {mesh_input['rows']}")
    return Mesh(nodes_q, cell_nodes, corner_to_local, bounds, faces,
                cell_row_start, exterior_row_start, row_blocks,
                row_supports, cut_nodes)


def _gauss(model: dict[str, Any], order: int) -> tuple[np.ndarray, np.ndarray]:
    if order == int(model["quadrature"]["order"]):
        return (np.asarray(model["quadrature"]["roots"], dtype=float),
                np.asarray(model["quadrature"]["weights"], dtype=float))
    roots, weights = np.polynomial.legendre.leggauss(order)
    return roots.astype(float), weights.astype(float)


def _rotation(phi: float) -> np.ndarray:
    c, s = math.cos(phi), math.sin(phi)
    return np.array(((c, -s, 0.0), (s, c, 0.0), (0.0, 0.0, 1.0)))


def _sample(model: dict[str, Any], entity: int, q: np.ndarray,
            base_weight: float, axis: int | None) -> Sample:
    geom = model["geometry"]
    a = float(geom["minor_radius_m"])
    r0 = float(geom["R0_m"])
    rho, theta, zeta = map(float, q)
    radius = r0 + a * rho * math.cos(theta)
    phi = zeta
    E = np.array(((a * math.cos(theta), -a * rho * math.sin(theta), 0.0),
                  (0.0, 0.0, radius),
                  (a * math.sin(theta), a * rho * math.cos(theta), 0.0)))
    det_e = float(np.linalg.det(E))
    Einv = np.linalg.inv(E)
    normal = np.zeros(3)
    weight = base_weight * abs(det_e)
    if axis is not None:
        dual = Einv[axis, :]
        rot = _rotation(phi)
        normal = rot @ dual / np.linalg.norm(dual)
        other = [index for index in range(3) if index != axis]
        weight = base_weight * np.linalg.norm(np.cross(E[:, other[0]], E[:, other[1]]))
    xyz = np.array((radius * math.cos(phi), radius * math.sin(phi),
                    a * rho * math.sin(theta)))
    return Sample(entity, q.copy(), xyz, radius, phi, float(weight), normal, E, Einv)


def _quadrature_samples(model: dict[str, Any], mesh: Mesh,
                        order: int) -> tuple[list[list[Sample]], list[list[Sample]]]:
    roots, weights = _gauss(model, order)
    volume: list[list[Sample]] = [[] for _ in mesh.cell_nodes]
    for cell, bounds in enumerate(mesh.bounds):
        for iz in range(order):
            for it in range(order):
                for ir in range(order):
                    indices = (ir, it, iz)
                    q = np.asarray([sum(bounds[a]) / 2.0 +
                                    roots[indices[a]] * (bounds[a][1] - bounds[a][0]) / 2.0
                                    for a in range(3)])
                    base = math.prod(weights[indices[a]] *
                                     (bounds[a][1] - bounds[a][0]) / 2.0
                                     for a in range(3))
                    volume[cell].append(_sample(model, cell, q, base, None))

    faces: list[list[Sample]] = [[] for _ in mesh.faces]
    for face_id, face in enumerate(mesh.faces):
        bounds = mesh.bounds[face.left if face.right is None else face.right]
        other = [index for index in range(3) if index != face.axis]
        qp = 0
        # The fixture's declared face order is j outer, i inner.
        for j in range(order):
            for i in range(order):
                indices = (i, j)
                q = np.zeros(3)
                q[face.axis] = face.fixed
                base = 1.0
                for axis, index in zip(other, indices):
                    q[axis] = (sum(bounds[axis]) / 2.0 +
                               roots[index] * (bounds[axis][1] - bounds[axis][0]) / 2.0)
                    base *= weights[index] * (bounds[axis][1] - bounds[axis][0]) / 2.0
                faces[face_id].append(_sample(model, face_id, q, base, face.axis))
                qp += 1
        if qp != order * order:
            raise AssertionError("incomplete face quadrature")
    return volume, faces


def _basis(mesh: Mesh, cell: int, q: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    bounds = mesh.bounds[cell]
    h = np.asarray([upper - lower for lower, upper in bounds])
    u = np.asarray(q, dtype=float) - np.asarray([lower for lower, _ in bounds])
    for axis in (1, 2):
        if u[axis] < -1e-10:
            u[axis] += 2.0 * math.pi
    u /= h
    if np.any(u < -1e-8) or np.any(u > 1.0 + 1e-8):
        raise ValueError(f"quadrature point is outside cell {cell}: {q.tolist()} -> {u.tolist()}")
    u[np.abs(u) < 1e-12] = 0.0
    u[np.abs(u - 1.0) < 1e-12] = 1.0
    N = np.zeros(len(mesh.cell_nodes[cell]))
    dN_dq = np.zeros((3, len(mesh.cell_nodes[cell])))
    for k in range(8):
        bits = (k % 2, (k // 2) % 2, k // 4)
        factors = [u[a] if bits[a] else 1.0 - u[a] for a in range(3)]
        local = mesh.corner_to_local[cell][k]
        N[local] += math.prod(factors)
        for axis in range(3):
            other_factor = math.prod(factors[b] for b in range(3) if b != axis)
            sign = 1.0 if bits[axis] else -1.0
            dN_dq[axis, local] += sign * other_factor / h[axis]
    return N, dN_dq


def _analytic(model: dict[str, Any], xyz: np.ndarray) -> tuple[np.ndarray, float, np.ndarray]:
    geometry, fields = model["geometry"], model["fields"]
    X, Y, Z = map(float, xyz)
    radius = math.hypot(X, Y)
    if radius <= 0.0:
        raise ValueError("manufactured torus excludes R=0")
    r0 = float(geometry["R0_m"])
    beta = float(fields["beta_T_m"])
    alpha = float(fields["alpha_Pa_m2"])
    mu0 = float(fields["mu0_N_A2"])
    B = np.array((-beta * Y, beta * X, 0.0))
    p = float(fields["p0_Pa"]) + alpha * ((radius - r0) ** 2 + Z**2)
    radial = -2.0 * beta**2 * radius / mu0 - 2.0 * alpha * (radius - r0)
    source = np.array((radial * X / radius, radial * Y / radius, -2.0 * alpha * Z))
    return B, p, source


def _stress(B: np.ndarray, p: float, mu0: float) -> np.ndarray:
    return np.outer(B, B) / mu0 - (float(B @ B) / (2.0 * mu0) + p) * np.eye(3)


def _field(mesh: Mesh, cell: int, sample: Sample, state: np.ndarray,
           model: dict[str, Any]) -> dict[str, Any]:
    N, dN_dq = _basis(mesh, cell, sample.q)
    Bcyl = np.zeros(3)
    D = np.zeros((3, 3))
    p = 0.0
    dp = np.zeros(3)
    for local, node in enumerate(mesh.cell_nodes[cell]):
        offset = 4 * node
        Bnode = state[offset:offset + 3]
        pnode = state[offset + 3]
        Bcyl += N[local] * Bnode
        p += N[local] * pnode
        D += np.outer(Bnode, dN_dq[:, local])
        dp += dN_dq[:, local] * pnode
    # Derivative of the cylindrical basis with respect to the physical Z row.
    H = D + np.outer(np.array((-Bcyl[1], Bcyl[0], 0.0)), sample.E[2, :] / sample.radius)
    G = H @ sample.Einv
    curl = np.array((G[2, 1] - G[1, 2], G[0, 2] - G[2, 0], G[1, 0] - G[0, 1]))
    rot = _rotation(sample.phi)
    Bxyz = rot @ Bcyl
    gradp = rot @ sample.Einv.T @ dp
    gradNxyz = rot @ sample.Einv.T @ dN_dq
    mu0 = float(model["fields"]["mu0_N_A2"])
    return {"N": N, "gradN_xyz": gradNxyz, "B_xyz": Bxyz, "p": p,
            "T_xyz": _stress(Bxyz, p, mu0), "divB": float(np.trace(G)),
            "curl": curl, "gradp_xyz": gradp}


def _analytic_field(sample: Sample, model: dict[str, Any]) -> dict[str, Any]:
    B, p, source = _analytic(model, sample.xyz)
    mu0 = float(model["fields"]["mu0_N_A2"])
    return {"B_xyz": B, "p": p, "T_xyz": _stress(B, p, mu0), "source": source}


def _exact_cell_field(mesh: Mesh, cell: int, sample: Sample,
                      model: dict[str, Any]) -> dict[str, Any]:
    N, _ = _basis(mesh, cell, sample.q)
    return {**_analytic_field(sample, model), "N": N}


def reference_state(mesh: Mesh, model: dict[str, Any]) -> np.ndarray:
    state: list[float] = []
    for rho, theta, zeta in mesh.nodes_q:
        a = float(model["geometry"]["minor_radius_m"])
        radius = float(model["geometry"]["R0_m"]) + a * rho * math.cos(theta)
        Z = a * rho * math.sin(theta)
        beta = float(model["fields"]["beta_T_m"])
        alpha = float(model["fields"]["alpha_Pa_m2"])
        p = float(model["fields"]["p0_Pa"]) + alpha * (
            (radius - float(model["geometry"]["R0_m"])) ** 2 + Z**2)
        state.extend((0.0, beta * radius, 0.0, p))
    return np.asarray(state, dtype=float)


def row_scales(mesh: Mesh, volume: list[list[Sample]], faces: list[list[Sample]],
               declaration: dict[str, Any], model: dict[str, Any]) -> np.ndarray:
    cell_volume = np.asarray([sum(s.weight for s in cell_samples)
                              for cell_samples in volume])
    face_area = np.asarray([sum(s.weight for s in face_samples)
                            for face_samples in faces])
    scaling = declaration["scaling"]
    stress_scale = float(scaling["B_T"])**2 / float(model["fields"]["mu0_N_A2"])
    stress_scale += float(scaling["p_Pa"])
    scales = np.zeros(len(mesh.row_blocks), dtype=float)
    for cell, ids in enumerate(mesh.cell_nodes):
        start = mesh.cell_row_start[cell]
        value = cell_volume[cell] ** (2.0 / 3.0)
        for local in range(len(ids)):
            scales[start + 4 * local:start + 4 * local + 3] = stress_scale * value
            scales[start + 4 * local + 3] = float(scaling["B_T"]) * value
    for face_id, start in mesh.exterior_row_start.items():
        area = face_area[face_id]
        for local in range(4):
            scales[start + 4 * local:start + 4 * local + 3] = stress_scale * area
            scales[start + 4 * local + 3] = float(scaling["B_T"]) * area
    scales[-1] = float(model["flux"]["nominal_Wb"])
    return scales


def assemble(model: dict[str, Any], declaration: dict[str, Any], mesh: Mesh,
             state: np.ndarray, order: int, mode: str = "finite_element") -> dict[str, Any]:
    """Assemble all current weak residual rows, without production code imports.

    mode='finite_element' interpolates the supplied nodal state. mode='exact'
    integrates the analytic continuum field against the same Q1 test functions.
    """
    if mode not in ("finite_element", "exact"):
        raise ValueError(f"unknown assembly mode: {mode}")
    if state.size != 4 * len(mesh.nodes_q):
        raise ValueError("state dimension does not match independent mesh")
    volume, faces = _quadrature_samples(model, mesh, order)
    residual = np.zeros(len(mesh.row_blocks), dtype=float)
    mu0 = float(model["fields"]["mu0_N_A2"])

    for cell, samples in enumerate(volume):
        for sample in samples:
            basis_N, basis_dN = _basis(mesh, cell, sample.q)
            if mode == "exact":
                f = _analytic_field(sample, model)
            else:
                f = _field(mesh, cell, sample, state, model)
            _, _, source = _analytic(model, sample.xyz)
            gradN = (_rotation(sample.phi) @ sample.Einv.T @ basis_dN)
            for local in range(len(mesh.cell_nodes[cell])):
                row = mesh.cell_row_start[cell] + 4 * local
                g = gradN[:, local]
                residual[row:row + 3] -= sample.weight * (
                    f["T_xyz"] @ g + basis_N[local] * source)
                residual[row + 3] -= sample.weight * float(g @ f["B_xyz"])

    for face_id, (face, samples) in enumerate(zip(mesh.faces, faces)):
        outer = face.right is None
        for sample in samples:
            left_field = (_exact_cell_field(mesh, face.left, sample, model) if mode == "exact" else
                          _field(mesh, face.left, sample, state, model))
            n = sample.normal
            if outer or mode == "exact":
                reference = _analytic_field(sample, model)
                t_ref = reference["T_xyz"] @ n
                bn_ref = float(reference["B_xyz"] @ n)
            else:
                t_ref = left_field["T_xyz"] @ n
                bn_ref = float(left_field["B_xyz"] @ n)

            for cell, sign in ((face.left, 1.0), (face.right, -1.0)):
                if cell is None:
                    continue
                f = (left_field if cell == face.left else
                     _exact_cell_field(mesh, cell, sample, model) if mode == "exact" else
                     _field(mesh, cell, sample, state, model))
                for local in range(len(mesh.cell_nodes[cell])):
                    row = mesh.cell_row_start[cell] + 4 * local
                    w = sign * sample.weight * f["N"][local]
                    residual[row:row + 3] += w * t_ref
                    residual[row + 3] += w * bn_ref

            if outer:
                trace_local = [local for local, node in enumerate(mesh.cell_nodes[face.left])
                               if mesh.nodes_q[node][0] == 1.0]
                start = mesh.exterior_row_start[face_id]
                for trace_index, local in enumerate(trace_local):
                    row = start + 4 * trace_index
                    w = sample.weight * left_field["N"][local]
                    residual[row:row + 3] += w * (left_field["T_xyz"] @ n - t_ref)
                    residual[row + 3] += w * (float(left_field["B_xyz"] @ n) - bn_ref)

            if face.axis == 2 and face.fixed == 0.0:
                residual[-1] += sample.weight * float(left_field["B_xyz"] @ n)

    residual[-1] -= float(model["flux"]["nominal_Wb"])
    scales = row_scales(mesh, volume, faces, declaration, model)
    return {"order": order, "mode": mode, "residual": residual,
            "row_scales": scales, "row_blocks": mesh.row_blocks,
            "row_supports": mesh.row_supports}


def summarize(result: dict[str, Any], original_scales: np.ndarray) -> dict[str, Any]:
    residual = result["residual"]
    scales = result["row_scales"]
    scaled = residual / scales
    fixed = residual / original_scales
    blocks: dict[str, dict[str, float | int]] = {}
    for name in dict.fromkeys(result["row_blocks"]):
        indices = np.asarray([i for i, item in enumerate(result["row_blocks"])
                              if item == name], dtype=int)
        blocks[name] = {"count": int(indices.size),
                        "raw_max_abs": float(np.max(np.abs(residual[indices]), initial=0.0)),
                        "raw_l2": float(np.linalg.norm(residual[indices])),
                        "scaled_max_abs_this_rule": float(np.max(np.abs(scaled[indices]), initial=0.0)),
                        "scaled_l2_this_rule": float(np.linalg.norm(scaled[indices])),
                        "scaled_max_abs_original_gl3_scale": float(np.max(np.abs(fixed[indices]), initial=0.0)),
                        "scaled_l2_original_gl3_scale": float(np.linalg.norm(fixed[indices]))}
    return {"order": result["order"], "mode": result["mode"],
            "rows": int(residual.size),
            "scaled_max_abs_this_rule": float(np.max(np.abs(scaled), initial=0.0)),
            "scaled_l2_this_rule": float(np.linalg.norm(scaled)),
            "scaled_max_abs_original_gl3_scale": float(np.max(np.abs(fixed), initial=0.0)),
            "scaled_l2_original_gl3_scale": float(np.linalg.norm(fixed)),
            "blocks": blocks}


def _difference(left: np.ndarray, right: np.ndarray, scales: np.ndarray,
                blocks: list[str]) -> dict[str, Any]:
    delta = left - right
    scaled = delta / scales
    by_block: dict[str, dict[str, float]] = {}
    for name in dict.fromkeys(blocks):
        indices = np.asarray([i for i, item in enumerate(blocks) if item == name], dtype=int)
        by_block[name] = {
            "raw_max_abs": float(np.max(np.abs(delta[indices]), initial=0.0)),
            "raw_l2": float(np.linalg.norm(delta[indices])),
            "scaled_max_abs_original_gl3_scale": float(np.max(np.abs(scaled[indices]), initial=0.0)),
            "scaled_l2_original_gl3_scale": float(np.linalg.norm(scaled[indices])),
        }
    return {"raw_max_abs": float(np.max(np.abs(delta), initial=0.0)),
            "raw_l2": float(np.linalg.norm(delta)),
            "scaled_max_abs_original_gl3_scale": float(np.max(np.abs(scaled), initial=0.0)),
            "scaled_l2_original_gl3_scale": float(np.linalg.norm(scaled)),
            "blocks": by_block}


def _compare_production(result: dict[str, Any], primary: dict[str, Any],
                        mesh: Mesh) -> dict[str, Any]:
    actual = np.asarray(primary["raw_residual"], dtype=float)
    actual_scales = np.asarray(primary["row_scales"], dtype=float)
    oracle = result["residual"]
    scales = result["row_scales"]
    if actual.size != oracle.size or actual_scales.size != oracle.size:
        raise ValueError("production and oracle row dimensions differ")
    supports_equal = [list(map(int, row)) == oracle_row
                      for row, oracle_row in zip(primary["row_supports"], mesh.row_supports)]
    blocks_equal = [str(row) == oracle_row
                    for row, oracle_row in zip(primary["row_blocks"], mesh.row_blocks)]
    deltas = oracle - actual
    scale_deltas = scales - actual_scales
    rows = []
    for index, delta in enumerate(deltas):
        rows.append({"row_1based": index + 1,
                     "block": mesh.row_blocks[index],
                     "support_1based": mesh.row_supports[index],
                     "production_raw": float(actual[index]),
                     "oracle_raw": float(oracle[index]),
                     "raw_delta_oracle_minus_production": float(delta),
                     "delta_over_original_scale": float(delta / actual_scales[index]),
                     "production_scale": float(actual_scales[index]),
                     "oracle_scale": float(scales[index]),
                     "scale_delta": float(scale_deltas[index]),
                     "support_equal": supports_equal[index],
                     "block_equal": blocks_equal[index]})
    return {"schema": "up2-closure-independent-gl3-row-comparison-v1",
            "interpretation": "independent NumPy assembly comparison only; not candidate, solver replay, or authority",
            "row_count": int(oracle.size),
            "column_count": int(len(primary["final_state"])),
            "row_blocks_all_equal": all(blocks_equal),
            "row_supports_all_equal": all(supports_equal),
            "production_vs_oracle_raw_max_abs": float(np.max(np.abs(deltas), initial=0.0)),
            "production_vs_oracle_raw_l2": float(np.linalg.norm(deltas)),
            "production_vs_oracle_max_abs_delta_over_original_scale": float(
                np.max(np.abs(deltas / actual_scales), initial=0.0)),
            "production_vs_oracle_scale_max_abs_delta": float(np.max(np.abs(scale_deltas), initial=0.0)),
            "rows": rows}


def run_gl3(model_path: Path, declaration_path: Path, primary_path: Path,
            output_dir: Path) -> dict[str, Any]:
    model = _load_json(model_path)
    declaration = _load_json(declaration_path)
    primary = _load_json(primary_path)
    mesh = build_mesh(model)
    state = np.asarray(primary["final_state"], dtype=float)
    if primary.get("status") != "fail" or primary.get("stopping_reason") != "stationary_nonzero_residual":
        raise ValueError("retained solver baseline is not the expected completed numerical_fail")
    if int(primary.get("solver_exit_code", -1)) != 2:
        raise ValueError("retained solver exit is not the expected numerical_fail exit 2")
    if state.size != 40 or len(primary["raw_residual"]) != 289:
        raise ValueError("retained solver baseline dimensions are not the frozen 40/289 case")

    ref = reference_state(mesh, model)
    initial = np.asarray(primary["initial_state"], dtype=float)
    perturbation = np.asarray(model["initialization"]["perturbation"], dtype=float)
    expected_initial = ref + np.tile(perturbation, len(mesh.nodes_q))
    initial_delta = expected_initial - initial

    production_scales = np.asarray(primary["row_scales"], dtype=float)
    solved = assemble(model, declaration, mesh, state, 3)
    comparison = _compare_production(solved, primary, mesh)
    oracle_path = output_dir / "gl3_oracle_rows.json"
    comparison_path = output_dir / "gl3_row_comparison.json"
    oracle_doc = {
        "schema": "up2-closure-independent-gl3-oracle-rows-v1",
        "scope": "offline diagnostic from retained final_state; not a new solver run",
        "source_sha256": primary["source_sha256"]["value"],
        "declaration_hash": primary["declaration_hash"]["value"],
        "rows": len(solved["residual"]), "columns": len(state),
        "reference_state_max_abs_delta_from_expected_initial_perturbation": float(
            np.max(np.abs(initial_delta), initial=0.0)),
        "summary": summarize(solved, production_scales),
        "row_residuals": [float(v) for v in solved["residual"]],
        "row_scales": [float(v) for v in solved["row_scales"]],
        "row_blocks": solved["row_blocks"],
        "row_supports": solved["row_supports"],
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    oracle_path.write_text(json.dumps(oracle_doc, indent=2, allow_nan=False) + "\n",
                           encoding="utf-8")
    comparison_path.write_text(json.dumps(comparison, indent=2, allow_nan=False) + "\n",
                               encoding="utf-8")
    return {"model": model, "declaration": declaration, "primary": primary,
            "mesh": mesh, "state": state, "reference_state": ref,
            "production_scales": production_scales,
            "gl3_result": solved, "comparison": comparison,
            "oracle_path": oracle_path, "comparison_path": comparison_path,
            "input_sha256": {"canonical_input": _digest(model_path),
                             "canonical_declaration": _digest(declaration_path),
                             "solver_primary": _digest(primary_path)}}


def run_orders(data: dict[str, Any], orders: list[int], output_dir: Path) -> Path:
    model, declaration, mesh = data["model"], data["declaration"], data["mesh"]
    primary_scales = data["production_scales"]
    states = {"solved_final_state": data["state"],
              "analytic_nodal_interpolant": data["reference_state"]}
    outputs: dict[str, Any] = {
        "schema": "up2-closure-independent-fixed-quadrature-v1",
        "interpretation": "fixed GL3/5/7/9 diagnostics; higher-order deltas are measured differences, not certified bounds",
        "authority": "none", "candidate_identity_issued": False,
        "physical_validation": "unsupported", "publish": "no_publish",
        "orders": {},
    }
    for order in orders:
        entry: dict[str, Any] = {}
        for name, state in states.items():
            result = assemble(model, declaration, mesh, state, order, "finite_element")
            entry[name] = {**summarize(result, primary_scales),
                           "row_residuals": [float(v) for v in result["residual"]],
                           "row_scales": [float(v) for v in result["row_scales"]]}
        exact = assemble(model, declaration, mesh, data["reference_state"], order, "exact")
        entry["analytic_continuum_field"] = {
            **summarize(exact, primary_scales),
            "row_residuals": [float(v) for v in exact["residual"]],
            "row_scales": [float(v) for v in exact["row_scales"]]}
        outputs["orders"][str(order)] = entry

    gl3 = outputs["orders"].get("3")
    if gl3 is not None:
        outputs["measured_differences"] = {
            "higher_order_minus_gl3_by_state": {},
            "representation_error_by_order": {},
        }
        modes = ("solved_final_state", "analytic_nodal_interpolant",
                 "analytic_continuum_field")
        for order_name, order_result in outputs["orders"].items():
            for mode in modes:
                current = np.asarray(order_result[mode]["row_residuals"])
                if order_name != "3":
                    baseline = np.asarray(gl3[mode]["row_residuals"])
                    outputs["measured_differences"][
                        "higher_order_minus_gl3_by_state"].setdefault(order_name, {})[mode] = _difference(
                            current, baseline, primary_scales, mesh.row_blocks)
            represented = np.asarray(order_result["analytic_nodal_interpolant"]["row_residuals"])
            continuum = np.asarray(order_result["analytic_continuum_field"]["row_residuals"])
            outputs["measured_differences"]["representation_error_by_order"][order_name] = _difference(
                represented, continuum, primary_scales, mesh.row_blocks)
    output_path = output_dir / "gl3_gl9_quadrature.json"
    output_path.write_text(json.dumps(outputs, indent=2, allow_nan=False) + "\n",
                           encoding="utf-8")
    return output_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canonical-input", required=True, type=Path)
    parser.add_argument("--canonical-declaration", required=True, type=Path)
    parser.add_argument("--solver-primary", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--orders", nargs="+", type=int, default=[3])
    args = parser.parse_args()
    if any(order < 2 or order > 16 for order in args.orders):
        parser.error("quadrature orders must be from 2 through 16")
    result = run_gl3(args.canonical_input, args.canonical_declaration,
                     args.solver_primary, args.output_dir)
    compare = result["comparison"]
    print(json.dumps({"gl3_comparison": str(result["comparison_path"]),
                      "rows": compare["row_count"],
                      "row_blocks_equal": compare["row_blocks_all_equal"],
                      "row_supports_equal": compare["row_supports_all_equal"],
                      "raw_max_abs_delta": compare["production_vs_oracle_raw_max_abs"],
                      "scaled_max_abs_delta": compare[
                          "production_vs_oracle_max_abs_delta_over_original_scale"]},
                     sort_keys=True))
    if args.orders != [3]:
        out = run_orders(result, args.orders, args.output_dir)
        print(json.dumps({"quadrature_diagnostics": str(out),
                          "orders": args.orders}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
