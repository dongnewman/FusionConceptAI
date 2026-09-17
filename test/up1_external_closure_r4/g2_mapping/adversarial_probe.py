"""Black-box adversarial probes for the independent R4 G2 checker.

The probes intentionally include malformed-but-self-consistent payloads.  A
probe is a finding when the checker returns a structurally accepted result
(the normal present result is ``accepted=false, decision=terminal_deferred``)
for a condition that the R4 contract says must be fail-closed.  This script
never edits the implementation directory.
"""
from __future__ import annotations

import copy
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
COMPONENT = ROOT / "tools" / "up1_external_closure_r4" / "g2_mapping"
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(COMPONENT))
from test_independent_g2_mapping import d, positive_profile  # noqa: E402
import validator  # noqa: E402


def run_case(case_id: str, description: str, payload: dict[str, Any], expected: str = "fail_closed") -> dict[str, Any]:
    result = validator.evaluate(payload)
    observed = "fail_closed" if result.get("decision") == "fail_closed" else "accepted_or_deferred"
    return {
        "case_id": case_id,
        "description": description,
        "expected": expected,
        "observed": observed,
        "decision": result.get("decision"),
        "resolution": result.get("resolution"),
        "accepted": result.get("accepted"),
        "no_publish": result.get("no_publish"),
        "formal_credit": result.get("formal_credit"),
        "error": result.get("error"),
        "finding": expected == "fail_closed" and observed != "fail_closed",
    }


def probe_duplicate_graph_endpoint_with_different_time() -> dict[str, Any]:
    item = positive_profile()
    edge = copy.deepcopy(item["evidence_graph"]["forward_edges"][0])
    edge["edge_id"] = "edge-fwd-2"
    edge["issued_at"] = "2026-09-17T00:01:00Z"
    edge["edge_sha256"] = d({k: v for k, v in edge.items() if k != "edge_sha256"})
    item["evidence_graph"]["forward_edges"].append(edge)
    item["evidence_graph"]["coverage"].update({"forward_edges": 2, "unique_forward_pairs": 2})
    item["evidence_graph"]["graph_sha256"] = d({k: v for k, v in item["evidence_graph"].items() if k != "graph_sha256"})
    item["authority_receipt"]["graph_sha256"] = item["evidence_graph"]["graph_sha256"]
    # Reverse list also has to be a complete inverse multiset to isolate the
    # duplicate endpoint-pair predicate from the bijection predicate.
    rev = copy.deepcopy(item["evidence_graph"]["reverse_edges"][0])
    rev["edge_id"] = "edge-rev-2"
    rev["issued_at"] = edge["issued_at"]
    rev["edge_sha256"] = d({k: v for k, v in rev.items() if k != "edge_sha256"})
    item["evidence_graph"]["reverse_edges"].append(rev)
    item["evidence_graph"]["coverage"].update({"reverse_edges": 2, "unique_reverse_pairs": 2})
    item["evidence_graph"]["graph_sha256"] = d({k: v for k, v in item["evidence_graph"].items() if k != "graph_sha256"})
    item["authority_receipt"]["graph_sha256"] = item["evidence_graph"]["graph_sha256"]
    return run_case("ADV-GRAPH-DUP-ENDPOINT-TIME", "same graph endpoint pair, different issued_at", item)


def probe_duplicate_mapping_endpoint_with_different_time() -> dict[str, Any]:
    item = positive_profile()
    row = copy.deepcopy(item["g2_mapping"]["mapping_rows"][0])
    row["row_id"] = "row-2"
    row["issued_at"] = "2026-09-17T00:01:00Z"
    row["row_sha256"] = d({k: v for k, v in row.items() if k != "row_sha256"})
    item["g2_mapping"]["mapping_rows"].append(row)
    reverse = copy.deepcopy(item["g2_mapping"]["reverse_rows"][0])
    reverse["row_id"] = "row-2"
    reverse["issued_at"] = row["issued_at"]
    reverse["row_sha256"] = d({k: v for k, v in reverse.items() if k != "row_sha256"})
    item["g2_mapping"]["reverse_rows"].append(reverse)
    item["g2_mapping"]["coverage"].update({"forward_rows": 2, "reverse_rows": 2, "unique_forward_pairs": 2, "unique_reverse_pairs": 2})
    item["g2_mapping"]["mapping_sha256"] = d({k: v for k, v in item["g2_mapping"].items() if k != "mapping_sha256"})
    return run_case("ADV-MAPPING-DUP-ENDPOINT-TIME", "same mapping endpoint pair, different issued_at", item)


def probe_unknown_status() -> dict[str, Any]:
    item = positive_profile()
    item["status"] = "made_up_status"
    return run_case("ADV-UNKNOWN-STATUS", "unknown present status token", item)


def probe_conflicting_aliases() -> dict[str, Any]:
    item = positive_profile()
    item["mapping"] = {"candidate_id": "candidate://foreign", "ambiguity_decision": "none"}
    item["authority"] = copy.deepcopy(item["authority_receipt"])
    return run_case("ADV-CONFLICTING-ALIASES", "R3 g2_mapping and standalone mapping aliases disagree", item)


def probe_forged_profile_source_digest() -> dict[str, Any]:
    item = positive_profile()
    item["source_identity_sha256"] = "f" * 64
    return run_case("ADV-PROFILE-SOURCE-DIGEST", "profile source digest disagrees with source_identity", item)


def main() -> int:
    started = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    cases = [
        probe_duplicate_graph_endpoint_with_different_time(),
        probe_duplicate_mapping_endpoint_with_different_time(),
        probe_unknown_status(),
        probe_conflicting_aliases(),
        probe_forged_profile_source_digest(),
    ]
    out = {
        "schema": "UP1.g2-independent-mapping-r4.adversarial-probe.v1",
        "started_at_utc": started,
        "ended_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "pid": os.getpid(),
        "component": str(COMPONENT),
        "cases": cases,
        "finding_count": sum(1 for case in cases if case["finding"]),
        "conservative_decision": "fail_closed_gap" if any(case["finding"] for case in cases) else "no_gap_observed",
        "no_publish": True,
        "formal_credit": "none",
    }
    print(json.dumps(out, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
