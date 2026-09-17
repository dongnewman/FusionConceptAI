# UP1 R2 PKI chain independent review R3

## 结论

结论：`pass_limited`。本轮没有发现 P1/P2。R2 残留的弱 hash profile 接受路径已关闭；R1、R2 全量攻击与本轮新增算法/OID/hash 边界均按预期拒绝，允许算法正例按预期通过。该结论仍只覆盖本地软件 verifier 和 TEST_ONLY non-evidence 边界，不等价于生产外部 trust root、真实 revocation、可信时间或 authority publication 已具备。

## 范围、所有权与复现

只读审计：

- `tools/up1_external_closure_r2/pki_chain/**`
- `test/up1_external_closure_r2/pki_chain/**`
- `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/02-pki-chain/**`

唯一写入本目录 `reviews/02-pki-independent-review-r3/**`；未覆盖 r1/r2 或任何被审件。三个 fresh Python `-B` 进程：

- R1 全量重跑：PID `87492`，exit `0`，`raw/r1-rerun.*`
- R2 全量重跑：PID `110376`，exit `0`，`raw/r2-rerun.*`
- R3 算法/OID/hash 补充：PID `98612`，exit `0`，`raw/algorithm.*`

R3 现行测试 fresh evidence：16 tests，PID `91884`，exit `0`，`02-pki-chain/raw_fresh_r3/`。R3 raw 9 项的 actual/owned hash 全部匹配；既有 raw_fresh_r2/raw_fresh_r3 及 manifest source hashes 也全部匹配（7 个 source hash、各自 4 个 fresh raw hash）。

## R1/R2 全量回归

R1 的错误 root、自签 leaf、链顺序/pathLen、basicConstraints、AKI/SKI、unknown critical、EKU、过期 receipt、CA-only keyUsage、unknown/duplicate JSON、TEST_ONLY mode mismatch、生产 trust root 缺失、RSA 1024、RFC822 notexample 等 16 项在当前 verifier 中全部按预期返回 `fail_closed` 或 `typed_absence`，并保持 `no_publish=true`。

R2 的 RSA 2048 与 ECDSA P-256 production 正例保持 `production_candidate/no_publish=false`；RSA 1024、未批准曲线、时间边界、各层 unknown/duplicate 与 mode mismatch 均拒绝。R2 残留 `RSA-SHA1` profile 现返回 `signature_profile_unknown/no_publish=true`。

## R3 新增边界

| 类别 | 结果 |
|---|---|
| Ed448 production allowed set | `valid_for_declared_scope`, `production_candidate`, `no_publish=false` |
| RSA certificate SHA-384 instead of SHA-256 | `fail_closed/signature_profile_unknown` |
| profile algorithm `rsa`, `RSA-SHA256`, `RSA-PKCS1v15-SHA256`, `Ed25519`, `ed448`, `ECDSA-SHA256` | 全部 `fail_closed/signature_profile_unknown` |
| profile algorithm `RSA-SHA1`, `RSA-MD5`, `RSA-MD2`, `UNKNOWN` | 全部 `fail_closed/signature_profile_unknown` |
| receipt `algorithm`/`signature_algorithm` mismatch | `fail_closed/signature_profile_unknown` |
| profile `algorithm`/`signature_algorithm` mismatch | `fail_closed/signature_profile_unknown` |

Ed25519 已由 TEST_ONLY 正例覆盖，RSA/ECDSA P-256 由 R2 production 正例覆盖，Ed448 由本轮独立 production 正例覆盖；未批准 EC 曲线与 RSA 1024 继续拒绝。证书实际签名 hash/OID 与 profile policy 的 mismatch 由 `rsa_sha384_certificate_hash` 负例拒绝。

## 关键核对点

- `_profile` 对生产 algorithm 使用 `ALLOWED_ALGORITHMS` closed enum，并拒绝大小写/别名/弱 hash 拼写；profile digest 非 SHA-256 也拒绝。
- `_check_certificate_algorithm` 对 root/intermediate/leaf 全层检查实际 signature hash 与 signature OID；RSA/ECDSA 必须 SHA-256 及对应 OID，Ed25519/Ed448 必须对应 EdDSA OID。
- `_verify_receipt` 对 profile、receipt 的 algorithm 与 signature_algorithm 做精确一致性检查，并按四类允许算法选择验签实现。
- 生产 RSA 最低 2048 bit、EC 曲线白名单、Ed25519/Ed448 允许集、SHA-1/MD5/MD2 证书 hash 拒绝均得到独立边界结果。

## 评审判定与边界

没有 P1/P2，因此本轮判定 `pass_limited`。`valid_for_declared_scope` 的 production candidate 仅证明本地 verifier 接受满足声明 profile 的密码学材料；没有生产 trust root、外部 attestor、真实 revocation、可信签名时间服务或 authority publication，不得将 TEST_ONLY 或本地生成材料升级为外部证据。
