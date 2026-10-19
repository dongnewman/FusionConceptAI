"""Static QA for the additive V2 G3 binding contract."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "src" / "GenomeV5" / "G3" / "G3BindingChildEditabilityV2.jl"
OLD = ROOT / "src" / "GenomeV5" / "G3" / "G3BindingChildEditabilityV1.jl"
TEXT = SRC.read_text(encoding="utf-8")
OLDTEXT = OLD.read_text(encoding="utf-8")
required = [
    "G3BindingSourcePayloadV2", "initial_links::Tuple{Vararg{G3BindingLinkV1}}",
    "G3BindingChildPresentV2", "G3BindingChildAbsentV2", "G3BindingStateV2",
    "initial_source_state_hash", "binding_child_identity_hash", "operation_history",
    "duplicate_operation_id", "stale_state_hash", "foreign_key", "operation_hash_mismatch",
    "checked-present source_hash is required", "_g3be2_validate_state", "source_record_hash",
]
missing = [x for x in required if x not in TEXT]
assert not missing, missing
assert "binding_authority_typed_absent" in OLDTEXT
assert "PresentChildBindingV1" in OLDTEXT
assert "digest256_text(\"local-g3-binding-v2\")" not in TEXT
assert "src/FusionConceptAI.jl" not in TEXT
print("static QA V2 binding: PASS")
