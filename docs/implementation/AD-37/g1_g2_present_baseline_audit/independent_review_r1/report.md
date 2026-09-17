# AD-37 G1/G2 present-baseline independent review R1

Date: 2026-09-15
Reviewer: different Luna/high, read-only
Review basis: current G1/G2 V1 source, tests, fixtures, archives, AD-33
baseline scaffold, T0/T0 authority recheck, T1 records, and the two AD-37
publication work orders

## Verdict

`changes_requested`. The present-baseline audit conclusion is supported: no
non-fixture source-backed G1/G2 declaration instance, factory-construction
receipt, present parent binding, or four-axis source receipt is available.
The two proposed publication work orders have the right semantic split and
authority boundary, but their machine work-order records need an exact archive
scope, explicit output records, and machine-readable dependency/input-only
edges before implementation is dispatched.

## Present-baseline evidence

The current G1 and G2 source, focused tests, fixtures, baseline scaffold and
T0/T0 authority-recheck hashes all match the AD-37 audit manifest. The V1 tests
construct local typed declarations from `_declaration` and `_fixture_source`;
their candidates are explicitly fixture candidates, their receipts remain
contract-only, and G2's mesh is `not_executed` with mesh and boundary authority
gaps. The G1/G2 implementation archives retain `accepted=false`, zero
provider/mesh/solver calls and no physical evidence.

The baseline integration test constructs only `g1_typed_absent_state` and
`g2_typed_absent_state`. Its fixture declares expected-only negative and
absence data. Public `admit_present_parent` rejects fixture, ref-only,
synthetic and foreign modes, then rejects the source-backed mode with
`source_backed_receipt_unavailable`; the receipt overloads do the same. The
absent state has no actual parent ref, declaration hash, source locator or
factory receipt, and `replace_source_payload` remains a rejected,
byte-preserving operation. The absent-to-present CAS path is forbidden.

The source tree contains the private receipt and present-binding type
definitions, but no production call site constructing a
`SourceBackedV1DeclarationReceiptV1(...)` or
`PresentParentBaselineBindingV1(...)`. The only matching constructor syntax is
the type definition itself; proposal text and negative tests do not create
authority. T0 authority recheck remains typed-absent or fail-closed with
`present=false`, and T1 remains planned/review_pending and blocked. The core
plan validator reports 39 tasks and an acyclic DAG. None of these software,
fixture, documentation or plan results is actual, provider, mesh, engineering,
solver, physical, search, B00, B04 or R01-R10 evidence.

## Work-order checks that pass

`AD37-G1-PRESENT-BASELINE-PUBLISH` and
`AD37-G2-PRESENT-BASELINE-PUBLISH` are separate semantic owners: G1 owns the
diffusion source body and G2 owns chart/metric/boundary/discretization. Each
lists seven product files and a separate actual-input set; the future product
directories and source files are not present in the current checkout. The G2
work order includes an explicit mapping receipt from its source
`GenomeContractRef` to the common fresh `QualifiedRefV1`; the G1 and G2
candidate/public-contract requirements are field-level and reject URI or
fixture-seed aliasing.

Both work orders enumerate raw-source, semantic-body, source-content,
declaration, parent-binding, child-key, state and receipt hashes. Both require
the four typed provenance axes, fresh candidate identity review, and a factory
receipt with `source_backed_present`, exact candidate binding and
`declaration_hash_recomputed=true`. Missing authority, input or axis produces
typed absence plus `terminal_deferred`; contradictions are fail-closed. The
reports contain layer-specific negative controls for foreign/fixture/synthetic
authority, candidate/public mismatch, stale or forged hashes, malformed bodies,
provenance conflicts, wrong layer/units/orientation and failure byte
stability. All work-order credit maps are false.

The two work orders are described as parallel to the typed-absence scaffold,
T0 and the authority recheck, and each explicitly excludes T1, T2 and the
other publication work order. This is semantically acyclic, and the current
39-task core DAG independently validates as acyclic. No AD-37 machine node was
created or dispatched.

## Blocking work-order findings

### 1. Archive ownership is a wildcard, not an exact file set

Both manifests use `evidence_sidecars: .../archive/**`. That permits an
unbounded set of files and does not let cleanup or an independent reviewer
decide which raw stdout/stderr, process, input/output hash, negative-summary and
receipt files belong to the work order. Replace the wildcard with an exact
archive file list, or add an archive manifest whose enumerated file set is
itself an owned output and whose additions are rejected unless explicitly
recorded.

### 2. Machine records do not declare exact publication outputs

`product_files` identifies source, test, fixture, static QA and three docs, but
the machine records do not have an `outputs`/`result_union` set for the actual
publication result. The prose says the result is either a source-backed
declaration/present binding or a typed-absent state, yet no exact output record
paths or typed output names are machine-checkable. Add explicit output records
for the present/absent union, source/factory/declaration receipt, child/state
receipt and the raw execution receipt set. Keep the fixture as negative/absence
data and keep the output receipts candidate-bound.

### 3. Dependency and input-only edges are not machine-readable

`parallel_to` and `must_not_depend_on` show the intended boundary, but neither
work order has a `depends_on` field or a separate `read_only_inputs` field.
Consequently a plan validator cannot prove which accepted upstream contracts
are prerequisites, which current V1 paths are read-only inputs, or that the
future publication outputs do not form an edge through the other sibling or
T0/T1/T2. Add explicit empty or named dependency lists, read-only input lists,
and a small local DAG assertion. Preserve G1/G2 sibling independence and the
no-T0/T1/T2-unlock rule.

## Required repair and exit gate

Repair ownership is limited to the AD-37 audit's future-work-order manifest and
its corresponding publication-boundary text. Do not create either future
source/product directory during this repair, and do not alter G1/G2 V1 source,
tests, fixtures, archives, AD-33, T0, T1, core task manifest or historical
receipts. Recheck exact product/input/output paths, JSON validity, all hash and
axis fields, typed-absence/fail-closed rules, fixture non-authority, local DAG
acyclicity, cleanup scope and the current 14 observed source/evidence hashes.

Until that repair and a later independent review, retain the present decision
as `not_found_terminal_deferred` for both layers. Keep implementation, actual
G1/G2, T0/T1/T2, provider, mesh, solver, engineering, physical, search, B00,
B04 and R01-R10 credits false. No Julia, DESC, provider, mesh, solver or
physical command was run by this review, and no reviewed file was modified.
