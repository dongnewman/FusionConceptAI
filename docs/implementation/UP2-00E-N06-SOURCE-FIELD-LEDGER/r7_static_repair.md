# E2-N06 R7 static repair evidence

Status: `review_pending`; no Julia/DESC run in this repair.

The R6 independent precheck found one test gap after the R4 Dict access
repair. The fixture now names `missing_source_selector`, and the focused
test temporarily deletes the authored `:source` selector, invokes the real
`n06_projection_from_a(package, e0)` path, asserts the explicit
`authored governing selector is missing` `ArgumentError`, and restores the
mutable selector in `finally`. The control therefore exercises the
pre-receipt projection boundary and cannot leak state into later tests.

R1-R4 focused receipts and independent prechecks remain immutable. This
repair has no provider, compiler, solver, mesh, engineering, physical, B04,
or R01-R10 credit. Static JSON, plan, hash, and diff checks are required
before a new serial focused run.
