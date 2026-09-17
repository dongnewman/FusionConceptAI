"""R5 independent ACL provider/reparse review; TEST_ONLY/non_evidence."""
from __future__ import annotations
import json, os, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
MODULE = ROOT / "tools" / "up1_external_closure_r2" / "revocation_time_replay"
TEST = ROOT / "test" / "up1_external_closure_r2" / "revocation_time_replay"
sys.path.insert(0, str(MODULE))
import core  # noqa: E402
from core import PersistentReplayLedger, ReceiptInputError, canonical_digest, evaluate_windows_acl, validate, validate_acl_provider  # noqa: E402

KEY = bytes(range(32))


def fixture():
    receipt = {"verification_id": "v-r5", "nonce": "nonce-r5", "challenge": "challenge-r5",
               "scope": {"candidate": "c-r5", "source": "attestor-r5"}, "source": "attestor-r5",
               "source_version": {"version": "source-r5", "hash": "r5hash"}, "sequence": 1,
               "issued_at": "2026-09-17T11:59:00Z", "expires_at": "2026-09-17T12:10:00Z",
               "idempotency_key": "idem-r5", "payload": {"value": 5}}
    digest = canonical_digest(receipt)
    return {"schema": "UP1-R2.revocation-time-replay.v1", "profile": "TEST_ONLY-W2-R1", "test_only": True,
            "receipt": receipt, "receipt_signature_valid": True, "clock_skew_seconds": 2,
            "replay_window": {"duration_seconds": 3600, "trusted_time_basis": "signed_receipt"},
            "trusted_time_receipt": {"available": True, "profile": "rfc3161", "gen_time": "2026-09-17T12:00:00Z",
            "receipt_digest": digest, "message_imprint": digest, "nonce": "nonce-r5", "challenge": "challenge-r5",
            "policy": "TEST_ONLY-TSA", "signature_valid": True, "chain_valid": True, "revocation_valid": True},
            "revocation_receipt": {"available": True, "kind": "crl", "status": "good", "issuer": "CA-TEST_ONLY",
            "serial": "7", "certificate_serial": "7", "crl_number": "1", "this_update": "2026-09-17T11:00:00Z",
            "next_update": "2026-09-17T13:00:00Z", "signature_valid": True, "issuer_binding_valid": True}}


def row(case, fn):
    try:
        result = fn()
        return {"case": case, "outcome": "pass", "result": result}
    except ReceiptInputError as exc:
        return {"case": case, "outcome": "expected_error", "error_code": exc.code, "detail": str(exc)}
    except Exception as exc:
        return {"case": case, "outcome": "unexpected_error", "error": repr(exc)}


def acl(owner_sid="S-1-5-21-1-2-3-4", current_sid="S-1-5-21-1-2-3-4", owner_ok=True, rules=None):
    return {"owner": "fixture-owner", "owner_sid": owner_sid, "current_sid": current_sid,
            "owner_ok": owner_ok, "sddl": "O:" + owner_sid + "D:(A;;FA;;;SY)", "protected": True,
            "access_rules": rules or [], "bad_allow_identities": []}


def main():
    rows = []
    rows.append(row("foreign_owner_sddl", lambda: evaluate_windows_acl(acl(owner_sid="S-1-5-20", owner_ok=False))))
    rows.append(row("malformed_provider", lambda: evaluate_windows_acl({"owner_sid": "not-a-sid"})))
    rows.append(row("unsupported_provider_none", lambda: validate_acl_provider(Path("unused"), None)))
    rows.append(row("unsupported_provider_exception", lambda: validate_acl_provider(Path("unused"), lambda _p: (_ for _ in ()).throw(ReceiptInputError("unavailable", "trusted_key_acl_unsupported")))))
    rows.append(row("restricted_acl_pure", lambda: evaluate_windows_acl(acl(rules=[{"identity": "SYSTEM", "type": "Allow", "inherited": False}]))))
    rows.append(row("broad_acl_pure", lambda: evaluate_windows_acl(acl(rules=[{"identity": "Everyone", "type": "Allow", "inherited": True}]))))
    with tempfile.TemporaryDirectory(prefix="up1-r5-acl-") as temp:
        td = Path(temp); key = td / "trusted.key"; key.write_bytes(KEY)
        # Real PowerShell Get-Acl provider: restricted current-user key must pass.
        restricted = validate(fixture(), ledger=PersistentReplayLedger(td / "restricted.json", key_path=key))
        rows.append({"case": "real_restricted_key", "result": restricted.get("result"), "error_code": restricted.get("error_code")})
        for name, sid in (("everyone", "*S-1-1-0"), ("users", "*S-1-5-32-545"), ("authenticated_users", "*S-1-5-11")):
            wide_key = td / (name + ".key"); wide_key.write_bytes(KEY)
            changed = subprocess.run(["icacls", str(wide_key), "/grant", sid + ":R"], capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
            if changed.returncode == 0:
                result = validate(fixture(), ledger=PersistentReplayLedger(td / (name + ".json"), key_path=wide_key))
                rows.append({"case": "real_broad_" + name, "mutation_exit": changed.returncode,
                             "result": result.get("result"), "error_code": result.get("error_code")})
            else:
                rows.append({"case": "real_broad_" + name, "outcome": "not_executed", "mutation_exit": changed.returncode})
        real = td / "real"; real.mkdir(); (real / "trusted.key").write_bytes(KEY); junction = td / "junction"
        created = subprocess.run(["cmd", "/c", "mklink", "/J", str(junction), str(real)], capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
        if created.returncode == 0:
            escaped = validate(fixture(), ledger=PersistentReplayLedger(td / "junction-ledger.json", key_path=junction / "trusted.key"))
            rows.append({"case": "real_junction_key_parent", "creation_exit": created.returncode,
                         "result": escaped.get("result"), "error_code": escaped.get("error_code")})
            escaped = validate(fixture(), ledger=PersistentReplayLedger(junction / "ledger.json", key_path=real / "trusted.key"))
            rows.append({"case": "real_junction_ledger_lock_parent", "creation_exit": created.returncode,
                         "result": escaped.get("result"), "error_code": escaped.get("error_code")})
        else:
            rows.append({"case": "real_junction_parent", "outcome": "not_executed", "creation_exit": created.returncode})
    script = TEST / "privileged_acl_fixture.ps1"
    parse_env = os.environ.copy(); parse_env["R5_PS_SCRIPT_PATH"] = str(script)
    parse = subprocess.run(["pwsh", "-NoProfile", "-NonInteractive", "-Command",
                            "$s=[scriptblock]::Create((Get-Content -LiteralPath $env:R5_PS_SCRIPT_PATH -Raw)); 'parse_ok'"],
                           capture_output=True, text=True, encoding="utf-8", errors="replace", env=parse_env, check=False)
    script_text = script.read_text(encoding="utf-8")
    rows.append({"case": "privileged_fixture_script", "parse_exit": parse.returncode,
                 "parse_output": parse.stdout.strip(), "contains_elevation": any(x in script_text.lower() for x in ("runas", "start-process", "sudo")),
                 "mutation": "not_executed", "scope": "test_scope_deferred", "icacls_1307": True})
    print(json.dumps({"TEST_ONLY": True, "non_evidence": True, "pid": os.getpid(), "parent_pid": os.getppid(),
                      "rows": rows}, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
