# AD-43 G1/G2 四轴 typed-absence 缺口审计 — 架构验收裁决

日期：2026-09-15  
观测 HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`  
状态：`accepted_limited`  
实现状态：`software_contract_record_closed; no candidate-bound implementation`  
验收范围：`architecture_only_three_typed_absences_and_source_only_axis_contract_records`

## 裁决

依据 AD-43 read-only audit、`AD43-AXIS-CONTRACT-RECORDS` 的不同
Luna/high 独立复核 `pass_limited`（90/90），以及 acceptance repair 的
different Luna/high independent review R2 `pass_limited`（19/19），本裁决接受
三个真实 typed-absence 判断以及四个 source-only axis contract products 的
有限软件合同边界。

三个缺口保持为：G1 `evidence_receipt_version`、G2
`applicability_profile_version`、G2 `evidence_receipt_version`。当前 V1 源码
没有 candidate-bound 的四轴记录、source-record hash 或 attestation；V1
software-only contract record 可以在后续工作单中补充合同定义和字节闭合，
但不因此把当前 W0、历史 receipt 或本地 profile 提升为 candidate-bound axis
present。缺少 fresh candidate/source/identity/attestation 输入时，结果仍是
`typed_absent` / `terminal_deferred`；冲突、跨域 alias、fixture、synthetic、
legacy 或历史 receipt 必须 `fail_closed`。

四个精确产品已完成 work-order 闭合并由不同 Luna/high 独立复核。它们的
`PresentAxisContractRecordV1` 只表示合同定义与 exact source/product bytes
可重算，不能表示 candidate-bound axis present、source-backed authority、
declaration present、T0/T1/T2、provider、mesh、solver、engineering、physical
或 R01–R10。所有未来 candidate/source/identity/attestation 字段保持 null，
记录 status 保持 `typed_absent`、缺失策略保持 `terminal_deferred`；V5 profile/
Genome、fixture、synthetic、legacy、historical receipt、跨域类型与 alias
只能作为负控或 `fail_closed`。

AD-43 work order 只允许单向边
`AD43-AXIS-CONTRACT-RECORDS -> AD42-W2R1-REAUTHOR-FRESH-PAYLOADS`；禁止由
payload、declaration 或 candidate hash 反向产生 axis record。G1 V1 的
`G1DiffusionReceiptV1`、G2 V1 的 `G2MBProfileV1` 和 `G2MBReceiptV1` 必须
各自保持精确 source type；G1/G2 V5 profile、Genome、candidate hash 只作
负控，不能冒充 V1 axis。AD-43 不新增 mainline task node。

## 证据与独立复核

AD43 axis products 的独立复核使用 Python 3.13.5，PID `28864`，UTC
`2026-09-15T10:17:45.206445Z`–`2026-09-15T10:17:45.252759Z`，exit `0`，
90/90；四个产品 exact bytes/SHA-256 为 4237/
`f16a518f886c31726725e18b9b317caecb2666e9905d718c60ef35b611ad1993`、5446/
`0b68dd638641990b16a88cc3fd5a7268bd0d1fe675bf0e76e695631b61954d5a`、4968/
`1ca17e3ac7414d3a3817f3cf98436484a002f7a0d780e824f5c7a72fb2902d19`、5764/
`699291a5f5478977fb4aab92b0d101126096da97a0bb989fd600d61ed92a5a98`。
Acceptance repair R2 的不同 Luna/high 复核为 19/19，PID `9900`，UTC
`2026-09-15T10:24:39.636492Z`–`2026-09-15T10:24:39.638369Z`，exit `0`；原错误
plan stderr hash 与修复后的真实 hash 均 append-only 保留。

本次 status sync R2 另行记录实时 JSON/hash/path/control、规划 DAG 与
`git diff --check` 的 PID、UTC、exit、raw sidecar 和 SHA。DAG 仅证明 39 个
计划任务无环，不是实现、工程或物理证据。

本裁决另行运行 acceptance JSON/hash/path/control validator 和规划 DAG
validator；二者均需记录 PID、UTC、exit、stdout/stderr、SHA-256。AD-42
acceptance 文档在本裁决生成后发生了字节变化；该当前漂移逐项记录为
`post_audit_input_drift`，不覆盖 AD-43 审计中 17 个输入的冻结 hash，也不把
后写入内容反向纳入本裁决。DAG 只证明
计划文档闭合，不是实现、工程或物理证据。验收记录保留当前输入 hash 与
review report/hash，manifest 自身采用 `self_hash_excluded=true`。

## 并行输出和关闭边界

AD-42 W0 与 AD-40 W2 的历史 payload/receipt，以及任何 W2R1 fresh payload
均为 `point_in_time_excluded`，必须重新绑定；它们不能反向生成 axis record。
AD43 四个合同产品仅在 `software_contract_record_only` 范围内接受，不能解锁
W2R1、T0/T1/T2 或任何 R credit。后续唯一允许方向为
`AD43-AXIS-CONTRACT-RECORDS -> AD42-W2R1-REAUTHOR-FRESH-PAYLOADS`。
AD-43 不修改 core、task manifest、源码、测试、fixture、W2R1 或旧 receipt；
cleanup 仅限 status sync 自有临时物，历史 evidence、四个产品和其它 agent 的
dirty work 保留。

当前 `present`、T0、T1、T2、provider、mesh、solver、engineering、physical、
search、B00、B04 和 R01–R10 全部为 `false`。没有运行 Julia、DESC、provider、
mesh、solver 或 physical workload；文档、hash、测试、DAG 或 agent exit code
不能替代真实物理与工程证据。
