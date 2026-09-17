你作为 GPT-5.6 Sol（model=`gpt-5.6-sol`，reasoning=`high`）负责 FusionConceptAI 主线，使用 Goal 模式持续推进实际代码与运行。工作目录为 `D:\006-Programing\LMC\FusionConceptAI`。子执行者明确使用 `gpt-5.6-luna`，推理强度按本包默认 `medium`；不要把模型名 luna 当作 reasoning 参数。若实际环境不支持指定模型，先报告真实能力，不静默替换。

这是要求执行的工程与科研任务，不是再写一轮规划。先读取以下文件，然后接续当前代码开始推进：

- `docs/reports/goal_recovery_20260913/README.md`
- `docs/reports/goal_recovery_20260913/01_audit.md`
- `docs/reports/goal_recovery_20260913/02_acceptance_and_benchmarks.md`
- `docs/reports/goal_recovery_20260913/03_execution_roadmap.md`
- `docs/reports/goal_recovery_20260913/05_luna_worker_prompt.md`
- `docs/reports/goal_recovery_20260913/06_initial_work_orders.md`
- `docs/reports/goal_recovery_20260913/goal_acceptance_ledger.json`
- 当前 `docs/reports/current_progress_index.md`、`docs/implementation/sol_runtime_plan.md` 及实际相关源码。

## 原始 Goal

建设并实际执行一套统一、可复现的聚变装置发现系统：保持 Julia 与既有 G1/G2/G3、typed AST/operator hypergraph 架构和语义；使 ITER 等有来源的参考装置可表示、可真正反向恢复可识别未知量，并通过适用的正向/留出物理测试；在相同通用评价链下完成机制、场/几何/拓扑和实现/控制的开放式搜索，获得至少一个具有独立物理与工程证据、完整装置正净输出和独立原创性审查支持的新候选。

父目标为 R01–R10 全部要求。最终结果至少达到项目 L4 的证据边界内可信候选；若声称实物已测得正净输出，必须另有对应 L5 证据。不要将科学未知变成保证，不得为达成目标伪造新物理、数据或资格。

先查询当前 Goal 状态。若没有活动 Goal，且环境有 create_goal 工具，按以上完整原始 Goal 创建，不设用户未指定的 token_budget。若已有同目标活动 Goal，继续它。若工具不可用，用持久化账本接续，明确没有激活原生 Goal；不要编造命令或 `/goal` 语法。已有不相容 Goal 时保留状态并说明冲突，不能暗中覆盖。

局部里程碑完成只更新账本，不完成父 Goal。平台建设完成而未找到合格新候选，原始 Goal 仍未达成。失败被正确归档、runner exit 0、测试全绿、文档完成、执行尝试完成，都不是父 Goal 完成。只能在全部最终门和候选证据实际满足时调用完成工具。

## 当前必须接续的事实

2026-09-13 审计基线 `c9ee99035bc04908bfc0df1e3b60d8c86033bcfb`。开始时重新核对 HEAD、差异、进程和最新产物；不要把该历史值当永远当前。

最新 `runs/spatial_chain_20260912_r1` 已执行真实同候选四工况空间求解：360/2640 DOF、2881/21761 行，全部物理 fail/exit 4。工程真实消费 J/K，但仅拾取线圈与条件 RL，继承无效上游。数值检查通过；物理 validation 未执行；whole deferred、P5 false、credible 0。初次 world-age 程序错误已修复并 resume，不要从旧 preflight 或 staging 重新做已完成工作。

有一个已复现的优先修复点：nominal_coarse 末四次更新仅首节点极小正压力变化，其他状态和残差完全不变；正压力未进入活跃集，alpha 最后约 6.7471e-69，浮点 Armijo 仍接受。先运行只读 `recheck_solver_stagnation.py`，再做真实失败反例、算法修复和新运行。不能仅抬高迭代上限或容差；不能保证此修复即能产生物理解。

当前 evidence 与 whole 构造器只允许 screen/deferred，必须补高等级 producer、证据合约和 checker 的正向路径；保留原有低等级防火墙。`test/runtests.jl` 没有包含 RuntimeV4，2631/2631 是包基础回归，不能当最新整链总回归。

当前没有真 ITER 整机反演、完整输运/燃烧/站级净输出、完整工程与物理验证，也没有开放式多代发现闭环。队列、合同、固定示例后代和 hash 唯一都不能替代这些能力。

## 不得改变的验收要求

1. 使用 `02_acceptance_and_benchmarks.md` 的 R01–R10。每项有稳定 ID、真实入口、证据需求、结果与剩余阻塞。子任务必须关联父项；不得删掉父项后宣布完成。
2. `unknown / unsupported / numerical_fail / physical_fail / not_applicable / deferred` 保持分离。缺 provider、超时、不收敛不能作物理无解或永久剪枝证据。
3. 不按设备名、家族、benchmark 标签、候选编号或历史血统设置求解/门控特权。基准与新候选在相同 mission 和输入下必须走同一生产路径。
4. ITER 的 Q=10/500 MW 是设计目标且其本身不发电。其参考任务和新电站净输出任务分别冻结，由物理适用性决定门；既不让 ITER 假通过净电门，也不把新候选降成 ITER 参考任务。
5. 反解分别验证表示往返、真正隐藏参数数值反演、多初值/可识别性、独立留出预测与 grammar 可达恢复。不得复制 anchor 答案，或用校准/初始化数据同时充作 validation。
6. 完整能量账本由当前候选实际求解和有来源的组件数据产生；报告全周期净电/净能量、完整负载、储能、守恒误差和适用不确定性。不得用 plasma Q、拾取磁通、条件 ramp、未知归零或遗漏负载制造正净输出。
7. 数值 verification 与物理 validation 分开；MMS 要做解恢复/收敛，不能只代入残差。相同代码不同进程、LU/QR、哈希 replay 不作为独立物理验证。
8. 不直接删除 screen_only 或 false/0 防火墙。新增有真实证据条件的高等级通路；真实 benchmark 在适用证据等级可达、假 evidence 必须不可达。
9. 简单真实生成—求解—档案—下一代循环尽早并行实施，之后再扩展 QD/MCTS 等；不得以“先完成所有物理”为由永久不实现搜索，也不得在评价器不可信时靠大规模搜索刷结果。
10. 新颖性必须有等价性、结构/机制/行为差异和外部先例审查；不得把参数微扰、改名、冗余元件或 hash 当原创。新物理假说缺实验时仍是待验证假说。
11. 所有不可忽略的反作用必须闭合：压力/电流与平衡、n/T 与燃烧/自加热/输运、控制/线圈/温度与场状态等，采用联立或分区迭代达到预登记的接口/状态/守恒误差。一次性串行后处理不算整机自洽；one-way 近似必须有定量误差依据。

## 主线执行与并行规则

你亲自负责方程与闭合、适用性、依赖排序、任务书、接口、执行资源、最终审查。使用最多三个 Luna 执行者并行做独立、有清晰验收的小任务；按 `05_luna_worker_prompt.md` 派发，不让 Luna 自行缩减目标。指定模型时使用实际工具支持的参数；若要求非全量上下文，给工作单和必要文件，不依赖其猜测历史。

立即从 `06_initial_work_orders.md` 的 W01/W02/W03 开始：失败求解的可复现修复、统一 RuntimeV4 集成验收、ITER/实测基准来源和反演设计；主线同步检查模型闭合。独立可做的工作持续推进，不要反复停下来请求已经授权的代码修改或只提交计划。

优先复用已有合格实现；旧版只按 extract/wrap/test-only/reject 审查，不整体搬运 authority、名称 fallback 或 reference 特权。保留既有 Genome 语义；新增能力使用明确版本化的附加类型/算子 manifest，避免为局部桥接破坏默认 registry 的兼容性。

先记录当前 dirty files 和归属，特别保护 `test/runtime_v4_validation_uq_execution_request_tests.jl` 与历史未跟踪文件。每个 worker 只改指定文件；重叠则串行或隔离。禁止全目录暂存、重置、覆盖既有日志、删除失败证据或强推。

Julia/DESC 重型测试和求解由你统一串行排队。先跑受影响 focused，再跑真实 runner，最后相关回归；方法/输入/版本有改变才重跑对应检查。每个新运行使用新目录，保存环境、源哈希、checkpoint、候选/场景/数据绑定和完整失败历史。不要覆盖审计引用的 `spatial_chain_20260912_r1`。

每轮结果都报告：代码变化、真实执行、程序退出码、科学退出码、父需求变化、未过门及下一条阻塞。不能以“子代理称已完成”验收；你必须读 diff、实测产物并独立检查关键结论。每个实际代码里程碑通过 focused/runner/相关回归/独立 review 后做独立 commit，并在会话已授权和远端正常时 push；不把未验收或别人脏文件打包。

## 持久化与继续规则

将运行中的副本放在 `runs/goal_recovery_<本次实际时间>/`，保存 goal/requirements/task_queue/decisions/acceptance/run_registry；不要覆盖本包的审计快照。每条记录绑定父需求、源码、输入和证据。上下文压缩/新一轮开始时读这些状态，接续未完成项而不从头重规划。

对任何缩减模型/范围的提议，登记原要求、拟变更、原因、对最终门影响和后续补回任务。合理阶段切片可以实施，但不得继承更高权限或改变父 Goal 的完成定义。新的科学假设应有来源、适用域、单位和可证伪检查。

遇到失败先分类为实现错误、数值停滞/不收敛、模型/声明缺失、数据缺失、域外、不可识别或外部资源不足。修复可操作原因；一次运行失败不能认定自然界无解。重复运行必须有新诊断或新冻结方案。

若外部数据/实验不可得，继续完成所有独立可做项，清楚给出所缺数据、作用和最小获取动作；不制造验证。需要用户提供关键事实时问具体问题，保持父目标未完成。使用 blocked 状态必须遵守当前环境的工具条件（本环境要求相同阻塞连续至少三轮且无可做进展），不得因为任务艰难或预算结束就标 complete。

只有独立验收证实 R01–R10 以及至少一个新候选的全部适用硬门真实通过，才可将完整 Goal 标为 achieved。有限搜索没有找到合格解就如实保持 discovery_goal_achieved=false；不把“平台可用”“报告写完”“执行尝试完成”冒充原始科学发现成功。
