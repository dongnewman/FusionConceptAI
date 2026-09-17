# AD-43 acceptance repair R1

日期：2026-09-15  
修复范围：仅修正 `acceptance/manifest.json` 中
`status_sync_r1/plan_dag_stderr.txt` 的 bytes/SHA-256 登记；不改 acceptance 正文、
AD-43 审计、四个 axis 并行产品、core 或 task manifest。

## 根因与修复

独立复核 `acceptance/independent_review_r1=changes_requested` 指出：原始
`plan_dag_stderr.txt` 实际为 1 byte，真实 SHA-256 为
`01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b`，而原
acceptance manifest 的 `validation.plan_dag.stderr_sha256` 误记为
`01ba4719c80b6fe911b091a7c05124b64eeece9649b934ca495991b7852b855`。

本 R1 只把 manifest 的 `plan_dag` stderr hash 改为实际完整 64 位 hash；旧错值
作为历史值保留在本 repair manifest，不覆盖任何历史 raw receipt。该文件的
bytes 仍为 1。acceptance 正文、`acceptance_validator` 记录、AD-43 audit 和
axis contract products 未修改。

## 复核与边界

修复后重新运行 JSON/hash/path/control/scope validator 与计划 DAG validator，
均记录真实 PID、UTC、exit、stdout/stderr 和 SHA-256。验证保持 39 tasks、DAG
acyclic、三处 typed absence、四产品 `point_in_time_excluded`/待独立复核和
全部 no-credit。既有独立复核 55/55、15/15 与验收 validator 20/20 仍作为
输入证据保留；本 R1 不把它们改写为物理或工程证据。

cleanup 只检查 repair 任务自有临时物；没有删除路径，历史失败收据、原审计、
并行产品、其它 agent dirty work 和 core 均保留。sidecars 仅保存验证元数据与
raw streams，不含 source、test、fixture、static-QA、launcher 或产品合同。
