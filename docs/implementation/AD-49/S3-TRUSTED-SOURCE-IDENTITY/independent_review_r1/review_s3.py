"""Independent AD49-S3 audit.  Reads formal products and writes only audit evidence."""
from __future__ import annotations
import hashlib, json, os, subprocess, sys
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
S3 = ROOT / "docs/implementation/AD-49/S3-TRUSTED-SOURCE-IDENTITY"
MANIFEST = S3 / "manifest.json"
PRODUCTS = [
    "docs/implementation/AD-49/G1-TRUSTED-SOURCE-IDENTITY/g1_trusted_source_identity_v1.json",
    "docs/implementation/AD-49/G1-TRUSTED-SOURCE-IDENTITY/g1_trusted_source_identity_receipt.json",
    "docs/implementation/AD-49/G2-TRUSTED-SOURCE-IDENTITY/g2_trusted_source_identity_v1.json",
    "docs/implementation/AD-49/G2-TRUSTED-SOURCE-IDENTITY/g2_trusted_source_identity_receipt.json",
]
SOURCE = {
    "G1": "src/GenomeV5/G1/DiffusionDeclarationV1.jl",
    "G2": "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl",
}
AXES = {
    "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/evidence_receipt_axis_schema_v1.json",
    "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g1_evidence_receipt_contract_v1.json",
    "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_applicability_profile_contract_v1.json",
    "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_evidence_receipt_contract_v1.json",
}
REQUIRED = PRODUCTS + [
    "docs/implementation/AD-49/S3-TRUSTED-SOURCE-IDENTITY/manifest.json",
    "docs/implementation/AD-49/S3-TRUSTED-SOURCE-IDENTITY/report.md",
    "docs/implementation/AD-49/S3-TRUSTED-SOURCE-IDENTITY/archive/input_hashes.json",
    "docs/implementation/AD-49/S3-TRUSTED-SOURCE-IDENTITY/archive/final_hashes.json",
    "docs/implementation/AD-49/G1-SOURCE-LOCATOR/g1_source_locator_v1.json",
    "docs/implementation/AD-49/G2-SOURCE-LOCATOR/g2_source_locator_v1.json",
    "docs/implementation/AD-49/S2-G1-G2-FACTORY-IDENTITIES-FRESH-R2/root_acceptance_r1/manifest.json",
    "docs/implementation/AD-49/F0-G1-G2-SOURCE-AUTHORITY-FACTORIES/root_acceptance_r2/manifest.json",
    "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json",
]

def sha(p: Path):
    b = p.read_bytes(); return {"path": p.relative_to(ROOT).as_posix(), "bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()}
def load(rel): return json.loads((ROOT / rel).read_text(encoding="utf-8"))
def git(*args):
    p = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)
    return p.returncode, p.stdout.strip(), p.stderr.strip()
def dump(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"), indent=2) + "\n", encoding="utf-8")

def reconstruct(rel):
    d = load(rel); inp = d.get("inputs", {})
    source = d["scope"]
    upstream = {x["path"] for x in inp.get("upstream_artifacts", [])}
    chain = inp.get("external_attestation_chain", {})
    checks = {
        "json_and_product_path": True,
        "typed_absence_semantics": (d.get("status") == "typed_absent" and d.get("result", "").startswith("Absent") and d.get("terminal_deferred") is True and d.get("no_publish") is True and d.get("present_result_permitted") is False),
        "reason_exact": d.get("reason") == "missing_source_closure_and_independent_attestation_chain",
        "source_head_absent": bool(inp.get("source_head_closure")) and all(x.get("head_present") is False and x.get("head_exit") == 128 for x in inp["source_head_closure"]),
        "source_worktree_bound": (inp.get("source_declaration", {}).get("path") == SOURCE[source] and inp["source_declaration"].get("present") is True and isinstance(inp["source_declaration"].get("sha256"), str) and inp["source_declaration"].get("bytes", 0) > 0),
        "ad45_exact": inp.get("ad45_handle", {}).get("id") == "fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7" and inp.get("ad45_handle", {}).get("version") == "v5" and inp.get("ad45_handle", {}).get("envelope_sha256") == "17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc",
        "four_axis_refs": AXES.issubset(upstream),
        "attestation_chain_all_missing": bool(chain) and all(v is False for v in chain.values()),
        "no_trust_claims": all(d.get(k) is False for k in ("source_authority", "trusted_attestation_created", "candidate_identity_created", "declaration_hash_created", "final_hash_created")),
        "forbidden_derivations_closed": set(d.get("forbidden_derivations", [])) >= {"local_receipt_hash", "reviewer_identity", "fixture", "URI", "seed", "test_exit", "provider_trust_root", "own_hash", "candidate_hash"},
    }
    checks["layer_and_union"] = source in ("G1", "G2") and d.get("record_kind", "").startswith(source) and d.get("result", "").startswith("Absent" + source)
    return checks

def audit():
    OUT.mkdir(parents=True, exist_ok=True)
    head_rc, head, head_err = git("rev-parse", "HEAD")
    status_rc, status, status_err = git("status", "--short", "--untracked-files=all")
    products = []
    checks = {}
    for rel in PRODUCTS:
        p = ROOT / rel; d = load(rel)
        products.append({**sha(p), "result": d.get("result"), "status": d.get("status"), "layer": d.get("scope"), "record_kind": d.get("record_kind")})
        checks[rel] = reconstruct(rel)
    s1 = [load("docs/implementation/AD-49/G1-SOURCE-LOCATOR/g1_source_locator_v1.json"), load("docs/implementation/AD-49/G2-SOURCE-LOCATOR/g2_source_locator_v1.json")]
    s2 = load("docs/implementation/AD-49/S2-G1-G2-FACTORY-IDENTITIES-FRESH-R2/root_acceptance_r1/manifest.json")
    f0 = load("docs/implementation/AD-49/F0-G1-G2-SOURCE-AUTHORITY-FACTORIES/root_acceptance_r2/manifest.json")
    manifest = load("docs/implementation/AD-49/S3-TRUSTED-SOURCE-IDENTITY/manifest.json")
    top = {
        "s1_typed_absent": all(x.get("status") == "typed_absent" for x in s1),
        "s2_root_acceptance_current": s2.get("decision") == "accepted_limited" and s2.get("accepted_scope") == "factory_software_capability_and_current_repository_typed_absence_only",
        "f0_software_only": f0.get("decision") == "accepted_limited",
        "s3_gate": manifest.get("gate") == "blocked_external_trust_root_and_source_closure",
        "g2_mapping_absent": manifest.get("formal_status", {}).get("G2_mapping") == "absent",
    }
    # Independent filesystem scan: no AD49 attestation chain material is present.
    suffixes = {".pem", ".key", ".crt", ".cer", ".der", ".p12", ".pfx", ".sig", ".asc", ".pub"}
    candidates = [p.relative_to(ROOT).as_posix() for p in ROOT.rglob("*") if p.is_file() and p.suffix.lower() in suffixes and "AD-49" in p.as_posix()]
    rc, git_sign, git_sign_err = git("config", "--get-regexp", r"^user\.signingkey$|^gpg\.format$|^commit\.gpgsign$")
    trust_scan = {"ad49_key_cert_signature_candidates": candidates, "git_signing_config": git_sign, "git_signing_config_exit": rc, "git_signing_config_stderr": git_sign_err, "all_required_external_components": False}
    all_checks = [v for group in checks.values() for v in group.values()] + list(top.values())
    result = {"schema_version": "AD49-S3-independent-review-r1-v1", "task": "AD49-S3-TRUSTED-G1-G2-SOURCE-IDENTITY", "reviewer_owned": True, "generated_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"), "observed_head": head, "head_exit": head_rc, "status_snapshot_sha256": hashlib.sha256(status.encode()).hexdigest(), "product_hashes": products, "product_checks": checks, "upstream_checks": top, "trust_scan": trust_scan, "passed": sum(bool(x) for x in all_checks), "total": len(all_checks), "verdict": "pass_limited" if all(all_checks) else "changes_requested", "gate": "blocked_external_trust_root_and_source_closure", "julia": False, "desc": False, "physical": False, "claims": {"trusted_attestation": False, "source_authority": False, "candidate_identity": False, "final_hash": False, "t0": False, "t1": False, "t2": False, "provider": False, "solver": False, "engineering": False, "physics": False, "search": False, "r01_r10": False, "l4_credible_count": 0}}
    dump(OUT / "audit_result.json", result)
    dump(OUT / "input_freeze.json", {"schema_version": "AD49-S3-independent-review-input-freeze-v1", "observed_head": head, "head_exit": head_rc, "status_sha256": hashlib.sha256(status.encode()).hexdigest(), "required_inputs": [sha(ROOT / r) for r in REQUIRED], "s1_status": [x.get("status") for x in s1], "s2_decision": s2.get("decision"), "f0_decision": f0.get("decision"), "product_hashes": products})
    dump(OUT / "trust_chain_scan.json", trust_scan)
    return result

if __name__ == "__main__":
    result = audit()
    print(json.dumps({"passed": result["passed"], "total": result["total"], "verdict": result["verdict"], "head": result["observed_head"]}, sort_keys=True))
    sys.exit(0 if result["verdict"] == "pass_limited" else 1)
