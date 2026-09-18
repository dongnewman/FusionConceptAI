# UP4-01A Source/Hardware Inverse Realization — R9 path-repair archive

日期：2026-09-18（Asia/Shanghai）  
状态：`contract_only / accepted=false / no runtime credit`  
范围：仅 focused test 的 fixture 元数据读取、R7 static QA 与本 R9 归档；不改
SHIR 产品源码或 fixture，不创建 commit，不运行 Julia。

## R8 → R9 lineage

R8 focused Julia lineage：`23 pass / 0 failed / 1 error / 24 total`。唯一错误来自
constructor-guard 正例元数据读取路径：test line 225 使用了
`fixture.constructor_guards`，而该对象位于 `fixture.positive.constructor_guards`。
这是测试 fixture 访问错误，不是 SHIR 产品或 fixture 内容错误；R8 的失败结果保持为
历史证据，不被改写。

R9 的最小修复仅将 line 225 改为：

```julia
constructor_guards = positive.constructor_guards
```

R7 static QA 增加两条静态守卫：必须出现正确路径，并明确拒绝
`fixture.constructor_guards`。既有 37-vector registry/coverage exact-set 检查保持不变。

## Static QA evidence

命令：

```text
python -B docs/implementation/UP4-EARLY-PREPARATION/UP4-01-SOURCE-HARDWARE-INVERSE-R1/agent_local_r7/static_qa.py
```

结果：exit `0`，`75` checks，`0` failed；fixture negative `37/37` unique，test
registry 与 fixture exact-set 闭合；Julia、DESC、provider、solver、checker 均未执行，
counters 均为 `0`。该结果只证明静态路径/合同检查，不授予 focused runtime、UP4、工程、
物理或 R01–R10 信用。

## Hash boundary

SHIR 产品源码与 fixture 哈希相对 R7 保持不变；本轮只产生 test、R7 QA 和归档文档变化。

| path | SHA-256 |
|---|---|
| `src/RuntimeV4/SourceHardwareInverseRealizationContractV1.jl` | `9b8f794a27d011a675a663606ae4bae59081bb3562b7a55c37f7aa04b16bbbe1` |
| `test/RuntimeV4/source_hardware_inverse_realization_contract_v1_tests.jl` | `bf4c2b10d9eee05840133bec616e28d6a5d0c20610a60d1071f7cd2ad430a47e` |
| `test/RuntimeV4/fixtures/source_hardware_inverse_realization_contract_v1.json` | `3708b78a23977090e7dd386edb247f8cad4adda3e9be3deb3aab1649406a84a8` |
| `docs/implementation/UP4-EARLY-PREPARATION/UP4-01-SOURCE-HARDWARE-INVERSE-R1/agent_local_r7/static_qa.py` | `94c7c3a9710ef566a84d63e5b8f273d31c46cac16e6cb92ca334484cdb3ea02a` |

## Next unique Julia command

Only after explicit authorization, run this one serialized focused command and capture
fresh PID/UTC, stdout/stderr, exit code, and before/after source/fixture hashes:

```text
julia --startup-file=no --project=. test/RuntimeV4/source_hardware_inverse_realization_contract_v1_tests.jl
```

No such command was run in R9.
