# RuntimeV4 multi-region law-set compiler

## Purpose

`ThreeDRegionLawSetCompilerV4.jl` closes the structural gap left by the
single-region law compiler. It declares exactly one constitutive, one source,
and one boundary `AtomicMIMOHyperedgeV1` law for every region in one accepted
oriented G2 declaration. The declaration normalizes caller selectors to the
oriented region order.

## Exact-cover and identity rules

- At least two distinct oriented regions are required.
- Selector region IDs must equal the oriented region set, with no missing,
  duplicate, or extra region.
- Every law edge is typed, has one region-owned input, and has the required
  output node kind.
- All law edge, AST-root, and output-node identities are globally unique
  across the complete set.
- The set declaration is stored in the current field/geometry Genome and is
  rebuilt from the current G2 graph before compilation.

## Current-context binding

`ThreeDRegionLawSetBindingV4` seals the candidate, compiled prefix, G2 Genome
and graph, law-set and oriented declarations, oriented binding, ordered region
and law identities, mission, bounds, and scenario. Compilation accepts exactly
one current declaration and one current binding of both typed kinds. Missing
generic inputs return exact recoverable gaps; ambiguous, shared, foreign, and
forged inputs fail closed.

The binding validator compares the already sealed oriented binding and law-set
binding directly with the current declaration reconstruction. It deliberately
does not reconstruct the compiled prefix or call the oriented binding factory
again; the enclosing `ForwardChainContextV4` owns that expensive validation.

## Authority boundary

This slice is a manufactured typed-input compiler. It selects and executes no
provider or solver, emits no evidence, grants no pass or promotion authority,
and cannot establish P5 or terminal readiness. Its claim ceiling is
`screen_only`, and credible physical-device count is zero.

## Isolated files

The implementation consists of one source file, one example, one focused test,
one runner, this note, and one dated report. It changes no existing composer,
include graph, registry, or production runner.
