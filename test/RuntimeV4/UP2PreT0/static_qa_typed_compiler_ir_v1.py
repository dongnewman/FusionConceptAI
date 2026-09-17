"""Static-only QA for the additive UP2 pre-T0 typed compiler IR slice.

The checker reads text and hashes only.  It never invokes Julia, DESC,
providers, meshes, solvers, or the shared runtime entry.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src/RuntimeV4/TypedCompilerIRV1.jl"
LOWERING = ROOT / "src/RuntimeV4/TypedCompilerLoweringV1.jl"
TEST = ROOT / "test/RuntimeV4/UP2PreT0/typed_compiler_ir_v1_contract_tests.jl"
ENTRY = ROOT / "src/FusionConceptAI.jl"

checks: dict[str, bool] = {}
errors: list[str] = []


def require(name: str, condition: bool, detail: str) -> None:
    checks[name] = condition
    if not condition:
        errors.append(f"{name}: {detail}")


source = SOURCE.read_text(encoding="utf-8") if SOURCE.is_file() else ""
lowering = LOWERING.read_text(encoding="utf-8") if LOWERING.is_file() else ""
test = TEST.read_text(encoding="utf-8") if TEST.is_file() else ""
entry = ENTRY.read_text(encoding="utf-8") if ENTRY.is_file() else ""

require("source_exists", SOURCE.is_file(), str(SOURCE))
require("lowering_exists", LOWERING.is_file(), str(LOWERING))
require("test_exists", TEST.is_file(), str(TEST))
require("shared_entry_untouched", "TypedCompilerIRV1.jl" not in entry and
        "TypedCompilerLoweringV1.jl" not in entry, "additive slice must not edit shared entry")
require("no_include", "include(" not in source and "include(" not in lowering,
        "source must remain an explicit include target")
require("no_heavy_execution", all(token not in (source + lowering) for token in
        ("DESC", "Gridap", "provider(", "mesh(", "solver(", "run(", "read(")),
        "heavy execution hook present")
require("no_julia_launcher", "julia" not in (source + lowering).lower(),
        "implementation must not launch Julia")
require("no_untyped_any", "::Any" not in (source + lowering) and
        "Vararg{Any" not in (source + lowering), "closed typed surface required")

for token in (
    "TypedCompilerUnitV1", "TypedCompilerBindingV1", "TypedCompilerIRV1",
    "TypedCompilerFailureV1", "TypedCompilerValidationV1",
    "TypedCompilerSourceAuthorityV1",
    "_tc_new_unit_v1", "_tc_new_binding_v1", "_tc_new_source_authority_v1",
    "_tc_new_ir_v1",
    "String(strip(String(value)))", "concrete String field type",
    "synthetic == (source_kind === :synthetic)",
    "ir.synthetic == (ir.source_kind === :synthetic)",
    "typed_compiler_unit_v1", "typed_compiler_binding_v1", "typed_compiler_ir_v1",
    "typed_compiler_source_authority_v1",
    "validate_typed_compiler_ir", "_TypedCompilerSealV1", "isfinite",
    "candidate_ref", "owner_ref", "region_ref", "chart_ref", "operator_ref",
    "source_ref", "conservation_ref", "input_unit", "output_unit",
    "contract_only", "not_measured", "typed_absent", "terminal_deferred",
    "fail_closed", "measured", "synthetic", "illegal_operation",
    "_TCIR_SCHEMA_V1", "_TCIR_REVISION_V1", "schema_mismatch",
    "revision_mismatch", "unit_mismatch", "source_authority",
    "checked_present", "source_authority_absent", "source_authority_mismatch",
):
    require(f"source_token:{token}", token in source, token)

for token in (
    "TypedCompilerUnitV1(args...) = throw",
    "TypedCompilerBindingV1(args...) = throw",
    "TypedCompilerSourceAuthorityV1(args...) =",
    "TypedCompilerIRV1(args...) = throw",
):
    require(f"sealed_rejection:{token}", token in source, token)

for token in (
    "TypedCompilerLoweringV1", "lower_typed_compiler_ir",
    "validate_typed_compiler_lowering", "lowered_operations", "lowering_hash",
    "_tc_new_lowering_v1", "TypedCompilerLoweringV1(args...) =",
    "structural_contract_ready", "contract_only", "not_measured",
    "terminal_deferred", "fail_closed", "measured=false",
):
    require(f"lowering_token:{token}", token in lowering, token)

for token in (
    ":ready", ":terminal_deferred", ":fail_closed", "typed_absent",
    "candidate_ref", "owner_ref", "region_ref", "chart_ref", "operator_ref",
    "source_ref", "conservation_ref", "illegal input", "@test_throws",
    "sealed factories and unsealed direct constructors", "TypedCompilerUnitV1(",
    "TypedCompilerBindingV1(", "TypedCompilerSourceAuthorityV1(",
    "TypedCompilerIRV1(", "TypedCompilerLoweringV1(",
    "factory trimming keeps concrete String fields", "typeof(unit.name) === String",
    "typeof(operation) === String",
    "source kind and synthetic flag are a two-way contract",
    "contract_only", "not_measured", "!lowered.measured", "schema_mismatch",
    "revision_mismatch", "unit_mismatch", "source_authority",
    "checked_present", "source_authority_absent", "source_authority_mismatch",
    "local_source",
):
    require(f"test_token:{token}", token in test, token)

require("source_hashable", SOURCE.is_file() and bool(hashlib.sha256(SOURCE.read_bytes()).hexdigest()),
        "source hash unavailable")
require("lowering_hashable", LOWERING.is_file() and bool(hashlib.sha256(LOWERING.read_bytes()).hexdigest()),
        "lowering hash unavailable")

print(json.dumps({
    "record_kind": "typed-compiler-ir-v1-static-qa",
    "checks": "pass" if not errors else "fail",
    "check_count": len(checks),
    "passed": sum(checks.values()),
    "errors": errors,
    "scope": [str(path.relative_to(ROOT)).replace("\\", "/") for path in
              (SOURCE, LOWERING, TEST, Path(__file__))],
}, ensure_ascii=False, indent=2))
sys.exit(0 if not errors else 1)
