"""Versioned status and error vocabulary shared by offline evidence tools."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Mapping


class Status(str, Enum):
    PASS = "pass"
    FAIL_CLOSED = "fail_closed"
    TYPED_ABSENT = "typed_absent"
    TERMINAL_DEFERRED = "terminal_deferred"
    NON_EVIDENCE = "non_evidence"
    UNKNOWN = "unknown"
    NOT_EXECUTED = "not_executed"
    HUMAN_INTERRUPTION = "human_interruption"
    NUMERICAL_FAIL = "numerical_fail"
    PHYSICAL_FAIL = "physical_fail"
    PROGRAM_EXCEPTION = "program_exception"
    UNSUPPORTED = "unsupported"
    BLOCKED_EXTERNAL = "blocked_external"
    PENDING = "pending"
    READY = "ready"
    RUNNING = "running"
    REVIEW_PENDING = "review_pending"
    ACCEPTED = "accepted"
    CHANGES_REQUESTED = "changes_requested"


class ErrorCode(str, Enum):
    DUPLICATE_JSON_KEY = "duplicate_json_key"
    NON_FINITE_NUMBER = "non_finite_number"
    NON_CANONICAL_NUMBER = "non_canonical_number"
    NON_CANONICAL_JSON = "non_canonical_json"
    INVALID_JSON_SYNTAX = "invalid_json_syntax"
    INVALID_UTF8 = "invalid_utf8"
    UNSUPPORTED_VALUE = "unsupported_value"
    CYCLIC_VALUE = "cyclic_value"
    PATH_ESCAPE = "path_escape"
    PATH_NOT_FILE = "path_not_file"
    SYMLINK_REJECTED = "symlink_rejected"
    FILE_TOO_LARGE = "file_too_large"
    MANIFEST_MALFORMED = "manifest_malformed"
    MANIFEST_MISSING = "manifest_missing"
    MANIFEST_UNEXPECTED = "manifest_unexpected"
    MANIFEST_DUPLICATE_PATH = "manifest_duplicate_path"
    MANIFEST_HASH_MISMATCH = "manifest_hash_mismatch"
    INVALID_STATUS = "invalid_status"
    INVALID_ERROR = "invalid_error"
    IDENTITY_MISMATCH = "identity_mismatch"
    SELF_REFERENCE = "self_reference"
    MISSING_FIELD = "missing_field"
    INVALID_FIELD = "invalid_field"


@dataclass(frozen=True)
class TypedError:
    code: str
    message: str
    path: str | None = None
    details: Mapping[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not isinstance(self.code, str) or not self.code:
            raise ValueError("error code must be non-empty")
        if not isinstance(self.message, str) or not self.message:
            raise ValueError("error message must be non-empty")

    def as_dict(self) -> dict[str, Any]:
        result: dict[str, Any] = {"code": self.code, "message": self.message}
        if self.path is not None:
            result["path"] = self.path
        if self.details:
            result["details"] = dict(self.details)
        return result


class EvidenceError(ValueError):
    """Fail-closed, typed exception used at package boundaries."""

    def __init__(self, error: TypedError | str, message: str | None = None):
        if isinstance(error, TypedError):
            self.error = error
        else:
            self.error = TypedError(error, message or error)
        super().__init__(self.error.message)
