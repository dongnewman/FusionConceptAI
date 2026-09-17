import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
BASE = ROOT / "docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY"
SCOPES = ("realization", "control", "binding", "bundle")


def digest(path: Path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(), "ends_lf": data.endswith(b"\n")}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def result_row(name, passed, detail=None):
    row = {"name": name, "passed": bool(passed)}
    if detail is not None:
        row["detail"] = detail
    return row


def main():
    manifest = load(BASE / "manifest.json")
    rows = []
    s2_root_acceptance = load(ROOT / manifest["inputs"]["s2_root_acceptance"]["path"])
    rows.append(result_row("fresh_s2_root_acceptance_limited", s2_root_acceptance.get("decision") == "accepted_limited" and s2_root_acceptance.get("only_unlocked") == "formal S3"))
    rows.append(result_row("fresh_s2_root_claim_ceiling", all(v is False or v == 0 for k, v in s2_root_acceptance.get("claims", {}).items())))
    rows.append(result_row("fresh_s2_root_product_mutation_false", s2_root_acceptance.get("product_mutation") is False and s2_root_acceptance.get("source_registry_mutation") is False))
    product_paths = []
    for scope in SCOPES:
        for kind in ("identity", "receipt"):
            rec = manifest["products"][scope][kind]
            path = ROOT / rec["path"]
            product_paths.append(path.relative_to(ROOT).as_posix())
            actual = digest(path)
            obj = load(path)
            rows.append(result_row(f"{scope}.{kind}.exists", path.is_file()))
            rows.append(result_row(f"{scope}.{kind}.bytes", actual["bytes"] == rec["bytes"], {"actual": actual["bytes"], "declared": rec["bytes"]}))
            rows.append(result_row(f"{scope}.{kind}.sha256", actual["sha256"] == rec["sha256"], {"actual": actual["sha256"], "declared": rec["sha256"]}))
            rows.append(result_row(f"{scope}.{kind}.result", obj.get("result") == rec["result"], {"actual": obj.get("result"), "declared": rec["result"]}))
            rows.append(result_row(f"{scope}.{kind}.typed_absent", obj.get("status") == "typed_absent"))
            rows.append(result_row(f"{scope}.{kind}.terminal_deferred", obj.get("terminal_deferred") is True))
            rows.append(result_row(f"{scope}.{kind}.no_publish", obj.get("no_publish") is True))
            rows.append(result_row(f"{scope}.{kind}.trusted_attestation_false", obj.get("trusted_attestation_created") is False))
            rows.append(result_row(f"{scope}.{kind}.candidate_false", obj.get("candidate_identity_created") is False))
            rows.append(result_row(f"{scope}.{kind}.declaration_false", obj.get("declaration_hash_created") is False))
            rows.append(result_row(f"{scope}.{kind}.reason", obj.get("reason") == "missing_independent_attestor_key_or_certificate_signature_verifier_trust_root_revocation_and_freshness_policy"))

        identity = load(BASE / scope / "trusted_source_identity_v1.json")
        receipt = load(BASE / scope / "trusted_source_identity_receipt.json")
        s1 = identity["inputs"]["s1"]
        s2 = identity["inputs"]["s2"]
        ad45 = identity["inputs"]["ad45"]
        f0 = identity["inputs"]["f0"]
        for label, rec in (
            ("s1.locator", {"path": s1["locator_path"], "sha256": s1["locator_sha256"]}),
            ("s1.receipt", {"path": s1["receipt_path"], "sha256": s1["receipt_sha256"]}),
            ("s2.identity", {"path": s2["identity_path"], "sha256": s2["identity_sha256"]}),
            ("s2.receipt", {"path": s2["receipt_path"], "sha256": s2["receipt_sha256"]}),
            ("s2.root_acceptance", {"path": s2["root_acceptance_manifest_path"], "sha256": s2["root_acceptance_manifest_sha256"]}),
            ("f0.root_acceptance", {"path": f0["root_acceptance_manifest_path"], "sha256": f0["root_acceptance_manifest_sha256"]}),
        ):
            p = ROOT / rec["path"]
            d = digest(p)
            rows.append(result_row(f"{scope}.{label}.hash", d["sha256"] == rec["sha256"], {"path": rec["path"], "actual": d["sha256"], "declared": rec["sha256"]}))
        ad45_path = ROOT / ad45["envelope_path"]
        rows.append(result_row(f"{scope}.ad45.envelope_hash", digest(ad45_path)["sha256"] == ad45["envelope_sha256"]))
        # Receipt input projection must agree with the identity input closure.
        projected = {
            "ad45_envelope_sha256": ad45["envelope_sha256"],
            "ad45_handle_id": ad45["handle_id"],
            "ad45_handle_version": ad45["handle_version"],
            "f0_root_acceptance_manifest_sha256": f0["root_acceptance_manifest_sha256"],
            "s1_locator_sha256": s1["locator_sha256"],
            "s1_receipt_sha256": s1["receipt_sha256"],
            "s2_identity_sha256": s2["identity_sha256"],
            "s2_receipt_sha256": s2["receipt_sha256"],
            "s2_root_acceptance_manifest_sha256": s2["root_acceptance_manifest_sha256"],
        }
        rows.append(result_row(f"{scope}.receipt_input_projection", receipt["inputs"] == projected))

    root_products = s2_root_acceptance.get("products", [])
    root_product_map = {(p.get("scope"), "identity" if p.get("kind") == "identity" else "receipt"): p for p in root_products}
    for scope in SCOPES:
        for kind in ("identity", "receipt"):
            # Resolve the exact accepted S2 product declared by the S3 identity input.
            s3_identity = load(BASE / scope / "trusted_source_identity_v1.json")
            inp = s3_identity["inputs"]["s2"]
            target_path = inp["identity_path"] if kind == "identity" else inp["receipt_path"]
            target_sha = inp["identity_sha256"] if kind == "identity" else inp["receipt_sha256"]
            rp = root_product_map.get((scope, "identity" if kind == "identity" else "receipt"))
            rows.append(result_row(f"{scope}.accepted_s2_{kind}_exact", rp is not None and rp.get("path") == target_path and rp.get("sha256") == target_sha and rp.get("result") == ("PresentG3FactoryIdentityV1" if kind == "identity" else "PresentG3FactoryConstructionReceiptV1")))

    expected = sorted(product_paths + [
        "docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/manifest.json",
        "docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/cleanup_inventory.md",
        "docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/archive/direct_validation.json",
        "docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/archive/replay_validation.json",
        "docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/archive/plan_validator_stdout.json",
        "docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/archive/plan_validator_stderr.txt",
        "docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/archive/scoped_diff.stdout.txt",
        "docs/implementation/AD-48/S3-TRUSTED-SOURCE-IDENTITY/archive/scoped_diff.stderr.txt",
    ])
    actual_files = sorted(p.relative_to(ROOT).as_posix() for p in BASE.rglob("*") if p.is_file() and "independent_review_r1" not in p.parts)
    rows.append(result_row("formal_eight_product_paths", len(product_paths) == 8 and len(set(product_paths)) == 8))
    rows.append(result_row("pre_review_owned_file_inventory_exact", actual_files == expected, {"unexpected": sorted(set(actual_files) - set(expected)), "missing": sorted(set(expected) - set(actual_files))}))

    direct = load(BASE / "archive/direct_validation.json")
    replay = load(BASE / "archive/replay_validation.json")
    rows.append(result_row("direct_65_of_65", direct.get("checks", {}).get("passed") == 65 and direct.get("checks", {}).get("total") == 65 and not direct.get("checks", {}).get("failed")))
    rows.append(result_row("replay_8_of_8", replay.get("checks", {}).get("passed") == 8 and replay.get("checks", {}).get("total") == 8 and all(all(row.get(k) is True for k in ("result", "bytes", "sha256", "terminal_deferred", "no_publish")) for row in replay.get("checks", {}).get("rows", []))))
    rows.append(result_row("heavy_execution_absent", direct.get("julia_desc_provider_mesh_solver_physics_run") is False and replay.get("julia_desc_provider_mesh_solver_physics_run") is False))
    rows.append(result_row("secret_contents_not_read", direct.get("key_or_credential_contents_read") is False and replay.get("key_or_credential_contents_read") is False))
    product_observations = {}
    for scope in SCOPES:
        product_observations[scope] = {}
        for kind, filename in (("identity", "trusted_source_identity_v1.json"), ("receipt", "trusted_source_identity_receipt.json")):
            p = BASE / scope / filename
            obj = load(p)
            d = digest(p)
            product_observations[scope][kind] = {
                "path": p.relative_to(ROOT).as_posix(),
                "bytes": d["bytes"],
                "sha256": d["sha256"],
                "result": obj.get("result"),
                "status": obj.get("status"),
                "terminal_deferred": obj.get("terminal_deferred"),
                "no_publish": obj.get("no_publish"),
                "trusted_attestation_created": obj.get("trusted_attestation_created"),
                "candidate_identity_created": obj.get("candidate_identity_created"),
                "declaration_hash_created": obj.get("declaration_hash_created"),
            }
    result = {
        "record_kind": "AD48S3IndependentReviewR1DirectValidation",
        "task_id": manifest["task_id"],
        "python": sys.version,
        "python_executable": sys.executable,
        "observed_head": manifest["observed_head"],
        "checks": {"passed": sum(1 for r in rows if r["passed"]), "total": len(rows), "failed": [r for r in rows if not r["passed"]]},
        "product_observations": product_observations,
        "product_paths": product_paths,
        "security_scan": {"contents_of_keys_or_credentials_read": False},
    }
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
