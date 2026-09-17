# UP4 inverse-realization contract matrix R5 fixture repair

状态：`contract_only / accepted=false / runtime_not_executed`。

## 修复范围

- fixture builder 现在对 provider semantic domains 使用稳定去重排序：
  `Tuple(sort!(unique((target_domain, source_domain))))`。同域正例只声明一次，
  target/source 跨域仍保留两个不同 domain。
- 增加真实 malformed external negative：直接构造重复 provider domains，必须由
  `InverseExternalInputError` 规范化为 `fail_closed`，并保持 `provider_calls=0`。
- 增加 target/source 跨域案例，保留并明确
  `source_geometry_domain_mismatch`；fixture 增加 cross-domain 与 duplicate-domain
  case ids/reasons。
- static QA 校验 R4 原始失败证据、输入 hashes unchanged、稳定 dedup、直接 malformed
  构造、ExternalInputError 边界和零调用约束。

## 既有 R4 失败证据

保留目录：

`runs/agent_local_up4_inverse_realization_contract_matrix_20260918_r4/`

- exit code：`1`
- test totals：`0 pass / 0 fail / 1 error`
- 原因：同域正例传入重复 domains，产品正确抛出
  `inverse external input [malformed_input]: duplicate provider domains`
- `hashes_unchanged=true`
- 未覆盖、未删除、未重写原始 `run.json/stdout.raw/stderr.raw`。

## 静态实测

```text
python -B docs/implementation/UP4-EARLY-PREPARATION/UP4-INVERSE-REALIZATION-CONTRACT-MATRIX-R5/agent_local_r5/static_qa.py
git diff --check
```

结果：static QA `pass`，`20/20` checks，Julia/DESC 未执行；provider/solver counters
保持 `0`；`git diff --check` 仅报告既有无关换行警告。

本归档只完成 fixture/contract repair，不能替代后续唯一串行 Julia focused rerun，
也不授予 UP4、工程、物理或 R01–R10 信用。

## 输入 SHA-256

| path | bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/InverseRealizationRequestContractV1.jl` | 21079 | `5c25e92b625eff79b3e4714e3bbfb33e3b57354bddf2a24339296c890537b6e4` |
| `test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl` | 9689 | `898bf30229a7254f3aaa5388253c959a51247d13bb66dc4afca999168aa2a2b5` |
| `test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json` | 1909 | `51c025279dc514fc035366696ffa29387ffac5b68f9edfab9ceab43daab39fcd` |
| `docs/implementation/UP4-EARLY-PREPARATION/UP4-INVERSE-REALIZATION-CONTRACT-MATRIX-R5/agent_local_r5/static_qa.py` | 3897 | `97592239adbc9b24af6ce7519e3164f63b417951ebad4cea32dfd87bb39b11cd` |
