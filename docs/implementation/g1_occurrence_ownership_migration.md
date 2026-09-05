# G1 occurrence ownership 迁移合同

## 1. 目标与非目标

本迁移把 G1 守恒不变量从 operator-site 级的 source/sink/boundary 许可，升级为逐个 ledger occurrence 的精确所有权。规范来源是冻结的 `G1 机制基因组.md`：occurrence 由 typed edge role、MIMO `program_position` 到 endpoint 的绑定和完整 ledger identity 派生。

该层只证明结构引用、scope 和 owner 的闭合。它不证明数值守恒，不产生物理拒绝，不提高 Runtime evidence ceiling，也不能作为整装、VVUQ 或实验验证。

## 2. 版本边界

七参数 invariant 改变了公开字段、构造 ABI 和 canonical wire，因此必须使用新的 G1 payload schema revision 和 canonicalization revision。新 registry contract 必须携带新的 schema hash；旧九参数 payload 与新 payload 不得使用同一个 contract revision。

冻结规范中的 `ConservationLedgerOccurrenceRefV1` 名称保持不变。旧九参数输入只允许进入 `MechanismLegacyMigration` 中的显式 legacy declaration。新 invariant constructor 不提供九参数重载，也不使用 `hasmethod`、反射或异常驱动的双路兼容。

旧 hash 和新 hash 没有相等要求。迁移结果必须带 receipt，绑定：

- source canonical hash；
- target canonical hash；
- source 和 target contract ref；
- mapping algorithm revision；
- resolved 或 typed deferred disposition。

### 2.1 机器可验证的 r2 authority

r2 不能使用测试中的重复字符 digest 作为 schema authority。实现应提供两段固定顺序的 closed ASCII JSON manifest：

- schema manifest：逐项列出 invariant 的七个字段、occurrence 的六个字段、六个 sealed occurrence kinds、owner key 字段和 scope closure 规则；
- canonicalization manifest：列出本文规定的 domain/version、排序规则、系数位置和 layer dependency 规则。

两个 authority hash 直接取相应 manifest bytes 的 SHA-256。标准 mechanism contract ref factory 接收非空 URI，并固定：

```text
version = "v2"
schema_hash = SHA256(closed schema manifest bytes)
canonicalization_hash = SHA256(closed canonicalization manifest bytes)
compatibility_profile = "g1-exact-occurrence-ownership-v2"
```

`MechanismGenomeV4` 和 mechanism canonicalization 入口必须核对这四项；registry 继续执行完整 contract ref exact equality。错误 version/hash/profile 必须拒绝。

未改变的 G1 primitive leaf 保持 `fusionconceptai:v4:g1-primitive:v1`。新增 occurrence kind/ref 是各自类型的首个 wire revision，使用 `g1-occurrence-kind:v1` 和 `g1-occurrence-ref:v1`。发生破坏性变化的 invariant、payload、canonical transport 和八个 hash-layer domain 使用 `:v2`，其 `canonicalization_version` 为 `"2"`。`CanonicalizationProfileV1` 仍表示算法预算/profile，不因 payload schema 升级而全局改动，避免影响 G2/G3。

### 2.2 冻结的 migration machine contract

迁移模式使用 sealed enum `G1LegacyMigrationModeV1`，只允许 `legacy9_to_exact7` 与 `exact7_recanonicalize`。模式必须是 `G1LegacyMigrationDeclarationV1` 的显式字段，不得根据 invariant tuple 是否为空或元素类型临时推断。声明的机器字段按以下顺序冻结：

```text
G1LegacyMigrationDeclarationV1(
  mapping_ref,
  mode,
  source_contract_ref,
  source_mechanism_hash,
  target_contract_ref,
  states,
  invariants,
  parameters,
  symmetries,
  observables,
  operator_holes,
  edge_completions,
  declaration_content_hash)
```

`declaration_content_hash` 必须覆盖除自身外的全部字段，包括 mode、两个完整 contract ref 和 mapping ref。`legacy9_to_exact7` 要求全部 invariant 精确为 `LegacyInvariantV1`，source contract 与声明完全相等且不得是 r2 authority，target/context 必须与声明的 exact-r2 target 完全相等。`exact7_recanonicalize` 要求全部 invariant 精确为 `InvariantV1`，source、target、context 三个 contract ref 完全相等并且都是 exact-r2。空 invariant tuple 的模式仍由显式字段决定；只有转换后的 graph 也没有 ledger occurrence 时它才能通过 closure。混合两种 invariant、错误 source contract、错误 target contract 或把旧 contract 改写成 r2 标签均返回 typed deferred `contract_incompatible` 或 `legacy_gene_semantics_unrepresentable`。

旧 invariant 的 expected projection 固定为：先用完整 ledger identity 过滤 normalized graph occurrences；global scope 取全部匹配项；domain scope 仅取其精确 MIMO endpoint 是 typed state node 且 node id 属于 scope state refs 的匹配项；interface scope 仅取精确 site 上的 interface-minus/interface-plus。非 state endpoint 在 domain projection 中是不匹配项，不能索引失败或被猜测成 state。随后分别投影 source、sink、boundary site set，其中旧 boundary set 对应 boundary-effect 与 interface-minus/interface-plus 的并集。三个投影必须分别与旧声明双向相等，之后才能把完整 expected occurrence tuple 交给正常 r2 payload closure。

迁移 receipt 使用 sealed constructor，并至少冻结：

```text
G1LegacyMigrationReceiptV1(
  source_contract_ref,
  target_contract_ref,
  source_canonical_hash,
  target_canonical_transport_hash,
  target_subject_hash,
  mapping_ref,
  mapping_hash,
  mode_or_null,
  mapping_algorithm_revision,
  declaration_content_hash_or_null,
  disposition,
  reason,
  receipt_hash)
```

`target_canonical_transport_hash` 是 canonical transport bytes 的 SHA-256，不能重复填入 subject hash。resolved receipt 的 source/target/mapping/declaration/mode 字段必须全部存在，并且 reason 只能是 lossless；deferred receipt 保留当时已经取得的 source hash、声明、mapping ref 和 mode，未知字段显式为 `nothing`。`receipt_hash` 覆盖上述全部字段。迁移结果和 `semantic_view` 必须携带同一个 receipt；调用方不能公开构造一份 resolved receipt 或替换其中的 mapping identity。

## 3. occurrence identity 与闭包

公开 owner key 是：

```text
(operator_site_ref,
 port_side,
 program_position,
 direction,
 occurrence_kind,
 full ledger identity)
```

系数保存在内部 normalized occurrence 中，不进入 owner key。`program_position` 必须通过该 edge 的精确 MIMO binding 解析 endpoint；不能把端口号当 graph node index。

payload admission 必须同时满足：

1. 每个 invariant 声明的 occurrence set 等于由其完整 ledger identity 和 typed scope 推导的 expected set；
2. 每个 `(完整 ledger identity, exact typed scope)` 只有一个 owner；
3. 所有 invariant 的 occurrence union 等于 graph occurrence 全集；
4. 所有 invariant 的 ledger identity 集等于 graph ledger identity 集；
5. interface 只使用配对的 minus/plus occurrence，不能用 direct account effect 代替。

缺失、额外、重复、悬空、错误 role/direction/port/ledger、非唯一 binding 均拒绝 admission。graph 没有 ledger occurrence 时空 owner tuple 合法；graph 有 occurrence 时不能用空 tuple 占位。

## 4. 九参数到七参数的确定性迁移

迁移函数必须接收完整旧 invariant、完整 typed graph 和 states，执行以下步骤：

1. 从 graph 派生全部 normalized occurrences；
2. 按 invariant 的 ledger identity 和 typed scope 求 expected occurrence set；
3. 将 expected set 投影为旧 source/sink/boundary site declarations；
4. 要求投影结果与旧声明双向相等；
5. 对全部 invariants 执行 owner 唯一性和 graph union 闭合；
6. 仅在所有条件成立时按 owner key 排序并构造七参数 invariant。

任何一步非唯一或信息不足都返回 typed deferred reason。迁移不得选取第一个匹配项，不得按 edge 名称或装置 family 路由，不得自动补入一个推测的 owner。

已知 `mechanism_observable_closed_canonical_tests` fixture 的 `g1oc-site` 包含两个 internal occurrences：`input/1/inflow` 与 `output/1/outflow`。它们都必须由相应 global invariant 明确拥有，空 tuple 必须失败。

## 5. canonical 与 hash 迁移

新 revision 的 invariant wire 明确序列化 `owned_ledger_occurrence_refs`，并使用新的 domain/revision。hash-layer 的 structure/decorated incidence 加入 occurrence vertex 和 invariant-owner edge。以下变化是预期的：

- owner endpoint、kind、ledger 或 scope 变化会改变相应 structure/decorated/subject hash；
- alpha rename 和仅排序变化不得改变规范 hash；
- topology 与 operator-program hash 是否变化只由原有 layer 定义决定，不能因测试方便而重定义；
- candidate、compiled prefix、cache 和 archive key 随新 target hash 自动分区。

旧 JSONL golden 保留为 legacy 记录。新 revision 追加独立 fixture 行，带明确 schema revision 和新 expected hashes；不得覆盖旧 hash 后继续沿用旧版本标签。

## 6. 调用点与文件分组

当前 tracked Julia 源中有 56 个 `InvariantV1(...)` 调用点。迁移必须全量盘点，不能只修改现有 dirty 的六个测试文件。

- **A：类型与 admission**：ownership enum/ref、invariant、payload closure、public exports。
- **B：canonical 与迁移**：gene wire、transport、hash layers、legacy migration receipt。
- **C：fixtures 与验收**：全部调用点、ownership/scope/hash/observable/adversarial tests、JSONL golden、Runtime 默认 fixture 和 algebraic fixture。

`test/mechanism_ledger_occurrence_ownership_tests.jl` 当前仍含旧九参数构造和旧字段访问，不能直接提交。它必须改为七参数 exact refs，并覆盖 internal/source/sink/boundary/interface-minus/interface-plus。

生产 Runtime fixture 最终使用新 schema。旧 fixture 只保留在 migration tests 中，不允许默认 campaign 继续以 legacy payload 运行。

## 7. 验收矩阵

| 范围 | 必须通过 | 必须拒绝或保持 deferred |
|---|---|---|
| constructor | typed、唯一、同 ledger occurrence tuple | duplicate key、wrong ledger、unsealed kind |
| payload | exact per-scope ownership 与 graph union 闭合 | missing/extra/dangling/wrong role/direction/port/ledger/ambiguous binding |
| canonical | alpha rename、tuple/edge permutation 稳定 | owner endpoint/kind/ledger/scope 改变却 hash 不变 |
| migration | 唯一可证的旧声明映射并生成 receipt | 任何歧义、遗漏、重叠 owner 或猜测性映射 |
| Runtime | 新 schema fixture 可 compile；已有 unresolved 仍保留 | ownership closure 被当作物理 evidence 或提高 ceiling |

执行顺序：

1. targeted ownership、scope、observable、hash、legacy migration tests；
2. 当前主工作区完整 `Pkg.test`；
3. Runtime core、vertical、archive、spine、algebraic 和两个 CLI；
4. 提交后的 fresh worktree 重复完整测试。

实现期间保留初始 dirty 文件。提交前逐文件核对其 SHA 和语义意图，只显式 stage 本迁移白名单。中间 ABI 破损状态不得推送；类型、canonical、fixtures 和 goldens 必须作为一个完整契约升级一起发布。
