"""Read-only audit of recorded spatial-solver stagnation; no solver is launched.

Usage from the repository root:
    python docs/reports/goal_recovery_20260913/recheck_solver_stagnation.py

An optional run-directory argument selects a different existing spatial run.
Only the saved physics.json and nominal_coarse/state_history.csv are read.
The JSON printed to stdout is a numerical bookkeeping audit, not a new solution.
Exit 0 means all recorded-stagnation checks hold; exit 1 means they do not.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path


FIELDS = ("BR_T", "Bphi_T", "BZ_T", "p_Pa")


def main() -> int:
    repository = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "run_directory",
        nargs="?",
        type=Path,
        default=repository / "runs" / "spatial_chain_20260912_r1",
    )
    run_directory = parser.parse_args().run_directory.resolve(strict=True)
    physics_path = run_directory / "physics.json"
    history_path = run_directory / "physics" / "nominal_coarse" / "state_history.csv"
    physics_bytes = physics_path.read_bytes()
    history_bytes = history_path.read_bytes()
    physics = json.loads(physics_bytes)
    case = next(case for case in physics["cases"] if case["case_id"] == "nominal_coarse")
    solver = physics["declaration"]["solver"]
    pressure_scale = physics["declaration"]["scaling"]["p_Pa"]
    rows = csv.DictReader(io.StringIO(history_bytes.decode("utf-8-sig")))
    history: dict[int, list[dict]] = {}
    for row in rows:
        history.setdefault(int(row["iteration"]), []).append(
            {"node_id": int(row["node_id"]), **{field: float(row[field]) for field in FIELDS}}
        )

    comparisons = []
    for attempt in case["diagnostics"]["attempts"][-4:]:
        iteration = attempt["iteration"]
        before, after = history[iteration], history[iteration + 1]
        if [row["node_id"] for row in before] != [row["node_id"] for row in after]:
            raise ValueError("Recorded node ordering changed between iterations")
        changes = []
        pressure_limits = []
        for index, (left, right) in enumerate(zip(before, after)):
            for field in FIELDS:
                if left[field] != right[field]:
                    changes.append(
                        {"node_id": left["node_id"], "field": field,
                         "before": left[field], "after": right[field]}
                    )
            scaled_pressure_step = attempt["proposed_scaled_step"][4 * index + 3]
            if scaled_pressure_step < 0:
                pressure_limits.append(
                    {"node_id": left["node_id"], "pressure_before_Pa": left["p_Pa"],
                     "scaled_pressure_direction": scaled_pressure_step,
                     "predicted_alpha": -left["p_Pa"] / (pressure_scale * scaled_pressure_step)}
                )
        limiting = min(pressure_limits, key=lambda entry: entry["predicted_alpha"]) \
            if pressure_limits else None
        predicted_alpha = max(0.0, min(1.0, limiting["predicted_alpha"])) \
            if limiting is not None else None
        recorded_alpha = attempt["accepted_alpha"]
        comparisons.append(
            {"attempt": attempt["attempt_index"], "iteration_before": iteration,
             "accepted": attempt["accepted"], "direction": attempt["direction"],
             "predicted_feasible_alpha": predicted_alpha, "recorded_alpha": recorded_alpha,
             "alpha_matches": recorded_alpha is not None and predicted_alpha is not None and math.isclose(
                 predicted_alpha, recorded_alpha, rel_tol=1e-14, abs_tol=0.0),
             "limiting_pressure": limiting, "changed_state_components": len(changes),
             "changes": changes}
        )

    tail = [
        {key: iteration[key] for key in (
            "iteration", "scaled_norm", "scaled_max", "projected_gradient_norm", "step_norm"
        )}
        for iteration in case["iterations"][-5:]
    ]
    final = tail[-1]
    checks = {
        "last_five_norms_exactly_equal": len({row["scaled_norm"] for row in tail}) == 1,
        "last_five_gradients_exactly_equal": len({row["projected_gradient_norm"] for row in tail}) == 1,
        "last_four_steps_accepted": all(row["accepted"] for row in comparisons),
        "last_four_alphas_reproduced": all(row["alpha_matches"] for row in comparisons),
        "last_four_change_only_node1_pressure": all(
            len(row["changes"]) == 1 and row["changes"][0]["node_id"] == 1
            and row["changes"][0]["field"] == "p_Pa" for row in comparisons
        ),
        "residual_not_converged": final["scaled_max"] > solver["residual_tolerance"],
        "gradient_not_stationary": final["projected_gradient_norm"] > solver["gradient_tolerance"],
    }
    output = {
        "scope": "Read-only recorded floating-point stagnation audit; no new physical solution",
        "run_directory": str(run_directory), "candidate_hash": physics["candidate_hash"],
        "case_id": case["case_id"], "recorded_status": case["status"],
        "recorded_solver_exit": case["solver_exit_code"],
        "recorded_stopping_reason": case["stopping_reason"],
        "input_sha256": {
            "physics.json": hashlib.sha256(physics_bytes).hexdigest(),
            "physics/nominal_coarse/state_history.csv": hashlib.sha256(history_bytes).hexdigest(),
        },
        "tail_iterations": tail, "last_four_attempts": comparisons,
        "thresholds": {
            "residual_tolerance": solver["residual_tolerance"],
            "gradient_tolerance": solver["gradient_tolerance"],
            "final_scaled_max_over_tolerance": final["scaled_max"] / solver["residual_tolerance"],
            "final_gradient_over_tolerance": final["projected_gradient_norm"] / solver["gradient_tolerance"],
        },
        "checks": checks, "recorded_stagnation_reproduced": all(checks.values()),
        "physical_convergence_after_a_solver_fix": "not established by this audit",
    }
    print(json.dumps(output, ensure_ascii=False, indent=2, allow_nan=False))
    return 0 if all(checks.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
