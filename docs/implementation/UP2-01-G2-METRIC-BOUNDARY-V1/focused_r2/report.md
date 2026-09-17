# UP2-01-G2-METRIC-BOUNDARY-V1 focused R2 execution receipt

Disposition: `focused_test_passed`; `accepted=false`; `review_pending=true`.

The single authorized serial command was run once after the R4 independent precheck reported `pass_limited`, exact target hashes were verified, and no matching Julia/DESC process was present:

```text
julia --startup-file=no --project=. test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl
```

PID `50816` ran from the repository root at `2026-09-14T20:53:04.6034925Z` through `2026-09-14T20:53:12.0300209Z` and exited `0`. Raw stdout and stderr are preserved in `stdout.txt` and `stderr.txt`; their computed hashes and launcher metadata are recorded in `output_hashes.json` and `run.json`.

All five runtime testsets passed, for `64/64` assertions:

| testset | result |
|---|---:|
| chart metric and determinant orientation | 20/20 |
| candidate-owned mesh and face identity | 10/10 |
| source-edit identity | 5/5 |
| contradictions fail closed and missing authority deferred | 14/14 |
| unit exponent algebra and derived measures | 15/15 |

The raw process output also records `G2_METRIC_BOUNDARY_V1_STATIC_TEST_DEFINED=true` and `G2_METRIC_BOUNDARY_V1_JULIA_OR_DESC_EXECUTED=false`; stderr is empty. This is executable software and contract evidence only. It does not establish compiler, provider, mesh execution, solver, engineering, physical, current-A, B00, B04, or R01-R10 credit. A third-party Luna postrun review is required before any acceptance decision.

The four protected target artifacts were unchanged during the run:

| artifact | SHA-256 | bytes |
|---|---|---:|
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` | 30773 |
| `test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl` | `1647d7f72a4d1f2a8e9ff93543058ee6a7c9799d3988911d6b8ec7d8a65121db` | 11208 |
| `test/GenomeV5/G2/metric_boundary_v1_fixture.json` | `1721eebb16ec4a4895e2f6a71c943daf1514fb4798565c44b548d8d8f22ef5d5` | 3974 |
| `test/GenomeV5/G2/static_qa_metric_boundary_v1.py` | `cf7bf40446929c8d28b21da0da61c159c0d0cdff979e042c115802fb20dd1f31` | 7104 |

Dirty status had 300 rows before and after. The matching Julia/DESC process count was zero before and after. The only write scope was `docs/implementation/UP2-01-G2-METRIC-BOUNDARY-V1/focused_r2/`; no source, test, fixture, static-QA, core, or prior evidence file was modified.
