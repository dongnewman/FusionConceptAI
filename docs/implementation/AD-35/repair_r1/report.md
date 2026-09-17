# AD-35 repair R1

R1 结论为 `changes_requested`。本 repair 只补齐合同字段和逐路径状态记录，继续保持 `status=review_pending`、`accepted=false`，不创建主线 task，不授予物理或 R01–R10 信用。

修复内容：

- 将 AD-35 `base_commit` 固定为完整 40 位 HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`，并明确 `gpt-5.6-luna` / `high`。
- 静态验证 receipt 现在要求并记录 command、cwd、PID 或 `in_process`、UTC start/end、exit、stdout/stderr/combined raw 内容 hash、input/output/artifact hashes。
- cleanup inventory 改为 exact path rows，分离 owned、protected、removed、deferred；不再使用聚合的 “all other” 行。
- `status_sync_r1/manifest.json` 纳入 inventory，并使用 `self_hash_excluded=true` 的非递归自身 hash 规则；实际字节 hash 由本 repair receipt 记录。
- 继续保护 pre-existing dirty、他人路径、R1–R10 失败 raw receipts 和 accepted artifacts；本轮没有创建 scratch/cache/debug/unrelated code，也没有删除或回退任何文件。

本 repair 只执行 JSON、plan/link/format 和 diff 验证；不运行 Julia、DESC 或重计算。独立 Luna R2 和 Sol 决策仍待完成。
