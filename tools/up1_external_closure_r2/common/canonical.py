"""Strict deterministic JSON with an explicit, versioned byte profile."""

from __future__ import annotations

import json
import math
import re
from typing import Any, Mapping

CANONICALIZATION_VERSION = "UP1-R2-CJSON-1"


class DuplicateKeyError(ValueError):
    """Raised when an input JSON object repeats a member name."""

    code = "duplicate_json_key"


class NonCanonicalJSONError(ValueError):
    """Raised for non-finite, non-UTF-8, or otherwise non-canonical values."""

    code = "non_canonical_json"


class InvalidUTF8Error(NonCanonicalJSONError):
    code = "invalid_utf8"


class SyntaxJSONError(NonCanonicalJSONError):
    code = "invalid_json_syntax"


class NonFiniteNumberError(NonCanonicalJSONError):
    code = "non_finite_number"


class NonCanonicalNumberError(NonCanonicalJSONError):
    code = "non_canonical_number"


class CyclicValueError(NonCanonicalJSONError):
    code = "cyclic_value"


class UnsupportedValueError(NonCanonicalJSONError):
    code = "unsupported_value"


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKeyError(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result


def _reject_constant(value: str) -> None:
    raise NonFiniteNumberError(f"non-finite JSON constant: {value}")


def _parse_int(value: str) -> int:
    try:
        return int(value)
    except ValueError as exc:
        raise NonCanonicalNumberError("integer exceeds implementation conversion limit") from exc


def _validate(value: Any, *, path: str = "$", seen: set[int] | None = None) -> None:
    """Validate values before handing them to :mod:`json`.

    Python's encoder otherwise accepts non-string mapping keys and silently
    coerces them.  Both behaviours are dangerous for content identities.
    Cycles are rejected explicitly so a receipt cannot accidentally hash an
    implementation-dependent traversal.
    """
    if seen is None:
        seen = set()
    if isinstance(value, (Mapping, list, tuple)):
        marker = id(value)
        if marker in seen:
            raise CyclicValueError(f"cyclic value at {path}")
        seen.add(marker)
    try:
        if value is None or type(value) is bool or type(value) is str or type(value) is int:
            if isinstance(value, str):
                try:
                    value.encode("utf-8", "strict")
                except UnicodeEncodeError as exc:
                    raise InvalidUTF8Error(f"invalid UTF-8 string at {path}") from exc
                if any(0xD800 <= ord(ch) <= 0xDFFF for ch in value):
                    raise InvalidUTF8Error(f"lone surrogate at {path}")
            return
        if type(value) is float:
            if not math.isfinite(value):
                raise NonFiniteNumberError(f"non-finite number at {path}")
            if value == 0.0 and math.copysign(1.0, value) < 0:
                raise NonCanonicalNumberError(f"negative zero is non-canonical at {path}")
            return
        if isinstance(value, (int, float)):
            raise NonCanonicalNumberError(f"numeric subclasses are not permitted at {path}")
        if isinstance(value, Mapping):
            for key, item in value.items():
                if not isinstance(key, str):
                    raise NonCanonicalJSONError(f"object key is not a string at {path}")
                _validate(key, path=f"{path}.{key}", seen=seen)
                _validate(item, path=f"{path}.{key}", seen=seen)
            return
        if isinstance(value, (list, tuple)):
            for index, item in enumerate(value):
                _validate(item, path=f"{path}[{index}]", seen=seen)
            return
        # Decimal, bytes, custom objects, and numeric subclasses are not part
        # of the profile; callers must convert them to an explicit payload.
        raise UnsupportedValueError(f"unsupported JSON value {type(value).__name__} at {path}")
    finally:
        if isinstance(value, (Mapping, list, tuple)):
            seen.remove(id(value))


def canonical_json(value: Any) -> str:
    """Encode a value using compact sorted-key JSON and finite numbers only."""
    _validate(value)
    return _encode(value)


_EXPONENT = re.compile(r"^(?P<mantissa>-?(?:\d+\.?\d*|\.\d+))[eE](?P<sign>[+-]?)(?P<exp>\d+)$")


def _number(value: int | float) -> str:
    if type(value) is int:
        try:
            return str(value)
        except ValueError as exc:
            raise NonCanonicalNumberError("integer exceeds implementation conversion limit") from exc
    if type(value) is not float:
        raise NonCanonicalNumberError("numeric subclasses are not permitted")
    if not math.isfinite(value):
        raise NonFiniteNumberError("non-finite number")
    if value == 0.0:
        return "0"
    text = repr(value)
    # JSON numbers have no distinct integral-float representation in this
    # profile: 1.0 and 1 are the same canonical number.  Python's repr is
    # already the shortest round-trippable decimal; normalize exponent syntax.
    if text.endswith(".0") and "e" not in text.lower():
        text = text[:-2]
    match = _EXPONENT.match(text)
    if match:
        mantissa = match.group("mantissa")
        exponent = int(("-" if match.group("sign") == "-" else "") + match.group("exp"))
        # Keep ordinary values in fixed form.  This also avoids alternate
        # spellings such as 1e+00 for values that have a finite decimal form.
        if -6 <= exponent < 21:
            from decimal import Decimal
            fixed = format(Decimal(text), "f")
            if "." in fixed:
                fixed = fixed.rstrip("0").rstrip(".")
            return fixed
        return f"{mantissa}e{'+' if exponent >= 0 else '-'}{abs(exponent)}"
    return text


def _encode(value: Any) -> str:
    if value is None:
        return "null"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if type(value) is int or type(value) is float:
        return _number(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=True, separators=(",", ":"))
    if isinstance(value, Mapping):
        return "{" + ",".join(json.dumps(key, ensure_ascii=True) + ":" + _encode(value[key]) for key in sorted(value)) + "}"
    if isinstance(value, (list, tuple)):
        return "[" + ",".join(_encode(item) for item in value) + "]"
    raise UnsupportedValueError(f"unsupported JSON value {type(value).__name__}")


def canonical_json_bytes(value: Any) -> bytes:
    return canonical_json(value).encode("ascii")


# Short aliases used by adjacent offline validators.
canonical_bytes = canonical_json_bytes


def parse_json(data: str | bytes | bytearray) -> Any:
    """Parse JSON while rejecting duplicate keys and non-standard constants."""
    if isinstance(data, (bytes, bytearray)):
        try:
            data = bytes(data).decode("utf-8", "strict")
        except UnicodeDecodeError as exc:
            raise InvalidUTF8Error("JSON input is not valid UTF-8") from exc
    if not isinstance(data, str):
        raise TypeError("JSON input must be str or bytes")
    try:
        result = json.loads(
            data,
            object_pairs_hook=_pairs,
            parse_constant=_reject_constant,
            parse_int=_parse_int,
            parse_float=float,
        )
    except DuplicateKeyError:
        raise
    except NonCanonicalJSONError:
        raise
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        raise SyntaxJSONError(f"invalid JSON: {exc}") from exc
    _validate(result)
    return result


def parse_canonical_json(data: str | bytes | bytearray) -> Any:
    """Parse and require that input bytes equal this profile's canonical bytes."""
    parsed = parse_json(data)
    expected = canonical_json_bytes(parsed)
    actual = data.encode("utf-8") if isinstance(data, str) else bytes(data)
    if actual != expected:
        raise NonCanonicalJSONError("JSON bytes are valid but not canonical")
    return parsed
