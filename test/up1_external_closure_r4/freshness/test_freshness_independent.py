"""Independent adversarial tests for the frozen R4 freshness prototype.

This file intentionally does not patch or import private implementation
helpers to manufacture a pass.  It constructs wire receipts at the public
boundary, and exercises the replay state through its public class API.  The
test is offline by construction: no authority client, network transport, or
host wall-clock value is supplied.
"""
from __future__ import annotations

import ast
import copy
import hashlib
import hmac
import json
import os
import pathlib
import socket
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[3]
SOURCE = ROOT / "tools" / "up1_external_closure_r4" / "freshness" / "core.py"
sys.path.insert(0, str(ROOT))

from tools.up1_external_closure_r4.freshness import (  # noqa: E402
    PROFILE,
    SCHEMA,
    PersistentReplayState,
    ReceiptInputError,
    canonical_bytes,
    canonical_digest,
    parse_json_strict,
    validate,
    validate_revocation_receipt,
)
import tools.up1_external_closure_r4.freshness.core as core  # noqa: E402


AS_OF = "2026-09-17T12:00:00Z"
KEY = bytes(range(32))


def _receipt(*, nonce: str = "nonce-001", sequence: int = 1, source: str = "attestor-A", candidate: str = "candidate-001") -> dict:
    return {
        "verification_id": "verification-001",
        "nonce": nonce,
        "challenge": "challenge-001",
        "scope": {"candidate": candidate, "source": source},
        "source": source,
        "source_version": {"version": "source-v1", "hash": "a" * 64},
        "sequence": sequence,
        "issued_at": "2026-09-17T11:59:00Z",
        "expires_at": "2026-09-17T12:10:00Z",
        "idempotency_key": "idem-001",
        "payload": {"claim": "offline-only"},
    }


def _payload(receipt: dict | None = None) -> dict:
    receipt = receipt or _receipt()
    digest = canonical_digest(receipt)
    return {
        "schema": SCHEMA,
        "profile": PROFILE,
        "test_only": True,
        "receipt": receipt,
        "receipt_signature_valid": True,
        "clock_skew_seconds": 2,
        "replay_window": {
            "duration_seconds": 3600,
            "trusted_time_basis": "trusted_time_receipt",
            "ledger_retention_seconds": 7200,
        },
        "trusted_time_receipt": {
            "available": True,
            "profile": "rfc3161",
            "gen_time": AS_OF,
            "receipt_digest": digest,
            "message_imprint": digest,
            "nonce": receipt["nonce"],
            "challenge": receipt["challenge"],
            "policy": "TSA-OFFLINE-TEST",
            "signature_valid": True,
            "chain_valid": True,
            "revocation_valid": True,
        },
        "revocation_receipt": {
            "available": True,
            "kind": "crl",
            "status": "good",
            "issuer": "CA-TEST",
            "serial": "7",
            "certificate_serial": "7",
            "crl_number": "1",
            "this_update": "2026-09-17T11:00:00Z",
            "next_update": "2026-09-17T13:00:00Z",
            "signature_valid": True,
            "issuer_binding_valid": True,
        },
    }


def _refresh_time(payload: dict) -> None:
    digest = canonical_digest(payload["receipt"])
    payload["trusted_time_receipt"]["receipt_digest"] = digest
    payload["trusted_time_receipt"]["message_imprint"] = digest
    payload["trusted_time_receipt"]["nonce"] = payload["receipt"]["nonce"]
    payload["trusted_time_receipt"]["challenge"] = payload["receipt"]["challenge"]


def _ledger(path: pathlib.Path, *, namespace: str = "UP1-R4") -> PersistentReplayState:
    return PersistentReplayState(path, key=KEY, namespace=namespace)


class IndependentFreshnessAdversarialTests(unittest.TestCase):
    def test_positive_is_still_no_publish_and_formal_credit_none(self) -> None:
        with tempfile.TemporaryDirectory(prefix="up1-r4-freshness-") as td:
            result = validate(_payload(), ledger=_ledger(pathlib.Path(td) / "ledger.json"))
        self.assertEqual(result["result"], "valid_for_declared_scope")
        self.assertEqual(result["formal_credit"], "none")
        self.assertIs(result["no_publish"], True)
        self.assertIs(result["network_access"], False)
        self.assertEqual(result["trusted_clock_basis"], "signed_receipt_only")

    def test_external_absence_is_typed_absence_and_never_wall_clock(self) -> None:
        original_time = core.time.time
        core.time.time = lambda: (_ for _ in ()).throw(AssertionError("host wall clock used"))
        try:
            payload = _payload()
            payload["trusted_time_receipt"] = {"available": False}
            result = validate(payload, ledger=_ledger(pathlib.Path(tempfile.gettempdir()) / "never-used.json"))
            self.assertEqual(result["result"], "typed_absent")
            self.assertEqual(result["error_code"], "trusted_time_absent")
            self.assertTrue(result["no_publish"])
        finally:
            core.time.time = original_time

        payload = _payload()
        payload["revocation_receipt"] = {"available": False}
        with tempfile.TemporaryDirectory(prefix="up1-r4-absence-") as td:
            result = validate(payload, ledger=_ledger(pathlib.Path(td) / "ledger.json"))
        self.assertEqual(result["result"], "typed_absent")
        self.assertEqual(result["error_code"], "revocation_status_unavailable")

    def test_trusted_time_digest_nonce_and_interval_binding(self) -> None:
        with tempfile.TemporaryDirectory(prefix="up1-r4-time-") as td:
            payload = _payload()
            payload["trusted_time_receipt"]["receipt_digest"] = "0" * 64
            result = validate(payload, ledger=_ledger(pathlib.Path(td) / "digest.json"))
            self.assertEqual(result["error_code"], "receipt_digest_mismatch")

            payload = _payload()
            payload["trusted_time_receipt"]["nonce"] = "attacker-nonce"
            result = validate(payload, ledger=_ledger(pathlib.Path(td) / "nonce.json"))
            self.assertEqual(result["error_code"], "timestamp_invalid")

            payload = _payload()
            payload["trusted_time_receipt"]["valid_to"] = "2026-09-17T11:59:00Z"
            result = validate(payload, ledger=_ledger(pathlib.Path(td) / "interval.json"))
            self.assertEqual(result["error_code"], "timestamp_expired")

            payload = _payload()
            payload["receipt"]["issued_at"] = "2026-09-18T00:00:00Z"
            _refresh_time(payload)
            result = validate(payload, ledger=_ledger(pathlib.Path(td) / "future.json"))
            self.assertEqual(result["error_code"], "timestamp_invalid")

    def test_ocsp_and_crl_receipts_are_checked_independently(self) -> None:
        as_of = datetime(2026, 9, 17, 12, tzinfo=timezone.utc)
        crl = _payload()["revocation_receipt"]
        self.assertEqual(validate_revocation_receipt(crl, trusted_as_of=as_of, receipt_nonce="nonce-001")["result"], "valid_for_declared_scope")

        ocsp = {
            "available": True, "kind": "ocsp", "status": "good", "issuer": "CA-TEST", "serial": "7",
            "this_update": "2026-09-17T11:00:00Z", "next_update": "2026-09-17T13:00:00Z",
            "produced_at": "2026-09-17T11:59:30Z", "signature_valid": True,
            "issuer_binding_valid": True, "responder_signature_valid": True, "chain_valid": True,
            "nonce_required": True, "nonce": "nonce-001",
        }
        self.assertEqual(validate_revocation_receipt(ocsp, trusted_as_of=as_of, receipt_nonce="nonce-001")["result"], "valid_for_declared_scope")
        for mutation, expected in (({"status": "revoked"}, "certificate_revoked"),
                                   ({"status": "unknown"}, "revocation_status_unknown"),
                                   ({"signature_valid": False}, "certificate_signature_invalid"),
                                   ({"next_update": "2026-09-17T11:59:00Z"}, "revocation_response_stale"),
                                   ({"nonce": "wrong"}, "nonce_replayed")):
            attack = copy.deepcopy(ocsp); attack.update(mutation)
            self.assertEqual(validate_revocation_receipt(attack, trusted_as_of=as_of, receipt_nonce="nonce-001")["error_code"], expected)

        missing_nonce = copy.deepcopy(ocsp); missing_nonce.pop("nonce")
        self.assertEqual(validate_revocation_receipt(missing_nonce, trusted_as_of=as_of, receipt_nonce="nonce-001")["error_code"], "nonce_absent")
        alias_conflict = copy.deepcopy(crl); alias_conflict["thisUpdate"] = crl["this_update"]
        self.assertEqual(validate_revocation_receipt(alias_conflict, trusted_as_of=as_of, receipt_nonce="nonce-001")["error_code"], "unknown_field")

    def test_nonce_sequence_window_idempotency_and_rollback(self) -> None:
        with tempfile.TemporaryDirectory(prefix="up1-r4-replay-") as td:
            ledger = _ledger(pathlib.Path(td) / "ledger.json")
            first = _payload()
            self.assertEqual(validate(first, ledger=ledger)["result"], "valid_for_declared_scope")
            self.assertEqual(validate(copy.deepcopy(first), ledger=ledger)["error_code"], "idempotent_replay")

            conflict = copy.deepcopy(first); conflict["receipt"]["payload"] = {"claim": "changed"}; _refresh_time(conflict)
            self.assertEqual(validate(conflict, ledger=ledger)["error_code"], "idempotency_conflict")

            rollback = _payload(_receipt(nonce="nonce-002", sequence=0)); rollback["receipt"]["idempotency_key"] = "idem-rollback"; _refresh_time(rollback)
            self.assertEqual(validate(rollback, ledger=ledger)["error_code"], "sequence_invalid")

            gap = _payload(_receipt(nonce="nonce-003", sequence=3)); gap["receipt"]["idempotency_key"] = "idem-gap"; _refresh_time(gap)
            self.assertEqual(validate(gap, ledger=ledger)["error_code"], "sequence_gap")

            other_scope = _payload(_receipt(nonce="nonce-001", sequence=1, candidate="different")); other_scope["receipt"]["idempotency_key"] = "idem-other-scope"; _refresh_time(other_scope)
            self.assertEqual(validate(other_scope, ledger=ledger)["error_code"], "scope_binding_mismatch")

            expired = _payload(_receipt(nonce="nonce-004", sequence=2)); expired["receipt"]["expires_at"] = "2026-09-17T14:00:00Z"; expired["trusted_time_receipt"]["gen_time"] = "2026-09-17T13:00:00Z"; _refresh_time(expired)
            self.assertEqual(validate(expired, ledger=ledger)["error_code"], "replay_window_expired")

    def test_cas_hmac_hash_and_atomic_persistence(self) -> None:
        with tempfile.TemporaryDirectory(prefix="up1-r4-ledger-") as td:
            path = pathlib.Path(td) / "state.json"
            ledger = _ledger(path)
            state_hash_before = ledger._read_unlocked(KEY)["state_hash"]
            disposition, envelope = ledger.check_and_commit(scope='{"candidate":"c","source":"s"}', source="s", nonce="n", sequence=0, key="i", digest="a" * 64, result_digest="b" * 64, expected_state_hash="bad")
            self.assertEqual(disposition, "cas_conflict")
            self.assertEqual(envelope["state_hash"], state_hash_before)

            validate(_payload(), ledger=ledger)
            parsed = json.loads(path.read_text(encoding="utf-8"))
            parsed["state"]["entries"][0]["nonce"] = "tampered"
            parsed["state_hash"] = canonical_digest(parsed["state"])
            path.write_text(json.dumps(parsed, separators=(",", ":")), encoding="utf-8")
            result = validate(_payload(), ledger=ledger)
            self.assertEqual(result["error_code"], "ledger_corrupt")

            # A completed commit leaves a complete authenticated envelope and
            # no temporary replacement file behind.
            clean = pathlib.Path(td) / "clean.json"
            clean_ledger = _ledger(clean)
            self.assertEqual(validate(_payload(), ledger=clean_ledger)["result"], "valid_for_declared_scope")
            self.assertEqual(json.loads(clean.read_text(encoding="utf-8"))["schema"], "UP1-R4.replay-state.v1")
            self.assertEqual(list(pathlib.Path(td).glob("clean.json.*.tmp")), [])

    def test_corrupt_json_duplicate_keys_nonfinite_and_unknown_fields_fail_closed(self) -> None:
        with self.assertRaises(ReceiptInputError):
            parse_json_strict('{"a":1,"a":2}')
        with self.assertRaises(ReceiptInputError):
            parse_json_strict('{"a":NaN}')
        for mutation, expected in ((lambda p: p.update({"unexpected": 1}), "unknown_field"),
                                   (lambda p: p["receipt"].update({"unexpected": 1}), "unknown_field"),
                                   (lambda p: p["replay_window"].update({"duration_seconds": float("nan")}), "replay_window_invalid")):
            payload = _payload(); mutation(payload)
            with tempfile.TemporaryDirectory(prefix="up1-r4-corrupt-") as td:
                self.assertEqual(validate(payload, ledger=_ledger(pathlib.Path(td) / "ledger.json"))["error_code"], expected)

        with tempfile.TemporaryDirectory(prefix="up1-r4-corrupt-ledger-") as td:
            path = pathlib.Path(td) / "ledger.json"; path.write_text('{"schema":1,"schema":2}', encoding="utf-8")
            result = validate(_payload(), ledger=_ledger(path))
            self.assertEqual(result["error_code"], "ledger_corrupt")

    def test_reparse_key_and_ledger_paths_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="up1-r4-reparse-") as td:
            root = pathlib.Path(td); target = root / "target.key"; target.write_bytes(KEY)
            directory_key = root / "directory.key"; directory_key.mkdir()
            result = validate(_payload(), ledger=PersistentReplayState(root / "directory-key-ledger.json", key_path=directory_key))
            self.assertEqual(result["error_code"], "ledger_corrupt")
            link = root / "link.key"
            try:
                os.symlink(target, link)
            except (OSError, NotImplementedError):
                link = None
            if link is not None:
                result = validate(_payload(), ledger=PersistentReplayState(root / "ledger.json", key_path=link))
                self.assertEqual(result["error_code"], "ledger_corrupt")

            directory_state = root / "directory-state.json"; directory_state.mkdir()
            result = validate(_payload(), ledger=PersistentReplayState(directory_state, key=KEY))
            self.assertEqual(result["error_code"], "ledger_corrupt")
            real = root / "real-state.json"; real.write_text("{}", encoding="utf-8")
            if link is not None:
                state_link = root / "state-link.json"; os.symlink(real, state_link)
                result = validate(_payload(), ledger=PersistentReplayState(state_link, key=KEY))
                self.assertEqual(result["error_code"], "ledger_corrupt")

    def test_two_process_same_receipt_has_one_commit_and_one_replay(self) -> None:
        worker = """import json, pathlib, sys\nfrom tools.up1_external_closure_r4.freshness import validate, PersistentReplayState\np=json.loads(sys.stdin.read())\nr=validate(p, ledger=PersistentReplayState(pathlib.Path(sys.argv[1]), key=bytes(range(32))))\nprint(json.dumps({k:r.get(k) for k in ('result','error_code','formal_credit','no_publish')}, sort_keys=True))\n"""
        with tempfile.TemporaryDirectory(prefix="up1-r4-procs-") as td:
            path = pathlib.Path(td) / "shared.json"
            payload = json.dumps(_payload(), separators=(",", ":"))
            procs = [subprocess.Popen([sys.executable, "-c", worker, str(path)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd=ROOT) for _ in range(2)]
            outputs = []
            for proc in procs:
                stdout, stderr = proc.communicate(payload, timeout=30)
                self.assertEqual(proc.returncode, 0, stderr)
                outputs.append(json.loads(stdout))
            self.assertEqual(sum(row["result"] == "valid_for_declared_scope" for row in outputs), 1)
            self.assertEqual(sum(row["error_code"] == "idempotent_replay" for row in outputs), 1)
            self.assertTrue(all(row["formal_credit"] == "none" and row["no_publish"] for row in outputs))

    def test_static_offline_surface_has_no_network_or_publish_escape(self) -> None:
        tree = ast.parse(SOURCE.read_text(encoding="utf-8"))
        imports = {alias.name.split(".")[0] for node in ast.walk(tree) if isinstance(node, ast.Import) for alias in node.names}
        imports |= {node.module.split(".")[0] for node in ast.walk(tree) if isinstance(node, ast.ImportFrom) and node.module}
        self.assertFalse(imports & {"socket", "urllib", "requests", "httpx", "subprocess"})
        source = SOURCE.read_text(encoding="utf-8")
        self.assertIn('"formal_credit": "none"', source)
        self.assertIn('"no_publish": True', source)
        self.assertNotIn("datetime.now", source)

        original = socket.create_connection
        socket.create_connection = lambda *a, **k: (_ for _ in ()).throw(AssertionError("network used"))
        try:
            with tempfile.TemporaryDirectory(prefix="up1-r4-network-") as td:
                result = validate(_payload(), ledger=_ledger(pathlib.Path(td) / "ledger.json"))
            self.assertEqual(result["result"], "valid_for_declared_scope")
        finally:
            socket.create_connection = original


if __name__ == "__main__":
    unittest.main(verbosity=2)
