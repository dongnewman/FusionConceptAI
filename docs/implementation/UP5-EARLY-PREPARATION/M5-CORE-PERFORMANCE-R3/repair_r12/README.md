# M5 core performance R3 repair R12

R12 is a minimal runtime-follow-up repair.  It preserves the R11 diagnostic
failure as raw evidence and changes only the verified-token map lookup plus a
focused verified-hit assertion.

## Archived R11 finding

The reviewer-approved direct diagnostic command exited `1` with `7 pass / 0
fail / 2 error`.  Both errors had the same root cause at
`_tac_validate_verified_token`: `getfield(map, program)` was used on an
`IdDict`, so Julia expected an integer or symbol field selector and rejected a
`TypedASTProgramV1` key.  Wall time was `13.4156 s`.  The parent-provided
input hashes and raw diagnostic remain authoritative; this lane does not
overwrite them and does not rerun the command.

## R12 repair

The token map read now uses indexed retrieval (`map[program]`) after `haskey`.
The focused test explicitly records a successful verified authority hit with
zero payload canonicalization calls, while the existing deleted-token,
replacement, and cross-owner negatives remain in place.  A static scan of all
four allowed core files found no other `getfield(map, key)` map-index misuse.

Status remains `screen_only / accepted=false / factorial_unresolved`; no formal
credit or performance claim is made.
