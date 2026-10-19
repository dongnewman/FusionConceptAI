"""v17 wrapper for a versioned fixed-observed-box Dirichlet Picard policy.

The frozen v2 input validator and source remain pinned.  The wrapper supplies
a shallow, run-local FreeGS namespace whose ``solve`` entry points at the
versioned policy; the imported FreeGS package/module object is never modified.
The v16 exact A_II/A_IB adapter remains scoped to the marked target instance.
"""

from __future__ import annotations

from contextlib import contextmanager
from contextvars import ContextVar, Token
import hashlib
import json
import runpy
import sys
from pathlib import Path
from types import SimpleNamespace
from typing import Any, Callable, Iterator, MutableMapping, Sequence

if __package__:
    from . import runtime_v4_freegs_axisymmetric_profile_runner_v7 as _v7
    from .freegs_fixed_box_picard_v1 import (
        FixedBoxBoundaryDriftError,
        FixedBoxNumericalStateError,
        FixedBoxPicardNonconvergence,
        FixedBoxTerminalTopologyUnsupported,
        FixedBoxTopologyObservationUnavailable,
        POLICY_REVISION,
        solve_fixed_observed_box,
    )
    from .freegs_observed_dirichlet_boundary_v4 import (
        temporary_observed_dirichlet_linear_solve,
    )
else:
    import runtime_v4_freegs_axisymmetric_profile_runner_v7 as _v7
    from freegs_fixed_box_picard_v1 import (
        FixedBoxBoundaryDriftError,
        FixedBoxNumericalStateError,
        FixedBoxPicardNonconvergence,
        FixedBoxTerminalTopologyUnsupported,
        FixedBoxTopologyObservationUnavailable,
        POLICY_REVISION,
        solve_fixed_observed_box,
    )
    from freegs_observed_dirichlet_boundary_v4 import (
        temporary_observed_dirichlet_linear_solve,
    )


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
BASELINE_RUNNER = _v7.BASELINE_RUNNER
VERSIONED_REVISION = (
    "runtime-v4-freegs-axisymmetric-profile-execution-v8-"
    "fixed-observed-box-dirichlet-picard-policy-v1"
)
DELEGATE_RUN_NAME = "_up4_reference_validation_v17_baseline"
ADAPTER_RECEIPT_NAME = "freegs_adapter_receipt_v17.json"
POLICY_RECEIPT_KEY = "fixed_box_dirichlet_picard_policy"


def make_freegs_policy_proxy(freegs_module: Any, solve_callable: Callable[..., Any]) -> Any:
    """Return a shallow module-like namespace without changing FreeGS globals."""
    if not callable(solve_callable):
        raise TypeError("versioned fixed-box solve callable must be callable")
    namespace = getattr(freegs_module, "__dict__", None)
    if not isinstance(namespace, dict) or not callable(namespace.get("solve")):
        raise RuntimeError("pinned FreeGS module has no callable solve API")
    proxy = SimpleNamespace(**namespace)
    proxy.solve = solve_callable
    if proxy is freegs_module or getattr(freegs_module, "solve", None) is solve_callable:
        raise RuntimeError("policy proxy unexpectedly aliases the imported FreeGS module")
    return proxy


def _classify_policy_failure(exc: Exception, fallback: Callable[..., Any], state: Any) -> Any:
    if isinstance(exc, FixedBoxPicardNonconvergence):
        return "numerical_fail_nonconvergence", 4
    if isinstance(exc, FixedBoxBoundaryDriftError):
        return "numerical_fail_boundary_invariant", 4
    if isinstance(exc, FixedBoxNumericalStateError):
        return "numerical_fail_invalid_state", 4
    if isinstance(exc, FixedBoxTerminalTopologyUnsupported):
        return "unsupported_fixed_box_terminal_topology", 6
    if isinstance(exc, FixedBoxTopologyObservationUnavailable):
        return "program_exception", 5
    return fallback(exc, state)


@contextmanager
def temporary_v17_runner_bindings(
    main_globals: MutableMapping[str, Any],
    freegs_module: Any,
    freegs_proxy: Any,
    observer_context: ContextVar[Any],
    policy_receipt: MutableMapping[str, Any],
    binding_receipt: MutableMapping[str, Any],
) -> Iterator[None]:
    """Scope all runner-global bindings and restore exact original objects."""
    names = (
        "environment_manifest",
        "EquilibriumSolveObserver",
        "classify_failure",
        "write_result",
    )
    if any(name not in main_globals or not callable(main_globals[name]) for name in names):
        raise RuntimeError("pinned baseline does not expose all v17 runner bindings")
    originals = {name: main_globals[name] for name in names}
    observer_tokens: list[Token[Any]] = []
    binding_receipt.update({
        "context_entered": False,
        "restore_attempted": False,
        "restored_exact": False,
        "freegs_module_object_unchanged": None,
        "policy_namespace_isolated": freegs_proxy is not freegs_module,
    })
    freegs_dict_before = dict(getattr(freegs_module, "__dict__", {}))

    def environment_manifest_with_proxy(*args: Any, **kwargs: Any) -> Any:
        returned = originals["environment_manifest"](*args, **kwargs)
        if not isinstance(returned, tuple) or len(returned) != 4:
            raise RuntimeError("pinned environment manifest returned an unexpected tuple")
        environment, observed_module, np_module, scipy_module = returned
        if observed_module is not freegs_module:
            raise RuntimeError("baseline environment manifest returned another FreeGS module")
        return environment, freegs_proxy, np_module, scipy_module

    def observed_observer_factory(*args: Any, **kwargs: Any) -> Any:
        observer = originals["EquilibriumSolveObserver"](*args, **kwargs)
        observer_tokens.append(observer_context.set(observer))
        return observer

    def classify_v17(exc: Exception, state: Any) -> Any:
        return _classify_policy_failure(exc, originals["classify_failure"], state)

    def write_v17_result(path: Any, result: dict[str, Any]) -> Any:
        if result.get("status") == "conditional_fixed_boundary_solver_converged_residual_measured":
            if policy_receipt.get("status") != "test_only_fixed_box_policy_converged":
                raise RuntimeError("v17 policy receipt does not prove its own convergence")
            result["status"] = (
                "test_only_fixed_observed_box_dirichlet_policy_converged_residual_measured"
            )
            result["solver_algorithm"] = {
                "revision": POLICY_REVISION,
                "native_freegs_picard_called": False,
                "native_picard_stopping_rule_used": False,
                "stopping_rule_replaced_by_versioned_fixed_box_policy": True,
                "boundary_convergence_state": "all_four_frozen_observed_edges_bitwise_exact",
                "boundary_scalar_flux_used": False,
                "rtol_atol_maxits_blend_changed": False,
                "transient_xpoints_recorded": True,
                "terminal_xpoint_or_limited_gate": "fail_closed",
                "numerical_scope": "fixed_box_dirichlet_iteration_only",
                "physics_credit": False,
                "inverse_credit": False,
            }
            result[POLICY_RECEIPT_KEY] = dict(policy_receipt)
            assessment = result.setdefault("numerical_assessment", {})
            assessment["native_freegs_picard_convergence"] = "not_run_versioned_policy_used"
            assessment["versioned_policy_test_only_converged"] = True
            assessment["independent_pde_acceptance"] = False
            assessment["independent_gs_residual_acceptance_threshold"] = (
                "typed_absent_not_defined"
            )
            result.pop("result_sha256", None)
            result["result_sha256"] = main_globals["canonical_hash"](result)
        return originals["write_result"](path, result)

    entered = False
    try:
        main_globals["environment_manifest"] = environment_manifest_with_proxy
        main_globals["EquilibriumSolveObserver"] = observed_observer_factory
        main_globals["classify_failure"] = classify_v17
        main_globals["write_result"] = write_v17_result
        entered = True
        binding_receipt["context_entered"] = True
        yield
    finally:
        if entered:
            binding_receipt["restore_attempted"] = True
            for name, original in originals.items():
                main_globals[name] = original
            for token in reversed(observer_tokens):
                observer_context.reset(token)
            restored = all(main_globals.get(name) is original for name, original in originals.items())
            freegs_dict_after = getattr(freegs_module, "__dict__", {})
            module_unchanged = (
                isinstance(freegs_dict_after, dict)
                and set(freegs_dict_after) == set(freegs_dict_before)
                and all(freegs_dict_after.get(key) is value for key, value in freegs_dict_before.items())
            )
            binding_receipt["restored_exact"] = restored
            binding_receipt["freegs_module_object_unchanged"] = module_unchanged
            if not restored or not module_unchanged:
                raise RuntimeError("v17 runner binding or FreeGS module restoration failed")


def run_baseline(
    argv: Sequence[str],
    *,
    equilibrium_class: type | None = None,
    runner_loader: Callable[..., dict[str, Any]] | None = None,
) -> int:
    args = list(argv)
    output_path = _v7._output_path(args)
    receipt_path = output_path.parent / ADAPTER_RECEIPT_NAME
    if receipt_path.exists():
        raise FileExistsError(f"v17 adapter receipt already exists: {receipt_path}")
    baseline_hash = _v7.verify_baseline_hash(BASELINE_RUNNER)
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
        freegs_module, pinned_source_hashes = _v7.verify_freegs_backend(equilibrium_class)
    if runner_loader is None:
        runner_loader = runpy.run_path
    if not BASELINE_RUNNER.is_file():
        raise FileNotFoundError(f"pinned baseline runner is missing: {BASELINE_RUNNER}")

    receipt: dict[str, Any] = {
        "schema": "fusionconceptai:freegs-fixed-observed-box-picard-adapter-receipt-v1",
        "revision": VERSIONED_REVISION,
        "status": "started",
        "baseline_runner_path": str(BASELINE_RUNNER),
        "baseline_runner_sha256": baseline_hash,
        "runner_path": str(Path(__file__).resolve()),
        "runner_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "policy_path": str(Path(__file__).with_name("freegs_fixed_box_picard_v1.py")),
        "policy_sha256": hashlib.sha256(
            Path(__file__).with_name("freegs_fixed_box_picard_v1.py").read_bytes()
        ).hexdigest(),
        "pinned_freegs_source_hashes": pinned_source_hashes,
        "output_path": str(output_path),
        "receipt_path": str(receipt_path),
        "solver_policy": {
            "revision": POLICY_REVISION,
            "native_freegs_picard_called": False,
            "numeric_controls_changed": False,
            "native_boundary_scalar_stop_replaced": True,
            "boundary_metric": "bit-exact full observed edge array equality",
            "boundary_drift_action": "fail_closed_no_projection_no_fallback",
            "terminal_topology_gate": "fail_closed_on_final_xpoint_or_limited_state",
            "transient_xpoints": "observed_and_recorded_then_permitted_to_disappear",
            "psi_bndry_read_or_written": False,
            "corner_proxy_write": False,
            "physical_boundary_flux_claim": False,
            "physics_credit": False,
            "inverse_credit": False,
        },
        POLICY_RECEIPT_KEY: {},
        "runner_global_bindings": {
            "context_entered": False,
            "restore_attempted": False,
            "restored_exact": False,
            "freegs_module_object_unchanged": None,
            "policy_namespace_isolated": False,
        },
        "version_binding": {
            "baseline_input_revision": _v7.BASELINE_REVISION,
            "emitted_result_revision": VERSIONED_REVISION,
            "namespace_vs_main_globals_separate": None,
            "patched_mapping": "delegated main.__globals__",
            "globals_context_entered": False,
            "globals_context_restore_attempted": False,
            "globals_restored_after_context": False,
            "globals_restore_exact": False,
        },
    }
    observer_context: ContextVar[Any] = ContextVar(
        "freegs_v17_active_equilibrium_observer", default=None
    )
    policy_receipt: MutableMapping[str, Any] = receipt[POLICY_RECEIPT_KEY]
    freegs_proxy = None
    try:
        namespace = runner_loader(str(BASELINE_RUNNER), run_name=DELEGATE_RUN_NAME)
        main_function = namespace.get("main")
        if not callable(main_function):
            raise RuntimeError("delegated v2 runner did not define callable main")
        main_globals = _v7._main_globals(namespace, BASELINE_RUNNER)
        receipt["version_binding"]["namespace_vs_main_globals_separate"] = (
            namespace is not main_globals
        )
        if freegs_module is None:
            raise RuntimeError("v17 actual dispatch requires the pinned FreeGS backend")

        def policy_solve(*solve_args: Any, **solve_kwargs: Any) -> Any:
            observer = observer_context.get()
            return solve_fixed_observed_box(
                *solve_args,
                observer=observer,
                policy_receipt=policy_receipt,
                **solve_kwargs,
            )

        freegs_proxy = make_freegs_policy_proxy(freegs_module, policy_solve)
        receipt["runner_global_bindings"]["policy_namespace_isolated"] = (
            freegs_proxy is not freegs_module
        )
        with _v7.versioned_v2_main_globals(
            namespace,
            BASELINE_RUNNER,
            version_binding_receipt=receipt["version_binding"],
        ):
            with temporary_v17_runner_bindings(
                main_globals,
                freegs_module,
                freegs_proxy,
                observer_context,
                policy_receipt,
                receipt["runner_global_bindings"],
            ):
                with temporary_observed_dirichlet_linear_solve(
                    equilibrium_class,
                    expected_runner_file=BASELINE_RUNNER,
                    solver_owner=freegs_proxy,
                    receipt=receipt,
                ):
                    try:
                        rc = int(main_function(args))
                        receipt["runner_return_code"] = rc
                        receipt["status"] = "runner_returned"
                        receipt["runner_global_bindings"]["formal_freegs_solve_returned"] = False
                        receipt["runner_global_bindings"]["versioned_policy_attempted"] = (
                            bool(policy_receipt.get("iteration_history"))
                        )
                        receipt["runner_global_bindings"]["versioned_policy_converged"] = (
                            policy_receipt.get("status") == "test_only_fixed_box_policy_converged"
                        )
                        if isinstance(receipt.get("target"), dict):
                            receipt["target"]["formal_freegs_solve_returned"] = False
                            receipt["target"]["versioned_fixed_box_policy_attempted"] = (
                                bool(policy_receipt.get("iteration_history"))
                            )
                            receipt["target"]["versioned_fixed_box_policy_converged"] = (
                                policy_receipt.get("status") == "test_only_fixed_box_policy_converged"
                            )
                        return rc
                    except BaseException as exc:
                        receipt["status"] = "runner_raised"
                        receipt["runner_exception"] = {
                            "type": type(exc).__name__, "message": str(exc)
                        }
                        raise
    except BaseException as exc:
        receipt["status"] = "runner_raised"
        receipt["runner_exception"] = {
            "type": type(exc).__name__, "message": str(exc)
        }
        raise
    finally:
        receipt["policy_boundary_semantics"] = {
            "native_freegs_picard_called": False,
            "native_eq_psi_bndry_stopping_scalar_used": False,
            "eq_psi_bndry_observations_are_read_only_diagnostics": True,
            "convergence_control_changed_from_native": True,
            "configured_rtol_atol_maxits_blend_changed": False,
            "boundary_metric": "all_four_frozen_observed_edges_bitwise_exact_each_solve",
            "terminal_topology_gate": "fail_closed_if_final_xpoint_or_limited",
            "transient_xpoints": "observed_only_and_may_disappear",
            "physical_or_inverse_credit": False,
        }
        for event in receipt.get("boundary_scalar_events", []):
            if isinstance(event, dict):
                event["picard_stop_effect"] = "not_used_by_v17_versioned_policy"
                event["observation_scope"] = "read_only_native_scalar_transition_diagnostic"
        target = receipt.get("target")
        if isinstance(target, dict):
            target["picard_controls_changed"] = True
            target["convergence_control_changed_from_native"] = True
            target["configured_thresholds_and_blend_changed"] = False
        _v7._write_adapter_receipt(receipt_path, receipt)


def main(argv: Sequence[str] | None = None) -> int:
    return run_baseline(sys.argv[1:] if argv is None else argv)


if __name__ == "__main__":
    raise SystemExit(main())
