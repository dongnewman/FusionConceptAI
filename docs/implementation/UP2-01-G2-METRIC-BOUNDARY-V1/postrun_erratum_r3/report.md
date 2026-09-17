# UP2-01-G2-METRIC-BOUNDARY-V1 postrun erratum R3

状态：`review_pending=true`，`accepted=false`。本目录只澄清 `focused_r2` 的证据语义；旧 focused receipt、源码、测试、fixture、static QA 和核心文档均未修改。本轮没有重跑 Julia/DESC。

## 需要澄清的两个执行范围

`focused_r2` 的 launcher 真实执行了 Julia：`run.json` 记录 PID `50816`、exit `0`，UTC `2026-09-14T20:53:04.6034925Z` 至 `2026-09-14T20:53:12.0300209Z`，且五个 testset 全部通过，共 `64/64`。

stdout 末行：

```text
G2_METRIC_BOUNDARY_V1_JULIA_OR_DESC_EXECUTED=false
```

这是测试/fixture 内部静态标记，不是 launcher 观测。为避免把两个范围混称，本勘误明确记录：

```text
fixture_static_julia_or_desc_executed=false
launcher_julia_executed=true
```

前者表示 fixture/static contract 不宣称 Julia/DESC 执行；后者由 `focused_r2/run.json` 的 PID、UTC、exit 和 test summaries 证明。该勘误不把 G2 mesh declaration 写成 mesh execution。

## Raw receipt 核对

直接核对 `focused_r2/stdout.txt` 与 `stderr.txt`：

| raw file | bytes | SHA-256 |
|---|---:|---|
| `focused_r2/stdout.txt` | 980 | `2fe76c7c6a7264f5449b06174f2d3a18e5f123eab581f5784c5d442e7da84a44` |
| `focused_r2/stderr.txt` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

`focused_r2/run.json` 的记录为 PID `50816`、exit `0`、前后无匹配 Julia/DESC 进程、dirty rows `300 → 300`。四个输入 hash 与原始 `input_hashes.json` 及 focused run 记录一致：

| input | SHA-256 |
|---|---|
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` |
| `test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl` | `1647d7f72a4d1f2a8e9ff93543058ee6a7c9799d3988911d6b8ec7d8a65121db` |
| `test/GenomeV5/G2/metric_boundary_v1_fixture.json` | `1721eebb16ec4a4895e2f6a71c943daf1514fb4798565c44b548d8d8f22ef5d5` |
| `test/GenomeV5/G2/static_qa_metric_boundary_v1.py` | `cf7bf40446929c8d28b21da0da61c159c0d0cdff979e042c115802fb20dd1f31` |

## Claim boundary

The focused run supports software-test evidence only: no compiler/provider/mesh execution, solver, physical, engineering, current-A, B00, B04, or R01–R10 credit. `review_pending=true` and `accepted=false` remain unchanged.
