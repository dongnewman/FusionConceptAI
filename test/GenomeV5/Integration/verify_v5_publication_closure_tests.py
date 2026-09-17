"""Focused tests for the AD-53 closure verifier."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[3] / "scripts" / "verify_v5_publication_closure.py"
SPEC = importlib.util.spec_from_file_location("verify_v5_publication_closure", SCRIPT)
assert SPEC and SPEC.loader
verifier = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verifier)


class ClosureVerifierTests(unittest.TestCase):
    def test_unknown_and_glob_paths_are_rejected(self):
        with self.assertRaises(ValueError):
            verifier.normalized_path("src/**/runs/*.jl")
        with self.assertRaises(ValueError):
            verifier.normalized_path("../outside.jl")

    def test_missing_path_is_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            (repo / "src").mkdir()
            (repo / "src" / "FusionConceptAI.jl").write_text("module FusionConceptAI\nend\n", encoding="utf-8")
            subprocess.run(["git", "-C", str(repo), "add", "."], check=True)
            subprocess.run(["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "base"], check=True)
            report = verifier.inspect_closure(repo, repo / "docs" / "implementation")
            self.assertEqual(report["core_closure_status"], "changes_required")
            self.assertIn("src/GenomeV5/G1/DiffusionDeclarationV1.jl", report["missing_paths"])

    def test_hash_drift_and_acceptance_statuses_do_not_promote(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            evidence = root / "docs" / "implementation" / "AD-52"
            evidence.mkdir(parents=True)
            data = b"current source"
            path = root / "src" / "GenomeV5" / "G1" / "DiffusionDeclarationV1.jl"
            path.parent.mkdir(parents=True)
            path.write_bytes(data)
            old = hashlib.sha256(b"old source").hexdigest()
            evidence.joinpath("acceptance.md").write_text(f"{path.as_posix()} accepted_limited sha256={old}\n", encoding="utf-8")
            status, files = verifier._status_for_evidence(root / "docs" / "implementation", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", hashlib.sha256(data).hexdigest())
            self.assertEqual(status, "hash_drift")
            self.assertTrue(files)
            evidence.joinpath("acceptance.md").write_text(f"src/GenomeV5/G1/DiffusionDeclarationV1.jl accepted_limited {hashlib.sha256(data).hexdigest()}\n", encoding="utf-8")
            status, _ = verifier._status_for_evidence(root / "docs" / "implementation", "src/GenomeV5/G1/DiffusionDeclarationV1.jl", hashlib.sha256(data).hexdigest())
            self.assertEqual(status, "accepted_limited")

    def test_optional_feedback_is_separate(self):
        self.assertEqual(verifier.OPTIONAL_G3_FEEDBACK, "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl")
        self.assertNotIn(verifier.OPTIONAL_G3_FEEDBACK, verifier.CORE_DECLARATION_AND_FACTORIES)
        self.assertEqual(verifier.OPTIONAL_PRODUCTS["g3_binding_editability"]["order"][0], verifier.OPTIONAL_G3_FEEDBACK)

    def test_core_probe_locks_g2_factory_arity(self):
        command = verifier._probe_command()
        probe = command[-1]
        self.assertIn("g2_source_authority_factory_v1(nothing, nothing, nothing, nothing, nothing, nothing)", probe)

    def test_run_temp_without_real_receipt_is_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            (repo / "src").mkdir()
            (repo / "src" / "FusionConceptAI.jl").write_text("module FusionConceptAI\nend\n", encoding="utf-8")
            subprocess.run(["git", "-C", str(repo), "add", "."], check=True)
            subprocess.run(["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "base"], check=True)
            output = repo / "report.json"
            rc = verifier.main(["--repo", str(repo), "--evidence-root", str(repo / "docs" / "implementation"), "--run-temp", "--output", str(output)])
            report = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(rc, 1)
            self.assertEqual(report["overall_status"], "changes_required")
            self.assertEqual(report["temporary_validation"]["status"], "not_executed")

    def test_manifest_separates_base_and_overlay(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            (repo / "src").mkdir()
            (repo / "src" / "FusionConceptAI.jl").write_text("module FusionConceptAI\nend\n", encoding="utf-8")
            subprocess.run(["git", "-C", str(repo), "add", "."], check=True)
            subprocess.run(["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "base"], check=True)
            report = verifier.inspect_closure(repo, repo / "docs" / "implementation")
            self.assertIn("base_head_tracked_dependencies", report)
            self.assertIn("overlay_publication_paths", report)
            self.assertTrue(set(report["base_head_tracked_dependencies"]).isdisjoint(report["overlay_publication_paths"]))

    def test_temporary_checkout_cleanup_on_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            closure = {"core_closure_status": "complete", "base_head_tracked_dependencies": [], "overlay_publication_paths": []}
            with patch.object(verifier, "_process_receipt", side_effect=RuntimeError("synthetic clone failure")):
                result = verifier._run_temp_validation(repo, closure)
            self.assertEqual(result["status"], "fail_closed")
            self.assertTrue(result["temporary_checkout_cleaned"])
            self.assertTrue(result["cleanup"]["cleaned"])

    def test_original_repo_snapshot_function_is_read_only(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            (repo / "x").write_text("x", encoding="utf-8")
            subprocess.run(["git", "-C", str(repo), "add", "x"], check=True)
            subprocess.run(["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "base"], check=True)
            before = verifier._repo_snapshot(repo)
            _ = verifier._repo_snapshot(repo)
            after = verifier._repo_snapshot(repo)
            self.assertEqual(before, after)


if __name__ == "__main__":
    unittest.main()
