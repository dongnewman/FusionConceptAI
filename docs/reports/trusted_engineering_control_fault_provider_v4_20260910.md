# Trusted engineering control/fault provider V4 report

Date: 2026-09-10

## Result

A repository-owned operational adapter now executes the current manufactured
ECF graph contract through a separately sealed registration and dispatch chain.
The generic provider API was not widened.

The manufactured run resolves the exact current-G3 declaration and physical
subject binding, verifies the three ordered operator identities, and runs their
fixed manufactured screen as an 11-event exact-rational trace. The observed run
contains five transport releases, two dropout-window samples, zero
scheduled-dropout decisions at the declared `1/100` probability, two
declared-fault samples, and zero actuator-bound
violations.

Every dropout sample now carries an exact rational counter draw derived by
canonical SHA-256 from the sealed context/subject/scenario/input identities and
the exact sample time/index. The decision is `window_active && draw < p`; Julia
`hash`, floating-point thresholds, and global random state are not used. This is
a deterministic scenario sampling screen, not statistical validation or a
physical dropout measurement.

## Trust and identity checks

- Fixed provider ID, source path, entrypoint, capability kind, model class, and
  attested source paths are owned by `TrustedProviderRegistryV4.jl`.
- Source hashes and the loaded executor method-table hash are recomputed from the
  repository root.
- Registration binds context, physical subject, scenario, declaration, subject
  binding, compilation, capability, input, manifest, source, and runtime hashes.
- Dispatch revalidates before and after execution and recomputes the result from
  the exact rational trace.
- Generic contexts, caller-supplied generic manifests/registrations, and forged
  identities fail closed.

## Evidence boundary

The result and receipt remain `screen_only`. Credible-device count is zero, and
all engineering-evidence, physical-evidence, validation-evidence, promotion, P5,
and terminal-authority flags are false. This operational screen emits no evidence
and provides no experimental or device credibility.

## Verification

All checks were run after the provider source stabilized:

| Gate | Result |
| --- | --- |
| Focused provider test | 127/127, exit 0 |
| Standalone manufactured example | exit 0 |
| Dedicated provider runner | 127/127, exit 0 |
| RuntimeV4 core | 26/26, exit 0 |
| RuntimeV4 spine | 54/54, exit 0 |
| Existing trusted registry | 65/65, exit 0 |
| Existing trusted FreeGS provider | 43/43, exit 0 |
| Seven-file scope and trailing-whitespace report | pass |

The standalone example reported trace hash
`4f501d75f8e1c4d1257ae78060bb2b9257945407527bfaa84d2139620d33d755`.
