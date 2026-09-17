"""JSON-only CLI for the offline UP1 R2 integration slice."""
from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path
try:
    from .runner import run_pipeline
except ImportError:  # direct ``python path/to/cli.py`` invocation
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
    from tools.up1_external_closure_r2.integration.runner import run_pipeline

def _strict_load(path: Path):
    def pairs(items):
        out = {}
        for key, value in items:
            if key in out:
                raise ValueError(f"duplicate JSON key: {key}")
            out[key] = value
        return out
    def constant(value):
        raise ValueError(f"non-standard JSON constant: {value}")
    return json.loads(path.read_bytes().decode("utf-8"), object_pairs_hook=pairs, parse_constant=constant)

def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--input", "--package", "-i", type=Path, required=True)
    p.add_argument("--expected-context", type=Path)
    p.add_argument("--anchors", type=Path)
    p.add_argument("--ledger", "--ledger-path", type=Path)
    p.add_argument("--key", "--replay-key", type=Path)
    p.add_argument("--prior-state", type=Path)
    p.add_argument("--output", "-o", type=Path)
    args = p.parse_args(argv)
    try:
        package = _strict_load(args.input)
        context = _strict_load(args.expected_context) if args.expected_context else None
        anchors = _strict_load(args.anchors) if args.anchors else None
        prior = _strict_load(args.prior_state) if args.prior_state else None
        result = run_pipeline(package, expected_context=context, anchors=anchors, ledger_path=args.ledger, key_path=args.key, prior_state=prior)
        text = json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        if args.output: args.output.write_text(text, encoding="utf-8", newline="")
        else: print(text)
        return 0 if result.get("status") in {"terminal_deferred", "eligible_for_authority_recheck"} else 2
    except (json.JSONDecodeError, UnicodeDecodeError, OSError, TypeError, ValueError) as exc:
        result = {"schema": "UP1-R2.integration-slice.v2", "status": "fail_closed", "resolution": "fail_closed", "no_publish": True, "error_code": "input_invalid", "error": f"{type(exc).__name__}: {exc}"}
        print(json.dumps(result, sort_keys=True, separators=(",", ":")))
        return 2
    except Exception as exc:
        result = {"schema": "UP1-R2.integration-slice.v2", "status": "fail_closed", "resolution": "fail_closed", "no_publish": True, "error_code": "program_exception", "error": f"{type(exc).__name__}: {exc}"}
        print(json.dumps(result, sort_keys=True, separators=(",", ":")))
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
