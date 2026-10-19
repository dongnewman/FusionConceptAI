from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
import tempfile
from types import ModuleType, SimpleNamespace


ROOT = Path(__file__).resolve().parents[2]
PROTOCOL_REL = Path(
    "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/"
    "native_axisymmetric_forward_v15/actual_run_protocol_v24_process_tree_candidate_v1.json"
)
EXPECTED = {
    "protocol": "2735bfb319695240ba9abc868e76e3b6756146067e635abf83ff0e0c88c37a4d",
    "supervisor": "ebf0e022e3d42622aac2eeff2858b9f70bd4b3cfba7bfbdce4ee28ae191861c7",
    "verifier": "8d564ba6b84f8c0e813c93dd1c22da1e866a4da080021eb51c0ed866560f5d28",
    "tests": "793f5a564509f46866720fb14e0429ec1c3250296b3187451bab2812c86ff989",
    "pin_manifest": "4d1c501f3d0f9d993d5a0852f5d7f68fe4cc88abf53a34cb89aedae580284d5c",
    "owner_manifest": "52a222ee54f1c9d1b39098d3f95fd5c79eaf772fe4e91a0b42b25a81e6fadd16",
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


class FakeTimeoutExpired(Exception):
    pass


class FakeProcess:
    def __init__(self, pid: int, rss: int, created: object,
                 children: list[object] | None = None) -> None:
        self.pid = pid
        self.rss = rss
        self.created = created
        self.child_list = list(children or [])
        self.alive = True
        self.pid_reused_to_other_process = False
        self.children_error: Exception | None = None
        self.rss_error: Exception | None = None
        self.identity_error: Exception | None = None
        self.state_error: Exception | None = None
        self.terminate_error: Exception | None = None
        self.kill_error: Exception | None = None
        self.terminate_calls = 0
        self.kill_calls = 0
        self.wait_hook = None

    def create_time(self):
        if self.identity_error is not None:
            raise self.identity_error
        return self.created

    def children(self, recursive: bool = False):
        if self.children_error is not None:
            raise self.children_error
        if not recursive:
            return list(self.child_list)
        found = []
        pending = list(self.child_list)
        while pending:
            item = pending.pop(0)
            found.append(item)
            pending[0:0] = item.child_list
        return found

    def memory_info(self):
        if self.rss_error is not None:
            raise self.rss_error
        if not self.alive:
            raise FakeNoSuchProcess("process disappeared before RSS read")
        return SimpleNamespace(rss=self.rss)

    def is_running(self):
        if self.state_error is not None:
            raise self.state_error
        # psutil Process.is_running() is PID-reuse aware: a stale Process
        # handle whose PID now belongs to another creation time reports False.
        if self.pid_reused_to_other_process:
            return False
        return self.alive

    def terminate(self):
        self.terminate_calls += 1
        if self.terminate_error is not None:
            raise self.terminate_error

    def kill(self):
        self.kill_calls += 1
        if self.kill_error is not None:
            raise self.kill_error

    def wait(self, timeout: float | None = None):
        self.alive = False
        if self.wait_hook is not None:
            self.wait_hook(self)
        return 0


class FakeAPI:
    NoSuchProcess = FakeNoSuchProcess
    AccessDenied = FakeAccessDenied
    TimeoutExpired = FakeTimeoutExpired

    def __init__(self, popen: FakeProcess, lookup: FakeProcess) -> None:
        self.popen = popen
        self.lookup = lookup
        self.lookup_calls = 0

    def Popen(self, *_args, **_kwargs):
        return self.popen

    def Process(self, pid: int):
        self.lookup_calls += 1
        assert pid == self.popen.pid
        return self.lookup

    @staticmethod
    def wait_procs(processes, timeout=0):
        alive = [process for process in processes if process.alive]
        gone = [process for process in processes if not process.alive]
        return gone, alive


def run_fake(module: ModuleType, base: Path, name: str, popen: FakeProcess,
             lookup: FakeProcess) -> tuple[int, dict, FakeAPI]:
    case_dir = base / name
    case_dir.mkdir()
    manifest = case_dir / "required.json"
    manifest.write_text(json.dumps({
        "schema": module.PIN_MANIFEST_SCHEMA, "pins": [],
    }, sort_keys=True) + "\n", encoding="utf-8")
    direct_pin = f"{manifest.resolve()}={sha256(manifest)}"
    args = SimpleNamespace(
        command=["fake_solver_never_spawned"], wall_seconds=180.0,
        rss_bytes=2_147_483_648, cwd=ROOT,
        stdout=case_dir / "stdout.raw", stderr=case_dir / "stderr.raw",
        receipt=case_dir / "execution.json", name=name, env=[],
        require_file_sha256=[direct_pin],
        require_file_sha256_manifest=[manifest.resolve()],
        require_absent_path=[],
    )
    api = FakeAPI(popen, lookup)
    exit_code = module.run_supervised(args, api)
    return exit_code, json.loads(args.receipt.read_text(encoding="utf-8")), api


def main() -> None:
    protocol_path = ROOT / PROTOCOL_REL
    protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    supervisor_path = ROOT / "tools/up4_reference_validation/freegs_process_supervisor_v24.py"
    verifier_path = ROOT / "tools/up4_reference_validation/verify_freegs_v24_process_tree_candidate.py"
    tests_path = ROOT / "test/UP4ReferenceValidationV1/test_freegs_process_supervisor_v24.py"
    pin_manifest_path = ROOT / "tools/up4_reference_validation/freegs_v24_pin_manifest.json"
    owner_manifest_path = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/agent_reference_gs_20260924/freegs_v24_identity_binding_static_r1/evidence_manifest.json"
    expected_paths = {
        protocol_path: EXPECTED["protocol"], supervisor_path: EXPECTED["supervisor"],
        verifier_path: EXPECTED["verifier"], tests_path: EXPECTED["tests"],
        pin_manifest_path: EXPECTED["pin_manifest"],
        owner_manifest_path: EXPECTED["owner_manifest"],
    }
    for path, digest in expected_paths.items():
        assert sha256(path) == digest, f"SHA mismatch: {path}"

    pins = protocol["dependency_file_pins"]
    assert protocol["dependency_file_pin_count"] == len(pins) == 179
    pin_map = {pin["path"]: (pin["bytes"], pin["sha256"].lower()) for pin in pins}
    assert len(pin_map) == len(pins)
    for raw_path, (expected_bytes, expected_sha) in pin_map.items():
        path = Path(raw_path)
        assert path.is_file() and path.stat().st_size == expected_bytes
        assert sha256(path) == expected_sha, f"pin mismatch: {path}"

    v23_path = ROOT / protocol["prior_v23_runtime_no_go"]["protocol_path"]
    v23 = json.loads(v23_path.read_text(encoding="utf-8"))
    v23_pins = {row["path"]: (row["bytes"], row["sha256"].lower())
                for row in v23["dependency_file_pins"]}
    v24_pins = pin_map
    missing = sorted(set(v23_pins) - set(v24_pins))
    changed = sorted(path for path in set(v23_pins) & set(v24_pins)
                     if v23_pins[path] != v24_pins[path])
    added = sorted(set(v24_pins) - set(v23_pins))
    assert len(v23_pins) == 169 and not missing and not changed
    assert len(added) == 10

    scope = protocol["protocol_scope_contract_v22"]
    budget = protocol["resource_contract"]
    assert scope["scope_key_count"] == 17 and len(scope["scope_key_names"]) == 17
    assert scope["current_scope"] == protocol["scope"]
    assert protocol["runtime_execution_authorized"] is False
    assert protocol["root_resource_slot"]["granted"] is False
    assert budget["wall_seconds_per_step"] == 180
    assert budget["process_tree_rss_bytes_per_step"] == 2_147_483_648
    assert budget["julia_threads"] == budget["blas_threads"] == 1
    assert budget["root_identity_binding_required"] is True
    assert budget["identity_failure_never_signals_unbound_lookup_pid"] is True
    assert budget["natural_exit_requires_exact_bound_root_identity"] is True
    output_leaf = Path(protocol["runtime_endpoint_join"]["output_leaf"])
    assert not output_leaf.exists()

    module = load_source("independent_freegs_process_supervisor_v24", supervisor_path)
    results = {}
    with tempfile.TemporaryDirectory(prefix="freegs_v24_independent_") as temp:
        base = Path(temp)

        # V23 false-positive control: exact PID but different process generation.
        old_v23_popen = FakeProcess(501, 4096, 10.0)
        old_v23_lookup = FakeProcess(501, 8192, 20.0)
        code, receipt, api = run_fake(module, base, "pre_sample_pid_reuse",
                                      old_v23_popen, old_v23_lookup)
        assert code == module.TREE_EVIDENCE_EXIT
        assert receipt["stop_reason"] == "root_identity_binding_failed"
        assert receipt["root_identity_binding"]["status"] == "mismatch"
        assert receipt["sample_count"] == 0
        assert receipt["evidence_status"] == "invalid_process_tree_evidence"
        assert old_v23_lookup.terminate_calls == old_v23_lookup.kill_calls == 0
        results["v23_false_positive_rejected"] = {
            "popen_identity": {"pid": 501, "create_time": 10.0},
            "lookup_identity": {"pid": 501, "create_time": 20.0},
            "exit": code, "stop_reason": receipt["stop_reason"],
            "samples": receipt["sample_count"],
            "evidence_status": receipt["evidence_status"],
            "unbound_lookup_signals": [old_v23_lookup.terminate_calls,
                                        old_v23_lookup.kill_calls],
        }

        # Popen identity unreadable and lookup identity unreadable both fail before sampling.
        bad_popen = FakeProcess(502, 4096, 10.0)
        bad_popen.identity_error = FakeAccessDenied("Popen create_time denied")
        lookup_after_bad_popen = FakeProcess(502, 4096, 10.0)
        code, receipt, api = run_fake(module, base, "unreadable_popen_identity",
                                      bad_popen, lookup_after_bad_popen)
        assert code == module.TREE_EVIDENCE_EXIT and receipt["sample_count"] == 0
        assert receipt["root_identity_binding"]["status"] == "unverified"
        assert api.lookup_calls == 0
        results["unreadable_popen_identity"] = {
            "exit": code, "binding": receipt["root_identity_binding"],
            "samples": receipt["sample_count"], "lookup_calls": api.lookup_calls,
        }

        popen_ok = FakeProcess(503, 4096, 10.0)
        lookup_bad = FakeProcess(503, 4096, 10.0)
        lookup_bad.identity_error = FakeAccessDenied("Process lookup create_time denied")
        code, receipt, api = run_fake(module, base, "unreadable_lookup_identity",
                                      popen_ok, lookup_bad)
        assert code == module.TREE_EVIDENCE_EXIT and receipt["sample_count"] == 0
        assert receipt["root_identity_binding"]["status"] == "popen_identity_observed"
        assert lookup_bad.terminate_calls == lookup_bad.kill_calls == 0
        results["unreadable_lookup_identity"] = {
            "exit": code, "binding": receipt["root_identity_binding"],
            "samples": receipt["sample_count"],
            "unbound_lookup_signals": [lookup_bad.terminate_calls, lookup_bad.kill_calls],
        }

        # After natural wait, lookup PID is recycled. V24 must reject and avoid signaling it.
        popen_after_wait = FakeProcess(504, 4096, 10.0)
        lookup_after_wait = FakeProcess(504, 8192, 10.0)
        def recycle_lookup(_child):
            lookup_after_wait.alive = False
            lookup_after_wait.created = 20.0
        popen_after_wait.wait_hook = recycle_lookup
        code, receipt, api = run_fake(module, base, "after_wait_pid_reuse",
                                      popen_after_wait, lookup_after_wait)
        assert code == module.TREE_EVIDENCE_EXIT
        assert receipt["natural_root_exit_identity_check"]["status"] == "failed"
        assert receipt["natural_root_exit_identity_check"]["error"]["operation"] == "natural_exit_root_identity_mismatch"
        assert receipt["tree_exit_proven"] is False
        assert lookup_after_wait.terminate_calls == lookup_after_wait.kill_calls == 0
        results["after_wait_pid_reuse"] = {
            "exit": code, "natural_exit_check": receipt["natural_root_exit_identity_check"],
            "tree_exit_proven": receipt["tree_exit_proven"],
            "unbound_lookup_signals": [lookup_after_wait.terminate_calls,
                                        lookup_after_wait.kill_calls],
        }

        # A natural Popen wait is tied to the launched child handle. If that
        # child has exited and the same PID is then owned by unrelated B,
        # psutil's cached Process(A).create_time() stays bound to A while
        # Process(A).is_running() reports False after detecting reuse. This
        # is valid proof that bound A exited, not proof about unrelated B.
        popen_natural_reuse = FakeProcess(506, 4096, 10.0)
        lookup_natural_reuse = FakeProcess(506, 8192, 10.0)
        def reuse_after_natural_exit(_child):
            lookup_natural_reuse.pid_reused_to_other_process = True
        popen_natural_reuse.wait_hook = reuse_after_natural_exit
        code, receipt, _api = run_fake(module, base, "natural_exit_then_unrelated_pid_reuse",
                                       popen_natural_reuse, lookup_natural_reuse)
        assert code == 0
        assert receipt["natural_root_exit_identity_check"]["status"] == "verified_exact_root_exit"
        assert receipt["natural_root_exit_identity_check"]["process_lookup_is_running"] is False
        assert receipt["tree_exit_proven"] is True
        results["natural_exit_then_unrelated_pid_reuse"] = {
            "exit": code,
            "bound_identity": receipt["root_identity"],
            "natural_exit_check": receipt["natural_root_exit_identity_check"],
            "tree_exit_proven": receipt["tree_exit_proven"],
            "fake_unrelated_reused_pid_still_live": lookup_natural_reuse.alive,
            "interpretation": "valid proof of bound Popen child A exit; unrelated B is outside bound tree identity",
        }

        # Malformed boolean create_time is probed separately from unreadable/NaN failures.
        bool_popen = FakeProcess(505, 4096, True)
        bool_lookup = FakeProcess(505, 4096, 1.0)
        bool_popen.wait_hook = lambda _child: setattr(bool_lookup, "alive", False)
        code, receipt, _api = run_fake(module, base, "boolean_create_time_type",
                                       bool_popen, bool_lookup)
        results["malformed_boolean_create_time"] = {
            "popen_raw_create_time_type": type(bool_popen.created).__name__,
            "lookup_raw_create_time_type": type(bool_lookup.created).__name__,
            "exit": code, "evidence_status": receipt["evidence_status"],
            "root_identity": receipt["root_identity"],
            "type_coercion_acceptance": receipt["evidence_status"] == "recorded_complete_samples",
        }

    review_verdict = "NO_GO" if results["malformed_boolean_create_time"]["type_coercion_acceptance"] else "PASS_STATIC_CONTROLS"
    print(json.dumps({
        "protocol_sha256": sha256(protocol_path),
        "v23_pin_count": len(v23_pins), "v24_pin_count": len(v24_pins),
        "v23_pins_preserved_exact": len(v23_pins) - len(missing) - len(changed),
        "added_v24_pins": added,
        "scope_key_count": scope["scope_key_count"],
        "resource_contract": budget,
        "planned_output_leaf_absent": True,
        "runtime_authorized": False,
        "independent_controls": results,
        "review_verdict": review_verdict,
        "no_freegs_or_julia_execution": True,
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
