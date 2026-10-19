#!/usr/bin/env python3
"""Cross-check four independently executed bounded-candidate shard receipts."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


SCENARIOS = (
    "implicit_default",
    "explicit_legacy",
    "declared_load",
    "declared_load_bounded",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise AssertionError(f"object required: {path}")
    return value


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def candidate_identity(receipt: dict[str, Any]) -> dict[str, Any]:
    value = receipt["candidate_identity"]
    require(isinstance(value, dict), "candidate identity must be an object")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--parent-receipt", type=Path, required=True)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("receipts", nargs=4, type=Path)
    args = parser.parse_args()

    require(not args.output.exists(), "refusing to overwrite cross-shard receipt")
    parent = load(args.parent_receipt)
    require(parent["schema"] ==
            "up2-04-independent-parent-checkpoint-receipt-v1",
            "parent receipt schema mismatch")
    require(parent["artifact_sha256"] == sha256(args.artifact),
            "parent artifact hash mismatch")
    require(parent["artifact_bytes"] == args.artifact.stat().st_size,
            "parent artifact size mismatch")

    by_scenario: dict[str, dict[str, Any]] = {}
    path_by_scenario: dict[str, Path] = {}
    for path in args.receipts:
        receipt = load(path)
        require(receipt["schema"] ==
                "up2-04-independent-bounded-candidate-shard-v1",
                f"child receipt schema mismatch: {path}")
        scenario = receipt["scenario"]
        require(scenario in SCENARIOS, f"unknown scenario: {scenario}")
        require(scenario not in by_scenario, f"duplicate scenario: {scenario}")
        require(receipt["status"] ==
                "pass_candidate_identity_and_analytic_assembly_only",
                f"scenario did not pass its narrow gate: {scenario}")
        require(receipt["parent_receipt_sha256"] == sha256(args.parent_receipt),
                f"foreign parent receipt: {scenario}")
        require(receipt["protocol_sha256"] == parent["protocol_sha256"],
                f"protocol binding drift: {scenario}")
        require(receipt["base_head"] == parent["base_head"],
                f"base HEAD drift: {scenario}")
        require(receipt["parent_artifact_sha256"] == sha256(args.artifact),
                f"foreign parent artifact: {scenario}")
        require(receipt["parent_identity"] == parent["identity"],
                f"parent identity drift: {scenario}")
        require(receipt["physical_input_hash"] ==
                parent["identity"]["physical_input_hash"],
                f"physical input drift: {scenario}")
        require(receipt["inherited_real_parent_and_registry_validated"] is True,
                f"parent/registry validation absent: {scenario}")
        require(receipt["dgpi_geometry_provider_executed"] is False,
                f"geometry-provider scope was broadened: {scenario}")
        require(receipt["nonlinear_convergence"] == "not_executed" and
                receipt["physical_state"] == "unknown" and
                receipt["resolution"] == "terminal_deferred" and
                receipt["formal_up2_04"] == "not_executed" and
                receipt["scientific_credit"] == 0,
                f"scope boundary changed: {scenario}")
        by_scenario[scenario] = receipt
        path_by_scenario[scenario] = path

    require(tuple(sorted(by_scenario)) == tuple(sorted(SCENARIOS)),
            "exact four-scenario coverage is required")
    implicit = by_scenario["implicit_default"]
    explicit = by_scenario["explicit_legacy"]
    loaded = by_scenario["declared_load"]
    combined = by_scenario["declared_load_bounded"]

    # Default construction and an explicit authoritative legacy declaration
    # must be the same production candidate, not merely similar assemblies.
    require(candidate_identity(implicit) == candidate_identity(explicit),
            "implicit default differs from explicit legacy candidate")
    require(implicit["declaration"] == explicit["declaration"],
            "implicit default differs from explicit legacy declaration")
    require(implicit["assembly"]["selected"] ==
            explicit["assembly"]["selected"],
            "implicit default differs from explicit legacy assembly")

    identity_fields = (
        "candidate_hash",
        "candidate_package_hash",
        "context_hash",
        "context_canonical_hash",
        "subject_hash",
        "mechanism_hash",
        "field_geometry_hash",
        "realization_control_hash",
        "genome_bundle_hash",
        "provenance_hash",
    )
    for field in identity_fields:
        require(candidate_identity(loaded)[field] !=
                candidate_identity(implicit)[field],
                f"declared load did not regenerate {field}")
        require(candidate_identity(combined)[field] !=
                candidate_identity(loaded)[field],
                f"bounded combined declaration did not regenerate {field}")

    require(loaded["declaration"]["revision"] ==
            "spatial-q1-static-mhd-declared-loads-v1",
            "declared-load revision mismatch")
    require(combined["declaration"]["revision"] ==
            "spatial-q1-static-mhd-declared-loads-bounded-step-v1",
            "combined revision mismatch")
    require(candidate_identity(combined)["candidate_id"] ==
            "spatial-coupled-declared-loads-bounded-step-v1",
            "combined candidate ID mismatch")

    legacy_assembly = implicit["assembly"]["selected"]
    loaded_assembly = loaded["assembly"]["selected"]
    combined_assembly = combined["assembly"]["selected"]
    require(loaded_assembly["residual_hash"] != legacy_assembly["residual_hash"],
            "declared source did not change the residual")
    require(loaded_assembly["jacobian_hash"] == legacy_assembly["jacobian_hash"],
            "declared source changed the Jacobian")
    require(combined_assembly == loaded_assembly,
            "bounded numerical declaration changed assembly")
    for receipt in by_scenario.values():
        assembly = receipt["assembly"]
        require(assembly["legacy"] == implicit["assembly"]["legacy"],
                "legacy assembly oracle drifted across shards")
        require(assembly["declared_load"] == loaded["assembly"]["declared_load"],
                "declared-load assembly oracle drifted across shards")
        require(assembly["declared_load_bounded"] ==
                combined["assembly"]["declared_load_bounded"],
                "combined assembly oracle drifted across shards")

    output = {
        "schema": "up2-04-independent-bounded-candidate-controller-v1",
        "status": "pass_candidate_identity_and_analytic_assembly_only",
        "scenario_order": list(SCENARIOS),
        "parent_receipt_sha256": sha256(args.parent_receipt),
        "parent_artifact_sha256": sha256(args.artifact),
        "child_receipts": [
            {
                "scenario": scenario,
                "path": path_by_scenario[scenario].name,
                "sha256": sha256(path_by_scenario[scenario]),
            }
            for scenario in SCENARIOS
        ],
        "implicit_equals_explicit_legacy": True,
        "declared_load_regenerates_identity": True,
        "declared_load_changes_residual_not_jacobian": True,
        "combined_regenerates_identity_not_assembly": True,
        "fresh_process_parent_roundtrip_count": 4,
        "scope": "real_candidate_identity_plus_analytic_torus_assembly_only",
        "dgpi_geometry_provider_execution": "not_executed",
        "nonlinear_convergence": "not_executed",
        "physical_state": "unknown",
        "resolution": "terminal_deferred",
        "formal_up2_04": "not_executed",
        "scientific_credit": 0,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(output, sort_keys=True, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(f"UP2_BOUNDED_CONTROLLER_RECEIPT_SHA256={sha256(args.output)}")
    print("UP2_BOUNDED_CONTROLLER_EXIT_CODE=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
