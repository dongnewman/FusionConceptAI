from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


REPO = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
SRC = REPO / "src/GenomeV5/UP2/GI1AuthorityContextV1.jl"
TEST = REPO / "test/GenomeV5/UP2/gi1_authority_context_tests.jl"
FIXTURE = REPO / "test/GenomeV5/UP2/gi1_authority_context_fixtures.json"
RUNNER = REPO / "test/GenomeV5/UP2/run_gi1_authority_context.jl"
MANIFEST = REPO / "docs/implementation/UP2-00G-I1A-AUTHORITY-CONTEXT/evidence_manifest.json"
AD26 = REPO / "docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def evidence(text: str, needles: list[str]) -> list[dict]:
    return [{"line": i, "text": line} for i, line in enumerate(text.splitlines(), 1)
            if any(n in line for n in needles)]


def run_command(command: list[str]) -> dict:
    started = datetime.now(timezone.utc).isoformat()
    p = subprocess.run(command, cwd=REPO, capture_output=True)
    ended = datetime.now(timezone.utc).isoformat()
    stdout = p.stdout or b""
    stderr = p.stderr or b""
    return {
        "command": command,
        "started_utc": started,
        "ended_utc": ended,
        "exit": p.returncode,
        "stdout": stdout.decode("utf-8", errors="replace"),
        "stderr": stderr.decode("utf-8", errors="replace"),
        "stdout_sha256": hashlib.sha256(stdout).hexdigest(),
        "stderr_sha256": hashlib.sha256(stderr).hexdigest(),
    }


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    source = SRC.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture_text = FIXTURE.read_text(encoding="utf-8")
    fixture = json.loads(fixture_text)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    ad26_text = AD26.read_text(encoding="utf-8")

    owned = manifest["owned_files"]
    owned_checks = {key: {"expected": expected, "actual": sha256(REPO / key), "match": expected == sha256(REPO / key)}
                    for key, expected in owned.items()}
    input_checks = {}
    for key, expected in manifest.get("input_hashes", {}).items():
        path = REPO / key
        actual = sha256(path) if path.exists() else None
        input_checks[key] = {"expected": expected, "actual": actual, "match": actual == expected}

    # R3 source checks are deliberately independent of the author's static QA.
    source_checks = {
        "explicit_context_metadata": all(token in source for token in (
            "context_version::String", "schema_hash::Digest256",
            "canonicalization_hash::Digest256", "compatibility_profile_hash::Digest256",
            "context_version=x.context_version", "compatibility_profile_hash=x.compatibility_profile_hash")),
        "slot_position_and_metadata": all(token in source for token in (
            "slot.slot === expected_slot", "compatibility_profile_hash == slot.profile_hash",
            "_gi1_check_slot(e1, :E1", "_gi1_check_slot(e2, :E2")),
        "n06_present_content_hash": all(token in source for token in (
            "struct GI1N06PresentAuthoritySlotV1", "mapping::N06SourceFieldLedgerMappingV1",
            "_gi1_n06_present_body", "mapping.mapping_hash == _n06_mapping_hash(slot.mapping)",
            "GI1N06PresentAuthoritySlotV1(:E2")),
        "n06_mapping_source_admission": all(token in source for token in (
            "n06_mapping_admission(package, e0, n06)", "n06_mapping_admission(package, e0)",
            "n06 === nothing", "admission.status === :terminal_deferred")),
        "n06_absent_present_exclusive": "n06 === nothing && begin" in source and "return (absent, :terminal_deferred" in source and "return (_gi1_make_n06_present" in source,
        "physical_ceiling": "physical_resolution == terminal_deferred" in source and "compile_calls == 0" in source and "provider_calls == 0" in source and "solver_calls == 0" in source,
        "status_error_mutual_exclusion": all(token in source for token in (
            "if package_structural_status === :valid", "isempty(errors) ||",
            "elseif package_structural_status === :fail_closed", "!isempty(errors) ||")),
        "trusted_actual_factory": all(token in source for token in (
            "up2e0_validate_binding(e0, package)", "up2e0_check_package(package)",
            "up2n05_validate(n05, package, e0)", "gi1_authority_context_from_a(package, e0")),
    }
    # This exact predicate is the R3 admission defect: it ignores e2_admission.
    admission_block = source[source.find("gaps = unique"):source.find("body = (", source.find("gaps = unique"))]
    admission_uses_status = "e2_admission" in admission_block and "e2_admission === :terminal_deferred" in admission_block
    source_checks["admission_respects_e2_status"] = admission_uses_status

    # N05 and E0 program_exception paths currently collapse status != valid to
    # ArgumentError.  Preserve this as a separate exact blocker.
    n05_factory_block = source[source.find("n05 === nothing ||"):source.find("e1 =", source.find("n05 === nothing ||"))]
    source_checks["n05_program_exception_preserved"] = (
        "n05_check.status === :program_exception" in n05_factory_block and
        "status=:program_exception" in n05_factory_block)
    source_checks["factory_program_exception_typed_or_preserved"] = (
        source_checks["n05_program_exception_preserved"] and
        "e0_check.status === :program_exception" in source[source.find("function gi1_authority_context_from_a"):source.find("package_check =")]
    )

    # Test coverage: fixture labels, branches, explicit mapping, program exception,
    # and deferred-present admission are checked for actual executable references.
    fixture_ids = [str(x.get("id")) for x in fixture.get("cases", [])]
    tests = {
        "constructor_branch_controls": all(token in test for token in (
            "status branches and explicit N06 boundary", ":valid", ":fail_closed", "unexpected_error")),
        "trusted_validator_controls": "gi1_validate_authority_context(context, package, e0" in test,
        "slot_metadata_controls": all(token in test for token in (
            "tampered_context_metadata", "swapped_slots", "foreign_component_hash", "foreign_axis")),
        "invalid_n06_control": "n06=bad_n06" in test and "invalid_e2_present" in test,
        "program_exception_control": ":program_exception" in test or "program_exception" in fixture_text,
        "explicit_valid_or_deferred_n06_present_control": (
            "n06_mapping_from_a" in test or "GI1N06PresentAuthoritySlotV1(" in test),
        "deferred_present_admission_assertion": (
            "e2_admission" in test or "GI1N06PresentAuthoritySlotV1" in test and ":terminal_deferred" in test),
    }

    commands = [
        run_command([sys.executable, str(REPO / "docs/v4_multitopology_generation/validate_plan.py")]),
        run_command([sys.executable, "-c", "import json, pathlib; root=pathlib.Path('docs/implementation/UP2-00G-I1A-AUTHORITY-CONTEXT'); files=list(root.glob('*.json'))+list(root.glob('repair_r3/*.json'))+list(root.glob('independent_precheck_r1/*.json'))+list(root.glob('independent_precheck_r2/*.json'))+list(root.glob('independent_precheck_r3/*.json')); [json.loads(p.read_text(encoding='utf-8')) for p in files]; print('json_parse_ok', len(files))"]),
        run_command(["git", "diff", "--check"]),
        run_command(["powershell", "-NoProfile", "-Command", "$p=Get-Process -Name julia,DESC -ErrorAction SilentlyContinue; if ($null -eq $p) { '[]' } else { $p | Select-Object Id,ProcessName | ConvertTo-Json -Compress }"]),
    ]
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2), encoding="utf-8")

    blockers = []
    if not all(x["match"] for x in owned_checks.values()):
        blockers.append({"id": "GI1A-R3-01", "detail": "Current R3 owned source/test/fixture/runner hashes do not match the frozen manifest.", "evidence": owned_checks})
    if not all(x["match"] for x in input_checks.values()):
        blockers.append({"id": "GI1A-R3-02", "detail": "Protected actual-A/E0/E1/E2 input hashes drifted.", "evidence": input_checks})
    if not source_checks["status_error_mutual_exclusion"]:
        blockers.append({"id": "GI1A-R3-03", "detail": "Constructor status/error branches are not mutually exclusive.", "evidence": evidence(source, ["package_structural_status === :valid", "package_structural_status === :fail_closed"])})
    if not source_checks["admission_respects_e2_status"]:
        blockers.append({"id": "GI1A-R3-04", "detail": "Factory contract_admission is selected only from E1/E2 slot types and ignores e2_admission; an E2 typed-present mapping with terminal_deferred admission is incorrectly promoted to declared_consistent. Minimal fix: require e2_admission == :declared_consistent for declared_consistent, otherwise retain terminal_deferred.", "evidence": evidence(source, ["e2, e2_admission, e2_gaps", "admission = e1 isa", "contract_admission=admission"])})
    if not source_checks["n05_program_exception_preserved"]:
        blockers.append({"id": "GI1A-R3-05", "detail": "Factory maps every n05_check status other than valid to ArgumentError; n05_check.status == :program_exception is therefore misclassified as fail_closed instead of retaining program_exception. Minimal fix: branch program_exception before the fail_closed ArgumentError path and preserve that taxonomy through the trusted API.", "evidence": evidence(source, ["n05_check.status === :valid", "GI1 E1 source fail_closed", "n05_check.status === :program_exception"])})
    if not all(tests[key] for key in ("explicit_valid_or_deferred_n06_present_control", "deferred_present_admission_assertion", "program_exception_control")):
        blockers.append({"id": "GI1A-R3-06", "detail": "R3 tests do not execute the explicit N06 typed-present/deferred branch and do not directly test exception taxonomy; the current-A baseline has no valid N06 mapping positive. Minimal fix: add a structurally valid source-bound mapping fixture only to exercise typed E2-present plus terminal_deferred, and add targeted program_exception classification controls without claiming a physical positive.", "evidence": {"fixture_ids": fixture_ids, "tests": tests}})
    if not source_checks["n06_present_content_hash"] or not source_checks["n06_mapping_source_admission"]:
        blockers.append({"id": "GI1A-R3-07", "detail": "Explicit N06 mapping is not source-bound/content-hashed at the slot boundary.", "evidence": evidence(source, ["_gi1_e2_slot", "mapping.mapping_hash", "n06_mapping_admission"])})

    verdict = "changes_requested" if blockers else "ready_for_focused"
    report = {
        "schema_version": "GI1A-independent-precheck-r3-v1",
        "reviewer": "Luna/high different-author static reviewer",
        "verdict": verdict,
        "runtime": {"julia": "not_run", "desc": "not_run", "reason": "static precheck only"},
        "frozen_owned_checks": owned_checks,
        "protected_input_checks": input_checks,
        "source_checks": source_checks,
        "test_checks": tests,
        "fixture_ids": fixture_ids,
        "blockers": blockers,
        "ad26_ceiling": {
            "contract_admission": ["declared_consistent", "fail_closed", "terminal_deferred", "program_exception"],
            "physical_resolution": "unknown_or_terminal_deferred",
            "no_credit": ["UP2 total", "B00", "B04", "provider", "mesh", "engineering", "physical", "R01-R10"],
            "ad26_terms_present": all(token in ad26_text for token in ("declared_consistent", "program_exception", "compatibility_profile_hash")),
        },
        "command_receipts": "command_receipts.json",
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    manifest_out = {
        "schema_version": "GI1A-independent-precheck-r3-evidence-v1",
        "report_sha256": sha256(OUT / "report.json"),
        "source_sha256": sha256(SRC),
        "test_sha256": sha256(TEST),
        "fixture_sha256": sha256(FIXTURE),
        "runner_sha256": sha256(RUNNER),
        "command_receipts_sha256": sha256(OUT / "command_receipts.json"),
        "verdict": verdict,
        "julia": False,
        "desc": False,
        "claim_ceiling": "none",
    }
    (OUT / "evidence_manifest.json").write_text(json.dumps(manifest_out, indent=2), encoding="utf-8")
    md = [
        "# G-I1A independent static precheck R3",
        "",
        f"Verdict: **{verdict}**.",
        "",
        "This review is independent of the G-I1A author and preserves R1/R2 archives. It is static only: Julia/DESC were not run and no source, test, or core file was changed.",
        "",
        "## Frozen hashes",
        "",
        *(f"- `{key}` SHA-256 `{sha256(REPO / key)}`" for key in owned),
        "",
        "## Findings",
        "",
    ]
    for blocker in blockers:
        md.append(f"- **{blocker['id']}** {blocker['detail']}")
        for ev in blocker.get("evidence", [])[:8] if isinstance(blocker.get("evidence"), list) else []:
            if isinstance(ev, dict) and "line" in ev:
                md.append(f"  - source/test line {ev['line']}: `{ev['text']}`")
    if not blockers:
        md.append("- No static blocker found; this result would authorize one focused runtime preparation only.")
    md += [
        "",
        "## Boundary",
        "",
        "The current A package has no valid dimensioned N06 source/field/return/heat mapping positive. A typed N06 mapping, if supplied later, must retain its mapping/content hash and may remain `terminal_deferred`; it cannot create physical/provider evidence. No UP2 total, B00, B04, provider, mesh, engineering, physical, or R01-R10 credit is granted.",
        "",
        "Command strings, UTC timestamps, real exits, stdout/stderr hashes, JSON parse, plan validation, diff check, and process sweep are in `command_receipts.json`.",
    ]
    (OUT / "report.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verdict, "blockers": [b["id"] for b in blockers], "output": str(OUT)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
