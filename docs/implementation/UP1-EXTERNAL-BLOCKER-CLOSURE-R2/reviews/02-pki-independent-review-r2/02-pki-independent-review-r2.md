# UP1 R2 PKI chain independent review R2

## 结论

结论：`rework`。返工已关闭 R1 的 P1/P2 接受路径，独立重跑与新增边界均按预期拒绝；但生产 profile 仍可声明 `RSA-SHA1` 而得到 `valid_for_declared_scope`、`production_candidate`、`no_publish=false`。因此当前不能 `pass_limited`。

## 范围与证据

只读审计：

- `tools/up1_external_closure_r2/pki_chain/**`
- `test/up1_external_closure_r2/pki_chain/**`
- `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/02-pki-chain/**`

唯一写入本目录：`attack_review.py` 与 `raw/**`、本报告；r1 目录未覆盖。

独立攻击命令使用 fresh Python：

```text
$env:PYTHONDONTWRITEBYTECODE='1'; $env:PYTHONPATH='.'; python -B reviews/02-pki-independent-review-r2/attack_review.py
```

PID `39344`，started UTC `2026-09-16T18:18:00.186953+00:00`，exit `0`；输出在 `raw/r2-boundary.stdout.raw`。R1 全部攻击以当前 verifier fresh 重跑，PID `15884`，exit `0`，输出在 `raw/r1-rerun.stdout.raw`。`raw/hashes.json` 中 6 个 raw/process/exit 文件 actual 与 owned 全部相等。

当前被审测试 fresh evidence：12 tests，PID `73488`，exit `0`，`02-pki-chain/raw_fresh_r2/`；其 `hashes.json` 四项 actual/owned 全部相等。当前 manifest 的 7 个 source hash 也全部与 fresh `python -B` actual 相等，未发现 ownership/hash 漂移。

## R1 全量重跑

错误 root、自签 leaf、pathLen 超限、leaf basicConstraints、AKI/SKI mismatch、unknown critical、EKU mismatch、过期 receipt、CA-only leaf keyUsage、unknown/duplicate JSON、TEST_ONLY caller/profile mismatch、生产 root typed absence、RSA 1024、production 过期 receipt、RFC822 notexample 均返回 `fail_closed` 或预期 `typed_absence`，且 `no_publish=true`。这确认 R1 暴露的接受路径已关闭。

## R2 新增边界结果

| case | 实际结果 | 判定 |
|---|---|---|
| `rsa_2048_production_baseline` | production candidate，`no_publish=false` | 正常正例 |
| `rsa_1024_production` | `fail_closed/signature_profile_unknown` | 通过 |
| `ec_p256_production_baseline` | production candidate，`no_publish=false` | 正常正例 |
| `ec_secp256k1_unapproved_curve` | `fail_closed/signature_profile_unknown` | 通过 |
| `profile_sha1_weak_hash` | production candidate，`no_publish=false` | **残留阻断** |
| receipt issued>expires、malformed、trusted genTime 越界/非法 | `fail_closed` | 通过 |
| RFC822 exact mailbox、合法 subdomain | TEST_ONLY non-evidence valid | 正常正例 |
| RFC822 `notexample.com` | `fail_closed/name_constraints_violation` | 通过 |
| leaf `keyCertSign`、`cRLSign` | `fail_closed/key_usage_invalid` | 通过 |
| root/intermediate unknown critical | `fail_closed/critical_extension_unknown` | 通过 |
| profile/receipt/trust_anchor/revocation/trusted_time/ledger unknown field | `fail_closed/canonical_bytes_mismatch` | 通过 |
| profile/receipt duplicate JSON | `fail_closed/canonical_bytes_mismatch` | 通过 |
| 两方向 TEST_ONLY caller/profile mismatch | `fail_closed/signature_profile_unknown` | 通过 |

## 残留问题：P1

### P1 — 弱 hash 算法标识仍可进入生产接受路径

复现 `profile_sha1_weak_hash` 将生产 profile 的 `algorithm` 设为 `RSA-SHA1`，证书与 receipt 使用当前 RSA/SHA-256 正常密码学材料；结果为：

```text
status=valid_for_declared_scope
resolution=accepted_for_declared_scope
evidence_class=production_candidate
no_publish=false
```

原因：`verifier.py:383-398` 只用 `alg.startswith("RSA")` 判断算法族和 key 类型，`RSA-SHA1` 不会被拒绝；`verifier.py:439-449` 又固定用 SHA-256 验 receipt，导致 profile 的弱 hash 声明与实际验签算法不一致且未被检测。现有 `_check_production_key_strength` 只检查证书真实 signature hash，不能替代 profile policy 校验。

精确修复：将生产算法改为 closed enum（例如 `RSA-PKCS1-SHA256`、明确批准的 ECDSA-SHA256/384、Ed25519/Ed448），显式拒绝名称或 digest 中的 SHA-1/MD5/MD2；将 profile digest、证书 signature hash、receipt verifier 三者绑定，任何不一致返回 `signature_profile_unknown`，并增加 `RSA-SHA1`、真实 SHA-1 证书/receipt 的负例。

## 评审判定

当前无新的 P2；但仍有上述 P1，故判定必须是 `rework`。修复该 profile/hash policy 后，需保留本 R2 全量攻击作为回归，并重新生成 source/raw/process/hash receipts。即使 R2 的 TEST_ONLY 正例通过，也只能说明本地软件与 non-evidence 边界，不能关闭生产外部 trust root、真实 revocation、可信时间或 authority publication 缺失。
