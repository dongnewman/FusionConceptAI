# UP1 R4 外部输入合同：EHP-01..EHP-04

本目录只整理 R2/R3 已归档材料，不新增 owner、endpoint、候选、证书、签名或
receipt，也不作验收裁决。机器可读主合同是
[`external_input_contract_r4.json`](external_input_contract_r4.json)。

当前快照（仅对应 00 扫描列出的 2 个 root × 7 个相对路径及 R4 时间戳）：
`usable_external_inputs=0`，`typed_absent=26/26`，G1/G2/G3 均为
`typed_absent`，后继状态是 `terminal_deferred`，`publish=false`，
`formal_credit=none`，`authority_credit=false`。因此本文件是外部材料的收集合同，
不是 UP1/T0/T1/T2、B00/B04、R01-R10 或 parent-goal 的关闭记录。该快照是
限定范围内的“未观察到”，不等于远端或未列出的外部渠道全球不存在；未扫描渠道
继续按 `typed_absent`/`unknown` 处理，不得当作已验证输入。

## 使用边界

每条记录都列出：

- R2/R3 矩阵中的 `owner`。括号中的 `external; currently typed_absence` 是当前
  类型状态，不是已确认的人员或机构。
- `authoritative_channel`。当前 owner、endpoint、transport、authentication 和
  ack 全部为 `typed_absent`；不得从环境、系统证书库、历史材料或上下文推断。
- 必须收到并按原始字节保存的材料、签名覆盖范围及 receipt。具体机器字段见 JSON
  中的 `required_raw_bytes`、`required_signatures`、`required_receipts`。
- `current_typed_state`、`recovery_condition` 和禁止替代物。缺少外部事实保持
  `typed_absent -> terminal_deferred`；结构错误、冲突、外国绑定、过期、撤销、重放
  或 digest 不一致进入 `fail_closed`。在归一化 taxonomy 中，`typed_absence`
  是“范围内缺少必需材料/能力”的规范状态；`invalid` 是已收到但已证明
  不合法或矛盾的材料；`unverified` 是字节可用但外部 authority/独立验证尚未
  完成。三者不可互相降级。

原始接收必须是一个有序原子集：`EHP-01,EHP-02,EHP-03,EHP-04`。四包和 set receipt
重复并签名同一个 candidate/source/four-axis/G1-G2-G3/expected-context/trust/
verifier/replay 绑定；接收结论只能是 `accepted_all` 或 `rejected_all`，不能逐包提升。
R3 草案要求保存精确 UTF-8 raw bytes、SHA-256、packet-owner preimage、receiver
set-receipt preimage、independent-review preimage，以及原始 quarantine/CAS receipt。

## 外部权威状态转换

外部四轴材料的输入状态可以是 raw `EXTERNAL_ISSUED`（且
`provenance_class=external_issued`），但这只是待验证的外部声明，不是
`authority_credit`。只有在同一 candidate/source/run 上完成 pinned trust root、
完整链、签名、trusted time、revocation、freshness/replay、G2 绑定和独立复核后，
外部验证适配器才可派生 `externally_verified`；该派生状态必须保留 raw bytes、
验证 receipt 和全部 digest。`TEST_ONLY`、local fixture、local spool/CAS、系统
trust store、历史 receipt 或本地产物永远不能转换为 `externally_verified`。
当前 R4 仍是 preparation-only，未产生该状态，因此 26/26 仍为 `typed_absent`，
`T1_go=false`、`T2_go=false`。

## 26 项外部输入索引

| ID | 包 | owner（归档原文） | authoritative channel | 当前状态 | 恢复条件（摘要） |
|---|---|---|---|---|---|
| `EXT-WITNESS-IDENTITY` | EHP-01 | independent witness/intake owner | `typed_absent` | `typed_absent` | 命名外部 witness 提供签名 identity package 和 reviewer receipt |
| `EXT-WITNESS-INDEPENDENCE` | EHP-01 | independent witness plus governance owner | `typed_absent` | `typed_absent` | 不同 witness 提供新的 signed disclosure；冲突/范围变化使旧 receipt 失效 |
| `EXT-TRUST-ROOT` | EHP-02 | project PKI/trust administrator | `typed_absent` | `typed_absent` | 外部发布 pinned root、策略 receipt 后重跑 path/revocation |
| `EXT-CERT-CHAIN` | EHP-02 | attestor PKI owner | `typed_absent` | `typed_absent` | 提供完整链及新的 issuer/revocation 证据 |
| `EXT-SIGNED-ATTESTATION` | EHP-01 | independent witness；trusted-time/PKI authorities | `typed_absent` | `typed_absent` | 对精确 canonical response 重新签名并绑定新 time/revocation receipt |
| `EXT-VERIFIER-POLICY` | EHP-02 | independent verifier/policy owner | `typed_absent` | `typed_absent` | 发布版本化、hash-pinned verifier/profile 和 fresh review receipt |
| `EXT-SOURCE-CLOSURE` | EHP-03 | source authority and independent attestor | `typed_absent` | `typed_absent` | 同一 candidate 的完整 signed source closure；源变化须重建下游 identity |
| `EXT-AUTH-CHANNEL` | EHP-01 | authoritative channel owner | `typed_absent` | `typed_absent` | 发布可验证 channel contract 和可测试 ack 路径后才可发送 |
| `EXT-CHANNEL-RECEIPT` | EHP-01 | authoritative channel owner | `typed_absent` | `typed_absent` | 返回 fresh signed ack/rejection；保留 raw response |
| `EXT-CANDIDATE-LINEAGE` | EHP-03 | candidate/source authority | `typed_absent` | `typed_absent` | 提供一个完整 same-candidate lineage package 并重建下游 receipt |
| `trust_root` | EHP-02 | project trust administrator | `typed_absent` | `typed_absent` | fresh out-of-band root/policy；重新验证全部依赖签名 |
| `intermediate_chain` | EHP-02 | PKI/CA owner | `typed_absent` | `typed_absent` | 完整有效 chain 和新 receipt；partial chain 仍 fail-closed |
| `leaf_attestor` | EHP-01 | independent attestor | `typed_absent` | `typed_absent` | 合格 attestor 提供 valid leaf 和 signed scope |
| `signature_profile` | EHP-02 | contract and verifier owner | `typed_absent` | `typed_absent` | 新 profile 版本发布并重签受影响 receipt |
| `signed_receipt` | EHP-02 | external attestor/authority | `typed_absent` | `typed_absent` | 对未变或明确 rebound 的字节签发 fresh receipt |
| `verifier` | EHP-02 | independent verification owner | `typed_absent` | `typed_absent` | 提供受支持的 pinned verifier；否则保持 absent/unsupported |
| `revocation_source` | EHP-02 | CA/attestor PKI owner | `typed_absent` | `typed_absent` | fresh signed CRL/OCSP、有效 issuer 和时间窗口 |
| `trusted_time` | EHP-02 | independent TSA/time-policy owner | `typed_absent` | `typed_absent` | 获取绑定精确字节的独立可验证 time token |
| `replay_policy` | EHP-02 | protocol and replay-ledger owner | `typed_absent` | `typed_absent` | fresh nonce 的 authorized request；key/policy 变化需新 anchor/receipt |
| `source_version_binding` | EHP-03 | source owners plus independent attestor | `typed_absent` | `typed_absent` | fresh signed inventory；drift 后重建 candidate/axis/G2/receipt identity |
| `independent_attestation_scope` | EHP-01 | attestor and governance owner | `typed_absent` | `typed_absent` | distinct attestor 签署完整 scope statement |
| `source_candidate_evidence_binding` | EHP-03 | source/candidate evidence authority | `typed_absent` | `typed_absent` | 完整 signed forward/reverse graph；重建下游 hash |
| `g2_authoritative_mapping` | EHP-03 | G2 mapping authority/attestor | `typed_absent` | `typed_absent` | fresh complete mapping；策略/源变化使旧 mapping 失效 |
| `four_axis_materials` | EHP-03 | G1/G2/G3 axis owners plus independent authority | `typed_absent` | `typed_absent` | 四项 externally issued materials 作为一组到齐 |
| `candidate_environment_closure` | EHP-04 | independent environment/SBOM provider | `typed_absent` | `typed_absent` | complete candidate-bound closure；runtime/source/dependency drift 要 rebind |
| `binary_provenance` | EHP-04 | binary publisher/distributor plus independent provenance reviewer | `typed_absent` | `typed_absent` | complete signed provenance，或明确标记 unavailable |

## 统一禁止替代物

不得用本地姓名或 self-attestation、未 pin 的系统证书根、TEST_ONLY fixture、local
spool/CAS/ledger receipt、OS clock/file mtime/Git time、历史 receipt、HEAD-only 或
stale hash、scalar graph label、软件测试/代理/屏幕结果、系统 Authenticode/store
观察、推测的 URL/credential/key/signature/authority/candidate 替代合同中的原始字节、
外部签名或 authoritative receipt。

恢复时不能在原始字节上原地修补：必须使用 fresh identity tuple、fresh canonical
bytes、fresh signatures/receipts；G1/G2/G3、source、axis、trust、policy 或环境变化
都要求重建受影响的 candidate 和下游 receipt。未获得真实 owner/channel/material 时，
合同保持 `typed_absent`，不新建 AD、不重跑 S3，也不改变 R01-R10 或 parent goal。
