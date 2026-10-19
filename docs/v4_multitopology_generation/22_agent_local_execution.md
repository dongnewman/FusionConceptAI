# 本地执行政策与当前职责

默认[execution_policy.json](execution_policy.json)的agent_local。当前root请求GPT-6 Sol/high，不同实现/测试/复核角色请求GPT-6 Luna/high，最多9子智能体；host可见实际设置另记。旧策略的sol_agent/luna_agent/different_luna_agent只是tools/agent_local_execution.py兼容角色ID，不代表实际模型。

## 当前规则

- root独占共享入口集成、正式运行及最终裁决；源码准备按模块并行，Julia/DESC/FreeGS重计算串行、4GiB及原各门预算/阈值/覆盖。
- 单一维护的核心src；不复制版本树，不额外建立Git/hash/快照排障前置。真实候选/数据/结果身份与必要hash保留原意义，不能冒充物理正确。
- 本地开发、候选/来源接线、数值运行不要求外部CA/OCSP/CRL/TSA、人员证书、EHP或签名ACK。实际第一方来源/物理适用性、单位、边界、闭合和独立验证仍必需；旧外部认证只是显式选用兼容功能。
- 已完成的T0/T1/source witness及UP1约定软件范围复用证据；独立T2未接受且已取消，不重跑控制器/Git生命周期/分片/R30重绑。
- 缺来源/模型/边界保持typed_absent或terminal_deferred；数值、物理、程序、资源和人工中断分开。新的物理假设编码前集中提交，不能默认零。

## 当前运行方式

沿用各正式消费者原命令和`scripts/run_bounded_check.py`，实际入口/argv/environment/预算见[21](21_next_execution_batches.md)。不要求再套新启动器。已有可选本地调度入口保留：

```powershell
python -B tools/agent_local_execution.py
python -B docs/v4_multitopology_generation/validate_plan.py
```

前者只检查任务/依赖与本地策略；历史accepted记录仍在归档时可能显示待提供当前记录，不能将此描述为物理失败。后者只检查当前文档、DAG、接口和合同一致性，不以已完成历史计划的字节hash/revision链作为当前前置。两者退出0都不授科学验收。

## 当前授权边界

用户已于2026-10-19暂停实验Goal；本轮仅文档整理、授权清理与Git交付。用户恢复后才执行16/21，完成短检才完整A/B，每次失败必须原因/对应修改。资源不完整仍失败；复用仍适用合格结果，不因无关文件变化全面重跑。终局同候选R01–R10保持原标准，当前可信候选0。

执行由root调度落实：现有`agent_local_execution.py`预检只列技术依赖已满足项，不自动获得正式运行授权。当前暂停期间不启动正式数值运行；用户恢复后仍由root启动。

`agent_local_execution.py --run`是历史通用开发命令记录功能；它自身没有正式资源采样保护。所有正式重计算必须由root调用既有`scripts/run_bounded_check.py`，不能用该通用记录功能替代正式runner或资源门。
