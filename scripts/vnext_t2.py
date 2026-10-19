"""Stable T2 entry point; implementations keep their frozen compatibility paths."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
IMPLEMENTATION_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
ENTRIES = {
    "build": "build_protocol_r23.py",
    "verify": "static_qa_independent_negative_r23.py",
    "run": "independent_negative_controller_r23.py",
}


def main(arguments: list[str] | None = None) -> int:
    arguments = sys.argv[1:] if arguments is None else arguments
    if not arguments or arguments[0] not in ENTRIES:
        print("Usage: python -B scripts/vnext_t2.py {build|verify|run} [original arguments]",
              file=sys.stderr)
        return 2
    implementation = IMPLEMENTATION_ROOT / ENTRIES[arguments[0]]
    completed = subprocess.run(
        [sys.executable, "-B", str(implementation), *arguments[1:]],
        cwd=ROOT,
        check=False,
    )
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
