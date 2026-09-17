# AD-33 G1/G2 candidate-owned editability independent review R3

Date: 2026-09-15  
Reviewer: different `gpt-5.6-luna/high`  
Review basis: AD-33 repair_r2  
Decision: `changes_requested`  
Status: `review_pending=true`, `accepted=false`

## Scope and evidence boundary

This review checks repair_r2 against the R2 review, the current G1/G2 V1
source/test/archive records, and the repository's actual closed reference and
canonicalization types. It is read-only. No Julia, DESC, provider, mesh,
solver, physical, or heavy-Python execution was run. No core, task manifest,
source, test, fixture, AD-31/AD-32, or old receipt was changed.

Reviewed repair hashes:

* `repair_r2/revised_proposal.md`:
  `bdaa1a370c0cb9474867ce0680e6c7b8ba37da548409e6fb5ddfeb41b5afb039`;
* `repair_r2/manifest.json`:
  `4dc076899d84fa28e8587033e749378b45c8fa8fabdf330e6bdc59171aaaaa89`.

The current V1 source/test/fixture/static-QA and UP2-01 archive hashes remain
the observed values recorded in the R2 manifest. No Julia/DESC process was
present during this review.

## Field-level disposition

### F03 — candidate binding, source-backed locator and baseline: changes requested

The repair correctly distinguishes the actual repository types. G1 retains
`QualifiedRefV1` and binds it to an independently stored public
`GenomeContractRef` with copied candidate id/version checks; G2 compares the
actual five-field `GenomeContractRef` exactly. The source locator, factory
input, fixed semantic projections, raw-source hash, semantic hash and parent
declaration hash are now explicit. This closes the R2 concerns about the
present-baseline recomputation algorithm.

The typed absent fallback is not closed across the identity graph. Both
`G1ParentEnvelopeV2`/`G2ParentEnvelopeV2` still require non-optional
`parent_declaration_hash`, `v1_baseline_hash` and `parent_binding_hash`. Both
`G1MechanismChildKeyV2`/`G2GeometryChildKeyV2` still require a non-optional
`parent_declaration_hash`. In contrast, `G1V1BaselineAbsentV2` and
`G2V1BaselineAbsentV2` deliberately have no declaration hash, baseline hash or
source/semantic hash. Therefore the stated current condition — no real V1
declaration instance — cannot produce a valid parent envelope and child key
that carries `typed_absent` plus `contract_admission=:terminal_deferred`.

The zero malformed transport key does not solve this: it is a receipt sentinel
for an invalid operation, not an identity for a real child with unavailable
baseline authority. The proposal needs one of the following explicit closed
shapes before dispatch:

1. a `G1/G2ParentEnvelopeAbsentV2` and corresponding absent parent/key union
   with an axis- and identity-bound absence hash; or
2. a single closed parent envelope whose baseline/declaration fields are
   present-or-typed-absent unions, with a specified `parent_binding_hash` and
   child-key recipe for the absent branch.

The absent branch must preserve candidate/public-contract binding and locator
identity, must not fabricate `parent_declaration_hash` or `v1_baseline_hash`,
and must derive its own absence hash without referring to a future child/state
hash. Only then is `terminal_deferred` representable without a synthetic
fixture.

### F04 — four provenance axes and absence: pass conditionally

Repair_r2 retains four distinct present slot types and a typed absent record
per axis, with axis, field, locator, source hash, candidate binding, parent,
child, contract identity and reason in the absence domain. The axes remain
independent and the missing-authority status remains separate from conflicts
and program exceptions. The slot contract is sufficient once the parent
absent identity described above is supplied; the unresolved parent absence
currently prevents a complete concrete instance.

### F05 — six hashes and digest-only history: pass

The six fixed-order, domain-tagged `Digest256` layers remain non-recursive.
The stored child identity, source record/content, initial state, operation and
result state are separated; history is bounded digest-only `NTuple` data and
does not embed state, payload, operation or receipt objects. The repair does
not reintroduce later-hash recursion. The absent parent branch should use an
additional explicitly named absence hash rather than overloading any of these
six layers.

### F06 — malformed receipt, truth table and dual CAS: pass

The deterministic zero operation IDs, zero child keys, typed zero digests and
empty canonical bytes close the pre-CAS malformed-input representation. The
receipt truth table rejects `rejected + none` and any `applied + non-none`
combination, while applied receipts alone publish and advance history. The
transition order is explicit: decode, snapshot, identity/hash checks, state
CAS, source CAS, semantic validation, local result construction, then one
publish. Rejected receipts never enter published state/history and preserve
prior bytes and SHA. The state-first/source-second stale distinction is now
closed.

### F07 — G2 public constructor versus wire decoder: pass

The repair resolves the prior inconsistency. The public mesh plan accepts only
`G2MeshExecutionNotExecutedV2`; a raw typed wire record carrying `"declared"`
is rejected by the controlled decoder with
`mesh_execution_status_invalid` before public construction. A valid typed
`not_executed` plan with `authority.mesh=:unique_match` remains
`terminal_deferred` with the separate gap `mesh_execution_not_executed`.
Neither path can promote execution or physical evidence.

### F08 — no-launcher exact scope: pass

No launcher is added. Direct future commands, source/test pairs, fixtures,
static QA and additive archive paths are named. The split baseline-binding
tests are appropriate because the source-backed present path and typed-absent
path require separate controls. No shared entry, core plan, task manifest or
old receipt is included.

## Dependency and claim boundary

The two sibling nodes remain acyclic. Each depends only on UP1-01/02/03 and
its own UP2-01 V1 contract; neither depends on the other sibling, T0, T1 or
T2. T0 remains transport owner, T1 remains the sole lossless package mapper,
and T2 remains downstream identity/receipt rebinding. No machine node is
created by repair_r2.

## Required next step and acceptance judgment

Because the repository currently has no real source-backed V1 declaration
instance, the architecture can be accepted later without inventing one, but
only after the absent identity path is made closed. The correct next step is a
narrow additive **source-backed baseline-binding/typed-absence envelope work
order**. It must freeze the present-or-absent parent envelope and child-key
recipe, without adding provider, mesh, physical or core authority.

After that schema is independently reviewed, a typed-absent scaffold may be
implemented first. It must emit only the absent baseline record and
`contract_admission=:terminal_deferred`; it must not publish a present child
or claim a real V1 declaration. A present implementation branch should wait
until a source-backed factory input and declaration receipt actually exist.

Therefore repair_r2 does **not** yet qualify for `pass_limited`: the missing
V1 instance alone would be compatible with a limited architecture acceptance,
but the repair's absent fallback is not presently representable in the parent
envelope and child-key types. Sol may accept an eventual architecture/work-
order boundary only after this narrow repair and a different-Luna review.

All implementation, actual-child, T0/T1/T2, UP2, provider, mesh,
engineering, physical, search, B00, B04 and R01-R10 credits remain false.
