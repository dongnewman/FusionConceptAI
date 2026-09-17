# UP1 外部阻塞 W2：信任链、吊销、可信时间与防重放合同

状态：`preparation_only`，R1 为针对独立复核 P1/P2/P3 findings 的合同修复。旧版本七文件内容不删除；本次变更说明、旧哈希和新哈希由 `manifest.json` 的 `repair_history` 保留。本目录是 UP1 外部输入闭包的验证准备，不是 AD，不产生生产 CA、密钥、证书、签名、时间戳、OCSP/CRL 响应或 authority。

## 1. 边界与现状

fresh S3 当前为 `typed_absence / terminal_deferred / no_publish`：trust root、独立 attestor、签名链、验证器、吊销来源、可信时间、防重放和 source-version binding 均未提供。AD55 的 F0/S2 是 source-stage present；AD56 是 Git-filter source locator 软件修复；两者均不是可信签名或 B00/B04 证据。`src/` 与 `test/` 不在本工单写入范围。

claim ceiling 固定为 `preparation_only`，不授予 T0、authority recheck、T1、T2、aggregate、UP1、B00、B04、R01–R10 或 L4 信用。39 节点 DAG 不变。

## 2. 信任路径合同

验证对象是签名覆盖的 canonical receipt bytes，而不是路径、文件夹、runner exit 或本地 hash 的单独陈述。机器验证顺序必须先完成 canonical digest 与 scope/source-version 结构绑定，再构链。路径必须是：

`trust_anchor(root) → intermediate CA (可选但若存在必须校验) → leaf attestor certificate → signature over canonical receipt`。

Root：必须由项目外部责任方以带指纹、版本、用途、有效期、轮换/撤销政策的带外渠道提供；测试根只能存放在明确的 fixture 范围，名称含 `TEST_ONLY`，不能进入默认信任库。Root 不得由被验证的 source 作者自签后自授信。

Intermediate：issuer/subject 链接、AKI/SKI、basicConstraints `CA=TRUE`、pathLen、keyUsage `keyCertSign,cRLSign`（若发布 CRL）、有效期、名称约束和 policy OID 必须满足 root policy。超出 nameConstraints、未知 critical extension、弱/禁用算法均 fail-closed。

Leaf attestor：`CA=FALSE`；keyUsage 至少 `digitalSignature`；EKU 必须包含项目声明的 attestation signing OID（不得以 serverAuth/clientAuth 代替）；issuer 必须是已验证的 intermediate/root；subject/SAN 必须绑定独立 attestor 身份与 scope；policy OID、有效期、key strength/algorithm、name constraints、revocation 状态均须在 evaluation time 通过。私钥永不进入仓库、receipt 或测试 fixture。

Path validation 必须按 `trust_path_requirements.json.validation_order` 的 Stage 0–8 执行：先校验 schema/profile、canonical bytes/digest、scope/source-version/replay 结构；然后才按 root→leaf 构链并检查签名、issuer、AKI/SKI、basicConstraints、keyUsage/EKU、nameConstraints、policy OID、有效期、算法与 critical extension，再检查吊销和可信时间，最后检查 replay ledger。任何顺序跳过、unknown 或不完整都不能发布 present。

信任锚来源与轮换：责任方必须提供带外来源、root fingerprint、授权范围、effective/not-after、旧根撤销/过渡窗口、key rollover 交叠规则和独立确认。仅换 root/key/cert 或 policy 即视为新的输入 fingerprint；旧 receipt 不自动迁移。轮换期间必须以明确的双锚过渡策略验证，过期旧锚不得作为新验证锚。

算法与 profile 不得使用 placeholder 冒充授权。当前唯一允许生成 fixture 的 profile 是 `TEST_ONLY-W2-R1`：receipt digest `SHA-256`，签名算法 `Ed25519`，公钥 256-bit，receipt 签名编码为固定 64-byte raw signature，测试 EKU OID `1.3.6.1.4.1.55555.1.1`，测试 policy OID `1.3.6.1.4.1.55555.1.2`，canonical encoding 为 UTF-8、RFC 8785 风格 deterministic JSON（排序键、无空白、无终止 LF）。该 profile 的每个证书、根和数据都必须带 `TEST_ONLY` 标记且仅可用于 fixture。生产 profile 的算法、强度、签名编码、EKU OID、policy OID、退役规则目前是独立 external input，状态为 `typed_absence`；字段为 null/absent 时验证器必须停止，不能把测试 OID 或字符串 `project_attestation_signing_oid` 当生产值。

## 3. 吊销、时间与重放

吊销合同见 `revocation_time_replay_contract.json`。在线 OCSP/离线 CRL 都必须绑定 issuer、serial、thisUpdate、nextUpdate、producedAt、responder/签名链和查询对象；无法取得、过期、未知、响应签名无效或状态不确定均为 `revocation_status_unavailable`，除非责任方预注册并满足明确离线策略。`good` 不是永久授权，必须在声明的 as-of 时间和 freshness window 内成立。

可信时间必须来自独立可验证 RFC 3161 TSA 或等价的带签名时间服务，覆盖 receipt digest、nonce、policy、genTime，并检查 TSA chain/revocation/有效期和本地允许偏差。OS clock、文件 mtime、日志时间、Git commit 时间只能是观测字段，不能单独成为 trusted time。

每个验证请求须有唯一 `verification_id`、随机 nonce/challenge、source/candidate scope、sequence、issued_at/expiry 和 idempotency key；签名 receipt 必须把这些字段纳入 canonical bytes。验证器应拒绝 nonce/sequence 已消费、跨 scope、过期、未来超窗、重复 idempotency key 但内容不同、同一 receipt 在 replay window 外再次提交。相同 bytes+相同 idempotency key 的安全重试只允许返回同一结果，不得产生第二次 authority。

## 4. Typed absence 与恢复

每项缺失必须输出稳定的 `typed_absence`，字段至少包括 `input_id,current_state,responsible_party,authoritative_source,recovery_condition,expiry_or_revocation_semantics,validation_method`。未知不能默认为 valid、local、trusted 或 no-revocation。输入 fingerprint 不变时不得重跑 S3、不得新建同义 AD；只有真实输入变化才可创建下一次 bounded attempt，并保存新的 input fingerprint。

当前缺失责任方、权威来源和恢复条件在 `external_input_register.json` 中逐项列出。该 register 的 canonical fingerprint 只覆盖完整 11 项 `inputs`，并加入本合同 schema/revision 与 trust-path profile schema/revision；对象键递归按 UTF-8 字节升序排序，数组按声明顺序（input records 再按 `id` 升序），UTF-8、无空白、无终止 LF、数字采用 JSON shortest form，fingerprint 为 canonical bytes 的 SHA-256。fingerprint 字段本身不进入 preimage。当前 fingerprint 记录于 `external_input_register.json.canonical_fingerprint`；fingerprint 不变不得重跑 S3、不得创建同义 AD，只有真实输入变化且产生新 fingerprint 才允许 bounded fresh attempt。

authority_decision 是封闭枚举：`unknown`、`unavailable`、`rejected`、`accepted_for_declared_scope`。未知值、缺失值或任何未列出的字符串均为 `fail_closed`；`accepted_for_declared_scope` 也不等于 T0 或最终 authority。恢复后仍须独立 Luna 复核；Sol/high 才能裁决是否允许正式 T0 链，且本合同本身不解锁任何正式门。

## 5. Fail-closed taxonomy 与验证顺序

稳定错误码：`trust_anchor_absent`、`trust_anchor_mismatch`、`certificate_chain_absent`、`certificate_signature_invalid`、`certificate_expired`、`certificate_revoked`、`revocation_status_unavailable`、`eku_missing`、`key_usage_invalid`、`name_constraints_violation`、`policy_oid_mismatch`、`critical_extension_unknown`、`signature_profile_unknown`、`canonical_bytes_mismatch`、`receipt_digest_mismatch`、`trusted_time_absent`、`timestamp_invalid`、`timestamp_expired`、`nonce_absent`、`nonce_replayed`、`sequence_invalid`、`idempotency_conflict`、`replay_window_expired`、`scope_binding_mismatch`、`source_version_binding_absent`、`source_version_binding_mismatch`、`input_fingerprint_unchanged`、`verifier_absent`。

建议顺序：

1. 读取 schema/profile 和 canonical bytes；拒绝未知字段、重复字段、非确定性编码与 digest 不符。
2. 检查 receipt scope、source/version/hash、verification_id、nonce、sequence、expiry 和 idempotency 结构。
3. 构建并验证 root/intermediate/leaf 路径、policy、EKU、keyUsage、name constraints、算法与 critical extensions。
4. 验证 leaf 对 canonical receipt 的签名。
5. 验证 CRL/OCSP as-of 状态和 freshness；验证 TSA/RFC3161 或等价可信时间。
6. 检查 replay ledger（nonce、sequence、idempotency、window）和独立性/scope。
7. 仅当全部通过时返回 fixture-only `valid_for_declared_scope`；任何缺失返回 typed absence/deferred，任何矛盾返回 fail-closed。

## 6. Fixture-only 验证命令模板

以下只是未来实现者的命令模板，不是本次执行，也不允许使用生产材料：

```text
python validator_fixture_only.py --fixture TEST_ONLY/trust_chain \
  --receipt TEST_ONLY/receipt.canonical.json \
  --anchor TEST_ONLY/ROOT_TEST_ONLY.pem \
  --chain TEST_ONLY/intermediate_TEST_ONLY.pem \
  --leaf TEST_ONLY/leaf_TEST_ONLY.pem \
  --revocation TEST_ONLY/revocation_fixture.json \
  --timestamp TEST_ONLY/timestamp_token_fixture.tsr \
  --replay-ledger TEST_ONLY/replay_ledger.json \
  --profile TEST_ONLY/profile.json
```

validator 必须在 fixture manifest 中证明所有根、私钥替代物、证书、响应和时间 token 均为 `TEST_ONLY`；不得联网取得生产 trust、不得写默认 trust store、不得输出 authority。测试至少覆盖 valid fixture、每一类缺失、过期/撤销、错误 policy/EKU/keyUsage/name constraint、canonical mutation、wrong scope、nonce duplicate、sequence rollback、idempotency conflict、replay-window expiry，并保存 raw/PID/UTC/exit/hash（若实际执行）。

## 7. 独立复核点

不同 Luna 必须复核：路径构造是否真的检查每个字段；测试根是否绝不冒充生产锚；CRL/OCSP fail-closed 是否区分 revoked 与 unavailable；trusted time 是否独立于 OS clock；nonce/sequence/idempotency 是否覆盖 canonical bytes；scope/version/hash 是否绑定 AD55/AD56 的 dirty executor 区分；是否产生任何未授权 authority 或门信用。Sol 复核范围和 claim ceiling，失败原件不可删除。
