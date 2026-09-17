"""Static scope checks for the six-file G3 binding precursor."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src/GenomeV5/G3/G3BindingChildEditabilityV1.jl"
TEST = ROOT / "test/GenomeV5/G3/g3_binding_child_editability_v1_tests.jl"
FIXTURE = ROOT / "test/GenomeV5/G3/g3_binding_child_editability_v1_fixture.json"
DOC = ROOT / "docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/README.md"
MANIFEST = ROOT / "docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/manifest.json"

def main():
    assert SOURCE.exists() and TEST.exists() and FIXTURE.exists() and DOC.exists() and MANIFEST.exists()
    text = SOURCE.read_text(encoding="utf-8")
    test_text = TEST.read_text(encoding="utf-8")
    contract_text = text + "\n" + test_text
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for token in ("G3BindingSourcePayloadV1", "initial_links", "AbsentChildBindingV1",
                  "PresentChildBindingV1", "G3BindingOperationDigestV1", "insert_link",
                  "replace_link", "delete_link", "authority_recheck_not_published",
                  "binding_authority_typed_absent", "duplicate_upstream_authority_layer",
                  "legacy_target_upstream_projection_mismatch",
                  "legacy_actual_without_declaration_authority", "complete=true",
                  "PresentChildBindingV1", "present_error",
                  "throw(ArgumentError(\"binding_authority_typed_absent\"))"):
        assert token in contract_text
    for forbidden in ("default_operator_registry", "CandidateStatePackageV5",
                      "G3FeedbackChild", "VNextDeclarationAuthorityRecheck",
                      "launcher", "provider_calls", "mesh_calls", "solver_calls"):
        assert forbidden not in text
    assert fixture["current_slot"] == "AbsentChildBindingV1"
    assert manifest["exact_file_count"] == 6
    expected = [
        "src/GenomeV5/G3/G3BindingChildEditabilityV1.jl",
        "test/GenomeV5/G3/g3_binding_child_editability_v1_tests.jl",
        "test/GenomeV5/G3/g3_binding_child_editability_v1_fixture.json",
        "test/GenomeV5/G3/static_qa_g3_binding_child_editability_v1.py",
        "docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/README.md",
        "docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/manifest.json",
    ]
    assert manifest["product_files"] == expected
    assert len(manifest["product_files"]) == manifest["exact_file_count"] == 6
    assert all("launcher" not in p.lower() for p in manifest["product_files"])
    print("static_qa_g3_binding_child_editability_v1: PASS")

if __name__ == "__main__":
    main()
