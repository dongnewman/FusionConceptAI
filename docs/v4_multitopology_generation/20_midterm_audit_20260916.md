# 2026-09-16 中期审计：阶段进度、阻塞与证据边界

**历史审计（2026-09-16）：** 下文进度、HEAD 与门禁描述是当日快照。2026-09-17 用户取消外部认证对研发的阻塞，当前规则见 [22 自主研发合同](22_agent_local_execution.md)；不得据此历史审计重新要求外部责任人，也不得把旧结论改写为当前事实。

## 1. 审计结论和口径

当前取得的是三层 Genome 合同、身份传递前置软件、源码发布与 locator 可移植性的进展。**尚未跨过 UP1 的整体退出门，UP2 的声明驱动通用执行尚未交付；UP3–UP6 只有有限旧原型和准备合同，不能按阶段完成计数。** 这不是“完全没有实现”，也不是“只差 S3 就能做物理搜索”。

本次按用户要求审计并整理文档，不运行新的物理 campaign、不修改求解器、不提交或推送代码。审计基线为 `b2c04d8339774635aaecd73651efcdb101e01b5d` **加实际脏工作树**；冻结了 5,968 个现有文件的 SHA-256。基线、独立分项审查、校验和修改清单保存在 [中期审计档案](../implementation/MIDTERM-AUDIT-20260916/README.md)。历史验收的时间和范围保持原义。

判定依据依次是：原父目标与当前合同、任务退出门、真实源码和输入、运行原件及独立复核。文件夹存在、测试断言数、AD 编号、`accepted_limited` 数量、runner exit 均不表示物理完成比例。本报告不提供缺乏计量依据的百分比。

## 2. UP0–UP6 到哪一步

任务表有 39 个节点：6 个 `accepted`、33 个 `planned`。这是调度状态计数；其中 accepted 仍只覆盖其验收书限定范围。AD 子切片的有限接受不会自动改变父节点状态。

| 阶段 | 任务表计数 | 当前可计入的成果 | 尚未通过的阶段退出门 | 审计判断 |
|---|---|---|---|---|
| UP0 | 2/2 accepted | 基线/脏文件保护与历史失败审计；版本合同和预先验收协议 | 每次执行仍须刷新 HEAD、实际 dirty bytes、环境和输入；不能继承旧进程状态 | 基线与协议已建立；本次已刷新审计快照 |
| UP1 | 4 accepted，11 planned | G1/G2/G3 有限结构合同；additive V5 集成接线；部分 typed edit、declaration transport、authority recheck 软件；AD54 发布和 AD56 locator 修复 | 完整同候选三层来源/四轴/映射；T0→recheck→T1→T2；aggregate；正式 B00 F0–F5 与 B04 50 条；最小组件数值验证 | 合同与前置软件部分完成，**整体未完成** |
| UP2 | 9 planned | typed precompiler、N01–N10 相关投影/缺口检查与局部前置软件；旧 RuntimeV4 有有限执行切片 | 任意已声明支持算子的组合 lowering、变系数/各向异性/多场残差、几何与离散、拓扑守恒传递、外部域、耦合求解、成熟模块能力接入 | 尚未交付通用执行层；前置检查通过不等于方程求解通过 |
| UP3 | 3 planned | 组合矩阵、留出组合、负控、oracle 和预算的准备合同 | 未写候选专用驱动的自动组合真实求解；守恒、反馈断边负控、留出组合；可信降维 | 准备阶段，正式组合验收未开始 |
| UP4 | 4 planned | 参考数据/坐标/单位与源、线圈、执行器输入合同；旧链有有限子系统 | 源与硬件逆设计，供能/热/材料/结构/控制闭环，真实参考隐参数恢复、可识别性及留出预测 | 准备和局部原型，不是一般 realization |
| UP5 | 3 planned | typed AST、hypergraph 和有限条件 e-graph/迭代原型；改写/编辑/预算准备 | 条件等价证明、真实跨 G1/G2/G3 编辑与重新求解、反馈影响提议、可恢复有界 campaign 和扩容证据 | 尚未形成要求的开放发现闭环 |
| UP6 | 3 planned | provider/VVUQ/工程/原创性/复放/R 账本模板 | 全部适用终局义务、独立验证、全周期净输出、原创性和新鲜复放；至少一个 L4 候选 | 终局未开始验收；R01–R10 全部未关闭，L4=0 |

逐项源码依据见 [UP 进度独立审查](../implementation/MIDTERM-AUDIT-20260916/up_progress_review.md)。完整退出标准继续以 [13 验收合同](13_acceptance_benchmarks_and_evidence.md)、[16 工作单](16_execution_work_orders.md) 和 [任务表](task_manifest.json) 为准；本表不删除任何细项。

关键代码事实进一步解释了“为什么现在还不通用”：

- [Compiler.jl](../../src/RuntimeV4/Compiler.jl) 的 `_runtime_edge_obligation`（49–80行）对非零空间维数返回坐标声明缺口，最后也不生成真实物理算子义务；当前主要是结构与能力检查。
- [FieldProgramEvaluation.jl](../../src/RuntimeV4/FieldProgramEvaluation.jl)（321–370行）仅支持有限单chart静态标量screen；map/metric未执行，导数等算子延期。这一局部执行器的限制不能解释成项目已经拥有完整PDE编译。
- [FieldGeometryGenomeV5.jl](../../src/GenomeV5/G2/FieldGeometryGenomeV5.jl)（217–230行）的admission输出mesh/physics为not_executed；声明写有conservative并不证明离散传递守恒。[SpatialMultiRegionV4.jl](../../src/RuntimeV4/SpatialMultiRegionV4.jl)（333–342行）仍明确不认证外部电流闭合、守恒和物理验证。
- [ConditionalEGraphSaturation.jl](../../src/IR/ConditionalEGraphSaturation.jl)（151–265行）有真实有界derive/replay原语，typed AST和hypergraph也实际存在；但尚未查到它们完成生产搜索—求解—反馈闭环。不能说“完全没用”，也不能说“已经解决通用搜索”。
- [CoupledRealizationControlBindingV2.jl](../../src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl)（86–94、185–191行）明确值相等不建立来源authority。资源/反馈字段和child edits不构成源硬件逆设计，更不构成热/结构/控制回代。

这些是静态可定位的能力缺口。基降维、更多迭代或改换某一个后端，都不能单独补上未实现的算子、几何、闭合与反馈链。

## 3. AD54–AD56 到底证明了什么

1. **AD54**：本地 `b2c04d8` 发布 21 个目标源码文件；只证明该次发布工程闭包。未推送/打标签不能替代信任来源，也不是物理成果。
2. **AD56**：G1 35/35、G2 35/35、G3 356/356，独立对抗 20/20；修复 Windows checkout raw bytes 与 Git canonical blob 的混用。正确区分二者是必要的软件修复，并未放松内容篡改检查。
3. **AD55 R2**：F0 和两次 S2 的 exit=0，六个 scope 输出 source-stage present，18 份 identity/declaration/receipt 可重复。磁盘每次有20个JSON，其中2个是negative_controls/status辅助文件；determinism清单明确是18。执行报告的“19 canonical JSON”是文案计数错误，本轮追加纠正，原报告和原始证据不回写。
4. 用户转述 Sol 的 `accepted_limited` 已在本次 [AD55 裁决归档](../implementation/MIDTERM-AUDIT-20260916/AD55_decision_archive.md) 中明确署为“用户转述的 Sol 裁决”，并与本轮审计判断分列；没有伪装成新增 Sol 签名或一次新的 Julia 运行。

**“current-HEAD”需要限定**：六个被定位的 Genome source-owner 文件的 canonical 内容可绑定到 HEAD；执行它们的三份 `G1/G2/G3SourceAuthorityFactoryV1.jl` 当前带有 AD56 未提交修改。因此应表述为“HEAD 来源对象 + 冻结的 AD56 工作树执行器”。不能由此声称只 checkout `b2c04d8` 就含有 AD56 修复。下一次复放必须同时冻结执行器、导入闭包、测试/探针和环境身份；是否再做受控源码发布另按明确工作单处理。

**另有执行输入清单缺口**：AD55 R2记录了六份owner、三份dirty factory等哈希，但未在其输入清单中逐项冻结实际probe/harness和完整加载依赖；独立记录也不完整。原运行及raw/PID/exit仍成立，但“完整可重建执行闭包”的声明要进一步限定。下一次运行前补冻结，不能把今天重算的hash反填为旧运行前已经冻结的证明；若要补足这一复现声明，应在新目录对完整冻结输入复跑。当前task_manifest本身也未包含在该21文件HEAD发布中，规划校验是工作树证据。

AD56原接受书及核心18末段中的“AD55仍需fresh rerun”是修复接受当时的历史状态；AD55 R2及独立R1已经提供后续复跑证据。本轮索引以此更新F0/S2状态，旧句不再是重跑同一任务的指令；fresh S3仍未被替代。

AD55 的 source-factory `F0/S2` 与 B00 的 `F0–F5` 是两套命名空间。前者通过不关闭后者，也不产生 B04 的 50 条正式候选绑定收据。细节和实测哈希核对见 [来源证据独立审查](../implementation/MIDTERM-AUDIT-20260916/source_evidence_review.md)。

## 4. 总架构师面临哪些问题

| 问题 | 性质与责任边界 | 可执行处置 |
|---|---|---|
| 外部 trust root、独立 attestor、密钥/证书/签名、验证器、吊销/时效/可信时间/防重放材料缺失 | 当前合同下的外部输入阻塞；智能体不能以本地 hash、评审或测试自授独立信任 | fresh S3 如实输出 typed absence；一次列清缺项、需要的提供方和验证方式，等待有效输入发生变化后才重跑 |
| 设计来源身份、可信来源身份、数值验证和物理证据混在同一条串行门里 | 架构分层风险；是本次审计判断，不是已证明无法求解 | Sol 必须说明每道门保护哪一类声明；如提出测试专用数值工作线，先作版本化范围决策和独立复核，不暗改现有候选/authority 门 |
| T0/T1/T2、G2 mapping、四轴、最终候选身份尚未闭合 | 有限软件和合同集成缺口，不能归因于 Python 安装或 MHD 后端不够通用 | 输入具备时按现有依赖集成；输入缺失则输出具体 typed gap，不增加同义临时身份或反复预备审查 |
| UP2 编译、离散、耦合仍缺真实执行 | 主要工程与数值研究工作，尚无证据说明 Sol/Luna 无法完成；也无证据说明只换 FreeGS/DESC/FUSE 即可完成 | 按算子残差、空间离散、接口守恒、求解反馈逐个纵向切片交付，并保留成熟数值算法 |
| 真实数据、校准、独立验证、材料工况与制造约束缺失 | 一部分需外部资料/实验或专业判断；代码不能凭空生成可信数据 | UP4/UP6 明确数据和验证任务的负责人、许可、版本、单位、适用域、误差、独立性及取得方式 |
| 一般抽象拓扑未必可物化、可闭合或可制造 | 适用性边界，不是可以靠搜索次数解决的软件缺陷 | 允许声明域内扩展；域外准确 unsupported/deferred，不能悄悄退回固定装置族或伪造结果 |

**没有证据可断言“总架构师能力不足，解决不了全部问题”。有证据说明当前主线长期停留在 provenance/authority 前置链，尚未把合同投入主要数值能力。** 外部输入不能自动解除；内部编码与分层问题必须转化为有限工单。下一轮需要产出可验证能力或明确的外部阻塞交接，不能只增加一份状态同步文档。

不把缺乏独立 attestation 的对象冒充可信来源；同时，制造解/解析解的数值测试本来只证明离散实现，不能要求它伪装成实验事实。现有 DAG 对正式候选执行的门保持不变。若要并行做不产生候选身份或物理信用的测试专用数值组件，Sol 须先明确其与正式链的隔离、允许输入、输出上限和回接条件；当前仅允许已授权的静态准备，不能凭本报告擅自越过执行门。

## 5. 档案审计发现与本次调整

| 发现 | 对 Luna 的风险 | 本轮处理 |
|---|---|---|
| README 的“当前事实”起于旧 HEAD，后面逐轮追加 AD，较新 AD55 不在主索引 | 按旧 S2 pending/旧未跟踪源码结论重复工作 | 核心入口改为当前快照与 UP 表；两份入口原文逐字节存档，历史没有删除 |
| `accepted_limited`、node accepted、phase accepted 混读 | 软件局部接受被推成主线解锁 | 增加三个独立维度：正式任务状态、子切片范围、阶段未过门 |
| AD 编号代替依赖关系；重复 status sync 使实现路径埋没 | 新执行者逐个翻数十档案仍不知道下个输入 | 增加 UP/任务到档案的机器目录、人工导航和带输入/输出/分支的下一轮批次 |
| 当前执行器 dirty 身份与“HEAD”简称混用 | 误报 clean-checkout reproducibility | 记录 HEAD 来源对象与实际执行器工作树身份分离，下一跑冻结完整执行闭包 |
| AD55 Sol 裁决只有用户转述，历史报告仍 review_pending | 未归档决策被忽略或反向改写历史 | 新增带来源标注的决策记录，原执行/独立报告保留 |
| 旧 AD 显示 planned 而局部前置软件通过 | 错把未更新状态当作“没有代码”，或擅自批量 accepted | 39 节点及其 hash 不改；目录显示有限软件成果并显式保留父门 |

本次不改原始验收标准、R01–R10、任务 DAG、Genome 语义、已验收历史记录、失败日志、代码、测试、registry 或运行产物。文件重排只发生在活跃入口；档案补充采用新目录。目录分类是检索提示，不是新验收授权。

## 6. 下一轮的具体交付

执行细节见 [21 下一轮执行批次](21_next_execution_batches.md)，不能只把“执行 fresh S3”当作完整目标：

1. 冻结 HEAD + dirty 执行闭包和环境；吸收本轮 AD55 归档，避免再造同范围 AD。
2. fresh S3 一次如实裁定；缺外部 trust root 时列出可交接的阻塞输入，严格禁止 present 升级。
3. 来源条件满足则推进 T0/recheck/T1/T2、正式 B00/B04；条件不足则交付明确阻塞分支，并在现有权限内完成 UP2 数值切片的可执行设计。测试专用执行需要先解决范围和依赖决策。
4. 让下一份实质能力交付聚焦“声明→真实残差→离散→求解→误差/守恒”，随后递进自动组合、逆实现和搜索；不先扩大搜索预算掩盖求解器缺口。
5. 独立 Luna 审查实现与边界，Sol 按证据裁决。任何 partial/deferred 都留在未完成账本，父目标持续开放。

本报告的源码判断是静态审计，历史数值结果只按原适用范围引用；本轮未复跑重型 Julia/DESC、未新增物理成功声明。正式结论须连同 [验证收据](../implementation/MIDTERM-AUDIT-20260916/validation_receipt.json) 与 [独立文档复核](../implementation/MIDTERM-AUDIT-20260916/independent_review.md) 阅读。
