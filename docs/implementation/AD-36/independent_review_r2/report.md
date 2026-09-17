# AD-36 mandatory evidence sidecar scope amendment — independent review R2

结论：`changes_requested`。

本轮只读复核 AD-36 independent R1、repair R1、当前 acceptance/manifest/status sync、AD-34/AD-35、核心 14/16/README/task policy 与现有静态 receipts；未修改被审文件，未运行 Julia、DESC、mesh、重计算或项目测试。只新增本目录的 `report.md` 与 `manifest.json`。

## R1 修复已闭合的部分

R1-CLEANUP 的根 manifest 修复已实际落地：AD-36 acceptance、status report、repair report 均有真实 64 位 after SHA256 与字节数；根 manifest 和 status-sync manifest 保留明确的 `self_hash_excluded`，没有把递归自哈希写入自身。

R1-SIDECAR 的 evidence-only 负向边界也已同步：AD-36 acceptance/manifest、核心 14、AD-35 acceptance/manifest 和核心 16 的全局 AD-35 关账门均禁止 product/contract deliverable、source、test、fixture、staticQA、launcher 进入 sidecar，并规定 `scope_violation`/`fail_closed`、只清理任务自有越界副本且保留违规 evidence。当前 AD-36 目录没有源码、测试、fixture、staticQA 或 launcher；AD-34 binding/recheck 仍分别为 6/7 个产品/合同文件，sidecar 目录仍是 task-owned、append-only、excluded-from-count、cleanup-protected。

39-task、DAG 无环、现有 plan/link/static receipt 的 466 links、JSON 解析和 exact-path diff 仍与当前状态一致。README 的 diff receipt 只有 Git 的 `LF will be replaced by CRLF` stderr warning，exit code 为 0；它没有造成验证失败，也不构成阻断。AD-36 仍为 `review_pending`/`accepted=false`，没有 provider、mesh、engineering、physical、search、B00、B04 或 R01–R10 credit。

## 仍未闭合的阻断

### AD36-R2-RECEIPT-01 — status_sync_r1 的命令输入哈希与当前文件漂移

repair R1 修改了 AD-36 根 manifest、AD-34/AD-35/core policy 等文件，并把 `status_sync_r1/manifest.json.current_file_hashes` 更新到了新状态，但 `status_sync_r1` 内保存的旧命令 receipts 没有随最终字节重算：

- JSON parse receipt 记录 AD-36 manifest 输入为 `a4bdd6df...`，当前文件为 `34b06aa3...`。
- diff receipt 记录 AD-36 manifest 输入为 `a4bdd6df...`，当前文件为 `34b06aa3...`。
- JSON parse receipt 记录 repair R1 manifest 输入为 `12b2061d...`，当前文件为 `66cda6bf...`。
- status-sync cleanup inventory 仍把 AD-36 根 manifest 的旧 after hash 记录为 `5ac257bb...`，而 current_file_hashes 与实际文件均为 `34b06aa...`。

这些不是 self-hash exclusion，而是同一 status record 内的 point-in-time 输入/cleanup hash 不一致。`current_file_hashes` 单独正确不能替代 raw receipt 的 input hash。旧 receipt 必须保留，不能覆盖；最小修复是新增 repair/status R2 记录，在最终文档字节冻结后重新执行适用 JSON/plan/link/static/diff 验证，保存真实 raw/PID/UTC/exit/stdout/stderr/combined/input/output/artifact hashes，并生成与该时点一致的 exact cleanup inventory。若继续沿用 status_sync_r1 名称，必须明确它是历史快照并把当前收据放到新的 append-only round，禁止静默改写 R1。

## 退出边界

在上述 point-in-time receipt/cleanup hash 修复前，AD-36 只能保持 `review_pending` / `accepted=false`。R2 通过后最多接受 sidecar scope amendment 的 contract-only boundary；不授权 AD-34/recheck 实现，不解锁 T1/T2，不创建 binding/feedback/T0 authority，不授任何 provider、mesh、engineering、physical、search、B00、B04 或 R01–R10 credit。

本轮 cleanup inventory：无 scratch、cache、debug、unrelated code 或 launcher；无删除、回退或 deferred cleanup；仅保留本复核目录的两个交付文件。
