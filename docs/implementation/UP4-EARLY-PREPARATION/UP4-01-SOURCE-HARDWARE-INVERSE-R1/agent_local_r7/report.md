# UP4-01A source/hardware inverse realization — R7 runtime-blocker repair

日期：2026-09-18（Asia/Shanghai）  
范围：仅 SHIR source、focused test、fixture 与本 R7 static QA archive。

## 修复

`SourceHardwareDesignAlternativeV1` constructor 原先把
`alternative isa SourceHardwareRefV1 && alternative.kind ===
:design_alternative` 的验证结果（`Bool`）赋给 typed `alternative` 字段，导致
合法 alternative 在进入 `new` 时被错误替换为 `Bool`。R7 将验证和值分离：保留
原始 `alternative` 传入 `new`。同文件审计未发现其他把 `isa && ... || throw`
结果写回 typed 字段的同类问题。

测试与 fixture 现在明确记录并检查：

- 正例 `request.design.alternative isa SourceHardwareRefV1` 且 kind 为
  `:design_alternative`；
- `Bool` alternative 与合法 `SourceHardwareRefV1` 但错误 kind 均抛出
  `SourceHardwareExternalInputError`；
- candidate/G1/G2/G3、provenance/hash join、37 个负例和 provider/solver/checker
  零调用边界保持不变。

## 静态证据边界

命令：

```text
python -B docs/implementation/UP4-EARLY-PREPARATION/UP4-01-SOURCE-HARDWARE-INVERSE-R1/agent_local_r7/static_qa.py
```

结果：`pass`，`73` checks，`0` failed，negative `37/37` unique；Julia、DESC、
provider、solver、checker 均未执行，counters 均为 `0`。因此本轮只关闭源码/测试
合同阻塞的静态检查，不能宣称 focused Julia runtime acceptance。

## 残余风险

仍为 `contract_only`、`accepted=false`：candidate provenance 只是 hash join，
不是独立签名、trust root 或 freshness 证明；没有 geometry、材料、制造、冷却、
控制、数值求解、物理可行性、硬件安全或 whole-device readiness 证据。下一步若
获授权，只能串行运行 focused Julia test，并重新记录进程、exit code、完整负例
registry、输入 hash 与原始 stdout/stderr；本 R7 未运行该命令。

## SHA-256

| path | SHA-256 |
|---|---|
| `src/RuntimeV4/SourceHardwareInverseRealizationContractV1.jl` | `9b8f794a27d011a675a663606ae4bae59081bb3562b7a55c37f7aa04b16bbbe1` |
| `test/RuntimeV4/source_hardware_inverse_realization_contract_v1_tests.jl` | `49d8343e5767aba4547a82a34368ae914d9279265b9687e0565ec781b8198639` |
| `test/RuntimeV4/fixtures/source_hardware_inverse_realization_contract_v1.json` | `3708b78a23977090e7dd386edb247f8cad4adda3e9be3deb3aab1649406a84a8` |
| `docs/implementation/UP4-EARLY-PREPARATION/UP4-01-SOURCE-HARDWARE-INVERSE-R1/agent_local_r7/static_qa.py` | `4061ab08617644fe58c36c53dba755f089741d85d8357b93a7fdadd91a8c1bfb` |
