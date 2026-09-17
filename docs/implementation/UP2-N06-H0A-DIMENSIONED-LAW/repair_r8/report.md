# N06 H0-A repair R8 test-only parse repair

Status: `review_pending`; `accepted=false`; runtime: `not_run`.

R7 static QA identified two remaining Julia reserved-key assignments in the
owned H0-A test file at `n06_dimensioned_law_tests.jl:360,362`.
`role_coefficients` and `role_directions` now use explicit
`NamedTuple{(:source,:load,:return,:heat)}(...)` construction. The values still
come from the same `:return` entry and port, so the role semantics and all
existing assertions are unchanged.

## Static QA

The reserved-word assignment scan passes for both the H0-A source and test
files. The related `:return` and source `getproperty` accesses remain present.
The fixture and runner were not modified. Julia and DESC were not run. No
runtime, physical, provider, mesh, engineering, B00, B04, or R-credit claim is
made.

## Diff and identity

Before:

```julia
role_coefficients = (source=..., load=..., return=..., heat=...)
role_directions = (source=..., load=..., return=..., heat=...)
```

After: both values are constructed with field tuple
`(:source,:load,:return,:heat)` and positional values containing the original
`:return` role entry/port results.

The test SHA256 changed from
`509582854e55383a40783df17b99261b8b84ddb64877ca5d0b132c9949817754` to
`70662390ac46a781ebf0c2e01e910ed640943b3e98c08c5d224a3e12705672dc`.
The R7 source remains
`03aa28636626efa4a5fdcb2f806e23bfc3e166f0d6fcabe72ebb0e7c6001e8dc`.

This archive requests an independent static review of R7 source plus R8 test
syntax before any serial focused runtime lane after G-I1B completes.

