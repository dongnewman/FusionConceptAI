# UP6 early preparation independent review repair r1

状态：`review_pending`；repair scope：`provider/engineering/manifest/validation/cleanup`；所有结论 `pending`；L4 credible count `0`。

## 复核意见对应修复

本 repair 针对 `independentR1=changes_requested` 的两项结构缺口：

1. `engineering_obligation_ledger_template.json` 的 15 条义务现在逐条显式展开 typed pending 字段：`candidate_ref`、`scenario_ref`、`physical_subject_ref`、`solver_input_ref`、`quantity`、`unit`、`threshold`、`comparison`、`owner`、`provider`、`data`、`model`、`verification`、`validation`、`model_discrepancy`、`uncertainty_uq`、`fresh_receipt` 和 `limitation`。每个字段均为 `{state:"pending",value:null,reason:<非空>}`；不再只依赖共享 `entry_contract`。
2. `provider_toolchain_audit_template.json` 与工程 ledger 的每条 `fresh_receipt` 都逐字段预留 candidate、scenario、physical subject、solver input、provider、toolchain、source tree、build、channel、interpreter、module identity，命令/cwd/时间/退出码、raw stdout/stderr/combined、对应 hashes、输入/输出/工件 hashes、status、applicability 和 limitation。receipt 合同要求 exact equality、freshness、raw/hash 完整性，并明确 `provider_id` 或 `input_hash` 单独不能关账。

## 允许写入和未执行边界

本 repair 只写目标包内：两个模板 JSON、目标 `manifest.json`、`validation_report.md`、`cleanup_inventory.md`，以及本目录下的 `repair_r1/report.md` 和 `repair_r1/manifest.json`。没有修改 core、旧 review、源码、测试、脚本、runs、历史 raw 失败证据或 task manifest。

没有运行 Julia/provider/solver/物理计算、下载数据、访问 Web、执行独立复放、计算净输出或原创性检索。JSON/schema/15-row/R01–R10/cross-reference/path/diff/cleanup 只做静态检查；静态通过不产生 provider、工程、VVUQ、物理、净输出、原创性、独立复放或 R01–R10 信用。

