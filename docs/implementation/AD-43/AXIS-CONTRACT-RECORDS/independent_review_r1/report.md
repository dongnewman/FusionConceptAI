# AD43-AXIS-CONTRACT-RECORDS independent review R1

日期：2026-09-15  
复核者：different `gpt-5.6-luna/high` independent reviewer  
状态：`pass_limited`

本复核只覆盖 AD43 的四个 source-only axis contract products，未修改产品、源码、测试、fixture、W0、旧 receipt、core 或 task manifest。`PresentAxisContractRecordV1` 在此处只表示合同定义及其 exact bytes 可重算；不授予 candidate-bound axis、source-backed authority、declaration present、T0/T1/T2、provider、mesh、solver、engineering、physical 或 R01–R10 信用。

复核确认：

- 四个顶层产品集合精确闭合，均为 UTF-8、lexicographic-key compact JSON、无 terminal LF；当前 bytes/SHA-256 与 AD43 r4 记录一致：4237/f16a518f…ad1993、5446/0b68dd63…954d5a、4968/1ca17e3a…902d19、5764/699291a5…a5a98。
- 共享 `EvidenceReceiptAxisSchemaV1` 定义了三值 result union、source exact-byte closure、独立 axis derivation 禁止依赖 payload/declaration/candidate/fixture/synthetic/legacy/historical receipt，以及 candidate-bound 字段缺失时的 `typed_absent`/`terminal_deferred` 边界。
- G1 精确引用 `G1DiffusionReceiptV1` 与其 field projection；G2 applicability 精确引用 `G2MBProfileV1` 的五字段 profile projection；G2 evidence 精确引用 `G2MBReceiptV1`，保持 `GenomeContractRef`，并禁止 `QualifiedRefV1` alias。
- 直接读取并核对 G1/G2 V1 源码中的 receipt/profile 类型、构造器、schema/canonicalization/profile descriptor/hash API；G1/G2 V5 profile/Genome 仅作为 cross-domain negative controls。
- 三个具体 record 的 future candidate binding 字段均为 null、status 为 `typed_absent`、missing policy 为 `terminal_deferred`；axis ref/version 不由 receipt/profile/declaration/candidate hash 派生。W0 envelope、fresh seed recipe、seed commitment 与产品中的闭合值一致。
- 负控覆盖 V1/V5 cross-domain、G1/G2 foreign type、`QualifiedRefV1` alias、fixture/historical reuse、seed mismatch、receipt/profile/hash 缺失和 axis alias；预先生成的失败验证收据仍保留。

独立复跑使用 `D:\Users\Newman\anaconda3\python.exe` / Python 3.13.5，从仓库根直接执行 JSON parse、canonical/no-LF、SHA/bytes、V1 API/source symbol、W0 seed/source closure、typed absence、negative-control、sidecar scope 和 `git diff --check`。最终复核为 90/90，PID `28864`，UTC `2026-09-15T10:17:45.206445Z`–`2026-09-15T10:17:45.252759Z`，exit `0`；raw streams 见 `review/validation_r3_stdout.json` 与 `review/validation_r3_stderr.txt`。

此前同一复核目录中的 `validation_stdout.json` 和 `validation_r2_stdout.json` 是复核器边界修正前的失败历史，分别因把共享 schema 当成具体 record、再因把非必需的 per-product `result_union` 当作必需字段而报错；两轮均未改变被审文件，均保留。最终 R3 已按共同 schema 与具体 `result ∈ union` 语义复跑并闭合。

结论：AD43-AXIS-CONTRACT-RECORDS 可在 `software_contract_record_only` 范围内 `pass_limited`。后续只允许由 W2R1 进行 fresh candidate/source/identity/attestation 的重新绑定；本复核不把四个合同产品转移为 candidate-bound present，也不提前开启 UP2、T0/T1/T2 或任何物理/R credit。
