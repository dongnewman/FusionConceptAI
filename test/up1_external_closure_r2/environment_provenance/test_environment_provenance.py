"""Fresh-process tests for UP1 R2 environment/provenance closure."""
from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import sys
import base64
from pathlib import Path
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

HERE = Path(__file__).resolve()
REPO = HERE.parents[3]
PKG = REPO / "tools" / "up1_external_closure_r2" / "environment_provenance"
sys.path.insert(0, str(REPO))
from tools.up1_external_closure_r2.environment_provenance.validator import (  # noqa: E402
    canonical_bytes,
    canonical_sha256,
    load_json,
    validate_document as _validate_document,
)

H = "a" * 64
TEST_PRIVATE = Ed25519PrivateKey.from_private_bytes(bytes(range(32)))
TEST_PUBLIC_B64 = base64.b64encode(TEST_PRIVATE.public_key().public_bytes_raw()).decode("ascii")
EXTERNAL_CONTEXTS = {}


def sign_payload(payload):
    return base64.b64encode(TEST_PRIVATE.sign(canonical_bytes(payload))).decode("ascii")


def authenticated_closure_for(value):
    authority = value["authority_proof"]
    return {
        "authority": {"authority": authority["authority"], "verified_at_utc": authority["verified_at_utc"]},
        "download_receipts": {item["name"]: {"origin": item["download_receipt"]["origin"], "retrieved_utc": item["download_receipt"]["retrieved_utc"]} for item in value["binaries"]},
        "binary_licenses": {item["name"]: item["license"] for item in value["binaries"]},
        "sbom_components": {item["bom_ref"]: {"supplier": item["supplier"], "license": item["license"]} for item in value["sbom"]["components"]},
    }


def external_context_for(value):
    cached = EXTERNAL_CONTEXTS.get(id(value))
    if cached is not None:
        return copy.deepcopy(cached)
    declaration = value["reproducible_declaration"]
    return {
        "candidate_ref": value["candidate_ref"],
        "source_revision": declaration["source_revision"],
        "frozen_root": H,
        "profile": "up1-r2-test",
        "lock_identities": [{"name": x["name"], "version": x["kind"], "path": x["path"], "sha256": x["sha256"]} for x in value["package_locks"]],
        "binary_identities": [{"name": x["name"], "version": x["version"], "path": x["path"], "sha256": x["sha256"]} for x in value["binaries"]],
        "authenticated_closure": copy.deepcopy(value["reproducible_declaration"]["authenticated_closure"]),
    }


def external_anchor():
    return {"public_key_b64": TEST_PUBLIC_B64, "key_id": "key", "issuer": "publisher", "trust_root": "root", "policy": "environment_provenance_only"}


def validate_document(value, **kwargs):
    signed = isinstance(value, dict) and (value.get("fixture_role") == "TEST_ONLY" or value.get("authority_proof", {}).get("status") == "signed_verified")
    if signed and "expected_context" not in kwargs:
        context = external_context_for(value)
        kwargs.update({"expected_context": context, "expected_context_sha256": canonical_sha256(context)})
    if signed and "trust_anchor" not in kwargs:
        anchor = external_anchor()
        kwargs.update({"trust_anchor": anchor, "trust_anchor_sha256": canonical_sha256(anchor)})
    return _validate_document(value, **kwargs)


def document(*, role="PRODUCTION", signed=False):
    candidate = "candidate://fixture-r2"
    declaration = {
        "schema": "UP1.reproducible-environment-declaration.v1",
        "candidate_ref": candidate,
        "source_revision": "git:fixture-r2",
        "lock_hashes": {"Project.toml": H, "Manifest.toml": H},
        "runtime_hashes": {"Julia": H, "Python": H},
        "binary_hashes": {"julia": H, "python": H},
        "recipe_hashes": {"julia": H, "python": H},
        "sbom_document_sha256": [H],
        "evidence_class": "reproducible_declaration",
    }
    declaration["declaration_sha256"] = canonical_sha256(declaration)
    authority = {
        "status": "signed_verified" if signed else "typed_absent",
        "signed_receipt": {"receipt_id": "receipt-r2", "payload_sha256": declaration["declaration_sha256"], "signature": "sig", "algorithm": "ed25519", "key_id": "key", "issuer": "publisher", "trust_root": "root", "verification_method": "offline-chain"},
        "authority": "publisher://fixture",
        "signature": {"algorithm": "ed25519", "key_id": "key", "signature": "sig", "issuer": "publisher", "verified": True, "trust_root": "root"},
        "verified_at_utc": "2026-09-17T00:00:00Z",
        "evidence_class": "authority_proof",
    }
    if not signed:
        authority.update({"absence_code": "SIGNED_PROVENANCE_NOT_SUPPLIED", "owner": "publisher", "authoritative_source": "signed provenance ledger", "recovery_condition": "supply signed receipt"})
    binary = lambda name: {"name": name, "version": "1.10.5" if name == "julia" else "3.11.9", "path": f"fixture/{name}.bin", "sha256": H, "publisher": "Fixture Publisher", "signature": {"algorithm": "ed25519", "key_id": "key", "signature": "sig", "issuer": "publisher", "verified": True, "trust_root": "root", "profile": "up1-r2-test", "subject_sha256": H, "subject_name": name, "subject_version": "1.10.5" if name == "julia" else "3.11.9", "subject_path": f"fixture/{name}.bin"}, "download_receipt": {"origin": f"https://example.invalid/{name}", "receipt_id": f"download-{name}", "receipt_sha256": H, "retrieved_utc": "2026-09-17T00:00:00Z", "signed": True, "subject_sha256": H, "subject_name": name, "subject_version": "1.10.5" if name == "julia" else "3.11.9", "subject_path": f"fixture/{name}.bin", "subject_binary_sha256": H}, "build_recipe": {"kind": "container", "uri": "oci://fixture/image", "sha256": H, "digest": "sha256:" + H, "subject_sha256": H, "subject_name": name, "subject_version": "1.10.5" if name == "julia" else "3.11.9", "subject_path": f"fixture/{name}.bin", "subject_binary_sha256": H}, "sbom_refs": [f"pkg:{name}"], "license": "MIT", "evidence_class": "authority_proof"}
    value = {
        "schema": "UP1.environment-provenance-closure.r2", "fixture_role": role, "candidate_ref": candidate,
        "status": "present", "claim_ceiling": "environment_provenance_only",
        "local_observation": {"os": {"name": "Windows", "version": "fixture", "architecture": "AMD64"}, "architecture": "AMD64", "runtime_paths": [], "observed_utc": "2026-09-17T00:00:00Z", "evidence_class": "local_observation"},
        "reproducible_declaration": declaration, "authority_proof": authority,
        "package_locks": [{"name": "Project.toml", "path": "fixture/Project.toml", "sha256": H, "kind": "julia_project", "evidence_class": "reproducible_declaration"}, {"name": "Manifest.toml", "path": "fixture/Manifest.toml", "sha256": H, "kind": "julia_manifest", "evidence_class": "reproducible_declaration"}],
        "runtimes": [{"name": "Julia", "version": "1.10.5", "path": "fixture/julia.exe", "sha256": H, "role": "runtime", "evidence_class": "local_observation"}, {"name": "Python", "version": "3.11.9", "path": "fixture/python.exe", "sha256": H, "role": "runtime", "evidence_class": "local_observation"}],
        "binaries": [binary("julia"), binary("python")],
        "sbom": {"format": "CycloneDX", "spec_version": "1.5", "document_sha256": H, "components": [{"bom_ref": "pkg:julia", "name": "julia", "version": "1.10.5", "purl": "pkg:generic/julia@1.10.5", "sha256": H, "supplier": "Fixture Publisher", "license": "MIT"}, {"bom_ref": "pkg:python", "name": "python", "version": "3.11.9", "purl": "pkg:generic/python@3.11.9", "sha256": H, "supplier": "Fixture Publisher", "license": "PSF-2.0"}], "dependency_edges": [{"ref": "pkg:julia", "depends_on": []}, {"ref": "pkg:python", "depends_on": []}], "evidence_class": "authority_proof"},
    }
    declaration["authenticated_closure"] = authenticated_closure_for(value)
    declaration.pop("declaration_sha256", None)
    declaration["declaration_sha256"] = canonical_sha256(declaration)
    for item in value["binaries"]:
        subject = {"name": item["name"], "version": item["version"], "path": item["path"], "sha256": item["sha256"], "publisher": item["publisher"]}
        sdigest = canonical_sha256(subject)
        sign_body = {"name": item["name"], "version": item["version"], "path": item["path"], "sha256": sdigest}
        signature_b64 = sign_payload(sign_body)
        item["signature"].update({"subject_sha256": sdigest, "public_key_b64": TEST_PUBLIC_B64, "signature_b64": signature_b64, "signature": signature_b64})
        item["signature"].update({"subject_name": item["name"], "subject_version": item["version"], "subject_path": item["path"]})
        receipt = item["download_receipt"]
        receipt.update({"subject_sha256": sdigest, "subject_binary_sha256": item["sha256"], "subject_path": item["path"], "subject_version": item["version"], "subject_name": item["name"]})
        receipt["receipt_sha256"] = canonical_sha256({k: v for k, v in receipt.items() if k != "receipt_sha256"})
        recipe = item["build_recipe"]
        recipe.update({"subject_sha256": sdigest, "subject_binary_sha256": item["sha256"], "subject_path": item["path"], "subject_version": item["version"], "subject_name": item["name"]})
        recipe["sha256"] = canonical_sha256({k: v for k, v in recipe.items() if k not in {"sha256", "digest"}})
        recipe["digest"] = "sha256:" + recipe["sha256"]
    declaration["recipe_hashes"] = {item["name"]: item["build_recipe"]["sha256"] for item in value["binaries"]}
    declaration.pop("declaration_sha256", None)
    declaration["declaration_sha256"] = canonical_sha256(declaration)
    value["authority_proof"]["signed_receipt"]["payload_sha256"] = declaration["declaration_sha256"]
    # A signed fixture is materialized against real repository files by the
    # positive test; TEST_ONLY/typed-absence fixtures intentionally remain
    # synthetic and are never promoted.
    if signed:
        runtime_path = "tools/up1_external_closure_r2/environment_provenance/validator.py"
        lock_project = "Project.toml"
        lock_manifest = "Manifest.toml"
        for item in value["runtimes"]:
            item["path"] = runtime_path
            item["sha256"] = hashlib.sha256((REPO / runtime_path).read_bytes()).hexdigest()
        value["local_observation"]["runtime_paths"] = [{"name": item["name"], "version": item["version"], "path": item["path"], "sha256": item["sha256"], "type": "executable", "evidence_class": "local_observation"} for item in value["runtimes"]]
        for item, path in zip(value["package_locks"], (lock_project, lock_manifest)):
            item["path"] = path
            item["sha256"] = hashlib.sha256((REPO / path).read_bytes()).hexdigest()
        for item in value["binaries"]:
            item["path"] = runtime_path
            item["sha256"] = hashlib.sha256((REPO / runtime_path).read_bytes()).hexdigest()
            subject = {"name": item["name"], "version": item["version"], "path": item["path"], "sha256": item["sha256"], "publisher": item["publisher"]}
            sdigest = canonical_sha256(subject)
            signature_b64 = sign_payload({"name": item["name"], "version": item["version"], "path": item["path"], "sha256": sdigest})
            item["signature"].update({"subject_sha256": sdigest, "subject_path": item["path"], "subject_version": item["version"], "public_key_b64": TEST_PUBLIC_B64, "signature_b64": signature_b64, "signature": signature_b64})
            receipt = item["download_receipt"]
            receipt.update({"subject_sha256": sdigest, "subject_binary_sha256": item["sha256"], "subject_path": item["path"], "subject_version": item["version"]})
            receipt["receipt_sha256"] = canonical_sha256({k: v for k, v in receipt.items() if k != "receipt_sha256"})
            recipe = item["build_recipe"]
            recipe.update({"subject_sha256": sdigest, "subject_binary_sha256": item["sha256"], "subject_path": item["path"], "subject_version": item["version"]})
            recipe["sha256"] = canonical_sha256({k: v for k, v in recipe.items() if k not in {"sha256", "digest"}})
            recipe["digest"] = "sha256:" + recipe["sha256"]
            for comp in value["sbom"]["components"]:
                if comp["bom_ref"] == "pkg:" + item["name"]:
                    comp.update({"version": item["version"], "sha256": item["sha256"]})
        context = {"candidate_ref": candidate, "source_revision": "git:fixture-r2", "frozen_root": H, "profile": "up1-r2-test", "lock_identities": [{"name": x["name"], "version": x["kind"], "path": x["path"], "sha256": x["sha256"]} for x in value["package_locks"]], "binary_identities": [{"name": x["name"], "version": x["version"], "path": x["path"], "sha256": x["sha256"]} for x in value["binaries"]], "authenticated_closure": authenticated_closure_for(value)}
        context_hash = canonical_sha256(context)
        value["sbom"]["document_sha256"] = H
        declaration = value["reproducible_declaration"]
        declaration["lock_hashes"] = {item["name"]: item["sha256"] for item in value["package_locks"]}
        declaration["runtime_hashes"] = {item["name"]: item["sha256"] for item in value["runtimes"]}
        declaration["binary_hashes"] = {item["name"]: item["sha256"] for item in value["binaries"]}
        declaration["recipe_hashes"] = {item["name"]: item["build_recipe"]["sha256"] for item in value["binaries"]}
        declaration["sbom_document_sha256"] = [value["sbom"]["document_sha256"]]
        declaration["authenticated_closure"] = authenticated_closure_for(value)
        declaration.pop("declaration_sha256", None)
        declaration["declaration_sha256"] = canonical_sha256(declaration)
        receipt = value["authority_proof"]["signed_receipt"]
        receipt.update({"profile": "up1-r2-test", "expected_context_sha256": context_hash, "public_key_b64": TEST_PUBLIC_B64, "payload": {"candidate_ref": candidate, "declaration_sha256": declaration["declaration_sha256"], "expected_context_sha256": context_hash, "profile": "up1-r2-test", "authenticated_closure": declaration["authenticated_closure"], "authenticated_closure_sha256": canonical_sha256(declaration["authenticated_closure"])}})
        receipt["payload_sha256"] = canonical_sha256(receipt["payload"])
        receipt["signature_b64"] = sign_payload(receipt["payload"])
        receipt["signature"] = receipt["signature_b64"]
        value["authority_proof"]["outer_envelope"] = {"payload_sha256": canonical_sha256(receipt), "algorithm": "ed25519", "key_id": "key", "issuer": "publisher", "trust_root": "root", "profile": "up1-r2-test", "public_key_b64": TEST_PUBLIC_B64, "signature_b64": sign_payload(receipt)}
        EXTERNAL_CONTEXTS[id(value)] = context
        value["status"] = "non_evidence" if role == "TEST_ONLY" else "present"
        return value
    value["local_observation"]["runtime_paths"] = [{"name": item["name"], "version": item["version"], "path": item["path"], "sha256": item["sha256"], "type": "executable", "evidence_class": "local_observation"} for item in value["runtimes"]]
    value["status"] = "typed_absent" if role != "TEST_ONLY" else "non_evidence"
    return value


def test_missing_signed_provenance_is_typed_absence():
    result = validate_document(document())
    assert result.status == "typed_absent"
    assert result.decision == "typed_absence"


def test_test_only_is_non_evidence_even_when_signed():
    result = validate_document(document(role="TEST_ONLY", signed=True), root=REPO)
    assert result.status == "non_evidence"
    assert result.decision == "non_evidence"


def test_signed_complete_closure_is_present():
    result = validate_document(document(signed=True), root=REPO)
    assert result.status == "present"
    assert result.decision == "admissible"


def test_invalid_declaration_fails_closed():
    value = document(signed=True)
    value["reproducible_declaration"]["source_revision"] = ""
    assert validate_document(value, root=REPO).status == "fail_closed"


def test_hash_drift_fails_closed(tmp_path):
    value = document(signed=True)
    runtime = tmp_path / "julia.exe"
    runtime.write_bytes(b"different")
    value["runtimes"][0]["path"] = str(runtime)
    value["package_locks"][0]["path"] = "missing-project.toml"
    value["package_locks"][1]["path"] = "missing-manifest.toml"
    value["binaries"][0]["path"] = "missing-binary"
    assert validate_document(value, root=tmp_path).status == "fail_closed"


def test_path_substitution_and_absolute_escape_fail_closed():
    value = document(signed=True)
    value["binaries"][0]["path"] = str((REPO / "Project.toml").resolve())
    assert validate_document(value, root=REPO).status == "fail_closed"
    value = document(signed=True)
    value["binaries"][0]["path"] = "missing/substituted.exe"
    assert validate_document(value, root=REPO).status == "fail_closed"


def test_version_duplicate_identity_and_sbom_graph_attacks_fail_closed():
    value = document(signed=True)
    value["runtimes"][0]["version"] = "9.9.9"
    assert validate_document(value, root=REPO).status == "fail_closed"
    value = document(signed=True)
    value["package_locks"].append(copy.deepcopy(value["package_locks"][0]))
    assert validate_document(value, root=REPO).status == "fail_closed"
    value = document(signed=True)
    value["sbom"]["components"].append({"bom_ref": "pkg:orphan", "name": "orphan", "version": "1", "purl": "pkg:generic/orphan@1", "sha256": H, "supplier": "x", "license": "MIT"})
    value["sbom"]["dependency_edges"].append({"ref": "pkg:orphan", "depends_on": []})
    assert validate_document(value, root=REPO).status == "fail_closed"
    value = document(signed=True)
    value["sbom"]["dependency_edges"] = [{"ref": "pkg:julia", "depends_on": ["pkg:python"]}, {"ref": "pkg:python", "depends_on": ["pkg:julia"]}]
    assert validate_document(value, root=REPO).status == "fail_closed"


def test_nested_provenance_linkage_and_root_claim_attacks_fail_closed():
    value = document(signed=True)
    value["binaries"][0]["publisher"] = "Other Publisher"
    assert validate_document(value, root=REPO).status == "fail_closed"


    value = document(signed=True)
    value["binaries"][0]["download_receipt"]["receipt_sha256"] = H
    assert validate_document(value, root=REPO).status == "fail_closed"
    value = document(signed=True)
    value["status"] = "fail_closed"
    assert validate_document(value, root=REPO).status == "fail_closed"
    value = document(signed=True)
    value["claim_ceiling"] = "candidate_authority"
    assert validate_document(value, root=REPO).status == "fail_closed"

    for mutate in (
        lambda v: v["binaries"][0]["download_receipt"].update({"origin": "https://attacker.invalid"}),
        lambda v: v["binaries"][0]["download_receipt"].update({"retrieved_utc": "2027-01-01T00:00:00Z"}),
        lambda v: v["authority_proof"].update({"authority": "publisher://attacker"}),
        lambda v: v["authority_proof"].update({"verified_at_utc": "2027-01-01T00:00:00Z"}),
        lambda v: v["binaries"][0].update({"license": "GPL-3.0-only"}),
        lambda v: v["sbom"]["components"][0].update({"supplier": "Attacker"}),
        lambda v: v["sbom"]["components"][0].update({"license": "GPL-3.0-only"}),
    ):
        value = document(signed=True)
        mutate(value)
        assert validate_document(value, root=REPO).status == "fail_closed"


def test_signed_chain_forgery_and_missing_anchor_boundaries():
    value = document(signed=True)
    envelope = value["authority_proof"]["outer_envelope"]
    envelope["signature_b64"] = envelope["signature_b64"][:-2] + ("AA" if envelope["signature_b64"][-2:] != "AA" else "BB")
    assert validate_document(value, root=REPO).status == "fail_closed"

    value = document(signed=True)
    value["binaries"][0]["signature"]["signature"] = "opaque"
    assert validate_document(value, root=REPO).status == "fail_closed"

    value = document(signed=True)
    value["authority_proof"]["signed_receipt"]["signature"] = "opaque"
    assert validate_document(value, root=REPO).status == "fail_closed"

    value = document(signed=True)
    value["status"] = "typed_absent"
    result = _validate_document(value, root=REPO)
    assert result.status == "typed_absent"
    assert result.decision == "typed_absence"

    value = document(signed=True)
    value["binaries"][0]["signature"].pop("signature_b64")
    value["status"] = "typed_absent"
    result = validate_document(value, root=REPO)
    assert result.status == "typed_absent"


def test_closed_sbom_and_runtime_path_identity_attacks_fail_closed():
    value = document(signed=True)
    value["sbom"]["components"][0]["purl"] = "pkg:generic/python@1.10.5"
    assert validate_document(value, root=REPO).status == "fail_closed"

    value = document(signed=True)
    value["binaries"][0]["sbom_refs"].append("pkg:julia")
    assert validate_document(value, root=REPO).status == "fail_closed"

    value = document(signed=True)
    value["local_observation"]["runtime_paths"][0]["type"] = "library"
    assert validate_document(value, root=REPO).status == "fail_closed"


def test_expected_context_identity_is_independent_anchor():
    value = document(signed=True)
    context = external_context_for(value)
    context["binary_identities"][0]["version"] = "9.9.9"
    assert validate_document(value, root=REPO, expected_context=context, expected_context_sha256=canonical_sha256(context)).status == "fail_closed"


def test_checked_test_only_fixture_is_non_evidence():
    fixture = PKG / "fixtures" / "test_only_positive.json"
    value = load_json(fixture)
    context = external_context_for(value)
    anchor = external_anchor()
    result = _validate_document(value, expected_context=context, expected_context_sha256=canonical_sha256(context), trust_anchor=anchor, trust_anchor_sha256=canonical_sha256(anchor))
    assert result.status == "non_evidence"


def test_external_anchor_rejects_bundle_key_substitution():
    value = document(signed=True)
    value["authority_proof"]["signed_receipt"]["public_key_b64"] = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    assert validate_document(value, root=REPO).status == "fail_closed"


def test_cli_requires_and_consumes_independent_context_and_anchor(tmp_path):
    value = document(signed=True)
    context = external_context_for(value)
    anchor = external_anchor()
    closure_path = tmp_path / "closure.json"
    context_path = tmp_path / "expected-context.json"
    anchor_path = tmp_path / "trust-anchor.json"
    closure_path.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")
    context_path.write_text(json.dumps(context, ensure_ascii=False), encoding="utf-8")
    anchor_path.write_text(json.dumps(anchor, ensure_ascii=False), encoding="utf-8")
    proc = subprocess.run([
        sys.executable, "-B", str(PKG / "cli.py"), str(closure_path), "--root", str(REPO),
        "--expected-context", str(context_path), "--expected-context-sha256", canonical_sha256(context),
        "--trust-anchor", str(anchor_path), "--trust-anchor-sha256", canonical_sha256(anchor),
    ], cwd=REPO, text=True, capture_output=True, check=False)
    payload = json.loads(proc.stdout)
    assert proc.returncode == 0
    assert payload["status"] == "present"


def test_evidence_manifest_exact_owned_set():
    manifest = load_json(REPO / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/06-environment-provenance/manifest.json")
    expected = {str(path).replace("/", "\\") for path in manifest["exact_files"]}
    actual = set()
    for base in (REPO / "tools/up1_external_closure_r2/environment_provenance", REPO / "test/up1_external_closure_r2/environment_provenance", REPO / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/06-environment-provenance"):
        for path in base.rglob("*"):
            if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".pyc":
                actual.add(str(path.relative_to(REPO)))
    assert manifest["exact_file_count"] == 20
    assert actual == expected


def test_cli_is_fresh_python_process(tmp_path):
    path = tmp_path / "closure.json"
    path.write_text(json.dumps(document(), ensure_ascii=False), encoding="utf-8")
    cli = PKG / "cli.py"
    proc = subprocess.run([sys.executable, "-B", str(cli), str(path)], cwd=REPO, text=True, capture_output=True, check=False)
    payload = json.loads(proc.stdout)
    assert proc.returncode == 0
    assert payload["status"] == "typed_absent"
    assert payload["pid"] > 0 and payload["utc"].endswith("Z")
    assert payload["input_sha256"] == hashlib.sha256(path.read_bytes()).hexdigest()
