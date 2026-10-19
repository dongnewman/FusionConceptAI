#!/usr/bin/env python3
"""Build the R3 replay protocol from the frozen R2 closure without changing R2 evidence."""
from __future__ import annotations

import argparse
import copy
import datetime as dt
import difflib
import hashlib
import json
import pathlib
import re
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parents[3]
BASE = pathlib.Path(__file__).resolve().parent
R2_PROTOCOL_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r2.json"
R2_PROTOCOL_PATH = ROOT / pathlib.Path(*pathlib.PurePosixPath(R2_PROTOCOL_REL).parts)
R2_PROTOCOL_SHA256 = "e6a6917bc720b7f61a48707aea60d5377b67c3c61c30c817eeacfb1dfa9b0659"
R2_TEST_SHA256 = "8bb1937ce0def915a94e2f0c45f95b3980a34b59ad5f5980af3d3baad7b43f59"
R2_SOURCE_SNAPSHOT_DIR = ROOT / "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r2_20260926_r1/independent_static_r2_source_snapshot_r1"
R2_SOURCE_SNAPSHOT_MANIFEST = R2_SOURCE_SNAPSHOT_DIR / "added_sources_manifest.json"
R2_SOURCE_SNAPSHOT_MANIFEST_SHA256 = "4c1b395e316c716287f0fb0f1f96c256aad6efd524eef01edc6447fe015fea6e"
R2_TEST_SNAPSHOT = R2_SOURCE_SNAPSHOT_DIR / "test_independent_static_v21_r2_e6_executed.py"
R2_PROTOCOL_SNAPSHOT = R2_SOURCE_SNAPSHOT_DIR / "replay_protocol_v21_r2_e6_frozen.json"
R2_TEST_RECEIPT = ROOT / "runs/UP2ClosureReplayOnlyV21/input_closure_r2_tests_20260926_r2/receipt_manifest.json"
R2_TEST_RECEIPT_SHA256 = "1894ad3ec64eb0bf3ca0fa935a3b8a32d2a4037f35465d3aac7aed2a9aea3ddd"
R2_RUNTIME_RECEIPT_REL = "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r2_20260926_r1/external_exit_receipt.json"
R2_RUNTIME_RECEIPT_SHA256 = "e2681ee8f47419d190b80a5bfa6315198b9c32eb70cfa105f7c0dccd2a398a82"
R2_RUNTIME_RECEIPT_BYTES = 1958
ARCHIVE_PATH = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "precleanup_docs_runs_tmp.zip"
ARCHIVE_SHA256 = "c84743bc55dc749bbcc43e936c278027ad9bce9b437c09e176be587f75ff2bb7"
ORIGINAL_CONTROLLER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21.py"
ORIGINAL_CONTROLLER_SHA256 = "8fdbf6b38e53ac3ab4ea65310587587707a643f16e76d2623b23601239f05579"
ORIGINAL_ENTRYPOINT_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_staged_v21.jl"
ORIGINAL_ENTRYPOINT_SHA256 = "ca2f0c6b6d4db4b1a3b2d9051f344af84cf0f9de3ff2f7bc479a644c8ae3dfa7"
ORIGINAL_BUILDER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/build_protocol_v21.py"
ORIGINAL_BUILDER_SHA256 = "d844efd26530bc4e240b2902baf53689b591aa7c862261816f1b751b018ca8e9"
ORIGINAL_PROTOCOL_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21.json"
ORIGINAL_PROTOCOL_SHA256 = "113fa02eb54d5b2aa870f2b9c07024def18427fa353c485f30568e50125c4b2e"
R2_BUILDER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/build_protocol_v21_r2.py"
R2_BUILDER_SHA256 = "ba42c715ec566982fa62e3841c46fdfaea31ea559735473cc1314c0df8cf5271"
R2_CONTROLLER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r2.py"
R2_CONTROLLER_SHA256 = "666c255aa2904eb55e90083b1ab59c32aed4fe4b5d005ef45afcc118905a3457"
R2_ENTRYPOINT_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_staged_v21_r2.jl"
R2_ENTRYPOINT_SHA256 = "cb70e7e508510a251379509b8cd07a5d7afd580226409c06f4cab22618ab398e"
R2_SPEC_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/controller_overlay_spec_v21_r2.json"
R2_SPEC_SHA256 = "369202ad82fa5669a5a1749117214f36bee9f01f953109ec53d6d9da39d3a345"
R3_BUILDER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/build_protocol_v21_r3.py"
R3_CONTROLLER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r3.py"
R3_ENTRYPOINT_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_staged_v21_r3.jl"
R3_SPEC_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/controller_overlay_spec_v21_r3.json"
R3_TEST_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/test_independent_static_v21.py"
R3_PROTOCOL_PATH = BASE / "replay_protocol_v21_r3.json"
R3_OUTPUT_ROOT = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "up2_replay_v21_r3"
R3_STAGING_ROOT = R3_OUTPUT_ROOT / "archive_mirror"
R3_OUTPUT_LEAF = R3_OUTPUT_ROOT / "runtime_replay_r21_r3"
R2_OUTPUT_ROOT = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "up2_replay_v21_r2"

PROCESS_TREE_NEGATIVES = [
    "inject descendant enumeration AccessDenied and require an incomplete sample with no RSS total returned",
    "inject descendant memory_info AccessDenied after a root sample and require the partial bytes be diagnostic only",
    "inject incomplete monitor status in run_stage and require resource_interruption/124 with consumer blocked",
    "inject wait_procs exceptions during terminate and kill waits and require candidates retained and termination_confirmed false",
    "inject missing or duplicate root identities and require the complete RSS sample be rejected",
    "inject root/descendant PID reuse and require fail-closed without signaling the recycled process",
    "make the leader exit with a live descendant and require interruption/124 with consumer blocked",
    "inject descendant lookup AccessDenied and terminate/kill errors; unknown residuals must remain unconfirmed",
    "confirm Popen exit after a complete root sample and require no post-exit RSS lookup plus a complete identity and PPID descendant audit",
    "make Popen exit before any complete root sample and require process-tree observation failure/124",
    "inject an unobserved child in the final PPID snapshot and require interruption/124, identity pinning, and no consumer launch",
    "inject PPID snapshot failure or a root PID still present/reused after confirmed exit and require fail-closed status",
    "inject unconfirmed bounded cleanup with zero measured overrun and require cleanup_unconfirmed/124 rather than aggregate_cleanup_overrun",
    "accept and ignore only the exact Windows PID 0/PPID 0 sentinel; reject PID 0 with nonzero PPID and all other invalid process-table identities",
]
R2_MONITOR_SUMMARY = (
    "Only an exact pinned Popen leader confirmed exited after a complete RSS sample may enter the V21 "
    "NoSuchProcess race branch; every previously observed descendant and current PPID table is still audited."
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def source_row(relative: str) -> dict[str, Any]:
    path = ROOT / pathlib.Path(*pathlib.PurePosixPath(relative).parts)
    if not path.is_file() or not path.resolve().is_relative_to(ROOT.resolve()):
        raise FileNotFoundError(f"R3 owned source is missing or escapes repository: {relative}")
    return {"path": relative, "bytes": path.stat().st_size, "sha256": sha256_file(path)}


def verify_exact_file(relative: str, expected_sha: str, expected_bytes: int | None = None) -> pathlib.Path:
    path = ROOT / pathlib.Path(*pathlib.PurePosixPath(relative).parts)
    if not path.is_file() or sha256_file(path) != expected_sha or \
            (expected_bytes is not None and path.stat().st_size != expected_bytes):
        raise ValueError(f"R3 frozen input source differs: {relative}")
    return path


def verify_r2_sidecars(r2: dict[str, Any]) -> dict[str, Any]:
    if not R2_SOURCE_SNAPSHOT_MANIFEST.is_file() or \
            sha256_file(R2_SOURCE_SNAPSHOT_MANIFEST) != R2_SOURCE_SNAPSHOT_MANIFEST_SHA256:
        raise ValueError("R2 source/protocol sidecar manifest is missing or changed")
    manifest = json.loads(R2_SOURCE_SNAPSHOT_MANIFEST.read_bytes())
    if manifest.get("purpose") != "Preserve exact R2 independent test and protocol bytes before R3 successor test edits; R2 failed runtime evidence and existing manifest are unchanged.":
        raise ValueError("R2 sidecar purpose changed")
    rows = manifest.get("files")
    expected = {
        "test_independent_static_v21_r2_e6_executed.py": (R2_TEST_SHA256, 19706),
        "replay_protocol_v21_r2_e6_frozen.json": (R2_PROTOCOL_SHA256, 973773),
    }
    if not isinstance(rows, list) or len(rows) != 2:
        raise ValueError("R2 sidecar must retain exactly the test and protocol snapshot rows")
    seen: set[str] = set()
    for row in rows:
        snapshot_path = pathlib.Path(row.get("snapshot_path", ""))
        name = snapshot_path.name
        if name not in expected or name in seen:
            raise ValueError(f"R2 sidecar snapshot path is unexpected or duplicated: {name}")
        expected_sha, expected_bytes = expected[name]
        if row.get("sha256") != expected_sha or row.get("bytes") != expected_bytes or \
                not snapshot_path.is_file() or snapshot_path.stat().st_size != expected_bytes or \
                sha256_file(snapshot_path) != expected_sha:
            raise ValueError(f"R2 exact source/protocol snapshot differs: {snapshot_path}")
        seen.add(name)
    if seen != set(expected):
        raise ValueError("R2 sidecar does not preserve both the executed test and protocol")
    if sha256_file(R2_TEST_RECEIPT) != R2_TEST_RECEIPT_SHA256:
        raise ValueError("R2 completed static-test receipt changed")
    r2_pins = r2.get("owned_source_files_by_path")
    if not isinstance(r2_pins, dict) or r2_pins.get(R3_TEST_REL) != R2_TEST_SHA256:
        raise ValueError("R2 protocol no longer pins the exact pre-R3 static test")
    return {
        "manifest_path": R2_SOURCE_SNAPSHOT_MANIFEST.relative_to(ROOT).as_posix(),
        "manifest_sha256": R2_SOURCE_SNAPSHOT_MANIFEST_SHA256,
        "test_snapshot_path": R2_TEST_SNAPSHOT.relative_to(ROOT).as_posix(),
        "test_sha256": R2_TEST_SHA256,
        "protocol_snapshot_path": R2_PROTOCOL_SNAPSHOT.relative_to(ROOT).as_posix(),
        "protocol_sha256": R2_PROTOCOL_SHA256,
        "static_receipt_path": R2_TEST_RECEIPT.relative_to(ROOT).as_posix(),
        "static_receipt_sha256": R2_TEST_RECEIPT_SHA256,
    }


def verify_r2_mirror(r2: dict[str, Any]) -> dict[str, Any]:
    source = r2.get("archived_input_source")
    if not isinstance(source, dict) or source.get("archive_sha256") != ARCHIVE_SHA256:
        raise ValueError("R2 parent protocol lacks the exact frozen archive identity")
    staging = pathlib.Path(str(source.get("staging_root", ""))).resolve()
    expected_root = (R2_OUTPUT_ROOT / "archive_mirror").resolve()
    if staging != expected_root or not staging.is_dir():
        raise FileNotFoundError("preserved R2 mirror is missing or has an unexpected root")
    rows = source.get("entries")
    if not isinstance(rows, list) or len(rows) != 613 or len(source.get("directory_prefixes", [])) != 31 or \
            len(source.get("referenced_paths", [])) != 645:
        raise ValueError("R2 parent closure dimensions differ from 613/31/645")
    expected = {row["logical_path"]: (row["bytes"], row["sha256"]) for row in rows}
    actual: dict[str, tuple[int, str]] = {}
    for path in staging.rglob("*"):
        if path.is_symlink():
            raise ValueError(f"R2 mirror contains a symlink: {path}")
        if path.is_file():
            logical = path.relative_to(staging).as_posix()
            actual[logical] = (path.stat().st_size, sha256_file(path))
    if actual != expected or sum(size for size, _ in actual.values()) != 31564478:
        raise ValueError("R2 mirror no longer equals the exact 613-file / 31,564,478-byte closure")
    r2_leaf = R2_OUTPUT_ROOT / "runtime_replay_r21_r2"
    if r2_leaf.exists():
        raise FileExistsError("preserve any existing R2 runtime leaf; R3 preparation will not use or replace it")
    return {"root": str(staging), "file_count": len(actual), "bytes": sum(size for size, _ in actual.values()),
            "directory_prefix_count": 31, "runtime_leaf_absent": True}


def apply_overlay(original: bytes, spec: dict[str, Any]) -> bytes:
    replacements = {row["old_line"]: row["new_line"] for row in spec["replacements"]}
    if len(replacements) != 7 or spec.get("replacement_count") != 7:
        raise ValueError("R3 overlay must retain six path bindings plus one guard-source correction")
    counts = {line: 0 for line in replacements}
    output: list[str] = []
    for line in original.decode("utf-8").splitlines(keepends=True):
        body = line.rstrip("\r\n")
        if body in replacements:
            counts[body] += 1
            output.append(replacements[body] + line[len(body):])
        else:
            output.append(line)
    if any(count != 1 for count in counts.values()):
        raise ValueError(f"R3 overlay old-line cardinality changed: {counts}")
    return "".join(output).encode("utf-8")


def verify_r3_sources(r2: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    spec_path = ROOT / pathlib.Path(*pathlib.PurePosixPath(R3_SPEC_REL).parts)
    spec = json.loads(spec_path.read_bytes())
    if spec.get("schema") != "mms-v21-r3-controller-overlay-spec-v1" or \
            spec.get("original_controller_path") != ORIGINAL_CONTROLLER_REL or \
            spec.get("original_controller_sha256") != ORIGINAL_CONTROLLER_SHA256 or \
            spec.get("replacement_count") != 7 or len(spec.get("replacements", [])) != 7:
        raise ValueError("R3 controller overlay spec identity is invalid")
    original = verify_exact_file(ORIGINAL_CONTROLLER_REL, ORIGINAL_CONTROLLER_SHA256).read_bytes()
    transformed = apply_overlay(original, spec)
    r3_entry_path = ROOT / pathlib.Path(*pathlib.PurePosixPath(R3_ENTRYPOINT_REL).parts)
    r2_entry_path = ROOT / pathlib.Path(*pathlib.PurePosixPath(R2_ENTRYPOINT_REL).parts)
    r2_entry = verify_exact_file(R2_ENTRYPOINT_REL, R2_ENTRYPOINT_SHA256).read_bytes()
    old = b'const PROTOCOL = joinpath(@__DIR__, "replay_protocol_v21_r2.json")'
    new = b'const PROTOCOL = joinpath(@__DIR__, "replay_protocol_v21_r3.json")'
    if r2_entry.count(old) != 1 or r3_entry_path.read_bytes() != r2_entry.replace(old, new, 1):
        raise ValueError("R3 Julia entrypoint is not the exact one-literal R2 successor")

    r2_pins = r2.get("owned_source_files_by_path")
    for relative, sha in ((R2_BUILDER_REL, R2_BUILDER_SHA256), (R2_CONTROLLER_REL, R2_CONTROLLER_SHA256),
                          (R2_ENTRYPOINT_REL, R2_ENTRYPOINT_SHA256), (R2_SPEC_REL, R2_SPEC_SHA256),
                          (ORIGINAL_BUILDER_REL, ORIGINAL_BUILDER_SHA256),
                          (ORIGINAL_CONTROLLER_REL, ORIGINAL_CONTROLLER_SHA256),
                          (ORIGINAL_ENTRYPOINT_REL, ORIGINAL_ENTRYPOINT_SHA256),
                          (ORIGINAL_PROTOCOL_REL, ORIGINAL_PROTOCOL_SHA256)):
        if r2_pins.get(relative) != sha:
            raise ValueError(f"R2 protocol parent source pin differs: {relative}")
        verify_exact_file(relative, sha)

    source_rels = [
        R3_BUILDER_REL, R3_CONTROLLER_REL, R3_ENTRYPOINT_REL, R3_SPEC_REL, R3_TEST_REL,
        R2_PROTOCOL_REL, R2_BUILDER_REL, R2_CONTROLLER_REL, R2_ENTRYPOINT_REL, R2_SPEC_REL,
        ORIGINAL_BUILDER_REL, ORIGINAL_CONTROLLER_REL, ORIGINAL_ENTRYPOINT_REL, ORIGINAL_PROTOCOL_REL,
    ]
    source_rows = [source_row(path) for path in sorted(source_rels)]
    source_by_path = {row["path"]: row["sha256"] for row in source_rows}
    overlay_diff = "".join(difflib.unified_diff(
        original.decode("utf-8").splitlines(keepends=True), transformed.decode("utf-8").splitlines(keepends=True),
        fromfile="run_replay_staged_v21.py (frozen source)",
        tofile="run_replay_staged_v21_r3.py (in-memory seven-line overlay)",
    ))
    overlay_evidence = {
        "schema": "mms-v21-r3-controller-overlay-evidence-v1",
        "original_controller_path": ORIGINAL_CONTROLLER_REL,
        "original_controller_sha256_before": sha256_bytes(original),
        "original_controller_sha256_after": sha256_file(ROOT / pathlib.Path(*pathlib.PurePosixPath(ORIGINAL_CONTROLLER_REL).parts)),
        "transformed_source_sha256": sha256_bytes(transformed),
        "overlay_spec_path": R3_SPEC_REL,
        "overlay_spec_sha256": sha256_file(spec_path),
        "replacement_count": 7,
        "path_binding_replacement_count": 6,
        "guard_consumption_binding_correction": {
            "original_call": spec["replacements"][6]["old_line"],
            "corrected_call": spec["replacements"][6]["new_line"],
            "source_variable": "R3_TRANSFORMED_CONTROLLER_SOURCE",
            "source_value": "exact UTF-8 decoded transformed controller bytes compiled and executed by the R3 wrapper",
        },
        "replacements": copy.deepcopy(spec["replacements"]),
        "unified_diff": overlay_diff,
        "unified_diff_sha256": sha256_bytes(overlay_diff.encode("utf-8")),
        "scope": "Six exact complete-line R3 path bindings plus the preserved guard-source consumption correction; official V21 validation/control flow is otherwise unchanged.",
    }
    return {"owned_source_files": source_rows, "owned_source_files_by_path": source_by_path}, overlay_evidence


def build_protocol() -> tuple[dict[str, Any], dict[str, Any]]:
    if not R2_PROTOCOL_PATH.is_file() or sha256_file(R2_PROTOCOL_PATH) != R2_PROTOCOL_SHA256:
        raise ValueError("R2 parent protocol differs from its frozen SHA")
    r2_wire = R2_PROTOCOL_PATH.read_bytes()
    r2 = json.loads(r2_wire)
    if (r2.get("schema"), r2.get("version"), r2.get("classification"), r2.get("runtime_grant")) != (
            "mms-replay-only-continuation-protocol-v21", 21, "test_only_continuation", False):
        raise ValueError("R2 parent status or no-credit boundary changed")
    verify_exact_file(R2_RUNTIME_RECEIPT_REL, R2_RUNTIME_RECEIPT_SHA256, R2_RUNTIME_RECEIPT_BYTES)
    if not ARCHIVE_PATH.is_file() or sha256_file(ARCHIVE_PATH) != ARCHIVE_SHA256:
        raise ValueError("pinned cleanup archive is missing or differs")
    if R3_OUTPUT_ROOT.exists() or R3_STAGING_ROOT.exists() or R3_OUTPUT_LEAF.exists():
        raise FileExistsError("R3 preparation requires its external output/mirror roots absent")

    sidecar = verify_r2_sidecars(r2)
    mirror = verify_r2_mirror(r2)
    source_rows, overlay = verify_r3_sources(r2)
    r3 = copy.deepcopy(r2)
    coverage = r3.get("coverage_contract")
    if not isinstance(coverage, dict) or coverage.get("process_tree_resource_monitor_negative_controls") != R2_MONITOR_SUMMARY:
        raise ValueError("R2 process-tree monitor summary changed from the preserved source text")
    coverage["process_tree_resource_monitor_summary"] = R2_MONITOR_SUMMARY
    coverage["process_tree_resource_monitor_negative_controls"] = copy.deepcopy(PROCESS_TREE_NEGATIVES)
    coverage["child_argv"]["entrypoint"] = R3_ENTRYPOINT_REL
    coverage["child_argv"]["negative_control"] = (
        "R3 no-write static gate checks exact monitor negatives, transformed exit-race guard, and the preserved R2 mirror; "
        "V21 tests follow. The R3 pre-mirror gate validates all 89 V10 inputs before its new mirror is created."
    )
    coverage["output_leaf"] = str(R3_OUTPUT_LEAF.resolve())

    r3["controller"] = R3_CONTROLLER_REL
    r3["entrypoint"] = R3_ENTRYPOINT_REL
    r3["output_leaf"] = str(R3_OUTPUT_LEAF.resolve())
    r3["archived_input_source"]["staging_root"] = str(R3_STAGING_ROOT.resolve())
    r3["archived_input_source"]["closure_scope"] = (
        "The R2-pinned V10-complete 613-file archive map is retained byte-for-byte; R3 uses a new external mirror/output root. "
        "It does not replace or mutate the already materialized R2 mirror."
    )
    r3["context_builder_contract"]["entrypoint_path"] = R3_ENTRYPOINT_REL
    r3["context_builder_contract"]["entrypoint_sha256"] = source_rows["owned_source_files_by_path"][R3_ENTRYPOINT_REL]
    for mode in ("producer", "consumer"):
        command = r3["child_command_contract"][mode]
        hits = [index for index, value in enumerate(command) if value == R2_ENTRYPOINT_REL]
        if len(hits) != 1:
            raise ValueError(f"R2 {mode} command does not contain one exact entrypoint binding")
        command[hits[0]] = R3_ENTRYPOINT_REL
    producer_command = r3["child_command_contract"]["producer"]
    logical_source = pathlib.PurePosixPath(str(r3["saved_producer_tree"]["root"]))
    if logical_source.is_absolute() or logical_source.as_posix() != r3["saved_producer_tree"]["root"] or \
            logical_source.parts[:1] != ("docs",) or any(part in ("", ".", "..") for part in logical_source.parts) or \
            len(producer_command) != 10:
        raise ValueError("R2 producer command source-root binding is malformed")
    logical_source_path = pathlib.Path(*logical_source.parts)
    expected_r2_source = str((R2_OUTPUT_ROOT / "archive_mirror" / logical_source_path).resolve())
    expected_r3_source = str((R3_STAGING_ROOT / logical_source_path).resolve())
    if producer_command[6] != expected_r2_source:
        raise ValueError("R2 producer command source root differs from its exact pinned staging/tree inputs")
    producer_command[6] = expected_r3_source

    r3["controller_command_template"] = (
        f"{r3['runtime']['python_executable']} -B {R3_CONTROLLER_REL} --protocol "
        f"test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r3.json "
        f"--protocol-sha256 <protocol-sha256> --output {R3_OUTPUT_LEAF.resolve()} --root-serial-slot-granted"
    )
    r3["r2_preservation_snapshot"] = sidecar
    r3["r2_runtime_static_receipt"] = {
        "path": sidecar["static_receipt_path"], "sha256": sidecar["static_receipt_sha256"],
        "classification": "R2 targeted static suite 2/2 exit 0; no Julia/solver and no mirror writes",
    }
    r3["r2_mirror_preservation"] = mirror
    r3["r3_controller_overlay"] = overlay
    r3["r3_repair"] = {
        "schema": "mms-v21-r3-process-tree-negative-control-shape-repair-v1",
        "cause": "The pinned V21 controller strictly requires an exact 14-string negative-control list, but R2 inherited a one-string policy summary at that field.",
        "preserved_summary_field": "coverage_contract.process_tree_resource_monitor_summary",
        "preserved_summary_value": R2_MONITOR_SUMMARY,
        "strict_controller_validator_unchanged": True,
        "exact_controller_required_negatives": copy.deepcopy(PROCESS_TREE_NEGATIVES),
        "r2_mirror_preserved": True,
        "new_r3_external_root": str(R3_OUTPUT_ROOT.resolve()),
        "runtime_grant": False,
    }
    r3["r3_output_ownership"] = {
        "schema": "mms-v21-r3-external-raw-root-ownership-v1",
        "owner": "UP2ClosureReplayOnlyV21 R3 preflight repair",
        "raw_external_root": str(R3_OUTPUT_ROOT.resolve()),
        "archive_mirror_root": str(R3_STAGING_ROOT.resolve()),
        "runtime_output_leaf": str(R3_OUTPUT_LEAF.resolve()),
        "outside_repository_docs": True,
        "mirror_contents": "Only the exact 613 R2-pinned ZIP members; no broad extraction and no docs restoration.",
        "builder_creates_mirror_or_output": False,
        "pre_mirror_gate_requires_both_absent": True,
        "r2_root_is_read_only_preserved": True,
    }
    r3["r3_pre_output_closure_contract"] = {
        "schema": "mms-v21-r3-v10-pre-mirror-closure-v1",
        "function": "verify_v10_closure_before_mirror",
        "position": "R3 resolver-factory gate after official timer/protocol SHA validation and before the original resolver writes any R3 mirror file",
        "required_v10_inputs": 89,
        "required_archive_map_entries": 613,
        "required_archive_directory_prefixes": 31,
        "requires_exact_archive_file_sha256": ARCHIVE_SHA256,
        "missing_or_changed_input_action": "raise before R3 archive-mirror/output creation; do not execute a producer or consumer",
        "r2_mirror_is_untouched": True,
    }
    r3["parent_r2_protocol"] = {
        "path": R2_PROTOCOL_REL, "bytes": len(r2_wire), "sha256": R2_PROTOCOL_SHA256,
        "runtime_failure_receipt": {
            "path": R2_RUNTIME_RECEIPT_REL,
            "bytes": R2_RUNTIME_RECEIPT_BYTES,
            "sha256": R2_RUNTIME_RECEIPT_SHA256,
            "julia_started": False,
            "mirror_materialized": True,
            "output_leaf_created": False,
        },
    }
    r3["owned_source_files"] = source_rows["owned_source_files"]
    r3["owned_source_files_by_path"] = source_rows["owned_source_files_by_path"]
    r3["r3_created_utc"] = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")
    r3["independent_static_review"] = {
        "scope": "R3 exact process-tree negative-control shape, R2 mirror preservation, R3 pre-mirror closure, and pure pre-output contracts; pending independent result",
        "julia_started": False,
        "solver_started": False,
        "runtime_grant": False,
    }

    summary = {
        "protocol_path": str(R3_PROTOCOL_PATH),
        "parent_r2_protocol_sha256": R2_PROTOCOL_SHA256,
        "parent_r2_mirror": mirror,
        "r3_owned_source_count": len(r3["owned_source_files"]),
        "r3_static_test_sha256": r3["owned_source_files_by_path"][R3_TEST_REL],
        "monitor_negative_controls": len(PROCESS_TREE_NEGATIVES),
        "archive_mapped_files": len(r3["archived_input_source"]["entries"]),
        "v10_pinned_inputs": r3["v10_protocol"]["pinned_input_count"],
        "r3_output_root_absent": not R3_OUTPUT_ROOT.exists(),
        "runtime_grant": r3["runtime_grant"],
    }
    return r3, summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="write only replay_protocol_v21_r3.json")
    args = parser.parse_args()
    protocol, summary = build_protocol()
    wire = canonical_bytes(protocol)
    summary["protocol_sha256"] = sha256_bytes(wire)
    summary["protocol_bytes"] = len(wire)
    if args.write:
        if R3_PROTOCOL_PATH.exists():
            raise FileExistsError("preserve existing R3 protocol; this builder never replaces it")
        R3_PROTOCOL_PATH.write_bytes(wire)
        summary["written"] = True
    else:
        summary["written"] = False
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
