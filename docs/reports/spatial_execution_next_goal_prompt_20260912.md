继续推进 D:\006-Programing\LMC\FusionConceptAI，接续现有空间求解实现，完成真实整链执行和 Git 交付。

本阶段目标是：同一新修订候选的完整空间多区域残差与耦合求解实际尝试 → 真实电流到有限孔径拾取线圈的工程计算 → 独立数值验证、实际参数传播与整装评估。允许科学结果 fail、缺失能力 unsupported/deferred；不允许用接口、制造轨迹、缺口账本或局部绿测代替执行。

1. 先只读核对 HEAD、origin/main、未提交文件、当前进度索引，以及 docs/reports/spatial_execution_handoff_20260912.md、docs/implementation/spatial_execution_contract_v4.md。源码位于 runs/spatial_chain_20260912_staging/，哈希清单位于 runs/spatial_chain_20260912_audit/closeout_source_manifest.json。保留全部既有未提交工作，特别是 test/runtime_v4_validation_uq_execution_request_tests.jl；不得全目录暂存。

2. 准确接续现状。51b5540 已提交并推送的是四幅值、36 行的降阶链路；r3 runner 退出 0，物理 3、工程 0、核验 1。它不是完整空间求解。空间源码尚未提升到正式目录或验收：工程 focused 60/60、验证最终 focused 33/33 退出 0；物理旧版 focused 33/33 退出 0，但最后新增的失败尝试账本尚未重测。根智能体新增 graph tests、runner、whole assessment 尚未执行。候选预检因用户要求收尾而中断，进程已停止、工具退出 1，不能解释为科学失败或预检通过；尚未启动空间阶段 DESC/求解。

3. 先完成有限集成修复和预检，不再铺开新模块。审查并提升 staging 文件后检查所有相对路径；集中运行受改动影响的 focused、graph 和候选预检。定位候选构建/验证的重复工作，增加阶段计时与输出，避免长时间无日志；只消除重复调用，不削弱身份校验。补充 Python 依赖版本、METADATA/RECORD 哈希、平台与线程配置快照。核对最后一次 QR/线搜索失败的 attempts、accepted_update_count、状态历史和退出码确实保存并可重放。

4. 延续冻结的最小 typed contract 和文件所有权。可恢复至少三个子智能体分别负责物理、工程、验证；先读已有实现和复用审查，避免重复开发。主智能体负责候选、runner、依赖连边、执行队列、审查和验收。Julia/DESC 重型运行只能由主智能体串行排队。各分支没有独立启动求解的权限。

5. 建立并核验新的空间候选修订：父候选来自已执行的降阶候选，保留 lineage、变化记录、来源、单位和适用范围，重算 G1/G2/G3 与上下文哈希，重新执行必要上游。旧 p/iota 只能作初始化；不得把旧候选收据嫁接到新候选。保留 Julia、三层 Genome、typed AST/operator hypergraph、局部附加 operator registry；禁止旧 authority、家族标签路由和隐藏物理正则化。

6. 按契约真实执行四个场景：nominal_coarse、nominal_fine、flux_low_coarse、flux_high_coarse；固定主结果为 nominal_coarse。粗/细空间为 360/2640 个 B_R、B_phi、B_Z、p 自由度，2881/21761 行残差。实现并实际组装全部体项、源项、局部面、周期配对、区域界面、外边界与总磁通约束，计算全状态稀疏 Jacobian 并尝试状态更新。保存初始/最终场、每次尝试、接受步数、分块残差、全局守恒诊断、秩/非唯一性、停止原因、资源与明确退出码。不得将 N 与 Wb 原始残差混为一个误差；不得将 B divB/μ0 遗漏后的强弱差归为积分误差。

7. 工程必须消费每个真实物理场产生的 J=curl(B)/μ0 和界面 K，执行 Biot–Savart、有限孔径磁通和独立 reciprocity。区分候选声明几何包围界、实际 DESC 谱系数连续包围界与样本检查；不得悄悄挪动线圈或用采样界冒充连续净空证明。静态实际场给出静态磁通及零 EMF；预设 ramp 下的解析 RL、短路与固定 10 μs 保护只能标成条件设计场景。缺外部线圈、outer K、回流路径及上游不收敛时必须传播 unsupported/fail，不能标工程合格。

8. 实际执行独立 formulation、每列每块 Jacobian 核验、两级非零源解析 MMS 和独立电路能量核验。实际运行候选磁通 ±5% 端点的空间求解并传到工程输出。分别报告积分诊断、离散差异、求解误差与模型残差；两级失败状态不能证明收敛阶。MMS 只提供软件验证，探索性区间不是概率分布；不得制造置信区间或物理 validation。适用实验数据、独立物理求解器或模型偏差依据缺失时保持 unsupported。

9. 严格绑定实际执行依赖，不只比较候选哈希。校验 upstream request/result/receipt/HDF5 → physics → engineering → verification → whole 的全部连边及原始文件哈希。恢复前检查运行进程、checkpoint、源码和输入；不能重复启动已运行的求解。缺 checkpoint 但阶段目录非空时先审查并恢复已完成产物，禁止覆盖重跑。源代码修复后明确哪些旧结果仍可重放，哪些需要重新执行。

10. 用统一 runner 完成整链，逐阶段列出声明完整性、模型实现、是否执行、实际结果、科学状态/退出码、上游有效性、剩余阻塞、原始产物和复现命令。源码稳定后集中运行相关回归和独立审查，不重复整套昂贵测试。更新 docs/implementation、docs/reports、当前进度索引，只暂存审查过的文件；按真实完成的里程碑 commit、push，并核验远端 HEAD。

最终汇报只围绕：新增真正执行了什么；实际计算得到了什么；还断在哪里，并区分缺模型、缺候选声明、缺数据、计算失败。若完整空间求解尝试或真实工程执行仍未发生，明确本阶段目标未达到，不得以新增文件或通过测试数量替代验收。
