# Independent environment reparse-repair retest

## Scope and frozen implementation

The collector was imported without modification from
`tools/up1_external_closure_r4/environment_closure/collector.py`.  The
collector SHA-256 recorded in both serial payloads is
`ce6450babcf10ad8e227d146c3fd41795596edde3d22eae315d57d3e855055e4`.
Only temporary fixtures and evidence under this directory were written.

## Result

Two runs were executed serially on 2026-09-17; receipt timestamps are UTC.
Both child processes exited `0` and returned `pass_limited`.  The focused
repair checks passed in both runs:

- static AST order confirms lexical component inspection/lstat precedes
  `resolve`; the `_lstat` OSError branch raises `CollectorError`;
- a simulated `PermissionError` from `lstat` is returned as `fail_closed`;
- a path outside the declared root is rejected as `path_escapes_root`;
- a regular file hash matches the expected SHA-256;
- identity, size, and mtime TOCTOU mutations are each rejected as
  `path_identity_changed`.

The existing eight regression checks were also run.  Seven passed.  The
reparse/symlink check could not create its fixture on this Windows host and
is recorded as `test_scope_deferred` (the legacy payload's raw status remains
`fail_limited`; the retest does not silently call that a positive result).

Therefore the bounded conclusion is `pass_limited`, not an external
authority claim and not formal UP1 gate closure.  Reparse behavior remains
unverified on a host that permits creating the relevant Windows reparse point.

## Evidence

- `serial_report.json` — structured result for both serial legs.
- `raw/run_1.*` and `raw/run_2.*` — raw stdout/stderr plus PID, UTC, exit,
  and SHA-256 sidecars.
