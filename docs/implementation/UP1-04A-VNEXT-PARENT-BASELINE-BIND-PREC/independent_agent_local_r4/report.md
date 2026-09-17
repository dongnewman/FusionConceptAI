# UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC — independent agent_local R4 review

Date: 2026-09-17 (Asia/Shanghai)
Reviewer: different Luna, high
Reviewed HEAD: `cfc745939a02fd023854dd04e9bb6d04ccadf9ee`
Verdict: **NO-GO** for one focused Julia run
Claim ceiling: `prepare_only_runtime_input_adapter`, `accepted=false`, `present_authority=false`.

## Scope and execution boundary

This review only checked closure of the three R3 blockers, the R4 local test/
fixture/static-QA evidence, the R3/R2/R1 append-only records, and the state
integrity surrounding those joins. It did not run Julia, DESC, a provider,
mesh, solver, shared entry, or full regression. No product file, task manifest,
public entry, old archive, or `runs/` path was changed. Only this independent
R4 report and manifest are new.

## Reproduced evidence and hash checks

Fresh static command:

```text
python -B test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py
```

Result: exit `0`, `118/118`, Python
`D:\Users\Newman\anaconda3\python.exe`. The worker R4 process receipt is
exit `0`, raw stdout 554 bytes / SHA-256
`18109d5453cafd89b513a74a6829195d799f5c520baaff51ed90fa729f9f6ecd`, and
empty stderr SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

Reviewer-recomputed R4 product hashes match the worker manifest:

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl` | 39380 | `5624ba859b425d3a6add9c67b41664e0d791715fa3307c2f883cb823aa1d17e8` |
| `test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl` | 21906 | `c6eb168e2ebe2e53de7bacfa89b70df4fc9f028708def7e2becd35d7853bc80e` |
| `test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_fixture.json` | 2210 | `225b68f7281cfb74004cf42dec642dd8be6b07cdab5274d116990977e01c1c13` |
| `test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py` | 7440 | `7d859427db92be59ed3e2e09cfab24be8fcc376057d5a0f841d694f2210bbefa` |

The old R1 four-file paths still rehash to the preserved values: source
`feaa25406350f76c785fa02094af8744397874a94cfbd694360f310df41cb232`, test
`6b90804eb7e973995291fe56c7419af6a52697cea54d66b347a7ea3beeedeb0a`, fixture
`59aef733a1e140c9906a123cebe96fce1790418d6b17ee33de4b7db6d45d115b`, static
QA `81141251e7f5780776a1b2fd87ad77287de824d28871d0089df00b9317979aac`.
The R2 and R3 product hashes remain present in their append-only manifests and
the R1/R2/R3 evidence directories remain read-only; no separate R2/R3 product
byte snapshots exist to rehash after those paths were overwritten by R4.
R3's recorded product hashes were not silently treated as fresh R4 bytes.

The historical old-R1 software evidence remains `38/38` static and `52/52`
focused Julia. Those are not R4 execution results. No Julia was invoked in
this review.

## R3 blocker closure checks

### Closed: child request to declaration/present binding

R4 adds `child_contract_ref` and `child_contract_hash` to
`LocalDeclarationRecordV1` and `PresentLocalParentBaselineBindingV1`. The
record structural checks validate the record's child contract hash against its
ref. `_vnl_record_child_binding_errors` (source lines 404–421) compares the
matching layer's request against the declaration record on child kind, child
ID, contract ref, and contract hash before the present branch. The parent
binding hash carries the child ref/hash (lines 449–466), and the public present
verifier checks the stored child kind/id/ref/hash (lines 490–537). The tests
cover a foreign child ID and a foreign contract ref; the fixture lists both
controls. Pure missing material still remains typed absent because the binding
join adds no error when its expected layer is genuinely absent.

This closes the specific R3 child cross-binding finding for the binder and the
stored present value. The type still has no separate child candidate field;
candidate ownership is inherited from the batch/record candidate and should
remain explicit in any later package integration.

### Closed: absent shape and self-consistent forged digest

`verify_absent_local_binding_v1` (lines 539–548) now rejects non-G1/G2 layers,
wrong layer-specific child kind, empty child IDs, non-`terminal_deferred`
resolution, and reasons outside the closed absence set before recomputing the
absence digest. The R4 tests construct both a G3/empty-ID self-consistent
digest and a G1/wrong-kind self-consistent digest; both direct verification and
canonical-state verification are expected to reject them. The canonical
`_vnl_absent` path produces nonempty G1/G2, layer-specific kinds and
`terminal_deferred` as required.

### Closed: LocalV1 factory/review version domains

R4 declares exact domains:

```text
GenomeV5/Integration/VNextParentBaselineBindingLocalV1/factory-v1
GenomeV5/Integration/VNextParentBaselineBindingLocalV1/review-v1
```

The structural binder and public present verifier require exact equality to
those domains. The test covers a future factory version and stale review
version; both bind and public verification paths fail closed. The fixture and
static QA also require these version domains. The factory version is validated
as an invariant (the review version is also included in the parent-binding
payload), so future/stale versions cannot enter a present value.

## Residual blocking finding

### P1 — state verifier does not verify bundle hash or bundle-level same-candidate binding

`verify_local_state_v1` (source lines 684–697) verifies the canonical bytes,
canonical SHA, state hash, and each `g1`/`g2` binding, but never recomputes
`bundle.bundle_hash` with `_vnl_bundle_hash(bundle.candidate, bundle.g1,
bundle.g2)`, and never checks `bundle.candidate == bundle.g1.candidate ==
bundle.g2.candidate`. `_vnl_bundle_hash(x::Present...)` and
`_vnl_bundle_hash(x::Absent...)` merely return the stored field (lines
647–651), so the state-byte/state-hash derivation also commits the supplied
bundle hash without proving that it is the content-derived hash.

An adversarial caller can therefore directly construct a bundle with a foreign
bundle candidate, cross-candidate G1/G2 bindings, or an arbitrary bundle hash,
recompute canonical bytes/SHA/state hash, and have `verify_local_state_v1`
accept the state because the per-binding verifiers still pass. The normal
`bind_local_parent_baseline_v1` path catches G1/G2 candidate mismatch, but the
public state verifier does not preserve that guarantee. This is a state-level
same-candidate and bundle-integrity hole, so the focused Julia gate remains
NO-GO.

Repair by adding a closed bundle verifier (or equivalent checks inside
`verify_local_state_v1`) that enforces bundle candidate equality for both
Present and Absent bundles and recomputes the corresponding bundle hash. Add
direct positive/negative tests for foreign bundle candidate, cross-candidate
G1/G2, and tampered bundle hash with recomputed canonical state bytes/hash;
then refresh static QA and receipts.

## Focused Julia handoff (not released by this review)

After the residual P1 repair and fresh independent review, the exact local
wrapper inputs should be the four current R4 product paths:

```text
src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl
test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl
test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_fixture.json
test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py
```

The not-yet-released wrapper command should use a new output directory and the
actual Julia executable, without modifying old runs:

```powershell
python -B tools/agent_local_execution.py `
  --task UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC `
  --input src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl `
  --input test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl `
  --input test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_fixture.json `
  --input test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py `
  --output runs/agent_local_up1_04a_parent_r4_focused_julia_20260917 `
  --timeout 300 `
  --run C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe `
    --startup-file=no --project=. `
    test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl
```

Expected output, after repair only, is exit `0` with all Julia tests passing
and the existing markers (`VNEXT_LOCAL_PBB_R3_STATUS=contract_tests_defined`,
`VNEXT_LOCAL_PBB_R3_RUNTIME_INPUT_ONLY=true`,
`VNEXT_LOCAL_PBB_R3_PHYSICAL_CREDIT=false`). The wrapper must preserve
`prepare_only`, `accepted=false`, `present_authority=false`, and no T0/T1/T2,
UP2, provider, mesh, solver, engineering, physical, search, B00/B04 or R01-R10
credit.

## Decision

The three requested R3 blocker closures are statically present and covered by
R4 negative controls. Nevertheless, the public state verifier can accept a
cross-candidate or tampered-bundle state after an attacker recomputes its
canonical bytes/hash. This is a remaining contract-level integrity gap, so the
focused Julia command is **NO-GO** until the bundle candidate/hash repair and
fresh receipt are supplied. No commit was created.
