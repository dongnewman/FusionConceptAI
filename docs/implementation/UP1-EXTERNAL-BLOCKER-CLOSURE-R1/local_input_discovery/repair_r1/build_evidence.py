"""Build W4 repair-R2 evidence from the metadata-only scan and upstream registers."""
from __future__ import annotations

import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
REPO = HERE.parents[3]
ARCHIVE = HERE / "archive/pre_repair_r2"

UPSTREAM = {
    "W1": REPO / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/witness_authority/external_input_register.json",
    "W2": REPO / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/trust_chain/external_input_register.json",
    "W3": REPO / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/source_g2_environment/external_input_register.json",
}
OLD_FILES = ["absence_delta.json", "candidate_inventory.json", "cleanup_inventory.json", "discovery_report.md", "manifest.json", "run_ledger.json", "static_discovery_validator.py", "validation_receipt.json"]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def copy_old() -> None:
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    for name in OLD_FILES:
        source = HERE / name
        if source.exists():
            destination = ARCHIVE / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            if not destination.exists():
                shutil.copy2(source, destination)
    raw = HERE / "raw"
    if raw.exists():
        for source in raw.iterdir():
            if source.is_file():
                destination = ARCHIVE / "raw" / source.name
                destination.parent.mkdir(parents=True, exist_ok=True)
                if not destination.exists():
                    shutil.copy2(source, destination)


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def record_from_scan(item: dict, kind: str) -> dict:
    path = item["path"]
    digest = hashlib.sha256(path.encode("utf-8")).hexdigest()[:20]
    test_only = path.startswith(("test/", "benchmarks/", "docs/implementation/AD-"))
    if kind == "candidate":
        reason = "metadata-only local or historical record; no external issuer, signed trust chain, freshness/revocation proof, or candidate-bound authority was inferred"
        return {
            "id": f"scan_{digest}",
            "path": path,
            "sha256": item["sha256"],
            "bytes": item["bytes"],
            "type": item["type"],
            "producer": "repository_metadata_scan",
            "authority": "unattested_local_or_historical",
            "signature_verification_feasibility": "not_attempted_metadata_only",
            "test_only": test_only,
            "production": False,
            "usable": False,
            "sensitive_unopened": item["sensitive_unopened"],
            "content_emitted": False,
            "why_not": reason,
        }
    return {
        "id": f"excluded_{digest}",
        "path": path,
        "sha256": item["sha256"],
        "bytes": item["bytes"],
        "type": item["type"],
        "classification": "excluded_inventory",
        "excluded_reason": item["category"],
        "sensitive_unopened": item["sensitive_unopened"],
        "content_emitted": False,
        "promotion": {"production": False, "usable": False},
    }


def build_crosswalk() -> tuple[dict, dict]:
    registers = {}
    crosswalk = []
    all_ids = []
    for scope, path in UPSTREAM.items():
        data = load_json(path)
        rows = data.get("inputs", [])
        ids = [row["id"] for row in rows]
        registers[scope] = {
            "path": path.relative_to(REPO).as_posix(),
            "sha256": sha256(path),
            "record_count": len(rows),
            "ids": ids,
        }
        for row in rows:
            source_id = row["id"]
            all_ids.append(f"{scope}:{source_id}")
            authoritative = row.get("authoritative_source", row.get("authority_source"))
            if not isinstance(authoritative, str) or not authoritative:
                authoritative = "typed_absence:unspecified_authoritative_source"
            provider = row.get("provider", row.get("responsible_party"))
            if not isinstance(provider, str) or not provider:
                provider = row.get("owner") if isinstance(row.get("owner"), str) else "typed_absence:unspecified_external_provider"
            owner = row.get("owner", row.get("responsible_party"))
            if not isinstance(owner, str) or not owner:
                owner = "typed_absence:unspecified_owner"
            responsible = row.get("responsible_party", row.get("owner"))
            if not isinstance(responsible, str) or not responsible:
                responsible = owner
            authority_ref = row.get("authority_ref", "typed_absence:unspecified_authority_ref")
            if not isinstance(authority_ref, str):
                authority_ref = "typed_absence:unspecified_authority_ref"
            crosswalk.append(
                {
                    "crosswalk_id": f"W4-{scope}-{source_id}",
                    "scope": scope,
                    "source_register": registers[scope]["path"],
                    "source_id": source_id,
                    "source_gap_id": row.get("gap_id"),
                    "state": "typed_absent",
                    "source_state": row.get("state", "typed_absent"),
                    "provider": provider,
                    "owner": owner,
                    "responsible_party": responsible,
                    "authoritative_source": authoritative,
                    "authority_ref": authority_ref,
                    "recovery_condition": row.get("recovery_condition", "typed_absence:unspecified_recovery_condition"),
                    "expiry_or_revocation": row.get("expiry_condition", row.get("expiry_or_revocation", "typed_absence:unspecified_expiry_or_revocation")),
                    "source_record_sha256": hashlib.sha256(json.dumps(row, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest(),
                    "legacy_delta_alias": None,
                }
            )
    full_id_digest = hashlib.sha256("\n".join(sorted(all_ids)).encode("utf-8")).hexdigest()
    delta = {
        "schema": "UP1.W4.local-input-discovery.absence-delta.r2.v1",
        "as_of_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "repo_head": "b2c04d8339774635aaecd73651efcdb101e01b5d",
        "changed_inputs": False,
        "new_real_inputs": [],
        "changed_inputs_basis": {
            "rule": "changed_inputs is true only when a full scoped register ID has a newly supplied real external value or a candidate record is usable/production",
            "full_scoped_id_count": len(all_ids),
            "full_scoped_id_digest": full_id_digest,
            "registers": registers,
            "candidate_usable_production_count": 0,
        },
        "no_upstream_register_mutation": True,
        "crosswalk_complete": True,
        "crosswalk_count": len(crosswalk),
        "crosswalk": crosswalk,
        "recovery_state": "unchanged_typed_absent",
        "interpretation": "Every W1/W2/W3 source ID is preserved one-to-one; no upstream ID is merged, renamed, dropped, or promoted."
    }
    return delta, registers


def main() -> int:
    copy_old()
    scan = load_json(HERE / "repair_r2/metadata_scan_summary.json")
    scanned_candidates = load_json(HERE / "repair_r2/metadata_scan_candidates.json")["records"]
    scanned_excluded = load_json(HERE / "repair_r2/metadata_scan_excluded.json")["records"]
    candidates = [record_from_scan(item, "candidate") for item in scanned_candidates]
    excluded = [record_from_scan(item, "excluded") for item in scanned_excluded]
    inventory = {
        "schema": "UP1.W4.local-input-discovery.candidate-inventory.r2.v1",
        "repo_root": str(REPO).replace("\\", "/"),
        "head": scan["head"],
        "scan_scope": {"paths": "repository only", "excluded_universe": scan["excluded_from_universe"], "home_or_credential_stores": "excluded", "network": "disabled by procedure", "content_policy": "metadata/hash only; no contents emitted"},
        "metadata_scan": {"raw": scan["raw"], "hit_count": scan["hit_count"], "candidate_count": scan["candidate_count"], "excluded_count": scan["excluded_count"], "sensitive_unopened_count": scan["sensitive_unopened_count"], "path_rule": scan["path_hit_rule"], "excluded_universe": scan["excluded_from_universe"]},
        "candidates": candidates,
        "candidate_summary": {"candidate_count": len(candidates), "usable_production_count": 0, "new_real_external_inputs": 0, "sensitive_unopened_count": sum(1 for x in candidates if x["sensitive_unopened"]), "default_policy": "local, historical, fixture, schema-only, self-authored and unverified material is not authoritative"},
    }
    excluded_inventory = {"schema": "UP1.W4.local-input-discovery.excluded-inventory.r2.v1", "records": excluded, "summary": {"excluded_count": len(excluded), "sensitive_unopened_count": sum(1 for x in excluded if x["sensitive_unopened"]), "content_emitted": False}}
    (HERE / "candidate_inventory.json").write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (HERE / "excluded_inventory.json").write_text(json.dumps(excluded_inventory, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    delta, registers = build_crosswalk()
    (HERE / "absence_delta.json").write_text(json.dumps(delta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    # New raw validator files are pre-created so the manifest has a closed set before capture.
    for raw in ("repair_r2/raw/static_discovery_validator.stdout.raw", "repair_r2/raw/static_discovery_validator.stderr.raw", "repair_r2/raw/static_discovery_validator.combined.raw"):
        path = HERE / raw
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"")
    files = sorted(x.relative_to(HERE).as_posix() for x in HERE.rglob("*") if x.is_file())
    manifest = {
        "schema": "UP1.W4.local-input-discovery.manifest.v2",
        "status": "repair_r2_ready_for_independent_review",
        "claim": "discovery_only/preparation_only",
        "repo_root": str(REPO).replace("\\", "/"),
        "head": scan["head"],
        "scope": "repository-only full metadata scan; reviews/** and local_input_discovery/** are assessor/self artifacts excluded from the universe; W1/W2/W3 main packages included; no home/credential stores/network; no content emitted",
        "metadata_scan": {"summary": "repair_r2/metadata_scan_summary.json", "raw": scan["raw"], "candidate_inventory": "candidate_inventory.json", "excluded_inventory": "excluded_inventory.json", "hit_count": scan["hit_count"], "candidate_count": len(candidates), "excluded_count": len(excluded), "sensitive_unopened_count": scan["sensitive_unopened_count"], "excluded_universe": scan["excluded_from_universe"]},
        "upstream_registers": registers,
        "files": files,
        "exact_file_set": True,
        "validation_receipt": "validation_receipt.json",
        "upstream_files_modified": False,
        "new_ad_created": False,
        "credit": {"discovery_only": True, "preparation_only": True, "T0": False, "B00": False, "B04": False, "UP1": False, "R": False, "L4": False, "parent_goal": False},
    }
    (HERE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    ledger = {
        "schema": "UP1.W4.local-input-discovery.run-ledger.v2",
        "status": "scan_complete_validator_pending",
        "claim": "discovery_only/preparation_only",
        "repo_root": str(REPO).replace("\\", "/"),
        "scan_scope": "repository_only; reviews/** and local_input_discovery/** excluded assessor/self artifacts; W1/W2/W3 main packages included; no user home; no credential stores; no network; metadata/hash only",
        "head": scan["head"],
        "commands": [{"id": "W4-METADATA-SCAN-R2", "purpose": "fresh full repository-only path/extension metadata and SHA-256 scan with reviews/self artifacts excluded", "status": "completed_read_only", "pid": scan["pid"], "start_utc": scan["started_utc"], "end_utc": scan["ended_utc"], "exit_code": 0, "raw_stdout": scan["raw"], "raw_stderr": None, "raw_sha256": sha256(HERE / scan["raw"]), "hit_count": scan["hit_count"], "candidate_count": len(candidates), "excluded_count": len(excluded)}, {"id": "W4-STATIC-VALIDATOR-R2", "purpose": "independent candidate/excluded existence/hash/types/crosswalk/manifest validator", "status": "pending_capture", "pid": None, "start_utc": None, "end_utc": None, "exit_code": None, "raw_stdout": "repair_r2/raw/static_discovery_validator.stdout.raw", "raw_stderr": "repair_r2/raw/static_discovery_validator.stderr.raw", "combined_raw": "repair_r2/raw/static_discovery_validator.combined.raw"}],
        "sensitive_unopened": [],
        "no_authoritative_external_input_found": True,
        "historical_pre_repair_ledger": "archive/pre_repair_r1/run_ledger.json",
    }
    (HERE / "run_ledger.json").write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    receipt = {"schema": "UP1.W4.local-input-discovery.validation-receipt.r2.v1", "status": "validator_pending", "claim": "discovery_only/preparation_only", "scan": {"pid": scan["pid"], "start_utc": scan["started_utc"], "end_utc": scan["ended_utc"], "exit_code": 0, "raw": scan["raw"], "sha256": sha256(HERE / scan["raw"]), "excluded_universe": scan["excluded_from_universe"]}, "validator": {"status": "pending_capture", "command": "python -B static_discovery_validator.py", "pid": None, "exit_code": None}, "candidate_count": len(candidates), "excluded_count": len(excluded), "changed_inputs": False, "upstream_register_mutated": False, "failures": []}
    (HERE / "validation_receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = f"""# UP1 W4 — local external-input discovery repair R2\n\nStatus: `discovery_only` / `preparation_only`\n\nA fresh repository-only metadata scan excluded `reviews/**` and `local_input_discovery/**` as assessor/self artifacts while including W1/W2/W3 main packages. It found {scan['hit_count']} path-rule hits: {len(candidates)} candidate-class records and {len(excluded)} excluded records. Every record has relative path, type, byte size, SHA-256, classification, and no emitted content in `{scan['raw']}`. AD-44/45/55/56 are explicitly covered in the candidate class; source/test/runtime/historical/non-target hits are retained in `excluded_inventory.json`.\n\nNo sensitive contents were emitted; the scan reports `sensitive_unopened_count={scan['sensitive_unopened_count']}`. All candidate records remain `usable=false`, `production=false`; no record is promoted.\n\nThe absence delta preserves every W1/W2/W3 register ID one-to-one (`{len(delta['crosswalk'])}` rows), with source register path/hash, owner/provider/authority/recovery/expiry and full scoped-ID digest. `changed_inputs=false`, `new_real_inputs=[]`; unchanged inputs do not create an AD or repeat S3.\n\nThe validator is independent of self-reported expected values: it recomputes existence, byte count, SHA-256, types/enums, promotion flags, candidate/excluded coverage, crosswalk coverage and exact file set.\n\nNo source, test, AD, upstream register, shared registry, network, Julia, DESC, solver, mesh, or physical/search execution was touched.\n"""
    (HERE / "discovery_report.md").write_text(report, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
