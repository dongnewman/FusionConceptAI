# v4 多拓扑聚变装置：当前路线

更新：2026-10-19。实验 Goal **已暂停**。本轮只整理实现、精简文档、按用户授权清理历史产物并提交代码；本页不触发计算恢复。

## 已实现与当前状态

完成的软件入口、调用、单位、已验证范围集中在[实现记录](../implementation/IMPLEMENTED-STATE-20261019/implementation.md)；既有运行的结论和失败集中在[运行摘要](../implementation/IMPLEMENTED-STATE-20261019/run_history.md)。原始大产物已按该页说明精简，摘要不能代替原始字节复放。

| 范围 | 可复用进展 | 剩余门 |
|---|---|---|
| UP1 / UP2-00 | 用户接受的来源/T0/T1/Gridap、B00/B04及合同软件范围 | 不授整机物理信用；旧独立 T2 未接受且已取消 |
| UP2-01 | DCCE 静态、离散时间、source-bound BE MMS 与耦合双场 focused 测试通过 | 生产统一入口的未知合法组合/预留组合及整体验收 |
| UP2-02 / 自研 Q1 | Q1_4 有限 FD；Q1_8 当前数值状态按用户决定接受 | 完整2080列FD、完整fresh replay、通用拓扑/强耦合 |
| UP2-03 | 候选绑定的保守跨网格传递软件 slice | 实际下游消费者、外域与完整守恒/复放 |
| UP2-04 / 五项闭合 | 真实 R/J、KKT 与局部压力/电流/外场构件 | C771 尚无接受步；pressure/current、B_out、K_outer、return path 全部 HOLD |
| UP2-05 | D-T provider 与限定消费者接线 | 全部适用物理/backend能力登记及真实执行 |
| UP3 | FV有限A/B、因果负例和Q1定点screen | full17未通过；合法组合/盲留出/完整同链复放未验收 |
| UP4 | 来源诊断、固定电流forward及硬件接口 | PF符号/匝数、Thomson校准/误差、真实三Genome反演和同链验证 |
| UP5 / UP6 / R01–R10 | 接口和部分软件构件 | 同一新候选的物理、工程、全周期正净输出、VVUQ、原创性与独立复放尚未同时通过；终局候选0 |

## 阅读顺序

1. [00 共同合同](00_normative_contracts_and_state_model.md)：科学范围、失败分类和 R01–R10。
2. [16 剩余工作单](16_execution_work_orders.md)、[机器清单](task_manifest.json)：接口、依赖与完整验收条款。
3. [21 恢复后的执行顺序](21_next_execution_batches.md)：当前缺口及下一判别动作。
4. [11 编译/离散](11_physics_compilation_and_discretization.md)、[12 组合/反演](12_composition_and_inverse_realization.md)、[13 验收](13_acceptance_benchmarks_and_evidence.md)：对应技术要求。
5. [14 职责](14_agent_orchestration.md)、[17 子智能体交付](17_luna_worker_prompt.md)、[22 本地执行](22_agent_local_execution.md)、[25 运行条件](25_astra_execution_and_recovery.md)。

[01–09路线合同](09_evidence_authority_campaign_and_v4_roadmap.md)、[10 Genome升级](10_genome_upgrade_execution.md)、[18 决策来源](18_sources_and_architecture_decisions.md)、[19 B00/B04协议](19_up0_02_contract_freeze.md)和 G1/G2/G3、typed AST 规范继续适用。已完成步骤移至实现目录，科学要求不随文档整理删除。旧 dated revision/observation 文件仅属历史，不能恢复旧 T2 或覆盖本页暂停状态。

主线程独占共享入口和正式运行；最多九个 GPT-6 Luna/high 子智能体分离实现、测试与复核，重计算串行、4 GiB。配置字段记录请求，不宣称宿主未暴露的实际设置。用户恢复实验后，仍须有具体失败原因、对应修改和受影响短检查才进入长跑。
