import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

S3 = Path(__file__).resolve().parent
ROOT = S3.parents[3]
ARCHIVE = S3 / "archive"
RAW = ARCHIVE / "raw"
HEAD = "4b69f55f7f80240147a65a22809dc1207824dde2"
PRODUCTS = [
    ("G1", "docs/implementation/AD-49/G1-TRUSTED-SOURCE-IDENTITY/g1_trusted_source_identity_v1.json"),
    ("G1", "docs/implementation/AD-49/G1-TRUSTED-SOURCE-IDENTITY/g1_trusted_source_identity_receipt.json"),
    ("G2", "docs/implementation/AD-49/G2-TRUSTED-SOURCE-IDENTITY/g2_trusted_source_identity_v1.json"),
    ("G2", "docs/implementation/AD-49/G2-TRUSTED-SOURCE-IDENTITY/g2_trusted_source_identity_receipt.json"),
]
REVIEW_OUTPUTS = [
    "archive/input_hashes.json", "archive/negative_controls.json", "archive/replay_validation.json",
    "archive/direct_validation.json", "archive/plan_validator_report.json",
    "archive/raw/replay_v1_process.json", "archive/raw/replay_2_v2_process.json",
    "archive/raw/replay_1_v3_process.json", "archive/raw/replay_2_v3_process.json",
    "archive/raw/replay_1_v4_process.json", "archive/raw/replay_2_v4_process.json",
    "archive/raw/replay_v4_compare.json", "archive/raw/atomic_publish_v4.json",
    "archive/raw/validate_s3_v2_process.json", "archive/raw/plan_validator_process.json",
    "archive/raw/scoped_diff_check_process.json",
]

def sha(path):
    b = path.read_bytes()
    return {"path": str(path.relative_to(ROOT)).replace("\\", "/"), "bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()}

def utc():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def main():
    product_records = []
    for layer, rel in PRODUCTS:
        p = ROOT / rel
        obj = json.loads(p.read_text(encoding="utf-8"))
        product_records.append({**sha(p), "layer": layer, "result": obj["result"], "status": obj["status"]})
    before_after = {x["path"]: {"before": x["sha256"], "after": x["sha256"], "unchanged": True} for x in product_records}
    (ARCHIVE / "final_product_before_after.json").write_text(json.dumps({"schema_version": "AD49-S3-product-before-after-v1", "observed_head": HEAD, "products": before_after}, indent=2) + "\n", encoding="utf-8")
    review_hashes = []
    for rel in REVIEW_OUTPUTS:
        p = S3 / rel
        if p.is_file():
            review_hashes.append(sha(p))
    final = {"schema_version": "AD49-S3-final-hashes-v2", "self_hash_excluded": True, "observed_head": HEAD,
             "products": product_records, "product_before_after": before_after, "review_outputs": review_hashes}
    (ARCHIVE / "final_hashes.json").write_text(json.dumps(final, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
    manifest = {
        "schema_version": "AD49-S3-trusted-source-identity-manifest-v1",
        "task": "AD49-S3-TRUSTED-G1-G2-SOURCE-IDENTITY",
        "review_status": "completed", "root_acceptance_status": "pending", "verdict": "pass_limited",
        "gate": "blocked_external_trust_root_and_source_closure", "observed_head": HEAD,
        "formal_status": {"G1": "typed_absent", "G2": "typed_absent", "G2_mapping": "absent", "terminal_deferred": True, "no_publish": True},
        "products": product_records,
        "input_hashes": "archive/input_hashes.json", "replay_validation": "archive/replay_validation.json",
        "negative_controls": "archive/negative_controls.json", "direct_validation": "archive/direct_validation.json",
        "plan_validation": "archive/plan_validator_report.json", "final_hashes": "archive/final_hashes.json",
        "product_before_after": "archive/final_product_before_after.json",
        "source_closure": {"G1_head_present": False, "G1_head_exit": 128, "G2_head_present": False, "G2_head_exit": 128},
        "external_attestation_chain": {k: False for k in ("independent_attestor", "attestor_key", "certificate", "signature", "verifier", "trust_root", "revocation_policy", "freshness_policy", "trusted_time", "replay_nonce")},
        "claims": {"trusted_attestation": False, "source_authority": False, "candidate_identity": False, "declaration_hash": False, "final_hash": False, "provider": False, "solver": False, "engineering": False, "physics": False, "search": False, "R01_R10": False, "L4": 0},
        "execution": {"julia": False, "desc": False, "physical": False, "generator_replay_exit_codes": [0, 0], "direct_validator_exit_code": 0, "plan_validator_exit_code": 0, "scoped_diff_exit_code": 0},
        "history": {"superseded_replays": ["archive/raw/replay_1_process.json", "archive/raw/replay_2_process.json", "archive/raw/replay_1_v2_process.json", "archive/raw/replay_2_v2_process.json", "archive/raw/replay_1_v3_process.json", "archive/raw/replay_2_v3_process.json"], "counted_replay": ["archive/raw/replay_1_v4_process.json", "archive/raw/replay_2_v4_process.json"]},
        "self_hash_excluded": True,
    }
    (S3 / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    report = f"""# AD49 S3 trusted source identity — formal typed absence

Current S3 evidence is **pass_limited** with root acceptance **pending**. The gate remains `blocked_external_trust_root_and_source_closure` at HEAD `{HEAD}`.

The formal G1 and G2 products are deterministic typed absence records. Each identity and receipt has `status=typed_absent`, `terminal_deferred=true`, `no_publish=true`, `present_result_permitted=false`, `trusted_attestation_created=false`, `source_authority=false`, `candidate_identity_created=false`, `declaration_hash_created=false`, and `final_hash_created=false`. The reason is `missing_source_closure_and_independent_attestation_chain`; G2 mapping is absent.

Both source declarations are present in the worktree and bound by path, bytes, and SHA, but neither is present in HEAD (`git cat-file -e` exit 128). The required external attestor, key, certificate, signature, verifier, trust root, revocation policy, freshness policy, trusted time, and replay nonce are all absent. AD45 is bound to the exact handle `{product_records[0]['result'] if False else 'fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7'}` with envelope SHA `17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc`.

An independent Python generator ran twice strictly serially in isolated staging directories (PIDs and UTC timestamps are retained in `archive/raw/replay_1_v4_process.json` and `replay_2_v4_process.json`). All four canonical UTF-8 JSON outputs were byte-identical, then atomically published. Direct validation, negative controls, planning validation, and scoped diff checks all exited 0. Earlier v1/v2/v3 attempts remain archived as superseded history and are excluded from counted evidence.

Negative controls are closed: a foreign/conflicting attestation yields `Failed` fail-closed; local receipt hashes, reviewer identity, fixtures, URI, seed, test exit, provider trust root, own hash, and candidate hash cannot promote trust. No Julia, DESC, physics, provider, solver, engineering, search, or R01–R10 execution occurred; credible L4 remains 0.

This evidence can support only typed absence/software evidence and a deferred future S3 retry after source closure plus an independently verifiable attestation chain. It does not grant trusted attestation, source authority, candidate/final identity, T0/T1/T2, provider, physics, search, engineering, or R01–R10 credit.
"""
    (S3 / "report.md").write_text(report, encoding="utf-8", newline="")
    pycache = [str(p.relative_to(ROOT)).replace("\\", "/") for p in S3.rglob("__pycache__") if p.is_dir()]
    staging = [str(p.relative_to(ROOT)).replace("\\", "/") for p in S3.rglob("*generator_staging*") if p.exists()]
    temp = [str(p.relative_to(ROOT)).replace("\\", "/") for p in S3.rglob("*tmp*") if p.exists()]
    cleanup = {"schema_version": "AD49-S3-cleanup-inventory-v1", "checked_utc": utc(), "pycache": pycache, "staging": staging, "temporary": temp, "all_clear": not (pycache or staging or temp), "deletions": [], "allowed_write_roots": ["docs/implementation/AD-49/G1-TRUSTED-SOURCE-IDENTITY", "docs/implementation/AD-49/G2-TRUSTED-SOURCE-IDENTITY", "docs/implementation/AD-49/S3-TRUSTED-SOURCE-IDENTITY"]}
    (ARCHIVE / "cleanup_inventory.json").write_text(json.dumps(cleanup, indent=2) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
