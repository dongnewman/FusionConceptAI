# UP1 R2 environment provenance independent review R3

## Decision

`rework` (P1 remains). The R2 signature/issuer/key/trust/profile forgery
controls now fail closed, binary opaque signatures are actually checked with
Ed25519, synchronously rewritten stale path substitutions fail, and SBOM
purl/reference attacks fail. However, the complete expected context and trust
key are still accepted when self-supplied by the bundle. A newly generated
attacker key can sign the whole bundle and obtain `present/admissible`, so the
requested independent anchor condition is not met.

## Scope and fresh checks

Read-only review of the 06 implementation, focused tests/docs and factual
10-environment-capture evidence. No installation or download was performed.

* Fresh `python -B -m pytest -q test/up1_external_closure_r2/environment_provenance`
  twice: `11 passed` each run.
* Fresh `python -B -m py_compile` for all focused Python files: exit 0.
* Independent Ed25519 verification of both binary subject signatures, the
  signed receipt and the outer envelope: `4/4` passed.
* 06 exact file manifest: `20/20` excluding pycache/pyc; listed hashes and
  bytes all match.
* 10 capture artifact manifest: `47/47` hashes match.
* Validator/CLI semantic results are deterministic across fresh runs after
  removing intentional PID/UTC fields.

Raw evidence is in `raw/attack_matrix.txt` and the other files under `raw/`.

## Finding

### F1 — P1: expected context and trust anchor can be generated inside the
bundle

The public API/CLI accepts no externally supplied expected-context digest,
trusted public key, trust-root fingerprint or profile policy. It only validates
the `expected_context` object found in the bundle, derives its hash, and
verifies signatures using public keys also found in that same bundle. The
signed receipt and outer envelope then authenticate the self-consistent bundle,
but do not establish that its context/key was authorized independently.

Attack reproduction: generate a fresh attacker Ed25519 key; replace the
bundle's `expected_context.frozen_root` and profile; replace binary and
authority key/issuer/trust metadata; re-sign all binary subjects, the signed
receipt and outer envelope; leave production status `present`. The validator
returned `present/admissible` (`bundle_self_supplied_context_and_key`). This
also demonstrates that synchronously rewritten path/context substitutions can
pass when the attacker can self-issue the entire envelope.

Fix by requiring an independent anchor input (for example an expected-context
digest and trusted public-key/trust-root/profile policy supplied out-of-band by
the caller), comparing all bundle values against it, and rejecting any
production bundle that lacks that anchor. A key/public-key value carried only
inside the signed bundle is not a trust anchor. The existing missing-context
behavior is correct when declared `typed_absent` (it returns typed absence),
but presence of a self-generated context must not upgrade production to
`present`.

## R2/R1 controls now closed

The following direct attacks all fail closed: missing, absolute, traversal and
case-drift paths; root runtime/binary/lock hashes; runtime/binary version/path
drift; duplicate runtime/lock/binary identities; SBOM orphan, empty, unknown
edge, cycle, uncovered component, purl drift and duplicate binary refs;
publisher/subject drift; binary opaque signature and profile forgery; receipt
and recipe digest drift; root status/claim changes; untyped runtime paths; all
authority signed-receipt and outer-envelope signature/issuer/key/trust/profile
forgeries; and signed validation without a root. Duplicate JSON keys and
unknown fields remain rejected. The checked TEST_ONLY positive returns
`non_evidence`; production missing context with declared `typed_absent`
returns `typed_absence`, while declared `present` is rejected.

## 10-environment-capture boundary

The capture package remains non-authoritative preparation evidence:

* `machine_observation.observation_status=local_observation_only`;
* `manifest.claim_ceiling=preparation_only/screen_only`;
* `dependency_closure.status=typed_absent`, `candidate_ref=null`;
* all four binary entries are `observed_not_candidate_bound`;
* six authority gaps remain typed absent, including missing candidate freeze,
  import closure, external binary provenance, trust root, artifact binding and
  `NO_AUTHORITY_FROM_LOCAL_OBSERVATION`.

These local facts cannot supply the missing production anchor.

## Claim ceiling

This review grants no candidate, source-authority, provider, solver,
engineering, physical, B00, B04, UP1, R or parent-goal credit. The requested
no-P1/P2 condition for `pass_limited` is not satisfied because F1 is P1.
