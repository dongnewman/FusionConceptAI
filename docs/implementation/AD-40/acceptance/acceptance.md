# AD-40 RepositoryDesignSourceAuthorityV1 架构裁决

日期：2026-09-15  
裁决范围：`architecture_and_finite_work_order_boundary`   
状态：`accepted_limited`  
实现状态：`not_dispatched`  
观测 HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`

## 裁决

基于 AD-40 原始提案、repair R1 的证据闭合以及不同 Luna 的
`independent_review_r2=pass_limited`，接受 `RepositoryDesignSourceAuthorityV1`
的架构边界和七个有限 work-order contract。该裁决只授予仓库设计源的软件来源
可追溯性：未来在各自工作单的产品、直接运行收据、冻结输入、不同 Luna identity
review 和复核全部通过后，才可讨论
`authority_class=repository_design_source`、`claim_ceiling=software_source_provenance_only`
的 source provenance 记录。

本裁决不接受任何实现或未来工作单的完成；七个 work-order 仍分别为
`proposed`（AD37 publication work-order 为
`proposed_blocked_until_identity_reviews`），必须各自实现、清理、自检并由不同
Luna 独立复核。并行中的 W2 或其它工作单产物不回填本裁决点，也不能由本裁决
推导 candidate identity、candidate hash 或 present。

## 明确保留的缺口与 claim ceiling

当前没有 candidate declaration payload、authority record、candidate binding、
factory receipt 或 fresh identity review；因此 `present=false`、`T0=false`、
`T1=false`、`T2=false`。仓库设计源的未来软件声明不能替代 external reference
truth、实验测量、provider capability、mesh、solver convergence、engineering
closure、manufacturability、control safety、physical net output、originality 或
任何 R01–R10 信用。上述维度继续保持 pending/blocked，并依现行合同记录
`terminal_deferred`、`unsupported`、`program_exception`、`fail_closed` 或实际
运行结果。

## 七个有限工作单

1. G1、G2 source payload authoring 可并行；必须基于 fresh public contract 和
   fresh authoring seed 生成 candidate-specific canonical payload，禁止 fixture、
   synthetic、legacy、historical receipt，且不得生成 candidate hash。
2. G1/G2 source authority records 在各自 payload 后并行；必须分开记录
   schema/factory source 与 payload 的 HEAD、路径、字节长度和 SHA-256。
3. candidate binding/provenance 在两层 authority record 后并行；四轴必须独立
   来源，G2 的 `GenomeContractRef` 到 `QualifiedRefV1` 映射保持 typed。
4. factory receipts 在 binding/provenance 后执行；只允许 direct focused command，
   重算 source/declaration body，provider、mesh、solver、physical 调用数必须为零。
5. fresh identity reviews 必须由不同于 author/implementer 的 Luna 从冻结输入重建
   identity，并完成同候选跨层 join。
6. AD37 publication input 只能在 identity reviews 通过后进行，仍不得调用
   T0/T1/T2、provider、mesh、solver、physical 或宣称 R01–R10。
7. 所有工作单都必须把 raw stdout/stderr、PID、UTC、exit、输入/输出 hashes 和
   review 证据放入各自 `archive/**`、`review/**` 或 `status_sync_*/**`；产品路径
   不得藏入 evidence sidecar。

完整路径、输入输出、result union、依赖、禁止边、退出门和精确产品文件清单以
[AD-40 原始 manifest](../repository_design_source_authority_architecture/manifest.json)
为准；本裁决的冻结输入、验证运行和 hashes 记录在同目录
`manifest.json`。

## 验收证据与清理

本裁决记录 15 个冻结输入、repair R1 manifest 和 independent review R2 的精确
字节数/SHA-256。新增验证覆盖 JSON parse、输入/repair/R2 hash 重算、路径归属、
控制字符、声明差异、七工作单 DAG/禁止边、false-claim flags 和 acceptance
文件范围；每次运行均保留 stdout、stderr、PID、UTC、exit 和输出 hash 的 append-only
sidecar。验证只证明架构和证据范围闭合，不执行 Julia、DESC、provider、mesh、
solver 或 physical workloads。

清理只允许删除本任务自有临时文件；历史失败收据、原提案、repair、两轮独立
review 和其它 agent 的 dirty work 均保留。任何歧义文件均 `cleanup_deferred_ambiguous`，
不作广泛删除或回滚。

