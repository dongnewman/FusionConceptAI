"""Read-only independent auditor for the T2 R19 first actual-run failure."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[4]
RUN_REL = Path("docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r19_r23_r9")
PROTOCOL_REL = Path("docs/implementation/UP1-04A-VNEXT-T2/archive/r2_protocol_freeze_20260925_t2_protocol_r19_snapshot_receipt_retry4/protocol.json")
EXPECTED_PROTOCOL_SHA = "1b0e6f4e2267b32c83195b7cf0cf0b92c3b8d356b8fd69b6840f3cfdcf6810b8"
EXPECTED_MAP_SHA = "7cb1c9ed0d32c5ef09c135b185d42865fa22ed7381907a325ed63561fe19db56"


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def require(ok: bool, message: str) -> None:
    if not ok:
        raise RuntimeError(message)


def current_pin_audit(root: Path, protocol: dict[str, Any]) -> dict[str, Any]:
    pins = protocol.get("inputs")
    require(type(pins) is dict and len(pins) == 655,
            f"protocol current input pins expected 655, got {len(pins) if isinstance(pins, dict) else 'bad type'}")
    mismatches: list[dict[str, Any]] = []
    for rel, pin in pins.items():
        if type(pin) is not dict or pin.get("path") != rel:
            mismatches.append({"path": rel, "reason": "malformed_pin"})
            continue
        path = (root / rel).resolve()
        try:
            path.relative_to(root.resolve())
        except ValueError:
            mismatches.append({"path": rel, "reason": "path_escape"})
            continue
        if not path.is_file():
            mismatches.append({"path": rel, "reason": "missing"})
            continue
        raw = path.read_bytes()
        if len(raw) != pin.get("bytes") or sha(raw) != pin.get("sha256"):
            mismatches.append({"path": rel, "reason": "bytes_or_sha_mismatch",
                               "actual_bytes": len(raw), "actual_sha256": sha(raw)})
    positive = protocol.get("positive_reuse_input_pins", {})
    positive_mismatches = [rel for rel, pin in positive.items() if pins.get(rel) != pin]
    return {
        "current_pin_count": len(pins),
        "current_pin_match_count": len(pins) - len(mismatches),
        "current_pin_mismatches": mismatches,
        "positive_pin_count": len(positive),
        "positive_pin_match_count": len(positive) - len(positive_mismatches),
        "positive_pin_mismatches": positive_mismatches,
    }


def compare_snapshot_map(protocol: dict[str, Any], actual_map: Any, label: str) -> dict[str, Any]:
    pins = protocol["inputs"]
    if type(actual_map) is not dict:
        return {"label": label, "status": "missing_or_bad_type", "row_count": None,
                "mismatch_count": None}
    mismatches: list[str] = []
    for rel, pin in pins.items():
        observed = actual_map.get(rel)
        if type(observed) is not dict or observed.get("bytes") != pin.get("bytes") or \
                observed.get("sha256") != pin.get("sha256"):
            mismatches.append(rel)
    extra = [rel for rel in actual_map if rel not in pins]
    return {"label": label, "status": "present", "row_count": len(actual_map),
            "expected_count": len(pins), "mismatch_count": len(mismatches),
            "extra_count": len(extra), "mismatch_sample": mismatches[:10],
            "extra_sample": extra[:10]}


def find_pid_rows(value: Any, pid: int, ppid: int, path: str = "$"
                  ) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    if isinstance(value, dict):
        for key, child in value.items():
            found.extend(find_pid_rows(child, pid, ppid, f"{path}.{key}"))
    elif isinstance(value, list):
        if len(value) >= 4 and value[0] == pid and value[1] == ppid:
            found.append({"path": path, "row": value})
        for index, child in enumerate(value):
            found.extend(find_pid_rows(child, pid, ppid, f"{path}[{index}]"))
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()
    root = ROOT.resolve()
    run_dir = root / RUN_REL
    protocol_path = root / PROTOCOL_REL
    out = Path(args.output_dir).resolve()
    out.mkdir(parents=True, exist_ok=True)

    protocol_raw = protocol_path.read_bytes()
    require(sha(protocol_raw) == EXPECTED_PROTOCOL_SHA, "frozen R19 protocol SHA mismatch")
    protocol = json.loads(protocol_raw)
    pipeline_start_path = run_dir / "pipeline_start.json"
    pipeline_final_path = run_dir / "pipeline_final.json"
    pipeline_start = read_json(pipeline_start_path)
    pipeline_final = read_json(pipeline_final_path)
    baseline_path = run_dir / "actual_formal_baseline" / "phase.json"
    baseline = read_json(baseline_path)
    samples_path = run_dir / "actual_formal_baseline" / "samples.jsonl"
    sample_rows = [json.loads(line) for line in samples_path.read_text(encoding="utf-8").splitlines()]
    last_sample = sample_rows[-1]

    require(sha(Path(root / protocol["coverage_map"]["path"]).read_bytes()) == EXPECTED_MAP_SHA,
            "coverage map SHA mismatch")
    pin_audit = current_pin_audit(root, protocol)
    require(pin_audit["current_pin_match_count"] == 655 and
            not pin_audit["current_pin_mismatches"], "current protocol input closure mismatch")
    require(pin_audit["positive_pin_match_count"] == 104 and
            not pin_audit["positive_pin_mismatches"], "positive reuse pin mismatch")

    phase_rows = pipeline_final.get("phases", [])
    phase_names = [row.get("name") for row in phase_rows]
    expected_phase_names = ["parse_gate", "coverage_ast_inventory",
                            "projection24_cross_run_validation", "actual_formal_baseline"]
    require(phase_names == expected_phase_names, f"unexpected completed phase sequence: {phase_names}")
    require([row.get("exit_code") for row in phase_rows] == [0, 0, 0, 15],
            "completed phase exit sequence differs from 0,0,0,15")
    require(pipeline_final.get("status") == "fail" and
            pipeline_final.get("formal_t2_accepted") is False and
            pipeline_final.get("scientific_acceptance") is False and
            pipeline_final.get("physical_acceptance") is False,
            "pipeline failure/acceptance classification drift")
    require(pipeline_final.get("repository_head_before") ==
            pipeline_final.get("repository_head_after"), "repository HEAD changed during run")
    require(baseline.get("name") == "actual_formal_baseline" and
            baseline.get("exit_code") == 15 and
            baseline.get("stop_reason") == "process_tree_monitor_incomplete",
            "baseline phase failure classification drift")
    require(baseline.get("process_tree_samples_complete") is False and
            baseline.get("process_tree_sample_count") == 161 and
            len(sample_rows) == 161 and last_sample.get("sample_complete") is False,
            "baseline incomplete sample receipt mismatch")
    require(baseline.get("peak_process_tree_working_set_bytes", 0) <
            protocol["resource_gates"]["process_tree_working_set_bytes"],
            "baseline reached/exceeded working-set cap")
    require(baseline.get("final_process_tree_audit", {}).get("complete") is True and
            baseline.get("final_process_tree_audit", {}).get("tracked_identity_count") == 2,
            "final audit completeness/tracked scope mismatch")
    require(baseline.get("final_process_tree_audit", {}).get(
            "residual_descendant_processes") == [] and
            baseline.get("final_process_tree_audit", {}).get("tracked_pid_reuse") == [],
            "tracked final audit found residual/reuse")
    require(baseline.get("termination_receipt", {}).get("verified") is True and
            baseline.get("termination_receipt", {}).get("root_exit_confirmed") is True,
            "termination receipt is not verified")
    signal_receipts = [entry.get("receipt", {}) for entry in
                       baseline.get("termination_receipt", {}).get("signal_attempts", [])]
    require(len(signal_receipts) == 2 and all(
        r.get("complete") is True and r.get("wait_confirmed") is True and
        r.get("exit_code") == 15 and r.get("signal_sent") is True
        for r in signal_receipts), "expected two exact tracked-process termination receipts")

    error_list = last_sample.get("errors", [])
    matching_error = any(
        e.get("type") == "MonitorIncomplete" and
        e.get("message") == "cannot open a process absent from current SPI snapshot" and
        e.get("phase") == "sample_process_tree" for e in error_list)
    require(matching_error, "last sample does not show expected absent-from-SPI monitor error")
    untracked_rows = find_pid_rows(last_sample, 18528, 86060)
    require(any(hit["row"] == [18528, 86060, 134348254310869192, "git.exe"]
                for hit in untracked_rows), "expected untracked direct git.exe row not found")
    tracked = {(row.get("pid"), row.get("create_time_100ns"))
               for row in baseline.get("tracked_process_identities_raw", [])}
    require(not any((18528, 134348254310869192) == identity for identity in tracked),
            "the observed git.exe generation was unexpectedly in tracked identity list")

    before = compare_snapshot_map(protocol, pipeline_start.get("inputs_before"), "pipeline_start.inputs_before")
    final_before = compare_snapshot_map(protocol, pipeline_final.get("inputs_before"), "pipeline_final.inputs_before")
    after = compare_snapshot_map(protocol, pipeline_final.get("inputs_after"), "pipeline_final.inputs_after")
    snapshot_maps = [before, final_before, after]
    # The pipeline records all three snapshots; allow missing only if the schema
    # omitted the duplicate start snapshot, but any present full snapshot must match.
    for snapshot in snapshot_maps:
        if snapshot["status"] != "missing_or_bad_type":
            require(snapshot["row_count"] == 655 and snapshot["mismatch_count"] == 0 and
                    snapshot["extra_count"] == 0,
                    f"{snapshot['label']} differs from the frozen 655-pin set")

    actual_files: list[dict[str, Any]] = []
    for path in sorted(run_dir.rglob("*")):
        if path.is_file():
            raw = path.read_bytes()
            actual_files.append({"path": path.relative_to(root).as_posix(),
                                 "bytes": len(raw), "sha256": sha(raw)})
    negative_phase_paths = [
        "actual_formal_preflight/phase.json",
        "actual_formal_authority/phase.json",
        "actual_formal_fault_n10/phase.json",
        "actual_formal_t1_handoff/phase.json",
    ]
    negative_shards_absent = all(not (run_dir / rel).exists() for rel in negative_phase_paths)
    require(negative_shards_absent, "a negative formal shard appears to have executed")
    baseline_stdout = (run_dir / "actual_formal_baseline" / "stdout.raw").read_bytes()
    baseline_stderr = (run_dir / "actual_formal_baseline" / "stderr.raw").read_bytes()
    require(not baseline_stderr, "baseline stderr is unexpectedly nonempty")
    stdout_text = baseline_stdout.decode("utf-8", errors="replace")
    require("Test Summary" not in stdout_text and
            "VNEXT_T2_NEGATIVE_STAGE=fresh_source_t1_admission.begin" in stdout_text,
            "baseline stdout no longer indicates interruption before test summary")
    require(pipeline_final.get("actual_source_site_hits") is None and
            pipeline_final.get("preserved_successor_runtime_hit_count_observed") is None,
            "actual assertion-site hit data unexpectedly present")

    report = {
        "schema": "independent-t2-r19-postrun-audit-r1",
        "verdict": "RUNTIME_NO_GO_MONITOR_INCOMPLETE_BEFORE_FORMAL_NEGATIVE_SHARDS",
        "protocol": {"path": PROTOCOL_REL.as_posix(), "sha256": sha(protocol_raw),
                     "bytes": len(protocol_raw)},
        "coverage_map_sha256": EXPECTED_MAP_SHA,
        "current_pin_audit": pin_audit,
        "run_file_inventory": actual_files,
        "run_file_count": len(actual_files),
        "pipeline": {
            "start_sha256": sha(pipeline_start_path.read_bytes()),
            "final_sha256": sha(pipeline_final_path.read_bytes()),
            "status": pipeline_final.get("status"),
            "formal_t2_accepted": pipeline_final.get("formal_t2_accepted"),
            "repository_head_before": pipeline_final.get("repository_head_before"),
            "repository_head_after": pipeline_final.get("repository_head_after"),
            "phase_sequence": [{"name": p.get("name"), "exit_code": p.get("exit_code"),
                                "stop_reason": p.get("stop_reason"),
                                "seconds": p.get("seconds"),
                                "samples": p.get("process_tree_sample_count"),
                                "samples_complete": p.get("process_tree_samples_complete")}
                               for p in phase_rows],
            "negative_shards_absent": negative_shards_absent,
            "actual_site_hits_observed": pipeline_final.get("actual_source_site_hits"),
            "outer_shell_exit": "1 as reported by root; no separate invocation receipt found in this repository checkout",
        },
        "baseline": {
            "phase_sha256": sha(baseline_path.read_bytes()),
            "phase_exit": baseline.get("exit_code"),
            "child_exit": baseline.get("exit_code"),
            "stop_reason": baseline.get("stop_reason"),
            "seconds": baseline.get("seconds"),
            "peak_rss_bytes": baseline.get("peak_process_tree_working_set_bytes"),
            "rss_cap_bytes": protocol["resource_gates"]["process_tree_working_set_bytes"],
            "sample_count": len(sample_rows),
            "samples_complete": baseline.get("process_tree_samples_complete"),
            "last_sample_index": last_sample.get("sample_index"),
            "last_sample_sha256": sha(samples_path.read_bytes()),
            "last_sample_error": [e for e in error_list if e.get("message") ==
                                  "cannot open a process absent from current SPI snapshot"],
            "untracked_git_row": untracked_rows,
            "tracked_identity_count": baseline.get("tracked_process_identity_count"),
            "tracked_final_audit_complete": baseline.get("final_process_tree_audit", {}).get("complete"),
            "tracked_final_audit_residuals": baseline.get("final_process_tree_audit", {}).get("residual_descendant_processes"),
            "verified_termination_exit_codes": [r.get("exit_code") for r in signal_receipts],
            "stdout_sha256": sha(baseline_stdout),
            "stderr_sha256": sha(baseline_stderr),
            "test_summary_emitted": "Test Summary" in stdout_text,
        },
        "input_snapshots": snapshot_maps,
        "interpretation": {
            "classification": "program/process-tree monitor interruption, not assertion or numerical failure",
            "final_audit_scope": "complete for the two tracked identities only; final residual audit is empty",
            "untracked_child": "PID 18528 git.exe with parent 86060 appears in the terminal native snapshot-before digest but was not in tracked identities; monitor failed closed while opening it against a later/current SPI snapshot",
            "acceptance": "none; baseline was interrupted before test summary and the four negative shards did not execute",
        },
        "limitations": [
            "No Julia was started by this auditor; the audited R19 run had already started Julia.",
            "The repository checkout contains no separate root invocation.json/outer shell receipt; outer shell exit 1 is reported by root, while pipeline_final status=fail and baseline phase exit 15 are directly verified.",
        ],
    }
    report_path = out / "audit.json"
    raw = json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    report_path.write_text(raw, encoding="utf-8", newline="\n")
    md = (
        "# T2 R19 actual-run independent postrun audit\n\n"
        "Verdict: **runtime NO-GO**. The baseline phase failed closed with `process_tree_monitor_incomplete`; no formal negative shard ran and no T2 acceptance was produced.\n\n"
        f"Protocol SHA-256: `{sha(protocol_raw)}`. Current protocol inputs: {pin_audit['current_pin_match_count']}/655 matched; positive reuse pins: {pin_audit['positive_pin_match_count']}/104.\n\n"
        "Completed phases: parse gate, AST inventory and Projection24 each exited 0; `actual_formal_baseline` exited 15 after 48.754 s. Peak sampled working set was 819,822,592 bytes against the 2 GiB cap. The baseline produced 161 samples, with sample completeness false.\n\n"
        "The final sample recorded `MonitorIncomplete: cannot open a process absent from current SPI snapshot`. Its `native_snapshot_before_digest` contained direct child `git.exe` PID 18528 / PPID 86060 / FILETIME 134348254310869192, absent from the two tracked identities. The supervisor terminated and verified both tracked processes (exit 15); its final audit was complete for those two tracked identities and reported no residual descendants.\n\n"
        "No `Test Summary` was emitted, the actual source-site hit total is null, and preflight/authority/fault-N10/T1 negative shards are absent. This is a monitor interruption, not an assertion/numerical result. The outer shell exit 1 is reported by root; no separate invocation receipt was found in this checkout. This audit itself only read files and did not launch Julia.\n"
    )
    (out / "report.md").write_text(md, encoding="utf-8", newline="\n")
    source = Path(__file__).resolve()
    files = []
    for path in sorted(out.iterdir()):
        if path.is_file() and path.name not in {"manifest.json", "SHA256SUMS"}:
            b = path.read_bytes()
            files.append({"path": path.name, "bytes": len(b), "sha256": sha(b)})
    sums = "".join(f"{row['sha256']}  {row['path']}\n" for row in files)
    (out / "SHA256SUMS").write_text(sums, encoding="ascii", newline="\n")
    sums_raw = (out / "SHA256SUMS").read_bytes()
    files.append({"path": "SHA256SUMS", "bytes": len(sums_raw), "sha256": sha(sums_raw)})
    manifest = {
        "schema": "independent-t2-r19-postrun-evidence-manifest-r1",
        "evidence_only": True,
        "verdict": report["verdict"],
        "artifacts": files,
        "source_anchors": [
            {"path": PROTOCOL_REL.as_posix(), "sha256": sha(protocol_raw)},
            {"path": source.relative_to(root).as_posix(), "sha256": sha(source.read_bytes())},
            {"path": RUN_REL.as_posix() + "/pipeline_start.json",
             "sha256": sha(pipeline_start_path.read_bytes())},
            {"path": RUN_REL.as_posix() + "/pipeline_final.json",
             "sha256": sha(pipeline_final_path.read_bytes())},
        ],
        "execution_boundary": "Read-only Python audit; no Julia launch",
    }
    (out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False,
        sort_keys=True, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"status": report["verdict"], "output": str(report_path),
                      "run_file_count": len(actual_files),
                      "current_pin_matches": pin_audit["current_pin_match_count"],
                      "phase_exit_codes": [p.get("exit_code") for p in phase_rows],
                      "julia_started_by_auditor": False}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
