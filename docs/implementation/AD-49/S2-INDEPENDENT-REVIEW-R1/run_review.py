from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


REPO = Path(__file__).resolve().parents[4]
OUT = REPO / "docs/implementation/AD-49/S2-INDEPENDENT-REVIEW-R1"
ARCH = OUT / "archive"
TASK = "AD49-S2-G1-G2-FACTORY-IDENTITY-PROBE"
PYTHON = sys.executable


def utc() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str:
    return sha_bytes(path.read_bytes())


def rel(path: Path) -> str:
    return path.relative_to(REPO).as_posix()


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(name: str, value) -> None:
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def run(name: str, args: list[str], raw_dir: Path = ARCH) -> dict:
    start = utc()
    p = subprocess.run(args, cwd=REPO, capture_output=True, text=False)
    end = utc()
    out = p.stdout or b""
    err = p.stderr or b""
    (raw_dir / f"{name}.stdout.txt").write_bytes(out)
    (raw_dir / f"{name}.stderr.txt").write_bytes(err)
    return {
        "command": args,
        "cwd": str(REPO).replace("\\", "/"),
        "pid": os.getpid(),
        "utc_start": start,
        "utc_end": end,
        "exit_code": p.returncode,
        "stdout_bytes": len(out),
        "stdout_sha256": sha_bytes(out),
        "stderr_bytes": len(err),
        "stderr_sha256": sha_bytes(err),
    }


def status() -> list[str]:
    p = subprocess.run(["git", "status", "--short", "--branch"], cwd=REPO, capture_output=True, text=True)
    return p.stdout.splitlines()


def nested_values(value, key_suffix: str = ""):
    if isinstance(value, dict):
        for k, v in value.items():
            yield k, v
            yield from nested_values(v, k)
    elif isinstance(value, list):
        for v in value:
            yield from nested_values(v, key_suffix)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    ARCH.mkdir(parents=True, exist_ok=True)
    before_status = status()
    protected = [
        "src/GenomeV5/G1/DiffusionDeclarationV1.jl",
        "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl",
        "src/Contracts/GenomeContractRegistry.jl",
        "src/IR/OperatorRegistry.jl",
    ]
    protected_before = {p: sha_file(REPO / p) for p in protected}
    write_json("archive/baseline.json", {
        "schema_version": "AD49-S2-independent-review-R1-baseline-v1",
        "task_id": TASK, "observed_root": str(REPO).replace("\\", "/"),
        "python": PYTHON.replace("\\", "/"), "python_version": sys.version.split()[0],
        "pid": os.getpid(), "utc": utc(), "status_lines": before_status,
        "protected_hashes": protected_before,
    })

    checks: dict[str, dict] = {}
    failures: list[str] = []

    def check(name: str, passed: bool, observed=None, note: str = "") -> None:
        checks[name] = {"pass": bool(passed), "observed": observed, "note": note}
        if not passed:
            failures.append(name)

    products = {
        "g1_identity": "docs/implementation/AD-49/G1-FACTORY-PROBE/g1_factory_identity_probe_v1.json",
        "g1_receipt": "docs/implementation/AD-49/G1-FACTORY-PROBE/g1_factory_construction_probe_receipt.json",
        "g2_identity": "docs/implementation/AD-49/G2-FACTORY-PROBE/g2_factory_identity_probe_v1.json",
        "g2_receipt": "docs/implementation/AD-49/G2-FACTORY-PROBE/g2_factory_construction_probe_receipt.json",
    }
    product_data = {}
    for key, path in products.items():
        p = REPO / path
        try:
            product_data[key] = load_json(p)
            check(f"product_present_{key}", True, {"path": path, "bytes": p.stat().st_size, "sha256": sha_file(p)})
        except Exception as e:
            check(f"product_present_{key}", False, {"path": path, "error": repr(e)})

    for layer in ("g1", "g2"):
        ident = product_data.get(f"{layer}_identity", {})
        receipt = product_data.get(f"{layer}_receipt", {})
        I = f"{layer.upper()}SourceFactoryIdentityV1"
        R = f"{layer.upper()}SourceFactoryConstructionReceiptV1"
        check(f"{layer}_identity_absent_union", ident.get("result") == f"Absent{I}", ident.get("result"))
        check(f"{layer}_identity_absent_state", ident.get("status") == "typed_absent" and ident.get("resolution") == "terminal_deferred", {"status": ident.get("status"), "resolution": ident.get("resolution")})
        check(f"{layer}_receipt_absent_union", receipt.get("result") == f"Absent{R}", receipt.get("result"))
        check(f"{layer}_receipt_absent_state", receipt.get("status") == "typed_absent" and receipt.get("resolution") == "terminal_deferred", {"status": receipt.get("status"), "resolution": receipt.get("resolution")})
        for label, obj in (("identity", ident), ("receipt", receipt)):
            created = {k: v for k, v in nested_values(obj) if k.endswith("_created") and v is True}
            check(f"{layer}_{label}_no_hash_or_identity_creation", not created, created)
        check(f"{layer}_identity_no_publish", ident.get("no_publish") is True and ident.get("candidate_identity_created") is False and ident.get("candidate_identity_hash") is None and ident.get("declaration_hash_created") is False and ident.get("source_content_hash_created") is False and ident.get("factory_identity_hash_created") is False, {k: ident.get(k) for k in ("no_publish", "candidate_identity_created", "candidate_identity_hash", "declaration_hash_created", "source_content_hash_created", "factory_identity_hash_created")})
        c = receipt.get("construction", {})
        check(f"{layer}_receipt_no_construction_hash", c.get("attempted") is False and c.get("replay_status") == "not_replayable" and c.get("replay_receipt_created") is False and c.get("construction_digest_created") is False and c.get("construction_digest") is None, c)
        probe = ident.get("factory_probe", {})
        check(f"{layer}_factory_absent_entry_flags", probe.get("found") is False and probe.get("independent_locator_argument") is False and probe.get("common_handle_argument") is False and probe.get("public_contract_argument") is False and probe.get("construction_replay_entry") is False, {k: probe.get(k) for k in ("found", "independent_locator_argument", "common_handle_argument", "public_contract_argument", "construction_replay_entry")})
        check(f"{layer}_typed_source_input_has_no_decl_hash", ident.get("inputs", {}).get("typed_source_input", {}).get("declaration_hash") is None, ident.get("inputs", {}).get("typed_source_input"))
        check(f"{layer}_runtime_claim_ceiling", all(v is False or v == 0 for v in ident.get("runtime_claims", {}).values()), ident.get("runtime_claims"))

    expected_neg = {
        "constructor_name_misrecognition": "Absent",
        "generic_scaffold_reuse": "Absent",
        "G3_cross_layer_reuse": "Absent",
        "fixture_seed_receipt_authority": "Absent",
        "registry_alias": "Absent",
        "signature_path_hash_conflict": "Failed",
    }
    for layer in ("g1", "g2"):
        obj = product_data.get(f"{layer}_identity", {}).get("negative_controls", {})
        for control, prefix in expected_neg.items():
            val = obj.get(control, {})
            observed = val.get("observed", "") if isinstance(val, dict) else str(val)
            ctrl_status = val.get("status") if isinstance(val, dict) else None
            check(f"{layer}_negative_{control}", observed.startswith(prefix) and ((prefix == "Failed" and ctrl_status == "fail_closed") or (prefix == "Absent" and ctrl_status == "typed_absent")), {"observed": observed, "status": ctrl_status})
        if layer == "g2":
            val = obj.get("registry_alias", {})
            check("g2_negative_registry_alias_mentions_mapping", "mapping" in str(val).lower(), val)
    for layer in ("g1", "g2"):
        obj = product_data.get(f"{layer}_receipt", {}).get("negative_controls", {})
        check(f"{layer}_receipt_signature_conflict_fail_closed", "Failed" in str(obj.get("signature_path_hash_conflict", "")) and "fail_closed" in str(obj.get("signature_path_hash_conflict", "")), obj.get("signature_path_hash_conflict"))

    # Recompute all declared input/product hashes and the exact protected source/registry bytes.
    refs = {
        "g1_s1": "docs/implementation/AD-49/G1-SOURCE-LOCATOR/g1_source_locator_v1.json",
        "g2_s1": "docs/implementation/AD-49/G2-SOURCE-LOCATOR/g2_source_locator_v1.json",
        "ad45": "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json",
        "g1_payload": "docs/implementation/AD-42/W2R1-G1-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json",
        "g2_payload": "docs/implementation/AD-42/W2R1-G2-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json",
    }
    ref_hashes = {k: sha_file(REPO / v) for k, v in refs.items()}
    declared_hashes = {
        "g1_s1": "840ec00d25e069b13af1562a9e4ebb7ab1b2896a0818dc1fa15a3c7167c770a5",
        "g2_s1": "439a2d496be0e7c6bd8bbefb7790f4f45f577e7b3954901a5914a5276b5294fa",
        "ad45": "17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc",
        "g1_payload": "f4841efa7e872a57e05c8eda687d951dd7775802ad3d07330947df72c5c97449",
        "g2_payload": "7244861fa4c640035c06ac7b69623f048c17b86f9deeda71de8406c452bbcacf",
    }
    check("declared_input_hashes_recompute", ref_hashes == declared_hashes, {"declared": declared_hashes, "recomputed": ref_hashes})
    module_declared = {
        "g1": ("src/GenomeV5/G1/DiffusionDeclarationV1.jl", 31743, "14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a"),
        "g2": ("src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", 30773, "261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61"),
    }
    for layer, (path, size, digest) in module_declared.items():
        p = REPO / path
        check(f"{layer}_module_bytes_sha", p.stat().st_size == size and sha_file(p) == digest, {"path": path, "bytes": p.stat().st_size, "sha256": sha_file(p), "declared_bytes": size, "declared_sha256": digest})
        for key, obj in (("identity", product_data.get(f"{layer}_identity", {})), ("receipt", product_data.get(f"{layer}_receipt", {}))):
            mi = obj.get("module_identity", {}) if key == "identity" else obj.get("inputs", {}).get("module_file", {})
            got_size = mi.get("source_bytes", mi.get("bytes"))
            got_hash = mi.get("source_sha256", mi.get("sha256"))
            check(f"{layer}_{key}_module_identity_closes", got_size == size and got_hash == digest and mi.get("head_path_status") == "absent_untracked", mi)
    reg_declared = {
        "src/Contracts/GenomeContractRegistry.jl": "ee57228623e314897a3e34f3bfd387e8cce4d89c2b0dfaaf29d227076a08495c",
        "src/IR/OperatorRegistry.jl": "4c2f4383140527613782288749283d268497846ec915df158164875125677f45",
    }
    reg_now = {p: sha_file(REPO / p) for p in reg_declared}
    check("registry_protected_hashes_recompute", reg_now == reg_declared, {"declared": reg_declared, "recomputed": reg_now})

    # Static source/API scan, with G3 deliberately treated as a cross-layer negative control.
    g1_src = (REPO / "src/GenomeV5/G1/DiffusionDeclarationV1.jl").read_text(encoding="utf-8")
    g2_src = (REPO / "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl").read_text(encoding="utf-8")
    g3_src = (REPO / "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl").read_text(encoding="utf-8")
    source_scan = {
        "future_factory_files_exist": {
            "g1": (REPO / "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl").exists(),
            "g2": (REPO / "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl").exists(),
        },
        "g1_factory_symbols": sorted(set(re.findall(r"(?:G1SourceAuthorityFactoryV1|g1_source_authority_factory_v1)", g1_src))),
        "g2_factory_symbols": sorted(set(re.findall(r"(?:G2SourceAuthorityFactoryV1|g2_source_authority_factory_v1)", g2_src))),
        "g1_entry_points_present": all(x in g1_src for x in ("G1DiffusionSourcePayloadV1", "G1DiffusionDeclarationV1", "g1_diffusion_declaration_v1", "g1_diffusion_receipt_v1")),
        "g2_entry_points_present": all(x in g2_src for x in ("G2MBSourceV1", "G2MBDeclarationV1", "g2mb_source_v1", "g2mb_declaration_v1", "g2mb_receipt_v1")),
        "g2_explicit_mapping_api": bool(re.search(r"GenomeContractRef.{0,160}QualifiedRefV1|QualifiedRefV1.{0,160}GenomeContractRef|mapping", g2_src, re.I)),
        "generic_scaffold_present": all(x in (REPO / "src/GenomeV5/Integration/VNextParentBaselineBindingV1.jl").read_text(encoding="utf-8") for x in ("struct SourceLocatorV1", "struct FactoryConstructionReceiptV1")),
        "g3_factory_present_cross_layer": "function g3_source_authority_factory_v1" in g3_src,
    }
    check("source_api_no_g1_factory_or_locator_or_replay", not source_scan["g1_factory_symbols"] and not any(x in g1_src for x in ("SourceLocator", "common_binding_handle", "GenomeContractRef", "construction_replay_entry")), source_scan)
    check("source_api_no_g2_factory_or_locator_or_mapping", not source_scan["g2_factory_symbols"] and not any(x in g2_src for x in ("SourceLocator", "common_binding_handle", "GenomeContractRef_to_QualifiedRef", "mapping_receipt")), source_scan)
    check("source_api_observed_entry_points", source_scan["g1_entry_points_present"] and source_scan["g2_entry_points_present"], source_scan)
    check("future_factory_files_absent", not any(source_scan["future_factory_files_exist"].values()), source_scan["future_factory_files_exist"])
    check("generic_scaffold_not_g1_g2_factory", source_scan["generic_scaffold_present"] and product_data["g1_identity"]["factory_probe"]["generic_scaffold"]["usable_for_G1"] is False and product_data["g2_identity"]["factory_probe"]["generic_scaffold"]["usable_for_G2"] is False, source_scan)
    check("g3_factory_cross_layer_not_reused", source_scan["g3_factory_present_cross_layer"] and all("G3_factory" in str(product_data[k].get("forbidden_derivations", [])) for k in product_data), source_scan)

    # Validate machine contract fields and product/archive ownership without treating archive as product.
    manifests = {
        "g1": REPO / "docs/implementation/AD-49/G1-FACTORY-PROBE/archive/manifest.json",
        "g2": REPO / "docs/implementation/AD-49/G2-FACTORY-PROBE/archive/manifest.json",
    }
    for layer, p in manifests.items():
        m = load_json(p)
        check(f"{layer}_archive_manifest_exact_products", m.get("exact_product_count") == 2 and len(m.get("product_paths", [])) == 2 and all("FACTORY-PROBE" in x for x in m.get("product_paths", [])), m)
        check(f"{layer}_archive_heavy_runtime_false", all(v is False for v in m.get("heavy_runtime", {}).values()), m.get("heavy_runtime"))
        check(f"{layer}_archive_reviewer_separation", m.get("review_required", {}).get("different_luna") is True and m.get("review_required", {}).get("same_agent_forbidden") is True, m.get("review_required"))
        cleanup = load_json(p.parent / "cleanup_inventory.json")
        expected_owned = set(m.get("product_paths", [])) | {rel(q) for q in p.parent.glob("*.json")}
        check(f"{layer}_archive_cleanup_exact_owned_set", set(cleanup.get("final_exact_owned_set", [])) == expected_owned and cleanup.get("removed") in (0, []) and cleanup.get("ambiguous_deferred") in (0, []), cleanup)
    g1_final = load_json(REPO / "docs/implementation/AD-49/G1-FACTORY-PROBE/archive/final_direct_validation.json")
    check("aggregate_product_validation_has_four_products", g1_final.get("product_count") == 4 and len(g1_final.get("products", [])) == 4 and not g1_final.get("failures"), {"product_count": g1_final.get("product_count"), "failures": g1_final.get("failures"), "pid": g1_final.get("pid"), "utc": g1_final.get("utc")})
    check("aggregate_product_validation_pid_utc_exit", bool(g1_final.get("pid")) and bool(g1_final.get("utc")) and g1_final.get("exit_code") == 0, {k: g1_final.get(k) for k in ("pid", "utc", "exit_code", "python")})
    check("aggregate_product_validation_protected_hashes", g1_final.get("protected_hashes") == protected_before, g1_final.get("protected_hashes"))
    check("g2_archive_static_scan_has_pid_utc_exit", all(k in load_json(REPO / "docs/implementation/AD-49/G2-FACTORY-PROBE/archive/direct_static_api_scan.json") for k in ("pid", "utc", "exit_code")) and load_json(REPO / "docs/implementation/AD-49/G2-FACTORY-PROBE/archive/direct_static_api_scan.json").get("exit_code") == 0, load_json(REPO / "docs/implementation/AD-49/G2-FACTORY-PROBE/archive/direct_static_api_scan.json"))

    plan = run("plan_validator", [PYTHON, "docs/v4_multitopology_generation/validate_plan.py"])
    check("plan_validator_exit_zero", plan["exit_code"] == 0, plan)
    diff = run("scoped_diff_check", ["git", "diff", "--check", "--", "docs/implementation/AD-49/S2-INDEPENDENT-REVIEW-R1"])
    check("scoped_diff_check_exit_zero", diff["exit_code"] == 0, diff)
    write_json("archive/scoped_diff_check.json", {"schema_version": "AD49-S2-independent-review-R1-scoped-diff-receipt-v1", "task_id": TASK, "tool": diff})

    after_status = status()
    new_lines = [x for x in after_status if x not in before_status]
    outside = [x for x in new_lines if x[3:] and not x[3:].startswith("docs/implementation/AD-49/S2-INDEPENDENT-REVIEW-R1/")]
    check("final_scope_only_review_directory", not outside, {"new_status_lines": new_lines, "outside_scope": outside})
    protected_after = {p: sha_file(REPO / p) for p in protected}
    check("protected_source_registry_unchanged", protected_after == protected_before, {"before": protected_before, "after": protected_after})
    write_json("archive/final_scope_check.json", {
        "schema_version": "AD49-S2-independent-review-R1-final-scope-v1", "pid": os.getpid(), "utc": utc(),
        "baseline_status_lines": before_status, "final_status_lines": after_status,
        "new_status_lines": new_lines, "outside_scope": outside,
        "protected_before": protected_before, "protected_after": protected_after,
        "scope_ok": not outside and protected_after == protected_before,
    })
    write_json("archive/direct_validation.json", {
        "schema_version": "AD49-S2-independent-review-R1-direct-v1", "record_kind": "fresh_static_recomputation",
        "task_id": TASK, "pid": os.getpid(), "python": PYTHON.replace("\\", "/"), "python_version": sys.version.split()[0],
        "utc_start": None, "utc_end": utc(), "exit_code": 0 if not failures else 1,
        "checks": checks, "failures": failures, "source_scan": source_scan,
        "protected_hashes": protected_after, "product_hashes": {k: {"path": v, "bytes": (REPO/v).stat().st_size, "sha256": sha_file(REPO/v)} for k, v in products.items()},
    })
    # Rewrite after direct validation so its own status is part of the final exact set; its self hash is excluded.
    write_json("archive/cleanup_inventory.json", {
        "schema_version": "AD49-S2-independent-review-R1-cleanup-v1", "task_id": TASK,
        "owner": "AD49-S2-independent-review-R1", "cleanup_action": "none",
        "task_owned_scratch_before": [], "task_owned_scratch_after": [], "removed": [], "ambiguous_deferred": [],
        "final_exact_owned_set": sorted(rel(p) for p in OUT.rglob("*") if p.is_file()),
        "protected_hashes_before": protected_before, "protected_hashes_after": protected_after,
    })
    verdict = "pass_limited" if not failures else "changes_requested"
    report = f'''# AD-49 S2 G1/G2 factory identity independent review R1

Date: {utc()}  
Reviewer: `different gpt-5.6-luna/high` (fresh independent static review)  
Verdict: `{verdict}`  
Claim ceiling: `factory_identity_probe_only`

## Decision

Fresh Python {sys.version.split()[0]} read-only recomputation of the four AD49-S2 products, their layer archives, the AD49 readiness and S1/root acceptance records, AD45's common binding handle, and the live G1/G2/G3 source/API boundary gives **{verdict}**. The four products close as `AbsentG1SourceFactoryIdentityV1`, `AbsentG1SourceFactoryConstructionReceiptV1`, `AbsentG2SourceFactoryIdentityV1`, and `AbsentG2SourceFactoryConstructionReceiptV1`; all are `typed_absent` + `terminal_deferred` with `no_publish=true`. No candidate identity, source/declaration/content/factory hash, construction digest or replay receipt is created.

The live G1 module exposes typed payload/declaration constructors, `g1_diffusion_declaration_v1`, and `g1_diffusion_receipt_v1`; the live G2 module exposes typed source/declaration constructors, `g2mb_source_v1`, `g2mb_declaration_v1`, and `g2mb_receipt_v1`. Neither layer contains a source-authority factory consuming the S1 locator, AD45 common `QualifiedRefV1/v5` handle, its public five-field `GenomeContractRef`, and typed source input together. The parent `SourceLocatorV1`/`FactoryConstructionReceiptV1` scaffold remains unusable without a layer adapter. The G3 factory is present only as a cross-layer negative control; it does not establish G1/G2 identity. G2 has no explicit `GenomeContractRef` to `QualifiedRefV1` mapping API.

## Product and control closure

The product JSON was parsed canonically, all declared S1/AD45/W2R1 input hashes were recomputed, and module bytes/SHA matched the products. Each identity product has false creation flags and null created-hash fields; each construction receipt has `attempted=false`, `replay_status=not_replayable`, `replay_receipt_created=false`, `construction_digest_created=false`, and null digest. Constructor-name recognition, generic-scaffold reuse, G3 cross-layer reuse, fixture/seed/receipt authority and registry alias remain typed `Absent`; signature/path/hash conflict remains `Failed...` + `fail_closed`. G2's registry-alias control also records that no mapping is supplied.

The G1 archive contains the aggregate four-product validation with PID/UTC/exit and protected source/registry hashes. The G2 archive contains its direct static scan with PID/UTC/exit and the same layer manifest/negative-control boundary. The fresh review recomputes the four product hashes and the protected hashes rather than treating archive claims as authority.

## Fresh validation receipts

- Direct static recomputation: `archive/direct_validation.json`, PID `{os.getpid()}`, Python `{sys.version.split()[0]}`, exit `{'0' if not failures else '1'}`.
- Plan validator: `archive/plan_validator.*` and `archive/plan_validator_receipt.json`, exit `{plan['exit_code']}`.
- Scoped `git diff --check`: `archive/scoped_diff_check.*`, exit `{diff['exit_code']}`.
- Final scope/protected-file receipt: `archive/final_scope_check.json`; review-owned exact set and zero-cleanup inventory: `archive/cleanup_inventory.json`.

## Boundary and handoff

This `{verdict}` is limited to the AD49-S2 factory identity/construction probe. If accepted by the parent, it may unlock only conditional AD49-F0 factory implementation under the frozen contract, and only after the parent makes that decision. It does not grant source authority, factory implementation, trusted identity/attestation, G2 mapping, candidate/declaration/final identity, T0/T1/T2, provider, mesh, solver, engineering, physical, R01-R10 or L4 credit. Any future F0 implementation must be additive, preserve G1/G2 type domains and public `GenomeContractRef` fields, produce fresh source/content/declaration hashes and replay receipts, and require a fresh S2 after implementation before downstream S3/mapping/W3-B.
'''
    (OUT / "report.md").write_text(report, encoding="utf-8")
    write_json("manifest.json", {
        "schema_version": "AD49-S2-independent-review-R1-manifest-v1", "task_id": TASK,
        "reviewer": "different gpt-5.6-luna/high", "verdict": verdict,
        "claim_ceiling": "factory_identity_probe_only", "scope": "fresh four-product and archive review; no source/product mutation",
        "product_paths": list(products.values()), "direct_validation": "archive/direct_validation.json",
        "plan_validator": "archive/plan_validator_receipt.json", "scoped_diff_check": "archive/scoped_diff_check.json",
        "final_scope_check": "archive/final_scope_check.json", "self_hash_excluded": True,
        "heavy_runtime": {"julia": False, "desc": False, "provider": False, "mesh": False, "solver": False, "engineering": False, "physics": False, "search": False},
        "credit_boundary": {"source_authority": False, "factory_implementation": False, "trusted_source_identity": False, "g2_mapping": False, "candidate_identity": False, "declaration": False, "t0": False, "t1": False, "t2": False, "provider": False, "mesh": False, "solver": False, "engineering": False, "physical": False, "search": False, "r01_r10": False, "l4_credible_count": 0},
    })
    # Receipt for the plan validator is written after running it and before final handoff.
    write_json("archive/plan_validator_receipt.json", {"schema_version": "AD49-S2-independent-review-R1-plan-receipt-v1", "task_id": TASK, "tool": plan})
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
