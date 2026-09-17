# AD-36 repair R1

状态仍为 `review_pending`；`accepted=false`。本修复响应 independent R1 `changes_requested`：补齐 AD-36 根 manifest 的非 self owned 文件真实 after SHA256/byte length，刷新 status sync current hashes，并把 evidence-only 负边界同步到 AD-36、AD-34、AD-35、core14、core16 与 task policy。

新增负条款：sidecar 只能保存 evidence metadata/raw/reports/inventory/review/status；不得放入产品/合同 deliverable、source、test、fixture、staticQA 或 launcher 来规避 exact scope。发现即 `scope_violation`/`fail_closed`；任务自有越界副本需清理，但违规 evidence 受保护。39-task count、DAG、credit boundaries 和 review_pending 状态不变。

本轮只新增本 repair report/manifest；不修改源码、测试、runs、旧 raw receipts 或其他 prep 包。文档任务使用 JSON、plan/link/static validator 和 exact-path diff check；未运行 Julia/DESC。cleanup inventory 逐路径保留本 repair 两个冻结档案，无 scratch/cache/debug/unrelated code、无删除、无 deferred cleanup。
