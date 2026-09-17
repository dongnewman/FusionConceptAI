# AD-36 mandatory evidence sidecar scope amendment — independent review R1

结论：`changes_requested`。

本复核仅读取 AD-36 acceptance/manifest/status sync、AD-34/AD-35 当前 acceptance/manifest、v4 核心 14/16/18、README、implementation README、task manifest 及当前 G3 binding/recheck work-order 条款；未修改被审文件，未运行 Julia、DESC、mesh、重计算或项目测试。只新增本目录的 `report.md` 与 `manifest.json`。

## 已闭合项

1. AD-36 的范围定义正确：`exact_file_count` 只计算产品/合同 deliverables；mandatory append-only evidence sidecars 受 task-owned `archive/**` 或命名 `review/**`、`status_sync_*/**` 目录约束，不能覆盖旧轮、不能被 cleanup 删除，临时 launcher 禁止，测试使用 direct command。
2. AD-34 binding precursor 的 6 个产品/合同文件与 T0 authority recheck 的 7 个产品/合同文件，在 `16_execution_work_orders.md`、AD-34 acceptance 和 manifest 中一致；两个工作单的 sidecar 根目录分别绑定自己的 task 目录，且均声明不计入 exact count。binding 仍无 feedback child；recheck 仍独立于 binding、位于 T0 后/T1 前，T1 依赖 T0+recheck，DAG 无环。
3. AD-35 的 raw receipt、cleanup inventory、不同 Luna 复核和 Sol 决策合同已被核心 14/16、README 与 AD-35 当前记录同步；AD-36 未创建主线任务。现有 AD-36 status sync receipt 报告 JSON、plan/link/static 与 exact-path diff 已通过，任务计数为 39、相对链接为 466，且 `accepted=false`、`status=review_pending`。
4. 当前 AD-36 没有产品源码、测试文件或 launcher 藏在 sidecar/archive 路径；AD-36 目录只有 acceptance、manifest 和 status_sync_r1 两份状态文件。provider、mesh、engineering、physical、search、B00、B04 与 R01–R10 信用均未晋升；AD-34 的 actual binding/feedback/control/T0/T1/T2 也保持 false。

## 阻断项与最小修复

### AD36-R1-CLEANUP-01 — 根 manifest 的 cleanup hash 不完整

`docs/implementation/AD-36/manifest.json` 的 `cleanup_inventory` 逐项列出了四个交付路径，但 `acceptance.md`、`status_sync_r1/report.md` 和 `status_sync_r1/manifest.json` 的 `after_sha256` 均为 `null`。其中只有 manifest 自身可以使用明确的 self-hash exclusion；其他已存在的冻结交付必须记录真实 64 位 after SHA256。AD-36 status sync manifest 已保存这些实际 hash，但没有修复根 manifest 自身的不完整 inventory。

最小修复：更新根 manifest 的三行 `after_sha256`，使用当前字节哈希；根 manifest 自身和 status-sync manifest 保留 `self_hash_excluded=true` 及非递归自哈希规则，并在 repair/status receipt 中记录更新后的根 manifest hash。不得改写既有轮次或清理任何历史证据。

### AD36-R1-SIDECAR-01 — 需要明确 evidence-only 负向边界

现有文字已经规定 sidecar 的位置、append-only、count exclusion 和 cleanup protection，但没有用可执行的负向条款明确禁止把产品/合同 deliverable、源码、测试、fixture 或 launcher 藏入 `archive/**`、`review/**` 或 `status_sync_*/**`。六/七文件清单目前没有越界事实，但未来 exact-scope workorder 仍可能把“目录允许”误读成“任意文件允许”。

最小修复：在 AD-36 acceptance、manifest 的 sidecar scope，以及核心 14/16 的对应条款中加入同一条规则：sidecar 目录只允许列举的 evidence receipt/repair/review/status/cleanup 文件；任何产品/合同交付物、源码、测试、fixture、runner/launcher 必须出现在显式 product-contract ownership 列表中，进入 sidecar 目录即 `fail_closed`，并计入 scope violation，而不是借目录规避 exact count。补充后更新受影响文档的静态 receipt/hash，但不改变 39-task DAG。

## 保留的边界

AD-36 在上述两项修复前只能保持 `review_pending` / `accepted=false`。它不授权 AD-34 或 recheck 实现，不创建 binding/feedback/T0 authority，不解锁 T1/T2，不授任何 provider、mesh、engineering、physical、search、B00、B04 或 R01–R10 信用。现有 dirty 文件、旧 receipts、runs、历史 repairs 和其他 agent 路径均保持只读。

本轮 cleanup inventory：无 scratch、cache、debug、unrelated code 或 launcher；无删除、回退或 deferred cleanup；仅保留本复核目录中的两个交付文件。
