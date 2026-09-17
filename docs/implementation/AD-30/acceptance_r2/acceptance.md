# AD-30 R2 有限架构接受记录

- `decision_id`: `AD-30`
- `status`: `accepted_limited`
- `accepted`: `true`（仅限无损声明传递合同、排期和证据边界）
- `resolution`: `accepted_limited`
- `base_head`: `4b69f55f7f80240147a65a22809dc1207824dde2`
- `independent_review`: different Luna/high，`pass_limited`，见 [R2 review](../independent_review_r2/report.md)
- `decision_owner`: Sol/root，2026-09-15

AD-30 R2 只接受 VNEXT 的 additive、同一 fresh candidate、强类型声明传递边界，以及 T0→T1→T2 的后续排期。执行拓扑固定为旧 `UP1-04A` 与三张 V1 upstream 先进入 T0，随后 T1、T2，最后由既有 `UP1-04A-VNEXT` 主工单汇聚冻结并独立验收，再进入 UP2-00；该主工单不重复 T0/T1/T2。上游未冻结时只能进行准备或本地 contract-only 检查，不能宣称 fresh-candidate acceptance。G1/G2/G3 V1 declaration 仍必须完整保留 semantic body、source/content/declaration/bundle identity、候选绑定、四轴 provenance 和 G3 child/feedback 状态；旧 concrete V5、旧 `CandidateStatePackageV5`、旧 hash/receipt/candidate identity 与 `default_operator_registry()` 继续只读。

本接受记录不授予 T0/T1/T2 源码实现信用；后续实现仅可按 root-owned 有限工作单和独立审查门推进，并仍不接受 UP2-00 total、UP1-04B、B00、50 条 formal B04、provider、mesh、engineering、physical、search 或 R01–R10。 当前 source-readiness 仅对 T0 contract implementation 为 `conditional_go`；fixture/direct join 不能作 authority，T1 在 T0 真实同候选完整 bundle 及独立退出门前为 `no_go`。所有新增工作单保持 `planned`/`proposal`、`accepted=false`；本地 focused test、文档、plan validator 和 runner exit 不能提升这些状态。

## R2 reviewer 的三个 T0 条件

1. **G2 candidate envelope**：G2 V1 的 `source.candidate_ref` 是 `GenomeContractRef`，不是 candidate `QualifiedRefV1`。T0 必须定义新的 typed transport candidate-binding envelope，精确 join 到 fresh candidate；不能把 G2 contract ref 重新解释成候选身份。缺失/歧义为 `terminal_deferred`，冲突为 `fail_closed`。
2. **四轴真实来源**：T0 必须为 `payload_schema_version`、`canonicalization_profile_version`、`applicability_profile_version`、`evidence_receipt_version` 各自记录可审计真实来源并逐项 equality。V1 schema/canonical/profile 常量、层名、相似版本字符串和默认值不能填补缺轴；缺轴为 `terminal_deferred`，冲突为 `fail_closed`。
3. **G3 hash 语义**：G3 V1 当前只有覆盖完整 declaration body 的 `declaration_hash`。T0 必须把它作为可用 declaration/content evidence 原样保留；只有实际提供新的、内容哈希受控的 source object 时才可出现独立 source hash，不能伪造或复制 hash。

## 有限工作边界

- T0 只允许未来新增 `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl`、对应 `test/GenomeV5/Integration/` 测试和 `docs/implementation/UP1-04A-VNEXT-T0/` 记录；当前接受不等于已实施这些文件。
- T1 另行新增版本化 `CandidateStatePackageV5Next` 与 integrator；完整 package hash 必须覆盖三张 declaration、source/declaration/bundle identity、候选绑定、四轴、自身 schema/canonical/profile 和 G3 actual-or-typed-absent child/feedback 状态。
- T2 另行重建 E0/G-I1A/E1/E2/UP2 identity/receipt；必须绑定同一 fresh candidate 和完整 authority provenance，之后才可按既有门冻结 formal B00/B04。T1/T2 不得与 T0 共享文件所有权。

AD-30 的执行状态仍由各自工作单和任务清单管理；任何 source authority、轴、child 或 provider 缺口保持独立 `terminal_deferred`，结构冲突保持 `fail_closed`。父目标及 R01–R10 不因本有限接受而关账。

证据、输入哈希、脏工作区保护和静态校验见 [evidence manifest](evidence_manifest.json)。
