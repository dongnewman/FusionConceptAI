# 实现档案入口：按阶段和验收范围查阅

更新：2026-09-16中期审计。当前规划在 [v4核心目录](../v4_multitopology_generation/README.md)；本目录保存实施、评审、失败、未完成记录和历史快照。**存入implementation不等于实现已接受。** R01–R10全部未关闭，L4=0。

## 接手入口

先读 [中期审计](../v4_multitopology_generation/20_midterm_audit_20260916.md) 和 [下一轮执行批次](../v4_multitopology_generation/21_next_execution_batches.md)，再读自己任务的 [工作单](../v4_multitopology_generation/16_execution_work_orders.md) 与 [任务表](../v4_multitopology_generation/task_manifest.json)。39节点中6 accepted、33 planned；按任务验收书的具体scope计入，不按文件夹或AD数量推断进度。

[archive_catalog.json](MIDTERM-AUDIT-20260916/archive_catalog.json) 提供全部一级目录和39任务的检索映射；分类仅用于定位，没有新的authority。旧逐轮入口全文保存在 [implementation_README.before.txt](MIDTERM-AUDIT-20260916/entry_snapshots/implementation_README.before.txt)，不再作为“当前状态”执行。

## 阶段导航

| 阶段 | 优先查看 | 接受范围与下一道门 |
|---|---|---|
| UP0 | [UP0-01](UP0-01/acceptance.md)、[UP0-02](UP0-02/acceptance.md)、[本轮快照](MIDTERM-AUDIT-20260916/before_inventory.json) | 历史基线/合同已建立；每次执行仍需刷新 |
| UP1 | [R2根裁决](UP1-EXTERNAL-BLOCKER-CLOSURE-R2/23-root-acceptance/decision.md)、[三层合同索引](UP1-INDEX/acceptance.md)、[UP1-04A有限接受](UP1-04/acceptance.md)、[AD30](AD-30/acceptance_r2/acceptance.md)、[AD34](AD-34/acceptance.md) | 外部证据验证/离线intake/聚合软件能力为 `accepted_limited_with_test_scope_deferred`；0 usable inputs、26 typed_absent，UP1 blockers未解除；T0及后续、B00/B04、R01-R10、39DAG、L4及parent均未关闭 |
| UP2 | [UP2-00](UP2-00/)、[UP2-01准备](UP2-01-PREPARATION/)、[N06 H0A](UP2-N06-H0A-DIMENSIONED-LAW/)、[AD38](AD-38/acceptance/acceptance.md) | 投影、缺口检查、部分软件核；不表示通用方程/空间/耦合已实现 |
| UP3 | [组合准备](UP3-EARLY-PREPARATION/acceptance.md) | 模板/协议有限接受；实际组合矩阵、留出和降维验证待执行 |
| UP4 | [逆实现准备](UP4-EARLY-PREPARATION/acceptance.md) | 输入/参考合同；通用硬件逆设计和工程闭环未完成 |
| UP5 | [搜索准备](UP5-EARLY-PREPARATION/acceptance.md) | 改写/编辑/预算准备；没有完整跨三层真实反馈搜索验收 |
| UP6 | [终局准备](UP6-EARLY-PREPARATION/acceptance.md) | 终局证据模板；物理、工程、净输出、原创性和L4未通过 |

## 当前来源工厂链

| 记录 | 读取方法 |
|---|---|
| [AD54源码发布](AD-54/V5-SOURCE-PUBLICATION-COMMIT/root_acceptance_r1/acceptance.md) | 本地b2c04d8的21文件发布工程证据，不能解释为可信来源 |
| [AD56可移植修复](AD-56/GIT-FILTER-PORTABLE-SOURCE-LOCATORS/root_acceptance_r1/acceptance.md) | canonical Git blob与Windows raw checkout分层，三份factory存在未提交修复 |
| [AD55执行](AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/report.md)、[独立复核](AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/independent_review_r1/report.md)、[裁决归档](MIDTERM-AUDIT-20260916/AD55_decision_archive.md) | source-stage六scope及18份正式输出复放；用户转述Sol有限接受，旧review_pending保留为历史 |
| [旧AD49 S3](AD-49/S3-TRUSTED-SOURCE-IDENTITY/root_acceptance_r1/acceptance.md) | 旧HEAD上的typed absence，解释外部trust/source缺口；不能代替fresh S3 |
| [本轮来源审查](MIDTERM-AUDIT-20260916/source_evidence_review.md) | 当前HEAD来源对象＋AD56工作树执行器的精确边界与哈希核查 |

source工厂F0/S2/S3、B00 F0–F5、旧运行器S0–S10是不同命名空间。source present、trusted source、candidate identity、provider execution和physical validity分别验收。缺外部trust root不能用本地hash/测试/评审顶替，也不能借此宣称主要数值能力已经完成。

## Luna如何新增档案

1. 复用既有task-id目录，在新子目录写实现或评审记录；未完成结果标partial/review_pending/blocked/failed。不能因已归档自动标accepted。
2. 每个关闭记录列：task-id、当前HEAD及dirty输入、实际model/effort、input/output hashes、具体实现、专属测试与raw/PID/UTC/exit、负例、接受范围、未满足退出门、不同复核者和Sol裁决来源。
3. docs/audit任务执行适用的JSON/链接/DAG/diff/保护校验，code_tests可明确not_applicable；代码任务必须执行其有意义的正负测试。重型Julia/DESC/mesh按单lane串行。
4. 独立性意味着审查者实际复算/反证，不是复制实现者的checker输出。测试或编译通过不能代替数值收敛、物理验证或可制造性。
5. 不覆盖旧日志/原件、不回写历史pending为accepted、不删不明归属文件、不整体stage runs。不再复制整套总规范；用链接加本任务差异说明。
6. 状态同步只算文档维护；只有真实能力、原退出项完成或可交接的外部缺项才算相应工作成果。完整模板见核心21章。

## 历史材料与本轮交付

[本轮审计档案](MIDTERM-AUDIT-20260916/README.md) 包含保护快照、独立审查、目录、验证和492字符Sol提示词。此前 [planning_update_20260914](planning_update_20260914/acceptance.md) 和其他历史目录均原样保留。优先按对象、时间、hash、scope定位最新适用证据；旧材料只解释历史，不覆盖当前要求。
