from __future__ import annotations

import datetime as dt
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(r"D:\006-Programing\LMC\FusionConceptAI")
OUT = ROOT / "docs/implementation/UP2-00E0-BOUND-INPUT/acceptance_integration_independent"
OUT.mkdir(parents=True, exist_ok=True)

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run(argv: list[str]) -> dict:
    started = dt.datetime.now(dt.timezone.utc)
    proc = subprocess.run(argv, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    ended = dt.datetime.now(dt.timezone.utc)
    return {"argv": argv, "started_utc": started.isoformat(), "ended_utc": ended.isoformat(), "exit_code": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr}

def parsed(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))

def diff_paths(old, new, path=""):
    if isinstance(old, dict) and isinstance(new, dict):
        for key in sorted(set(old) | set(new)):
            here = f"{path}.{key}" if path else key
            if key not in old:
                yield f"added:{here}"
            elif key not in new:
                yield f"removed:{here}"
            else:
                yield from diff_paths(old[key], new[key], here)
    elif old != new:
        yield f"changed:{path}"

before_freeze = parsed(OUT.parent / "acceptance_integration/before_freeze.json")
before_manifest = parsed(OUT.parent / "acceptance_integration/before/evidence_manifest.json")
author_path = OUT.parent / "taxonomy_fix_r3/evidence_manifest.json"
review_path = OUT.parent / "independent_review_r3/manifest.json"
author = parsed(author_path)
review = parsed(review_path)

targets = [
    "docs/implementation/UP2-00E0-BOUND-INPUT/acceptance.md",
    "docs/implementation/UP2-00E0-BOUND-INPUT/evidence_manifest.json",
    "docs/v4_multitopology_generation/README.md",
    "docs/v4_multitopology_generation/16_execution_work_orders.md",
    "docs/implementation/README.md",
]
target_hashes = {rel: {"sha256": sha(ROOT / rel), "bytes": (ROOT / rel).stat().st_size} for rel in targets}
before_hashes = {str(item["path"]).replace("\\", "/"): {"sha256": item["sha256"], "bytes": item["bytes"]} for item in before_freeze["files"]}

frozen_checks = {}
for field in ("source", "test", "runner", "fixture"):
    rel = author["snapshot"][f"{field}_path"]
    expected = author["snapshot"][f"{field}_sha256"]
    actual = sha(ROOT / rel)
    frozen_checks[rel] = {"expected": expected, "actual": actual, "match": expected == actual}
for label, path, expected in [
    ("author_r10_manifest", author_path, "7b5bf78dacf7a7abcbf78639495c4ad4ca2d7d6a4cc5a2f61c52894b93b213e5"),
    ("independent_r3_manifest", review_path, "de4937a6c4c80b8640c39a593872d86592b1862c689fa894b0c0d726b00be5c1"),
]:
    actual = sha(path)
    frozen_checks[label] = {"expected": expected, "actual": actual, "match": expected == actual}

acceptance = (ROOT / targets[0]).read_text(encoding="utf-8")
acceptance_before = (OUT.parent / "acceptance_integration/before/acceptance.md").read_text(encoding="utf-8")
old_status = "Status: `review_pending`; `accepted=false`."
new_status = "Status: `accepted_limited`; `accepted=true`."
without_addendum = acceptance.split("\n## E0-INT limited acceptance addendum", 1)[0] + "\n"
without_addendum = acceptance.split("\n## E0-INT limited acceptance addendum", 1)[0].rstrip("\n") + "\n"
acceptance_projection_ok = without_addendum.replace(new_status, old_status, 1) == acceptance_before

readme_suffix = ("UP2-00E0 E0 integration is accepted_limited only for actual CandidateStatePackageV5 "
                 "bound-input source identity and exception-taxonomy software behavior, after independent "
                 "R3 pass_limited review. The original package hash remains unchanged; candidate, ref, "
                 "component-hash, and version-axis joins are source-bound, while N05 and N06 remain "
                 "separate terminal_deferred gaps. This does not accept N05/N06 declarations, UP2 total, "
                 "the 50 formal B04 receipts, B00/B04, provider, mesh, engineering, physical, or R01-R10 "
                 "evidence. See ../implementation/UP2-00E0-BOUND-INPUT/acceptance.md and its "
                 "independent_review_r3/manifest.json.\n")
work_suffix = ("\nUP2-00E0 E0 integration status: accepted_limited after independent R3 pass_limited, "
               "restricted to actual CandidateStatePackageV5 bound-input source identity and "
               "exception-taxonomy software. N05/N06 declarations remain deferred to E1/E2; UP2 "
               "total, UP1-04B, all 50 formal B04 receipts/checker/two-process replay, B00/B04, "
               "provider, mesh, engineering, physical, and R01-R10 remain pending or unaccepted.\n")
readme_current = (ROOT / targets[2]).read_text(encoding="utf-8")
work_current = (ROOT / targets[3]).read_text(encoding="utf-8")
work_before = (OUT.parent / "acceptance_integration/before/16_execution_work_orders.md").read_text(encoding="utf-8")
readme_pre = readme_current[:-len(readme_suffix)] if readme_current.endswith(readme_suffix) else ""
readme_before_freeze = before_hashes[targets[2]]
readme_prefix_bytes = readme_pre.encode("utf-8")
readme_normalized_before = readme_prefix_bytes[:-1]
readme_restored_before = readme_normalized_before[:-1] + b"\r\n"
readme_projection_ok = readme_current.endswith(readme_suffix) and {
    "sha256": hashlib.sha256(readme_restored_before).hexdigest(),
    "bytes": len(readme_restored_before),
} == readme_before_freeze
work_projection_ok = work_current.startswith(work_before) and work_current[len(work_before):] == work_suffix

manifest_changes = list(diff_paths(before_manifest, parsed(ROOT / targets[1])))
allowed_manifest_paths = {
    "status", "accepted", "scope", "accepted_scope", "acceptance_record", "author_r10_reference",
    "claims.exception_taxonomy_software", "claims.UP2_total", "claims.UP1_04B", "review.independent_luna",
    "review.verdict", "review.manifest_path", "review.manifest_sha256", "review.report_path", "review.r3_exit",
    "review.r3_counts", "review.sol_decision", "review.historical_review_states", "review.notes",
    "review.status_ceiling", "integration",
}
unexpected_manifest_changes = [item for item in manifest_changes if item.split(":", 1)[1] not in allowed_manifest_paths]

r7_sentence = "r7 is the current software execution receipt."
r7_qualification = "earlier sentence that independent review was required is retained as historical r7 draft state"
r7_satisfied = "E0-INT records that requirement as satisfied by the independent R3 pass_limited review"
r7_sole = "r7 is the only" in acceptance or "r7 is the sole" in acceptance
r7_ambiguity_resolved = all([r7_sentence in acceptance, r7_qualification in acceptance, r7_satisfied in acceptance, not r7_sole])

json_paths = [
    ROOT / targets[1], OUT.parent / "acceptance_integration/before_freeze.json",
    OUT.parent / "acceptance_integration/after_hashes.json", OUT.parent / "acceptance_integration/final_hashes.json",
    author_path, review_path,
]
json_parse = []
for path in json_paths:
    try:
        parsed(path)
        json_parse.append({"path": str(path.relative_to(ROOT)), "ok": True})
    except Exception as exc:
        json_parse.append({"path": str(path.relative_to(ROOT)), "ok": False, "error": repr(exc)})

control_scan = []
for path in [ROOT / rel for rel in targets] + [author_path, review_path]:
    text = path.read_text(encoding="utf-8")
    bad = [(idx, ord(ch)) for idx, ch in enumerate(text) if ord(ch) < 32 and ch not in "\r\n\t"]
    control_scan.append({"path": str(path.relative_to(ROOT)), "bad_control_count": len(bad), "first_bad": bad[:5]})

receipts = [
    run(["python", "docs/v4_multitopology_generation/validate_plan.py"]),
    run(["git", "diff", "--check"]),
    run(["powershell", "-NoProfile", "-Command", "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)' } | Select-Object Name,ProcessId,ParentProcessId | ConvertTo-Json -Compress"]),
]
current = parsed(ROOT / targets[1])
required_false = {key: current["claims"].get(key) for key in ["n05_n06_declarations", "UP2_total", "UP1_04B", "B00", "B04", "provider", "mesh", "engineering", "physical", "R01_R10"]}
claims_ok = all(value is False for value in required_false.values())
impl_suffix = ("UP2-00E0 E0 is accepted_limited only for actual CandidateStatePackageV5 bound-input source identity and "
               "exception-taxonomy software behavior, with independent R3 pass_limited evidence. N05/N06, UP2 total, "
               "the 50 formal B04 receipts, B00/B04, provider, mesh, engineering, physical, and R01-R10 remain unaccepted. "
               "See UP2-00E0-BOUND-INPUT/acceptance.md and independent_review_r3/manifest.json.\n")
impl_current_bytes = (ROOT / targets[4]).read_bytes()
impl_suffix_bytes = impl_suffix.encode("utf-8")
impl_prefix_bytes = impl_current_bytes[:-len(impl_suffix_bytes)] if impl_current_bytes.endswith(impl_suffix_bytes) else b""
impl_normalized_before = impl_prefix_bytes[:-1]
impl_restored_before = impl_normalized_before[:-1] + b"\r\n"
impl_readme_suffix_ok = impl_current_bytes.endswith(impl_suffix_bytes) and impl_restored_before == (OUT.parent / "acceptance_integration/before/README.md").read_bytes()

all_checks = [
    acceptance_projection_ok, readme_projection_ok, work_projection_ok, impl_readme_suffix_ok,
    not unexpected_manifest_changes, all(item["ok"] for item in json_parse),
    all(item["bad_control_count"] == 0 for item in control_scan), all(item["match"] for item in frozen_checks.values()),
    receipts[0]["exit_code"] == 0, receipts[1]["exit_code"] == 0,
    receipts[2]["exit_code"] == 0 and not receipts[2]["stdout"].strip(), claims_ok, r7_ambiguity_resolved,
]
report = {
    "record_kind": "UP2-00E0-E0-INT-independent-integration-QA",
    "captured_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
    "verdict": "pass_limited" if all(all_checks) else "changes_requested",
    "scope": "read-only E0-INT documentation integration and provenance QA",
    "limitations": [
        "No Julia or DESC process was started; process inspection was read-only.",
        "The integrator before/README.md is the implementation README snapshot; the core v4 README had no content snapshot, so its before_freeze hash was checked by restoring the one CRLF lost when the integrator rewrote the old text with LF.",
        "This contract/provenance review grants no N05/N06 declaration, UP2 total, B00/B04, provider, mesh, engineering, physical, or R01-R10 credit.",
    ],
    "target_hashes": target_hashes, "before_freeze_target_hashes": before_hashes,
    "frozen_source_test_fixture_runner_and_manifest_checks": frozen_checks,
    "target_projection_checks": {
        "acceptance_md_reconstructs_before_after_status_and_addendum_removal": acceptance_projection_ok,
        "v4_readme_is_before_plus_exact_e0_index_suffix": readme_projection_ok,
        "work_orders_is_before_plus_exact_e0_status_suffix": work_projection_ok,
        "implementation_readme_is_before_snapshot_plus_exact_e0_index_suffix": impl_readme_suffix_ok,
        "manifest_changed_paths": manifest_changes, "unexpected_manifest_changes": unexpected_manifest_changes,
    },
    "r7_ambiguity_check": {
        "current_sentence_present": r7_sentence in acceptance,
        "historical_r7_draft_qualification_present": r7_qualification in acceptance,
        "review_requirement_satisfied_present": r7_satisfied in acceptance,
        "sole_execution_claim_present": r7_sole,
        "substantive_ambiguity_resolved": r7_ambiguity_resolved,
        "assessment": "The preserved r7 sentence is explicitly qualified by the E0-INT addendum as historical r7 draft wording; the addendum records author r10 and independent R3 evidence, so a reader is not left with a sole-execution or unmet-review claim.",
    },
    "claims": {"required_false": required_false, "claim_ceiling_ok": claims_ok},
    "json_parse": json_parse, "control_scan": control_scan, "command_receipts": receipts,
}
(OUT / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
(OUT / "command_receipts.json").write_text(json.dumps(receipts, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
print(json.dumps({"verdict": report["verdict"], "validate_plan_exit": receipts[0]["exit_code"], "git_diff_check_exit": receipts[1]["exit_code"], "json_ok": all(item["ok"] for item in json_parse), "control_scan_ok": all(item["bad_control_count"] == 0 for item in control_scan), "frozen_hashes_ok": all(item["match"] for item in frozen_checks.values()), "process_empty": not receipts[2]["stdout"].strip(), "r7_ambiguity_resolved": r7_ambiguity_resolved}, ensure_ascii=False))
