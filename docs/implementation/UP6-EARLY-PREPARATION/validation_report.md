# UP6 early preparation validation report

状态：`accepted_limited`；范围：`preparation_only`；accepted scope：`early-preparation-template-only`；claim ceiling：`contract_only`。
所有结论为 `pending`，L4 credible candidate count 为 `0`。

`independent_review_r3=pass_limited` 只允许本模板包进入有限接受；不产生 provider、engineering、physical、net-output、VVUQ、originality、independent-replay 或 R01–R10 credit。

本次 `repair_r1` 仅修复 provider/toolchain fresh-receipt 显式连接、15 条工程义务逐条 typed pending 展开及其验证记录；没有修改 core、旧 review、运行产物或任务清单。

## 静态检查

本包完成后执行了以下只读检查（PowerShell，cwd 为仓库根）：

1. 对本目录递归 13 个 `.json` 严格解析：`errors=0`；其中 `independent_review_r1/`、`independent_review_r2/`、`independent_review_r3/` JSON 只作为受保护输入解析；`status_sync_r1/manifest.json` 是本次状态记录；
2. 检查 15 个 obligation ID（`unique=15`）和 R01–R10 10 个 ID（`unique=10`、`missing=0`）；
3. 检查 manifest 的 19 个本地文件/目录输入：`missing=0`；当前 root manifest 声明的 writable/deliverable 集合为 12 项，逐项如下，全部存在：

   - `docs/implementation/UP6-EARLY-PREPARATION/architecture_audit.md`
   - `docs/implementation/UP6-EARLY-PREPARATION/provider_toolchain_audit_template.json`
   - `docs/implementation/UP6-EARLY-PREPARATION/vvuq_data_catalog_template.json`
   - `docs/implementation/UP6-EARLY-PREPARATION/engineering_obligation_ledger_template.json`
   - `docs/implementation/UP6-EARLY-PREPARATION/originality_search_protocol.json`
   - `docs/implementation/UP6-EARLY-PREPARATION/independent_replay_protocol.json`
   - `docs/implementation/UP6-EARLY-PREPARATION/r01_r10_closeout_template.json`
   - `docs/implementation/UP6-EARLY-PREPARATION/manifest.json`
   - `docs/implementation/UP6-EARLY-PREPARATION/validation_report.md`
   - `docs/implementation/UP6-EARLY-PREPARATION/cleanup_inventory.md`
   - `docs/implementation/UP6-EARLY-PREPARATION/repair_r1/report.md`
   - `docs/implementation/UP6-EARLY-PREPARATION/repair_r1/manifest.json`

   `repair_r2/report.md` 和 `repair_r2/manifest.json` 是 repair 记录文件，已在 root manifest 的 `repair_history` 中登记；`acceptance.md` 和 `status_sync_r1/` 是状态记录；它们均不改变上述 12 项 root writable/deliverable 计数。
4. 递归检查模板的 pending 字段：`pending_null_without_reason=0`；15 条 engineering obligations 的 typed-field 错误数为 `0`；
5. 在目标目录搜索 64 位十六进制哈希：无结果，未填入未来 candidate/provider/solver/physical hash；R01–R10 为 `10/10` 且 ID 唯一；
6. 当前 HEAD 只作为审计标识记录为 `4b69f55f7f80240147a22809dc1207824dde2`；工作树已有大量 dirty/untracked 条目，本 status sync 的写入均位于目标目录，未修改其余路径；
7. 按任务边界确认本次未安装工具、下载数据、检索外网、运行 Julia/DESC/FreeGS/VMEX/Pleiades/CQL3D、执行 provider/solver/整装物理、计算净输出、独立复放、原创性检索或修改 core/task manifest。

### repair_r1 / repair_r2 / status_sync_r1 增量检查

- 每条 15 条 obligation 都显式包含 `candidate_ref`、`scenario_ref`、`physical_subject_ref`、`solver_input_ref`、`quantity`、`unit`、`threshold`、`comparison`、`owner`、`provider`、`data`、`model`、`verification`、`validation`、`model_discrepancy`、`uncertainty_uq`、`fresh_receipt` 和 `limitation`；每个字段均为 `{state:"pending",value:null,reason:<非空>}`。
- 每条 `fresh_receipt` 都显式包含自身 typed pending wrapper，并显式包含 candidate/scenario/physical subject/solver input/provider/toolchain/source tree/build/channel/interpreter/module identity，命令、cwd、起止时间、退出码、stdout/stderr/combined raw 与 hashes、输入/输出/工件 hashes、status、applicability 和 limitation。
- 静态结果：`rows=15`、`row_field_errors=0`、`fresh_field_errors=0`；provider 5 条 receipt 的字段错误数为 `0`；R01–R10 为 `10/10`、`missing=0`；manifest writable 路径 `missing=0`、受保护 review 目录之外 `unexpected=0`；future hash-like values 为 `0`。
- receipt contract 强制 exact identity equality、freshness 和 raw/hash 完整性，并明确禁止仅用 `provider_id` 或 `input_hash` 关账。
- repair 文件路径已加入目标 manifest 的 `repair_history`；既有 `independent_review_r1/`、`independent_review_r2/` 作为受保护旧 review 保留，未写入或清理。
- repair_r2 静态复核结果：递归 JSON `11` 个、解析错误 `0`；root writable `12`、root deliverable `12`、root 路径缺失 `0`；repair history 引用缺失 `0`；repair metadata 与两个 review 目录之外的额外文件 `0`。
- status_sync_r1 静态结果：递归 JSON `13` 个、解析错误 `0`；root writable `12`、root deliverable `12`；`acceptance.md`、status sync report/manifest、`independent_review_r3` 引用均存在；provider/engineering/physical/net-output/VVUQ/originality/replay/R01–R10 均保持 `pending`/`false`，L4 为 `0`。

## 预期结果和证据上限

| check | result | credit |
|---|---|---|
| JSON syntax | `pass` (`13` recursive JSON files; `0` errors) | none |
| identifier/reference/path checks | `pass` (`15` obligations, `10` R IDs, `12` root paths, `0` missing repair refs) | none |
| pending/hash boundary | `pass` by template design; no future execution identity is populated | none |
| diff scope | `pass` for target-package repair writes; existing dirty entries preserved | none |
| execution boundary | `not_executed` by contract | none |
| early-preparation template | `accepted_limited` | template/documentation only |
| UP6-01/02/03 | `planned`/`pending` upstream | none |
| R01–R10 | `pending`; `accepted=false` | none |

静态检查只证明文件结构和边界，不能证明 provider capability、物理收敛、工程可行性、VVUQ validation、正净输出、原创性或父目标完成。若最终检查发现目标目录以外已有变更，应保留并报告为既有 dirty/并发变更，不得回滚或覆盖。

## Formal-run gates

正式运行前必须由 Sol 冻结 candidate/scenario/mission、适用域、数量单位与阈值、provider/toolchain/source/build hashes、数据许可和独立性分组；由不同执行者复核模板和 checker。正式运行必须产生 raw stdout/stderr/combined、退出码和输入/输出/工件 hash。任何缺项保持 `unknown` 或 `terminal_deferred`，不得用历史收据、环境目录存在、文档、测试或 runner exit 0 晋升。
