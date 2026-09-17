"""Fresh-process contract tests for the UP1 R2 witness/authority seam."""

from __future__ import annotations

import copy
import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
TOOLS = REPO / "tools"
CLI = TOOLS / "up1_external_closure_r2" / "witness_authority" / "cli.py"
# Import through the repository's unique top-level namespace.  Pytest adds
# ``test`` to sys.path while collecting this suite, where the test package is
# also named ``up1_external_closure_r2``; importing that short name therefore
# resolves to the test package and shadows the production package.
from tools.up1_external_closure_r2.witness_authority.validator import (  # noqa: E402
    AuthorityLedger, _signature_binding_payload, parse_json, sha256_json, validate,
)


def load(name: str) -> dict:
    return json.loads((HERE / "fixtures" / name).read_text(encoding="utf-8"))


def base() -> dict:
    return load("test_only_shape.json")


class WitnessAuthorityTests(unittest.TestCase):
    def test_test_only_is_never_evidence(self) -> None:
        result = validate(base(), now="2026-09-17T00:00:02Z")
        self.assertEqual(result["status"], "non_evidence")
        self.assertTrue(result["non_evidence"])
        self.assertTrue(result["no_publish"])
        self.assertFalse(result["r01_r10_closed"])

    def test_external_witness_absence_is_typed_absence(self) -> None:
        result = validate(load("production_witness_absent.json"), now="2026-09-17T00:00:02Z")
        self.assertEqual(result["resolution"], "typed_absence")
        self.assertEqual(result["error_code"], "ERR_WITNESS_EXTERNAL_ABSENT")
        self.assertEqual(result["status"], "typed_absence")
        self.assertTrue(result["terminal_deferred"])

    def test_external_signature_and_authority_absence_are_typed_absence(self) -> None:
        row = load("production_witness_absent.json")
        row["witness"] = {"identity":{"name":"Real Witness","organization":"Independent Org"},
                           "independence_declaration":{"statement":"independent","scope":"candidate-r2-demo","conflict_disclosure":False},
                           "evidence_candidates":[{"candidate_id":row["candidate_id"],"canonical_object_sha256":row["canonical_object_sha256"],"source_revision":row["source_revision"],"source_locator":row["source_locator"],"source_version":row["source_version"]}]}
        row["witness"]["independence_declaration"]["external_attestation"] = {
            "attestation_id":"external-attestation-1", "provider":"Independent Org", "ref":"external://attestation/1",
            "digest":"9" * 64, "verifier_ref":"external://verifier", "verifier_version":"v1",
            "candidate_id":row["candidate_id"], "subject_object_sha256":row["canonical_object_sha256"], "status":"verified"}
        row["witness"]["evidence_candidates"][0]["layer_refs"] = copy.deepcopy(row["layer_refs"])
        row["witness"]["evidence_candidates"][0]["four_axis_refs"] = copy.deepcopy(row["four_axis_refs"])
        self.assertEqual(validate(row)["error_code"], "ERR_SIGNATURE_EXTERNAL_ABSENT")
        row["witness"]["signature_material"] = {"ref":"external://signature","algorithm":"ed25519","signature":"real-signature"}
        row["witness"]["signature_material"]["digest"] = sha256_json(_signature_binding_payload(row, row["witness"]["evidence_candidates"]))
        row["authority"] = {"endpoint":{"uri":"typed_absence","owner":"typed_absence"}}
        self.assertEqual(validate(row)["error_code"], "ERR_AUTHORITY_EXTERNAL_ABSENT")

    def test_missing_candidate_fields_fail_closed(self) -> None:
        result = validate(load("missing_field_negative.json"))
        self.assertEqual(result["status"], "non_evidence")
        self.assertEqual(result["resolution"], "fail_closed")
        self.assertEqual(result["error_code"], "ERR_MISSING_FIELD")

    def test_foreign_layer_and_axis_fail_closed(self) -> None:
        layer = load("production_witness_absent.json")
        layer["witness"] = copy.deepcopy(base()["witness"])
        layer["witness"]["identity"] = {"name":"Real Witness","organization":"Independent Org"}
        layer["witness"]["independence_declaration"] = {"statement":"independent","scope":"candidate-r2-demo","conflict_disclosure":False}
        layer["witness"]["signature_material"] = {"ref":"external://sig","algorithm":"ed25519","signature":"sig"}
        layer["witness"]["evidence_candidates"] = [{"candidate_id":"candidate-r2-demo","canonical_object_sha256":layer["canonical_object_sha256"],"source_revision":layer["source_revision"],"source_locator":layer["source_locator"],"source_version":layer["source_version"]}]
        layer["layer_refs"]["G2"]["candidate_id"] = "foreign-candidate"
        result = validate(layer)
        self.assertEqual(result["error_code"], "ERR_FOREIGN_LAYER_CANDIDATE")
        axis = copy.deepcopy(layer)
        axis["layer_refs"]["G2"]["candidate_id"] = axis["candidate_id"]
        axis["four_axis_refs"]["profile"]["candidate_id"] = "foreign-candidate"
        result = validate(axis)
        self.assertEqual(result["error_code"], "ERR_FOREIGN_AXIS_CANDIDATE")

    def test_duplicate_and_conflicting_requests_fail_closed(self) -> None:
        ledger = AuthorityLedger()
        row = load("production_witness_absent.json")
        row["witness"] = copy.deepcopy(base()["witness"])
        row["witness"]["identity"] = {"name":"Real Witness","organization":"Independent Org"}
        row["witness"]["independence_declaration"] = {"statement":"independent","scope":"candidate-r2-demo","conflict_disclosure":False}
        row["witness"]["signature_material"] = {"ref":"external://sig","algorithm":"ed25519","signature":"sig"}
        row["witness"]["evidence_candidates"] = [{"candidate_id":row["candidate_id"],"canonical_object_sha256":row["canonical_object_sha256"],"source_revision":row["source_revision"],"source_locator":row["source_locator"],"source_version":row["source_version"]}]
        row["witness"]["evidence_candidates"][0]["layer_refs"] = copy.deepcopy(row["layer_refs"])
        row["witness"]["evidence_candidates"][0]["four_axis_refs"] = copy.deepcopy(row["four_axis_refs"])
        row["witness"]["signature_material"]["digest"] = sha256_json(_signature_binding_payload(row, row["witness"]["evidence_candidates"]))
        # Production witness is complete, but the authority endpoint remains
        # external and therefore the result is typed absence.
        row["authority"] = {"endpoint":{"uri":"typed_absence","owner":"typed_absence"}}
        first = ledger.validate(row)
        self.assertEqual(first["status"], "typed_absence")  # authority ack is still external
        self.assertEqual(ledger.validate(row)["error_code"], "ERR_DUPLICATE_IDEMPOTENCY")
        row2 = copy.deepcopy(row)
        row2["witness"]["independence_declaration"]["external_attestation"] = {
            "attestation_id":"external-attestation-1", "provider":"Independent Org",
            "ref":"external://attestation/1", "digest":"9" * 64,
            "verifier_ref":"external://verifier", "verifier_version":"v1",
            "candidate_id":row2["candidate_id"], "subject_object_sha256":row2["canonical_object_sha256"], "status":"verified"}
        evidence = row2["witness"]["evidence_candidates"][0]
        evidence["layer_refs"] = copy.deepcopy(row2["layer_refs"])
        evidence["four_axis_refs"] = copy.deepcopy(row2["four_axis_refs"])
        row2["witness"]["signature_material"]["digest"] = sha256_json(_signature_binding_payload(row2, row2["witness"]["evidence_candidates"]))
        row2["authority"] = {"endpoint":{"uri":"external://authority","owner":"Authority"}, "ack": {
            "ack_id":"real-ack", "request_id":row2["request_id"], "idempotency_key":row2["idempotency_key"],
            "accepted_object_sha256":row2["canonical_object_sha256"], "authority_decision":"RECEIVED",
            "received_at_trusted_time":"2026-09-17T00:00:01Z", "verifier_ref":"external://verifier",
            "verifier_version":"v1", "receipt_signature":"real-receipt", "receipt_sha256":"8" * 64}}
        # New ledger is needed because first had no ack but did not record idem.
        ledger = AuthorityLedger()
        self.assertEqual(ledger.validate(row2)["status"], "present_admissible_shape")
        duplicate = ledger.validate(row2)
        self.assertEqual(duplicate["error_code"], "ERR_DUPLICATE_IDEMPOTENCY")
        conflict = copy.deepcopy(row2)
        conflict["canonical_object_sha256"] = "c" * 64
        self.assertEqual(ledger.validate(conflict)["error_code"], "ERR_IDEMPOTENCY_CONFLICT")

        bad_signature = copy.deepcopy(row2)
        bad_signature["request_id"] = "r2-bad-signature"
        bad_signature["authority"]["ack"]["request_id"] = "r2-bad-signature"
        bad_signature["witness"]["signature_material"]["digest"] = "0" * 64
        self.assertEqual(AuthorityLedger().validate(bad_signature)["error_code"], "ERR_SIGNATURE_BINDING_MISMATCH")

        changed_source = copy.deepcopy(row2)
        changed_source["source_revision"] = "revision-r2-changed"
        changed_source["witness"]["evidence_candidates"][0]["source_revision"] = "revision-r2-changed"
        changed_source["authority"]["ack"]["request_id"] = changed_source["request_id"]
        self.assertEqual(ledger.validate(changed_source)["error_code"], "ERR_IDEMPOTENCY_CONFLICT")

    def test_scope_is_exact_and_self_certification_stays_deferred(self) -> None:
        row = load("production_witness_absent.json")
        row["witness"] = {"identity":{"name":"Real Witness","organization":"Independent Org"},
                           "independence_declaration":{"statement":"self-certified independent","scope":"attacker/candidate-r2-demo/other","conflict_disclosure":False}}
        row["witness"]["evidence_candidates"] = [{"evidence_id":"e-1","candidate_id":row["candidate_id"],"canonical_object_sha256":row["canonical_object_sha256"],"source_revision":row["source_revision"],"source_locator":row["source_locator"],"source_version":row["source_version"],"layer_refs":copy.deepcopy(row["layer_refs"]),"four_axis_refs":copy.deepcopy(row["four_axis_refs"])}]
        row["witness"]["signature_material"] = {"ref":"external://sig","algorithm":"ed25519","signature":"sig"}
        row["witness"]["signature_material"]["digest"] = sha256_json(_signature_binding_payload(row, row["witness"]["evidence_candidates"]))
        result = validate(row)
        self.assertEqual(result["status"], "fail_closed")
        self.assertEqual(result["error_code"], "ERR_SCOPE_MISMATCH")
        row["witness"]["independence_declaration"]["scope"] = row["candidate_id"]
        result = validate(row)
        self.assertEqual(result["status"], "typed_absence")
        self.assertEqual(result["error_code"], "ERR_INDEPENDENCE_EXTERNAL_ABSENT")
        self.assertTrue(result["terminal_deferred"])

    def test_signature_and_ack_scalar_types_fail_closed(self) -> None:
        row = load("production_witness_absent.json")
        row["witness"] = {"identity":{"name":"Real Witness","organization":"Independent Org"},
                           "independence_declaration":{"statement":"independent","scope":row["candidate_id"],"conflict_disclosure":False}}
        # Self-certification is deliberately deferred before any signature can
        # be admitted; this confirms the proof boundary has priority.
        row["witness"]["independence_declaration"]["external_attestation"] = {
            "attestation_id":"att-1", "provider":"org", "ref":"external://att-1", "digest":"9" * 64,
            "verifier_ref":"external://v", "verifier_version":"v1", "candidate_id":row["candidate_id"],
            "subject_object_sha256":row["canonical_object_sha256"], "status":"verified"}
        evidence = {"evidence_id":"e-1", "candidate_id":row["candidate_id"], "canonical_object_sha256":row["canonical_object_sha256"],
                    "source_revision":row["source_revision"], "source_locator":row["source_locator"], "source_version":row["source_version"],
                    "layer_refs":copy.deepcopy(row["layer_refs"]), "four_axis_refs":copy.deepcopy(row["four_axis_refs"])}
        row["witness"]["evidence_candidates"] = [evidence]
        row["witness"]["signature_material"] = {"ref":"external://sig", "algorithm":"ed25519", "signature":123,
                                                  "digest":sha256_json(_signature_binding_payload(row, [evidence]))}
        self.assertEqual(validate(row)["error_code"], "ERR_INVALID_SIGNATURE_MATERIAL")
        row["witness"]["signature_material"]["signature"] = "real-signature"
        row["authority"] = {"endpoint":{"uri":"external://authority","owner":"Authority"}, "ack": {
            "ack_id":123, "request_id":row["request_id"], "idempotency_key":row["idempotency_key"],
            "accepted_object_sha256":row["canonical_object_sha256"], "authority_decision":"RECEIVED",
            "received_at_trusted_time":"2026-09-17T00:00:01Z", "verifier_ref":"external://verifier",
            "verifier_version":"v1", "receipt_signature":"real-receipt", "receipt_sha256":"8" * 64}}
        self.assertEqual(validate(row)["error_code"], "ERR_INVALID_ACK_FIELD_TYPE")

    def test_strict_json_rejects_duplicate_keys(self) -> None:
        with self.assertRaises(ValueError):
            parse_json('{"mode":"TEST_ONLY","mode":"PRODUCTION"}')

    def test_unknown_fields_rejected_at_root_and_nested_boundaries(self) -> None:
        root = base()
        root["unversioned_extension"] = {"value": 1}
        result = validate(root)
        self.assertEqual(result["status"], "non_evidence")
        self.assertEqual(result["error_code"], "ERR_UNKNOWN_FIELD")

    def test_semantic_aliases_are_closed_not_preferred(self) -> None:
        root = base()
        root["object_sha256"] = root["canonical_object_sha256"]
        result = validate(root)
        self.assertEqual(result["error_code"], "ERR_ALIAS_CONFLICT")

        root = base()
        root.pop("canonical_object_sha256")
        root["object_sha256"] = "b" * 64
        result = validate(root)
        self.assertEqual(result["error_code"], "ERR_UNKNOWN_FIELD")

        signature = base()
        signature["witness"]["signature_material_ref"] = {"ref":"legacy://signature"}
        result = validate(signature)
        self.assertEqual(result["error_code"], "ERR_ALIAS_CONFLICT")

        authority = base()
        authority["authority"]["receipt"] = copy.deepcopy(authority["authority"]["ack"])
        result = validate(authority)
        self.assertEqual(result["error_code"], "ERR_ALIAS_CONFLICT")
        nested = base()
        nested["witness"]["identity"]["unversioned_extension"] = "x"
        result = validate(nested)
        self.assertEqual(result["status"], "non_evidence")
        self.assertEqual(result["error_code"], "ERR_UNKNOWN_FIELD")

    def test_fresh_python_b_cli_emits_one_json_object(self) -> None:
        proc = subprocess.run([sys.executable, "-B", str(CLI)], input=json.dumps(base()),
                              text=True, capture_output=True, cwd=str(REPO))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        output = json.loads(proc.stdout)
        self.assertEqual(output["status"], "non_evidence")
        self.assertTrue(output["non_evidence"])
        self.assertEqual(len(proc.stdout.strip().splitlines()), 1)
        self.assertEqual(proc.stderr, "")
        alias = base()
        alias["object_sha256"] = alias["canonical_object_sha256"]
        proc = subprocess.run([sys.executable, "-B", str(CLI)], input=json.dumps(alias),
                              text=True, capture_output=True, cwd=str(REPO))
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(json.loads(proc.stdout)["error_code"], "ERR_ALIAS_CONFLICT")


if __name__ == "__main__":
    unittest.main(verbosity=2)
