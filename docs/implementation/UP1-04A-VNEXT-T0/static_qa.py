"""Static QA for the additive AD-30 T0 slice.

This checker deliberately does not import Julia or execute a focused test.  It
guards the frozen file boundary and the source-level contract while the actual
Julia receipt remains a separate precheck gate.
"""

from pathlib import Path
import hashlib
import json
import sys


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src" / "GenomeV5" / "Integration" / "VNextDeclarationTransportV1.jl"
TEST = ROOT / "test" / "GenomeV5" / "Integration" / "vnext_declaration_transport_v1_tests.jl"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(text: str, token: str, path: Path) -> None:
    if token not in text:
        raise AssertionError(f"missing {token!r} in {path}")


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    required_source = (
        "VNextTypedAbsenceV1",
        "VNextAxisProvenanceV1",
        "vnext_axis_identity_hash_v1",
        "VNextG2CandidateMappingReceiptV1",
        "VNextG2CandidateEnvelopeV1",
        "VNextG3ChildStateV1",
        "VNextDeclarationTransportV1",
        "VNextTransportAdmissionV1",
        "_vnext_t0_g1_body",
        "_vnext_t0_g2_body",
        "_vnext_t0_g3_body",
        "g3_source_content_hash",
        "terminal_deferred",
        "fail_closed",
        "canonical_hash",
        "G2_mapping_source_record_hash_mismatch",
        "G2_mapping_unattested",
        "G2_mapping_external_receipt_verification_pending",
        "axis_candidate_ref_mismatch",
        "axis_source_record_hash_mismatch",
        "axis_identity_hash_mismatch",
        "axis_unattested",
        "external_verification_pending",
        "G3_feedback_unattested_authority",
        "G3_feedback_contradictory_authority",
        "G3_feedback_stale_authority",
        "G3_upstream_unattested_authority",
        "G3_upstream_contradictory_authority",
        "G3_upstream_stale_authority",
        "G3_upstream_authority_missing",
        "G3_upstream_actual_authority_external_verification_pending",
        "CandidateStatePackageV5",
    )
    for token in required_source:
        require(source, token, SOURCE)
    forbidden_source = (
        'include("Contracts/CandidateStatePackageV5.jl")',
        "default_operator_registry(",
        "load_genome_v5_components!",
        "load_genome_v5_up2_components!",
        "mapping_receipt::Union{Nothing,Digest256}",
    )
    for token in forbidden_source:
        if token in source:
            raise AssertionError(f"forbidden legacy integration token {token!r}")
    for token in (
        "G1_candidate_binding_mismatch",
        "axis_conflict:payload_schema_version",
        "G3_declaration_hash_mismatch",
        "G2_mapping_source_record_hash_mismatch",
        "G2_mapping_candidate_ref_mismatch",
        "G2_mapping_field_path_mismatch",
        "axis_source_record_hash_mismatch:G1:payload_schema_version",
        "axis_candidate_ref_mismatch:G1:payload_schema_version",
        "axis_identity_hash_mismatch:G1:payload_schema_version",
        "G3_feedback_unattested_authority:g1-residual",
        "G3_upstream_unattested_authority:G1",
        "G3_upstream_contradictory_authority:G1",
        "G3_feedback_contradictory_authority:g1-residual-contradictory",
        "G3_upstream_stale_authority:G1",
        "G3_feedback_stale_authority:g1-residual-stale",
        "G3_upstream_authority_missing:G1:terminal_deferred",
        "G3_feedback_authority_missing:g1-residual:terminal_deferred",
        "stale-g2-source-record",
        "synthetic-fake-evidence",
        "edited_g1.source_hash != g1.source_hash",
        "edited_g2.source.source_hash != g2.source.source_hash",
        "g3_source_content_hash === nothing",
        "status=:typed_absent",
        "VNEXT_T0_JULIA_OR_DESC_EXECUTED=false",
    ):
        require(test, token, TEST)
    if not SOURCE.is_file() or not TEST.is_file():
        raise AssertionError("T0 source/test path missing")
    print(json.dumps({
        "record_kind": "AD-30_T0_static_qa",
        "status": "pass",
        "julia_executed": False,
        "desc_executed": False,
        "source_sha256": sha256(SOURCE),
        "test_sha256": sha256(TEST),
        "forbidden_legacy_edits_in_source": False,
        "required_negative_controls_present": True,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, UnicodeError) as exc:
        print(f"static_qa_error={exc}", file=sys.stderr)
        raise SystemExit(1)
