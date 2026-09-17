# G-I1B-A focused_r1 independent post-run audit

Verdict: `program_exception`; `repair_required`.

This is an independent read-only audit of the preserved focused run at
[`../focused_r1/`](../focused_r1/). The run was frozen on `main` at HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`, with 3455 dirty porcelain entries
at preflight. The recorded command was
`julia --startup-file=no --project=. test/GenomeV5/UP2/run_gi1b_source_envelope.jl`.
It started at `2026-09-14T17:53:24.3878104Z`, ended at
`2026-09-14T17:53:30.7569804Z`, ran under root PID `4384`, and exited `1`.

## Failure fact

The preserved stderr is 1078 bytes with SHA256
`b240b5d933e86f61b72adc3c87fe88e93554bb84529d56c1cb17b9d439c76313`.
It reports a Julia load-time `ParseError` at
`src/GenomeV5/UP2/GI1BSourceMutationEnvelopeV1.jl:293:148`:

`head=="n05" && context.e1 isa GI1N05PresentAuthoritySlotV1 ? return context.e1.authority.declaration,join(seg[2:end],"/") : return nothing,rest`

Julia expected `:` in the `?` expression. The runner include failed at
`run_gi1b_source_envelope.jl:7`; stdout is 0 bytes with the empty SHA256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` recorded
in the original receipt. The
runner reached zero testsets and zero observed rows. Therefore this is a
`program_exception` before test execution, not a focused test pass or a
domain-level failure classification.

The process evidence is consistent: PID 4384 was observed as `julia.exe` during
the recorded interval, and postflight matching Julia/DESC process count was
zero at `2026-09-14T17:53:30.7812916Z`. The protected before/after manifest
reports all 16 protected inputs unchanged across that failed run. That proves
run isolation, not implementation success.

## Freeze and post-run repair boundary

The focused input manifest froze the G-I1B source at
`e07e140130ce1299b70aff84f9d97a3d8cf6749d423e06f22f2822fd7de051e8` (42985B),
tests at
`5b5ffc8d0c5c0a28c64294e5d6cdef48d4b5a6dfba2d1c83ce51c8fa6b2a896e` (25255B),
fixture at
`23794ed2e7958ccd21b26418428e06279150d380e4710c77050bf8b4fe3da1c6`, and
runner at
`54132f1415faba369807857c1175c317757339b1f3451af902a5f525b0f067b5`.

Current source and tests no longer match that run input: source is now
`58e5f3aa24da64e4ca9c843fc35bba79d8089206a6b49fd56966784051a31e12` (43037B)
and tests are
`2b2280b5c75714501d3cface473cfbf7f6de8dde6034a51ff773ad904e2da0c1` (25672B).
The current source contains the explicit `if head == "n05"` branch at line
293, and repair_r6 records these changed hashes. Those edits occurred after
the focused_r1 evidence and cannot convert its exit-1 parse failure into a
successful R1 run. Current fixture, runner, and all listed dependencies still
match the focused protected manifest.

## Required disposition

Preserve the focused_r1 failure as the authoritative result for that run.
Repair the source/test pair, then perform a new serial focused run with a new
freeze, input manifest, command receipt, stdout/stderr, testset counts, and
postflight process sweep. No B00, B04, physical, engineering, or parent-goal
credit is available from this failed run or from the later static repair.
