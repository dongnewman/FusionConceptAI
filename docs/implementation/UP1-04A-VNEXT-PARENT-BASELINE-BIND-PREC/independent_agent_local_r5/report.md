# UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC — independent agent_local R5 review

Date: 2026-09-17 (Asia/Shanghai)
Reviewer: different Luna, high
Reviewed HEAD: `cfc745939a02fd023854dd04e9bb6d04ccadf9ee`
Verdict: **GO for one focused Julia run**
Claim ceiling: `prepare_only_runtime_input_adapter`, `accepted=false`, `present_authority=false`.

## Scope and boundary

This was an independent static review of the R5 minimum repair, focused test,
fixture/static QA, R1–R4 append-only evidence, and old R1 paths. Julia, DESC,
provider, mesh, solver, shared entry, and full regression were not run. No
product file, task manifest, public entry, old archive, or `runs/` path was
modified. Only this independent R5 report and manifest were created.

`GO` is limited to a single focused Julia contract run after this review. It is
not formal acceptance, present G1/G2 authority, T0/T1/T2, UP2, provider/mesh,
engineering/physical/search, B00/B04, or R01–R10 credit.

## Static QA, hash and archive evidence

Fresh reviewer command:

```text
python -B test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py
```

Result: exit `0`, `124/124`, Python
`D:\Users\Newman\anaconda3\python.exe`. The R5 worker receipt is process
exit `0`, raw stdout 554 bytes / SHA-256
`729502a9e1919d83ffee3d1784ea42f61fdaa112d57cc56035c904edb3f220db`, and
empty stderr SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

Reviewer-recomputed current R5 product hashes match the worker manifest:

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl` | 40070 | `a7292894315f450df5db94e436e764773e34b900e36ff80abb751a41c7aecf2e` |
| `test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl` | 23338 | `d510577bee27f6d89ede8bdfcac6960c89d88a166fbb6241bc94764eb32d0252` |
| `test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_fixture.json` | 2285 | `3d3237ff339885a7fe7c770342e2df676c15e369a31c29e8cb5c1364ebc2a547` |
| `test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py` | 7586 | `9dfbe705d646b8264328a50f12f56435f844c8f342d3cc3153b81e667f0b4a80` |

The four old R1 paths rehash unchanged: source
`feaa25406350f76c785fa02094af8744397874a94cfbd694360f310df41cb232`, test
`6b90804eb7e973995291fe56c7419af6a52697cea54d66b347a7ea3beeedeb0a`, fixture
`59aef733a1e140c9906a123cebe96fce1790418d6b17ee33de4b7db6d45d115b`, and
static QA `81141251e7f5780776a1b2fd87ad77287de824d28871d0089df00b9317979aac`.
R1–R4 evidence manifests/directories all parse as valid JSON and remain
preserved. R2–R4 product hashes are retained in their append-only manifests;
no independent old product-byte snapshots exist after each version replaced
the same product paths, so those historical values are not represented as new
byte rehashes. No hard-coded 64-hex upstream hash occurs in the R5 source, and
the public entry remains untouched/not importing the adapter.

The historical R1 boundary remains `38/38` static plus `52/52` focused Julia;
that is not a current R5 Julia result. No Julia was invoked by this reviewer.

## R5 repair verification

### Bundle hash is independently recomputed

`recompute_local_bundle_hash_v1` (source lines 653–658) calls the content
function `_vnl_bundle_hash(candidate, g1, g2)` rather than returning the stored
field. `verify_local_state_v1` (lines 690–705) requires the recomputed value to
equal `bundle.bundle_hash` before checking canonical bytes/SHA and state hash.
Thus changing `bundle_hash` and recomputing the outer canonical/state hashes is
not sufficient to pass.

### Bundle, G1, G2 and present/absent candidates are all joined

The same state verifier requires `bundle.candidate == bundle.g1.candidate` and
`bundle.candidate == bundle.g2.candidate` for both Present and Absent bundles.
The per-binding present verifier also keeps candidate equality through factory
receipt, typed review receipt, and parent-binding hash; the absent verifier
keeps the candidate in the absence digest. The bundle-level checks close the
R4 residual state gap without adding a promotion path.

### Recomputed negative controls are present

The test constructs a cross-candidate Present bundle, recomputes its bundle
hash, canonical bytes, canonical SHA and state hash, and expects
`verify_local_state_v1` to reject it. It separately constructs a tampered
bundle hash, recomputes canonical bytes/SHA/state hash around that tampered
bundle, and expects rejection. These controls exercise the exact attack that
was blocking R4; static QA requires `tampered_bundle`, `cross_candidate`,
`recompute_local_bundle_hash_v1`, and both bundle candidate fields.

The existing R4 closures remain present: child request layer/kind/id/contract
ref/hash joins enter the present value and parent hash; malformed absent
G1/G2/kind/nonempty-id/`terminal_deferred`/reason and self-consistent forged
digest controls reject; factory/review versions are exact LocalV1 domains and
future/stale controls fail closed.

## Exact focused Julia handoff

The single focused run, if the mainline releases it, should use exactly these
four inputs and a new output directory:

```powershell
python -B tools/agent_local_execution.py `
  --task UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC `
  --input src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl `
  --input test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl `
  --input test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_fixture.json `
  --input test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_local_v1.py `
  --output runs/agent_local_up1_04a_parent_r5_focused_julia_20260917 `
  --timeout 300 `
  --run C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe `
    --startup-file=no --project=. `
    test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl
```

Expected result: exit `0`, all focused tests pass, and the existing output
markers remain `VNEXT_LOCAL_PBB_R3_STATUS=contract_tests_defined`,
`VNEXT_LOCAL_PBB_R3_RUNTIME_INPUT_ONLY=true`, and
`VNEXT_LOCAL_PBB_R3_PHYSICAL_CREDIT=false`. The run must retain
`prepare_only`, `accepted=false`, `present_authority=false`, and no downstream
credit. The wrapper command is recorded for handoff only; it was not executed
in this review.

## Decision

R5 closes the remaining state-level blocker: bundle hash recomputation is
independent, bundle/G1/G2 candidate equality is enforced for both union arms,
and recomputed outer canonical/state hashes do not hide cross-candidate or
tampered bundle values. Static QA and current/old archive checks pass. **GO for
one focused Julia contract run only**, with the claim ceiling and acceptance
boundaries above unchanged. No commit was created.
