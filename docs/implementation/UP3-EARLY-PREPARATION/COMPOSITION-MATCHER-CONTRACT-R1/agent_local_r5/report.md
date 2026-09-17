# UP3 CompositionMatcher contract R5 — runtime module-boundary repair

Date: 2026-09-18 (Asia/Shanghai).

## Result

R5 is a minimal additive repair of the R4 isolated-load failure. The isolated
test now includes `src/RuntimeV4/Contracts.jl` before the matcher source. That
include establishes the local RuntimeV4 contract vocabulary, including the
non-exported `CapabilitySignatureV4`, without changing the package root or its
shared export/registry surface. `CompositionMatcherContractV1.jl` now imports
only package-core bindings (`Digest256`, `PhysicalType`, `UnitSignature`,
`canonical_hash`, and `semantic_view`) and does not import
`CapabilitySignatureV4` from `FusionConceptAI`.

The fixture constructor uses `M.CapabilitySignatureV4`, so the test proves the
type comes from the preceding isolated Contracts include. Static QA checks both
the include order and the forbidden package-root import, in addition to the
existing contract-only negative matrix and zero provider/solver assertions.

No shared entry, package export list, registry, task manifest, provider, mesh,
solver, or physical path was changed.

## Parent failure being repaired

The R4 receipt
`runs/agent_local_up3_composition_matcher_contract_matrix_20260918_r4/`
records exit code 1 before the test summary. Julia reported:

```text
WARNING: could not import FusionConceptAI.CapabilitySignatureV4
ERROR: LoadError: UndefVarError: `CapabilitySignatureV4` not defined
... src/RuntimeV4/CompositionMatcherContractV1.jl:36
```

Its `run.json` records `hashes_unchanged: true`. R5 addresses the module
boundary rather than adding a root export or modifying matcher semantics.

## Static evidence and ceiling

**R5 verdict: GO for the isolated static handoff; NO-GO for runtime or formal
UP3 acceptance.**

```text
python -B test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
exit=0
PASS static_qa_composition_matcher_contract_v1_r5
```

The static checks were run in a fresh Python process. Julia and DESC were not
run by this lane, and no runtime result or physical/engineering evidence is
claimed. The maximum state remains `contract_only / prepared`, with
`accepted=false`, `formal_acceptance=false`, and no UP3, B01/B02/B04/B08,
conservation, convergence, engineering, or R01-R10 credit. A different agent
must run the focused Julia process and independently review this slice before
any runtime gate is advanced.

## Current reviewed files

| Path | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/CompositionMatcherContractV1.jl` | 21055 | `c5da07f89bb89792c33f3afadd13a8e412a9f3350694f00b73d65a464e3637e4` |
| `test/RuntimeV4/composition_matcher_contract_v1_tests.jl` | 9224 | `37417092cedf01dd1fa85dddb6f62a1702973190be61376a245f428c33d3169a` |
| `test/RuntimeV4/composition_matcher_contract_v1_fixture.json` | 649 | `62ffa652ff0ec098837fb84015ffcfa581bd04f353e27287eb24252e92357edf` |
| `test/RuntimeV4/static_qa_composition_matcher_contract_v1.py` | 6027 | `db2b5b370ca519caea895b84a9267064a24157846f1900f6bbde351896084de6` |
