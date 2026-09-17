# UP1-03 G3 资源与实现控制合同交付

状态：`accepted`，范围状态：`accepted_limited`，`accepted=true`。接受范围仅为 `g3_structural_resource_control_fault_and_standalone_feedback_contract`：candidate-owned/edit identity、JSON 四层 refs/axes、standalone namespace/version/gap/fail-closed 与 synthetic full-ref 值比较。provider、B00/B04、跨层真实 provenance/UP1-04 join、工程、物理和 R01–R10 均不接受。

实际模型为 `gpt-5.6-luna`，reasoning effort 为 `high`。仓库根为 `D:\006-Programing\LMC\FusionConceptAI`，基线 HEAD 为 `4b69f55f7f80240147a65a22809dc1207824dde2`。输入合同使用当前 UP0-02 protocol/contract hash，旧 V1/V4 实现仅作只读边界参考。

## 实现范围

- `RealizationGenomeV5.jl` 定义独立的 `GenomeContractRef`/四版本轴/candidate binding、typed effort/flow/load/return/heat-sink/material ports、组件容量、材料域、制造域、初值、事件和 energy/material/thermal ledger。每个 account 只有一个 owner 字段，但同一 owner 可以合法持有多个账户；每个 resource port 都必须有可消费 entry 且 account 出现在 closure，source effort/flow 必须按 component 配对，容量超限、回流或热汇 entry/closure 缺失、entry account 缺失时 fail closed；closure 检查对未知 account 安全过滤，不抛 KeyError；被动组件不能产生 source entry。
- `ControlGenomeV5.jl` 定义独立 signal ports、sensor/actuator controller、fault path、初值和事件。open circuit、sensor dropout、actuator stuck 等故障保持 typed contract；provider 状态不由控制结构伪造。
- `CoupledRealizationControlBindingV2.jl` 定义 control-resource link 与分别指向 G1/G2 的 implementation error、loss、thermal load、deformation feedback channel。每个 child ref 独立且 candidate-bound；反馈目标先做目标层 namespace/version/type 检查。没有实际 G1/G2 公共 ref 时记录 `feedback_authority_gap`，不会把 fixture ref 当 authority；`g3_compare_feedback_target_refs` 只比较 supplied full-ref 值，匹配也保留 authority gap，四轴、candidate 和 provenance join 留给 UP1-04。
- `RealizationControlGenomeV5.jl` 组装外部 G3 bundle，执行资源/账本/控制/故障/跨层 binding admission，并提供 component capacity 与 fault edit；编辑会重建 child plan hash 和 bundle candidate hash。
- schema、canonicalization 和 applicability profile hash 由 G3 文件中的版本化字段/类型/约束及规则 source 常量通过 `digest256_text` 计算，不采用旧值、零值或猜测值；canonicalization source 与 canonicalization-profile 轴均为 `v5`。每个 layer 的 `GenomeContractRef` 与四版本轴必须精确匹配本层权威 ref；bundle/realization/control 使用合同修订 `v5`，binding child 使用 `v2`，不能按 Julia 类型名或通配版本接受。缺失的外部 provider 或 G1/G2 authority 只产生 gap 与 `resolution=terminal_deferred`，结构错误仍 `fail_closed`。

## 测试和执行边界

专属 recipe 已冻结；此前 r5 针对上一版源码/fixture 执行成功；本轮补入 fixture 完整构造、ControlPlan 唯一性和 binding `v2` 语义后，已串行重跑 r6、r7、r8 并 exit 0。r9 在加入四层 JSON candidate refs/axes、G1/G2 authority gap、ref 值比较器、错轴/错候选/错误反馈层负控及 canonicalization v5 对齐后运行；r1–r10 保留为历史证据，不能改写为物理失败。首次尝试保留为 `g3_focused_20260914`（exit 1，component kind Symbol 构造异常）；第二次 `..._r2`（exit 1，signal kind Symbol 构造异常）；第三、四次 `..._r3`/`..._r4`（exit 1，测试断言暴露 missing-return 负控预期问题）；历史 `..._r5`–`..._r10` 均保留其真实分类和日志。

```powershell
julia --startup-file=no --project=. test/GenomeV5/G3/up1_g3_contract_tests.jl
```

W24 r2 heavy lane 的历史 wrapper/Julia PID `16512`/`5812` 约在 `2026-09-14T02:15:53/57` 启动，已释放。r9 在无 Julia/DESC 的独占窗口执行但因旧负控与新 JSON 解析边界不匹配 exit 1，原始日志保留；局部修复后 r10 于 `2026-09-14T04:54:07.6752510+08:00` 启动、`04:54:20.5041548+08:00` 结束，wrapper/Julia PID `64096`，exit `0`。r11 与仅措辞/标注变更后的 r12 均在 lane 释放后执行，r12 的真实开始/结束时间、PID、stdout/stderr/exit/metadata 写入 `g3_focused_20260914_r12/`；r1–r11 及 r9 失败证据均保留。本次只验证结构合同与负控，不产生 provider、工程或物理 evidence。

fixture 由 focused test 实际读取 `test/GenomeV5/G3/fixtures.json`，并驱动完整 resources/accounts/entries/closures/components/materials/manufacturing/signals/faults/controllers/control plan/links/feedback 构造及 negative mutation 选择。四层 candidate refs 和四轴均从 JSON 解析，并逐层精确断言本层 URI/version；测试覆盖错候选、错轴、错误反馈层、外部 authority 缺失 gap，以及标记为 `synthetic_equality_only` 的 supplied-ref 值比较（匹配不清除 gap）。静态测试覆盖合法资源网络、provider deferred、三类账本、source/return/heat-sink、entry/closure 缺失、容量超限、单位错、同一 owner 持有多个账户的合法语义、被动 source、open loop、fault target/detection 缺失、组件编辑、故障编辑、独立 child refs、G1/G2 feedback 以及 legacy version 反例。未运行测试不能替代真实执行证据。

## 受限结论和后续门

当前可复核且经不同 Luna 独立复核通过的结论限于上述结构合同和 fail-closed admission；`physical_result=false`、`engineering_result=false`、`provider_result=false`、`claim_ceiling=none`、`scope=contract_only`，且 `credible_device_count` 不增加。该交付不证明任何 source inverse、材料性能、热结构稳定性、控制恢复或目标场实现。

当前源码与 fixture 的最新变更以 r12 exit 0 及 `49/49 + 35/35 + 23/23 = 107/107` 测试摘要为准；不同 Luna 已对本受限范围给出 `pass`。`g3_compare_feedback_target_refs` 的值相等结果不代表 provenance、四轴或 candidate join 完成。UP1-04 才能在三 child refs、真实 G1/G2 public refs、四轴/candidate join 和执行证据齐全后接入公共入口；不修改旧 V1/V4、default registry、G1/G2、共享入口、旧 tests、queue 或 runs。
