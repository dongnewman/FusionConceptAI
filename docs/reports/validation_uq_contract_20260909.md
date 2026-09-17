# Validation/UQ contract implementation report — 2026-09-09

## Scope

Implemented a fail-closed Runtime V4 validation-admission contract over
artifact-derived candidate/subject/scenario/observable bindings, the three Genome identities, typed AST and
operator-hypergraph hashes, provenance, applicability, split records,
measurement uncertainty, parameter distributions/correlations, extrapolation,
and separate numerical/model/measurement/transfer uncertainty. Physical
`:pass` requires a candidate-bound prediction artifact and explicit comparison
result; the focused unit control reports admission gaps and never mints
physical credit.

## Reuse audit

Legacy `candidate_vvuq_runtime_v87.jl`, `generic_vvuq_runtime_v94.jl`, and
`physical_vvuq_runtime_v96.jl` were inspected as test-intent and gate references
only. Their dictionary schemas, authority, statuses, and candidate routing were
not wrapped or included. Current Runtime V4 hashes and typed identity patterns
were reused. Manufactured controls and cross-code results are explicitly
zero-credit for physical validation.

| Source/use | Decision | Boundary |
|---|---|---|
| legacy refinement/gate invariants | extract | minimum split, hash, and fail-closed test intent, rewritten over typed records |
| legacy runtime modules | reject | no inclusion, wrapper, status/authority reuse, or candidate routing |
| current Runtime V4 `Digest256`/canonical identity | extract | hash and immutable-payload conventions only |
| current Runtime V4 validation artifacts | test-only | adversarial binding and evidence-boundary test intent; no physical credit |
| synthetic/manufactured and cross-code outputs | reject as physical validation | retained only as screen/numerical controls, credit exactly zero |
| future physical-data adapters | wrap (planned) | must populate this contract with provenance, applicability, split, and uncertainty |

## Acceptance boundary

The focused tests cover hash-only binding rejection, synthetic provenance
rejection, missing/invalid uncertainty and applicability, and invalid
distributions/correlations. A real physical-data provider is absent, so no
positive physical-validation unit control is claimed. The contract returns
`:pass` only after actual artifact and comparison admission, otherwise
`:unknown`/`:out_of_domain`; it never performs
permanent pruning or final authority closure. Integration remains an explicit
include hook until a physical-data provider is available.
