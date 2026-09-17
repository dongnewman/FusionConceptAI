import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
PRODUCTS = {
    "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl": "cf52fa4b0240dc25b793940a199153edc019190a7d2da106524a150514139a92",
    "test/GenomeV5/G1/g1_source_authority_factory_v1_tests.jl": "3e257e8b0b8a75cee36cac29f5aa3dc6a67e1f59aed28f31b07623a2c6154726",
    "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl": "1e64993eced7f7741eef46e840062a6bf1868593770314db33949de2918e919c",
    "test/GenomeV5/G2/g2_source_authority_factory_v1_tests.jl": "907d797f39fb4be8fbdc59d2dd8aeaa1d238e4f0544a95e525bd8e6c2931c5fd",
}
PROTECTED = {
    "src/Contracts/GenomeContractRegistry.jl": "ee57228623e314897a3e34f3bfd387e8cce4d89c2b0dfaaf29d227076a08495c",
    "src/IR/OperatorRegistry.jl": "4c2f4383140527613782288749283d268497846ec915df158164875125677f45",
    "src/FusionConceptAI.jl": "e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783",
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run(*args):
    p = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return {"exit": p.returncode, "stdout": p.stdout, "stderr": p.stderr}

result = {"cwd": str(ROOT), "products": {}, "protected": {}, "git": {}, "static": {}}
for rel, expected in PRODUCTS.items():
    p = ROOT / rel
    result["products"][rel] = {"exists": p.is_file(), "bytes": p.stat().st_size if p.is_file() else None,
                                "sha256": sha(p) if p.is_file() else None, "expected_sha256": expected}
for rel, expected in PROTECTED.items():
    p = ROOT / rel
    result["protected"][rel] = {"exists": p.is_file(), "bytes": p.stat().st_size if p.is_file() else None,
                                 "sha256": sha(p) if p.is_file() else None, "expected_sha256": expected}
for rel in ("src/GenomeV5/G1/DiffusionDeclarationV1.jl", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"):
    result["git"][rel] = {
        "head_path": run("git", "cat-file", "-e", f"HEAD:{rel}"),
        "status": run("git", "status", "--porcelain=v1", "--untracked-files=all", "--", rel),
    }
for rel in PRODUCTS:
    text = (ROOT / rel).read_text(encoding="utf-8")
    result["static"][rel] = {
        "required": all(token in text for token in ("source_content_hash", "binding_hash", "candidate_identity_created=false", "temporary_common_candidate_binding_handle_only")),
        "forbidden_registry_mutation_tokens": [token for token in ("default_operator_registry", "GenomeContractRegistry") if token in text],
    }
diff = run("git", "diff", "--check", "--", "docs/implementation/AD-49/F0-G1-G2-SOURCE-AUTHORITY-FACTORIES/independent_review_r1")
result["git"]["scoped_diff_check"] = diff
result["all_product_hashes_match"] = all(x["exists"] and x["sha256"] == x["expected_sha256"] for x in result["products"].values())
result["all_protected_hashes_match"] = all(x["exists"] and x["sha256"] == x["expected_sha256"] for x in result["protected"].values())
result["source_head_absent"] = all(x["head_path"]["exit"] != 0 for x in result["git"].values() if isinstance(x, dict) and "head_path" in x)
print(json.dumps(result, indent=2, sort_keys=True))
