from __future__ import annotations

import copy
import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "up1_external_closure_r2"))
from source_axis_binding import AXES, canonical_digest, capture_source_identity, material_digest, source_identity_digest, validate_bundle


def fixture() -> dict:
    cid = "candidate-up1-r2-test-001"
    identity = {
        "identity_schema_version": "UP1-R2.source-identity.v1",
        "repository_locator": "D:/006-Programing/LMC/FusionConceptAI",
        "head": "0123456789abcdef0123456789abcdef01234567",
        "head_tree": "89abcdef0123456789abcdef0123456789abcdef",
        "dirty_status": "dirty",
        "dirty_status_digest": canonical_digest({"status": "dirty", "entries": ["AD56 software bookkeeping"]}),
        "patch_digest": canonical_digest({"patch": "AD56 software bookkeeping patch digest"}),
        "untracked_files": [],
        "untracked_content_digest": canonical_digest([]),
        "submodule_closure": {"applicable": False, "reason": "no submodules in closure"},
    }
    identity["source_identity_digest"] = source_identity_digest(identity)
    materials = []
    for ordinal, axis in enumerate(AXES, 1):
        material = {
            "axis": axis,
            "namespace": f"fusionconceptai://UP1/R2/axis/{axis}",
            "version": "v1",
            "issuer": "typed_absence:external_issuer_unspecified",
            "issued_at": "2026-09-17T00:00:00Z",
            "candidate_id": cid,
            "source_identity_digest": identity["source_identity_digest"],
            "payload": {"fixture": "TEST_ONLY", "ordinal": ordinal},
        }
        material["digest"] = material_digest(material)
        edge = {k: material[k] for k in ("axis", "candidate_id", "namespace", "version", "issuer", "issued_at")}
        edge["source_identity_digest"] = identity["source_identity_digest"]
        edge["material_digest"] = material["digest"]
        material["source_edge"] = edge
        material["candidate_edge"] = copy.deepcopy(edge)
        materials.append(material)
    identity["axis_edges"] = {m["axis"]: m["source_edge"] for m in materials}
    return {
        "schema": "UP1-R2.source-axis-binding.bundle.v1",
        "candidate_id": cid,
        "state": "TEST_ONLY",
        "provenance_class": "test_fixture",
        "ad56": {"source": "AD56", "authority_evidence": False, "classification": "software_bookkeeping_only"},
        "source_identity": identity,
        "axis_materials": materials,
        "candidate_axis_edges": {m["axis"]: m["candidate_edge"] for m in materials},
    }


class SourceAxisBindingTests(unittest.TestCase):
    def test_capture_records_git_identity_without_authority(self):
        identity = capture_source_identity(ROOT)
        self.assertRegex(identity["head"], r"^[0-9a-f]{40}$")
        self.assertRegex(identity["dirty_status_digest"], r"^[0-9a-f]{64}$")
        self.assertRegex(identity["patch_digest"], r"^[0-9a-f]{64}$")
        self.assertEqual(identity["source_identity_digest"], source_identity_digest(identity))

    def test_missing_fresh_observed_source_is_fail_closed(self):
        receipt = validate_bundle(fixture())
        self.assertFalse(receipt["valid"])
        self.assertIn("missing_observed_source", {e["code"] for e in receipt["errors"]})

    def test_labels_cannot_escalate_typed_absent_issuer(self):
        value = fixture()
        value["state"] = "EXTERNAL_ISSUED"
        value["provenance_class"] = "external_issued"
        receipt = validate_bundle(value, value["source_identity"])
        self.assertFalse(receipt["valid"])
        self.assertFalse(receipt["authority_evidence"])
        self.assertIn("missing_external_authority", {e["code"] for e in receipt["errors"]})

    def test_complete_join_is_test_only_non_evidence(self):
        receipt = validate_bundle(fixture(), fixture()["source_identity"])
        self.assertTrue(receipt["valid"], receipt)
        self.assertEqual(receipt["status"], "TEST_ONLY")
        self.assertFalse(receipt["authority_evidence"])
        self.assertEqual(set(receipt["axis_set"]), set(AXES))
        self.assertTrue(receipt["checks"]["bidirectional_edges"])

    def test_missing_duplicate_unknown_and_foreign_are_rejected(self):
        missing = fixture()
        missing["axis_materials"] = missing["axis_materials"][:-1]
        self.assertIn("missing_axis", {e["code"] for e in validate_bundle(missing, missing["source_identity"])["errors"]})
        duplicate = fixture()
        duplicate["axis_materials"].append(copy.deepcopy(duplicate["axis_materials"][0]))
        self.assertIn("duplicate_axis", {e["code"] for e in validate_bundle(duplicate, duplicate["source_identity"])["errors"]})
        unknown = fixture()
        unknown["axis_materials"][0]["axis"] = "unknown_axis"
        self.assertIn("unknown_axis", {e["code"] for e in validate_bundle(unknown, unknown["source_identity"])["errors"]})
        foreign = fixture()
        foreign["axis_materials"][0]["candidate_id"] = "foreign-candidate"
        self.assertIn("foreign_candidate", {e["code"] for e in validate_bundle(foreign, foreign["source_identity"])["errors"]})

    def test_hash_drift_and_edge_contradictions_fail_closed(self):
        altered = fixture()
        altered["axis_materials"][0]["payload"]["ordinal"] = 999
        self.assertIn("hash_mismatch", {e["code"] for e in validate_bundle(altered, altered["source_identity"])["errors"]})
        observed = copy.deepcopy(fixture()["source_identity"])
        observed["patch_digest"] = "f" * 64
        self.assertIn("source_drift", {e["code"] for e in validate_bundle(fixture(), observed)["errors"]})
        edge = fixture()
        edge["candidate_axis_edges"][AXES[0]]["version"] = "v2"
        self.assertIn("candidate_edge_missing_or_ambiguous", {e["code"] for e in validate_bundle(edge, edge["source_identity"])["errors"]})

    def test_external_material_absence_is_typed(self):
        value = json.loads((Path(__file__).parent / "fixtures" / "typed_absence.json").read_text(encoding="utf-8"))
        receipt = validate_bundle(value, value["source_identity"])
        self.assertTrue(receipt["valid"], receipt)
        self.assertEqual(receipt["status"], "typed_absence")
        self.assertEqual(receipt["admission"], "terminal_deferred")
        self.assertFalse(receipt["authority_evidence"])

    def test_negative_fixture_is_fail_closed(self):
        value = json.loads((Path(__file__).parent / "fixtures" / "negative_source_hash.json").read_text(encoding="utf-8"))
        receipt = validate_bundle(value, value["source_identity"])
        self.assertFalse(receipt["valid"])
        self.assertEqual(receipt["status"], "fail_closed")
        self.assertIn("hash_mismatch", {e["code"] for e in receipt["errors"]})

    def test_json_cli_has_machine_exit(self):
        source = ROOT / "tools" / "up1_external_closure_r2" / "source_axis_binding"
        env = dict(os.environ)
        env["PYTHONPATH"] = str(source.parent)
        proc = subprocess.run([sys.executable, "-B", "-m", "source_axis_binding", "--input", str(Path(__file__).parent / "fixtures" / "typed_absence.json"), "--observed-source", str(Path(__file__).parent / "fixtures" / "observed_source.json")], cwd=source.parent, env=env, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout)["status"], "typed_absence")

    def test_strict_schema_rejects_unknown_and_scalar_edges(self):
        value = fixture()
        value["unknown_field"] = True
        value["source_identity"]["unknown_field"] = True
        value["axis_materials"][0]["unknown_field"] = True
        value["candidate_axis_edges"]["extra"] = []
        receipt = validate_bundle(value, value["source_identity"])
        codes = {e["code"] for e in receipt["errors"]}
        self.assertIn("unknown_field", codes)
        self.assertFalse(receipt["valid"])

    def test_evil_schema_state_provenance_and_nested_unknown_are_closed(self):
        for key, value in (("schema", "evil.schema.v99"), ("state", "EVIL_STATE"), ("provenance_class", "evil_profile")):
            candidate = fixture()
            candidate[key] = value
            receipt = validate_bundle(candidate, candidate["source_identity"])
            self.assertFalse(receipt["valid"])
            self.assertFalse(receipt["authority_evidence"])
        nested = fixture()
        nested["source_identity"]["submodule_closure"]["evil"] = True
        nested["ad56"]["authority_evidence"] = True
        receipt = validate_bundle(nested, nested["source_identity"])
        self.assertFalse(receipt["valid"])
        self.assertFalse(receipt["authority_evidence"])
        self.assertIn("unknown_field", {e["code"] for e in receipt["errors"]})

    def test_duplicate_json_key_is_fail_closed(self):
        source = ROOT / "tools" / "up1_external_closure_r2" / "source_axis_binding"
        env = dict(os.environ)
        env["PYTHONPATH"] = str(source.parent)
        text = '{"schema":"UP1-R2.source-axis-binding.bundle.v1","schema":"duplicate"}'
        proc = subprocess.run([sys.executable, "-B", "-m", "source_axis_binding"], cwd=source.parent, env=env, input=text, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 1)
        self.assertEqual(json.loads(proc.stdout)["errors"][0]["code"], "duplicate_json_key")

    def test_two_process_cli_is_byte_deterministic(self):
        source = ROOT / "tools" / "up1_external_closure_r2" / "source_axis_binding"
        env = dict(os.environ)
        env["PYTHONPATH"] = str(source.parent)
        args = [sys.executable, "-B", "-m", "source_axis_binding", "--input", str(Path(__file__).parent / "fixtures" / "typed_absence.json"), "--observed-source", str(Path(__file__).parent / "fixtures" / "observed_source.json")]
        first = subprocess.run(args, cwd=source.parent, env=env, capture_output=True)
        second = subprocess.run(args, cwd=source.parent, env=env, capture_output=True)
        self.assertEqual(first.returncode, second.returncode)
        self.assertEqual(first.stdout, second.stdout)
        self.assertEqual(first.stderr, second.stderr)


if __name__ == "__main__":
    unittest.main()
