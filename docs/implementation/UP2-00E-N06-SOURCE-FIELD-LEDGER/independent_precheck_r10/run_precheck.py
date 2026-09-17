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
SRC = ROOT / "src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl"
TEST = ROOT / "test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl"
FIXTURE = ROOT / "test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json"
RUNNER = ROOT / "test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl"
LEDGER = ROOT / "docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER"

EXPECTED = {
    "src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl":
        "69bd82f040f405e55768e52af64b9b9b6d97272a2ec3988b66b7bdf21ec1128c",
    "test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl":
        "dac8c62e4ba20b45930a119649468659931eca2236cb9c5181aba101392a66ce",
    "test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json":
        "361a1777a765ed6784a1f37c02febc24c2ba5f6eed3c6a15b99333af596736b2",
    "test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl":
        "9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def run_command(name: str, args: list[str]) -> dict:
    started = utc_now()
    cp = subprocess.run(args, cwd=ROOT, text=True, capture_output=True,
                        encoding="utf-8", errors="replace")
    ended = utc_now()
    return {"name": name, "argv": args, "started_utc": started,
            "ended_utc": ended, "exit": cp.returncode,
            "stdout": cp.stdout, "stderr": cp.stderr}


def parse_hash_lines(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        parts = line.replace("\t", " ").split()
        if len(parts) >= 2 and re.fullmatch(r"[0-9a-f]{64}", parts[0]):
            out[parts[1]] = parts[0]
        elif len(parts) >= 2 and re.fullmatch(r"[0-9a-f]{64}", parts[-1]):
            out[parts[0]] = parts[-1]
    return out


def json_load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def assert_true(checks: dict, key: str, value: bool, detail: str = "") -> None:
    checks[key] = {"pass": bool(value), "detail": detail}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    source = SRC.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    checks: dict = {}

    frozen_hashes = {rel: sha256(ROOT / rel) for rel in EXPECTED}
    assert_true(checks, "frozen_input_hashes", frozen_hashes == EXPECTED,
                json.dumps(frozen_hashes, sort_keys=True))

    return_tuple = "(equation, occurrence, closure, region, patch, network, entry, g3closure, link, fields)"
    assert_true(checks, "actual_fields_returns_ten_values", source.count(return_tuple) == 1,
                "one exact ten-value return tuple; ninth=link, tenth=fields")
    projection_bind = re.compile(
        r"equation, occurrence, closure, region, patch, _, _, _, link, fields\s*=\s*_n06_actual_fields\(package\)",
        re.S)
    assert_true(checks, "projection_destructures_ten_and_retains_link", bool(projection_bind.search(source)),
                "n06_projection_from_a lines 419-420")
    join_bind = re.compile(
        r"equation, occurrence, closure, region, patch, network, entry, g3closure, link, _\s*=\s*_n06_actual_fields\(package\)",
        re.S)
    assert_true(checks, "join_helper_destructures_ten_values", bool(join_bind.search(source)),
                "_n06_join_errors lines 452-453")

    proj = source[source.index("function n06_projection_from_a"):source.index("\nend", source.index("function n06_projection_from_a"))]
    for name, needle in {
        "projection_uses_link_id": "link.link_id",
        "projection_uses_fields": "fields, gaps",
        "projection_uses_equation": "equation.equation_id",
        "projection_uses_occurrence": "occurrence.ledger_id",
        "projection_uses_closure": "closure.closure_id",
        "projection_uses_region_patch": "patch.region_id",
    }.items():
        assert_true(checks, name, needle in proj, needle)
    assert_true(checks, "projection_hash_includes_link_and_fields",
                "g3_selected_flow_link_id=link.link_id" in proj and "network=network, fields=fields" in proj,
                "canonical_hash payload contains actual selected link and fields")
    local_bindings = {
        "refs": "g1_ref, g2_ref, g3_ref = _n06_actual_refs(package)",
        "boundary_index": "boundary_index = _n06_index_for(package.g2.plan.exterior.boundary_patches",
        "boundary_locator": "boundary_locator = \"/g2/plan/exterior/boundary_patches/",
        "gaps": "gaps = (\"g1_occurrence_to_g2_boundary_exact_join_missing\"",
        "network": "network = package.g3.realization.network",
        "occurrence_key": "occurrence_key = (ledger_id=occurrence.ledger_id",
        "all_occurrence_keys": "all_occurrence_keys = Tuple((ledger_id=o.ledger_id",
        "constructor": "N06LedgerProjectionV1(package.candidate_ref, package.candidate_hash",
    }
    assert_true(checks, "projection_local_binding_audit",
                all(needle in proj for needle in local_bindings.values()),
                json.dumps(local_bindings, sort_keys=True))

    # The prior R5 typed-key and R6 selector repairs are checked directly in the
    # current source/test, rather than inferred from old reports.
    typed_patterns = [
        "ids = [id_of(x) for x in items]",
        "length(unique(ids)) == length(ids)",
        "index = Dict{Any,Any}()",
        "typed_a = (\"energy\", \"governing-0\", :output, Int64(1))",
        "typed_index[typed_a] === typed_a",
    ]
    assert_true(checks, "r5_typed_key_repair_preserved",
                all(p in source or p in test for p in typed_patterns),
                "typed tuple identity/duplicate controls remain present")
    selector_patterns = [
        "const _N06_G1_ROLE_SELECTORS",
        "const _N06_G2_SELECTOR",
        "_n06_selector_key",
        "missing_source_selector",
        "wrong_source_selector",
        "finally",
        "G1 authored governing occurrence has no source match",
    ]
    assert_true(checks, "r6_selector_repair_preserved",
                all(p in source or p in test for p in selector_patterns),
                "authored selectors, wrong/missing controls, and restoration remain present")

    # The actual positive projection regression is source/test-bound, not a
    # fixture label assertion: the test compares the projection link to the
    # ninth return element and checks the five real fields.
    positive_patterns = [
        "projection = G.n06_projection_from_a(package, e0)",
        "projection.g3_selected_flow_link_id ==",
        "G._n06_actual_fields(package)[9].link_id",
        "@test length(projection.fields) == 5",
    ]
    assert_true(checks, "actual_projection_link_positive_regression",
                all(p in test for p in positive_patterns),
                "test positive actual-A projection compares selected link and fields")

    # Validate every existing source call has a ten-slot destructuring shape or
    # is the direct indexed positive assertion in the test.  This catches a
    # partial R8 repair that fixes only the first caller.
    source_call_count = source.count("_n06_actual_fields(package)")
    assert_true(checks, "source_call_count_and_shapes", source_call_count == 2 and
                bool(projection_bind.search(source)) and bool(join_bind.search(source)),
                f"source calls={source_call_count}; both current callers retain ten-slot shape")

    # R7 failure evidence and R8 repair metadata are JSON/text checked.  No
    # focused rerun is performed by this reviewer.
    r7 = LEDGER / "focused_r7"
    r7_receipt = json_load(r7 / "receipt.json")
    r8_static = json_load(LEDGER / "repair_r8/static_qa.json")
    r8_qa = json_load(LEDGER / "repair_r8/qa_final.json")
    r8_hash_record = (LEDGER / "repair_r8/before_after_hashes.txt").read_text(encoding="utf-8")
    assert_true(checks, "r8_before_after_hash_record_matches_frozen_after",
                "source_before_sha256=7bf3bfd22e61de7a6414cdb75fd3683379ed22ae2865990b97bdf391dffdf181" in r8_hash_record and
                "source_after_sha256=" + EXPECTED["src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl"] in r8_hash_record and
                "focused_r7_exit=1" in r8_hash_record,
                "author R8 repair record preserves R7 before hash and current after hash")
    assert_true(checks, "r7_exit1_preserved", r7_receipt.get("exit") == 1,
                f"classification={r7_receipt.get('classification')}; error={r7_receipt.get('error')}")
    assert_true(checks, "r7_raw_hashes_match_receipt",
                sha256(r7 / "stdout.log") == r7_receipt["stdout"]["sha256"] and
                sha256(r7 / "stderr.log") == r7_receipt["stderr"]["sha256"],
                "focused_r7 stdout/stderr hashes match receipt")
    assert_true(checks, "r8_static_repair_metadata", r8_static == {
        "actual_fields_return_arity": 10,
        "projection_destructure_arity": 10,
        "link_retained": True,
        "r7_receipt_immutable": True,
        "focused_rerun_performed": False,
        "heavy_process_count": 0,
    }, "repair_r8/static_qa.json exact values")
    assert_true(checks, "r8_qa_no_rerun_and_hashes", r8_qa.get("artifact_hashes_match") is True and
                r8_qa.get("R7_raw_immutable") is True and
                r8_qa.get("focused_rerun_performed") is False and
                r8_qa.get("heavy_lane_count") == 0,
                "repair_r8/qa_final.json")

    # Keep all earlier focused raw artifacts present and internally consistent.
    focused = {}
    for i in range(1, 8):
        d = LEDGER / f"focused_r{i}"
        required = ["receipt.json", "exit.txt", "stdout.log", "stderr.log"]
        present = all((d / x).is_file() for x in required)
        raw_hashes = {x: sha256(d / x) for x in required if (d / x).is_file()}
        receipt = json_load(d / "receipt.json") if (d / "receipt.json").is_file() else {}
        nested_ok = True
        if isinstance(receipt.get("stdout"), dict) and "sha256" in receipt["stdout"]:
            nested_ok &= receipt["stdout"]["sha256"] == raw_hashes.get("stdout.log")
        if isinstance(receipt.get("stderr"), dict) and "sha256" in receipt["stderr"]:
            nested_ok &= receipt["stderr"]["sha256"] == raw_hashes.get("stderr.log")
        focused[f"focused_r{i}"] = {"required_raw_present": present,
            "receipt_exit": receipt.get("exit"), "raw_sha256": raw_hashes,
            "receipt_embedded_hashes_match": nested_ok}
    assert_true(checks, "r1_r7_raw_history_preserved",
                all(x["required_raw_present"] and x["receipt_embedded_hashes_match"]
                    for x in focused.values()), json.dumps(focused, sort_keys=True))

    # Protected dirty files are compared against the recorded focused-r7
    # after-hashes, preserving the shared dirty worktree without editing it.
    protected_path = r7 / "protected_after_hashes.txt"
    protected_expected = parse_hash_lines(protected_path)
    protected_current = {rel: sha256(ROOT / rel) for rel in protected_expected}
    assert_true(checks, "protected_dirty_hashes_unchanged",
                protected_current == protected_expected,
                json.dumps({"expected": protected_expected, "current": protected_current}, sort_keys=True))

    # Verify all prior independent review directories remain present; their
    # verdicts are historical evidence and are not reused as this verdict.
    prior_dirs = {}
    for i in range(1, 10):
        d = LEDGER / f"independent_precheck_r{i}"
        files = sorted(x.name for x in d.iterdir()) if d.is_dir() else []
        prior_dirs[f"independent_precheck_r{i}"] = files
    assert_true(checks, "r1_r9_independent_history_present",
                all(prior_dirs[f"independent_precheck_r{i}"] for i in range(1, 10)),
                json.dumps(prior_dirs, sort_keys=True))

    commands = []
    commands.append(run_command("json_parse", [sys.executable, "-c",
        "import json, pathlib; [json.loads(p.read_text(encoding='utf-8')) for p in pathlib.Path('docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER').rglob('*.json')]; print('json_parse_ok')"]))
    commands.append(run_command("validate_plan", [sys.executable, "docs/v4_multitopology_generation/validate_plan.py"]))
    commands.append(run_command("git_diff_check", ["git", "diff", "--check"]))
    process_cmd = "Get-Process | Where-Object { $_.ProcessName -match 'julia|desc' } | Select-Object Id,ProcessName | ConvertTo-Json -Compress"
    commands.append(run_command("julia_desc_process_sweep", ["powershell", "-NoProfile", "-Command", process_cmd]))
    command_exits = {c["name"]: c["exit"] for c in commands}
    assert_true(checks, "static_command_qa", all(v == 0 for v in command_exits.values()),
                json.dumps(command_exits, sort_keys=True))
    process_stdout = next(c["stdout"] for c in commands if c["name"] == "julia_desc_process_sweep")
    assert_true(checks, "no_julia_desc_process_observed",
                process_stdout.strip() in ("", "null", "{}", "[]"), process_stdout.strip())

    status = subprocess.run(["git", "status", "--short", "--",
        "src/FusionConceptAI.jl", "test/runtime_v4_test_manifest.json", "README.md"],
        cwd=ROOT, text=True, capture_output=True, encoding="utf-8", errors="replace")
    dirty_paths = set()
    for line in status.stdout.splitlines():
        if line.strip():
            dirty_paths.add(line[3:].strip())
    expected_dirty_paths = {"README.md", "src/FusionConceptAI.jl",
                            "test/runtime_v4_test_manifest.json"}
    checks["protected_scoped_git_status"] = {
        "pass": status.returncode == 0 and dirty_paths == expected_dirty_paths,
        "detail": {"observed": sorted(dirty_paths),
                    "expected_preserved_dirty_paths": sorted(expected_dirty_paths)},
    }

    passed = all(v["pass"] for v in checks.values())
    verdict = "ready_for_focused_r8" if passed else "changes_requested"
    report = {
        "schema_version": "n06-independent-static-precheck-v1",
        "work_order": "E2-N06-SOURCE-FIELD-LEDGER-independent-precheck-r10",
        "review_round": "R10",
        "reviewer_role": "different_luna_static_reviewer",
        "head": subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True,
            capture_output=True, encoding="utf-8", errors="replace").stdout.strip(),
        "verdict": verdict,
        "accepted": False,
        "frozen_inputs": frozen_hashes,
        "checks": checks,
        "focused_history": focused,
        "command_receipts": [{k: v for k, v in c.items()} for c in commands],
        "claim_ceiling": "static contract readiness only; no B04/provider/mesh/engineering/physical/R01-R10 credit",
        "runtime": {"julia": False, "desc": False, "status": "not_run",
                    "reason": "independent static precheck; focused R8 runtime remains required"},
        "owned_write_scope": ["docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER/independent_precheck_r10/"],
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    evidence = {
        "schema_version": "n06-independent-evidence-manifest-v1",
        "review_round": "R10", "verdict": verdict, "accepted": False,
        "frozen_inputs": frozen_hashes,
        "r7_receipt": "focused_r7/receipt.json",
        "r7_stdout_sha256": r7_receipt["stdout"]["sha256"],
        "r7_stderr_sha256": r7_receipt["stderr"]["sha256"],
        "repair_r8": ["repair_r8/repair_r8.md", "repair_r8/static_qa.json", "repair_r8/qa_final.json"],
        "raw_history": [f"focused_r{i}/" for i in range(1, 8)],
        "protected_after_hashes": protected_current,
        "claim_ceiling": report["claim_ceiling"],
    }
    (OUT / "evidence_manifest.json").write_text(json.dumps(evidence, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md = f"""# E2-N06 independent static precheck R10\n\nVerdict: `{verdict}`. This is a static precheck only; it is not runtime acceptance and does not grant B04/provider/mesh/engineering/physical/R01-R10 credit.\n\nFrozen inputs are the requested source `{frozen_hashes[next(iter(EXPECTED))]}`, test `{frozen_hashes[list(EXPECTED)[1]]}`, fixture `{frozen_hashes[list(EXPECTED)[2]]}`, and runner `{frozen_hashes[list(EXPECTED)[3]]}`. `_n06_actual_fields` has the exact ten-value return tuple with selected G3 `link` ninth and `fields` tenth. `n06_projection_from_a` retains `link` and consumes `link.link_id` in the projection and canonical hash; it consumes the returned `fields` in the projection and hash. The adjacent join helper also destructures ten values. The positive source-bound test compares `projection.g3_selected_flow_link_id` with `_n06_actual_fields(package)[9].link_id` and checks five fields.\n\nThe R5 typed occurrence identity repair and R6 authored-selector controls remain present. R7 exit-1 raw stdout/stderr and receipt are preserved and hash-consistent; R8 metadata records no rerun. Focused R1-R7 raw directories, R1-R9 independent history, and the protected dirty after-hashes remain present/current. Static JSON parse, `validate_plan.py`, `git diff --check`, scoped protected status, and Julia/DESC process sweep were recorded in `command_receipts.json`.\n\nNo Julia/DESC process was started by this review. The next permitted action is one serial focused R8 runtime run after lane authorization.\n"""
    (OUT / "report.md").write_text(md, encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
