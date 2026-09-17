# UP2 SpatialTopologyTransferContractV1 — agent_local R3 repair

## Status

R3 blocker repair is complete and is **pending different-Luna static review**.
The slice remains additive, `contract_only`, `screen_only`,
`accepted=false`, with no formal, numerical, physical, UP2, provider, mesh,
solver, or R01–R10 credit. Julia/DESC were not run.

## Implemented repairs

1. Added `_sttc_effect_sort_key` as the canonical total-order key.  It retains
   transfer/account/orientation and now includes `signed_value` plus the full
   unit identity: `unit.name`, all seven `unit.exponents`, and
   `unit.scale_to_si`.  This makes legal tied effect keys deterministic rather
   than relying on caller order.
2. Added a tied-key positive permutation vector: two same
   transfer/account/orientation minus effects with different signed values,
   plus the closing target effect.  Both caller permutations must validate and
   produce identical canonical JSON and hash.
3. Each witness effect now calls the complete `_sttc_valid_unit` validator,
   including the unit name check.  Added a real negative vector with an empty
   effect unit name, expected to fail closed with `:unit_mismatch`.
4. Updated fixture policy and vector counts (`1` tied-key permutation positive,
   `1` malformed effect-unit negative, total `2`) and expanded static QA to
   require the new source/test/fixture contracts.

## Static evidence

```text
python -B test/RuntimeV4/UP2SpatialTopologyTransfer/static_qa_spatial_topology_transfer_contract_v1.py
```

Result: exit `0`, `124/124`, no errors.  The QA remains text/JSON-only and
does not invoke Julia, DESC, providers, a mesh, or a solver.  Provider, mesh,
and solver counters remain zero in the contract boundary.

The root slice manifest still records the historical R1 `92/92` hashes and is
not overwritten.  Current R3 bytes and hashes are recorded in this
`agent_local_r3/manifest.json`; different-Luna review must use those current
hashes.

## Boundary

Only the owned source/test/fixture/static-QA files and this new R3 archive were
changed.  Shared entry, registry, compiler, old V4, runs, task manifest and
the historical root manifest were not modified.  The serialized Julia lane
remains deferred until the independent review completes; even a passing lane
cannot grant mesh, solver, physical, engineering, UP2 total, or R01–R10 credit.
