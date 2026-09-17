# AD-48 G3 source-authority gap decomposition — status sync R1

日期：2026-09-15  
决策：`accepted_limited`  
范围：`g3_source_authority_gap_topology_only`  
验收上限：软件 readiness、三道缺口门的有限派单拓扑和条件 F0 边界。

本状态同步依据不同 `gpt-5.6-luna/high` 的 AD-48 R1 `changes_requested` 与修复后的 R2 `pass_limited`。R1 指出的 63 位 `RealizationGenomeV5.jl` SHA 已在三冻结产品中修正为完整 64 位，并由 R2 重新复核。三产品冻结如下：

| 产品 | bytes | SHA-256 |
|---|---:|---|
| `report.md` | 14214 | `7037300a6207518bf6c1369e1f2642aa9e71eeecb818aeb95e469dc80a2c360f` |
| `manifest.json` | 7228 | `31986f6f401c2b47455f3e287c18247c702cc4b6c0152714c180051fd2f9f2ba` |
| `cleanup_inventory.md` | 827 | `4a17966bd6318b900fa11b6c45bb8e1219606cabb13790c53c385b54026dc801` |

批准的拓扑是：

`AD47-W1 review → AD48-S1 → AD48-S2 factory probe → 仅当 S2 产生 AbsentG3FactoryIdentityV1 真实证据时派发 AD48-F0 → fresh S2 → AD48-S3 → fresh W1 八产品 → AD47-W2`。

S1 覆盖 realization/control/binding/bundle 四个 scope，每个 scope 两个 JSON，共 8 个产品；冻结独立 source locator、HEAD/working-tree 状态、路径、bytes、SHA、role、scope 和 UTC。S1 可在父审查完成后派发，并可与 AD47 G3 axis-schema extension 准备并行。S2 依赖 S1，共 8 个 JSON，必须以真实构造入口和实际类型/registry 状态取证。F0 严格条件派发，恰有两个源码/测试归属文件；不得先于 S2 的 factory absence 证据，完成后必须重新取证 S2。S3 依赖 S1、S2 和不同 Luna 的 source-identity review，共 8 个 JSON；随后才允许重建新鲜 W1 八产品，再进入 W2。

W1 内嵌的 `source_locator` 仍只是同一 W1 record/receipt 内的 working-tree 观察快照，不能替代独立 `SourceLocatorV1` authority input。当前 G3 source authority、factory identity、trusted source identity、candidate binding、candidate-bound axes、T0/T1/T2、UP2、provider、mesh、solver、engineering、physical、search、R01–R10 和 L4 均保持 false/0。AD-48 状态同步不创建 candidate/declaration/final identity，不改源码、测试、fixture、core、task manifest、registry 或三冻结产品/reviews。

## 验证收据

直接 JSON/hash/path/control 复核使用 `D:\Users\Newman\anaconda3\python.exe`、Python `3.13.5`，PID `91052`，UTC `2026-09-15T13:04:57.424058+00:00`，exit `0`；三产品均逐字节匹配，原始输出见 `status_sync_r1/raw/direct_json_hash_path_control.json`。规划校验使用同一 Python 环境，31 markdown、497 relative links、39 tasks、DAG acyclic，exit `0`；原始输出见 `status_sync_r1/raw/plan_validator_stdout.json`。作用域 `git diff --check` exit `0`，原始 stdout/stderr 见对应 raw 文件。所有检查是软件/工程卫生证据，不是 authority、工程或物理证据。

