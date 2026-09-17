"""JSON stdin/file CLI for the offline R4 trust-chain prototype."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .verifier import result_exit_code, verify_request


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="UP1 R4 offline non-authoritative trust-chain verifier")
    parser.add_argument("--request", type=Path, help="request JSON path; otherwise read stdin")
    args = parser.parse_args(argv)
    try:
        raw = args.request.read_text(encoding="utf-8") if args.request else sys.stdin.read()
        request = json.loads(raw)
    except Exception as exc:
        result = {"schema": "UP1.external-closure-r4.trust-chain.v1", "status": "invalid", "error_code": "REQUEST_INVALID", "message": str(exc), "resolution": "no_publish", "no_publish": True, "authoritative": False, "evidence_class": "none", "test_only": False}
        sys.stdout.write(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")
        return 3
    result = verify_request(request)
    sys.stdout.write(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")
    return result_exit_code(result)


if __name__ == "__main__":
    raise SystemExit(main())
