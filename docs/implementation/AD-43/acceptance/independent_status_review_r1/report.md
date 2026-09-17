# AD43 acceptance status independent review R1

日期：2026-09-15  
复核者：different `gpt-5.6-luna/high` independent reviewer  
状态：`pass_limited`  
范围：只复核 AD43 acceptance status_sync_r2、四个 source-only axis contract products、既有 raw receipts 与 point-in-time exclusion。

本次复核确认 `software_contract_record_only` 边界成立。四个产品的当前
bytes/SHA-256 与 status_sync_r2 和 AD43 acceptance 记录一致：4237/
`f16a518f886c31726725e18b9b317caecb2666e9905d718c60ef35b611ad1993`、5446/
`0b68dd638641990b16a88cc3fd5a7268bd0d1fe675bf0e76e695631b61954d5a`、4968/
`1ca17e3ac7414d3a3817f3cf98436484a002f7a0d780e824f5c7a72fb2902d19`、5764/
`699291a5f5478977fb4aab92b0d101126096da97a0bb989fd600d61ed92a5a98`。四个
JSON 均可解析、lexicographic compact canonical、无 terminal LF，结果均为
`PresentAxisContractRecordV1`，其 present 语义仅为合同定义和 exact bytes 闭合。

三个具体 axis record 的 future candidate fields 均为 `null`，status 为
`typed_absent`，missing policy 为 `terminal_deferred`；共享 schema 与
acceptance decision 的相同字段也闭合。所有 candidate-bound axis/present、
authority、declaration、T0/T1/T2、provider、mesh、solver、engineering、
physical 与 R01–R10 flags 均为 `false`，运行计数为零，三项真实缺口保持
typed absence。

历史收据的独立复核 90/90、axis 直接验证 38/38、acceptance repair 独立复核
19/19、status_sync JSON/hash/path/control 24/24 均逐项核对 PID、UTC、exit、
stdout/stderr bytes 与 SHA-256；本次独立 Python 3.13.5 复核为 47/47，PID
`73688`，UTC `2026-09-15T10:49:17.6874678Z`–`2026-09-15T10:49:18.5691805Z`，
exit `0`。计划验证器重新执行为 39 tasks、DAG acyclic，PID `83688`，UTC
`2026-09-15T10:49:32.9526356Z`–`2026-09-15T10:49:33.8298701Z`，exit `0`；
独立 `git diff --check -- docs/implementation/AD-43` 为 PID `29188`，UTC
`2026-09-15T10:49:49.6273698Z`–`2026-09-15T10:49:50.3154327Z`，exit `0`，
stdout/stderr 均为空。

AD-42 W2R1 fresh payload/receipt paths 当前存在，但仍按 acceptance manifest
标记为 `point_in_time_excluded`；本复核不把它们、AD-42 W0、AD-40 W2 或任意
历史收据转移到 AD43 axis authority，也不解锁 W2R1、T0/T1/T2 或任何 R credit。
status_sync_r2 的 acceptance manifest 是注册自身输出前的快照（22719 bytes，
SHA `145046a9a8472f8d5b0b9545de578808f612b2d619e4691a3f2ac5f7ca2a3474`）；
当前文件为 22958 bytes，SHA
`4f1087ab7ac1f931b1db0a2ce1f64dc9225bdb44c7644aec73b90596856ece45`，符合其
明确的 snapshot policy，未覆盖冻结输入。

本任务只写入本目录的报告、manifest 和 evidence-only raw sidecars。前三次
验证器尝试的失败 raw streams 因键名修正而保留，最终 R4 通过；未修改四个
产品、AD43 acceptance/status_sync_r2、W2R1、core、task manifest、源码、测试
或 fixture。清理状态 closed，临时验证脚本已移除。

结论：AD43 acceptance status_sync_r2 可在 `software_contract_record_only`
范围内 `pass_limited`；该结论不提供 candidate-bound axis present、source-backed
authority、工程/物理证据或 R01–R10 信用。
