# E2-N06 independent static precheck R5

Verdict: `ready_for_focused_r4`.

This is an independent static precheck by a Luna distinct from the N06
author. The frozen author inputs match the bytes inspected on 2026-09-14:

| input | SHA-256 |
|---|---|
| `src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl` | `e13b0a4051c1cee65797f73e3728d590908d7c335c9c7f641cb7aaabb4084ae9` |
| `test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json` | `657ad5c058a0477adc01b59c11d4fc3bb7a92577d2d8d1d58a7205d0d4851d25` |
| `test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl` | `5576299e6364744d5f297fd58ee24f1888d37eb41a162e68b0d833ff5ac8e01f` |
| `test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl` | `9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af` |

## R4 blocker closure

1. `n06_validate_mutation` at source lines 820-837 now requires the actual
   `CandidateStatePackageV5`, actual `UP2CandidatePhysicalBindingV1`, exact
   projection, and mutation spec. Before any receipt it calls
   `_n06_projection_matches_package` (795-818), which rebuilds
   `n06_projection_from_a(package,e0)`. That rebuild revalidates the package,
   E0 binding and E0 source (387-405), then derives the actual G1/G2/G3 refs,
   selected typed fields, axes and projection hash. The comparison covers
   candidate/package/E0 hashes, all three refs, G1 equation/occurrence/closure,
   G2 region/face/locator, selected G3 link, network, fields, gaps and
   projection hash. Detached projection and foreign E0 controls are present
   in the fixture-driven test at lines 282-300. A foreign or stale input is
   rejected before mutation receipt construction.

2. Mutation routing is source-bound. `_n06_field_for_spec` and
   `_n06_validate_spec_binding` (619-664) require exactly one matching
   `field_path`, then require the registered path suffix, `mutation_kind`,
   `source_locator`, `source_type`, and typed original value. `_n06_source_field_matches`
   (666-717) resolves the collection index from the path and compares the
   selected value to the actual package object. `_n06_mutate` (719-739)
   dispatches on the validated path-derived target kind and uses the field's
   internal field id only to copy that already-selected field. `spec.id`
   appears only in the unknown-error text and receipt/result identity hash;
   the relabeled-id control at test lines 278-281 exercises this boundary.

3. There is no unchecked positional source selection. Actual A selection uses
   authored complete G1 occurrence keys, G2 interface/face selectors, typed
   predicates and unique-match/index checks (270-303, 306-386). Collection
   indices in emitted paths are computed from the selected object's unique
   identity, and the reordered-network control checks that the path changes
   with the selected object (test lines 318-324). Mapping joins independently
   check distinct roles, exact G1/G2/G3 locators, selected flow-link identity,
   effort partner, source/flow kinds, entry/closure/account ownership,
   energy boundary, and dimensional conversion/law hash (435-570). The source
   join keeps shared owner legal while rejecting duplicate account scope.

4. The contract's boundary is preserved in source declarations and result
   paths: missing cross-layer source-to-field-to-return/heat authority remains
   `terminal_deferred`; contradictory typed refs, locators, kinds, dimensions
   and closure values are `fail_closed`; unexpected source/E0 exceptions are
   surfaced as exceptions for the runner-level `program_exception` boundary.
   Invocation counters are carried in results and no compile/provider/solver
   call is introduced. The fixture and tests keep `schema_validation_only`,
   the three counters at zero, and `physical/provider/formal_B04=false`.

## Evidence and limits

The JSON fixture is read at test load and supplies the five mutation specs,
selectors, expected statuses/error classes, authority gaps and negative
control inventory. Tests exercise forged locator/type/kind, relabeled ID,
detached projection, foreign E0, duplicate IDs, missing flow partner, foreign
link, reordered network, duplicate owner scope, dimension mismatch and
derived-law offset controls. Static inspection confirms test calls use the
four-argument public signature `(package,e0,projection,spec)`.

This review did not run Julia or DESC. The verdict only permits the author's
next focused run; it does not establish runtime pass, formal B04 receipts,
provider resolution, mesh, engineering, physical evidence, or any R01-R10
credit. The existing author R1-R3 failed receipts remain historical and the
author R4 run is still a required fresh serial gate.

## QA

HEAD inspected: `4b69f55f7f80240147a65a22809dc1207824dde2`.

`python docs/v4_multitopology_generation/validate_plan.py` returned exit 0
(`checks=pass`). `git diff --check --` over the four frozen implementation
inputs returned exit 0. JSON parsing, frozen input hash comparison and the
Julia/DESC process sweep are recorded in `manifest.json` and `qa.json`; the
sweep observed active Julia parent/child processes, so this reviewer neither
started nor stopped a process and the focused run remains the author's serial
gate.
