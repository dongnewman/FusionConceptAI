# Implementation record

## Scope

Added only `VNextT1PackageBindingAdapterV1.jl` and its dedicated test,
fixture, independent Python oracle, static QA, and documentation directory.
The adapter recomputes the V5Next component identity and exact package hash
recipe before producing a V2 input.  It does not reconstruct or mutate a
package.

The recheck also compares stored layer-contract hash tuples with the
component-derived tuples, validates the frozen package metadata constants,
rebuilds the complete component-count receipt including feedback IDs, and
checks the T0 gate status/resolution/claim ceiling plus declaration, child,
feedback, prior-bundle, output-projection, and output-byte joins.

## Boundary behavior

- Valid closed package: result status `prepared_not_executed`, resolution
  `terminal_deferred`, explicit V2 input, `accepted=false`,
  `claim_ceiling=contract_only`.
- G3 child with `typed_absent`: result status `terminal_deferred` and
  `input=nothing`; no presence is fabricated.
- Status, structure, candidate identity, semantic identity, or package hash
  conflict: `fail_closed`, with no input.
- Optional V2 wire is carried by digest and never used as the package or
  receipt hash.

## Verification boundary

The independent oracle and static QA are intended to be run with
`python -B`.  Julia was not run by this implementation task, and no runtime,
registry, UP2, V4, provider, or physical evidence credit is claimed.

The focused Julia test source now constructs a real
`CandidateStatePackageV5Next` through the local source-backed admission
fixture and calls the adapter for valid, stale layer tuple, stale metadata,
stale count, stale T0 gate, and G3 typed-absent cases.  That test source was
not executed in this handoff.
