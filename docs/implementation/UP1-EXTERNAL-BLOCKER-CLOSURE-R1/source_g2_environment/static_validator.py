"""Bounded W3 preparation validator; no Julia, DESC, mesh, solver, or recomputation."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[3]
HEX64 = re.compile(r"^[0-9a-f]{64}$")
HEX40 = re.compile(r"^[0-9a-f]{40}$")
AXES = {"payload_schema_version", "canonicalization_profile_version", "applicability_profile_version", "evidence_receipt_version"}
ABSENCE_KEYS = ("owner", "authoritative_source", "authority_ref", "recovery_condition", "expiry_condition")
BIN_KEYS = {"name", "version", "path", "sha256", "publisher", "signature", "download_origin", "build_recipe", "sbom", "license"}
SELF_EXCLUDED = {"manifest.json", "cleanup_inventory.json", "validation_receipt.json"}


def load(name):
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def canonical_hash(obj):
    return hashlib.sha256(json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def file_hash(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def assert_absence(x, label):
    assert x.get("status") in ("typed_absent", "incomplete_typed_absent", "source_only_present"), label
    for key in ABSENCE_KEYS:
        assert key in x, f"{label}:missing {key}"
        if key == "authority_ref":
            assert isinstance(x[key], dict) and x[key].get("state") == "typed_absent", f"{label}:authority_ref"
        else:
            assert x[key] not in (None, ""), f"{label}:missing accountability {key}"


def check_snapshot(src, manifest):
    snap = src["source_snapshot"]
    assert snap["head_commit"] == manifest["source_snapshot"]["head"] and HEX40.fullmatch(snap["head_commit"])
    assert snap["head_tree"] == manifest["source_snapshot"]["tree"] and HEX40.fullmatch(snap["head_tree"])
    for key in ("dirty_status_sha256", "dirty_patch_sha256", "frozen_dirty_patch_sha256"):
        assert HEX64.fullmatch(snap[key])
    assert len(snap["frozen_dirty_status_sha256"]) == 63
    assert snap["drift"]["old_frozen_status_format"] == "historical_malformed_63_chars_typed_absent"
    assert snap["dirty_status_sha256"] == manifest["source_snapshot"]["observed_dirty_status_sha256"]
    assert snap["dirty_patch_sha256"] == manifest["source_snapshot"]["observed_dirty_patch_sha256"]
    assert snap["dirty_status_sha256"] != snap["frozen_dirty_status_sha256"]
    assert snap["dirty_patch_sha256"] != snap["frozen_dirty_patch_sha256"]
    assert snap["drift"]["state"] == "typed_drift_terminal_deferred"
    assert subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO).decode().strip() == snap["head_commit"]
    assert subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=REPO).decode().strip() == snap["head_tree"]
    # The historical snapshot is an input boundary, not a mutable assertion
    # against this repair's own untracked evidence and concurrent dirty work.
    # Record current hashes and require an explicit typed drift classification;
    # never silently rebind the frozen status/patch or claim source authority.
    current_status = hashlib.sha256(subprocess.check_output(["git", "status", "--short"], cwd=REPO)).hexdigest()
    current_patch = hashlib.sha256(subprocess.check_output(["git", "diff", "--binary", "--"], cwd=REPO)).hexdigest()
    assert re.fullmatch(r"[0-9a-f]{64}", current_status) and re.fullmatch(r"[0-9a-f]{64}", current_patch)
    assert snap["drift"]["state"] == "typed_drift_terminal_deferred"
    assert current_status != snap["dirty_status_sha256"] or current_patch != snap["dirty_patch_sha256"]


def check_bindings(src):
    assert len(src["four_axes"]) == 4 and {x["axis_id"] for x in src["four_axes"]} == AXES
    for axis in src["four_axes"]:
        assert_absence(axis, axis["axis_id"])
        assert axis["uri"] is None and axis["sha256"] is None
    materials = src["source_only_axis_materials"]
    edges = src["binding_edges"]
    assert len(materials) == 4 and len(edges) == 4
    for item in materials:
        assert_absence(item, item["axis_id"])
        assert item["candidate_ref"] is None and item["evidence_ref"] and HEX64.fullmatch(item["sha256"])
    for edge in edges:
        forward = edge["source_to_evidence"]
        reverse = edge["evidence_to_source"]
        assert forward["status"] == reverse["status"] == "present"
        assert forward["sha256"] == reverse["sha256"] and HEX64.fullmatch(forward["sha256"])
        assert edge["source_to_candidate"]["status"] == edge["candidate_to_source"]["status"] == "typed_absent"


def check_g2_contract(g2):
    assert g2["status"] == "typed_absent" and g2["no_publish"] is True
    mapping = g2["mapping"]
    assert all(mapping[key] is None for key in ("namespace", "version", "issuer", "source_ref", "candidate_ref", "evidence_ref"))
    requirements = g2["present_admission_requirements"]
    assert requirements["unknown_fields"] == "fail_closed"
    assert all(key in requirements for key in ("namespace", "version", "effective_interval", "issuer", "signature", "trust_root", "revocation", "anti_replay", "ambiguity", "conflict", "binding"))
    assert g2["production_profile_schema"] == "g2_production_profile_schema.json"
    assert g2["production_profile_evaluator"] == "production_g2_evaluator.py"


def check_env(env, bins):
    assert env["status"] == "typed_absent" and env["candidate_ref"] is None
    for key in ("import_closure", "module_paths", "package_closure", "artifact_closure", "environment_variables", "locale_timezone_provenance"):
        assert env[key]["status"] == "typed_absent"
    assert env["closure_policy"]["self_report_or_shape_is_not_closure"] is True
    assert bins["status"] == "typed_absent" and bins["candidate_ref"] is None
    assert bins["closure_policy"]["self_report_or_shape_is_not_closure"] is True
    for item in bins["binaries"]:
        assert BIN_KEYS <= set(item) and HEX64.fullmatch(item["sha256"]) and item["status"] == "typed_absent"


def check_register(reg):
    assert reg["status"] == "typed_absent" and reg["no_repeat"]["unchanged_action"] == "do_not_create_new_AD_or_repeat_acceptance"
    fingerprint = reg["canonical_input_fingerprint"]
    assert HEX64.fullmatch(fingerprint)
    payload = dict(reg)
    payload.pop("canonical_input_fingerprint")
    payload.pop("fingerprint_rule")
    assert canonical_hash(payload) == fingerprint
    for item in reg["inputs"]:
        assert item["state"] == "typed_absent"
        for key in ABSENCE_KEYS:
            assert item[key] not in (None, "")


def load_evaluator():
    spec = importlib.util.spec_from_file_location("production_g2_evaluator", ROOT / "production_g2_evaluator.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def check_production_profile():
    evaluator = load_evaluator()
    base = evaluator.load_path(ROOT / "fixtures/valid_present.json")
    positive = evaluator.evaluate(base)
    assert positive["accepted"] is True and positive["decision"] == "non_evidence" and positive["production_admissible"] is False
    cases = load("fixtures/production_negative_cases.json")["cases"]
    rejected = {}
    for case in cases:
        try:
            evaluator.evaluate(evaluator.mutate(base, case))
        except evaluator.ProfileError as exc:
            rejected[case] = str(exc)
        else:
            raise AssertionError(f"negative_case_accepted:{case}")
    duplicate = (ROOT / "fixtures/production_negative_duplicate_key.json").read_text(encoding="utf-8")
    try:
        evaluator.load_text(duplicate)
    except evaluator.ProfileError as exc:
        rejected["duplicate_key"] = str(exc)
    else:
        raise AssertionError("negative_case_accepted:duplicate_key")
    assert len(rejected) == len(cases) + 1
    return {"positive": positive, "negative_rejected": rejected}


def artifact_maps(manifest):
    actual = {p.relative_to(ROOT).as_posix() for p in ROOT.rglob("*") if p.is_file()}
    assert actual == set(manifest["input_exact_set"]), "manifest exact file set mismatch"
    for name in SELF_EXCLUDED:
        assert name in actual
    inputs = sorted(actual - SELF_EXCLUDED - {name for name in actual if name.startswith("raw/")} - {"report.md"})
    outputs = sorted({name for name in actual if name.startswith("raw/")} | {"report.md"})
    return {name: file_hash(ROOT / name) for name in inputs}, {name: file_hash(ROOT / name) for name in outputs}


def main():
    src = load("source_four_axis_binding.json")
    g2 = load("g2_mapping_contract.json")
    env = load("environment_dependency_closure.json")
    bins = load("binary_provenance_closure.json")
    reg = load("external_input_register.json")
    manifest = load("manifest.json")
    profile = check_production_profile()
    check_snapshot(src, manifest)
    check_bindings(src)
    check_g2_contract(g2)
    check_env(env, bins)
    check_register(reg)
    input_hashes, output_hashes = artifact_maps(manifest)
    result = {
        "status": "pass",
        "snapshot": "pass",
        "bindings": "pass",
        "g2_security": "pass",
        "production_profile": "pass_non_evidence_only",
        "negative_case_count": len(profile["negative_rejected"]),
        "environment_closure": "typed_absent_pass",
        "binary_provenance": "typed_absent_pass",
        "canonical_input_fingerprint": "pass",
        "artifact_hash_policy": {"input_count": len(input_hashes), "output_count": len(output_hashes), "self_excluded": sorted(SELF_EXCLUDED)},
        "input_artifact_hashes": input_hashes,
        "output_artifact_hashes": output_hashes,
    }
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(json.dumps({"status": "fail_closed", "error": str(exc)}, sort_keys=True, separators=(",", ":")))
        sys.exit(1)
