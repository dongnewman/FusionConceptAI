# AD-36 status sync R1

状态：`review_pending`；`accepted=false`；`accepted_scope=null`；Sol decision pending。AD-36 是 mandatory evidence sidecar scope amendment，仅澄清 exact-file count 与实现/测试 evidence sidecar 的关系，等待不同 Luna/high 独立复核。

`exact_file_count` 只统计产品/合同 deliverables。实现/测试所需 raw stdout/stderr、exit、PID/UTC、interpreter、input/output/artifact hashes、repair reports、cleanup inventory、independent reviews 和 status sync 属于 mandatory append-only evidence sidecars，必须位于 task-owned `docs/implementation/<task-id>/archive/**` 或命名 `review/**`、`status_sync_*/**` 子目录，不计入产品文件数，不得覆盖旧轮、越出 task-owned 目录或被 cleanup 删除。临时 launcher 仍禁止，测试使用 direct command。

Sidecar 只能是 evidence metadata/raw/reports/inventory/review/status；禁止放入任何产品/合同 deliverable、source、test、fixture、staticQA 或 launcher 来规避 exact scope。发现即 `scope_violation`/`fail_closed`，由任务清理自己创建的越界副本并保留记录违规的 evidence；既有 evidence 继续保护。

本规则已同步到 AD-34 binding6（6 个产品/合同 deliverables）和 recheck7（7 个产品/合同 deliverables），并作为 future exact-scope workorders 的通用边界。39-task count、DAG、physical/R credit 边界不变；不授权 AD-34 实现或执行。

本任务为文档合同任务，`code_tests=not_applicable`；manifest 记录实际 JSON、plan/link/static validator 与 exact-path diff receipts。未运行 Julia、DESC、mesh 或重计算。四个 AD-36 档案均为冻结交付并保留，本轮无 scratch/cache/debug/unrelated code、无删除、无 deferred cleanup。
