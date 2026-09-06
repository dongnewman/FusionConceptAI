# D3 bounded acceptance: candidate-bound field/time bridge

## Decision

D3 stops at a materialization and obligation bridge. It executes the accepted
D2.1 consistent initialization, D2.2 mixed-state backward-Euler trajectory,
and the existing static G2 typed field program under one candidate and one
compiled prefix. It does not execute a coupled field-time equation.

This is the smallest honest next step because the current genomes do not own:

- a `StateGeneRefV1` to G2 parameter/source producer with a unit transform and
  sample time;
- a time-dependent field unknown, field initial payload, mass operator, or
  `DT` root;
- a same-candidate G1 spatial residual binding to the selected G2 root; or
- executable coordinate-map and metric programs.

## Sealed inputs and outputs

The input binds the candidate, compiled prefix, genome/operator registries,
passing D2 plan/report, G2 plan/report, provider, and two explicit scenario
identities. The scenarios are recorded as `distinct_unmapped`; co-membership in
a candidate is not evidence that they describe one operating point. The bridge
first proves that their sealed hashes differ; identical scenario identities are
rejected.

`FieldTimeMaterializationV4` records the complete candidate/prefix payload,
the three genome payloads, mission/bounds/minimality scope, D2 initialization
and trajectory identities, and the G2 support/chart/program/root/grid/parameter
manifests. `FieldTimeBridgeReportV4` references the existing D2.2 and G2
evidence IDs separately. The materialization also seals the complete semantic
G2 report hash, component status, and unresolved/deferred reasons. It has no
field-time artifact and no merged metrics.

The four mandatory gaps are sealed `UnresolvedStageDeclarationV4` values.
Boundary-time, interface, material, and source defaults are not invented. A
missing G2 provider remains a deferred component and never becomes
`unsupported`.

## Validation and stopping rule

Validation reuses the complete D2 validators. Because G2 has no standalone
sealed report validator, D3 recompiles its plan from the frozen candidate and
re-executes it in a fresh store, then compares the complete semantic plan and
report. Candidate, prefix, genome bundle, scenarios, grid, root, provider,
results, evidence, gaps, and promotion fields therefore fail closed.

D3 is accepted only when the combined fixture and replay pass, missing-provider
and foreign/tampered cases remain deferred or rejected as specified, and D2/G2
regressions pass. At that point work stops: no native/FE field solve, temporal
cast, field-time step, boundary default, or new physical equation is added.

## Physical non-conclusions

The bridge is not a PDE/DAE coupled solve, field-time coupling, native field
closure, high-fidelity assembly, VVUQ, validation, minimal-device proof, or
candidate promotion. Its fixed authority is `claim_ceiling=none`, zero credible
physical candidates, `p5_ready=false`, and `unsupported_emitted=false`.
