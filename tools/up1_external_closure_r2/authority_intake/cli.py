"""JSON-only command line entry point for the offline intake adapter."""

from __future__ import annotations

import argparse
import json
import sys

try:
    from .adapter import AuthorityIntakeAdapter
except ImportError:  # permit `python -B cli.py` for offline operator use
    from adapter import AuthorityIntakeAdapter


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="offline UP1 authority-channel intake; no network is used")
    parser.add_argument("--spool", required=True)
    parser.add_argument("--input", dest="input_path")
    parser.add_argument("--max-bytes", type=int, default=1_048_576)
    args = parser.parse_args(argv)
    adapter = AuthorityIntakeAdapter(args.spool, max_bytes=args.max_bytes)
    if args.input_path:
        result = adapter.intake(args.input_path)
    else:
        result = {"ok": True, "outcome": "scan", "results": adapter.scan()}
    sys.stdout.write(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")
    return 0 if result.get("ok") else 2


if __name__ == "__main__":
    raise SystemExit(main())
