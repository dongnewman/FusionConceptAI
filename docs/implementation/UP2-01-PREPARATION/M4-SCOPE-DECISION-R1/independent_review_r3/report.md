# M4-SCOPE-DECISION-R1 R3 独立复核

## Verdict

`pass_limited`。R3 修复后的范围决策满足本轮五项复核条件；仅接受隔离范围决策本身，不授予 A 实现、UP2/B00/B04、provider、mesh、solver、物理、工程或 R01–R10 信用。M1 仍为 `review_pending`，A 仍未派发，Sol 仍需单独接受后才能进入后续步骤。

## Independent checks

- Formal reentry 在 manifest 和 decision 中均为精确顺序：`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`；UP1-04B 的 `50 fresh receipts + checker + two-process replay`、B00/B04、solver-input hashes 和 full re-verification 仍列为前置收据。
- `archive/final_hashes.json` 的三个产品记录与磁盘重新计算完全一致：`decision.md` 10964 bytes / `779f41...b788f`；`manifest.json` 6746 bytes / `71be66...21c34`；`cleanup_inventory.json` 2268 bytes / `5df3c4...f90f`。产品数为 3，cleanup inventory 对自身采用 self-hash exclusion。
- R1/R2 failure history、R2/R3 repair receipts 和 raw sidecars 均仍存在；R3 cleanup receipt 明确未删除、覆盖、staging 或修改既有 history。`final_json_parse.stdout.raw` 与 `scope_git_status.stdout.raw` 已在作者 validation receipt 中索引，且 SHA-256 与磁盘一致。
- M1 精确四路径及 hash 均可定位，状态仍为 `review_pending`，`accepted_by_this_decision=false`；其环境/导入闭包为可复核准备，不构成 authority。
- external trust blockers 仍为 typed absence，共 10 项，保留责任方、恢复条件和“不变输入不重跑 S3/不造新 AD”规则。
- 四个 Luna 角色使用不同标识，source/test-oracle/reviewer/integration-docs pairwise distinct；reviewer 明确不得复核自身或其他角色同一变更。角色并未授予执行权。
- 原作者 cleanup exact set 仍只有三个 R1 产品、无 ambiguous path；R1/R2/R3 archive sidecars 受保护。未运行 Julia/solver，未派发 A。

## Ceiling

本次只能将 R1 范围决策标为 `pass_limited`/可供 Sol 处理的范围文件；不能将 M1、S3、T0/T1/T2、UP2、B00/B04、数值、物理或 R01–R10 标记 accepted，也不能据此派发 A 或 B。
