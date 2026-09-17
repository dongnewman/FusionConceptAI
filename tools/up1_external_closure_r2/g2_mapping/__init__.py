"""UP1 external-closure R2 G2 mapping validator."""

from .production_g2_mapping import (
    ProfileError,
    evaluate,
    load_text,
    validate_profile,
)

__all__ = ["ProfileError", "evaluate", "load_text", "validate_profile"]
