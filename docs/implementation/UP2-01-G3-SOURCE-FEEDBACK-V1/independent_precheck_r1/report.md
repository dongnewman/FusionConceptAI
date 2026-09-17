# UP2-01-G3-SOURCE-FEEDBACK-V1 independent static precheck R1

Verdict: `changes_requested`.

This review is static-only at HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`. The current
worktree had 300 porcelain entries at the review freeze and no matching Julia
or DESC process. The implementation's Python static QA exits 0 and correctly
recomputes the fixture's `120 -> 90 + 15 + 15` rational example, but it mirrors
the same formula and does not independently exercise the typed ledger,
authority identity, hash tamper, or exception paths. No Julia/DESC command was
run by this review.

## Findings

### 1. The exact rational example is locally legal, but the evaluator ignores declared ledger entries

`G3SFLawV1` enforces `efficiency=3/4`, `heat_fraction=1/8`, and their sum at
most one. `g3_sf_evaluate_v1(..., 120)` therefore computes exact rationals
`field=90`, `heat=15`, and `return=15`, with an energy residual of zero. The
fixture and Julia test cover these values.

The evaluator then constructs a fresh hard-coded ledger tuple from those
computed values (`source=p, field=-field, return_power=-returned, heat=-heat`)
and sums that tuple. It never reads `x.ledger_entries`, their endpoint IDs,
effects, directions, or signs. `g3_sf_validate_v1` checks entry IDs, endpoint
existence, units and owner scope, but does not require an entry effect to match
its endpoint role or an entry sign/direction to match its endpoint. A malformed
ledger can therefore receive a zero residual from the evaluator. The existing
tests have no ledger-sign, effect-to-role, endpoint, or evaluator-versus-
declaration negative control.

Required repair: make ledger evaluation and validation consume the declared
entries, or explicitly split a declared ledger projection from an evaluator
that cannot claim ledger closure. Add a typed contradictory-ledger control
that is reached through the public API.

### 2. Declaration content hashes are produced but not validated

`g3_sf_declaration_v1` computes a hash over `_g3sf_body`, and the efficiency
edit test checks that changing efficiency changes the hash. However,
`g3_sf_validate_v1` never recomputes or compares
`x.declaration_hash == canonical_hash(_g3sf_body(x))`. A manually reconstructed
or tampered `G3SFDeclarationV1` can pass validation/admission with a stale
declaration hash. There is no declaration-hash tamper test. The required
content-hash-preserving contract is incomplete until validation rejects the
tamper as `fail_closed`.

### 3. Actual authority ref/hash is type-checked, but not identity-checked

`G3SFAuthorityV1` requires an `actual` authority to carry a v5
`GenomeContractRef` and a `Digest256`, and all authority candidate refs must
equal the declaration candidate ref. This is only shape checking. The source
does not verify that `contract_hash` is the content hash of `contract_ref`, that
the ref belongs to a supplied same-candidate G1/G2 package, or that the
feedback target's authority ref/hash matches the target layer's exact upstream
public ref/hash. An arbitrary v5 ref and arbitrary digest could be labeled
`:actual` and admission would treat the authority gap as resolved.

The current fixture correctly uses `missing` authority and remains
`terminal_deferred`; it must not be upgraded using historical A/H0/E1/E2
receipts. The next repair needs an explicit same-candidate binding input or an
unambiguous `actual` authority verification gate, plus foreign/stale ref/hash
negative controls.

### 4. `program_exception` exists in the admission taxonomy but is not independently reachable in tests

`g3_sf_admit_v1` has a broad catch that returns `program_exception`, while
typed contradictions return `fail_closed` and missing authority returns
`terminal_deferred`. The test reaches `fail_closed` through `nothing` and an
authority contradiction, but has no typed public-input case that deliberately
reaches and asserts `program_exception`. The current typed structs make many
malformed values constructor errors before admission, so the exception path
needs a documented test-only fault seam or a reachable malformed typed payload;
otherwise the taxonomy is only source text.

### 5. Formula strings are free text and are not bound to the numeric law

`energy_equation`, `heat_equation`, and the ledger closure `equation` are stored
as non-empty `String`s. Evaluation uses only rational `efficiency` and
`heat_fraction`; validation never parses or compares the strings with the
actual formulas. A declaration can carry a text such as `P_source = P_field`
while retaining the same numeric result and declaration hash. The fixture's
correct strings and Python check do not test this contradiction. These fields
need a typed formula representation or a canonical parser/consistency check,
with a wrong-text `fail_closed` control.

## Static checks that pass

- The source definitions are ordered coherently for the visible type and
  function references; no obvious forward-definition or `? return` pattern
  was found by the static scan. Julia parsing remains unverified until the
  serial focused lane is available.
- Endpoint, law, ledger and feedback constructors enforce typed units,
  directions, signs and non-empty owner scopes. Declaration validation checks
  common unit, owner, endpoint-set and candidate-ref consistency.
- The exact fixture arithmetic is rational and locally legal: `120 W` with
  `3/4` efficiency and `1/8` heat fraction yields `90 W`, `15 W`, `15 W`.
- Efficiency edit `7/8` changes the declaration hash and the computed field
  value to `105`; this behavior is covered, subject to the missing declaration
  hash revalidation above.
- Missing G1/G2 authority is represented by typed `missing` statuses and
  admission gaps `external_authority_gap:G1/G2`, with
  `resolution=terminal_deferred`. The fixture is candidate-owned and
  synthetic; it provides no actual-A external authority or physical feedback.

Until findings 1–5 are repaired and independently rechecked, this package is
not ready for serial focused execution. No compiler, provider, mesh,
engineering, physical, B00/B04, or R01–R10 credit is granted.
