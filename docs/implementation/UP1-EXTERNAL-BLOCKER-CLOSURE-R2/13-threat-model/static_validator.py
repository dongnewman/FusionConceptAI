"""Fresh-process, standard-library-only validator for the R2 threat-model package.

This validator is deliberately read-only: it parses package JSON strictly, rejects
duplicate keys, checks coverage and fail-closed/deferred semantics, and emits no
authority or promotion decision.
"""
from __future__ import annotations

import json
import pathlib
import sys
from typing import Any

ROOT = pathlib.Path(__file__).resolve().parent
EXPECTED = {f"TM-{n:02d}" for n in range(1, 21)}
REQUIRED_AR = {f"AR-{n:02d}" for n in range(1, 13)}
REQUIRED_TEXT = (
    "identity spoofing", "candidate substitution", "source substitution",
    "axis/layer confusion", "chain replacement", "algorithm downgrade",
    "revocation unavailable", "time rollback", "nonce replay",
    "sequence rollback", "idempotency replay", "TOCTOU",
    "symlink/path traversal", "manifest self-reference",
    "duplicate key/JSON ambiguity", "SBOM omission", "binary substitution",
    "environment drift", "typed_absence as pass",
)


class DuplicateKey(ValueError):
    pass


def no_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in pairs:
        if key in out:
            raise DuplicateKey(f"duplicate key: {key}")
        out[key] = value
    return out


def load(name: str) -> Any:
    path = ROOT / name
    raw = path.read_text(encoding="utf-8")
    return json.loads(raw, object_pairs_hook=no_duplicate_pairs, parse_constant=lambda x: (_ for _ in ()).throw(ValueError(f"non-finite number: {x}")))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    threat = load("threat_model.json")
    matrix = load("attack_matrix.json")
    acceptance = load("acceptance_requirements.json")
    allowed_verdicts = ["pass_limited", "rework", "block_external"]
    for item, name in ((threat, "threat"), (matrix, "matrix"), (acceptance, "acceptance")):
        require(item["status"] in allowed_verdicts, f"{name} verdict enum")
        require(item["verdict_enum"] == allowed_verdicts, f"{name} verdict set")
    require(threat["decision_semantics"]["program_exception"].find("not fail_closed") >= 0, "program_exception semantics")
    require(acceptance["evidence_state_semantics"]["program_exception"].find("not fail_closed") >= 0, "acceptance program_exception semantics")
    require(matrix["oracle_contract"]["program_exception"]["required"] is True, "matrix program_exception semantics")
    for item, name in ((threat, "threat"), (matrix, "matrix"), (acceptance, "acceptance")):
        require(item["claim_ceiling"] == "preparation_only", f"{name} claim ceiling")
        require(item["no_authority_credit"] is True, f"{name} no authority credit")
        require(item["no_publish"] is True, f"{name} no publish")

    threats = threat["threats"]
    rows = matrix["rows"]
    reqs = acceptance["requirements"]
    threat_ids = {x["id"] for x in threats}
    row_ids = {x["attack_id"] for x in rows}
    require(threat_ids == EXPECTED, f"threat coverage mismatch: {sorted(EXPECTED ^ threat_ids)}")
    require(row_ids == EXPECTED, f"matrix coverage mismatch: {sorted(EXPECTED ^ row_ids)}")
    require(len(threats) == len(threat_ids) == 20, "duplicate/missing threat rows")
    require(len(rows) == len(row_ids) == 20, "duplicate/missing attack rows")
    require(set(acceptance["global_gates"][0]["id"] for _ in [0]) == {"GATE-THREAT-COVERAGE"}, "coverage gate missing")
    ar_ids = {x["id"] for x in reqs}
    require(ar_ids == REQUIRED_AR, f"acceptance coverage mismatch: {sorted(REQUIRED_AR ^ ar_ids)}")
    require(len(reqs) == len(ar_ids) == 12, "duplicate/missing acceptance requirements")
    for row in rows:
        require(row["contradiction_status"] == "fail_closed", f"{row['attack_id']} contradiction downgrade")
        require(row["unavailable_status"] == "typed_absence", f"{row['attack_id']} unavailable state")
        require(row["unavailable_resolution"] == "terminal_deferred", f"{row['attack_id']} unavailable resolution")
        require(row["component"] and row["oracle"] and row["evidence"], f"{row['attack_id']} incomplete oracle")
    tm07 = next(x for x in threats if x["id"] == "TM-07")
    require(tm07["class"] == "revocation_unavailable", "TM-07 stable class")
    require(tm07["description_zh"], "TM-07 Chinese description")
    matrix_tm07 = next(x for x in rows if x["attack_id"] == "TM-07")
    require(matrix_tm07["class"] == "revocation_unavailable", "matrix TM-07 stable class")
    tm14 = next(x for x in threats if x["id"] == "TM-14")["expected"]
    for key in ("manifest_self_reference", "manifest_omission", "manifest_hash_mismatch", "manifest_extra"):
        require(tm14.get(key) == "fail_closed", f"TM-14 {key}")
    require(tm14.get("external_required_receipt_unavailable") == "typed_absence -> terminal_deferred", "TM-14 external receipt unavailable")
    matrix_tm14 = next(x for x in rows if x["attack_id"] == "TM-14")
    require(set(matrix_tm14["contradiction_cases"]) == {"manifest_self_reference", "manifest_omission", "manifest_hash_mismatch", "manifest_extra"}, "matrix TM-14 contradiction cases")
    for item in threats:
        expected = item["expected"]
        require(expected["no_publish"] is True, f"{item['id']} publishes")
        require("contradiction" in expected or any(token in key for token in ("invalid", "revoked", "mutation", "escape", "changed", "circular", "incomplete", "ambiguity", "omission", "substitution", "drift", "contradictory") for key in expected), f"{item['id']} contradiction mapping missing")
        mapping_keys = set(expected)
        require(any("missing" in key or "unavailable" in key or "absence" in key or "ledger" in key or "policy" in key or "atomicity" in key or "escape" in key or "drift" in key or "invalid" in key for key in mapping_keys), f"{item['id']} missing mapping")
    coverage = matrix["coverage"]
    require(set(coverage["required_attack_ids"]) == EXPECTED, "matrix required IDs")
    text = " ".join(coverage["required_topics"])
    for topic in REQUIRED_TEXT:
        require(topic in text, f"required topic absent: {topic}")
    req_attack_ids = {a for r in reqs for a in r["negative_attacks"]}
    require(EXPECTED.issubset(req_attack_ids), "acceptance negative attack coverage incomplete")
    print("UP1-R2-13 STATIC PASS")
    print("threats=20 matrix_rows=20 acceptance_requirements=12")
    print("outcomes=fail_closed|typed_absence->terminal_deferred no_publish=true")
    print("claim_ceiling=preparation_only authority_credit=false")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, KeyError, OSError, ValueError) as exc:
        print(f"UP1-R2-13 STATIC FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
