# 工作区整理与存储清理（2026-10-19）

本次按用户要求整理实现文档、精简活动规划、退休无用旧代码，并将大部分历史运行结果/日志汇总后删除。实验Goal保持暂停，R01–R10、科学阈值和接受范围不变。

实现入口见[已实现软件](../IMPLEMENTED-STATE-20261019/implementation.md)，结论见[运行历史摘要](../IMPLEMENTED-STATE-20261019/run_history.md)，原接受条款见[accepted_contracts.md](../IMPLEMENTED-STATE-20261019/accepted_contracts.md)。活动规划只保留当前状态、剩余工作及原验收门。已完成依赖保留编号、范围与归档指针。

## 清理边界与可复放性

基线清点104,016个文件，共63,847,429,385字节，排除`.git`；其中`runs/`为62,960,586,296字节。最终清单包含70,873个文件、61,457,124,451字节（61.46 GB / 57.24 GiB）。实际执行结果以[删除执行收据](deletion_execution.json)和[独立校验](post_cleanup_verification.json)为准。

执行收据确认70,873/70,873全部删除、无失败。随后计入新增摘要/压缩清单，工作区文件长度为2,392,960,005字节，较基线净减少61,454,469,380字节；这是[文件长度统计快照](workspace_after_cleanup.json)，不是文件系统分配块测量，也不含`.git`。

保留暂停链明确输入/最新诊断检查点360个文件、1,835,254,241字节，均逐一记录SHA；保留44个当前工作单输入/证据根、原始参考输入、生产源码/fixtures、当前UP1 source/native pair。历史receipt与source/input pins的JSON保留原路径；已退休代码家族的专属元数据随家族进入摘要和删除清单。其余小型JSON/小型序列化包也有保留，360不是清理后文件总数。

大部分旧数组、重复检查点、原始stdout/stderr、source快照、临时probe和缓存已删除。保留的收据和SHA只能核对身份与原结论，不能重建数组。旧运行若需要已删输入，必须重新生成并写新收据；不得以摘要代替fresh replay或补写旧通过记录。部分历史文档/接受原件在本次清点前已缺失，未伪造恢复；原接受范围按保留条款记录。

## 审计文件

| 文件 | 用途 |
|---|---|
| [baseline_summary.json](baseline_summary.json)、[baseline_file_inventory.json.gz](baseline_file_inventory.json.gz) | 删除前文件/字节及路径清点，包含既有缺失tracked文件 |
| [baseline_git_status.bin.gz](baseline_git_status.bin.gz) | 原始Git状态的无损压缩；保留当时脏工作区边界 |
| [run_receipts.tsv](run_receipts.tsv)、[history_statistics.json](history_statistics.json) | 4578份历史收据的紧凑检索及字段统计；不是实验或接受次数 |
| [run_history_index.jsonl.gz](run_history_index.jsonl.gz) | 5473个目录分组的收据字段、有限日志摘录、被删JSON标量投影；数组明确省略 |
| [retained_inputs.json](retained_inputs.json)、[active_keep_roots.json](active_keep_roots.json) | 暂停输入SHA和当前工作单保护根 |
| [deletion_plan.jsonl.gz](deletion_plan.jsonl.gz)、[deletion_receipt.jsonl.gz](deletion_receipt.jsonl.gz) | 逐文件原路径/字节/SHA/理由与实际删除记录 |
| [retired_code.md](retired_code.md)、[retired_code_manifest.json](retired_code_manifest.json) | 调用审查后的代码退休范围与独立方法摘要 |
| [cleanup_verification.json](cleanup_verification.json)、[python_static_check.json](python_static_check.json) | 有界源码解析、模块加载及控制体oracle；不代表物理验证 |
| [planning_validation.json](planning_validation.json) | 原合同、任务状态和活动规划链接检查 |
| [normative_cleanup_baseline.json](normative_cleanup_baseline.json) | 10月16日已存在的Jn协议段落；精确移除该段并恢复旧换行能重建10月9日保护SHA，本次未编辑00–09 |
| [current_receipts_index.json](current_receipts_index.json) | 实现正文引用的6份收据的同字节已提交副本，原路径/SHA可核对 |
| [python_static_post_cleanup.json](python_static_post_cleanup.json) | 剩余347份Python源码含兼容测试语法通过；前次广扫发现的两项语法错误单独保留记录 |
| [audit_compaction.json](audit_compaction.json) | 3份本次生成的无压缩审计副本在字节一致性验证后移除，压缩件保留 |
| [user_pause_interruption.json](user_pause_interruption.json) | 暂停时尚未完成的UP3启动及未获测试信用说明 |

生成器为`tools/maintenance/summarize_run_history.py`；它只生成摘要和清单，不删除。PowerShell执行器先检查全部绝对目标均在本工作区、禁止reparse路径及保护根，再逐文件核对SHA后用`Remove-Item -LiteralPath`删除；没有递归清目录或改写Git历史。`verify_summarized_cleanup.py`独立核对缺失目标、保留输入及清单/收据对应，再无损压缩审计文件。

## 提交

`c5a304ebf57478eb5c2f4b1d10c3af446853a902`先保存当前编译器、求解器、测试和参考输入；`cd9982c`退休无用认证/参考协议版本、加入清单维护工具，并移除两个保留T2兼容QA脚本中四个非法列表推导式逗号。该修正只有语法信用，没有执行T2。后续文档提交记录实现/规划整理和清理审计；最终交付提交号由Git历史核对。大体积本地暂停输入不推送至远端，完整旧复放需要在本地重新准备缺失输入。
