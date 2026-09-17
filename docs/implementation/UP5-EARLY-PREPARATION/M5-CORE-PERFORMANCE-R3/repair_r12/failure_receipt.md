# R12 failure receipt

- Upstream raw artifact: R11 reviewer-approved diagnostic, direct command,
  exit `1`.
- Result: `7 pass / 0 fail / 2 error`.
- Wall time: `13.4156 s`.
- Root cause: `_tac_validate_verified_token` called `getfield` on the
  `verified_tokens` `IdDict` with a `TypedASTProgramV1` key.
- Repair: replace that read with indexed `verified_tokens[program]` after the
  existing `haskey` check; add an explicit verified-hit byte-equivalence test.
- Runtime rerun: deferred; Julia/DESC was not started in this lane.
- Claim ceiling: `screen_only / accepted=false / factorial_unresolved`.
