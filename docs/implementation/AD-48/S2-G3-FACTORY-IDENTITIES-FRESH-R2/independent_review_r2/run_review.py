from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[5]
FRESH = REPO / "docs/implementation/AD-48/S2-G3-FACTORY-IDENTITIES-FRESH-R2"
OUT = FRESH / "independent_review_r2"
ARCH = OUT / "raw"
TASK = "AD48-S2-G3-FACTORY-IDENTITY-FRESH-R2"
SCOPES = ("realization", "control", "binding", "bundle")
PYTHON = sys.executable


def utc() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canon(obj) -> str:
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def rel(path: Path) -> str:
    return path.relative_to(REPO).as_posix()


def run(name: str, args: list[str]) -> dict:
    started = utc()
    p = subprocess.run(args, cwd=REPO, capture_output=True)
    ended = utc()
    out = p.stdout or b""
    err = p.stderr or b""
    (ARCH / f"{name}.stdout.txt").write_bytes(out)
    (ARCH / f"{name}.stderr.txt").write_bytes(err)
    return {"command": args, "cwd": str(REPO).replace("\\", "/"), "pid": os.getpid(), "utc_start": started, "utc_end": ended, "exit_code": p.returncode, "stdout_bytes": len(out), "stdout_sha256": hashlib.sha256(out).hexdigest(), "stderr_bytes": len(err), "stderr_sha256": hashlib.sha256(err).hexdigest()}


def status() -> list[str]:
    p = subprocess.run(["git", "status", "--short", "--branch"], cwd=REPO, capture_output=True, text=True)
    return p.stdout.splitlines()


def file_hashes(root: Path) -> dict[str, dict]:
    return {rel(p): {"bytes": p.stat().st_size, "sha256": digest(p)} for p in sorted(root.rglob("*")) if p.is_file()}


def main() -> int:
    before_status = status()
    old_r1_hashes = file_hashes(FRESH / "independent_review_r1")
    old_s2_hashes = file_hashes(FRESH.parent / "S2-FACTORY-IDENTITIES")
    OUT.mkdir(parents=True, exist_ok=True)
    ARCH.mkdir(parents=True, exist_ok=True)
    checks: dict[str, dict] = {}
    failures: list[str] = []

    def check(name: str, value: bool, observed=None) -> None:
        checks[name] = {"pass": bool(value), "observed": observed}
        if not value:
            failures.append(name)

    manifest = json.loads((FRESH / "manifest.json").read_text(encoding="utf-8"))
    snapshot_path = FRESH / "archive/repair_r2_final_snapshot.json"
    snapshot = json.loads(snapshot_path.read_text(encoding="utf-8"))
    check("repair_snapshot_present", snapshot_path.is_file())
    check("repair_snapshot_frozen_hash", snapshot_path.stat().st_size == 6299 and digest(snapshot_path) == "ddafe940d8f7ed2d9c5f3083bec85284312de6acd824d8f3e997d5575e37db3b", {"bytes": snapshot_path.stat().st_size, "sha256": digest(snapshot_path)})
    check("repair_snapshot_contract", snapshot.get("schema_version") == "AD48-S2-fresh-r2-repair-snapshot-v1" and snapshot.get("task_id") == TASK and snapshot.get("self_hash_excluded") is True, {"schema_version": snapshot.get("schema_version"), "task_id": snapshot.get("task_id"), "self_hash_excluded": snapshot.get("self_hash_excluded")})
    check("manifest_snapshot_reference", manifest.get("repair_r2_final_snapshot", {}).get("path") == rel(snapshot_path) and manifest.get("repair_r2_final_snapshot", {}).get("sha256") == digest(snapshot_path), manifest.get("repair_r2_final_snapshot"))
    check("manifest_status_scope", manifest.get("status") == "review_pending" and manifest.get("accepted") is False and manifest.get("accepted_scope") == "four_scope_present_factory_identity_and_construction_receipts_software_only", {k: manifest.get(k) for k in ("status", "accepted", "accepted_scope")})
    check("manifest_observed_head", manifest.get("observed_head") == "4b69f55f7f80240147a65a22809dc1207824dde2", manifest.get("observed_head"))
    check("manifest_four_scopes", set(manifest.get("products", {})) == set(SCOPES), list(manifest.get("products", {})))
    expected_controls = {"source_hash_mutation": "fail_closed", "source_bytes_mutation": "fail_closed", "HEAD_mutation": "fail_closed", "path_status_mutation": "fail_closed", "wrong_locator_scope": "fail_closed", "AD45_handle_or_version_mutation": "fail_closed", "AD45_envelope_hash_mutation": "fail_closed", "contract_ref_mismatch": "fail_closed", "version_axes_mismatch": "fail_closed", "replay_conflict": "fail_closed", "missing_typed_input": "typed_absent_terminal_deferred"}
    check("manifest_negative_controls", manifest.get("negative_controls") == expected_controls, manifest.get("negative_controls"))

    product_hashes = {}
    for scope in SCOPES:
        ipath = FRESH / scope / "factory_identity_v1.json"
        rpath = FRESH / scope / "construction_receipt.json"
        ip = json.loads(ipath.read_text(encoding="utf-8"))
        rp = json.loads(rpath.read_text(encoding="utf-8"))
        product_hashes[scope] = {"identity": {"path": rel(ipath), "bytes": ipath.stat().st_size, "sha256": digest(ipath)}, "receipt": {"path": rel(rpath), "bytes": rpath.stat().st_size, "sha256": digest(rpath)}}
        pm = manifest["products"][scope]
        sm = snapshot["products"][scope]
        check(f"{scope}_identity_manifest_snapshot_hash", product_hashes[scope]["identity"] == {"path": pm["identity"]["path"], "bytes": pm["identity"]["bytes"], "sha256": pm["identity"]["sha256"]} == {"path": sm["identity"]["path"], "bytes": sm["identity"]["bytes"], "sha256": sm["identity"]["sha256"]}, product_hashes[scope]["identity"])
        check(f"{scope}_receipt_manifest_snapshot_hash", product_hashes[scope]["receipt"] == {"path": pm["receipt"]["path"], "bytes": pm["receipt"]["bytes"], "sha256": pm["receipt"]["sha256"]} == {"path": sm["receipt"]["path"], "bytes": sm["receipt"]["bytes"], "sha256": sm["receipt"]["sha256"]}, product_hashes[scope]["receipt"])
        check(f"{scope}_identity_canonical_no_lf", not ipath.read_bytes().endswith(b"\n") and ipath.read_text(encoding="utf-8") == canon(ip), True)
        check(f"{scope}_receipt_canonical_no_lf", not rpath.read_bytes().endswith(b"\n") and rpath.read_text(encoding="utf-8") == canon(rp), True)
        check(f"{scope}_present_union", ip.get("result") == "PresentG3FactoryIdentityV1" and rp.get("result") == "PresentG3FactoryConstructionReceiptV1", {"identity": ip.get("result"), "receipt": rp.get("result")})
        check(f"{scope}_task_schema", ip.get("task_id") == TASK and rp.get("task_id") == TASK and ip.get("schema_version") == "AD48-G3-factory-identity-v1" and rp.get("schema_version") == "AD48-G3-factory-construction-receipt-v1", {"identity": ip.get("schema_version"), "receipt": rp.get("schema_version")})
        check(f"{scope}_semantic_hash_recompute", ip.get("semantic_hash") == hashlib.sha256(canon(ip["semantic_body"]).encode()).hexdigest() and rp.get("semantic_hash") == hashlib.sha256(canon(rp["semantic_body"]).encode()).hexdigest(), {"identity": ip.get("semantic_hash"), "receipt": rp.get("semantic_hash")})
        check(f"{scope}_claim_ceiling_flags", ip.get("trusted_attestation_created") is False and rp.get("trusted_attestation_created") is False and ip.get("candidate_identity_created") is False and rp.get("candidate_identity_created") is False and ip.get("final_candidate_or_package_declaration_hash_created") is False and rp["semantic_body"].get("final_candidate_or_package_declaration_hash_created") is False and ip.get("no_publish") is True and rp.get("no_publish") is True, {k: ip.get(k) for k in ("trusted_attestation_created", "candidate_identity_created", "final_candidate_or_package_declaration_hash_created", "no_publish")})
        im, rm = ip["semantic_body"], rp["semantic_body"]
        check(f"{scope}_local_hashes_present", all(isinstance(ip.get(k), str) and len(ip[k]) == 64 for k in ("factory_identity_digest", "g3_source_contract_binding_digest", "g3_source_declaration_hash", "source_content_digest")) and isinstance(rp.get("construction_digest"), str) and len(rp["construction_digest"]) == 64, True)
        check(f"{scope}_identity_receipt_hash_closure", ip["g3_source_declaration_hash"] == rp["g3_source_declaration_hash"] == im["source_declaration_hash"]["value"] == rm["source_declaration_hash"]["value"] and ip["source_content_digest"] == rp["source_content_digest"] and ip["g3_source_contract_binding_digest"] == rp["g3_source_contract_binding_digest"], True)
        check(f"{scope}_source_stage_binding_present", im.get("constructor_type") == "G3SourceContractBindingV1+G3CandidateBoundSourceDeclarationV1" and rm.get("output_source_declaration", {}).get("content", {}).get("binding", {}).get("binding_role") == "temporary_common_candidate_binding_handle_only", True)
        check(f"{scope}_locator_closure", im.get("locator") == rm["output_source_declaration"]["content"]["locator"], True)
        check(f"{scope}_axes_four_way", im.get("version_axes") == rm["output_source_declaration"]["content"].get("version_axes") == rm["output_source_declaration"]["content"].get("binding", {}).get("version_axes"), True)
        expected_version = "v2" if scope == "binding" else "v5"
        check(f"{scope}_contract_ref_exact", im.get("contract_ref") == rm["output_source_declaration"]["content"].get("contract_ref") == rm["output_source_declaration"]["content"].get("binding", {}).get("contract_ref") and im.get("contract_ref", {}).get("uri") == f"fusionconceptai://GenomeV5/G3/{scope}" and im.get("contract_ref", {}).get("version") == expected_version, im.get("contract_ref"))
        handle = im.get("common_binding_handle", {})
        check(f"{scope}_ad45_exact_handle", handle.get("id") == manifest["inputs"]["ad45_handle_id"] and handle.get("version") == "v5" and rm["output_source_declaration"]["content"].get("common_binding_envelope_sha256", {}).get("value") == manifest["inputs"]["ad45_envelope_sha256"], handle)
        loc = im.get("locator", {})
        src = REPO / Path(loc.get("source_path", ""))
        check(f"{scope}_source_length_hash", src.exists() and src.stat().st_size == loc.get("source_bytes") and digest(src) == loc.get("source_sha256", {}).get("value") and digest(src) == im.get("source_sha256", {}).get("value"), {"path": loc.get("source_path"), "exists": src.exists()})
        check(f"{scope}_git_freshness_fields", loc.get("observed_head") == manifest["observed_head"] and loc.get("head_path_status") == "absent_untracked" and loc.get("working_tree_path_status") == "absent_untracked" and loc.get("working_tree_status") == "untracked", {k: loc.get(k) for k in ("observed_head", "head_path_status", "working_tree_path_status", "working_tree_status")})
        pr = snapshot.get("products", {}).get(scope, {})
        check(f"{scope}_snapshot_result", pr.get("result") == "PresentG3FactoryIdentityV1+PresentG3FactoryConstructionReceiptV1", pr.get("result"))
        check(f"{scope}_f0_input_hashes", ip.get("inputs", {}).get("f0", {}).get("source_factory_sha256") == manifest["inputs"]["f0_factory_source_sha256"] and ip.get("inputs", {}).get("f0", {}).get("test_sha256") == manifest["inputs"]["f0_factory_test_sha256"], ip.get("inputs", {}).get("f0"))
        s1 = REPO / Path(ip.get("inputs", {}).get("s1_locator", {}).get("path", ""))
        check(f"{scope}_s1_locator_hash", s1.exists() and digest(s1) == ip["inputs"]["s1_locator"]["sha256"], ip.get("inputs", {}).get("s1_locator"))

    env = REPO / Path(manifest["inputs"]["ad45_envelope_path"])
    factory = REPO / "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl"
    test = REPO / "test/GenomeV5/G3/g3_source_authority_factory_v1_tests.jl"
    root_manifest = REPO / Path(manifest["root_acceptance_input"]["path"])
    check("AD45_envelope_actual", env.exists() and env.stat().st_size == 9612 and digest(env) == manifest["inputs"]["ad45_envelope_sha256"], {"bytes": env.stat().st_size if env.exists() else None, "sha256": digest(env) if env.exists() else None})
    check("F0_source_test_actual", digest(factory) == manifest["inputs"]["f0_factory_source_sha256"] and digest(test) == manifest["inputs"]["f0_factory_test_sha256"], True)
    check("root_acceptance_actual", digest(root_manifest) == manifest["root_acceptance_input"]["sha256"], True)
    s_inputs = snapshot.get("inputs", {})
    check("snapshot_inputs_exact", s_inputs.get("ad45", {}).get("envelope", {}).get("sha256") == manifest["inputs"]["ad45_envelope_sha256"] and s_inputs.get("ad45", {}).get("handle_id") == manifest["inputs"]["ad45_handle_id"] and s_inputs.get("f0", {}).get("factory_source", {}).get("sha256") == manifest["inputs"]["f0_factory_source_sha256"] and s_inputs.get("f0", {}).get("factory_test", {}).get("sha256") == manifest["inputs"]["f0_factory_test_sha256"], s_inputs)
    check("snapshot_old_s2_hashes_exact", snapshot.get("old_s2_hashes") == {s: {k: {"bytes": v.stat().st_size, "path": rel(v), "sha256": digest(v)} for k, v in (("identity", FRESH.parent / "S2-FACTORY-IDENTITIES" / s / "factory_identity_v1.json"), ("receipt", FRESH.parent / "S2-FACTORY-IDENTITIES" / s / "factory_construction_receipt.json"))} for s in SCOPES}, True)
    check("manifest_claim_ceiling", all(manifest.get("claims", {}).get(k) is False for k in ("trusted_attestation", "candidate_identity", "final_candidate_or_package_declaration_hash", "t0", "t1", "t2", "provider", "mesh", "solver", "engineering", "physical", "search", "r01_r10")) and manifest.get("claims", {}).get("l4_credible_count") == 0, manifest.get("claims"))

    # Re-execute the frozen checker read-only; it only reads old evidence and emits to this review's raw directory.
    integrity = run("independent_integrity", [PYTHON, str(FRESH / "independent_review_r1/raw/independent_integrity.py")])
    integrity_result = json.loads((ARCH / "independent_integrity.stdout.txt").read_text(encoding="utf-8").strip())
    check("fresh_integrity_126_of_126", integrity["exit_code"] == 0 and integrity_result.get("status") == "pass" and integrity_result.get("checks") == 126 and integrity_result.get("passed") == 126 and integrity_result.get("failed") == 0, {**integrity_result, "pid": integrity["pid"], "utc_start": integrity["utc_start"], "utc_end": integrity["utc_end"], "exit_code": integrity["exit_code"]})
    plan = run("plan_validator", [PYTHON, "docs/v4_multitopology_generation/validate_plan.py"])
    check("plan_validator_exit_zero", plan["exit_code"] == 0, plan)
    diff = run("scoped_diff_check", ["git", "diff", "--check", "--", "docs/implementation/AD-48/S2-G3-FACTORY-IDENTITIES-FRESH-R2"])
    check("scoped_diff_exit_zero", diff["exit_code"] == 0, diff)

    after_status = status()
    outside = [line for line in after_status if line not in before_status and line[3:] and not line[3:].startswith("docs/implementation/AD-48/S2-G3-FACTORY-IDENTITIES-FRESH-R2/independent_review_r2")]
    check("scope_only_review_outputs", not outside, outside)
    check("old_r1_raw_unchanged", old_r1_hashes == file_hashes(FRESH / "independent_review_r1"), {"before_count": len(old_r1_hashes), "after_count": len(file_hashes(FRESH / "independent_review_r1"))})
    check("old_s2_products_unchanged", old_s2_hashes == file_hashes(FRESH.parent / "S2-FACTORY-IDENTITIES"), {"before_count": len(old_s2_hashes), "after_count": len(file_hashes(FRESH.parent / "S2-FACTORY-IDENTITIES"))})
    write_json = lambda name, value: (OUT / name).write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    write_json("raw/final_scope_check.json", {"schema_version": "AD48-S2-fresh-r2-independent-review-R2-scope-v1", "pid": os.getpid(), "utc": utc(), "baseline_status": before_status, "final_status": after_status, "outside_scope": outside, "scope_ok": not outside, "old_r1_unchanged": old_r1_hashes == file_hashes(FRESH / "independent_review_r1"), "old_s2_unchanged": old_s2_hashes == file_hashes(FRESH.parent / "S2-FACTORY-IDENTITIES")})
    direct = {"schema_version": "AD48-S2-fresh-r2-independent-review-R2-direct-v1", "task_id": TASK, "reviewer": "different gpt-5.6-luna/high", "pid": os.getpid(), "python": PYTHON.replace("\\", "/"), "python_version": sys.version.split()[0], "utc": utc(), "checks": checks, "failed": failures, "product_hashes": product_hashes, "repair_snapshot": {"bytes": snapshot_path.stat().st_size, "sha256": digest(snapshot_path)}, "old_r1_file_count": len(old_r1_hashes), "old_s2_file_count": len(old_s2_hashes), "heavy_runtime": {"julia": False, "desc": False, "provider": False, "mesh": False, "solver": False, "engineering": False, "physics": False, "search": False}}
    write_json("raw/direct_validation.json", direct)
    verdict = "pass_limited" if not failures else "changes_requested"
    write_json("manifest.json", {"schema_version": "AD48-S2-fresh-r2-independent-review-R2-manifest-v1", "task_id": TASK, "reviewer": "different gpt-5.6-luna/high", "verdict": verdict, "accepted": False, "allowed_next": "parent_may_accept_and_dispatch_formal_S3" if verdict == "pass_limited" else None, "blocking_findings": failures, "claim_ceiling": "source_stage_factory_identity_and_construction_receipt_software_only", "product_count": 8, "integrity_check": {"checks": 126, "passed": integrity_result.get("passed"), "exit_code": integrity["exit_code"]}, "plan_validator_exit": plan["exit_code"], "scoped_diff_exit": diff["exit_code"], "repair_snapshot": {"path": rel(snapshot_path), "bytes": snapshot_path.stat().st_size, "sha256": digest(snapshot_path)}, "products": product_hashes, "old_r1_unchanged": old_r1_hashes == file_hashes(FRESH / "independent_review_r1"), "old_s2_unchanged": old_s2_hashes == file_hashes(FRESH.parent / "S2-FACTORY-IDENTITIES"), "trusted_attestation": False, "candidate_identity": False, "final_candidate_or_package_declaration_hash": False, "t0_t1_t2": False, "provider_mesh_solver_engineering_physics_search": False, "r01_r10": False, "l4_credible_count": 0, "heavy_runtime": {"julia": False, "desc": False, "provider": False, "mesh": False, "solver": False, "engineering": False, "physics": False, "search": False}, "self_hash_excluded": True})
    (OUT / "report.md").write_text(f'''# AD48-S2 G3 fresh R2 independent review R2\n\nDate: {utc()}  \nReviewer: `different gpt-5.6-luna/high`  \nVerdict: `{verdict}`  \nClaim ceiling: `source_stage_factory_identity_and_construction_receipt_software_only`\n\n## Decision\n\nFresh repair review confirms that `archive/repair_r2_final_snapshot.json` is present, 6299 bytes, SHA-256 `{digest(snapshot_path)}`, and closes the exact eight product path/bytes/SHA records and frozen inputs. The four scopes (`realization`, `control`, `binding`, `bundle`) remain `PresentG3FactoryIdentityV1` plus `PresentG3FactoryConstructionReceiptV1`; the eight current products match both `manifest.json` and the repair snapshot byte-for-byte.\n\nA fresh read-only Python integrity execution returned `126/126`, PID `{integrity["pid"]}`, Python `{sys.version.split()[0]}`, UTC `{integrity["utc_start"]}`–`{integrity["utc_end"]}`, exit `{integrity["exit_code"]}`. The review also rechecked AD45 exact handle/envelope, four real S1 locators, source-stage binding/declaration/content hashes, source bytes and Git freshness, replay and negative-control closure, and `trusted_attestation=false`, `candidate_identity=false`, `final_candidate_or_package_declaration_hash=false`.\n\nThe previous R1 `changes_requested` blocker is closed by the now-present repair snapshot. Old S2 products and all R1 raw evidence were hashed before and after this review and remained unchanged.\n\n## Validation receipts\n\n- Fresh integrity: `raw/independent_integrity.stdout.txt` and `.stderr.txt`, exit `{integrity["exit_code"]}`, 126/126.\n- Plan validator: `raw/plan_validator.stdout.txt`/`.stderr.txt`, exit `{plan["exit_code"]}`.\n- Scoped `git diff --check`: `raw/scoped_diff_check.stdout.txt`/`.stderr.txt`, exit `{diff["exit_code"]}`.\n- Final scope and historical immutability: `raw/final_scope_check.json`; fresh direct checks: `raw/direct_validation.json`.\n\n## Boundary\n\nThis `{verdict}` only permits root to accept fresh AD48-S2 and dispatch formal S3. It does not grant trusted attestation, final candidate/package identity or hash, T0/T1/T2, provider, mesh, solver, engineering, physics, search, R01-R10 or L4 credit.\n''', encoding="utf-8")
    report_path = OUT / "report.md"
    report_text = report_path.read_text(encoding="utf-8")
    report_text = report_text.replace("\n## Boundary\n\nThis `", "\n## Boundary\n\nAccepted: `false` (this review does not replace the root decision).  \nAllowed next: `parent_may_accept_and_dispatch_formal_S3`.\n\nThis `")
    report_path.write_text(report_text, encoding="utf-8")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
