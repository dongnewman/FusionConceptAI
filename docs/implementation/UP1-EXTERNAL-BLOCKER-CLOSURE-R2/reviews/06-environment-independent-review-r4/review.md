# UP1 R2 environment provenance independent review R4

## Decision

`rework` (P1/P2 remain). The external context and trust-anchor repair closes
the R3 bundle-self-supplied-anchor attack: self-generated keys and
synchronously re-signed bundles fail against the caller-supplied anchor. All
R1–R3 direct mutation controls also fail closed. However, several provenance
metadata fields are outside the authenticated payload and can still be
mutated in place while returning `present/admissible`.

## Fresh verification

Read-only review of the 06 implementation/tests/docs and factual
10-environment-capture evidence. No installation or download was performed.

* Fresh `python -B -m pytest -q test/up1_external_closure_r2/environment_provenance`
  twice: `16 passed` each run.
* Fresh `python -B -m py_compile` for all focused Python files: exit 0.
* Independent Ed25519 verification of two binary subject signatures, signed
  receipt and outer envelope: `4/4` passed.
* 06 exact manifest: `20/20` files (excluding pycache/pyc), all listed hashes
  and byte counts match.
* 10 capture manifest: `56/56` artifact hashes match.
* Fresh validator and CLI semantic outputs are deterministic after removing
  intentional PID/UTC fields.

## Findings

### F1 — P1: authenticated chain still does not cover all provenance fields

With the correct external expected-context and trust-anchor supplied, the
following in-bundle mutations still returned `present/admissible`:

* `binaries[0].download_receipt.origin` changed to an attacker origin and its
  self-digest recomputed;
* `binaries[0].download_receipt.retrieved_utc` changed to a future time and
  its self-digest recomputed;
* `authority_proof.authority` changed to an attacker authority;
* `authority_proof.verified_at_utc` changed to a future time.

These values are not included in the declaration/context or signed receipt
payload. Receipt digest recomputation proves only self-consistency, not
publisher authenticity. Thus a locally modified receipt can retain an
otherwise valid Ed25519 chain while changing origin/time/authority claims.
The complete signed receipt/envelope must authenticate these fields, or the
validator must require a separately authenticated receipt digest and reject
any mutation as `fail_closed`.

### F2 — P2: license and SBOM supplier metadata are mutable outside the chain

Changing `sbom.components[0].supplier`, `sbom.components[0].license`, or
`binaries[0].license` to attacker values still returned
`present/admissible`. These fields are required and syntactically checked but
are not part of expected context, declaration hashes, or any verified signed
payload. Include them in the authenticated candidate context/receipt (or
explicitly downgrade them to non-authoritative metadata and prohibit claims
based on them).

## Controls that now pass

The R2/R3 direct attacks all fail closed: missing/absolute/traversal/case
paths; root hash drift; runtime/binary/lock version/path drift; duplicate
identities; SBOM orphan/empty/unknown/cycle/coverage/purl/reference cases;
publisher and binary subject drift; opaque binary signature/profile forgery;
receipt/recipe digest drift; root status/claim manipulation; runtime-path
shape/layer drift; authority signed-receipt and outer-envelope
signature/issuer/key/trust/profile forgery; signed validation without a root;
bundle-provided expected context; external candidate/source/root/profile,
lock/binary context mismatch; anchor key/issuer/trust/policy mismatch; missing
or wrong context/anchor digest; and attacker-key synchronous re-signing with
the correct external anchors. Duplicate JSON keys and unknown fields remain
rejected. TEST_ONLY positive remains `non_evidence`; production missing anchor
with declared typed absence remains `typed_absence`, while declared present is
rejected.

## 10-environment-capture boundary

The capture package remains non-authoritative preparation evidence:

* `machine_observation.observation_status=local_observation_only`;
* `manifest.claim_ceiling=preparation_only/screen_only`;
* `dependency_closure.status=typed_absent`, `candidate_ref=null`;
* all four binary inventory entries are `observed_not_candidate_bound`;
* six authority gaps remain typed absent, including candidate freeze/import
  closure, external binary provenance, trust root, artifact binding and
  `NO_AUTHORITY_FROM_LOCAL_OBSERVATION`.

The 56 capture artifact hashes were internally consistent at this audit; these
local facts do not supply the missing authenticated metadata.

## Claim ceiling

This review grants no candidate, source-authority, provider, solver,
engineering, physical, B00, B04, UP1, R or parent-goal credit. Because F1 is
P1 and F2 is P2, the requested no-P1/P2 condition for `pass_limited` is not
met.
