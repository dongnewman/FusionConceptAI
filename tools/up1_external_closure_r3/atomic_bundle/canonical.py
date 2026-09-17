"""Strict, offline canonical JSON support for the UP1 prototype.

RFC 8785 is used when the optional :mod:`rfc8785` package is installed.  The
fallback is deliberately fail-closed: it accepts only JSON values and
ECMAScript-safe integers, rejecting every float/exponent because the local
encoder cannot prove RFC 8785 shortest-round-trip equivalence.  It never
silently claims full RFC 8785 coverage.
"""
from __future__ import annotations

import json
import math
from typing import Any

try:  # optional dependency; never installed or fetched by this package
    import rfc8785 as _rfc8785  # type: ignore
except ImportError:  # pragma: no cover - exercised on the supported offline host
    _rfc8785 = None

MAX_SAFE_INTEGER = 9007199254740991


class CanonicalError(ValueError):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


def _pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in items:
        if key in result:
            raise CanonicalError("RAW_DUPLICATE_KEY", f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _constant(token: str) -> Any:
    raise CanonicalError("RAW_NONFINITE_NUMBER", f"non-finite JSON constant: {token}")


def parse_json_strict(raw: bytes | bytearray | str) -> Any:
    if isinstance(raw, (bytes, bytearray)):
        try:
            text = bytes(raw).decode("utf-8", "strict")
        except UnicodeDecodeError as exc:
            raise CanonicalError("RAW_INVALID_UTF8", "input is not strict UTF-8") from exc
    elif isinstance(raw, str):
        try:
            raw.encode("utf-8", "strict")
        except UnicodeEncodeError as exc:
            raise CanonicalError("RAW_INVALID_UTF8", "input contains an invalid Unicode scalar") from exc
        text = raw
    else:
        raise CanonicalError("RAW_INVALID_JSON", "JSON input must be bytes or str")
    try:
        value = json.loads(text, object_pairs_hook=_pairs, parse_constant=_constant)
    except CanonicalError:
        raise
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        raise CanonicalError("RAW_INVALID_JSON", "invalid JSON syntax") from exc
    validate_value(value)
    return value


def validate_value(value: Any, path: str = "$") -> None:
    if value is None or type(value) is bool or type(value) is str:
        if type(value) is str:
            try:
                value.encode("utf-8", "strict")
            except UnicodeEncodeError as exc:
                raise CanonicalError("RAW_INVALID_UTF8", f"invalid string at {path}") from exc
            if any(0xD800 <= ord(ch) <= 0xDFFF for ch in value):
                raise CanonicalError("RAW_INVALID_UTF8", f"lone surrogate at {path}")
        return
    if type(value) is int:
        if abs(value) > MAX_SAFE_INTEGER:
            raise CanonicalError("CANONICAL_NUMBER_UNSUPPORTED", f"integer outside ECMAScript range at {path}")
        return
    if type(value) is float:
        if not math.isfinite(value):
            raise CanonicalError("RAW_NONFINITE_NUMBER", f"non-finite number at {path}")
        # Without RFC 8785 we cannot prove that Python's binary float spelling
        # has the same ECMAScript/JCS shortest-round-trip spelling.  Reject all
        # floats, including exponent notation such as 1e20, instead of
        # normalising it to a potentially colliding integer (1e20 != 1).
        if _rfc8785 is None:
            raise CanonicalError("CANONICAL_NUMBER_UNSUPPORTED", f"float/exponent requires RFC8785 at {path}")
        if value == 0.0 and math.copysign(1.0, value) < 0:
            raise CanonicalError("CANONICAL_NUMBER_UNSUPPORTED", f"negative zero at {path}")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if type(key) is not str:
                raise CanonicalError("CANONICAL_VALUE_UNSUPPORTED", f"non-string key at {path}")
            validate_value(item, f"{path}.{key}")
        return
    if isinstance(value, list):
        for i, item in enumerate(value):
            validate_value(item, f"{path}[{i}]")
        return
    raise CanonicalError("CANONICAL_VALUE_UNSUPPORTED", f"unsupported value at {path}")


def _fallback_number(value: int | float) -> str:
    if type(value) is int:
        return str(value)
    if not math.isfinite(value) or value == 0.0 and math.copysign(1.0, value) < 0:
        raise CanonicalError("CANONICAL_NUMBER_UNSUPPORTED", "non-finite or negative zero")
    raise CanonicalError("CANONICAL_NUMBER_UNSUPPORTED", "float/exponent requires RFC8785")


def _fallback(value: Any) -> str:
    validate_value(value)
    if value is None:
        return "null"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if type(value) in (int, float):
        return _fallback_number(value)
    if type(value) is str:
        return json.dumps(value, ensure_ascii=True, separators=(",", ":"))
    if isinstance(value, dict):
        return "{" + ",".join(json.dumps(k, ensure_ascii=True, separators=(",", ":")) + ":" + _fallback(value[k]) for k in sorted(value)) + "}"
    if isinstance(value, list):
        return "[" + ",".join(_fallback(v) for v in value) + "]"
    raise CanonicalError("CANONICAL_VALUE_UNSUPPORTED", "unsupported value")


def canonical_bytes(value: Any) -> bytes:
    validate_value(value)
    if _rfc8785 is not None:
        try:
            return bytes(_rfc8785.dumps(value))
        except Exception as exc:
            raise CanonicalError("CANONICAL_NUMBER_UNSUPPORTED", str(exc)) from exc
    return _fallback(value).encode("ascii")


def canonical_profile() -> str:
    return "RFC8785" if _rfc8785 is not None else "RFC8785-required-float-reject-fallback"


# Compatibility names used by adjacent offline closure validators.
canonical_json_bytes = canonical_bytes
parse_raw = parse_json_strict
