# 三Genome当前接口与后续语义编辑

UP1-04A-VNEXT、UP1-04B和UP1-04约定软件范围已完成，其操作步骤不再列入当前路线。已接受节点范围与原验收条款见[16依赖索引](16_execution_work_orders.md)，软件完成不代表物理或整机完成。旧独立T2未接受且非活动；实际T0/T1/source witness仍为真实消费者输入。

## 当前接口

| 层 | 核心责任 | 进入真实消费者 |
|---|---|---|
| G1 | typed方程/单位、守恒、适用域、闭合与来源 | equation lowering→实际残差/J；缺provider或闭合明确延期 |
| G2 | 区域、坐标/度量、面/法向、积分、边界及DOF映射 | actual region/face/state gather→全局assembler；BOX与LCFS分开 |
| G3 | 源/线圈/驱动/材料/控制/返回与耗能 | source-to-field、受约束inverse、同链forward和工程账本 |

完整合同仍见[00](00_normative_contracts_and_state_model.md)、[G1](G1%20机制基因组.md)、[G2](G2%20场—几何基因组.md)、[G3](G3%20实现—控制Genome.md)。保留四版本轴、typed字段、旧payload/ref的原语义和原证据；现有真实接口需要兼容时，只处理已出现的差异，不复制整套V1/V2实现。

## 尚未完成

- UP2：五项闭合在同候选变化状态通过真实映射和适用物理律进入global R/J；具体接口见16。
- UP3：一般合法组合与留出进入统一coupled consumer，回传边拆除确实改变输出，不能只有预制组合表。
- UP4：真实观测→G1/G2/G3(theta)→同生产forward→识别/盲留出/复放；硬件参数替代目标源后实际重新求解并计工程损失。
- UP5：合法结构编辑产生真实下游变化；条件等价必须带适用假设/证明；完整搜索等上游门，不能靠标签或唯一hash授原创性。

后续每项实现只保留一个主线源码入口，交付接口表、可应用修改、消费者和验证命令；复用仍适用的已通过合同/覆盖。
