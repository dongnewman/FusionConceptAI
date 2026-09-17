"""CLI entry point for the independent R4 G2 mapping validator."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from validator import main  # noqa: E402


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
