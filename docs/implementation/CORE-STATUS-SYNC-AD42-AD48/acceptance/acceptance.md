# CORE-STATUS-SYNC-AD42-AD48 acceptance

日期：2026-09-15  
决策：`accepted_limited`  ���
范围：`core_status_index_synchronization_only`  
复核依据：[independent review R1](../independent_review_r1/report.md)，report 5440 bytes，SHA-256 `b50e71ea7f7ef85316d2698d090f2b1702c896ddf189ddfdca1aa878dda706a0`。

## 裁决

依据不同 Luna/high 的 R1 `pass_limited`，接受该同步点的五个核心文件状态、相对链接、任务/DAG 与软件边界记录。五个核心文件的冻结 bytes/SHA、172 条同步索引链接、31 个规划 markdown、526 条规划相对链接、39 个任务和 acyclic DAG 均已由 R1 独立重算；本接受不扩展其 claim ceiling。

同步内容确认：AD-42 W2R1 仅为 fresh canonical G1/G2 source authoring；AD-43 仅为 G1/G2 四轴软件合同；AD-44 W3-A 仅为 untracked working-tree repository-design source provenance，W3-B blocked；AD-45 common `QualifiedRefV1/v5` 仅为临时 G1/G2 handle；AD-46 三个 identity work orders blocked；AD-47 W0/W1 分别为 additive G3 axis contract 与四 scope/eight typed-absence products；AD-48 S1 仅为 untracked working-tree locators。

该同步点将 AD-48 S2 记录为 `in_progress`/`pending`/unaccepted。之后出现的 S2 identity/construction products 以及后续 R1 changes_requested/repair 只可作为新的追加记录处理，不能回写或升级本 acceptance。F0 仍只能在不同 Luna 独立确认 `AbsentG3FactoryIdentityV1` 后条件派发，随后必须 fresh S2 → S3 → fresh W1 → W2。

正式主线仍为 `T0 → authority recheck → T1 → T2 → aggregate → UP2 → UP3 → UP4 → UP5 → UP6`。UP3–UP6 正式运行仍 pending。T0/T1/T2、provider、mesh、solver、engineering、physical、search、R01–R10 均 false，L4=0。文档、测试、代理、planner 和 runner exit 不构成物理证据。

## 边界与保护

本接受只新增本 `acceptance/` 目录及其 `status/raw/**`。不修改五个核心同步文件、原 sync report/manifest、R1 review、task manifest、源码、测试、fixture、runs 或既有 implementation products。R1 的失败/修复历史继续 append-only 保留。该记录是 point-in-time acceptance；后续 S2 状态另行验收，不改变本记录。

直接 hash/path/control、规划 validator、相对链接/任务/DAG 与 scoped diff 的最终命令、Python 3.13.5、PID、UTC、exit 和 raw SHA 均记录于 [status/raw](status/raw/)，manifest 自身 `self_hash_excluded=true`。
