# AD48-S1 G3 independent source locator acceptance

日期：2026-09-15  
工作单：`AD48-S1-G3-INDEPENDENT-SOURCE-LOCATOR`  
decision：`accepted_limited`  
accepted_scope：`current_untracked_working_tree_g3_source_locator_only`

## 裁决

接受 realization、control、binding、bundle 四个 G3 scope 的八个独立 source-locator 产品。四个 scope 均为 `PresentG3SourceLocatorV1`，对应 receipt 均为 `PresentG3SourceLocatorReceiptV1`。由于全部主源和 child source 当前仍是 `absent_untracked`、`head_blob_sha256=null`，本接受仅覆盖 repository-local working-tree 的路径、字节和 SHA 闭合。

Present locator 不等于 source authority、factory identity、trusted attestation、candidate/declaration/final identity 或 checked-present Genome。S2 factory probe 已获准，必须只消费这八个冻结 locator；若证明 factory 缺失，才可进入 AD48-F0，之后仍需 fresh S2。

## 冻结产品

| scope | source locator | receipt |
|---|---|---|
| realization | 3764 bytes / `bfb7a4f2cd4e128078b38dd3f47c2e11d6a85a5350662cda400054eeec8ba029` | 6613 bytes / `fa042cdc32954d38f2c55c4204593cbbae32b309c291267841dda07a0f85408a` |
| control | 3722 bytes / `e0d3c8468210c85a3ed66a22ddee1be4d86ed3052d6a09884619d5af374490c4` | 6571 bytes / `40c223e302a2263657150d1eba088db1b21825d0db4730403719b563acdfe845` |
| binding | 4451 bytes / `07b4de5bc4b290ce60a3f5a9158c315a795a6b013db286d5c563adcbb3543eaa` | 7300 bytes / `407387f7f1e3a5e76102a3e9234d446b39a96e1bf276336584af2e02374ffd78` |
| bundle | 5773 bytes / `fb826aa4d32bd6284f3fca7ec9f21b66e3f06d1fc13d4fc678793442ccf8e361` | 8622 bytes / `bb3b187bbfc77dd55434e56c13e53793052fb61e07e4ff559c6806f1aff77772` |

八个产品在本 acceptance 中未被改写。不同 Luna/high 独立复核为 `pass_limited`，direct `74/74`、negative controls `39/39`、exit `0`，报告和 raw sidecars 保持原路径。

## 本次 status sync

本次只新增 `acceptance/{acceptance.md,manifest.json}` 与 `status_sync_r1/raw/**`。重新核对八个产品的 canonical JSON、无尾部换行、bytes/SHA、semantic hash、receipt-to-record closure、source path/HEAD/working-tree 状态、四 scope result union、mutation/HEAD/role negative controls 及 R1 continuity。direct JSON/hash/path/git-status/control 为 `199/199`，exit `0`。

规划校验为 31 markdown、497 relative links、39 tasks、DAG acyclic、exit `0`；scoped `git diff --check` exit `0`。Python 3.13.5 PID `11312`，UTC `2026-09-15T13:19:56.244557Z`。原始 stdout/stderr、计划校验、scoped diff 和 final snapshot 均在 `status_sync_r1/raw/`。

这些记录只证明软件 provenance 和工程卫生，不能代替 source authority、factory、工程、物理或 R01–R10 证据。

## 信用边界

本 acceptance 不授予 G3 source authority、factory identity、trusted attestation、source-backed declaration、candidate binding、四轴 provenance、T0/T1/T2、UP2、provider、mesh、solver、engineering、physical、search、R01–R10 或 L4 credit；相关字段保持 false/0。
