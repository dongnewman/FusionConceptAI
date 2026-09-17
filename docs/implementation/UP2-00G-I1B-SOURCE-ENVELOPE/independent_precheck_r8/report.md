# G-I1B-A R8 independent static precheck

Verdict: `ready_for_serial_focused`.

The R8 test-only repair changes the N10-03 expected value at
`test/GenomeV5/UP2/gi1b_source_envelope_tests.jl:160` to
`package.g3.binding.contract_binding.contract_ref`. This matches the frozen
production row path `/g3/binding/contract_binding/contract_ref`, the
`GenomeContractRef` source type, and the N10 projection's
`component_identity.g3_child_refs.binding` target. The outer
`package.g3.contract_binding.contract_ref` remains the G3 layer owner used for
`source_ref` and `source_hash`; it is not the typed N10-03 field value.

The source, fixture, and runner are unchanged from the R8 freeze:

- source `58e5f3aa24da64e4ca9c843fc35bba79d8089206a6b49fd56966784051a31e12`
- fixture `23794ed2e7958ccd21b26418428e06279150d380e4710c77050bf8b4fe3da1c6`
- runner `54132f1415faba369807857c1175c317757339b1f3451af902a5f525b0f067b5`

Static review confirms that both actual-A calls remain: one with authored E1
present and one with E1/E2 absent. Each call runs the independent expected
manifest over all 50 rows and checks typed original and attempted values,
source locators/types, original/attempted/mutation hashes, row identities,
classification, and aggregate counters. The fixture and source retain five
rows per N01 through N10, unique IDs/field paths, N05 typed absence metadata,
N06 authority gaps, N09 provider gaps, and N10-05 fresh-receipt deferral.

The public factory has no `row_builder` keyword and the test retains the
`MethodError` rejection. The internal fault seam remains confined to the
controlled program-exception test; aggregate precedence still preserves
`program_exception` over `fail_closed`, and every row/envelope compile,
provider, and solver counter is asserted zero. The independent test helper
has its own attempted mutation rules and hash payload construction; it does
not call production `_gi1b_attempt` or `_gi1b_hash_typed`.

The prior `focused_r3` exit-1 evidence remains immutable. Julia and DESC were
not run during this static review, and the current process sweep is zero. A
serial focused rerun may proceed in a fresh receipt directory. This verdict
is a software gate only and grants no B00, B04, physical, engineering, or
parent-goal credit.

Freeze: HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`, current
porcelain count `297`, status snapshot SHA256
`4fc481ba691dab125a587f47b32b93e6054719d9b152043e152802b5b509952b`.
