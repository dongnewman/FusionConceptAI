"""Deterministic negative control for a source changing during UP1 freeze."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch


REPO = Path(__file__).resolve().parents[3]
FREEZER_PATH = REPO / "scripts" / "freeze_up1_candidate_inputs.py"
CANDIDATE_REL = Path(
    "benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2"
)


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


class FreezeSourceChangeTest(unittest.TestCase):
    def test_source_changed_after_snapshot_copy_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="up1-freeze-race-") as temporary:
            root = Path(temporary) / "isolated-repo"
            source = root / CANDIDATE_REL / "g1_source.jl"
            original = b"candidate_input = :before\n"
            changed = b"candidate_input = :after\n"
            source.parent.mkdir(parents=True)
            source.write_bytes(original)

            candidate_ref = (
                "fusionconceptai://candidate-design/"
                "local-authored-up4-g123-20260928-r2"
            )
            candidate_id = "local-authored-up4-g123-20260928-r2"
            scenario_id = "scenario-local-authored-up4-g123-20260928-r2"
            identity = root / CANDIDATE_REL / "identity.jl"
            identity_bytes = (
                f'candidate_id = "{candidate_id}"\n'
                f'candidate_ref = "{candidate_ref}"\n'
                f'scenario_id = "{scenario_id}"\n'
            ).encode("utf-8")
            identity.write_bytes(identity_bytes)
            (root / CANDIDATE_REL / "manifest.json").write_text(
                json.dumps({
                    "candidate_id": candidate_id,
                    "candidate_ref": {"id": candidate_ref, "version": "v5"},
                    "scenario_id": scenario_id,
                    "design_status": "unvalidated_design_input",
                    "files": [
                        {"path": "g1_source.jl", "bytes": len(original),
                         "sha256": sha(original)},
                        {"path": "identity.jl", "bytes": len(identity_bytes),
                         "sha256": sha(identity_bytes)},
                    ],
                }),
                encoding="utf-8",
            )
            for relative, content in (
                (Path("Project.toml"), b"name = \"freeze-race-fixture\"\n"),
                (Path("Manifest.toml"), b"# isolated fixture\n"),
                (Path("test/GenomeV5/Integration/up1_frozen_source_t0_v1_tests.jl"),
                 b"# isolated consumer placeholder\n"),
                (Path("docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/"
                      "fresh_candidate_binding_envelope_v1.json"), b"{}\n"),
                (Path("src/fixture.jl"), b"fixture_source = true\n"),
            ):
                destination = root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(content)

            freezer = types.ModuleType("freeze_up1_candidate_inputs_under_test")
            freezer.__file__ = str(FREEZER_PATH)
            code = compile(FREEZER_PATH.read_text(encoding="utf-8"),
                           str(FREEZER_PATH), "exec")
            exec(code, freezer.__dict__)
            freezer.ROOT = root
            output = root / "runs" / "e" / "freeze-source-race"
            snapshot_copy = output / "snapshot" / CANDIDATE_REL / "g1_source.jl"
            real_write_new = freezer.write_new
            mutation_applied = False

            def write_then_mutate(destination: Path, raw: bytes) -> None:
                nonlocal mutation_applied
                real_write_new(destination, raw)
                if destination == snapshot_copy and not mutation_applied:
                    mutation_applied = True
                    source.write_bytes(changed)

            with patch.object(sys, "argv", [str(FREEZER_PATH), "--output-dir", str(output)]), \
                    patch.object(freezer, "write_new", side_effect=write_then_mutate):
                with self.assertRaisesRegex(
                    RuntimeError, "workspace input changed during freeze"
                ):
                    freezer.main()

            self.assertTrue(mutation_applied, "mutation hook did not reach the snapshot copy")
            self.assertEqual(source.read_bytes(), changed)
            self.assertEqual(snapshot_copy.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
