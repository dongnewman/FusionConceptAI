"""JSON stdin/file CLI for the UP1 R2 PKI verifier."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .verifier import SCHEMA, VerificationError, _reject_duplicate_pairs, result_exit_code, verify_request


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Fail-closed UP1 R2 X.509 receipt verifier")
    parser.add_argument("--request", type=Path, help="JSON request file; otherwise read JSON from stdin")
    parser.add_argument("--root", type=Path)
    parser.add_argument("--intermediate", type=Path, action="append")
    parser.add_argument("--chain", type=Path)
    parser.add_argument("--leaf", type=Path)
    parser.add_argument("--receipt", type=Path)
    parser.add_argument("--profile", type=Path)
    parser.add_argument("--signature", help="base64 receipt signature")
    parser.add_argument("--test-only", action="store_true")
    parser.add_argument("--evaluation-time")
    args = parser.parse_args(argv)
    try:
        if args.request:
            request = json.loads(args.request.read_text(encoding="utf-8"), object_pairs_hook=_reject_duplicate_pairs)
        else:
            request = json.load(sys.stdin, object_pairs_hook=_reject_duplicate_pairs)
    except VerificationError as exc:
        result = {"schema": SCHEMA, "status": "fail_closed", "error_code": exc.code, "message": exc.message, "stage": exc.stage, "resolution": "no_publish", "no_publish": True, "evidence_class": "none", "test_only": False}
        sys.stdout.write(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")
        return result_exit_code(result)
    except (json.JSONDecodeError, OSError) as exc:
        result = {"schema": SCHEMA, "status": "fail_closed", "error_code": "canonical_bytes_mismatch", "message": f"invalid request JSON: {exc}", "stage": "canonical_schema_profile", "resolution": "no_publish", "no_publish": True, "evidence_class": "none", "test_only": False}
        sys.stdout.write(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")
        return result_exit_code(result)
    if args.root: request["root"] = str(args.root)
    if args.intermediate: request["intermediates"] = [str(p) for p in args.intermediate]
    if args.chain: request["chain"] = str(args.chain)
    if args.leaf: request["leaf"] = str(args.leaf)
    if args.receipt: request["receipt"] = str(args.receipt)
    if args.profile: request["profile"] = str(args.profile)
    if args.signature: request["signature"] = args.signature
    if args.test_only: request["test_only"] = True
    if args.evaluation_time: request["evaluation_time"] = args.evaluation_time
    result = verify_request(request)
    sys.stdout.write(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")
    return result_exit_code(result)


if __name__ == "__main__":
    raise SystemExit(main())
