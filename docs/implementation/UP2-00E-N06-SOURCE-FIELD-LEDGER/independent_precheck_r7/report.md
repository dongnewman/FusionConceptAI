# E2-N06 independent static precheck R7

Verdict: `ready_for_focused_r5`.

This is a read-only independent static review. No Julia or DESC process was
started, and no source, test, core document, prior receipt, or run artifact was
modified. The reviewed frozen inputs are:

| input | SHA-256 |
|---|---|
| `src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl` | `605f3447a8a7bc0241b8efbbe778601ad56a3a811a187c642abff57493aab6d9` |
| `test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json` | `29d96647d5996359c231035c1a4d9a0637cf48777fc03bdc662513e9f426b2d9` |
| `test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl` | `f950e3cebcba6893c0d70032a4df53f72bb5d949f9af2f50e2c960b9ebaf7785` |
| `test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl` | `9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af` |

## R7 control review

The fixture includes `missing_source_selector` in its
`static_negative_controls`. In the focused test, after constructing an actual
A package and E0 binding, the test saves
`G._N06_G1_ROLE_SELECTORS[:source]`, executes
`delete!(G._N06_G1_ROLE_SELECTORS, :source)`, and calls the production
`G.n06_projection_from_a(package, e0)` path. The exception is captured and
asserted to be `ArgumentError` whose text contains
`authored governing selector is missing`. The production path reaches
`_n06_actual_fields`, whose `get(_N06_G1_ROLE_SELECTORS, :source, nothing)`
branch produces that exact error; this is a real missing-key check rather than
a copy or expected-label route.

The mutation is enclosed by `try ... finally`; the saved selector is restored
with `G._N06_G1_ROLE_SELECTORS[:source] = saved_source_selector` regardless of
the projection result. Subsequent test code uses the source selector again to
construct reordered-network fields and asserts the source-backed value and
changed dynamic path. That later use provides a static contamination guard: if
the `finally` restoration failed, the later production lookup would fail before
its assertions.

The R4 dot-access defect remains closed. Source lines 310-312 use `get` and an
explicit absent-selector error; no `_N06_G1_ROLE_SELECTORS.source` access exists.
R4/R5 gates remain visible in the frozen source: E0 validation precedes the
projection; actual package, E0, three outer refs, axes, G1/G2/G3 locators,
network, fields, authority gaps, and projection hash are rechecked; mutation
field path, mutation kind, source locator/type, and typed source value are
bound before producing a receipt. The current source has no
`first(generator, nothing)` fallback. The prior R1-R4 focused receipts and R1-R6
independent precheck archives remain present and are not rewritten.

## Boundary

The result only opens the next serial focused-run gate. It does not establish a
runtime pass, compiler/provider/solver execution, mesh or engineering evidence,
physical evidence, formal B04 evidence, or R01-R10 credit. Cross-layer
source-to-field-to-return/heat/ledger authority remains `terminal_deferred`.
The author archive remains `review_pending` with `accepted=false`.

## Static QA

- Frozen input SHA, byte-size, and listed manifest hash checks: pass.
- Fixture and author evidence JSON parsing: pass.
- Targeted source/test control scan: pass.
- `git diff --check` for reviewed paths: exit 0.
- Julia/DESC process sweep: zero observed before archive creation.
- No Julia/DESC execution was performed.

The exact commands and their outputs are recorded in `qa.json`, and this
review's input snapshot is in `input_hashes.json`.
