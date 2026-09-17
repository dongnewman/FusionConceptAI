"""Independent metadata-only validator for W4 repair R1."""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
HEX64 = re.compile(r"^[0-9a-f]{64}$")
UPSTREAM = {
    "W1": ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/witness_authority/external_input_register.json",
    "W2": ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/trust_chain/external_input_register.json",
    "W3": ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/source_g2_environment/external_input_register.json",
}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def main() -> int:
    failures: list[str] = []
    inventory = load(HERE / "candidate_inventory.json")
    excluded = load(HERE / "excluded_inventory.json")
    delta = load(HERE / "absence_delta.json")
    ledger = load(HERE / "run_ledger.json")
    manifest = load(HERE / "manifest.json")
    raw_path = HERE / inventory["metadata_scan"]["raw"]
    raw = []
    for line_no, line in enumerate(raw_path.read_text(encoding="utf-8").splitlines(), 1):
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            failures.append(f"raw_json:{line_no}")
            continue
        raw.append(row)
    raw_by_path = {row.get("path"): row for row in raw}
    if len(raw_by_path) != len(raw):
        failures.append("raw_duplicate_paths")
    if inventory.get("candidate_summary", {}).get("candidate_count") != len(inventory.get("candidates", [])):
        failures.append("candidate_count")
    excluded_universe = set(inventory.get("scan_scope", {}).get("excluded_universe", []))
    if "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/reviews/**" not in excluded_universe or "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/local_input_discovery/**" not in excluded_universe:
        failures.append("excluded_universe")
    candidate_paths = set()
    excluded_paths = set()
    for item in inventory.get("candidates", []):
        path_text = item.get("path", "")
        candidate_paths.add(path_text)
        path = (ROOT / path_text).resolve()
        try:
            path.relative_to(ROOT.resolve())
        except ValueError:
            failures.append(f"candidate_outside_repo:{path_text}")
            continue
        if not path.is_file():
            failures.append(f"candidate_missing:{path_text}")
            continue
        if item.get("bytes") != path.stat().st_size:
            failures.append(f"candidate_bytes:{path_text}")
        if item.get("sha256") != sha256(path):
            failures.append(f"candidate_hash:{path_text}")
        if not isinstance(item.get("type"), str) or not isinstance(item.get("producer"), str) or not isinstance(item.get("authority"), str):
            failures.append(f"candidate_field_type:{path_text}")
        if item.get("signature_verification_feasibility") not in {"none", "schema_only", "not_attempted_metadata_only"}:
            failures.append(f"candidate_signature_enum:{path_text}")
        for flag in ("production", "usable", "sensitive_unopened", "content_emitted"):
            if not isinstance(item.get(flag), bool):
                failures.append(f"candidate_bool:{path_text}:{flag}")
        if item.get("production") is not False or item.get("usable") is not False or item.get("content_emitted") is not False or not item.get("why_not"):
            failures.append(f"candidate_promotion:{path_text}")
        if path_text not in raw_by_path or raw_by_path[path_text].get("classification") != "candidate":
            failures.append(f"candidate_raw_crosscheck:{path_text}")
    for item in excluded.get("records", []):
        path_text = item.get("path", "")
        excluded_paths.add(path_text)
        path = (ROOT / path_text).resolve()
        try:
            path.relative_to(ROOT.resolve())
        except ValueError:
            failures.append(f"excluded_outside_repo:{path_text}")
            continue
        if not path.is_file():
            failures.append(f"excluded_missing:{path_text}")
            continue
        if item.get("bytes") != path.stat().st_size:
            failures.append(f"excluded_bytes:{path_text}")
        if item.get("sha256") != sha256(path):
            failures.append(f"excluded_hash:{path_text}")
        if not isinstance(item.get("excluded_reason"), str) or item.get("content_emitted") is not False:
            failures.append(f"excluded_metadata:{path_text}")
        if path_text not in raw_by_path or raw_by_path[path_text].get("classification") != "excluded":
            failures.append(f"excluded_raw_crosscheck:{path_text}")
    if candidate_paths & excluded_paths or candidate_paths | excluded_paths != set(raw_by_path):
        failures.append("candidate_excluded_partition")
    for required in ("repo_root", "head", "files", "exact_file_set"):
        if required not in manifest:
            failures.append(f"manifest_missing:{required}")
    actual_files = {path.relative_to(HERE).as_posix() for path in HERE.rglob("*") if path.is_file()}
    if set(manifest.get("files", [])) != actual_files or manifest.get("exact_file_set") is not True:
        failures.append("manifest_exact_file_set")
    if delta.get("changed_inputs") is not False or delta.get("new_real_inputs") != [] or delta.get("crosswalk_complete") is not True:
        failures.append("delta_state")
    crosswalk = delta.get("crosswalk", [])
    expected_ids = set()
    for scope, path in UPSTREAM.items():
        source = load(path)
        for row in source.get("inputs", []):
            expected_ids.add(f"W4-{scope}-{row['id']}")
    if len(crosswalk) != len(expected_ids) or {row.get("crosswalk_id") for row in crosswalk} != expected_ids:
        failures.append("crosswalk_coverage")
    for row in crosswalk:
        for field in ("source_id", "state", "provider", "owner", "responsible_party", "authoritative_source", "authority_ref", "recovery_condition", "expiry_or_revocation"):
            if not isinstance(row.get(field), str) or not row[field]:
                failures.append(f"crosswalk_field:{row.get('crosswalk_id')}:{field}")
        if row.get("state") != "typed_absent":
            failures.append(f"crosswalk_state:{row.get('crosswalk_id')}")
    if ledger.get("sensitive_unopened") != []:
        failures.append("ledger_sensitive")
    result = {
        "schema": "UP1.W4.local-input-discovery.validation-receipt.v2",
        "status": "pass" if not failures else "fail",
        "failures": failures,
        "candidate_count": len(candidate_paths),
        "excluded_count": len(excluded_paths),
        "raw_hit_count": len(raw),
        "crosswalk_count": len(crosswalk),
        "changed_inputs": delta.get("changed_inputs"),
        "upstream_register_mutated": delta.get("no_upstream_register_mutation") is not True,
    }
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
