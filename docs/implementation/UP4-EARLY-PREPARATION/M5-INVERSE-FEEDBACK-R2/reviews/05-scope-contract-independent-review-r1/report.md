# M5 inverse-feedback R2 R3 scope-contract independent review R1

## 裁决

结论：`changes_requested`，`implementation_not_authorized`，`status=review_pending`。
本审查不授权 bounded `screen_only` V2 implementation。最高 claim ceiling 仍为
`manufactured_inverse_feedback/screen_only`，`formal_credit=none`；不授予
UP4-01/02/03/04、B07A/B、B08、provider、solver、engineering、physical、candidate
或 R01--R10 credit。

本次仅做 PowerShell/Python 文件解析、字节/SHA-256、路径/字段静态核对；没有运行
Julia、DESC、provider、solver、mesh、S3、hardware 或 network，也没有修改源码、
tests、合同或历史包。唯一写入是本 review 目录。

## 输入边界

审查了 `05-scope-contract-repair-r3/**`、
`reviews/03-scope-contract-independent-review-r1/**`、以及实际存在于包根的
`04-implementation-readiness-audit-r1/**`（用户给出的 `reviews/04-...` 路径在
当前 checkout 不存在）。R3 的 manifest 固定 HEAD
`b2c04d8339774635aaecd73651efcdb101e01b5d`；既有 dirty worktree 保持只读。

## 逐项静态核验

| 项目 | 结果 | 证据与边界 |
|---|---|---|
| canonical joins/digests | **P1 fail** | 10 组 pointer equality 和 D01--D12 被列出，但 D12 的 bytes pointer 是 `/canonical_bundle/canonical_bytes`，而 canonical schema 只有 `canonical_bytes_sha256`，没有 `canonical_bytes` 字段。D03--D09 只重算 typed body digest，除 source 外没有逐一重算 typed `content_sha256`。另有 candidate/source/owner 未贯通 deletion/history 的完整 identity pointer。checker 文件自身标记 `contract_only_not_executed`，所以文字 invariant 不是已执行 checker receipt。 |
| `valid_screen` implication | **P1/P2 fail-limited** | output schema 的 valid 分支确实约束 `valid=true`、fresh authority、join/ref-digest/CAS/identity/owner/direction/taxonomy/checker 为 true，以及两次 replay、`[0,0]`、相等性、raw/process refs。可是 `history` 没有 `minItems`，C01--C04 未在 schema implication 中闭合；缺失的 deletion/history candidate/source/owner 等值链允许外来 identity 伴随 `cas_pass=true`，除非未来实现补写未提供的 checker。 |
| 17 dependency closure | **static pass** | manifest 的 17 项 path/bytes/SHA 当前均匹配；19 条 include edge 全部指向这 17 项；按 manifest 规定的 `path\tbytes\tsha256\n` 排序序列重算 closure SHA 与 `a3463dfe...a21ad` 相等。该 pass 只是当前字节一致，不是 fresh authority。 |
| 33 failure mapping | **static pass** | concrete taxonomy 为 33 行、33 个唯一 code；与 failure-record/taxonomy schema 的 code/class/resolution enums 相等。无 runtime failure record；mapping 仍需 future typed checker 对 record 做逐行闭合。 |
| CAS/history | **P1/P2 fail-limited** | C01--C04 文字规则存在，且 schema 有 full-looking fields；但 checker pointer list 只把 edge/parameter/axis/direction 贯通到 deletion/history，未把 candidate/source/owner 贯通。`history` 可为空且只有 state hashes，没有 C03 所需的 canonical before/after state bytes 或 operation bytes 投影；sequence/version/fail-atomic 仍是未执行的 prose contract。 |
| URN resolver | **static pass, runtime deferred** | 7 个 local URN registry entries 的 package-contained path、bytes、SHA 均匹配；network/implicit base 禁止，unknown URI=`typed_absent`。没有也不应有 runtime resolver/unknown-URI receipt。 |
| dirty start/end/fresh freeze | **P1 fail** | start/end 都有 384 条 baseline records，path/status/bytes/SHA 静态比较为 0 diff，end comparison 写成 `pass_at_snapshot_baseline_non_task_paths_unchanged_plus_task_package`。但 end receipt 的 `captured_utc=2026-09-17T00:00:00Z` 早于 manifest `review_start_utc=2026-09-17T03:27:05.0798986Z`；freeze receipt 仍是 `pending_independent_review`、`review_end=pending_independent_handoff`、`current_authority=unknown_until_fresh_refreeze`。因此它不能是本审查后的 review-end/fresh-freeze authority。 |
| 25 hash entries | **static pass** | 实际 package files（排除 hash_manifest 自身）=25，entries=25，missing=0，hash/byte mismatch=0。 |
| negative vectors | **static inventory pass, not executed** | 24 vectors，ID 唯一且与 checker 的 24 negative_controls 一一对应，覆盖 foreign join/digest/resolver/replay/CAS/history/taxonomy/dirty 等。文件明确 `execution=not_executed`；没有 empty-history、missing-state-bytes 或 D12-invalid-pointer 的向量，因此上述缺口未被负向集合捕获。 |

## 关键 findings

### P1-R3-01 — D12 不是可重算 canonical-bytes digest

`checker_contract.json:21-33` 把
`/candidate_binding/canonical_bundle_sha256` 声明为从
`/canonical_bundle/canonical_bytes` 重算；但
`schemas/canonical_bundle_schema.json:5-12` 没有 `canonical_bytes`，只有
`canonical_bytes_sha256`。因此 canonical bundle digest closure 在静态合同层面
不成立。应明确冻结 canonical bytes 投影（或将 D12 改为真实字段），并补 positive
与 digest-mismatch negative receipt。

### P1-R3-02 — CAS/history identity 与 valid-screen gate 仍可脱链

`checker_contract.json:16-19` 只比较 feedback/deletion/history 的 edge、parameter、
axis、direction；candidate/source/owner 没有同样的 deletion/history pointer
equalities。`schemas/output_schema.json:17-19` 又允许这些对象各自携带任意合法
ref，且 history array 没有 `minItems`。因此仅凭当前 schema + checker contract
文本，无法证明 foreign owner/candidate/source、empty history 或 fail-atomic
state transition 会 fail closed。需补完整 immutable tuple equality、history
non-empty/sequence/version/state-byte projection，并把这些条件机器绑定到
`valid_screen`。

### P1-R3-03 — dirty end receipt 与 fresh freeze 时序不成立

`raw/dirty_inventory_end.json:4-10` 的比较仅在其 2026-09-17 00:00 snapshot 上
成立，而 manifest 的 review start 是 03:27Z；`freeze_receipt.json:3-15` 明确仍
pending、unknown authority、pending handoff。必须在全部合同修改后重新 capture
review-start/end、重算 package/dependency hashes，并由不同角色复核；当前 receipt
不能授权 implementation。

## 正向静态结果与证据保存

独立静态命令 PID `78808`，UTC `2026-09-17T04:37:19.9494027Z`--
`2026-09-17T04:37:20.1027543Z`，exit `0`；raw stdout/stderr、validation
receipt 与本报告同目录保存。它只证明当前 snapshot 的内部一致性，不证明
implementation/replay/fresh authority。

## 最终边界

保持 `review_pending`，拒绝 bounded `screen_only` V2 implementation authorization。
R3 需先修复 P1-R3-01/P1-R3-02，重新捕获时序正确的 dirty end/fresh freeze，补齐
missing negative vectors，并取得不同角色 review 与 Sol/root 决策。即使这些门关闭，
后续 lane 仍只能是 isolated manufactured software fixture，必须两次 serial replay；
`formal_credit` 仍为 `none`，外部 authority 仍 `typed_absent`，不得转移到 UP4、
B07A/B、B08、provider、solver、engineering、physical 或 hardware claims。
