#!/usr/bin/env python3
"""Read-only W24/N1 physics-closure diagnostic.

This tool consumes sealed W24 and N1 artifacts.  It never imports Julia, starts
DESC/mesh work, edits a run directory, or changes the task queue.  Its output
is a diagnostic handoff, not a solver acceptance receipt.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import pathlib
import sys
from datetime import datetime, timezone
from collections import defaultdict
from typing import Any, Iterable


W24_IDS = ("w24_spatial_parent_r1", "w24_spatial_g2_child_r2")
EXPECTED_PRODUCTION_SOURCE_SHA256 = (
    "cac5b47beeee2fbab7de6f171f7f155ff5534bc51edec0e66ee8caf711d6b932"
)
OBJECTIVE_DECREASE_REL_TOL = 1.0e-10
OBJECTIVE_DECREASE_ABS_TOL = 1.0e-12


class _ArtifactTracker:
    """Record every producer/source byte read by this diagnostic."""

    def __init__(self, root: pathlib.Path) -> None:
        self.root = root.resolve()
        self._records: dict[str, dict[str, Any]] = {}

    def _relative(self, path: pathlib.Path) -> str:
        try:
            return path.resolve().relative_to(self.root).as_posix()
        except ValueError:
            return str(path.resolve())

    def read_bytes(self, path: pathlib.Path) -> bytes:
        data = path.read_bytes()
        relative = self._relative(path)
        self._records[relative] = {
            "relative_path": relative,
            "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
        }
        return data

    def inventory(self) -> list[dict[str, Any]]:
        return [self._records[key] for key in sorted(self._records)]


def _read_json(path: pathlib.Path, tracker: _ArtifactTracker | None = None) -> dict[str, Any]:
    raw = tracker.read_bytes(path) if tracker else path.read_bytes()
    value = json.loads(raw.decode("utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def _read_csv(path: pathlib.Path, tracker: _ArtifactTracker | None = None) -> list[dict[str, str]]:
    raw = tracker.read_bytes(path) if tracker else path.read_bytes()
    return list(csv.DictReader(raw.decode("utf-8").splitlines()))


def _read_text(path: pathlib.Path, tracker: _ArtifactTracker | None = None) -> str:
    raw = tracker.read_bytes(path) if tracker else path.read_bytes()
    return raw.decode("utf-8")


def _sha256(path: pathlib.Path, tracker: _ArtifactTracker | None = None) -> str:
    raw = tracker.read_bytes(path) if tracker else path.read_bytes()
    return hashlib.sha256(raw).hexdigest()


def _float(value: Any) -> float:
    return float(value)


def _finite(value: Any) -> bool:
    return isinstance(value, (int, float)) and math.isfinite(float(value))


def _block_stats(rows: Iterable[dict[str, str]]) -> dict[str, dict[str, Any]]:
    blocks: dict[str, list[tuple[float, float, int]]] = defaultdict(list)
    for row in rows:
        required = ("row", "block", "residual", "declared_scale")
        if any(field not in row or row[field] in (None, "") for field in required):
            raise ValueError("residual row is missing row/block/residual/declared_scale")
        block = row["block"]
        residual = _float(row["residual"])
        scale = _float(row["declared_scale"])
        if not block or not (_finite(residual) and _finite(scale)) or scale <= 0.0:
            raise ValueError("non-finite or non-positive residual scale")
        blocks[block].append((residual, scale, int(row["row"])))
    result: dict[str, dict[str, Any]] = {}
    for block, values in blocks.items():
        scaled = [abs(residual / scale) for residual, scale, _ in values]
        absolute = [abs(residual) for residual, _, _ in values]
        squared = sum(value * value for value in scaled)
        max_i = max(range(len(values)), key=lambda i: scaled[i])
        max_abs_i = max(range(len(values)), key=lambda i: absolute[i])
        result[block] = {
            "rows": len(values),
            "scaled_l2": math.sqrt(squared),
            "objective_share": squared,
            "scaled_max": scaled[max_i],
            "scaled_max_row": values[max_i][2],
            "absolute_max": absolute[max_abs_i],
            "absolute_max_row": values[max_abs_i][2],
            "scale_min": min(scale for _, scale, _ in values),
            "scale_max": max(scale for _, scale, _ in values),
        }
    total = sum(item["objective_share"] for item in result.values())
    for item in result.values():
        item["objective_share"] = item["objective_share"] / total if total else 0.0
    return result


def _jacobian_shape(path: pathlib.Path, tracker: _ArtifactTracker | None = None) -> dict[str, Any]:
    rows = _read_csv(path, tracker)
    if not rows:
        raise ValueError(f"empty Jacobian artifact: {path}")
    row_ids = {int(row["row"]) for row in rows}
    column_ids = {int(row["column"]) for row in rows}
    return {
        "entries": len(rows),
        "rows": len(row_ids),
        "columns": len(column_ids),
        "value_abs_min": min((abs(_float(row["value"])) for row in rows), default=0.0),
        "value_abs_max": max((abs(_float(row["value"])) for row in rows), default=0.0),
    }


def _solver_summary(path: pathlib.Path, tracker: _ArtifactTracker | None = None) -> dict[str, Any]:
    artifact = _read_json(path, tracker)
    last = artifact.get("last_attempt", {})
    rank = last.get("linear_rank_diagnostics", {})
    attempts = artifact.get("attempts", [])
    if not isinstance(attempts, list):
        raise ValueError(f"solver attempts is not a list: {path}")
    accepted = [attempt for attempt in attempts if attempt.get("accepted")]
    if artifact.get("attempt_count") != len(attempts):
        raise ValueError(f"solver attempt count mismatch: {path}")
    if artifact.get("accepted_update_count") != len(accepted):
        raise ValueError(f"solver accepted count mismatch: {path}")
    for attempt in accepted:
        objective_before = attempt.get("objective_before")
        objective_after = attempt.get("objective_after")
        objective_decrease = attempt.get("objective_decrease")
        objective_delta_consistent = (
            _finite(objective_before)
            and _finite(objective_after)
            and _finite(objective_decrease)
            and math.isclose(
                float(objective_decrease),
                float(objective_before) - float(objective_after),
                rel_tol=OBJECTIVE_DECREASE_REL_TOL,
                abs_tol=OBJECTIVE_DECREASE_ABS_TOL,
            )
        )
        strict = (
            attempt.get("progress_classification") == "accepted_strict_decrease"
            and attempt.get("strict_objective_decrease") is True
            and attempt.get("scaled_state_change") is True
            and _finite(attempt.get("accepted_alpha"))
            and float(attempt.get("accepted_alpha")) > 0.0
            and objective_delta_consistent
            and float(objective_after) < float(objective_before)
        )
        if not strict:
            raise ValueError(
                f"accepted solver attempt is not a strict finite decrease or has inconsistent "
                f"objective_decrease (rtol={OBJECTIVE_DECREASE_REL_TOL}, "
                f"atol={OBJECTIVE_DECREASE_ABS_TOL}): {path}"
            )
    alphas = [attempt.get("accepted_alpha") for attempt in accepted]
    return {
        "attempt_count": artifact.get("attempt_count"),
        "accepted_update_count": artifact.get("accepted_update_count"),
        "accepted_all_strict_decrease": all(
            attempt.get("progress_classification") == "accepted_strict_decrease"
            for attempt in accepted
        ),
        "accepted_alpha_min": min((float(a) for a in alphas if a is not None), default=None),
        "accepted_alpha_max": max((float(a) for a in alphas if a is not None), default=None),
        "last": {
            key: last.get(key)
            for key in (
                "iteration",
                "accepted",
                "accepted_alpha",
                "direction",
                "objective_before",
                "objective_after",
                "objective_decrease",
                "linear_relative_residual",
                "progress_classification",
                "proposed_step_norm",
                "scaled_state_change",
            )
        },
        "rank": {
            key: rank.get(key)
            for key in (
                "method",
                "rows",
                "columns",
                "rank_estimate",
                "nullity_estimate",
                "diagonal_min",
                "diagonal_max",
                "relative_tolerance",
                "physical_closure",
                "continuum_uniqueness",
            )
        },
        "bound_active_count": len(last.get("bound_active_indices", [])),
        "free_column_count": len(last.get("free_columns", [])),
    }


def summarize_case(case_dir: pathlib.Path, case_id: str, tracker: _ArtifactTracker | None = None) -> dict[str, Any]:
    physics_dir = case_dir / "physics" / case_id
    rows = _read_csv(physics_dir / "residual_rows.csv", tracker)
    residual_stats = _block_stats(rows)
    scaled_values = [float(row["residual"]) / float(row["declared_scale"]) for row in rows]
    scaled_l2 = math.sqrt(sum(item["scaled_l2"] ** 2 for item in residual_stats.values()))
    attempts = _solver_summary(physics_dir / "solver_attempts.json", tracker)
    jacobian = _jacobian_shape(physics_dir / "full_jacobian.csv", tracker)
    exit_code = int(_read_text(physics_dir / "solver.exitcode", tracker).strip())
    iterations = _read_csv(physics_dir / "iterations.csv", tracker)
    final_iteration = iterations[-1] if iterations else {}
    if exit_code == 0 and not iterations:
        raise ValueError(f"exit 0 with missing/empty iterations artifact: {physics_dir}")
    if exit_code == 0:
        terminal_scaled_max = final_iteration.get("scaled_max")
        try:
            terminal_scaled_max = float(terminal_scaled_max)
        except (TypeError, ValueError):
            terminal_scaled_max = None
        if not _finite(terminal_scaled_max) or abs(float(terminal_scaled_max)) > 1.0e-6:
            raise ValueError(
                f"exit 0 without finite terminal scaled residual <= 1e-6: {physics_dir}"
            )
    return {
        "case_id": case_id,
        "solver_exit_code": exit_code,
        "status": "converged" if exit_code == 0 and iterations else "fail",
        "row_count": len(rows),
        "scaled_l2": scaled_l2,
        "scaled_max": max((abs(value) for value in scaled_values), default=0.0),
        "residual_blocks": residual_stats,
        "jacobian": jacobian,
        "solver": attempts,
        "final_iteration": final_iteration,
        "residual_gate": 1.0e-6,
        "gate_pass": exit_code == 0 and bool(iterations) and abs(float(final_iteration.get("scaled_max", 0.0))) <= 1.0e-6,
    }


def _metadata_case_ids(result: dict[str, Any], physics: dict[str, Any], verification: dict[str, Any], execution_manifest: dict[str, Any]) -> dict[str, list[str]]:
    result_ids: list[str] = []
    for stage in result.get("stages", []):
        if stage.get("stage") == "spatial_multiregion":
            result_ids = [item["case_id"] for item in stage.get("metrics", {}).get("cases", [])]
            break
    physics_ids = [item["case_id"] for item in physics.get("cases", [])]
    verification_ids = [item["case_id"] for item in verification.get("cases", [])]
    manifest_ids: set[str] = set()
    for item in execution_manifest.get("artifacts", []):
        path = str(item.get("path", "")).replace("\\", "/")
        parts = path.split("/")
        for marker in ("physics", "verification"):
            if marker in parts:
                index = parts.index(marker)
                leaf = parts[-1]
                is_case_artifact = (
                    marker == "physics" and leaf in {"residual_rows.csv", "solver_attempts.json"}
                ) or (
                    marker == "verification" and leaf in {"metrics.csv", "actual_residual.csv"}
                )
                if index + 1 < len(parts) and is_case_artifact:
                    manifest_ids.add(parts[index + 1])
    return {
        "result": result_ids,
        "physics": physics_ids,
        "verification": verification_ids,
        "execution_manifest": sorted(manifest_ids),
    }


def _physical_artifact_inventory(
    run_dir: pathlib.Path,
    execution_manifest: dict[str, Any],
    expected_case_ids: tuple[str, ...],
    run_id: str,
) -> dict[str, Any]:
    physics_root = run_dir / "physics"
    if not physics_root.is_dir():
        raise ValueError(f"missing physical artifact directory for {run_id}: {physics_root}")
    actual_directories = sorted(item.name for item in physics_root.iterdir() if item.is_dir())
    registered: dict[str, set[str]] = defaultdict(set)
    for item in execution_manifest.get("artifacts", []):
        raw_path = item.get("path")
        if not raw_path:
            continue
        parts = str(raw_path).replace(chr(92), "/").split("/")
        if "physics" not in parts:
            continue
        physics_index = parts.index("physics")
        if physics_index + 2 < len(parts):
            registered[parts[physics_index + 1]].add(parts[-1])
    registered_directories = sorted(registered)
    if actual_directories != registered_directories:
        raise ValueError(
            f"physical directory registration mismatch for {run_id}: "
            f"actual={actual_directories}, registered={registered_directories}"
        )
    actual_case_ids = sorted(item for item in actual_directories if item != "geometry")
    expected = sorted(expected_case_ids)
    if actual_case_ids != expected:
        raise ValueError(
            f"physical case directory mismatch for {run_id}: actual={actual_case_ids}, expected={expected}"
        )
    artifacts: dict[str, list[str]] = {}
    for directory in actual_directories:
        actual_files = sorted(item.name for item in (physics_root / directory).iterdir() if item.is_file())
        registered_files = sorted(registered[directory])
        if actual_files != registered_files:
            raise ValueError(
                f"physical artifact registration mismatch for {run_id}/{directory}: "
                f"actual={actual_files}, registered={registered_files}"
            )
        artifacts[directory] = actual_files
    return {
        "directories": actual_directories,
        "case_directories": actual_case_ids,
        "artifacts": artifacts,
    }


def _checked_case_ids(case_sets: dict[str, list[str]], run_id: str) -> tuple[str, ...]:
    normalized = {name: tuple(sorted(set(values))) for name, values in case_sets.items()}
    if any(not values for values in normalized.values()):
        raise ValueError(f"missing case enumeration in W24 metadata for {run_id}: {normalized}")
    expected = next(iter(normalized.values()))
    if any(values != expected for values in normalized.values()):
        raise ValueError(f"W24 case-set mismatch for {run_id}: {normalized}")
    return expected


def _load_w24_pair(root: pathlib.Path, tracker: _ArtifactTracker) -> dict[str, Any]:
    runs = root / "runs" / "goal_recovery_20260913_012528_cst"
    pair: dict[str, Any] = {"cases": {}, "pair": {}}
    run_case_sets: dict[str, dict[str, list[str]]] = {}
    for run_id in W24_IDS:
        run_dir = runs / run_id
        result = _read_json(run_dir / "result.json", tracker)
        physics = _read_json(run_dir / "physics.json", tracker)
        verification = _read_json(run_dir / "verification.json", tracker)
        execution_manifest = _read_json(run_dir / "execution_manifest.json", tracker)
        case_sets = _metadata_case_ids(result, physics, verification, execution_manifest)
        case_ids = _checked_case_ids(case_sets, run_id)
        physical_inventory = _physical_artifact_inventory(run_dir, execution_manifest, case_ids, run_id)
        run_case_sets[run_id] = case_sets
        pair["cases"][run_id] = {
            "candidate_hash": result.get("candidate_hash", {}).get("value"),
            "context_hash": result.get("context_hash", {}).get("value"),
            "result_status": result.get("status"),
            "physical_validation": result.get("physical_validation"),
            "solver_exit_code": result.get("stages", [{}])[2].get("exit_code"),
            "verification_status": verification.get("status"),
            "verification_exit_code": verification.get("solver_exit_code"),
            "physical_inventory": physical_inventory,
            "cases": {
                case_id: summarize_case(run_dir, case_id, tracker) for case_id in case_ids
            },
        }
    parent_case_ids = tuple(pair["cases"][W24_IDS[0]]["cases"])
    child_case_ids = tuple(pair["cases"][W24_IDS[1]]["cases"])
    if parent_case_ids != child_case_ids:
        raise ValueError(f"W24 parent/child case-set mismatch: {parent_case_ids} vs {child_case_ids}")
    parent = pair["cases"][W24_IDS[0]]
    child = pair["cases"][W24_IDS[1]]
    comparisons = {}
    for case_id in parent_case_ids:
        p = parent["cases"][case_id]
        c = child["cases"][case_id]
        comparisons[case_id] = {
            "scaled_l2_delta_child_minus_parent": c["scaled_l2"] - p["scaled_l2"],
            "scaled_max_delta_child_minus_parent": c["scaled_max"] - p["scaled_max"],
            "solver_exit_equal": c["solver_exit_code"] == p["solver_exit_code"],
            "block_scaled_max_delta": {
                block: c["residual_blocks"][block]["scaled_max"]
                - p["residual_blocks"][block]["scaled_max"]
                for block in p["residual_blocks"]
                if block in c["residual_blocks"]
            },
        }
    pair["pair"] = {
        "candidate_identity_differs": parent["candidate_hash"] != child["candidate_hash"],
        "context_identity_differs": parent["context_hash"] != child["context_hash"],
        "comparisons": comparisons,
        "pair_audit": _read_json(runs / W24_IDS[1] / "w24_spatial_g2_pair_audit_attempt.json", tracker),
        "manifest_audit": _read_json(runs / W24_IDS[1] / "w24_spatial_manifest_audit.json", tracker),
        "case_sets": run_case_sets,
    }
    return pair


def _observed_order(e_left: float, e_right: float, h_left: float, h_right: float) -> float | None:
    if min(e_left, e_right, h_left, h_right) <= 0:
        return None
    return math.log(e_left / e_right) / math.log(h_left / h_right)


def _producer_expected_n1_perturbation_indices(source: dict[str, Any]) -> set[int]:
    observed_orders = source.get("observed_orders")
    if not isinstance(observed_orders, list) or not observed_orders:
        raise ValueError("N1 result has no producer observed-order metadata")
    expected: set[int] = set()
    for item in observed_orders:
        try:
            index = int(item["perturbation_index"])
        except (KeyError, TypeError, ValueError) as exc:
            raise ValueError("N1 observed-order metadata has an invalid perturbation index") from exc
        if not _finite(item.get("observed_order")):
            raise ValueError(f"N1 observed-order metadata has non-finite order: perturbation {index}")
        expected.add(index)
    if not expected:
        raise ValueError("N1 producer metadata declares no perturbation indices")
    return expected


def _validate_n1_perturbation_set(source: dict[str, Any], actual: set[int]) -> set[int]:
    expected = _producer_expected_n1_perturbation_indices(source)
    if actual != expected:
        raise ValueError(
            "N1 perturbation-set mismatch: "
            f"result={sorted(actual)}, producer_observed_orders={sorted(expected)}"
        )
    return expected


def _load_n1(root: pathlib.Path, tracker: _ArtifactTracker) -> dict[str, Any]:
    path = root / "runs" / "goal_recovery_20260913_012528_cst" / "n1_refined_family_r1" / "result.json"
    source = _read_json(path, tracker)
    resolutions = {item["level"]: item for item in source.get("resolutions", [])}
    if not resolutions:
        raise ValueError("N1 result has no resolution manifest")
    groups: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for item in source.get("results", []):
        if item.get("level") not in resolutions:
            raise ValueError(f"N1 result level is absent from resolution manifest: {item.get('level')}")
        if item.get("all_accepted_updates_strict") is not True:
            raise ValueError("N1 result contains a non-strict accepted-update claim")
        groups[int(item["perturbation_index"])].append(item)
    if not groups:
        raise ValueError("N1 result has no perturbation results")
    expected_perturbation_indices = _validate_n1_perturbation_set(source, set(groups))
    expected_pairs = len(resolutions) * len(groups)
    if len(source.get("results", [])) != expected_pairs:
        raise ValueError(
            f"N1 result completeness mismatch: got {len(source.get('results', []))}, expected {expected_pairs}"
        )
    for index, values in groups.items():
        levels = {item["level"] for item in values}
        if levels != set(resolutions) or len(values) != len(resolutions):
            raise ValueError(f"N1 perturbation {index} does not cover every declared resolution")
        for item in values:
            for field in ("h", "solution_relative_error", "scaled_residual_max", "truth_scaled_residual_max"):
                if not _finite(item.get(field)):
                    raise ValueError(f"N1 result has non-finite {field}: perturbation {index}")
    perturbations: dict[str, Any] = {}
    for index, values in groups.items():
        ordered = sorted(values, key=lambda item: item["h"], reverse=True)
        pairs = []
        for left, right in zip(ordered, ordered[1:]):
            order = _observed_order(left["solution_relative_error"], right["solution_relative_error"], left["h"], right["h"])
            pairs.append({
                "from_level": left["level"],
                "to_level": right["level"],
                "from_h": left["h"],
                "to_h": right["h"],
                "from_error": left["solution_relative_error"],
                "to_error": right["solution_relative_error"],
                "from_truth_scaled_residual_max": left["truth_scaled_residual_max"],
                "to_truth_scaled_residual_max": right["truth_scaled_residual_max"],
                "from_solver_residual_max": left["scaled_residual_max"],
                "to_solver_residual_max": right["scaled_residual_max"],
                "solver_exits": [left["solver_exit_code"], right["solver_exit_code"]],
                "observed_order_recomputed": order,
                "error_decreases": right["solution_relative_error"] < left["solution_relative_error"],
            })
        perturbations[str(index)] = {
            "levels": [
                {
                    "level": item["level"],
                    "h": item["h"],
                    "unknowns": resolutions.get(item["level"], {}).get("unknowns"),
                    "solver_exit_code": item["solver_exit_code"],
                    "accepted_update_count": item["accepted_update_count"],
                    "all_accepted_updates_strict": item["all_accepted_updates_strict"],
                    "solution_relative_error": item["solution_relative_error"],
                    "scaled_residual_max": item["scaled_residual_max"],
                    "truth_scaled_residual_max": item["truth_scaled_residual_max"],
                }
                for item in ordered
            ],
            "pairs": pairs,
            "asymptotic_candidate": all(pair["error_decreases"] and (pair["observed_order_recomputed"] or 0.0) > 0 for pair in pairs),
        }
    return {
        "benchmark": source.get("benchmark"),
        "max_iterations": source.get("max_iterations"),
        "production_source_sha256": source.get("production_source_sha256"),
        "source_sha256": source.get("source_sha256"),
        "numerical_only": source.get("numerical_only"),
        "physical_validation": source.get("physical_validation"),
        "declared_levels": sorted(resolutions),
        "declared_perturbation_indices": sorted(groups),
        "producer_expected_perturbation_indices": sorted(expected_perturbation_indices),
        "perturbation_set_source": "result.observed_orders[].perturbation_index",
        "result_count": len(source.get("results", [])),
        "perturbations": perturbations,
        "asymptotic_region_established": bool(perturbations) and all(
            item["asymptotic_candidate"] for item in perturbations.values()
        ),
    }


def _causal_assessment(pair: dict[str, Any], n1: dict[str, Any], source_hash: str | None) -> dict[str, Any]:
    all_cases = [pair["cases"][run_id]["cases"] for run_id in W24_IDS]
    case_ids = tuple(pair["cases"][W24_IDS[0]]["cases"])
    last = [cases[case]["solver"]["last"] for cases in all_cases for case in case_ids]
    accepted_total = sum(
        cases[case]["solver"].get("accepted_update_count", 0)
        for cases in all_cases
        for case in case_ids
    )
    return {
        "model": {
            "classification": "confirmed_gap",
            "evidence": [
                "all W24 solver rank diagnostics retain physical_closure=pressure_current_topology_not_fixed",
                "all W24 result stages retain missing_model for pressure/current topology, transport/time evolution and external closure",
                "both runs retain external current closure unknown and physical_validation unsupported",
            ],
            "repair": "candidate-owned pressure profile plus one compatible iota/current/topology selector, then a candidate-bound exterior vacuum/coil/return-current provider",
        },
        "boundary": {
            "classification": "unresolved_compatibility_check",
            "evidence": [
                "assembly adds reference traction and B.n=0 exterior moments while also carrying natural cell-face terms",
                "artifacts do not provide a separated natural-vs-exterior consistency audit",
            ],
            "repair": "separate exterior load/moment blocks and quantify compatibility before changing solver controls",
        },
        "discretization": {
            "classification": "not_proven_not_confirmed_defect",
            "evidence": [
                "fine meshes have different row/unknown counts and lower residuals, but no converged physical mesh-error estimate exists",
                "N1 has a nonmonotone h=1/4 to h=1/5 state error and therefore no asymptotic region",
            ],
            "repair": "use a matched nested manufactured family with tighter residual-to-error separation and independent mesh-order checker",
        },
        "scale": {
            "classification": "declared_scale_is_finite_but_weighting_requires_audit",
            "evidence": [
                "all residual scales are finite and nonzero; block scale ranges follow volume/face measures",
                "W24 objective shares are dominated by divB on coarse and momentum on fine; this is a weighting observation, not proof of a scaling bug",
            ],
            "repair": "add a read-only block scale/units audit and report conditioning; do not silently retune scales or the 1e-6 gate",
        },
        "algorithm": {
            "classification": "confirmed_iteration_limit_with_small_progress_not_code_failure",
            "evidence": [
                f"W24 has {accepted_total} accepted updates in final artifacts; each retained accepted attempt is classified accepted_strict_decrease",
                "W24 exits are iteration_limit/exit 4; final linear relative residuals remain roughly 0.47-0.98 and accepted alpha can be O(1e-5)",
                "N1 exits 0 with strict accepted updates, so adding iterations alone is not a demonstrated remedy for the negative order",
            ],
            "repair": "record condition/active-set and residual-to-state-error diagnostics, then fix model/constraint compatibility; do not use more iterations as the repair",
        },
        "capability": {
            "classification": "terminal_deferred",
            "evidence": [
                "external B_out, outer K and return current are unknown; source_closure_certified=false",
                "physical validation and engineering applicability remain unsupported",
            ],
            "repair": "queue the formal coupled-solve work only after selector/boundary/exterior provider inputs are frozen",
        },
        "source_hash_current": source_hash,
        "source_hash_matches_n1_receipt": source_hash == n1.get("production_source_sha256"),
        "expected_source_hash_matches": source_hash == EXPECTED_PRODUCTION_SOURCE_SHA256,
    }


def analyze(root: pathlib.Path) -> dict[str, Any]:
    tracker = _ArtifactTracker(root)
    source_path = root / "src" / "RuntimeV4" / "SpatialMultiRegionV4.jl"
    if not source_path.is_file():
        raise FileNotFoundError(source_path)
    pair = _load_w24_pair(root, tracker)
    n1 = _load_n1(root, tracker)
    source_hash = _sha256(source_path, tracker)
    inventory = tracker.inventory()
    inventory_digest = hashlib.sha256(
        json.dumps(inventory, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    return {
        "schema": "up2-04-physics-closure-diagnostic-v1",
        "execution_state": "read_only_analysis",
        "source": {
            "path": str(source_path),
            "sha256": source_hash,
            "n1_receipt_sha256": n1.get("production_source_sha256"),
        },
        "producer_artifacts": {
            "count": len(inventory),
            "files": inventory,
            "inventory_sha256": inventory_digest,
            "binding": "Every W24/N1 metadata, residual, Jacobian, solver, iteration, audit and source file read by this analyzer is listed with relative_path, bytes and SHA256.",
        },
        "inputs": {
            "w24": [str(root / "runs" / "goal_recovery_20260913_012528_cst" / run_id) for run_id in W24_IDS],
            "n1": str(root / "runs" / "goal_recovery_20260913_012528_cst" / "n1_refined_family_r1" / "result.json"),
        },
        "w24": pair,
        "n1": n1,
        "causal_assessment": _causal_assessment(pair, n1, source_hash),
        "acceptance_boundary": {
            "formal_up2_04_closed": False,
            "physical_credit": 0,
            "threshold_changed": False,
            "unknowns_fixed": False,
            "old_runs_overwritten": False,
            "queue_required": True,
        },
    }


def _markdown(report: dict[str, Any]) -> str:
    pair = report["w24"]
    lines = [
        "# UP2-04 physics-closure diagnostic (read-only)",
        "",
        "This report analyses sealed W24 parent/child and N1 artifacts. It does not rerun Julia/DESC/mesh, change source, or accept formal UP2-04.",
        "",
        f"- production source SHA-256: `{report['source']['sha256']}`",
        f"- source matches N1 receipt: `{report['causal_assessment']['source_hash_matches_n1_receipt']}`",
        f"- N1 asymptotic region established: `{report['n1']['asymptotic_region_established']}`",
        f"- accepted objective decrease consistency: `objective_decrease == objective_before - objective_after` within rtol `{OBJECTIVE_DECREASE_REL_TOL}` and atol `{OBJECTIVE_DECREASE_ABS_TOL}`",
        "",
        "## Producer artifact binding",
        "",
        "Complete byte-level read set used by this analyzer; paths are relative to the repository root and bound by bytes and SHA-256.",
        "",
        "| relative path | bytes | SHA-256 |",
        "|---|---:|---|",
    ]
    for artifact in report["producer_artifacts"]["files"]:
        lines.append(f"| `{artifact['relative_path']}` | {artifact['bytes']} | `{artifact['sha256']}` |")
    lines += [
        "",
        "Independent physical-directory registration passed: every `physics/` directory and every file beneath it matched the execution-manifest registration; case directories also matched result/physics/verification metadata.",
    ]
    for run_id in W24_IDS:
        physical_inventory = pair["cases"][run_id]["physical_inventory"]
        lines.append(
            f"- `{run_id}` physical directories: `{', '.join(physical_inventory['directories'])}`; case directories: `{', '.join(physical_inventory['case_directories'])}`."
        )
    case_ids = tuple(pair["cases"][W24_IDS[0]]["cases"])
    lines += [
        "",
        "## W24 cases",
        "",
        "| run | case | exit | scaled L2 | scaled max | dominant block | rank estimate / free cols | active bounds | last alpha | linear residual |",
        "|---|---|---:|---:|---:|---|---:|---:|---:|---:|",
    ]
    for run_id in W24_IDS:
        for case_id in case_ids:
            case = pair["cases"][run_id]["cases"][case_id]
            dominant = max(case["residual_blocks"].items(), key=lambda item: item[1]["objective_share"])[0]
            solver = case["solver"]
            last = solver["last"]
            lines.append(
                f"| `{run_id}` | `{case_id}` | {case['solver_exit_code']} | {case['scaled_l2']:.6g} | {case['scaled_max']:.6g} | `{dominant}` | {solver['rank'].get('rank_estimate')} / {solver['free_column_count']} | {solver['bound_active_count']} | {last.get('accepted_alpha')} | {last.get('linear_relative_residual')} |"
            )
    lines += [
        "",
        f"W24 is a consistent {len(case_ids)}-case terminal non-convergence: every case exits 4, all saved updates are strict decreases, but the final max residual is far above `1e-6`. Full free-column QR rank estimates do not establish continuum uniqueness or closure; all diagnostics retain `pressure_current_topology_not_fixed`.",
        "",
        "## Parent-child comparison",
        "",
        "The child changes candidate/context identity and has the same terminal exit behavior. Its paired audit itself failed closed because the source-record set differs; therefore this is a numerical comparison, not independent paired physical evidence.",
        "",
        "| case | child-parent scaled L2 | child-parent scaled max |",
        "|---|---:|---:|",
    ]
    for case_id, comparison in pair["pair"]["comparisons"].items():
        lines.append(f"| `{case_id}` | {comparison['scaled_l2_delta_child_minus_parent']:.6g} | {comparison['scaled_max_delta_child_minus_parent']:.6g} |")
    lines += [
        "",
        "## N1 manufactured grid check",
        "",
        f"N1 expected perturbation set is producer-bound from `result.observed_orders[].perturbation_index`: `{report['n1']['producer_expected_perturbation_indices']}`; observed result set: `{report['n1']['declared_perturbation_indices']}`.",
        "",
        "| perturbation | pair | errors (from → to) | truth residual max (from → to) | recomputed order |",
        "|---:|---|---:|---:|---:|",
    ]
    for index, item in report["n1"]["perturbations"].items():
        for pair_item in item["pairs"]:
            lines.append(
                f"| {index} | `{pair_item['from_level']}→{pair_item['to_level']}` | {pair_item['from_error']:.6g} → {pair_item['to_error']:.6g} | {pair_item['from_truth_scaled_residual_max']:.6g} → {pair_item['to_truth_scaled_residual_max']:.6g} | {pair_item['observed_order_recomputed']:.6g} |"
            )
    lines += [
        "",
        "The `h=1/4→1/5` error is nonmonotone for perturbation 1, producing order `-6.157952975...`; positive orders in the other pairs do not establish an asymptotic regime. N1 is numerical-only and does not provide physical validation.",
        "",
        "## Causal classification and handoff",
        "",
        "- **Model/closure (confirmed):** pressure/current topology selector and exterior current/field closure are absent; this is the principal W24 blocker.",
        "- **Boundary (unresolved):** reference traction plus `B.n=0` exterior moments need a separated compatibility audit; no threshold or boundary is changed here.",
        "- **Discretization (not proven defective):** no converged physical mesh error exists; N1 rejects a grid-order claim.",
        "- **Scale (audit required):** scales are finite and measure-based; objective block dominance is an observation, not proof of a scaling bug.",
        "- **Algorithm (confirmed terminal behavior):** iteration limit with strict decreases and high linear residual; more iterations alone is not a repair.",
        "- **Capability (terminal deferred):** external `B_out`/`K_outer`/return current and physical validation are unavailable.",
        "",
        "## Suggested next writes (not performed)",
        "",
        "1. Formal UP2-04 should add candidate-owned pressure and iota/current/topology inputs, then a candidate-bound exterior vacuum/coil/return-current provider.",
        "2. A permitted source patch may instrument `_smr_row_scales` with units/block-scale audits, `assemble_spatial_system_v4` with separate natural/exterior residual blocks, and `solve_spatial_state_v4` with condition/active-set/residual-to-state-error diagnostics. No source defect was proven by this read-only pass.",
        "3. Only after a new protocol and authorization may `runtime_v4_manufactured_recovery_benchmark.jl` report tighter residual-vs-state-error diagnostics; do not alter the `1e-6` gate or hide residual blocks.",
        "",
        "## Minimal commands",
        "",
        "Positive (read-only): `python -B tools/up2_04_physics_closure_diagnostic.py --root . --json-out docs/implementation/UP2-04-PHYSICS-CLOSURE-DIAGNOSTIC/agent_local_r1/diagnostic.json --markdown-out docs/implementation/UP2-04-PHYSICS-CLOSURE-DIAGNOSTIC/agent_local_r1/diagnostic.md`",
        "Negative (missing input, expected non-zero): `python -B tools/up2_04_physics_closure_diagnostic.py --root .\\missing-up2-04-input --strict`",
        "",
        "Queue: **required** for formal UP2-04 coupled-solve repair/acceptance; this diagnostic is complete without running the heavy cross-mesh queue.",
    ]
    return "\n".join(lines) + "\n"


def _receipt_manifest(report: dict[str, Any], command: str, pid_utc: str, raw_hashes: dict[str, Any] | None = None) -> dict[str, Any]:
    raw_hashes = raw_hashes or {}
    contract_refs = [
        "docs/v4_multitopology_generation/README.md",
        "docs/v4_multitopology_generation/00_normative_contracts_and_state_model.md",
        "docs/v4_multitopology_generation/22_agent_local_execution.md",
        "docs/v4_multitopology_generation/14_agent_orchestration.md",
        "docs/v4_multitopology_generation/16_execution_work_orders.md",
        "docs/v4_multitopology_generation/21_next_execution_batches.md",
        "docs/v4_multitopology_generation/11_physics_compilation_and_discretization.md",
        "docs/v4_multitopology_generation/13_acceptance_benchmarks_and_evidence.md",
        "docs/v4_multitopology_generation/17_luna_worker_prompt.md",
    ]
    return {
        "schema": "up2-04-physics-closure-diagnostic-handoff-v2",
        "task_id": "UP2-04-PHYSICS-CLOSURE-DIAGNOSTIC",
        "receipt_profile": "preparation",
        "role": "implementer",
        "requested_model": "gpt-5.6-luna",
        "requested_reasoning_effort": "high",
        "actual_model": "gpt-5.6-luna",
        "actual_reasoning_effort": "high",
        "base_commit": "63792ca22958ffca8c3fa8e642256eb9f7240724",
        "contract_refs": contract_refs,
        "input_hashes": {
            "production_source_sha256": report["source"]["sha256"],
            "producer_inventory_sha256": report["producer_artifacts"]["inventory_sha256"],
        },
        "changed_paths": [
            "tools/up2_04_physics_closure_diagnostic.py",
            "test/RuntimeV4/up2_04_physics_closure_diagnostic_tests.py",
            "docs/implementation/UP2-04-PHYSICS-CLOSURE-DIAGNOSTIC/agent_local_r1/",
        ],
        "protected_paths": [
            "src/RuntimeV4/SpatialMultiRegionV4.jl",
            "scripts/runtime_v4_manufactured_recovery_benchmark.jl",
            "runs/goal_recovery_20260913_012528_cst/",
            "task_queue/",
        ],
        "capability_gap": "W24 four-case coupled spatial solve remains non-converged; N1 has no credible mesh-order regime; pressure/current topology and exterior current closure are unresolved",
        "producer": "sealed W24 parent/child result, physics, verification and execution-manifest artifacts plus N1 refined-family result",
        "consumer": "formal UP2-04 coupled-solve repair and acceptance input",
        "shared_entry": "read-only artifact loader -> causal comparison -> diagnostic handoff",
        "producer_artifacts": report["producer_artifacts"],
        "consumer_receipt": {
            "status": "not_executed",
            "reason": "formal UP2-04 coupled-solve consumer is outside this preparation diagnostic",
            "entry_symbol": "formal UP2-04 coupled solve",
            "input_hashes_ref": "producer_artifacts.files",
            "output_hashes_ref": None,
            "trace_and_raw_log_ref": None,
        },
        "genome_bundle": {
            "status": "not_applicable",
            "reason": "this preparation diagnostic does not produce or modify G1/G2/G3 Genome bodies",
            "candidate_identity_ref": report["w24"]["cases"][W24_IDS[0]]["candidate_hash"],
            "g1": {"status": "not_applicable", "reason": "outside scope"},
            "g2": {"status": "not_applicable", "reason": "outside scope"},
            "g3": {"status": "not_applicable", "reason": "outside scope"},
        },
        "inverse_observations": {
            "status": "not_applicable",
            "reason": "no reference inverse or observation data are produced",
        },
        "identifiability": {
            "status": "not_executed",
            "reason": "Jacobian rank metadata is diagnosed but no inverse identifiability run is performed",
        },
        "common_forward_receipt": {
            "status": "not_executed",
            "reason": "formal common-forward consumer is not run in this read-only phase",
            "entry_symbol": None,
            "genome_input_hashes_ref": None,
            "run_receipt_ref": None,
        },
        "heldout_prediction": {
            "status": "not_applicable",
            "reason": "no held-out reference prediction belongs to this diagnostic",
        },
        "commands": [
            {
                "command": command,
                "cwd": str(pathlib.Path.cwd()),
                "pid_utc": pid_utc,
                "exit_code": 0,
                "raw_artifact_hashes": raw_hashes,
            }
        ],
        "execution_state": "read_only_analysis",
        "numerical_state": "diagnosed_not_repaired",
        "physical_state": "terminal_deferred",
        "engineering_state": "not_applicable_to_this_diagnostic",
        "same_chain_call_observed": False,
        "producer_consumer_shared_entry": "pass_for_read_only_diagnostic; formal_solver_consumer_not_executed",
        "program_state": "pass",
        "remaining": [
            "freeze candidate-owned pressure/current topology selector",
            "resolve natural-load versus exterior-moment compatibility",
            "provide candidate-bound exterior B_out, K_outer and return-current closure",
            "run a new authorized coupled-solve repair and independent acceptance",
            "establish a matched manufactured mesh-order protocol with residual-to-state-error diagnostics",
        ],
        "acceptance_boundary": {
            "formal_up2_04_closed": False,
            "physical_credit": 0,
            "threshold_changed": False,
            "unknowns_fixed": False,
            "old_runs_overwritten": False,
            "queue_required": True,
        },
        "parent_goal_complete": False,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=pathlib.Path, default=pathlib.Path("."))
    parser.add_argument("--json-out", type=pathlib.Path)
    parser.add_argument("--markdown-out", type=pathlib.Path)
    parser.add_argument("--manifest-out", type=pathlib.Path)
    parser.add_argument("--raw-stdout", type=pathlib.Path)
    parser.add_argument("--raw-stderr", type=pathlib.Path)
    parser.add_argument("--strict", action="store_true", help="fail closed on missing artifacts")
    args = parser.parse_args(argv)
    try:
        report = analyze(args.root.resolve())
        markdown = _markdown(report)
        json_text = json.dumps(report, indent=2, sort_keys=True) + "\n"
        pid_utc = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z") + f";pid={os.getpid()}"
        command = "python -B " + " ".join(str(item) for item in sys.argv)
        if args.json_out:
            args.json_out.parent.mkdir(parents=True, exist_ok=True)
            args.json_out.write_text(json_text, encoding="utf-8")
        if args.markdown_out:
            args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
            args.markdown_out.write_text(markdown, encoding="utf-8")
        if args.manifest_out:
            args.manifest_out.parent.mkdir(parents=True, exist_ok=True)
            raw_hashes: dict[str, Any] = {}
            for label, path in (("stdout", args.raw_stdout), ("stderr", args.raw_stderr)):
                if path is not None and path.is_file():
                    raw_hashes[label] = {
                        "path": str(path),
                        "bytes": path.stat().st_size,
                        "sha256": _sha256(path),
                    }
            manifest = _receipt_manifest(report, command, pid_utc, raw_hashes)
            args.manifest_out.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        if not args.json_out and not args.markdown_out:
            print(markdown, end="")
        return 0
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        if args.strict:
            print(f"diagnostic failed closed: {exc}", file=sys.stderr)
            return 2
        raise


if __name__ == "__main__":
    raise SystemExit(main())
