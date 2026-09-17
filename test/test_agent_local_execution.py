"""Dispatch/integrity regressions, not Genome or physics acceptance."""
import contextlib
import copy
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

from tools.agent_local_execution import PLAN, file_record, main, preflight, verify_records


ROOT = Path(__file__).resolve().parents[1]
POLICY = json.loads((ROOT / PLAN / "execution_policy.json").read_text(encoding="utf-8"))


class AgentLocalExecutionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        (self.root / PLAN).mkdir(parents=True)
        self.save("execution_policy.json", copy.deepcopy(POLICY))
        self.manifest = {
            "execution_policy": "execution_policy.json",
            "tasks": [
                {"id": "A", "status": "accepted", "depends_on": [], "acceptance_record": "a.md"},
                {"id": "B", "status": "planned", "depends_on": ["A"]},
                {"id": "C", "status": "planned", "depends_on": ["B"]},
            ],
        }
        self.save("task_manifest.json", self.manifest)
        (self.root / "a.md").write_text("actual software scope", encoding="utf-8")
        (self.root / "input.txt").write_text("actual input", encoding="utf-8")

    def save(self, name, data):
        (self.root / PLAN / name).write_text(json.dumps(data), encoding="utf-8")

    def cli(self, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = main(["--root", str(self.root), *args])
        return code, json.loads(out.getvalue())

    def run_command(self, script, directory="result"):
        return self.cli("--task", "B", "--input", "input.txt", "--output", directory,
                        "--run", sys.executable, "-B", "-c", script)

    def test_no_external_material_required_and_real_command_runs(self):
        self.assertFalse(any("external" in p.name for p in self.root.iterdir()))
        self.assertEqual(preflight(self.root)["ready_tasks"], ["B"])
        code, result = self.run_command("from pathlib import Path; print(Path('input.txt').read_text())")
        self.assertEqual(code, 0)
        self.assertEqual(result["status"], "command_completed")
        self.assertEqual(result["exit_code"], 0)
        self.assertFalse(result["scientific_acceptance"])
        self.assertEqual((self.root / "result/stdout.txt").read_text().strip(), "actual input")
        self.assertTrue((self.root / "result/run.json").is_file())

    def test_unfinished_technical_dependency_still_blocks(self):
        result = preflight(self.root, "C")
        self.assertEqual(result["status"], "blocked_technical_dependency")
        self.assertEqual(result["unmet_technical_dependencies"], ["B"])

    def test_only_planned_and_ready_tasks_are_dispatchable(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["tasks"][1]["status"] = "ready"
        self.save("task_manifest.json", manifest)
        result = preflight(self.root)
        self.assertEqual(result["status"], "ready")
        self.assertEqual(result["ready_tasks"], ["B"])
        self.assertEqual(preflight(self.root, "B")["status"], "ready")

    def test_non_dispatchable_task_statuses_fail_closed(self):
        for status in ("running", "review_pending", "changes_requested", "blocked_external"):
            with self.subTest(status=status):
                manifest = copy.deepcopy(self.manifest)
                manifest["tasks"][1]["status"] = status
                self.save("task_manifest.json", manifest)
                result = preflight(self.root, "B")
                self.assertEqual(result["status"], "non_dispatchable_task_status")
                self.assertIn(f"non_dispatchable_task_status:B:{status}", result["errors"])
                code, cli_result = self.cli("--task", "B")
                self.assertEqual(code, 2)
                self.assertEqual(cli_result["status"], "non_dispatchable_task_status")
                self.assertNotIn("B", preflight(self.root)["ready_tasks"])

    def test_accepted_task_is_not_dispatchable(self):
        result = preflight(self.root, "A")
        self.assertEqual(result["status"], "non_dispatchable_task_status")
        self.assertIn("non_dispatchable_task_status:A:accepted", result["errors"])
        code, cli_result = self.cli("--task", "A")
        self.assertEqual(code, 2)
        self.assertEqual(cli_result["status"], "non_dispatchable_task_status")
        self.assertNotIn("A", preflight(self.root)["ready_tasks"])

    def test_acceptance_without_archive_does_not_unlock(self):
        (self.root / "a.md").unlink()
        self.assertEqual(preflight(self.root, "B")["status"], "blocked_technical_dependency")

    def test_unknown_task_and_profile_rejected(self):
        self.assertEqual(preflight(self.root, "unknown")["status"], "invalid")
        policy = copy.deepcopy(POLICY)
        policy["default_profile"] = "external_override"
        self.save("execution_policy.json", policy)
        self.assertEqual(preflight(self.root)["status"], "invalid")

    def test_external_gate_cannot_silently_return(self):
        for key, value in [("external_requirements", ["TSA"]),
                           ("external_approval_required", True),
                           ("external_certification_blocks_execution", True)]:
            with self.subTest(key=key):
                policy = copy.deepcopy(POLICY)
                policy[key] = value
                self.save("execution_policy.json", policy)
                self.assertEqual(preflight(self.root)["status"], "invalid")

    def test_missing_input_does_not_start_process(self):
        code, result = self.cli("--task", "B", "--input", "missing.txt", "--output", "result",
                                "--run", sys.executable, "-c", "raise Exception('must not run')")
        self.assertEqual(code, 2)
        self.assertEqual(result["status"], "invalid")
        self.assertFalse((self.root / "result").exists())

    def test_changed_input_rejected_before_or_after_execution(self):
        record = file_record(self.root, "input.txt")
        (self.root / "input.txt").write_text("changed", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "input_changed"):
            verify_records(self.root, [record])
        code, result = self.run_command("from pathlib import Path; Path('input.txt').write_text('changed again')")
        self.assertEqual(code, 2)
        self.assertEqual(result["status"], "input_changed_during_execution")

    def test_nonzero_command_exit_is_preserved(self):
        code, result = self.run_command("raise SystemExit(7)")
        self.assertEqual(code, 2)
        self.assertEqual(result["exit_code"], 7)
        self.assertEqual(result["status"], "command_failed")

    def test_existing_run_is_not_overwritten(self):
        self.assertEqual(self.run_command("print('first')")[0], 0)
        original = (self.root / "result/run.json").read_bytes()
        self.assertEqual(self.run_command("print('second')")[0], 2)
        self.assertEqual((self.root / "result/run.json").read_bytes(), original)

    def test_invalid_executable_is_recorded(self):
        code, result = self.cli("--task", "B", "--input", "input.txt", "--output", "result",
                                "--run", str(self.root / "missing.exe"))
        self.assertEqual(code, 2)
        self.assertEqual(result["status"], "program_exception")
        self.assertTrue((self.root / "result/run.json").is_file())

    def test_input_path_cannot_escape_repository(self):
        with self.assertRaisesRegex(ValueError, "input_outside_repository"):
            file_record(self.root, "../outside.txt")

    def test_acceptance_record_parent_escape_is_invalid(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["tasks"][0]["acceptance_record"] = "../outside_acceptance.md"
        self.save("task_manifest.json", manifest)
        result = preflight(self.root, "B")
        self.assertEqual(result["status"], "invalid")
        self.assertTrue(any("acceptance_record_outside_repository" in error
                            for error in result["errors"]))

    def test_acceptance_record_external_symlink_is_invalid_when_supported(self):
        outside = Path(self.temp.name).parent / "outside_acceptance_for_review.md"
        outside.write_text("outside", encoding="utf-8")
        link = self.root / "linked_acceptance.md"
        try:
            os.symlink(outside, link)
        except (OSError, NotImplementedError) as exc:
            self.skipTest(f"symlink unavailable: {exc}")
        manifest = copy.deepcopy(self.manifest)
        manifest["tasks"][0]["acceptance_record"] = "linked_acceptance.md"
        self.save("task_manifest.json", manifest)
        result = preflight(self.root, "B")
        self.assertEqual(result["status"], "invalid")

    def test_duplicate_dependency_is_invalid(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["tasks"][1]["depends_on"] = ["A", "A"]
        self.save("task_manifest.json", manifest)
        self.assertEqual(preflight(self.root)["status"], "invalid")

    def test_missing_dependency_is_invalid(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["tasks"][1]["depends_on"] = ["MISSING"]
        self.save("task_manifest.json", manifest)
        result = preflight(self.root)
        self.assertEqual(result["status"], "invalid")
        self.assertIn("manifest_missing_dependency:B:MISSING", result["errors"])

    def test_dependency_cycle_is_invalid(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["tasks"][0]["depends_on"] = ["C"]
        self.save("task_manifest.json", manifest)
        result = preflight(self.root)
        self.assertEqual(result["status"], "invalid")
        self.assertIn("manifest_dependency_cycle", result["errors"])

    def test_illegal_status_is_invalid(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["tasks"][1]["status"] = "surprise"
        self.save("task_manifest.json", manifest)
        result = preflight(self.root)
        self.assertEqual(result["status"], "invalid")
        self.assertIn("manifest_illegal_status:B", result["errors"])

    def test_unknown_policy_field_is_invalid(self):
        policy = copy.deepcopy(POLICY)
        policy["unmodeled_policy_field"] = True
        self.save("execution_policy.json", policy)
        result = preflight(self.root)
        self.assertEqual(result["status"], "invalid")
        self.assertIn("execution_policy_unknown_field:unmodeled_policy_field", result["errors"])

    def test_policy_local_requirements_are_validated(self):
        policy = copy.deepcopy(POLICY)
        policy["local_requirements"] = []
        self.save("execution_policy.json", policy)
        result = preflight(self.root)
        self.assertEqual(result["status"], "invalid")


if __name__ == "__main__":
    unittest.main()
