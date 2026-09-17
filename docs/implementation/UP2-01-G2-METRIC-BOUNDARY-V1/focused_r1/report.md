# UP2-01-G2-METRIC-BOUNDARY-V1 focused R1 execution receipt

Disposition: `focused_test_failed`; `accepted=false`; `review_pending=true`.

The single authorized serial command was run once after the preflight found no
Julia/DESC process and exact R3 input hashes. The command was:

```text
julia --startup-file=no --project=. test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl
```

PID `20064` ran from the repository root at
`2026-09-14T20:35:50.4379427Z` through
`2026-09-14T20:36:00.0278564Z` and exited `1`. Raw stdout and stderr are
preserved in `stdout.txt` and `stderr.txt`; their hashes and all launcher
metadata are recorded in `output_hashes.json` and `run.json`.

The first three testsets passed: chart/determinant `20/20`, candidate-owned
mesh/face identity `10/10`, and source-edit identity `5/5`. The fourth testset
passed `13/14` and failed at
`test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl:143`:

```text
Expression: any(occursin("boundary_value_unit_mismatch"), (G.g2mb_admit(unit_source)).errors)
```

The process therefore stopped before the R3 unit-exponent testset at lines
146-174. The receipt records the observed failure without inferring whether
the mismatch is in the implementation or the assertion; no second run is
authorized in this lane. A different Luna postrun review must inspect this
failure before any repair or rerun.

The four target SHA-256 values before launch and after completion remained:

| artifact | SHA-256 | bytes |
|---|---|---:|
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` | 30773 |
| `test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl` | `c747c174471ebd3c15812a5d25bfecff0389ed6e3dcb7eec888fd47730d8b007` | 11176 |
| `test/GenomeV5/G2/metric_boundary_v1_fixture.json` | `1721eebb16ec4a4895e2f6a71c943daf1514fb4798565c44b548d8d8f22ef5d5` | 3974 |
| `test/GenomeV5/G2/static_qa_metric_boundary_v1.py` | `cf7bf40446929c8d28b21da0da61c159c0d0cdff979e042c115802fb20dd1f31` | 7104 |

Dirty status had 300 rows before and after. The matching Julia/DESC process
count was zero before launch and zero after completion. This is software test
evidence only. It grants no compiler, provider, mesh, solver, engineering,
physical, current-A, B00, B04 or R01-R10 credit. The R3 static review remains
historical input; this runtime failure keeps the focused lane pending.
