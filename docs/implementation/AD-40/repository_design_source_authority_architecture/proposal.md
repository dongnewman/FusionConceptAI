# AD-40 RepositoryDesignSourceAuthorityV1 架构提案

日期：2026-09-15  
状态：`proposal` / `accepted=false` / `implementation_not_dispatched`  
观测 HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`

## 1. 决策问题与当前边界

AD-37/AD-39 的外部来源阻塞是真实的：当前 G1/G2 V1 只有 schema、typed
payload、factory 形状和 contract-only receipt；fixture、synthetic transport、
legacy receipt、ref-only record 和历史运行都不能充当 candidate-specific source
authority。AD-33 parent binding 与 AD-34 T0 authority recheck 因而仍只能输出
typed absence。AD-40 提议一个 additive 的 `RepositoryDesignSourceAuthorityV1`
（简称 `RSDA-V1`）：把仓库内新建、候选专属、规范化的 declaration payload
作为软件设计源的权威对象，并用不可变 receipt 把它与 schema/factory 源、公共
contract、四轴 provenance 和后续 factory 重建连接起来。

本提案只定义边界和有限后续工作单。它不创建 payload、candidate identity、
source hash、declaration hash、T0 record、present result 或任何 machine node；
本次目录之外的实现、测试、AD-37 publication 和 core synchronization 均不在
本任务写入范围。

## 2. 权威对象的分层

`RSDA-V1` 必须把以下三类字节分开记录，不能把源码文本或 schema 常量当成
candidate declaration payload：

| 层 | 角色 | 允许证明 | 禁止证明 |
|---|---|---|---|
| schema/factory source | `schema_factory_source` | 解析器、类型、factory API 和 canonicalization 实现的可复查来源 | candidate 内容、candidate identity、物理或 provider authority |
| candidate declaration payload | `candidate_declaration_payload` | 某一 fresh candidate 的 G1/G2 声明语义及其精确 canonical bytes | 实验/参考对象真实性、mesh/provider、物理收敛 |
| receipt/provenance | `software_source_receipt` | payload 在指定源码、HEAD、schema、canonicalization、applicability 和公共 contract 下可重建 | 工程可制造、数值求解、实验或 R01–R10 |

G1 payload 应能完整重建 `G1DiffusionSourcePayloadV1` 及其 declaration body；
G2 payload 应能完整重建 `G2MBSourceV1`、chart/metric/boundary/mesh-plan 的
声明值及其 source body。payload 的 `candidate_ref`、layer、source ref、
source version、four axes 和适用域都是内容的一部分。G2 的 `source.candidate_ref`
仍是 `GenomeContractRef`，必须另有 candidate-binding envelope 映射到 fresh
`QualifiedRefV1`，不能重解释或 alias。

未来 `source_authority_record.json` 至少包含：

1. `authority_class=repository_design_source`、layer、source role 和结果 union
   版本；
2. `repository_head`、payload 相对路径、working-tree/HEAD 状态、exact byte
   length、exact-byte SHA-256、canonical JSON bytes 规则和 semantic body hash；
3. schema/factory source 的 path、HEAD byte receipt、schema URI/version/hash、
   canonicalization profile/hash；该源码收据与 payload 收据必须独立；
4. applicability profile/ref/hash、单位/维度/拓扑/适用域及缺口分类；
5. fresh public `GenomeContractRef`、candidate binding、candidate-specific
   source record 和四个独立 provenance axes：
   `payload_schema_version`、`canonicalization_profile_version`、
   `grammar_applicability_profile_version`、`execution_evidence_receipt_version`；
6. authoring receipt、factory input/output references、recomputed declaration
   receipt、identity review reference 和 all input/output hashes；
7. explicit exclusions：`fixture=false`、`synthetic=false`、`legacy=false`、
   `historical_receipt_reused=false`、`candidate_hash_created=false`（本架构阶段）。

`repository_design_source` 不是“外部实验权威”的别名。源文件和 payload
必须是新建的 candidate-specific canonical data；改变 G1/G2 payload、source
ref、schema/canonicalization/applicability 或公共 contract 必须开新的
candidate identity、重建受影响 upstream receipts，并重新走独立 review。
旧文件和历史收据 append-only 保留，不能原地换标签。

## 3. claim ceiling 与外部权威判断

对**软件设计源**，仓库 design authority 足以在所有后续门通过后把该层标为
`source_backed_present`，但只代表“仓库内候选声明可由指定源码和规范化 payload
重建”。推荐的 result union 仍保持 AD-39 的
`PresentBaselinePublicationV1 | AbsentBaselinePublicationV1 |
FailedBaselinePublicationV1`，其中 present record 必须显式带
`authority_class=repository_design_source` 和
`claim_ceiling=software_source_provenance_only`，避免把 `present` 读成实验或
物理 present。

该 authority 不足以提供下列任何信用：external reference truth、真实逆问题
可识别性、provider capability、mesh existence、solver convergence、engineering
closure、manufacturability、control safety、physical net output、originality，
或 R01–R10/L4。AD-39 的真实外部阻塞因此被拆成两类：

- 若目标只是软件 source-backed G1/G2 baseline publication，后续 RSDA 实施可
  消除“必须由仓库外部主体供给 source bytes”的阻塞；不需要额外用户授权，
  因为这是本仓库设计源的声明，不是替用户声称实验事实。
- 若目标包含参考对象、实验测量、真实 provider/mesh/工程或物理结论，仍需
  相应外部来源或实测证据。RSDA 不能替代这些输入；它们必须继续以
  `terminal_deferred`/`unsupported`/`physical_fail` 等独立维度记录。

当前 AD-39/AD-37 仍保持 `proposed_blocked_external`/`present=false`，直到
AD-40 的后续实现与不同 Luna 复核被接受；本提案本身不改变这些状态。

## 4. 有限后续顺序

以下是 future work-order boundary，不是 task-manifest machine nodes。G1/G2 的
同阶段工作可并行，但任何 T0 join 都必须等两层使用同一 fresh candidate binding
和同一公共 contract，且 G1/G2 各自的 identity review 完成。

### A. source payload authoring（G1 与 G2 并行）

输入是已接受的 V1 schema/factory source、fresh public contract、candidate
authoring seed 和四轴版本要求；输出是新的 canonical candidate declaration
payload 与 authoring receipt。不得读 fixture/legacy/historical receipt 生成
payload，不生成 candidate hash。缺输入为 typed absence/`terminal_deferred`，
冲突或 canonicalization 不一致为 `fail_closed`。

### B. source authority record（各层在自己的 payload 完成后）

直接读取 exact payload bytes，记录 repository HEAD/path/byte hash/schema/
canonicalization/applicability 和 source-vs-payload 分层，输出
`RepositoryDesignSourceAuthorityRecordV1`。记录本身不改变 payload，不创建
candidate identity，也不把源码 hash 当 declaration hash。

### C. candidate binding / provenance（G1 与 G2 可并行）

将 authority record 精确绑定到 fresh candidate/public contract，分别生成四轴
provenance record；G2 另生成
`GenomeContractToQualifiedRefMappingReceiptV1`。缺轴、alias、layer 或 candidate
不一致分别进入 `terminal_deferred`/`fail_closed`；没有同候选 join 不能进入 T0。

### D. factory receipt（G1 与 G2 可并行，但只能在各自 B/C 完成后）

在冻结所有输入后以 direct focused command 调用现有 typed factory，重新读取
payload 并重算 source/declaration body；产出 factory receipt 和 declaration
receipt。factory receipt 必须区分 `schema_factory_source` 的 hash 与
`candidate_declaration_payload` 的 hash，并声明 provider/mesh/solver/physical
调用为零。异常是 `program_exception`；字节、candidate、公共 contract、四轴
或 body hash 冲突是 `fail_closed`。

### E. different-Luna fresh identity review（G1/G2 各自独立）

不同于 author/implementer 的 Luna 从冻结输入重建 layer-local source,
declaration, parent-binding, child/state/receipt identity；再生成一个只读的
same-candidate cross-layer join check。任何 source 改动、公共 contract 改动、
旧 receipt 复用或 identity 不一致都拒绝并要求新 candidate。该 review 不执行
T0/T1/T2、provider、mesh 或 physics。

### F. AD-37 publication（最后按层）

只有 E 通过后才可把 RSDA record 作为 AD-37 publication 的 source authority
input。G1/G2 sibling 互不依赖；两者在同 candidate join 后才可提交 T0。publication
仍输出 AD-39 union，并保留 software-only claim ceiling。AD-37 不因 RSDA 自动
解锁 T0 authority recheck、T1、T2 或 UP2。

## 5. Work-order contracts

下列每单的精确未来产品路径、输入、输出、union、依赖、禁止边、退出门和清理
规则已在同目录 `manifest.json` 中机器化列出。每单的 raw stdout/stderr、PID、
UTC、exit、input/output hashes、独立评审和 cleanup receipt 只能放该单的
`archive/**`、`review/**` 或 `status_sync_*/**` sidecar；sidecar 不计产品数且
不能藏入 source/test/fixture/static-QA/launcher/product payload。

所有未来工作单的共同禁止项是：修改 core/README/00/10/14/16/18、修改
`task_manifest.json`、新增 machine node、重写旧 receipt、复用 fixture/synthetic/
legacy/historical 数据、生成未绑定 candidate hash、调用 T0/T1/T2、provider、
mesh、solver 或物理运行器，以及宣称 present、R01–R10 或 L4。

## 6. 验收结论

AD-40 当前仅为 `architecture_proposal`。它为 AD-39 提供了一个可审计的仓库
内 source authority 路径，使“软件 present”在未来可以不依赖仓库外部 source
owner；同时把经验/物理外部阻塞保留为真实独立缺口。只有未来产品文件、直接
运行收据、不同 Luna identity review 和 AD-37 publication 全部满足退出门后，
Sol 才能裁决是否接受该有限软件 claim。当前 `present=false`、T0/T1/T2=false、
provider/mesh/physical/engineering=false，B00/B04 和 R01–R10=false。
