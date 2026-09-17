# M5 core performance R3 repair R2

This repair was an intermediate response to independent precheck R1.  It is
superseded by `repair_r3/`, which removes the ungrounded authority claim for
mutable module-local cache state.  It remains an UP5 early-preparation
implementation only; it does not alter the formal DAG, stage credit, public
entry points, manifests, or existing run evidence.

## Changes

- The earlier shadow-map/guard design was only a best-effort hint and must not
  be treated as an authority boundary; see `repair_r3/` for current
  canonical-output revalidation.
- A guarded cache fragment path supplies source/target/rule bytes and hashes to
  `ConditionalRewriteTraceStepV1` and `ConditionalEqualityProvenanceV1`.
  Proposal provenance therefore does not repeat typed-AST canonicalization,
  while the legacy constructor remains available and canonical field order is
  unchanged.
- The focused test now covers cold/hot equivalence and hashes for equivalence
  and attempt receipts, query/replay behavior, forced same-digest witnesses,
  cache isolation, mutation negatives, and deterministic sorted projections.

## Evidence boundary

No Julia process was started in this worker lane.  The repair evidence is
`screen_only / performance implementation pending runtime`; no frozen
canonical/hash, query/replay, runtime, allocation, or speed claim is made.
The deterministic `Dict` check is an equivalent sorted-projection proof in the
focused test, not a fresh-process measurement.

The known factorial root cause is intentionally not covered by this slice:
the first canonicalization of a new program still performs the exact graph
permutation search in `_tac_permutations`.  This repair removes repeated work
for the same immutable program during one derivation, but it does not replace
that exact search with a polynomial algorithm.  A separate architecture
decision and runtime profile are required before claiming factorial-root-cause
resolution.
