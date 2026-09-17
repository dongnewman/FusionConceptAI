# AD-47 W0 G3 axis schema extension independent review R2

日期：2026-09-15  
范围：复核 W0 修复后的四个产品、AD43 四份冻结 source-only contract、五个 G3 source closure、schema/scope/migration/validation/final-snapshot 的哈希闭合，以及 JSON/path/control、规划 DAG 和 scoped diff。未修改四个产品、`src/`、`test/`、核心规划、`task_manifest.json` 或 registry。

## 结论

`pass_limited`，仅限 additive software contract 与其 source-byte/hash closure。

R1 发现的 bundle source hash 错误已修复。当前 `src/GenomeV5/G3/RealizationControlGenomeV5.jl` 为 6704 bytes，实际及所有相关声明均为 64 字符 SHA-256 `8e9d4f1505098b745048a5f741e0cb1edcccdcf70a395c212f0a8649a73d62a4`。Realization、Control、CoupledBinding、RealizationControl bundle 与 G3SourceFeedbackLaw 五个源文件均 exact。

## 冻结与闭合检查

四个当前冻结产品均按实际最终值通过字节数、SHA-256、canonical sorted JSON 与无末尾 LF：

* schema：7465 bytes，`b9ff3eeab8027085a09ba88c6b2418d1017321da7a4376357fff437bcd6d0e13`；
* scope：4420 bytes，`41ec0e8e035183bd946cd6899789ab800ccbc558e094ae08f569baff8f33c617`；
* migration：3428 bytes，`3cfa558475eaaed8e327754e144fc113e3b22310a9625a87941b7b0dc02244b9`；
* validation：4410 bytes，`9a5a7e0f0b2ee8d3eac7ed6ba74b565cc456525bc77946575f7893fd475a1c99`。

validation receipt 的实际最终文件在复核开始前后 mtime 与 SHA 双次相同：mtime ns `1789476772359754300`，bytes `4410`，SHA `9a5a7e0f0b2ee8d3eac7ed6ba74b565cc456525bc77946575f7893fd475a1c99`。因此未观察到评审期间并发修改。

scope 对 schema adapter 的 bytes/SHA 引用 exact；migration 对 schema、scope 和五个 G3 source 的引用 exact；validation 对前三个产品、final snapshot 和 `self_hash_excluded` exact；final snapshot 的源闭合和前三个产品引用也 exact，无循环身份派生。

AD43 四份输入按照 migration receipt 的冻结 bytes/SHA 逐字节复核通过，G1/G2 layer enum 保持不变。schema/scope 均为 G3，scope 恰为 `realization|control|binding|bundle`，axis 恰为 `payload_schema|canonicalization_profile|applicability_profile|evidence_receipt`，adapter ref/version 为 `fusionconceptai://GenomeV5/G3/axis-contract` / `v1`。负控计数为 schema 9、scope 7、validation 6；registry unchanged；所有 claims false、runtime counts zero，禁止的 candidate/declaration/source identity 字段无非空命中。

独立直接校验使用 `D:\Users\Newman\anaconda3\python.exe`、Python `3.13.5`，PID `88976`，UTC `2026-09-15T12:54:43.223472+00:00`，exit `0`；mtime 稳定性检查使用同一解释器 PID `80008`，UTC `2026-09-15T12:53:59.859230+00:00`，两次采样一致。规划校验为 31 markdown、497 relative links、39 tasks、DAG acyclic，exit `0`；scoped `git diff --check` exit `0`。原始收据均在 `review/`。

## 边界

`PresentG3AxisSchemaExtensionV1` 只关闭软件合同、schema/migration/negative-control 与 source-byte/hash closure。该复核没有产生 candidate、declaration、final identity、candidate-bound axis、T0/T1/T2、provider、mesh、solver、engineering、physical、search 或 R01–R10 证据，也不改变 L4=0 和父目标状态。
