# N06 G1-to-G3 dimensioned-law gap audit

Status: `read_only_audit`; no implementation or acceptance is claimed. No Julia/DESC command was run and no source, test, core, or run file was modified. The frozen inputs and their SHA256 values are recorded in `report.json`.

## What the actual A package contains

The current G1 fixture has four authored ledger occurrences in the actual candidate package:

| occurrence | closure | coefficient | unit exponents |
|---|---|---:|---|
| `governing-0/output/1`, ledger `energy` | `energy-balance` | `+1/1` | `(0,0,0,0,0,0,0)` |
| `source-0/output/1`, ledger `energy` | `energy-balance` | `-1/1` | `(0,0,0,0,0,0,0)` |
| `constraint-0/output/1`, ledger `constraint` | `constraint-balance` | `+1/1` | `(0,0,0,0,0,0,0)` |
| `constraint-0/output/2`, ledger `constraint` | `constraint-balance` | `-1/1` | `(0,0,0,0,0,0,0)` |

These are real typed `UnitSignature` values from `test/GenomeV5/G1/fixtures.json` and the G1 fixture builder, not inferred physical units. The current G1 closures are also dimensionless. The package therefore supplies no dimensioned G1 source or equation quantity from which a power, heat, return, or field conversion coefficient can be derived.

The current G3 fixture supplies typed resource and ledger values that describe the contract shape:

| role/value | direction | unit exponents | account/closure and coefficient |
|---|---|---|---|
| `source_effort` resource port | `out` | `(1,2,-3,-1,0,0,0)` | `source_effort`; effort closure expected `1/1` |
| `source_flow` resource port | `out` | `(0,0,0,1,0,0,0)` | linked to `source_power`; source entry `+10/1` |
| `load` resource port | `in` | `(1,2,-3,0,0,0,0)` | `load_power`; load entry `-8/1` |
| `return` resource port | `in` | `(0,0,0,1,0,0,0)` | `return_power`; return entry `-2/1` |
| `heat_sink` resource port | `out` | `(1,2,-3,0,0,0,0)` | `heat_rejection`; heat entry `-1/1`, thermal closure `-1/1` |

The G3 energy closure contains `source_power`, `load_power`, and `return_power` with expected balance `0/1`; the thermal closure contains `heat_rejection` with expected balance `-1/1`. The G3 entries and directions are schema values from `test/GenomeV5/G3/fixtures.json`. They establish typed port/account/closure relations and sign conventions in the current fixture. They do not prove that a dimensionless G1 ledger occurrence physically equals any of those G3 quantities.

The G3 feedback rows also carry power/heat-shaped units and source IDs (`source_flow`, `heat_sink`), but their target refs are explicitly `external_ref_required` with null schema/canonical/profile fields. They are not authority for a G1-to-G3 law.

## What N06 currently does and does not prove

`src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl:1-18` explicitly calls the projection contract-only and records missing source→field→return/heat/ledger authority as a gap. Its schema lists four role bindings, a dimensioned conversion, owner scope and provenance, but these are required fields of a candidate-owned contract; they are not supplied by the actual A package.

The current conversion vocabulary at `:38-44` is `same_dimension`, `time_derivative`, and `power_from_effort_flow`, with zero derived offset. The constructor at `:92-104` checks a versioned law ID, nonzero rational scale, supported rule, nonempty provenance, and a digest of the rule token. The source-side validator at `:540-571` checks an effort-plus-flow exponent sum, time exponent subtraction, zero derived offset, and a rule content digest. None of these lines carries a physical coefficient, calibration, constitutive equation, efficiency, sign convention tied to G1 effects, or source-backed energy/heat law. In particular, the law digest is a digest of the rule label (`_n06_conversion_law_hash` at `:60-61`), not evidence of the missing physical law.

The actual-A projection at `:400-446` binds candidate/package/E0/G1/G2/G3 identity and deliberately emits `g1_source_field_to_g3_return_heat_ledger_join_missing`. The join validator at `:449-586` can validate a supplied four-role join and checks local units, G3 kind, port/account/entry/closure identity, owner scope and the effort-flow exponent sum. It cannot create a truthful join from the present G1 dimensionless occurrences. It also treats shared owner names as legal when account scopes are distinct. The R10 focused run proves only the software slice: N06 `28/28`, occurrence index `3/3`, mutation controls `31/31`, and boundary group `40/40`, exit `0`; it does not close the declared authority gap.

E0 binds actual candidate/package/three-layer refs, hashes, axes and bound-input identity, but it does not add a dimensioned law. E1 N05 is an authored declaration over actual A and is accepted only for a limited source-bound serialization slice; its full receipt gate remains open. UP1-04A is accepted only for additive identity wiring. None of these accepted-limited records supplies the missing G1-to-G3 dimensioned conservation authority.

## Minimum authored input that is missing

An additive candidate-owned law is required. It must carry, at minimum:

1. exact G1 occurrence selectors and source ref/hash for all four occurrences;
2. exact G3 port, account, entry, closure and feedback/heat endpoints with source ref/hash and typed unit vectors;
3. an explicit mapping from G1 ledger/effect coefficient and sign to source, field, return and heat roles;
4. a dimensioned relation with named variables, unit equation, rational scale/efficiency or calibration provenance, and any time derivative/order;
5. closure equations and expected balances for energy and thermal ledgers, including sign/direction convention;
6. candidate ref, package hash, E0 bound-input hash, three public refs, component hashes, four axes, schema/canonical/profile hashes, and a content hash over the law itself.

No dimensionless-to-power coefficient or heat conversion factor is inferred here. A law that merely repeats `power_from_effort_flow` or a fixture label is synthetic schema validation, not physical input. A typed absent law must remain `terminal_deferred`; a present law whose source/ref/hash/unit/sign/closure contradicts the actual package must be `fail_closed`; an unexpected implementation exception is `program_exception`.

## Finite implementation work-order draft

**H0 — candidate-owned dimensioned law declaration and actual-A binding.** Exclusive new files should be a versioned N06 law/binding module, fixture, focused test/runner, and its implementation archive (for example `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl`, `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json`, `n06_dimensioned_law_tests.jl`, and `docs/implementation/UP2-N06-DIMENSIONED-LAW/`). Inputs are the frozen CandidateStatePackageV5, E0 binding, the four actual G1 occurrences, actual G3 network/ledger values, and an explicitly authored law. Outputs are a candidate-bound four-role law context and rebuilt identity. H0 must reject stale/foreign refs, hashes, axes, units, signs, selectors, closure accounts, and law content hashes; it must preserve absent authority as `terminal_deferred` and present contradiction as `fail_closed`. It must not edit N06’s current source or claim a physical result.

**H1 — independent law checker and replay preparation.** A different Luna owns a new checker/test/archive, consuming H0’s immutable law context and independently recomputing unit equations, signs, coefficients, closure balances and all source/hash joins. The checker must not share H0’s row-construction helper. It needs positive/negative controls for missing law, wrong dimension, wrong sign, wrong coefficient, foreign endpoint, stale source hash, wrong closure account, and synthetic equality-only declarations, with zero provider/solver calls. A later UP1-04B/G-I2 gate must freeze fresh candidate-bound B00/B04 envelopes and two-process receipts; H0/H1 local focused exits, N06 R10, documentation, or provider gaps cannot substitute for that formal gate.

Dependencies are `UP1-04A accepted_limited + E0 accepted_limited + N06 R10` → H0 → H1 → UP1-04B/G-I2 formal checker/replay. E1’s limited source-bound serialization may supply authored declaration mechanics but does not supply the missing physical law. The parent R01–R10 scope remains unchanged.

