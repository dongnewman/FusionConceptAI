# RuntimeV4 3-D physical-provider input report — 2026-09-10

## Result

The current generic G2 fixture now compiles to an exact eight-item 3-D input
gap instead of inferring readiness from graph dimension. A separate
manufactured fixture proves that typed Fourier geometry, coordinate/metric AST
ownership, profiles, flux, and subject binding can be reconstructed from the
current compiled candidate and `ForwardChainContextV4`.

That fixture remains `recoverable_gap`: region laws, oriented interfaces and
spaces, residual/Jacobian ownership, and discretization controls are not yet
present. No 3-D provider was selected or executed.

## Verification

- focused tests cover generic gaps, positive manufactured compilation, exact
  G2 graph/root/mission/bounds/scenario binding, malformed numeric/type inputs,
  hash substitution, foreign context, and authority ceilings;
- standalone example prints both the eight-gap generic result and the
  four-gap manufactured result;
- focused tests: 56/56, definitive exit code 0;
- standalone example: exit code 0;
- RuntimeV4 core: 26/26, exit code 0;
- RuntimeV4 spine: 54/54, exit code 0;
- `git diff --check` on the owned slice: exit code 0.

## Remaining chain gaps

1. Land typed multi-region constitutive/source/boundary ownership.
2. Bind oriented interfaces and discretization spaces to the same candidate.
3. Bind the governing residual and Jacobian to real graph-owned operators.
4. Add provider-specific, repository-trusted input translation and execution.
5. Keep solver output below physical validation until independent evidence and
   UQ obligations are satisfied.

Credible physical-device count: **0**.
