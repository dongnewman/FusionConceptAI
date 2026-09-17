from __future__ import annotations

import copy
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE_PACKAGE = ROOT / "tools" / "up1_external_closure_r4"
sys.path.insert(0, str(SOURCE_PACKAGE))

from source_axis_binding import (  # noqa: E402
    AXES,
    CANONICALIZATION_VERSION,
    SCHEMA_VERSION,
    BindingValidationError,
    canonical_bytes,
    canonical_digest,
    canonical_preimage,
    capture_source_identity,
    material_digest,
    raw_observation,
    source_identity_digest,
    validate_bundle,
)


def _identity() -> dict[str, object]:
    """Deterministic synthetic identity used only as local test input."""
    records = [
        raw_observation(b"independent-source\n", "fixture/source.txt"),
        raw_observation(b"axis contract\n", "fixture/contract.txt"),
    ]
    value: dict[str, object] = {
        "identity_schema_version": "UP1-R4.source-identity.v1",
        "repository_locator": "D:/fixture/up1-r4",
        "source_locator": "D:/fixture/up1-r4",
        "source_files": records,
        "raw_bytes": sum(int(item["raw_bytes"]) for item in records),
        "raw_sha256": canonical_digest(records),
        "head": "0123456789abcdef0123456789abcdef01234567",
        "head_tree": "89abcdef0123456789abcdef0123456789abcdef",
        "dirty_status": "dirty",
        "dirty_status_digest": "a" * 64,
        "patch_digest": "b" * 64,
        "untracked_files": [raw_observation(b"untracked\n", "fixture/untracked.txt")],
        "untracked_content_digest": canonical_digest([raw_observation(b"untracked\n", "fixture/untracked.txt")]),
        "submodule_closure": {"applicable": False, "digest": None, "reason": "no .gitmodules"},
    }
    value["git_evidence"] = {key: value[key] for key in ("head", "head_tree", "dirty_status", "dirty_status_digest", "patch_digest", "untracked_files", "untracked_content_digest", "submodule_closure")}
    value["source_identity_digest"] = source_identity_digest(value)
    return value


def _bundle(*, state: str = "TEST_ONLY", provenance: str = "test_fixture") -> dict[str, object]:
    cid, rid = "candidate-r4-independent-001", "run-r4-independent-001"
    identity = _identity()
    candidate_ref = {"id": cid, "sha256": "1" * 64}
    run_ref = {"id": rid, "sha256": "2" * 64}
    authority_ref = {"state": "typed_absent", "value": None, "reason": "external authority is not locally available"}
    materials: list[dict[str, object]] = []
    for ordinal, axis in enumerate(AXES, 1):
        material: dict[str, object] = {
            "axis": axis,
            "material_id": f"material-{ordinal}",
            "namespace": f"up1-r4://fixture/{axis}",
            "version": "v1",
            "issuer": "TEST_ONLY.fixture",
            "issued_at": "2026-09-17T00:00:00Z",
            "candidate_id": cid,
            "run_id": rid,
            "source_identity_digest": identity["source_identity_digest"],
            "payload": {"fixture": "TEST_ONLY", "ordinal": ordinal},
            "raw": raw_observation(f"raw-{axis}".encode("ascii"), f"fixture/raw/{axis}.json"),
            "candidate_ref": candidate_ref,
            "run_ref": run_ref,
            "authority_ref": authority_ref,
        }
        material["digest"] = material_digest(material)
        materials.append(material)
    value: dict[str, object] = {
        "schema": SCHEMA_VERSION,
        "candidate_id": cid,
        "run_id": rid,
        "state": state,
        "provenance_class": provenance,
        "source_identity": identity,
        "axis_materials": materials if state not in {"TYPED_ABSENT", "typed_absent", "typed_absence"} else [],
        "candidate_ref": candidate_ref,
        "run_ref": run_ref,
        "authority_ref": authority_ref,
        "formal_credit": "none",
        "no_publish": True,
    }
    # Digest fields are optional but included to exercise their preimages.
    from source_axis_binding import bundle_digest, bundle_preimage
    value["canonical_preimage_sha256"] = hashlib.sha256(bundle_preimage(value)).hexdigest()
    value["bundle_digest"] = bundle_digest(value)
    return value


class SourceAxisBindingIndependentTests(unittest.TestCase):
    def test_raw_observation_is_lossless_and_locator_normalized(self):
        result = raw_observation(b"abc\x00\xff", r"a\\b.bin")
        self.assertEqual(result["locator"], "a//b.bin")
        self.assertEqual(result["raw_bytes"], 5)
        self.assertEqual(result["raw_sha256"], hashlib.sha256(b"abc\x00\xff").hexdigest())
        with self.assertRaises(ValueError):
            raw_observation("not-bytes", "x")  # type: ignore[arg-type]

    def test_capture_records_raw_source_and_full_git_receipt(self):
        # Use an isolated repository: the shared checkout may be concurrently
        # dirtied by unrelated work, and its untracked closure is intentionally
        # not a stable test fixture.
        with tempfile.TemporaryDirectory(prefix="up1-r4-git-") as temp:
            repo = Path(temp)
            relative = "tracked.txt"
            tracked = repo / relative
            tracked.write_bytes(b"tracked-v1\n")
            subprocess.run(["git", "init", "-q"], cwd=repo, check=True, capture_output=True)
            subprocess.run(["git", "config", "user.email", "test@example.invalid"], cwd=repo, check=True)
            subprocess.run(["git", "config", "user.name", "R4 independent test"], cwd=repo, check=True)
            subprocess.run(["git", "add", relative], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-qm", "fixture"], cwd=repo, check=True)
            tracked.write_bytes(b"tracked-v2\n")
            (repo / "untracked.txt").write_bytes(b"untracked\n")
            first = capture_source_identity(repo, [relative])
            second = capture_source_identity(repo, [relative])
        self.assertEqual(first["source_identity_digest"], source_identity_digest(first))
        self.assertEqual(second["source_identity_digest"], source_identity_digest(second))
        record = first["source_files"][0]
        data = b"tracked-v2\n"
        self.assertEqual(record["locator"], relative)
        self.assertEqual(record["raw_bytes"], len(data))
        self.assertEqual(record["raw_sha256"], hashlib.sha256(data).hexdigest())
        self.assertEqual(first["raw_bytes"], len(data))
        self.assertEqual(first["raw_sha256"], canonical_digest([record]))
        self.assertEqual(first["dirty_status"], "dirty")
        self.assertTrue(first["untracked_files"])
        self.assertEqual(first["untracked_files"][0]["locator"], "untracked.txt")
        self.assertNotEqual(first["patch_digest"], hashlib.sha256(b"").hexdigest())
        self.assertRegex(first["head"], r"^[0-9a-f]{40}$")
        self.assertRegex(first["head_tree"], r"^[0-9a-f]{40}$")
        for key in ("dirty_status_digest", "patch_digest", "untracked_content_digest", "source_identity_digest"):
            self.assertRegex(first[key], r"^[0-9a-f]{64}$")
        self.assertEqual(first["git_evidence"], {key: first[key] for key in ("head", "head_tree", "dirty_status", "dirty_status_digest", "patch_digest", "untracked_files", "untracked_content_digest", "submodule_closure")})
        self.assertIn(first["submodule_closure"]["applicable"], (True, False))

    def test_canonical_integer_only_and_domain_separated_preimage(self):
        self.assertEqual(canonical_bytes({"b": 2, "a": 1}), b'{"a":1,"b":2}')
        self.assertNotEqual(canonical_preimage({"a": 1}, domain="one"), canonical_preimage({"a": 1}, domain="two"))
        self.assertNotEqual(canonical_preimage({"a": 1}, version="v1"), canonical_preimage({"a": 1}, version="v2"))
        for value in ({"x": 1.0}, {1: "bad"}, {"x": float("nan")}):
            with self.assertRaises(ValueError):
                canonical_bytes(value)
        cyclic: list[object] = []
        cyclic.append(cyclic)
        with self.assertRaises(ValueError):
            canonical_bytes(cyclic)
        self.assertEqual(CANONICALIZATION_VERSION, "UP1-R4-CJSON-1")

    def test_complete_four_axis_refs_and_domain_digests_are_test_only(self):
        value = _bundle()
        receipt = validate_bundle(value, copy.deepcopy(value["source_identity"]))
        self.assertTrue(receipt["valid"], receipt)
        self.assertEqual(receipt["status"], "TEST_ONLY")
        self.assertEqual(set(receipt["axis_set"]), set(AXES))
        self.assertEqual(receipt["missing_axes"], [])
        self.assertTrue(receipt["checks"]["exact_axis_set"])
        self.assertTrue(receipt["checks"]["refs_present"])
        self.assertFalse(receipt["authority_evidence"])
        self.assertEqual(receipt["formal_credit"], "none")
        self.assertTrue(receipt["no_publish"])

    def test_typed_absent_is_terminal_non_evidence(self):
        value = _bundle(state="typed_absent", provenance="external_material_absent")
        value["bundle_digest"] = None
        value.pop("bundle_digest")
        value.pop("canonical_preimage_sha256")
        receipt = validate_bundle(value, copy.deepcopy(value["source_identity"]))
        self.assertTrue(receipt["valid"], receipt)
        self.assertEqual(receipt["status"], "typed_absent")
        self.assertEqual(receipt["admission"], "terminal_deferred")
        self.assertEqual(receipt["classification"], "non_evidence")
        self.assertFalse(receipt["authority_evidence"])

    def test_duplicate_unknown_missing_and_nonunique_axes_fail_closed(self):
        value = _bundle()
        value["axis_materials"] = value["axis_materials"][:-1]
        self.assertIn("missing_axis", {e["code"] for e in validate_bundle(value, value["source_identity"])["errors"]})
        duplicate = _bundle()
        duplicate["axis_materials"].append(copy.deepcopy(duplicate["axis_materials"][0]))
        self.assertIn("duplicate_axis", {e["code"] for e in validate_bundle(duplicate, duplicate["source_identity"])["errors"]})
        unknown = _bundle()
        unknown["axis_materials"][0]["axis"] = "evil-axis"
        self.assertIn("unknown_axis", {e["code"] for e in validate_bundle(unknown, unknown["source_identity"])["errors"]})
        extra = _bundle()
        extra["axis_materials"][0]["evil"] = True
        self.assertIn("unknown_field", {e["code"] for e in validate_bundle(extra, extra["source_identity"])["errors"]})

    def test_candidate_run_authority_and_source_joins_cannot_drift(self):
        for field, bad, code in (("candidate_id", "foreign-candidate", "foreign_candidate"), ("run_id", "foreign-run", "foreign_run"), ("source_identity_digest", "f" * 64, "foreign_source_identity")):
            value = _bundle()
            value["axis_materials"][0][field] = bad
            self.assertIn(code, {e["code"] for e in validate_bundle(value, value["source_identity"])["errors"]})
        for ref_key in ("candidate_ref", "run_ref", "authority_ref"):
            value = _bundle()
            value["axis_materials"][0][ref_key] = {"id": "contradictory"}
            self.assertIn("ref_mismatch", {e["code"] for e in validate_bundle(value, value["source_identity"])["errors"]})
        missing = _bundle()
        missing.pop("authority_ref")
        self.assertIn("missing_ref", {e["code"] for e in validate_bundle(missing, missing["source_identity"])["errors"]})

    def test_raw_material_hash_and_material_preimage_drift_fail_closed(self):
        altered = _bundle()
        altered["axis_materials"][0]["raw"]["raw_bytes"] += 1
        self.assertIn("hash_mismatch", {e["code"] for e in validate_bundle(altered, altered["source_identity"])["errors"]})
        payload = _bundle()
        payload["axis_materials"][0]["payload"]["ordinal"] = 999
        self.assertIn("hash_mismatch", {e["code"] for e in validate_bundle(payload, payload["source_identity"])["errors"]})
        changed_id = _bundle()
        changed_id["axis_materials"][0]["material_id"] = "relabelled"
        self.assertIn("hash_mismatch", {e["code"] for e in validate_bundle(changed_id, changed_id["source_identity"])["errors"]})

    def test_source_hash_and_observed_drift_fail_closed(self):
        value = _bundle()
        observed = copy.deepcopy(value["source_identity"])
        observed["patch_digest"] = "f" * 64
        observed["source_identity_digest"] = source_identity_digest(observed)
        self.assertIn("source_drift", {e["code"] for e in validate_bundle(value, observed)["errors"]})
        observed_hash_bad = copy.deepcopy(value["source_identity"])
        observed_hash_bad["source_identity_digest"] = "f" * 64
        self.assertIn("observed_source_hash_mismatch", {e["code"] for e in validate_bundle(value, observed_hash_bad)["errors"]})
        bound_bad = copy.deepcopy(value)
        bound_bad["source_identity"]["raw_sha256"] = "f" * 64
        self.assertIn("hash_mismatch", {e["code"] for e in validate_bundle(bound_bad, bound_bad["source_identity"])["errors"]})

    def test_git_evidence_reverse_mirror_cannot_be_relabelled(self):
        value = _bundle()
        value["source_identity"]["git_evidence"]["head"] = "f" * 40
        receipt = validate_bundle(value, value["source_identity"])
        self.assertIn("git_evidence_mismatch", {e["code"] for e in receipt["errors"]})

    def test_bundle_hash_preimage_and_axis_edge_drift_fail_closed(self):
        value = _bundle()
        value["candidate_axis_edges"] = {axis: {"material_id": "wrong"} for axis in AXES}
        self.assertIn("edge_mismatch", {e["code"] for e in validate_bundle(value, value["source_identity"])["errors"]})
        value = _bundle()
        value["bundle_digest"] = "f" * 64
        self.assertIn("bundle_hash_mismatch", {e["code"] for e in validate_bundle(value, value["source_identity"])["errors"]})
        value = _bundle()
        value["canonical_preimage_sha256"] = "f" * 64
        self.assertIn("preimage_hash_mismatch", {e["code"] for e in validate_bundle(value, value["source_identity"])["errors"]})

    def test_formal_credit_publish_and_external_state_are_irrevocably_closed(self):
        for field, bad, code in (("formal_credit", "credited", "formal_credit_escalation"), ("no_publish", False, "publish_forbidden")):
            value = _bundle()
            value[field] = bad
            receipt = validate_bundle(value, value["source_identity"])
            self.assertIn(code, {e["code"] for e in receipt["errors"]})
            self.assertFalse(receipt["authority_evidence"])
            self.assertEqual(receipt["formal_credit"], "none")
            self.assertTrue(receipt["no_publish"])
        external = _bundle(state="EXTERNAL_ISSUED", provenance="external_issued")
        receipt = validate_bundle(external, external["source_identity"])
        self.assertFalse(receipt["valid"])
        self.assertIn("external_material_not_supported", {e["code"] for e in receipt["errors"]})

    def test_duplicate_json_key_cli_is_adversarial_fail_closed(self):
        env = dict(os.environ)
        env["PYTHONPATH"] = str(SOURCE_PACKAGE)
        proc = subprocess.run([sys.executable, "-B", "-m", "source_axis_binding"], cwd=SOURCE_PACKAGE, env=env, input=b'{"schema":"x","schema":"y"}', capture_output=True)
        self.assertEqual(proc.returncode, 1)
        result = json.loads(proc.stdout)
        self.assertEqual(result["errors"][0]["code"], "duplicate_json_key")
        self.assertFalse(result["authority_evidence"])
        self.assertEqual(result["formal_credit"], "none")

    def test_float_in_canonical_source_is_program_exception_and_non_evidence(self):
        value = _bundle()
        value["source_identity"]["raw_bytes"] = 1.5
        env = dict(os.environ)
        env["PYTHONPATH"] = str(SOURCE_PACKAGE)
        with tempfile.TemporaryDirectory(prefix="up1-r4-float-") as temp:
            input_path = Path(temp) / "bundle.json"
            input_path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True), encoding="utf-8")
            proc = subprocess.run([sys.executable, "-B", "-m", "source_axis_binding", "--input", str(input_path)], cwd=SOURCE_PACKAGE, env=env, capture_output=True)
        self.assertEqual(proc.returncode, 2)
        result = json.loads(proc.stdout)
        self.assertEqual(result["errors"][0]["code"], "program_exception")
        self.assertFalse(result["authority_evidence"])
        self.assertEqual(result["formal_credit"], "none")

    def test_serial_cli_runs_are_byte_identical_with_machine_exit_and_hash(self):
        value = _bundle(state="typed_absent", provenance="external_material_absent")
        observed = value["source_identity"]
        value.pop("bundle_digest", None)
        value.pop("canonical_preimage_sha256", None)
        env = dict(os.environ)
        env["PYTHONPATH"] = str(SOURCE_PACKAGE)
        with tempfile.TemporaryDirectory(prefix="up1-r4-binding-") as temp:
            input_path, observed_path = Path(temp) / "bundle.json", Path(temp) / "observed.json"
            input_path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True), encoding="utf-8")
            observed_path.write_text(json.dumps(observed, ensure_ascii=False, sort_keys=True), encoding="utf-8")
            command = [sys.executable, "-B", "-m", "source_axis_binding", "--input", str(input_path), "--observed-source", str(observed_path)]
            first = subprocess.run(command, cwd=SOURCE_PACKAGE, env=env, capture_output=True)
            second = subprocess.run(command, cwd=SOURCE_PACKAGE, env=env, capture_output=True)
        self.assertEqual(first.returncode, 0)
        self.assertEqual(second.returncode, 0)
        self.assertEqual(first.stdout, second.stdout)
        self.assertEqual(first.stderr, second.stderr)
        self.assertEqual(hashlib.sha256(first.stdout).hexdigest(), hashlib.sha256(second.stdout).hexdigest())
        self.assertEqual(json.loads(first.stdout)["status"], "typed_absent")


if __name__ == "__main__":
    unittest.main(verbosity=2)
