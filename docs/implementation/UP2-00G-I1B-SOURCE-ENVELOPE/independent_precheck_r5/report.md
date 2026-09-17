# G-I1B-A independent static precheck R5

Verdict: `ready_for_serial_focused`.

This independent Luna/high review covers repair R5 only. Julia, DESC,
compiler, provider, solver, mesh, and physical processes were not started.
The fresh freeze is HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`, branch
`main`, with 3438 dirty porcelain entries, status snapshot SHA256
`1497cb32894c5ff3e80e773f1863aac68e9d45ecf3aae3643a46bc734053c0c3`, and
zero matching Julia/DESC processes. Only this R5 review directory was written.
The result carries no formal B04, physical, engineering, provider, mesh, or
parent-goal credit.

R5 closes the R4 P1. The public
`gi1b_source_mutation_envelope` method has no `row_builder` keyword and always
passes production `_gi1b_row` to the internal assembly path. The focused test
explicitly calls the public method with `row_builder=` and expects
`MethodError`; it then invokes the underscore-prefixed internal helper for the
controlled fault only. That helper is not used by the ordinary public factory
calls, so the tested E1-present/E2-absent and E1-absent/E2-absent paths read
actual A package/context objects through production source accessors.

## R5 checks

The independent expected manifest still reads typed originals from package and
E1 present/absent source objects and derives attempted values and original,
attempted, and mutation hashes independently of production attempt/hash
helpers. Both ordinary envelopes traverse 50 rows and assert row and envelope
compile/provider/solver counters are zero. The internal fault case retains a
real `program_exception` together with fail-closed error entries and asserts
aggregate precedence and zero counters. N05 E1 absence retains typed absence
identity with content/schema/canonicalization/profile/compatibility hashes;
N06/N09/N10 deferred, provider, and fresh-receipt gaps remain asserted.

The public keyword rejection is statically plausible: the only public method
has a `specs` keyword and no `row_builder` keyword, while the test's unknown
keyword call is expected to dispatch as Julia `MethodError`. The internal
helper's typed method has no competing public signature, and the fault closure
matches its `(package, context, spec)` call shape. No source routing uses the
fixture labels.

## Claim ceiling

This review is source/fixture/test/runner static evidence only. It authorizes
the next serial focused run as a software test step; it does not establish
formal B04, physics, engineering, provider, mesh, or parent-goal completion.

