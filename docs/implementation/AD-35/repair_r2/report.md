# AD-35 repair R2

R2 是对 independent R2 `changes_requested` 的最小修复。状态继续为 `review_pending`、`accepted=false`；AD-35 仍是协作合同，不创建主线 task，不授物理或 R01–R10 信用。

本轮修复：

- 实际执行并保存三个精确静态命令：AD-35 manifests JSON parse、`validate_plan.py`、逐项列出允许 core 与 AD-35 路径的 `git diff --check`。每条 receipt 都含 PID、UTC、exit、stdout/stderr/combined raw byte/hash、input/output/artifact hashes。
- raw stdout/stderr 分别保存为本目录的六个指定文件；JSON parse 明确列出 AD-35 manifest 路径，diff 命令不含占位符。未跟踪文件范围另以 exact path inventory 记录，diff receipt 不宣称覆盖未跟踪内容。
- `status_sync_r1/manifest.json` 顶层声明 `self_hash_excluded=true`；最终稳定文件 hash 通过 status sync 与本 repair receipt 记录，manifest 自身递归 hash 排除。
- cleanup inventory 逐项加入 repair_r2 的八个 owned 文件，并保留显式 protected/removed/deferred 集合；本轮未创建 scratch/cache/debug/unrelated code，未删除或回退任何路径。

本轮只运行 JSON、plan/link/format 和 diff 验证；不运行 Julia、DESC 或重计算。最终 current hashes、命令 receipt 与独立复核入口见 `manifest.json`。
