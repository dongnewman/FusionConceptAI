# N06 H0-A repair R7 focused parse repair

Status: `review_pending`; `accepted=false`; runtime: `not_run`.

Focused R1 evidence identified the first module-load ParseError at
`N06DimensionedLedgerLawV1.jl:507:46`: a NamedTuple field written as
`return=:return`. The source-only repair preserves the `:return` role key with
explicit `NamedTuple{(:source,:load,:return,:heat)}(...)` construction and
preserves the existing `getproperty(effects, role)` and
`getproperty(role_effects, role)` semantics. The same source file had two more
reserved-key NamedTuple assignments in the role-effects and returned-role
values; those were repaired identically.

## Static QA

Source reserved-word assignment scan is clean; source delimiter scan passes;
focused evidence inputs remain unchanged; no Julia/DESC process was running.
No Julia/DESC command was run for R7.

The test file still contains two `return=` NamedTuple assignments at the
existing role coefficient/direction fixture lines. Test files are outside the
R7 ownership granted for this task and were intentionally not modified. This
is recorded for the next independent static review rather than silently
claiming a full repository-wide reserved-word scan.

## Diff boundary

Before: `effects=(source=:source,load=:load,return=:return,heat=:heat_rejection)`
and equivalent `role_effects`/returned-role NamedTuple literals.

After: explicit NamedTuple construction with field tuple
`(:source,:load,:return,:heat)` and values ending in `:return` or
`result[:return]`. Candidate identity, unit algebra, energy/thermal checks,
exception taxonomy, and all semantic logic are unchanged.

Actual A remains deferred; no synthetic source-backed positive, physical,
provider, mesh, engineering, B00/B04, or R01-R10 credit is claimed.
