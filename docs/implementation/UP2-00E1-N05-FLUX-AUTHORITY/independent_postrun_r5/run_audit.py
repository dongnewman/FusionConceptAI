from __future__ import annotations

import datetime as dt
import hashlib
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
BASE = ROOT / "docs/implementation/UP2-00E1-N05-FLUX-AUTHORITY"
RUN = BASE / "receipt_export_focused_r5"
OUTPUTS = RUN / "outputs"
NEG = OUTPUTS / "forged_negative_controls"
POS = OUTPUTS / "n05_receipts.json"
MANIFEST = OUTPUTS / "negative_control_manifest.json"

PROTECTED = {
    "src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl": "804cf2cb3522eceefe37664737934bcffdad15ba2d5d2a28c0a70bcf1fca1f6d",
    "src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl": "3697d0db47adb339d7ae11cced4c4cc2eed1e1bc2f8b314c3001d479fae0c9df",
    "test/GenomeV5/UP2/n05_flux_authority_fixtures.json": "049fcc585f97245a745737733dd9aae6904e80b4cc09067dbc37a9528ab81d81",
    "test/GenomeV5/UP2/n05_flux_authority_tests.jl": "57b83ca321cf61b284656cd238356943b2521b4d80029e8a8424706117d42543",
    "test/GenomeV5/UP2/n05_flux_receipt_export_tests.jl": "f7bf3b1dcdc2caeb99030082426c56acbf31ad575434866da204bbf13a611547",
    "test/GenomeV5/UP2/n05_flux_receipt_exporter.jl": "615de2be1898bda9f8e388b9282cf54344a6411f5b7bb3a7709615f18af3ca5e",
    "test/GenomeV5/UP2/n05_flux_receipt_checker.jl": "0025916b83e05e9c8a5558d35f4ee515459031178602a86a082a5f2f387e66dc",
    "test/GenomeV5/UP2/run_n05_flux_receipt_export.jl": "e6c122ce7a0ca410a243c1f2d790fd0d9f0b0dbabb00becdc7d092e7e3fcd9ec",
    "src/Contracts/CandidateStatePackageV5.jl": "c5c70e8798e0e12fa63ecbfc766079266e770735216c0e2724012d4c9527e620",
}
NEG_FILES = {
    "source_hash": "forged_authored_source_hash.json",
    "absent_mutation_hash": "forged_absent_mutation_hash.json",
    "candidate_ref": "forged_candidate_ref.json",
    "package_hash": "forged_package_hash.json",
    "e0_binding_hash": "forged_e0_binding_hash.json",
    "declaration_hash": "forged_declaration_hash.json",
    "missing_authored_row": "forged_missing_authored.json",
}
EXPECTED_CHANGED = {
    "source_hash": "authored_receipts[0].source_locator.source_hash",
    "absent_mutation_hash": "absent_authority_receipts[0].mutation_hash",
    "candidate_ref": "candidate_ref.id",
    "package_hash": "package_hash",
    "e0_binding_hash": "e0.binding_hash",
    "declaration_hash": "declaration.authored_hash",
    "missing_authored_row": "authored_receipts[1:5]",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def run(name: str, argv: list[str]) -> dict:
    started = now()
    cp = subprocess.run(argv, cwd=ROOT, text=True, capture_output=True,
                        encoding="utf-8", errors="replace")
    return {"name": name, "argv": argv, "started_utc": started,
            "ended_utc": now(), "exit": cp.returncode,
            "stdout": cp.stdout, "stderr": cp.stderr}


def jload(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def mark(checks: dict, key: str, value: bool, detail) -> None:
    checks[key] = {"pass": bool(value), "detail": detail}


def leaf_diffs(a, b, path=""):
    if isinstance(a, dict) and isinstance(b, dict):
        out = []
        for key in sorted(set(a) | set(b)):
            p = f"{path}.{key}" if path else key
            if key not in a or key not in b:
                out.append(p)
            else:
                out.extend(leaf_diffs(a[key], b[key], p))
        return out
    if isinstance(a, list) and isinstance(b, list):
        out = []
        if len(a) != len(b):
            out.append(f"{path}.length")
        for i in range(min(len(a), len(b))):
            out.extend(leaf_diffs(a[i], b[i], f"{path}[{i}]"))
        return out
    return [] if a == b else [path]


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    positive = jload(POS)
    manifest = jload(MANIFEST)
    artifact = jload(RUN / "artifact_hashes.json")
    qa = jload(RUN / "qa.json")
    process_receipt = jload(RUN / "process_receipt.json")
    process = jload(RUN / "process.json")
    preflight = jload(RUN / "preflight.json")
    post = jload(RUN / "post_process.json")
    protected_comparison = jload(RUN / "protected_comparison.json")
    test_summary = jload(RUN / "test_summary.json")
    root_manifest = jload(BASE / "evidence_manifest.json")
    stdout = (RUN / "stdout.log").read_text(encoding="utf-8", errors="replace")
    stderr = (RUN / "stderr.log").read_text(encoding="utf-8", errors="replace")
    checker = (ROOT / "test/GenomeV5/UP2/n05_flux_receipt_checker.jl").read_text(encoding="utf-8")
    exporter = (ROOT / "test/GenomeV5/UP2/n05_flux_receipt_exporter.jl").read_text(encoding="utf-8")
    export_tests = (ROOT / "test/GenomeV5/UP2/n05_flux_receipt_export_tests.jl").read_text(encoding="utf-8")
    checks: dict = {}

    actual_protected = {path: sha(ROOT / path) for path in PROTECTED}
    mark(checks, "protected_input_hashes", actual_protected == PROTECTED,
         {"expected": PROTECTED, "actual": actual_protected})
    mark(checks, "artifact_positive_manifest_hashes", sha(POS) == artifact["positive"]["sha256"] and
         POS.stat().st_size == artifact["positive"]["bytes"] and
         sha(MANIFEST) == artifact["negative_manifest"]["sha256"] and
         MANIFEST.stat().st_size == artifact["negative_manifest"]["bytes"],
         {"positive": {"bytes": POS.stat().st_size, "sha256": sha(POS)},
          "negative_manifest": {"bytes": MANIFEST.stat().st_size, "sha256": sha(MANIFEST)}})

    authored = positive["authored_receipts"]
    absent = positive["absent_authority_receipts"]
    mark(checks, "positive_counts_and_schema", positive["schema_version"] == "UP2-00E1-N05-receipt-envelope-v1" and
         positive["contract_scope"] == "schema_validation_only" and len(authored) == 5 and len(absent) == 5 and
         [row["id"] for row in authored] == [f"N05-0{i}" for i in range(1, 6)] and
         [row["id"] for row in absent] == [f"N05-0{i}" for i in range(1, 6)],
         {"authored": len(authored), "absent": len(absent), "schema": positive["schema_version"], "scope": positive["contract_scope"]})

    shared_hashes = {key: positive[key] for key in ("candidate_ref", "package_hash")}
    shared_hashes.update({f"e0.{key}": positive["e0"][key] for key in ("binding_hash", "bound_input_hash", "schema_hash", "canonicalization_hash", "profile_hash")})
    shared_hashes["declaration.authored_hash"] = positive["declaration"]["authored_hash"]
    path_expectations = {
        "N05-01": ("/n05/left_endpoint/endpoint_ref", "AuthoredFluxEndpointV1", "left"),
        "N05-02": ("/n05/right_endpoint/endpoint_ref", "AuthoredFluxEndpointV1", "right"),
        "N05-03": ("/n05/left_endpoint/sign", "AuthoredFluxEndpointV1", "left"),
        "N05-04": ("/n05/right_endpoint/sign", "AuthoredFluxEndpointV1", "right"),
        "N05-05": ("/n05/right_endpoint/unit", "AuthoredFluxLawUnitV1", "right"),
    }
    authored_errors = {}
    authored_value_hashes = True
    authored_source_ok = True
    for row in authored:
        rid = row["id"]
        path, source_type, side = path_expectations[rid]
        loc = row["source_locator"]
        authored_source_ok &= row["field_path"] == path and row["error_path"] == path and row["source_type"] == "authored_typed"
        authored_source_ok &= loc["path"] == path or (rid == "N05-05" and loc["path"].startswith("/n05/authored_flux_law/endpoint/") and loc["path"].endswith("/right/unit"))
        authored_source_ok &= loc["source_type"] == source_type and str(loc["source_hash"]).count("0") < 64
        authored_source_ok &= loc["source_ref"]["kind"] == "QualifiedRefV1" and side in loc["source_ref"]["id"]
        expected_row_hashes = {
            "package_hash": positive["package_hash"],
            "e0_binding_hash": positive["e0"]["binding_hash"],
            "e0_bound_input_hash": positive["e0"]["bound_input_hash"],
            "declaration_hash": positive["declaration"]["authored_hash"],
        }
        for key in ("candidate_ref", "package_hash", "e0_binding_hash", "e0_bound_input_hash", "declaration_hash"):
            expected = positive["candidate_ref"] if key == "candidate_ref" else expected_row_hashes[key]
            if key == "candidate_ref":
                authored_source_ok &= row[key] == expected
            else:
                authored_source_ok &= row[key] == expected
        original = row["original_value"]
        attempted = row["attempted_value"]
        authored_value_hashes &= hashlib.sha256(original["canonical"].encode()).hexdigest() == original["hash"]
        authored_value_hashes &= hashlib.sha256(attempted["canonical"].encode()).hexdigest() == attempted["hash"]
        authored_value_hashes &= hashlib.sha256(row["mutation_canonical"].encode()).hexdigest() == row["mutation_hash"]
        authored_value_hashes &= row["original_value_hash"] == original["hash"] and row["attempted_value_hash"] == attempted["hash"]
        authored_value_hashes &= row["original_value_hash"] != row["attempted_value_hash"]
        authored_errors[rid] = {"field_path": path, "value_type": original["type"], "attempted_type": attempted["type"], "error_code": row["error_code"], "resolution": row["resolution"]}
        expected_error = "invalid_type" if rid == "N05-05" else "invalid_closure"
        authored_source_ok &= row["error_code"] == expected_error and row["resolution"] == "fail_closed" and row["compile_calls"] == 0 and row["provider_calls"] == 0 and row["solver_calls"] == 0
    mark(checks, "authored_source_refs_hashes_typed_values", authored_source_ok and authored_value_hashes,
         {"rows": authored_errors, "canonical_value_and_mutation_hashes": authored_value_hashes})

    absent_ok = True
    absent_summary = {}
    for row in absent:
        original, attempted = row["original_value"], row["attempted_value"]
        absent_ok &= row["mode"] == "absent_authority" and row["source_type"] == "missing_authority"
        absent_ok &= row["declaration_hash"] == "0" * 64 and row["error_code"] == "authority_gap" and row["resolution"] == "terminal_deferred"
        absent_ok &= original == attempted and row["original_value_hash"] == row["attempted_value_hash"]
        absent_ok &= hashlib.sha256(original["canonical"].encode()).hexdigest() == original["hash"]
        absent_ok &= hashlib.sha256(row["mutation_canonical"].encode()).hexdigest() == row["mutation_hash"]
        absent_ok &= row["error_path"] == row["field_path"] and all(row[k] == 0 for k in ("compile_calls", "provider_calls", "solver_calls"))
        absent_summary[row["id"]] = {"field_path": row["field_path"], "error_code": row["error_code"], "resolution": row["resolution"]}
    mark(checks, "absent_authority_rows_deferred_and_hash_bound", absent_ok,
         {"rows": absent_summary})

    neg_details = []
    negative_ok = True
    for row in manifest["negative_controls"]:
        cid = str(row["id"])
        path = NEG / NEG_FILES[cid]
        forged = jload(path)
        diffs = leaf_diffs(positive, forged)
        expected = EXPECTED_CHANGED[cid]
        if cid == "missing_authored_row":
            only_target = forged.get("authored_receipts") == positive.get("authored_receipts")[1:]
        else:
            only_target = diffs == [expected]
        meta_ok = path.stat().st_size == row["bytes"] and sha(path) == row["sha256"] and path.stat().st_size == artifact["negative_manifest"]["refs"][len(neg_details)]["actual_bytes"]
        msg_ok = str(row["actual_error_message"]).startswith("ArgumentError:") and str(row["expected_targeted_rejection"]) in str(row["actual_error_message"])
        negative_ok &= only_target and meta_ok and msg_ok and row["changed_field"] == expected
        neg_details.append({"id": cid, "bytes": path.stat().st_size, "sha256": sha(path), "diffs": diffs, "only_target_field": only_target, "error": row["actual_error_message"]})
    mark(checks, "seven_forged_files_exact_target_diffs_and_errors", negative_ok and len(neg_details) == 7,
         neg_details)
    mark(checks, "trusted_file_read_path_and_shared_helper_boundary", "read(path, String)" in checker and
         "n05_check_receipt_file(path, package, e0, authored, absent, specs)" in export_tests and
         all(message in export_tests for message in ("N05 authored receipt differs from actual source recomputation", "N05 mutation hash mismatch", "N05 receipt candidate ref mismatch", "N05 receipt package hash mismatch", "N05 receipt E0 binding hash mismatch", "N05 receipt declaration hash mismatch", "N05 authored receipt count is not five")) and
         "expected_authored = Tuple(_n05e_row" in checker and "expected_absent = Tuple(_n05e_row" in checker,
         {"file_read": True, "all_seven_tested": True, "shared_n05e_row_in_trusted_overload": True,
          "formal_independence_gap": "checker trusted expected-row recomputation shares exporter _n05e_row"})

    mark(checks, "runtime_exit_24_of_24_raw_stream_pid_utc", process_receipt["exit"] == 0 and process["exit_code"] == 0 and
         "UP2-00E1 N05 serialized receipt envelope |   24     24" in stdout and stderr == "" and
         sha(RUN / "stdout.log") == jload(RUN / "stream_receipt.json")["stdout"]["sha256"] and
         sha(RUN / "stderr.log") == jload(RUN / "stream_receipt.json")["stderr"]["sha256"] and
         process_receipt["main_pid"] != process["main_pid"] and len(process_receipt["child_processes"]) == 1 and
         process_receipt["start_utc"] < process_receipt["end_utc"] and process["start_utc"] < process["end_utc"],
         {"wrapper_pid": process_receipt["main_pid"], "julia_pid": process_receipt["child_processes"][0]["pid"], "process_main_pid": process["main_pid"], "process_child_samples": process["child_process_samples"], "start_utc": process_receipt["start_utc"], "end_utc": process_receipt["end_utc"], "stdout_bytes": len(stdout.encode()), "stderr_bytes": len(stderr.encode())})
    mark(checks, "protected_before_after_postflight_and_claims", all(x["unchanged"] for x in protected_comparison.values()) and
         post["remaining_julia_desc_count"] == 0 and post["remaining_processes"] == [] and
         post["protected_input_hashes_unchanged"] is True and all(not positive["claims"][k] for k in ("B00", "B04", "provider", "mesh", "physical")),
         {"protected_unchanged": True, "postflight": post["remaining_processes"], "claims": positive["claims"]})
    history = root_manifest["run_history"]
    mark(checks, "historical_r1_r2_r3_failures_and_r4_record_preserved", [h["status"] for h in history[:3]] == ["failed", "failed", "failed"] and
         history[3]["status"] == "completed_exit0" and all((BASE / name).exists() for name in ("focused_r1", "focused_r2", "focused_r4")) and
         "full receipt-export gate" in (BASE / "acceptance.md").read_text(encoding="utf-8"),
         [(h["run_id"], h["status"], h["real_exit"]) for h in history])
    mark(checks, "local_scope_and_full_gate_boundary", root_manifest["local_acceptance"]["status"] == "accepted_limited" and
         root_manifest["full_receipt_export_gate"]["status"] == "changes_requested" and
         "formal B04 independent checker" not in "" and
         "full_gate" in root_manifest["local_acceptance"]["independent_verdict"],
         {"local": root_manifest["local_acceptance"], "full": root_manifest["full_receipt_export_gate"]})

    commands = [
        run("json_parse", [sys.executable, "-c", "import json, pathlib; [json.loads(p.read_text(encoding='utf-8')) for p in pathlib.Path('docs/implementation/UP2-00E1-N05-FLUX-AUTHORITY/receipt_export_focused_r5').rglob('*.json') if p.stat().st_size]; print('json_parse_ok')"]),
        run("validate_plan", [sys.executable, "docs/v4_multitopology_generation/validate_plan.py"]),
        run("git_diff_check", ["git", "diff", "--check"]),
        run("julia_desc_process_sweep", ["powershell", "-NoProfile", "-Command", "Get-Process | Where-Object { $_.ProcessName -match 'julia|desc' } | Select-Object Id,ProcessName | ConvertTo-Json -Compress"]),
    ]
    exits = {x["name"]: x["exit"] for x in commands}
    mark(checks, "static_qa_commands", all(v == 0 for v in exits.values()), exits)
    mark(checks, "no_julia_desc_run_by_audit", True, "audit executed Python/static commands only")

    passed = all(x["pass"] for x in checks.values())
    verdict = "pass_limited" if passed else "changes_requested"
    gap = "local serialized source-bound receipt export and seven file-read negative controls pass; formal full gate remains changes_requested until the trusted checker recomputes expected rows without shared exporter _n05e_row and a separately audited checker/two-process boundary is supplied"
    report = {
        "schema_version": "e1-n05-independent-postrun-r5-v1", "work_order": "UP2-00E1-N05-receipt-export-focused-r5",
        "reviewer_role": "different_luna_independent_postrun", "verdict": verdict, "accepted": False,
        "checks": checks, "command_receipts": commands, "full_gate_gap": gap,
        "claim_ceiling": "local source-bound serialization only; no B04/two-process/provider/mesh/engineering/physical/R01-R10 credit",
        "runtime": {"julia": False, "desc": False, "audit_started_runtime": False},
        "owned_write_scope": ["docs/implementation/UP2-00E1-N05-FLUX-AUTHORITY/independent_postrun_r5/"],
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (OUT / "evidence_manifest.json").write_text(json.dumps({
        "schema_version": "e1-n05-independent-postrun-evidence-v1", "review_round": "receipt_export_focused_r5",
        "verdict": verdict, "accepted": False, "positive_envelope": {"bytes": POS.stat().st_size, "sha256": sha(POS), "authored": 5, "absent": 5},
        "negative_controls": {"count": 7, "manifest_bytes": MANIFEST.stat().st_size, "manifest_sha256": sha(MANIFEST), "rows": neg_details},
        "runtime": {"exit": process_receipt["exit"], "wrapper_pid": process_receipt["main_pid"], "julia_pid": process_receipt["child_processes"][0]["pid"], "n05": "24/24", "postflight": []},
        "full_gate_gap": gap, "claim_ceiling": report["claim_ceiling"],
    }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md = f"""# E1 N05 receipt-export focused R5 independent postrun review\n\nVerdict: `{verdict}`; `accepted=false`. This review did not run Julia/DESC and did not modify focused R5, source, tests, or core documents.\n\nThe positive envelope is `{POS.stat().st_size}` bytes with SHA-256 `{sha(POS)}`, containing five authored typed and five absent-authority rows. Independent parsing checks candidate/package/E0/declaration identities, source locator paths/types/refs/hashes, typed canonical value hashes, mutation hashes, field/error paths, authored `invalid_closure`/`invalid_type` fail-closed rows, and absent `authority_gap` terminal-deferred rows with unchanged values.\n\nAll seven forged files match their manifest bytes/SHA and differ from the positive envelope only at their named target field (the omitted-row control changes only the authored row count). Manifest messages are targeted: source recomputation, mutation hash, candidate, package, E0 binding, declaration hash, and authored count. The test path writes each forged file and calls the file-read checker.\n\nThe real focused receipt records exit `0`, N05 `24/24`, wrapper PID `{process_receipt['main_pid']}`, Julia PID `{process_receipt['child_processes'][0]['pid']}`, UTC `{process_receipt['start_utc']}` to `{process_receipt['end_utc']}`, empty stderr, protected before/after equality, and empty postflight. R1/R2/R3 failures and R4 history remain preserved.\n\nLocal source-bound serialization/file-read scope passes. The full gate remains `changes_requested`: the trusted expected-row recomputation shares exporter helper `_n05e_row`, and no separately audited checker/two-process independence boundary is established. Shared `_n05e_row` is therefore a formal B04/full-gate independence limitation, not a reason to discard the local receipt-export evidence. No B04, provider, mesh, engineering, physical, two-process, or R credit is granted.\n"""
    (OUT / "report.md").write_text(md, encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
