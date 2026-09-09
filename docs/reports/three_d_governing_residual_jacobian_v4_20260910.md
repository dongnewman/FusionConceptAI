# RuntimeV4 3-D governing residual/Jacobian report — 2026-09-10

## Outcome

Added one isolated new-file compiler slice for typed 3-D governing residual and
Jacobian ownership. It derives an ordered exact-cover declaration set from
current-G2 `AtomicMIMOHyperedgeV1` edges and registered typed-AST roots, then
binds the full set through one typed physical-subject binding to the exact
candidate, graph, context, mission, bounds, and selected scenario.

The accepted generic G2 context remains `recoverable_gap`. The manufactured
compiler fixture contains two heterogeneous state nodes and two distinct
residual/Jacobian pairs. It reaches `compiled` only after exact state, residual,
and Jacobian node coverage; edge/root uniqueness; per-state domain/codomain,
units, rank, dimension, and time compatibility; typed roles; manifests; and
canonical identities all match. The typed 3-D discretization-controls gap
remains explicit.

The initial single-state prototype was rejected as non-composable. The revised
declaration normalizes reversed selectors to current G2 state order and rejects
missing, duplicate, extra, shared, or unowned identities.

## Canonicalization performance correction

The first revised probe was stopped after several minutes because inner
derivation repeatedly called `canonical_hash(::ForwardGraphBindingV4)`, which
reconstructed the entire graph identity inventory for each state/operator and
again through context lookup. The corrected implementation keeps one complete
validation at every public trust boundary: graph binding at declaration,
compiled prefix at subject-binding construction, and forward context at compile
and context-bound ownership validation. Inner work then reuses the validated
identity inventories, computes the root inventory once per declaration, and
uses a minimal four-manifest registry in the two-state fixture.

Every new operator, pair, declaration, binding, ownership, and resolution hash
still recomputes its own canonical body and checks the stored digest. The
optimization does not turn stored self-hash fields into authority. White-box
tests use the private tokens to corrupt a context hash and construct a compiled
prefix whose G2 graph differs from its candidate; all three public entry paths
reject those inputs. The final standalone example completed in 50.761 seconds
wall time, including Julia/package/fixture cold loading.

## Legacy review

The old v68 residual graph contributed structural ideas only: exact state-row
ownership, residual-unit and dependency checks, and matching Jacobian row and
column slots were extracted. Current `PhysicalType`, typed AST, AtomicMIMO, and
forward-context identities wrap those ideas into the active V4 architecture.
Callable residual/Jacobian blocks and old manufactured solve examples remain
test-only references. Mutable manifests, callback selection, solver outputs,
evidence ceilings, and legacy `pass`/`fail`/`unsupported` decisions were
rejected.

## Authority result

- provider selected or executed: no;
- solver executed: no;
- evidence emitted or accepted: no;
- pass or promotion granted: no;
- physical or engineering validation: no;
- P5 ready: false;
- terminal authority: none;
- claim ceiling: `screen_only`;
- credible physical-device count: 0.

## Files

- `src/RuntimeV4/ThreeDGoverningResidualJacobianV4.jl`
- `examples/runtime_v4_three_d_governing_residual_jacobian.jl`
- `test/runtime_v4_three_d_governing_residual_jacobian_tests.jl`
- `scripts/run_v4_three_d_governing_residual_jacobian.jl`
- `docs/implementation/three_d_governing_residual_jacobian_v4.md`
- this report

No accepted file, rejected prototype, aggregator, or old output was modified.
No commit or push was made.

## Verification

All commands completed with process exit code 0:

- standalone example: generic `recoverable_gap`; manufactured `compiled`; two
  ordered states; two distinct residual roots; two distinct Jacobian roots;
  only the discretization-controls gap remains;
- focused runner: 140/140 assertions in 54.379 seconds, plus
  `THREE_D_GOVERNING_RESIDUAL_JACOBIAN_FOCUSED_EXIT_CODE=0` and
  `THREE_D_GOVERNING_RESIDUAL_JACOBIAN_OK`;
- RuntimeV4 core tests: 26/26 in 30.293 seconds;
- RuntimeV4 spine tests: 54/54 in about 33 seconds;
- RuntimeV4 spine example: exit code 0, 11 stages, admission/P5/terminal
  classification correctly withheld, in 25.761 seconds.
