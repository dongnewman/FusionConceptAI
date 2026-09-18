# UP4-01A Source/Hardware Inverse Realization — R10 runtime archive

日期：2026-09-18（UTC）  
状态：`contract_only / prepared_not_measured / accepted=false`  
范围：归档 R10 focused Julia runtime receipt；不改 SHIR 源码、focused
test、fixture 或既有 fixtureQA 索引，不创建 commit。本归档不运行 Julia。

## R6 → R10 lineage

### R6 Bool constructor blocker

R6 暴露了 `SourceHardwareDesignAlternativeV1` constructor 的 typed-value
问题：`alternative isa SourceHardwareRefV1 && alternative.kind ===
:design_alternative` 的验证布尔值被错误写入 typed `alternative` 字段，合法的
`SourceHardwareRefV1` 因而在进入 `new` 前被替换为 `Bool`。R7 的最小修复将
验证与值分离，保留原始 `alternative`，并补充 `Bool` alternative 与错误 kind
的拒绝检查。该修复不产生 provider、solver、checker、物理或硬件证据。

### R8 → R9 fixture-key failure and repair

R8 focused Julia 历史结果为 `23 pass / 0 failed / 1 error / 24 total`。唯一
错误是 constructor-guard 正例读取路径：test line 225 使用
`fixture.constructor_guards`，但该对象实际位于
`fixture.positive.constructor_guards`。这是测试 fixture key/path 访问错误，
不是产品源码或 fixture 内容错误；R8 失败结果作为历史 lineage 保留。

R9 只将该读取修复为：

```julia
constructor_guards = positive.constructor_guards
```

R9 的静态守卫同时要求正确路径并拒绝 `fixture.constructor_guards`；已有
37-vector negative registry 与 fixture exact-set 保持不变。

## R10 focused runtime receipt

唯一允许的 Julia 命令执行一次：

```text
C:/Users/Newman/AppData/Local/Programs/Julia-1.10.5/bin/julia.exe --startup-file=no --history-file=no --project=. test/RuntimeV4/source_hardware_inverse_realization_contract_v1_tests.jl
```

运行前无 Julia 进程。运行时间为 `2026-09-18T00:55:17.8734658Z` 至
`2026-09-18T00:55:27.0986394Z`，PID `49460`，exit `0`；运行后 Julia 进程数
为 `0`。完整 stdout 为：

```text
Test Summary:                                                | Pass  Total  Time
UP4-01A source/hardware inverse realization contract-only V1 |  547    547  8.4s
```

stderr 为空。该 receipt 只证明本 focused contract test 的软件运行结果。

## Negative coverage and counters

- fixture negative vectors：`37/37`，test registry 与 fixture 为 exact set；
- provider calls：`0`；solver calls：`0`；checker calls：`0`；
- 无 DESC、mesh、numerical provider、工程执行、硬件测量或实物回代。

因此 provenance 仍只是 candidate-bound 的 hash join，不是独立签名、trust
root、freshness 或 source authority。`contract_only / prepared_not_measured`
是本 slice 的 claim ceiling；`accepted=false` 不变。没有 UP4 物理/工程/硬件
证据，也没有 R01–R10 信用；R01–R10 与父目标继续保持未关闭。

## Four-input SHA-256 replay

R10 receipt 的 before/after 四项哈希完全一致；以下为复算后的当前值：

| path | SHA-256 | before = after |
|---|---|---|
| `src/RuntimeV4/SourceHardwareInverseRealizationContractV1.jl` | `9b8f794a27d011a675a663606ae4bae59081bb3562b7a55c37f7aa04b16bbbe1` | yes |
| `test/RuntimeV4/source_hardware_inverse_realization_contract_v1_tests.jl` | `bf4c2b10d9eee05840133bec616e28d6a5d0c20610a60d1071f7cd2ad430a47e` | yes |
| `test/RuntimeV4/fixtures/source_hardware_inverse_realization_contract_v1.json` | `3708b78a23977090e7dd386edb247f8cad4adda3e9be3deb3aab1649406a84a8` | yes |
| `docs/implementation/UP4-EARLY-PREPARATION/UP4-01-SOURCE-HARDWARE-INVERSE-R1/agent_local_r7/static_qa.py` | `94c7c3a9710ef566a84d63e5b8f273d31c46cac16e6cb92ca334484cdb3ea02a` | yes |

本轮仅新增本目录下的 `report.md` 与 `manifest.json`；不更新源测 fixtureQA
索引，不运行 Julia，不提交 commit。
