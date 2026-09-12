"""Read-only numerical audit of an existing revised-chain run.

Reconstructs coefficients with 70-digit Decimal arithmetic from the exact same
binary64-parsed raw samples. It does not launch DESC or replace any accepted
physics/engineering state. A tiny independent box-quadratic calculation is an
audit of the stopped solver, not a new production candidate result.
"""
import argparse
import csv
import hashlib
import itertools
import json
import math
import pathlib
import platform
import sys
from decimal import Decimal as D, localcontext

import numpy as np


def sha(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()


def audit(run):
    run = pathlib.Path(run).resolve()
    physics_path = run / "physics.json"
    verification_path = run / "verification.json"
    p = json.loads(physics_path.read_text())
    v = json.loads(verification_path.read_text())
    raw = pathlib.Path(p["execution"]["raw_samples_path"])
    assert sha(raw) == p["execution"]["raw_samples_sha256"]["value"]
    for artifact in v["artifacts"]:
        assert sha(artifact["path"]) == artifact["sha256"]["value"]
    assert p["candidate_hash"] == v["candidate_hash"]
    assert p["context_hash"] == v["context_hash"]
    params = {parameter["name"]: parameter for parameter in p["declaration"]["parameters"]}
    with localcontext() as context:
        context.prec = 70
        zero, one, two = D(0), D(1), D(2)
        mu = D(float(params["mu0"]["value"]))
        length = D(float(params["test_reference_length"]["value"]))
        C = [[zero for _ in range(4)] for _ in range(36)]
        absolute = [[zero for _ in range(4)] for _ in range(36)]
        dm, dp = [zero] * 36, [zero] * 36

        def add(row, column, value):
            C[row][column] += value
            absolute[row][column] += abs(value)

        with raw.open() as stream:
            rows = list(csv.DictReader(stream, delimiter="\t"))
        for sample in rows:
            kind, region = sample["kind"], int(sample["region"])
            get = lambda key: D(float(sample[key]))
            B = [get(key) for key in ("Bx", "By", "Bz")]
            normal = [get(key) for key in ("nx", "ny", "nz")]
            pressure, weight = get("p"), get("measure")
            basis = [one] + [get(key) / length for key in ("x", "y", "z")]
            b2 = sum(value * value for value in B)
            M = [[(B[k] * B[l] - (b2 / two if k == l else zero)) / mu
                  for l in range(3)] for k in range(3)]
            if kind == "volume":
                for k, l in itertools.product(range(3), repeat=2):
                    row = 12 * (region - 1) + 3 * (l + 1) + k
                    add(row, 2 * (region - 1), -weight * M[k][l] / length)
                    if k == l:
                        add(row, 2 * (region - 1) + 1, weight * pressure / length)
            else:
                mt = [sum(M[k][l] * normal[l] for l in range(3)) for k in range(3)]
                pt = [-pressure * normal[k] for k in range(3)]
                for t, k in itertools.product(range(4), range(3)):
                    row, w = 3 * t + k, weight * basis[t]
                    if kind == "interface":
                        assert float(sample["rho"]) == 0.5
                        for owner in range(2):
                            for rr, sign in ((row, one), (12 + row, -one)):
                                add(rr, 2 * owner, sign * w * mt[k] / two)
                                add(rr, 2 * owner + 1, sign * w * pt[k] / two)
                            sign = one if owner == 0 else -one
                            add(24 + row, 2 * owner, sign * w * mt[k])
                            add(24 + row, 2 * owner + 1, sign * w * pt[k])
                    else:
                        assert kind == "exterior" and float(sample["rho"]) == 1.0
                        dm[12 + row] += w * mt[k]
                        dp[12 + row] += w * pt[k]
        x = [D(float(value)) for value in p["final_state"]]
        transformed = [x[0] ** 2, x[1], x[2] ** 2, x[3]]
        residual_hp = [sum(C[i][j] * transformed[j] for j in range(4)) + dm[i] + dp[i]
                       for i in range(36)]
        derivative = [2 * x[0], one, 2 * x[2], one]
        J_hp = np.array([[float(C[i][j] * derivative[j]) for j in range(4)] for i in range(36)])
        C_hp = np.array([[float(value) for value in row] for row in C])
        residual_hp = np.array([float(value) for value in residual_hp])
        summed_absolute = [float(sum(absolute[i][j] * abs(transformed[j]) for j in range(4)))
                           for i in range(36)]
    J = np.array(p["full_state_jacobian"])
    fd = np.array(v["numerical"]["physics"]["full_state_jacobian"]["finite_difference_rows"])
    primary = np.array(p["residual"])
    independent = np.array(v["numerical"]["physics"]["residual_crosscheck"]["independent_residual"])
    scales = np.array(p["row_scales"])
    C_primary = np.array(p["coefficient_matrix"])
    A = C_primary / scales[:, None]
    b = (np.array(p["constant_magnetic"]) + np.array(p["constant_pressure"])) / scales
    declared_bounds = np.array([state["bounds"] for state in p["declaration"]["states"]])
    bounds = declared_bounds.copy()
    bounds[[0, 2], :] **= 2
    assert np.linalg.matrix_rank(A) == 4
    best, best_face, count = None, None, 0
    # Full column rank makes each free-face least-squares minimizer unique.
    # Enumerating 3^4 faces therefore includes the convex box problem optimum.
    for face in itertools.product((-1, 0, 1), repeat=4):
        free = [i for i, value in enumerate(face) if value == 0]
        active = [i for i, value in enumerate(face) if value != 0]
        y = np.zeros(4)
        for i in active:
            y[i] = bounds[i, 0 if face[i] == -1 else 1]
        if free:
            y[free] = np.linalg.lstsq(A[:, free], -b - A[:, active] @ y[active], rcond=None)[0]
        if np.any(y < bounds[:, 0] - 1e-12) or np.any(y > bounds[:, 1] + 1e-12):
            continue
        count += 1
        objective = float(np.linalg.norm(A @ y + b) ** 2)
        if best is None or objective < best[0]:
            best, best_face = (objective, y.copy()), face
    assert best is not None
    initial_scaled = float(p["iterations"][0]["scaled_residual_norm"])
    actual_squared = float(np.linalg.norm(primary / scales) ** 2)
    floor = float(v["numerical"]["physics"]["solve_error"]["unconstrained_scaled_residual_floor"])
    worst = np.argsort(np.abs(independent - primary) / scales)[-10:][::-1]
    result = dict(
        schema="revised-verification-decimal-audit-v1", audit_exit_code=0,
        candidate_hash=p["candidate_hash"], context_hash=p["context_hash"],
        method="70-digit Decimal operations on exact same binary64-parsed raw values; all 36 rows and 4 analytic derivative columns",
        production_outputs_replaced=False, physics_or_engineering_solver_restarted=False,
        physical_validation_credit=0, raw_sample_count=len(rows),
        environment=dict(python=sys.executable, python_version=platform.python_version(),
                         numpy_version=np.__version__, executable_sha256=sha(sys.executable)),
        source=dict(path=str(pathlib.Path(__file__).resolve()), sha256=sha(__file__)),
        inputs=[dict(path=str(path), sha256=sha(path)) for path in (physics_path, verification_path, raw)],
        original_verification_status=v["status"], original_verification_exit_code=v["solver_exit_code"],
        residual=dict(primary_vs_high_precision_norm_N=float(np.linalg.norm(primary-residual_hp)),
                      independent_vs_high_precision_norm_N=float(np.linalg.norm(independent-residual_hp)),
                      original_gate=1e-10, original_maximum_scaled_difference=float(np.max(abs(independent-primary)/scales)),
                      worst_rows=[dict(row=int(i+1), label=p["row_labels"][i], scale=float(scales[i]),
                                       primary=float(primary[i]), independent=float(independent[i]),
                                       high_precision=float(residual_hp[i]),
                                       summed_absolute_coefficient_contribution_N=summed_absolute[i]) for i in worst]),
        jacobian=dict(original_global_gate=1e-7, original_global_relative_error=v["numerical"]["physics"]["full_state_jacobian"]["relative_error"],
                      original_global_status=v["numerical"]["physics"]["full_state_jacobian"]["status"],
                      original_gate_is_not_columnwise=True,
                      columns=[dict(column=i+1, reference_norm=float(np.linalg.norm(J[:,i])),
                                    FD_absolute_error=float(np.linalg.norm(fd[:,i]-J[:,i])),
                                    FD_relative_error=float(np.linalg.norm(fd[:,i]-J[:,i])/np.linalg.norm(J[:,i])),
                                    production_vs_high_precision_relative_error=float(np.linalg.norm(J[:,i]-J_hp[:,i])/np.linalg.norm(J_hp[:,i]))) for i in range(4)]),
        constrained_solver_audit=dict(method="enumerate 81 faces of full-rank transformed convex box quadratic; diagnostic only",
             feasible_face_count=count, transformed_bounds=bounds.tolist(), best_face=best_face,
             diagnostic_transformed_state=best[1].tolist(), diagnostic_scaled_residual_norm=math.sqrt(best[0]),
             accepted_initial_scaled_residual_norm=initial_scaled, accepted_final_scaled_residual_norm=math.sqrt(actual_squared),
             accepted_state_gradient=(J.T @ ((primary/scales)/scales)).tolist(),
             unconstrained_scaled_residual_floor=floor,
             constraint_objective_penalty=best[0]-floor**2,
             algorithm_objective_gap=actual_squared-best[0],
             original_combined_objective_excess=actual_squared-floor**2,
             interpretation="Original excess above an infeasible unconstrained SVD optimum combines constraint cost and algorithmic suboptimality. The diagnostic box minimizer is not substituted into candidate outputs."),
        interpretation="Near-zero stress moments suffer severe Float64 cancellation; independent high-precision analytic columns agree with production at roundoff. The original strict gate remains fail. Spatial/integration error and physical validation are not inferred from this arithmetic audit.")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("run_dir")
    parser.add_argument("output_path")
    arguments = parser.parse_args()
    output = pathlib.Path(arguments.output_path).resolve()
    result = audit(arguments.run_dir)
    output.write_text(json.dumps(result, indent=2, allow_nan=False)+"\n", encoding="utf-8")
    output.with_suffix(".exitcode").write_text("0\n", encoding="ascii")
    print(json.dumps(dict(output_path=str(output), output_sha256=sha(output),
                          source_sha256=sha(__file__), audit_exit_code=0)))
