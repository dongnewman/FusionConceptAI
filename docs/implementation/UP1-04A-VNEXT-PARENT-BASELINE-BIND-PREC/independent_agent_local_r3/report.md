# UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC — independent agent_local R3 review

Date: 2026-09-17 (Asia/Shanghai)
Reviewer: different Luna, high
Reviewed HEAD: `cfc745939a02fd023854dd04e9bb6d04ccadf9ee`
Verdict: **NO-GO** for one focused Julia run
Implementation boundary: `prepare_only_runtime_input_adapter`, `accepted=false`, `present_authority=false`.

## Scope and boundary

This was a read-only static review of the R3 LocalV1 adapter, its focused test,
fixture, static QA, R3 worker evidence, R1/R2 independent records, AD-33, the
current local-execution contract, and the UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC
work order. I did not run Julia, DESC, a provider, mesh, solver, or a shared
entry. I did not edit product files, the task manifest, the public entry, old
R1/R2 records, or `runs/`. Only this report and its manifest are new.

The historical contract boundary is retained: this scaffold cannot close the
machine node, T0/T1/T2, UP2, provider/mesh/solver, engineering, physical,
search, B00/B04, or any R01-R10 credit. The current fixture is explicitly
runtime-input-only and does not establish G1/G2 authority.

## Evidence and hashes

Fresh reviewer command (Python only):

```text
python -B test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py
```

It exited `0` with `102/102`, interpreter
`D:\Users\Newman\anaconda3\python.exe`. No Julia invocation was made by this
review. The worker R3 static receipt is process-exit `0`, `102/102`, raw
stdout 554 bytes / SHA-256
`c3f6c07b10871a3f825adab70a63900876d27003c17c7897fc9b98d0d88f4701`, and empty
stderr SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

Reviewer recomputation of the current R3 product bytes matches the R3 worker
manifest:

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl` | 36759 | `2fd321cd172ab1912caf6f7d119b95b175ade8a7c999cf99ccf7e93a0321ef0a` |
| `test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl` | 16038 | `6a2f8db61d7cae6397b4c08f892b2275d7dae4b086ad88e85023b0340b808430` |
| `test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_fixture.json` | 1780 | `29a79ef7e7e4b3480c3cb55d4a49a4f2a51c16ca32c8c6e0828d2b4ad120c257` |
| `test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py` | 6583 | `94e862be2eb036509f228e642727a1c4faa8c957e2c34fc5eae580a6552b2c35` |

The four old R1 product paths remain byte/hash unchanged and independently
match their preserved R1 values: source
`feaa25406350f76c785fa02094af8744397874a94cfbd694360f310df41cb232`, test
`6b90804eb7e973995291fe56c7419af6a52697cea54d66b347a7ea3beeedeb0a`, fixture
`59aef733a1e140c9906a123cebe96fce1790418d6b17ee33de4b7db6d45d115b`, static QA
`81141251e7f5780776a1b2fd87ad77287de824d28871d0089df00b9317979aac`.

R2 product bytes are not archived as separate files in the work-order tree;
therefore the R2 values below are verified as the recorded hashes in both the
R2 worker manifest and the R2 independent manifest, not rehashed from a second
R2 byte copy: source
`55d2f60242af013b9b8f2ebb9874019f5d87906a01d0dd28fa03f1294fda2b98`, test
`85c14a10cf89805806a7c1d11551a32012a61fb357ffbc910121af9fce4d1753`, fixture
`61a169d8456c3d3437d62b1f633dcd25c7c43ffdec5cd094f26ed954689c51c3`, static QA
`b88c4e842ab0e9af234a567b6a277d56df0e378120646f156e7c5186cc35cc61`.

The retained AD-33/local scaffold evidence is the historical `38/38` Python
static check and `52/52` focused Julia result for the old R1 scaffold. They are
not claimed as execution of the R3 files. R3 has no focused-Julia result in
this review.

## What passes statically

1. `LocalParentBaselineBindingUnionV1` and
   `LocalParentBaselineBundleUnionV1` are explicit closed Present/Absent
   unions. The fixture remains `runtime_input_only`, `fixture_is_authority=false`,
   and contains no frozen 64-hex upstream hash. The additive adapter remains
   outside `src/FusionConceptAI.jl`.
2. Pure missing declaration records, a single declaration layer, empty
   children, and a single child layer are routed to
   `typed_absent/terminal_deferred`; the `_vnl_only_missing_errors` guard keeps
   duplicate, unknown, foreign, and hash contradictions on `fail_closed`.
3. Source bytes, source claimed/recomputed SHA, locator byte count/SHA, source
   and declaration refs, declaration/semantic bytes and hashes, factory receipt
   bytes/SHA, candidate/layer/axes/ref joins, and the typed candidate review
   receipt are checked in the binder. The public present verifier repeats the
   principal bytes/hash/locator/factory/review/axes/ref/parent-hash joins.
4. History is now included in canonical state bytes and state hash. CAS checks
   expected prior source hash, state hash, and history, and rejected receipts
   return copies of the prior canonical bytes, SHA, state hash, source hash and
   history without publication. Absent state rejects source replacement and the
   explicit absent-to-present function always throws.
5. No hard-coded upstream SHA-256 literal is present in the R3 source. The
   worker keeps `prepare_only_runtime_input_adapter`, `accepted=false`, and
   `present_authority=false`; this is the honest ceiling.

## Blocking findings

### P1 — child request is not bound to the declaration record or retained in the present verifier

`_vnl_child_errors` (source lines 363–384) checks only each request's own
layer/kind/id, duplicate layer/child, and
`child_contract_hash == child_contract_ref.content_hash`. The complete path in
`bind_local_parent_baseline_v1` (lines 555–575) selects records by record layer
but never compares a child request's `child_id`, `child_kind`, contract ref, or
contract hash with that layer's `LocalDeclarationRecordV1`. The present binding
type (lines 230–246) does not retain a child contract ref/hash, and
`verify_present_local_binding_v1` (lines 450–492) has no child argument or child
join to recheck.

Consequently, a batch with otherwise valid G1/G2 records can replace the G1/G2
children with different nonempty IDs and self-consistent child contract refs /
hashes and still reach `:present`. This violates the requested same-candidate/
layer/child binding and the work-order requirement for an actual child identity.
It is not covered by the current `bad_child` test, which changes only the
child-contract hash. Repair by carrying a candidate-bound child key/contract in
the record and present bundle, comparing each request to the corresponding
record before the present branch, including the child identity in the parent or
bundle hash, and adding a foreign-child-id/ref/hash negative test plus a public
verifier test.

### P1 — public absent verifier accepts malformed layer/child shapes

`verify_absent_local_binding_v1` (source lines 494–499) checks only
`resolution`, the absence-reason enum, and a digest recomputed from the supplied
fields. It does not require `layer ∈ (:G1, :G2)`, the layer-specific child kind,
or a nonempty child ID. A directly constructed absent value with `:G3`, an
arbitrary child kind/empty ID, and a matching digest therefore verifies even
though it is outside the closed G1/G2 union. The binder's own `_vnl_absent`
output is well-shaped, but the exported verifier is not a full verifier of the
public union/state. Add layer/child/id checks and direct malformed-absent
negative controls; then ensure state verification rejects the same controls.

### P2 — review/factory versions are only nonempty, not schema-bound

`LocalCandidateIdentityReviewReceiptV1` and `LocalFactoryReceiptV1` constructors
require nonempty versions, while the binder/public verifier only checks review
version nonempty and does not validate either version against a declared local
schema/factory version. The review version is included in the parent hash, but
the review bytes are not canonically tied to that metadata and factory version
is not in the parent-binding payload. A caller can supply an arbitrary future
version and recompute the surrounding hashes. Define and check the expected
version domains (and bind the factory version/review metadata into the canonical
receipt payload), with stale/future-version negative controls.

### P2 — R2 hash evidence has no archived R2 byte copy

The R2 manifests record four product hashes, but the work-order tree contains
no R2 product snapshots; the R3 checkout has already replaced those paths. Thus
R2 hash preservation can be checked only against the append-only manifest text,
not by a fresh hash of R2 bytes. Preserve a byte-level R2 snapshot or explicitly
label the existing values as manifest-recorded historical hashes in future
handoffs.

## Decision

The R3 repair is materially better than R2: missing-only cases now produce
typed absence, history/CAS/failure atomicity is represented, the review boolean
is replaced by a typed receipt, and the main public present joins are repeated.
However, the child cross-binding gap and malformed-absent public verifier are
contract-level fail-closed holes, not merely evidence wording issues. Therefore
the focused Julia gate is **NO-GO** until P1 findings are repaired and new
negative tests/static receipt are refreshed.

After repair, the permitted claim remains prepare-only, `accepted=false`,
`present_authority=false`, `accepted=false` at the machine node, and no
T0/T1/T2, UP2, provider, mesh, solver, engineering, physical, search, B00/B04,
or R01-R10 credit. No commit was created.
