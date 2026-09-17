# AD-48 G3 source-authority gap decomposition — independent review R1

日期：2026-09-15  
复核模型：different `gpt-5.6-luna/high`  
结论：`changes_requested`  
复核范围：只复核冻结 AD48 readiness audit 的事实、三门工作单、依赖和禁止边；未修改被审产品、源码、测试、fixture、核心清单或 registry，未运行 Julia、DESC、provider、mesh、solver、engineering、physics 或 search。

## 可重放事实

AD48 的三个冻结产品逐字节匹配任务给出的值：`report.md` 13210 bytes / `ea8b6b6f57f6a1f85d53589581e0ceb9826057f85b0cf9357c3091a3c37c49b2`，`manifest.json` 6343 bytes / `aed7b27912416c6f35fb37b647fbf441f7bc7ff9a9af0d106a74ba24bb8c4baa`，`cleanup_inventory.md` 827 bytes / `4a17966bd6318b900fa11b6c45bb8e1219606cabb13790c53c385b54026dc801`。

AD47 W1 的八个产品均保持冻结哈希；其 different Luna R1 为 `pass_limited`，且四个 scope 均为 typed absence。当前 HEAD 仍为 `4b69f55f7f80240147a65a22809dc1207824dde2`。规划复核为 Python 3.13.5、validate_plan exit 0，31 markdown、497 relative links、39 tasks、DAG acyclic；作用域 `git diff --check` exit 0。这些记录只证明软件/文档闭合，不是物理或工程证据。

## 必须退回的问题

AD48 的 `manifest.json` 和 `report.md` 都声明 `src/GenomeV5/G3/RealizationGenomeV5.jl` 的 SHA 为
`0034f0c494df9a61f6e753d6d0b7f0fbca2d1a21eccf915ad3bba25ca427f6b`。该值只有 63 个十六进制字符；当前 33751-byte 文件的独立 SHA-256 是
`0034f0c494df9a61f6e753d6d0b7f0fbca2d1a21eccf915ad3bba25ca427f6fb`，64 个字符。字节数相同但 hash 不相等，且错误值同时出现在冻结报告和 manifest 中。因此 readiness 产品没有通过 exact source hash closure，不能给 `pass_limited`；应重生成该 source hash 字段及受影响的 archive/manifest evidence，再由不同 Luna 复核。不得修改源码迎合记录。

其余四个主 G3 源、反馈源和三个 child-editability 源的 declared bytes/SHA 与当前文件匹配。代表性 G3 源均是 `git ls-files` absent、working-tree untracked，AD48 正确地把它们视为观察快照而非 committed source authority。

## 三门工作单复核

S1 的四 scope（realization、control、binding、bundle）各有 `source_locator_v1.json` 和 `source_locator_receipt.json`，共 8 个产品；schemas、Present/Absent/Failed unions、完整 source closure、HEAD/working-tree 状态、精确 bytes/SHA、变更失效规则、terminal deferred 和 no-publish 退出门均已明确。S1 不产生 candidate/declaration/final identity，也不从 seed、fixture、URI 或 hash 派生身份。S1 可和已经准备的 AD47 G3 axis schema extension 并行。

S2 的四 scope 各有 `factory_identity_v1.json` 和 `factory_construction_receipt.json`，共 8 个产品；它要求真实 locator、构造入口、参数、registry 状态、语义输入及 candidate identity 未创建的事实，并禁止把 `RealizationControlGenomeV5.candidate_hash` 冒充 `CandidateIdentityV1`。当前源码只有 G3 genome constructors/helpers；检索没有发现 `G3SourceAuthorityFactoryV1` 或 G3 factory adapter。`SourceLocatorV1` 和 `FactoryConstructionReceiptV1` 只在 `VNextParentBaselineBindingV1.jl` 的 parent typed-absence scaffold 中存在，不能当作 G3 factory。

因此 AD48-F0 的 conditional 边界是合理的：若 S2 的真实探针仍为 Absent，只允许不同 Luna 实现恰两个归属文件：`src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl` 和 `test/GenomeV5/G3/g3_source_authority_factory_v1_tests.jl`；不得修改 `default_operator_registry()`。F0 必须使用 S1 locator 和真实 G3 constructors，保持 union/absence/fail-closed 语义，不创造 candidate identity。F0 之后仍需新鲜 S2 取证。

S3 的四 scope 各有 `trusted_source_identity_v1.json` 和 `trusted_source_identity_receipt.json`，共 8 个产品；独立 Luna 只能提供 repository-local 软件 source identity review，不能把本地复核写成密码学签名、外部信任、provider、mesh、solver、工程或物理证据。没有真实 signing/key 机制时应保持 Absent；root Sol 只接收该 review 的范围，不作为唯一 attestor。缺 candidate-bound input、完整 closure、factory receipt 或可信身份时保持 terminal deferred。

## 依赖与裁决

合法顺序仍为：`AD47-W1 independent review → AD48-S1 → AD48-F0（仅当 S2 证明 factory absent）→ AD48-S2 → AD48-S3 → fresh W1 八产品 → AD47-W2`。S1 与 axis schema 准备可并行；S2 等 S1；S3 等 S1、S2 和不同 Luna source-identity review；fresh W1 必须在 source/factory/attestation 输入变化后重建。该顺序无环，且没有把 typed-absence 或文档/测试/runner exit 当成 authority 或物理证据。

## 结论与退出门

AD48 的拆解形状可继续作为有限派单依据，S1 可以派发，S2 的 F0 可以保持条件派单；但在修正 realization source hash 并重建受影响 evidence 前，本复核结论为 `changes_requested`。本复核不授予 G3 source authority、factory identity、trusted source identity、candidate binding、四轴、T0/T1/T2、UP2、provider、mesh、solver、engineering、physical、search、R01–R10 或 L4 credit；这些仍为 `false/0`。
