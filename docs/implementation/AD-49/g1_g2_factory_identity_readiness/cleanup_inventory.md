# AD-49 cleanup inventory

本单是只读就绪性审计。未删除、移动、覆盖、暂存或回退任何既有文件；未清理共享
`runs/`、其他 agent 的临时目录、脏源码、测试、fixture、历史 receipt 或 accepted
产品。唯一新增根产品是 `report.md`、`manifest.json` 和本清单；唯一 sidecar 是
`archive/validation_summary.json`。

本单自有临时文件：无。没有可安全清理的 task-owned scratch；任何未来 S1/S2/F0/S3/
mapping/W3-B 实现都必须拥有自己的目录和 cleanup inventory。失败、中断和 typed-absence
raw 必须 append-only 保留；ownership 不明确时 cleanup 必须 deferred。

## R1 repair closure

独立复核 R1 的 `changes_requested` 报告、manifest 及其 `review/raw/**` 完整保留，未覆盖。
本次修复仅更新三件根产品，并新增 `archive/validation_summary_r1_repair.json`；修复内容是
W3-B 八个轴路径的 G1/G2 唯一目录、六个 machine work-order 的逐单字段及分层 result
union。没有创建任何未来产品或修改被审输入。

范围保护：未修改 `src/`、`test/`、fixture、registry、core、`task_manifest.json`、
AD-39–AD-48 既有产品或父目标证据；未运行 Julia/DESC/provider/mesh/solver/engineering/
physics/search；未创建 declaration、candidate、identity 或 final hash。
