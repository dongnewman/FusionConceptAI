"""Read-only environment and binary-source closure collector."""

from .collector import (
    ABSENT,
    FAIL_CLOSED,
    LOCAL_OBSERVED,
    TYPED_ABSENT,
    CollectorError,
    collect_closure,
    collect_file_observation,
    file_sha256,
)

__all__ = [
    "ABSENT",
    "FAIL_CLOSED",
    "LOCAL_OBSERVED",
    "TYPED_ABSENT",
    "CollectorError",
    "collect_closure",
    "collect_file_observation",
    "file_sha256",
]
