# Independent review r3: UP2-00D N03

Verdict: `pass_limited` for the actual-A, candidate-bound, contract-only time-authority projection. The author archive remains `review_pending` / `accepted=false`. No B00/B04, provider, mesh, engineering, physical, or R01-R10 credit is granted.

## Runtime evidence

The independent pre-run snapshot (`focused_test_prerun.json`) recorded zero Julia and zero DESC processes. Exactly one focused command was run after the lane was released:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n03_time_authority.jl
```

The synchronized runner was Julia PID `68860`, started at `2026-09-14T08:56:18.4206749+08:00` and ended at `2026-09-14T08:56:47.3423727+08:00`, with exit `0`. The stdout is 1,718 bytes and reports fixture/protocol `8/8`, five actual fields `9/9`, mutation classification `50/50`, and forged metadata/counter controls `2/2`. Stderr is 908 bytes containing only Julia documentation replacement warnings. `focused_test.exit.txt` records `0`; `post_processes.json` is `[]`, and no Julia or DESC process remains.

The author history is retained without substitution: r1 was interrupted by the N04 serialization collision and has `unknown` exit; r2 has conflicting evidence (`exit.txt=0` but the preserved outer process receipt is exit 1 with an orphaned child); r3 is the synchronized serial-only run with PID `2480`, exit `0`, and the same 8/8, 9/9, 50/50, and 2/2 summaries. None of those earlier conflicting bytes were silently promoted.

## Actual-A source checks

`n03_time_authority_projection` at `src/GenomeV5/UP2/N03TimeAuthorityProjectionV1.jl:125-173` requires a `CandidateStatePackageV5`, locates the first actual G1 equation and its referenced operator, then locates the first actual G3 controller event. Five declarations carry the package candidate ref, public G1/G3 contract ref, component candidate hash, schema hash, canonicalization hash, field path, source locator, and original typed value.

The projected fields are:

- N03-01: `G1EquationV2.temporal_kind::TimeKindV1`
- N03-02: `G1EquationV2.derivative_order::Int`
- N03-03: `G1OperatorSpecV2.temporal_kinds::Tuple{Vararg{TimeKindV1}}`
- N03-04: `G3EventV2.trigger::Symbol`
- N03-05: `G3EventV2.time::Rational{Int64}`

The actual G1/G2/G3 objects are constructed in `test/GenomeV5/UP2/n03_time_authority_tests.jl:31-64` from the versioned fixture constructors included in separate test modules, rebound to one candidate, and passed through `integrate_genome_v5`. The test checks all five declarations against that actual package and preserves the G3 policy gap `missing_candidate_bound_g3_event_time_basis_policy`.

## Classification and boundary

`_n03_mutated_projection` at `:259-274` requires an authoritative field path and exact source locator and rejects a mutation that does not change the actual source value. `n03_validate_mutation` at `:290-340` derives G1 local failures from the actual equation/operator time-kind whitelist and derivative bound. It derives the G3 local event-time failure from the event enum and nonnegative rational time. A legal scheduled G3 event remains `terminal_deferred` with `time_basis_authority_gap`; the static G1 equation semantics do not reject it. The test verifies error path, changed projection hash, candidate binding, and zero compile/provider/solver calls for all 50 mutation assertions.

The fixture's `expected_error` is metadata only. The test fixes its provisional value to `invalid_type`, compares the separately emitted `expected_actual_error`, and uses actual classification output. The two forged controls reject a non-authoritative path and a nonzero provider counter.

## Limits

This is a bounded projection of the actual A fixture, with first-equation/first-operator/first-controller-event selection matching the frozen fixture. The G3 event trigger/time checks are local only; no candidate-bound time-basis policy or exact G1-to-G3 temporal join exists, so the policy gap remains terminal deferred. Low-level synthetic projection construction and the included G1/G2/G3 fixture suites are not evidence of provider, solver, B04, geometry, engineering, physical, or R01-R10 behavior.

Only this independent review directory was written. Recommendation: retain N03 as review-pending and permit only this contract-only slice to proceed to its integration gate.

