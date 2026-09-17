# AD-30 T0 LocalV1 R20b G2 typed semantic rebind

日期：2026-09-18（Asia/Shanghai）
范围：仅 T0 LocalV1 G2 nested semantic rebind；无 Julia/DESC/provider/mesh/solver
运行信用，无提交。

## 实现

生产 `_vnl_t0_semantic_rebind_candidate` 增加独立的 exact typed G2 分支：

- 要求 `candidate_envelope`、`contract_ref`、`G2MBSourceV1` 与全部 schema/
  canonicalization/profile/declaration hashes；确认 package candidate ref 与 v5
  `GenomeContractRef` 未发生域混淆。
- 在任何重绑定前校验旧 envelope/source 的 candidate、contract、source ref/hash
  连接及 source canonical hash；不接受 stale 或不一致输入。
- 用 fresh `source_ref` 重建 `G2MBSourceV1`，保留 chart/mesh/faces/profile/units/
  authority，重算 source hash；用真实 `g2mb_declaration_v1` 重建 declaration 与
  四个 identity hashes，再构造 fresh envelope。
- 不调用 provider、mesh 或 solver；R20a G1 分支与 R19 diagnostic 保持不变。

## 测试与静态 QA

R20b executable testset：`29/29` 通过，覆盖 fresh deterministic rebuild，以及
stale typed source ref/hash、envelope/source mismatch、contract-domain confusion、
stale schema/canonical/profile/declaration hash。所有负例均为 `ArgumentError`，不返回
partial semantic body。

静态 QA：

```text
python -B docs/implementation/UP1-04A-VNEXT-T0/static_qa_local_v1.py
```

结果：exit `0`，`status=pass`，`accepted=false`，`claim_ceiling=contract_only`，
`julia_executed=false`，`desc_executed=false`。

整文件回归还观察到既有 R20c 范围的 G3 feedback authority stale-candidate 失败；
该问题不属于本 G2 slice，不能据此给出 runtime/credit。R20c 仍为显式 NO-GO。

## 当前文件哈希

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl` | 85390 | `9129c8d43740b40b641157a3bc1468755d0bbbcbbcf53d64e4fa6f6dfbae15f1` |
| `test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl` | 64835 | `3719585c9c4a9767f32cead734313da093c252ee617b69e094213c44dd738c1e` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa_local_v1.py` | 22460 | `4412fec1f15730953615da2ee23c9ab46adcb73123e4dd7628149379304dbeb4` |
