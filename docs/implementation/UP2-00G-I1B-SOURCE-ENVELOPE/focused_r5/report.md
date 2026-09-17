# G-I1B source envelope focused R5 execution receipt

Disposition: `focused_test_passed`; `accepted=false`; `review_pending=true`.

After the R9 independent precheck reported `pass_limited` and the focused-R4 launcher audit confirmed no orphan Julia/DESC process, the corrected serial launcher executed the command exactly once:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_gi1b_source_envelope.jl
```

PID `14796` ran from the repository root at `2026-09-14T21:10:05.4292512Z` through `2026-09-14T21:12:22.1171014Z` and exited `0`. Raw stdout and stderr are preserved in `stdout.txt` and `stderr.txt`; computed byte lengths and SHA-256 values are recorded in `output_hashes.json`.

The runner reported all testsets passing, totaling `2653/2653` assertions. This includes the repeated UP1 G1/G2/G3 contract groups, the G-I1B actual-A E1-present and both-absent factory (`2024/2024`), aggregate taxonomy (`8/8`), source-envelope schema/frozen matrix (`14/14`), production boundary (`6/6`), and fixture oracle-only (`3/3`).

The four protected inputs matched the R9 freeze and remained unchanged. Dirty status was `301→301`; matching Julia/DESC process count was `0→0`. The only write scope was `docs/implementation/UP2-00G-I1B-SOURCE-ENVELOPE/focused_r5/`; no source, test, fixture, runner, core, or old evidence file was modified.

This is executable software and source-envelope contract evidence only. It grants no compiler, provider, mesh, solver, engineering, physical, current-A, B00, B04, or parent-goal credit. A different Luna postrun review is required before any acceptance decision.
