# RuntimeV4 3-D physical-input composition

## Purpose

`ThreeDPhysicalInputCompositionV4.jl` joins five accepted typed 3-D input
slices plus an explicit structural support mapping. It does not copy outputs
from their independent examples. One current `CandidateStatePackageV4`, one
compiled prefix, one scenario, and one `ForwardChainContextV4` subject must own
and reconstruct:

1. the Fourier boundary, coordinate/metric, and profiles/flux declaration;
2. a candidate-owned mapping from the physical coordinate/metric support to
   every oriented region and its declared support;
3. the exact-cover region constitutive/source/boundary law-set compilation;
4. the oriented multi-region interface and its discrete spaces;
5. the exact-cover governing residual/Jacobian ownership; and
6. the mesh, space, nonlinear, linear, and refinement controls.

## Subject binding and reconstruction

The physical subject contains the five existing component bindings, one
`ThreeDPhysicalRegionSupportMappingBindingV4`, and one
`ThreeDPhysicalInputCompositionBindingV4`. The composition binding seals the
candidate, compiled prefix, G2 Genome and graph, all component declaration
and binding hashes, region/state/interface/space identities, and the mission,
bounds, and scenario hashes.

`compose_three_d_physical_inputs(context)` first inventories declarations and
bindings. Missing generic inputs return ordered, exact recoverable gaps.
Bindings without declarations, a composition claim with missing or ambiguous
components, foreign-context bindings, and forged hashes fail closed. Missing
mapping declarations and bindings have distinct recoverable gaps. A complete
inventory is rebuilt through each existing component API; the stored
composition binding must then equal that reconstruction in both semantic value
and canonical hash.

## Cross-component laws

- The manufactured fixture has two oriented regions.
- The region-law set must cover every oriented region in exact oriented order,
  with three globally distinct edge, AST-root, and output identities per region.
- The support mapping must store the exact physical coordinate/metric support
  and map every oriented region ID to that region declaration's support ref.
  It is a co-listed structural ownership declaration; it does not prove a
  coordinate transform, containment, overlap, or other geometric compatibility.
- Oriented state-node IDs, identity hashes, and physical types must exactly
  equal the residual/Jacobian state cover by keyed state-node identity. Tuple
  order is irrelevant, while missing, duplicate, or mismatched keys fail.
  The positive fixture deliberately stores G2 state nodes in right/left order
  while the oriented declaration remains left/right, exercising this rule
  through the full candidate, bindings, context, and composition path.
- Every oriented interface endpoint must belong to that state cover.
- The discretization space identities must exactly equal the oriented volume,
  trace, and multiplier spaces.
- Existing component validators independently rebind every declaration to the
  same current G2 graph and every binding to the same mission, bounds, and
  scenario.

## Status and authority boundary

The only composition statuses are `recoverable_gap` and `input_complete`.
`input_complete` means that the typed input package is structurally complete;
it is not a provider-selection, provider-execution, nonlinear solve, evidence,
validation, pass, P5, promotion, or terminal result. The claim ceiling remains
`screen_only`, and credible physical-device count remains zero.

## Files and verification

The slice is intentionally isolated to one source file, one manufactured
example, one focused test file, one runner, this implementation note, and one
dated report. No existing RuntimeV4 include graph or production runner is
changed. Verification consists of focused tests, the standalone example and
runner, RuntimeV4 core and spine regressions, and owned-file whitespace checks.
