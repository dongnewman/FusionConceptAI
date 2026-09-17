"""Independent R2 attack checks; TEST_ONLY/non_evidence only."""
from __future__ import annotations
import json, os, subprocess, sys, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[5]
MODULE = ROOT / "tools" / "up1_external_closure_r2" / "revocation_time_replay"
sys.path.insert(0, str(MODULE))
from core import PersistentReplayLedger, canonical_digest, parse_json_strict, validate, _state_hash  # noqa: E402

ASOF = "2026-09-17T12:00:00Z"

def fixture(seq=1, nonce="nonce-001", idem="idem-001"):
    receipt = {"verification_id": "v-001", "nonce": nonce, "challenge": "challenge-001", "scope": {"candidate": "c-001", "source": "attestor-A"}, "source": "attestor-A", "source_version": {"version": "source-v1", "hash": "abc123"}, "sequence": seq, "issued_at": "2026-09-17T11:59:00Z", "expires_at": "2026-09-17T12:10:00Z", "idempotency_key": idem, "payload": {"value": 3}}
    d = canonical_digest(receipt)
    return {"schema": "UP1-R2.revocation-time-replay.v1", "profile": "TEST_ONLY-W2-R1", "test_only": True, "receipt": receipt, "receipt_signature_valid": True, "clock_skew_seconds": 2, "replay_window": {"duration_seconds": 3600, "trusted_time_basis": "signed_receipt"}, "trusted_time_receipt": {"profile": "rfc3161", "gen_time": ASOF, "receipt_digest": d, "message_imprint": d, "nonce": nonce, "policy": "TEST_ONLY-TSA", "signature_valid": True, "chain_valid": True, "revocation_valid": True}, "revocation_receipt": {"kind": "crl", "status": "good", "issuer": "CA-TEST_ONLY", "serial": "7", "certificate_serial": "7", "crl_number": "1", "this_update": "2026-09-17T11:00:00Z", "next_update": "2026-09-17T13:00:00Z", "signature_valid": True, "issuer_binding_valid": True}}

def refresh(p):
    d = canonical_digest(p["receipt"]); p["trusted_time_receipt"]["receipt_digest"] = d; p["trusted_time_receipt"]["message_imprint"] = d; p["trusted_time_receipt"]["nonce"] = p["receipt"]["nonce"]; return p

def summary(name, out):
    return {"case": name, "result": out.get("result"), "status": out.get("status"), "error_code": out.get("error_code")}

def cli(cli_path, payload, ledger):
    p = subprocess.run([sys.executable, "-B", str(cli_path), "--ledger", str(ledger)], input=json.dumps(payload, separators=(",", ":")), text=True, capture_output=True)
    return p.returncode, json.loads(p.stdout)

def main():
    cli_path = MODULE / "cli.py"; rows = []
    with tempfile.TemporaryDirectory(prefix="up1-r2-review-") as td:
        td = Path(td); ledger_path = td / "shared.json"
        # Positive, then same-key/same-digest retry and same nonce/new key.
        p = fixture(); rc1, o1 = cli(cli_path, p, ledger_path); rows.append({"case": "baseline", "exit": rc1, **summary("baseline", o1)})
        rc2, o2 = cli(cli_path, p, ledger_path); rows.append({"case": "same_key_same_digest_retry", "exit": rc2, **summary("retry", o2)})
        p2 = fixture(nonce="nonce-001", idem="idem-002"); rc3, o3 = cli(cli_path, p2, ledger_path); rows.append({"case": "same_nonce_new_key", "exit": rc3, **summary("nonce", o3)})
        p3 = fixture(seq=2, nonce="nonce-002", idem="idem-003"); rc4, o4 = cli(cli_path, p3, ledger_path); rows.append({"case": "next_sequence", "exit": rc4, **summary("next", o4)})
        # HMAC/state tamper: state change with stale tag.
        env = json.loads(ledger_path.read_text(encoding="utf-8")); env["state"]["nonces"] = {}; ledger_path.write_text(json.dumps(env), encoding="utf-8")
        rc5, o5 = cli(cli_path, fixture(seq=3, nonce="nonce-003", idem="idem-004"), ledger_path); rows.append({"case": "state_tamper_stale_hmac", "exit": rc5, **summary("tamper", o5)})
        # Build HMAC-valid but index-inconsistent/duplicate-entry states using the ledger's own key.
        malformed_path = td / "malformed.json"; mal = PersistentReplayLedger(malformed_path); key = mal._key(); scope = '{"candidate":"c-001","source":"attestor-A"}'
        e1 = {"scope": scope, "nonce": "n1", "sequence": 1, "idempotency_key": "same", "canonical_digest": "d1", "result_digest": "r1"}; e2 = {"scope": scope, "nonce": "n2", "sequence": 2, "idempotency_key": "same", "canonical_digest": "d2", "result_digest": "r2"}
        state = {"nonces": {scope: ["n1", "n2"]}, "sequences": {scope: 2}, "idempotency": {"same": {"canonical_digest": "d2", "result_digest": "r2"}}, "entries": [e1, e2]}; malformed_path.write_text(json.dumps(mal._envelope(state, key), separators=(",", ":")), encoding="utf-8")
        p6 = fixture(seq=3, nonce="nonce-003", idem="idem-004"); rc6, o6 = cli(cli_path, p6, malformed_path); rows.append({"case": "duplicate_idempotency_entries", "exit": rc6, **summary("duplicate", o6)})
        duplicate_nonce_path = td / "duplicate-nonce.json"; dup_nonce = PersistentReplayLedger(duplicate_nonce_path); dup_key = dup_nonce._key(); e3 = {"scope": scope, "nonce": "same-nonce", "sequence": 1, "idempotency_key": "k1", "canonical_digest": "d1", "result_digest": "r1"}; e4 = {"scope": scope, "nonce": "same-nonce", "sequence": 2, "idempotency_key": "k2", "canonical_digest": "d2", "result_digest": "r2"}; dup_state = {"nonces": {scope: ["same-nonce", "same-nonce"]}, "sequences": {scope: 2}, "idempotency": {"k1": {"canonical_digest": "d1", "result_digest": "r1"}, "k2": {"canonical_digest": "d2", "result_digest": "r2"}}, "entries": [e3, e4]}; duplicate_nonce_path.write_text(json.dumps(dup_nonce._envelope(dup_state, dup_key), separators=(",", ":")), encoding="utf-8")
        rc7, o7 = cli(cli_path, fixture(seq=3, nonce="nonce-003", idem="idem-004"), duplicate_nonce_path); rows.append({"case": "duplicate_nonce_entries", "exit": rc7, **summary("duplicate_nonce", o7)})
        # Two processes share one ledger; O_EXCL lock/atomic replace must produce one commit only.
        concurrent = td / "concurrent.json"; raw = json.dumps(fixture(), separators=(",", ":")); ps = [subprocess.Popen([sys.executable, "-B", str(cli_path), "--ledger", str(concurrent)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(2)]; outs = []
        for proc in ps:
            so, se = proc.communicate(raw); outs.append({"exit": proc.returncode, **summary("concurrent", json.loads(so))})
        rows.append({"case": "two_process_atomic_cas", "observed": outs})
        # Strict JSON and nonfinite parser checks through the CLI.
        base = json.dumps(fixture(), separators=(",", ":")); dup = base.replace('"sequence":1,"issued_at"', '"sequence":1,"sequence":1,"issued_at"', 1); q = subprocess.run([sys.executable, "-B", str(cli_path), "--ledger", str(td / "dup.json")], input=dup, text=True, capture_output=True); rows.append({"case": "duplicate_json_cli", "exit": q.returncode, **summary("dup", json.loads(q.stdout))})
        nan = json.dumps(fixture(), separators=(",", ":")).replace('"duration_seconds":3600', '"duration_seconds":NaN'); q = subprocess.run([sys.executable, "-B", str(cli_path), "--ledger", str(td / "nan.json")], input=nan, text=True, capture_output=True); rows.append({"case": "nonfinite_json_cli", "exit": q.returncode, **summary("nan", json.loads(q.stdout))})
        # OCSP chain fields are required and invalid responder proof is fail-closed.
        ocsp = fixture(); ocsp["revocation_receipt"] = {"kind": "ocsp", "status": "good", "issuer": "CA-TEST_ONLY", "serial": "7", "this_update": "2026-09-17T11:00:00Z", "next_update": "2026-09-17T13:00:00Z", "produced_at": "2026-09-17T11:30:00Z", "signature_valid": True, "issuer_binding_valid": True, "responder_signature_valid": True, "chain_valid": True}; rows.append(summary("ocsp_valid", validate(ocsp, ledger=PersistentReplayLedger(td / "ocsp.json"))))
        ocsp["revocation_receipt"]["responder_signature_valid"] = False; rows.append(summary("ocsp_bad_chain", validate(ocsp, ledger=PersistentReplayLedger(td / "ocsp-bad.json"))))
        false_string = fixture(); false_string["revocation_receipt"]["available"] = "false"; rows.append(summary("revocation_available_string", validate(false_string, ledger=PersistentReplayLedger(td / "available-string.json"))))
        key_probe = PersistentReplayLedger(td / "caller-selected.json"); key_probe._key(); rows.append({"case": "hmac_key_location", "key_path": str(key_probe.key_path), "ledger_path": str(key_probe.path), "co_located_with_caller_selected_ledger": key_probe.key_path.parent == key_probe.path.parent})
    print(json.dumps({"TEST_ONLY": True, "non_evidence": True, "pid": os.getpid(), "parent_pid": os.getppid(), "rows": rows}, sort_keys=True, separators=(",", ":")))
    return 0

if __name__ == "__main__": raise SystemExit(main())
