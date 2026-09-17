# G-I1B-A independent static precheck R6

Verdict: `ready_for_serial_focused`.

The R5 focused run was independently fact-checked from the preserved
`focused_r1/` evidence: command exit `1`, stdout empty, stderr SHA256
`b240b5d933e86f61b72adc3c87fe88e93554bb84529d56c1cb17b9d439c76313`, and a
Julia load-time ParseError at
`GI1BSourceMutationEnvelopeV1.jl:293:148` stating that `:` was expected in
the `?` expression. The runner reached no testset and no row assertion.

This R6 review is static only. Julia, DESC, compiler, provider, solver, mesh,
and physical processes were not started. The fresh freeze is HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`, with 3483 dirty
porcelain entries, status snapshot SHA256
`e3bf99f8563cad3234f6d9704e820b1d339a228e69ac59d8c97a665b19db8a17`, and
zero matching Julia/DESC processes. Only this R6 review directory was written.
No B00, B04, physical, engineering, provider, mesh, or parent-goal credit is
claimed.

## R6 repair checks

`_gi1b_root_for` now uses an explicit `if head == "n05"` branch at source
lines `293-299`. With present E1 it returns the authored declaration and
`left_endpoint/endpoint_ref`; with absent E1 it returns `nothing` and the same
remaining locator. Direct tests cover both branches at
`gi1b_source_envelope_tests.jl:277-280` and `:351-354`, in addition to the
ordinary E1-present/E2-absent and E1/E2-absent factory calls.

A source-only scan found no remaining `? return` form. The remaining
question-mark expressions are value ternaries with explicit `:` arms; no
similar invalid return expression was found in this module. The R5 public
factory constraint remains: no public `row_builder` keyword, fixed production
`_gi1b_row`, and a public injection test expecting `MethodError`. The internal
fault helper, independent attempted manifest and hashes, actual-A 50-row
factory assertions, aggregate/row zero counters, error precedence, and
N05/N06/N09/N10 assertions remain present. The preserved focused_r1 exit-1
stderr and zero-testset fact are not overwritten or treated as success.

The static result authorizes a new serial focused Julia attempt. It does not
close the prior failed run and does not establish formal B04 or physical
readiness.

