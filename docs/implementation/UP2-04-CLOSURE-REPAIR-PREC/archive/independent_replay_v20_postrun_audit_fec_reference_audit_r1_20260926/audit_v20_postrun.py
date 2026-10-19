import hashlib, json, sys
from pathlib import Path, PurePosixPath

ROOT = Path(r"D:\006-Programing\LMC\FusionConceptAI").resolve()
PROTO_REL = "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r20/replay_protocol_v20.json"
RUN_REL = "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r20/runtime_replay_r20"
EXPECTED_PROTOCOL_SHA = "26690948566c5191994e2d2ae3cbf94e7d9f481f8adf7e88962b128792d61dc2"
errors = []
counts = {}
def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()
def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))
def safe_path(rel):
    s = str(rel).replace("\\", "/")
    pp = PurePosixPath(s)
    if pp.is_absolute() or ".." in pp.parts:
        raise ValueError(f"unsafe relative path: {rel}")
    p = (ROOT / Path(*pp.parts)).resolve()
    p.relative_to(ROOT)
    return p
def check_pin(rel, expected_bytes, expected_sha, label):
    try:
        path = safe_path(rel)
        if not path.is_file():
            raise FileNotFoundError(str(path))
        size = path.stat().st_size
        sha = digest(path)
        counts[label] = counts.get(label, 0) + 1
        if expected_bytes is not None and size != int(expected_bytes):
            errors.append(f"bytes:{label}:{rel}:{size}!={expected_bytes}")
        if expected_sha is not None and sha != str(expected_sha).lower():
            errors.append(f"sha256:{label}:{rel}:{sha}!={expected_sha}")
        return {"path": str(rel), "bytes": size, "sha256": sha}
    except Exception as exc:
        errors.append(f"path:{label}:{rel}:{type(exc).__name__}:{exc}")
        return None

protocol_path = safe_path(PROTO_REL)
protocol_sha = digest(protocol_path)
if protocol_sha != EXPECTED_PROTOCOL_SHA:
    errors.append(f"protocol_sha:{protocol_sha}!={EXPECTED_PROTOCOL_SHA}")
p = read_json(protocol_path)
run = safe_path(RUN_REL)
final_path = run / "final.json"
final = read_json(final_path)
process_path = run / "producer_process.json"
process = read_json(process_path)
checks = []
for pin in p["owned_source_files"]:
    checks.append(check_pin(pin["path"], pin["bytes"], pin["sha256"], "v20_owned_source"))

# Rehash both 725-entry runtime snapshots against the live workspace.
before_path, after_path = run / "inputs_before.json", run / "inputs_after.json"
before, after = read_json(before_path), read_json(after_path)
if len(before) != 725 or len(after) != 725:
    errors.append(f"snapshot_count:{len(before)}:{len(after)}")
if before != after:
    errors.append("inputs_before_after_mismatch")
input_snapshot_checks = 0
for pin in before:
    if check_pin(pin["path"], pin["bytes"], pin["sha256"], "runtime_725_input") is not None:
        input_snapshot_checks += 1
proc_after = read_json(run / "producer_process" / "inputs_after.json")
if proc_after != after:
    errors.append("producer_inputs_after_differs_from_controller_after")

# Recheck each named frozen input set.
v10_stage_ref = p["v10_protocol"]
v10_stage_path = safe_path(v10_stage_ref["path"])
check_pin(v10_stage_ref["path"], v10_stage_path.stat().st_size, v10_stage_ref["sha256"], "v10_staged_protocol")
v10_stage = read_json(v10_stage_path)
if len(v10_stage["inputs"]) != 89 or len(v10_stage["inputs"]) != v10_stage_ref["pinned_input_count"]:
    errors.append(f"v10_staged_input_count:{len(v10_stage['inputs'])}")
for pin in v10_stage["inputs"]:
    check_pin(pin["path"], pin["bytes"], pin["sha256"], "v10_staged_input_89")
for name, pin in p["replay_inputs"].items():
    check_pin(pin["path"], pin["bytes"], pin["sha256"], f"v20_replay_input_{name}")
for pin in p["saved_producer_tree"]["entries"]:
    check_pin(pin["path"], pin["bytes"], pin["sha256"], "saved_producer_tree_119")

# Verify the executed child matches the frozen entrypoint and protocol; bind raw process logs.
stage = final["stages"][0] if final.get("stages") else {}
cmd = process.get("command", [])
if len(final.get("stages", [])) != 1 or stage.get("stage") != "producer":
    errors.append("unexpected_stage_sequence")
if cmd[3] != p["entrypoint"] or cmd[7] != EXPECTED_PROTOCOL_SHA:
    errors.append(f"command_pin_mismatch:{cmd}")
if any(stage.get(k) != v for k, v in process.items() if k != "stage"):
    errors.append("final_stage_vs_producer_process_mismatch")
for stream in ("stdout", "stderr"):
    ref = process[stream]
    raw_path = safe_path(str(Path(RUN_REL) / "producer_process" / f"{stream}.raw").replace("\\", "/"))
    if raw_path.stat().st_size != ref["bytes"] or digest(raw_path) != ref["sha256"]:
        errors.append(f"raw_{stream}_receipt_mismatch")

# Bind terminal and cleanup semantics without treating empty lists as proof of cleanup.
cleanup = process.get("cleanup", {})
no_such = [e for e in cleanup.get("termination_verification_errors", []) if e.get("stage") == "root_process_lookup" and e.get("error_type") == "NoSuchProcess" and e.get("pid") == 80036]
rss_errors = process.get("rss_observation_errors", [])
if (final.get("controller_exit_code"), final.get("classification")) != (124, "resource_interruption"):
    errors.append("outer_resource_classification_mismatch")
if (process.get("exit_code"), process.get("stop_reason")) != (1, "cleanup_unconfirmed"):
    errors.append("child_exit_or_stop_mismatch")
if (process.get("pid"), process.get("root_process_identity")) != (80036, {"pid": 80036, "create_time": 1790353289.44393}):
    errors.append("root_process_identity_mismatch")
if not no_such or cleanup.get("termination_confirmed") is not False or cleanup.get("termination_wait_succeeded") is not False or cleanup.get("process_tree_inventory_complete") is not False:
    errors.append("cleanup_unconfirmed_evidence_mismatch")
if process.get("rss_complete_sample_count") != 934 or process.get("rss_sampling_complete") is not False or not rss_errors:
    errors.append("rss_incomplete_evidence_mismatch")
if process.get("peak_sampled_process_tree_working_set_bytes") != 1152794624:
    errors.append("peak_rss_mismatch")
if process.get("child_wall_seconds", 0) >= 480 or process.get("peak_sampled_process_tree_working_set_bytes", 0) >= 2147483648:
    errors.append("reported_measured_resource_limit_exceeded")
if final.get("inputs_unchanged") is not True or final.get("producer_tree_comparison_status") != "not_reached" or final.get("producer_tree_unchanged") is not None:
    errors.append("input_or_tree_comparison_status_mismatch")
if final.get("aggregate_child_wall_budget", {}).get("limit_status") != "cleanup_unconfirmed" or final.get("aggregate_child_wall_budget", {}).get("unconfirmed_cleanup_stages") != ["producer"]:
    errors.append("aggregate_cleanup_status_mismatch")
if final.get("controller_overhead_budget", {}).get("limit_status") != "within_limit":
    errors.append("controller_overhead_status_mismatch")

# The Julia error is a separate failure: producer hydration returned, then the preserved state identity gate failed.
stderr = (run / "producer_process" / "stderr.raw").read_text(encoding="utf-8", errors="replace")
if "saved result state hash differs from protocol" not in stderr or "replay_staged_v20.jl:850" not in stderr:
    errors.append("saved_state_hash_exception_signature_missing")
source = safe_path(p["entrypoint"]).read_text(encoding="utf-8")
source_lines = source.splitlines()
if "string(c.state_hash) == String(protocol.preserved_identity.state_after_hash)" not in source_lines[849]:
    errors.append("state_hash_guard_source_pin_mismatch")
if not (next((i for i, line in enumerate(source_lines) if 'phase_path = joinpath(out, "producer_full_validator.json")' in line), -1) > 849):
    errors.append("validator_not_after_state_hash_guard")
runner_source = safe_path("test/RuntimeV4/UP2ClosureReplayOnlyV20/run_replay_staged_v20.py").read_text(encoding="utf-8")
resource_branch_index = runner_source.find('resource_exit = resource_interruption_exit_code(str(producer["stop_reason"]))')
resource_class_index = runner_source.find('classification = "resource_interruption"', resource_branch_index)
typed_failure_index = runner_source.find('elif failure and failure.get("classification") == "replay_hydration_unsupported":', resource_branch_index)
program_failure_index = runner_source.find('classification = "program_exception"', typed_failure_index)
if min(resource_branch_index, resource_class_index, typed_failure_index, program_failure_index) < 0 or not (resource_branch_index < resource_class_index < typed_failure_index < program_failure_index):
    errors.append("resource_vs_program_classification_order_mismatch")
phase_dir = run / "producer_process" / "numerical" / "hydration_phases"
phases = []
for path in sorted(phase_dir.glob("*.json")):
    d = read_json(path)
    phases.append({"file": path.name, "phase": d.get("phase"), "completed": d.get("completed"), "result_hash": d.get("result_hash")})
if len(phases) != 7 or not all(x["completed"] is True for x in phases):
    errors.append("hydration_phase_receipts_incomplete")
initial = read_json(run / "producer_process" / "numerical" / "hydration_observation_initial.json")
reconstructed = read_json(run / "producer_process" / "numerical" / "hydration_observation_reconstruction.json")
if (len(initial.get("representation_differences", [])), len(initial.get("numeric_type_differences", [])), len(initial.get("semantic_differences", [])), len(initial.get("mismatch_roots", []))) != (750, 153, 0, 3):
    errors.append("initial_observation_counts_mismatch")
if (len(reconstructed.get("reconstruction_paths", [])), len(reconstructed.get("representation_differences", [])), len(reconstructed.get("numeric_type_differences", [])), len(reconstructed.get("semantic_differences", [])), len(reconstructed.get("mismatch_roots", []))) != (153, 110, 0, 0, 0):
    errors.append("reconstruction_observation_counts_mismatch")

for absent in ("consumer_process", "consumer_process.json", "producer_validator_started.json", "producer_validator_completed.json", "producer_full_validator.json", "producer_complete.json", "consumer_complete.json"):
    if (run / absent).exists():
        errors.append(f"unexpected_post_failure_artifact:{absent}")
if final.get("solver_exit_code") != 2 or final.get("numerical_status") != "fail" or final.get("stopping_reason") != "stationary_nonzero_residual" or final.get("authority") != "no_publish" or final.get("physical_validation") != "unsupported" or final.get("nonlinear_solves") != 0:
    errors.append("preserved_v10_numerical_lineage_mismatch")

# Distinguish the final-vector hash from the case metadata-bound state hash.
numerical = read_json(safe_path(p["replay_inputs"]["numerical_result"]["path"]))
case = numerical["cases"][0]
v10_ref = p["parent_v10_actual_replay_failure"]["protocol"]
v10_actual_protocol_path = safe_path(v10_ref["path"])
check_pin(v10_ref["path"], v10_actual_protocol_path.stat().st_size, v10_ref["sha256"], "v10_actual_replay_protocol")
v10_actual_protocol = read_json(v10_actual_protocol_path)
attempt_ref = case["artifacts"]["attempts"]
attempt_path = Path(attempt_ref["path"]).resolve()
attempt_path.relative_to(ROOT)
attempts = read_json(attempt_path)
attempt_sha = digest(attempt_path)
if attempt_sha != attempt_ref["sha256"]["value"]:
    errors.append("solver_attempt_artifact_hash_mismatch")
expected_vector_hash = p["preserved_identity"]["state_after_hash"]
recorded_vector_hash = attempts["last_attempt"]["state_after_hash"]["value"]
case_metadata_hash = case["state_hash"]["value"]
v10_protocol_vector_hash = v10_actual_protocol["preserved_identity"]["state_after_hash"]
if expected_vector_hash != recorded_vector_hash or expected_vector_hash != v10_protocol_vector_hash or expected_vector_hash == case_metadata_hash:
    errors.append("state_hash_definition_crosscheck_mismatch")
multi_source = safe_path("src/RuntimeV4/SpatialMultiRegionV4.jl").read_text(encoding="utf-8").splitlines()
if ("state_after_hash=canonical_hash(Tuple(x))" not in multi_source[650] or
        "statehash=canonical_hash((candidate_hash=context.candidate_hash,context_hash=context.context_hash,case_id=case.case_id,level=case.level,flux_Wb=case.flux_Wb,state=sol.final_state))" not in multi_source[833] or
        "initial_state=sol.initial_state,final_state=sol.final_state,state_hash=statehash" not in multi_source[902] or
        "c.state_hash==statehash||error(\"spatial solved state mismatch\")" not in multi_source[1167]):
    errors.append("state_hash_source_definitions_mismatch")

runtime_inventory = []
for path in sorted(x for x in run.rglob("*") if x.is_file()):
    runtime_inventory.append({"path": path.relative_to(run).as_posix(), "bytes": path.stat().st_size, "sha256": digest(path)})
result = {
    "schema": "independent_up2_v20_postrun_audit_v1",
    "protocol": {"path": PROTO_REL, "sha256": protocol_sha, "expected_sha256": EXPECTED_PROTOCOL_SHA},
    "pins": {"checks_by_label": counts, "check_count": sum(counts.values()), "error_count": len(errors), "errors": errors,
             "input_snapshot_count": len(before), "input_snapshot_equal": before == after, "input_snapshot_current_matches": input_snapshot_checks},
    "execution": {"controller_exit": final.get("controller_exit_code"), "classification": final.get("classification"),
                  "child_stage": stage.get("stage"), "child_exit": process.get("exit_code"), "child_stop_reason": process.get("stop_reason"),
                  "child_command": cmd,
                  "child_wall_seconds": process.get("child_wall_seconds"), "controller_elapsed_seconds": final.get("elapsed_seconds"),
                  "controller_overhead": final.get("controller_overhead_budget"), "aggregate_child_wall": final.get("aggregate_child_wall_budget"),
                  "rss_complete_samples": process.get("rss_complete_sample_count"), "rss_sampling_complete": process.get("rss_sampling_complete"),
                  "peak_sampled_rss_bytes": process.get("peak_sampled_process_tree_working_set_bytes"), "cleanup": cleanup,
                  "no_such_process_errors": no_such, "rss_observation_errors": rss_errors},
    "underlying_julia_failure": {"kind": "saved_result_state_hash_mismatch", "signature": "saved result state hash differs from protocol",
                                  "source_path": p["entrypoint"], "source_line": 850, "stderr_sha256": process["stderr"]["sha256"],
                                  "occurs_after_completed_hydration_phases": phases[-1]["phase"] if phases else None,
                                  "validator_gate_line": 859, "validator_gate_after_failure": True,
                                  "controller_classification_order": {"resource_branch_precedes_replay_hydration_and_program_exception": True,
                                      "resource_branch_source_line": 3945, "typed_hydration_classification_source_line": 3949,
                                      "program_exception_classification_source_line": 3953},
                                  "hash_definition_crosscheck": {"protocol_state_after_hash": expected_vector_hash,
                                      "v10_actual_replay_protocol_state_after_hash": v10_protocol_vector_hash,
                                      "last_solver_attempt_state_after_hash": recorded_vector_hash,
                                      "attempt_file_sha256": attempt_sha,
                                      "case_metadata_state_hash": case_metadata_hash,
                                      "case_final_state_count": len(case["final_state"]),
                                      "vector_hash_formula_source_line": 651,
                                      "case_metadata_hash_formula_source_line": 834,
                                      "case_state_hash_assignment_source_line": 903,
                                      "authoritative_case_recheck_source_line": 1167},
                                  "initial_observation_counts": {"representation": 750, "numeric_type": 153, "semantic": 0, "mismatch_roots": 3},
                                  "after_reconstruction_counts": {"reconstruction_paths": 153, "representation": 110, "numeric_type": 0, "semantic": 0, "mismatch_roots": 0}},
    "final_status": {"solver_exit": final.get("solver_exit_code"), "numerical_status": final.get("numerical_status"),
                     "stopping_reason": final.get("stopping_reason"), "authority": final.get("authority"),
                     "physical_validation": final.get("physical_validation"), "inputs_unchanged": final.get("inputs_unchanged"),
                     "producer_tree_comparison_status": final.get("producer_tree_comparison_status"),
                     "producer_tree_unchanged": final.get("producer_tree_unchanged"), "nonlinear_solves": final.get("nonlinear_solves"),
                     "stages": [x.get("stage") for x in final.get("stages", [])], "consumer_or_validator_artifacts": False},
    "runtime_inventory": runtime_inventory,
}
print(json.dumps(result, sort_keys=True, separators=(",", ":")))
sys.exit(1 if errors else 0)
