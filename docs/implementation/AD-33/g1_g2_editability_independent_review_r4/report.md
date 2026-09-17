# AD-33 G1/G2 candidate-owned editability independent review R4

Date: 2026-09-15  
Reviewer: different `gpt-5.6-luna/high`  
Review basis: AD-33 repair_r3  
Decision: `changes_requested`  
Status: `review_pending=true`, `accepted=false`

## Scope and evidence boundary

This review is limited to the repair_r3 shared prerequisite, its Present/
Absent parent and child identity records, typed-absent-only state transitions,
and the sibling/T0/T1/T2 boundary. Current G1/G2 V1 source, tests and
archives were inspected as read-only inputs. No Julia, DESC, provider, mesh,
solver, physical, or heavy-Python execution was run. No core, source, test,
fixture, task manifest, AD-31/AD-32 artifact, or old receipt was changed.

Reviewed repair hashes:

* `repair_r3/revised_proposal.md`:
  `0e2d513ef488ce38836fc81139bfd68e395268e4250683a604d2bd69a406aced`;
* `repair_r3/manifest.json`:
  `75f773202d5a9225dd85c926c88acaac3f2b2a7e6577720502f7382f384b8689`.

No Julia/DESC process was present during the review. All implementation,
actual-child, provider, mesh, physical and R01-R10 credits remain false.

## Field-level disposition

### Shared prerequisite and dependency graph: pass

`UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC` is a sensible single additive
prerequisite. It depends on UP1-01/02/03 and both existing UP2-01 V1
contracts, is parallel with T0, and explicitly excludes T0/T1/T2 and both
editable siblings from its dependency set. G1 and G2 then depend on this
prerequisite plus their own V1 contract, remain siblings, and retain their
semantic ownership. The graph is acyclic and does not unlock T1 or T2.

### Present parent baseline binding: pass

`PresentParentBaselineBindingV1` has an explicit fixed field order containing
the actual parent ref, declaration hash, raw-source hash, semantic-body hash,
source locator, factory receipt, requested candidate, public contract and
parent binding hash. The parent binding hash has a domain, fixed order,
self/child/state/operation exclusions, and is recomputed from the
source-backed receipt. The factory receipt requires source-backed construction,
exact candidate binding and declaration-hash recomputation.

The G1 `QualifiedRefV1` versus independently bound public `GenomeContractRef`
relation and the G2 exact five-field equality are retained. A present value
still requires a real source-backed V1 declaration receipt; the proposal does
not turn the existing synthetic JSON fixtures into authority.

### Absent parent baseline binding: pass

`AbsentParentBaselineBindingV1` contains only layer, requested candidate,
requested public contract, closed reason, exact absence domain and absence
digest. It contains no actual parent ref, parent/declaration/baseline hash,
source locator, factory receipt or placeholder. The absence digest is bound to
layer, candidate, all public-contract fields and reason, and excludes future
child/state hashes. It maps to `contract_admission=:terminal_deferred`.

This closes the R3 identity-graph blocker: the absent branch is now a real
identity path rather than an absent record that cannot satisfy a non-optional
parent key.

### Present and absent child keys: pass

The present child key can only be constructed from a present parent binding and
recomputes its parent ref, parent declaration hash and child-key digest. The
absent child key contains requested candidate/public contract, child kind/id,
child-contract schema identity, the parent absence digest and its own digest;
it contains no parent ref/hash, baseline hash, source locator or factory
receipt. Its digest binds to the absent parent digest without referring to
future state or operation hashes.

### Typed-absent-only scaffold and failure atomicity: pass

The absent state carries the absent parent binding, absent child key, typed
absent source payload, `contract_admission=:terminal_deferred`, state hash and
canonical bytes. `replace_source_payload` is explicitly forbidden for an
absent state and returns `baseline_authority_absent`; no state or history
change is allowed, and prior canonical bytes/SHA remain unchanged. This is a
valid bounded scaffold contract and does not manufacture a present parent or
child.

### Absent-to-present transition: pass with a hard gate

The proposal correctly forbids CAS promotion and ordinary source replacement.
Absent-to-present requires a fresh source publication, fresh source/content and
child/state identities, a source-backed V1 declaration receipt, and a fresh
candidate identity review. The prerequisite itself cannot publish that present
object. Since the repository has no verified source-backed V1 instance, the
present branch remains blocked.

### Exact scope: changes requested

The shared prerequisite's future scope is mostly additive and has no launcher,
but its documentation entry is:

`docs/implementation/AD-33/g1_g2_editability_audit/**`

That directory contains the original AD-33 audit, repair_r1/r2/r3 proposals,
and independent review records. Treating the whole directory as a writable
fixture/static-QA scope is too broad and conflicts with the repair's own
promise to preserve those records. A future worker could overwrite historical
reports or mutate the review chain while still appearing to stay inside the
declared scope.

Minimum scope repair: replace the wildcard with a new dedicated archive path,
for example
`docs/implementation/UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC/`, and list any
fixture/static-QA files as exact paths or a newly created subdirectory owned by
that node. Preserve all existing AD-33 audit and repair paths read-only. The
no-launcher rule, direct future command, and source/test locations otherwise
remain acceptable.

## Acceptance judgment and next step

With the scope wildcard corrected, this architecture can receive
`pass_limited` for the shared prerequisite and sibling work-order boundary
only. The currently absent repository state does not prevent that limited
architecture acceptance because the absent parent/key/state path is now
closed. The immediately dispatchable work is the additive typed-absent
baseline-binding scaffold under the shared prerequisite.

No present child implementation or present source publication may be
dispatched. It remains blocked until a real source-backed V1 factory input and
declaration receipt exist, followed by fresh identity evidence and independent
review. Sol may accept only the corrected architecture/work-order boundary;
machine nodes remain uncreated and `accepted=false`.

## Claim ceiling

This review grants no implementation, actual child, T0/T1/T2, UP2, provider,
mesh, solver, engineering, physical, search, B00, B04 or R01-R10 credit.
