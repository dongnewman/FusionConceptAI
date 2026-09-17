"""Independent R2 attack and replay review for witness_authority."""
from __future__ import annotations

import copy
import hashlib
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve()
ROOT = next(p for p in HERE.parents if (p / "tools").is_dir() and (p / "test").is_dir())
TOOLS = ROOT / "tools"
FIXTURES = ROOT / "test/up1_external_closure_r2/witness_authority/fixtures"
CLI = ROOT / "tools/up1_external_closure_r2/witness_authority/cli.py"
sys.path.insert(0, str(TOOLS))
from up1_external_closure_r2.witness_authority.validator import AuthorityLedger, validate


def sha(value: object) -> str:
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                     separators=(",", ":"), allow_nan=False).encode()).hexdigest()


def load_absent() -> dict:
    return json.loads((FIXTURES / "production_witness_absent.json").read_text(encoding="utf-8"))


def full() -> dict:
    row = load_absent()
    row["witness_scope"] = row["candidate_id"]
    evidence = {
        "evidence_id": "E-1", "candidate_id": row["candidate_id"],
        "object_sha256": row["canonical_object_sha256"],
        "source_revision": row["source_revision"], "source_locator": row["source_locator"],
        "source_version": row["source_version"], "layer_refs": copy.deepcopy(row["layer_refs"]),
        "four_axis_refs": copy.deepcopy(row["four_axis_refs"]),
    }
    row["witness"] = {
        "identity": {"name": "Independent Witness", "organization": "External Institution"},
        "independence_declaration": {
            "statement": "independent review for candidate-r2-demo", "scope": row["candidate_id"],
            "conflict_disclosure": False,
            "external_attestation": {
                "attestation_id": "att-1", "provider": "External Institution", "ref": "external://attestation/1",
                "digest": "9" * 64, "verifier_ref": "external://verifier", "verifier_version": "v1",
                "candidate_id": row["candidate_id"], "subject_object_sha256": row["canonical_object_sha256"],
                "status": "verified",
            },
        },
        "evidence_candidates": [evidence],
    }
    binding_payload = {
        "candidate_id": row["candidate_id"], "canonical_object_sha256": row["canonical_object_sha256"],
        "source_revision": row["source_revision"], "source_locator": row["source_locator"],
        "source_version": row["source_version"], "layer_refs": row["layer_refs"],
        "four_axis_refs": row["four_axis_refs"], "evidence_candidates": [evidence],
    }
    row["witness"]["signature_material"] = {
        "ref": "external://signature", "algorithm": "ed25519", "signature": "detached-signature",
        "digest": sha(binding_payload), "scope": row["candidate_id"],
        "subject_object_sha256": row["canonical_object_sha256"],
    }
    row["authority"] = {
        "endpoint": {"uri": "external://authority", "owner": "External Authority"},
        "ack": {
            "ack_id": "ACK-1", "request_id": row["request_id"], "idempotency_key": row["idempotency_key"],
            "accepted_object_sha256": row["canonical_object_sha256"], "authority_decision": "RECEIVED",
            "received_at_trusted_time": "2026-09-17T00:00:01Z", "verifier_ref": "external://verifier",
            "verifier_version": "v1", "receipt_signature": "receipt-signature", "receipt_sha256": "8" * 64,
        },
    }
    return row


def refresh_signature_digest(row: dict) -> None:
    evidence = row["witness"]["evidence_candidates"]
    payload = {
        "candidate_id": row["candidate_id"], "canonical_object_sha256": row["canonical_object_sha256"],
        "source_revision": row["source_revision"], "source_locator": row["source_locator"],
        "source_version": row["source_version"], "layer_refs": row["layer_refs"],
        "four_axis_refs": row["four_axis_refs"], "evidence_candidates": evidence,
    }
    row["witness"]["signature_material"]["digest"] = sha(payload)


def outcome(name: str, row: dict) -> dict:
    r = validate(row, now="2026-09-17T00:00:02Z")
    return {"case": name, "status": r["status"], "resolution": r["resolution"],
            "error_code": r["error_code"], "error_path": r["error_path"]}


def main() -> int:
    started = datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
    rows: list[dict] = []

    # Unknown-field attacks at every public object boundary.
    unknown_cases = {
        "root": lambda x: x.update(unversioned_extension="x"),
        "candidate": lambda x: x.update(candidate={"candidate_id": x["candidate_id"], "unknown": "x"}),
        "layer": lambda x: x["layer_refs"]["G1"].update(unknown="x"),
        "axis": lambda x: x["four_axis_refs"]["schema"].update(unknown="x"),
        "witness": lambda x: x["witness"].update(unknown="x"),
        "identity": lambda x: x["witness"]["identity"].update(unknown="x"),
        "independence": lambda x: x["witness"]["independence_declaration"].update(unknown="x"),
        "attestation": lambda x: x["witness"]["independence_declaration"]["external_attestation"].update(unknown="x"),
        "evidence": lambda x: x["witness"]["evidence_candidates"][0].update(unknown="x"),
        "signature": lambda x: x["witness"]["signature_material"].update(unknown="x"),
        "authority": lambda x: x["authority"].update(unknown="x"),
        "endpoint": lambda x: x["authority"]["endpoint"].update(unknown="x"),
        "ack": lambda x: x["authority"]["ack"].update(unknown="x"),
    }
    for name, mutate in unknown_cases.items():
        row = full(); mutate(row); rows.append(outcome("unknown_" + name, row))

    # Exact scope, complete evidence/signature binding and scalar type attacks.
    row = full(); row["witness_scope"] = "attacker/" + row["candidate_id"] + "/other"; row["witness"]["independence_declaration"]["scope"] = row["witness_scope"]
    rows.append(outcome("scope_substring_foreign", row))
    row = full(); row["witness"]["witness_scope"] = "attacker"  # unknown witness key must not become a bypass
    rows.append(outcome("witness_unknown_scope_alias", row))
    row = full(); row["witness"]["evidence_candidates"][0]["layer_refs"]["G1"]["ref"] = "foreign://G1"
    rows.append(outcome("evidence_foreign_ref", row))
    row = full(); del row["witness"]["evidence_candidates"][0]["layer_refs"]["G1"]["version"]
    rows.append(outcome("evidence_missing_version", row))
    row = full(); row["witness"]["signature_material"]["digest"] = "f" * 64
    rows.append(outcome("signature_digest_mismatch", row))
    row = full(); row["witness"]["signature_material"]["signature"] = 123
    rows.append(outcome("signature_wrong_type", row))
    row = full(); row["authority"]["ack"]["ack_id"] = 123
    rows.append(outcome("ack_wrong_type", row))
    row = full(); row["witness"]["evidence_candidates"][0]["canonical_object_sha256"] = "f" * 64; refresh_signature_digest(row)
    rows.append(outcome("evidence_conflicting_digest_alias", row))
    row = full(); row["witness"]["signature_material_ref"] = {"ref": "attacker://signature"}
    rows.append(outcome("conflicting_signature_alias", row))
    row = full(); row["authority"]["receipt"] = {"ack_id": "attacker-ack"}
    rows.append(outcome("conflicting_ack_alias", row))
    row = full(); del row["witness"]["independence_declaration"]["external_attestation"]
    rows.append(outcome("self_certified_independence", row))

    # Typed absence must consume replay key; changed full request bytes conflict.
    absent = load_absent(); ledger = AuthorityLedger()
    first = ledger.validate(absent, now="2026-09-17T00:00:02Z")
    second = ledger.validate(copy.deepcopy(absent), now="2026-09-17T00:00:02Z")
    changed = copy.deepcopy(absent); changed["source_revision"] = "changed-source"
    conflict = ledger.validate(changed, now="2026-09-17T00:00:02Z")
    rows.append({"case": "typed_absence_replay", "first": first["error_code"], "second": second["error_code"],
                 "second_status": second["status"], "changed": conflict["error_code"]})

    # Two fresh CLI processes must have equal semantic output; one-process batch
    # must reject the second request in its shared ledger.
    payload = json.dumps(full(), ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    proc_rows = []
    for _ in range(2):
        p = subprocess.run([sys.executable, "-B", str(CLI)], input=payload, text=True,
                           capture_output=True, cwd=str(ROOT), check=False)
        value = json.loads(p.stdout)
        proc_rows.append({"exit_code": p.returncode, "status": value["status"],
                          "resolution": value["resolution"], "error_code": value["error_code"],
                          "semantic": {k: v for k, v in value.items() if k not in {"started_at_utc", "ended_at_utc", "cli_pid", "cli_started_at_utc"}}})
    rows.append({"case": "two_process_replay", "processes": proc_rows,
                 "semantic_equal": proc_rows[0]["semantic"] == proc_rows[1]["semantic"]})
    batch = subprocess.run([sys.executable, "-B", str(CLI)], input=json.dumps({"requests": [full(), full()]}),
                           text=True, capture_output=True, cwd=str(ROOT), check=False)
    b = json.loads(batch.stdout)
    rows.append({"case": "single_process_batch_replay", "exit_code": batch.returncode,
                 "results": [{"status": r["status"], "error_code": r["error_code"]} for r in b["results"]]})

    # Shared in-memory ledger under concurrent calls: exactly one admission and
    # all subsequent observations must be duplicate (same bytes).
    concurrent_ledger = AuthorityLedger()
    with ThreadPoolExecutor(max_workers=12) as pool:
        concurrent = list(pool.map(lambda _: concurrent_ledger.validate(full(), now="2026-09-17T00:00:02Z"), range(24)))
    rows.append({"case": "ledger_thread_concurrency", "status_counts": {
        status: sum(r["status"] == status for r in concurrent) for status in sorted({r["status"] for r in concurrent})},
        "error_counts": {code: sum(r["error_code"] == code for r in concurrent) for code in sorted({r["error_code"] for r in concurrent})}})

    ended = datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
    print(json.dumps({"schema": "UP1.witness-independent-review-r2.attack.v1", "pid": os.getpid(),
                      "started_at_utc": started, "ended_at_utc": ended, "TEST_ONLY": True,
                      "non_evidence": True, "no_publish": True, "results": rows},
                     ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
