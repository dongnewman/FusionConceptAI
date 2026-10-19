#!/usr/bin/env python3
"""Build the immutable V21 replay protocol from retained V20 and its cleanup ZIP."""
from __future__ import annotations

import argparse
import copy
import datetime as dt
import hashlib
import json
import pathlib
import zipfile
from pathlib import PurePosixPath
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parents[3]
BASE = pathlib.Path(__file__).resolve().parent
PROTOCOL_PATH = BASE / "replay_protocol_v21.json"
ARCHIVE_PATH = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "precleanup_docs_runs_tmp.zip"
ARCHIVE_SHA256 = "c84743bc55dc749bbcc43e936c278027ad9bce9b437c09e176be587f75ff2bb7"
ARCHIVE_PROTOCOL = (
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_continuation_r20/replay_protocol_v20.json"
)
V20_REVIEW_ROOT = (
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "independent_replay_v20_postrun_audit_fec_reference_audit_r1_20260926"
)
V16_ABSENT_AFTER_OBSERVATION = (
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_continuation_r16/runtime_replay_r16/producer_process/numerical/"
    "hydration_observation_reconstruction.json"
)
OUTPUT_ROOT = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "up2_replay_v21"
STAGING_ROOT = OUTPUT_ROOT / "archive_mirror"
OUTPUT_LEAF = OUTPUT_ROOT / "runtime_replay_r21"
V21_ENTRYPOINT = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_staged_v21.jl"
V21_CONTROLLER = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21.py"
V21_BUILDER = "test/RuntimeV4/UP2ClosureReplayOnlyV21/build_protocol_v21.py"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def normalize_docs_path(value: str) -> str:
    logical = value.replace("\\", "/")
    path = PurePosixPath(logical)
    if path.is_absolute() or path.parts[:1] != ("docs",) or \
            any(part in ("", ".", "..") for part in path.parts):
        raise ValueError(f"V20 path-valued docs reference is not a confined relative path: {value!r}")
    return path.as_posix()


def iter_path_values(value: Any, location: str = "$"):
    if isinstance(value, dict):
        for key, child in value.items():
            if isinstance(child, str) and child.replace("\\", "/").startswith("docs/") and \
                    any(token in key.lower() for token in ("path", "file", "root", "leaf")):
                yield normalize_docs_path(child), f"{location}.{key}"
            yield from iter_path_values(child, f"{location}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from iter_path_values(child, f"{location}[{index}]")


def inventory_from_zip(archive: zipfile.ZipFile, prefix: str) -> list[dict[str, Any]]:
    prefix = prefix.rstrip("/") + "/"
    rows = []
    for info in sorted((item for item in archive.infolist()
                        if not item.is_dir() and item.filename.startswith(prefix)),
                       key=lambda item: item.filename):
        data = archive.read(info)
        rows.append({"path": info.filename, "bytes": len(data), "sha256": sha256_bytes(data)})
    return rows


def current_directory_inventory(path: pathlib.Path) -> list[dict[str, Any]]:
    return [{"path": item.relative_to(path).as_posix(), "bytes": item.stat().st_size,
             "sha256": sha256_file(item)}
            for item in sorted(path.rglob("*")) if item.is_file()]


def path_record_from_zip(archive: zipfile.ZipFile, logical: str) -> tuple[bytes, zipfile.ZipInfo]:
    info = archive.getinfo(logical)
    if info.is_dir():
        raise ValueError(f"V21 archive input expected a file but found a directory: {logical}")
    content = archive.read(info)
    return content, info


def verify_v20_failure(archive: zipfile.ZipFile, parent: dict[str, Any]) -> dict[str, Any]:
    protocol_ref = {"path": ARCHIVE_PROTOCOL, "bytes": archive.getinfo(ARCHIVE_PROTOCOL).file_size,
                    "sha256": sha256_bytes(archive.read(ARCHIVE_PROTOCOL))}
    if protocol_ref["sha256"] != "26690948566c5191994e2d2ae3cbf94e7d9f481f8adf7e88962b128792d61dc2":
        raise ValueError("retained V20 protocol does not match the independently reported frozen SHA-256")
    if parent.get("schema") != "mms-replay-only-continuation-protocol-v20" or \
            parent.get("version") != 20 or parent.get("runtime_grant") is not False or \
            parent.get("classification") != "test_only_continuation":
        raise ValueError("V20 source protocol is not the retained test-only candidate")

    runtime_root = parent.get("output_leaf")
    if not isinstance(runtime_root, str):
        raise ValueError("V20 protocol lacks its historical output leaf")
    runtime_entries = inventory_from_zip(archive, runtime_root)
    review_entries = inventory_from_zip(archive, V20_REVIEW_ROOT)
    if len(runtime_entries) != 21 or len(review_entries) != 8:
        raise ValueError("V20 archived runtime/review inventories differ from the retained 21/8 file closure")
    runtime_by_path = {row["path"]: row for row in runtime_entries}
    review_by_path = {row["path"]: row for row in review_entries}

    def json_at(path: str) -> dict[str, Any]:
        if path not in runtime_by_path and path not in review_by_path:
            raise ValueError(f"V20 required failure/review receipt is outside its archived inventory: {path}")
        data, _ = path_record_from_zip(archive, path)
        value = json.loads(data)
        if not isinstance(value, dict):
            raise ValueError(f"V20 receipt is not a JSON object: {path}")
        return value

    final_path = f"{runtime_root}/final.json"
    process_path = f"{runtime_root}/producer_process.json"
    stdout_path = f"{runtime_root}/producer_process/stdout.raw"
    stderr_path = f"{runtime_root}/producer_process/stderr.raw"
    review_json_path = f"{V20_REVIEW_ROOT}/review.json"
    review_report_path = f"{V20_REVIEW_ROOT}/review.md"
    final = json_at(final_path)
    process = json_at(process_path)
    review = json_at(review_json_path)
    report = archive.read(review_report_path).decode("utf-8", errors="replace")
    stderr = archive.read(stderr_path).decode("utf-8", errors="replace")
    stdout = archive.read(stdout_path).decode("utf-8", errors="replace")
    if (final.get("controller_exit_code"), final.get("classification"), final.get("solver_exit_code"),
            final.get("numerical_status"), final.get("stopping_reason"), final.get("authority"),
            final.get("physical_validation"), final.get("nonlinear_solves")) != (
            124, "resource_interruption", 2, "fail", "stationary_nonzero_residual", "no_publish",
            "unsupported", 0):
        raise ValueError("V20 archived controller failure/no-credit semantics changed")
    if (process.get("schema"), process.get("stage"), process.get("exit_code"), process.get("stop_reason"),
            process.get("rss_complete_sample_count"), process.get("rss_sampling_complete")) != (
            "mms-replay-recorded-process-v2", None, 1, "cleanup_unconfirmed", 934, False):
        raise ValueError("V20 archived producer root-exit RSS/cleanup race signature changed")
    stages = final.get("stages")
    if not isinstance(stages, list) or len(stages) != 1 or not isinstance(stages[0], dict) or \
            stages[0].get("stage") != "producer" or \
            {key: value for key, value in stages[0].items() if key != "stage"} != process:
        raise ValueError("V20 controller final no longer preserves its sole producer receipt")
    errors = process.get("rss_observation_errors", [])
    cleanup = process.get("cleanup", {})
    if not any(isinstance(item, dict) and item.get("error_type") == "NoSuchProcess" and
               item.get("root_pid") == process.get("pid") and item.get("process_pid") == process.get("pid")
               for item in errors) or cleanup.get("termination_confirmed") is not False or \
            not any(isinstance(item, dict) and item.get("error_type") == "NoSuchProcess"
                    for item in cleanup.get("termination_verification_errors", [])):
        raise ValueError("V20 raw process evidence no longer shows the pinned NoSuchProcess root race")
    if (not isinstance(final.get("aggregate_child_wall_budget"), dict) or
            final["aggregate_child_wall_budget"].get("limit_seconds") != 960.0 or
            final["aggregate_child_wall_budget"].get("overrun_seconds") != 0.0 or
            not isinstance(final.get("controller_overhead_budget"), dict) or
            final["controller_overhead_budget"].get("limit_seconds") != 120.0):
        raise ValueError("V20 archived aggregate/overhead limits changed")
    if "saved result state hash differs from protocol" not in stderr or "mode=producer" not in stdout:
        raise ValueError("V20 archived raw output no longer records the state identity failure")
    if (review.get("verdict"), review.get("reviewer_ran_julia")) != ("NO_GO", False) or \
            review.get("protocol", {}).get("sha256") != protocol_ref["sha256"] or \
            "NO-GO for another V20 replay" not in report or "different hash definitions" not in report:
        raise ValueError("V20 archived independent NO-GO review changed")
    if any("consumer_process" in row["path"] or "producer_validator_started.json" in row["path"] or
           "producer_complete.json" in row["path"] for row in runtime_entries):
        raise ValueError("V20 archived failed run unexpectedly includes validator or consumer completion")

    numerical_ref = parent.get("replay_inputs", {}).get("numerical_result")
    if not isinstance(numerical_ref, dict):
        raise ValueError("V20 protocol has no pinned saved numerical-result source")
    numerical_bytes, _ = path_record_from_zip(archive, numerical_ref.get("path", ""))
    if (len(numerical_bytes), sha256_bytes(numerical_bytes)) != (
            numerical_ref.get("bytes"), numerical_ref.get("sha256")):
        raise ValueError("V20 saved numerical-result source differs from its protocol binding")
    numerical = json.loads(numerical_bytes)
    cases = numerical.get("cases")
    if not isinstance(cases, list) or not cases or not isinstance(cases[0], dict):
        raise ValueError("V20 saved numerical result has no first case state identity")
    state_hash_wire = cases[0].get("state_hash")
    case_state_hash = state_hash_wire.get("value") if isinstance(state_hash_wire, dict) else None
    if case_state_hash != "b36d2109eba29fdced93e09f2730fb785860f203d4cf9d39f2dedf43e94fb5d7":
        raise ValueError("V20 case-bound state hash differs from the archived failure diagnosis")
    if parent.get("preserved_identity", {}).get("state_after_hash") != \
            "464534cafdcecbbf215c656843349faa88a4ea3120e58d4cf79345a71bd89662":
        raise ValueError("V20 solver final-state vector digest differs from the archived failure diagnosis")

    source_entries = parent.get("owned_source_files")
    if not isinstance(source_entries, list) or len(source_entries) != 4:
        raise ValueError("V20 frozen source inventory is malformed")
    for row in source_entries:
        path = ROOT / pathlib.Path(*PurePosixPath(row["path"]).parts)
        if not path.is_file() or path.stat().st_size != row["bytes"] or sha256_file(path) != row["sha256"]:
            raise ValueError(f"retained V20 source does not match its frozen source inventory: {row['path']}")
    return {
        "protocol": protocol_ref,
        "output_leaf": runtime_root,
        "runtime_entries": runtime_entries,
        "review_entries": review_entries,
        "source_files": source_entries,
        "final_path": final_path,
        "process_path": process_path,
        "stdout_path": stdout_path,
        "stderr_path": stderr_path,
        "review_json_path": review_json_path,
        "review_report_path": review_report_path,
        "case_state_hash": case_state_hash,
    }


def verify_expected_absence(parent: dict[str, Any], archive_names: set[str], archive_dirs: set[str]) -> dict[str, Any]:
    v16 = parent.get("parent_v16_actual_failure")
    if not isinstance(v16, dict) or v16.get("after_observation_present") is not False or \
            v16.get("after_observation_path") != V16_ABSENT_AFTER_OBSERVATION:
        raise ValueError("V20 protocol does not prove the specific V16 after-observation output was absent")
    runtime_entries = v16.get("runtime_entries")
    protocol_ref = v16.get("protocol")
    if not isinstance(runtime_entries, list) or len(runtime_entries) != 19 or not isinstance(protocol_ref, dict) or \
            any(isinstance(item, dict) and item.get("path") == V16_ABSENT_AFTER_OBSERVATION
                for item in runtime_entries):
        raise ValueError("V16 absence witness runtime manifest does not exclude the after-observation path")
    if V16_ABSENT_AFTER_OBSERVATION in archive_names or V16_ABSENT_AFTER_OBSERVATION in archive_dirs or \
            (ROOT / pathlib.Path(*PurePosixPath(V16_ABSENT_AFTER_OBSERVATION).parts)).exists():
        raise ValueError("V16 observation path exists despite its archived absence witness")
    return {
        "logical_path": V16_ABSENT_AFTER_OBSERVATION,
        "kind": "expected_absent_historical_output",
        "reason": "V16 runtime receipt records after_observation_present=false; the exact path is excluded from its pinned 19-file runtime inventory.",
        "archive_sha256": ARCHIVE_SHA256,
        "archive_member_present": False,
        "workspace_state_at_build": "absent",
        "witness_field": "parent_v16_actual_failure.after_observation_present",
        "witness_protocol_path": protocol_ref["path"],
        "witness_protocol_sha256": protocol_ref["sha256"],
        "witness_runtime_root": v16["runtime_root"],
        "witness_runtime_entries_sha256": sha256_bytes(canonical_bytes(runtime_entries)),
    }


def build_directory_binding(archive: zipfile.ZipFile, logical: str,
                            map_entries: dict[str, dict[str, Any]]) -> dict[str, Any]:
    prefix = logical.rstrip("/") + "/"
    archive_infos = sorted((info for info in archive.infolist()
                            if not info.is_dir() and info.filename.startswith(prefix)),
                           key=lambda info: info.filename)
    archive_members = [{"member": info.filename, "bytes": info.file_size,
                        "crc32": f"{info.CRC:08x}"} for info in archive_infos]
    mapped = sorted((row for path, row in map_entries.items() if path.startswith(prefix)),
                    key=lambda row: row["logical_path"])
    mapped_manifest = [{"logical_path": row["logical_path"], "bytes": row["bytes"],
                        "sha256": row["sha256"]} for row in mapped]
    workspace_path = ROOT / pathlib.Path(*PurePosixPath(logical).parts)
    current = current_directory_inventory(workspace_path) if workspace_path.is_dir() else []
    current_bytes = sum(row["bytes"] for row in current)
    return {
        "logical_path": logical,
        "archive_member_prefix": logical,
        "archive_sha256": ARCHIVE_SHA256,
        "archive_member_count": len(archive_infos),
        "archive_member_bytes": sum(info.file_size for info in archive_infos),
        "archive_member_manifest_sha256": sha256_bytes(canonical_bytes(archive_members)),
        "mapped_descendant_count": len(mapped),
        "mapped_descendant_bytes": sum(row["bytes"] for row in mapped),
        "mapped_descendant_manifest_sha256": sha256_bytes(canonical_bytes(mapped_manifest)),
        "workspace_state": "present" if workspace_path.is_dir() else "absent",
        "workspace_file_count": len(current),
        "workspace_bytes": current_bytes,
        "workspace_manifest_sha256": sha256_bytes(canonical_bytes(current)),
        "mirror_scope": "explicitly_mapped_descendants_only",
    }


def build_protocol() -> tuple[dict[str, Any], dict[str, Any]]:
    if not ARCHIVE_PATH.is_file() or sha256_file(ARCHIVE_PATH) != ARCHIVE_SHA256:
        raise ValueError("precleanup docs archive is missing or differs from the fixed SHA-256")
    with zipfile.ZipFile(ARCHIVE_PATH, "r") as archive:
        archive_names = {info.filename for info in archive.infolist() if not info.is_dir()}
        archive_dirs = {"/".join(PurePosixPath(info.filename).parts[:index])
                        for info in archive.infolist() if not info.is_dir()
                        for index in range(1, len(PurePosixPath(info.filename).parts))}
        if ARCHIVE_PROTOCOL not in archive_names:
            raise FileNotFoundError(f"V20 protocol is absent from the pinned cleanup archive: {ARCHIVE_PROTOCOL}")
        v20_protocol_bytes = archive.read(ARCHIVE_PROTOCOL)
        v20 = json.loads(v20_protocol_bytes)
        parent_v20_failure = verify_v20_failure(archive, v20)
        expected_absent = verify_expected_absence(v20, archive_names, archive_dirs)

        path_occurrences: dict[str, list[str]] = {}
        for logical, source in iter_path_values(v20):
            path_occurrences.setdefault(logical, []).append(source)
        v20_path_value_occurrences = sum(len(items) for items in path_occurrences.values())
        v20_unique_docs_paths = len(path_occurrences)
        # Add the parent V20 protocol and its actual failure/review closure, which are
        # referenced by the new V21 ancestry record rather than by V20's own protocol.
        extra_source_paths = {
            ARCHIVE_PROTOCOL: ["V21.parent_v20_actual_failure.protocol.path"],
            **{row["path"]: ["V21.parent_v20_actual_failure.runtime_entries"]
               for row in parent_v20_failure["runtime_entries"]},
            **{row["path"]: ["V21.parent_v20_actual_failure.review_entries"]
               for row in parent_v20_failure["review_entries"]},
        }
        for logical, sources in extra_source_paths.items():
            path_occurrences.setdefault(logical, []).extend(sources)

        path_classes: dict[str, str] = {}
        map_entries: dict[str, dict[str, Any]] = {}
        restored_entries = []
        directory_logicals = []
        expected_absent_logicals = {expected_absent["logical_path"]}
        for logical in sorted(path_occurrences):
            if logical in archive_names:
                content, info = path_record_from_zip(archive, logical)
                archive_sha = sha256_bytes(content)
                workspace_path = ROOT / pathlib.Path(*PurePosixPath(logical).parts)
                workspace_state = "missing"
                workspace_bytes = None
                workspace_sha = None
                if workspace_path.is_file():
                    workspace_bytes = workspace_path.stat().st_size
                    workspace_sha = sha256_file(workspace_path)
                    if workspace_bytes != info.file_size or workspace_sha != archive_sha:
                        raise ValueError(f"restored workspace path differs from pinned archive member: {logical}")
                    workspace_state = "present_same_sha256"
                map_entries[logical] = {
                    "logical_path": logical, "archive_member": logical,
                    "bytes": info.file_size, "sha256": archive_sha,
                    "archive_sha256": ARCHIVE_SHA256,
                    "workspace_state_at_build": workspace_state,
                    "workspace_bytes_at_build": workspace_bytes,
                    "workspace_sha256_at_build": workspace_sha,
                    "source_fields": sorted(set(path_occurrences[logical])),
                }
                path_classes[logical] = "archive_file"
                continue
            if logical in archive_dirs:
                directory_logicals.append(logical)
                path_classes[logical] = "archive_directory_prefix"
                continue
            workspace_path = ROOT / pathlib.Path(*PurePosixPath(logical).parts)
            if workspace_path.is_file():
                size = workspace_path.stat().st_size
                sha = sha256_file(workspace_path)
                restored_entries.append({"logical_path": logical, "bytes": size, "sha256": sha,
                                         "source_fields": sorted(set(path_occurrences[logical]))})
                path_classes[logical] = "restored_workspace_file"
                continue
            if workspace_path.is_dir():
                # This is a verified restored directory reference, not an implicit fallback.
                current = current_directory_inventory(workspace_path)
                restored_dir = {"logical_path": logical, "file_count": len(current),
                                "bytes": sum(row["bytes"] for row in current),
                                "manifest_sha256": sha256_bytes(canonical_bytes(current)),
                                "source_fields": sorted(set(path_occurrences[logical]))}
                directory_logicals.append(logical)
                path_classes[logical] = "restored_workspace_directory"
                continue
            if logical in expected_absent_logicals:
                path_classes[logical] = "expected_absent_historical_output"
                continue
            raise FileNotFoundError(
                f"required V20 docs reference is neither restored, ZIP-mapped, nor proven absent: {logical}")

        # Historical output leaf inventories are independently reconstructed from the
        # exact V20 runtime and review directories and must agree with their fixed counts.
        source_inventory = v20.get("owned_source_files")
        if not isinstance(source_inventory, list):
            raise ValueError("V20 source inventory is missing")
        runtime_root = parent_v20_failure["output_leaf"]
        review_root = V20_REVIEW_ROOT
        for root_path, expected in ((runtime_root, 21), (review_root, 8)):
            leaf_files = sorted(name for name in archive_names if name.startswith(root_path.rstrip("/") + "/"))
            if len(leaf_files) != expected:
                raise ValueError(f"archived failure/review leaf inventory changed: {root_path}")

        directory_prefixes = []
        restored_directories = []
        for logical in sorted(set(directory_logicals)):
            if logical in archive_dirs:
                directory_prefixes.append(build_directory_binding(archive, logical, map_entries))
            else:
                current = current_directory_inventory(ROOT / pathlib.Path(*PurePosixPath(logical).parts))
                restored_directories.append({"logical_path": logical, "file_count": len(current),
                    "bytes": sum(row["bytes"] for row in current),
                    "manifest_sha256": sha256_bytes(canonical_bytes(current)),
                    "source_fields": sorted(set(path_occurrences[logical]))})

        path_references = []
        for logical in sorted(path_occurrences):
            path = ROOT / pathlib.Path(*PurePosixPath(logical).parts)
            path_references.append({
                "logical_path": logical,
                "classification": path_classes[logical],
                "occurrence_count": len(path_occurrences[logical]),
                "source_fields": sorted(set(path_occurrences[logical])),
                "workspace_state_at_build": "present" if path.exists() else "absent",
                "workspace_sha256_at_build": (
                    sha256_file(path) if path.is_file() else
                    next((row["workspace_manifest_sha256"] for row in directory_prefixes
                          if row["logical_path"] == logical), None)),
                "archive_source_sha256": ARCHIVE_SHA256 if path_classes[logical].startswith("archive_") or
                    path_classes[logical] == "expected_absent_historical_output" else None,
            })

        controller_path = ROOT / pathlib.Path(*PurePosixPath(V21_CONTROLLER).parts)
        entrypoint_path = ROOT / pathlib.Path(*PurePosixPath(V21_ENTRYPOINT).parts)
        builder_path = ROOT / pathlib.Path(*PurePosixPath(V21_BUILDER).parts)
        for path in (controller_path, entrypoint_path, builder_path):
            if not path.is_file():
                raise FileNotFoundError(f"V21 owned source is missing: {path}")
        owned_sources = []
        for rel, path in ((V21_ENTRYPOINT, entrypoint_path), (V21_CONTROLLER, controller_path),
                          (V21_BUILDER, builder_path)):
            owned_sources.append({"path": rel, "bytes": path.stat().st_size,
                                  "sha256": sha256_file(path)})
        source_by_path = {row["path"]: row["sha256"] for row in owned_sources}

        v21 = copy.deepcopy(v20)
        v21.update({
            "schema": "mms-replay-only-continuation-protocol-v21",
            "version": 21,
            "recorded_utc": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d"),
            "frozen_utc": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d"),
            "protocol_generation": (
                "Test-only V21 repair from the retained V20 failure. V21 separately verifies the saved final-state "
                "vector digest and the case-bound V4 state identity, then recognizes only the exact pinned leader "
                "NoSuchProcess race after Popen confirms exit and at least one complete RSS sample before the full "
                "descendant audit. V20 failure/review bytes remain immutable ancestry. Numerical failure, 1e-6 "
                "threshold, 480 s per stage, sampled 2 GiB RSS, 960 s aggregate child wall, and 120 s controller "
                "overhead are unchanged; runtime grant remains false."
            ),
            "controller": V21_CONTROLLER,
            "entrypoint": V21_ENTRYPOINT,
            "output_leaf": str(OUTPUT_LEAF.resolve()),
            "owned_source_files": owned_sources,
            "owned_source_files_by_path": source_by_path,
            "parent_v20_actual_failure": parent_v20_failure,
            "archived_input_source": {
                "schema": "mms-v21-archived-input-map-v1",
                "archive_path": str(ARCHIVE_PATH.resolve()),
                "archive_sha256": ARCHIVE_SHA256,
                "staging_root": str(STAGING_ROOT.resolve()),
                "closure_scope": "All docs path/root/leaf/file values in the exact retained V20 protocol, plus the V20 protocol and its 21-file runtime/8-file independent-review failure closure.",
                "entries": [map_entries[key] for key in sorted(map_entries)],
                "directory_prefixes": directory_prefixes,
                "restored_entries": restored_entries,
                "restored_directories": restored_directories,
                "expected_absent": [expected_absent],
                "referenced_paths": path_references,
                "closure_summary": {
                    "v20_path_value_occurrences": v20_path_value_occurrences,
                    "v20_unique_docs_path_values": v20_unique_docs_paths,
                    "v21_parent_v20_extra_file_references": len(extra_source_paths),
                    "complete_unique_docs_paths": len(path_occurrences),
                    "archive_mapped_files": len(map_entries),
                    "archive_mapped_bytes": sum(row["bytes"] for row in map_entries.values()),
                    "archive_mapped_workspace_present_files": sum(
                        row["workspace_state_at_build"] == "present_same_sha256" for row in map_entries.values()),
                    "archive_mapped_workspace_missing_files": sum(
                        row["workspace_state_at_build"] == "missing" for row in map_entries.values()),
                    "archive_directory_prefixes": len(directory_prefixes),
                    "restored_workspace_files_without_archive": len(restored_entries),
                    "restored_workspace_directories_without_archive": len(restored_directories),
                    "witnessed_expected_absences": len([expected_absent]),
                },
            },
            "static_test": None,
            "static_test_contract": {
                "status": "pending_independent_test_assignment",
                "command": None,
                "evidence_leaf": None,
                "julia_started": False,
                "producer_consumer_started": False,
                "runtime_grant": False,
            },
            "static_contract_run": {
                "status": "not_run",
                "julia_started": False,
                "producer_consumer_started": False,
                "output_leaf_must_remain_absent": True,
            },
            "state": "static_candidate_pending_independent_review_and_root_serial_slot",
            "grant_note": (
                "V21 protocol/source candidate only. runtime_grant remains false. Independent test/review and a "
                "separate root serial-slot grant are required before any producer/consumer replay."
            ),
        })
        v21["preserved_identity"]["case_state_hash"] = parent_v20_failure["case_state_hash"]
        v21["controller_command_template"] = (
            f"{v21['runtime']['python_executable']} -B {V21_CONTROLLER} --protocol "
            f"test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21.json "
            f"--protocol-sha256 <protocol-sha256> --output {OUTPUT_LEAF.resolve()} --root-serial-slot-granted"
        )
        v21["context_builder_contract"]["entrypoint_path"] = V21_ENTRYPOINT
        v21["context_builder_contract"]["entrypoint_sha256"] = source_by_path[V21_ENTRYPOINT]
        v21["context_builder_contract"]["semantic_change"] = (
            "V21 preserves the V4 context reconstruction. The added state identity check hashes the final-state "
            "vector independently, then recomputes the separate case-bound state hash with candidate, context, "
            "case id, level, flux, and final state."
        )
        v21["child_command_contract"] = {
            "producer": [v21["runtime"]["julia_executable"], "--startup-file=no", "--project=.", V21_ENTRYPOINT,
                         "producer", "<new-producer-numerical-dir>",
                         str((STAGING_ROOT / pathlib.Path(*PurePosixPath(v21["saved_producer_tree"]["root"]).parts)).resolve()),
                         "<protocol-sha256>", "not_applicable", "not_applicable"],
            "consumer": [v21["runtime"]["julia_executable"], "--startup-file=no", "--project=.", V21_ENTRYPOINT,
                         "consumer", "<new-consumer-numerical-dir>", "<new-producer-numerical-dir>",
                         "<protocol-sha256>", "<controller-sealed-carrier-sha256>",
                         "<controller-sealed-binding-sha256>"],
        }
        v21["coverage_contract"]["output_leaf"] = str(OUTPUT_LEAF.resolve())
        v21["coverage_contract"]["child_argv"] = {
            "entrypoint": V21_ENTRYPOINT,
            "negative_control": "No producer or consumer starts from static checks; V21 tests and independent review follow before the separately granted root serial slot.",
        }
        v21["coverage_contract"]["hydration_fix"] = (
            "Preserve V20 observe-first schema reconstruction. Validate canonical_hash(Tuple(final_state)) against "
            "the solver state_after_hash, then independently recompute the case-bound state hash with its V4 identity fields."
        )
        v21["coverage_contract"]["process_tree_resource_monitor_negative_controls"] = (
            "Only an exact pinned Popen leader confirmed exited after a complete RSS sample may enter the V21 "
            "NoSuchProcess race branch; every previously observed descendant and current PPID table is still audited."
        )
        v21["independent_static_review"] = {
            "scope": "V21 test-only source/protocol review pending",
            "julia_started": False, "solver_started": False, "runtime_grant": False,
        }

        # Keep the existing parent status meanings and all resource/numerical gates.
        if (v21["stage_limits"].get("seconds"), v21["stage_limits"].get("working_set_bytes"),
                v21.get("total_child_wall_limit_seconds"), v21.get("controller_overhead_seconds_limit"),
                v21["preserved_numerical_status"]) != (
                480, 2147483648, 960, 120,
                {"authority": "no_publish", "physical_validation": "unsupported", "solver_exit_code": 2,
                 "status": "fail", "stopping_reason": "stationary_nonzero_residual"}):
            raise ValueError("V21 builder would change a frozen numerical or resource acceptance gate")

        summary = {
            "protocol_path": str(PROTOCOL_PATH),
            "archive_sha256": ARCHIVE_SHA256,
            "v20_protocol_sha256": parent_v20_failure["protocol"]["sha256"],
            "v20_path_value_occurrences": v20_path_value_occurrences,
            "v20_unique_docs_path_values": v20_unique_docs_paths,
            "complete_unique_docs_paths_including_v20_failure": len(path_occurrences),
            "v21_parent_v20_extra_file_references": len(extra_source_paths),
            "archive_mapped_files": len(map_entries),
            "archive_mapped_bytes": sum(row["bytes"] for row in map_entries.values()),
            "archive_mapped_workspace_present_files": sum(
                row["workspace_state_at_build"] == "present_same_sha256" for row in map_entries.values()),
            "archive_mapped_workspace_missing_files": sum(
                row["workspace_state_at_build"] == "missing" for row in map_entries.values()),
            "archive_directory_prefixes": len(directory_prefixes),
            "restored_workspace_files_without_archive": len(restored_entries),
            "witnessed_expected_absences": [expected_absent["logical_path"]],
            "v20_runtime_files": len(parent_v20_failure["runtime_entries"]),
            "v20_review_files": len(parent_v20_failure["review_entries"]),
            "owned_sources": owned_sources,
        }
        return v21, summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="write the V21 protocol into this directory")
    parser.add_argument("--replace", action="store_true", help="replace an existing V21 protocol after review")
    args = parser.parse_args()
    protocol, summary = build_protocol()
    wire = canonical_bytes(protocol)
    summary["protocol_sha256"] = sha256_bytes(wire)
    summary["protocol_bytes"] = len(wire)
    if args.write:
        if PROTOCOL_PATH.exists() and not args.replace:
            raise FileExistsError("V21 protocol already exists; use --replace only after reviewing the source changes")
        PROTOCOL_PATH.write_bytes(wire)
        summary["written"] = True
    else:
        summary["written"] = False
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
