# M5-CORE-PERFORMANCE-R3 repair R12 — independent static precheck R1

## Decision

**PASS — GO for one new diagnostic-only, serial focused Julia invocation.**

This is a static screen-only verdict. Julia/DESC was not started, product and
test sources were not edited by this review, and no performance, formal, or
factorial credit is granted.

## Frozen failure boundary

The R12 README, failure receipt, and evidence manifest consistently preserve
the upstream R11 diagnostic as:

- exit code `1`;
- `7 pass / 0 fail / 2 error`;
- wall time `13.4156 s`;
- root cause: `getfield` used with a `TypedASTProgramV1` key on the
  `verified_tokens` `IdDict`.

The R11 implementation receipt remains an implementation archive and was not
rewritten into a runtime pass. The R12 archive also retains
`screen_only / accepted=false / factorial_unresolved`, with runtime rerun
deferred and `formal_credit=none`.

The repository snapshot contains the textual R12 summary above, but does not
materialize the parent-frozen five input hashes/raw R11 stdout-stderr bundle in
this R12 directory. Therefore this review treats those hashes as external
parent authority and does not claim an independent cryptographic recheck of
them. No R11/R12 receipt is overwritten by this review.

## Static findings

### Verified-token map repair

`_tac_validate_verified_token` now performs the map membership check and then
retrieves the token with indexed `getfield(cache,:verified_tokens)[program]`.
`_tac_verified_entry` likewise uses `tokens[program]`; promotion writes
`getfield(cache,:verified_tokens)[program]=token`. This is the correct `IdDict`
key operation and removes the R11 `getfield(IdDict, TypedASTProgramV1)` error.

An independent textual scan of the four allowed core files found no remaining
`getfield(map, key)` form for the verified-token map or an equivalent map-key
selector misuse. Other `getfield` calls are field selectors with symbols or
integer tuple/struct positions, not dictionary key reads.

### Verified hit and fail-closed negatives

The focused test now makes a cold authority call, asserts the program is in
`verified_tokens`, resets the payload counter, calls the authority path again,
asserts returned bytes equal the cold result, and asserts `0` payload calls.
That second call reaches `_tac_verified_entry` and the repaired
`_tac_validate_verified_token` path, so the 0F assertion is not merely an
ordinary-cache hit.

The existing negatives remain present: deleted verified token, replaced entry,
foreign-owner token transplant, wrong program, wrong hash, wrong witness,
unverified forged entry, mutation/deletion paths, and forced same-digest
different-bytes rejection. The cold ordinary path, cold authority path, and
unverified-entry `1F` counter assertions remain adjacent to the verified-hit
assertion.

### Scope and unchanged semantics

The four core source files retain the R11 canonical/cache design: the public
canonical writer remains the factorial authority; the verified token binds
owner/program/entry nonce/bytes/hash/witness; and ordinary cache entries do not
become authority merely because their map lookup succeeds. The R12 change is
limited to indexed token-map retrieval plus the focused verified-hit test.

No M4 adapter/probe, task manifest, or `runs/` artifact was touched by this
review. No commit was created.

## Allowed next command

The parent lane may run this **once, serially, diagnostic-only** against the R12
snapshot:

```text
julia --project=. --startup-file=no --history-file=no test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl
```

The result must remain screen-only. Any fresh-process, timing, factorial-hotspot,
or broader performance conclusion remains pending its separately authorized
lane.
