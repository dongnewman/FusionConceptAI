"""JSON CLI for offline UP1 R2 provenance validation."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

if __package__:
    from .validator import load_json, validate_document
else:  # direct ``python -B cli.py`` execution
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent.parent))
    from tools.up1_external_closure_r2.environment_provenance.validator import load_json, validate_document


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate UP1 R2 environment/provenance closure JSON")
    parser.add_argument("document", help="closure JSON path")
    parser.add_argument("--root", help="root for relative runtime/binary/lock paths")
    parser.add_argument("--expected-context", help="independent expected-context JSON path")
    parser.add_argument("--expected-context-sha256", help="caller-frozen SHA-256 of expected-context JSON")
    parser.add_argument("--trust-anchor", help="independent trust-anchor JSON path")
    parser.add_argument("--trust-anchor-sha256", help="caller-frozen SHA-256 of trust-anchor JSON")
    args = parser.parse_args(argv)
    path = Path(args.document)
    started = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    digest = None
    try:
        raw = path.read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        document = load_json(path)
        expected_context = load_json(args.expected_context) if args.expected_context else None
        trust_anchor = load_json(args.trust_anchor) if args.trust_anchor else None
        result = validate_document(
            document,
            root=args.root,
            expected_context=expected_context,
            trust_anchor=trust_anchor,
            expected_context_sha256=args.expected_context_sha256,
            trust_anchor_sha256=args.trust_anchor_sha256,
        )
        payload = result.as_dict()
        payload.update({"record_kind": "up1_environment_provenance_cli_receipt_v1", "pid": os.getpid(), "utc": started, "exit_code": 0 if result.status in {"present", "typed_absent", "non_evidence"} else 1, "input_sha256": digest})
    except Exception as exc:  # malformed JSON is itself a fail-closed receipt
        payload = {"record_kind": "up1_environment_provenance_cli_receipt_v1", "status": "fail_closed", "decision": "reject", "checks": {}, "errors": [str(exc)], "pid": os.getpid(), "utc": started, "exit_code": 1, "input_sha256": digest}
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return int(payload["exit_code"])


if __name__ == "__main__":
    raise SystemExit(main())
