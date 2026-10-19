# R01–R10 暂停交接与迭代路线（2026-09-26）

本文件是本次清扫后的工作树索引。父 Goal 按用户指令暂停，**未完成**；终局可信新候选数仍为 **0**。当前 HEAD 在清扫前为 `63792ca22958ffca8c3fa8e642256eb9f7240724`。活动范围、覆盖与阈值仍以 `docs/v4_multitopology_generation/README.md`、`16_execution_work_orders.md`、`task_manifest.json` 和 `25` 为准；这里不改变科学门。

## 最近一次正式尝试与下一步

| 门 | 最近实际运行、退出码及最深阶段 | 当前状态与复核 | 恢复时的下一步 |
|---|---|---|---|
| T2 负例与复放 | R19 controller shell exit **1**；前三阶段 parse、AST、projection exit 0，第四阶段 baseline Julia exit **15**，48.754 s、161 次采样、RSS 峰值 819,822,592 B；瞬时 `git.exe` PID 18528 在 SPI 行与 handle 重查间消失，`process_tree_monitor_incomplete`。四个负向 shard 均未启动。 | `formal_t2_accepted=false`，独立测试/审查 NO-GO；R20 只有未冻结 controller、QA 与旧 freezer 副本。保留 R19 [protocol](UP1-04A-VNEXT-T2/archive/r2_protocol_freeze_20260925_t2_protocol_r19_snapshot_receipt_retry4/protocol.json)、[pipeline](UP1-04A-VNEXT-T2/formal_t2_actual_negative_r19_r23_r9/pipeline_final.json) 与 [独立审查](UP1-04A-VNEXT-T2/archive/independent_t2_r19_postrun_review_20260926_r2/review.md)。 | 修复 Windows 短命子进程身份与 handle 绑定竞态，双人独立审查、host 负控后重新冻结；一次有界完整正式负例运行与新进程复放。|
| UP2 MMS 闭合 | V20 test-only controller exit **124** `resource_interruption`；producer exit **1**、259.829 s、934 个完整 RSS 样本，峰值 1,152,794,624 B，随后 PID 80036 `NoSuchProcess`、清理未确认。Julia 在第 850 行另外报保存状态 hash 不匹配；full validator 与 `M.result_tests` 消费者未开始。 | 两个独立复核均 NO-GO。向量 `state_after_hash=464534…89662` 与 case 身份 `state_hash=b36d…b5d7` 定义不同，第 850 行比较错误。原 V10 solver exit **2**、残差 `5.387476275861409e-4 > 1e-6` 的 `numerical_fail/no_publish` 不变。V21 仅有名称替换的占位副本，已归档清除。保留 [V20 final](UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r20/runtime_replay_r20/final.json) 与 [独立审查](UP2-04-CLOSURE-REPAIR-PREC/archive/independent_up2_v20_actual_postrun_reference_inverse_r1_20260926/review_report.md)。 | 分别修正采样/清理证明和 hash 对象，在隔离新版本复核后按原 480 s/阶段、2 GiB sampled RSS、960 s 总阶段预算串行重跑。|
| 原生 G1/G2 Gridap | R26 shell exit **1**；`parse_all` exit 0，primary 在 87.623 s 因 `resource_monitor_incomplete` 停止，262 个完整样本、峰值 579,330,048 B；fresh replay 未开始。 | R27 漏掉消失父进程 B 的存活后代 C，独立 NO-GO。R28 的 30/30 测试和 191 pin verifier 退出 0，但独立审查发现 stale PPID 场景无法排除短暂复用的 B′，**仍 NO-GO**；未启动 Gridap。保留 [R26 原始叶](UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_gridap_consumer_r26_v1/actual_run_root_grant_01/)、[R28 handoff](UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_gridap_consumer_r28_v1/handoff.md)。 | 用权威父代退出时间或保守标记未归属解决 B/B′ 歧义；独立复核通过后再安排唯一重计算槽。|
| 参考 G1/G2/G3 反演 | 正式反演 **not_executed**；已有源/载荷 hash 只读核对 exit 0、7/7。 | MAST 30421 EFM/P6 线圈段电流带符号映射和 AYC Thomson 通道、标定、协方差定义仍 `typed_absent`；`no_likelihood/no_inverse`。FEC 筛查或下载数据不升级信用。 | 取得第一方算法与标定，已知电流响应检验，冻结同候选 `F/H/y/Sigma`，再做 G1/G2/G3 与盲留出。|
| VNEXT aggregate、B00/B04、UP3、UP5、UP6 | 当前链正式消费者 **not_executed**；UP5 局部 Julia 测试 exit **1**，静态 Python 通过只算准备。 | 没有同候选物理、工程、全周期净输出、VVUQ、原创性和独立复放证据。 | 按 T2→aggregate/B00/B04→UP2 求解→UP3 组合→UP4 反演→UP5 真实搜索消费者→UP6 终局门串行/依赖恢复，最终由 root 裁决。|

精确命令、完整退出码、数值及独立审查仍在 [原关键路径表](GOAL-EXECUTION-20260923/archive/root_critical_path_20260925_r2/critical_path.md) 和 [root 实际派发收据](GOAL-EXECUTION-20260923/archive/root_critical_path_20260925_r2/root_actual_dispatches_20260926.md)。上表只概括已执行的最深阶段；静态测试不是物理或反演通过。

## 清扫与恢复边界

清扫前 `docs/implementation` 为 **21,593 文件 / 1,105,335,761 B**，`docs/reports` 为 **89 / 526,183 B**，`runs` 为 **1,457 / 581,187,768 B**，`tmp` 为 **12 / 297,766 B**。逐文件 SHA-256 归档并二次验证 **23,151/23,151** 项后，按明确路径共删除 **22,910 文件 / 1,566,531,579 B**：实施证据 21,401、报告 87、旧运行 1,410、临时文件 12。旧运行中第二批 548 项为 `goal_recovery_20260913_012528_cst` 内已归档且未跟踪的输出；Git 跟踪的 47 项（包括脏 `task_queue.json`）保留。另将无修复/未测试的 V21 三个源码占位副本（416,638 B）单独归档并清除。清扫脚本逐文件验证原字节，没有递归删除非空目录。

恢复包在仓库外 `D:\006-Programing\LMC\FusionConceptAI_cleanup_20260926\precleanup_docs_runs_tmp.zip`，SHA-256 `c84743bc55dc749bbcc43e936c278027ad9bce9b437c09e176be587f75ff2bb7`；同目录 `precleanup_manifest.jsonl` SHA-256 `77b95edeb3757a45b06e54ce4de6e7d861e8219e3800c646040b7f37f456414e`，`deleted_paths.jsonl` 和 `deleted_goal_recovery_untracked.jsonl` 逐条记录两批原路径、长度和 hash。V21 另存 `abandoned_v21_placeholder_sources.zip` 及其 JSON manifest。压缩包是历史恢复载体，**不是**当前运行/验收收据。

原冻结协议中有指向已移出的历史证据的 pins。恢复任何正式运行前，须按 manifest 精确恢复所需输入、核对 SHA，然后按当前源码和活动指导重新冻结协议；不能把清扫后的缺失路径或旧静态 GO 当成物理失败/通过。`typed_absent`、`numerical_fail`、`resource_interruption` 等原分类保持。此前自动审批拦截的 `UP5-01/.../__pycache__/run_once.cpython-313.pyc` 未删除，也没有改用其他工具绕过；其受阻记录与 40 个受保护脏文件基线保留。

## 2026-09-26 恢复执行补记

用户要求继续主任务后，已从上述校验过的 ZIP **仅恢复 R19 T2 protocol 引用的 427 个历史文件 / 76,568,568 B**；逐项内容与原归档及 protocol pin 相符。恢复收据：`D:\006-Programing\LMC\FusionConceptAI_cleanup_20260926\restored_t2_r19_reference_closure.json`。清扫后的文档数 196 是归档时点；本次必要恢复后两目录合计 **623**，仍低于原 21,682 文件的 1/20 上限（1,084）。R19 protocol 的 `formal_t2_actual_negative_r6_attempt11_retry8` 指向故意不存在的目录，未创建。恢复旧输入不使 R19 或 R20 自动通过；更新活动指导后必须重新冻结当前 R20。
