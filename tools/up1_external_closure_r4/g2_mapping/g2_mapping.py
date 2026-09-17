"""Compatibility import name for the independent R4 G2 validator."""

try:
    from .validator import *  # type: ignore # noqa: F401,F403
except ImportError:  # direct script/path compatibility
    from validator import *  # noqa: F401,F403
