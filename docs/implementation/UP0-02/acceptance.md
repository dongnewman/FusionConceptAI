# UP0-02 合同/协议草案交付

状态：`accepted`，范围状态：`accepted_limited`，`accepted=true`。接受范围严格为 `accepted_scope=pre_result_contract_design`：本交付提出预结果版本轴和协议设计，不代表三层 schema、provider、compiler、solver 或物理证据已经存在。

执行边界：`B00=false`、`B04=false`、`physical=false`。本档案没有 B00/B04 执行、schema/provider hash、checker/receipt 或物理结果信用。

本单实际执行模型为 `gpt-5.6-luna`，reasoning effort `high`。仓库根为 `D:\006-Programing\LMC\FusionConceptAI`，HEAD 为 `4b69f55f7f80240147a65a22809dc1207824dde2`。live goal 文件为 `runs/goal_recovery_20260913_012528_cst/goal.json`，SHA-256 为 `96d38ae3504f3bc71ed89013d9c32a9eeb9fff45be9bd65fdd5a8821489eb9af`；其 `credible_candidate_count=0`、`platform_ready=false`、`discovery_goal_achieved=false`。

合同正文见 [19_up0_02_contract_freeze.md](../../v4_multitopology_generation/19_up0_02_contract_freeze.md)，机器可解析协议见 [up0_02_protocol.json](../../v4_multitopology_generation/up0_02_protocol.json)，Sol 裁决已写入 [18_sources_and_architecture_decisions.md](../../v4_multitopology_generation/18_sources_and_architecture_decisions.md)。

## 已裁决的边界（仍待独立复核）

- 四版本轴独立：payload schema、canonicalization/hash profile、grammar/capability applicability profile、execution/evidence receipt。
- 新类型为 G1 `MechanismGenomePayloadV2`/`MechanismGenomeV5`，G2 `FieldGeometryGenomeV5`，G3 `RealizationControlGenomeV5`（含 `RealizationGenomeV5`、`ControlGenomeV5`、`CoupledRealizationControlBindingV2`）。`CandidateStatePackage` 对外保留 G1/G2/G3 各一个独立 `GenomeContractRef`；仅 G3 external bundle ref 内携带三个 child refs。
- V1/V4 bytes、hash、candidate identity、receipt 和 evidence 只读；G1 `wire-domain:v2` 不等于 `MechanismGenomePayloadV2`。
- 新 operator 只进入 candidate-owned additive registry，不修改 `default_operator_registry()`。
- 内部 ECF `unsupported` 只能经显式映射成为中间 provider gap 或 `resolution=terminal_deferred`，不能成为最终 authority。
- B00 F0–F5、B04 N01–N10、UP1-FX-001 及 B01–B13 pending/trigger 均已写入 19 和 JSON。B04 的每类五个条目是 `illustrative_contract_mutations_pending_schema_binding`，不是 JSON Pointer、可运行 suite 或 execution pass；正式运行前仍须由 UP1 schema/validator 另冻真实路径和 receipt。结果前必须冻结量纲、归一化、阈值、预算、seed、环境、independence group 与 claim ceiling。

## 精确协议交付

B00 F0–F5 依次覆盖输入登记、canonical package、独立 replay、标签擦除、provider/ECF 路由、证据闭合；两个独立进程的 canonical package/hash 以及标签擦除后的 route/hash/decision diff 必须为零，但本单不执行这些门。B04 十类负例已各登记五个 illustrative 变体；当前没有 validator execution、calls=0 运行证据或 B04 acceptance，UP1-04 不得提前接受。UP1-FX-001 是 3D 两域合同级 fixture，结构 admission 预期为 `after_schema_available`；没有 provider 时预期为 `provider_match=no_match`、`resolution=terminal_deferred`、`physical_solver=not_executed`、`claim_ceiling=none`、`scope=contract_only`。

所有尚未取得实现或 provider 的 `schema_hash`、`canonicalization_hash`、`profile_hash`、`provider_manifest_hash` 和 receipt 均显式为 `null`/`pending`，没有使用旧 hash、零值或猜测值。B01–B13 的正式字段仍 pending，分别等待 19 中列出的 UP1–UP6 输入触发；不能查看结果后调门。

## UP1 并行路径建议

UP1-01 仅写 `src/GenomeV5/G1/` 与 `test/GenomeV5/G1/`；UP1-02 仅写 `src/GenomeV5/G2/` 与 `test/GenomeV5/G2/`；UP1-03 仅写 `src/GenomeV5/G3/` 与 `test/GenomeV5/G3/`。三者分别交付 admission/负例、region/interface/mesh plan、realization/control/fault binding；UP1-04 独占公共入口、迁移 receipt 和 identity 重建。本单未实施这些路径，也未改源码或测试。

## 证据、命令和退出

只读核对命令在仓库根执行：`Get-Content -Raw` 读取指定规范与 UP0-01，`Get-FileHash -Algorithm SHA256` 记录输入，`git rev-parse HEAD`、`git status --porcelain`、`git diff --numstat` 核对基线。命令组 exit `0`。PowerShell 对 protocol、evidence manifest 和 19 内 JSON fixture 的 `ConvertFrom-Json` 解析检查 exit `0`；F0–F5 数量为 6、N01–N10 数量为 10。B00/B04 未执行。本次没有启动 Julia/DESC、没有重跑旧任务、没有终止进程。

当前工作树保护快照为 status 250 lines、diff numstat 24 lines，其中既有保护条目为 246 lines；全部既有 dirty tracked/untracked 对象保持受保护。作者交付阶段只写 UP0-02 声明的五类文件；本次接受集成仅补写授权的状态、审查与归档链接，并未写源码、测试或旧 runs。

## 哈希时间线

任务派发时提供的 18 原始 SHA-256 `2f9a09df8944cb401949199a86e0ef8ca7f36d61bb0f583e2e685353df4ffb70` 作为历史 before-write 快照保留；该消息未携带墙上时钟，不能冒充当前值。此次修订开始前的精确 worker 捕获为 `2026-09-14T02:27:11.1330842+08:00`：18=`c482d3694e804e3c551f8b1f8474f8cefc841d8c25e0f6f9d9985fde519cfb9b`、19=`b05915a0946afe9916a0cd48a46233fbbdf3860dabc0797f216b74649ed7d7a0`、protocol=`38f894998064207c9a8765cb4a3e310ec395047dd2c94185ac556e47487a8aa0`。并发集成后的精确捕获为 `2026-09-14T02:27:26.1107501+08:00`：README=`172bdfb42732508e5bf89de6719ad0a08f579e10dd73d983aa8cc1b18ff2d584`、task_manifest=`60df2d2671b754066d0b77c883d8c32d9040b4791909ca83b8768978e28b72a5`、16=`769db4a46fdf7a7552e00fdde000cb19126ee10a94bdc8968510ca3e968151de`、UP0-01 acceptance=`04d1d0be22fe08c6ba40868bae12cd22b2c0b1a8f1845befb44581de2a684953`、UP0-01 evidence=`8485f46dbca4d6c79f57d6fa5d68eb8d769129c08cd5d562b2fd5e249f6edec3`。中间修订捕获为 `2026-09-14T02:36:25.2015026+08:00`：18=`c482d3694e804e3c551f8b1f8474f8cefc841d8c25e0f6f9d9985fde519cfb9b`、19=`afb0f8b5bd7a605a516905aea91d07fdeb5ecf5d7cb3b3ec0515382b7182f484`、protocol=`7d468989482ac2404318ea42993e7e0761554eb08b7c7f00b23e64d4ac583faf`、acceptance=`505268fd853a957ae7e3f0b980bb1ad2d647c96a7ba99207697fb54b956d8ffe`。这些值均是并发后的观察值，不能替代历史快照；本次结单 as-of 精确值记录在 `evidence_manifest.json` 的 `hash_timeline.post_revision_capture` 与 `output_hashes`。

W24 观测边界：UP0-01 的 queue、parent、child、interrupt key hashes 只在 `2026-09-14T01:39` 基线核验；本 UP0-02 没有重新哈希旧 W24 paths，也没有重新观测旧 W24 identity，因此这些值不能解释为当前状态。本单的 hash timeline 只覆盖列出的规范/归档文件。`2026-09-14T02:15` 之后由另一 Luna 动态生成的 r2 run/queue/checkpoint/log 与本协议输入无关，不进入本单 hash timeline；本单未对其做重哈希或物理判断。

## 退出边界与复核请求

本单已由不同 Luna（`up0_independent Luna(high)`）独立复核并由 Sol 接受，但仅限 `pre_result_contract_design`。后续 B00/B04 execution 及实际三层 schema/profile hash、canonicalizer、migration program/receipt、candidate-owned registry、provider signatures、B01–B10 checker、B03/B07/B08/B12/B13 数据与独立审查、锁定环境/命令和独立 replay receipt 则属于 UP1/UP1-04/UP2 运行门。缺口保持 `unknown` 或 `terminal_deferred`，不伪造 `unsupported` 或物理失败。

独立复核结论：`up0_independent Luna(high)` = `pass`，核对范围包括 18 的 AD-09–AD-16、JSON 解析、B00 F0–F5 预注册协议、B04 N01–N10 illustrative templates（非 JSON Pointer、非 execution pass）、fixture 与 protocol 结构一致性、B01–B13 触发条件、UP1 路径互斥、输入哈希时间线和 dirty 保护。Sol 决策为接受本单的预结果合同设计范围；不改变 R01–R10 或 live goal 状态。
