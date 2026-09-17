# 验收记录

范围仅为 `tools/up1_external_closure_r2/revocation_time_replay/**`、
`test/up1_external_closure_r2/revocation_time_replay/**` 与本证据目录。

实现覆盖（R4 返工后）：确定性 canonical digest；严格 TEST_ONLY 签名门；CRL/OCSP 抽象的 good/revoked/unknown/
unavailable/stale；RFC3161/等价 signed-time imprint、链/撤销、策略和 skew；nonce/challenge、
scope、source-version、连续 sequence、idempotency、持久化 HMAC/hash ledger、显式独立 trusted key、
跨进程锁/CAS 和 freshness window。Windows trusted key 真实调用 PowerShell 7 `Get-Acl`/SDDL，校验 owner、
DACL、继承宽权限和宽泛主体；逐层拒绝 parent/final path reparse/Junction。认证后的 ledger 还做 entries 全局 nonce/idempotency/source+sequence
唯一性、canonical scope/source 绑定和 indexes 双向 exact 校验；duplicate/nonfinite/schema 均协议化 fail_closed。

`python -B -m pytest -q test/up1_external_closure_r2/revocation_time_replay/test_revocation_time_replay.py`
新鲜运行通过 13 个测试（另有 1 个 Windows symlink 环境限制 skip）。测试覆盖正例、外部 typed absence、revoked/unknown/stale/invalid、nonce
duplicate、跨进程 replay、认证后 ledger 语义篡改、sequence gap/idempotency、canonical mutation、重复/未知
字段、非有限数、严格 profile/type/optional-time 和 CLI 正负 exit；0644 等价宽 ACL 拒绝、restricted key
通过、父目录 Junction/reparse 逃逸拒绝。ACL owner/DACL 判定已抽为纯函数且 provider 可注入，NetworkService
foreign owner、malformed/unsupported provider 均有明确回归。ACL 检查方法和原始结果记录在 repair_r2 receipt/raw 中。

需 SeRestorePrivilege 的 foreign-owner 动态脚本已准备但本轮 `not_executed/test_scope_deferred`；保留
`icacls /setowner` 权限 1307 作为待授权环境命令，不宣称动态通过。

边界：这是离线抽象 receipt 的软件证据，不是生产 CA/OCSP/CRL/TSA、真实可信时间、外部
attestor authority、B00/B04、UP1 或 R01–R10 证据；必须由外部责任方提供并独立验证真实信任
根、证书链、吊销源和时间服务后，才能进行正式复核。
