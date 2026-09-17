# AD-33 status synchronization R1

Date: 2026-09-15  
Decision: Sol/root accepts `accepted_limited` for the architecture and finite
work-order boundary only, based on independent R5 `pass_limited` review.

## Synchronized result

The only machine node created by this synchronization is
`UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC`, with:

    status=planned
    scope_status=proposal
    accepted=false
    resolution=review_pending
    claim_ceiling=contract_only

The node depends only on accepted `UP1-01`, `UP1-02`, and `UP1-03`. The G1/G2
V1 declaration source and archive paths are read-only inputs rather than
accepted dependencies. The node is parallel to T0, AD-31 and AD-32 and does
not unlock T0, T1 or T2.

The G1 mechanism/source-body and G2 geometry/metric-boundary edit precursors
remain reviewed future sibling nodes only. No G1 or G2 edit sibling machine
node is created in this synchronization. Their present branches remain blocked
until the corresponding real source-backed V1 instance and factory/declaration
receipt exist, followed by fresh same-candidate identity review.

## Exact future ownership

The shared node owns exactly these seven files:

* `src/GenomeV5/Integration/VNextParentBaselineBindingV1.jl`
* `test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_tests.jl`
* `test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_fixture.json`
* `test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_v1.py`
* `docs/implementation/UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC/README.md`
* `docs/implementation/UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC/manifest.json`
* `docs/implementation/UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC/acceptance.md`

No launcher is added. The future focused command is
`julia --project=. test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_tests.jl`.
AD-33 audit, repair and review history remains read-only.

## Implementation ceiling

The only permitted local implementation before a real V1 receipt exists is a
typed-absent scaffold. It may emit absent parent/child binding and
`contract_admission=:terminal_deferred`. It must not fabricate a parent ref,
parent declaration hash, baseline hash, source locator or factory receipt.

`replace_source_payload` is forbidden for absent state. It must return
`baseline_authority_absent`, preserve prior canonical bytes and SHA exactly,
and leave state/history unchanged. Absent-to-present requires a fresh source
publication, fresh child/state/candidate identities and fresh review; it is
never CAS promotion.

## Claim ceiling

All machine nodes remain `accepted=false`; no implementation, actual child,
source publication, T0/T1/T2, UP2, provider, mesh, solver, engineering,
physical, search, B00, B04 or R01–R10 credit is granted. The current
repository has no verified source-backed V1 declaration instance/factory
receipt, so present G1/G2 branches remain blocked.
