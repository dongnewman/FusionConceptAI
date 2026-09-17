# UP2-01-G2-METRIC-BOUNDARY-V1 R4 diagnostic repair

状态：`review_pending=true`，`accepted=false`。本轮只诊断并修复第三方 focused R1 在 test line 143 的失败；没有覆盖 `focused_r1/`，没有自行重跑 focused test。

## 诊断结论

在确认无 Julia/DESC/G3 进程后，运行了唯一一个最小、候选输入哈希绑定的 Julia diagnostic process。它只构造与 focused test 相同语义的 `unit_source`，并原样打印 admission：

```text
status=fail_closed
error_code=structural_contradiction
errors=("boundary_value_unit_mismatch:face-x-min",)
gaps=("mesh_execution_not_executed", "mesh_authority=no_match", "boundary_authority=no_match")
face_value_unit=UnitSignature((0//1, 0//1, 0//1, 0//1, 0//1, 1//1, 0//1))
field_value_unit=UnitSignature((0//1, 0//1, 0//1, 0//1, 0//1, 0//1, 1//1))
flux_value_unit=UnitSignature((0//1, 0//1, 0//1, 0//1, 0//1, 1//1, 0//1))
source_hash=454d9de134a0c09a5161400baae63c40be9bd54bd6c0a3158ecca0a729ddf25a
```

生产 source validator 正确地产生了 Dirichlet-vs-field unit contradiction。失败原因是 test 使用了单参数 `occursin("boundary_value_unit_mismatch")`：该 partial predicate 把搜索串绑定到了被搜索字符串位置，无法匹配带 `:face-x-min` 后缀的实际错误。修复为显式 `error -> occursin("boundary_value_unit_mismatch", error)`；同类 determinant assertion 一并改为显式参数顺序。语义未弱化，仍保留带 face id 的错误码检查。

## 诊断证据

原始诊断文件位于 `diagnostic_r2/`：`diagnostic_unit_source.jl`、`stdout.txt`、`stderr.txt`、`run.json`。诊断命令 exit `0`，PID `54756`，UTC `2026-09-14T20:45:49.6007580Z` 至 `2026-09-14T20:45:55.2997126Z`；stderr 为空。该次 Julia 诊断不是 focused 测试、compiler/provider/mesh/solver 或物理执行。

## R3 → R4 哈希

| artifact | R3 before | R4 after |
|---|---|---|
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` |
| `test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl` | `c747c174471ebd3c15812a5d25bfecff0389ed6e3dcb7eec888fd47730d8b007` | `1647d7f72a4d1f2a8e9ff93543058ee6a7c9799d3988911d6b8ec7d8a65121db` |
| `test/GenomeV5/G2/metric_boundary_v1_fixture.json` | `1721eebb16ec4a4895e2f6a71c943daf1514fb4798565c44b548d8d8f22ef5d5` | `1721eebb16ec4a4895e2f6a71c943daf1514fb4798565c44b548d8d8f22ef5d5` |
| `test/GenomeV5/G2/static_qa_metric_boundary_v1.py` | `cf7bf40446929c8d28b21da0da61c159c0d0cdff979e042c115802fb20dd1f31` | `cf7bf40446929c8d28b21da0da61c159c0d0cdff979e042c115802fb20dd1f31` |

## QA and exit boundary

Post-repair Python static QA exited `0` with `static_qa=pass`; JSON metadata parsing and `git diff --check` passed. No focused test was rerun by this worker. No Julia/DESC process remained after the diagnostic. `review_pending=true`, `accepted=false`, `claim_ceiling=contract_only`; no compiler/provider/mesh/physical/engineering/R01-R10 credit.
