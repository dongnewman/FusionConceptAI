"""Independent adversarial retest for the repaired cross-stage binding seam.

This file deliberately calls only the public merge seam.  It reproduces the
old A/B shape (one value in one receipt and a foreign value nested in another)
without relying on the implementation's private collectors.
"""

from __future__ import annotations

import copy
from typing import Any

import pytest

from tools.up1_external_closure_r4.integration.orchestrator import (
    STAGE_ORDER,
    OfflineIntegrationOrchestrator,
    merge_stage_results,
)


_TUPLE_FIELDS = (
    "candidate_id",
    "source_identity_digest",
    "run_id",
    "request_id",
    "bundle_id",
    "raw_sha256",
    "bundle_canonical_sha256",
    "packet_digests",
    "quarantine_locator",
    "quarantine_transaction_id",
    "nonce",
    "sequence",
    "idempotency_key",
    "scope",
    "result_digest",
)

_BASE = {
    "candidate_id": "candidate://ab-a",
    "source_identity_digest": "1" * 64,
    "run_id": "run-ab-a",
    "request_id": "request-ab-a",
    "bundle_id": "bundle-ab-a",
    "raw_sha256": "2" * 64,
    "bundle_canonical_sha256": "3" * 64,
    "packet_digests": ["4" * 64, "5" * 64],
    "quarantine_locator": "cas://ab-a/raw",
    "quarantine_transaction_id": "qtx-ab-a",
    "nonce": "nonce-ab-a",
    "sequence": 17,
    "idempotency_key": "idem-ab-a",
    "scope": {"scope_marker": "scope-a"},
    "result_digest": "6" * 64,
}

_ALIASES = {
    "quarantine_locator": "cas_path",
    "quarantine_transaction_id": "cas_transaction_id",
    "result_digest": "canonical_receipt_digest",
}


def _stage(name: str, *, binding: dict[str, Any] | None = None, nested: dict[str, Any] | None = None) -> dict[str, Any]:
    row: dict[str, Any] = {
        "schema": f"independent.{name}.v1",
        "stage": name,
        "status": "unverified",
        "decision": "accepted_all",
        "formal_credit": "none",
        "authority_credit": False,
        "no_publish": True,
        "input_sha256": "a" * 64,
        "output_sha256": "b" * 64,
        "receipt_ref": f"receipt://{name}/ab-a",
        "raw_receipt": {"opaque": f"raw-{name}"},
    }
    if binding:
        row["binding"] = binding
    if nested:
        row["receipt"] = {"ack": {"binding": nested}}
    return row


def _stages(*, nested_conflict: tuple[str, Any] | None = None) -> dict[str, dict[str, Any]]:
    rows = {name: _stage(name) for name in STAGE_ORDER}
    rows["atomic_bundle"] = _stage("atomic_bundle", binding=copy.deepcopy(_BASE))
    if nested_conflict is not None:
        field, value = nested_conflict
        key = _ALIASES.get(field, field)
        rows["freshness"] = _stage("freshness", nested={key: value})
    return rows


@pytest.mark.parametrize("field", _TUPLE_FIELDS)
def test_every_binding_tuple_field_conflict_is_hard_and_unset(field: str):
    """The old A/B conflict must never become first-value-wins."""
    foreign = copy.deepcopy(_BASE[field])
    if isinstance(foreign, list):
        foreign = ["f" * 64]
    elif isinstance(foreign, dict):
        foreign = {"scope_marker": "scope-b"}
    elif isinstance(foreign, int):
        foreign = foreign + 1
    elif isinstance(foreign, str) and len(foreign) == 64:
        foreign = "f" * 64
    else:
        foreign = f"{foreign}-foreign"

    result = merge_stage_results(_stages(nested_conflict=(field, foreign)), request={})

    assert result["status"] == "fail_closed"
    assert result["decision"] == "rejected_all"
    assert result["accepted_all"] is False
    assert "BINDING_CONFLICT" in result["failure_codes"]
    assert {"atomic_bundle", "freshness"}.issubset(result["binding_conflict_stages"])
    assert result["stages"]["atomic_bundle"]["raw_receipt"] == {"opaque": "raw-atomic_bundle"}
    assert result["stages"]["freshness"]["raw_receipt"] == {"opaque": "raw-freshness"}
    assert result["receipt_refs"]["atomic_bundle"]
    assert result["receipt_refs"]["freshness"]
    assert all(len(result["stage_hashes"][name]["receipt_sha256"]) == 64 for name in STAGE_ORDER)
    assert result["binding"][field] is None


def test_original_ab_conflict_is_detected_when_foreign_value_is_nested():
    rows = _stages(nested_conflict=("candidate_id", "candidate://ab-b"))
    rows["freshness"]["receipt"]["ack"]["binding"]["raw_receipt"] = {"opaque": "must-stay-raw"}
    result = merge_stage_results(rows, request={})

    assert result["binding"]["candidate_id"] is None
    assert result["binding_conflicts"][0]["field"] == "candidate_id"
    assert result["stages"]["freshness"]["receipt"]["ack"]["binding"]["raw_receipt"] == {
        "opaque": "must-stay-raw"
    }


def test_missing_and_unknown_stage_are_hard_contract_failures():
    rows = _stages()
    rows.pop("freshness")
    rows["invented_stage"] = _stage("invented_stage")
    result = merge_stage_results(rows, request={})

    assert result["status"] == "fail_closed"
    assert result["decision"] == "rejected_all"
    assert result["accepted_all"] is False
    assert result["missing_stages"] == ["freshness"]
    assert result["unknown_stages"] == ["invented_stage"]
    assert "MISSING_REQUIRED_STAGE" in result["failure_codes"]
    assert "UNKNOWN_STAGE" in result["failure_codes"]
    assert result["stages"]["invented_stage"]["raw_receipt"] == {"opaque": "raw-invented_stage"}


def test_empty_run_has_all_seven_typed_absent_stages_and_is_deferred(tmp_path):
    result = OfflineIntegrationOrchestrator(quarantine_root=tmp_path).run({})

    assert list(result["stages"]) == list(STAGE_ORDER)
    assert result["status"] == "terminal_deferred"
    assert result["decision"] == "terminal_deferred"
    assert result["accepted_all"] is False
    assert result["missing_stages"] == []
    assert result["unknown_stages"] == []
    assert all(row["status"] == "typed_absent" for row in result["stages"].values())
    assert result["t0_executed"] is False
    assert result["s3_executed"] is False
    assert result["network_access"] is False
    assert result["runtime_execution"] is False
