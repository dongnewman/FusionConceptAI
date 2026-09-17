# G2 metric-boundary independent postrun R3

Verdict: `pass_limited`; `accepted=false`; `review_pending=true`.

This read-only third-party review directly verifies the preserved
`focused_r2` raw outputs, launcher receipt, four input hashes and execution
labels. No source, test, fixture, static QA, core document or old receipt was
modified, and no Julia/DESC command was run during this review.

## Launcher and fixture scope

`focused_r2/run.json` records the original command

```text
julia --startup-file=no --project=. test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl
```

with PID `50816`, UTC interval
`2026-09-14T20:53:04.6034925Z` to `2026-09-14T20:53:12.0300209Z`, and exit
code `0`. The five reported test groups total `64/64`:

- chart metric/determinant: `20/20`
- candidate mesh/face identity: `10/10`
- source-edit identity: `5/5`
- contradictions deferred: `14/14`
- unit exponent algebra: `15/15`

The stdout marker
`G2_METRIC_BOUNDARY_V1_JULIA_OR_DESC_EXECUTED=false` is a fixture/static
contract marker. It does not negate the launcher fact that Julia executed the
command. The verified meanings are therefore:

```text
fixture_static_julia_or_desc_executed=false
launcher_julia_executed=true
launcher_desc_executed=false
mesh_execution=false
```

The declaration/test run is software and contract execution evidence only;
the presence of mesh/face identity assertions is not mesh execution.

## Raw output and input audit

Direct raw-file hashes match `focused_r2/output_hashes.json`:

| raw file | bytes | SHA-256 |
|---|---:|---|
| `focused_r2/stdout.txt` | 980 | `2fe76c7c6a7264f5449b06174f2d3a18e5f123eab581f5784c5d442e7da84a44` |
| `focused_r2/stderr.txt` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

The four input artifacts match both `focused_r2/input_hashes.json` and the
current files:

| input | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | 30773 | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` |
| `test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl` | 11208 | `1647d7f72a4d1f2a8e9ff93543058ee6a7c9799d3988911d6b8ec7d8a65121db` |
| `test/GenomeV5/G2/metric_boundary_v1_fixture.json` | 3974 | `1721eebb16ec4a4895e2f6a71c943daf1514fb4798565c44b548d8d8f22ef5d5` |
| `test/GenomeV5/G2/static_qa_metric_boundary_v1.py` | 7104 | `cf7bf40446929c8d28b21da0da61c159c0d0cdff979e042c115802fb20dd1f31` |

The launcher receipt reports zero matching Julia/DESC processes before and
after, dirty rows `300 → 300`, and unchanged target hashes. The old focused_r2
receipt directory is preserved byte-for-byte; its key-file hashes are sealed
in `evidence_manifest.json` for this review.

## Claim ceiling

This review grants only `pass_limited` software-test/contract provenance with
`accepted=false`. It grants no compiler, provider, mesh execution, solver,
physical, engineering, current-A, B00, B04 or R01–R10 credit. The G2 work
order remains proposal-scoped and requires subsequent acceptance review.
