## 从组件基因组转向物理程序基因组

当前路线大致是：

```
已有区域/组件
→ 拼成拓扑图
→ 填充参数
→ 求解
```

更本质的路线应当反过来：

```
状态空间 + 守恒律 + 对称性
→ 动力学算子程序
→ 产生场、相变、边界和拓扑
→ 提取涌现区域
→ 逆向实现为线圈、壁面、驱动器和控制器
```

这样搜索对象不再是“线圈、磁镜、闭合区、开放区”，而是一个可执行、可证伪的物理机制程序。

## 建议拆成三个相互独立的基因组

### 1. Mechanism Genome：机制基因组

这是原创性搜索的核心，描述“什么物理过程发生”，但不指定由什么装置实现。

包含：

- 状态变量：标量、矢量、张量、分布函数、相变量；
- 状态所在的流形、尺度和时间语义；
- 粒子、动量、能量、电荷、磁通、熵等账户；
- governing operator；
- additive operator；
- 非局域核、记忆项、随机项和事件算子；
- 对称性、规范约束、因果方向；
- 可观测量和可证伪预测。

其通用形式可以写成：

\[ \partial_t q_a+\nabla\cdot\Gamma_a=S_a, \]\[ \Gamma_a=\mathcal F_a[z,\nabla z,\nabla^2z, \mathcal K[z],h_t;\theta], \]\[ 0=\mathcal C_b[z]. \]

搜索改变的是：

- 有哪些状态；
- 哪些状态相互作用；
- 相互作用采用何种微分、积分、非局域或反馈算子；
- 哪些量守恒；
- 哪些结构是动态生成而不是预先给定。

而不是改变“它叫托卡马克还是磁镜”。

### 2. Field–Geometry Genome：场—几何基因组

不直接生成“线圈 A、壁面 B”，而是生成连续源和隐式几何：

- 外部电流密度 \(J_{\rm ext}(x,t)\)；
- 电荷、压力、动量或辐射源分布；
- 材料相场 \(\phi_m(x,t)\)；
- level-set 边界；
- 度量、坐标图和拓扑事件；
- 可变边界条件算子。

求解之后，闭合场区、开放区、分离面、磁岛、多个核心或动态通道作为结果涌现。

只有机制通过物理门后，才运行逆向 realization：

```
目标连续电流/场分布
→ 离散线圈、电极、激光、粒子束或材料结构
```

因此最终组件可能完全不像预先列出的装置组件。

### 3. Realization–Control Genome：实现与控制基因组

负责回答“怎样实现并维持这个机制”：

- 源的物理实现；
- 材料与结构；
- 传感器可观测量；
- 控制律及其记忆、延迟和饱和；
- 故障模式；
- 运行轨迹与启动/停机过程。

这个基因组必须与机制基因组使用独立 seed。否则一个 seed 同时决定机制、几何和控制，会重新退化成模板搜索。

## 什么可以进化，什么不能随意进化

要避免“原创性”退化成随机编造方程，建议采用三层权限。

### 固定硬核

通常不允许变异：

- 量纲一致性；
- 电荷、能量和物质账户；
- 明确声明的外部源；
- 因果性；
- 熵产生约束；
- gauge/坐标一致性；
- 数学适定性最低要求。

### 可进化机制

允许结构变异：

- 状态变量集合；
- operator DAG/hypergraph；
- 耦合、反馈和尺度分离；
- 局域/非局域输运形式；
- 边界动力学；
- 对称性破缺；
- 多时间尺度和事件。

### 假说算子

允许产生当前规则库没有的 `partial_operator`，但必须声明：

- 输入和输出；
- 单位与张量秩；
- 允许和禁止的守恒影响；
- 复杂度上限；
- null model 和 alternative model；
- 最小可测效应；
- 能区分它的实验或数值观测。

无法辨识的算子可以留在假说档案，但不能晋级。这部分现有 OTG v2 已经有结构基础：[OTG 状态与 interaction](D:\\006-Programing\\LMC\\outputs\\fusion_concept_ai\\docs\\open_typed_genome_v2_architecture_20260819.md)、[partial operator 合同](D:\\006-Programing\\LMC\\outputs\\fusion_concept_ai\\docs\\open_typed_genome_v2_architecture_20260819.md)。

## 基因不再是固定位数，而是可变长度程序

建议使用 typed AST、operator hypergraph 或 e-graph，而不是更长的十六进制字符串。例如：

```
PhysicsProgramGenome
├─ state_ontology
├─ invariant_and_account_set
├─ operator_program
│  ├─ governing_blocks
│  ├─ additive_blocks
│  ├─ nonlocal_kernels
│  ├─ feedback_blocks
│  └─ event_rules
├─ geometry_field_program
├─ symmetry_and_constraint_set
├─ observable_program
├─ unknown_operator_hypotheses
└─ complexity_and_evidence_budget
```

其空间原则上可以递归扩展，campaign 不再用“总共有多少点”定义，而是用描述长度限定，例如：

- 状态场：4–16；
- operator AST 节点：16–128；
- 微分阶数：不超过 4；
- 非局域核：0–4；
- 记忆算子：0–2；
- 事件规则：0–4；
- 自由函数和自由参数分别限额。

这样“最简装置”也可以改写为：

> 在相同任务、物理硬门和证据等级下，具有最短机制程序、最低实现复杂度且非支配的候选。

## 如何接入当前项目

不需要推倒现有架构。可以增加一条新主线：

```
PhysicsProgramGenome
→ 类型/量纲/守恒/可辨识性编译
→ OTG v2
→ v68 residual graph / Physics IR
→ 候选绑定求解
→ 涌现拓扑提取
→ v137 自由几何 realization
→ 工程与证据链
```

现有 v91/v138 组件拓扑生成器保留，但降级为：

- 对照组；
- 已知表达能力 sentinel；
- PhysicsProgramGenome 的一种 realization backend。

v68 已经具有 governing/additive residual、状态所有权、Jacobian、mass matrix、边界和守恒审计，因此可以作为新基因组的执行目标，而不需要重新写整个求解体系。[v68 残差编译入口](D:\\006-Programing\\LMC\\outputs\\fusion_concept_ai\\src\\candidate_residual_graph_runtime_v68.jl)

## 怎样判断是真的“机制原创”

至少同时满足：

1. 不能通过重命名映射成已有模板；
2. operator canonical form 与现有机制不同；
3. 标准干预下的因果响应不同；
4. 存在可测、可辨识的独特预测；
5. 同一机制能产生两个以上不同 physical realization；
6. 换 realization 后关键效应仍存在；
7. 通过守恒、稳定性和适用域硬门；
8. 最后再做外部文献、专利和专家原创性审查。

其中第 5、6 项很重要：如果一个“新机制”只能依赖某个特殊组件拼法存在，它很可能仍是实现偶然性，而不是新的物理组织原则。

所以我认为下一步最值得做的，不是 v139 再扩大区域图，而是建立：

> **PhysicsProgramGenome v1：以状态—守恒—算子—可观测量为基因，以区域和组件为涌现表型。**

这才是从“组合式装置搜索”进入“机制级发现搜索”的真正转折点。