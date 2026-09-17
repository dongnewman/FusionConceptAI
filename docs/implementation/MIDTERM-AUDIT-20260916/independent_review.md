# 中期审计成品独立复核（2026-09-16）

## 复核结论

结论：`pass_for_documentation_scope`。主审已修复初次复核发现的失效链接和 AD-55 catalog 入口，并在21中明确新 prompt 的 UTF-8/LF 计数口径；最终 validation、artifact 和 protection 收据均通过。当前20、21、两个 README、审计 README、AD55 决策归档、目录和下一轮 prompt 已形成一条可供 Luna 使用的入口链。未发现删减 R01–R10、39-node DAG、T0/recheck/T1/T2、B00/B04、provider/mesh/solver/engineering/physics 或 L4 要求，也未发现把 source-stage `present` 越过 trusted/source/candidate/physics authority 的表述。

本复核的时间点为 2026-09-16 09:58–当前复核（Asia/Shanghai）。此前初审时 AD55 决策文件尚未出现；本次复核确认 [`AD55_decision_archive.md`](AD55_decision_archive.md) 已新增，因此不再把 AD55 说成“绝无归档”。该文件正确标注为用户转述的 Sol 裁决，不冒签 Sol，也不回写 AD55 原有 `accepted=false`/`completed_review_pending` 历史（[`AD55_decision_archive.md`（第3–7行）](AD55_decision_archive.md)、[`AD55_decision_archive.md`（第18–24行）](AD55_decision_archive.md)）。

复核只读取成品、`task_manifest.json`、AD55/AD48/AD49/AD56 原始档案、`before_inventory.json` 和入口快照；未运行 Julia/DESC/mesh/solver，没有修改任何主文件。本复核自身 `code_tests=not_applicable`，仅做 JSON 解析、路径/链接、计数、字符长度和内容边界核对；这不是 Julia/DESC/mesh/solver、数值、工程或物理验收。

## 必须修订或补充的事项

### 初次发现 P1：implementation README 的失效链接（已修复）

初次复核时 [`docs/implementation/README.md`（第16行）](../README.md) 将 UP1 接受记录链接为 `UP1-04A/`，但该目录不存在；真实目录是 [`UP1-04`](../UP1-04/)，其中有 `acceptance.md`。机器目录也已记录 `UP1-04A` 的 `acceptance_record` 为 `docs/implementation/UP1-04/acceptance.md`（[`archive_catalog.json`（第115–132行）](archive_catalog.json)）。主审随后已将入口修为 `UP1-04/acceptance.md`，计划链接校验现通过。

修订只改变检索路径，保留显示名 `UP1-04A`、task id、acceptance scope 和 DAG。

### 初次发现 P2：AD-55 在 catalog 中缺少可检索入口记录（已修复）

初次复核时 [`archive_catalog.json`（第1163–1169行）](archive_catalog.json) 将 `AD-55` 正确标为 `architecture_or_software_slice` 且 `acceptance_inferred_from_folder=false`，但 `entry_records=[]`。主审随后补入 fresh F0/S2 report、independent R1 和 related decision record；当前 implementation README 也明确列出它们（[`docs/implementation/README.md`（第27–33行）](../README.md)）。

当前入口记录只提供检索路径，仍保留 `acceptance_inferred_from_folder=false`，没有把入口记录写成 `accepted=true` 或 machine-node completion。

### 初次发现 P2：prompt 的“492 字符”口径（已由21闭合）

初次复核测得 `next_sol_goal_prompt.txt` 的两个正文行长度为 183 和 308，正文合计 491 个 Unicode 字符；CRLF 文件读取长度为 495，去掉 CR/LF 为 491。此前把计划校验报告的 `sol_prompt_characters=493` 归因于此文件是错误的；`validate_plan.py` 实际读取的是旧 `15_sol_system_prompt.md`，其去 CR/LF 长度为493。主审已在21明确新 prompt 的 canonical 口径：UTF-8 解码、CRLF 转 LF、去首尾空白、保留内部一个换行，计492（不计内部换行为491），并保持低于500。

当前计数口径已闭合；不应为了凑数改变提示词技术约束。

## 已确认正确的边界

1. 20 将 39 节点明确写为 6 accepted、33 planned，并把 UP1 的 4 accepted/11 planned、UP2–UP6 的 planned 状态与阶段未过门分开；这与 `task_manifest.json` 的按 phase 计数一致。20 还明确指出 accepted 只覆盖验收书范围，AD 子切片不会改变父节点状态（[`20_midterm_audit_20260916.md`（第11–25行）](../../v4_multitopology_generation/20_midterm_audit_20260916.md)）。
2. 21 将 M1–M5 标为分派标签，明确不新增 machine node、不替代 39 节点、不改变 UP0–UP6/B00–B13/R01–R10；M4 也明确不是越过 M2/M3 的执行授权（[`21_next_execution_batches.md`（第3–9行）](../../v4_multitopology_generation/21_next_execution_batches.md)、[`21_next_execution_batches.md`（第44–55行）](../../v4_multitopology_generation/21_next_execution_batches.md)）。
3. AD55 归档把“用户转述 Sol 的 accepted_limited”与原执行/独立复核的 `accepted=false` 分开，并保留 source authority、trusted attestation、candidate/final identity、provider、mesh、solver、engineering、physics、search、R01–R10、B00/B04 和 L4=0 的开放项（[`AD55_decision_archive.md`（第3–7行）](AD55_decision_archive.md)、[`AD55_decision_archive.md`（第20–24行）](AD55_decision_archive.md)）。
4. AD55 的18/19计数已被主审明确纠正：每次磁盘有20个JSON，其中18个是正式 identity/declaration/receipt，另2个是negative_controls/status辅助文件；旧报告“19 canonical JSON”作为历史文案保留，不再作为当前事实。主审同时记录了probe、harness和完整加载依赖未逐项冻结，因此 `source-stage present` 可以复核，完整执行闭包复建仍需先冻结完整输入再新目录复跑，不能倒填旧运行的冻结证明（[`AD55_decision_archive.md`（第18–20行）](AD55_decision_archive.md)）。
5. AD48/AD49 S3 的外部 trust root 缺口仍是 typed absence/terminal deferred/no publish 条件；21 要求逐项记录提供方、独立性、密钥/证书/验证器、吊销、时效、可信时间、防重放和 source/G2 mapping 输入，没有把本地 hash、reviewer 或 test exit 当作信任（[`21_next_execution_batches.md`（第21–34行）](../../v4_multitopology_generation/21_next_execution_batches.md)）。
6. 20 明确下一份实质交付应回到“声明→真实残差→离散→求解→误差/守恒”，并把 source authority、数值、工程和物理分层；这保留了完整目标，没有以 S3 或状态同步文档替代 UP2 数值能力（[`20_midterm_audit_20260916.md`（第38–51行）](../../v4_multitopology_generation/20_midterm_audit_20260916.md)、[`README.md`（第31–43行）](../../v4_multitopology_generation/README.md)）。
7. 审计 README 正确保护 5968 文件快照、旧入口原文、源码/测试/合同/任务表/失败证据，并规定 `code_tests=not_applicable` 与不得 stage/commit/push；其 `accepted_limited` 判读规则也没有产生新执行权限（[`MIDTERM-AUDIT-20260916/README.md`（第15–25行）](README.md)）。

## 校验状态与交接

catalog 当前已确认 `task_count=39`、`directory_count=90`、status counts `accepted=6/planned=33`、manifest SHA 为 `7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`，AD-55 已有两个 fresh report 入口和 decision origin 记录，且 `acceptance_inferred_from_folder=false`。`before_inventory.json` 的 HEAD 为 `b2c04d8339774635aaecd73651efcdb101e01b5d`，与当前核心入口一致。

初次复核运行 `python validate_plan.py` 时，本复核文件尚未存在且 UP1 链接仍失效，结果为 39 tasks、DAG acyclic、prompt 校验通过，但 exit `1`；主审修复两个入口问题并补齐本文件后，复跑结果为 `checks=pass`、33 markdown、358 relative links、39 tasks、DAG acyclic、16 snapshot hashes、exit `0`。验证收据仍需由主审按其最终字段状态归档；本复核不把待归档 receipt 当作科学或实现验收。

除上述三项检索/计数口径修订外，成品可交给 Luna 使用。Luna 仍应先读 21 → 20 → 00 → 16 → task manifest → implementation README → 自己的 acceptance/manifest/review，并按 `planned + local accepted_limited`、`present + trusted=false`、`typed_absent + terminal_deferred` 和 `fail_closed` 模板行动；任何新输入变化都必须使下游 identity/receipt fresh rebuild，外部 trust root 缺失则保持 no publish。
