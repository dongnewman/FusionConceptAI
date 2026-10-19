"""Python-only fake-process controls for the FreeGS v23 supervisor."""
from __future__ import annotations

import importlib.util
import copy
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/up4_reference_validation/freegs_process_supervisor_v23.py"
SPEC = importlib.util.spec_from_file_location("freegs_process_supervisor_v23_test", SOURCE)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
import sys
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class FakeNoSuchProcess(Exception):
    pass


class FakeAccessDenied(Exception):
    pass


class FakeTimeoutExpired(Exception):
    pass


class FakeProcess:
    def __init__(self, pid: int, rss: int, *, create_time: float | None = None):
        self.pid = pid
        self.rss = rss
        self.created = float(pid if create_time is None else create_time)
        self.alive = True
        self.child_list: list[FakeProcess] = []
        self.children_error: Exception | None = None
        self.rss_error: Exception | None = None
        self.identity_error: Exception | None = None
        self.state_error: Exception | None = None
        self.terminate_error: Exception | None = None
        self.kill_error: Exception | None = None
        self.terminate_leaves_alive = True
        self.kill_leaves_alive = False
        self.exit_code = 0
        self.natural_exit_on_wait = False

    def create_time(self) -> float:
        if self.identity_error:
            raise self.identity_error
        return self.created

    def children(self, recursive: bool = False) -> list[FakeProcess]:
        if self.children_error:
            raise self.children_error
        if not recursive:
            return list(self.child_list)
        found: list[FakeProcess] = []
        pending = list(self.child_list)
        while pending:
            item = pending.pop(0)
            found.append(item)
            pending[0:0] = item.child_list
        return found

    def memory_info(self):
        if self.rss_error:
            raise self.rss_error
        if not self.alive:
            raise FakeNoSuchProcess("process exited before RSS read")
        return type("MemoryInfo", (), {"rss": self.rss})()

    def is_running(self) -> bool:
        if self.state_error:
            raise self.state_error
        return self.alive

    def terminate(self) -> None:
        if self.terminate_error:
            raise self.terminate_error
        if not self.terminate_leaves_alive:
            self.alive = False

    def kill(self) -> None:
        if self.kill_error:
            raise self.kill_error
        if not self.kill_leaves_alive:
            self.alive = False

    def wait(self, timeout: float | None = None) -> int:
        if self.natural_exit_on_wait:
            self.alive = False
            self.children_error = FakeNoSuchProcess("root exited")
            return self.exit_code
        if self.alive:
            raise FakeTimeoutExpired("still running")
        return self.exit_code


class FakeAPI:
    NoSuchProcess = FakeNoSuchProcess
    AccessDenied = FakeAccessDenied
    TimeoutExpired = FakeTimeoutExpired

    @staticmethod
    def wait_procs(processes, timeout=0):
        alive = [process for process in processes if process.alive]
        gone = [process for process in processes if not process.alive]
        return gone, alive


class HarnessAPI(FakeAPI):
    root: FakeProcess | None = None
    launch_count = 0

    @classmethod
    def Popen(cls, command, **kwargs):
        assert cls.root is not None
        cls.launch_count += 1
        return cls.root

    @classmethod
    def Process(cls, pid):
        assert cls.root is not None and cls.root.pid == pid
        return cls.root


def required_manifest_args(base: Path) -> tuple[list[str], list[Path]]:
    import hashlib

    path = base / "pinned_files.json"
    path.write_text(json.dumps({"schema": MODULE.PIN_MANIFEST_SCHEMA, "pins": []}), encoding="utf-8")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return [f"{path.resolve()}={digest}"], [path.resolve()]


class FakeProcessSupervisorV23Tests(unittest.TestCase):
    def test_complete_recursive_snapshot_records_each_process_and_full_rss(self):
        root = FakeProcess(100, 1000)
        child = FakeProcess(101, 2000)
        grandchild = FakeProcess(102, 3000)
        root.child_list = [child]
        child.child_list = [grandchild]
        snapshot = MODULE.observe_process_tree(root, FakeAPI)
        self.assertEqual(snapshot.rss_bytes, 6000)
        self.assertEqual([item["pid"] for item in snapshot.processes], [100, 101, 102])
        self.assertEqual(len(snapshot.handles), 3)

    def test_access_denied_enumeration_invalidates_sample(self):
        root = FakeProcess(100, 1000)
        root.children_error = FakeAccessDenied("cannot enumerate descendants")
        with self.assertRaisesRegex(MODULE.ProcessTreeEvidenceError, "recursive_enumeration"):
            MODULE.observe_process_tree(root, FakeAPI)

    def test_no_such_process_enumeration_race_invalidates_sample(self):
        root = FakeProcess(100, 1000)
        root.children_error = FakeNoSuchProcess("root exited during sample")
        with self.assertRaisesRegex(MODULE.ProcessTreeEvidenceError, "recursive_enumeration"):
            MODULE.observe_process_tree(root, FakeAPI)

    def test_access_denied_rss_does_not_return_partial_total(self):
        root = FakeProcess(100, 1000)
        child = FakeProcess(101, 2000)
        child.rss_error = FakeAccessDenied("rss denied")
        root.child_list = [child]
        with self.assertRaisesRegex(MODULE.ProcessTreeEvidenceError, "rss_read"):
            MODULE.observe_process_tree(root, FakeAPI)

    def test_no_such_process_rss_race_does_not_return_partial_total(self):
        root = FakeProcess(100, 1000)
        child = FakeProcess(101, 2000)
        child.rss_error = FakeNoSuchProcess("exited between enumeration and RSS")
        root.child_list = [child]
        with self.assertRaisesRegex(MODULE.ProcessTreeEvidenceError, "rss_read"):
            MODULE.observe_process_tree(root, FakeAPI)

    def test_duplicate_identity_is_counted_once(self):
        root = FakeProcess(100, 1000)
        child = FakeProcess(101, 2000)
        root.child_list = [child, child]
        snapshot = MODULE.observe_process_tree(root, FakeAPI)
        self.assertEqual(snapshot.rss_bytes, 3000)
        self.assertEqual(len(snapshot.identities), 2)

    def test_reused_pid_with_different_creation_time_is_distinct_identity(self):
        root = FakeProcess(100, 1000)
        first = FakeProcess(101, 2000, create_time=1.0)
        second = FakeProcess(101, 3000, create_time=2.0)
        root.child_list = [first, second]
        snapshot = MODULE.observe_process_tree(root, FakeAPI)
        self.assertEqual(snapshot.rss_bytes, 6000)
        self.assertEqual(len(snapshot.identities), 3)

    def test_root_pid_with_wrong_creation_time_cannot_replace_exact_root_identity(self):
        root = FakeProcess(100, 1000, create_time=10.0)
        fake_root_alias = FakeProcess(100, 2000, create_time=11.0)
        root.child_list = [fake_root_alias]
        with self.assertRaisesRegex(MODULE.ProcessTreeEvidenceError, "root_identity_membership"):
            MODULE.observe_process_tree(root, FakeAPI)

    def test_manifest_expands_pins_and_rejects_changed_file(self):
        import hashlib

        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            pinned = base / "pinned.txt"
            pinned.write_text("frozen", encoding="utf-8")
            manifest = base / "pins.json"
            payload = {
                "schema": MODULE.PIN_MANIFEST_SCHEMA,
                "pins": [{"path": str(pinned.resolve()), "sha256": hashlib.sha256(pinned.read_bytes()).hexdigest()}],
            }
            manifest.write_text(json.dumps(payload), encoding="utf-8")
            manifest_hash = hashlib.sha256(manifest.read_bytes()).hexdigest()
            expanded, errors = MODULE._expand_required_files([f"{manifest.resolve()}={manifest_hash}"], [manifest.resolve()])
            self.assertEqual(errors, [])
            self.assertEqual(len(expanded), 2)
            self.assertTrue(all(item["status"] == "match" for item in expanded))
            pinned.write_text("changed", encoding="utf-8")
            expanded_after, errors_after = MODULE._expand_required_files([f"{manifest.resolve()}={manifest_hash}"], [manifest.resolve()])
            self.assertEqual(len(expanded_after), 2)
            self.assertTrue(any("hash_mismatch" in error for error in errors_after))

    def test_manifest_requires_its_own_direct_sha_pin(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "pins.json"
            manifest.write_text(json.dumps({"schema": MODULE.PIN_MANIFEST_SCHEMA, "pins": []}), encoding="utf-8")
            _, errors = MODULE._expand_required_files([], [manifest.resolve()])
            self.assertTrue(any("direct SHA pin" in error for error in errors))

    def test_access_denied_during_cleanup_never_proves_tree_exit(self):
        root = FakeProcess(100, 1000)
        child = FakeProcess(101, 2000)
        root.child_list = [child]
        rid = MODULE._identity(root, FakeAPI, "test")
        tracked = {rid.key(): (rid, root), (101, 101.0): (MODULE._identity(child, FakeAPI, "test"), child)}
        child.terminate_error = FakeAccessDenied("terminate denied")
        child.kill_error = FakeAccessDenied("kill denied")
        result = MODULE.stop_and_verify(root, rid, tracked, FakeAPI, timeout_seconds=0)
        self.assertFalse(result["tree_exit_proven"])
        self.assertFalse(result["residual_audit"]["all_tracked_descendants_gone"])
        self.assertTrue(any(item["status"] == "failed" for item in result["operations"]))

    def test_wait_still_alive_then_kill_and_verify_can_prove_exit(self):
        root = FakeProcess(100, 1000)
        child = FakeProcess(101, 2000)
        root.child_list = [child]
        rid = MODULE._identity(root, FakeAPI, "test")
        cid = MODULE._identity(child, FakeAPI, "test")
        tracked = {rid.key(): (rid, root), cid.key(): (cid, child)}
        result = MODULE.stop_and_verify(root, rid, tracked, FakeAPI, timeout_seconds=0)
        self.assertTrue(result["tree_exit_proven"])
        self.assertEqual(result["waits"][0]["alive_pids"], [100, 101])
        self.assertEqual(result["waits"][1]["alive_pids"], [])

    def test_process_still_alive_after_kill_fails_exit_proof(self):
        root = FakeProcess(100, 1000)
        root.kill_leaves_alive = True
        rid = MODULE._identity(root, FakeAPI, "test")
        result = MODULE.stop_and_verify(root, rid, {rid.key(): (rid, root)}, FakeAPI, timeout_seconds=0)
        self.assertFalse(result["tree_exit_proven"])
        self.assertEqual(result["waits"][1]["alive_pids"], [100])

    def test_supervisor_preserves_natural_exit_only_after_complete_sample_and_exit_audit(self):
        import argparse
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            HarnessAPI.root = FakeProcess(100, 4096)
            HarnessAPI.root.natural_exit_on_wait = True
            direct, manifests = required_manifest_args(base)
            args = argparse.Namespace(
                command=["--", "fake-child"], cwd=base, wall_seconds=180.0, rss_bytes=2147483648,
                stdout=base / "stdout.raw", stderr=base / "stderr.raw", receipt=base / "execution.json",
                env=[], require_file_sha256=direct, require_file_sha256_manifest=manifests,
                require_absent_path=[], name="fake-natural",
            )
            exit_code = MODULE.run_supervised(args, HarnessAPI)
            receipt = __import__("json").loads(args.receipt.read_text(encoding="utf-8"))
        self.assertEqual(exit_code, 0)
        self.assertTrue(receipt["all_samples_complete"])
        self.assertTrue(receipt["tree_exit_proven"])
        self.assertEqual(receipt["evidence_status"], "recorded_complete_samples")
        HarnessAPI.root = None

    def test_supervisor_incomplete_enumeration_cannot_become_natural_exit(self):
        import argparse
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            HarnessAPI.root = FakeProcess(100, 4096)
            HarnessAPI.root.children_error = FakeAccessDenied("enumeration denied")
            direct, manifests = required_manifest_args(base)
            args = argparse.Namespace(
                command=["--", "fake-child"], cwd=base, wall_seconds=180.0, rss_bytes=2147483648,
                stdout=base / "stdout.raw", stderr=base / "stderr.raw", receipt=base / "execution.json",
                env=[], require_file_sha256=direct, require_file_sha256_manifest=manifests,
                require_absent_path=[], name="fake-incomplete",
            )
            exit_code = MODULE.run_supervised(args, HarnessAPI)
            receipt = __import__("json").loads(args.receipt.read_text(encoding="utf-8"))
        self.assertEqual(exit_code, MODULE.TREE_EVIDENCE_EXIT)
        self.assertFalse(receipt["all_samples_complete"])
        self.assertFalse(receipt["tree_exit_proven"])
        self.assertEqual(receipt["harness_exit_code"], MODULE.TREE_EVIDENCE_EXIT)
        HarnessAPI.root = None

    def test_supervisor_rejects_root_exit_with_descendant_still_live(self):
        import argparse
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            root = FakeProcess(100, 4096)
            child = FakeProcess(101, 2048)
            root.child_list = [child]
            root.natural_exit_on_wait = True
            HarnessAPI.root = root
            direct, manifests = required_manifest_args(base)
            args = argparse.Namespace(
                command=["--", "fake-child"], cwd=base, wall_seconds=180.0, rss_bytes=2147483648,
                stdout=base / "stdout.raw", stderr=base / "stderr.raw", receipt=base / "execution.json",
                env=[], require_file_sha256=direct, require_file_sha256_manifest=manifests,
                require_absent_path=[], name="fake-descendant",
            )
            exit_code = MODULE.run_supervised(args, HarnessAPI)
            receipt = __import__("json").loads(args.receipt.read_text(encoding="utf-8"))
        self.assertEqual(exit_code, MODULE.TREE_EVIDENCE_EXIT)
        self.assertEqual(receipt["stop_reason"], "natural_root_exit_with_live_descendants")
        self.assertEqual(receipt["child_exit_code"], 0)
        self.assertFalse(receipt["tree_exit_proven"])
        HarnessAPI.root = None

    def test_supervisor_refuses_to_launch_without_directly_pinned_manifest(self):
        import argparse
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            HarnessAPI.root = FakeProcess(100, 4096)
            HarnessAPI.launch_count = 0
            args = argparse.Namespace(
                command=["--", "fake-child"], cwd=base, wall_seconds=180.0, rss_bytes=2147483648,
                stdout=base / "stdout.raw", stderr=base / "stderr.raw", receipt=base / "execution.json",
                env=[], require_file_sha256=[], require_file_sha256_manifest=[], require_absent_path=[],
                name="fake-no-manifest",
            )
            exit_code = MODULE.run_supervised(args, HarnessAPI)
            receipt = json.loads(args.receipt.read_text(encoding="utf-8"))
        self.assertEqual(exit_code, MODULE.PREFLIGHT_EXIT)
        self.assertEqual(HarnessAPI.launch_count, 0)
        self.assertEqual(receipt["stop_reason"], "preflight_failed")
        HarnessAPI.root = None

    def test_wait_access_denied_never_counts_as_exit_proof(self):
        class WaitDeniedAPI(FakeAPI):
            calls = 0

            @classmethod
            def wait_procs(cls, processes, timeout=0):
                cls.calls += 1
                if cls.calls == 1:
                    raise FakeAccessDenied("wait denied")
                return FakeAPI.wait_procs(processes, timeout)

        root = FakeProcess(100, 1000)
        root.terminate_leaves_alive = False
        rid = MODULE._identity(root, WaitDeniedAPI, "test")
        tracked = {rid.key(): (rid, root)}
        result = MODULE.stop_and_verify(root, rid, tracked, WaitDeniedAPI, timeout_seconds=0)
        self.assertFalse(result["tree_exit_proven"])
        self.assertEqual(result["waits"][0]["status"], "failed")

    def test_unreadable_final_state_is_unknown_not_exited(self):
        root = FakeProcess(100, 1000)
        child = FakeProcess(101, 2000)
        rid = MODULE._identity(root, FakeAPI, "test")
        cid = MODULE._identity(child, FakeAPI, "test")
        tracked = {rid.key(): (rid, root), cid.key(): (cid, child)}
        child.state_error = FakeAccessDenied("final state denied")
        result = MODULE.audit_tracked_processes(tracked, rid, FakeAPI)
        self.assertFalse(result["all_tracked_descendants_gone"])
        self.assertEqual(result["unknown_processes"][0]["pid"], 101)

    def test_root_exit_with_live_descendant_is_detected(self):
        root = FakeProcess(100, 1000)
        child = FakeProcess(101, 2000)
        root.alive = False
        rid = MODULE._identity(root, FakeAPI, "test")
        cid = MODULE._identity(child, FakeAPI, "test")
        tracked = {rid.key(): (rid, root), cid.key(): (cid, child)}
        result = MODULE.audit_tracked_processes(tracked, rid, FakeAPI)
        self.assertFalse(result["all_tracked_descendants_gone"])
        self.assertEqual(result["alive_descendants"][0]["pid"], 101)

    def test_all_tracked_descendants_verified_gone(self):
        root = FakeProcess(100, 1000)
        child = FakeProcess(101, 2000)
        root.alive = False
        child.alive = False
        rid = MODULE._identity(root, FakeAPI, "test")
        cid = MODULE._identity(child, FakeAPI, "test")
        result = MODULE.audit_tracked_processes({rid.key(): (rid, root), cid.key(): (cid, child)}, rid, FakeAPI)
        self.assertTrue(result["all_tracked_descendants_gone"])
        self.assertEqual([item["pid"] for item in result["verified_exited_processes"]], [100, 101])


PROTOCOL = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v14/actual_run_protocol_v23_process_tree_candidate_v1.json"
VERIFIER_PATH = ROOT / "tools/up4_reference_validation/verify_freegs_v23_process_tree_candidate.py"
VERIFIER_SPEC = importlib.util.spec_from_file_location("freegs_v23_protocol_verifier_tests", VERIFIER_PATH)
assert VERIFIER_SPEC is not None and VERIFIER_SPEC.loader is not None
VERIFIER = importlib.util.module_from_spec(VERIFIER_SPEC)
sys.modules[VERIFIER_SPEC.name] = VERIFIER
VERIFIER_SPEC.loader.exec_module(VERIFIER)


class FreeGSV23ProtocolTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.protocol = json.loads(PROTOCOL.read_text(encoding="utf-8"))

    def _validate_mutation(self, mutate):
        candidate = copy.deepcopy(self.protocol)
        mutate(candidate)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "candidate.json"
            path.write_text(json.dumps(candidate, ensure_ascii=False), encoding="utf-8")
            with self.assertRaises(RuntimeError):
                VERIFIER.validate_candidate(path)

    def test_frozen_candidate_passes_static_preflight_and_is_ungranted(self):
        result = VERIFIER.validate_candidate(PROTOCOL)
        self.assertEqual(result["status"], "static_process_tree_candidate_pass_ungranted")
        self.assertEqual(result["dependency_pin_count"], 169)
        self.assertFalse(result["root_resource_slot_granted"])
        self.assertFalse(result["runtime_execution_authorized"])
        self.assertTrue(result["new_output_leaf_absent"])
        self.assertEqual(result["resource_limits"], {"wall_seconds": 180, "rss_bytes": 2147483648, "threads": 1})

    def test_v22_scope_inputs_statuses_and_numerical_policy_are_preserved(self):
        v22_path = ROOT / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v13/actual_run_protocol_v22_scope_contract_candidate_v1.json"
        v22 = json.loads(v22_path.read_text(encoding="utf-8"))
        self.assertEqual(self.protocol["scope"], v22["scope"])
        self.assertEqual(self.protocol["source_inputs"], v22["source_inputs"])
        self.assertEqual(self.protocol["steps"][0]["dynamic_binding"], v22["steps"][0]["dynamic_binding"])
        self.assertEqual(self.protocol["steps"][0]["natural_exit_statuses_by_code"], v22["steps"][0]["natural_exit_statuses_by_code"])
        self.assertEqual(self.protocol["steps"][0]["result_exit_schema_contract"], v22["steps"][0]["result_exit_schema_contract"])

    def test_contract_states_failure_semantics_and_sampled_proof_limit(self):
        contract = self.protocol["process_tree_supervisor_v23"]
        self.assertEqual(contract["resource_exit_codes"], {"preflight": 96, "wall_limit": 97, "rss_limit": 98, "incomplete_or_unproven_tree": 99})
        self.assertIn("never compare a partial sum", contract["sample_race_policy"])
        self.assertIn("every tracked process is verified gone", contract["cleanup_policy"])
        self.assertIn("live or unreadable descendants", contract["natural_exit_policy"])
        self.assertIn("not OS job-object containment", contract["proof_scope"])
        self.assertGreaterEqual(len(contract["negative_controls"]), 9)

    def test_slot_grant_cannot_be_changed(self):
        self._validate_mutation(lambda p: p["root_resource_slot"].update(granted=True))

    def test_solver_input_hash_cannot_change(self):
        self._validate_mutation(lambda p: p["source_inputs"].update(solver_input_sha256="0" * 64))

    def test_resource_cap_cannot_change(self):
        self._validate_mutation(lambda p: p["resource_contract"].update(process_tree_rss_bytes_per_step=2147483647))

    def test_incomplete_sample_exit_code_is_bound(self):
        self._validate_mutation(lambda p: p["resource_contract"].update(incomplete_process_tree_harness_exit=0))

    def test_partial_rss_must_not_be_compared_to_cap(self):
        self._validate_mutation(lambda p: p["resource_contract"].update(partial_rss_never_compared_to_limit=False))

    def test_old_supervisor_argv_is_not_dispatchable(self):
        self._validate_mutation(lambda p: p["steps"][0]["launcher_argv_template"].__setitem__(2, "D:\\old\\run_recorded_process.py"))

    def test_cross_leaf_sidecar_retarget_is_rejected(self):
        self._validate_mutation(lambda p: p["mandatory_evidence_sidecars"].update(execution="D:\\foreign\\execution.json"))

    def test_output_leaf_cannot_reuse_v22_leaf(self):
        self._validate_mutation(lambda p: p["runtime_endpoint_join"].update(output_leaf="D:\\old\\actual_run_r22\\freegs_solve"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
