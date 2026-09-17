# AD-37 G1/G2 present-baseline audit — independent R2 repair

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
Scope: repair of the original read-only audit and `repair_r1` only. The
original report, manifest, cleanup inventory, independent reviews and
`repair_r1` remain preserved byte-for-byte.

## Decision remains unchanged

No non-fixture, candidate-bound, source-backed G1 or G2 V1 declaration
instance, factory construction receipt, or declaration receipt is present in
the inspected checkout. The present gate remains **NO-GO for both layers**.
The repository can construct structural typed declarations from local test
values, but those values do not establish source authority, candidate
binding, a fresh factory receipt, or four-axis provenance. The parent
baseline remains typed-absent only; T0 authority recheck remains typed-absent
or fail-closed; T1 remains planned/review_pending and blocked.

This repair is documentation-only. It adds exactly `repair_r2/revised_report.md`
and `repair_r2/manifest.json`. It does not create a future publication
directory, output directory, archive directory, source, test, fixture,
static-QA, launcher, baseline, T0/T1/T2, core-plan, old-receipt or physical
artifact. Julia, DESC, provider, mesh, solver and physical execution were not
run. No candidate hash was created. All implementation, actual, physical,
provider, mesh, solver, engineering, search, B00, B04 and R01–R10 credits
remain false.

## R2 findings closed

The two future publication work orders now classify every fixed `output/*.json`
branch result record as an explicit product/data deliverable. Each exact path
is listed in that work order's `product_files`, and each work order declares
`product_file_count=14`: seven contract/source/test/document files plus seven
possible branch result records (five present receipts, one absence record and
one failure record). These seven branch records are a typed result union;
only the selected branch is emitted by a future implementation. The count is
therefore a declared product scope count, not a claim that any branch output
currently exists.

`archive/evidence_index.json` remains evidence metadata and is listed under
each branch's `evidence_sidecar_files`, never in `product_files`. It is the
only enumerator for append-only sidecars. Sidecars must carry exact
`path/kind/round/bytes/sha256/immutable` records, and may contain only raw
streams, process/exit data, hashes, repairs, cleanup, reviews or status
records. Product/data records must not be placed in a sidecar namespace.

The parent dependency is now the canonical task ID
`UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC` in both work orders and the local
DAG. `AD-36` is recorded in `architecture_decision_refs` and as an explicit
external pending policy blocker. The AD-36 contract is currently
`review_pending`/`accepted=false`; this repair does not turn it into an
accepted dependency or unlock implementation.

## Work-order boundary

The G1 and G2 proposals remain independent and additive, with the exact
result union
`PresentBaselinePublicationV1 | AbsentBaselinePublicationV1 |
FailedBaselinePublicationV1`. The present branch requires fresh source bytes,
source locator, candidate/public-contract binding, factory receipt, all eight
hashes, four present provenance axes and fresh identity review. Missing
authority or inputs yields typed absence plus `terminal_deferred`; a
contradiction yields `fail_closed`; an unexpected fault yields
`program_exception`. The G2 mapping from `GenomeContractRef` to the common
`QualifiedRefV1`, and its separate mesh/boundary authority gap, remain
required.

The proposed work orders remain `proposed_blocked_external`. They must not be
dispatched until the external source/factory/provenance inputs exist and the
AD-36 sidecar policy has an accepted-limited decision. They do not create a
machine node, modify the 39-task DAG, or grant T0/T1/T2, provider, mesh,
solver, engineering, physical, search, B00, B04 or R01–R10 credit. Sibling
publication edges and edges to T0, authority recheck, T1 and T2 remain
forbidden.

## Validation and cleanup

The repair manifest records the frozen R2 inputs, exact paths, SHA-256 values,
PID/UTC, raw validation receipts, exit code and input/output hashes. The
applicable checks are JSON parsing, exact output-path/product-count checks,
canonical dependency checks, AD-36 pending-blocker checks, lowercase SHA-256
format checks, control-character checks, exact write-scope checks and
`git diff --check` over the two new paths. The final validation exit is 0.

Cleanup is closed with no owned temporary or unrelated code files found. No
historical failure, original receipt or prior review was removed or
overwritten. The only new paths are the two files in `repair_r2`.
