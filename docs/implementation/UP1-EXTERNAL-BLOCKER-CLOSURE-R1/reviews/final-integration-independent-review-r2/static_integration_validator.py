from __future__ import annotations

import hashlib
import json
import pathlib
import re
import sys


ROOT = pathlib.Path.cwd()
BASE = ROOT / "docs" / "implementation" / "UP1-EXTERNAL-BLOCKER-CLOSURE-R1"
HANDOFF = BASE / "reviews" / "external-handoffs-r1"
RESULT = {"checks": [], "findings": []}


def unique_pairs(items):
    result = {}
    for key, value in items:
        if key in result:
            raise ValueError(f"duplicate_json_key:{key}")
        result[key] = value
    return result


def load(path):
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_pairs)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(name, passed, detail):
    item = {"name": name, "passed": bool(passed), "detail": detail}
    RESULT["checks"].append(item)
    if not passed:
        RESULT["findings"].append({"id": name, "severity": "P1", "detail": detail})


def main():
    latest = {
        "W1": "reviews/W1-witness-authority-independent-review-r7",
        "W2": "reviews/W2-trust-chain-independent-review-r3",
        "W3": "reviews/W3-source-g2-environment-independent-review-r4",
        "W4": "reviews/W4-local-input-discovery-independent-review-r3",
    }
    for key, rel in latest.items():
        text = (BASE / rel / "review.md").read_text(encoding="utf-8")
        check(f"latest_{key}_pass_limited", "pass_limited" in text, rel + "/review.md")

    decision = load(BASE / "reviews/root-architecture-adjudication-r1/decision_matrix.json")
    gate = load(BASE / "reviews/root-architecture-adjudication-r1/gate_state.json")
    dep = load(BASE / "reviews/root-architecture-adjudication-r1/dependency_39_node_preservation.json")
    accept = load(BASE / "reviews/root-architecture-adjudication-r1/acceptance_manifest.json")
    check("zero_usable_external_inputs", decision.get("usable_external_inputs") == 0 and gate.get("usable_external_inputs") == 0,
          f"decision={decision.get('usable_external_inputs')!r}; gate={gate.get('usable_external_inputs')!r}")
    check("fresh_s3_absence", decision.get("fresh_S3") == "typed_absent/terminal_deferred/no_publish"
          and gate.get("fresh_s3", {}).get("G1") == "typed_absent"
          and gate.get("fresh_s3", {}).get("G2") == "typed_absent"
          and gate.get("fresh_s3", {}).get("G3") == "typed_absent"
          and gate.get("fresh_s3", {}).get("terminal") == "terminal_deferred"
          and gate.get("fresh_s3", {}).get("publish") is False,
          "fresh S3 G1/G2/G3 typed_absent, terminal_deferred, no_publish")
    check("root_no_formal_credit", decision.get("formal_credit") is False
          and dep.get("credit") is False
          and all(v is False or v == 0 for v in accept.get("credits", {}).values()), "root credit fields")
    check("dag_head_preserved", dep.get("node_count") == 39 and dep.get("edges_modified") is False
          and dep.get("node_ids_modified") is False and dep.get("topology_modified") is False
          and dep.get("checkout_head") == "b2c04d8339774635aaecd73651efcdb101e01b5d", "39-node DAG and HEAD")

    packets = load(HANDOFF / "request_packets.json")
    manifest = load(HANDOFF / "manifest.json")
    cleanup = load(HANDOFF / "cleanup_inventory.json")
    check("handoff_controls", packets.get("not_sent") is True and manifest.get("not_sent") is True
          and packets.get("external_mutation") is False and manifest.get("external_mutation") is False
          and packets.get("credentials_requested") is False and manifest.get("credentials_requested") is False
          and packets.get("new_ad") is False and manifest.get("new_ad") is False, "not_sent/no mutation/no credentials/no AD")
    text = json.dumps(packets, ensure_ascii=False)
    check("no_invented_endpoints", not re.search(r"https?://|mailto:|@[A-Za-z0-9_.-]+", text),
          "endpoint-like literals absent from packet JSON")

    w1 = load(BASE / "witness_authority/external_input_register.json")
    w2 = load(BASE / "trust_chain/external_input_register.json")
    w3 = load(BASE / "source_g2_environment/external_input_register.json")
    expected_absence = {x["id"] for x in w1["inputs"] + w2["inputs"] + w3["inputs"]}
    received_absence = set()
    for packet in packets.get("packets", []):
        received_absence.update(packet.get("original_absence_ids", []))
    check("lossless_absence_coverage", expected_absence <= received_absence,
          f"missing={sorted(expected_absence - received_absence)} count={len(expected_absence)}")
    check("four_packets", [p.get("packet_id") for p in packets.get("packets", [])] == ["EHP-01", "EHP-02", "EHP-03", "EHP-04"],
          "packet IDs")

    schedule = load(HANDOFF / "conditional_schedule.json")
    route = ["T0", "authority_recheck", "T1", "T2", "aggregate", "UP2-00", "UP1-04B", "UP1-04", "UP2-01"]
    stages = schedule.get("stages", [])
    stage_ids = [s.get("stage") for s in stages]
    transitions = all(s.get("success_transition") == (route[i + 1] if i + 1 < len(route) else "parent_architect_acceptance_decision_only")
                      for i, s in enumerate(stages))
    requirements = all(isinstance(s.get("requires"), list) and len(s["requires"]) > 0 for s in stages)
    failures = all(isinstance(s.get("failure_transition"), str) and s["failure_transition"] for s in stages)
    receipt_driven = all(any("receipt" in str(req).lower() or "digest" in str(req).lower() or "hash" in str(req).lower()
                            for req in s["requires"]) for s in stages)
    check("full_route", schedule.get("route") == route and stage_ids == route
          and schedule.get("ordering", "").startswith("T0 -> authority_recheck -> T1 -> T2 -> aggregate -> UP2-00 -> UP1-04B -> UP1-04 -> UP2-01"),
          f"route={schedule.get('route')}; stages={stage_ids}")
    check("eight_adjacent_transitions", len(route) - 1 == 8 and transitions,
          f"count={len(route)-1}; transitions={transitions}")
    check("stage_requires_receipt_driven", requirements and failures and receipt_driven,
          f"requires={requirements}; success={transitions}; failure={failures}; receipt_driven={receipt_driven}")
    check("schedule_boundaries", schedule.get("calendar_dates") == "not_assigned"
          and schedule.get("status") == "preparation_only"
          and schedule.get("not_sent") is True
          and schedule.get("no_external_mutation") is True
          and schedule.get("no_new_ad") is True
          and schedule.get("formal_credit") is False, "no fixed dates/no gate credit")

    # Verify every declared exact-set path and every non-self manifest/cleanup hash.
    actual = sorted(p.relative_to(HANDOFF).as_posix() for p in HANDOFF.rglob("*") if p.is_file())
    declared = sorted(manifest.get("exact_set", []))
    check("handoff_exact_set", actual == declared, f"actual_count={len(actual)} declared_count={len(declared)}")
    manifest_hash_mismatches = []
    for item in manifest.get("product_hashes_pre_manifest", []):
        p = HANDOFF / item["path"]
        if not p.exists() or digest(p) != item["sha256"]:
            manifest_hash_mismatches.append(item["path"])
    check("manifest_hashes", not manifest_hash_mismatches, f"mismatches={manifest_hash_mismatches}")
    cleanup_map = cleanup.get("current_artifact_hash_map", {})
    cleanup_mismatches = [n for n, h in cleanup_map.items() if not (HANDOFF / n).exists() or digest(HANDOFF / n) != h]
    check("cleanup_hashes", not cleanup_mismatches, f"mismatches={cleanup_mismatches}")
    dynamic = {n for n in actual if n.startswith("repair_r2/raw/")}
    check("cleanup_hash_key_set", set(cleanup_map) == set(actual) - {"manifest.json", "cleanup_inventory.json"} - dynamic,
          f"map={len(cleanup_map)} dynamic_raw={len(dynamic)} actual={len(actual)}")
    check("no_pycache_or_temp", not any(p.name == "__pycache__" or p.suffix == ".pyc" or p.suffix in {".tmp", ".bak"}
                                        for p in HANDOFF.rglob("*")), "handoff package temporary scan")

    hygiene = load(BASE / "reviews/git-hygiene-r1/candidate_cleanup.json")
    gs = load(BASE / "reviews/git-hygiene-r1/git_scope_snapshot.json")
    candidates = hygiene.get("candidates", [])
    check("hygiene_read_only", hygiene.get("read_only") is True and hygiene.get("no_deletions_performed") is True
          and gs.get("read_only") is True and gs.get("source_or_test_mutation_by_audit") is False, "hygiene controls")
    check("four_historical_raw_retain", len(candidates) == 4
          and all(c.get("owned_by_manifest") is False and c.get("recommendation") == "retain" for c in candidates), "raw retain")
    check("hygiene_head", gs.get("head") == "b2c04d8339774635aaecd73651efcdb101e01b5d", "HEAD")

    RESULT["decision"] = "rework" if RESULT["findings"] else "pass_limited"
    RESULT["summary"] = {"usable_external_inputs": 0, "formal_credit": False,
                          "fresh_s3": "typed_absent/terminal_deferred/no_publish",
                          "adjacent_transitions": 8, "read_only": True,
                          "julia_s3_desc_solver_executed": False}
    print(json.dumps(RESULT, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if RESULT["decision"] == "pass_limited" else 1


if __name__ == "__main__":
    sys.exit(main())
