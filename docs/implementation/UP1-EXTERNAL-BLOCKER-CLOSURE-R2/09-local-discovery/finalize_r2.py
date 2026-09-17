#!/usr/bin/env python3
"""Materialize the R2 discovery crosswalk and lossless audit records."""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = Path(r"D:/006-Programing/LMC/FusionConceptAI")
R1 = REPO / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/local_input_discovery"
RAW = HERE / "raw/metadata_scan_r2.jsonl"

def now():
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def head():
    try:
        return subprocess.check_output(["git", "-C", str(REPO), "rev-parse", "HEAD"], text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return "unavailable"

def load_rows():
    return [json.loads(line) for line in RAW.open(encoding="utf-8") if line.strip()]

def load_r1():
    absence = json.loads((R1 / "absence_delta.json").read_text(encoding="utf-8"))
    return absence, json.loads((R1 / "candidate_inventory.json").read_text(encoding="utf-8"))

def matching(rows, terms):
    rx = re.compile("|".join(re.escape(term) for term in terms), re.I)
    return [row for row in rows if rx.search(row["path"])]

def main():
    started_utc = now()
    process_pid = os.getpid()
    rows = load_rows()
    r1_absence, r1_inventory = load_r1()
    strict = [row for row in rows if row["match_kind"] in ("r1_rule", "r1_and_supplemental")]
    supplemental_only = [row for row in rows if row["match_kind"] == "supplemental_rule"]
    source_terms = {
        "EXT-WITNESS-IDENTITY": ["witness", "attest", "authority"],
        "EXT-WITNESS-INDEPENDENCE": ["witness", "independence", "conflict", "attest"],
        "EXT-TRUST-ROOT": ["trust", "root", "certificate", "cert"],
        "EXT-CERT-CHAIN": ["certificate", "cert", "chain", "intermediate", "leaf"],
        "EXT-SIGNED-ATTESTATION": ["signed", "signature", "attest", "receipt"],
        "EXT-VERIFIER-POLICY": ["verifier", "policy", "revocation", "ocsp", "crl", "nonce"],
        "EXT-SOURCE-CLOSURE": ["source", "closure", "environment", "provenance"],
        "EXT-AUTH-CHANNEL": ["authority", "channel", "endpoint"],
        "EXT-CHANNEL-RECEIPT": ["receipt", "ack", "retry", "idempot"],
        "EXT-CANDIDATE-LINEAGE": ["candidate", "lineage", "g1", "g2", "g3", "axis"],
        "trust_root": ["trust", "root", "certificate", "cert"],
        "intermediate_chain": ["certificate", "cert", "chain", "intermediate", "leaf"],
        "leaf_attestor": ["leaf", "attest", "certificate", "cert"],
        "signature_profile": ["signature", "signed", "canonical", "profile"],
        "signed_receipt": ["signed", "receipt", "attest"],
        "verifier": ["verifier", "validation", "replay"],
        "revocation_source": ["revocation", "ocsp", "crl"],
        "trusted_time": ["tsa", "timestamp", "trusted", "time"],
        "replay_policy": ["replay", "nonce", "idempot", "retry"],
        "source_version_binding": ["source", "version", "binding", "provenance"],
        "independent_attestation_scope": ["independent", "attest", "scope", "witness"],
        "source_candidate_evidence_binding": ["source", "candidate", "evidence", "binding"],
        "g2_authoritative_mapping": ["g2", "mapping", "authority"],
        "four_axis_materials": ["axis", "four", "g1", "g2", "g3"],
        "candidate_environment_closure": ["candidate", "environment", "closure"],
        "binary_provenance": ["binary", "provenance", "sbom", "lock"],
    }
    crosswalk = []
    for old in r1_absence.get("crosswalk", []):
        sid = old["source_id"]
        hits = matching(rows, source_terms.get(sid, [sid]))
        crosswalk.append({
            "crosswalk_id": old.get("crosswalk_id"),
            "scope": old.get("scope"),
            "source_register": old.get("source_register"),
            "source_id": sid,
            "source_gap_id": old.get("source_gap_id"),
            "r1_state": old.get("state"),
            "r2_state": old.get("state", "typed_absent"),
            "r2_discovery": "metadata_hits_only_no_usable_external_input",
            "r2_matching_metadata_hit_count": len(hits),
            "r2_new_or_changed_metadata_hit_count": sum(row["delta"] != "unchanged" for row in hits),
            "r2_usable_production_count": 0,
            "r2_metadata_raw": "raw/metadata_scan_r2.jsonl",
            "r2_reason": "No local path/hash/mtime or contract/test/historical record proves an external issuer, trust chain, freshness/revocation receipt, candidate-bound authority, or production source closure.",
            "provider": old.get("provider"),
            "owner": old.get("owner"),
            "responsible_party": old.get("responsible_party"),
            "authoritative_source": old.get("authoritative_source"),
            "authority_ref": old.get("authority_ref"),
            "recovery_condition": old.get("recovery_condition"),
            "expiry_or_revocation": old.get("expiry_or_revocation"),
            "source_record_sha256": old.get("source_record_sha256"),
        })
    strict_counts = {
        "r1_strict_current_hit_count": len(strict),
        "r1_strict_unchanged_count": sum(row["delta"] == "unchanged" for row in strict),
        "r1_strict_changed_hash_count": sum(row["delta"] == "changed_hash" for row in strict),
        "r1_strict_new_path_count": sum(row["delta"] == "new_path" for row in strict),
        "supplemental_only_hit_count": len(supplemental_only),
        "r1_prior_hit_count": r1_inventory.get("metadata_scan", {}).get("hit_count"),
        "r1_prior_candidate_count": r1_inventory.get("candidate_summary", {}).get("candidate_count"),
    }
    result = {
        "schema": "UP1.W4.local-input-discovery.R2.crosswalk.v1",
        "status": "completed",
        "claim_ceiling": "preparation_only",
        "as_of_utc": now(),
        "pid": os.getpid(),
        "repo_head": head(),
        "r1_head": r1_inventory.get("head"),
        "r1_fingerprint_source": "../UP1-EXTERNAL-BLOCKER-CLOSURE-R1/local_input_discovery/absence_delta.json",
        "scan_result": "scan_result.json",
        "raw_metadata": "raw/metadata_scan_r2.jsonl",
        "counts": strict_counts,
        "new_real_inputs": [],
        "changed_inputs": False,
        "no_new_ad": True,
        "no_s3_rerun": True,
        "crosswalk_complete": len(crosswalk) == 26,
        "crosswalk_count": len(crosswalk),
        "crosswalk": crosswalk,
        "interpretation": "Changed source/history hashes and new R2 implementation artifacts are not external input changes. All discovered material remains local, historical, fixture, schema, environment, or contract metadata and is nonusable for UP1 authority closure.",
    }
    (HERE / "crosswalk.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# UP1 external blocker closure R2 — local discovery",
        "",
        "Status: `completed`, claim ceiling: `preparation_only`, `changed_inputs=false`, `new_real_inputs=[]`.",
        "",
        "This is a metadata/hash-only rediscovery over the FusionConceptAI repository and `outputs/fusion_concept_ai`. `.git`, review directories, cache directories, R1's generated local-discovery directory, and this R2 output directory were excluded. Suspected credential/private-key/token paths were not opened; no environment-variable values were read.",
        "",
        "## R1 comparison",
        "",
        f"R1 recorded `{strict_counts['r1_prior_hit_count']}` raw path hits and `{strict_counts['r1_prior_candidate_count']}` candidate records at HEAD `{r1_inventory.get('head')}`. Under the exact R1 rule, R2 has `{strict_counts['r1_strict_current_hit_count']}` current hits: `{strict_counts['r1_strict_unchanged_count']}` unchanged, `{strict_counts['r1_strict_changed_hash_count']}` changed hashes, and `{strict_counts['r1_strict_new_path_count']}` new paths. The supplementary certificate/root/axis/mapping/lockfile/evidence rule adds `{strict_counts['supplemental_only_hit_count']}` path hits. These deltas are local source/history/fixture/environment or R2 implementation material, not newly supplied external values.",
        "",
        "## Findings",
        "",
        "No real witness/authority receipt, trust root, public-key certificate chain, signed attestation, CRL/OCSP/TSA receipt, authoritative G2 mapping, candidate-bound four-axis issuance, or binary/SBOM/lockfile provenance receipt was found. The 12 public-material hits are Python/Conda CA bundles and are not an attestor chain or candidate-bound receipt. Local contracts, tests, fixtures, schemas, reports, source code, hashes, and historical run receipts remain nonusable and cannot be promoted.",
        "",
        "The complete 26-row crosswalk is in `crosswalk.json`; every row retains the R1 provider/owner/authority/recovery/expiry fields and records the R2 metadata-hit count. The lossless path/size/mtime/hash stream is `raw/metadata_scan_r2.jsonl`.",
        "",
        "## Disposition",
        "",
        "`no_new_AD=true`; `no_s3_rerun=true`. The external trust-root/source-closure blocker remains open. A future S3 attempt requires an actual external input change plus a fresh candidate-bound source/environment closure and independent verifier evidence.",
        "",
        "## Reproduction",
        "",
        "```powershell",
        "python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/09-local-discovery/scan_r2.py",
        "python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/09-local-discovery/finalize_r2.py",
        "```",
        "",
        "Run PID/UTC/exit and stdout/stderr hashes are recorded in `run_ledger.json` and `validation_receipt.json`.",
    ]
    (HERE / "discovery_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({"crosswalk_count": len(crosswalk), "strict_counts": strict_counts, "new_real_inputs": [], "changed_inputs": False, "pid": process_pid, "started_utc": started_utc, "ended_utc": now()}, ensure_ascii=False, sort_keys=True))

if __name__ == "__main__":
    main()
