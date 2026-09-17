# AD48-S1 independent review R1

日期：2026-09-15  
评审者：different `gpt-5.6-luna/high` review lane  
仓库：`D:/006-Programing/LMC/FusionConceptAI`  
观察 HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`  
结论：`pass_limited`  
S2：在父审查接受本 R1 后可派发；本报告不直接授予 S1 acceptance。

## 审查范围

本复核只读 AD48-S1 的四个 scope、八个冻结 JSON 产品、AD47-W1 八个输入、AD48 gap decomposition、共同合同和活动工作单。没有修改被审产品、AD47 产品、源码、测试、fixture、registry、核心清单或任务清单；没有运行 Julia、DESC、provider、mesh、solver、engineering、physics 或 search。

四个 scope 的冻结产品均与派单消息一致：

| scope | locator | receipt |
|---|---|---|
| realization | 3764 bytes / `bfb7a4f2cd4e128078b38dd3f47c2e11d6a85a5350662cda400054eeec8ba029` | 6613 bytes / `fa042cdc32954d38f2c55c4204593cbbae32b309c291267841dda07a0f85408a` |
| control | 3722 bytes / `e0d3c8468210c85a3ed66a22ddee1be4d86ed3052d6a09884619d5af374490c4` | 6571 bytes / `40c223e302a2263657150d1eba088db1b21825d0db4730403719b563acdfe845` |
| binding | 4451 bytes / `07b4de5bc4b290ce60a3f5a9158c315a795a6b013db286d5c563adcbb3543eaa` | 7300 bytes / `407387f7f1e3a5e76102a3e9234d446b39a96e1bf276336584af2e02374ffd78` |
| bundle | 5773 bytes / `fb826aa4d32bd6284f3fca7ec9f21b66e3f06d1fc13d4fc678793442ccf8e361` | 8622 bytes / `bb3b187bbfc77dd55434e56c13e53793052fb61e07e4ff559c6806f1aff77772` |

## 独立核对结果

直接复核的 74 项全部通过。每个 locator 和 receipt 均为 canonical JSON、无 terminal LF，冻结 bytes/SHA 与派单值一致；locator 的 `semantic_hash` 按 `sha256(canonical_json(semantic_body))` 重算一致，receipt 的 `record_ref` bytes/path/SHA 与对应 locator 一致，且 `self_hash_excluded=true`。

四个 scope 的 repository root、HEAD 和 observation UTC 一致。每个 source closure 的当前文件均存在，bytes/SHA-256/64 位长度重算一致；`git ls-files --error-unmatch` 对这些路径均保持 HEAD absence，locator 也明确记录 `head_blob_sha256=null`、`head_path_status=absent_untracked` 和 working-tree `untracked`。因此 `PresentG3SourceLocatorV1` 只能表示当前工作树中的本地软件 locator 快照，不能表示已提交 source authority。

bundle 主闭包恰含五个 source：`RealizationControlGenomeV5.jl`、`CoupledRealizationControlBindingV2.jl`、`RealizationGenomeV5.jl`、`ControlGenomeV5.jl` 和 `G3SourceFeedbackLawV1.jl`。child source、child test、binding static QA 与依赖 receipt 单独使用 `dependent_child_*` 角色，没有把 test/receipt 混进五个主 source 的 kind/role。四份 receipt 的 AD47-W1 八项输入路径、bytes、SHA 与冻结值完全一致。

所有 receipt 的 negative controls、registry unchanged、W1 frozen/read-only、no candidate/declaration identity、no publish 和 runtime-zero 声明均为真。四个 scope 都显式声明 source byte、path、HEAD、repository root 或 closure 变化需要新的 locator。独立的内存 mutation probe 对每个 source 追加一个字节后得到不同 SHA；39 项 head/source/path/root invalidation 与 role-mix checks 全部通过，结果保存在 `review/negative_controls_r2_stdout.json`。

独立运行 `validate_plan.py`：31 markdown、497 links、39 tasks、DAG acyclic，exit 0；原始输出在 `review/plan_validator_stdout.json`。独立 scoped `git diff --check` exit 0，stderr/stdout 为空。复核直接执行使用 Python 3.13.5（`D:/Users/Newman/anaconda3/python.exe`），PID 79148，UTC `2026-09-15T13:13:23.188241+00:00`；negative-control probe PID 83688，UTC `2026-09-15T13:14:44.791055+00:00`。

## 失败历史与边界

第一次 direct verifier 以 exit 2 结束，原因是审查器自身把 receipt 的全局 AD47-W1 八项输入误当成 scope-local 两项，并把 binding static QA 的 role 判定写得过窄；没有修改输入，也不是产品失败。原始 `review/direct_validation_stdout.json` 与 exit 文件保留。修正复跑为 74/74、exit 0，原始 `review/direct_validation_r2_stdout.json` 保留。另有一次 PowerShell 包装器的条件表达式错误，产品 scoped diff 本身没有失败；修正后的 raw 仍保留。没有临时文件留在 review 目录之外。

## 裁决

AD48-S1 的八个产品通过独立复核，建议 verdict 为 `pass_limited`，接受范围仅为四个 G3 scope 的 repository-local、working-tree source locator 与可复查的字节/hash/路径闭包。由于主源均 untracked、HEAD blob 缺失，locator 仍不是 authority，不产生 G3 source authority、factory identity、trusted attestation、candidate/declaration/final identity、T0/T1/T2、provider、mesh、solver、engineering、physical、search、R01–R10 或 L4 credit。

在 root/Sol 记录本 R1 后，S2 可以按 AD48 规定派发四 scope 的 factory identity/construction receipt probe。S2 只能消费这八个冻结 locator，必须使用实际构造入口并保持 absent/fail-closed union；不得借 locator、fixture、seed、URI、W2R1、bundle hash、own hash、测试或 runner exit 生成 identity。若 S2 仍证明没有 G3 source-authority factory，才可进入条件单 AD48-F0；S2 实现后必须 fresh rerun。
