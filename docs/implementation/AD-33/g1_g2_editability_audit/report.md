# AD-33 G1/G2 candidate-owned editability precursor audit

Date: 2026-09-15  
Repository: `D:\006-Programing\LMC\FusionConceptAI`  
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Observed dirty rows: `307` (`25` modified, `282` untracked)

## Decision

The two proposed child precursors **should be split into sibling work orders**:

* `UP1-04A-VNEXT-G1-MECHANISM-EDIT-PREC` owns a G1 mechanism/source-body
  precursor;
* `UP1-04A-VNEXT-G2-GEOMETRY-EDIT-PREC` owns a G2 geometry/metric-boundary
  precursor.

They have different semantic owners, invariants, source edits, and negative
controls. G1 must own typed operators, state/occurrence/closure and mechanism
source semantics; G2 must own charts, metric, topology/face ownership and
discretization declarations. Making either node depend on the other would
create a false cross-layer authority edge and would make T1's later exact join
less auditable.

The dispatch verdict is **NO-GO pending minimum architecture repair**. The
current V1 slices are useful evidence for the body semantics, but they are not
safe child state machines. They implement rebuild-on-edit declarations, not an
atomic candidate-owned child payload/state with independent provenance and
compare-and-swap failure behavior. This audit proposes the repair boundary and
does not edit the plan, task manifest, V1 source/tests, old receipts, AD-31 or
AD-32.

## Read-only basis and current evidence

The audit followed `AGENTS.md`, then `docs/v4_multitopology_generation/README.md`,
`00_normative_contracts_and_state_model.md`, `10_genome_upgrade_execution.md`,
`14_agent_orchestration.md`, `16_execution_work_orders.md`,
`18_sources_and_architecture_decisions.md`, and the current
`task_manifest.json`. The relevant accepted architecture precedents are
AD-31 (realization child) and AD-32 (control child); both remain
`accepted_limited` architecture/work-order boundaries with implementation and
actual-child acceptance false.

The V1 files were inspected by bytes and source text. No Julia, DESC, provider,
mesh, solver, physical or heavy Python execution was started by this audit.

| slice | current source/test/fixture/static-QA SHA-256 | current boundary |
|---|---|---|
| G1 | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a`; `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6`; `7b580bf9ad875ed70ffc3aa0ee2e27cbe124c413ec7dad0a8fcd3410c6864641`; `87f511f5402224df06928a9e78c0d3213d2330da5b91021b628acd51d7536066` | static QA recorded `pass`; Julia/DESC/provider/mesh/solver calls `0`; `accepted=false`; `terminal_deferred`; contract-only |
| G2 | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61`; `1647d7f72a4d1f2a8e9ff93543058ee6a7c9799d3988911d6b8ec7d8a65121db`; `1721eebb16ec4a4895e2f6a71c943daf1514fb4798565c44b548d8d8f22ef5d5`; `cf7bf40446929c8d28b21da0da61c159c0d0cdff979e042c115802fb20dd1f31` | static QA recorded `pass`; Julia/DESC/provider/mesh/solver calls `0`; `accepted=false`; mesh/authority gaps `terminal_deferred`; contract-only |

The current V1 declaration archives and the current plan manifest are also
source inputs. Their observed hashes are in `manifest.json`; these hashes are
audit receipts, not new candidate evidence.

## Current V1 findings and blocking gaps

### G1 mechanism/source-body V1

`DiffusionDeclarationV1.jl` has a closed typed local body for a bounded
3-D scalar `u`, diagonal-affine positive `K(x)`, scalar `f`, typed `GRAD`,
`K_APPLY` and `DIV`, units, closure references and a fixed negative residual
sign. `g1_diffusion_edit_source` rebuilds a declaration when `u`, `K` or `f`
is replaced and changes the source/declaration hash. The focused test covers
typed construction, malformed units/bounds/bindings, missing authority,
source-hash tamper, string-only edit rejection and an edited `K` identity.

The blocking gaps are:

1. The declaration has no typed parent declaration reference or additive child
   contract identity. `candidate_ref` and `source_ref` are `QualifiedRefV1`
   values, while the future V5 join requires a candidate-bound external
   contract identity with schema/canonicalization/profile fields. A URI and a
   declaration hash cannot silently fill this gap.
2. There is no closed source record with four independent provenance axes
   (payload schema, canonicalization, applicability/profile, receipt). The
   `closure_ref` and `applicability_ref` are declarations, not candidate-bound
   evidence slots. Missing source authority is represented only by one
   `terminal_deferred` result, not by typed absent slots and absence hashes.
3. There is no materialized child state, initial/current state hash, operation
   history or operation hash. The edit API has no expected prior state/source
   hash and therefore cannot distinguish a stale edit from a valid edit.
4. The edit operation is a field selector API. It rejects string-only input,
   but it does not provide an atomic full-payload replacement contract,
   forged operation/source-record checks, or a proof that every failed call
   leaves prior canonical bytes unchanged.
5. The declaration validator checks a subset of constructor invariants. The
   future child must independently recompute all source-record, source-content,
   child-contract and state identities; fixture labels and the existing
   `source_ref` must not become authority.

### G2 geometry/metric-boundary V1

`MetricBoundaryDeclarationV1.jl` has an executable affine 3-D chart, exact
Jacobian and `JᵀJ` metric, orientation/area/volume calculations, typed mesh
plan with Q1/Q2 basis and quadrature, six oriented face owners with typed
Dirichlet/Neumann values, unit algebra, source/declaration hashes and a
`g2mb_edit_source` rebuild for chart, mesh or one face value. The focused test
covers exact metric values, face closure and orientation, unit failures,
contradiction `fail_closed`, missing authority `terminal_deferred`, and a
separate `program_exception` probe.

The blocking gaps are:

1. The source has a candidate `GenomeContractRef`, but `G2MBAuthorityV1` is
   only three symbols (`unique_match`, `no_match`, `missing`). It contains no
   source locator, source hash, candidate-bound receipt or four-axis provenance
   and cannot represent typed absent slots with stable absence hashes.
2. `G2MBSourceV1` and `G2MBDeclarationV1` have source/declaration hashes but no
   child key, parent declaration binding, child contract identity, materialized
   state or operation lineage. The fixture's candidate seeds are explicitly
   synthetic and cannot be promoted to actual-candidate authority.
3. `g2mb_edit_source` accepts three selector forms, has no expected prior
   state/source hashes, no operation hash and no failure byte-stability
   requirement. It also permits a whole mesh replacement without a separately
   auditable operation record.
4. The mesh `execution_status` and authority gaps correctly cap the receipt,
   but they do not constitute typed provenance or a fail-atomic edit state.
   Mesh-plan declaration remains a contract object; it is not mesh/provider
   execution or physical evidence.
5. The source validates the six-box face set and local units, but a future
   child must bind geometry edits to a parent declaration and child identity,
   preserve source-record refs and explicitly reject foreign/stale refs before
   any state transition.

The gaps are structural and independent. They are why G1 and G2 need separate
precursors, and also why neither current V1 should be dispatched as if it were
already an AD-31/AD-32-style editable child.

## Proposed sibling G1 precursor

The exact future write set is:

* `src/GenomeV5/G1/G1MechanismChildEditabilityV1.jl`;
* `test/GenomeV5/G1/g1_mechanism_child_editability_v1_contract_tests.jl`;
* `test/GenomeV5/G1/g1_mechanism_child_editability_v1_fixture.json`;
* `test/GenomeV5/G1/static_qa_g1_mechanism_child_editability_v1.py`; and
* `docs/implementation/UP1-04A-VNEXT-G1-MECHANISM-EDIT-PREC/README.md` plus
  `manifest.json`.

The node depends on the accepted limited scopes of UP1-01/02/03 and the
`UP2-01-G1-DIFFUSION-V1` declaration contract. It is parallel to the G2
precursor and `UP1-04A-VNEXT-T0`; it must not depend on G2, T0 or an actual G3
child. Its input is the read-only current G1 V1 declaration, the G1 semantic
owner rules in the normative and Genome documents, a fresh typed candidate
envelope, and fresh typed local body values. Historical fixtures, old
candidate hashes and old receipts are not inputs.

The closed source body must retain, with fixed field order, the mechanism
source ID/owner scope, typed state and time semantics, typed operator graph,
typed units and derivatives, governing/additive/constraint roles, occurrence
and closure ledger identities, applicability/capability declarations, and
source-derived negative controls. It must reject `Dict`, `Any` semantic bodies,
open paths, old V1/V4 aliases and label-only references.

The child key and payload must include:

```text
G1MechanismChildKeyV1(
    candidate_ref, parent_g1_declaration_ref, parent_g1_declaration_hash,
    child_kind=:mechanism, child_id)
G1MechanismSourcePayloadV1(
    key, child_contract, source_uri, source_version, closed_body,
    source_record, source_content_hash)
```

`parent_g1_declaration_ref` must be a real typed declaration ref with an exact
hash binding. The current G1 V1 lacks this external contract envelope; that
envelope is a dispatch blocker and must be frozen additively before coding.

The sole operation is `replace_source_payload`. It replaces the complete
closed body under exact candidate/parent/child/source-record identity, with
`expected_prior_state_hash`, `expected_prior_source_content_hash` and a closed
operation record. It does not accept a dynamic field path, partial patch,
insert/delete, alias or operation inferred from a fixture. All G1 body
invariants are rechecked before publishing the new state.

The outputs are one present-or-typed-absent source payload, a materialized
state, derived identity/hash helpers, an operation receipt, focused tests,
static QA and an archive receipt. The local contract status is separate from
physical status; no source edit can create a compiled residual, provider
match, mesh, solver or physical result.

## Proposed sibling G2 precursor

The exact future write set is:

* `src/GenomeV5/G2/G2GeometryChildEditabilityV1.jl`;
* `test/GenomeV5/G2/g2_geometry_child_editability_v1_contract_tests.jl`;
* `test/GenomeV5/G2/g2_geometry_child_editability_v1_fixture.json`;
* `test/GenomeV5/G2/static_qa_g2_geometry_child_editability_v1.py`; and
* `docs/implementation/UP1-04A-VNEXT-G2-GEOMETRY-EDIT-PREC/README.md` plus
  `manifest.json`.

The node depends on the accepted limited scopes of UP1-01/02/03 and the
`UP2-01-G2-METRIC-BOUNDARY-V1` declaration contract. It is parallel to the G1
precursor and `UP1-04A-VNEXT-T0`; it must not depend on G1, T0 or an actual G3
child. Its input is the read-only current G2 V1 declaration, the G2 semantic
owner rules, a fresh candidate envelope, and fresh typed local chart,
metric/continuity, boundary, basis/quadrature and mesh-plan values. Existing
mesh/provider receipts and the fixture seed are not inputs.

The closed source body must retain chart/domain and transition semantics,
metric/Jacobian/orientation, regions/interfaces/exterior or boundary ownership,
field/source target declarations, basis/quadrature and mesh-plan semantics,
units, applicability and discretization profile. It must keep geometry hash,
mesh/evaluation identity and solver input identity separate, so changing mesh
resolution does not masquerade as a G2 geometry edit.

The child key and payload must include:

```text
G2GeometryChildKeyV1(
    candidate_ref, parent_g2_declaration_ref, parent_g2_declaration_hash,
    child_kind=:geometry, child_id)
G2GeometrySourcePayloadV1(
    key, child_contract, source_uri, source_version, closed_body,
    source_record, source_content_hash)
```

The sole operation is the same full `replace_source_payload` protocol. A
replacement may change chart/metric/boundary/mesh-plan semantics only when the
closed body remains internally valid and the operation's exact prior source
and state hashes match. A face, metric or mesh selector is not itself an
operation identity. Provider, mesh backend and solver execution stay outside
the precursor.

## Shared identity, provenance and typed absence contract

Both siblings must use the repository canonicalizer with valid UTF-8, LF,
fixed field order and no self-recursion. The minimum non-recursive layers are:

1. `child_contract_identity_hash = H(canonical(child_contract_ref))`;
2. `source_record_hash = H(canonical(source_uri, source_version,
   payload_schema_slot, canonicalization_slot, applicability_slot,
   evidence_receipt_slot))`, excluding itself and all content/operation hashes;
3. `source_content_hash = H(canonical(key, parent_ref, parent_hash,
   child_contract, source_uri, source_version, closed_body,
   source_record_hash))`, excluding itself;
4. `initial_state_hash = H(canonical(key, state_status,
   source_content_or_absence_hash, contract_admission,
   physical_resolution, operation_hash=ZERO_DIGEST, empty_history))`;
5. `operation_hash = H(canonical(operation_id, key, expected prior state/source
   hashes, replacement payload, source_record_ref))`, excluding result hash;
6. `state_hash = H(canonical(key, state_status, source_payload_ref_or_absence,
   editable body or body hash, source-content/absence hash,
   contract_admission, physical_resolution, operation_hash, history))`.

Every provenance axis is a closed present-or-absent slot. A present slot has
the exact typed value/ref, locator/path, source hash, candidate ref and status.
An absent slot has no value or fabricated source hash, an explicit reason and
an independently derived absence-content hash. Missing authority is
`typed_absent` plus `contract_admission=:terminal_deferred`; contradictory
present data is `:fail_closed`; unexpected implementation faults are
`:program_exception`. `physical_resolution` is only `:unknown` or
`:terminal_deferred` here and cannot be promoted by a constructor, hash, test,
runner exit, provider label or `bridge_ready` marker.

## Fail-atomic negative controls and exit gates

Each sibling must test all of the following against canonical state bytes and
SHA-256 before and after the call:

* foreign candidate, parent declaration ref/hash, child kind/id or child
  contract ref/hash;
* malformed/open body, duplicate IDs, unresolved operator/field/region/face
  references, wrong units/orientation/closure and unsupported dynamic paths;
* missing provenance slot -> typed absence and `terminal_deferred`, with no
  fabricated source/content hash;
* conflicting candidate/source/axis/status/hash -> `fail_closed`;
* independently recomputed source-record, source-content, initial-state,
  operation and state hashes;
* forged payload, source-record ref or operation hash;
* stale source hash and stale state hash as separate failure codes;
* non-target or multi-object edit, insert/delete/rebind and fixture/URI-only
  authority attempts; and
* successful full replacement changes the permitted source/content/operation/
  state identities while preserving key/parent/child identities and the old
  state on every failed path.

The future focused exit requires source/static QA, a focused contract test,
raw stdout/stderr bytes, input/output SHA-256, PID, exit code and dirty-file
protection, followed by a different Luna independent review. The resulting
scope can at most be `accepted_limited` software contract evidence. This audit
itself ran only read-only inspection; it records no focused execution receipt.

## Relation to T0/T1/T2 and evidence ceiling

The siblings are preparation children before T0. T0 remains the only owner of
transporting the complete G1/G2/G3 V1 declarations and the child actual-or-
typed-absent states into a semantic bundle; the siblings must not import,
redefine or close T0 authority. T1 remains the only owner of lossless mapping
into `CandidateStatePackageV5Next`; a local child state is not a T1 package.
T2 must rebuild E0/G-I1A/E1/E2/UP2 identities and receipts from the fresh T1
package. A changed G1 or G2 source body requires a new candidate identity,
fresh upstream hashes and fresh downstream receipts; old V1/V4/AD-31/AD-32
receipts cannot be grafted.

Neither sibling grants T0, T1, T2, UP2, B00, B04, provider, mesh, engineering,
physical, search or R01-R10 credit. The full R01-R10 parent goal remains
unchanged, and a local contract pass cannot close it.

## Minimum repair sequence before dispatch

1. Freeze an additive candidate/declaration envelope for both V1 parents,
   including exact parent ref, candidate ref, schema/canonicalization/profile
   hashes and the source-backed baseline hash. Resolve the current G1 lack of
   an external typed declaration ref without mutating old V1 bytes.
2. Freeze one shared typed provenance-slot/absence vocabulary and the exact
   six-layer hash/state recipe above, while keeping G1 and G2 body schemas
   disjoint.
3. Freeze the full replacement operation and receipt schema, including two
   separate stale guards and canonical-byte fail-atomic behavior.
4. Add the two sibling work-order records only after the above boundary has a
   reviewed source and manifest; each gets a separate source/test/fixture/
   static-QA/archive scope and a different-Luna reviewer.
5. Run only the bounded software gates, review the fresh receipts, and keep
   T0/T1/T2 and all provider/mesh/physical/search/R01-R10 credit false.

Until steps 1–3 are frozen, both proposed nodes remain `blocked_pending_architecture_repair`.

