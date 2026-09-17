"""Command-line interface for the observation-only r4 collector."""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

if __package__:
    from .collector import FAIL_CLOSED, collect_closure, dump_receipt
else:  # ``python cli.py`` from the package directory
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
    from tools.up1_external_closure_r4.environment_closure.collector import FAIL_CLOSED, collect_closure, dump_receipt


def _binary(value: str) -> dict[str, str]:
    if "=" not in value:
        raise argparse.ArgumentTypeError("binary must use NAME=PATH")
    name, path = value.split("=", 1)
    if not name.strip() or not path.strip():
        raise argparse.ArgumentTypeError("binary NAME and PATH must be non-empty")
    return {"name": name.strip(), "path": path}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Collect a read-only UP1 environment/binary-source closure")
    parser.add_argument("--root", default=".", help="repository/environment root to inspect")
    parser.add_argument("--python-path")
    parser.add_argument("--julia-path")
    parser.add_argument("--desc-path")
    parser.add_argument("--binary", action="append", type=_binary, default=[], metavar="NAME=PATH")
    parser.add_argument("--manifest", action="append", default=[], metavar="PATH")
    parser.add_argument("--source-receipt")
    parser.add_argument("--signature")
    parser.add_argument("--download-receipt")
    parser.add_argument("--sbom")
    parser.add_argument("--build-recipe")
    parser.add_argument("--probe-versions", action="store_true", help="run only --version probes; no shell/network/package manager")
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("--output", help="new JSON receipt path; existing files are never overwritten")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    receipt = collect_closure(
        root=args.root,
        python_path=args.python_path,
        julia_path=args.julia_path,
        desc_path=args.desc_path,
        binaries=args.binary,
        manifests=args.manifest or None,
        source_receipt=args.source_receipt,
        signature=args.signature,
        download_receipt=args.download_receipt,
        sbom=args.sbom,
        build_recipe=args.build_recipe,
        probe_versions=args.probe_versions,
        command_timeout=args.timeout,
    )
    try:
        dump_receipt(receipt, args.output)
    except Exception as exc:
        receipt = {
            "record_kind": "up1_external_environment_closure_r4",
            "schema": "UP1.external-environment-closure-r4.v1",
            "status": FAIL_CLOSED,
            "errors": [f"receipt_write_failed:{type(exc).__name__}"],
            "command_policy": {"read_only": True, "network_used": False, "download_performed": False, "installation_performed": False, "environment_modified": False, "environment_variables_captured": False},
        }
    print(json.dumps(receipt, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return 1 if receipt.get("status") == FAIL_CLOSED else 0


if __name__ == "__main__":
    raise SystemExit(main())
