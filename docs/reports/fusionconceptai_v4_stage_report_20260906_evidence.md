# FusionConceptAI v4 阶段报告：现场核查记录

此文件支持同目录阶段报告的进度与来源核查，不是物理验收证明。

## 核查范围

- 日期：2026-09-06，Asia/Shanghai。
- 主仓库：D:/006-Programing/LMC/FusionConceptAI。
- 主分支：main，HEAD 1f80263192f0223097801225cff0f13908e14414。
- 历史目录：D:/006-Programing/LMC/outputs/fusion_concept_ai。
- 主分支已有时间残差、细化与事件三项提交。D1.3 执行合同、两份源文件、fixture、CLI 和测试在核查时为未跟踪文件；报告不授予其最终验收。
- 核查前后主仓库均无已跟踪文件修改。本次只新增报告资料，未改 Genome、运行时代码或旧版工件，未提交 Git。
- 历史验收结果来自记录中的冻结快照；本次没有重跑旧版 campaign 或完整 Pkg.test。
- 开发分支日志只表示该日志对应的运行，未证明分支最新全部文件与当次测试逐字节相同。

## 本次新增的数值复核

命令：

~~~powershell
julia --startup-file=no --project=. scripts/run_v4_typed_time_residual.jl
~~~

在当前主仓库执行，Julia 1.10.5，退出码为 0。

~~~text
h=0.2 status=integrated steps=5 rhs=40 error=4.0365695784527755e-5 drift=0.0 residual=2.220446049250313e-16
h=0.1 status=integrated steps=10 rhs=80 error=2.1325969487007157e-6 drift=0.0 residual=2.220446049250313e-16
h=0.05 status=integrated steps=20 rhs=160 error=1.2259258902469483e-7 drift=0.0 residual=2.220446049250313e-16
observed_order=(4.242446526050873, 4.120667655640253)
policy_claim_ceiling=screen_only
~~~

该复核验证受控两状态常质量矩阵 ODE 的积分行为，不覆盖完整包、事件全部负例、D1.3、物理验证或整装。

## 开发和验收日志摘录

### 场残差接入

记录目录：D:/006-Programing/LMC/.codex_tmp。

- fusion-v4-field-chain-scoped-final-verified.json：冻结文件 115、改变文件 0、scoped 项退出 0、75 项断言通过。
- fusion-v4-field-chain-new-four-root.log：field_residual_scoped exit=0，field_numerics exit=0。
- 原生内核制造解误差：(0.6176470588235297, 0.16475300734872175, 0.04191074911381381)。
- 观察阶：(1.9064778764480812, 1.9749125863875925)。
- field_residual 三网格 study 报错：MethodError: no method matching semantic_view(::...ResidualAssemblyV4)。
- field_residual exit=1；field_residual_cli exit=4294967295。
- 总状态文件 ExitCode=1，FinishedAt=2026-09-06T02:13:44.7696675+08:00。

结论：内核和部分 scoped 路径通过，整条 Pipeline 未通过；没有把此前的局部通过写成完整接入通过。

### Gridap 开发原型

记录目录：D:/006-Programing/LMC/.codex_tmp/fusion-v4-gridap-adapter。

- b1_formal.log / .status：单网格 n=5；27 个自由度；退出 0。
- algebraic residual：5.551115123125783e-17。
- L2 error：1.1841334713086045；H1 error：5.705374456859974。
- source interpolation error：14.366627996854366；boundary interpolation error：3.4687093340959616。
- 声明：screen_only=true；physical_validation=false；integrated_validation=false；VVUQ=false。
- gridap_tests.log / .status：29/29，约 2 分 23 秒，退出 0。

小代数残差不等于解对精确物理或制造解的误差小。单网格日志没有产生收敛阶，不能替代三网格验收、独立代码资格或主分支接入。

### 旧版 v142

现存 acceptance.json 的内容为：

~~~json
{"protocol_id":"fusionconceptai-v142-terminal-deferred-whole-device-20260901","acceptance":false,"status":"NOT_SEALED","reason":"Prior pseudo-pass invalidated by Sol final review; awaiting real exhaustive materialized audit and frontier execution."}
~~~

因此仅引用其设计思想，不授予百万级整装执行或封存验收。

## 文件身份

以下为本次读取后记录的原始文件 SHA-256，用于追溯报告来源。哈希记录不自动证明任何物理结论，也不把未跟踪文件变成已发布版本。路径相对于主仓库根目录；临时工作区日志的关键内容已摘录在上文。

| 路径 | SHA-256 |
|---|---|
| docs/v4_multitopology_generation/Genome V3.md | 4f241ceb1ab75d2ca9c7d0147977f1ce7526ea5e8cf5038f42a8d2821a722d10 |
| docs/v4_multitopology_generation/G1 机制基因组.md | f4ff9e6fe05251d7137a115ece692efe04c355e5e49284bfae3e2cec0cb48d74 |
| docs/v4_multitopology_generation/G2 场—几何基因组.md | 21654e2be80814924aaf1b2023fd480412e6a25b0de50b979dc908c1cd982be4 |
| docs/v4_multitopology_generation/G3 实现—控制Genome.md | 22bc4892d932c0a420ff33ec1941a0904a9fdff769ef593c50480d36b9fb56d8 |
| docs/implementation/runtime_acceptance.md | e9c730a72f5341e38474e1cdfa1b6a332679b2e4cef93a64eb419ad47b946571 |
| docs/implementation/native_field_numerics_acceptance.md | 2c794227d22e0f8bc8eec64895837d726d30a36460132edfd20d87270400daf6 |
| docs/implementation/typed_time_residual_plan.md | fef9085cb73cab22417b27e44188b49f75af23551068d3a2f1c33dc75ad2a93e |
| docs/implementation/typed_time_execution_contract.md | b08942944f2b25b3ab7bd4599884f60e281596bd2cd6f632b7de2982f1a0ef01 |
| src/RuntimeV4/FusionRuntimeV4.jl | dd03914ebff78cfdb1eb10777613e74c2ed4200636f29f09e4261f98a98d9b4f |
| src/RuntimeV4/Authority.jl | e48a5f9b24b9390806012333509ee0bca61d1fe07e9d0459523fef2548f7b22f |
| src/RuntimeV4/FieldResidualNumerics.jl | ed956e72e0d1f3c27d029ed1f463ce4fd38c3a9eb309c9ba9cc9ed735af2ccb5 |
| src/RuntimeV4/TypedTimeResidual.jl | 896d7e5f67b2089422b378d7bf7021b5b5e844239fe32fb65b5bc8a5ac56acf0 |
| src/RuntimeV4/TypedTimeRefinement.jl | a664c2b03af8c57a115fea84095146c28f405d637e7cd7e9693a1c5cec66692d |
| src/RuntimeV4/TypedTimeEvents.jl | 9de5b50eaf7cbd2e781d95f486adf057dc6fb3789c663ccfd910568819554bde |
| scripts/run_v4_typed_time_residual.jl | 25a3d391493eb7cd0a3042319d177eeefabea8780f1fc588f7803addc5a9a65c |
| examples/runtime_v4_typed_time_fixture.jl | 42672ca064d6a471f2a6c059b8a8ad3ba20450b8c8426a15c6d272bf5d16ca13 |
| Project.toml | dd0e3da29b8ab36af7aea8e81f5f6f73dc5bc2e1e2afb3c8258eadd06ab6c225 |
| Manifest.toml | 3e5eef2a0af7ddcdc79b7df3b69f491cf088f76865765ec3169c1325649ab39d |
| ../outputs/fusion_concept_ai/interactive_candidate_739c_demo/candidate.json | 9f98f4195ba9bb473f71bfbbab938a0bb5443df41c53e03c4ca57fabac991b45 |
| ../outputs/fusion_concept_ai/runs/v142_terminal_deferred_acceptance/acceptance.json | fa4f7338ffc525cc9c5ab03ef53a96a1a933d6ef315bc7b9b3a598de1f8af757 |
| ../.codex_tmp/fusion-v4-field-chain-new-four-status.json | 624e313ce96c5c5ccee3c5d3348f4eba0c43ee072ca907da83777530698df5ee |
| ../.codex_tmp/fusion-v4-field-chain-new-four-root.log | 69b42dfb8b8b8447002e4a285f1c45f32e5aabee247fdbd93ad55398d104a735 |
| ../.codex_tmp/fusion-v4-field-chain-scoped-final-verified.json | 0d847ea7064423005329c8552129a8af56300af148cf96390f89b71a3b492aa2 |
| ../.codex_tmp/fusion-v4-gridap-adapter/b1_formal.log | e2428d290ffe4aba627c3526bd0bed5060a7376def9660f6f024c795752699be |
| ../.codex_tmp/fusion-v4-gridap-adapter/b1_formal.status | 13bf7b3039c63bf5a50491fa3cfd8eb4e699d1ba1436315aef9cbe5711530354 |
| ../.codex_tmp/fusion-v4-gridap-adapter/gridap_tests.log | ad09aba66712410b560959ca874a6d1410e2c7a383520fc1b4e7932040d8cfe4 |
| ../.codex_tmp/fusion-v4-gridap-adapter/gridap_tests.status | 13bf7b3039c63bf5a50491fa3cfd8eb4e699d1ba1436315aef9cbe5711530354 |
| docs/reports/fusionconceptai_v4_stage_report_20260906_time_residual.txt | 32911a95098f2ea7c393150d6cfce8a05ec0948404273fd19628d72c57644ba2 |

记录时间：2026-09-06T13:48:48.2120767+08:00
