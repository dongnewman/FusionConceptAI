# agent_local execution repair r3

本轮只修复 independent review r2 的唯一 P1：调度器此前把除
`accepted` 外的所有合法状态都放进 `ready_tasks`，从而可能重复启动
`running`、绕过 `review_pending`/`changes_requested` 或重放 blocked 任务。

实现定义闭合集合 `DISPATCHABLE_TASK_STATUSES={planned, ready}`：

- `ready_tasks` 仅列出这两个状态且技术依赖已满足的任务；
- 显式 `--task` 选择 `running`、`review_pending`、`changes_requested`、
  `blocked_external` 或 `accepted` 时返回
  `status=non_dispatchable_task_status` 并 exit 2；
- `changes_requested` 必须由调度者先显式改回 `planned`/`ready`，工具不会替换状态；
- 非法 status 仍走 manifest `invalid` fail-closed 路径。

只修改了 `tools/agent_local_execution.py` 和
`test/test_agent_local_execution.py`，未修改 16 号工作单、task manifest、Julia、
DESC、mesh、runs 或既有接受状态。命令与 stdout/stderr/combined hashes 见
[commands.json](commands.json)，清理记录见 [cleanup_inventory.json](cleanup_inventory.json)。

## 验证边界

`unittest` 22 项通过，Windows symlink 权限测试 1 项按环境 skip；
`validate_plan.py`、默认 preflight 和 `git diff --check` 均 exit 0。
这些结果仅证明调度/规划软件边界，不是 Genome、数值、物理或 R01–R10 验收。
