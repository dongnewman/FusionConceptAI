# UP2-01-G3-SOURCE-FEEDBACK-V1 focused R2 execution receipt

Disposition: `executor_launcher_failed`; `accepted=false`; `review_pending=true`.

The authorized command was started once after the R5 independent precheck was `pass_limited`, the four target hashes matched, and no matching Julia/DESC process was present:

```text
julia --startup-file=no --project=. test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl
```

The launcher failed immediately after creating the Julia process because PowerShell variable `$pid` is a read-only built-in. The child process was not rerun. Because the failure occurred before the launcher copied the child PID, drained its redirected streams, or observed its exit code, this archive intentionally does not claim a Julia exit status and does not present synthetic stdout/stderr as raw test output. The exact launcher error is preserved in `launcher_error.txt`; `run.json` records `capture_status=interrupted_before_pid_and_stream_drain`.

The process sweep after the interruption found no Julia/DESC process. The target artifacts were not modified by this lane; their post-sweep hashes are recorded in `post_input_hashes.json`. No focused test result, pass count, or software credit is assigned. A subsequent run would require explicit serial authorization because the command has already been started once in this lane.

`accepted=false`; `review_pending=true`. No compiler, provider, mesh, solver, engineering, physical, current-A, B00, B04, or R01-R10 credit is granted.
