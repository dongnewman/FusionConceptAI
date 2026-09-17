"""Offline, fail-closed adapter orchestration for UP1 external closure R4.

This module is a seam adapter, not an authority service.  It calls the frozen
local APIs with caller-supplied material only and returns one aggregate
decision.  In particular, it never contacts a channel, opens a trust store,
commits a freshness ledger on behalf of a caller, starts T0/S3, or executes a
runtime.  A local structural pass remains deferred/non-evidence.
"""

from __future__ import annotations

import base64
import hashlib
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Iterable, Mapping, MutableMapping, Sequence

from ..authoritative_intake.intake import AuthorityIntake
from ..environment_closure.collector import collect_closure
from ..freshness.core import validate as validate_freshness
from ..g2_mapping.validator import evaluate as evaluate_g2
from ..source_axis_binding.source_axis_binding import validate_bundle as validate_source_axis
from ..trust_chain.verifier import verify_request
from ...up1_external_closure_r3.atomic_bundle.bundle import validate_bundle as validate_atomic_bundle


STAGE_ORDER = (
    "atomic_bundle",
    "authoritative_intake",
    "source_axis_binding",
    "g2_mapping",
    "environment_closure",
    "trust_chain",
    "freshness",
)

FORMAL_CREDIT = "none"
NO_PUBLISH = True
AUTHORITY_CREDIT = False

_ABSENT_STATES = frozenset({
    "typed_absent",
    "typed_absence",
    "terminal_deferred",
    "rejected_all_absent",
})
_UNVERIFIED_STATES = frozenset({
    "typed_unverified",
    "unverified",
    "local_observed",
    "accepted_local",
    "TEST_ONLY",
    "test_only",
    "valid_for_declared_scope",
})
_HARD_STATES = frozenset({
    "program_exception",
    "typed_program_exception",
    "invalid",
    "fail_closed",
    "rejected_all",
    "cas_conflict",
})
_HARD_CODE_MARKERS = (
    "invalid",
    "mismatch",
    "contradiction",
    "duplicate",
    "foreign_",
    "source_drift",
    "digest",
    "hash",
    "cas_conflict",
    "collision",
    "replay",
    "sequence",
    "scope_binding",
    "publication",
    "publish_forbidden",
    "formal_credit",
)
_ABSENCE_CODE_MARKERS = (
    "absent",
    "missing",
    "unavailable",
    "not_supplied",
    "not_configured",
    "no_external",
    "runtime_inventory",
    "binary_inventory",
    "lock_or_channel",
)


def _sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _jsonable(value: Any) -> Any:
    """Convert adapter values to a stable digestable representation.

    Bytes are represented by their digest and length, never decoded or
    rewritten.  This preserves the fact that the adapter was handed exact raw
    bytes without putting arbitrary binary material in an aggregate receipt.
    """
    if isinstance(value, (bytes, bytearray, memoryview)):
        raw = bytes(value)
        return {"__bytes_sha256__": _sha256(raw), "length": len(raw)}
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, Mapping):
        return {str(key): _jsonable(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_jsonable(item) for item in value]
    if isinstance(value, (str, int, bool)) or value is None:
        return value
    if isinstance(value, float):
        # Adapter outputs are expected to be strict JSON.  Keeping a marker
        # here makes a non-JSON output visible instead of silently rounding it.
        return {"__unsupported_float__": repr(value)}
    return {"__unsupported_type__": type(value).__name__}


def _canonical(value: Any) -> bytes:
    return json.dumps(_jsonable(value), ensure_ascii=False, sort_keys=True,
                      separators=(",", ":"), allow_nan=False).encode("utf-8")


def _digest(value: Any) -> str:
    return _sha256(_canonical(value))


def _first(mapping: Mapping[str, Any], *names: str, default: Any = None) -> Any:
    for name in names:
        if name in mapping:
            return mapping[name]
    return default


def _section(request: Mapping[str, Any], *names: str) -> Mapping[str, Any] | None:
    value = _first(request, *names)
    return value if isinstance(value, Mapping) else None


def _find_nested(value: Any, *names: str) -> Any:
    """Find the first explicitly named binding field without guessing paths."""
    wanted = set(names)
    if isinstance(value, Mapping):
        for key, item in value.items():
            if key in wanted and item is not None:
                return item
        for item in value.values():
            found = _find_nested(item, *names)
            if found is not None:
                return found
    elif isinstance(value, (list, tuple)):
        for item in value:
            found = _find_nested(item, *names)
            if found is not None:
                return found
    return None


def _extract_codes(value: Any) -> list[str]:
    codes: list[str] = []
    if isinstance(value, Mapping):
        for key in ("failure_codes", "errors", "error_code", "code", "reason"):
            item = value.get(key)
            if key in {"errors", "failure_codes"} and isinstance(item, Sequence) and not isinstance(item, (str, bytes, bytearray)):
                for error in item:
                    codes.extend(_extract_codes(error))
            elif isinstance(item, str) and item:
                codes.append(item)
        for key in ("checks", "details"):
            if key in value and isinstance(value[key], Mapping):
                # Do not classify arbitrary detail text as an error, but retain
                # explicit nested error fields.
                codes.extend(_extract_codes(value[key]))
    elif isinstance(value, str) and value:
        codes.append(value)
    return list(dict.fromkeys(codes))


def _state(value: Mapping[str, Any]) -> str:
    for key in ("status", "state", "resolution", "result", "decision", "authority_status"):
        item = value.get(key)
        if isinstance(item, str) and item:
            return item
    return "typed_absent"


def _lock_violation(value: Mapping[str, Any]) -> bool:
    return (
        ("formal_credit" in value and value.get("formal_credit") != FORMAL_CREDIT)
        or ("no_publish" in value and value.get("no_publish") is not NO_PUBLISH)
        or ("authority_credit" in value and value.get("authority_credit") is not AUTHORITY_CREDIT)
    )


def _is_hard(value: Mapping[str, Any]) -> bool:
    status = _state(value)
    if status in _HARD_STATES or _lock_violation(value):
        return True
    codes = [code.lower() for code in _extract_codes(value)]
    if any(code in {"program_exception", "typed_program_exception", "publication_lock"} for code in codes):
        return True
    # An explicit rejected set is hard unless the module itself typed it as an
    # authority absence (the intake adapter uses this for missing channel).
    if status == "rejected_all" and not _is_absence(value):
        return True
    return any(any(marker in code for marker in _HARD_CODE_MARKERS) for code in codes)


def _is_absence(value: Mapping[str, Any]) -> bool:
    status = _state(value)
    if status in _ABSENT_STATES:
        return True
    codes = [code.lower() for code in _extract_codes(value)]
    return any(any(marker in code for marker in _ABSENCE_CODE_MARKERS) for code in codes)


def _normalise_stage(value: Mapping[str, Any]) -> str:
    if _is_hard(value):
        return "fail_closed"
    if _is_absence(value) or _state(value) in _UNVERIFIED_STATES:
        return "terminal_deferred"
    # Unknown local outputs are not promoted.  This also handles a module that
    # returned a shape newer than this adapter understands.
    return "terminal_deferred"


def _typed_absent(stage: str, reason: str = "external_input_absent") -> dict[str, Any]:
    return {
        "schema": "UP1.external-closure-r4.integration-stage.v1",
        "stage": stage,
        "status": "typed_absent",
        "resolution": "terminal_deferred",
        "decision": "terminal_deferred",
        "classification": "non_evidence",
        "reason": reason,
        "failure_codes": ["typed_absent"],
        "formal_credit": FORMAL_CREDIT,
        "authority_credit": AUTHORITY_CREDIT,
        "no_publish": NO_PUBLISH,
    }


def _typed_exception(stage: str, exc: BaseException) -> dict[str, Any]:
    return {
        "schema": "UP1.external-closure-r4.integration-stage.v1",
        "stage": stage,
        "status": "typed_program_exception",
        "resolution": "fail_limited",
        "decision": "fail_closed",
        "implementation_status": "fail_limited",
        "failure_codes": ["PROGRAM_EXCEPTION", type(exc).__name__],
        "error": str(exc),
        "formal_credit": FORMAL_CREDIT,
        "authority_credit": AUTHORITY_CREDIT,
        "no_publish": NO_PUBLISH,
    }


def _receipt_refs(value: Any, prefix: str = "$") -> list[dict[str, str]]:
    refs: list[dict[str, str]] = []
    if isinstance(value, Mapping):
        for key, item in value.items():
            path = f"{prefix}.{key}"
            lower = str(key).lower()
            if isinstance(item, str) and item and (lower.endswith("_ref") or lower.endswith("_sha256") or lower in {"cas_path", "quarantine_locator", "quarantine_transaction_id", "receipt_ref"}):
                refs.append({"path": path, "value": item})
            elif isinstance(item, Mapping) or isinstance(item, (list, tuple)):
                refs.extend(_receipt_refs(item, path))
    elif isinstance(value, (list, tuple)):
        for index, item in enumerate(value):
            refs.extend(_receipt_refs(item, f"{prefix}[{index}]"))
    return refs


@dataclass(frozen=True)
class BindingTuple:
    """Cross-stage identity tuple carried without inferred values."""

    candidate_id: str | None = None
    source_identity_digest: str | None = None
    run_id: str | None = None
    request_id: str | None = None
    bundle_id: str | None = None
    raw_sha256: str | None = None
    bundle_canonical_sha256: str | None = None
    packet_digests: tuple[Any, ...] | None = ()
    quarantine_locator: str | None = None
    quarantine_transaction_id: str | None = None
    nonce: str | None = None
    sequence: int | None = None
    idempotency_key: str | None = None
    scope: Mapping[str, Any] | None = field(default_factory=dict)
    result_digest: str | None = None

    def as_dict(self) -> dict[str, Any]:
        return {
            "candidate_id": self.candidate_id,
            "source_identity_digest": self.source_identity_digest,
            "run_id": self.run_id,
            "request_id": self.request_id,
            "bundle_id": self.bundle_id,
            "raw_sha256": self.raw_sha256,
            "bundle_canonical_sha256": self.bundle_canonical_sha256,
            "packet_digests": (list(self.packet_digests)
                               if self.packet_digests is not None else None),
            "quarantine_locator": self.quarantine_locator,
            "quarantine_transaction_id": self.quarantine_transaction_id,
            "nonce": self.nonce,
            "sequence": self.sequence,
            "idempotency_key": self.idempotency_key,
            "scope": dict(self.scope) if self.scope is not None else None,
            "result_digest": self.result_digest,
        }


_BINDING_FIELD_ALIASES: dict[str, tuple[str, ...]] = {
    "candidate_id": ("candidate_id",),
    "source_identity_digest": ("source_identity_digest", "source_identity_sha256"),
    "run_id": ("run_id",),
    "request_id": ("request_id",),
    "bundle_id": ("bundle_id",),
    "raw_sha256": ("raw_sha256",),
    "bundle_canonical_sha256": ("bundle_canonical_sha256",),
    "packet_digests": ("packet_digests",),
    "quarantine_locator": ("quarantine_locator", "cas_path"),
    "quarantine_transaction_id": ("quarantine_transaction_id", "cas_transaction_id"),
    "nonce": ("nonce",),
    "sequence": ("sequence",),
    "idempotency_key": ("idempotency_key",),
    "scope": ("scope",),
    "result_digest": ("result_digest", "canonical_receipt_digest"),
}


def _binding_present(value: Any) -> bool:
    """Return whether a binding observation carries a non-empty value."""
    if value is None:
        return False
    if isinstance(value, (str, bytes, bytearray, memoryview)):
        return len(value) != 0
    if isinstance(value, (Mapping, list, tuple, set, frozenset)):
        return len(value) != 0
    return True


def _binding_key(value: Any) -> bytes:
    """Canonical key used only to compare observations, never to rewrite them."""
    return _canonical(value)


def _collect_named(value: Any, names: frozenset[str], path: str = "$") -> list[tuple[str, Any]]:
    """Collect every exact named field instead of selecting the first one.

    Receipts may nest identity fields under ``binding``/``ack``/``receipt``.
    Keeping all occurrences is intentional: a duplicate field with a foreign
    value is a contradiction, not an opportunity to pick a convenient value.
    """
    found: list[tuple[str, Any]] = []
    if isinstance(value, Mapping):
        for key, item in value.items():
            item_path = f"{path}.{key}"
            if str(key) in names and _binding_present(item):
                found.append((item_path, item))
            if isinstance(item, (Mapping, list, tuple)):
                found.extend(_collect_named(item, names, item_path))
    elif isinstance(value, (list, tuple)):
        for index, item in enumerate(value):
            if isinstance(item, (Mapping, list, tuple)):
                found.extend(_collect_named(item, names, f"{path}[{index}]"))
    return found


def _binding_observations(request: Mapping[str, Any], outputs: Mapping[str, Mapping[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    observations: dict[str, list[dict[str, Any]]] = {field: [] for field in _BINDING_FIELD_ALIASES}

    def add(origin: str, tree: Any) -> None:
        if not isinstance(tree, (Mapping, list, tuple)):
            return
        for field, aliases in _BINDING_FIELD_ALIASES.items():
            for path, value in _collect_named(tree, frozenset(aliases)):
                observations[field].append({"origin": origin, "path": path, "value": value})

    # The caller's scope is an observation too.  A stage may not silently
    # disagree with it by being allowed to overwrite it via first-value wins.
    add("request", request)
    for stage, result in outputs.items():
        add(stage, result)
    return observations


def _consensus_binding(observations: Mapping[str, Sequence[Mapping[str, Any]]]) -> tuple[BindingTuple, list[dict[str, Any]]]:
    values: dict[str, Any] = {}
    conflicts: list[dict[str, Any]] = []
    for field in _BINDING_FIELD_ALIASES:
        rows = [row for row in observations.get(field, ()) if _binding_present(row.get("value"))]
        unique: dict[bytes, list[Mapping[str, Any]]] = {}
        for row in rows:
            unique.setdefault(_binding_key(row.get("value")), []).append(row)
        if len(unique) > 1:
            conflicts.append({
                "field": field,
                "observations": [
                    {"origin": row.get("origin"), "path": row.get("path"), "value": _jsonable(row.get("value"))}
                    for row in rows
                ],
            })
            # A conflicted field must not leak the first observed identity.
            values[field] = None
        elif rows:
            values[field] = rows[0].get("value")
        else:
            values[field] = None

    conflicted_fields = {conflict["field"] for conflict in conflicts}
    packet_digests = values.get("packet_digests")
    if not isinstance(packet_digests, (list, tuple)):
        # An explicit cross-stage contradiction is an unset binding, not the
        # empty collection used for a genuinely absent optional observation.
        packet_digests = None if "packet_digests" in conflicted_fields else ()
    scope = values.get("scope")
    if not isinstance(scope, Mapping):
        # Keep the same distinction for structured scope bindings: conflict
        # must remain visibly unset instead of being normalised to ``{}``.
        scope = None if "scope" in conflicted_fields else {}
    return BindingTuple(
        candidate_id=values.get("candidate_id"),
        source_identity_digest=values.get("source_identity_digest"),
        run_id=values.get("run_id"),
        request_id=values.get("request_id"),
        bundle_id=values.get("bundle_id"),
        raw_sha256=values.get("raw_sha256"),
        bundle_canonical_sha256=values.get("bundle_canonical_sha256"),
        packet_digests=(tuple(packet_digests)
                        if packet_digests is not None else None),
        quarantine_locator=values.get("quarantine_locator"),
        quarantine_transaction_id=values.get("quarantine_transaction_id"),
        nonce=values.get("nonce"),
        sequence=values.get("sequence"),
        idempotency_key=values.get("idempotency_key"),
        scope=dict(scope) if scope is not None else None,
        result_digest=values.get("result_digest"),
    ), conflicts


def _binding(request: Mapping[str, Any], outputs: Mapping[str, Mapping[str, Any]]) -> BindingTuple:
    """Return only a consensus tuple; conflicting fields remain unset."""
    binding, _ = _consensus_binding(_binding_observations(request, outputs))
    return binding


def merge_stage_results(stages: Mapping[str, Mapping[str, Any]], *, request: Mapping[str, Any] | None = None) -> dict[str, Any]:
    """Merge immutable stage outputs using the contract's conservative order."""
    request = request if isinstance(request, Mapping) else {}
    # The public seam is strict even when callers bypass ``run``.  ``run``
    # supplies all seven typed-absent rows for an empty request; a direct
    # partial merge is a contract violation and must never look deferred.
    ordered_stage_names = [stage for stage in STAGE_ORDER if stage in stages]
    ordered_stage_names.extend(stage for stage in stages if stage not in STAGE_ORDER)
    ordered_stages = {stage: stages[stage] for stage in ordered_stage_names}
    missing_stages = [stage for stage in STAGE_ORDER if stage not in stages]
    unknown_stages = [stage for stage in stages if stage not in STAGE_ORDER]

    normalized = {
        stage: (_normalise_stage(result) if isinstance(result, Mapping) else "fail_closed")
        for stage, result in ordered_stages.items()
    }
    hard = [stage for stage in ordered_stage_names if normalized[stage] == "fail_closed"]
    deferred = [stage for stage in ordered_stage_names if normalized[stage] == "terminal_deferred"]
    observations = _binding_observations(request, ordered_stages)
    binding, binding_conflicts = _consensus_binding(observations)
    binding_conflict_stages = sorted({
        row.get("origin")
        for conflict in binding_conflicts
        for row in conflict.get("observations", ())
        if row.get("origin") in STAGE_ORDER
    }, key=lambda stage: STAGE_ORDER.index(stage))
    if binding_conflicts:
        # Keep the source-stage receipts untouched while making the aggregate
        # hard.  A conflicted field is deliberately left unset in ``binding``.
        hard.extend(stage for stage in binding_conflict_stages if stage not in hard)
    contract_failure = bool(hard or missing_stages or unknown_stages)
    aggregate_status = "fail_closed" if contract_failure else "terminal_deferred"
    decision = "rejected_all" if contract_failure else "terminal_deferred"
    stage_hashes: dict[str, dict[str, Any]] = {}
    for stage, result in ordered_stages.items():
        input_sha256 = result.get("input_sha256") if isinstance(result, Mapping) else None
        output_sha256 = result.get("output_sha256", _digest(result)) if isinstance(result, Mapping) else _digest(result)
        stage_hashes[stage] = {
            "input_sha256": input_sha256,
            "output_sha256": output_sha256,
            "receipt_sha256": _digest({
                "stage": stage,
                "input_sha256": input_sha256,
                "output_sha256": output_sha256,
            }),
        }
    receipt_refs = {stage: _receipt_refs(result) for stage, result in ordered_stages.items()}
    aggregate = {
        "schema": "UP1.external-closure-r4.integration.v1",
        "status": aggregate_status,
        "resolution": aggregate_status,
        "decision": decision,
        "accepted_all": False,
        "classification": "non_evidence" if not contract_failure else "integrity_failure",
        "failure_stages": hard,
        "deferred_stages": deferred,
        "missing_stages": missing_stages,
        "unknown_stages": unknown_stages,
        "binding_conflicts": binding_conflicts,
        "binding_conflict_stages": binding_conflict_stages,
        "failure_codes": (["BINDING_CONFLICT"] if binding_conflicts else [])
        + (["MISSING_REQUIRED_STAGE"] if missing_stages else [])
        + (["UNKNOWN_STAGE"] if unknown_stages else []),
        "stages": dict(ordered_stages),
        "normalized_stages": normalized,
        "stage_hashes": stage_hashes,
        "receipt_refs": receipt_refs,
        "binding": binding.as_dict(),
        "formal_credit": FORMAL_CREDIT,
        "authority_credit": AUTHORITY_CREDIT,
        "no_publish": NO_PUBLISH,
        "t0_executed": False,
        "s3_executed": False,
        "network_access": False,
        "runtime_execution": False,
    }
    # ``binding.result_digest`` is an observed stage binding and must remain
    # the consensus value (or ``None`` after a contradiction).  Keep the
    # independently computed aggregate receipt digest under a distinct name so
    # it can never overwrite a conflicted binding field.
    aggregate["aggregate_result_digest"] = _digest(
        {key: value for key, value in aggregate.items() if key != "binding"}
    )
    aggregate["result_digest"] = aggregate["binding"]["result_digest"]
    return aggregate


class OfflineIntegrationOrchestrator:
    """Call the seven local seams and produce one all-or-reject result."""

    def __init__(self, *, intake: Any = None, replay_ledger: Any = None,
                 quarantine_root: str | Path | None = None,
                 adapters: Mapping[str, Callable[..., Any]] | None = None) -> None:
        self.intake = intake
        self.replay_ledger = replay_ledger
        self.quarantine_root = quarantine_root
        self.adapters = dict(adapters or {})

    def _invoke(self, stage: str, fn: Callable[..., Any], *args: Any, **kwargs: Any) -> dict[str, Any]:
        input_digest = _digest({"args": args, "kwargs": kwargs})
        try:
            value = fn(*args, **kwargs)
            if not isinstance(value, Mapping):
                raise TypeError(f"{stage} adapter returned {type(value).__name__}, expected mapping")
            result = dict(value)
        except (TypeError, AttributeError, KeyError, ValueError, OSError, RuntimeError) as exc:
            result = _typed_exception(stage, exc)
        except Exception as exc:  # adapter bugs remain explicitly fail-limited
            result = _typed_exception(stage, exc)
        result.setdefault("stage", stage)
        result["input_sha256"] = input_digest
        # Preserve a lock-clear attempt for diagnosis, but expose only the
        # frozen local ceiling to callers.  The explicit failure code keeps
        # the attempt hard-failing after the values are normalised.
        if _lock_violation(result):
            result["reported_formal_credit"] = result.get("formal_credit")
            result["reported_authority_credit"] = result.get("authority_credit")
            result["reported_no_publish"] = result.get("no_publish")
            codes = list(result.get("failure_codes", [])) if isinstance(result.get("failure_codes"), list) else []
            if "PUBLICATION_LOCK" not in codes:
                codes.append("PUBLICATION_LOCK")
            result["failure_codes"] = codes
        result["formal_credit"] = FORMAL_CREDIT
        result["authority_credit"] = AUTHORITY_CREDIT
        result["no_publish"] = NO_PUBLISH
        result["output_sha256"] = _digest(result)
        return result

    def _adapter(self, stage: str, default: Callable[..., Any]) -> Callable[..., Any]:
        value = self.adapters.get(stage)
        return value if callable(value) else default

    def _intake(self, request: Mapping[str, Any]) -> dict[str, Any]:
        section = _section(request, "authoritative_intake", "intake") or {}
        packets = _first(section, "packets", "packet_set")
        if packets is None:
            return _typed_absent("authoritative_intake")
        # Intake is an object seam in the frozen implementation, while tests
        # and embedding callers may inject a callable adapter.  Honour either
        # form without constructing a local channel when none was supplied.
        adapter = self.intake if self.intake is not None else self.adapters.get("authoritative_intake")
        if callable(adapter) and not callable(getattr(adapter, "receive_packet_set", None)):
            kwargs = {
                "channel_id": _first(section, "channel_id"),
                "transport_receipt": _first(section, "transport_receipt"),
                "request_id": _first(section, "request_id", default=_first(request, "request_id")),
            }
            return self._invoke("authoritative_intake", adapter, packets,
                                **{key: value for key, value in kwargs.items() if value is not None})
        if adapter is None:
            config = _first(section, "config", "intake_config")
            if isinstance(config, Mapping) and config.get("spool_root"):
                adapter = AuthorityIntake(
                    config["spool_root"],
                    channel_identity=config.get("channel_identity"),
                    channel_policy=config.get("channel_policy"),
                    signature_verifier=config.get("signature_verifier"),
                )
            else:
                return _typed_absent("authoritative_intake", "channel_or_owner_absent")
        method = getattr(adapter, "receive_packet_set", None)
        if not callable(method):
            return _typed_exception("authoritative_intake", TypeError("receive_packet_set seam is unavailable"))
        kwargs = {
            "channel_id": _first(section, "channel_id"),
            "transport_receipt": _first(section, "transport_receipt"),
            "request_id": _first(section, "request_id", default=_first(request, "request_id")),
        }
        return self._invoke("authoritative_intake", method, packets,
                            **{key: value for key, value in kwargs.items() if value is not None})

    def _trust(self, request: Mapping[str, Any]) -> dict[str, Any]:
        section = _section(request, "trust_chain", "trust")
        if section is None:
            return _typed_absent("trust_chain", "trust_material_absent")
        return self._invoke("trust_chain", self._adapter("trust_chain", verify_request), section)

    def _freshness(self, request: Mapping[str, Any]) -> dict[str, Any]:
        section = _section(request, "freshness")
        if section is None:
            return _typed_absent("freshness", "freshness_receipt_absent")
        payload = _first(section, "payload", "request", default=section)
        kwargs = {"ledger": self.replay_ledger} if self.replay_ledger is not None else {}
        return self._invoke("freshness", self._adapter("freshness", validate_freshness), payload, **kwargs)

    def _source(self, request: Mapping[str, Any]) -> dict[str, Any]:
        section = _section(request, "source_axis_binding", "source_axis", "source")
        if section is None:
            return _typed_absent("source_axis_binding", "source_identity_absent")
        bundle = _first(section, "bundle", "source_axis_bundle")
        observed = _first(section, "observed_source_identity", "observed_source")
        if bundle is None or observed is None:
            return _typed_absent("source_axis_binding", "source_or_observation_absent")
        return self._invoke("source_axis_binding", self._adapter("source_axis_binding", validate_source_axis), bundle, observed)

    def _g2(self, request: Mapping[str, Any]) -> dict[str, Any]:
        section = _section(request, "g2_mapping", "g2")
        if section is None:
            return _typed_absent("g2_mapping", "mapping_authority_absent")
        profile = _first(section, "profile", "mapping", default=section)
        return self._invoke("g2_mapping", self._adapter("g2_mapping", evaluate_g2), profile)

    def _environment(self, request: Mapping[str, Any]) -> dict[str, Any]:
        section = _section(request, "environment_closure", "environment")
        if section is None:
            return _typed_absent("environment_closure", "environment_material_absent")
        forbidden = {"execute", "run", "probe", "probe_versions", "network", "allow_network", "start_t0", "start_s3"}
        if any(section.get(key) not in (None, False) for key in forbidden):
            return _typed_exception("environment_closure", ValueError("execution/network probes are outside offline integration scope"))
        allowed = {"root", "runtimes", "runtime_paths", "python_path", "julia_path", "desc_path", "binaries", "binary_paths", "manifests", "source_receipt", "signature", "download_receipt", "sbom", "build_recipe", "command_timeout"}
        kwargs = {key: section[key] for key in allowed if key in section}
        kwargs["probe_versions"] = False
        return self._invoke("environment_closure", self._adapter("environment_closure", collect_closure), **kwargs)

    def _atomic(self, request: Mapping[str, Any]) -> dict[str, Any]:
        section = _section(request, "atomic_bundle", "r3", "bundle") or {}
        raw = _first(section, "raw_utf8", "raw", "bundle_raw", default=_first(request, "raw_utf8", "atomic_bundle_raw"))
        if raw is None:
            return _typed_absent("atomic_bundle", "raw_bundle_absent")
        if not isinstance(raw, (bytes, bytearray, memoryview)):
            return _typed_exception("atomic_bundle", TypeError("raw_utf8 exact bytes are required"))
        context = _first(section, "context", default=_first(request, "context", default={}))
        quarantine_root = _first(section, "quarantine_root", default=self.quarantine_root)
        if quarantine_root is None:
            return _typed_absent("atomic_bundle", "cas_quarantine_root_absent")
        return self._invoke("atomic_bundle", self._adapter("atomic_bundle", validate_atomic_bundle), bytes(raw), context, quarantine_root)

    def run(self, request: Mapping[str, Any] | None = None) -> dict[str, Any]:
        if not isinstance(request, Mapping):
            return merge_stage_results({stage: _typed_absent(stage, "request_absent") for stage in STAGE_ORDER}, request={})
        stages: MutableMapping[str, Mapping[str, Any]] = {}
        for stage, call in (
            # The exact received bytes enter the R3 quarantine/parser seam
            # before any downstream intake, binding, mapping, environment,
            # trust, or freshness seam is consulted.  Keep this order aligned
            # with the frozen 02 integration contract; do not reorder based
            # on which inputs happen to be present.
            ("atomic_bundle", self._atomic),
            ("authoritative_intake", self._intake),
            ("source_axis_binding", self._source),
            ("g2_mapping", self._g2),
            ("environment_closure", self._environment),
            ("trust_chain", self._trust),
            ("freshness", self._freshness),
        ):
            result = call(request)
            # Missing inputs are emitted before a component call; stamp them
            # with the same immutable hash envelope as invoked stages so the
            # aggregate never contains an unbound gap that resembles success.
            if not isinstance(result, Mapping):
                result = _typed_exception(stage, TypeError("stage adapter returned a non-mapping result"))
            result = dict(result)
            if "input_sha256" not in result:
                section = _section(request, stage, {
                    "source_axis_binding": "source_axis",
                    "g2_mapping": "g2",
                    "environment_closure": "environment",
                    "atomic_bundle": "r3",
                }.get(stage, stage))
                result["input_sha256"] = _digest(section if section is not None else {"stage": stage, "input": None})
            if "output_sha256" not in result:
                result["output_sha256"] = _digest(result)
            result.setdefault("formal_credit", FORMAL_CREDIT)
            result.setdefault("authority_credit", AUTHORITY_CREDIT)
            result.setdefault("no_publish", NO_PUBLISH)
            stages[stage] = result
        return merge_stage_results(stages, request=request)


def orchestrate(request: Mapping[str, Any] | None = None, **kwargs: Any) -> dict[str, Any]:
    """Functional entry point for the offline orchestrator."""
    return OfflineIntegrationOrchestrator(**kwargs).run(request)


integrate = orchestrate
