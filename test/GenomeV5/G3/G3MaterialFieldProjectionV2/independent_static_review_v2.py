from __future__ import annotations

import copy
import hashlib
import itertools
import json
import sys
from fractions import Fraction
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
SOURCE = Path("src/GenomeV5/G3/G3MaterialFieldProjectionV2.jl")
FOCUSED = Path("test/GenomeV5/G3/G3MaterialFieldProjectionV2/focused_tests.jl")
STATIC_QA = Path("test/GenomeV5/G3/G3MaterialFieldProjectionV2/verify_g3_mfp_v2_static.py")
V1_SOURCE = Path("src/GenomeV5/G3/G3MaterialFieldProjectionV1.jl")
V1_TEST = Path("test/GenomeV5/G3/G3MaterialFieldProjectionV1/focused_tests.jl")
G3SF_SOURCE = Path("src/GenomeV5/G3/G3SourceFeedbackLawV1.jl")
G3SF_TEST = Path("test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl")
ARCHIVE = Path("docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g3_mfp_v2_static_r1_20260923")
EXPECTED = {
    SOURCE: (53184, "d08dff9064808e36762a226b94b2295a4cc38f81981f8008ce1425a80531771a"),
    FOCUSED: (20619, "a4752286960efe44566bd9c745c94efedbceb43e1c8e6754b3c1ea91b1a88064"),
    STATIC_QA: (7715, "cd224adc1db240a1acdd860d191a15e3072b42049b06475b97846ebd3e928a67"),
    V1_SOURCE: (None, "74df80b1204a4ede798171fb06926ab4f1291fccd7fe658d15d626ba9f4e6598"),
    V1_TEST: (None, "85a57e248872ff62ebeec70c40389a531c47ab86186e1c0817dd2086a35208d6"),
    G3SF_SOURCE: (None, "616bda1a3f8f32a60e8175f9d8cbb44261e803fd9e392bf75c7a5593d26ed8e7"),
    G3SF_TEST: (None, "2569086821d04a2a1a77584cf07fbc27a06278e3eef37a31591c5f34fcea9f31"),
}
PRODUCER_MANIFEST_SHA256 = "d311899f5710e9a8711fa3c8e47f17748f17cd36f4e2f6645d2ae8a26fac53bc"


class ContractFailure(AssertionError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractFailure(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def check_frozen_inputs() -> dict[str, dict[str, object]]:
    result: dict[str, dict[str, object]] = {}
    for rel, (expected_size, expected_hash) in EXPECTED.items():
        path = ROOT / rel
        require(path.is_file(), f"missing pinned input: {rel.as_posix()}")
        payload = path.read_bytes()
        actual_hash = sha256(payload)
        require(actual_hash == expected_hash, f"hash drift: {rel.as_posix()}")
        if expected_size is not None:
            require(len(payload) == expected_size, f"byte count drift: {rel.as_posix()}")
        result[rel.as_posix()] = {"bytes": len(payload), "sha256": actual_hash}
    return result


def check_producer_archive() -> int:
    manifest_path = ROOT / ARCHIVE / "archive_manifest.json"
    payload = manifest_path.read_bytes()
    require(sha256(payload) == PRODUCER_MANIFEST_SHA256, "producer archive manifest hash drift")
    manifest = json.loads(payload)
    require(manifest.get("schema") == "native-g3-mfp-v2-static-review-manifest-v1", "producer archive schema mismatch")
    require(manifest.get("status") == "bounded_static_go_dynamic_julia_not_run", "producer review status changed")
    require(manifest.get("evidence_only") is True, "producer archive must be evidence-only")
    require(manifest.get("contains_source_test_or_launcher") is False, "producer archive contains source/test/launcher")
    require(manifest.get("julia_started") is False and manifest.get("solver_started") is False, "producer archive claims runtime execution")
    require(manifest.get("claims") == {"accepted": False, "formal_up2_credit": False, "physical_credit": False, "solver_credit": False}, "producer credit boundary changed")
    entries = manifest.get("files")
    require(isinstance(entries, list) and len(entries) == 6, "unexpected producer evidence inventory")
    for entry in entries:
        rel = entry["path"]
        require(not rel.lower().endswith((".jl", ".py", ".ps1", ".bat", ".cmd", ".exe")), f"source or executable in producer archive: {rel}")
        target = manifest_path.parent / rel
        require(target.is_file(), f"producer receipt missing: {rel}")
        data = target.read_bytes()
        require(len(data) == entry["bytes"], f"producer receipt byte mismatch: {rel}")
        require(sha256(data) == entry["sha256"], f"producer receipt hash mismatch: {rel}")
    return len(entries)


def spd_by_exact_rationals(entries: tuple[Fraction, ...]) -> bool:
    if len(entries) != 9:
        return False
    a, b, c, d, e, f, g, h, i = entries
    if b != d or c != g or f != h:
        return False
    # Sylvester criterion for a symmetric 3x3 matrix, exact over rationals.
    det = sum(
        Fraction((-1) ** inversions) * entries[perm[0]] * entries[3 + perm[1]] * entries[6 + perm[2]]
        for perm in itertools.permutations((0, 1, 2))
        for inversions in [sum(perm[x] > perm[y] for x in range(3) for y in range(x + 1, 3))]
    )
    return a > 0 and a * e - b * b > 0 and det > 0


def validate_text_contract(source: str, focused: str, v1_source: str, v1_test: str) -> None:
    required_source = (
        "g3_sf_evaluate_v1(declaration, source.source_power_w)",
        "heat_witness.heat_power_w == evaluation.heat_power",
        "heat_witness.endpoint_id == declaration.law.heat_endpoint_id",
        "evaluation.heat_power * weight",
        "integrated_heat == heat_witness.heat_power_w",
        "heat_witness_hash::Digest256",
        "g2_region_map_hash::Digest256",
        "jacobian_included::Bool",
        "profile_kind !== :uniform_within_region",
        "sum(r.allocation_fraction for r in allocation.region_support; init=0 // 1) == 1",
        "candidate_bound_heat_to_region_allocation_missing",
        "physical_measure_jacobian_missing",
        "conductivity_tensor_w_m_k::NTuple{9,Rational{Int64}}",
        "b == d && c == g && f == h || return false",
        "minor1 > 0 && minor2 > 0 && determinant > 0",
        "conductivity tensor must use SI W/(m*K)",
        "status=:terminal_deferred",
        "status=:fail_closed",
        "accepted=false",
        "physical_status=:unknown",
        "formal_up2_credit=false",
        "formal_r_credit=false",
        "discovery_credit=false",
        "engineering_credit=false",
        "compiler_calls=0",
        "provider_calls=0",
        "mesh_calls=0",
        "solver_calls=0",
    )
    for marker in required_source:
        require(marker in source, f"V2 source marker absent: {marker}")
    for forbidden in ("source.source_power_w * weight", "witness.power_w * weight", "g3_mfp_project_v1", "Gridap.", "CartesianDiscreteModel"):
        require(forbidden not in source, f"forbidden V2 source path present: {forbidden}")

    required_focused = (
        "receipt.source_power_w == 120 // 1",
        "receipt.field_power_w == 90 // 1",
        "receipt.return_power_w == 15 // 1",
        "receipt.heat_power_w == 15 // 1",
        "receipt.integrated_heat_power_w == 15 // 1",
        "receipt.normalized_support_integral == 1 // 1",
        "Tuple(r.volumetric_source_w_m3 for r in receipt.regions) == (15 // 8, 45 // 4)",
        "receipt.input_provenance == :synthetic_local",
        "receipt.accepted === false",
        "receipt.physical_status === :unknown",
        "no_heat.status == :terminal_deferred",
        "no_allocation.status == :terminal_deferred",
        "unsupported_profile.status == :terminal_deferred",
        "mismatched_heat.status == :fail_closed",
        "bad_allocation.status == :fail_closed",
        "duplicate.status == :fail_closed",
        "anisotropic.conductivity_tensor_w_m_k[2] == 1 // 1",
    )
    for marker in required_focused:
        require(marker in focused, f"V2 focused test marker absent: {marker}")

    # Preserve the pinned V1 false positive as history: its green fixture
    # integrates the full source witness (120 W) as thermal power.
    require("witness.power_w * weight" in v1_source, "V1 full-source-to-heat defect no longer represented")
    require("integrated_power == witness.power_w" in v1_source, "V1 full-source integral assertion changed")
    require("receipt.integrated_source_power_w == 120 // 1" in v1_test, "V1 120 W false-positive test changed")
    require("== 120 // 1" in v1_test, "V1 120 W positive fixture missing")


def run_python_negative_controls(source: str, focused: str, v1_source: str, v1_test: str) -> int:
    count = 0
    mutations = (
        ("source-power-used-as-heat", source.replace("evaluation.heat_power * weight", "source.source_power_w * weight", 1), focused, v1_source, v1_test),
        ("heat-witness-check-removed", source.replace("heat_witness.heat_power_w == evaluation.heat_power", "true", 1), focused, v1_source, v1_test),
        ("integrated-heat-check-removed", source.replace("integrated_heat == heat_witness.heat_power_w", "true", 1), focused, v1_source, v1_test),
        ("determinant-condition-weakened", source.replace("determinant > 0", "determinant >= 0", 1), focused, v1_source, v1_test),
        ("physical-credit-enabled", source.replace("accepted=false", "accepted=true", 1), focused, v1_source, v1_test),
        ("v1-false-positive-rewritten", source, focused, v1_source.replace("witness.power_w * weight", "heat_power_w * weight", 1), v1_test),
        ("v1-120w-assertion-rewritten", source, focused, v1_source, v1_test.replace("receipt.integrated_source_power_w == 120 // 1", "receipt.integrated_source_power_w == 15 // 1", 1)),
    )
    for name, s, f, v1s, v1t in mutations:
        try:
            validate_text_contract(s, f, v1s, v1t)
        except ContractFailure:
            print(f"NEGATIVE_CONTROL=PASS name={name}")
            count += 1
        else:
            raise ContractFailure(f"mutant accepted: {name}")
    return count


def main() -> int:
    pins = check_frozen_inputs()
    archive_count = check_producer_archive()
    source = (ROOT / SOURCE).read_text(encoding="utf-8-sig")
    focused = (ROOT / FOCUSED).read_text(encoding="utf-8-sig")
    v1_source = (ROOT / V1_SOURCE).read_text(encoding="utf-8-sig")
    v1_test = (ROOT / V1_TEST).read_text(encoding="utf-8-sig")
    validate_text_contract(source, focused, v1_source, v1_test)

    accepted = spd_by_exact_rationals(tuple(map(Fraction, (4, 1, 0, 1, 3, 0, 0, 0, 2))))
    asymmetric = spd_by_exact_rationals(tuple(map(Fraction, (1, 2, 0, 0, 1, 0, 0, 0, 1))))
    leading_minor_negative = spd_by_exact_rationals(tuple(map(Fraction, (1, 2, 0, 2, 1, 0, 0, 0, 1))))
    determinant_only_negative = spd_by_exact_rationals(tuple(map(Fraction, (1, 0, 0, 0, 1, 2, 0, 2, 1))))
    require(accepted and not asymmetric and not leading_minor_negative and not determinant_only_negative, "exact-rational SPD controls failed")
    negatives = run_python_negative_controls(source, focused, v1_source, v1_test)

    print(f"PINNED_INPUTS=PASS count={len(pins)} v1_g3sf_inputs=4")
    print(f"PRODUCER_ARCHIVE=PASS sha256={PRODUCER_MANIFEST_SHA256} payloads={archive_count} runtime_claims=false")
    print("HEAT_LEDGER=PASS source=120W field=90W return=15W heat=15W integrated=15W synthetic_fixture=true")
    print("REGION_ALLOCATION=PASS separate_heat_bound_receipt map_frame_jacobian_volumes_uniform_profiles conservative_fractions")
    print("CONDUCTIVITY=PASS exact_rational_spd_positive_asymmetric_indefinite_and_determinant_negative_controls")
    print("ABSENCE_AND_V1=PASS missing_inputs_deferred V1_120W_false_positive_hash_pinned_and_retained")
    print(f"NEGATIVE_CONTROLS=PASS count={negatives}")
    print("INDEPENDENT_G3_MFP_V2_REVIEW=PASS julia_started=false solver_started=false physical_credit=false")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"INDEPENDENT_G3_MFP_V2_REVIEW=FAIL {type(exc).__name__}: {exc}", file=sys.stderr)
        raise
