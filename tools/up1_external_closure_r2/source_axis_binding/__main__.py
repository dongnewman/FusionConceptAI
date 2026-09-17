"""JSON CLI for ``python -B -m source_axis_binding``."""

from __future__ import annotations

from .source_axis_binding import main as _main


if __name__ == "__main__":
    raise SystemExit(_main())
