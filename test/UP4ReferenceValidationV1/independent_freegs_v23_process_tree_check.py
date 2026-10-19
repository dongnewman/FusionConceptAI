from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import sys
import tempfile
from types import ModuleType, SimpleNamespace


ROOT = Path(__file__).resolve().parents[2]
PROTOCOL_REL = Path(
    "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/"
    "native_axisymmetric_forward_v14/actual_run_protocol_v23_process_tree_candidate_v1.json"
)
EXPECTED = {
    "protocol": "c05adbfb7c0abf87d6d28b96e2c0249e64cb4ad29032ea60c8b3cefdddac86a4",
    "supervisor": "93565d8dbaefcf01a7d85c17d5aea4b9a078bfe61c484cee659670f602da1e83",
    "verifier": "a87af3d1e5a022c89b99bb8be1ec4b246528f0baaaf1729f83694c02f0d8763f",
    "tests": "c28cab04728a7b69402f3a3607f26c76d2e6bbd2a57c34a54fe429ce6587a78d",
    "pin_manifest": "ce3d415c1492c7773cf796a5edd8046bd826aba751284d9fc2cb7f6f8e370331",
    "owner_evidence_manifest": "5703322bf96329b55a2abb7acc469ff8591d891a713c4e32126c3efd1166f4a6",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_source(name: str, path: Path) -> ModuleType:
    module = ModuleType(name)
    module.__file__ = str(path)
    sys.modules[name] = module
    exec(compile(path.read_bytes(), str(path), "exec"), module.__dict__)
    return module


class FakeNoSuchProcess(Exception):
    pass


class FakeAccessDenied(Exception):
    pass


class FakeProcess:
    def __init__(self, pid: int, rss: int, create_time: float,
                 children: list[object] | None = None) -> None:
        self.pid = pid
        self._rss = rss
        self._create_time = create_time
        self.child_list = list(children or [])
        self.children_error: Exception | None = None
        self.rss_error: Exception | None = None
        self.terminate_error: Exception | None = None
        self.kill_error: Exception | None = None
        self.alive = True

    def create_time(self) -> float:
        return self._create_time

    def children(self, recursive: bool = False) -> list[object]:
        if self.children_error is not None:
            raise self.children_error
        return self.child_list

    def memory_info(self) -> SimpleNamespace:
        if self.rss_error is not None:
            raise self.rss_error
        return SimpleNamespace(rss=self._rss)

    def terminate(self) -> None:
        if self.terminate_error is not None:
            raise self.terminate_error

    def kill(self) -> None:
        if self.kill_error is not None:
            raise self.kill_error

    def is_running(self) -> bool:
        return self.alive


class FakeAPI:
    NoSuchProcess = FakeNoSuchProcess
    AccessDenied = FakeAccessDenied

    @staticmethod
    def wait_procs(processes: list[FakeProcess], timeout: float = 0):
        return [], list(processes)


class SpawnedChildHandle:
    pid = 501

    def create_time(self) -> float:
        return 10.0

    def wait(self, timeout: float | None = None) -> int:
        return 0


class ReusedPidProcess(FakeProcess):
    def __init__(self) -> None:
        super().__init__(501, 700, 20.0)


def main() -> None:
    protocol_path = ROOT / PROTOCOL_REL
    protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    manifest_path = ROOT / "tools/up4_reference_validation/freegs_v23_pin_manifest.json"
    supervisor_path = ROOT / "tools/up4_reference_validation/freegs_process_supervisor_v23.py"
    verifier_path = ROOT / "tools/up4_reference_validation/verify_freegs_v23_process_tree_candidate.py"
    tests_path = ROOT / "test/UP4ReferenceValidationV1/test_freegs_process_supervisor_v23.py"
    owner_manifest = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/agent_reference_gs_20260924/freegs_v23_process_tree_static_r2/evidence_manifest.json"
    expected_paths = {
        protocol_path: EXPECTED["protocol"], supervisor_path: EXPECTED["supervisor"],
        verifier_path: EXPECTED["verifier"], tests_path: EXPECTED["tests"],
        manifest_path: EXPECTED["pin_manifest"], owner_manifest: EXPECTED["owner_evidence_manifest"],
    }
    for path, expected_sha in expected_paths.items():
        assert sha256(path) == expected_sha, f"SHA mismatch: {path}"

    pins = protocol["dependency_file_pins"]
    assert protocol["dependency_file_pin_count"] == 169 == len(pins)
    by_path = {pin["path"]: pin for pin in pins}
    assert len(by_path) == len(pins), "duplicate pin paths"
    checked_pins = []
    for raw_path, pin in by_path.items():
        path = Path(raw_path)
        assert path.is_file(), f"missing pinned dependency: {path}"
        assert path.stat().st_size == pin["bytes"], f"size mismatch: {path}"
        actual = sha256(path)
        assert actual == pin["sha256"].lower(), f"hash mismatch: {path}"
        checked_pins.append({"path": raw_path, "bytes": pin["bytes"], "sha256": actual})

    v22_path = ROOT / protocol["prior_v22_runtime_no_go"]["protocol_path"]
    v22 = json.loads(v22_path.read_text(encoding="utf-8"))
    v22_pins = {p["path"]: (p["bytes"], p["sha256"].lower())
                for p in v22["dependency_file_pins"]}
    v23_pins = {p["path"]: (p["bytes"], p["sha256"].lower()) for p in pins}
    missing = sorted(set(v22_pins) - set(v23_pins))
    changed = sorted(path for path in set(v22_pins) & set(v23_pins)
                     if v22_pins[path] != v23_pins[path])
    added = sorted(set(v23_pins) - set(v22_pins))
    expected_added = sorted([
        str(supervisor_path), str(verifier_path), str(tests_path), str(manifest_path),
    ])
    assert len(v22_pins) == 165 and not missing and not changed
    assert added == expected_added, {"missing": missing, "changed": changed, "added": added}

    scope = protocol["scope"]
    scope_contract = protocol["protocol_scope_contract_v22"]
    assert scope_contract["scope_key_count"] == 17
    assert len(scope_contract["scope_key_names"]) == 17
    assert scope_contract["current_scope"] == scope
    assert protocol["runtime_execution_authorized"] is False
    assert protocol["root_resource_slot"]["granted"] is False
    budget = protocol["resource_contract"]
    assert budget["wall_seconds_per_step"] == 180
    assert budget["process_tree_rss_bytes_per_step"] == 2_147_483_648
    assert budget["julia_threads"] == budget["blas_threads"] == 1
    assert budget["thread_environment"] == {
        "JULIA_NUM_THREADS": "1", "MKL_NUM_THREADS": "1",
        "NUMEXPR_NUM_THREADS": "1", "OMP_NUM_THREADS": "1",
        "OPENBLAS_NUM_THREADS": "1",
    }
    assert budget["partial_rss_never_compared_to_limit"] is True
    assert budget["natural_exit_requires_complete_samples_and_descendant_audit"] is True

    step = protocol["steps"][0]
    argv = step["launcher_argv_template"]
    assert argv[0].lower().endswith("anaconda3\\python.exe")
    assert argv[1:4] == ["-B", str(supervisor_path), "--name"]
    assert "--wall-seconds" in argv and argv[argv.index("--wall-seconds") + 1] == "180"
    assert "--rss-bytes" in argv and argv[argv.index("--rss-bytes") + 1] == "2147483648"
    assert "--require-file-sha256-manifest" in argv
    manifest_argv = argv[argv.index("--require-file-sha256-manifest") + 1]
    assert manifest_argv == str(manifest_path)
    assert argv[argv.index("--") + 1].lower().endswith(".venv-freegs\\scripts\\python.exe")
    assert any(token.endswith("runtime_v4_freegs_axisymmetric_profile_runner_v9.py") for token in argv)
    assert len(" ".join(argv)) == step["command_length_chars"] == 2158
    output_leaf = Path(protocol["runtime_endpoint_join"]["output_leaf"])
    assert not output_leaf.exists(), f"planned actual output unexpectedly exists: {output_leaf}"

    module = load_source("independent_freegs_process_supervisor_v23", supervisor_path)
    child = FakeProcess(202, 400, 2.0)
    root = FakeProcess(201, 600, 1.0, [child])
    snapshot = module.observe_process_tree(root, FakeAPI)
    assert snapshot.rss_bytes == 1000
    assert [i.key() for i in snapshot.identities] == [(201, 1.0), (202, 2.0)]

    alias = FakeProcess(201, 50, 3.0)
    root_with_alias = FakeProcess(201, 600, 1.0, [alias])
    try:
        module.observe_process_tree(root_with_alias, FakeAPI)
    except module.ProcessTreeEvidenceError as exc:
        assert exc.operation == "root_identity_membership"
        root_identity_negative = exc.as_dict()
    else:
        raise AssertionError("PID reuse alias for root was accepted")

    denied = FakeProcess(203, 400, 3.0)
    denied.rss_error = FakeAccessDenied("synthetic denied RSS")
    root_with_denied = FakeProcess(201, 600, 1.0, [denied])
    try:
        module.observe_process_tree(root_with_denied, FakeAPI)
    except module.ProcessTreeEvidenceError as exc:
        assert exc.operation == "rss_read"
        rss_incomplete = exc.as_dict()
    else:
        raise AssertionError("partial RSS sum was accepted after AccessDenied")

    tracked_root = FakeProcess(301, 600, 1.0)
    tracked_child = FakeProcess(302, 400, 2.0)
    tracked_root.child_list = [tracked_child]
    tracked_root.terminate_error = FakeAccessDenied("synthetic terminate denied")
    tracked_root.kill_error = FakeAccessDenied("synthetic kill denied")
    tracked_child.terminate_error = FakeAccessDenied("synthetic terminate denied")
    tracked_child.kill_error = FakeAccessDenied("synthetic kill denied")
    rid = module._identity(tracked_root, FakeAPI, "independent_test")
    cid = module._identity(tracked_child, FakeAPI, "independent_test")
    termination = module.stop_and_verify(
        tracked_root, rid, {rid.key(): (rid, tracked_root), cid.key(): (cid, tracked_child)}, FakeAPI,
        timeout_seconds=0,
    )
    assert termination["tree_exit_proven"] is False
    assert not termination["residual_audit"]["all_tracked_descendants_gone"]

    spawned_handle = SpawnedChildHandle()
    reused_process = ReusedPidProcess()

    class ReusedPidAPI(FakeAPI):
        @staticmethod
        def Popen(*_args, **_kwargs):
            return spawned_handle

        @staticmethod
        def Process(pid: int) -> ReusedPidProcess:
            assert pid == spawned_handle.pid
            return reused_process

    with tempfile.TemporaryDirectory(prefix="freegs_v23_pid_reuse_") as temp:
        tempdir = Path(temp)
        synthetic_manifest = tempdir / "required.json"
        synthetic_manifest.write_text(json.dumps({
            "schema": "fusionconceptai:process-tree-required-files-manifest-v1",
            "pins": [],
        }, sort_keys=True) + "\n", encoding="utf-8")
        args = SimpleNamespace(
            command=["fake_solver_never_spawned"],
            wall_seconds=180,
            rss_bytes=2_147_483_648,
            cwd=ROOT,
            stdout=tempdir / "stdout.raw",
            stderr=tempdir / "stderr.raw",
            receipt=tempdir / "execution.json",
            name="synthetic-pid-reuse-check",
            env=[],
            require_file_sha256=[f"{synthetic_manifest}={sha256(synthetic_manifest)}"],
            require_file_sha256_manifest=[synthetic_manifest],
            require_absent_path=[],
        )
        spawn_exit = module.run_supervised(args, ReusedPidAPI)
        spawn_receipt = json.loads(args.receipt.read_text(encoding="utf-8"))
        assert "root_identity" in spawn_receipt, spawn_receipt
        assert spawned_handle.create_time() == 10.0
        assert spawn_receipt["root_identity"] == {
            "pid": 501, "create_time_epoch_s": 20.0,
        }
        assert spawn_receipt["tree_exit_proven"] is True
        assert spawn_receipt["evidence_status"] == "recorded_complete_samples"
        spawn_pid_reuse = {
            "popen_handle_identity": {"pid": 501, "create_time_epoch_s": 10.0},
            "process_handle_identity": spawn_receipt["root_identity"],
            "supervisor_exit": spawn_exit,
            "receipt_evidence_status": spawn_receipt["evidence_status"],
            "receipt_tree_exit_proven": spawn_receipt["tree_exit_proven"],
            "child_exit_code": spawn_receipt["child_exit_code"],
            "observation": "Supervisor never compares Popen handle create_time to Process(pid) create_time.",
        }

    print(json.dumps({
        "protocol_sha256": sha256(protocol_path),
        "pin_count": len(checked_pins),
        "v22_preserved": len(v22_pins),
        "added_pins": added,
        "resource_contract": budget,
        "scope_key_count": scope_contract["scope_key_count"],
        "launcher_argv_count": len(argv),
        "launcher_joined_char_count": len(" ".join(argv)),
        "planned_output_leaf_absent": True,
        "runtime_authorized": False,
        "fake_positive_tree": {"rss_bytes": snapshot.rss_bytes,
                                "identities": [list(i.key()) for i in snapshot.identities]},
        "root_pid_reuse_negative": root_identity_negative,
        "access_denied_rss_negative": rss_incomplete,
        "termination_failure_negative": termination,
        "spawn_pid_reuse_false_pass": spawn_pid_reuse,
        "all_dependency_pins": checked_pins,
        "no_julia_or_freegs_execution": True,
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
