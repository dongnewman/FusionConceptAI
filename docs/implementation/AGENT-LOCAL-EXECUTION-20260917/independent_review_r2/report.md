# agent_local repair r2 独立复核

结论：`pass_with_findings`。

repair r2 已有效修复 r1 的 F1–F6：路径约束、manifest schema/status/dependency/DAG 校验、39 节点调度表、当前 HEAD 与历史基线标记、G3 本地来源措辞和闭合 policy schema 均已落地。当前 HEAD 仍为 `cfc745939a02fd023854dd04e9bb6d04ccadf9ee`；未运行 Julia、DESC 或 mesh，未提交。

## 复核通过项

- `execution_policy.json` 与 `EXPECTED_POLICY` 完全相等；外部认证字段为 false/空，R01–R10 保留，候选身份不等于科学验收。
- `tools/agent_local_execution.py` 现在拒绝 parent traversal、绝对路径、解析到仓库外的路径和外部 symlink（本机 symlink 创建因 WinError 1314 无权限而 skip；代码路径解析仍 fail-closed）。manifest 可独立拒绝 duplicate/missing dependency、cycle、非法状态、重复 task ID、越界 acceptance record 和未知 policy 字段。
- 当前 manifest 与 16 号调度总表精确一致：39/39、唯一 39、missing=[]、extra=[]。当前状态仍为 6 accepted、33 planned；R01–R10 完整、credible candidate count=0。
- `task_manifest.json` 当前 `base_head` 和 closeout `base_commit` 均绑定当前 HEAD；旧 `4b69f55` 已明确为 read-only historical baseline。G3 工单已改为 agent-owned local source/declaration records，不再要求 external authority declarations。
- r2 档案声明无 Julia/源码/旧 evidence/仓库级清理；533 条既有保护哈希独立复算仍为 `changed=[]`, `missing=[]`。

## 新发现：仍需修复

### F1 [P1] preflight 会把非可调度状态列为 ready

`tools/agent_local_execution.py:213-220` 的 ready 过滤条件只有 `status != "accepted"`。因此 `running`、`review_pending`、`changes_requested`、`blocked_external`，甚至显式传入 `--task` 的 accepted 任务，都可返回 `status="ready"`；实测临时 manifest 的各状态结果如下：

```text
planned          ready [A]
ready            ready [A]
running          ready [A]
review_pending   ready [A]
changes_requested ready [A]
blocked_external ready [A]
accepted         ready []
```

这会允许重复启动正在运行/等待复核/外部阻塞的任务，尤其不适合直接作为重型 Julia 独立复放调度入口。建议仅 `planned`/明确 `ready` 状态进入 `ready_tasks`，并对 `task_id` 检查可调度状态；`running`、`review_pending`、`blocked_external` 和 accepted 必须 fail-closed 或返回非可调度状态，`changes_requested` 需显式重新置为 ready。

## 是否可用于 agent_local→Julia 独立复放

当前结论：**不可直接作为通用独立复放调度入口**，原因是 F1 会破坏任务状态门，可能重复启动运行中的 Julia 或绕过 review/blocked 状态。对当前 manifest 中明确列出的 4 个 `planned` ready tasks，工具的路径、输入哈希、输出不覆盖、超时、非零退出和日志记录保护已通过；但在修复 F1 并补回归测试、再由不同 Luna 重跑后，才可作为默认 agent_local→Julia dispatch wrapper。即使修复后，它仍只是 development dispatch，不是 Genome、数值或物理验收器。

## 命令/证据

| 命令 | exit | 输出 SHA256 |
|---|---:|---|
| `python -B -m unittest discover -s test -p 'test_agent_local_execution.py'` | 0 | `946349cbb460d7132d310c2089fe19d875f72d0b3af579ac681a8db863eb7433` |
| `python -B docs/v4_multitopology_generation/validate_plan.py` | 0 | `c668c92af8ca7afd38217fd545e7178a093c13fe2ae58245d1e4406d78881364` |
| `python -B tools/agent_local_execution.py` | 0 | `dc44da46560f70e9f461ccd35063e85180aa84db0fbd2002f80237b25cb9c62b` |
| `python -B tools/agent_local_execution.py --task UP2-01-G3-SOURCE-FEEDBACK-V1` | 0 | `86a0f7bcbdf6b857e6d03903e3f0b4f6dc37e0a5d0180f19aa98dd36e9b7a8` |
| `git diff --check` | 0 | `a00de60aac9b463569a82c8ddbc1e32e65bae5179df5775d0679700a77e9e956` |
| 独立临时目录 traversal/absolute/symlink/cycle/dependency/status/policy probe | 0 | `cb8df56a30a0bd5e7d38fa6d9f7fca43568ee342fb9fb782a210afadd71cdf58` |
| 533 条 `before_inventory.json.protected_sha256` 独立复算 | 0 | `9d4f6beb53881bfd57f7444c3da7054ec54292718a3d51e0e5bb013f3a23a167` |

修复建议：增加 `DISPATCHABLE_TASK_STATUSES`/显式 task 状态门，覆盖 `running`、`review_pending`、`blocked_external`、`changes_requested` 和 accepted 的 negative controls；修复后重跑本报告同一组命令。除 F1 外，本批 r2 目标可接受为软件策略/规划同步范围，不授予任何 R01–R10、provider、mesh、工程或物理信用。
