"""JSON CLI: stdin/stdout only; no network and no OS-clock decisions."""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

try:  # supports both ``python cli.py`` and ``python -m ...revocation_time_replay.cli``
    from .core import CLAIM_CEILING, SCHEMA, PersistentReplayLedger, ReceiptInputError, parse_json_strict, validate
except ImportError:  # pragma: no cover - direct script path
    from core import CLAIM_CEILING, SCHEMA, PersistentReplayLedger, ReceiptInputError, parse_json_strict, validate


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="UP1 R2 TEST_ONLY receipt verifier")
    parser.add_argument("--input", type=pathlib.Path, help="JSON input; otherwise stdin")
    parser.add_argument("--ledger", type=pathlib.Path, help="durable authenticated replay ledger")
    parser.add_argument("--key", type=pathlib.Path, help="explicit independent trusted HMAC key file")
    parser.add_argument("--namespace", default="UP1-R2", help="ledger namespace binding")
    args = parser.parse_args(argv)
    try:
        raw = args.input.read_text(encoding="utf-8") if args.input else sys.stdin.read()
        payload = parse_json_strict(raw)
        ledger = PersistentReplayLedger(args.ledger, key_path=args.key, namespace=args.namespace) if args.ledger else None
        result = validate(payload, ledger=ledger)
        print(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
        return 0 if result.get("result") == "valid_for_declared_scope" else 2
    except ReceiptInputError as exc:
        # Input/schema/ledger errors are protocol outcomes, never program_exception.
        print(json.dumps({"schema": SCHEMA, "result": "fail_closed", "status": "fail_closed",
                          "resolution": "fail_closed", "error_code": exc.code,
                          "detail": str(exc), "claim_ceiling": CLAIM_CEILING,
                          "network_access": False, "trusted_clock_basis": "signed_receipt_only"},
                         ensure_ascii=False, sort_keys=True, separators=(",", ":")))
        return 2
    except Exception as exc:  # Unexpected execution failures remain distinguishable.
        print(json.dumps({"schema": SCHEMA, "result": "fail_closed", "status": "fail_closed",
                          "resolution": "fail_closed", "error_code": "program_exception",
                          "detail": str(exc), "claim_ceiling": CLAIM_CEILING,
                          "network_access": False, "trusted_clock_basis": "signed_receipt_only"},
                         ensure_ascii=False, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
