# Typed AST、operator hypergraph 与条件 e-graph：职责和实施状态

> 2026-09-14。本文是表示层说明及 UP5 接入合同，当前实际能力须以源码核验。共同语义见 [00](00_normative_contracts_and_state_model.md)，实现工作见 [16](16_execution_work_orders.md)。

当前 typed AST 和 operator hypergraph 确实参与候选构造、类型/单位/守恒检查和若干执行切片。对应 `src/IR/TypedAST.jl`、`OperatorHypergraph.jl`。它们支持表达合法程序，不保证每种合法程序已存在离散/求解实现。

`src/IR/ConditionalEGraph.jl` 与 `ConditionalEGraphSaturation.jl` 已有带条件、有限预算的整程序精确匹配与推导实现；当前生产搜索尚未把它用作一般子表达式 congruence/equality-saturation 引擎。不要重写为“完全没有 e-graph”，也不要称“已全面用于物理搜索”。UP5-01 负责实际接入，UP1–UP4 不等待广泛重写系统。

它们是三种不同层次的“物理程序表示方法”，不是互相排斥的方案。可以把它们理解为：

- typed AST：描述一个物理算子“怎么算”；
- operator hypergraph：描述多个状态和算子“怎样耦合”；
- e-graph：判断不同写法“是否其实等价”。

用一个能量输运方程举例：

\[ \partial_t u+\nabla\cdot(u\mathbf v-\kappa\nabla T)=Q. \]

## 1. Typed AST：带类型的抽象语法树

AST，即 Abstract Syntax Tree，是编程语言用来表示表达式的树。

上式中的通量

\[ \Gamma=u\mathbf v-\kappa\nabla T \]

可以表示为：

```
Subtract
├─ Multiply
│  ├─ u
│  └─ v
└─ Multiply
   ├─ κ
   └─ Gradient
      └─ T
```

“typed”表示每个节点不仅知道名称，还知道物理类型：

```
T        : scalar_field[K]
grad(T)  : vector_field[K/m]
κ        : scalar_field[W/(m·K)]
κgrad(T) : vector_field[W/m²]
div(...) : scalar_field[W/m³]
```

因此编译器可以自动拒绝：

```
温度 + 速度
标量作为散度输入
单位 W/m² 与 W/m³ 相加
三维 curl 作用在 0D 状态上
```

它特别适合做物理基因组，因为基因变异可以是：

- 增加或删除算子；
- 把局域扩散替换为非局域积分核；
- 改变张量秩；
- 插入反馈项；
- 替换闭合关系；
- 增加时间记忆项。

优点是适合生成和类型检查；执行还要求每个算子及其组合有已验证的 lowering/kernel。缺点是它天然是一棵树，不善于表达大量共享状态、循环反馈和多区域耦合。

## 2. Operator hypergraph：算子超图

普通图的一条边只能连接两个节点。超图的一条 hyperedge 可以同时连接多个输入和多个输出。

例如聚变反应：

\[ D+T\rightarrow \alpha+n+17.6\,\text{MeV} \]

不能很好地表示成一条普通二元边，因为它同时：

- 消耗 D；
- 消耗 T；
- 产生 α；
- 产生中子；
- 向不同区域注入能量。

在 operator hypergraph 中，可以表示为：

```
输入：
  n_D, n_T, T_i

        │
        ▼
[D-T reaction operator]
        │
        ├─→ D sink
        ├─→ T sink
        ├─→ alpha source
        ├─→ neutron source
        ├─→ plasma heating
        └─→ wall nuclear heating
```

对于多区域接口也很合适。例如区域 A 流出 10 MW，必须同时成为区域 B 的输入或外部损失：

```
(region_A_energy, region_B_energy)
               │
               ▼
      [interface flux operator]
               │
       (-10 MW, +10 MW)
```

一个 hyperedge 同时写入两边，可以天然保证符号相反和接口守恒。

它适合表示：

- 多输入、多输出反应；
- 多区域守恒耦合；
- 场—粒子—材料耦合；
- 传感器—控制器—执行器反馈环；
- 一个算子同时影响多个方程；
- 拓扑事件和区域 birth/death。

因此，operator hypergraph 更像整台“物理程序”的系统结构，而 typed AST 更像其中每个算子的内部公式。

## 3. E-graph：等价表达式图

E-graph，即 equivalence graph，用来把许多数学上等价的表达式压缩到同一个等价类中。

例如：

\[ a+b,\qquad b+a \]

或者：

\[ -(a-b),\qquad b-a \]

写法不同，但数学上等价。如果搜索器把它们当成两个原创候选，就会产生大量伪多样性。

E-graph 会通过重写规则记录：

```
a + b  ≡  b + a
a × 1  ≡  a
a + 0  ≡  a
div(κ grad(T)) ≡ κ laplacian(T)   仅当 κ 为常数
```

然后完成：

- 等价表达式去重；
- 选择计算成本最低的形式；
- 找出最简 operator program；
- 判断所谓“新机制”是否只是旧公式换了写法；
- 在多个数值离散方案中寻找更稳定的实现。

最后一条例子非常重要：

\[ \nabla\cdot(\kappa\nabla T) = \kappa\nabla^2T \]

只在 \(\kappa\) 为常数等条件下成立。因此物理 e-graph 不能只保存重写规则，还必须保存适用条件：

```
equivalence:
    div(κ * grad(T)) ↔ κ * laplacian(T)

requirements:
    grad(κ) = 0
    same coordinate metric
    same boundary interpretation
```

否则 e-graph 可能错误地把不同物理模型合并。

## 三者的关系

|表示|回答的问题|最适合的用途|
|---|---|---|
|Typed AST|一个算子具体怎样计算？|基因生成、类型/单位检查、执行|
|Operator hypergraph|多个算子和状态怎样耦合？|多区域残差、守恒、反馈、反应网络|
|E-graph|两个程序是否只是等价写法？|去重、规范化、最简化、原创性预检|

对于 FusionConceptAI，最合理的方案是三层同时使用：

```
PhysicsProgramGenome
        │
        ▼
Typed AST
表示每个 governing/additive operator
        │
        ▼
Operator Hypergraph
连接状态、残差、区域、接口和可观测量
        │
        ▼
E-graph Canonicalization
等价变换、去重、最简表达式和机制比较
        │
        ▼
Physics IR / v68 Residual Graph
        │
        ▼
数值求解与独立审计
```

一个具体候选可能是：

```
Typed AST：
  描述新输运项的公式

Hypergraph：
  描述该输运项如何连接核心、边缘、开放区和控制器

E-graph：
  检查这个“新项”是否其实等价于已有扩散、对流或变量替换
```

所以它们不是三选一。建议采用：

> **typed AST 作为基因语言，operator hypergraph 作为整机物理结构，e-graph 作为等价性和原创性过滤器。**

其中真正承载机制原创性的主要是 typed AST 与 operator hypergraph；e-graph 的任务是防止把代数换皮误认为原创。
## 5. UP5 接入协议

输入为 typed program、完整算子语义/效应、声明域、边界/时间解释、条件证明、规则版本、固定规则顺序和预算。输出为等价类引用、重写轨迹、条件检查与 `saturated/incomplete` 记录；这些是拟议的接入字段，非新增 Julia 类型已存在声明。

先做有限保守规范化与整程序去重，再扩展子表达式 pattern/congruence。每条规则独立验证类型、单位、坐标度量、边界、闭合、守恒 occurrence、随机/有状态效应。连续方程等价不自动保证离散系统或浮点程序逐位等价；不能因此移植不同 solver input 的证据。

固定配置必须确定性重放。预算截断会影响可达闭包；不同规则顺序不必得到相同 hash，未发现等价不能证明不等价。“最简”仅在已探索等价类与冻结代价模型内成立，不是全数学或全物理空间最简。

负控制包括变系数扩散被错误当常系数、非兼容边界、带副作用程序被重复消除、单位不符、缺条件和预算耗尽。全部 trace 需由独立 checker 重放。通过 e-graph 测试只提供表示等价证据，独立物理、工程与外部原创性仍按 [13](13_acceptance_benchmarks_and_evidence.md) 验收。
