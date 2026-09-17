# H0-A actual-A observation acceptance R1 independent review

结论：`pass_limited`；被审接受记录的状态 `accepted_limited`，但其 `accepted=false` 的 H0-A 总门保持不变。本复核只确认一次 R2 candidate-bound source-path 软件观察的有限接受链，不扩大为 actual authority、H0-A total、UP2、B00/B04、provider、mesh、engineering、physical 或 R01–R10 证据。本复核为轻量只读 JSON、链接与哈希检查，没有运行 Julia/DESC，也没有修改旧文件。

接受记录准确引用了 R1 `receipt_erratum_r2`、R2 observation、R2 `run.json` 和上一轮 `independent_actual_observation_r2`。这些目标均存在，manifest 中记录的 SHA-256 逐项重算匹配：R1 erratum report `11439af0c32b62b16133b0753b6420d67b38fde3d8f6b0d550b0605474e9a640`、erratum manifest `46f209c3d0cfb537a60dbd01c6a56ade368b3967cab691c145b5c3035a221bd2`；R2 report `86d4871eee1d08d1d3cb392377ef49c1bc589868e9d05a3b3764e5ae0f99362c`、R2 manifest `1b8104fae4a4e6ba0e2c701b66b041480ae08d5c121d685363a039feba02fa2b`；R2 run `adead66ce4d3bc9b778b79921dbf469cf67936f85730e8e1eaed0d8c09b64649`；R2 result `1b092b02aa4656291c46e734e9b536bf81fb4ab7892cf1ec2c4ed31c22b5bdd0`；R2 raw-hash manifest `719937de24265f055dda26a9b9eb7d42c0ca672885ceabe4a7af5a1874c421a3`；独立 R2 review manifest `d97b01e5b61d00529a23a2dd019ed47f0b7cd958618520b1a1e4293ced761725`。

接受记录中的观测字段与 R2 `result.json` 一致：`terminal_deferred`、`FusionConceptAI.N06H0ATypedAbsentV1`、`declaration_is_nothing=false`、`external_ref_required`、errors 空、三个 gaps，以及 compile/provider/solver 均为零。candidate hash 与 E0 package hash 均为 `0cfe748c66121a69bf818778a92a6bce1f14bf2892f4159326c426bbc1c3a16a`，E0 bound-input hash 为 `5dc008c66d37f7f810f08ea3b30f8eafd6ca7e5fda2f128a6dd2525e2ff4cd97`。

R1 erratum 链被正确保留：原 R1 的错误 stderr digest 和 dirty 增量归因已由 append-only erratum 修正，R1 PID/exit 仍标为 uncertain；R2 的 `$childPid`、`WaitForExit()`、PID `55732`、exit `0`、UTC 区间和进程启动观察只支持 R2。接受记录也正确承认完整 OS command arguments 的唯一来源是 R2 `run.json`；R2 启动快照只包含 Julia executable path，这一限制没有被夸大为更强的独立带参数 command-line 证据。

接受记录明确将 `actual_authority`、H0-A total、UP2、B00、B04、provider、mesh、DESC、engineering、physical 和 R01–R10 全部置为 false，并保留旧软件 precursor、总接受边界、历史收据、核心索引、源码、测试和 fixture。由此，`accepted_limited` 的含义被正确限制为软件 source-path observation，不会替代物理与工程证据。

## 独立复核状态

本复核通过；接受记录可以保留 `accepted_limited=true` 与 `accepted=false` 的双层状态。未发现引用、哈希、结果字段或证据边界错误。后续仍须沿现有 R1/R2 erratum 链推进，不能把本有限接受升级为 H0-A 总门或父目标完成。

