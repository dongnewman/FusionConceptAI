# Implementation report

## Code

`DeclaredDiffusionCompileExecuteV1.jl` adds a single adapter seam and leaves
the shared registry, `Compiler.jl`, and all prior files untouched.  The strict
input constructor delegates candidate/source/declaration/body/bundle identity
checks to the submitted G123 execution seam, then records the three source
byte hashes and three declaration byte hashes in a new DCCE hash receipt.

Typed lowering rejects dimension/rank violations and closes the executable
subset to one-dimensional structured scalar, static, diagonal-affine data.
Nonlinear, time-dependent, multifield, and anisotropic declarations are
classified as unsupported/deferred or fail-closed at the lowering boundary.

Composition uses the submitted unique-producer matcher.  Its semantic edge
hash is built from typed port payloads, not component/port display labels or
component order.  The numerical phase calls the submitted overlap transfer,
finite-volume assembly, and linear solve.  Pure Neumann, singular, nonfinite,
and residual failures remain numerical failures.  Composition authority is
kept separate, so a screen solve does not erase deferred G2/G3 authority.

## Tests and evidence

`fixture.json` fixes the accepted=false/screen_only boundary, positive phase
statuses, the separate 2x2 G123 lane and 4x4 FV holdout arithmetic, transfer
conservation, plan identity, label/permutation invariance, and three actual
negative dispatches (candidate mismatch, missing boundary, and pure Neumann).
Sixteen requested negative vectors remain explicitly pending until the Julia
runner is executed and are not claimed as covered here.

The executed checks were:

```text
python -B test/RuntimeV4/DeclaredDiffusionCompileExecute/static_qa.py
python -B test/RuntimeV4/DeclaredDiffusionCompileExecute/independent_oracle.py
```

The independent oracle recomputes the finite-volume matrix, right-hand side,
solution, and residual from fixture data without importing the product.  Both
Python checks pass.  Julia and DESC execution evidence is explicitly false;
therefore this package is not a hardware, physical, engineering, UP, R, or
whole-device acceptance claim.  The package remains `accepted=false` and
`review_pending`; it is not labelled accepted_limited.

## Gaps

No higher-dimensional mesh, tensor/anisotropic K, time-dependent or multifield
operator, nonlinear source, external provider, trusted mesh authority, or
production compiler integration is implemented.  The focused Julia runner is
defined but deferred to a serialized runtime lane.  The G123 2x2 numerical
receipt and spatial FV holdout remain separate because their discretization
matrices are different.  The numerical solve is a software screen only and
cannot promote the frozen candidate or close any parent goal.

The general IR/compiler route, G2/G3 causal promotion, trusted external
authority, formal UP2-01 acceptance, and the 16 pending negative dispatches
remain explicit P1 gaps.
