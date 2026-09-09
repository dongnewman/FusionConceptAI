# EngineeringControlFaultGraphObligationV4 report — 2026-09-10

## Outcome

The rejected caller-manifest design was replaced. The six-file isolated slice
now derives its complete contract from one `ForwardChainContextV4`:

- one immutable declaration is owned exactly once by the current
  `RealizationControlGenomeV4.control` tuple;
- one typed binding is constructed from the compiled prefix before context
  creation and is actually embedded in the manufactured physical subject;
- the context-only resolver locates both values, rebuilds the binding from the
  current candidate/G3/graph/subject inputs, and compares full semantics plus
  recomputed hashes.

The positive manufactured G3 owns three actual `AtomicMIMOHyperedgeV1` control
edges for observation, controller, and actuator stages. The subject binding
seals their edge/program/AST-root/node identities, typed finite actuator limit,
exact delay/dropout/fault/recovery timing, and candidate, prefix, registry, G3,
mission, bounds, scopes, and selected-scenario identities. Because the binding
is part of `ExecutablePhysicalSubjectV4.bindings`, the physical-subject hash also
commits to it.

The unchanged generic fixture owns no ECF declaration or binding and resolves
to the explicit `required_current_g3_engineering_control_fault_declaration`
recoverable gap. Missing/duplicate declarations, missing/duplicate subject
bindings, and foreign candidate/scenario bindings have distinct tested paths.

## Hash and authority audit

Every ECF type that stores a digest recomputes its semantic body in
`canonical_hash` and compares the digest instead of returning the stored field.
The same validation rejects any non-false execution, evidence, promotion, P5,
or terminal flag. The declaration, subject binding, gap, and compilation also
carry and hash `claim_ceiling=screen_only` and `credible_device_count=0`;
`canonical_hash` rejects forged ceilings or counts. Inner constructors require
identity equality with the private token; constructing a new token of the same
type is rejected.

This is a manufactured compiler contract only. It does not run a controller,
simulate recovery, validate engineering performance, inspect hardware, emit
evidence, pass a promotion gate, establish P5 readiness, or grant terminal
authority. Credible device count remains zero.

## Prior-output decision record

- Extracted: old control/fault vocabulary and bounded-actuator, delay, dropout,
  stuck-actuator, and recovery-window intent.
- Wrapped: those semantics only through a declaration owned by the current G3,
  real typed graph objects, and a binding embedded in the current subject.
- Test-only: manufactured positive, generic, duplicate, foreign-candidate, and
  foreign-scenario fixtures.
- Rejected: resolution-time caller manifests, mutable float schedules,
  dictionary/array state, capability labels, detached hashes, and historical
  pass/survivor flags as proof or authority.

## Verification

The rewritten focused suite passes 157/157. It covers positive
ownership, exact identity equality, missing/duplicate declaration and binding,
foreign candidate/scenario binding, absent edge, wrong root, detached actuator
limit, invalid stage order/timing, counterfeit constructor tokens, forged
stored hashes, forged execution/P5 authority, and forged claim ceilings/device
counts across the four boundary-carrying types. Final results:

- focused test: 157/157 pass, exit 0;
- standalone example: `compiled_contract`, current-G3 declaration ownership and
  subject binding ownership both true, generic `recoverable_gap`, claim ceiling
  `screen_only`, execution authority false, credible device count zero, exit 0;
- focused runner: 157/157 pass, both completion markers present, exit 0;
- RuntimeV4 core: 26/26 pass, exit 0;
- RuntimeV4 spine: 54/54 pass, exit 0.

No neighboring engineering-control/fault variant, accepted manifest, aggregate
runner, runtime execution path, or evidence path was changed. No commit was
created.
