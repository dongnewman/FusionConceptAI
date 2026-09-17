# M4-SCOPE-DECISION-R1 R2 独立复核

## Verdict

`changes_requested`。R2 的 M1、external trust、role separation 和 sidecar-index 修复基本闭合，但 formal reentry 顺序仍错误，且三产品最终 hash receipt 中的 `manifest.json` 记录已陈旧。此复核只接受/退回范围决策，不授权 A 实现、B、UP2/B00/B04、物理或 R01–R10。

## Five-item audit

1. **M1 dependency：通过。** `decision.md` 与 `manifest.json` 已给出四个精确 M1 路径、各自 SHA-256、`status=review_pending`、`accepted_by_this_decision=false`，并明确需不同 Luna 复核及另行 Sol acceptance。dirty G1/G2/G3 factory hash、解释器路径/hash、静态导入闭包及未知运行时依赖均列出；没有把 M1 当作已接受事实。

2. **External trust：通过。** manifest/decision 给出 10 项 typed-absence 输入：provider/owner、independent attestor、trust root/key chain、certificate/signature、verifier、validity/revocation/time/freshness/anti-replay、source/version binding、G2 mapping、four axes、acceptance command/contact channel；每项有责任方/恢复条件，并声明外部材料未变化时禁止重复 S3/新 AD。该项仍是阻塞输入清单，不是 present/trusted authority。

3. **Role separation：通过。** 四个 Luna 角色有不同的明确标识：source implementer、test/oracle owner、independent reviewer、integration/docs owner；reviewer 明确不得复核自身或其他角色对同一变更的工作，Sol 单独负责 acceptance。未来路径也互斥且尚未创建。

4. **Formal reentry：不通过。** R2 文本和 manifest 当前写成 `... → aggregate → UP2-00 → UP1-04 → UP1-04B 50 fresh receipts + checker + two-process replay → ... → UP2-01`。要求顺序是 `T0 → recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B 50 + checker + two-process → UP1-04 → UP2-01`。必须交换 `UP1-04B` 与 `UP1-04` 的顺序，并保留 B00/B04、solver-input hashes 及完整复核。

5. **Validation receipt sidecars：部分通过，产品 hash 不通过。** `archive/validation_receipt.json` 已加入 `final_json_parse.stdout.raw` 和 `scope_git_status.stdout.raw` 的 informational entries，引用的 SHA-256 与磁盘实际值一致；R2 repair receipt 和两次失败历史也保留。可是 `archive/final_hashes.json` 当前记录 `manifest.json` 为 6687 bytes / `da63eb...`，实际 manifest 为 6685 bytes / `110efe...`。decision 与 cleanup inventory 的当前 hash 记录一致。需在不改产品内容的前提下重算并更新 final hash receipt（或留下明确的 superseded/repair receipt），再重新复核。

## Cleanup and dispatch ceiling

原作者 `cleanup_inventory.json` 仍将 exact owned product set 限定为三个产品、无删除、无 ambiguous path；R2 repair history 属于 append-only archive sidecar，不应纳入产品数。未运行 Julia/solver，不派发 A，不授予 manufactured numerical、UP2、B00/B04、物理、工程或 R01–R10 信用；当前决策只能保持 `review_pending`，直到上述两项修正后再次独立复核。
