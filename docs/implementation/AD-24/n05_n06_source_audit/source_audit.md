# AD-24: N05/N06 source and authority audit

审计日期：2026-09-14（Asia/Shanghai）。本报告是只读架构审计，不是实现验收。审计在当前工作树 `HEAD=4b69f55f7f80240147a65a22809dc1207824dde2` 上完成；工作树已有大量与本工单无关的 dirty/untracked 文件，均未改动。审计开始时未发现本仓 Julia 或 DESC 进程；本工单没有启动 Julia/DESC，也没有生成运行证据。

## 判定

`changes_requested`（authority audit）。N05/N06 的五行 provisional rows 仍应保留为历史登记，不能升格为 B04 或物理合同。G3 资源网络拥有足够的局部 typed structural checks；N05 的 interface flux pair 与 N06 的跨层 source→field→return/heat/ledger join 缺少权威 typed mapping，因此缺失能力统一保持 `terminal_deferred`。当未来声明中的实际 typed 值违反已有局部不变量时，才使用 `fail_closed`；局部 validator 的通过不代表跨层 authority、mesh、provider、工程或物理执行。

## 被审实际对象和边界

* `CandidateStatePackageV5` 的实际 package 由现有 UP1-04A/N04/N10 fixture factory 以真实 G1、G2、G3 constructors 组合，再由 `integrate_genome_v5` 生成。package 携带 candidate ref、三层对象、version axes、component identity、candidate hash、fresh migration receipt 和 claim ceiling；fresh receipt 的 records 为空且状态为 pending。
* G1 的 `G1EquationV2`/`G1ResidualSemanticsV2` 实际携带 `input_state_refs`、`output_state_refs`、units、ranks、temporal/derivative/effects、typed expression、closure ref 和 `G1LedgerOccurrenceV2` occurrences。occurrence 的键含 equation、port side/index、ledger id；没有 G2 flux endpoint 或 G3 account 的精确 join 字段。
* G2 的 `G2InterfaceV2` 实际字段只有 `interface_ref::QualifiedRefV1`、左右 region id、axis、rational coordinate、normal、continuity、transfer kind。它没有 flux port、flux unit、flux sign、source id、return id、heat sink id 或 ledger owner；接口 ref 自身是 G2 typed qualified ref，不能被当作完整公共五字段 `GenomeContractRef`。
* G3 的实际 `G3ResourceNetworkV2` 携带 typed components、resource ports、accounts、entries、closures。`G3ResourcePortV2` 有 port id/kind/direction/unit/account id；account 有 id/domain/unit/owner；entry 有 entry/account/port/component/coefficient/unit/effect；closure 有 id/domain/account ids/expected balance。现有 actual-A fixture 只把形状门写成至少 6 accounts、7 entries、4 closures，测试以这些 lower bounds 检查，未在本次只读审计中重新运行或声称精确运行计数。G3 局部 validator 检查引用、单位、容量、必需 kind、closure domain 和 balance。它没有 G1 occurrence→G3 account/energy boundary 的版本化权威 mapping。
* G3 binding 的 control-resource link 可以解析 controller/sensor/actuator/resource/fault，feedback 具有 typed target ref 和 source id，但现有 binding validator 没有建立 G1 occurrence 到 G3 source/field/return/heat 的 exact join。

## 旧 provisional rows

UP2 现有 `TypedPrecompilerValidatorV1.jl:41-52` 仍登记五行 N05 和五行 N06。N05 使用 `/up2/flux_pair/*` 以及 `UP2FluxPairV1`；N06 使用 G3 resource ports、entries、control link、closure balance 和 resource kind。它们的 expected class 是协议登记，不是已获得 authority。现有 N05 projection 在 `TypedPrecompilerValidatorV1.jl:135-152` 将 ports 写成 `pending-port:left/right`，把 `interface.normal` 和 `-interface.normal` 当 signs，并把 `eq.input_units[1]` 当 pair unit；`port_source` 为 `:unverified`。这三处都不能作为真实 flux authority：interface normal 不是 flux sign，G1 equation input unit 不是 flux endpoint unit，pending port 字符串不是 endpoint。

## N05 field-by-field audit

| row | 当前实际 typed source | placeholder/synthetic portion | candidate/ref/hash/axis linkage | 现有局部 validator | 缺失 authority 与状态 |
|---|---|---|---|---|---|
| N05-01 left endpoint | G2 `G2InterfaceV2.left_region_id::String`，以及 G1 occurrence 的 port side/index/ledger id；两者无 exact join。 | `UP2FluxPairV1.left_port` 是 `"pending-port:left"`，不是 G2 endpoint 或 G1 flux port。 | package 可绑定 G2 outer ref/hash/axes，interface 有 v2 `QualifiedRefV1`；没有 endpoint ref/hash、同-candidate G1 occurrence mapping。 | `up2_flux_pair_valid` 只检查非空/成对等局部字段；`port_source=:unverified` 时 `_up2_real_classification` deferred。 | 缺实际 interface endpoint/port 与 G1 occurrence 的 source→field join；不能判物理 pair。缺 authority = `terminal_deferred`；未来 typed endpoint 空/错 ref 属 `fail_closed`。 |
| N05-02 right endpoint | G2 `right_region_id::String`；G1 occurrences 仍只提供自己的 typed occurrence identity。 | `UP2FluxPairV1.right_port` 是 synthetic pending string。 | 同上；左右 region id 不能冒充左右 flux ports。 | 同 N05-01。 | 缺 right endpoint、方向和来源 provenance；`terminal_deferred`。错误/重复/外部 endpoint 在 authority 存在后 `fail_closed`。 |
| N05-03 left sign | G2 `normal::Int8` 仅表示界面几何方向；G1 occurrence 有 Rational coefficient/effect，但没有 interface flux sign。 | 当前 UP2 用 `interface.normal` 直接填 left sign。 | normal 受 G2 candidate hash 间接绑定，但 sign 的物理/账本来源没有 ref/hash/axis join。 | 局部枚举/相反符号检查可拒绝 zero 或 malformed pair；不能证明 flux orientation。 | 缺 flux sign provenance，且不能把 normal 与 flux sign 等同；`terminal_deferred`。实际 typed sign 越界或与同 interface 规则冲突时 `fail_closed`。 |
| N05-04 right sign | 没有实际 right flux sign；G2 normal 不能提供它。 | 当前 UP2 用 `-interface.normal` 合成 right sign；“opposite sign”只是 wrapper 规则。 | 只有 G2 normal/axes/hash 的 candidate linkage；没有 right endpoint source/ref/hash。 | `up2_flux_pair_valid` 可检查 opposite-sign 形式，但仅对 synthetic wrapper 有效。 | 缺 pair 的双端 sign authority、端点和 transfer semantics；`terminal_deferred`。同号、零号或错 interface ref 在正式 authority 中 `fail_closed`。 |
| N05-05 unit | G1 `input_units`/`output_units`、G1 occurrence unit 及 G3 resource/ledger units 各自是真实 `UnitSignature`；G2 interface 没有 unit。 | 当前 UP2 取 `eq.input_units[1]` 作为 flux pair unit；这把方程输入 unit 错当 flux unit。 | 各层 hash/ref/axes 可独立绑定；没有 flux endpoint UnitSignature 的 typed source，也没有 G1 occurrence↔G2 interface↔G3 resource unit exact mapping。 | UP2 可做 pair 内 unit equality；G3 可做 resource kind 的 expected unit，但不能跨层 join。 | 必须独立记录 flux unit provenance；禁止用 equation input unit 或 region coordinate unit 代替。缺 mapping = `terminal_deferred`；实际 unit mismatch = `fail_closed`。 |

N05 的协议五类 mutation 仍为 `invalid_closure`/calls=0 的目标合同，但当前 actual A 只能证明 G2 结构有界面和 normal，而不能证明 interface flux/traction/current 已成对。没有 source-backed endpoint、sign、unit、return/account mapping 前，不应将任何 N05 行计为通过。

## N06 field-by-field audit

| row | 当前实际 typed source | placeholder/synthetic portion | candidate/ref/hash/axis linkage | 现有局部 validator | 缺失 authority 与状态 |
|---|---|---|---|---|---|
| N06-01 resource ports | G3 `G3ResourceNetworkV2.resource_ports::Tuple{G3ResourcePortV2}`；每个 port 有 id/kind/direction/unit/account id。 | 旧 row 的 `pending` 和缺失 source/return/heat 描述没有对应 source-backed cross-layer mutation。 | G3 realization outer ref/candidate hash/axes 绑定 package；resource port content 进入 G3 candidate hash。 | `g3_validate_resource_network` 检查 account resolution、kind expected unit、consumable entry、closure membership 和 required kinds。 | 没有 G1 source occurrence 到 source/field/return/heat 端口的 exact, versioned mapping；局部 network valid 仍只能 `terminal_deferred`。陌生 kind、缺 account/entry/closure 等 intrinsic error = `fail_closed`。 |
| N06-02 entries | G3 `G3LedgerEntryV2` tuple，字段为 entry/account/port/component/coefficient/unit/effect。 | 旧 row 仅用 tuple path，未指定哪条 entry 实际对应 G1 ledger occurrence 或 source/field/return/heat。 | entry 内容由 G3 hash 绑定；account/port/component refs 只在 G3 network 内解析。 | validator 检查 account/port/component 存在、account/port 一致、entry unit、capacity/passive source、closure balance。 | 缺 G1 occurrence ledger id→entry/account→energy boundary mapping 和 owner scope；`terminal_deferred`。跨引用/单位/容量/closure balance 的实际结构错 = `fail_closed`。 |
| N06-03 resource link | G3 `G3ControlResourceLinkV2.resource_port_id::String`，并带 controller/sensor/actuator/fault ids。 | 旧 row 的 “missing source binding” 未绑定实际 source field 或 G1 target。 | link 属 G3 binding hash；binding candidate/ref/axes 可验证，resource id 可在 G3 network 解析。 | G3 binding validator 检查 link refs、resource direction、controller ownership 和 fault/signal resolution。 | 没有 source→G1 field→G3 resource link 的 exact target/provenance，也没有 return/heat continuation；缺 authority = `terminal_deferred`。错误 resource id/direction/owner = `fail_closed`。 |
| N06-04 closure balance | G3 `G3LedgerClosureV2.expected_balance::Rational{Int64}`，closure account ids/domain 真实存在。 | 旧 row 的 index 0 只是 provisional locator；不能假设 closure[0] 是 G1 conservation account。 | closure 属 G3 network/candidate hash；无 G1 closure_ref 的 exact mapping（G1 closure_ref 是 String，语义域不同）。 | validator 计算 closure entries 的 Rational sum、domain、account existence。 | 缺 G1 equation closure/occurrence→G3 closure 与 energy boundary 的 authority；局部 balance 错可 `fail_closed`，缺跨层 join = `terminal_deferred`。 |
| N06-05 resource kind | G3 `G3ResourcePortV2.kind::Symbol`，允许 effort/flow/load/return/heat_sink/material，且 required kinds 由 G3 contract 声明。 | 旧 row `resource_ports/0/kind` 的 pending class 没有 source→field semantics。 | kind 随 G3 network/candidate hash 绑定；没有 G1/G2 flux/field source identity 或 G3 return/heat ownership join。 | validator 检查 enum、required set、expected unit 和 downstream entry/closure。 | 缺 “source→field→return/heat” 语义链与 owner scope；不能将 kind 枚举通过称为 N06 闭环。unknown kind/required kind missing = `fail_closed`；缺真实 source mapping = `terminal_deferred`。 |

## 关键链路审计

1. **flux 两端与相反号**：G2 只有左右 region 和 geometric `normal`。当前 `normal/-normal` 是 wrapper 合成值；没有 left/right flux endpoint、port id 或 sign source。不能使用 normal 替代 flux sign，也不能由左右 region 名称推导 endpoint。
2. **unit provenance**：G1 `input_units` 是方程输入 units；G1 occurrence unit 与 G3 port/account/entry units 是不同 typed sources。当前 fixture 中可见 G1 occurrence 的 dimensionless `temperature`/`energy` 类字段，而 G3 resource network 使用 W/V/A 等 source/load/return/heat units；相同的 `energy` 字符串或一个局部平衡的 G3 ledger 都不是跨层转换。源码中没有可审计的 dimensioned conversion 或 source-to-field law。`eq.input_units[1]` 不能成为 flux unit。未来 authority 必须记录 flux endpoint 的实际 `UnitSignature`、来源 ref/hash/path，并明确其与 G1 occurrence、G3 port/entry 的 join。
3. **source→field→return/heat**：UP0-02 的说明性关系是 `source_effort*source_flow -> source_power; load -> load_power; return_flow -> return_power; heat_sink -> heat_rejection`，并要求 source/actuator→G1 boundary、load→G1 field、return→source ledger、heat_sink→thermal ledger。当前 G3 validator 仅验证 G3 内部引用和余额，G1/G2 没有对应 typed target/return/heat mapping，因此该链路仍 `terminal_deferred`。
4. **ledger ownership**：G3 account 的 `owner::String` 可用于局部 account record，但 AD-22 已明确 shared owner 合法，字符串相同不等于 double-count。没有版本化 owner scope 和 G1 occurrence ledger id→G3 account/entry/energy boundary exact join 时，不能因同名 owner 拒绝，也不能因不同名接受；缺 authority 为 `terminal_deferred`。

## 最小 additive authority 建议

未来新增独立版本化集合（本审计不实现、不占用旧 UP2 文件）：

* `src/GenomeV5/UP2/N05N06InterfaceLedgerAuthorityV1.jl`
* `test/GenomeV5/UP2/n05_n06_interface_ledger_fixtures.json`
* `test/GenomeV5/UP2/n05_n06_interface_ledger_tests.jl`
* `test/GenomeV5/UP2/run_n05_n06_interface_ledger.jl`
* `docs/implementation/UP2-00E-N05-N06/`

输入只能是实际 A `CandidateStatePackageV5` factory。authority wrapper 要携带 package candidate ref/hash、三层公共 ref 的完整五字段、component hashes、四轴、schema/canonical/profile hashes 和自身 canonical hash。G2 interface 的 v2 `QualifiedRefV1` 只能作为 wrapper 内的 child locator，不能冒充外层公共 ref。

N05 projection 至少需要真实 `interface_ref`、左右 endpoint/port ref、left/right region、axis/coordinate/normal、双端 `UnitSignature`、双端 sign、transfer kind、G1 occurrence locator 和 source provenance。若 G2/G1 当前没有 endpoint/unit/sign source，应显式输出 authority gap/`terminal_deferred`，不得填 `pending-port`、normal-derived sign 或 equation input unit。

N06 projection 至少需要真实 G3 resource ports/accounts/entries/closures/links，以及版本化 G1 occurrence→G3 account/entry/source/field/return/heat mapping、owner scope、unit and balance rules。局部结构错误（unknown kind、bad ref、bad direction、unit/capacity/closure mismatch）独立 `fail_closed`；mapping/provenance/owner scope 缺失独立 `terminal_deferred`。共享 owner 的合法正例必须保留，不能把 owner 相等自报为 double count。

最小负控应覆盖：foreign/stale candidate/ref/hash/axis；同 interface 左右端点、region 或方向错配；normal 与 flux sign 混淆；缺 endpoint、同号/零号；用 G1 equation unit 冒充 flux unit；G3 entry account/port/component 错配；wrong resource direction/link；缺 return 或 heat sink；closure balance mismatch；缺 occurrence→account exact join；仅因 account owner 同名而误拒。每条 mutation 必须记录 baseline package hash、实际 source ref/hash/path/type/value、attempted value/hash、source-derived code/path 和 zero compile/provider/solver counters；fixture expected code 只能作 oracle。

## 结论和受限信用

本审计对 G3 局部 typed structural checks 给出静态可用性意见，对 N05/N06 跨层 authority 给出 `changes_requested`。可接受的最小范围是“source audit + future additive contract design”；当前没有 N05/N06 implementation acceptance，没有 B00/B04、provider、mesh、engineering、physical 或 R01–R10 信用。Julia/DESC lane 在本审计期间保持空闲并留给 N03 独立复核。
