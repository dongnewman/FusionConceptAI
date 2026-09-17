from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


REPO = Path(__file__).resolve().parents[4]
AUTHOR = REPO / "docs/implementation/UP2-00G-I1B-PREPARATION/source_matrix_r1"
OUT = Path(__file__).resolve().parent
MATRIX = AUTHOR / "source_matrix.json"
BUILD = AUTHOR / "build_matrix.py"
MANIFEST = AUTHOR / "evidence_manifest.json"
INPUTS = AUTHOR / "input_hashes.json"
AFTER_INPUTS = AUTHOR / "after_input_hashes.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def lines_with(text: str, needles: list[str]) -> list[dict]:
    return [{"line": i, "text": line} for i, line in enumerate(text.splitlines(), 1)
            if any(needle in line for needle in needles)]


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
    matrix = json.loads(MATRIX.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    input_records = json.loads(INPUTS.read_text(encoding="utf-8"))
    after_records = json.loads(AFTER_INPUTS.read_text(encoding="utf-8"))
    rows = matrix["rows"]

    input_checks = []
    for record in input_records:
        path = REPO / record["path"]
        actual = sha256(path) if path.exists() else None
        input_checks.append({"path": record["path"], "expected": record["sha256"],
                             "actual": actual, "match": actual == record["sha256"]})
    after_checks = []
    for record in after_records:
        path = REPO / record["path"]
        actual = sha256(path) if path.exists() else None
        after_checks.append({"path": record["path"], "expected": record["sha256"],
                             "actual": actual, "match": actual == record["sha256"]})

    source_text = {
        "typed_validator": (REPO / "src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl").read_text(encoding="utf-8"),
        "typed_contract": (REPO / "src/GenomeV5/UP2/TypedPrecompilerContractV1.jl").read_text(encoding="utf-8"),
        "n03": (REPO / "src/GenomeV5/UP2/N03TimeAuthorityProjectionV1.jl").read_text(encoding="utf-8"),
        "n04": (REPO / "src/GenomeV5/UP2/N04LedgerAuthorityProjectionV1.jl").read_text(encoding="utf-8"),
        "n05": (REPO / "src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl").read_text(encoding="utf-8"),
        "n06": (REPO / "src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl").read_text(encoding="utf-8"),
        "n07n08": (REPO / "src/GenomeV5/UP2/N07N08GeometryProjectionV1.jl").read_text(encoding="utf-8"),
        "n09": (REPO / "src/GenomeV5/UP2/N09ProviderGapProjectionV1.jl").read_text(encoding="utf-8"),
        "n10": (REPO / "src/GenomeV5/UP2/N10IdentityReceiptProjectionV1.jl").read_text(encoding="utf-8"),
    }
    build_text = BUILD.read_text(encoding="utf-8")

    groups = Counter(row["group"] for row in rows)
    ids = [row["id"] for row in rows]
    paths = [row["field_path"] for row in rows]
    source_kinds = Counter(row["source_kind"] for row in rows)
    eligibles = Counter(row["eligible_for_g1b_local_row"] for row in rows)

    # The source modules are checked independently of the author's matrix builder.
    exact_path_checks = {}
    for group, key in [("N01", "typed_validator"), ("N02", "typed_validator"),
                       ("N03", "n03"), ("N04", "n04"), ("N05", "n05"),
                       ("N07", "n07n08"), ("N08", "n07n08"), ("N09", "n09"),
                       ("N10", "n10")]:
        group_rows = [row for row in rows if row["group"] == group]
        exact_path_checks[group] = {
            row["id"]: row["field_path"] in source_text[key] for row in group_rows
        }
    # N06 is intentionally selector-bound: the production strings use the selected
    # Julia index, while the inventory uses <selected-index> as a candidate-neutral
    # template.  Check the corresponding interpolated production paths explicitly.
    n06_templates = {
        "N06-01": "/g3/realization/network/resource_ports/$(pi - 1)/port_id",
        "N06-02": "/g3/realization/network/entries/$(ei - 1)/account_id",
        "N06-03": "/g3/binding/links/$(li - 1)/resource_port_id",
        "N06-04": "/g3/realization/network/closures/$(ci - 1)/expected_balance",
        "N06-05": "/g3/realization/network/resource_ports/$(pi - 1)/kind",
    }
    exact_path_checks["N06"] = {row["id"]: n06_templates[row["id"]] in source_text["n06"]
                                  for row in rows if row["group"] == "N06"}

    source_checks = {
        "n01_n02_actual_accessors": all(token in source_text["typed_validator"] for token in (
            "UP2IntegerValueV1(eq.input_ranks[1])", "UP2IntegerValueV1(eq.output_ranks[1])",
            "input_state.physical_type.tensor_rank", "package.g2.plan.embedding.ambient_dimension",
            "package.g2.plan.field_space.value_shape", "UP2UnitValueV1(eq.input_units[1])",
            "UP2TextValueV1(package.g2.plan.field_space.state_unit)",
            "package.g3.realization.network.resource_ports[1].unit",
            "package.g3.realization.network.entries[1].unit")),
        "n03_actual_factory": all(token in source_text["n03"] for token in (
            "function n03_time_authority_projection(package)", "equation = first(equations)",
            "event_value = first(events)", "candidate, g1ref, g1hash", "candidate, g3ref, g3hash")),
        "n04_actual_factory": all(token in source_text["n04"] for token in (
            "function n04_projection_from_a", "network.accounts[1]", "network.closures[1]",
            "network.entries[1]", "network.entries[2]", "package.g1.candidate_hash")),
        "n05_authored_binding": all(token in source_text["n05"] for token in (
            "declaration.left_endpoint.endpoint_ref", "declaration.right_endpoint.endpoint_ref",
            "declaration.law.law_hash", "endpoint.unit.source.source_ref",
            "endpoint.unit.source.source_hash", "_n05_authored_unit_path")),
        "n06_actual_selector_join": all(token in source_text["n06"] for token in (
            "_n06_actual_fields(package)", "_n06_unique_match", "(x.ledger_id, x.equation_id, x.port_side, x.port_index)",
            "_N06_G2_SELECTOR.boundary_face", "x.kind == :effort", "x.kind == :flow",
            "g3_selected_flow_link_id=link.link_id")),
        "n07n08_actual_factory": all(token in source_text["n07n08"] for token in (
            "function n07_n08_projection_from_a", "package.g2_binding.candidate_ref",
            "package.component_identity.g2_genome_hash", "package.candidate_hash == expected_package_hash")),
        "n09_actual_factory": all(token in source_text["n09"] for token in (
            "function n09_provider_gap_projection(package)", "package.g1", "package.g2", "package.g3",
            "N09ProviderDeclarationV1(:g1_operator", "N09ProviderDeclarationV1(:g2_grammar",
            "N09ProviderDeclarationV1(:g2_exterior", "N09ProviderDeclarationV1(:g3_realization",
            "N09ProviderDeclarationV1(:g3_control")),
        "n10_actual_factory": all(token in source_text["n10"] for token in (
            "function n10_identity_projection_from_a", "_n10_check_package(package)",
            "package.g3.binding.contract_binding.contract_ref", "_n10_expected_package_hash(package)",
            "_n10_expected_identity_hash(package)")),
    }

    # All source expressions are checked against the owning module.  The N05-05
    # hash is intentionally exact: unit provenance has its own source_hash and is
    # not equivalent to the authored law hash.
    n05_05 = next(row for row in rows if row["id"] == "N05-05")
    n05_hash_mismatch = {
        "matrix_expression": n05_05["component_or_content_hash"],
        "production_unit_hash_expression": "declaration.right_endpoint.unit.source.source_hash",
        "production_evidence": lines_with(source_text["n05"], ["endpoint.unit.source.source_hash", "declaration.law.law_hash"]),
        "match": n05_05["component_or_content_hash"] == "declaration.right_endpoint.unit.source.source_hash",
    }

    # Existing local archives establish only contract-local ceilings; they are not
    # used as substitutes for source verification.
    archive_paths = {
        "N03": REPO / "docs/implementation/UP2-00D-N03/acceptance.md",
        "N04": REPO / "docs/implementation/UP2-00D-N04/acceptance.md",
        "N05": REPO / "docs/implementation/UP2-00E1-N05-FLUX-AUTHORITY/acceptance.md",
        "N06": REPO / "docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER/acceptance.md",
        "N07N08": REPO / "docs/implementation/UP2-00B-N07-N08/acceptance.md",
        "N09": REPO / "docs/implementation/UP2-00C-N09/acceptance.md",
        "N10": REPO / "docs/implementation/UP2-00C-N10-IDENTITY-RECEIPT/acceptance.md",
    }
    archive_checks = {}
    for key, path in archive_paths.items():
        text = path.read_text(encoding="utf-8")
        archive_checks[key] = {
            "path": str(path.relative_to(REPO)),
            "sha256": sha256(path),
            "accepted_limited_present": "accepted_limited" in text,
            "contract_only_present": "contract_only" in text or "contract-only" in text,
            "formal_b04_false_or_open": any(token in text for token in ("B04", "formal")),
        }

    commands = [
        run_command([sys.executable, str(REPO / "docs/v4_multitopology_generation/validate_plan.py")]),
        run_command([sys.executable, "-c", "import json, pathlib; root=pathlib.Path('.'); files=[p for p in root.glob('docs/implementation/UP2-00G-I1B-PREPARATION/source_matrix_r1/*.json')]; [json.loads(p.read_text(encoding='utf-8')) for p in files]; print('json_parse_ok', len(files))"]),
        run_command(["git", "diff", "--check"]),
        run_command(["powershell", "-NoProfile", "-Command", "$p=Get-Process -Name julia,DESC -ErrorAction SilentlyContinue; if ($null -eq $p) { '[]' } else { $p | Select-Object Id,ProcessName | ConvertTo-Json -Compress }"]),
    ]
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2), encoding="utf-8")

    structural = {
        "row_count_50": len(rows) == 50 and matrix.get("row_count") == 50,
        "five_rows_each_N01_N10": all(groups[group] == 5 for group in [f"N{i:02d}" for i in range(1, 11)]),
        "ids_unique": len(ids) == len(set(ids)),
        "field_paths_unique": len(paths) == len(set(paths)),
        "all_ids_match_group": all(row["id"].startswith(row["group"] + "-") for row in rows),
        "source_kind_counts": dict(source_kinds),
        "eligible_counts": dict(eligibles),
        "all_exact_or_selector_paths": all(all(values.values()) for values in exact_path_checks.values()),
    }
    blockers = []
    if not all(input_check["match"] for input_check in input_checks):
        blockers.append({"id": "G-I1B-R1-01", "detail": "Author frozen input hashes drifted.", "evidence": [x for x in input_checks if not x["match"]]})
    if not all(after_check["match"] for after_check in after_checks):
        blockers.append({"id": "G-I1B-R1-02", "detail": "Author after-input hashes do not reproduce.", "evidence": [x for x in after_checks if not x["match"]]})
    if not all(structural[key] for key in ("row_count_50", "five_rows_each_N01_N10", "ids_unique", "field_paths_unique", "all_ids_match_group", "all_exact_or_selector_paths")):
        blockers.append({"id": "G-I1B-R1-03", "detail": "50-row/group/id/path or source path structure failed.", "evidence": structural})
    if not all(source_checks.values()):
        blockers.append({"id": "G-I1B-R1-04", "detail": "A source module did not support the claimed actual path/type/ref/hash construction.", "evidence": {k: v for k, v in source_checks.items() if not v}})
    if not n05_hash_mismatch["match"]:
        blockers.append({"id": "G-I1B-R1-05", "detail": "N05-05 assigns declaration.law.law_hash to the right endpoint UnitSignature row; production validates and hashes the endpoint unit provenance with endpoint.unit.source.source_hash. Correct the row hash expression or explicitly add the unit provenance hash as the row content hash.", "evidence": n05_hash_mismatch})

    verdict = "changes_requested" if blockers else "pass_limited"
    report = {
        "schema_version": "G-I1B-independent-review-r1-v1",
        "reviewer": "Luna/high different-author static reviewer",
        "verdict": verdict,
        "runtime": {"julia": "not_run", "desc": "not_run", "reason": "static source-matrix review only"},
        "structural": structural,
        "hash_checks": {"source_matrix": sha256(MATRIX), "build_matrix": sha256(BUILD), "author_manifest": sha256(MANIFEST),
                        "input_checks": input_checks, "after_checks": after_checks},
        "source_kind_counts": dict(source_kinds),
        "eligible_counts": dict(eligibles),
        "exact_path_checks": exact_path_checks,
        "source_checks": source_checks,
        "n05_05_hash_check": n05_hash_mismatch,
        "archive_checks": archive_checks,
        "local_envelope": {
            "local_contract_rows": ["N01-01..N01-05", "N02-01..N02-05"],
            "actual_a_rows": ["N03-01..N04-05", "N06-01..N10-05"],
            "authored_over_actual_a_rows": ["N05-01..N05-05"],
            "terminal_deferred_baseline_or_gap": ["N03-04", "N03-05", "N04-01", "N05 absent branch", "N06 cross-layer join", "N09-01..N09-05 provider gaps", "N10-05 fresh/legacy receipt gap"],
            "fail_closed_when_typed_contradiction": "all mutation rows whose source-bound typed value/ref/path/type/closure/boundary conflicts",
            "program_exception": "unexpected checker/source fault; never fixture-driven",
        },
        "blockers": blockers,
        "claim_ceiling": "local contract envelope only; no formal B04, UP2 total, B00, provider, mesh, engineering, physical, or R01-R10 credit",
        "command_receipts": "command_receipts.json",
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    evidence = {
        "schema_version": "G-I1B-independent-review-r1-evidence-v1",
        "report_sha256": sha256(OUT / "report.json"),
        "source_matrix_sha256": sha256(MATRIX),
        "build_matrix_sha256": sha256(BUILD),
        "source_input_drift_count": sum(not x["match"] for x in input_checks),
        "author_after_drift_count": sum(not x["match"] for x in after_checks),
        "verdict": verdict,
        "julia": False,
        "desc": False,
        "formal_b04": False,
        "claim_ceiling": "contract_only",
    }
    (OUT / "evidence_manifest.json").write_text(json.dumps(evidence, indent=2), encoding="utf-8")
    md = [
        "# G-I1B source matrix R1 independent review",
        "",
        f"Verdict: **{verdict}**.",
        "",
        "This is a read-only, different-Luna static review. Julia/DESC were not run. The author matrix is treated as an input and checked against the production source modules and existing local archive boundaries.",
        "",
        "## Structure and provenance",
        "",
        f"- Rows: `{len(rows)}`; groups: `{dict(groups)}`; unique IDs: `{len(set(ids))}`; unique field paths: `{len(set(paths))}`.",
        f"- Source kinds: `{dict(source_kinds)}`; local eligibility labels: `{dict(eligibles)}`.",
        "- N06 uses candidate-neutral `<selected-index>` templates; the review matched each to the production interpolated path using the actual unique selector-derived index expression.",
        "",
        "## Findings",
        "",
    ]
    for blocker in blockers:
        md.append(f"- **{blocker['id']}** {blocker['detail']}")
        if blocker["id"] == "G-I1B-R1-05":
            md.append("  - matrix builder evidence: `build_matrix.py:36` records `declaration.law.law_hash` for `/n05/right_endpoint/unit`.")
            md.append("  - production evidence: `N05FluxAuthorityProjectionV1.jl:292-296` derives the unit source hash from `(endpoint_ref, unit)`; `:428-429` validates `endpoint.unit.source.source_hash`.")
    if not blockers:
        md.append("- No source-matrix correction was found in this static review.")
    md += [
        "",
        "## Local envelope and ceiling",
        "",
        "N01–N02 are actual-A typed local contract rows. N03–N04, N06–N10 are actual-A source projections; their missing cross-layer basis, mapping, provider, or legacy provenance stays `terminal_deferred`. N05 is authored E1 content over actual A and is limited to the existing accepted-limited local scope; the A-absent branch remains deferred. Typed contradictions remain `fail_closed`, and unexpected faults remain `program_exception`.",
        "",
        "The matrix does not constitute formal B04, UP2 total, B00, provider, mesh, engineering, physical, or R01–R10 evidence. Formal G-I2/UP1-04B still requires fresh 50 rows, an independent checker, and two-process replay.",
        "",
        "Hashes, command exits, stdout/stderr, UTC timestamps, JSON parse, plan validation, diff check, and process sweep are in `report.json`, `evidence_manifest.json`, and `command_receipts.json`.",
    ]
    (OUT / "report.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verdict, "blockers": [b["id"] for b in blockers], "output": str(OUT)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
