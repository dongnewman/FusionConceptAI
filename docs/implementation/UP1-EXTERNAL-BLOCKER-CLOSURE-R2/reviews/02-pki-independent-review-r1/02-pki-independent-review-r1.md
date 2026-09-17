# UP1 R2 PKI chain independent attack review R1

## 结论

结论：`rework`。本地 TEST_ONLY/non-evidence 负例链路基本 fail-closed，但生产 profile 可在独立构造的有效链上返回 `valid_for_declared_scope`、`accepted_for_declared_scope`、`no_publish=false`，因此不能将此 slice 标为 production-ready。发现 3 个生产边界阻断项（弱 key、过期 receipt、receipt 时间未绑定 trusted time），以及 3 个 schema/约束缺口（RFC822 nameConstraints、额外 keyUsage、unknown/duplicate JSON）。

## 审计范围与复现

只读审计：

- `tools/up1_external_closure_r2/pki_chain/**`
- `test/up1_external_closure_r2/pki_chain/**`
- `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/02-pki-chain/**`

独立攻击脚本唯一写入本 review 目录：`attack_review.py`。所有证书、密钥和 receipt 在 fresh process 内生成；不联网、不读系统 trust store。

复现命令：

```text
$env:PYTHONDONTWRITEBYTECODE='1'; $env:PYTHONPATH='.'; python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/02-pki-independent-review-r1/attack_review.py
```

攻击进程 PID `103468`，Python `3.13.5`，started UTC `2026-09-16T17:55:54.249894+00:00`，exit `0`。原始输出见 `raw/attack.stdout.raw`，exit 见 `raw/attack.exit`，进程记录见 `raw/process.json`。

现有被审 fresh 测试也复核：`python -B -m unittest discover -s test/up1_external_closure_r2/pki_chain -p 'test_*.py' -v`，6 tests，exit `0`，既有 raw_fresh PID `102320`。该套测试只覆盖 6 个正/负例，未覆盖下述生产接受路径。

## 独立负例结果

按预期拒绝：错误 root signature、self-signed leaf、pathLen 超限、leaf `basicConstraints.ca=true`、AKI/SKI mismatch、unknown critical extension、EKU mismatch；生产 root 缺失返回 `typed_absence/trust_anchor_absent/terminal_deferred/no_publish=true`。receipt 签名变异的既有测试同样通过。

以下是“应拒绝但实际接受”的结果：

| case | 实际结果 | 级别 | 代码位置/原因 |
|---|---|---:|---|
| `production_rsa_1024_weak_key_accepted` | `valid_for_declared_scope`, `production_candidate`, `no_publish=false` | P1 | `verifier.py:320-327` 只比较 profile 宣称的算法/位数，没有独立最低强度；1024-bit RSA 可被 profile 自洽地放行。 |
| `production_expired_receipt_fields_accepted` | 同上 | P1 | `verifier.py:375-382` 仅检查 `issued_at`/`expires_at` 存在，不解析、不比较 evaluation/trusted time；2000 年 receipt 被接受。 |
| `name_constraints_email_suffix_bypass` | TEST_ONLY `valid_for_declared_scope` | P1 | `verifier.py:284,292` 对 RFC822Name 使用裸 `endswith`；`attacker@notexample.com` 被当作属于 permitted `example.com`。 |
| `leaf_key_usage_extra_key_cert_sign_accepted` | TEST_ONLY `valid_for_declared_scope` | P2 | `verifier.py:240-244` 只要求 leaf `digital_signature`，不拒绝 leaf 上的 CA-only bits；`ca=false + keyCertSign=true` 被接受。 |
| `receipt_unknown_field_accepted` | TEST_ONLY `valid_for_declared_scope` | P2 | `verifier.py:334-342,375-391` 没有 receipt 字段 allowlist；未知字段可进入 canonical bytes 并被签名接受。 |
| `duplicate_json_keys_accepted` | TEST_ONLY `valid_for_declared_scope` | P2 | `_load_json` 直接 `json.loads`，无 `object_pairs_hook` 重复键检测；重复 `scope` 被静默折叠后照常验签。 |

`test_only_profile_forced_non_evidence` 的调用者显式给 `test_only=false` 但 profile id 为 `TEST_ONLY-W2-R1`，结果仍为 `valid_for_declared_scope`，但 `evidence_class=non_evidence`、`no_publish=true`。这没有造成 production 升级，安全结果是保守的；建议仍对 caller/profile mode 不一致直接 fail-closed，避免状态误读。

## 精确修复要求

1. **独立算法/强度策略（P1）**：不要把 `public_key_bits` 当作唯一策略来源。对生产 profile 固定允许集和最低强度（至少 RSA 2048，明确批准的 EC 曲线，Ed25519/Ed448；拒绝 DSA/弱 key）；检查证书签名 hash，拒绝 SHA-1/MD5 等弱算法；receipt 验签算法必须与 profile 的签名方案严格一一对应，而不是仅按 leaf key 类型分支。
2. **receipt 时间绑定（P1）**：严格解析 RFC3339/UTC 的 `issued_at`、`expires_at`，要求 `issued_at <= expires_at`，并要求 evaluation time（生产应为独立 trusted `gen_time`）落在区间内；receipt 过期、未来或 malformed 均 `fail_closed`。trusted-time `gen_time` 也必须解析并绑定到 receipt 时间窗口。
3. **RFC822Name 约束（P1）**：按 RFC 语义实现 mailbox/domain boundary；domain constraint `example.com` 仅匹配该域及 `*.example.com` 的合法边界，不匹配 `notexample.com`。补充 permitted/excluded mailbox、DNS、IP 的正负例。
4. **keyUsage 精确策略（P2）**：attestation leaf 除 `digitalSignature` 外拒绝 `keyCertSign`/`cRLSign` 等 CA-only bits；CA 证书则强制 `basicConstraints.ca=true` 与 CA bits 一致。
5. **JSON schema 防歧义（P2）**：使用拒绝重复键的 JSON decoder；对 receipt、profile、revocation、trusted_time、ledger 定义严格 allowlist/schema，unknown field 直接 `fail_closed`。canonicalization 只能作用于已通过 schema 的对象。
6. **mode 一致性（P2）**：调用者显式 `test_only=false` 时，TEST_ONLY profile 应返回 `signature_profile_unknown` 或专门 mode mismatch；保留 `non_evidence/no_publish` 保险。

## owned / actual / hashes / raw 核对

- `02-pki-chain/manifest.json` 中 7 个 source hash 与 fresh `python -B` 计算的 actual 全部相等；未发现 source ownership/hash 漂移。
- `02-pki-chain/hashes.json` 中 4 个 `raw_fresh/*` hash 与 actual 全部相等；既有 raw test exit 为 `0`，stderr 记录 6 tests OK。
- 本复核新增 raw 证据均位于本 review 目录；`raw/attack.exit=0` 表示攻击 harness 完成，不表示被审 verifier 合格。接受路径的判定以 `raw/attack.stdout.raw` 中的 machine result 为准。

## 证据边界

本复核只证明本地软件 verifier 的接受/拒绝行为；没有生产 trust root、外部 attestor、真实 revocation、可信签名时间服务或 authority publication。修复前，父目标应保持 `rework`/`no_publish`，不能把 TEST_ONLY 结果或本次生产伪造链当作外部证据。
