# 下一轮执行批次与 Luna 档案使用规则

## 1. 接手只读顺序

先读 [README](README.md) → [20 中期审计](20_midterm_audit_20260916.md) → [00 合同](00_normative_contracts_and_state_model.md) → 自己的 [16 工作单](16_execution_work_orders.md) 与 [task_manifest.json](task_manifest.json) → [档案入口](../implementation/README.md) 中该任务的有限验收。只有需要解释某字段时才沿 AD 追溯；不按 AD 编号顺序重新执行全部历史任务。

任务表是调度事实，验收书是接受范围，当前源码/输入/日志是执行事实。这三者必须同时满足。`planned + local accepted_limited` 表示有可复用的有限前置软件，但主门未解锁；`present + trusted=false` 表示来源工厂有对象，不是可信来源。

本页批次号 `M1–M5` 只是下一轮分派标签，不新增 machine node，不替代既有39节点，也不改变 UP0–UP6、B00–B13 或 R01–R10。Sol(high) 只负责契约、依赖、决策和裁决；Luna(high) 承担实现、测试、集成、文档和独立复核。作者与复核者不同，重计算共用一个串行 lane。

## 2. M1：当前执行闭包与 AD55 归档

**对应**：UP0-01 刷新、UP1 来源前置链。**读取**：[AD55 决策归档](../implementation/MIDTERM-AUDIT-20260916/AD55_decision_archive.md)、AD54/56 root acceptance、AD55 R2/独立复核及本轮 before inventory。

Luna 在下次执行前记录 full HEAD、index 状态、目标 raw SHA-256、canonical HEAD bytes/hash/blob OID、filtered working OID、所有运行时导入源码/探针/测试/解释器 hash。三份 AD56 factory 未提交不能被省略。禁止把工作树执行器 hash 填入 HEAD blob 字段，禁止由当前 HEAD 猜测旧进程代码。

**交付**：一份 exact execution-input manifest、命令与环境清单、明确的 claim ceiling。若采取新的受控源码发布，另明确文件清单和授权范围；没有新发布则完整保留 dirty 输入身份，不能声称纯 HEAD 重现。已有 AD55 裁决归档不再重复创建；若发现事实差异，追加修正记录并引用旧件。

**退出**：不同 Luna 从磁盘重算 hash、检查 provenance 两层含义；不以 diff clean 代替输入闭包检查。

## 3. M2：fresh S3 与外部输入阻塞交接

**前提**：M1 和 AD55 source-stage 接受范围已读；明确 AD48 G3 与 AD49 G1/G2 的 S3 对象集、产品 ID 及版本。不要把这些 S3 与运行器 S0–S10、B00 F0–F5 混为一谈。

**步骤**：

1. 冻结该次使用的 source locator、factory identity/declaration/receipt 和独立 source review；保留旧 S3 typed absence 作为历史，不能复用其 candidate/HEAD 字段。
2. 对 G1/G2/G3 每个适用 scope 检查 source closure 与独立信任链。closure present 与 trust present 分别记录，不把两类缺口合并成一个模糊错误。
3. 缺信任材料时产出 typed absence/terminal_deferred/no_publish；哈希冲突、重放或来源错绑属于 fail_closed，不能降格成可忽略缺项。
4. 不同 Luna 复算并审查；Sol 只接受诚实的缺项记录及其软件可复现性。没有输入变化时，不再循环执行相同 S3 或新增同义 AD。

**外部输入工单必须逐项列**：提供方/责任人（尚未确定就写未指定）、独立性依据、被证明对象和 scope、受信根/公钥指纹与授权链、证书和签名、验证器及版本、有效期/吊销/可信时间/防重放策略、source内容/版本绑定、G2 mapping、四轴材料、验收命令、失败分类、可联系或获取渠道。未知值不可补造。本项目维护者确认一个开发信任根是否足够，是信任模型决策；不能以普通用户“继续”自动充作 attestation，更不能授予物理信用。

**结束分支**：A＝真实 trust/closure 满足，进入 M3；B＝缺外部输入，登记明确 blocked_external 子条件、负责人和唤醒条件，正式身份链保持关闭。此时 M4 只做当前允许的静态准备；若要测试专用数值执行，按 M4 范围决策，不能悄悄绕门。

## 4. M3：来源条件成立后的最短集成线

按既有 AD/工作单，完成尚缺的 W1/W2、G2 mapping 和四轴后，再作 `T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04`。这里的顺序是概览；每个节点仍按 task_manifest 的完整依赖检查，不覆盖其中并行关系。

每个接线任务交付一份完整输入、输出、缺口与变更的 receipt。G1/G2/G3 任何变化都重建 candidate/subject/solver-input identity，并使受影响旧 evidence 失效。不得把临时 QualifiedRef、fixture seed、legacy 六字段相等、源码 present 或独立软件评审当成来源 authority。

UP1-04B 必须在最终 schema 后、首次执行前冻结 B00 F0–F5 和 B04 N01–N10 各五个正式变体；独立磁盘 checker、50 条 fresh candidate-bound receipts、两进程重放、标签擦除/置换均要具备。局部投影 40/50、AD55 两次18件一致以及每个模块断言数均不能替代这些条件。UP1 的最小组件数值要求另按原退出门验收。

## 5. M4：把重心转回实际数值执行能力

**本页不是越过 M2/M3 的执行授权。** 现有 UP2-01 等正式任务的依赖保持不变；环境 gate 和真实候选绑定也保持不变。并行静态准备现在可做。若被外部信任阻塞而要继续测试专用组件执行，Sol 必须先写有限范围决策，由不同 Luna 核验：只用显式 manufactured/analytic 输入、不创建正式候选身份、不复用实验/正式 authority、不解锁主线节点、不授予物理信用，及将来回接正式链所需的全部新鲜验证。该决策不能删去原有正式门。

外部阻塞分支中，下一轮必须明确裁决是否建立上述测试专用开发范围：允许则给出有限实施单并产生实际数值测试证据；不允许则说明具体冲突条款、待提供输入及责任方。不能以反复写“以后讨论”替代这项架构决策。测试通过只能关闭对应组件开发项，正式UP阶段和父目标仍须原有完整链验收。

准备或获准后的实现按以下切片交付，**任何一个小切片通过都不是 UP2 整体通过**：

| 切片 | 必需实现和输入 | 可审查输出/测试 | 禁止替代 |
|---|---|---|---|
| 声明到方程 | 带单位/作用域的 state、parameter、operator、closure、边界及 source ownership；每算子组合 lowering | 稳态及时间残差；变系数、各向异性、多场组合；缺闭合/单位/重复守恒 owner 负例 | 整棵 AST 识别、只验证元数据、硬编码 fixture 方程 |
| 方程到离散 | G2 geometry/chart/metric、region-interface-exterior、空间及基函数；弱式或数值通量 | 真实矩阵/向量/约束、稀疏结构；制造解误差、残差、积分守恒、网格与时间细化 | 声明匹配既有 _smr_declaration 就称一般拓扑 |
| 多区域及拓扑变化 | 面定向、成对 flux、外部域 closure、old/new overlap 或可验证 transfer | 守恒传递、positivity/约束适用性、缺外部闭合负例、场投影误差 | 只改拓扑标签或丢弃新增/消失区域的守恒量 |
| 耦合求解 | 完整 dependency/residual graph、Jacobian/导数适用性、DAE 约束、真实反馈边 | 实际解、收敛/失败分类、耦合守恒；断反馈边应改变对应响应 | 以 solver exit 或输入 hash 证明数值正确 |

每份工单必须在运行前给出具体目标文件、公式和符号约定、实际输入清单、独立 oracle、预先阈值、命令、停止条件、正负控和适用域。复用成熟线性/非线性/ODE/DAE/离散库，不重新开发所有数值基础；后端按 capability 适配，不能把换一个等离子体框架等同于解决通用组合。

之后才按原路线交付 UP3 留出组合和基降维误差认证，UP4 源/硬件逆实现与主物理反馈，UP5 等价改写与扩大搜索，UP6 全部终局义务。降维的空间基/截断、残差、稳定性和误差认证是数值工作，不会替代来源、闭合、几何或工程条件。

## 6. M5：分派和交付模板

每次派给 Luna 的消息应包含以下完整信息，不要求其阅读所有历史 AD 才能猜出任务：

```text
existing_task_id / batch_id / parent_exit_gate:
objective: 一个可验证的能力或确切缺项
current_state: machine_status / accepted_slice_scope / phase_unmet_gates
frozen_inputs: exact paths + versions + raw/canonical hashes + environment
write_scope: product files (exact paths); dedicated append-only evidence directory
prerequisites: 哪些已满足，哪些未满足；未满足时允许做什么
implementation: 操作步骤、接口、公式、适用域和负例
validation: direct commands, independent oracle, frozen tolerance, replay requirements
stop_rule: 超预算、输入变化、外部缺失、程序/数值/物理失败如何分类
handoff: artifact list, actual model/effort, raw/PID/UTC/exit/hash, cleanup, remaining gaps
reviewer: different Luna(high); Sol adjudicates accepted scope
```

禁止每个小步都新建一套重复总规则。若需要新 AD，应指出旧合同中**具体哪个字段或依赖不可满足**、为何现有机制不能表达，并给最小修改与独立反例验证。任务完成应增加可执行能力、关闭原有具体验收项，或交出外部阻塞输入合同；单纯状态同步只能算文档维护。

完成证据仍保存到 `docs/implementation/<existing-task-id>/` 的新命名子目录。未完成结果也可以归档，但必须标 `partial/review_pending/blocked/failed`，不得挪进 accepted 类别。旧文件不回写、不清洗失败历史，不广泛删除不明归属文件。

## 7. 可直接交给 Sol 的短提示词

[next_sol_goal_prompt.txt](../implementation/MIDTERM-AUDIT-20260916/next_sol_goal_prompt.txt) 是本轮 goal 的提示正文，计数统一为UTF-8解码、CRLF转LF、去首尾空白，保留内部一个换行，共492字符（不计内部换行为491）；单独校验小于500字符；它引用本页的详细步骤，不需要将所有技术约束塞入提示词。提示词不是已经创建或启动的 Codex goal。
