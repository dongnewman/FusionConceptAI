# AD-44 RSDA W3 readiness audit — independent review R1

日期：2026-09-15  
复核者：different `gpt-5.6-luna/high` independent reviewer  
结论：`pass_limited`   
范围：`static_readiness_audit_only`

本复核只判断 AD-44 是否准确划分了 W3-A 的可派发边界与 W3-B 的实际阻塞，未执行
W3、未生成 authority record、candidate binding、axis attestation、candidate
identity/hash、T0/T1/T2、provider、mesh、solver 或 physical result。未修改 AD-44
审计输入、AD-42/AD-43 产品、源码、测试、fixture、核心索引或
`task_manifest.json`。

## 复核证据

AD-42 W2R1 四件冻结产品均逐字节闭合：G1 payload `6180` bytes /
`f4841efa7e872a57e05c8eda687d951dd7775802ad3d07330947df72c5c97449`，G1 receipt
`13968` / `46d7329bd83188c280208b65ac58afc571c813c9d48e3732707dcf4d4bcb4210`，G2
payload `7086` / `7244861fa4c640035c06ac7b69623f048c17b86f9deeda71de8406c452bbcacf`，
G2 receipt `14337` / `7a68be8d2e24b6a15364800cb3855c6a3d80b6d03bed6e2f9eb59d1b29cd988c`。
四件产品均为无 terminal LF 的 sorted compact canonical JSON；G1 的 candidate ref
保持 `QualifiedRefV1`，G1/G2 public contract ref 保持 `GenomeContractRef`，G2
`contract_ref` 保持其原始 `GenomeContractRef` 值形状。G2 common mapping target
仍为 `typed_absent`/`null`，两层 candidate identity 未创建且 declaration hash
为 null。

AD-42 W2R1 different-Luna 复核为 `pass_limited`、`47/47`，AD-43 四轴产品
different-Luna 复核为 `pass_limited`、`90/90`。AD-43 四轴 source-only 合同的
candidate-bound 字段仍全部 null，状态为 `typed_absent`，缺失策略为
`terminal_deferred`；四个 source/schema bytes 与记录中的 bytes/SHA 闭合。

我的最终独立复跑使用 `D:\Users\Newman\anaconda3\python.exe` / Python `3.13.5`，
仓库根目录 PID `15008`，UTC `2026-09-15T10:58:29.707649Z` 至
`2026-09-15T10:58:29.708724Z`，exit `0`。最终 raw stdout 为
`review/validation_stdout.json`，5743 bytes，SHA-256
`ecd250dd2bb097e1cdbac8d5636a45a022cce28e09568a4f45553419d39bf481`；stderr 为
空 raw stream，SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。该复跑确认
JSON/canonical/no-LF、四件 W2R1 bytes/SHA、AD-42/AD-43 独立门、W3 产品缺失、
W3 结果联合、依赖方向、禁止边、claim flags、源 API、39 tasks 与 task manifest
SHA、规划校验和 `git diff --check`。

规划校验由子进程 PID `82224` 执行，UTC `2026-09-15T10:57:43.331946Z` 至
`2026-09-15T10:57:43.787899Z`，exit `0`；31 markdown、497 links、39 tasks、DAG
acyclic。raw stdout `review/plan_validator_r2_stdout.txt`，401 bytes，SHA-256
`cf4058eae2fcca17ca5cdfa4207f0caf0451e9299254edf56fe875f4fe283bf7`；stderr 为空。
`git diff --check` exit `0`，其 stderr 只有现有工作树的 LF/CRLF 警告，不是 diff
错误。复跑时观察到 329 条 dirty status 行；AD-44 原审计的 328 行是更早快照，
新增的独立复核目录本身即可解释该增量，未把它误判为源或合同漂移。

曾保留三轮修复性复跑的 raw sidecars：第一次因 Windows 默认 GBK 解码规划校验
输出而出现 `UnicodeDecodeError`（PID 未形成最终 receipt）；第二轮全量闭合仅因
复核器把 G1 public ref 错判为 `QualifiedRefV1`、并把 G2 raw value 要求成带
`type` 字段而 exit `1`；第三轮已明确正确类型并保留 exit `1` 的原始结果。它们
均未修改任何被审输入；最终 R1 以修正后的类型语义重新通过。

## W3-A 判断

`AD44-RSDA-W3-SOURCE-AUTHORITY-RECORDS` 的四件产品、三值 result union、输入、
输出、依赖、禁止边、退出门和 task-owned cleanup 均闭合。它清楚区分 payload、
schema/factory source、source body、HEAD/path/exact bytes、semantic hash、
applicability/profile 与 AD-43 axis contract 引用，并要求缺失为
`AbsentRepositoryDesignSourceAuthorityV1` + `terminal_deferred`、冲突为
`FailedRepositoryDesignSourceAuthorityV1` + `fail_closed`。W3-A 不依赖 W3-B，
与 parent baseline、T0 recheck 和 G3 edit precursors 的并行关系无环；因此其有限
边界可在父任务审查后派发。该判断只是 readiness，不能把四件未来产品当成已存在。

## W3-B 判断

`AD44-RSDA-W3-CANDIDATE-BINDING-PROVENANCE` 的八件产品和结果联合定义完整，且
明确依赖 W3-A。它保持状态
`proposed_blocked_common_candidate_identity_and_axis_attestation`，阻塞项准确为：

1. 不存在独立提供的 `FreshCandidateBindingEnvelopeV1` 与 common `QualifiedRefV1`；
2. 四个 candidate-bound axis attestation 不存在；
3. 最终 candidate identity/hash 必须留在本工作单之外。

AD-42 seed、payload hash、declaration hash、axis hash、fixture、legacy 或 historical
receipt 只能作为来源/负控，不能伪造 common candidate identity、mapping 或四轴
attestation。用这些值推导绑定应 `fail_closed`；缺输入应保持
`AbsentCandidateBoundRepositorySourceProvenanceV1` + `terminal_deferred`。因此
W3-B 不应提前派发，也不能把自身 binding 反向注入 T0 或将 parent/T0 typed absence
CAS 成 present。

## 裁决

AD-44 原审计的裁决准确：`pass_limited` 仅覆盖静态 readiness。W3-A 可在父任务审查
后进入调度；W3-B 保持 blocked。当前 present、T0/T1/T2、provider、mesh、solver、
engineering、physical、search、R01–R10 和 L4 credible count 均不获得任何信用。
39-task manifest hash 保持
`7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`，DAG 校验不等同
实现、工程或物理证据。
