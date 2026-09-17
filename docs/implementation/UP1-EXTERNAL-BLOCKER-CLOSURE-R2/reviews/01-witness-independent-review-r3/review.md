# UP1 R2 witness-authority independent review R3

Decision: `pass_limited` for the bounded software contract slice;
`accepted=false`, claim ceiling `contract/software preparation only`,
`TEST_ONLY=true`, `non_evidence=true`, `no_publish=true`.

This independent rerun inspected only the witness-authority implementation,
focused tests/fixtures, and frozen 00-contract, 13-threat, and 14-protocol
criteria. No reviewed implementation/test/fixture path was modified. All
writes are confined to this R3 review directory.

## Alias attack closure

All three requested alias families pass both standalone and coexisting forms:

- evidence `object_sha256` alone -> `ERR_UNKNOWN_FIELD`; alongside canonical
  digest -> `ERR_ALIAS_CONFLICT`;
- `signature_material_ref` alone -> `ERR_UNKNOWN_FIELD`; alongside canonical
  material -> `ERR_ALIAS_CONFLICT`;
- authority `receipt` alone -> `ERR_UNKNOWN_FIELD`; alongside canonical `ack`
  -> `ERR_ALIAS_CONFLICT`.

## Full R1/R2 rerun

All public-boundary unknown-field attacks, exact scope attack, complete
G1/G2/G3 and four-axis evidence binding attacks, signature digest/type attacks,
ack type attack, and self-certified independence attack produced the required
fail-closed or typed-absence result. Typed-absence replay consumed the key;
same bytes produced `ERR_DUPLICATE_IDEMPOTENCY`, changed full request bytes
produced `ERR_IDEMPOTENCY_CONFLICT`. A two-process fresh CLI replay had equal
semantic outputs. A one-process batch produced one shape then one duplicate.
Twenty-four concurrent calls on one in-memory ledger produced exactly one
`present_admissible_shape` and 23 `ERR_DUPLICATE_IDEMPOTENCY` failures.

## Fresh evidence

- Reviewer-owned attack probe: `python -B .../reviews/01-witness-independent-review-r3/attack_review.py`, PID 112764, UTC 2026-09-16T18:36:20.351082Z to 18:36:20.594408Z, exit 0.
- Focused author tests in a fresh child Python `-B`: 12 passed, exit 0;
  reviewer/child PID and UTC are retained in `raw/pytest.stdout.raw`.
- Duplicate-key CLI control: exit 2 with `ERR_INVALID_JSON`; raw streams and
  numeric exit are retained.

The attack probe independently derives canonical signature payload digests and
does not import the author's test module or read fixture `expected` fields.
No network, authority, provider, Julia, DESC, solver, mesh, or heavy numerical
lane was run. The in-memory ledger is not persistent authority evidence;
two-process determinism grants no cross-process replay or external credit.
The parent external blocker remains typed absence/terminal deferred and all
UP1, B00/B04, and R01-R10 gates remain open.
