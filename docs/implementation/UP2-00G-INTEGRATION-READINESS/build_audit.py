import hashlib
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent

CLASS_META = {
    "N01": {"status": "accepted_limited actual-A local slice", "scope": "UP2-00 r18 N01/N02 local schema/value projection", "source": "src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl", "artifact": "docs/implementation/UP2-00/evidence_manifest.json"},
    "N02": {"status": "accepted_limited actual-A local slice", "scope": "UP2-00 r18 N01/N02 local schema/value projection", "source": "src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl", "artifact": "docs/implementation/UP2-00/evidence_manifest.json"},
    "N03": {"status": "accepted_limited actual-A local slice", "scope": "five time fields; G3 event time-basis deferred", "source": "src/GenomeV5/UP2/N03TimeAuthorityProjectionV1.jl", "artifact": "docs/implementation/UP2-00D-N03/evidence_manifest.json"},
    "N04": {"status": "accepted_limited actual-A local slice", "scope": "five ledger fields; cross-layer join/shared-owner scope deferred", "source": "src/GenomeV5/UP2/N04LedgerAuthorityProjectionV1.jl", "artifact": "docs/implementation/UP2-00D-N04/evidence_manifest.json"},
    "N05": {"status": "review_pending", "scope": "E1 source/fixture prepared; authoritative flux endpoint/unit absent", "source": "src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl", "artifact": "docs/implementation/UP2-00E1-N05-FLUX-AUTHORITY/evidence_manifest.json"},
    "N06": {"status": "review_pending changes_requested", "scope": "E2 R2 static blockers; cross-layer source-field-return/heat/ledger authority absent", "source": "src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl", "artifact": "docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER/evidence_manifest.json"},
    "N07": {"status": "accepted_limited actual-A local slice", "scope": "N07/N08 current-admitted-G2 ten schema rows; topology limits remain", "source": "src/GenomeV5/UP2/N07N08GeometryProjectionV1.jl", "artifact": "docs/implementation/UP2-00B-N07-N08/evidence_manifest.json"},
    "N08": {"status": "accepted_limited actual-A local slice", "scope": "N07/N08 current-admitted-G2 ten schema rows; topology limits remain", "source": "src/GenomeV5/UP2/N07N08GeometryProjectionV1.jl", "artifact": "docs/implementation/UP2-00B-N07-N08/evidence_manifest.json"},
    "N09": {"status": "accepted_limited actual-A local slice", "scope": "five provider_match declarations and 11 changed provider-gap mutations", "source": "src/GenomeV5/UP2/N09ProviderGapProjectionV1.jl", "artifact": "docs/implementation/UP2-00C-N09/evidence_manifest.json"},
    "N10": {"status": "accepted_limited actual-A local slice", "scope": "five identity/receipt fields; N10-04 synthetic attempted and N10-05 fresh-only", "source": "src/GenomeV5/UP2/N10IdentityReceiptProjectionV1.jl", "artifact": "docs/implementation/UP2-00C-N10-IDENTITY-RECEIPT/evidence_manifest.json"},
}

FILES = [
    "src/FusionConceptAI.jl",
    "src/GenomeV5/Integration/GenomeV5Integration.jl",
    "src/GenomeV5/UP2/PrecompilerInvocationCounterV1.jl",
    "src/GenomeV5/UP2/TypedPrecompilerContractV1.jl",
    "src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl",
    "src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl",
    "src/GenomeV5/UP2/N03TimeAuthorityProjectionV1.jl",
    "src/GenomeV5/UP2/N04LedgerAuthorityProjectionV1.jl",
    "src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl",
    "src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl",
    "src/GenomeV5/UP2/N07N08GeometryProjectionV1.jl",
    "src/GenomeV5/UP2/N09ProviderGapProjectionV1.jl",
    "src/GenomeV5/UP2/N10IdentityReceiptProjectionV1.jl",
    "test/GenomeV5/UP2/fixtures.json",
    "test/GenomeV5/UP2/up2_00_contract_tests.jl",
    "test/GenomeV5/UP2/run_up2_00_contract.jl",
    "test/GenomeV5/UP2/n03_time_authority_fixtures.json",
    "test/GenomeV5/UP2/n03_time_authority_tests.jl",
    "test/GenomeV5/UP2/run_n03_time_authority.jl",
    "test/GenomeV5/UP2/n04_ledger_authority_fixtures.json",
    "test/GenomeV5/UP2/n04_ledger_authority_tests.jl",
    "test/GenomeV5/UP2/run_n04_ledger_authority.jl",
    "test/GenomeV5/UP2/n05_flux_authority_fixtures.json",
    "test/GenomeV5/UP2/n05_flux_authority_tests.jl",
    "test/GenomeV5/UP2/run_n05_flux_authority.jl",
    "test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json",
    "test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl",
    "test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl",
    "test/GenomeV5/UP2/n07_n08_geometry_fixtures.json",
    "test/GenomeV5/UP2/n07_n08_geometry_tests.jl",
    "test/GenomeV5/UP2/run_n07_n08_geometry.jl",
    "test/GenomeV5/UP2/n09_provider_gap_fixtures.json",
    "test/GenomeV5/UP2/n09_provider_gap_tests.jl",
    "test/GenomeV5/UP2/run_n09_provider_gap.jl",
    "test/GenomeV5/UP2/n10_identity_receipt_fixtures.json",
    "test/GenomeV5/UP2/n10_identity_receipt_tests.jl",
    "test/GenomeV5/UP2/run_n10_identity_receipt.jl",
    "docs/implementation/UP2-00/evidence_manifest.json",
    "docs/implementation/UP2-00E1-N05-FLUX-AUTHORITY/evidence_manifest.json",
    "docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER/evidence_manifest.json",
    "docs/implementation/UP2-00B-N07-N08/evidence_manifest.json",
    "docs/implementation/UP2-00C-N09/evidence_manifest.json",
    "docs/implementation/UP2-00C-N10-IDENTITY-RECEIPT/evidence_manifest.json",
    "docs/implementation/UP2-00D-N03/evidence_manifest.json",
    "docs/implementation/UP2-00D-N04/evidence_manifest.json",
    "docs/implementation/UP2-00E0-BOUND-INPUT/evidence_manifest.json",
    "docs/v4_multitopology_generation/16_execution_work_orders.md",
    "docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md",
]

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for b in iter(lambda: f.read(1024 * 1024), b""):
            h.update(b)
    return h.hexdigest()

def file_record(rel):
    p = ROOT / rel
    s = p.stat()
    return {"path": rel, "sha256": sha(p), "bytes": s.st_size,
            "mtime": datetime.fromtimestamp(s.st_mtime, timezone.utc).isoformat()}

def main():
    fixture = json.loads((ROOT / "test/GenomeV5/UP2/fixtures.json").read_text(encoding="utf-8"))
    rows = fixture["mutations"]
    assert len(rows) == 50
    records = [file_record(p) for p in FILES]
    dirty = subprocess.run(["git", "status", "--short"], cwd=ROOT, text=True,
                           capture_output=True, check=False).stdout.splitlines()
    ps = subprocess.run(["powershell", "-NoProfile", "-Command",
        "Get-CimInstance Win32_Process | Where-Object {$_.Name -match 'julia|desc'} | Select-Object ProcessId,Name,CommandLine | ConvertTo-Json -Depth 3"],
        cwd=ROOT, text=True, capture_output=True, check=False)
    proc_text = ps.stdout.strip() or "[]"
    try:
        processes = json.loads(proc_text)
    except json.JSONDecodeError:
        processes = {"raw": proc_text}
    snapshot = {"head": subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True,
                                        capture_output=True, check=False).stdout.strip(),
                "dirty_entries": dirty, "julia_desc_process_sweep": processes,
                "checked_at_utc": datetime.now(timezone.utc).isoformat(),
                "files": records}
    (OUT / "input_hashes.json").write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    class_records = {}
    for k, v in CLASS_META.items():
        class_records[k] = {**v, "source_sha256": next(x["sha256"] for x in records if x["path"] == v["source"]),
                            "artifact_sha256": next(x["sha256"] for x in records if x["path"] == v["artifact"])}
    lines = [
        "# UP2-00G integration-readiness audit",
        "",
        "This is a read-only capture of the current dirty checkout. It does not promote any task, rewrite the frozen 50-row fixture, or claim formal B04, provider, mesh, engineering, physical, or R01-R10 evidence.",
        "",
        f"Checked HEAD: `{snapshot['head']}`. Checked at `{snapshot['checked_at_utc']}`. Julia/DESC process sweep: `{json.dumps(processes, ensure_ascii=False)}` (the audit itself did not run Julia/DESC). Dirty entries and all input hashes are in `input_hashes.json`.",
        "",
        "## Evidence class capture",
        "",
        "The 50 rows in the frozen `test/GenomeV5/UP2/fixtures.json` are historical/provisional registration rows. The local slice column below refers to each class's current artifact and recorded scope; it never converts a provisional row into a fresh B04 receipt.",
        "",
        "| class | current local slice | source path | source SHA256 | archive manifest | manifest SHA256 |",
        "|---|---|---|---|---|---|",
    ]
    for k in [f"N{i:02d}" for i in range(1, 11)]:
        c = class_records[k]
        lines.append(f"| {k} | {c['status']}; {c['scope']} | `{c['source']}` | `{c['source_sha256']}` | `{c['artifact']}` | `{c['artifact_sha256']}` |")
    lines += ["", "Every row has `fresh formal B04 = pending`: no local slice has the required candidate-bound receipt/checker/two-process replay. N01/N02 remain only the UP2-00 local accepted_limited slice; N03/N04/N07/N08/N09/N10 are similarly bounded local slices; N05 is E1 review_pending and N06 is E2 review_pending/changes_requested.", "", "## Exact 50-row matrix", "", "| row | historical provisional source locator | type | local evidence | fresh formal B04 |", "|---|---|---|---|---|"]
    for r in rows:
        k = r["class_id"]
        lines.append(f"| {r['id']} | `{r['source_locator']}` | `{r['source_type']}` | {k}: {class_records[k]['status']} (`{class_records[k]['source']}`) | pending: fresh receipt + checker + two-process replay |")
    lines += [
        "", "## Current integration gaps", "",
        "1. `src/FusionConceptAI.jl:5-51` includes the core V4/V5 contracts and `GenomeV5/Integration/GenomeV5Integration.jl`, but no UP2 source. Its exports at `:120-123` expose CandidateStatePackageV5 APIs, not N01-N10 or a unified UP2 validator. The current `load_genome_v5_components!()` at `src/GenomeV5/Integration/GenomeV5Integration.jl:15-26` includes the G1/G2/G3 component files only; each UP2 runner manually `Base.include`s its own file. This leaves include order, shared methods, and one public admission seam unresolved.",
        "2. `TypedPrecompilerValidatorV1.jl:29-76` registers all 50 rows, but its documented implementation is N01/N02; the remaining rows are pending/provisional projections. The A projection at `:115-150` uses explicit placeholders for N05 and typed pending values for later classes. Registration and `length(fields)==50` at `:168` therefore do not prove 50 source-backed rows.",
        "3. N03 local authority is limited to G1 temporal/operator and G3 trigger/nonnegative rational checks; candidate-bound event time basis is deferred. N04 local closure checks do not establish G1 occurrence→G3 account/entry/energy-boundary join; shared owner is legal. N05 lacks authoritative typed endpoints/sign/unit provenance. N06 R2 remains changes_requested: its local authored mapping cannot establish dimensioned source→field→return/heat/ledger authority. N07/N08 are current admitted-G2 geometry schema only. N09 proves only five actual-A declarations and 11 changed provider-gap mutations; it performs no provider resolution. N10 is limited to five actual-A identity/receipt fields, with synthetic attempted hash/fresh-only boundaries.",
        "4. The existing UP2 invocation counter and validators provide local zero-call checks, but there is no unified 50-row checker that consumes one fresh candidate-bound package and emits formal receipt envelopes. `up2_00_contract_tests.jl` and N03-N10 runners are separate manually included seams, so compile-before-provider ordering and counter ownership must be integrated before B04.",
        "",
        "## B04 distinction and dependency route",
        "",
        "The required route remains `UP2-00` (unified contract-only schema/validator) → `UP1-04B` (freeze and execute B00 F0-F5 plus 50 formal B04 receipts/checker/two-process replay) → `UP1-04` total gate → `UP2-01`. Current local N01–N10 slices can be inputs to that work, but they do not satisfy the route. All 50 formal B04 receipts remain pending and the parent R01-R10 scope is unchanged.",
        "",
        "## Bounded integration work packages for Sol",
        "",
        """| package | exclusive future ownership | inputs | output | executable exit gate | dependency |
|---|---|---|---|---|---|
| G-I0 module seam | additive registration in `src/FusionConceptAI.jl` and `src/GenomeV5/Integration/GenomeV5Integration.jl` (registration lines only); new `src/GenomeV5/UP2/UP2ModuleEntryV1.jl`, `test/GenomeV5/UP2/up2_module_entry_tests.jl`, runner, archive | current UP2 files; E0 package; dirty-file before hashes | one additive include/export/API seam with deterministic order and no V4 edits | static include graph resolves every owned symbol once; JSON parse; loader test; `git diff --check`; no Julia/DESC claim; protected unrelated dirty bytes unchanged | before unified UP2-00; explicit owner required for the two existing registration files |
| G-I1 authority reconciliation | `src/GenomeV5/UP2/UP2ActualAUnifiedProjectionV1.jl`; new 50-row fixture/test/runner/archive | E0 accepted binding; actual A package; E1/E2 and N03/N04/N07/N08/N09/N10 local artifacts; frozen base fixture as history | one versioned candidate-bound row envelope with source path/type/value/ref/hash and explicit local-valid, fail_closed, terminal_deferred, program_exception classes | exactly 50 rows each have one real accessor or explicit missing-authority gap; mutation hash changes are source-derived; no expected-label routing, synthetic constructor, reused evidence, or downstream calls | depends on G-I0 and E1/E2 resolution; output feeds UP2-00 |
| G-I2 formal receipt/checker | `src/GenomeV5/UP2/UP2FormalB04EnvelopeV1.jl`; new checker/test/runner/archive | unified G-I1 envelope; 19/13/16 formal obligations; candidate package and counter seam | fresh 50 receipt set, checker, two-process replay inputs and immutable process receipts | 50/50 fresh candidate-bound receipts, registered F0-F5/N01-N10 classifications, compile-before-provider and zero-counter gates where required, exact two-process receipts, independent Luna pass; no physics inference | after UP2-00 unified gate; hands formal package to UP1-04B |
| UP1-04B/total acceptance | existing separately governed UP1-04B paths | G-I2 outputs plus formal freeze | B00/B04 acceptance record, then UP1-04 total review | Sol scheduling, independent Luna review, all formal receipts and process evidence complete; only then UP1-04 can proceed | `UP2-00 → UP1-04B → UP1-04`; UP2-01 remains downstream |
""", "", "## Action order and claim ceiling", "", "1. Freeze G-I0 ownership and resolve the additive module seam without changing V4 or the dirty `FusionConceptAI.jl` entrypoint by implication.", "2. Reconcile E1/E2 and the accepted local slices into a fresh candidate-bound schema; missing N05/N06 authority stays terminal_deferred, present typed contradictions fail_closed, and unexpected faults stay program_exception.", "3. Run the unified UP2-00 contract-only checker and freeze its 50-row formal envelope before any B04 execution. UP1-04B then owns the first formal B00/B04 run and two-process replay.", "4. Until those gates complete, this audit and every cited local slice carry no B00/B04/provider/mesh/engineering/physical/R01-R10 credit.", ""]
    (OUT / "report.md").write_text("\n".join(lines), encoding="utf-8")
    manifest = {"work_order":"UP2-00G-INTEGRATION-READINESS", "status":"review_pending", "accepted":False, "claim_ceiling":"read_only_integration_audit", "head":snapshot["head"], "checked_at_utc":snapshot["checked_at_utc"], "scope":"50-row local evidence classification, module wiring gap, and bounded integration work packages", "formal_b04":False, "b00":False, "provider":False, "mesh":False, "engineering":False, "physical":False, "r01_r10_credit":False, "inputs":"input_hashes.json", "report":"report.md", "source_status":{"N01-N04":"accepted_limited local slices", "N05":"review_pending", "N06":"review_pending changes_requested", "N07-N10":"accepted_limited local slices"}, "fresh_formal_rows":50, "fresh_formal_receipts":0, "dependency_route":["UP2-00","UP1-04B","UP1-04","UP2-01"], "julia_desc_invoked":False, "review_gate":"independent Luna review required"}
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
