# Independent source-axis binding test report

## Scope and boundary

The harness imported the frozen R4 implementation from
`tools/up1_external_closure_r4/source_axis_binding/` without editing it. It
used synthetic `TEST_ONLY` and typed-absence fixtures plus a read-only source
capture. It did not contact a network, install packages, create external
materials, or mutate authority state.

## Serial result

On 2026-09-17 (Asia/Shanghai host; evidence timestamps are UTC), the runner
executed 15 independent tests in two separate child processes, serially. Both
children exited `0`; normalized stderr and empty stdout were consistent across
the two runs. The raw stderr SHA-256 values differ only because unittest emits
the measured wall-clock duration; both raw streams and their hashes are
retained, and the normalized hash is recorded in `serial_report.json`.

The checks independently exercised raw/PID/UTC/exit/hash evidence, git
identity fields, four-axis uniqueness, candidate/run/authority joins, canonical
and duplicate-key adversaries, source/material/ref/axis drift, and the
fail-closed non-evidence boundary. A complete fixture was classified
`TEST_ONLY`/`non_evidence`; typed absence was `terminal_deferred`; every
receipt retained `authority_evidence=false`, `formal_credit=none`, and
`no_publish=true`.

## Evidence files

- `serial_report.json` — structured serial result and claim ceiling.
- `raw/run_1.*` and `raw/run_2.*` — unmodified child streams plus PID, UTC,
  exit, and SHA-256 sidecars.
- `../../../../test/up1_external_closure_r4/source_axis_binding/` — independent
  test source.

The independent conclusion is `pass_limited`: local implementation behavior
passed the stated tests twice. This grants no external authority, does not
constitute physical or external evidence, does not award formal UP1 credit,
and does not close the frozen parent goal.
