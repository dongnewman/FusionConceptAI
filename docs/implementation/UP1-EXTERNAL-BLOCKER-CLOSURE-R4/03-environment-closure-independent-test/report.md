# Independent environment-closure test report

## Scope and boundary

The implementation under test was imported from
`tools/up1_external_closure_r4/environment_closure/` without modification.
The independent harness created only temporary fixture files and evidence
under this directory. It did not install packages, contact a network, mutate
the implementation, or treat local observations as external authority.

## Serial result

Two child runs were executed sequentially on 2026-09-17 (Asia/Shanghai host;
the receipt timestamps are UTC). Both child processes exited `0` as harness
processes, while both test payloads returned `fail_limited` because the host
refused creation of the reparse-point fixture (`OSError`). The seven other
checks passed in both legs:

1. read-only input preservation;
2. no shell/network/install and no environment-secret leak;
3. no-overwrite receipt behavior;
4. hash/PID/UTC/exit evidence;
5. missing provenance as `typed_absent`;
6. version observation not promoted to reproducible closure;
7. malicious path and argument handling.

The reparse check is not silently downgraded: because no reparse fixture could
be created, the independent conclusion is `fail_limited`. This is a limitation
of this run's host evidence, not a grant of authority to the implementation.

## Evidence

- `serial_report.json` — structured serial result and claim ceiling.
- `raw/run_1.*` and `raw/run_2.*` — raw stdout/stderr plus PID, UTC, exit, and
  SHA-256 sidecars.

The result is local behavior evidence only. It grants no external authority,
does not establish reproducible environment closure, and does not close any
formal UP1 gate.
