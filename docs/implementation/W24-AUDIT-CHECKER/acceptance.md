# W24-AUDIT-CHECKER

状态：`accepted`（限定为 ledger predicate/checker artifact semantics），`accepted=true`。

本工作单只修复 `scripts/verify_v4_spatial_manifest.py` 的 execution-ledger 判断，并新增其 focused test 与本记录。实际模型为 `gpt-5.6-luna`，effort 为 `high`；基线 HEAD 为 `4b69f55f7f80240147a65a22809dc1207824dde2`。允许写入范围仅为本脚本、`test/verify_v4_spatial_manifest_tests.py` 和本目录两份记录；旧 runs、queue、其他源码/测试/入口和核心文档未修改。

旧脚本 SHA-256 为 `a8f42022a8be19c4a1960678cf41e97cc157f33f429464d17335da4f08ec886b`，修复后为 `bbf9a7e3fc2f6c611f05194ed9909dc22b9c7f4f9cf0694ea7ef6573813b16d6`。修复内容是：required stages 的最终 ledger event 必须全部为 `execution_state=completed`；缺 stage 使用 fail-closed；历史 `program_exception` 只独立计数，不再作为恢复成立条件。`ledger_recovery_history_ok` 字段保留以兼容报告 schema，但其语义现在是 required-stage terminal completion。

focused test 命令：

```powershell
python -m unittest discover -s test -p 'verify_v4_spatial_manifest_tests.py' -v
```

实际结果：3 tests，`OK`，exit `0`。覆盖干净完整 ledger（无 exception）通过、缺 terminal stage 失败闭合、历史 whole exception 后有 completed terminal event 仍通过且 exception 计数为 1。

W24 parent 审计使用临时输出路径，不修改 parent run。以 HEAD 旧 checker 在临时等价 fixture 上复现：exit `1`，`ledger_recovery_history_ok=false`，`mismatch_count=0`，报告 SHA-256 `bd1d77e33082a20ea4c72fe61f749f0a1f8459dc05f8bf68c89638fd4ea841da`。新 checker 对相同 fixture：exit `0`，`status=pass`，`ledger_recovery_history_ok=true`，`mismatch_count=0`，报告 SHA-256 `35ff55c825992edbc0781fa04d3b5507254ce9dfa234027c5a1beeb632cb725f`。该隔离复现把 parent manifest 的 source/artifact 路径映射到临时副本，只用于把 ledger 条件与脚本自身版本哈希分离。

直接审计 immutable parent 原目录时，新 checker 的 ledger 判定为 `true`，但总 exit 为 `1`，原因是 parent execution manifest 仍封存旧 checker 哈希 `a8f42022...ec886b`，而当前脚本已按本工作单变更为 `bbf9a7e3...13b16d6`。这是 source-byte integrity mismatch，应保留为真实工程证据，不能通过修改旧 manifest 消除。

本 checker 只验证文件字节、candidate/context identity、stage/solver exit、四场景和 authority ceiling；它不是物理验证器，不能证明 W24 的数值收敛、工程可行性或 R01–R10 完成。W24 parent 的原有物理分类仍为 solver exit `4`/`iteration_limit`、whole `deferred`、credible `0`。

独立 reviewer 为 `different Luna`，复核通过脚本 diff、三类 ledger 测试、parent immutable manifest 的 source hash mismatch 边界。Sol 决策：接受本 checker 的有限软件修复；不授予 W24 物理/工程或 R01–R10 信用。直接审计 parent 的 exit `1` 必须保留，根因是 sealed manifest 中封存旧 checker hash；隔离 fixture 的新 checker exit `0` 不能替换或升级旧正式 run。
