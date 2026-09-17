# AD-30 T0 LocalV1 R20a G1 nested semantic rebind

日期：2026-09-18（Asia/Shanghai）
范围：仅 T0 G1 nested semantic rebind 的 product/test/static-QA additive slice 与本归档；未运行 Julia/DESC，未提交。

## 实现

生产 helper `_vnl_t0_semantic_rebind_candidate` 现在只对 exact typed G1
semantic body 进入专门分支：

- 要求完整 G1 body shape 与 typed `G1DiffusionSourcePayloadV1`、`u/K/f`；缺字段或错误类型立即 `ArgumentError`，不走 generic merge。
- 用真实 `G1DiffusionScalarFieldV1`、`G1DiffusionCoefficientFieldV1` 构造器按 fresh `source_ref` 重建 `u/K/f`，保留 physical type、表达式、系数边界、空间依赖、对称性、正定性和 operator expression。
- 用真实 `G1DiffusionSourcePayloadV1` 绑定 fresh candidate/source，重算 `g1_diffusion_source_hash_v1`。
- 在重建前先核对旧 typed body 的 candidate/source 绑定、`u/K/f` 与 payload 的逐字段一致性、旧 source hash 与 payload 的精确一致性，并重跑旧声明构造器与 validator；nested candidate、任一 stale field source ref、tampered source hash 因此 fail-closed，不会被静默修复。
- 用真实 `g1_diffusion_declaration_v1` 构造并执行 `g1_diffusion_validate`；验证失败 fail-closed，不返回部分 semantic body。
- G2 envelope、G2 typed source、G3 authorities/feedback 尚未改变，留给 R20b/R20c；本 slice 不声称关闭跨层 nested identity。

## 测试与静态 QA

新增真实 typed 构造测试覆盖：

- fresh candidate/source 下 payload、`u/K/f` source refs 和 source hash 全部一致；physical type、K bounds/expression 保持；真实 G1 declaration validator 返回 `(:valid, ())`；重复 rebind bytes/hash 完全确定。
- old nested candidate payload、`u`/`K`/`f` 任一 stale source ref、stale source hash 直接进入 semantic rebind 均 `ArgumentError`，且不返回部分 body。

静态 QA：

```text
python -B docs/implementation/UP1-04A-VNEXT-T0/static_qa_local_v1.py
```

结果：exit `0`，`status=pass`，`accepted=false`，`claim_ceiling=contract_only`，
`fixture_authority=false`，`julia_executed=false`，`desc_executed=false`。

## 证据边界与后续缺口

本轮没有 Julia/DESC runtime 结果；R20a 仅为静态实现/测试切片，仍无 T0/T1/T2 或
R01-R10 credit。R19 的 source-edit locator mismatch 仍未解决。必须完成 R20b 的 G2
typed source/envelope nested rebind 与 R20c 的 G3 upstream authority/feedback nested
rebind及 cross-G1/G2 source-vs-declaration target mapping，再由不同 Luna 复核后安排一次
串行 runtime gate。

## 当前 10 文件 SHA-256

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl` | 80733 | `9c651251bdb80709033fd349f073f9da1a6b7d0fa65aefadabecbbe03d7ac366` |
| `test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl` | 59590 | `153a3ec185aef3bf70f1f91e6ad3d7d3262fcae3766427973dab8c7d623abe68` |
| `docs/implementation/UP1-04A-VNEXT-T0/vnext_declaration_transport_local_v1_fixture.json` | 2419 | `b1028b4d21ad690491a24549e73de5507af31edf3b70bf9357b25c3a09c24460` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa_local_v1.py` | 20427 | `c0f7613b8f8c21eba0c65fd073bc60c0d5a056df32022f63ec0a2efac39daddd` |
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | 27211 | `9cf9563b2e3b16b4c9111492a147581945809ccd982ec4e711f85682659ab716` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | 30863 | `807837ce2a4aef4c196d0f4e2635201e9843f3532bc1afd94d667865569a976b` |
| `src/FusionConceptAI.jl` | 10144 | `e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783` |
| `src/IR/OperatorRegistry.jl` | 64932 | `4c2f4383140527613782288749283d268497846ec915df158164875125677f45` |
| `src/Contracts/GenomeContractRegistry.jl` | 2389 | `ee57228623e314897a3e34f3bfd387e8cce4d89c2b0dfaaf29d227076a08495c` |
| `docs/v4_multitopology_generation/task_manifest.json` | 97171 | `84af082ba5fff336dd89ae506f6b8e680f96f0af2e657ae926d6e9cc666fd6ad` |
