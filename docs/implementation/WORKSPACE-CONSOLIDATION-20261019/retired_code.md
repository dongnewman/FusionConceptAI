# 无用旧版本退休记录

退休依据是当前生产入口、测试导入和规划引用的调用检查。代码快照已先进入提交`c5a304ebf57478eb5c2f4b1d10c3af446853a902`，随后才删除工作区中的无用版本；不改写Git历史。

| 范围 | 处理及理由 |
|---|---|
| `tools/up1_external_closure_r2/`、`r3/`、`r4/`及对应测试目录 | 整组退休。旧外部认证路径在agent_local默认流程中没有当前生产调用；各独占测试随功能一起移除 |
| `tools/up4_reference_validation/`、`test/UP4ReferenceValidationV1/`、`test/UP4ReferenceValidationV10Review/` | 整组退休。历史协议wrapper、观察器和专属测试构成闭合家族，生产FreeGS两条runner均不依赖它 |
| `test/runtime_v4_freegs_axisymmetric_lcfs_trace_tests.jl.after` | 无调用的副本；现用`.jl`仍包含六个测试集及相关helper |
| `runs/`与`tmp/`的未引用source/patch/probe | 按清理清单退休；当前源码引用闭包和暂停入口排除在外 |

[退休源码清单](retired_code_manifest.json)保存191个上述代码/独占测试文件的路径、字节和SHA；临时源码另见[全量删除清单](deletion_plan.jsonl.gz)。旧版本名称本身不是删除依据；仍有调用或不同冻结合同、负例、oracle的V1/V2/V3等继续保留。

UP4旧独立审查的关键方法也保留在这里：`audit_r10.py`（SHA256 `ba8574d1a13ce143298c9783dacbf96ae973c73c14dd0aee79ee60ba69a4b33e`）从保存的ψ和实际最终`Jphi`重新计算轴对称Grad–Shafranov残差，左侧为`ψ_RR - ψ_R/R + ψ_ZZ`，右侧为`-μ0 R Jphi`，分别报告相对L2/L∞及绝对RMS。它同时检查Picard控制流与调用观察记录。

该历史程序冻结的r10 solver输出SHA为`0ab33908927e1875cddd4cb56302aa800bfc77a03d9ccf8a709ebc028ef59869`，r8为`5a90938510dc41266dddc7e4c25989d33311f33dea0473a7e0975e200c010f38`；断言状态`numerical_fail_nonconvergence`、101次`eq.solve`、Picard迭代过多。这里只记录旧程序的方法和断言，没有重新执行独立审查，也没有把观察次数升级为收敛或物理接受。
