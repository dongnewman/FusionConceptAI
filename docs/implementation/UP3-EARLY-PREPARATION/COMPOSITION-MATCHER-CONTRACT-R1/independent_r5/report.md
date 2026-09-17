# UP3 CompositionMatcher contract R5 — independent static review

Date: 2026-09-18 (Asia/Shanghai). This review is read-only. It did not modify
the product, test, fixture, shared entry, registry, task manifest, or any
existing run, and it did not run Julia or DESC. No commit was created.

## Verdict

**GO for the next focused isolated Julia gate; NO-GO for runtime or formal
UP3 acceptance.** The R5 module-boundary repair is statically coherent and
the prescribed R5 static QA passed. The ceiling remains
`contract_only / prepared / accepted=false / formal_acceptance=false`.

## Static QA

Command:

```text
python -B test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
exit=0
PASS static_qa_composition_matcher_contract_v1_r5
```

The output is archived in `static_qa.stdout`; `static_qa.stderr` is empty.

## Module boundary checks

- `test/RuntimeV4/composition_matcher_contract_v1_tests.jl` includes
  `src/RuntimeV4/Contracts.jl` before
  `src/RuntimeV4/CompositionMatcherContractV1.jl` in
  `CompositionMatcherIsolatedV1`.
- The test checks `isdefined(M, ...)` and constructs the capability with
  `M.CapabilitySignatureV4`, so the binding comes from the preceding isolated
  Contracts include rather than package-root export visibility.
- The matcher imports only `Digest256`, `PhysicalType`, `UnitSignature`,
  `canonical_hash`, and `semantic_view` from `FusionConceptAI`.
- The matcher has no `CapabilitySignatureV4` package-root import and no
  `using FusionConceptAI`; no shared entry/export/registry change is present.
- Existing contract-only negative cases, deterministic ordering/identity
  checks, label/permutation erasure checks, and zero provider/solver
  invocation assertions remain statically required.

## R4 failure receipt and current hashes

The parent failure is preserved at
`runs/agent_local_up3_composition_matcher_contract_matrix_20260918_r4/`:

- `run.json` exit code `1`, `hashes_unchanged=true`.
- No test summary was reached; the raw stderr records the missing
  package-root `FusionConceptAI.CapabilitySignatureV4` and the resulting
  `UndefVarError` at the old isolated load boundary.

Current R5 bytes match `agent_local_r5/manifest.json`:

| Path | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/CompositionMatcherContractV1.jl` | 21055 | `c5da07f89bb89792c33f3afadd13a8e412a9f3350694f00b73d65a464e3637e4` |
| `test/RuntimeV4/composition_matcher_contract_v1_tests.jl` | 9224 | `37417092cedf01dd1fa85dddb6f62a1702973190be61376a245f428c33d3169a` |
| `test/RuntimeV4/composition_matcher_contract_v1_fixture.json` | 649 | `62ffa652ff0ec098837fb84015ffcfa581bd04f353e27287eb24252e92357edf` |
| `test/RuntimeV4/static_qa_composition_matcher_contract_v1.py` | 6027 | `db2b5b370ca519caea895b84a9267064a24157846f1900f6bbde351896084de6` |

The repository HEAD observed during review was
`23baee9f889713655b04f108f49f8dd0213e3ddf`.

## Boundary and next action

No Julia/DESC/runtime result is inferred from static QA. A different agent may
now run exactly one fresh focused isolated Julia contract test, preserving
the R5 input hashes and the `contract_only/accepted=false` ceiling. T0/T1/T2,
provider, solver, conservation, convergence, physical, engineering, and
R01--R10 credit remain unavailable.
