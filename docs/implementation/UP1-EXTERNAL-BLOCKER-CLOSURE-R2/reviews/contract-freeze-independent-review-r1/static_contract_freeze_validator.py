import hashlib
import json
import os
import subprocess
import sys
from collections import defaultdict, deque
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
FREEZE = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/00-contract-freeze"
R2 = FREEZE.parent
PROTO = R2 / "14-review-protocol"

STARTED = datetime.now(timezone.utc)
CHECKS = []
DETAILS = {}


def check(name, condition, detail=None):
    ok = bool(condition)
    CHECKS.append((name, ok))
    if detail is not None:
        DETAILS[name] = detail
    print(f"{name}={'PASS' if ok else 'FAIL'}")
    return ok


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def main():
    names = ["work_orders.json", "frozen_inputs.json", "interface_contracts.json",
             "ownership.json", "gate_ceiling.json", "manifest.json", "cleanup_inventory.json"]
    objs = {}
    parse_ok = True
    for name in names:
        try:
            objs[name] = read_json(FREEZE / name)
            check(f"JSON_{name}", True)
        except Exception as exc:
            parse_ok = False
            check(f"JSON_{name}", False, repr(exc))
    if not parse_ok:
        return 1
    manifest = objs["manifest.json"]
    frozen = objs["frozen_inputs.json"]
    work = objs["work_orders.json"]
    contracts = objs["interface_contracts.json"]
    ownership = objs["ownership.json"]
    ceiling = objs["gate_ceiling.json"]
    cleanup = objs["cleanup_inventory.json"]

    check("HEAD", git("rev-parse", "HEAD") == manifest["baseline_head"],
          {"actual": git("rev-parse", "HEAD"), "expected": manifest["baseline_head"]})
    check("R2_EXACT_ROOT", sorted(p.name for p in FREEZE.iterdir() if p.is_file()) == sorted(names))
    check("R2_EXACT_RAW", sorted(str(p.relative_to(FREEZE)).replace("\\", "/") for p in (FREEZE / "raw").iterdir() if p.is_file()) == sorted(manifest["validation_raw_files"]))
    check("R2_SCOPE", manifest["write_scope"] == "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/00-contract-freeze/**")
    check("R2_SELF_EXCLUSIONS", manifest["self_hash_exclusions"] == ["manifest.json", "cleanup_inventory.json"])

    artifact_mismatches = []
    for name, expected in manifest["artifacts"].items():
        p = FREEZE / name
        actual = {"sha256": sha(p), "bytes": p.stat().st_size}
        if actual != expected:
            artifact_mismatches.append({"path": name, "expected": expected, "actual": actual})
    check("R2_ARTIFACT_HASHES", not artifact_mismatches, artifact_mismatches)
    clean_mismatches = []
    for name, expected in cleanup["artifact_hashes"].items():
        actual = sha(FREEZE / name)
        if actual != expected:
            clean_mismatches.append({"path": name, "expected": expected, "actual": actual})
    check("R2_CLEANUP_HASHES", not clean_mismatches, clean_mismatches)
    raw_mismatches = []
    for name, expected in cleanup["raw_receipt_hashes"].items():
        actual = sha(FREEZE / name)
        if actual != expected:
            raw_mismatches.append({"path": name, "expected": expected, "actual": actual})
    check("R2_RAW_HASHES", not raw_mismatches, raw_mismatches)

    # Recompute the six planning-input and three AD56 working-tree hashes.
    input_mismatches = []
    for row in frozen["planning_inputs"]:
        p = ROOT / row["path"]
        actual_raw = sha(p)
        actual_oid = git("hash-object", "--path=" + row["path"], str(p))
        if actual_raw != row["raw_sha256"] or actual_oid != row["git_blob_oid"]:
            input_mismatches.append({"path": row["path"], "raw": actual_raw, "oid": actual_oid,
                                     "expected_raw": row["raw_sha256"], "expected_oid": row["git_blob_oid"]})
    check("PLANNING_INPUT_HASHES", not input_mismatches, input_mismatches)
    ad56_mismatches = []
    for row in frozen["ad56_dirty_scope"]["paths"]:
        p = ROOT / row["path"]
        actual_raw = sha(p)
        actual_oid = git("hash-object", "--path=" + row["path"], str(p))
        if actual_raw != row["raw_sha256"] or actual_oid != row["working_blob_oid"]:
            ad56_mismatches.append({"path": row["path"], "raw": actual_raw, "oid": actual_oid,
                                    "expected_raw": row["raw_sha256"], "expected_oid": row["working_blob_oid"]})
    check("AD56_THREE_FACTORY_HASHES", not ad56_mismatches, ad56_mismatches)

    # Current status is deliberately re-read; later user/agent dirty work may make
    # the frozen pre-review count differ, which is reported as an observation.
    status_raw = subprocess.check_output(["git", "status", "--porcelain=v1"], cwd=ROOT)
    status_lines = status_raw.decode("utf-8").splitlines()
    status_sha = hashlib.sha256(status_raw).hexdigest()
    status_observation = {"current_line_count": len(status_lines), "current_raw_bytes": len(status_raw),
                          "current_raw_sha256": status_sha,
                          "frozen_line_count": frozen["worktree"]["status_line_count"],
                          "frozen_sha256": frozen["worktree"]["status_sha256"],
                          "matches": len(status_lines) == frozen["worktree"]["status_line_count"] and status_sha == frozen["worktree"]["status_sha256"]}
    DETAILS["WORKTREE_STATUS_RECOMPUTE"] = status_observation
    check("WORKTREE_STATUS_RECOMPUTE", True, status_observation)
    check("WORKTREE_STATUS_DRIFT_IS_NOT_FREEZE_MUTATION", any("UP1-EXTERNAL-BLOCKER-CLOSURE-R2" in x for x in status_lines), status_observation)

    # 39-node task manifest and acyclic dependencies.
    tm = read_json(ROOT / "docs/v4_multitopology_generation/task_manifest.json")
    tasks = tm["tasks"]
    ids = [t["id"] for t in tasks]
    deps = {t["id"]: list(t.get("depends_on", [])) for t in tasks}
    missing = sorted({d for ds in deps.values() for d in ds if d not in deps})
    indegree = {i: 0 for i in ids}
    children = defaultdict(list)
    for node, ds in deps.items():
        for d in ds:
            if d in indegree:
                indegree[node] += 1
                children[d].append(node)
    q = deque(i for i, n in indegree.items() if n == 0)
    visited = []
    while q:
        n = q.popleft(); visited.append(n)
        for c in children[n]:
            indegree[c] -= 1
            if indegree[c] == 0: q.append(c)
    check("TASK_MANIFEST_39_UNIQUE", len(tasks) == 39 and len(set(ids)) == 39)
    check("TASK_MANIFEST_DEPENDENCIES", not missing and len(visited) == 39, {"missing": missing, "toposort": len(visited)})
    check("R01_R10_REQUIREMENTS", tm["goal"]["requirements"] == [f"R{i:02d}" for i in range(1, 11)])
    check("R01_R10_OPEN", tm["goal"]["credible_candidate_count"] == 0 and tm["goal"]["discovery_goal_achieved"] is False)
    check("TASK_MANIFEST_HASH", sha(ROOT / "docs/v4_multitopology_generation/task_manifest.json") == next(x["raw_sha256"] for x in frozen["planning_inputs"] if x["path"].endswith("task_manifest.json")))

    route = work["formal_route"]
    expected_route = ["T0", "authority_recheck", "T1", "T2", "aggregate", "UP2-00", "UP1-04B", "UP1-04", "UP2-01"]
    check("FORMAL_ROUTE", route == expected_route and ceiling["route"] == expected_route)
    component_by_id = {x["id"]: x for x in work["components"]}
    transitions_ok = all(route[i] in component_by_id[route[i + 1]].get("depends_on", [])
                         for i in range(len(route) - 1))
    check("FORMAL_ROUTE_TRANSITIONS", transitions_ok, {"count": len(route)-1})
    statuses = {x["id"]: x["status"] for x in work["components"]}
    check("ROUTE_LOCKS", all(statuses.get(x) in {"locked", "required_before_T1"} for x in expected_route))
    check("DAG_39_DECLARATION", work["dag"]["node_count"] == 39 and work["dag"]["changed"] is False)

    # Interface and absence semantics.
    absence = set(contracts["absence_types"])
    needed_absence = {"typed_absent", "terminal_deferred", "not_applicable", "program_exception", "fail_closed"}
    check("INTERFACE_ABSENCE_TYPES", absence == needed_absence)
    rules = contracts["rules"]
    check("INTERFACE_STATUS_SEMANTICS", rules["unknown"] == "unknown external facts are typed_absent, never null-as-present" and rules["contradiction"] == "structural mismatch is deterministic fail_closed" and rules["fault"] == "unexpected tool/runtime fault is program_exception and cannot promote")
    check("INTERFACE_COMMON_FIELDS", {"status", "claim_ceiling", "receipt", "canonical_sha256", "four_axes"}.issubset(contracts["common_fields"]))
    check("INTERFACE_UNIQUE_IDS", len({x["id"] for x in contracts["interfaces"]}) == len(contracts["interfaces"]))
    check("NO_SYNTHETIC_ABSENCE_PROMOTION", "typed absence to present child" in contracts["forbidden_promotions"])
    check("G123_TYPED_ABSENT_TERMINAL", ceiling["external_input_state"] == {"usable_count": 0, "G1": "typed_absent", "G2": "typed_absent", "G3": "typed_absent", "terminal": "terminal_deferred", "publish": False})
    check("FAIL_CLOSED_SCOPE", ownership["scope_violation"] == "fail_closed; stop and preserve evidence; do not delete or overwrite out-of-scope material")

    # Ownership and write isolation.
    file_owners = ownership["file_owners"]
    check("OWNERSHIP_EXACT_SET", set(file_owners) == set(cleanup["owned_exact_set"]))
    check("OWNERSHIP_MUTUAL_EXCLUSION", not (set(file_owners) & {"reviews/contract-freeze-independent-review-r1/**"}) and ownership["reviewer"] != ownership["owner"])
    check("PROTECTED_PATHS", all(x in ownership["protected_paths"] for x in ["src/**", "test/**", "39-node task_manifest.json", "AD55/**", "AD56/**"]))
    check("NO_EXTERNAL_INPUTS", manifest["claims"]["external_inputs"] == 0 and frozen["r1_root_final_acceptance"]["usable_external_inputs"] == 0)

    # Review protocol controls: all protocol-only output is test-only/non-evidence,
    # and heavy execution/formal suites remain forbidden or future-locked.
    proto_ok = True
    try:
        ec = read_json(PROTO / "evidence_contract.json")
        matrix = read_json(PROTO / "test_matrix.json")
        proto_manifest = read_json(PROTO / "manifest.json")
        proto_ok = ec["labels"] == {"TEST_ONLY": True, "non_evidence": True, "claim_ceiling": "contract_software_preparation_only"}
        proto_ok = proto_ok and matrix["labels"] == {"TEST_ONLY": True, "non_evidence": True}
        proto_ok = proto_ok and matrix["heavy_lane"]["default"] == "forbidden"
        proto_ok = proto_ok and all("forbidden_this_round" == x.get("status") for x in matrix["rows"] if x["id"].startswith("B00") or x["id"].startswith("B04"))
        proto_ok = proto_ok and proto_manifest["labels"] == {"TEST_ONLY": True, "non_evidence": True}
    except Exception as exc:
        proto_ok = False; DETAILS["PROTOCOL_LABELS"] = repr(exc)
    check("TEST_ONLY_NON_EVIDENCE", proto_ok)
    check("NO_FORMAL_CREDIT", manifest["claims"]["formal_credit"] is False and all(v is False for v in ceiling["credits"].values() if isinstance(v, bool)) and ceiling["formal_b00"]["status"] == "pending" and ceiling["formal_b04"]["status"] == "pending")
    check("SERIAL_HEAVY_RECOMPUTE", work["parallel_policy"]["heavy_recompute"] == "one serialized lane" and work["parallel_policy"]["formal_sequence"] == "must remain ordered; parallel preparation cannot unlock successors")
    check("NO_HEAVY_EXECUTION_AUTHORIZATION", proto_ok and matrix["heavy_lane"]["forbidden"] == ["DESC", "solver", "mesh", "provider", "heavy Julia", "external operation"])

    overall = all(ok for _, ok in CHECKS)
    print(f"CHECKS={sum(1 for _, ok in CHECKS if ok)}/{len(CHECKS)}")
    print(f"PID={os.getpid()}")
    print(f"PARENT_PID={os.getppid()}")
    print(f"STARTED_UTC={STARTED.isoformat().replace('+00:00','Z')}")
    ended = datetime.now(timezone.utc)
    print(f"ENDED_UTC={ended.isoformat().replace('+00:00','Z')}")
    print("EXIT_CODE=0" if overall else "EXIT_CODE=1")
    return 0 if overall else 1


if __name__ == "__main__":
    sys.exit(main())
