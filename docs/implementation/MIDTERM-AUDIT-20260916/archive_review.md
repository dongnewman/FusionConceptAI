# 实现档案审计：Luna 可用性与主审修订入口（2026-09-16）

## 结论

本审计只读扫描了当前 `FusionConceptAI` 的规划入口、任务表和 `docs/implementation` 一级档案目录。任务表的事实是 **39 个节点 = 6 个 `accepted` + 33 个 `planned`**；这只是调度状态，不是物理进度。6 个 accepted 为 `UP0-01`、`UP0-02`、`UP1-01`、`UP1-02`、`UP1-03`、`UP1-04A`。证据见 [`task_manifest.json`](../../v4_multitopology_generation/task_manifest.json) 的 `tasks`，其阅读/状态边界也由 [`README.md`（第13–27行）](../../v4_multitopology_generation/README.md) 和 [`16_execution_work_orders.md`（第20–61行）](../../v4_multitopology_generation/16_execution_work_orders.md) 固定。

`accepted_limited` 档案与 machine node 的 `planned` 可以同时成立。AD-31、AD-32、AD-33、AD-34 及其 G3/authority-recheck 相关档案记录的是局部架构或软件前置范围；核心入口明确保留对应 node 为 `planned`、`accepted=false`、`review_pending`，不能由局部测试、文档或 root/status-sync 自动升级（[`implementation/README.md`（第64–74行）](../README.md)，[`14_agent_orchestration.md`（第35–52行）](../../v4_multitopology_generation/14_agent_orchestration.md)）。

当前 Git `HEAD` 是 `b2c04d8339774635aaecd73651efcdb101e01b5d`（Genome V5 source-closure 发布）；`task_manifest.json.base_head` 仍是 `4b69f55`。因此 Luna 的输入必须同时记录“旧规划基线”和“当前 HEAD/实际 dirty 执行闭包”，不能把旧 HEAD 的结论移植到新 HEAD。主审已有中期冻结声明是当前 HEAD 加 dirty 工作树、5968 个文件 SHA-256（[`20_midterm_audit_20260916.md`（第5–9行）](../../v4_multitopology_generation/20_midterm_audit_20260916.md)）；本次不覆盖该冻结。本地扫描在写入本审计前观察到 90 个一级档案目录、5435 个实现档案文件；这是工作树计数，不能替换主审的 5968 文件基线。

**初审时点（pre-edit，2026-09-16，主审决策归档生成前）**，AD-55 的实际档案已经有 fresh F0、S2 run1/run2 和独立 R1 `pass_limited`：当前 HEAD、三次 Julia 运行 exit 0、18 份 canonical identity/declaration/receipt 两次字节一致、negative controls 通过，且 claim ceiling 仍是 source-stage software（[`AD-55 f0_s2 manifest`（第1–18行）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/manifest.json)、[`AD-55 independent R1`（第1–15行）](../AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/independent_review_r1/report.md)）。当时 AD-55 目录没有 `acceptance.*` 或 `decision.*` 文件，manifest 仍为 `completed_review_pending`/`accepted=false`，故初审结论是 Sol 裁决尚未形成可检索的正式归档。**复核时点**已见主审新增 [`AD55_decision_archive.md`](AD55_decision_archive.md)，其中把裁决来源限定为用户转述并保持 `accepted_limited`/source-stage ceiling；这不改变初审观察，也不将 R1 `pass_limited`升级为 root acceptance，更不解锁 S3 或 B00/B04。

AD-56 的架构正文仍保留“AD55 F0/S2 需修复后 fresh rerun”的旧句子（[`18_sources_and_architecture_decisions.md`（第460–468行）](../../v4_multitopology_generation/18_sources_and_architecture_decisions.md)），与 AD-55 的 fresh R2/R1 结果冲突。该句应作为历史前置状态标注为 superseded，并由主审在 AD-55 决策归档中引用当前 R2；不要改写旧失败报告或旧 raw receipt。

AD48/AD49 的 S3 仍是外部信任输入阻塞：四 scope 或 readiness 89–92 产品可以 `accepted_limited` 为 typed absence，但 `external trust root`、attestor、key/certificate、signature verifier、revocation、freshness/trusted time 缺失时必须 `terminal_deferred` + `no_publish`，不能生成 trusted identity、candidate identity 或物理 credit（[`AD48 S3 root`（第3–14行）](../AD-48/S3-TRUSTED-SOURCE-IDENTITY/root_acceptance_r1/acceptance.md)，[`AD48 gate`（第27–41行）](../AD-48/S3-TRUSTED-SOURCE-IDENTITY/root_acceptance_r1/acceptance.md)，[`AD49 S3 root`（第1–11行）](../AD-49/S3-TRUSTED-SOURCE-IDENTITY/root_acceptance_r1/acceptance.md)）。AD-50 只同步状态，未解锁 G2 mapping/W3B/AD46/T0（[`18_sources_and_architecture_decisions.md`（第449–458行）](../../v4_multitopology_generation/18_sources_and_architecture_decisions.md)）。

## 需要主审修订的入口

1. **补 AD-55 决策归档并保持范围窄。** 新归档应记录：用户转述的 Sol 决策来源（若没有独立 Sol 签名就明确写“用户转述”）、AD-55 F0/S2 R2 manifest、independent R1、当前 HEAD、`task_manifest` hash、18 件 output 集合、`source-stage software only` ceiling、S3 pending，以及 `accepted=false`/待 root 决策的事实。它不能假造新的 Julia 运行、trusted attestation 或 machine node。旧 `f0_execution/**`、`failure_history/**`、R2 与 R1 只读保留。
2. **修正旧 HEAD 的可见性。** 在主索引和 AD-56 后附一条 append-only 状态修订：`4b69f55` 是规划基线，`b2c04d8` 是 AD-55 运行 HEAD；若执行器来自 AD-56 dirty 工作树，要同时绑定执行器源码、测试、探针和环境 hash。AD-55 报告的“current HEAD”只能表示 canonical source objects，不能暗示 clean checkout 已包含所有 AD-56 工作树修复。
3. **分离三条状态轴。** 入口应同时显示 `task_manifest.status`、archive 的 `accepted_scope/claim_ceiling`、以及 scientific/authority state。局部 `accepted_limited` 不更新 39-node DAG；`review_pending`、`blocked_external`、`terminal_deferred`、`fail_closed` 不能被折叠成“完成/失败”二值。
4. **修正计划校验入口的缺链。** 本次只读执行 `python validate_plan.py`，PID `105352`，UTC `2026-09-16T01:55:28.6427568Z`–`01:55:29.0932430Z`，exit `1`。39 tasks 和 DAG acyclic 仍通过；失败是 `20_midterm_audit_20260916.md`、`21_next_execution_batches.md` 和 README 引用了尚不存在的 `MIDTERM-AUDIT-20260916/README.md`、`up_progress_review.md`、`AD55_decision_archive.md`、`source_evidence_review.md`、`validation_receipt.json`、`independent_review.md`、`archive_catalog.json`。本审计不能越权创建这些文件；主审应把入口引用与实际交付集合一次性对齐，或在明确工单下建立它们。
5. **保持 S3 外部 trustroot 阻塞。** 有效外部凭据、信任根绑定、验证器、撤销/时效/可信时间和防重放材料到达前，Luna 只能重跑或复核 typed absence；材料到达后才允许按现有 S1 → S2/F0 条件 → fresh S2 → S3 → fresh W1 → W2 顺序重建受影响产品。任何 source/path/HEAD/factory/attestation 变化都使旧 downstream identity/receipt 失效，旧证据另存。

## UP0–UP6 档案导航

| 阶段 | 当前任务表状态 | Luna 先读的主要档案 | 可计入范围与下一门 |
|---|---|---|---|
| UP0 | 2 accepted | [`UP0-01`](../UP0-01/acceptance.md)、[`UP0-02`](../UP0-02/acceptance.md)、[`up0_02_protocol.json`](../../v4_multitopology_generation/up0_02_protocol.json)、[`W24-AUDIT-CHECKER`](../W24-AUDIT-CHECKER/acceptance.md) | 基线、脏文件、旧中断、合同/协议；每次运行仍刷新 HEAD/dirty/input；不授 B00 物理信用 |
| UP1 | 4 accepted，11 planned | [`UP1-01`](../UP1-01/acceptance.md)、[`UP1-02`](../UP1-02/acceptance.md)、[`UP1-03`](../UP1-03/acceptance.md)、[`UP1-04`](../UP1-04/acceptance.md)、[`UP1-INDEX`](../UP1-INDEX/acceptance.md)、AD-30–AD-48 有限前置 | 结构合同、V5 接线和 typed-absence 软件；T0→recheck→T1→T2、三层真实 join、B00/B04 仍未通过 |
| UP2 | 9 planned | [`UP2-00`](../UP2-00/acceptance.md)、N03/N04/N07/N08/N09/N10、[`UP2-00E0`](../UP2-00E0-BOUND-INPUT/acceptance.md)、[`UP2-00G-I0`](../UP2-00G-I0-MODULE-SEAM/acceptance.md)、[`UP2-01-G1`](../UP2-01-G1-DIFFUSION-V1/README.md)、[`UP2-01-G2`](../UP2-01-G2-METRIC-BOUNDARY-V1/acceptance.md)、[`UP2-01-G3`](../UP2-01-G3-SOURCE-FEEDBACK-V1/implementation.md) | contract-only projection、局部 source/software；通用方程编译、离散、耦合、provider、mesh、solver 仍是后续实际执行 |
| UP3 | 3 planned | [`UP3-EARLY-PREPARATION`](../UP3-EARLY-PREPARATION/acceptance.md) | 组合/holdout/negative/budget/oracle 模板；不得冻结候选 hash 或运行物理 |
| UP4 | 4 planned | [`UP4-EARLY-PREPARATION`](../UP4-EARLY-PREPARATION/acceptance.md) | 数据、坐标/单位、source/coil/actuator 准备；适配器与最终产品分离，不能当作 realization 闭环 |
| UP5 | 3 planned | [`UP5-EARLY-PREPARATION`](../UP5-EARLY-PREPARATION/acceptance.md)、旧 AST/hypergraph/e-graph 记录 | 规则/typed edits/预算准备；不得转移 evidence、剪枝候选或声称开放发现闭环 |
| UP6 | 3 planned | [`UP6-EARLY-PREPARATION`](../UP6-EARLY-PREPARATION/acceptance.md)、[`13_acceptance_benchmarks_and_evidence.md`](../../v4_multitopology_generation/13_acceptance_benchmarks_and_evidence.md)、[`09_evidence_authority_campaign_and_v4_roadmap.md`](../../v4_multitopology_generation/09_evidence_authority_campaign_and_v4_roadmap.md) | provider/VVUQ/工程/原创性/复放模板；R01–R10 与 L4 仍全部开放，L4=0 |

## 证据类别判别

| 类别 | 能证明什么 | 不能替代什么 |
|---|---|---|
| `architecture` | Sol 的边界、依赖、版本、失效和 authority 决定；主要见 AD-17–AD-56 与 18 | 代码实现、运行、source authority 或物理 |
| `protocol` | 验收门、receipt 字段、复放/清理/独立复核流程；见 14、16、AD-35/36 | 任何实际通过结果 |
| `structural` | typed schema、字段/identity wiring、fail-closed/typed-absence 行为；见 UP1、UP2 局部 slices | source-backed authority、数值收敛、物理真实性 |
| `source software` | 当前源码 locator/factory 的输入闭合、construction receipt、deterministic replay；AD-55 是此类 | trusted attestation、candidate/final identity、provider/mesh/physics |
| `numerical` | 离散/残差/收敛/误差/UQ 在声明模型与适用域内的计算证据 | source trust、工程可制造性或实验验证 |
| `physics` | 适用 provider、模型、工程/实验数据及整装净输出的独立物理证据 | 文档、测试数量、runner exit、单纯 software identity |

因此，AD-55 的 `present` 是 source-stage factory software 结果；AD48/49 S3 的 `typed_absent` 是 trust/authority 缺口；UP2 旧数值运行的 exit 或残差是 numerical 层事实。三者都不能被写成 physics 或 L4。

## 一级档案扫描

扫描口径是 `docs/implementation` 的直接子目录（不递归把子目录当一级目录）；结果写入同目录的 [`archive_review.json`](archive_review.json)。共 90 个一级目录：`AD-*` 38、`CORE-*` 5、`UP*` 41、`W24-*` 2、其他 4（`history`、`MIDTERM-AUDIT-20260916`、`planning_update_20260914`、`PYTHON-ENV-REINSTALL-AUDIT`）。各目录的递归文件数和前缀计数属于检索信息，不是验收计数。

主审修订时应采用“主类别 + 状态标签”而非以目录名推断信用：AD/CORE 多为 architecture/protocol/status-sync；UP1/UP2 同时含 structural 与 source software 局部切片；UP3–UP6 是 preparation；旧 implementation Markdown 可能带 numerical/physics 历史结果，但必须按其自身 claim ceiling 读取。`accepted_limited` 数量、文件数和 AD 编号都不改变任务表。

## Luna 接手模板

```text
task_id: <task_manifest id or explicitly bounded archive review id>
actual_model / reasoning: gpt-5.6-luna / high
read_first: AGENTS.md; v4 README; 00; 14; 16; task_manifest.json; assigned technical chapter;
            implementation/README.md; relevant acceptance + independent review + manifest
baseline: task_manifest.base_head=<old>; current HEAD=<new>; dirty_fingerprint=<fresh>
scope_axis: task_status=<planned|review_pending|accepted>; accepted_scope=<exact>; claim_ceiling=<exact>
evidence_class: architecture|protocol|structural|source_software|numerical|physics
if accepted_limited: use only its exact local scope; leave machine node and parent gate unchanged
if completed_review_pending or review_pending: do not call accepted; request independent review/decision
if typed_absent + terminal_deferred: record missing input and stop that branch; do not synthesize identity
if fail_closed: preserve raw failure and hashes; do not retry with changed thresholds or relabelled input
if source/path/HEAD/factory/attestation changes: invalidate downstream identities/receipts; fresh rebuild only
if external trust root missing: S3 remains no_publish; hand off required trust materials and verifier inputs
if numerical failure: classify numerical/unknown/deferred; do not infer universal impossibility or physics failure
if physics/provider evidence absent: keep provider/mesh/solver/engineering/physics/R01-R10/L4 closed
delivery: changed_paths; protected hashes; command/cwd/PID-or-in_process; UTC; stdout/stderr/combined hashes;
          input/output/artifact hashes; positive/negative controls; exact remaining obligations; cleanup inventory;
          different-Luna review request; next dependency or concrete blocker
code_tests: not_applicable  # for this archive audit; use direct static/link/JSON validation only
```

归档规则仍以 AD-35/36 为准：实现任务要有专属正负测试；纯审计/架构/文档任务写 `code_tests=not_applicable` 并保存适用静态验证；sidecar 只能放 task-owned evidence 目录，不得改写旧 artifact、任务表或代码（[`16_execution_work_orders.md`（第949–955行）](../../v4_multitopology_generation/16_execution_work_orders.md)）。父目标只有 R01–R10 全部满足且至少一个新候选通过最终门时才可关闭（[`14_agent_orchestration.md`（第63–67行）](../../v4_multitopology_generation/14_agent_orchestration.md)）。
