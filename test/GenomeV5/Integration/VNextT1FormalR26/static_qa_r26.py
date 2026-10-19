"""Read-only protocol, inventory, dependency, and controller QA."""

from pathlib import Path
import argparse, ast, hashlib, json

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
EVIDENCE = ROOT / "docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922"

def digest(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest().upper()}

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    rel = Path(args.out)
    if rel.is_absolute() or ".." in rel.parts:
        raise RuntimeError("invalid output path")
    out = (ROOT / rel).resolve()
    out.relative_to(EVIDENCE)
    out.mkdir(parents=True, exist_ok=False)
    protocol_path = HERE / "protocol_r26_v9.json"
    protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    if protocol["schema"] != "vnext_t1_independent_formal_r26_protocol_v9":
        raise RuntimeError("protocol schema mismatch")
    guard = protocol["path_guard_selftest"]
    if guard != {"schema": "vnext_t1_r26_path_guard_selftest_v1",
            "positive_cases": ["trailing_root_project", "nested_source",
                "new_ledger_parent"],
            "negative_cases": ["dotdot_escape", "absolute_path",
                "repository_sibling_prefix", "different_drive",
                "evidence_sibling_prefix"], "passed": True}:
        raise RuntimeError("path guard selftest inventory mismatch")
    active_julia = [
        "test/GenomeV5/Integration/VNextT1FormalR26/vnext_t1_v1_formal_r26.jl",
        "test/GenomeV5/Integration/VNextT1FormalR26/v1_semantic_contract_r26.jl",
        "test/GenomeV5/Integration/VNextT1FormalR26/path_guard_r26.jl",
        "test/GenomeV5/Integration/VNextT1FormalR26/v1_shard_r26.jl",
        "test/GenomeV5/Integration/VNextT1FormalR26/v2_formal_r26.jl",
        "test/GenomeV5/Integration/VNextT1FormalR26/binding_missing_wire_formal_r26.jl",
        "test/GenomeV5/Integration/VNextT1FormalR26/freeze_protocol_r26.jl",
    ]
    parsed = protocol["harness_parse_gate"]
    if [row["path"] for row in parsed] != active_julia or not all(
            row["parsed"] is True for row in parsed):
        raise RuntimeError("active Julia parse inventory mismatch")
    for row in parsed:
        if digest(ROOT / row["path"]) != {"bytes": row["bytes"],
                "sha256": row["sha256"]}:
            raise RuntimeError("active Julia parse hash drift: " + row["path"])
    for row in protocol["dependencies"]:
        if digest(ROOT / row["path"]) != {"bytes": row["bytes"], "sha256": row["sha256"]}:
            raise RuntimeError("dependency drift: " + row["path"])
    dependencies = {row["path"]: row for row in protocol["dependencies"]}
    resources = protocol["resources"]
    if resources != {"carrier_seconds": 10.0, "carrier_expected_bytes": 8269571,
            "package_integrator_seconds": 30.0,
            "reload_adapter_seconds": 30.0,
            "fresh_process_wall_seconds": 240.0,
            "process_tree_rss_bytes": 2 ** 31}:
        raise RuntimeError("resource contract mismatch")
    v1_carrier = protocol["v1"]["source_carrier_fixture"]
    if (v1_carrier["fixture"] != "first_actual_v1_t1_fixture_transport" or
            v1_carrier["fixture_source"] != protocol["v1"]["successor"]["path"] or
            v1_carrier["fixture_source_sha256"] !=
                protocol["v1"]["successor"]["sha256"] or
            v1_carrier["expected_bytes"] != 8269571 or
            v1_carrier["raw_sha256"] !=
                "1abdd43b057c6f6ba7dc020cf3c4a9239823cc2081f00583a405f7d0d91645f8" or
            v1_carrier["limit_seconds"] != 10.0 or
            v1_carrier["reference_manifest"] !=
                dependencies[v1_carrier["reference_manifest"]["path"]]):
        raise RuntimeError("V1 source carrier fixture contract mismatch")
    v2_carrier = protocol["v2"]["carrier_fixture"]
    if (v2_carrier["fixture"] != "original_v2_same_chain_fixture" or
            v2_carrier["fixture_source"] != protocol["v2"]["source"]["path"] or
            v2_carrier["fixture_source_sha256"] != protocol["v2"]["source"]["sha256"] or
            v2_carrier["expected_bytes"] != 8267526 or
            v2_carrier["wire_sha256"] !=
                "aed5b8f16b9a27c76fe5b098e1e52015d7b4090de1563915a02dcff413885e1a" or
            v2_carrier["reference_receipt"] !=
                dependencies[v2_carrier["reference_receipt"]["path"]] or
            v2_carrier["reference_artifact"] !=
                dependencies[v2_carrier["reference_artifact"]["path"]]):
        raise RuntimeError("V2 carrier fixture contract mismatch")
    targets = protocol["v1"]["targets"]
    ids = [row["id"] for row in targets]
    expected = ([f"r18v2-{i:03d}" for i in range(1, 64)] +
        [f"r26-extra-{i:03d}" for i in range(1, 8)])
    if ids != expected:
        raise RuntimeError("target inventory mismatch")
    expected_changed = ["r18v2-013", "r18v2-043", "r18v2-044",
        "r18v2-045", "r18v2-046", "r18v2-047", "r18v2-048",
        "r18v2-049"]
    if protocol["v1"]["changed_target_ids"] != expected_changed:
        raise RuntimeError("changed target inventory mismatch")
    target_043 = targets[42]
    if (target_043["id"] != "r18v2-043" or
            target_043["baseline_mapping_kind"] !=
                "preserve_current_semantic_obligation" or
            target_043["mapping_kind"] !=
                "strengthen_label_isolation_canonical_invariance"):
        raise RuntimeError("target 043 old-to-new mapping mismatch")
    shard_ids = [target for shard in protocol["v1"]["shards"] for target in shard["target_ids"]]
    if len(shard_ids) != 70 or set(shard_ids) != set(expected):
        raise RuntimeError("shard ownership mismatch")
    if len(shard_ids) != len(set(shard_ids)):
        raise RuntimeError("overlapping shard ownership")
    if protocol["v2"]["legacy_testset_count"] != 7 or len(protocol["v2"]["legacy_testsets"]) != 7:
        raise RuntimeError("V2 inventory mismatch")
    if protocol["binding"]["case_count"] != 16:
        raise RuntimeError("binding inventory mismatch")
    python_scripts = (HERE / "run_recorded_r26.py", HERE / "formal_controller_r26.py",
        HERE / "merge_r26.py", HERE / "static_qa_r26.py")
    for script in python_scripts:
        ast.parse(script.read_text(encoding="utf-8"), filename=str(script))
    active_protocol_users = (HERE / "v1_shard_r26.jl", HERE / "v2_formal_r26.jl",
        HERE / "binding_missing_wire_formal_r26.jl", HERE / "freeze_protocol_r26.jl",
        HERE / "formal_controller_r26.py", HERE / "merge_r26.py",
        HERE / "static_qa_r26.py")
    forbidden_protocol_names = tuple("protocol_r26_v" + value + ".json"
        for value in ("2", "3", "4", "5", "6", "7", "8"))
    forbidden_protocol_schemas = tuple(
        "vnext_t1_independent_formal_r26_protocol_v" + value
        for value in ("2", "3", "4", "5", "6", "7", "8"))
    for script in active_protocol_users:
        text = script.read_text(encoding="utf-8")
        if (any(value in text for value in forbidden_protocol_names) or
                any(value in text for value in forbidden_protocol_schemas)):
            raise RuntimeError("active v9 script retains old protocol reference: " + script.name)
    controller = (HERE / "formal_controller_r26.py").read_text(encoding="utf-8")
    merger = (HERE / "merge_r26.py").read_text(encoding="utf-8")
    for label in ("primary_r8", "replay_r8"):
        if label not in controller or label not in merger:
            raise RuntimeError("v9 round label missing: " + label)
    manifest = {"schema": "vnext_t1_independent_formal_r26_static_qa_v9",
        "verdict": "pass", "protocol": digest(protocol_path),
        "baseline_targets": 63, "successor_extras": 7,
        "exact_shard_partition": True, "v2_legacy_testsets": 7,
        "binding_cases": 16, "dependency_count": len(protocol["dependencies"]),
        "path_guard_cases": {"positive": 3, "negative": 5},
        "active_julia_parse_files": len(parsed),
        "round_runs": ["primary_r8", "replay_r8"],
        "formal_T1": False, "scientific_acceptance": False,
        "actual_model_attestation": "unavailable"}
    (out / "static_qa.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps(manifest), flush=True)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
