#!/usr/bin/env python3
"""Versioned runner wrapper for fixed observed-Dirichlet boundary semantics.

The numerical runner v2 remains untouched and hash-frozen. This wrapper installs
the narrow FreeGS 0.8.2 no-X-point boundary-scalar compatibility only on the
Equilibrium created with v2's exact observed_dirichlet_boundary callback, then
delegates the original argv unchanged to v2.
"""

from __future__ import annotations

import hashlib
import runpy
import sys
from pathlib import Path
from typing import Any, Callable, Sequence

if __package__:
    from .freegs_observed_dirichlet_boundary_v1 import (
        temporary_observed_dirichlet_semantics,
        verify_pinned_freegs_sources,
        verify_pinned_freegs_solve_api,
    )
else:
    from freegs_observed_dirichlet_boundary_v1 import (
        temporary_observed_dirichlet_semantics,
        verify_pinned_freegs_sources,
        verify_pinned_freegs_solve_api,
    )


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
BASELINE_RUNNER = (
    REPOSITORY_ROOT / "scripts" / "runtime_v4_freegs_axisymmetric_profile_runner_v2.py"
)
VERSIONED_REVISION = (
    "runtime-v4-freegs-axisymmetric-profile-execution-v3-"
    "observed-box-boundary-convergence-proxy"
)
BASELINE_REVISION = "runtime-v4-freegs-axisymmetric-profile-execution-v2"
PINNED_BASELINE_SHA256 = "3fbc8262ea9e6ab58e06892349bc3640e36d88f2985d950cc386b511e6e3b4ec"
DELEGATE_RUN_NAME = "_up4_reference_validation_v3_baseline"


def verify_baseline_hash(path: str | Path = BASELINE_RUNNER) -> str:
    """Fail closed unless the delegated numerical runner is the pinned v2 file."""
    digest = hashlib.sha256(Path(path).read_bytes()).hexdigest()
    if digest != PINNED_BASELINE_SHA256:
        raise RuntimeError(
            "pinned v2 FreeGS runner hash mismatch: "
            f"expected {PINNED_BASELINE_SHA256}, got {digest}"
        )
    return digest


def install_versioned_input_validation(namespace: dict[str, Any]) -> None:
    """Keep the v2 input revision check while emitting a distinct v3 result.

    The original validator resolves ``REVISION`` from the delegated namespace.
    Temporarily expose the pinned v2 revision only for that validator call, and
    restore the v3 output identity in ``finally`` even when validation fails.
    """
    baseline_revision = namespace.get("REVISION")
    original_validator = namespace.get("validate_wrapper")
    if baseline_revision != BASELINE_REVISION or not callable(original_validator):
        raise RuntimeError("delegated runner does not expose the pinned v2 input contract")

    def validate_frozen_v2_input(value: Any) -> Any:
        namespace["REVISION"] = BASELINE_REVISION
        try:
            return original_validator(value)
        finally:
            namespace["REVISION"] = VERSIONED_REVISION

    namespace["validate_wrapper"] = validate_frozen_v2_input
    namespace["REVISION"] = VERSIONED_REVISION


def verify_freegs_backend(equilibrium_class: type) -> Any:
    """Resolve and verify the exact FreeGS modules before installing patches."""
    import freegs
    from freegs import equilibrium, picard

    if getattr(freegs, "Equilibrium", None) is not equilibrium_class:
        raise RuntimeError("requested Equilibrium class is not the pinned FreeGS class")
    verify_pinned_freegs_sources(equilibrium_class)
    verify_pinned_freegs_solve_api(
        freegs,
        picard,
        Path(equilibrium.__file__).resolve().parent,
    )
    return freegs


def run_baseline(
    argv: Sequence[str],
    *,
    equilibrium_class: type | None = None,
    runner_loader: Callable[..., dict[str, Any]] | None = None,
) -> int:
    """Run the unchanged v2 implementation with the scoped boundary adapter."""
    freegs_module = None
    if equilibrium_class is None:
        import freegs

        freegs_module = freegs
        equilibrium_class = freegs.Equilibrium
    elif getattr(equilibrium_class, "__module__", "").startswith("freegs."):
        import freegs

        freegs_module = freegs
    if freegs_module is not None:
        verify_freegs_backend(equilibrium_class)
    if runner_loader is None:
        runner_loader = runpy.run_path
    if not BASELINE_RUNNER.is_file():
        raise FileNotFoundError(f"pinned baseline runner is missing: {BASELINE_RUNNER}")
    verify_baseline_hash(BASELINE_RUNNER)

    with temporary_observed_dirichlet_semantics(
        equilibrium_class,
        expected_runner_file=BASELINE_RUNNER,
        solver_owner=freegs_module,
    ):
        namespace = runner_loader(str(BASELINE_RUNNER), run_name=DELEGATE_RUN_NAME)
        original_revision = namespace.get("REVISION")
        original_validator = namespace.get("validate_wrapper")
        install_versioned_input_validation(namespace)
        try:
            return int(namespace["main"](list(argv)))
        finally:
            namespace["REVISION"] = original_revision
            namespace["validate_wrapper"] = original_validator


def main(argv: Sequence[str] | None = None) -> int:
    return run_baseline(sys.argv[1:] if argv is None else argv)


if __name__ == "__main__":
    raise SystemExit(main())
