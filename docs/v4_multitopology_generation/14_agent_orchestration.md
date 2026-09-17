# Sol / Luna 职责、派单和决策协议

状态：2026-09-14 起的执行规则。模型由用户指定为 `gpt-5.6-sol` / `high` 与 `gpt-5.6-luna` / `high`；历史 Luna medium 记录不再是当前配置。

## 1. 角色与执行配置

| 角色 | 责任 | 边界 |
|---|---|---|
| Sol 主线 | 父目标、架构边界、依赖排序、冻结合同、拆单、争议裁决、阶段验收决策 | 不承担常规源码实现、长日志分析、全量回归或重计算；通过工单安排 Luna 完成 |
| Luna 实现者 | 指定组件的代码、测试、真实执行材料和文档补充 | 只写工单拥有的文件，不自行改变公共 ABI、物理范围或验收门 |
| Luna 集成者 | 独占共享入口和测试清单，集成已审改动，串行运行重计算、汇总 artifacts | 不凭集成通过授予物理信用；不替原作者独立审查自己的修改 |
| Luna 复核者 | 独立检查合同、源码、负控制、命令/退出码/证据身份；必要时另写独立检查器 | 与被审实现者不同；复核自身作品不算独立评审 |

提示词不能自行切换实际模型。启动时检查宿主可用模型及 reasoning 设置，派单回执记录请求值与实际值。缺少所需模型、工具或并发槽位时保持任务待分配并报告具体限制；不得静默改成另一模型或让 Sol 接管全部实现。模型可用时按用户授权持续委派，不为每个普通代码修改重复请示。

当前宿主最多 4 个并发智能体时，安排 Sol 加最多 3 个 Luna；宿主变化时读实际上限。实施者、集成者和复核者是可轮换岗位，不要求所有岗位永远占一个进程。空闲槽位只用于能独立推进的具体工单。

## 2. 启动与派单

1. 读取 00、README、[16](16_execution_work_orders.md)、`task_manifest.json` 与本次任务技术章。
2. 先派 UP0-01：核对 HEAD、dirty diff、未跟踪文件、运行中进程和落盘检查点。不要误停旧任务或覆盖非空 run 目录。
3. Sol 根据报告冻结本批合同及文件所有权，再派依赖已完成的工作单。UP1 三条 Genome 线可并行准备；共享版本和接口由 UP0-02 定义，最终由 UP1-04 集成。
4. 工单必须写明任务 ID、精确基线、读取清单、允许写入文件、不得写入文件、依赖的接口版本、输入输出、验收协议、资源限制、返回格式。
5. 已验证独立的代码编写/阅读可以并行。Julia 编译、DESC、Gridap/大网格、全包回归等共用一个重计算队列；每个任务必须取得当前队列所有权后启动，完成后落盘退出码和释放记录。
6. 实现完成后先独立复核，再由集成 Luna 执行相邻回归及必要整体运行。Sol 根据证据作接受/退回决定，由 Luna 将状态更新落盘。

## 3. 冻结接口及冲突

工作单合同包至少包含 `task_id / plan_version / base_commit / dirty_fingerprints / contract_refs / input_hashes / writable_paths / acceptance_protocol_ref / resource_lane`。这些是调度元数据，不替代运行时 typed payload。

禁止两名 Luna 同时修改同一文件。公共 `src/FusionConceptAI.jl`、`src/RuntimeV4/FusionRuntimeV4.jl`、`test/runtests.jl`、`test/runtime_v4_test_manifest.json` 等入口由集成者独占。组件作者在独立文件交付，并给出拟插入点；是否并入入口由集成工单处理。不得为安装 bridge 修改 `default_operator_registry()` 的默认语义；新增能力使用明确版本和隔离 manifest。

发现跨层语义或接口冲突时，Luna 返回最小反例、影响的工单和两个可行方案。Sol 决策并写入 [18](18_sources_and_architecture_decisions.md)，集成 Luna 更新合同版本和依赖；受影响的旧编译产物、候选哈希和 provider 收据作失效处理。不得用字符串约定、隐式全局状态或默认装置模板绕开冲突。

## 4. 状态与返回格式

调度状态仅描述工作，不描述物理：`planned → ready → running → review_pending → accepted`；失败复核回到 `running` 或 `changes_requested`；确需外部输入为 `blocked_external`。依赖未通过维持 `planned`。算法不收敛不能直接把工作单记 accepted；若工单目的是诊断，可接受诊断交付，但其被诊断物理义务仍失败或未知。

Luna 每次交付必须返回：

```text
task_id / actual_model / actual_reasoning_effort / base_commit
changed_paths + protected_file_hash_check
implemented_scope + still_unsupported_scope
contract_versions + candidate/input hashes
commands + working_directory + environment_versions + exit_codes
tests + physical/numerical outcomes + artifact_paths
negative_controls + independent_review_requests
next_dependency_or_specific_blocker
```

正常进展只给摘要与定位路径，不将全量日志塞回 Sol 上下文。主线未获得实际命令/退出码/产物时不能把“子智能体说已完成”当验收。没有新输出时不反复轮询同一进程；读取检查点和日志偏移，等待合理时间，继续其他无依赖工作。

## 5. 必须由 Sol 裁决的事项

- 改变 Genome schema、canonicalization、物理闭合或假设的含义。
- 新 backend 的适用域、独立性类别、能力缺口与替代路线。
- 预注册容差、资源预算、阶段范围、拓扑物化的能力边界。
- 复核者与实现者意见不一致，或证据不足却有人请求阶段晋升。

算法局部实现、可逆修复、相邻测试选择等由 Luna 在冻结工单范围内自行完成。不能因一个候选不收敛就请求用户重新批准整个路线；先诊断为建模缺口、数值失败、执行异常或适用域缺口。

## 6. 结束与归档

阶段完成必须有实现者、独立复核者、集成执行记录及 Sol 决策。实施者写 `docs/implementation/<task-id>/acceptance.md` 与证据 manifest；当前目录的任务状态引用档案。历史计划快照单列为 history，不是完成的实现。

整个父目标只在 R01–R10 全部满足且至少一个新候选通过最终适用门时完成。局部阶段关闭、文档更新、测试退出 0、一次 provider 成功、甚至一次平衡收敛均不能关闭父目标。外部数据、验证资源或工具缺失时写具体阻塞、已尝试路径和可继续任务，不伪造替代证据。

工作方式参考 [OpenAI 子智能体文档](https://learn.chatgpt.com/docs/agent-configuration/subagents)（2026-09-14 核验）；本项目的模型、职责和验收要求来自用户指令，不能由官方示例模型名覆盖。

## 7. AD-35 子任务关账与清理合同

状态：`accepted_limited`；`accepted=true`；`accepted_scope=collaboration_contract`。Sol/root 已依据 independent_review_r4 `pass_limited` 接受本协作合同；39-task count、DAG、主线/物理/R01–R10 credit 边界不变。

每个分派子任务在实现或适用的静态验证后都必须执行关账：先按任务拥有的 exact path 建立 cleanup inventory，再只清理本任务新建且不属于冻结交付、测试、evidence 或 accepted artifact 的 scratch/cache/debug/unrelated code。inventory 要记录 path、owner、category、before/after existence、before/after SHA256、action 和 reason，并给出 `final_exact_owned_set`；不确定路径使用 `cleanup_deferred_ambiguous` 并保留。禁止 broad glob、递归全局清理、按扩展名批量删除和全局 revert。

实现任务必须先完成专属正向和负向测试，并保存真实 raw/PID/exit/hash；纯架构、审计或文档任务运行适用的 JSON/link/diff/format/static 验证并明确 `code_tests=not_applicable`，不得伪造代码测试。每个适用静态命令也必须记录 command、cwd、PID 或 `in_process`、UTC start/end、exit、stdout/stderr/combined raw 内容及 SHA256、input/output/artifact hashes。pre-existing dirty、他人文件、R1–R10 失败 raw receipts 与 accepted artifacts 保护不变。清理后由不同 Luna 独立复核保护哈希、验证收据和最终 exact owned set；Julia/DESC/mesh/全包回归仍串行。详见 [AD-35 contract](../implementation/AD-35/acceptance.md) 与 [AD-35 manifest](../implementation/AD-35/manifest.json)。

## 8. AD-36 mandatory evidence sidecar scope amendment

AD-36 只澄清精确交付计数：`exact_file_count` 仅计算产品/合同 deliverables。实现或测试所需的 mandatory append-only evidence sidecars（raw stdout/stderr、exit、PID/UTC、interpreter、input/output hashes、repair reports、cleanup inventory、independent reviews、status sync）允许且必须放在该 task 专属 `docs/implementation/<task-id>/archive/**` 或命名的 review/status 子目录中；sidecar 不计入产品/合同文件数，不得越出专属目录、覆盖旧轮或被 cleanup 删除。sidecar 仅限 evidence metadata/raw/reports/inventory/review/status，禁止放入产品/合同 deliverable、source、test、fixture、staticQA 或 launcher；发现即 `scope_violation`/`fail_closed`，清理任务自有越界副本但保护违规 evidence。临时 launcher 仍禁止，测试使用 direct command。该规则应用于 AD-34 binding6、recheck7 及未来 exact-scope work orders；不改变 39-task DAG，不授 physical/R credit。详见 [AD-36 acceptance](../implementation/AD-36/acceptance.md)。
# Status synchronization rule (2026-09-15)

AD-36–AD-38 and the UP3–UP6 early-preparation packages are documentation/architecture records only. AD-36's sidecar amendment makes `exact_file_count` product/contract-only and requires append-only evidence-only sidecars; AD-37 does not publish present G1/G2; AD-38 is blocked on checked-present authority and T1/T2. The four UP packages may be accepted-limited preparation templates, but their formal runs and conclusions remain pending. No such record creates a machine node or changes the 39-task DAG. All worker closeouts still require real input/output hashes, PID/UTC/exit and applicable validation, with different-Luna review; runner/documentation exits never replace physical evidence.

## 9. AD-39–AD-42 synchronization and G3 binding ceiling

The synchronized records accept only bounded architecture or typed-absence software scopes. AD-39 and AD-41 are static audits; AD-40 accepts the repository-design source-authority architecture and seven finite work-order contracts; AD-40 W2's repaired payload/receipt products remain excluded point-in-time observations. AD-42 accepts the acyclic schema/profile→fresh-seed→payload boundary and W0→W2R1 preparation contract, with W0 explicitly parallel and prepare-only.

The G3 binding precursor is accepted-limited only for local typed-absence software behavior. Its machine node remains planned/proposal/accepted=false/review_pending. No checked-present authority, actual binding/feedback child, candidate hash, T0/T1/T2, provider, mesh, solver, engineering, physical, search or R01–R10 credit may be inferred. All evidence sidecars remain task-owned and append-only under AD-36; task cleanup protects pre-existing dirty work and historical receipts.

## 10. AD-42–AD-48 synchronized status ceiling

AD-42 W2R1 is fresh canonical G1/G2 source authoring only; AD-43 is the general G1/G2 four-axis software contract. AD-44 W3-A is untracked working-tree repository-design source provenance only and W3-B remains blocked. AD-45 A's common `QualifiedRefV1/v5` is a temporary G1/G2 join handle; AD-46 keeps final identity work orders blocked until complete G1/G2/G3 source-backed inputs, candidate-bound axes, explicit G2 mapping and independent identity reviews exist.

AD-47 W0 is an additive G3 axis contract and byte/hash closure; AD-47 W1 is four-scope/eight-product typed absence and does not establish G3 source authority. AD-48 S1 is a working-tree source-locator slice. S2 factory probe products may exist, but remain `in_progress`/`pending` until independent review and root decision; F0 is legal only after independently evidenced `AbsentG3FactoryIdentityV1`, followed by fresh S2, S3, fresh W1 and W2. Workers must report this ceiling explicitly and cannot promote any record through planner or runner success. T0/T1/T2, provider, mesh, solver, engineering, physical, search, R01–R10 and L4 remain false/zero. These decisions do not add task-manifest nodes or alter the 39-task DAG.

## 2026-09-16 AD49–AD50 core status synchronization

The AD48 and AD49 source-authority lanes are synchronized from their independent reviews and root records. AD48 F0/S2/S3 and AD49 F0/S2/S3 are `accepted_limited` within software and typed-absence ceilings. AD48 remains blocked on its external trust root; AD49 S3 remains blocked on external trust root and source closure. The AD49 S3 formal record was `review_pending` until the root acceptance recorded its limited decision; no present trusted identity is created.

This synchronization does not alter `task_manifest.json`, create a machine node, or unlock G2 mapping, W3B or AD46. UP1-04B, UP2-00, B00 and B04 retain their existing pending/blocked gates. T0/T1/T2, provider, mesh, solver, engineering, physical, search and R01–R10 remain false and L4 remains zero. The archive and exact input/output hashes are recorded in [CORE-STATUS-SYNC-AD49-AD50](../implementation/CORE-STATUS-SYNC-AD49-AD50/report.md).
AD50 本身当前为 `implementation_status=completed_review_pending`、`independent_review_status=pending`、`root_acceptance_status=pending`、`decision=review_pending`；本段只记录状态同步实现，不构成 AD50 验收。