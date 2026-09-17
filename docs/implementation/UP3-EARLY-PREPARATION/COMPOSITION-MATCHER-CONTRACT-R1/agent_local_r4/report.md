# UP3 CompositionMatcher contract R4 — isolated import repair

Date: 2026-09-18 (Asia/Shanghai).

## Result

R4 is a minimal additive repair for the isolated-module load failure recorded
by R3. The source now explicitly imports every FusionConceptAI binding it uses:
`CapabilitySignatureV4`, `Digest256`, `PhysicalType`, `UnitSignature`,
`canonical_hash`, and `semantic_view`. This is necessary because
`CapabilitySignatureV4` is defined by the package but is not exported.

The test no longer relies on `using FusionConceptAI`; it explicitly imports its
fixture types/values and includes the source into
`CompositionMatcherIsolatedV1`. It asserts that the isolated module defines
the imported key types/functions before constructing matcher fixtures. Static
QA now checks the explicit source/test imports, rejects export-only loading,
and reports the R4 revision.

No shared entry, package export list, registry, task manifest, legacy matcher,
provider, mesh, solver, or physical path was changed.

## Failure being repaired

The parent-lane receipt
`runs/agent_local_up3_composition_matcher_contract_matrix_20260918_r3/`
records exit 1 before Test Summary with:

```text
UndefVarError: `CapabilitySignatureV4` not defined
... src/RuntimeV4/CompositionMatcherContractV1.jl:30
```

Its pre/post input hashes were unchanged. R4 addresses the missing binding
without changing matcher semantics.

## Static evidence and ceiling

```text
python -B test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
exit=0
PASS static_qa_composition_matcher_contract_v1_r4
```

`git diff --check` for the reviewed paths produced no output. Julia/DESC were
not run by this lane, so the focused Julia test remains a required next gate.
Maximum state remains `contract_only / prepared`, with
`accepted=false`, `formal_acceptance=false`, and no UP3, B01/B02/B04/B08,
conservation, convergence, engineering, or R01-R10 credit.
