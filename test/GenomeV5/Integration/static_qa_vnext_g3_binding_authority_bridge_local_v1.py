"""Static QA for the local T0 -> G3 binding bridge."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "src" / "GenomeV5" / "Integration" / "VNextG3BindingAuthorityBridgeLocalV1.jl"
TEXT = SRC.read_text(encoding="utf-8")
for token in (
    "VNextG3BindingAuthorityExpectedCommitmentV1",
    "vnext_g3_binding_self_consistency_v1",
    "vnext_g3_binding_authority_bridge_local_v1",
    "authority_verified", "local_checked_present", "t0_typed_absent",
    "G3BindingChildPresentV2", "G3BindingStateV2",
    "VNextG3BindingChildExpectedCommitmentV1", "source_record_hash",
    "commitment_hash", "realization_expected_commitment_mismatch",
):
    assert token in TEXT, token
assert "default_operator_registry" not in TEXT
assert "include(FusionConceptAI" not in TEXT
print("static QA local G3 binding bridge: PASS")
