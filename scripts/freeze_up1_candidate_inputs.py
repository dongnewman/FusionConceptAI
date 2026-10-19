"""Copy the current UP1 G1/G2 consumer inputs into one closed, pinned snapshot.

This prepares a local software admission input. It does not grant source,
physics, engineering, or final-candidate authority.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import stat


ROOT = Path(__file__).resolve().parents[1]
CANDIDATE_DIR = Path("benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2")
CANDIDATE_ID = "local-authored-up4-g123-20260928-r2"
CONSUMER = Path("test/GenomeV5/Integration/up1_frozen_source_t0_v1_tests.jl")
G3_CONSUMER_HELPER = Path("test/GenomeV5/Integration/up1_g3_expected_consumer_helpers.jl")
G3_EXPECTED_PRODUCER = Path("scripts/up1_g3_expected_commitment_producer_v1.jl")
FREEZER = Path("scripts/freeze_up1_candidate_inputs.py")
NATIVE_HANDOFF = Path("scripts/run_up1_native_handoff.jl")
AD45 = Path("docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json")
CANDIDATE_REF = "fusionconceptai://candidate-design/local-authored-up4-g123-20260928-r2"
SCENARIO_ID = "scenario-local-authored-up4-g123-20260928-r2"


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def checked_file(relative: Path) -> bytes:
    source = ROOT / relative
    cursor = ROOT
    for part in relative.parts:
        cursor /= part
        link_info = cursor.stat(follow_symlinks=False)
        if stat.S_ISLNK(link_info.st_mode) or \
                getattr(link_info, "st_file_attributes", 0) & 0x0400:
            raise ValueError(f"linked or reparse input component: {relative.as_posix()}")
    if not source.is_file() or source.is_symlink():
        raise ValueError(f"missing or linked input: {relative.as_posix()}")
    info = source.stat(follow_symlinks=False)
    if not stat.S_ISREG(info.st_mode) or getattr(info, "st_file_attributes", 0) & 0x0400:
        raise ValueError(f"non-regular or reparse input: {relative.as_posix()}")
    return source.read_bytes()


def inputs() -> list[tuple[Path, Path, str]]:
    # On Windows, root/Manifest.toml would alias the UP1 root/manifest.toml.
    # Keep the Julia project under runtime_project, with source copies pinned
    # alongside the source paths observed by UP1 locators.
    paths = [(Path("Project.toml"), Path("runtime_project/Project.toml"), "runtime_config"),
             (Path("Manifest.toml"), Path("runtime_project/Manifest.toml"), "runtime_config"),
             (Path("tools/qualification/gridap/Project.toml"),
              Path("runtime_project/tools/qualification/gridap/Project.toml"), "runtime_config"),
             (Path("tools/qualification/gridap/Manifest.toml"),
              Path("runtime_project/tools/qualification/gridap/Manifest.toml"), "runtime_config"),
             (CONSUMER, CONSUMER, "consumer_source"),
             (G3_CONSUMER_HELPER, G3_CONSUMER_HELPER, "consumer_source"),
             (G3_EXPECTED_PRODUCER, G3_EXPECTED_PRODUCER, "expected_commitment_producer_source"),
             (NATIVE_HANDOFF, NATIVE_HANDOFF, "native_handoff_consumer_source"),
             (FREEZER, FREEZER, "snapshot_freezer_source"),
             (AD45, AD45, "binding_envelope")]
    for source in sorted((ROOT / "src").rglob("*.jl")):
        if source.is_file():
            relative = source.relative_to(ROOT)
            paths.append((relative, relative, "production_source"))
            paths.append((relative, Path("runtime_project") / relative, "runtime_source"))
    paths.extend((p.relative_to(ROOT), p.relative_to(ROOT), "candidate_design_source")
                 for p in sorted((ROOT / CANDIDATE_DIR).iterdir()) if p.is_file())
    names = [target.as_posix() for _, target, _ in paths]
    if len(names) != len(set(names)) or any("\\" in name for name in names):
        raise ValueError("duplicate or noncanonical input path")
    return sorted(paths, key=lambda item: item[1].as_posix())


def verify_candidate_manifest(raw_by_path: dict[str, bytes]) -> None:
    directory = CANDIDATE_DIR.as_posix()
    payload = json.loads(raw_by_path[directory + "/manifest.json"])
    if payload.get("candidate_id") != CANDIDATE_ID or \
            payload.get("candidate_ref") != {"id": CANDIDATE_REF, "version": "v5"} or \
            payload.get("scenario_id") != SCENARIO_ID or \
            payload.get("design_status") != "unvalidated_design_input":
        raise ValueError("candidate identity or status mismatch")
    identity_source = raw_by_path[directory + "/identity.jl"]
    if any(token.encode("utf-8") not in identity_source
           for token in (CANDIDATE_ID, CANDIDATE_REF, SCENARIO_ID)):
        raise ValueError("candidate identity source differs from manifest identity")
    rows = payload.get("files")
    if not isinstance(rows, list):
        raise ValueError("candidate file inventory missing")
    actual = {p[len(directory) + 1:] for p in raw_by_path
              if p.startswith(directory + "/") and p != directory + "/manifest.json"}
    seen: set[str] = set()
    for row in rows:
        name = row.get("path") if isinstance(row, dict) else None
        if not isinstance(name, str) or name in seen or name not in actual:
            raise ValueError("candidate file inventory has an invalid or duplicate member")
        seen.add(name)
        raw = raw_by_path[directory + "/" + name]
        if row.get("bytes") != len(raw) or row.get("sha256") != sha(raw):
            raise ValueError(f"candidate manifest pin mismatch: {name}")
    if seen != actual:
        raise ValueError("candidate manifest omits an input")


def write_new(path: Path, raw: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as stream:
        stream.write(raw)
        stream.flush()
        os.fsync(stream.fileno())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.relative_to(ROOT / "runs" / "e")
    if output.exists():
        raise FileExistsError(f"retain existing evidence: {output}")
    selected = inputs()
    before = {target.as_posix(): checked_file(source) for source, target, _ in selected}
    verify_candidate_manifest(before)
    rows = [{"logical_path": target.as_posix(), "role": role,
             "bytes": len(before[target.as_posix()]), "sha256": sha(before[target.as_posix()])}
            for _, target, role in selected]
    identity_raw = json.dumps({"candidate_ref": CANDIDATE_REF,
                               "scenario_id": SCENARIO_ID, "entries": rows},
                              sort_keys=True, separators=(",", ":")).encode("utf-8")
    snapshot_id = "up1-up4-r2-" + sha(identity_raw)[:20]
    snapshot = output / "snapshot"
    snapshot.mkdir(parents=True, exist_ok=False)
    for row in rows:
        relative = Path(row["logical_path"])
        write_new(snapshot / relative, before[row["logical_path"]])
    lines = ["[snapshot]", 'schema = "fusion-up1-04a-vnext-frozen-source-v1"',
             f"snapshot_id = {json.dumps(snapshot_id)}",
             f"candidate_ref = {json.dumps(CANDIDATE_REF)}",
             f"scenario_id = {json.dumps(SCENARIO_ID)}",
             f"entry_count = {len(rows)}", ""]
    for row in rows:
        lines.extend(["[[entries]]", f"logical_path = {json.dumps(row['logical_path'])}",
                      f"role = {json.dumps(row['role'])}", f"bytes = {row['bytes']}",
                      f"sha256 = {json.dumps(row['sha256'])}", ""])
    manifest_raw = ("\n".join(lines) + "\n").encode("utf-8")
    write_new(snapshot / "manifest.toml", manifest_raw)
    after = {target.as_posix(): checked_file(source) for source, target, _ in selected}
    if any(after[name] != raw for name, raw in before.items()):
        raise RuntimeError("workspace input changed during freeze; retain incomplete output")
    if any((snapshot / row["logical_path"]).read_bytes() != before[row["logical_path"]]
           for row in rows):
        raise RuntimeError("snapshot copy differs from captured bytes; retain incomplete output")
    receipt = {"schema": "up1-candidate-freeze-receipt-v1", "snapshot_root": str(snapshot),
               "runtime_project": str(snapshot / "runtime_project"),
               "snapshot_id": snapshot_id, "manifest_sha256": sha(manifest_raw),
               "candidate_ref": CANDIDATE_REF, "scenario_id": SCENARIO_ID,
               "entry_count": len(rows), "entries": rows, "source_pins_unchanged": True,
               "snapshot_copy_verified": True, "formal_acceptance": False,
               "physical_validation": "not_assessed"}
    receipt_raw = (json.dumps(receipt, indent=2, sort_keys=True) + "\n").encode("utf-8")
    write_new(output / "freeze_receipt.json", receipt_raw)
    print(json.dumps({"snapshot_id": snapshot_id, "entry_count": len(rows),
                      "manifest_sha256": sha(manifest_raw),
                      "freeze_receipt_sha256": sha(receipt_raw)}), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
