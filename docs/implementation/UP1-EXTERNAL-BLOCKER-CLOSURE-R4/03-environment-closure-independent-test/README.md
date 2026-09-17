# R4 environment-closure independent test

This directory contains a black-box, local-only test of the frozen
`tools/up1_external_closure_r4/environment_closure/` implementation.

The test covers:

- read-only input preservation;
- no shell/network/package installation and no environment-secret capture;
- reparse-point rejection (the current host did not permit creation of a
  symlink, so this check is explicitly recorded as limited/failed);
- no-overwrite receipt behavior;
- SHA-256, PID, UTC timestamp, and version-probe exit evidence;
- typed-absent provenance;
- the distinction between a version observation and a reproducible closure;
- NUL, environment-marker, and malicious argument handling.

Run the two legs serially with:

```text
python docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/03-environment-closure-independent-test/run_serial_twice.py
```

`raw/` contains each child stdout/stderr, PID, UTC bounds, exit code, and
combined SHA-256. `serial_report.json` is local test evidence only. Its
`pass_limited`/`fail_limited` status is not external authority and is not a
formal UP1 gate.
