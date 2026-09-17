"""Independent adversarial checks for the R2 revocation/time/replay fixture.

This harness is TEST_ONLY/non_evidence.  It deliberately constructs its own
fixture and reports observed classifications; it does not import the author's
test module or use an expected-error table to route validation.
"""
from __future__ import annotations

import datetime as dt
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
MODULE = ROOT / "tools" / "up1_external_closure_r2" / "revocation_time_replay"
sys.path.insert(0, str(MODULE))
from core import canonical_digest, validate  # noqa: E402

ASOF = "2026-09-17T12:00:00Z"


def fixture() -> dict:
    receipt = {
        "verification_id": "v-001", "nonce": "nonce-001", "challenge": "challenge-001",
        "scope": {"candidate": "c-001", "source": "attestor-A"}, "source": "attestor-A",
        "source_version": {"version": "source-v1", "hash": "abc123"}, "sequence": 4,
        "issued_at": "2026-09-17T11:59:00Z", "expires_at": "2026-09-17T12:10:00Z",
        "idempotency_key": "idem-001", "payload": {"value": 3},
    }
    digest = canonical_digest(receipt)
    return {
        "schema": "UP1-R2.revocation-time-replay.v1", "profile": "TEST_ONLY-W2-R1",
        "test_only": True, "receipt": receipt, "receipt_signature_valid": True,
        "clock_skew_seconds": 2,
        "replay_window": {"duration_seconds": 3600, "trusted_time_basis": "signed_receipt"},
        "trusted_time_receipt": {
            "profile": "rfc3161", "gen_time": ASOF, "receipt_digest": digest,
            "message_imprint": digest, "nonce": "nonce-001", "policy": "TEST_ONLY-TSA",
            "signature_valid": True, "chain_valid": True, "revocation_valid": True,
        },
        "revocation_receipt": {
            "kind": "crl", "status": "good", "issuer": "CA-TEST_ONLY", "serial": "7",
            "this_update": "2026-09-17T11:00:00Z", "next_update": "2026-09-17T13:00:00Z",
            "signature_valid": True, "issuer_binding_valid": True,
        },
        "replay_cache_snapshot": {"nonces": {}, "sequences": {}, "idempotency": {}, "entries": []},
    }


def refresh(payload: dict) -> None:
    digest = canonical_digest(payload["receipt"])
    payload["trusted_time_receipt"]["receipt_digest"] = digest
    payload["trusted_time_receipt"]["message_imprint"] = digest


def observed(name: str, payload: dict) -> dict:
    result = validate(payload)
    return {"case": name, "result": result.get("result"), "status": result.get("status"),
            "error_code": result.get("error_code")}


def main() -> int:
    rows = []
    payload = fixture(); payload["unknown_top"] = 1; payload["receipt"]["unknown_nested"] = 2; refresh(payload)
    rows.append(observed("TM15_unknown_top_and_nested_accepted", payload))
    payload = fixture(); payload["test_only"] = "false"; payload["profile"] = "TEST_ONLY-EVIL"
    rows.append(observed("TM06_nonboolean_test_only_and_prefix_accepted", payload))
    payload = fixture(); payload["replay_window"]["duration_seconds"] = float("nan")
    rows.append(observed("TM08_nan_replay_window_accepted", payload))
    payload = fixture(); payload["replay_window"]["duration_seconds"] = float("inf")
    rows.append(observed("TM08_inf_replay_window_accepted", payload))
    payload = fixture(); payload["revocation_receipt"].pop("status")
    rows.append(observed("TM07_missing_revocation_status_fail_closed", payload))
    payload = fixture(); payload["trusted_time_receipt"]["valid_to"] = "not-a-time"
    rows.append(observed("TM08_malformed_optional_time_accepted", payload))
    payload = fixture(); payload["receipt"]["source_version"] = 0; refresh(payload)
    rows.append(observed("TM02_wrong_source_version_type_accepted", payload))
    payload = fixture(); payload["receipt"]["source"] = 123; refresh(payload)
    rows.append(observed("TM03_wrong_source_type_accepted", payload))
    payload = fixture(); payload["replay_cache_snapshot"]["entries"] = [{"scope": "evil", "nonce": "nonce-001", "sequence": 999}]
    rows.append(observed("TM09_inconsistent_entries_ignored", payload))
    payload = fixture(); payload["replay_cache_snapshot"]["sequences"] = {"{\"candidate\":\"c-001\",\"source\":\"attestor-A\"}": 1}; payload["receipt"]["sequence"] = 100; refresh(payload)
    rows.append(observed("TM10_sequence_gap_accepted", payload))
    cli = MODULE / "cli.py"
    raw = json.dumps(fixture(), separators=(",", ":"))
    replay = []
    for _ in range(2):
        proc = subprocess.run([sys.executable, "-B", str(cli)], input=raw, text=True, capture_output=True)
        output = json.loads(proc.stdout)
        replay.append({"exit": proc.returncode, "result": output.get("result"), "status": output.get("status"), "error_code": output.get("error_code")})
    rows.append({"case": "TM09_two_process_replay_with_reset_snapshot", "observed": replay})
    payload = fixture(); digest = canonical_digest(payload["receipt"]); payload["trusted_time_receipt"]["receipt_digest"] = digest; payload["trusted_time_receipt"]["message_imprint"] = digest
    raw = json.dumps(payload, separators=(",", ":")).replace('"sequence":4,"issued_at"', '"sequence":999,"sequence":4,"issued_at"', 1)
    proc = subprocess.run([sys.executable, "-B", str(cli)], input=raw, text=True, capture_output=True)
    output = json.loads(proc.stdout)
    rows.append({"case": "TM15_duplicate_sequence_json_accepted", "observed": {"exit": proc.returncode, "result": output.get("result"), "error_code": output.get("error_code")}})
    print(json.dumps({"TEST_ONLY": True, "non_evidence": True, "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "pid": os.getpid(), "parent_pid": os.getppid(), "rows": rows}, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
