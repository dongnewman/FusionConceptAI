# agent_local execution repair r2

基线 `HEAD=cfc745939a02fd023854dd04e9bb6d04ccadf9ee` 未改变；本轮不提交。
本轮只修复独立复核 r1 的 F1--F6：仓库内 acceptance record 路径约束、manifest
schema/status/dependency/DAG 的 fail-closed 边界、16 号调度总表同步、当前
`base_head` 与历史基线只读标记、G3 本地来源措辞，以及完整闭合的 execution
policy 校验。没有修改 Julia、G1/G2/G3、M4/M5、runs 或既有验收状态。

## 结果边界

- `test_agent_local_execution.py`：19 项通过；外部 symlink 负例在本 Windows
  环境无 symlink 权限时按测试内 skip，`../` 逃逸负例始终执行。
- `validate_plan.py`：39 节点、DAG 无环、370 条相对链接、0 errors。
- `agent_local_execution.py`：exit 0，报告 `ready`，仅为 development dispatch；不
  代表科学或物理验收。
- `git diff --check`：exit 0；Git 仅报告既有 LF/CRLF warning。

命令、退出码和 stdout/stderr/combined SHA256 见 [commands.json](commands.json)。
测试产生的 TemporaryDirectory 已由 unittest 清理；本修订没有执行仓库级清理，
路径归属和清理结果见 [cleanup_inventory.json](cleanup_inventory.json)。
