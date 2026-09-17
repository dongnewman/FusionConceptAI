# UP2-00G-I0 additive module seam

Status: `accepted_limited`; `accepted=true`.

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

The authorized focused R3 runtime completed with real exit `0` and `26/26`,
including preloaded-counter identity/idempotence and the isolated partial-include
failure probe (`:failed` plus same-process retry rejection). The different-Luna
independent postrun R3 review is `pass_limited`; its receipt and raw hashes are
linked by `evidence_manifest.json`. The zero-valued counter remains a constructor
and static wiring check, not a downstream spy. Historical R1 evidence and the R2
hold remain preserved; R3 is the accepted corrected runtime receipt.

This record accepts only additive loader wiring, idempotence, and failure-state
software behavior. It does not accept UP2-00 overall, N05/N06, B00/B04,
provider, mesh, engineering, physical, or R01–R10 credit. The UP2-00 →
UP1-04B → UP1-04 → UP2-01 dependency route is unchanged.

See `evidence_manifest.json`, `after_snapshot.json`, and `bounded_diff.md`.
