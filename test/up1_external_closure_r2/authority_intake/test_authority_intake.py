from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
import tools.up1_external_closure_r2.authority_intake.adapter as adapter_module
from tools.up1_external_closure_r2.authority_intake import AuthorityIntakeAdapter, SCHEMA_VERSION


def envelope(**changes):
    value = {
        "schema_version": SCHEMA_VERSION,
        "sender_id": "external-attestor-ref",
        "authority_channel_id": "authority-channel-ref",
        "nonce": "nonce-001",
        "sequence": 1,
        "idempotency_key": "idem-001",
        "payload": {"candidate_ref": "typed_absence", "claim": False},
    }
    value.update(changes)
    return value


class AuthorityIntakeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.incoming = self.root / "incoming"
        self.incoming.mkdir()
        self.adapter = AuthorityIntakeAdapter(self.root)

    def tearDown(self):
        self.tmp.cleanup()

    def put(self, name="one.json", value=None, raw=None):
        path = self.incoming / name
        path.write_bytes(raw if raw is not None else json.dumps(value or envelope()).encode("utf-8"))
        return path

    def test_accepts_without_external_authority_and_creates_cas_receipt(self):
        source = self.put()
        before = source.read_bytes()
        result = self.adapter.intake(source.relative_to(self.incoming))
        self.assertTrue(result["ok"])
        self.assertEqual("accepted_local", result["outcome"])
        self.assertEqual(before, source.read_bytes())
        receipt = json.loads((self.root / result["receipt"]).read_bytes())
        self.assertEqual("typed_absence", receipt["external_endpoint_state"])
        self.assertEqual("not_verified", receipt["external_signature_state"])
        self.assertTrue(receipt["local_bookkeeping_only"])
        self.assertFalse(receipt["external_authority_claim"])
        cas = self.root / result["entry"]["cas_path"]
        self.assertTrue(cas.is_file())

    def test_same_idempotency_is_duplicate_without_second_ledger_entry(self):
        source = self.put()
        first = self.adapter.intake(source.relative_to(self.incoming))
        second = self.adapter.intake(source.relative_to(self.incoming))
        self.assertEqual("accepted_local", first["outcome"])
        self.assertEqual("duplicate", second["outcome"])
        ledger = json.loads(self.adapter.ledger_path.read_text())
        self.assertEqual(1, len(ledger["entries"]))

    def test_idempotency_conflict_is_quarantined(self):
        self.put()
        self.adapter.intake("one.json")
        source = self.put("conflict.json", envelope(payload={"different": True}))
        result = self.adapter.intake(source.relative_to(self.incoming))
        self.assertFalse(result["ok"])
        self.assertEqual("idempotency_conflict", result["error"]["code"])
        self.assertTrue((self.root / result["quarantine_path"]).is_file())

    def test_nonce_replay_and_sequence_rollback_are_rejected(self):
        self.put()
        self.adapter.intake("one.json")
        replay = self.put("replay.json", envelope(idempotency_key="idem-002", sequence=2))
        self.assertEqual("nonce_replay", self.adapter.intake(replay.relative_to(self.incoming))["error"]["code"])
        rollback = self.put("rollback.json", envelope(idempotency_key="idem-003", nonce="nonce-003", sequence=1))
        self.assertEqual("sequence_replay", self.adapter.intake(rollback.relative_to(self.incoming))["error"]["code"])

    def test_schema_duplicate_key_unknown_field_and_invalid_json_quarantine(self):
        cases = [
            b'{"schema_version":"bad"}',
            b'{"schema_version":"UP1.authority-intake-envelope.v1","schema_version":"bad"}',
            json.dumps(envelope(extra=True)).encode(),
            b"not-json",
        ]
        codes = {"schema_version_unsupported", "duplicate_json_key", "unknown_field", "invalid_json"}
        observed = set()
        for index, raw in enumerate(cases):
            self.put(f"bad-{index}.json", raw=raw)
            result = self.adapter.intake(f"bad-{index}.json")
            self.assertFalse(result["ok"])
            observed.add(result["error"]["code"])
        self.assertEqual(codes, observed)

    def test_path_traversal_and_oversize_do_not_read_outside(self):
        outside = self.root / "outside.json"
        outside.write_bytes(json.dumps(envelope()).encode())
        result = self.adapter.intake("..\\outside.json")
        self.assertEqual("path_traversal", result["error"]["code"])
        huge = self.put("huge.json", raw=b"x" * 100)
        result = AuthorityIntakeAdapter(self.root, max_bytes=10).intake("huge.json")
        self.assertEqual("oversize", result["error"]["code"])
        receipt = json.loads((self.root / result["receipt"]).read_text())
        self.assertTrue(receipt["raw_unavailable"])
        self.assertEqual("not_attempted", receipt["quarantine_copy"])

    def test_absolute_inside_path_is_rejected_by_contract(self):
        source = self.put()
        result = self.adapter.intake(source.absolute())
        self.assertEqual("absolute_path", result["error"]["code"])

    def test_platform_without_handle_pinned_io_is_unsupported(self):
        self.put()
        with mock.patch.object(adapter_module, "_WINDOWS_HANDLE_IO_SUPPORTED", False):
            result = self.adapter.intake("one.json")
        self.assertFalse(result["ok"])
        self.assertEqual("unsupported", result["outcome"])
        self.assertEqual("handle_pinned_io_unsupported", result["error"]["code"])

    def test_cas_wrong_digest_is_quarantined_with_receipt(self):
        source = self.put()
        canonical = adapter_module._canonical_bytes(envelope())
        digest = adapter_module._sha256(canonical)
        cas = self.root / "cas" / "sha256" / digest[:2] / f"{digest}.json"
        cas.parent.mkdir(parents=True)
        cas.write_bytes(b"wrong-content")
        result = self.adapter.intake(source.relative_to(self.incoming))
        self.assertEqual("cas_collision", result["error"]["code"])
        self.assertTrue((self.root / result["quarantine_path"]).is_file())
        self.assertTrue((self.root / result["receipt"]).is_file())

    def test_missing_cas_cannot_return_duplicate(self):
        source = self.put()
        first = self.adapter.intake(source.relative_to(self.incoming))
        (self.root / first["entry"]["cas_path"]).unlink()
        result = self.adapter.intake(source.relative_to(self.incoming))
        self.assertEqual("cas_missing", result["error"]["code"])
        self.assertEqual("quarantined", result["outcome"])

    def test_reparse_point_substitute_is_rejected(self):
        linkdir = self.incoming / "linkdir"
        linkdir.mkdir()
        self.put("linkdir/input.json")
        original = adapter_module._is_reparse_point

        def fake_reparse(path):
            return path == linkdir or original(path)

        with mock.patch.object(adapter_module, "_is_reparse_point", side_effect=fake_reparse):
            result = self.adapter.intake("linkdir/input.json")
        self.assertEqual("reparse_input", result["error"]["code"])

    def test_windows_junction_is_rejected_when_available(self):
        target = self.root / "junction-target"
        target.mkdir()
        (target / "input.json").write_bytes(json.dumps(envelope()).encode())
        junction = self.incoming / "junction"
        if os.name != "nt":
            self.skipTest("Windows junctions are unavailable")
        made = subprocess.run(["cmd.exe", "/c", "mklink", "/J", str(junction), str(target)],
                              capture_output=True, text=True, check=False)
        if made.returncode != 0:
            self.skipTest("mklink /J is unavailable without administrator privileges")
        try:
            result = self.adapter.intake("junction/input.json")
            self.assertEqual("reparse_input", result["error"]["code"])
        finally:
            os.rmdir(junction)

    def test_windows_junction_inserted_after_path_check_is_rejected(self):
        if os.name != "nt":
            self.skipTest("Windows junctions are unavailable")
        original = self.incoming / "race"
        target = self.root / "race-target"
        original.mkdir()
        target.mkdir()
        (original / "input.json").write_bytes(json.dumps(envelope()).encode())
        (target / "input.json").write_bytes(json.dumps(envelope(payload={"outside": True})).encode())
        junction_target = self.incoming / "race-target-link"
        # The hook runs after lexical validation and before CreateFileW. It
        # replaces the checked directory with a junction to an outside target.
        def inject(_path=None):
            os.rename(original, junction_target)
            made = subprocess.run(["cmd.exe", "/c", "mklink", "/J", str(original), str(target)],
                                  capture_output=True, text=True, check=False)
            if made.returncode != 0:
                raise RuntimeError("mklink /J unavailable")

        self.adapter._before_input_open = inject
        try:
            result = self.adapter.intake("race/input.json")
            self.assertEqual("reparse_input", result["error"]["code"])
        finally:
            if original.exists() and original.is_dir():
                os.rmdir(original)
            if junction_target.exists():
                import shutil
                shutil.rmtree(junction_target)

    def test_windows_output_junction_inserted_before_handle_open_is_rejected(self):
        if os.name != "nt":
            self.skipTest("Windows junctions are unavailable")
        source = self.put()
        digest = adapter_module._sha256(adapter_module._canonical_bytes(envelope()))
        cas_dir = self.root / "cas" / "sha256" / digest[:2]
        outside = self.root / "cas-outside"
        outside.mkdir()

        def inject(_path=None):
            cas_dir.parent.mkdir(parents=True, exist_ok=True)
            made = subprocess.run(["cmd.exe", "/c", "mklink", "/J", str(cas_dir), str(outside)],
                                  capture_output=True, text=True, check=False)
            if made.returncode != 0:
                raise RuntimeError("mklink /J unavailable")

        self.adapter._before_output_open = inject
        try:
            result = self.adapter.intake(source.relative_to(self.incoming))
            self.assertEqual("cas_symlink", result["error"]["code"])
            self.assertTrue((self.root / result["quarantine_path"]).is_file())
            self.assertEqual([], list(outside.iterdir()))
        finally:
            if cas_dir.exists():
                os.rmdir(cas_dir)
            if outside.exists():
                outside.rmdir()

    def test_cas_replacement_race_is_structured_collision(self):
        source = self.put()
        digest = adapter_module._sha256(adapter_module._canonical_bytes(envelope()))
        cas_path = self.root / "cas" / "sha256" / digest[:2] / f"{digest}.json"

        def replace_before_open(_path=None):
            cas_path.parent.mkdir(parents=True, exist_ok=True)
            cas_path.write_bytes(b"replacement")

        self.adapter._before_output_open = replace_before_open
        result = self.adapter.intake(source.relative_to(self.incoming))
        self.assertFalse(result["ok"])
        self.assertEqual("cas_collision", result["error"]["code"])
        self.assertEqual("quarantined", result["outcome"])
        self.assertTrue((self.root / result["receipt"]).is_file())

    def test_two_processes_commit_only_one_sequence(self):
        first = self.put("a.json", envelope(idempotency_key="idem-a", nonce="nonce-a", payload={"a": 1}))
        second = self.put("b.json", envelope(idempotency_key="idem-b", nonce="nonce-b", payload={"b": 1}))
        worker = "from tools.up1_external_closure_r2.authority_intake import AuthorityIntakeAdapter; import json,sys; print(json.dumps(AuthorityIntakeAdapter(sys.argv[1]).intake(sys.argv[2])))"
        procs = [subprocess.Popen([sys.executable, "-B", "-c", worker, str(self.root), str(path.relative_to(self.incoming))], cwd=str(Path(__file__).resolve().parents[3]), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for path in (first, second)]
        outputs = [json.loads(proc.communicate(timeout=20)[0]) for proc in procs]
        self.assertEqual(1, sum(item.get("outcome") == "accepted_local" for item in outputs))
        self.assertEqual(1, sum(item.get("error", {}).get("code") == "sequence_replay" for item in outputs))
        ledger = json.loads(self.adapter.ledger_path.read_text())
        self.assertEqual(1, len(ledger["entries"]))

    def test_metadata_change_during_read_is_toctou_rejection(self):
        if os.name == "nt":
            self.skipTest("Windows handle-pinned race is covered by junction insertion regression")
        source = self.put()
        original_fstat = adapter_module.os.fstat

        def changed_fstat(fd):
            result = original_fstat(fd)
            values = list(result)
            values[6] += 1  # report a changed size for the opened descriptor
            return adapter_module.os.stat_result(tuple(values))

        with mock.patch.object(adapter_module.os, "fstat", side_effect=changed_fstat):
            result = self.adapter.intake("one.json")
        self.assertEqual("toctou", result["error"]["code"])

    def test_scan_is_json_only_and_read_only(self):
        source = self.put()
        before = source.read_bytes()
        (self.incoming / "ignore.txt").write_text("ignored")
        result = self.adapter.scan()
        self.assertEqual(1, len(result))
        self.assertEqual(before, source.read_bytes())

    def test_symlink_is_rejected_when_supported(self):
        target = self.put("target.json")
        link = self.incoming / "link.json"
        try:
            link.symlink_to(target)
        except (OSError, NotImplementedError):
            self.skipTest("symlink creation is unavailable")
        result = self.adapter.intake("link.json")
        self.assertEqual("symlink_input", result["error"]["code"])


if __name__ == "__main__":
    unittest.main()
