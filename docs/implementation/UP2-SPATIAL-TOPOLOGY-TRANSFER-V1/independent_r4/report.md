# UP2 SpatialTopologyTransferContractV1 — independent R4 review

## Verdict

**GO for one direct serialized focused Julia gate.** The R3 repairs are
present in the current owned source/test/fixture/static-QA files, and the
read-only Python QA passes `124/124`. This is only a gate recommendation:
the slice remains `contract_only`, `screen_only`, `accepted=false`, with no
UP2-total, provider, mesh, solver, physical, engineering, or R01–R10 credit.

The permitted next command is exactly:

```text
julia --startup-file=no --history-file=no --project=. test/RuntimeV4/UP2SpatialTopologyTransfer/spatial_topology_transfer_contract_v1_tests.jl
```

It must run serially as the focused lane. This review did not invoke Julia or
DESC.

## R3 controls verified statically

1. `_sttc_effect_sort_key` orders by transfer ref, account ref, orientation,
   `repr(signed_value)`, unit name, all seven unit exponents, and
   `repr(unit.scale_to_si)`. The key therefore covers the requested signed
   value and complete unit identity.
2. The positive tied-key vector uses two legal effects with the same
   transfer/account/orientation and different signed values, plus the closing
   target effect. Both caller permutations are validated and assert identical
   canonical JSON and hash.
3. `validate_spatial_topology_transfer` calls `_sttc_valid_unit(effect.unit,
   ...)` for every effect. The test constructs an empty-name effect unit and
   asserts `:unit_mismatch`.
4. The static QA executed read-only with exit `0`, reporting `124/124` checks
   and no errors. Fixture vector counts record one positive permutation and one
   malformed-unit negative. Test assertions keep `provider_calls`,
   `mesh_calls`, and `solver_calls` equal to zero.

The source remains standalone and does not include the shared entry, registry,
provider, mesh, or solver. The root manifest was not rewritten.

## Root manifest drift

`docs/implementation/UP2-SPATIAL-TOPOLOGY-TRANSFER-V1/manifest.json` still
records the historical R1 hashes and `92/92`. It is intentionally preserved as
historical provenance. Current R3 hashes match
`agent_local_r3/manifest.json`; synchronization belongs to the owning lane,
not this independent review.

## Static command result

```text
python -B test/RuntimeV4/UP2SpatialTopologyTransfer/static_qa_spatial_topology_transfer_contract_v1.py
exit=0
checks=124
passed=124
errors=[]
julia_invoked=false
desc_invoked=false
provider_mesh_solver_invoked=false
```

## Current input hashes

| path | bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/SpatialTopologyTransferContractV1.jl` | 29346 | `57915e122e8d9211f732e9e8abea468fb20aa3b74d111fe938ff5e8584ebec34` |
| `test/RuntimeV4/UP2SpatialTopologyTransfer/spatial_topology_transfer_contract_v1_tests.jl` | 15350 | `920f0c0e43c103f93bc58991be04492d139fff8060e6d465c689343d43d6967c` |
| `test/RuntimeV4/UP2SpatialTopologyTransfer/spatial_topology_transfer_contract_v1_fixture.json` | 1636 | `4ddcb561170ba260f3ef73f7e2f68bf5dc3fd66a6be7a30260e93aead455593f` |
| `test/RuntimeV4/UP2SpatialTopologyTransfer/static_qa_spatial_topology_transfer_contract_v1.py` | 6613 | `fa79dda76894fe5d05a76cd59ecb4a04447724e5f6c7046f8249b6f5479466b2` |

Protected current hashes observed during review:

- `src/FusionConceptAI.jl`: `e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783`
- `src/IR/OperatorRegistry.jl`: `4c2f4383140527613782288749283d268497846ec915df158164875125677f45`
- `docs/v4_multitopology_generation/task_manifest.json`: `84af082ba5fff336dd89ae506f6b8e680f96f0af2e657ae926d6e9cc666fd6ad`

No product/test files, root manifest, shared entry, registry, task manifest,
runs, or commit were modified by this review.
