#!/usr/bin/env python3
"""v12 runner: exact observed-edge reprojection with correctly bound v4 ID.

The numerical implementation and input contract remain the pinned v2 runner.
This wrapper fixes the v3 ``runpy.run_path`` namespace/global binding mistake,
records adapter events in a separate evidence sidecar, and keeps every hook
scoped to the marked observed-Dirichlet equilibrium.
"""

from __future__ import annotations

from contextlib import contextmanager
import hashlib
import json
import runpy
import sys
from pathlib import Path
from typing import Any, Callable, Iterator, Sequence

if __package__:
    from .freegs_observed_dirichlet_boundary_v2 import (
        temporary_observed_dirichlet_projection,
        verify_pinned_freegs_solve_api,
        verify_pinned_freegs_sources,
    )
else:
    from freegs_observed_dirichlet_boundary_v2 import (
        temporary_observed_dirichlet_projection,
        verify_pinned_freegs_solve_api,
        verify_pinned_freegs_sources,
    )


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
BASELINE_RUNNER = (
    REPOSITORY_ROOT / "scripts" / "runtime_v4_freegs_axisymmetric_profile_runner_v2.py"
)
VERSIONED_REVISION = (
    "runtime-v4-freegs-axisymmetric-profile-execution-v4-"
    "observed-box-boundary-edge-reprojection"
)
BASELINE_REVISION = "runtime-v4-freegs-axisymmetric-profile-execution-v2"
PINNED_BASELINE_SHA256 = "3fbc8262ea9e6ab58e06892349bc3640e36d88f2985d950cc386b511e6e3b4ec"
DELEGATE_RUN_NAME = "_up4_reference_validation_v4_baseline"
ADAPTER_RECEIPT_NAME = "freegs_adapter_receipt_v12.json"


def _normalised_path(path: str | Path) -> str:
    return str(Path(path).resolve()).casefold()


def verify_baseline_hash(path: str | Path = BASELINE_RUNNER) -> str:
    digest = hashlib.sha256(Path(path).read_bytes()).hexdigest()
    if digest != PINNED_BASELINE_SHA256:
        raise RuntimeError(
            "pinned v2 FreeGS runner hash mismatch: "
            f"expected {PINNED_BASELINE_SHA256}, got {digest}"
        )
    return digest


def _main_globals(namespace: dict[str, Any], baseline_path: Path) -> dict[str, Any]:
    main_function = namespace.get("main")
    if not callable(main_function):
        raise RuntimeError("delegated v2 runner did not define callable main")
    function_globals = getattr(main_function, "__globals__", None)
    if not isinstance(function_globals, dict):
        raise RuntimeError("delegated main function has no mutable globals mapping")
    if _normalised_path(function_globals.get("__file__", "")) != _normalised_path(
        baseline_path
    ):
        raise RuntimeError("delegated main globals are not owned by the pinned v2 runner")
    if function_globals.get("REVISION") != BASELINE_REVISION or not callable(
        function_globals.get("validate_wrapper")
    ):
        raise RuntimeError("delegated main globals do not expose the frozen v2 input contract")
    return function_globals


@contextmanager
def versioned_v2_main_globals(
    namespace: dict[str, Any], baseline_path: Path = BASELINE_RUNNER
) -> Iterator[dict[str, Any]]:
    """Rebind the actual function globals and restore exact objects in finally."""
    globals_dict = _main_globals(namespace, baseline_path)
    old_revision = globals_dict["REVISION"]
    old_validator = globals_dict["validate_wrapper"]

    def validate_frozen_v2_input(value: Any) -> Any:
        # The unchanged v2 validator requires the v2 input identity. Only its
        # call observes v2; output construction after it sees the v4 identity.
        globals_dict["REVISION"] = BASELINE_REVISION
        try:
            return old_validator(value)
        finally:
            globals_dict["REVISION"] = VERSIONED_REVISION

    globals_dict["validate_wrapper"] = validate_frozen_v2_input
    globals_dict["REVISION"] = VERSIONED_REVISION
    try:
        yield globals_dict
    finally:
        globals_dict["REVISION"] = old_revision
        globals_dict["validate_wrapper"] = old_validator


def verify_freegs_backend(equilibrium_class: type) -> Any:
    import freegs
    from freegs import equilibrium, picard

    if getattr(freegs, "Equilibrium", None) is not equilibrium_class:
        raise RuntimeError("requested Equilibrium class is not the pinned FreeGS class")
    source_hashes = verify_pinned_freegs_sources(equilibrium_class)
    verify_pinned_freegs_solve_api(
        freegs, picard, Path(equilibrium.__file__).resolve().parent
    )
    return freegs, source_hashes


def _output_path(argv: Sequence[str]) -> Path:
    positions = [index for index, item in enumerate(argv) if item == "--output"]
    if len(positions) != 1 or positions[0] + 1 >= len(argv):
        raise RuntimeError("v12 runner requires exactly one --output path for its receipt")
    return Path(argv[positions[0] + 1])


def _write_adapter_receipt(path: Path, receipt: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(receipt, indent=2, sort_keys=True, allow_nan=False) + "\n"
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        handle.write(payload)
        handle.flush()


def run_baseline(
    argv: Sequence[str],
    *,
    equilibrium_class: type | None = None,
    runner_loader: Callable[..., dict[str, Any]] | None = None,
) -> int:
    args = list(argv)
    output_path = _output_path(args)
    receipt_path = output_path.parent / ADAPTER_RECEIPT_NAME
    if receipt_path.exists():
        raise FileExistsError(f"v12 adapter receipt already exists: {receipt_path}")
    baseline_hash = verify_baseline_hash(BASELINE_RUNNER)
    freegs_module = None
    pinned_source_hashes: dict[str, str] = {}
    if equilibrium_class is None:
        import freegs

        freegs_module = freegs
        equilibrium_class = freegs.Equilibrium
    elif getattr(equilibrium_class, "__module__", "").startswith("freegs."):
        import freegs

        freegs_module = freegs
    if freegs_module is not None:
        freegs_module, pinned_source_hashes = verify_freegs_backend(equilibrium_class)
    if runner_loader is None:
        runner_loader = runpy.run_path
    if not BASELINE_RUNNER.is_file():
        raise FileNotFoundError(f"pinned baseline runner is missing: {BASELINE_RUNNER}")

    receipt: dict[str, Any] = {
        "schema": "fusionconceptai:freegs-observed-dirichlet-adapter-receipt-v2",
        "revision": VERSIONED_REVISION,
        "status": "started",
        "baseline_runner_path": str(BASELINE_RUNNER),
        "baseline_runner_sha256": baseline_hash,
        "adapter_path": str(Path(__file__).resolve().with_name(
            "freegs_observed_dirichlet_boundary_v2.py")),
        "adapter_sha256": hashlib.sha256(
            Path(__file__).resolve().with_name("freegs_observed_dirichlet_boundary_v2.py").read_bytes()
        ).hexdigest(),
        "pinned_freegs_source_hashes": pinned_source_hashes,
        "output_path": str(output_path),
        "receipt_path": str(receipt_path),
        "version_binding": {
            "baseline_input_revision": BASELINE_REVISION,
            "emitted_result_revision": VERSIONED_REVISION,
            "namespace_vs_main_globals_separate": None,
            "patched_mapping": "delegated main.__globals__",
            "globals_restored_after_call": False,
        },
    }
    try:
        namespace = runner_loader(str(BASELINE_RUNNER), run_name=DELEGATE_RUN_NAME)
        main_function = namespace.get("main")
        if not callable(main_function):
            raise RuntimeError("delegated v2 runner did not define callable main")
        main_globals = _main_globals(namespace, BASELINE_RUNNER)
        receipt["version_binding"]["namespace_vs_main_globals_separate"] = (
            namespace is not main_globals
        )
        with versioned_v2_main_globals(namespace, BASELINE_RUNNER):
            if freegs_module is None:
                # Fake backend support is for Python-only unit tests. Actual
                # FreeGS runs always take the verified module-owned path below.
                return int(main_function(args))
            with temporary_observed_dirichlet_projection(
                equilibrium_class,
                expected_runner_file=BASELINE_RUNNER,
                solver_owner=freegs_module,
                receipt=receipt,
            ):
                try:
                    rc = int(main_function(args))
                    receipt["runner_return_code"] = rc
                    receipt["status"] = "runner_returned"
                    return rc
                except BaseException as exc:
                    receipt["status"] = "runner_raised"
                    receipt["runner_exception"] = {
                        "type": type(exc).__name__, "message": str(exc)
                    }
                    raise
    except BaseException as exc:
        receipt.setdefault("status", "runner_raised")
        receipt.setdefault("runner_exception", {"type": type(exc).__name__, "message": str(exc)})
        raise
    finally:
        # The inner version context restores globals before control reaches here.
        receipt["version_binding"]["globals_restored_after_call"] = True
        _write_adapter_receipt(receipt_path, receipt)


def main(argv: Sequence[str] | None = None) -> int:
    return run_baseline(sys.argv[1:] if argv is None else argv)


if __name__ == "__main__":
    raise SystemExit(main())
