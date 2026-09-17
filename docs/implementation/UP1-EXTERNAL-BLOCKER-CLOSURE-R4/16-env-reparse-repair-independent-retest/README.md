# UP1 R4 environment reparse repair — independent retest

This directory contains a Luna independent retest of the frozen
`tools/up1_external_closure_r4/environment_closure/collector.py`.  The test
module is a black-box/static harness; it does not edit the collector, install
packages, use the network, or make an external-closure claim.

Run the serial evidence twice with:

```text
python docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/16-env-reparse-repair-independent-retest/run_serial_twice.py
```

`serial_report.json` and `raw/run_1.*` / `raw/run_2.*` preserve payload,
stdout/stderr, PID, UTC, exit code, and SHA-256 evidence.
