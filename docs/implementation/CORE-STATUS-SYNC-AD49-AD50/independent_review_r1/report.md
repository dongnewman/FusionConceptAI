# CORE-STATUS-SYNC-AD49-AD50 独立复核 R1

日期：2026-09-16（复核 UTC 记录为 2026-09-15）

## 判定

`pass_limited`。该判定只覆盖 AD50 核心状态同步的文档、清单、哈希、链接和规划验证证据，不构成 AD50 root acceptance，也不授予候选、物理、工程、搜索或 R01–R10 信用。AD50 当前严格保持 `implementation_status=completed_review_pending`、`independent_review_status=pending`、`root_acceptance_status=pending`、`decision=review_pending`、`accepted=false`；核心正文没有把 AD50 写成已验收。

## 冻结输入

`input_hashes.json` 冻结五个核心文件、`task_manifest.json`、AD50 当前 `manifest.json`/`report.md`/`direct_validation.json`/`cleanup_inventory.json`，以及被 AD50 引用的六组 AD48/AD49 root acceptance 目录中的全部文件（共 31 个输入文件）。task manifest 为 91208 bytes，SHA-256 精确为 `7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`；当前 39 个 task id 唯一、`depends_on` 形状保持，未加入 AD50 节点或边。

## 独立核验结果

1. 六组上游 root acceptance 均为 `accepted_limited`，并按各自范围保留软件能力边界。AD48 S3 与 AD49 S3 的正式 trusted-source 产品仍是 `typed_absent`、`terminal_deferred=true`、`no_publish=true`，且 external trust/source closure 分别为 `blocked_external_trust_root` 与 `blocked_external_trust_root_and_source_closure`。AD49 S2 的 G1/G2 factory identity/construction products 仍为 typed absence，G2 mapping 仍 absent；AD48/AD49 的有限接受没有被提升为 trusted identity。
2. G2 mapping、W3B、AD46、UP1-04B、UP2-00、B00、B04 仍为现有 `pending`/`blocked` 状态。T0、T1、T2、provider、mesh、solver、engineering、physical、search、R01–R10 全部为 `false`，`L4_credible_count=0`。
3. 独立运行 `python docs/v4_multitopology_generation/validate_plan.py`，PID `90848`，UTC `2026-09-15T19:51:45.095451Z`，exit `0`。原始 stdout/stderr 保存在 `raw/`，结果为 31 Markdown、534 relative links、39 tasks、DAG acyclic。五个新增同步相对链接逐条存在；同步目录内 18 个 JSON 全部可解析，0 errors。
4. 历史首轮计划校验仍保留为 `exit_code=1`、`status=superseded`、`counted_as_evidence=false`；没有把失败记录伪造成通过，也没有新增伪造 PID。当前 scoped `git diff --check` PID `97744`、UTC `2026-09-15T19:54:17.540667Z`、exit `0`，stderr 只有 CRLF warning。

## 保护与边界

本复核只写入 `independent_review_r1/**`。`cleanup_inventory.json` 记录无删除、无临时文件、无 `__pycache__`，冻结输入、源码、测试和旧归档未修改；复核前脏树状态为 336 行、SHA-256 `d1f625bcf24de1a605571e1a1b4b8fcdedcb18cae18dcf8c56ec5eb1e11b45da`。全程未运行 Julia/DESC，未触碰进程。输出哈希见 `output_hashes.json`；自身哈希字段均排除以避免循环。

## 信用上限

`pass_limited` 仅表示 status-sync 工程证据闭合。它不接受 AD50 实现，不改变 root acceptance pending，不解锁 G2 mapping、W3B、AD46、UP1-04B、UP2-00、B00、B04、T0/T1/T2、provider、mesh、solver、engineering、physical、search、R01–R10 或 L4。
