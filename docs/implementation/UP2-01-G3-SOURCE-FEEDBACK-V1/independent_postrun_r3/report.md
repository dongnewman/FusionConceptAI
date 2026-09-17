# UP2-01-G3-SOURCE-FEEDBACK-V1 independent postrun R3

Disposition: `pass_limited`; focused software result: `45/45`.
`status=proposal`; `review_pending=true`; `accepted=false`.

This is a read-only different-Luna postrun audit at HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`. The executor command was run
once with PID `51704` and exit code `0`:

```text
julia --startup-file=no --project=. test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl
```

The raw output independently hashes to 392 bytes,
`d128334555045139ee24f9f1c5ba36d8ee1b8e92147597d594e885670e497f12`.
stderr is 0 bytes with the empty-stream SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
The output contains three completed testsets: source/feedback typed law
`9/9`, external authority and resolution ceiling `9/9`, and typed
contradiction and edit identity `27/27`, totaling `45/45`.

The four R5 inputs match the recorded focused-r3 input hashes and target
bytes. Pre/post dirty rows are both 301, dirty snapshots are identical, and
the focused-r3 pre/post process snapshots are empty. At the end of this
read-only audit, a separate live Julia process (PID 14796) was present in the
shared lane; it was not started or terminated by this audit, and it does not
alter the focused-r3 pre/post snapshots. The prior focused-r2 launcher interruption remains intact and
records `not_executed`, with its original launcher error and uncaptured
streams; it was not overwritten by focused-r3.

## Coverage and authority ceiling

The focused test exercises the typed law evaluator at 120 W with exact
90/15/15 outputs and zero energy/ledger residuals; declaration hash
recomputation and tamper rejection; typed ledger coefficient mismatch and
typed unit contradiction; public fault-keyword rejection plus the private
program-exception seam; efficiency editing with a changed declaration hash,
updated ledger coefficients, and closure checks; and zero compiler/provider,
mesh, solver, and physical calls.

The authority test deliberately remains a ceiling test. The fixture's G1 and
G2 `upstream_authority` entries have `status: missing`, so the ordinary
admission path returns `terminal_deferred` with external authority gaps.
The contradiction and trusted-looking cases verify fail-closed or deferred
classification, but they do not provide a real external receipt, compiler,
provider, mesh, solver, physical, current-A, B00, B04, or R01-R10 result.
The focused pass therefore supports only limited software contract evidence;
it does not establish external authority or physical validity.

## Protected hashes

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | 27969 | `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` |
| `test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl` | 8412 | `a5c2874dbcccefd78bae245e8e79e1448f5a712d843699f5fe1d5ad21d3e142e` |
| `test/GenomeV5/G3/up2_g3_source_feedback_v1_fixture.json` | 2332 | `7a09ec15949e148c87c2772319e6c018d767d23bacf131147c34b3e6ce63fc40` |
| `docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/static_qa.py` | 5251 | `111d5a2ceb9f0364c1cc7efda26d1bb9013577862ac30bd00ff9f3321c5c2642` |
