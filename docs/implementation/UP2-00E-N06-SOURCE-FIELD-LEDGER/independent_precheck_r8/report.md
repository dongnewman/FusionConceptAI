# E2-N06 independent static precheck R8

Verdict: `ready_for_focused_r6` (static readiness only; no runtime acceptance).

The frozen R6 repair closes the R5 typed-key blocker. `_n06_unique_index` at
`src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl:270-284` stores the result
of `id_of` without stringifying it, checks `unique(ids)` before construction,
and checks `haskey(index, id)` while inserting into a `Dict{Any,Any}`. Thus a
G1 occurrence key retains the declared `(String, String, Symbol, Int64)`
identity and duplicate keys fail closed. String registries retain their old
String IDs because their callers pass `x.equation_id`, `x.closure_id`,
`x.region_id`, `x.port_id`, `x.entry_id`, `x.account_id`, or `x.link_id`.

The executable typed-key test at
`test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl:203-211` constructs
exactly `("energy", "governing-0", :output, Int64(1))` and the corresponding
index-2 key, asserts both normal lookups preserve object identity, and asserts
the duplicate tuple raises `ArgumentError`. This is a real source-level
control, not a fixture metadata check. The existing fixture-driven mutation,
source-join, detached projection, foreign-E0, missing selector, duplicate
resource-port, and typed source controls remain present in the same test.

R5's exit-1 focused receipt and raw logs remain immutable evidence of the old
String(tuple) program exception. R6 is a source/test repair only; it has not
converted that historical failure into a pass and has not run Julia/DESC.
The author source, mapping fixture, mapping test, and runner hashes match the
specified frozen handoff. The current result permits one new serial focused
R6 run after Sol's lane decision. It does not grant formal B04, provider, mesh,
engineering, physical, or R01-R10 credit.

## Frozen input hashes

- source: `c5c2c59a6d79ac5e225c64cf04b0cf2cdeda3b30791ab5382d4cade4753b3bc6`
- fixture: `29d96647d5996359c231035c1a4d9a0637cf48777fc03bdc662513e9f426b2d9`
- test: `5dfab6bfc3f5c71e93889181b1f8984cab01114201531ffb252fbc757ebe3ca8`
- runner: `9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af`

The only files written by this review are the three files in this directory.
