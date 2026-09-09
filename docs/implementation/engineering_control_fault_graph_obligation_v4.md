# EngineeringControlFaultGraphObligationV4

## Scope and authority ceiling

This compiler-only slice admits an engineering control/fault **contract** only
when its declaration is owned by the current realization/control Genome (G3)
and its typed binding was already embedded in the physical subject before the
forward context was constructed. It does not execute control logic or create
engineering, validation, physical, promotion, P5, or terminal evidence.
The declaration, subject binding, recoverable gap, and compilation each carry
and hash `claim_ceiling=screen_only`, `credible_device_count=0`, and all-false
authority fields; these boundaries are not present only in a descriptive manifest.

## G3-owned declaration

`EngineeringControlFaultDeclarationV4` contains the ordered and complete
observation, controller, and actuator edge specifications, the typed actuator
limit, and the exact control/fault timing contract. A valid current candidate
must contain exactly one such declaration in
`RealizationControlGenomeV4.control`; a caller-created declaration passed at
resolution time is impossible because the resolver accepts only a
`ForwardChainContextV4`.

The actuator limit owns a `QuantityIntervalV1` and the exact actuator edge and
output-node IDs. Timing uses `NonnegativeQuantityV1` values for transport delay,
dropout onset/duration, fault onset, and recovery deadline, plus an exact
`Rational{Int64}` dropout probability. Time units must agree, duration must be
positive, and the recovery deadline must be strictly later than fault onset.

## Pre-context subject binding

`make_engineering_control_fault_subject_binding` runs before subject/context
construction. Its inputs are the `CompiledCandidatePrefixV4`, Genome registry,
mission, bounds, comparison scope, scenario scope, selected scenario, and the
declaration. It first revalidates the compiled prefix, then proves that the
supplied declaration is the sole declaration owned by the current G3.

The resulting immutable `EngineeringControlFaultSubjectBindingV4` seals:

- candidate, compiled-prefix, registry, Genome-bundle, and current-G3 identities;
- control graph and forward graph-binding identities;
- the G3-owned declaration, actuator-limit, and timing identities;
- exact mission, bounds, comparison scope, scenario scope, and selected scenario;
- three actual graph-owned `AtomicMIMOHyperedgeV1` values, their actual
  `TypedASTProgramV1` values, graph positions, edge identity hashes, root operator
  references, program root positions, forward AST-root identity hashes, and
  actual typed input/output nodes plus their forward identity hashes.

The manufactured physical subject contains this typed binding directly in its
`bindings` tuple. Consequently the subject's own canonical hash commits to the
binding. The final compilation records both that physical-subject hash and the
already-embedded binding; it does not manufacture a binding after context
creation.

## Graph closure

The current control graph must own exactly three `AtomicMIMOHyperedgeV1` edges
with role `control`. They must match the G3 declaration in stage order and form
the exact graph-node chain
`plant_signal -> observation -> controller_command -> actuator_command`.
Every edge has one typed input, one typed output, and one `ASTApplyV1` root.
The actuator limit must point to the actual actuator output and use its physical
unit. Capability strings, detached hashes, or similarly named objects cannot
stand in for graph ownership.

## Context-only resolution and recoverable gaps

`resolve_engineering_control_fault_graph_obligation(context)` performs these
steps without caller-supplied specs, limits, timing, declarations, or bindings:

1. revalidate the forward context;
2. locate exactly one declaration in the current G3;
3. locate exactly one typed binding inside the current physical subject;
4. rebuild the expected binding from the context's compiled prefix, registry,
   mission, bounds, scopes, scenario, current G3, and declaration;
5. compare both the complete semantic body and recomputed canonical hash.

Missing or duplicate declarations and missing or duplicate subject bindings
produce distinct recoverable gaps. Foreign-candidate, foreign-scenario, stale,
or otherwise mismatched bindings produce a binding-mismatch gap. An absent,
ambiguous, mis-typed, wrongly rooted, or disconnected G3 graph produces a graph
ownership gap. Malformed declaration construction, invalid timing, or detached
actuator limits is rejected before a subject binding can be built.

## Sealing and stored-hash validation

All externally meaningful stored-hash types recompute their complete semantic
body in `canonical_hash`, compare the result with the stored digest, and reject
non-false authority fields. For the four contract/result types above, the same
recomputation rejects a claim ceiling other than `screen_only` or any nonzero
credible-device count. Their inner constructors require the unique private token
value, not merely another instance of the token's type. Focused tests cover
counterfeit tokens, deliberately forged stored hashes, forged execution/P5
authority, forged claim ceilings, and forged credible-device counts.

## Prior-output disposition

- **Extract:** older v85/v108 controller, actuator, delay, dropout, stuck-actuator,
  and recovery-window intent; the v90 bounded-actuator concept; and the older
  FreeGS C1 statement that controller dynamics were missing.
- **Wrap:** only those semantics, through an immutable current-G3 declaration,
  actual typed G3 graph objects, and a subject-owned pre-context binding.
- **Test-only:** the new three-edge manufactured chain and adversarial generic,
  duplicate, foreign-candidate, and foreign-scenario fixtures.
- **Reject:** caller-created resolution manifests, mutable floating schedules or
  dictionaries, capability labels as ownership, detached hashes as node proof,
  and historical survivor/pass flags as authority.

The slice remains isolated: no neighboring engineering-control/fault variant,
accepted manifest, aggregate runner, runtime executor, or evidence path is
modified.
