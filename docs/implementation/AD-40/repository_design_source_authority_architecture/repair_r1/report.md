# AD-40 RepositoryDesignSourceAuthorityV1 repair R1

日期：2026-09-15  
状态：`review_pending` / `accepted=false`  
修复对象：independent review R1 的 `AD40-R1-AD35-RECEIPT-CLOSURE`

## 修复范围

R1 指出原 `archive/validation_receipt_r2.json` 虽有 PID、UTC、exit 和 raw
路径，但没有 stdout、stderr、combined raw stream 的 SHA-256，也没有冻结输入
与输出 artifact 的机器可读 hash 闭合。本修复只追加本目录 `repair_r1/`，不改
原 proposal、原 manifest、cleanup inventory、原 `validation_receipt.json`、
`validation_receipt_r2.json`、初次失败 attempt1 或 independent review R1。

修复后收据采用 UTF-8/LF 原始字节约定，分别记录：

- 静态闭合验证的 command、PowerShell interpreter、PID、UTC start/end、cwd、exit；
- plan validator 的 command、Python interpreter、PID、UTC start/end、cwd、exit；
- 两个命令各自的 stdout、stderr 和 `stdout || stderr` combined 文件的实际
  byte count 与 SHA-256；
- proposal、原 manifest、cleanup inventory，以及 AD-39 repair/independent
  review、当前 G1/G2 declaration、parent binding、T0 recheck 和 AD-30/33/34/36/37
  关键合同文件的冻结输入 path/bytes/SHA；
- 本 repair 的 report、manifest 和所有 raw sidecar 的输出 path/bytes/SHA；
  repair manifest 自身采用 `self_hash_excluded=true`，其余输出全部闭合。

## 适用验证结果

静态验证重新检查 JSON parse、产品文件名、AD-40 七个 work-order 的
inputs/outputs/result union/dependencies/forbidden edges/exit gates/cleanup/
sidecar 字段、claim flags、machine-node/task-manifest/candidate-hash 禁止项、
fixture/synthetic/legacy/historical reuse 禁止项、未来 payload 不存在、控制字符、
禁止路径、source artifact bytes/SHA 和 diff scope；结果为 exit `0`。

`python docs/v4_multitopology_generation/validate_plan.py` 重新检查规划文档与
39-task DAG，结果为 exit `0`。plan validator 只证明规划文档一致性，不证明
实现、候选、物理或 R01–R10。

最终 repair scoped recheck 在 repair 文件写入后再次确认：原三份 AD-40 产品
未被改写，repair 产品仅位于本任务目录，raw sidecar 仅位于 task-owned
`repair_r1/archive/**`，没有未来 candidate payload 文件，没有 src/test/core/
task_manifest 写入，且所有状态仍为 false。其收据追加在 `archive/`。

## 证据与声明边界

本修复没有运行 Julia、DESC、provider、mesh、solver 或物理程序，没有生成
candidate hash、source payload、factory receipt、present record、T0/T1/T2 或
任何 machine node。AD-40 仍是 architecture proposal；software source
provenance ceiling、present=false、T0/T1/T2=false、provider/mesh/solver/
engineering/physical=false、R01–R10=false 均保持不变。

完整输入输出闭合、raw receipt 内容、失败历史和 `self_hash_excluded` 规则见
同目录 `manifest.json` 与 `archive/`。原失败与不完整收据均 append-only 保留。

## 清理

本任务没有发现需要删除的 task-owned temporary 或 unrelated code。没有使用
glob 删除、global revert 或跨目录清理；预先存在的 dirty worktree、历史证据、
独立评审和其他进程产物均保留。cleanup result 为
`closed_no_owned_cleanup_required`。
