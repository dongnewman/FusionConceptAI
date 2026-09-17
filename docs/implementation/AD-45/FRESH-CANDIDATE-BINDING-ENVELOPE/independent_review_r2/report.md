# AD-45 FreshCandidateBindingEnvelopeV1 independent review R2

日期：2026-09-15  
复核者：different `gpt-5.6-luna/high` independent reviewer  
结论：`pass_limited`  
验收：`accepted=true`  
范围：修复后 AD45 A 单的有限软件合同、最终负控 raw、内容寻址收据和声明边界。

本复核重新读取共同合同、AD45 prerequisite audit 及 R1 失败报告、AD42 W0/W2R1、AD43 轴合同、修复后的两件产品、五份最终 `_r2` raw 和五份旧 attempt1 raw。没有修改两件产品、任何 archive raw、源码、测试、fixture、核心目录或 `task_manifest.json`；只写入本目录的 R2 report、manifest 和 `review/` raw sidecars。

## 冻结产品与身份连续性

修复后产品逐字节匹配本次冻结值：

- `fresh_candidate_binding_envelope_v1.json`：9612 bytes，SHA-256 `17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc`。
- `envelope_receipt.json`：5776 bytes，SHA-256 `adf9caefb31398c4cf4fd04dc443fb8f409d7485e1ee04f125a28e3b427a9b64`。

两件产品均为 sorted compact canonical UTF-8、无末尾 LF；receipt 的 `sha256` 和 `content_sha256` 都闭合到 envelope exact bytes。R1 的 common ref、namespace、allocation UUID 和 nonce 保持不变：common ref 仍是 `QualifiedRefV1`/`v5`，namespace 是 AD45 固定任务专属 namespace，UUID 为 v4 形状，nonce 为 64 个十六进制字符。fresh allocator 仍记录 exclusive create、generation `1`、CAS token、nonce non-reuse、OS cryptographic random source，wall clock 仅作 receipt metadata，identity inputs 仍只有 namespace、UUID 和 nonce。

G1/G2 public refs 逐字段匹配 AD42 W0 和 W2R1 冻结输入。G2 仍是 `GenomeContractRef`，`qualified_ref_alias=false`，`source_type_preserved=true`；没有把 G2 合同 ref alias 成 common `QualifiedRefV1`。AD43 四类输入的路径、字节数和 hash 均重新闭合。fresh UUID、nonce 和 namespace 没有出现在 AD42 seed、W0/W2R1 或 AD43 输入中；seed 仍是 read-only negative-control，未作为熵源或派生输入。

## 五项最终负控

receipt 只引用五份最终 `_r2` raw，旧五份 attempt1 raw 仍 append-only 保留。每份最终 raw 都重新核对了：

- canonical perturbation input SHA-256 和 64 字符格式；
- 明确的 `artifact_hash_object=envelope_product_exact_bytes`，artifact SHA-256 与 envelope exact bytes 相等；
- namespace、allocation UUID、nonce、allocator generation、expected generation、CAS token；
- `trusted_time_source=OS monotonic allocator sequence` 与 `wall_clock_role=receipt_metadata_only`；
- exact result-union token、failure semantics、no-publish、command、PID、UTC、stdout/stderr hashes；
- raw 文件自身的 bytes/SHA-256 与 receipt snapshot 一致。

四项控制 `uuid_nonce_collision`、`envelope_replay_nonce_reuse`、`concurrent_dual_write_cas_conflict` 和 `ad42_seed_misuse` 均为精确的 `FailedFreshCandidateBindingEnvelopeV1` + `fail_closed`。CAS 负控记录 expected generation `1`、loser 的不同 allocation 以及唯一 winner UUID/nonce；replay 与 collision 使用已提交 UUID/nonce/CAS 状态，不能发布新的 ref。clock 负控覆盖 rollback、future、timezone shift 和 untrusted timestamp，保持 monotonic allocator sequence 与 UUID/nonce 不变，精确结果为 `AbsentFreshCandidateBindingEnvelopeV1` + `terminal_deferred`；说明已单列，wall clock 没有进入 ref identity。五项的 `published_candidate_ref` 均为 false。

产品顶层的 negative-control 条目现在都使用精确 result token；receipt 只保留 `_r2` final raw 的 references，避免把旧失败收据混入最终证据。旧 attempt1 raw 没有被删除或覆盖。

## 独立运行证据

直接 JSON/hash/path/control 核验使用 `D:\Users\Newman\anaconda3\python.exe` / Python 3.13.5，PID `48072`，UTC `2026-09-15T11:59:29.680322+00:00` 至 `2026-09-15T11:59:29.703237+00:00`，exit `0`；59/59 项通过。原始 stdout 和零字节 stderr 已保存到 `review/`。

规划校验使用 Python 子进程 PID `86828`（wrapper PID `69348`），UTC `11:59:40.607812+00:00` 至 `11:59:41.075644+00:00`，exit `0`：31 markdown、497 relative links、39 tasks、DAG acyclic。作用域 `git diff --check` 子进程 PID `85116`（wrapper PID `87856`），UTC `11:59:49.839570+00:00` 至 `11:59:49.900020+00:00`，exit `0`，stdout/stderr 均为空。规划和 diff 检查只作为工程完整性辅助证据，不替代负控与物理证据。

归档的 `validation_summary_r2.json` 也记录 23/23 direct checks、5 份 final raw、5 份 attempt1 保留、artifact hash 重算、canonical input SHA 和 allocator/time 字段完整；其 summary 自身不参与 envelope/receipt 内容 hash，避免循环。

## 结论与信用边界

R1 指出的三项阻塞已在新冻结版本中闭合，本 R2 对 AD45 A 单给出 `pass_limited`。这只接受有限的软件 binding-handle 和负控 receipt scope，不创建或认可最终 candidate identity。candidate identity/hash、declaration hash、present、T0、T1、T2、provider、mesh、solver、engineering、physical、search、R01–R10 均保持 false，L4 credible count 为 0。B-G1/B-G2 仍需等待 W3-A、独立 source/identity 输入和 G2 mapping，不因 A 单 R2 通过而自动派发或获得物理信用。
