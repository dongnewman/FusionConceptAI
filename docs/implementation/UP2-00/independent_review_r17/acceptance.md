# UP2-00 r17 独立复核

结论：`changes_requested`（受限范围）。本复核只接受当前实现作为 `schema_validation_only` 的 contract-only typed slice；不接受 UP2-00 总门，也不授予 B00/B04、solver、mesh、provider、engineering、physical 或 R01-R10 信用。

## 输入与方法

冻结文件复算 SHA256 与任务给定值一致：

- `src/GenomeV5/UP2/TypedPrecompilerContractV1.jl`: `b63258ee4c26bb686c7c8fc711449b9f22af0a8234dc5e1a33ff271849cae1e0`
- `src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl`: `0557532f9921afabbd6cdcc190e216496807227ef802b3898bd0292b1e98150b`
- `test/GenomeV5/UP2/up2_00_contract_tests.jl`: `749fcb5bb1d6e3af85ee500df1febd341135dd982c6d55bbfbe4106715f07354`
- `docs/implementation/UP2-00/evidence_manifest.json`: `4e054674381660f725176cf8cc1cfcff06f29f44b20fce4367a895adf4b809db`
- `docs/implementation/UP2-00/acceptance.md`: `2ea8555368931aca8e59067943c4f8d168fdfaef6bedf49e83935ddea2aa83d7`

读取共同合同 00、技术/执行约束 16、AD-20，以及 G1/G2/G3/A 当前源码。执行前无 Julia/DESC 进程。唯一独立命令为：

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_up2_00_contract.jl
```

父进程 PID `62640`，启动时间 `2026-09-14T07:41:54.6267400+08:00`，Julia 1.10.5，HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`，exit `0`。stdout/stderr/exit/process/environment 已在本目录封存；运行后无 Julia/DESC 进程。

## 已验证事实

`up2_projection_from_a(package)` 确实从实际 A package 读取 N01/N02：G1 equation 的 input/output ranks 和 units、G1 state `physical_type.tensor_rank`、G2 embedding dimension、G2 field-space shape/unit、G3 resource port unit 和 ledger entry unit。`up2_input_from_a` 重新生成 projection 并比较 `projection.projection_hash`，同 package hash/ref 的 forged projection 被测试拒绝。

N01/N02 的 mutation classifier 不读取 `spec.expected_error` 来产生 `error_code`；它检查变异后的 typed projection value 与 rank/unit/mission baseline，invalid path 的 compile/provider/solver counters 保持为 0。N05 的五项 mutation 由于 `port_source=:unverified` 均保持 deferred；N03、N04、N06-N10 及其余 pending rows 没有自证通过。测试输出显示所有测试集通过，actual A package slice 为 `48/48`。

## 必须限缩的证据

1. actual A package 测试的 `48/48` 只断言 N01/N02 结果为 `fail_closed` 以及 invocation counters 为 0；完整 `error_code`/`error_path` 断言仍在 earlier `UP2-00 real N01 N02 slice` 中对 `_up2_reference_input()` synthetic input 执行。故当前运行证明了实际 A projection 入口和状态门控，但没有完整证明 actual A package 对每个 N01/N02 mutation 的错误路径/分类。归档中 “N01/N02 mutations are source-backed and classified” 应明确为 projection/value-level partial evidence。

2. `_up2_mutated_input` 重建的是 `UP2SemanticFieldV1` typed wrappers；它没有重建或写回 G1/G2/G3 component object。此实现可以作为 schema-validation-only projection slice，不能作为 B04 candidate mutation、component recompilation 或物理输入变异证据。

3. low-level `UP2PrecompilerInputV1(...)` 仍可由 caller 传入任意 v5 refs、非零 hashes、state 和 `terminal_deferred`; 它不持有 A package，也不验证三层 refs/hashes/axes、G2 binding、G3 children 或 provenance。测试和 acceptance 已将其标为 synthetic/unverified，因此不能用于 B04。

4. N05 仅从 G2 interface 携带 interface ref/regions/normal/transfer kind，flux ports 与单位仍是 pending/unverified；region/interface metadata 未被当作真实 flux-port authority。这一边界表述正确，不能转为 closure credit。

5. counter=0 只证明这次 contract validator 没有调用 provider/solver；UP2 仍未证明正式 compile-before-provider gate 或 B04 runner receipt。AD-20 的首次 B04 suite、50 条正式 mutation、checker 和 two-process replay 尚未执行。

## 最小修正/后续门

- 在 actual A test 中对实际 package input 的每一条 N01/N02 mutation 断言 code、path、mutated hash 和独立分类，并保留 synthetic seam 只作负控。
- 保持 N05 和其余 40 rows pending，直到有真实 flux endpoint/unit provenance 与其 own accessor；不要用 region IDs 或 fixture metadata 代替。
- B04 前必须把 typed projection mutation 与真实 candidate-bound mutation receipt 的边界写入正式 B04 contract，并提供 compile/provider invocation gate 与 two-process evidence。

本复核不改变 UP2-00 的 `review_pending`、`accepted=false`、`schema_validation_only`、`claim_ceiling=none` 及所有物理/工程/R01-R10 false 结论。
