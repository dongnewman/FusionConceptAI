# M5-C ConditionalEGraph repair R1

Status: `repair_complete_review_pending`  
Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`  
Claim ceiling: `manufactured_conditional_egraph` / `screen_only`

## Minimum source repair

The frozen source SHA before repair was
`c4271f93e3b781a36ffc3f83d5a0bf42fd51c95ba0bf92a46dba8765cd3d6ab4`; the
final SHA is
`f53854872c907626047ac582a3a1a804a3c87e6aae537522418a81328076f1b8`.

The exact source changes are:

1. In `validate_manufactured_conditional_egraph`, the ambiguous
   `x.graph === nothing || begin ... end` was replaced by explicit
   `if x.graph === nothing ... else ... end`, so the surrounding `try` has an
   unambiguous `catch`.
2. The graph status ternary is now assigned to `status_ok` and then checked by
   one explicit `status_ok || push!(...)`. This prevents ternary/`||`
   precedence from skipping `:status_mismatch` failures. An absent graph now
   explicitly requires `:terminal_deferred`.
3. The generic aliases `build_conditional_egraph`,
   `saturate_conditional_egraph`, `replay_conditional_egraph`,
   `query_conditional_egraph`, `validate`, `payload`, and `is_valid` are each
   defined only when absent. This prevents the existing M5-B generic aliases
   from causing `invalid redefinition of constant` during isolated include.

The existing source-hash checks for `source_program_hash`, M5-A source,
composition, and M5-B source remain inside the same `try/catch`. Any digest,
program, condition-catalog, or status exception is converted to a typed
`:fail_closed` failure; no check is bypassed.

## Minimal diagnostic evidence

The first authoritative M5 test run remains untouched at
`../test_execution_r1/raw/julia_tests.authoritative.{stdout,stderr}.raw`:
PID `104576`, exit `1`, with the original `try without catch or finally`
parse error at lines 378–394.

No formal tests were run for this repair. The final allowed parse/include probe
ran only after the two source edits and exited successfully:

- command: `julia --startup-file=no --history-file=no docs/implementation/UP5-EARLY-PREPARATION/M5-EGRAPH-R1/repair_r1/parse_include_probe.jl`
- PID `92192`
- UTC `2026-09-16T13:43:35.6029614Z`–`2026-09-16T13:43:37.1355668Z`
- exit `0`
- stdout/combined SHA-256 `96aff8a65eb0abd96d56f95c121d8338af0859d4662189c5372590fdca7513a1`
- stderr SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`

Two intermediate repair harness failures are retained, not overwritten: the
first used a malformed `-e` argument and the second resolved the source path
relative to the probe directory. Their raw streams and receipts remain under
`repair_r1/raw/`; the third probe is authoritative.

## Remaining risks and boundary

The source has only passed parse/include, not the M5-C test/oracle suite. The
repair does not establish e-graph construction, saturation, replay, equality,
provider, physics, engineering, candidate, B00/B04, R01–R10, or L4 evidence.
The generic alias guards intentionally preserve an earlier M5-B alias when
present; callers must use the explicit M5-C names in a combined module.
Independent Luna review and a separate Sol/root limited decision are required.
