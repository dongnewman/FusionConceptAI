# AD-22 N03/N04 跨层时间与账本 authority 边界

状态：`accepted_limited`；`accepted=true`。范围仅限 AD-22 architecture consistency and provenance。

本归档只记录 Sol 的 AD-22 架构裁决，未接受 UP2-00 实现。19 与 `up0_02_protocol.json` 的 N03/N04 五行仍是 `illustrative_contract_mutations_pending_schema_binding`，不是可直接消费的 JSON Pointer。当 V5 没有对应字段时，不能把说明性路径静默映射为新字段，也不能删减这十类失败义务。当前 `TypedPrecompilerValidatorV1.jl:29-40` 的五行 N03 与五行 N04 是 provisional candidate-bound projection locators；正式 schema freeze 前必须逐行绑定真实 source field、mutation value、分类与 invocation receipt。

G1 局部时间合同已经权威：`MechanismGenomePayloadV2.jl:83-95` 对 equation 的 `operator_ref` 做 candidate-owned exact lookup，并检查 `temporal_kind in operator.temporal_kinds` 与 `derivative_order <= max_derivative_order`；`:115-184` 继续检查 typed expression、状态时间/导数、occurrence、closure ledger 和 balance。G3 事件局部合同只权威到类型与范围：`RealizationGenomeV5.jl:306-315` 限定 trigger 枚举和非负 exact Rational time。G3 event 没有 equation time basis；静态 G1 方程不能单独使 G3 scheduled/event 失效。只有新增的 candidate-bound、内容哈希受控事件时间政策才能判定跨层 time mismatch；缺少该 authority 保持 `terminal_deferred`，intrinsic enum/range 错误才 `fail_closed`。

G3 account/entry/closure 局部合同保持独立：`RealizationGenomeV5.jl:435-449` 检查 closure account_ids 非空且唯一，`:467-488` 检查 typed/unique IDs，`:504-565` 检查 port/account/entry/component 引用、单位、容量、closure domain 与余额。profile 文本的 `owner_uniqueness`（`:132-140`）目前没有对应 executable check；现有测试明确允许 shared owner（`test/GenomeV5/G3/up1_g3_contract_tests.jl:245-252`）。因此 owner 字符串相等不等于 duplicate accounting。N04 double-count 分类必须先冻结 owner uniqueness 的 account/closure scope，并要求 G1 occurrence ledger_id 到 G3 account/entry 及 energy boundary 的 exact mapping；缺 authority 仅为独立 `terminal_deferred`，不能由现有 G3 balance 检查代替。

最小 additive authority 是独立、版本化、内容哈希的 N03 time authority 与 N04 account-closure authority。每条声明绑定同一 candidate 的 G1/G3 public refs、component hashes、四轴、精确 source locator/type/value 和 schema/canonical/profile hash。结构类型或枚举错误必须 `fail_closed`；缺 time basis、owner scope 或 ledger join 必须保留 gap 与 `terminal_deferred`。该 authority 只服务 contract-only precompiler admission，不调用 compiler/provider/solver，不产生 B04、工程、物理或 R01-R10 信用。N03/N04 实现应各写入互不重叠的新 UP2 文件集合，后续再由 UP2 formal validator 接入；不得修改旧 V4、default registry、已有 N09 文件或历史 evidence。

本裁决不改变 UP0-UP6 DAG、任务状态、UP2 总门或父目标范围。本归档保留 before/after 字节、SHA、mtime 与 bounded diff provenance。

## 独立复核与有限接受

不同 Luna 独立复核结果为 `pass_limited`，仅确认本架构决议的 consistency/provenance 边界。复核报告：[AD-22 independent review](independent_review/report.md)，SHA256 `834f406d3658bbfff9171503ab04887a0e5a09b77db2228f637c0dbe05a66a67`；复核 manifest：[manifest](independent_review/manifest.json)，SHA256 `41cd5ec238b98ab349a19a7159fc165c4719447e2748b256c5969ec259abf3ea`。

N03/N04 十条 mutation 仍保留，仍等待真实 source field、typed mutation value、source-derived classification、跨层 authority 与 receipt。该 limited acceptance 不接受 UP2-00 implementation，不授予 B04、provider、mesh、engineering、physical 或 R01–R10 信用。

