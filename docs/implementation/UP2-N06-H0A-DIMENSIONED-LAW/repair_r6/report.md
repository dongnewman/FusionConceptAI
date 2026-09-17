# N06 H0-A repair R6 static handoff

Status: `review_pending`; `accepted=false`; runtime: `not_run`.

This test-only archive responds to `../independent_precheck_r5/report.md`.
R1-R5 evidence and source remain unchanged.

## F05 closure payload and envelope controls

The H0-A source was not modified. The existing R5 typed semantic boundary is
now covered with a second malformed `Any` payload shape: a correctly rehashed
closure payload whose `equation` field is a nontext tuple. The malformed
closure declaration is sent through both public trusted APIs:
`n06_h0a_validate(present,package,e0)` and
declaration-shaped `n06_h0a_admit_present(present,package,e0)`. Each must
return `program_exception`, carry `declaration === nothing`, and expose no raw
conversion exception.

The public foreign E0 contradiction control now explicitly asserts
`declaration === nothing`; the existing actual-A known-gap route retains its
typed deferred absence. The malformed structured `closure_relation` control
remains fail-closed, distinct from the unexpected closure-payload conversion
case.

## Claim boundary

Actual A remains deferred, synthetic present remains schema-only, and no
physical/provider/mesh/engineering/B00/B04/R01-R10 credit is claimed. Julia and
DESC were not run pending a different Luna R6 precheck.
