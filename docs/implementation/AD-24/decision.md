# AD-24 架构裁决：N05/N06 cross-layer physical-binding authority

日期：2026-09-14。状态：`review_pending`。这是架构边界记录，不是实现或物理验收。

## 裁决

当前 actual `CandidateStatePackageV5` 缺少 N05 的权威 flux/traction/current endpoint、双端 sign、flux unit 与 G1/G2/G3 exact join；也缺少 N06 的 dimensioned source→field→return/heat/ledger/owner-scope mapping。N05/N06 provisional rows 继续保留为历史登记。缺 authority 的状态是 `terminal_deferred`；已存在的 typed 值若违反局部或显式声明不变量才是 `fail_closed`。

证据来自 [N05/N06 source audit](n05_n06_source_audit/source_audit.md)：

* `G2InterfaceV2` 只有接口 ref、region、axis/coordinate、normal、continuity 和 transfer kind。几何 `normal` 不能替代 flux sign，接口没有 flux port 或 unit。
* G1 equation/occurrence units 与 G3 V/A/W resource units 各有来源；现有源码没有可审计的 dimensioned conversion/source-to-field law。`eq.input_units[1]`、相同字符串或局部 G3 balance 都不能完成跨层物理映射。
* G3 局部 validator 能检查 resource port、account、entry、component、closure 的 typed 引用、单位、容量和 balance，但没有 G1 occurrence→G3 account/entry/energy-boundary authority。shared owner 合法，owner 字符串相同不等于 double count。

## 最小后续设计

后续可新增可编辑、candidate-owned、版本化且内容哈希的 `UP2CandidatePhysicalBindingV1`，输入只能是实际 `CandidateStatePackageV5`。bound identity 至少包含 candidate ref/package hash、三个完整公共 `GenomeContractRef`、三 component hashes、四轴和自身 schema/canonical/profile/binding hashes；binding hash 参与新 bound-input canonical identity，但不回写原 `CandidateStatePackageV5.candidate_hash`。G2 interface 的 v2 `QualifiedRefV1` 只能作为 wrapper 内 child locator，不能替代 G2 outer 完整五字段公共 `GenomeContractRef`。

N05 声明必须包含 authored typed flux/traction/current law，左右 endpoint refs、G2 interface child ref/regions、按 flux semantics 给出的双端 signs、每端真实 `UnitSignature`/provenance、G1 equation/operator/occurrence locator。N06 声明必须包含 typed conversion/source-field-return-heat/ledger owner-scope mapping，精确绑定 G1 occurrence/closure、G2 region/boundary、G3 port/entry/account/closure/link 和 dimension/unit transformation law。无来源或 mapping 就 deferred；已有声明的 ref、candidate、方向、sign、unit、容量或 closure 冲突就 fail-closed。

N05、N06、shared bound-input 的 source/fixture/test/receipt/checker 文件集合必须互不重叠。该 envelope 只提供 contract authority，不能推出 compiler/provider/mesh/engineering/physical closure。50 条 formal B04 receipts、UP2 总门和独立 Luna 复核仍 pending。

## 保留的父级边界

AD-24 不改变 UP0–UP6 DAG、任务状态、UP0–UP2 既有历史 rows、旧 V4 入口、default registry、旧 evidence、B00/B04 义务或 R01–R10。`accepted=false`；不授 implementation、provider、mesh、engineering、physical 或 R01–R10 信用。
