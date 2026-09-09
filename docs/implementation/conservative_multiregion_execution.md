# ConservativeMultiRegionExecutionV4

## Scope

This isolated Runtime V4 slice consumes one externally validated
`ForwardChainContextV4` and derives a typed multi-region execution contract
from its mechanism graph. It demonstrates that declared interface terms are
assembled into and executed through one global non-diagonal residual. It does
not implement a three-dimensional physical provider, engineering closure,
physical validation, or whole-device authority.

The source is intentionally not included in `FusionRuntimeV4.jl`. Integration
must wait until an actual downstream provider and the remaining chain
contracts are accepted.

## Typed ownership contract

The public declaration contains region IDs plus mechanism-node IDs and an
interface ID plus one exact typed interface edge and ledger identity. Contract
construction revalidates the complete `ForwardChainContextV4`, then derives
and seals:

- exact mechanism graph, node, hyperedge, AST-root/output, and physical-type
  identities through `ForwardGraphBindingV4`;
- at least two nonempty, disjoint regions that exactly cover every mechanism
  graph node;
- every typed interface flux pair, with one declaration per pair, distinct
  region owners, declared orientation, exactly opposite rational
  coefficients, and matching ledger/state units;
- a connected region-interface graph; and
- unique ownership for every source, sink, and boundary ledger occurrence.

Absent or incomplete structural capability is returned as a typed
`recoverable_gap`. This layer never emits terminal `unsupported`.

## Executed manufactured control

Each region balance has a positive finite lumped diagonal and an initial
value. Its right-hand side is not accepted from the caller: it is recomputed
from the exact ordered source/sink/boundary owners and their typed external
values. Admission and validation both repeat that derivation.

Each interface receives one positive finite coefficient. Assembly contributes
the four terms `(i,i,+k)`, `(i,j,-k)`, `(j,i,-k)`, and `(j,j,+k)` to the same
global matrix. Plan validation reconstructs that matrix and requires at least
two nonzero off-diagonal entries per interface. Execution evaluates the whole
global residual and applies the global linear correction; the trace validator
recomputes every residual and state transition.

The reported interface conservation defect is the cancellation of the two
exact opposite discrete interface contributions. It is a structural property
of this lumped manufactured operator, not a measurement of continuum,
three-dimensional, multiphysics, or device-level conservation.

## Identity, replay, and authority

The provider identity locks the source bytes, `Project.toml`, `Manifest.toml`,
Julia version, and algorithm label. Contract, plan, execution input, trace,
result, and receipt are content addressed. A cache hit is revalidated. Fresh
replay uses a new store and must reproduce result and receipt hashes, but it
remains the same implementation in the same process environment and is not
independent-code evidence.

All receipts have `model_class=:manufactured_control` and
`claim_ceiling=screen_only`. The manifest explicitly states
`emits_runtime_evidence=false`, `terminal_authority=false`, and
`credible_device_count=0`.

## Legacy reuse classification

| Legacy source | Extract | Wrap | Test-only | Reject |
|---|---|---|---|---|
| `multiregion_residual_compiler_v89.jl` | governing/additive/interface block vocabulary and paired-flux invariants | none | malformed topology and duplicate-ID intent | dictionaries, old plans, reduced result as physical evidence |
| `multiregion_interface_assembly_v93.jl` | monolithic residual and off-diagonal comparison intent | none | orientation and residual negatives | dense proxy as candidate backend or validation |
| `multiregion_conservation_providers_v116.jl` | oriented balance and refinement-test intent | none | analytic cancellation and replay intent | one-dimensional result as three-dimensional physical closure |

No legacy runtime object, Genome, authority, candidate preference, or family
router is imported.
