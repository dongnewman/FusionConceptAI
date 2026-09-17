# AD-35 task closeout and cleanup contract

状态：`accepted_limited`；`accepted=true`；`accepted_scope=collaboration_contract`；`claim_ceiling=collaboration_contract_only`。本档案只定义 Luna 子任务的实现、验证、关账和清理边界，不创建新的主线 task，不改变 UP0–UP6 DAG，不授予 provider、mesh、工程、物理、搜索、B00、B04 或 R01–R10 信用。AD-35 当前基线为完整 HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`，实际模型为 `gpt-5.6-luna`、reasoning 为 `high`。Sol 已裁决为 accepted_limited；不同 Luna 已独立复核本合同的落地记录。

## 1. 适用范围和不可替代的收尾顺序

每次分派子任务都必须在同一 `task_id` 下完成以下顺序，才能向 `review_pending` 返回：

1. 冻结 `base_commit`、当前 dirty inventory、运行中进程快照和受保护文件的路径/SHA256；明确本任务的 `writable_paths` 与禁止写入路径。
2. 对实现任务完成实现，再执行该任务专属的正向和负向测试；测试必须针对真实实现入口和真实输入，不以文档、计划、代理口述或总 runner 的退出码替代。
3. 对纯架构、审计或文档任务运行适用的 JSON 解析/schema、link、diff、format 或静态一致性验证；这类任务不得伪造代码测试、物理测试或实现信用。
4. 保留每个适用命令的真实 `cwd`、argv、环境/解释器、PID 或明确 `in_process=true`、UTC 开始/结束时间、stdout raw 内容/路径及 SHA256、stderr raw 内容/路径及 SHA256、stdout+stderr combined 内容及 SHA256、exit code、输入/输出/artifact SHA256。实现任务缺任何一项，保持 `review_pending` 或 `changes_requested`；纯文档静态命令也必须具备同一 receipt 字段。
5. 在清理前建立 closeout inventory，列出本任务创建或修改过的每个路径、before/after existence、SHA256、所有权、类别、原因和拟采取动作；给出 `final_exact_owned_set`。
6. 只清理本任务自己创建且不属于冻结交付、测试、失败证据或 accepted artifact 的 `scratch`、`cache`、`debug`、`unrelated_code`。删除或回退必须逐路径记录；不确定的条目使用 `cleanup_deferred_ambiguous` 并保留。
7. 清理后重新计算所有 owned/protected 路径的存在性和 SHA256，由不同 Luna 独立复核 cleanup inventory、保护哈希、正负测试/静态验证 raw receipt 与最终文件集合；最后由 Sol 裁决。

清理是任务关账的一部分，但不能把清理成功写成实现、数值、物理或父目标成功。重计算、Julia、DESC、Gridap、大网格和全包回归仍共用唯一串行 lane；清理不得启动第二条重计算 lane。

## 2. 验证和证据合同

实现任务的正向测试证明声明能力在目标输入上工作；负向测试至少覆盖任务合同指定的非法/缺失/foreign/stale/冲突输入，并保存真实失败分类。`pass`、`program_exception`、`numerical_fail`、`physical_fail`、`human_interruption`、`not_executed`、`unsupported` 和 `terminal_deferred` 必须分开记录。局部软件测试不能提升物理或 R01–R10 状态。

架构、审计和文档任务只提交其适用的 JSON/link/diff/format/static validation receipt。若任务没有源码实现入口，必须明确写 `code_tests=not_applicable`，并写出实际运行的静态验证及其退出码，不能用预期的“通过”占位。

## 3. 保护和清理边界

以下对象默认受保护，除非它们同时出现在本任务冻结的明确写入范围内，并且 Sol 已记录该范围：

- 分派前已存在的 dirty 文件、他人任务的文件和未声明的路径；
- R1–R10 相关失败 raw receipts、stderr/stdout、PID/exit 记录、checkpoint 和审计输入；
- 已接受或已归档的 implementation/evidence artifacts、旧 receipts、历史 runs 与其 manifest/hash；
- 任何共享入口、测试清单、公共 registry、旧 candidate identity、旧 evidence/hash 和 `runs/` 下的非本任务产物。

禁止 broad glob、递归全局清理、按扩展名批量删除、清空整个 cache 目录或用全局 revert 覆盖 dirty work。路径所有权无法从 before inventory、任务命令、文件内容和 hash 共同确定时，必须保留并记录 `cleanup_deferred_ambiguous`。清理动作只能作用于逐项列出的 exact path；`final_exact_owned_set` 不得依赖未展开的 glob。

## 4. 关账记录字段和独立复核

每份任务关账至少有：

```text
task_id / base_commit / actual_model / actual_reasoning_effort
protected_file_hashes_before_after
command_receipts (cwd, argv, pid or in_process, started_utc, ended_utc,
  stdout/stderr/combined raw content and hashes, exit_code, input/output/artifact hashes)
validation_kind (implementation_tests | architecture_audit | documentation_validation)
cleanup_inventory[] (path, owner, category, existed_before, before_sha256,
  action, reason, existed_after, after_sha256, classification)
final_exact_owned_set
independent_luna_reviewer / review_result / review_report
sol_decision / claim_ceiling / remaining_obligations
```

独立 Luna 必须检查清理前后哈希、是否误触 pre-existing dirty/他人文件/R1–R10 失败 raw receipts/accepted artifacts、实现任务的正负测试或纯文档任务的适用静态验证，以及是否有 broad glob 或隐式全局动作。独立复核不能由实现者自审替代；没有复核和 Sol 决策，任务不得记为 accepted。

`status_sync_r1/manifest.json` 的自身 hash 使用 `self_hash_excluded=true`：manifest 记录自身路径、before/after existence、reason 和 canonical self-hash exclusion 规则，但不把包含自身 hash 的递归值写入自身。该 manifest 的实际字节 hash 由 repair receipt 记录。本 AD-35 的档案只记录合同和本合同自身的文档验证。它不是新的主线 task，不改变现有 task count/DAG，也不产生物理或 R credit。

AD-36 对 exact-file scope 作强制澄清：`exact_file_count` 只计产品/合同 deliverables。实现/测试所需 mandatory append-only evidence sidecars（raw stdout/stderr、exit、PID/UTC、interpreter、input/output hashes、repair reports、cleanup inventory、independent reviews、status sync）必须位于该 task 专属 `docs/implementation/<task-id>/archive/**` 或命名 review/status 子目录，不计入产品文件数，不得覆盖旧轮、越出专属目录或被 cleanup 删除。sidecar 仅限 evidence metadata/raw/reports/inventory/review/status，禁止放入产品/合同 deliverable、source、test、fixture、staticQA 或 launcher；发现即 `scope_violation`/`fail_closed`，只清理任务自有越界副本并保护违规 evidence。临时 launcher 仍禁止，测试使用 direct command；该规则由 [AD-36 amendment](../AD-36/acceptance.md) 适用于 AD-34 binding6/recheck7 与未来 exact-scope workorders。
