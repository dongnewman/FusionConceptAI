# UP1 W2 trust-chain independent review

结论：`rework_required`。Claim ceiling 仍为 `preparation_only`；没有 trusted
attestation、source authority、T0/T1/T2、UP1、B00/B04、R01–R10 或 L4 信用。

## 只读审查范围与完整性

审查对象是
`docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/trust_chain/` 的七个
文件。七个文件的 JSON 均成功解析且无重复键；实际目录集合与输入
`manifest.json.outputs`、`cleanup_inventory.json.owned_products` 一致。每个
输入 SHA-256 已记录在本目录 `manifest.json`，没有生成密钥、证书、签名、
CRL/OCSP 响应、时间戳或生产 trust material，也没有改动输入、源码、测试或
AD 文件。

当前仓库状态核对为 39 个任务节点、credible candidate count `0`、R01–R10
全开、B00/B04 全开；fresh S3 仍是
`typed_absence / terminal_deferred / no_publish`。AD55 仍仅 source-stage
present，AD56 仍仅 Git locator 软件有限接受。指定的 T0→recheck→T1→T2、
aggregate 与正式 B00/B04 顺序未被本 review 改写。

## 对抗性检查

信任路径合同正确列出了 root→intermediate（可选）→leaf→receipt signature
以及 issuer/AKI/SKI、basicConstraints、keyUsage、EKU、nameConstraints、
policy OID、算法、critical extension、有效期和 source/scope binding。叶证书
明确要求 `CA=FALSE`、`digitalSignature` 与项目 attestation EKU，且测试根不得
冒充生产根。CRL/OCSP 的 issuer/serial/thisUpdate/nextUpdate/producedAt、
revoked/unknown/unavailable 语义、RFC3161 digest/nonce/policy/genTime、
nonce/challenge/sequence/idempotency/replay window、轮换/撤销和旧收据不可
静默迁移均有合同字段。责任方与恢复条件也在 external input register 中
逐项列出。

但 adversarial review 发现以下阻塞：

1. P1 `validation_receipt.expected_absence` 只有 7 个聚合标签，而
   `external_input_register` 有 11 个独立缺失输入；缺少逐项 lossless 映射。
2. P1 规定“输入 fingerprint 改变才允许重试”，却没有冻结当前完整 absence
   register 的 canonical fingerprint 或确定性计算规则，无法机械阻止重复
   S3/同义 AD。
3. P1 `trust_path_requirements.fail_closed_on` 把 unavailable revocation
   列为 fail-closed，但 revocation contract 要求它是
   `revocation_status_unavailable / typed_absence / terminal_deferred`；两者都
   no_publish，却不能混用状态分类。
4. P2 的 `path_order` 没有把 canonical bytes/digest、scope/source-version
   结构作为 root 构链前的明确阶段；正文虽然要求先做，机器化顺序仍不完整。
5. P2 source-version binding 只说“六份 HEAD owners + 三份 AD56 dirty
   executors”，未列出确切路径、HEAD blob/OID、working-tree hash 和版本
   区分，无法完成无损签名绑定。
6. P2 EKU/policy/algorithm 仍为 placeholder 或 absent，没有具体允许算法、密钥
   强度、编码、policy OID 与退役规则；在输入补齐前必须继续 typed absence。
7. P3 authority channel 的 `authority_decision` 仍是无约束 placeholder
   string，未来应使用封闭枚举，未知值必须 fail-closed。

详细证据、严重度和修复要求见 `findings.json`。这些问题不改变当前缺失事实，
但阻止把本准备合同当作完整 W2 闭包或允许后续信任链实现。

## 裁决与恢复条件

本次独立复核不修改原件，不删除失败或历史材料，不运行外部信任验证。应先
修复 P1/P2 合同并由另一位 Luna 重新独立复核；只有真实外部输入变化产生新的
canonical fingerprint，才可开展 bounded fresh S3。恢复包至少需包含带外 root
指纹和策略、完整链/leaf 身份、具体 EKU/keyUsage/policy/算法 profile、签名
canonical receipt、独立 verifier、CRL/OCSP、可信 RFC3161 时间、replay ledger
及完整 source-version owner inventory。届时仍须按现有 DAG，由 Sol 决定是否
允许正式 T0；本 review 不授予任何正式门。
