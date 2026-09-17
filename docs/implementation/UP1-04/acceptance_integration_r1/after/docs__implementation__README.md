# implementation：实现档案与历史记录

当前架构、安排、知识规范和开放工作单统一从 [v4 核心索引](../v4_multitopology_generation/README.md) 查找。本目录保存实现与执行记录；其中旧计划不再负责当前排期。

## 1. 归档类别

| 类别 | 位置与意义 | 不能推导的结论 |
|---|---|---|
| 本次规划更新的交付记录 | [planning_update_20260914](planning_update_20260914/acceptance.md) | 文档验收不是 Genome、求解器或物理能力实现验收 |
| 历史规划原文 | [20260914_planning_baseline/INDEX.md](history/20260914_planning_baseline/INDEX.md) | 快照不是已实现功能，也不是当前安排 |
| 既有实现/合同记录 | 本目录原有 85 份 Markdown，原文及哈希保留；见下表和快照 manifest | 位置本身不意味着 accepted；须按记录中的版本、测试与证据范围判断 |
| 后续已验收工单 | `docs/implementation/<task-id>/acceptance.md` 与 evidence manifest（规划目录，随真实完成新增） | 局部 accepted 不自动传播到父目标、整装或 L4 |
| UP0-01 基线与中断审计 | [UP0-01 acceptance](UP0-01/acceptance.md)、[evidence manifest](UP0-01/evidence_manifest.json) | 仅接受当前基线/脏文件保护/W22–W24 审计/R01–R10 账本；B00 仍 pending |
| UP0-02 跨层合同与验收协议 | [UP0-02 acceptance](UP0-02/acceptance.md)、[evidence manifest](UP0-02/evidence_manifest.json)、[protocol](../v4_multitopology_generation/up0_02_protocol.json) | 仅接受 `accepted_scope=pre_result_contract_design`；`B00=false`、`B04=false`、`physical=false`，不提供 schema/provider、执行或物理信用 |
| UP1-01 G1 机制/MIMO/闭合合同 | [UP1-01 acceptance](UP1-01/acceptance.md)、[evidence manifest](UP1-01/evidence_manifest.json) | 仅接受 `g1_typed_mechanism_mimo_closure_candidate_owned_structural_contract`；`claim_ceiling=contract_only`，B00/B04/provider/mesh/engineering/physical/R01–R10 均未通过 |
| UP1-02 G2 空间与场合同 | [UP1-02 acceptance](UP1-02/acceptance.md)、[evidence manifest](UP1-02/evidence_manifest.json) | 仅接受 `axis_aligned_rational_3d_g2_structural_contract`；`claim_ceiling=contract_only`，B00/B04/provider/mesh/engineering/physical/R01–R10 均未通过 |
| UP1-03 G3 资源/控制/反馈合同 | [UP1-03 acceptance](UP1-03/acceptance.md)、[evidence manifest](UP1-03/evidence_manifest.json) | 仅接受 `g3_structural_resource_control_fault_and_standalone_feedback_contract`；`claim_ceiling=contract_only`，真实跨层 provenance/UP1-04 join 与 B00/B04/provider/工程/物理/R01–R10 均未通过 |
| AD-20 G2 ref authority 与 UP1-04 staged schedule | [AD-20 acceptance](AD-20/acceptance.md)、[evidence manifest](AD-20/evidence_manifest.json) | `accepted_limited` 仅覆盖新 G2 public-ref namespace 与 UP1-04A→UP2-00→UP1-04B→UP1-04→UP2-01 排期；实现、provider、B00/B04、mesh、工程、物理、R01–R10 均未通过 |
| UP1-INDEX 三层有限接受汇总 | [UP1-INDEX acceptance](UP1-INDEX/acceptance.md)、[evidence manifest](UP1-INDEX/evidence_manifest.json) | 仅汇总三层各自有限 structural contract；不代表 UP1 整体、UP1-04 或父目标通过 |
| UP1-04A V5 共享入口与同候选 identity wiring | [UP1-04A acceptance](UP1-04/acceptance.md)、[evidence manifest](UP1-04/evidence_manifest.json)、[独立 r12 复核](UP1-04/independent_review_r12/acceptance.md) | `accepted_limited` 仅覆盖 additive V5 shared entry 与 structural same-candidate join，claim ceiling=`contract_only`；UP2-00=`ready`，UP1-04B/完整 UP1-04、B00/B04/provider/mesh/engineering/physical/R01–R10 均未通过 |
| W24-AUDIT-CHECKER | [acceptance](W24-AUDIT-CHECKER/acceptance.md)、[evidence manifest](W24-AUDIT-CHECKER/evidence_manifest.json) | 仅接受 execution-ledger predicate 与 checker artifact 语义修复；不提供 W24 物理/工程或 R01–R10 信用 |
| W24-G2-CHILD-R2 | [acceptance](W24-G2-CHILD-R2/acceptance.md)、[evidence manifest](W24-G2-CHILD-R2/evidence_manifest.json) | 仅接受 `sealed_execution_status_snapshot`；`comparability_status=changes_requested`，不提供可比执行、物理、工程或 R01–R10 信用 |

## 2. 既有记录导航

以下是检索入口，**没有因本次整理重新接受或升级它们**。实施者需要回到当前源码/产物验证事实。

| 主题 | 历史记录 | 阅读边界 |
|---|---|---|
| 原执行计划和验收合同 | [sol_runtime_plan.md](sol_runtime_plan.md)、[runtime_acceptance.md](runtime_acceptance.md) | 旧排期及 Luna medium 如有残留，以当前核心规范为准 |
| G1 ownership 迁移 | [g1_occurrence_ownership_migration.md](g1_occurrence_ownership_migration.md) | 对应版本的迁移与测试记录，不能替代新版 Genome 验收 |
| 有限 G1 迭代切片 | [runtime_v4_algebraic_generation_slice.md](runtime_v4_algebraic_generation_slice.md) | 0D screen 的局部实现，不是通用物理搜索 |
| G2 几何编辑切片 | [runtime_v4_spatial_geometry_edit_slice.md](runtime_v4_spatial_geometry_edit_slice.md) | 父子候选绑定和失败传播，不是收敛的多拓扑物理证明 |
| 空间执行与多区域 | [spatial_execution_contract_v4.md](spatial_execution_contract_v4.md)、[spatial_multiregion_v4.md](spatial_multiregion_v4.md) | 当前有限空间模型及历史证据，不能外推为一般空间离散器 |
| 拾取工程和数值验证 | [spatial_pickup_engineering_v4.md](spatial_pickup_engineering_v4.md)、[spatial_verification_uq_v4.md](spatial_verification_uq_v4.md) | 固定工程子系统、数值诊断与 physical validation 分离 |
| 制造解恢复 | [runtime_v4_manufactured_recovery_benchmark.md](runtime_v4_manufactured_recovery_benchmark.md) | 数值/识别测试不是实际参考装置验证 |
| 入口覆盖 | [runtime_v4_entrypoint_coverage.md](runtime_v4_entrypoint_coverage.md) | 已登记测试的覆盖范围，不能用整包退出码推断未登记切片通过 |

全部原有文件与内容哈希保存在 [snapshot_manifest.json](history/20260914_planning_baseline/snapshot_manifest.json) 的 `preexisting_implementation_records`，不覆盖原始证据。当前运行状态见 runs 的真实检查点及 UP0 审计；本索引不代替它们。

## 3. 后续归档流程

1. Luna 提交实现、真实命令/环境/输入输出哈希、退出码、负控制和剩余义务。
2. 不同 Luna 独立复核，集成者执行所需回归，Sol 按冻结协议作阶段决策。
3. 通过后写 `<task-id>/acceptance.md`，精确说明 accepted scope、claim ceiling、评审人与证据路径；更新核心工作单中的状态和链接。
4. 失败、中断和诊断同样保留，但名称和状态必须明确非通过。重新执行另建证据，不覆盖旧 artifact。

无需复制巨大的 runs 目录进文档。档案引用内容寻址产物并保存可复算 manifest。当前规范继续留在核心目录；被替代的旧规范才进入 history，并保留原相对路径上下文说明。
