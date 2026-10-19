from __future__ import annotations

import ast
import hashlib
import importlib.util
import json
import pathlib
import sys


ROOT = pathlib.Path.cwd().resolve()
PROTOCOL_REL = pathlib.Path(
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_continuation_r13/replay_protocol_v13.json"
)
OWNER_LEAF_REL = pathlib.Path(
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_continuation_r13/static_contract_check_v13_r1"
)
OWNER_RECEIPT_SHA = "0abe14b104fb862c520258443b17f8b7ba54c89212165af91c98dac32b78f19c"
PROTOCOL_SHA = "49af413f03d106d94fd830a98d489adf876d9d039f590e9115b4f0b9ec41b2ee"
RUNNER_REL = pathlib.Path("test/RuntimeV4/UP2ClosureReplayOnlyV13/run_replay_staged_v13.py")
JULIA_REL = pathlib.Path("test/RuntimeV4/UP2ClosureReplayOnlyV13/replay_staged_v13.jl")
TEST_REL = pathlib.Path("test/RuntimeV4/UP2ClosureReplayOnlyV13/test_contract_v13.py")
V10_REL = pathlib.Path(
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/agent_r2_n1_20260922/"
    "manufactured_candidate_v1/protocol_staged_v10.json"
)
HELPER_REL = pathlib.Path("test/RuntimeV4/UP2ClosureRepairV1/manufactured_candidate_v1_tests.jl")
OUTPUT_REL = pathlib.Path(
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_continuation_r13/runtime_replay_r13"
)


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: pathlib.Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def load_runner():
    path = ROOT / RUNNER_REL
    spec = importlib.util.spec_from_file_location("independent_v13_static_review_runner", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot import the frozen V13 controller")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check_package(protocol: dict, runner, owner_leaf: pathlib.Path) -> dict:
    protocol_path = ROOT / PROTOCOL_REL
    assert sha(protocol_path) == PROTOCOL_SHA
    receipt_path = owner_leaf / "receipt.json"
    assert sha(receipt_path) == OWNER_RECEIPT_SHA
    receipt = load_json(receipt_path)
    assert receipt["protocol"]["sha256"] == PROTOCOL_SHA
    assert receipt["command"]["tests_run"] == 21
    assert receipt["command"]["tests_passed"] == 21
    assert receipt["command"]["exit_code"] == 0
    assert receipt["runtime_boundary"]["julia_started"] is False
    assert receipt["runtime_boundary"]["producer_started"] is False
    assert receipt["runtime_boundary"]["consumer_started"] is False
    assert receipt["runtime_boundary"]["scientific_credit"] is False
    assert receipt["classification"] == "STATIC_TESTS_PASS_RUNTIME_NOT_GRANTED"

    sums = {}
    for line in (owner_leaf / "SHA256SUMS.txt").read_text(encoding="ascii").splitlines():
        expected, name = line.split("  ", 1)
        sums[name] = expected
    assert set(sums) == {p.name for p in owner_leaf.iterdir() if p.is_file() and p.name != "SHA256SUMS.txt"}
    for name, expected in sums.items():
        assert sha(owner_leaf / name) == expected, f"owner evidence checksum mismatch: {name}"

    v10 = load_json(ROOT / V10_REL)
    pins = v10["inputs"]
    assert len(pins) == 89
    assert protocol["v10_protocol"]["pinned_input_count"] == 89
    for item in pins:
        path = ROOT / pathlib.PurePosixPath(item["path"])
        assert path.is_file() and path.stat().st_size == item["bytes"] and sha(path) == item["sha256"], item["path"]
    for item in v10["source_pins"]:
        path = ROOT / pathlib.PurePosixPath(item["path"])
        assert path.is_file() and path.stat().st_size == item["bytes"] and sha(path) == item["sha256"], item["path"]

    tree = protocol["saved_producer_tree"]
    tree_root = ROOT / pathlib.PurePosixPath(tree["root"])
    actual_tree = runner.file_inventory(tree_root)
    assert actual_tree == tree["entries"]
    assert len(actual_tree) == 119 == tree["file_count"]
    assert sum(item["bytes"] for item in actual_tree) == tree["bytes"] == 6_590_185
    assert hashlib.sha256(runner.canonical_bytes(actual_tree)).hexdigest() == tree["sha256"]

    assert protocol["stage_limits"] == {"memory_measurement": protocol["stage_limits"]["memory_measurement"],
                                         "seconds": 480, "working_set_bytes": 2**31}
    assert protocol["total_child_wall_limit_seconds"] == 960
    assert protocol["controller_overhead_seconds_limit"] == 120
    assert protocol["termination_cleanup_grace_seconds"] == 6
    assert protocol["aggregate_child_wall_contract"]["poll_interval_seconds"] == 0.25
    assert v10["numerical_gates"]["residual_tolerance"] == 1e-6
    assert v10["numerical_gates"]["absolute_KKT_tolerance"] == 1e-10
    assert v10["numerical_gates"]["max_outer_updates"] == 12
    assert v10["numerical_gates"]["original_Armijo"] is True
    assert protocol["runtime_grant"] is False
    assert protocol["coverage_contract"]["nonlinear_solver_calls"] == 0
    assert protocol["preserved_numerical_status"] == {
        "authority": "no_publish", "physical_validation": "unsupported",
        "solver_exit_code": 2, "status": "fail",
        "stopping_reason": "stationary_nonzero_residual",
    }
    assert not (ROOT / OUTPUT_REL).exists()

    v13_sources = {item["path"]: item for item in protocol["owned_source_files"]}
    for relative, item in v13_sources.items():
        path = ROOT / pathlib.PurePosixPath(relative)
        assert path.stat().st_size == item["bytes"] and sha(path) == item["sha256"], relative

    test_source = (ROOT / TEST_REL).read_text(encoding="utf-8")
    test_tree = ast.parse(test_source)
    test_methods = [node.name for cls in test_tree.body if isinstance(cls, ast.ClassDef)
                    for node in cls.body if isinstance(node, ast.FunctionDef) and node.name.startswith("test_")]
    assert len(test_methods) == 21

    julia_source = (ROOT / JULIA_REL).read_text(encoding="utf-8")
    runner.check_hydration_contract_text(julia_source)
    observe = julia_source.index('new_json(joinpath(out, "hydration_observation_initial.json")')
    rebuild = julia_source.index("result = hydration_rebuild_result(body, wire, expected_result_hash, context)")
    validator = julia_source.index("S.validate_spatial_manufactured_result_v1(context, result)")
    consumer = julia_source.index("M.result_tests(context, result, out)")
    assert observe < rebuild < validator < consumer
    contract = protocol["coverage_contract"]
    assert "validate_spatial_manufactured_geometry_v1" in contract["full_validator_includes"]
    assert "_smr_validate_cases_v1" in contract["full_validator_includes"]
    assert contract["producer_calls"] == ["validate_spatial_manufactured_result_v1(context, result)"]
    assert contract["consumer_calls"] == ["ManufacturedCandidateV1Tests.result_tests(context, result, out)"]
    required_completion = {
        "strict source/input/result hashes", "exact context/candidate/declaration rebind",
        "typed result hash and canonical wire roundtrip", "producer full validator exit 0",
        "fresh consumer full result_tests exit 0", "independent controller carrier/binding seal",
        "before/after input snapshots unchanged", "producer tree unchanged through consumer",
    }
    assert required_completion.issubset(set(contract["completion_requires"]))

    full_validator_path = ROOT / "src/RuntimeV4/SpatialMultiRegionV4.jl"
    full_validator_source = full_validator_path.read_text(encoding="utf-8")
    v10_pin = next(item for item in v10["source_pins"] if item["path"] == "src/RuntimeV4/SpatialMultiRegionV4.jl")
    assert sha(full_validator_path) == v10_pin["sha256"]
    full_validator = full_validator_source[full_validator_source.index("function validate_spatial_manufactured_result_v1(context,p::SpatialManufacturedNumericalResultV1)"):]
    assert "validate_spatial_manufactured_geometry_v1(context,d.source.input,e.provider_receipt)" in full_validator
    assert "_smr_validate_cases_v1(context,p,d,e.provider_receipt)" in full_validator
    helper = (ROOT / HELPER_REL).read_text(encoding="utf-8")
    result_tests = helper[helper.index("function result_tests(context,result,out)"):]
    assert "S.validate_spatial_manufactured_result_v1(context,result)" in result_tests

    return {
        "protocol": {"path": PROTOCOL_REL.as_posix(), "bytes": protocol_path.stat().st_size,
                     "sha256": sha(protocol_path)},
        "owner_receipt": {"path": (OWNER_LEAF_REL / "receipt.json").as_posix(),
                          "sha256": sha(receipt_path), "tests": 21, "exit_code": 0},
        "v10_pins": {"input_count": len(pins), "source_pin_count": len(v10["source_pins"]),
                     "all_hashes_match": True},
        "saved_producer_tree": {"entry_count": len(actual_tree), "bytes": tree["bytes"],
                                 "sha256": tree["sha256"], "all_hashes_match": True},
        "gates": {"scaled_residual_tolerance": 1e-6, "absolute_kkt_tolerance": 1e-10,
                  "max_outer_updates": 12, "original_armijo": True, "stage_seconds": 480,
                  "sampled_rss_bytes": 2**31, "aggregate_child_wall_seconds": 960,
                  "controller_overhead_seconds": 120, "cleanup_grace_seconds": 6,
                  "poll_seconds": 0.25},
        "validator_consumer_preconditions": {"full_spatial_validator_pinned": True,
            "geometry_validator_bound": True, "case_validator_bound": True,
            "consumer_full_result_tests_bound": True, "call_order": ["observe", "rebuild",
            "full_validator", "consumer"], "completion_gates": len(required_completion)},
        "runtime_boundary": {"grant": False, "output_leaf_absent": not (ROOT / OUTPUT_REL).exists(),
                             "julia_started": False, "solver_calls": 0,
                             "preserved_status": "fail/exit2/stationary_nonzero_residual/no_publish"},
    }


def check_mutations(runner, julia_source: str) -> list[dict[str, str]]:
    mutations = (
        ("unequal numeric rejection",
         "        else\n            push!(semantic_differences, path)\n        end\n        return",
         "        end\n        return"),
        ("object key-set rejection",
         '        if parsed_keys != exact_keys\n            push!(semantic_differences, path * ".<keys>")\n            return\n        end\n',
         ""),
        ("sequence shape rejection",
         '        parsed_shape == exact_shape || (push!(semantic_differences, path * ".<shape>"); return)\n',
         ""),
    )
    observed = []
    for label, before, after in mutations:
        assert before in julia_source, f"mutation anchor missing: {label}"
        weakened = julia_source.replace(before, after, 1)
        assert weakened != julia_source
        try:
            runner.check_hydration_contract_text(weakened)
        except ValueError as exc:
            assert "lost its fail-closed guard" in str(exc)
            observed.append({"mutation": label, "result": "rejected", "exception": type(exc).__name__,
                             "message": str(exc)})
        else:
            raise AssertionError(f"V13 checker accepted V12 fail-open mutation: {label}")
    return observed


def check_resource_fakes(runner, stage_dir: pathlib.Path) -> dict:
    import psutil

    class FakeInfo:
        def __init__(self, rss: int):
            self.rss = rss

    class FakeProcess:
        def __init__(self, pid: int, rss: int, children=None, deny_rss=False,
                     deny_children=False, inaccessible_rss: int = 0):
            self.pid = pid
            self.actual_rss = rss
            self._children = list(children or [])
            self.deny_rss = deny_rss
            self.deny_children = deny_children
            self.inaccessible_rss = inaccessible_rss
            self.alive = True
            self.terminate_called = False
            self.kill_called = False

        def children(self, recursive=False):
            if self.deny_children:
                raise psutil.AccessDenied(pid=self.pid)
            return self._children

        def memory_info(self):
            if self.deny_rss:
                raise psutil.AccessDenied(pid=self.pid)
            return FakeInfo(self.actual_rss)

        def create_time(self):
            return float(self.pid)

        def terminate(self):
            self.terminate_called = True

        def kill(self):
            self.kill_called = True
            self.alive = False

    original_process = runner.psutil.Process
    original_wait_procs = runner.psutil.wait_procs
    original_popen = runner.subprocess.Popen
    original_sleep = runner.time.sleep
    try:
        denied_root = FakeProcess(71001, 3 * 2**30, deny_children=True)
        runner.psutil.Process = lambda pid: denied_root
        root_bytes, root_ids = runner.live_tree_bytes(denied_root.pid)
        assert root_bytes == 0 and root_ids == []

        hidden = FakeProcess(71004, 536_870_912, deny_rss=True, inaccessible_rss=536_870_912)
        visible = FakeProcess(71003, 943_718_400)
        partial_root = FakeProcess(71002, 1_073_741_824, children=[visible, hidden])
        runner.psutil.Process = lambda pid: partial_root
        observed_bytes, observed_ids = runner.live_tree_bytes(partial_root.pid)
        expected_actual = partial_root.actual_rss + visible.actual_rss + hidden.inaccessible_rss
        assert observed_bytes == partial_root.actual_rss + visible.actual_rss
        assert observed_bytes < 2**31 < expected_actual
        assert {row["pid"] for row in observed_ids} == {partial_root.pid, visible.pid}

        fake_child = FakeProcess(71007, 943_718_400)
        fake_hidden = FakeProcess(71008, 536_870_912, deny_rss=True, inaccessible_rss=536_870_912)
        fake_root = FakeProcess(71006, 1_073_741_824, children=[fake_child, fake_hidden])
        runner.psutil.Process = lambda pid: fake_root

        class FakePopen:
            def __init__(self, *args, **kwargs):
                self.pid = 71006
                self.returncode = None

            def poll(self):
                return self.returncode

            def kill(self):
                self.returncode = -9

        fake_popen = FakePopen()
        runner.subprocess.Popen = lambda *args, **kwargs: fake_popen

        def finish_fake_child(_seconds):
            fake_popen.returncode = 0

        runner.time.sleep = finish_fake_child
        stage_receipt = runner.run_stage(
            ["fake-child-no-exec"], ROOT, stage_dir, 480.0, 2**31, {},
            {"live_limit_seconds": 480.0, "stage_cap_seconds": 480.0,
             "cleanup_grace_seconds": 6.0, "remaining_before_seconds": 960.0},
        )
        assert stage_receipt["stop_reason"] == "exited"
        assert stage_receipt["exit_code"] == 0
        assert stage_receipt["peak_sampled_process_tree_working_set_bytes"] < 2**31
        assert fake_root.actual_rss + fake_child.actual_rss + fake_hidden.inaccessible_rss > 2**31

        still_running = FakeProcess(71009, 1)
        runner.psutil.Process = lambda pid: still_running

        def inaccessible_wait(procs, timeout=None):
            raise psutil.AccessDenied(pid=still_running.pid)

        runner.psutil.wait_procs = inaccessible_wait
        cleanup_receipt = runner.terminate_tree(still_running.pid, 6.0)
        assert still_running.terminate_called and still_running.alive
        assert cleanup_receipt["termination_confirmed"] is True
        assert cleanup_receipt["remaining_process_pids"] == []
        assert still_running.kill_called is False
    finally:
        runner.psutil.Process = original_process
        runner.psutil.wait_procs = original_wait_procs
        runner.subprocess.Popen = original_popen
        runner.time.sleep = original_sleep

    return {
        "root_children_access_denied": {"result": "sampled_as_zero", "actual_rss_bytes": 3 * 2**30},
        "child_rss_access_denied": {"observed_bytes": observed_bytes,
            "expected_actual_tree_bytes": expected_actual, "cap_bytes": 2**31,
            "result": "partial_sample_below_cap"},
        "run_stage_partial_rss": {"reported_stop_reason": stage_receipt["stop_reason"],
            "reported_peak_bytes": stage_receipt["peak_sampled_process_tree_working_set_bytes"],
            "expected_actual_tree_bytes": fake_root.actual_rss + fake_child.actual_rss + fake_hidden.inaccessible_rss,
            "result": "stage_not_stopped_above_cap"},
        "terminate_wait_access_denied": {"reported_termination_confirmed": cleanup_receipt["termination_confirmed"],
            "remaining_process_pids": cleanup_receipt["remaining_process_pids"],
            "fake_process_still_alive": still_running.alive,
            "kill_called": still_running.kill_called, "result": "false_confirmation"},
    }


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: review_v13_static.py <owned-evidence-leaf>")
    evidence_leaf = pathlib.Path(sys.argv[1]).resolve()
    evidence_leaf.mkdir(parents=True, exist_ok=True)
    protocol_path = ROOT / PROTOCOL_REL
    protocol = load_json(protocol_path)
    runner = load_runner()
    preflight = runner.verify_pre_output_contract(protocol_path, PROTOCOL_SHA, OUTPUT_REL)
    assert len(preflight["input_entries"]) >= 89 + 119
    assert len(preflight["v12_static_no_go"]["input_entries"]) > 0
    source = (ROOT / JULIA_REL).read_text(encoding="utf-8")
    mutation_results = check_mutations(runner, source)
    package = check_package(protocol, runner, ROOT / OWNER_LEAF_REL)
    resource = check_resource_fakes(runner, evidence_leaf / "resource_fake_stage")
    assert not (ROOT / OUTPUT_REL).exists()
    result = {
        "schema": "independent-mms-v13-static-and-resource-fake-review-v1",
        "classification": "STATIC_HYDRATION_AND_PRECONDITIONS_PASS; RUNTIME_NO_GO_RESOURCE_MONITOR_FAIL_OPEN",
        "protocol_sha256": PROTOCOL_SHA,
        "owner_static_receipt_sha256": OWNER_RECEIPT_SHA,
        "full_pre_output_verifier": "PASS_NO_OUTPUT_CREATED_NO_CHILD_LAUNCHED",
        "package_checks": package,
        "v12_deletion_mutations": mutation_results,
        "resource_fake_counterexamples": resource,
        "runtime_boundary": {"julia_started": False, "solver_started": False,
                              "producer_started": False, "consumer_started": False,
                              "output_leaf_exists": False, "runtime_grant": False,
                              "numerical_or_physical_credit": False},
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
