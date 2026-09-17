"""Audit two completed spatial runner receipts; never promote screen evidence."""

import hashlib
import json
import sys
from pathlib import Path


def load(directory, name):
    return json.loads((directory / name).read_text(encoding="utf-8"))


def check(condition, message):
    if not condition:
        raise ValueError(message)


def digest(value):
    return value["value"]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def canonical_sha256(value):
    wire = json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(wire).hexdigest()


def inspect(directory):
    check(directory.is_dir(), f"run directory missing: {directory}")
    check((directory / "runner.exit").read_text(encoding="utf-8").strip() == "0",
          f"runner did not exit zero: {directory}")
    manifest = load(directory, "execution_manifest.json")
    candidate = load(directory, "candidate.json")
    upstream = load(directory, "upstream.json")
    receipt = load(directory, "upstream_receipt.json")
    process_keys = ("command", "inspection_command", "exit_code",
                    "inspection_exit_code", "stdout", "stderr",
                    "inspection_stdout", "inspection_stderr", "input_sha256",
                    "output_sha256", "adapter_source_sha256",
                    "inspector_source_sha256", "python_executable_sha256",
                    "desc_module_sha256", "output_schema_validated")
    check(canonical_sha256({key: receipt[key] for key in process_keys}) ==
          digest(receipt["process_hash"]), "provider process hash differs")
    check(canonical_sha256(receipt) == digest(upstream["result"]["receipt_hash"]),
          "provider receipt canonical hash differs")
    check(manifest["process_exit_code"] == 0, "manifest process exit differs")
    check(manifest["candidate_hash"] == candidate["candidate_hash"] ==
          upstream["request"]["candidate_hash"] == upstream["result"]["candidate_hash"],
          "candidate hash join differs")
    check(manifest["context_hash"] == candidate["context_hash"] ==
          upstream["request"]["context_hash"] == upstream["result"]["context_hash"],
          "context hash join differs")
    check(upstream["result"]["provider_executed"] and
          upstream["result"]["solver_executed"] and receipt["exit_code"] == 0 and
          receipt["inspection_exit_code"] == 0 and receipt["output_schema_validated"],
          "provider process receipt is absent or failed")
    sealed = {str(Path(item["path"]).resolve()): digest(item["sha256"])
              for item in manifest["artifacts"]}
    for name in ("candidate.json", "upstream.json", "upstream_receipt.json"):
        path = (directory / name).resolve()
        check(sealed.get(str(path)) == sha256(path), f"manifest artifact hash differs: {path}")
    receipt_files = (
        ("input_path", "input_sha256"),
        ("output_path", "output_sha256"),
        ("adapter_path", "adapter_source_sha256"),
        ("inspector_path", "inspector_source_sha256"),
        ("python_executable", "python_executable_sha256"),
        ("desc_module_path", "desc_module_sha256"),
    )
    for path_key, hash_key in receipt_files:
        path = Path(receipt[path_key]).resolve()
        check(path.is_file() and sha256(path) == digest(receipt[hash_key]),
              f"provider {path_key} file differs from receipt")
        check(sealed.get(str(path)) == sha256(path),
              f"provider {path_key} file differs from manifest")
    check(all(receipt[key] in receipt["command"] for key in
              ("python_executable", "adapter_path", "input_path", "output_path")) and
          all(receipt[key] in receipt["inspection_command"] for key in
              ("python_executable", "inspector_path", "input_path", "output_path")),
          "provider command paths differ from receipt")
    check(upstream["result"]["claim_ceiling"] == "screen_only" and
          not upstream["result"]["physical_validation"] and
          upstream["result"]["credible_physical_device_count"] == 0,
          "DESC screen authority was overstated")
    check(not manifest["resume"] and not any(manifest["reused_checkpoints"].values()),
          "paired benchmark must use fresh, unreused checkpoints")
    return manifest, candidate, upstream, receipt


def main(argv):
    if len(argv) != 4:
        raise SystemExit("usage: audit_v4_spatial_g2_pair.py PARENT_DIR CHILD_DIR NEW_RESULT_JSON")
    parent_dir, child_dir, result_path = map(Path, argv[1:])
    check(parent_dir.resolve() != child_dir.resolve(), "parent and child run directories coincide")
    check(not result_path.exists(), "refusing to overwrite pair audit")
    pm, pc, pu, pr = inspect(parent_dir)
    cm, cc, cu, cr = inspect(child_dir)
    check(pm["candidate_kind"] == "spatial_fixture_parent", "first run is not parent")
    check(cm["candidate_kind"] == "g2_geometry_edit_child", "second run is not G2 child")
    check(cc["parent_hash"] == pc["candidate_hash"] == cm["candidate_parent_hash"],
          "G2 proposal parent binding differs")
    check(pc["candidate_hash"] != cc["candidate_hash"] and
          pc["context_hash"] != cc["context_hash"], "parent and child identities coincide")
    ph = pc["candidate"]["canonical_hashes"]
    ch = cc["candidate"]["canonical_hashes"]
    check(ph["mechanism_hash"] == ch["mechanism_hash"] and
          ph["realization_control_hash"] == ch["realization_control_hash"] and
          ph["field_geometry_hash"] != ch["field_geometry_hash"],
          "edit did not change only G2 genome")
    check(pc["candidate"]["mission_contract_ref"] == cc["candidate"]["mission_contract_ref"],
          "mission contract differs")
    for genome in ("mechanism_genome_ref", "realization_control_genome_ref"):
        check(pc["candidate"][genome] == cc["candidate"][genome],
              f"retained {genome} declaration differs")
    changes = cc["changes"]
    check(changes["kind"] == "g2_geometry_edit" and
          changes["old_declaration_hash"] == pu["geometry"]["declaration_hash"] and
          changes["new_declaration_hash"] == cu["geometry"]["declaration_hash"] and
          changes["old_program_hash"] != changes["new_program_hash"],
          "G2 declaration edit is absent")
    check(pu["result"]["request_hash"] != cu["result"]["request_hash"] and
          pu["result"]["receipt_hash"] != cu["result"]["receipt_hash"] and
          digest(pr["input_sha256"]) != digest(cr["input_sha256"]),
          "provider request/receipt/input was reused")
    check(pr["input_path"] != cr["input_path"] and
          pr["output_path"] != cr["output_path"], "provider paths were reused")
    for key in ("L", "M", "N", "L_grid", "M_grid", "N_grid", "maxiter",
                "ftol", "xtol", "gtol", "optimizer", "nfp", "psi", "Z_modes",
                "pressure", "iota"):
        check(pu["request"]["runner_payload"][key] ==
              cu["request"]["runner_payload"][key],
              f"paired DESC control or retained input differs: {key}")
    check(pu["request"]["runner_payload"]["R_modes"] !=
          cu["request"]["runner_payload"]["R_modes"],
          "edited R mode did not reach DESC request")
    for key in ("declaration_hash", "compiled_prefix_hash", "physical_subject_hash",
                "coordinate_program_hash", "metric_program_hash"):
        check(pu["geometry"][key] != cu["geometry"][key],
              f"child geometry identity was reused: {key}")
    check(pm["sources"] == cm["sources"], "paired source hash set differs")
    check("--g2-child" not in pm["command"]["arguments"] and
          "--g2-child" in cm["command"]["arguments"],
          "runner variant command differs")
    result = {
        "schema": "w24-spatial-g2-paired-screen-audit-v1",
        "status": "paired_identity_and_receipt_file_hash_checks_pass",
        "parent_candidate_hash": pc["candidate_hash"],
        "child_candidate_hash": cc["candidate_hash"],
        "parent_context_hash": pc["context_hash"],
        "child_context_hash": cc["context_hash"],
        "parent_request_hash": pu["result"]["request_hash"],
        "child_request_hash": cu["result"]["request_hash"],
        "parent_physics_solver_exit_code": pm["physical_solver_exit_code"],
        "child_physics_solver_exit_code": cm["physical_solver_exit_code"],
        "parent_outcome": pm["outcome"],
        "child_outcome": cm["outcome"],
        "claim_ceiling": "screen_only",
        "receipt_integrity_scope": "Process and receipt canonical SHA256, all receipt-referenced files, and manifest artifact SHA256 values checked using the observed no-float receipt wire schema.",
        "discovery_goal_achieved": False,
        "credible_candidate_count": 0,
    }
    result_path.parent.mkdir(parents=True, exist_ok=True)
    result_path.write_text(json.dumps(result, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main(sys.argv)
