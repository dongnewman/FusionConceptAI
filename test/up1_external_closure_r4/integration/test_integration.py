from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path

import pytest

from tools.up1_external_closure_r4.integration import orchestrator as impl
from tools.up1_external_closure_r4.integration.orchestrator import (
    STAGE_ORDER,
    OfflineIntegrationOrchestrator,
    merge_stage_results,
)


CONTRACT_ORDER = (
    "atomic_bundle",
    "authoritative_intake",
    "source_axis_binding",
    "g2_mapping",
    "environment_closure",
    "trust_chain",
    "freshness",
)


def _request(root: Path) -> dict:
    return {
        "request_id": "request-integration-01",
        "scope": {
            "candidate_id": "candidate://integration-01",
            "source_identity_digest": "a" * 64,
            "run_id": "run-integration-01",
            "bundle_id": "bundle-integration-01",
            "nonce": "nonce-integration-01",
            "sequence": 1,
            "idempotency_key": "idem-integration-01",
        },
        "authoritative_intake": {
            "packets": [{"packet_id": f"EHP-0{i}"} for i in range(1, 5)],
            "channel_id": "injected-test-channel",
        },
        "trust_chain": {"root": b"pinned-root", "profile": "TEST_ONLY"},
        "freshness": {"payload": {"nonce": "nonce-integration-01", "sequence": 1}},
        "source_axis_binding": {
            "bundle": {
                "state": "EXTERNAL_ISSUED",
                "provenance_class": "external_issued",
                "candidate_id": "candidate://integration-01",
            },
            "observed_source_identity": {"digest": "a" * 64},
        },
        "g2_mapping": {"profile": {"candidate_id": "candidate://integration-01"}},
        "environment_closure": {"root": str(root), "probe_versions": False},
        "atomic_bundle": {
            "raw_utf8": b'{"schema":"TEST_ONLY"}',
            "context": {"candidate_id": "candidate://integration-01"},
            "quarantine_root": str(root),
        },
    }


def _stage_result(stage: str, status: str = "unverified", **extra) -> dict:
    return {
        "schema": f"fake.{stage}.v1",
        "stage": stage,
        "status": status,
        "decision": "accepted_all" if status in {"unverified", "TEST_ONLY", "local_observed"} else status,
        "candidate_id": "candidate://integration-01",
        "source_identity_digest": "a" * 64,
        "run_id": "run-integration-01",
        "request_id": "request-integration-01",
        "bundle_id": "bundle-integration-01",
        "raw_sha256": hashlib.sha256(b'{"schema":"TEST_ONLY"}').hexdigest(),
        "bundle_canonical_sha256": "b" * 64,
        "packet_digests": ["c" * 64 + str(i) for i in range(4)],
        "quarantine_locator": "cas://integration-01/raw",
        "quarantine_transaction_id": "qtx-integration-01",
        "nonce": "nonce-integration-01",
        "sequence": 1,
        "idempotency_key": "idem-integration-01",
        "receipt_ref": f"receipt://{stage}/integration-01",
        "formal_credit": "none",
        "authority_credit": False,
        "no_publish": True,
        **extra,
    }


def _wired(root: Path, trace: list[str], *, status: str = "unverified", overrides=None):
    overrides = overrides or {}
    adapters = {}
    for stage in STAGE_ORDER:
        if stage == "authoritative_intake":
            continue

        def make(stage_name):
            def adapter(*args, **kwargs):
                trace.append(stage_name)
                value = _stage_result(stage_name, status=status)
                value.update(overrides.get(stage_name, {}))
                return value

            return adapter

        adapters[stage] = make(stage)

    def intake(packets, **kwargs):
        trace.append("authoritative_intake")
        value = _stage_result("authoritative_intake", status=status)
        value.update(overrides.get("authoritative_intake", {}))
        return value

    return OfflineIntegrationOrchestrator(intake=intake, adapters=adapters), _request(root)


def test_seven_stage_order_is_explicit_and_single_pass(tmp_path):
    trace: list[str] = []
    runner, request = _wired(tmp_path, trace)
    result = runner.run(request)
    assert tuple(STAGE_ORDER) == (
        "atomic_bundle",
        "authoritative_intake",
        "source_axis_binding",
        "g2_mapping",
        "environment_closure",
        "trust_chain",
        "freshness",
    )
    assert trace == list(STAGE_ORDER)
    assert list(result["stages"]) == list(STAGE_ORDER)
    assert result["accepted_all"] is False


def test_contract_matrix_order_matches_implementation():
    assert tuple(STAGE_ORDER) == CONTRACT_ORDER


def test_empty_and_missing_inputs_are_typed_absent_and_terminal_deferred(tmp_path):
    trace: list[str] = []
    runner, _ = _wired(tmp_path, trace)
    result = runner.run({})
    assert result["status"] == "terminal_deferred"
    assert result["decision"] == "terminal_deferred"
    assert result["accepted_all"] is False
    assert all(row["status"] == "typed_absent" for row in result["stages"].values())
    assert trace == []
    assert result["formal_credit"] == "none"
    assert result["authority_credit"] is False
    assert result["no_publish"] is True
    assert result["t0_executed"] is False
    assert result["s3_executed"] is False
    assert result["network_access"] is False
    assert result["runtime_execution"] is False


def test_typed_priority_hard_failure_dominates_absent_and_unverified():
    stages = {
        "authoritative_intake": _stage_result("authoritative_intake", "typed_absent"),
        "trust_chain": _stage_result("trust_chain", "unverified"),
        "freshness": _stage_result("freshness", "invalid", failure_codes=["DIGEST_MISMATCH"]),
        "source_axis_binding": _stage_result("source_axis_binding", "typed_absent"),
        "g2_mapping": _stage_result("g2_mapping", "unverified"),
        "environment_closure": _stage_result("environment_closure", "typed_absent"),
        "atomic_bundle": _stage_result("atomic_bundle", "unverified"),
    }
    result = merge_stage_results(stages, request={"scope": {"candidate_id": "candidate://integration-01"}})
    assert result["status"] == "fail_closed"
    assert result["decision"] == "rejected_all"
    assert result["failure_stages"] == ["freshness"]
    assert result["classification"] == "integrity_failure"
    assert result["accepted_all"] is False


def test_all_or_reject_preserves_stage_receipts_hashes_and_binding_tuple(tmp_path):
    trace: list[str] = []
    runner, request = _wired(tmp_path, trace, overrides={"g2_mapping": {"status": "invalid", "failure_codes": ["G2_BIJECTION_FAILURE"]}})
    result = runner.run(request)
    assert result["status"] == "fail_closed"
    assert result["decision"] == "rejected_all"
    assert result["accepted_all"] is False
    assert set(result["failure_stages"]) == {"g2_mapping"}
    for stage in STAGE_ORDER:
        row = result["stages"][stage]
        assert isinstance(row.get("input_sha256"), str) and len(row["input_sha256"]) == 64
        assert isinstance(row.get("output_sha256"), str) and len(row["output_sha256"]) == 64
        receipt = result["stage_hashes"][stage]
        assert receipt["input_sha256"] == row["input_sha256"]
        assert len(receipt["output_sha256"]) == 64
        assert len(receipt["receipt_sha256"]) == 64
        assert result["receipt_refs"][stage]
    binding = result["binding"]
    for key in (
        "candidate_id", "source_identity_digest", "run_id", "request_id", "bundle_id",
        "raw_sha256", "bundle_canonical_sha256", "packet_digests", "quarantine_locator",
        "quarantine_transaction_id", "nonce", "sequence", "idempotency_key", "scope",
        "result_digest",
    ):
        assert key in binding
    assert binding["candidate_id"] == request["scope"]["candidate_id"]
    assert binding["request_id"] == request["request_id"]
    assert binding["scope"] == request["scope"]


def test_adapter_exception_is_typed_program_exception_and_fail_closed(tmp_path):
    trace: list[str] = []

    def exploding(*args, **kwargs):
        trace.append("trust_chain")
        raise RuntimeError("injected adapter fault")

    runner, request = _wired(tmp_path, trace)
    runner.adapters["trust_chain"] = exploding
    result = runner.run(request)
    row = result["stages"]["trust_chain"]
    assert row["status"] == "typed_program_exception"
    assert row["decision"] == "fail_closed"
    assert "PROGRAM_EXCEPTION" in row["failure_codes"]
    assert result["status"] == "fail_closed"
    assert result["decision"] == "rejected_all"
    assert result["no_publish"] is True


@pytest.mark.parametrize("status", ["TEST_ONLY", "local_observed", "unverified", "EXTERNAL_ISSUED", "externally_verified"])
def test_local_test_only_unverified_and_raw_external_labels_never_upgrade(tmp_path, status):
    trace: list[str] = []
    runner, request = _wired(tmp_path, trace, status=status)
    result = runner.run(request)
    assert result["status"] == "terminal_deferred"
    assert result["decision"] == "terminal_deferred"
    assert result["formal_credit"] == "none"
    assert result["authority_credit"] is False
    assert result["no_publish"] is True
    assert all(value == "terminal_deferred" for value in result["normalized_stages"].values())
    assert not any(row.get("authority_evidence") is True for row in result["stages"].values())


def test_publication_and_authority_locks_are_hard_and_report_attempted_values(tmp_path):
    trace: list[str] = []
    runner, request = _wired(
        tmp_path,
        trace,
        overrides={"freshness": {"formal_credit": "T1", "authority_credit": True, "no_publish": False}},
    )
    result = runner.run(request)
    row = result["stages"]["freshness"]
    assert result["status"] == "fail_closed"
    assert result["decision"] == "rejected_all"
    assert "PUBLICATION_LOCK" in row["failure_codes"]
    assert row["reported_formal_credit"] == "T1"
    assert row["reported_authority_credit"] is True
    assert row["reported_no_publish"] is False
    assert row["formal_credit"] == "none"
    assert row["authority_credit"] is False
    assert row["no_publish"] is True
    assert result["formal_credit"] == "none"
    assert result["authority_credit"] is False
    assert result["no_publish"] is True


def test_forbidden_environment_probe_is_typed_exception_without_network_or_heavy_lane(tmp_path):
    trace: list[str] = []
    runner, request = _wired(tmp_path, trace)
    request["environment_closure"]["network"] = True
    result = runner.run(request)
    row = result["stages"]["environment_closure"]
    assert row["status"] == "typed_program_exception"
    assert row["decision"] == "fail_closed"
    assert result["status"] == "fail_closed"
    assert result["network_access"] is False
    assert result["t0_executed"] is False
    assert result["s3_executed"] is False
    assert result["runtime_execution"] is False


def test_serial_double_run_is_semantically_identical_and_adversarial_non_mapping_is_closed(tmp_path):
    trace_a: list[str] = []
    first_runner, request = _wired(tmp_path, trace_a)
    first = first_runner.run(copy.deepcopy(request))
    trace_b: list[str] = []
    second_runner, _ = _wired(tmp_path, trace_b)
    second = second_runner.run(copy.deepcopy(request))
    assert first == second
    assert trace_a == trace_b == list(STAGE_ORDER)

    trace_c: list[str] = []
    adversarial, bad_request = _wired(tmp_path, trace_c)
    adversarial.adapters["g2_mapping"] = lambda *args, **kwargs: "not-a-mapping"
    bad = adversarial.run(bad_request)
    assert bad["stages"]["g2_mapping"]["status"] == "typed_program_exception"
    assert bad["status"] == "fail_closed"
    assert bad["decision"] == "rejected_all"


def test_raw_bytes_are_passed_unchanged_to_atomic_adapter_and_no_heavy_imports_are_needed(tmp_path):
    seen: list[bytes] = []
    trace: list[str] = []
    runner, request = _wired(tmp_path, trace)

    def atomic(raw, context, quarantine_root):
        trace.append("atomic_bundle")
        seen.append(raw)
        assert isinstance(raw, bytes)
        assert context == request["atomic_bundle"]["context"]
        assert str(quarantine_root) == request["atomic_bundle"]["quarantine_root"]
        return _stage_result("atomic_bundle")

    runner.adapters["atomic_bundle"] = atomic
    runner.run(request)
    assert seen == [request["atomic_bundle"]["raw_utf8"]]
