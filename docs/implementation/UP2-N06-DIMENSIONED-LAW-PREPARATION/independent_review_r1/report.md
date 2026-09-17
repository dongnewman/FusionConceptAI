# Independent review: N06 dimensioned-law entry audit R1

Verdict: `pass_limited` for the read-only audit and preparation boundary.
The audit is accurate as a contract/provenance gap report and its H0/H1
follow-on gates are directionally sufficient. It does not accept a dimensioned
law, N06 implementation, UP2 total, B04, provider, engineering, physical, or
R01-R10 evidence.

## Frozen inputs and independent facts

The audit's `report.json` input hashes were recomputed. All 12 listed source,
archive and acceptance hashes matched. The current N06 source hash is
`69bd82f040f405e55768e52af64b9b9b6d97272a2ec3988b66b7bdf21ec1128c`.
The R10 receipt is independently readable: PID `33836`, UTC
`2026-09-14T06:17:04.9578748Z` to `06:19:52.5473688Z`, real exit `0`, stdout
3852 bytes/SHA256
`d6975da0772b9945c73aa70e46237c4ce27372cb02e20d9419b50ac7c5e9bec3`, empty
stderr/SHA256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, and
postflight Julia/DESC counts zero. The R10 group summary is
`28/28 + 3/3 + 31/31 + 40/40` for N06; it is software contract evidence only.
No Julia/DESC was started by this review; the final process sweep was zero.

## Actual A source comparison

The G1 fixture at `test/GenomeV5/G1/fixtures.json:28-35` contains four typed
occurrences. The energy and constraint closure unit vectors are all
`[0,0,0,0,0,0,0]`; coefficients are `+1`, `-1`, `+1`, and `-1` for the
governing, source, constraint-left and constraint-right occurrences. These
labels and coefficients are real contract fields, but `energy` is a G1 ledger
label and does not establish a physical energy unit.

The G3 fixture at `test/GenomeV5/G3/fixtures.json:43-69` contains typed effort,
flow, load, return and heat-sink ports, accounts, entries and closures. The
effort unit is `[1,2,-3,-1,0,0,0]`; load/return/heat units are power-like;
source/load/return entries carry `10/1`, `-8/1`, and `-2/1`, and the energy
closure expects `0/1`. These are local G3 typed values. The feedback rows at
`test/GenomeV5/G3/fixtures.json:105-107` explicitly use null schema,
canonicalization and compatibility fields with `external_ref_required`; they
cannot authorize a G1-to-G3 law.

The audit correctly concludes that the current A package has no dimensioned G1
source quantity or auditable coefficient mapping those four dimensionless G1
occurrences to G3 power/return/heat values. AD-24 states the same boundary at
`docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md:188-204`.

## N06 law and validator boundary

`N06DimensionedConversionV1` at
`src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl:82-104` stores units, scale,
offset, rule, provenance and `law_hash`, but
`_n06_conversion_law_hash` at `:60-61` hashes the fixed rule text plus the
rule symbol. It is a schema/rule token digest, not a coefficient, efficiency,
calibration, constitutive law, or external source provenance. The validator
at `:540-580` checks local dimensional relations, effort-flow exponent sums,
zero derived offsets, G3 port/entry/closure and owner scopes; it cannot infer
the missing cross-layer law.

`_n06_actual_fields` at `:306-398` binds actual G1/G2/G3 objects and emits
typed fields, while `n06_projection_from_a` at `:400-446` records the missing
G1-to-G3 source/field/return/heat join as an authority gap. The mapping
admission at `:854-890` correctly returns `terminal_deferred` after local
joins pass, and the source's module contract explicitly says local G3 balance
is not conservation evidence. Shared owner names are not double-counting;
the account-scope checks at `:570-580` are consistent with AD-22/AD-24.

## H0/H1 gate review

The proposed H0 inputs are sufficient only if they remain mandatory: exact
candidate-bound G1 occurrence/closure selectors and source refs/hashes, exact
G2 region/boundary identity, exact G3 port/account/entry/closure/link refs,
typed units/directions/signs, a real coefficient/efficiency or calibration
provenance, closure equations, all four axes and a content hash over the law.
An authored `power_from_effort_flow` label or a G3 fixture balance cannot fill
any of those missing fields. Missing authority must remain
`terminal_deferred`; an actual typed contradiction must be `fail_closed`.

H1 must independently recompute source values, dimensions, signs,
coefficients, closures and all refs/hashes without sharing H0's row builder.
Its exit gate should require independent negative controls for missing law,
wrong dimensions, wrong sign/coefficient, foreign or stale endpoint, wrong
closure/account scope, and synthetic equality-only declarations, with zero
compiler/provider/solver calls. The audit's proposed later fresh B04
candidate-bound envelope, checker and two-process replay remains necessary and
is not satisfied by R10.

One implementation caution is retained for the next work order: current N06
selectors and conversion rules are source-level contract scaffolding, not
actual A authority. H0 must introduce a new versioned authored law identity;
it must not reinterpret the existing `_N06_G1_ROLE_SELECTORS` or
`_n06_conversion_law_hash` as physical evidence.

## Scope decision

`pass_limited` applies only to this independent audit's factual source/hash
review and the bounded H0/H1 preparation plan. The dimensioned G1-to-G3 law,
cross-layer conservation, provider/mesh/engineering/physical execution,
formal B04 and R01-R10 remain open or false. No source, test, core, run or
original audit file was changed; only this independent review directory was
written.
