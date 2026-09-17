# UP2-01-G2-METRIC-BOUNDARY-V1 independent static precheck R4

Verdict: `pass_limited`; `review_pending=true`; `accepted=false`.
Serial focused R2: `ready_for_serial_focused=true`.
Julia/DESC: not run by this independent precheck.

The diagnostic R2 receipt is internally consistent. `run.json` reports exit
`0`, PID `54756`, `focused_test_rerun=false`, and the exact diagnostic
command. Its source hash is `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61`;
raw `stdout.txt` is 540 bytes with SHA-256
`efdf0e74947ca0990bb0aa5ba7fb874d253c144a9094d2672d7cc43ad46e5fbf`; raw
stderr is empty with SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
The actual production diagnostic result is `status=fail_closed`,
`error_code=structural_contradiction`, and
`boundary_value_unit_mismatch:face-x-min`, with the expected mesh and boundary
authority gaps. The unit values printed in the receipt support the
Dirichlet-vs-field mismatch diagnosis.

R4 is a narrow test repair. The two affected assertions now use the explicit
direction `error -> occursin("...", error)` at the chart-orientation and
boundary-value mismatch checks. The boundary negative control still requires
the full `boundary_value_unit_mismatch` token, and the production source still
emits the face-qualified error `boundary_value_unit_mismatch:face-x-min`.
The unrelated joined-gap assertion remains separate. The source, fixture, and
static-QA hashes are unchanged; the test hash changes exactly from the
diagnostic R2/R3 before value to the R4 after value recorded by the manifest.

The R4 manifest's four after hashes match the current bytes exactly, and its
JSON parses. Python static QA exited `0` with `static_qa=pass`,
`julia_or_desc_executed=false`, and `provider_or_mesh_execution=false`.
Therefore the package is ready for the single serial focused R2 run, subject
to fresh process and target-hash capture. This review does not grant compiler,
provider, mesh, solver, physical, engineering, current-A, B00, B04, or R01-R10
credit.

## Frozen evidence

- HEAD/branch: `4b69f55f7f80240147a65a22809dc1207824dde2` / `main`.
- Pre-write dirty snapshot: 3,764 entries; UTF-8/LF status SHA-256
  `ec49de5e6a96f876049a21962002151dce4299e3eb9365706c6759a411a70de4`.
- Current targets: source 30,773 bytes
  `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61`;
  test 11,208 bytes
  `1647d7f72a4d1f2a8e9ff93543058ee6a7c9799d3988911d6b8ec7d8a65121db`;
  fixture 3,974 bytes
  `1721eebb16ec4a4895e2f6a71c943daf1514fb4798565c44b548d8d8f22ef5d5`;
  static QA 7,104 bytes
  `cf7bf40446929c8d28b21da0da61c159c0d0cdff979e042c115802fb20dd1f31`.

