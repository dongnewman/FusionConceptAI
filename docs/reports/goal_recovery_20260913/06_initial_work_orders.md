# 首批可直接派发的工作单

这些工作单是下一次实施的任务，不表示本轮已经改代码或通过验收。由 Sol 先核对当前 HEAD/差异，在运行中的任务账本填写实际 baseline 与文件所有权，再派发 Luna。新文件名为建议接口名，落地前应检索去重；不是已存在可直接运行的功能。

## W01：复现并修复近边界压力停滞

父要求：R03。优先级：第一。执行者：Luna，Sol 负责算法和物理约束判断。

读取：`src/RuntimeV4/SpatialMultiRegionV4.jl`、`test/runtime_v4_spatial_multiregion_tests.jl`、本包 `recheck_solver_stagnation.py`、历史 nominal_coarse 的 `iterations.csv`、`state_history.csv`、`physics.json`。

候选 owned_files：`SpatialMultiRegionV4.jl`、新增 `test/runtime_v4_spatial_solver_stagnation_tests.jl`；不要同时修改候选 mission、空间 mesh、残差组装、整个 solver registry 或 whole authority。

目标：真实重现末四次接受但无有效下降的数值机制；按 Sol 给定的尺度/KKT/可行方向设计修正；为无进展提供清楚退出而不冒充 convergence。先证明反例旧代码失败，新算法在反例上正确分类或真实推进，再由主线调度实际空间运行。

必须保持：现有物理 residual max 容差 `1e-6`、完整残差/约束和空间变量；负压力不可物理接受；不能靠把所有近零压力粗暴清零掩盖方程残差。正的极小压力、恰零、微负舍入、不可行方向、非零残差驻点、真实收敛和非有限值必须分清。

允许执行：只读复核脚本；主线冻结后允许指定轻量 focused。真实 coarse/fine/端点由 Sol 串行执行，新建 run 目录。

交付：反例、源码 diff、具体公式依据、focused 输出、每步真实下降/约束/KKT/停滞记录。原案例未收敛仍写 fail；“根因已诊断”不等于 R03 全过。

## W02：RuntimeV4 集成入口与测试覆盖清单

父要求：R01、R10。执行者：Luna；可与 W01 并行。

读取：`src/FusionConceptAI.jl`、`src/RuntimeV4/FusionRuntimeV4.jl`、`examples/runtime_v4_spatial_candidate.jl`、`scripts/run_v4_spatial_chain.jl`、`test/runtests.jl`、所有相关 focused 入口。

第一阶段只读交付：包含图、已跟踪/未跟踪/未导入列表，列出标准包、早期 RuntimeV4、最新空间链的实际边界；记录 world-age 出现的加载路径。建议生产入口和测试分层供 Sol 审定后，第二阶段实现。

建议 owned_files：新增 `scripts/audit_runtime_v4_test_coverage.py`、`docs/implementation/runtime_v4_entrypoint_coverage.md`；第二阶段由 Sol 授予具体聚合器/runner 文件权限。不得擅自把 W01 测试和源码覆盖或整包重构。

验收：生产入口不依赖手工运行多个 example；测试入口覆盖所宣称 RuntimeV4 模块；快速测试、provider、实际科学基准分层；报告准确反映运行覆盖，2631 基础断言不再冒充全部运行时回归。真实 provider 测试不强塞每次默认单元测试。

交付：覆盖 JSON、调用图、入口 diff、明确命令与合适的实际加载/回归结果。解析得到 include 数量只是清单，不能代替模块运行测试。

## W03：ITER/实测基准的数据与真反演输入

父要求：R01、R02、R06。执行者：Luna；与 W01/W02 独立，Sol 定义物理可识别问题。

读取：本包反解合同；旧版 v102 报告、v89 anchor/compiler 作为负例；ITER 官方 FAQ 与直接相关的一手设计/数据文件。用当前可用工具查找适用公开数据，不在未取得时假写已拥有。

候选 owned_files：新增 `benchmarks/reference_registry_v1.json`、`benchmarks/iter_design_v1/README.md`、来源登记和独立数据解析器；先检索仓库，若已有同功能目录则由 Sol 指定复用路径。禁止填 `validation_pass=true`，禁止下载/记录账户凭据。

必须输出：每个字段的来源页/文件/版本/单位、design/measurement/simulation 类别、误差或 unknown、许可/可获取性、缺失字段。ITER 明确登记“非发电设计参考”。再寻找一组真实可获得的实验数据和具有不同 capability 的第二参考资料；候选名单不等于已有数据。

Sol 根据实际字段冻结未知 θ、已知输入、calibration y、held-out y、先验与可识别性问题。Luna 再实现 loader、单位/范围检查和泄漏检查；未知信息不得拿 anchor 默认值填平。

验收：至少一个真实可读、带来源的 reference 输入通过 loader；无名称特权；设计数据不能进入 measurement validation；缺失数据有精确获取任务。没有数值 inverse 与留出运行前，R02 不可标通过。

## W04：方程闭合与下一条物理边界（Sol 主线）

与三个 worker 并行，由 Sol 亲自做。父要求 R03–R05。

逐项审查当前 unknowns、弱式、源、外边界、接口与 flux 约束，确认欠定/超定/兼容性和物理意义；特别检查压力/电流拓扑、外部 coils/Kouter/return path。将“数值停滞”与“真实闭合缺失”分开，不用 regularization 伪造物理闭合。

输出可执行的下一版最小物理问题与独立 benchmark，不删父目标。随后为 Luna 编写具体的空间/时间、输运/燃烧、线圈/热/功率 producer 工作单，让下游真正消费上游状态。

## 首轮验收命令

以下两个命令在本轮审计已确认可用；后续只能以新输出路径写新的复核报告。Python 路径可先用 `Get-Command python` 验证。

```powershell
Set-Location -LiteralPath 'D:\006-Programing\LMC\FusionConceptAI'
python docs/reports/goal_recovery_20260913/recheck_solver_stagnation.py
python scripts/verify_v4_spatial_manifest.py runs/spatial_chain_20260912_r1 runs/goal_recovery_start/manifest_recheck.json
```

第二个检查器针对这个具体历史失败/恢复运行，含固定四工况和保留程序异常的预期。它可以复核基线，但不能原封不动作为未来成功链的通用 authority 或验收器。

第一个脚本 exit 0 还必须对应 JSON 中 `recorded_stagnation_reproduced=true`；检查不成立时返回 exit 1。这个成功只表示旧故障机制被复现，绝不表示 solver 已修复或物理已通过。

其余 focused/runner 命令由 Sol 在检查真实测试入口、依赖与当前文件后写入工作单。不要把尚未创建的文件名当作已经执行过的命令。
