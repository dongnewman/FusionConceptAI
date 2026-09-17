# AD-37 G1/G2 present-baseline independent review R3

Date: 2026-09-15  
Reviewer: different Luna/high, read-only  
Verdict: `pass_limited`

## Scope and basis

This review independently checks `repair_r2` against the v4 README, the common
contract, orchestration rules, work-order rules, architecture decisions, the
current AD-36 status, the original AD-37 audit, `repair_r1`, and independent
reviews R1/R2. The reviewed repair and all prior records remain unchanged. The
only files created by this review are this report, its manifest, and the raw
validation receipt under this review's own `review/` directory.

The current HEAD is `4b69f55f7f80240147a65a22809dc1207824dde2`. The original
AD-37 observed set of 14 source/test/fixture/baseline/T0 hashes was recomputed
by an independent PowerShell process (PID `69700`) and all 14 match. The
repair's own frozen input hashes and revised-report hash also match its raw
receipt (PID `49060`, exit `0`).

## Findings

`repair_r2` closes all three R2 findings.

1. Both future work orders declare `product_file_count=14`, with 14 unique
   `product_files`. The seven output records are explicitly product/data
   deliverables in each list: five `PresentBaselinePublicationV1` records,
   one `AbsentBaselinePublicationV1` record, and one
   `FailedBaselinePublicationV1` record. Every output path appears in
   `product_files`; the archive evidence index does not. The future G1/G2
   product and input paths are absent, so this is a frozen future scope rather
   than a claim that any output exists.

2. `archive/evidence_index.json` remains evidence metadata and the only sidecar
   enumerator. Its required registration fields, append-only rule, SHA-256
   format, forbidden product/source/test/fixture/static-QA/launcher kinds,
   out-of-scope action, and direct-command rule are present. The product/data
   output records are outside sidecar namespaces.

3. Both `depends_on` lists use the canonical
   `UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC` task ID. `AD-36` is present only
   as an architecture reference and an explicit external blocker; it is absent
   from `depends_on`, has `accepted=false`, remains `review_pending`, and does
   not unlock dispatch. Sibling publication edges and edges to T0, the
   authority recheck, T1 and T2 remain forbidden. The local graph is declared
   acyclic, and the core task manifest still has 39 tasks with no AD-37 machine
   node.

4. The shared result contract is complete: the three-way result union, eight
   independent hash fields, four provenance axes, fresh identity rule, typed
   absence plus `terminal_deferred`, contradiction `fail_closed`, and separate
   `program_exception` are all present. G2 retains its explicit
   `GenomeContractRef` to `QualifiedRefV1` mapping and mesh/boundary authority
   gap. No URI, fixture seed, old fixture, or historical authority is promoted.

5. The current source/evidence boundary remains conservative. The only source
   occurrences of `SourceBackedV1DeclarationReceiptV1(...)` and
   `PresentParentBaselineBindingV1(...)` are their private type-definition
   constructors; the current integration tests construct typed-absent states
   and preserve `AD33_PBB_PRESENT_AUTHORITY=false`. Current G1/G2 records remain
   proposal/review-pending with `accepted=false`, zero provider/mesh/solver
   calls and no physical evidence. No future publication directory, source,
   test, fixture, static-QA file or launcher exists.

## Validation evidence

The final JSON/hash/count/path/control-character/DAG/product-scope assertions
ran in PID `58028` from the repository root and exited `0`. The original
14-hash recheck, repair receipt recheck, and audited-scope `git diff --check`
also exited `0`. Their UTC timestamps and raw result strings are preserved in
`review/validation_receipt_r3.json`.

No Julia, DESC, provider, mesh, solver or physical command was run. This review
therefore accepts only the documentation and future work-order boundary. It
does not accept present G1/G2, a source-backed parent baseline, T0/T1/T2,
provider, mesh, solver, engineering, physical, search, B00, B04 or any R01–R10
credit. Dispatch remains blocked on fresh source/factory/provenance inputs and
an accepted-limited AD-36 decision.

## Cleanup and final boundary

No task-owned temporary, scratch, cache, unrelated code, historical receipt or
prior review file was removed or changed. The exact new review-owned set is:

- `independent_review_r3/report.md`
- `independent_review_r3/manifest.json`
- `independent_review_r3/review/validation_receipt_r3.json`

The result is `pass_limited` for the repaired AD-37 architecture/work-order
scope only.
