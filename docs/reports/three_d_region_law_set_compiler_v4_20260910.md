# RuntimeV4 multi-region law-set compiler report — 2026-09-10

## Scope

This isolated six-file slice adds an exact-cover multi-region law declaration
and subject binding without changing the existing physical-input composer.
The manufactured positive fixture has two oriented regions and six distinct
laws: constitutive, source, and boundary for each region.

## Acceptance claims

- Selector input is normalized to the oriented region order.
- Every oriented region is covered exactly once.
- Edge, AST-root, and output-node identities are unique across all six laws.
- Declaration and binding identities are sealed to the current candidate,
  compiled prefix, G2 graph, oriented declaration and binding, mission,
  bounds, and scenario.
- Missing generic inputs remain recoverable gaps; missing, duplicate, extra,
  shared, foreign, and forged exactness violations fail closed.
- Authority remains `screen_only`; no provider or solver executes, no evidence
  or pass is emitted, and credible physical-device count remains zero.

## Performance correction

An initial version rebuilt the full compiled prefix and recreated the oriented
binding while validating the law-set binding, then repeated the same work from
the context compiler. The implementation now inventories G2 roots once per
declaration and compares sealed current-context identities directly during
binding compilation. This removes redundant whole-context reconstruction while
retaining fail-closed identity checks.

The focused fixture remains unusually expensive: its cold RuntimeV4 load and
repeated full-context construction dominate elapsed time even after the
law-set-local reconstruction was removed. The completed focused test required
8 minutes 24 seconds. This is recorded as performance debt, not as a semantic
failure and not as evidence that the standalone runner or broader regressions
have passed.

## Verification record

The focused test completed with definitive exit status 0. Its observed testset
summaries covered the generic recoverable gap, the positive two-region/six-law
exact cover, selector violations, binding violations (5/5), and the authority
manifest (14/14).

The standalone example, runner, RuntimeV4 core tests, and spine regressions are
not claimed here because no definitive successful exit status was recorded for
them. A timed-out or interrupted Julia run is not acceptance evidence.

## Boundary

This report records structural compiler work only. It is not physics,
engineering, manufactured-control, or device evidence and creates no promotion
or terminal authority.
