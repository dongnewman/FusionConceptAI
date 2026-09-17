# M5 core performance R3 repair R3

This repair responds to independent precheck R2 and the diagnostic finding
that the earlier focused test referenced removed mutable cache fields.  The
cache is now explicitly an unexported, derivation-local performance hint; it
is never canonical/hash authority.

## Boundary and implementation

- Typed-AST cache entries are immutable records keyed by immutable program
  identity and a cheap structural fingerprint.  The cache itself is an
  immutable owner shell around mutable lookup maps; owner reassignment is not
  possible through normal field mutation.  A same-digest/different-bytes hint
  can still be manufactured by hostile same-module reflection, so it is not
  trusted: final receipt writers re-run current canonical bytes/hash and fail
  closed on mismatch.
- Condition, rule, member, proposal, and proposal-sort hits validate their
  current key material before reuse.  Rule hits use an immutable-program
  fingerprint; receipt writers still use current canonical AST bytes.
- Trace fragments carry the derivation owner, sealed rule bytes/reference, and
  a rule hash recomputed from those bytes.  Cached provenance checks every
  trace step's owner against the provenance fragment owner.
- The focused test now uses current cache APIs, covers entry/owner/condition/
  rule/member/proposal/fragment mutation and cross-derivation negatives, and
  includes a forced same-digest/different-bytes hint rejected by authoritative
  receipt validation.

No Julia process was started for this repair.  The claim ceiling remains
`screen_only / performance implementation pending runtime`.  The first exact
`_tac_permutations` search remains factorial and is intentionally not
optimized here.
