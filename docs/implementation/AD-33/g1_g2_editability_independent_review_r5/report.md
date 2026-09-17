# AD-33 G1/G2 candidate-owned editability independent review R5

Date: 2026-09-15  
Reviewer: different `gpt-5.6-luna/high`  
Review basis: AD-33 repair_r4  
Decision: `pass_limited`  
Status: `review_pending=true`, `accepted=false` for machine nodes

## Scope and evidence boundary

This final review verifies that repair_r4 inherits repair_r3 and only narrows
the shared prerequisite documentation scope. I also rechecked the current G1
and G2 V1 source/test/archive records and the previously accepted identity,
typed-absent, operation and dependency boundaries. No Julia, DESC, provider,
mesh, solver, physical, or heavy-Python execution was run. No core, source,
test, fixture, task manifest, AD-31/AD-32 artifact, or old receipt was changed.

Repair_r4 hashes:

* `repair_r4/revised_proposal.md`:
  `40a87333d16f71fe306ba014c0c026b998c18c032b462f8e551adeb9206deea3`;
* `repair_r4/manifest.json`:
  `84731b35e4ac5b5b83dfef53cc817dfbdb2ab3d6a690d74be36e563e3f0a9c85`.

The review found no Julia/DESC process. The current repository still has no
verified source-backed V1 declaration instance and factory receipt.

## Scope-only repair verification

The proposal diff from repair_r3 changes only the repair heading/review basis
and adds the explicit statement that the dedicated prerequisite archive does
not include the AD-33 audit history. The manifest changes only its revision
identity/review hashes, splits the future scope into exact categories, and
records the forbidden historical path. No semantic identity, hash, state,
operation, negative-control, DAG, or credit rule drifted.

The shared prerequisite now has this exact future scope:

| category | exact paths |
| --- | --- |
| source | `src/GenomeV5/Integration/VNextParentBaselineBindingV1.jl` |
| test | `test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_tests.jl` |
| fixture | `test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_fixture.json` |
| static QA | `test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_v1.py` |
| archive | `docs/implementation/UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC/README.md`, `manifest.json`, `acceptance.md` |

There is no launcher. The former broad
`docs/implementation/AD-33/g1_g2_editability_audit/**` path is explicitly
forbidden. Existing AD-33 audit, repair and independent-review records remain
read-only, so old evidence cannot be overwritten by the shared prerequisite.

## Boundary verification

The following items remain closed from R3:

* `PresentParentBaselineBindingV1` has exact fields and a non-recursive,
  source-backed parent binding hash. G1 keeps the actual `QualifiedRefV1`
  while its public `GenomeContractRef` binding is independent and exact; G2
  compares the actual five-field public contract.
* `AbsentParentBaselineBindingV1` has no parent ref, declaration/baseline
  hash, source locator, factory receipt or placeholder. Its separate absence
  digest is bound to layer, requested candidate, public contract and reason,
  and resolves to `contract_admission=:terminal_deferred`.
* Present child keys require a present parent binding. Absent child keys carry
  only requested identity, child schema identity and the parent absence digest;
  they contain no present parent or baseline fields.
* The typed-absent scaffold has a typed-absent source payload,
  `terminal_deferred` state and canonical bytes. `replace_source_payload` is
  forbidden, returns `baseline_authority_absent`, does not advance history,
  and preserves prior bytes/SHA atomically.
* Absent-to-present is a fresh source publication with a fresh child/state
  identity and candidate review. It is never a CAS promotion or ordinary
  source replacement.
* The shared prerequisite depends on UP1-01/02/03 and both existing UP2-01
  V1 contracts, is parallel with T0, and must not depend on T0/T1/T2 or either
  sibling. G1/G2 depend on the shared prerequisite plus their own V1 contract;
  the graph remains acyclic.

## Limited acceptance and execution gate

The repair is sufficient for `pass_limited` acceptance of the additive
architecture/work-order boundary. Sol may accept the shared prerequisite and
the two sibling work-order boundary records after this review. The only
dispatchable implementation before a real V1 receipt exists is the shared
typed-absent baseline-binding scaffold, with static QA and focused contract
tests confined to the exact paths above.

The present G1/G2 child branches remain prohibited. A present parent binding,
present child, source publication or absent-to-present publication requires a
real source-backed V1 factory input and declaration receipt, fresh candidate
identity evidence, and another independent review. The repository's current
absence therefore changes the permitted implementation branch, not the
architecture claim ceiling.

## Claim ceiling

`pass_limited` here means architecture and finite work-order boundary only. It
does not accept an implementation, actual G1/G2 child, T0/T1/T2, UP2,
provider, mesh, solver, engineering, physical, search, B00, B04 or R01-R10
credit. Machine nodes remain uncreated and `accepted=false`; all actual and
physical credits remain false.
