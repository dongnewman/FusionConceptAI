from __future__ import annotations

import hashlib
import json
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().with_name("coverage_map_r17.json")
OLD_SUITE = ROOT / "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/vnext_t2_identity_receipt_v2_tests.jl"
PROJECTION_SUITE = ROOT / (
    "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/"
    "vnext_t2_package_full_content_projection_r1.jl")
WORK_ORDER = ROOT / "docs/v4_multitopology_generation/16_execution_work_orders.md"
ACTUAL_DRIVER = Path(__file__).resolve().with_name("actual_formal_negative_driver_r6.jl")
SUPPLEMENTARY_DRIVER = Path(__file__).resolve().with_name(
    "supplementary_contract_driver_r1.jl")
CONTROLLER = Path(__file__).resolve().with_name("independent_negative_controller_r18.py")
ATTEMPT7_COVERAGE = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol/coverage_map_r2.json")
ATTEMPT9C_COVERAGE = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt9c_final/coverage_map_r3.json")

EXPECTED_OLD_SUITE_SHA256 = (
    "edefda4defb0a94c7fc0935579f75e5d7c7431e97006eebee4186b9210ee8587"
)
EXPECTED_PROJECTION_SUITE_SHA256 = (
    "041a11f5852b5efaaac3992f108d59a6d98a59d0fbbf7a21504937b0234dde91"
)

ACTUAL_RUNTIME_CASE_IDS = [
    "ACTUAL_BASELINE_POSITIVE",
    "SRC_BYTES_ONLY", "SRC_HASH_ONLY", "SRC_BYTES_REHASHED",
    "SRC_ZERO_BYTES_HASH", "SOURCE_EDIT_NO_REBUILD",
    "WIRE_GATE_STALE", "SEMANTIC_GATE_FOREIGN", "PACKAGE_GATE_FOREIGN",
    "CANDIDATE_STALE", "CANDIDATE_FOREIGN",
    "T0_STALE", "T0_FOREIGN", "AXIS_STALE", "AXIS_FOREIGN",
    "CHILD_STALE", "CHILD_FOREIGN", "FEEDBACK_STALE",
    "FEEDBACK_FOREIGN", "PARENT_STALE", "PARENT_FOREIGN",
    "G3_STALE", "G3_FOREIGN", "ACTUAL_FOREIGN_SCENARIO",
    "ACTUAL_TYPED_ABSENCE", "ACTUAL_FORMAL_GATE_REJECTION",
    "ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR",
    "ACTUAL_DUPLICATE_INVOCATION",
    "FAULT_E0", "FAULT_GI1A", "FAULT_E1", "FAULT_E2", "FAULT_UP2",
    "ACTUAL_N10_BASELINE", "ACTUAL_N10_N10_01", "ACTUAL_N10_N10_02",
    "ACTUAL_N10_N10_03", "ACTUAL_N10_N10_04", "ACTUAL_N10_N10_05",
    "ACTUAL_COUPLING_DIAGNOSTIC_MUTATION",
    "ACTUAL_T1_PARENT_DOMAIN_MISMATCH", "ACTUAL_T1_ABSENCE_HANDOFF",
    "ACTUAL_T1_STALE_RESULT", "ACTUAL_T1_FORGED_RESULT",
    "SUP_CONSTRUCTOR_BOUNDARY",
]

ACTUAL_OBSERVATION_IDS = [
    *ACTUAL_RUNTIME_CASE_IDS[
        :ACTUAL_RUNTIME_CASE_IDS.index(
            "ACTUAL_COUPLING_DIAGNOSTIC_MUTATION") + 1],
    "ACTUAL_T1_PARENT_DOMAIN_INPUT",
    "ACTUAL_T1_PARENT_DOMAIN_MISMATCH",
    "ACTUAL_T1_ABSENCE_INPUT",
    "ACTUAL_T1_ABSENCE_HANDOFF",
    "ACTUAL_T1_MALFORMED_WIRE_INPUT",
    "ACTUAL_T1_STALE_RESULT",
    "ACTUAL_T1_FORGED_RESULT",
    "SUP_CONSTRUCTOR_BOUNDARY",
]

ACTUAL_PHASE_CASE_IDS = {
    "actual_formal_baseline": ["ACTUAL_BASELINE_POSITIVE"],
    "actual_formal_preflight": [
        "SRC_BYTES_ONLY", "SRC_HASH_ONLY", "SRC_BYTES_REHASHED",
        "SRC_ZERO_BYTES_HASH", "SOURCE_EDIT_NO_REBUILD",
        "WIRE_GATE_STALE", "SEMANTIC_GATE_FOREIGN",
        "PACKAGE_GATE_FOREIGN", "CANDIDATE_STALE", "CANDIDATE_FOREIGN",
        "T0_STALE", "T0_FOREIGN", "AXIS_STALE", "AXIS_FOREIGN",
        "CHILD_STALE", "CHILD_FOREIGN", "FEEDBACK_STALE",
        "FEEDBACK_FOREIGN"],
    "actual_formal_authority": [
        "PARENT_STALE", "PARENT_FOREIGN", "G3_STALE", "G3_FOREIGN",
        "ACTUAL_FOREIGN_SCENARIO", "ACTUAL_TYPED_ABSENCE",
        "ACTUAL_FORMAL_GATE_REJECTION",
        "ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR",
        "ACTUAL_DUPLICATE_INVOCATION"],
    "actual_formal_fault_n10": [
        "FAULT_E0", "FAULT_GI1A", "FAULT_E1", "FAULT_E2", "FAULT_UP2",
        "ACTUAL_N10_BASELINE", "ACTUAL_N10_N10_01",
        "ACTUAL_N10_N10_02", "ACTUAL_N10_N10_03",
        "ACTUAL_N10_N10_04", "ACTUAL_N10_N10_05",
        "ACTUAL_COUPLING_DIAGNOSTIC_MUTATION"],
    "actual_formal_t1_handoff": [
        "ACTUAL_T1_PARENT_DOMAIN_MISMATCH", "ACTUAL_T1_ABSENCE_HANDOFF",
        "ACTUAL_T1_STALE_RESULT", "ACTUAL_T1_FORGED_RESULT",
        "SUP_CONSTRUCTOR_BOUNDARY"],
}
ACTUAL_CASE_PHASE = {
    case_id: phase for phase, case_ids in ACTUAL_PHASE_CASE_IDS.items()
    for case_id in case_ids
}
ACTUAL_PHASE_OBSERVATION_IDS = {
    "actual_formal_baseline": ["ACTUAL_BASELINE_POSITIVE"],
    "actual_formal_preflight": ACTUAL_PHASE_CASE_IDS[
        "actual_formal_preflight"],
    "actual_formal_authority": ACTUAL_PHASE_CASE_IDS[
        "actual_formal_authority"],
    "actual_formal_fault_n10": ACTUAL_PHASE_CASE_IDS[
        "actual_formal_fault_n10"],
    "actual_formal_t1_handoff": [
        "ACTUAL_T1_PARENT_DOMAIN_INPUT",
        "ACTUAL_T1_PARENT_DOMAIN_MISMATCH",
        "ACTUAL_T1_ABSENCE_INPUT", "ACTUAL_T1_ABSENCE_HANDOFF",
        "ACTUAL_T1_MALFORMED_WIRE_INPUT", "ACTUAL_T1_STALE_RESULT",
        "ACTUAL_T1_FORGED_RESULT", "SUP_CONSTRUCTOR_BOUNDARY"],
}

SUPPLEMENTARY_RUNTIME_CASE_IDS = {
    "edited_operation": [
        "SUP_EDITED_OPERATION_DEFERRAL", "SUP_SYNTHETIC_GATE_BOUNDARY"],
    "child_coupling": [
        "SUP_CHILD_COUPLING_CONTRADICTION", "SUP_SYNTHETIC_GATE_BOUNDARY"],
}

HELPER_RUNTIME_CASE_IDS = {
    "artifact_hash_precondition": "HELPER_ARTIFACT_HASH_PRECONDITION",
    "artifact_recomputed_corrupt":
        "HELPER_ARTIFACT_DESERIALIZE_PRECONDITION",
    "artifact_zero_malformed": "HELPER_ARTIFACT_DESERIALIZE_PRECONDITION",
}

FORMAL_ARTIFACT_RUNTIME_CASE_IDS = {
    "formal_driver_artifact_raw_hash_precondition":
        "FORMAL_ARTIFACT_HASH_PRECONDITION",
    "formal_driver_artifact_deserialize_precondition":
        "FORMAL_ARTIFACT_DESERIALIZE_PRECONDITION",
    "formal_driver_artifact_zero_precondition":
        "FORMAL_ARTIFACT_ZERO_PRECONDITION",
    "formal_driver_artifact_wrong_type_precondition":
        "FORMAL_ARTIFACT_WRONG_TYPE_PRECONDITION",
    "formal_driver_artifact_foreign_package_precondition":
        "FORMAL_ARTIFACT_FOREIGN_PACKAGE_PRECONDITION",
}

DRIVER_POSTCONDITION_RUNTIME_CASE_IDS = {
    "candidate_receipt_precondition": "CANDIDATE_RECEIPT_PRECONDITION",
    "serialized_result_postcondition": "SERIALIZED_RESULT_POSTCONDITION",
    "stable_projection_postcondition": "STABLE_PROJECTION_POSTCONDITION",
}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def receipt(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    return {
        "path": path.relative_to(ROOT).as_posix(),
        "bytes": len(data),
        "sha256": sha256_bytes(data),
    }


def assertion_sites(text: str) -> list[dict[str, Any]]:
    lines = text.splitlines()
    sites: list[dict[str, Any]] = []
    for index, line in enumerate(lines):
        stripped = line.lstrip()
        if not (stripped.startswith("@test ") or
                stripped.startswith("@test\n") or
                stripped.startswith("@test_throws ")):
            continue
        indent = len(line) - len(stripped)
        body = [stripped]
        cursor = index + 1
        while cursor < len(lines):
            candidate = lines[cursor]
            candidate_stripped = candidate.lstrip()
            candidate_indent = len(candidate) - len(candidate_stripped)
            if not candidate_stripped or candidate_stripped.startswith("#"):
                break
            if candidate_indent <= indent:
                break
            body.append(candidate_stripped)
            cursor += 1
        expression = " ".join(part.strip() for part in body)
        sites.append({
            "id": f"OLD_SYN_{len(sites) + 1:03d}",
            "line": index + 1,
            "macro_name": "@test_throws" if
                stripped.startswith("@test_throws ") else "@test",
            "source_text": expression,
            "source_text_sha256": sha256_bytes(expression.encode("utf-8")),
            "runtime_multiplicity": 5 if 126 <= index + 1 <= 130 else 1,
        })
    return sites


def projection_regression_inventory() -> dict[str, Any]:
    frozen = receipt(PROJECTION_SUITE)
    if frozen["sha256"] != EXPECTED_PROJECTION_SUITE_SHA256:
        raise RuntimeError(
            f"versioned projection suite drift: {frozen['sha256']}")
    sites = assertion_sites(PROJECTION_SUITE.read_text(encoding="utf-8"))
    if len(sites) != 24:
        raise RuntimeError(
            f"expected 24 versioned projection assertion sites, got {len(sites)}")
    groups = {
        "full_package_projection_positive": [],
        "wire_byte_rebuilt_carrier_attack": [],
        "source_byte_rebuilt_carrier_attack": [],
        "admission_projection_positive": [],
    }
    for index, site in enumerate(sites, 1):
        site["id"] = f"PROJECTION-R1-{index:03d}"
        site["path"] = frozen["path"]
        if index <= 8:
            group = "full_package_projection_positive"
        elif index <= 15:
            group = "wire_byte_rebuilt_carrier_attack"
        elif index <= 22:
            group = "source_byte_rebuilt_carrier_attack"
        else:
            group = "admission_projection_positive"
        site["semantic_group"] = group
        groups[group].append(site["id"])
    expected_group_counts = {
        "full_package_projection_positive": 8,
        "wire_byte_rebuilt_carrier_attack": 7,
        "source_byte_rebuilt_carrier_attack": 7,
        "admission_projection_positive": 2,
    }
    if {name: len(ids) for name, ids in groups.items()} != \
            expected_group_counts:
        raise RuntimeError("versioned projection group inventory mismatch")
    return {
        "classification": "additive_versioned_product_repair_regression",
        "original_154_baseline_changed": False,
        "suite": frozen,
        "assertion_site_count": len(sites),
        "expected_runtime_hit_count": len(sites),
        "assertion_sites": sites,
        "semantic_groups": groups,
        "semantic_group_counts": expected_group_counts,
        "execution_requirement":
            "must execute exactly once as a separately receipted supplemental product-regression phase",
    }


def successor_assertion_sites() -> tuple[
        list[dict[str, Any]], dict[str, list[str]], dict[str, list[str]],
        dict[str, tuple[str, ...]]]:
    rows: list[dict[str, Any]] = []
    by_region: dict[str, list[str]] = {}

    def add_file(path: Path, prefix: str) -> tuple[list[str], list[dict[str, Any]]]:
        text = path.read_text(encoding="utf-8")
        lines = text.splitlines()
        sites = assertion_sites(text)
        for site in sites:
            site["id"] = f"{prefix}-{len(rows) + 1:03d}"
            site["path"] = path.relative_to(ROOT).as_posix()
            site["runtime_multiplicity"] = 1
            rows.append(site)
        return lines, sites

    actual_lines, actual_sites = add_file(ACTUAL_DRIVER, "NEW-ACT")
    supplementary_lines, supplementary_sites = add_file(
        SUPPLEMENTARY_DRIVER, "NEW-SUP")

    def line_of(lines: list[str], token: str, start: int = 1) -> int:
        for index in range(start - 1, len(lines)):
            if token in lines[index]:
                return index + 1
        raise RuntimeError(f"successor assertion anchor absent: {token}")

    def region(name: str, sites: list[dict[str, Any]], lo: int, hi: int,
               multiplicity: int = 1) -> None:
        selected = [site for site in sites if lo <= site["line"] < hi]
        if not selected:
            raise RuntimeError(f"successor assertion region empty: {name}")
        for site in selected:
            if site["runtime_multiplicity"] != 1 and \
                    site["runtime_multiplicity"] != multiplicity:
                raise RuntimeError(f"overlapping multiplicity regions: {site}")
            site["runtime_multiplicity"] = multiplicity
        by_region[name] = [site["id"] for site in selected]

    run_zero = line_of(actual_lines, "function _t2_neg_run_zero!")
    run_build = line_of(actual_lines, "function _t2_neg_run_build_zero!")
    source_carrier = line_of(actual_lines, "function _t2_neg_source_carrier_input")
    baseline = line_of(actual_lines, "function _t2_neg_require_baseline!")
    fault = line_of(actual_lines, "function _t2_neg_fault_case!")
    support = line_of(actual_lines, "function _t2_neg_revalidate_source(")
    transport = line_of(actual_lines, "function _t2_neg_require_transport!")
    preflight_group = line_of(actual_lines,
                              "function _t2_neg_group_preflight!")
    region("actual_zero_preflight_helper", actual_sites,
           run_zero, run_build, 22)
    region("actual_t1_build_zero_helper", actual_sites,
           run_build, source_carrier, 6)
    region("actual_baseline", actual_sites, baseline, fault)
    region("actual_fault_helper", actual_sites, fault, support, 5)
    region("context_transport_validation", actual_sites,
           transport, preflight_group, 4)

    typed_absence = line_of(actual_lines, "absent_build =")
    gate_rejection = line_of(actual_lines, "rejected_gate =")
    duplicate = line_of(actual_lines, "duplicate =", gate_rejection)
    no_prior_rejection = line_of(actual_lines, "no_prior_before =",
                                 gate_rejection)
    fault_loop = line_of(actual_lines, "for (stage, reason, order)")
    n10_baseline = line_of(actual_lines, "projection =", fault_loop)
    n10_loop = line_of(actual_lines, "for (row_id, expected_reason)")
    projection_reload = line_of(actual_lines, "projection_io =")
    coupling = line_of(actual_lines, "coupling_input =", projection_reload)
    mixed_t1 = line_of(actual_lines, "mixed_admission_input =")
    missing_t1 = line_of(actual_lines, "missing_admission_input =")
    stale_t1 = line_of(actual_lines, "malformed_bytes =")
    forged_t1 = line_of(actual_lines, "forged_admission =")
    constructor = line_of(actual_lines, "thrown = try")
    actual_finally = line_of(actual_lines,
                             "const T2_NEG_SHARD_SUMMARY_IDS", constructor)
    parent_cases = line_of(actual_lines, "chain_view =")
    g3_cases = line_of(actual_lines,
                       'for label in ("stale", "foreign")', parent_cases)
    region("actual_typed_absence", actual_sites, typed_absence, gate_rejection)
    region("actual_formal_gate_rejection", actual_sites,
           gate_rejection, no_prior_rejection)
    region("actual_formal_gate_rejection_no_prior", actual_sites,
           no_prior_rejection, duplicate)
    region("actual_duplicate", actual_sites, duplicate, fault_loop)
    region("actual_n10_baseline", actual_sites, n10_baseline, n10_loop)
    region("actual_n10_rows", actual_sites, n10_loop, projection_reload, 5)
    region("actual_n10_reload", actual_sites, projection_reload, coupling)
    region("actual_coupling_diagnostic", actual_sites, coupling, mixed_t1)
    region("actual_t1_parent_domain", actual_sites, mixed_t1, missing_t1)
    region("actual_t1_absence", actual_sites, missing_t1, stale_t1)
    region("actual_t1_stale", actual_sites, stale_t1, forged_t1)
    region("actual_constructor", actual_sites, constructor, actual_finally)
    region("actual_parent_stale_structural", actual_sites,
           parent_cases, g3_cases)

    edited_start = line_of(supplementary_lines,
                           "if mode === :edited_operation")
    child_start = line_of(supplementary_lines, "        else", edited_start)
    supplement_catch = line_of(supplementary_lines, "catch error", child_start)
    region("supplementary_edited", supplementary_sites,
           edited_start, child_start)
    region("supplementary_child", supplementary_sites,
           child_start, supplement_catch)
    by_region["supplementary_all"] = [site["id"]
                                       for site in supplementary_sites]

    case_regions = {
        "ACTUAL_BASELINE_POSITIVE": ("actual_baseline",),
        "ACTUAL_N10_BASELINE": ("actual_n10_baseline",
                                 "actual_n10_reload"),
        "ACTUAL_TYPED_ABSENCE": ("actual_typed_absence",),
        "ACTUAL_FORMAL_GATE_REJECTION":
            ("actual_formal_gate_rejection",
             "actual_t1_build_zero_helper"),
        "ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR":
            ("actual_formal_gate_rejection_no_prior",),
        "ACTUAL_DUPLICATE_INVOCATION": ("actual_duplicate",),
        "ACTUAL_T1_PARENT_DOMAIN_MISMATCH":
            ("actual_t1_parent_domain", "actual_t1_build_zero_helper"),
        "ACTUAL_T1_ABSENCE_HANDOFF":
            ("actual_t1_absence", "actual_t1_build_zero_helper"),
        "ACTUAL_T1_STALE_RESULT":
            ("actual_t1_stale", "actual_t1_build_zero_helper"),
        "ACTUAL_T1_FORGED_RESULT":
            ("actual_t1_build_zero_helper",),
        "SUP_CONSTRUCTOR_BOUNDARY": ("actual_constructor",),
        "ACTUAL_COUPLING_DIAGNOSTIC_MUTATION":
            ("actual_coupling_diagnostic",),
        "SUP_CHILD_COUPLING_CONTRADICTION": ("supplementary_child",),
        "SUP_EDITED_OPERATION_DEFERRAL": ("supplementary_edited",),
        "SUP_SYNTHETIC_GATE_BOUNDARY": ("supplementary_all",),
        "PARENT_STALE":
            ("actual_t1_build_zero_helper",
             "actual_parent_stale_structural"),
    }
    for case in ("ACTUAL_N10_N10_01", "ACTUAL_N10_N10_02",
                 "ACTUAL_N10_N10_03", "ACTUAL_N10_N10_04",
                 "ACTUAL_N10_N10_05"):
        case_regions[case] = ("actual_n10_rows",)
    for case in ("FAULT_E0", "FAULT_GI1A", "FAULT_E1",
                 "FAULT_E2", "FAULT_UP2"):
        case_regions[case] = ("actual_fault_helper",)
    for case in ("SRC_BYTES_ONLY", "SRC_HASH_ONLY", "SRC_BYTES_REHASHED",
                 "SRC_ZERO_BYTES_HASH", "SOURCE_EDIT_NO_REBUILD",
                 "WIRE_GATE_STALE", "SEMANTIC_GATE_FOREIGN",
                 "PACKAGE_GATE_FOREIGN", "CANDIDATE_STALE",
                 "CANDIDATE_FOREIGN", "T0_STALE", "T0_FOREIGN",
                 "AXIS_STALE", "AXIS_FOREIGN", "CHILD_STALE",
                 "CHILD_FOREIGN", "FEEDBACK_STALE", "FEEDBACK_FOREIGN",
                 "PARENT_FOREIGN", "G3_STALE", "G3_FOREIGN",
                 "ACTUAL_FOREIGN_SCENARIO"):
        case_regions[case] = ("actual_zero_preflight_helper",)

    case_assertions = {
        case: sorted({assertion_id for region_name in regions
                      for assertion_id in by_region[region_name]})
        for case, regions in case_regions.items()
    }
    return rows, case_assertions, by_region, case_regions


def mapping_for_line(line: int) -> tuple[list[str], str]:
    if line <= 92:
        if line in {13, 14, 35, 37, 90}:
            return (["SUP_SYNTHETIC_GATE_BOUNDARY",
                     "ACTUAL_BASELINE_POSITIVE"],
                    "old synthetic-gate fact retained separately and strengthened by actual-gate evidence")
        return (["ACTUAL_BASELINE_POSITIVE"],
                "actual formal baseline preserves the positive semantic obligation")
    if line <= 135:
        if 126 <= line <= 130:
            return (["ACTUAL_N10_N10_01", "ACTUAL_N10_N10_02",
                     "ACTUAL_N10_N10_03", "ACTUAL_N10_N10_04",
                     "ACTUAL_N10_N10_05"],
                    "the loop site executes once for each of the five actual-formal N10 rows")
        return (["ACTUAL_N10_BASELINE"],
                "actual formal input supplies the projection and reload checks")
    if line <= 215:
        if line <= 150:
            return (["ACTUAL_TYPED_ABSENCE"],
                    "typed absence is checked with the committed baseline ledger held immutable")
        if line <= 157:
            return (["ACTUAL_FOREIGN_SCENARIO"],
                    "actual gate rejects the foreign scenario before downstream consumers")
        if line <= 169:
            if line == 165:
                return (["ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR"],
                        "unaccepted actual formal gate without prior ledger preserves the old ledger-is-nothing branch")
            return (["ACTUAL_FORMAL_GATE_REJECTION"],
                    "actual unaccepted gate rejects before downstream consumers")
        if line <= 174:
            return (["ACTUAL_FORMAL_GATE_REJECTION", "SUP_CONSTRUCTOR_BOUNDARY"],
                    "actual unaccepted gate carries zero receipt hashes; invalid accepted-zero construction remains supplemental")
        if line <= 178:
            return (["ACTUAL_FORMAL_GATE_REJECTION"],
                    "actual gate build preserves the fail-closed status and first reason")
        if line <= 187:
            return (["ACTUAL_DUPLICATE_INVOCATION"],
                    "duplicate invocation preserves the already committed actual ledger")
        if line <= 199:
            return (["FAULT_E0"],
                    "actual-formal E0 fault records its exact attempted prefix and no committed ledger")
        if line <= 208:
            return (["FAULT_GI1A"],
                    "actual-formal GI1A fault records its exact attempted prefix and no committed ledger")
        return (["FAULT_E1"],
                "actual-formal E1 fault records its exact attempted prefix and no committed ledger")
    if line <= 317:
        if line <= 237:
            return (["ACTUAL_T1_PARENT_DOMAIN_MISMATCH"],
                    "actual source-backed T1 handoff rejects mixed parent domains")
        if line <= 252:
            return (["ACTUAL_T1_ABSENCE_HANDOFF"],
                    "actual source-backed T1 handoff preserves typed absence")
        if line <= 278:
            return (["ACTUAL_T1_STALE_RESULT"],
                    "malformed wire and stale T1 result reject before T2 consumers")
        if line <= 296:
            return (["ACTUAL_T1_FORGED_RESULT"],
                    "forged T1 gaps and trace reject before T2 consumers")
        return (["PARENT_STALE"],
                "actual gate executes the old source-parent/T1-parent domain contradiction")
    if line <= 335:
        return (["SUP_CHILD_COUPLING_CONTRADICTION"],
                "one natural coherent_g3_child=false producer preserves the original source contradiction")
    return (["SUP_EDITED_OPERATION_DEFERRAL"],
            "one supplemental edited-realization scenario preserves the old deferred contract")


ACTIVE_CASES: list[dict[str, Any]] = [
    {"id": "ACTUAL_BASELINE_POSITIVE", "domain": "actual_formal_shards", "expected_branch": "five_consumers_complete", "downstream": "E0,GI1A,E1,E2,UP2_N10 exactly once"},
    {"id": "SRC_BYTES_ONLY", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_source_carrier_mismatch", "downstream": "zero"},
    {"id": "SRC_HASH_ONLY", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_source_carrier_mismatch", "downstream": "zero"},
    {"id": "SRC_BYTES_REHASHED", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_source_carrier_mismatch", "downstream": "zero"},
    {"id": "SRC_ZERO_BYTES_HASH", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_source_carrier_mismatch", "downstream": "zero"},
    {"id": "SOURCE_EDIT_NO_REBUILD", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_source_edit_without_rebuild", "downstream": "zero"},
    {"id": "WIRE_GATE_STALE", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_wire_hash_mismatch", "downstream": "zero"},
    {"id": "SEMANTIC_GATE_FOREIGN", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_semantic_identity_mismatch", "downstream": "zero"},
    {"id": "PACKAGE_GATE_FOREIGN", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_package_hash_mismatch", "downstream": "zero"},
    {"id": "CANDIDATE_STALE", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_candidate_ref_mismatch", "downstream": "zero"},
    {"id": "CANDIDATE_FOREIGN", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_candidate_ref_mismatch", "downstream": "zero"},
    {"id": "T0_STALE", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_t0_bundle_mismatch", "downstream": "zero"},
    {"id": "T0_FOREIGN", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_t0_bundle_mismatch", "downstream": "zero"},
    {"id": "AXIS_STALE", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_axis_mismatch", "downstream": "zero"},
    {"id": "AXIS_FOREIGN", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_axis_mismatch", "downstream": "zero"},
    {"id": "CHILD_STALE", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_child_mismatch", "downstream": "zero"},
    {"id": "CHILD_FOREIGN", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_child_mismatch", "downstream": "zero"},
    {"id": "FEEDBACK_STALE", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_feedback_mismatch", "downstream": "zero"},
    {"id": "FEEDBACK_FOREIGN", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_feedback_mismatch", "downstream": "zero"},
    {"id": "PARENT_STALE", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_parent_commitment_mismatch", "downstream": "zero"},
    {"id": "PARENT_FOREIGN", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_parent_commitment_mismatch", "downstream": "zero"},
    {"id": "G3_STALE", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_g3_authority_mismatch", "downstream": "zero"},
    {"id": "G3_FOREIGN", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_g3_authority_mismatch", "downstream": "zero"},
    {"id": "ACTUAL_FOREIGN_SCENARIO", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_scenario_mismatch", "downstream": "zero"},
    {"id": "ACTUAL_TYPED_ABSENCE", "domain": "actual_formal_shards", "expected_branch": "typed_absent", "downstream": "zero"},
    {"id": "ACTUAL_FORMAL_GATE_REJECTION", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_formal_t1_not_accepted", "downstream": "zero"},
    {"id": "ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_formal_t1_not_accepted/no_prior_ledger", "downstream": "zero; ledger remains nothing"},
    {"id": "ACTUAL_DUPLICATE_INVOCATION", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_duplicate_invocation", "downstream": "zero"},
    {"id": "FAULT_E0", "domain": "actual_formal_shards", "expected_branch": "e0_program_exception", "downstream": "attempt E0"},
    {"id": "FAULT_GI1A", "domain": "actual_formal_shards", "expected_branch": "gi1a_program_exception", "downstream": "attempt E0,GI1A"},
    {"id": "FAULT_E1", "domain": "actual_formal_shards", "expected_branch": "e1_program_exception", "downstream": "attempt E0,GI1A,E1"},
    {"id": "FAULT_E2", "domain": "actual_formal_shards", "expected_branch": "e2_program_exception", "downstream": "attempt E0,GI1A,E1,E2"},
    {"id": "FAULT_UP2", "domain": "actual_formal_shards", "expected_branch": "up2_program_exception", "downstream": "attempt all five"},
    {"id": "ACTUAL_N10_BASELINE", "domain": "actual_formal_shards", "expected_branch": "actual formal N10 projection valid and reload stable", "downstream": "direct actual-gate projection validation"},
    {"id": "ACTUAL_N10_N10_01", "domain": "actual_formal_shards", "expected_branch": "up2_n10_01_g1_schema_descriptor_mismatch", "downstream": "direct actual-gate projection validation"},
    {"id": "ACTUAL_N10_N10_02", "domain": "actual_formal_shards", "expected_branch": "up2_n10_02_g2_canonicalization_descriptor_mismatch", "downstream": "direct actual-gate projection validation"},
    {"id": "ACTUAL_N10_N10_03", "domain": "actual_formal_shards", "expected_branch": "up2_n10_03_g3_binding_child_identity_mismatch", "downstream": "direct actual-gate projection validation"},
    {"id": "ACTUAL_N10_N10_04", "domain": "actual_formal_shards", "expected_branch": "up2_n10_04_t1_package_hash_mismatch", "downstream": "direct actual-gate projection validation"},
    {"id": "ACTUAL_N10_N10_05", "domain": "actual_formal_shards", "expected_branch": "up2_n10_05_reload_binding_identity_mismatch", "downstream": "direct actual-gate projection validation"},
    {"id": "ACTUAL_COUPLING_DIAGNOSTIC_MUTATION", "domain": "actual_formal_shards", "expected_branch": "e2_declared_source_child_contradiction", "downstream": "attempt E0,GI1A,E1,E2; formal diagnostic mutation"},
    {"id": "ACTUAL_T1_PARENT_DOMAIN_MISMATCH", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_t1_admission_input_mismatch", "downstream": "zero"},
    {"id": "ACTUAL_T1_ABSENCE_HANDOFF", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_t1_admission_absent", "downstream": "zero"},
    {"id": "ACTUAL_T1_STALE_RESULT", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_t1_admission_result_mismatch", "downstream": "zero"},
    {"id": "ACTUAL_T1_FORGED_RESULT", "domain": "actual_formal_shards", "expected_branch": "t2_preflight_t1_admission_result_mismatch", "downstream": "zero"},
    {"id": "FORMAL_ARTIFACT_HASH_PRECONDITION", "domain": "artifact_and_driver_boundaries", "expected_branch": "producer_artifact_hash_precondition", "downstream": "zero; real formal driver"},
    {"id": "FORMAL_ARTIFACT_DESERIALIZE_PRECONDITION", "domain": "artifact_and_driver_boundaries", "expected_branch": "producer_artifact_deserialize_precondition", "downstream": "zero; real formal driver"},
    {"id": "FORMAL_ARTIFACT_ZERO_PRECONDITION", "domain": "artifact_and_driver_boundaries", "expected_branch": "producer_artifact_deserialize_precondition", "downstream": "zero; real formal driver"},
    {"id": "FORMAL_ARTIFACT_WRONG_TYPE_PRECONDITION", "domain": "artifact_and_driver_boundaries", "expected_branch": "producer_artifact_deserialize_precondition/type_invalid", "downstream": "zero; real formal driver"},
    {"id": "FORMAL_ARTIFACT_FOREIGN_PACKAGE_PRECONDITION", "domain": "artifact_and_driver_boundaries", "expected_branch": "producer_artifact_deserialize_precondition/expected_admission_mismatch", "downstream": "zero; real formal driver"},
    {"id": "CANDIDATE_RECEIPT_PRECONDITION", "domain": "artifact_and_driver_boundaries", "expected_branch": "candidate_receipt_precondition", "downstream": "zero"},
    {"id": "SERIALIZED_RESULT_POSTCONDITION", "domain": "artifact_and_driver_boundaries", "expected_branch": "serialized_result_postcondition", "downstream": "all five attempted; no publication"},
    {"id": "STABLE_PROJECTION_POSTCONDITION", "domain": "artifact_and_driver_boundaries", "expected_branch": "stable_projection_postcondition", "downstream": "all five attempted; no publication"},
    {"id": "PREEXISTING_OWNED_TARGETS", "domain": "artifact_and_driver_boundaries", "expected_branch": "formal_t2_output_artifact_already_exists", "downstream": "zero; every owned target and prior publication set remain byte-identical"},
    {"id": "PREEXISTING_EXTERNAL_SYMLINK", "domain": "artifact_and_driver_boundaries", "expected_branch": "formal_t2_output_artifact_already_exists", "downstream": "zero; external sentinel remains byte-identical"},
    {"id": "HELPER_ARTIFACT_HASH_PRECONDITION", "domain": "supplementary_artifact_helper", "expected_branch": "raw hash mismatch helper observation", "downstream": "not formal-driver qualification"},
    {"id": "HELPER_ARTIFACT_DESERIALIZE_PRECONDITION", "domain": "supplementary_artifact_helper", "expected_branch": "real Serialization.deserialize helper observation", "downstream": "not formal-driver qualification"},
    {"id": "SUP_SYNTHETIC_GATE_BOUNDARY", "domain": "supplementary_contract", "expected_branch": "synthetic_local remains non-formal", "downstream": "not formal qualification"},
    {"id": "SUP_CONSTRUCTOR_BOUNDARY", "domain": "supplementary_contract", "expected_branch": "constructor rejects invalid accepted receipt identities", "downstream": "constructor only"},
    {"id": "SUP_CHILD_COUPLING_CONTRADICTION", "domain": "supplementary_contract", "expected_branch": "natural coherent_g3_child=false producer reaches e2_declared_source_child_contradiction", "downstream": "attempt E0,GI1A,E1,E2; synthetic-local contract evidence"},
    {"id": "SUP_EDITED_OPERATION_DEFERRAL", "domain": "supplementary_contract", "expected_branch": "e2_operation_replay_evidence_missing", "downstream": "one supplemental natural scenario"},
]


def main() -> int:
    old = receipt(OLD_SUITE)
    if old["sha256"] != EXPECTED_OLD_SUITE_SHA256:
        raise RuntimeError(f"old focused suite drift: {old['sha256']}")
    sites = assertion_sites(OLD_SUITE.read_text(encoding="utf-8"))
    if len(sites) != 154:
        raise RuntimeError(f"expected 154 old assertion sites, got {len(sites)}")
    for site in sites:
        site["path"] = old["path"]
    projection_regression = projection_regression_inventory()
    successor_sites, case_assertions, successor_regions, case_regions = \
        successor_assertion_sites()
    exact_old_site_successors = {
        8: "@test build.input isa FusionConceptAI.VNextT2UP2BoundInputV2",
        11: "@test input_validation.status === :valid",
        12: "@test input_validation.reason === :none",
        21: "@test material.package.package_hash == material.t1.admission.package.package_hash",
        91: "@test build.input.package.package_hash == package_hash_before",
        134: "@test projection_reload.projection_hash == projection.projection_hash",
        135: "@test FusionConceptAI.vnext_t2_validate_identity_receipt_v2( projection_reload).status === :valid",
        165: "@test rejected_without_prior.ledger === nothing",
        311: "@test build.status === expected_status",
        312: "@test build.reason === expected_reason",
    }
    for site in sites:
        targets, note = mapping_for_line(site["line"])
        site["successor_obligations"] = targets
        try:
            site["successor_assertion_ids"] = sorted({
                assertion_id for target in targets
                for assertion_id in case_assertions[target]})
        except KeyError as error:
            raise RuntimeError(
                f"old assertion maps to a case without executable Julia assertions: {error}") from error
        if site["line"] in exact_old_site_successors:
            expected_source = exact_old_site_successors[site["line"]]
            exact = [row["id"] for row in successor_sites
                     if row["source_text"] == expected_source]
            if len(exact) != 1:
                raise RuntimeError(
                    f"exact old-site successor is not unique: {site['line']}")
            site["successor_assertion_ids"] = exact
            note += "; exact direct successor assertion is frozen"
        site["mapping_note"] = note
    work_lines = WORK_ORDER.read_text(encoding="utf-8").splitlines()
    work_text = work_lines[526]
    runtime_case_hits = [*ACTUAL_RUNTIME_CASE_IDS]
    for rows in SUPPLEMENTARY_RUNTIME_CASE_IDS.values():
        runtime_case_hits.extend(rows)
    runtime_case_hits.extend(HELPER_RUNTIME_CASE_IDS.values())
    runtime_case_hits.extend(FORMAL_ARTIFACT_RUNTIME_CASE_IDS.values())
    runtime_case_hits.extend(["PREEXISTING_OWNED_TARGETS"] * 7)
    runtime_case_hits.append("PREEXISTING_EXTERNAL_SYMLINK")
    runtime_case_hits.extend(DRIVER_POSTCONDITION_RUNTIME_CASE_IDS.values())
    runtime_case_hit_counts = dict(sorted(Counter(runtime_case_hits).items()))
    active_case_ids = [row["id"] for row in ACTIVE_CASES]
    if set(runtime_case_hit_counts) != set(active_case_ids):
        raise RuntimeError({
            "runtime_case_plan_missing": sorted(
                set(active_case_ids) - set(runtime_case_hit_counts)),
            "runtime_case_plan_unknown": sorted(
                set(runtime_case_hit_counts) - set(active_case_ids)),
        })
    if len(ACTUAL_OBSERVATION_IDS) != len(ACTUAL_RUNTIME_CASE_IDS) + 3:
        raise RuntimeError("actual observation inventory must add three input diagnostics")

    assertion_phase_order = [
        "actual_formal_baseline", "actual_formal_preflight",
        "actual_formal_authority", "actual_formal_fault_n10",
        "actual_formal_t1_handoff", "supplementary_edited_operation",
        "supplementary_child_coupling",
    ]
    site_phase_hits: dict[str, Counter[str]] = {
        site["id"]: Counter() for site in successor_sites}
    for case_id, regions in case_regions.items():
        if case_id == "SUP_SYNTHETIC_GATE_BOUNDARY":
            # This aggregate obligation is observed in both supplemental phases;
            # its constituent assertion sites execute in their own branch once.
            continue
        phase = ACTUAL_CASE_PHASE.get(case_id)
        if phase is None:
            phase = {
                "SUP_EDITED_OPERATION_DEFERRAL":
                    "supplementary_edited_operation",
                "SUP_CHILD_COUPLING_CONTRADICTION":
                    "supplementary_child_coupling",
            }.get(case_id)
        if phase is None:
            continue
        for assertion_id in case_assertions[case_id]:
            site_phase_hits[assertion_id][phase] += \
                runtime_case_hit_counts[case_id]
    for assertion_id in successor_regions["context_transport_validation"]:
        for phase in assertion_phase_order[1:5]:
            site_phase_hits[assertion_id][phase] += 1

    site_rows = {site["id"]: site for site in successor_sites}
    phase_site_hit_counts = {phase: {} for phase in assertion_phase_order}
    for assertion_id, counts in site_phase_hits.items():
        expected_total = site_rows[assertion_id]["runtime_multiplicity"]
        actual_total = sum(counts.values())
        if actual_total != expected_total:
            raise RuntimeError({
                "assertion_site_runtime_mapping_mismatch": assertion_id,
                "source_line": site_rows[assertion_id]["line"],
                "expected_runtime_multiplicity": expected_total,
                "mapped_phase_hits": dict(sorted(counts.items())),
            })
        site_rows[assertion_id]["expected_phase_hits"] = dict(
            sorted(counts.items()))
        for phase, count in counts.items():
            phase_site_hit_counts[phase][assertion_id] = count
    expected_site_hit_total = sum(
        sum(counts.values()) for counts in phase_site_hit_counts.values())
    if expected_site_hit_total != sum(
            site["runtime_multiplicity"] for site in successor_sites):
        raise RuntimeError("source assertion site hit plan total mismatch")
    authority_case_order = [
        "PARENT_STALE", "PARENT_FOREIGN", "G3_STALE", "G3_FOREIGN",
        "ACTUAL_FOREIGN_SCENARIO", "ACTUAL_TYPED_ABSENCE",
        "ACTUAL_FORMAL_GATE_REJECTION",
        "ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR",
        "ACTUAL_DUPLICATE_INVOCATION",
    ]
    authority_source_ids = sorted(
        site["id"] for site in successor_sites
        if site["path"] == ACTUAL_DRIVER.relative_to(ROOT).as_posix())
    authority_case_site_hits: dict[str, dict[str, int]] = {}
    for case_id in authority_case_order:
        case_ids = set(case_assertions[case_id])
        counts = {site_id: int(site_id in case_ids)
                  for site_id in authority_source_ids}
        if case_id == authority_case_order[0]:
            for site_id in successor_regions["context_transport_validation"]:
                counts[site_id] = counts.get(site_id, 0) + 1
        authority_case_site_hits[case_id] = dict(sorted(counts.items()))
    merged_authority_case_hits = Counter()
    for counts in authority_case_site_hits.values():
        merged_authority_case_hits.update(counts)
    expected_authority = {
        site_id: int(phase_site_hit_counts["actual_formal_authority"].get(
            site_id, 0)) for site_id in authority_source_ids}
    if dict(merged_authority_case_hits) != expected_authority:
        raise RuntimeError("authority case-hit allocation does not join the frozen phase plan")
    if len(authority_source_ids) != 175 or sum(expected_authority.values()) != 118 or             sum(count > 0 for count in expected_authority.values()) != 75:
        raise RuntimeError("authority case-hit static plan differs from 175/75/118")
    authority_case_hit_plan = {
        "schema": "vnext-t2-authority-case-hit-plan-r1",
        "status": "static_plan_actual_case_hits_pending",
        "phase": "actual_formal_authority",
        "case_order": authority_case_order,
        "source_path": ACTUAL_DRIVER.relative_to(ROOT).as_posix(),
        "source_site_count": len(authority_source_ids),
        "nonzero_site_count": sum(count > 0 for count in expected_authority.values()),
        "expected_hit_count": sum(expected_authority.values()),
        "expected_phase_site_hits": expected_authority,
        "case_site_hit_counts": authority_case_site_hits,
        "context_transport_site_ids": successor_regions[
            "context_transport_validation"],
        "context_transport_hits_assigned_to_case": authority_case_order[0],
        "case_receipts_require_natural_exit_zero": True,
        "partial_case_receipts_never_aggregate": True,
        "formal_t2_accepted": False,
    }

    successor_assertion_runtime_hit_plan = {
        "schema": "vnext-t2-independent-negative-assertion-hit-plan-r8",
        "status": "expected_source_site_hits_static_plan_actual_hits_pending",
        "site_ids_are_unique_source_path_and_line_targets": True,
        "assertion_site_count": len(successor_sites),
        "expected_runtime_hit_count": expected_site_hit_total,
        "phase_order": assertion_phase_order,
        "phase_site_hit_counts": {
            phase: dict(sorted(counts.items()))
            for phase, counts in phase_site_hit_counts.items()},
        "site_expected_phase_hits": {
            assertion_id: site_rows[assertion_id]["expected_phase_hits"]
            for assertion_id in sorted(site_rows)},
        "authority_case_hit_plan": authority_case_hit_plan,
        "preserved_successor": {
            "assertion_site_count": 191,
            "expected_runtime_hit_count": 530,
            "site_ids": sorted(site["id"] for site in successor_sites
                                if site["id"] not in successor_regions[
                                    "context_transport_validation"]),
        },
        "context_transport": {
            "assertion_site_count": len(successor_regions[
                "context_transport_validation"]),
            "expected_runtime_hit_count": sum(
                sum(site_phase_hits[assertion_id].values())
                for assertion_id in successor_regions[
                    "context_transport_validation"]),
            "site_ids": successor_regions["context_transport_validation"],
        },
        "old_focused_suite_mapping": {
            "assertion_site_count": len(sites),
            "planned_runtime_hit_count": sum(
                row["runtime_multiplicity"] for row in sites),
            "status": "mapped_to_successor_not_executed_by_r3_shards",
        },
        "projection24_mapping": {
            "assertion_site_count": projection_regression[
                "assertion_site_count"],
            "planned_runtime_hit_count": projection_regression[
                "expected_runtime_hit_count"],
            "status": "prior_actual_execution_reused_by_r3_python_validator",
        },
    }

    controller_lines = CONTROLLER.read_text(encoding="utf-8").splitlines()

    def controller_sites(token: str) -> list[dict[str, Any]]:
        rows = []
        for line, text in enumerate(controller_lines, 1):
            if token in text:
                stripped = text.strip()
                rows.append({
                    "path": CONTROLLER.relative_to(ROOT).as_posix(),
                    "line": line,
                    "source_text": stripped,
                    "source_text_sha256":
                        sha256_bytes(stripped.encode("utf-8")),
                })
        if not rows:
            raise RuntimeError(f"controller validation anchor absent: {token}")
        return rows

    actual_controller_sites = controller_sites(
        "aggregated_actual_case_ids != expected_actual_case_ids") + \
        controller_sites(
            "aggregated_actual_observation_ids != runtime_plan[")
    supplementary_controller_sites = controller_sites(
        'supplementary_summary.get("observed_case_ids") !=')
    helper_controller_sites = controller_sites(
        "receipt = verify_artifact_helper(")
    uncommitted_controller_sites = controller_sites(
        "receipt = verify_uncommitted(")
    occupied_controller_sites = controller_sites(
        "observed_first_error = require_output_guard_first_error(")
    symlink_controller_sites = controller_sites(
        "symlink_first_error = require_output_guard_first_error(")

    reverse_formal = {case: phase for phase, case in
                      FORMAL_ARTIFACT_RUNTIME_CASE_IDS.items()}
    reverse_post = {case: phase for phase, case in
                    DRIVER_POSTCONDITION_RUNTIME_CASE_IDS.items()}
    runtime_validation_bindings = []
    for case in ACTIVE_CASES:
        case_id = case["id"]
        if case_id in ACTUAL_RUNTIME_CASE_IDS:
            phase_names = [ACTUAL_CASE_PHASE[case_id]]
            validation_sites = actual_controller_sites
        elif case_id == "SUP_EDITED_OPERATION_DEFERRAL":
            phase_names = ["supplementary_edited_operation"]
            validation_sites = supplementary_controller_sites
        elif case_id == "SUP_CHILD_COUPLING_CONTRADICTION":
            phase_names = ["supplementary_child_coupling"]
            validation_sites = supplementary_controller_sites
        elif case_id == "SUP_SYNTHETIC_GATE_BOUNDARY":
            phase_names = ["supplementary_edited_operation",
                           "supplementary_child_coupling"]
            validation_sites = supplementary_controller_sites
        elif case_id in HELPER_RUNTIME_CASE_IDS.values():
            phase_names = [phase for phase, bound_case in
                           HELPER_RUNTIME_CASE_IDS.items()
                           if bound_case == case_id]
            validation_sites = helper_controller_sites
        elif case_id in reverse_formal:
            phase_names = [reverse_formal[case_id]]
            validation_sites = uncommitted_controller_sites
        elif case_id in reverse_post:
            phase_names = [reverse_post[case_id]]
            validation_sites = uncommitted_controller_sites
        elif case_id == "PREEXISTING_OWNED_TARGETS":
            phase_names = ["preexisting_owned_targets_seven_executions"]
            validation_sites = occupied_controller_sites
        elif case_id == "PREEXISTING_EXTERNAL_SYMLINK":
            phase_names = ["preexisting_symlink_owned_target"]
            validation_sites = symlink_controller_sites
        else:
            raise RuntimeError(f"runtime validation binding absent: {case_id}")
        runtime_validation_bindings.append({
            "case_id": case_id,
            "domain": case["domain"],
            "phase_names": phase_names,
            "julia_assertion_ids": case_assertions.get(case_id, []),
            "controller_validation_sites": validation_sites,
            "expected_runtime_hits": runtime_case_hit_counts[case_id],
        })
    ast_sources = []
    for role, path, rows in (
            ("old_focused", OLD_SUITE, sites),
            ("successor", ACTUAL_DRIVER,
             [row for row in successor_sites
              if row["path"] == ACTUAL_DRIVER.relative_to(ROOT).as_posix()]),
            ("successor", SUPPLEMENTARY_DRIVER,
             [row for row in successor_sites
              if row["path"] ==
              SUPPLEMENTARY_DRIVER.relative_to(ROOT).as_posix()]),
            ("projection_regression", PROJECTION_SUITE,
             projection_regression["assertion_sites"])):
        ast_sources.append({
            "role": role,
            **receipt(path),
            "assertion_site_count": len(rows),
        })
    ast_inventory_plan = {
        "schema": "vnext-t2-independent-negative-ast-plan-r3",
        "hash_algorithm": "sha256_sprint_show_ast",
        "semantic_hash_transform": "remove_LineNumberNode_only",
        "control_context_hash_scope": "full_enclosing_control_node",
        "control_context_path_semantics":
            "one_based_expr_child_indexes_from_parseall_root",
        "context_fields": [
            "testset_path", "function_path", "control_context",
            "site_ast_path"],
        "sources": ast_sources,
        "source_count": len(ast_sources),
        "old_assertion_site_count": len(sites),
        "successor_assertion_site_count": len(successor_sites),
        "projection_assertion_site_count":
            projection_regression["assertion_site_count"],
        "total_assertion_site_count":
            len(sites) + len(successor_sites) +
            projection_regression["assertion_site_count"],
        "old_to_successor_mapping_bound_by_site_id": True,
    }
    value = {
        "schema": "vnext-t2-independent-negative-coverage-map-r17",
        "status": "static_coverage_map_no_julia",
        "formal_t2_accepted": False,
        "scientific_acceptance": False,
        "active_work_order": {
            **receipt(WORK_ORDER),
            "line": 527,
            "text": work_text,
            "text_sha256": sha256_bytes(work_text.encode("utf-8")),
        },
        "old_focused_suite": old,
        "old_assertion_site_count": len(sites),
        "old_expected_runtime_hit_count": sum(
            row["runtime_multiplicity"] for row in sites),
        "runtime_multiplicity_is_not_target_ownership": True,
        "old_assertion_sites": sites,
        "versioned_product_repair_regression": projection_regression,
        "ast_inventory_plan": ast_inventory_plan,
        "successor_assertion_site_count": len(successor_sites),
        "successor_expected_runtime_hit_count": sum(
            row["runtime_multiplicity"] for row in successor_sites),
        "preserved_successor_assertion_site_count": len([
            row for row in successor_sites
            if row["id"] not in successor_regions[
                "context_transport_validation"]]),
        "preserved_successor_expected_runtime_hit_count": sum(
            row["runtime_multiplicity"] for row in successor_sites
            if row["id"] not in successor_regions[
                "context_transport_validation"]),
        "context_transport_assertion_site_count":
            len(successor_regions["context_transport_validation"]),
        "context_transport_expected_runtime_hit_count": sum(
            row["runtime_multiplicity"] for row in successor_sites
            if row["id"] in successor_regions[
                "context_transport_validation"]),
        "context_transport_assertion_ids":
            successor_regions["context_transport_validation"],
        "successor_assertion_sites": successor_sites,
        "successor_case_assertion_ids": case_assertions,
        "attempt9c_relocation_ledger": [],
        "successor_cases": ACTIVE_CASES,
        "successor_case_count": len(ACTIVE_CASES),
        "runtime_execution_plan": {
            "actual_formal_summary_case_ids": ACTUAL_RUNTIME_CASE_IDS,
            "actual_formal_observation_ids": ACTUAL_OBSERVATION_IDS,
            "actual_formal_phase_case_ids": ACTUAL_PHASE_CASE_IDS,
            "actual_formal_phase_observation_ids":
                ACTUAL_PHASE_OBSERVATION_IDS,
            "baseline_five_consumer_execution_count": 1,
            "context_transport_validation_execution_count": 4,
            "supplementary_summary_case_ids":
                SUPPLEMENTARY_RUNTIME_CASE_IDS,
            "helper_phase_case_ids": HELPER_RUNTIME_CASE_IDS,
            "formal_artifact_phase_case_ids":
                FORMAL_ARTIFACT_RUNTIME_CASE_IDS,
            "driver_postcondition_phase_case_ids":
                DRIVER_POSTCONDITION_RUNTIME_CASE_IDS,
            "preexisting_owned_target_semantic_case":
                "PREEXISTING_OWNED_TARGETS",
            "preexisting_owned_target_runtime_multiplicity": 7,
            "preexisting_symlink_semantic_case":
                "PREEXISTING_EXTERNAL_SYMLINK",
            "expected_unique_case_ids": active_case_ids,
            "expected_unique_case_count": len(active_case_ids),
            "expected_runtime_case_hit_counts": runtime_case_hit_counts,
            "expected_runtime_case_hit_count": len(runtime_case_hits),
        },
        "successor_assertion_runtime_hit_plan":
            successor_assertion_runtime_hit_plan,
        "runtime_validation_bindings": runtime_validation_bindings,
        "formal_qualification_domains": [
            "actual_formal_shards", "artifact_and_driver_boundaries"],
        "supplementary_nonqualifying_domains": [
            "supplementary_contract", "supplementary_artifact_helper"],
        "observe_first_required": True,
        "actual_observation_before_assertion": [
            "type", "status", "resolution", "first_reason", "errors",
            "package_fingerprint_before", "package_fingerprint_after",
            "prior_ledger_fingerprint_before", "prior_ledger_fingerprint_after",
            "attempted_counts", "committed_counts"],
        "active_work_order_obligation_map": {
            "bytes_only": ["SRC_BYTES_ONLY"],
            "hash_only": ["SRC_HASH_ONLY"],
            "bytes_plus_recomputed_hash": ["SRC_BYTES_REHASHED"],
            "zero_bytes_hash": ["SRC_ZERO_BYTES_HASH",
                                  "FORMAL_ARTIFACT_ZERO_PRECONDITION"],
            "wire": ["WIRE_GATE_STALE"],
            "semantic": ["SEMANTIC_GATE_FOREIGN"],
            "package": ["PACKAGE_GATE_FOREIGN"],
            "stale_foreign_candidate": ["CANDIDATE_STALE",
                                         "CANDIDATE_FOREIGN"],
            "stale_foreign_t0": ["T0_STALE", "T0_FOREIGN"],
            "stale_foreign_axis": ["AXIS_STALE", "AXIS_FOREIGN"],
            "stale_foreign_child": ["CHILD_STALE", "CHILD_FOREIGN"],
            "stale_foreign_feedback": ["FEEDBACK_STALE",
                                        "FEEDBACK_FOREIGN"],
            "stale_foreign_parent": ["PARENT_STALE", "PARENT_FOREIGN"],
            "stale_foreign_g3": ["G3_STALE", "G3_FOREIGN"],
            "duplicate_invocation": ["ACTUAL_DUPLICATE_INVOCATION"],
            "corrupt_serialization": [
                "FORMAL_ARTIFACT_DESERIALIZE_PRECONDITION",
                "FORMAL_ARTIFACT_ZERO_PRECONDITION",
                "FORMAL_ARTIFACT_WRONG_TYPE_PRECONDITION",
                "FORMAL_ARTIFACT_FOREIGN_PACKAGE_PRECONDITION"],
            "source_edit_without_rebuild": ["SOURCE_EDIT_NO_REBUILD"],
            "fail_atomic_preconditions": [
                "SRC_BYTES_ONLY", "SRC_HASH_ONLY", "SRC_BYTES_REHASHED",
                "SRC_ZERO_BYTES_HASH", "SOURCE_EDIT_NO_REBUILD",
                "WIRE_GATE_STALE", "SEMANTIC_GATE_FOREIGN",
                "PACKAGE_GATE_FOREIGN", "CANDIDATE_STALE",
                "CANDIDATE_FOREIGN", "T0_STALE", "T0_FOREIGN",
                "AXIS_STALE", "AXIS_FOREIGN", "CHILD_STALE",
                "CHILD_FOREIGN", "FEEDBACK_STALE", "FEEDBACK_FOREIGN",
                "PARENT_STALE", "PARENT_FOREIGN", "G3_STALE",
                "G3_FOREIGN", "ACTUAL_FOREIGN_SCENARIO",
                "ACTUAL_FORMAL_GATE_REJECTION",
                "ACTUAL_DUPLICATE_INVOCATION",
                "FORMAL_ARTIFACT_HASH_PRECONDITION",
                "FORMAL_ARTIFACT_DESERIALIZE_PRECONDITION",
                "FORMAL_ARTIFACT_ZERO_PRECONDITION",
                "FORMAL_ARTIFACT_WRONG_TYPE_PRECONDITION",
                "FORMAL_ARTIFACT_FOREIGN_PACKAGE_PRECONDITION",
                "CANDIDATE_RECEIPT_PRECONDITION"],
            "fail_atomic_attempted_prefix": [
                "FAULT_E0", "FAULT_GI1A", "FAULT_E1", "FAULT_E2",
                "FAULT_UP2", "ACTUAL_COUPLING_DIAGNOSTIC_MUTATION"],
            "output_postconditions_no_publication": [
                "SERIALIZED_RESULT_POSTCONDITION",
                "STABLE_PROJECTION_POSTCONDITION"],
            "publication_no_overwrite": [
                "PREEXISTING_OWNED_TARGETS",
                "PREEXISTING_EXTERNAL_SYMLINK"],
        },
    }
    all_case_ids = {row["id"] for row in ACTIVE_CASES}
    old_refs = {target for site in sites
                for target in site["successor_obligations"]}
    work_refs = {target for targets in
                 value["active_work_order_obligation_map"].values()
                 for target in targets}
    missing = sorted((old_refs | work_refs) - all_case_ids)
    if missing:
        raise RuntimeError(f"coverage map has dangling successor case ids: {missing}")
    prior = json.loads(ATTEMPT7_COVERAGE.read_text(encoding="utf-8"))
    prior9c = json.loads(ATTEMPT9C_COVERAGE.read_text(encoding="utf-8"))
    if prior.get("schema") != "vnext-t2-independent-negative-coverage-map-r2":
        raise RuntimeError("attempt7 coverage-map source is not frozen r2")
    prior_sites = prior["successor_assertion_sites"]
    current_sites = value["successor_assertion_sites"]
    site_contract_fields = (
        "id", "macro_name", "source_text", "source_text_sha256",
        "runtime_multiplicity", "expected_phase_hits")
    normalized_prior_sites = [
        {field: row[field] for field in site_contract_fields}
        for row in prior_sites]
    normalized_current_sites = [
        {field: row[field] for field in site_contract_fields}
        for row in current_sites]
    prior_cases = {row["id"]: row for row in prior["successor_cases"]}
    current_cases = {row["id"]: row for row in value["successor_cases"]}
    if normalized_current_sites != normalized_prior_sites:
        raise RuntimeError("attempt11 assertion ID/source/phase contract differs from attempt7")
    if current_cases != prior_cases:
        raise RuntimeError("attempt11 semantic case set/contract differs from attempt7")
    if value["runtime_execution_plan"] != prior["runtime_execution_plan"]:
        raise RuntimeError("attempt11 runtime case/phase plan differs from attempt7")
    current_hit_plan = value["successor_assertion_runtime_hit_plan"]
    prior_hit_plan = prior["successor_assertion_runtime_hit_plan"]
    current_hit_plan_contract = json.loads(json.dumps(current_hit_plan))
    prior_hit_plan_contract = json.loads(json.dumps(prior_hit_plan))
    for contract in (current_hit_plan_contract, prior_hit_plan_contract):
        contract.pop("schema", None)
        contract.pop("authority_case_hit_plan", None)
        contract["old_focused_suite_mapping"].pop("status", None)
        contract["projection24_mapping"].pop("status", None)
    if current_hit_plan_contract != prior_hit_plan_contract:
        raise RuntimeError("attempt11 site/phase hit plan differs from attempt7")
    prior9c_sites = prior9c["successor_assertion_sites"]
    normalized_prior9c_sites = [
        {field: row[field] for field in site_contract_fields}
        for row in prior9c_sites]
    if normalized_current_sites != normalized_prior9c_sites or             current_cases != {row["id"]: row for row in prior9c["successor_cases"]} or             value["runtime_execution_plan"] != prior9c["runtime_execution_plan"]:
        raise RuntimeError("attempt11 case/site/runtime semantics differ from attempt9c")
    old_by_id = {row["id"]: row for row in prior9c_sites
                 if row["path"].endswith("actual_formal_negative_driver_r3.jl")}
    new_by_id = {row["id"]: row for row in current_sites
                 if row["path"] == ACTUAL_DRIVER.relative_to(ROOT).as_posix()}
    if set(old_by_id) != set(new_by_id) or len(old_by_id) != 175:
        raise RuntimeError("attempt11 driver-site relocation inventory differs")
    relocation_ledger = []
    for site_id in sorted(old_by_id):
        old_row, new_row = old_by_id[site_id], new_by_id[site_id]
        if old_row["source_text_sha256"] != new_row["source_text_sha256"] or                 old_row["runtime_multiplicity"] != new_row["runtime_multiplicity"] or                 old_row["expected_phase_hits"] != new_row["expected_phase_hits"]:
            raise RuntimeError(f"attempt11 site semantic drift: {site_id}")
        relocation_ledger.append({
            "id": site_id,
            "old_path": old_row["path"], "old_line": old_row["line"],
            "new_path": new_row["path"], "new_line": new_row["line"],
            "source_text_sha256": new_row["source_text_sha256"],
            "runtime_multiplicity": new_row["runtime_multiplicity"],
            "expected_phase_hits": new_row["expected_phase_hits"],
        })
    value["attempt9c_relocation_ledger"] = relocation_ledger
    value["attempt9c_relocation_summary"] = {
        "schema": "vnext-t2-source-site-relocation-ledger-r1",
        "old_driver_path": "test/GenomeV5/Integration/VNextT2FormalIndependentR1/actual_formal_negative_driver_r3.jl",
        "new_driver_path": ACTUAL_DRIVER.relative_to(ROOT).as_posix(),
        "entry_count": len(relocation_ledger),
        "all_source_text_and_phase_hit_contracts_equal": True,
        "formal_t2_accepted": False,
    }
    OUT.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n",
                   encoding="utf-8", newline="\n")
    print(json.dumps({
        "status": "pass", "output": str(OUT),
        "old_assertion_sites": len(sites),
        "old_runtime_hits": value["old_expected_runtime_hit_count"],
        "versioned_product_repair_assertion_sites":
            projection_regression["assertion_site_count"],
        "successor_assertion_sites": value["successor_assertion_site_count"],
        "successor_runtime_hits":
            value["successor_expected_runtime_hit_count"],
        "successor_cases": len(ACTIVE_CASES),
        "attempt7_and_attempt9c_exact_case_site_runtime_plan_equality": True,
        "authority_case_plan": {"case_count": 9, "source_sites": 175, "nonzero_sites": 75, "hits": 118},
        "relocation_entries": len(relocation_ledger),
        "output_sha256": sha256_bytes(OUT.read_bytes()),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
