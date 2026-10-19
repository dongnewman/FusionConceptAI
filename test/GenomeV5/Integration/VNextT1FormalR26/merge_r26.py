"""Strict single-run and two-run replay merger for independent T1 R26."""

from __future__ import annotations
from pathlib import Path
import argparse, hashlib, json

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
EVIDENCE = ROOT / "docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922"
PROTOCOL_PATH = HERE / "protocol_r26_v9.json"
ROUND_RUNS = ("primary_r8", "replay_r8")

def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))

def digest(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest().upper()}

def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)

def write_new(path: Path, value) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2)

def validate_recorded(stage_dir: Path, protocol: dict) -> dict:
    start, final = load(stage_dir / "start.json"), load(stage_dir / "final.json")
    protocol_rel = PROTOCOL_PATH.relative_to(ROOT).as_posix()
    expected_inputs = {row["path"]: {"bytes": row["bytes"], "sha256": row["sha256"]}
        for row in protocol["dependencies"]}
    expected_inputs[protocol_rel] = digest(PROTOCOL_PATH)
    require(final["exit_code"] == 0, f"nonzero child: {stage_dir.name}")
    require(final["stop_reason"] == "natural_exit", f"unnatural stop: {stage_dir.name}")
    require(final["elapsed_seconds"] <= protocol["resources"]["fresh_process_wall_seconds"],
        f"wall ceiling: {stage_dir.name}")
    require(final["peak_process_tree_rss_bytes"] < protocol["resources"]["process_tree_rss_bytes"],
        f"RSS ceiling: {stage_dir.name}")
    require(start["timeout_seconds"] == protocol["resources"]["fresh_process_wall_seconds"],
        f"timeout mismatch: {stage_dir.name}")
    require(start["working_set_limit_bytes"] == protocol["resources"]["process_tree_rss_bytes"],
        f"RSS config mismatch: {stage_dir.name}")
    require(start["environment"] == {"JULIA_NUM_THREADS": "1"},
        f"environment mismatch: {stage_dir.name}")
    require(final["input_changes"] == [], f"input drift: {stage_dir.name}")
    require(final["new_or_residual_heavy_processes"] == [], f"residual process: {stage_dir.name}")
    require(final["inputs_before"] == final["inputs_after"], f"input snapshots differ: {stage_dir.name}")
    require(start["inputs_before"] == expected_inputs, f"start inputs not protocol-exact: {stage_dir.name}")
    require(final["inputs_before"] == expected_inputs, f"final inputs not protocol-exact: {stage_dir.name}")
    require(final["stdout"] == digest(stage_dir / "stdout.raw"), f"stdout hash mismatch: {stage_dir.name}")
    require(final["stderr"] == digest(stage_dir / "stderr.raw"), f"stderr hash mismatch: {stage_dir.name}")
    require(final["stderr"]["bytes"] == 0, f"stderr nonempty: {stage_dir.name}")
    require(final["actual_model_attestation"] == "unavailable", "model attestation drift")
    return {"start": start, "final": final}

def single(run: str) -> dict:
    protocol = load(PROTOCOL_PATH)
    require(protocol["schema"] == "vnext_t1_independent_formal_r26_protocol_v9",
        "protocol schema mismatch")
    require(run in ROUND_RUNS, "run label outside v9 round")
    dependency_rows = {row["path"]: row for row in protocol["dependencies"]}
    v1_carrier_spec = protocol["v1"]["source_carrier_fixture"]
    v2_carrier_spec = protocol["v2"]["carrier_fixture"]
    require(protocol["resources"]["carrier_expected_bytes"] ==
        v1_carrier_spec["expected_bytes"] == 8269571,
        "V1 carrier frozen byte identity")
    require(v1_carrier_spec["raw_sha256"] ==
        "1abdd43b057c6f6ba7dc020cf3c4a9239823cc2081f00583a405f7d0d91645f8",
        "V1 carrier frozen SHA identity")
    require(v1_carrier_spec["fixture_source_sha256"] ==
        protocol["v1"]["successor"]["sha256"], "V1 carrier fixture source")
    require(v1_carrier_spec["reference_manifest"] ==
        dependency_rows[v1_carrier_spec["reference_manifest"]["path"]],
        "V1 carrier reference pin")
    require(v2_carrier_spec["expected_bytes"] == 8267526 and
        v2_carrier_spec["wire_sha256"] ==
            "aed5b8f16b9a27c76fe5b098e1e52015d7b4090de1563915a02dcff413885e1a",
        "V2 carrier frozen identity")
    require(v2_carrier_spec["fixture_source"] == protocol["v2"]["source"]["path"] and
        v2_carrier_spec["fixture_source_sha256"] ==
            protocol["v2"]["source"]["sha256"], "V2 carrier fixture source")
    require(v2_carrier_spec["reference_receipt"] ==
        dependency_rows[v2_carrier_spec["reference_receipt"]["path"]],
        "V2 carrier receipt pin")
    require(v2_carrier_spec["reference_artifact"] ==
        dependency_rows[v2_carrier_spec["reference_artifact"]["path"]],
        "V2 carrier artifact pin")
    protocol_hash = digest(PROTOCOL_PATH)["sha256"]
    run_dir = EVIDENCE / run
    require(run_dir.is_dir(), "missing run directory")
    expected_ids = [f"r18v2-{i:03d}" for i in range(1, 64)] + [f"r26-extra-{i:03d}" for i in range(1, 8)]
    expected_shards = ["v1_" + row["name"] for row in protocol["v1"]["shards"]]
    shard_protocol = {"v1_" + row["name"]: row for row in protocol["v1"]["shards"]}
    stage_names = expected_shards + ["v2_formal", "binding_formal"]
    observed_dirs = sorted(path.name for path in run_dir.iterdir() if path.is_dir())
    require(observed_dirs == sorted(stage_names), "unknown or missing stage directory")
    recorded, v1_rows = {}, []
    expected_deps = {row["path"]: {"bytes": row["bytes"], "sha256": row["sha256"]}
        for row in protocol["dependencies"]}
    for name in stage_names:
        stage_dir = run_dir / name
        recorded[name] = validate_recorded(stage_dir, protocol)
        ledger = load(stage_dir / "ledger.json")
        require(ledger["protocol_sha256"] == protocol_hash, f"protocol mismatch: {name}")
        if name.startswith("v1_"):
            require(ledger["schema"] == "vnext_t1_v1_shard_r26_ledger_v2", "V1 ledger schema")
            require(ledger["target_ownership_exact"] is True, "V1 target ownership")
            require(ledger["dependencies_unchanged"] is True, "V1 dependency drift")
            require(ledger["dependencies_before"] == expected_deps and
                ledger["dependencies_after"] == expected_deps, "V1 ledger dependency binding")
            require(ledger["source_sha256"] == protocol["v1"]["successor"]["sha256"],
                "V1 source hash")
            require(ledger["selected_target_ids"] == shard_protocol[name]["target_ids"],
                "V1 shard protocol ownership")
            require(ledger["include_wall_gate_pass"] is True, "V1 wall gate")
            require(ledger["include_wall_limit_seconds"] == shard_protocol[name]["max_wall_seconds"],
                "V1 wall limit mismatch")
            require(ledger["include_wall_elapsed_seconds"] <= shard_protocol[name]["max_wall_seconds"],
                "V1 wall elapsed mismatch")
            require(set(ledger["runtime_target_ids"]) == set(ledger["selected_target_ids"]), "V1 runtime IDs")
            require(set(ledger["runtime_multiplicity"]) == set(ledger["selected_target_ids"]), "V1 multiplicity keys")
            require(all(value > 0 for value in ledger["runtime_multiplicity"].values()), "V1 zero hit")
            carrier_resource = ledger["source_carrier_resource"]
            if name == "v1_contract":
                spec = protocol["v1"]["source_carrier_fixture"]
                require(carrier_resource["schema"] ==
                    "vnext_t1_v1_source_carrier_resource_r26_v1", "V1 carrier schema")
                require(carrier_resource["first_call_count"] == 1,
                    "V1 carrier call count")
                require(carrier_resource["operation"] == spec["operation"] and
                    carrier_resource["fixture"] == spec["fixture"],
                    "V1 carrier operation identity")
                require(carrier_resource["expected_bytes"] == spec["expected_bytes"] ==
                    protocol["resources"]["carrier_expected_bytes"],
                    "V1 carrier expected bytes")
                require(carrier_resource["actual_bytes"] == spec["expected_bytes"] and
                    carrier_resource["carrier_bytes"] == spec["expected_bytes"],
                    "V1 carrier actual bytes")
                require(carrier_resource["expected_raw_sha256"] == spec["raw_sha256"] and
                    carrier_resource["raw_sha256"] == spec["raw_sha256"] and
                    carrier_resource["carrier_sha256"] == spec["raw_sha256"],
                    "V1 carrier SHA join")
                require(carrier_resource["limit_seconds"] == spec["limit_seconds"] ==
                    protocol["resources"]["carrier_seconds"],
                    "V1 carrier limit")
                require(0 <= carrier_resource["cold_seconds"] <= spec["limit_seconds"] and
                    carrier_resource["canonical_seconds"] >= 0,
                    "V1 carrier elapsed")
                require(carrier_resource["carrier_type"] ==
                    "FusionConceptAI.VNextT1CanonicalBytesV2",
                    "V1 carrier type")
                require(carrier_resource["exact_byte_join"] is True and
                    carrier_resource["gate_pass"] is True, "V1 carrier gate")
            else:
                require(carrier_resource is None,
                    "V1 carrier resource ran outside contract shard")
            v1_rows.append(ledger)
        elif name == "v2_formal":
            require(ledger["schema"] == "vnext_t1_v2_formal_r26_ledger_v3", "V2 ledger schema")
            require(ledger["legacy_testset_count"] == 7, "V2 legacy count")
            require([{key: row[key] for key in ("title", "ast_sha256")}
                for row in ledger["legacy_testsets"]] == protocol["v2"]["legacy_testsets"],
                "V2 testset AST inventory")
            require(all(row["default_source_ast_sha256"] == row["ast_sha256"]
                for row in ledger["legacy_testsets"]),
                "V2 default-source raw AST mismatch")
            require(all(row["context_match"] is True and
                row["filename_context_ast_sha256"] == row["captured_ast_sha256"]
                for row in ledger["legacy_testsets"]),
                "V2 include-context raw AST mismatch")
            require(all(row["filename_context_line_files"] == row["captured_line_files"]
                for row in ledger["legacy_testsets"]),
                "V2 include-context line metadata mismatch")
            require(ledger["source_sha256"] == protocol["v2"]["source"]["sha256"],
                "V2 source hash")
            require(all(row["status"] == "pass" for row in ledger["legacy_testsets"]), "V2 legacy failure")
            require(ledger["historical_writer_suppressions"] == 2, "V2 writer suppression")
            require(ledger["carrier_gate_pass"] is True, "carrier gate")
            v2_carrier = protocol["v2"]["carrier_fixture"]
            require(ledger["carrier_expected_bytes"] == v2_carrier["expected_bytes"],
                "V2 carrier bytes config")
            require(ledger["carrier_expected_sha256"] == v2_carrier["wire_sha256"],
                "V2 carrier SHA config")
            require(ledger["wire_bytes"] == v2_carrier["expected_bytes"],
                "V2 carrier bytes actual")
            require(ledger["wire_sha256"] == v2_carrier["wire_sha256"],
                "V2 carrier SHA actual")
            require(ledger["carrier_limit_seconds"] == protocol["resources"]["carrier_seconds"], "carrier limit")
            require(ledger["carrier_seconds"] <= protocol["resources"]["carrier_seconds"], "carrier elapsed")
            require(ledger["package_integrator_gate_pass"] is True, "package gate")
            require(ledger["package_integrator_limit_seconds"] == protocol["resources"]["package_integrator_seconds"], "package limit")
            require(ledger["package_integrator_seconds"] <= protocol["resources"]["package_integrator_seconds"], "package elapsed")
            require(ledger["reload_adapter_gate_pass"] is True, "reload gate")
            require(ledger["reload_adapter_limit_seconds"] == protocol["resources"]["reload_adapter_seconds"], "reload limit")
            require(ledger["reload_adapter_seconds"] <= protocol["resources"]["reload_adapter_seconds"], "reload elapsed")
            require(ledger["dependencies_unchanged"] is True and ledger["inputs_unchanged"] is True, "V2 mutation")
            require(ledger["dependencies_before"] == expected_deps and
                ledger["dependencies_after"] == expected_deps, "V2 ledger dependency binding")
            v2 = ledger
        else:
            require(ledger["schema"] == "vnext_t1_binding_cross_product_r26_ledger_v1", "binding ledger schema")
            require(ledger["case_count"] == 16, "binding case count")
            require(ledger["dependencies_unchanged"] is True, "binding dependency drift")
            require(ledger["dependencies_before"] == expected_deps and
                ledger["dependencies_after"] == expected_deps, "binding ledger dependency binding")
            require(all(row["receipt_hash_matches"] for row in ledger["results"]), "binding receipt hash")
            binding = ledger
    owned = [target for row in v1_rows for target in row["selected_target_ids"]]
    require(owned == expected_ids, "ordered target ownership mismatch")
    require(len(owned) == len(set(owned)) == 70, "duplicate target ownership")
    contract_carrier = next(row["source_carrier_resource"] for row in v1_rows
        if row["shard"] == "contract")
    stable = {"protocol_sha256": protocol_hash,
        "dependencies": protocol["dependencies"],
        "v1": [{"shard": row["shard"], "selected_target_ids": row["selected_target_ids"],
            "runtime_multiplicity": row["runtime_multiplicity"],
            "source_sha256": row["source_sha256"]} for row in v1_rows],
        "v1_source_carrier": {key: contract_carrier[key] for key in
            ("operation", "fixture", "actual_bytes", "raw_sha256", "carrier_bytes",
             "carrier_sha256", "carrier_type", "exact_byte_join")},
        "v2": {key: v2[key] for key in ("source_sha256", "legacy_testsets", "wire_bytes",
            "wire_sha256", "bundle_hash", "semantic_identity", "package_hash",
            "serialized_package_bytes")},
        "binding": {"case_count": binding["case_count"], "results": binding["results"]}}
    manifest = {"schema": "vnext_t1_independent_formal_r26_single_merge_v8",
        "round": "r8", "run": run, "verdict": "pass",
        "protocol": digest(PROTOCOL_PATH),
        "target_count": 70, "baseline_target_count": 63, "extra_target_count": 7,
        "v2_legacy_testset_count": 7, "binding_case_count": 16,
        "stages": {name: {"elapsed_seconds": recorded[name]["final"]["elapsed_seconds"],
            "peak_process_tree_rss_bytes": recorded[name]["final"]["peak_process_tree_rss_bytes"],
            "stdout": recorded[name]["final"]["stdout"], "stderr": recorded[name]["final"]["stderr"]}
            for name in stage_names}, "stable_replay_projection": stable,
        "child_identities": {name: {"pid": recorded[name]["start"]["pid"],
            "process_create_time": recorded[name]["start"]["process_create_time"],
            "started_utc": recorded[name]["start"]["started_utc"]} for name in stage_names},
        "formal_T1": False, "scientific_acceptance": False,
        "actual_model_attestation": "unavailable"}
    write_new(run_dir / "single_merge.json", manifest)
    print(json.dumps(manifest), flush=True)
    return manifest

def replay(primary: str, replay_run: str, out_rel: str) -> dict:
    require((primary, replay_run) == ROUND_RUNS,
        "v9 replay requires primary_r8 followed by replay_r8")
    p_path = EVIDENCE / primary / "single_merge.json"
    r_path = EVIDENCE / replay_run / "single_merge.json"
    require(p_path.is_file() and r_path.is_file(), "single merge missing")
    p, r = load(p_path), load(r_path)
    require((EVIDENCE / primary).resolve() != (EVIDENCE / replay_run).resolve(),
        "primary and replay directories must differ")
    require(p["schema"] == r["schema"] ==
        "vnext_t1_independent_formal_r26_single_merge_v8", "single schema mismatch")
    require(p["round"] == r["round"] == "r8", "single round mismatch")
    require(p["run"] == primary and r["run"] == replay_run, "single run label mismatch")
    current_protocol = digest(PROTOCOL_PATH)
    require(p["protocol"] == r["protocol"] == current_protocol,
        "single manifests are not bound to current v9 protocol")
    require(p["verdict"] == r["verdict"] == "pass", "single run not pass")
    require(p["stable_replay_projection"] == r["stable_replay_projection"], "replay projection mismatch")
    require(set(p["child_identities"]) == set(r["child_identities"]), "child stage mismatch")
    require(all(p["child_identities"][name] != r["child_identities"][name]
        for name in p["child_identities"]), "replay reused a child identity")
    rel = Path(out_rel)
    require(not rel.is_absolute() and ".." not in rel.parts, "invalid replay output")
    out = (ROOT / rel).resolve(); out.relative_to(EVIDENCE)
    require(out == (EVIDENCE / "replay_r8" / "cross_merge.json").resolve(),
        "v9 replay output must be replay_r8/cross_merge.json")
    manifest = {"schema": "vnext_t1_independent_formal_r26_replay_merge_v8",
        "round": "r8", "verdict": "pass", "primary": primary,
        "replay": replay_run,
        "primary_manifest": digest(p_path), "replay_manifest": digest(r_path),
        "protocol_sha256": p["protocol"]["sha256"], "same_protocol": True,
        "same_dependencies": True, "same_target_inventory": True,
        "same_runtime_multiplicity": True, "same_v2_identities": True,
        "same_binding_receipts": True, "formal_T1": False,
        "scientific_acceptance": False, "actual_model_attestation": "unavailable"}
    write_new(out, manifest)
    print(json.dumps(manifest), flush=True)
    return manifest

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", required=True, choices=("single", "replay"))
    parser.add_argument("--run")
    parser.add_argument("--primary")
    parser.add_argument("--replay")
    parser.add_argument("--out")
    args = parser.parse_args()
    if args.mode == "single":
        require(args.run in ROUND_RUNS, "invalid v9 single run")
        single(args.run)
    else:
        require(args.primary and args.replay and args.out, "replay arguments required")
        replay(args.primary, args.replay, args.out)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
