"""Read-only provenance audit for PF current channel names and stated turn scaling.

This audit records source-visible names and formulas.  It deliberately does not
turn them into an EFM-segment mapping or assert sign, turns, per-turn, or unit
semantics.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path
import re
import struct
from typing import Any


REPO = Path(__file__).resolve().parents[2]
PF_ROOT = REPO / "benchmarks/reference_source_fields_v1/shot30421_pf_geometry_r1/acquisition_r1"
EVIDENCE = REPO / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/pf_geometry_source_r1_20260922"
LEVEL1_GEOMETRY = REPO / "benchmarks/reference_source_fields_v1/shot30421_coil_geometry_r1"
YAML = EVIDENCE / "source_evidence/mast_ab435c799d892956fb042d55391f7d1be0c950e6.yml"
SOURCE_RECEIPT = EVIDENCE / "source_evidence/receipt.json"
NATIVE_ADAPTER = REPO / "benchmarks/reference_source_fields_v1/native_axisymmetric_adapter.py"
NATIVE_PROTOCOL = REPO / "benchmarks/reference_source_fields_v1/native_axisymmetric_protocol_v2.json"

EXPECTED_HASHES = {
    PF_ROOT / "acquisition.json": "a690debff6ecea5bf6d885e4d2f325f43ea21fdac613bf92a94064ff1798f2e8",
    PF_ROOT / "selection.json": "c6c9c6381de8365b80a6af75948876033d9df4486b58332eef54fa0c7c199ba6",
    YAML: "0d7ec0542621730e2dc6a3708d6ab10010514cc9a05677590961aa23c2f8873a",
    SOURCE_RECEIPT: "c7b1422083bac649120dacd0d07e1dadd45b8e86e8855cbba03a3259495b8ffe",
    NATIVE_ADAPTER: "b29c4b80b5fd83d2abd476d5f5d7d68479dfa30c11eac755e44eab261b887ebd",
    NATIVE_PROTOCOL: "9c68cd4f171983dc13df48dbcfe64e84373de1bbe20fd5135286a604ce36d4df",
    LEVEL1_GEOMETRY / "acquisition.json": "8173e2a0a418c28cafc3302ebe578012d0daa3e43e5bf635328f7fa5d5ef8816",
    LEVEL1_GEOMETRY / "fields/efm__fcoil_turns/field_metadata.json": "1b65727476fdf061b13c78d91a9688ab30bc9bddef55643af70e4109deaf4d08",
    LEVEL1_GEOMETRY / "fields/efm__fcoil_xmult/field_metadata.json": "be441728da2bb9e2ffad09de03e648c39206453c6b5388ca5c8c0302ddfaf3ae",
}

EXPECTED_ACTIVE_CHANNELS = [
    "SOL", "P2IL FEED", "P2IU FEED", "P2OL FEED", "P2OU FEED",
    "P3L FEED", "P3U FEED", "P4L FEED", "P4U FEED", "P5L FEED",
    "P5U FEED", "P6L", "P6U",
]
EXPECTED_YAML_SCALES = [None, 12, 12, 8, 8, 8, 8, 23, 23, 23, 23, None, None]
EXPECTED_NATIVE_PATHS = [
    "amc/p2u_current", "amc/p2l_current", "amc/p3u_current", "amc/p3l_current",
    "amc/p4u_current", "amc/p4l_current", "amc/p5u_current", "amc/p5l_current",
    "amc/p6u_current", "amc/p6l_current",
]


class AuditError(AssertionError):
    pass


class Audit:
    def __init__(self) -> None:
        self.assertions = 0
        self.negatives: list[str] = []

    def equal(self, actual: Any, expected: Any, detail: str) -> None:
        self.assertions += 1
        if actual != expected:
            raise AuditError(f"{detail}: {actual!r} != {expected!r}")

    def check(self, condition: bool, detail: str) -> None:
        self.assertions += 1
        if not condition:
            raise AuditError(detail)

    def negative(self, name: str, callback) -> None:
        try:
            callback()
        except AuditError:
            self.assertions += 1
            self.negatives.append(name)
            return
        raise AuditError(f"negative did not fail: {name}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True,
                       separators=(",", ":"), allow_nan=False) + "\n").encode("utf-8")


def find_assignment(source: str, name: str) -> Any:
    tree = ast.parse(source)
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == name
                                                for target in node.targets):
            return ast.literal_eval(node.value)
    raise AuditError(f"assignment absent: {name}")


def load_float32(path: Path) -> list[float]:
    raw = path.read_bytes()
    if len(raw) % 4:
        raise AuditError(f"unaligned float32: {path}")
    return [item[0] for item in struct.iter_unpack("<f", raw)]


def yaml_current_mapping(text: str) -> tuple[list[str], list[int | None], str]:
    marker = "      coil_current:\n"
    start = text.index(marker)
    end = text.index("        dimensions:\n", start)
    block = text[start:end]
    pattern = re.compile(
        r'^\s*-\s+"(AMC_[^"]+ CURRENT)"(?:[ \t]*:[ \t]*\{[ \t]*scale:[ \t]*(\d+)[ \t]*\})?'
        r'[ \t]*(?:#.*)?$'
    )
    matches = [match.groups() for line in block.splitlines() if (match := pattern.match(line))]
    names = [name.removeprefix("AMC_").removesuffix(" CURRENT") for name, _ in matches]
    scales = [int(scale) if scale else None for _, scale in matches]
    formula = ("Feed current is in kA/turn. Each channel needs to be scaled by the "
               "number of turns in the coil to get the actual current in A.")
    if formula not in block:
        raise AuditError("source-visible scaling comment absent")
    return names, scales, formula


def run(report_path: Path) -> dict[str, Any]:
    audit = Audit()
    identities = []
    for path, expected in EXPECTED_HASHES.items():
        audit.check(path.is_file(), f"missing input: {path}")
        actual = sha256(path)
        audit.equal(actual, expected, f"input hash {path}")
        identities.append({"path": str(path), "bytes": path.stat().st_size, "sha256": actual})

    acquisition = json.loads((PF_ROOT / "acquisition.json").read_text(encoding="utf-8"))
    by_path = {record["path"]: record for record in acquisition["arrays"]}
    active_record = by_path["pf_active/current_channel"]
    active_document = json.loads((PF_ROOT / active_record["assembled_path"]).read_text(encoding="utf-8"))
    active_channels = active_document["values"]
    audit.equal(active_channels, EXPECTED_ACTIVE_CHANNELS, "active channel order")
    audit.equal(active_record["assembled_sha256"], sha256(PF_ROOT / active_record["assembled_path"]),
                "active channel assembled hash")

    current_record = by_path["pf_active/coil_current"]
    audit.equal(current_record["shape"], [13, 15305], "active current shape")
    audit.equal(current_record["dimensions"], ["current_channel", "time"], "active current dimensions")
    audit.equal(current_record["units"], "A", "active current recorded unit")
    audit.equal(current_record["finite_count"], 198965, "active current finite count")
    audit.equal(current_record["finite_count"], current_record["total_count"], "active current finite coverage")

    yaml_text = YAML.read_text(encoding="utf-8")
    yaml_channels, yaml_scales, yaml_formula = yaml_current_mapping(yaml_text)
    audit.equal(yaml_channels, active_channels, "YAML-to-Level2 named channel order")
    audit.equal(yaml_scales, EXPECTED_YAML_SCALES, "source-visible scale sequence")
    source_receipt = json.loads(SOURCE_RECEIPT.read_text(encoding="utf-8"))
    audit.equal(source_receipt["interpretation"]["mapping_scope"],
                "pinned ingestion mapping research input only", "source mapping scope")
    audit.equal(source_receipt["interpretation"]["mapping_does_not_establish_circ_index_or_turn_sign_or_independent_validation"],
                True, "source interpretation lock")
    yaml_source = next(item for item in source_receipt["sources"] if item["path"].endswith(".yml"))
    audit.equal(yaml_source["sha256"], EXPECTED_HASHES[YAML], "YAML receipt binding")

    native_source = NATIVE_ADAPTER.read_text(encoding="utf-8")
    native_paths = list(find_assignment(native_source, "PF_CURRENT_PATHS"))
    audit.equal(native_paths, EXPECTED_NATIVE_PATHS, "native AMC current paths")
    audit.check('float(arrays[path][amc_index]) * 1000.0' in native_source,
                "native x1000 formula absent")
    native_protocol = json.loads(NATIVE_PROTOCOL.read_text(encoding="utf-8"))
    canonical = native_protocol["canonical_contract"]
    audit.equal(canonical["amc_current_scale_to_A_turn"], 1000.0, "native scale")
    audit.equal(canonical["amc_current_unit"], "kA * turn", "native source unit")
    for path in native_paths:
        audit.equal(native_protocol["array_contracts"][path]["units"], "kA * turn",
                    f"native unit {path}")

    turns_metadata_path = LEVEL1_GEOMETRY / "fields/efm__fcoil_turns/field_metadata.json"
    xmult_metadata_path = LEVEL1_GEOMETRY / "fields/efm__fcoil_xmult/field_metadata.json"
    turns_metadata = json.loads(turns_metadata_path.read_text(encoding="utf-8"))
    xmult_metadata = json.loads(xmult_metadata_path.read_text(encoding="utf-8"))
    turns_path = LEVEL1_GEOMETRY / "fields/efm__fcoil_turns/assembled.raw"
    xmult_path = LEVEL1_GEOMETRY / "fields/efm__fcoil_xmult/assembled.raw"
    audit.equal(sha256(turns_path), turns_metadata["assembled_raw_sha256"], "turns bytes binding")
    audit.equal(sha256(xmult_path), xmult_metadata["assembled_raw_sha256"], "xmult bytes binding")
    turns = load_float32(turns_path)
    xmult = load_float32(xmult_path)
    audit.equal(len(turns), 938, "turns count")
    audit.equal(set(turns), {1.0}, "turns observed values")
    audit.equal(len(xmult), 938, "xmult count")
    audit.equal(len(set(xmult)), 21, "xmult unique count")
    audit.equal(turns_metadata["attributes"]["quality"], "Not Checked", "turns quality")
    audit.equal(xmult_metadata["attributes"]["quality"], "Not Checked", "xmult quality")
    audit.equal(turns_metadata["attributes"]["units"], "deg", "turns raw metadata unit")
    audit.equal(xmult_metadata["attributes"]["units"], "deg", "xmult raw metadata unit")

    forged_scales = list(yaml_scales)
    forged_scales[1] = 13
    audit.negative("turn_scale_forgery", lambda: audit.equal(forged_scales, EXPECTED_YAML_SCALES,
                                                              "forged turn scale"))
    swapped_channels = list(active_channels)
    swapped_channels[1], swapped_channels[2] = swapped_channels[2], swapped_channels[1]
    audit.negative("named_channel_order_forgery", lambda: audit.equal(swapped_channels, yaml_channels,
                                                                       "forged channel order"))
    audit.negative("active_current_unit_forgery", lambda: audit.equal("A * turn", current_record["units"],
                                                                       "forged Level2 unit"))

    passive_channel_records = sorted(path for path in by_path if path.startswith("pf_passive/")
                                     and path.endswith("_current_channel"))
    passive_names = {}
    for path in passive_channel_records:
        record = by_path[path]
        document = json.loads((PF_ROOT / record["assembled_path"]).read_text(encoding="utf-8"))
        audit.equal(record["assembled_sha256"], sha256(PF_ROOT / record["assembled_path"]),
                    f"passive channel hash {path}")
        passive_names[path] = document["values"]

    report = {
        "schema": "fusionconceptai:pf-current-provenance-independent-audit-v1",
        "status": "source_visible_names_and_formulas_recorded",
        "assertion_count": audit.assertions,
        "negative_controls": audit.negatives,
        "input_identities": identities,
        "level2_active_current": {
            "channels": active_channels,
            "shape": current_record["shape"],
            "dimensions": current_record["dimensions"],
            "recorded_unit": current_record["units"],
            "minimum": current_record["minimum"],
            "maximum": current_record["maximum"],
            "sign_semantics": "unknown",
        },
        "level2_passive_named_channels": passive_names,
        "pinned_ingestion_mapping": {
            "source_url": yaml_source["url"],
            "channels_match_level2_order": True,
            "scale_sequence": yaml_scales,
            "source_visible_formula_comment": yaml_formula,
            "evidence_role": "research_input_only",
        },
        "existing_native_adapter": {
            "paths": native_paths,
            "source_recorded_unit": canonical["amc_current_unit"],
            "implemented_conversion": "amc_sample * 1000.0",
            "output_field": "internal_pf_currents_a_turn",
            "level2_13_to_native_10_mapping": "not_established",
            "turn_scale_sequence_consumed": False,
        },
        "level1_segment_arrays": {
            "turns": {
                "count": len(turns), "unique_values": sorted(set(turns)),
                "raw_metadata_units": turns_metadata["attributes"]["units"],
                "quality": turns_metadata["attributes"]["quality"], "sha256": sha256(turns_path),
            },
            "xmult": {
                "count": len(xmult), "unique_count": len(set(xmult)),
                "minimum": min(xmult), "maximum": max(xmult), "sum": sum(xmult),
                "raw_metadata_units": xmult_metadata["attributes"]["units"],
                "quality": xmult_metadata["attributes"]["quality"], "sha256": sha256(xmult_path),
            },
        },
        "scope": {
            "named_channel_provenance": "observed_and_hash_bound",
            "turn_formula": "source_visible_comment_only",
            "circ_or_segment_mapping": "not_accepted",
            "turns_semantics": "unknown",
            "current_sign_semantics": "unknown",
            "current_per_turn_semantics": "unknown",
            "unit_consistency_across_packages": "not_established",
            "physical_validation": False,
            "free_boundary_ready": False,
        },
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_bytes(canonical_bytes(report))
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    report = run(args.report.resolve())
    print(json.dumps({"status": report["status"], "assertions": report["assertion_count"],
                      "negative_controls": len(report["negative_controls"]),
                      "report": str(args.report.resolve()), "report_sha256": sha256(args.report.resolve())},
                     sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
