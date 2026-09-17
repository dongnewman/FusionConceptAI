# AD-46 三层 Candidate Identity Owner 就绪性审计

## 裁决

本审计是 `readiness_audit_only`，`accepted=false`。AD-46 独立 R1 仍为 `changes_requested`；本次只修正其指出的 upstream 状态陈述，保留 R1 报告和失败历史。AD-46 没有实现、生成或晋升任何 identity、hash、binding 或候选物理证据；R01–R10 全部保持无信用。三层 Genome 不能缩减为两层、单一 seed、URI、payload hash 或 common handle。

当前 owner 不具备进入 identity materialization 的条件。AD-44 W3-A 已由独立 R2 以 47/47 `pass_limited` 复核并由 root `accepted_limited` 接受，范围仍仅为 current-working-tree repository-design source software provenance；四产品 frozen，但 G1/G2 source paths 在 HEAD 中仍为 `absent_untracked`。W3-B 八个 candidate-bound axis 产品不存在。AD-45 A 已由独立 R2 以 59/59 `pass_limited` 复核并由 root `accepted_limited` 接受，范围仅为 software common `QualifiedRef` binding handle；两产品已重新 frozen。R1 的三类缺口作为 `repaired_history` 保留，不把 common ref 升级为最终 identity。仍缺 G3 source-backed declaration/binding/axes/child-control-feedback provenance、G1/G2/G3 source identity review/factory inputs 及其它 manifest 列明的真实输入。G3 realization/control/binding 仍处于 typed absence / terminal deferred 上限。故任何 `CandidateIdentityV1`、present T0、T1/T2、provider/mesh/solver/physics/search 结论均被阻断。

## 当前源码与合同证据

- HEAD 为 `4b69f55f7f80240147a65a22809dc1207824dde2`；当前 `docs/v4_multitopology_generation/task_manifest.json` SHA-256 为 `7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`，任务数为 39，计划 DAG 校验退出码为 0。
- 共同合同和 v4 README 要求三层 public refs、四轴、组件/声明/来源证据、candidate binding、G3 realization/control/binding/feedback 一起进入最终 identity 的语义输入；G2 的 `GenomeContractRef` 必须保留为来源类型，不能以 URI 后缀、别名、seed 或 hash 替换。
- AD-42 W2R1 四冻结产品和 AD-43 四个 source-only axis 产品均可定位，但 AD-43 的 candidate-bound 字段仍为 null，不能冒充候选轴证明。
- AD-44 W3-A 四产品当前 frozen：G1 record 6550 bytes SHA-256 `0980aa741561445f2d66efbf828100b1df3afa24d177c54a2712fa2ed7ccb750`、receipt 3404 bytes SHA-256 `3264717def0fdb1afb0ddf1213691b41a8b37d0d7f81460cb6616d5ac16e3cc2`；G2 record 6925 bytes SHA-256 `15a2479d73270fa3ef4562bc8e509404a18c61b4392d250f7f360546098eaa3e`、receipt 3596 bytes SHA-256 `807950e896c342ddb2187b66364687d656ef0433469a72192e32c17c86b5506d`。独立 R2 为 47/47、`pass_limited`，root acceptance 为 `accepted_limited`，且四项 source provenance 的 claim ceiling 保持 software-only；G1/G2 HEAD source paths 仍是 `absent_untracked`。W3-B 产品尚不存在。
- AD-45 A 当前 frozen envelope 为 9612 bytes，SHA-256 `17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc`；receipt 为 5776 bytes，SHA-256 `adf9caefb31398c4cf4fd04dc443fb8f409d7485e1ee04f125a28e3b427a9b64`。独立 R2 为 59/59 `pass_limited`，root acceptance 为 `accepted_limited`，scope 仅为 software common `QualifiedRef` binding handle；`common_ref` 仍是临时 G1/G2 handle，`candidate_identity_created=false`、`candidate_identity_hash=null`、`declaration_hash=null`。R1 的五个 raw artifact SHA 缺位、negative-control receipt 字段缺失、wall-clock union token 三类缺口均作为 `repaired_history` 保留；A 可以作为 accepted handle input，但不能解锁三层 identity。
- G3 source feedback law、realization、control、binding 源文件均存在软件合同或 typed absence scaffold；当前 parent authority unavailable，不能把 scaffold、文档或运行器退出码升级成 source-backed child identity。
- AD-46 `independent_review_r1/` 是外部复核 sidecar，当前 `changes_requested`；其报告、raw review sidecars 与三次失败历史保留，不计入本次三件正式产品，也不改变本审计的 `accepted=false`。

## Identity owner 的合同裁决

### Common QualifiedRefV1 的定位

AD-45 A 的 common `QualifiedRefV1` 是临时的、同候选 join/binding handle。它由独立 namespace、UUID、nonce、CAS token 和 OS randomness 产生，且排除了 wall clock、seed、payload、声明、axis 与最终 candidate hash；这正是防止 identity 预生成和伪造的必要边界。它不能成为最终 identity 的前置替身，也不能被重命名成 `CandidateIdentityV1`。

### 最终 CandidateIdentityV1 的最低输入

最终 `CandidateIdentityV1` 必须包含并精确绑定：

1. G1、G2、G3 的三份实际 public `GenomeContractRef`，保留每层原始类型和来源路径。
2. 三层 source-backed declaration、source/content/declaration/bundle hashes，以及独立 source identity review 的闭环 receipt。
3. 三层四个 candidate-bound axes；AD-43 source-only axis 产品只能作为模板，不能直接充当这些证明。
4. G2 的显式 `GenomeContractRef -> common QualifiedRefV1` mapping，且 mapping 位于 identity 输入冻结/三层 join 中，不藏在 axis、不从 URI 推断、不由字符串或 hash 转换。
5. G3 source-backed bundle、realization/control/binding child identity 和 feedback/authority provenance；如果 child 尚未具备同一 fresh candidate 的来源证据，最终结果必须是 typed `AbsentCandidateIdentityV1` 或 `terminal_deferred`，不能输出 partial present identity。

### 合法且无循环的 semantic preimage

合法顺序为：`fresh common handle` → `G1/G2/G3 source-backed declarations` → `independent source identity reviews` → `explicit G2 mapping` → `candidate-bound four-axis attestations` → `IdentityInputFreezeV1` → `TrilayerJoinV1` semantic preimage → `CandidateIdentityV1` materialization → downstream T0/T1/T2。preimage 只能引用组件、声明、来源、轴、mapping、G3 child/feedback 和 candidate binding 的 canonical content；identity 自身的最终 hash、未来 candidate hash 或自身 URI 永远不能成为输入。任一来源、ref、axis、mapping 或 child 状态改变，都必须产生新的 preimage 和新的 identity。冲突、重放、旧候选复用全部 fail closed。

### Source identity review

Source identity review 是独立 Luna 对实际 source bytes、路径、schema、canonicalization、profile/applicability、receipt、source/content/declaration hashes 和 candidate binding 的复核；它是 identity materialization 的前置证据，而不是 identity 生成后的装饰。source 变化必须使旧 review 和旧 identity 失效。AD-44 W3-A 的 R2 已通过 software provenance 门，但 `absent_untracked` HEAD source boundary、G3 source-backed declaration/children、candidate-bound axes 和 factory/source identity review 仍未闭合；AD-45 A 的 R2 只通过 common handle 软件合同，不提供三层 source identity、G3 declaration/binding 或 factory/physical evidence。因此 identity input freeze 仍被阻止。

## 有限工作单与边界

AD-46 只拆分以下三个有限工作单；本审计不创建它们的实现产品，也不把它们追加进 39-task manifest。每单两件预定产品，合计六件；在前置条件满足前只允许 typed absent/deferred 结果。

### AD46-IDENTITY-INPUT-FREEZE

- 文件归属：`docs/implementation/AD-46/IDENTITY-INPUT-FREEZE/identity_input_freeze_v1.json`、`freeze_receipt.json`（2 products）。
- 输入：修复并独立复核通过的 AD-44 W3-A；独立复核并同步状态后的 AD-45 A；fresh G1/G2/G3 source-backed declarations/factory/receipts；AD-43 四轴合同；candidate-bound axis attestations；source identity review；显式 G2 mapping；G3 realization/control/binding/feedback 状态。
- 输出 union：`IdentityInputFreezeV1 | AbsentIdentityInputFreezeV1 | FailedIdentityInputFreezeV1`。成功时只冻结 exact paths/types/hashes、三层声明、四轴、mapping 和 child 状态；不输出 candidate identity。
- 依赖/阻断：AD-44 W3-A R2/accepted_limited 已满足其 software-provenance 门，但仍只有 `absent_untracked` working-tree source boundary；AD-45 A R2/accepted_limited 仅提供可用的临时 common G1/G2 handle。仍缺 fresh G1/G2/G3 source-backed declarations/factory inputs、G3 source-backed declaration/binding/axes/child-control-feedback provenance、三层 candidate-bound axes、G2 mapping 和三层 source identity reviews。当前仍 blocked。
- 禁止：identity/hash 创建、T0/T1/T2、UP2、provider/mesh/solver/physics/search、R01–R10、修改 core/task_manifest/src/test/fixture。
- 退出门：canonical replay 与 exact hash/path/type closure；每层 present/absent 语义明确；无 hash 自依赖、无 seed/payload 推导、无旧候选复用；不同 Luna 独立复核通过。

### AD46-TRILAYER-JOIN

- 文件归属：`docs/implementation/AD-46/TRILAYER-JOIN/trilayer_join_receipt.json`、`join_negative_controls.json`（2 products）。
- 输入：通过的 `IdentityInputFreezeV1`、同一 fresh candidate 的 G1/G2/G3 refs、四轴、显式 G2 mapping、source review 和 G3 child/binding/feedback 状态。
- 输出 union：`TrilayerJoinV1 | AbsentTrilayerJoinV1 | FailedTrilayerJoinV1`。`TrilayerJoinV1` 是可重放的 semantic preimage/join receipt，不是 identity hash。
- 依赖/阻断：IdentityInputFreezeV1 先行，且 AD-45 A 的 accepted common handle 必须与 fresh 三层 refs exact join；仍缺 G3 source-backed declaration/binding/axes/child-control-feedback provenance、G1/G2/G3 source identity reviews/factory inputs、candidate-bound axes、G2 mapping 和其它 manifest inputs，无法启动。
- 禁止：CandidateIdentityV1 或其 hash materialization、T0/T1/T2、UP2、provider/mesh/solver/physics/search、任何 R credit。
- 退出门：fresh process canonical replay；common handle、G2 mapping、三层 refs/axes/child/feedback exact match；冲突、重放、来源变化 fail closed；绝不将最终 identity hash写回 preimage。

### AD46-IDENTITY-MATERIALIZATION

- 文件归属：`docs/implementation/AD-46/IDENTITY-MATERIALIZATION/candidate_identity_v1.json`、`identity_receipt.json`（2 products）。
- 输入：通过的 IdentityInputFreezeV1 和 TrilayerJoinV1；三层完整 source-backed declaration；独立 source identity review；三层四轴；G2 mapping；G3 source-backed bundle/realization/control/binding/feedback；外部 identity owner 的独立决策。
- 输出 union：`CandidateIdentityV1 | AbsentCandidateIdentityV1 | FailedCandidateIdentityV1`。G3 source-backed/binding 或任一三层输入缺失时只能输出 absent/deferred。
- 依赖/阻断：前两单通过，AD-45 A R2 accepted handle 只满足 common binding-handle 输入；仍需 fresh 同候选三层来源、G3 declaration/binding/axes/child-control-feedback provenance、axes/factory/source reviews、G2 mapping 和 G3 子身份齐备；AD-44 W3-A software provenance 已通过但不提供 present/factory/physical credit。当前不可派发。
- 禁止：以 common handle、seed、payload、URI、历史 hash 或自身 hash制造 identity；T0/T1/T2、UP2、provider/mesh/solver/physics/search、R01–R10。
- 退出门：独立 process 重算一致；source/ref/axis/mapping/child 任一改变均改变 identity；无旧候选复用和自引用；独立 Luna review 通过；仍不产生物理信用。

## 运行与范围证据

本次最终静态验证使用 Python 3.13.5，主 PID、UTC、子 PID 和 raw hashes 记录在 manifest 与本目录 `archive/validation_stdout.json`；退出码 0。计划校验退出码 0，`git diff --check -- docs/implementation/AD-46` 退出码 0。验证 raw stdout/stderr、历史失败尝试、plan stdout/stderr 和 diff stdout/stderr 均只放在本目录 `archive/`。验证观察到既有脏状态；没有清理或重写既有用户改动。

本报告只判断静态 readiness 和合同闭环。它不把 task validator、文档、代理结论、测试或 runner 退出码当作物理/工程证据，也不向父目标 R01–R10 晋升任何信用。
