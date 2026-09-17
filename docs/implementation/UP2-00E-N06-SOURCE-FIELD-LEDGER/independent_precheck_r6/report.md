# E2-N06 independent static precheck R6

Verdict: `changes_requested`.

The frozen R6 bytes match the author handoff:

| input | SHA-256 |
|---|---|
| `src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl` | `605f3447a8a7bc0241b8efbbe778601ad56a3a811a187c642abff57493aab6d9` |
| `test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json` | `657ad5c058a0477adc01b59c11d4fc3bb7a92577d2d8d1d58a7205d0d4851d25` |
| `test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl` | `4e01d55146eaa43e82376f2e0b5f4a6e7286469d60c6aa8244d454f6d80037be` |
| `test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl` | `9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af` |

## Closed items

The R4 Julia failure at the old `_N06_G1_ROLE_SELECTORS` dot access is fixed.
Source lines 310-312 use `get(_N06_G1_ROLE_SELECTORS, :source, nothing)` and an
explicit missing-selector `ArgumentError`; the source contains no remaining
`_N06_G1_ROLE_SELECTORS.source` access. Other selector resolution uses
`get(..., join.role, nothing)` at line 460 and explicitly records
`g1_role_selector_missing`. This avoids the invalid `Dict` field access and
does not introduce `first(generator, nothing)`.

The R5 gates remain present: `n06_validate_mutation` requires package, E0,
projection and spec; `_n06_projection_matches_package` rebuilds the actual
projection and compares candidate/package/E0 hashes, three refs, axes, G1/G2/G3
locators, network, fields, authority gaps and projection hash; path, mutation
kind, source locator/type and typed source value remain checked before receipt.
Detached projection and foreign E0 controls remain in the test. Full G1/G2/G3
join, effort-flow partner, owner scope, energy boundary and dimensional law
checks remain source-backed. R1-R5 archives are untouched.

## Remaining blocker

The requested missing-selector regression is absent from the frozen test. The
only selector assertions at test lines 168-173 prove that the existing
`:source` key and fixture keys are present and equal. There is no test that
temporarily removes or supplies an absent role selector and observes the
explicit `N06 authored governing selector is missing` classification, nor a
fixture/control row for that path. This leaves the newly fixed branch
source-inspected but not regression-tested. Add an isolated test control that
copies or temporarily edits the selector table in a fresh test scope, invokes
the actual selector path, and asserts the explicit missing-selector failure;
preserve the fixture-driven source and existing hashes. Do not change the
classification merely to make the test pass.

The test's `G._N06_G1_ROLE_SELECTORS[:source]` syntax is valid dictionary
indexing and is not the R4 dot-access defect. No other source Dict dot access
was found by static search.

## Boundary and QA

No Julia or DESC was run. The precheck only permits a repair and a later fresh
serial focused run; it does not establish runtime pass, formal B04, provider,
mesh, engineering, physical, or R01-R10 credit. The cross-layer source to
field/return/heat/ledger authority remains `terminal_deferred`.

HEAD is `4b69f55f7f80240147a65a22809dc1207824dde2`. JSON parsing, control scan,
frozen hash comparison and process sweep are recorded in `qa.json`; the
current Julia/DESC sweep was empty. `validate_plan.py` was not used to upgrade
this implementation claim; its planning result is recorded only as a static
check if rerun by the integrator.
