# UP2-01-G1-DIFFUSION-V1 focused R1 execution receipt

The single authorized serial focused command exited `0`:

```text
julia --startup-file=no --project=. test/GenomeV5/G1/diffusion_v1_contract_tests.jl
```

The raw stdout is preserved in `stdout.txt` and raw stderr in `stderr.txt`.
The process PID was `51988`. The output files were created at
`2026-09-14T20:31:03Z` and the final stdout write was observed at
`2026-09-14T20:31:10Z`; no Julia/DESC process remained after completion.
The three summaries report 32/32 positive, 34/34 fail-closed negative, and
5/5 source-edit identity checks, for 71/71 reported assertions. stderr is
zero bytes.

The four target files retained the preflight hashes and byte counts after the
run: source `14d26ee5...` (31,743 bytes), Julia test `34bfaf76...` (9,655
bytes), fixture `7b580bf9...` (1,582 bytes), and static QA `87f511f5...`
(4,499 bytes). The dirty entry count was 3,692 immediately before launch and
3,697 after completion; the post-run UTF-8/LF status hash is
`5a5377c953e753d7a84f540ecb0a10322a12d245f89c788ca5c9fc6356a4366d`.
The launcher captured the pre-run dirty count but not its serialized status
hash; this is recorded as unavailable rather than inferred.

This is a software test receipt only. It does not establish compiler/provider
acceptance, mesh, solver, physical, engineering, current-A, B00, B04, or
R01-R10 credit. `review_pending=true` and `accepted=false`; an independent
postrun Luna review is required.

