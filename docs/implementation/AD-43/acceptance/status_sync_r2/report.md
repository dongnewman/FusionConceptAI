# AD-43 acceptance status sync R2

日期：2026-09-15  
观察 HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`  
Sol/root 裁决：`accepted_limited`  
范围：`AD43-AXIS-CONTRACT-RECORDS / software_contract_record_only`

本次追加状态同步记录 AD43 四个 source-only axis contract products 的接受。
不同 Luna/high 独立复核为 `pass_limited` 90/90，PID `28864`，UTC
`2026-09-15T10:17:45.206445Z`–`2026-09-15T10:17:45.252759Z`，exit `0`；
直接产品 validator 的 38/38 收据为 PID `75732`，UTC
`2026-09-15T10:08:20.088684Z`–`2026-09-15T10:08:47.804914Z`，exit `0`。
四个产品的当前 exact bytes/SHA-256 为：

- `evidence_receipt_axis_schema_v1.json`: 4237 bytes,
  `f16a518f886c31726725e18b9b317caecb2666e9905d718c60ef35b611ad1993`
- `g1_evidence_receipt_contract_v1.json`: 5446 bytes,
  `0b68dd638641990b16a88cc3fd5a7268bd0d1fe675bf0e76e695631b61954d5a`
- `g2_applicability_profile_contract_v1.json`: 4968 bytes,
  `1ca17e3ac7414d3a3817f3cf98436484a002f7a0d780e824f5c7a72fb2902d19`
- `g2_evidence_receipt_contract_v1.json`: 5764 bytes,
  `699291a5f5478977fb4aab92b0d101126096da97a0bb989fd600d61ed92a5a98`

`PresentAxisContractRecordV1` 在本裁决中只表示合同定义与 exact source/product
bytes 已闭合。四个产品的 future candidate/source/identity/attestation 字段
保持 `null`，状态为 `typed_absent`，缺失策略为 `terminal_deferred`；它们不
产生 candidate-bound axis present、source-backed authority、declaration
present、T0/T1/T2、provider、mesh、solver、engineering、physical 或 R01–R10
信用。W2R1 当前并行 authoring payload/receipt 是
`point_in_time_excluded`，必须由后续工作单 fresh rebind，不能反向生成 axis
record 或提前授予 R credit。

acceptance repair R2 的不同 Luna/high 独立复核为 19/19，PID `9900`，UTC
`2026-09-15T10:24:39.636492Z`–`2026-09-15T10:24:39.638369Z`，exit `0`，
其历史失败收据和原错误 hash 均保留。

本次 status sync 的实时 JSON/hash/path/control validator 为 24/24，PID
`59748`，UTC `2026-09-15T10:35:45.297187Z`–`2026-09-15T10:35:45.303884Z`，
exit `0`；raw stdout 为
`status_sync_r2/acceptance_validator_stdout.json`（3076 bytes，SHA
`16791815750f2e214ede16b11d41216ebe7ed6593574b2e53235b9f60527ca62`），stderr
为 1 byte，SHA
`01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b`。
规划 DAG validator PID `77496`，UTC
`2026-09-15T10:35:57.067520Z`–`2026-09-15T10:35:57.536208Z`，exit `0`，39
tasks、DAG acyclic；raw stdout 735 bytes，SHA
`233e8d9f514d74ac3a2e5ca6500a55b2dc027eec6b6b3c2ee36d5068bd177d42`，stderr
为 1 byte，SHA
`01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b`。
`git diff --check` PID `28668`，UTC
`2026-09-15T10:36:09.332061Z`–`2026-09-15T10:36:09.399578Z`，exit `0`；stdout
326 bytes，SHA `f58782b73faa6788278ec141976f5dc81a711896a4bf8986daa1008b3ba1f7b5`，
stderr 为 1 byte，SHA
`01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b`。

状态同步只写入本目录的 acceptance decision、manifest 与 raw evidence
sidecars；未修改四个 axis products、AD-42 W2R1 并行产物、core、task manifest、
源码、测试或 fixture。未运行 Julia、DESC、provider、mesh、solver 或 physical
workload；所有 R01–R10 与工程/物理 claims 继续为 `false`。cleanup 没有发现
或删除任务外临时物，历史 repair/R2/raw receipts 均 append-only 保留。
