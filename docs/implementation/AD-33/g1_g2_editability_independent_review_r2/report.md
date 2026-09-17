# AD-33 G1/G2 candidate-owned editability independent review R2

Date: 2026-09-15  
Reviewer: different `gpt-5.6-luna/high`  
Review basis: AD-33 repair_r1  
Decision: `changes_requested`  
Status: `review_pending=true`, `accepted=false`

## Scope and evidence boundary

This review rechecked the original R1 findings against the complete
`repair_r1/revised_proposal.md` and `repair_r1/manifest.json`, the current G1
and G2 V1 source/test/fixture/archive records, and AD-31/AD-32. The review is
read-only. No Julia, DESC, provider, mesh, solver, physical, or heavy-Python
execution was run, and no core, task manifest, source, test, fixture, or old
receipt was changed.

The repair proposal and manifest hashes are:

* `repair_r1/revised_proposal.md`:
  `a09c87c2a68816b3edda74f3834712bb678a4a0d1c96b611d65cd35a77396830`;
* `repair_r1/manifest.json`:
  `e7d7cf21a989cf88abf419976da93373824bca04be895511afb93bc7b1b2aef0`.

The AD-33 R1 reviewed-record hashes remain report
`154ea03f20503e069f68ebd2cd72315af2685049482c418d5b91838d019016d3` and
manifest `1ad2f48e139bb51a862c60f661e04c11aa1e07ab85ec6bcbbf8b4a3be3496cc2`.
The current V1 source/test/fixture/static-QA hashes still match the AD-33
observed inputs. No Julia/DESC process was present during the audit.

## Field-level disposition

### F03 — parent envelope and V1 baseline: changes requested

The repair now gives both siblings closed parent-envelope records, fixed hash
domains, equality checks, a child contract identity hash, and explicit
foreign/ref-only/synthetic-authority controls. Those parts close the shape of
the envelope.

The binding is not yet implementable against the actual V1 records. The new
G1 envelope uses `candidate_ref::GenomeContractRef`, while the current
`G1DiffusionDeclarationV1.candidate_ref` is `QualifiedRefV1`. The proposal
requires `parent_ref.candidate_ref == candidate_ref`, but does not define the
typed projection or equality relation by which the source-backed G1 V1
candidate is bound to that `GenomeContractRef`. A child can therefore satisfy
the proposed envelope while selecting a declaration whose actual V1 candidate
is different.

The baseline fields also name `source_bytes_hash`, `semantic_body_hash` and
`parent_declaration_hash` without making all three obtainable from the current
V1 artifacts. Raw source bytes can be hashed from `source_path`, but the
current G1/G2 source modules define constructors and hash helpers; they do not
publish one source-backed declaration instance from which the selected parent
declaration hash and exact semantic-body projection can be recovered. The
existing JSON fixtures contain synthetic candidate seeds and are explicitly
not authority. The proposal gives a semantic hash domain tag, but not the
exact field projection, declaration locator/factory, or candidate binding
record needed to recompute it without promoting a fixture.

Minimum repair: add a typed, source-backed baseline locator/factory or an
explicit additive baseline record whose authority is the existing V1
declaration contract, specify the exact semantic-body field order excluding
the declaration hash, and define the G1 `QualifiedRefV1` to
`GenomeContractRef` candidate binding (or use a typed G1 parent ref that can
represent the actual V1 candidate and separately binds the public contract).
The child must recompute raw source-byte SHA, semantic-body SHA and parent
declaration SHA from that source-backed record, while treating fixture values
as expected test data only.

### F04 — four provenance axes and absence: pass

The repair supplies four distinct present slot types for each sibling and a
typed absent record with axis, candidate, parent, child, contract identity and
reason bindings. The absence domain is explicit and excludes source/content/
operation/state hashes. The slot union is closed, and missing authority maps
to typed absence plus `contract_admission=:terminal_deferred`; conflicts and
unexpected exceptions remain separate. This closes the R1 F04 request,
subject to the unresolved parent/baseline binding above being fixed for real
instances.

### F05 — six hashes and digest-only history: pass

The repair adds literal domain tags and fixed order for child-contract,
source-record, source-content, initial-state, operation and result/current
state hashes. It stores and recomputes the child contract identity hash and
defines operation history as a bounded `NTuple{N,Digest256}` with no state,
payload, operation or receipt objects. The zero operation digest is typed and
domain-separated. The recipes form a forward chain without embedding later
hashes in earlier layers. This closes the R1 F05 request.

### F06 — state/operation/receipt and dual CAS: changes requested

The repair now specifies complete outer records, state-first then
source-content CAS order, separate stale error codes, rejected receipts that
are not stored or appended, and exact prior canonical-byte/SHA preservation.
The positive transition and failure-atomic rule are adequate at the
architecture level.

Two details still need freezing. First, step 1 permits an arbitrary malformed
input to return a closed `G1EditReceiptV1`/`G2EditReceiptV1`, but that receipt
requires typed operation ID, child key and several `Digest256` fields. The
proposal does not define the deterministic typed-absent/zero values used for
those fields before a closed input exists. Second, the closed error list names
`mesh_execution_status_not_executed`, while the terminal-deferred G2 example
uses `mesh_execution_not_executed`; the structural rejection code and the
missing-execution gap must be distinct, consistently named receipt/gap
values. Constructors must also restrict receipt status, error/status pairs,
and `published/history_advanced` combinations.

Minimum repair: freeze the pre-CAS malformed-receipt representation and the
status/error cross-field table, and reconcile the two G2 not-executed names.
Keep the fixed state-CAS-before-source-CAS order and ensure no failed receipt
is part of published state or operation history.

### F07 — G2 declaration versus mesh execution: changes requested

The intended boundary is correct: the child mesh plan accepts only
`execution_status=:not_executed`, `authority.mesh=:unique_match` cannot
promote execution, and the unresolved execution remains terminal deferred.
The semantic owner lists also keep G1 mechanism fields and G2 geometry fields
disjoint.

The negative control is internally inconsistent. The proposal says the typed
constructor accepts only `:not_executed`, then gives
`G2GeometryMeshPlanV1(..., execution_status=:declared)` as a constructible
input that should reach admission with `fail_closed` and
`mesh_execution_status_not_executed`. A normal typed constructor cannot
produce that value. The future test must either use an explicit controlled
decode/tamper seam that is outside the public constructor, or classify the
constructor rejection with a separate closed error and reserve admission for
well-typed values. The terminal-deferred gap for valid `:not_executed` plus
unique symbolic authority must remain independently tested.

### F08 — no-launcher exact scope: pass

The repair removes the implicit launcher and names direct static-QA and
focused-test commands for each sibling. Source, test, fixture, static QA and
implementation archive files are sufficient for this contract-only work
order; fixtures and static QA are necessary for source-backed negative
controls. Existing V1 files, shared entries, core, task manifest and old
receipts remain protected. The direct Julia commands are future work-order
commands only and were not run in this review.

## Dependency and claim boundary

The two proposed nodes remain acyclic siblings. Each depends only on
UP1-01/02/03 and its own UP2-01 V1 contract; neither depends on the other
sibling, T0, T1 or T2. T0 remains the transport owner, T1 the sole
lossless-package mapper and T2 the downstream identity/receipt rebuilder. The
repair does not create machine nodes or synchronize core planning records.

## Required R2 repair before limited acceptance

1. Make the parent envelope bind to the actual V1 candidate types, especially
   the G1 `QualifiedRefV1` case, and provide an executable source-backed
   baseline locator/factory with exact semantic-body projection and SHA rules.
2. Define deterministic typed values for malformed pre-CAS receipts and close
   the receipt status/error cross-field table; reconcile the two G2
   not-executed error/gap names.
3. Clarify the G2 negative-control seam so the constructor/admission path is
   internally consistent while preserving the valid unique-match plus
   `:not_executed` terminal-deferred case.

After these narrow repairs, a different Luna may grant `pass_limited` for the
architecture/work-order boundary only. Sol may accept that boundary, but the
machine nodes remain uncreated and `accepted=false`; no implementation,
actual child, T0/T1/T2, UP2, provider, mesh, engineering, physical, search,
B00, B04 or R01-R10 credit is allowed.
