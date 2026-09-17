# AD-33 G1/G2 candidate-owned editability independent review R1

Date: 2026-09-15  
Reviewer: different `gpt-5.6-luna/high`  
Decision: `changes_requested`  
Status: `review_pending=true`, `accepted=false`

## Scope and evidence boundary

This is a read-only architecture review of the AD-33 audit and its proposed
work orders. I inspected the repository rules, the v4 contract/orchestration/
work-order records, AD-31 and AD-32, the current G1/G2 V1 source and focused
test/fixture/static-QA inputs, and the AD-33 report and manifest. No Julia,
DESC, provider, mesh, solver, physical, or heavy-Python execution was run.
No source, test, fixture, core, task-manifest, old receipt, AD-31, or AD-32
file was changed by this review.

The current input hashes agree with the AD-33 manifest:

| slice | source | contract test | fixture | static QA |
| --- | --- | --- | --- | --- |
| G1 | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` | `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6` | `7b580bf9ad875ed70ffc3aa0ee2e27cbe124c413ec7dad0a8fcd3410c6864641` | `87f511f5402224df06928a9e78c0d3213d2330da5b91021b628acd51d7536066` |
| G2 | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` | `1647d7f72a4d1f2a8e9ff93543058ee6a7c9799d3988911d6b8ec7d8a65121db` | `1721eebb16ec4a4895e2f6a71c943daf1514fb4798565c44b548d8d8f22ef5d5` | `cf7bf40446929c8d28b21da0da61c159c0d0cdff979e042c115802fb20dd1f31` |

The reviewed AD-33 report hash is
`154ea03f20503e069f68ebd2cd72315af2685049482c418d5b91838d019016d3` and
its manifest hash is
`1ad2f48e139bb51a862c60f661e04c11aa1e07ab85ec6bcbbf8b4a3be3496cc2`.

## Findings

### 1. Sibling split: pass

G1 and G2 should be separate siblings. The current G1 declaration owns the
candidate mechanism fields, typed operators, closure and applicability. The
current G2 declaration owns the affine chart/metric/orientation, boundary face
ownership, units and mesh-plan declaration. Their edit targets and failure
controls are independent. G1 must not gain chart, metric, face or mesh
semantics; G2 must not gain G1 operator, closure or diffusion semantics.

The proposed dependency shape is also sound: each sibling depends on its own
UP1-01/02/03 and UP2-01 V1 contract, is parallel to the other sibling and T0,
and does not depend on the other sibling, T0, T1 or T2. This part should be
retained.

### 2. Current blockers: real, but not yet sufficient for dispatch

The blockers are present in the actual source. G1 uses a
`QualifiedRefV1` candidate and a source/declaration hash, but has no typed
external parent declaration binding, child key, materialized state or
operation lineage. Its `g1_diffusion_edit_source` is a field-selector rebuild
with no expected prior state/source guards. G2 has a `GenomeContractRef` and
source/declaration hashes, but its authority is symbolic, its source has no
four-axis source record or typed absence, and its edit function likewise lacks
state, operation and stale-guard identity. Existing tests and receipts verify
the V1 declarations; they do not supply a child state machine.

The AD-33 list correctly identifies these gaps, but it is not yet a closed
implementation contract. It names the required envelope, six hash layers and
operation without freezing their complete typed fields, domain tags, error
codes, and byte-level transition rules. Dispatch should remain blocked until
the minimum repairs below are incorporated into an additive proposal.

### 3. Parent/declaration envelope: changes requested

The proposed envelope is directionally correct and avoids using a source URI
as authority, but it must state the exact type and equality rules. For each
sibling it must contain, at minimum, a typed candidate reference, typed parent
declaration reference, parent declaration hash, child kind/id, child contract
reference, child contract identity hash, and the source-backed V1 baseline
hash. The parent reference must be bound to the candidate and to the exact
parent declaration hash; a reference plus a separately supplied hash is not
enough unless the constructor recomputes and compares both.

The G1 gap is concrete: the existing V1 has no external typed declaration
reference. The G2 `contract_ref` is not a substitute for a parent binding or a
candidate-owned child identity. The additive envelope must therefore be new
data and must not rewrite either V1 declaration or reuse fixture candidate
seeds as authority. Add negative controls for a foreign parent, a foreign
candidate, a ref-only authority claim, and a self-consistent but mismatched
parent hash.

### 4. Provenance and typed absence: changes requested

Four independent slots are the right boundary, but the proposal must freeze
four distinct typed slot records rather than a permissive tuple or a combined
canonicalization/profile value. Each present slot needs its axis tag/version,
typed value/reference, locator, source hash, candidate binding, parent binding
and status. Each absent slot needs an axis-tagged reason and an absence-content
hash. The absence hash domain must include the slot name, candidate, parent,
child identity and reason; otherwise different missing authorities can collide
while retaining a valid-looking hash.

The source-record hash must include these exact slot records while excluding
itself and all source/content/operation results. Missing authority must produce
typed absence plus `contract_admission=:terminal_deferred`; contradictory
present data must be `:fail_closed`; an unexpected implementation exception
must be `:program_exception`. None of these states may be inferred from a
fixture label, URI, constructor success or a runner exit.

### 5. Six-layer hashes and CAS: changes requested

The six layers are a workable non-recursive direction, but two details must be
made explicit before implementation:

1. `child_contract_identity_hash` must be a stored, independently recomputed
   field used by source-content and state recipes. A canonical child reference
   alone must not silently become ref-only authority. Every identity hash needs
   a domain/version tag and fixed field order.
2. `history` must be a closed tuple of prior operation digests (or an equally
   bounded typed chain), never embedded state objects. The initial state uses a
   typed zero operation digest. The operation may point to the expected prior
   state/source digests, while the resulting state points to the operation
   digest; this is a chain, not a recursive state object. The proposal should
   state this rule and test independent recomputation of all six layers.

The two CAS guards must be distinct typed `Digest256` fields:
`expected_prior_state_hash` and `expected_prior_source_content_hash`. A stale
source must not be reported as a stale state, and neither stale failure may
mutate the state, operation history, or error receipt.

### 6. Operation, receipt, and fail-atomic semantics: changes requested

`replace_source_payload` is the correct sole operation. The proposal must
freeze its complete closed record: operation id, child key, expected prior
state/source hashes, replacement payload, source-record reference, canonical
input bytes or digest, result status/error code, and derived operation/result
hashes. It must explicitly reject selectors, partial patches, insert/delete,
rebind, fixture/URI-only edits, and multi-object edits.

Failure atomicity must be observable as the canonical state bytes and their
SHA-256 being identical before and after every failed call. The operation
receipt may describe the failure, but it must not become part of the published
state or advance history on failure. Required negative controls are foreign
identity, malformed/open body, duplicate or unresolved references, missing or
conflicting provenance, forged derived hashes, stale source, stale state, and
each unsupported operation shape. A successful full replacement must change
the permitted source/content/operation/state digests while preserving the
candidate/parent/child identity tuple.

### 7. Semantic ownership and execution boundary: pass with a required guard

The proposed G1 body may own typed mechanism/operator/closure/applicability
semantics. The proposed G2 body may own chart, metric, orientation, face
ownership, boundary values, basis, quadrature, units and mesh-plan
declaration. G2 must keep `execution_status=:not_executed` as a terminal mesh
gap even if symbolic authority says `:unique_match`; a mesh plan is not a mesh
backend or boundary execution. Neither sibling may claim provider, solver,
engineering or physical authority.

The G2 proposal should make the declaration-versus-execution separation a
constructor and negative-control invariant, so no later implementation can
turn a mesh-plan field into an execution receipt by changing only a status
label.

### 8. File scope and evidence: pass with one clarification

The proposed exact scope is appropriately narrow: one new G1 source, test,
fixture, static-QA file and implementation archive; and the corresponding
G2 files. Keeping fixtures and static QA is necessary because the new child
identity, absence, CAS and byte-stability controls need source-backed,
independently inspectable inputs. Existing V1 files, shared entry points,
core, task manifest and old receipts must remain read-only.

If a dedicated launcher is needed to produce raw PID/exit/stream evidence, it
must be named explicitly inside the sibling test scope or the focused test
must be directly launched without a new runner. An implicit launcher would
make the claimed exact write scope incomplete. No launcher is needed for this
architecture review.

## Minimum repairs before dispatch

1. Freeze an additive typed parent/declaration envelope for G1 and G2 with
   candidate/parent/child bindings, parent and child identity hashes, and the
   source-backed V1 baseline hash; add foreign/ref-only/synthetic-authority
   negative controls.
2. Freeze four separate typed provenance slot records and a tagged absence
   record/hash domain. Preserve the independent admission, physical and
   program-exception statuses.
3. Freeze all six hash recipes with domain/version tags, an explicit stored
   child identity hash, and a non-recursive typed operation-digest history.
4. Freeze the closed operation and receipt records, separate source/state CAS
   errors, and canonical-byte/hash failure atomicity. Require positive and
   negative controls for every listed path.
5. Retain the sibling DAG and semantic ownership exactly as proposed. If a
   launcher is part of the future evidence gate, add it to each exact test
   scope before dispatch; otherwise run the focused test directly.

Until these repairs are reviewed, the two nodes remain
`blocked_pending_architecture_repair`.

## Claim ceiling

This review grants no implementation acceptance, actual child authority,
T0/T1/T2 completion, UP2, provider, mesh, solver, engineering, physical,
search, B00, B04 or R01-R10 credit. All such credits remain false.
