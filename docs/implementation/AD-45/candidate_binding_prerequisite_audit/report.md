# AD-45 candidate binding prerequisite audit

日期：2026-09-15  
状态：`readiness_audit_only`  
验收：`accepted=false`  
范围：只读架构审计、候选绑定前置合同和有限工作单拆分。

本审计没有创建 `FreshCandidateBindingEnvelopeV1`、candidate、declaration、axis
attestation 或任何 candidate/declaration hash；没有修改既有产品、源码、测试、fixture、
核心目录或 `task_manifest.json`，没有运行 T0/T1/T2、provider、mesh、solver、physics、
search，也没有授予 R01-R10 信用。唯一新增的本单产品是本报告、`manifest.json`、
`cleanup_inventory.md`；原始核验摘要位于本目录 `archive/`。

## 观测基线与真实证据

仓库根为 `D:\006-Programing\LMC\FusionConceptAI`，HEAD 为
`4b69f55f7f80240147a65a22809dc1207824dde2`。工作树保留大量已有修改和历史/实现档案；
本单不清理、不暂存、不覆盖。审计时未发现正在运行的 Julia、DESC 或 mesh 进程；发现的
Python 进程属于其他并行工作，不触碰。

W2R1 当前四件冻结产品可由 Python 3.13.5 重新解析，均为 compact sorted JSON、无末尾
LF，字节与 SHA-256 如下：G1 payload `6180/f4841efa7e872a57e05c8eda687d951dd7775802ad3d07330947df72c5c97449`，
G1 receipt `13968/46d7329bd83188c280208b65ac58afc571c813c9d48e3732707dcf4d4bcb4210`，
G2 payload `7086/7244861fa4c640035c06ac7b69623f048c17b86f9deeda71de8406c452bbcacf`，
G2 receipt `14337/7a68be8d2e24b6a15364800cb3855c6a3d80b6d03bed6e2f9eb59d1b29cd988c`。
G1 的 authoring ref 是 `QualifiedRefV1`、version `v1`；G2 的 source ref 保持五字段
`GenomeContractRef`、version `v5`。两层 `candidate_identity.created=false`、hash 为
null，G2 `target_common_candidate_ref` 为 typed absent，declaration hash 为 null。

AD43 四份 source-only axis contract 也逐字节复算：4237/
`f16a518f886c31726725e18b9b317caecb2666e9905d718c60ef35b611ad1993`、5446/
`0b68dd638641990b16a88cc3fd5a7268bd0d1fe675bf0e76e695631b61954d5a`、4968/
`1ca17e3ac7414d3a3817f3cf98436484a002f7a0d780e824f5c7a72fb2902d19`、5764/
`699291a5f5478977fb4aab92b0d101126096da97a0bb989fd600d61ed92a5a98`。其 candidate-bound
字段仍为 null，缺失语义为 `AbsentAxisContractRecordV1` + `terminal_deferred`，冲突、
跨层 alias、fixture/历史复用和 hash 反推为 `FailedAxisContractRecordV1` + `fail_closed`。

直接核验使用 `D:\Users\Newman\anaconda3\python.exe` / Python 3.13.5，PID `33648`，
UTC `2026-09-15T11:07:04.794708+00:00`；12 个冻结 JSON 全部解析，11 个产品 JSON
canonical/no-LF，任务清单按其格式保留 LF。39 个任务、依赖无缺失且 DAG acyclic；
`task_manifest.json` SHA-256 为
`7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`。规划校验 exit `0`
（31 markdown、497 links、39 tasks），`git diff --check` exit `0`；后者仅有既有
LF/CRLF 警告。raw 摘要见 `archive/validation_summary.json`。

## common candidate ref 的架构裁决

允许未来单独的 A 单生成 common ref，但该 ref 只能是绑定句柄，不能冒充最终
candidate identity 或物理对象 hash。原因是当前 `QualifiedRefV1` 只有 `id` 和 `version`，
而 `GenomeContractRef` 有五个独立字段；二者不能凭 URI、后缀或版本字符串互相转换。

A 单必须由独立新鲜 namespace 与 UUID/nonce 产生一个 `QualifiedRefV1`，建议下游包使用
version `v5`；不得使用 W2R1 authoring ref、AD42 seed、payload/declaration/axis/final
hash、fixture、legacy 或历史 receipt 派生。生成过程、nonce/UUID、namespace、调用时间、
freshness/non-reuse 检查和 producer identity 必须写进 envelope 与 receipt。这个 ref
必须同时绑定 G1/G2 的精确 public `GenomeContractRef`，但不能改变 G2 source ref 的类型，
也不能把 G1/G2 public ref 转成 common `QualifiedRefV1`。缺 fresh nonce/namespace、重复、
碰撞或类型/层不一致时输出 `AbsentFreshCandidateBindingEnvelopeV1` +
`terminal_deferred` 或 `FailedFreshCandidateBindingEnvelopeV1` + `fail_closed`。

因此 A 是“可在父任务审查后派发”的独立前置工作单；本审计本身保持 envelope absent。
最终 candidate identity/hash 仍须由后续 identity owner 根据完整新鲜 Genome/source 输入重建，
不能由 A 或轴 attestation 顺手生成。

## 有限工作单 A：FreshCandidateBindingEnvelopeV1

工作单 ID：`AD45-FRESH-CANDIDATE-BINDING-ENVELOPE`；状态：
`proposed_ready_after_parent_review`；Luna/high 实现，另一个不同 Luna/high 独立复核。

精确产品为 2 件：

1. `docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json`
2. `docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/envelope_receipt.json`

输入是 AD42 W0 两层 public envelope、AD42 W2R1 四件冻结产品及独立 pass_limited
review、AD43 四份 source-only axis contract、当前五字段 public `GenomeContractRef`、
namespace/UUID 或 nonce 发生器及其独立 freshness receipt。AD42
`fresh_seed_binding_recipe.json` 只作为 machine-level read-only negative control 和
上下文闭合输入：A 的正向生成器不得读取其 seed、commitment、namespace 或 nonce 作为
common ref 的派生输入或熵源；若测试证明发生读取、alias 或派生，必须 `fail_closed`。
输出
联合为 `FreshCandidateBindingEnvelopeV1 | AbsentFreshCandidateBindingEnvelopeV1 |
FailedFreshCandidateBindingEnvelopeV1`；envelope content hash 可以作为 envelope receipt
的内容寻址值，但不得创建 candidate hash 或 declaration hash。

退出门：common ref 为实际 `QualifiedRefV1` 且 version/namespace 合同闭合；G1/G2
public refs 精确相等并保留各自类型；nonce/UUID 与 namespace 可复放且不复用；payload、
declaration、axis、final-candidate hash 不在生成输入或算法中；缺失/冲突结果正确；
直接 JSON/hash/path/control、PID/UTC/exit/raw、task-owned cleanup 和不同 Luna 复核齐全。
禁止边为 B、factory receipt、identity promotion、T0/T1/T2、UP2、provider/mesh/solver/
physical/search/R01-R10，以及修改 core、task manifest、源码、测试、fixture、AD42/43 产品。

A 的 machine-level negative-control vectors 必须在实现前冻结，并逐项形成 raw receipt；
每项 receipt 必须记录 exact input perturbation、canonical input SHA、namespace、
nonce/UUID、allocator generation/CAS token、可信时间来源、观察到的 result-union
分支、failure semantics、`candidate_ref_published=false`、命令/PID/UTC/exit/stdout/
stderr/artifact hashes。所有控制都禁止发布 candidate ref：

| 控制 | 输入扰动与可测向量 | 预期 result union 与语义 |
|---|---|---|
| UUID/nonce collision | 在同一 namespace 注入已提交 allocation 的完全相同 UUID/nonce 与不同 request id | `FailedFreshCandidateBindingEnvelopeV1` + `fail_closed`；若 allocation ledger 缺失而无法判定碰撞，则 `AbsentFreshCandidateBindingEnvelopeV1` + `terminal_deferred`，两种情况都不发布 ref |
| envelope replay / nonce reuse | 重放同一 envelope canonical bytes、nonce、namespace 和 commit token，第二次使用 fresh request id | 已发现已提交 envelope 时 `Failed...` + `fail_closed`；replay ledger/commit record 缺失时 `Absent...` + `terminal_deferred`；不得以 replay 当作 fresh ref |
| concurrent dual-write / CAS conflict | 两个 writer 对同一 namespace 和相同 expected generation 并发提交不同 UUID/nonce 或相同 nonce；只允许一个 CAS winner | 失去 CAS 的 writer 必须 `Failed...` + `fail_closed`；若原子 allocator/CAS 能力不存在则 `Absent...` + `terminal_deferred`；不能以 exit timing 或 wall clock 选 winner，不能发布 loser ref |
| wall-clock rollback / future skew | 将 wall clock 分别回拨、跳到未来、跨时区或给出不可信 timestamp，同时保持 monotonic allocator sequence 与 UUID/nonce 不变 | 时间不参与 identity derivation；若 freshness evidence 仅因不可信时钟无法闭合，`Absent...` + `terminal_deferred`；若实现尝试用时间生成/改写 common ref，`Failed...` + `fail_closed` |
| AD42 seed misuse | 把 W0 `fresh_seed_binding_recipe.json` 的 seed/commitment/namespace/nonce 注入 allocator、替换 fresh UUID/nonce 或制造相同 ref | 任何读取、派生、alias 或熵源使用均为 `Failed...` + `fail_closed`；recipe 缺失只使该负控执行为 `Absent...` + `terminal_deferred`，绝不能把 seed 当作正向输入或发布 ref |

上述负控是 A 的 machine-level exit gate，不是文档建议。正向 ref 只来自独立 fresh
namespace 与 UUID/nonce；wall clock 只能作为 receipt metadata，不能参与 identity。负控
失败历史必须 append-only 保留，不能用后来通过覆盖早期 collision/replay/CAS/clock
失败。R1 的 `changes_requested` 报告与其 raw sidecars 继续保持原路径和字节不变。

## 有限工作单 B：G1/G2 candidate-bound provenance axes

当前“G1/G2 四个轴”在语义上必须按每一层四轴处理：`payload_schema`、
`canonicalization_profile`、`applicability_profile`、`evidence_receipt`。AD43 的四个产品
包含一个共享 schema 加三个 layer-specific records；共享 schema 不是 `layer=G1|G2`
的 candidate axis，不能凭空再造第五种层。因此 B 拆为两个 disjoint 子单，各生成该层
四轴的一份 candidate-bound attestation，共 8 件产品；共享 AD43 schema 作为每份记录的
共同 schema input/reference。这样避免把 AD44 中“four candidate-bound axis records”
误读成只绑定三处缺口，也避免把共享 schema 伪装成第三层。

### B-G1

ID：`AD45-G1-CANDIDATE-BOUND-PROVENANCE-AXIS-ATTESTATIONS`；依赖 A、AD44 W3-A
四件冻结 authority record、W2R1 G1、AD43 shared/G1 contracts，以及独立 fresh source
record、source identity review 和最终 identity owner 提供的 candidate identity hash；
不同 Luna/high 对输入冻结和结果独立复核。

精确产品为 4 件，分别是：

1. `docs/implementation/AD-45/G1-CANDIDATE-BOUND-AXES/payload_schema_attestation.json`
2. `docs/implementation/AD-45/G1-CANDIDATE-BOUND-AXES/canonicalization_profile_attestation.json`
3. `docs/implementation/AD-45/G1-CANDIDATE-BOUND-AXES/applicability_profile_attestation.json`
4. `docs/implementation/AD-45/G1-CANDIDATE-BOUND-AXES/evidence_receipt_attestation.json`

### B-G2

ID：`AD45-G2-CANDIDATE-BOUND-PROVENANCE-AXIS-ATTESTATIONS`；依赖 A、AD44 W3-A
四件冻结 authority record、W2R1 G2、AD43 shared/G2 contracts，以及独立 fresh source
record、G2 `GenomeContractRef`→common `QualifiedRefV1` mapping receipt、source identity
review 和最终 identity owner 提供的 candidate identity hash；不同 Luna/high 独立复核。

精确产品为 4 件，分别是：

1. `docs/implementation/AD-45/G2-CANDIDATE-BOUND-AXES/payload_schema_attestation.json`
2. `docs/implementation/AD-45/G2-CANDIDATE-BOUND-AXES/canonicalization_profile_attestation.json`
3. `docs/implementation/AD-45/G2-CANDIDATE-BOUND-AXES/applicability_profile_attestation.json`
4. `docs/implementation/AD-45/G2-CANDIDATE-BOUND-AXES/evidence_receipt_attestation.json`

每份输出使用 `CandidateBoundProvenanceAxisAttestationV1 |
AbsentCandidateBoundProvenanceAxisAttestationV1 |
FailedCandidateBoundProvenanceAxisAttestationV1`。输入中的 candidate ref 必须精确等于
A 的 common ref；public contract、source record hash、source identity hash、candidate
identity hash、attestation ref、fresh W2R1 receipt hash 和 axis ref/version 必须逐字段闭合。
B 不生成 candidate identity/hash；只消费 identity owner 的独立值。缺任一必需 fresh 输入
输出 typed absence + `terminal_deferred`；层、ref、hash、attestation、seed 或历史来源
冲突输出 `fail_closed`。AD43 shared schema 只能作为共同 contract reference，不能被
重命名成 G1/G2 axis 或提升 authority。

B 的退出门是 A envelope 冻结、AD44 W3-A 产品冻结、每层四轴各一份独立 attestation、
G1/G2 均使用同一 common ref、G2 mapping 保持 `GenomeContractRef` source type、source
change 强制新 identity、所有 hash 可重算、无 payload/declaration/axis hash 派生 candidate
identity、direct receipt 和不同 Luna review 完整。B 当前仍 `blocked`，因为 A、W3-A、fresh
source/identity inputs、G2 mapping 和 candidate-bound attestations 均不存在。

禁止边：AD44 W3-B same-candidate join/final provenance promotion、factory receipts、
fresh identity review 的生成、AD37 publication、T0 authority recheck、T1/T2、UP2、
provider/mesh/solver/physical/search/R01-R10；不得把 B 写回 T0 或把 parent/T0 typed
absence CAS 为 present。

## 当前结论

本单最终状态为 `readiness_audit_only`、`accepted=false`。A 的独立 UUID/nonce+namespace
来源在当前类型合同下可行，建议先派发并由不同 Luna 复核；B 必须等 A、W3-A、独立 source/
identity inputs 和 G2 mapping，且按 G1/G2 每层四轴拆成 8 件。当前 present、candidate
identity、declaration hash、T0/T1/T2、provider、mesh、solver、engineering、physical、
search、R01-R10 和 L4 credible count 全部保持 false/0。
