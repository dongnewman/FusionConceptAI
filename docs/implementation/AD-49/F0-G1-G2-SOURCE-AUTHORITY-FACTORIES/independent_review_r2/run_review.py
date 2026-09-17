from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


OUT = Path(__file__).resolve().parent
# independent_review_r2/<factory>/<AD-49>/implementation/docs/FusionConceptAI
# The repository root is the fifth parent from the output directory itself
# (parents[4]); parents[5] would incorrectly select the outer LMC workspace.
REPO = OUT.parents[4]
RAW = OUT / "raw"
RAW.mkdir(parents=True, exist_ok=True)
TASK = "AD49-F0-G1-G2-SOURCE-AUTHORITY-FACTORIES-INDEPENDENT-REVIEW-R2"
REVIEW_REL = "docs/implementation/AD-49/F0-G1-G2-SOURCE-AUTHORITY-FACTORIES/independent_review_r2/"


def utc() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_hash(rel: str) -> dict:
    p = REPO / rel
    b = p.read_bytes()
    return {"path": rel, "exists": True, "bytes": len(b), "sha256": sha(b)}


def run(name: str, argv: list[str], cwd: Path = REPO) -> dict:
    start = utc()
    p = subprocess.run(argv, cwd=cwd, capture_output=True, text=False)
    end = utc()
    out = p.stdout or b""
    err = p.stderr or b""
    (RAW / f"{name}_stdout.txt").write_bytes(out)
    (RAW / f"{name}_stderr.txt").write_bytes(err)
    return {
        "name": name,
        "command": argv,
        "cwd": str(cwd).replace("\\", "/"),
        "pid": os.getpid(),
        "utc_start": start,
        "utc_end": end,
        "exit_code": p.returncode,
        "stdout_bytes": len(out),
        "stdout_sha256": sha(out),
        "stderr_bytes": len(err),
        "stderr_sha256": sha(err),
    }


def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], cwd=REPO, capture_output=True, text=True, encoding="utf-8", errors="replace")


def checkout_status() -> dict:
    """Summarize pre-existing checkout status without recursively embedding it."""
    lines = git("status", "--short", "--untracked-files=all").stdout.splitlines()
    kept = []
    for line in lines:
        path = line[3:].replace("\\", "/") if len(line) >= 3 else ""
        if not path.startswith(REVIEW_REL):
            kept.append(line)
    payload = ("\n".join(kept) + "\n").encode("utf-8")
    return {"count": len(kept), "sha256": sha(payload), "review_outputs_excluded": True}


def load_json(rel: str):
    return json.loads((REPO / rel).read_text(encoding="utf-8"))


def main() -> int:
    before_status = checkout_status()
    failures: list[str] = []
    checks: dict[str, dict] = {}

    def check(name: str, passed: bool, observed=None, note: str = ""):
        checks[name] = {"pass": bool(passed), "observed": observed, "note": note}
        if not passed:
            failures.append(name)

    review_meta = {
        "schema_version": "AD49-F0-independent-review-R2-baseline-v1",
        "task_id": TASK,
        "reviewer": "different gpt-5.6-luna/high",
        "repo": str(REPO).replace("\\", "/"),
        "head": git("rev-parse", "HEAD").stdout.strip(),
        "python": sys.executable.replace("\\", "/"),
        "python_version": sys.version.split()[0],
        "pid": os.getpid(),
        "utc": utc(),
        "before_status": before_status,
    }
    (OUT / "baseline.json").write_text(json.dumps(review_meta, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    products = {
        "g1_factory": "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
        "g1_tests": "test/GenomeV5/G1/g1_source_authority_factory_v1_tests.jl",
        "g2_factory": "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
        "g2_tests": "test/GenomeV5/G2/g2_source_authority_factory_v1_tests.jl",
    }
    product_hashes = {}
    for key, rel in products.items():
        try:
            product_hashes[key] = file_hash(rel)
            check(f"product_{key}_exists", True, product_hashes[key])
        except Exception as exc:
            product_hashes[key] = {"path": rel, "exists": False, "error": repr(exc)}
            check(f"product_{key}_exists", False, product_hashes[key])

    protected = {
        "src/Contracts/GenomeContractRegistry.jl": file_hash("src/Contracts/GenomeContractRegistry.jl"),
        "src/IR/OperatorRegistry.jl": file_hash("src/IR/OperatorRegistry.jl"),
        "src/FusionConceptAI.jl": file_hash("src/FusionConceptAI.jl"),
        "src/GenomeV5/G1/DiffusionDeclarationV1.jl": file_hash("src/GenomeV5/G1/DiffusionDeclarationV1.jl"),
        "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl": file_hash("src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"),
    }
    (OUT / "protected_hashes_before.json").write_text(json.dumps(protected, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    # The main checkout deliberately contains untracked G1/G2 source snapshots.
    for rel in ("src/GenomeV5/G1/DiffusionDeclarationV1.jl", "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"):
        ls = git("ls-files", "--error-unmatch", "--", rel)
        cat = git("cat-file", "-e", f"HEAD:{rel}")
        status = git("status", "--porcelain=v1", "--untracked-files=all", "--", rel)
        check(f"main_{Path(rel).parts[2].lower()}_locator_typed_absence", ls.returncode != 0 and cat.returncode != 0 and status.stdout.startswith("??"), {
            "ls_files_exit": ls.returncode, "cat_file_exit": cat.returncode, "status": status.stdout,
        }, "Current source-stage authority remains typed absent.")

    # Static closure audit is independent of the product tests.
    g1 = (REPO / products["g1_factory"]).read_text(encoding="utf-8")
    g2 = (REPO / products["g2_factory"]).read_text(encoding="utf-8")
    g1t = (REPO / products["g1_tests"]).read_text(encoding="utf-8")
    g2t = (REPO / products["g2_tests"]).read_text(encoding="utf-8")
    for layer, src, tst in (("g1", g1, g1t), ("g2", g2, g2t)):
        required_source = (
            f"_{layer}sf_repository_anchor", f"_{layer}sf_validate_locator",
            '"show"', '"cat-file"', "working_tree_head_bytes_mismatch",
            "head_blob_sha256_mismatch", "temporary_common_candidate_binding_handle_only",
            "source_content_hash", "declaration_hash", "binding_hash", "factory_identity_hash",
            "trusted=false", "candidate_identity_created=false", "final_candidate_or_package_hash_created=false",
        )
        check(f"{layer}_factory_required_closure_tokens", all(t in src for t in required_source),
              {"missing": [t for t in required_source if t not in src]})
        controls = {
            "relabelled_fixture": "relabel" in tst and "repository_head" in tst,
            "anchor_unavailable": "missing-module-dir" in tst and f"_{layer}sf_repository_anchor" in tst,
            "assume_unchanged": "assume-unchanged" in tst,
            "skip_worktree": "skip-worktree" in tst,
            "head_blob_mismatch": "head-blob-mismatch" in tst,
            "main_typed_absence": "_current_locator" in tst and "typed_absent" in tst,
            "fixture_synthetic": "isolated_test_fixture" in tst and "synthetic_test_only" in tst,
        }
        check(f"{layer}_tests_required_negative_controls", all(controls.values()), controls)
    check("g2_no_contract_to_handle_mapping_api", not re.search(r"(?:map|mapping)[A-Za-z_]*(?:GenomeContractRef|QualifiedRefV1)|(?:GenomeContractRef|QualifiedRefV1)[A-Za-z_]*(?:map|mapping)", g2, re.I), {
        "mapping_api_matches": re.findall(r"(?:map|mapping)[A-Za-z_]*(?:GenomeContractRef|QualifiedRefV1)|(?:GenomeContractRef|QualifiedRefV1)[A-Za-z_]*(?:map|mapping)", g2, re.I)
    })
    check("no_registry_or_entrypoint_symbol_in_factories", all(x not in g1 + g2 for x in ("default_operator_registry", "GenomeContractRegistry", "FusionConceptAI.jl")), None)
    check("factory_modules_have_no_desc_or_solver", not re.search(r"DESC|FreeGS|Gridap|solver", g1 + g2, re.I), None)

    # Recompute upstream contract/product bytes declared by the F0 package.
    refs = {
        "g1_s1_locator": "docs/implementation/AD-49/G1-SOURCE-LOCATOR/g1_source_locator_v1.json",
        "g2_s1_locator": "docs/implementation/AD-49/G2-SOURCE-LOCATOR/g2_source_locator_v1.json",
        "ad45_envelope": "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json",
        "g1_payload": "docs/implementation/AD-42/W2R1-G1-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json",
        "g2_payload": "docs/implementation/AD-42/W2R1-G2-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json",
    }
    ref_hashes = {k: file_hash(v) for k, v in refs.items()}
    check("upstream_inputs_rehashable", all(v["exists"] for v in ref_hashes.values()), ref_hashes)

    # Fresh plan and scoped diff receipts; the latter checks tracked review bytes.
    plan = run("plan_validator", [sys.executable, "docs/v4_multitopology_generation/validate_plan.py"])
    diff = run("scoped_diff_check", ["git", "diff", "--check", "--", "docs/implementation/AD-49/F0-G1-G2-SOURCE-AUTHORITY-FACTORIES/independent_review_r2"])
    check("plan_validator_exit_zero", plan["exit_code"] == 0, plan)
    check("scoped_diff_check_exit_zero", diff["exit_code"] == 0, diff)

    # Product/source protection after all read-only checks.
    protected_after = {rel: file_hash(rel) for rel in protected}
    check("protected_files_unchanged", protected_after == protected, {"before": protected, "after": protected_after})
    after_status = checkout_status()
    status_unchanged = before_status["count"] == after_status["count"] and before_status["sha256"] == after_status["sha256"]
    check("new_files_scope_only_r2", status_unchanged, {"before": before_status, "after": after_status})

    result = {
        "schema_version": "AD49-F0-independent-review-R2-direct-v1",
        "task_id": TASK,
        "reviewer": "different gpt-5.6-luna/high",
        "repo": str(REPO).replace("\\", "/"),
        "head": review_meta["head"],
        "pid": os.getpid(),
        "python": sys.executable.replace("\\", "/"),
        "python_version": sys.version.split()[0],
        "utc_end": utc(),
        "exit_code": 0 if not failures else 1,
        "checks": checks,
        "failures": failures,
        "product_hashes": product_hashes,
        "protected_hashes_before": protected,
        "protected_hashes_after": protected_after,
        "upstream_hashes": ref_hashes,
        "plan_validator": plan,
        "scoped_diff_check": diff,
        "before_status": before_status,
        "after_status": after_status,
        "status_unchanged_outside_review": status_unchanged,
    }
    (OUT / "direct_validation.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (OUT / "plan_validator_receipt.json").write_text(json.dumps(plan, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (OUT / "scoped_diff_check.json").write_text(json.dumps(diff, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return result["exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())
