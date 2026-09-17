# agent_local 批次独立复核 r1

结论：`pass_with_findings`。

复核者按不同 Luna/独立复核角色检查了当前未提交的 `agent_local` 政策、调度器、测试、指导文档、任务清单和本批档案。基线 `HEAD=cfc745939a02fd023854dd04e9bb6d04ccadf9ee`；工作树已有大量与本批无关的 dirty/untracked 文件，均未修改。未运行 Julia、DESC、mesh 或重型任务。

## 已确认通过

- `execution_policy.json` 将 `agent_local` 设为默认，`external_approval_required=false`、`external_certification_blocks_execution=false`、`external_requirements=[]`；`candidate_identity_is_scientific_acceptance=false`，且 `R01`–`R10` 全部保留。
- `22_agent_local_execution.md` 明确取消外部认证作为研发/候选/数值/项目内验收/搜索前置，同时保留 typed、数值、工程和科学边界；旧外部模块/收据按兼容历史保留，未发现批量改写旧收据为 present 的行为。
- 当前 manifest 有 39 个唯一任务、无缺失依赖；状态为 6 `accepted`、33 `planned`；R01–R10 要求和 `credible_candidate_count=0` 未改变。`validate_plan.py` 报告 39 节点、DAG 无环、34 个 Markdown、365 条相对链接、0 errors、exit 0。
- Python focused unittest：11/11，exit 0；覆盖外部材料不需要、技术依赖阻塞、输入缺失/篡改、非零退出、非法 executable、输出目录不可覆盖和输入路径逃逸。`git diff --check` exit 0（仅有换行转换 warning）。
- 533 个保护哈希独立复算：`changed=[]`、`missing=[]`，exit 0。HEAD 未变，已有任务状态和 R01–R10 目标未被本批改写。

## Findings

### F1 [P1] acceptance record 依赖路径未 fail-closed

`tools/agent_local_execution.py:64-72` 对上游 `acceptance_record` 仅执行 `(root / record).is_file()`，未调用和 `file_record` 相同的仓库内路径约束。独立临时 manifest 中把已接受任务的记录写成 `../outside_acceptance_for_review.md`，`preflight()` 返回 `status="ready"` 并释放下游任务；仓库外文件或仓库内指向外部的 symlink 因而可伪造技术依赖已满足。当前真实 manifest 的记录均在仓库内，但这是调度器的潜在越界路径。

建议：复用统一的 resolved repository-relative helper 检查 acceptance record，拒绝 `..`、绝对路径和解析到 root 外的 symlink，并增加负例；异常或越界统一返回 invalid/blocked，不应释放任务。

### F2 [P1] 直接 preflight 对循环/非法任务状态没有 fail-closed

`preflight()` 只检查重复 ID 和策略绑定，不验证允许的任务状态、依赖 ID 或 DAG 环；在临时 manifest 中，A↔B 循环返回 `status="ready", ready_tasks=[]`，未知状态 `unexpected` 的任务也返回 `status="ready", ready_tasks=["A"]`。当前 `validate_plan.py` 能发现真实规划的循环/状态问题，但正常入口 `python -B tools/agent_local_execution.py` 可以绕过它，因此不能把规划校验器作为唯一安全边界。

建议：在 `preflight()` 中独立执行 manifest schema/status/dependency/cycle 校验；任何 malformed、unknown status、missing dependency 或 cycle 均返回 invalid，且补充对应回归测试。

### F3 [P1] 39 节点与 16 号调度总表不同步

当前 `task_manifest.json` 有 39 个任务，但 `16_execution_work_orders.md` 第 28–61 行的调度总表只有 34 个任务，漏列：

- `UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC`
- `UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC`
- `UP1-04A-VNEXT-T0`
- `UP1-04A-VNEXT-T1`
- `UP1-04A-VNEXT-T2`

这些任务虽有后文 anchor，故 `validate_plan.py` 仍 pass；但调度总表不完整会使依赖路线不可见。建议补齐总表，或让 validator 显式核对总表 ID 集合等于 manifest ID 集合（允许明确标注的非任务 AD anchor）。

### F4 [P2] active manifest 的基线字段仍指向旧提交

`task_manifest.json:5` 的 `base_head=4b69f55`，`task_closeout_policy.base_commit`（约第 37 行）也是旧提交；本批 README 已声明起点为 `cfc745939a02fd023854dd04e9bb6d04ccadf9ee`。若 `4b69f55` 是历史规划基线，应明确字段名/注释为 historical；若它表示当前执行基线，应改为本批 HEAD。否则 worker receipts 可能误绑定旧源码。

### F5 [P2] G3 工单仍有外部 authority 前置语义歧义

`task_manifest.json:484` 和 `16_execution_work_orders.md` 的 G3 SOURCE-FEEDBACK 工单仍写 `external authority declarations`，并要求后续 binding receipt 中有 `authority`；这与 `execution_policy.json:11-13` 的外部认证非前置和 22 章“外部权威 G2/四轴材料不再阻塞”不完全一致。其他 T0/T1 更新已明确使用 agent-owned local records。建议将此处改成可由智能体验证的 local source/semantic authority record，并明确外部认证缺失不能使该任务 blocked；真正缺失的物理/语义闭合仍可按 `terminal_deferred` 保留。

### F6 [P2] policy validator 不是完整 fail-closed schema 校验

`policy_errors()` 目前只核对选定的 profile、外部门、candidate identity、DAG freeze 和 R01–R10 字段；`responsibility`、`local_requirements`、`authority_basis`、`legacy_external_profile` 等声明被删除或改变时仍可能通过。建议至少对本地要求、职责和兼容 profile 做固定 schema/类型/值检查，避免政策声明漂移而工具仍报告可执行。

## 命令与收据

| 命令 | exit | 输出 SHA256 |
|---|---:|---|
| `python -B -m unittest discover -s test -p 'test_agent_local_execution.py'` | 0 | `387982b8b95c0fb0bc72fe05c29468962209e68668d4919fc526272d2295b861` |
| `python -B docs/v4_multitopology_generation/validate_plan.py` | 0 | `2822ed13b8dcad6553164e1b9727a09e189b6cf287d337723a336983582d9743` |
| `git diff --check` | 0 | `510453d3c8c5c4c2706a9ad5d2af109506def0fbd992111fd001f82b54b18d44` |
| 533 条 `before_inventory.json.protected_sha256` 独立复算 | 0 | `9d4f6beb53881bfd57f7444c3da7054ec54292718a3d51e0e5bb013f3a23a167` |

关键当前文件哈希：`execution_policy.json=4c148ca007b30431856ddf6fd5217eea23071ed80f8920742eea18b362dc4015`，`tools/agent_local_execution.py=e29e7cb1b1d379259930f93b23e5e21d66d41a775de6b1554d93dafb05a1763b`，`test/test_agent_local_execution.py=ff62bc20b0791818b2ea0e888caa2acfa53fdd7c93d370b1b9d591590ae98adb`，`22_agent_local_execution.md=48887c44f896c9dcd013dfa300858fc24ccdebfbf580438a8e95580e3749e02b`。

本复核只在本目录新增 `report.md` 与 `manifest.json`，不修改被审文件，不修改 task manifest，不提交 commit。建议先修复 F1–F3，再由不同 Luna 重跑同一组轻量检查；F4–F6 可在同一修订批次澄清/加固。
