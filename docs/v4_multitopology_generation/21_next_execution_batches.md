# 恢复后的执行批次

更新：2026-10-19。实验 Goal 已暂停，等待用户恢复；文档维护和授权清理不等于恢复计算。已完成实现见[实现记录](../implementation/IMPLEMENTED-STATE-20261019/implementation.md)，既有运行见[简短摘要](../implementation/IMPLEMENTED-STATE-20261019/run_history.md)。本页只保留下一步和判别条件。

| 顺序 | 当前问题 | 下一可判别动作 | 完整门 |
|---|---|---|---|
| S0 资源运行器 | full17 r4出现674.67秒采样缺口，原因未证 | 定位阻塞采样调用；修改后用正常/立即退出/超时负控验证原覆盖与清理门 | 每个正式运行独立满足4 GiB及完整覆盖；退出或峰值不能补缺失采样 |
| S1 C771实际求解 | r17通过资源门但Schur、stationarity、pressure未通过 | 利用保留的精确输入做固定active-set的高精度小Schur改进；先独立小矩阵oracle，再真实步 | 原KKT/压力/可行性/下降门同时通过；不得放宽阈值 |
| S2 完整64点B/J | near native-map contraction超预算；far只完成成本估计 | 对保留输入评估能证明误差界的批量中心/半径算法及共享几何缓存；先全列oracle | 完整near/far64点、同状态原始消费者、原预算/精度、独立复放 |
| S3 连续电流/周期积分 | 离散64行不能代替连续LCFS与全周期 | 同状态的根/切线相关包络单扇区pilot，再完整signed/gross积分 | 点值1e-4 A/m²、gross1e-3 A、signed1e-4 A，误差全部计入；真实路径守恒 |
| S4 UP2整体 | 五项全局闭合及UP2-01～05未完整接受 | 按[16](16_execution_work_orders.md)复用已合格局部范围，补真实统一R/J、合法/留出组合与原消费者A/B | 所有适用合同、数值/资源门和独立聚合齐备 |
| S5 UP3/UP4 | full17未通过；参考输入校准/映射缺项 | UP3先聚焦队列负控与资源问题；UP4先补实际signed PF/匝数和Thomson校准/误差来源 | 完整组合/断边/盲留出；三Genome参考反演、同链forward及fresh replay |
| S6 UP5/UP6 | 没有满足全部终局门的新候选 | 上游完整evaluator和工程/净电账本可用后执行真实搜索 | 同一候选完成全部R01–R10 |

沿用现有`scripts/run_bounded_check.py`与各原消费者入口。保留的暂停点输入及脚本清单见[retained_inputs](../implementation/WORKSPACE-CONSOLIDATION-20261019/retained_inputs.json)；被清理的大产物需要重新生成，不能以摘要代替fresh replay。不要复刻同义runner、冻结版本树或恢复已取消的旧T2与Q1_8降残差专项。

root独占共享入口和正式运行；源码准备按模块分工，Julia/DESC/FreeGS/网格重计算串行。未改变输入、语义和覆盖的合格证据可复用，失败必须先形成原因和对应修复。
