"""Focused positive/negative tests for the UP1 external closure aggregate gate."""

from __future__ import annotations

import pathlib
import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "up1_external_closure_r2"))
from aggregate_gate.aggregate_gate import SCHEMA_VERSION, _read_json, aggregate_document, canonical_json, transition  # noqa: E402

CANDIDATE_FP = "a" * 64
SOURCE_FP = "b" * 64
INPUT_FP = "c" * 64


def fixture(status="verified"):
    packages = {}
    for name in ("g1", "g2", "g3", "source_authority"):
        packages[name] = {
            "candidate_fingerprint": CANDIDATE_FP,
            "source_fingerprint": SOURCE_FP,
            "input_fingerprint": INPUT_FP,
            "receipts": {
                "component-1": {
                    "status": status,
                    "candidate_fingerprint": CANDIDATE_FP,
                    "source_fingerprint": SOURCE_FP,
                    "input_fingerprint": INPUT_FP,
                }
            },
        }
    return {
        "schema_version": SCHEMA_VERSION,
        "event": "intake",
        "candidate_fingerprint": CANDIDATE_FP,
        "source_fingerprint": SOURCE_FP,
        "input_fingerprint": INPUT_FP,
        "responsibility_packages": packages,
    }


class AggregateGateTests(unittest.TestCase):
    def test_verified_four_package_result_only_allows_authority_recheck(self):
        result = aggregate_document(fixture())
        self.assertEqual(result["status"], "verified")
        self.assertEqual(result["resolution"], "eligible_for_authority_recheck")
        self.assertFalse(result["terminal_deferred"])
        self.assertFalse(result["no_publish"])
        self.assertFalse(result["ad_created"])
        self.assertEqual(result["claims"]["L4"], 0)
        self.assertTrue(all(result["claims"][key] is False for key in ("T0", "T1", "T2", "B00", "B04", "parent")))

    def test_typed_absence_is_terminal_and_not_publishable(self):
        result = aggregate_document(fixture("typed_absence"))
        self.assertEqual(result["status"], "typed_absence")
        self.assertEqual(result["resolution"], "terminal_deferred")
        self.assertTrue(result["terminal_deferred"])
        self.assertTrue(result["no_publish"])

    def test_all_non_verified_states_are_preserved_and_fail_closed(self):
        for status in ("invalid", "unsupported", "stale", "replayed", "conflict"):
            with self.subTest(status=status):
                result = aggregate_document(fixture(status))
                self.assertEqual(result["status"], status)
                self.assertEqual(result["resolution"], "terminal_deferred")
                self.assertTrue(result["no_publish"])

    def test_mismatched_receipt_fingerprint_is_conflict(self):
        doc = fixture()
        doc["responsibility_packages"]["g2"]["receipts"]["component-1"]["source_fingerprint"] = "d" * 64
        result = aggregate_document(doc)
        self.assertEqual(result["status"], "conflict")
        self.assertTrue(result["no_publish"])
        self.assertTrue(any(reason["code"] == "fingerprint_mismatch" for reason in result["packages"][1]["reasons"]))

    def test_missing_receipt_is_typed_absence(self):
        doc = fixture()
        del doc["responsibility_packages"]["g3"]["receipts"]
        result = aggregate_document(doc)
        self.assertEqual(result["status"], "typed_absence")
        self.assertTrue(result["no_publish"])

    def test_changed_input_is_only_intake_changed(self):
        with tempfile.TemporaryDirectory() as directory:
            ledger = pathlib.Path(directory) / "state.json"
            baseline = transition(fixture(), ledger_path=ledger)
            changed = fixture()
            changed["input_fingerprint"] = "e" * 64
            result = transition(changed, baseline, ledger_path=ledger)
        self.assertEqual(result["event"], "intake_changed")
        self.assertTrue(result["input_changed"])
        self.assertFalse(result["ad_created"])
        self.assertEqual(result["packages"], [])

    def test_same_input_is_deterministic_noop(self):
        with tempfile.TemporaryDirectory() as directory:
            ledger = pathlib.Path(directory) / "state.json"
            baseline = transition(fixture(), ledger_path=ledger)
            first = transition(fixture(), baseline, ledger_path=ledger)
            second = transition(fixture(), baseline, ledger_path=ledger)
        self.assertEqual(first["event"], "deterministic_noop")
        self.assertEqual(canonical_json(first), canonical_json(second))
        self.assertFalse(first["ad_created"])

    def test_version_and_four_count_are_fail_closed(self):
        doc = fixture()
        doc["schema_version"] = "unversioned"
        with self.assertRaises(ValueError):
            aggregate_document(doc)
        doc = fixture()
        del doc["responsibility_packages"]["g3"]
        result = aggregate_document(doc)
        self.assertEqual(result["status"], "conflict")

    def test_sequence_is_positive_when_present(self):
        doc = fixture()
        doc["sequence"] = 0
        with self.assertRaises(ValueError):
            transition(doc)

    def test_unknown_root_package_receipt_fields_are_rejected(self):
        doc = fixture()
        doc["unknown_root"] = True
        with self.assertRaises(ValueError):
            aggregate_document(doc)
        doc = fixture()
        doc["responsibility_packages"]["g1"]["unknown_package"] = True
        self.assertNotEqual(aggregate_document(doc)["status"], "verified")
        doc = fixture()
        doc["responsibility_packages"]["g1"]["receipts"]["component-1"]["unknown_receipt"] = True
        self.assertNotEqual(aggregate_document(doc)["status"], "verified")

    def test_authority_false_at_each_layer_cannot_verify(self):
        for layer in ("root", "package", "receipt"):
            doc = fixture()
            if layer == "root":
                doc["authority_verified"] = False
            elif layer == "package":
                doc["responsibility_packages"]["source_authority"]["authority_verified"] = False
            else:
                doc["responsibility_packages"]["source_authority"]["receipts"]["component-1"]["authority_verified"] = False
            result = aggregate_document(doc)
            self.assertNotEqual(result["status"], "verified")
            self.assertTrue(result["no_publish"])

    def test_exact_responsibility_set_is_required(self):
        doc = fixture()
        packages = doc["responsibility_packages"]
        doc["responsibility_packages"] = {"a": packages["g1"], "b": packages["g2"], "c": packages["g3"], "d": packages["source_authority"]}
        result = aggregate_document(doc)
        self.assertEqual(result["status"], "conflict")
        self.assertTrue(result["no_publish"])

    def test_direct_aggregate_and_sequence_jump_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            ledger = pathlib.Path(directory) / "state.json"
            direct = fixture()
            direct["event"] = "aggregate"
            result = transition(direct, ledger_path=ledger)
            self.assertEqual(result["event"], "invalid_order")
            jumped = fixture()
            jumped["sequence"] = 2
            self.assertEqual(transition(jumped, ledger_path=pathlib.Path(directory) / "jump.json")["event"], "invalid_order")

    def test_validated_predecessor_is_required_before_aggregate(self):
        changed = fixture()
        changed["input_fingerprint"] = "e" * 64
        for package in changed["responsibility_packages"].values():
            package["input_fingerprint"] = "e" * 64
            package["receipts"]["component-1"]["input_fingerprint"] = "e" * 64
        changed["sequence"] = 2
        with tempfile.TemporaryDirectory() as directory:
            ledger = pathlib.Path(directory) / "state.json"
            baseline = transition(fixture(), ledger_path=ledger)
            intake_changed = transition(changed, baseline, ledger_path=ledger)
            validated = dict(changed)
            validated["event"] = "validated"
            validated["sequence"] = 3
            validated_state = transition(validated, intake_changed, ledger_path=ledger)
            self.assertEqual(validated_state["event"], "validated")
            aggregate = dict(changed)
            aggregate["event"] = "aggregate"
            aggregate["sequence"] = 4
            final = transition(aggregate, validated_state, ledger_path=ledger)
        self.assertEqual(final["event"], "aggregated")

    def test_map_permutation_has_identical_canonical_output(self):
        first = fixture()
        second = fixture()
        second["responsibility_packages"] = dict(reversed(list(second["responsibility_packages"].items())))
        self.assertEqual(canonical_json(aggregate_document(first)), canonical_json(aggregate_document(second)))

    def test_cli_json_duplicate_key_is_rejected(self):
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".json", delete=False) as handle:
            handle.write('{"status":"verified","status":"typed_absence"}')
            path = handle.name
        try:
            with self.assertRaises(ValueError):
                _read_json(path)
        finally:
            pathlib.Path(path).unlink(missing_ok=True)

    def test_fingerprints_require_lowercase_sha256_and_domains(self):
        malformed = fixture()
        malformed["candidate_fingerprint"] = "X" * 64
        for package in malformed["responsibility_packages"].values():
            package["candidate_fingerprint"] = "X" * 64
            package["receipts"]["component-1"]["candidate_fingerprint"] = "X" * 64
        self.assertNotEqual(aggregate_document(malformed)["status"], "verified")
        wrong_domain = fixture()
        wrong_domain["fingerprint_domains"] = {"candidate": "source", "source": "source", "input": "input"}
        self.assertNotEqual(aggregate_document(wrong_domain)["status"], "verified")

    def test_missing_ledger_is_typed_absence_and_cannot_trust_prior(self):
        baseline = aggregate_document(fixture())
        result = transition(fixture(), baseline)
        self.assertEqual(result["status"], "typed_absence")
        self.assertTrue(result["no_publish"])
        self.assertEqual(result["event"], "ledger_required")

    def test_forged_prior_state_is_rejected_even_when_fingerprint_matches(self):
        with tempfile.TemporaryDirectory() as directory:
            ledger = pathlib.Path(directory) / "state.json"
            baseline = transition(fixture(), ledger_path=ledger)
            forged = json.loads(canonical_json(baseline))
            forged["status"] = "verified"
            forged["no_publish"] = False
            forged["packages"] = []
            result = transition(fixture(), forged, ledger_path=ledger)
            self.assertEqual(result["status"], "conflict")
            self.assertTrue(result["no_publish"])
            self.assertEqual(result["reasons"][0]["code"], "prior_state_not_in_ledger")

    def test_noop_reads_complete_ledger_state_not_input_package_overlay(self):
        with tempfile.TemporaryDirectory() as directory:
            ledger = pathlib.Path(directory) / "state.json"
            baseline = transition(fixture(), ledger_path=ledger)
            overlay = fixture()
            overlay["responsibility_packages"] = {}
            result = transition(overlay, baseline, ledger_path=ledger)
            self.assertEqual(result["event"], "deterministic_noop")
            self.assertEqual(len(result["packages"]), 4)
            self.assertFalse(result["no_publish"])

    def test_ledger_tamper_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            ledger = pathlib.Path(directory) / "state.json"
            baseline = transition(fixture(), ledger_path=ledger)
            payload = json.loads(ledger.read_text(encoding="utf-8"))
            payload["records"][0]["state"]["packages"] = []
            ledger.write_text(json.dumps(payload), encoding="utf-8")
            result = transition(fixture(), baseline, ledger_path=ledger)
            self.assertEqual(result["status"], "invalid")
            self.assertTrue(result["no_publish"])
            self.assertEqual(result["reasons"][0]["code"], "state_ledger_tampered")

    def test_concurrent_changed_intake_has_atomic_compare_and_swap(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            ledger = root / "state.json"
            baseline = transition(fixture(), ledger_path=ledger)
            prior_path = root / "prior.json"
            input_path = root / "input.json"
            prior_path.write_text(canonical_json(baseline), encoding="utf-8")
            changed = fixture()
            changed["input_fingerprint"] = "e" * 64
            input_path.write_text(canonical_json(changed), encoding="utf-8")
            code = "import json,sys; sys.path.insert(0,sys.argv[1]); from aggregate_gate.aggregate_gate import transition; d=json.load(open(sys.argv[2],encoding='utf-8')); p=json.load(open(sys.argv[3],encoding='utf-8')); print(json.dumps(transition(d,p,ledger_path=sys.argv[4]),sort_keys=True))"
            command = [sys.executable, "-B", "-c", code, str(ROOT / "tools" / "up1_external_closure_r2"), str(input_path), str(prior_path), str(ledger)]
            first = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            second = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            out_a, err_a = first.communicate(timeout=20)
            out_b, err_b = second.communicate(timeout=20)
            self.assertEqual(err_a, "")
            self.assertEqual(err_b, "")
            results = [json.loads(out_a), json.loads(out_b)]
            self.assertEqual(sorted(item["status"] for item in results), ["conflict", "typed_absence"])
            records = json.loads(ledger.read_text(encoding="utf-8"))["records"]
            self.assertEqual(len(records), 2)
            self.assertEqual(records[-1]["state"]["event"], "intake_changed")


if __name__ == "__main__":
    unittest.main(verbosity=2)
