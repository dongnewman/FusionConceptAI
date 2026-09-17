from __future__ import annotations

import json
import hashlib
import hmac
import os
import pathlib
import subprocess
import sys
import pytest

ROOT = pathlib.Path(__file__).resolve().parents[3]
MODULE = ROOT / "tools" / "up1_external_closure_r2" / "revocation_time_replay"
sys.path.insert(0, str(MODULE))
import core as core_module  # noqa: E402
from core import PersistentReplayLedger, ReceiptInputError, canonical_bytes, canonical_digest, evaluate_windows_acl, parse_json_strict, validate  # noqa: E402

ASOF = "2026-09-17T12:00:00Z"

def ledger_for(tmp_path, name="ledger.json"):
    keydir = tmp_path / "trusted-keys"
    keydir.mkdir(exist_ok=True)
    key = keydir / "fixture.key"
    if not key.exists():
        key.write_bytes(bytes(range(32)))
    return PersistentReplayLedger(tmp_path / name, key_path=key)


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
        "schema": "UP1-R2.revocation-time-replay.v1", "profile": "TEST_ONLY-W2-R1", "test_only": True,
        "receipt": receipt, "receipt_signature_valid": True, "clock_skew_seconds": 2,
        "replay_window": {"duration_seconds": 3600, "trusted_time_basis": "signed_receipt", "ledger_retention_seconds": 7200},
        "trusted_time_receipt": {"available": True, "profile": "rfc3161", "gen_time": ASOF, "receipt_digest": digest, "message_imprint": digest, "nonce": "nonce-001", "policy": "TEST_ONLY-TSA", "signature_valid": True, "chain_valid": True, "revocation_valid": True},
        "revocation_receipt": {"available": True, "kind": "crl", "status": "good", "issuer": "CA-TEST_ONLY", "serial": "7", "certificate_serial": "7", "crl_number": "1", "this_update": "2026-09-17T11:00:00Z", "next_update": "2026-09-17T13:00:00Z", "signature_valid": True, "issuer_binding_valid": True},
    }


def refresh(payload: dict) -> None:
    digest = canonical_digest(payload["receipt"])
    payload["trusted_time_receipt"]["receipt_digest"] = digest
    payload["trusted_time_receipt"]["message_imprint"] = digest
    payload["trusted_time_receipt"]["nonce"] = payload["receipt"]["nonce"]
    payload["trusted_time_receipt"]["challenge"] = payload["receipt"]["challenge"]


def test_positive_and_durable_commit(tmp_path):
    result = validate(fixture(), ledger=ledger_for(tmp_path))
    assert result["result"] == "valid_for_declared_scope"
    assert result["replay_ledger"]["state_hash"]
    assert result["replay_ledger"]["auth_tag"]


def test_external_unavailable_is_typed_absence(tmp_path):
    for field, code in (("revocation_receipt", "revocation_status_unavailable"), ("trusted_time_receipt", "trusted_time_absent")):
        payload = fixture(); payload[field] = {"available": False}
        result = validate(payload, ledger=ledger_for(tmp_path, field + ".json"))
        assert result["result"] == "typed_absent" and result["resolution"] == "terminal_deferred" and result["error_code"] == code
    result = validate(fixture())
    assert result["error_code"] == "replay_ledger_absent"


def test_revoked_stale_unknown_and_invalid_fail_closed(tmp_path):
    for mutation, code in (({"status": "revoked"}, "certificate_revoked"), ({"next_update": "2026-09-17T11:59:00Z"}, "revocation_response_stale"), ({"status": "unknown"}, "revocation_status_unknown"), ({"signature_valid": False}, "certificate_signature_invalid")):
        payload = fixture(); payload["revocation_receipt"].update(mutation)
        assert validate(payload, ledger=ledger_for(tmp_path, code + ".json"))["error_code"] == code


def test_durable_two_process_only_one_valid(tmp_path):
    cli = MODULE / "cli.py"
    ledger = tmp_path / "shared-ledger.json"
    keydir = tmp_path / "trusted-keys"; keydir.mkdir(); key = keydir / "fixture.key"; key.write_bytes(bytes(range(32)))
    raw = json.dumps(fixture(), separators=(",", ":"))
    procs = [subprocess.Popen([sys.executable, "-B", str(cli), "--ledger", str(ledger), "--key", str(key)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(2)]
    results = []
    for proc in procs:
        stdout, stderr = proc.communicate(raw)
        results.append((proc.returncode, json.loads(stdout)))
    assert sum(x[0] == 0 for x in results) == 1
    assert any(x[1]["error_code"] == "nonce_replayed" for x in results)
    tampered = json.loads(ledger.read_text(encoding="utf-8")); tampered["state"]["nonces"] = {}; ledger.write_text(json.dumps(tampered), encoding="utf-8")
    proc = subprocess.run([sys.executable, "-B", str(cli), "--ledger", str(ledger), "--key", str(key)], input=raw, text=True, capture_output=True, check=False)
    assert json.loads(proc.stdout)["error_code"] == "ledger_corrupt"


def test_strict_profile_types_duplicates_unknown_and_nonfinite(tmp_path):
    ledger = ledger_for(tmp_path)
    for field, value in (("test_only", "false"), ("profile", "TEST_ONLY-EVIL"), ("source", 123), ("source_version", 0)):
        payload = fixture()
        if field in ("source", "source_version"):
            payload["receipt"][field] = value
        else:
            payload[field] = value
        refresh(payload) if field in ("source", "source_version") else None
        assert validate(payload, ledger=ledger_for(tmp_path, field + ".json"))["result"] == "fail_closed"
    payload = fixture(); payload["replay_window"]["duration_seconds"] = float("nan")
    assert validate(payload, ledger=ledger_for(tmp_path, "nan.json"))["error_code"] == "replay_window_invalid"
    payload = fixture(); payload["receipt"]["unknown_nested"] = 1
    assert validate(payload, ledger=ledger_for(tmp_path, "unknown.json"))["error_code"] == "unknown_field"
    with pytest.raises(Exception):
        parse_json_strict('{"a":1,"a":2}')
    with pytest.raises(Exception):
        parse_json_strict('{"a":NaN}')


def test_sequence_gap_idempotency_scope_and_optional_time(tmp_path):
    ledger = ledger_for(tmp_path)
    first = validate(fixture(), ledger=ledger); assert first["result"] == "valid_for_declared_scope"
    payload = fixture(); payload["receipt"]["nonce"] = "new"; payload["receipt"]["idempotency_key"] = "new"; payload["receipt"]["sequence"] = 100; refresh(payload)
    assert validate(payload, ledger=ledger)["error_code"] == "sequence_gap"
    payload = fixture(); payload["trusted_time_receipt"]["valid_to"] = "not-a-time"
    assert validate(payload, ledger=ledger_for(tmp_path, "badtime.json"))["error_code"] == "timestamp_invalid"


def test_r2_authenticated_global_ledger_semantics_and_explicit_key(tmp_path):
    ledger = ledger_for(tmp_path)
    assert validate(fixture(), ledger=ledger)["result"] == "valid_for_declared_scope"
    envelope = json.loads(ledger.path.read_text(encoding="utf-8"))
    envelope["state"]["entries"].append(dict(envelope["state"]["entries"][0]))
    envelope["state_hash"] = hashlib.sha256(canonical_bytes(envelope["state"])).hexdigest()
    base = {k: envelope[k] for k in ("schema", "version", "namespace", "state", "state_hash")}
    envelope["auth_tag"] = hmac.new(bytes(range(32)), canonical_bytes(base), hashlib.sha256).hexdigest()
    ledger.path.write_text(json.dumps(envelope), encoding="utf-8")
    result = validate(fixture(), ledger=ledger)
    assert result["result"] == "fail_closed" and result["error_code"] == "ledger_corrupt"
    missing = validate(fixture(), ledger=PersistentReplayLedger(tmp_path / "missing-key.json"))
    assert missing["error_code"] == "replay_ledger_absent" and missing["result"] == "typed_absent" and missing["no_publish"] is True


def test_r2_nested_closed_types_and_cli_input_errors(tmp_path):
    payload = fixture()
    payload["revocation_receipt"]["available"] = "true"
    assert validate(payload, ledger=ledger_for(tmp_path, "bad-available.json"))["error_code"] == "revocation_status_invalid"
    payload = fixture()
    payload["revocation_receipt"]["future_field"] = 1
    assert validate(payload, ledger=ledger_for(tmp_path, "bad-nested.json"))["error_code"] == "unknown_field"
    cli = MODULE / "cli.py"
    keydir = tmp_path / "cli-key"; keydir.mkdir(); key = keydir / "trusted.key"; key.write_bytes(bytes(range(32)))
    proc = subprocess.run([sys.executable, "-B", str(cli), "--ledger", str(tmp_path / "cli-ledger.json"), "--key", str(key)], input='{"schema":1,"schema":2}', text=True, capture_output=True, check=False)
    parsed = json.loads(proc.stdout)
    assert proc.returncode == 2 and parsed["error_code"] == "duplicate_field" and parsed["status"] == "fail_closed"
    proc = subprocess.run([sys.executable, "-B", str(cli), "--ledger", str(tmp_path / "cli-ledger-2.json"), "--key", str(key)], input='{"clock_skew_seconds":NaN}', text=True, capture_output=True, check=False)
    assert proc.returncode == 2 and json.loads(proc.stdout)["error_code"] == "nonfinite_number"


def test_r2_trusted_key_symlink_is_rejected(tmp_path):
    target = tmp_path / "trusted.key"; target.write_bytes(bytes(range(32)))
    link = tmp_path / "trusted-link.key"
    try:
        os.symlink(target, link)
    except (OSError, NotImplementedError):
        pytest.skip("symlink creation unavailable in this fixture environment")
    result = validate(fixture(), ledger=PersistentReplayLedger(tmp_path / "ledger.json", key_path=link))
    assert result["result"] == "fail_closed" and result["error_code"] == "ledger_corrupt"


def test_r3_windows_acl_wide_denied_and_restricted_key_passes(tmp_path):
    if os.name != "nt":
        pytest.skip("Windows ACL regression")
    keydir = tmp_path / "acl-keys"; keydir.mkdir(); key = keydir / "trusted.key"; key.write_bytes(bytes(range(32)))
    restricted = validate(fixture(), ledger=PersistentReplayLedger(tmp_path / "restricted.json", key_path=key))
    assert restricted["result"] == "valid_for_declared_scope"
    changed = subprocess.run(["icacls", str(key), "/grant", "*S-1-1-0:R"], capture_output=True, text=True, check=False)
    if changed.returncode != 0:
        pytest.skip("icacls ACL mutation unavailable")
    wide = validate(fixture(), ledger=PersistentReplayLedger(tmp_path / "wide.json", key_path=key))
    assert wide["result"] == "fail_closed" and wide["error_code"] == "trusted_key_acl_invalid"


def test_r3_parent_junction_reparse_escape_is_rejected(tmp_path):
    if os.name != "nt":
        pytest.skip("Windows Junction regression")
    real = tmp_path / "real"; real.mkdir(); key = real / "trusted.key"; key.write_bytes(bytes(range(32)))
    junction = tmp_path / "junction"
    created = subprocess.run(["cmd", "/c", "mklink", "/J", str(junction), str(real)], capture_output=True, text=True, check=False)
    if created.returncode != 0:
        pytest.skip("Junction creation unavailable")
    escaped = validate(fixture(), ledger=PersistentReplayLedger(tmp_path / "junction-ledger.json", key_path=junction / "trusted.key"))
    assert escaped["result"] == "fail_closed" and escaped["error_code"] == "ledger_corrupt"


def test_r3_acl_verifier_unavailable_never_validates(tmp_path, monkeypatch):
    if os.name != "nt":
        pytest.skip("Windows ACL verifier regression")
    keydir = tmp_path / "unsupported-key"; keydir.mkdir(); key = keydir / "trusted.key"; key.write_bytes(bytes(range(32)))
    monkeypatch.setattr(core_module.shutil, "which", lambda _name: None)
    result = validate(fixture(), ledger=PersistentReplayLedger(tmp_path / "unsupported.json", key_path=key))
    assert result["result"] == "typed_absent" and result["error_code"] == "trusted_key_acl_unsupported"


def test_r4_foreign_owner_sid_is_fail_closed():
    foreign = {"owner": "NT AUTHORITY\\NETWORK SERVICE", "owner_sid": "S-1-5-20", "current_sid": "S-1-5-21-1-2-3-4", "owner_ok": False, "sddl": "O:S-1-5-20D:(A;;FA;;;SY)", "protected": True, "bad_allow_identities": [], "access_rules": []}
    with pytest.raises(ReceiptInputError) as exc:
        evaluate_windows_acl(foreign)
    assert exc.value.code == "trusted_key_acl_invalid"


def test_r4_injected_acl_provider_malformed_and_unsupported(tmp_path):
    keydir = tmp_path / "provider-key"; keydir.mkdir(); key = keydir / "trusted.key"; key.write_bytes(bytes(range(32)))
    malformed = validate(fixture(), ledger=PersistentReplayLedger(tmp_path / "malformed.json", key_path=key, acl_provider=lambda _path: {"owner_sid": "not-a-sid"}))
    assert malformed["result"] == "fail_closed" and malformed["error_code"] == "trusted_key_acl_invalid"
    unsupported = validate(fixture(), ledger=PersistentReplayLedger(tmp_path / "unsupported.json", key_path=key, acl_provider=lambda _path: (_ for _ in ()).throw(ReceiptInputError("provider unavailable", "trusted_key_acl_unsupported"))))
    assert unsupported["result"] == "typed_absent" and unsupported["error_code"] == "trusted_key_acl_unsupported"


if __name__ == "__main__":
    import pytest
    raise SystemExit(pytest.main([__file__, "-q"]))
