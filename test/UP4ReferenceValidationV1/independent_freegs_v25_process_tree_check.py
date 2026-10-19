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
    "native_axisymmetric_forward_v16/actual_run_protocol_v25_process_tree_candidate_v1.json"
)
EXPECTED = {
    "protocol": "ce2a06249c79f9a134adf41bc0731ead1da7189b4fb6fd14ea2d6850e604d8ae",
    "supervisor": "7092ac49e8a6af758b97433b002dbf605ff4cbf12669aa5c5de42ec07c90c53b",
    "verifier": "09f6c2e8fb4838ec44923388b44f3fb951b970bb4adf330a4c8c7a4afab7178e",
    "tests": "b48ae0c63d7264deb87e80b4612016d0277dd4516f74bb4522dc3fce4a257830",
    "pin_manifest": "a71da61f6946d40ca1e52e3e20e82953fa67afdda54f793da4b827f6d0fc7a04",
    "owner_manifest": "771f4cf19345fd71905cee0e29c30c4b95722b33898fd1ec5ec9fbd03b80fd9a",
    "v24_protocol": "2735bfb319695240ba9abc868e76e3b6756146067e635abf83ff0e0c88c37a4d",
    "v24_supervisor": "ebf0e022e3d42622aac2eeff2858b9f70bd4b3cfba7bfbdce4ee28ae191861c7",
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
    def __init__(self, pid: object, rss: int, created: object) -> None:
        self.pid = pid
        self.rss = rss
        self.created = created
        self.alive = True
        self.identity_error: Exception | None = None
        self.terminate_calls = 0
        self.kill_calls = 0
        self.wait_hook = None

    def create_time(self):
        if self.identity_error is not None:
            raise self.identity_error
        return self.created

    def children(self, recursive: bool = False):
        return []

    def memory_info(self):
        if not self.alive:
            raise FakeNoSuchProcess("gone")
        return SimpleNamespace(rss=self.rss)

    def is_running(self):
        return self.alive

    def terminate(self):
        self.terminate_calls += 1

    def kill(self):
        self.kill_calls += 1

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

    def Process(self, pid):
        self.lookup_calls += 1
        assert pid == self.popen.pid
        return self.lookup

    @staticmethod
    def wait_procs(processes, timeout=0):
        alive = [p for p in processes if p.alive]
        gone = [p for p in processes if not p.alive]
        return gone, alive


def run_fake(module: ModuleType, base: Path, name: str, popen: FakeProcess,
             lookup: FakeProcess) -> tuple[int, dict, FakeAPI]:
    case_dir = base / name
    case_dir.mkdir()
    manifest = case_dir / "required.json"
    manifest.write_text(json.dumps({"schema": module.PIN_MANIFEST_SCHEMA, "pins": []}) + "\n",
                        encoding="utf-8")
    digest = sha256(manifest)
    args = SimpleNamespace(
        command=["fake_solver_never_spawned"], wall_seconds=180.0,
        rss_bytes=2_147_483_648, cwd=ROOT,
        stdout=case_dir / "stdout.raw", stderr=case_dir / "stderr.raw",
        receipt=case_dir / "execution.json", name=name, env=[],
        require_file_sha256=[f"{manifest.resolve()}={digest}"],
        require_file_sha256_manifest=[manifest.resolve()], require_absent_path=[],
    )
    api = FakeAPI(popen, lookup)
    code = module.run_supervised(args, api)
    return code, json.loads(args.receipt.read_text(encoding="utf-8")), api


def identity_control(module: ModuleType, pid: object, created: object) -> dict:
    proc = FakeProcess(pid, 1, created)
    try:
        identity = module._identity(proc, FakeAPI(proc, proc), "independent_strict_identity")
        return {"accepted": True, "identity": {"pid": identity.pid,
                "create_time_epoch_s": identity.create_time_epoch_s}}
    except module.ProcessTreeEvidenceError as exc:
        return {"accepted": False, "error": exc.as_dict()}


def main() -> None:
    protocol_path = ROOT / PROTOCOL_REL
    supervisor_path = ROOT / "tools/up4_reference_validation/freegs_process_supervisor_v25.py"
    verifier_path = ROOT / "tools/up4_reference_validation/verify_freegs_v25_process_tree_candidate.py"
    tests_path = ROOT / "test/UP4ReferenceValidationV1/test_freegs_process_supervisor_v25.py"
    pin_manifest_path = ROOT / "tools/up4_reference_validation/freegs_v25_pin_manifest.json"
    owner_manifest_path = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/agent_reference_gs_20260924/freegs_v25_strict_identity_static_r1/evidence_manifest.json"
    v24_protocol_path = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v15/actual_run_protocol_v24_process_tree_candidate_v1.json"
    v24_supervisor_path = ROOT / "tools/up4_reference_validation/freegs_process_supervisor_v24.py"
    expected_paths = {
        protocol_path: EXPECTED["protocol"], supervisor_path: EXPECTED["supervisor"],
        verifier_path: EXPECTED["verifier"], tests_path: EXPECTED["tests"],
        pin_manifest_path: EXPECTED["pin_manifest"], owner_manifest_path: EXPECTED["owner_manifest"],
        v24_protocol_path: EXPECTED["v24_protocol"], v24_supervisor_path: EXPECTED["v24_supervisor"],
    }
    for path, expected_sha in expected_paths.items():
        assert sha256(path) == expected_sha, f"SHA mismatch: {path}"

    protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    pins = protocol["dependency_file_pins"]
    pin_map = {row["path"]: (row["bytes"], row["sha256"].lower()) for row in pins}
    assert len(pins) == len(pin_map) == protocol["dependency_file_pin_count"] == 190
    for raw_path, (expected_bytes, expected_sha) in pin_map.items():
        path = Path(raw_path)
        assert path.is_file() and path.stat().st_size == expected_bytes
        assert sha256(path) == expected_sha, f"pin mismatch: {path}"

    v24_protocol = json.loads(v24_protocol_path.read_text(encoding="utf-8"))
    v24_pin_map = {row["path"]: (row["bytes"], row["sha256"].lower())
                   for row in v24_protocol["dependency_file_pins"]}
    assert len(v24_pin_map) == 179
    missing = sorted(set(v24_pin_map) - set(pin_map))
    changed = sorted(path for path in set(v24_pin_map) & set(pin_map)
                     if v24_pin_map[path] != pin_map[path])
    added = sorted(set(pin_map) - set(v24_pin_map))
    assert not missing and not changed and len(added) == 11

    scope = protocol["protocol_scope_contract_v22"]
    resources = protocol["resource_contract"]
    assert scope["scope_key_count"] == len(scope["scope_key_names"]) == 17
    assert scope["current_scope"] == protocol["scope"]
    assert protocol["runtime_execution_authorized"] is False
    assert protocol["root_resource_slot"]["granted"] is False
    assert resources["wall_seconds_per_step"] == 180
    assert resources["process_tree_rss_bytes_per_step"] == 2_147_483_648
    assert resources["julia_threads"] == resources["blas_threads"] == 1
    assert resources["pid_requires_builtin_positive_int"] is True
    assert resources["create_time_requires_builtin_finite_positive_int_or_float_excluding_bool"] is True
    output_leaf = Path(protocol["runtime_endpoint_join"]["output_leaf"])
    assert not output_leaf.exists()

    v24_module = load_source("independent_freegs_process_supervisor_v24", v24_supervisor_path)
    v25_module = load_source("independent_freegs_process_supervisor_v25", supervisor_path)
    cases: dict[str, dict] = {}
    with tempfile.TemporaryDirectory(prefix="freegs_v25_independent_") as temp:
        base = Path(temp)

        # Reproduce V24: bool True and float 1.0 collapse to the same identity.
        old_child = FakeProcess(501, 4096, True)
        old_lookup = FakeProcess(501, 8192, 1.0)
        old_child.wait_hook = lambda _child: setattr(old_lookup, "alive", False)
        old_code, old_receipt, _ = run_fake(v24_module, base, "v24_bool_float_alias", old_child, old_lookup)
        assert old_code == 0 and old_receipt["evidence_status"] == "recorded_complete_samples"
        cases["v24_bool_true_vs_float_1_false_pass"] = {
            "exit": old_code, "evidence_status": old_receipt["evidence_status"],
            "root_identity": old_receipt["root_identity"],
        }

        # Same values against V25 must fail before sampling and never signal lookup PID.
        new_child = FakeProcess(502, 4096, True)
        new_lookup = FakeProcess(502, 8192, 1.0)
        new_code, new_receipt, new_api = run_fake(v25_module, base, "v25_bool_float_alias", new_child, new_lookup)
        assert new_code == v25_module.TREE_EVIDENCE_EXIT
        assert new_receipt["sample_count"] == 0 and not new_receipt["all_samples_complete"]
        assert new_receipt["tree_exit_proven"] is False
        assert new_receipt["evidence_status"] == "invalid_process_tree_evidence"
        assert new_receipt["observation_errors"][0]["operation"] == "popen_root_identity"
        assert new_lookup.terminate_calls == new_lookup.kill_calls == 0
        cases["v25_bool_true_vs_float_1_rejected"] = {
            "exit": new_code, "sample_count": new_receipt["sample_count"],
            "evidence_status": new_receipt["evidence_status"],
            "error": new_receipt["observation_errors"][0],
            "unbound_lookup_signals": [new_lookup.terminate_calls, new_lookup.kill_calls],
            "lookup_calls": new_api.lookup_calls,
        }

        malformed_values = [
            (True, 1.0, "bool_pid"), (1.0, 1.0, "float_pid"), ("501", 1.0, "string_pid"),
            (0, 1.0, "zero_pid"), (-1, 1.0, "negative_pid"),
            (501, True, "bool_time"), (501, "1.0", "string_time"),
            (501, 0, "zero_time"), (501, -1, "negative_time"),
            (501, float("nan"), "nan_time"), (501, float("inf"), "infinite_time"),
        ]
        bad_results = {label: identity_control(v25_module, pid, created)
                       for pid, created, label in malformed_values}
        assert all(not result["accepted"] for result in bad_results.values())
        cases["malformed_identity_matrix"] = bad_results

        valid_results = {
            "builtin_int_creation_time": identity_control(v25_module, 501, 12),
            "builtin_float_creation_time": identity_control(v25_module, 501, 12.5),
        }
        assert all(result["accepted"] for result in valid_results.values())
        cases["finite_positive_identity_controls"] = valid_results

        # A/B reuse is rejected both before first sample and on the post-wait lookup.
        pre_child = FakeProcess(503, 4096, 10.0)
        pre_lookup = FakeProcess(503, 8192, 20.0)
        pre_code, pre_receipt, _ = run_fake(v25_module, base, "v25_presample_generation_mismatch", pre_child, pre_lookup)
        assert pre_code == v25_module.TREE_EVIDENCE_EXIT and pre_receipt["sample_count"] == 0
        assert pre_lookup.terminate_calls == pre_lookup.kill_calls == 0
        cases["presample_A_B_generation_mismatch"] = {
            "exit": pre_code, "sample_count": pre_receipt["sample_count"],
            "binding": pre_receipt["root_identity_binding"],
            "unbound_lookup_signals": [pre_lookup.terminate_calls, pre_lookup.kill_calls],
        }

        post_child = FakeProcess(504, 4096, 10.0)
        post_lookup = FakeProcess(504, 8192, 10.0)
        def replace_pid_after_wait(_child):
            post_lookup.created = 20.0
            post_lookup.alive = False
        post_child.wait_hook = replace_pid_after_wait
        post_code, post_receipt, _ = run_fake(v25_module, base, "v25_postwait_generation_mismatch", post_child, post_lookup)
        assert post_code == v25_module.TREE_EVIDENCE_EXIT
        assert post_receipt["natural_root_exit_identity_check"]["status"] == "failed"
        assert post_receipt["tree_exit_proven"] is False
        cases["postwait_A_B_generation_mismatch"] = {
            "exit": post_code, "natural_exit_check": post_receipt["natural_root_exit_identity_check"],
            "tree_exit_proven": post_receipt["tree_exit_proven"],
        }

    print(json.dumps({
        "protocol_sha256": sha256(protocol_path),
        "v24_protocol_sha256": sha256(v24_protocol_path),
        "v25_pin_count_rehashed": len(pin_map),
        "v24_pin_records_preserved_exact": len(v24_pin_map) - len(missing) - len(changed),
        "missing_v24_pins": missing, "changed_v24_pins": changed,
        "added_v25_pins": added,
        "scope_key_count": scope["scope_key_count"], "resource_contract": resources,
        "planned_output_leaf_absent": True, "runtime_authorized": False,
        "controls": cases,
        "review_verdict": "PASS_STATIC_CONTRACT" if old_code == 0 and new_code == 99 else "NO_GO",
        "no_freegs_or_julia_execution": True,
    }, indent=2, sort_keys=True, allow_nan=False))


if __name__ == "__main__":
    main()
