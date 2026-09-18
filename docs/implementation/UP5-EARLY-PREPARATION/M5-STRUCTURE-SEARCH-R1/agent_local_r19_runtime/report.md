# UP5 M5 bounded structure-search R19 — serialized raw runtime evidence

日期：2026-09-18（Asia/Shanghai）
任务：`UP5-M5-STRUCTURE-SEARCH-R1`
运行：`agent_local_r19_runtime`

## 结论

R19 是本 lane 唯一一次、直接前台、串行 Julia focused run。原始 stdout/stderr
在执行期间直接重定向到 `stdout.raw`/`stderr.raw`。测试结果为 `94 passed, 0 failed,
0 errored`，`LASTEXITCODE=0`。

精确运行时间（UTC）：

- `started_utc=2026-09-18T04:04:25.0882601Z`
- `ended_utc=2026-09-18T04:04:35.7757241Z`
- `LASTEXITCODE=0`

唯一命令：

```text
julia --startup-file=no --history-file=no --project=. test/RuntimeV4/M4Isolated/bounded_structure_search_v1_tests.jl
```

Raw artifacts：

- `stdout.raw`: 116 bytes, SHA-256 `e21f3d779617fdec73a70abd507a2ecad284958efe61b1c6838bb39e0ce65070`
- `stderr.raw`: 0 bytes, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`

stdout 原文为：`Test Summary: | Pass Total Time; UP5 bounded structure-search contract | 94 94 9.1s`。
post-check 时间为 `2026-09-18T04:04:49.3917451Z`，无残留 Julia/DESC 进程。

## Frozen inputs and protected dirty hashes

以下五个 runtime 输入及两个 protected dirty 文件在运行前后 SHA-256 完全一致：

| path | SHA-256 pre = post |
|---|---|
| `src/RuntimeV4/M4Isolated/BoundedStructureSearchV1.jl` | `d811ced9245f8f5cfea2f57fcf5e5f91f379340108b2bdc3ba3415b7f25633cf` |
| `test/RuntimeV4/M4Isolated/bounded_structure_search_v1_tests.jl` | `191ea63ba2a5d0824ee2bf3096a41ee29be00e730636f4b2fbe1592174c51464` |
| `test/RuntimeV4/M4Isolated/bounded_structure_search_v1_fixture.json` | `cc77dcf441db9440c6ad822ab9134b5a7ed05ad15bc41bded0c340cdb6184cfc` |
| `test/RuntimeV4/M4Isolated/oracles/bounded_structure_search_oracle_v1.py` | `47bd46520e998966184ae6bb851dd56fa35e2cf47bd06c388cb1d0bed63fb3e7` |
| `test/RuntimeV4/M4Isolated/static_qa_bounded_structure_search_v1.py` | `2bf5a3e5b7368e57f914e5ddbaf8c8b6d7df24ac4f6ff7b35f2d9e8c12bbe599` |
| `test/RuntimeV4/M4Isolated/m5c_perf_r2/profile_probe.jl` (protected dirty) | `7d9a4452a10f726d547a61490974add77b4f14dc3db4df6b975be1e0edc18cb5` |
| `src/RuntimeV4/M4Isolated/ManufacturedConditionalEGraphV1.jl` (protected dirty) | `0041e9041b7376b3127d80454f8ffa1f455ae488b667f326719d3a0f5adf3773` |

## Scope boundary

```text
contract_only / screen_only / accepted=false / no_publish=true
no M5C credit / no UP5 credit / no R01-R10 credit
no provider / solver / mesh / physical / engineering execution
no QD/MCTS winner or promotion
```

No source, focused test, fixture, oracle, or static-QA edits were made; no DESC,
relaunch, second Julia lane, or commit occurred.
