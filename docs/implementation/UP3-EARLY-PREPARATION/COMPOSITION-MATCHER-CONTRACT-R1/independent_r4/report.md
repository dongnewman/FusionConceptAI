# UP3 CompositionMatcherContractV1 independent review R4

Date: 2026-09-18 (Asia/Shanghai). This is a read-only independent static
review of the R4 isolated-import repair. No product or test file was modified,
no Julia/DESC/provider/solver command was run, and no commit was created.

## Verdict

**GO for the next isolated Julia contract-test gate; NO-GO for formal UP3
acceptance.** The additive source and isolated test now explicitly import the
package bindings they use, and the test checks the key names inside its fresh
module. The R3 import failure is addressed at the source boundary. This does
not grant provider, solver, mesh, physical, conservation, convergence,
engineering, or R01--R10 credit.

## Static QA

Command executed:

```text
python -B test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
exit=0
PASS static_qa_composition_matcher_contract_v1_r4
```

The checker is static and does not invoke Julia, DESC, providers, meshes, or
solvers.

## Import and isolated-module audit

The source explicitly imports every non-Base package binding used by the
additive module:

```julia
import FusionConceptAI: CapabilitySignatureV4, Digest256, PhysicalType,
    UnitSignature, canonical_hash, semantic_view
```

Manual identifier scanning confirms these are the only unqualified
`FusionConceptAI` bindings used by the source. The source contains no
`using FusionConceptAI` and therefore does not depend on package export
visibility; notably, `CapabilitySignatureV4` is not exported by the shared
package.

The test explicitly imports its package fixture dependencies
`CapabilitySignatureV4`, `Digest256`, `PhysicalType`, `UnitSignature`,
`TemporalTypeV1`, `static_time`, and `screen_only`. It includes the source
inside `module CompositionMatcherIsolatedV1`, binds `M` to that module, and
asserts `isdefined(M, name)` for the six source-side key bindings:
`CapabilitySignatureV4`, `Digest256`, `PhysicalType`, `UnitSignature`,
`canonical_hash`, and `semantic_view`. It then calls matcher APIs through `M`.
The test contains no `using FusionConceptAI` fallback and no shared-entry
lookup for matcher symbols.

## Shared-boundary audit

The R4 source is an additive standalone file. The shared
`src/FusionConceptAI.jl` entry, export list, default registry, task manifest,
and provider/solver paths were not modified. The current shared-entry hash is
`e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783`; the
targeted `git diff --name-only` query reports no shared-entry path.

## R3 failure receipt

The preserved parent receipt is
`runs/agent_local_up3_composition_matcher_contract_matrix_20260918_r3/`.
Its Julia command exited `1` before Test Summary with:

```text
UndefVarError: `CapabilitySignatureV4` not defined
... src/RuntimeV4/CompositionMatcherContractV1.jl:30
```

The R3 `input_hashes_pre.json` and `input_hashes_post.json` are byte-identical
for all four reviewed paths. R4 changes the source/test import boundary and
does not overwrite this historical failure receipt.

## Current input hashes

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/CompositionMatcherContractV1.jl` | 20946 | `725ff6d2d84d292576b7737dfeec0b352f05a43e017be2642f39ead8c5e1f9b0` |
| `test/RuntimeV4/composition_matcher_contract_v1_tests.jl` | 9169 | `9157058e85405dd08445e7cd542a601c17621f96fe7a7edb0e4e043910e302ee` |
| `test/RuntimeV4/composition_matcher_contract_v1_fixture.json` | 649 | `62ffa652ff0ec098837fb84015ffcfa581bd04f353e27287eb24252e92357edf` |
| `test/RuntimeV4/static_qa_composition_matcher_contract_v1.py` | 5191 | `df565496f587bd0380401565523bca2d41714ef0b81ccfd2f13ea3098cf5e67a` |

## Next gate

Run the isolated Julia contract test in a fresh process once, retaining stdout,
stderr, exit code, process receipt, and before/after hashes. Even if that gate
passes, the slice remains `contract_only / prepared / accepted=false`; no
formal UP3 or physics credit follows from this static review.
