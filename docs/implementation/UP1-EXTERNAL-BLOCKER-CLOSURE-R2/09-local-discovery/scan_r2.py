#!/usr/bin/env python3
"""UP1 R2 local input discovery.

Metadata/hash-only scan.  It intentionally never opens files whose path looks
like a credential, private key, token, or password store.  JSON inspection is
limited to a small allow-list of non-sensitive evidence-envelope files and
only emits safe top-level shape/enum metadata.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(r"D:/006-Programing/LMC")
REPO = ROOT / "FusionConceptAI"
OUTPUTS = ROOT / "outputs/fusion_concept_ai"
OUT = REPO / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/09-local-discovery"
R1 = REPO / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/local_input_discovery"

R1_PATH_RULE_TEXT = (
    r"(?:AD[-_ ]?(?:44|45|55|56)|authority|candidate|trust|signature|signed|receipt|"
    r"attest|witness|g2|environment|binary|provenance|sbom|certificate|cert|nonce|"
    r"revocation|ocsp|crl)"
)
PATH_RULE = re.compile(R1_PATH_RULE_TEXT, re.I)
SUPPLEMENTAL_RULE_TEXT = (
    r"(?:root|intermediate|leaf|tsa|four[-_ ]?axis|axis|mapping|source|lockfile|"
    r"package-lock|manifest|evidence)"
)
SUPPLEMENTAL_RULE = re.compile(SUPPLEMENTAL_RULE_TEXT, re.I)
SENSITIVE_RULE = re.compile(
    r"(?:secret|private|credential|password|passwd|token|api[_-]?key|access[_-]?key|"
    r"id[_-]?rsa|ssh[_-]?key|\.key$|\.p12$|\.pfx$)", re.I
)
PUBLIC_MATERIAL_EXT = {".pem", ".crt", ".cer", ".der", ".crl", ".ocsp", ".tst", ".p7b", ".p7c"}
SAFE_JSON_NAMES = {
    "manifest.json", "evidence_manifest.json", "validation_receipt.json",
    "external_input_register.json", "gap_matrix.json", "sbom.json",
    "bom.json", "provenance.json", "lockfile.json",
}
SKIP_NAMES = {".git", "reviews", "review", "cache", ".cache", "__pycache__"}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_json_shape(path: Path):
    """Return only non-sensitive shape/enum metadata for an allow-listed JSON."""
    if path.name.lower() not in SAFE_JSON_NAMES or SENSITIVE_RULE.search(str(path)):
        return None
    try:
        if path.stat().st_size > 8 * 1024 * 1024:
            return {"parse": "skipped_size_limit"}
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # metadata-only; never print content or exception text
        return {"parse": "failed"}
    if not isinstance(value, dict):
        return {"parse": "non_object"}
    result = {"parse": "ok", "top_level_keys": sorted(str(k) for k in value.keys())}
    for key in ("schema", "status", "state", "claim_ceiling", "resolution", "gate"):
        item = value.get(key)
        if isinstance(item, (str, int, float, bool)) or item is None:
            result[key] = item
    for key in ("test_only", "production", "usable", "sensitive_unopened", "new_real_inputs"):
        item = value.get(key)
        if isinstance(item, (bool, int, float)) or item is None:
            result[key] = item
        elif isinstance(item, list):
            result[key + "_count"] = len(item)
    return result


def excluded(path: Path) -> bool:
    parts = {part.lower() for part in path.parts}
    if parts & SKIP_NAMES:
        return True
    # Keep historical R1's generated scan out of the new universe; otherwise
    # the prior report would become a self-referential candidate set.
    normalized = str(path).replace("\\", "/").lower()
    if "/docs/implementation/up1-external-blocker-closure-r1/local_input_discovery/" in normalized:
        return True
    if "/docs/implementation/up1-external-blocker-closure-r2/09-local-discovery/" in normalized:
        return True
    return False


def relpath(path: Path) -> str:
    for base in (REPO, OUTPUTS):
        try:
            return f"{base.name}/{path.relative_to(base).as_posix()}"
        except ValueError:
            pass
    return path.as_posix()


def prior_inventory():
    path = R1 / "candidate_inventory.json"
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}, {"available": False}
    prior = {}
    for record in value.get("candidates", []):
        if isinstance(record, dict) and record.get("path"):
            prior[record["path"]] = record.get("sha256")
    raw_map = {}
    raw_path = R1 / "raw/metadata_scan_r2.jsonl"
    try:
        for line in raw_path.open(encoding="utf-8"):
            record = json.loads(line)
            if isinstance(record, dict) and record.get("path"):
                raw_map[record["path"]] = record
    except Exception:
        raw_map = {}
    return prior, {
        "available": True,
        "head": value.get("head"),
        "candidate_count": value.get("candidate_summary", {}).get("candidate_count"),
        "hit_count": value.get("metadata_scan", {}).get("hit_count"),
        "path_rule": value.get("metadata_scan", {}).get("path_rule"),
        "raw_map": raw_map,
    }


def git_head() -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(REPO), "rev-parse", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except Exception:
        return "unavailable"


def scan():
    started = utc_now()
    pid = os.getpid()
    prior, prior_meta = prior_inventory()
    records = []
    roots = [REPO, OUTPUTS]
    for base in roots:
        for dirpath, dirnames, filenames in os.walk(base, topdown=True, followlinks=False):
            dirnames[:] = [name for name in dirnames if name.lower() not in SKIP_NAMES]
            current_dir = Path(dirpath)
            dirnames[:] = [name for name in dirnames if not excluded(current_dir / name)]
            for name in sorted(filenames, key=str.casefold):
                path = current_dir / name
                if excluded(path):
                    continue
                r1_match = bool(PATH_RULE.search(str(path)))
                supplemental_match = bool(SUPPLEMENTAL_RULE.search(str(path)))
                if not (r1_match or supplemental_match):
                    continue
                try:
                    stat = path.stat()
                except OSError:
                    continue
                relative = relpath(path)
                sensitive = bool(SENSITIVE_RULE.search(str(path)))
                record = {
                    "path": relative,
                    "bytes": stat.st_size,
                    "mtime_utc": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z"),
                    "extension": path.suffix.lower(),
                    "sensitive_unopened": sensitive,
                    "content_emitted": False,
                    "match_kind": "r1_and_supplemental" if r1_match and supplemental_match else ("r1_rule" if r1_match else "supplemental_rule"),
                }
                if sensitive:
                    record.update({"sha256": None, "classification": "unknown", "reason": "sensitive_path_unopened"})
                else:
                    try:
                        record["sha256"] = sha256_file(path)
                    except OSError:
                        record["sha256"] = None
                    record["json_shape"] = safe_json_shape(path)
                    # A hash/path-only hit cannot prove authority.  Explicit
                    # public-material paths are still nonusable until trust,
                    # issuer, freshness, revocation, and candidate binding are
                    # independently attested.
                    record["classification"] = "nonusable"
                    record["reason"] = "local_or_historical_metadata_only"
                    if path.suffix.lower() in PUBLIC_MATERIAL_EXT:
                        record["reason"] = "public_material_metadata_only_no_chain_or_receipt"
                records.append(record)

    records.sort(key=lambda item: item["path"].casefold())
    for record in records:
        # R1 used repo-relative paths.  Compare by suffix to retain a lossless
        # comparison despite this R2 scan spanning two roots.
        old_path = record["path"]
        if old_path.startswith("FusionConceptAI/"):
            old_path = old_path[len("FusionConceptAI/"):]
        previous_hash = prior.get(old_path)
        old_record = prior_meta.get("raw_map", {}).get(old_path)
        record["r1_present"] = old_record is not None
        record["r1_sha256"] = previous_hash
        if old_record is None:
            record["delta"] = "new_path"
        elif previous_hash != record.get("sha256"):
            record["delta"] = "changed_hash"
        else:
            record["delta"] = "unchanged"

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "raw").mkdir(parents=True, exist_ok=True)
    with (OUT / "raw/metadata_scan_r2.jsonl").open("w", encoding="utf-8", newline="\n") as handle:
        for record in records:
            handle.write(json.dumps(record, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")

    categories = {
        "all_hits": len(records),
        "nonusable": sum(item["classification"] == "nonusable" for item in records),
        "unknown": sum(item["classification"] == "unknown" for item in records),
        "sensitive_unopened": sum(item["sensitive_unopened"] for item in records),
        "new_paths": sum(item["delta"] == "new_path" for item in records),
        "changed_hashes": sum(item["delta"] == "changed_hash" for item in records),
        "unchanged": sum(item["delta"] == "unchanged" for item in records),
        "public_material_hits": sum(item["extension"] in PUBLIC_MATERIAL_EXT for item in records),
    }
    result = {
        "schema": "UP1.W4.local-input-discovery.R2.scan-result.v1",
        "status": "completed",
        "claim_ceiling": "preparation_only",
        "pid": pid,
        "started_utc": started,
        "ended_utc": utc_now(),
        "repo_head": git_head(),
        "scan_roots": [str(path).replace("\\", "/") for path in roots],
        "excluded": [".git", "reviews", "cache", "R1/local_input_discovery", "R2/09-local-discovery"],
        "content_policy": "metadata/hash only; sensitive paths unopened; no credentials/private keys/tokens read",
        "r1_path_rule": R1_PATH_RULE_TEXT,
        "supplemental_path_rule": SUPPLEMENTAL_RULE_TEXT,
        "categories": categories,
        "prior_r1": {key: value for key, value in prior_meta.items() if key != "raw_map"},
        "records": len(records),
    }
    (OUT / "scan_result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    scan()
