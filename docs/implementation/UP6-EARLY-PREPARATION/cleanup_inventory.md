# UP6 early preparation cleanup inventory

状态：`review_pending`；本任务没有需要删除的 material。

| path/scope | before | after | action | reason |
|---|---|---|---|---|
| `docs/implementation/UP6-EARLY-PREPARATION/` | 已有 10 个初始交付文件 | root manifest 定义的 12 个 writable/deliverable 文件 | retain | repair_r1 已纳入 root 计数；repair_r2 为独立记录 |
| `docs/implementation/UP6-EARLY-PREPARATION/independent_review_r1/` | 既有独立复核文件 | unchanged | preserve | 旧 review 受保护，本 repair 不覆盖、不删除 |
| `docs/implementation/UP6-EARLY-PREPARATION/independent_review_r2/` | 既有独立复核文件 | unchanged | preserve | 当前 R2 review 受保护，本 repair 不覆盖、不删除 |
| `docs/implementation/UP6-EARLY-PREPARATION/repair_r2/` | 本 repair 记录目录不存在 | `report.md`、`manifest.json` | retain | 仅记录本次 validation-count repair |
| `docs/implementation/UP6-EARLY-PREPARATION/acceptance.md` | 有限接受记录不存在 | `acceptance.md` | retain | Sol/root `pass_limited` 的模板范围接受记录 |
| `docs/implementation/UP6-EARLY-PREPARATION/status_sync_r1/` | 状态同步目录不存在 | `report.md`、`manifest.json` | retain | 仅同步 accepted_limited 状态，不增加证据信用 |
| `docs/implementation/UP6-EARLY-PREPARATION/independent_review_r3/` | 既有独立复核文件 | unchanged | preserve | R3 review 受保护，本 status sync 不覆盖、不删除 |
| task-local scratch/cache | none created | none | no action | 未运行 provider、solver、复放或搜索 |
| task-local unrelated code | none created | none | no action | 未写 `src/`、`test/`、`scripts/` |
| `src/`, `test/`, `scripts/` | 既有 dirty/untracked | preserved | no action | 保护当前源码、测试和脚本 |
| `runs/`, `benchmarks/` | 历史 raw、失败和运行产物 | preserved | no action | 保护失败证据和历史身份，禁止 broad cleanup |
| `docs/implementation/` outside this directory | 既有实现档案、环境审计和历史快照 | preserved | no action | 只读输入 |
| v4 planning docs, README, `task_manifest.json`, registry | 既有规划/清单 | preserved | no action | 用户明确禁止修改 |

没有执行删除、移动、reset、checkout、递归清理、历史归档重写或环境变更。本 status sync 只更新目标 manifest/validation/cleanup 并新增 `acceptance.md`、`status_sync_r1/` 记录；未改 provider、engineering、其他模板、core、index、其他包、旧 review 或运行产物。若独立复核发现并发 worker 在本目录外产生变更，应逐项登记并保护；不得将其归为本任务可清理对象。
