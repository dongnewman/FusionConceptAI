from __future__ import annotations

import hashlib
import os
import socket
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.up1_external_closure_r4.authoritative_intake import (
    AuthorityIntake,
    ChannelIdentity,
    ChannelPolicy,
    IntakeError,
    atomic_quarantine,
)
from tools.up1_external_closure_r4.authoritative_intake import intake as intake_impl


def _identity(channel: str = "channel-r4", *, real: bool = True) -> dict[str, object]:
    return {
        "channel_id": channel,
        "owner_id": "owner-r4",
        "transport": "offline-spool",
        "endpoint": "local-only://r4",
        "real_channel": real,
    }


def _policy(channel: str = "channel-r4", *, required: tuple[str, ...] = (), signature: bool = False) -> dict[str, object]:
    return {
        "channel_id": channel,
        "required_packet_ids": list(required),
        "max_packet_count": 8,
        "max_packet_bytes": 4096,
        "require_signature": signature,
    }


def _packet(packet_id: str, value: str = "r4") -> bytes:
    return (f'{{"packet_id":"{packet_id}","value":"{value}"}}').encode("utf-8")


class AuthoritativeIntakeContractTests(unittest.TestCase):
    def test_identity_policy_mismatch_is_rejected_at_construction(self):
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaisesRegex(IntakeError, "channel IDs must match"):
                AuthorityIntake(td, _identity("channel-a"), _policy("channel-b"))

    def test_request_channel_mismatch_is_rejected_and_is_not_authority(self):
        with tempfile.TemporaryDirectory() as td:
            adapter = AuthorityIntake(td, _identity(), _policy())
            result = adapter.receive(_packet("EHP-01"), channel_id="wrong-channel")
            self.assertEqual(result["decision"], "rejected_all")
            self.assertIn("channel_identity_mismatch", {e["code"] for e in result["receipt"]["errors"]})
            self.assertFalse(result["ack"]["authority_claim"])
            self.assertFalse(result["ack"]["external_ack_sent"])

    def test_typed_absent_without_configuration(self):
        with tempfile.TemporaryDirectory() as td:
            result = AuthorityIntake(td).receive(_packet("EHP-01"))
            self.assertEqual(result["authority_status"], "typed_absent")
            self.assertEqual(result["decision"], "rejected_all")
            self.assertIn("channel_configuration_absent", {e["code"] for e in result["receipt"]["errors"]})
            self.assertFalse(result["receipt"]["authority_claim"])

    def test_typed_unverified_remains_unverified_even_when_local_verifier_succeeds(self):
        with tempfile.TemporaryDirectory() as td:
            adapter = AuthorityIntake(td, _identity(), _policy(signature=True), signature_verifier=lambda _raw, _sig: True)
            result = adapter.receive(_packet("EHP-01"), signature={"local": "sig"})
            self.assertEqual(result["authority_status"], "typed_unverified")
            self.assertEqual(result["decision"], "accepted_all")
            self.assertFalse(result["receipt"]["authority_claim"])
            self.assertEqual(result["receipt"]["external_signature_state"], "not_verified")
            self.assertIsNone(result["receipt"]["external_channel_ack"])

    def test_quarantine_preserves_exact_bytes_hash_size_and_locator(self):
        raw = b'{"packet_id":"EHP-01","value":"\xe4\xb8\xad"}\r\n'
        with tempfile.TemporaryDirectory() as td:
            meta = atomic_quarantine(raw, td)
            digest = hashlib.sha256(raw).hexdigest()
            self.assertEqual(meta["raw_sha256"], digest)
            self.assertEqual(meta["raw_size_bytes"], len(raw))
            self.assertEqual(meta["quarantine_transaction_id"], f"quarantine-{digest[:24]}")
            target = Path(td) / meta["quarantine_locator"]
            self.assertTrue(target.is_file())
            self.assertEqual(target.read_bytes(), raw)
            self.assertEqual(target.relative_to(Path(td)).as_posix(), meta["quarantine_locator"])

    def test_receive_receipt_binds_each_raw_packet_to_quarantine(self):
        first, second = _packet("EHP-01", "one"), _packet("EHP-02", "two")
        with tempfile.TemporaryDirectory() as td:
            adapter = AuthorityIntake(td, _identity(), _policy(required=("EHP-01", "EHP-02")))
            result = adapter.receive_packet_set([("EHP-01", first), ("EHP-02", second)], request_id="req-r4")
            self.assertEqual(result["decision"], "accepted_all")
            self.assertEqual(result["receipt"]["request_id"], "req-r4")
            self.assertEqual(len(result["receipt"]["packet_quarantine"]), 2)
            expected = {hashlib.sha256(first).hexdigest(): first, hashlib.sha256(second).hexdigest(): second}
            for item in result["receipt"]["packet_quarantine"]:
                self.assertEqual(item["raw_size_bytes"], len(expected[item["raw_sha256"]]))
                self.assertEqual((Path(td) / item["quarantine_locator"]).read_bytes(), expected[item["raw_sha256"]])

    def test_equal_byte_replay_is_idempotent(self):
        raw = _packet("EHP-01")
        with tempfile.TemporaryDirectory() as td:
            first = atomic_quarantine(raw, td)
            second = atomic_quarantine(raw, td)
            self.assertEqual(first, second)
            self.assertEqual(len(list((Path(td) / "quarantine").glob("*.bin"))), 1)

    def test_different_byte_digest_collision_fails_closed_without_overwrite(self):
        raw = _packet("EHP-01", "original")
        digest = hashlib.sha256(raw).hexdigest()
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "quarantine" / f"{digest}.bin"
            target.parent.mkdir()
            target.write_bytes(b"attacker-bytes")
            with self.assertRaisesRegex(IntakeError, "different bytes"):
                atomic_quarantine(raw, td)
            self.assertEqual(target.read_bytes(), b"attacker-bytes")

    def test_reparse_components_are_rejected(self):
        with tempfile.TemporaryDirectory() as td, tempfile.TemporaryDirectory() as outside:
            link = Path(td) / "quarantine"
            try:
                os.symlink(outside, link, target_is_directory=True)
            except (OSError, NotImplementedError) as exc:
                self.skipTest(f"symlink/reparse creation unavailable: {exc}")
            with self.assertRaisesRegex(IntakeError, "link or reparse"):
                atomic_quarantine(b"reparse-probe", td)
            self.assertEqual(list(Path(outside).iterdir()), [])

    def test_input_symlink_is_rejected_without_quarantining_target(self):
        with tempfile.TemporaryDirectory() as td, tempfile.TemporaryDirectory() as outside:
            target = Path(outside) / "outside.json"
            target.write_bytes(_packet("EHP-01"))
            source = Path(td) / "incoming.json"
            try:
                os.symlink(target, source)
            except (OSError, NotImplementedError) as exc:
                self.skipTest(f"symlink/reparse creation unavailable: {exc}")
            adapter = AuthorityIntake(Path(td) / "spool", _identity(), _policy())
            result = adapter.receive(source)
            self.assertEqual(result["error"]["code"], "input_not_regular")
            self.assertFalse((Path(td) / "spool" / "quarantine" / (hashlib.sha256(target.read_bytes()).hexdigest() + ".bin")).exists())

    def test_hardlink_digest_alias_is_rejected_as_non_immutable(self):
        """A digest object must not be an alias to a separately mutable inode."""
        raw = _packet("EHP-01", "hardlink")
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            source = root / "outside.bin"
            source.write_bytes(raw)
            target = root / "quarantine" / f"{hashlib.sha256(raw).hexdigest()}.bin"
            target.parent.mkdir()
            try:
                os.link(source, target)
            except (OSError, NotImplementedError) as exc:
                self.skipTest(f"hardlink creation unavailable: {exc}")
            with self.assertRaises(IntakeError):
                atomic_quarantine(raw, root)
            self.assertTrue(os.path.samefile(source, target))

    def test_path_traversal_component_is_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td) / "spool"
            root.mkdir()
            escaped = root / ".." / "escape"
            try:
                with self.assertRaisesRegex(IntakeError, "escaped root"):
                    intake_impl._ensure_regular_parent(escaped, root)
            finally:
                # The cleanup is constrained to this test's private temp parent.
                created = Path(td) / "escape"
                if created.is_dir() and not created.is_symlink():
                    created.rmdir()

    def test_packet_set_is_all_or_reject_and_never_partial_ack(self):
        first, second = _packet("EHP-01"), _packet("EHP-02")
        with tempfile.TemporaryDirectory() as td:
            adapter = AuthorityIntake(td, _identity(), _policy(required=("EHP-01", "EHP-03")))
            result = adapter.receive_packet_set([("EHP-01", first), ("EHP-02", second)], request_id="req-set")
            self.assertFalse(result["ok"])
            self.assertEqual(result["decision"], "rejected_all")
            self.assertEqual(result["ack"]["packet_count"], 2)
            self.assertFalse(result["ack"]["authority_claim"])
            self.assertFalse(result["ack"]["external_ack_sent"])
            self.assertEqual(len(result["quarantine"]), 2)
            self.assertFalse((Path(td) / "accepted").exists())

    def test_no_network_send_or_authority_claim(self):
        raw = _packet("EHP-01")
        with tempfile.TemporaryDirectory() as td:
            adapter = AuthorityIntake(td, _identity(), _policy())
            with mock.patch.object(socket, "socket", side_effect=AssertionError("network attempted")):
                result = adapter.receive(raw)
            self.assertFalse(result["receipt"]["authority_claim"])
            self.assertTrue(result["receipt"]["no_network_or_message_sent"])
            self.assertTrue(result["receipt"]["local_bookkeeping_only"])
            self.assertFalse(result["receipt"]["transport_receipt"]["external_ack"])


if __name__ == "__main__":
    unittest.main()
