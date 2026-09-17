"""Static QA for the AD-34 T0 authority recheck scaffold."""
from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "src" / "GenomeV5" / "Integration" / "VNextDeclarationAuthorityRecheckV1.jl"
TEST = ROOT / "test" / "GenomeV5" / "Integration" / "vnext_declaration_authority_recheck_v1_tests.jl"
FIXTURE = ROOT / "test" / "GenomeV5" / "Integration" / "vnext_declaration_authority_recheck_v1_fixture.json"
DOC_ROOT = ROOT / "docs" / "implementation" / "UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC"


def main() -> int:
    checks = []
    source = SRC.read_text(encoding="utf-8")
    tests = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    checks.extend([
        SRC.is_file(), TEST.is_file(), FIXTURE.is_file(),
        (DOC_ROOT / "README.md").is_file(),
        (DOC_ROOT / "manifest.json").is_file(),
        (DOC_ROOT / "acceptance.md").is_file(),
        "VNEXT_AR_REQUIRED_LAYERS" in source,
        "duplicate_upstream_authority_layer" in source,
        "duplicate_or_ambiguous_feedback_target" in source,
        "declaration_candidate_mismatch" in source,
        "legacy_actual_without_declaration_authority" in source,
        "synthetic_authority_rejected" in source,
        "ref_only_authority_rejected" in source,
        "fixture_authority_rejected" in source,
        "canonical_bytes" in source and "source_receipt_ref" in source,
        "CandidateStatePackageV5" not in source,
        "default_operator_registry" not in source,
        "vnext_declaration_authority_recheck_v1" in tests,
        fixture["required_layers"] == ["G1", "G2"],
        len(fixture["legacy_authority_fields"]) == 6,
    ])
    if not all(checks):
        print(f"AD34_T0_STATIC_QA=fail checks={len(checks)} passed={sum(checks)}")
        return 1
    print(f"AD34_T0_STATIC_QA=pass checks={len(checks)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
