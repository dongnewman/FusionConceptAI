# AD-30 T0 LocalV1 R19 locator fixture repair

日期：2026-09-18（Asia/Shanghai）  
范围：仅 T0 test/static QA/R19 文档；未运行 Julia/DESC，不修改产品实现、fixture、expected、legacy/shared/registry/manifest，不提交。

## R18 原始证据

保留并引用：`runs/agent_local_up1_04a_vnext_t0_20260918_r18_diagnostic/`。

- 前两组摘要：`34/34`、`37/37`；
- fresh source-edit 摘要：`4 passed, 4 failed, 9 errored`（fresh 通过 `4/9`）；
- 精确异常：`ArgumentError: source edit locator ref mismatch`，产品
  `VNextDeclarationTransportLocalV1.jl:1146`；
- 根因：测试硬编码 `#r8-source-`，产品 `_vnl_t0_edit_ref(..., :source)` 生成
  `#source-`，导致 locator 的 source ref 与 product-derived source ref 不相等。

R18 raw receipt：

| artifact | bytes | SHA-256 |
|---|---:|---|
| `run.json` | 3773 | `fbcdf94d74f5c75a0e1981e6f475fac06edd1ce06996c345d2ff858dda7aa18e` |
| `stdout.txt` | 8353 | `f4b500e55a35307cec642b3962b314da0ee5635e8250322c9cfc8b4991221089` |
| `stderr.txt` | 2893 | `07e90bf767712c1668b7677555eb4d7cc39d7e86d93c5b52a7c372e3e00b9e2a` |

## R19 最小修复

测试现在调用产品 helper：

```julia
G._vnl_t0_edit_ref(declarations[1].source_ref, edited_source.sha256, :source)
```

并保留旧 `#r8-source-` spelling 作为负控，显式断言它与 product-derived ref
不同。static QA 对 helper 调用、旧 spelling 与拒绝断言设硬门。R18 internal/public
diagnostic、exception/backtrace、admission guards 与 typed-declaration mismatch
expected 均保留。

## 静态验证

```text
python -B docs/implementation/UP1-04A-VNEXT-T0/static_qa_local_v1.py
```

结果：exit `0`，`status=pass`，`accepted=false`，`claim_ceiling=contract_only`，
`fixture_authority=false`，`julia_executed=false`，`desc_executed=false`。
`git diff --check` 通过，仅有既有无关换行警告。

本轮不把 R18 失败改写为通过；须由不同 Luna 复核后再安排一次串行 focused runtime。

## 当前 10 文件 SHA-256

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl` | 74966 | `efeae3112009b0e8d4b0902bb0c0da305b49bba40a919b1c4fd24b68f336ec8e` |
| `test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl` | 53115 | `f288da66084e74739629e54d80c83c286848f50aa9ad49b6e47f05a19e602f34` |
| `docs/implementation/UP1-04A-VNEXT-T0/vnext_declaration_transport_local_v1_fixture.json` | 2419 | `b1028b4d21ad690491a24549e73de5507af31edf3b70bf9357b25c3a09c24460` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa_local_v1.py` | 18745 | `1879616b2ce1a800c1e39f01abe8c7c321cc6a2fd8f353ccf43747a13cb4d14e` |
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | 27211 | `9cf9563b2e3b16b4c9111492a147581945809ccd982ec4e711f85682659ab716` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | 30863 | `807837ce2a4aef4c196d0f4e2635201e9843f3532bc1afd94d667865569a976b` |
| `src/FusionConceptAI.jl` | 10144 | `e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783` |
| `src/IR/OperatorRegistry.jl` | 64932 | `4c2f4383140527613782288749283d268497846ec915df158164875125677f45` |
| `src/Contracts/GenomeContractRegistry.jl` | 2389 | `ee57228623e314897a3e34f3bfd387e8cce4d89c2b0dfaaf29d227076a08495c` |
| `docs/v4_multitopology_generation/task_manifest.json` | 97171 | `84af082ba5fff336dd89ae506f6b8e680f96f0af2e657ae926d6e9cc666fd6ad` |

