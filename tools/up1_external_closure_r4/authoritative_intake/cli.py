"""Command line entry point for local, non-authoritative intake."""

from __future__ import annotations

import argparse
import json
import sys

from .intake import AuthorityIntake


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="offline UP1 R4 intake; no network or external ack")
    parser.add_argument("--spool", required=True)
    parser.add_argument("--input", required=True, help="raw packet file; read-only")
    parser.add_argument("--channel-id")
    parser.add_argument("--owner-id")
    parser.add_argument("--transport")
    parser.add_argument("--real-channel", action="store_true", help="descriptive opt-in; still no network")
    parser.add_argument("--max-bytes", type=int, default=16 * 1024 * 1024)
    args = parser.parse_args(argv)
    identity = None
    policy = None
    if args.channel_id and args.owner_id and args.transport:
        identity = {"channel_id": args.channel_id, "owner_id": args.owner_id,
                    "transport": args.transport, "real_channel": args.real_channel}
        policy = {"channel_id": args.channel_id, "require_signature": False}
    adapter = AuthorityIntake(args.spool, identity, policy, max_bytes=args.max_bytes)
    result = adapter.receive(args.input, channel_id=args.channel_id)
    sys.stdout.write(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")
    return 0 if result.get("ok") else 2


if __name__ == "__main__":
    raise SystemExit(main())
