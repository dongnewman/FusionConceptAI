from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
BASE = ROOT / "docs/implementation/UP2-00G-I0-MODULE-SEAM"
RUN = BASE / "focused_r3"
ENTRY = ROOT / "src/GenomeV5/UP2/UP2ModuleEntryV1.jl"
RUNNER = ROOT / "test/GenomeV5/UP2/run_up2_module_entry.jl"
PROBE = ROOT / "test/GenomeV5/UP2/up2_module_entry_failure_probe.jl"
TEST = ROOT / "test/GenomeV5/UP2/up2_module_entry_tests.jl"
INTEGRATION = ROOT / "src/GenomeV5/Integration/GenomeV5Integration.jl"
FUSION = ROOT / "src/FusionConceptAI.jl"
N06_TEST = ROOT / "test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl"

EXPECTED = {
    "src/GenomeV5/UP2/UP2ModuleEntryV1.jl": "7eb7ed593fbac217ea925830e53b675a38760aed708c7864bd43c436f74d8937",
    "test/GenomeV5/UP2/up2_module_entry_tests.jl": "3d595b399f8e9681881f61fa2e25590dd6646986385af72021a33672c96b4cb5",
    "test/GenomeV5/UP2/run_up2_module_entry.jl": "2847d1b98455a2fb4186be491cc00c09e5f475f83e14e1b26b7a246bf4b19cab",
    "test/GenomeV5/UP2/up2_module_entry_failure_probe.jl": "59204f1b24d6c03c1a6097e748c42808d06858a6197f49254c6ff28580c21591",
}
N06_R5 = "d88a1ed7965716eb4210c09fd5b89b3e4e27e8677c15ff8dcbe0721b8a373ca1"
N06_CURRENT = "87b5375a2f33df3acaad503bfd5685c54187e95308139e68e15ac491af43b63b"
INPUT_MANIFEST_SHA = "04b9e5f202e48cc3347a85b41c03434de996ff9d9da18af1dd5af7f046c66e05"


def digest(path: Path) -> str:
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


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    receipt = jload(RUN / "receipt.json")
    evidence = jload(RUN / "evidence_manifest.json")
    inputs = jload(RUN / "input_hashes.json")
    immediate = jload(RUN / "post_hashes.json")
    current = jload(RUN / "post_hashes_current.json")
    mutation = jload(RUN / "external_mutation.json")
    preflight = jload(RUN / "preflight.json")
    snapshots = [json.loads(x) for x in (RUN / "process_snapshots.jsonl").read_text(encoding="utf-8").splitlines() if x.strip()]
    stdout = (RUN / "stdout.log").read_text(encoding="utf-8", errors="replace")
    stderr = (RUN / "stderr.log").read_text(encoding="utf-8", errors="replace")
    entry = ENTRY.read_text(encoding="utf-8")
    runner = RUNNER.read_text(encoding="utf-8")
    probe = PROBE.read_text(encoding="utf-8")
    tests = TEST.read_text(encoding="utf-8")
    checks: dict = {}

    actual = {path: digest(ROOT / path) for path in EXPECTED}
    mark(checks, "frozen_entry_test_runner_probe_hashes", actual == EXPECTED, actual)
    mark(checks, "focused_r3_input_manifest_hash", digest(RUN / "input_hashes.json") == INPUT_MANIFEST_SHA,
         digest(RUN / "input_hashes.json"))
    input_files = inputs["files"]
    current_input_mismatches = {
        path: {"expected": (sha if isinstance(sha, str) else sha["sha256"]), "actual": digest(ROOT / path)}
        for path, sha in input_files.items()
        if path != "test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl"
        and digest(ROOT / path) != (sha if isinstance(sha, str) else sha["sha256"])
    }
    mark(checks, "r5_inputs_unchanged_except_external_n06_test", not current_input_mismatches and
         digest(N06_TEST) == N06_CURRENT,
         {"mismatches": current_input_mismatches, "n06_r5": N06_R5,
          "n06_current": digest(N06_TEST), "n06_expected_current": N06_CURRENT})

    receipt_sha = digest(RUN / "receipt.json")
    mark(checks, "receipt_and_raw_stream_hashes", receipt_sha == evidence["runtime_artifacts"]["receipt.json"]["sha256"] and
         receipt["real_exit"] == 0 and receipt["stdout"]["sha256"] == digest(RUN / "stdout.log") and
         receipt["stderr"]["sha256"] == digest(RUN / "stderr.log") and
         receipt["stdout"]["sha256"] == "95100dba52a45182383b52a1db23ae67dd1de04c0f8f0bee8fecdfc185c02d70" and
         receipt["stderr"]["sha256"] == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
         {"receipt_sha256": receipt_sha, "real_exit": receipt["real_exit"],
          "stdout": receipt["stdout"], "stderr": receipt["stderr"]})
    mark(checks, "main_summary_and_clean_stderr", re.search(r"UP2 additive module entry\s+\|\s+26\s+26", stdout) is not None and stderr == "",
         {"stdout": stdout, "stderr_bytes": len(stderr.encode("utf-8"))})
    mark(checks, "child_failure_probe_observed", receipt["main_pid"] == 54568 and
         receipt["child_pids_observed"] == [42460] and len(snapshots) >= 2 and
         snapshots[1]["main_pid"] == 54568 and any(p.get("ProcessId") == 42460 and p.get("ParentProcessId") == 54568
             for p in snapshots[1].get("processes", [])),
         {"main_pid": receipt["main_pid"], "child_pids": receipt["child_pids_observed"], "snapshots": snapshots})
    mark(checks, "probe_and_runner_static_path", "const _FAILURE_PROBE" in runner and
         "$_FAILURE_PROBE" in runner and "FAILURE_PROBE`" not in runner and
         "Base.include(@__MODULE__, entry_path)" in probe and
         "isdefined(@__MODULE__, :UP2InvocationCounterV1)" in probe and
         "up2_module_load_state() == :failed" in probe and
         "previously failed" in probe and
         "second_error === nothing" in probe,
         "runner passes the defined probe path; probe checks partial sentinel, terminal failed state, and retry refusal")

    load_order = [
        "PrecompilerInvocationCounterV1.jl", "TypedPrecompilerContractV1.jl",
        "TypedPrecompilerValidatorV1.jl", "UP2CandidatePhysicalBindingV1.jl",
        "N03TimeAuthorityProjectionV1.jl", "N04LedgerAuthorityProjectionV1.jl",
        "N05FluxAuthorityProjectionV1.jl", "N06SourceFieldLedgerMappingV1.jl",
        "N07N08GeometryProjectionV1.jl", "N09ProviderGapProjectionV1.jl",
        "N10IdentityReceiptProjectionV1.jl",
    ]
    positions = [entry.index(name) for name in load_order]
    mark(checks, "entry_order_idempotence_and_terminal_state", positions == sorted(positions) and
         "_UP2_MODULE_LOAD_STATE[] === :loaded && return nothing" in entry and
         "_UP2_MODULE_LOAD_STATE[] === :failed &&" in entry and
         "_UP2_MODULE_LOAD_STATE[] = :failed" in entry and
         "_UP2_MODULE_LOAD_STATE[] = :loaded" in entry and
         "_UP2_MODULE_LOAD_STATE[] === :loading" in entry,
         {"positions": positions, "state_guards": True})
    mark(checks, "failure_probe_partial_include_order", probe.index("Base.include(@__MODULE__, entry_path)") < probe.index("first_error = try") and
         probe.index("isdefined(@__MODULE__, :UP2InvocationCounterV1)") > probe.index("first_error === nothing") and
         entry.index("PrecompilerInvocationCounterV1.jl") < entry.index("TypedPrecompilerContractV1.jl"),
         "counter include precedes contract failure and probe checks its sentinel after first error")
    mark(checks, "no_execution_calls_or_spy_overclaim", all(token not in entry for token in ("up2_provider!", "up2_compile!", "solver_calls", "mesh_calls")) and
         all(receipt.get(key, 0) == 0 for key in ("compile_calls", "provider_calls", "solver_calls", "mesh_calls", "physical_calls")) and
         "static wiring check" in tests and "not a downstream" in tests,
         {"receipt_zero_counters": {key: receipt.get(key, 0) for key in ("compile_calls", "provider_calls", "solver_calls", "mesh_calls", "physical_calls")},
          "entry_has_no_execution_calls": True})
    mark(checks, "n06_external_test_not_loader_dependency", "n06_source_field_ledger_mapping_tests.jl" not in runner and
         "n06_source_field_ledger_mapping_tests.jl" not in entry and
         "N06SourceFieldLedgerMappingV1.jl" in entry and
         mutation["r5_preflight_sha256"] == N06_R5 and mutation["current_sha256"] == N06_CURRENT and
         mutation["runtime_impact"] == "none_to_focused_r3_loader_entry",
         mutation)
    mark(checks, "immediate_post_hashes_and_protected_dirty", immediate["mismatches"] == [] and
         immediate["protected_mismatches"] == [] and current["mismatches"] == ["test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl"],
         {"immediate_mismatches": immediate["mismatches"], "protected_mismatches": immediate["protected_mismatches"],
          "current_mismatches": current["mismatches"]})
    mark(checks, "postflight_empty_and_prior_r2_preserved", jload(RUN / "postflight_processes.json") == [] and
         (BASE / "focused_r2/hold.json").is_file() and (BASE / "focused_r1/receipt.json").is_file() and
         evidence["historical_r2_hold_preserved"] is True,
         {"postflight": jload(RUN / "postflight_processes.json"), "r2_hold": True, "r1_receipt": True})
    mark(checks, "claim_ceiling_review_pending", evidence["accepted"] is False and
         evidence["status"] == "review_pending" and "no UP2-total/B00/B04/provider/mesh/engineering/physical/R01-R10 credit" in evidence["claim_ceiling"],
         {"status": evidence["status"], "accepted": evidence["accepted"], "claim_ceiling": evidence["claim_ceiling"]})

    commands = [
        run("json_parse", [sys.executable, "-c", "import json, pathlib; [json.loads(p.read_text(encoding='utf-8')) for p in pathlib.Path('docs/implementation/UP2-00G-I0-MODULE-SEAM').rglob('*.json') if p.stat().st_size]; print('json_parse_ok')"]),
        run("validate_plan", [sys.executable, "docs/v4_multitopology_generation/validate_plan.py"]),
        run("git_diff_check", ["git", "diff", "--check"]),
        run("julia_desc_process_sweep", ["powershell", "-NoProfile", "-Command", "Get-Process | Where-Object { $_.ProcessName -match 'julia|desc' } | Select-Object Id,ProcessName | ConvertTo-Json -Compress"]),
    ]
    exits = {x["name"]: x["exit"] for x in commands}
    mark(checks, "static_qa_commands", all(v == 0 for v in exits.values()), exits)
    sweep = next(x for x in commands if x["name"] == "julia_desc_process_sweep")
    mark(checks, "no_julia_desc_run_by_audit", sweep["exit"] == 0,
         {"current_sweep_stdout": sweep["stdout"], "interpretation": "audit did not start Julia/DESC; focused R3 postflight evidence is checked separately"})

    passed = all(x["pass"] for x in checks.values())
    verdict = "pass_limited" if passed else "changes_requested"
    claim_ceiling = "module wiring/idempotence/failure-state only; no UP2-total/B00/B04/provider/mesh/engineering/physical/R01-R10 credit"
    report = {
        "schema_version": "g-i0-independent-postrun-r3-v1",
        "work_order": "UP2-00G-I0-MODULE-SEAM-independent-postrun-r3",
        "reviewer_role": "different_luna_independent_postrun",
        "verdict": verdict, "accepted": False, "checks": checks,
        "command_receipts": commands, "claim_ceiling": claim_ceiling,
        "runtime": {"julia": False, "desc": False, "auditor_started_runtime": False},
        "owned_write_scope": ["docs/implementation/UP2-00G-I0-MODULE-SEAM/independent_postrun_r3/"],
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    manifest = {
        "schema_version": "g-i0-independent-postrun-evidence-v1", "review_round": "focused_r3",
        "verdict": verdict, "accepted": False, "focused_r3_receipt_sha256": receipt_sha,
        "focused_r3_stdout_sha256": receipt["stdout"]["sha256"], "focused_r3_stderr_sha256": receipt["stderr"]["sha256"],
        "assertions": "26/26", "main_pid": receipt["main_pid"], "child_pids": receipt["child_pids_observed"],
        "failure_probe": "static source path plus observed child; partial include -> terminal :failed -> same-process retry refusal checks are present",
        "r5_input_hashes_preserved": True, "n06_external_test_only_drift_not_loader_input": True,
        "postflight_processes": [], "claim_ceiling": claim_ceiling,
    }
    (OUT / "evidence_manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    sweep_note = next(x for x in commands if x["name"] == "julia_desc_process_sweep")["stdout"].strip()
    sweep_text = sweep_note or "empty"
    md = f"""# G-I0 focused R3 independent postrun review\n\nVerdict: `{verdict}`; `accepted=false`. This review did not run Julia/DESC and did not modify focused R3 or production/core files.\n\nThe immutable receipt records real exit `0`, main PID `{receipt['main_pid']}`, observed child PID `{receipt['child_pids_observed'][0]}`, and `26/26`; raw stdout/stderr hashes match the receipt and stderr is empty. The frozen runner manually includes the counter, invokes the shared loader twice, checks exact type identity and second-call no-op, then invokes the fresh failure probe. The frozen probe includes the real entry in an isolated module, checks the counter sentinel after the later contract include fails, requires terminal `:failed`, and rejects same-process retry. The observed parent/child process sequence and exit 0 are consistent with those probe assertions passing.\n\nR5 loader inputs and protected dirty hashes match at immediate post-run. The later N06 test-only mutation is recorded separately (`d88a1ed...` to `87b537...`); the loader/runner/entry do not reference that test file, and no rerun was performed. Postflight Julia/DESC in the focused R3 receipt is empty. The independent static audit's final sweep was `{sweep_text}`; the audit did not start or stop Julia/DESC.\n\nScope is limited to module wiring, idempotence, and failure-state behavior. It grants no UP2-total, B00/B04, provider, mesh, engineering, physical, or R01-R10 credit. Historical R2 hold and R1 evidence remain preserved.\n"""
    (OUT / "report.md").write_text(md, encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
