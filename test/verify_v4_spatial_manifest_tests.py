"""Focused tests for the W24 artifact and execution-ledger checker."""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
CHECKER = REPO / "scripts" / "verify_v4_spatial_manifest.py"
HEAD = "4b69f55f7f80240147a65a22809dc1207824dde2"
CASES = [
    "nominal_coarse",
    "nominal_fine",
    "flux_low_coarse",
    "flux_high_coarse",
]
REQUIRED_STAGES = (
    "candidate", "upstream_DESC", "physics", "engineering",
    "verification", "whole", "manifest",
)


def _write(path: Path, content: str) -> str:
    path.write_text(content, encoding="utf-8")
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _event(stage: str, state: str = "completed", classification: str = "completed"):
    return {
        "stage": stage,
        "execution_state": state,
        "classification": classification,
    }


def _make_run(root: Path, *, missing_stage: str | None = None,
              historical_exception: bool = False) -> Path:
    run = root / "run"
    run.mkdir()
    records = {}
    for name in ("julia", "project", "manifest", "environment"):
        path = run / f"{name}.txt"
        records[name] = {"path": str(path), "sha256": _write(path, name)}

    ledger_path = run / "execution_ledger.jsonl"
    records["execution_ledger"] = {
        "path": str(ledger_path),
        "sha256": "pending",
    }
    result = {
        "candidate_hash": "candidate",
        "context_hash": "context",
        "status": "deferred",
        "physical_validation": "unsupported",
        "p5_ready": False,
        "credible_device_count": 0,
    }
    physics = {
        "candidate_hash": "candidate",
        "context_hash": "context",
        "solver_exit_code": 4,
        "cases": [{"case_id": case} for case in CASES],
    }
    engineering = {
        "candidate_hash": "candidate",
        "context_hash": "context",
        "solver_exit_code": 0,
        "cases": [{"case_id": case} for case in CASES],
    }
    verification = {
        "candidate_hash": "candidate",
        "context_hash": "context",
        "solver_exit_code": 0,
    }
    json_paths = {}
    for name, value in (("result", result), ("physics", physics),
                        ("engineering", engineering),
                        ("verification", verification)):
        path = run / f"{name}.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        json_paths[name] = path

    runner = run / "runner.exit"
    _write(runner, "0\n")
    initial_head = run / "initial_head.txt"
    _write(initial_head, f"{HEAD}\n")

    events = []
    for stage in REQUIRED_STAGES:
        if stage == missing_stage:
            continue
        if stage == "whole" and historical_exception:
            events.append(_event(stage, classification="program_exception"))
        events.append(_event(stage))
    ledger_path.write_text(
        "\n".join(json.dumps(event) for event in events) + "\n",
        encoding="utf-8",
    )
    records["execution_ledger"]["sha256"] = hashlib.sha256(
        ledger_path.read_bytes()).hexdigest()

    artifacts = []
    for path in (json_paths["result"], json_paths["physics"],
                 json_paths["engineering"], json_paths["verification"],
                 runner, initial_head):
        artifacts.append({"path": str(path), "sha256": hashlib.sha256(
            path.read_bytes()).hexdigest()})
    manifest = {
        "julia_executable": records["julia"],
        "project": records["project"],
        "manifest": records["manifest"],
        "environment": records["environment"],
        "execution_ledger": records["execution_ledger"],
        "sources": [],
        "artifacts": artifacts,
        "candidate_hash": "candidate",
        "context_hash": "context",
        "result_hash": {"value": hashlib.sha256(
            json_paths["result"].read_bytes()).hexdigest()},
        "process_exit_code": 0,
        "physical_solver_exit_code": 4,
        "engineering_solver_exit_code": 0,
        "verification_exit_code": 0,
        "p5_ready": False,
        "credible_device_count": 0,
        "starting_head": HEAD,
    }
    (run / "execution_manifest.json").write_text(
        json.dumps(manifest), encoding="utf-8")
    return run


class VerifySpatialManifestTests(unittest.TestCase):
    def _run_checker(self, run: Path):
        report = run.parent / "report.json"
        completed = subprocess.run(
            [sys.executable, str(CHECKER), str(run), str(report)],
            cwd=REPO,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertTrue(report.is_file(), completed.stderr)
        return completed, json.loads(report.read_text(encoding="utf-8"))

    def test_clean_completed_ledger_passes_without_exception(self):
        with tempfile.TemporaryDirectory() as directory:
            completed, report = self._run_checker(_make_run(Path(directory)))
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(report["status"], "pass")
        self.assertTrue(report["ledger_recovery_history_ok"])
        self.assertEqual(report["program_exception_events"], 0)

    def test_missing_terminal_stage_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            completed, report = self._run_checker(
                _make_run(Path(directory), missing_stage="verification"))
        self.assertEqual(completed.returncode, 1, completed.stderr)
        self.assertEqual(report["status"], "fail")
        self.assertFalse(report["ledger_recovery_history_ok"])

    def test_historical_exception_does_not_prove_recovery(self):
        with tempfile.TemporaryDirectory() as directory:
            completed, report = self._run_checker(
                _make_run(Path(directory), historical_exception=True))
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(report["status"], "pass")
        self.assertTrue(report["ledger_recovery_history_ok"])
        self.assertEqual(report["program_exception_events"], 1)


if __name__ == "__main__":
    unittest.main()
