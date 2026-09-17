# AD-37 G1/G2 present-baseline independent review R2

Date: 2026-09-15
Reviewer: different Luna/high, read-only
Review basis: repair_r1, original R1 passing checks, current G1/G2/T0/T1
inputs, AD-36 sidecar policy and the core 39-task plan

## Verdict

`changes_requested`. Repair R1 closes the original R1 findings: the evidence
index is exact and append-only, the three result branches and output paths are
listed, and dependency/read-only/blocked/parallel/DAG structures are explicit.
The present-baseline conclusion remains valid and conservative. Three
integration details still need repair before these work orders can be accepted
as an architecture boundary: result files are placed in an unclassified
`output/` namespace under the AD-36 sidecar policy, the parent-baseline
dependency uses a non-canonical short ID, and the AD-36 pending acceptance
boundary is not represented as an explicit external blocker.

## Checks that pass

The repaired manifest parses and preserves the original audit. Its top-level
read-only input inventory has exactly 47 unique existing paths: 10 current G1
V1 paths, 11 current G2 V1 paths, 10 baseline-scaffold paths, 7 T0 paths and
9 T0 authority-recheck paths. The recomputed sorted path/bytes/SHA-256
inventory digest is:

`a86b06ed4badd9fec4f7c30a41e3aadc69ed8ac1b4d8c3023c4b0b054c246406`

The original 14 observed source/test/fixture/static-QA/baseline/T0 hashes still
match the audit manifest. All future publication source and input directories
remain absent. The current source tree has no production call site creating a
`SourceBackedV1DeclarationReceiptV1(...)` or
`PresentParentBaselineBindingV1(...)`; the only matching constructor syntax is
the type definition. Current G1/G2 tests and archives remain fixture/contract
only, G2 mesh remains `not_executed`, the baseline is typed-absent, T0
authority recheck is typed-absent or fail-closed with `present=false`, and T1
is planned/review_pending and blocked.

Each repaired work order has seven product files, its exact actual-input set,
the three-way typed result union
`PresentBaselinePublicationV1 | AbsentBaselinePublicationV1 |
FailedBaselinePublicationV1`, branch-specific output paths, all eight raw/
semantic/source/declaration/parent/child/state/receipt hash fields, all four
provenance axes, typed absence/terminal-deferred and fail-closed/program-
exception rules, negative controls, exit gates and all-false credit flags.
Fixtures remain negative/absence data and are not authority.

The evidence policy now has one exact owner,
`archive/evidence_index.json`, with append-only registration, required
`path/kind/round/bytes/sha256/immutable` fields, lowercase 64-character SHA-256
format, forbidden product/source/test/fixture/static-QA/launcher kinds, and a
scope violation for unregistered sidecars. The local proposed graph is
acyclic, sibling publications have forbidden edges to each other and to T0,
the authority recheck, T1 and T2, and no future publication directory was
created.

The AD-36 alignment is substantively correct for the evidence index: it keeps
evidence-only sidecars append-only, task-owned and excluded from product
deliverable counts, and forbids product/source/test/fixture/static-QA/launcher
material in sidecars. AD-36 itself remains `review_pending`/`accepted=false`,
so this alignment cannot be treated as an accepted cross-task authority.

## Remaining blocking findings

### 1. Result outputs are outside both product scope and the AD-36 sidecar scope

The branch outputs such as
`G1-PRESENT-BASELINE-PUBLISH/output/parent_binding_receipt.json`,
`source_backed_declaration_record.json`, `absence_record.json` and
`failure_record.json` are explicit paths, but they are neither in
`product_files` nor under `archive/`, `review/` or `status_sync_*/`. AD-36
permits evidence sidecars only in its named task-owned sidecar namespaces;
these output records therefore have no classification and could violate exact
deliverable counting. Move them into the corresponding product contract set,
or classify them as AD-36 evidence sidecars under `archive/` and register each
with `evidence_index.json`. Apply the same choice to G2 and state that the
branch output union remains contract-only.

### 2. The parent-baseline dependency is not a canonical task ID

Both `depends_on` lists and the local DAG use
`PARENT-BASELINE-BIND-PREC`, while the core task manifest uses
`UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC`. The short name is not a task ID in
the 39-task manifest, so a cross-manifest DAG checker cannot resolve this edge.
Replace it everywhere in the repaired AD-37 record with the canonical ID and
retain the node's actual `planned`/`proposal`/`accepted=false` status. Keep the
G1/G2 sibling edges absent and the T0/T1/T2 forbidden edges explicit.

### 3. AD-36 remains an external pending blocker

The local evidence-index rules correctly mirror AD-36, but the repair manifest
does not record AD-36 as a pending external policy input or state that
publication cannot be dispatched until the AD-36 decision is resolved. Add an
explicit `external_policy_inputs` or equivalent field containing the canonical
AD-36 acceptance/manifest paths, their `review_pending`/`accepted=false`
status, and a `blocked_on` entry. This must not turn AD-36 into an accepted
dependency or unlock implementation; it only prevents silent promotion of a
pending sidecar policy.

## Exit boundary

After these documentation-only corrections and one new independent review, the
two records may be accepted as architecture work orders only, with status
`proposed_blocked_external`; they still must not dispatch a present publication
without fresh external source/factory/provenance inputs. Keep implementation,
actual G1/G2, T0/T1/T2, provider, mesh, solver, engineering, physical, search,
B00, B04 and R01-R10 credits false. No Julia, DESC, provider, mesh, solver or
physical command was run here, and no reviewed source, test, fixture, archive,
baseline, T0, T1, core plan or prior receipt was modified.
