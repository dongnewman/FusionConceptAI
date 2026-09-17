"""Fresh R3 adversarial review for UP1-R2 common; reviewed code is read-only."""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(ROOT))

from tools.up1_external_closure_r2.common import (  # noqa: E402
    CANONICALIZATION_VERSION,
    Fingerprint,
    Status,
    build_receipt,
    canonical_json,
    candidate_fingerprint,
    content_identity,
    parse_json,
    read_json_file,
    source_fingerprint,
    verify_exact_set,
    verify_manifest,
)
from tools.up1_external_closure_r2.common.files import SafeFileError, read_bytes_limited, safe_relative_path  # noqa: E402


class EvilFloat(float):
    def __repr__(self):
        return "NaN"


class EvilInt(int):
    def __str__(self):
        return "NaN"


def emit(name, fn):
    try:
        value = fn()
        detail = value if isinstance(value, (str, int, bool)) else type(value).__name__
        print(json.dumps({"name": name, "outcome": "return", "detail": detail}, ensure_ascii=True))
    except BaseException as exc:
        error = getattr(exc, "error", None)
        print(json.dumps({"name": name, "outcome": "exception", "type": type(exc).__name__,
                          "code": getattr(error, "code", getattr(exc, "code", None))}, ensure_ascii=True))


def base_receipt():
    return dict(status=Status.PASS, command=("python", "-B", "check.py"), working_directory=".", pid=1234,
                utc_start="2026-01-01T00:00:00Z", utc_end="2026-01-01T00:00:01Z",
                exit_code=0, stdout=b"ok\n", stderr=b"")


def candidate_mapping(**changes):
    preimage = '{"canonicalization":"UP1-R2-CJSON-1","domain":"up1:candidate","payload":null,"version":"v1"}'
    value = {"type": "candidate_fingerprint", "domain": "up1:candidate", "version": "v1",
             "algorithm": "sha256", "canonicalization": CANONICALIZATION_VERSION,
             "preimage": preimage, "digest": hashlib.sha256(preimage.encode("ascii")).hexdigest()}
    value.update(changes)
    return value


def two_process_determinism():
    child = r'''
import json
from tools.up1_external_closure_r2.common import Status, build_receipt, candidate_fingerprint, canonical_json, receipt_digest, source_fingerprint
c=candidate_fingerprint({"z":2,"unicode":"磁约束","n":1.0}); s=source_fingerprint({"uri":"fixture://source","n":1})
r=build_receipt(status=Status.PASS,command=("python","-B","check.py"),working_directory=".",pid=1234,utc_start="2026-01-01T00:00:00Z",utc_end="2026-01-01T00:00:01Z",exit_code=0,stdout=b"ok\n",stderr=b"",candidate=c,source=s,inputs={"x":"0"*64},outputs={"y":"1"*64})
print(json.dumps({"canonical":canonical_json({"z":2,"unicode":"磁约束","n":1.0}),"candidate":c.digest,"source":s.digest,"receipt":receipt_digest(r)},sort_keys=True))
'''
    common = {"cwd": ROOT, "stdout": subprocess.PIPE, "stderr": subprocess.PIPE, "text": True}
    p1 = subprocess.Popen([sys.executable, "-B", "-c", child], env=dict(os.environ, PYTHONHASHSEED="1"), **common)
    p2 = subprocess.Popen([sys.executable, "-B", "-c", child], env=dict(os.environ, PYTHONHASHSEED="2"), **common)
    out1, err1 = p1.communicate(); out2, err2 = p2.communicate()
    return {"exit_codes": [p1.returncode, p2.returncode], "pids_distinct": p1.pid != p2.pid,
            "stderr_empty": not err1 and not err2, "stdout_equal": out1 == out2,
            "stdout_sha256": hashlib.sha256(out1.encode()).hexdigest()}


def replacement_pressure():
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary); target = root / "target"; staged = root / "staged"
        original_open = os.open; rejected = leaked = 0
        for _ in range(256):
            target.write_bytes(b"OK"); staged.write_bytes(b"EVIL")
            def race(path, flags, *args, **kwargs):
                if Path(path) == target: os.replace(staged, target)
                return original_open(path, flags, *args, **kwargs)
            try:
                with patch.object(os, "open", race): data = read_bytes_limited(target, max_bytes=16)
                leaked += int(data == b"EVIL")
            except SafeFileError as exc:
                rejected += int(exc.error.code == "identity_mismatch")
        return {"iterations": 256, "identity_mismatch_rejections": rejected,
                "leaked_replacements": leaked, "all_rejected": rejected == 256 and leaked == 0}


def main():
    emit("canonical_duplicate_key", lambda: parse_json('{"a":{"x":1,"x":2}}'))
    emit("canonical_invalid_utf8", lambda: parse_json(b'{"x":\x80}'))
    emit("canonical_unicode", lambda: canonical_json({"x": "磁约束"}))
    emit("canonical_lone_surrogate", lambda: canonical_json({"x": "\ud800"}))
    emit("canonical_json_nan", lambda: parse_json(b'{"x":NaN}'))
    emit("canonical_json_inf", lambda: parse_json(b'{"x":Infinity}'))
    emit("canonical_nan", lambda: canonical_json(float("nan")))
    emit("canonical_inf", lambda: canonical_json(float("inf")))
    emit("canonical_negative_zero", lambda: canonical_json(-0.0))
    emit("canonical_numeric_subclasses", lambda: (canonical_json(EvilFloat(1.0)), canonical_json(EvilInt(1))))
    emit("canonical_large_integer", lambda: canonical_json(10**5000))
    emit("canonical_large_json_integer", lambda: parse_json(b'{"x":' + b"9" * 5000 + b'}'))
    cycle = {}; cycle["self"] = cycle
    emit("canonical_cycle", lambda: canonical_json(cycle))
    nested = {"nested": {"candidate_fingerprint": "x"}}
    emit("fingerprint_nested_self_reference", lambda: candidate_fingerprint(nested))
    fp_cycle = {}; fp_cycle["self"] = fp_cycle
    emit("fingerprint_cycle", lambda: candidate_fingerprint(fp_cycle))
    emit("candidate_source_domain_separation", lambda: candidate_fingerprint({"x": 1}).digest == source_fingerprint({"x": 1}).digest)

    emit("receipt_fake_candidate_domain", lambda: build_receipt(**base_receipt(), candidate={"type": "candidate_fingerprint", "digest": "0" * 64, "domain": "up1:source", "version": "v1", "algorithm": "sha256", "canonicalization": CANONICALIZATION_VERSION, "preimage": "{\"canonicalization\":\"UP1-R2-CJSON-1\",\"domain\":\"up1:source\",\"payload\":null,\"version\":\"v1\"}"}))
    emit("receipt_conflicting_digest_alias", lambda: build_receipt(**base_receipt(), candidate={"type": "candidate_fingerprint", "digest": "0" * 64, "sha256": "1" * 64, "domain": "up1:candidate", "version": "v1", "algorithm": "sha256", "canonicalization": CANONICALIZATION_VERSION, "preimage": "{\"canonicalization\":\"UP1-R2-CJSON-1\",\"domain\":\"up1:candidate\",\"payload\":null,\"version\":\"v1\"}"}))
    emit("receipt_bad_candidate_version", lambda: build_receipt(**base_receipt(), candidate=candidate_mapping(version=1)))
    emit("receipt_bad_candidate_type", lambda: build_receipt(**base_receipt(), candidate=candidate_mapping(type="source_fingerprint")))
    emit("receipt_bad_preimage_digest", lambda: build_receipt(**base_receipt(), candidate=candidate_mapping(digest="0" * 64)))
    emit("receipt_unknown_status", lambda: build_receipt(**{**base_receipt(), "status": "banana"}))
    emit("receipt_reverse_utc", lambda: build_receipt(**{**base_receipt(), "utc_start": "2026-01-02T00:00:00Z", "utc_end": "2026-01-01T00:00:00Z"}))
    emit("receipt_unknown_error", lambda: build_receipt(**base_receipt(), error={"code": "not_taxonomy", "message": "x"}))
    emit("receipt_forged_fingerprint", lambda: Fingerprint("up1:candidate", "v1", "0" * 64, b"forged", CANONICALIZATION_VERSION))
    emit("receipt_malformed_error_details", lambda: build_receipt(**{**base_receipt(), "status": Status.FAIL_CLOSED}, error={"code": "invalid_field", "message": "x", "details": []}))
    emit("receipt_malformed_error_path", lambda: build_receipt(**{**base_receipt(), "status": Status.FAIL_CLOSED}, error={"code": "invalid_field", "message": "x", "path": 3}))
    emit("content_identity_canonical_false", lambda: content_identity({"a": 1}, canonical=True).digest == content_identity({"a": 1}, canonical=False).digest)

    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        cases = {"utf8": b'{"x":\x80}', "syntax": b'{"x":', "finite": b'{"x":NaN}', "number": b'{"x":-0.0}'}; errors = {}
        for name, data in cases.items():
            path = root / (name + ".json"); path.write_bytes(data)
            try: read_json_file(path)
            except SafeFileError as exc: errors[name] = exc.error.code
        print(json.dumps({"name": "json_error_taxonomy", "outcome": "return", "detail": errors}, ensure_ascii=True))
        target = root / "target"; staged = root / "staged"; target.write_bytes(b"OK"); staged.write_bytes(b"EVIL"); original_open = os.open
        def race(path, flags, *args, **kwargs):
            if Path(path) == target: os.replace(staged, target)
            return original_open(path, flags, *args, **kwargs)
        with patch.object(os, "open", race):
            try: read_bytes_limited(target); race_result = "unexpected_return"
            except SafeFileError as exc: race_result = exc.error.code
        print(json.dumps({"name": "read_stat_open_toctou", "outcome": "return", "detail": race_result}, ensure_ascii=True))
        payload = root / "a"; payload.write_bytes(b"a"); digest = hashlib.sha256(b"a").hexdigest()
        print(json.dumps({"name": "manifest_bare_string", "outcome": "return", "detail": verify_exact_set(root, "target").errors[0].code}, ensure_ascii=True))
        print(json.dumps({"name": "manifest_duplicate_normalized", "outcome": "return", "detail": verify_exact_set(root, [{"path": "a", "sha256": digest}, {"path": "./a", "sha256": digest}]).errors[0].code}, ensure_ascii=True))
        check = verify_exact_set(root, {"a": "0" * 64, "missing": "1" * 64})
        print(json.dumps({"name": "manifest_missing_extra_hash_mismatch", "outcome": "return", "detail": [e.code for e in check.errors]}, ensure_ascii=True))
        try:
            link = root / "link"; os.symlink(payload, link); symlink = {"available": True}
            try: read_bytes_limited(link)
            except SafeFileError as exc: symlink["read_code"] = exc.error.code
        except OSError as exc:
            symlink = {"available": False, "winerror": getattr(exc, "winerror", None)}
        print(json.dumps({"name": "windows_symlink_control", "outcome": "return", "detail": symlink}, ensure_ascii=True))
        for path in ("../x", "C:/x", "/x", "\\\\server\\x", ""):
            emit("path_escape_" + repr(path), lambda path=path: safe_relative_path(path))

    print(json.dumps({"name": "two_process_determinism", "outcome": "return", "detail": two_process_determinism()}, ensure_ascii=True))
    print(json.dumps({"name": "windows_replacement_pressure", "outcome": "return", "detail": replacement_pressure()}, ensure_ascii=True))
    review_root = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/15-common"; manifest = read_json_file(review_root / "manifest.json")
    print(json.dumps({"name": "implementation_manifest", "outcome": "return", "detail": verify_manifest(review_root, manifest).ok}, ensure_ascii=True))
    hashes = read_json_file(review_root / "input_hashes.json")["files"]; checks = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() == h for p, h in hashes.items()}
    print(json.dumps({"name": "implementation_input_hashes", "outcome": "return", "detail": all(checks.values())}, ensure_ascii=True))


if __name__ == "__main__":
    main()
