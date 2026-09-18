# VNext T1 Candidate Binding V2

This additive slice defines an explicit candidate-binding contract without
connecting it to `FusionConceptAI.jl`, an operator registry, or production T1
admission. It never constructs the V1 giant-tuple package.

The contract compares an expected `QualifiedRefV1`, candidate `Digest256`,
source-package `Digest256`, and optional V2 canonical wire against explicit
observations. It does not infer identity from labels, URI components, order, or
payload contents. Missing evidence is `terminal_deferred`; foreign, tampered,
or duplicate evidence is `fail_closed`; exact equality is `bound`. Every result
remains `accepted=false` and `claim_ceiling=:contract_only`.

`wire_hash` authenticates exact wire bytes. `receipt_hash` authenticates the
binding decision and its separately domain-enveloped fields. The receipt's
sealed constructor recomputes this hash and validates domain, schema, version,
status/reason, duplicate count, and expected-wire presence. They are deliberately
separate. A future adapter may obtain the explicit input fields from an already
verified package, but that adapter and runtime integration are not part of this
slice.

Decision precedence is fixed: observation multiplicity first, then exact
reference/digest/package identity, then expected/observed wire presence and
wire integrity. A foreign identity carrying a missing wire therefore remains
`fail_closed`; it is not erased into `terminal_deferred`.

`QualifiedRefV1.id` and `.version` are compared as one exact pair. Path-like
ids are opaque identities: `/a/../b` is not normalized to `/b`. Combining an
id from one reference with a version from another is likewise rejected rather
than treated as a candidate alias.

## R1 runtime receipt

The serialized R1 attempt is preserved byte-for-byte under
`local_profile_r1_runtime/` (the original preflight directory remains intact).
It exited `1` after `2.1441962` seconds and is classified as
`program_exception`: the package load reached `CanonicalJSON.jl` before the
`ConservationAccountRefV1` definition (`UndefVarError: `ConservationAccountRefV1`
not defined`). All `19/19` protected files were unchanged and both postflight
observations had no Julia/DESC residual process. R1 grants no runtime, T1, or
T2, or UP1 credit.

The minimal test-loader repair uses `using FusionConceptAI`, includes the two
V2 definition files into the package module, and keeps the test definition-only;
it does not manually include `CanonicalJSON.jl` or `PhysicalTypes.jl`. Only the
Python static/oracle checks and `git diff --check` are run after this repair;
Julia is not rerun.

## R2 runtime receipt

The serialized R2 runtime receipt is preserved under
`local_profile_r2_preflight/run_20260918_221435_957_da33f0ff621f4c33a6863f82b632afca/`.
It exited `0` after `3.425417` seconds and reported
`VNext T1 V2 explicit candidate binding | 24 | 24`. All `19/19` protected files
were unchanged, and the two postflight Julia/DESC observations were both zero.
R2 is a successful runtime receipt for this definition-only contract, but it
grants no T1, T2, or UP1 credit; `accepted=false` and
`claim_ceiling=:contract_only` remain in force.

## R3 independent replay receipt

The serialized R3 runtime receipt is preserved under
`local_profile_r3_preflight/run_20260918_222901_638_f60c70a246944614abd4abe3fc375a4e/`.
It exited `0` after `3.3223064` seconds and reported the same `24/24` named
test summary. `replayExact=true` holds for all six replay fields:
`schema`, `version`, `status`, `candidate_digest`, `wire_hash`, and
`receipt_hash`. All `35/35` protected files were unchanged, and both postflight
Julia/DESC observations were zero. R3 independently confirms the R2 replay
fingerprint only; it grants no T1, T2, or UP1 credit. Production integration
remains `not_connected`, with `accepted=false` and
`claim_ceiling=:contract_only`.
