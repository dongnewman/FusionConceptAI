# UP6 整装独立验收：前置架构审计

状态：`review_pending`；范围：`preparation_only`；claim ceiling：`contract_only`。
本审计只建立 UP6-01/02/03 的可审查前置合同、模板和证据边界。未执行整装物理、净输出、独立复放、原创性检索或 R01–R10 关账；所有结论保持 `pending`，L4 credible count 为 `0`。

## 依据和当前基线

本包的只读输入为：

- `AGENTS.md`、`README.md`；
- `docs/v4_multitopology_generation/README.md`、`00_normative_contracts_and_state_model.md`、`06_multifidelity_hard_physics_frontier.md`、`08_high_fidelity_whole_device_vvuq.md`、`09_evidence_authority_campaign_and_v4_roadmap.md`、`13_acceptance_benchmarks_and_evidence.md`、`14_agent_orchestration.md`、`16_execution_work_orders.md`、`18_sources_and_architecture_decisions.md`；
- `docs/v4_multitopology_generation/task_manifest.json`；
- `docs/implementation/PYTHON-ENV-REINSTALL-AUDIT/`；
- 已有 provider、工程、VVUQ、原创性、goal ledger、`docs/reports/` 与 `runs/`，均按历史或只读上下文处理。

当前工作树是 dirty。UP0-01 的历史审计记录了 W24 四个物理 case 的 solver `exit 4`/`iteration_limit`，以及工程和 whole-device 的 deferred 边界；历史记录的身份和哈希只用于追溯，不能填充本包的 fresh receipt。当前 goal ledger 的 R01–R10 均 `accepted=false`，父目标 `discovery_goal_achieved=false`、`credible_candidate_count=0`。这些是已读取的历史/基线状态，不是本包新的验收结论。

## UP6 边界和 authority

UP6-01 必须逐候选、逐适用域、逐 required scenario 关闭物理和工程义务；UP6-02 才能消费收敛整装解，执行 verification、validation、discrepancy、uncertainty 和全周期站级账本；UP6-03 由独立执行者进行原创性协议和完整复放，最后才由 `FinalWholeDeviceAuthorityV4` 发出终局 disposition。中间 provider、solver、VVUQ 或搜索模块没有权力发出 `credible_within_scope`、终局 `unsupported` 或 R01–R10 acceptance。

身份必须按层重建并绑定：`mechanism_hash`、`field_geometry_hash`、`realization_control_hash`、`genome_bundle_hash`、`physical_subject_hash`、`solver_input_hash`、`scenario_manifest_hash` 和各 provider/toolchain/source tree/build hash。候选、场景、输入、提供者或源码有语义变化时，旧 receipt 不得嫁接；缓存命中不算独立执行。

## 证据链合同

```text
candidate-bound Genome bundle
  -> physical subject and obligation ledger
  -> exact provider/toolchain/source/build admission
  -> integrated residual/iteration and hard-gate evidence
  -> verification and validation VVUQ with discrepancy/UQ propagation
  -> engineering and all required scenarios
  -> whole-cycle plant ledger and conservative net-output interval
  -> independent originality search and two-executor replay
  -> FinalWholeDeviceAuthorityV4 / R01-R10 closeout
```

每个结果必须同时保留：原始命令、cwd、PID 或进程标识、UTC 起止、退出码、stdout/stderr/combined 原文及 SHA-256、输入/输出/工件哈希、provider 与环境身份、适用域和限制。`null` 指标必须带不适用或缺失原因；不能以 `0`、`Inf`、空结果或 runner exit 0 代替缺证据。

## 整装义务覆盖

`engineering_obligation_ledger_template.json` 将义务拆为可逐项关账的记录：平衡、稳定、轨道/端损失、输运、燃烧/反应、辐射；外域、供能、电源、冷却；材料、热、结构、屏蔽、维护；控制、传感器、执行器、故障和安全停机；燃料循环、能量转换、厂用电和全周期站级账本。每条记录都需要 applicability proof、provider/toolchain/source/data receipt、candidate/scenario binding、quantity/unit/threshold、discrepancy/UQ 和 authority disposition。required 但缺 provider 只能是 `terminal_deferred`；未声明 `not_applicable` 不能默跳。

## VVUQ、原创性和复放边界

verification 证明离散实现、收敛和守恒审计；validation 比较候选绑定的独立测量/参考数据；discrepancy 是模型与观测或双实现之间的差异模型；uncertainty 覆盖参数、制造、初值、solver、网格/基阶/时间步和数据测量不确定度。数据条目必须带许可/使用权、版本、来源、内容哈希、校准/验证隔离、适用域、候选和 scenario ref。数值 VVUQ 不提升为 validation 或工程 qualification。

原创性记录检索日期、数据库/库版本、精确查询、筛选和复核方法，并分别比较机制、结构和行为；没有实际检索就保持 `pending`。独立复放必须隔离环境、冻结命令和输入、保存 raw/hash，并由两个不同执行者/independence group 重放；同一环境缓存、换线性求解器或复用历史 run 都不能作为第二独立证据。

## 当前开放项

UP6 正式运行前仍需 Sol 冻结 mission、candidate/scenario identities、适用域、阈值和 authority；逐 provider 取得 fresh toolchain/source/build receipt；补齐有许可的数据和 discrepancy/UQ 计划；为每条 required obligation 指派 owner、provider 和测试；再由独立执行者重放。上述准备不代表 UP6-01/02/03 已启动或通过，也不改变任何历史失败和 raw evidence。

