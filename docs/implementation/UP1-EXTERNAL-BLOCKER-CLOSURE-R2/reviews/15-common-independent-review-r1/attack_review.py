"""Independent adversarial review driver for UP1-R2 common.

This driver is intentionally additive and does not modify the reviewed package.
It prints JSONL evidence so the review can be replayed with ``python -B``.
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

# Make direct replay from any working directory resolve the isolated package.
sys.path.insert(0, str(Path(__file__).resolve().parents[5]))

from tools.up1_external_closure_r2.common import (
    Status,
    build_receipt,
    canonical_json,
    candidate_fingerprint,
    content_identity,
    parse_json,
    verify_exact_set,
    verify_manifest,
    read_json_file,
)
from tools.up1_external_closure_r2.common.files import read_bytes_limited, safe_relative_path


def emit(name: str, fn) -> None:
    try:
        value = fn()
        print(json.dumps({"name": name, "outcome": "return", "value": repr(value)}, ensure_ascii=True))
    except BaseException as exc:  # review records intentionally include unexpected exceptions
        error = getattr(exc, "error", None)
        print(json.dumps({"name": name, "outcome": "exception", "type": type(exc).__name__,
                          "message": str(exc), "code": getattr(error, "code", None)}, ensure_ascii=True))


class EvilFloat(float):
    def __repr__(self) -> str:
        return "NaN"


class EvilInt(int):
    def __str__(self) -> str:
        return "NaN"


def main() -> None:
    emit("canonical_duplicate_key", lambda: parse_json('{"a":{"x":1,"x":2}}'))
    emit("canonical_invalid_utf8", lambda: parse_json(b'{"x":\x80}'))
    emit("canonical_unicode", lambda: canonical_json({"x": "磁约束"}))
    emit("canonical_nonfinite", lambda: canonical_json(float("nan")))
    emit("canonical_cycle", lambda: (lambda x: (x.update({"self": x}), canonical_json(x))[1])({}))
    emit("canonical_numeric_subclasses", lambda: (canonical_json(EvilFloat(1.0)), canonical_json(EvilInt(1))))
    emit("canonical_large_integer", lambda: canonical_json(10**5000))
    emit("fingerprint_nested_self_reference", lambda: candidate_fingerprint({"nested": {"candidate_fingerprint": "x"}}).as_dict())
    emit("fingerprint_cycle", lambda: (lambda x: (x.update({"self": x}), candidate_fingerprint(x))[1])({}))

    base = dict(status=Status.PASS, command=("x",), working_directory=".", pid=1,
                utc_start="2026-01-01T00:00:00Z", utc_end="2026-01-01T00:00:00Z",
                exit_code=0, stdout=b"", stderr=b"")
    emit("receipt_fake_candidate_domain", lambda: build_receipt(
        **base, candidate={"digest": "0" * 64, "domain": "up1:source"})["candidate_fingerprint"])
    emit("receipt_conflicting_digest_alias", lambda: build_receipt(
        **base, candidate={"digest": "0" * 64, "sha256": "1" * 64})["candidate_fingerprint"])
    emit("receipt_unknown_status", lambda: build_receipt(**{**base, "status": "banana"})["status"])
    emit("receipt_reverse_utc", lambda: build_receipt(**{**base,
        "utc_start": "2026-01-02T00:00:00Z", "utc_end": "2026-01-01T00:00:00Z"})["utc"])
    emit("content_identity_canonical_false", lambda: (
        content_identity({"a": 1}, canonical=True).digest,
        content_identity({"a": 1}, canonical=False).digest))

    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        target = root / "target"
        staged = root / "staged"
        target.write_bytes(b"OK")
        staged.write_bytes(b"EVIL")
        original_open = Path.open

        def race_open(self, *args, **kwargs):
            if self == target:
                os.replace(staged, target)
            return original_open(self, *args, **kwargs)

        with patch.object(Path, "open", race_open):
            raced = read_bytes_limited(target, max_bytes=10)
        print(json.dumps({"name": "read_stat_open_toctou", "outcome": "return",
                          "initial_size": 2, "read_after_replacement": raced.decode("ascii")}, ensure_ascii=True))

        payload = root / "a"
        payload.write_bytes(b"a")
        digest = hashlib.sha256(b"a").hexdigest()
        print(json.dumps({"name": "manifest_duplicate_normalized", "outcome": "return",
                          "value": verify_exact_set(root, [{"path": "a", "sha256": digest},
                                                             {"path": "./a", "sha256": digest}]).as_dict()}, ensure_ascii=True))
        for path in ("../x", "C:/x", "/x", "\\\\server\\x", ""):
            emit("path_escape_" + repr(path), lambda path=path: safe_relative_path(path))

    review_root = Path("docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/15-common")
    manifest = read_json_file(review_root / "manifest.json")
    print(json.dumps({"name": "implementation_manifest", "outcome": "return",
                      "value": verify_manifest(review_root, manifest).as_dict()}, ensure_ascii=True))
    hashes = read_json_file(review_root / "input_hashes.json")["files"]
    checks = {path: hashlib.sha256(Path(path).read_bytes()).hexdigest() == expected
              for path, expected in hashes.items()}
    print(json.dumps({"name": "implementation_input_hashes", "outcome": "return",
                      "all_match": all(checks.values()), "checks": checks}, ensure_ascii=True))


if __name__ == "__main__":
    main()
