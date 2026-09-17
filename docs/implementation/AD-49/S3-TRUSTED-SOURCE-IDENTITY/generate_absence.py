import hashlib, json, os, pathlib, shutil, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[4]
S3 = pathlib.Path(__file__).resolve().parent
HEAD = "4b69f55f7f80240147a65a22809dc1207824dde2"
REASON = "missing_source_closure_and_independent_attestation_chain"
HANDLE = "fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7"
ENVELOPE_SHA = "17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc"

def digest(rel):
    p = ROOT / rel
    if not p.is_file():
        return {"path": rel, "present": False, "bytes": None, "sha256": None}
    b = p.read_bytes()
    return {"path": rel, "present": True, "bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()}

def git_head_path(rel):
    p = subprocess.run(["git", "cat-file", "-e", "HEAD:" + rel], cwd=ROOT, capture_output=True)
    return {"path": rel, "head_present": p.returncode == 0, "head_exit": p.returncode}

COMMON = [
    "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json",
    "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/acceptance/manifest.json",
    "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/evidence_receipt_axis_schema_v1.json",
    "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g1_evidence_receipt_contract_v1.json",
    "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_applicability_profile_contract_v1.json",
    "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_evidence_receipt_contract_v1.json",
    "docs/implementation/AD-49/S1-ROOT-ACCEPTANCE-R1/manifest.json",
    "docs/implementation/AD-49/S2-G1-G2-FACTORY-IDENTITIES-FRESH-R2/root_acceptance_r1/manifest.json",
    "docs/implementation/AD-49/F0-G1-G2-SOURCE-AUTHORITY-FACTORIES/root_acceptance_r2/manifest.json",
    "docs/implementation/AD-42/W2R1-G1-SOURCE-PAYLOAD-AUTHORING/authoring_receipt.json",
    "docs/implementation/AD-42/W2R1-G1-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json",
    "docs/implementation/AD-42/W2R1-G2-SOURCE-PAYLOAD-AUTHORING/authoring_receipt.json",
    "docs/implementation/AD-42/W2R1-G2-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json",
]

def product(layer, kind):
    low = layer.lower()
    source = f"src/GenomeV5/{layer}/" + ("DiffusionDeclarationV1.jl" if layer == "G1" else "MetricBoundaryDeclarationV1.jl")
    s2 = f"docs/implementation/AD-49/S2-G1-G2-FACTORY-IDENTITIES-FRESH-R2/{low}_factory_" + ("identity_probe.json" if kind == "identity" else "construction_probe_receipt.json")
    inputs = [digest(x) for x in COMMON + [source, s2]]
    head = [git_head_path(x) for x in [source]]
    missing = {
        "independent_attestor": False, "attestor_key": False, "certificate": False,
        "signature": False, "verifier": False, "trust_root": False,
        "revocation_policy": False, "freshness_policy": False, "trusted_time": False,
        "replay_nonce": False
    }
    result = f"Absent{layer}TrustedSourceIdentityV1" if kind == "identity" else f"Absent{layer}TrustedSourceIdentityReceiptV1"
    return {
        "schema_version": f"AD49-{layer}-trusted-source-identity-{'v1' if kind == 'identity' else 'receipt-v1'}",
        "record_kind": f"{layer}TrustedSourceIdentityV1" if kind == "identity" else f"{layer}TrustedSourceIdentityReceiptV1",
        "scope": layer,
        "result": result,
        "status": "typed_absent",
        "reason": REASON,
        "terminal_deferred": True,
        "no_publish": True,
        "present_result_permitted": False,
        "trusted_attestation_created": False,
        "source_authority": False,
        "candidate_identity_created": False,
        "declaration_hash_created": False,
        "final_hash_created": False,
        "inputs": {
            "repository_root": str(ROOT).replace("\\", "/"), "observed_head": HEAD,
            "ad45_handle": {"id": HANDLE, "version": "v5", "envelope_sha256": ENVELOPE_SHA},
            "source_declaration": digest(source), "source_head_closure": head,
            "upstream_artifacts": inputs,
            "external_attestation_chain": missing,
        },
        "forbidden_derivations": ["local_receipt_hash", "reviewer_identity", "fixture", "URI", "seed", "test_exit", "provider_trust_root", "own_hash", "candidate_hash"],
    }

def write_set(out):
    out = pathlib.Path(out); out.mkdir(parents=True, exist_ok=True)
    records = [
        ("G1", "identity", out / "G1" / "g1_trusted_source_identity_v1.json"),
        ("G1", "receipt", out / "G1" / "g1_trusted_source_identity_receipt.json"),
        ("G2", "identity", out / "G2" / "g2_trusted_source_identity_v1.json"),
        ("G2", "receipt", out / "G2" / "g2_trusted_source_identity_receipt.json"),
    ]
    for layer, kind, path in records:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(product(layer, kind), sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8", newline="")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: generate_absence.py OUTPUT_DIR")
    write_set(sys.argv[1])
