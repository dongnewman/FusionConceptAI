# UP1 R2 witness-authority independent review R2

Decision: `rework` (accepted=false) due to one remaining P1 structural
binding defect. Claim ceiling remains contract/software preparation only;
`TEST_ONLY=true`, `non_evidence=true`, `no_publish=true`.

## Scope and independence

This is an independent fresh-process rerun of the R1 witness-authority
attacks. I inspected only the witness-authority implementation, focused
tests/fixtures, and the frozen 00-contract, 13-threat, 14-protocol criteria.
No reviewed implementation/test/fixture path was edited. The only writes are
under this R2 review directory.

## R1 attack rerun

All six requested R1 classes now pass their expected safety classification:

- unknown fields at root, candidate, every G1/G2/G3 and four-axis binding,
  witness, identity, independence, external attestation, evidence, signature,
  authority, endpoint and ack boundaries are `fail_closed`;
- substring/foreign witness scope is `ERR_SCOPE_MISMATCH`;
- complete evidence refs/hashes/versions, signature digest, signature scalar,
  and ack scalar attacks are `fail_closed`;
- self-certified independence is `ERR_INDEPENDENCE_EXTERNAL_ABSENT` with
  `typed_absence` (and terminal-deferred semantics), never admissible shape;
- the first typed-absence request is consumed, the same request is
  `ERR_DUPLICATE_IDEMPOTENCY`, and changed full request bytes are
  `ERR_IDEMPOTENCY_CONFLICT`;
- one-process batch replay yields one admissible shape then one duplicate;
  24 concurrent shared-ledger calls yielded exactly one admissible shape and
  23 duplicate failures;
- two separate fresh CLI processes produced byte-identical semantic output
  after excluding process/time observations.

## Remaining P1 finding

`WA-R2-001` remains: conflicting aliases are silently preferred. A conflicting
evidence digest alias can be paired with a recomputed signature digest and
returns `OK_SHAPE_ONLY`; conflicting `signature_material` versus
`signature_material_ref` and `ack` versus `receipt` also return `OK_SHAPE_ONLY`.
These are structural contradictions and must be rejected even though the
current result is still `resolution=typed_absence` and `no_publish=true`.
See `findings.json` for source paths and the required repair.

## Fresh execution evidence

- Reviewer-owned attack probe: `python -B .../reviews/01-witness-independent-review-r2/attack_review.py`, PID 42028, UTC 2026-09-16T18:21:49.850437Z to 18:21:50.121472Z, exit 0.
- Focused tests: fresh child Python `-B`, 11 passed, exit 0; reviewer/child PID and UTC are retained in `raw/pytest.stdout.raw`.
- Duplicate-key CLI positive control: exit 2 with `ERR_INVALID_JSON`; raw streams and exit are retained.

The probe is reviewer-owned and does not import the author's test module or
read fixture `expected` fields. No network, external authority, provider,
Julia, DESC, solver, mesh, or heavy numerical lane was run. The in-memory
ledger is not persistent authority evidence and the two-process replay does
not grant cross-process replay credit.
