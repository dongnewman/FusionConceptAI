# N06 test-only focused R9 failure

The authorized frozen runner was invoked exactly once, from
`2026-09-14T05:51:13.909664Z` to `2026-09-14T05:53:15.179636Z`, with main
PID `33600` and observed child PIDs `13708, 54652, 55796, 72544, 73372,
77544, 79896, 80456, 80604`. It returned real exit `1`. The frozen G1/G2/G3,
E0, and N06 input hashes matched; protected SHA/mtime before and after
matched; postflight Julia/DESC was empty.

The R9 test-only repair did reach the repaired baseline and all five
source-derived mutations. The raw summaries show:

- actual A authored sample and typed boundary: `28/28`;
- typed occurrence identity index: `3/3`;
- source-derived mutation controls: `31/31`.

The run then failed at `test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl:263`:

`Expression: length(_N06_FIXTURE.static_negative_controls) == 12`  
`Evaluated: 14 == 12`

The shared owner/E0 boundary group therefore ended `37 passed, 1 failed, 38
total`. This is a test/fixture count mismatch after the R9 test-only repair,
not a production validator or physical result. Raw stdout/stderr and their
receipt hashes are immutable in this directory. No repair or retry was made.

No physical, engineering, B04, provider, mesh, or R credit is granted.
