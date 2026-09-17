# AD-46 三层 Candidate Identity Owner 独立复核 R1

日期：2026-09-15  
复核者：different `gpt-5.6-luna/high` independent reviewer  
结论：`changes_requested`  
验收：`accepted=false`  
范围：只复核 AD-46 三产品、三份有限工作单、共同合同和当前上游收据；不生成
CandidateIdentityV1、候选 hash、binding、T0/T1/T2、provider、mesh、solver、physics、
search 或 R01–R10 证据。

## 复核对象与当前定点

AD-46 审计目录的三个根产品可重算：`report.md` 为 9564 bytes，SHA-256
`37aa44a3344913d66bdfd0f4d80d6d9de68523d57061509da2abe199a6ac06ac`；
`cleanup_inventory.md` 为 1027 bytes，SHA-256
`0cd00cfb804d68bf8df1b36fd4b5d5d4d54a557a640ef4de4d4de3ccf1b24190`；manifest 的
自身 hash 按合同排除。三份产品均未修改。

三个工作单各声明恰好两个产品，结果 union 均为成功、typed absence、failure 三分支：

| 工作单 | 两件产品 | result union | 当前状态 |
|---|---|---|---|
| `AD46-IDENTITY-INPUT-FREEZE` | `identity_input_freeze_v1.json`、`freeze_receipt.json` | `IdentityInputFreezeV1` / `AbsentIdentityInputFreezeV1` / `FailedIdentityInputFreezeV1` | blocked |
| `AD46-TRILAYER-JOIN` | `trilayer_join_receipt.json`、`join_negative_controls.json` | `TrilayerJoinV1` / `AbsentTrilayerJoinV1` / `FailedTrilayerJoinV1` | blocked |
| `AD46-IDENTITY-MATERIALIZATION` | `candidate_identity_v1.json`、`identity_receipt.json` | `CandidateIdentityV1` / `AbsentCandidateIdentityV1` / `FailedCandidateIdentityV1` | blocked |

上述六个未来产品目录当前不存在；AD-46 没有因本审计产生 identity 或 hash。当前
task manifest 仍为 39 tasks、DAG acyclic，SHA-256 为
`7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`。

## 需要修复的 AD-46 审计产品

AD-46 根报告的合同判断大体正确，但其上游状态已经过时，不能作为当前定点审计记录：

1. 报告仍写 AD-44 W3-A 独立复核为 `changes_requested`。当前 AD-44 W3-A R2
   已是 `pass_limited`，仅接受当前工作树 repository-design source software
   provenance；它明确保留 HEAD source blob 缺失、candidate-bound W3-B 不存在和
   所有物理/父目标信用为 false。AD-46 应改为引用 W3-A R2，并保留这些边界。
2. 报告写 AD-45 A “没有独立复核”。当前 AD-45 A 已有不同 Luna 的
   `independent_review_r1/report.md`，其结论是 `changes_requested`：五份负控 raw
   的 artifact SHA 少一位、每项 raw 缺少 canonical input SHA/namespace/nonce 或
   UUID/generation/CAS/可信时间字段，且 wall-clock 的 envelope result token 不是
   精确 union 成员。该 review 不是通过证据，AD-45 A 仍不能解锁 B 或 AD-46；但
   “没有独立复核”的事实陈述必须修正为“复核存在且未通过”。

这两个过时陈述是本 R1 的 `changes_requested` 原因。它们不改变 AD-46 的总裁决：
三个工作单仍全部 blocked。AD-45 原 audit manifest 仍 `accepted=false`，A 的实现
产品虽已落盘，其独立 review 尚未通过，也没有形成可用于 identity 的 source-backed
三层输入。

## CandidateIdentityV1 的合同核对

common `QualifiedRefV1` 必须只作为 fresh、同候选 join/binding handle。AD-45 A 的
句柄由独立 namespace、UUID、nonce、CAS token 和 OS randomness 产生，明确排除
seed、payload、声明、axis、历史 fixture、legacy 和最终 candidate hash；其
`candidate_identity_created=false`、`candidate_identity_hash=null`。它不能改名为
最终 CandidateIdentityV1，也不能单独使任何层 present。

最终 identity 的输入不能缩减为 G1/G2 两层、一个 seed、URI、payload hash 或 common
handle。必须同时有：

1. G1、G2、G3 各自保持原始类型的实际 `GenomeContractRef` 和 source-backed
   declaration、source/content/declaration/bundle hashes；
2. 三层四个 candidate-bound axes 和不同 Luna 的 source identity review/factory
   receipts；AD-43 当前产品是 source-only axis contract，candidate-bound 字段仍
   null；
3. 位于 identity input freeze/join 中的显式
   `GenomeContractRef -> common QualifiedRefV1` G2 mapping，不能从 URI、字符串、
   seed 或任意 hash 推导，G2 仍必须是 `GenomeContractRef`；
4. 同一 fresh candidate 的 G3 source-backed bundle、realization/control/binding
   child identity 以及 feedback/authority provenance。

合法的无循环顺序仍是 fresh handle → 三层 source-backed declarations → 独立 source
   identity reviews → 显式 G2 mapping → candidate-bound axes →
   `IdentityInputFreezeV1` → `TrilayerJoinV1` semantic preimage →
   `CandidateIdentityV1` materialization → T0/T1/T2。semantic preimage 只能引用这些
   canonical 输入；不能含最终 identity hash、自身 URI、未来 candidate hash、seed、
   payload hash 或历史 hash。任一 source/ref/axis/mapping/child 变化必须生成新的
   preimage 和新的 identity；冲突、重放和旧候选复用必须 fail closed。

## 当前阻断与最早前置修复

当前阻断是实质性的：AD-37 仍记录 G1/G2 fresh source-backed instance、factory
receipt 和 declaration receipt 未找到并 `terminal_deferred`；AD-43 candidate-bound
axis 尚未具备；AD-44 W3-A 只有 software provenance，W3-B 尚未形成；G3
realization/control/binding/feedback 仍是 typed absence/terminal deferred；AD-45 A
的 fresh handle review 为 `changes_requested`。因此 AD46-IDENTITY-INPUT-FREEZE、
AD46-TRILAYER-JOIN、AD46-IDENTITY-MATERIALIZATION 当前全部不可派发为成功实现，且
只能在缺输入时返回 typed absence/deferred。

最早可派发的前置修复是 AD-45 A 的版本化修复：由原实现者补齐五个负控 raw 的完整
artifact hash 和逐项 machine-level input receipt，修正 wall-clock exact result
union token，保留本轮失败 raw，重新冻结 envelope/receipt，再交给另一不同 Luna
独立复核。其后才可评估 W3-B G1/G2 candidate-bound axis；这些轴还必须等待 fresh
三层 source/factory/identity inputs 和显式 G2 mapping。G1/G2 publication、G3
source-backed child/feedback 输入可分别准备，但不能把准备记录升级为 AD-46 identity
输入，更不能绕过 T0/T1/T2 顺序。

本复核未执行任何物理或工程运行。所有 candidate identity/hash、present、T0/T1/T2、
provider、mesh、solver、engineering、physical、search、R01–R10 和 L4 credit 继续
为 false/0。
