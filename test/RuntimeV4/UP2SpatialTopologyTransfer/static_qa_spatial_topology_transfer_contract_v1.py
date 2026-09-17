"""Static-only QA for the additive UP2 spatial transfer contract.

This checker reads text/JSON and hashes only.  It never invokes Julia, DESC,
a provider, a mesh builder, a solver, or the shared runtime entry.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src/RuntimeV4/SpatialTopologyTransferContractV1.jl"
TEST = ROOT / "test/RuntimeV4/UP2SpatialTopologyTransfer/spatial_topology_transfer_contract_v1_tests.jl"
FIXTURE = ROOT / "test/RuntimeV4/UP2SpatialTopologyTransfer/spatial_topology_transfer_contract_v1_fixture.json"
ENTRY = ROOT / "src/FusionConceptAI.jl"

checks: dict[str, bool] = {}
errors: list[str] = []


def require(name: str, condition: bool, detail: str) -> None:
    checks[name] = condition
    if not condition:
        errors.append(f"{name}: {detail}")


source = SOURCE.read_text(encoding="utf-8") if SOURCE.is_file() else ""
test = TEST.read_text(encoding="utf-8") if TEST.is_file() else ""
entry = ENTRY.read_text(encoding="utf-8") if ENTRY.is_file() else ""
fixture_text = FIXTURE.read_text(encoding="utf-8") if FIXTURE.is_file() else ""

require("source_exists", SOURCE.is_file(), str(SOURCE))
require("test_exists", TEST.is_file(), str(TEST))
require("fixture_exists", FIXTURE.is_file(), str(FIXTURE))
require("shared_entry_untouched", "SpatialTopologyTransferContractV1.jl" not in entry,
        "additive contract must not edit shared entry")
require("source_standalone", "include(" not in source and "FusionConceptAI.jl" not in source,
        "source must remain a standalone explicit include target")
require("no_execution_hooks", all(token not in source for token in
        ("provider(", "mesh(", "solver(", "run(", "read(", "write(", "execute(")),
        "provider/mesh/solver execution hook present")
require("no_julia_launcher", "julia" not in source.lower(),
        "implementation must not launch Julia")
require("no_shared_symbols", "CandidateStatePackage" not in source and
        "using FusionConceptAI" not in test, "shared runtime import leaked into additive test")

for token in (
    "SpatialTransferUnitV1", "SpatialTopologyIdentityV1", "SpatialRegionIdentityV1",
    "SpatialInterfaceIdentityV1", "SpatialTypedAccountV1", "SpatialAccountEffectV1",
    "SpatialTransferWitnessV1", "SpatialDefectV1", "SpatialDiagnosticV1",
    "SpatialTopologyTransferV1", "SpatialTransferValidationV1",
    "candidate_ref", "space_ref", "topology_ref", "mesh_ref", "basis_ref",
    "quadrature_ref", "dof_ref", "order_ref", "region_ref", "interface_ref",
    "owner_ref", "account_ref", "unit", "orientation", "signed_value",
    "source_topology_ref", "target_topology_ref", "external_closure_ref",
    "local", "region", "interface", "exterior", "global", "external",
    "divB", "positivity", "gauge", "nullspace", "constraint_refs",
    "physical_event_refs", "return_ref", "_STTC_SCHEMA_V1", "_STTC_REVISION_V1",
    "_STTC_EXTERNAL_OWNER_V1", "_STTC_WILDCARD_REFS_V1", "_sttc_ref_ok",
    "_sttc_units_compatible", "_sttc_effect_sort_key", "repr(effect.signed_value)",
    "effect.unit.name", "effect.unit.exponents", "repr(effect.unit.scale_to_si)",
    "_sttc_valid_unit(effect.unit", "transfer_units", "normalized_value",
    "validate_spatial_topology_transfer", "spatial_topology_transfer_canonical_json",
    "spatial_topology_transfer_canonical_hash", "contract_only", "screen_only",
    "provider_calls", "mesh_calls", "solver_calls", "fail_closed",
):
    require(f"source_token:{token}", token in source, token)

for token in (
    "identity, opposite sign, and canonical order", "split and merge transfer witness",
    "Same transfer/account/orientation keys", "tied_effects", "tied_a", "tied_b",
    "spatial_topology_transfer_canonical_hash(tied_a)", "empty_effect_unit",
    "compatible scales normalize; incompatible dimensions fail closed",
    "external closure is explicit", "candidate_mismatch", "space_mismatch",
    "topology_identity_mismatch", "unit_mismatch", "orientation_mismatch",
    "owner_mismatch", "nonfinite", "external_closure_mismatch",
    "return_mismatch", "constraint_mismatch", "physical_event_misuse",
    "bad_interface_owner", "external_owner_transfer", "empty_interface", "wildcard_interface", "empty_account",
    "provider_calls == 0", "mesh_calls == 0", "solver_calls == 0",
    "CandidateStatePackageV5", "FusionConceptAI",
):
    require(f"test_token:{token}", token in test, token)

try:
    fixture = json.loads(fixture_text)
except json.JSONDecodeError as exc:
    fixture = {}
    errors.append(f"fixture_json: {exc}")
    checks["fixture_json"] = False
else:
    checks["fixture_json"] = True

for key in ("schema", "revision", "source_target_identity", "ownership",
            "typed_transfer", "unit_policy", "owner_binding", "ref_policy",
            "canonical_effect_order", "defect_scopes", "diagnostics", "external_closure",
            "vector_counts", "execution"):
    require(f"fixture_key:{key}", key in fixture, key)
require("fixture_effect_order_complete",
        fixture.get("canonical_effect_order") == [
            "transfer_ref", "account_ref", "orientation", "signed_value",
            "unit.name", "unit.exponents", "unit.scale_to_si"],
        "canonical effect order must include signed value and complete unit identity")
require("fixture_effect_unit_validation",
        fixture.get("unit_policy", {}).get("effect_unit_validation") ==
        "every_effect_uses_complete_unit_validator",
        "every effect unit must use the complete unit validator")
require("fixture_r3_vector_counts",
        fixture.get("vector_counts") == {"r3_added_positive": 1,
                                          "r3_added_negative": 1, "r3_total": 2},
        "R3 vector counts must record one permutation and one malformed-unit negative")
require("fixture_execution_zero", fixture.get("execution") ==
        {"provider_calls": 0, "mesh_calls": 0, "solver_calls": 0},
        "fixture execution boundary must be all zero")
require("source_hashable", SOURCE.is_file() and bool(hashlib.sha256(SOURCE.read_bytes()).hexdigest()),
        "source hash unavailable")

print(json.dumps({
    "record_kind": "spatial-topology-transfer-contract-v1-static-qa",
    "checks": "pass" if not errors else "fail",
    "check_count": len(checks),
    "passed": sum(checks.values()),
    "errors": errors,
    "scope": [str(path.relative_to(ROOT)).replace("\\", "/") for path in
              (SOURCE, TEST, FIXTURE, Path(__file__))],
}, ensure_ascii=False, indent=2))
sys.exit(0 if not errors else 1)
