"""Independent R4 revocation/replay attack harness; TEST_ONLY/non_evidence."""
from __future__ import annotations
import hashlib, hmac, json, os, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
MODULE = ROOT / "tools" / "up1_external_closure_r2" / "revocation_time_replay"
sys.path.insert(0, str(MODULE))
import core as core_module  # noqa: E402
from core import PersistentReplayLedger, canonical_bytes, canonical_digest, validate  # noqa: E402

KEY = bytes(range(32))
ASOF = "2026-09-17T12:00:00Z"


def fixture(seq=1, nonce="nonce-001", idem="idem-001"):
    receipt = {"verification_id": "v-001", "nonce": nonce, "challenge": "challenge-001",
               "scope": {"candidate": "c-001", "source": "attestor-A"}, "source": "attestor-A",
               "source_version": {"version": "source-v1", "hash": "abc123"}, "sequence": seq,
               "issued_at": "2026-09-17T11:59:00Z", "expires_at": "2026-09-17T12:10:00Z",
               "idempotency_key": idem, "payload": {"value": 3}}
    digest = canonical_digest(receipt)
    return {"schema": "UP1-R2.revocation-time-replay.v1", "profile": "TEST_ONLY-W2-R1",
            "test_only": True, "receipt": receipt, "receipt_signature_valid": True,
            "clock_skew_seconds": 2, "replay_window": {"duration_seconds": 3600,
            "trusted_time_basis": "signed_receipt"}, "trusted_time_receipt": {"available": True,
            "profile": "rfc3161", "gen_time": ASOF, "receipt_digest": digest,
            "message_imprint": digest, "nonce": nonce, "challenge": "challenge-001",
            "policy": "TEST_ONLY-TSA", "signature_valid": True, "chain_valid": True,
            "revocation_valid": True}, "revocation_receipt": {"available": True, "kind": "crl",
            "status": "good", "issuer": "CA-TEST_ONLY", "serial": "7", "certificate_serial": "7",
            "crl_number": "1", "this_update": "2026-09-17T11:00:00Z",
            "next_update": "2026-09-17T13:00:00Z", "signature_valid": True,
            "issuer_binding_valid": True}}


def refresh(payload):
    digest = canonical_digest(payload["receipt"])
    payload["trusted_time_receipt"].update(receipt_digest=digest, message_imprint=digest,
                                            nonce=payload["receipt"]["nonce"])


def summary(case, obj, exit_code=None):
    result = {"case": case, "result": obj.get("result"), "status": obj.get("status"),
              "error_code": obj.get("error_code")}
    if exit_code is not None:
        result["exit"] = exit_code
    return result


def cli(cli_path, payload, ledger, key):
    proc = subprocess.run([sys.executable, "-B", str(cli_path), "--ledger", str(ledger),
                           "--key", str(key)], input=json.dumps(payload, separators=(",", ":")),
                          text=True, capture_output=True, check=False)
    return proc.returncode, json.loads(proc.stdout)


def signed(path, state, key):
    ledger = PersistentReplayLedger(path, key_path=key)
    envelope = ledger._envelope(state, KEY)
    path.write_text(json.dumps(envelope, separators=(",", ":")), encoding="utf-8")


def main():
    cli_path = MODULE / "cli.py"
    rows = []
    with tempfile.TemporaryDirectory(prefix="up1-r4-review-") as temp:
        td = Path(temp); key = td / "trusted.key"; key.write_bytes(KEY)
        ledger = td / "ledger.json"
        rc, obj = cli(cli_path, fixture(), ledger, key); rows.append(summary("baseline", obj, rc))
        rc, obj = cli(cli_path, fixture(), ledger, key); rows.append(summary("replay_nonce", obj, rc))
        rc, obj = cli(cli_path, fixture(seq=2, nonce="nonce-002", idem="idem-002"), ledger, key)
        rows.append(summary("next_sequence", obj, rc))
        rc, obj = cli(cli_path, fixture(seq=100, nonce="nonce-003", idem="idem-003"), ledger, key)
        rows.append(summary("sequence_gap", obj, rc))
        scope = '{"candidate":"c-001","source":"attestor-A"}'
        e1 = {"scope": scope, "source": "attestor-A", "nonce": "n1", "sequence": 1,
              "idempotency_key": "same", "canonical_digest": "a" * 64, "result_digest": "b" * 64}
        e2 = dict(e1, nonce="n2", sequence=2, canonical_digest="c" * 64, result_digest="d" * 64)
        state = {"nonces": {scope: ["n1", "n2"]}, "sequences": {scope: 2},
                 "idempotency": {"same": {"canonical_digest": "c" * 64, "result_digest": "d" * 64}},
                 "entries": [e1, e2]}
        bad = td / "duplicate-idem.json"; signed(bad, state, key)
        rc, obj = cli(cli_path, fixture(seq=3, nonce="n3", idem="n3"), bad, key)
        rows.append(summary("hmac_valid_duplicate_idempotency", obj, rc))
        e3 = dict(e1, sequence=2, idempotency_key="other")
        state = {"nonces": {scope: ["n1", "n1"]}, "sequences": {scope: 2},
                 "idempotency": {"same": {"canonical_digest": "a" * 64, "result_digest": "b" * 64},
                                 "other": {"canonical_digest": "a" * 64, "result_digest": "b" * 64}},
                 "entries": [e1, e3]}
        bad = td / "duplicate-nonce.json"; signed(bad, state, key)
        rc, obj = cli(cli_path, fixture(seq=3, nonce="n3", idem="n3"), bad, key)
        rows.append(summary("hmac_valid_duplicate_nonce", obj, rc))
        bad = td / "index-mismatch.json"; signed(bad, {"nonces": {}, "sequences": {},
                                                         "idempotency": {}, "entries": [e1]}, key)
        rc, obj = cli(cli_path, fixture(seq=2, nonce="n2", idem="n2"), bad, key)
        rows.append(summary("hmac_valid_index_mismatch", obj, rc))
        rc, obj = cli(cli_path, fixture(), td / "missing.json", td / "missing-key")
        rows.append(summary("key_missing", obj, rc))
        auto = PersistentReplayLedger(td / "auto.json"); obj = validate(fixture(), ledger=auto)
        rows.append({"case": "automatic_key_generation", "result": obj.get("result"),
                     "status": obj.get("status"), "error_code": obj.get("error_code"),
                     "key_created": auto.key_path is not None and auto.key_path.exists()})
        replaced = td / "replacement.json"; rc, obj = cli(cli_path, fixture(), replaced, key)
        key.write_bytes(bytes(255 - x for x in range(32)))
        rc2, obj2 = cli(cli_path, fixture(seq=2, nonce="replacement", idem="replacement"), replaced, key)
        rows.append({"case": "key_replacement", "first_exit": rc, "second_exit": rc2,
                     "second": summary("replacement", obj2)})
        # Strict parser and nested type controls are exercised through the real CLI.
        base = json.dumps(fixture(), separators=(",", ":"))
        duplicate = base.replace('"sequence":1,"issued_at"', '"sequence":1,"sequence":1,"issued_at"', 1)
        proc = subprocess.run([sys.executable, "-B", str(cli_path), "--ledger", str(td / "duplicate.json"),
                               "--key", str(key)], input=duplicate, text=True, capture_output=True, check=False)
        rows.append({"case": "duplicate_json", "exit": proc.returncode, **summary("duplicate", json.loads(proc.stdout))})
        nonfinite = base.replace('"duration_seconds":3600', '"duration_seconds":NaN')
        proc = subprocess.run([sys.executable, "-B", str(cli_path), "--ledger", str(td / "nonfinite.json"),
                               "--key", str(key)], input=nonfinite, text=True, capture_output=True, check=False)
        rows.append({"case": "nonfinite_json", "exit": proc.returncode, **summary("nonfinite", json.loads(proc.stdout))})
        wrong = fixture(); wrong["receipt"]["source"] = 123; refresh(wrong)
        rc, obj = cli(cli_path, wrong, td / "source-type.json", key); rows.append(summary("source_type", obj, rc))
        available = fixture(); available["revocation_receipt"]["available"] = "false"
        rc, obj = cli(cli_path, available, td / "available-string.json", key)
        rows.append(summary("revocation_available_string", obj, rc))
        for label, mutation in [("revoked", {"status": "revoked"}), ("stale", {"next_update": "2026-09-17T11:59:00Z"}),
                                ("unknown", {"status": "unknown"}), ("bad_signature", {"signature_valid": False})]:
            payload = fixture(); payload["revocation_receipt"].update(mutation)
            rc, obj = cli(cli_path, payload, td / (label + ".json"), key)
            rows.append(summary("revocation_" + label, obj, rc))
        # Windows ACL owner/broad-ACE controls are live mutations on disposable files only.
        if os.name == "nt":
            for label, sid in [("everyone", "*S-1-1-0"), ("users", "*S-1-5-32-545"),
                               ("authenticated_users", "*S-1-5-11")]:
                acl_key = td / (label + ".key"); acl_key.write_bytes(KEY)
                changed = subprocess.run(["icacls", str(acl_key), "/grant", sid + ":R"],
                                         capture_output=True, text=True, check=False)
                if changed.returncode == 0:
                    rc, obj = cli(cli_path, fixture(), td / (label + ".json"), acl_key)
                    rows.append({"case": "acl_broad_" + label, "mutation_exit": changed.returncode,
                                 "validation": summary("acl", obj, rc)})
                else:
                    rows.append({"case": "acl_broad_" + label, "skipped": True,
                                 "reason": "icacls mutation unavailable", "mutation_exit": changed.returncode})
            owner_key = td / "foreign-owner.key"; owner_key.write_bytes(KEY)
            changed = subprocess.run(["icacls", str(owner_key), "/setowner", "*S-1-5-20"],
                                     capture_output=True, text=True, check=False)
            if changed.returncode == 0:
                rc, obj = cli(cli_path, fixture(), td / "foreign-owner.json", owner_key)
                rows.append({"case": "acl_foreign_owner", "mutation_exit": changed.returncode,
                             "validation": summary("owner", obj, rc)})
            else:
                rows.append({"case": "acl_foreign_owner", "skipped": True,
                             "reason": "icacls owner mutation unavailable", "mutation_exit": changed.returncode})
            restricted = td / "restricted.key"; restricted.write_bytes(KEY)
            rc, obj = cli(cli_path, fixture(), td / "restricted.json", restricted)
            rows.append(summary("acl_restricted_key", obj, rc))
            unavailable_key = td / "acl-unavailable.key"; unavailable_key.write_bytes(KEY)
            original_which = core_module.shutil.which
            core_module.shutil.which = lambda _name: None
            try:
                obj = validate(fixture(), ledger=PersistentReplayLedger(td / "acl-unavailable.json",
                                                                         key_path=unavailable_key))
            finally:
                core_module.shutil.which = original_which
            rows.append(summary("acl_verifier_unavailable", obj))
            real = td / "real"; real.mkdir(); (real / "trusted.key").write_bytes(KEY)
            junction = td / "junction"
            created = subprocess.run(["cmd", "/c", "mklink", "/J", str(junction), str(real)],
                                     capture_output=True, text=True, check=False)
            if created.returncode == 0:
                rc, obj = cli(cli_path, fixture(), td / "junction-key-ledger.json", junction / "trusted.key")
                rows.append({"case": "junction_key_parent", "creation_exit": created.returncode,
                             "validation": summary("junction", obj, rc)})
                rc, obj = cli(cli_path, fixture(), junction / "ledger.json", real / "trusted.key")
                rows.append({"case": "junction_ledger_lock_parent", "creation_exit": created.returncode,
                             "validation": summary("junction", obj, rc)})
            else:
                rows.append({"case": "junction_parent_escape", "skipped": True,
                             "reason": "Junction creation unavailable", "creation_exit": created.returncode})
        # Fresh two-process race: exactly one commit and one replay response.
        concurrent = td / "concurrent.json"; raw = json.dumps(fixture(), separators=(",", ":"))
        processes = [subprocess.Popen([sys.executable, "-B", str(cli_path), "--ledger", str(concurrent),
                                       "--key", str(td / "race.key")], stdin=subprocess.PIPE,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(2)]
        (td / "race.key").write_bytes(KEY)
        observed = []
        for process in processes:
            stdout, _stderr = process.communicate(raw)
            observed.append({"exit": process.returncode, **summary("concurrent", json.loads(stdout))})
        rows.append({"case": "two_process_atomic_cas", "observed": observed})
    print(json.dumps({"TEST_ONLY": True, "non_evidence": True, "pid": os.getpid(),
                      "parent_pid": os.getppid(), "rows": rows}, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
