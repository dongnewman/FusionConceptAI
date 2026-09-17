# AD-35 status sync R2

状态：`accepted_limited`；`accepted=true`；`accepted_scope=collaboration_contract`；`sol_decision=accepted_limited`。Sol/root 依据 independent_review_r4 `pass_limited` 接受 AD-35 协作关账合同。task count 保持 39，DAG 保持无环；不创建主线 task，不授予 physical、provider、mesh、engineering、search、B00、B04 或 R01–R10 credit。`base_commit=4b69f55f7f80240147a65a22809dc1207824dde2`，`actual_model=gpt-5.6-luna`，`actual_reasoning_effort=high`。

本次只同步接受状态与索引字段，规则、任务数组、依赖边和清理保护边界不变。AD-35 是文档合同任务，`code_tests=not_applicable_for_contract_documentation`；实际运行 JSON parse、`validate_plan.py` 与逐路径 `git diff --check --`，不运行 Julia、DESC、mesh 或重计算。每条静态命令均在 manifest 中记录真实 cwd、PID、UTC、exit、stdout/stderr/combined raw 内容摘要及 SHA256、input/output/artifact hashes。

## 允许变更路径

本次允许修改的 exact targets 是 README、14、16、18、task_manifest、implementation README、AD-35 acceptance/manifest/status_sync_r1 report/status_sync_r1 manifest，以及 `status_sync_r2/report.md`、`status_sync_r2/manifest.json`。本轮新建且由 R2 拥有的 final exact owned set 仅为 status_sync_r2 的两个冻结交付档案；既有 repair_r1–r4 档案与 raw receipts 均为 accepted/protected artifacts，保持原样。

## cleanup closeout

status_sync_r2 只创建本报告和 manifest；两者均属于冻结交付，均保留。没有本轮 scratch/cache/debug/unrelated code，`removed_paths=[]`，`deferred_paths=[]`，`cleanup_action=none`。inventory 在 manifest 中逐路径列出这两个 owned 路径和每个 protected 路径的 before/after hash 或 `preexisting_untracked_no_baseline`；不使用聚合的 all-other 行。`status_sync_r2/manifest.json` 使用 `self_hash_excluded=true`，其递归 self hash 排除，最终自文件字节 hash 不回写自身。

## independent review boundary

不同 Luna 的独立复核对象是本 R2 状态字段、39-task/DAG 不变性、静态 receipts、逐路径 cleanup inventory 与保护集合；该档案不宣称任何实现任务或父目标完成。
