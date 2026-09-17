# N06 H0-A repair R5 static handoff

Status: `review_pending`; `accepted=false`; runtime: `not_run`.

This archive records the narrow response to
`../independent_precheck_r4/report.md`. R1-R4 review inputs and archives remain
read-only.

## F05 exception boundary

The trusted `n06_h0a_validate(present, package, e0)` path now wraps both
endpoint and law semantic traversals in the same typed boundary used for
projection. `_n06_h0a_validate_law` rejects malformed Any payload shapes before
conversion: nonnumeric calibration scale/efficiency, nontext closure equation,
non-tuple closure account ids, and nonnumeric closure balances become typed
`N06H0AProgramError`. Public declaration-shaped `n06_h0a_admit_present` keeps
that result envelope and never exposes the raw conversion exception.

The R5 tests create one malformed calibration payload and send the same
rehashed declaration through both public validate and public admit. Both must
return `program_exception` with `declaration === nothing`. Existing public
actual-A known-gap and foreign E0 contradiction tests remain as explicit
`terminal_deferred` and `fail_closed` controls. No message-prefix taxonomy was
reintroduced.

## Claim boundary

Actual A remains deferred for missing candidate-owned coefficient, calibration,
closure-law, and feedback authority. Synthetic present remains schema-only.
There is no physical, provider, mesh, engineering, B00/B04, or R01-R10 credit.
Julia and DESC were intentionally not run pending a different Luna R5 precheck.
