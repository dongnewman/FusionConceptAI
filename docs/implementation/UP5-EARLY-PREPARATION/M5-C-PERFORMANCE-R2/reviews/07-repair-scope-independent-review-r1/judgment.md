# M5-C Performance R2 repair-scope independent review R1 (R4)

## Decision

**GO for a later adapter-only implementation, scoped to the frozen M5-C adapter boundary; NO-GO for core performance implementation and NO-GO for any bounded Julia/performance run.** This is a read-only independent review of `07-repair-scope-contract-r4/**`, compared with `reviews/06-repair-scope-independent-review-r1/**`. No Julia, M5-C probe, DESC, S3, solver, mesh, search, or physical process was started. No contract, source, test, oracle, probe, or prior review was modified. The only write root for this review is:

`docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/reviews/07-repair-scope-independent-review-r1/**`

The R4 contract package itself remains `review_pending` / `not_implemented` /
`implementation_authorized=false` / `formal_credit=none`; this review records a
scoped future disposition and does not mutate that package manifest.

## Reproduced evidence

| check | result | evidence |
|---|---:|---|
| R4 Python self-test | exit `0`, `status=pass`, **28 tests**, stderr empty, Julia count `0` | `raw/independent_self_test.stdout.raw` |
| all declared negative vectors | exit `0`, **18/18 schema rejects**, 0 gaps | `raw/negative_vectors_replay.stdout.raw` |
| repaired negative vectors | `condition-required-closure`, `cache-owner`, `baseline-typed-absent` all rejected | `raw/negative_vectors_replay.stdout.raw` |
| baseline schema | Draft 2020-12 schema parses; positive baseline valid; populated `source_run_id` under `typed_absent` rejected | `raw/audit_checks.txt` |
| R4 package hash manifest | **25/25** records match bytes and SHA-256; aggregate record hash `f7d76b833ff8f8266ef3a351247f854931b0a55a35a36cd85737424b1ddf1cc6` | `raw/audit_checks.txt` |
| R4 frozen current inputs | **10/10** bytes and SHA-256 match | `raw/audit_checks.txt` |
| current-path dirty closure | **10/10** closure records match; exact ten-path set; pre-existing dirty boundary recorded; `outside_write_root_mutated=false` | `raw/audit_checks.txt` |
| review-06 provenance | 36/36 review-06 hash-manifest records match | `raw/audit_checks.txt` |

The R4 freeze corrects the review-06 AutoComposition stale-hash residual. The
current bytes hash to `284094e7781f41075915ab0f3b930e17e099e1fa45853218f2f639ea57e1a209`,
and the fresh R4 freeze, current-path closure, and package manifest agree.

## Closure of review-06 residuals

1. `condition-required-closure` is now rejected by the condition schema when a
   required fact is `unknown/null` under `required_all_met=true`.
2. `cache-owner` is now rejected because cache entries structurally inherit
   top-level ownership and entry objects use `additionalProperties=false`.
3. `baseline-typed-absent` is now bound to the real
   `baseline_capture_contract_schema.json`; typed-absent status requires null
   run and receipt fields and keeps `implementation_authorized=false`.
4. The fresh ten-input freeze removes the review-06 stale AutoComposition hash.

These results close the specific machine-closure and freeze findings from
review-06. They do not establish core canonicalization/saturation/key/cache
performance improvement, a runtime result, a baseline comparison, or formal
credit.

## Authorization boundary

| action | disposition |
|---|---|
| adapter-only implementation | **YES, scoped only to the frozen M5-C adapter boundary and screen-only contract; later implementation must preserve fail-closed receipts and this claim ceiling** |
| core performance implementation | **NO** — no changes to core canonicalization, saturation, proposal/member/visited identity, or shared cache seams |
| bounded Julia/performance run | **NO** — no smoke, probe, cache-on comparison, or performance lane is authorized by this review |
| baseline capture | **NO / not captured** — baseline remains `contract_only_not_captured` / `typed_absent` |
| performance credit or formal credit | **NO** |

`typed_absent` is not zero and cannot authorize a run, performance comparison,
or performance credit. A future adapter implementation must remain under the
declared screen-only scope; a separate explicit gate is required before any
runtime or performance execution. The claim ceiling remains
`manufactured_conditional_egraph/screen_only` and
`synthetic_egraph_equality/screen_only`.

## Process record

* role: read-only JSON/schema/negative-vector/hash/freeze/dirty-closure audit
* Julia/performance probe started: `false`
* source/test/contract mutation: `false`
* output-only write root: `reviews/07-repair-scope-independent-review-r1/**`
