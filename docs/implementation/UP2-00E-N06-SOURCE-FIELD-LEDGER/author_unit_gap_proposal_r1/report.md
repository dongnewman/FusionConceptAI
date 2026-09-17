# N06 R8 单位缺口与最小测试提案

状态：`proposal_only`；本目录为只读审计归档，未修改 N06 生产源码、现有 fixture、测试或 runner，未运行 Julia/DESC。

## R8 原始事实

R8 使用冻结命令 `julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl`，主 PID `37060`，观察到 Julia 子进程 `17324, 75116, 77624`，UTC `2026-09-14T05:27:19.355459Z` 至 `2026-09-14T05:28:23.388901Z`，真实 `exit=1`。前八个组通过 `323/323`；N06 组为 `24 pass, 0 failed, 1 error, 25 total`，全程 `323/324`。错误是 `ArgumentError: N06 mapping is structurally inconsistent: conversion_same_dimension_mismatch`，栈定位 `n06_mapping_from_a` 源码行 593、测试行 196。R8 的 `receipt.json`、stdout/stderr、process 与 protected before/after 均保留；postflight Julia/DESC 为空，未发生同轮重试。该结果只属于程序/合同失败证据，不产生 B04、provider、mesh、工程、物理或 R01–R10 信用。

R8 的失败发生在首个 actual-A projection/mapping testset，因此后续五个 mutation 的动态执行在该次 R8 中没有发生；不能用前八个 G1/G2/G3 组或 fixture 行数替代它们。当前 `_n06_valid_join` 虽从 actual 对象选择 occurrence/entry，但它把 authored `selected.unit`、G3 role port 和 expected labels 组装成 join；join 对象本身不是跨层 authority。若测试只断言 `joins` 非空或直接把 admission 的 `terminal_deferred` 当作通过，会形成 vacuous baseline；修复必须让每个角色的单位矛盾或真实 authority gap 被显式分类，并继续执行五个 source-derived mutation。

## 实际 A 的单位链

| role | 实际 G1 occurrence | 实际 G1 unit | 当前 G3 选择及 entry unit | 当前规则/事实 | 当前结论 |
|---|---|---|---|---|---|
| `source` | `energy/governing-0/output/1` | `UnitSignature(0,0,0,0,0,0,0)`；G1 fixture 的 `governing-0` input/output units 及 occurrence 均为全零 | `source_flow` + `source-entry`，entry 为 `(1,2,-3,0,0,0,0)`；partner `source_effort` 为 `(1,2,-3,-1,0,0,0)`，flow 为 `(0,0,0,1,0,0,0)` | `power_from_effort_flow` 只检查 effort+flow 指数和 `to_unit`；`from_unit` 仍要求等于 G1 occurrence，因此 dimensionless G1 value 没有被证明为 power source | 局部 typed law 可检查，但真实 G1→G3 source/field 语义仍缺 authority，应保持 `terminal_deferred` |
| `field` | `energy/source-0/output/1` | `UnitSignature(0,0,0,0,0,0,0)` | `load` + `load-entry`，`(1,2,-3,0,0,0,0)` | test 构造 `:same_dimension`；validator 行 562–563 要求 `from_unit == to_unit`，因而真实 mismatch | 当前正例是错误的：应改为明确 `fail_closed` mismatch 负例，不能改 validator 放宽 |
| `return` | `constraint/constraint-0/output/1` | 全零 dimensionless | `return` + `return-entry`，`(1,2,-3,0,0,0,0)` | 同上，`same_dimension` 不成立 | 当前正例是错误的；应为 typed dimension mismatch `fail_closed`，而无 authored physical law 的 admission 仍 `terminal_deferred` |
| `heat` | `constraint/constraint-0/output/2` | 全零 dimensionless | `heat_sink` + `heat-entry`，`(1,2,-3,0,0,0,0)` | 同上，`same_dimension` 不成立 | 当前正例是错误的；应为 typed dimension mismatch `fail_closed`，不能把 G3 heat unit 反投影为 G1 heat authority |

G2 的 actual interface/boundary 只给 region、axis、coordinate、normal、continuity、transfer kind；G2 fixture 的 `field_space.state_unit` 是无量纲文本 `1`，没有 flux/return/heat `UnitSignature`。因此 G2 不能补上上述转换。G3 资源端口和 entries 的单位来自 `test/GenomeV5/G3/fixtures.json:43–64`；G3 局部 validator 可证明端口、entry、account、closure 的局部一致性，却不能证明 G1 occurrence 到 G3 ledger 的跨层物理含义。

## R8 假阳性来源

`test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl:120–124` 对非 `source` role 一律用 `selected.unit` 到 `role_entry.unit` 的 `:same_dimension`。实际 A 中这四个 G1 occurrence 全为 dimensionless，而 `load`、`return`、`heat_sink` entries 为 power；所以 test 的所谓 valid join 不满足当前 conversion contract，R8 暴露的是测试样本与 typed validator 的真实冲突。即使把这些样本改成 `power_from_effort_flow` 也不能自动成立：该 rule 需要实际、候选绑定的 effort/flow partner 与内容哈希 law；它不能把 dimensionless G1 occurrence 变成物理 power source。

## 最小 test/fixture-only 修复边界

只在获得 Sol 裁决后修改 owned fixture/test，生产 validator 保持不动：

1. 保留五个 N06 source-derived mutation 与现有 source locator/hash/value receipt；不要把 `expected_error` 变成分类路由。
2. 将当前 `_n06_valid_join` 的四角色样本拆成两类：`source` 只保留明确的 effort+flow `power_from_effort_flow` declaration，并在测试中标记其跨层 source-field law 仍 `terminal_deferred`；`field/return/heat` 不再伪装成合法 `same_dimension` 正例，改为构造 mismatch declaration 并断言 `fail_closed`、`conversion_same_dimension_mismatch`，同时保持 admission 的 unresolved cross-layer result 为 `terminal_deferred`。
3. 负控必须由真实选中的 typed source 值触发：G1 dimensionless occurrence 对 G3 power entry；另加同指数但错误 field/path、缺 flow partner、foreign-valid flow link、非零 derived offset。不要把单位字符串或 fixture expected label 当作 authority。
4. 若未来要使 `field/return/heat` 形成合法 mapping，必须新增 candidate-owned、版本化且 content-hashed 的 conversion/source-field-return-heat law，携带实际 G1 occurrence/closure、G2 region/boundary、G3 port/entry/account/closure/link 的完整 refs、UnitSignature 和 provenance；在该来源不存在时，测试应期望 `terminal_deferred`，而不是制造 synthetic unit。
5. shared owner 仍是合法状态；只有 exact account/closure/event scope 重复才可 `fail_closed`。owner 字符串相同、G3 局部 balance 或相同 unit 不能证明跨层 conservation。

测试顺序还应把单位/映射分类和五个 mutation 放在可独立完成的 testset 中：若正例 mapping 因真实 dimension mismatch 被拒绝，测试应捕获并断言该 `fail_closed`，然后用同一 actual A projection 继续运行 N06-01..05；不能让一个伪正例的构造异常跳过五行。

建议的窄断言矩阵：

| 断言 | 期望 |
|---|---|
| selected G1 dimensionless → G3 load/return/heat power with `same_dimension` | `fail_closed`, `conversion_same_dimension_mismatch` |
| no authoritative source-field/return/heat law after local declaration check | `terminal_deferred`, independent authority gap |
| source role with actual effort+flow partner and exact candidate-bound link | local conversion structural check may pass; cross-layer admission remains `terminal_deferred` |
| shared owner with distinct legal accounts/closures | not duplicate by owner string; remains deferred if owner scope join absent |
| duplicate account scope, wrong unit exponents, foreign link, missing partner | `fail_closed` from typed contradiction |

这只是修正测试语义和保留真实缺口的提案，不是 N06 实现验收，也不关闭 UP2 total、formal B04、provider、mesh、工程、物理或 R01–R10。

## 可复查定位

- N06 conversion schema/rules：`src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl:38–65`
- actual A selectors/units and G3 selection：`src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl:315–397`
- conversion checks：`src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl:500–580`
- N06 test conversion construction：`test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl:81–136`
- G1 occurrence unit type/validator：`src/GenomeV5/G1/GrammarProfileV2.jl:153–175`、`src/GenomeV5/G1/MechanismGenomePayloadV2.jl:155–165`
- G3 resource/entry unit types：`src/GenomeV5/G3/RealizationGenomeV5.jl:254–269`、`:415–432`
- AD-24 authority boundary：`docs/implementation/AD-24/decision.md:7–21`、`docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md:188–204`
