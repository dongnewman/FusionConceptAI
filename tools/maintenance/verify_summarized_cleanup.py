"""Verify the one-time cleanup and compact its audit manifests; never delete."""
from __future__ import annotations

import argparse
import collections
import gzip
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/implementation/WORKSPACE-CONSOLIDATION-20261019"


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def read(name: str):
    return json.loads((OUT / name).read_text(encoding="utf-8-sig"))


def rows(name: str):
    path = OUT / name
    opener = path.open if path.is_file() else lambda **kw: gzip.open(str(path) + ".gz", **kw)
    with opener(mode="rt", encoding="utf-8-sig") as stream:
        return [json.loads(line) for line in stream if line.strip()]


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--after", action="store_true")
    parser.add_argument("--compress", action="store_true")
    args = parser.parse_args()
    previous_report = OUT / "post_cleanup_verification.json"
    prior_compaction = {row["path"]: row for row in read(previous_report.name).get("compressed_manifests_verified", [])} if previous_report.is_file() else {}
    plan = rows("deletion_plan.jsonl")
    paths = {row["path"] for row in plan}
    assert len(paths) == len(plan), "duplicate deletion paths"
    for rel in paths:
        assert not Path(rel).is_absolute() and ".." not in Path(rel).parts and ":" not in rel and "\\" not in rel
        assert (ROOT / rel).resolve().is_relative_to(ROOT)
    retained = read("retained_inputs.json")
    assert not paths.intersection(row["path"] for row in retained), "deleted paused input"
    for row in retained:
        path = ROOT / row["path"]
        assert path.is_file() and path.stat().st_size == row["bytes"] and digest(path) == row["sha256"], row["path"]
    for rel in read("active_keep_roots.json"):
        assert (ROOT / rel).exists(), rel
        assert not any(p == rel or p.startswith(rel.rstrip("/") + "/") for p in paths), rel
    with gzip.open(OUT / "run_history_index.jsonl.gz", "rt", encoding="utf-8") as stream:
        history = [json.loads(line) for line in stream]
    projected = {p["path"] for group in history for p in group["json_projections"]}
    deleted_json = {p for p in paths if p.endswith(".json")}
    assert deleted_json <= projected, "removed JSON absent from bounded projection"
    receipts = [row for group in history for row in group["receipts"]]
    fields = collections.Counter("software_check_pass" if r.get("passed_software_check") is True else
                                 "software_check_fail" if r.get("passed_software_check") is False else
                                 "not_classified_by_receipt" for r in receipts)
    statistics = {"groups": len(history), "receipt_records": len(receipts),
                  "receipt_software_check_fields": dict(fields),
                  "interpretation": "receipt records, not unique scientific experiments or acceptance counts"}
    (OUT / "history_statistics.json").write_text(json.dumps(statistics, indent=2), encoding="utf-8")
    retired = [r for r in plan if r["reason"].startswith("retired optional")
               or r["path"] == "test/runtime_v4_freegs_axisymmetric_lcfs_trace_tests.jl.after"]
    (OUT / "retired_code_manifest.json").write_text(json.dumps(retired, indent=2), encoding="utf-8")
    result = {"phase": "after" if args.after else "before", "planned_files": len(plan),
              "planned_bytes": sum(r["bytes"] for r in plan), "retained_input_files_verified": len(retained),
              "retained_input_bytes_verified": sum(r["bytes"] for r in retained),
              "active_roots_verified": len(read("active_keep_roots.json")),
              "removed_json_with_projection": len(deleted_json), "retired_code_files": len(retired),
              "goal_state": "paused", "scientific_acceptance": False}
    if args.after:
        execution = read("deletion_execution.json")
        assert execution["complete"] and execution["failure"] is None, "incomplete application"
        receipt = rows("deletion_receipt.jsonl")
        assert len(receipt) == len(plan) and {r["path"] for r in receipt} == paths
        planned_by_path = {r["path"]: r for r in plan}
        for row in receipt:
            expected = planned_by_path[row["path"]]
            assert row["status"] == "deleted" and row["sha256"] == expected["sha256"] and row["bytes"] == expected["bytes"]
            assert not (ROOT / row["path"]).exists(), row["path"]
        assert execution["deleted_bytes"] == result["planned_bytes"]
        result["all_planned_deletions_verified"] = True
        result["execution"] = execution
    if args.compress:
        assert args.after, "only compact a completed receipt"
        compressed = []
        for name in ("deletion_plan.jsonl", "deletion_receipt.jsonl", "baseline_git_status.bin"):
            src = OUT / name
            dest = OUT / (name + ".gz")
            key = dest.relative_to(ROOT).as_posix()
            if src.is_file():
                expected_raw_hash = digest(src)
                expected_raw_bytes = src.stat().st_size
                with src.open("rb") as source, gzip.open(dest, "wb", compresslevel=9) as target:
                    for block in iter(lambda: source.read(4 * 1024 * 1024), b""):
                        target.write(block)
            else:
                expected = prior_compaction[key]
                assert dest.is_file() and digest(dest) == expected["gzip_sha256"], name
                expected_raw_hash, expected_raw_bytes = expected["raw_sha256"], expected["raw_bytes"]
            h = hashlib.sha256()
            raw_bytes = 0
            with gzip.open(dest, "rb") as stream:
                for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
                    h.update(block)
                    raw_bytes += len(block)
            assert h.hexdigest() == expected_raw_hash and raw_bytes == expected_raw_bytes, name
            compressed.append({"path": key, "raw_bytes": raw_bytes,
                               "raw_sha256": h.hexdigest(), "gzip_bytes": dest.stat().st_size, "gzip_sha256": digest(dest)})
        result["compressed_manifests_verified"] = compressed
    output = OUT / ("post_cleanup_verification.json" if args.after else "pre_cleanup_verification.json")
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
