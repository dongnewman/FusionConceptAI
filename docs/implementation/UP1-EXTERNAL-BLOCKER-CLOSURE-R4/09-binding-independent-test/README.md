# R4 source-axis binding independent test

This directory contains an independent, local-only black-box test of
`tools/up1_external_closure_r4/source_axis_binding/`. The implementation is
frozen for this test; the harness only imports it and creates evidence under
this directory.

The test covers:

- lossless raw bytes, SHA-256 and normalized locators;
- source HEAD/tree, dirty status, patch, untracked and submodule evidence;
- canonical integer-only JSON, duplicate keys, domain-separated preimages and
  derived hash checks;
- unique coverage of all four frozen axes;
- candidate, run, authority references and exact reverse-edge joins;
- raw/material/source/bundle/hash/ref/axis drift adversaries;
- `TEST_ONLY` and typed absence as non-evidence, with `formal_credit=none` and
  `no_publish=true`;
- adversarial CLI exit behavior and two serial child runs.

Run the serial test twice with:

```text
python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/09-binding-independent-test/run_serial_twice.py
```

`raw/` contains each child's unmodified stdout/stderr, PID, UTC bounds, exit
code, and SHA-256 sidecar. `serial_report.json` records normalized output
consistency because unittest embeds a wall-clock duration in stderr; raw
streams and raw hashes remain preserved. `pass_limited` means local behavior
passed twice. It is not external authority, formal UP1 credit, or permission
to publish.
