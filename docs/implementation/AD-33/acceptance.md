# AD-33 acceptance — G1/G2 parent-baseline binding prerequisite

Date: 2026-09-15  
Decision owner: Sol/root  
Independent review: different `gpt-5.6-luna/high`, `pass_limited`; see [R5 review](g1_g2_editability_independent_review_r5/report.md)

## Limited acceptance

`AD-33` is accepted_limited for the architecture and finite work-order
boundary only. This acceptance creates exactly one machine work-order node:
`UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC`. The node remains
`planned`/`proposal`/`accepted=false`/`review_pending`; this record does not
accept its implementation or an actual G1/G2 child.

The accepted boundary inherits the reviewed R4 proposal and its R5
independent review. The shared prerequisite is the sole dispatchable future
node. G1 mechanism/source-body and G2 geometry/metric-boundary editability
remain reviewed future sibling nodes; no G1/G2 sibling machine node is created
by this synchronization.

## Frozen shared work order

The only future files owned by
`UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC` are:

1. `src/GenomeV5/Integration/VNextParentBaselineBindingV1.jl`
2. `test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_tests.jl`
3. `test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_fixture.json`
4. `test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_v1.py`
5. `docs/implementation/UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC/README.md`
6. `docs/implementation/UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC/manifest.json`
7. `docs/implementation/UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC/acceptance.md`

There is no launcher. The direct future focused command is
`julia --project=. test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_tests.jl`.
The fixture is expected-test data only and cannot be authority for a present
parent. The AD-33 audit, repair and independent-review history is read-only.

The machine node depends only on accepted `UP1-01`, `UP1-02` and `UP1-03`.
The G1/G2 V1 declaration paths are read-only inputs, not accepted dependency
nodes. The node is parallel to T0, AD-31 and AD-32; it must not unlock or
complete T0, T1 or T2.

## Typed-absent implementation ceiling

Before a real source-backed V1 declaration instance and factory receipt exist,
the maximum implementation is a typed-absent scaffold. It may emit
`AbsentParentBaselineBindingV1`, `AbsentChildKeyV1`, typed-absent source
payload/state and `contract_admission=:terminal_deferred`.

The absent branch contains no actual parent ref, parent declaration hash,
baseline raw/semantic hash, source locator, factory receipt or placeholder.
`replace_source_payload` is forbidden for absent state; it returns
`baseline_authority_absent`, does not advance state/history, and preserves
prior canonical bytes and SHA exactly. Absent-to-present is never CAS
promotion: it requires a fresh source publication, fresh child/state and
candidate identities, a source-backed V1 declaration/factory receipt, and a
fresh identity review.

Present G1/G2 parent binding, present child, source publication and
absent-to-present publication remain blocked on both V1 declaration tasks,
real source-backed factory/declaration receipts, and fresh candidate identity
review.

## Evidence ceiling

No Julia, DESC, provider, mesh, solver, engineering, physical or search
execution is part of this architecture acceptance. All actual, physical,
B00, B04 and R01–R10 credits remain false. This decision preserves the
existing DAG and all other nodes; it does not accept UP1-04A-VNEXT-T0/T1/T2,
UP2, or either G1/G2 edit sibling.
