"""Static, bounded audit for the AD-33 typed-absent scaffold."""
from __future__ import annotations
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
source = ROOT / "src/GenomeV5/Integration/VNextParentBaselineBindingV1.jl"
test = ROOT / "test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_tests.jl"
fixture = ROOT / "test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_fixture.json"
entry = ROOT / "src/FusionConceptAI.jl"
docs_root = ROOT / "docs/implementation/UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC"
doc_files = [docs_root / name for name in ("README.md", "manifest.json", "acceptance.md")]

errors: list[str] = []
checks: dict[str, bool] = {}

def require(name: str, condition: bool, detail: str) -> None:
    checks[name] = condition
    if not condition:
        errors.append(f"{name}: {detail}")

source_text = source.read_text(encoding="utf-8") if source.is_file() else ""
test_text = test.read_text(encoding="utf-8") if test.is_file() else ""
fixture_text = fixture.read_text(encoding="utf-8") if fixture.is_file() else ""
entry_text = entry.read_text(encoding="utf-8") if entry.is_file() else ""

require("source_exists", source.is_file(), str(source))
require("test_exists", test.is_file(), str(test))
require("fixture_exists", fixture.is_file(), str(fixture))
require("dedicated_docs_exist", all(path.is_file() for path in doc_files), str(docs_root))
require("not_in_shared_entry", "VNextParentBaselineBindingV1.jl" not in entry_text,
        "shared FusionConceptAI.jl must remain unchanged")
for forbidden in ("::Any", "Dict{", "Vararg", "Union{Nothing", "Base.include(FusionConceptAI"):
    require(f"source_forbidden_{forbidden}", forbidden not in source_text,
            f"forbidden construct {forbidden!r}")
for token in (
    "PresentParentBaselineBindingV1", "AbsentParentBaselineBindingV1",
    "PresentChildKeyV1", "AbsentChildKeyV1", "VNEXT_PBB_ABSENT_DOMAIN_G1",
    "VNEXT_PBB_ABSENT_DOMAIN_G2", "VNEXT_PBB_CHILD_ABSENT_DOMAIN_G1",
    "VNEXT_PBB_CHILD_ABSENT_DOMAIN_G2", "terminal_deferred",
    "baseline_authority_absent", "absent_to_present_cas_forbidden",
    "synthetic_fixture_authority", "ref_only_authority",
    "canonical_bytes", "history"):
    require(f"source_token_{token}", token in source_text, token)
for token in (
    "g1_typed_absent_state", "g2_typed_absent_state",
    "verify_absent_parent", "verify_absent_child", "replace_source_payload",
    "synthetic_fixture_authority", "ref_only_authority",
    "foreign_candidate", "absent_to_present_cas_forbidden"):
    require(f"test_token_{token}", token in test_text, token)
require("fixture_expected_only", "expected_only_negative_and_absence_data" in fixture_text,
        "fixture authority marker missing")
require("fixture_no_present_authority", '"present_authority": "verified"' not in fixture_text,
        "fixture cannot be present authority")
require("fixture_domains", "ad33:G1:parent-baseline-absent:v1" in fixture_text and
        "ad33:G2:parent-baseline-absent:v1" in fixture_text,
        "absence domains missing")
require("no_ad33_history_scope", all("AD-33/g1_g2_editability" not in path.as_posix()
        for path in doc_files), "historical AD-33 audit scope leaked")

print(json.dumps({
    "record_kind": "AD-33-static-qa-typed-absent-scaffold",
    "python": sys.executable,
    "checks": "pass" if not errors else "fail",
    "check_count": len(checks),
    "passed": sum(checks.values()),
    "errors": errors,
    "scope": [str(path.relative_to(ROOT)).replace("\\", "/") for path in
              [source, test, fixture, Path(__file__), *doc_files]],
}, ensure_ascii=False, indent=2))
sys.exit(0 if not errors else 1)
