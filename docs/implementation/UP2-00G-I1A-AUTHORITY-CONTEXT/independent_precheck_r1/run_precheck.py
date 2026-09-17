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
WORKORDERS = REPO / "docs/v4_multitopology_generation/16_execution_work_orders.md"
PLAN_VALIDATOR = REPO / "docs/v4_multitopology_generation/validate_plan.py"

FROZEN = {
    "src/GenomeV5/UP2/GI1AuthorityContextV1.jl": "dc976dedd0f01aab13b7b17bd6a9e17aeacd5d272d2957659b97331b99c2903b",
    "test/GenomeV5/UP2/gi1_authority_context_fixtures.json": "7c0793f42e01feac522c428cad7b7522a9517dc19922e67215dac4ea0dc3bf2c",
    "test/GenomeV5/UP2/gi1_authority_context_tests.jl": "4be356e86a72cbf5f2fd31b6f1da57b1e11c052f31beab788354cd5c94d6d1a8",
    "test/GenomeV5/UP2/run_gi1_authority_context.jl": "20d01f6ee0ceb7a7bf11c160a4257224ceee61c50ff229dca62303efa0658ff6",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def line_evidence(text: str, needles: list[str]) -> list[dict]:
    rows = []
    for number, line in enumerate(text.splitlines(), 1):
        if any(needle in line for needle in needles):
            rows.append({"line": number, "text": line})
    return rows


def run_command(command: list[str], *, cwd: Path = REPO) -> dict:
    started = datetime.now(timezone.utc).isoformat()
    proc = subprocess.run(command, cwd=cwd, capture_output=True)
    ended = datetime.now(timezone.utc).isoformat()
    stdout_bytes = proc.stdout or b""
    stderr_bytes = proc.stderr or b""
    stdout = stdout_bytes.decode("utf-8", errors="replace")
    stderr = stderr_bytes.decode("utf-8", errors="replace")
    return {
        "command": command,
        "started_utc": started,
        "ended_utc": ended,
        "exit": proc.returncode,
        "stdout": stdout,
        "stderr": stderr,
        "stdout_sha256": hashlib.sha256(stdout_bytes).hexdigest(),
        "stderr_sha256": hashlib.sha256(stderr_bytes).hexdigest(),
    }


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    source = SRC.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture_text = FIXTURE.read_text(encoding="utf-8")
    fixture = json.loads(fixture_text)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    ad26_text = AD26.read_text(encoding="utf-8")
    workorders_text = WORKORDERS.read_text(encoding="utf-8")

    current = {key: sha256(REPO / key) for key in FROZEN}
    hash_checks = {key: {"expected": expected, "actual": current[key], "match": expected == current[key]}
                   for key, expected in FROZEN.items()}
    manifest_owned_after = manifest.get("owned_after_hashes", {})
    manifest_match = {key: current[key] == manifest_owned_after.get(key) for key in FROZEN}
    protected_input_checks = {}
    for key, expected in manifest.get("input_hashes", {}).items():
        path = REPO / key
        if path.exists():
            protected_input_checks[key] = {"expected": expected, "actual": sha256(path), "match": expected == sha256(path)}
        else:
            protected_input_checks[key] = {"expected": expected, "actual": None, "match": False, "missing": True}

    # These are static structural checks.  A false result is evidence of a source
    # contract gap; no implementation is modified by this script.
    has_context_metadata = all(token in source for token in (
        "context_version", "schema_hash", "canonicalization_hash", "compatibility_profile_hash"))
    context_body_metadata = all(token in source[source.find("function _gi1_context_body"):source.find("semantic_view(x::GI1AuthorityContextV1)")]
                               for token in ("schema_hash", "canonicalization_hash", "compatibility_profile_hash"))
    slot_metadata = all(token in source for token in ("schema_hash::Digest256", "canonicalization_hash::Digest256", "profile_hash::Digest256", "content_hash::Digest256"))
    required_admission = {":declared_consistent", ":fail_closed", ":terminal_deferred", ":program_exception"}
    admission_enum = {token: token in source for token in required_admission}
    has_forbidden_contract_ready = ":contract_ready" in source
    validator_signature = "function gi1_validate_authority_context(context::GI1AuthorityContextV1)" in source
    validator_start = source.find("function gi1_validate_authority_context")
    validator_body = source[validator_start:] if validator_start >= 0 else ""
    validator_trusted_calls = {token: token in validator_body for token in (
        "up2e0_validate_binding", "up2e0_check_package", "up2n05_validate", "n06_mapping_admission")}
    factory_trusted_calls = {token: token in source for token in (
        "up2e0_validate_binding", "up2e0_check_package", "up2n05_validate", "n06_mapping_admission")}
    positional_slot_binding = ("_gi1_check_slot(e1" in source and "slot === :E1" in source and
                               "_gi1_check_slot(e2" in source and "slot === :E2" in source)
    unknown_exception_wrapped = "throw(ErrorException(\"GI1 N06 authority program_exception" in source
    factory_start = source.find("function gi1_authority_context_from_a")
    validator_marker = source.find("function gi1_validate_authority_context", factory_start)
    factory_body = source[factory_start:validator_marker] if factory_start >= 0 and validator_marker >= 0 else ""
    factory_typed_program_exception = "status=:program_exception" in factory_body or "contract_admission=:program_exception" in factory_body
    admission_factory = line_evidence(source, ["admission =", ":contract_ready :terminal_deferred"])
    context_body = source[source.find("function _gi1_context_body"):source.find("semantic_view(x::GI1AuthorityContextV1)")]
    identity_inputs = {token: token in context_body for token in (
        "candidate_ref", "package_hash", "e0_binding", "e1=x.e1", "e2=x.e2", "version_axes", "contract_admission")}
    has_e2_present_type = "GI1N06PresentAuthoritySlotV1" in source or "E2Present" in source
    absent_slot_check = line_evidence(source, ["slot in (:E1, :E2)", "_gi1_check_slot(e1", "_gi1_check_slot(e2"])
    exception_taxonomy = {
        "validator_maps_non_argument_error_to_program_exception": "err isa ArgumentError || return (status=:program_exception" in source,
        "e2_absent_rethrows_unknown_as_error_exception": unknown_exception_wrapped,
        "factory_returns_typed_program_exception_state": factory_typed_program_exception,
    }

    case_ids = [str(case.get("id")) for case in fixture.get("cases", [])]
    testset_count = test.count('@testset "')
    mutation_terms = ["candidate", "package_hash", "g1_ref", "g2_ref", "g3_ref", "version_axes",
                      "slot", "schema_hash", "canonicalization_hash", "profile_hash", "content_hash"]
    mutation_coverage = {term: term in test for term in mutation_terms}
    commands = [
        run_command([sys.executable, str(PLAN_VALIDATOR)]),
        run_command([sys.executable, "-c", "import json, pathlib; root=pathlib.Path('.'); files=list(root.glob('docs/implementation/UP2-00G-I1A-AUTHORITY-CONTEXT/*.json'))+list(root.glob('docs/implementation/UP2-00G-I1A-AUTHORITY-CONTEXT/independent_precheck_r1/*.json')); [json.loads(p.read_text(encoding='utf-8')) for p in files]; print('json_parse_ok', len(files))"]),
        run_command(["git", "diff", "--check"]),
        run_command(["powershell", "-NoProfile", "-Command",
                     "$p=Get-Process -Name julia,DESC -ErrorAction SilentlyContinue; if ($null -eq $p) { '[]' } else { $p | Select-Object Id,ProcessName | ConvertTo-Json -Compress }"]),
    ]
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2), encoding="utf-8")

    checks = {
        "frozen_hashes": all(x["match"] for x in hash_checks.values()),
        "manifest_owned_after_matches": all(manifest_match.values()),
        "protected_input_hashes": all(x["match"] for x in protected_input_checks.values()),
        "ad26_required_contract_terms": all(term in ad26_text for term in (
            "declared_consistent", "fail_closed", "terminal_deferred", "program_exception",
            "compatibility_profile_hash", "same-candidate", "G-I2", "UP1-04B")),
        "work_order_mentions_g_i1": "G-I1" in workorders_text,
        "slot_metadata_present": slot_metadata,
        "context_metadata_explicit": has_context_metadata and context_body_metadata,
        "admission_enum_ad26": all(admission_enum.values()) and not has_forbidden_contract_ready,
        "validator_trusted_actual_binding": validator_signature and all(validator_trusted_calls.values()),
        "factory_trusted_actual_binding": all(factory_trusted_calls.values()),
        "positional_e1_e2_slot_binding": positional_slot_binding,
        "typed_program_exception_factory": exception_taxonomy["factory_returns_typed_program_exception_state"],
        "identity_body_contains_core_inputs": all(identity_inputs.values()),
        "test_matrix_sufficient": testset_count >= 6 and all(mutation_coverage.values()),
        "e2_present_slot_type_or_explicit_scope": has_e2_present_type,
        "fixture_has_actual_and_negative_cases": len(case_ids) >= 5 and "actual_a_e1_present_e2_absent" in case_ids and "actual_a_e1_absent_e2_absent" in case_ids,
    }

    blockers = [
        {"id": "GI1A-01", "check": "context_metadata_explicit", "detail": "GI1AuthorityContextV1/_gi1_context_body has no explicit top-level context_version, schema_hash, canonicalization_hash, or compatibility_profile_hash. Nested slots carry schema_hash/canonicalization_hash/profile_hash, but profile_hash is not an explicit GI1 compatibility_profile_hash and does not satisfy the context-level AD-26 field requirement.", "evidence": line_evidence(source, ["struct GI1AuthorityContextV1", "function _gi1_context_body", "context_hash"])},
        {"id": "GI1A-02", "check": "admission_enum_ad26", "detail": "Constructor and factory use :contract_ready/:terminal_deferred/:fail_closed; AD-26 requires declared_consistent/fail_closed/terminal_deferred/program_exception.", "evidence": line_evidence(source, ["contract_admission in", "admission =", "contract_admission=admission"])},
        {"id": "GI1A-03", "check": "validator_trusted_actual_binding", "detail": "gi1_validate_authority_context accepts only a context and checks self-consistency; it has no trusted package/E0/E1/E2 inputs or source validation, so a forged internally coherent context can pass.", "evidence": line_evidence(source, ["function gi1_validate_authority_context", "_gi1_validate_context_identity", "status=:valid"])},
        {"id": "GI1A-04", "check": "positional_e1_e2_slot_binding", "detail": "The constructor calls the same checker for e1 and e2, while the absent branch only accepts slot in (:E1,:E2); swapped absent slots are not rejected.", "evidence": absent_slot_check},
        {"id": "GI1A-05", "check": "typed_program_exception_factory", "detail": "_gi1_e2_absent converts unknown errors to ErrorException and the factory propagates them; no typed program_exception context/admission is constructed. Validator classification alone cannot repair factory taxonomy.", "evidence": line_evidence(source, ["catch err", "program_exception", "function gi1_authority_context_from_a"])},
        {"id": "GI1A-06", "check": "test_matrix_sufficient", "detail": f"Tests contain {testset_count} testsets and fixture cases {case_ids}; they omit systematic candidate/ref/hash/axis/slot/schema/canonical/profile/content mutations and trusted validator binding.", "evidence": line_evidence(test, ["@testset", "@test_throws", "gi1_validate_authority_context"])},
        {"id": "GI1A-07", "check": "e2_present_slot_type_or_explicit_scope", "detail": "Only GI1N05PresentAuthoritySlotV1 (hard-coded E1) and generic absent slots exist; no typed E2-present slot. Scope must explicitly defer E2-present to a later work order or add the typed slot with independent metadata.", "evidence": line_evidence(source, ["struct GI1N05PresentAuthoritySlotV1", "GI1AbsentAuthoritySlotV1"])},
    ]
    blockers = [b for b in blockers if not checks[b["check"]]]
    verdict = "changes_requested" if blockers else "ready_for_focused_r1"
    report = {
        "schema_version": "independent-precheck-r1-v1",
        "reviewer": "Luna/high independent reviewer",
        "verdict": verdict,
        "runtime": {"julia": "not_run", "desc": "not_run", "reason": "static precheck only"},
        "frozen_inputs": {"owned_files": FROZEN, "current_hashes": current, "manifest_owned_after": manifest_owned_after},
        "hash_checks": hash_checks,
        "manifest_owned_after_checks": manifest_match,
        "protected_input_checks": protected_input_checks,
        "checks": checks,
        "admission_enum": admission_enum,
        "context_identity_inputs": identity_inputs,
        "validator_trusted_calls": validator_trusted_calls,
        "factory_trusted_calls": factory_trusted_calls,
        "exception_taxonomy": exception_taxonomy,
        "mutation_coverage": mutation_coverage,
        "fixture_case_ids": case_ids,
        "testset_count": testset_count,
        "blockers": blockers,
        "command_receipts": "command_receipts.json",
        "limitations": [
            "No Julia or DESC process was started by this review.",
            "This is a static precheck, not focused runtime acceptance.",
            "AD-26/core18 and source/test inputs are frozen only for this snapshot; any author change invalidates the result.",
            "E2-present is called out as an explicit scope gap; no B04, provider, mesh, engineering, physical, UP2-total, or R01-R10 credit is granted.",
        ],
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    evidence = {
        "schema_version": "independent-precheck-r1-evidence-v1",
        "report_sha256": sha256(OUT / "report.json"),
        "source_sha256": current["src/GenomeV5/UP2/GI1AuthorityContextV1.jl"],
        "test_sha256": current["test/GenomeV5/UP2/gi1_authority_context_tests.jl"],
        "fixture_sha256": current["test/GenomeV5/UP2/gi1_authority_context_fixtures.json"],
        "runner_sha256": current["test/GenomeV5/UP2/run_gi1_authority_context.jl"],
        "command_receipts_sha256": sha256(OUT / "command_receipts.json"),
        "verdict": verdict,
        "claim_ceiling": "none",
        "julia": False,
        "desc": False,
    }
    (OUT / "evidence_manifest.json").write_text(json.dumps(evidence, indent=2), encoding="utf-8")
    md = [
        "# G-I1A independent static precheck R1",
        "",
        f"Verdict: **{verdict}**.",
        "",
        "This is a different-Luna, read-only static precheck. Julia/DESC were not run and no implementation, test, or core document was changed.",
        "",
        "## Frozen inputs",
        "",
        *(f"- `{key}` SHA-256 `{value}`" for key, value in FROZEN.items()),
        "",
        "## Blocking findings",
        "",
    ]
    for blocker in blockers:
        md.append(f"- **{blocker['id']} ({blocker['check']})** {blocker['detail']}")
        for ev in blocker["evidence"][:6]:
            md.append(f"  - source evidence line {ev['line']}: `{ev['text']}`")
    md += [
        "",
        "## Boundary",
        "",
        "Factory source binding to actual A/E0/E1/E2 paths is present, but the public validator is self-consistency-only. The local typed context is therefore not ready for focused runtime until the blockers are repaired and independently rechecked. No B04, provider, mesh, engineering, physical, UP2-total, or R01-R10 credit is granted.",
        "",
        "QA receipts are in `command_receipts.json`; `report.json` and `evidence_manifest.json` carry the re-computable hashes and exits.",
    ]
    (OUT / "report.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verdict, "blockers": [b["id"] for b in blockers], "output": str(OUT)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
