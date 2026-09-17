# v4 高保真整装、工程与 VVUQ

## 1. 目标

本模块对极少量 frontier candidates 执行完整、候选绑定、场景绑定的 whole-device integration。单个平衡、场线、稳定性或工程后处理通过不能代替整装闭合。

## 2. 高保真准入

候选必须：

- 通过所有适用的前置 hard gates；
- 拥有完整 `ExecutablePhysicalSubjectV4`；
- required provider graph 已全部 resolved；含 `terminal_deferred` 的候选只能进入 terminal closure audit 和 capability-gap queue，不得把已解子图当作 whole-device integrated solve；
- 所有设计 alternatives 和 required scenarios 已冻结；
- 数值预算、收敛准则、UQ 分布和交叉代码协议预注册；
- 不因搜索排名获得不同物理阈值。

## 3. 整装耦合范围

按 mission 和候选义务组装，不强制每个候选使用同一无意义方程集合。典型 required blocks 包括：

- 多区域电磁场与有限压力/自由边界平衡；
- 粒子、动量、离子/电子能量守恒；
- 反应、自加热、辐射、燃料和灰分；
- 平行/横向/轨道/动理学输运；
- 适用的局域、全局、非线性、阻性或动理学稳定性；
- 线圈、电源、执行器、传感器、控制器与故障逻辑；
- 电磁力、结构、热、材料、屏蔽、低温和维护；
- plant power 和净功率区间。

完整 residual/iteration 必须包含 required coupling。一次求解后顺序拼接的独立后处理只能获得其局部 evidence ceiling。

## 4. 数值收敛与守恒审计

每个 integrated solve 至少记录：

- governing residual norms by block；
- interface conservation mismatch；
- nonlinear/DAE iteration history；
- mesh/basis/time-step convergence；
- solver warnings and termination reason；
- state/observable uncertainty；
- exact software/environment hashes。

求解器没有在适用域内收敛时是 `numerical_fail` 或 `unknown`，不能依据部分输出给出物理失败或通过。

## 5. Numerical VVUQ

至少包含：

- 网格/基阶/时间步收敛；
- 参数和制造误差 UQ；
- 初值与场景敏感性；
- surrogate discrepancy；
- solver tolerance sensitivity；
- 独立实现或双代码比较；
- uncertainty propagation 到 hard-gate margins。

`numerical_vvuq=pass` 只表示在声明模型与数值协议内的可信度，不代表实验 validation 或工程 readiness。

因此 L3 numerical whole-device candidate 仍不能简称为“可信物理装置”；该称呼至少要求后续 authority 判定达到 L4 的工程与独立验证作用域。

## 6. 双代码与独立性

双代码证据必须满足：

- 两个 provider 属于声明的不同 independence group；
- 输入物理 subject 相同，坐标/单位转换可审计；
- 比较 observables、容差和对齐方法预注册；
- 共享底层库、mesh generator 或校准数据时显式披露；
- cache replay 不计为第二个独立代码。

代码不一致不能挑选有利结果；应记录 discrepancy 并按协议判为 numerical fail/unknown 或触发诊断。

## 7. Validation VVUQ

验证证据必须候选绑定，并声明：

- 数据来源、测量不确定度和独立性；
- 候选/实验的几何、运行点和边界映射；
- calibration 与 validation 数据隔离；
- 可比较 observables 和外推范围；
- discrepancy model。

已知装置公开数据可做 scoped sentinel regression，但不能自动验证新候选。没有 admissible validation evidence 时保持 `unknown`。

## 8. 工程与控制场景

高保真整装不仅评估名义点，还必须执行 mission 声明的：

- startup、ramp、steady/hold、shutdown；
- actuator saturation、sensor dropout、delay；
- single-fault 和必要组合故障；
- thermal transient、quench/disruption 或对应异常；
- external power loss 与安全停机；
- 制造偏差和维护约束。

设计 alternative 可择一，required scenario 不可择优。任一全称 scenario 缺 evidence 时，整装结论不能越过其 ceiling。

## 9. WholeDeviceEvidencePackageV4

```text
physical_subject_hash
integrated_solver_graph_hash
scenario_manifest_hash
coupled_residual_audit
hard_gate_summary
engineering_summary
control_and_fault_summary
numerical_vvuq_summary
cross_code_summary
validation_vvuq_summary
unresolved_obligations[]
all_evidence_refs[]
claim_ceiling
```

包中 unavailable metrics 必须为 `null` 并附原因；不允许用 `Inf`、空数组或默认 pass 表示缺失。

## 10. 验收测试

1. 所有 required coupling 在同一整装 closure 中审计。
2. 数值不收敛不产生物理 pass/fail 越权。
3. 双代码 independence 可审计。
4. calibration 与 validation 数据隔离。
5. 所有 required scenarios 均有结果或明确 unknown/deferred。
6. numerical VVUQ 不提升为 validation VVUQ。
7. EvidencePackage 可从内容寻址 artifacts 完整 replay。
