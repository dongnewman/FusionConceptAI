# AD-30 T0 focused R3 software receipt

The exact focused command executed once after the R6 independent precheck:

```text
julia --startup-file=no --project=. test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl
```

The process ran as PID `55428` from
`2026-09-14T23:26:25.9668343+00:00` to
`2026-09-14T23:26:41.6582139+00:00` and returned real Julia exit code `0`.
Raw stdout and stderr are preserved in `stdout.bin` and `stderr.bin`; their
SHA-256 values and the capture metadata hash are in `evidence_manifest.json`.

All seven testsets passed:

| testset | pass / total |
|---|---:|
| preserves complete bodies and typed gaps | 14 / 14 |
| rejects candidate and axis contradictions | 4 / 4 |
| rejects forged mapping and axis receipts | 19 / 19 |
| checks every locally verifiable G2 mapping field | 13 / 13 |
| rejects stale complete declaration hashes | 8 / 8 |
| rejects contradictory G3 authority | 8 / 8 |
| rejects bare actual feedback authority and tracks edits | 13 / 13 |
| **total** | **79 / 79** |

Post-run static QA passed. Julia/DESC processes were absent after completion and
the worktree porcelain count remained `304` before and after. This is a
software contract receipt only: T0 remains `accepted=false`, T1 no-go, and no
external mapping/axis receipt, provider, mesh, physical, or R01-R10 credit is
created. G2 evidence and four-axis records remain externally pending; G3 source
content and child identities remain typed absent.

