# N06 test-only repair R9

状态：`review_pending`；仅修改 N06 owned test/fixture，未运行 Julia/DESC，未修改生产 validator、runner、E0、G1/G2/G3 或核心文档。

## 修复内容

- 将 actual-A `_n06_valid_join` test sample 改为明确的 authored sample 语义，不再称为合法 mapping。
- baseline 现在调用 `_n06_join_errors`，以 baseline error set 为参照，断言实际 field/return/heat 的 `conversion_same_dimension_mismatch`，并断言 `n06_mapping_from_a` 对该样本抛出含该 code 的 `ArgumentError`。
- 删除构造成功 mapping 的死分支；baseline admission 仍明确为 `terminal_deferred`。
- 将 N06 mapping negative controls 从 2 项扩为 5 项：duplicate owner-account scope、derived offset、missing effort partner、foreign-valid flow link、detached G1 occurrence。每项都要求相对 baseline 新增目标 error code 后再断言拒绝。
- 保留并独立进入原五个 source-derived mutation rows；R8 首组异常不再跳过这些 testset。
- `same_dimension_exponent_mismatch` 保留为重复 baseline mismatch control，明确标记不新增 mapping credit，而不是将重复 error 当作新 coverage。

## 语义边界

G1 actual occurrence 全为 dimensionless；G3 load/return/heat entries 为 power unit。该测试修复把单位冲突分类为 typed `fail_closed`，不放宽生产 validator，也不伪造 G1→G3 physical law。source effort+flow 只证明 G3 局部维度组合；跨层 law/provenance 缺失时 admission 仍 `terminal_deferred`。shared owner 只有 exact account/closure scope 重复才拒绝。

## 保护与 QA

R8 `focused_r8/` 及 R1–R7 raw 证据保持不变。修复前输入 hash：

- source `69bd82f040f405e55768e52af64b9b9b6d97272a2ec3988b66b7bdf21ec1128c`
- test `dac8c62e4ba20b45930a119649468659931eca2236cb9c5181aba101392a66ce`
- fixture `361a1777a765ed6784a1f37c02febc24c2ba5f6eed3c6a15b99333af596736b2`
- runner `9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af`

本轮只做 JSON 解析、静态文本检查、`git diff --check`、hash/脏文件/进程 QA；focused Julia 需不同 Luna 静态复核后由 Sol 另行串行放行。
