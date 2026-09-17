# UP2-01-G3-SOURCE-FEEDBACK-V1 focused R1 execution receipt

Disposition: `focused_test_failed`; `accepted=false`; `review_pending=true`.

The single authorized serial command was run once after preflight confirmed the
R3 `pass_limited` review, exact four-file hashes and no Julia/DESC process:

```text
julia --startup-file=no --project=. test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl
```

PID `49960` ran from the repository root at
`2026-09-14T20:40:54.9211201Z` through
`2026-09-14T20:40:56.8643649Z` and exited `1`. Raw stdout and stderr are
preserved in `stdout.txt` and `stderr.txt`; their SHA-256 values and launcher
metadata are recorded in `output_hashes.json` and `run.json`.

The first testset stopped during fixture construction. The observed error is:

```text
UndefVarError: `G3SFEndpointV1` not defined
```

It was raised at
`test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl:22`, while the generator
was constructing endpoint values inside `_g3sf_build`. The summary reports
`1 passed, 1 errored, 2 total`; no later source evaluation, hash tamper,
authority, fault classification or efficiency closure testset was reached.
This receipt records the runtime fact without inferring whether the missing
binding is caused by module loading, an export, or the test/source contract.
Different Luna postrun review must diagnose it before any repair or rerun.

The four target SHA-256 values before launch and after completion remained:

| artifact | SHA-256 | bytes |
|---|---|---:|
| `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl` | `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0` | 27969 |
| `test/GenomeV5/G3/up2_g3_source_feedback_v1_fixture.json` | `7a09ec15949e148c87c2772319e6c018d767d23bacf131147c34b3e6ce63fc40` | 2332 |
| `test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl` | `37a66fcee910b123183df0f6c8eec568f617e5702b6e62875a4d7e6f4d5c5838` | 8302 |
| `docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/static_qa.py` | `ff1ae5e48c83f6240a38ed1c16f39c24d141572d63e8544447313e59cb5f01f0` | 5247 |

Dirty status had 300 rows before and after. The matching Julia/DESC process
count was zero before launch and zero after completion. This is software test
evidence only. It grants no compiler, provider, mesh, solver, engineering,
physical, current-A, B00, B04 or R01-R10 credit. The R3 static review remains
historical input; this runtime error keeps the focused lane pending.
