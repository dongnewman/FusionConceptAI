"""Strict JSON stdin/stdout CLI for witness-authority validation."""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone

try:  # Supports both ``python -m ...`` and direct fresh-file execution.
    from .validator import DuplicateKeyError, parse_json, validate, validate_batch
except ImportError:  # pragma: no cover - exercised by the direct CLI command
    from validator import DuplicateKeyError, parse_json, validate, validate_batch


def _utc() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def main(argv: list[str] | None = None) -> int:
    del argv
    started = _utc()
    raw = sys.stdin.read()
    try:
        value = parse_json(raw)
        if isinstance(value, dict) and "requests" in value:
            if not isinstance(value["requests"], list):
                raise ValueError("requests must be an array")
            results = validate_batch(value["requests"])
            output = {"schema": "UP1.external_closure_r2.witness_authority.cli.v1",
                      "status": "batch", "results": results}
            rc = 0
        else:
            output = validate(value)
            output["cli_pid"] = os.getpid()
            output["cli_started_at_utc"] = started
            rc = 0
    except (ValueError, TypeError, DuplicateKeyError) as exc:
        output = {"schema": "UP1.external_closure_r2.witness_authority.cli.v1",
                  "status": "fail_closed", "resolution": "fail_closed",
                  "error_code": "ERR_INVALID_JSON", "detail": str(exc),
                  "no_publish": True, "claim_ceiling": "preparation_only",
                  "r01_r10_closed": False, "cli_pid": os.getpid(),
                  "cli_started_at_utc": started, "cli_ended_at_utc": _utc()}
        rc = 2
    sys.stdout.write(json.dumps(output, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
