# AD-45 candidate binding prerequisite audit — independent review R1

日期：2026-09-15  
复核者：different gpt-5.6-luna/high independent reviewer  
结论：changes_requested  
范围：static_readiness_audit_only

本复核逐字检查了 AGENTS.md、v4 README、共同合同、AD-45 三件审计产品，以及
AD-44 readiness/report 与 R1、AD-42 W0/W2R1、AD-43 axis contracts、parent baseline
typed-absence 和 T0 authority-recheck typed-absence 边界。没有修改被审产品、源码、
测试、fixture、core 或 task_manifest.json，没有执行 A/B、T0/T1/T2、provider、
mesh、solver、physics、search。

## 直接复核证据

独立静态核验使用
D:\Users\Newman\anaconda3\python.exe / Python 3.13.5，PID 84132，UTC
2026-09-15T11:17:05.757707+00:00，exit 0。原始结果保存为
review/validation_stdout.json，2340 bytes，SHA-256
9efb40b0f155d25405b20fe21e9256e1c85622cf008bdd9a2f38a6b50665ce5e；stderr 为空，
SHA-256 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855。

该核验确认 AD-45 恰有 3 件产品，accepted=false、readiness_audit_only、
implementation_dispatched=false，A/B 未来产品路径当前均不存在；AD-42 W2R1 四件
产品及 AD-43 四件 axis 产品的 bytes/SHA-256、JSON 解析和无末尾 LF 全部闭合。冻结
W2R1 hashes 为 G1 payload 6180/f4841efa7e872a57e05c8eda687d951dd7775802ad3d07330947df72c5c97449、
G1 receipt 13968/46d7329bd83188c280208b65ac58afc571c813c9d48e3732707dcf4d4bcb4210、
G2 payload 7086/7244861fa4c640035c06ac7b69623f048c17b86f9deeda71de8406c452bbcacf、
G2 receipt 14337/7a68be8d2e24b6a15364800cb3855c6a3d80b6d03bed6e2f9eb59d1b29cd988c。
AD-43 axis products 的四个 bytes/SHA-256 与审计冻结值一致。

规划校验由子进程 PID 83980 执行，UTC
2026-09-15T11:19:07.283090+00:00–2026-09-15T11:19:07.701842+00:00，
exit 0；31 markdown、497 links、39 tasks、DAG acyclic。stdout raw 为
review/plan_validator_stdout.json，343 bytes，SHA-256
a60a05cff7db64a5ea68a50b0cfc42208d8b4aaadbc947f233b28e2ee500bf13；stderr 为空。
git diff --check 的最终复跑子进程 PID 85420，UTC
2026-09-15T11:19:29.071235+00:00–2026-09-15T11:19:29.175021+00:00，
exit 0；仅有既有 LF/CRLF warnings，raw warning sidecar 保留。一次先行的默认
GBK 解码尝试由 PID 29400 以 exit 0 结束但在读取 stderr 时发生
UnicodeDecodeError，该失败也保留为 append-only review sidecar，没有替代最终
UTF-8-safe 复跑。

## A：FreshCandidateBindingEnvelopeV1

A 的类型边界是正确的：QualifiedRefV1 只有 id/version，而 G1/G2 public
contract ref 必须各自保持五字段 GenomeContractRef；审计禁止把二者通过 URI、
版本或后缀 alias。A 也明确要求由独立新鲜 namespace 与 cryptographic UUID/nonce
产生 common QualifiedRefV1，不使用 W2R1 authoring ref、AD-42 seed、payload/
declaration/axis/final-candidate hash，且不产生 candidate identity/hash 或 declaration
hash。G1/G2 public refs 的精确绑定、三值 result union、缺失
terminal_deferred、冲突 fail_closed、task-owned cleanup、不同 Luna 复核和
禁止向 B/factory/identity/T0/T1/T2/UP2/provider/mesh/solver/physical/search/R01-R10
连边均已写明。因此 A 的架构方向可行，且不会制造循环。

A 目前不能直接派发。AD-45 文本只零散提到重复/碰撞和 freshness/non-reuse，A 的
machine manifest 与退出门没有逐项冻结以下必需的可复放负控及结果分类：

- 强制 nonce/UUID collision；
- replay 或 nonce/namespace reuse；
- 并发生成同一 namespace 下的重复/竞态；
- 时钟回拨、未来时间或时间戳不可信时的处理。

同时，A 将 AD-42 fresh seed recipe 列为输入，却未在 machine-level contract 中明确
它只作只读负控/上下文，生成算法不得读取其 seed/commitment 派生 common ref。报告
正文虽禁止 AD-42 seed，但该禁止应同步进入 A 的输入/forbidden/exit-gate 字段，避免
实现者从 manifest 误读出新的可派生来源。

修复门：补齐上述四类负控的 exact test vector、输入/输出/result union 与 raw receipt
要求；明确碰撞、重放、并发冲突和不可信时钟分别是 typed absence/terminal_deferred
还是结构冲突/fail_closed；将 AD-42 seed recipe 标为 read-only negative control 并
写入禁止派生项。修复后由不同 Luna 重新复核，才可把 A 标为
proposed_ready_after_parent_review 并派发。

## B：G1/G2 candidate-bound axes

B 的拆分和阻塞是正确的。G1、G2 各自四轴共 8 件产品，shared axis schema 只是共同
contract reference，不被伪装为 G1/G2 的第五轴。B 明确依赖 A、AD44 W3-A、W2R1、
AD43、独立 source/identity 输入；G2 还要求显式
GenomeContractRef -> QualifiedRefV1 mapping，并保持 G2 source ref 的原始类型。
candidate identity hash 由外部 identity owner 提供，B 不创建或推导 candidate/hash。

B 的 result union、same-candidate common ref equality、source/identity/attestation/
fresh-W2R1 hash closure、缺失 terminal_deferred、层/ref/hash 冲突 fail_closed、
source change 强制新 identity 及禁止回写 T0/parent typed absence 均闭合。当前 A、
W3-A、fresh source/identity、G2 mapping 与 candidate-bound attestations 不存在，故
B 保持 blocked，不能提前派发；也没有发现从 seed、fixture、history、
payload/declaration/axis hash 伪造 common ref 或 candidate identity 的路径。

## 裁决

静态审计的大部分结论通过，但 A 的派单合同缺少逐项 collision/replay/concurrency/
clock 负控和 seed read-only/非派生的 machine-level closure。因此最终 verdict 为
changes_requested，A 当前不可派发；修复 AD-45 合同并完成另一 Luna 复核后再派发。
B 继续保持 blocked。所有 present、candidate/declaration hash、T0/T1/T2、provider、
mesh、solver、engineering、physical、search、R01-R10 和 L4 credit 继续为
false/0。文档、测试、DAG 和进程退出码只证明合同核验，不能替代工程或物理证据。

