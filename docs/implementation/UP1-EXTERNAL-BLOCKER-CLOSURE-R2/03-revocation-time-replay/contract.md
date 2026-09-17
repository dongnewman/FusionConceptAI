# UP1 外部阻塞补充 R2：撤销、可信时间与防重放

状态：`implemented_fixture_only_repair_r4`；claim ceiling：`TEST_ONLY non_evidence`。
本组件只验证抽象 CRL/OCSP、RFC3161/等价时间与 replay-cache receipt，不联网、不读取
OS clock/file mtime/Git time、不写 trust store、不生产证书、密钥、签名、authority 或门信用。

## 验证顺序与状态

1. 以递归排序键、无空白、UTF-8、无终止 LF 的确定性 JSON 计算 receipt SHA-256；canonical
   bytes、声明 digest 或签名覆盖不一致为 `fail_closed`。
2. 检查 `verification_id`、`nonce`、`challenge`、scope、source/source_version、sequence、
   issued/expiry、idempotency key。缺少这些结构不是外部不可用，按错误码 `fail_closed`。
3. 要求明确的 TEST_ONLY attestor signature outcome；production profile 或无签名不能被当成
   valid。
4. 只接受显式的 CRL/OCSP receipt abstraction：`available` 必须是 bool，且 nested object
   字段闭集；issuer/serial/thisUpdate/nextUpdate、绑定和签名、good/revoked/unknown 及 freshness。来源 unavailable/缺字段/无法信任是
   `typed_absent/terminal_deferred`；revoked、unknown、stale 是 `fail_closed`。
5. 只接受带签名、策略、digest/messageImprint、链和撤销结果的 RFC3161 或等价时间 receipt。
   `genTime` 是唯一 as-of basis；缺失外部 receipt 为 typed absence，伪造/失效/过期/错绑为
   fail closed。OS 时钟永不作裁决。
6. replay window 必须有正、有限 duration、signed-receipt basis 和持久化 authenticated ledger。
   ledger 使用显式传入、独立的 trusted key file（不在 ledger 目录自动生成、不由 ledger 路径派生），
   key/ledger/lock 拒绝 symlink/reparse，并逐层检查 parent 与 final path；Windows 实际调用 PowerShell
   7 `Get-Acl`/SDDL 检查 owner 仅当前用户/SYSTEM/Administrators，拒绝 Everyone/Users/Authenticated
   Users 等宽泛 Allow ACE 及其继承宽权限；POSIX 使用 owner/permission 检查。若 ACL 方法不可用为
   `typed_absent/unsupported`，绝不放行。使用 HMAC authentication
   tag、state hash、跨进程 lock 和 atomic replace。调用方提交的 snapshot 不在允许 schema 内，不能重置状态。
   认证通过后还执行全局语义完整性：entries 的 nonce、idempotency key、source+sequence 必须 exact
   unique，scope/source 必须 canonical 且与双向 indexes exact；重复、未知字段、非有限数或索引不一致均为
   `ledger_corrupt/fail_closed`。nonce 在 scope 内唯一且跨 scope 不可复用；
   sequence 严格连续递增（gap 也 fail closed）；同 idempotency key + 同 canonical digest 的
   第二次请求标为 replayed/fail_closed；同 key + 不同 bytes、回退 sequence、超窗均 fail closed。

唯一成功结果是 `valid_for_declared_scope`，并保留 `trusted_as_of`、revocation 和更新后的
cache snapshot。所有输出都携带 `network_access=false`、`trusted_clock_basis=signed_receipt_only`
和 `claim_ceiling=TEST_ONLY non_evidence`。

## CLI

```text
python -B tools/up1_external_closure_r2/revocation_time_replay/cli.py --ledger path/to/ledger.json --key path/to/trusted.key < input.json
python -B tools/up1_external_closure_r2/revocation_time_replay/cli.py --ledger path/to/ledger.json --key path/to/trusted.key --input input.json
```

CLI 始终输出纯 JSON；valid 首次提交返回 exit 0，typed absence/fail closed/replayed 及
duplicate/nonfinite/schema/ledger-corrupt 返回 exit 2（含完整 status/labels，不能伪装为
`program_exception`），程序异常才返回 exit 1。缺少 production key 为 typed absence/no_publish；
TEST_ONLY fixture key 仅为 non_evidence。输入必须由调用方提供；实现不进行联网补全或自动信任。

Windows owner/DACL 判定由纯函数 `evaluate_windows_acl` 承载，并可注入 ACL provider；foreign owner
（例如 `S-1-5-20` NetworkService）及 malformed provider 输出是 `trusted_key_acl_invalid/fail_closed`，
provider 不可用是 `trusted_key_acl_unsupported/typed_absent`。需要 SeRestorePrivilege 的
`privileged_acl_fixture.ps1` 与 `icacls /setowner` 仅作为未执行的 test-scope-deferred 准备，不构成动态通过证据。
