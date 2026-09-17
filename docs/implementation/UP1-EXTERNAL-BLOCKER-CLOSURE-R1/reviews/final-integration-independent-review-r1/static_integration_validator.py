import hashlib
import json
import pathlib
import re
import sys


ROOT = pathlib.Path.cwd()
BASE = ROOT / "docs" / "implementation" / "UP1-EXTERNAL-BLOCKER-CLOSURE-R1"
OUT = {
    "validator": "final-integration-independent-review-r1/static_integration_validator.py",
    "checks": [],
    "findings": [],
}


def load(rel):
    p = BASE / rel
    return json.loads(p.read_text(encoding="utf-8"), object_pairs_hook=unique_pairs)


def unique_pairs(pairs):
    d = {}
    for k, v in pairs:
        if k in d:
            raise ValueError(f"duplicate JSON key: {k}")
        d[k] = v
    return d


def sha256(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def check(name, passed, detail):
    OUT["checks"].append({"name": name, "passed": bool(passed), "detail": detail})
    if not passed:
        OUT["findings"].append({"id": name, "severity": "P1", "detail": detail})


def main():
    latest = {
        "W1": "reviews/W1-witness-authority-independent-review-r7",
        "W2": "reviews/W2-trust-chain-independent-review-r3",
        "W3": "reviews/W3-source-g2-environment-independent-review-r4",
        "W4": "reviews/W4-local-input-discovery-independent-review-r3",
    }
    for key, rel in latest.items():
        p = BASE / rel / "review.md"
        txt = p.read_text(encoding="utf-8")
        check(f"latest_{key}_review", "pass_limited" in txt, f"{rel}/review.md")

    root_decision = load("reviews/root-architecture-adjudication-r1/decision_matrix.json")
    root_gate = load("reviews/root-architecture-adjudication-r1/gate_state.json")
    root_dep = load("reviews/root-architecture-adjudication-r1/dependency_39_node_preservation.json")
    root_accept = load("reviews/root-architecture-adjudication-r1/acceptance_manifest.json")
    check("root_external_count", root_decision.get("usable_external_inputs") == 0,
          f"usable_external_inputs={root_decision.get('usable_external_inputs')!r}")
    check("root_fresh_s3_deferred", root_decision.get("fresh_S3") == "typed_absent/terminal_deferred/no_publish",
          f"fresh_S3={root_decision.get('fresh_S3')!r}")
    check("root_formal_credit_false", root_decision.get("formal_credit") is False,
          f"formal_credit={root_decision.get('formal_credit')!r}")
    check("root_39_nodes", root_dep.get("node_count") == 39 and root_dep.get("edges_modified") is False
          and root_dep.get("node_ids_modified") is False and root_dep.get("topology_modified") is False,
          "39-node topology preservation fields")
    check("root_no_gate_credit", root_accept.get("status") == "accepted_limited"
          and all(v is False for v in root_accept.get("credits", {}).values() if isinstance(v, bool)),
          "root acceptance/credits")
    check("root_head", root_dep.get("checkout_head") == "b2c04d8339774635aaecd73651efcdb101e01b5d",
          f"checkout_head={root_dep.get('checkout_head')!r}")

    packets = load("reviews/external-handoffs-r1/request_packets.json")
    handoff_manifest = load("reviews/external-handoffs-r1/manifest.json")
    handoff_cleanup = load("reviews/external-handoffs-r1/cleanup_inventory.json")
    check("handoff_not_sent", packets.get("not_sent") is True and handoff_manifest.get("not_sent") is True,
          "request_packets and manifest not_sent")
    check("handoff_no_mutation", packets.get("external_mutation") is False
          and handoff_manifest.get("external_mutation") is False
          and packets.get("credentials_requested") is False
          and handoff_manifest.get("credentials_requested") is False
          and packets.get("new_ad") is False and handoff_manifest.get("new_ad") is False,
          "external mutation/credentials/new AD controls")
    bad_literals = []
    for packet in packets.get("packets", []):
        text = json.dumps(packet, ensure_ascii=False)
        if re.search(r"https?://|mailto:|@[A-Za-z0-9_.-]+", text):
            bad_literals.append(packet.get("packet_id"))
    check("no_invented_endpoint", not bad_literals, f"endpoint-like literals in packets={bad_literals}")

    w1 = load("witness_authority/external_input_register.json")
    w2 = load("trust_chain/external_input_register.json")
    w3 = load("source_g2_environment/external_input_register.json")
    expected = {x["id"] for x in w1["inputs"] + w2["inputs"] + w3["inputs"]}
    handed = set()
    for packet in packets["packets"]:
        handed.update(packet.get("original_absence_ids", []))
    check("lossless_external_absence_union", expected <= handed,
          f"missing={sorted(expected-handed)} extra_traceability={sorted(handed-expected)}")
    check("four_packets", [p.get("packet_id") for p in packets.get("packets", [])]
          == ["EHP-01", "EHP-02", "EHP-03", "EHP-04"], "four packet IDs")

    schedule = load("reviews/external-handoffs-r1/conditional_schedule.json")
    required_route = ["T0", "recheck", "T1", "T2", "aggregate", "UP2-00", "UP1-04B", "UP1-04", "UP2-01"]
    ordering = schedule.get("ordering", "")
    stages = [str(s.get("stage")) for s in schedule.get("stages", [])]
    route_present = all(token in ordering for token in required_route) and all(token in stages for token in required_route)
    check("strict_formal_route", route_present,
          f"required={required_route}; ordering={ordering!r}; stages={stages}")
    check("schedule_no_new_ad", schedule.get("not_sent") is True and schedule.get("no_external_mutation") is True
          and schedule.get("no_new_ad") is True, "conditional schedule controls")

    hygiene = load("reviews/git-hygiene-r1/candidate_cleanup.json")
    gs = load("reviews/git-hygiene-r1/git_scope_snapshot.json")
    candidates = hygiene.get("candidates", [])
    check("hygiene_read_only", hygiene.get("read_only") is True and hygiene.get("no_deletions_performed") is True
          and gs.get("read_only") is True and gs.get("source_or_test_mutation_by_audit") is False,
          "hygiene read-only/no mutation")
    check("hygiene_four_raw_retain", len(candidates) == 4
          and all(c.get("owned_by_manifest") is False and c.get("recommendation") == "retain" for c in candidates),
          "four historical unowned raw retain dispositions")
    check("hygiene_head", gs.get("head") == "b2c04d8339774635aaecd73651efcdb101e01b5d",
          f"hygiene head={gs.get('head')!r}")

    # Verify stable product hashes using the handoff manifest's non-self map.
    mismatches = []
    for item in handoff_manifest.get("product_hashes_pre_manifest", []):
        p = BASE / "reviews" / "external-handoffs-r1" / item["path"]
        actual = sha256(p)
        if actual != item["sha256"]:
            mismatches.append({"path": item["path"], "expected": item["sha256"], "actual": actual})
    check("handoff_hashes", not mismatches, f"mismatches={mismatches}")
    owned = [x["path"].replace("docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/reviews/external-handoffs-r1/", "")
             for x in handoff_cleanup.get("final_exact_owned_set", [])]
    check("handoff_exact_set", sorted(owned) == sorted(handoff_manifest.get("exact_set", [])),
          f"owned={sorted(owned)} manifest={sorted(handoff_manifest.get('exact_set', []))}")

    OUT["decision"] = "rework" if OUT["findings"] else "pass_limited"
    OUT["summary"] = {
        "usable_external_inputs": 0,
        "formal_gate_credit": False,
        "fresh_s3": "typed_absent/terminal_deferred/no_publish",
        "strict_route_check": route_present,
        "read_only": True,
        "julia_s3_desc_solver_executed": False,
    }
    print(json.dumps(OUT, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if OUT["decision"] == "pass_limited" else 1


if __name__ == "__main__":
    sys.exit(main())
