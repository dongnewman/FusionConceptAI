"""Independent R3 witness-authority attack/replay review."""
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
TOOLS = ROOT / "tools"; FIX = ROOT / "test/up1_external_closure_r2/witness_authority/fixtures"
CLI = ROOT / "tools/up1_external_closure_r2/witness_authority/cli.py"
sys.path.insert(0, str(TOOLS))
from up1_external_closure_r2.witness_authority.validator import AuthorityLedger, validate


def canon(v: object) -> str:
    return hashlib.sha256(json.dumps(v, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()


def absent() -> dict:
    return json.loads((FIX / "production_witness_absent.json").read_text(encoding="utf-8"))


def full() -> dict:
    row = absent(); row["witness_scope"] = row["candidate_id"]
    ev = {"evidence_id":"E-1", "candidate_id":row["candidate_id"], "canonical_object_sha256":row["canonical_object_sha256"], "source_revision":row["source_revision"], "source_locator":row["source_locator"], "source_version":row["source_version"], "layer_refs":copy.deepcopy(row["layer_refs"]), "four_axis_refs":copy.deepcopy(row["four_axis_refs"])}
    row["witness"] = {"identity":{"name":"Independent Witness", "organization":"External Institution"}, "independence_declaration":{"statement":"independent review", "scope":row["candidate_id"], "conflict_disclosure":False, "external_attestation":{"attestation_id":"att-1", "provider":"External Institution", "ref":"external://attestation/1", "digest":"9"*64, "verifier_ref":"external://verifier", "verifier_version":"v1", "candidate_id":row["candidate_id"], "subject_object_sha256":row["canonical_object_sha256"], "status":"verified"}}, "evidence_candidates":[ev]}
    payload = {"candidate_id":row["candidate_id"], "canonical_object_sha256":row["canonical_object_sha256"], "source_revision":row["source_revision"], "source_locator":row["source_locator"], "source_version":row["source_version"], "layer_refs":row["layer_refs"], "four_axis_refs":row["four_axis_refs"], "evidence_candidates":[ev]}
    row["witness"]["signature_material"] = {"ref":"external://signature", "algorithm":"ed25519", "signature":"detached-signature", "digest":canon(payload), "scope":row["candidate_id"], "subject_object_sha256":row["canonical_object_sha256"]}
    row["authority"] = {"endpoint":{"uri":"external://authority", "owner":"External Authority"}, "ack":{"ack_id":"ACK-1", "request_id":row["request_id"], "idempotency_key":row["idempotency_key"], "accepted_object_sha256":row["canonical_object_sha256"], "authority_decision":"RECEIVED", "received_at_trusted_time":"2026-09-17T00:00:01Z", "verifier_ref":"external://verifier", "verifier_version":"v1", "receipt_signature":"receipt-signature", "receipt_sha256":"8"*64}}
    return row


def out(name: str, row: dict, expected: set[str] | None = None) -> dict:
    r = validate(row, now="2026-09-17T00:00:02Z")
    result = {"case":name, "status":r["status"], "resolution":r["resolution"], "error_code":r["error_code"], "error_path":r["error_path"]}
    if expected is not None: result["PASS"] = r["error_code"] in expected
    return result


def main() -> int:
    started = datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
    rows: list[dict] = []

    # R3 alias attacks: each legacy spelling alone and coexisting with its
    # canonical spelling must be rejected deterministically.
    alias_cases = [
        ("evidence_object_alias_alone", lambda x: x["witness"]["evidence_candidates"][0].update(object_sha256=x["witness"]["evidence_candidates"][0].pop("canonical_object_sha256")), {"ERR_UNKNOWN_FIELD"}),
        ("evidence_digest_alias_coexist", lambda x: x["witness"]["evidence_candidates"][0].update(object_sha256="f"*64), {"ERR_ALIAS_CONFLICT"}),
        ("signature_ref_alias_alone", lambda x: x["witness"].update(signature_material_ref={"ref":"attacker://sig"}), {"ERR_UNKNOWN_FIELD"}),
        ("signature_ref_alias_coexist", lambda x: x["witness"].update(signature_material_ref={"ref":"attacker://sig"}), {"ERR_ALIAS_CONFLICT"}),
        ("authority_receipt_alias_alone", lambda x: x["authority"].update(receipt=x["authority"]["receipt"]), {"ERR_UNKNOWN_FIELD"}),
        ("authority_receipt_alias_coexist", lambda x: x["authority"].update(receipt={"ack_id":"attacker-ack"}), {"ERR_ALIAS_CONFLICT"}),
    ]
    # For alone forms, add the legacy field explicitly where needed.
    for name, mutate, expected in alias_cases:
        row = full()
        if name == "authority_receipt_alias_alone":
            ack = row["authority"].pop("ack"); row["authority"]["receipt"] = ack
        if name == "signature_ref_alias_alone":
            row["witness"].pop("signature_material")
        mutate(row); rows.append(out(name, row, expected))

    # All R1 unknown-boundary and binding/type attacks.
    unknown = {
        "root":lambda x:x.update(unversioned="x"), "layer":lambda x:x["layer_refs"]["G1"].update(unversioned="x"),
        "axis":lambda x:x["four_axis_refs"]["schema"].update(unversioned="x"), "witness":lambda x:x["witness"].update(unversioned="x"),
        "identity":lambda x:x["witness"]["identity"].update(unversioned="x"), "independence":lambda x:x["witness"]["independence_declaration"].update(unversioned="x"),
        "attestation":lambda x:x["witness"]["independence_declaration"]["external_attestation"].update(unversioned="x"), "evidence":lambda x:x["witness"]["evidence_candidates"][0].update(unversioned="x"),
        "signature":lambda x:x["witness"]["signature_material"].update(unversioned="x"), "authority":lambda x:x["authority"].update(unversioned="x"),
        "endpoint":lambda x:x["authority"]["endpoint"].update(unversioned="x"), "ack":lambda x:x["authority"]["ack"].update(unversioned="x"),
    }
    for name, mutate in unknown.items():
        row=full(); mutate(row); rows.append(out("unknown_"+name,row,{"ERR_UNKNOWN_FIELD"}))
    row=full(); row["witness_scope"]="attacker/"+row["candidate_id"]+"/other"; row["witness"]["independence_declaration"]["scope"]=row["witness_scope"]; rows.append(out("scope_substring",row,{"ERR_SCOPE_MISMATCH"}))
    row=full(); row["witness"]["evidence_candidates"][0]["layer_refs"]["G1"]["ref"]="foreign://G1"; rows.append(out("evidence_foreign_ref",row,{"ERR_EVIDENCE_BINDING_MISMATCH"}))
    row=full(); del row["witness"]["evidence_candidates"][0]["layer_refs"]["G1"]["version"]; rows.append(out("evidence_missing_version",row,{"ERR_EVIDENCE_BINDING_MISMATCH"}))
    row=full(); row["witness"]["signature_material"]["digest"]="f"*64; rows.append(out("signature_digest_mismatch",row,{"ERR_SIGNATURE_BINDING_MISMATCH"}))
    row=full(); row["witness"]["signature_material"]["signature"]=123; rows.append(out("signature_wrong_type",row,{"ERR_INVALID_SIGNATURE_MATERIAL"}))
    row=full(); row["authority"]["ack"]["ack_id"]=123; rows.append(out("ack_wrong_type",row,{"ERR_INVALID_ACK_FIELD_TYPE"}))
    row=full(); del row["witness"]["independence_declaration"]["external_attestation"]; rows.append(out("self_certified",row,{"ERR_INDEPENDENCE_EXTERNAL_ABSENT"}))

    # Replay and changed-byte conflict.
    l=AuthorityLedger(); a=absent(); first=l.validate(a,now="2026-09-17T00:00:02Z"); second=l.validate(copy.deepcopy(a),now="2026-09-17T00:00:02Z"); changed=copy.deepcopy(a); changed["source_revision"]="changed-source"; third=l.validate(changed,now="2026-09-17T00:00:02Z")
    rows.append({"case":"typed_absence_replay","first":first["error_code"],"second":second["error_code"],"second_status":second["status"],"changed":third["error_code"],"PASS":first["error_code"]=="ERR_WITNESS_EXTERNAL_ABSENT" and second["error_code"]=="ERR_DUPLICATE_IDEMPOTENCY" and third["error_code"]=="ERR_IDEMPOTENCY_CONFLICT"})

    payload=json.dumps(full(),ensure_ascii=False,sort_keys=True,separators=(",",":")); procs=[]
    for _ in range(2):
        p=subprocess.run([sys.executable,"-B",str(CLI)],input=payload,text=True,capture_output=True,cwd=str(ROOT),check=False); v=json.loads(p.stdout); semantic={k:x for k,x in v.items() if k not in {"started_at_utc","ended_at_utc","cli_pid","cli_started_at_utc"}}; procs.append({"exit":p.returncode,"semantic":semantic})
    rows.append({"case":"two_process_replay","semantic_equal":procs[0]["semantic"]==procs[1]["semantic"],"processes":procs,"PASS":procs[0]["semantic"]==procs[1]["semantic"]})
    p=subprocess.run([sys.executable,"-B",str(CLI)],input=json.dumps({"requests":[full(),full()]}),text=True,capture_output=True,cwd=str(ROOT),check=False); b=json.loads(p.stdout); rows.append({"case":"batch_replay","exit":p.returncode,"results":[{"status":x["status"],"error_code":x["error_code"]} for x in b["results"]],"PASS":b["results"][1]["error_code"]=="ERR_DUPLICATE_IDEMPOTENCY"})
    ledger=AuthorityLedger()
    with ThreadPoolExecutor(max_workers=12) as pool: concurrent=list(pool.map(lambda _:ledger.validate(full(),now="2026-09-17T00:00:02Z"),range(24)))
    rows.append({"case":"ledger_concurrency","present":sum(x["status"]=="present_admissible_shape" for x in concurrent),"duplicates":sum(x["error_code"]=="ERR_DUPLICATE_IDEMPOTENCY" for x in concurrent),"PASS":sum(x["status"]=="present_admissible_shape" for x in concurrent)==1 and sum(x["error_code"]=="ERR_DUPLICATE_IDEMPOTENCY" for x in concurrent)==23})
    ended=datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00","Z")
    print(json.dumps({"schema":"UP1.witness-independent-review-r3.attack.v1","pid":os.getpid(),"started_at_utc":started,"ended_at_utc":ended,"TEST_ONLY":True,"non_evidence":True,"no_publish":True,"results":rows},ensure_ascii=False,sort_keys=True,separators=(",",":")))
    return 0


if __name__ == "__main__": raise SystemExit(main())
