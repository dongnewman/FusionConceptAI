# M5 core performance R3 repair R11

R11 is the first factorial-hotspot implementation slice.  It is intentionally
screen-only: Julia/DESC is not run in this lane and no formal DAG or stage
credit is changed.

## Implemented slice

- `_tac_program_fingerprint` now emits a stored-order, full structural witness
  from expanded named tuples.  It covers the schema, concrete AST node kind
  and all node fields, roots, input ports, and manifest bindings.  It does not
  call `_tac_program_payload`, candidate generation, permutations, or typed
  JSON canonicalization.
- Derivation-local typed-AST cache misses canonicalize once.  Cache hits verify
  owner, program identity, structural witness, and the hash of the cached
  bytes.  The public `canonical_json`/`canonical_hash` path is unchanged.
- Authoritative cold misses canonicalize once and promote a cache-owned token.
  Unverified injected entries are canonicalized once and compared in full;
  verified hits do not canonicalize.  Tokens bind owner, program, entry nonce,
  bytes, hash, and structural witness.  Entry replacement, deleted token,
  foreign token, wrong program, wrong hash, wrong bytes, and wrong witness are
  fail-closed negatives.
- The cached rule writer uses current AST authority before accepting its
  performance hint, avoiding a second AST permutation search after a verified
  derivation-local entry exists.  Rule/receipt bytes remain the existing
  canonical projection.
- A disabled-by-default test-only payload-call counter records the expected
  canonicalization boundary: cold cached and authoritative paths are `1F`,
  verified/cache hits are `0F`, and an unverified injected entry is `1F`.
  Programs with 1..8 stored nodes are compared byte-for-byte and hash-for-hash
  against the pre-existing public canonical writers.

## Evidence boundary

The corrected R10 diagnostic is retained at
`../repair_r10/diagnostic_julia_r8/` and reports `57 passed, 0 failed, 0
errored`; the earlier R10 `58 passed, 1 failed, 0 errored` receipt remains raw
historical failure evidence under `../repair_r10/`.  Both are
pre-optimization evidence.  R11 adds no runtime evidence.  Fresh focused execution,
two-process/fresh-process determinism, and measured timing are deferred to the
serial parent lane.  Status stays:

`screen_only / performance implementation pending runtime / factorial root cause
implementation slice only / formal credit none`.

The remaining factorial limitation is deliberate: the public AST canonical
writer still performs exact stored-node permutation search for canonical
identity.  R11 only removes repeated entry into that search for a validated
derivation-local witness; it does not redesign the factorial authority or
raise its node-count boundary.
