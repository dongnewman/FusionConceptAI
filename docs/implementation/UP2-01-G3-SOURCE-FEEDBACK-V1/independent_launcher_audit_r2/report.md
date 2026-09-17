# UP2-01-G3-SOURCE-FEEDBACK-V1 independent launcher audit R2

Disposition: `launcher_failure_confirmed`; focused result: `not_executed`.
`accepted=false`; `review_pending=true`.

This is a read-only different-Luna audit at HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`. The focused-R2 receipt records
the authorized command as:

```text
julia --startup-file=no --project=. test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl
```

The launcher error is the PowerShell variable collision:

```text
Cannot overwrite variable PID because it is read-only or constant.
```

It occurred at launcher line 36 while assigning `$pid = $p.Id`. The run
receipt records `started_once=true`, but the launcher stopped before copying
the child PID, draining redirected stdout/stderr, or calling `WaitForExit`
and recording an exit code. Consequently there is no Julia test result,
pass count, failure diagnosis, or runtime acceptance to infer from this
archive. The raw launcher error is preserved; the absent stdout/stderr are
explicitly represented as uncaptured rather than synthesized.

The preflight and postflight target hashes are identical to the R5 input
hashes. Dirty snapshots are byte-identical, and both process snapshots are
empty. A fresh process sweep during this audit found zero Julia/DESC
processes, so no orphan process blocks the next serial attempt.

## Safe focused-R3 retry gate

The next executor must use a task-specific variable such as
`$childProcessId`, never PowerShell's read-only `$PID`. It must create raw
stdout and stderr redirection before starting Julia, start the child once,
capture `$childProcessId`, call `WaitForExit()`, record the real exit code,
then drain and hash both streams. The retry must preserve pre/post input
hashes, process sweeps, dirty snapshots, the exact command, and the existing
R5 source/test/fixture/static-QA hashes. Until that receipt exists, focused
R2/R3 behavior remains `not_executed` and `accepted=false`.

## Input and receipt hashes

| artifact | bytes | SHA-256 |
|---|---:|---|
| `focused_r2/launcher_error.txt` | 134 | `b816f60b876a9a7f1a934253907622ab21dd6809b83d13d52487c85b73a84266` |
| `focused_r2/run.json` | 602 | `234005e2df04c396ab9d7ca2d28e23417a4279f25be5d0e111556c22d2149061` |
| `focused_r2/report.json` | 2075 | `414d3991f3d080f02f0c2952e99c8b5a47c461d51eaee618b0f11f8f1322b2dc` |
| `focused_r2/evidence_manifest.json` | 1117 | `eb6dede1809394d0f6f1d19dac7bfa80fa21e2a2b3a296c15eea291e91d6019e` |
| `focused_r2/input_hashes.json` | 731 | `256de4e93b0cf1392422b826e086a5bacedc15f9e9d5e84050fb7e339361dd5c` |
| `focused_r2/post_input_hashes.json` | 731 | `256de4e93b0cf1392422b826e086a5bacedc15f9e9d5e84050fb7e339361dd5c` |
| `focused_r2/process_before.json` | 2 | `4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945` |
| `focused_r2/process_after.json` | 2 | `4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945` |
| `focused_r2/dirty_before.txt` | 14952 | `ee90566313115d6fcb65e12120b5c965ca2a21b665c59e7b09b4628d9fbfd64b` |
| `focused_r2/dirty_after.txt` | 14952 | `ee90566313115d6fcb65e12120b5c965ca2a21b665c59e7b09b4628d9fbfd64b` |

The four target inputs remain:

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | 27969 | `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` |
| `test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl` | 8412 | `a5c2874dbcccefd78bae245e8e79e1448f5a712d843699f5fe1d5ad21d3e142e` |
| `test/GenomeV5/G3/up2_g3_source_feedback_v1_fixture.json` | 2332 | `7a09ec15949e148c87c2772319e6c018d767d23bacf131147c34b3e6ce63fc40` |
| `docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/static_qa.py` | 5251 | `111d5a2ceb9f0364c1cc7efda26d1bb9013577862ac30bd00ff9f3321c5c2642` |

