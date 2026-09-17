# AD-30 T0 LocalV1 R21 test-fixture repair

日期：2026-09-18（Asia/Shanghai）
范围：仅 T0 R20c 测试构造、static QA 与本归档；未修改产品源码，未运行
Julia/DESC/provider/mesh/solver，未提交。

## R20 failure lineage

R20 wrapper 的唯一 T0 运行错误属于测试构造，不是产品 mapping 错误。旧版
`_t0l_feedback` 使用 `id == "g1-residual" ? :G1 : :G2`；因此 R20c 正例
`g1-source` 被错误标成 `:G2`，产品按错误层在旧声明中查找该 source ref，
正确 fail-closed 为 `feedback_target_ref_unknown`。R20c 另有覆盖缺口：
`fresh_declarations = (d1, d2, d3)` 复用了旧 refs，source-vs-declaration 映射
没有经过不同 fresh identity 的实际检验。

R21 将 helper 改为显式可选 `target_layer`，对 `:G1/:G2` 及 id 前缀做一致性
验证；未提供时，既有 `g1-*`/`g2-*` 调用保持原本意图。正例现在明确用 G1
source ref 与 G2 declaration ref，并用 `_t0l_rekey_present` 构造与旧 refs
不同的 `fresh_declarations`，断言映射到 fresh refs。

## 负例与边界

保留并补足 wrong-layer、foreign target、candidate mismatch、body-hash
mismatch 和可合法构造的 ambiguous target ref；ambiguous 记录通过让旧 G1
source/declaration ref 相同构造，断言产品返回
`feedback_target_ref_ambiguous`。产品源码
`src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl` 未改动，仍以
exact old source/declaration ref 分类并 fail-closed。

## Static QA

命令：

```text
python -B docs/implementation/UP1-04A-VNEXT-T0/static_qa_local_v1.py
```

结果：exit `0`，`status=pass`，`accepted=false`，`claim_ceiling=contract_only`，
`screen_only=true`，`julia_executed=false`，`desc_executed=false`，
`r01_r10_credit=false`。本轮不把 static QA 结果升级为 runtime/T0/T1/T2
或物理/provider/mesh/solver 证据。

## 待重跑唯一 wrapper 命令

由 root 在不同 Luna 环境串行、使用 fresh output directory 通过既有
agent-local wrapper 运行以下唯一 inner command；本轮刻意未执行：

```text
C:/Users/Newman/AppData/Local/Programs/Julia-1.10.5/bin/julia.exe --startup-file=no --history-file=no --project=. test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl
```

## 当前哈希

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl` | 96310 | `3f3446ec7b641470d1bb45cefed814463aca1af424a858945e09cbb1330ffcaa` |
| `test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl` | 75870 | `a92c028abf1fa1dd207c02d6a539efbdddf52be0cf9caabd5e3f208651ca8c64` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa_local_v1.py` | 25662 | `a32fa5ebd1eee059cd12053b82f2f1fb69a616b60e221f7682bb714df643fca3` |
| `docs/implementation/UP1-04A-VNEXT-T0/vnext_declaration_transport_local_v1_fixture.json` | 2419 | `b1028b4d21ad690491a24549e73de5507af31edf3b70bf9357b25c3a09c24460` |

`accepted=false`、`claim_ceiling=contract_only` 与 no-credit 边界保持不变。
