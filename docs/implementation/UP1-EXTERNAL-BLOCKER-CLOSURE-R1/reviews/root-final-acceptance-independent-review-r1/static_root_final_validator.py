from __future__ import annotations

import hashlib
import json
import pathlib
import re
import sys


ROOT = pathlib.Path.cwd()
BASE = ROOT / "docs" / "implementation" / "UP1-EXTERNAL-BLOCKER-CLOSURE-R1"
FINAL = BASE / "reviews" / "root-final-acceptance-r1"
R2 = BASE / "reviews" / "final-integration-independent-review-r2"
RESULT = {"checks": [], "findings": []}


def unique_pairs(items):
    d = {}
    for k, v in items:
        if k in d:
            raise ValueError(f"duplicate_json_key:{k}")
        d[k] = v
    return d


def load(path):
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_pairs)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(name, passed, detail):
    RESULT["checks"].append({"name": name, "passed": bool(passed), "detail": detail})
    if not passed:
        RESULT["findings"].append({"id": name, "severity": "P1", "detail": detail})


def main():
    acceptance = load(FINAL / "acceptance_manifest.json")
    cleanup = load(FINAL / "cleanup_inventory.json")
    scope = load(FINAL / "scope_matrix.json")
    owners = load(FINAL / "external_inputs_and_owners.json")
    gates = load(FINAL / "gate_and_next_trigger.json")

    actual = sorted(p.relative_to(FINAL).as_posix() for p in FINAL.rglob("*") if p.is_file())
    owned = sorted(cleanup.get("owned_exact_set", []))
    declared = sorted(acceptance.get("products_exact_set", []))
    check("final_exact_owned_set", actual == owned == declared,
          f"actual={len(actual)} owned={len(owned)} declared={len(declared)}")
    hash_bad = []
    for name, expected in acceptance.get("stable_hashes", {}).items():
        p = FINAL / name
        if not p.exists() or sha(p) != expected:
            hash_bad.append(name)
    check("final_stable_hashes", not hash_bad, f"mismatches={hash_bad}")
    cleanup_bad = []
    for name, expected in cleanup.get("stable_artifact_hash_map", {}).items():
        p = FINAL / name
        if not p.exists() or sha(p) != expected:
            cleanup_bad.append(name)
    check("final_cleanup_hashes", not cleanup_bad, f"mismatches={cleanup_bad}")
    check("final_self_exclusions", acceptance.get("products_exact_set", []) and
          set(acceptance.get("stable_hashes", {})) == set(acceptance.get("products_exact_set", [])) - {"acceptance_manifest.json", "cleanup_inventory.json"}
          and set(cleanup.get("stable_artifact_hash_map", {})) == set(acceptance.get("stable_hashes", {})),
          "six stable non-self artifacts")
    check("final_no_delete", cleanup.get("deleted") == [] and cleanup.get("glob_used") is False
          and cleanup.get("semantic_change") is False and cleanup.get("formal_credit") is False,
          "cleanup is non-destructive and documentation-only")

    check("r2_consistent", acceptance.get("review_basis", [])[-1] == "final integration R2 pass_limited"
          and scope.get("final_integration", {}).get("status") == "pass_limited"
          and scope.get("final_integration", {}).get("formal_credit") is False,
          "root-final basis matches final integration R2")
    r2_review = (R2 / "review.md").read_text(encoding="utf-8")
    check("r2_review_path_and_decision", "pass_limited" in r2_review and "final-integration-independent-review-r2" in str(R2),
          str(R2 / "review.md"))

    check("external_inputs_blocked", acceptance.get("external_inputs", {}).get("usable_count") == 0
          and acceptance.get("external_inputs", {}).get("state") == "typed_absent"
          and acceptance.get("external_inputs", {}).get("terminal") == "terminal_deferred"
          and acceptance.get("external_inputs", {}).get("no_publish") is True
          and owners.get("usable_external_inputs") == 0,
          "zero usable inputs and typed absence")
    check("no_new_ad_no_s3_rerun", "unchanged" in (BASE / "reviews/root-architecture-adjudication-r1/adjudication.md").read_text(encoding="utf-8")
          and "no new AD" in (BASE / "reviews/root-architecture-adjudication-r1/adjudication.md").read_text(encoding="utf-8")
          and "no S3 rerun" in (FINAL / "decision.md").read_text(encoding="utf-8"),
          "unchanged input policy")

    owner_rows = owners.get("packages", [])
    check("four_typed_absent_owners", len(owner_rows) == 4
          and all(r.get("owner") == "typed_absent" and r.get("authority_channel") == "typed_absent" for r in owner_rows),
          "four responsibility owners/channels remain typed_absent")
    handoff = scope.get("external_handoffs", {})
    check("handoff_not_sent", handoff.get("sent") is False and handoff.get("formal_credit") is False
          and "not_sent" in (FINAL / "decision.md").read_text(encoding="utf-8"), "not_sent/no credit")
    owner_text = json.dumps(owners, ensure_ascii=False)
    check("no_invented_channels", not re.search(r"https?://|mailto:|@[A-Za-z0-9_.-]+", owner_text),
          "no endpoint-like owner literals")

    route = ["T0", "authority_recheck", "T1", "T2", "aggregate", "UP2-00", "UP1-04B", "UP1-04", "UP2-01"]
    check("formal_route", gates.get("formal_route") == route and " → ".join(route) in (FINAL / "decision.md").read_text(encoding="utf-8"),
          f"route={gates.get('formal_route')}")
    check("gates_open", all(gates.get("gates", {}).get(k) in {"locked", "required", "open"} for k in route + ["B00", "B04", "R01-R10", "L4", "parent"])
          and all(v is False or v == 0 for v in gates.get("credits", {}).values()), "formal gates/credits remain open")
    check("dag_preserved", gates.get("preservation", {}).get("node_count") == 39
          and gates.get("preservation", {}).get("dag_changed") is False
          and gates.get("preservation", {}).get("task_manifest_changed") is False
          and gates.get("preservation", {}).get("protected_plans_unchanged") is True, "39-node preservation")

    m5_manifest = load(ROOT / "docs/implementation/UP3-EARLY-PREPARATION/M5-CHAIN-REPLAY-R1/manifest.json")
    m5_receipt = load(ROOT / "docs/implementation/UP3-EARLY-PREPARATION/M5-CHAIN-REPLAY-R1/validation_receipt.json")
    check("m5_c_deferred_no_credit", m5_manifest.get("layers", {}).get("C") == "deferred_performance_blocked"
          and m5_receipt.get("status") == "partial_chain_C_deferred_performance_blocked"
          and scope.get("m5_c", {}).get("formal_credit") is False
          and gates.get("credits", {}).get("M5-C") is False, "M5-C boundary")
    check("runtime_not_run", all(acceptance.get("runtime", {}).get(k) == "not_run" for k in ["julia", "S3", "DESC", "solver"]),
          "no Julia/S3/DESC/solver")

    RESULT["decision"] = "rework" if RESULT["findings"] else "pass_limited"
    RESULT["summary"] = {"usable_external_inputs": 0, "up1_blockers_resolved": False,
                          "formal_credit": False, "route_transition_count": 8,
                          "m5_c": "deferred_performance_blocked", "read_only": True}
    print(json.dumps(RESULT, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if RESULT["decision"] == "pass_limited" else 1


if __name__ == "__main__":
    sys.exit(main())
