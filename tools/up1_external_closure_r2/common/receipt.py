"""Deterministic execution receipt builder with an explicit self-hash policy."""

from __future__ import annotations

import re
from collections.abc import Mapping, Sequence
from datetime import datetime
from typing import Any, Iterable

from .canonical import CANONICALIZATION_VERSION, canonical_json_bytes, parse_canonical_json
from .identity import Fingerprint, sha256_hex
from .taxonomy import ErrorCode, EvidenceError, Status, TypedError

RECEIPT_SCHEMA_VERSION = "UP1-R2-receipt-v1"
_HEX64 = re.compile(r"^[0-9a-f]{64}$")
_SELF_FIELDS = frozenset({"receipt_sha256", "receipt_digest", "self_hash"})


def _hash(value: Any, name: str) -> str:
    if isinstance(value, (bytes, bytearray, memoryview)):
        return sha256_hex(value)
    if isinstance(value, str) and _HEX64.fullmatch(value):
        return value
    raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, f"{name} must be bytes or lowercase SHA-256", name))


def _utc_text(value: str, field: str) -> str:
    if not isinstance(value, str) or not value:
        raise EvidenceError(TypedError(ErrorCode.MISSING_FIELD.value, f"{field} must be supplied explicitly", field))
    # A receipt records the caller's observation; it never obtains current time.
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00" if value.endswith("Z") else value)
    except (TypeError, ValueError) as exc:
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, f"{field} is not ISO-8601", field)) from exc
    if parsed.tzinfo is None:
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, f"{field} must include a timezone", field))
    # Normalize only the spelling, never the time source or instant.
    return parsed.isoformat(timespec="microseconds").replace("+00:00", "Z") if parsed.utcoffset().total_seconds() == 0 else parsed.isoformat(timespec="microseconds")


def _fp(value: Any, field: str, expected_domain: str) -> dict[str, Any] | None:
    if value is None:
        return None
    if type(value) is Fingerprint:
        value = value.as_dict()
    if type(value) is not dict:
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, f"{field} must be a fingerprint object", field))
    allowed = {"type", "domain", "version", "algorithm", "digest", "sha256", "canonicalization", "preimage"}
    if any(type(key) is not str for key in value):
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, f"{field} keys must be builtin strings", field))
    unknown = set(value) - allowed
    if unknown:
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, f"{field} contains unknown fields", field, {"fields": sorted(unknown)}))
    digest_alias = value.get("digest")
    sha_alias = value.get("sha256")
    if digest_alias is not None and sha_alias is not None and digest_alias != sha_alias:
        raise EvidenceError(TypedError(ErrorCode.IDENTITY_MISMATCH.value, f"{field} digest/sha256 aliases conflict", field))
    digest = digest_alias if digest_alias is not None else sha_alias
    if type(digest) is not str or not _HEX64.fullmatch(digest):
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, f"{field} has invalid digest", field))
    expected_type = "candidate_fingerprint" if expected_domain == "up1:candidate" else "source_fingerprint"
    if value.get("type") != expected_type:
        raise EvidenceError(TypedError(ErrorCode.IDENTITY_MISMATCH.value, f"{field} type is not {expected_type}", field))
    if value.get("domain") != expected_domain:
        raise EvidenceError(TypedError(ErrorCode.IDENTITY_MISMATCH.value, f"{field} domain is not {expected_domain}", field))
    if type(value.get("version")) is not str or not value["version"]:
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, f"{field} version is required", field))
    if value.get("algorithm") != "sha256":
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, f"{field} algorithm must be sha256", field))
    if value.get("canonicalization") != CANONICALIZATION_VERSION:
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, f"{field} canonicalization profile mismatch", field))
    preimage = value.get("preimage")
    if type(preimage) is not str:
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, f"{field} preimage must be canonical JSON text", field))
    try:
        preimage_obj = parse_canonical_json(preimage.encode("ascii"))
    except (UnicodeEncodeError, ValueError) as exc:
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, f"{field} preimage is not canonical JSON", field)) from exc
    if not isinstance(preimage_obj, dict) or preimage_obj.get("domain") != expected_domain or preimage_obj.get("version") != value.get("version") or preimage_obj.get("canonicalization") != CANONICALIZATION_VERSION:
        raise EvidenceError(TypedError(ErrorCode.IDENTITY_MISMATCH.value, f"{field} preimage header mismatch", field))
    if sha256_hex(preimage.encode("ascii")) != digest:
        raise EvidenceError(TypedError(ErrorCode.IDENTITY_MISMATCH.value, f"{field} digest does not match preimage", field))
    result = dict(value)
    result["digest"] = digest
    result.pop("sha256", None)
    result.setdefault("algorithm", "sha256")
    return result


def _preimage(receipt: Mapping[str, Any]) -> bytes:
    return canonical_json_bytes({key: value for key, value in receipt.items() if key not in _SELF_FIELDS})


def receipt_digest(receipt: Mapping[str, Any]) -> str:
    """Recompute the digest over the defined self-excluded preimage."""
    if not isinstance(receipt, Mapping):
        raise TypeError("receipt must be an object")
    return sha256_hex(_preimage(receipt))


def _closed_json(value: Any, path: str = "$") -> None:
    """Require the receipt extension fields to use only closed JSON types."""
    if value is None or type(value) in (bool, int, float, str):
        # The canonical encoder performs finite/negative-zero checks.
        canonical_json_bytes(value)
        return
    if type(value) is list:
        for index, item in enumerate(value):
            _closed_json(item, f"{path}[{index}]")
        return
    if type(value) is dict:
        for key, item in value.items():
            if type(key) is not str or not key:
                raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, "closed object keys must be non-empty builtin strings", path))
            _closed_json(item, f"{path}.{key}")
        return
    raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, "receipt extension contains an unsupported type", path))


def _validate_error_path(path: Any) -> None:
    if type(path) is not str or not path or "\x00" in path or any(ord(ch) < 0x20 for ch in path):
        raise EvidenceError(TypedError(ErrorCode.INVALID_ERROR.value, "error path must be a non-empty canonical path string", "error.path"))
    if path.startswith(("/", "\\")) or "\\" in path or ".." in path:
        raise EvidenceError(TypedError(ErrorCode.INVALID_ERROR.value, "error path must not escape its scope", "error.path"))


def _validate_error(error: TypedError | Mapping[str, Any], status: str) -> dict[str, Any]:
    """Validate typed error shape and its relationship to receipt status."""
    known = {item.value for item in ErrorCode}
    if type(error) is TypedError:
        value = error.as_dict()
    elif type(error) is dict:
        allowed = {"code", "message", "path", "details"}
        unknown = set(error) - allowed
        if unknown:
            raise EvidenceError(TypedError(ErrorCode.INVALID_ERROR.value, "error contains unknown fields", "error", {"fields": sorted(unknown)}))
        value = dict(error)
    else:
        raise EvidenceError(TypedError(ErrorCode.INVALID_ERROR.value, "error must be TypedError or mapping", "error"))
    if any(type(key) is not str for key in value):
        raise EvidenceError(TypedError(ErrorCode.INVALID_ERROR.value, "error keys must be builtin strings", "error"))
    code = value.get("code")
    if type(code) is not str or code not in known:
        raise EvidenceError(TypedError(ErrorCode.INVALID_ERROR.value, "error code is not in taxonomy", "error.code"))
    if type(value.get("message")) is not str or not value["message"]:
        raise EvidenceError(TypedError(ErrorCode.INVALID_ERROR.value, "error message is required", "error.message"))
    if "path" in value:
        _validate_error_path(value["path"])
    if "details" in value:
        if type(value["details"]) is not dict:
            raise EvidenceError(TypedError(ErrorCode.INVALID_ERROR.value, "error details must be a closed object", "error.details"))
        _closed_json(value["details"], "error.details")
    error_statuses = {Status.FAIL_CLOSED.value, Status.PROGRAM_EXCEPTION.value,
                      Status.NUMERICAL_FAIL.value, Status.PHYSICAL_FAIL.value,
                      Status.UNSUPPORTED.value, Status.BLOCKED_EXTERNAL.value,
                      Status.TYPED_ABSENT.value, Status.TERMINAL_DEFERRED.value,
                      Status.NON_EVIDENCE.value, Status.UNKNOWN.value,
                      Status.NOT_EXECUTED.value, Status.HUMAN_INTERRUPTION.value,
                      Status.CHANGES_REQUESTED.value}
    if status not in error_statuses:
        raise EvidenceError(TypedError(ErrorCode.INVALID_ERROR.value, "status does not permit an error payload", "error"))
    return value


def build_receipt(
    *,
    status: str | Status,
    command: Sequence[str],
    working_directory: str,
    pid: int,
    utc_start: str,
    utc_end: str,
    exit_code: int,
    stdout: bytes | bytearray | memoryview | str,
    stderr: bytes | bytearray | memoryview | str,
    candidate: Any = None,
    source: Any = None,
    inputs: Mapping[str, Any] | None = None,
    outputs: Mapping[str, Any] | None = None,
    error: TypedError | Mapping[str, Any] | None = None,
    metadata: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    """Build a receipt from caller-supplied observations only.

    ``stdout``/``stderr`` are hashed as UTF-8 bytes when strings are supplied.
    No PID, UTC, exit code, path, or status is inferred.  Candidate/source may
    be Fingerprint objects or their serialized mapping forms.
    """
    if isinstance(status, Status):
        status_value = status.value
    elif type(status) is str and status in {item.value for item in Status}:
        status_value = status
    else:
        raise EvidenceError(TypedError(ErrorCode.INVALID_STATUS.value, "status must be a non-empty string", "status"))
    if type(command) not in (list, tuple) or not all(type(x) is str for x in command):
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, "command must be a sequence of strings", "command"))
    if type(working_directory) is not str or not working_directory:
        raise EvidenceError(TypedError(ErrorCode.MISSING_FIELD.value, "working_directory is required", "working_directory"))
    if type(pid) is not int or pid <= 0:
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, "pid must be a positive integer", "pid"))
    if type(exit_code) is not int:
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, "exit_code must be an integer", "exit_code"))
    if isinstance(stdout, str):
        stdout = stdout.encode("utf-8")
    if isinstance(stderr, str):
        stderr = stderr.encode("utf-8")
    if type(stdout) not in (bytes, bytearray, memoryview) or type(stderr) not in (bytes, bytearray, memoryview):
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, "stdout/stderr must be bytes or text", "raw"))
    start_value = _utc_text(utc_start, "utc_start")
    end_value = _utc_text(utc_end, "utc_end")
    start_dt = datetime.fromisoformat(start_value[:-1] + "+00:00" if start_value.endswith("Z") else start_value)
    end_dt = datetime.fromisoformat(end_value[:-1] + "+00:00" if end_value.endswith("Z") else end_value)
    if end_dt < start_dt:
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, "utc_end precedes utc_start", "utc"))
    if (inputs is not None and type(inputs) is not dict) or (outputs is not None and type(outputs) is not dict):
        raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, "inputs and outputs must be closed objects", "artifacts"))
    result: dict[str, Any] = {
        "schema": RECEIPT_SCHEMA_VERSION,
        "canonicalization": CANONICALIZATION_VERSION,
        "status": status_value,
        "command": list(command),
        "working_directory": working_directory,
        "pid": pid,
        "utc": {"start": start_value, "end": end_value, "basis": "caller_observation_untrusted"},
        "exit_code": exit_code,
        "raw": {"stdout_sha256": _hash(stdout, "stdout"), "stderr_sha256": _hash(stderr, "stderr"), "stdout_bytes": len(stdout), "stderr_bytes": len(stderr)},
        "inputs": dict(inputs or {}),
        "outputs": dict(outputs or {}),
        "candidate_fingerprint": _fp(candidate, "candidate", "up1:candidate") if candidate is not None else None,
        "source_fingerprint": _fp(source, "source", "up1:source") if source is not None else None,
        "self_hash_policy": {"algorithm": "sha256", "excluded_fields": sorted(_SELF_FIELDS), "preimage": "canonical receipt excluding self-hash fields"},
    }
    _closed_json(result["inputs"], "inputs")
    _closed_json(result["outputs"], "outputs")
    error_statuses = {Status.FAIL_CLOSED.value, Status.PROGRAM_EXCEPTION.value,
                      Status.NUMERICAL_FAIL.value, Status.PHYSICAL_FAIL.value,
                      Status.UNSUPPORTED.value, Status.BLOCKED_EXTERNAL.value,
                      Status.TYPED_ABSENT.value, Status.TERMINAL_DEFERRED.value,
                      Status.NON_EVIDENCE.value, Status.UNKNOWN.value, Status.NOT_EXECUTED.value,
                      Status.HUMAN_INTERRUPTION.value, Status.CHANGES_REQUESTED.value}
    if status_value in error_statuses and error is None:
        raise EvidenceError(TypedError(ErrorCode.INVALID_ERROR.value, "failure/deferred status requires a taxonomy error", "error"))
    if error is not None:
        result["error"] = _validate_error(error, status_value)
    if metadata is not None:
        if type(metadata) is not dict:
            raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, "metadata must be a closed object", "metadata"))
        _closed_json(metadata, "metadata")
        result["metadata"] = dict(metadata)
    result["receipt_sha256"] = sha256_hex(_preimage(result))
    return result


build_deterministic_receipt = build_receipt
