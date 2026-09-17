from __future__ import annotations

import hashlib
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.up1_external_closure_r3.atomic_bundle import canonical_bytes, validate_bundle
from tools.up1_external_closure_r3.atomic_bundle import bundle as impl
from tools.up1_external_closure_r3.atomic_bundle.canonical import CanonicalError
from test_atomic_bundle_vectors import all_vectors, _json_bytes, _semantic_execute


class P1RegressionTests(unittest.TestCase):
    def test_cas_external_hardlink_is_rejected_by_link_identity(self):
        raw = b"external-hardlink-regression"
        digest = hashlib.sha256(raw).hexdigest()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "q"
            outside = Path(tmp) / "outside-object"
            outside.write_bytes(raw)
            (root / "cas").mkdir(parents=True)
            target = root / "cas" / digest
            try:
                os.link(outside, target)
            except (OSError, NotImplementedError) as exc:
                self.skipTest(f"hardlink unavailable on this host: {type(exc).__name__}: {exc}")
            with self.assertRaises(OSError) as raised:
                impl.quarantine_raw(raw, root)
            self.assertIn("CAS_HARDLINK_REJECTED", str(raised.exception))

    def test_reparse_probe_is_injected_and_unavailable_probe_is_real_skip(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "target"
            target.mkdir()
            link = Path(tmp) / "link"
            try:
                os.symlink(target, link, target_is_directory=True)
            except (OSError, NotImplementedError) as exc:
                self.skipTest(f"symlink/reparse probe unavailable on this host: {type(exc).__name__}: {exc}")
            with self.assertRaises(OSError) as raised:
                impl.quarantine_raw(b"reparse-probe", link)
            self.assertIn("CAS_REPARSE_POINT_REJECTED", str(raised.exception))

    def test_decision_precedence_rejects_real_errors_before_fixture_defer(self):
        result = impl._result("a" * 64, {}, {"cas_path": "", "receipt": {}}, [{"code": "EHP03_G2_ROW_DIGEST_MISMATCH", "path": "/g2"}], "not_executed", True)
        self.assertEqual(result["decision"], "rejected_all")
        deferred = impl._result("a" * 64, {}, {"cas_path": "", "receipt": {}}, [], "not_executed", True)
        self.assertEqual(deferred["decision"], "terminal_deferred")

    def test_unavailable_cas_identity_is_typed_deferred(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(impl, "_link_count", return_value=None):
            result = validate_bundle(b"cas-identity-unavailable", quarantine_root=Path(tmp) / "q")
        self.assertEqual(result["decision"], "terminal_deferred")
        self.assertIn("CAS_INSTALL_UNAVAILABLE", result["failure_codes"])
        self.assertTrue(result["no_publish"])

    def test_fallback_rejects_float_and_exponent_without_collision(self):
        with self.assertRaises(CanonicalError) as raised:
            canonical_bytes({"n": 1e20})
        self.assertEqual(raised.exception.code, "CANONICAL_NUMBER_UNSUPPORTED")
        self.assertNotEqual(canonical_bytes({"n": 1}), b'{"n":1.0}')

    def test_malformed_shapes_return_typed_result(self):
        for raw in (b'{"schema":"x","packets":[{"payload":1}]}', b'[]', b'{"schema":1}'):
            with self.subTest(raw=raw):
                result = validate_bundle(raw)
                self.assertIn(result["status"], {"fail_limited", "prototype_pass_limited"})
                self.assertIn("SCHEMA_INVALID", result["failure_codes"])
                self.assertTrue(result["no_publish"])

    def test_cas_collision_is_fail_closed_and_idempotent(self):
        raw = b"atomic-cas-regression"
        digest = hashlib.sha256(raw).hexdigest()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "q"
            (root / "cas").mkdir(parents=True)
            (root / "cas" / digest).write_bytes(b"different")
            with self.assertRaises(OSError) as raised:
                impl.quarantine_raw(raw, root)
            self.assertIn("CAS_COLLISION_FAIL_CLOSED", str(raised.exception))
            (root / "cas" / digest).write_bytes(raw)
            first = impl.quarantine_raw(raw, root)
            second = impl.quarantine_raw(raw, root)
            self.assertEqual(first["cas_path"], second["cas_path"])
            self.assertEqual(Path(first["cas_path"]).read_bytes(), raw)

    def test_receiver_receipt_tamper_is_independently_rejected(self):
        raw = b"receiver-receipt-regression"
        with tempfile.TemporaryDirectory() as tmp:
            q = impl.quarantine_raw(raw, tmp)
            fake = {"set_receipt": {"quarantine_receipt": dict(q["receipt"])}}
            fake["set_receipt"]["quarantine_receipt"]["cas_transaction_id"] = "attacker"
            errors: list[dict[str, str]] = []
            impl._check_quarantine(fake, q, errors, raw)
            self.assertIn("QUARANTINE_RECEIPT_NOT_BOUND", {x["code"] for x in errors})
            self.assertIn("QUARANTINE_TRANSACTION_MISMATCH", {x["code"] for x in errors})
            fake["set_receipt"]["quarantine_receipt"] = dict(q["receipt"])
            fake["set_receipt"]["quarantine_receipt"]["receiver_signature"] = dict(q["receipt"]["receiver_signature"])
            fake["set_receipt"]["quarantine_receipt"]["receiver_signature"]["signature_b64"] = "AAAA"
            errors = []
            impl._check_quarantine(fake, q, errors, raw)
            self.assertIn("QUARANTINE_RECEIPT_NOT_BOUND", {x["code"] for x in errors})
            self.assertIn("QUARANTINE_RECEIVER_SIGNATURE_INVALID", {x["code"] for x in errors})

    def test_test_only_trust_context_is_non_evidence(self):
        # The public API never treats caller-selected or TEST_ONLY trust
        # material as an authority input, even when the key map is otherwise
        # well-formed.
        result = validate_bundle(b'{"schema":"wrong"}', context={"public_keys": {"TEST_ONLY-owner": "x"}, "security_ok": True, "security_profile": "TEST_ONLY-R3"})
        self.assertIn("SCHEMA_INVALID", result["failure_codes"])
        self.assertTrue(result["no_publish"])


class AcceptanceVectorExecutionTests(unittest.TestCase):
    """Concrete offline execution of every R01-R25 and D01 inventory ID."""

    def test_r01_r25_and_d01_execute_fail_closed(self):
        # R01/R23 use the public parser/schema boundary.  The remaining IDs
        # use the companion harness's direct production predicate calls so the
        # intentionally self-referential wire digest cannot mask their target
        # semantic path with SCHEMA_INVALID.
        vectors = all_vectors()
        receipts = []
        for vector in vectors:
            with self.subTest(vector=vector.vector_id):
                built = vector.build()
                raw = _json_bytes(built)
                actual_code, called_function, result = _semantic_execute(vector, built, raw)
                self.assertTrue(result["no_publish"])
                self.assertEqual(result["decision"], vector.decision)
                expected_code = None if vector.expected in {"no_failure_code", "internal accepted_all only"} else vector.expected
                self.assertEqual(actual_code, expected_code)
                receipts.append({
                    "vector_id": vector.vector_id,
                    "path": vector.mutation_path,
                    "input_hash": hashlib.sha256(raw).hexdigest(),
                    "called_function": called_function,
                    "actual_code": actual_code or "no_failure_code",
                    "actual_decision": result["decision"],
                })
        self.assertEqual(len(receipts), 26)
        self.assertEqual({x["vector_id"] for x in receipts}, {f"R{i:02d}" for i in range(1, 26)} | {"D01"})
        self.assertEqual(len({x["input_hash"] for x in receipts}), 26)
        for receipt in receipts:
            self.assertTrue(receipt["called_function"])


if __name__ == "__main__":
    unittest.main()
