# UP2-00G-I0 additive module seam

Status: `review_pending`; `accepted=false`.

This bounded implementation adds an idempotent UP2 module entry. It invokes
the existing G1/G2/G3 loader first, checks the published `(:G1, :G2, :G3)`
dependency order, and then registers the UP2 counter, contract, validator,
E0 bound-input, and N03–N10 definitions in a stable order. Sentinel checks
make a focused runner's prior individual include a no-op during a later shared
load. The entry defines no provider/compiler/solver/mesh/physical execution.

The two existing source edits are narrow registrations: `FusionConceptAI.jl`
includes the new entry and exports its status/order/load API; the existing
GenomeV5 integration file publishes the G1/G2/G3 order accessor. V4 behavior,
`default_operator_registry`, and old focused runners are untouched. E1 and E2
implementations are not changed or executed by this work order.

The new focused runner is prepared but intentionally not run. E1/E2 are still
mutable/review_pending and Sol has reserved runtime authorization for a later
serial gate. Static checks cover the source order, sentinel/idempotence guards,
JSON records, protected hashes, control characters, `validate_plan.py`, and
`git diff --check`. Repair R2 adds a real preloaded-counter identity test and a
fresh-process partial-include failure probe that observes the terminal `:failed` state and
same-process retry rejection. The zero-valued counter remains a constructor
and static wiring check, not a downstream spy. A runtime exit and independent Luna review are required
before any limited implementation acceptance.

This record carries wiring/contract evidence only. It does not accept UP2-00
overall, N05/N06, B00/B04, provider, mesh, engineering, physical, or R01–R10
credit. The UP2-00 → UP1-04B → UP1-04 → UP2-01 dependency route is unchanged.

See `evidence_manifest.json`, `after_snapshot.json`, and `bounded_diff.md`.
