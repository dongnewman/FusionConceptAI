from __future__ import annotations

import hashlib
import json
import os
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

from tools.up1_external_closure_r2.common import (
    DuplicateKeyError,
    ErrorCode,
    EvidenceError,
    NonCanonicalJSONError,
    NonCanonicalNumberError,
    Status,
    build_receipt,
    candidate_fingerprint,
    canonical_json,
    canonical_json_bytes,
    content_identity,
    parse_canonical_json,
    parse_json,
    receipt_digest,
    source_fingerprint,
    verify_exact_set,
)
from tools.up1_external_closure_r2.common.files import SafeFileError, read_bytes_limited, read_json_file
from tools.up1_external_closure_r2.common.identity import Fingerprint
from tools.up1_external_closure_r2.common.taxonomy import TypedError


class CanonicalJSONTests(unittest.TestCase):
    def test_order_and_unicode_are_stable(self):
        self.assertEqual(canonical_json({"z": 1, "a": [True, "磁约束"]}), '{"a":[true,"\\u78c1\\u7ea6\\u675f"],"z":1}')
        self.assertEqual(canonical_json({"a": 1}), canonical_json(parse_json('{"a":1}')))

    def test_negative_values_are_rejected(self):
        class EvilFloat(float):
            def __repr__(self):
                return "NaN"
        class EvilInt(int):
            def __str__(self):
                return "NaN"
        cases = [float("nan"), float("inf"), float("-inf"), -0.0, EvilFloat(1.0), EvilInt(1), {"x": b"bytes"}, {1: "bad"}]
        for value in cases:
            with self.subTest(value=repr(value)):
                with self.assertRaises((ValueError, TypeError)):
                    canonical_json(value)
        with self.assertRaises(DuplicateKeyError):
            parse_json('{"a":1,"a":2}')
        with self.assertRaises(NonCanonicalJSONError):
            parse_json(b"{\x80}")
        for raw in (b'{"a": 1}', b'{"b":2,"a":1}', b'{"a":1.0}', b'{"a":-0.0}'):
            with self.subTest(raw=raw):
                with self.assertRaises(NonCanonicalJSONError):
                    parse_canonical_json(raw)
        with self.assertRaises(NonCanonicalNumberError):
            parse_json(b'{"x":' + b"9" * 5000 + b"}")

    def test_round_trip_bytes_and_identity(self):
        value = {"a": [1, 2], "b": None}
        encoded = canonical_json_bytes(value)
        self.assertEqual(parse_canonical_json(encoded), value)
        identity = content_identity(value)
        self.assertEqual(identity.digest, hashlib.sha256(encoded).hexdigest())
        self.assertEqual(identity.byte_length, len(encoded))


class FileAndManifestTests(unittest.TestCase):
    def test_bounded_read_and_exact_set(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "a.txt").write_bytes(b"a")
            (root / "nested").mkdir()
            (root / "nested" / "b.bin").write_bytes(b"bb")
            expected = {
                "a.txt": hashlib.sha256(b"a").hexdigest(),
                "nested/b.bin": hashlib.sha256(b"bb").hexdigest(),
            }
            check = verify_exact_set(root, expected)
            self.assertTrue(check.ok, check.as_dict())
            (root / "extra").write_bytes(b"x")
            self.assertIn("extra", verify_exact_set(root, expected).unexpected)
            with self.assertRaises(SafeFileError) as raised:
                read_bytes_limited(root / "nested" / "b.bin", max_bytes=1)
            self.assertEqual(raised.exception.error.code, ErrorCode.FILE_TOO_LARGE.value)

    def test_json_file_rejects_duplicate(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "x.json"
            path.write_text('{"x":1,"x":2}', encoding="utf-8")
            with self.assertRaises(SafeFileError):
                read_json_file(path)

    def test_json_file_preserves_error_taxonomy(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            cases = {
                "encoding": b'{"x":\x80}',
                "syntax": b'{"x":',
                "finite": b'{"x":NaN}',
                "number": b'{"x":-0.0}',
            }
            expected = {"encoding": "invalid_utf8", "syntax": "invalid_json_syntax", "finite": "non_finite_number", "number": "non_canonical_number"}
            for name, data in cases.items():
                path = root / (name + ".json")
                path.write_bytes(data)
                with self.subTest(name=name), self.assertRaises(SafeFileError) as raised:
                    read_json_file(path)
                self.assertEqual(raised.exception.error.code, expected[name])


class FingerprintAndReceiptTests(unittest.TestCase):
    def test_domain_separation_and_self_reference_guard(self):
        payload = {"id": "c-1", "version": 1}
        candidate = candidate_fingerprint(payload)
        source = source_fingerprint(payload)
        self.assertNotEqual(candidate.digest, source.digest)
        with self.assertRaises(EvidenceError) as raised:
            candidate_fingerprint({"id": "c-1", "candidate_fingerprint": "bad"})
        self.assertEqual(raised.exception.error.code, ErrorCode.SELF_REFERENCE.value)

    def test_receipt_is_deterministic_and_self_excluded(self):
        kwargs = dict(
            status=Status.PASS,
            command=("python", "-B", "check.py"),
            working_directory="D:/fixture",
            pid=1234,
            utc_start="2026-09-17T01:02:03.000000Z",
            utc_end="2026-09-17T01:02:04.000000Z",
            exit_code=0,
            stdout=b"ok\n",
            stderr=b"",
            candidate=candidate_fingerprint({"id": "c-1"}),
            source=source_fingerprint({"uri": "fixture://s", "version": "1"}),
            inputs={"input.json": hashlib.sha256(b"input").hexdigest()},
            outputs={"result.json": hashlib.sha256(b"result").hexdigest()},
        )
        first = build_receipt(**kwargs)
        second = build_receipt(**kwargs)
        self.assertEqual(first, second)
        self.assertEqual(first["receipt_sha256"], receipt_digest(first))
        tampered = dict(first)
        tampered["receipt_sha256"] = "0" * 64
        self.assertEqual(receipt_digest(tampered), first["receipt_sha256"])

    def test_receipt_requires_explicit_observations(self):
        with self.assertRaises(EvidenceError):
            build_receipt(
                status="pass", command=("x",), working_directory=".", pid=1,
                utc_start="", utc_end="2026-09-17T00:00:00Z", exit_code=0,
                stdout=b"", stderr=b"",
            )

    def test_receipt_rejects_unknown_error_and_bad_status_mapping(self):
        kwargs = dict(status=Status.PASS, command=("x",), working_directory=".", pid=1,
                      utc_start="2026-01-01T00:00:00Z", utc_end="2026-01-01T00:00:00Z",
                      exit_code=0, stdout=b"", stderr=b"")
        with self.assertRaises(EvidenceError):
            build_receipt(**{**kwargs, "status": "banana"})
        with self.assertRaises(EvidenceError):
            build_receipt(**{**kwargs, "status": Status.NON_EVIDENCE})
        with self.assertRaises(EvidenceError):
            build_receipt(**kwargs, error={"code": "not_taxonomy", "message": "x"})
        with self.assertRaises(EvidenceError):
            build_receipt(**kwargs, error={"code": "invalid_field", "message": "x", "details": []})
        with self.assertRaises(EvidenceError):
            build_receipt(**kwargs, error={"code": "invalid_field", "message": "x", "path": "../escape"})

    def test_receipt_rejects_forged_fingerprint_preimage(self):
        kwargs = dict(status=Status.PASS, command=("x",), working_directory=".", pid=1,
                      utc_start="2026-01-01T00:00:00Z", utc_end="2026-01-01T00:00:00Z",
                      exit_code=0, stdout=b"", stderr=b"")
        fp = candidate_fingerprint({"id": "c-1"}).as_dict()
        fp["digest"] = "0" * 64
        with self.assertRaises(EvidenceError):
            build_receipt(**kwargs, candidate=fp)

    def test_receipt_rejects_serializer_subclasses_and_closed_field_subclasses(self):
        kwargs = dict(status=Status.PASS, command=("x",), working_directory=".", pid=1,
                      utc_start="2026-01-01T00:00:00Z", utc_end="2026-01-01T00:00:00Z",
                      exit_code=0, stdout=b"", stderr=b"")

        class ForgedFingerprint(Fingerprint):
            def as_dict(self):
                return {"type": "candidate_fingerprint", "domain": "up1:candidate",
                        "version": "v1", "algorithm": "sha256", "digest": "0" * 64,
                        "canonicalization": "UP1-R2-CJSON-1", "preimage": "{}"}

        real = candidate_fingerprint({"id": "c-1"})
        forged = ForgedFingerprint(real.domain, real.version, real.digest, real.preimage)
        with self.assertRaises(EvidenceError):
            build_receipt(**kwargs, candidate=forged)

        class ForgedError(TypedError):
            def as_dict(self):
                return {"code": "invalid_field", "message": "x", "details": []}

        with self.assertRaises(EvidenceError):
            build_receipt(**kwargs, error=ForgedError(ErrorCode.INVALID_FIELD.value, "x"))

    def test_manifest_rejects_bare_string_and_open_replacement(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / "target"
            staged = root / "staged"
            target.write_bytes(b"OK")
            staged.write_bytes(b"EVIL")
            original_open = os.open

            def race_open(path, flags, *args, **kwargs):
                if Path(path) == target:
                    os.replace(staged, target)
                return original_open(path, flags, *args, **kwargs)

            with patch.object(os, "open", race_open):
                with self.assertRaises(SafeFileError) as raised:
                    read_bytes_limited(target)
            self.assertEqual(raised.exception.error.code, "identity_mismatch")
            result = verify_exact_set(root, "target")
            self.assertFalse(result.ok)
            self.assertEqual(result.errors[0].code, "manifest_malformed")


if __name__ == "__main__":
    unittest.main()
