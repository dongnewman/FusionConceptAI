"""Independent attack probes for the frozen witness-authority slice.

This is a reviewer-owned probe.  It imports only the implementation API and
derives expected safety classifications from the frozen contract, not from
the implementation's test oracle.
"""
from __future__ import annotations

import copy
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
TOOLS = ROOT / "tools"
FIXTURES = ROOT / "test/up1_external_closure_r2/witness_authority/fixtures"
CLI = ROOT / "tools/up1_external_closure_r2/witness_authority/cli.py"
sys.path.insert(0, str(TOOLS))
from up1_external_closure_r2.witness_authority.validator import AuthorityLedger, validate


def complete() -> dict:
    row = json.loads((FIXTURES / "production_witness_absent.json").read_text(encoding="utf-8"))
    row["witness"] = {
        "identity": {"name": "Independent Witness", "organization": "External Institution"},
        "independence_declaration": {
            "statement": "independent review for candidate-r2-demo",
            "scope": "candidate-r2-demo",
            "conflict_disclosure": False,
        },
        "evidence_candidates": [{
            "evidence_id": "E-1",
            "candidate_id": row["candidate_id"],
            "object_sha256": row["canonical_object_sha256"],
            "source_revision": row["source_revision"],
            "source_locator": row["source_locator"],
            "source_version": row["source_version"],
        }],
        "signature_material": {
            "ref": "external://signature",
            "algorithm": "ed25519",
            "signature": "detached-signature",
            "digest": row["canonical_object_sha256"],
        },
    }
    row["authority"] = {
        "endpoint": {"uri": "external://authority", "owner": "External Authority"},
        "ack": {
            "ack_id": "ACK-1",
            "request_id": row["request_id"],
            "idempotency_key": row["idempotency_key"],
            "accepted_object_sha256": row["canonical_object_sha256"],
            "authority_decision": "RECEIVED",
            "received_at_trusted_time": "2026-09-17T00:00:01Z",
            "verifier_ref": "external://verifier",
            "verifier_version": "v1",
            "receipt_signature": "receipt-signature",
            "receipt_sha256": "8" * 64,
        },
    }
    return row


def probe(name: str, row: dict) -> dict:
    out = validate(row, now="2026-09-17T00:00:02Z")
    return {"case": name, "status": out["status"], "resolution": out["resolution"],
            "error_code": out["error_code"], "error_path": out["error_path"]}


def main() -> int:
    started = datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
    results: list[dict] = []

    row = complete()
    row["unexpected_extension"] = {"unversioned": "attacker-controlled"}
    results.append(probe("unknown_top_level_extension", row))

    row = complete()
    row["witness"]["independence_declaration"]["scope"] = "attacker/candidate-r2-demo/other"
    results.append(probe("non_exact_witness_scope", row))

    row = complete()
    row["witness"]["independence_declaration"]["statement"] = "self-certified independent"
    results.append(probe("self_attested_independence", row))

    row = complete()
    row["witness"]["signature_material"]["digest"] = "f" * 64
    results.append(probe("signature_digest_not_bound", row))

    row = complete()
    row["witness"]["evidence_candidates"][0]["layer_refs"] = {
        "G1": {"candidate_id": row["candidate_id"], "ref": "foreign://G1"},
        "G2": {"candidate_id": row["candidate_id"]},
        "G3": {"candidate_id": row["candidate_id"], "ref": "foreign://G3", "sha256": "0" * 64, "version": "foreign"},
    }
    results.append(probe("evidence_binding_incomplete_foreign_refs", row))

    row = complete()
    row["witness"]["signature_material"]["signature"] = 123
    row["authority"]["ack"]["ack_id"] = 123
    results.append(probe("wrong_signature_and_ack_types", row))

    absent = json.loads((FIXTURES / "production_witness_absent.json").read_text(encoding="utf-8"))
    ledger = AuthorityLedger()
    first = ledger.validate(absent, now="2026-09-17T00:00:02Z")
    second = ledger.validate(copy.deepcopy(absent), now="2026-09-17T00:00:02Z")
    results.append({"case": "repeat_typed_absence_idempotency", "first": first["error_code"],
                    "second": second["error_code"], "second_status": second["status"]})

    first = complete()
    second = copy.deepcopy(first)
    second["source_revision"] = "changed-source-revision"
    second["witness"]["evidence_candidates"][0]["source_revision"] = second["source_revision"]
    ledger = AuthorityLedger()
    ledger.validate(first, now="2026-09-17T00:00:02Z")
    repeated_changed_bytes = ledger.validate(second, now="2026-09-17T00:00:02Z")
    results.append({"case": "same_idempotency_changed_request_bytes",
                    "status": repeated_changed_bytes["status"],
                    "error_code": repeated_changed_bytes["error_code"]})

    cli_row = complete()
    cli_row["unknown_nested"] = "ignored"
    proc = subprocess.run([sys.executable, "-B", str(CLI)], input=json.dumps(cli_row),
                          text=True, capture_output=True, cwd=str(ROOT), check=False)
    cli = json.loads(proc.stdout)
    results.append({"case": "cli_unknown_field", "exit_code": proc.returncode,
                    "status": cli["status"], "error_code": cli["error_code"]})

    ended = datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
    print(json.dumps({"schema": "UP1.witness-independent-review-r1.probes.v1",
                      "pid": os.getpid(), "started_at_utc": started, "ended_at_utc": ended,
                      "TEST_ONLY": True, "non_evidence": True, "no_publish": True,
                      "results": results}, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
