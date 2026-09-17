# R2 G2 independent review — findings

## Verdict

`rework`. This is a TEST_ONLY/non_evidence software review only. No external
authority, production trust, UP1, B00/B04, provider, solver, mesh, physical,
engineering, or R01–R10 credit is issued.

## Findings

### G2-R1-001 — P1: foreign candidate/source can pass when locally self-consistent

`validate_profile` checks that each edge agrees with the candidate/source refs
inside the same profile (`production_g2_mapping.py:312-317`,
`:178-212`), but it receives no expected candidate or authoritative source
identity. The review mutated `candidate_ref` to
`fusionconceptai://candidate/foreign` and updated the corresponding local
edges; it returned `accepted`. The same attack succeeded for
`source_ref=.../source/foreign`. These are the
`G2-NEG-FOREIGN-CANDIDATE-SELF-CONSISTENT` and
`G2-NEG-FOREIGN-SOURCE-SELF-CONSISTENT` rows.

This violates the frozen G2 ownership requirement that foreign candidate/source
binding fail closed. Rework should add an explicit expected candidate/source
binding (or an authoritative binding context) to the validation boundary and
compare all refs/edges against it; a profile's self-consistency is not
ownership proof.

### G2-R1-002 — P1: canonical declaration bytes/hash and authoritative source hash are not produced or recomputed

The implementation only shape-checks supplied digest strings
(`production_g2_mapping.py:145-147`, `:169`) and returns selected details
(`:318-339`). It does not emit canonical profile/declaration bytes or a
canonical hash, nor recompute the supplied axis/edge/source digests. The legal
axis permutation was accepted, but no canonical bytes/hash was available for
the required semantic replay binding. The review's independent SHA-256 values
bind the test inputs and source files, not an implementation-produced G2
canonical declaration.

Rework should define one deterministic canonical serialization, return its
bytes/hash in the receipt, and bind/recompute source/declaration/axis/edge
hashes before any production-admissible structural result.

## Safe/expected boundary observations

- Duplicate JSON keys (top-level and nested), unknown top-level/nested fields,
  repeated/missing axis IDs, duplicate axis evidence refs, asymmetric edge refs
  and hashes, issuer/key/policy/name/EKU/keyUsage/revocation/freshness/nonce/
  sequence/idempotency/replay errors all failed closed in the independent run.
- `TEST_ONLY` evaluated to `non_evidence`; typed absence evaluated to
  `typed_absence`; a structurally complete PRODUCTION profile with arbitrary
  signature bytes returned `production_admissible_structural` with
  `authority_verified=false`. This is safe only as a structural boundary and
  is not signature/trust verification.
