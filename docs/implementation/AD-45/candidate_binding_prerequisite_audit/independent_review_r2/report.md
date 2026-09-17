# AD-45 candidate binding prerequisite audit — independent review R2

日期：2026-09-15  
复核者：different gpt-5.6-luna/high independent reviewer  
结论：pass_limited  
A 派发裁决：dispatchable_after_parent_review  
范围：static_readiness_audit_only

本复核只审 AD-45 修复后的三件产品，未修改 report.md、manifest.json、
cleanup_inventory.md，也未修改 R1 review、源码、测试、fixture、core 或
task_manifest.json。未执行 A/B、T0/T1/T2、provider、mesh、solver、physics、search。

## 定点输入闭合

修复后三件被审产品逐字节匹配父任务给出的冻结值：

- report.md：13328 bytes，SHA-256
  2f4f99bc16d4056c4e69a4c2e60e3b5bf789cf6ebd698f27dafed5f15e35735b
- manifest.json：10280 bytes，SHA-256
  203168dcc2fa7c96f7a8b8a5a5ab7f6b1f74590f6ea2d39adb95ef661ea03d6b
- cleanup_inventory.md：1022 bytes，SHA-256
  ce50f6b6114a0040b4314d70833496072e2137d055cdf73bf20bd6eccc5845b7

独立直接核验使用 D:/Users/Newman/anaconda3/python.exe / Python 3.13.5，PID
37524，UTC 2026-09-15T11:28:02.322931+00:00，exit 0。验证覆盖三件产品
hash、exact product count、A/B future path absence、A result union、A 的五类控制
向量、六类 raw receipt 字段、seed guard、B blocked、same common ref、G2 mapping、
外部 identity 输入、task manifest hash 和所有 false claim flags。raw stdout 为
review/direct_validation_stdout.json，711 bytes，SHA-256
b7644b506973c031fd2244eec76d42cc71a9902eb2f13c6a8adbbfc78dbfaaab；stderr 未产生。

第一次直接核验因复核器自身把 external identity owner wording 判错而失败，PID
72416 的原始失败保留于 review/direct_validation_attempt1_failed.json；更早的
direct_validation_attempt1.json 也保留为 append-only 历史。修正谓词后最终检查
全项通过，未改变任何被审输入。

规划校验子进程 PID 25396，UTC
2026-09-15T11:28:19.866371+00:00–2026-09-15T11:28:20.116539+00:00，exit 0；
31 markdown、497 links、39 tasks、DAG acyclic。raw stdout 343 bytes，SHA-256
a60a05cff7db64a5ea68a50b0cfc42208d8b4aaadbc947f233b28e2ee500bf13。scoped
git diff --check 子进程 PID 78132，UTC
2026-09-15T11:28:19.870115+00:00–2026-09-15T11:28:19.904462+00:00，exit 0，
stdout/stderr 均为空 raw stream。

## A 负控复核

修复已把 AD-42 fresh_seed_binding_recipe.json 明确标记为
read_only_negative_control_only，derivation_allowed=false；manifest forbidden
edges 进一步禁止其作为 namespace、nonce、common-ref、candidate-identity 熵源或
派生来源。正向 common ref 只允许来自独立 fresh namespace 加 cryptographic
UUID/nonce，保持 QualifiedRefV1；G1/G2 public refs 仍分别保持原始五字段
GenomeContractRef，不能 alias。

逐项复核的 machine-level vectors、输入扰动、结果联合、failure semantics 和
no-publish 要求均已冻结：

- UUID/nonce collision：已提交 allocation 的同 nonce/UUID 注入时为
  FailedFreshCandidateBindingEnvelopeV1 + fail_closed；无法判断 allocation 时为
  AbsentFreshCandidateBindingEnvelopeV1 + terminal_deferred；两者均不发布 ref。
- envelope replay / nonce reuse：同 canonical envelope、namespace、nonce 和
  commit token 的二次提交为 Failed + fail_closed；缺 replay ledger 为 Absent +
  terminal_deferred；replay 不得被当作 fresh。
- concurrent dual-write / CAS conflict：同 namespace、expected generation 的
  双 writer 只允许一个 CAS winner；loser 为 Failed + fail_closed，缺原子 allocator/CAS
  为 Absent + terminal_deferred；不能用 wall-clock 或 exit timing 选择 winner，
  loser 不发布 ref。
- wall-clock rollback / future skew：回拨、未来、跨时区或不可信 timestamp 下，
  monotonic allocator sequence 与 UUID/nonce 保持不变；时间不能进入 identity
  derivation。仅 freshness 证据无法闭合时为 Absent + terminal_deferred；尝试以时间
  生成或改写 common ref 时为 Failed + fail_closed。
- AD42 seed misuse：读取、派生、alias 或把 seed/commitment/namespace/nonce 作为
  allocator 熵源为 Failed + fail_closed；recipe 缺失只能使该负控为 Absent +
  terminal_deferred，不能成为正向输入或发布 ref。

每一项 raw receipt 均被要求记录 exact input perturbation、canonical input SHA、
namespace、nonce/UUID、allocator generation/CAS token、可信时间来源、观察结果
result union、failure semantics、candidate_ref_published=false、command/PID/UTC/
exit/stdout/stderr/artifact hashes；失败历史 append-only，不能覆盖早期 collision、
replay、CAS 或 clock 失败。R1 指出的两个派单缺口已在 report、manifest 和 cleanup
repair closure 中同步闭合。

A 的精确产品数为 2，result union 为
FreshCandidateBindingEnvelopeV1 / AbsentFreshCandidateBindingEnvelopeV1 /
FailedFreshCandidateBindingEnvelopeV1；输入、输出、depends_on、forbidden_edges、
退出门和不同 Luna 复核要求完整。A 仍只创建绑定句柄和 envelope receipt，不能创建
candidate/declaration hash 或 identity promotion。

## B 和依赖方向

B-G1 与 B-G2 均保持 blocked，各 4 件产品，共 8 件。两者都要求 A、AD44 W3-A、
W2R1、AD43 和独立 source/identity 输入；G2 额外要求显式
GenomeContractRef 到 common QualifiedRefV1 mapping，同时保持 G2 source ref 的
原始 GenomeContractRef 类型。

B 的 candidate identity hash 只能由外部 identity owner 提供，B never derives or
creates it。两层必须逐字段使用同一个 A common ref；缺输入为 typed absence +
terminal_deferred，层/ref/hash/attestation/seed/历史来源冲突为 fail_closed；source
change 强制新 identity。B 不创建 candidate/hash、不把 shared AD43 schema 伪装为
layer axis、不回写 T0/parent typed absence，也没有从 seed、fixture、history、
payload/declaration/axis hash 构造 identity 的路径。A、W3-A、fresh source/identity、
G2 mapping 和 candidate-bound attestations 仍不存在，因此 B 不可提前派发。

## 裁决

AD-45 修复满足 R1 的最小修复门，R2 verdict 为 pass_limited。A 可在父任务审查后
派发，并必须由另一不同 Luna 完成实现复核；B 继续 blocked。当前 envelope、
candidate/declaration hash、axis attestation、present、T0/T1/T2、provider、mesh、
solver、engineering、physical、search、R01-R10 和 L4 credit 均保持 false/0。
本复核只证明合同和软件证据边界，不替代工程或物理证据。

