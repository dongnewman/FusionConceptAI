# G-I1A status sync R3 provenance repair

## Verdict

`repair_complete_pending_independent_review`; current bounded status remains `accepted_limited` and `accepted=true` for the local actual-A authority-context software contract only. The independent status review R2 found one provenance defect; this R3 sidecar repairs the executable test hash chain without changing source, tests, core indexes, old run evidence, or status_sync_r2.

The accepted runtime is `focused_r2` with GI1A `79/79`, exit `0`, and independent postrun R2 `pass_limited`. The executed test bytes are the R6 repair SHA256 `83D765EC5A7FF5867F5E80D1BF4CE2DF2CAB21F55E82D63E4BA579C219A8B1AF`, not the R5 static-stage SHA `1A4737ACF6A7457B95F5B33B689AAF97866F5F7946BAABB0116200D9FB7472D6`. The R5 value is retained only as historical provenance.

The focused_r2 input manifest contains 11 files. Rechecking all 11 current paths against that manifest produced 11/11 matches, including source, fixture, corrected test, runner, and G1/G2/G3 child tests. The primary evidence manifest now points to the executed R6 test bytes; status_sync_r2 remains immutable and is superseded by this sidecar.

Scope remains limited to E1-present/E2-absent and both-absent source-bound identity, typed E2 synthetic schema/admission, program-exception/fail-closed/tamper behavior, and zero downstream counters. A real dimensioned E2 source law, UP2 total, G-I2, B00/B04, provider, mesh, engineering, physical, and R01–R10 evidence remains false. Fresh independent status review is required after this repair.
