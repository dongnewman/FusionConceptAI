# AD-45 FreshCandidateBindingEnvelopeV1 independent review R1

日期：2026-09-15  
复核者：different `gpt-5.6-luna/high` independent reviewer  
结论：`changes_requested`  
验收：`accepted=false`  
范围：AD45 A 单的软件合同、内容寻址收据、五类机器级负控和边界声明；不授予 candidate identity、T0/T1/T2、provider、mesh、solver、工程、物理、搜索或 R01–R10 信用。

本复核只读取共同合同、AD45 prerequisite audit 及其 R1/R2、AD42 W0/W2R1、AD43 轴合同、AD45 两件产品和全部 archive/negative_controls。没有修改被审产品、源码、测试、fixture、核心目录或 `task_manifest.json`。只在本目录写入本报告、manifest 和 `review/` raw sidecars。

## 冻结输入与边界

被审产品与父任务冻结值逐字节匹配：

- `fresh_candidate_binding_envelope_v1.json`：7911 bytes，SHA-256 `d82ab662e72bb4ea9c50524e3ffec1146a84a4f6dc23cb37ff366b74575852c5`。
- `envelope_receipt.json`：3750 bytes，SHA-256 `31fb41e6d30e03256d07098f34ab47040c6c1d9b17330daeb7fd9754df0b6ba2`。

两件产品都是 sorted compact canonical UTF-8、无末尾 LF，receipt 对 envelope 的字节数和 SHA-256 闭合。common ref 是 `QualifiedRefV1`/`v5`，namespace 固定为 AD45 专属值，UUID 为 v4 形状，nonce 为 64 个十六进制字符；产品记录 OS cryptographic random source、exclusive create、generation、CAS token、nonce non-reuse，且明确 wall clock 只作 receipt metadata。G1/G2 均保留自身 `GenomeContractRef`；G2 的 `qualified_ref_alias=false` 且 `source_type_preserved=true`。W0、W2R1、AD43 四类输入的路径、字节数和 SHA-256 均重新闭合。

独立检查还确认 fresh UUID、nonce 和 namespace 没有出现在 AD42 seed、W0/W2R1 或 AD43 输入中；seed guard 仍是 read-only negative-control，禁止 derivation，且没有 candidate/declaration/final hash 生成。B-G1/B-G2 产品目录不存在，G2 的未来 mapping 仍未被改写。

## 复核运行证据

直接独立核验使用 `D:\Users\Newman\anaconda3\python.exe` / Python 3.13.5，PID `31752`，UTC `2026-09-15T11:45:58.125972+00:00` 至 `2026-09-15T11:45:58.143994+00:00`，exit `1`。35 项直接检查中 29 项通过、6 项失败；原始 stdout 保存在 `review/direct_validation_stdout.json`，stderr 是零字节并保存在对应 sidecar。失败不是运行器异常，而是对已落盘负控收据和 result-union 字段的内容核验失败。

规划校验使用 Python 子进程 PID `83664`（wrapper PID `85836`），UTC `11:46:12.388893+00:00` 至 `11:46:12.790002+00:00`，exit `0`：31 markdown、497 relative links、39 tasks、DAG acyclic。其原始 stdout/stderr 已保存。作用域 `git diff --check` 子进程 PID `31016`（wrapper PID `39564`），UTC `11:46:22.735579+00:00` 至 `11:46:22.781582+00:00`，exit `0`，stdout/stderr 均为空。上述规划和作用域检查不替代负控内容证据。

## 需要修复的门

1. 五个 machine-level negative-control raw receipt 的 `artifact_sha256` 都是 63 个字符，值为 `d82ab662e72bb4ea9c50524e3ffec1146a84a4f6dc23cb37ff366b74575852c`，少了被审 envelope 实际 SHA-256 的最后一个字符 `5`。因此 `uuid_nonce_collision`、`envelope_replay_nonce_reuse`、`concurrent_dual_write_cas_conflict`、`wall_clock_rollback_future_skew` 和 `ad42_seed_misuse` 的 raw artifact hash 均不能通过内容寻址校验。`envelope_receipt.json` 自身的 envelope hash 是正确的；问题局限在五份负控 raw。

2. 五份负控 raw 没有记录 AD45 工作单明确要求的完整机器级字段：canonical input SHA、namespace、nonce/UUID、allocator generation、CAS token 和可信时间来源。它们记录了 perturbation、command、PID、UTC、exit、stdout/stderr hash、观察结果和 no-publish，但这组缺失字段使 collision/replay/CAS winner 唯一性和 clock 不参与 identity 的原始收据不可独立重放核对。产品顶层虽有部分 allocator 字段，不能替代每一项负控的 exact input receipt。

3. envelope 的 `negative_controls` 中，`wall_clock_rollback_future_skew.observed_result` 为 `AbsentFreshCandidateBindingEnvelopeV1 when freshness time evidence cannot close`，不是 result union 中的精确成员 `AbsentFreshCandidateBindingEnvelopeV1`。解释应放入独立字段，result 字段必须保持精确 union token；同样建议将 `failure_semantics` 保持精确的 `terminal_deferred`，把“identity unchanged and no publish”作为说明字段。receipt 列表中的 wall-clock result token 已是精确值，但 envelope 与 receipt 目前不一致。

因此本复核不能给 A 单 `pass_limited`。修复应以新的 AD45 产品版本完成并重新冻结 envelope/receipt hash；不得原地覆盖本次冻结输入，也不得删除或覆盖当前五份失败 raw。修复后必须由另一独立 Luna 重新复核全部五向量和新的 exact hashes。

## 五类负控的语义结论

从当前产品字段看，collision、replay/nonce reuse、CAS loser 和 AD42 seed misuse 都声明 `FailedFreshCandidateBindingEnvelopeV1` + `fail_closed`，wall-clock 控制声明 `AbsentFreshCandidateBindingEnvelopeV1` + `terminal_deferred`，五项均声明 `candidate_ref_published=false`。这些分类方向与合同一致；但上面的 raw hash、per-control receipt 字段和 wall-clock envelope token 缺陷阻止把它们当作闭合的独立机器证据。

当前记录的 exclusive-create/CAS、重放拒绝、winner/loser 语义、clock-independent identity 和 seed guard 没有把 candidate identity 或 declaration hash 伪造出来；本复核未观察到 hash 循环或 alias。结论仍只到软件合同复核，不能把这些字段升级为实际候选、物理或工程证据。

## 结论与保留项

当前 candidate identity/hash、declaration hash、present、T0、T1、T2、provider、mesh、solver、engineering、physical、search、R01–R10 均为 false，L4 credible count 为 0。AD45 A 不能在本 R1 后被接受或解锁 B；B-G1/B-G2 继续 blocked。规划 validator 的通过只证明文档/DAG，不能抵销上述 raw receipt 缺陷。

本复核产生的失败验证 stdout 已 append-only 保留在 `review/direct_validation_stdout.json`；没有 task-owned temporary artifact 需要清理，既有 dirty worktree 保持不变。
