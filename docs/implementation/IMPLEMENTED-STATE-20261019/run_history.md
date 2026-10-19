# 运行历史简要结论（截至2026-10-19）

实验 Goal 已暂停。本页汇总既有软件、数值和来源诊断，不改变任务接受状态。用户本次要求将大部分原始运行结果和日志汇总后删除；完整保留范围及逐文件SHA见[清理记录](../WORKSPACE-CONSOLIDATION-20261019/README.md)。

## 如何核对历史

清点覆盖 5473 个历史目录分组，找到 4578 份可解析/可定位收据。按收据原有 `passed_software_check` 字段，2502 份为 true，1966 份为 false，其余 110 份无该字段。这里统计收据，嵌套进程会各有记录；不能把数量解释为独立科学实验数或接受次数。

- [收据索引TSV](../WORKSPACE-CONSOLIDATION-20261019/run_receipts.tsv)：目录、原receipt路径、退出、资源、清理及pins，方便按名字检索。
- [压缩历史索引](../WORKSPACE-CONSOLIDATION-20261019/run_history_index.jsonl.gz)：每组收据字段、有限日志摘录和已删JSON的标量投影。投影声明了采样/数组省略，不保证覆盖全部报告。
- 历史receipt及source/input pins的JSON保留原路径；已退休代码家族专属元数据随家族进入摘要和删除清单。摘要/哈希不能重建已删数组、检查点或日志。缺原始字节的直接复放须重新生成，不能用本页补通过。

## 按工作线归并

| 工作线 | 已取得的结果 | 接受边界和保留的失败 |
|---|---|---|
| UP1 / UP2-00 | 用户约定的来源/T0/T1/native Gridap软件范围与合同消费者A/B可复用；对应当前接受记录和actual source/native pair保留 | 只保留原软件范围；旧独立T2未接受、已取消。此前缺失的历史原件本次没有重建 |
| DCCE / UP2-01 | focused r21：静态27/27、负例6/6、离散时间32/32、source-bound BE MMS/时间细化217/217、双场耦合35/35，共317项 | exit 0，资源/pins/cleanup完整，仅限定软件/数值范围；未知合法组合/预留组合及UP2整体仍未验收 |
| 自研Q1 | Q1_4有限全列FD；Q1_8按用户决定接受当前数值状态 | 原残差1.5257218976168253e-5未满足旧1e-6门，历史numerical_fail保留；完整2080列FD及完整fresh replay未执行。不恢复降残差专项 |
| C771实际KKT | r17通过4 GiB资源门，峰值4,091,719,680 B，181.30 s | stationarity约2.105e-5、true-KKT相对缺陷8.713e-8、Schur相对残差1.705e-5；198个压力违例、最大约3.302。无接受步/下降证明，不能解释为物理不可行性证明 |
| 完整64点B/J | near r7完成部分E/G检查点；far r6成本预测覆盖7200个edge key | near未产生合格native B/J，当前实现的收缩成本超过其原预算；far约5.061e9操作只是经验预测，两个类未匹配、provider调用0、full64=false。不能以预测充当全64证明 |
| 连续Jn/周期守恒 | 64点离散行、局部根/导数和部分扇区诊断 | 全LCFS连续误差界、全部64扇区signed/gross积分、回流路径仍缺；sector35无共享缓存的尝试超时。点值1e-4 A/m²、gross1e-3 A、signed1e-4 A的原科学门保持 |
| UP3 | 当前FV组合A/B和stale-route因果负例有限范围；Q1 targeted dispatch r4 screen-only，20次solver调用，末源密度残差约2.27e-13 W/m³ | full17 r2：OOM、资源门失败；r3：资源门通过但测试释放base后仍取base.spatial，19pass/2fail/1error；r4：674.67 s采样缺口、exit94。均不是full17接受 |
| UP4 | MAST来源诊断、固定电流forward screen、优化/handback接口与部分实际调用 | PF signed映射/匝数、Thomson校准/误差语义、真实三Genome参数反演与同链heldout未完整取得；调用次数不能抵消资源失败 |
| UP5 / UP6 | 工程反馈、搜索、验证/UQ接口及制造/结构控制 | 尚无一个同一新候选同时通过物理、工程、全周期站级正净输出、VVUQ、原创性和独立新进程复放；R01–R10保持未完成 |

## 最新UP3失败后的处理

组合wrapper已补齐显式 `accepted=false`、`evidence_credit=0`、`physical_validation=false`、`engineering_validation=false`，并进入结果hash；独立Q1 dispatch和full17中已到达的组件检查通过。队列测试保留 `base_spatial` 后释放大source/package临时对象，三处后续构造器都复用该快照；当前缺完整整体验证。

直接空输入构造器的限定检查2/2通过，9.44 s。暂停时的 `up3_up3_queue_rejection_focus_20261020_r1` 未写出最终receipt；实际复用的启动参数仍指向整份full17，聚焦脚本仅被pin，不能计作聚焦测试通过。其人工中断说明见[单独记录](../WORKSPACE-CONSOLIDATION-20261019/user_pause_interruption.json)。目录中的日期标签不覆盖本页客户端日期。

## 本次整理的维护验证

131份Python源码AST检查通过。源码清点发现跨网格控制体权重生成式无法解析，已等价改为显式循环，并补齐load-only检查的类型定义依赖。最终346份Julia源码解析通过，模块加载5/5、非均匀轴网格的解析总体积/正权重检查4/4通过；9.15 s、峰值352,702,464 B，资源/pins/cleanup完整。这里没有执行真实网格迁移、KKT、参考反演或搜索。

前置静态检查脚本的soft-scope错误、原源码解析失败和短检缺类型依赖各自保留失败记录，最终受影响检查通过。详见[维护验证](../WORKSPACE-CONSOLIDATION-20261019/cleanup_verification.json)。

退休后扩大到兼容测试的Python扫描发现两个既有T2静态QA脚本的列表推导式过滤条件末尾有非法逗号；四处逗号最小修正后，剩余347份Python语法全部通过。T2未执行、未恢复或接受。规划校验通过46个任务、25个有限范围接受记录、10条工作线和129个相对链接；规范00中10月16日已存在的Jn段落用精确可逆差异校验，科学条款没有因清理改写。

## 清理后的复放含义

本次移除 70,873 个文件、61,457,124,451 字节，保留暂停点明确输入/检查点 360 个、1,835,254,241 字节；实数以清理收据和独立校验为准。原始参考输入、当前源码/fixtures及当前UP1接受结果单独保护。大部分历史数组和重复状态已不再可直接反序列化；如后续门要求它们，必须按保留配方重新生成。
