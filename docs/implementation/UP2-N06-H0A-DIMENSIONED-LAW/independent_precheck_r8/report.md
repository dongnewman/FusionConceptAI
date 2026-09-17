# H0-A independent static precheck R8

Verdict: `ready_for_serial_focused`.

This independent Luna/high review covers the R7 source-only parse repair together with the R8 test-only parse repair at frozen HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`. Julia and DESC were not run. The pre-write worktree snapshot had 296 porcelain entries and zero matching Julia/DESC processes. The prior focused R1 ParseError evidence remains unchanged and is linked by the R7/R8 archives.

## Parse repair and role semantics

The original load error was the source assignment `return=:return` at source line 507. The current source has no `return\s*=` assignment. The three affected source constructions are explicit `NamedTuple{(:source,:load,:return,:heat)}(...)` values at lines 507, 521, and 614. The two affected test constructions at lines 359 and 362 use the same valid form. The field tuple retains `:return` as a Symbol field, and the existing `getproperty(..., role)` and `result[:return]` accesses retain the role identity. The role effect map still maps the `return` role to the `:return` ledger effect; the test coefficient and direction maps preserve the original source entry and port values.

The explicit constructors produce `NamedTuple` values required by `N06H0AUnitEquationV1.role_coefficients` and `.role_directions`, so the repair does not widen or change those field types. No source semantic code was changed in R8 after the R7 source repair.

## Semantic and negative-control preservation

The source still checks input units and power output units at lines 541-548, positive scale-efficiency algebra at 549-562, calibration/closure/law payload hashes at 531-539, closure equation and structured energy/thermal relations at 563-596, source sign and direction at 597-609, owner scope at 610-613, four G3 role coefficients/directions and signs at 614-634, and energy/thermal zero-balance conditions at 636-639. The R8 test retains the source-derived positive construction and negative controls for G2 payloads, calibration/closure/law payloads, role coefficient/direction, input/output units, closure equation, owner scope, and direction (tests 324-516). These controls remain reachable through both public trusted validation/admission paths where previously covered; R8 only repairs test syntax.

Typed classification remains explicit in source lines 642-648 and public validate/admit catches at 686-752. The tests preserve typed known-gap `terminal_deferred`, typed conflict `fail_closed` with empty declaration, and malformed calibration/closure payload `program_exception` with empty declaration (tests 518-588). The malformed structured `closure_relation` control remains a distinct `fail_closed` path (tests 414-421). No classification relies on parsing an exception message.

## Source boundary and claims

The fixture declares `schema_validation_only=true` and `actual_a_positive=false`. Synthetic present construction is therefore schema-only. The actual-A helper reconstructs candidate-bound G1/G2/G3 packages from child fixtures and keeps `n06_h0a_bind_actual_a` terminal-deferred because candidate-owned dimensioned-law, scale, efficiency, calibration, closure, conservation, and external feedback authority are absent. The tests retain zero compile/provider/solver counters on those deferred paths. No physical positive, provider, mesh, engineering, B00, B04, or R01-R10 credit is granted.

## Disposition

R7's three source reserved-key assignments and R8's two test reserved-key assignments are statically closed. Current source, test, fixture, and runner hashes are frozen in the evidence manifest. This package is ready for the single serial focused Julia lane only after the parent confirms the GI1B postflight and independent postrun arrangement. This review itself did not run Julia/DESC and is not a runtime pass.