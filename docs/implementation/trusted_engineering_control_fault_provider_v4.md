# Trusted engineering control/fault provider V4

## Scope

This slice operationalizes only the repository's manufactured three-edge
observation/controller/actuator contract. It is a deterministic software screen,
not engineering, physical, validation, promotion, P5, or terminal evidence.

The generic trusted-provider registration path remains unchanged. A separate
`TrustedEngineeringControlFaultRegistryV4` wraps the content-addressed base trust
root and admits exactly one registration derived from one validated
`ForwardChainContextV4`.

## Repository trust root

`TrustedProviderRegistryV4.jl` owns the fixed provider identifier, source path,
entrypoint, allowed capability kind, model class, and attested source list. At
bootstrap it hashes the provider source, the ECF graph-obligation source, and the
loaded executor method table. Validation recomputes those identities from the
repository root.

The narrow registration function accepts only the base registry and the forward
context. It internally derives and seals the current declaration, subject
binding, compilation, capability, input, provider manifest, and executor. There
is no caller descriptor, capability, input, manifest, provider identifier, or
function argument.

## Manufactured execution

The operational input uses exact rational values and a finite event schedule:
the start, declared dropout boundaries, declared fault boundaries, horizon, and
the corresponding transport-delay release events. Controller updates occur at
the six declaration-derived control boundaries. A queued command becomes active
at its exact transport release event. Plant state is propagated piecewise with
the prior bounded actuator command.

Each trace item records time, state, observation, requested command, actuator
command, delayed-command release, dropout-window state, the exact dropout draw,
the resulting dropout decision, and declared fault state. The result binds the
declaration, subject binding, input, full trace, summary counts, and hashes.
Validation reruns the fixed kernel and requires exact semantic and canonical
equality.

### Deterministic probability semantics

Dropout uses no global random generator and no Julia `hash`. For every sample,
the kernel hashes a domain separator together with the sealed context, physical
subject, scenario, and input identities plus the exact sample time and sample
index. The first 60 digest bits become an exact rational draw in `[0,1)`. A
scheduled dropout occurs exactly when the sample lies in the declared dropout
window and `draw < dropout_probability`.

This is one deterministic, replayable scenario draw per sample. It makes the
declared probability operational and auditable, but it is not a Monte Carlo
study, calibration, statistical validation, or physical dropout measurement.

## Dispatch boundary

Before dispatch, registry, descriptor, source/runtime identity, context,
declaration, binding, compilation, capability, input, manifest, and request are
revalidated. The fixed executor is invoked without accepting a caller function.
After dispatch, the same trust root and the recomputed result are revalidated
before the receipt is issued.

The receipt is always `operational_screen`, `screen_only`, credible-device count
zero, and false for every evidence or authority flag. A receipt cannot promote a
candidate or count as real-device evidence.

## Fail-closed coverage

Focused tests cover exact positive registration and execution, deterministic
replay, actuator bounds, `p=0`, `p=1`, fractional-probability replay and exact
threshold decisions, generic-context rejection, generic public API rejection,
sealed constructors, and forged descriptor source, runtime, registration,
registry, input, scenario, request, result, and receipt identities.
