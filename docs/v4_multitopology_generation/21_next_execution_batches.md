# 当前执行批次：智能体自主完成技术链路

生效：2026-09-17。先读 [22 自主研发合同](22_agent_local_execution.md)，再按 [任务清单](task_manifest.json) 和 [16 工作单](16_execution_work_orders.md) 派单。旧版 M1–M5 中等待外部 trust root、责任人点名、签名齐套和仅准静态准备的规定已撤销；原文保存在本次修改档案的 before 目录，不重写旧验收结果。

## 1. 接手和责任

Sol 负责最高层安排、架构补充及项目内验收；Luna 实现、测试、集成和维护文档，不同 Luna 复核。先检查实际 HEAD、相关 dirty 文件、正在运行的任务和已完成产物，保护其他任务；重 Julia/DESC/mesh 计算继续串行。已有 M4/M5 数值工作应先按真实产物盘点，不能因旧清单没有同步而重复实现。

默认入口 `python -B tools/agent_local_execution.py` 直接给出可派任务和技术依赖；没有 CA、证明人、TSA 或 ACK 也能执行。源文件、Genome、G2 映射和环境记录由智能体生成并复核，不建立新的外部人员名单或本地 PKI 系统。

## 2. 首批：完成本地 UP1 输入与集成

1. 盘点 G1 diffusion、G2 metric/boundary、G3 source/feedback 的实际声明及组件核，按各工作单补齐和验收；源码 factory 能生成 present 只说明材料存在，仍需组件数值、非法构造和适用性测试。
2. 冻结实际 G1/G2/G3 declaration/source bytes、版本、candidate/parent/mission/scenario 和完整 child 状态。四轴取本地实际文件，G2 candidate envelope 必须显式；不要求外部签发，不强制所有 G2 映射双射。
3. 完成 T0 的完整 transport 与 bundle。将 recheck 实现为版本化本地来源/声明一致性路径，检查实际 bytes/hash/candidate/layer/receipt 绑定、反馈投影与重复/缺失/篡改反例。不能只把旧 `trusted_receipt` 判断替换成恒真；旧外部验证器继续保留原含义。
4. 用验证通过的本地记录完成 T1/T2 package/edit/round-trip 和受影响 identity 重建，再进入 aggregate、UP2-00、UP1-04B 等实际技术验收。检查 B00/B04 的冻结输入与原退出要求，不把改政策或历史工厂复放当成这些验证已通过。

当前状态同步（2026-09-18，R22 runtime receipt，工作树基于 `345bafb`）：T0 R22 为 `runtime_complete`，Julia `310/310`、negative dispatch `25/25`、`accepted=false`、`contract_only`、no T1/T2 credit；`100 snapshots` 仅为静态 25×4 推导，非独立运行时计数。R21 的 `interrupted_incomplete` 保留历史；T1 R5 仍为 static `16`、`prepared_not_executed`。Spatial R9 为 `54/54`、`screen_only`。G1/G2/G3 R22 的 nested receipt authoritative，计数 `39/39 + 13/13`，但 package manifest 为 `preflight_only`，不授 formal credits。DCCE `09cf7d1` 仅 Python static QA/oracle，`screen_only`、`accepted=false`，Julia未运行，不授 UP2-01 或 R credit。EngineeringFeedback R14 code/R15 runtime `77/77` 仍为 `screen_only`、`accepted=false`、`component_load=false`，no formal credits。T0/T1/T2、UP2-00、B00/B04、编译/mesh/provider/solver、数值/物理/工程/search 及 R01–R10 均未接受；R01–R10 为 `pending`，L4=0，parent goal=open。

UP1 的结束条件是可执行三层合同、合法/非法构造、迁移、标签擦除及最小组件数值验证。外部认证缺失不再是结束条件之一。任务未完成则保持原状态，验收有证据后再更新机器清单。

## 3. 第二批：增强实际编译与求解

| 工作 | 必须交付的行为 | 验证重点 |
|---|---|---|
| G1 编译 | 状态、参数、算子、闭合、边界与源按类型和单位 lowering | 稳态/时间残差、变系数、多场、多算子；缺闭合/单位错误被拒绝 |
| G2 离散 | geometry/chart/metric、region/interface/exterior 生成实际空间和离散系统 | 真正改变几何与系数后重新组装；残差、边界、守恒与细化误差 |
| 拓扑变化 | 实际 old/new 空间、overlap/transfer 和外部闭合 | 质量/能量等所需守恒，约束保持，映射损失和不可表示情况 |
| 耦合求解 | 从 dependency/residual graph 组装稀疏系统、Jacobian 和约束 | 多种合法组合、收敛/失败分类、耦合守恒；避免整棵 AST 特判 |

先复用已实现切片，补未满足的原技术要求。解析解和 manufactured 数值验证是正常研发工作，不需要外部批准或单独的行政特许；其证据范围仍是所测模型。重用成熟稀疏、非线性、ODE/DAE 和离散算法，核心自研放在物理编译、组装和耦合。

## 4. 后续批次保持完整

UP3 验证多种合法模块自动组合，包含留出组合、守恒和基降维的误差/残差/稳定性；UP4 完成源与硬件逆实现、供能/热/材料/结构/控制反馈及参考逆恢复；UP5 接入条件 e-graph 和 G1/G2/G3 结构编辑，以实际物理反馈驱动搜索；UP6 验收完整科学、工程、净输出、VVUQ、原创性与复放要求。

所需参考数据优先从现有、公开或可由智能体计算的材料取得。模型输入假设必须明示；确实无法获得的实验事实不能用模拟冒充。不存在外部签字等待，不代表任意物理问题必能求解，实际能力或数据缺口照实标注并推进其他可做任务。

## 5. 派单、依赖和交付

每张派单写清：现有 task-id、要补的行为、真实输入及版本、确切文件归属、技术步骤、直接运行命令、独立数值依据和容差、退出条件、复核者。不要求执行者通读所有 AD。需要变更技术依赖时同步 16 与 task_manifest，验证无环；39 节点不冻结，未完成任务不得直接改 accepted。

实现记录写入现有任务目录的新轮次，至少包含改了什么、实际命令与退出码、关键产物/输入哈希、数值或软件结论范围、剩余缺口和智能体复核。避免为一次小修改增加完整的签发/接收/吊销流程。本地来源检查、语义检查、数值验证、物理与工程结论分别报告；进程 exit 0 只说明该命令成功结束。

Sol 主线提示词以 [15](15_sol_system_prompt.md) 为准；旧中期审计中的 next_sol_goal_prompt 是历史版本。
